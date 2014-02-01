import 'dart:html';
import 'dart:math';
import 'dart:js';

Room r;
Grid gr;
var lastLoop = new DateTime.now();

const tolerance = 10;

class Color {
  final int r, g, b;
  final num a;

  static const Color BLUE = const Color.fromRGBA(0, 0, 255);
  static const Color BLACK = const Color.fromRGBA(0, 0, 0);
  static const Color GREEN = const Color.fromRGBA(0, 255, 0);
  static const Color RED = const Color.fromRGBA(255, 0, 0);
  static const Color TRANSPARENT = const Color.fromRGBA(255, 255, 255, 0);

  const Color.fromRGBA(this.r, this.g, this.b, [this.a = 1]);

  String get rgba => "rgba($r, $g, $b, $a)";
  String get rgb => "rgb($r, $g, $b)";
}

class Point {
  int _x, _y;
  int offsetX = 0, offsetY = 0;
  bool _lockX = false;
  bool _lockY = false;

  get x => _lockX ? gr.nearestX(_x + offsetX) : _x + offsetX;
  set x(v) { _x = v; offsetX = 0; }
  get y => _lockY ? gr.nearestY(_y + offsetY) : _y + offsetY;
  set y(v) { _y = v; offsetY = 0; }

  Point(this._x, this._y);

  Point.fromEvent(ev) : this(ev.page.x, ev.page.y);

  // returns true if a ray from the left of the line to this point
  // intersects the line between these points
  //
  // special rules:
  // 1. rays do not intersect horizontal lines
  // 2. rays intersect the bottom point, but not the top
  bool intersects(Point a, Point b) {
    // nothing crosses a horizontal line (special rule #1)
    if (a.y == b.y)
      return false;

    // point is clearly above or below (special rule #2)
    if (y >= max(a.y, b.y) || y < min(a.y, b.y))
      return false;

    // vertical line
    if (a.x == b.x)
      return x > a.x;

    // determine the y coordinate of the point that shares this x value
    num slope = a.slopeTo(b);
    num yIntercept = a.y - (a.x * slope);

    num y_val = (slope * x) + yIntercept;

    // the other points y coordinate will be larger or smaller than us
    // if the slope is positive or negative respectively
    return (slope > 0) ? y_val > y : y > y_val;
  }
  
  void move(int x, int y) {
    this._x += x;
    this._y += y;
  }
  void offset(int x, int y) {
    this.offsetX += x;
    this.offsetY += y;
  }
  void save() {
    // make the value of x permanent
    this._x = this.x;
    this._y = this.y;

    this.offsetX = 0;
    this.offsetY = 0;

    this._lockX = false;
    this._lockY = false;
  }

  num distanceTo(Point p) {
    num diffX = p.x - this.x;
    num diffY = p.y - this.y;

    return sqrt(diffX*diffX + diffY*diffY);
  }

  num slopeTo(Point p) => (y - p.y) / (x - p.x);

  String toString() => "($x, $y)";
}

class Polygon {
  List<Point> points;
  Color stroke = Color.RED;
  Color fill = Color.BLUE;

  bool _hover = false;
  int _selectedEdge;
  int _selectedPoint;

  int _lockEdge;

  get selected => _hover;
  set selected(v) => _hover = v;

  get selectedEdge => _selectedEdge;
  set selectedEdge(i) {
    if (i != null)
      _selectedPoint = null;
    _selectedEdge = i;
  }

  get selectedPoint => _selectedPoint;
  set selectedPoint(i) {
    if (i != null)
      _selectedEdge = null;
    _selectedPoint = i;
  }

  Polygon(points, {Color stroke, Color fill}) {
    this.points = points;
    if (stroke != null)
      this.stroke = stroke;
    if (fill != null)
      this.fill = fill;
  }
  Polygon.rect(int x, y, w, h, {Color stroke, Color fill}) : this([new Point(x, y), new Point(x, h+y), new Point(w+x, h+y), new Point(w+x, y)], stroke: stroke, fill: fill);

  // uses ray-casting algorithm
  bool contains(Point p) {
    num crosses = 0;
    for (int i = 0; i < points.length; i++) {
      int second = (i + 1) % points.length;

      Point a = points[i];
      Point b = points[second];

      if (p.intersects(a, b)) {
        crosses++;
      }
    }

    return crosses % 2 == 1;
  }

  int onEdge(Point p) {
    int best;
    num bestDistance = double.INFINITY;
    for (int i = 0; i < points.length; i++) {
      int second = (i + 1) % points.length;

      Point a = points[i];
      Point b = points[second];

      num dist;
      if (a.x == b.x) {
        // vertical line; only consider points between the segment end-points
        if (p.y < max(a.y, b.y) && p.y > min(a.y, b.y))
          dist = (p.x - a.x).abs();
      } else if (a.y == b.y) {
        // horizontal line; only consider points between the segment end-points
        if (p.x < max(a.x, b.x) && p.x > min(a.x, b.x))
          dist = (p.y - a.y).abs();
      } else {
        num slope = a.slopeTo(b);
        num yIntercept = a.y - (a.x * slope);

        // TODO: why is this necessary?
        slope *= -1;
        dist = (slope*p.x + p.y - yIntercept).abs() / sqrt(slope*slope + 1);
      }

      if (dist != null && dist < bestDistance) {
        best = i;
        bestDistance = dist;
      }
    }

    return bestDistance <= tolerance ? best : null;
  }

  int onPoint(Point p) {
    int best;
    num bestDistance = double.INFINITY;
    for (int i = 0; i < points.length; i++) {
      num dist = p.distanceTo(points[i]);
      if (dist < bestDistance) {
        best = i;
        bestDistance = dist;
      }
    }

    return bestDistance <= tolerance ? best : null;
  }

  void move(int x, int y) => this.points.forEach((p) => p.move(x, y));
  void offset(int x, int y, [bool lock]) => this.points.forEach((p) => p.offset(x, y));

  void offsetEdge(int edge, int x, int y, [bool lock]) {
    int next = (edge + 1) % points.length;
    Point a = points[edge];
    Point b = points[next];

    if (edge != this._lockEdge && this._lockEdge != null) {
      // unlock old points
      this.points[this._lockEdge]._lockX = false;
      this.points[this._lockEdge]._lockY = false;
      this.points[this._lockEdge+1]._lockX = false;
      this.points[this._lockEdge+1]._lockY = false;
    }
    this._lockEdge = lock ? edge : null;

    // bind to an axis
    if (isVertEdge(edge)) {
      y = 0;
      a._lockX = lock;
      b._lockX = lock;
    } else if (isHorizEdge(edge)) {
      x = 0;
      a._lockY = lock;
      b._lockY = lock;
    } else {
      return print("Illegal edge");
    }

    a.offset(x, y);
    b.offset(x, y);
  }

  void save() {
    this._lockEdge = null;
    this.points.forEach((p) => p.save());
  }

  bool isVertEdge(int edge) => points[edge].x == points[(edge + 1) % points.length].x;
  bool isHorizEdge(int edge) => points[edge].y == points[(edge + 1) % points.length].y;

  void reset() {
    this.selected = false;
    querySelector('canvas').classes.removeWhere((c) => c.startsWith('hover-'));
  }

  void draw(g) {
    g.fillStyle = fill.rgba;
    g.strokeStyle = stroke.rgba;

    g.beginPath();
    g.moveTo(points[0].x, points[0].y);
    points.sublist(1).forEach((p) => g.lineTo(p.x, p.y));
    g.closePath();

    g.fill();
    if (this.selected) {
      g.lineWidth = 3;
    }
    g.stroke();

    if (selectedPoint != null) {
      Point p = points[selectedPoint];
      g.beginPath();
      g.arc(p.x, p.y, tolerance, 0, PI*2);
      g.closePath();
      g.fillStyle = Color.BLACK.rgba;
      g.fill();
    }

    if (selectedEdge != null) {
      int next = (selectedEdge+1) % points.length;
      g.beginPath();
      g.moveTo(points[selectedEdge].x, points[selectedEdge].y);
      g.lineTo(points[next].x, points[next].y);
      g.closePath();
      g.lineWidth = 3;
      g.stroke();
    }
  }
}

class Furniture extends Polygon {
  Furniture(points, {Color stroke, Color fill}) : super(points, stroke: stroke, fill: fill);
}

class Room extends Polygon {
  List<Furniture> furniture = [];

  Room(points, {Color stroke: Color.BLACK, Color fill: Color.TRANSPARENT}) : super(points, stroke: stroke, fill: fill);
  Room.rect(int x, y, w, h, {Color stroke: Color.BLACK, Color fill: Color.TRANSPARENT}) : super.rect(x, y, w, h, stroke: stroke, fill: fill);
}

class Grid {
  Point offset = new Point(0, 0);
  num pixelsPerMeter;
  num metersPerLine;

  Grid({this.pixelsPerMeter: 100, this.metersPerLine: .3, offset}) {
    if (offset != null)
      this.offset = offset;
  }

  // given an x/y pixel and an offset, returns the nearest pixel on the grid
  _nearest(int x, int offset) {
    int gridSize = (pixelsPerMeter * metersPerLine);
    num gridNum = (x - offset) / gridSize;
    num lower = gridNum.floor() * gridSize;
    num upper = gridNum.ceil() * gridSize;

    return (x - lower) / (upper - lower) < 0.5 ? lower : upper;
  }

  nearestX(int x) => _nearest(x, offset.x);
  nearestY(int y) => _nearest(y, offset.y);

  draw(g) {
    g.strokeStyle = 'rgba(0, 0, 0, 0.25)';
    g.lineWidth = 1;
    for (int x = offset.x; x < g.canvas.width; x += pixelsPerMeter*metersPerLine) {
      g.beginPath();
      g.moveTo(x, 0);
      g.lineTo(x, g.canvas.height);
      g.closePath();
      g.stroke();
    }

    for (int y = offset.y; y < g.canvas.height; y += pixelsPerMeter*metersPerLine) {
      g.beginPath();
      g.moveTo(0, y);
      g.lineTo(g.canvas.width, y);
      g.closePath();
      g.stroke();
    }
  }
}

void fillScreen(el) {
  el.width = window.innerWidth;
  el.height = window.innerHeight;
}

void redraw(i) {
  var g = (query('canvas') as CanvasElement).getContext('2d');

  g.clearRect(0, 0, g.canvas.width, g.canvas.height);
  gr.draw(g);
  r.draw(g);

  /*
  var thisLoop = new DateTime.now();
  var fps = 1000 / thisLoop.difference(lastLoop).inMilliseconds;
  if (fps.isFinite) {
    g.font = '14pt sans';
    g.fillStyle = Color.BLACK.rgba;
    g.fillText('FPS: ${fps.round()}', g.canvas.width / 2, g.canvas.height / 2);
  }
  lastLoop = thisLoop;
  */

  window.animationFrame.then(redraw);
}

Point movement(ev) {
  JsObject evnt = new JsObject.fromBrowserObject(ev);
  if (evnt['webkitMovementX'] != null)
    return ev.movement;
  else
    return new Point(evnt['mozMovementX'], evnt['mozMovementY']);
}

void main() {
  bool dragging = false;

  r = new Room.rect(10, 10, 50, 50);
  gr = new Grid();
  querySelectorAll('canvas').forEach(fillScreen);
  window.onResize.listen((ev) => querySelectorAll('canvas').forEach(fillScreen));

  window.onMouseMove.listen((ev) {
      if (dragging)
        return;

      Point p = new Point.fromEvent(ev);

      // TODO: diagonal drag
      /*
      int i = r.onPoint(p);
      if (i != null) {
        querySelector('canvas').classes.add('hover-point');
      } else {
        querySelector('canvas').classes.remove('hover-point');
      }
      r.selectedPoint = i;
      if (i != null) {
        return;
      }
      */

      int i = r.onEdge(p);
      if (i != null) {
        if (r.isVertEdge(i)) {
          querySelector('canvas').classes.add('hover-edge-vert');
          querySelector('canvas').classes.remove('hover-edge-horiz');
        } else if (r.isHorizEdge(i)) {
          querySelector('canvas').classes.add('hover-edge-horiz');
          querySelector('canvas').classes.remove('hover-edge-vert');
        }
      } else {
        querySelector('canvas').classes.remove('hover-edge-horiz');
        querySelector('canvas').classes.remove('hover-edge-vert');
      }
      r.selectedEdge = i;
      if (i != null) {
        r.selected = false;
        return;
      }

      bool hover = r.contains(p);
      if (r.selected != hover) {
        r.selected = hover;
        querySelector('canvas').classes.toggle('hover');
      }
    });
  window.onMouseDown.listen((ev) {
    var sub;

    /*if (r.selectedPoint != null) {
      sub = window.onMouseMove.listen((ev) => r.points[r.selectedPoint].offset(movement(ev).x, movement(ev).y));
    } else */
    if (r.selectedEdge != null) {
      sub = window.onMouseMove.listen((ev) => r.offsetEdge(r.selectedEdge, movement(ev).x, movement(ev).y, ev.ctrlKey));
    } else if (r.selected) {
      sub = window.onMouseMove.listen((ev) => r.offset(movement(ev).x, movement(ev).y, ev.ctrlKey));
    } else {
      return;
    }

    dragging = true;

    window.onMouseUp.take(1).forEach((ev) {
      r.save();
      sub.cancel();
      dragging = false;
    });
  });

  redraw(null);
}