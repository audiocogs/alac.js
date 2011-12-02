class Buffer
    constructor: (@data) ->
        @length = @data.length
        
        @timestamp = null
        @duration  = null
        
        @discontinuity = false
    
    @allocate: (size) ->
        return new Buffer(new Uint8Array(size))
    
    copy: () ->
        buffer = new Buffer(new Uint8Array(@data))
        
        buffer.timestamp = @timestamp
        buffer.duration = @duration
        
        buffer.discontinuity = @discontinuity
    

class BufferList
    constructor: () ->
        @buffers = []
        
        @availableBytes = 0
        @availableBuffers = 0
        
        @bufferHighWaterMark = null; @bufferLowWaterMark = null
        @bytesHighWaterMark = null; @bytesLowWaterMark = null
        
        @onLowWaterMarkReached = null; @onHighWaterMarkReached = null
        
        @onLevelChange = null
        
        @endOfList = false
        
        @first = null
    
    copy: () ->
        result = new BufferList()
        
        result.buffers = @buffers.slice(0)
        
        result.availableBytes = @availableBytes
        result.availableBuffers = @availableBuffers
        
        result.endOfList = @endOfList
    
    shift: () ->
        result = @buffers.shift()
        
        @availableBytes -= result.length
        @availableBuffers -= 1
        
        @first = @buffers[0]
        
        return result
    
    push: (buffer) ->
        @buffers.push(buffer)
        
        @availableBytes += buffer.length
        @availableBuffers += 1
        
        @first = buffer unless @first
        
        return this
    
    unshift: (buffer) ->
        @buffers.unshift(buffer)
        
        @availableBytes += buffer.length
        @availableBuffers += 1
        
        @first = buffer
        
        return this
    

Float64 = new ArrayBuffer(8)
Float32 = new ArrayBuffer(4)

FromFloat64 = new Float64Array(Float64)
FromFloat32 = new Float32Array(Float32)

ToFloat64 = new Uint32Array(Float64)
ToFloat32 = new Uint32Array(Float32)

class Stream
    constructor: (@list) ->
        @localOffset = 0; @offset = 0
    
    available: (bytes) ->
        @list.availableBytes > bytes
    
    advance: (bytes) ->
        @localOffset += bytes; @offset += bytes
        
        while @localOffset > @list.first.length
            @localOffset -= @list.first.length
            
            @list.shift()
        
        return this
    
    readUInt32: () ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + 4
            a0 = buffer[@localOffset + 0]
            a1 = buffer[@localOffset + 1]
            a2 = buffer[@localOffset + 2]
            a3 = buffer[@localOffset + 3]
            
            this.advance(4)
        else
            a0 = this.readUInt8()
            a1 = this.readUInt8()
            a2 = this.readUInt8()
            a3 = this.readUInt8()
        
        return ((a0 << 24) >>> 0) + (a1 << 16) + (a2 << 8) + (a3)
    
    peekUInt32: (offset = 0) ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + offset + 4
            a0 = buffer[@localOffset + offset + 0]
            a1 = buffer[@localOffset + offset + 1]
            a2 = buffer[@localOffset + offset + 2]
            a3 = buffer[@localOffset + offset + 3]
        else
            a0 = this.peekUInt8(offset + 0)
            a1 = this.peekUInt8(offset + 1)
            a2 = this.peekUInt8(offset + 2)
            a3 = this.peekUInt8(offset + 3)
        
        return ((a0 << 24) >>> 0) + (a1 << 16) + (a2 << 8) + (a3)
    
    readInt32: () ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + offset + 4
            a0 = buffer[@localOffset + 0]
            a1 = buffer[@localOffset + 1]
            a2 = buffer[@localOffset + 2]
            a3 = buffer[@localOffset + 3]
            
            this.advance(4)
        else
            a0 = this.readUInt8()
            a1 = this.readUInt8()
            a2 = this.readUInt8()
            a3 = this.readUInt8()
        
        return (a0 << 24) + (a1 << 16) + (a2 << 8) + (a3)
    
    peekInt32: (offset = 0) ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + offset + 4
            a0 = buffer[@localOffset + offset + 0]
            a1 = buffer[@localOffset + offset + 1]
            a2 = buffer[@localOffset + offset + 2]
            a3 = buffer[@localOffset + offset + 3]
        else
            a0 = this.peekUInt8(offset + 0)
            a1 = this.peekUInt8(offset + 1)
            a2 = this.peekUInt8(offset + 2)
            a3 = this.peekUInt8(offset + 3)
        
        return (a0 << 24) + (a1 << 16) + (a2 << 8) + (a3)
    
    readUInt16: () ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + 2
            a0 = buffer[@localOffset + 0]
            a1 = buffer[@localOffset + 1]
            
            this.advance(2)
        else
            a0 = this.readUInt8()
            a1 = this.readUInt8()
        
        return (a0 << 8) + (a1)
    
    peekUInt16: (offset = 0) ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + offset + 2
            a0 = buffer[@localOffset + offset + 0]
            a1 = buffer[@localOffset + offset + 1]
        else
            a0 = this.peekUInt8(offset + 0)
            a1 = this.peekUInt8(offset + 1)
        
        return (a0 << 8) + (a1)
    
    readInt16: () ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + 2
            a0 = buffer[@localOffset + 0]
            a1 = buffer[@localOffset + 1]
        else
            a0 = this.readInt8()
            a1 = this.readUInt8()
        
        return (a0 << 8) + (a1)
    
    peekInt16: (offset = 0) ->
        buffer = @list.first.data
        
        if buffer.length > @localOffset + offset + 2
            a0 = buffer[@localOffset + offset + 0]
            a1 = buffer[@localOffset + offset + 1]
        else
            a0 = this.peekInt8(offset + 0)
            a1 = this.peekUInt8(offset + 1)
        
        return (a0 << 8) + (a1)
    
    readUInt8: () ->
        a0 = @list.first.data[@localOffset]
        
        @localOffset += 1; @offset += 1
        
        if @localOffset == @list.first.length
            @localOffset = 0; @buffers.shift()
        
        return a0
    
    peekUInt8: (offset = 0) ->
        offset = @localOffset + offset
        
        i = 0; buffer = @list.buffers[i].data
        
        until buffer.length > offset + 1
            offset -= buffer.length
            buffer = @list.buffers[++i].data
        
        return buffer[offset]
    
    readInt8: () ->
        a0 = ((@list.first.data[@localOffset] << 24) >> 24)
        
        @localOffset += 1; @offset += 1
        
        if @localOffset == @list.first.length
            @localOffset = 0; @buffers.shift()
        
        return a0
    
    peekUInt8: (offset = 0) ->
        offset = @localOffset + offset
        
        i = 0; buffer = @list.buffers[i].data
        
        until buffer.length > offset + 1
            offset -= buffer.length
            buffer = @list.buffers[++i].data
        
        return buffer[offset]
    
    readFloat64: () ->
        ToFloat64[1] = this.readUInt32()
        ToFloat64[0] = this.readUInt32()
        
        return FromFloat64[0]
    
    readFloat32: () ->
        ToFloat32[0] = this.readUInt32()
        
        return FromFloat32[0]
    
    readString: (length) ->
        result = []
        
        for i in [0 ... length]
            result.push(String.fromCharCode(this.readUInt8()))
        
        return result.join('')
    
    readBuffer: (length) ->
        result = Buffer.allocate(length)
        
        to = result.data
        
        offset = 0
        buffer = @list.first.data
        
        until length - offset < buffer.length - @localOffset
            for i in [@localOffset ... buffer.length] by 1
                to[offset - @localOffset + i] = buffer[i]
            
            offset += buffer.length - @localOffset
            
            this.advance(buffer.length - @localOffset)
            
            buffer = @list.first.data; @localOffset = 0
        
        for i in [@localOffset ... @localOffset + length - offset] by 1
            to[offset - @localOffset + i] = buffer[i]
        
        @localOffset = length - offset
        
        return result
    

window.Aurora = {} unless window.Aurora

window.Aurora.Buffer = Buffer
window.Aurora.BufferList = BufferList
window.Aurora.Stream = Stream
