"""Prancha de surf da Magu Magu (X): prancha longa com bico pontudo, cauda arredondada,
curvatura (rocker) levantando as pontas, quilha central e duas quilhas laterais. Uma malha,
sem material (o shader de lava vai no jogo). Frente = -Z no glTF, base na origem (pés em y=0).

Uso: blender -b -P tools/blender/prancha_lava.py
Saidas: art_src/blender/prancha_lava.blend e assets/models/magu/prancha_lava.glb
"""
import bpy, bmesh, math, os

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)

COMP, LARG, ESP = 2.6, .7, .15  # comprimento, largura, espessura (m)

bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=40, radius=1)
b = bpy.context.active_object
b.name = "prancha_lava"
me = b.data
for v in me.vertices:
    y = v.co.y                       # -1..1 ao longo da prancha
    # Bico (y>0) afunilado e pontudo; cauda (y<0) mais cheia e arredondada.
    largura = LARG / 2 * ((1.0 - .5 * y * y) if y > 0 else (1.0 - .15 * y * y))
    if y > 0: largura *= (1.0 - y) ** .35 + .08
    x = v.co.x * largura
    # Convés quase plano, fundo arredondado.
    z = v.co.z * ESP / 2 * (1.0 if v.co.z > 0 else .8)
    # Rocker: pontas sobem, mais no bico.
    z += (.16 if y > 0 else .07) * y * y
    v.co = (x, y * COMP / 2, z)
bpy.ops.object.shade_smooth()

def peca(nome, verts, faces):
    m = bpy.data.meshes.new(nome)
    m.from_pydata(verts, [], faces)
    m.update()
    o = bpy.data.objects.new(nome, m)
    bpy.context.collection.objects.link(o)
    return o

# Quilhas: lâmina triangular com espessura, penduradas sob a cauda.
def quilha(x, y0, comprimento, altura, esp, inclina=0.0):
    zb = -ESP * .35 + .07 * y0 * y0 / (COMP / 2) ** 2 * 0   # sob o fundo
    p = [(x - esp, y0, zb), (x + esp, y0, zb),
         (x - esp * .4, y0 - comprimento, zb), (x + esp * .4, y0 - comprimento, zb),
         (x - esp * .2, y0 - comprimento * .55, zb - altura), (x + esp * .2, y0 - comprimento * .55, zb - altura)]
    f = [(0, 1, 5, 4), (2, 4, 5, 3), (0, 4, 2), (1, 3, 5), (0, 2, 3, 1)]
    return peca("quilha", p, f)

quilha(0, -.15, .5, .17, .02)
quilha(.2, -.55, .4, .13, .016)
quilha(-.2, -.55, .4, .13, .016)
# Filete central no convés (stringer): uma crista fina para dar leitura de prancha.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, .05, ESP / 2 + .004))
s = bpy.context.active_object
s.scale = (.025, COMP * .78, .012)

for o in bpy.context.scene.objects: o.select_set(False)
for o in bpy.context.scene.objects:
    if o.type == 'MESH': o.select_set(True)
bpy.context.view_layer.objects.active = b
bpy.ops.object.join()
b = bpy.context.active_object
# Assenta: a base da prancha (sem quilhas) em y=0 do glTF -> o mínimo em Z do corpo.
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
corpo_min = -ESP * .8 / 2
for v in b.data.vertices: v.co.z -= corpo_min
print("PRANCHA dim:", tuple(round(d, 3) for d in b.dimensions))

os.makedirs(os.path.join(RAIZ, "art_src/blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src/blender/prancha_lava.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets/models/magu/prancha_lava.glb"),
                          export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True)
