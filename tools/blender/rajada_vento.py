"""Rajada de vento do Estilo de Combate Base (Z): tres meias-luas finas empilhadas ao longo da
direcao do soco, mais fios de ar atras. Voltada para -Z no glTF (+Y no Blender); largura da
meia-lua maior = 1 m (o jogo escala por 2 x raio do projetil). Uma malha so, `vento`: o jogo
pinta com material translucido.

Uso: blender -b -P tools/blender/rajada_vento.py
Saidas: art_src/blender/rajada_vento.blend e assets/models/vento/rajada.glb
"""
import bpy, bmesh, math, os
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()


def meia_lua(raio, largura, abertura, y0, espessura, passos=24):
    """Arco convexo para +Y; a ponta afina ate 0 nas duas pontas. Fatia horizontal, com espessura em Z."""
    fil = []
    for i in range(passos + 1):
        t = -abertura + 2 * abertura * i / passos
        afina = math.cos(t / abertura * math.pi / 2)            # 1 no meio, 0 nas pontas
        ext = (raio * math.sin(t), y0 + raio * math.cos(t))
        ine = (ext[0], ext[1] - largura * afina)
        fil.append((ext, ine, espessura * afina))
    cols = []
    for ext, ine, h in fil:
        cols.append([bm.verts.new((ext[0], ext[1], -h)), bm.verts.new((ext[0], ext[1], h)),
                     bm.verts.new((ine[0], ine[1], h)), bm.verts.new((ine[0], ine[1], -h))])
    for a, b in zip(cols, cols[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    for c in (cols[0], cols[-1]):
        bm.faces.new(c)


# a maior na frente, as menores empurradas atras (a rajada "abre" para a frente)
meia_lua(0.50, 0.16, math.radians(70), 0.30, 0.012)
meia_lua(0.40, 0.13, math.radians(66), -0.05, 0.010)
meia_lua(0.30, 0.10, math.radians(62), -0.36, 0.008)

# fios de ar atras: losangos finos e compridos
for x, y, c, e in [(-0.36, -0.55, 0.55, 0.012), (0.36, -0.55, 0.55, 0.012), (0.0, -0.75, 0.7, 0.014),
                   (-0.18, -0.95, 0.45, 0.010), (0.18, -0.95, 0.45, 0.010)]:
    p = [bm.verts.new(v) for v in [(x, y + c / 2, 0), (x + e, y, e), (x, y - c / 2, 0), (x - e, y, e),
                                   (x + e, y, -e), (x - e, y, -e)]]
    for f in [(0, 1, 3), (1, 2, 3), (0, 4, 1), (1, 4, 2), (0, 3, 5), (3, 2, 5), (2, 4, 5), (0, 5, 4)]:
        bm.faces.new([p[i] for i in f])

bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
malha = bpy.data.meshes.new("vento")
bm.to_mesh(malha)
bm.free()
obj = bpy.data.objects.new("vento", malha)
bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.shade_smooth()
print("RAJADA dims:", tuple(round(v, 3) for v in obj.dimensions))
os.makedirs(os.path.join(RAIZ, "art_src/blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(RAIZ, "art_src/blender/rajada_vento.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(RAIZ, "assets/models/vento/rajada.glb"),
                          export_format='GLB', export_apply=True, export_materials='NONE', export_yup=True)
