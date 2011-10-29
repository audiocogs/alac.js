class Data
    constructor: (@data) ->
        @pos = 0
        @length = @data.length
                
    readByte: ->
        @data[@pos++]
        
    byteAt: (index) ->
        @data[index]
        
    readUInt32: ->
        b1 = @readByte() << 24 >>> 0
        b2 = @readByte() << 16
        b3 = @readByte() << 8
        b4 = @readByte()
        b1 + (b2 | b3 | b4)
    
    readInt32: ->
        int = @readUInt32()
        if int >= 0x80000000 then int - 0x100000000 else int
        
    readUInt16: ->
        b1 = @readByte() << 8
        b2 = @readByte()
        b1 | b2
        
    readInt16: ->
        int = @readUInt16()
        if int >= 0x8000 then int - 0x10000 else int
        
    readUInt8: ->
        @readByte()
        
    readInt8: ->
        @readByte()
        
    readString: (length) ->
        ret = []
        for i in [0...length]
            ret[i] = String.fromCharCode @readByte()
            
        return ret.join ''
                
    slice: (start, end) ->
        @data.slice start, end
        
    read: (bytes) ->
        buf = []
        for i in [0...bytes]
            buf.push @readByte()
            
        return buf
        
module.exports = Data