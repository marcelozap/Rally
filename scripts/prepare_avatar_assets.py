#!/usr/bin/env python3
"""Rebuild Rally's CC0 human assets with Python 3 standard library only.

Usage: python3 scripts/prepare_avatar_assets.py [--source-cache PATH]
Pinned MakeHuman graphical data are CC0; no upstream application code is used.
Source downloads are verified against SHA-256 before geometry conversion.
Coordinates are meters, Y-up and +Z-forward. The neutral A-pose is retained so
all consumers can apply the same skinned pose and outfit. PNG files retain
their upstream pixel orientation; exported UV V is flipped once for SceneKit's
UIImage-backed top-left texture sampling convention.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import urllib.request
import zlib

REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / 'Rally/Resources/Avatar3D'
UPSTREAM_COMMIT = 'a8bc2d54ff0ac92e78ff71431b1023eda42bf482'
RAW_ROOT = 'https://raw.githubusercontent.com/makehumancommunity/makehuman/' + UPSTREAM_COMMIT + '/'
PACK_URL = 'https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip'
PACK_LICENSE_URL = 'https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html'
HEIGHT_METERS = 1.78
# Bilinear MakeHuman body target blend: muscle=0.70, lean weight=0.60.
# The remaining 0.12 is the zero-delta average-muscle/average-weight corner.
# This retains chest breadth while reducing waist/hip softness, rather than
# applying the full maximum-muscle bodybuilder shape.
BODY_TARGET_WEIGHTS = {
    'athletic.target': 0.28,       # maximum muscle, average weight
    'athletic-lean.target': 0.42,  # maximum muscle, minimum weight
    'lean.target': 0.18,           # average muscle, minimum weight
}

# A separate adult female source anatomy, with a female-specific lean-athletic
# blend (muscle=0.65, lean weight=0.55). Shared topology is a rigging contract,
# not a scaled or narrowed version of the male geometry.
FEMALE_HEIGHT_METERS = 1.73
FEMALE_BODY_TARGET_WEIGHTS = {
    'female-athletic.target': 0.2925,
    'female-athletic-lean.target': 0.3575,
    'female-lean.target': 0.1925,
}

# Filled from the verified, immutable upstream source and individually checked
# CC0 asset-pack members. Offsets are for selective ZIP range reads, not a
# dependency on installing MakeHuman or fetching the full 267 MB asset pack.
SOURCES = {'athletic-lean.target': {'license': 'CC0-1.0',
                          'path': 'makehuman/data/targets/macrodetails/universal-male-young-maxmuscle-minweight.target',
                          'sha256': '5873f11edc96fde72a79ec35fa1d292a6a1a594b5eadfd82d59faf48834561de'},
 'athletic.target': {'license': 'CC0-1.0',
                     'path': 'makehuman/data/targets/macrodetails/universal-male-young-maxmuscle-averageweight.target',
                     'sha256': 'c171ff9cc95e96273beb3e3b1969a01988c2d4982ebc6fe04bf81cf72ee3b295'},
 'base.obj': {'license': 'CC0-1.0',
              'path': 'makehuman/data/3dobjs/base.obj',
              'sha256': '8e761e6624b8f54536409135d1636da63b32486a90d4897f84e121d144f6fb4c'},
 'eyes.mhclo': {'license': 'CC0-1.0',
                'path': 'makehuman/data/eyes/high-poly/high-poly.mhclo',
                'sha256': 'b183cfe37120ab726f9b3f2ea6cd3a64c44ce7b4bd91a77c841cf70c04f83a0d'},
 'eyes.obj': {'license': 'CC0-1.0',
              'path': 'makehuman/data/eyes/high-poly/high-poly.obj',
              'sha256': 'da2493215b708a344c33dc72f2a9a5b8fa985dcc5a70ad3b208995cf871da8e1'},
 'eyes.png': {'license': 'CC0-1.0',
              'path': 'makehuman/data/eyes/materials/brown_eye.png',
              'sha256': '4659691c7295ad6206c78b003e5fd0e5f91dcd53032fa914a229bb48cabe424b'},
 'female-asian-skin.png': {'compressed': 3884836,
                           'crc': 1036941696,
                           'license': 'CC0-1.0',
                           'method': 8,
                           'offset': 31747571,
                           'packMember': 'skins/young_asian_female/young_lightskinned_female_diffuse3.png',
                           'sha256': '1d82f782b7d2da732229633bd2d14754d873fff53cdb1d088977bcf67ae19dde'},
 'female-asian.target': {'license': 'CC0-1.0',
                         'path': 'makehuman/data/targets/macrodetails/asian-female-young.target',
                         'sha256': '095fe79694fa19e1fe98d93009ec116199bd524e081c640351a10eccf2cca1eb'},
 'female-athletic-lean.target': {'license': 'CC0-1.0',
                                 'path': 'makehuman/data/targets/macrodetails/universal-female-young-maxmuscle-minweight.target',
                                 'sha256': '05351f0063429f4e1e484501b73997a6fb129b93939db355d108f98d5479fb10'},
 'female-athletic.target': {'license': 'CC0-1.0',
                            'path': 'makehuman/data/targets/macrodetails/universal-female-young-maxmuscle-averageweight.target',
                            'sha256': '2e56b09b44a8497b927585447fdaac5ea7293521d1f3a3df1059495873c53f4e'},
 'female-black.target': {'license': 'CC0-1.0',
                         'path': 'makehuman/data/targets/macrodetails/african-female-young.target',
                         'sha256': '92d61eeb3c164b421fd5a7c3537ee45e7e1a51de4d49bf312e19c3df2be1d8fc'},
 'female-lean.target': {'license': 'CC0-1.0',
                        'path': 'makehuman/data/targets/macrodetails/universal-female-young-averagemuscle-minweight.target',
                        'sha256': 'e53a4afc87ac2703460a59e8290b1111478aeee5c02ece6735328c1f8c62eb63'},
 'female-skin-dark.png': {'compressed': 4427955,
                          'crc': 4033131569,
                          'license': 'CC0-1.0',
                          'method': 8,
                          'offset': 27239667,
                          'packMember': 'skins/young_african_female/young_darkskinned_female_diffuse.png',
                          'sha256': '96aa4a96b247fc90d371587bb88e6ae3bfc77e83f5126f17e6bbb713aa200470'},
 'female-skin.png': {'compressed': 4391823,
                     'crc': 4200317813,
                     'license': 'CC0-1.0',
                     'method': 8,
                     'offset': 58763113,
                     'packMember': 'skins/young_caucasian_female/young_lightskinned_female_diffuse.png',
                     'sha256': 'b2a6ac8cd4f9febdb447368e29c76cd68410bb66e46d9dcfa2d5f75126eea8fc'},
 'female.target': {'license': 'CC0-1.0',
                   'path': 'makehuman/data/targets/macrodetails/caucasian-female-young.target',
                   'sha256': '118379f6e8ba9266247fdb8788a20e1df40a239f97ced0b9905bcbcc74f6e820'},
 'hair-afro.mhclo': {'compressed': 51632,
                     'crc': 1407668219,
                     'license': 'CC0-1.0',
                     'method': 8,
                     'offset': 238649397,
                     'packMember': 'hair/afro01/afro01.mhclo',
                     'sha256': '9977bd4507e2dd1408504b7a39a6f585ffa2d3ba3aa40ad4bdc2844884bbebb5'},
 'hair-afro.obj': {'compressed': 34735,
                   'crc': 1663250277,
                   'license': 'CC0-1.0',
                   'method': 8,
                   'offset': 238701724,
                   'packMember': 'hair/afro01/afro01.obj',
                   'sha256': '8344fffef15120a05a89219f31184ca2958537223fa885c885137ad1e97edcb8'},
 'hair-afro.png': {'compressed': 4807104,
                   'crc': 953081953,
                   'license': 'CC0-1.0',
                   'method': 8,
                   'offset': 238736539,
                   'packMember': 'hair/afro01/afro_diffuse.png',
                   'sha256': 'dc0db7dd8a13802f02303ca7e49844b219e09db134471b7061538a8af8f7c7fb'},
 'hair-long.mhclo': {'compressed': 73147,
                     'crc': 1883604236,
                     'license': 'CC0-1.0',
                     'method': 8,
                     'offset': 265768542,
                     'packMember': 'hair/long01/long01.mhclo',
                     'sha256': '94ecbebfd834da2cbee2ce90b730972590eb22a252ecd9592038ea736e063646'},
 'hair-long.obj': {'compressed': 72272,
                   'crc': 1344197710,
                   'license': 'CC0-1.0',
                   'method': 8,
                   'offset': 265696190,
                   'packMember': 'hair/long01/long01.obj',
                   'sha256': '7f1d6dadbdf9e96435251955d6657e77ea5433c9bc7c85a5c5f5e4eae0cb9a8c'},
 'hair-long.png': {'compressed': 2906544,
                   'crc': 404196468,
                   'license': 'CC0-1.0',
                   'method': 8,
                   'offset': 262788847,
                   'packMember': 'hair/long01/long01_diffuse.png',
                   'sha256': 'e8dc25d90f8f62467e8630420e1240a400d070054fb7c3f1d3f7bf3e457d6c2c'},
 'hair-medium.mhclo': {'compressed': 116992,
                       'crc': 3818770036,
                       'license': 'CC0-1.0',
                       'method': 8,
                       'offset': 246068686,
                       'packMember': 'hair/bob01/bob01.mhclo',
                       'sha256': 'a295b11ab6c7808afa1e01d0c79fb595bbbd7885f65252766486c9fcf6d158c5'},
 'hair-medium.obj': {'compressed': 136544,
                     'crc': 2655678121,
                     'license': 'CC0-1.0',
                     'method': 8,
                     'offset': 250427645,
                     'packMember': 'hair/bob01/bob01.obj',
                     'sha256': 'd7fb73806f47ee37ba3c37bcfadff40a91ba99635d08c3e02d94b4acbf97c231'},
 'hair-medium.png': {'compressed': 4241081,
                     'crc': 1656468869,
                     'license': 'CC0-1.0',
                     'method': 8,
                     'offset': 246186478,
                     'packMember': 'hair/bob01/bob01_diffuse.png',
                     'sha256': '2b38bc7a028e06e8e633accb7fe2dd1b2bacbb9d32463df73f39f82e63ef9009'},
 'hair-ponytail.mhclo': {'compressed': 82028,
                         'crc': 1792184878,
                         'license': 'CC0-1.0',
                         'method': 8,
                         'offset': 254558226,
                         'packMember': 'hair/ponytail01/ponytail01.mhclo',
                         'sha256': '97fc50b12bcb3b1c7b33edddd8d427a2604ffb06fe79b31132bf47f82d7afbac'},
 'hair-ponytail.obj': {'compressed': 87120,
                       'crc': 2835480296,
                       'license': 'CC0-1.0',
                       'method': 8,
                       'offset': 250564341,
                       'packMember': 'hair/ponytail01/ponytail01.obj',
                       'sha256': 'd9f5fe96fbedbc8006220d87aad0e4a33d15286eb6b21f5929661cdc490ebf5a'},
 'hair-ponytail.png': {'compressed': 3906581,
                       'crc': 3412443288,
                       'license': 'CC0-1.0',
                       'method': 8,
                       'offset': 250651549,
                       'packMember': 'hair/ponytail01/ponytail01_diffuse.png',
                       'sha256': 'dcb364300cac06ce8bef91b2f7c0970baf310898bbdd06b0c6b884ee9306eb97'},
 'hair.mhclo': {'compressed': 68368,
                'crc': 2069295345,
                'license': 'CC0-1.0',
                'method': 8,
                'offset': 236127380,
                'packMember': 'hair/short01/short01.mhclo',
                'sha256': 'ae1ffaa98da5753b803b3a173bede4895d2215e6bb94763f3765a71f0e984f35'},
 'hair.obj': {'compressed': 67065,
              'crc': 98592969,
              'license': 'CC0-1.0',
              'method': 8,
              'offset': 236196558,
              'packMember': 'hair/short01/short01.obj',
              'sha256': 'd998d8416f9b5d5591f1d756f4d292288d000a6951bc0f4d2e8e72727bbc44fa'},
 'hair.png': {'compressed': 2338834,
              'crc': 2320943918,
              'license': 'CC0-1.0',
              'method': 8,
              'offset': 236263705,
              'packMember': 'hair/short01/short01_diffuse.png',
              'sha256': 'f34a0957184e3d1e911ed59245f874f8d4843f61ee44ff49f43edb4be0196949'},
 'lean.target': {'license': 'CC0-1.0',
                 'path': 'makehuman/data/targets/macrodetails/universal-male-young-averagemuscle-minweight.target',
                 'sha256': 'fac0d53b7051f4d1f06230d0b419e916eb5bae5ce67c031a9998fdde05229755'},
 'license.txt': {'license': 'CC0-1.0',
                 'path': 'LICENSE.ASSETS.md',
                 'sha256': 'f6089cba01cb570a24712b41ab8a586ccd3cc5ef53dc266ca50b95c288956d2c'},
 'male-asian-skin.png': {'compressed': 3589718,
                         'crc': 4054467912,
                         'license': 'CC0-1.0',
                         'method': 8,
                         'offset': 55094118,
                         'packMember': 'skins/young_asian_male/young_lightskinned_male_diffuse3.png',
                         'sha256': 'f50016a5507fc687dc8df06599c8ea48de950cd185de33a71cafc1319ddab4d5'},
 'male-asian.target': {'license': 'CC0-1.0',
                       'path': 'makehuman/data/targets/macrodetails/asian-male-young.target',
                       'sha256': 'ed2e8c191cb6b87b4a2d97c80486acb2604fa549316c7aa2a738a5d5a14334dc'},
 'male-black.target': {'license': 'CC0-1.0',
                       'path': 'makehuman/data/targets/macrodetails/african-male-young.target',
                       'sha256': '894abc1fbb3d28543a51fef16f89d5d4bdf9aa2e1534413339811a3d47818b7d'},
 'male.target': {'license': 'CC0-1.0',
                 'path': 'makehuman/data/targets/macrodetails/caucasian-male-young.target',
                 'sha256': '70e228ba7164737dae664454394536fc5935fa48d333c1a97d77e2dc6eacc5f5'},
 'polo-normal.png': {'author': 'Namuhekam',
                     'compressed': 5311884,
                     'crc': 1050072632,
                     'license': 'CC0-1.0',
                     'licenseURL': 'https://static.makehumancommunity.org/assets/assetpacks/shirts01.html',
                     'method': 8,
                     'offset': 7439285,
                     'packMember': 'clothes/namuhekam_male_polo_shirt/Polo_Normal_OpenGL.png',
                     'sha256': '1428ecac615cf45d409f42167b3d4cba70ea77a14a0c4f06ff5d01b75e7a8b5c',
                     'url': 'https://files2.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip'},
 'polo-roughness.png': {'author': 'Namuhekam',
                        'compressed': 559521,
                        'crc': 3148677723,
                        'license': 'CC0-1.0',
                        'licenseURL': 'https://static.makehumancommunity.org/assets/assetpacks/shirts01.html',
                        'method': 8,
                        'offset': 12751655,
                        'packMember': 'clothes/namuhekam_male_polo_shirt/Polo_Roughness.png',
                        'sha256': 'b7205361068df100f8f63256a265d052dfa4bbec96d826e7999b23fcf17c95c2',
                        'url': 'https://files2.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip'},
 'polo.mhclo': {'author': 'Namuhekam',
                'compressed': 46797,
                'crc': 3823161511,
                'license': 'CC0-1.0',
                'licenseURL': 'https://static.makehumancommunity.org/assets/assetpacks/shirts01.html',
                'method': 8,
                'offset': 14347669,
                'packMember': 'clothes/namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo',
                'sha256': '1639239b0d6d16ef2ca98f1f5af1af447d1e9e6950cd0fad9ecf774fa597434b',
                'url': 'https://files2.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip'},
 'polo.obj': {'author': 'Namuhekam',
              'compressed': 56285,
              'crc': 2479266468,
              'license': 'CC0-1.0',
              'licenseURL': 'https://static.makehumancommunity.org/assets/assetpacks/shirts01.html',
              'method': 8,
              'offset': 7325638,
              'packMember': 'clothes/namuhekam_male_polo_shirt/Polo_t-shirt.obj',
              'sha256': 'aaee5f49077a8bacb8b1077910e4b9cc7946d587c75e367273f4ecaf94abd627',
              'url': 'https://files2.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip'},
 'polo.png': {'author': 'Namuhekam',
              'compressed': 1234736,
              'crc': 2360567097,
              'license': 'CC0-1.0',
              'licenseURL': 'https://static.makehumancommunity.org/assets/assetpacks/shirts01.html',
              'method': 8,
              'offset': 6090791,
              'packMember': 'clothes/namuhekam_male_polo_shirt/Polo_Base_Color.png',
              'sha256': 'd8e74dbcc3e79227dd7f6d8b1e0ed6c614eb11d4dc3cfeb935222783c23ae64b',
              'url': 'https://files2.makehumancommunity.org/asset_packs/shirts01/shirts01_cc0.zip'},
 'rig.json': {'license': 'CC0-1.0',
              'path': 'makehuman/data/rigs/default.mhskel',
              'sha256': '99f179bce0aa850b45d4191a1d0d234c5851f881c057439470ded3bddf729a24'},
 'shirt-normal.png': {'compressed': 6053909,
                      'crc': 2574698187,
                      'license': 'CC0-1.0',
                      'method': 8,
                      'offset': 98150970,
                      'packMember': 'clothes/male_casualsuit04/male_casualsuit04_normal.png',
                      'sha256': '006c0c0dfecaeda1a749f737ac15bfc228ebb76dbbcbf9871993e267a545ca69'},
 'shirt.mhclo': {'compressed': 42767,
                 'crc': 445502132,
                 'license': 'CC0-1.0',
                 'method': 8,
                 'offset': 107013531,
                 'packMember': 'clothes/male_casualsuit04/male_casualsuit04.mhclo',
                 'sha256': '8c1a2d3272cd51ba03f0840d593eddc6325d3d2c4c8529f8203d2c2cad3d0cef'},
 'shirt.obj': {'compressed': 43117,
               'crc': 3011514520,
               'license': 'CC0-1.0',
               'method': 8,
               'offset': 104237356,
               'packMember': 'clothes/male_casualsuit04/male_casualsuit04.obj',
               'sha256': '9a56b7b1cb27589233dc048e8ccf1fd93d03f3a5c01a668f0e8a189ebdea7a34'},
 'shoes.mhclo': {'compressed': 25723,
                 'crc': 2509739001,
                 'license': 'CC0-1.0',
                 'method': 8,
                 'offset': 110187741,
                 'packMember': 'clothes/shoes05/shoes05.mhclo',
                 'sha256': '75fc467264b085d7a05ce0c9b5628bb364b246392c59524c556fa09f92b6cb16'},
 'shoes.obj': {'compressed': 34275,
               'crc': 2216852263,
               'license': 'CC0-1.0',
               'method': 8,
               'offset': 110129187,
               'packMember': 'clothes/shoes05/shoes05.obj',
               'sha256': '5726aabac42ff489998d0a769545dea013961bbb71b9c6024d75170181a98818'},
 'shoes.png': {'compressed': 1289694,
               'crc': 3090551316,
               'license': 'CC0-1.0',
               'method': 8,
               'offset': 108798945,
               'packMember': 'clothes/shoes05/shoes05_diffuse.png',
               'sha256': '7fe5ea2600f6578cdf017da3392ae13aedabea8e8cc1dd6302a8f57e8fb7e5af'},
 'skin-dark.png': {'compressed': 2972845,
                   'crc': 46561097,
                   'license': 'CC0-1.0',
                   'method': 8,
                   'offset': 8832382,
                   'packMember': 'skins/young_african_male/young_darkskinned_male_diffuse.png',
                   'sha256': 'e3f0dbb634e4c68561338f0087f7a122444e84ec56df102212f1222aa12e4d50'},
 'skin.png': {'compressed': 3690012,
              'crc': 3877881233,
              'license': 'CC0-1.0',
              'method': 8,
              'offset': 23394852,
              'packMember': 'skins/young_caucasian_male/young_lightskinned_male_diffuse.png',
              'sha256': '862a26e335e958b70534cb5f0d7c47ef30ab148a56c42b3e9da969cf76f12963'},
 'weights.json': {'license': 'CC0-1.0',
                  'path': 'makehuman/data/rigs/default_weights.mhw',
                  'sha256': '0f3641d651ae3d00ad6b4ccee43142edb109d3bd909d27d9e4139ef1beed8625'}}


def fetch_source(key, cache, offline=False):
    info = SOURCES[key]
    destination = cache / key
    if destination.exists() and hashlib.sha256(destination.read_bytes()).hexdigest() == info['sha256']:
        return destination
    if offline:
        raise FileNotFoundError('Verified source missing from offline cache: ' + str(destination))
    if 'packMember' in info:
        start = info['offset']
        end = start + 30 + len(info['packMember'].encode()) + 4096 + info['compressed']
        request = urllib.request.Request(info.get('url', PACK_URL), headers={'Range': f'bytes={start}-{end}'})
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise RuntimeError('Asset host did not support a selective byte range')
            raw = response.read()
        name_length, extra_length = struct.unpack_from('<HH', raw, 26)
        payload = raw[30 + name_length + extra_length:30 + name_length + extra_length + info['compressed']]
        data = zlib.decompress(payload, -15) if info['method'] == 8 else payload
        if zlib.crc32(data) != info['crc']:
            raise ValueError('Asset pack changed: CRC does not match ' + key)
    else:
        with urllib.request.urlopen(RAW_ROOT + info['path'], timeout=60) as response:
            data = response.read()
    if hashlib.sha256(data).hexdigest() != info['sha256']:
        raise ValueError('SHA-256 mismatch for ' + key)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return destination


def read_obj(path):
    positions, uvs, groups = [], [], collections.defaultdict(list)
    group = 'default'
    for line in path.read_text().splitlines():
        parts = line.split()
        if not parts or parts[0].startswith('#'):
            continue
        if parts[0] == 'v':
            positions.append([float(v) for v in parts[1:4]])
        elif parts[0] == 'vt':
            uvs.append([float(v) for v in parts[1:3]])
        elif parts[0] == 'g':
            group = parts[1]
        elif parts[0] == 'f':
            corners = []
            for corner in parts[1:]:
                indices = corner.split('/')
                corners.append((int(indices[0]) - 1, int(indices[1]) - 1 if len(indices) > 1 and indices[1] else -1))
            groups[group].append(corners)
    return positions, uvs, dict(groups)


def apply_target(positions, path, strength):
    for line in path.read_text().splitlines():
        parts = line.split()
        if not parts or parts[0].startswith('#'):
            continue
        index = int(parts[0])
        for axis in range(3):
            positions[index][axis] += float(parts[axis + 1]) * strength


def centroid(positions, indices):
    indices = sorted(set(indices))
    return [sum(positions[i][axis] for i in indices) / len(indices) for axis in range(3)]


def make_rig(positions, skeleton, weight_data):
    bone_defs = skeleton['bones']
    ordered = []
    def add(name):
        if name in ordered:
            return
        parent = bone_defs[name]['parent']
        if parent:
            add(parent)
        ordered.append(name)
    for name in sorted(bone_defs):
        add(name)
    bone_index = {name: index for index, name in enumerate(ordered)}
    bones = []
    for name in ordered:
        definition = bone_defs[name]
        bones.append({'name': name,
                      'parent': bone_index.get(definition['parent'], -1),
                      'position': centroid(positions, skeleton['joints'][definition['head']]),
                      'tail': centroid(positions, skeleton['joints'][definition['tail']])})
    influences = collections.defaultdict(list)
    for name, values in weight_data['weights'].items():
        for vertex, weight in values:
            if weight > 0:
                influences[vertex].append((bone_index[name], weight))
    return bones, {index: normalized_weights(weights) for index, weights in influences.items()}


def normalized_weights(weights):
    combined = collections.defaultdict(float)
    for bone, weight in weights:
        combined[bone] += weight
    top = sorted(combined.items(), key=lambda pair: (-pair[1], pair[0]))[:4]
    total = sum(weight for _, weight in top)
    if total <= 0:
        top, total = [(0, 1.0)], 1.0
    result = [(bone, weight / total) for bone, weight in top]
    return result + [(0, 0.0)] * (4 - len(result))


def fit_proxy(path, base_positions, influences):
    mappings = []
    scales = [1.0, 1.0, 1.0]
    reading_vertices = False
    for line in path.read_text().splitlines():
        parts = line.split()
        if not parts or parts[0].startswith('#'):
            continue
        if parts[0] in ['x_scale', 'y_scale', 'z_scale']:
            axis = ['x_scale', 'y_scale', 'z_scale'].index(parts[0])
            scales[axis] = abs(base_positions[int(parts[1])][axis] - base_positions[int(parts[2])][axis]) / float(parts[3])
        if parts[0] == 'verts':
            reading_vertices = True
            continue
        if reading_vertices and not parts[0].lstrip('-').isdigit():
            if parts[0] == 'delete_verts':
                break
            # Some bundled MHCLO files put material metadata after `verts`.
            continue
        if reading_vertices:
            if len(parts) == 1:
                mappings.append(([int(parts[0])], [1.0], [0.0, 0.0, 0.0]))
            elif len(parts) >= 9:
                mappings.append(([int(v) for v in parts[:3]], [float(v) for v in parts[3:6]], [float(v) for v in parts[6:9]]))
            else:
                raise ValueError('Unknown MHCLO vertex mapping')
    positions, proxy_weights = [], {}
    for index, (refs, weights, offsets) in enumerate(mappings):
        positions.append([sum(base_positions[ref][axis] * weight for ref, weight in zip(refs, weights)) + offsets[axis] * scales[axis] for axis in range(3)])
        weighted = []
        for ref, weight in zip(refs, weights):
            weighted.extend((bone, value * max(0.0, weight)) for bone, value in influences.get(ref, [(0, 1.0)]))
        proxy_weights[index] = normalized_weights(weighted)
    return positions, proxy_weights


def vector_subtract(a, b):
    return [a[i] - b[i] for i in range(3)]


def cross(a, b):
    return [a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]]


def mesh_json(positions, uvs, faces, joints, bones, weights):
    triangles = [(face[0], face[i], face[i+1]) for face in faces for i in range(1, len(face)-1)]
    normals = [[0.0, 0.0, 0.0] for _ in positions]
    for tri in triangles:
        a, b, c = [positions[corner[0]] for corner in tri]
        normal = cross(vector_subtract(b, a), vector_subtract(c, a))
        for vertex, _ in tri:
            for axis in range(3):
                normals[vertex][axis] += normal[axis]
    for normal in normals:
        length = math.sqrt(sum(value * value for value in normal))
        if length > 1e-12:
            for axis in range(3):
                normal[axis] /= length
    result = {'positions': [], 'normals': [], 'uvs': [], 'indices': [],
              'sourceVertexIndices': [], 'joints': joints, 'bones': bones,
              'boneIndices': [], 'boneWeights': []}
    corner_map = {}
    for tri in triangles:
        for corner in tri:
            if corner not in corner_map:
                corner_map[corner] = len(corner_map)
                vertex, uv = corner
                result['positions'].extend(positions[vertex])
                result['normals'].extend(normals[vertex])
                # OBJ uses a bottom-left V origin. Direct SceneKit UIImage
                # sampling uses top-left; flip once here for every atlas.
                result['uvs'].extend([uvs[uv][0], 1.0 - uvs[uv][1]] if uv >= 0 else [0.0, 0.0])
                result['sourceVertexIndices'].append(vertex)
                vertex_weights = weights.get(vertex, [(0, 1.0), (0, 0.0), (0, 0.0), (0, 0.0)])
                result['boneIndices'].extend(bone for bone, _ in vertex_weights)
                result['boneWeights'].extend(weight for _, weight in vertex_weights)
            result['indices'].append(corner_map[corner])
    result['bounds'] = {'min': [min(result['positions'][axis::3]) for axis in range(3)],
                        'max': [max(result['positions'][axis::3]) for axis in range(3)]}
    return result


def round_floats(value):
    if isinstance(value, float):
        return round(value, 6)
    if isinstance(value, list):
        return [round_floats(v) for v in value]
    if isinstance(value, dict):
        return {k: round_floats(v) for k, v in value.items()}
    return value


def save_mesh(name, data):
    count = len(data['positions']) // 3
    assert count and len(data['normals']) == count*3 and len(data['uvs']) == count*2
    assert len(data['boneIndices']) == len(data['boneWeights']) == count*4
    assert max(data['indices']) < count and min(data['indices']) >= 0
    assert all(math.isfinite(v) for v in data['positions'] + data['normals'] + data['uvs'])
    for i in range(count):
        assert abs(sum(data['boneWeights'][i*4:(i+1)*4]) - 1) < 1e-5
    OUTPUT.joinpath(name).write_text(json.dumps(round_floats(data), separators=(',', ':'), allow_nan=False) + '\n')
    print(f'{name}: {count:,} vertices, {len(data["indices"])//3:,} triangles')


def apply_head_identity(positions, base_path, variant_path, floor, scale, transition, head_joint_vertices):
    """Apply authored identity differences above a smooth neck transition.

    Scale/floor come from the standardized same-sex body. Never renormalize a
    variant to its new head height, which would change every garment fit.
    """
    def target_deltas(path):
        result = {}
        for line in path.read_text().splitlines():
            fields = line.split()
            if fields and not fields[0].startswith('#'):
                result[int(fields[0])] = [float(v) for v in fields[1:4]]
        return result
    baseline, variant = target_deltas(base_path), target_deltas(variant_path)
    # Macro targets also encode stature differences. Remove their global head
    # translation at the authored skull-base landmark before retaining local
    # facial differences; otherwise heads shift several centimeters vertically.
    head_offset = [sum(variant.get(i, [0.0]*3)[axis] - baseline.get(i, [0.0]*3)[axis]
                       for i in head_joint_vertices) / len(head_joint_vertices)
                   for axis in range(3)]
    start, end = transition
    for index, point in enumerate(positions):
        y = (point[1] - floor) * scale
        if y <= start:
            continue
        t = max(0.0, min(1.0, (y - start) / (end - start)))
        amount = t * t * (3.0 - 2.0 * t)
        old, new = baseline.get(index, [0.0]*3), variant.get(index, [0.0]*3)
        for axis in range(3):
            point[axis] += (new[axis] - old[axis] - head_offset[axis]) * amount


def export_model(paths, model_prefix, identity_target, body_target_weights, height_meters,
                 head_identity_target=None, transition=None, fixed_hair=None):
    positions, uvs, groups = read_obj(paths['base.obj'])
    apply_target(positions, paths[identity_target], 1.0)
    for target, weight in body_target_weights.items():
        apply_target(positions, paths[target], weight)
    body_ids = set(corner[0] for face in groups['body'] for corner in face)
    floor = min(positions[i][1] for i in body_ids)
    scale = height_meters / (max(positions[i][1] for i in body_ids) - floor)
    if head_identity_target is not None:
        apply_head_identity(positions, paths[identity_target], paths[head_identity_target], floor, scale, transition,
                            json.loads(paths['rig.json'].read_text())['joints']['head____head'])
    def to_meters(points):
        return [[point[0]*scale, (point[1]-floor)*scale, point[2]*scale] for point in points]
    meter_positions = to_meters(positions)
    skeleton = json.loads(paths['rig.json'].read_text())
    weight_data = json.loads(paths['weights.json'].read_text())
    bones, weights = make_rig(meter_positions, skeleton, weight_data)
    joints = {name: centroid(meter_positions, [corner[0] for face in faces for corner in face])
              for name, faces in groups.items() if name.startswith('joint-')}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    save_mesh(model_prefix + 'athlete.json', mesh_json(meter_positions, uvs, groups['body'], joints, bones, weights))
    if head_identity_target is None:
        save_mesh(model_prefix + 'helper-tights.json', mesh_json(meter_positions, uvs, groups['helper-tights'], joints, bones, weights))
    proxy_assets = [('eyes', 'eyes.json'), ('hair', 'hair-short.json'),
                             ('shirt', 'shirt.json'), ('shoes', 'shoes.json'), ('polo', 'polo.json'),
                             ('hair-medium', 'hair-medium.json'), ('hair-long', 'hair-long.json'),
                             ('hair-ponytail', 'hair-ponytail.json')]
    if head_identity_target is not None:
        proxy_assets = [('eyes', 'eyes.json'), fixed_hair]
    for prefix, filename in proxy_assets:
        proxy_original, proxy_uvs, proxy_groups = read_obj(paths[prefix + '.obj'])
        fitted, proxy_weights = fit_proxy(paths[prefix + '.mhclo'], positions, weights)
        faces = [face for group in proxy_groups.values() for face in group]
        if prefix in ['shirt', 'shoes']:
            # These upstream outfits have disconnected garment components.
            # Select whole components so seams are not cut by a height plane.
            parents = list(range(len(proxy_original)))
            def component(index):
                while parents[index] != index:
                    parents[index] = parents[parents[index]]
                    index = parents[index]
                return index
            for face in faces:
                for corner in face[1:]:
                    parents[component(corner[0])] = component(face[0][0])
            component_floor, component_top = {}, {}
            for index, point in enumerate(proxy_original):
                root = component(index)
                component_floor[root] = min(component_floor.get(root, math.inf), point[1])
                component_top[root] = max(component_top.get(root, -math.inf), point[1])
            if prefix == 'shirt':
                # The tee is above original Y=1.0; jeans extend to the ankles.
                faces = [face for face in faces if component_floor[component(face[0][0])] > 1.0]
            else:
                # The socks reach above original Y=-7.0; shoes end below it.
                sock_faces = [face for face in faces if component_top[component(face[0][0])] > -7.0]
                save_mesh(model_prefix + 'socks.json', mesh_json(to_meters(fitted), proxy_uvs, sock_faces, joints, bones, proxy_weights))
                faces = [face for face in faces if component_top[component(face[0][0])] <= -7.0]
        save_mesh(model_prefix + filename, mesh_json(to_meters(fitted), proxy_uvs, faces, joints, bones, proxy_weights))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-cache', type=Path, default=Path('/tmp/rally-avatar-source-cache'))
    parser.add_argument('--offline', action='store_true', help='Require a populated verified source cache; never access the network')
    args = parser.parse_args()
    args.source_cache.mkdir(parents=True, exist_ok=True)
    paths = {key: fetch_source(key, args.source_cache, args.offline) for key in SOURCES}
    export_model(paths, '', 'male.target', BODY_TARGET_WEIGHTS, HEIGHT_METERS)
    export_model(paths, 'female-', 'female.target', FEMALE_BODY_TARGET_WEIGHTS, FEMALE_HEIGHT_METERS)
    for family in ['male-asian', 'male-black', 'female-asian', 'female-black']:
        female = family.startswith('female')
        hair = ('hair-ponytail', 'hair-ponytail.json') if female else (
            ('hair-afro', 'hair-afro.json') if family == 'male-black' else ('hair', 'hair-short.json'))
        export_model(paths, family + '-', 'female.target' if female else 'male.target',
                     FEMALE_BODY_TARGET_WEIGHTS if female else BODY_TARGET_WEIGHTS,
                     FEMALE_HEIGHT_METERS if female else HEIGHT_METERS,
                     head_identity_target=family + '.target',
                     transition=(1.40, 1.48) if female else (1.45, 1.53), fixed_hair=hair)
    for source, filename in [('skin.png', 'skin-diffuse.png'), ('skin-dark.png', 'skin-dark-diffuse.png'),
                             ('female-skin.png', 'female-skin-diffuse.png'),
                             ('female-skin-dark.png', 'female-skin-dark-diffuse.png'),
                             ('male-asian-skin.png', 'male-asian-skin-diffuse.png'),
                             ('female-asian-skin.png', 'female-asian-skin-diffuse.png'),
                             ('hair-afro.png', 'hair-afro-diffuse.png'),
                             ('eyes.png', 'eyes-diffuse.png'), ('hair.png', 'hair-diffuse.png'),
                             ('shirt-normal.png', 'shirt-normal.png'), ('shoes.png', 'shoes-diffuse.png'),
                             ('polo.png', 'polo-diffuse.png'), ('polo-normal.png', 'polo-normal.png'),
                             ('polo-roughness.png', 'polo-roughness.png'),
                             ('hair-medium.png', 'hair-medium-diffuse.png'),
                             ('hair-long.png', 'hair-long-diffuse.png'),
                             ('hair-ponytail.png', 'hair-ponytail-diffuse.png'),
                             ('license.txt', 'LICENSE-MAKEHUMAN-CC0.txt')]:
        shutil.copyfile(paths[source], OUTPUT / filename)
    manifest = {'schemaVersion': 1, 'source': 'MakeHuman Community hm08 graphical assets',
                'sourceCommit': UPSTREAM_COMMIT, 'license': 'CC0-1.0',
                'licenseURL': 'https://github.com/makehumancommunity/makehuman/blob/'+UPSTREAM_COMMIT+'/LICENSE.md',
                'assetPackLicenseURL': PACK_LICENSE_URL, 'assetPackURL': PACK_URL,
                'units': 'meters', 'upAxis': '+Y', 'forwardAxis': '+Z',
                'uvConvention': 'SceneKit UIImage coordinates: (OBJ u, 1 - OBJ v). Do not flip again at runtime.',
                'heightMeters': HEIGHT_METERS,
                'adultBody': 'Original adult male identity; lean tennis build (muscle=0.70, leanWeight=0.60)',
                'bodyTargetWeights': BODY_TARGET_WEIGHTS,
                'models': [
                    {'id': 'male', 'meshPrefix': '', 'heightMeters': HEIGHT_METERS,
                     'identityTarget': 'male.target', 'bodyTargetWeights': BODY_TARGET_WEIGHTS,
                     'skinTextures': ['skin-diffuse.png', 'skin-dark-diffuse.png']},
                    {'id': 'female', 'meshPrefix': 'female-', 'heightMeters': FEMALE_HEIGHT_METERS,
                     'identityTarget': 'female.target', 'bodyTargetWeights': FEMALE_BODY_TARGET_WEIGHTS,
                     'skinTextures': ['female-skin-diffuse.png', 'female-skin-dark-diffuse.png']}
                ],
                'players': [
                    {'id': 'male-european', 'baseBody': 'male', 'meshPrefix': '', 'hairMesh': 'hair-short.json', 'hairTexture': 'hair-diffuse.png', 'skinTexture': 'skin-diffuse.png'},
                    {'id': 'male-asian', 'baseBody': 'male', 'meshPrefix': 'male-asian-', 'hairMesh': 'male-asian-hair-short.json', 'hairTexture': 'hair-diffuse.png', 'skinTexture': 'male-asian-skin-diffuse.png'},
                    {'id': 'male-black', 'baseBody': 'male', 'meshPrefix': 'male-black-', 'hairMesh': 'male-black-hair-afro.json', 'hairTexture': 'hair-afro-diffuse.png', 'skinTexture': 'skin-dark-diffuse.png'},
                    {'id': 'female-european', 'baseBody': 'female', 'meshPrefix': 'female-', 'hairMesh': 'female-hair-ponytail.json', 'hairTexture': 'hair-ponytail-diffuse.png', 'skinTexture': 'female-skin-diffuse.png'},
                    {'id': 'female-asian', 'baseBody': 'female', 'meshPrefix': 'female-asian-', 'hairMesh': 'female-asian-hair-ponytail.json', 'hairTexture': 'hair-ponytail-diffuse.png', 'skinTexture': 'female-asian-skin-diffuse.png'},
                    {'id': 'female-black', 'baseBody': 'female', 'meshPrefix': 'female-black-', 'hairMesh': 'female-black-hair-ponytail.json', 'hairTexture': 'hair-ponytail-diffuse.png', 'skinTexture': 'female-skin-dark-diffuse.png'}
                ],
                'headIdentityBlend': {'male': {'startY': 1.45, 'completeY': 1.53}, 'female': {'startY': 1.40, 'completeY': 1.48},
                                      'method': 'Authored adult ethnic target minus same-sex European target, aligned at the skull-base head joint to remove macro stature translation, then smoothstep through neck; identical baseline body/height scale below transition'},
                'modelIntegration': 'Six fixed player identities on two standardized bodies. Use player prefix for athlete and eyes and exact hair/skin names from players. Use baseline same-sex clothing prefix (empty for male, female- for female), never the full identity prefix. Build skeleton from selected athlete; below-neck bind positions are shared per sex.',
                'pose': 'MakeHuman neutral A-pose; all bones have world-aligned axes and bind translations only',
                'bonePositionConvention': 'Absolute bind-space meters; subtract parent position for local bone translation',
                'skinWeights': 'Official MakeHuman weights, strongest four influences normalized per vertex',
                'meshConversion': 'Body only; helpers excluded. UV seams duplicated, area-weighted smooth normals. Eye/hair/garment MHCLO barycentric fitting to morphed body. Shirt is upper connected component from casualsuit04.',
                'commerceScope': 'Unbranded base athlete; product-specific garment geometry and retailer catalog assets are separate.',
                'sources': SOURCES}
    (OUTPUT / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (OUTPUT / 'README.md').write_text('''# Rally human assets\n\nThese are anatomical CC0 MakeHuman graphical assets, converted by the project-owned\n`python3 scripts/prepare_avatar_assets.py` converter. See `asset-manifest.json` for\nsource URLs, hashes, transforms and the coordinate/skinning contract.\n\nRebuild with verified downloads: `python3 scripts/prepare_avatar_assets.py`.\nAfter that, rebuild without network: `python3 scripts/prepare_avatar_assets.py --offline`.\nUse `--source-cache /path/to/cache` to keep raw inputs in a durable location.\nThe default cache is `/tmp/rally-avatar-source-cache`; it is not an app dependency.\n\nThe skin, eyes and hair use real UV maps with V flipped once for direct SceneKit\nUIImage sampling. Do not add another material or runtime V flip. Body helpers are separate, never body\ngeometry. There are exactly two base models: an original adult male (1.78m, 70% muscle,\n60% lean-weight interpolation), and an original adult female (1.73m, 65% muscle,\n55% lean-weight interpolation). Female geometry uses the adult female identity\nand female-specific body targets, not a scale transform of the male. The neutral model must be dressed by\nthe shared renderer. All meshes\nshare one full rig and calibrated scale; no independent face or limb primitives\nare required. `sourceVertexIndices` refer to the original OBJ for each mesh.\n\nThere are six fixed identities, defined in the manifest `players` array: three\nmale and three female (European, Asian, Black), each with an authored adult face\nand source skin atlas. Asian and Black faces apply source target differences\nonly above a smooth neck transition, not a skin tint. Their authored skull-base\nhead landmarks are aligned to remove macro stature offsets while retaining local\nfacial shape differences. Below Y=1.45m (male) or\n1.40m (female), the body vertices and skeleton positions remain identical to\nthe same-sex base, so all garments share one fit per sex. Never rescale each\nidentity to its slightly different head height.\n\nUse the selected player prefix for athlete/eyes and exact hair/texture names\nfrom the manifest. Construct the rig from that athlete. Clothing uses the same-sex\nbase prefix: empty for male, `female-` for female. Existing unprefixed assets\nremain the European male; `female-` remains the European female.\n\n`shoes.json` and `socks.json` are separated connected components and use\n`shoes-diffuse.png` UVs. `shirt.json` is the real tee component from a system\noutfit; `polo.json` is Namuhekam's CC0 polo. Short, medium, long and ponytail\nhair meshes each use corresponding RGBA texture files; alpha is embedded.\nSneaker soles extend below the barefoot origin; use `shoes.json` bounds to\nalign the shoe sole to the ground.\n\nThe output is a realistic anatomical base, not a scanned person, virtual fit\nsimulation, or brand-approved garment. Product-specific clothing needs its own\naccurate supplied mesh/textures.\n\nCC0 applies to the graphical assets; no MakeHuman application code is embedded.\n''')


if __name__ == '__main__':
    main()
