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

# File: matrix_dec.coffee
# Contains: ALAC mixing/matrixing routines to/from 32-bit predictor buffers.

class Matrixlib
    @unmix16 = (u, v, out, stride, samples, mixbits, mixres) ->
        console.log("Stride, Samples, Mix Bits, Mix Res", stride, samples, mixbits, mixres)
        console.log("U, V", u, v)
        
        # Conventional separated stereo
        if mixres is 0
            console.log("Outputting Separated Stereo")
            for i in [0...samples] by 1
                out[i * stride + 0] = u[i]
                out[i * stride + 1] = v[i]
            
        # Matrixed stereo
        else
            console.log("Outputting Matrixed Stereo")
            for i in [0...samples] by 1
                l = u[i] + v[i] - ((mixres * v[i]) >> mixbits)
                out[i * stride + 0] = l
                out[i * stride + 1] = l - v[i]
                
        console.log(samples * stride)
    
    # unmix20
    # unmix24
    # unmix 32