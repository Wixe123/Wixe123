#!/usr/bin/env python3
"""Bäddar in aerox.obj i index.html som en komprimerad blob (<script id="axd">).

Användning:  python3 -I tools/embed_aerox.py assets/aerox.obj index.html [ut.html]
Utan tredje argument skrivs index.html över.

Blobformat (läses av initAx() i index.html):
  uint32 LE  headerlängd, JSON-header, nollpadding till 4 byte,
  därefter positionsdata (int16 x3, skala 1/4000) och indexdata (uint32) per klass.
Allt gzippas och base64-kodas.

OBJ-filen använder NEGATIVA, relativa face-index och saknar material, så grupperna
sorteras i klasser efter nummer. Klassningen (CLASSES nedan) är en gissning från form
och placering i en sidovy, justera den om delar ser fel ut.
"""
import base64, collections, gzip, json, re, struct, sys
import numpy as np

# Grupp-id (polySurfaceNNNN) -> klass. Alla andra grupper: 'metal' om <150 ytor, annars 'dark'.
PAINT = {'1195', '1198', '1200', '1201', '1172', '1432', '1524', '1193', '1509'}
SEAT = {'1189', '1191'}
EXHAUST = {'1254'}
METAL = {'1301', '1302'}
WHEELS = {'1530': 'fTire', '1529': 'fRim', '1528': 'fDisc',
          '1467': 'rTire', '1466': 'rRim', '1441': 'rDisc'}

CY, CZ = 1.187, 3.01      # hjulcentrum (höjd, avstånd från mitten) efter förskjutning
DY, DZ = 0.087, 0.8       # förskjutning så att hjulen står på y=0 och modellen centreras
SCALE = 1.30 / 6.02       # modellenheter -> meter (hjulbas 1.30 m)
QUANT = 4000              # int16-kvantisering
DECAL_Y, DECAL_Z = 2.84, -1.92


def klass(n, nfaces):
    if n in WHEELS: return WHEELS[n]
    if n in PAINT: return 'paint'
    if n in SEAT: return 'seat'
    if n in EXHAUST: return 'ex'
    if n in METAL or nfaces < 150: return 'metal'
    return 'dark'


def parse(path):
    V, G, cur = [], collections.OrderedDict(), None
    for l in open(path, encoding='latin-1'):
        if l.startswith('v '):
            V.append(tuple(map(float, l.split()[1:4])))
        elif l.startswith('g '):
            cur = l.split()[1]; G.setdefault(cur, [])
        elif l.startswith('f '):
            ids = []
            for t in l.split()[1:]:
                i = int(t.split('/')[0])
                ids.append(len(V) + i if i < 0 else i - 1)
            G[cur].append(ids)
    return np.array(V), G


def build(obj):
    V, G = parse(obj)
    V[:, 1] += DY; V[:, 2] += DZ
    cls = collections.OrderedDict()
    for g, fs in G.items():
        n = g.replace('polySurface', '')
        cls.setdefault(klass(n, len(fs)), []).extend(fs)
    p = V[[i for f in G['polySurface1195'] for i in f]]
    m = (p[:, 2] > -2.7) & (p[:, 2] < -1.2) & (p[:, 1] > 2.4) & (p[:, 1] < 3.3)
    dx = float(np.abs(p[m][:, 0]).max()) + .01
    hdr = {'s': SCALE, 'cy': CY, 'cz': CZ, 'dx': dx, 'dy': DECAL_Y, 'dz': DECAL_Z, 'c': {}}
    pos, idx, ibs = b'', b'', {}
    for k, fs in cls.items():
        wheel = k.endswith(('Tire', 'Rim', 'Disc'))
        cen = np.array([0, CY, CZ if k[0] == 'f' else -CZ]) if wheel else np.zeros(3)
        mp, P, I = {}, [], []
        for f in fs:
            l = []
            for i in f:
                if i not in mp:
                    mp[i] = len(P); P.append(V[i] - cen)
                l.append(mp[i])
            I += [l[0], l[1], l[2]]
            if len(l) == 4: I += [l[0], l[2], l[3]]
        q = np.round(np.array(P) * QUANT)
        assert abs(q).max() < 32767, k
        pb = q.astype('<i2').tobytes()
        hdr['c'][k] = {'n': len(P), 'm': len(I), 'po': len(pos), 'io': 0}
        ibs[k] = np.array(I, '<u4').tobytes()
        pos += pb + b'\0' * ((4 - len(pb) % 4) % 4)
    tot = len(pos)
    for k in hdr['c']:
        hdr['c'][k]['io'] = tot + len(idx); idx += ibs[k]
    h = json.dumps(hdr).encode()
    blob = struct.pack('<I', len(h)) + h + b'\0' * ((4 - len(h) % 4) % 4) + pos + idx
    return base64.b64encode(gzip.compress(blob, 9)).decode(), hdr


def main(obj, html, out):
    b64, hdr = build(obj)
    h = open(html, encoding='utf-8').read()
    pat = re.compile(r'(<script id="axd" type="text/plain">)(.*?)(</script>)', re.S)
    assert len(pat.findall(h)) == 1, 'hittar inte <script id="axd"> exakt en gång'
    old = pat.search(h).group(2).strip()
    h = pat.sub(lambda m: m.group(1) + b64 + m.group(3), h)
    open(out, 'w', encoding='utf-8').write(h)
    print({k: (v['n'], v['m']) for k, v in hdr['c'].items()})
    same = gzip.decompress(base64.b64decode(old)) == gzip.decompress(base64.b64decode(b64))
    print('blob tecken:', len(b64), '| samma modelldata som tidigare:', same)


if __name__ == '__main__':
    if len(sys.argv) < 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else sys.argv[2])
