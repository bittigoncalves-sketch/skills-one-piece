"""
Gera as armas da BUKI BUKI NO MI em .glb — Skills One Piece.

Por que existir: as armas nasceram montadas em GDScript (caixas e cilindros no
`BukiFX._construir_*`). Isso trava o acabamento — não dá pra chanfrar, nem
soltar a silhueta — e obriga a mexer em código pra ajustar arte. Aqui elas viram
ASSET: modeladas, com bisel, e exportadas pro jogo apenas instanciar.

Rodar:
    blender --background --python tools/blender/buki_weapons.py

Saída: assets/models/weapons/buki_{metralhadora,lamina,canhao}.glb

--------------------------------------------------------------------- EIXOS
O Godot usa Y para cima e −Z para frente. O exportador glTF converte do Blender
(Z para cima) mapeando +Z(Blender) -> +Y(glTF) e +Y(Blender) -> −Z(glTF).

Logo, AQUI:  o cano aponta para +Y   (vira "frente" = −Z no jogo)
             a vertical é +Z          (vira "cima"  = +Y no jogo)

Os offsets batem com os antigos do BukiFX: a arma nasce na ponta do membro, com
a origem no ponto de encaixe, então trocar procedural por .glb não move nada de
lugar.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "weapons")

# Paleta — a MESMA do BukiFX (ACO / _mat_escuro / ACO_QUENTE), para as armas em
# .glb não destoarem de nenhum efeito que continue procedural.
ACO = (0.74, 0.78, 0.84, 1.0)
ESCURO = (0.20, 0.21, 0.24, 1.0)
QUENTE = (1.00, 0.72, 0.30, 1.0)


# --------------------------------------------------------------------- utilidades
def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(nome, cor, metallic=0.95, roughness=0.28, emissivo=None):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = cor
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emissivo:
        bsdf.inputs["Emission Color"].default_value = emissivo
        bsdf.inputs["Emission Strength"].default_value = 2.2
    return m


def _finalizar(obj, mat, bisel=0.006, segmentos=2):
    obj.data.materials.append(mat)
    if bisel > 0:
        mod = obj.modifiers.new("Bisel", "BEVEL")
        mod.width = bisel
        mod.segments = segmentos
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
    _auto_smooth(obj)
    return obj


def _auto_smooth(obj):
    """Suaviza só onde o ângulo é raso (canos redondos), mantendo as quinas duras.

    O nome disso mudou de versão pra versão do Blender (`shade_smooth_by_angle`
    virou operador, depois `shade_auto_smooth`); por isso a cascata em vez de
    uma chamada só. Sem isso o cano do canhão fica facetado como um lápis.
    """
    bpy.context.view_layer.objects.active = obj
    for op in ("shade_auto_smooth", "shade_smooth_by_angle"):
        fn = getattr(bpy.ops.object, op, None)
        if fn is None:
            continue
        try:
            fn(angle=math.radians(35))
            return
        except (TypeError, RuntimeError):
            continue
    bpy.ops.object.shade_flat()


def caixa(nome, tam, pos, mat, bisel=0.006):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    o = bpy.context.object
    o.name = nome
    o.scale = Vector(tam)
    bpy.ops.object.transform_apply(scale=True)
    return _finalizar(o, mat, bisel)


def cilindro(nome, raio, alt, pos, mat, eixo="y", lados=16, bisel=0.005, raio2=None):
    """Cilindro (ou cone truncado, com raio2) deitado no eixo pedido."""
    if raio2 is None or abs(raio2 - raio) < 1e-6:
        bpy.ops.mesh.primitive_cylinder_add(vertices=lados, radius=raio, depth=alt, location=pos)
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=lados, radius1=raio, radius2=raio2, depth=alt, location=pos
        )
    o = bpy.context.object
    o.name = nome
    if eixo == "y":                      # primitivo nasce em +Z; deita no cano
        o.rotation_euler[0] = math.radians(90)
    bpy.ops.object.transform_apply(rotation=True)
    return _finalizar(o, mat, bisel)


def inclinar(objetos, pivo_z, graus):
    """Inclina um grupo de peças em torno de um MESMO pivô no eixo X.

    Existe porque inclinar só a peça principal descola o resto: a ponta e a
    canaleta da lâmina ficavam para trás e a arma saía em pedaços. Quem faz
    parte da mesma peça tem que girar junto, no mesmo centro.
    """
    rad = math.radians(graus)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    for o in objetos:
        y, z = o.location[1], o.location[2] - pivo_z
        o.location[1] = y * cos_a - z * sin_a
        o.location[2] = pivo_z + y * sin_a + z * cos_a
        o.rotation_euler[0] += rad


def juntar(nome, objetos):
    for o in bpy.data.objects:
        o.select_set(False)
    for o in objetos:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.object.join()
    alvo = bpy.context.object
    alvo.name = nome
    alvo.data.name = nome
    return alvo


def exportar(nome):
    os.makedirs(SAIDA, exist_ok=True)
    caminho = os.path.join(SAIDA, nome + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=caminho,
        export_format="GLB",
        export_yup=True,               # converte Z-up(Blender) -> Y-up(glTF/Godot)
        export_apply=True,             # aplica os modificadores (o bisel entra na malha)
        use_selection=False,
    )
    tam = os.path.getsize(caminho)
    print("  -> %s (%.1f KB)" % (caminho, tam / 1024.0))
    return caminho


# ------------------------------------------------------------------ METRALHADORA
def metralhadora():
    """Braço-metralhadora (slot Z). Y = ponta do antebraço, cano em +Y."""
    limpar()
    aco = material("BukiAco", ACO)
    escuro = material("BukiEscuro", ESCURO, metallic=0.85, roughness=0.45)
    quente = material("BukiQuente", ACO, emissivo=QUENTE)
    z = -0.34                                    # ponta do antebraço (era `y` no GDScript)

    partes = [
        # Bisel curto na culatra: com 0.012 ela virava um sabonete e a arma
        # perdia a quina que a fazia ler como bloco mecânico.
        caixa("culatra", (0.20, 0.30, 0.17), (0, 0.08, z + 0.02), escuro, bisel=0.005),
        cilindro("cano", 0.082, 0.60, (0, 0.42, z), escuro),
        cilindro("boca", 0.058, 0.10, (0, 0.76, z), quente, bisel=0.004),
        # Camisa de refrigeração: as ranhuras é que fazem ler "metralhadora" em
        # vez de "tubo" — MAS só se sobrar cano aparecendo entre elas. Com 7 aros
        # grossos e colados o cano sumia e a peça virava uma sanfona escura.
        # 5 aros finos, bem espaçados, sobre cano claro: o contraste volta.
        # Os aros são de AÇO CLARO sobre cano escuro (e não o contrário): a arma
        # inteira em tom escuro sumia contra o cenário cinza do jogo. Claro-e-
        # escuro alternando ao longo do cano é o que dá leitura à distância.
        *[cilindro("camisa%d" % i, 0.108, 0.030, (0, 0.24 + i * 0.105, z), aco, bisel=0.003)
          for i in range(5)],
        cilindro("tambor", 0.13, 0.11, (0, 0.10, z - 0.13), escuro, eixo="z", lados=12),
        cilindro("tambor_eixo", 0.045, 0.14, (0, 0.10, z - 0.13), aco, eixo="z", lados=10),
        caixa("alca", (0.02, 0.02, 0.07), (0, 0.20, z + 0.13), escuro, bisel=0.003),
        caixa("massa", (0.02, 0.02, 0.05), (0, 0.62, z + 0.12), escuro, bisel=0.003),
        # Janela de ejeção, encostada na culatra. A FITA DE MUNIÇÃO foi cortada:
        # os elos ficavam soltos no ar ao lado da arma (sem nada os prendendo,
        # liam como bolhas flutuando). Cápsulas de verdade agora saem daqui como
        # partícula, no disparo — ver BukiFX._capsulas.
        caixa("ejetor", (0.035, 0.13, 0.06), (0.105, 0.08, z + 0.03), escuro, bisel=0.004),
    ]
    juntar("BukiMetralhadora", partes)
    return exportar("buki_metralhadora")


# ------------------------------------------------------------------------ LÂMINA
def lamina():
    """Braço-lâmina (slot X). A lâmina desce em −Z (o braço aponta pra baixo)."""
    limpar()
    aco = material("BukiAco", ACO)
    gume = material("BukiQuente", ACO, emissivo=QUENTE)
    escuro = material("BukiEscuro", ESCURO, metallic=0.85, roughness=0.45)

    # ATENÇÃO ao sinal: o Y do Blender vira −Z no Godot. Os valores abaixo são
    # os antigos do BukiFX com o sinal INVERTIDO — sem isso o fio da lâmina
    # aponta pra trás (a arma sai espelhada frente-fundo).
    # A LÂMINA (tudo que é gume) gira junto, em torno do mesmo pivô. O punho
    # (ricasso + guarda) fica de pé, porque é ele que encaixa no antebraço.
    folha = [
        caixa("corpo", (0.055, 0.17, 0.98), (0, 0.06, -0.78), aco, bisel=0.008),
        caixa("fio", (0.020, 0.05, 0.96), (0, 0.150, -0.78), gume, bisel=0.006),
        # Canaleta (fuller): o sulco central que toda lâmina de verdade tem.
        # Impossível no builder antigo sem empilhar mais três caixas.
        caixa("canaleta", (0.024, 0.060, 0.78), (0, -0.010, -0.80), escuro, bisel=0.003),
        caixa("ponta", (0.050, 0.13, 0.20), (0, 0.075, -1.30), aco, bisel=0.010),
    ]
    inclinar(folha, -0.30, -6)                   # curvatura de sabre, a partir do punho

    punho = [
        caixa("ricasso", (0.10, 0.10, 0.16), (0, 0.02, -0.30), escuro, bisel=0.008),
        caixa("guarda", (0.24, 0.10, 0.035), (0, 0.04, -0.37), escuro, bisel=0.006),
    ]
    juntar("BukiLamina", folha + punho)
    return exportar("buki_lamina")


# ------------------------------------------------------------------------ CANHÃO
def canhao():
    """Canhão de perna (slot C). Peça mais pesada: silhueta grossa de longe."""
    limpar()
    aco = material("BukiAco", ACO)
    escuro = material("BukiEscuro", ESCURO, metallic=0.85, roughness=0.45)
    boca = material("BukiQuente", ACO, emissivo=QUENTE)
    z = -0.30

    partes = [
        cilindro("camara", 0.19, 0.30, (0, 0.06, z), escuro, lados=14),
        # Cano levemente cônico (0.155 -> 0.14): dá perspectiva à peça, o que um
        # cilindro reto não dá.
        cilindro("cano", 0.155, 0.56, (0, 0.44, z), aco, lados=14, raio2=0.140),
        *[cilindro("aro%d" % i, 0.185, 0.05, (0, 0.26 + i * 0.20, z), escuro, lados=14, bisel=0.006)
          for i in range(3)],
        cilindro("boca", 0.215, 0.14, (0, 0.78, z), aco, lados=14, raio2=0.185),
        cilindro("interior", 0.145, 0.06, (0, 0.83, z), boca, lados=14, bisel=0.003),
        caixa("punho", (0.10, 0.10, 0.16), (0, 0.14, z - 0.17), escuro, bisel=0.010),
        # Munhões (os pinos laterais de todo canhão) e o parafuso da culatra.
        cilindro("munhao_e", 0.05, 0.22, (0, 0.10, z), escuro, eixo="x" if False else "z", lados=10),
        cilindro("culatra", 0.10, 0.10, (0, -0.10, z), aco, lados=12),
    ]
    juntar("BukiCanhao", partes)
    return exportar("buki_canhao")


if __name__ == "__main__":
    print("=== armas da Buki Buki no Mi ===")
    metralhadora()
    lamina()
    canhao()
    print("=== pronto ===")
