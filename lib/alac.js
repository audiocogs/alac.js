(function() {
  var ALAC, ALACDecoder, Aglib, Data, Dplib, Matrixlib;
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
      var offset, predictorBuffer, remaining, _ref;
      this.cookie = cookie;
      _ref = [0, this.cookie.byteLength], offset = _ref[0], remaining = _ref[1];
      if (CSCompareToString(this.cookie, offset + 4, 'frma', 0, 4)) {
        offset += 12;
        remaining -= 12;
        console.log("Skipping 'frma'");
      }
      if (CSCompareToString(cookie, offset + 4, 'alac', 0, 4)) {
        offset += 12;
        remaining -= 12;
        console.log("Skipping 'alac'");
      }
      if (remaining < 24) {
        console.log("Cookie too short");
        return ALAC.errors.paramError;
      }
      this.config = {
        frameLength: CSLoadBigUInt32(cookie, offset + 0),
        compatibleVersion: CSLoadUInt8(cookie, offset + 4),
        bitDepth: CSLoadUInt8(cookie, offset + 5),
        pb: CSLoadUInt8(cookie, offset + 6),
        mb: CSLoadUInt8(cookie, offset + 7),
        kb: CSLoadUInt8(cookie, offset + 8),
        numChannels: CSLoadUInt8(cookie, offset + 9),
        maxRun: CSLoadBigUInt16(cookie, offset + 10),
        maxFrameBytes: CSLoadBigUInt32(cookie, offset + 12),
        avgBitRage: CSLoadBigUInt32(cookie, offset + 16),
        sampleRate: CSLoadBigUInt32(cookie, offset + 20)
      };
      console.log(this.config);
      this.mixBufferU = new Int32Array(this.config.frameLength);
      this.mixBufferV = new Int32Array(this.config.frameLength);
      predictorBuffer = CSAlloc(this.config.frameLength * 4);
      this.predictor = new Int32Array(predictorBuffer);
      this.shiftBuffer = new Int16Array(predictorBuffer);
      return ALAC.errors.noError;
    }
    ALACDecoder.prototype.decode = function(input, offset, samples, channels) {
      var bits1, bytesShifted, chanBits, channelIndex, coefsU, coefsV, denShiftU, elementInstanceTag, escapeFlag, headerByte, i, input_a, maxBits, mixBits, mixRes, modeU, numU, outSamples, output, params, partialFrame, pbFactorU, shift, status, tag, unused, val;
      if (!(channels > 0)) {
        console.log("Requested less than a single channel");
        return ALAC.errors.paramError;
      }
      this.activeElements = 0;
      channelIndex = 0;
      coefsU = new Int16Array(32);
      coefsV = new Int16Array(32);
      output = CSAlloc(samples * channels * this.config.bitDepth / 8);
      input_a = new Int16Array(input);
      offset *= 8;
      status = ALAC.errors.noError;
      while (status === ALAC.errors.noError) {
        tag = CSLoadFewBits(input, offset, 3);
        offset += 3;
        switch (tag) {
          case ID_SCE:
          case ID_LFE:
            console.log("LFE or SCE element");
            elementInstanceTag = CSLoadFewBits(input, offset, 4);
            offset += 4;
            this.activeElements |= 1 << elementInstanceTag;
            unused = CSLoadManyBits(input, offset, 12);
            if (unused !== 0) {
              return ALAC.errors.paramError;
            }
            offset += 12;
            headerByte = CSLoadFewBits(input, offset, 4);
            offset += 4;
            partialFrame = headerByte >> 3;
            bytesShifted = (headerByte >> 1) & 0x3;
            if (bytesShifted !== 3) {
              return ALAC.errors.paramError;
            }
            shift = bytesShifted * 8;
            escapeFlag = headerByte & 0x1;
            chanBits = this.config.bitDepth - shift;
            if (partialFrame !== 0) {
              samples = CSLoadManyBits(input, offset, 16) << 16;
              offset += 16;
              samples |= CSLoadManyBits(input, offset, 16);
              offset += 16;
            }
            if (escapeFlag === 0) {
              mixBits = CSLoadFewBits(input, offset, 8);
              offset += 8;
              mixRes = CSLoadFewBits(input, offset, 8);
              offset += 8;
              headerByte = CSLoadFewBits(input, offset, 8);
              offset += 8;
              modeU = headerByte >> 4;
              denShiftU = headerByte & 0xf;
              headerByte = CSLoadFewBits(input, offset, 8);
              offset += 8;
              pbFactorU = headerByte >> 5;
              numU = headerByte & 0x1f;
              for (i = 0; 0 <= numU ? i < numU : i > numU; 0 <= numU ? i++ : i--) {
                coefsU[i] = CSLoadManyBits(bits, 16);
                offset += 16;
              }
              if (bytesShifted !== 0) {
                offset += shift * samples;
              }
              params = Aglib.ag_params(this.config.mb, (pb * pbFactorU) / 4, this.config.kb, samples, samples, this.config.maxRun);
              status = Aglib.dyn_decomp(params, input, offset, this.predictor, samples, chanBits);
              if (status !== ALAC.errors.noError) {
                return status;
              }
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
            break;
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
            console.log("End of frame");
            return status;
          default:
            console.log("Error in frame");
            return ALAC.errors.paramError;
        }
      }
      if (channelIndex > channels) {
        console.log("Channel Index is higher than the amount of channels");
      }
      return [status, output];
    };
    return ALACDecoder;
  })();
  Aglib = (function() {
    var KB0, MAX_PREFIX_16, MAX_PREFIX_32, MAX_RUN_DEFAULT, MB0, PB0, dyn_get_16, dyn_get_32, get_next, get_stream_bits, lead, lg3a, read;
    function Aglib() {}
    PB0 = 40;
    MB0 = 10;
    KB0 = 14;
    MAX_RUN_DEFAULT = 255;
    MAX_PREFIX_16 = 9;
    MAX_PREFIX_32 = 9;
    lead = function(m) {
      var c, i;
      c = 1 << 31;
      for (i = 0; i < 32; i++) {
        if (c & m !== 0) {
          return i;
        }
        c = c >> 1;
      }
      return 32;
    };
    lg3a = function(x) {
      return 31 - lead(x + 3);
    };
    read = function(buffer, offset) {
      return (buffer[0] << 24 >>> 0) + ((buf[1] << 16) | (buf[2] << 8) | buf[3]);
    };
    get_next = function(input, suff) {
      return input >> (32 - suff);
    };
    get_stream_bits = function(input, offset, bits) {
      var byteoffset, input_a, load1, load2, load2shift, result;
      byteoffset = offset / 8;
      input_a = new Uint8Array(input);
      load1 = read(input, byteoffset);
      if ((bits + (offset & 0x7)) > 32) {
        result = load1 << (bitoffset & 0x7);
        load2 = input_a[byteoffset + 4];
        load2shift = 8 - (bits + (offset & 0x7) - 32);
        load2 >>= load2shift;
        result >>= 32 - bits;
        result |= load2;
      } else {
        result = load1 >> (32 - numbits - (bitoffset & 7));
      }
      return result;
    };
    dyn_get_16 = function(input, pos, m, k) {
      var input_a, pre, result, stream, tempbits, v;
      input_a = new Uint8Array(input);
      tempbits = new Uint32Array(input)[pos];
      stream = read(input, tempbits >> 3) << (tempbits & 7);
      pre = lead(~stream);
      if (pre >= MAX_PREFIX_16) {
        pre = MAX_PREFIX_16;
        tempbits += pre;
        stream <<= pre;
        result = get_next(stream, MAX_DATATYPE_BITS_16);
        tempbits += MAX_DATATYPE_BITS_16;
      } else {
        tempbits += pre + 1;
        stream <<= pre + 1;
        v = get_next(stream, k);
        tempbits += k;
        result = pre * m + v - 1;
        if (v < 2) {
          result -= v - 1;
          tempbits -= 1;
        }
      }
      return [result, pos];
    };
    dyn_get_32 = function(input, pos, m, k, maxbits) {
      var input_a, result, stream, tempbits, v;
      input_a = Uint8Array(input);
      tempbits = new Uint32Array(input)[pos];
      stream = read(input, tempbits >> 3);
      stream = stream << (tempbits & 0x7);
      result = lead(~stream);
      if (result >= MAX_PREFIX_32) {
        result = get_stream_bits(input, tempbits + MAX_PREFIX_32, maxbits);
        tempbits += MAX_PREFIX_32 + maxbits;
      } else {
        tempbits += result + 1;
        if (k !== 1) {
          stream <<= result + 1;
          v = get_next(stream, k);
          tempbits += k - 1;
          result = result * m;
          if (v >= 2) {
            result += v - 1;
            tempbits += 1;
          }
        }
      }
      return [result, pos];
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
    Aglib.dyn_decomp = function(params, input, offset, pc, samples, size) {
      var bitPos, c, del, j, k, kb, m, maxPos, mb, multiplier, mz, n, ndecode, out, outPtr, pb, status, wb, zmode, _ref, _ref2;
      pb = params.pb, kb = params.kb, wb = params.wb, mb = params.mb0;
      input = bitstream.cur, bitPos = bitstream.bitIndex, maxPos = bitstream.byteSize;
      maxPos *= 8;
      zmode = c = status = outPtr = 0;
      out = new Uint32Array(pc);
      while (c < samples) {
        if (!(bitPos < maxPos)) {
          return ALAC.error.paramError;
        }
        m = mb >> QBSHIFT;
        k = lg3a(m);
        k = Math.min(k, kb);
        m = (1 << k) - 1;
        _ref = dyn_get_32(input, bitPos, m, k, maxSize), n = _ref[0], bitPos = _ref[1];
        ndecode = n + zmode;
        multiplier = -(ndecode & 1) | 1;
        del = ((ndecode + 1) >> 1) * multiplier;
        out[outPtr++] = del;
        c++;
        mb = pb * (n + zmode) + mb - ((pb * mb) >> QBSHIFT);
        if (n > N_MAX_MEAN_CLAMP) {
          mb = N_MEAN_CLAMP_VAL;
        }
        zmode = 0;
        if (((mb << MMULSHIFT) < QB) && (c < samples)) {
          zmode = 1;
          k = lead(mb) - BITOFF + ((mb + MOFF) >> MDENSHIFT);
          mz = ((1 << k) - 1) & wb;
          _ref2 = dyn_get_16(input, bitPos, mz, k), n = _ref2[0], bitPos = _ref2[1];
          if (!(c + 1 <= samples)) {
            return ALAC.error.paramError;
          }
          for (j = 0; 0 <= n ? j < n : j > n; 0 <= n ? j++ : j--) {
            out[outPtr++] = 0;
            c++;
          }
          if (z >= 65535) {
            zmode = 0;
          }
          mb = 0;
        }
      }
      bitstream.bitIndex = bitPos;
      bitstream.cur += bitPos >> 3;
      butstream.bitIndex &= 7;
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
    Data.prototype.readString = function(length) {
      var i, ret;
      ret = [];
      for (i = 0; 0 <= length ? i < length : i > length; 0 <= length ? i++ : i--) {
        ret[i] = String.fromCharCode(this.readByte());
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
    return Data;
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
      var chanshift, coefs_a, dd, del, del0, denhalf, i, j, lim, out_a, pc1_a, prev, sg, sum1, top, _ref, _step;
      chanshift = 32 - chanbits;
      denhalf = 1 << (denshift - 1);
      pc1_a = new Int32Array(pcl);
      out_a = new Int32Array(out);
      coefs_a = new Int32Array(coefs);
      out[0] = pc1[0];
      if (active === 0) {
        copy(out, 0, pc1, 0, num * 4);
        return;
      } else if (active === 31) {
        prev = out_a[0];
        for (i = 1; 1 <= num ? i < num : i > num; 1 <= num ? i++ : i--) {
          del = pcl_a[i] + prev;
          prev = (del << chanshift) >> chanshift;
          out_a[i] = prev;
        }
        return;
      }
      for (i = 1; 1 <= active ? i < active : i > active; 1 <= active ? i++ : i--) {
        del = pc1_a[i] + out_a[i - 1];
        out_a[i] = (del << chanshift) >> chanshift;
      }
      lim = active + 1;
      for (i = lim; lim <= num ? i < num : i > num; lim <= num ? i++ : i--) {
        sum1 = 0;
        top = out_a[i - lim];
        for (j = 0; 0 <= active ? j < active : j > active; 0 <= active ? j++ : j--) {
          sum1 += coefs_a[j] * (out_a[i - j - 1] - top);
        }
        del = del0 = pc1[i];
        sg = del / Math.abs(del);
        del += top + ((sum1 + denhalf) >> denshift);
        out_a[i] = (del << chanshift) >> chanshift;
        for (j = _ref = active - 1, _step = -1; _ref <= 0 ? j <= 0 : j >= 0; j += _step) {
          dd = top - out_a[i - j - 1];
          coefs_a[j] -= sg * dd / Math.abs(dd);
          del0 -= (active - k) * (Math.abs(dd) >> denshift);
          if (sg * del0 <= 0) {
            break;
          }
        }
      }
    };
    return Dplib;
  })();
  Matrixlib = (function() {
    function Matrixlib() {}
    Matrixlib.unmix16 = function(u, v, out, stride, samples, mixbits, mixres) {
      var i, l, out_a, u_a, v_a, _results, _results2, _step;
      out_a = new Int16Array(out);
      u_a = new Int16Array(u);
      v_a = new Int16Array(v);
      if (mixres === 0) {
        _results = [];
        for (i = 0; 0 <= samples ? i < samples : i > samples; 0 <= samples ? i++ : i--) {
          op[i * stride + 0] = u[i];
          _results.push(op[i * stride + 1] = v[i]);
        }
        return _results;
      } else {
        _results2 = [];
        for (i = 0, _step = 1; 0 <= samples ? i < samples : i > samples; i += _step) {
          l = u[i] + v[i] - ((mixres * v[i]) >> mixbits);
          op[i * stride + 0] = l;
          _results2.push(op[i * stride + 1] = l - v[i]);
        }
        return _results2;
      }
    };
    return Matrixlib;
  })();
}).call(this);
