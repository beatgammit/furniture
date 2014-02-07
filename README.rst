=========
Furniture
=========

This is a simple furniture organization webapp licensed under the AGPL.

The current feature-set includes:

- create room (with simple draw tool)
- add furniture
- resize room/furniture and move furniture

This is a work in progress, so please stay tuned.

Installation
============

Dependencies:

- jade_
- less_
- dart_ - (just sdk)
- go_ - (to run server)

Run ``build.sh`` to compile everything. By default, Dart code is compiled to Javascript *without* copying the original Dart code.

To copy the original Dart code, run: ``build.sh --mode dev``.

An example server is provided. To run it, just run: ``go run server.go``. The server currently only serves files from ``build/``,
so any webserver will do.

.. _dart: https://www.dartlang.org
.. _jade: https://github.com/visionmedia/jade
.. _less: http://www.lesscss.org/
.. _go: http://golang.org/
