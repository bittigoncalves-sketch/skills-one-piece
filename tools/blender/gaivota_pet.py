"""Gaivota low poly — pet do Modo História (30/09/2026). Fonte autoral reproduzível.

    blender --background --python tools/blender/gaivota_pet.py

Coordenadas de AUTORIA iguais às do Godot: X lateral (+X = direita da ave), Y vertical,
frente -Z. A conversão para o Blender acontece só na gravação (`v`); o GLB volta Y-up.

Low poly de verdade (pedido do dono): faces chapadas, poucos lados, cor por material.
Cada articulação é um VAZIO nomeado — o jogo gira o vazio e a malha filha acompanha:

    Gaivota (raiz, pés no chão)
      Corpo            tronco (inclina, rola na curva)
        Cabeca         cabeça, bico, olhos (olha em volta, bica)
        Cauda          leque da cauda (abre no pouso)
        Asa_E / Asa_D  asa interna (bate, dobra no chão)
          Ponta_E / Ponta_D   asa externa com a ponta preta (dobra sobre a interna)
        Perna_E / Perna_D     perna e pé (recolhe no voo)

Medidas: ~0,62 m do bico à cauda, ~1,30 m de envergadura, ~0,42 m em pé.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for bloco in (bpy.data.meshes, bpy.data.materials):
    for item in list(bloco):
        bloco.remove(item)


def v(p):
    """Godot (x, y, z) → Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def material(nome, cor, rugosidade=.6):
    m = bpy.data.materials.new(nome)
    m.diffuse_color = (*cor, 1)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (*cor, 1)
    bs.inputs['Roughness'].default_value = rugosidade
    return m


BRANCO = material('Penas brancas', (.90, .90, .87), .7)
CINZA = material('Manto cinza', (.50, .56, .62), .65)
PRETO = material('Pontas pretas', (.045, .045, .05), .55)
AMARELO = material('Bico amarelo', (.93, .72, .14), .4)
VERMELHO = material('Mancha do bico', (.80, .13, .08), .4)
ROSA = material('Pernas', (.86, .56, .42), .55)
OLHO = material('Olho', (.02, .02, .025), .15)


def vazio(nome, pai, onde):
    o = bpy.data.objects.new(nome, None)
    bpy.context.collection.objects.link(o)
    o.empty_display_size = .05
    if pai is not None:
        o.parent = pai
    o.location = v(onde)
    return o


def malha(nome, verts, faces, mats, pai, mat_por_face=None):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([v(p) for p in verts], [], faces)
    # Normais para FORA em toda peça fechada: a asa esquerda é o contorno da direita
    # espelhado (ordem invertida), e sem isto ela sairia escura no sol.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    for m in mats:
        me.materials.append(m)
    if mat_por_face:
        for f, i in zip(me.polygons, mat_por_face):
            f.material_index = i
    for f in me.polygons:
        f.use_smooth = False      # low poly: faces chapadas
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.parent = pai
    return o


def loft(anneis, lados):
    """Anéis ao longo de Z: (cx, cy, cz, rx, ry). Raio 0 vira ponta (um vértice)."""
    verts, faces, indices = [], [], []
    for cx, cy, cz, rx, ry in anneis:
        if rx == 0 and ry == 0:
            indices.append([len(verts)])
            verts.append((cx, cy, cz))
            continue
        anel = []
        for k in range(lados):
            a = math.tau * k / lados + math.pi / lados
            anel.append(len(verts))
            verts.append((cx + rx * math.cos(a), cy + ry * math.sin(a), cz))
        indices.append(anel)
    for a, b in zip(indices, indices[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for k in range(lados):
                faces.append((a[0], b[(k + 1) % lados], b[k]))
        elif len(b) == 1:
            for k in range(lados):
                faces.append((a[k], a[(k + 1) % lados], b[0]))
        else:
            for k in range(lados):
                faces.append((a[k], a[(k + 1) % lados], b[(k + 1) % lados], b[k]))
    return verts, faces


def placa(contorno_xz, y, espessura, afina=0.0):
    """Prisma chato a partir de um contorno (x, z) convexo; `afina` baixa a espessura na
    borda externa (|x| maior), como uma asa."""
    n = len(contorno_xz)
    xs = [abs(p[0]) for p in contorno_xz]
    xmax = max(xs) or 1.0
    verts = []
    for x, z in contorno_xz:
        e = espessura * (1.0 - afina * abs(x) / xmax)
        verts.append((x, y + e * .5, z))
    for x, z in contorno_xz:
        e = espessura * (1.0 - afina * abs(x) / xmax)
        verts.append((x, y - e * .5, z))
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for k in range(n):
        j = (k + 1) % n
        faces.append((k, n + k, n + j, j))
    return verts, faces


def caixa(c, t):
    x, y, z = c
    a, b, d = t[0] * .5, t[1] * .5, t[2] * .5
    verts = [(x - a, y - b, z - d), (x + a, y - b, z - d), (x + a, y + b, z - d), (x - a, y + b, z - d),
             (x - a, y - b, z + d), (x + a, y - b, z + d), (x + a, y + b, z + d), (x - a, y + b, z + d)]
    faces = [(0, 1, 2, 3), (5, 4, 7, 6), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7), (4, 5, 1, 0)]
    return verts, faces


# ------------------------------------------------------------------ esqueleto
raiz = vazio('Gaivota', None, (0, 0, 0))
corpo = vazio('Corpo', raiz, (0, .27, 0))

# Tronco: fuso achatado de 7 lados, peito na frente, afinando para a cauda. Dorso cinza
# (as faces de cima), resto branco — a leitura clássica da gaivota vista do chão e do alto.
vs, fs = loft([(0, .01, -.19, 0, 0), (0, .02, -.15, .065, .06), (0, .025, -.07, .10, .092),
               (0, .02, .03, .105, .09), (0, .02, .12, .075, .065), (0, .03, .20, .035, .03),
               (0, .035, .24, 0, 0)], 7)
tronco = malha('Tronco', vs, fs, [BRANCO, CINZA], corpo)
for f in tronco.data.polygons:
    f.material_index = 1 if f.normal.z > .55 else 0   # Blender Z = altura

cabeca = vazio('Cabeca', corpo, (0, .075, -.16))
# O pescoço começa DENTRO do peito: sem ele a cabeça parecia solta (prévia de cima).
vs, fs = loft([(0, -.01, .06, 0, 0), (0, 0, .045, .05, .055), (0, .02, -.01, .048, .05),
               (0, .038, -.035, .05, .05), (0, .045, -.075, .06, .058),
               (0, .045, -.115, .05, .05), (0, .04, -.145, .03, .028), (0, .038, -.155, 0, 0)], 6)
malha('CabecaMalha', vs, fs, [BRANCO], cabeca)
# Bico: cunha de 4 lados, um pouco curvado para baixo na ponta.
vs, fs = loft([(0, .035, -.145, .016, .014), (0, .03, -.19, .011, .01), (0, .02, -.225, 0, 0)], 4)
malha('Bico', vs, fs, [AMARELO], cabeca)
vs, fs = caixa((0, .022, -.195), (.02, .01, .016))
malha('ManchaDoBico', vs, fs, [VERMELHO], cabeca)
for lado in (-1, 1):
    vs, fs = caixa((lado * .047, .058, -.1), (.012, .014, .014))
    malha('Olho_' + ('E' if lado < 0 else 'D'), vs, fs, [OLHO], cabeca)

cauda = vazio('Cauda', corpo, (0, .035, .2))
vs, fs = placa([(0, 0), (.055, .02), (.06, .13), (.02, .15), (-.02, .15), (-.06, .13), (-.055, .02)], 0, .014)
malha('CaudaMalha', vs, fs, [BRANCO], cauda)   # cauda branca, como na gaivota-comum

for lado, letra in ((-1, 'E'), (1, 'D')):
    # Asa interna: raiz larga no ombro, bordo de ataque reto, bordo de fuga recuado.
    asa = vazio('Asa_' + letra, corpo, (lado * .075, .07, -.05))
    vs, fs = placa([(0, -.055), (lado * .31, -.04), (lado * .31, .1), (0, .14)], 0, .03, afina=.4)
    malha('AsaInterna_' + letra, vs, fs, [CINZA], asa)
    # Asa externa: cinza até 0,2 m e a PONTA PRETA como peça própria (a face de cima é
    # um polígono só — cor por face não separava a ponta; prévia de 30/09).
    ponta = vazio('Ponta_' + letra, asa, (lado * .31, 0, 0))
    vs, fs = placa([(0, -.04), (lado * .2, -.03), (lado * .2, .085), (0, .1)], 0, .02, afina=.3)
    malha('AsaExterna_' + letra, vs, fs, [CINZA], ponta)
    vs, fs = placa([(lado * .2, -.03), (lado * .34, 0), (lado * .37, .03), (lado * .2, .085)], 0, .014)
    malha('PontaPreta_' + letra, vs, fs, [PRETO], ponta)
    # Perna: canela fina e pé palmado em triângulo.
    perna = vazio('Perna_' + letra, corpo, (lado * .045, -.05, .03))
    vs, fs = caixa((0, -.1, 0), (.016, .2, .016))
    malha('Canela_' + letra, vs, fs, [ROSA], perna)
    vs, fs = placa([(0, .01), (.035, -.055), (-.035, -.055)], -.205, .01)
    malha('Pe_' + letra, vs, fs, [ROSA], perna)

# ------------------------------------------------------------------ gravação
tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == 'MESH' for p in o.data.polygons)
print('GAIVOTA triangulos=%d' % tris)
destino = ROOT / 'assets/models/pets/gaivota.glb'
destino.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(destino), export_format='GLB', export_yup=True,
                          export_animations=False, export_extras=True)
fonte = ROOT / 'art_src/pets/gaivota.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(fonte))
print('GAIVOTA gravada em', destino)
