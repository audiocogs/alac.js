class ALACDecoder
    constructor: (magicCookie) ->
        cookie = new Data(magicCookie)
        cookie.pos = 4
        
        # For historical reasons the decoder needs to be resilient to magic cookies vended by older encoders.
        # As specified in the ALACMagicCookieDescription.txt document, there may be additional data encapsulating 
        # the ALACSpecificConfig. This would consist of format ('frma') and 'alac' atoms which precede the
        # ALACSpecificConfig. 
        # See ALACMagicCookieDescription.txt for additional documentation concerning the 'magic cookie'
        
        # skip format ('frma') atom if present
        if cookie.readString(4) is 'frma'
            cookie.pos += 12
        
        # skip 'alac' atom header if present    
        if cookie.readString(3) is 'alac'
            cookie.pos += 12
            
        # read the ALACSpecificConfig
        @config = 
            frameLength: cookie.readUInt32()
            compatibleVersion: cookie.readUInt8()
            bitDepth: cookie.readUInt8()
            pb: cookie.readUInt8()
            mb: cookie.readUInt8()
            kb: cookie.readUInt8()
            numChannels: cookie.readUInt8()
            maxRun: cookie.readUInt16()
            maxFrameBytes: cookie.readUInt32()
            avgBitRage: cookie.readUInt32()
            sampleRate: cookie.readUInt32()
            
        @mixBufferU = new Uint32Array(@config.frameLength * 4)
        @mixBufferV = new Uint32Array(@config.frameLength * 4)
        @predictor = new Uint32Array(@config.frameLength * 4)
        #@shiftBuffer = new Uint16Array(@predictor)
        
    decode: (input, output, numSamples, numChannels) ->
        data = new Data(input)
        activeElements = channelIndex = 0
        
        # TODO: complete