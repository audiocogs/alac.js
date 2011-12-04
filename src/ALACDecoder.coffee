#
#  Original C(++) version by Apple, http://alac.macosforge.org
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
            data.advance(12)
        
        atom = data.stringAt(4, 4)
        
        if atom is 'alac'
            console.log "Skipping 'alac'"
            data.advance(12)
            
        if data.remaining() < 24
            console.log "Cookie too short"
            return [ALAC.errors.paramError]
        
        @config =
            frameLength: data.readUInt32()
            compatibleVersion: data.readUInt8()
            bitDepth: data.readUInt8()
            pb: data.readUInt8()
            mb: data.readUInt8()
            kb: data.readUInt8()
            numChannels: data.readUInt8()
            maxRun: data.readUInt16()
            maxFrameBytes: data.readUInt32()
            avgBitRate: data.readUInt32()
            sampleRate: data.readUInt32()
        
        console.log 'cookie', @config
        
        @mixBufferU = new Int32Array(@config.frameLength)
        @mixBufferV = new Int32Array(@config.frameLength)
        
        predictorBuffer = new ArrayBuffer(@config.frameLength * 4)
        @predictor = new Int32Array(predictorBuffer)
        @shiftBuffer = new Int16Array(predictorBuffer)
            
        return ALAC.errors.noError
        
    decode: (data, samples, channels) ->
        unless channels > 0
            console.log "Requested less than a single channel"
            return [ALAC.errors.paramError]
        
        @activeElements = 0
        channelIndex = 0
        
        coefsU = new Int16Array(32)
        coefsV = new Int16Array(32)
        output = new ArrayBuffer(samples * channels * @config.bitDepth / 8)
        
        status = ALAC.errors.noError
        
        while status is ALAC.errors.noError
            pb = @config.pb
            
            tag = data.readSmall(3)
            
            console.log("Tag: #{tag}")
            
            switch tag
                when ID_SCE, ID_LFE  
                    # Mono / LFE channel
                    elementInstanceTag = data.readSmall(4)
                    @activeElements |= (1 << elementInstanceTag)
                    
                    # read the 12 unused header bits
                    unused = data.read(12)
                    
                    unless unused == 0
                        console.log("Unused part of header does not contain 0, it should")
                        return [ALAC.errors.paramError]
                    
                    # read the 1-bit "partial frame" flag, 2-bit "shift-off" flag & 1-bit "escape" flag
                    headerByte = data.read(4)
                    partialFrame = headerByte >>> 3
                    bytesShifted = (headerByte >>> 1) & 0x3
                    
                    if bytesShifted == 3
                        console.log("Bytes are shifted by 3, they shouldn't be")
                        return [ALAC.errors.paramError]
                    
                    shift = bytesShifted * 8
                    escapeFlag = headerByte & 0x1
                    chanBits = @config.bitDepth - shift
                    
                    # check for partial frame to override requested samples
                    if partialFrame isnt 0
                        samples = data.read(16) << 16 + data.read(16)
                    
                    if escapeFlag is 0
                        # compressed frame, read rest of parameters
                        mixBits     = data.read(8)
                        mixRes      = data.read(8)
                        
                        headerByte  = data.read(8)
                        modeU       = headerByte >>> 4
                        denShiftU   = headerByte & 0xf
                        
                        headerByte  = data.read(8)
                        pbFactorU   = headerByte >>> 5
                        numU        = headerByte & 0x1f
                        
                        for i in [0...numU] by 1
                            coefsU[i] = data.read(16)
                        
                        # if shift active, skip the the shift buffer but remember where it starts
                        if bytesShifted isnt 0
                            shiftbits = data.copy()
                            data.advance(shift * samples)
                        
                        params = Aglib.ag_params(@config.mb, (@config.pb * pbFactorU) / 4, @config.kb, samples, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(params, data, @predictor, samples, chanBits)
                        return status unless status is ALAC.errors.noError
                        
                        if modeU == 0
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        else
                            # the special "numActive == 31" mode can be done in-place
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        
                    else
                        # uncompressed frame, copy data into the mix buffer to use common output code
                        shift = 32 - chanBits
                        
                        if (chanBits <= 16)
                            for i in [0 ... samples] by 1
                                val = (data.read(chanBits) << shift) >> shift
                                @mixBufferU[i] = val
                            
                        else
                            for i in [0 ... samples] by 1
                                val = (data.readBig(chanBits) << shift) >> shift
                                @mixBufferU[i] = val
                        
                        maxBits = mixRes = 0
                        bits1 = chanbits * samples
                        bytesShifted = 0
                    
                    # now read the shifted values into the shift buffer
                    if bytesShifted isnt 0
                        shift = bytesShifted * 8
                        
                        for i in [0...samples]
                            @shiftBuffer[i] = shiftbits.read(shift)
                    
                    # convert 32-bit integers into output buffer
                    switch @config.bitDepth
                        when 16
                            out16 = new Int16Array(output, channelIndex)
                            j = 0
                            for i in [0...samples] by 1
                                out16[j] = @mixBufferU[i]
                                j += channels
                                
                        else
                            console.log("Only supports 16-bit samples right now")
                            return -9000
                        
                    
                    channelIndex += 1
                    return [status, output]
                    
                when ID_CPE                    
                    # if decoding this pair would take us over the max channels limit, bail
                    if (channelIndex + 2) > channels
                        # TODO: GOTO NOMOARCHANNELS
                        console.log("No more channels, please")
                    
                    # stereo channel pair
                    elementInstanceTag = data.readSmall(4)
                    @activeElements |= (1 << elementInstanceTag)
                    
                    # read the 12 unused header bits
                    unusedHeader = data.read(12)
                    
                    unless unusedHeader == 0
                        console.log("Error! Unused header is silly")
                        return [ALAC.errors.paramError]
                    
                    # read the 1-bit "partial frame" flag, 2-bit "shift-off" flag & 1-bit "escape" flag
                    headerByte = data.read(4)
                    
                    partialFrame = headerByte >>> 3
                    bytesShifted = (headerByte >>> 1) & 0x03
                    
                    if bytesShifted == 3
                        console.log("Moooom, the reference said that bytes shifted couldn't be 3!")
                        return [ALAC.errors.paramError]
                    
                    escapeFlag = headerByte & 0x01
                    chanBits = @config.bitDepth - (bytesShifted * 8) + 1
                    
                    # check for partial frame length to override requested numSamples
                    if partialFrame != 0
                        samples = data.read(16) << 16 + data.read(16)
                    
                    if escapeFlag == 0
                        # compressed frame, read rest of parameters
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
                            coefsV[i] = data.read(16)
                        
                        # if shift active, skip the interleaved shifted values but remember where they start
                        if bytesShifted != 0
                            shiftbits = data.copy()
                            bits.advance((bytesShifted * 8) * 2 * samples)
                        
                        # decompress and run predictor for "left" channel
                        agParams = Aglib.ag_params(@config.mb, (pb * pbFactorU) / 4, @config.kb, samples, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(agParams, data, @predictor, samples, chanBits)
                        
                        if status != ALAC.errors.noError
                            console.log("Mom said there should be no errors in the adaptive Goloumb code (part 1)...")
                            return status
                        
                        if modeU == 0
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        else
                            # the special "numActive == 31" mode can be done in-place
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferU, samples, coefsU, numU, chanBits, denShiftU)
                        
                        # decompress and run predictor for "right" channel
                        agParams = Aglib.ag_params(@config.mb, (pb * pbFactorV) / 4, @config.kb, samples, samples, @config.maxRun)
                        status = Aglib.dyn_decomp(agParams, data, @predictor, samples, chanBits)
                        
                        if status != ALAC.errors.noError
                            console.log("Mom said there should be no errors in the adaptive Goloumb code (part 2)...")
                            return status
                        
                        if modeV == 0
                            Dplib.unpc_block(@predictor, @mixBufferV, samples, coefsV, numV, chanBits, denShiftV)
                        else
                            # the special "numActive == 31" mode can be done in-place
                            Dplib.unpc_block(@predictor, @predictor, samples, null, 31, chanBits, 0)
                            Dplib.unpc_block(@predictor, @mixBufferV, samples, coefsV, numV, chanBits, denShiftV)
                        
                    else
                        # uncompressed frame, copy data into the mix buffers to use common output code
                        chanBits = @config.bitDepth
                        shift = 32 - chanBits
                        
                        if (chanBits <= 16)
                            for i in [0 ... samples] by 1
                                val = (data.read(chanBits) << shift) >> shift
                                @mixBufferU[i] = val
                                
                                val = (data.read(chanBits) << shift) >> shift
                                @mixBufferV[i] = val
                            
                        else
                            for i in [0 ... samples] by 1
                                val = (data.readBig(chanBits) << shift) >> shift
                                @mixBufferU[i] = val
                                
                                val = (data.readBig(chanBits) << shift) >> shift
                                @mixBufferV[i] = val
                            
                        
                        mixBits = mixRes = 0
                        bits1 = chanBits * samples
                        bytesShifted = 0
                    
                    # now read the shifted values into the shift buffer
                    if bytesShifted != 0
                        shift = bytesShifted * 8
                        
                        for i in [0 ... samples * 2] by 2
                            @shiftBuffer[i + 0] = shiftbits.read(shift)
                            @shiftBuffer[i + 1] = shiftbits.read(shift)
                        
                    # un-mix the data and convert to output format
                    # - note that mixRes = 0 means just interleave so we use that path for uncompressed frames
                    switch @config.bitDepth
                        when 16
                            out16 = new Int16Array(output, channelIndex)
                            Matrixlib.unmix16(@mixBufferU, @mixBufferV, out16, channels, samples, mixBits, mixRes)
                            
                        else
                            console.log("Evil bit depth")
                            return -1231
                        
                    channelIndex += 2
                    return [status, output]
                    
                when ID_CCE, ID_PCE
                    console.log("Unsupported element")
                    return [ALAC.errors.paramError]
                    
                when ID_DSE
                    console.log("Data Stream element, ignoring")
                    
                    # the tag associates this data stream element with a given audio element
                    elementInstanceTag = data.readSmall(4)
                    dataByteAlignFlag = data.readOne()
                    
                    # 8-bit count or (8-bit + 8-bit count) if 8-bit count == 255
                    count = data.readSmall(8)
                    if count == 255
                        count += data.readSmall(8)
                    
                    # the align flag means the bitstream should be byte-aligned before reading the following data bytes
                    if dataByteAlignFlag
                        data.align()
                        
                    # skip the data bytes
                    data.advance(count * 8)
                    unless data.pos < data.length
                        console.log("My first overrun")
                        return [ALAC.errors.paramError]
                        
                    status = ALAC.errors.noError
                    
                when ID_FIL
                    console.log("Fill element, ignoring")
                    
                    # 4-bit count or (4-bit + 8-bit count) if 4-bit count == 15
                	# - plus this weird -1 thing I still don't fully understand
                    count = data.readSmall(4)
                    if count == 15
                        count += data.readSmall(8) - 1
                        
                    data.advance(count * 8)
                    unless data.pos < data.length
                        console.log("Another overrun")
                        return [ALAC.errors.paramError]
                        
                    status = ALAC.errors.noError
                    
                when ID_END
                    data.align()
                    
                else
                    console.log("Error in frame")
                    return [ALAC.errors.paramError]
            
            if channelIndex >= channels
                console.log("Channel Index is high:", data.pos - 0)
                
        return [status, output]
