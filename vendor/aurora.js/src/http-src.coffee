class HTTPSource
    constructor: (@name) ->
        @chunkSize = (1 << 20)
        @outputs = {}
        @inflight = false
        @reset()
    
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
        @xhr = new XMLHttpRequest()
        
        @xhr.onload = (event) =>
            if @xhr.response
                buf = new Uint8Array(@xhr.response)
            else
                txt = @xhr.responseText
                buf = new Uint8Array(txt.length)
                for i in [0...txt.length]
                    buf[i] = txt.charCodeAt(i) & 0xff
            
            buffer = new Buffer(buf)
            @offset += buffer.length
            buffer.final = true if @offset == @length
            
            @outputs.data.send(buffer)
            @inflight = false
            @loop()
        
        @xhr.onerror = (event) =>
            console.log("HTTP Error: ", event)
            @pause()
        
        @xhr.onabort = (event) =>
            console.log("HTTP Aborted: Paused?")
            @inflight = false
               
        @xhr.open("GET", @url, true)
        @xhr.responseType = "arraybuffer"
        
        endPos = Math.min(@offset + @chunkSize, @length)
        @xhr.setRequestHeader("Range", "bytes=#{@offset}-#{endPos}")
        @xhr.overrideMimeType('text/plain; charset=x-user-defined')
        @xhr.send(null)
                
        return this

this.Aurora ||= {}
this.Aurora.HTTPSource = HTTPSource