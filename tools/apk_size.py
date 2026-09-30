"""Measure the real ZIP payload and map imported textures back to their sources."""
import collections
import hashlib
import json
import re
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as apk:
    entries = {i.filename: i for i in apk.infolist()}
    sources = {}
    for name in entries:
        if name.endswith('.import'):
            for path in re.findall(r'res://([^"\n]+\.ctex)', apk.read(name).decode()):
                sources['assets/' + path] = name.removesuffix('.import')
    categories = collections.Counter()
    folders = collections.Counter()
    duplicates = collections.defaultdict(list)
    textures = []
    for name, item in entries.items():
        source = sources.get(name, name)
        category = ('textures' if name.endswith(('.ctex', '.png', '.webp', '.jpg')) else
                    'native' if name.endswith('.so') else
                    'audio' if name.endswith(('.ogg', '.mp3', '.wav')) else
                    'fonts' if name.endswith(('.ttf', '.otf', '.woff2')) else
                    'json' if name.endswith('.json') else 'other')
        categories[category] += item.compress_size
        if name.endswith('.ctex'):
            folders['/'.join(source.split('/')[:-1])] += item.compress_size
            textures.append((item.compress_size, source))
            duplicates[hashlib.sha256(apk.read(name)).hexdigest()].append(source)
    print(json.dumps({'apk': sys.argv[1], 'payload_bytes': sum(categories.values()),
                      'categories': categories, 'texture_folders': folders,
                      'largest_textures': sorted(textures, reverse=True)[:20],
                      'duplicate_textures': [v for v in duplicates.values() if len(v) > 1],
                      'native': [n for n in entries if n.endswith('.so')]},
                     ensure_ascii=False, indent=2))
