"""Bake reproducível das curvas/IK validadas no Godot para edição no Blender.
Execute tools/export_yoru_poses.gd antes; não sobrescreve o personagem fonte.
"""
import bpy
import json
from pathlib import Path
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art_src/blender/personagem_base_v2.blend'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
scene = bpy.context.scene
scene.render.fps = 30
source = json.loads((ROOT/'art_src/animations/yoru_poses.json').read_text())
# Godot +Yup,-Zfront -> Blender +Zup,+Yfront.
C = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def matrix(values):
    return Matrix([values[i:i+4] for i in range(0,16,4)])

bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/weapons/yoru_v2.glb'))
imported = list(bpy.context.selected_objects)
weapon = bpy.data.objects.new('Yoru_Action_Root',None)
scene.collection.objects.link(weapon)
for obj in imported:
    if obj.parent not in imported:
        obj.parent = weapon
arm.animation_data_create()
weapon.animation_data_create()
first = None
for name, frames in source['actions'].items():
    action = bpy.data.actions.new('Yoru_'+name)
    action.use_fake_user = True
    arm.animation_data.action = action
    weapon_action = bpy.data.actions.new('Yoru_Weapon_'+name)
    weapon_action.use_fake_user = True
    weapon.animation_data.action = weapon_action
    for frame, transforms in enumerate(frames,1):
        targets = {}
        for bone in arm.data.bones:
            if bone.name not in transforms:
                continue
            runtime = C @ matrix(transforms[bone.name]) @ C.inverted()
            targets[bone.name] = runtime @ bone.matrix_local.to_3x3().to_4x4()
            parent = bone.parent
            rest = bone.matrix_local.copy()
            if parent:
                rest = parent.matrix_local.inverted() @ rest
            local = targets.get(parent.name if parent else '',Matrix.Identity(4)).inverted() @ targets[bone.name]
            pose = arm.pose.bones[bone.name]
            pose.rotation_mode = 'QUATERNION'
            pose.matrix_basis = rest.inverted() @ local
            for channel in ('location','rotation_quaternion','scale'):
                pose.keyframe_insert(channel,frame=frame,group=bone.name)
        weapon.rotation_mode = 'QUATERNION'
        weapon.matrix_world = C @ matrix(transforms['__sword']) @ C.inverted()
        for channel in ('location','rotation_quaternion','scale'):
            weapon.keyframe_insert(channel,frame=frame)
    if first is None: first=(action,weapon_action,len(frames))
    action['source'] = 'src/anim/YoruRig.gd + IK validada no rig real'
    action['fps'] = 30
    print('YORU_BAKE',name,len(frames),'frames',len(targets),'joints')
arm.animation_data.action,weapon.animation_data.action,scene.frame_end = first
scene.frame_start = 1
scene.frame_set(1)
scene['Yoru_instructions'] = 'Selecione pares Yoru_<acao> e Yoru_Weapon_<acao>. Gameplay: YoruMoves.gd/YoruRig.gd. Reexportar após editar a autoria runtime.'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_src/blender/yoru_combate.blend'))
