#!/bin/sh

rm -rf build/scan bin/scan
pyinstaller --onefile scan.spec

exit

