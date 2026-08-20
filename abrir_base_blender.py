"""Abre o personagem base rigado no Blender e enquadra na viewport.

Uso:
    blender -P abrir_base_blender.py

Passe --unrigged na linha de comando para abrir o base.glb cru em vez do rigado.
"""
import bpy
import sys

RIGADO   = "/home/administrador/dev/skills-one-piece/assets/models/base_rigged.glb"
CRU      = "/home/administrador/dev/skills-one-piece/assets/models/base.glb"

caminho = CRU if "--unrigged" in sys.argv else RIGADO

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

print("Importando", caminho)
# disable_bone_shape=True evita que o importador crie a "Icosphere" e a use como
# custom shape dos ossos — no rig do Mixamo ela vira uma bola cinza gigante que
# engole o personagem inteiro na viewport.
bpy.ops.import_scene.gltf(filepath=caminho, disable_bone_shape=True)

# Rede de seguranca: se alguma versao do addon criar a bola assim mesmo, tira ela.
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere"):
        print("removendo bola parasita:", o.name)
        bpy.data.objects.remove(o, do_unlink=True)
for a in bpy.data.objects:
    if a.type == 'ARMATURE':
        for b in a.pose.bones:
            b.custom_shape = None
        # Octaedro solido tapa o personagem; STICK deixa o rig visivel sem atrapalhar
        a.data.display_type = 'STICK'
        a.show_in_front = False

# Confere o tamanho: se as pecas vierem microscopicas, o rig colapsou de novo
malhas = [o for o in bpy.context.scene.objects if o.type == 'MESH']
alturas = {o.name: max(o.dimensions) for o in malhas}
menores = [n for n, a in alturas.items() if a < 0.05]
if menores:
    print("!! ALERTA: pecas colapsadas ->", menores)
else:
    topo = max((o.matrix_world @ v.co).z for o in malhas for v in o.data.vertices)
    print("OK: %d pecas, personagem com %.2f de altura" % (len(malhas), topo))

# Enquadra nas MALHAS (o armature do Mixamo mede ~10 unidades e estouraria o
# enquadramento, deixando o personagem como um pontinho no meio da tela).
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        for espaco in area.spaces:
            if espaco.type == 'VIEW_3D':
                espaco.shading.type = 'SOLID'
        regiao = next(r for r in area.regions if r.type == 'WINDOW')
        with bpy.context.temp_override(area=area, region=regiao):
            bpy.ops.object.select_all(action='DESELECT')
            for o in malhas:
                o.select_set(True)
            bpy.context.view_layer.objects.active = malhas[0]
            bpy.ops.view3d.view_axis(type='FRONT')
            bpy.ops.view3d.view_selected()
        break
