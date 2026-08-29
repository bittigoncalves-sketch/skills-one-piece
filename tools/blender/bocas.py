# -*- coding: utf-8 -*-
"""
Bocas (expressões) da Customização, em .glb — Skills One Piece.

Rodar:
    ~/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/bocas.py

Saída: assets/models/bocas/*.glb  (12 expressões)

Reproduz a metade de cima da folha `imagens para designs/cabeloserostos.png`.

--------------------------------------------------------------- O QUE É ISTO
O rig não tem rosto: a cabeça é uma caixa lisa, e o olho já é peça acrescentada
na frente (`Corpo.gd`). A boca segue a mesma ideia — placas finas na FACE
FRONTAL, um fio à frente da pele para não brigar por profundidade com ela.

⚠️ O "BRAVO" TRAZ SOBRANCELHAS. Na folha ele é a única expressão que muda algo
acima dos olhos, e sem elas a cara não lê como brava — lê como assustada. As
sobrancelhas ficam ACIMA da linha dos olhos (y=0,60 da caixa da cabeça), e por
isso a peça é mais alta que as outras onze.

--------------------------------------------------------------------- EIXOS
    Blender X = largura | Y = FRENTE | Z = para cima

--------------------------------------------------------------- A ORIGEM
No centro da FACE FRONTAL, na ALTURA DA BOCA (âncora y=0,32 da caixa da cabeça,
bem abaixo dos olhos). A peça cresce em ±X, ±Z e para +Y (para fora do rosto).
"""

import bpy
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "bocas")

ESP = 0.030               # o quanto a peça sobressai do rosto
Y = ESP * 0.5             # centro da placa, para ela nascer colada na face

COR = {
    "traco":   (0.06, 0.06, 0.09, 1.0),
    "lingua":  (0.85, 0.18, 0.20, 1.0),
    "dente":   (0.97, 0.97, 0.95, 1.0),
}

# Altura dos olhos MENOS a da boca, em unidades da cabeça: os olhos estão na
# âncora 0,60 e a boca na 0,32, e a cabeça tem 0,500 de altura.
ATE_OS_OLHOS = (0.60 - 0.32) * 0.500      # 0,140


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


def bloco(nome, larg, alt, x, z, cor="traco", prof=ESP, y=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, Y if y is None else y, z))
    o = bpy.context.active_object
    o.name = nome
    o.scale = (larg, prof, alt)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material(cor, COR[cor]))
    return o


def exportar(partes, arquivo):
    os.makedirs(SAIDA, exist_ok=True)
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = arquivo
    caminho = os.path.join(SAIDA, arquivo + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    d = obj.dimensions
    print("[boca] %-18s %3d verts  X=%.3f Y=%.3f Z=%.3f"
          % (arquivo, len(obj.data.vertices), d.x, d.y, d.z))


def _arco(nome, larg, degraus, passo_z, cor="traco", esp=0.028, inverte=False):
    """Curva feita de degraus — é assim que um arco lê em voxel."""
    p = []
    n = len(degraus)
    for i, dz in enumerate(degraus):
        x = -larg * 0.5 + larg * (i + 0.5) / n
        z = dz * passo_z * (-1.0 if inverte else 1.0)
        p.append(bloco("%s%d" % (nome, i), larg / n, esp, x, z, cor))
    return p


# ------------------------------------------------------------------ as bocas
def neutra():
    limpar()
    exportar([bloco("Linha", 0.185, 0.030, 0, 0)], "neutra")


def sorriso():
    limpar()
    p = _arco("Sup", 0.215, [1, 0, 0, 0, 1], 0.030, esp=0.032)
    p.append(bloco("Vao", 0.155, 0.055, 0, -0.030))
    p.append(bloco("Lingua", 0.115, 0.030, 0, -0.052, "lingua"))
    exportar(p, "sorriso")


def feliz():
    limpar()
    p = [bloco("Vao", 0.190, 0.095, 0, -0.015)]
    p.append(bloco("Lingua", 0.150, 0.040, 0, -0.048, "lingua"))
    p += _arco("Canto", 0.230, [1, 0, 0, 0, 1], 0.034, esp=0.030)
    exportar(p, "feliz")


def sorriso_com_dentes():
    limpar()
    p = [bloco("Vao", 0.215, 0.080, 0, 0)]
    p.append(bloco("Dentes", 0.190, 0.055, 0, 0.005, "dente", prof=ESP * 1.2))
    # as divisões entre os dentes
    for i in range(4):
        x = -0.072 + i * 0.048
        p.append(bloco("Div%d" % i, 0.012, 0.055, x, 0.005, "traco", prof=ESP * 1.4))
    exportar(p, "sorriso_com_dentes")


def smirk():
    """Assimétrico de propósito: é o que separa o sorrisinho do sorriso."""
    limpar()
    p = [bloco("A", 0.055, 0.028, -0.075, 0.014),
         bloco("B", 0.055, 0.028, -0.025, -0.006),
         bloco("C", 0.055, 0.028, 0.028, -0.020),
         bloco("D", 0.030, 0.055, 0.062, -0.006)]
    exportar(p, "smirk")


def triste():
    limpar()
    exportar(_arco("Arco", 0.205, [1, 0, 0, 0, 1], 0.032, esp=0.030, inverte=True), "triste")


def surpreso():
    limpar()
    p = [bloco("Meio", 0.090, 0.105, 0, 0),
         bloco("Topo", 0.060, 0.135, 0, 0)]
    exportar(p, "surpreso")


def bravo():
    """A única com SOBRANCELHAS — ver a nota no topo do arquivo."""
    limpar()
    p = [bloco("Vao", 0.180, 0.085, 0, -0.010)]
    p.append(bloco("Lingua", 0.140, 0.032, 0, -0.040, "lingua"))
    # sobrancelhas inclinadas, acima da linha dos olhos
    z_sob = ATE_OS_OLHOS + 0.075
    for lado, passos in ((-1, [0, 1, 2]), (1, [2, 1, 0])):
        for i, d in enumerate(passos):
            x = lado * (0.055 + i * 0.040)
            p.append(bloco("Sob%d%d" % (lado, i), 0.045, 0.030, x, z_sob + d * 0.022))
    exportar(p, "bravo")


def dentes_cerrados():
    limpar()
    p = [bloco("Vao", 0.225, 0.070, 0, 0)]
    p.append(bloco("Dentes", 0.200, 0.048, 0, 0, "dente", prof=ESP * 1.2))
    p.append(bloco("Meio", 0.200, 0.012, 0, 0, "traco", prof=ESP * 1.4))
    for i in range(5):
        x = -0.080 + i * 0.040
        p.append(bloco("Div%d" % i, 0.010, 0.048, x, 0, "traco", prof=ESP * 1.4))
    exportar(p, "dentes_cerrados")


def assustado():
    limpar()
    p = [bloco("Vao", 0.130, 0.115, 0, 0),
         bloco("Estreito", 0.160, 0.075, 0, 0)]
    p.append(bloco("Lingua", 0.095, 0.032, 0, -0.040, "lingua"))
    exportar(p, "assustado")


def tirando_lingua():
    limpar()
    p = _arco("Sup", 0.215, [1, 0, 0, 0, 1], 0.030, esp=0.030)
    p.append(bloco("Vao", 0.160, 0.050, 0, -0.028))
    # a língua sai por um canto e desce
    p.append(bloco("Lingua1", 0.070, 0.055, 0.048, -0.062, "lingua"))
    p.append(bloco("Lingua2", 0.055, 0.045, 0.048, -0.098, "lingua"))
    exportar(p, "tirando_lingua")


def desconfortavel():
    """Zigue-zague: a linha que a folha usa para 'sem graça'."""
    limpar()
    p = []
    n = 8
    larg = 0.210
    for i in range(n):
        x = -larg * 0.5 + larg * (i + 0.5) / n
        z = 0.020 if i % 2 == 0 else -0.020
        p.append(bloco("Z%d" % i, larg / n * 1.1, 0.028, x, z))
    exportar(p, "desconfortavel")


if __name__ == "__main__":
    neutra()
    sorriso()
    feliz()
    sorriso_com_dentes()
    smirk()
    triste()
    surpreso()
    bravo()
    dentes_cerrados()
    assustado()
    tirando_lingua()
    desconfortavel()
    print("[boca] 12 expressões exportadas em", SAIDA)
