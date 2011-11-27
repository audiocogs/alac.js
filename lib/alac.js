(function() {
  var ALAC, ALACDecoder, Aglib, BitBuffer, Data, Dplib, Matrixlib;

  ALAC = {};

  ALAC.channelAtomSize = 12;

  ALAC.maxChannels = 8;

  ALAC.maxEscapeHeaderBytes = 8;

  ALAC.maxSearches = 16;

  ALAC.maxCoefs = 16;

  ALAC.defaultFramesPerPacket = 4096;

  ALAC.errors = {
    noError: 0,
    unimplementedError: -4,
    fileNotFoundError: -43,
    paramError: -50,
    memFullError: -108
  };

  ALAC.formats = {
    appleLossless: 'alac',
    linearPCM: 'lpcm'
  };

  ALAC.sampleTypes = {
    isFloat: 1 << 0,
    isBigEndian: 1 << 1,
    isSignedInteger: 1 << 2,
    isPacked: 1 << 3,
    isAlignedHigh: 1 << 4
  };

  ALAC.channelLayouts = {
    mono: (100 << 16) | 1,
    stereo: (101 << 16) | 2,
    MPEG_3_0_B: (113 << 16) | 3,
    MPEG_4_0_B: (116 << 16) | 4,
    MPEG_5_0_D: (120 << 16) | 5,
    MPEG_5_1_D: (124 << 16) | 6,
    AAC_6_1: (142 << 16) | 7,
    MPEG_7_1_B: (127 << 16) | 8
  };

  ALAC.channelLayoutArray = [ALAC.channelLayouts.mono, ALAC.channelLayouts.stereo, ALAC.channelLayouts.MPEG_3_0_B, ALAC.channelLayouts.MPEG_4_0_B, ALAC.channelLayouts.MPEG_5_0_D, ALAC.channelLayouts.MPEG_5_1_D, ALAC.channelLayouts.AAC_6_1, ALAC.channelLayouts.MPEG_7_1_B];

  ALACDecoder = (function() {
    var ID_CCE, ID_CPE, ID_DSE, ID_END, ID_FIL, ID_LFE, ID_PCE, ID_SCE;

    window.ALACDecoder = ALACDecoder;

    ID_SCE = 0;

    ID_CPE = 1;

    ID_CCE = 2;

    ID_LFE = 3;

    ID_DSE = 4;

    ID_PCE = 5;

    ID_FIL = 6;

    ID_END = 7;

    function ALACDecoder(cookie) {
      var atom, data, offset, predictorBuffer, remaining, _ref;
      this.cookie = cookie;
      _ref = [0, this.cookie.byteLength], offset = _ref[0], remaining = _ref[1];
      data = new Data(this.cookie);
      atom = data.stringAt(4, 4);
      if (atom === 'frma') {
        console.log("Skipping 'frma'");
        data.advance(12);
      }
      atom = data.stringAt(4, 4);
      if (atom === 'alac') {
        console.log("Skipping 'alac'");
        data.advance(12);
      }
      if (data.remaining() < 24) {
        console.log("Cookie too short");
        return ALAC.errors.paramError;
      }
      this.config = {
        frameLength: data.readUInt32(),
        compatibleVersion: data.readUInt8(),
        bitDepth: data.readUInt8(),
        pb: data.readUInt8(),
        mb: data.readUInt8(),
        kb: data.readUInt8(),
        numChannels: data.readUInt8(),
        maxRun: data.readUInt16(),
        maxFrameBytes: data.readUInt32(),
        avgBitRate: data.readUInt32(),
        sampleRate: data.readUInt32()
      };
      console.log('cookie', this.config);
      this.mixBufferU = new Int32Array(this.config.frameLength);
      this.mixBufferV = new Int32Array(this.config.frameLength);
      predictorBuffer = new ArrayBuffer(this.config.frameLength * 4);
      this.predictor = new Int32Array(predictorBuffer);
      this.shiftBuffer = new Int16Array(predictorBuffer);
      return ALAC.errors.noError;
    }

    ALACDecoder.prototype.decode = function(data, offset, samples, channels) {
      var agParams, bits1, bytesShifted, chanBits, channelIndex, coefsU, coefsV, denShiftU, denShiftV, elementInstanceTag, escapeFlag, headerByte, i, maxBits, mixBits, mixRes, modeU, modeV, numU, numV, out16, outSamples, output, params, partialFrame, pb, pbFactorU, pbFactorV, shift, shiftbits, status, tag, unused, unusedHeader, val, _ref;
      if (!(channels > 0)) {
        console.log("Requested less than a single channel");
        return ALAC.errors.paramError;
      }
      this.activeElements = 0;
      channelIndex = 0;
      coefsU = new Int16Array(32);
      coefsV = new Int16Array(32);
      output = new ArrayBuffer(samples * channels * this.config.bitDepth / 8);
      offset *= 8;
      status = ALAC.errors.noError;
      while (status === ALAC.errors.noError) {
        pb = this.config.pb;
        tag = data.readSmall(3);
        switch (tag) {
          case ID_SCE:
          case ID_LFE:
            console.log("LFE or SCE element");
            elementInstanceTag = data.readSmall(4);
            this.activeElements |= 1 << elementInstanceTag;
            unused = data.read(12);
            if (unused !== 0) return ALAC.errors.paramError;
            headerByte = data.read(4);
            partialFrame = headerByte >> 3;
            bytesShifted = (headerByte >> 1) & 0x3;
            if (bytesShifted === 3) return ALAC.errors.paramError;
            shift = bytesShifted * 8;
            escapeFlag = headerByte & 0x1;
            chanBits = this.config.bitDepth - shift;
            if (partialFrame !== 0) {
              samples = data.read(16) << 16;
              samples |= data.read(16);
            }
            if (escapeFlag === 0) {
              mixBits = data.read(8);
              mixRes = data.read(8);
              headerByte = data.read(8);
              modeU = headerByte >> 4;
              denShiftU = headerByte & 0xf;
              headerByte = data.read(8);
              pbFactorU = headerByte >> 5;
              numU = headerByte & 0x1f;
              for (i = 0; 0 <= numU ? i < numU : i > numU; 0 <= numU ? i++ : i--) {
                coefsU[i] = data.read(16);
              }
              if (bytesShifted !== 0) data.advance(shift * samples);
              params = Aglib.ag_params(this.config.mb, (this.config.pb * pbFactorU) / 4, this.config.kb, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(params, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) return status;
              return;
              if (modeU === 0) {
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              } else {
                Dplib.unpc_block(this.predictor, this.predictor, samples, null, 31, chanBits, 0);
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              }
            } else {
              shift = 32 - chanBits;
              if (chanBits <= 16) {
                for (i = 0; 0 <= samples ? i < samples : i > samples; 0 <= samples ? i++ : i--) {
                  val = CSLoadManyBits(input, offset, chanBits);
                  offset += chanBits;
                  val = (val << shift) >> shift;
                  this.mixBufferU[i] = val;
                }
              } else {
                console.log("Failing, not less than 16 bits per channel");
                return -9000;
              }
              maxBits = mixRes = 0;
              bits1 = chanbits * samples;
              bytesShifted = 0;
            }
            if (bytesShifted !== 0) {
              shift = bytesShifted * 8;
              for (i = 0; 0 <= samples ? i < samples : i > samples; 0 <= samples ? i++ : i--) {
                this.shiftBuffer[i] = CSLoadManyBits(shiftBits, shift);
              }
            }
            switch (this.config.bitDepth) {
              case 16:
                console.log("16-bit output, yaay!");
                break;
              default:
                console.log("Only supports 16-bit samples right now");
                return -9000;
            }
            channelIndex += 1;
            outSamples = samples;
            break;
          case ID_CPE:
            console.log("CPE element");
            console.log("Channel Index", channelIndex);
            if ((channelIndex + 2) > channels) {
              console.log("No more channels, please");
            }
            elementInstanceTag = data.readSmall(4);
            console.log("Element Instance Tag", elementInstanceTag);
            this.activeElements |= 1 << elementInstanceTag;
            unusedHeader = data.read(12);
            if (unusedHeader !== 0) {
              console.log("Error! Unused header is silly");
              return ALAC.errors.paramError;
            }
            headerByte = data.read(4);
            console.log("Header Byte", headerByte);
            partialFrame = headerByte >>> 3;
            bytesShifted = (headerByte >>> 1) & 0x03;
            console.log("Partial Frame, Bytes Shifted", partialFrame, bytesShifted);
            if (bytesShifted === 3) {
              console.log("Moooom, the reference said that bytes shifted couldn't be 3!");
              return ALAC.errors.paramError;
            }
            escapeFlag = headerByte & 0x01;
            console.log("Escape Flag", escapeFlag);
            chanBits = this.config.bitDepth - (bytesShifted * 8) + 1;
            console.log("Channel Bits", chanBits);
            if (partialFrame !== 0) samples = data.read(16) << 16 + data.read(16);
            console.log("Samples", samples);
            if (escapeFlag === 0) {
              mixBits = data.read(8);
              mixRes = data.read(8);
              console.log("Mix Bits, Mix Res", mixBits, mixRes);
              headerByte = data.read(8);
              modeU = headerByte >>> 4;
              denShiftU = headerByte & 0x0F;
              console.log("Mode U, DenShift U", modeU, denShiftU);
              headerByte = data.read(8);
              pbFactorU = headerByte >>> 5;
              numU = headerByte & 0x1F;
              console.log("pbFactor U, Num U", pbFactorU, numU);
              for (i = 0; i < numU; i += 1) {
                coefsU[i] = data.read(16);
              }
              headerByte = data.read(8);
              modeV = headerByte >>> 4;
              denShiftV = headerByte & 0x0F;
              console.log("Mode V, DenShift V", modeV, denShiftV);
              headerByte = data.read(8);
              pbFactorV = headerByte >>> 5;
              numV = headerByte & 0x1F;
              console.log("pbFactor V, Num V", pbFactorU, numV);
              for (i = 0; i < numV; i += 1) {
                coefsV[i] = data.read(16);
              }
              console.log("Coefs U, V", coefsU, coefsV);
              if (bytesShifted !== 0) {
                shiftbits = data.copy();
                bits.advance((bytesShifted * 8) * 2 * samples);
              }
              console.log("Bytes Shifted", bytesShifted);
              console.log("AG: Left");
              agParams = Aglib.ag_params(this.config.mb, (pb * pbFactorU) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(agParams, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) {
                console.log("Mom said there should be no errors in the adaptive Goloumb code (part 2)…");
                return status;
              }
              console.log("Mode U", modeU);
              if (modeU === 0) {
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              } else {
                Dplib.unpc_block(this.predictor, this.predictor, samples, null, 31, chanBits, 0);
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              }
              console.log("AG: Right");
              agParams = Aglib.ag_params(this.config.mb, (pb * pbFactorV) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(agParams, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) {
                console.log("Mom said there should be no errors in the adaptive Goloumb code (part 2)…");
                return status;
              }
              console.log("Mode V", modeV);
              if (modeV === 0) {
                Dplib.unpc_block(this.predictor, this.mixBufferV, samples, coefsV, numV, chanBits, denShiftV);
              } else {
                Dplib.unpc_block(this.predictor, this.predictor, samples, null, 31, chanBits, 0);
                Dplib.unpc_block(this.predictor, this.mixBufferV, samples, coefsV, numV, chanBits, denShiftV);
              }
            } else {
              chanBits = this.config.bitDepth;
              shift = 32 - chanBits;
              if (chanBits <= 16) {
                for (i = 0; i < samples; i += 1) {
                  val = (data.read(chanBits) << shift) >> shift;
                  this.mixBufferU[i] = val;
                  val = (data.read(chanBits) << shift) >> shift;
                  this.mixBufferV[i] = val;
                }
              } else {
                for (i = 0; i < samples; i += 1) {
                  val = (data.readBig(chanBits) << shift) >> shift;
                  this.mixBufferU[i] = val;
                  val = (data.readBig(chanBits) << shift) >> shift;
                  this.mixBufferV[i] = val;
                }
              }
              console.log("Mix Buffer U, V", this.mixBufferU, this.mixBufferV);
              mixBits = mixRes = 0;
              bits1 = chanBits * samples;
              bytesShifted = 0;
            }
            console.log("Bytes Shifted", bytesShifted);
            if (bytesShifted !== 0) {
              shift = bytesShifted * 8;
              for (i = 0, _ref = samples * 2; i < _ref; i += 2) {
                this.shiftBuffer[i + 0] = shiftbits.read(shift);
                this.shiftBuffer[i + 1] = shiftbits.read(shift);
              }
            }
            switch (this.config.bitDepth) {
              case 16:
                out16 = new Int16Array(output, channelIndex);
                console.log("Channels, Samples, Mix Bits, Mix Res", channels, samples, mixBits, mixRes);
                Matrixlib.unmix16(this.mixBufferU, this.mixBufferV, out16, channels, samples, mixBits, mixRes);
                console.log("Output", out16[0], out16[1], out16[2], out16[3], out16[4], out16[5], "...", out16[1024], out16[1025], out16[1026], out16[1027], out16[1028], out16[1029]);
                break;
              default:
                console.log("Evil bit depth");
                return -1231;
            }
            channelIndex += 2;
            return [status, output];
          case ID_CCE:
          case ID_PCE:
            console.log("Unsupported element");
            return ALAC.errors.paramError;
          case ID_DSE:
            console.log("Data Stream element, ignoring");
            status = this.dataStreamElement(input, offset);
            break;
          case ID_FIL:
            console.log("Fill element, ignoring");
            status = this.fillElement(input, offset);
            break;
          case ID_END:
            console.log("End of frame", data.offset);
            data.align();
            break;
          default:
            console.log("Error in frame");
            return ALAC.errors.paramError;
        }
        if (channelIndex > channels) {
          console.log("Channel Index is higher than the amount of channels");
        }
      }
      return [status, output];
    };

    return ALACDecoder;

  })();

  Aglib = (function() {
    var BITOFF, KB0, MAX_DATATYPE_BITS_16, MAX_PREFIX_16, MAX_PREFIX_32, MAX_RUN_DEFAULT, MB0, MDENSHIFT, MMULSHIFT, MOFF, N_MAX_MEAN_CLAMP, N_MEAN_CLAMP_VAL, PB0, QB, QBSHIFT, dyn_get_16, dyn_get_32, get_next, lead, lg3a;

    function Aglib() {}

    PB0 = 40;

    MB0 = 10;

    KB0 = 14;

    MAX_RUN_DEFAULT = 255;

    MAX_PREFIX_16 = 9;

    MAX_PREFIX_32 = 9;

    QBSHIFT = 9;

    QB = 1 << QBSHIFT;

    MMULSHIFT = 2;

    MDENSHIFT = QBSHIFT - MMULSHIFT - 1;

    MOFF = 1 << (MDENSHIFT - 2);

    N_MAX_MEAN_CLAMP = 0xffff;

    N_MEAN_CLAMP_VAL = 0xffff;

    MMULSHIFT = 2;

    BITOFF = 24;

    MAX_DATATYPE_BITS_16 = 16;

    lead = function(m) {
      var c, i;
      c = 1 << 31;
      for (i = 0; i < 32; i += 1) {
        if ((c & m) !== 0) return i;
        c = c >>> 1;
      }
      return 32;
    };

    lg3a = function(x) {
      return 31 - lead(x + 3);
    };

    get_next = function(input, suff) {
      return input >>> (32 - suff);
    };

    dyn_get_16 = function(data, pos, m, k) {
      var bitsInPrefix, offs, result, stream, v;
      offs = data.pos;
      stream = data.peekBig(32 - offs) << offs;
      bitsInPrefix = lead(~stream);
      if (bitsInPrefix >= MAX_PREFIX_16) {
        data.advance(MAX_PREFIX_16 + MAX_DATATYPE_BITS_16);
        stream = stream << (bitsInPrefix + 1);
        result = stream >>> (32 - MAX_DATATYPE_BITS_16);
      } else {
        data.advance(bitsInPrefix + 1);
        if (k !== 1) {
          stream = stream << (bitsInPrefix + 1);
          result = bitsInPrefix * m;
          v = stream >>> (32 - k);
          data.advance(k);
          result = bitsInPrefix * m + v - 1;
          if (v < 2) {
            result -= v - 1;
            data.rewind(1);
          }
        }
      }
      return result;
    };

    dyn_get_32 = function(data, m, k, maxbits) {
      var bitsInPrefix, offs, result, stream, v;
      offs = data.pos;
      stream = data.peekBig(32 - offs) << offs;
      bitsInPrefix = lead(~stream);
      if (bitsInPrefix >= MAX_PREFIX_32) {
        data.advance(MAX_PREFIX_32);
        return data.readBig(maxbits);
      } else {
        data.advance(bitsInPrefix + 1);
        if (k !== 1) {
          stream = stream << (bitsInPrefix + 1);
          result = bitsInPrefix * m;
          v = stream >>> (32 - k);
          data.advance(k - 1);
          if (v > 1) {
            result += v - 1;
            data.advance(1);
          }
        }
      }
      return result;
    };

    Aglib.standard_ag_params = function(fullwidth, sectorwidth) {
      return this.ag_params(MB0, PB0, KB0, fullwidth, sectorwidth, MAX_RUN_DEFAULT);
    };

    Aglib.ag_params = function(m, p, k, f, s, maxrun) {
      return {
        mb: m,
        mb0: m,
        pb: p,
        kb: k,
        wb: (1 << k) - 1,
        qb: QB - p,
        fw: f,
        sw: s,
        maxrun: maxrun
      };
    };

    Aglib.dyn_decomp = function(params, data, pc, samples, maxSize) {
      var c, j, k, kb, m, mb, multiplier, mz, n, ndecode, pb, start, status, wb, zmode;
      pb = params.pb, kb = params.kb, wb = params.wb, mb = params.mb0;
      console.log("\tPC", pc);
      console.log("\tSamples, Max Size", samples, maxSize);
      start = data.copy();
      zmode = 0;
      c = 0;
      status = ALAC.errors.noError;
      while (c < samples) {
        m = mb >>> QBSHIFT;
        k = lg3a(m);
        k = Math.min(k, kb);
        m = (1 << k) - 1;
        n = dyn_get_32(data, m, k, maxSize);
        ndecode = n + zmode;
        multiplier = -(ndecode & 1) | 1;
        pc[c++] = ((ndecode + 1) >>> 1) * multiplier;
        mb = pb * (n + zmode) + mb - ((pb * mb) >>> QBSHIFT);
        if (n > N_MAX_MEAN_CLAMP) mb = N_MEAN_CLAMP_VAL;
        zmode = 0;
        if (((mb << MMULSHIFT) < QB) && (c < samples)) {
          zmode = 1;
          k = lead(mb) - BITOFF + ((mb + MOFF) >>> MDENSHIFT);
          mz = ((1 << k) - 1) & wb;
          n = dyn_get_16(data, mz, k);
          console.log("\t\tRecursive N", n);
          if (!(c + n <= samples)) {
            status = ALAC.error.paramError;
            break;
          }
          for (j = 0; j < n; j += 1) {
            pc[c++] = 0;
          }
          if (n >= 65535) zmode = 0;
          mb = 0;
        }
      }
      return status;
    };

    return Aglib;

  })();

  Data = (function() {

    window.Data = Data;

    function Data(data) {
      this.data = data;
      this.pos = 0;
      this.length = this.data.length;
    }

    Data.prototype.readByte = function() {
      return this.data[this.pos++];
    };

    Data.prototype.byteAt = function(index) {
      return this.data[index];
    };

    Data.prototype.readUInt32 = function() {
      var b1, b2, b3, b4;
      b1 = this.readByte() << 24 >>> 0;
      b2 = this.readByte() << 16;
      b3 = this.readByte() << 8;
      b4 = this.readByte();
      return b1 + (b2 | b3 | b4);
    };

    Data.prototype.readInt32 = function() {
      var int;
      int = this.readUInt32();
      if (int >= 0x80000000) {
        return int - 0x100000000;
      } else {
        return int;
      }
    };

    Data.prototype.readUInt64 = function() {
      return this.readUInt32() * 0x100000000 + this.readUInt32();
    };

    Data.prototype.readUInt16 = function() {
      var b1, b2;
      b1 = this.readByte() << 8;
      b2 = this.readByte();
      return b1 | b2;
    };

    Data.prototype.readInt16 = function() {
      var int;
      int = this.readUInt16();
      if (int >= 0x8000) {
        return int - 0x10000;
      } else {
        return int;
      }
    };

    Data.prototype.readUInt8 = function() {
      return this.readByte();
    };

    Data.prototype.readInt8 = function() {
      return this.readByte();
    };

    Data.prototype.readFloat = function() {
      var exp, frac, num, sign;
      num = this.readUInt32();
      if (!num || num === 0x80000000) return 0.0;
      sign = (num >> 31) * 2 + 1;
      exp = (num >> 23) & 0xff;
      frac = num & 0x7fffff;
      if (exp === 0xff) {
        if (frac) {
          return NaN;
        } else {
          return sign * Infinity;
        }
      }
      return sign * (frac | 0x00800000) * Math.pow(2, exp - 127 - 23);
    };

    Data.prototype.readDouble = function() {
      var exp, frac, high, low, sign;
      high = this.readUInt32();
      low = this.readUInt32();
      if (!high || high === 0x80000000) return 0.0;
      sign = (high >> 31) * 2 + 1;
      exp = (high >> 20) & 0x7ff;
      frac = high & 0xfffff;
      if (exp === 0x7ff) {
        if (frac) {
          return NaN;
        } else {
          return sign * Infinity;
        }
      }
      return sign * ((frac | 0x100000) * Math.pow(2, exp - 1023 - 20) + low * Math.pow(2, exp - 1023 - 52));
    };

    Data.prototype.readString = function(length) {
      var value;
      value = this.stringAt(0, length);
      this.advance(length);
      return value;
    };

    Data.prototype.stringAt = function(pos, length) {
      var i, ret, _ref, _ref2;
      ret = [];
      for (i = _ref = this.pos + pos, _ref2 = this.pos + pos + length; i < _ref2; i += 1) {
        ret[i] = String.fromCharCode(this.data[i]);
      }
      return ret.join('');
    };

    Data.prototype.slice = function(start, end) {
      return this.data.subarray(start, end);
    };

    Data.prototype.read = function(bytes) {
      var buf, i;
      buf = [];
      for (i = 0; 0 <= bytes ? i < bytes : i > bytes; 0 <= bytes ? i++ : i--) {
        buf.push(this.readByte());
      }
      return buf;
    };

    Data.prototype.advance = function(bytes) {
      return this.pos += bytes;
    };

    Data.prototype.rewind = function(bytes) {
      return this.pos -= bytes;
    };

    Data.prototype.remaining = function() {
      return this.length - this.pos;
    };

    return Data;

  })();

  BitBuffer = (function() {

    window.BitBuffer = BitBuffer;

    function BitBuffer(data) {
      this.data = data;
      this.pos = 0;
      this.offset = 0;
      this.length = this.data.length * 8;
    }

    BitBuffer.prototype.readBig = function(bits) {
      var a;
      a = (this.data[this.offset + 0] * Math.pow(2, 32)) + (this.data[this.offset + 1] * Math.pow(2, 24)) + (this.data[this.offset + 2] * Math.pow(2, 16)) + (this.data[this.offset + 3] * Math.pow(2, 8)) + (this.data[this.offset + 4] * Math.pow(2, 0));
      a = a % Math.pow(2, 40 - this.pos);
      a = a / Math.pow(2, 40 - this.pos - bits);
      this.advance(bits);
      return a << 0;
    };

    BitBuffer.prototype.read = function(bits) {
      var a;
      a = (this.data[this.offset + 0] << 16) + (this.data[this.offset + 1] << 8) + (this.data[this.offset + 2] << 0);
      a = (a << this.pos) & 0xFFFFFF;
      this.advance(bits);
      return a >>> (24 - bits);
    };

    BitBuffer.prototype.readSmall = function(bits) {
      var a;
      a = (this.data[this.offset + 0] << 8) + (this.data[this.offset + 1] << 0);
      a = (a << this.pos) & 0xFFFF;
      this.advance(bits);
      return a >>> (16 - bits);
    };

    BitBuffer.prototype.peekBig = function(bits) {
      var v;
      v = this.readBig(bits);
      this.rewind(bits);
      return v;
    };

    BitBuffer.prototype.advance = function(bits) {
      this.pos += bits;
      this.offset += this.pos >> 3;
      return this.pos &= 7;
    };

    BitBuffer.prototype.rewind = function(bits) {
      return this.advance(-bits);
    };

    BitBuffer.prototype.align = function() {
      if (this.pos !== 0) return this.advance(8 - this.pos);
    };

    BitBuffer.prototype.copy = function() {
      var bit;
      bit = new BitBuffer(this.data);
      bit.pos = this.pos;
      bit.offset = this.offset;
      return bit;
    };

    return BitBuffer;

  })();

  Dplib = (function() {
    var copy;

    function Dplib() {}

    copy = function(dst, dstOffset, src, srcOffset, n) {
      var destination, source;
      destination = new Uint8Array(dst, dstOffset, n);
      source = new Uint8Array(src, srcOffset, n);
      destination.set(source);
      return dst;
    };

    Dplib.unpc_block = function(pc1, out, num, coefs, active, chanbits, denshift) {
      var chanshift, dd, del, del0, denhalf, i, j, lim, offset, prev, sg, sgn, sum1, top, _ref, _ref2;
      chanshift = 32 - chanbits;
      denhalf = 1 << (denshift - 1);
      out[0] = pc1[0];
      console.log("\tChanshift, Denhalf, Active", chanshift, denhalf, active);
      console.log("\tPC1", pc1);
      if (active === 0) return copy(out, 0, pc1, 0, num * 4);
      if (active === 31) {
        debug();
        prev = out[0];
        for (i = 1; 1 <= num ? i < num : i > num; 1 <= num ? i++ : i--) {
          del = pcl[i] + prev;
          prev = (del << chanshift) >> chanshift;
          out[i] = prev;
        }
        return;
      }
      for (i = 1; i <= active; i += 1) {
        del = pc1[i] + out[i - 1];
        out[i] = (del << chanshift) >> chanshift;
      }
      lim = active + 1;
      sum1 = 0;
      for (i = lim; i < num; i += 1) {
        sum1 = 0;
        top = out[i - lim];
        offset = i - 1;
        for (j = 0; j < active; j += 1) {
          sum1 += coefs[j] * (out[offset - j] - top);
        }
        del = del0 = pc1[i];
        sg = (-del >>> 31) | (del >> 31);
        del += top + ((sum1 + denhalf) >> denshift);
        out[i] = (del << chanshift) >> chanshift;
        if (sg > 0) {
          for (j = _ref = active - 1; j >= 0; j += -1) {
            dd = top - out[offset - j];
            sgn = (-dd >>> 31) | (dd >> 31);
            coefs[j] -= sgn;
            del0 -= (active - j) * ((sgn * dd) >> denshift);
            if (del0 <= 0) break;
          }
        } else if (sg < 0) {
          for (j = _ref2 = active - 1; j >= 0; j += -1) {
            dd = top - out[offset - j];
            sgn = (-dd >>> 31) | (dd >> 31);
            coefs[j] += sgn;
            del0 -= (active - j) * ((-sgn * dd) >> denshift);
            if (del0 >= 0) break;
          }
        }
      }
      console.log("\tLast Sum", sum1);
      return console.log("\tOutput", out);
    };

    return Dplib;

  })();

  Matrixlib = (function() {

    function Matrixlib() {}

    Matrixlib.unmix16 = function(u, v, out, stride, samples, mixbits, mixres) {
      var i, l;
      console.log("Stride, Samples, Mix Bits, Mix Res", stride, samples, mixbits, mixres);
      console.log("U, V", u, v);
      if (mixres === 0) {
        console.log("Outputting Separated Stereo");
        for (i = 0; i < samples; i += 1) {
          out[i * stride + 0] = u[i];
          out[i * stride + 1] = v[i];
        }
      } else {
        console.log("Outputting Matrixed Stereo");
        for (i = 0; i < samples; i += 1) {
          l = u[i] + v[i] - ((mixres * v[i]) >> mixbits);
          out[i * stride + 0] = l;
          out[i * stride + 1] = l - v[i];
        }
      }
      return console.log(samples * stride);
    };

    return Matrixlib;

  })();

}).call(this);
