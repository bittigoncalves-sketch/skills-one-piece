# -*- coding: utf-8 -*-
"""
Acessórios de CABEÇA e ROSTO, em .glb — Skills One Piece.

Rodar:
    ~/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/acessorios_cabeca.py

Saída: assets/models/acessorios/{aureola,coroa,cartola,
                                 mascara_caveira,mascara_peste,mascara_covid}.glb

Reproduz a folha de design 2D do dono (`imagens para designs/acessórioscabeça.png`):
seis peças voxel sobre uma cabeça cúbica azul. Três assentam no TOPO (auréola,
coroa, cartola) e três cobrem o ROSTO (caveira, peste, covid) — daí serem duas
partes do corpo no catálogo, e não uma, para chapéu e máscara poderem conviver.

--------------------------------------------------------------------- EIXOS
Mesma convenção de `acessorios.py`. O exportador glTF mapeia
+Z(Blender) -> +Y(glTF) e +Y(Blender) -> −Z(glTF). Logo, AQUI:

    Blender X = largura
    Blender Y = FRENTE do personagem   (vira −Z no jogo)
    Blender Z = para cima              (vira +Y no jogo)

------------------------------------------------------------- AS MEDIDAS
Da AABB LOCAL do nó `Head` do `base.scn` — as mesmas unidades da peça, que
entra como filha dele:

    posição (-0,250,  0,000, -0,370)
    tamanho ( 0,500,  0,500,  0,740)

⚠️ A cabeça é quase 1,5× MAIS FUNDA que larga (0,740 contra 0,500). Uma coroa
ou cartola dimensionada só pela largura deixaria a testa e a nuca de fora — foi
o que a nota do `chapeu_palha.py` já registrava.

--------------------------------------------------------------- A ORIGEM
Cada peça tem a origem no PONTO DE ENCAIXE, não no centro:

    topo  -> origem no centro do TOPO da cabeça, peça cresce para +Z
    rosto -> origem no centro da FACE FRONTAL, peça cresce para +Y

Assim o catálogo posiciona por âncora (0..1 na AABB do nó) sem compensar meia
altura na mão — conta que erra em silêncio quando o modelo muda de proporção.

--------------------------------------------------------------- O ESTILO
Só caixas. A auréola é o caso que mais tenta a fugir disso: na folha ela é um
anel, e anel pede cilindro. Aqui ela é um polígono de 16 caixas alinhadas aos
eixos — é o serrilhado voxel que aparece no desenho, e é o que mantém a peça no
mesmo mundo de um personagem feito inteiro de caixas.
"""

import bpy
import os
import math

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "acessorios")

# Cabeça, em unidades locais (ver AS MEDIDAS no topo).
CAB_L, CAB_A, CAB_P = 0.500, 0.500, 0.740
FRENTE = CAB_P * 0.5          # +0,370: onde fica a face do rosto

COR = {
    "ouro":       (0.93, 0.72, 0.15, 1.0),
    "ouro_claro": (0.99, 0.85, 0.35, 1.0),
    "rubi":       (0.80, 0.12, 0.14, 1.0),
    "safira":     (0.18, 0.45, 0.80, 1.0),
    "preto":      (0.07, 0.07, 0.09, 1.0),
    "preto_couro":(0.13, 0.12, 0.14, 1.0),
    "vermelho":   (0.72, 0.10, 0.12, 1.0),
    "osso":       (0.94, 0.94, 0.91, 1.0),
    "branco":     (0.97, 0.97, 0.98, 1.0),
    "cinza":      (0.82, 0.83, 0.85, 1.0),
    "halo":       (1.00, 0.85, 0.15, 1.0),
}


def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(bloco):
            bloco.remove(item)


def material(nome, cor):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = cor
    b.inputs["Roughness"].default_value = 0.95
    if "Metallic" in b.inputs:
        b.inputs["Metallic"].default_value = 0.0
    return m


def caixa(nome, tam, centro, cor, rot=(0.0, 0.0, 0.0)):
    """`tam` e `centro` em (X, Y=frente, Z=cima)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro, rotation=rot)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material(nome.split(".")[0] + "_" + str(cor[0])[:4], cor))
    return o


def juntar(partes, nome):
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = nome
    return o


def exportar(obj, arquivo):
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, arquivo + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    d = obj.dimensions
    print("[cabeca] %-18s %3d verts  X=%.3f Y=%.3f Z=%.3f"
          % (arquivo, len(obj.data.vertices), d.x, d.y, d.z))


# ============================================================= TOPO DA CABEÇA
def aureola():
    """Origem no TOPO da cabeça; o anel PAIRA acima, sem encostar.

    16 caixas alinhadas aos eixos, num círculo achatado. Alinhadas de propósito:
    girar cada segmento para tangenciar daria um anel liso, que é justamente o
    que a folha 2D não mostra.
    """
    limpar()
    p = []
    raio_x, raio_y = 0.285, 0.300
    altura = 0.235                 # folga visível entre o anel e o crânio
    n = 16
    for i in range(n):
        ang = 2.0 * math.pi * i / n
        p.append(caixa("Halo%d" % i, (0.072, 0.072, 0.045),
                       (math.cos(ang) * raio_x, math.sin(ang) * raio_y, altura),
                       COR["halo"]))
    exportar(juntar(p, "Aureola"), "aureola")


def coroa():
    """Origem no TOPO. Aro largo + cinco pontas + gemas."""
    limpar()
    p = []
    aro_l, aro_p = CAB_L * 1.08, CAB_P * 1.05
    # aro
    p.append(caixa("Aro", (aro_l, aro_p, 0.085), (0, 0, 0.0425), COR["ouro"]))
    # faixa clara no alto do aro, o brilho que separa aro de ponta na folha
    p.append(caixa("AroTopo", (aro_l * 0.99, aro_p * 0.99, 0.022), (0, 0, 0.096),
                   COR["ouro_claro"]))
    # cinco pontas: uma central na frente, duas nos cantos da frente, duas atrás
    pontas = [
        (0.0,             aro_p * 0.46, 0.20),   # central, frente
        (aro_l * 0.40,    aro_p * 0.30, 0.15),
        (-aro_l * 0.40,   aro_p * 0.30, 0.15),
        (aro_l * 0.40,   -aro_p * 0.34, 0.15),
        (-aro_l * 0.40,  -aro_p * 0.34, 0.15),
        (0.0,            -aro_p * 0.46, 0.17),   # central, trás
    ]
    for i, (x, y, alt) in enumerate(pontas):
        p.append(caixa("Ponta%d" % i, (0.085, 0.085, alt), (x, y, 0.085 + alt * 0.5),
                       COR["ouro"]))
        # ponteira mais clara
        p.append(caixa("Pico%d" % i, (0.055, 0.055, 0.045),
                       (x, y, 0.085 + alt + 0.0225), COR["ouro_claro"]))
    # gema central de rubi, na frente
    p.append(caixa("Rubi", (0.085, 0.045, 0.095), (0, aro_p * 0.50, 0.055), COR["rubi"]))
    # safiras nas laterais do aro
    for lado in (1, -1):
        p.append(caixa("Safira", (0.045, 0.055, 0.055),
                       (lado * aro_l * 0.50, aro_p * 0.12, 0.048), COR["safira"]))
    exportar(juntar(p, "Coroa"), "coroa")


def cartola():
    """Origem no TOPO. Aba fina e larga, copa alta, faixa vermelha na base."""
    limpar()
    p = []
    # ⚠️ A ABA É A SILHUETA. Na primeira versão ela tinha 0,038 de espessura e
    # sumia atrás da cabeça na prévia — o chapéu lia como coco, não como
    # cartola. Grossa e larga o bastante para sobrar dos dois lados.
    p.append(caixa("Aba", (CAB_L * 1.62, CAB_P * 1.30, 0.058), (0, 0, 0.029), COR["preto"]))
    copa_l, copa_p, copa_a = CAB_L * 0.94, CAB_P * 0.86, 0.115
    # faixa vermelha, logo acima da aba
    p.append(caixa("Faixa", (copa_l * 1.02, copa_p * 1.02, 0.062), (0, 0, 0.089),
                   COR["vermelho"]))
    # copa
    p.append(caixa("Copa", (copa_l, copa_p, 0.330), (0, 0, 0.285), COR["preto"]))
    exportar(juntar(p, "Cartola"), "cartola")


# ==================================================================== ROSTO
def mascara_caveira():
    """Origem no centro da FACE FRONTAL; cresce para +Y (para fora do rosto)."""
    limpar()
    p = []
    esp = 0.055                     # espessura da placa
    # crânio
    p.append(caixa("Cranio", (0.400, esp, 0.330), (0, esp * 0.5, 0.030), COR["osso"]))
    # maxilar, um degrau mais estreito
    p.append(caixa("Maxilar", (0.250, esp * 0.9, 0.085), (0, esp * 0.45, -0.175),
                   COR["osso"]))
    # órbitas
    for lado in (1, -1):
        p.append(caixa("Olho", (0.105, 0.030, 0.105),
                       (lado * 0.098, esp * 0.90, 0.070), COR["preto"]))
    # nariz
    p.append(caixa("Nariz", (0.055, 0.030, 0.060), (0, esp * 0.90, -0.055), COR["preto"]))
    # dentes: dois vãos escuros no maxilar
    for lado in (1, -1):
        p.append(caixa("Dente", (0.030, 0.026, 0.055),
                       (lado * 0.048, esp * 0.85, -0.175), COR["preto"]))
    # tira que dá a volta na cabeça
    p.extend(_tira(0.030))
    exportar(juntar(p, "MascaraCaveira"), "mascara_caveira")


def mascara_peste():
    """Origem na FACE FRONTAL. Bico em degraus, descendo para a frente."""
    limpar()
    p = []
    esp = 0.060
    # placa do rosto
    p.append(caixa("Placa", (0.400, esp, 0.330), (0, esp * 0.5, 0.020), COR["preto_couro"]))
    # ⚠️ BICO LONGO DE PROPÓSITO. Ele é a assinatura da máscara, e é a parte que
    # mais sofre com o ajuste de proporção: numa cabeça rasa a peça encolhe em
    # PROFUNDIDADE, que é justamente a direção em que o bico cresce. Com os
    # 0,384 da primeira versão ele encolhia para dentro do rosto e a máscara
    # virava uma placa preta com óculos. Estes 0,60 leem nas duas cabeças.
    degraus = [
        (0.155, 0.170, 0.145, esp + 0.080, -0.060),
        (0.125, 0.170, 0.118, esp + 0.245, -0.130),
        (0.095, 0.170, 0.092, esp + 0.410, -0.196),
        (0.062, 0.140, 0.062, esp + 0.560, -0.250),
    ]
    for i, (lx, ly, lz, y, z) in enumerate(degraus):
        p.append(caixa("Bico%d" % i, (lx, ly, lz), (0, y, z), COR["preto_couro"]))
    # rebites de latão ao longo do bico
    for i, (_, _, _, y, z) in enumerate(degraus[:3]):
        p.append(caixa("Rebite%d" % i, (0.028, 0.028, 0.028), (0, y - 0.07, z + 0.055),
                       COR["ouro"]))
    # óculos: dois anéis de latão, cada um 8 caixas
    for lado in (1, -1):
        cx = lado * 0.105
        for i in range(8):
            ang = 2.0 * math.pi * i / 8
            p.append(caixa("Aro%d%d" % (lado, i), (0.032, 0.028, 0.032),
                           (cx + math.cos(ang) * 0.058, esp * 0.95 + 0.010,
                            0.088 + math.sin(ang) * 0.058), COR["ouro"]))
        # lente escura
        p.append(caixa("Lente%d" % lado, (0.080, 0.024, 0.080), (cx, esp * 0.95, 0.088),
                       COR["preto"]))
    p.extend(_tira(0.030))
    exportar(juntar(p, "MascaraPeste"), "mascara_peste")


def mascara_covid():
    """Origem na FACE FRONTAL. Cobre da ponta do nariz ao queixo, com pregas."""
    limpar()
    p = []
    esp = 0.050
    larg, alt = 0.395, 0.235
    centro_z = -0.095               # metade de baixo do rosto
    # corpo da máscara
    p.append(caixa("Pano", (larg, esp, alt), (0, esp * 0.5, centro_z), COR["branco"]))
    # três pregas horizontais
    for i in range(3):
        z = centro_z + 0.070 - i * 0.070
        p.append(caixa("Prega%d" % i, (larg * 1.01, esp * 0.55, 0.020),
                       (0, esp * 0.92, z), COR["cinza"]))
    # borda de cima, mais firme (o arame do nariz)
    p.append(caixa("Arame", (larg * 0.98, esp * 0.8, 0.028), (0, esp * 0.55, centro_z + alt * 0.5),
                   COR["cinza"]))
    # elásticos das orelhas
    for lado in (1, -1):
        p.append(caixa("Elastico", (0.028, CAB_P * 0.52, 0.026),
                       (lado * (larg * 0.5 - 0.010), -CAB_P * 0.20, centro_z + 0.055),
                       COR["branco"]))
    exportar(juntar(p, "MascaraCovid"), "mascara_covid")


def _tira(espessura):
    """A tira preta que dá a volta na cabeça — comum às máscaras rígidas.

    Vai para TRÁS (Y negativo) a partir da face, encostada nas laterais.
    """
    p = []
    for lado in (1, -1):
        p.append(caixa("Tira%d" % lado, (espessura, CAB_P * 0.62, 0.070),
                       (lado * (CAB_L * 0.5 + espessura * 0.4), -CAB_P * 0.24, 0.055),
                       COR["preto"]))
    return p


if __name__ == "__main__":
    aureola()
    coroa()
    cartola()
    mascara_caveira()
    mascara_peste()
    mascara_covid()
    print("[cabeca] 6 pecas exportadas em", SAIDA)
