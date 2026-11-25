"""Gomu Gomu no Mi & Gear 3rd assets generator for Blender 5+.
Run: /home/gabriel-bitti/.local/bin/blender -b --python tools/blender/gomu_gomu_assets.py
Exports:
  - assets/models/gomu_gomu/gomu_gomu_fruit.glb
  - assets/models/gomu_gomu/gomu_gear3_fist.glb
"""
import bpy
import math
import os
from mathutils import Vector
from math import sin, cos, pi, exp

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets/models/gomu_gomu')
os.makedirs(OUT, exist_ok=True)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0.0, rough=0.45, emission=(0, 0, 0), emission_energy=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1.0)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emission_energy > 0:
        p.inputs['Emission Color'].default_value = (*emission, 1.0)
        p.inputs['Emission Strength'].default_value = emission_energy
    return m

def mesh(name, verts, faces, mat, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for poly in ob.data.polygons:
        poly.use_smooth = smooth
    return ob

def tube(name, points, radius, mat, res=3):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = radius
    c.bevel_resolution = res
    c.use_fill_caps = True
    s = c.splines.new('POLY')
    s.points.add(len(points) - 1)
    for p, co in zip(s.points, points):
        p.co = (*co, 1.0)
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o

def export_selected(path, objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = os.path.basename(path).replace('.glb', '')
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_materials='EXPORT',
        export_yup=True
    )
    return ob

# ==============================================================================
# 1. GOMU GOMU NO MI FRUIT (Melon with devil spirals & curly stem)
# ==============================================================================
def build_gomu_fruit():
    clear_scene()

    purple_base = material('Gomu | Purple Skin', (0.46, 0.14, 0.62), rough=0.38)
    purple_spiral = material('Gomu | Violet Swirl', (0.68, 0.22, 0.88), rough=0.42,
                             emission=(0.55, 0.18, 0.72), emission_energy=0.25)
    green_stem = material('Gomu | Jade Curly Stem', (0.12, 0.44, 0.18), rough=0.5)
    leaf_mat = material('Gomu | Leaf', (0.18, 0.52, 0.20), rough=0.55)

    # Fruit body: sphere slightly flattened at poles like a cantaloupe melon
    def sphere_point(u, v, r=0.42):
        z = sin(u)
        factor = 1.0 - 0.08 * max(0.0, z)**2
        x = cos(u) * cos(v) * r * factor
        y = cos(u) * sin(v) * r * factor
        z_pos = z * r * 0.96
        return Vector((x, y, z_pos))

    M = 48  # latitudes
    N = 64  # longitudes
    verts = [sphere_point(-pi/2 + pi * i / M, 2 * pi * j / N) for i in range(M + 1) for j in range(N)]
    faces = [(i * N + j, i * N + (j + 1) % N, (i + 1) * N + (j + 1) % N, (i + 1) * N + j) for i in range(M) for j in range(N)]
    mesh('Gomu_Melon_Base', verts, faces, purple_base)

    # Classic devil swirls wrapping the sphere
    centers = [
        (-0.55, -2.4, 0.19), (-0.52, -1.2, 0.19), (-0.50, 0.0, 0.20), (-0.52, 1.25, 0.19), (-0.55, 2.45, 0.19),
        (0.0, -2.7, 0.21), (0.0, -1.6, 0.21), (0.0, -0.5, 0.22), (0.0, 0.6, 0.21), (0.0, 1.7, 0.21), (0.0, 2.8, 0.21),
        (0.52, -2.3, 0.19), (0.50, -1.1, 0.19), (0.50, 0.1, 0.20), (0.52, 1.3, 0.19), (0.55, 2.5, 0.19)
    ]

    for k, (u_c, v_c, span) in enumerate(centers):
        pts = []
        for step in range(48):
            t = step / 47.0
            angle = 2.0 * pi * 1.5 * t + k * 0.4
            r = span * (0.08 + 0.92 * t)
            u_p = u_c + sin(angle) * r
            v_p = v_c + cos(angle) * r * 1.2
            base_pt = sphere_point(u_p, v_p, 0.422)
            pts.append(base_pt)
        tube(f'Gomu_Spiral_{k:02d}', pts, 0.009, purple_spiral, res=2)

    # Classic curly "S" stem at top cleft
    stem_pts = []
    for step in range(80):
        t = step / 79.0
        if t < 0.35:
            q = t / 0.35
            x = 0.015 * sin(q * pi)
            y = 0.01 * cos(q * pi)
            z = 0.38 + 0.18 * q
        else:
            q = (t - 0.35) / 0.65
            ang = -pi/2 + q * 2.2 * pi
            rad = 0.085 * (1.0 - 0.45 * q)
            x = rad * cos(ang)
            y = 0.02 * sin(q * pi)
            z = 0.56 + rad * sin(ang)
        stem_pts.append(Vector((x, y, z)))
    tube('Gomu_Curly_Stem', stem_pts, 0.022, green_stem, res=3)

    # Crown leaves at stem base
    def make_leaf(name, angle_rot):
        vv = []
        ff = []
        length = 0.16
        width = 0.065
        o = Vector((0, 0, 0.385))
        c_rot = cos(angle_rot)
        s_rot = sin(angle_rot)
        for i in range(12):
            t = i / 11.0
            mid_z = 0.385 + 0.04 * sin(pi * t) - 0.03 * t
            mid_dist = length * t
            mid_x = mid_dist * c_rot
            mid_y = mid_dist * s_rot
            for j in range(5):
                s = (j / 2.0) - 1.0
                w = width * sin(pi * t)**0.8 * s
                px = mid_x - w * s_rot
                py = mid_y + w * c_rot
                pz = mid_z - 0.012 * s * s
                vv.append(Vector((px, py, pz)))
        for i in range(11):
            for j in range(4):
                ff.append((i * 5 + j, i * 5 + j + 1, (i + 1) * 5 + j + 1, (i + 1) * 5 + j))
        mesh(name, vv, ff, leaf_mat)

    for i in range(3):
        make_leaf(f'Crown_Leaf_{i}', i * (2 * pi / 3) + 0.3)

    fruit_path = os.path.join(OUT, 'gomu_gomu_fruit.glb')
    export_selected(fruit_path, list(bpy.context.scene.objects))
    print("Exported:", fruit_path)

# ==============================================================================
# 2. GEAR 3RD GIGANT FIST (Colossal Anime Fist)
# ==============================================================================
def build_gear3_fist():
    clear_scene()

    skin_mat = material('Gear3 | Anime Skin', (0.96, 0.60, 0.47), rough=0.35,
                        emission=(0.94, 0.52, 0.40), emission_energy=0.2)
    cuff_mat = material('Gear3 | Shadow Crease', (0.75, 0.38, 0.30), rough=0.45)

    objs = []

    # Forearm junction / wrist (depth along Z)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24, radius=0.9, depth=1.6, location=(0, 0, 0.8)
    )
    cuff = bpy.context.object
    cuff.name = 'Forearm_Cuff'
    cuff.rotation_euler = (pi / 2, 0, 0)
    cuff.data.materials.append(cuff_mat)
    objs.append(cuff)

    # Main palm / back of fist block (solid, rounded box)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.6))
    palm = bpy.context.object
    palm.name = 'Palm_Block'
    palm.scale = (2.1, 1.7, 1.8)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = palm.modifiers.new('Bevel', 'BEVEL')
    mod.width = 0.35
    mod.segments = 3
    palm.data.materials.append(skin_mat)
    objs.append(palm)

    # 4 Folded Finger knuckles across the front face (-Z)
    finger_widths = [0.46, 0.50, 0.48, 0.44]
    x_offsets = [-0.75, -0.25, 0.25, 0.75]
    for i, (x_pos, fw) in enumerate(zip(x_offsets, finger_widths)):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_pos, 0.08, -1.8))
        f = bpy.context.object
        f.name = f'Knuckle_{i}'
        f.scale = (fw, 1.45, 1.1)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mod_f = f.modifiers.new('Bevel', 'BEVEL')
        mod_f.width = 0.22
        mod_f.segments = 3
        f.data.materials.append(skin_mat)
        objs.append(f)

        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16, ring_count=12, radius=fw * 0.72,
            location=(x_pos, 0.08, -2.4)
        )
        knuckle_cap = bpy.context.object
        knuckle_cap.name = f'Knuckle_Cap_{i}'
        knuckle_cap.scale = (1.0, 1.3, 0.8)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        knuckle_cap.data.materials.append(skin_mat)
        objs.append(knuckle_cap)

    # Folded Thumb along the side
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.15, -0.32, -1.1))
    thumb = bpy.context.object
    thumb.name = 'Thumb_Fold'
    thumb.scale = (0.65, 0.75, 1.4)
    thumb.rotation_euler = (0.2, 0.3, 0.1)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    mod_t = thumb.modifiers.new('Bevel', 'BEVEL')
    mod_t.width = 0.2
    mod_t.segments = 3
    thumb.data.materials.append(skin_mat)
    objs.append(thumb)

    fist_path = os.path.join(OUT, 'gomu_gear3_fist.glb')
    export_selected(fist_path, objs)
    print("Exported:", fist_path)

if __name__ == '__main__':
    build_gomu_fruit()
    build_gear3_fist()
