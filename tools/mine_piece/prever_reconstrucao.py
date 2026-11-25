#!/usr/bin/env python3
"""Pré-visualização rápida (sem Godot/Blender) da reconstrução: lê art_src/reconstrucao/<id>.geo.json + a textura
(final do Codex ou provisória) e desenha 3 vistas (frente, 3/4, costas) para `art_src/reconstrucao/<id>_previa.png`.
Pintor de faces com mapeamento de UV por pixel (amostra a textura, como o jogo)."""
import json, math, os, sys
from PIL import Image, ImageDraw
RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARTE = os.path.join(RAIZ, "art_src/reconstrucao")

def faces_cubo(o, s, uv):
    u, v = uv; sx, sy, sz = (int(a) for a in s)
    x0, y0, z0 = -(o[0] + s[0]), o[1], o[2]; x1, y1, z1 = -o[0], o[1] + s[1], o[2] + s[2]   # x espelhado (Bedrock→jogo)
    R = {"N": [u+sz, v+sz, u+sz+sx, v+sz+sy], "S": [u+2*sz+sx, v+sz, u+2*sz+2*sx, v+sz+sy], "E": [u, v+sz, u+sz, v+sz+sy],
         "W": [u+sz+sx, v+sz, u+2*sz+sx, v+sz+sy], "U": [u+sz, v, u+sz+sx, v+sz], "D": [u+sz+sx, v+sz, u+sz+2*sx, v]}
    C = {"N": [(x1,y1,z0),(x0,y1,z0),(x0,y0,z0),(x1,y0,z0)], "S": [(x0,y1,z1),(x1,y1,z1),(x1,y0,z1),(x0,y0,z1)],
         "E": [(x1,y1,z1),(x1,y1,z0),(x1,y0,z0),(x1,y0,z1)], "W": [(x0,y1,z0),(x0,y1,z1),(x0,y0,z1),(x0,y0,z0)],
         "U": [(x1,y1,z1),(x0,y1,z1),(x0,y1,z0),(x1,y1,z0)], "D": [(x1,y0,z0),(x0,y0,z0),(x0,y0,z1),(x1,y0,z1)]}
    return [(C[k], R[k]) for k in "NSEWUD"]

def vista(geo, tex, yaw, pitch=22, esc=9):
    ca, sa, cp, sp = math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    def proj(p):
        x, y, z = p; x, z = x*ca - z*sa, x*sa + z*ca
        return (x, y*cp + z*sp, z*cp - y*sp)         # (sx, sy, profundidade)
    polis = []
    for osso in geo["bones"]:
        for c in osso.get("cubes", []):
            for cantos, r in faces_cubo(c["origin"], c["size"], c["uv"]):
                pj = [proj(q) for q in cantos]
                # descarta faces de costas (normal virada para longe)
                ax, ay = pj[1][0]-pj[0][0], pj[1][1]-pj[0][1]; bx, by = pj[2][0]-pj[1][0], pj[2][1]-pj[1][1]
                if ax*by - ay*bx < 0: continue
                polis.append((sum(p[2] for p in pj)/4, pj, r))
    polis.sort(key=lambda t: -t[0])
    xs = [p[0] for _, pj, _ in polis for p in pj]; ys = [p[1] for _, pj, _ in polis for p in pj]
    W, H = int((max(xs)-min(xs))*esc)+24, int((max(ys)-min(ys))*esc)+24
    im = Image.new("RGBA", (W, H), (60, 70, 85, 255)); px = im.load()
    for _, pj, (u0, v0, u1, v1) in polis:
        P = [(12+(p[0]-min(xs))*esc, H-12-(p[1]-min(ys))*esc) for p in pj]
        minx, maxx = int(min(p[0] for p in P)), int(max(p[0] for p in P))+1; miny, maxy = int(min(p[1] for p in P)), int(max(p[1] for p in P))+1
        A, B, D = P[0], P[1], P[3]   # A=sup-esq, B=sup-dir, D=inf-esq
        ex, ey, fx, fy = B[0]-A[0], B[1]-A[1], D[0]-A[0], D[1]-A[1]; det = ex*fy - ey*fx
        if abs(det) < 1e-6: continue
        for y in range(max(miny, 0), min(maxy, H)):
            for x in range(max(minx, 0), min(maxx, W)):
                dx, dy = x+0.5-A[0], y+0.5-A[1]
                a = (dx*fy - dy*fx)/det; b = (ex*dy - ey*dx)/det
                if 0 <= a < 1 and 0 <= b < 1:
                    tx = int(u0 + a*(u1-u0)); ty = int(v0 + b*(v1-v0))
                    if 0 <= tx < tex.width and 0 <= ty < tex.height:
                        c = tex.getpixel((tx, ty))
                        if c[3] > 25: px[x, y] = c
    return im

def main():
    for mid in (sys.argv[1:] or ["pirate", "chouchou", "suzume"]):
        geo = json.load(open(f"{ARTE}/{mid}.geo.json"))["minecraft:geometry"][0]
        final = f"{ARTE}/_final_{mid}.png"
        tex = Image.open(final if os.path.exists(final) else f"{ARTE}/{mid}_provisoria.png").convert("RGBA")
        vs = [vista(geo, tex, y) for y in (0, 35, 180)]
        H = max(v.height for v in vs); out = Image.new("RGBA", (sum(v.width for v in vs), H), (60, 70, 85, 255)); x = 0
        for v in vs: out.paste(v, (x, H-v.height)); x += v.width
        out.save(f"{ARTE}/{mid}_previa.png"); print("OK", mid, out.size)
main()
