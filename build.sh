#!/bin/sh

rm -rf build

pub build $@

jade web/index.jade -o build
lessc web/main.less > build/main.css

rm build/*.jade build/*.less
