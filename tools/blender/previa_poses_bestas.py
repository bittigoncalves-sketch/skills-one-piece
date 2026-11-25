"""Prévia rápida das poses das bestas do mar, direto no Blender (08/10/2026).

Aplica `animacoes_bestas_mar.pose()` num instante do clipe e renderiza 3/4 e perfil,
sem bake nem exportação: serve para iterar a postura antes de assar os GLBs.

DISPLAY=:1 blender -b --python tools/blender/previa_poses_bestas.py -- <pasta> <especie,...> <clipe:fracao,...>
  ex.: ... -- /tmp/previa bovina,serpente dormindo:0.25,nadando_walk:0.5

Sai <pasta>/<especie>_<clipe>_<fracao>_{34,lado,topo}.png. Não salva o .blend.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import animacoes_bestas_mar as anim  # noqa: E402


def preparar_cena():
    cena = bpy.context.scene
    try:
        cena.render.engine = "BLENDER_WORKBENCH"
        cena.display.shading.light = "STUDIO"
        cena.display.shading.color_type = "TEXTURE"
    except TypeError:
        cena.render.engine = "BLENDER_EEVEE"
    cena.render.resolution_x = 640
    cena.render.resolution_y = 420
    cena.render.film_transparent = False
    if cena.world is None:
        cena.world = bpy.data.worlds.new("Previa")
    cena.world.color = (0.55, 0.7, 0.85)
    # Laje fina (e não um plano): na vista de perfil a linha do chão aparece.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -0.15))
    chao = bpy.context.active_object
    chao.scale = (80, 80, 0.3)
    chao.name = "ChaoPrevia"
    mat = bpy.data.materials.new("AreiaPrevia")
    mat.diffuse_color = (0.85, 0.78, 0.6, 1)
    chao.data.materials.append(mat)
    cams = {}
    for nome, pos, alvo, orto in [("34", (34, 34, 16), (0, 0, 4), False), ("lado", (60, 0, 6), (0, 0, 6), True),
                                  ("topo", (0, 0.01, 60), (0, 0, 0), True)]:
        dados = bpy.data.cameras.new("Cam" + nome)
        if orto:
            dados.type = "ORTHO"
            dados.ortho_scale = 34
        cam = bpy.data.objects.new("Cam" + nome, dados)
        cena.collection.objects.link(cam)
        cam.location = pos
        cam.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        cams[nome] = cam
    return cams


def posar(rig, especie, clipe, u):
    for b in rig.pose.bones:
        b.rotation_mode = "XYZ"
        b.rotation_euler, b.location = anim.pose(clipe, b.name, u, especie)
    bpy.context.view_layer.update()


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    saida = Path(args[0])
    saida.mkdir(parents=True, exist_ok=True)
    especies = args[1].split(",")
    pedidos = [(p.split(":")[0], float(p.split(":")[1])) for p in args[2].split(",")]
    for especie in especies:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / f"art_src/bestas_mar/besta_mar_{especie}.blend"))
        rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        rig.show_in_front = False
        rig.hide_render = True
        cams = preparar_cena()
        for clipe, u in pedidos:
            posar(rig, especie, clipe, u)
            for vista, cam in cams.items():
                bpy.context.scene.camera = cam
                bpy.context.scene.render.filepath = str(saida / f"{especie}_{clipe}_{u:.2f}_{vista}.png")
                bpy.ops.render.render(write_still=True)
        print("PREVIA_OK", especie, flush=True)


if __name__ == "__main__":
    main()
