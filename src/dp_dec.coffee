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
# Contains: Dynamic Predictor decode routines

class Dplib
    copy = (dst, dstOffset, src, srcOffset, n) ->
        destination = new Uint8Array(dst, dstOffset, n)
        source = new Uint8Array(src, srcOffset, n)
        destination.set(source)
        return dst
    
    @unpc_block: (pc1, out, num, coefs, active, chanbits, denshift) ->
        packet += 1
        
        chanshift = 32 - chanbits
        denhalf = 1 << (denshift - 1)
        
        out[0] = pc1[0];
        
        console.log("\tChanshift, Denhalf, Active", chanshift, denhalf, active)
        console.log("\tPC1", pc1)
        
        # just copy if active == 0
        return copy(out, 0, pc1, 0, num * 4) if active == 0
        
        # short-circuit if numactive is 31    
        if active == 31
            debug()
            prev = out[0]
            
            for i in [1...num]
                del = pcl[i] + prev
                prev = (del << chanshift) >> chanshift
                out[i] = prev
            
            return
        
        for i in [1 .. active] by 1
            del = pc1[i] + out[i - 1]
            out[i] = (del << chanshift) >> chanshift
        
        lim = active + 1
        
        # if active == 4 # Optimization for active == 4
        # if active == 8 # Optimization for active == 8
        # else           # General case
        
        sum1 = 0
        
        for i in [lim ... num] by 1
            sum1 = 0; top = out[i - lim]; offset = i - 1
            
            for j in [0 ... active] by 1
                sum1 += coefs[j] * (out[offset - j] - top)
            
            del = del0 = pc1[i]
            sg  = (-del >>> 31) | (del >> 31)
            
            del += top + ((sum1 + denhalf) >> denshift)
            out[i] = (del << chanshift) >> chanshift
            
            if sg > 0
                for j in [active - 1 .. 0] by -1
                    dd = top - out[offset - j]
                    sgn = (-dd >>> 31) | (dd >> 31)
                    
                    coefs[j] -= sgn
                    
                    del0 -= (active - j) * ((sgn * dd) >> denshift)
                    
                    if del0 <= 0
                        break
                    
                
            else if sg < 0
                for j in [active - 1 .. 0] by -1
                    dd = top - out[offset - j]
                    sgn = (-dd >>> 31) | (dd >> 31)
                    
                    coefs[j] += sgn
                    
                    del0 -= (active - j) * ((-sgn * dd) >> denshift)
                    
                    if del0 >= 0
                        break
                    
                
            
        
        console.log("\tLast Sum", sum1)
        console.log("\tOutput", out)
    
