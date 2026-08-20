import bpy
import json

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

base_path = "/home/administrador/dev/skills-one-piece/assets/models/base.glb"
bpy.ops.import_scene.gltf(filepath=base_path)

output = {}
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        dims = obj.dimensions
        loc = obj.location
        output[obj.name] = {
            "dimensions": [dims.x, dims.y, dims.z],
            "location": [loc.x, loc.y, loc.z]
        }

with open("base_glb_stats.json", "w") as f:
    json.dump(output, f)
