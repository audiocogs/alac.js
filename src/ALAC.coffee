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

ALAC = {}

ALAC.channelAtomSize = 12
ALAC.maxChannels = 8
ALAC.maxEscapeHeaderBytes = 8
ALAC.maxSearches = 16
ALAC.maxCoefs = 16
ALAC.defaultFramesPerPacket = 4096

ALAC.errors =
    noError: 0
    unimplementedError: -4
    fileNotFoundError: -43
    paramError: -50
    memFullError: -108

ALAC.formats =
    appleLossless: 'alac'
    linearPCM: 'lpcm'

ALAC.sampleTypes =
    isFloat:         (1 << 0)
    isBigEndian:     (1 << 1)
    isSignedInteger: (1 << 2)
    isPacked:        (1 << 3)
    isAlignedHigh:   (1 << 4)

ALAC.channelLayouts =
    mono:       (100 << 16) | 1
    stereo:     (101 << 16) | 2
    MPEG_3_0_B: (113 << 16) | 3
    MPEG_4_0_B: (116 << 16) | 4
    MPEG_5_0_D: (120 << 16) | 5
    MPEG_5_1_D: (124 << 16) | 6
    AAC_6_1:    (142 << 16) | 7
    MPEG_7_1_B: (127 << 16) | 8

ALAC.channelLayoutArray = [
    ALAC.channelLayouts.mono
    ALAC.channelLayouts.stereo
    ALAC.channelLayouts.MPEG_3_0_B
    ALAC.channelLayouts.MPEG_4_0_B
    ALAC.channelLayouts.MPEG_5_0_D
    ALAC.channelLayouts.MPEG_5_1_D
    ALAC.channelLayouts.AAC_6_1
    ALAC.channelLayouts.MPEG_7_1_B
]