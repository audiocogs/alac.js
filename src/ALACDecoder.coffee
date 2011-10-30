#
#  Original C(++) version by Apple, http://alac.macosforge.org
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

class ALACDecoder
    window.ALACDecoder = this
    
    constructor: (@cookie) ->
        [offset, remaining] = [0, @cookie.byteLength]
        
        if CSCompareToString(@cookie, offset + 4, 'frma', 0, 4)
            offset += 12; remaining -= 12
            console.log "Skipping 'frma'"
        
        if CSCompareToString(cookie, offset + 4, 'alac', 0, 4)
            offset += 12; remaining -= 12
            console.log "Skipping 'alac'"
        
        if remaining < 24
            console.log "Cookie too short"
            return ALAC.errors.paramError
        
        @config = 
            frameLength:        CSLoadBigUInt32(cookie, offset + 0)
            compatibleVersion:  CSLoadUInt8(cookie, offset + 4)
            bitDepth:           CSLoadUInt8(cookie, offset + 5)
            pb:                 CSLoadUInt8(cookie, offset + 6)
            mb:                 CSLoadUInt8(cookie, offset + 7)
            kb:                 CSLoadUInt8(cookie, offset + 8)
            numChannels:        CSLoadUInt8(cookie, offset + 9)
            maxRun:             CSLoadBigUInt16(cookie, offset + 10)
            maxFrameBytes:      CSLoadBigUInt32(cookie, offset + 12)
            avgBitRage:         CSLoadBigUInt32(cookie, offset + 16)
            sampleRate:         CSLoadBigUInt32(cookie, offset + 20)
            
        console.log @config
        
        @mixBufferU = new Int32Array(@config.frameLength)
        @mixBufferV = new Int32Array(@config.frameLength)
        
        predictorBuffer = CSAlloc(@config.frameLength * 4)
        
        @predictor = new Int32Array(predictorBuffer)
        @shiftBuffer = new Int16Array(predictorBuffer)
        
        return ALAC.errors.noError
        
    decode: (input, offset, samples, channels) ->
        unless channels > 0
            console.log "Requested less than a single channel"
            
            return ALAC.errors.paramError
        
        @activeElements = 0
        
        output = CSAlloc(samples * channels * @config.bitDepth / 8)
        
        [offset, channelIndex, input_a] = [offset * 8, 0, new Int16Array(input)]
        
        status = ALAC.errors.noError
        
        while status == ALAC.errors.noError
            tag = CSLoadFewBits(input, offset, 3)
            
            switch tag
                when 0, 3   # ID_SCE, Single Channel Element; ID_LFE, LFE Channel Element
                    console.log("LFE or SCE element")
                    
                    break
                when 1      # ID_CPE, Channel Pair Element
                    console.log("CPE element")
                    
                    break
                when 2, 5   # ID_CCE, Coupling Channel Element; ID_PCE
                    console.log("Unsupported element")
                    
                    return ALAC.errors.paramError
                when 4      # ID_DSE, Data Stream Element
                    console.log("Data Stream element, ignoring")
                    
                    status = this.dataStreamElement(input, offset)
                    
                    break
                when 6      # ID_FIL, Fill element
                    console.log("Fill element, ignoring")
                    
                    status = this.fillElement(input, offset)
                    
                    break
                when 7      # ID_END, End element
                    console.log("End of frame")
                    
                    return status
                else
                    console.log("Error in frame")
                
                    return ALAC.errors.paramError
                
            
            if channelIndex > channels
                console.log("Channel Index is higher than the amount of channels")
                
                break
        
        return [status, output]
    
