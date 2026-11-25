"""Pata da Nikyu Nikyu no Mi: pata de gato 'de pelúcia' com a almofada grande e quatro
dedinhos redondos, voltada para -Z no glTF (a almofada é a face que bate). Largura total = 1 m
(o jogo escala por 2 x raio do projétil). Duas malhas: `pelagem` (o corpo da pata) e
`almofadas` (palma + dedos), para o jogo pintar cada uma de uma cor.

Uso: blender -b -P tools/blender/pata_nikyu.py
Saidas: art_src/blender/pata_nikyu.blend e assets/models/nikyu/pata.glb
"""
import bpy, os
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)

def esfera(nome, loc, esc):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1, location=loc)
    o = bpy.context.active_object
    o.name = nome
    o.scale = esc
    return o

def juntar(nome, objs):
    for o in bpy.context.scene.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = nome
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    return o

# Blender: +Y = frente (a face da almofada), +Z = cima. Em y=0 fica a frente do corpo da pata.
corpo = [esfera("c0", (0, -.16, 0), (.46, .22, .44)),             # massa da pata
         esfera("c1", (0, -.30, -.05), (.36, .26, .36))]          # punho/braço atrás
pelagem = juntar("pelagem", corpo)

palma = [esfera("p0", (0, .10, -.08), (.27, .12, .20)),           # almofada grande
         esfera("p1", (-.15, .10, -.15), (.17, .11, .14)),
         esfera("p2", (.15, .10, -.15), (.17, .11, .14))]
dedos = []
for i, (x, z) in enumerate([(-.38, .10), (-.14, .33), (.14, .33), (.38, .10)]):
    dedos.append(esfera(f"d{i}", (x, .09, z), (.115, .10, .14)))   # dedinhos redondos
almofadas = juntar("almofadas", palma + dedos)

print("PATA dims:", tuple(round(v, 3) for v in pelagem.dimensions), tuple(round(v, 3) for v in almofadas.dimensions))
os.makedirs(os.path.join(RAIZ, "art_src/blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src/blender/pata_nikyu.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets/models/nikyu/pata.glb"),
                          export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True)
