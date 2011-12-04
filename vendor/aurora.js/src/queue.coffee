class Queue
    constructor: (@name) ->
        @highwaterMark = 256
        @lowwaterMark = 64
        
        @finished = false
        @buffering = true
        
        @onHighwaterMark = null
        @onLowwaterMark = null
        
        @buffers = []
        
        @inputs = {
            contents:
                send: (buffer) => this.enqueueBuffer(buffer)
                mode: "Passive"
            
        }
        
        @outputs = {
            contents:
                receive: () => this.dequeueBuffer()
                mode: "Pull"
            
        }
        
        this.reset()
    
    enqueueBuffer: (buffer) ->
        @buffers.push(buffer)
        
        console.log(@buffers.length) if @buffers.length % 64 == 0
        
        if @buffering
            if @buffers.length >= @highwaterMark || buffer.final
                @onHighwaterMark(@buffers.length) if @onHighwaterMark
                
                @buffering = false
            
        
        return this
    
    dequeueBuffer: () ->
        result = @buffers.shift()
        
        unless @buffering
            if @buffers.length < @lowwaterMark
                @onLowwaterMark(@buffers.length) if @onLowwaterMark
            
        
        return result
    
    start: () ->
        @status = "Started"
        
        return this
    
    pause: () ->
        @status = "Paused"
        
        return this
    
    reset: () ->
        @status = "Paused"
        
        return this
    
    finished: () ->
        @status = "Finished"
        
        return this
    

window.Aurora = {} unless window.Aurora

window.Aurora.Queue = Queue
