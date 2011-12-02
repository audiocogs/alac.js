class HTTPSource
    constructor: (@name) ->
        @chunkSize = (1 << 20)
        
        @outputs = {}
        
        this.reset()
    
    start: () ->
        @status = "Started"
        
        unless @length
            if @inflight
                console.log("Should never be here, something is seriously wrong"); debugger
            
            @inflight = true
            
            @xhr = new XMLHttpRequest()
            
            onLoad = (event) =>
                @length = parseInt(@xhr.getResponseHeader("Content-Length"))
                
                @inflight = false
                
                return this.loop()
            
            onError = (event) =>
                console.log("HTTP Error when requesting length: ", event)
                
                @inflight = false
                
                this.pause()
                
                @messagebus.send(this, @name, "ERROR", "Source paused, failed to get length of file")
                
                return
            
            onAbort = (event) =>
                console.log("HTTP Aborted: Paused?")
                
                @inflight = false
                
                return
            
            @xhr.addEventListener("load", onLoad, false);
            @xhr.addEventListener("error", onError, false);
            @xhr.addEventListener("abort", onAbort, false);
            
            @xhr.open("HEAD", @url, true)
            
            @xhr.send(null)
        
        return this
        
        if @inflight
            console.log("Should never get here, unless you're starting a stream with in-flight requests"); debugger
            
        return this.loop()
    
    pause: () ->
        @status = "Paused"
        
        if @inflight
            @xhr.abort()
            
            @inflight = false
        
        return this
    
    reset: () ->
        @status = "Paused"
        
        @xhr.abort() if @inflight
        
        @offset = 0
        @inflight = false
        
        return this
    
    finished: () ->
        @status = "Finished"
        
        return this
    
    loop: () ->
        if @inflight
            console.log("Should never be here, unless a loop is failing"); debugger
        
        if @offset == @length
            return this.finished()
        
        @inflight = true
        
        @xhr = new XMLHttpRequest()
        
        onLoad = (event) =>
            buffer = new Buffer(new Uint8Array(@xhr.response))
            
            @offset += buffer.length
            
            buffer.final = true if @offset == @length
            
            @outputs.data.send(buffer)
            
            @inflight = false
            
            console.log("HTTP Finished: #{@name} (offset #{@offset >> 10} kB, length #{buffer.length >> 10} kB)")
            
            return this.loop()
        
        onError = (event) =>
            console.log("HTTP Error: ", event)
            
            @inflight = false
            
            this.pause()
            
            @messagebus.send(this, @name, "ERROR", "Source paused, errror sending HTTP request")
            
            return
        
        onAbort = (event) =>
            console.log("HTTP Aborted: Paused?")
            
            @inflight = false
            
            return
        
        @xhr.addEventListener("load", onLoad, false);
        @xhr.addEventListener("error", onError, false);
        @xhr.addEventListener("abort", onAbort, false);
        
        @xhr.open("GET", @url, true)
        
        @xhr.responseType = "arraybuffer"
        @xhr.setRequestHeader("Range", "bytes=#{@offset}-#{Math.min(@offset + @chunkSize, @length)}");
        
        @xhr.send(null)
        
        return this
    

window.Aurora = {} unless window.Aurora

window.Aurora.HTTPSource = HTTPSource
