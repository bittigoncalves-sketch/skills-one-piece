"""Rachadura no chao do Estilo de Combate Base (X): fendas irregulares saindo de um ponto central,
afinando nas pontas, com ramos laterais e lascas de piso levantadas. Plana (Blender XY = o chao;
glTF XZ), diametro ~1 m (o jogo escala pela `escala` do VFX). Duas malhas: `fenda` (o corte escuro)
e `lascas` (pedacinhos soltos).  Semente fixa: sai igual toda vez.

Uso: blender -b -P tools/blender/rachadura_chao.py
Saidas: art_src/blender/rachadura_chao.blend e assets/models/vento/rachadura.glb
"""
import bpy, bmesh, math, os, random
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(14102026)
fenda, lascas = bmesh.new(), bmesh.new()


def fita(bm, pts, w0, z=0.0):
    """Faixa ao longo da polilinha `pts`, largura w0 no inicio e 0 na ponta."""
    n = len(pts)
    lados = []
    for i, (x, y) in enumerate(pts):
        ax, ay = pts[min(i + 1, n - 1)]
        bx, by = pts[max(i - 1, 0)]
        dx, dy = ax - bx, ay - by
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        w = w0 * (1.0 - i / (n - 1)) ** 0.8 * rng.uniform(0.8, 1.2)
        lados.append((bm.verts.new((x + nx * w, y + ny * w, z)), bm.verts.new((x - nx * w, y - ny * w, z))))
    for (a1, a2), (b1, b2) in zip(lados, lados[1:]):
        bm.faces.new((a1, b1, b2, a2))


def caminho(x, y, ang, comp, passos, desvio):
    pts = [(x, y)]
    for _ in range(passos):
        ang += rng.uniform(-desvio, desvio)
        x += math.cos(ang) * comp / passos
        y += math.sin(ang) * comp / passos
        pts.append((x, y))
    return pts


N = 8
for k in range(N):
    ang = 2 * math.pi * k / N + rng.uniform(-0.18, 0.18)
    comp = rng.uniform(0.7, 1.0) if k % 2 == 0 else rng.uniform(0.45, 0.65)
    pts = caminho(0, 0, ang, comp, 12, 0.26)
    fita(fenda, pts, 0.045)
    # ramos laterais saindo do meio da fenda principal
    for j in (5, 9):
        if rng.random() < 0.7:
            sx, sy = pts[j]
            lado = rng.choice((-1, 1))
            fita(fenda, caminho(sx, sy, ang + lado * rng.uniform(0.5, 0.9), comp * 0.35, 6, 0.3), 0.022)
    # lascas de piso ao longo da fenda
    for j in range(4, 12, 3):
        px, py = pts[j]
        px += rng.uniform(-.05, .05); py += rng.uniform(-.05, .05)
        a = rng.uniform(0, math.pi)
        s = rng.uniform(0.012, 0.028)
        h = rng.uniform(0.008, 0.02)
        v = [lascas.verts.new((px + math.cos(a + q) * s * 1.4 + rng.uniform(-.01, .01),
                               py + math.sin(a + q) * s * 1.4 + rng.uniform(-.01, .01), 0.0))
             for q in (0, 2.1, 4.2)]
        t = [lascas.verts.new((x, y, h)) for (x, y) in [(px + (v[i].co.x - px) * 0.5, py + (v[i].co.y - py) * 0.5) for i in range(3)]]
        lascas.faces.new(v[::-1])
        for i in range(3):
            lascas.faces.new((v[i], v[(i + 1) % 3], t[(i + 1) % 3], t[i]))
        lascas.faces.new(t)

# centro: um polígono irregular onde o punho bateu
c = [fenda.verts.new((math.cos(a) * r, math.sin(a) * r, 0.0))
     for a, r in [(2 * math.pi * i / 10, 0.07 * rng.uniform(0.7, 1.3)) for i in range(10)]]
fenda.faces.new(c)

objs = []
for nome, bm in (("fenda", fenda), ("lascas", lascas)):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    m = bpy.data.meshes.new(nome)
    bm.to_mesh(m)
    bm.free()
    o = bpy.data.objects.new(nome, m)
    bpy.context.scene.collection.objects.link(o)
    objs.append(o)
print("RACHADURA dims:", [tuple(round(v, 3) for v in o.dimensions) for o in objs])
os.makedirs(os.path.join(RAIZ, "art_src/blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src/blender/rachadura_chao.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets/models/vento/rachadura.glb"),
                          export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True)
