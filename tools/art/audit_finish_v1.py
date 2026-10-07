"""Audit Stage F authored assets and Godot import conventions without modifying them."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def audit(repo):
    manifest = json.loads((repo / 'assets/3d/finish_v1/manifest.json').read_text())
    checks, meshes, textures = [], [], []

    def check(value, label):
        checks.append({'label': label, 'pass': bool(value)})

    for name, expected in manifest['sha256'].items():
        check(hashlib.sha256((repo / name).read_bytes()).hexdigest() == expected, 'manifest SHA256 ' + name)
    for entry in manifest['generated']:
        raw = (repo / entry['file']).read_bytes()
        magic, version, length = struct.unpack_from('<III', raw)
        check(magic == 0x46546C67 and version == 2 and length == len(raw), 'valid GLB ' + entry['file'])
        chunk_length, chunk_type = struct.unpack_from('<II', raw, 12)
        check(chunk_type == 0x4E4F534A, 'GLB JSON ' + entry['file'])
        gltf = json.loads(raw[20:20 + chunk_length])
        triangles = 0
        for mesh in gltf['meshes']:
            for part in mesh['primitives']:
                check({'POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0'} <= part['attributes'].keys(), 'UV0/normals/tangents ' + mesh['name'])
                triangles += gltf['accessors'][part['indices']]['count'] // 3
        check(triangles == entry['triangles'], 'triangle count ' + entry['file'])
        roles = sorted({n['name'].split('_')[0] for n in gltf['nodes'] if 'mesh' in n})
        if 'parts.glb' not in entry['file']:
            check(set(roles) <= {'shell', 'metal', 'solar', 'foil', 'glass', 'light'}, 'mapped civilian material roles ' + entry['file'])
        meshes.append(dict(entry, bytes=len(raw), roles=roles))
    for image in sorted((repo / 'assets/textures/finish_v1').glob('*.png')):
        raw = image.read_bytes()
        width, height = struct.unpack_from('>II', raw, 16)
        params = dict(line.split('=', 1) for line in image.with_suffix('.png.import').read_text().splitlines() if '=' in line)
        normal = '_normal' in image.stem
        check(width == height == (1024 if image.stem.startswith('trim_') else 512), 'texture resolution ' + image.name)
        check(params.get('mipmaps/generate') == 'true', 'mipmaps ' + image.name)
        check(params.get('compress/mode') == '0', 'lossless review storage ' + image.name)
        check(params.get('compress/normal_map') == ('1' if normal else '2'), 'normal/data import ' + image.name)
        check(params.get('detect_3d/compress_to') == '0', 'stable review compression ' + image.name)
        textures.append({'file': image.relative_to(repo).as_posix(), 'width': width, 'height': height, 'bytes': len(raw),
                         'color_space': 'sRGB albedo sampler' if '_albedo' in image.stem else 'linear',
                         'mipmaps': params['mipmaps/generate'] == 'true', 'compression': 'lossless'})
    check(len(meshes) == 10, 'shared part set and nine hull GLBs')
    check(len(textures) == 20, 'six PBR map sets plus trim normal/AO')
    check(manifest['external_assets'] == [], 'no external asset provenance')
    sources = []
    for name in ['tools/art/build_finish_v1.py', 'tools/art/sources/finish_v1.blend']:
        raw = (repo / name).read_bytes()
        sources.append({'file': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
    return {'checks': len(checks), 'failures': [c['label'] for c in checks if not c['pass']], 'results': checks,
            'meshes': meshes, 'textures': textures, 'sources': sources,
            'mesh_bytes': sum(m['bytes'] for m in meshes), 'texture_png_bytes': sum(t['bytes'] for t in textures),
            'qualification': 'GLB structure, mappings, deterministic output checksums and import conventions. Visual UV/normal/seam/scale review is recorded separately. Lossless review maps with mips; target GPU compression remains Stage G.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path('.'))
    parser.add_argument('--out', type=Path, default=Path('build/stage_f/asset_audit.json'))
    args = parser.parse_args()
    result = audit(args.repo.resolve())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['checks', 'failures', 'mesh_bytes', 'texture_png_bytes']}))
    raise SystemExit(bool(result['failures']))
