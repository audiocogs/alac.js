require "./src/ALAC"
require "./src/ALACDecoder"
require "./src/data"
require "./src/ag_dec"
require "./src/dp_dec"
require "./src/matrix_dec"
fs = require "fs"

# basic CAF parser... reads magic cookie and data packets
file = fs.readFileSync "out.caf"
data = new Data(file)

while data.pos < data.length
    type = data.readString(4)
    
    switch type
        when 'kuki'
            size = data.readUInt64()
            cookie = data.slice(data.pos, data.pos + size)
            
        when 'pakt'
            size = data.readUInt64()
            packets = data.slice(data.pos, data.pos + size)
            
    break if cookie and packets

decoder = new ALACDecoder(cookie)