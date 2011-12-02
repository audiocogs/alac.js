class CAFDemuxer
    constructor: (@name) ->
        @inputs = {
            data:
                send: (buffer) => this.enqueueBuffer(buffer)
                mode: "Passive"
        }
        
        @outputs = {
            
        }
        
        @list = new BufferList()
        
        @stream = new Stream(@list)
        
        @metadata = null
        @headerCache = null
        @packetCache = null
        
        @magic = null
        
        this.reset()
    
    enqueueBuffer: (buffer) ->
        @list.push(buffer)
        
        if !@metadata && @stream.available(64) # Number out of my behind
            if @stream.readString(4) != 'caff'
                console.log("Invalid CAF, does not begin with 'caff'"); debugger
            
            @metadata = {}
            
            @metadata.caff = {
                version:            @stream.readUInt16()
                flags:              @stream.readUInt16()
            }
            
            if @stream.readString(4) != 'desc'
                console.log("Invalid CAF, 'caff' is not followed by 'desc'"); debugger
            
            unless @stream.readUInt32() == 0 && @stream.readUInt32() == 32
                console.log("Invalid 'desc' size, should be 32"); debugger
            
            @metadata.desc = {
                sampleRate:         @stream.readFloat64()
                formatID:           @stream.readString(4)
                formatFlags:        @stream.readUInt32()
                bytesPerPacket:     @stream.readUInt32()
                framesPerPacket:    @stream.readUInt32()
                channelsPerFrame:   @stream.readUInt32()
                bitsPerChannel:     @stream.readUInt32()
            }
            
            if @metadata.desc.formatID != 'alac'
                console.log("Right now we only support Apple Lossless audio"); debugger
            
            @outputs.metadata.send({
                format:
                    format:             "Apple Lossless"
                    samplingFrequency:  @metadata.desc.sampleRate
                    bytesPerPacket:     @metadata.desc.bytesPerPacket
                    framesPerPacket:    @metadata.desc.framesPerPacket
                    channelsPerFrame:   @metadata.desc.channelsPerFrame
                    bitsPerChannel:     @metadata.desc.bitsPerChannel
            })
        
        if !@metadata && buffer.final
            console.log("Not enough data in file for CAF header"); debugger
        
        while (@headerCache && @stream.available(1)) || @stream.available(13)
            unless @headerCache
                @headerCache = {
                    type:               @stream.readString(4)
                    oversize:           @stream.readUInt32() != 0
                    size:               @stream.readUInt32()
                }
            
            if @headerCache.oversize
                console.log("Holy Shit, an oversized file, not supported in JS"); debugger
            
            size = @headerCache.size
            
            switch @headerCache.type
                when 'kuki'
                    if @stream.available(@headerCache.size)
                        buffer = @stream.readBuffer(@headerCache.size)
                        
                        buffer.final = true
                        
                        @outputs.cookie.send(buffer)
                        
                        @headerCache = null
                    else
                        return
                when 'data'
                    buffer = @stream.readSingleBuffer(@headerCache.size)
                    
                    @headerCache.size -= buffer.length
                    
                    if @headerCache.size <= 0
                        @headerCache = null
                        buffer.final = true
                    
                    @outputs.data.send(buffer)
                else
                    if @stream.available(@headerCache.size)
                        @stream.advance(@headerCache.size)
                        
                        @headerCache = null
                    else
                        return
                
            
        
        this.finished() if buffer.final
        
        return
    
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

window.Aurora.CAFDemuxer = CAFDemuxer
