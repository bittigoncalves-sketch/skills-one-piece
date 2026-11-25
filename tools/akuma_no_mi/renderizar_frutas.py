"""Renderiza cada assets/models/akuma_no_mi/<id>.glb (vista 3/4, Workbench com textura, sem suavização) em PNGs e
monta uma folha de contato.   blender -b -P tools/akuma_no_mi/renderizar_frutas.py -- SAIDA_DIR [ids...]"""
import math, os, sys, glob
import bpy
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:]
saida, ids = args[0], args[1:]
os.makedirs(saida, exist_ok=True)
pasta = os.environ.get("PASTA_GLB") or os.path.join(RAIZ, "assets/models/akuma_no_mi")   # PASTA_GLB/ORTHO: alimentos e outros itens
if not ids:
    ids = sorted(os.path.basename(p)[:-4] for p in glob.glob(pasta + "/*.glb"))
for fid in ids:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f"{pasta}/{fid}.glb")
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.25, 0.28, 0.34)
    cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = float(os.environ.get("ORTHO", "0.95"))
    co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
    d = 3.0; az = math.radians(-35); el = math.radians(22)
    co.location = (d * math.sin(az) * math.cos(el) * -1, d * math.cos(az) * math.cos(el) * -1, d * math.sin(el) + 0.12)
    co.rotation_euler = (math.radians(90) - el, 0, math.radians(180) + az * -1 + math.radians(0))
    # aponta para o centro
    from mathutils import Vector
    alvo = Vector((0, 0, 0.12)); dirv = alvo - co.location
    co.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(saida, fid + ".png")
    bpy.ops.render.render(write_still=True)
    print("OK", fid)
