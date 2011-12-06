importScripts('lib/aurora.js', 'lib/alac.js');

var httpSource = new Aurora.HTTPSource("Source")
var cafDemuxer = new Aurora.CAFDemuxer("Demuxer")
var alacDecoder = new Aurora.ALACDecoder("Decoder")
var buffer = new Aurora.Queue("Buffer")
var output, frame;
var frameOffset = 0;

function emit() {
    postMessage(Array.prototype.slice.call(arguments));
}

this.console = {
    log: function() {
        postMessage(['log'].concat(Array.prototype.slice.call(arguments)));
    }
}

this.onmessage = function(e) {
    switch (e.data[0]) {
        case 'start':
            httpSource.url = e.data[1]; // pass in URL
    
            httpSource.chunkSize = 128 * 1024
            httpSource.outputs.data = cafDemuxer.inputs.data

            cafDemuxer.outputs.metadata = alacDecoder.inputs.metadata
            cafDemuxer.outputs.cookie = alacDecoder.inputs.cookie
            cafDemuxer.outputs.data = alacDecoder.inputs.data

            alacDecoder.outputs.audio = buffer.inputs.contents
    
            buffer.onHighwaterMark = function () {
                console.log("Hitting High-Water Mark, Aurora o'hoy! Lets start playing!");
                output = buffer.outputs.contents
                
                var f = output.receive();
                frame = new Int16Array(f.data.buffer);
                frameOffset = 0;
                
                emit('ready');
            }
            
            buffer.start()
            alacDecoder.start()
            cafDemuxer.start()
            httpSource.start()
            
            break;
        
        case 'read':
            if (!output) return;
            
            var bufferOffset = 0, 
                bufferLength = e.data[1],
                buf = new Float32Array(bufferLength);
            
            while (frame && bufferOffset < bufferLength) {
                var max = Math.min(frame.length - frameOffset, bufferLength - bufferOffset);
                for (var i = 0; i < max; i++) {
                    buf[bufferOffset + i] = frame[frameOffset + i] / 0x8000
                }

                bufferOffset += i
                frameOffset += i

                if (frameOffset == frame.length) {
                    f = output.receive()
                    
                    if (f) {
                        frame = new Int16Array(f.data.buffer), frameOffset = 0
                    } else {
                        frame = null, frameOffset = 0
                    }
                }
            }
            
            emit('response', buf);            
            break;
    }
}