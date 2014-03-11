#!/bin/sh

if [ -e dist/Otto.zip ]; then
  rm -f dist/Otto.zip
fi

(cd dist; zip -y Otto.zip Otto.app)

exit
