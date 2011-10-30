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
    
    ID_SCE = 0 # Single Channel Element
    ID_CPE = 1 # Channel Pair Element
    ID_CCE = 2 # Coupling Channel Element
    ID_LFE = 3 # LFE Channel Element
    ID_DSE = 4 # not yet supported
    ID_PCE = 5
    ID_FIL = 6
    ID_END = 7
    
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
        channelIndex = 0
        
        coefsU = new Int16Array(32)
        coefsV = new Int16Array(32)
                
        output = CSAlloc(samples * channels * @config.bitDepth / 8)
        input_a = new Int16Array(input)
        
        offset *= 8
        status = ALAC.errors.noError
        
        while status is ALAC.errors.noError
            tag = CSLoadFewBits(input, offset, 3)
            offset += 3
            
            switch tag
                when ID_SCE, ID_LFE
                    console.log("LFE or SCE element")
                    
                    # Mono / LFE channel
                    elementInstanceTag = CSLoadFewBits(input, offset, 4); offset += 4
                    @activeElements |= (1 << elementInstanceTag)
                    
                    # read the 12 unused header bits
                    unused = CSLoadManyBits(input, offset, 12)
                    return ALAC.errors.paramError unless unused is 0
                    offset += 12
                    
                    # read the 1-bit "partial frame" flag, 2-bit "shift-off" flag & 1-bit "escape" flag
                    headerByte = CSLoadFewBits(input, offset, 4); offset += 4
                    partialFrame = headerByte >> 3
                    bytesShifted = (headerByte >> 1) & 0x3
                    return ALAC.errors.paramError unless bytesShifted is 3
                    
                    shift = bytesShifted * 8
                    escapeFlag = headerByte & 0x1
                    chanBits = @config.bitDepth - shift
                    
                    # check for partial frame to override requested samples
                    if partialFrame isnt 0
                        samples = CSLoadManyBits(input, offset, 16) << 16; offset += 16
                        samples |= CSLoadManyBits(input, offset, 16);      offset += 16
                    
                    if escapeFlag is 0
                        # compressed frame, read rest of parameters
                        mixBits     = CSLoadFewBits(input, offset, 8); offset += 8
                        mixRes      = CSLoadFewBits(input, offset, 8); offset += 8 # TODO: Should be signed
                        
                        headerByte  = CSLoadFewBits(input, offset, 8); offset += 8
                        modeU       = headerByte >> 4
                        denShiftU   = headerByte & 0xf
                        
                        headerByte  = CSLoadFewBits(input, offset, 8); offset += 8
                        pbFactorU   = headerByte >> 5
                        numU        = headerByte & 0x1f
                        
                        for i in [0...numU]
                            coefsU[i] = CSLoadManyBits(bits, 16); offset += 16
                        
                        # if shift active, skip the the shift buffer but remember where it starts
                        if bytesShifted isnt 0
                            offset += shift * samples
                        
                        # TODO: Fix dyn_decomp, I am not sure what the api should be
                        params = Aglib.ag_params(@config.mb, (pb * pbFactorU) / 4, @config.kb, samples, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(params, input, offset, @predictor, samples, chanBits)
                        return status unless status is ALAC.errors.noError
                        
                        if modeU is 0
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        else
                            # TODO: Needs the optimizations?
                            # the special "numActive == 31" mode can be done in-place
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        
                    else
                        # uncompressed frame, copy data into the mix buffer to use common output code
                        shift = 32 - chanBits
                        
                        if chanBits <= 16
                            for i in [0...samples]
                                val = CSLoadManyBits(input, offset, chanBits); offset += chanBits
                                val = (val << shift) >> shift
                                @mixBufferU[i] = val
                            
                        else
                            # TODO: Fix with chanbits > 16
                            console.log("Failing, not less than 16 bits per channel")
                            return -9000
                        
                        maxBits = mixRes = 0
                        bits1 = chanbits * samples # TODO: fix
                        bytesShifted = 0
                    
                    # now read the shifted values into the shift buffer
                    if bytesShifted isnt 0
                        shift = bytesShifted * 8
                        
                        for i in [0...samples]
                            @shiftBuffer[i] = CSLoadManyBits(shiftBits, shift)
                    
                    # convert 32-bit integers into output buffer
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
                    
                when ID_CPE
                    console.log("CPE element")
                    
                when ID_CCE, ID_PCE
                    console.log("Unsupported element")
                    return ALAC.errors.paramError
                    
                when ID_DSE
                    console.log("Data Stream element, ignoring")
                    status = this.dataStreamElement(input, offset)
                    
                when ID_FIL
                    console.log("Fill element, ignoring")
                    status = this.fillElement(input, offset)
                    
                when ID_END
                    console.log("End of frame")
                    return status
                    
                else
                    console.log("Error in frame")
                    return ALAC.errors.paramError
                
            
        if channelIndex > channels
            console.log("Channel Index is higher than the amount of channels")
        
        return [status, output]
    
