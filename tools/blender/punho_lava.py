"""Punho da Magu Magu (Z): um punho fechado de verdade -- palma, quatro dedos dobrados com
nós saltados, polegar cruzado na frente e punho/pulso afunilado. Uma malha só, sem material
(o shader de lava é aplicado no jogo). Frente do soco = -Z no glTF.

Uso: blender -b -P tools/blender/punho_lava.py
Saidas: art_src/blender/punho_lava.blend (fonte) e assets/models/magu/punho_lava.glb
"""
import bpy, math, os
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)
partes = []

def esfera(nome, loc, esc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = nome
    o.scale = esc
    partes.append(o)
    return o

def capsula(nome, a, b, raio):
    """Cápsula entre os pontos a e b (cilindro + esferas nas pontas via esferas alongadas)."""
    a, b = Vector(a), Vector(b)
    meio, d = (a + b) / 2, b - a
    comp = d.length
    o = esfera(nome, meio, (raio, raio, comp / 2 + raio * .6))
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return o

# Blender: +Y é a frente do soco, +Z para cima, +X para a direita (palma para -X no polegar).
# Costas da mão / palma
esfera("palma", (0, -.1, 0), (.62, .62, .52))
# Quatro dedos: nó (junta proximal) no alto e frente, falange média descendo pela frente.
xs = [-.40, -.135, .135, .40]
raios = [.19, .21, .21, .18]
for i, (x, r) in enumerate(zip(xs, raios)):
    no = (x, .42, .22)
    capsula(f"proximal{i}", (x, .05, .30), no, r * .95)
    esfera(f"no{i}", no, (r * 1.08, r * 1.0, r * 1.0))      # nó saltado
    capsula(f"media{i}", no, (x, .62, -.12), r * .95)         # dobra para baixo
    capsula(f"ponta{i}", (x, .62, -.12), (x, .30, -.40), r * .85)  # ponta recolhida na palma
# Polegar cruzado na frente dos dedos (de fora, atrás, para dentro, na frente).
capsula("polegar_base", (.55, -.15, -.05), (.50, .30, -.22), .20)
capsula("polegar_ponta", (.50, .30, -.22), (.05, .70, -.28), .17)
esfera("polegar_unha", (.05, .72, -.28), (.17, .15, .15))
# Pulso: afunila para trás, terminando num toco que o shader/escala escondem no braço.
capsula("pulso", (0, -.35, .03), (0, -1.05, .03), .36)
esfera("manga", (0, -1.05, .03), (.34, .16, .34))

for o in bpy.context.scene.objects: o.select_set(False)
for o in partes: o.select_set(True)
bpy.context.view_layer.objects.active = partes[0]
bpy.ops.object.join()
fist = bpy.context.active_object
fist.name = "punho_lava"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Funde as primitivas numa pele só, mantendo os vincos entre os dedos.
fist.data.remesh_voxel_size = .028
fist.data.remesh_voxel_adaptivity = 0
bpy.ops.object.voxel_remesh()

# Rugosidade de rocha/lava: deslocamento fino por ruído.
tex = bpy.data.textures.new("rocha", 'CLOUDS')
tex.noise_scale = .22
tex.noise_depth = 2
d = fist.modifiers.new("rocha", 'DISPLACE')
d.texture = tex
d.strength = .045
d.mid_level = .5
bpy.ops.object.modifier_apply(modifier="rocha")
bpy.ops.object.shade_smooth()

# Centra no punho fechado (sem o pulso): origem no centro da palma.
fist.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CENTER_OF_VOLUME')
fist.location.y += .2   # puxa o centro de massa para a palma, o pulso fica atrás
bpy.ops.object.transform_apply(location=True)
print("PUNHO dimensoes:", tuple(round(v, 3) for v in fist.dimensions), "verts:", len(fist.data.vertices))

os.makedirs(os.path.join(RAIZ, "art_src/blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src/blender/punho_lava.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets/models/magu/punho_lava.glb"),
                          export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True)
