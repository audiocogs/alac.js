class HTTPWorker
    BlobBuilder = window.BlobBuilder or window.WebKitBlobBuilder or window.MozBlobBuilder
    URL = window.URL or window.webkitURL
    
    constructor: (doLoop) ->
        @events = {}
        
        bb = new BlobBuilder()
        bb.append 'var emit = ' + emit
        bb.append '\n\n'
        
        bb.append 'var doLoop = ' + doLoop
        bb.append '\n\n'
        
        bb.append 'this.onmessage = ' + onmessage
        bb.append '\n\n'
        
        url = URL.createObjectURL(bb.getBlob())
        @worker = new Worker(url)
        @worker.onmessage = (e) =>
            @emit e.data...
        
    onmessage = (e) ->
        if e.data[0] == 'loop'
            doLoop Array.prototype.slice.call(e.data, 1)...
        
    emit =  ->
        postMessage Array.prototype.slice.call(arguments)
        
    run: (args...) ->
        @worker.postMessage ['loop'].concat(args)
        
    on: (evt, fn) ->
        @events[evt] ?= []
        @events[evt].push(fn)
        
    off: (evt, fn) ->
        events = @events[evt]
        return unless events
        
        index = events.indexOf(fn)
        events.splice(index, 1) if ~index
        
    once: (evt, fn) ->
        @on evt, fun = =>
            @off evt, fun
            fn arguments...
        
    emit: (evt, args...) ->
        events = @events[evt]
        return unless events
        
        for fn in events
            fn args...
            
        return

class HTTPSource
    constructor: (@name) ->
        @chunkSize = (1 << 20)
        @outputs = {}
        @inflight = false
        @reset()
        @worker = new HTTPWorker(workerLoop)
    
    start: ->
        if @inflight
            return @loop()
        
        @status = "Started"
        
        @inflight = true
        @xhr = new XMLHttpRequest()
        
        @xhr.onload = (event) =>
            @length = parseInt(@xhr.getResponseHeader("Content-Length"))
            @inflight = false
            @loop()
        
        @xhr.onerror = (event) =>
            console.log("HTTP Error when requesting length: ", event)
            
            @pause()
            @messagebus.send(this, @name, "ERROR", "Source paused, failed to get length of file")
            
        @xhr.onabort = (event) =>
            console.log("HTTP Aborted: Paused?")
            @inflight = false
        
        @xhr.open("HEAD", @url, true)
        @xhr.send(null)
        
        return this
    
    pause: ->
        @status = "Paused"
        
        if @inflight
            @xhr.abort() if @xhr
            @inflight = false
        
        return this
    
    reset: ->
        @pause()
        @offset = 0
        return this
    
    finished: ->
        @status = "Finished"
        @inflight = false
        return this
        
    loop: ->
        if @inflight or not @length
            console.log("Should never be here, unless a loop is failing")
            debugger
            
        if @offset == @length
            return @finished()
        
        @inflight = true
        
        @worker.once 'load', (response) =>
            #console.log(response)
            
            buffer = new Buffer(response)
            @offset += buffer.length
            buffer.final = true if @offset == @length
            
            @outputs.data.send(buffer)
            @inflight = false
            @loop()
            
        @worker.once 'error', =>
            console.log("HTTP Error: ", event)
            @pause()
            
        @worker.once 'abort', =>
            console.log("HTTP Aborted: Paused?")
            @inflight = false
        
        endPos = Math.min(@offset + @chunkSize, @length)
        @worker.run(@url, @offset, endPos)
        
        return this
        
    workerLoop = (url, start, end) ->
        xhr = new XMLHttpRequest()
        
        xhr.onload = (event) =>
            emit 'load', new Uint8Array(xhr.response)
        
        xhr.onerror = (event) =>
            emit 'error'
        
        xhr.onabort = (event) =>
            emit 'abort'
               
        xhr.open("GET", url, true)
        xhr.responseType = "arraybuffer"
        xhr.setRequestHeader("Range", "bytes=#{start}-#{end}");
        
        xhr.send(null)

window.Aurora ||= {}
window.Aurora.HTTPSource = HTTPSource