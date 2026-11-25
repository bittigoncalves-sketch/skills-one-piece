"""Build the reference block mannequin, FK/IK rig and matching Godot node rig.

blender --background --python tools/blender/redesenhar_base.py
All dimensions are metres; +X is right, +Y forward, +Z up in Blender.
The GLB conversion gives Godot +X right, +Y up and -Z forward.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/base_v2'
ART = ROOT / 'art_src'
BONES = {}
PARTS = []
GODOT = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0))).to_4x4()


def bone(name, head, tail, parent=None, category='body', deform=True):
    BONES[name] = dict(head=list(head), tail=list(tail), parent=parent,
                       category=category, deform=deform)
    return name


def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .78
    return m


def block(name, center, size, owner, mat, bevel=.006, rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.object
    o.name = 'Geo_' + name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Small planar edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.rotation_euler.y = rotation
    o.data.materials.append(mat)
    PARTS.append((o, owner))
    return o


def segment(name, a, b, width, depth, owner, mat, gap=.015):
    a, b = Vector(a), Vector(b)
    o = block(name, (a+b)/2, (width, depth, (b-a).length-gap), owner, mat)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = (b-a).to_track_quat('Z', 'Y')
    return o


def anatomy(gray, joint):
    bone('Root', (0, 0, 0), (0, 0, .12), category='root', deform=False)
    bone('Torso', (0, 0, .91), (0, 0, 1.05), 'Root')
    bone('Pelvis', (0, 0, .91), (0, 0, 1.02), 'Torso')
    bone('SpineLower', (0, 0, 1.025), (0, 0, 1.14), 'Torso')
    bone('SpineMid', (0, 0, 1.14), (0, 0, 1.29), 'SpineLower')
    bone('Chest', (0, 0, 1.29), (0, 0, 1.49), 'SpineMid')
    bone('Neck', (0, 0, 1.49), (0, 0, 1.55), 'Chest')
    bone('NeckUpper', (0, 0, 1.55), (0, 0, 1.59), 'Neck')
    bone('Head', (0, 0, 1.59), (0, 0, 1.96), 'NeckUpper')
    block('Pelvis', (0, 0, .952), (.40, .255, .125), 'Pelvis', gray)
    block('PelvisInset', (0, 0, .893), (.17, .22, .063), 'Pelvis', joint)
    block('Waist', (0, 0, 1.045), (.305, .215, .078), 'SpineLower', joint)
    block('Abdomen', (0, 0, 1.15), (.395, .25, .19), 'SpineMid', gray)
    block('Chest', (0, 0, 1.36), (.445, .28, .28), 'Chest', gray)
    block('NeckLower', (0, 0, 1.526), (.142, .145, .065), 'Neck', joint, .003)
    block('NeckUpper', (0, 0, 1.574), (.148, .15, .034), 'NeckUpper', gray, .003)
    block('Head', (0, 0, 1.795), (.425, .365, .335), 'Head', gray, .005)
    block('HeadTop', (0, -.003, 1.973), (.345, .30, .035), 'Head', gray, .003)
    block('HeadBottom', (0, 0, 1.613), (.335, .29, .031), 'Head', gray, .003)
    # Blank reference face is preserved. These are attachment/animation anchors,
    # explicitly non-deforming until face geometry is authored.
    bone('Jaw', (0, .10, 1.66), (0, .17, 1.625), 'Head', 'face_anchor', False)
    for side, s in [('L', -1), ('R', 1)]:
        for label, x, z in [('Eye', .092, 1.81), ('Brow', .092, 1.86),
                            ('Cheek', .13, 1.73), ('MouthCorner', .06, 1.68)]:
            bone(label+'_'+side, (s*x, .18, z), (s*x, .21, z),
                 'Head', 'face_anchor', False)
        sh = Vector((s*.254, 0, 1.475))
        elbow = Vector((s*.348, 0, 1.205))
        wrist = Vector((s*.438, 0, .951))
        hand = Vector((s*.451, 0, .914))
        clav = bone('Clavicle_'+side, (s*.10, 0, 1.46), sh, 'Chest')
        bone('Scapula_'+side, (s*.13, -.09, 1.43), (s*.22, -.09, 1.42), 'Chest')
        upper = bone('UpperArm_'+side, sh, elbow, clav)
        twist = bone('UpperArmTwist_'+side, sh.lerp(elbow, .5), elbow, upper)
        bone('Elbow_'+side, elbow, elbow+Vector((0, 0, -.04)), upper)
        fore = bone('ForeArm_'+side, elbow, wrist, upper)
        ft = bone('ForeArmTwist_'+side, elbow.lerp(wrist, .52), wrist, fore)
        wr = bone('Wrist_'+side, wrist, hand, fore)
        palm = bone('Hand_'+side, hand, hand+Vector((0, 0, -.10)), wr)
        segment('Shoulder_'+side, sh, sh.lerp(elbow, .25), .172, .235, upper, gray, .006)
        segment('UpperArm_'+side, sh.lerp(elbow, .23), sh.lerp(elbow, .77), .172, .22, twist, gray, .006)
        segment('ElbowJoint_'+side, sh.lerp(elbow, .76), elbow.lerp(wrist, .10), .108, .132, 'Elbow_'+side, joint, .004)
        segment('ForeArm_'+side, elbow.lerp(wrist, .12), elbow.lerp(wrist, .91), .155, .182, ft, gray, .006)
        segment('Wrist_'+side, elbow.lerp(wrist, .90), hand, .103, .123, wr, joint, .003)
        block('Palm_'+side, hand+Vector((0, -.005, -.044)), (.163, .13, .087), palm, gray, .004)
        block('Scapula_'+side, (s*.16, -.143, 1.405), (.13, .014, .15), 'Scapula_'+side, gray, .002)
        # Four three-phalange fingers + metacarpals; narrow seams retain a block hand.
        for k, digit in enumerate(['Index', 'Middle', 'Ring', 'Little']):
            x = hand.x + s*(-.060+k*.040)
            z = hand.z-.071
            meta = bone(digit+'Meta_'+side, (x, -.014, hand.z-.01),
                        (x, .015, z), palm, 'fingers')
            parent = meta
            for j, length in enumerate([.031, .024, .020]):
                a, b = (x, .015, z), (x, .015, z-length)
                bn = bone(f'{digit}{j+1}_{side}', a, b, parent, 'fingers')
                segment(f'{digit}{j+1}_{side}', a, b, .038, .088, bn, gray, .001)
                parent, z = bn, z-length
        thumb_a = hand+Vector((-s*.081, .028, -.017))
        parent = palm
        for j, dv in enumerate([(-s*.025, .014, -.027), (s*.006, .008, -.032), (s*.012, 0, -.024)]):
            thumb_b = thumb_a+Vector(dv)
            bn = bone(f'Thumb{j+1}_{side}', thumb_a, thumb_b, parent, 'fingers')
            segment(f'Thumb{j+1}_{side}', thumb_a, thumb_b, .044, .064, bn, gray, .001)
            thumb_a, parent = thumb_b, bn
        hip = Vector((s*.144, 0, .909))
        knee = Vector((s*.17, 0, .566))
        ankle = Vector((s*.195, 0, .224))
        thigh = bone('Thigh_'+side, hip, knee, 'Torso')
        tt = bone('ThighTwist_'+side, hip.lerp(knee, .35), knee, thigh)
        bone('Knee_'+side, knee, knee+Vector((0, 0, -.043)), thigh)
        shin = bone('Shin_'+side, knee, ankle, thigh)
        st = bone('ShinTwist_'+side, knee.lerp(ankle, .40), ankle, shin)
        # Foot pivot deliberately at the ankle for the existing two-bone leg IK.
        foot = bone('Foot_'+side, ankle, (ankle.x, .16, .102), shin)
        bone('Heel_'+side, (ankle.x, -.04, .11), (ankle.x, -.09, .11), foot)
        ball = bone('Ball_'+side, (ankle.x, .125, .073), (ankle.x, .22, .073), foot)
        segment('Thigh_'+side, hip.lerp(knee, .035), hip.lerp(knee, .82), .205, .24, tt, gray, .005)
        segment('KneeJoint_'+side, hip.lerp(knee, .81), knee.lerp(ankle, .19), .128, .15, 'Knee_'+side, joint, .003)
        segment('Shin_'+side, knee.lerp(ankle, .16), knee.lerp(ankle, .79), .205, .215, st, gray, .005)
        segment('AnkleJoint_'+side, knee.lerp(ankle, .78), ankle, .131, .14, shin, joint, .003)
        block('AnkleCuff_'+side, (ankle.x, 0, .194), (.214, .219, .067), foot, gray, .004)
        block('Heel_'+side, (ankle.x, -.039, .094), (.207, .15, .154), 'Heel_'+side, gray, .004)
        block('Foot_'+side, (ankle.x, .093, .074), (.213, .122, .122), foot, gray, .004)
        # Five individually articulated toes fit inside the same squared boot silhouette.
        for k, digit in enumerate(['BigToe', 'Toe2', 'Toe3', 'Toe4', 'Toe5']):
            x = ankle.x+s*(-.083+k*.042)
            parent = bone(digit+'Meta_'+side, (x, .105, .074), (x, .149, .074), ball, 'toes', False)
            y = .149
            for j in range(2):
                bn = bone(f'{digit}{j+1}_{side}', (x, y, .074), (x, y+.044, .074), parent, 'toes')
                block(f'{digit}{j+1}_{side}', (x, y+.022, .074), (.0413, .0433, .122), bn, gray, .001)
                y, parent = y+.044, bn
        for name, pt, parent in [('Grip', hand+Vector((0, .05, -.067)), palm),
                                 ('Weapon', hand+Vector((0, .05, -.067)), palm),
                                 ('Sole', (ankle.x, .08, .012), foot)]:
            bone(name+'_'+side, pt, Vector(pt)+Vector((0, .06, 0)), parent, 'socket', False)


def make_armature():
    data = bpy.data.armatures.new('BaseV2_Rig')
    arm = bpy.data.objects.new('BaseV2_Armature', data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, d in BONES.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = d['head'], d['tail']
        if d['parent']:
            b.parent = data.edit_bones[d['parent']]
        b.use_deform = d['deform']
    bpy.ops.object.mode_set(mode='OBJECT')
    collections = {}
    for name, d in BONES.items():
        category = d['category']
        if category not in collections:
            collections[category] = data.collections.new(category)
        collections[category].assign(data.bones[name])
    for o, bn in PARTS:
        o.parent = arm
        vg = o.vertex_groups.new(name=bn)
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Rigid voxel skin', 'ARMATURE')
        mod.object = arm
    arm.show_in_front = True
    data.display_type = 'STICK'
    # Four IK chains. FK is the default; enable the constraint to pose by target.
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    controls = []
    for side in ['L', 'R']:
        for kind, source, end in [('Arm', 'ForeArm', 'Wrist'), ('Leg', 'Shin', 'Foot')]:
            pt = Vector(BONES[end+'_'+side]['head'])
            target = f'IK_{kind}_{side}'
            pole = f'Pole_{kind}_{side}'
            for name, p in [(target, pt), (pole, Vector(BONES[source+'_'+side]['head'])+Vector((0, -.5 if kind=='Arm' else .5, 0)))]:
                b = data.edit_bones.new(name)
                b.head, b.tail = p, p+Vector((0, 0, .08))
                b.use_deform = False
                controls.append(name)
    bpy.ops.object.mode_set(mode='POSE')
    for side in ['L', 'R']:
        for kind, source in [('Arm', 'ForeArm'), ('Leg', 'Shin')]:
            c = arm.pose.bones[source+'_'+side].constraints.new('IK')
            c.name = 'IK optional (0 FK / 1 IK)'
            c.target, c.subtarget = arm, f'IK_{kind}_{side}'
            c.pole_target, c.pole_subtarget = arm, f'Pole_{kind}_{side}'
            c.chain_count = 2
            c.use_stretch = False
            c.influence = 0
    bpy.ops.object.mode_set(mode='OBJECT')
    col = data.collections.new('IK_controls')
    for name in controls:
        col.assign(data.bones[name])
    return arm


def validate(arm):
    bpy.context.view_layer.update()
    assert len(arm.data.bones) == len(BONES)+8
    weighted = {bn for _, bn in PARTS}
    for o, bn in PARTS:
        assert bn in arm.data.bones
        assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in o.data.vertices)
    # Independently check evaluated skin against FK rigid transforms during bending.
    poses = {'ForeArm_R': (1.35, 0, 0), 'Shin_L': (-1.2, 0, 0),
             'SpineMid': (.15, 0, .1), 'Index1_R': (.8, 0, 0), 'Ball_L': (.3, 0, 0)}
    for name, angles in poses.items():
        p = arm.pose.bones[name]
        p.rotation_mode = 'XYZ'
        p.rotation_euler = angles
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    worst = 0
    for o, bn in PARTS:
        evaluated = o.evaluated_get(dg)
        skin = arm.pose.bones[bn].matrix @ arm.data.bones[bn].matrix_local.inverted()
        for a, b in zip(o.data.vertices, evaluated.data.vertices):
            expected = skin @ o.matrix_world @ a.co
            actual = evaluated.matrix_world @ b.co
            worst = max(worst, (expected-actual).length)
    assert worst < 1e-5, worst
    for p in arm.pose.bones:
        p.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ik_errors = {}
    for side, sign in [('L', -1), ('R', 1)]:
        for kind, source in [('Arm', 'ForeArm'), ('Leg', 'Shin')]:
            end = arm.pose.bones[source+'_'+side]
            target = arm.pose.bones[f'IK_{kind}_{side}']
            original = target.matrix.copy()
            moved = original.copy()
            moved.translation += Vector((-sign*.025, .05, .07))
            target.matrix = moved
            constraint = end.constraints[0]
            constraint.iterations = 500
            constraint.influence = 1
            bpy.context.view_layer.update()
            error = (end.tail-target.head).length
            ik_errors[kind+'_'+side] = error
            assert error < .003, (kind, side, error)
            constraint.influence = 0
            target.matrix = original
            bpy.context.view_layer.update()
    for o, _ in PARTS:
        o.data.calc_loop_triangles()
    return dict(total_bones=len(arm.data.bones), runtime_joints=len(BONES),
                weighted_bones=len(weighted), ik_controls=8, mesh_parts=len(PARTS),
                triangles=sum(len(o.data.loop_triangles) for o, _ in PARTS),
                skin_pose_max_error_m=worst, unweighted_vertices=0,
                ik_endpoint_errors_m=ik_errors,
                note='Face anchors and sockets are non-deforming; IK is opt-in in Blender.')


def demonstration(arm):
    """Author in game axes, convert to each bone's rest frame without guessing rolls."""
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.frame_start, scene.frame_end = 1, 81
    c = GODOT.inverted()
    fist = {f'{digit}{j}_{side}': (.95 if j==1 else 1.2, 0, 0)
            for side in ['L', 'R'] for digit in ['Index', 'Middle', 'Ring', 'Little']
            for j in range(1, 4)}
    frames = {1: {}, 21: fist,
              41: {**fist, 'UpperArm_R': (.7, 0, .2), 'ForeArm_R': (1.3, 0, 0),
                   'Wrist_R': (0, -.25, 0), 'Clavicle_R': (0, 0, .10),
                   'SpineMid': (0, -.18, 0), 'Head': (0, .18, 0)},
              61: {'Thigh_L': (.8, 0, 0), 'Shin_L': (-1.3, 0, 0),
                   'Foot_L': (.5, 0, 0), 'Ball_R': (.25, 0, 0),
                   'UpperArm_R': (-.5, 0, 0), 'ForeArm_L': (.7, 0, 0)}, 81: {}}
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions.new('Rig_Demonstracao')
    arm.animation_data.action.use_fake_user = True
    for frame, rotations in frames.items():
        node_world, targets = {}, {}
        for name, d in BONES.items():
            parent = d['parent']
            origin = Vector(d['head'])
            if parent:
                origin -= Vector(BONES[parent]['head'])
            delta = c @ Euler(rotations.get(name, (0, 0, 0)), 'ZXY').to_matrix().to_4x4() @ GODOT
            node_world[name] = node_world.get(parent, Matrix.Identity(4)) @ Matrix.Translation(origin) @ delta
            orientation = arm.data.bones[name].matrix_local.to_3x3().to_4x4()
            targets[name] = node_world[name] @ orientation
            rest = arm.data.bones[name].matrix_local.copy()
            if parent:
                rest = arm.data.bones[parent].matrix_local.inverted() @ rest
            local = targets.get(parent, Matrix.Identity(4)).inverted() @ targets[name]
            pb = arm.pose.bones[name]
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis = rest.inverted() @ local
            for prop in ['location', 'rotation_quaternion', 'scale']:
                pb.keyframe_insert(data_path=prop, frame=frame, group=name)
    scene.frame_set(1)
    bpy.context.view_layer.update()


def export(arm, report):
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for o, _ in PARTS:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'base_v2_rigged.glb'),
        use_selection=True, export_animations=True, export_animation_mode='ACTIONS', export_extras=True,
        export_def_bones=False)
    runtime = bpy.data.collections.new('Godot_Runtime')
    bpy.context.scene.collection.children.link(runtime)
    proxies = {}
    # Axis-aligned nodes preserve the exact Euler convention of the current game.
    for name, d in BONES.items():
        p = bpy.data.objects.new(name, None)
        runtime.objects.link(p)
        p.location = d['head']
        p['rig_joint'] = True
        proxies[name] = p
    bpy.context.view_layer.update()
    for name, d in BONES.items():
        if d['parent']:
            p = proxies[name]
            world = p.matrix_world.copy()
            p.parent = proxies[d['parent']]
            p.matrix_world = world
    bpy.context.view_layer.update()
    for o, bn in PARTS:
        p = o.copy()
        p.data = o.data.copy()
        p.modifiers.clear()
        p.vertex_groups.clear()
        runtime.objects.link(p)
        world = o.matrix_world.copy()
        p.parent = proxies[bn]
        p.matrix_world = world
        p.name = o.name+'_Runtime'
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for o in runtime.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'base_v2_runtime.glb'),
        use_selection=True, export_animations=False, export_extras=True)
    # The duplicate node export is not kept in the editable artist scene.
    for o in list(runtime.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(runtime)
    manifest = dict(reference='art_src/references/personagem_base_2026-09-08.png',
                    godot_front='-Z', godot_right='+X', height_m=1.9775,
                    report=report, bones=BONES,
                    controls={b.name: dict(head=list(b.head_local), tail=list(b.tail_local),
                              parent=None, category='IK_controls', deform=False)
                              for b in arm.data.bones if b.name not in BONES})
    (OUT/'rig_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')


def studio(arm):
    floor = material('Studio floor', (.055, .067, .082))
    bpy.ops.mesh.primitive_plane_add(size=200)
    plane = bpy.context.object
    plane.name = 'StudioFloor'
    plane.location.z = -.009
    plane.data.materials.append(floor)
    for name, loc, power, size in [('Key', (3, 4, 5), 450, 4), ('Fill', (-3, 2, 3), 220, 3), ('Rim', (1, -3, 4), 500, 3)]:
        bpy.ops.object.light_add(type='AREA', location=loc)
        light = bpy.context.object
        light.name = 'Studio_'+name
        light.data.energy = power
        light.data.shape = 'DISK'
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 1))-light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add(location=(2.6, 6, 2.6))
    cam = bpy.context.object
    cam.name = 'ReviewCamera'
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.45
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 850
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('StudioWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.22, .25, .30, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
    for name, loc in [('front', (0, 6, 1.15)), ('three_quarter', (3, 6, 2.8)), ('side', (6, 0, 1.2))]:
        cam.location = loc
        cam.rotation_euler = (Vector((0, 0, 1))-cam.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(ART/'previews'/f'base_v2_{name}.png')
        bpy.ops.render.render(write_still=True)
    scene.frame_set(41)
    cam.location = (3, 6, 2.8)
    cam.rotation_euler = (Vector((0, 0, 1))-cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ART/'previews/base_v2_pose.png')
    bpy.ops.render.render(write_still=True)
    scene.frame_set(1)
    # A separate visible skeleton render, from the actual authored bones.
    overlay = bpy.data.collections.new('RigDiagram')
    scene.collection.children.link(overlay)
    cyan = material('Rig cyan', (.05, .7, .85))
    for name, d in BONES.items():
        if d['category'] in ['face_anchor', 'socket']:
            continue
        a, b = Vector(d['head']), Vector(d['tail'])
        a.y += .28
        b.y += .28
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=.0035, depth=(b-a).length, location=(a+b)/2)
        obj = bpy.context.object
        obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
        obj.data.materials.append(cyan)
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        overlay.objects.link(obj)
    cam.location = (0, 6, 1.05)
    cam.rotation_euler = (Vector((0, 0, 1))-cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ART/'previews/base_v2_bones.png')
    bpy.ops.render.render(write_still=True)
    overlay.hide_render = True
    overlay.hide_viewport = True
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_distance = 3.5
            area.spaces.active.region_3d.view_location = (0, 0, 1)
            area.spaces.active.region_3d.view_rotation = cam.rotation_euler.to_quaternion()
    # Pack the supplied reference so the .blend remains self-contained.
    reference = bpy.data.objects.new('Reference_sheet (packed)', None)
    scene.collection.objects.link(reference)
    reference.empty_display_type = 'IMAGE'
    reference.data = bpy.data.images.load(str(ART/'references/personagem_base_2026-09-08.png'))
    reference.data.pack()
    reference.empty_display_size = 2.2
    reference.location = (2.1, -.5, 1)
    reference.rotation_euler.x = math.pi/2
    reference.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/'blender/personagem_base_v2.blend'))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT.mkdir(parents=True, exist_ok=True)
    (ART/'previews').mkdir(parents=True, exist_ok=True)
    gray = material('Reference gray', (.47, .48, .50))
    joint = material('Joint gray', (.38, .39, .41))
    anatomy(gray, joint)
    arm = make_armature()
    report = validate(arm)
    demonstration(arm)
    export(arm, report)
    print('BASE_V2_REPORT', json.dumps(report))
    studio(arm)


if __name__ == '__main__':
    main()
