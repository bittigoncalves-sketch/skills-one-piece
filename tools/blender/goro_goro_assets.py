"""Author original Goro Goro no Mi fruit. Blender 5+, no external assets.
Run: blender -b --python tools/blender/goro_goro_assets.py
Godot fruit Y-up. All geometry / materials editable here.

DIRECAO DE ARTE — identidade TROVAO, acabamento padrao Ope (~/.claude/NIVEL_OPE.md).
A Ope e a regua de QUALIDADE, nao de estetica: la e um coracao carmesim com
espirais curvas; aqui a mesma exigencia de autoria produz outra coisa.

A regra de ouro da paleta da Goro (docs/frutas/goro_goro.md) e o CONTRASTE:
escuro embaixo, amarelo-branco em cima. A fruta obedece a mesma regra do golpe —
casca ambar sobre sulcos azul-petroleo profundos, e as espirais assinatura das
Akuma no Mi desenhadas em ZIGUE-ZAGUE (o traco do raio) em amarelo-branco
emissivo, nao em curva suave. E o unico lugar do modelo que brilha.

Silhueta: bulbo de tambor (os tambores de Enel), gomos verticais marcados,
peduculo enrolado em espiral apertada.
"""
import bpy, math, os
from mathutils import Vector
from math import sin, cos, pi, exp, atan2

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets/models/goro_goro')
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, metal=0, rough=.5, emit=None, emit_power=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emit is not None:
        p.inputs['Emission Color'].default_value = (*emit, 1)
        p.inputs['Emission Strength'].default_value = emit_power
    return m


# Casca ambar madura. A espiral e RELEVO, como na Ope: mesma familia de cor, um
# tom acima — quem le a forma e a luz na aresta, nao uma cor gritante. A primeira
# versao usou branco emissivo forte e as espirais viraram adesivo colado na fruta.
# A arvore da Goro declara `fruit_color` = Ouro Raio (TreeAndFruitGenerator).
#
# ⚠️ RAZAO VERDE/VERMELHO — o erro que custou uma rodada de captura.
# A primeira versao usava linear (.58,.34,.020), que em sRGB da (.79,.62,.15):
# o verde e 79% do vermelho. No render do Blender isso passa por ouro, mas sob a
# luz AZULADA do ceu da arena a fruta lia como VERDE-OLIVA. Medido lado a lado
# com a Ope, que aparece vermelha viva no mesmo quadro.
# Ouro que sobrevive aquela luz quer o verde perto de 72% do vermelho e o azul
# quase zero. Conferir sempre NO JOGO, nunca so no preview do Blender.
# Medido na arena (amostra de pixel, nao no olho): a luz da cena EMPURRA a razao
# verde/vermelho em cerca de +0,15. Material com G/R 0,74 em sRGB chegava na tela
# com 0,88-0,95 — amarelo puro, oliva na sombra. Para a fruta ler como OURO o
# material precisa sair daqui mais alaranjado do que parece certo no Blender.
# Referencia da medicao: a Ope no mesmo quadro da G/R 0,21.
rind = material('Goro | ripe gold rind', (.90, .225, .018), 0, .40)
# Sulco: UM tom abaixo da casca, mesma familia quente.
groove = material('Goro | shaded gomo', (.36, .078, .008), 0, .52)
# Carga contida: emissao baixa sugere a eletricidade sem apagar o relevo.
bolt = material('Goro | embossed bolt', (.99, .60, .155), 0, .34, (1.0, .70, .24), .70)
stem = material('Goro | scorched stem', (.26, .17, .050), 0, .62)
leaf_mat = material('Goro | storm leaf', (.10, .22, .085), 0, .58)
vein_mat = material('Goro | charged vein', (.62, .66, .22), 0, .5)


def mesh(name, verts, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = smooth
    return ob


def tube(name, points, radius, mat, res=3):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = radius
    c.bevel_resolution = res
    c.use_fill_caps = True
    s = c.splines.new('POLY')
    s.points.add(len(points) - 1)
    for p, co in zip(s.points, points):
        p.co = (*co, 1)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


# ---------------------------------------------------------------- corpo
# Bulbo de tambor: mais largo na base que no topo, com 12 gomos verticais.
# `a` vai de -pi/2 (base) a +pi/2 (topo); `b` roda em volta.
GOMOS = 12


def body(a, b, offset=0.0):
    z0 = sin(a)
    # Perfil de SUPERELIPSE (expoente 2.7): corpo cheio de tambor, base arredondada.
    # O perfil linear anterior (.385 + .085*z0 - .115*z0^2) afunilava a base e a
    # fruta saia como uma gota apontada para baixo.
    cheio = max(1.0 - abs(z0) ** 2.7, 0.0) ** (1.0 / 2.7)
    raio = .395 * cheio * (1.0 - .17 * max(z0, 0) ** 2.2)
    # Gomos: sulco senoidal em torno do eixo, fundo nos vales.
    # max(): nos polos cos(a) chega a -1e-17, e negativo elevado a .6 vira complexo.
    gomo = 1.0 - .052 * (1.0 - cos(GOMOS * b)) * max(cos(a), 0.0) ** .6
    x = cos(a) * cos(b) * raio * gomo
    y = cos(a) * sin(b) * raio * gomo
    # Achata a base e afunda o topo onde o peduculo nasce.
    z = .445 * z0 - .085 * exp(-(max(z0, 0) / .38) ** 2) * max(z0, 0) ** 2 \
        - .030 * exp(-((z0 + 1) / .22) ** 2)
    v = Vector((x, y, z))
    if offset:
        n = Vector((x / .385, y / .385, z / .445)).normalized()
        v = v + n * offset
    return v


N, M = 120, 76
verts = [body(-pi / 2 + pi * i / M, 2 * pi * j / N) for i in range(M + 1) for j in range(N)]
faces = [(i * N + j, i * N + (j + 1) % N, (i + 1) * N + (j + 1) % N, (i + 1) * N + j)
         for i in range(M) for j in range(N)]
mesh('Goro_Bulb', verts, faces, rind)

# Sulcos dos gomos: tubos escuros afundados no vale de cada gomo.
for g in range(GOMOS):
    b = 2 * pi * g / GOMOS + pi / GOMOS
    pts = []
    for i in range(44):
        t = i / 43
        a = -pi / 2 + pi * t * .94 - .04
        pts.append(body(a, b, -.007))
    tube('Gomo_groove_%02d' % g, pts, .0115, groove, 2)

# ---------------------------------------------------------------- espirais
# A assinatura da Akuma no Mi. Na Ope sao voltas suaves; aqui cada volta e um
# ZIGUE-ZAGUE de 5 pernas — o traco do raio. Elas envolvem a superficie real.
centers = [(-.62, -2.55, .30), (-.60, -1.28, .31), (-.58, .02, .29), (-.60, 1.30, .31), (-.58, 2.58, .30),
           (-.02, -2.95, .34), (.00, -1.72, .33), (-.02, -.48, .34), (.00, .76, .33), (-.02, 2.00, .34),
           (.02, 3.05, .33),
           (.58, -2.42, .30), (.60, -1.14, .31), (.58, .14, .30), (.60, 1.42, .31), (.58, 2.70, .30)]
VOLTAS = 2.0
PERNAS_POR_VOLTA = 6                 # 6 pernas por volta: angular, ainda legivel
QUINAS = int(VOLTAS * PERNAS_POR_VOLTA) + 1
for k, (a0, b0, span) in enumerate(centers):
    pts = []
    # Um ponto POR QUINA, raio crescendo de forma MONOTONA. A versao anterior
    # alternava o raio +-19% a cada quina e, com poucas quinas, a espiral virava
    # um poligono fechado tipo estrela — perdia a leitura de espiral.
    # O carater de raio vem das pernas retas entre quinas, nao de serrilhar o raio.
    for j in range(QUINAS):
        t = j / (QUINAS - 1)
        ang = 2 * pi * VOLTAS * t + k * .52
        r = span * (.07 + .93 * t)
        pts.append(body(a0 + sin(ang) * r, b0 + cos(ang) * r * 1.24, .009))
    tube('Bolt_Spiral_%02d' % k, pts, .0092, bolt, 2)

# ---------------------------------------------------------------- peduculo
# Espiral apertada, queimada na ponta — a fruta foi colhida de uma arvore atingida.
pts = []
for j in range(120):
    t = j / 119
    if t < .40:
        q = t / .40
        x = 3 * (1 - q) * q * q * (-.055) + q * q * q * .012
        z = (1 - q) ** 3 * .30 + 3 * (1 - q) ** 2 * q * .38 + 3 * (1 - q) * q * q * .49 + q ** 3 * .49
        p = (x, .010 * sin(q * pi), z)
    else:
        q = (t - .40) / .60
        a = -pi / 2 + q * pi * 1.72
        r = .096 * (1 - .62 * q)
        p = (.012 + r * cos(a), .002 + .017 * sin(q * pi), .588 + r * sin(a))
    pts.append(p)
tube('Curled_Stem', pts, .021, stem, 3)


def leaf(name, origin, axis, length, width):
    o = Vector(origin)
    ax = Vector(axis).normalized()
    side = Vector((-ax.y, ax.x, 0)).normalized()
    vv, ff, vein_pts = [], [], []
    for i in range(25):
        t = i / 24
        mid = o + ax * length * t + Vector((0, 0, .075 * sin(pi * t) - .026 * t * t))
        vein_pts.append(mid)
        for j in range(9):
            s = j / 4 - 1
            p = mid + side * (width * max(sin(pi * t), 0.0) ** .8 * s) + Vector((0, 0, -.030 * s * s * sin(pi * t)))
            vv.append(p)
    for i in range(24):
        for j in range(8):
            ff.append((i * 9 + j, i * 9 + j + 1, (i + 1) * 9 + j + 1, (i + 1) * 9 + j))
    ob = mesh(name, vv, ff, leaf_mat)
    sol = ob.modifiers.new('Living leaf thickness', 'SOLIDIFY')
    sol.thickness = .006
    tube(name + '_midrib', vein_pts, .004, vein_mat, 2)


leaf('Crown_Leaf_Left', (-.004, 0, .352), (-1, .12, .22), .31, .096)
leaf('Crown_Leaf_Right', (.010, .013, .354), (1, .16, .30), .27, .082)


def export_selected(path, objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # Converte curvas e aplica modificadores antes de juntar: orcamento de desenho estavel.
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = os.path.basename(path).replace('.glb', '')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_materials='EXPORT', export_yup=True)
    return ob


fruit = export_selected(os.path.join(OUT, 'goro_goro_fruit.glb'), list(bpy.context.scene.objects))

# ------------------------------------------------- preview renderizavel
# Cena de revisao da fonte, separada do asset de runtime.
#
# ⚠️ ESTE PREVIEW SERVE PARA CONFERIR GEOMETRIA, NAO COR. Como a paleta foi
# compensada para a luz azulada da arena (ver o bloco de materiais), aqui a
# fruta sai mais salmao do que aparece no jogo. A cor que vale e a medida em
# `multimodal/cache/goro-validation/captures/`, gerada por `./jogar_goro.sh -- --capture`.
world = bpy.context.scene.world or bpy.data.worlds.new('Studio')
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.020, .026, .038, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = .30
for name, loc, power, size in [('Key', (-3, -4, 5), 520, 4), ('Fill', (3, -2, 2), 230, 3), ('Rim', (1, 3, 4), 760, 2)]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, .1)) - o.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(1.25, -2.4, 1.00))
cam = bpy.context.object
cam.rotation_euler = (Vector((0, 0, .10)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.28
bpy.context.scene.camera = cam
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = os.path.join(OUT, 'fruit_preview.png')
bpy.ops.render.render(write_still=True)

# Medidas impressas: a entrega declara numero, nao adjetivo.
bb = [Vector(c) for c in fruit.bound_box]
dim = fruit.dimensions
print('GORO_ASSETS_READY', [(fruit.name, len(fruit.data.polygons))],
      'dim_xyz=(%.3f, %.3f, %.3f)' % (dim.x, dim.y, dim.z),
      'materials=%d' % len(fruit.data.materials))
