#
#  Original C(++) version by Apple, http://alac.macosforge.org
#
#  Javascript port by Jens Nockert of OFMLabs, https://github.com/ofmlabs/alac
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

Alac = {}

Alac.channelAtomSize = 12

Alac.maxChannels = 8
Alac.maxEscapeHeaderBytes = 8
Alac.maxSearches = 16
Alac.maxCoefs = 16

Alac.defaultFramesPerPacket = 4096

Alac.errors = {
	unimplementedError = -4,
	fileNotFoundError = -43,
	paramError = -50,
	memFullError = -108
}

Alac.formats = {
	appleLossless = 'alac',
	linearPCM = 'lpcm'
}

Alac.sampleTypes = {
	isFloat =         (1 << 0),
	isBigEndian =     (1 << 1),
	isSignedInteger = (1 << 2),
	isPacked =        (1 << 3),
	isAlignedHigh =   (1 << 4)
}

Alac.channelLayouts = {
	mono =       (100 << 16) | 1,
	stereo =     (101 << 16) | 2,
	MPEG_3_0_B = (113 << 16) | 3,
	MPEG_4_0_B = (116 << 16) | 4,
	MPEG_5_0_D = (120 << 16) | 5,
	MPEG_5_1_D = (124 << 16) | 6,
	AAC_6_1 =    (142 << 16) | 7,
	MPEG_7_1_B = (127 << 16) | 8
}

Alac.channelLayoutArray = [
	Alac.channelLayouts.mono,
	Alac.channelLayouts.stereo,
	Alac.channelLayouts.MPEG_3_0_B,
	Alac.channelLayouts.MPEG_4_0_B,
	Alac.channelLayouts.MPEG_5_0_D,
	Alac.channelLayouts.MPEG_5_1_D,
	Alac.channelLayouts.AAC_6_1,
	Alac.channelLayouts.MPEG_7_1_B,
]

Alac.unmix16 = (u, v, out, stride, samples, mixbits, mixres) ->
	[out_a, u_a, v_a] = [Int16Array(out), Int16Array(u), Int16Array(v)]
	
	if mixres == 0 # Conventional separated stereo
		for i in [0 ... samples] by 1
			op[i * stride + 0] = u[i]
			op[i * stride + 1] = v[i]
		
	else # Matrixed stereo
		for i in [0 ... samples] by 1
			l = u[i] + v[i] - ((mixres * v[i]) >> mixbits)
			
			op[i * stride + 0] = l
			op[i * stride + 1] = l - v[i]
		
	

Alac.unpc_block = (pc1, out, num, coefs, active, chanbits, denshift) ->
	[chanshift, denhalf] = [32 - chanbits, 1 << (denshift - 1)]
	
	[pc1_a, out_a, coefs_a] = [Int32Array(pcl), Int32Array(out), Int16Array(coefs)]
	
	out[0] = pc1[0];
	
	if active == 0
		CSCopy(out, 0, pc1, 0, num * 4) if pc1 != out # Yes, I know that I copy pc1[0] twice
		return
	else if active == 31
		prev = out_a[0]
		
		for i in [0 ... num] by 1
			del = pcl_a[i] + prev
			
			prev = (del << chanshift) >> chanshift
			
			out_a[i] = prev
		
		return
	
	for i in [1 ... active] by 1
		del = pc1_a[i] + out_a[i - 1]
		
		out_a[i] = (del << chanshift) >> chanshift
	
	lim = active + 1
	
	# if active == 4 # Optimization for active == 4
	# if active == 8 # Optimization for active == 8
	# else           # General case
	
	for i in [lim ... num] by 1
		[sum1, top] = [0, out_a[i - lim]
		
		sum1 += coefs_a[j] * (out_a[i - j - 1] - top) for j in [0 ... active] by 1
		
		del = del0 = pc1[i]
		sg  = del / abs(del)
		
		del += top + ((sum1 + denhalf) >> denshift)
		
		out_a[i] = (del << chanshift) >> chanshift
		
		for j in [active - 1 .. 0] by -1 # Modified from Apple ALAC to remove the two loops
			dd = top - out_a[i - j - 1]
			
			coefs_a[j] -= sg * dd / abs(dd)
			
			del0 -= (active - k) * (abs(dd) >> denshift)
			
			break unless sg * del0 > 0
		
	

PB0 = 40
MB0 = 10
KB0 = 14

MAX_RUN_DEFAULT = 255

lead = (m) ->
	c = (1 << 31)
	
	for i in [0 ... 32] by 1
		return i if (c & m) != 0
		
		c = c >> 1
	
	return 32

read = (buffer, offset) ->
	return Uint32Buffer(CSReadBig32(buffer, offset))[0]

get_next = (input, suff) ->
	return input >> (32 - suff)

get_stream_bits = (input, offset, bits) ->
	byteoffset = offset / 8
	
	input_a = Uint8Array(input)
	
	load1 = read(input, byteoffset)
	
	if (bits + (offset & 0x7)) > 32
		result = load1 << (bitoffset & 0x7)
		
		load2 = input_a[byteoffset + 4]
		load2shift = (8 - (bits + (offset & 0x7) - 32))
		
		load2 >>= load2shift
		
		result >>= (32 - bits)
		
		result |= load2
	else
		result = load1 >> (32 - numbits - (bitoffset & 0x7))
	
	result &= ~(0xFFFFFFFF << numbits) if numbits != 32 # Is x << 32 defined in JS?
	
	return result

MAX_PREFIX_16 = 9
MAX_PREFIX_32 = 9

dyn_get_16 = (input, pos, m, k) ->
	input_a = Uint8Array(input)
	
	tempbits = Uint32Array(input)[pos]
	
	stream = read(input, tempbits >> 3)
	stream = stream << (tempbits & 0x7)
	
	pre = lead(~stream)
	
	if pre >= MAX_PREFIX_16
		pre = MAX_PREFIX_16
		
		tempbits += pre
		stream = stream << pre
		
		result = get_next(stream, MAX_DATATYPE_BITS_16)
		
		tempbits += MAX_DATATYPE_BITS_16
	else
		tempbits += pre + 1
		
		stream = stream << (pre + 1)
		
		v = get_next(stream, k)
		
		tempbits += k
		
		result = pre * m + v - 1
		
		if v < 2
			result -= (v - 1)
			tempbits -= 1
		
	
	return [result, pos]

dyn_get_32 = (input, pos, m, k, maxbits) ->
	input_a = Uint8Array(input)
	
	tempbits = Uint32Array(input)[pos]
	
	stream = read(input, tempbits >> 3)
	stream = stream << (tempbits & 0x7)
	
	result = lead(~stream)
	
	if result >= MAX_PREFIX_32
		result = get_stream_bits(input, tempbits + MAX_PREFIX_32, maxbits)
		tempbits += MAX_PREFIX_32 + maxbits
	else
		tempbits += result
		tempbits += 1
		
		unless k == 1
			stream = stream << (result + 1)
			
			v = get_next(stream, k)
			
			tempbits += k - 1
			
			result = result * m
			
			if v > 2
				result += v - 1
				tempbits += 1
			
		
	
	return [result, pos]

Alac.standard_ag_params = (fullwidth, sectorwidth) ->
	Alac.ag_params(MB0, PB0, KB0, fullwidth, sectorwidth, MAX_RUN_DEFAULT)

Alac.ag_params = (m, p, k, f, s, maxrun) ->
	return {
		mb:  m,
		mb0: m,
		pb:  p,
		kb:  k,
		wb:  (1 << k) - 1,
		qb:  QB - p,
		fw:  f,
		sw:  s,
		maxrun: maxrun
	}


Alac.dyn_decomp = (params, bitstream, pc, samples, size) ->
	[pb, kb, wb] = [params.pb, params.kb, params.wb]
	
	return Alac.errors.paramError unless bitstream and pc
	
	[input, startPos, maxPos] = [bitstream.cur, bitstream.bitIndex, bitstream.byteSize * 8]
	
	[bitPos, mb, zmode, c, status] = [startPos, params.mb0, 0, 0, 0]
	
	[out, outPtr] = [Uint32Array(pc), 0]
	
	try
		while c < samples
			unless bitPos > maxPos
				status = Alac.error.paramError
				
				throw "Look ma, flow control!"
			
			[m, k] = [mb >> QBSHIFT, lb3a(m)]
			
			k = min(k, kb)
			m = (1 << k) - 1
			
			[n, bitPos] = dyn_get_32(input, bitPos, m, k, maxSize)
			
			ndecode = n + zmode
			multiplier = -(ndecode & 1) | 1
			
			del = ((ndecode + 1) >> 1) * multiplier
			
			out[outPtr] = del; outPtr += 1; c += 1
			
			mb = pb * (n + zmode) + mb ((pb * mb) >> QBSHIFT)
			
			mb = N_MEAN_CLAMP_VAL if (n > N_MAX_MEAN_CLAMP)
			
			zmode = 0
			
			if ((mb << MMULSHIFT) < QB) && (c < samples)
				zmode = 1
				
				k = lead(mb) - BITOFF + ((mb + MOFF) >> MDENSHIFT)
				mz = ((1 << k) - 1) & wb
				
				[n, bitPos] = dyn_get_16(input, bitPos, mz, k)
	
	
	
	