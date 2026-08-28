# -*- coding: utf-8 -*-
"""
Acessórios do menu de Customização, em .glb — Skills One Piece.

Rodar:
    ~/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/acessorios.py

Saída: assets/models/acessorios/{chinelo,capa_marinha,luffy_camisa,
                                 luffy_calcao,espadas_zoro}.glb

--------------------------------------------------------------------- EIXOS
O Godot usa Y para cima e −Z para FRENTE. O exportador glTF mapeia
+Z(Blender) -> +Y(glTF) e +Y(Blender) -> −Z(glTF).

Logo, AQUI:
    Blender X = X do jogo (largura)
    Blender Y = FRENTE do personagem   (vira −Z no jogo)
    Blender Z = para cima              (vira +Y no jogo)

--------------------------------------------------------------- A ORIGEM
⚠️ Cada peça tem a origem no PONTO DE ENCAIXE, não no centro geométrico. É o que
permite o catálogo posicionar por âncora (0..1 na caixa do nó de destino) sem
compensar meia altura na mão — conta que erra em silêncio quando o modelo muda.

------------------------------------------------------------- AS MEDIDAS
Tiradas da AABB LOCAL dos nós do rig, que são as mesmas unidades do acessório
(ele entra como filho do nó):

    Torso   tam(0.500, 0.750, 0.360)
    Head    tam(0.500, 0.500, 0.400)
    Foot_R  tam(0.250, 0.125, 0.400)

Nada aqui é em metros. Se o rig mudar de proporção, é esta tabela que muda.

--------------------------------------------------------------- O ESTILO
Só caixas, como o resto do jogo. Um acessório com curva ou bisel lê como peça de
outro jogo colada por cima — foi o que aconteceu com a primeira versão do chapéu,
que era cilíndrica.
"""

import bpy
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "acessorios")

TORSO_L, TORSO_A, TORSO_P = 0.500, 0.750, 0.360
PE_L, PE_A, PE_P = 0.250, 0.125, 0.400

COR = {
    "borracha": (0.16, 0.16, 0.18, 1.0),
    "palha_pe": (0.80, 0.66, 0.42, 1.0),
    "branco":   (0.95, 0.95, 0.96, 1.0),
    "azul_mar": (0.13, 0.26, 0.52, 1.0),
    "vermelho": (0.78, 0.14, 0.14, 1.0),
    "azul_jean":(0.22, 0.34, 0.62, 1.0),
    "amarelo":  (0.92, 0.78, 0.25, 1.0),
    "verde":    (0.16, 0.42, 0.24, 1.0),
    "preto":    (0.10, 0.10, 0.12, 1.0),
    "branco_g": (0.90, 0.90, 0.88, 1.0),
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
    print("[acess] %-16s %2d verts  X=%.3f Y=%.3f Z=%.3f"
          % (arquivo, len(obj.data.vertices), d.x, d.y, d.z))


# ---------------------------------------------------------------- as peças
def chinelo():
    """Origem na SOLA — encaixa na base do pé."""
    limpar()
    p = []
    # sola, um pouco maior que o pé para aparecer por baixo dele
    p.append(caixa("Sola", (PE_L * 1.18, PE_P * 1.10, 0.055), (0, 0, 0.0275), COR["borracha"]))
    # tira em V, as duas fitas do chinelo de dedo
    p.append(caixa("TiraR", (0.035, 0.20, 0.035), (0.055, 0.05, 0.075), COR["palha_pe"],
                   (0.0, 0.0, -0.45)))
    p.append(caixa("TiraL", (0.035, 0.20, 0.035), (-0.055, 0.05, 0.075), COR["palha_pe"],
                   (0.0, 0.0, 0.45)))
    exportar(juntar(p, "Chinelo"), "chinelo")


def capa_marinha():
    """Origem no ALTO DAS COSTAS — cai a partir dos ombros."""
    limpar()
    p = []
    # manto: desce; Y negativo = para TRÁS
    p.append(caixa("Manto", (TORSO_L * 1.22, 0.085, TORSO_A * 1.15),
                   (0, -TORSO_P * 0.52, -TORSO_A * 0.575), COR["branco"]))
    # gola alta, a marca visual do casaco da Marinha
    p.append(caixa("Gola", (TORSO_L * 0.85, 0.11, 0.11),
                   (0, -TORSO_P * 0.50, -0.055), COR["azul_mar"]))
    # ombreiras
    for lado in (1, -1):
        p.append(caixa("Ombro", (0.13, 0.13, 0.09),
                       (lado * TORSO_L * 0.55, -TORSO_P * 0.42, -0.06), COR["azul_mar"]))
    exportar(juntar(p, "CapaMarinha"), "capa_marinha")


def luffy_camisa():
    """Colete vermelho ABERTO. Origem no alto do tronco."""
    limpar()
    p = []
    a = TORSO_A * 0.72   # mais comprido: parava na altura do peito e sumia
    # costas inteiras
    p.append(caixa("Costas", (TORSO_L * 1.10, 0.06, a),
                   (0, -TORSO_P * 0.53, -a / 2.0), COR["vermelho"]))
    # frente ABERTA: duas bandas, com o peito de fora — é isso que faz ler como
    # o colete do Luffy e não como uma camiseta.
    # Bandas da frente LARGAS: com 0,30 do tronco elas liam como duas tiras, não
    # como um colete aberto. O vão do meio é o que faz a leitura do Luffy.
    for lado in (1, -1):
        p.append(caixa("Frente", (TORSO_L * 0.46, 0.07, a),
                       (lado * TORSO_L * 0.36, TORSO_P * 0.55, -a / 2.0), COR["vermelho"]))
    # laterais, fechando o vão
    for lado in (1, -1):
        p.append(caixa("Lado", (0.07, TORSO_P * 1.10, a),
                       (lado * TORSO_L * 0.57, 0, -a / 2.0), COR["vermelho"]))
    exportar(juntar(p, "LuffyCamisa"), "luffy_camisa")


def luffy_calcao():
    """Calção azul. Origem na CINTURA (alto da peça)."""
    limpar()
    p = []
    h = TORSO_A * 0.42
    p.append(caixa("Calcao", (TORSO_L * 1.12, TORSO_P * 1.12, h), (0, 0, -h / 2.0),
                   COR["azul_jean"]))
    # barra mais clara na bainha
    p.append(caixa("Bainha", (TORSO_L * 1.15, TORSO_P * 1.15, 0.045), (0, 0, -h - 0.0225),
                   COR["branco_g"]))
    exportar(juntar(p, "LuffyCalcao"), "luffy_calcao")


def espadas_zoro():
    """As TRÊS espadas na cintura, do lado esquerdo. Origem no ponto do quadril."""
    limpar()
    p = []
    comp = TORSO_A * 0.95
    for i, (dx, dy, giro, cor_punho) in enumerate([
            (0.00, 0.00, 0.16, COR["branco_g"]),
            (0.05, -0.05, 0.26, COR["verde"]),
            (0.10, -0.10, 0.36, COR["preto"])]):
        # bainha: comprida, inclinada para trás
        p.append(caixa("Bainha%d" % i, (0.055, 0.055, comp),
                       (dx, dy, -comp / 2.0), COR["preto"], (giro, 0.0, 0.0)))
        # guarda e punho, no alto
        p.append(caixa("Guarda%d" % i, (0.11, 0.11, 0.035),
                       (dx, dy + 0.02, 0.03), COR["amarelo"], (giro, 0.0, 0.0)))
        p.append(caixa("Punho%d" % i, (0.05, 0.05, 0.16),
                       (dx, dy + 0.04, 0.12), cor_punho, (giro, 0.0, 0.0)))
    exportar(juntar(p, "EspadasZoro"), "espadas_zoro")


if __name__ == "__main__":
    chinelo()
    capa_marinha()
    luffy_camisa()
    luffy_calcao()
    espadas_zoro()
    print("[acess] fim")
