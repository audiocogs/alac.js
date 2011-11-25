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

# File: ag_dec.coffee
# Contains: Adaptive Golomb decode routines.

class Aglib
    PB0 = 40
    MB0 = 10
    KB0 = 14
    MAX_RUN_DEFAULT = 255
    MAX_PREFIX_16 = 9
    MAX_PREFIX_32 = 9
    QBSHIFT = 9
    QB = 1 << QBSHIFT
    MMULSHIFT = 2
    MDENSHIFT = QBSHIFT - MMULSHIFT - 1
    MOFF = 1 << (MDENSHIFT-2)
    N_MAX_MEAN_CLAMP = 0xffff
    N_MEAN_CLAMP_VAL = 0xffff
    MMULSHIFT = 2
    BITOFF = 24
    MAX_DATATYPE_BITS_16 = 16

    lead = (m) ->
        c = 1 << 31
    
        for i in [0...32]
            break if (c & m) isnt 0
            c >>= 1
    
        return i
        
    lg3a = (x) ->
        31 - lead(x + 3)

    get_next = (input, suff) ->
        input >>> (32 - suff)

    dyn_get_16 = (data, pos, m, k) ->
        input = data.data
        stream = read(input, data.offset + (pos >> 3)) 
        stream <<= (pos & 7)
        
        pre = lead(~stream)

        if pre >= MAX_PREFIX_16
            pre = MAX_PREFIX_16
            pos += pre
            
            stream <<= pre
            result = get_next(stream, MAX_DATATYPE_BITS_16)

            pos += MAX_DATATYPE_BITS_16
            
        else
            pos += pre + 1

            stream <<= pre + 1
            v = get_next(stream, k)

            pos += k
            result = pre * m + v - 1

            if v < 2
                result -= (v - 1)
                pos -= 1

        return [result, pos]

    dyn_get_32 = (data, m, k, maxbits) ->
        stream = data.readBig(maxbits)

        result = lead(~stream)
        
        if result >= MAX_PREFIX_32
            result = data.read(maxbits)
            
        else
            if k isnt 1
                stream <<= result + 1
                v = get_next(stream, k)

                pos += k - 1
                result = result * m

                if v >= 2
                    result += v - 1
                    pos += 1
        
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
        
    @dyn_decomp: (params, data, pc, samples, maxSize) ->
        {pb, kb, wb, mb0: mb} = params
        
        console.log("\tPC", pc)
        console.log("\tSamples, Max Size", samples, maxSize)
        
        start = data.copy()
        
        zmode = 0
        c = 0
        
        status = ALAC.errors.noError
        
        while c < samples
            m = mb >>> QBSHIFT
            k = lg3a(m)
            
            console.log("\tm, k", m, k)
            
            k = Math.min(k, kb)
            m = (1 << k) - 1
            
            n = dyn_get_32(data, m, k, maxSize)
            
            # least significant bit is sign bit
            ndecode = n + zmode
            multiplier = (-(ndecode & 1)) | 1
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
                
                unless c + n <= samples
                    status = ALAC.error.paramError
                    break
                    
                for j in [0...n]
                    out[outPtr++] = 0
                    c++
                    
                console.log c
                    
                zmode = 0 if n >= 65535
                mb = 0
            
        
        input.advance(bitPos - startPos)
          
        console.log 'length', bitPos, startPos, bitPos - startPos
        
        debug()
        
        return status
    