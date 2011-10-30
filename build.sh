#!/bin/sh

if [ ! -d "vendor" ]; then
  mkdir vendor
fi

if [ ! -d "vendor/core.js" ]; then
  git clone https://github.com/JensNockert/core.js.git vendor/core.js
fi

cd vendor/core.js && git pull && cd ../..

coffee --join lib/alac.js --compile src/*.coffee
