(function() {
  var ALAC, ALACDecoder, Aglib, AuroraALACDecoder, BitBuffer, Data, Dplib, Matrixlib;

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
        return [ALAC.errors.paramError];
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

    ALACDecoder.prototype.decode = function(data, samples, channels) {
      var agParams, bits1, bytesShifted, chanBits, channelIndex, coefsU, coefsV, count, dataByteAlignFlag, denShiftU, denShiftV, elementInstanceTag, escapeFlag, headerByte, i, j, maxBits, mixBits, mixRes, modeU, modeV, numU, numV, out16, output, params, partialFrame, pb, pbFactorU, pbFactorV, shift, shiftbits, status, tag, unused, unusedHeader, val, _ref;
      if (!(channels > 0)) {
        console.log("Requested less than a single channel");
        return [ALAC.errors.paramError];
      }
      this.activeElements = 0;
      channelIndex = 0;
      coefsU = new Int16Array(32);
      coefsV = new Int16Array(32);
      output = new ArrayBuffer(samples * channels * this.config.bitDepth / 8);
      status = ALAC.errors.noError;
      while (status === ALAC.errors.noError) {
        pb = this.config.pb;
        tag = data.readSmall(3);
        console.log("Tag: " + tag);
        switch (tag) {
          case ID_SCE:
          case ID_LFE:
            elementInstanceTag = data.readSmall(4);
            this.activeElements |= 1 << elementInstanceTag;
            unused = data.read(12);
            if (unused !== 0) {
              console.log("Unused part of header does not contain 0, it should");
              return [ALAC.errors.paramError];
            }
            headerByte = data.read(4);
            partialFrame = headerByte >>> 3;
            bytesShifted = (headerByte >>> 1) & 0x3;
            if (bytesShifted === 3) {
              console.log("Bytes are shifted by 3, they shouldn't be");
              return [ALAC.errors.paramError];
            }
            shift = bytesShifted * 8;
            escapeFlag = headerByte & 0x1;
            chanBits = this.config.bitDepth - shift;
            if (partialFrame !== 0) samples = data.read(16) << 16 + data.read(16);
            if (escapeFlag === 0) {
              mixBits = data.read(8);
              mixRes = data.read(8);
              headerByte = data.read(8);
              modeU = headerByte >>> 4;
              denShiftU = headerByte & 0xf;
              headerByte = data.read(8);
              pbFactorU = headerByte >>> 5;
              numU = headerByte & 0x1f;
              for (i = 0; i < numU; i += 1) {
                coefsU[i] = data.read(16);
              }
              if (bytesShifted !== 0) {
                shiftbits = data.copy();
                data.advance(shift * samples);
              }
              params = Aglib.ag_params(this.config.mb, (this.config.pb * pbFactorU) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(params, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) return status;
              if (modeU === 0) {
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              } else {
                Dplib.unpc_block(this.predictor, this.predictor, samples, null, 31, chanBits, 0);
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              }
            } else {
              shift = 32 - chanBits;
              if (chanBits <= 16) {
                for (i = 0; i < samples; i += 1) {
                  val = (data.read(chanBits) << shift) >> shift;
                  this.mixBufferU[i] = val;
                }
              } else {
                for (i = 0; i < samples; i += 1) {
                  val = (data.readBig(chanBits) << shift) >> shift;
                  this.mixBufferU[i] = val;
                }
              }
              maxBits = mixRes = 0;
              bits1 = chanbits * samples;
              bytesShifted = 0;
            }
            if (bytesShifted !== 0) {
              shift = bytesShifted * 8;
              for (i = 0; 0 <= samples ? i < samples : i > samples; 0 <= samples ? i++ : i--) {
                this.shiftBuffer[i] = shiftbits.read(shift);
              }
            }
            switch (this.config.bitDepth) {
              case 16:
                out16 = new Int16Array(output, channelIndex);
                j = 0;
                for (i = 0; i < samples; i += 1) {
                  out16[j] = this.mixBufferU[i];
                  j += channels;
                }
                break;
              default:
                console.log("Only supports 16-bit samples right now");
                return -9000;
            }
            channelIndex += 1;
            return [status, output];
          case ID_CPE:
            if ((channelIndex + 2) > channels) {
              console.log("No more channels, please");
            }
            elementInstanceTag = data.readSmall(4);
            this.activeElements |= 1 << elementInstanceTag;
            unusedHeader = data.read(12);
            if (unusedHeader !== 0) {
              console.log("Error! Unused header is silly");
              return [ALAC.errors.paramError];
            }
            headerByte = data.read(4);
            partialFrame = headerByte >>> 3;
            bytesShifted = (headerByte >>> 1) & 0x03;
            if (bytesShifted === 3) {
              console.log("Moooom, the reference said that bytes shifted couldn't be 3!");
              return [ALAC.errors.paramError];
            }
            escapeFlag = headerByte & 0x01;
            chanBits = this.config.bitDepth - (bytesShifted * 8) + 1;
            if (partialFrame !== 0) samples = data.read(16) << 16 + data.read(16);
            if (escapeFlag === 0) {
              mixBits = data.read(8);
              mixRes = data.read(8);
              headerByte = data.read(8);
              modeU = headerByte >>> 4;
              denShiftU = headerByte & 0x0F;
              headerByte = data.read(8);
              pbFactorU = headerByte >>> 5;
              numU = headerByte & 0x1F;
              for (i = 0; i < numU; i += 1) {
                coefsU[i] = data.read(16);
              }
              headerByte = data.read(8);
              modeV = headerByte >>> 4;
              denShiftV = headerByte & 0x0F;
              headerByte = data.read(8);
              pbFactorV = headerByte >>> 5;
              numV = headerByte & 0x1F;
              for (i = 0; i < numV; i += 1) {
                coefsV[i] = data.read(16);
              }
              if (bytesShifted !== 0) {
                shiftbits = data.copy();
                bits.advance((bytesShifted * 8) * 2 * samples);
              }
              agParams = Aglib.ag_params(this.config.mb, (pb * pbFactorU) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(agParams, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) {
                console.log("Mom said there should be no errors in the adaptive Goloumb code (part 1)...");
                return status;
              }
              if (modeU === 0) {
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              } else {
                Dplib.unpc_block(this.predictor, this.predictor, samples, null, 31, chanBits, 0);
                Dplib.unpc_block(this.predictor, this.mixBufferU, samples, coefsU, numU, chanBits, denShiftU);
              }
              agParams = Aglib.ag_params(this.config.mb, (pb * pbFactorV) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(agParams, data, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) {
                console.log("Mom said there should be no errors in the adaptive Goloumb code (part 2)...");
                return status;
              }
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
              mixBits = mixRes = 0;
              bits1 = chanBits * samples;
              bytesShifted = 0;
            }
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
                Matrixlib.unmix16(this.mixBufferU, this.mixBufferV, out16, channels, samples, mixBits, mixRes);
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
            return [ALAC.errors.paramError];
          case ID_DSE:
            console.log("Data Stream element, ignoring");
            elementInstanceTag = data.readSmall(4);
            dataByteAlignFlag = data.readOne();
            count = data.readSmall(8);
            if (count === 255) count += data.readSmall(8);
            if (dataByteAlignFlag) data.align();
            data.advance(count * 8);
            if (!(data.pos < data.length)) {
              console.log("My first overrun");
              return [ALAC.errors.paramError];
            }
            status = ALAC.errors.noError;
            break;
          case ID_FIL:
            console.log("Fill element, ignoring");
            count = data.readSmall(4);
            if (count === 15) count += data.readSmall(8) - 1;
            data.advance(count * 8);
            if (!(data.pos < data.length)) {
              console.log("Another overrun");
              return [ALAC.errors.paramError];
            }
            status = ALAC.errors.noError;
            break;
          case ID_END:
            data.align();
            break;
          default:
            console.log("Error in frame");
            return [ALAC.errors.paramError];
        }
        if (channelIndex >= channels) {
          console.log("Channel Index is high:", data.pos - 0);
        }
      }
      return [status, output];
    };

    return ALACDecoder;

  })();

  Aglib = (function() {
    var BITOFF, KB0, MAX_DATATYPE_BITS_16, MAX_PREFIX_16, MAX_PREFIX_32, MAX_RUN_DEFAULT, MB0, MDENSHIFT, MMULSHIFT, MOFF, N_MAX_MEAN_CLAMP, N_MEAN_CLAMP_VAL, PB0, QB, QBSHIFT, dyn_get_16, dyn_get_32, lead;

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

    N_MAX_MEAN_CLAMP = 0xFFFF;

    N_MEAN_CLAMP_VAL = 0xFFFF;

    MMULSHIFT = 2;

    BITOFF = 24;

    MAX_DATATYPE_BITS_16 = 16;

    lead = function(m) {
      var c, i;
      c = 1 << 31;
      for (i = 0; i < 32; i += 1) {
        if ((c & m) !== 0) return i;
        c >>>= 1;
      }
      return 32;
    };

    dyn_get_16 = function(data, m, k) {
      var bitsInPrefix, offs, result, stream, v;
      offs = data.pos;
      stream = data.readBig(32 - offs, false) << offs;
      bitsInPrefix = lead(~stream);
      if (bitsInPrefix >= MAX_PREFIX_16) {
        data.advance(MAX_PREFIX_16 + MAX_DATATYPE_BITS_16);
        stream <<= MAX_PREFIX_16;
        result = stream >>> (32 - MAX_DATATYPE_BITS_16);
      } else {
        data.advance(bitsInPrefix + k);
        stream <<= bitsInPrefix + 1;
        v = stream >>> (32 - k);
        result = bitsInPrefix * m + v - 1;
        if (v < 2) {
          result -= v - 1;
        } else {
          data.advance(1);
        }
      }
      return result;
    };

    dyn_get_32 = function(data, m, k, maxbits) {
      var offs, result, stream, v;
      offs = data.pos;
      stream = data.readBig(32 - offs, false) << offs;
      result = lead(~stream);
      if (result >= MAX_PREFIX_32) {
        data.advance(MAX_PREFIX_32);
        return data.readBig(maxbits);
      } else {
        data.advance(result + 1);
        if (k !== 1) {
          stream <<= result + 1;
          result *= m;
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
      var c, j, k, kb, m, mb, multiplier, mz, n, ndecode, pb, status, wb, zmode;
      pb = params.pb, kb = params.kb, wb = params.wb, mb = params.mb0;
      zmode = 0;
      c = 0;
      status = ALAC.errors.noError;
      while (c < samples) {
        m = mb >>> QBSHIFT;
        k = Math.min(31 - lead(m + 3), kb);
        m = (1 << k) - 1;
        n = dyn_get_32(data, m, k, maxSize);
        ndecode = n + zmode;
        multiplier = -(ndecode & 1) | 1;
        pc[c++] = ((ndecode + 1) >>> 1) * multiplier;
        mb = pb * (n + zmode) + mb - ((pb * mb) >> QBSHIFT);
        if (n > N_MAX_MEAN_CLAMP) mb = N_MEAN_CLAMP_VAL;
        zmode = 0;
        if (((mb << MMULSHIFT) < QB) && (c < samples)) {
          zmode = 1;
          k = lead(mb) - BITOFF + ((mb + MOFF) >> MDENSHIFT);
          mz = ((1 << k) - 1) & wb;
          n = dyn_get_16(data, mz, k);
          if (!(c + n <= samples)) return ALAC.errors.paramError;
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

  AuroraALACDecoder = (function() {

    function AuroraALACDecoder(name) {
      var _this = this;
      this.name = name;
      this.inputs = {
        metadata: {
          send: function(object) {
            return _this.setMetadata(object);
          },
          mode: "Passive"
        },
        cookie: {
          send: function(buffer) {
            return _this.setCookie(buffer);
          },
          mode: "Passive"
        },
        data: {
          send: function(buffer) {
            return _this.enqueueBuffer(buffer);
          },
          mode: "Passive"
        }
      };
      this.outputs = {};
      this.list = new Aurora.BufferList();
      this.stream = new Aurora.Stream(this.list);
      this.bitstream = new Aurora.Bitstream(this.stream);
      this.decoder = null;
      this.metadata;
      this.packetsDecoded = 0;
      this.reset();
    }

    AuroraALACDecoder.prototype.setMetadata = function(object) {
      this.metadata = object;
      return this;
    };

    AuroraALACDecoder.prototype.setCookie = function(buffer) {
      this.decoder = new ALACDecoder(buffer.data);
      this.enqueueBuffer(null);
    };

    AuroraALACDecoder.prototype.enqueueBuffer = function(buffer) {
      var out, result, _results;
      if (buffer) this.list.push(buffer);
      if (this.decoder) {
        _results = [];
        while ((this.bitstream.available(8) && buffer.final) || this.bitstream.available(4096 << 6)) {
          out = this.decoder.decode(this.bitstream, this.metadata.format.framesPerPacket, this.metadata.format.channelsPerFrame);
          if (out[0] !== 0) {
            console.log("Error in ALAC (" + out[0] + ")");
            debugger;
          }
          if (out[1]) {
            result = new Aurora.Buffer(new Uint8Array(out[1]));
            result.duration = this.metadata.format.framesPerPacket / this.metadata.format.samplingFrequency * 1e9;
            result.timestamp = this.packetsDecoded * result.duration;
            result.final = this.bitstream.availableBytes === 0;
            this.packetsDecoded += 1;
            _results.push(this.outputs.audio.send(result));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      }
    };

    AuroraALACDecoder.prototype.start = function() {
      this.status = "Started";
      return this;
    };

    AuroraALACDecoder.prototype.pause = function() {
      this.status = "Paused";
      return this;
    };

    AuroraALACDecoder.prototype.reset = function() {
      this.status = "Paused";
      return this;
    };

    AuroraALACDecoder.prototype.finished = function() {
      this.status = "Finished";
      return this;
    };

    return AuroraALACDecoder;

  })();

  if (!window.Aurora) window.Aurora = {};

  window.Aurora.ALACDecoder = AuroraALACDecoder;

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
    var TWO_16, TWO_24, TWO_32, TWO_8;

    window.BitBuffer = BitBuffer;

    function BitBuffer(data) {
      this.data = data;
      this.pos = 0;
      this.offset = 0;
      this.length = this.data.length * 8;
    }

    TWO_32 = Math.pow(2, 32);

    TWO_24 = Math.pow(2, 24);

    TWO_16 = Math.pow(2, 16);

    TWO_8 = Math.pow(2, 8);

    BitBuffer.prototype.readBig = function(bits, advance) {
      var a;
      a = (this.data[this.offset + 0] * TWO_32) + (this.data[this.offset + 1] * TWO_24) + (this.data[this.offset + 2] * TWO_16) + (this.data[this.offset + 3] * TWO_8) + this.data[this.offset + 4];
      a = a % Math.pow(2, 40 - this.pos);
      a = a / Math.pow(2, 40 - this.pos - bits);
      if (advance !== false) this.advance(bits);
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

    BitBuffer.prototype.readOne = function() {
      var bits;
      bits = this.data[this.offset] >>> (7 - this.pos) & 1;
      this.advance(1);
      return bits;
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
      var a0, a1, a2, a3, a4, a5, a6, a7, b0, b1, b2, b3, b4, b5, b6, b7, chanshift, dd, del, del0, denhalf, i, j, lim, offset, prev, sg, sgn, sum1, top, _ref, _ref2;
      chanshift = 32 - chanbits;
      denhalf = 1 << (denshift - 1);
      out[0] = pc1[0];
      if (active === 0) return copy(out, 0, pc1, 0, num * 4);
      if (active === 31) {
        prev = out[0];
        for (i = 1; i < num; i += 1) {
          del = pc1[i] + prev;
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
      if (active === 4) {
        a0 = coefs[0], a1 = coefs[1], a2 = coefs[2], a3 = coefs[3];
        for (j = lim; j < num; j += 1) {
          top = out[j - lim];
          offset = j - 1;
          b0 = top - out[offset];
          b1 = top - out[offset - 1];
          b2 = top - out[offset - 2];
          b3 = top - out[offset - 3];
          sum1 = (denhalf - a0 * b0 - a1 * b1 - a2 * b2 - a3 * b3) >> denshift;
          del = del0 = pc1[j];
          sg = (-del >>> 31) | (del >> 31);
          del += top + sum1;
          out[j] = (del << chanshift) >> chanshift;
          if (sg > 0) {
            sgn = (-b3 >>> 31) | (b3 >> 31);
            a3 -= sgn;
            del0 -= 1 * ((sgn * b3) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b2 >>> 31) | (b2 >> 31);
            a2 -= sgn;
            del0 -= 2 * ((sgn * b2) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b1 >>> 31) | (b1 >> 31);
            a1 -= sgn;
            del0 -= 3 * ((sgn * b1) >> denshift);
            if (del0 <= 0) continue;
            a0 -= (-b0 >>> 31) | (b0 >> 31);
          } else if (sg < 0) {
            sgn = -((-b3 >>> 31) | (b3 >> 31));
            a3 -= sgn;
            del0 -= 1 * ((sgn * b3) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b2 >>> 31) | (b2 >> 31));
            a2 -= sgn;
            del0 -= 2 * ((sgn * b2) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b1 >>> 31) | (b1 >> 31));
            a1 -= sgn;
            del0 -= 3 * ((sgn * b1) >> denshift);
            if (del0 >= 0) continue;
            a0 += (-b0 >>> 31) | (b0 >> 31);
          }
        }
        coefs[0] = a0;
        coefs[1] = a1;
        coefs[2] = a2;
        coefs[3] = a3;
      } else if (active === 8) {
        a0 = coefs[0], a1 = coefs[1], a2 = coefs[2], a3 = coefs[3], a4 = coefs[4], a5 = coefs[5], a6 = coefs[6], a7 = coefs[7];
        for (j = lim; j < num; j += 1) {
          top = out[j - lim];
          offset = j - 1;
          b0 = top - out[offset];
          b1 = top - out[offset - 1];
          b2 = top - out[offset - 2];
          b3 = top - out[offset - 3];
          b4 = top - out[offset - 4];
          b5 = top - out[offset - 5];
          b6 = top - out[offset - 6];
          b7 = top - out[offset - 7];
          sum1 = (denhalf - a0 * b0 - a1 * b1 - a2 * b2 - a3 * b3 - a4 * b4 - a5 * b5 - a6 * b6 - a7 * b7) >> denshift;
          del = del0 = pc1[j];
          sg = (-del >>> 31) | (del >> 31);
          del += top + sum1;
          out[j] = (del << chanshift) >> chanshift;
          if (sg > 0) {
            sgn = (-b7 >>> 31) | (b7 >> 31);
            a7 -= sgn;
            del0 -= 1 * ((sgn * b7) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b6 >>> 31) | (b6 >> 31);
            a6 -= sgn;
            del0 -= 2 * ((sgn * b6) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b5 >>> 31) | (b5 >> 31);
            a5 -= sgn;
            del0 -= 3 * ((sgn * b5) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b4 >>> 31) | (b4 >> 31);
            a4 -= sgn;
            del0 -= 4 * ((sgn * b4) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b3 >>> 31) | (b3 >> 31);
            a3 -= sgn;
            del0 -= 5 * ((sgn * b3) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b2 >>> 31) | (b2 >> 31);
            a2 -= sgn;
            del0 -= 6 * ((sgn * b2) >> denshift);
            if (del0 <= 0) continue;
            sgn = (-b1 >>> 31) | (b1 >> 31);
            a1 -= sgn;
            del0 -= 7 * ((sgn * b1) >> denshift);
            if (del0 <= 0) continue;
            a0 -= (-b0 >>> 31) | (b0 >> 31);
          } else if (sg < 0) {
            sgn = -((-b7 >>> 31) | (b7 >> 31));
            a7 -= sgn;
            del0 -= 1 * ((sgn * b7) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b6 >>> 31) | (b6 >> 31));
            a6 -= sgn;
            del0 -= 2 * ((sgn * b6) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b5 >>> 31) | (b5 >> 31));
            a5 -= sgn;
            del0 -= 3 * ((sgn * b5) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b4 >>> 31) | (b4 >> 31));
            a4 -= sgn;
            del0 -= 4 * ((sgn * b4) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b3 >>> 31) | (b3 >> 31));
            a3 -= sgn;
            del0 -= 5 * ((sgn * b3) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b2 >>> 31) | (b2 >> 31));
            a2 -= sgn;
            del0 -= 6 * ((sgn * b2) >> denshift);
            if (del0 >= 0) continue;
            sgn = -((-b1 >>> 31) | (b1 >> 31));
            a1 -= sgn;
            del0 -= 7 * ((sgn * b1) >> denshift);
            if (del0 >= 0) continue;
            a0 += (-b0 >>> 31) | (b0 >> 31);
          }
        }
        coefs[0] = a0;
        coefs[1] = a1;
        coefs[2] = a2;
        coefs[3] = a3;
        coefs[4] = a4;
        coefs[5] = a5;
        coefs[6] = a6;
        coefs[7] = a7;
      } else {
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
      }
    };

    return Dplib;

  })();

  Matrixlib = (function() {

    function Matrixlib() {}

    Matrixlib.unmix16 = function(u, v, out, stride, samples, mixbits, mixres) {
      var i, l;
      if (mixres === 0) {
        for (i = 0; i < samples; i += 1) {
          out[i * stride + 0] = u[i];
          out[i * stride + 1] = v[i];
        }
      } else {
        for (i = 0; i < samples; i += 1) {
          l = u[i] + v[i] - ((mixres * v[i]) >> mixbits);
          out[i * stride + 0] = l;
          out[i * stride + 1] = l - v[i];
        }
      }
    };

    return Matrixlib;

  })();

}).call(this);
