"""SIMPLIFICAR O CAVALO DA VILA (01/10/2026).

    ~/opt/blender/blender -b --python tools/blender/simplificar_cavalo.py -- \
        mapas/modelos/animals__farm__horse_1__base.glb art_src/cavalo/cavalo_leve.glb

Decisão do dono: o cavalo posto na vila (`animals__farm__horse_1__base`, sculpt do
Sketchfab) tinha 751.792 triângulos — mais que todas as construções da ilha juntas.
Reduz mantendo a aparência, num arquivo NOVO (o original fica na loja).

O que faz, e por quê:
  1. JUNTA os pedaços da mesma malha (o glTF corta malhas em 65 mil vértices: o corpo
     veio em 5 pedaços) e solda as emendas — reduzir cada pedaço sozinho abre fresta
     entre eles;
  2. reduz por TAMANHO: peça grande (corpo, crina) até ~4 mil triângulos ou 4 %,
     média a 30 %, pequena (olhos, cascos) intacta — olho reduzido vira borrão;
  3. a cor é POR VÉRTICE (sem textura): o "collapse" interpola a cor, e menos vértices
     é menos detalhe de pintura — por isso o corpo fica com mais triângulos que o
     resto (conferido em foto lado a lado no Godot);
  4. cria a malha `Colisao` (casca convexa simplificada): sem ela, um modelo abaixo de
     150 mil triângulos colide pela malha inteira, e colisão densa custa milissegundos
     por quadro a quem encosta (a plantação, 01/10/2026).
"""

import sys
from collections import defaultdict

import bmesh
import bpy

args = sys.argv[sys.argv.index("--") + 1:]
ORIGEM, DESTINO = args[0], args[1]

PEQUENA = 5000          # abaixo disto: intacta
MEDIA = 20000           # abaixo disto: 30 %
ALVO_GRANDE = 4000      # grande: até isto de triângulos...
RAZAO_MINIMA = 0.04     # ...mas nunca menos de 4 % do que tinha
CASCA_TRIANGULOS = 160


def triangulos(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def ativar(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ORIGEM)
malhas = [o for o in bpy.data.objects if o.type == "MESH"]
antes = sum(triangulos(o) for o in malhas)

# 1. Pedaços da mesma malha: mesmo pai e mesmos materiais.
grupos = defaultdict(list)
for o in malhas:
    grupos[(o.parent.name if o.parent else "", tuple(m.name for m in o.data.materials if m))].append(o)
for objs in grupos.values():
    if len(objs) < 2:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bm = bmesh.new()
    bm.from_mesh(objs[0].data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(objs[0].data)
    bm.free()
    print("JUNTOU %d pedaços em %s" % (len(objs), objs[0].name))

# 2. Redução por tamanho.
malhas = [o for o in bpy.data.objects if o.type == "MESH"]
for o in malhas:
    n = triangulos(o)
    if n < PEQUENA:
        continue
    razao = 0.3 if n < MEDIA else max(RAZAO_MINIMA, ALVO_GRANDE / n)
    ativar(o)
    mod = o.modifiers.new("Reduzir", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = razao
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print("REDUZIU %s: %d -> %d" % (o.name, n, triangulos(o)))

# 3. Casca convexa como colisão, no espaço do MUNDO (raiz da cena).
pontos = []
for o in malhas:
    m = o.matrix_world
    pontos.extend(m @ v.co for v in o.data.vertices)
bm = bmesh.new()
for p in pontos:
    bm.verts.new(p)
bmesh.ops.convex_hull(bm, input=bm.verts)
# Os pontos de dentro da casca sobram soltos (sem face): fora.
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
malha_colisao = bpy.data.meshes.new("Colisao")
bm.to_mesh(malha_colisao)
bm.free()
colisao = bpy.data.objects.new("Colisao", malha_colisao)
bpy.context.scene.collection.objects.link(colisao)
n = triangulos(colisao)
if n > CASCA_TRIANGULOS:
    ativar(colisao)
    mod = colisao.modifiers.new("Reduzir", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = CASCA_TRIANGULOS / n
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("COLISAO casca convexa: %d triângulos" % triangulos(colisao))

depois = sum(triangulos(o) for o in malhas)
bpy.ops.export_scene.gltf(filepath=DESTINO, export_format="GLB")
print("CAVALO_SIMPLIFICADO %d -> %d triângulos (%.1fx), colisão %d" % (antes, depois, antes / max(depois, 1),
                                                                     triangulos(colisao)))
