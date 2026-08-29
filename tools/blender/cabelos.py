# -*- coding: utf-8 -*-
"""
Cabelos da Customização, em .glb — Skills One Piece.

Rodar:
    ~/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/cabelos.py

Saída: assets/models/cabelos/*.glb  (12 estilos)

Reproduz a metade de baixo da folha `imagens para designs/cabeloserostos.png`.

--------------------------------------------------------------- SEM OLHOS
⚠️ INSTRUÇÃO EXPLÍCITA DO DONO: os olhos que aparecem na folha ao lado dos
cabelos são REFERÊNCIA DE ALTURA e nada mais — nenhum cabelo pode trazer olho
junto. Os olhos já são categoria própria (`Corpo.gd`), e um cabelo que
carregasse os seus daria dois pares na cara de quem escolhesse os dois.

O que a referência serve para decidir é ONDE A FRANJA PARA. Os olhos ficam na
âncora y=0,60 da caixa da cabeça (`Corpo.BASE`), o que — com a origem desta peça
no TOPO do crânio — cai em z = −0,20. É a linha `OLHOS_Z` abaixo.

--------------------------------------------------------------------- EIXOS
Mesma convenção de `acessorios_cabeca.py`:
    Blender X = largura | Y = FRENTE | Z = para cima

--------------------------------------------------------------- A ORIGEM
No CENTRO DO TOPO da cabeça, com o cabelo descendo para −Z. A âncora do catálogo
é (0,5, 1,0, 0,5), a mesma da coroa e da cartola.

------------------------------------------------------------------- A COR
⚠️ TUDO NUMA COR SÓ, e neutra. O dono escolheu que a cor do cabelo é do JOGADOR,
não do estilo: o catálogo pinta a peça inteira com o tom escolhido. Modelar o
espetado preto e o curto loiro, como estão na folha, fixaria a decisão na
geometria e impediria "moicano loiro".
"""

import bpy
import os
import math
import random

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "cabelos")

CAB_L, CAB_A, CAB_P = 0.500, 0.500, 0.740
FOLGA = 0.016                 # o cabelo assenta por FORA do crânio
OLHOS_Z = -0.20               # linha dos olhos — piso das franjas (ver acima)
NEUTRO = (0.55, 0.55, 0.55, 1.0)

L = CAB_L + FOLGA * 2.0       # largura da casca
P = CAB_P + FOLGA * 2.0       # profundidade da casca


def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(bloco):
            bloco.remove(item)


def material():
    m = bpy.data.materials.get("Cabelo")
    if m:
        return m
    m = bpy.data.materials.new("Cabelo")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = NEUTRO
    b.inputs["Roughness"].default_value = 0.95
    if "Metallic" in b.inputs:
        b.inputs["Metallic"].default_value = 0.0
    return m


def caixa(nome, tam, centro):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material())
    return o


def calota(altura=0.085, escala=1.0):
    """A base de todo penteado: a tampa que cobre o alto do crânio."""
    return [caixa("Calota", (L * escala, P * escala, altura), (0, 0, -altura * 0.5))]


def borda(desce, frente=True, tras=True, lados=True, esp=0.055):
    """Faixa que desce pelas laterais/nuca/testa. `desce` é positivo."""
    p = []
    z = -desce * 0.5
    if lados:
        for lado in (1, -1):
            p.append(caixa("Lado", (esp, P, desce), (lado * (L * 0.5 - esp * 0.5), 0, z)))
    if tras:
        p.append(caixa("Nuca", (L, esp, desce), (0, -(P * 0.5 - esp * 0.5), z)))
    if frente:
        p.append(caixa("Testa", (L, esp, desce), (0, P * 0.5 - esp * 0.5, z)))
    return p


def juntar(partes, nome):
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = nome
    return o


def exportar(partes, arquivo):
    os.makedirs(SAIDA, exist_ok=True)
    obj = juntar(partes, arquivo)
    caminho = os.path.join(SAIDA, arquivo + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=caminho, export_format="GLB",
                              use_selection=True, export_apply=True, export_yup=True)
    d = obj.dimensions
    print("[cabelo] %-16s %4d verts  X=%.3f Y=%.3f Z=%.3f"
          % (arquivo, len(obj.data.vertices), d.x, d.y, d.z))


# ------------------------------------------------------------------ estilos
def espetado():
    """Pontas retas subindo do alto — irregulares, mas nunca aleatórias: a
    semente é fixa para o modelo sair igual em toda reexportação."""
    limpar()
    random.seed(1)
    p = calota(0.075)
    p += borda(0.055, frente=True, tras=True, lados=True, esp=0.045)
    for i in range(26):
        x = random.uniform(-L * 0.42, L * 0.42)
        y = random.uniform(-P * 0.40, P * 0.40)
        h = random.uniform(0.075, 0.185)
        p.append(caixa("Espeto%d" % i, (0.052, 0.052, h), (x, y, h * 0.5 - 0.02)))
    exportar(p, "espetado")


def baguncado():
    limpar()
    random.seed(7)
    p = calota(0.095)
    p += borda(0.115, esp=0.058)
    for i in range(30):
        x = random.uniform(-L * 0.46, L * 0.46)
        y = random.uniform(-P * 0.44, P * 0.44)
        h = random.uniform(0.045, 0.105)
        p.append(caixa("Tufo%d" % i, (0.080, 0.080, h), (x, y, random.uniform(-0.03, 0.055))))
    exportar(p, "baguncado")


def topete():
    """Bloco liso e reto — o oposto do espetado."""
    limpar()
    p = calota(0.070)
    p.append(caixa("Bloco", (L, P * 0.92, 0.115), (0, 0.012, 0.045))
             )
    p += borda(0.075, frente=True, tras=True, lados=True, esp=0.050)
    exportar(p, "topete")


def curto():
    limpar()
    p = calota(0.080)
    p += borda(0.105, esp=0.052)
    # franja curta, bem acima da linha dos olhos
    p.append(caixa("Franja", (L, 0.075, 0.075), (0, P * 0.5 - 0.038, -0.125)))
    exportar(p, "curto")


def cacheado():
    """Volume feito de cubinhos pequenos: é o que lê como cacho em voxel."""
    limpar()
    random.seed(3)
    p = calota(0.080)
    p += borda(0.130, esp=0.060)
    for i in range(46):
        ang = random.uniform(0, math.pi * 2)
        r = random.uniform(0.0, 1.0) ** 0.5
        x = math.cos(ang) * r * L * 0.48
        y = math.sin(ang) * r * P * 0.48
        p.append(caixa("Cacho%d" % i, (0.062, 0.062, 0.062),
                       (x, y, random.uniform(-0.06, 0.055))))
    exportar(p, "cacheado")


def longo():
    """Desce pelas laterais bem abaixo do queixo, e a franja chega aos olhos."""
    limpar()
    p = calota(0.085)
    p += borda(0.520, frente=False, tras=True, lados=True, esp=0.062)
    # mechas laterais mais compridas, à frente das orelhas
    for lado in (1, -1):
        p.append(caixa("Mecha%d" % lado, (0.070, 0.150, 0.560),
                       (lado * (L * 0.5 - 0.035), P * 0.30, -0.280)))
    # franja até a altura dos olhos (referência da folha)
    p.append(caixa("Franja", (L, 0.070, abs(OLHOS_Z)),
                   (0, P * 0.5 - 0.035, OLHOS_Z * 0.5)))
    exportar(p, "longo")


def franja():
    """Franja reta e cheia, com os fios recortados na ponta."""
    limpar()
    p = calota(0.085)
    p += borda(0.150, frente=False, tras=True, lados=True, esp=0.058)
    # a franja para NA linha dos olhos — a referência de altura da folha
    p.append(caixa("Franja", (L, 0.075, abs(OLHOS_Z) - 0.03),
                   (0, P * 0.5 - 0.038, (OLHOS_Z + 0.03) * 0.5)))
    # fios: dentes que descem um pouco mais, alternados
    for i in range(7):
        x = -L * 0.42 + i * (L * 0.84 / 6.0)
        p.append(caixa("Fio%d" % i, (0.048, 0.070, 0.070),
                       (x, P * 0.5 - 0.038, OLHOS_Z - 0.010)))
    exportar(p, "franja")


def lateral():
    """Repartido de lado: volume alto de um lado, rente do outro."""
    limpar()
    p = calota(0.080)
    p += borda(0.115, esp=0.055)
    p.append(caixa("Volume", (L * 0.58, P * 0.88, 0.105), (-L * 0.20, 0, 0.045)))
    p.append(caixa("Rente", (L * 0.40, P * 0.88, 0.045), (L * 0.29, 0, 0.015)))
    # a mecha que cruza a testa
    p.append(caixa("Mecha", (L * 0.66, 0.075, 0.085), (-L * 0.14, P * 0.5 - 0.038, -0.105)))
    exportar(p, "lateral")


def moicano():
    """Só a crista central. Sem calota: as laterais são raspadas."""
    limpar()
    p = []
    # ⚠️ CRISTA ALTA, e não só comprida. A primeira versão apostava no
    # comprimento (0,115 de altura por 9 blocos ao longo da cabeça) e virava um
    # TUFO na prévia: ali a cabeça é mais rasa, a peça encolhe em PROFUNDIDADE
    # (é o eixo em que a crista se estende) e sobra pouco do penteado. Altura
    # não sofre esse encolhimento, então é nela que o moicano tem de se apoiar.
    p.append(caixa("Base", (0.165, P * 0.88, 0.055), (0, 0, -0.027)))
    for i in range(9):
        y = -P * 0.38 + i * (P * 0.76 / 8.0)
        h = 0.215 + 0.130 * math.sin(math.pi * i / 8.0)
        p.append(caixa("Crista%d" % i, (0.145, 0.084, h), (0, y, h * 0.5 - 0.015)))
    exportar(p, "moicano")


def dread():
    """Tranças verticais descendo em volta da cabeça."""
    limpar()
    random.seed(11)
    p = calota(0.085)
    p += borda(0.095, esp=0.055)
    n = 22
    for i in range(n):
        ang = 2.0 * math.pi * i / n
        x = math.cos(ang) * L * 0.47
        y = math.sin(ang) * P * 0.47
        comp = random.uniform(0.170, 0.330)
        p.append(caixa("Dread%d" % i, (0.062, 0.062, comp), (x, y, -comp * 0.5 - 0.02)))
    exportar(p, "dread")


def super_espetado():
    """Espetos longos saindo em leque, inclusive para os lados."""
    limpar()
    random.seed(5)
    p = calota(0.070)
    p += borda(0.050, esp=0.045)
    for i in range(34):
        ang = random.uniform(0, math.pi * 2)
        r = random.uniform(0.25, 1.0)
        x = math.cos(ang) * r * L * 0.50
        y = math.sin(ang) * r * P * 0.50
        h = random.uniform(0.140, 0.290)
        # quanto mais na borda, mais o espeto deita para fora
        p.append(caixa("Espeto%d" % i, (0.048, 0.048, h),
                       (x * 1.18, y * 1.18, h * 0.45 - 0.02)))
    exportar(p, "super_espetado")


def rabo_de_cavalo():
    limpar()
    p = calota(0.085)
    p += borda(0.120, esp=0.058)
    # o laço, colado na nuca
    p.append(caixa("Laco", (0.115, 0.075, 0.090), (0, -(P * 0.5 + 0.020), -0.090)))
    # o rabo, descendo atrás em três blocos que afinam
    p.append(caixa("Rabo1", (0.140, 0.115, 0.185), (0, -(P * 0.5 + 0.045), -0.215)))
    p.append(caixa("Rabo2", (0.110, 0.095, 0.150), (0, -(P * 0.5 + 0.055), -0.375)))
    p.append(caixa("Rabo3", (0.075, 0.075, 0.105), (0, -(P * 0.5 + 0.060), -0.495)))
    exportar(p, "rabo_de_cavalo")


if __name__ == "__main__":
    espetado()
    baguncado()
    topete()
    curto()
    cacheado()
    longo()
    franja()
    lateral()
    moicano()
    dread()
    super_espetado()
    rabo_de_cavalo()
    print("[cabelo] 12 estilos exportados em", SAIDA)
