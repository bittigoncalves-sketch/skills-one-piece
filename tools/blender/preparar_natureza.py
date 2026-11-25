"""PREPARAR A NATUREZA PARA A LOJA (01/10/2026).

    ~/opt/blender/blender -b --python tools/blender/preparar_natureza.py -- \
        "<free_download_low_poly_nature_pack.glb>" "<pasta Free Forest Nature Pack>" art_src/natureza

Pedido do dono: árvores novas e frutas grudadas nelas (pacote "low poly nature pack", tudo
num GLB só: 6 frutas + 5 famílias de árvore em estágios de crescimento + tocos) e os
complementos de floresta do "Free Forest Nature Pack" (árvores, arbustos, pedras,
cogumelos, grama, extras).

Saída em <saida>/: um .glb por modelo + manifesto.json (lido por
tools/mapa_ilha/importar_natureza_na_loja.gd). Para cada modelo:
  • ÁRVORE: malha `Colisao` = cilindro de 8 lados só no TRONCO (folhagem não colide:
    colisão densa custa milissegundos a quem encosta — a plantação, 01/10/2026);
  • ÁRVORE FRUTÍFERA adulta: vazios `Fruta_0..4` na SUPERFÍCIE da copa (raio de fora
    para dentro contra a malha), onde o jogo pendura as frutas;
  • fruta, grama, flor, cogumelo, arbusto: sem colisão (o importador marca atravessável);
  • pedra, toco, tronco caído: colidem pela própria malha (poucos triângulos).
O tamanho no jogo NÃO é aplicado aqui: o manifesto leva o fator e o importador grava o
tamanho padrão da loja.
"""

import glob
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
PACOTE, PASTA_FF, SAIDA = args[0], args[1], args[2]
os.makedirs(SAIDA, exist_ok=True)
random.seed(20261001)

PONTOS_DE_FRUTA = 5
FATOR_FF = 0.45          # Free Forest em unidades exageradas (grama de 2 m)

# ------------------------------------------------------------------ pacote
# nome do vazio no GLB -> (id, nome, tipo, família, altura alvo em m | None = fator da família)
PECAS = {
    # 0,45 m: estilizado de propósito — com 0,3 m a fruta sumia na copa vista do chão
    # (captura de 01/10/2026).
    "ACCORN": ("fruta_bolota", "Bolota", "fruta", "", 0.45),
    "APPLE ": ("fruta_maca", "Maçã", "fruta", "", 0.45),
    "CHERRY": ("fruta_cereja", "Cereja", "fruta", "", 0.48),
    "ORANGE": ("fruta_laranja", "Laranja", "fruta", "", 0.45),
    "PEACH": ("fruta_pessego", "Pêssego", "fruta", "", 0.45),
    "PINE": ("fruta_pinha", "Pinha", "fruta", "", 0.48),
    "Newborn": ("arvore_verde_broto", "Árvore verde — broto", "arvore", "verde", 0.8),
    "sprout.001": ("arvore_verde_muda", "Árvore verde — muda", "arvore", "verde", 2.5),
    "MidGrow.001": ("arvore_verde_jovem", "Árvore verde — jovem", "arvore", "verde", 4.5),
    "Full Grow.001": ("arvore_verde_adulta", "Árvore verde (frutífera)", "arvore", "verde", 7.0),
    "Cut": ("toco_arvore_verde", "Toco de árvore verde", "toco", "verde", None),
    "Newborn.001": ("pinheiro_broto", "Pinheiro — broto", "arvore", "pinheiro", 0.8),
    "sprout.003": ("pinheiro_muda", "Pinheiro — muda", "arvore", "pinheiro", 2.5),
    "MidGrow.003": ("pinheiro_jovem", "Pinheiro — jovem", "arvore", "pinheiro", 5.0),
    "Full Grow.003": ("pinheiro_adulto", "Pinheiro (dá pinha)", "arvore", "pinheiro", 10.0),
    "Cut.001": ("toco_pinheiro", "Toco de pinheiro", "toco", "pinheiro", None),
    "Newborn.002": ("cerejeira_broto", "Cerejeira — broto", "arvore", "cerejeira", 0.8),
    "sprout.004": ("cerejeira_muda", "Cerejeira — muda", "arvore", "cerejeira", 2.2),
    "MidGrow.004": ("cerejeira_jovem", "Cerejeira — jovem", "arvore", "cerejeira", 4.0),
    "MidGrow.005": ("cerejeira_adulta", "Cerejeira (dá cereja)", "arvore", "cerejeira", 6.5),
    "MidGrow.006": ("toco_cerejeira", "Toco de cerejeira", "toco", "cerejeira", None),
    "Newborn.003": ("palmeira_broto", "Palmeira — broto", "arvore", "palmeira", 0.8),
    "Newborn.004": ("palmeira_broto_alto", "Palmeira — broto alto", "arvore", "palmeira", 1.1),
    "Cylinder": ("palmeira_muda", "Palmeira — muda", "arvore", "palmeira", 2.5),
    "Cylinder.001": ("palmeira_jovem", "Palmeira — jovem", "arvore", "palmeira", 5.0),
    "Cylinder.002": ("palmeira_adulta", "Palmeira (nova)", "arvore", "palmeira", 8.5),
    "Cylinder.003": ("toco_palmeira", "Toco de palmeira", "toco", "palmeira", None),
    "Full Grow.004": ("arvore_gigante", "Árvore gigante (dá bolota)", "arvore", "gigante", 12.0),
}
# Quais adultas dão fruta, e qual (uma espécie por árvore; decisão do dono).
FRUTIFERAS = {
    "arvore_verde_adulta": ["fruta_maca", "fruta_laranja", "fruta_pessego"],
    "cerejeira_adulta": ["fruta_cereja"],
    "pinheiro_adulto": ["fruta_pinha"],
    "arvore_gigante": ["fruta_bolota"],
}
ADULTAS = {"verde": "arvore_verde_adulta", "pinheiro": "pinheiro_adulto", "cerejeira": "cerejeira_adulta",
           "palmeira": "palmeira_adulta", "gigante": "arvore_gigante"}

# Free Forest: pasta -> tipo (o resto é árvore)
TIPO_FF = {"Bushes": "arbusto", "Grass": "grama", "Mushrooms": "cogumelo", "Rocks": "pedra"}
EXTRAS_FF = {"Flat_Fallen_Log": "tronco_caido", "Flat_Flowers_red": "flor", "Flat_Forest_Ground": "chao",
             "Flat_Tree_Stump": "toco"}
NOMES_FF = {
    "Birch": "Bétula", "Cypress": "Cipreste", "Oak": "Carvalho", "Elm": "Olmo", "Maple": "Bordo vermelho",
    "Windswept": "Árvore do vento", "Mistletoe": "Árvore com visco", "Park": "Árvore de parque",
    "Pine": "Pinheiro alto", "Simple": "Árvore simples", "Spruce": "Abeto", "Bush": "Arbusto",
    "Grass": "Capim", "Mushroom": "Cogumelo", "Boulder": "Rochedo", "Rock": "Pedra", "Fallen": "Tronco caído",
    "Flowers": "Flores vermelhas", "Forest": "Chão de floresta", "Stump": "Toco grande",
}
TAMANHOS_FF = {"small": "pequeno", "medium": "médio", "large": "grande", "hero": "enorme"}


# ------------------------------------------------------------------ apoio
def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def malhas_de(raiz):
    return [o for o in [raiz] + list(raiz.children_recursive) if o.type == "MESH"]


def caixa(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def vertices_mundo(objs, filtro_material=None):
    pts = []
    for o in objs:
        me = o.data
        for p in me.polygons:
            if filtro_material is not None:
                m = me.materials[p.material_index] if p.material_index < len(me.materials) else None
                if not filtro_material(m.name if m else ""):
                    continue
            pts.extend(o.matrix_world @ me.vertices[i].co for i in p.vertices)
    return pts


def eh_tronco(nome):
    n = nome.lower()
    return any(k in n for k in ("trunk", "bark", "wood"))


def cilindro_de_tronco(objs, lo, hi, altura_tronco=None):
    """Malha `Colisao`: cilindro de 8 lados no tronco, do chão até onde a copa começa."""
    tronco = vertices_mundo(objs, eh_tronco)
    altura = hi.z - lo.z
    base = [p for p in (tronco or vertices_mundo(objs)) if p.z < lo.z + altura * 0.12]
    if not base:
        base = vertices_mundo(objs)
    cx = sum(p.x for p in base) / len(base)
    cy = sum(p.y for p in base) / len(base)
    raio = max(0.08, sorted(math.hypot(p.x - cx, p.y - cy) for p in base)[int(len(base) * 0.8)] * 0.85)
    if altura_tronco is None:
        copa = vertices_mundo(objs, lambda n: not eh_tronco(n)) if tronco else []
        topo = min((p.z for p in copa), default=lo.z + altura * 0.35)
        altura_tronco = max(topo - lo.z, altura * 0.2)
    altura_tronco = min(altura_tronco, altura)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=raio, radius2=raio * 0.85, depth=altura_tronco)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((cx, cy, lo.z + altura_tronco * 0.5)))
    me = bpy.data.meshes.new("Colisao")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Colisao", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, raio, altura_tronco


def pontos_na_copa(objs, lo, hi, quantos, raio_fruta):
    """Pontos na SUPERFÍCIE de fora da copa: raio de fora para dentro contra a malha."""
    bm = bmesh.new()
    for o in objs:
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        tmp.transform(o.matrix_world)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    bvh = BVHTree.FromBMesh(bm)
    altura = hi.z - lo.z
    centro = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z + altura * 0.62))
    alcance = (hi - lo).length
    candidatos = []
    for k in range(48):
        az = (k / 48) * math.tau + random.uniform(-0.1, 0.1)
        # Faixa média-baixa da copa: é a que se vê de baixo (fruta no topo ninguém vê).
        el = math.radians(random.uniform(-30, 15))
        d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        hit, normal, _i, _d = bvh.ray_cast(centro + d * alcance, -d, alcance * 2)
        if hit is None or hit.z < lo.z + altura * 0.3:
            continue
        candidatos.append(hit + d * raio_fruta * 0.6)     # meio para fora da folhagem
    bm.free()
    escolhidos = []
    random.shuffle(candidatos)
    distancia = max(0.4, altura * 0.18)
    for c in candidatos:
        if all((c - e).length >= distancia for e in escolhidos):
            escolhidos.append(c)
        if len(escolhidos) == quantos:
            break
    return escolhidos


def exportar(raiz, extras, caminho):
    bpy.ops.object.select_all(action="DESELECT")
    for o in [raiz] + list(raiz.children_recursive) + extras:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB", use_selection=True)


def tris(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


manifesto = []

# ------------------------------------------------- 1. o pacote (um GLB só)
limpar()
bpy.ops.import_scene.gltf(filepath=PACOTE)
raiz_cena = next(o for o in bpy.data.objects if o.name.startswith("GLTF_SceneRootNode"))
pecas = list(raiz_cena.children)
# Solta cada peça da hierarquia do Sketchfab mantendo a posição no mundo.
for p in pecas:
    mw = p.matrix_world.copy()
    p.parent = None
    p.matrix_world = mw
for o in list(bpy.data.objects):
    if o not in pecas and not any(o in p.children_recursive for p in pecas):
        bpy.data.objects.remove(o, do_unlink=True)

alturas_arquivo = {}
for p in pecas:
    chave = p.name.rsplit("_", 1)[0]
    if chave not in PECAS:
        print("IGNORADO", p.name)
        continue
    lo, hi = caixa(malhas_de(p))
    alturas_arquivo[PECAS[chave][0]] = hi.z - lo.z

for p in pecas:
    chave = p.name.rsplit("_", 1)[0]
    if chave not in PECAS:
        continue
    pid, nome, tipo, familia, alvo = PECAS[chave]
    objs = malhas_de(p)
    lo, hi = caixa(objs)
    # Base no chão e centrada: o importador mede a caixa, mas a origem limpa ajuda a
    # quem abrir o .glb.
    deslocar = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z if tipo != "fruta" else -(lo.z + hi.z) / 2))
    p.matrix_world.translation += deslocar
    bpy.context.view_layer.update()
    lo, hi = caixa(objs)
    altura = hi.z - lo.z
    if alvo is None:                 # toco: o fator da adulta da família
        fator = PECAS_ALVO = None
        adulta = ADULTAS[familia]
        alvo_adulta = next(v[4] for v in PECAS.values() if v[0] == adulta)
        fator = alvo_adulta / alturas_arquivo[adulta]
    else:
        fator = alvo / (altura if tipo != "fruta" else max(hi.x - lo.x, hi.y - lo.y, altura))
    extras = []
    colisao = "nenhuma"
    pontos = 0
    if tipo == "arvore":
        ob, raio, alt = cilindro_de_tronco(objs, lo, hi, altura * 0.35)
        ob.parent = p
        ob.matrix_parent_inverse = p.matrix_world.inverted()
        colisao = "tronco"
        if pid in FRUTIFERAS:
            raio_fruta = 0.45 / fator     # 0,45 m no jogo, em unidades do arquivo
            for i, ponto in enumerate(pontos_na_copa(objs, lo, hi, PONTOS_DE_FRUTA, raio_fruta)):
                v = bpy.data.objects.new("Fruta_%d" % i, None)
                bpy.context.scene.collection.objects.link(v)
                v.location = ponto
                v.parent = p
                v.matrix_parent_inverse = p.matrix_world.inverted()
                pontos += 1
    elif tipo == "toco":
        colisao = "malha"
    exportar(p, extras, os.path.join(SAIDA, pid + ".glb"))
    manifesto.append({"id": pid, "nome": nome, "tipo": tipo, "familia": familia, "fator": fator,
                      "colisao": colisao, "frutas": FRUTIFERAS.get(pid, []), "pontos_de_fruta": pontos,
                      "triangulos": tris(objs), "altura_jogo": round(altura * fator, 2),
                      "origem": "low_poly_nature_pack"})
    print("PECA %-22s %-6s altura no jogo %.2f m  colisão %-7s pontos de fruta %d" % (
        pid, tipo, altura * fator, colisao, pontos))

# ------------------------------------------------- 2. Free Forest (um GLB por arquivo)
for f in sorted(glob.glob(os.path.join(PASTA_FF, "**", "*.glb"), recursive=True)):
    if "__MACOSX" in f:
        continue
    pasta = os.path.relpath(f, PASTA_FF).split(os.sep)[0]
    base = os.path.splitext(os.path.basename(f))[0]
    tipo = EXTRAS_FF.get(base, TIPO_FF.get(pasta, "arvore"))
    limpar()
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    raiz = next((o for o in bpy.data.objects if o.parent is None), objs[0])
    if len([o for o in bpy.data.objects if o.parent is None]) > 1:
        raiz = bpy.data.objects.new(base, None)
        bpy.context.scene.collection.objects.link(raiz)
        for o in list(bpy.data.objects):
            if o.parent is None and o is not raiz:
                mw = o.matrix_world.copy()
                o.parent = raiz
                o.matrix_world = mw
    lo, hi = caixa(objs)
    colisao = {"arvore": "tronco", "pedra": "malha", "toco": "malha", "tronco_caido": "malha"}.get(tipo, "nenhuma")
    if tipo == "arvore":
        ob, _r, _a = cilindro_de_tronco(objs, lo, hi)
        ob.parent = raiz
        ob.matrix_parent_inverse = raiz.matrix_world.inverted()
    pid = "floresta_" + base.lower().replace("flat_", "")
    partes = base.replace("Flat_", "").split("_")
    nome = next((NOMES_FF[k] for k in NOMES_FF if k in partes), " ".join(partes))
    tam = next((TAMANHOS_FF[t] for t in TAMANHOS_FF if t in [x.lower() for x in partes]), "")
    if "Red" in partes and "Mushroom" in partes:
        nome += " vermelho"
    if tam:
        nome += " " + tam
    nome += " (floresta)"
    exportar(raiz, [], os.path.join(SAIDA, pid + ".glb"))
    manifesto.append({"id": pid, "nome": nome, "tipo": tipo, "familia": pasta.strip(), "fator": FATOR_FF,
                      "colisao": colisao, "frutas": [], "pontos_de_fruta": 0, "triangulos": tris(objs),
                      "altura_jogo": round((hi.z - lo.z) * FATOR_FF, 2), "origem": "free_forest_nature_pack"})
    print("FF   %-38s %-12s altura no jogo %.2f m  colisão %s" % (pid, tipo, (hi.z - lo.z) * FATOR_FF, colisao))

with open(os.path.join(SAIDA, "manifesto.json"), "w") as fp:
    json.dump({"_leia": "Gerado por tools/blender/preparar_natureza.py; lido por "
               "tools/mapa_ilha/importar_natureza_na_loja.gd.", "modelos": manifesto}, fp, indent=1,
              ensure_ascii=False)
print("NATUREZA_PRONTA %d modelos" % len(manifesto))
