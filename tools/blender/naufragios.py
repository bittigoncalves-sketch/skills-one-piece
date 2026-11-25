"""Naufragios do mar do Modo Historia (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3).

Tres cascos afundados, feitos de TABUAS (faixas com espessura, cada uma com a sua cor),
costelas expostas, convés com buracos, mastros quebrados, vela rasgada, barris e canhoes:
  naufragio_galeao   ~20 m, partido em dois (popa assentada, proa tombada ao lado)
  naufragio_chalupa  ~10 m, deitada de lado, rombo no casco
  naufragio_bote     ~5 m, emborcado
Cor de vertice = COR FINAL (madeira, metal, lona). O jogo poe alga/cracas por cima
(src/historia/mar/naufragio.gdshader). Origem = centro da base (quilha no z = 0), proa
para +X no Blender (glTF/Godot: +X), para o jogo girar a peca no mapa.
Marcadores (empties exportados como nos): `ponto_bau`, `ponto_esqueleto_N` (E4).

Uso: blender -b -P tools/blender/naufragios.py
Saidas: art_src/blender/naufragios.blend e art_src/mar/naufragio_<tipo>.glb
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)


def lin(hexa):
    h = hexa.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)


MADEIRA = [lin("#6b4a2b"), lin("#5c3f24"), lin("#7a5634"), lin("#664527"), lin("#53381f")]
MADEIRA_ESCURA = lin("#3a2716")
METAL = lin("#3a3e42")
LONA = lin("#cfc3a1")
ARGOLA = lin("#5b5145")


class Construtor:
    """Junta faces com cor por face (cor de vertice por canto, sem misturar tabuas)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.cor = self.bm.loops.layers.float_color.new("Cor")

    def face(self, pts, cor):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        for l in f.loops:
            l[self.cor] = cor
        return f

    def solido(self, p, cor):
        """8 cantos (0-3 embaixo, 4-7 em cima, mesma ordem) -> bloco FECHADO com vertices
        compartilhados: o recalc_face_normals so orienta regiao conectada."""
        vs = [self.bm.verts.new(q) for q in p]
        for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            face = self.bm.faces.new([vs[i] for i in f])
            for l in face.loops:
                l[self.cor] = cor

    def caixa(self, centro, eixo_x, eixo_y, eixo_z, cor):
        """Paralelepipedo: centro + meios-eixos (vetores)."""
        c = Vector(centro)
        x, y, z = Vector(eixo_x), Vector(eixo_y), Vector(eixo_z)
        self.solido([c - x - y - z, c + x - y - z, c + x + y - z, c - x + y - z,
                     c - x - y + z, c + x - y + z, c + x + y + z, c - x + y + z], cor)

    def placa(self, a, b, c, d, espessura, normal, cor):
        """Quad com espessura."""
        n = Vector(normal).normalized() * espessura * 0.5
        q = [Vector(a), Vector(b), Vector(c), Vector(d)]
        self.solido([v - n for v in q] + [v + n for v in q], cor)

    def cilindro(self, base, topo, raio, lados, cor, recorte=0.0, rng=None, tampa=True):
        base, topo = Vector(base), Vector(topo)
        eixo = (topo - base).normalized()
        u = eixo.orthogonal().normalized()
        v = eixo.cross(u).normalized()
        anel_b, anel_t = [], []
        for k in range(lados):
            a = k / lados * math.tau
            off = (u * math.cos(a) + v * math.sin(a)) * raio
            anel_b.append(self.bm.verts.new(base + off))
            jit = eixo * (rng.uniform(-recorte, recorte) if rng and recorte else 0.0)
            anel_t.append(self.bm.verts.new(topo + off + jit))
        for k in range(lados):
            j = (k + 1) % lados
            f = self.bm.faces.new((anel_b[k], anel_b[j], anel_t[j], anel_t[k]))
            for l in f.loops:
                l[self.cor] = cor
        if tampa:
            for anel, rev in ((anel_b, True), (anel_t, False)):
                f = self.bm.faces.new(list(reversed(anel)) if rev else anel)
                for l in f.loops:
                    l[self.cor] = cor

    def objeto(self, nome):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        me = bpy.data.meshes.new(nome)
        self.bm.to_mesh(me)
        self.bm.free()
        obj = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(obj)
        # cor por canto -> atributo de cor exportado (COLOR_0)
        me.color_attributes.active_color = me.color_attributes["Cor"]
        me.materials.append(material_madeira())
        return obj


def material_madeira():
    """So para o editor de mapa mostrar a madeira (o jogo troca pelo naufragio.gdshader)."""
    m = bpy.data.materials.get("madeira_naufragio")
    if m:
        return m
    m = bpy.data.materials.new("madeira_naufragio")
    m.use_nodes = True
    nos = m.node_tree.nodes
    bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
    attr = nos.new("ShaderNodeVertexColor")
    attr.layer_name = "Cor"
    m.node_tree.links.new(attr.outputs[0], bsdf.inputs[0])
    bsdf.inputs["Roughness"].default_value = 1.0
    return m


class Casco:
    """Forma do casco: meia-largura, fundo e borda por posicao u (0 = popa, 1 = proa)."""

    def __init__(self, comprimento, largura, pontal, tosado, espelho):
        self.L, self.W, self.D, self.tosado, self.espelho = comprimento, largura, pontal, tosado, espelho

    def meia_largura(self, u):
        if u >= 0.5:
            s = 1.0 - ((u - 0.5) / 0.5) ** 2.2
        else:
            s = 1.0 - ((0.5 - u) / 0.5) ** 3.0 * (1.0 - self.espelho)
        return self.W * 0.5 * max(s, 0.0)

    def fundo(self, u):
        s = self.meia_largura(u) / (self.W * 0.5)
        return -self.D * (0.55 + 0.45 * math.sqrt(max(s, 0.0)))

    def borda(self, u):
        return self.tosado * (2.0 * u - 1.0) ** 2

    def ponto(self, u, v, lado):
        """v: 0 = quilha, 1 = borda. lado: -1 bombordo, +1 estibordo."""
        a = v * math.pi * 0.5
        w = self.meia_largura(u)
        y = lado * w * math.sin(a) ** 0.55
        z = self.fundo(u) * math.cos(a) + self.borda(u) * (1.0 - math.cos(a))
        x = (u - 0.5) * self.L
        return Vector((x, y, z))


def tabuado(cons, casco, u0, u1, rng, tabuas=9, falha=0.0, lascas=0.0, rombo=None, lados=(-1, 1)):
    """Costado em tabuas. falha: chance de tirar um pedaco; lascas: ponta irregular na
    quebra (fracao de u); rombo: (u_centro, v_centro, raio) sem tabuas."""
    for lado in lados:
        for t in range(tabuas):
            va, vb = t / tabuas, (t + 1) / tabuas - 0.012
            cor = MADEIRA[(t + (0 if lado > 0 else 2)) % len(MADEIRA)]
            ua = u0 + (rng.uniform(0, lascas) if lascas and u0 > 0.02 else 0.0)
            ub = u1 - (rng.uniform(0, lascas) if lascas and u1 < 0.98 else 0.0)
            passos = max(2, int((ub - ua) * casco.L / 0.7))
            for s in range(passos):
                sa = ua + (ub - ua) * s / passos
                sb = ua + (ub - ua) * (s + 1) / passos
                um = (sa + sb) * 0.5
                vm = (va + vb) * 0.5
                if falha and rng.random() < falha * (0.4 + vm):
                    continue
                if rombo and ((um - rombo[0]) * casco.L) ** 2 + ((vm - rombo[1]) * 4.0) ** 2 < rombo[2] ** 2:
                    continue
                p = [casco.ponto(sa, va, lado), casco.ponto(sb, va, lado), casco.ponto(sb, vb, lado), casco.ponto(sa, vb, lado)]
                normal = (p[1] - p[0]).cross(p[3] - p[0]) * lado
                cons.placa(p[0], p[1], p[2], p[3], 0.09, normal, cor)


def costelas(cons, casco, us, rng, quebradas=0.0):
    """Cavernas: vigas curvas por dentro do costado, da quilha a borda."""
    for u in us:
        for lado in (-1, 1):
            topo = 1.0 if rng.random() > quebradas else rng.uniform(0.45, 0.8)
            pontos = [casco.ponto(u, v / 8 * topo, lado) for v in range(9)]
            for a, b in zip(pontos, pontos[1:]):
                dentro = Vector((0, -lado * 0.12, 0.08))
                meio = (a + b) * 0.5 + dentro
                eixo = (b - a) * 0.5
                cons.caixa(meio, eixo, Vector((0.07, 0, 0)), eixo.cross(Vector((1, 0, 0))).normalized() * 0.08, MADEIRA_ESCURA)
    # quilha
    for i in range(len(us) - 1):
        pass


def conves(cons, casco, u0, u1, altura, rng, buracos=0.15):
    """Convés em tabuas no sentido do comprimento, com buracos."""
    n = 9
    for t in range(n):
        f = (t + 0.5) / n * 2.0 - 1.0
        cor = MADEIRA[t % len(MADEIRA)]
        passos = max(2, int((u1 - u0) * casco.L / 1.1))
        for s in range(passos):
            sa = u0 + (u1 - u0) * s / passos
            sb = u0 + (u1 - u0) * (s + 1) / passos
            if rng.random() < buracos:
                continue
            wa = casco.meia_largura(sa) * 0.92
            wb = casco.meia_largura(sb) * 0.92
            if wa < 0.3 or wb < 0.3:
                continue
            ya0, ya1 = f * wa - wa / n, f * wa + wa / n * 0.85
            yb0, yb1 = f * wb - wb / n, f * wb + wb / n * 0.85
            za = altura(sa)
            zb = altura(sb)
            xa, xb = (sa - 0.5) * casco.L, (sb - 0.5) * casco.L
            cons.placa((xa, ya0, za), (xb, yb0, zb), (xb, yb1, zb), (xa, ya1, za), 0.07, (0, 0, 1), cor)


def barril(cons, centro, raio, altura, deitado, rng):
    c = Vector(centro)
    eixo = Vector((0, 0, altura * 0.5)) if not deitado else Vector((altura * 0.5, 0, 0)).to_3d()
    if deitado:
        eixo = Matrix.Rotation(rng.uniform(0, math.tau), 3, "Z") @ Vector((altura * 0.5, 0, 0))
    cons.cilindro(c - eixo, c + eixo, raio, 12, MADEIRA[rng.randrange(len(MADEIRA))])
    for f in (-0.6, 0.6):
        meio = c + eixo * f
        cons.cilindro(meio - eixo * 0.06, meio + eixo * 0.06, raio * 1.04, 12, ARGOLA)


def canhao(cons, base, rumo, rng):
    base = Vector(base)
    rumo = Vector(rumo).normalized()
    cons.cilindro(base, base + rumo * 1.7, 0.2, 10, METAL)
    cons.cilindro(base - rumo * 0.15, base, 0.24, 10, METAL)
    cons.cilindro(base + rumo * 1.6, base + rumo * 1.75, 0.24, 10, METAL)


def vela_rasgada(cons, origem, largura, altura, rumo_l, rumo_a, rng):
    """Pano UNICO (vertices compartilhados), ondulado, com rasgos que crescem para a ponta."""
    o = Vector(origem)
    nl, na = 10, 8
    normal = rumo_l.cross(rumo_a).normalized()
    grade = [[cons.bm.verts.new(o + rumo_l * largura * (i / nl) + rumo_a * altura * (j / na)
                                + normal * (0.18 * math.sin(i * 0.9 + j * 0.5) * (j / na)))
              for j in range(na + 1)] for i in range(nl + 1)]
    for i in range(nl):
        for j in range(na):
            if rng.random() < 0.08 + 0.32 * (j / na) ** 1.5:
                continue
            f = cons.bm.faces.new((grade[i][j], grade[i + 1][j], grade[i + 1][j + 1], grade[i][j + 1]))
            for l in f.loops:
                l[cons.cor] = LONA
    for linha in grade:
        for v in linha:
            if not v.link_faces:
                cons.bm.verts.remove(v)


def marcador(nome, pos, pai):
    e = bpy.data.objects.new(nome, None)
    e.empty_display_size = 0.4
    e.location = pos
    bpy.context.scene.collection.objects.link(e)
    e.parent = pai
    return e


def assentar(obj, enterrar):
    """Origem no centro da base: menor z sobe para -enterrar (o jogo põe o z=0 no fundo)."""
    me = obj.data
    zs = [v.co.z for v in me.vertices]
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    d = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs) + enterrar))
    for v in me.vertices:
        v.co -= d
    return d


# ------------------------------------------------------------------ galeao
def galeao():
    rng = random.Random(101)
    cons = Construtor()
    casco = Casco(20.0, 6.0, 3.6, 1.4, 0.65)
    # popa (u 0..0.47): inteira, levemente inclinada depois
    tabuado(cons, casco, 0.0, 0.47, rng, falha=0.06, lascas=0.05)
    costelas(cons, casco, [0.08 + k * 0.06 for k in range(7)] + [0.45, 0.48, 0.51], rng, quebradas=0.5)
    alt = lambda u: casco.borda(u) - 0.45
    conves(cons, casco, 0.03, 0.44, alt, rng, buracos=0.22)
    # castelo de popa: caixa de tabuas sobre a popa
    for k in range(5):
        x = (0.04 + k * 0.035 - 0.5) * casco.L
        cons.placa((x, -2.2, 1.0), (x + 0.65, -2.2, 1.0), (x + 0.65, -2.2, 2.6), (x, -2.2, 2.6), 0.09, (0, -1, 0), MADEIRA[k % 5])
        if k != 2:
            cons.placa((x + 0.65, 2.2, 1.0), (x, 2.2, 1.0), (x, 2.2, 2.6), (x + 0.65, 2.2, 2.6), 0.09, (0, 1, 0), MADEIRA[(k + 2) % 5])
    # mastro principal quebrado na popa
    cons.cilindro((-1.5, 0, alt(0.42)), (-1.5, 0, alt(0.42) + 3.2), 0.32, 12, MADEIRA_ESCURA, recorte=0.5, rng=rng)
    popa = cons.objeto("popa")

    cons = Construtor()
    tabuado(cons, casco, 0.53, 1.0, rng, falha=0.08, lascas=0.05)
    costelas(cons, casco, [0.52, 0.55, 0.58] + [0.62 + k * 0.07 for k in range(5)], rng, quebradas=0.6)
    conves(cons, casco, 0.56, 0.93, alt, rng, buracos=0.3)
    # gurupés quebrado
    cons.cilindro(casco.ponto(1.0, 1.0, 1) + Vector((-0.4, 0, -0.3)), casco.ponto(1.0, 1.0, 1) + Vector((2.6, 0, 1.1)), 0.16, 8, MADEIRA_ESCURA, recorte=0.3, rng=rng)
    proa = cons.objeto("proa")
    # proa tombada: gira 28° sobre o eixo do comprimento, afasta e torce
    proa.data.transform(Matrix.Translation((2.4, 1.6, -0.3)) @ Matrix.Rotation(math.radians(-9), 4, "Z") @ Matrix.Rotation(math.radians(28), 4, "X"))
    popa.data.transform(Matrix.Rotation(math.radians(-6), 4, "X") @ Matrix.Rotation(math.radians(3), 4, "Y"))

    cons = Construtor()
    # mastro caido na areia, com verga e vela rasgada
    base = Vector((-1.0, -4.2, 0.2))
    rumo = Vector((0.95, -0.3, 0.0)).normalized()
    cons.cilindro(base, base + rumo * 13.0, 0.27, 12, MADEIRA_ESCURA, recorte=0.4, rng=rng)
    verga = base + rumo * 8.5
    lado = Vector((-rumo.y, rumo.x, 0))
    cons.cilindro(verga - lado * 3.4 + Vector((0, 0, 0.1)), verga + lado * 3.4 + Vector((0, 0, 0.1)), 0.13, 8, MADEIRA_ESCURA)
    vela_rasgada(cons, verga - lado * 3.2 + Vector((0, 0, 0.05)), 6.4, 3.0, lado, -rumo, rng)
    for k in range(4):
        barril(cons, (rng.uniform(-6, 4), rng.uniform(-5.5, -3.2) if k % 2 else rng.uniform(3.6, 5.5), 0.35), 0.4, 1.0, True, rng)
    canhao(cons, (3.5, -3.6, 0.2), (0.4, -1, 0.05), rng)
    canhao(cons, (-4.5, 3.8, 0.25), (-0.6, 1, 0.1), rng)
    resto = cons.objeto("destrocos")

    juntar = [popa, proa, resto]
    obj = unir(juntar, "naufragio_galeao")
    d = assentar(obj, 0.9)
    # marcadores (no espaço já assentado): baú no convés da popa; esqueletos
    pontos = {"ponto_bau": Vector((-5.2, 0.4, alt(0.22) - 0.25)), "ponto_esqueleto_1": Vector((-3.4, -0.8, alt(0.3) - 0.3)),
              "ponto_esqueleto_2": Vector((3.0, 1.2, 0.6)), "ponto_esqueleto_3": Vector((-0.5, -3.6, 0.15))}
    for nome, p in pontos.items():
        marcador(nome, p - d, obj)
    return obj


def unir(objs, nome):
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs):
        bpy.ops.object.join()
    o = objs[0]
    o.name = nome
    o.data.name = nome
    return o


# ------------------------------------------------------------------ chalupa
def chalupa():
    rng = random.Random(202)
    cons = Construtor()
    casco = Casco(10.0, 3.2, 1.9, 0.6, 0.45)
    tabuado(cons, casco, 0.0, 1.0, rng, tabuas=7, falha=0.04, rombo=(0.58, 0.45, 1.4))
    costelas(cons, casco, [0.1 + k * 0.1 for k in range(9)], rng, quebradas=0.3)
    alt = lambda u: casco.borda(u) - 0.25
    conves(cons, casco, 0.06, 0.9, alt, rng, buracos=0.2)
    cons.cilindro((0.6, 0, alt(0.55)), (0.6, 0, alt(0.55) + 4.5), 0.18, 10, MADEIRA_ESCURA, recorte=0.4, rng=rng)
    vela_rasgada(cons, Vector((0.7, 0, alt(0.55) + 0.8)), 3.4, 3.2, Vector((-1, 0, 0)), Vector((0, 0, 1)), rng)
    barril(cons, (-2.5, 0.3, alt(0.25) + 0.45), 0.35, 0.9, False, rng)
    corpo = cons.objeto("chalupa")
    # deitada de lado: 72° sobre o comprimento
    corpo.data.transform(Matrix.Rotation(math.radians(72), 4, "X"))
    cons = Construtor()
    barril(cons, (2.0, -3.3, 0.3), 0.35, 0.9, True, rng)
    barril(cons, (-3.0, -2.8, 0.3), 0.35, 0.9, True, rng)
    canhao(cons, (3.6, 2.0, 0.2), (1, 0.4, 0.05), rng)
    resto = cons.objeto("destrocos_chalupa")
    obj = unir([corpo, resto], "naufragio_chalupa")
    d = assentar(obj, 0.6)
    pontos = {"ponto_bau": Vector((-1.6, -1.6, 0.2)), "ponto_esqueleto_1": Vector((1.2, -1.4, 0.4)),
              "ponto_esqueleto_2": Vector((-3.4, -2.4, 0.1))}
    for nome, p in pontos.items():
        marcador(nome, p - Vector((0, 0, d.z)) - Vector((d.x, d.y, 0)), obj)
    return obj


# ------------------------------------------------------------------ bote
def bote():
    rng = random.Random(303)
    cons = Construtor()
    casco = Casco(5.0, 1.8, 0.8, 0.3, 0.55)
    tabuado(cons, casco, 0.0, 1.0, rng, tabuas=5, falha=0.05)
    costelas(cons, casco, [0.15 + k * 0.14 for k in range(6)], rng)
    for u in (0.3, 0.55, 0.78):
        x = (u - 0.5) * casco.L
        w = casco.meia_largura(u) * 0.95
        cons.placa((x - 0.15, -w, -0.25), (x + 0.15, -w, -0.25), (x + 0.15, w, -0.25), (x - 0.15, w, -0.25), 0.06, (0, 0, 1), MADEIRA[2])
    corpo = cons.objeto("bote")
    # emborcado: 180° sobre o comprimento, um pouco de banda
    corpo.data.transform(Matrix.Rotation(math.radians(172), 4, "X"))
    cons = Construtor()
    cons.caixa((1.6, 1.4, 0.05), (1.3, 0, 0), (0, 0.08, 0), (0, 0, 0.04), MADEIRA[1])   # remo
    cons.caixa((2.95, 1.4, 0.05), (0.25, 0, 0), (0, 0.13, 0), (0, 0, 0.02), MADEIRA[1])
    resto = cons.objeto("destrocos_bote")
    obj = unir([corpo, resto], "naufragio_bote")
    d = assentar(obj, 0.35)
    pontos = {"ponto_bau": Vector((-0.6, 1.7, 0.0)), "ponto_esqueleto_1": Vector((0.8, -1.5, 0.05))}
    for nome, p in pontos.items():
        marcador(nome, p - Vector((0, 0, d.z)) - Vector((d.x, d.y, 0)), obj)
    return obj


modelos = [galeao(), chalupa(), bote()]
os.makedirs(os.path.join(RAIZ, "art_src", "blender"), exist_ok=True)
os.makedirs(os.path.join(RAIZ, "art_src", "mar"), exist_ok=True)
x = 0.0
for m in modelos:
    m.location.x = x
    x += 26.0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src", "blender", "naufragios.blend"))
for m in modelos:
    m.location.x = 0.0
    tri = sum(len(p.vertices) - 2 for p in m.data.polygons)
    dims = m.dimensions
    print("NAUFRAGIO %-18s triangulos=%6d medidas=%.1f x %.1f x %.1f m marcadores=%s" % (
        m.name, tri, dims.x, dims.y, dims.z, [c.name for c in m.children]))
    bpy.ops.object.select_all(action="DESELECT")
    m.select_set(True)
    for c in m.children:
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "art_src", "mar", m.name + ".glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_animations=False,
                              export_vertex_color="ACTIVE", export_materials="EXPORT")
print("NAUFRAGIOS_EXPORTADOS", len(modelos))
