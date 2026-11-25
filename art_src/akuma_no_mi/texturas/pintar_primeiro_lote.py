#!/usr/bin/env python3
"""Pintura pixelada original para as frutas do primeiro lote.

Executar na raiz do projeto. Consulta a geometria do gerador compartilhado para
projetar o padrão sobre a superfície 3D e alinhar as seis vistas do atlas.
Os PNGs de referência são somente consulta; não são copiados para as texturas.
"""
import json
import math
import sys
import types
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
ARTE = ROOT / 'art_src/akuma_no_mi'
OUT = Path(__file__).resolve().parent
sys.modules.setdefault('bpy', types.ModuleType('bpy'))
code = (ROOT / 'tools/akuma_no_mi/gerar_frutas.py').read_text().rsplit('\nmain()', 1)[0]
g = {'__file__': str(ROOT / 'tools/akuma_no_mi/gerar_frutas.py'), '__name__': 'geometria'}
exec(compile(code, g['__file__'], 'exec'), g)

# Paletas originais, derivadas de leitura visual; hex aproximados, não amostras.
FRUTAS = {
    'gomu_gomu': ('#8b6cc4', '#c7abed', '#a288da', '#8a9f51', 'espiral'),
    'mera_mera': ('#e77820', '#ffbb50', '#b84b19', '#4a8b65', 'chama'),
    'hie_hie': ('#75bcd9', '#d2f1f5', '#3e809f', '#567991', 'gelo'),
    'goro_goro': ('#e6b928', '#fff097', '#b47b18', '#529562', 'raio'),
    'ope_ope': ('#c6414a', '#f17b80', '#8d293d', '#57945f', 'espiral'),
    'pika_pika': ('#eacb41', '#fff4a0', '#b99520', '#638b62', 'raio'),
    'yami_yami': ('#9978b5', '#d4b2e4', '#6c4e85', '#598151', 'bagas'),
    'magu_magu': ('#9d3229', '#f07737', '#521e22', '#6f6550', 'magma'),
    'suna_suna': ('#c99a61', '#efd09a', '#9b714c', '#6c935c', 'areia'),
    'bara_bara': ('#bc4b36', '#ef8762', '#80382b', '#4f8049', 'bagas'),
}


def rgba(value):
    h=value.lstrip('#')
    return tuple(int(h[i:i+2],16) for i in (0,2,4))+(255,)


def pattern(idx, kind):
    x,y,z = (v-11.5 for v in idx)
    longitude = (math.atan2(z,x) / (2*math.pi)) % 1
    if kind == 'magma':
        return 1 if (int(longitude*14 + y*.13) + int(y*.36)) % 7 == 0 else 0
    if kind == 'areia':
        return 1 if (int(longitude*12)%2 == 0 and int(y+12)%4 == 0) else 0
    if kind == 'raio':
        return 1 if (int(longitude*24 + (y+12)*.55) % 11 in (0,1)) else 0
    if kind in ('leopardo', 'sabertiger'):
        if kind == 'sabertiger' and -9 < y < -3 and (abs(longitude-.69) < .025 or abs(longitude-.81) < .025):
            return 1
        u = longitude * 13
        v = (y + 12) / 3.7
        row = math.floor(v)
        du = (u + .5 * (row % 2)) % 1 - .5
        dv = v % 1 - .5
        return 2 if du*du + dv*dv < .055 else 0
    if kind == 'fantasma':
        u = longitude * 6
        v = (y + 12) / 9
        du = u % 1 - .5
        dv = v % 1 - .5
        if -.28 < dv < -.06 and (.08 < abs(du) < .2): return 2
        return 0
    # Distribute spirals in rows around a periodic cylindrical map; the seam
    # between longitude 0 and 1 uses the same cells.
    u = longitude * (8 if kind == 'bagas' else 7)
    v = (y+12) / (5.0 if kind == 'bagas' else 6.0)
    row=math.floor(v); du=(u + 0.5*(row%2)) % 1 - .5; dv=v%1-.5
    r=math.hypot(du,dv)
    theta=math.atan2(dv,du)
    target=2.0*math.pi*r*(1.7 if kind=='chama' else 1.3)
    diff=abs((theta-target+math.pi)%(2*math.pi)-math.pi)
    return 1 if r < .43 and diff < .42 else (2 if r>.46 else 0)


def make(fid, forms):
    base,light,dark,stem,kind=FRUTAS[fid]
    colors=[rgba(base),rgba(light),rgba(dark)]
    filled=g['voxels'](forms[fid]); views=g['VISTAS']; vis={}
    for idx,role in filled.items():
        for view in views:
            n=view[0]; neighbor=tuple(idx[k]+n[k] for k in range(3))
            if neighbor in filled: continue
            t=g['texel'](view,idx); depth=g['dot'](idx,n)
            if t not in vis or depth>vis[t][0]: vis[t]=(depth,idx,role)
    image=Image.new('RGBA',(72,48),(0,0,0,0))
    for (x,y),(_,idx,role) in vis.items():
        if role in ('caule','folha'):
            color=rgba(stem)
        else:
            color=colors[pattern(idx,kind)]
        image.putpixel((x,y),color)
    guide=Image.open(ARTE/'guias'/f'{fid}_guia.png').convert('RGBA')
    mismatch=sum((a[3]>0)!=(b[3]>0) for a,b in zip(image.getdata(),guide.getdata()))
    if mismatch: raise ValueError(f'{fid}: {mismatch} pixels incompatíveis com o guia atual')
    image.save(OUT/f'{fid}.png')
    print(fid, len(vis), 'pixels; guia OK')


if __name__=='__main__':
    forms=json.loads((ARTE/'formas.json').read_text())['frutas']
    for fruit in FRUTAS: make(fruit,forms)
