alac.js: An Apple Lossless decoder in the browser
================================================================================

## How to run the development server

If alac.js isn't already on a web server, you can start a simple Rack server:

    thin -R static.ru start
    
Currently, the [import](https://github.com/devongovett/import) module is used to build alac.js.  You can run
the development server by first installing import with npm, and then running it like this:

    sudo npm install import
    import Aurora/aurora.coffee
    
You can also build a static version like this:

    import Aurora/aurora.coffee alac.js

## Browser Support

Currently, alac.js works properly in the latest versions of Firefox and Chrome.