class AuroraALACDecoder
    constructor: (@name) ->
        @inputs = {
            metadata:
                send: (object) => this.setMetadata(object)
                mode: "Passive"
            cookie:
                send: (buffer) => this.setCookie(buffer)
                mode: "Passive"
            data:
                send: (buffer) => this.enqueueBuffer(buffer)
                mode: "Passive"
        }
        
        @outputs = {
            
        }
        
        @list = new Aurora.BufferList()
        
        @stream = new Aurora.Stream(@list)
        @bitstream = new Aurora.Bitstream(@stream)
        
        @decoder = null
        @metadata
        
        @packetsDecoded = 0
        
        this.reset()
    
    setMetadata: (object) ->
        @metadata = object
        
        return this
    
    setCookie: (buffer) ->
        @decoder = new ALACDecoder(buffer)
        
        this.enqueueBuffer(null)
        
        return
    
    enqueueBuffer: (buffer) ->
        @list.push(buffer) if buffer
        
        if @decoder
            while (@bitstream.available(32) && buffer && buffer.final) || @bitstream.available(4096 << 6) # TODO: Number picked by my behind
                out = @decoder.decode(@bitstream, @metadata.format.framesPerPacket, @metadata.format.channelsPerFrame);
                
                if out[0] != 0
                    console.log("Error in ALAC (#{out[0]})"); debugger
                
                if out[1]
                    result = new Aurora.Buffer(new Uint8Array(out[1]))
                    
                    result.duration  = @metadata.format.framesPerPacket / @metadata.format.samplingFrequency * 1e9
                    result.timestamp = @packetsDecoded * result.duration
                    
                    result.final = (@bitstream.availableBytes == 0)
                    
                    @packetsDecoded += 1
                    
                    unless @bitstream.available(64) # TODO: Number picked by my behind
                        result.final = true
                    
                    @outputs.audio.send(result)
                
            
        
    
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
    

this.Aurora = {} unless this.Aurora

this.Aurora.ALACDecoder = AuroraALACDecoder
