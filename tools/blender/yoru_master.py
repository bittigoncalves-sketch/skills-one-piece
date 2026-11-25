"""Rebuild Yoru without external assets (Blender 5.2).

  blender --background -noaudio --factory-startup --python tools/blender/yoru_master.py
  Append -- --no-render to rebuild only the source and game GLB.

Blender +Z becomes glTF/Godot +Y; Blender -Y is the decorated front.
Dimensions are metres, root scale is one. The studio collection is excluded
from export. Original yoru.glb and character sources are never modified.
"""
from pathlib import Path
import json
import math
import struct
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_src/blender/yoru_master.blend"
EXPORT = ROOT / "assets/models/weapons/yoru_v2.glb"
PREVIEWS = ROOT / "art_src/previews"

# How far the blade centreline leaves the axis, and TOWARDS WHICH SIDE.
#
# The ground edge sits at `center + half_width`, so a POSITIVE value puts the
# belly of the curve on the edge side: the convex flank is the one that cuts,
# as on any curved single-edged blade. It was negative until 10/09/2026, which
# ground the edge into the concave flank and left the thick blunt belly leading
# every swing -- a scythe assembled backwards. Reported by the owner from a
# screen capture: "o local onde deveria estar o corte está do lado errado".
#
# Flipping this sign is the whole fix. `edge_direction`, the two YoruRig roll
# constants and the cyan/amber marker all key off +X being the edge, and none of
# them move. Mirrored in `YoruSword._laterais`, which draws that marker.
BLADE_BELLY = .095


def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def mesh(name, vertices, faces, mat, group):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    groups[group].append(obj)
    return obj


def bevel(obj, width=.003, segments=3):
    mod = obj.modifiers.new("Soft machined bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod = obj.modifiers.new("Weighted surface normals", "WEIGHTED_NORMAL")
    mod.keep_sharp = True


def prism(name, outline, thickness, mat, group, bevel_width=.003):
    n = len(outline)
    verts = [(x, y, z) for y in (-thickness/2, thickness/2) for x, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    obj = mesh(name, verts, faces, mat, group)
    if bevel_width:
        bevel(obj, bevel_width)
    return obj


def tube(name, points, radius, mat, group, sides=6):
    # Parallel transported frame avoids tube pinching around helices.
    vertices, faces = [], []
    last_u = None
    for i, co in enumerate(points):
        p = Vector(co)
        tangent = Vector(points[min(i+1, len(points)-1)]) - Vector(points[max(0, i-1)])
        tangent.normalize()
        if last_u is None:
            axis = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
            u = tangent.cross(axis).normalized()
        else:
            u = (last_u - tangent * last_u.dot(tangent)).normalized()
        v = tangent.cross(u).normalized()
        last_u = u
        for j in range(sides):
            a = 2*math.pi*j/sides
            vertices.append(tuple(p + radius*(math.cos(a)*u + math.sin(a)*v)))
        if i:
            for j in range(sides):
                faces.append(((i-1)*sides+j, (i-1)*sides+(j+1)%sides, i*sides+(j+1)%sides, i*sides+j))
    faces.extend([tuple(reversed(range(sides))), tuple(range((len(points)-1)*sides, len(points)*sides))])
    obj = mesh(name, vertices, faces, mat, group)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def cylinder(name, radius, depth, location, mat, group, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    groups[group].append(obj)
    bevel(obj, .0015, 2)
    return obj


def gem(name, x, z, radius, depth, front=-1):
    # Two stepped octagons and a table: readable emerald facets, no transmission.
    verts = []
    rings = [(radius, .043), (radius*.82, .043+depth*.7), (radius*.52, .043+depth)]
    for r, y in rings:
        for i in range(8):
            a = i*math.pi/4 + math.pi/8
            verts.append((x+r*math.cos(a), front*y, z+r*math.sin(a)))
    faces = []
    for ring in range(2):
        for i in range(8):
            faces.append((ring*8+i, ring*8+(i+1)%8, (ring+1)*8+(i+1)%8, (ring+1)*8+i))
    faces.append(tuple(range(16,24)))
    obj = mesh(name, verts, faces, EMERALD, "Gems")
    obj.data.materials.append(EMERALD_LIGHT)
    for i, poly in enumerate(obj.data.polygons):
        poly.material_index = 1 if i % 4 == 1 else 0
    pts = [(x+(radius+.005)*math.cos(i*math.pi/24), front*.044, z+(radius+.005)*math.sin(i*math.pi/24)) for i in range(49)]
    tube(name+" bezel", pts, .0035, GOLD_LIGHT, "Guard")


def bake_group(name, objects, root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Keep source/game vertices at absolute metre positions under identity root.
    bpy.context.scene.cursor.location = (0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.parent = root
    obj.data.calc_loop_triangles()
    # UVs exist for future hand painting; current PBR deliberately needs no atlas.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=.000001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(island_margin=.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()


def studio(scene):
    collection = bpy.data.collections.new("STUDIO — excluded from game export")
    scene.collection.children.link(collection)
    def move(obj):
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        collection.objects.link(obj)
    for name, location, energy, size, color in [
        ("Large warm key", (-2,-3,3), 450, 3, (1,.84,.62)),
        ("Cool blade strip", (1.5,-1.5,2), 260, 1.5, (.50,.74,1)),
        ("Back rim", (-1,1,1.5), 500, 2, (.57,1,.82)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        obj = bpy.context.object
        obj.name = name
        obj.data.energy = energy
        obj.data.shape = "DISK"
        obj.data.size = size
        obj.data.color = color
        aim(obj, (0,0,.7))
        move(obj)
    bpy.ops.object.camera_add(location=(0,-5,.75))
    camera = bpy.context.object
    camera.name = "Yoru presentation camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.38
    aim(camera, (0,0,.75))
    move(camera)
    scene.camera = camera
    scene.world.color = (.09,.09,.09)
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.055,.070,.095,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .6
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1500
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    return camera


def validate_export():
    raw = EXPORT.read_bytes()
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4e4f534a
    data = json.loads(raw[20:20+length])
    nodes = {node["name"]: node for node in data["nodes"]}
    expected = {"handle": (0,0,0), "grip_l": (0,-.17,0), "guarda": (0,.39,0), "ponta": (0,1.77,0), "edge_direction": (.1,.9,0)}
    for name, target in expected.items():
        actual = nodes[name].get("translation", (0,0,0))
        assert max(abs(a-b) for a,b in zip(actual,target)) < 1e-5, (name,actual)
    root = nodes["Yoru"]
    assert root.get("scale", [1,1,1]) == [1,1,1]
    count = 0
    mins, maxs = [math.inf]*3, [-math.inf]*3
    for mesh_data in data["meshes"]:
        for primitive in mesh_data["primitives"]:
            acc = data["accessors"][primitive["attributes"]["POSITION"]]
            for axis in range(3):
                mins[axis] = min(mins[axis], acc["min"][axis])
                maxs[axis] = max(maxs[axis], acc["max"][axis])
            count += data["accessors"][primitive["indices"]]["count"]//3
    assert abs(maxs[1]-1.77) < 1e-5, maxs

    # The belly must sit on the EDGE side. `edge_direction` says the edge is +X,
    # and the curve is what makes one flank reach further out than the other, so
    # the blade's own bounds settle it: +X has to win. This is the regression
    # guard for BLADE_BELLY -- flip that sign back and this assert fires here,
    # at build time, instead of shipping a sword that cuts with its spine.
    blade = data["accessors"][data["meshes"][nodes["Blade"]["mesh"]]["primitives"][0]["attributes"]["POSITION"]]
    belly, spine = blade["max"][0], -blade["min"][0]
    assert belly > spine, ("blade belly is on the blunt side", belly, spine)

    print("YORU_ASSET_VALIDATED " + json.dumps({"bytes": len(raw), "triangles": count, "meshes": len(data["meshes"]), "materials": len(data["materials"]), "bounds_min": mins, "bounds_max": maxs, "blade_belly": belly, "blade_spine": spine, "markers": expected}))


if __name__ == "__main__":
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.preferences.filepaths.save_version = 0
    for output in (SOURCE.parent, EXPORT.parent, PREVIEWS):
        output.mkdir(parents=True, exist_ok=True)
    # Preserve previous generated artifacts when intentionally rebuilding.
    for output in (SOURCE, EXPORT):
        if output.exists():
            import shutil
            backup = Path("/tmp/yoru-asset-backup")
            backup.mkdir(exist_ok=True)
            shutil.copy2(output, backup/output.name)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    groups = {name: [] for name in ("Blade", "Edge", "Guard", "Grip", "Wrap", "Pommel", "Gems")}
    BLACK = material("Yoru · blue black steel", (.012,.023,.038), .78, .28)
    EDGE = material("Yoru · honed edge", (.18,.27,.32), .88, .24)
    GOLD = material("Yoru · antique gold", (.48,.285,.075), .78, .31)
    GOLD_LIGHT = material("Yoru · polished gold relief", (.72,.48,.16), .82, .27)
    IVORY = material("Yoru · ivory braid", (.80,.765,.60), .04, .68)
    GRIP_DARK = material("Yoru · warm grip recess", (.24,.17,.085), .05, .8)
    EMERALD = material("Yoru · deep emerald", (.009,.19,.095), .35, .22)
    EMERALD_LIGHT = material("Yoru · emerald facet", (.055,.48,.24), .3, .24)
    bpy.ops.object.empty_add(type="PLAIN_AXES")
    root = bpy.context.object
    root.name = "Yoru"
    root["contract"] = "metres; handle origin; +Y longitudinal in glTF; blade 1.38 m"
    root["asset_version"] = 2
    # Broad curved blade. Separate centre face, longitudinal facets and ground edge.
    # Cross section travels spine front -> ridge -> edge -> back ridge.
    blade_verts, blade_faces = [], []
    rings = 48
    for i in range(rings+1):
        t = i/rings
        z = .39+1.38*t
        center = BLADE_BELLY*math.sin(math.pi*t)*(.5+.5*t)
        half_width = (.084 + .03*math.sin(math.pi*t))*(1-t**7)
        if i == rings:
            half_width = 0
        thickness = .012*(1-.65*t)
        if i == rings:
            thickness = 0
        for x, y in [(center-half_width, -.003*(1-t)), (center-half_width*.66, -thickness), (center+half_width*.68, -thickness*.78), (center+half_width, 0), (center+half_width*.68, thickness*.78), (center-half_width*.66, thickness), (center-half_width, .003*(1-t))]:
            blade_verts.append((x,y,z))
        if i:
            for j in range(7):
                blade_faces.append(((i-1)*7+j, (i-1)*7+(j+1)%7, i*7+(j+1)%7, i*7+j))
    blade_faces.extend([tuple(reversed(range(7))), tuple(range(rings*7,(rings+1)*7))])
    blade = mesh("Forged curved black blade", blade_verts, blade_faces, BLACK, "Blade")
    blade.data.materials.append(EDGE)
    for i, polygon in enumerate(blade.data.polygons):
        polygon.material_index = 1 if i % 7 in (2,3) else 0
    # Narrow polished spine and irregular hamon inside the broad black face.
    for side in (-1,1):
        pts = []
        for i in range(95):
            t = .02+.96*i/94
            center = BLADE_BELLY*math.sin(math.pi*t)*(.5+.5*t)
            w = (.084+.03*math.sin(math.pi*t))*(1-t**7)
            x = center+w*(.53+.045*math.sin(t*math.pi*24))
            pts.append((x, side*.012*(1-.65*t)*.9, .39+1.38*t))
        tube("Subtle tempered hamon", pts, .00085, EDGE, "Edge", 4)
    # Cruciform guard with tapered fleur-de-lis ends, generous sculpted bevel.
    arm = [(-.39,.39),(-.36,.442),(-.322,.447),(-.285,.425),(-.13,.414),(-.072,.432),(-.05,.52),(-.018,.566),(0,.607),(.018,.566),(.05,.52),(.072,.432),(.13,.414),(.285,.425),(.322,.447),(.36,.442),(.39,.39),(.36,.34),(.321,.332),(.282,.356),(.12,.365),(.066,.342),(.052,.294),(-.052,.294),(-.066,.342),(-.12,.365),(-.282,.356),(-.321,.332),(-.36,.34)]
    prism("Crossguard forged gold", arm, .068, GOLD, "Guard", .006)
    for side in (-1,1):
        # Gold filigree: outline rails, mirrored scrolling leaves and central spear.
        for sign in (-1,1):
            pts = [(sign*x,side*.038,z) for x,z in [(.075,.398),(.14,.395),(.215,.396),(.285,.400),(.317,.426),(.345,.425),(.367,.39),(.345,.358),(.321,.354),(.285,.376),(.21,.384),(.14,.382),(.075,.382)]]
            tube("Raised guard border", pts, .0028, GOLD_LIGHT, "Guard")
            for ox in (.135,.215):
                pts = []
                for i in range(26):
                    angle = -math.pi*.2 + i/25*math.pi*1.9
                    r = .019*(1-i/32)
                    pts.append((sign*(ox+r*math.cos(angle)),side*.039,.39+r*.65*math.sin(angle)))
                tube("Chased scrolling leaf", pts, .002, GOLD_LIGHT, "Guard", 5)
            gem("Quillon emerald", sign*.332,.39,.022,.012,side)
        tube("Cross crest raised spine", [(0,side*.039,.455),(0,side*.038,.53),(0,side*.022,.584)], .0035, GOLD_LIGHT,"Guard")
        gem("Heart emerald",0,.397,.042,.019,side)
        gem("Crest emerald",0,.517,.017,.009,side)
    # Grip extends both sides of handle origin; left hand has a real grip at -.17.
    cylinder("Grip recessed core", .038, .565, (0,0,.0115), GRIP_DARK,"Grip")
    for z in (-.273,.281):
        cylinder("Gold grip ferrule", .044,.022,(0,0,z),GOLD,"Grip")
        for dz in (-.009,.009):
            cylinder("Ferrule engraved lip", .046,.003,(0,0,z+dz),GOLD_LIGHT,"Grip")
    # Two opposing continuous ivory ribbons create a tactile diamond braid.
    for direction in (-1,1):
        for offset in (-.12,.12):
            pts=[]
            for i in range(289):
                t=i/288
                angle=direction*t*2*math.pi*9+offset
                radius=.040 + .0015*math.cos(angle*2)
                pts.append((radius*math.cos(angle),radius*math.sin(angle),-.259+.529*t))
            tube("Ivory woven cord",pts,.0039,IVORY,"Wrap",6)
    # Octagonal pommel repeats the cross geometry and green gemstone.
    prism("Crown pommel", [(-.023,-.28),(-.053,-.302),(-.062,-.336),(-.037,-.366),(0,-.389),(.037,-.366),(.062,-.336),(.053,-.302),(.023,-.28)], .064,GOLD,"Pommel",.005)
    for side in (-1,1):
        gem("Pommel emerald",0,-.331,.025,.009,side)
        tube("Pommel crest",[(-.039,side*.036,-.341),(0,side*.037,-.372),(.039,side*.036,-.341)],.0028,GOLD_LIGHT,"Pommel")
    game_objects=[root]
    for name, objects in groups.items():
        game_objects.append(bake_group(name,objects,root))
    for name, position in {"handle":(0,0,0),"grip_l":(0,0,-.17),"guarda":(0,0,.39),"ponta":(0,0,1.77),"edge_direction":(.1,0,.9)}.items():
        bpy.ops.object.empty_add(type="PLAIN_AXES", location=position)
        marker=bpy.context.object
        marker.name=name
        marker.empty_display_size=.045
        marker.parent=root
        game_objects.append(marker)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in game_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format="GLB",use_selection=True,export_yup=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=False,export_animations=False)
    validate_export()
    camera=studio(scene)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    if "--no-render" not in sys.argv:
        for label, position, target, scale in [
            ("front",(0,-5,.69),(0,0,.69),2.38),
            ("three_quarter",(2.3,-5,2.2),(0,0,.7),2.42),
            ("side",(5,-.75,.7),(0,0,.7),2.38),
            ("detail",(.55,-3,.95),(0,0,.30),.95),
        ]:
            camera.location=position
            aim(camera,target)
            camera.data.ortho_scale=scale
            scene.render.filepath=str(PREVIEWS/f"yoru_{label}.png")
            bpy.ops.render.render(write_still=True)
