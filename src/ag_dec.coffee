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
    N_MAX_MEAN_CLAMP = 0xFFFF
    N_MEAN_CLAMP_VAL = 0xFFFF
    MMULSHIFT = 2
    BITOFF = 24
    MAX_DATATYPE_BITS_16 = 16

    lead = (m) ->
        c = 1 << 31
                
        for i in [0 ... 32] by 1
            return i if (c & m) != 0            
            c >>>= 1
    
        return 32
        
    lg3a = (x) ->
        31 - lead(x + 3)

    get_next = (input, suff) ->
        input >>> (32 - suff)

    dyn_get_16 = (data, m, k) ->
        offs = data.pos
        stream = data.peekBig(32 - offs) << offs
        bitsInPrefix = lead(~stream)
        
        if bitsInPrefix >= MAX_PREFIX_16
            data.advance(MAX_PREFIX_16 + MAX_DATATYPE_BITS_16)
            stream <<= (bitsInPrefix + 1)
            result = (stream >>> (32 - MAX_DATATYPE_BITS_16))
            
        else
            data.advance(bitsInPrefix + 1)
            
            stream <<= (bitsInPrefix + 1)
            result = bitsInPrefix * m
            v = (stream >>> (32 - k))
            
            data.advance(k)
            
            result = bitsInPrefix * m + v - 1;
            
            if v < 2
                result -= (v - 1)
                data.rewind(1)

        return result
    
    dyn_get_32 = (data, m, k, maxbits) ->
        offs = data.pos
        stream = data.peekBig(32 - offs) << offs
        result = lead(~stream)
        
        if result >= MAX_PREFIX_32
            data.advance(MAX_PREFIX_32)
            return data.readBig(maxbits)
            
        else
            data.advance(result + 1)
        
            if k != 1
                stream <<= (result + 1)
                result *= m
                v = (stream >>> (32 - k))
                
                data.advance(k - 1)
                
                if v > 1
                    result += v - 1
                    data.advance(1)

        return result
        
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
        {pb, kb, wb, mb0:mb} = params
        
        zmode = 0
        c = 0
        status = ALAC.errors.noError
        
        while c < samples            
            m = mb >>> QBSHIFT
            k = Math.min(lg3a(m), kb)
            m = (1 << k) - 1
            
            n = dyn_get_32(data, m, k, maxSize)
            
            # least significant bit is sign bit
            ndecode = n + zmode
            multiplier = -(ndecode & 1) | 1
            pc[c++] = ((ndecode + 1) >>> 1) * multiplier
            
            mb = pb * (n + zmode) + mb - ((pb * mb) >> QBSHIFT)
            
            # update mean tracking
            mb = N_MEAN_CLAMP_VAL if n > N_MAX_MEAN_CLAMP
            
            zmode = 0
            
            if ((mb << MMULSHIFT) < QB) && (c < samples)
                zmode = 1
                
                k = lead(mb) - BITOFF + ((mb + MOFF) >> MDENSHIFT)
                mz = ((1 << k) - 1) & wb
                n = dyn_get_16(data, mz, k)
                
                unless c + n <= samples
                    return ALAC.errors.paramError
                    
                for j in [0...n] by 1
                    pc[c++] = 0
                    
                zmode = 0 if n >= 65535
                mb = 0
        
        return status