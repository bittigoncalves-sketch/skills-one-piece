# -*- coding: utf-8 -*-
"""
Gera o CHAPÉU DE PALHA em .glb — Skills One Piece.

Por que existir: o Gear 2 invoca o chapéu na cabeça do jogador. O pedido do dono
foi explícito — **modelar só o chapéu**, como acessório, e não um personagem novo
já com chapéu. Assim ele serve a QUALQUER personagem do elenco (Base, Buggy,
Nami, Ace) sem duplicar modelo, e some junto com a transformação.

Rodar:
    ~/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/chapeu_palha.py

Saída: assets/models/acessorios/chapeu_palha.glb

--------------------------------------------------------------------- EIXOS
O Godot usa Y para cima. O exportador glTF converte do Blender (Z para cima)
mapeando +Z(Blender) -> +Y(glTF).

Logo, AQUI: a vertical do chapéu é +Z.

--------------------------------------------------------------- A ORIGEM
⚠️ A origem fica na LINHA DE 2/3 DA CABEÇA — a altura em que a aba se apoia e a
copa começa a engolir o terço de cima. Não no centro geométrico, e não no topo
da cabeça (era assim na versão redonda, e por isso o chapéu ficava POUSADO em vez
de VESTIDO).

É o que torna o encaixe uma linha só no Godot: `chapeu.position.y = topo_da_cabeça`.
Origem no centro obrigaria a compensar meia altura na mão, e essa conta erra
silenciosamente quando o modelo muda de proporção. Mesma escolha das armas da
Buki (`buki_weapons.py`), pelo mesmo motivo.

--------------------------------------------------------------- PROPORÇÕES
⚠️ MEDIDAS TIRADAS DA CABEÇA DO JOGADOR, não escolhidas a olho. A AABB do nó
`Head` do `base.scn`, em unidades LOCAIS (que são as mesmas do chapéu, porque ele
é filho dela):

    posição (-0,250,  0,000, -0,370)
    tamanho ( 0,500,  0,500,  0,740)

Ou seja: 0,50 de largura, 0,50 de altura e 0,740 de PROFUNDIDADE — a cabeça é
quase 1,5× mais funda que larga, e um chapéu dimensionado só pela largura
flutuaria na frente e atrás.

**O terço de cima da cabeça vai de y=0,333 a y=0,500** (altura 0,167). A copa
envolve exatamente essa faixa e sobe mais um pouco: é o "incorporando 1/3 da
cabeça" que o dono pediu.

CAIXAS, não cilindros. A primeira versão era cilíndrica (16 lados) e destoava de
um personagem feito inteiro de caixas — o chapéu lia como peça de outro jogo.
"""

import bpy
import os
import math

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "acessorios")

# ------------------------------------------------------------------ MEDIDAS
# Todas em unidades LOCAIS da cabeça (ver PROPORÇÕES no topo).
CAB_L = 0.500      # largura da cabeça (X)
CAB_P = 0.740      # profundidade da cabeça (Z no jogo / Y no Blender)
CAB_A = 0.500      # altura da cabeça

TERCO = CAB_A / 3.0        # 0,167 — o que a copa engole
FOLGA = 0.030              # sobra da copa sobre a cabeça, para não haver z-fighting

ABA = 1.02                 # aba QUADRADA (X = Z), ~2× a largura da cabeça
ABA_ESP = 0.055            # espessura da aba
COPA_ALTURA = TERCO + 0.13 # engole o terço e ainda sobe
FITA_ESP = 0.07

# palha e fita — a fita VERMELHA é o que faz o chapéu ser o do Luffy e não um
# chapéu de palha qualquer. Sem ela a silhueta é genérica.
COR_PALHA = (0.88, 0.74, 0.42, 1.0)
COR_FITA = (0.72, 0.11, 0.11, 1.0)


def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(bloco):
            bloco.remove(item)


def material(nome, cor):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = cor
    # Rugosidade alta: palha não brilha, e o shader de cel do jogo desliga o
    # especular de qualquer forma (ver cel.gdshader).
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    return m


def caixa(nome, sx, sy, sz, z_base, mat):
    """Caixa apoiada em `z_base` (não centrada nele) — é o que deixa as peças
    empilharem sem cada uma exigir uma conta de meia altura."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, z_base + sz / 2.0))
    o = bpy.context.active_object
    o.name = nome
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


def construir():
    limpar()
    palha = material("Palha", COR_PALHA)
    fita = material("Fita", COR_FITA)

    partes = []

    # ---- ABA ----
    # Quadrada e plana, apoiada na ORIGEM. A origem é a linha de 2/3 da cabeça:
    # ver a nota da origem acima.
    partes.append(caixa("Aba", ABA, ABA, ABA_ESP, 0.0, palha))

    # ---- COPA ----
    # Envolve a cabeça com FOLGA nos quatro lados: ela precisa CONTER o terço de
    # cima, não encostar nele — encostar dá z-fighting entre as duas malhas.
    partes.append(caixa("Copa", CAB_L + FOLGA * 2.0, CAB_P + FOLGA * 2.0,
                        COPA_ALTURA, 0.0, palha))

    # ---- FITA ----
    # Um fio mais larga que a copa, pelo mesmo motivo de z-fighting. Fica logo
    # acima da aba, que é onde a fita de um chapéu de palha realmente fica.
    partes.append(caixa("Fita", CAB_L + FOLGA * 2.0 + 0.02, CAB_P + FOLGA * 2.0 + 0.02,
                        FITA_ESP, ABA_ESP, fita))

    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    chapeu = bpy.context.active_object
    chapeu.name = "ChapeuPalha"

    # A origem JÁ está em z=0 (o apoio) porque cada peça foi apoiada a partir
    # dali. Nada de `origin_set`, que a moveria para o centro geométrico.
    return chapeu


def exportar(obj):
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, "chapeu_palha.glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=caminho,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print("\n[chapeu] %s  (%d vertices, %d faces)"
          % (caminho, len(obj.data.vertices), len(obj.data.polygons)))
    d = obj.dimensions
    print("[chapeu] X=%.3f Y=%.3f Z=%.3f  (Y=profundidade, Z=vertical no Blender)"
          % (d.x, d.y, d.z))
    zs = [v.co.z for v in obj.data.vertices]
    print("[chapeu] z de %.3f a %.3f — apoio em 0,000 (a linha de 2/3 da cabeca)"
          % (min(zs), max(zs)))
    print("[chapeu] a copa engole %.3f de cabeca (o terco e %.3f)"
          % (TERCO, TERCO))


if __name__ == "__main__":
    exportar(construir())
