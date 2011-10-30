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

# File: ag_dec.coffee
# Contains: Adaptive Golomb decode routines.

class Aglib
    PB0 = 40
    MB0 = 10
    KB0 = 14
    MAX_RUN_DEFAULT = 255
    MAX_PREFIX_16 = 9
    MAX_PREFIX_32 = 9

    lead = (m) ->
        c = 1 << 31
    
        for i in [0...32]
            return i if c & m isnt 0
            c = c >> 1
    
        return 32
        
    lg3a = (x) ->
        31 - lead(x + 3)

    read = (buffer, offset) ->
        (buffer[0] << 24 >>> 0) + ((buf[1] << 16) | (buf[2] << 8) | buf[3])

    get_next = (input, suff) ->
        input >> (32 - suff)

    get_stream_bits = (input, offset, bits) ->
        byteoffset = offset / 8
        input_a = new Uint8Array(input)
        load1 = read(input, byteoffset)
    
        if (bits + (offset & 0x7)) > 32
            result = load1 << (bitoffset & 0x7)
            load2 = input_a[byteoffset + 4]
            load2shift = (8 - (bits + (offset & 0x7) - 32))
        
            load2 >>= load2shift
            result >>= (32 - bits)
            result |= load2
            
        else
            result = load1 >> (32 - numbits - (bitoffset & 7))
    
        return result

    dyn_get_16 = (input, pos, m, k) ->
        input_a = new Uint8Array(input)

        tempbits = new Uint32Array(input)[pos]
        stream = read(input, tempbits >> 3) << (tempbits & 7)
        pre = lead(~stream)

        if pre >= MAX_PREFIX_16
            pre = MAX_PREFIX_16
            tempbits += pre
            
            stream <<= pre
            result = get_next(stream, MAX_DATATYPE_BITS_16)

            tempbits += MAX_DATATYPE_BITS_16
            
        else
            tempbits += pre + 1

            stream <<= pre + 1
            v = get_next(stream, k)

            tempbits += k
            result = pre * m + v - 1

            if v < 2
                result -= (v - 1)
                tempbits -= 1


        return [result, pos]

    dyn_get_32 = (input, pos, m, k, maxbits) ->
        input_a = Uint8Array(input)

        tempbits = new Uint32Array(input)[pos]
        stream = read(input, tempbits >> 3)
        stream = stream << (tempbits & 0x7)

        result = lead(~stream)

        if result >= MAX_PREFIX_32
            result = get_stream_bits(input, tempbits + MAX_PREFIX_32, maxbits)
            tempbits += MAX_PREFIX_32 + maxbits
            
        else
            tempbits += result + 1

            if k isnt 1
                stream <<= result + 1
                v = get_next(stream, k)

                tempbits += k - 1
                result = result * m

                if v >= 2
                    result += v - 1
                    tempbits += 1



        return [result, pos]
        
    @standard_ag_params: (fullwidth, sectorwidth) ->
        @ag_params(MB0, PB0, KB0, fullwidth, sectorwidth, MAX_RUN_DEFAULT)

    @ag_params: (m, p, k, f, s, maxrun) ->
        mb:  m
        mb0: m
        pb:  p
        kb:  k
        wb:  (1 << k) - 1
        qb:  QB - p
        fw:  f
        sw:  s
        maxrun: maxrun
        
    @dyn_decomp: (params, bitstream, pc, samples, size) ->
        {pb, kb, wb, mb0:mb} = params

        unless bitstream and pc
            return ALAC.errors.paramError
        
        {cur:input, bitIndex:bitPos, byteSize:maxPos} = bitstream
        maxPos *= 8
        
        zmode = c = status = outPtr = 0
        out = new Uint32Array(pc)

        while c < samples
            # bail if we've run off the end of the buffer
            unless bitPos < maxPos
                return ALAC.error.paramError
                
            m = mb >> QBSHIFT
            k = lg3a(m)

            k = Math.min(k, kb)
            m = (1 << k) - 1
            [n, bitPos] = dyn_get_32(input, bitPos, m, k, maxSize)
            
            # least significant bit is sign bit
            ndecode = n + zmode
            multiplier = -(ndecode & 1) | 1
            del = ((ndecode + 1) >> 1) * multiplier

            out[outPtr++] = del
            c++

            mb = pb * (n + zmode) + mb - ((pb * mb) >> QBSHIFT)
            
            # update mean tracking
            if n > N_MAX_MEAN_CLAMP
                mb = N_MEAN_CLAMP_VAL

            zmode = 0

            if ((mb << MMULSHIFT) < QB) && (c < samples)
                zmode = 1
                k = lead(mb) - BITOFF + ((mb + MOFF) >> MDENSHIFT)
                mz = ((1 << k) - 1) & wb

                [n, bitPos] = dyn_get_16(input, bitPos, mz, k)
                
                unless c + 1 <= samples
                    return ALAC.error.paramError
                    
                for j in [0...n]
                    out[outPtr++] = 0
                    c++
                    
                zmode = 0 if z >= 65535
                    
                mb = 0
        
        bitstream.bitIndex = bitPos
        bitstream.cur += bitPos >> 3
        butstream.bitIndex &= 7
                
        return status