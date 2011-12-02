class CAFDemuxer
    constructor: (@name) ->
        @chunkSize = (1 << 20)
        
        @inputs = {
            data:
                send: (buffer) => this.enqueueBuffer(buffer)
                finished: () => this.finished()
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
            
        
        while @headerCache || @stream.available(12)
            if !@headerCache
                @headerCache = {
                    type:               @stream.readString(4)
                    oversize:           @stream.readUInt32() != 0
                    size:               @stream.readUInt32()
                }
            
            console.log(@headerCache.type, @headerCache.size, @stream.localOffset)
            
            if @headerCache.oversize
                console.log("Holy Shit, an oversized file, not supported in JS"); debugger
            
            size = @headerCache.size
            
            switch @headerCache.type
                when 'kuki'
                    if @stream.available(@headerCache.size)
                        @outputs.cookie.send(@stream.readBuffer(@headerCache.size))
                        
                        @headerCache = null
                when 'data'
                    while @headerCache # Fixme into no-copy version
                        return unless @list.first
                        
                        if @stream.localOffset + @headerCache.size > @list.first.length
                            buffer = @list.shift()
                            
                            @outputs.data.send(buffer.slice(@stream.localOffset))
                            
                            @headerCache.size -= buffer.length - @stream.localOffset; @stream.localOffset = 0
                        else
                            buffer = @list.first
                            
                            @outputs.data.send(buffer.slice(@stream.localOffset, @headerCache.size))
                            
                            @stream.localOffset += @headerCache.size; @headerCache = null
                        
                    
                else
                    if @stream.available(@headerCache.size)
                        @stream.advance(@headerCache.size)
                        
                        @headerCache = null
                    
                
            
        
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
