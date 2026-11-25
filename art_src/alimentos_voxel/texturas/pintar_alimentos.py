#!/usr/bin/env python3
"""Pinta os nove atlas 48x32 a partir dos papéis e da geometria originais.

Execute: python3 art_src/alimentos_voxel/texturas/pintar_alimentos.py
As cores são autorais; cada padrão é calculado na posição 3D do voxel.
"""
import hashlib
import sys
import types
from pathlib import Path

from PIL import Image, ImageColor

ROOT = Path(__file__).resolve().parents[3]
ARTE = ROOT / 'art_src/alimentos_voxel'
OUT = Path(__file__).resolve().parent


def load_definitions():
    sys.modules.setdefault('bpy', types.ModuleType('bpy'))
    fruit_path = ROOT / 'tools/akuma_no_mi/gerar_frutas.py'
    fruit_code = fruit_path.read_text().rsplit('\nmain()', 1)[0]
    fruit = types.ModuleType('gerar_frutas')
    fruit.__file__ = str(fruit_path)
    exec(compile(fruit_code, str(fruit_path), 'exec'), fruit.__dict__)
    sys.modules['gerar_frutas'] = fruit
    path = ROOT / 'tools/alimentos_voxel/gerar_alimentos.py'
    mod = types.ModuleType('alimentos_voxel_defs')
    mod.__file__ = str(path)
    exec(compile(path.read_text(), str(path), 'exec'), mod.__dict__)
    return fruit, mod


def rgb(h):
    return ImageColor.getrgb(h)


def tint(c, value):
    return tuple(max(0, min(255, v + value)) for v in c) + (255,)


def color(fid, role, idx, normal, palette):
    x, y, z = idx
    base = rgb(palette[role])
    seed = hashlib.blake2s(f'{fid}/{role}/{x}/{y}/{z}'.encode(), digest_size=1).digest()[0]
    delta = 0
    # Material patterns are intentionally small and tied to the voxel position,
    # not to each face of the UV layout.
    if role in ('crosta', 'topo', 'casca', 'corpo', 'cauda', 'carne', 'tostado', 'legume', 'arroz'):
        if seed < 25: delta = -18
        elif seed > 233: delta = 15
    if fid == 'pao' and role == 'topo' and (x + 2*z) % 7 == 0: delta = -17
    if fid == 'maca' and role == 'casca' and y > 7 and x < 6: delta = 18
    if fid == 'peixe_assado' and role == 'corpo' and (z + y) % 5 == 0: delta = -27
    if fid == 'carne_assada' and role == 'carne' and (x + z) % 6 == 0: delta = -21
    if fid == 'sopa_de_peixe' and role == 'sopa' and (x + 2*z) % 7 == 0: delta = 15
    if fid == 'refeicao' and role == 'arroz' and seed < 36: delta = -14
    # The liquid is inside an opaque outer shell in the source mesh. Tint the
    # visible shell so the drink remains legible without claiming glass alpha.
    if fid == 'agua_potavel' and role == 'vidro' and 2 <= y < 9:
        base = rgb('#72b9dc')
    if fid == 'suco_de_laranja' and role == 'copo' and 3 <= y < 10:
        base = rgb('#ef9a35')
    if role in ('vidro', 'copo') and normal == (0,0,-1) and x in (5,6) and 4 <= y <= 9:
        delta = 32
    return tint(base, delta)


def make(fid, spec, fruit, food):
    voxels = food.voxels(spec)
    visual = {}
    for idx in voxels:
        for view in fruit.VISTAS:
            normal = view[0]
            if tuple(idx[k] + normal[k] for k in range(3)) in voxels:
                continue
            target = fruit.texel(view, idx)
            depth = fruit.dot(idx, normal)
            if target not in visual or depth > visual[target][0]:
                visual[target] = (depth, idx, normal)
    image = Image.new('RGBA', (48,32), (0,0,0,0))
    for xy, (_, idx, normal) in visual.items():
        image.putpixel(xy, color(fid, voxels[idx], idx, normal, spec['paleta']))
    guide = Image.open(ARTE/'guias'/f'{fid}_guia.png').convert('RGBA')
    if image.getchannel('A').tobytes() != guide.getchannel('A').tobytes():
        raise ValueError(f'{fid}: atlas diverge da silhueta atual')
    image.save(OUT/f'{fid}.png')
    print(fid, len(visual), 'texels visíveis; guia OK')


if __name__ == '__main__':
    g, food = load_definitions()
    for fid, spec in food.ITENS.items():
        make(fid, spec, g, food)
