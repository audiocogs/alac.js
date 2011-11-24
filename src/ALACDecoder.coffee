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
        
        data = new Data(@cookie)
        atom = data.stringAt(4, 4)
        
        if atom is 'frma'
            console.log "Skipping 'frma'"
            data.pos += 12
            
        else if atom is 'alac'
            console.log "Skipping 'alac'"
            data.pos += 12
            
        if data.length - data.pos < 24
            console.log "Cookie too short"
            return ALAC.errors.paramError
            
        @config = data.struct
            frameLength: 'uint32'
            compatibleVersion: 'uint8'
            bitDepth: 'uint8'
            pb: 'uint8'
            mb: 'uint8'
            kb: 'uint8'
            numChannels: 'uint8'
            maxRun: 'uint16'
            maxFrameBytes: 'uint32'
            avgBitRate: 'uint32'
            sampleRate: 'uint32'
            
        console.log 'cookie', @config
        
        @mixBufferU = new Int32Array(@config.frameLength)
        @mixBufferV = new Int32Array(@config.frameLength)
        
        predictorBuffer = new ArrayBuffer(@config.frameLength * 4)
        @predictor = new Int32Array(predictorBuffer)
        @shiftBuffer = new Int16Array(predictorBuffer)
            
        return ALAC.errors.noError
        
    decode: (input, offset, samples, channels) ->
        unless channels > 0
            console.log "Requested less than a single channel"
            return ALAC.errors.paramError
        
        @activeElements = 0
        channelIndex = 0
        
        data = new BitBuffer(input)
        
        coefsU = new Int16Array(32)
        coefsV = new Int16Array(32)
        output = new ArrayBuffer(samples * channels * @config.bitDepth / 8)
        
        offset *= 8
        status = ALAC.errors.noError
        
        while status is ALAC.errors.noError
            tag = data.readSmall(3)
            
            switch tag
                when ID_SCE, ID_LFE
                    console.log("LFE or SCE element")
                    
                    # Mono / LFE channel
                    elementInstanceTag = data.readSmall(4)
                    @activeElements |= (1 << elementInstanceTag)
                    
                    # read the 12 unused header bits
                    #unused = CSLoadManyBits(input, offset, 12)
                    unused = data.read(12)
                    return ALAC.errors.paramError unless unused is 0
                    
                    # read the 1-bit "partial frame" flag, 2-bit "shift-off" flag & 1-bit "escape" flag
                    #headerByte = CSLoadFewBits(input, offset, 4); offset += 4
                    headerByte = data.read(4)
                    partialFrame = headerByte >> 3
                    bytesShifted = (headerByte >> 1) & 0x3
                    return ALAC.errors.paramError if bytesShifted is 3
                    
                    shift = bytesShifted * 8
                    escapeFlag = headerByte & 0x1
                    chanBits = @config.bitDepth - shift
                    
                    # check for partial frame to override requested samples
                    if partialFrame isnt 0
                        samples = data.read(16) << 16
                        samples |= data.read(16)
                    
                    if escapeFlag is 0
                        # compressed frame, read rest of parameters
                        mixBits     = data.read(8)
                        mixRes      = data.read(8)
                        
                        headerByte  = data.read(8)
                        modeU       = headerByte >> 4
                        denShiftU   = headerByte & 0xf
                        
                        headerByte  = data.read(8)
                        pbFactorU   = headerByte >> 5
                        numU        = headerByte & 0x1f
                        
                        for i in [0...numU]
                            coefsU[i] = data.read(16)
                        
                        # if shift active, skip the the shift buffer but remember where it starts
                        if bytesShifted isnt 0
                            # shiftbits = bits?
                            data.advance(shift * samples)
                        
                        # TODO: Fix dyn_decomp, I am not sure what the api should be
                        params = Aglib.ag_params(@config.mb, (@config.pb * pbFactorU) / 4, @config.kb, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(params, data, @predictor, samples, chanBits)
                        return status unless status is ALAC.errors.noError
                        return
                        
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
                            for i in [0 ... samples]
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
                    
                    if (channelIndex + 2) > channels
                        # TODO: GOTO NOMOARCHANNELS
                        console.log("No more channels, please")
                    
                    elementInstanceTag = data.readSmall(4)
                    
                    console.log("Element Instance Tag", elementInstanceTag) # DEBUG
                    
                    @activeElements |= (1 << elementInstanceTag)
                    
                    unusedHeader = data.read(12)
                    
                    unless unusedHeader == 0
                        console.log("Error! Unused header is silly")
                        
                        return ALAC.errors.paramError
                    
                    headerByte = data.read(4)
                    
                    console.log("Header Byte", headerByte) # DEBUG
                    
                    partialFrame = headerByte >>> 3
                    
                    bytesShifted = (headerByte >>> 1) & 0x03
                    
                    console.log("Partial Frame, Bytes Shifted", partialFrame, bytesShifted) # DEBUG
                    
                    if bytesShifted == 3
                        console.log("Moooom, the reference said that bytes shifted couldn't be 3!")
                        
                        return ALAC.errors.paramError
                    
                    escapeFlag = headerByte & 0x01
                    
                    console.log("Escape Flag", escapeFlag) # DEBUG
                    
                    chanBits = @config.bitDepth - (bytesShifted * 8) + 1
                    
                    console.log("Channel Bits", chanBits) # DEBUG
                    
                    if partialFrame != 0
                        samples = data.read(16) << 16 + data.read(16)
                    
                    console.log("Samples", samples) # DEBUG
                    
                    if escapeFlag == 0
                        mixBits = data.read(8)
                        mixRes = data.read(8)
                        
                        headerByte = data.read(8)
                        modeU = headerByte >>> 4
                        denShiftU = headerByte & 0x0F
                        
                        headerByte = data.read(8)
                        pbFactorU = headerByte >>> 5
                        numU = headerByte & 0x1F
                        
                        for i in [0 ... numU] by 1
                            coefsU[i] = data.read(16)
                        
                        headerByte = data.read(8)
                        modeV = headerByte >>> 4
                        denShiftV = headerByte & 0x0F
                        
                        headerByte = data.read(8)
                        pbFactorV = headerByte >>> 5
                        numV = headerByte & 0x1F;
                        
                        for i in [0 ... numV] by 1
                            coefsV = data.read(16)
                        
                        if bytesShifted != 0
                            shiftbits = data.copy()
                            
                            bits.advance((bytesShifted * 8) * samples)
                        
                        agParams = Aglib.ag_params(@config.mb, pb * pbFactorU / 4, @config.kb, samples, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(agParams, bits, @predictor, samples, chanBits, data) # data might be wrong.
                        
                        if status != ALAC.errors.noError
                            console.log("Mom also said there should be no error")
                            
                            return status
                        
                        if modeU == 0
                            Dplib.unpc_block(@predictor, @predictor, samples, coefsU, numU, chanBits, denShiftU)
                        else
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        
                    else
                        chanBits = @config.bitDepth
                        shift = 32 - chanBits
                        
                        if (chanBits <= 16)
                            for i in [0 ... samples] by 1
                                val = (data.read(chanBits) << shift) >> shift
                                
                                @mixBufferU[i] = val
                                
                                val = (data.read(chanBits) << shift) >> shift
                                
                                @mixBufferV[i] = val
                            
                        else
                            extraBits = chanBits - 16
                            for i in [0 ... samples] by 1
                                val = (data.read(16) << 16) >> shift
                                val += data.read(extraBits)
                                
                                @mixBufferU[i] = val
                                
                                val = (data.read(16) << 16) >> shift
                                val += data.read(extraBits)
                                
                                @mixBufferV[i] = val
                            
                        
                        console.log("Mix Buffer U, V", @mixBufferU, @mixBufferV) # DEBUG
                        
                        mixBits = mixRes = 0
                        bits1 = chanBits * samples
                        bytesShifted = 0
                    
                    console.log("Bytes Shifted", bytesShifted) # DEBUG
                    
                    if bytesShifted != 0
                        shift = bytesShifted * 8
                        
                        for i in [0 ... samples * 2] by 2
                            @shiftBuffer[i + 0] = shiftbits.read(shift)
                            @shiftBuffer[i + 1] = shiftbits.read(shift)
                        
                    
                    switch @config.bitDepth
                        when 16
                            out16 = new Uint16Array(output, samples * channelIndex * @config.bitDepth / 8)
                            
                            Matrixlib.unmix16(@mixBufferU, @mixBufferV, out16, channels, samples, mixBits, mixRes)
                            
                            console.log("Output", out16)
                        else
                            console.log("Evil bit depth")
                            
                            return -1231
                        
                    
                    channelIndex += 2
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
    
