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
        
        [coefsU, coefsV] = [new Int16Array(32), new Int16Array(32)]
        
        output = CSAlloc(samples * channels * @config.bitDepth / 8)
        
        [offset, channelIndex, input_a] = [offset * 8, 0, new Int16Array(input)]
        
        status = ALAC.errors.noError
        
        while status == ALAC.errors.noError
            tag = CSLoadFewBits(input, offset, 3); offset += 3
            
            switch tag
                when 0, 3   # ID_SCE, Single Channel Element; ID_LFE, LFE Channel Element
                    console.log("LFE or SCE element")
                    
                    # Mono / LFE channel
                    
                    elementInstanceTag = CSLoadFewBits(input, offset, 4); offset += 4
                    
                    @activeElements = @activeElements | (1 << elementInstanceTag)
                    
                    unused = CSLoadManyBits(input, offset, 12); offset += 12
                    
                    return ALAC.errors.paramError unless unused == 0
                    
                    headerByte = CSLoadFewBits(input, offset, 4); offset += 4
                    
                    partialFrame = headerByte >> 3
                    
                    bytesShifted = (headerByte >> 1) & 0x3
                    
                    return ALAC.errors.paramError unless bytesShifted == 3
                    
                    shift = bytesShifted * 8
                    
                    escapeFlag = headerByte & 0x1
                    
                    chanBits = @config.bitDepth - shift
                    
                    unless partialFrame == 0
                        samples = CSLoadManyBits(input, offset, 16); offset += 16
                        samples = samples | CSLoadManyBits(input, offset, 16); offset += 16
                    
                    if escapeFlag == 0
                        mixBits     = CSLoadFewBits(input, offset, 8); offset += 8
                        mixRes      = CSLoadFewBits(input, offset, 8); offset += 8 # TODO: Should be signed
                        
                        headerByte  = CSLoadFewBits(input, offset, 8); offset += 8
                        modeU       = headerByte >> 4
                        denShiftU   = headerByte & 0x1F
                        
                        headerByte  = CSLoadFewBits(input, offset, 8); offset += 8
                        pbFactorU   = headerByte >> 5
                        numU        = headerByte & 0x1F
                        
                        for i in [0 ... numU] by 1
                            coefsU[i] = CSLoadManyBits(bits, 16); offset += 16
                        
                        offset += (bytesShifted * 8) * samples unless bytesShifted == 0
                        
                        # TODO: Fix dyn_decomp, I am not sure what the api should be
                        params = Aglib.ag_params(@config.mb, pb * pbFactorU / 4, @config.kb, samples, samples, @config.maxRun)
                        
                        status = Aglib.dyn_decomp(params, input, offset, @predictor, samples, chanBits)
                        
                        return status unless status = ALAC.errors.noError
                        
                        if modeU == 0
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        else
                            # TODO: Needs the optimizations?
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        
                    else
                        shift = 32 - chanBits
                        
                        if chanBits <= 16
                            for i in [0 ... samples] by 1
                                val = CSLoadManyBits(input, offset, chanBits); offset += chanBits
                                val = (val << shift) >> shift
                                
                                mixBufferU[i] = val
                            
                        else
                            # TODO: Fix with chanbits > 16
                            
                            console.log("Failing, not less than 16 bits per channel")
                            
                            return -9000
                        
                        maxBits = mixRes = 0
                        
                        bits1 = chanbits * samples
                        
                        bytesShifted = 0
                    
                    unless bytesShifted == 0
                        shift = bytesShifted * 8
                        
                        for i in [0 ... samples] by 1
                            shiftBuffer[i] = CSLoadManyBits(shiftBits, shift)
                        
                        console.log("Something")
                    
                    switch @config.bitDepth
                        when 16
                            console.log("16-bit output, yaay!")
                            
                            # TODO: Do something
                            
                            break
                        else
                            console.log("Only supports 16-bit samples right now")
                            
                            return -9000
                        
                    
                    channelIndex += 1
                    
                    outSamples = samples
                    
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
        
        return [status, output]
    
