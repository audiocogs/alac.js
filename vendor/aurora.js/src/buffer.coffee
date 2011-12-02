class Buffer
    constructor: (@data) ->
        @length = @data.length
        
        @timestamp = null
        @duration  = null
        
        @final = false
        @discontinuity = false
    
    @allocate: (size) ->
        return new Buffer(new Uint8Array(size))
    
    copy: () ->
        buffer = new Buffer(new Uint8Array(@data))
        
        buffer.timestamp = @timestamp
        buffer.duration = @duration
        
        buffer.final = @final
        buffer.discontinuity = @discontinuity
    
    slice: (position, length) ->
        if position == 0 && length >= @length
            return this
        else
            return new Buffer(@data.subarray(position, length))
        
    

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
    
    copy: () ->
        result = new Stream(@list.copy)
        
        result.localOffset = @localOffset
        result.offset = @offset
        
        return result
    
    available: (bytes) ->
        @list.availableBytes > bytes
    
    advance: (bytes) ->
        @localOffset += bytes; @offset += bytes
        
        while @list.first && (@localOffset >= @list.first.length)
            @localOffset -= @list.shift().length
        
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
        
        this.advance(1)
        
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
        
        for i in [0 ... length]
            to[i] = this.readUInt8()
        
        return result
    
    readSingleBuffer: (length) ->
        result = @list.first.slice(@localOffset, length)
        
        this.advance(result.length)
        
        return result
    

TWO_32 = Math.pow(2, 32)
TWO_24 = Math.pow(2, 24)
TWO_16 = Math.pow(2, 16)
TWO_8  = Math.pow(2, 8)

class Bitstream
    constructor: (@stream) ->
        @bitPosition = 0
    
    copy: () ->
        result = new Bitstream(@stream.copy())
        
        result.bitPosition = @bitPosition
        
        return result
    
    available: (bits) ->
        return @stream.available((bits + 8 - @bitPosition) / 8)
    
    advance: (bits) ->
        @bitPosition += bits
        
        @stream.advance(@bitPosition >> 3)
        
        @bitPosition = @bitPosition & 7
        
        return this
    
    align: ->
        unless @bitPosition == 0
            @bitPosition = 0
            
            @stream.advance(1)
        
        return this
    
    readBig: (bits) ->
        a = @stream.peekUInt8(0) * TWO_32 +
            @stream.peekUInt8(1) * TWO_24 +
            @stream.peekUInt8(2) * TWO_16 +
            @stream.peekUInt8(3) * TWO_8 +
            @stream.peekUInt8(4) + 
        
        a = (a % Math.pow(2, 40 - @pos))
        a = (a / Math.pow(2, 40 - @pos - bits))
        
        this.advance(bits)
        
        return ((a << 32 - bits) >> bits)
    
    peekBig: (bits) ->
        a = @stream.peekUInt8(0) * TWO_32 +
            @stream.peekUInt8(1) * TWO_24 +
            @stream.peekUInt8(2) * TWO_16 +
            @stream.peekUInt8(3) * TWO_8 +
            @stream.peekUInt8(4) + 
        
        a = (a % Math.pow(2, 40 - @pos))
        a = (a / Math.pow(2, 40 - @pos - bits))
        
        return (a << 0)
    
    read: (bits) ->
        a = (@stream.peekUInt8(0) << 16) +
            (@stream.peekUInt8(1) <<  8) +
            (@stream.peekUInt8(2) <<  0)
        
        this.advance(bits)
        
        return (((a << @pos) & 0xFFFF) >>> (24 - bits))
    
    readSmall: (bits) ->
        a = (@stream.peekUInt8(0) << 8) +
            (@stream.peekUInt8(1) << 0)
        
        this.advance(bits)
        
        return (((a << @pos) & 0xFF) >>> (16 - bits))
    
    readOne: ->
        a = @stream.peekUInt8(0)
        
        this.advance(1)
        
        return (a >>> (7 - @pos)) & 0x01
    

window.Aurora = {} unless window.Aurora

window.Aurora.Buffer = Buffer
window.Aurora.BufferList = BufferList

window.Aurora.Stream = Stream
window.Aurora.Bitstream = Bitstream
