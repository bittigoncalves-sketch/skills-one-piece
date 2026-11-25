"""Centro de treino voxel. Execute: blender -b --python tools/blender/centro_treino_voxel.py.

Modelo separado da primeira versão. X largura, Y frente e Z acima no Blender;
o exportador glTF converte para Y acima. Origem no chão, no centro do pavilhão.
"""
import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/models/centro_treino/centro_treino_voxel.glb")
SOURCE = os.path.join(ROOT, "art_src/blender/centro_treino/centro_treino_voxel.blend")
PREVIEW = os.path.join(ROOT, "art_src/validation/centro_treino/centro_treino_voxel.png")

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

colors = {
    'pedra': (0.41, 0.43, 0.40, 1), 'pedra_clara': (0.56, 0.57, 0.52, 1),
    'terra': (0.57, 0.42, 0.26, 1), 'terra_clara': (0.64, 0.49, 0.31, 1),
    'madeira': (0.47, 0.27, 0.12, 1), 'madeira_clara': (0.64, 0.40, 0.19, 1),
    'madeira_escura': (0.25, 0.14, 0.07, 1), 'telha': (0.58, 0.17, 0.10, 1),
    'telha_clara': (0.72, 0.25, 0.14, 1), 'palha': (0.88, 0.70, 0.35, 1),
    'corda': (0.77, 0.62, 0.38, 1), 'ferro': (0.21, 0.22, 0.21, 1),
    'lona': (0.88, 0.79, 0.58, 1), 'alvo': (0.71, 0.12, 0.09, 1),
    'luz': (1.0, 0.69, 0.25, 1),
}
verts, faces, indices = [], [], []
names = list(colors)

def box(center, size, color):
    x, y, z = center
    a, b, c = (v / 2 for v in size)
    start = len(verts)
    verts.extend([(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
                  (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)])
    for f in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)):
        faces.append(tuple(start+i for i in f))
        indices.append(names.index(color))

# Fundação em blocos e piso: espaço coberto aberto para treinamento.
box((0, 0, .15), (10.4, 6.4, .30), 'pedra')
for i in range(26):
    x = -4.875 + i*.39
    box((x, 0, .34), (.375, 6.0, .08), 'madeira_clara' if i%4 else 'madeira')
for x in (-4.65, -1.55, 1.55, 4.65):
    for y in (-2.70, 2.70):
        box((x, y, .42), (.48, .48, .24), 'pedra_clara')
        box((x, y, 1.95), (.34, .34, 3.0), 'madeira')
        box((x, y, 1.15), (.39, .39, .12), 'corda')
        box((x, y, 3.37), (.5, .5, .18), 'madeira_escura')
for y in (-2.7, 2.7):
    box((0, y, 3.48), (10.25, .34, .26), 'madeira_escura')
for x in (-4.65, -1.55, 1.55, 4.65):
    box((x, 0, 3.55), (.24, 6.2, .18), 'madeira_escura')
# Telhado em degraus com beirais: silhueta nitidamente voxel.
for side in (-1, 1):
    for row in range(8):
        y = side * (0.22 + row*.45)
        z = 4.60 - row*.145
        box((0, y, z), (10.9, .48, .20), 'telha' if row%3 else 'telha_clara')
        for x in (-5.25, 5.25):
            box((x, y, z+.11), (.32, .43, .06), 'madeira_escura')
box((0, 0, 4.74), (11.1, .40, .18), 'madeira_escura')
for x in (-4.25, 4.25):
    box((x, -2.70, .97), (.22, .20, 1.0), 'madeira_escura')
box((0, -2.7, 1.35), (9.6, .18, .18), 'madeira_escura')
# Fundo e faixas de tecido: deixam o interior visível.
for x in (-3.1, 0, 3.1):
    box((x, -2.69, 2.65), (2.65, .09, 1.05), 'lona')
    box((x, -2.62, 3.02), (2.65, .06, .13), 'alvo')
for x in (-3.1, 3.1):
    box((x, 2.68, 3.14), (.10, .1, .42), 'ferro')
    box((x, 2.68, 2.86), (.32, .32, .34), 'luz')
    box((x, 2.68, 3.05), (.39, .39, .08), 'madeira_escura')

# Pátio ao nível do terreno: borda, áreas de terra e entrada livre.
box((0, 6.25, .06), (10.4, 6.1, .12), 'terra')
for x in (-4, -2, 0, 2, 4):
    for y in (4.0, 5.8, 7.6, 8.9):
        box((x + (.18 if int(y*10)%2 else 0), y, .125), (.60, .42, .012), 'terra_clara')
for side in (-1, 1):
    box((side*5.08, 6.15, .18), (.25, 6.2, .36), 'pedra_clara')
    for y in (3.4, 5.2, 7.0, 8.8):
        box((side*4.72, y, .65), (.25, .25, 1.3), 'madeira')
        box((side*4.72, y, 1.23), (.32, .32, .12), 'madeira_escura')
    for z in (.52, .90):
        box((side*4.72, 6.1, z), (.08, 5.5, .08), 'corda')
for x in (-3.6, 3.6):
    box((x, 9.15, .18), (2.6, .25, .36), 'pedra_clara')
for i in range(2):
    box((0, 3.28+i*.30, .08+i*.08), (2.7, .34, .16), 'madeira')
# Adereços laterais mantêm o centro do pátio livre para o boneco separado.
for x, y in ((-3.9,4.3),(-3.9,5.2),(3.9,4.3)):
    box((x,y,.37), (.55,.55,.74), 'madeira')
    for z in (.12,.60): box((x,y,z), (.61,.61,.08), 'ferro')
    box((x,y,.76), (.48,.48,.04), 'madeira_clara')
for x in (-4.3, 4.3):
    box((x, -.8, .62), (.35,1.3,.45), 'madeira_escura')
    box((x, -.8, .88), (.50,1.5,.10), 'madeira_clara')

mesh = bpy.data.meshes.new('CentroTreinoVoxelMalha')
mesh.from_pydata(verts, [], faces)
mesh.update()
obj = bpy.data.objects.new('CentroTreinoVoxel', mesh)
bpy.context.collection.objects.link(obj)
for name, color in colors.items():
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = color
    shader.inputs['Roughness'].default_value = .88
    mesh.materials.append(mat)
for poly, idx in zip(mesh.polygons, indices): poly.material_index = idx

os.makedirs(os.path.dirname(OUT), exist_ok=True)
os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True)

world = bpy.context.scene.world
world.color = (.28, .28, .28)
sun = bpy.data.lights.new('Sol', 'SUN')
sun.energy = 3
light = bpy.data.objects.new('Sol', sun)
bpy.context.collection.objects.link(light)
light.rotation_euler = (math.radians(28), math.radians(-25), math.radians(-30))
camdata = bpy.data.cameras.new('CameraPrevia')
cam = bpy.data.objects.new('CameraPrevia', camdata)
bpy.context.collection.objects.link(cam)
cam.location = (16, 23, 16)
cam.rotation_euler = (Vector((0, 2.7, 1.2)) - cam.location).to_track_quat('-Z','Y').to_euler()
camdata.type = 'ORTHO'
camdata.ortho_scale = 22
scene = bpy.context.scene
scene.camera = cam
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 1200
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = PREVIEW
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
bpy.ops.render.render(write_still=True)
print('CENTRO_VOXEL:', OUT, SOURCE, PREVIEW, 'vertices', len(verts), 'faces', len(faces))
