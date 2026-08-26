# -*- coding: utf-8 -*-
"""
PREPARA A ÁRVORE DO MESHY PARA O JOGO.

    blender --background --python tools/blender/preparar_arvore.py

Entra:  ~/Downloads/arvore3Dparaonepiecevoxel.glb  (saída crua do Meshy AI)
Sai:    assets/models/arvore_voxel.glb             (pronta para o Godot)

------------------------------------------------------------------ O PROBLEMA
O modelo do Meshy é bonito e leve (3.140 triângulos), mas chega no formato de
uma VITRINE, não de um asset de jogo. Quatro coisas o separam de ser usável:

1. **Pivô no centro.** A caixa vai de Z −0,5 a +0,5. Plantar isso no chão
   enterra metade da árvore. Pivô de asset de jogo fica na BASE.
2. **Escala unitária.** Mede 1 m. A árvore que ela substitui tem ~6,4 m.
3. **Malha única.** Tronco e copa são o mesmo objeto, com um material só.
4. **8,3 MB de textura** — três mapas 2048² (base_color, normal,
   metallic_roughness) para uma árvore que aparece dezenas de vezes no mapa.

-------------------------------------------- O PROBLEMA DE VERDADE: A COR
E há um quinto, que é o que decide o desenho deste script.

**Cada fruta tem a cor da própria árvore**, declarada em
`TreeAndFruitGenerator._todas_as_definicoes()`: a Mera Mera é copa laranja-fogo
sobre tronco ébano, a Hie Hie é azul-gelo sobre cinza glacial, a Yami Yami é
roxo-trevas sobre obsidiana. É assim que o jogador acha a fruta que quer do
outro lado do mapa.

Trocar as nove árvores por uma cópia verde idêntica ganharia forma e **perderia
essa leitura** — o jogador teria de chegar perto de cada árvore para saber qual
é. Não foi isso que o dono pediu; ele pediu a árvore no lugar das atuais.

Então: fica a FORMA do Meshy e ficam as CORES do jogo. Para isso, duas coisas:

  • **separar tronco e copa em objetos distintos**, para cada um receber a sua
    cor. A separação é feita amostrando a textura no centro de cada face:
    verde dominante = copa, o resto = tronco;
  • **converter a textura para TONS DE CINZA normalizado**. Isto é o pulo do
    gato: o Godot multiplica `albedo_texture × albedo_color`. Textura verde ×
    tinta laranja dá um marrom sujo; textura CINZA × tinta laranja dá laranja
    com todo o relevo de voxel preservado.

A normalização (média do cinza puxada para ~0,85) existe porque multiplicar por
um cinza de 0,4 escureceria toda cor aplicada.

------------------------------------------------------------------- TEXTURAS
Fica só a base_color, em 1024². Saem a normal e a metallic_roughness:

  • a `metallic_roughness` de uma árvore fosca não carrega informação;
  • a `normal` desenha relevo por sombreamento suave — que é exatamente o que
    o alvo de cel-shading (ver `docs/PLANO_VISUAL.md`) quer eliminar.

De 8,3 MB para uma fração, sem perder o que se vê.
"""

import bpy, os, sys, math
import numpy as np
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENTRADA = os.path.expanduser("~/Downloads/arvore3Dparaonepiecevoxel.glb")
SAIDA = os.path.join(RAIZ, "assets", "models", "arvore_voxel.glb")

ALTURA_ALVO = 6.4        # a árvore de caixas que ela substitui mede isto
LADO_TEXTURA = 1024
CINZA_ALVO = 0.85        # média do cinza depois de normalizar


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def img_para_np(img):
    px = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(img.size[1], img.size[0], 4)


def base_color_da_cena():
    for img in bpy.data.images:
        if "base_color" in img.name.lower() or "basecolor" in img.name.lower():
            return img
    # fallback: a maior imagem
    return max((i for i in bpy.data.images if i.size[0] > 0),
               key=lambda i: i.size[0] * i.size[1], default=None)


def classificar_faces(obj, arr):
    """Devolve o conjunto de índices de face que são COPA.

    O critério é a cor da textura no centro da face: verde dominante = folha.
    Amostrar no CENTRO e não nos vértices é de propósito — vértice fica na
    fronteira entre folha e galho e vota errado."""
    me = obj.data
    h, w, _ = arr.shape
    uvs = me.uv_layers.active.data
    copa = set()
    for poly in me.polygons:
        u = v = 0.0
        for li in poly.loop_indices:
            uv = uvs[li].uv
            u += uv.x; v += uv.y
        n = len(poly.loop_indices)
        u /= n; v /= n
        px = int(np.clip(u * (w - 1), 0, w - 1))
        py = int(np.clip(v * (h - 1), 0, h - 1))
        r, g, b = arr[py, px, 0], arr[py, px, 1], arr[py, px, 2]
        # verde dominante sobre os dois outros canais, com folga
        if g > r * 1.15 and g > b * 1.15:
            copa.add(poly.index)
    return copa


def main():
    if not os.path.exists(ENTRADA):
        print("✗ não achei", ENTRADA); sys.exit(1)
    limpar()
    bpy.ops.import_scene.gltf(filepath=ENTRADA)
    malhas = [o for o in bpy.data.objects if o.type == 'MESH']
    if len(malhas) != 1:
        print("✗ esperava 1 malha, achei", len(malhas)); sys.exit(2)
    obj = malhas[0]
    obj.name = "Arvore"
    print("entrada: %d verts, %d polígonos" % (len(obj.data.vertices), len(obj.data.polygons)))

    # ---------------------------------------------------------- 1. a textura
    img = base_color_da_cena()
    if img is None:
        print("✗ sem base_color"); sys.exit(3)
    arr = img_para_np(img)
    print("base_color: %dx%d" % (img.size[0], img.size[1]))

    copa = classificar_faces(obj, arr)
    print("faces: %d copa / %d tronco" % (len(copa), len(obj.data.polygons) - len(copa)))
    if not copa or len(copa) == len(obj.data.polygons):
        print("✗ a classificação não separou nada — critério de verde falhou"); sys.exit(4)

    # ------------------------------------------- 2. cinza normalizado, 1024²
    lum = 0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]
    media = float(lum.mean())
    lum = np.clip(lum * (CINZA_ALVO / max(media, 1e-4)), 0.0, 1.0)
    print("cinza: média %.3f -> %.3f" % (media, float(lum.mean())))
    # reamostra por passo inteiro (nearest): é voxel, não quer suavização
    passo = max(1, img.size[0] // LADO_TEXTURA)
    lum_s = lum[::passo, ::passo]
    h2, w2 = lum_s.shape
    nova = bpy.data.images.new("arvore_cinza", w2, h2, alpha=False)
    saida = np.empty((h2, w2, 4), dtype=np.float32)
    saida[..., 0] = saida[..., 1] = saida[..., 2] = lum_s
    saida[..., 3] = 1.0
    nova.pixels.foreach_set(saida.reshape(-1))
    nova.update()
    print("textura de saída: %dx%d" % (w2, h2))

    # ----------------------------------------------- 3. dois objetos, 2 mats
    for m in list(obj.data.materials):
        obj.data.materials.clear()
    mat_folha = bpy.data.materials.new("Folhagem")
    mat_tronco = bpy.data.materials.new("Tronco")
    for mat in (mat_folha, mat_tronco):
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = nova
        tex.interpolation = 'Closest'          # voxel: nada de suavizar
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.append(mat_folha)       # slot 0
    obj.data.materials.append(mat_tronco)      # slot 1
    for poly in obj.data.polygons:
        poly.material_index = 0 if poly.index in copa else 1

    # ⚠️ SEPARA POR MATERIAL, não por seleção.
    #
    # A primeira versão marcava `poly.select` e chamava `separate(type='SELECTED')`.
    # Não funciona: ao entrar em modo de edição o Blender REDERIVA a seleção a
    # partir dos vértices, e vértice na fronteira entre folha e galho arrasta a
    # face vizinha junto. Resultado medido: um objeto saiu com os DOIS materiais
    # misturados ({0, 1}) em vez de um de cada.
    #
    # `separate(type='MATERIAL')` usa o índice de material da face, que é
    # exatamente o que a classificação escreveu. Sem fronteira, sem propagação.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')

    # ⚠️ IDENTIFICA PELO NOME DO MATERIAL, não pelo índice.
    # Depois de `separate`, cada objeto fica só com os materiais que usa, e o
    # índice é RENUMERADO — os dois passam a reportar `{0}`. Checar índice aqui
    # dava "a separação não deu dois objetos limpos" com a separação perfeita.
    partes = [o for o in bpy.data.objects if o.type == 'MESH']
    tronco, folhagem = None, None
    for o in partes:
        nomes = {m.name for m in o.data.materials if m}
        if nomes == {"Folhagem"}:
            folhagem = o
        elif nomes == {"Tronco"}:
            tronco = o
    if folhagem is None or tronco is None:
        print("✗ a separação não deu dois objetos limpos:",
              [(o.name, [m.name for m in o.data.materials if m]) for o in partes])
        sys.exit(5)
    folhagem.name = "Folhagem"
    tronco.name = "Tronco"
    for o, mat in ((folhagem, mat_folha), (tronco, mat_tronco)):
        o.data.materials.clear()
        o.data.materials.append(mat)
    print("separado: Folhagem %d polígonos | Tronco %d" % (
        len(folhagem.data.polygons), len(tronco.data.polygons)))

    # --------------------------------------- 4. pivô na base e escala do jogo
    todos = [folhagem, tronco]
    zs = [(o.matrix_world @ v.co).z for o in todos for v in o.data.vertices]
    z_min, z_max = min(zs), max(zs)
    escala = ALTURA_ALVO / (z_max - z_min)
    raiz = bpy.data.objects.new("ArvoreVoxel", None)
    bpy.context.collection.objects.link(raiz)
    for o in todos:
        o.parent = raiz
    raiz.scale = (escala, escala, escala)
    raiz.location = (0.0, 0.0, -z_min * escala)   # base em Z = 0
    bpy.context.view_layer.update()
    zs2 = []
    for o in todos:
        o_ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        zs2 += [(o_ev.matrix_world @ v.co).z for v in o_ev.data.vertices]
    print("altura final: %.3f m  (base em Z = %.4f)" % (max(zs2) - min(zs2), min(zs2)))

    # ------------------------------------------------------------ 5. exportar
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=SAIDA, export_format='GLB',
                              use_selection=True, export_apply=True,
                              export_image_format='JPEG')
    print("✓ %s  (%.2f MB)" % (SAIDA, os.path.getsize(SAIDA) / 1e6))


main()
