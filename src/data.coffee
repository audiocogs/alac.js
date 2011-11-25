#
#  Original C(++) version by Apple, http://alac.macosforge.org/
#
#  Javascript port by Jens Nockert and Devon Govett of OFMLabs, https://github.com/ofmlabs/alac.js
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

class Data
    window.Data = Data

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

    readUInt64: ->
        # TODO: fix for files larger than 2GB
        @readUInt32() * 0x100000000 + @readUInt32()

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

    readFloat: ->
        num = @readUInt32()
        return 0.0 if not num or num is 0x80000000 # 0.0 or -0.0

        sign = (num >> 31) * 2 + 1 # +1 or -1
        exp = (num >> 23) & 0xff
        frac =  num & 0x7fffff

        # NaN or Infinity
        if exp is 0xff
            return if frac then NaN else sign * Infinity

        return sign * (frac | 0x00800000) * Math.pow(2, exp - 127 - 23)

    readDouble: ->
        high = @readUInt32()
        low = @readUInt32()

        return 0.0 if not high or high is 0x80000000 # 0.0 or -0.0

        sign = (high >> 31) * 2 + 1 # +1 or -1
        exp = (high >> 20) & 0x7ff
        frac = high & 0xfffff

        # NaN or Infinity
        if exp is 0x7ff
            return if frac then NaN else sign * Infinity

        return sign * ((frac | 0x100000) * Math.pow(2, exp - 1023 - 20) + low * Math.pow(2, exp - 1023 - 52))

    readString: (length) ->
        ret = []
        for i in [0...length]
            ret[i] = String.fromCharCode @readByte()

        return ret.join ''

    stringAt: (pos, length) ->
        p = @pos
        @pos = pos
        ret = @readString length
        @pos = p
        return ret

    slice: (start, end) ->
        @data.subarray(start, end)

    read: (bytes) ->
        buf = []
        for i in [0...bytes]
            buf.push @readByte()

        return buf

    types =
        'uint8'  : 'UInt8'
        'uint16' : 'UInt16'
        'uint32' : 'UInt32'
        'uint64' : 'UInt64'
        'int8'   : 'Int8'
        'int16'  : 'Int16'
        'int32'  : 'Int32'
        'float'  : 'Float'
        'float32': 'Float'
        'double' : 'Double'
        'float64': 'Double'

    struct: (properties) ->
        out = {}

        for key, val of properties
            if val.slice(0, 7) is 'string['
                out[key] = @readString +val.slice(7, -1)
            else
                out[key] = this['read' + types[val]]()

        return out

class BitBuffer
    window.BitBuffer = BitBuffer

    constructor: (@data) ->
        @pos = 0 # bit position
        @offset = 0 # byte offset
        @length = @data.length * 8

    readBig: (bits) ->
        a = (@data[@offset + 0] * Math.pow(2, 32)) +
            (@data[@offset + 1] * Math.pow(2, 24)) +
            (@data[@offset + 2] * Math.pow(2, 16)) +
            (@data[@offset + 3] * Math.pow(2, 8)) +
            (@data[@offset + 4] * Math.pow(2, 0))
        
        a = (a % Math.pow(2, 40 - @pos))
        a = (a / Math.pow(2, 40 - @pos - bits))
        
        @advance(bits)
        
        return a << 0
    
    read: (bits) ->
        a = (@data[@offset + 0] << 16) +
            (@data[@offset + 1] <<  8) +
            (@data[@offset + 2] <<  0)
        
        a = (a << @pos) & 0xFFFFFF
        
        @advance(bits)
        
        return (a >>> (24 - bits))

    # Reads up to 8 bits
    readSmall: (bits) ->
        a = (@data[@offset + 0] <<  8) +
            (@data[@offset + 1] <<  0)
        
        a = (a << @pos) & 0xFFFF
        
        @advance(bits)
        
        return (a >>> (16 - bits))
    
    peekBig: (bits) ->
        v = this.readBig(bits)
        
        this.rewind(bits)
        
        return v
    
    advance: (bits) ->
        @pos += bits
        @offset += (@pos >> 3)
        @pos &= 7
    
    rewind: (bits) ->
        this.advance(-bits)
    
    align: () ->
        if @pos != 0
            this.advance(8 - @pos)
        
    
    copy: ->
        bit = new BitBuffer(@data)
        bit.pos = @pos
        bit.offset = @offset
        return bit