(function() {
  var Buffer, BufferList, CAFDemuxer, Float32, Float64, FromFloat32, FromFloat64, HTTPSource, Queue, Stream, ToFloat32, ToFloat64;

  Buffer = (function() {

    function Buffer(data) {
      this.data = data;
      this.length = this.data.length;
      this.timestamp = null;
      this.duration = null;
      this.discontinuity = false;
    }

    Buffer.allocate = function(size) {
      return new Buffer(new Uint8Array(size));
    };

    Buffer.prototype.copy = function() {
      var buffer;
      buffer = new Buffer(new Uint8Array(this.data));
      buffer.timestamp = this.timestamp;
      buffer.duration = this.duration;
      return buffer.discontinuity = this.discontinuity;
    };

    Buffer.prototype.slice = function(position, length) {
      if (position === 0 && length >= this.length) {
        return this;
      } else {
        return new Buffer(this.data.subarray(position, length));
      }
    };

    return Buffer;

  })();

  BufferList = (function() {

    function BufferList() {
      this.buffers = [];
      this.availableBytes = 0;
      this.availableBuffers = 0;
      this.bufferHighWaterMark = null;
      this.bufferLowWaterMark = null;
      this.bytesHighWaterMark = null;
      this.bytesLowWaterMark = null;
      this.onLowWaterMarkReached = null;
      this.onHighWaterMarkReached = null;
      this.onLevelChange = null;
      this.endOfList = false;
      this.first = null;
    }

    BufferList.prototype.copy = function() {
      var result;
      result = new BufferList();
      result.buffers = this.buffers.slice(0);
      result.availableBytes = this.availableBytes;
      result.availableBuffers = this.availableBuffers;
      return result.endOfList = this.endOfList;
    };

    BufferList.prototype.shift = function() {
      var result;
      result = this.buffers.shift();
      this.availableBytes -= result.length;
      this.availableBuffers -= 1;
      this.first = this.buffers[0];
      return result;
    };

    BufferList.prototype.push = function(buffer) {
      this.buffers.push(buffer);
      this.availableBytes += buffer.length;
      this.availableBuffers += 1;
      if (!this.first) this.first = buffer;
      return this;
    };

    BufferList.prototype.unshift = function(buffer) {
      this.buffers.unshift(buffer);
      this.availableBytes += buffer.length;
      this.availableBuffers += 1;
      this.first = buffer;
      return this;
    };

    return BufferList;

  })();

  Float64 = new ArrayBuffer(8);

  Float32 = new ArrayBuffer(4);

  FromFloat64 = new Float64Array(Float64);

  FromFloat32 = new Float32Array(Float32);

  ToFloat64 = new Uint32Array(Float64);

  ToFloat32 = new Uint32Array(Float32);

  Stream = (function() {

    function Stream(list) {
      this.list = list;
      this.localOffset = 0;
      this.offset = 0;
    }

    Stream.prototype.available = function(bytes) {
      return this.list.availableBytes > bytes;
    };

    Stream.prototype.advance = function(bytes) {
      this.localOffset += bytes;
      this.offset += bytes;
      while (this.list.first && (this.localOffset >= this.list.first.length)) {
        this.localOffset -= this.list.shift().length;
      }
      if (!this.list.first) console.log("Local Offset: " + this.localOffset);
      return this;
    };

    Stream.prototype.readUInt32 = function() {
      var a0, a1, a2, a3, buffer;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + 4) {
        a0 = buffer[this.localOffset + 0];
        a1 = buffer[this.localOffset + 1];
        a2 = buffer[this.localOffset + 2];
        a3 = buffer[this.localOffset + 3];
        this.advance(4);
      } else {
        a0 = this.readUInt8();
        a1 = this.readUInt8();
        a2 = this.readUInt8();
        a3 = this.readUInt8();
      }
      return ((a0 << 24) >>> 0) + (a1 << 16) + (a2 << 8) + a3;
    };

    Stream.prototype.peekUInt32 = function(offset) {
      var a0, a1, a2, a3, buffer;
      if (offset == null) offset = 0;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + offset + 4) {
        a0 = buffer[this.localOffset + offset + 0];
        a1 = buffer[this.localOffset + offset + 1];
        a2 = buffer[this.localOffset + offset + 2];
        a3 = buffer[this.localOffset + offset + 3];
      } else {
        a0 = this.peekUInt8(offset + 0);
        a1 = this.peekUInt8(offset + 1);
        a2 = this.peekUInt8(offset + 2);
        a3 = this.peekUInt8(offset + 3);
      }
      return ((a0 << 24) >>> 0) + (a1 << 16) + (a2 << 8) + a3;
    };

    Stream.prototype.readInt32 = function() {
      var a0, a1, a2, a3, buffer;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + offset + 4) {
        a0 = buffer[this.localOffset + 0];
        a1 = buffer[this.localOffset + 1];
        a2 = buffer[this.localOffset + 2];
        a3 = buffer[this.localOffset + 3];
        this.advance(4);
      } else {
        a0 = this.readUInt8();
        a1 = this.readUInt8();
        a2 = this.readUInt8();
        a3 = this.readUInt8();
      }
      return (a0 << 24) + (a1 << 16) + (a2 << 8) + a3;
    };

    Stream.prototype.peekInt32 = function(offset) {
      var a0, a1, a2, a3, buffer;
      if (offset == null) offset = 0;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + offset + 4) {
        a0 = buffer[this.localOffset + offset + 0];
        a1 = buffer[this.localOffset + offset + 1];
        a2 = buffer[this.localOffset + offset + 2];
        a3 = buffer[this.localOffset + offset + 3];
      } else {
        a0 = this.peekUInt8(offset + 0);
        a1 = this.peekUInt8(offset + 1);
        a2 = this.peekUInt8(offset + 2);
        a3 = this.peekUInt8(offset + 3);
      }
      return (a0 << 24) + (a1 << 16) + (a2 << 8) + a3;
    };

    Stream.prototype.readUInt16 = function() {
      var a0, a1, buffer;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + 2) {
        a0 = buffer[this.localOffset + 0];
        a1 = buffer[this.localOffset + 1];
        this.advance(2);
      } else {
        a0 = this.readUInt8();
        a1 = this.readUInt8();
      }
      return (a0 << 8) + a1;
    };

    Stream.prototype.peekUInt16 = function(offset) {
      var a0, a1, buffer;
      if (offset == null) offset = 0;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + offset + 2) {
        a0 = buffer[this.localOffset + offset + 0];
        a1 = buffer[this.localOffset + offset + 1];
      } else {
        a0 = this.peekUInt8(offset + 0);
        a1 = this.peekUInt8(offset + 1);
      }
      return (a0 << 8) + a1;
    };

    Stream.prototype.readInt16 = function() {
      var a0, a1, buffer;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + 2) {
        a0 = buffer[this.localOffset + 0];
        a1 = buffer[this.localOffset + 1];
      } else {
        a0 = this.readInt8();
        a1 = this.readUInt8();
      }
      return (a0 << 8) + a1;
    };

    Stream.prototype.peekInt16 = function(offset) {
      var a0, a1, buffer;
      if (offset == null) offset = 0;
      buffer = this.list.first.data;
      if (buffer.length > this.localOffset + offset + 2) {
        a0 = buffer[this.localOffset + offset + 0];
        a1 = buffer[this.localOffset + offset + 1];
      } else {
        a0 = this.peekInt8(offset + 0);
        a1 = this.peekUInt8(offset + 1);
      }
      return (a0 << 8) + a1;
    };

    Stream.prototype.readUInt8 = function() {
      var a0;
      a0 = this.list.first.data[this.localOffset];
      this.localOffset += 1;
      this.offset += 1;
      if (this.localOffset === this.list.first.length) {
        this.localOffset = 0;
        this.buffers.shift();
      }
      return a0;
    };

    Stream.prototype.peekUInt8 = function(offset) {
      var buffer, i;
      if (offset == null) offset = 0;
      offset = this.localOffset + offset;
      i = 0;
      buffer = this.list.buffers[i].data;
      while (!(buffer.length > offset + 1)) {
        offset -= buffer.length;
        buffer = this.list.buffers[++i].data;
      }
      return buffer[offset];
    };

    Stream.prototype.readInt8 = function() {
      var a0;
      a0 = (this.list.first.data[this.localOffset] << 24) >> 24;
      this.advance(1);
      return a0;
    };

    Stream.prototype.peekUInt8 = function(offset) {
      var buffer, i;
      if (offset == null) offset = 0;
      offset = this.localOffset + offset;
      i = 0;
      buffer = this.list.buffers[i].data;
      while (!(buffer.length > offset + 1)) {
        offset -= buffer.length;
        buffer = this.list.buffers[++i].data;
      }
      return buffer[offset];
    };

    Stream.prototype.readFloat64 = function() {
      ToFloat64[1] = this.readUInt32();
      ToFloat64[0] = this.readUInt32();
      return FromFloat64[0];
    };

    Stream.prototype.readFloat32 = function() {
      ToFloat32[0] = this.readUInt32();
      return FromFloat32[0];
    };

    Stream.prototype.readString = function(length) {
      var i, result;
      result = [];
      for (i = 0; 0 <= length ? i < length : i > length; 0 <= length ? i++ : i--) {
        result.push(String.fromCharCode(this.readUInt8()));
      }
      return result.join('');
    };

    Stream.prototype.readBuffer = function(length) {
      var i, result, to;
      result = Buffer.allocate(length);
      to = result.data;
      for (i = 0; 0 <= length ? i < length : i > length; 0 <= length ? i++ : i--) {
        to[i] = this.readUInt8();
      }
      return result;
    };

    Stream.prototype.readSingleBuffer = function(length) {
      var result;
      result = this.list.first.slice(this.localOffset, length);
      this.advance(result.length);
      return result;
    };

    return Stream;

  })();

  if (!window.Aurora) window.Aurora = {};

  window.Aurora.Buffer = Buffer;

  window.Aurora.BufferList = BufferList;

  window.Aurora.Stream = Stream;

  CAFDemuxer = (function() {

    function CAFDemuxer(name) {
      var _this = this;
      this.name = name;
      this.chunkSize = 1 << 20;
      this.inputs = {
        data: {
          send: function(buffer) {
            return _this.enqueueBuffer(buffer);
          },
          finished: function() {
            return _this.finished();
          },
          mode: "Passive"
        }
      };
      this.outputs = {};
      this.list = new BufferList();
      this.stream = new Stream(this.list);
      this.metadata = null;
      this.headerCache = null;
      this.packetCache = null;
      this.magic = null;
      this.reset();
    }

    CAFDemuxer.prototype.enqueueBuffer = function(buffer) {
      var size;
      this.list.push(buffer);
      if (!this.metadata && this.stream.available(64)) {
        if (this.stream.readString(4) !== 'caff') {
          console.log("Invalid CAF, does not begin with 'caff'");
          debugger;
        }
        this.metadata = {};
        this.metadata.caff = {
          version: this.stream.readUInt16(),
          flags: this.stream.readUInt16()
        };
        if (this.stream.readString(4) !== 'desc') {
          console.log("Invalid CAF, 'caff' is not followed by 'desc'");
          debugger;
        }
        if (!(this.stream.readUInt32() === 0 && this.stream.readUInt32() === 32)) {
          console.log("Invalid 'desc' size, should be 32");
          debugger;
        }
        this.metadata.desc = {
          sampleRate: this.stream.readFloat64(),
          formatID: this.stream.readString(4),
          formatFlags: this.stream.readUInt32(),
          bytesPerPacket: this.stream.readUInt32(),
          framesPerPacket: this.stream.readUInt32(),
          channelsPerFrame: this.stream.readUInt32(),
          bitsPerChannel: this.stream.readUInt32()
        };
        if (this.metadata.desc.formatID !== 'alac') {
          console.log("Right now we only support Apple Lossless audio");
          debugger;
        }
      }
      while ((this.headerCache && this.stream.available(1)) || this.stream.available(13)) {
        if (!this.headerCache) {
          this.headerCache = {
            type: this.stream.readString(4),
            oversize: this.stream.readUInt32() !== 0,
            size: this.stream.readUInt32()
          };
        }
        console.log(this.headerCache.type, this.headerCache.size, this.stream.localOffset);
        if (this.headerCache.oversize) {
          console.log("Holy Shit, an oversized file, not supported in JS");
          debugger;
        }
        size = this.headerCache.size;
        switch (this.headerCache.type) {
          case 'kuki':
            if (this.stream.available(this.headerCache.size)) {
              this.outputs.cookie.send(this.stream.readBuffer(this.headerCache.size));
              this.headerCache = null;
            } else {
              return;
            }
            break;
          case 'data':
            buffer = this.stream.readSingleBuffer(this.headerCache.size);
            this.outputs.data.send(buffer);
            this.headerCache.size -= buffer.length;
            if (this.headerCache.size <= 0) this.headerCache = null;
            break;
          default:
            if (this.stream.available(this.headerCache.size)) {
              this.stream.advance(this.headerCache.size);
              this.headerCache = null;
            } else {
              return;
            }
        }
      }
    };

    CAFDemuxer.prototype.start = function() {
      this.status = "Started";
      return this;
    };

    CAFDemuxer.prototype.pause = function() {
      this.status = "Paused";
      return this;
    };

    CAFDemuxer.prototype.reset = function() {
      this.status = "Paused";
      return this;
    };

    CAFDemuxer.prototype.finished = function() {
      this.status = "Finished";
      return this;
    };

    return CAFDemuxer;

  })();

  if (!window.Aurora) window.Aurora = {};

  window.Aurora.CAFDemuxer = CAFDemuxer;

  HTTPSource = (function() {

    function HTTPSource(name) {
      this.name = name;
      this.chunkSize = 1 << 20;
      this.outputs = {};
      this.reset();
    }

    HTTPSource.prototype.start = function() {
      var onAbort, onError, onLoad;
      var _this = this;
      this.status = "Started";
      if (!this.length) {
        if (this.inflight) {
          console.log("Should never be here, something is seriously wrong");
          debugger;
        }
        this.inflight = true;
        this.xhr = new XMLHttpRequest();
        onLoad = function(event) {
          _this.length = parseInt(_this.xhr.getResponseHeader("Content-Length"));
          _this.inflight = false;
          return _this.loop();
        };
        onError = function(event) {
          console.log("HTTP Error when requesting length: ", event);
          _this.inflight = false;
          _this.pause();
          _this.messagebus.send(_this, _this.name, "ERROR", "Source paused, failed to get length of file");
        };
        onAbort = function(event) {
          console.log("HTTP Aborted: Paused?");
          _this.inflight = false;
        };
        this.xhr.addEventListener("load", onLoad, false);
        this.xhr.addEventListener("error", onError, false);
        this.xhr.addEventListener("abort", onAbort, false);
        this.xhr.open("HEAD", this.url, true);
        this.xhr.send(null);
      }
      return this;
      if (this.inflight) {
        console.log("Should never get here, unless you're starting a stream with in-flight requests");
        debugger;
      }
      return this.loop();
    };

    HTTPSource.prototype.pause = function() {
      this.status = "Paused";
      if (this.inflight) {
        this.xhr.abort();
        this.inflight = false;
      }
      return this;
    };

    HTTPSource.prototype.reset = function() {
      this.status = "Paused";
      if (this.inflight) this.xhr.abort();
      this.offset = 0;
      this.inflight = false;
      return this;
    };

    HTTPSource.prototype.finished = function() {
      this.status = "Finished";
      return this;
    };

    HTTPSource.prototype.loop = function() {
      var onAbort, onError, onLoad;
      var _this = this;
      if (this.inflight) {
        console.log("Should never be here, unless a loop is failing");
        debugger;
      }
      if (this.offset === this.length) return this.finished();
      this.inflight = true;
      this.xhr = new XMLHttpRequest();
      onLoad = function(event) {
        var buffer;
        buffer = new Buffer(new Uint8Array(_this.xhr.response));
        _this.outputs.data.send(buffer);
        _this.offset += buffer.length;
        _this.inflight = false;
        console.log("HTTP Finished: " + _this.name + " (offset " + (_this.offset >> 10) + " kB, length " + (buffer.length >> 10) + " kB)");
        return _this.loop();
      };
      onError = function(event) {
        console.log("HTTP Error: ", event);
        _this.inflight = false;
        _this.pause();
        _this.messagebus.send(_this, _this.name, "ERROR", "Source paused, errror sending HTTP request");
      };
      onAbort = function(event) {
        console.log("HTTP Aborted: Paused?");
        _this.inflight = false;
      };
      this.xhr.addEventListener("load", onLoad, false);
      this.xhr.addEventListener("error", onError, false);
      this.xhr.addEventListener("abort", onAbort, false);
      this.xhr.open("GET", this.url, true);
      this.xhr.responseType = "arraybuffer";
      this.xhr.setRequestHeader("Range", "bytes=" + this.offset + "-" + (this.offset + this.chunkSize > this.length ? this.length : this.offset + this.chunkSize));
      this.xhr.send(null);
      return this;
    };

    return HTTPSource;

  })();

  if (!window.Aurora) window.Aurora = {};

  window.Aurora.HTTPSource = HTTPSource;

  Queue = (function() {

    function Queue(name) {
      this.name = name;
      this.chunkSize = 1 << 20;
      this.highwaterMark = 16;
      this.lowwaterMark = 4;
      this.finished = false;
      this.buffering = true;
      this.onHighwaterMark = null;
      this.onLowwaterMark = null;
      this.buffers = [];
      this.inputs = {
        contents: {
          send: function(buffer) {
            return this.enqueueBuffer(buffer);
          },
          finished: function() {
            return this.finished();
          },
          mode: "Passive"
        }
      };
      this.outputs = {
        contents: {
          receive: function() {
            return this.dequeueBuffer();
          },
          mode: "Pull"
        }
      };
      this.reset();
    }

    Queue.prototype.enqueueBuffer = function(buffer) {
      this.buffers.push(buffer);
      if (this.buffering) {
        if (this.buffer.length >= this.highWaterMark) {
          this.onHighwaterMark(this.buffers.length);
          this.buffering = false;
        }
      } else {
        if (this.buffer.length <= this.lowWaterMark) {
          this.onLowwaterMark(this.buffers.length);
        }
      }
      return this;
    };

    Queue.prototype.dequeueBuffer = function() {
      return this.buffers.shift();
    };

    Queue.prototype.start = function() {
      this.status = "Started";
      return this;
    };

    Queue.prototype.pause = function() {
      this.status = "Paused";
      return this;
    };

    Queue.prototype.reset = function() {
      this.status = "Paused";
      return this;
    };

    Queue.prototype.finished = function() {
      this.status = "Finished";
      return this;
    };

    return Queue;

  })();

  if (!window.Aurora) window.Aurora = {};

  window.Aurora.Queue = Queue;

}).call(this);
