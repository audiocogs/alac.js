#!/bin/sh

coffee --join lib/alac.js --compile src/*.coffee
coffee --join lib/aurora.js --compile vendor/aurora.js/src/*.coffee
