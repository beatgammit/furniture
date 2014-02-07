#!/bin/sh

rm -rf build

if ! dartanalyzer web/main.dart; then
	echo "Did not pass lint, refusing to build"
	exit 1
fi

pub build $@

jade web/index.jade -o build
lessc web/main.less > build/main.css

rm -f build/*.jade build/*.less
