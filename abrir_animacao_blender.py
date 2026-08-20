import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

anim_path = "/home/administrador/dev/skills-one-piece/assets/animations_glb/punching.glb"
base_path = "/home/administrador/dev/skills-one-piece/assets/models/base.glb"

# disable_bone_shape=True: sem isso o importador cria uma Icosphere gigante como
# custom shape dos ossos do Mixamo e ela engole o personagem na viewport.
bpy.ops.import_scene.gltf(filepath=anim_path, disable_bone_shape=True)

armature = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif "Beta_Surface" in obj.name or "Beta_Joints" in obj.name:
        bpy.data.objects.remove(obj, do_unlink=True)

if armature:
    armature.data.pose_position = 'REST'
    
    bpy.ops.import_scene.gltf(filepath=base_path, disable_bone_shape=True)
    
    mapping = {
        "Torso": "mixamorig:Spine",
        "Head": "mixamorig:Head",
        "UpperArm_L": "mixamorig:LeftArm",
        "ForeArm_L": "mixamorig:LeftForeArm",
        "UpperArm_R": "mixamorig:RightArm",
        "ForeArm_R": "mixamorig:RightForeArm",
        "Thigh_L": "mixamorig:LeftUpLeg",
        "Shin_L": "mixamorig:LeftLeg",
        "Foot_L": "mixamorig:LeftFoot",
        "Thigh_R": "mixamorig:RightUpLeg",
        "Shin_R": "mixamorig:RightLeg",
        "Foot_R": "mixamorig:RightFoot"
    }
    
    # Primeiro salvamos a posicao global de tudo pra nao explodir
    global_matrices = {}
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            global_matrices[obj] = obj.matrix_world.copy()
            
    # Remove parentesco mantendo a posicao
    for obj in global_matrices:
        obj.parent = None
        obj.matrix_world = global_matrices[obj]
    
    # Aplica as constraints
    for obj in global_matrices:
        bone_name = None
        for key, val in mapping.items():
            if key in obj.name:
                bone_name = val
                break
        
        if bone_name:
            con = obj.constraints.new('CHILD_OF')
            con.target = armature
            con.subtarget = bone_name
            bpy.context.view_layer.objects.active = obj
            bpy.ops.constraint.childof_set_inverse(constraint="Child Of", owner='OBJECT')

    armature.data.pose_position = 'POSE'
    if armature.animation_data and armature.animation_data.action:
        action = armature.animation_data.action
        bpy.context.scene.frame_start = int(action.frame_range[0])
        bpy.context.scene.frame_end = int(action.frame_range[1])
