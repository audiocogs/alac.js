#
#  Original C(++) version by Apple, http://alac.macosforge.org/
#
#  Javascript port by Jens Nockert and Devon Govett of OFMLabs, https://github.com/ofmlabs/alac
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
        
    readString: (length) ->
        ret = []
        for i in [0...length]
            ret[i] = String.fromCharCode @readByte()
            
        return ret.join ''
                
    slice: (start, end) ->
        @data.subarray(start, end)
        
    read: (bytes) ->
        buf = []
        for i in [0...bytes]
            buf.push @readByte()
            
        return buf