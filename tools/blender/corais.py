"""Corais e vida de recife do mar do Modo Historia (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E2).

Direcao de arte (decisao do dono, 14/10): "One Piece vibrante" -- formas arredondadas e
bulbosas, leitura clara contra a areia. A COR nao mora aqui: o jogo escolhe a paleta por
instancia (src/historia/mar/coral.gdshader). Aqui a cor de vertice carrega MASCARAS:
  R = gradiente base -> ponta (0 -> 1)      G = oclusao ambiente (1 = aberto, raios)
  B = detalhe (polipos, sulcos, pintas)     A = peso do balanco (0 = rigido, 1 = solto)

Cada especie e um objeto com origem no CENTRO DA BASE (z = 0 no chao, +Z para cima no
Blender = +Y no glTF). Determinístico (semente fixa por especie).

Uso: blender -b -P tools/blender/corais.py
Saidas: art_src/blender/corais.blend e assets/models/mar/corais.glb
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)
AO_RAIOS = 10
AO_ALCANCE = 0.45


# ------------------------------------------------------------------ utilidades
def objeto(nome, malha):
    obj = bpy.data.objects.new(nome, malha)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def de_bmesh(nome, bm):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    return objeto(nome, me)


def aplicar(obj):
    """Congela os modificadores na malha (avaliada pelo depsgraph)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    velho = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(velho)


def triangulos(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def reduzir(obj, alvo):
    t = triangulos(obj)
    if t > alvo:
        m = obj.modifiers.new("Reduzir", "DECIMATE")
        m.ratio = alvo / t
        aplicar(obj)


def esqueleto(nome, pontos, arestas, raios, suavizar=0.5):
    """Galhos organicos: arestas + raio por ponto -> Skin + Subsurf."""
    me = bpy.data.meshes.new(nome)
    me.from_pydata(pontos, arestas, [])
    obj = objeto(nome, me)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = suavizar
    camada = me.skin_vertices[0].data
    for i, r in enumerate(raios):
        camada[i].radius = (r, r)
    camada[0].use_root = True
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    aplicar(obj)
    return obj


def galho(rng, pontos, arestas, raios, i0, rumo, comprimento, raio, nivel, passo=0.2,
          abrir=0.55, subir=0.18, afinar=0.4, filhos=2, chance=0.85, plano=None):
    """Cresce um galho a partir do ponto i0 e ramifica (recursivo)."""
    n = max(2, int(comprimento / passo))
    atual = i0
    pos = Vector(pontos[i0])
    r = raio
    for s in range(n):
        desvio = Vector((rng.uniform(-.22, .22), rng.uniform(-.22, .22), rng.uniform(-.05, subir)))
        if plano is not None:
            desvio.y = 0.0
        rumo = (rumo + desvio).normalized()
        if plano is not None:
            rumo.y = 0.0
            rumo.normalize()
        pos = pos + rumo * (comprimento / n)
        r = raio * (1.0 - afinar * (s + 1) / n)
        pontos.append(tuple(pos))
        raios.append(r)
        arestas.append((atual, len(pontos) - 1))
        atual = len(pontos) - 1
    if nivel > 0:
        for k in range(filhos):
            if rng.random() > chance:
                continue
            ang = abrir * (1 if k % 2 == 0 else -1) * rng.uniform(0.7, 1.2)
            if plano is not None:
                novo = Vector((rumo.x * math.cos(ang) - rumo.z * math.sin(ang), 0.0,
                               rumo.x * math.sin(ang) + rumo.z * math.cos(ang))).normalized()
            else:
                eixo = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.0)).normalized()
                novo = (rumo + eixo * math.tan(abs(ang))).normalized()
            galho(rng, pontos, arestas, raios, atual, novo, comprimento * 0.72, r * 0.95, nivel - 1,
                  passo, abrir, subir, afinar, filhos, chance, plano)


def mascaras(obj, gradiente, detalhe, balanco):
    """Grava R,G,B,A na cor de vertice. gradiente/detalhe/balanco: f(co, normal) -> 0..1."""
    me = obj.data
    me.calc_loop_triangles()
    arvore = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
    cor = me.color_attributes.new(name="Mascaras", type="FLOAT_COLOR", domain="POINT")
    dirs = []
    for k in range(AO_RAIOS):          # hemisferio fixo (Fibonacci), girado pela normal
        y = 1.0 - (k + 0.5) / AO_RAIOS
        rr = math.sqrt(max(0.0, 1.0 - y * y))
        a = k * 2.399963
        dirs.append(Vector((math.cos(a) * rr, math.sin(a) * rr, y)))
    for v in me.vertices:
        n = v.normal.normalized()
        livre = 0
        q = Vector((0, 0, 1)).rotation_difference(n)     # leva o hemisferio (+Z) para a normal
        for d in dirs:
            dd = q @ d
            hit = arvore.ray_cast(v.co + n * 0.01, dd, AO_ALCANCE)
            if hit[0] is None:
                livre += 1
        ao = livre / AO_RAIOS
        ao = max(0.0, min(1.0, ao * 1.15 - 0.05))
        if v.co.z < 0.05:
            ao *= 0.6 + 0.4 * (v.co.z / 0.05 if v.co.z > 0 else 0.0)
        cor.data[v.index].color = (gradiente(v.co, n), ao, detalhe(v.co, n), balanco(v.co, n))
    me.color_attributes.active_color = cor
    me.color_attributes.render_color_index = 0


def assentar(obj):
    """Origem no centro da base: menor z = 0, x/y centrados."""
    me = obj.data
    zs = [v.co.z for v in me.vertices]
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    d = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
    for v in me.vertices:
        v.co -= d


def altura(obj):
    return max(v.co.z for v in obj.data.vertices)


def suave(obj):
    for p in obj.data.polygons:
        p.use_smooth = True


# ------------------------------------------------------------------ especies
def coral_ramo():
    """Chifre-de-alce grosso: galhos curtos e roliços, pontas redondas."""
    rng = random.Random(11)
    pontos, arestas, raios = [(0, 0, 0)], [], [0.15]
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-.3, .3)
        rumo = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 1.0)).normalized()
        galho(rng, pontos, arestas, raios, 0, rumo, rng.uniform(0.45, 0.6), 0.13, 2,
              passo=0.12, abrir=0.6, subir=0.25, afinar=0.25)
    obj = esqueleto("coral_ramo", pontos, arestas, raios, 0.8)
    reduzir(obj, 1300)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, (c.z / h) ** 0.8),
             lambda c, n: 1.0 if noise.noise(c * 22.0) > 0.35 else 0.0,     # polipos
             lambda c, n: 0.0)
    return obj


def coral_cerebro():
    """Cerebro: cupula achatada com sulcos sinuosos."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=56, v_segments=28, radius=0.7)
    for v in list(bm.verts):
        if v.co.z < -0.02:
            bm.verts.remove(v)
    for v in bm.verts:
        p = v.co.copy()
        n = p.normalized()
        # sulcos: cristas do ruido entortado (|ruido| pequeno = vale)
        q = p * 3.2 + Vector((noise.noise(p * 1.7), noise.noise(p * 1.7 + Vector((5, 1, 2))), 0)) * 1.2
        sulco = 1.0 - min(1.0, abs(noise.noise(q)) * 4.0)
        v.co = Vector((p.x, p.y, p.z * 0.62)) + n * (-0.05 * sulco ** 2)
    # fecha a base
    borda = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=borda, sides=0)
    obj = de_bmesh("coral_cerebro", bm)
    reduzir(obj, 1500)
    assentar(obj)
    suave(obj)
    h = altura(obj)

    def sulco(c, n):
        p = Vector((c.x, c.y, c.z / 0.62))
        q = p * 3.2 + Vector((noise.noise(p * 1.7), noise.noise(p * 1.7 + Vector((5, 1, 2))), 0)) * 1.2
        return 1.0 - min(1.0, abs(noise.noise(q)) * 4.0)
    mascaras(obj, lambda c, n: min(1, c.z / h), sulco, lambda c, n: 0.0)
    return obj


def coral_leque():
    """Gorgonia (leque-do-mar): rede plana de galhos finos; balanca."""
    rng = random.Random(23)
    pontos, arestas, raios = [(0, 0, 0)], [], [0.08]
    galho(rng, pontos, arestas, raios, 0, Vector((0, 0, 1)), 0.35, 0.07, 0, passo=0.1, afinar=0.1)
    topo = len(pontos) - 1
    for k in range(5):
        a = -0.9 + k * 0.45
        rumo = Vector((math.sin(a), 0, math.cos(a)))
        galho(rng, pontos, arestas, raios, topo, rumo, 0.55, 0.05, 3, passo=0.09, abrir=0.42,
              subir=0.1, afinar=0.35, filhos=2, chance=0.9, plano=True)
    obj = esqueleto("coral_leque", pontos, arestas, raios, 0.4)
    reduzir(obj, 1600)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, c.z / h),
             lambda c, n: 1.0 if noise.noise(c * 30.0) > 0.3 else 0.0,
             lambda c, n: min(1, (c.z / h) ** 1.4))
    return obj


def coral_tubos():
    """Esponjas-tubo: canos abertos, boca alargada."""
    rng = random.Random(31)
    bm = bmesh.new()
    for k in range(6):
        a = k / 6 * math.tau + rng.uniform(-.4, .4)
        d = 0.0 if k == 0 else rng.uniform(0.16, 0.3)
        cx, cy = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(0.55, 1.15) * (1.15 if k == 0 else 1.0)
        r = rng.uniform(0.08, 0.13)
        aneis = []
        for j in range(7):
            t = j / 6
            rr = r * (1.0 + 0.45 * t ** 3) * (1.0 + 0.08 * math.sin(j * 1.7))
            lado = Vector((math.cos(a), math.sin(a), 0)) * 0.08 * t * t * (1 if k else 0)
            anel = [bm.verts.new((cx + lado.x + math.cos(u / 14 * math.tau) * rr,
                                  cy + lado.y + math.sin(u / 14 * math.tau) * rr, t * h)) for u in range(14)]
            aneis.append(anel)
        for a0, a1 in zip(aneis, aneis[1:]):
            for u in range(14):
                bm.faces.new((a0[u], a0[(u + 1) % 14], a1[(u + 1) % 14], a1[u]))
        bm.faces.new(list(reversed(aneis[0])))
    obj = de_bmesh("coral_tubos", bm)
    sol = obj.modifiers.new("Parede", "SOLIDIFY")
    sol.thickness = 0.035
    sol.offset = -1
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    aplicar(obj)
    reduzir(obj, 1100)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, c.z / h),
             lambda c, n: 1.0 if noise.noise(c * 18.0) > 0.4 else 0.0,
             lambda c, n: 0.0)
    return obj


def coral_mesa():
    """Coral-mesa: tronco curto e prato largo com borda recortada."""
    bm = bmesh.new()
    aneis = []
    raios = [0.12, 0.10, 0.12, 0.35, 0.65, 0.85, 0.95]
    alturas = [0.0, 0.35, 0.55, 0.62, 0.66, 0.66, 0.62]
    for j, (r, z) in enumerate(zip(raios, alturas)):
        anel = []
        for u in range(36):
            a = u / 36 * math.tau
            recorte = 1.0 + (0.07 * math.sin(a * 9) + 0.04 * math.sin(a * 4 + 1)) * (j / 6)
            anel.append(bm.verts.new((math.cos(a) * r * recorte, math.sin(a) * r * recorte, z)))
        aneis.append(anel)
    for a0, a1 in zip(aneis, aneis[1:]):
        for u in range(36):
            bm.faces.new((a0[u], a0[(u + 1) % 36], a1[(u + 1) % 36], a1[u]))
    bm.faces.new(list(reversed(aneis[0])))
    obj = de_bmesh("coral_mesa", bm)
    sol = obj.modifiers.new("Prato", "SOLIDIFY")
    sol.thickness = 0.07
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    aplicar(obj)
    reduzir(obj, 1100)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, (c.z / h) ** 2 * (0.4 + 0.6 * min(1, Vector((c.x, c.y)).length / 0.9))),
             lambda c, n: 1.0 if (noise.noise(c * 14.0) > 0.25 and n.z > 0.5) else 0.0,
             lambda c, n: 0.0)
    return obj


def anemona():
    """Anemona: pe curto e coroa de tentaculos ondulantes."""
    rng = random.Random(41)
    pontos, arestas, raios = [(0, 0, 0)], [], [0.16]
    pontos.append((0, 0, 0.14))
    raios.append(0.17)
    arestas.append((0, 1))
    for k in range(26):
        a = k / 26 * math.tau
        anel = 0.07 + 0.08 * (k % 2)
        pontos.append((math.cos(a) * anel, math.sin(a) * anel, 0.16))
        raios.append(0.035)
        arestas.append((1, len(pontos) - 1))
        base = len(pontos) - 1
        rumo = Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 1.0)).normalized()
        galho(rng, pontos, arestas, raios, base, rumo, rng.uniform(0.3, 0.42), 0.032, 0,
              passo=0.07, subir=0.05, afinar=0.7)
    obj = esqueleto("anemona", pontos, arestas, raios, 0.6)
    reduzir(obj, 1400)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, max(0, (c.z - 0.12) / (h - 0.12))) ** 0.7,
             lambda c, n: 1.0 if c.z > h * 0.82 else 0.0,                # pontas claras
             lambda c, n: min(1, max(0, (c.z - 0.14) / (h - 0.14)) ** 1.2))
    return obj


def alga():
    """Kelp: fitas altas torcendo devagar, com bolsas de ar; balanca muito."""
    rng = random.Random(53)
    bm = bmesh.new()
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-.5, .5)
        ox, oy = math.cos(a) * 0.14, math.sin(a) * 0.14
        h = rng.uniform(3.2, 4.6)
        segs = 28
        esq, dir_ = [], []
        for j in range(segs + 1):
            t = j / segs
            giro = a + t * rng.uniform(2.0, 3.2)
            larg = (0.08 + 0.24 * math.sin(min(1, t * 1.6) * math.pi * 0.5)) * (1 - t * 0.5)
            larg *= 1.0 + 0.18 * math.sin(j * 1.9)
            cx = ox + math.sin(t * 3.0 + k) * 0.12 * t
            cy = oy + math.cos(t * 2.3 + k) * 0.12 * t
            d = Vector((math.cos(giro), math.sin(giro), 0)) * larg
            esq.append(bm.verts.new((cx - d.x, cy - d.y, t * h)))
            dir_.append(bm.verts.new((cx + d.x, cy + d.y, t * h)))
        for j in range(segs):
            bm.faces.new((esq[j], dir_[j], dir_[j + 1], esq[j + 1]))
    obj = de_bmesh("alga", bm)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, c.z / h),
             lambda c, n: 1.0 if noise.noise(c * 9.0) > 0.45 else 0.0,
             lambda c, n: min(1, (c.z / h) ** 1.2))
    return obj


def coral_bolhas():
    """Coral-bolha: cacho de esferas lisas (o mais 'One Piece' da vitrine)."""
    rng = random.Random(61)
    bm = bmesh.new()
    for k in range(13):
        r = rng.uniform(0.09, 0.24)
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.32)
        z = r * 0.8 + rng.uniform(0.0, 0.35) * (1 - d / 0.4)
        m = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=7, radius=r)
        bmesh.ops.translate(bm, verts=m["verts"], vec=Vector((math.cos(a) * d, math.sin(a) * d, z)))
    obj = de_bmesh("coral_bolhas", bm)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, 0.35 + 0.65 * max(0.0, n.z)),          # topo de cada bolha claro
             lambda c, n: 1.0 if n.z > 0.85 else 0.0,
             lambda c, n: 0.0)
    return obj


def estrela():
    """Estrela-do-mar: cinco bracos achatados, deitada na areia."""
    bm = bmesh.new()
    centro = bm.verts.new((0, 0, 0.06))
    borda = []
    for u in range(40):
        a = u / 40 * math.tau
        braco = 0.5 + 0.5 * math.cos(a * 5)
        r = 0.07 + 0.11 * braco ** 1.6
        borda.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.012 + 0.02 * braco)))
    for u in range(40):
        bm.faces.new((centro, borda[u], borda[(u + 1) % 40]))
    obj = de_bmesh("estrela", bm)
    sol = obj.modifiers.new("Corpo", "SOLIDIFY")
    sol.thickness = 0.02
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    aplicar(obj)
    reduzir(obj, 320)
    assentar(obj)
    suave(obj)
    mascaras(obj, lambda c, n: 0.4 + 0.6 * min(1, Vector((c.x, c.y)).length / 0.18),
             lambda c, n: 1.0 if noise.noise(c * 60.0) > 0.4 else 0.0,
             lambda c, n: 0.0)
    return obj


def ourico():
    """Ourico: bola escura com espinhos longos."""
    rng = random.Random(71)
    bm = bmesh.new()
    m = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.11)
    bmesh.ops.translate(bm, verts=m["verts"], vec=Vector((0, 0, 0.09)))
    for k in range(46):
        y = 1.0 - (k + 0.5) / 46 * 1.6
        if y < -0.45:
            continue
        rr = math.sqrt(max(0.0, 1 - y * y))
        a = k * 2.399963
        d = Vector((math.cos(a) * rr, math.sin(a) * rr, y)).normalized()
        base = Vector((0, 0, 0.09)) + d * 0.1
        ponta = base + d * rng.uniform(0.14, 0.22)
        lado = d.orthogonal().normalized() * 0.012
        lado2 = d.cross(lado).normalized() * 0.012
        b = [bm.verts.new(base + lado), bm.verts.new(base + lado2), bm.verts.new(base - lado), bm.verts.new(base - lado2)]
        p = bm.verts.new(ponta)
        for i in range(4):
            bm.faces.new((b[i], b[(i + 1) % 4], p))
    obj = de_bmesh("ourico", bm)
    assentar(obj)
    suave(obj)
    h = altura(obj)
    mascaras(obj, lambda c, n: min(1, (Vector((c.x, c.y, c.z - 0.09)).length - 0.09) / 0.2),
             lambda c, n: 0.0, lambda c, n: 0.0)
    return obj


ESPECIES = [coral_ramo, coral_cerebro, coral_leque, coral_tubos, coral_mesa, anemona, alga,
            coral_bolhas, estrela, ourico]

objs = []
x = 0.0
for f in ESPECIES:
    o = f()
    o.location.x = x            # so na vitrine do .blend; o glTF usa a origem de cada no
    x += 2.2
    objs.append(o)
    print("CORAL %-14s triangulos=%5d altura=%.2f m" % (o.name, triangulos(o), altura(o)))

os.makedirs(os.path.join(RAIZ, "art_src", "blender"), exist_ok=True)
os.makedirs(os.path.join(RAIZ, "assets", "models", "mar"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src", "blender", "corais.blend"))
for o in objs:
    o.location.x = 0.0
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets", "models", "mar", "corais.glb"),
                          export_format="GLB", export_yup=True, export_animations=False,
                          export_vertex_color="ACTIVE", export_materials="NONE")
print("CORAIS_EXPORTADOS", len(objs))
