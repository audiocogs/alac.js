alac.js: An Apple Lossless decoder in the browser
================================================================================

The Apple Lossless Audio Codec (ALAC) is an audio codec developed by Apple and included in the original iPod.
ALAC is a data compression method which reduces the size of audio files with no loss of information.
A decoded ALAC stream is bit-for-bit identical to the original uncompressed audio file.

The original encoder and decoder were recently [open sourced](http://alac.macosforge.org/) by Apple, 
and this is a port of the decoder to CoffeeScript so that ALAC files can be played in the browser.

## Demo

You can check out a [demo](http://codecs.ofmlabs.org/) alongside [jsmad](http://github.com/nddrylliog/jsmad), the 
JavaScript MP3 decoder.  Currently, alac.js works properly in the latest versions of Firefox and Chrome.

## Authors

alac.js was written by [@jensnockert](http://github.com/jensnockert) and [@devongovett](http://github.com/devongovett) 
of [ofmlabs](http://ofmlabs.org/).

## How to run the development server

If alac.js isn't already on a web server, you can start a simple Rack server:

    thin -R static.ru start
    
Currently, the [import](https://github.com/devongovett/import) module is used to build alac.js.  You can run
the development server by first installing import with npm, and then running it like this:

    sudo npm install import
    import Aurora/aurora.coffee
    
You can also build a static version like this:

    import Aurora/aurora.coffee alac.js
    
## License

alac.js is released under the same terms as the original ALAC decoder from Apple, which is the 
[Apache 2](http://www.apache.org/licenses/LICENSE-2.0) license.