import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath="/home/administrador/dev/skills-one-piece/assets/models/nami.glb")

for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        print("BONES IN NAMI:")
        for bone in obj.data.bones:
            print(f"- {bone.name}")
