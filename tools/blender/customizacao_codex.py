# -*- coding: utf-8 -*-
"""
Assets de customização do Modo História modelados a partir das IMAGENS que o
Codex gerou em `art_src/references/customizacao_codex/<peca>.png`.

Rodar (uma peça ou todas):
    blender --background --python tools/blender/customizacao_codex.py -- espada_katana
    blender --background --python tools/blender/customizacao_codex.py

Saída: assets/models/<categoria>/<peca>.glb  (categoria no dicionário PECAS)

Convenção (a mesma de cabelos.py / acessorios_cabeca.py): Blender X = largura,
Y = FRENTE do personagem, Z = para cima. Cabeça = caixa 0,50 × 0,50 × 0,74.
- cabelo/chifre/acessório de cabeça: origem no CENTRO DO TOPO da cabeça;
- arma de quadril: origem no centro da peça, pendurada na vertical.
Cabelos saem numa cor neutra só (o catálogo tinge); detalhes de outra cor
(fitas, ouro) ficam em material próprio.
"""

import os
import sys

import bpy

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models")

CAB_L, CAB_A, CAB_P = 0.500, 0.500, 0.740
FOLGA = 0.016
L = CAB_L + FOLGA * 2.0
P = CAB_P + FOLGA * 2.0
NEUTRO = (0.55, 0.55, 0.55, 1.0)

_mats = {}


def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(bloco):
            bloco.remove(item)
    _mats.clear()


def mat(nome, cor, metal=0.0, rug=0.85):
    if nome in _mats:
        return _mats[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = cor if len(cor) == 4 else (*cor, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rug
    _mats[nome] = m
    return m


def caixa(nome, tam, centro, m):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o


def exportar(partes, pasta, arquivo):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = arquivo
    destino = os.path.join(SAIDA, pasta)
    os.makedirs(destino, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(destino, arquivo + ".glb"),
                              export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    d = obj.dimensions
    print("[codex] %-22s %5d verts  X=%.3f Y=%.3f Z=%.3f"
          % (arquivo, len(obj.data.vertices), d.x, d.y, d.z))


# ----------------------------------------------------------------- katana
def espada_katana():
    """Katana na bainha, pendurada. Cabo no topo (+Z), ponteira em −Z.
    Altura total 0,96. Bainha roxa-escura com arabesco dourado (imagem)."""
    limpar()
    roxo = mat("Saya", (0.10, 0.07, 0.15), 0.0, 0.6)
    ouro = mat("Ouro", (0.85, 0.64, 0.20), 0.85, 0.35)
    preto = mat("Cabo", (0.07, 0.07, 0.09), 0.0, 0.7)
    p = []
    topo = 0.48
    # cabo (tsuka) 0,24 + diamantes dourados
    p.append(caixa("Cabo", (0.046, 0.040, 0.24), (0, 0, topo - 0.12), preto))
    for i in range(4):
        p.append(caixa("Losango", (0.026, 0.044, 0.026), (0, 0, topo - 0.035 - i * 0.052), ouro))
    p.append(caixa("Pomo", (0.052, 0.046, 0.022), (0, 0, topo - 0.002), ouro))
    # guarda (tsuba) escalonada + fuchi
    p.append(caixa("Tsuba", (0.120, 0.118, 0.022), (0, 0, topo - 0.254), ouro))
    p.append(caixa("TsubaMeio", (0.082, 0.082, 0.020), (0, 0, topo - 0.272), ouro))
    p.append(caixa("Fuchi", (0.056, 0.052, 0.018), (0, 0, topo - 0.290), ouro))
    # bainha (saya) 0,58
    sy = topo - 0.30
    p.append(caixa("Saya", (0.050, 0.044, 0.58), (0, 0, sy - 0.29), roxo))
    # anel do meio com rebites
    p.append(caixa("Anel", (0.066, 0.058, 0.040), (0, 0, sy - 0.14), preto))
    for dx in (-0.02, 0.02):
        p.append(caixa("Rebite", (0.014, 0.062, 0.014), (dx, 0, sy - 0.14), ouro))
    # arabesco dourado na metade de baixo (zigue-zague de blocos)
    for i, (dx, dz) in enumerate([(0.012, 0.26), (-0.010, 0.30), (0.010, 0.34), (-0.012, 0.38),
                                  (0.008, 0.42), (-0.010, 0.46), (0.010, 0.50)]):
        p.append(caixa("Arab%d" % i, (0.024, 0.050, 0.022), (dx, 0, sy - dz), ouro))
    # ponteira
    p.append(caixa("Ponteira", (0.056, 0.050, 0.036), (0, 0, sy - 0.598), ouro))
    exportar(p, "acessorios", "espada_katana")


# ------------------------------------------------------- cabelo coque samurai
def cabelo_coque_samurai():
    """Coque alto preso com fita vermelha; franja e laterais descem até o nível
    dos olhos; nuca volumosa. Origem no centro do topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    fita = mat("Fita", (0.62, 0.08, 0.10), 0.0, 0.8)
    p = []
    # calota
    p.append(caixa("Calota", (L, P, 0.09), (0, 0, -0.045), cab))
    # franja
    p.append(caixa("Franja", (L, 0.07, 0.15), (0, P * 0.5 - 0.035, -0.075), cab))
    p.append(caixa("FranjaPonta", (0.14, 0.07, 0.07), (0.0, P * 0.5 - 0.035, -0.185), cab))
    # laterais (costeletas) até os olhos
    for s in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.62, 0.26), (s * (L * 0.5 - 0.03), -P * 0.19, -0.13), cab))
    # nuca volumosa
    p.append(caixa("Nuca", (L, 0.10, 0.34), (0, -(P * 0.5 - 0.05), -0.17), cab))
    p.append(caixa("NucaBaixa", (L * 0.8, 0.07, 0.10), (0, -(P * 0.5 - 0.035), -0.39), cab))
    # camada de volume no alto
    p.append(caixa("Volume", (L * 0.84, P * 0.70, 0.07), (0, -0.02, 0.035), cab))
    # coque (3 níveis) acima e atrás
    p.append(caixa("CoqueBase", (0.16, 0.16, 0.06), (0, -0.14, 0.095), cab))
    p.append(caixa("Coque", (0.22, 0.22, 0.12), (0, -0.14, 0.185), cab))
    p.append(caixa("CoqueTopo", (0.15, 0.15, 0.06), (0, -0.14, 0.275), cab))
    # fita vermelha
    p.append(caixa("Fita", (0.24, 0.24, 0.035), (0, -0.14, 0.115), fita))
    for s in (1, -1):
        p.append(caixa("FitaPonta", (0.032, 0.03, 0.17), (s * 0.04, -0.27, 0.01), fita))
    exportar(p, "cabelos", "cabelo_coque_samurai")


def _girar_y(partes, graus):
    """Gira o conjunto em torno do eixo Y (frente) — espada inclinada nas costas."""
    import math
    from mathutils import Matrix
    r = Matrix.Rotation(math.radians(graus), 4, "Y")
    for o in partes:
        o.matrix_world = r @ o.matrix_world
        o.data.transform(Matrix.Identity(4))
    for o in partes:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ------------------------------------------------------ espada larga cerimonial
def espada_larga_cerimonial():
    """Espadão cerimonial na bainha de couro/prata/ouro, para as COSTAS,
    inclinada ~38° (cabo sobre o ombro direito). Origem no centro da peça."""
    limpar()
    ouro = mat("Ouro", (0.80, 0.58, 0.16), 0.85, 0.35)
    prata = mat("Prata", (0.70, 0.72, 0.76), 0.85, 0.4)
    couro = mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.7)
    p = []
    topo = 0.62
    p.append(caixa("Pomo", (0.07, 0.05, 0.06), (0, 0, topo - 0.03), ouro))
    p.append(caixa("Cabo", (0.04, 0.04, 0.20), (0, 0, topo - 0.16), couro))
    for i in range(3):
        p.append(caixa("Fio", (0.046, 0.046, 0.014), (0, 0, topo - 0.09 - i * 0.055), ouro))
    p.append(caixa("Guarda", (0.32, 0.05, 0.04), (0, 0, topo - 0.28), ouro))
    for s in (1, -1):
        p.append(caixa("GuardaPonta", (0.05, 0.06, 0.07), (s * 0.165, 0, topo - 0.28), prata))
    p.append(caixa("Escudete", (0.12, 0.06, 0.12), (0, 0, topo - 0.34), ouro))
    p.append(caixa("Estrela", (0.05, 0.065, 0.05), (0, 0, topo - 0.34), prata))
    # bainha
    sx = topo - 0.40
    p.append(caixa("Bainha", (0.15, 0.05, 0.72), (0, 0, sx - 0.36), couro))
    p.append(caixa("Friso", (0.06, 0.055, 0.66), (0, 0, sx - 0.36), prata))
    for dz in (0.14, 0.40):
        p.append(caixa("Cinta", (0.17, 0.062, 0.06), (0, 0, sx - dz), couro))
        p.append(caixa("Rebite", (0.05, 0.068, 0.05), (0, 0, sx - dz), ouro))
    for i in range(5):
        p.append(caixa("Runa%d" % i, (0.10, 0.056, 0.028), (0, 0, sx - 0.55 - i * 0.04), ouro if i % 2 else prata))
    p.append(caixa("Ponteira", (0.11, 0.054, 0.06), (0, 0, sx - 0.76), ouro))
    p.append(caixa("Ponta", (0.06, 0.05, 0.05), (0, 0, sx - 0.82), ouro))
    _girar_y(p, 38)
    exportar(p, "acessorios", "espada_larga_cerimonial")


# ------------------------------------------------------------- cabelo longo liso
def cabelo_longo_liso():
    """Cabelo liso até o quadril, repartido ao meio, mechas na frente dos
    ombros. Origem no centro do topo do crânio; desce até z = -1,30."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = []
    p.append(caixa("Calota", (L, P, 0.09), (0, 0, -0.045), cab))
    # franja repartida: duas abas laterais descendo pela testa
    for s in (1, -1):
        p.append(caixa("Aba", (0.17, 0.07, 0.17), (s * 0.12, P * 0.5 - 0.035, -0.085), cab))
        p.append(caixa("AbaPonta", (0.08, 0.07, 0.08), (s * 0.17, P * 0.5 - 0.035, -0.20), cab))
        # lado do rosto até o peito (mecha frontal)
        p.append(caixa("Lado", (0.07, P * 0.62, 0.50), (s * (L * 0.5 - 0.035), -P * 0.19, -0.25), cab))
        p.append(caixa("Mecha", (0.07, 0.10, 0.80), (s * (L * 0.5 - 0.035), P * 0.5 - 0.05 - 0.1, -0.60), cab))
        p.append(caixa("MechaPonta", (0.07, 0.10, 0.12), (s * (L * 0.5 - 0.035), P * 0.5 - 0.15, -1.06), cab))
    # costas: painel largo + degraus no fim
    p.append(caixa("Costas", (L, 0.11, 1.18), (0, -(P * 0.5 - 0.055), -0.59), cab))
    p.append(caixa("CostasBaixo", (L * 0.9, 0.11, 0.10), (0, -(P * 0.5 - 0.055), -1.23), cab))
    p.append(caixa("CostasPonta", (L * 0.7, 0.11, 0.08), (0, -(P * 0.5 - 0.055), -1.32), cab))
    # volume do alto
    p.append(caixa("Volume", (L * 0.9, P * 0.8, 0.05), (0, -0.02, 0.025), cab))
    exportar(p, "cabelos", "cabelo_longo_liso")


# ------------------------------------------------------------------ chifre único
def chifre_unico():
    """Chifre único escalonado, marfim, na testa (centro, ligeiramente à frente).
    Origem no centro do topo da cabeça. Cor própria (não tinge)."""
    limpar()
    osso = mat("Chifre", (0.93, 0.85, 0.68), 0.0, 0.6)
    p = []
    y = P * 0.5 - 0.10
    larg = [0.15, 0.12, 0.09, 0.06, 0.035]
    z = -0.01
    for i, w in enumerate(larg):
        h = 0.07 if i < 4 else 0.06
        # a ponta inclina para frente: cada degrau avança um pouco em Y
        p.append(caixa("Degrau%d" % i, (w, w, h), (0, y + i * 0.012, z + h * 0.5), osso))
        z += h
    exportar(p, "acessorios", "chifre_unico")


# ---------------------------------------------------------------- capa com gola
def capa_com_gola():
    """Capa verde-azulada de gola alta, mantô sobre os ombros e saia que abre
    até a canela, com debrum claro e fecho dourado. Mesmo encaixe da
    capa_marinha: origem no topo do pescoço, pende para −Z (0,..−1,35)."""
    limpar()
    esc = mat("CapaEscura", (0.03, 0.25, 0.26), 0.0, 0.8)
    claro = mat("CapaDebrum", (0.18, 0.55, 0.56), 0.0, 0.8)
    ouro = mat("Fecho", (0.85, 0.62, 0.16), 0.85, 0.35)
    p = []
    # gola alta em volta do pescoço (aberta na frente)
    p.append(caixa("GolaTras", (0.46, 0.05, 0.17), (0, -0.20, 0.06), esc))
    p.append(caixa("GolaTrasDebrum", (0.46, 0.055, 0.03), (0, -0.20, 0.155), claro))
    for s in (1, -1):
        p.append(caixa("GolaLado", (0.05, 0.30, 0.15), (s * 0.23, -0.06, 0.05), esc))
        p.append(caixa("GolaLadoDebrum", (0.055, 0.30, 0.03), (s * 0.23, -0.06, 0.135), claro))
        p.append(caixa("GolaFrente", (0.10, 0.05, 0.10), (s * 0.16, 0.10, 0.03), esc))
    # mantô sobre os ombros (duas camadas escalonadas)
    p.append(caixa("Manto1", (0.86, 0.50, 0.10), (0, -0.07, -0.06), esc))
    p.append(caixa("Manto2", (0.94, 0.52, 0.10), (0, -0.07, -0.16), esc))
    p.append(caixa("MantoDebrum", (0.96, 0.54, 0.03), (0, -0.07, -0.225), claro))
    # saia traseira em degraus, alargando para baixo
    z = -0.24
    for i, larg in enumerate([0.78, 0.82, 0.88, 0.94, 1.00]):
        h = 0.22
        p.append(caixa("Costas%d" % i, (larg, 0.055, h), (0, -0.25, z - h * 0.5), esc))
        for s in (1, -1):
            p.append(caixa("Borda%d" % i, (0.045, 0.06, h), (s * (larg * 0.5 - 0.022), -0.25, z - h * 0.5), claro))
        z -= h
    p.append(caixa("BarraTras", (1.00, 0.06, 0.05), (0, -0.25, z + 0.025), claro))
    # panos da frente, caindo pelos lados dos braços
    for s in (1, -1):
        fx = s * 0.43
        p.append(caixa("PanoLado", (0.05, 0.36, 0.86), (fx, -0.07, -0.67), esc))
        p.append(caixa("PanoBorda", (0.055, 0.04, 0.86), (fx, 0.13, -0.67), claro))
        p.append(caixa("PanoBarra", (0.055, 0.36, 0.04), (fx, -0.07, -1.12), claro))
    # fecho dourado
    for s in (1, -1):
        p.append(caixa("FechoPino", (0.06, 0.04, 0.06), (s * 0.13, 0.13, -0.01), ouro))
    p.append(caixa("FechoBarra", (0.20, 0.025, 0.025), (0, 0.13, -0.045), ouro))
    exportar(p, "acessorios", "capa_com_gola")


# ------------------------------------------------------------- cabelo afro
def cabelo_afro_volumoso():
    """Afro grande: casca elipsoidal de cubos de tamanhos variados (semente
    fixa). Rosto aberto: nada na frente abaixo da linha da testa."""
    import random
    limpar()
    random.seed(11)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = []
    rx, ry, rz = 0.46, 0.52, 0.42
    cy, cz = -0.04, -0.10
    passo = 0.085
    nx, ny, nz = int(rx / passo) + 1, int(ry / passo) + 1, int(rz / passo) + 1
    for i in range(-nx, nx + 1):
        for j in range(-ny, ny + 1):
            for k in range(-nz, nz + 1):
                x, y, z = i * passo, cy + j * passo, cz + k * passo
                r = (x / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2
                if not (0.62 <= r <= 1.0):
                    continue
                if y > 0.18 and z < 0.0:          # rosto aberto
                    continue
                if z < -0.40 and y > -0.05:       # orelhas/pescoço livres
                    continue
                t = random.uniform(0.085, 0.135)
                p.append(caixa("F", (t, t, t), (x + random.uniform(-.012, .012),
                                                y + random.uniform(-.012, .012),
                                                z + random.uniform(-.012, .012)), cab))
    # calota que fecha o couro cabeludo
    p.append(caixa("Calota", (L, P, 0.08), (0, 0, -0.04), cab))
    exportar(p, "cabelos", "cabelo_afro_volumoso")


# -------------------------------------------------------------- chifres de oni
def chifres_oni_par():
    """Par de chifres curvos (sobem abrindo e fecham a ponta para dentro).
    Cor marfim própria. Origem no centro do topo da cabeça."""
    limpar()
    osso = mat("Chifre", (0.92, 0.78, 0.55), 0.0, 0.55)
    ponta = mat("ChifrePonta", (0.97, 0.88, 0.68), 0.0, 0.55)
    p = []
    base_x, base_y = 0.20, 0.12
    dx = [0.00, 0.035, 0.065, 0.065, 0.035]
    zz = [0.04, 0.11, 0.18, 0.25, 0.31]
    tam = [0.115, 0.10, 0.085, 0.065, 0.04]
    for s in (1, -1):
        for i in range(5):
            p.append(caixa("Chifre%d" % i, (tam[i], tam[i], 0.075),
                           (s * (base_x + dx[i]), base_y - i * 0.004, zz[i]), ponta if i == 4 else osso))
    exportar(p, "acessorios", "chifres_oni_par")


# --------------------------------------------------------- orelhas de raposa
def orelhas_gato_raposa():
    """Par de orelhas pontudas de raposa: pelo laranja, miolo creme na frente,
    ponta marrom. Origem no centro do topo da cabeça."""
    limpar()
    laranja = mat("Pelo", (0.72, 0.31, 0.10), 0.0, 0.9)
    creme = mat("Miolo", (0.95, 0.82, 0.66), 0.0, 0.9)
    ponta = mat("PontaOrelha", (0.32, 0.12, 0.06), 0.0, 0.9)
    p = []
    larg = [0.16, 0.13, 0.10, 0.065, 0.035]
    for s in (1, -1):
        x0 = s * 0.15
        z = -0.01
        for i, w in enumerate(larg):
            h = 0.06
            m = ponta if i == 4 else laranja
            p.append(caixa("Orelha%d" % i, (w, 0.075, h), (x0 + s * i * 0.012, -0.04, z + h * 0.5), m))
            if i < 4:   # miolo creme na face da frente, mais estreito
                p.append(caixa("Miolo%d" % i, (w * 0.55, 0.012, h), (x0 + s * i * 0.012, -0.04 + 0.040, z + h * 0.5), creme))
            z += h
    exportar(p, "acessorios", "orelhas_gato_raposa")


# ------------------------------------------------------------------- tapa-olho
def tapa_olho():
    """Tapa-olho de couro escuro no olho ESQUERDO do personagem (−X no Blender),
    tira diagonal pela testa e cinta em volta da cabeça com fivela dourada.
    Origem no centro da FACE FRONTAL (como as máscaras): cresce para +Y."""
    limpar()
    couro = mat("Couro", (0.13, 0.09, 0.07), 0.0, 0.75)
    borda = mat("CouroBorda", (0.22, 0.15, 0.10), 0.0, 0.75)
    ouro = mat("Fivela", (0.78, 0.58, 0.20), 0.85, 0.4)
    p = []
    px, pz = -0.12, 0.02
    p.append(caixa("Placa", (0.17, 0.035, 0.17), (px, 0.018, pz), borda))
    p.append(caixa("PlacaMiolo", (0.13, 0.045, 0.13), (px, 0.022, pz), couro))
    # tira diagonal: do tapa-olho até o alto da cabeça no lado oposto
    n = 6
    x0, z0, x1, z1 = px + 0.02, pz + 0.07, 0.25, 0.20
    for i in range(n):
        t = i / (n - 1)
        p.append(caixa("Tira%d" % i, (0.075, 0.03, 0.045),
                       (x0 + (x1 - x0) * t, 0.012, z0 + (z1 - z0) * t), couro))
    # cinta em volta (laterais, nuca) na altura z=0,20
    zc, esp = 0.20, 0.045
    p.append(caixa("CintaLadoD", (0.03, 0.76, esp), (0.265, -0.37, zc), couro))
    p.append(caixa("CintaLadoE", (0.03, 0.76, esp), (-0.265, -0.37, zc), couro))
    p.append(caixa("CintaNuca", (0.56, 0.03, esp), (0, -0.755, zc), couro))
    p.append(caixa("CintaTesta", (0.50, 0.03, esp), (0, 0.012, zc), couro))
    p.append(caixa("Fivela", (0.07, 0.04, 0.065), (0.268, -0.30, zc), ouro))
    exportar(p, "acessorios", "tapa_olho")


# -------------------------------------------------------------- asas pequenas
def asas_pequenas():
    """Par de asas pequenas de penas (marrom → creme) nas omoplatas, em V.
    Mesmo encaixe da capa: origem no topo do pescoço, atrás do tronco."""
    limpar()
    cores = [(0.52, 0.31, 0.16), (0.62, 0.40, 0.22), (0.76, 0.55, 0.35), (0.88, 0.72, 0.52), (0.96, 0.86, 0.70)]
    p = []
    for s in (1, -1):
        # osso/ombro da asa, marrom escuro, subindo para fora
        for i in range(4):
            p.append(caixa("Osso%d" % i, (0.09, 0.05, 0.05), (s * (0.08 + i * 0.075), -0.17, 0.015 + i * 0.012), mat("Osso", (0.42, 0.24, 0.12), 0.0, 0.8)))
        # penas: 7 colunas, mais compridas para fora; duas camadas de cor
        for i in range(7):
            x = s * (0.12 + i * 0.065)
            top = 0.0 - i * 0.006
            for linha in range(5):
                h = 0.075
                comp = 0.06 + i * 0.012
                p.append(caixa("Pena", (0.062, 0.04 + linha * 0.002, h),
                               (x, -0.18 - linha * 0.012, top - 0.04 - linha * h * 0.92 - 0.0),
                               mat("Pena%d" % linha, cores[linha], 0.0, 0.85)))
                if linha * h > comp + 0.12:
                    break
    exportar(p, "acessorios", "asas_pequenas")


# ---------------------------------------------------------------- bandana
def bandana_faixa():
    """Faixa vermelha na testa com nó e duas pontas caindo atrás. Origem no
    centro do topo da cabeça (como os cabelos)."""
    limpar()
    verm = mat("Faixa", (0.70, 0.06, 0.08), 0.0, 0.8)
    escuro = mat("FaixaSombra", (0.50, 0.04, 0.06), 0.0, 0.8)
    p = []
    zc, h, g = -0.12, 0.13, 0.02
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p.append(caixa("Frente", (larg, 0.035, h), (0, prof * 0.5 - 0.017, zc), verm))
    p.append(caixa("Tras", (larg, 0.035, h), (0, -(prof * 0.5 - 0.017), zc), verm))
    for s in (1, -1):
        p.append(caixa("Lado", (0.035, prof, h), (s * (larg * 0.5 - 0.017), 0, zc), verm))
    yk = -prof * 0.5 - 0.03
    p.append(caixa("No", (0.10, 0.07, 0.09), (0, yk, zc), escuro))
    p.append(caixa("NoCentro", (0.06, 0.08, 0.06), (0, yk - 0.005, zc), verm))
    for s in (1, -1):
        for i in range(3):
            p.append(caixa("Ponta%d" % i, (0.05, 0.03, 0.07), (s * (0.04 + i * 0.022), yk - 0.04 - i * 0.012, zc - 0.07 - i * 0.065), verm))
    exportar(p, "acessorios", "bandana_faixa")


# ------------------------------------------------------------- cauda de raposa
def cauda_raposa():
    """Cauda volumosa de raposa (laranja → creme na ponta). Origem no nó Torso
    (quadril): base colada às costas (y=−0,13), cai e curva para trás."""
    limpar()
    cores = [(0.62, 0.22, 0.07), (0.70, 0.28, 0.08), (0.78, 0.36, 0.12), (0.86, 0.48, 0.20),
             (0.92, 0.62, 0.36), (0.96, 0.78, 0.58), (0.98, 0.90, 0.78)]
    larg = [0.09, 0.13, 0.17, 0.19, 0.20, 0.19, 0.17, 0.14, 0.10, 0.06]
    p = []
    n = len(larg)
    for i, w in enumerate(larg):
        t = i / (n - 1)
        y = -0.15 - 0.20 * t ** 1.6
        z = 0.10 - i * 0.085
        c = cores[min(int(t * len(cores) + (0.4 if t > 0.55 else 0)), len(cores) - 1)]
        m = mat("Pelo%d" % int(t * 10), c, 0.0, 0.9)
        p.append(caixa("Seg%d" % i, (w, w * 0.9, 0.095), (0, y, z), m))
        if 1 <= i <= n - 2:   # tufos de pelo nas laterais, mais claros que o miolo
            for s in (1, -1):
                p.append(caixa("Tufo", (0.05, w * 0.7, 0.07), (s * (w * 0.5 + 0.01), y + 0.01, z - 0.02), m))
    exportar(p, "acessorios", "cauda_raposa")


# ---------------------------------------------------------- jaqueta curta (malha)
def jaqueta_curta():
    """Jaqueta curta de gola alta, em 3 GLBs (tronco no Chest, manga_sup no
    UpperArm, manga_inf no ForeArm), como o moletom. Material "Jaqueta" é
    tingido pela cor da roupa; "Vinco" escurece (costuras/zíper); "Punho"
    clareia (a dobra da manga)."""
    jq = lambda: mat("Jaqueta", (0.48, 0.12, 0.20), 0.0, 0.9)
    vinco = lambda: mat("Vinco", (0.35, 0.08, 0.14), 0.0, 0.9)
    punho = lambda: mat("Punho", (0.62, 0.20, 0.30), 0.0, 0.9)
    # tronco: relativo ao Chest (−0,36 … +0,25)
    limpar()
    p = [caixa("Corpo", (0.535, 0.355, 0.50), (0, 0, -0.03), jq()),
         caixa("Barra", (0.55, 0.37, 0.07), (0, 0, -0.275), punho()),
         caixa("GolaTras", (0.30, 0.05, 0.12), (0, -0.115, 0.31), jq()),
         caixa("GolaFrente", (0.30, 0.05, 0.12), (0, 0.115, 0.31), jq()),
         caixa("GolaEsq", (0.05, 0.28, 0.12), (-0.125, 0, 0.31), jq()),
         caixa("GolaDir", (0.05, 0.28, 0.12), (0.125, 0, 0.31), jq()),
         caixa("Ziper", (0.022, 0.02, 0.50), (0, 0.185, -0.03), vinco()),
         caixa("CostCostaE", (0.02, 0.02, 0.34), (-0.12, -0.185, 0.0), vinco()),
         caixa("CostCostaD", (0.02, 0.02, 0.34), (0.12, -0.185, 0.0), vinco()),
         caixa("Ombro", (0.55, 0.37, 0.03), (0, 0, 0.245), vinco())]
    exportar(p, "roupas", "jaqueta_tronco")
    limpar()
    p = [caixa("Manga", (0.29, 0.29, 0.33), (0, 0, -0.15), jq()),
         caixa("Ombro", (0.30, 0.30, 0.08), (0, 0, -0.01), jq()),
         caixa("Vinco", (0.02, 0.30, 0.30), (0.145, 0, -0.15), vinco())]
    exportar(p, "roupas", "jaqueta_manga_sup")
    limpar()
    p = [caixa("Manga", (0.285, 0.285, 0.11), (0, 0, -0.045), jq()),
         caixa("Dobra", (0.315, 0.315, 0.105), (0, 0, -0.16), punho()),
         caixa("DobraBorda", (0.32, 0.32, 0.02), (0, 0, -0.11), vinco())]
    exportar(p, "roupas", "jaqueta_manga_inf")


# ----------------------------------------------- casaco longo de capitão (malha)
def casaco_capitao():
    """Casaco naval longo: base azul-marinho tingível; debrum/botões/dragonas em
    material "Ouro" (cor fixa). Quatro GLBs: tronco (Chest), saia (Torso),
    manga_sup (UpperArm), manga_inf (ForeArm). Frente aberta com vão central."""
    az = lambda: mat("Casaco", (0.10, 0.13, 0.30), 0.0, 0.85)
    ouro = lambda: mat("Ouro", (0.90, 0.68, 0.14), 0.7, 0.4)
    forro = lambda: mat("Forro", (0.05, 0.06, 0.15), 0.0, 0.9)
    limpar()
    p = []
    for s in (1, -1):
        p.append(caixa("Painel", (0.245, 0.37, 0.57), (s * 0.1475, 0, -0.025), az()))
        p.append(caixa("Debrum", (0.03, 0.378, 0.57), (s * 0.0375, 0.0, -0.025), ouro()))
        for k in range(3):
            p.append(caixa("Botao", (0.045, 0.03, 0.045), (s * 0.10, 0.19, 0.10 - k * 0.13), ouro()))
        p.append(caixa("GolaLado", (0.05, 0.30, 0.14), (s * 0.13, 0, 0.31), az()))
        p.append(caixa("GolaDebrum", (0.052, 0.31, 0.03), (s * 0.13, 0, 0.385), ouro()))
        p.append(caixa("GolaFrente", (0.09, 0.05, 0.14), (s * 0.09, 0.125, 0.31), az()))
    p.append(caixa("GolaTras", (0.30, 0.05, 0.14), (0, -0.125, 0.31), az()))
    p.append(caixa("GolaTrasDebrum", (0.30, 0.052, 0.03), (0, -0.125, 0.385), ouro()))
    p.append(caixa("Peito", (0.06, 0.34, 0.50), (0, -0.01, -0.01), forro()))
    p.append(caixa("PlacaCosta", (0.20, 0.02, 0.07), (0, -0.19, -0.27), ouro()))
    exportar(p, "roupas", "casaco_capitao_tronco")
    limpar()
    p = []
    for s in (1, -1):
        p.append(caixa("Aba", (0.235, 0.34, 0.72), (s * 0.15, 0, -0.19), az()))
        p.append(caixa("AbaDebrum", (0.03, 0.348, 0.72), (s * 0.0375, 0.0, -0.19), ouro()))
        p.append(caixa("Bolso", (0.09, 0.02, 0.05), (s * 0.18, 0.175, -0.10), ouro()))
    p.append(caixa("Costas", (0.56, 0.05, 0.72), (0, -0.165, -0.19), az()))
    p.append(caixa("Fenda", (0.03, 0.054, 0.30), (0, -0.165, -0.30), ouro()))
    p.append(caixa("Barra", (0.57, 0.36, 0.04), (0, 0, -0.56), ouro()))
    exportar(p, "roupas", "casaco_capitao_saia")
    limpar()
    p = [caixa("Manga", (0.29, 0.29, 0.33), (0, 0, -0.15), az()),
         caixa("Ombro", (0.30, 0.30, 0.08), (0, 0, -0.01), az()),
         caixa("Dragona", (0.31, 0.31, 0.03), (0, 0, 0.045), ouro())]
    for i in range(5):
        p.append(caixa("Franja", (0.03, 0.31, 0.07), (0.12 - i * 0.06, 0, 0.065 - 0.0), ouro()))
    exportar(p, "roupas", "casaco_capitao_manga_sup")
    limpar()
    p = [caixa("Manga", (0.285, 0.285, 0.11), (0, 0, -0.045), az()),
         caixa("Punho", (0.315, 0.315, 0.105), (0, 0, -0.16), az()),
         caixa("Faixa", (0.32, 0.32, 0.025), (0, 0, -0.13), ouro()),
         caixa("FaixaBaixo", (0.32, 0.32, 0.02), (0, 0, -0.205), ouro()),
         caixa("Botao1", (0.04, 0.04, 0.04), (0, 0.16, -0.16), ouro()),
         caixa("Botao2", (0.04, 0.04, 0.04), (0, -0.16, -0.16), ouro())]
    exportar(p, "roupas", "casaco_capitao_manga_inf")


# ------------------------------------------------------------ ombreira + bandoleira
def ombreira_armadura():
    """Ombreira de aço escovado com debrum de bronze no ombro DIREITO do
    personagem (+X no Blender), bandoleira de couro cruzando o peito até o
    quadril oposto e cinto com fivelas. Origem no nó Chest (topo = +0,25)."""
    limpar()
    aco = mat("Aco", (0.22, 0.24, 0.27), 0.6, 0.5)
    bronze = mat("Bronze", (0.62, 0.40, 0.14), 0.8, 0.4)
    couro = mat("Couro", (0.24, 0.13, 0.07), 0.0, 0.75)
    p = []
    cx = 0.335
    p.append(caixa("Placa", (0.19, 0.34, 0.09), (cx, 0, 0.215), aco))
    p.append(caixa("PlacaBorda", (0.21, 0.36, 0.035), (cx, 0, 0.275), bronze))
    p.append(caixa("PlacaTopo", (0.15, 0.30, 0.04), (cx - 0.02, 0, 0.31), bronze))
    for i in range(3):   # lâminas escalonadas descendo pelo lado de fora
        p.append(caixa("Lamina%d" % i, (0.06, 0.32 - i * 0.04, 0.07), (cx + 0.115 + i * 0.03, 0, 0.19 - i * 0.075), aco))
        p.append(caixa("LaminaBorda%d" % i, (0.065, 0.335 - i * 0.04, 0.02), (cx + 0.115 + i * 0.03, 0, 0.15 - i * 0.075), bronze))
    p.append(caixa("Rebite", (0.04, 0.04, 0.04), (cx + 0.05, 0.19, 0.22), bronze))
    # bandoleira diagonal: ombro direito (+X) -> quadril esquerdo (-X), na frente e nas costas
    n = 9
    for lado in (1, -1):
        y = lado * 0.19
        for i in range(n):
            t = i / (n - 1)
            x = 0.20 - 0.40 * t
            z = 0.20 - 0.50 * t
            p.append(caixa("Tira", (0.075, 0.025, 0.075), (x, y, z), couro))
    p.append(caixa("Fivela", (0.09, 0.03, 0.09), (0.0, 0.2, -0.02), bronze))
    # cinto
    zc = -0.27
    p.append(caixa("CintoF", (0.55, 0.03, 0.06), (0, 0.19, zc), couro))
    p.append(caixa("CintoT", (0.55, 0.03, 0.06), (0, -0.19, zc), couro))
    for s in (1, -1):
        p.append(caixa("CintoL", (0.03, 0.37, 0.06), (s * 0.275, 0, zc), couro))
        p.append(caixa("CintoFivela", (0.04, 0.035, 0.08), (s * 0.20, 0.2, zc), bronze))
    exportar(p, "acessorios", "ombreira_armadura")


# --------------------------------------------------------- cachecol vermelho
def cachecol_longo_vermelho():
    """Cachecol de duas voltas no pescoço e duas pontas com franja na frente.
    Coordenadas relativas ao nó Chest (topo do tronco = +0,25); sem offset."""
    limpar()
    v1 = mat("Cachecol", (0.78, 0.05, 0.06), 0.0, 0.85)
    v2 = mat("CachecolSombra", (0.55, 0.03, 0.04), 0.0, 0.85)
    p = []
    for i, (w, d, z, m) in enumerate([(0.40, 0.36, 0.265, v1), (0.44, 0.40, 0.305, v2), (0.38, 0.34, 0.345, v1)]):
        p.append(caixa("Volta%d" % i, (w, d, 0.05), (0, -0.01 * i, z), m))
    p.append(caixa("Nozinho", (0.14, 0.05, 0.12), (0.10, 0.205, 0.27), v2))
    for s in (1, -1):
        x = s * 0.115
        p.append(caixa("Ponta", (0.13, 0.04, 0.80), (x, 0.205, -0.15), v1))
        p.append(caixa("Dobra", (0.13, 0.05, 0.05), (x, 0.205, 0.20), v2))
        for k in range(5):
            p.append(caixa("Franja", (0.02, 0.04, 0.07), (x - 0.05 + k * 0.025, 0.205, -0.585), v1))
    p.append(caixa("Costas", (0.16, 0.04, 0.40), (0.06, -0.185, 0.05), v2))
    exportar(p, "acessorios", "cachecol_longo_vermelho")


# ------------------------------------------------------ botas altas com fivelas
def botas_altas_fivelas():
    """Bota alta de couro com duas cintas e fivelas de prata. Pivô no nó Foot:
    sola em z=−0,10, cano sobe até +0,24 (quase o joelho). Toe = +Y."""
    limpar()
    couro = mat("Couro", (0.30, 0.16, 0.09), 0.0, 0.7)
    escuro = mat("CouroEscuro", (0.18, 0.09, 0.05), 0.0, 0.7)
    prata = mat("Prata", (0.74, 0.75, 0.78), 0.9, 0.35)
    p = [caixa("Sola", (0.29, 0.34, 0.035), (0, 0.0, -0.0825), escuro),
         caixa("Salto", (0.27, 0.10, 0.03), (0, -0.115, -0.1), escuro),
         caixa("Pe", (0.275, 0.33, 0.085), (0, 0.0, -0.025), couro),
         caixa("Bico", (0.25, 0.06, 0.07), (0, 0.19, -0.04), couro),
         caixa("Cano", (0.30, 0.285, 0.29), (0, -0.01, 0.12), couro),
         caixa("Boca", (0.315, 0.30, 0.05), (0, -0.01, 0.255), escuro)]
    for z in (0.17, 0.0):
        p.append(caixa("Cinta", (0.318, 0.298, 0.05), (0, -0.01, z), escuro))
        for s in (1, -1):
            p.append(caixa("Fivela", (0.03, 0.06, 0.065), (s * 0.165, -0.01, z), prata))
    exportar(p, "acessorios", "botas_altas_fivelas")


# -------------------------------------------------------- luvas de couro com garras
def luvas_couro_garras():
    """Luva de couro com punho de cinta, fivela e quatro garras de aço. Pivô no
    nó Hand (punho): a peça vai nas DUAS mãos. Garras para baixo (−Z)."""
    limpar()
    couro = mat("Couro", (0.48, 0.24, 0.12), 0.0, 0.7)
    escuro = mat("CouroEscuro", (0.30, 0.15, 0.08), 0.0, 0.7)
    aco = mat("Aco", (0.78, 0.80, 0.84), 0.9, 0.3)
    p = [caixa("Punho", (0.26, 0.26, 0.10), (0, 0, 0.05), escuro),
         caixa("PunhoFivela", (0.07, 0.03, 0.07), (0, 0.135, 0.05), aco),
         caixa("Palma", (0.205, 0.155, 0.11), (0, 0, -0.055), couro),
         caixa("Placa", (0.14, 0.02, 0.07), (0, 0.085, -0.06), escuro),
         caixa("Dedos", (0.20, 0.15, 0.04), (0, 0, -0.13), couro)]
    for i in range(4):
        x = -0.075 + i * 0.05
        p.append(caixa("Nodo", (0.04, 0.04, 0.025), (x, 0.0, -0.165), aco))
        p.append(caixa("Garra%d" % i, (0.022, 0.03, 0.085), (x, 0.0, -0.22), aco))
        p.append(caixa("PontaGarra%d" % i, (0.012, 0.02, 0.04), (x, 0.0, -0.285), aco))
    exportar(p, "acessorios", "luvas_couro_garras")


# ------------------------------------------------------------ chapéu tricórnio
def chapeu_pirata_tricornio():
    """Tricórnio preto com debrum dourado: aba com três abas levantadas (frente,
    esquerda e direita) e copa baixa. Origem no centro do topo da cabeça."""
    limpar()
    preto = mat("Chapeu", (0.07, 0.07, 0.08), 0.0, 0.8)
    ouro = mat("Ouro", (0.84, 0.62, 0.14), 0.8, 0.4)
    p = [caixa("Copa", (0.46, 0.62, 0.17), (0, 0, 0.085), preto),
         caixa("CopaTopo", (0.38, 0.50, 0.03), (0, 0, 0.185), preto),
         caixa("Aba", (0.66, 0.90, 0.035), (0, 0, 0.0), preto)]
    for sx in (1, -1):
        p.append(caixa("AbaLado", (0.045, 0.84, 0.11), (sx * 0.345, 0, 0.065), preto))
        p.append(caixa("AbaLadoDebrum", (0.05, 0.86, 0.025), (sx * 0.345, 0, 0.13), ouro))
        p.append(caixa("Quina", (0.07, 0.07, 0.10), (sx * 0.345, 0.43, 0.07), ouro))
    p.append(caixa("AbaFrente", (0.56, 0.045, 0.11), (0, 0.45, 0.065), preto))
    p.append(caixa("AbaFrenteDebrum", (0.58, 0.05, 0.025), (0, 0.45, 0.13), ouro))
    p.append(caixa("AbaTras", (0.60, 0.04, 0.09), (0, -0.44, 0.055), preto))
    p.append(caixa("AbaTrasDebrum", (0.62, 0.045, 0.02), (0, -0.44, 0.11), ouro))
    exportar(p, "acessorios", "chapeu_pirata_tricornio")


# ------------------------------------------------------------- chapéu de bruxa
def chapeu_feiticeiro_bruxa():
    """Chapéu pontudo roxo escalonado com fita lilás, fivela dourada e ponta
    dobrada para trás. Origem no centro do topo da cabeça."""
    limpar()
    roxo = mat("Roxo", (0.27, 0.07, 0.42), 0.0, 0.85)
    claro = mat("RoxoClaro", (0.50, 0.18, 0.68), 0.0, 0.85)
    ouro = mat("Ouro", (0.88, 0.66, 0.14), 0.8, 0.4)
    p = [caixa("Aba", (0.86, 0.96, 0.035), (0, 0, 0.0), roxo),
         caixa("Aba2", (0.74, 0.84, 0.03), (0, 0, 0.03), roxo),
         caixa("Fita", (0.54, 0.64, 0.07), (0, 0, 0.085), claro),
         caixa("Fivela", (0.10, 0.04, 0.09), (0, 0.325, 0.085), ouro)]
    larg = [0.48, 0.42, 0.36, 0.30, 0.25, 0.20, 0.15]
    z = 0.12
    for i, w in enumerate(larg):
        p.append(caixa("Camada%d" % i, (w, w * 1.12, 0.095), (0, -0.025 * i, z + 0.0475), roxo))
        z += 0.095
    p.append(caixa("Ponta1", (0.10, 0.10, 0.09), (0.0, -0.20, z + 0.045), roxo))
    p.append(caixa("Ponta2", (0.08, 0.08, 0.08), (0.04, -0.24, z + 0.12), roxo))
    p.append(caixa("Ponta3", (0.06, 0.06, 0.06), (0.09, -0.26, z + 0.16), roxo))
    exportar(p, "acessorios", "chapeu_feiticeiro_bruxa")


# ------------------------------------------------------------- cabelo trança lateral
def cabelo_tranca_lateral():
    """Cabelo ondulado volumoso preso numa trança grossa que cai pelo ombro do
    lado esquerdo do personagem (−X). Origem no centro do topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    fita = mat("Fita", (0.78, 0.40, 0.14), 0.0, 0.8)
    p = [caixa("Calota", (L + 0.03, P + 0.03, 0.12), (0, 0, -0.04), cab),
         caixa("VolumeTopo", (L * 0.9, P * 0.85, 0.07), (0, -0.02, 0.045), cab),
         caixa("Franja", (L + 0.02, 0.08, 0.17), (0, P * 0.5 - 0.02, -0.10), cab),
         caixa("Costas", (L + 0.03, 0.14, 0.50), (0, -(P * 0.5 - 0.05), -0.25), cab),
         caixa("CostasBaixo", (L * 0.8, 0.12, 0.12), (0, -(P * 0.5 - 0.04), -0.56), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.07, P * 0.68, 0.40), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.20), cab))
        p.append(caixa("Mecha", (0.07, 0.09, 0.26), (sx * (L * 0.5 - 0.0), P * 0.5 - 0.09, -0.19), cab))
    # trança: segmentos zigue-zague caindo pelo ombro esquerdo
    for i in range(9):
        dx = 0.035 if i % 2 else -0.035
        p.append(caixa("Tranca%d" % i, (0.13, 0.11, 0.095), (-0.20 + dx, P * 0.5 - 0.20, -0.48 - i * 0.085), cab))
    p.append(caixa("Elo", (0.10, 0.13, 0.045), (-0.20, P * 0.5 - 0.20, -1.20), fita))
    p.append(caixa("Ponta", (0.08, 0.08, 0.10), (-0.20, P * 0.5 - 0.20, -1.28), cab))
    exportar(p, "cabelos", "cabelo_tranca_lateral")


# ------------------------------------------------------------- cabelo rabo duplo
def cabelo_rabo_duplo():
    """Dois rabos altos nas laterais da cabeça, franja reta e topo liso. Os
    rabos caem em mechas de comprimentos diferentes até z=−0,72."""
    import random
    limpar()
    random.seed(5)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab),
         caixa("Topo", (L * 0.82, P * 0.70, 0.05), (0, -0.02, 0.025), cab),
         caixa("Franja", (L, 0.07, 0.16), (0, P * 0.5 - 0.035, -0.08), cab),
         caixa("FranjaPonta", (0.30, 0.07, 0.07), (0, P * 0.5 - 0.035, -0.19), cab),
         caixa("Costas", (L, 0.10, 0.36), (0, -(P * 0.5 - 0.05), -0.18), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.30), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.15), cab))
        p.append(caixa("Elo", (0.15, 0.24, 0.12), (sx * (L * 0.5 + 0.06), -0.10, 0.0), cab))
        for k in range(4):
            y = -0.20 + k * 0.10
            comp = random.uniform(0.50, 0.72)
            p.append(caixa("Mecha", (0.095, 0.095, comp), (sx * (L * 0.5 + 0.11), y, -comp * 0.5 - 0.02), cab))
    exportar(p, "cabelos", "cabelo_rabo_duplo")


# ---------------------------------------------------------- cabelo ruivo baguncado
def cabelo_ruivo_curto_baguncado():
    """Cabelo curto desgrenhado: calota, franja irregular, mechas e tufos em
    todas as direções (semente fixa) e uma mecha comprida sobre o olho esquerdo."""
    import random
    limpar()
    random.seed(23)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab),
         caixa("Nuca", (L, 0.11, 0.26), (0, -(P * 0.5 - 0.055), -0.13), cab),
         caixa("NucaBaixa", (L * 0.8, 0.10, 0.10), (0, -(P * 0.5 - 0.05), -0.30), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.22), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.11), cab))
    for i in range(34):
        x = random.uniform(-L * 0.45, L * 0.45)
        y = random.uniform(-P * 0.42, P * 0.44)
        h = random.uniform(0.06, 0.17)
        w = random.uniform(0.06, 0.11)
        p.append(caixa("Tufo%d" % i, (w, w, h), (x, y, h * 0.5 - 0.01), cab))
    for i in range(10):    # franja irregular
        x = -L * 0.45 + i * (L * 0.9 / 9)
        h = random.uniform(0.08, 0.20)
        p.append(caixa("FranjaT%d" % i, (0.07, 0.06, h), (x, P * 0.5 - 0.03, -h * 0.5 - 0.02), cab))
    for i in range(4):     # mecha comprida sobre o olho esquerdo (−X)
        p.append(caixa("Mecha%d" % i, (0.075, 0.07, 0.08), (-0.13 + i * 0.012 * -1, P * 0.5 - 0.02, -0.12 - i * 0.075), cab))
    exportar(p, "cabelos", "cabelo_ruivo_curto_baguncado")


# ------------------------------------------------------------------- headset
def fone_ouvido_headset():
    """Headset: arco sobre a cabeça, duas conchas nas orelhas (azul/preto) e
    microfone na lateral esquerda (−X) até a boca. Origem no topo da cabeça."""
    limpar()
    preto = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)
    azul = mat("Azul", (0.15, 0.38, 0.85), 0.0, 0.6)
    p = [caixa("Arco", (0.56, 0.09, 0.05), (0, -0.0, 0.045), preto),
         caixa("ArcoAzul", (0.40, 0.07, 0.03), (0, 0, 0.082), azul)]
    for sx in (1, -1):
        p.append(caixa("Haste", (0.05, 0.09, 0.28), (sx * 0.28, 0, -0.10), preto))
        p.append(caixa("Concha", (0.09, 0.25, 0.25), (sx * 0.30, -0.02, -0.25), preto))
        p.append(caixa("ConchaAzul", (0.095, 0.15, 0.15), (sx * 0.31, -0.02, -0.25), azul))
    # microfone: do lado esquerdo até a frente da boca
    for i, (x, y, z) in enumerate([(-0.30, 0.10, -0.34), (-0.27, 0.22, -0.39), (-0.20, 0.31, -0.42), (-0.12, 0.37, -0.43)]):
        p.append(caixa("Boom%d" % i, (0.03, 0.10, 0.03), (x, y, z), preto))
    p.append(caixa("Mic", (0.06, 0.06, 0.06), (-0.10, 0.40, -0.43), azul))
    exportar(p, "acessorios", "fone_ouvido_headset")


# ---------------------------------------------- duas espadas cruzadas nas costas
def bainhas_duas_espadas_cruzadas():
    """Duas bainhas em X nas costas (cabos sobre os ombros: um vermelho, um
    azul), arnês de couro com cinta e fivela no peito. Relativo ao nó Chest."""
    limpar()
    escura = mat("Bainha", (0.10, 0.09, 0.11), 0.0, 0.6)
    ouro = mat("Ouro", (0.86, 0.64, 0.15), 0.8, 0.4)
    couro = mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.75)
    cores = [mat("Vermelho", (0.78, 0.10, 0.10), 0.2, 0.5), mat("Azul", (0.15, 0.35, 0.80), 0.2, 0.5)]
    y = -0.225
    for sinal, pomo in ((1, cores[0]), (-1, cores[1])):
        parte = [caixa("Bainha", (0.075, 0.05, 0.62), (0, y, -0.14), escura),
                 caixa("Boca", (0.09, 0.055, 0.05), (0, y, 0.19), ouro),
                 caixa("Guarda", (0.15, 0.05, 0.03), (0, y, 0.225), ouro),
                 caixa("Cabo", (0.04, 0.045, 0.16), (0, y, 0.32), couro),
                 caixa("Pomo", (0.06, 0.05, 0.05), (0, y, 0.425), pomo),
                 caixa("Ponteira", (0.09, 0.055, 0.10), (0, y, -0.45), ouro),
                 caixa("Vinco", (0.05, 0.055, 0.04), (0, y, -0.40), ouro)]
        _girar_y(parte, 32 * sinal)
        _mantem.extend(parte)
    p = list(_mantem)
    _mantem.clear()
    # arnês: tiras verticais na frente e cruzando atrás
    for sx in (1, -1):
        p.append(caixa("TiraF", (0.06, 0.03, 0.56), (sx * 0.13, 0.19, 0.0), couro))
        p.append(caixa("TiraOmbro", (0.06, 0.40, 0.03), (sx * 0.13, -0.02, 0.255), couro))
        p.append(caixa("TiraT", (0.06, 0.03, 0.56), (sx * 0.13, -0.19, 0.0), couro))
    p.append(caixa("CintaPeito", (0.40, 0.03, 0.05), (0, 0.195, 0.05), couro))
    p.append(caixa("Fivela", (0.07, 0.035, 0.07), (0, 0.205, 0.05), ouro))
    p.append(caixa("CintaCintura", (0.55, 0.03, 0.05), (0, 0.195, -0.26), couro))
    exportar(p, "acessorios", "bainhas_duas_espadas_cruzadas")


_mantem: list = []


# --------------------------------------------------------- braçadeiras de metal
def bracadeiras_metal():
    """Braçadeira de aço com debrum e gema de bronze, no antebraço (nó ForeArm,
    pivô no cotovelo). Uma peça para os dois braços."""
    limpar()
    aco = mat("Aco", (0.40, 0.42, 0.46), 0.8, 0.45)
    bronze = mat("Bronze", (0.70, 0.46, 0.14), 0.8, 0.4)
    p = [caixa("Corpo", (0.285, 0.285, 0.13), (0, 0, -0.10), aco),
         caixa("BordaCima", (0.30, 0.30, 0.03), (0, 0, -0.025), bronze),
         caixa("BordaBaixo", (0.30, 0.30, 0.03), (0, 0, -0.175), bronze),
         caixa("Gema", (0.05, 0.03, 0.06), (0, 0.155, -0.10), bronze),
         caixa("Placa", (0.12, 0.02, 0.09), (0, 0.15, -0.10), bronze),
         caixa("Placa2", (0.09, 0.02, 0.07), (0, -0.15, -0.10), bronze)]
    exportar(p, "acessorios", "bracadeiras_metal")


# --------------------------------------------------------------- mochila de viagem
def mochila_viagem():
    """Mochila de lona e couro com aba, fivelas e bolsos laterais; alças sobre
    os ombros. Relativo ao nó Chest (costas = −Y)."""
    limpar()
    lona = mat("Lona", (0.62, 0.48, 0.30), 0.0, 0.9)
    couro = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.75)
    ouro = mat("Fivela", (0.82, 0.62, 0.20), 0.8, 0.4)
    p = [caixa("Corpo", (0.36, 0.17, 0.42), (0, -0.27, -0.04), lona),
         caixa("Aba", (0.38, 0.19, 0.18), (0, -0.275, 0.12), couro),
         caixa("BolsoBaixo", (0.30, 0.07, 0.17), (0, -0.375, -0.14), lona),
         caixa("Rolo", (0.34, 0.11, 0.11), (0, -0.27, -0.30), couro)]
    for sx in (1, -1):
        p.append(caixa("BolsoLado", (0.07, 0.13, 0.20), (sx * 0.215, -0.27, -0.06), lona))
        p.append(caixa("Cinta", (0.03, 0.20, 0.30), (sx * 0.10, -0.27, 0.05), couro))
        p.append(caixa("Fivela", (0.05, 0.03, 0.05), (sx * 0.10, -0.375, 0.07), ouro))
        p.append(caixa("AlcaOmbro", (0.07, 0.40, 0.03), (sx * 0.13, -0.02, 0.255), couro))
        p.append(caixa("AlcaFrente", (0.07, 0.03, 0.46), (sx * 0.13, 0.19, 0.01), couro))
        p.append(caixa("AlcaTras", (0.07, 0.03, 0.30), (sx * 0.13, -0.19, 0.08), couro))
    p.append(caixa("Peitoral", (0.26, 0.03, 0.04), (0, 0.195, 0.05), couro))
    p.append(caixa("PeitoralFivela", (0.05, 0.035, 0.06), (0, 0.205, 0.05), ouro))
    exportar(p, "acessorios", "mochila_viagem")


# ------------------------------------------------------------------ colar pingente
def colar_pingente():
    """Cordão preto em volta do pescoço com pingente quadrado dourado.
    Relativo ao nó Chest."""
    limpar()
    cordao = mat("Cordao", (0.08, 0.08, 0.09), 0.0, 0.8)
    ouro = mat("Ouro", (0.92, 0.70, 0.14), 0.9, 0.3)
    p = [caixa("AroT", (0.34, 0.02, 0.025), (0, -0.14, 0.255), cordao),
         caixa("AroE", (0.02, 0.30, 0.025), (-0.17, 0.0, 0.255), cordao),
         caixa("AroD", (0.02, 0.30, 0.025), (0.17, 0.0, 0.255), cordao)]
    for sx in (1, -1):
        for i in range(3):
            t = i / 2
            p.append(caixa("V%d" % i, (0.03, 0.02, 0.05), (sx * (0.15 - 0.13 * t), 0.17, 0.235 - 0.09 * t - 0.0), cordao))
    p.append(caixa("Argola", (0.03, 0.02, 0.03), (0, 0.175, 0.085), ouro))
    p.append(caixa("Pingente", (0.07, 0.03, 0.07), (0, 0.185, 0.045), ouro))
    p.append(caixa("PingenteBrilho", (0.035, 0.035, 0.035), (0, 0.195, 0.045), mat("Brilho", (1.0, 0.88, 0.45), 0.9, 0.2)))
    exportar(p, "acessorios", "colar_pingente")


# --------------------------------------------------------------- óculos de aviador
def oculos_aviador_testa():
    """Óculos de aviador (aros de latão, lentes escuras) sobre a testa, com
    tira de couro e fivela atrás. Origem no centro do topo da cabeça."""
    limpar()
    latao = mat("Latao", (0.62, 0.40, 0.14), 0.8, 0.4)
    lente = mat("Lente", (0.04, 0.05, 0.07), 0.4, 0.2)
    couro = mat("Couro", (0.34, 0.18, 0.09), 0.0, 0.75)
    ouro = mat("Fivela", (0.84, 0.64, 0.18), 0.8, 0.4)
    zc = -0.07
    yf = P * 0.5 + 0.03
    p = []
    for sx in (1, -1):
        p.append(caixa("Aro", (0.20, 0.07, 0.17), (sx * 0.115, yf, zc), latao))
        p.append(caixa("Lente", (0.15, 0.075, 0.11), (sx * 0.115, yf + 0.004, zc), lente))
    p.append(caixa("Ponte", (0.05, 0.05, 0.04), (0, yf, zc), latao))
    p.append(caixa("TiraF", (0.53, 0.04, 0.07), (0, P * 0.5 + 0.005, zc), couro))
    for sx in (1, -1):
        p.append(caixa("TiraL", (0.035, P + 0.02, 0.07), (sx * 0.267, 0, zc), couro))
    p.append(caixa("TiraT", (0.53, 0.035, 0.07), (0, -P * 0.5 - 0.005, zc), couro))
    p.append(caixa("Fivela", (0.08, 0.04, 0.085), (0, -P * 0.5 - 0.02, zc), ouro))
    exportar(p, "acessorios", "oculos_aviador_testa")


def caixa_rot(nome, tam, centro, m, graus_z=0.0, graus_x=0.0):
    """Caixa girada (em Z e/ou X) em torno do próprio centro."""
    import math
    o = caixa(nome, tam, (0.0, 0.0, 0.0), m)      # em 0,0,0: caixa() assa a posição na malha
    o.rotation_euler = (math.radians(graus_x), 0.0, math.radians(graus_z))
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = centro
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return o


# ------------------------------------------------------------------- lanterna
def lanterna_mao():
    """Lanterna de moldura dourada com vidro âmbar brilhante, pendurada na mão
    DIREITA (nó Hand_R). Alça logo abaixo do punho; 0,10 × 0,10 × 0,20."""
    limpar()
    ouro = mat("Moldura", (0.70, 0.46, 0.12), 0.8, 0.4)
    vidro = mat("Vidro", (1.0, 0.62, 0.12), 0.0, 0.3)
    b = next(n for n in vidro.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Emission Color"].default_value = (1.0, 0.55, 0.10, 1.0)
    b.inputs["Emission Strength"].default_value = 2.5
    p = [caixa("Alca", (0.09, 0.02, 0.02), (0, 0, -0.145), ouro),
         caixa("AlcaE", (0.02, 0.02, 0.05), (-0.04, 0, -0.17), ouro),
         caixa("AlcaD", (0.02, 0.02, 0.05), (0.04, 0.0, -0.17), ouro),
         caixa("Tampa", (0.13, 0.13, 0.04), (0, 0, -0.215), ouro),
         caixa("Vidro", (0.10, 0.10, 0.17), (0, 0, -0.32), vidro),
         caixa("Base", (0.13, 0.13, 0.04), (0, 0, -0.425), ouro)]
    for sx in (1, -1):
        for sy in (1, -1):
            p.append(caixa("Coluna", (0.025, 0.025, 0.19), (sx * 0.055, sy * 0.055, -0.32), ouro))
    exportar(p, "acessorios", "lanterna_mao")


# ----------------------------------------------------------- escudo redondo
def escudo_redondo_costas():
    """Escudo redondo de madeira com aro de ferro rebitado e umbo central, nas
    costas, com arnês de couro no peito. Relativo ao nó Chest."""
    import math
    limpar()
    madeira = mat("Madeira", (0.46, 0.27, 0.12), 0.0, 0.8)
    ferro = mat("Ferro", (0.50, 0.52, 0.56), 0.8, 0.45)
    couro = mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.75)
    ouro = mat("Fivela", (0.82, 0.62, 0.20), 0.8, 0.4)
    p = []
    y = -0.25

    def disco(nome, raio, prof, y_, m, verts=12):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=raio, depth=prof,
                                            location=(0, y_, 0.02), rotation=(math.pi / 2, 0, 0))
        o = bpy.context.active_object
        o.name = nome
        bpy.ops.object.transform_apply(rotation=True)
        o.data.materials.append(m)
        return o
    p.append(disco("Aro", 0.33, 0.055, y, ferro))
    p.append(disco("Tabua", 0.29, 0.07, y - 0.0, madeira))
    p.append(disco("Umbo", 0.085, 0.10, y - 0.04, ferro, 8))
    for k in range(6):
        a = k * math.pi / 3
        p.append(caixa("Rebite", (0.035, 0.03, 0.035), (0.31 * math.cos(a), y - 0.03, 0.02 + 0.31 * math.sin(a)), ferro))
    for sx in (-0.1, 0.0, 0.1):    # tábuas verticais (relevo)
        p.append(caixa("Veio", (0.012, 0.075, 0.46), (sx, y - 0.005, 0.02), couro))
    for sx in (1, -1):
        p.append(caixa("TiraF", (0.06, 0.03, 0.56), (sx * 0.13, 0.19, 0.0), couro))
        p.append(caixa("TiraOmbro", (0.06, 0.40, 0.03), (sx * 0.13, -0.02, 0.255), couro))
        p.append(caixa("TiraT", (0.06, 0.03, 0.40), (sx * 0.13, -0.19, 0.06), couro))
    p.append(caixa("Peitoral", (0.30, 0.03, 0.05), (0, 0.195, 0.06), couro))
    p.append(caixa("Fivela", (0.06, 0.035, 0.06), (0, 0.205, 0.06), ouro))
    exportar(p, "acessorios", "escudo_redondo_costas")


# ---------------------------------------------------------- coroa de louros
def coroa_louros():
    """Coroa de louros: folhas verdes em fileira em volta da cabeça, abrindo em V
    atrás, com tufo de folhas na testa. Origem no topo da cabeça."""
    import math
    limpar()
    v1 = mat("Louro", (0.22, 0.52, 0.12), 0.0, 0.8)
    v2 = mat("LouroClaro", (0.38, 0.68, 0.18), 0.0, 0.8)
    p = []
    zc = -0.045
    n = 22
    for i in range(n):
        t = i / n * 2 * math.pi
        x = 0.272 * math.cos(t)
        y = 0.392 * math.sin(t)
        ang = math.degrees(t) + 90 + (28 if i % 2 else -28)
        p.append(caixa_rot("Folha%d" % i, (0.10, 0.05, 0.045), (x, y, zc + (0.012 if i % 2 else 0.0)), v2 if i % 2 else v1, ang))
    p.append(caixa("Talo", (0.52, 0.02, 0.02), (0, 0.405, zc), mat("Talo", (0.18, 0.36, 0.10), 0.0, 0.9)))
    exportar(p, "acessorios", "coroa_louros")


# ------------------------------------------------ katana + wakizashi na direita
def katana_wakizashi_cintura_direita():
    """Katana e wakizashi lado a lado no quadril DIREITO (+X): bainha preta,
    cabo vermelho/preto com ouro, cordão vermelho (sageo). Mesma origem e
    encaixe da katana: nó Torso, pendurado na vertical."""
    limpar()
    preta = mat("Saya", (0.06, 0.05, 0.06), 0.0, 0.6)
    ouro = mat("Ouro", (0.86, 0.64, 0.16), 0.85, 0.35)
    cabo = mat("Cabo", (0.45, 0.06, 0.07), 0.0, 0.7)
    cordao = mat("Cordao", (0.70, 0.08, 0.10), 0.0, 0.8)
    p = []

    def espada(x, y, topo, comp):
        p.append(caixa("Cabo", (0.042, 0.038, 0.20 if comp > 0.8 else 0.15), (x, y, topo - (0.10 if comp > 0.8 else 0.075)), cabo))
        p.append(caixa("Pomo", (0.048, 0.044, 0.02), (x, y, topo), ouro))
        p.append(caixa("Tsuba", (0.10, 0.10, 0.02), (x, y, topo - (0.21 if comp > 0.8 else 0.16)), ouro))
        s0 = topo - (0.23 if comp > 0.8 else 0.18)
        p.append(caixa("Saya", (0.046, 0.04, comp), (x, y, s0 - comp * 0.5), preta))
        p.append(caixa("Ponteira", (0.052, 0.046, 0.03), (x, y, s0 - comp), ouro))
        p.append(caixa("Boca", (0.052, 0.046, 0.025), (x, y, s0 - 0.015), ouro))
    espada(0.0, 0.0, 0.48, 0.66)
    espada(-0.065, 0.03, 0.30, 0.50)
    p.append(caixa("Cordao", (0.03, 0.03, 0.12), (-0.03, 0.05, 0.13), cordao))
    p.append(caixa("No", (0.05, 0.03, 0.05), (-0.03, 0.05, 0.19), cordao))
    p.append(caixa("Borla", (0.04, 0.03, 0.06), (-0.03, 0.05, 0.04), cordao))
    exportar(p, "acessorios", "katana_wakizashi_cintura_direita")


# ---------------------------------------------------------------- capuz e manto
def capuz_manto():
    """Capuz azul-marinho sobre a cabeça (rosto aberto) e mantelete sobre os
    ombros, numa peça só presa ao nó Chest: a cabeça fica em z +0,25…+0,73
    (caixa 0,48). Sem offset de posição."""
    limpar()
    az = mat("Manto", (0.07, 0.11, 0.50), 0.0, 0.85)
    esc = mat("MantoSombra", (0.04, 0.07, 0.34), 0.0, 0.85)
    p = [caixa("CapuzTras", (0.62, 0.08, 0.52), (0, -0.295, 0.50), az),
         caixa("CapuzTopo", (0.62, 0.58, 0.08), (0, -0.01, 0.80), az),
         caixa("CapuzPonta", (0.40, 0.24, 0.10), (0, -0.18, 0.89), az)]
    for sx in (1, -1):
        p.append(caixa("CapuzLado", (0.07, 0.58, 0.54), (sx * 0.305, -0.01, 0.52), az))
        p.append(caixa("CapuzFrente", (0.10, 0.08, 0.50), (sx * 0.25, 0.28, 0.50), az))
        p.append(caixa("CapuzBorda", (0.10, 0.06, 0.12), (sx * 0.25, 0.30, 0.74), esc))
    p.append(caixa("CapuzBrim", (0.60, 0.07, 0.10), (0, 0.285, 0.78), az))
    # mantelete em camadas sobre os ombros
    p.append(caixa("Manto1", (0.82, 0.50, 0.08), (0, -0.01, 0.24), az))
    p.append(caixa("Manto2", (0.94, 0.54, 0.08), (0, -0.01, 0.16), az))
    p.append(caixa("Manto3", (1.04, 0.58, 0.07), (0, -0.01, 0.085), esc))
    for i in range(7):
        x = -0.45 + i * 0.15
        p.append(caixa("Barra%d" % i, (0.15, 0.58, 0.06), (x, -0.01, 0.02 if i % 2 else 0.035), az))
    p.append(caixa("CostasPano", (0.84, 0.07, 0.34), (0, -0.30, -0.02), az))
    exportar(p, "acessorios", "capuz_manto")


# -------------------------------------------------------------- máscara de oni
def mascara_oni():
    """Máscara de oni vermelha (sobrancelhas franzidas, presas, mandíbula) com
    dois chifres de marfim e tira preta com fivela. Origem no centro da FACE
    FRONTAL, como as outras máscaras: cresce para +Y; face ±0,25 em X e Z."""
    limpar()
    verm = mat("Vermelho", (0.70, 0.06, 0.06), 0.0, 0.6)
    escuro = mat("VermelhoEscuro", (0.40, 0.03, 0.04), 0.0, 0.6)
    osso = mat("Marfim", (0.95, 0.88, 0.72), 0.0, 0.5)
    preto = mat("Preto", (0.04, 0.04, 0.05), 0.0, 0.7)
    p = [caixa("Placa", (0.46, 0.06, 0.46), (0, 0.03, 0.0), verm),
         caixa("Testa", (0.40, 0.04, 0.10), (0, 0.08, 0.17), verm),
         caixa("Sobrancelha", (0.44, 0.05, 0.07), (0, 0.085, 0.085), escuro),
         caixa("Nariz", (0.09, 0.07, 0.15), (0, 0.095, -0.03), verm),
         caixa("NarizPonta", (0.14, 0.05, 0.05), (0, 0.11, -0.09), verm),
         caixa("Queixo", (0.30, 0.06, 0.08), (0, 0.09, -0.21), verm),
         caixa("Boca", (0.32, 0.035, 0.075), (0, 0.075, -0.145), preto)]
    for sx in (1, -1):
        p.append(caixa("Orbita", (0.13, 0.04, 0.085), (sx * 0.115, 0.085, 0.035), preto))
        p.append(caixa("Olho", (0.07, 0.03, 0.035), (sx * 0.115, 0.1, 0.03), osso))
        p.append(caixa("Bochecha", (0.12, 0.06, 0.10), (sx * 0.15, 0.085, -0.10), verm))
        p.append(caixa("Presa", (0.04, 0.05, 0.13), (sx * 0.115, 0.095, -0.175), osso))
        # chifre: três degraus subindo e abrindo
        for i in range(3):
            p.append(caixa("Chifre%d" % i, (0.075 - i * 0.02, 0.06 - i * 0.012, 0.06), (sx * (0.14 + i * 0.03), 0.04, 0.255 + i * 0.055), osso))
    for i in range(5):
        p.append(caixa("Dente", (0.03, 0.04, 0.045), (-0.06 + i * 0.03, 0.095, -0.135), osso))
    # tira preta em volta da cabeça na altura dos olhos + fivela quadrada
    zc = 0.05
    for sx in (1, -1):
        p.append(caixa("TiraL", (0.03, 0.76, 0.06), (sx * 0.265, -0.37, zc), preto))
    p.append(caixa("TiraT", (0.54, 0.03, 0.06), (0, -0.755, zc), preto))
    p.append(caixa("Fivela", (0.065, 0.05, 0.085), (0.268, -0.24, zc), preto))
    p.append(caixa("FivelaMiolo", (0.04, 0.055, 0.05), (0.268, -0.24, zc), osso))
    exportar(p, "acessorios", "mascara_oni")


# ------------------------------------------------------------ kimono (malha)
def kimono_yukata():
    """Kimono aberto de mangas largas com obi vermelho. Quatro GLBs: tronco
    (Chest), saia (Torso), manga_sup (UpperArm), manga_inf (ForeArm). Material
    "Casaco" é tingido pela cor da roupa; "Obi" tem cor fixa; "Vinco" escurece."""
    az = lambda: mat("Casaco", (0.12, 0.13, 0.38), 0.0, 0.9)
    gola = lambda: mat("Vinco", (0.08, 0.09, 0.28), 0.0, 0.9)
    obi = lambda: mat("Obi", (0.72, 0.08, 0.10), 0.0, 0.85)
    limpar()
    p = []
    for sx in (1, -1):
        p.append(caixa("Painel", (0.235, 0.37, 0.58), (sx * 0.1625, 0, -0.04), az()))
        p.append(caixa("Gola", (0.06, 0.385, 0.58), (sx * 0.075, 0, -0.04), gola()))
    p.append(caixa("Costas", (0.55, 0.04, 0.58), (0, -0.19, -0.04), az()))
    p.append(caixa("GolaNuca", (0.30, 0.20, 0.06), (0, -0.06, 0.26), gola()))
    p.append(caixa("Obi", (0.58, 0.40, 0.13), (0, 0, -0.24), obi()))
    p.append(caixa("ObiNo", (0.14, 0.05, 0.16), (0, -0.225, -0.24), obi()))
    exportar(p, "roupas", "kimono_tronco")
    limpar()
    p = []
    for sx in (1, -1):
        p.append(caixa("Aba", (0.245, 0.36, 0.70), (sx * 0.1675, 0, -0.19), az()))
        p.append(caixa("Borda", (0.05, 0.37, 0.70), (sx * 0.0625, 0, -0.19), gola()))
    p.append(caixa("Costas", (0.57, 0.05, 0.70), (0, -0.175, -0.19), az()))
    p.append(caixa("Barra", (0.585, 0.375, 0.04), (0, 0, -0.55), gola()))
    exportar(p, "roupas", "kimono_saia")
    limpar()
    exportar([caixa("Manga", (0.30, 0.34, 0.34), (0, 0, -0.15), az()),
              caixa("Ombro", (0.31, 0.33, 0.07), (0, 0, -0.01), az())], "roupas", "kimono_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.34, 0.46, 0.20), (0, 0, -0.11), az()),
              caixa("Barra", (0.35, 0.47, 0.03), (0, 0, -0.21), gola()),
              caixa("Dobra", (0.34, 0.14, 0.12), (0, 0, -0.17), az())], "roupas", "kimono_manga_inf")


# ----------------------------------------------------------- armadura de aço (malha)
def armadura_aco():
    """Peitoral de aço com debrum de bronze e ombreiras em lâminas, correias de
    couro. Dois GLBs: tronco (Chest) e ombro (UpperArm). Materiais "Aco" e
    "Bronze" com cor fixa; "Couro" fica marrom."""
    aco = lambda: mat("Aco", (0.70, 0.72, 0.76), 0.9, 0.35)
    bronze = lambda: mat("Bronze", (0.72, 0.46, 0.14), 0.85, 0.4)
    couro = lambda: mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.75)
    limpar()
    p = [caixa("PeitoCima", (0.46, 0.05, 0.27), (0, 0.19, 0.10), aco()),
         caixa("PeitoBaixo", (0.36, 0.05, 0.22), (0, 0.19, -0.14), aco()),
         caixa("PeitoPonta", (0.22, 0.05, 0.08), (0, 0.19, -0.28), aco()),
         caixa("DebrumCima", (0.48, 0.055, 0.035), (0, 0.19, 0.24), bronze()),
         caixa("DebrumMeio", (0.38, 0.055, 0.03), (0, 0.19, -0.02), bronze()),
         caixa("DebrumBaixo", (0.24, 0.055, 0.03), (0, 0.19, -0.33), bronze()),
         caixa("Costas", (0.46, 0.05, 0.56), (0, -0.19, -0.02), aco()),
         caixa("CostasDebrum", (0.48, 0.055, 0.03), (0, -0.19, 0.25), bronze())]
    for sx in (1, -1):
        p.append(caixa("Correia", (0.06, 0.40, 0.03), (sx * 0.15, -0.0, 0.265), couro()))
        p.append(caixa("CorreiaF", (0.05, 0.03, 0.12), (sx * 0.15, 0.20, 0.27), couro()))
        p.append(caixa("Fivela", (0.05, 0.06, 0.05), (sx * 0.26, 0.0, -0.10), bronze()))
        p.append(caixa("Lateral", (0.03, 0.30, 0.36), (sx * 0.27, 0, -0.06), aco()))
    p.append(caixa("Cinta", (0.58, 0.40, 0.05), (0, 0, -0.30), couro()))
    exportar(p, "roupas", "armadura_tronco")
    limpar()
    p = [caixa("Lamina1", (0.31, 0.31, 0.07), (0, 0, 0.03), aco()),
         caixa("Debrum1", (0.325, 0.325, 0.025), (0, 0, 0.07), bronze()),
         caixa("Lamina2", (0.33, 0.33, 0.07), (0.0, 0, -0.04), aco()),
         caixa("Debrum2", (0.34, 0.34, 0.02), (0, 0, -0.08), bronze()),
         caixa("Lamina3", (0.35, 0.34, 0.07), (0.0, 0, -0.11), aco()),
         caixa("Debrum3", (0.36, 0.35, 0.02), (0, 0, -0.15), bronze()),
         caixa("Braco", (0.25, 0.25, 0.30), (0, 0, -0.17), couro())]
    exportar(p, "roupas", "armadura_ombro")


# ------------------------------------------------------ capa de chuva (malha)
def capa_chuva_amarela():
    """Capa de chuva longa com capuz e botões-toggle. Quatro GLBs: tronco com o
    capuz (Chest; a cabeça fica em z +0,25…+0,73), saia (Torso), manga_sup e
    manga_inf. "Casaco" é tingido pela cor da roupa; "Preto" = toggles."""
    am = lambda: mat("Casaco", (0.92, 0.70, 0.08), 0.0, 0.35)
    vinco = lambda: mat("Vinco", (0.75, 0.55, 0.05), 0.0, 0.4)
    preto = lambda: mat("Preto", (0.05, 0.05, 0.06), 0.0, 0.7)
    limpar()
    p = [caixa("Corpo", (0.56, 0.38, 0.62), (0, 0, -0.05), am()),
         caixa("Gola", (0.32, 0.30, 0.07), (0, 0, 0.27), vinco()),
         caixa("CapuzTras", (0.64, 0.10, 0.54), (0, -0.30, 0.50), am()),
         caixa("CapuzTopo", (0.64, 0.60, 0.09), (0, -0.01, 0.81), am()),
         caixa("CapuzPonta", (0.44, 0.30, 0.10), (0, -0.15, 0.90), am()),
         caixa("CapuzBrim", (0.62, 0.08, 0.11), (0, 0.285, 0.77), am()),
         caixa("Frente", (0.025, 0.02, 0.58), (0, 0.195, -0.05), vinco())]
    for sx in (1, -1):
        p.append(caixa("CapuzLado", (0.08, 0.60, 0.56), (sx * 0.32, -0.01, 0.52), am()))
        p.append(caixa("CapuzFrente", (0.11, 0.09, 0.50), (sx * 0.265, 0.285, 0.50), am()))
        p.append(caixa("Cordao", (0.02, 0.02, 0.18), (sx * 0.12, 0.2, 0.15), preto()))
    for k in range(3):
        p.append(caixa("Toggle", (0.09, 0.035, 0.035), (0.04, 0.205, 0.10 - k * 0.20), preto()))
    exportar(p, "roupas", "capa_chuva_tronco")
    limpar()
    p = [caixa("Saia", (0.60, 0.40, 0.76), (0, 0, -0.21), am()),
         caixa("Frente", (0.025, 0.02, 0.76), (0, 0.205, -0.21), vinco()),
         caixa("Barra", (0.61, 0.41, 0.035), (0, 0, -0.575), vinco())]
    for sx in (1, -1):
        p.append(caixa("Bolso", (0.15, 0.04, 0.17), (sx * 0.17, 0.21, -0.28), vinco()))
        p.append(caixa("BolsoAba", (0.16, 0.045, 0.05), (sx * 0.17, 0.215, -0.20), am()))
    exportar(p, "roupas", "capa_chuva_saia")
    limpar()
    exportar([caixa("Manga", (0.31, 0.31, 0.34), (0, 0, -0.15), am()),
              caixa("Ombro", (0.32, 0.32, 0.07), (0, 0, -0.01), am())], "roupas", "capa_chuva_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.30, 0.30, 0.20), (0, 0, -0.10), am()),
              caixa("Punho", (0.32, 0.32, 0.05), (0, 0, -0.19), vinco())], "roupas", "capa_chuva_manga_inf")


# -------------------------------------------------------------- cabelo mohawk
def cabelo_mohawk_punk():
    """Moicano punk em degraus (alto no meio), laterais raspadas (só uma casca
    fina). Origem no centro do topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Casca", (L, P, 0.035), (0, 0, -0.0175), cab)]
    n = 9
    for i in range(n):
        t = i / (n - 1)
        alt = 0.10 + 0.20 * (1 - abs(2 * t - 1) ** 1.5)
        y = -P * 0.46 + i * (P * 0.92 / (n - 1))
        p.append(caixa("Fio%d" % i, (0.14, P * 0.92 / n + 0.005, alt), (0, y, alt * 0.5 - 0.01), cab))
        if alt > 0.17:
            p.append(caixa("Pico%d" % i, (0.09, P * 0.92 / n, 0.06), (0, y - 0.01 * (1 if t > 0.5 else -1), alt + 0.02), cab))
    p.append(caixa("Nuca", (0.16, 0.08, 0.22), (0, -(P * 0.5 - 0.04), -0.11), cab))
    p.append(caixa("Franja", (0.16, 0.07, 0.10), (0, P * 0.5 - 0.035, -0.05), cab))
    exportar(p, "cabelos", "cabelo_mohawk_punk")


# -------------------------------------------------------------- máscara de gás
def mascara_gas_respirador():
    """Respirador de duas latas com tira preta sobre a cabeça e em volta.
    Origem no centro da FACE FRONTAL (±0,25 em X e Z), cresce para +Y."""
    limpar()
    preto = mat("Preto", (0.06, 0.06, 0.07), 0.0, 0.6)
    cinza = mat("Cinza", (0.28, 0.29, 0.32), 0.5, 0.5)
    prata = mat("Prata", (0.70, 0.72, 0.76), 0.9, 0.3)
    p = [caixa("Corpo", (0.30, 0.10, 0.24), (0, 0.05, -0.13), preto),
         caixa("Focinho", (0.18, 0.06, 0.14), (0, 0.12, -0.15), cinza)]
    for sx in (1, -1):
        p.append(caixa("Lata", (0.15, 0.12, 0.17), (sx * 0.20, 0.06, -0.13), cinza))
        p.append(caixa("Grade", (0.12, 0.03, 0.13), (sx * 0.20, 0.13, -0.13), prata))
        p.append(caixa("GradeMiolo", (0.06, 0.035, 0.06), (sx * 0.20, 0.14, -0.13), preto))
        p.append(caixa("TiraL", (0.03, 0.76, 0.05), (sx * 0.265, -0.37, -0.03), preto))
    p.append(caixa("TiraT", (0.54, 0.03, 0.05), (0, -0.755, -0.03), preto))
    p.append(caixa("TiraTopo", (0.05, 0.78, 0.03), (0, -0.37, 0.265), preto))
    p.append(caixa("TiraTopoF", (0.05, 0.03, 0.30), (0, 0.0, 0.11), preto))
    exportar(p, "acessorios", "mascara_gas_respirador")


# ---------------------------------------------------------------- barba cheia
def barba_cheia_bigode():
    """Barba cheia com bigode e costeletas. Origem no centro da FACE FRONTAL;
    cor própria (castanho)."""
    limpar()
    pelo = mat("Barba", (0.27, 0.15, 0.09), 0.0, 0.95)
    p = [caixa("Queixo", (0.46, 0.09, 0.14), (0, 0.045, -0.19), pelo),
         caixa("QueixoBaixo", (0.38, 0.11, 0.07), (0, 0.055, -0.265), pelo),
         caixa("Ponta", (0.20, 0.12, 0.06), (0, 0.07, -0.31), pelo),
         caixa("Bigode", (0.30, 0.07, 0.055), (0, 0.075, -0.085), pelo),
         caixa("BigodeE", (0.07, 0.08, 0.08), (-0.17, 0.065, -0.11), pelo),
         caixa("BigodeD", (0.07, 0.08, 0.08), (0.17, 0.065, -0.11), pelo)]
    for sx in (1, -1):
        p.append(caixa("Costeleta", (0.05, 0.34, 0.22), (sx * 0.265, -0.17, -0.07), pelo))
        p.append(caixa("Barba", (0.05, 0.30, 0.12), (sx * 0.265, -0.15, -0.22), pelo))
    exportar(p, "acessorios", "barba_cheia_bigode")


# -------------------------------------------------------- cabelo coque + palitos
def cabelo_coque_alto_palitos():
    """Coque alto preso por dois palitos dourados com pingentes vermelhos;
    franja repartida e laterais recolhidas. Origem no topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    ouro = mat("Ouro", (0.90, 0.68, 0.15), 0.8, 0.4)
    verm = mat("Pingente", (0.70, 0.08, 0.10), 0.0, 0.6)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab),
         caixa("Franja", (L, 0.07, 0.15), (0, P * 0.5 - 0.035, -0.075), cab),
         caixa("Nuca", (L, 0.10, 0.28), (0, -(P * 0.5 - 0.05), -0.14), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.26), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.13), cab))
        p.append(caixa("Aba", (0.14, 0.07, 0.17), (sx * 0.12, P * 0.5 - 0.035, -0.085), cab))
    p.append(caixa("CoqueBase", (0.26, 0.26, 0.07), (0, -0.05, 0.035), cab))
    p.append(caixa("Coque", (0.30, 0.30, 0.13), (0, -0.05, 0.14), cab))
    p.append(caixa("CoqueTopo", (0.22, 0.22, 0.08), (0, -0.05, 0.245), cab))
    for sx, ang in ((1, 22), (-1, -22)):
        pal = [caixa_rot("Palito", (0.02, 0.02, 0.26), (sx * 0.06, -0.05, 0.14), ouro, 0, 0)]
        p += pal
        p.append(caixa("Ponta", (0.035, 0.035, 0.035), (sx * 0.14, -0.05, 0.27), ouro))
        p.append(caixa("Fio", (0.012, 0.012, 0.10), (sx * 0.14, -0.05, 0.19), ouro))
        p.append(caixa("Pingente", (0.03, 0.03, 0.05), (sx * 0.14, -0.05, 0.11), verm))
    exportar(p, "cabelos", "cabelo_coque_alto_palitos")


# ------------------------------------------------------------ cabelo bob chanel
def cabelo_bob_chanel_franja():
    """Chanel na altura do queixo com franja reta cobrindo a testa. Origem no
    topo do crânio; desce até z = −0,50."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab),
         caixa("Volume", (L * 0.9, P * 0.85, 0.05), (0, -0.01, 0.03), cab),
         caixa("Franja", (L + 0.02, 0.08, 0.20), (0, P * 0.5 - 0.01, -0.10), cab),
         caixa("Costas", (L + 0.04, 0.12, 0.52), (0, -(P * 0.5 - 0.04), -0.26), cab),
         caixa("CostasBaixo", (L * 0.9, 0.10, 0.07), (0, -(P * 0.5 - 0.03), -0.55), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.7, 0.44), (sx * (L * 0.5 + 0.01), -P * 0.10, -0.22), cab))
        p.append(caixa("LadoFrente", (0.08, 0.09, 0.30), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.15), cab))
        p.append(caixa("LadoBaixo", (0.08, P * 0.6, 0.06), (sx * (L * 0.5 + 0.015), -P * 0.12, -0.47), cab))
    exportar(p, "cabelos", "cabelo_bob_chanel_franja")


# ------------------------------------------------------ vestido de gala (malha)
def vestido_gala():
    """Vestido longo azul-marinho com debrum dourado: corpete de decote reto,
    saia ampla em camadas até o chão e mangas compridas. Quatro GLBs (tronco
    Chest, saia Torso, manga_sup, manga_inf). "Casaco" tingível; "Ouro" fixo."""
    az = lambda: mat("Casaco", (0.07, 0.11, 0.32), 0.0, 0.85)
    ouro = lambda: mat("Ouro", (0.90, 0.68, 0.14), 0.7, 0.4)
    esc = lambda: mat("Vinco", (0.04, 0.07, 0.22), 0.0, 0.85)
    limpar()
    p = [caixa("Corpete", (0.545, 0.37, 0.56), (0, 0, -0.07), az()),
         caixa("Decote", (0.20, 0.04, 0.05), (0, 0.19, 0.20), ouro()),
         caixa("DecoteBorda", (0.34, 0.04, 0.03), (0, 0.19, 0.225), ouro()),
         caixa("Cintura", (0.56, 0.38, 0.04), (0, 0, -0.31), ouro()),
         caixa("Costas", (0.545, 0.04, 0.60), (0, -0.19, -0.05), az()),
         caixa("OmbroE", (0.12, 0.30, 0.04), (-0.205, 0.0, 0.265), ouro()),
         caixa("OmbroD", (0.12, 0.30, 0.04), (0.205, 0.0, 0.265), ouro())]
    exportar(p, "roupas", "vestido_tronco")
    limpar()
    p = []
    camadas = [(0.58, 0.40, 0.20, 0.17), (0.68, 0.48, 0.20, -0.03), (0.80, 0.58, 0.20, -0.23), (0.94, 0.68, 0.20, -0.43), (1.04, 0.76, 0.12, -0.59)]
    for i, (w, d, h, z) in enumerate(camadas):
        p.append(caixa("Saia%d" % i, (w, d, h), (0, 0, z - h * 0.5 + 0.0), az() if i % 2 == 0 else esc()))
    p.append(caixa("Barra", (1.06, 0.78, 0.035), (0, 0, -0.66), ouro()))
    for i, z in enumerate((-0.10, -0.32)):
        p.append(caixa("FaixaOuro%d" % i, (0.04, 0.42 + i * 0.12, 0.26), (0.20 + i * 0.10, 0.0, z), ouro()))
    exportar(p, "roupas", "vestido_saia")
    limpar()
    exportar([caixa("Manga", (0.275, 0.275, 0.34), (0, 0, -0.15), az()),
              caixa("Ombro", (0.29, 0.29, 0.06), (0, 0, 0.0), ouro())], "roupas", "vestido_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.27, 0.27, 0.15), (0, 0, -0.075), az()),
              caixa("Punho", (0.285, 0.285, 0.035), (0, 0, -0.20), ouro())], "roupas", "vestido_manga_inf")


# ------------------------------------------------ camisa de pirata + colete (malha)
def camisa_pirata():
    """Camisa creme de mangas bufantes com babados no peito e nos punhos, e
    colete bordô com botões dourados. Três GLBs (tronco, manga_sup, manga_inf).
    "Casaco" (colete) é tingível; "Branco" e "Ouro" são fixos."""
    cam = lambda: mat("Branco", (0.93, 0.89, 0.78), 0.0, 0.9)
    col = lambda: mat("Casaco", (0.45, 0.07, 0.13), 0.0, 0.85)
    ouro = lambda: mat("Ouro", (0.90, 0.68, 0.14), 0.7, 0.4)
    limpar()
    p = [caixa("Camisa", (0.54, 0.36, 0.60), (0, 0, -0.05), cam()),
         caixa("Jabo", (0.20, 0.07, 0.22), (0, 0.19, 0.12), cam()),
         caixa("JaboBaixo", (0.14, 0.07, 0.12), (0, 0.195, -0.02), cam()),
         caixa("Gola", (0.32, 0.30, 0.07), (0, 0, 0.27), cam()),
         caixa("ColeteCosta", (0.545, 0.04, 0.50), (0, -0.19, -0.08), col()),
         caixa("CinchaCosta", (0.22, 0.045, 0.05), (0, -0.2, -0.20), ouro())]
    for sx in (1, -1):
        p.append(caixa("Colete", (0.17, 0.05, 0.50), (sx * 0.185, 0.19, -0.07), col()))
        p.append(caixa("ColeteOmbro", (0.12, 0.38, 0.03), (sx * 0.225, 0, 0.255), col()))
        p.append(caixa("ColeteLado", (0.05, 0.36, 0.50), (sx * 0.27, 0, -0.07), col()))
    for k in range(4):
        p.append(caixa("Botao", (0.035, 0.03, 0.035), (0.14, 0.22, 0.05 - k * 0.1), ouro()))
        p.append(caixa("Botao", (0.035, 0.03, 0.035), (-0.14, 0.22, 0.05 - k * 0.1), ouro()))
    exportar(p, "roupas", "pirata_tronco")
    limpar()
    exportar([caixa("Manga", (0.31, 0.31, 0.35), (0, 0, -0.14), cam()),
              caixa("Ombro", (0.32, 0.32, 0.06), (0, 0, 0.0), cam())], "roupas", "pirata_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.33, 0.33, 0.12), (0, 0, -0.06), cam()),
              caixa("Babado1", (0.38, 0.38, 0.04), (0, 0, -0.14), cam()),
              caixa("Babado2", (0.35, 0.35, 0.04), (0, 0, -0.19), cam()),
              caixa("Babado3", (0.32, 0.32, 0.03), (0, 0, -0.225), cam())], "roupas", "pirata_manga_inf")


def malha_plana(nome, verts, faces, m):
    """Membrana de dupla face: duas cópias separadas por 1 cm em Y, com
    enrolamentos opostos (o exportador funde faces idênticas e o glTF/Godot
    descarta a face de trás)."""
    n = len(verts)
    vv = [(x, y + 0.005, z) for x, y, z in verts] + [(x, y - 0.005, z) for x, y, z in verts]
    ff = list(faces) + [tuple(n + i for i in reversed(f)) for f in faces]
    me = bpy.data.meshes.new(nome)
    me.from_pydata(vv, [], ff)
    me.update()
    o = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    return o


def osso(nome, a, b, larg, m):
    """Caixa longa de a até b (ambos no plano XZ, y = a[1])."""
    import math
    dx, dz = b[0] - a[0], b[2] - a[2]
    comp = math.hypot(dx, dz)
    o = caixa(nome, (comp, larg, larg), (0, 0, 0), m)
    o.rotation_euler = (0.0, -math.atan2(dz, dx), 0.0)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = ((a[0] + b[0]) / 2, a[1], (a[2] + b[2]) / 2)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return o


# ----------------------------------------------------------- cauda de dragão
def cauda_dragao_lagarto():
    """Cauda longa de dragão (verde-escuro, espinhos claros no dorso). Origem no
    nó Torso; base nas costas, curva para trás e para baixo."""
    limpar()
    esc = mat("Escama", (0.10, 0.30, 0.13), 0.0, 0.7)
    claro = mat("Espinho", (0.42, 0.68, 0.22), 0.0, 0.7)
    p = []
    n = 13
    for i in range(n):
        t = i / (n - 1)
        w = 0.17 * (1 - t) + 0.03
        y = -0.15 - 0.62 * t ** 1.5
        z = 0.08 - 0.95 * t
        p.append(caixa("Seg%d" % i, (w, w * 0.9, 0.095), (0, y, z), esc))
        if 0 < i < n - 1:
            p.append(caixa("Espinho", (0.04, 0.06 + 0.05 * (1 - t), 0.05), (0, y - w * 0.45 - 0.03, z), claro))
    exportar(p, "acessorios", "cauda_dragao_lagarto")


# -------------------------------------------------------------- tentáculos
def tentaculos_bracos_extras():
    """Dois tentáculos roxos saindo das omoplatas, subindo e enrolando para
    fora, com ventosas claras. Relativo ao nó Chest."""
    import math
    limpar()
    roxo = mat("Tentaculo", (0.33, 0.12, 0.48), 0.0, 0.6)
    vent = mat("Ventosa", (0.78, 0.58, 0.88), 0.0, 0.5)
    p = []
    n = 16
    for sx in (1, -1):
        for i in range(n):
            t = i / (n - 1)
            ang = t * math.pi * 1.55
            x = sx * (0.18 + 0.30 * math.sin(ang * 0.85) - 0.0)
            z = 0.12 + 0.95 * math.sin(ang * 0.62) - 0.05 * t
            w = 0.14 * (1 - t) + 0.035
            p.append(caixa("Seg%d" % i, (w, w, w), (x, -0.22, z), roxo))
            if i % 2 == 1 and i < n - 2:
                p.append(caixa("Ventosa", (w * 0.5, w * 0.5, w * 0.5), (x - sx * w * 0.5, -0.22 + w * 0.5, z), vent))
    exportar(p, "acessorios", "tentaculos_bracos_extras")


# ------------------------------------------------------ auréola + asas de anjo
def aureola_asas_anjo():
    """Auréola dourada flutuando sobre a cabeça e asas brancas pequenas nas
    omoplatas, numa peça só presa ao Chest (a cabeça sobe até z +0,73)."""
    import math
    limpar()
    ouro = mat("Ouro", (0.95, 0.76, 0.12), 0.9, 0.3)
    br = [mat("Pena%d" % i, c, 0.0, 0.9) for i, c in enumerate([(0.98, 0.98, 1.0), (0.93, 0.94, 0.98), (0.86, 0.88, 0.94)])]
    p = []
    for i in range(16):
        t = i / 16 * 2 * math.pi
        p.append(caixa_rot("Halo%d" % i, (0.10, 0.045, 0.04), (0.23 * math.cos(t), 0.23 * math.sin(t) - 0.0, 0.93), ouro, math.degrees(t) + 90))
    for sx in (1, -1):
        for i in range(5):
            x = sx * (0.12 + i * 0.07)
            for linha in range(3):
                h = 0.09
                p.append(caixa("Pena", (0.065, 0.04, h), (x, -0.21 - linha * 0.012, 0.14 - i * 0.015 - 0.04 - linha * h * 0.9), br[linha]))
    exportar(p, "acessorios", "aureola_asas_anjo")


# ---------------------------------------------------------- asas de morcego
def asas_morcego_grandes():
    """Par de asas grandes de morcego/demônio: braço e três dedos ósseos
    (bordô escuro) com membrana vermelha. Relativo ao nó Chest, nas costas."""
    limpar()
    osso_m = mat("Osso", (0.30, 0.04, 0.09), 0.0, 0.6)
    mem = mat("Membrana", (0.62, 0.10, 0.20), 0.0, 0.7)
    p = []
    y = -0.22
    for sx in (1, -1):
        S = (sx * 0.12, y, 0.18)
        pts = [(sx * 0.62, y, 0.62), (sx * 1.18, y, 0.78), (sx * 1.30, y, 0.20), (sx * 1.12, y, -0.38), (sx * 0.72, y, -0.62), (sx * 0.30, y, -0.50)]
        cot = pts[0]
        p.append(osso("Braco", S, cot, 0.07, osso_m))
        for k, tip in enumerate(pts[1:]):
            p.append(osso("Dedo%d" % k, cot, tip, 0.045, osso_m))
        verts = [S, cot] + pts[1:]
        # membrana: leque a partir do ombro e do cotovelo
        faces = []
        idx = {i: i for i in range(len(verts))}
        for i in range(2, len(verts) - 1):
            faces.append((0, i, i + 1) if sx > 0 else (0, i + 1, i))
        p.append(malha_plana("Membrana", verts, faces, mem))
        p.append(caixa("Garra", (0.05, 0.05, 0.08), (sx * 0.62, y, 0.68), osso_m))
    exportar(p, "acessorios", "asas_morcego_grandes")


# ----------------------------------------------------------- chapéu de caubói
def chapeu_cauboi():
    """Chapéu de caubói de couro marrom: aba larga curvada para cima nas laterais,
    copa vincada e faixa escura. Origem no centro do topo da cabeça."""
    limpar()
    couro = mat("Couro", (0.45, 0.22, 0.10), 0.0, 0.75)
    faixa = mat("Faixa", (0.24, 0.11, 0.06), 0.0, 0.75)
    ouro = mat("Ouro", (0.80, 0.60, 0.20), 0.8, 0.4)
    p = [caixa("Aba", (0.74, 0.92, 0.035), (0, 0.0, 0.005), couro),
         caixa("Faixa", (0.50, 0.65, 0.05), (0, 0, 0.065), faixa),
         caixa("Fivela", (0.07, 0.04, 0.06), (0, 0.335, 0.065), ouro),
         caixa("Copa", (0.46, 0.60, 0.15), (0, 0, 0.165), couro),
         caixa("CopaFrente", (0.46, 0.20, 0.06), (0, 0.20, 0.27), couro),
         caixa("CopaTras", (0.46, 0.20, 0.06), (0, -0.20, 0.27), couro)]
    for sx in (1, -1):
        p.append(caixa("AbaLado", (0.08, 0.80, 0.04), (sx * 0.40, 0, 0.035), couro))
        p.append(caixa("AbaLado2", (0.07, 0.70, 0.04), (sx * 0.46, 0, 0.07), couro))
        p.append(caixa("AbaLado3", (0.06, 0.55, 0.04), (sx * 0.51, 0, 0.11), couro))
    exportar(p, "acessorios", "chapeu_cauboi")


# ----------------------------------------------------------------- cicatriz
def cicatriz_rosto():
    """Cicatriz diagonal com pontos de sutura sobre o olho direito do
    personagem (+X). Peça finíssima colada à face: origem no centro da FACE
    FRONTAL (±0,25 em X e Z); cresce 4 mm para +Y."""
    limpar()
    cic = mat("Cicatriz", (0.78, 0.52, 0.50), 0.0, 0.9)
    claro = mat("CicatrizClara", (0.92, 0.80, 0.76), 0.0, 0.9)
    p = [osso("Corte", (0.17, 0.004, 0.17), (0.07, 0.004, -0.05), 0.014, cic)]
    for t in (0.15, 0.40, 0.65, 0.88):
        x = 0.17 + (0.07 - 0.17) * t
        z = 0.17 + (-0.05 - 0.17) * t
        p.append(osso("Ponto", (x - 0.028, 0.006, z - 0.016), (x + 0.028, 0.006, z + 0.016), 0.010, claro))
    exportar(p, "acessorios", "cicatriz_rosto")


# ------------------------------------------------------------ boné de capitão
def bone_capitao_naval():
    """Boné de oficial naval: copa azul-marinho de topo largo, faixa preta com
    debrum dourado, viseira preta e emblema. Origem no topo da cabeça."""
    limpar()
    az = mat("Azul", (0.06, 0.09, 0.30), 0.0, 0.8)
    preto = mat("Preto", (0.05, 0.05, 0.06), 0.0, 0.7)
    ouro = mat("Ouro", (0.90, 0.68, 0.14), 0.8, 0.4)
    p = [caixa("Copa", (0.54, 0.76, 0.12), (0, 0.0, 0.07), az),
         caixa("Topo", (0.60, 0.82, 0.05), (0, 0.0, 0.155), az),
         caixa("Faixa", (0.55, 0.77, 0.05), (0, 0.0, 0.015), preto),
         caixa("DebrumC", (0.555, 0.775, 0.015), (0, 0.0, 0.045), ouro),
         caixa("DebrumB", (0.555, 0.775, 0.015), (0, 0.0, -0.01), ouro),
         caixa("Viseira", (0.32, 0.18, 0.03), (0, P * 0.5 + 0.08, 0.0), preto),
         caixa("ViseiraDebrum", (0.33, 0.02, 0.032), (0, P * 0.5 + 0.17, 0.0), ouro),
         caixa("Emblema", (0.10, 0.03, 0.10), (0, P * 0.5 + 0.03, 0.075), ouro)]
    exportar(p, "acessorios", "bone_capitao_naval")


# --------------------------------------------------------------------- cajado
def cajado_mago_mao():
    """Cajado de madeira com anéis dourados e gancho que segura uma gema
    âmbar brilhante, na mão DIREITA (nó Hand_R): o punho segura o fuste em
    z=0; topo em +0,95, ponteira em −0,88."""
    limpar()
    mad = mat("Madeira", (0.28, 0.14, 0.08), 0.0, 0.7)
    ouro = mat("Ouro", (0.85, 0.62, 0.16), 0.85, 0.35)
    gema = mat("Gema", (1.0, 0.60, 0.10), 0.0, 0.3)
    b = next(n for n in gema.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Emission Color"].default_value = (1.0, 0.55, 0.08, 1.0)
    b.inputs["Emission Strength"].default_value = 3.0
    p = [caixa("Fuste", (0.05, 0.05, 1.80), (0, 0.0, 0.01), mad)]
    for z in (0.60, 0.18, -0.30, -0.70):
        p.append(caixa("Anel", (0.07, 0.07, 0.035), (0, 0, z), ouro))
    p.append(caixa("Ponteira", (0.06, 0.06, 0.07), (0, 0, -0.875), ouro))
    p.append(caixa("Losango", (0.09, 0.09, 0.09), (0, 0, 0.52), ouro))
    # gancho em espiral no topo + gema
    p += [caixa("Gancho1", (0.05, 0.05, 0.05), (0.04, 0, 0.93), mad),
          caixa("Gancho2", (0.05, 0.05, 0.05), (0.09, 0, 0.98), mad),
          caixa("Gancho3", (0.05, 0.05, 0.05), (0.13, 0, 1.03), mad),
          caixa("Gancho4", (-0.05 + 0.05, 0.05, 0.05), (0.10, 0, 1.08), mad),
          caixa("Gancho5", (0.05, 0.05, 0.05), (0.04, 0, 1.11), mad),
          caixa("Gancho6", (0.05, 0.05, 0.05), (-0.03, 0, 1.12), mad),
          caixa("Gema", (0.10, 0.10, 0.10), (0.05, 0, 1.01), gema)]
    exportar(p, "acessorios", "cajado_mago_mao")


# --------------------------------------------------------------- machado de costas
def machado_batalha_costas():
    """Machado de batalha de duas lâminas nas costas, cabo diagonal e bandoleira
    de couro cruzando o peito até o quadril; cabeça sobre o ombro direito (+X).
    Relativo ao nó Chest."""
    import math
    limpar()
    mad = mat("Cabo", (0.28, 0.15, 0.08), 0.0, 0.7)
    aco = mat("Aco", (0.62, 0.64, 0.68), 0.9, 0.35)
    ferro = mat("Ferro", (0.32, 0.33, 0.36), 0.8, 0.5)
    couro = mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.75)
    ouro = mat("Fivela", (0.78, 0.58, 0.20), 0.8, 0.4)
    y = -0.25
    b, a = (-0.28, y, -0.62), (0.30, y, 0.50)
    p = [osso("Cabo", b, a, 0.06, mad)]
    ux, uz = a[0] - b[0], a[2] - b[2]
    n = math.hypot(ux, uz)
    ux, uz = ux / n, uz / n
    vx, vz = uz, -ux              # perpendicular (lâmina para o lado de fora)
    cx, cz = a[0] + ux * 0.02, a[2] + uz * 0.02
    p.append(osso("Cabeca", (cx - ux * 0.09, y, cz - uz * 0.09), (cx + ux * 0.09, y, cz + uz * 0.09), 0.10, ferro))
    for k, (off, comp) in enumerate([(-0.13, 0.14), (-0.05, 0.22), (0.04, 0.26), (0.13, 0.20)]):
        px, pz = cx + ux * off, cz + uz * off
        p.append(osso("Lamina%d" % k, (px, y, pz), (px + vx * comp, y, pz + vz * comp), 0.065, aco))
    p.append(osso("Espigao", (cx, y, cz), (cx + ux * 0.18, y, cz + uz * 0.18), 0.04, aco))
    p.append(osso("Pomo", (b[0], y, b[2]), (b[0] - ux * 0.08, y, b[2] - uz * 0.08), 0.07, ferro))
    # bandoleira (frente e costas) do ombro direito ao quadril esquerdo + cinto
    for yy in (0.19, -0.19):
        p.append(osso("Tira", (0.20, yy, 0.25), (-0.22, yy, -0.30), 0.055, couro))
    p.append(caixa("Fivela", (0.07, 0.035, 0.07), (0.0, 0.21, -0.02), ouro))
    zc = -0.27
    p.append(caixa("CintoF", (0.55, 0.03, 0.06), (0, 0.19, zc), couro))
    p.append(caixa("CintoT", (0.55, 0.03, 0.06), (0, -0.19, zc), couro))
    for sx in (1, -1):
        p.append(caixa("CintoL", (0.03, 0.37, 0.06), (sx * 0.275, 0, zc), couro))
    p.append(caixa("CintoFivela", (0.07, 0.035, 0.07), (0.0, 0.205, zc), ouro))
    exportar(p, "acessorios", "machado_batalha_costas")


# -------------------------------- jaqueta de couro de motoqueiro (malha)
def jaqueta_motoqueiro():
    """Jaqueta de couro curta com lapelas largas, zíper prateado diagonal,
    ombreiras e punhos com rebites. Três GLBs (tronco, manga_sup, manga_inf).
    "Casaco" tingível; "Lapela"/"Vinco"/"Punho" derivam da cor; "Prata" fixo."""
    c = lambda: mat("Casaco", (0.09, 0.09, 0.10), 0.0, 0.45)
    lap = lambda: mat("Lapela", (0.12, 0.12, 0.14), 0.0, 0.45)
    vin = lambda: mat("Vinco", (0.06, 0.06, 0.07), 0.0, 0.5)
    pun = lambda: mat("Punho", (0.14, 0.14, 0.16), 0.0, 0.5)
    prata = lambda: mat("Prata", (0.76, 0.78, 0.82), 0.95, 0.25)
    limpar()
    p = [caixa("Corpo", (0.545, 0.365, 0.52), (0, 0, -0.06), c()),
         caixa("Cintura", (0.555, 0.375, 0.06), (0, 0, -0.30), vin()),
         caixa("Gola", (0.34, 0.32, 0.07), (0, 0, 0.275), lap()),
         caixa("GolaFrente", (0.34, 0.05, 0.10), (0, 0.17, 0.27), lap()),
         caixa("Costura", (0.50, 0.02, 0.04), (0, -0.185, 0.14), vin()),
         caixa("Ziper", (0.02, 0.02, 0.50), (0.04, 0.19, -0.04), prata())]
    for sx in (1, -1):
        p.append(caixa("Lapela", (0.14, 0.05, 0.30), (sx * 0.14 + 0.02, 0.19, 0.12), lap()))
        p.append(caixa("LapelaPonta", (0.09, 0.05, 0.08), (sx * 0.20 + 0.02, 0.19, -0.04), lap()))
        p.append(caixa("BolsoZip", (0.12, 0.02, 0.02), (sx * 0.17, 0.19, -0.18), prata()))
        p.append(caixa("Ombreira", (0.10, 0.10, 0.03), (sx * 0.22, 0, 0.255), vin()))
    exportar(p, "roupas", "motoqueiro_tronco")
    limpar()
    exportar([caixa("Manga", (0.29, 0.29, 0.34), (0, 0, -0.15), c()),
              caixa("Ombro", (0.30, 0.30, 0.05), (0, 0, 0.005), vin()),
              caixa("Rebite", (0.03, 0.03, 0.03), (0, 0.15, 0.0), prata())], "roupas", "motoqueiro_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.285, 0.285, 0.13), (0, 0, -0.065), c()),
              caixa("Punho", (0.31, 0.31, 0.075), (0, 0, -0.17), pun()),
              caixa("Rebite", (0.035, 0.03, 0.035), (0, 0.16, -0.17), prata()),
              caixa("Rebite2", (0.035, 0.03, 0.035), (0, -0.16, -0.17), prata())], "roupas", "motoqueiro_manga_inf")


# -------------------------------------------------------------- terno (malha)
def terno_blazer():
    """Blazer de terno com camisa branca, gravata vermelha, lapelas, bolsos e
    abotoamento. Quatro GLBs (tronco, saia curta no Torso, mangas)."""
    c = lambda: mat("Casaco", (0.16, 0.16, 0.19), 0.0, 0.85)
    lap = lambda: mat("Lapela", (0.20, 0.20, 0.24), 0.0, 0.85)
    vin = lambda: mat("Vinco", (0.12, 0.12, 0.14), 0.0, 0.85)
    br = lambda: mat("Branco", (0.93, 0.93, 0.95), 0.0, 0.9)
    gr = lambda: mat("Gravata", (0.62, 0.07, 0.10), 0.0, 0.8)
    limpar()
    p = [caixa("Corpo", (0.545, 0.365, 0.58), (0, 0, -0.04), c()),
         caixa("Camisa", (0.12, 0.04, 0.46), (0, 0.19, 0.03), br()),
         caixa("GolaBranca", (0.30, 0.30, 0.06), (0, 0, 0.275), br()),
         caixa("Gravata", (0.05, 0.03, 0.26), (0, 0.205, 0.10), gr()),
         caixa("Nozinho", (0.065, 0.035, 0.05), (0, 0.205, 0.20), gr()),
         caixa("GolaTras", (0.34, 0.05, 0.08), (0, -0.14, 0.27), lap())]
    for sx in (1, -1):
        p.append(caixa("Lapela", (0.115, 0.05, 0.36), (sx * 0.12, 0.19, 0.07), lap()))
        p.append(caixa("LapelaPonta", (0.07, 0.05, 0.08), (sx * 0.14, 0.19, 0.275), lap()))
        p.append(caixa("Bolso", (0.13, 0.03, 0.035), (sx * 0.15, 0.19, -0.14), vin()))
    p.append(caixa("Botao", (0.035, 0.03, 0.035), (0.0, 0.205, -0.10), vin()))
    p.append(caixa("Botao2", (0.035, 0.03, 0.035), (0.0, 0.205, -0.20), vin()))
    p.append(caixa("Lenco", (0.07, 0.03, 0.04), (0.17, 0.205, 0.03), br()))
    exportar(p, "roupas", "terno_tronco")
    limpar()
    p = []
    for sx in (1, -1):
        p.append(caixa("Aba", (0.255, 0.37, 0.30), (sx * 0.1475, 0, -0.07), c()))
    p.append(caixa("Costas", (0.57, 0.05, 0.30), (0, -0.175, -0.07), c()))
    p.append(caixa("Fenda", (0.02, 0.055, 0.22), (0, -0.175, -0.10), vin()))
    exportar(p, "roupas", "terno_saia")
    limpar()
    exportar([caixa("Manga", (0.29, 0.29, 0.34), (0, 0, -0.15), c()),
              caixa("Ombro", (0.30, 0.30, 0.05), (0, 0, 0.005), c())], "roupas", "terno_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.285, 0.285, 0.15), (0, 0, -0.075), c()),
              caixa("Punho", (0.27, 0.27, 0.05), (0, 0, -0.195), br()),
              caixa("Botao", (0.03, 0.03, 0.03), (0, 0.145, -0.15), vin())], "roupas", "terno_manga_inf")


# ---------------------------------------------------- uniforme escolar (malha)
def uniforme_escolar():
    """Blazer azul-marinho curto com gravata vermelha, botões dourados e saia
    plissada curta no Torso. Quatro GLBs."""
    c = lambda: mat("Casaco", (0.09, 0.12, 0.30), 0.0, 0.85)
    vin = lambda: mat("Vinco", (0.06, 0.08, 0.22), 0.0, 0.85)
    br = lambda: mat("Branco", (0.93, 0.93, 0.95), 0.0, 0.9)
    gr = lambda: mat("Gravata", (0.70, 0.08, 0.10), 0.0, 0.8)
    ouro = lambda: mat("Ouro", (0.90, 0.68, 0.14), 0.8, 0.4)
    limpar()
    p = [caixa("Corpo", (0.545, 0.365, 0.54), (0, 0, -0.06), c()),
         caixa("Camisa", (0.13, 0.04, 0.40), (0, 0.19, 0.04), br()),
         caixa("GolaBranca", (0.30, 0.30, 0.06), (0, 0, 0.275), br()),
         caixa("Gravata", (0.05, 0.03, 0.24), (0, 0.205, 0.10), gr()),
         caixa("Nozinho", (0.065, 0.035, 0.05), (0, 0.205, 0.20), gr()),
         caixa("Barra", (0.555, 0.375, 0.04), (0, 0, -0.31), vin())]
    for sx in (1, -1):
        p.append(caixa("Lapela", (0.10, 0.05, 0.30), (sx * 0.115, 0.19, 0.08), vin()))
        p.append(caixa("BolsoAba", (0.12, 0.03, 0.04), (sx * 0.15, 0.19, -0.13), vin()))
    for k in range(2):
        p.append(caixa("Botao", (0.04, 0.03, 0.04), (0.06, 0.205, -0.02 - k * 0.12), ouro()))
    exportar(p, "roupas", "escolar_tronco")
    limpar()
    p = [caixa("Cos", (0.58, 0.38, 0.05), (0, 0, 0.14), c())]
    for i in range(16):       # plissado: abas alternando fundo/frente
        x = -0.27 + i * 0.036
        p.append(caixa("Prega", (0.04, 0.40 + (0.07 if i % 2 else 0.0), 0.25), (x * 1.18, 0, 0.0), c() if i % 2 else vin()))
    p.append(caixa("Barra", (0.72, 0.52, 0.02), (0, 0, -0.13), vin()))
    exportar(p, "roupas", "escolar_saia")
    limpar()
    exportar([caixa("Manga", (0.29, 0.29, 0.34), (0, 0, -0.15), c()),
              caixa("Ombro", (0.30, 0.30, 0.05), (0, 0, 0.005), c())], "roupas", "escolar_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.285, 0.285, 0.12), (0, 0, -0.06), c()),
              caixa("Punho", (0.27, 0.27, 0.07), (0, 0, -0.175), br()),
              caixa("Barra", (0.29, 0.29, 0.02), (0, 0, -0.125), ouro())], "roupas", "escolar_manga_inf")


# ------------------------------------------------------- suéter de tricô (malha)
def sueter_trico():
    """Suéter de tricô grosso com gola rolê e trança central em relevo; mangas
    largas com punhos canelados. Quatro peças? Não: três GLBs (tronco, manga_sup,
    manga_inf). "Casaco" tingível; "Vinco" = relevo mais escuro."""
    c = lambda: mat("Casaco", (0.86, 0.77, 0.60), 0.0, 1.0)
    v = lambda: mat("Vinco", (0.72, 0.62, 0.46), 0.0, 1.0)
    l = lambda: mat("Lapela", (0.92, 0.84, 0.68), 0.0, 1.0)
    limpar()
    p = [caixa("Corpo", (0.565, 0.385, 0.58), (0, 0, -0.04), c()),
         caixa("Barra", (0.575, 0.395, 0.07), (0, 0, -0.30), v()),
         caixa("Gola1", (0.36, 0.34, 0.08), (0, 0, 0.275), l()),
         caixa("Gola2", (0.38, 0.36, 0.06), (0, 0, 0.345), l()),
         caixa("TrancaF", (0.12, 0.03, 0.46), (0, 0.205, -0.02), l()),
         caixa("TrancaFV", (0.04, 0.035, 0.46), (0, 0.21, -0.02), v()),
         caixa("TrancaT", (0.12, 0.03, 0.46), (0, -0.205, -0.02), l()),
         caixa("TrancaTV", (0.04, 0.035, 0.46), (0, -0.21, -0.02), v())]
    for sx in (1, -1):
        for k in range(2):
            p.append(caixa("Canelado", (0.035, 0.03, 0.46), (sx * (0.14 + k * 0.07), 0.205, -0.02), v()))
            p.append(caixa("CaneladoT", (0.035, 0.03, 0.46), (sx * (0.14 + k * 0.07), -0.205, -0.02), v()))
    exportar(p, "roupas", "sueter_tronco")
    limpar()
    p = [caixa("Manga", (0.315, 0.315, 0.34), (0, 0, -0.15), c()),
         caixa("Ombro", (0.325, 0.325, 0.06), (0, 0, 0.0), c())]
    for k in range(3):
        p.append(caixa("Canelado", (0.03, 0.32, 0.30), (0.15 - 0 , 0, -0.15), v()) if False else caixa("Veio", (0.04, 0.325, 0.30), (-0.10 + k * 0.10, 0, -0.15), v()))
    exportar(p, "roupas", "sueter_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.305, 0.305, 0.12), (0, 0, -0.06), c()),
              caixa("Punho", (0.33, 0.33, 0.09), (0, 0, -0.165), v()),
              caixa("PunhoBorda", (0.335, 0.335, 0.025), (0, 0, -0.12), l())], "roupas", "sueter_manga_inf")


# ------------------------------------------------------------- orelhas de coelho
def orelhas_coelho():
    """Orelhas compridas de coelho (creme com miolo rosa), levemente abertas.
    Origem no centro do topo da cabeça."""
    limpar()
    creme = mat("Pelo", (0.95, 0.88, 0.72), 0.0, 0.95)
    rosa = mat("Miolo", (0.90, 0.58, 0.58), 0.0, 0.9)
    p = []
    for sx in (1, -1):
        for i in range(6):
            x = sx * (0.12 + i * 0.012)
            z = -0.01 + i * 0.06
            w = 0.11 if i < 5 else 0.09
            p.append(caixa("Orelha%d" % i, (w, 0.065, 0.065), (x, -0.03, z + 0.03), creme))
            if 0 < i < 5:
                p.append(caixa("Miolo%d" % i, (0.055, 0.012, 0.062), (x, -0.03 + 0.034, z + 0.03), rosa))
        p.append(caixa("Ponta", (0.075, 0.06, 0.04), (sx * 0.19, -0.03, 0.385), creme))
    exportar(p, "acessorios", "orelhas_coelho")


# ------------------------------------------------------------- cauda de pompom
def cauda_pompom():
    """Cauda de coelho: bola de pelo creme escalonada. Origem no nó Torso, nas
    costas, na altura da cintura/quadril."""
    limpar()
    creme = mat("Pelo", (0.97, 0.92, 0.80), 0.0, 1.0)
    p = [caixa("Miolo", (0.14, 0.12, 0.14), (0, -0.19, 0.05), creme),
         caixa("Lado1", (0.17, 0.08, 0.10), (0, -0.20, 0.05), creme),
         caixa("Lado2", (0.10, 0.10, 0.17), (0, -0.20, 0.05), creme),
         caixa("Topo", (0.10, 0.09, 0.05), (0, -0.19, 0.125), creme),
         caixa("Baixo", (0.10, 0.09, 0.05), (0, -0.19, -0.025), creme)]
    exportar(p, "acessorios", "cauda_pompom")


# --------------------------------------------------------------------- tiara
def tiara_joias():
    """Tiara dourada fina com três joias (rubi no centro, safiras laterais).
    Origem no centro do topo da cabeça."""
    limpar()
    ouro = mat("Ouro", (0.92, 0.72, 0.16), 0.9, 0.3)
    rubi = mat("Rubi", (0.85, 0.08, 0.20), 0.2, 0.2)
    safira = mat("Safira", (0.20, 0.45, 0.95), 0.2, 0.2)
    zc = -0.03
    p = [caixa("Frente", (0.54, 0.025, 0.04), (0, P * 0.5 + 0.012, zc), ouro),
         caixa("Tras", (0.54, 0.025, 0.04), (0, -P * 0.5 - 0.012, zc), ouro),
         caixa("Pico", (0.07, 0.03, 0.09), (0, P * 0.5 + 0.012, zc + 0.05), ouro),
         caixa("PicoE", (0.05, 0.03, 0.06), (-0.12, P * 0.5 + 0.012, zc + 0.035), ouro),
         caixa("PicoD", (0.05, 0.03, 0.06), (0.12, P * 0.5 + 0.012, zc + 0.035), ouro),
         caixa("Rubi", (0.045, 0.035, 0.045), (0, P * 0.5 + 0.02, zc + 0.01), rubi),
         caixa("SafiraE", (0.035, 0.035, 0.035), (-0.12, P * 0.5 + 0.02, zc + 0.0), safira),
         caixa("SafiraD", (0.035, 0.035, 0.035), (0.12, P * 0.5 + 0.02, zc + 0.0), safira)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.025, P, 0.04), (sx * 0.2685, 0, zc), ouro))
    exportar(p, "acessorios", "tiara_joias")


# ---------------------------------------------------------- polainas arco-íris
def polainas_arco_iris():
    """Polainas fofas listradas em arco-íris com punho canelado branco, no nó
    Shin (joelho no pivô): cobrem a canela de −0,03 a −0,26."""
    limpar()
    cores = [(0.90, 0.20, 0.22), (0.96, 0.52, 0.16), (0.98, 0.84, 0.20), (0.30, 0.74, 0.30), (0.25, 0.55, 0.92), (0.50, 0.34, 0.80)]
    branco = mat("Branco", (0.95, 0.95, 0.97), 0.0, 1.0)
    p = [caixa("Punho", (0.32, 0.32, 0.045), (0, 0, -0.045), branco)]
    for i, c in enumerate(cores):
        w = 0.305 + (0.012 if i % 2 else 0.0)
        p.append(caixa("Faixa%d" % i, (w, w, 0.038), (0, 0, -0.088 - i * 0.04), mat("Arco%d" % i, c, 0.0, 1.0)))
    p.append(caixa("Base", (0.30, 0.30, 0.03), (0, 0, -0.088 - 6 * 0.04), branco))
    exportar(p, "acessorios", "polainas_arco_iris")


# ----------------------------------------------------------- chapéu panamá
def chapeu_panama_palha():
    """Chapéu panamá de palha creme com fita azul-marinho e laço. Origem no
    centro do topo da cabeça."""
    limpar()
    palha = mat("Palha", (0.94, 0.86, 0.66), 0.0, 0.95)
    azul = mat("Fita", (0.08, 0.12, 0.34), 0.0, 0.8)
    p = [caixa("Aba", (0.72, 0.94, 0.03), (0, 0, 0.0), palha),
         caixa("AbaBorda", (0.735, 0.955, 0.012), (0, 0, 0.0), azul),
         caixa("Copa", (0.50, 0.66, 0.13), (0, 0, 0.095), palha),
         caixa("CopaTopo", (0.46, 0.62, 0.03), (0, 0, 0.175), palha),
         caixa("Fita", (0.51, 0.67, 0.055), (0, 0, 0.055), azul),
         caixa("Laco", (0.14, 0.04, 0.07), (0, 0.345, 0.055), azul),
         caixa("LacoNo", (0.05, 0.05, 0.05), (0, 0.355, 0.055), azul)]
    exportar(p, "acessorios", "chapeu_panama_palha")


# ------------------------------------------------- joelheiras e cotoveleiras
def _pad(nome, pivo_z, lado_y, larg, alt, m, mc, mo, z_cintas):
    p = [caixa("Pad", (0.20, 0.07, alt), (0, lado_y * 0.17, pivo_z), m),
         caixa("PadBorda", (0.215, 0.05, alt + 0.02), (0, lado_y * 0.155, pivo_z), mc)]
    for z in z_cintas:
        p.append(caixa("Cinta", (0.305, 0.305, 0.035), (0, 0, z), mc))
        p.append(caixa("Fivela", (0.04, 0.03, 0.05), (0.05, lado_y * 0.16, z), mo))
    return p


def joelheiras_couro():
    """Joelheira de couro com duas cintas de bronze, no nó Shin (joelho no
    pivô), uma peça por perna."""
    limpar()
    m, mc, mo = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.7), mat("CouroEscuro", (0.22, 0.12, 0.06), 0.0, 0.7), mat("Bronze", (0.80, 0.60, 0.22), 0.8, 0.4)
    exportar(_pad("Joelheira", -0.02, 1, 0.2, 0.18, m, mc, mo, (0.03, -0.09)), "acessorios", "joelheiras_couro")


def cotoveleiras_couro():
    """Cotoveleira de couro nas duas pontas do cotovelo (nó ForeArm, pivô no
    cotovelo), com duas cintas."""
    limpar()
    m, mc, mo = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.7), mat("CouroEscuro", (0.22, 0.12, 0.06), 0.0, 0.7), mat("Bronze", (0.80, 0.60, 0.22), 0.8, 0.4)
    exportar(_pad("Cotoveleira", -0.05, -1, 0.2, 0.17, m, mc, mo, (0.0, -0.10)), "acessorios", "cotoveleiras_couro")


# ------------------------------------------------------- cinto de ferramentas
def cinto_ferramentas_bolsas():
    """Cinto de couro com fivela, duas bolsas laterais com aba e ferramentas
    (martelo e chave) penduradas à direita. Origem no nó Torso (cintura em
    z +0,10; corpo ±0,25 × ±0,13)."""
    limpar()
    couro = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.7)
    escuro = mat("CouroEscuro", (0.24, 0.13, 0.07), 0.0, 0.7)
    prata = mat("Prata", (0.74, 0.76, 0.80), 0.9, 0.3)
    amar = mat("Amarelo", (0.95, 0.75, 0.10), 0.0, 0.6)
    zc = 0.07
    p = [caixa("CintoF", (0.53, 0.03, 0.07), (0, 0.145, zc), escuro),
         caixa("CintoT", (0.53, 0.03, 0.07), (0, -0.145, zc), escuro),
         caixa("Fivela", (0.08, 0.035, 0.08), (0, 0.16, zc), prata),
         caixa("FivelaMiolo", (0.04, 0.04, 0.04), (0, 0.165, zc), escuro)]
    for sx in (1, -1):
        p.append(caixa("CintoL", (0.03, 0.29, 0.07), (sx * 0.265, 0, zc), escuro))
        p.append(caixa("Bolsa", (0.11, 0.17, 0.17), (sx * 0.325, 0.0, -0.03), couro))
        p.append(caixa("Aba", (0.12, 0.18, 0.06), (sx * 0.325, 0.0, 0.05), escuro))
        p.append(caixa("Fecho", (0.125, 0.03, 0.03), (sx * 0.325, 0.095, 0.045), prata))
    p.append(caixa("Martelo", (0.02, 0.02, 0.14), (0.30, 0.13, -0.05), couro))
    p.append(caixa("MarteloCabeca", (0.07, 0.03, 0.045), (0.30, 0.13, 0.03), prata))
    p.append(caixa("Chave", (0.02, 0.02, 0.15), (0.35, 0.13, -0.05), amar))
    p.append(caixa("ChaveBoca", (0.045, 0.03, 0.04), (0.35, 0.13, 0.04), prata))
    exportar(p, "acessorios", "cinto_ferramentas_bolsas")


# --------------------------------------------------------------- gancho de pirata
def gancho_pirata():
    """Punho de couro com rebites e gancho de aço no lugar da mão ESQUERDA
    (nó Hand_L, pivô no punho; gancho para baixo, curva para a frente)."""
    limpar()
    couro = mat("Couro", (0.38, 0.20, 0.09), 0.0, 0.7)
    ouro = mat("Bronze", (0.82, 0.62, 0.20), 0.85, 0.4)
    aco = mat("Aco", (0.72, 0.74, 0.78), 0.95, 0.25)
    p = [caixa("Punho", (0.215, 0.215, 0.075), (0, 0, 0.0), couro),
         caixa("Base", (0.14, 0.14, 0.05), (0, 0, -0.06), aco)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(caixa("Rebite", (0.03, 0.03, 0.03), (sx * 0.095, sy * 0.095, 0.0), ouro))
    p += [caixa("Haste", (0.045, 0.045, 0.17), (0, 0, -0.17), aco),
          caixa("Curva1", (0.045, 0.06, 0.05), (0, 0.025, -0.29), aco),
          caixa("Curva2", (0.045, 0.06, 0.04), (0, 0.075, -0.32), aco),
          caixa("Curva3", (0.045, 0.06, 0.04), (0, 0.115, -0.285), aco),
          caixa("Ponta", (0.04, 0.05, 0.05), (0, 0.125, -0.235), aco)]
    exportar(p, "acessorios", "gancho_pirata")


# ------------------------------------------------------------------ perna de pau
def perna_de_pau():
    """Perna de pau de madeira afunilada com cinta de couro e rebites, na
    canela ESQUERDA (nó Shin_L, joelho no pivô)."""
    limpar()
    mad = mat("Madeira", (0.42, 0.24, 0.11), 0.0, 0.75)
    couro = mat("Couro", (0.28, 0.15, 0.08), 0.0, 0.7)
    ouro = mat("Bronze", (0.82, 0.62, 0.20), 0.85, 0.4)
    aco = mat("Aco", (0.50, 0.52, 0.56), 0.8, 0.5)
    p = [caixa("Cinta", (0.31, 0.31, 0.06), (0, 0, -0.07), couro),
         caixa("Madeira1", (0.255, 0.255, 0.07), (0, 0, -0.14), mad),
         caixa("Madeira2", (0.225, 0.225, 0.07), (0, 0, -0.20), mad),
         caixa("Madeira3", (0.19, 0.19, 0.06), (0, 0, -0.255), mad),
         caixa("Ponta", (0.14, 0.14, 0.03), (0, 0, -0.30), aco)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(caixa("Rebite", (0.035, 0.035, 0.035), (sx * 0.14, sy * 0.14, -0.07), ouro))
    exportar(p, "acessorios", "perna_de_pau")


# ------------------------------------------------------------ cabelo box braids
def cabelo_box_braids_longas():
    """Tranças longas finas (box braids) com risca ao meio: dezenas de fios
    verticais ao redor da cabeça, comprimentos variados até z = −1,15."""
    import random
    limpar()
    random.seed(31)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L, P, 0.09), (0, 0, -0.045), cab),
         caixa("Franja", (L, 0.06, 0.12), (0, P * 0.5 - 0.03, -0.06), cab)]
    def fio(x, y, comp):
        p.append(caixa("Fio", (0.052, 0.052, comp), (x, y, -comp * 0.5 - 0.03), cab))
    for i in range(9):
        x = -0.24 + i * 0.06
        for k, y in enumerate((-(P * 0.5 - 0.03), -(P * 0.5 - 0.09))):
            fio(x, y, random.uniform(0.95, 1.18) - 0.06 * k)
    for sx in (1, -1):
        for j in range(8):
            y = -P * 0.5 + 0.12 + j * 0.095
            fio(sx * (L * 0.5 - 0.02), y, random.uniform(0.80, 1.10) - 0.05 * (0 if y < 0.1 else 1))
    for sx in (1, -1):    # mechas da frente, uma de cada lado
        for j in range(3):
            fio(sx * (0.10 + j * 0.06), P * 0.5 - 0.03, random.uniform(0.55, 0.85) if j else 0.9)
    exportar(p, "cabelos", "cabelo_box_braids_longas")


# ------------------------------------------------------ furisode (malha)
def furisode_laco():
    """Furisode bordô de mangas longas, faixa obi dourada e laço grande nas
    costas, com flores rosa-claras. Quatro GLBs (tronco, saia no Torso, mangas).
    "Casaco" tingível; "Ouro" e "Rosa" fixos."""
    c = lambda: mat("Casaco", (0.42, 0.06, 0.14), 0.0, 0.8)
    vin = lambda: mat("Vinco", (0.28, 0.04, 0.09), 0.0, 0.8)
    ouro = lambda: mat("Ouro", (0.92, 0.72, 0.30), 0.7, 0.45)
    cre = lambda: mat("Branco", (0.93, 0.88, 0.76), 0.0, 0.85)
    rosa = lambda: mat("Rosa", (0.98, 0.74, 0.80), 0.0, 0.85)
    limpar()
    p = [caixa("Corpo", (0.55, 0.37, 0.58), (0, 0, -0.04), c()),
         caixa("ColarE", (0.10, 0.045, 0.40), (-0.09, 0.195, 0.06), cre()),
         caixa("ColarD", (0.10, 0.045, 0.40), (0.09, 0.195, 0.06), cre()),
         caixa("GolaNuca", (0.30, 0.20, 0.06), (0, -0.06, 0.26), cre()),
         caixa("Obi", (0.58, 0.40, 0.17), (0, 0, -0.22), ouro()),
         caixa("ObiFaixa", (0.60, 0.41, 0.03), (0, 0, -0.22), vin()),
         caixa("Laco", (0.46, 0.09, 0.30), (0, -0.28, -0.17), ouro()),
         caixa("LacoNo", (0.12, 0.12, 0.12), (0, -0.25, -0.17), vin()),
         caixa("LacoTiraE", (0.09, 0.06, 0.28), (-0.10, -0.26, -0.45), ouro()),
         caixa("LacoTiraD", (0.09, 0.06, 0.28), (0.10, -0.26, -0.45), ouro())]
    for x, z in ((-0.17, 0.10), (0.16, 0.0), (-0.12, -0.05), (0.2, 0.17)):
        p.append(caixa("Flor", (0.07, 0.02, 0.07), (x, 0.2, z), rosa()))
    exportar(p, "roupas", "furisode_tronco")
    limpar()
    p = [caixa("Saia", (0.60, 0.40, 0.84), (0, 0, -0.25), c()),
         caixa("Barra", (0.61, 0.41, 0.04), (0, 0, -0.665), ouro()),
         caixa("ColarSaiaE", (0.07, 0.045, 0.84), (-0.06, 0.205, -0.25), cre()),
         caixa("ColarSaiaD", (0.07, 0.045, 0.84), (0.06, 0.205, -0.25), cre())]
    for x, z in ((-0.18, -0.1), (0.17, -0.22), (-0.13, -0.36), (0.18, -0.48), (-0.17, -0.55), (0.0, -0.3)):
        p.append(caixa("Flor", (0.075, 0.02, 0.075), (x, 0.205, z), rosa()))
    exportar(p, "roupas", "furisode_saia")
    limpar()
    exportar([caixa("Manga", (0.30, 0.34, 0.34), (0, 0, -0.15), c()),
              caixa("Ombro", (0.31, 0.33, 0.07), (0, 0, -0.01), c()),
              caixa("Flor", (0.03, 0.08, 0.08), (0.155, 0, -0.12), rosa())], "roupas", "furisode_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.32, 0.30, 0.62), (0, 0, -0.30), c()),
              caixa("Barra", (0.33, 0.31, 0.04), (0, 0, -0.60), ouro()),
              caixa("Flor", (0.03, 0.08, 0.08), (0.165, 0, -0.30), rosa()),
              caixa("Flor2", (0.03, 0.07, 0.07), (-0.165, 0, -0.45), rosa())], "roupas", "furisode_manga_inf")


# -------------------------------------------------------- brincos longos
def brincos_longos_piercing():
    """Brincos longos dourados (argola + corrente + pingente) nas duas orelhas.
    Origem no topo da cabeça; orelha em x=±0,26, z=−0,24."""
    limpar()
    ouro = mat("Ouro", (0.95, 0.76, 0.14), 0.95, 0.25)
    p = []
    for sx in (1, -1):
        x = sx * 0.27
        p.append(caixa("Argola", (0.03, 0.045, 0.045), (x, 0.0, -0.235), ouro))
        for i in range(3):
            p.append(caixa("Elo", (0.018, 0.018, 0.045), (x + sx * 0.012, 0.0, -0.285 - i * 0.045), ouro))
        p.append(caixa("Pingente", (0.04, 0.04, 0.09), (x + sx * 0.012, 0.0, -0.45), ouro))
        p.append(caixa("PingenteMeio", (0.025, 0.025, 0.04), (x + sx * 0.012, 0.0, -0.505), ouro))
    p.append(caixa("Piercing", (0.02, 0.02, 0.02), (0.07, P * 0.5 + 0.012, -0.28), ouro))
    exportar(p, "acessorios", "brincos_longos_piercing")


# ---------------------------------------------------- rabo de cavalo com laço
def cabelo_rabo_cavalo_laco():
    """Rabo de cavalo alto com laço vermelho grande e franja de lado. Origem no
    centro do topo do crânio; o rabo cai pelas costas até z = −0,85."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    fita = mat("Fita", (0.80, 0.08, 0.10), 0.0, 0.7)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab),
         caixa("Franja", (L, 0.07, 0.16), (0, P * 0.5 - 0.035, -0.08), cab),
         caixa("FranjaLado", (0.18, 0.07, 0.16), (0.14, P * 0.5 - 0.035, -0.20), cab),
         caixa("Nuca", (L, 0.10, 0.34), (0, -(P * 0.5 - 0.05), -0.17), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.30), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.15), cab))
    yb = -P * 0.5 - 0.02
    p.append(caixa("Base", (0.17, 0.12, 0.12), (0, yb, 0.0), cab))
    for i, (y, z, w) in enumerate([(-0.07, -0.14, 0.17), (-0.12, -0.28, 0.17), (-0.15, -0.44, 0.16), (-0.17, -0.60, 0.14), (-0.18, -0.74, 0.11), (-0.18, -0.85, 0.07)]):
        p.append(caixa("Rabo%d" % i, (w, 0.13, 0.15), (0, yb + y, z), cab))
    p.append(caixa("Laco", (0.07, 0.07, 0.07), (0, yb, 0.07), fita))
    for sx in (1, -1):
        p.append(caixa("LacoAsa", (0.13, 0.05, 0.11), (sx * 0.10, yb, 0.10), fita))
        p.append(caixa("LacoTira", (0.04, 0.04, 0.15), (sx * 0.05, yb - 0.01, -0.03), fita))
    exportar(p, "cabelos", "cabelo_rabo_cavalo_laco")


# ---------------------------------------------------------- capuz de gato
def capuz_gato_orelhas():
    """Capuz preto de pelúcia com orelhas de gato (miolo rosa) e gola grossa,
    rosto aberto. Origem no centro do topo da cabeça."""
    limpar()
    pelo = mat("Pelo", (0.10, 0.10, 0.12), 0.0, 1.0)
    rosa = mat("Miolo", (0.78, 0.42, 0.50), 0.0, 1.0)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.07), (0, 0, 0.03), pelo),
         caixa("Tras", (larg, 0.07, 0.56), (0, -prof * 0.5 + 0.035, -0.25), pelo),
         caixa("Brim", (larg, 0.07, 0.11), (0, prof * 0.5 - 0.035, -0.02), pelo),
         caixa("Gola", (larg + 0.02, prof + 0.02, 0.12), (0, 0, -0.58), pelo)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.07, prof, 0.56), (sx * (larg * 0.5 - 0.035), 0, -0.25), pelo))
        p.append(caixa("Bochecha", (0.09, 0.07, 0.40), (sx * (CAB_L * 0.5 - 0.0), prof * 0.5 - 0.035, -0.31), pelo))
        for i, w in enumerate((0.13, 0.10, 0.07)):
            p.append(caixa("Orelha%d" % i, (w, 0.07, 0.05), (sx * 0.17, -0.08, 0.075 + i * 0.05), pelo))
        p.append(caixa("OrelhaMiolo", (0.05, 0.015, 0.07), (sx * 0.17, -0.08 + 0.04, 0.10), rosa))
    p.append(caixa("Queixo", (larg - 0.04, 0.06, 0.10), (0, prof * 0.5 - 0.03, -0.56), pelo))
    exportar(p, "acessorios", "capuz_gato_orelhas")


# ----------------------------------------- casaco longo com gola felpuda (malha)
def casaco_gola_felpuda():
    """Casaco longo marrom com gola enorme de pele creme, botões dourados,
    bolsos de aba e punhos largos. Quatro GLBs (tronco, saia no Torso, mangas).
    "Casaco" tingível; "Pelo" e "Ouro" fixos."""
    c = lambda: mat("Casaco", (0.30, 0.16, 0.10), 0.0, 0.85)
    vin = lambda: mat("Vinco", (0.22, 0.11, 0.07), 0.0, 0.85)
    pelo = lambda: mat("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0)
    ouro = lambda: mat("Ouro", (0.88, 0.65, 0.16), 0.8, 0.4)
    limpar()
    p = []
    for sx in (1, -1):
        p.append(caixa("Painel", (0.245, 0.375, 0.58), (sx * 0.1525, 0, -0.04), c()))
        p.append(caixa("Pele", (0.14, 0.40, 0.10), (sx * 0.15, 0, 0.30), pelo()))
        p.append(caixa("PeleFrente", (0.12, 0.10, 0.34), (sx * 0.17, 0.2, 0.15), pelo()))
        for k in range(3):
            p.append(caixa("Botao", (0.04, 0.03, 0.04), (sx * 0.10, 0.205, 0.10 - k * 0.14), ouro()))
    p.append(caixa("Costas", (0.55, 0.045, 0.58), (0, -0.19, -0.04), c()))
    p.append(caixa("PeleTras", (0.52, 0.12, 0.12), (0, -0.19, 0.30), pelo()))
    p.append(caixa("PeleLado", (0.06, 0.34, 0.10), (-0.27, 0, 0.30), pelo()))
    p.append(caixa("PeleLado", (0.06, 0.34, 0.10), (0.27, 0, 0.30), pelo()))
    p.append(caixa("PeleAlta", (0.46, 0.34, 0.06), (0, -0.02, 0.36), pelo()))
    exportar(p, "roupas", "casaco_pelo_tronco")
    limpar()
    p = [caixa("Costas", (0.58, 0.05, 0.80), (0, -0.18, -0.23), c()),
         caixa("Barra", (0.59, 0.38, 0.04), (0, 0, -0.63), vin())]
    for sx in (1, -1):
        p.append(caixa("Aba", (0.255, 0.37, 0.80), (sx * 0.165, 0, -0.23), c()))
        p.append(caixa("Bolso", (0.13, 0.04, 0.16), (sx * 0.17, 0.205, -0.25), vin()))
        p.append(caixa("BolsoAba", (0.14, 0.045, 0.04), (sx * 0.17, 0.205, -0.17), c()))
        p.append(caixa("BotaoBolso", (0.035, 0.03, 0.035), (sx * 0.17, 0.225, -0.17), ouro()))
        p.append(caixa("BordaPele", (0.03, 0.375, 0.80), (sx * 0.0425, 0.0, -0.23), vin()))
    exportar(p, "roupas", "casaco_pelo_saia")
    limpar()
    exportar([caixa("Manga", (0.30, 0.30, 0.34), (0, 0, -0.15), c()),
              caixa("Ombro", (0.31, 0.31, 0.06), (0, 0, 0.0), c())], "roupas", "casaco_pelo_manga_sup")
    limpar()
    exportar([caixa("Manga", (0.295, 0.295, 0.11), (0, 0, -0.055), c()),
              caixa("Punho", (0.33, 0.33, 0.10), (0, 0, -0.16), vin()),
              caixa("Botao", (0.035, 0.035, 0.035), (0, 0.17, -0.16), ouro())], "roupas", "casaco_pelo_manga_inf")


# ----------------------------------------------------------- monóculo
def monoculo_corrente():
    """Monóculo dourado no olho direito do personagem (+X) com corrente que
    desce pela bochecha até a orelha. Origem no centro da FACE FRONTAL."""
    limpar()
    ouro = mat("Ouro", (0.95, 0.74, 0.16), 0.95, 0.25)
    vidro = mat("Vidro", (0.78, 0.88, 0.95), 0.1, 0.05)
    x, z = 0.115, 0.035
    p = [caixa("AroC", (0.19, 0.03, 0.03), (x, 0.02, z + 0.085), ouro),
         caixa("AroB", (0.19, 0.03, 0.03), (x, 0.02, z - 0.085), ouro),
         caixa("AroE", (0.03, 0.03, 0.14), (x - 0.08, 0.02, z), ouro),
         caixa("AroD", (0.03, 0.03, 0.14), (x + 0.08, 0.02, z), ouro),
         caixa("Lente", (0.13, 0.008, 0.14), (x, 0.022, z), vidro),
         caixa("Pino", (0.04, 0.04, 0.04), (x + 0.09, 0.02, z + 0.04), ouro)]
    pts = [(x + 0.08, z - 0.09), (x + 0.10, z - 0.14), (x + 0.115, z - 0.19), (x + 0.12, z - 0.24)]
    for i, (px, pz) in enumerate(pts):
        p.append(caixa("Elo%d" % i, (0.02, 0.02, 0.04), (px, 0.015, pz), ouro))
    for i in range(6):
        p.append(caixa("ElLado%d" % i, (0.04, 0.02, 0.02), (0.25, -0.02 - i * 0.04, -0.24 + i * 0.004), ouro))
    exportar(p, "acessorios", "monoculo_corrente")


# ---------------------------------------------------- cabelo finger waves
def cabelo_finger_waves_curto():
    """Cabelo curto com ondas marcadas (finger waves): ondas horizontais em
    camadas alternadas, laterais até a orelha. Origem no topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.12), (0, 0, -0.05), cab),
         caixa("Nuca", (L + 0.02, 0.12, 0.38), (0, -(P * 0.5 - 0.05), -0.19), cab),
         caixa("Franja", (L + 0.02, 0.08, 0.14), (0, P * 0.5 - 0.01, -0.07), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.62, 0.34), (sx * (L * 0.5 + 0.0), -P * 0.12, -0.17), cab))
    for k in range(3):
        for i in range(6):
            x = -0.20 + i * 0.08
            dy = 0.0 if (i + k) % 2 == 0 else 0.05
            p.append(caixa("Onda", (0.085, P * 0.9, 0.05), (x, dy - 0.0, 0.03 + k * 0.0 + (0.04 if (i + k) % 2 == 0 else 0.0) - k * 0.0), cab)) if k == 0 else None
    for k in range(5):     # ondas em S na vertical, nas costas e laterais
        z = -0.06 - k * 0.07
        dx = 0.035 if k % 2 else -0.035
        p.append(caixa("OndaT", (L * 0.92, 0.05, 0.065), (dx, -(P * 0.5 + 0.02), z), cab))
        for sx in (1, -1):
            p.append(caixa("OndaL", (0.05, P * 0.5, 0.06), (sx * (L * 0.5 + 0.04), -0.06 + (0.05 if k % 2 else -0.05), z), cab))
    exportar(p, "cabelos", "cabelo_finger_waves_curto")


# ------------------------------------------------------------- boina francesa
def boina_francesa():
    """Boina vermelha achatada, caída para um lado, com cabinho no topo. Origem
    no centro do topo da cabeça."""
    limpar()
    v = mat("Boina", (0.62, 0.06, 0.12), 0.0, 0.95)
    p = [caixa("Faixa", (0.52, 0.70, 0.04), (0, 0, 0.0), v),
         caixa("Disco", (0.64, 0.84, 0.07), (0.04, 0.0, 0.055), v),
         caixa("Topo", (0.52, 0.68, 0.05), (0.06, 0.0, 0.115), v),
         caixa("Cabo", (0.045, 0.045, 0.06), (0.06, 0.0, 0.17), v),
         caixa("Queda", (0.14, 0.76, 0.06), (0.30, 0.0, 0.01), v)]
    exportar(p, "acessorios", "boina_francesa")


def cachecol_curto_vermelho():
    """Cachecol curto de uma volta com ponta e franja caindo à esquerda do
    peito. Relativo ao nó Chest."""
    limpar()
    v = mat("Cachecol", (0.70, 0.06, 0.12), 0.0, 0.9)
    s = mat("CachecolSombra", (0.50, 0.04, 0.09), 0.0, 0.9)
    p = [caixa("Volta1", (0.40, 0.36, 0.06), (0, -0.01, 0.275), v),
         caixa("Volta2", (0.42, 0.38, 0.06), (0, -0.01, 0.325), s),
         caixa("No", (0.12, 0.05, 0.12), (-0.09, 0.2, 0.26), s),
         caixa("Ponta", (0.13, 0.04, 0.26), (-0.09, 0.205, 0.07), v),
         caixa("Ponta2", (0.11, 0.04, 0.16), (-0.02, 0.21, 0.13), v)]
    for k in range(4):
        p.append(caixa("Franja", (0.025, 0.04, 0.05), (-0.135 + k * 0.036, 0.205, -0.085), v))
    exportar(p, "acessorios", "cachecol_curto_vermelho")


# =====================================================================
# Conjuntos de roupa pelo helper `vestir` (lote 5): cada peça é uma lista de
# (tamanho, centro, chave_do_material); `mats` = {chave: (nome, cor, metal, rug)}.
# Nome do material manda na cor no jogo (`_cor_do_material`): "Casaco" = tinge;
# "Branco", "Ouro", "Prata", "Gravata", "Couro", "Pelo"... = fixos.
# =====================================================================
def vestir(pref, mats, **partes):
    """Exporta <pref>_<parte>.glb para cada parte dada (tronco, saia, manga_sup,
    manga_inf, cintura, coxa, canela, pe) em assets/models/roupas/."""
    for parte, itens in partes.items():
        if not itens:
            continue
        limpar()
        ms = {k: mat(*v) for k, v in mats.items()}
        exportar([caixa(parte, tam, cen, ms[k]) for tam, cen, k in itens], "roupas", "%s_%s" % (pref, parte))


TRONCO = ((0.545, 0.365, 0.55), (0, 0, -0.04))
MANGA_SUP = ((0.29, 0.29, 0.34), (0, 0, -0.15))
MANGA_INF = ((0.285, 0.285, 0.21), (0, 0, -0.105))


def _base(chave):
    return [(TRONCO[0], TRONCO[1], chave)]


def _bracos(chave):
    return [(MANGA_SUP[0], MANGA_SUP[1], chave)], [(MANGA_INF[0], MANGA_INF[1], chave)]


# ------------------------------------------------------------- capa de mago
def capa_mago_estrelas():
    """Capa roxo-escura com debrum dourado, gola de corrente, estrelas e lua
    crescente nas costas. Mesma origem/encaixe da capa_marinha (topo do pescoço,
    pende para −Z)."""
    import random
    random.seed(3)
    limpar()
    roxo = mat("CapaRoxa", (0.12, 0.08, 0.30), 0.0, 0.85)
    ouro = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    p = [caixa("Gola", (0.46, 0.06, 0.10), (0, -0.20, 0.05), roxo),
         caixa("Corrente", (0.30, 0.03, 0.03), (0, 0.13, -0.03), ouro),
         caixa("Manto", (0.90, 0.52, 0.12), (0, -0.07, -0.12), roupa := roxo)]
    z = -0.18
    for i, larg in enumerate([0.78, 0.84, 0.90, 0.96, 1.02]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), roxo))
        for sx in (1, -1):
            p.append(caixa("Borda%d" % i, (0.04, 0.06, 0.22), (sx * (larg * 0.5 - 0.02), -0.25, z - 0.11), ouro))
        z -= 0.22
    p.append(caixa("BarraTras", (1.02, 0.06, 0.04), (0, -0.25, z + 0.02), ouro))
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.85), (sx * 0.43, -0.07, -0.60), roxo))
        p.append(caixa("PanoBorda", (0.055, 0.04, 0.85), (sx * 0.43, 0.13, -0.60), ouro))
    for i in range(18):    # estrelas
        x = random.uniform(-0.40, 0.40)
        zz = random.uniform(-1.05, -0.32)
        t = random.choice((0.03, 0.04))
        p.append(caixa("Estrela", (t, 0.012, t), (x, -0.285, zz), ouro))
    for i in range(7):     # lua crescente
        import math
        a = math.radians(-70 + i * 22)
        p.append(caixa("Lua", (0.045, 0.012, 0.045), (0.10 + 0.13 * math.cos(a) - 0.1, -0.285, -0.68 + 0.13 * math.sin(a)), ouro))
    exportar(p, "acessorios", "capa_mago_estrelas")


# ---------------------------------------------------------------- ladino
def armadura_ladino():
    sup, inf = _bracos("c")
    mats = {"c": ("Casaco", (0.42, 0.22, 0.10), 0.0, 0.7), "v": ("Vinco", (0.30, 0.15, 0.07), 0.0, 0.7),
            "o": ("Ouro", (0.80, 0.60, 0.20), 0.8, 0.4)}
    tronco = _base("c") + [((0.575, 0.395, 0.06), (0, 0, -0.30), "v"),
                           ((0.06, 0.40, 0.03), (0.15, 0, 0.255), "v"), ((0.06, 0.40, 0.03), (-0.15, 0, 0.255), "v"),
                           ((0.05, 0.03, 0.54), (0.0, 0.195, -0.03), "v"), ((0.04, 0.035, 0.04), (0, 0.205, 0.0), "o"),
                           ((0.6, 0.4, 0.14), (0, 0, 0.30), "c"),
                           ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"),
                           ((0.44, 0.30, 0.10), (0, -0.15, 0.90), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "c"),
                           ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
                           ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c")]
    vestir("ladino", mats, tronco=tronco,
           manga_sup=sup + [((0.33, 0.33, 0.07), (0, 0, 0.02), "v"), ((0.34, 0.34, 0.03), (0, 0, -0.03), "o")],
           manga_inf=inf + [((0.31, 0.31, 0.09), (0, 0, -0.16), "v")])


# ------------------------------------------------------------- astronauta
def traje_astronauta():
    sup, inf = _bracos("c")
    mats = {"c": ("Casaco", (0.92, 0.93, 0.95), 0.0, 0.5), "g": ("Aco", (0.55, 0.57, 0.62), 0.6, 0.5),
            "o": ("Ouro", (0.95, 0.55, 0.10), 0.0, 0.6)}
    tronco = _base("c") + [((0.575, 0.385, 0.06), (0, 0, 0.22), "g"), ((0.575, 0.385, 0.05), (0, 0, -0.30), "g"),
                           ((0.20, 0.04, 0.14), (0, 0.205, 0.08), "g"), ((0.14, 0.045, 0.03), (0, 0.21, 0.08), "o"),
                           ((0.40, 0.20, 0.50), (0, -0.28, -0.02), "c"), ((0.30, 0.04, 0.30), (0, -0.39, 0.0), "g"),
                           ((0.34, 0.34, 0.07), (0, 0, 0.29), "g")]
    vestir("astronauta", mats, tronco=tronco,
           manga_sup=sup + [((0.31, 0.31, 0.05), (0, 0, -0.30), "g"), ((0.315, 0.315, 0.025), (0, 0, -0.10), "o")],
           manga_inf=inf + [((0.31, 0.31, 0.07), (0, 0, -0.17), "g"), ((0.315, 0.315, 0.025), (0, 0, -0.05), "o")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.55, 0.31, 0.04), (0, 0, 0.03), "g")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.27, 0.27, 0.04), (0, 0, -0.30), "g")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.275, 0.275, 0.05), (0, 0, -0.04), "g"), ((0.265, 0.265, 0.025), (0, 0, -0.12), "o")],
           pe=[((0.27, 0.32, 0.09), (0, 0.0, -0.05), "g"), ((0.26, 0.06, 0.07), (0, 0.17, -0.06), "c")])
    limpar()
    vid = mat("Vidro", (0.55, 0.75, 0.90), 0.2, 0.05)
    g = mat("Aco", (0.55, 0.57, 0.62), 0.6, 0.5)
    br = mat("Casaco", (0.92, 0.93, 0.95), 0.0, 0.5)
    o = mat("Ouro", (0.95, 0.55, 0.10), 0.0, 0.6)
    p = [caixa("Anel", (0.64, 0.86, 0.05), (0, 0, -0.45), g),
         caixa("Casca", (0.62, 0.84, 0.06), (0, 0, 0.06), br),
         caixa("CascaTras", (0.62, 0.06, 0.55), (0, -0.41, -0.22), br)]
    for sx in (1, -1):
        p.append(caixa("CascaLado", (0.06, 0.84, 0.55), (sx * 0.31, 0, -0.22), br))
        p.append(caixa("Luz", (0.04, 0.06, 0.06), (sx * 0.325, 0.08, -0.22), o))
    p.append(caixa("Viseira", (0.52, 0.04, 0.42), (0, 0.405, -0.22), vid))
    p.append(caixa("ViseiraAro", (0.58, 0.045, 0.06), (0, 0.405, -0.015), g))
    exportar(p, "acessorios", "capacete_astronauta")


# --------------------------------------------------------------------- chef
def roupa_chef():
    sup, inf = _bracos("b")
    mats = {"b": ("Branco", (0.95, 0.95, 0.96), 0.0, 0.9), "c": ("Casaco", (0.92, 0.92, 0.94), 0.0, 0.9),
            "g": ("Vinco", (0.78, 0.78, 0.82), 0.0, 0.9)}
    tronco = [(TRONCO[0], TRONCO[1], "c"), ((0.32, 0.33, 0.07), (0, 0, 0.27), "c"),
              ((0.08, 0.04, 0.50), (0.12, 0.19, -0.04), "g"), ((0.08, 0.04, 0.50), (-0.12, 0.19, -0.04), "g")]
    for k in range(3):
        tronco.append(((0.04, 0.03, 0.04), (0.10, 0.215, 0.10 - k * 0.14), "b"))
        tronco.append(((0.04, 0.03, 0.04), (-0.10, 0.215, 0.10 - k * 0.14), "b"))
    vestir("chef", mats, tronco=tronco, manga_sup=[(MANGA_SUP[0], MANGA_SUP[1], "c")],
           manga_inf=[(MANGA_INF[0], MANGA_INF[1], "c"), ((0.31, 0.31, 0.06), (0, 0, -0.17), "g")],
           saia=[((0.40, 0.04, 0.55), (0, 0.19, -0.10), "b"), ((0.42, 0.045, 0.06), (0, 0.19, 0.12), "g")])
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.97), 0.0, 0.95)
    p = [caixa("Aba", (0.52, 0.76, 0.10), (0, 0, 0.05), br)]
    for i in range(5):
        p.append(caixa("Prega", (0.10, 0.62, 0.38 + 0.02 * (i % 2)), (-0.19 + i * 0.095, 0, 0.29), br))
    p.append(caixa("Topo", (0.50, 0.70, 0.06), (0, 0, 0.50), br))
    exportar(p, "acessorios", "toque_chef")


# ------------------------------------------------------------------ roupão
def roupao_banho():
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")]
    mats = {"c": ("Casaco", (0.65, 0.78, 0.90), 0.0, 1.0), "v": ("Vinco", (0.50, 0.64, 0.80), 0.0, 1.0),
            "l": ("Lapela", (0.74, 0.85, 0.95), 0.0, 1.0)}
    tronco = [((0.56, 0.38, 0.58), (0, 0, -0.04), "c"), ((0.14, 0.04, 0.46), (0.07, 0.205, 0.03), "l"),
              ((0.14, 0.04, 0.46), (-0.07, 0.205, 0.03), "l"), ((0.34, 0.32, 0.08), (0, 0, 0.27), "l"),
              ((0.58, 0.40, 0.06), (0, 0, -0.22), "v"), ((0.12, 0.05, 0.12), (0.12, 0.21, -0.22), "v"),
              ((0.05, 0.05, 0.20), (0.10, 0.215, -0.34), "v"), ((0.05, 0.05, 0.16), (0.17, 0.215, -0.32), "v")]
    vestir("roupao", mats, tronco=tronco, saia=[((0.60, 0.40, 0.74), (0, 0, -0.20), "c"), ((0.61, 0.41, 0.05), (0, 0, -0.55), "v")],
           manga_sup=[((0.31, 0.31, 0.34), (0, 0, -0.15), "c")],
           manga_inf=[((0.33, 0.33, 0.21), (0, 0, -0.105), "c"), ((0.34, 0.34, 0.04), (0, 0, -0.20), "v")])
    limpar()
    t = mat("Toalha", (0.68, 0.80, 0.92), 0.0, 1.0)
    tv = mat("ToalhaSombra", (0.55, 0.68, 0.82), 0.0, 1.0)
    p = [caixa("Base", (0.58, 0.82, 0.14), (0, 0.0, 0.07), t), caixa("Volta", (0.60, 0.84, 0.05), (0, 0, 0.12), tv),
         caixa("Torre", (0.44, 0.66, 0.12), (-0.03, -0.04, 0.20), t), caixa("Pico", (0.30, 0.46, 0.10), (-0.06, -0.08, 0.29), t),
         caixa("Dobra", (0.10, 0.40, 0.05), (0.20, 0.18, 0.12), tv)]
    exportar(p, "acessorios", "toalha_turbante")


# -------------------------------------------------------------- marinheiro
def uniforme_marinheiro():
    mats = {"c": ("Casaco", (0.10, 0.14, 0.32), 0.0, 0.85), "b": ("Branco", (0.94, 0.94, 0.96), 0.0, 0.9),
            "r": ("Gravata", (0.72, 0.08, 0.10), 0.0, 0.8)}
    tronco = [(TRONCO[0], TRONCO[1], "c")]
    for k in range(5):
        tronco.append(((0.555, 0.375, 0.05), (0, 0, 0.17 - k * 0.12), "b"))
    tronco += [((0.34, 0.33, 0.07), (0, 0, 0.27), "c"), ((0.36, 0.05, 0.12), (0, -0.19, 0.22), "c"),
               ((0.10, 0.04, 0.30), (0, 0.205, 0.12), "c"), ((0.16, 0.05, 0.08), (0, 0.205, 0.17), "r"),
               ((0.05, 0.05, 0.14), (-0.03, 0.21, 0.07), "r"), ((0.05, 0.05, 0.14), (0.04, 0.21, 0.07), "r")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + [((0.295, 0.295, 0.04), (0, 0, -0.07 - k * 0.1), "b") for k in range(2)]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c")] + [((0.29, 0.29, 0.04), (0, 0, -0.04 - k * 0.1), "b") for k in range(2)]
    vestir("marinheiro_listrado", mats, tronco=tronco, manga_sup=sup, manga_inf=inf)
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.97), 0.0, 0.9)
    az = mat("Azul", (0.10, 0.14, 0.32), 0.0, 0.85)
    p = [caixa("Copa", (0.56, 0.78, 0.10), (0, 0, 0.05), br), caixa("Faixa", (0.58, 0.80, 0.045), (0, 0, 0.0), az),
         caixa("Topo", (0.64, 0.84, 0.05), (0, 0, 0.115), br), caixa("Fita", (0.50, 0.03, 0.04), (0, 0.40, 0.0), az)]
    exportar(p, "acessorios", "bone_marinheiro")


# ----------------------------------------------------------------- pijama
def pijama_nuvens():
    mats = {"c": ("Casaco", (0.48, 0.62, 0.90), 0.0, 0.95), "b": ("Branco", (0.95, 0.96, 0.98), 0.0, 1.0),
            "o": ("Ouro", (0.98, 0.84, 0.30), 0.0, 0.6)}
    tronco = _base("c") + [((0.14, 0.05, 0.08), (-0.14, 0.2, 0.08), "b"), ((0.34, 0.32, 0.06), (0, 0, 0.27), "b"),
                           ((0.12, 0.04, 0.04), (0.12, 0.2, -0.10), "b"), ((0.14, 0.04, 0.05), (-0.12, 0.2, -0.22), "b"),
                           ((0.035, 0.03, 0.035), (0.14, 0.2, 0.15), "o"), ((0.035, 0.03, 0.035), (-0.05, 0.2, -0.02), "o"),
                           ((0.575, 0.385, 0.05), (0, 0, -0.30), "b"),
                           ((0.14, 0.05, 0.07), (0.14, -0.2, 0.05), "b"), ((0.12, 0.05, 0.06), (-0.10, -0.2, -0.15), "b")]
    sup, inf = _bracos("c")
    vestir("pijama", mats, tronco=tronco, manga_sup=sup + [((0.1, 0.295, 0.05), (0, 0.0, -0.1), "b")],
           manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "b")],
           cintura=[((0.52, 0.28, 0.15), (0, 0, 0.09), "c"), ((0.54, 0.29, 0.04), (0, 0, 0.14), "b")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.1, 0.27, 0.06), (0.0, 0.0, -0.12), "b"), ((0.035, 0.27, 0.035), (0.05, 0, -0.25), "o")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.275, 0.275, 0.05), (0, 0, -0.26), "b"), ((0.09, 0.275, 0.05), (0, 0, -0.12), "b")])
    limpar()
    az = mat("Gorro", (0.40, 0.55, 0.88), 0.0, 1.0)
    br = mat("Branco", (0.97, 0.97, 0.99), 0.0, 1.0)
    o = mat("Ouro", (0.98, 0.84, 0.30), 0.0, 0.6)
    p = [caixa("Barra", (0.57, 0.80, 0.07), (0, 0, 0.0), br), caixa("Copa", (0.50, 0.70, 0.12), (0, -0.02, 0.09), az),
         caixa("Cone", (0.38, 0.54, 0.12), (0, -0.08, 0.20), az), caixa("Cone2", (0.26, 0.36, 0.12), (0, -0.16, 0.30), az),
         caixa("Cone3", (0.17, 0.2, 0.10), (-0.05, -0.26, 0.37), az), caixa("Ponta", (0.10, 0.10, 0.10), (-0.14, -0.34, 0.33), br),
         caixa("Estrela", (0.04, 0.02, 0.04), (0.15, 0.30, 0.09), o)]
    exportar(p, "acessorios", "gorro_dormir")


# ------------------------------------------------------------- macacão
def macacao_mecanico():
    mats = {"c": ("Casaco", (0.16, 0.30, 0.60), 0.0, 0.9), "v": ("Vinco", (0.11, 0.21, 0.45), 0.0, 0.9),
            "p": ("Prata", (0.76, 0.78, 0.82), 0.95, 0.25), "r": ("Couro", (0.55, 0.36, 0.18), 0.0, 0.85)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.02, 0.02, 0.54), (0, 0.19, -0.04), "p"),
                           ((0.575, 0.385, 0.05), (0, 0, -0.30), "v"), ((0.10, 0.03, 0.06), (0.14, 0.19, 0.10), "v"),
                           ((0.08, 0.03, 0.08), (-0.16, 0.2, -0.10), "r"), ((0.08, 0.03, 0.08), (0.17, -0.2, 0.0), "r")]
    sup, inf = _bracos("c")
    vestir("macacao", mats, tronco=tronco, manga_sup=sup + [((0.08, 0.30, 0.08), (0.0, 0.0, -0.10), "r")],
           manga_inf=inf + [((0.31, 0.31, 0.06), (0, 0, -0.18), "v")],
           cintura=[((0.52, 0.28, 0.15), (0, 0, 0.09), "c"), ((0.12, 0.04, 0.08), (0.12, 0.15, 0.08), "v")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.09, 0.27, 0.10), (0.04, 0.0, -0.17), "r")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.275, 0.275, 0.04), (0, 0, -0.26), "v"), ((0.08, 0.27, 0.07), (-0.03, 0, -0.10), "r")])


# ----------------------------------------------------- fantasia de dinossauro
def fantasia_dinossauro():
    """Macacão verde de dinossauro com barriga creme, espinhos nas costas, rabo
    e capuz com cabeça de dino (olhos, dentes, narinas). Capuz e cabeça no
    tronco (nó Chest: a cabeça fica em z +0,25…+0,73); rabo na cintura (Torso)."""
    mats = {"c": ("Casaco", (0.30, 0.55, 0.20), 0.0, 0.9), "v": ("Vinco", (0.22, 0.42, 0.15), 0.0, 0.9),
            "p": ("Pelo", (0.93, 0.86, 0.70), 0.0, 0.95), "e": ("Espinho", (0.62, 0.82, 0.22), 0.0, 0.8),
            "k": ("Preto", (0.05, 0.05, 0.06), 0.0, 0.6), "b": ("Branco", (0.96, 0.96, 0.96), 0.0, 0.5)}
    tronco = _base("c") + [((0.36, 0.03, 0.46), (0, 0.19, -0.04), "p"), ((0.345, 0.04, 0.05), (0, 0.195, -0.02), "v")]
    for k in range(4):
        tronco.append(((0.08, 0.07, 0.10), (0, -0.215, 0.14 - k * 0.12), "e"))
    tronco += [((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"),
               ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
               ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"),
               ((0.62, 0.30, 0.12), (0, 0.40, 0.80), "c"), ((0.56, 0.12, 0.10), (0, 0.55, 0.74), "c"),
               ((0.08, 0.08, 0.10), (0.15, 0.62, 0.78), "v"), ((0.08, 0.08, 0.10), (-0.15, 0.62, 0.78), "v"),
               ((0.09, 0.05, 0.09), (0.24, 0.34, 0.86), "b"), ((0.09, 0.05, 0.09), (-0.24, 0.34, 0.86), "b"),
               ((0.05, 0.03, 0.05), (0.25, 0.36, 0.86), "k"), ((0.05, 0.03, 0.05), (-0.25, 0.36, 0.86), "k"),
               ((0.07, 0.07, 0.09), (0.0, -0.22, 0.88), "e"), ((0.07, 0.07, 0.09), (0.0, -0.05, 0.92), "e")]
    for sx in (1, -1):
        for k in range(3):
            tronco.append(((0.045, 0.03, 0.08), (sx * (0.10 + k * 0.1), 0.60, 0.69), "b"))
    sup, inf = _bracos("c")
    cintura = [((0.53, 0.30, 0.15), (0, 0, 0.09), "c")]
    for i in range(6):
        w = 0.20 - i * 0.03
        cintura.append(((w, 0.18 - i * 0.02, 0.12), (0, -0.17 - i * 0.12, 0.0 - i * 0.07), "c"))
        cintura.append(((0.07, 0.07, 0.07), (0, -0.17 - i * 0.12, 0.07 - i * 0.07 + (0.02 if i < 5 else -0.03)), "e"))
    vestir("dino", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.12, 0.30, 0.05), (0, 0.0, -0.19), "p")], cintura=cintura,
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")],
           pe=[((0.27, 0.32, 0.09), (0, 0.0, -0.05), "v"), ((0.05, 0.05, 0.05), (0.07, 0.17, -0.06), "b"), ((0.05, 0.05, 0.05), (-0.07, 0.17, -0.06), "b")])


# ------------------------------------------------------------ smoking + capa
def smoking_capa():
    """Smoking preto com camisa branca, lapelas, laço e punhos brancos; saia curta
    de fraque. Três GLBs de cima (tronco, saia, mangas)."""
    mats = {"c": ("Casaco", (0.07, 0.07, 0.09), 0.0, 0.6), "l": ("Lapela", (0.12, 0.12, 0.15), 0.0, 0.5),
            "b": ("Branco", (0.95, 0.95, 0.97), 0.0, 0.9), "k": ("Preto", (0.04, 0.04, 0.05), 0.0, 0.6),
            "o": ("Ouro", (0.90, 0.68, 0.14), 0.8, 0.4)}
    tronco = _base("c") + [((0.14, 0.04, 0.44), (0, 0.19, 0.03), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"),
                           ((0.12, 0.04, 0.07), (0, 0.205, 0.19), "k"), ((0.035, 0.03, 0.035), (0, 0.205, 0.07), "o"),
                           ((0.035, 0.03, 0.035), (0, 0.205, -0.03), "o"), ((0.575, 0.385, 0.05), (0, 0, -0.30), "k")]
    for sx in (1, -1):
        tronco.append(((0.12, 0.05, 0.36), (sx * 0.12, 0.19, 0.06), "l"))
        tronco.append(((0.06, 0.05, 0.08), (sx * 0.15, 0.19, 0.27), "l"))
    vestir("smoking", mats, tronco=tronco,
           saia=[((0.255, 0.37, 0.32), (0.1525, 0, -0.07), "c"), ((0.255, 0.37, 0.32), (-0.1525, 0, -0.07), "c"), ((0.57, 0.05, 0.40), (0, -0.175, -0.11), "c")],
           manga_sup=[(MANGA_SUP[0], MANGA_SUP[1], "c")],
           manga_inf=[(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.05), (0, 0, -0.19), "b")])
    limpar()
    pr = mat("CapaPreta", (0.05, 0.05, 0.06), 0.0, 0.7)
    ve = mat("Gravata", (0.55, 0.05, 0.08), 0.0, 0.8)
    p = [caixa("GolaTras", (0.46, 0.06, 0.16), (0, -0.20, 0.08), pr), caixa("GolaForro", (0.44, 0.02, 0.14), (0, -0.165, 0.08), ve),
         caixa("Manto", (0.92, 0.54, 0.12), (0, -0.07, -0.12), pr)]
    z = -0.18
    for i, larg in enumerate([0.78, 0.86, 0.94, 1.02, 1.10]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), pr))
        z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.85), (sx * 0.45, -0.07, -0.60), pr))
        p.append(caixa("Forro", (0.02, 0.34, 0.84), (sx * 0.415, -0.07, -0.60), ve))
    exportar(p, "acessorios", "capa_opera")


# ----------------------------------------------------------------- cocar
def cocar_grande_penas():
    """Cocar de penas em leque arco-íris sobre faixa turquesa e dourada. Origem no
    centro do topo da cabeça; leque no plano frontal, inclinado para trás."""
    import math
    limpar()
    ouro = mat("Ouro", (0.90, 0.68, 0.14), 0.8, 0.4)
    turq = mat("Turquesa", (0.10, 0.65, 0.65), 0.2, 0.4)
    verm = mat("Vermelho", (0.80, 0.08, 0.08), 0.2, 0.5)
    cores = [(0.55, 0.20, 0.70), (0.20, 0.30, 0.85), (0.10, 0.65, 0.65), (0.20, 0.70, 0.25), (0.95, 0.85, 0.15), (0.95, 0.50, 0.10), (0.85, 0.12, 0.10)]
    p = [caixa("Faixa", (0.56, 0.05, 0.11), (0, P * 0.5 + 0.02, -0.02), turq), caixa("FaixaOuro", (0.58, 0.055, 0.025), (0, P * 0.5 + 0.02, 0.04), ouro),
         caixa("FaixaOuro2", (0.58, 0.055, 0.025), (0, P * 0.5 + 0.02, -0.08), ouro), caixa("Gema", (0.08, 0.06, 0.08), (0, P * 0.5 + 0.04, -0.02), verm),
         caixa("Tras", (0.56, 0.05, 0.11), (0, -P * 0.5 - 0.02, -0.02), turq)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.05, P, 0.11), (sx * 0.28, 0, -0.02), turq))
        for k in range(3):
            p.append(caixa("Pendente", (0.03, 0.03, 0.14), (sx * 0.28, P * 0.5 - 0.02 - k * 0.0, -0.17 - 0.0), ouro)) if k == 0 else None
    n = 15
    for i in range(n):
        t = (i / (n - 1)) * 2 - 1
        ang = t * math.radians(78)
        comp = 0.46 - 0.11 * abs(t)
        base = (t * 0.22, -0.02 - abs(t) * 0.0, 0.06)
        tip = (base[0] + math.sin(ang) * comp, base[1], base[2] + math.cos(ang) * comp)
        c = cores[min(int((i / n) * len(cores)), len(cores) - 1)] if t >= 0 else cores[min(int(((n - 1 - i) / n) * len(cores)), len(cores) - 1)]
        cor = mat("Pena%d" % (min(abs(i - n // 2), 6)), cores[min(abs(i - n // 2), 6)] if False else cores[(abs(i - n // 2) * 7) // 8], 0.0, 0.85)
        p.append(osso("Pena%d" % i, base, tip, 0.06, cor))
    exportar(p, "acessorios", "cocar_grande_penas")


# -------------------------------------------------------- coroa do rei + manto
def coroa_rei():
    """Coroa de ouro com almofada vermelha, quatro picos e joias. Origem no
    centro do topo da cabeça."""
    limpar()
    ouro = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    vel = mat("Veludo", (0.65, 0.08, 0.12), 0.0, 0.9)
    j = [mat("JoiaV", (0.1, 0.65, 0.2), 0.2, 0.2), mat("JoiaA", (0.2, 0.4, 0.95), 0.2, 0.2), mat("JoiaR", (0.9, 0.1, 0.15), 0.2, 0.2)]
    p = [caixa("Aro", (0.54, P + 0.04, 0.12), (0, 0, 0.03), ouro), caixa("Almofada", (0.46, 0.66, 0.14), (0, 0, 0.14), vel),
         caixa("TopoV", (0.40, 0.58, 0.06), (0, 0, 0.21), vel)]
    for sx in (1, -1):
        p.append(caixa("PicoL", (0.06, 0.16, 0.10), (sx * 0.27, 0.0, 0.12), ouro))
        p.append(caixa("PicoF", (0.12, 0.06, 0.10), (sx * 0.14, P * 0.5 + 0.02, 0.12), ouro))
        p.append(caixa("PicoT", (0.12, 0.06, 0.10), (sx * 0.14, -P * 0.5 - 0.02, 0.12), ouro))
    p.append(caixa("PicoCentro", (0.12, 0.06, 0.14), (0, P * 0.5 + 0.02, 0.14), ouro))
    p.append(caixa("JoiaC", (0.07, 0.04, 0.07), (0, P * 0.5 + 0.045, 0.14), j[2]))
    for k, sx in enumerate((-0.2, 0.2)):
        p.append(caixa("JoiaS", (0.05, 0.04, 0.05), (sx, P * 0.5 + 0.03, 0.04), j[k]))
    p.append(caixa("JoiaTopo", (0.07, 0.07, 0.07), (0, 0.0, 0.25), j[1]))
    exportar(p, "acessorios", "coroa_rei")


def manto_arminho():
    """Manto vermelho real com gola de arminho (pontos pretos), debruns
    dourados e flor-de-lis. Encaixe da capa_marinha."""
    import random
    random.seed(8)
    limpar()
    ve = mat("CapaVermelha", (0.62, 0.06, 0.10), 0.0, 0.85)
    br = mat("Pelo", (0.95, 0.93, 0.88), 0.0, 1.0)
    pr = mat("Preto", (0.05, 0.05, 0.06), 0.0, 0.7)
    ouro = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    p = [caixa("PeleTras", (0.62, 0.14, 0.12), (0, -0.19, 0.06), br), caixa("PeleManto", (0.98, 0.56, 0.14), (0, -0.07, -0.12), br)]
    for sx in (1, -1):
        p.append(caixa("PeleFrente", (0.14, 0.12, 0.90), (sx * 0.40, 0.12, -0.62), br))
        p.append(caixa("PeleLado", (0.14, 0.40, 0.14), (sx * 0.34, -0.05, -0.05), br))
        p.append(caixa("Broche", (0.06, 0.04, 0.06), (sx * 0.14, 0.16, -0.03), ouro))
    p.append(caixa("Corrente", (0.28, 0.03, 0.03), (0, 0.17, -0.02), ouro))
    z = -0.20
    for i, larg in enumerate([0.82, 0.88, 0.94, 1.00, 1.06]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), ve))
        z -= 0.22
    p.append(caixa("Barra", (1.06, 0.07, 0.07), (0, -0.25, z + 0.035), br))
    for sx in (1, -1):
        p.append(caixa("FaixaOuro", (0.03, 0.06, 0.95), (sx * 0.36, -0.25, -0.65), ouro))
        p.append(caixa("PanoLado", (0.05, 0.30, 0.80), (sx * 0.46, -0.07, -0.60), ve))
    p.append(caixa("Flor", (0.08, 0.012, 0.18), (0, -0.285, -0.72), ouro))
    p.append(caixa("FlorL", (0.07, 0.012, 0.09), (-0.07, -0.285, -0.70), ouro))
    p.append(caixa("FlorR", (0.07, 0.012, 0.09), (0.07, -0.285, -0.70), ouro))
    for i in range(14):
        p.append(caixa("Pinta", (0.03, 0.012, 0.03), (random.uniform(-0.38, 0.38), -0.185, 0.07 if i < 4 else -0.12), pr)) if False else None
    for sx in (1, -1):
        for k in range(5):
            p.append(caixa("Pinta", (0.03, 0.02, 0.04), (sx * 0.40, 0.18, -0.08 - k * 0.17), pr))
    exportar(p, "acessorios", "manto_arminho")


# ------------------------------------------------------------- visor de RV
def visor_realidade_virtual():
    """Visor de realidade virtual preto com acentos azuis e tira com cabo no
    alto. Origem no centro da FACE FRONTAL (±0,25 em X/Z), cresce para +Y."""
    limpar()
    preto = mat("Preto", (0.05, 0.05, 0.07), 0.2, 0.4)
    azul = mat("Azul", (0.10, 0.30, 0.95), 0.0, 0.4)
    cinza = mat("Cinza", (0.16, 0.17, 0.20), 0.3, 0.5)
    p = [caixa("Corpo", (0.56, 0.14, 0.20), (0, 0.07, 0.04), preto), caixa("Frente", (0.50, 0.04, 0.16), (0, 0.15, 0.04), cinza),
         caixa("Faixa", (0.30, 0.02, 0.03), (0, 0.16, 0.04), azul), caixa("Marca", (0.05, 0.02, 0.05), (0, 0.165, 0.04), azul),
         caixa("TiraTopo", (0.06, 0.80, 0.03), (0, -0.37, 0.265), preto), caixa("TiraTopoAz", (0.04, 0.70, 0.015), (0, -0.37, 0.285), azul),
         caixa("TiraTopoF", (0.06, 0.03, 0.18), (0, 0.0, 0.17), preto), caixa("TiraTras", (0.54, 0.03, 0.09), (0, -0.755, 0.04), preto)]
    for sx in (1, -1):
        p.append(caixa("TiraL", (0.03, 0.80, 0.09), (sx * 0.265, -0.37, 0.04), preto))
        p.append(caixa("Pad", (0.03, 0.10, 0.12), (sx * 0.28, 0.0, 0.04), azul))
    exportar(p, "acessorios", "visor_realidade_virtual")


# ------------------------------------------------------------ asas de fada
def asas_fada_translucidas():
    """Dois pares de asas de fada translúcidas (rosa/lilás) com nervuras. Relativo
    ao nó Chest, nas costas."""
    limpar()
    mem = mat("Asa", (0.92, 0.78, 0.98, 0.55), 0.0, 0.2)
    try:
        mem.surface_render_method = "BLENDED"
    except Exception:
        pass
    b = next(n for n in mem.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Alpha"].default_value = 0.55
    ner = mat("Nervura", (0.70, 0.45, 0.85), 0.0, 0.6)
    p = []
    y = -0.22
    for sx in (1, -1):
        sup = [(sx * 0.10, y, 0.20), (sx * 0.36, y, 0.62), (sx * 0.78, y, 0.88), (sx * 0.92, y, 0.60), (sx * 0.74, y, 0.22), (sx * 0.34, y, 0.10)]
        inf = [(sx * 0.10, y, 0.08), (sx * 0.38, y, 0.06), (sx * 0.66, y, -0.18), (sx * 0.50, y, -0.52), (sx * 0.26, y, -0.36), (sx * 0.10, y, -0.10)]
        for pts in (sup, inf):
            faces = [(0, i, i + 1) if sx > 0 else (0, i + 1, i) for i in range(1, len(pts) - 1)]
            p.append(malha_plana("Asa", pts, faces, mem))
            for tip in pts[2:5]:
                p.append(osso("Nervura", pts[0], tip, 0.018, ner))
    exportar(p, "acessorios", "asas_fada_translucidas")


# ------------------------------------------------------------ cauda de sereia
def barbatana_sereia():
    """Cauda de sereia verde-água que cobre as duas pernas, da cintura ao chão,
    com escamas em fileiras e barbatana aberta. Origem no nó Torso (quadril;
    chão em z = −0,72)."""
    limpar()
    esc = mat("Escama", (0.10, 0.58, 0.52), 0.1, 0.4)
    cla = mat("EscamaClara", (0.30, 0.82, 0.72), 0.1, 0.4)
    esc2 = mat("EscamaEscura", (0.06, 0.42, 0.40), 0.1, 0.4)
    p = [caixa("Cinto", (0.56, 0.30, 0.06), (0, 0, 0.16), cla)]
    larg = [0.54, 0.54, 0.50, 0.46, 0.40, 0.34, 0.30, 0.28]
    for i, w in enumerate(larg):
        z = 0.12 - i * 0.095
        m = esc if i % 2 == 0 else esc2
        p.append(caixa("Fileira%d" % i, (w, 0.30 - i * 0.012, 0.095), (0, 0, z), m))
        for k in range(3):
            p.append(caixa("Escama", (w * 0.28, 0.02, 0.05), (-w * 0.3 + k * w * 0.3, 0.155 - i * 0.006, z - 0.01), cla))
    for sx in (1, -1):
        p.append(caixa("Lobulo", (0.24, 0.10, 0.20), (sx * 0.15, 0.02, -0.62), esc))
        p.append(caixa("Lobulo2", (0.30, 0.09, 0.10), (sx * 0.17, 0.03, -0.70), cla))
        p.append(caixa("Ponta", (0.14, 0.08, 0.06), (sx * 0.26, 0.04, -0.71), cla))
    exportar(p, "acessorios", "barbatana_sereia")


# --------------------------------------------------------- pelúcia de urso
def pelucia_urso():
    """Orelhas redondas de urso (miolo bege), focinho com nariz e tira marrom em
    volta da cabeça. Origem no centro da FACE FRONTAL (±0,25 em X e Z)."""
    limpar()
    pel = mat("Pelo", (0.45, 0.27, 0.13), 0.0, 1.0)
    cla = mat("Focinho", (0.86, 0.70, 0.48), 0.0, 1.0)
    nariz = mat("Nariz", (0.10, 0.06, 0.05), 0.0, 0.6)
    p = [caixa("Focinho", (0.24, 0.10, 0.15), (0, 0.05, -0.115), cla), caixa("Queixo", (0.14, 0.07, 0.05), (0, 0.045, -0.20), cla),
         caixa("Nariz", (0.07, 0.05, 0.05), (0, 0.11, -0.07), nariz), caixa("Boca", (0.02, 0.03, 0.05), (0, 0.105, -0.125), nariz),
         caixa("Tira", (0.54, 0.03, 0.06), (0, -0.755, 0.05), pel), caixa("TiraF", (0.45, 0.025, 0.05), (0, 0.012, 0.06), pel)]
    for sx in (1, -1):
        p.append(caixa("TiraL", (0.03, 0.76, 0.06), (sx * 0.265, -0.37, 0.05), pel))
        p.append(caixa("Orelha", (0.15, 0.10, 0.15), (sx * 0.19, -0.14, 0.31), pel))
        p.append(caixa("OrelhaMiolo", (0.09, 0.03, 0.09), (sx * 0.19, -0.085, 0.31), cla))
    exportar(p, "acessorios", "pelucia_urso")


# --------------------------------------------- cabelo longo ondulado com flores
def cabelo_longo_ondulado_flores():
    """Cabelo longo em ondas largas com pequenas flores brancas presas. Origem no
    centro do topo do crânio; desce até z = −1,25."""
    import random
    random.seed(17)
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    flor = mat("Flor", (0.97, 0.95, 0.88), 0.0, 0.8)
    mei = mat("FlorMeio", (0.95, 0.78, 0.2), 0.0, 0.8)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.10), (0, 0, -0.045), cab),
         caixa("Volume", (L * 0.92, P * 0.86, 0.05), (0, -0.02, 0.03), cab),
         caixa("Franja", (L, 0.07, 0.15), (0, P * 0.5 - 0.035, -0.075), cab),
         caixa("FranjaL", (0.18, 0.07, 0.18), (0.13, P * 0.5 - 0.035, -0.19), cab)]
    n = 12
    for i in range(n):
        z = -0.12 - i * 0.095
        dx = 0.05 * (1 if (i // 2) % 2 == 0 else -1)
        p.append(caixa("Costas%d" % i, (L - 0.02 - i * 0.004, 0.12, 0.10), (dx, -(P * 0.5 - 0.05) - 0.012 * (i % 3), z), cab))
        for sx in (1, -1):
            if i < 9:
                p.append(caixa("Lado%d" % i, (0.085, 0.13, 0.10), (sx * (L * 0.5 + 0.0) + sx * 0.03 * (1 if (i + (sx < 0)) % 2 == 0 else -1), -0.05 + 0.04 * (1 if i % 2 else -1) + (P * 0.5 - 0.17), z - 0.1), cab))
    for i in range(4):
        x, y, z = random.choice([(0.26, 0.20, -0.05), (-0.25, 0.10, -0.12), (0.27, -0.10, -0.45), (-0.2, -0.40, -0.1), (0.1, -0.41, -0.6)])
        p.append(caixa("Flor", (0.06, 0.02, 0.06), (x, y + 0.0, z), flor))
        p.append(caixa("Meio", (0.025, 0.025, 0.025), (x, y + 0.012, z), mei))
    exportar(p, "cabelos", "cabelo_longo_ondulado_flores")


# ------------------------------------------------------------ cabelo anime espetado
def cabelo_anime_azul_espetado():
    """Cabelo curto de anime com grandes espetos em todas as direções e duas
    mechas sobre a testa. Origem no centro do topo do crânio."""
    import math
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L, P, 0.12), (0, 0, -0.06), cab), caixa("Nuca", (L, 0.10, 0.22), (0, -(P * 0.5 - 0.05), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.22), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.11), cab))
    # espetos: base na cabeça (x, y) + direção (dx, dy, dz); degraus contíguos que afinam
    spikes = [(-0.18, 0.22, -0.5, 0.5, 1.0), (0.0, 0.28, 0.0, 0.8, 0.9), (0.18, 0.22, 0.5, 0.5, 1.0),
              (-0.22, 0.0, -1.0, 0.0, 0.8), (0.22, 0.0, 1.0, 0.0, 0.8), (0.0, 0.0, 0.0, 0.0, 1.0),
              (-0.2, -0.22, -0.7, -0.6, 0.9), (0.2, -0.22, 0.7, -0.6, 0.9), (0.0, -0.3, 0.0, -1.0, 0.8),
              (-0.1, 0.1, -0.3, 0.3, 1.0), (0.1, 0.1, 0.3, 0.3, 1.0), (-0.12, -0.1, -0.3, -0.3, 1.0), (0.12, -0.1, 0.3, -0.3, 1.0)]
    for k, (x, y, dx, dy, dz) in enumerate(spikes):
        n = math.sqrt(dx * dx + dy * dy + dz * dz)
        dx, dy, dz = dx / n, dy / n, dz / n
        for j, w in enumerate((0.16, 0.13, 0.10, 0.075, 0.05)):
            t = 0.04 + 0.055 * j
            p.append(caixa("Espeto%d_%d" % (k, j), (w, w, w), (x + dx * t, y + dy * t, 0.0 + dz * t * 1.3), cab))
    p.append(caixa("Mecha1", (0.08, 0.07, 0.24), (-0.10, P * 0.5 - 0.03, -0.14), cab))
    p.append(caixa("Mecha2", (0.08, 0.07, 0.20), (0.06, P * 0.5 - 0.03, -0.12), cab))
    p.append(caixa("Mecha3", (0.07, 0.07, 0.16), (0.16, P * 0.5 - 0.03, -0.10), cab))
    exportar(p, "cabelos", "cabelo_anime_azul_espetado")


# ------------------------------------------------------- cabelo duas tranças
def cabelo_duas_trancas_curtas():
    """Cabelo na altura do queixo com duas tranças curtas à frente dos ombros,
    amarradas com elásticos dourados. Origem no centro do topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    ouro = mat("Elastico", (0.85, 0.65, 0.25), 0.3, 0.6)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.9, P * 0.85, 0.05), (0, -0.02, 0.03), cab),
         caixa("Franja", (L + 0.02, 0.08, 0.20), (0, P * 0.5 - 0.01, -0.10), cab),
         caixa("Costas", (L + 0.03, 0.13, 0.46), (0, -(P * 0.5 - 0.05), -0.23), cab),
         caixa("CostasBaixo", (L * 0.85, 0.10, 0.08), (0, -(P * 0.5 - 0.04), -0.50), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.66, 0.40), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.20), cab))
        p.append(caixa("LadoFrente", (0.08, 0.09, 0.30), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.15), cab))
        for i in range(8):
            dx = 0.03 if i % 2 else -0.03
            p.append(caixa("Tranca%d" % i, (0.115, 0.11, 0.095), (sx * (0.20 + dx), P * 0.5 - 0.20, -0.42 - i * 0.085), cab))
        p.append(caixa("Elo", (0.09, 0.12, 0.045), (sx * 0.20, P * 0.5 - 0.20, -1.12), ouro))
        p.append(caixa("Ponta", (0.07, 0.07, 0.08), (sx * 0.20, P * 0.5 - 0.20, -1.19), cab))
    exportar(p, "cabelos", "cabelo_duas_trancas_curtas")


# ---------------------------------------------------------- gorro de lã
def gorro_la_pompom():
    """Gorro de tricô bordô com barra dobrada e pompom creme. Origem no topo da
    cabeça."""
    import random
    random.seed(41)
    limpar()
    bor = mat("Gorro", (0.50, 0.06, 0.13), 0.0, 1.0)
    esc = mat("GorroSombra", (0.36, 0.04, 0.09), 0.0, 1.0)
    cre = mat("Pompom", (0.95, 0.90, 0.75), 0.0, 1.0)
    p = [caixa("Barra", (0.58, 0.82, 0.11), (0, 0, 0.02), esc), caixa("Corpo", (0.55, 0.78, 0.15), (0, 0, 0.14), bor),
         caixa("Topo", (0.46, 0.66, 0.10), (0, 0, 0.245), bor), caixa("Topo2", (0.32, 0.46, 0.06), (0, 0, 0.32), bor)]
    for i in range(7):
        p.append(caixa("Trico", (0.04, 0.79, 0.15), (-0.21 + i * 0.07, 0, 0.14), esc))
    for i in range(14):
        p.append(caixa("Pompom", (0.07, 0.07, 0.07), (random.uniform(-0.06, 0.06), random.uniform(-0.06, 0.06), 0.40 + random.uniform(-0.05, 0.06)), cre))
    p.append(caixa("PompomMiolo", (0.12, 0.12, 0.12), (0, 0, 0.40), cre))
    exportar(p, "acessorios", "gorro_la_pompom")


# ------------------------------------------------------ colete salva-vidas
def colete_salva_vidas():
    """Colete salva-vidas laranja com duas cintas pretas, fivelas e faixas
    refletivas. Relativo ao nó Chest."""
    limpar()
    lar = mat("Colete", (0.98, 0.45, 0.05), 0.0, 0.7)
    esc = mat("ColeteSombra", (0.80, 0.32, 0.03), 0.0, 0.7)
    preto = mat("Preto", (0.06, 0.06, 0.07), 0.0, 0.6)
    ref = mat("Reflexo", (0.96, 0.96, 0.98), 0.3, 0.3)
    p = [caixa("Costas", (0.56, 0.08, 0.48), (0, -0.20, -0.02), lar), caixa("Ombros", (0.56, 0.38, 0.06), (0, 0, 0.255), esc)]
    for sx in (1, -1):
        p.append(caixa("Frente", (0.22, 0.09, 0.50), (sx * 0.145, 0.19, -0.02), lar))
        p.append(caixa("Lado", (0.05, 0.30, 0.46), (sx * 0.285, 0, -0.02), esc))
        p.append(caixa("Refl", (0.16, 0.02, 0.05), (sx * 0.145, 0.24, 0.14), ref))
    for z in (0.0, -0.19):
        p.append(caixa("Cinta", (0.58, 0.40, 0.045), (0, 0, z), preto))
        p.append(caixa("Fivela", (0.09, 0.03, 0.07), (0, 0.215, z), preto))
    p.append(caixa("ReflT", (0.30, 0.02, 0.05), (0, -0.25, 0.10), ref))
    exportar(p, "acessorios", "colete_salva_vidas")


# ------------------------------------------- casaco de capitão pirata (malha)
def casaco_pirata_vermelho():
    """Casaco longo vermelho com debrum, botões e punhos dourados, gola alta.
    Quatro GLBs (tronco, saia no Torso, mangas)."""
    mats = {"c": ("Casaco", (0.55, 0.07, 0.10), 0.0, 0.8), "o": ("Ouro", (0.92, 0.70, 0.16), 0.8, 0.4),
            "v": ("Vinco", (0.38, 0.04, 0.07), 0.0, 0.85)}
    tronco = [((0.245, 0.375, 0.58), (0.1525, 0, -0.04), "c"), ((0.245, 0.375, 0.58), (-0.1525, 0, -0.04), "c"),
              ((0.55, 0.045, 0.58), (0, -0.19, -0.04), "c"), ((0.34, 0.32, 0.12), (0, 0, 0.30), "c"),
              ((0.34, 0.03, 0.03), (0, 0, 0.365), "o"), ((0.03, 0.385, 0.58), (0.0375, 0, -0.04), "o"), ((0.03, 0.385, 0.58), (-0.0375, 0, -0.04), "o"),
              ((0.24, 0.045, 0.12), (0.0, -0.20, -0.30), "o")]
    for sx in (1, -1):
        for k in range(3):
            tronco.append(((0.04, 0.03, 0.04), (sx * 0.10, 0.205, 0.12 - k * 0.14), "o"))
    sup, inf = _bracos("c")
    vestir("capitao_vermelho", mats, tronco=tronco,
           saia=[((0.255, 0.37, 0.80), (0.165, 0, -0.23), "c"), ((0.255, 0.37, 0.80), (-0.165, 0, -0.23), "c"), ((0.58, 0.05, 0.80), (0, -0.18, -0.23), "c"),
                 ((0.59, 0.38, 0.04), (0, 0, -0.63), "o"), ((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "o"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "o"),
                 ((0.02, 0.055, 0.30), (0, -0.18, -0.50), "v")],
           manga_sup=sup, manga_inf=inf + [((0.32, 0.32, 0.08), (0, 0, -0.16), "v"), ((0.325, 0.325, 0.03), (0, 0, -0.12), "o"), ((0.04, 0.04, 0.04), (0, 0.16, -0.16), "o")])


# ------------------------------------------------------- papagaio no ombro
def papagaio_ombro():
    """Arara vermelha pousada no ombro direito do personagem (+X): corpo, cabeça
    com bico, asa azul-amarela e cauda. Relativo ao nó Chest (ombro em
    x=0,30, z=0,25)."""
    limpar()
    verm = mat("Vermelho", (0.85, 0.08, 0.08), 0.0, 0.7)
    az = mat("Azul", (0.10, 0.35, 0.90), 0.0, 0.7)
    am = mat("Amarelo", (0.98, 0.82, 0.15), 0.0, 0.7)
    br = mat("Branco", (0.97, 0.97, 0.97), 0.0, 0.8)
    pre = mat("Preto", (0.05, 0.05, 0.05), 0.0, 0.6)
    lar = mat("Bico", (0.30, 0.28, 0.26), 0.0, 0.6)
    x, z = 0.32, 0.30
    p = [caixa("Corpo", (0.11, 0.11, 0.18), (x, 0.0, z + 0.09), verm), caixa("Cabeca", (0.12, 0.12, 0.11), (x, 0.01, z + 0.23), verm),
         caixa("Face", (0.085, 0.02, 0.07), (x, 0.07, z + 0.235), br), caixa("Olho", (0.03, 0.02, 0.03), (x, 0.082, z + 0.245), pre),
         caixa("Bico", (0.05, 0.08, 0.05), (x, 0.09, z + 0.20), lar), caixa("BicoPonta", (0.035, 0.05, 0.035), (x, 0.13, z + 0.17), lar),
         caixa("AsaE", (0.025, 0.09, 0.13), (x - 0.07, 0.0, z + 0.11), az), caixa("AsaD", (0.025, 0.09, 0.13), (x + 0.07, 0.0, z + 0.11), az),
         caixa("AsaAm", (0.027, 0.09, 0.06), (x - 0.07, 0.0, z + 0.03), am), caixa("AsaAmD", (0.027, 0.09, 0.06), (x + 0.07, 0.0, z + 0.03), am),
         caixa("Pata", (0.08, 0.04, 0.03), (x, 0.0, z - 0.005), lar)]
    for k, (m, dx) in enumerate(((verm, -0.025), (am, 0.0), (az, 0.025))):
        p.append(caixa("Cauda%d" % k, (0.035, 0.04, 0.20), (x + dx, -0.07 - k * 0.01, z - 0.10), m))
    exportar(p, "acessorios", "papagaio_ombro")


# ----------------------------------------------- chapéu de capitão pirata
def chapeu_capitao_pirata():
    """Chapéu de capitão preto com debrum dourado, faixa vermelha, caveira na
    frente e pena branca alta. Origem no topo da cabeça."""
    limpar()
    pre = mat("Preto", (0.06, 0.06, 0.07), 0.0, 0.8)
    ouro = mat("Ouro", (0.90, 0.68, 0.14), 0.8, 0.4)
    verm = mat("Faixa", (0.60, 0.06, 0.08), 0.0, 0.8)
    br = mat("Osso", (0.95, 0.94, 0.90), 0.0, 0.6)
    p = [caixa("Copa", (0.50, 0.66, 0.15), (0, 0, 0.085), pre), caixa("Faixa", (0.52, 0.68, 0.05), (0, 0, 0.04), verm),
         caixa("Aba", (0.74, 0.96, 0.04), (0, 0, 0.0), pre), caixa("CopaTopo", (0.42, 0.58, 0.03), (0, 0, 0.175), pre)]
    for sx in (1, -1):
        p.append(caixa("AbaLado", (0.05, 0.86, 0.11), (sx * 0.385, 0, 0.065), pre))
        p.append(caixa("AbaLadoOuro", (0.055, 0.88, 0.025), (sx * 0.385, 0, 0.125), ouro))
    p.append(caixa("AbaFrente", (0.60, 0.05, 0.13), (0, 0.48, 0.075), pre))
    p.append(caixa("AbaFrenteOuro", (0.62, 0.055, 0.025), (0, 0.48, 0.14), ouro))
    p.append(caixa("Caveira", (0.12, 0.03, 0.10), (0, 0.51, 0.08), br))
    p.append(caixa("OlhoE", (0.03, 0.035, 0.03), (-0.03, 0.52, 0.09), pre)); p.append(caixa("OlhoD", (0.03, 0.035, 0.03), (0.03, 0.52, 0.09), pre))
    for k in range(5):     # pena
        p.append(caixa("Pena%d" % k, (0.06 - k * 0.006, 0.03, 0.09), (0.28 + k * 0.04, 0.10 - k * 0.04, 0.12 + k * 0.08), br))
    exportar(p, "acessorios", "chapeu_capitao_pirata")


# -------------------------------------------------------- samurai (malha + kabuto)
def armadura_samurai():
    mats = {"c": ("Casaco", (0.55, 0.08, 0.08), 0.0, 0.5), "o": ("Ouro", (0.92, 0.70, 0.16), 0.8, 0.4),
            "k": ("Preto", (0.07, 0.07, 0.08), 0.0, 0.6), "v": ("Vinco", (0.38, 0.05, 0.05), 0.0, 0.6)}
    tronco = _base("c") + [((0.575, 0.385, 0.04), (0, 0, 0.17 - k * 0.11), "o") for k in range(5)] + \
             [((0.575, 0.385, 0.06), (0, 0, -0.30), "k"), ((0.08, 0.04, 0.08), (0, 0.205, -0.30), "k"), ((0.06, 0.06, 0.20), (0.07, 0.21, -0.40), "k"),
              ((0.34, 0.33, 0.07), (0, 0, 0.27), "v")]
    for sx in (1, -1):
        tronco.append(((0.07, 0.40, 0.03), (sx * 0.15, 0, 0.26), "k"))
    saia = []
    for i, x in enumerate((-0.22, -0.11, 0.0, 0.11, 0.22)):
        saia.append(((0.105, 0.38, 0.46), (x, 0, -0.06), "c" if i % 2 == 0 else "v"))
        saia.append(((0.11, 0.39, 0.03), (x, 0, -0.30), "o"))
    vestir("samurai", mats, tronco=tronco, saia=saia,
           manga_sup=[((0.37, 0.37, 0.07), (0, 0, 0.03), "c"), ((0.38, 0.38, 0.03), (0, 0, 0.07), "o"), ((0.38, 0.38, 0.07), (0, 0, -0.05), "v"),
                      ((0.39, 0.39, 0.03), (0, 0, -0.09), "o"), ((0.38, 0.38, 0.07), (0, 0, -0.14), "c"), ((0.39, 0.39, 0.03), (0, 0, -0.18), "o"),
                      ((0.27, 0.27, 0.15), (0, 0, -0.24), "k")],
           manga_inf=[((0.27, 0.27, 0.13), (0, 0, -0.065), "k"), ((0.31, 0.31, 0.11), (0, 0, -0.16), "c"), ((0.315, 0.315, 0.025), (0, 0, -0.115), "o"), ((0.315, 0.315, 0.025), (0, 0, -0.205), "o")])
    limpar()
    v = mat("Casaco", (0.55, 0.08, 0.08), 0.0, 0.5); o = mat("Ouro", (0.92, 0.70, 0.16), 0.8, 0.4); k = mat("Preto", (0.07, 0.07, 0.08), 0.0, 0.6)
    p = [caixa("Casco", (0.56, 0.78, 0.14), (0, 0, 0.07), v), caixa("Topo", (0.44, 0.62, 0.08), (0, 0, 0.17), v), caixa("Pico", (0.28, 0.40, 0.06), (0, 0, 0.24), v),
         caixa("Aba", (0.62, 0.84, 0.04), (0, 0.0, -0.01), o), caixa("Pescoco", (0.64, 0.10, 0.22), (0, -0.40, -0.10), v),
         caixa("PescocoOuro", (0.66, 0.11, 0.03), (0, -0.40, -0.22), o), caixa("Crista", (0.05, 0.22, 0.05), (0, 0.38, 0.12), o)]
    for sx in (1, -1):
        p.append(caixa("Orelha", (0.07, 0.30, 0.24), (sx * 0.34, -0.05, -0.12), v))
        p.append(caixa("OrelhaOuro", (0.075, 0.32, 0.03), (sx * 0.34, -0.05, -0.23), o))
        for j in range(3):
            p.append(caixa("Chifre%d" % j, (0.045, 0.045, 0.07), (sx * (0.06 + j * 0.05), 0.38, 0.17 + j * 0.06), o))
    p.append(caixa("Emblema", (0.10, 0.04, 0.10), (0, 0.39, 0.06), o))
    exportar(p, "acessorios", "kabuto_samurai")


# --------------------------------------------------- capa de viajante com remendos
def capa_viajante_remendos():
    """Capa marrom esfarrapada com capelo, fivela de couro e remendos coloridos.
    Mesma origem/encaixe da capa_marinha (topo do pescoço, pende para −Z)."""
    import random
    random.seed(52)
    limpar()
    mar = mat("CapaMarrom", (0.36, 0.20, 0.10), 0.0, 0.95)
    esc = mat("CapaSombra", (0.26, 0.14, 0.07), 0.0, 0.95)
    rem = [mat("Remendo%d" % i, c, 0.0, 0.95) for i, c in enumerate([(0.62, 0.45, 0.25), (0.62, 0.22, 0.18), (0.45, 0.50, 0.30), (0.70, 0.60, 0.40)])]
    ouro = mat("Fivela", (0.80, 0.62, 0.22), 0.8, 0.4)
    couro = mat("Couro", (0.25, 0.14, 0.07), 0.0, 0.8)
    p = [caixa("Capelo", (0.50, 0.14, 0.18), (0, -0.20, 0.08), esc), caixa("CapeloTopo", (0.46, 0.30, 0.08), (0, -0.14, 0.17), mar),
         caixa("Manto", (0.94, 0.54, 0.12), (0, -0.07, -0.12), mar), caixa("Cinta", (0.30, 0.03, 0.04), (0, 0.13, -0.03), couro),
         caixa("Fivela", (0.07, 0.04, 0.06), (0, 0.15, -0.03), ouro)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.96, 1.04, 1.12]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), mar if i % 2 == 0 else esc))
        for k in range(3):    # barra esfarrapada
            if i == 4:
                p.append(caixa("Rasgo", (0.10, 0.058, random.uniform(0.04, 0.12)), (-0.45 + k * 0.45 + random.uniform(-0.05, 0.05), -0.25, z - 0.22 - 0.03), mar))
        z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.85), (sx * 0.45, -0.07, -0.60), mar))
    for i in range(7):
        side = random.choice((1, -1))
        p.append(caixa("Remendo", (0.13, 0.015, 0.13), (random.uniform(-0.42, 0.42), -0.285, random.uniform(-1.0, -0.4)), rem[i % 4]))
    for sx in (1, -1):
        p.append(caixa("RemendoFrente", (0.015, 0.14, 0.12), (sx * 0.475, -0.07, -0.55 - 0.15 * (sx > 0)), rem[(sx + 2) % 4]))
    exportar(p, "acessorios", "capa_viajante_remendos")


# ----------------------------------------------------------- hakama + haori
def hakama_haori():
    mats = {"c": ("Casaco", (0.62, 0.68, 0.82), 0.0, 0.8), "h": ("Hakama", (0.10, 0.14, 0.34), 0.0, 0.8),
            "b": ("Branco", (0.93, 0.93, 0.96), 0.0, 0.9), "k": ("Preto", (0.06, 0.06, 0.07), 0.0, 0.6)}
    tronco = [((0.245, 0.375, 0.58), (0.1525, 0, -0.04), "c"), ((0.245, 0.375, 0.58), (-0.1525, 0, -0.04), "c"),
              ((0.55, 0.045, 0.58), (0, -0.19, -0.04), "c"), ((0.30, 0.30, 0.07), (0, 0, 0.27), "c"),
              ((0.07, 0.04, 0.46), (0.08, 0.195, 0.02), "b"), ((0.07, 0.04, 0.46), (-0.08, 0.195, 0.02), "b"),
              ((0.05, 0.04, 0.14), (0, 0.205, -0.20), "k"), ((0.58, 0.39, 0.05), (0, 0, -0.30), "k")]
    sup, inf = _bracos("c")
    saia = [((0.62, 0.42, 0.30), (0, 0, 0.02), "c"), ((0.60, 0.40, 0.04), (0, 0, 0.17), "k")]
    for i in range(7):
        saia.append(((0.095, 0.44 + (0.04 if i % 2 else 0.0), 0.66), (-0.27 + i * 0.09, 0, -0.32), "h"))
    saia.append(((0.72, 0.48, 0.03), (0, 0, -0.66), "h"))
    vestir("hakama", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=inf + [((0.34, 0.34, 0.12), (0, 0, -0.12), "c")])


# ------------------------------------------------------------------- ninja
def traje_ninja():
    mats = {"c": ("Casaco", (0.07, 0.09, 0.20), 0.0, 0.9), "v": ("Vinco", (0.05, 0.07, 0.16), 0.0, 0.9), "k": ("Preto", (0.05, 0.05, 0.07), 0.0, 0.8)}
    tronco = _base("c") + [((0.58, 0.40, 0.11), (0, 0, -0.17), "v"), ((0.10, 0.05, 0.22), (0.0, 0.2, -0.28), "v"), ((0.34, 0.33, 0.10), (0, 0, 0.28), "c"),
                           ((0.10, 0.04, 0.46), (0.07, 0.195, 0.03), "v"), ((0.10, 0.04, 0.46), (-0.07, 0.195, 0.03), "v")]
    for sx in (1, -1):
        tronco.append(((0.15, 0.40, 0.04), (sx * 0.26, 0, 0.255), "v"))
        tronco.append(((0.15, 0.40, 0.04), (sx * 0.30, 0, 0.215), "v"))
    sup, inf = _bracos("c")
    vestir("ninja", mats, tronco=tronco, manga_sup=sup + [((0.33, 0.33, 0.05), (0, 0, -0.30), "v")],
           manga_inf=inf + [((0.31, 0.31, 0.04), (0, 0, -0.06 - k * 0.07), "v") for k in range(3)],
           cintura=[((0.54, 0.30, 0.15), (0, 0, 0.09), "c")],
           coxa=[((0.30, 0.30, 0.36), (0, 0, -0.18), "c"), ((0.28, 0.28, 0.04), (0, 0, -0.34), "v")],
           canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "c")] + [((0.285, 0.285, 0.035), (0, 0, -0.10 - k * 0.055), "v") for k in range(3)],
           pe=[((0.27, 0.32, 0.09), (0, 0, -0.05), "c"), ((0.26, 0.06, 0.07), (0, 0.17, -0.06), "v")])
    limpar()
    az = mat("Pano", (0.08, 0.10, 0.22), 0.0, 0.9)
    p = [caixa("Mascara", (0.52, 0.05, 0.26), (0, 0.025, -0.13), az), caixa("MascaraTopo", (0.34, 0.06, 0.05), (0, 0.03, -0.02), az),
         caixa("Faixa", (0.55, 0.04, 0.10), (0, 0.02, 0.12), az), caixa("FaixaTras", (0.54, 0.03, 0.10), (0, -0.755, 0.12), az),
         caixa("No", (0.10, 0.06, 0.12), (0, -0.78, 0.12), az), caixa("Ponta1", (0.05, 0.04, 0.22), (-0.04, -0.80, -0.00), az),
         caixa("Ponta2", (0.05, 0.04, 0.18), (0.05, -0.80, 0.02), az)]
    for sx in (1, -1):
        p.append(caixa("FaixaL", (0.03, 0.77, 0.10), (sx * 0.265, -0.37, 0.12), az))
        p.append(caixa("MascaraL", (0.03, 0.77, 0.26), (sx * 0.265, -0.37, -0.13), az)) if False else None
    exportar(p, "acessorios", "mascara_ninja_faixa")


# ------------------------------------------------------------ jaleco médico
def roupa_medica():
    mats = {"c": ("Casaco", (0.93, 0.94, 0.96), 0.0, 0.9), "v": ("Vinco", (0.78, 0.80, 0.84), 0.0, 0.9), "z": ("Cruz", (0.15, 0.40, 0.85), 0.0, 0.6),
            "g": ("Aco", (0.55, 0.57, 0.62), 0.5, 0.5)}
    tronco = [((0.245, 0.375, 0.58), (0.1525, 0, -0.04), "c"), ((0.245, 0.375, 0.58), (-0.1525, 0, -0.04), "c"),
              ((0.55, 0.045, 0.58), (0, -0.19, -0.04), "c"), ((0.34, 0.32, 0.08), (0, 0, 0.28), "c"),
              ((0.10, 0.04, 0.44), (0.05, 0.195, 0.04), "v"), ((0.10, 0.04, 0.44), (-0.05, 0.195, 0.04), "v"),
              ((0.09, 0.03, 0.09), (0.17, 0.2, 0.10), "c"), ((0.045, 0.035, 0.016), (0.17, 0.215, 0.10), "z"), ((0.016, 0.035, 0.045), (0.17, 0.215, 0.10), "z"),
              ((0.58, 0.04, 0.05), (0, -0.2, -0.22), "v")]
    sup, inf = _bracos("c")
    vestir("medico", mats, tronco=tronco,
           saia=[((0.255, 0.37, 0.66), (0.165, 0, -0.16), "c"), ((0.255, 0.37, 0.66), (-0.165, 0, -0.16), "c"), ((0.58, 0.05, 0.66), (0, -0.18, -0.16), "c"),
                 ((0.14, 0.04, 0.14), (0.17, 0.205, -0.20), "v"), ((0.14, 0.04, 0.14), (-0.17, 0.205, -0.20), "v")],
           manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "g"), ((0.06, 0.30, 0.12), (0.14, 0.0, -0.14), "v")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "g")])


# ------------------------------------------- uniforme de marinha branco
def uniforme_marinha_branco():
    mats = {"c": ("Casaco", (0.95, 0.95, 0.97), 0.0, 0.85), "a": ("Azul", (0.10, 0.20, 0.60), 0.0, 0.7), "o": ("Ouro", (0.95, 0.76, 0.18), 0.8, 0.4)}
    tronco = [((0.245, 0.375, 0.58), (0.1525, 0, -0.04), "c"), ((0.245, 0.375, 0.58), (-0.1525, 0, -0.04), "c"),
              ((0.55, 0.045, 0.58), (0, -0.19, -0.04), "c"), ((0.34, 0.32, 0.10), (0, 0, 0.29), "c"),
              ((0.03, 0.385, 0.58), (0.0375, 0, -0.04), "a"), ((0.03, 0.385, 0.58), (-0.0375, 0, -0.04), "a"),
              ((0.70, 0.06, 0.36), (0, -0.22, 0.12), "c"), ((0.72, 0.065, 0.04), (0, -0.22, -0.07), "a"), ((0.70, 0.065, 0.04), (0, -0.22, 0.30), "o"),
              ((0.32, 0.065, 0.20), (0, -0.225, 0.14), "a")]
    for sx in (1, -1):
        for k in range(4):
            tronco.append(((0.04, 0.03, 0.04), (sx * 0.12, 0.205, 0.14 - k * 0.12), "o"))
    saia = [((0.255, 0.37, 0.80), (0.165, 0, -0.23), "c"), ((0.255, 0.37, 0.80), (-0.165, 0, -0.23), "c"), ((0.58, 0.05, 0.80), (0, -0.18, -0.23), "c"),
            ((0.59, 0.38, 0.05), (0, 0, -0.62), "a"), ((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "a"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "a")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.33, 0.33, 0.045), (0, 0, 0.04), "o")]
    for k in range(6):
        sup.append(((0.03, 0.03, 0.10), (-0.12 + k * 0.05, 0.16, -0.0), "o"))
    vestir("marinha_branco", mats, tronco=tronco, saia=saia, manga_sup=sup,
           manga_inf=[(MANGA_INF[0], MANGA_INF[1], "c"), ((0.32, 0.32, 0.08), (0, 0, -0.16), "a")])


# ---------------------------------------------------------- túnica de monge
def tunica_monge():
    mats = {"c": ("Casaco", (0.95, 0.60, 0.06), 0.0, 0.9), "v": ("Vinco", (0.80, 0.46, 0.04), 0.0, 0.9)}
    tronco = [((0.20, 0.375, 0.58), (-0.17, 0, -0.04), "c"), ((0.55, 0.045, 0.58), (0, -0.19, -0.04), "c"), ((0.36, 0.38, 0.12), (-0.09, 0, 0.27), "v"),
              ((0.58, 0.39, 0.10), (0, 0, -0.22), "v"), ((0.14, 0.05, 0.18), (0.06, 0.21, -0.28), "v")]
    p = [osso("Drapeado", (0.22, 0.195, 0.22), (-0.22, 0.195, -0.12), 0.09, mat("Casaco", (0.95, 0.60, 0.06), 0.0, 0.9)) ]
    limpar()
    vestir("monge", mats, tronco=tronco,
           saia=[((0.60, 0.40, 0.70), (0, 0, -0.18), "c"), ((0.62, 0.41, 0.04), (0, 0, -0.54), "v"), ((0.03, 0.40, 0.70), (0.1, 0, -0.18), "v"), ((0.03, 0.40, 0.70), (-0.1, 0, -0.18), "v")],
           manga_sup=[((0.31, 0.31, 0.20), (0, 0, -0.07), "c")])
    limpar()
    mad = mat("Conta", (0.30, 0.15, 0.08), 0.0, 0.5)
    p = []
    import math
    for i in range(18):
        a = i / 18 * 2 * math.pi
        p.append(caixa("Conta", (0.05, 0.05, 0.05), (0.19 * math.cos(a), 0.17 * math.sin(a) + 0.0, 0.26), mad))
    for i in range(10):
        t = i / 9
        p.append(caixa("Conta", (0.055, 0.05, 0.055), (0.13 - 0.26 * t * 0.0 + (0.0), 0.20 - 0.0, 0.22 - i * 0.045), mad)) if False else None
    for sx in (1, -1):
        for i in range(7):
            p.append(caixa("ContaV", (0.055, 0.055, 0.055), (sx * (0.17 - i * 0.025), 0.19, 0.23 - i * 0.04), mad))
    exportar(p, "acessorios", "colar_contas")


# -------------------------------------------------------------- aventureiro
def roupa_aventureiro():
    """Colete de couro marrom com botões, cinto largo com bolsas e lanterninha,
    botas curtas de couro. Peças: tronco (Chest), cintura (Torso), canela e pé."""
    mats = {"c": ("Casaco", (0.36, 0.20, 0.10), 0.0, 0.75), "v": ("Vinco", (0.25, 0.13, 0.07), 0.0, 0.8), "o": ("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4),
            "l": ("Lapela", (0.46, 0.27, 0.14), 0.0, 0.75)}
    tronco = [((0.245, 0.375, 0.56), (0.1525, 0, -0.05), "c"), ((0.245, 0.375, 0.56), (-0.1525, 0, -0.05), "c"), ((0.55, 0.045, 0.56), (0, -0.19, -0.05), "c"),
              ((0.36, 0.34, 0.08), (0, 0, 0.275), "l"), ((0.13, 0.05, 0.12), (0.10, 0.20, 0.18), "l"), ((0.13, 0.05, 0.12), (-0.10, 0.20, 0.18), "l"),
              ((0.55, 0.12, 0.30), (0, -0.20, 0.11), "l")]
    for sx in (1, -1):
        for k in range(3):
            tronco.append(((0.04, 0.03, 0.04), (sx * 0.06, 0.205, 0.08 - k * 0.12), "o"))
        tronco.append(((0.06, 0.39, 0.04), (sx * 0.27, 0, 0.26), "v"))
    cintura = [((0.55, 0.30, 0.07), (0, 0, 0.08), "v"), ((0.09, 0.035, 0.08), (0, 0.17, 0.08), "o")]
    for sx in (1, -1):
        cintura.append(((0.11, 0.17, 0.15), (sx * 0.31, 0, 0.0), "c"))
        cintura.append(((0.12, 0.18, 0.05), (sx * 0.31, 0, 0.065), "v"))
        cintura.append(((0.05, 0.05, 0.12), (sx * 0.33, 0.12, -0.11), "o"))
    vestir("aventureiro", mats, tronco=tronco, cintura=cintura,
           canela=[((0.30, 0.30, 0.12), (0, 0, -0.22), "c"), ((0.31, 0.31, 0.04), (0, 0, -0.17), "v")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "c"), ((0.26, 0.07, 0.08), (0, 0.17, -0.06), "v"), ((0.28, 0.34, 0.03), (0, 0, -0.095), "v")])


# ------------------------------------------------------------ vestido de verão
def vestido_verao():
    mats = {"c": ("Casaco", (0.98, 0.90, 0.55), 0.0, 0.9), "v": ("Vinco", (0.88, 0.78, 0.42), 0.0, 0.9), "b": ("Branco", (0.99, 0.97, 0.90), 0.0, 0.9)}
    tronco = [((0.53, 0.36, 0.48), (0, 0, -0.07), "c"), ((0.06, 0.38, 0.03), (0.15, 0, 0.255), "c"), ((0.06, 0.38, 0.03), (-0.15, 0, 0.255), "c"),
              ((0.46, 0.04, 0.05), (0, 0.19, 0.17), "v"), ((0.575, 0.385, 0.05), (0, 0, -0.30), "v"), ((0.16, 0.05, 0.10), (0, 0.205, -0.30), "b"),
              ((0.06, 0.05, 0.16), (0.10, 0.205, -0.38), "b"), ((0.06, 0.05, 0.16), (-0.10, 0.205, -0.38), "b")]
    saia = []
    for i, (w, d, z) in enumerate([(0.60, 0.40, 0.08), (0.74, 0.50, -0.07), (0.88, 0.60, -0.22), (1.00, 0.70, -0.37)]):
        saia.append(((w, d, 0.15), (0, 0, z - 0.075 + 0.1), "c" if i % 2 == 0 else "v"))
    saia.append(((1.02, 0.72, 0.03), (0, 0, -0.50), "b"))
    vestir("vestido_verao", mats, tronco=tronco, saia=saia)
    limpar()
    palha = mat("Palha", (0.93, 0.80, 0.42), 0.0, 0.95)
    br = mat("Fita", (0.99, 0.97, 0.88), 0.0, 0.85)
    p = [caixa("Aba", (0.96, 1.10, 0.035), (0, 0, 0.0), palha), caixa("Aba2", (0.80, 0.94, 0.03), (0, 0, 0.03), palha),
         caixa("Copa", (0.52, 0.66, 0.15), (0, 0, 0.10), palha), caixa("CopaTopo", (0.46, 0.60, 0.03), (0, 0, 0.19), palha),
         caixa("Fita", (0.54, 0.68, 0.045), (0, 0, 0.06), br), caixa("Laco", (0.16, 0.04, 0.08), (0.20, 0.34, 0.065), br),
         caixa("LacoNo", (0.05, 0.05, 0.05), (0.20, 0.355, 0.065), br), caixa("LacoPonta", (0.04, 0.04, 0.12), (0.26, 0.36, 0.0), br)]
    exportar(p, "acessorios", "chapeu_palha_verao")


# ---------------------------------------------------- cabelo menta rabo baixo
def cabelo_menta_rabo_baixo():
    """Cabelo longo com mechas laterais e rabo baixo preso na nuca, com
    elásticos. Origem no centro do topo do crânio; rabo até z = −1,15."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    elas = mat("Elastico", (0.85, 0.85, 0.88), 0.2, 0.6)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.9, P * 0.86, 0.05), (0, -0.02, 0.03), cab),
         caixa("Franja", (L + 0.02, 0.08, 0.17), (0, P * 0.5 - 0.01, -0.085), cab), caixa("Nuca", (L, 0.12, 0.42), (0, -(P * 0.5 - 0.05), -0.21), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.66, 0.40), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.20), cab))
        p.append(caixa("Mecha", (0.09, 0.10, 0.86), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.43), cab))
        p.append(caixa("MechaPonta", (0.07, 0.09, 0.10), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.91), cab))
    yb = -P * 0.5 - 0.05
    p.append(caixa("Base", (0.24, 0.14, 0.16), (0, yb, -0.46), cab))
    p.append(caixa("Elastico", (0.26, 0.16, 0.035), (0, yb, -0.56), elas))
    for i, (w, z) in enumerate([(0.26, -0.70), (0.25, -0.84), (0.22, -0.97), (0.17, -1.08), (0.10, -1.16)]):
        p.append(caixa("Rabo%d" % i, (w, 0.15, 0.15), (0, yb - 0.01 * i, z), cab))
    p.append(caixa("Elastico2", (0.24, 0.16, 0.03), (0, yb - 0.02, -0.80), elas))
    exportar(p, "cabelos", "cabelo_menta_rabo_baixo")


# ----------------------------------------------------------- orelhas e cauda de lobo
def orelhas_lobo():
    limpar()
    cin = mat("Pelo", (0.36, 0.37, 0.40), 0.0, 1.0)
    esc = mat("PeloEscuro", (0.18, 0.19, 0.22), 0.0, 1.0)
    cla = mat("Miolo", (0.82, 0.80, 0.82), 0.0, 1.0)
    p = []
    for sx in (1, -1):
        for i, w in enumerate((0.15, 0.125, 0.10, 0.075, 0.045)):
            p.append(caixa("Orelha%d" % i, (w, 0.07, 0.065), (sx * (0.15 - 0.006 * i), -0.06, -0.01 + 0.065 * i + 0.03), cin if i < 4 else esc))
            if 0 < i < 4:
                p.append(caixa("Miolo%d" % i, (w * 0.55, 0.012, 0.06), (sx * (0.15 - 0.006 * i), -0.06 + 0.04, -0.01 + 0.065 * i + 0.03), esc))
        p.append(caixa("Pelo", (0.04, 0.05, 0.05), (sx * 0.22, -0.06, 0.03), cla))
    exportar(p, "acessorios", "orelhas_lobo")


def cauda_lobo():
    limpar()
    cores = [(0.20, 0.21, 0.24), (0.34, 0.35, 0.38), (0.55, 0.56, 0.60), (0.80, 0.80, 0.84), (0.96, 0.96, 0.98)]
    p = []
    n = 10
    for i in range(n):
        t = i / (n - 1)
        w = 0.10 + 0.16 * (1 - abs(2 * t - 0.9)) if t < 0.95 else 0.08
        y = -0.15 - 0.32 * t ** 1.4
        z = 0.08 - 0.80 * t
        c = cores[min(int(t * 5), 4)]
        m = mat("Pelo%d" % min(int(t * 5), 4), c, 0.0, 1.0)
        p.append(caixa("Seg%d" % i, (w, w * 0.95, 0.10), (0, y, z), m))
        for sx in (1, -1):
            p.append(caixa("Tufo", (0.045, w * 0.7, 0.08), (sx * (w * 0.5 + 0.005), y, z - 0.02), m))
    exportar(p, "acessorios", "cauda_lobo")


# ------------------------------------------------------------- chifres de cervo
def chifres_cervo():
    limpar()
    mad = mat("Galho", (0.35, 0.20, 0.10), 0.0, 0.9)
    fol = mat("Folha", (0.32, 0.65, 0.20), 0.0, 0.8)
    p = []
    for sx in (1, -1):
        pts = [(0.14, 0.0, 0.0), (0.17, 0.0, 0.08), (0.20, 0.0, 0.16), (0.24, 0.0, 0.24), (0.27, 0.0, 0.32), (0.29, 0.0, 0.40)]
        for a, b in zip(pts, pts[1:]):
            p.append(osso("Galho", (sx * a[0], -0.05, a[2]), (sx * b[0], -0.05, b[2]), 0.055, mad))
        for base, tip in (((0.17, 0.08), (0.05, 0.22)), ((0.24, 0.24), (0.40, 0.34)), ((0.20, 0.16), (0.36, 0.20))):
            p.append(osso("Ramo", (sx * base[0], -0.05, base[1]), (sx * tip[0], -0.05, tip[1]), 0.04, mad))
            p.append(caixa("Folha", (0.05, 0.03, 0.05), (sx * tip[0], -0.05, tip[1] + 0.025), fol))
            p.append(caixa("Folha2", (0.04, 0.03, 0.04), (sx * (tip[0] + 0.04), -0.05, tip[1]), fol))
        p.append(caixa("Folha", (0.05, 0.03, 0.05), (sx * 0.29, -0.05, 0.43), fol))
    exportar(p, "acessorios", "chifres_cervo")


# -------------------------------------------------- cabelo curto prateado
def cabelo_curto_prateado_mecha():
    import random
    limpar()
    random.seed(77)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.85)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab), caixa("Nuca", (L, 0.11, 0.24), (0, -(P * 0.5 - 0.055), -0.12), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.20), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.10), cab))
    for i in range(28):
        x = random.uniform(-L * 0.44, L * 0.44); y = random.uniform(-P * 0.40, P * 0.44)
        h = random.uniform(0.05, 0.14); w = random.uniform(0.07, 0.12)
        p.append(caixa("Tufo%d" % i, (w, w, h), (x, y, h * 0.5 - 0.01), cab))
    for k in range(5):    # mecha comprida varrida para o lado esquerdo (−X)
        p.append(caixa("Mecha%d" % k, (0.09, 0.08, 0.10), (-0.05 - k * 0.07, P * 0.5 - 0.03, -0.03 - k * 0.045), cab))
    p.append(caixa("Franja", (L * 0.6, 0.07, 0.12), (0.08, P * 0.5 - 0.03, -0.06), cab))
    exportar(p, "cabelos", "cabelo_curto_prateado_mecha")


# --------------------------------------------------- coroa de flores + borboleta
def coroa_flores():
    import math
    limpar()
    verde = mat("Folha", (0.30, 0.60, 0.22), 0.0, 0.8)
    cores = [(0.95, 0.45, 0.55), (0.98, 0.78, 0.30), (0.60, 0.40, 0.85), (0.45, 0.70, 0.95), (0.96, 0.96, 0.92)]
    mei = mat("Miolo", (0.98, 0.85, 0.25), 0.0, 0.7)
    p = []
    n = 24
    for i in range(n):
        t = i / n * 2 * math.pi
        x, y = 0.272 * math.cos(t), 0.392 * math.sin(t)
        p.append(caixa_rot("Folha", (0.09, 0.05, 0.04), (x, y, -0.04), verde, math.degrees(t) + 90 + (25 if i % 2 else -25)))
        if i % 2 == 0:
            m = mat("Flor%d" % (i // 2 % 5), cores[(i // 2) % 5], 0.0, 0.8)
            p.append(caixa("Flor", (0.10, 0.10, 0.06), (x * 1.02, y * 1.02, -0.01), m))
            p.append(caixa("Meio", (0.04, 0.04, 0.04), (x * 1.02, y * 1.02, 0.025), mei))
    exportar(p, "acessorios", "coroa_flores")


def asas_borboleta():
    limpar()
    rosa = mat("AsaRosa", (0.95, 0.55, 0.70), 0.0, 0.5)
    lar = mat("AsaLaranja", (0.98, 0.65, 0.30), 0.0, 0.5)
    rox = mat("AsaRoxa", (0.62, 0.38, 0.85), 0.0, 0.5)
    ner = mat("Nervura", (0.45, 0.22, 0.60), 0.0, 0.6)
    p = []
    y = -0.22
    for sx in (1, -1):
        sup = [(sx * 0.10, y, 0.22), (sx * 0.40, y, 0.72), (sx * 0.80, y, 0.90), (sx * 0.98, y, 0.62), (sx * 0.80, y, 0.24), (sx * 0.36, y, 0.12)]
        inf = [(sx * 0.10, y, 0.10), (sx * 0.40, y, 0.08), (sx * 0.62, y, -0.20), (sx * 0.52, y, -0.54), (sx * 0.28, y, -0.38), (sx * 0.10, y, -0.12)]
        for pts, mm in ((sup, rosa), (inf, rox)):
            faces = [(0, i, i + 1) if sx > 0 else (0, i + 1, i) for i in range(1, len(pts) - 1)]
            p.append(malha_plana("Asa", pts, faces, mm))
        mid = [(sx * 0.30, y - 0.002, 0.30), (sx * 0.62, y - 0.002, 0.62), (sx * 0.72, y - 0.002, 0.34)]
        p.append(malha_plana("Mancha", mid, [(0, 1, 2)] if sx > 0 else [(0, 2, 1)], lar))
        for tip in sup[2:5] + inf[2:5]:
            p.append(osso("Nervura", sup[0] if tip in sup else inf[0], tip, 0.02, ner))
    exportar(p, "acessorios", "asas_borboleta")


# ------------------------------------------------------- cinto com bússola e mapas
def cinto_bussola_mapas():
    """Cinto de couro com fivela, bússola dourada pendurada à direita do
    personagem (+X) e bolsa de mapas à esquerda (−X). Origem no nó Torso."""
    limpar()
    couro = mat("Couro", (0.42, 0.24, 0.11), 0.0, 0.7)
    escuro = mat("CouroEscuro", (0.26, 0.14, 0.07), 0.0, 0.7)
    ouro = mat("Ouro", (0.88, 0.66, 0.18), 0.85, 0.35)
    vidro = mat("Vidro", (0.85, 0.92, 0.95), 0.1, 0.1)
    agulha = mat("Agulha", (0.85, 0.12, 0.10), 0.0, 0.5)
    zc = 0.07
    p = [caixa("CintoF", (0.53, 0.03, 0.07), (0, 0.145, zc), escuro), caixa("CintoT", (0.53, 0.03, 0.07), (0, -0.145, zc), escuro),
         caixa("Fivela", (0.08, 0.035, 0.08), (0, 0.16, zc), ouro), caixa("FivelaMiolo", (0.04, 0.04, 0.04), (0, 0.165, zc), escuro)]
    for sx in (1, -1):
        p.append(caixa("CintoL", (0.03, 0.29, 0.07), (sx * 0.265, 0, zc), escuro))
    # bússola (+X): argola + corrente + corpo octogonal
    bx = 0.19
    p += [caixa("Argola", (0.04, 0.03, 0.04), (bx, 0.165, 0.02), ouro), caixa("Elo1", (0.02, 0.02, 0.05), (bx, 0.165, -0.02), ouro),
          caixa("Elo2", (0.02, 0.02, 0.05), (bx, 0.165, -0.065), ouro), caixa("Aro", (0.15, 0.04, 0.15), (bx, 0.165, -0.15), ouro),
          caixa("AroDiag", (0.11, 0.045, 0.19), (bx, 0.165, -0.15), ouro), caixa("Vidro", (0.11, 0.05, 0.11), (bx, 0.18, -0.15), vidro),
          caixa("Agulha", (0.025, 0.055, 0.09), (bx, 0.19, -0.15), agulha)]
    # bolsa de mapas (−X)
    mx = -0.22
    p += [caixa("Bolsa", (0.16, 0.08, 0.16), (mx, 0.17, -0.08), couro), caixa("Aba", (0.17, 0.09, 0.07), (mx, 0.17, -0.015), escuro),
          caixa("Fecho", (0.04, 0.095, 0.05), (mx, 0.17, -0.03), ouro), caixa("Alca", (0.03, 0.03, 0.08), (mx, 0.165, 0.03), escuro),
          caixa("Rolo", (0.05, 0.05, 0.16), (mx - 0.09, 0.14, -0.05), mat("Papel", (0.93, 0.87, 0.70), 0.0, 0.9))]
    exportar(p, "acessorios", "cinto_bussola_mapas")


# -------------------------------------------------------------- auréola neon
def aureola_neon():
    """Auréola fina de neon rosa-claro flutuando sobre a cabeça (emissiva: usar
    com "brilha"). Origem no centro do topo da cabeça."""
    import math
    limpar()
    m = mat("Neon", (1.0, 0.82, 0.92), 0.0, 0.3)
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Emission Color"].default_value = (1.0, 0.70, 0.88, 1.0)
    b.inputs["Emission Strength"].default_value = 3.5
    p = []
    for i in range(20):
        t = i / 20 * 2 * math.pi
        p.append(caixa_rot("Anel", (0.11, 0.035, 0.035), (0.27 * math.cos(t), 0.38 * math.sin(t), 0.20), m, math.degrees(t) + 90))
    exportar(p, "acessorios", "aureola_neon")


# ------------------------------------------------------- cabelo longo em camadas
def cabelo_longo_camadas():
    """Cabelo longo e liso em camadas com franja desfiada; as pontas terminam em
    degraus irregulares até z = −1,0. Origem no centro do topo do crânio."""
    import random
    limpar()
    random.seed(64)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.9, P * 0.86, 0.05), (0, -0.02, 0.03), cab)]
    for i in range(9):    # franja desfiada
        x = -0.24 + i * 0.06
        p.append(caixa("Franja", (0.065, 0.07, random.uniform(0.14, 0.26)), (x, P * 0.5 - 0.03, -0.13), cab))
    for i in range(9):
        x = -0.24 + i * 0.06
        for k, y in enumerate((-(P * 0.5 - 0.03), -(P * 0.5 - 0.10))):
            comp = random.uniform(0.80, 1.02) - 0.08 * k
            p.append(caixa("Costas", (0.066, 0.08, comp), (x, y, -comp * 0.5 - 0.03), cab))
    for sx in (1, -1):
        for j in range(6):
            y = -P * 0.5 + 0.14 + j * 0.12
            comp = random.uniform(0.55, 0.9)
            p.append(caixa("Lado", (0.08, 0.1, comp), (sx * (L * 0.5 + 0.02), y, -comp * 0.5 - 0.03), cab))
        for j in range(3):
            comp = random.uniform(0.70, 0.95)
            p.append(caixa("Mecha", (0.07, 0.09, comp), (sx * (0.17 + j * 0.05), P * 0.5 - 0.06, -comp * 0.5 - 0.1), cab))
    exportar(p, "cabelos", "cabelo_longo_camadas")


# ======================================================================= lote 7
def tenis_chunky_colorido():
    """Tênis grosso azul/vermelho/creme com solado alto e cadarços. Pivô no nó
    Foot (sola em z=−0,10), toe = +Y."""
    limpar()
    creme = mat("Creme", (0.94, 0.90, 0.80), 0.0, 0.7)
    azul = mat("Azul", (0.14, 0.26, 0.62), 0.0, 0.6)
    verm = mat("Vermelho", (0.80, 0.14, 0.16), 0.0, 0.6)
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.7)
    p = [caixa("Sola", (0.29, 0.35, 0.05), (0, 0.0, -0.075), creme), caixa("SolaTopo", (0.285, 0.34, 0.025), (0, 0, -0.035), br),
         caixa("Corpo", (0.27, 0.27, 0.10), (0, -0.02, 0.0), azul), caixa("Bico", (0.26, 0.10, 0.08), (0, 0.18, -0.015), creme),
         caixa("Lingua", (0.13, 0.04, 0.16), (0, 0.10, 0.10), verm), caixa("Cano", (0.28, 0.20, 0.07), (0, -0.07, 0.065), azul),
         caixa("Calcanhar", (0.20, 0.05, 0.14), (0, -0.165, 0.01), verm), caixa("Cadarco", (0.15, 0.03, 0.025), (0, 0.15, 0.04), br),
         caixa("Cadarco2", (0.15, 0.03, 0.025), (0, 0.11, 0.07), br)]
    exportar(p, "acessorios", "tenis_chunky_colorido")


def botas_cauboi_esporas():
    limpar()
    cou = mat("Couro", (0.50, 0.26, 0.10), 0.0, 0.7)
    esc = mat("CouroEscuro", (0.30, 0.15, 0.06), 0.0, 0.7)
    prata = mat("Prata", (0.78, 0.79, 0.83), 0.9, 0.3)
    p = [caixa("Sola", (0.29, 0.34, 0.035), (0, 0, -0.0825), esc), caixa("Salto", (0.26, 0.10, 0.05), (0, -0.115, -0.09), esc),
         caixa("Pe", (0.275, 0.33, 0.085), (0, 0, -0.025), cou), caixa("Bico", (0.24, 0.07, 0.07), (0, 0.19, -0.04), cou),
         caixa("Cano", (0.30, 0.285, 0.30), (0, -0.01, 0.125), cou), caixa("Boca", (0.315, 0.30, 0.05), (0, -0.01, 0.275), esc),
         caixa("Pico", (0.07, 0.03, 0.06), (0, 0.125, 0.30), esc), caixa("Costura", (0.04, 0.30, 0.20), (0, -0.01, 0.10), esc),
         caixa("Esporao", (0.04, 0.05, 0.05), (0, -0.18, -0.01), prata), caixa("Roseta", (0.08, 0.025, 0.08), (0, -0.20, -0.01), prata)]
    exportar(p, "acessorios", "botas_cauboi_esporas")


def sandalias_gladiador():
    limpar()
    cou = mat("Couro", (0.45, 0.24, 0.10), 0.0, 0.7)
    esc = mat("CouroEscuro", (0.28, 0.14, 0.06), 0.0, 0.7)
    p = [caixa("Sola", (0.27, 0.34, 0.04), (0, 0, -0.08), esc), caixa("TiraPe", (0.28, 0.07, 0.03), (0, 0.06, -0.03), cou),
         caixa("TiraPe2", (0.28, 0.07, 0.03), (0, -0.07, -0.03), cou), caixa("Tornozelo", (0.28, 0.28, 0.04), (0, 0, 0.02), cou)]
    for k in range(5):
        p.append(caixa("Cinta%d" % k, (0.29, 0.29, 0.03), (0, 0, 0.08 + k * 0.05), cou))
    for sx in (-1, 0, 1):
        p.append(caixa("Tira", (0.04, 0.03, 0.30), (sx * 0.08, 0.145, 0.16), esc))
    p.append(caixa("TiraT", (0.05, 0.03, 0.30), (0, -0.145, 0.16), esc))
    exportar(p, "acessorios", "sandalias_gladiador")


def luvas_boxe_vermelhas():
    """Luva de boxe vermelha grande com punho branco e fita. Pivô no punho
    (nó Hand): vai nas duas mãos."""
    limpar()
    v = mat("Vermelho", (0.85, 0.08, 0.08), 0.0, 0.35)
    vs = mat("VermelhoSombra", (0.62, 0.05, 0.06), 0.0, 0.4)
    br = mat("Branco", (0.96, 0.96, 0.97), 0.0, 0.8)
    p = [caixa("Punho", (0.26, 0.26, 0.07), (0, 0, 0.04), br), caixa("Fita", (0.27, 0.27, 0.02), (0, 0, 0.065), vs),
         caixa("Corpo", (0.25, 0.25, 0.20), (0, 0, -0.09), v), caixa("Topo", (0.22, 0.22, 0.10), (0, 0.0, -0.22), v),
         caixa("Dedos", (0.23, 0.12, 0.10), (0, 0.10, -0.25), v), caixa("Polegar", (0.07, 0.12, 0.12), (0.14, 0.03, -0.10), vs),
         caixa("Sombra", (0.23, 0.04, 0.12), (0, -0.13, -0.12), vs)]
    exportar(p, "acessorios", "luvas_boxe_vermelhas")


def tee_estrela_shorts():
    """Camiseta creme com estrela azul e shorts jeans de barra dobrada. Peças:
    tronco, manga_sup curta, cintura (Torso) e coxa (Thigh)."""
    mats = {"c": ("Casaco", (0.96, 0.92, 0.80), 0.0, 0.9), "j": ("Jeans", (0.22, 0.40, 0.70), 0.0, 0.9), "q": ("Jeansclaro", (0.40, 0.58, 0.82), 0.0, 0.9),
            "e": ("Jeans", (0.22, 0.40, 0.70), 0.0, 0.9)}
    tronco = _base("c") + [((0.34, 0.33, 0.06), (0, 0, 0.275), "c"), ((0.575, 0.385, 0.04), (0, 0, -0.31), "c"),
                           ((0.14, 0.03, 0.14), (0, 0.19, 0.04), "e"), ((0.07, 0.03, 0.22), (0, 0.19, 0.04), "e"), ((0.22, 0.03, 0.07), (0, 0.19, 0.075), "e"),
                           ((0.05, 0.03, 0.05), (0.09, 0.19, -0.04), "e"), ((0.05, 0.03, 0.05), (-0.09, 0.19, -0.04), "e")]
    vestir("tee_estrela", mats, tronco=tronco,
           manga_sup=[((0.30, 0.30, 0.20), (0, 0, -0.07), "c"), ((0.31, 0.31, 0.04), (0, 0, -0.16), "c")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "j"), ((0.55, 0.31, 0.03), (0, 0, 0.16), "q"), ((0.10, 0.03, 0.10), (0.15, 0.16, 0.06), "q"), ((0.10, 0.03, 0.10), (-0.15, 0.16, 0.06), "q")],
           coxa=[((0.27, 0.27, 0.22), (0, 0, -0.11), "j"), ((0.28, 0.28, 0.04), (0, 0, -0.22), "q"), ((0.03, 0.28, 0.20), (0.0, 0, -0.10), "q")])


def elmo_viking_barba():
    """Elmo viking de aço com faixa dourada, protetor de nariz e dois chifres
    de marfim; barba cheia trançada com argolas douradas caindo pelo peito."""
    limpar()
    aco = mat("Aco", (0.45, 0.47, 0.52), 0.8, 0.4)
    ouro = mat("Ouro", (0.88, 0.66, 0.16), 0.85, 0.35)
    osso = mat("Marfim", (0.94, 0.88, 0.74), 0.0, 0.6)
    pelo = mat("Barba", (0.38, 0.20, 0.10), 0.0, 0.95)
    p = [caixa("Domo", (0.56, 0.78, 0.12), (0, 0, 0.06), aco), caixa("Domo2", (0.46, 0.64, 0.08), (0, 0, 0.14), aco), caixa("Topo", (0.30, 0.42, 0.05), (0, 0, 0.20), aco),
         caixa("Faixa", (0.58, 0.80, 0.06), (0, 0, 0.01), ouro), caixa("Crista", (0.06, 0.60, 0.05), (0, 0, 0.215), ouro),
         caixa("Nariz", (0.07, 0.04, 0.20), (0, 0.395, -0.10), aco), caixa("NarizOuro", (0.08, 0.045, 0.03), (0, 0.40, -0.01), ouro)]
    for sx in (1, -1):
        p.append(caixa("Bochecha", (0.04, 0.20, 0.22), (sx * 0.29, 0.20, -0.12), aco))
        for i in range(5):
            x = sx * (0.30 + 0.045 * i + 0.0)
            z = 0.04 + 0.075 * i
            p.append(caixa("Chifre%d" % i, (0.11 - 0.014 * i, 0.10 - 0.012 * i, 0.09), (x, -0.0, z), osso))
    # barba cheia + tranças
    p += [caixa("Barba", (0.50, 0.12, 0.20), (0, 0.33, -0.34), pelo), caixa("BarbaBaixo", (0.40, 0.14, 0.22), (0, 0.35, -0.55), pelo),
          caixa("BarbaPonta", (0.26, 0.14, 0.20), (0, 0.36, -0.74), pelo), caixa("Bigode", (0.34, 0.08, 0.06), (0, 0.385, -0.25), pelo)]
    for sx in (1, -1):
        for i in range(6):
            dx = 0.02 if i % 2 else -0.02
            p.append(caixa("Tranca", (0.075, 0.08, 0.09), (sx * 0.20 + dx, 0.34, -0.80 - i * 0.075), pelo))
        p.append(caixa("Argola", (0.09, 0.09, 0.03), (sx * 0.20, 0.34, -0.80 - 5 * 0.075 - 0.07), ouro))
        p.append(caixa("Argola2", (0.09, 0.09, 0.03), (sx * 0.20, 0.34, -0.9), ouro))
    exportar(p, "acessorios", "elmo_viking_barba")


def colar_dentes():
    """Colar tribal de conchas e presas de marfim, relativo ao nó Chest."""
    import math
    limpar()
    cor = mat("Cordao", (0.30, 0.18, 0.10), 0.0, 0.8)
    conc = mat("Concha", (0.96, 0.92, 0.82), 0.0, 0.6)
    dente = mat("Marfim", (0.97, 0.94, 0.86), 0.0, 0.5)
    p = []
    for i in range(18):
        t = i / 18 * 2 * math.pi
        x, y = 0.19 * math.cos(t), 0.17 * math.sin(t)
        p.append(caixa("Conta", (0.05, 0.05, 0.05), (x, y, 0.26), cor))
    for i in range(7):
        a = -math.pi * (0.1 + 0.8 * i / 6)
        x = 0.19 * math.cos(a + math.pi) * -1 if False else (-0.17 + 0.34 * i / 6)
        y = 0.19 + 0.0
        z = 0.25 - 0.07 * math.sin(math.pi * i / 6)
        p.append(caixa("Concha", (0.07, 0.04, 0.06), (x, y, z - 0.02), conc))
        alt = 0.10 if i == 3 else 0.06
        p.append(caixa("Presa", (0.035, 0.03, alt), (x, y, z - 0.08 - alt * 0.3), dente))
        p.append(caixa("PresaPonta", (0.02, 0.025, 0.04), (x, y, z - 0.08 - alt * 0.9), dente))
    exportar(p, "acessorios", "colar_dentes")


def braceletes_dentes():
    """Bracelete de contas e presas no punho (nó ForeArm, parte de baixo)."""
    import math
    limpar()
    cor = mat("Cordao", (0.30, 0.18, 0.10), 0.0, 0.8)
    dente = mat("Marfim", (0.97, 0.94, 0.86), 0.0, 0.5)
    conc = mat("Concha", (0.96, 0.92, 0.82), 0.0, 0.6)
    p = [caixa("Faixa", (0.30, 0.30, 0.035), (0, 0, -0.185), cor)]
    for i in range(8):
        t = i / 8 * 2 * math.pi
        p.append(caixa("Concha", (0.05, 0.05, 0.05), (0.15 * math.cos(t), 0.15 * math.sin(t), -0.185), conc))
        p.append(caixa("Presa", (0.03, 0.03, 0.06), (0.16 * math.cos(t), 0.16 * math.sin(t), -0.225), dente))
    exportar(p, "acessorios", "braceletes_dentes")


def bailarina_tule():
    mats = {"c": ("Casaco", (0.98, 0.78, 0.84), 0.0, 0.7), "v": ("Vinco", (0.84, 0.64, 0.70), 0.0, 0.7), "t": ("Casaco", (0.98, 0.78, 0.84), 0.0, 0.7)}
    tronco = [((0.51, 0.35, 0.50), (0, 0, -0.06), "c"), ((0.40, 0.03, 0.06), (0, 0.18, 0.20), "v"), ((0.08, 0.38, 0.03), (0.15, 0, 0.26), "c"), ((0.08, 0.38, 0.03), (-0.15, 0, 0.26), "c"),
              ((0.55, 0.37, 0.04), (0, 0, -0.32), "v")]
    saia = [((0.58, 0.40, 0.08), (0, 0, 0.13), "v")]
    for i, (w, d, z) in enumerate([(0.60, 0.42, 0.04), (0.76, 0.54, -0.10), (0.92, 0.66, -0.24), (1.08, 0.78, -0.38), (1.22, 0.88, -0.52), (1.30, 0.96, -0.64)]):
        saia.append(((w, d, 0.15), (0, 0, z), "c" if i % 2 == 0 else "v"))
    vestir("bailarina", mats, tronco=tronco, saia=saia)


def jaqueta_jeans():
    mats = {"c": ("Casaco", (0.22, 0.38, 0.65), 0.0, 0.9), "v": ("Vinco", (0.15, 0.27, 0.48), 0.0, 0.9), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.3),
            "r": ("Gravata", (0.85, 0.15, 0.20), 0.0, 0.8), "y": ("Ouro", (0.98, 0.80, 0.20), 0.0, 0.7), "g": ("Espinho", (0.40, 0.75, 0.25), 0.0, 0.8),
            "l": ("Rosa", (0.75, 0.45, 0.85), 0.0, 0.8)}
    tronco = [((0.545, 0.365, 0.46), (0, 0, 0.0), "c"), ((0.555, 0.375, 0.06), (0, 0, -0.26), "v"), ((0.34, 0.33, 0.08), (0, 0, 0.275), "v"),
              ((0.13, 0.03, 0.12), (0.13, 0.19, 0.10), "v"), ((0.13, 0.03, 0.12), (-0.13, 0.19, 0.10), "v"), ((0.03, 0.03, 0.46), (0.0, 0.19, 0.0), "v")]
    for k in range(3):
        tronco.append(((0.03, 0.03, 0.03), (0.0, 0.2, 0.15 - k * 0.14), "p"))
    tronco += [((0.07, 0.03, 0.07), (0.15, 0.2, 0.09), "y"), ((0.07, 0.03, 0.06), (-0.14, 0.2, 0.07), "r"), ((0.09, 0.03, 0.05), (-0.14, 0.2, 0.12), "g"),
               ((0.10, 0.03, 0.10), (0.12, -0.19, -0.03), "l"), ((0.10, 0.03, 0.10), (-0.12, -0.19, -0.18), "y"), ((0.55, 0.04, 0.05), (0, -0.19, 0.12), "v")]
    sup, inf = _bracos("c")
    vestir("jeans_jaqueta", mats, tronco=tronco, manga_sup=sup + [((0.03, 0.03, 0.30), (0.145, 0.0, -0.15), "v")],
           manga_inf=inf + [((0.30, 0.30, 0.05), (0, 0, -0.18), "v"), ((0.035, 0.035, 0.035), (0, 0.15, -0.18), "p")])


def jeans_rasgado_regata():
    mats = {"c": ("Casaco", (0.50, 0.07, 0.12), 0.0, 0.85), "j": ("Jeans", (0.22, 0.40, 0.70), 0.0, 0.9), "q": ("Jeansclaro", (0.40, 0.58, 0.82), 0.0, 0.9),
            "r": ("Cruz", (0.82, 0.86, 0.90), 0.0, 0.9)}
    tronco = [((0.52, 0.355, 0.54), (0, 0, -0.05), "c"), ((0.12, 0.38, 0.03), (0.15, 0, 0.255), "c"), ((0.12, 0.38, 0.03), (-0.15, 0, 0.255), "c"),
              ((0.26, 0.04, 0.05), (0, 0.185, 0.20), "c")]
    vestir("jeans_rasgado", mats, tronco=tronco,
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "j"), ((0.55, 0.31, 0.03), (0, 0, 0.16), "q"), ((0.10, 0.03, 0.10), (0.14, 0.16, 0.05), "q"), ((0.10, 0.03, 0.10), (-0.14, 0.16, 0.05), "q")],
           coxa=[((0.27, 0.27, 0.36), (0, 0, -0.18), "j"), ((0.11, 0.03, 0.12), (0.0, 0.145, -0.14), "r"), ((0.10, 0.03, 0.06), (-0.04, 0.145, -0.28), "r")],
           canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "j"), ((0.285, 0.285, 0.05), (0, 0, -0.255), "q"), ((0.10, 0.03, 0.09), (0.03, 0.145, -0.08), "r"), ((0.08, 0.03, 0.05), (-0.05, 0.145, -0.17), "r")])


def capa_super_heroi():
    """Capa de super-herói vermelha com fechos dourados nos ombros e estrela
    dourada nas costas. Encaixe da capa_marinha (topo do pescoço)."""
    limpar()
    ve = mat("CapaVermelha", (0.78, 0.07, 0.10), 0.0, 0.75)
    esc = mat("CapaSombra", (0.58, 0.04, 0.07), 0.0, 0.75)
    ouro = mat("Ouro", (0.98, 0.80, 0.18), 0.9, 0.3)
    p = [caixa("Gola", (0.44, 0.06, 0.08), (0, -0.20, 0.04), esc), caixa("Manto", (0.92, 0.52, 0.10), (0, -0.07, -0.12), ve),
         caixa("Corrente", (0.34, 0.03, 0.03), (0, 0.15, -0.04), ouro)]
    for sx in (1, -1):
        p.append(caixa("Fecho", (0.08, 0.06, 0.08), (sx * 0.40, 0.0, -0.10), ouro))
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.98, 1.08, 1.18]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), ve if i % 2 == 0 else esc))
        z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.90), (sx * 0.46, -0.07, -0.62), ve))
    for dx, dz, w, h in ((0, 0, 0.09, 0.26), (0, 0, 0.26, 0.09), (0.0, 0, 0.18, 0.18)):
        p.append(caixa("Estrela", (w, 0.012, h), (dx, -0.285, -0.55 + dz), ouro))
    exportar(p, "acessorios", "capa_super_heroi")


def pintura_facial_listras():
    """Listras tribais turquesa e laranja sob os olhos (peça fina, 4 mm). Origem
    no centro da FACE FRONTAL (±0,25 em X/Z)."""
    limpar()
    tq = mat("Turquesa", (0.10, 0.65, 0.65), 0.0, 0.8)
    lar = mat("Laranja", (0.95, 0.50, 0.10), 0.0, 0.8)
    am = mat("Amarelo", (0.98, 0.82, 0.18), 0.0, 0.8)
    p = []
    for sx in (1, -1):
        for k, (m, w) in enumerate(((tq, 0.15), (lar, 0.16), (am, 0.13))):
            p.append(caixa("Listra%d" % k, (w, 0.006, 0.026), (sx * 0.12, 0.003, -0.08 - k * 0.04), m))
            p.append(caixa("ListraL%d" % k, (0.006, 0.10, 0.026), (sx * 0.2535, -0.04, -0.08 - k * 0.04), m))
    exportar(p, "acessorios", "pintura_facial_listras")


def tatuagem_braco():
    """Tatuagem tribal fina (linhas pretas em volta e diamante) na frente do
    braço, 3 mm sobre a pele. Pivô no nó UpperArm (ombro); uma peça por braço."""
    limpar()
    t = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.7)
    y = 0.1465
    p = [caixa("Faixa1", (0.29, 0.008, 0.012), (0, y, -0.28), t), caixa("Faixa2", (0.29, 0.008, 0.012), (0, y, -0.305), t),
         caixa("Linha", (0.012, 0.008, 0.14), (0.0, y, -0.14), t), caixa("Linha2", (0.10, 0.008, 0.012), (-0.05, y, -0.07), t),
         caixa("Linha3", (0.012, 0.008, 0.08), (-0.10, y, -0.04), t), caixa("Linha4", (0.012, 0.008, 0.06), (-0.10, y, -0.20), t),
         caixa("Diamante", (0.05, 0.008, 0.05), (-0.05, y, -0.15), t), caixa("DiamanteMiolo", (0.025, 0.009, 0.025), (-0.05, y, -0.15), mat("Pele", (0.62, 0.48, 0.40), 0.0, 0.8)),
         caixa("Linha5", (0.012, 0.008, 0.07), (-0.05, y, -0.22), t)]
    exportar(p, "acessorios", "tatuagem_braco")


def mascara_domino():
    """Máscara de herói (domino) azul quadrada em volta dos olhos. Origem no
    centro da FACE FRONTAL (±0,25 em X e Z)."""
    limpar()
    az = mat("Azul", (0.12, 0.30, 0.92), 0.0, 0.4)
    esc = mat("AzulEscuro", (0.08, 0.18, 0.60), 0.0, 0.5)
    vid = mat("Lente", (0.78, 0.90, 0.98, 1.0), 0.0, 0.1)
    p = [caixa("Ponte", (0.08, 0.03, 0.03), (0, 0.02, 0.05), az)]
    for sx in (1, -1):
        p.append(caixa("AroC", (0.17, 0.03, 0.025), (sx * 0.12, 0.02, 0.105), az)); p.append(caixa("AroB", (0.17, 0.03, 0.025), (sx * 0.12, 0.02, -0.0), az))
        p.append(caixa("AroE", (0.025, 0.03, 0.10), (sx * 0.04, 0.02, 0.05), az)); p.append(caixa("AroD", (0.025, 0.03, 0.10), (sx * 0.20, 0.02, 0.05), az))
        p.append(caixa("Haste", (0.03, 0.34, 0.03), (sx * 0.265, -0.17, 0.05), esc))
    exportar(p, "acessorios", "mascara_domino")


def cabelo_curto_volumoso():
    import random
    limpar()
    random.seed(90)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.12), (0, 0, -0.05), cab), caixa("Nuca", (L + 0.02, 0.13, 0.28), (0, -(P * 0.5 - 0.05), -0.14), cab),
         caixa("Volume", (L * 0.95, P * 0.9, 0.10), (0, 0, 0.05), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.65, 0.24), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.12), cab))
        p.append(caixa("Costeleta", (0.07, 0.09, 0.20), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.1, -0.10), cab))
    for i in range(24):
        x = random.uniform(-L * 0.46, L * 0.46); y = random.uniform(-P * 0.42, P * 0.44)
        h = random.uniform(0.04, 0.11); w = random.uniform(0.09, 0.14)
        p.append(caixa("Onda%d" % i, (w, w, h), (x, y, 0.10 + h * 0.5), cab))
    for i in range(8):
        p.append(caixa("Franja%d" % i, (0.085, 0.07, random.uniform(0.10, 0.20)), (-0.24 + i * 0.068, P * 0.5 - 0.03, -0.08), cab))
    exportar(p, "cabelos", "cabelo_curto_volumoso")


def elmo_cavaleiro():
    """Elmo de cavaleiro de aço com frisos azuis, abertura no rosto e plumas
    azuis. Origem no topo da cabeça."""
    limpar()
    aco = mat("Aco", (0.72, 0.74, 0.78), 0.9, 0.3)
    azul = mat("Azul", (0.12, 0.32, 0.95), 0.0, 0.5)
    esc = mat("AcoEscuro", (0.45, 0.47, 0.52), 0.8, 0.4)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), aco), caixa("Tras", (larg, 0.08, 0.56), (0, -prof * 0.5 + 0.04, -0.23), aco),
         caixa("Crista", (0.06, prof, 0.05), (0, 0, 0.115), azul), caixa("Brim", (larg, 0.08, 0.14), (0, prof * 0.5 - 0.04, -0.03), aco),
         caixa("BrimAzul", (larg - 0.02, 0.085, 0.025), (0, prof * 0.5 - 0.04, -0.115), azul), caixa("NarizBarra", (0.07, 0.07, 0.30), (0, prof * 0.5 - 0.035, -0.28), aco),
         caixa("Queixo", (larg - 0.1, 0.07, 0.07), (0, prof * 0.5 - 0.035, -0.50), esc)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, prof, 0.56), (sx * (larg * 0.5 - 0.04), 0, -0.23), aco))
        p.append(caixa("LadoAzul", (0.085, 0.55, 0.03), (sx * (larg * 0.5 - 0.04), -0.05, -0.20), azul))
        p.append(caixa("Bochecha", (0.09, 0.14, 0.40), (sx * (larg * 0.5 - 0.04), prof * 0.5 - 0.07, -0.30), esc))
    for i in range(6):     # plumas: arco para trás
        z = 0.13 + 0.04 * i
        y = -0.10 - 0.07 * i
        p.append(caixa("Pluma%d" % i, (0.20 - 0.012 * i, 0.10, 0.07), (0, y, z), azul))
        p.append(caixa("PlumaL", (0.07, 0.08, 0.08), (0.12 - 0.01 * i, y - 0.02, z - 0.02), azul))
        p.append(caixa("PlumaR", (0.07, 0.08, 0.08), (-0.12 + 0.01 * i, y - 0.02, z - 0.02), azul))
    exportar(p, "acessorios", "elmo_cavaleiro_plumas")


def chapeu_mago_azul():
    limpar()
    az = mat("Azul", (0.10, 0.18, 0.62), 0.0, 0.85)
    ouro = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    p = [caixa("Aba", (0.88, 0.98, 0.035), (0, 0, 0.0), az), caixa("Aba2", (0.76, 0.86, 0.03), (0, 0, 0.03), az),
         caixa("AbaOuro", (0.90, 1.00, 0.015), (0, 0, 0.0), ouro), caixa("Fita", (0.54, 0.64, 0.07), (0, 0, 0.085), ouro),
         caixa("FitaAzul", (0.50, 0.60, 0.04), (0, 0, 0.09), az), caixa("Fivela", (0.10, 0.04, 0.09), (0, 0.325, 0.085), ouro)]
    larg = [0.48, 0.42, 0.36, 0.30, 0.25, 0.20, 0.15]
    z = 0.12
    for i, w in enumerate(larg):
        p.append(caixa("Camada%d" % i, (w, w * 1.12, 0.095), (0, -0.025 * i, z + 0.0475), az))
        if i % 2 == 0:
            p.append(caixa("Estrela", (0.06, 0.012, 0.012), (0, w * 0.56 - 0.025 * i, z + 0.05), ouro))
            p.append(caixa("Estrela", (0.012, 0.012, 0.06), (0, w * 0.56 - 0.025 * i, z + 0.05), ouro))
        z += 0.095
    p.append(caixa("Ponta1", (0.10, 0.10, 0.09), (0.0, -0.20, z + 0.045), az))
    p.append(caixa("Ponta2", (0.08, 0.08, 0.08), (0.04, -0.24, z + 0.12), az))
    p.append(caixa("Ponta3", (0.06, 0.06, 0.06), (0.09, -0.26, z + 0.16), az))
    exportar(p, "acessorios", "chapeu_mago_azul")


def asas_dragao_pequenas():
    limpar()
    verde = mat("AsaVerde", (0.55, 0.80, 0.18), 0.0, 0.6)
    osso_m = mat("Osso", (0.22, 0.42, 0.12), 0.0, 0.6)
    p = []
    y = -0.22
    for sx in (1, -1):
        S = (sx * 0.10, y, 0.20)
        pts = [(sx * 0.30, y, 0.46), (sx * 0.60, y, 0.50), (sx * 0.62, y, 0.12), (sx * 0.50, y, -0.14), (sx * 0.26, y, -0.04)]
        cot = pts[0]
        p.append(osso("Braco", S, cot, 0.05, osso_m))
        for k, tip in enumerate(pts[1:]):
            p.append(osso("Dedo%d" % k, cot, tip, 0.035, osso_m))
        verts = [S, cot] + pts[1:]
        faces = [(0, i, i + 1) if sx > 0 else (0, i + 1, i) for i in range(2, len(verts) - 1)]
        p.append(malha_plana("Membrana", verts, faces, verde))
    exportar(p, "acessorios", "asas_dragao_pequenas")


def orelhas_cachorro():
    """Orelhas de cachorro marrons caídas dos dois lados da cabeça. Origem no
    topo; orelha pende da quina superior (x=±0,27, z=0) até z=−0,30."""
    limpar()
    mar = mat("Pelo", (0.45, 0.22, 0.10), 0.0, 0.95)
    esc = mat("PeloEscuro", (0.32, 0.15, 0.07), 0.0, 0.95)
    p = []
    for sx in (1, -1):
        for i in range(6):
            w = 0.09 + 0.02 * min(i, 3)
            p.append(caixa("Orelha%d" % i, (0.07, w + 0.05, 0.075), (sx * (0.30 + 0.015 * i), -0.05 - 0.01 * i, 0.03 - 0.065 * i), mar if i % 2 == 0 else esc))
        p.append(caixa("Base", (0.08, 0.12, 0.07), (sx * 0.28, -0.05, 0.045), esc))
        p.append(caixa("Ponta", (0.08, 0.14, 0.05), (sx * 0.38, -0.12, -0.30), esc))
    exportar(p, "acessorios", "orelhas_cachorro")


def coleira_couro():
    """Coleira de couro com fivela dourada e plaquinha. Relativo ao nó Chest."""
    limpar()
    cou = mat("Couro", (0.38, 0.20, 0.09), 0.0, 0.7)
    ouro = mat("Ouro", (0.92, 0.72, 0.18), 0.9, 0.3)
    p = [caixa("Frente", (0.34, 0.03, 0.06), (0, 0.17, 0.275), cou), caixa("Tras", (0.34, 0.03, 0.06), (0, -0.17, 0.275), cou)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.03, 0.34, 0.06), (sx * 0.17, 0, 0.275), cou))
    p += [caixa("Fivela", (0.08, 0.04, 0.08), (0, 0.185, 0.275), ouro), caixa("FivelaMiolo", (0.04, 0.045, 0.04), (0, 0.19, 0.275), cou),
          caixa("Placa", (0.05, 0.02, 0.05), (0.0, 0.19, 0.22), ouro)]
    exportar(p, "acessorios", "coleira_couro")


def tiara_gelo():
    limpar()
    gelo = mat("Gelo", (0.65, 0.85, 0.98), 0.3, 0.2)
    brilho = mat("GeloClaro", (0.92, 0.98, 1.0), 0.3, 0.1)
    azul = mat("GeloAzul", (0.35, 0.65, 0.95), 0.3, 0.2)
    zc = -0.02
    p = [caixa("Frente", (0.54, 0.03, 0.05), (0, P * 0.5 + 0.015, zc), gelo), caixa("Tras", (0.54, 0.03, 0.05), (0, -P * 0.5 - 0.015, zc), gelo)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.03, P, 0.05), (sx * 0.27, 0, zc), gelo))
        for k, (dx, h) in enumerate(((0.12, 0.10), (0.20, 0.07))):
            p.append(caixa("Cristal", (0.04, 0.04, h), (sx * dx, P * 0.5 + 0.015, zc + 0.05 + h * 0.5), brilho))
    for h, w, dx in ((0.18, 0.05, 0.0), (0.12, 0.04, 0.08), (0.12, 0.04, -0.08)):
        p.append(caixa("Pico", (w, 0.04, h), (dx, P * 0.5 + 0.015, zc + 0.04 + h * 0.5), brilho))
    p.append(caixa("Gema", (0.06, 0.04, 0.06), (0, P * 0.5 + 0.03, zc + 0.0), azul))
    exportar(p, "acessorios", "tiara_gelo")


def capa_neve():
    import random
    random.seed(12)
    limpar()
    az = mat("CapaGelo", (0.62, 0.78, 0.94), 0.0, 0.8)
    br = mat("Pelo", (0.97, 0.98, 1.0), 0.0, 1.0)
    cris = mat("Gelo", (0.50, 0.78, 0.98), 0.3, 0.2)
    flo = mat("Floco", (0.96, 0.98, 1.0), 0.0, 0.5)
    p = [caixa("PeleTras", (0.62, 0.14, 0.12), (0, -0.19, 0.06), br), caixa("Manto", (0.94, 0.54, 0.10), (0, -0.07, -0.12), az), caixa("PeleManto", (0.98, 0.58, 0.12), (0, -0.07, -0.08), br),
         caixa("Broche", (0.07, 0.04, 0.09), (0, 0.16, -0.02), cris)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.96, 1.04, 1.12]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), az))
        z -= 0.22
    p.append(caixa("Barra", (1.14, 0.08, 0.08), (0, -0.25, z + 0.04), br))
    for sx in (1, -1):
        p.append(caixa("PeleFrente", (0.12, 0.12, 0.95), (sx * 0.41, 0.12, -0.62), br))
        p.append(caixa("PanoLado", (0.05, 0.30, 0.82), (sx * 0.46, -0.07, -0.60), az))
        p.append(caixa("PeleLado", (0.14, 0.40, 0.14), (sx * 0.34, -0.05, -0.05), br))
        p.append(caixa("Flocos", (0.04, 0.012, 0.04), (sx * 0.20, -0.285, -0.45), flo))
    for dx, dz, w, h in ((0, 0, 0.05, 0.30), (0, 0, 0.30, 0.05), (0.0, 0, 0.22, 0.22)):
        p.append(caixa("Floco", (w, 0.012, h), (0, -0.285, -0.62 + dz), flo))
    for i in range(12):
        p.append(caixa("Pt", (0.035, 0.012, 0.035), (random.uniform(-0.45, 0.45), -0.285, random.uniform(-1.05, -0.4)), flo))
    exportar(p, "acessorios", "capa_neve")


def mascara_coruja():
    """Máscara veneziana de coruja dourada com penas turquesa, olhos vazados,
    bico e tira de couro. Origem no centro da FACE FRONTAL, cresce para +Y."""
    limpar()
    ouro = mat("Ouro", (0.90, 0.72, 0.28), 0.8, 0.35)
    cre = mat("Creme", (0.96, 0.92, 0.80), 0.0, 0.6)
    tq = mat("Turquesa", (0.08, 0.55, 0.55), 0.3, 0.5)
    tq2 = mat("TurquesaClara", (0.20, 0.75, 0.72), 0.3, 0.5)
    pre = mat("Preto", (0.04, 0.04, 0.05), 0.0, 0.6)
    cou = mat("Couro", (0.30, 0.16, 0.08), 0.0, 0.7)
    p = [caixa("Base", (0.48, 0.05, 0.22), (0, 0.025, 0.04), cre), caixa("Testa", (0.40, 0.06, 0.07), (0, 0.04, 0.14), ouro),
         caixa("Bico", (0.07, 0.07, 0.12), (0, 0.065, -0.02), ouro), caixa("BicoPonta", (0.04, 0.06, 0.05), (0, 0.075, -0.09), ouro),
         caixa("Gema", (0.05, 0.04, 0.05), (0, 0.06, 0.12), tq2), caixa("Topo", (0.10, 0.05, 0.12), (0, 0.03, 0.21), tq)]
    for sx in (1, -1):
        p.append(caixa("Olho", (0.12, 0.06, 0.10), (sx * 0.12, 0.035, 0.04), ouro))
        p.append(caixa("Vazado", (0.07, 0.08, 0.06), (sx * 0.12, 0.04, 0.04), pre))
        p.append(caixa("Sobrancelha", (0.15, 0.05, 0.035), (sx * 0.15, 0.06, 0.105), ouro))
        for k in range(4):
            p.append(caixa("Pena%d" % k, (0.07, 0.04, 0.11 - 0.01 * k), (sx * (0.26 + 0.06 * k), 0.02, 0.07 + 0.045 * k), tq if k % 2 == 0 else tq2))
        p.append(caixa("PenaCreme", (0.06, 0.03, 0.16), (sx * 0.23, 0.02, 0.24), cre))
        p.append(caixa("TiraL", (0.03, 0.78, 0.05), (sx * 0.265, -0.37, 0.04), cou))
    p.append(caixa("TiraT", (0.54, 0.03, 0.05), (0, -0.755, 0.04), cou)); p.append(caixa("Fivela", (0.07, 0.04, 0.07), (0.268, -0.25, 0.04), ouro))
    exportar(p, "acessorios", "mascara_coruja")


# ======================================================================= lote 8
def presas_vampiro():
    """Duas presas de vampiro sobre o lábio. Origem no centro da FACE FRONTAL."""
    limpar()
    d = mat("Marfim", (0.98, 0.96, 0.90), 0.0, 0.4)
    p = []
    for sx in (1, -1):
        p.append(caixa("Presa", (0.035, 0.035, 0.07), (sx * 0.065, 0.015, -0.155), d))
        p.append(caixa("PresaPonta", (0.022, 0.03, 0.04), (sx * 0.065, 0.015, -0.205), d))
    exportar(p, "acessorios", "presas_vampiro")


def capa_vampiro():
    limpar()
    pr = mat("CapaPreta", (0.04, 0.04, 0.05), 0.0, 0.8)
    ve = mat("Gravata", (0.55, 0.04, 0.07), 0.0, 0.8)
    ouro = mat("Ouro", (0.92, 0.72, 0.18), 0.9, 0.3)
    rub = mat("Rubi", (0.85, 0.08, 0.15), 0.2, 0.2)
    p = [caixa("GolaTras", (0.50, 0.06, 0.24), (0, -0.20, 0.12), pr), caixa("GolaForro", (0.46, 0.02, 0.20), (0, -0.165, 0.12), ve),
         caixa("GolaL1", (0.06, 0.30, 0.22), (-0.25, -0.05, 0.11), pr), caixa("GolaL2", (0.06, 0.30, 0.22), (0.25, -0.05, 0.11), pr),
         caixa("GolaLF1", (0.02, 0.28, 0.20), (-0.215, -0.05, 0.11), ve), caixa("GolaLF2", (0.02, 0.28, 0.20), (0.215, -0.05, 0.11), ve),
         caixa("Manto", (0.94, 0.54, 0.12), (0, -0.07, -0.12), pr), caixa("Broche", (0.07, 0.04, 0.07), (0, 0.16, -0.01), ouro), caixa("Rubi", (0.04, 0.045, 0.04), (0, 0.17, -0.01), rub)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.96, 1.04, 1.12]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), pr))
        z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.90), (sx * 0.46, -0.07, -0.62), pr))
        p.append(caixa("Forro", (0.02, 0.34, 0.88), (sx * 0.425, -0.07, -0.62), ve))
    exportar(p, "acessorios", "capa_vampiro")


def chifres_diabinho():
    limpar()
    v = mat("Chifre", (0.80, 0.08, 0.10), 0.0, 0.5)
    p = []
    for sx in (1, -1):
        for i in range(3):
            p.append(caixa("Chifre%d" % i, (0.09 - 0.025 * i, 0.09 - 0.025 * i, 0.06), (sx * (0.19 + 0.015 * i), 0.10, 0.03 + 0.06 * i), v))
    exportar(p, "acessorios", "chifres_diabinho")


def cauda_diabo():
    limpar()
    v = mat("Cauda", (0.80, 0.08, 0.10), 0.0, 0.5)
    p = []
    pts = [(0.0, -0.14, 0.04), (0.0, -0.19, -0.03), (0.0, -0.25, -0.08), (0.0, -0.32, -0.10), (0.0, -0.38, -0.07), (0.0, -0.41, -0.01), (0.0, -0.41, 0.05)]
    for i, (x, y, z) in enumerate(pts):
        p.append(caixa("Seg%d" % i, (0.04, 0.05, 0.05), (x, y, z), v))
    p.append(caixa("Seta", (0.09, 0.04, 0.04), (0, -0.41, 0.10), v)); p.append(caixa("SetaP", (0.04, 0.04, 0.07), (0, -0.41, 0.13), v))
    p.append(caixa("SetaA", (0.13, 0.04, 0.03), (0, -0.41, 0.09), v))
    exportar(p, "acessorios", "cauda_diabo")


def peruca_arco_iris():
    """Peruca longa e lisa em degradê arco-íris (cores PRÓPRIAS: vai na categoria
    de perucas, que não é tingida). Origem no topo do crânio; até z=−1,1."""
    limpar()
    cores = [(0.90, 0.15, 0.20), (0.96, 0.40, 0.14), (0.98, 0.65, 0.12), (0.98, 0.86, 0.18), (0.62, 0.85, 0.22), (0.18, 0.72, 0.35),
             (0.12, 0.70, 0.70), (0.15, 0.50, 0.92), (0.30, 0.30, 0.88), (0.55, 0.30, 0.85), (0.70, 0.28, 0.80)]
    ms = [mat("Faixa%d" % i, c, 0.0, 0.9) for i, c in enumerate(cores)]
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.10), (0, 0, -0.05), ms[0]), caixa("Franja", (L + 0.02, 0.08, 0.17), (0, P * 0.5 - 0.01, -0.085), ms[1])]
    for i, m in enumerate(ms):
        z = -0.12 - i * 0.092
        p.append(caixa("Costas%d" % i, (L + 0.02, 0.11, 0.094), (0, -(P * 0.5 - 0.04), z), m))
        for sx in (1, -1):
            p.append(caixa("Lado%d" % i, (0.085, 0.14, 0.094), (sx * (L * 0.5 + 0.0), P * 0.5 - 0.12, z), m))
            if i < 9:
                p.append(caixa("LadoT%d" % i, (0.08, 0.30, 0.094), (sx * (L * 0.5 + 0.0), -0.10, z), m))
    exportar(p, "acessorios", "peruca_arco_iris")


def cabelo_afro_puff_duplo():
    import random, math
    limpar()
    random.seed(21)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab), caixa("Franja", (L, 0.07, 0.14), (0, P * 0.5 - 0.035, -0.07), cab),
         caixa("Nuca", (L, 0.10, 0.26), (0, -(P * 0.5 - 0.05), -0.13), cab), caixa("Risca", (0.03, P, 0.02), (0, 0, 0.005), mat("Risca", (0.30, 0.30, 0.30), 0.0, 0.9))]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.22), (sx * (L * 0.5 - 0.03), -P * 0.1, -0.11), cab))
        cx, cy, cz = sx * 0.30, -0.10, 0.17
        for i in range(70):
            a, b = random.uniform(0, 2 * math.pi), random.uniform(0, math.pi)
            r = 0.20 * (0.6 + 0.4 * random.random())
            if i < 20:
                r = 0.10 * random.random()
            t = random.uniform(0.07, 0.11)
            p.append(caixa("Puff", (t, t, t), (cx + r * math.sin(b) * math.cos(a) * 0.9, cy + r * math.sin(b) * math.sin(a) * 0.9, cz + r * math.cos(b) * 0.9), cab))
        p.append(caixa("Laco", (0.12, 0.05, 0.09), (sx * 0.22, 0.14, 0.12), cab))
        p.append(caixa("LacoNo", (0.05, 0.06, 0.05), (sx * 0.22, 0.14, 0.12), cab))
    exportar(p, "cabelos", "cabelo_afro_puff_duplo")


def cabelo_cacheado_lenco():
    import random
    limpar()
    random.seed(33)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab)]
    for i in range(90):
        x = random.uniform(-L * 0.55, L * 0.55)
        y = random.uniform(-P * 0.5, P * 0.38)
        z = random.uniform(-0.55, 0.06)
        if abs(x) < L * 0.42 and y > -P * 0.30 and z < -0.06 and y < P * 0.45:   # miolo oco dentro da cabeça
            continue
        if y > P * 0.30 and z < -0.20:
            continue
        t = random.uniform(0.08, 0.13)
        p.append(caixa("Cacho", (t, t, t), (x, y, z), cab))
    p.append(caixa("Nuca", (L, 0.12, 0.40), (0, -(P * 0.5 - 0.05), -0.20), cab))
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.6, 0.38), (sx * (L * 0.5 + 0.0), -P * 0.12, -0.19), cab))
    p.append(caixa("Lenco", (L + 0.05, 0.03, 0.10), (0, P * 0.5 + 0.015, -0.01), cab))
    exportar(p, "cabelos", "cabelo_cacheado_lenco")


def cabelo_ruivo_cacheado():
    import random
    limpar()
    random.seed(45)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Nuca", (L + 0.04, 0.14, 0.50), (0, -(P * 0.5 - 0.04), -0.25), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.10, P * 0.66, 0.42), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.21), cab))
    for i in range(70):
        x = random.uniform(-L * 0.60, L * 0.60)
        y = random.uniform(-P * 0.55, P * 0.40)
        z = random.uniform(-0.58, 0.07)
        if abs(x) < L * 0.40 and y > -P * 0.30 and z < -0.07 and y < P * 0.45:
            continue
        if y > P * 0.28 and z < -0.20:
            continue
        t = random.uniform(0.08, 0.14)
        p.append(caixa("Cacho", (t, t, t), (x, y, z), cab))
    for i in range(8):
        p.append(caixa("Franja", (0.09, 0.07, random.uniform(0.10, 0.22)), (-0.24 + i * 0.07, P * 0.5 - 0.03, -0.08), cab))
    exportar(p, "cabelos", "cabelo_ruivo_cacheado")


def _tronco_aberto(c, h=0.58, z=-0.04):
    """Duas metades de frente aberta + costas (vão central de 0,075)."""
    return [((0.245, 0.375, h), (0.1525, 0, z), c), ((0.245, 0.375, h), (-0.1525, 0, z), c), ((0.55, 0.045, h), (0, -0.19, z), c)]


def _saia_aberta(c, h=0.80, z=-0.23):
    return [((0.255, 0.37, h), (0.165, 0, z), c), ((0.255, 0.37, h), (-0.165, 0, z), c), ((0.58, 0.05, h), (0, -0.18, z), c)]


def cabelo_cornrows():
    """Tranças rentes ao couro cabeludo (cornrows): fileiras de nodos da testa
    à nuca. Origem no topo do crânio."""
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L, P, 0.09), (0, 0, -0.045), cab), caixa("Nuca", (L, 0.09, 0.22), (0, -(P * 0.5 - 0.045), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.05, P * 0.6, 0.18), (sx * (L * 0.5 - 0.025), -P * 0.10, -0.09), cab))
    for i in range(9):
        x = -0.22 + i * 0.055
        for j in range(8):
            y = -P * 0.46 + j * (P * 0.9 / 7)
            p.append(caixa("Nodo", (0.05, 0.085, 0.055), (x, y, 0.03 + (0.01 if (i + j) % 2 else 0.0)), cab))
    exportar(p, "cabelos", "cabelo_cornrows")


def elfico_arqueiro():
    mats = {"c": ("Casaco", (0.18, 0.36, 0.14), 0.0, 0.85), "v": ("Vinco", (0.12, 0.26, 0.10), 0.0, 0.85), "o": ("Ouro", (0.82, 0.78, 0.40), 0.7, 0.45),
            "k": ("Couro", (0.30, 0.18, 0.09), 0.0, 0.8)}
    tronco = _tronco_aberto("c") + [((0.36, 0.34, 0.08), (0, 0, 0.275), "c"), ((0.58, 0.40, 0.05), (0, 0, -0.30), "k"), ((0.08, 0.04, 0.08), (0, 0.21, -0.30), "o"),
              ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.44, 0.30, 0.10), (0, -0.15, 0.90), "c"),
              ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
              ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "o"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "o"),
              ((0.02, 0.045, 0.40), (0.07, 0.205, 0.0), "o"), ((0.02, 0.045, 0.40), (-0.07, 0.205, 0.0), "o"),
              ((0.14, 0.40, 0.04), (0.27, 0, 0.26), "v"), ((0.14, 0.40, 0.04), (-0.27, 0, 0.26), "v")]
    sup, inf = _bracos("c")
    vestir("elfico", mats, tronco=tronco,
           saia=_saia_aberta("c", 0.42, -0.04) + [((0.59, 0.38, 0.03), (0, 0, -0.26), "o")],
           manga_sup=sup + [((0.31, 0.31, 0.05), (0, 0, -0.01), "v")], manga_inf=inf + [((0.30, 0.30, 0.04), (0, 0, -0.19), "o")])


def oficial_vermelho():
    mats = {"c": ("Casaco", (0.62, 0.08, 0.10), 0.0, 0.8), "o": ("Ouro", (0.95, 0.76, 0.18), 0.8, 0.4), "v": ("Vinco", (0.42, 0.05, 0.07), 0.0, 0.85)}
    tronco = _tronco_aberto("c") + [((0.34, 0.32, 0.12), (0, 0, 0.30), "c"), ((0.34, 0.03, 0.03), (0, 0, 0.365), "o"),
              ((0.03, 0.385, 0.58), (0.0375, 0, -0.04), "o"), ((0.03, 0.385, 0.58), (-0.0375, 0, -0.04), "o"), ((0.24, 0.045, 0.06), (0, -0.20, -0.30), "o")]
    for sx in (1, -1):
        for k in range(4):
            tronco.append(((0.04, 0.03, 0.04), (sx * 0.11, 0.205, 0.14 - k * 0.12), "o"))
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.33, 0.33, 0.04), (0, 0, 0.04), "o")] + [((0.03, 0.03, 0.12), (-0.13 + k * 0.05, 0.155, 0.02), "o") for k in range(6)]
    vestir("oficial_vermelho", mats, tronco=tronco,
           saia=_saia_aberta("c") + [((0.59, 0.38, 0.04), (0, 0, -0.62), "o"), ((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "o"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "o"),
                                    ((0.02, 0.055, 0.30), (0, -0.18, -0.50), "v")],
           manga_sup=sup, manga_inf=[(MANGA_INF[0], MANGA_INF[1], "c"), ((0.32, 0.32, 0.07), (0, 0, -0.16), "v"), ((0.325, 0.325, 0.025), (0, 0, -0.12), "o"), ((0.04, 0.04, 0.04), (0, 0.16, -0.16), "o")])


def bardo():
    mats = {"c": ("Casaco", (0.50, 0.08, 0.18), 0.0, 0.85), "r": ("Lapela", (0.42, 0.22, 0.65), 0.0, 0.85), "o": ("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4),
            "b": ("Branco", (0.96, 0.94, 0.88), 0.0, 0.9), "k": ("Couro", (0.30, 0.17, 0.09), 0.0, 0.8)}
    tronco = _tronco_aberto("c") + [((0.14, 0.04, 0.46), (0.0, 0.195, 0.0), "r"), ((0.16, 0.06, 0.20), (0, 0.21, 0.16), "b"), ((0.34, 0.32, 0.07), (0, 0, 0.275), "c"),
              ((0.03, 0.385, 0.58), (0.0375, 0, -0.04), "o"), ((0.03, 0.385, 0.58), (-0.0375, 0, -0.04), "o"),
              ((0.58, 0.40, 0.04), (0, 0, -0.30), "k"), ((0.07, 0.03, 0.07), (0, 0.22, -0.30), "o"), ((0.14, 0.14, 0.04), (0.26, 0.0, 0.265), "o"), ((0.14, 0.14, 0.04), (-0.26, 0.0, 0.265), "o")]
    for k in range(4):
        tronco.append(((0.04, 0.03, 0.04), (0.0, 0.225, 0.14 - k * 0.12), "o"))
    sup, inf = _bracos("c")
    vestir("bardo", mats, tronco=tronco, saia=_saia_aberta("c", 0.60, -0.13) + [((0.59, 0.38, 0.03), (0, 0, -0.43), "o")],
           manga_sup=sup + [((0.31, 0.31, 0.07), (0, 0, 0.0), "o")], manga_inf=inf + [((0.36, 0.36, 0.05), (0, 0, -0.17), "b"), ((0.34, 0.34, 0.04), (0, 0, -0.22), "b")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "k")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "k"), ((0.29, 0.29, 0.10), (0, 0, -0.04), "o")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k"), ((0.26, 0.06, 0.07), (0, 0.17, -0.06), "o")])
    limpar()
    vi = mat("Chapeu", (0.50, 0.08, 0.18), 0.0, 0.85); ro = mat("Roxo", (0.42, 0.22, 0.65), 0.0, 0.85); ou = mat("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4)
    br = mat("Pena", (0.97, 0.95, 0.88), 0.0, 0.9); am = mat("PenaAmarela", (0.98, 0.80, 0.25), 0.0, 0.9)
    p = [caixa("Aba", (0.80, 0.98, 0.035), (0, 0, 0.0), vi), caixa("AbaOuro", (0.82, 1.0, 0.015), (0, 0, 0.0), ou), caixa("Copa", (0.50, 0.64, 0.17), (0, 0, 0.10), vi),
         caixa("Fita", (0.52, 0.66, 0.05), (0, 0, 0.06), ro), caixa("Fivela", (0.09, 0.04, 0.08), (0, 0.33, 0.06), ou)]
    for k in range(5):
        p.append(caixa("Pena%d" % k, (0.07, 0.04, 0.10), (0.20 + k * 0.05, -0.05 - k * 0.07, 0.18 + k * 0.075), br if k % 2 == 0 else am))
    exportar(p, "acessorios", "chapeu_bardo")
    limpar()
    mad = mat("Madeira", (0.62, 0.36, 0.14), 0.0, 0.7); esc = mat("MadeiraEscura", (0.35, 0.18, 0.08), 0.0, 0.7); br2 = mat("Boca", (0.92, 0.85, 0.62), 0.0, 0.8)
    p = [caixa("Corpo", (0.26, 0.12, 0.30), (0.0, -0.28, -0.12), mad), caixa("CorpoBaixo", (0.20, 0.12, 0.10), (0.0, -0.28, -0.30), mad), caixa("Boca", (0.10, 0.02, 0.10), (0.0, -0.345, -0.12), esc),
         caixa("Braco", (0.05, 0.05, 0.40), (0.0, -0.28, 0.20), esc), caixa("Cravelha", (0.10, 0.06, 0.10), (0.0, -0.28, 0.42), esc), caixa("Tampo", (0.24, 0.02, 0.28), (0.0, -0.345, -0.12), br2)]
    for z in (0.45, 0.39):
        p.append(caixa("Pino", (0.05, 0.03, 0.03), (0.06, -0.28, z), esc)); p.append(caixa("PinoE", (0.05, 0.03, 0.03), (-0.06, -0.28, z), esc))
    p.append(caixa("Alca", (0.04, 0.40, 0.03), (0.0, -0.05, 0.255), esc))
    for sx in (1, -1):
        p.append(caixa("AlcaT", (0.05, 0.03, 0.40), (sx * 0.14, -0.19, 0.06), esc)) if False else None
    exportar(p, "acessorios", "alaude_costas")


def kamishimo():
    mats = {"c": ("Casaco", (0.10, 0.14, 0.34), 0.0, 0.8), "o": ("Ouro", (0.88, 0.70, 0.24), 0.7, 0.45), "b": ("Branco", (0.93, 0.93, 0.96), 0.0, 0.9),
            "h": ("Hakama", (0.09, 0.12, 0.30), 0.0, 0.8)}
    tronco = _tronco_aberto("c") + [((0.09, 0.04, 0.46), (0.0, 0.195, 0.0), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"),
              ((0.58, 0.39, 0.10), (0, 0, -0.24), "o"), ((0.14, 0.05, 0.14), (0.06, 0.215, -0.24), "o")]
    for sx in (1, -1):    # ombros largos (kataginu)
        tronco += [((0.30, 0.36, 0.05), (sx * 0.38, 0, 0.255), "c"), ((0.12, 0.36, 0.05), (sx * 0.56, 0, 0.22), "c"), ((0.30, 0.37, 0.015), (sx * 0.38, 0, 0.285), "o"),
                   ((0.04, 0.38, 0.58), (sx * 0.075, 0, -0.04), "o")]
        tronco.append(((0.07, 0.04, 0.07), (sx * 0.22, 0.205, 0.10), "o"))
    saia = [((0.60, 0.40, 0.20), (0, 0, 0.07), "c")]
    for i in range(7):
        saia.append(((0.095, 0.44 + (0.04 if i % 2 else 0.0), 0.66), (-0.27 + i * 0.09, 0, -0.32), "h"))
        saia.append(((0.015, 0.47, 0.66), (-0.27 + i * 0.09 + 0.048, 0, -0.32), "o"))
    saia.append(((0.72, 0.48, 0.03), (0, 0, -0.66), "o"))
    sup, inf = _bracos("c")
    vestir("kamishimo", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=inf + [((0.30, 0.30, 0.03), (0, 0, -0.19), "o")])


def sacerdote():
    mats = {"c": ("Casaco", (0.96, 0.96, 0.98), 0.0, 0.9), "o": ("Ouro", (0.92, 0.74, 0.20), 0.8, 0.4), "v": ("Vinco", (0.82, 0.82, 0.86), 0.0, 0.9)}
    tronco = [((0.56, 0.38, 0.58), (0, 0, -0.04), "c"), ((0.34, 0.32, 0.08), (0, 0, 0.275), "o"), ((0.34, 0.33, 0.04), (0, 0, 0.255), "v"),
              ((0.58, 0.40, 0.04), (0, 0, -0.30), "v"), ((0.16, 0.06, 0.62), (0.10, 0.205, -0.10), "o"), ((0.16, 0.06, 0.62), (-0.10, 0.205, -0.10), "o"),
              ((0.04, 0.065, 0.10), (0.10, 0.235, 0.0), "c"), ((0.08, 0.065, 0.035), (0.10, 0.235, 0.0), "c"), ((0.04, 0.065, 0.10), (-0.10, 0.235, 0.0), "c"), ((0.08, 0.065, 0.035), (-0.10, 0.235, 0.0), "c"),
              ((0.24, 0.02, 0.04), (0, -0.195, 0.10), "o"), ((0.04, 0.02, 0.24), (0, -0.195, 0.08), "o")]
    for sx in (1, -1):
        tronco.append(((0.03, 0.40, 0.04), (sx * 0.27, 0, 0.255), "o"))
    vestir("sacerdote", mats, tronco=tronco,
           saia=[((0.60, 0.40, 0.84), (0, 0, -0.25), "c"), ((0.61, 0.41, 0.04), (0, 0, -0.66), "o"), ((0.16, 0.06, 0.60), (0.10, 0.215, -0.30), "o"), ((0.16, 0.06, 0.60), (-0.10, 0.215, -0.30), "o")],
           manga_sup=[((0.31, 0.31, 0.34), (0, 0, -0.15), "c")], manga_inf=[((0.35, 0.35, 0.21), (0, 0, -0.105), "c"), ((0.36, 0.36, 0.03), (0, 0, -0.21), "o")])


def piloto_corrida():
    mats = {"c": ("Casaco", (0.96, 0.96, 0.98), 0.0, 0.7), "k": ("Preto", (0.07, 0.07, 0.08), 0.0, 0.6), "r": ("Gravata", (0.82, 0.10, 0.12), 0.0, 0.6),
            "a": ("Azul", (0.10, 0.20, 0.60), 0.0, 0.6), "y": ("Ouro", (0.98, 0.80, 0.15), 0.0, 0.6)}
    tronco = _base("c") + [((0.20, 0.04, 0.50), (0.17, 0.19, -0.04), "k"), ((0.20, 0.04, 0.50), (-0.17, 0.19, -0.04), "k"), ((0.34, 0.33, 0.07), (0, 0, 0.27), "k"),
              ((0.58, 0.39, 0.06), (0, 0, -0.30), "k"), ((0.07, 0.03, 0.07), (0, 0.21, -0.30), "c"), ((0.10, 0.03, 0.06), (0.17, 0.205, 0.15), "y"), ((0.10, 0.03, 0.06), (-0.17, 0.205, 0.15), "r")]
    for sx in (1, -1):
        tronco += [((0.14, 0.40, 0.04), (sx * 0.27, 0, 0.255), "r"), ((0.07, 0.04, 0.12), (sx * 0.05, 0.19, 0.20), "r")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.30, 0.30, 0.05), (0, 0, 0.0), "r"), ((0.30, 0.30, 0.04), (0, 0, -0.06), "y"), ((0.30, 0.30, 0.04), (0, 0, -0.10), "a")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.31, 0.31, 0.07), (0, 0, -0.17), "k")]
    vestir("piloto", mats, tronco=tronco, manga_sup=sup, manga_inf=inf,
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.55, 0.31, 0.04), (0, 0, 0.03), "k")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.04, 0.27, 0.36), (0.09, 0, -0.18), "r")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.04, 0.27, 0.285), (0.09, 0, -0.1425), "r"), ((0.16, 0.05, 0.14), (0, 0.145, -0.04), "c")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k")])
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.98), 0.0, 0.4); ve = mat("Vermelho", (0.82, 0.10, 0.12), 0.0, 0.4); az = mat("Azul", (0.10, 0.25, 0.80), 0.0, 0.4)
    am = mat("Amarelo", (0.98, 0.82, 0.15), 0.0, 0.4); pr = mat("Preto", (0.06, 0.06, 0.08), 0.0, 0.5)
    g = 0.045
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), ve), caixa("Tras", (larg, 0.09, 0.56), (0, -prof * 0.5 + 0.045, -0.23), br), caixa("Faixa", (0.14, prof, 0.10), (0, 0, 0.09), br),
         caixa("Brim", (larg, 0.09, 0.14), (0, prof * 0.5 - 0.045, -0.03), ve), caixa("Queixo", (larg - 0.04, 0.09, 0.12), (0, prof * 0.5 - 0.045, -0.46), pr),
         caixa("Visor", (larg + 0.02, 0.05, 0.04), (0, prof * 0.5 + 0.0, -0.10), pr)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, prof, 0.56), (sx * (larg * 0.5 - 0.045), 0, -0.23), br if sx > 0 else az))
        p.append(caixa("Faixa", (0.095, 0.4, 0.07), (sx * (larg * 0.5 - 0.045), -0.05, -0.12), am))
        p.append(caixa("Bochecha", (0.095, 0.10, 0.40), (sx * (larg * 0.5 - 0.045), prof * 0.5 - 0.05, -0.28), pr))
    exportar(p, "acessorios", "capacete_piloto")


def enfermagem_antiga():
    mats = {"c": ("Casaco", (0.94, 0.95, 0.97), 0.0, 0.9), "v": ("Vinco", (0.80, 0.82, 0.86), 0.0, 0.9)}
    tronco = [((0.545, 0.37, 0.58), (0, 0, -0.04), "c"), ((0.34, 0.33, 0.08), (0, 0, 0.275), "c"), ((0.12, 0.05, 0.10), (0.10, 0.20, 0.23), "v"), ((0.12, 0.05, 0.10), (-0.10, 0.20, 0.23), "v"),
              ((0.58, 0.39, 0.05), (0, 0, -0.30), "v"), ((0.03, 0.04, 0.40), (0, 0.195, 0.0), "v"), ((0.17, 0.06, 0.12), (0, -0.21, -0.26), "c"), ((0.06, 0.06, 0.24), (0.07, -0.21, -0.40), "c"), ((0.06, 0.06, 0.24), (-0.07, -0.21, -0.40), "c")]
    vestir("enfermeira", mats, tronco=tronco,
           saia=[((0.62, 0.42, 0.74), (0, 0, -0.20), "c"), ((0.40, 0.04, 0.55), (0, 0.22, -0.18), "v"), ((0.42, 0.05, 0.05), (0, 0.22, 0.10), "v"), ((0.64, 0.44, 0.03), (0, 0, -0.56), "v")],
           manga_sup=[((0.33, 0.33, 0.24), (0, 0, -0.08), "c"), ((0.31, 0.31, 0.04), (0, 0, -0.21), "v")], manga_inf=[((0.28, 0.28, 0.12), (0, 0, -0.06), "c")])
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9); vm = mat("Cruz", (0.15, 0.40, 0.85), 0.0, 0.6)
    exportar([caixa("Base", (0.54, 0.76, 0.12), (0, 0, 0.06), br), caixa("Topo", (0.50, 0.66, 0.08), (0, 0, 0.16), br), caixa("Aba", (0.50, 0.08, 0.16), (0, 0.38, 0.10), br),
              caixa("Faixa", (0.56, 0.78, 0.03), (0, 0, 0.02), vm)], "acessorios", "touca_enfermagem")


def lenhador():
    mats = {"c": ("Casaco", (0.78, 0.10, 0.12), 0.0, 0.9), "k": ("Preto", (0.10, 0.08, 0.08), 0.0, 0.9), "s": ("Couro", (0.40, 0.22, 0.10), 0.0, 0.7), "o": ("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "c"), ((0.04, 0.04, 0.46), (0, 0.195, 0.0), "k")]
    for i in range(5):
        for j in range(4):
            if (i + j) % 2 == 0:
                tronco.append(((0.10, 0.375, 0.11), (-0.20 + i * 0.10, 0, 0.17 - j * 0.12), "k"))
    for sx in (1, -1):
        tronco += [((0.06, 0.04, 0.58), (sx * 0.12, 0.2, -0.04), "s"), ((0.06, 0.04, 0.58), (sx * 0.12, -0.2, -0.04), "s"), ((0.07, 0.04, 0.05), (sx * 0.12, 0.205, -0.28), "o"),
                   ((0.06, 0.40, 0.03), (sx * 0.12, 0, 0.255), "s")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + [((0.30, 0.30, 0.09), (0, 0, -0.06 - 0.17 * k), "k") for k in range(2)]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.09), (0, 0, -0.09), "k"), ((0.31, 0.31, 0.04), (0, 0, -0.195), "c")]
    vestir("lenhador", mats, tronco=tronco, manga_sup=sup, manga_inf=inf)


def junina():
    mats = {"c": ("Casaco", (0.82, 0.12, 0.14), 0.0, 0.9), "a": ("Azul", (0.15, 0.30, 0.72), 0.0, 0.9), "y": ("Ouro", (0.98, 0.82, 0.18), 0.0, 0.8), "b": ("Branco", (0.97, 0.97, 0.97), 0.0, 0.9)}
    tronco = [((0.52, 0.355, 0.50), (0, 0, -0.07), "a"), ((0.40, 0.04, 0.40), (0, 0.19, -0.02), "c"), ((0.07, 0.03, 0.40), (0.0, 0.215, -0.02), "y"), ((0.18, 0.06, 0.10), (0, 0.22, -0.20), "c"),
              ((0.06, 0.06, 0.16), (0.06, 0.22, -0.32), "c"), ((0.06, 0.06, 0.16), (-0.06, 0.22, -0.32), "c"), ((0.20, 0.06, 0.12), (0, -0.20, -0.18), "c"),
              ((0.575, 0.385, 0.04), (0, 0, -0.30), "y")]
    saia = []
    for i, (w, d, z, k) in enumerate([(0.60, 0.40, 0.07, "a"), (0.80, 0.54, -0.08, "c"), (0.98, 0.68, -0.22, "y"), (1.12, 0.80, -0.34, "a")]):
        saia.append(((w, d, 0.14), (0, 0, z), k))
        saia.append(((w * 0.5, d * 0.5, 0.15), (0, 0, z), "b"))
    sup = [((0.31, 0.31, 0.16), (0, 0, -0.07), "c"), ((0.32, 0.32, 0.04), (0, 0, -0.165), "y"), ((0.10, 0.10, 0.08), (0.12, 0, -0.07), "b")]
    vestir("junina", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=[((0.28, 0.28, 0.08), (0, 0, -0.04), "c")])
    limpar()
    pal = mat("Palha", (0.94, 0.78, 0.38), 0.0, 0.95); ve = mat("Fita", (0.82, 0.10, 0.14), 0.0, 0.8); gi = mat("Girassol", (0.98, 0.78, 0.10), 0.0, 0.8); ce = mat("Miolo", (0.40, 0.25, 0.10), 0.0, 0.9)
    p = [caixa("Aba", (0.90, 1.04, 0.035), (0, 0, 0.0), pal), caixa("Aba2", (0.74, 0.88, 0.03), (0, 0, 0.03), pal), caixa("Copa", (0.52, 0.66, 0.16), (0, 0, 0.10), pal),
         caixa("CopaTopo", (0.46, 0.60, 0.03), (0, 0, 0.19), pal), caixa("Fita", (0.54, 0.68, 0.045), (0, 0, 0.06), ve),
         caixa("Laco", (0.18, 0.04, 0.09), (0, -0.35, 0.065), ve), caixa("Ponta1", (0.04, 0.04, 0.16), (-0.05, -0.37, 0.0), ve), caixa("Ponta2", (0.04, 0.04, 0.16), (0.05, -0.37, 0.0), ve),
         caixa("Flor", (0.13, 0.03, 0.13), (0.22, 0.35, 0.09), gi), caixa("Flor2", (0.09, 0.035, 0.09), (0.22, 0.355, 0.09), ce)]
    exportar(p, "acessorios", "chapeu_junino")


def gato_preto():
    mats = {"c": ("Casaco", (0.07, 0.07, 0.09), 0.0, 0.95), "v": ("Vinco", (0.05, 0.05, 0.07), 0.0, 0.95), "r": ("Rosa", (0.92, 0.55, 0.62), 0.0, 0.9), "b": ("Branco", (0.97, 0.97, 0.97), 0.0, 0.6)}
    tronco = _base("c") + [((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
              ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "c")]
    for sx in (1, -1):
        for i, w in enumerate((0.13, 0.10, 0.07)):
            tronco.append(((w, 0.07, 0.05), (sx * 0.19, -0.05, 0.875 + 0.05 * i), "c"))
        tronco.append(((0.05, 0.015, 0.07), (sx * 0.19, -0.015, 0.92), "r"))
    cintura = [((0.53, 0.30, 0.15), (0, 0, 0.09), "c")]
    pts = [(-0.14, 0.04), (-0.20, -0.04), (-0.27, -0.10), (-0.34, -0.12), (-0.40, -0.09), (-0.43, -0.03), (-0.42, 0.04)]
    for y, z in pts:
        cintura.append(((0.05, 0.05, 0.05), (0, y, z), "v"))
    sup, inf = _bracos("c")
    vestir("gato_preto", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=cintura,
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")],
           pe=[((0.27, 0.32, 0.09), (0, 0, -0.05), "v"), ((0.05, 0.05, 0.05), (0.07, 0.17, -0.06), "r"), ((0.05, 0.05, 0.05), (-0.07, 0.17, -0.06), "r")])


def asas_anjo_grandes():
    import math
    limpar()
    ouro = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    br = [mat("Pena%d" % i, c, 0.0, 0.9) for i, c in enumerate([(0.99, 0.99, 1.0), (0.94, 0.95, 0.98), (0.88, 0.90, 0.96)])]
    p = []
    for i in range(16):
        t = i / 16 * 2 * math.pi
        p.append(caixa_rot("Halo", (0.10, 0.04, 0.04), (0.23 * math.cos(t), 0.23 * math.sin(t), 0.95), ouro, math.degrees(t) + 90))
    for sx in (1, -1):
        p.append(caixa("Fecho", (0.08, 0.06, 0.12), (sx * 0.08, -0.21, 0.10), ouro))
        for i in range(8):
            x = sx * (0.14 + i * 0.075)
            top = 0.28 - i * 0.012 if i < 4 else 0.20 - (i - 4) * 0.05
            for linha in range(6):
                h = 0.09
                comp = 0.12 + 0.07 * min(i, 5)
                if linha * h > comp + 0.1:
                    break
                p.append(caixa("Pena", (0.07, 0.04, h), (x, -0.22 - linha * 0.008, top - 0.045 - linha * h * 0.9), br[min(linha // 2, 2)]))
    exportar(p, "acessorios", "asas_anjo_grandes")


def orelhas_elfo():
    """Orelhas de elfo longas e pontudas (tom de pele neutro) com argolas
    douradas. Origem no topo da cabeça; orelha em z=−0,22."""
    limpar()
    pele = mat("Pele", (0.72, 0.56, 0.46), 0.0, 0.85)
    ouro = mat("Ouro", (0.95, 0.76, 0.16), 0.9, 0.3)
    p = []
    for sx in (1, -1):
        for i in range(6):
            w = 0.10 - 0.013 * i
            p.append(caixa("Orelha%d" % i, (0.07 + 0.03 * (i < 2), 0.10 - 0.012 * i + 0.0, w), (sx * (0.27 + 0.05 * i), -0.05, -0.22 + 0.028 * i), pele))
        p.append(caixa("Argola", (0.02, 0.04, 0.04), (sx * 0.30, -0.05, -0.30), ouro))
        p.append(caixa("Pingente", (0.02, 0.025, 0.05), (sx * 0.30, -0.05, -0.345), ouro))
    exportar(p, "acessorios", "orelhas_elfo")


def capuz_panda():
    """Capuz branco de panda com orelhas pretas, manchas dos olhos e cordões com
    pompons. Origem no topo da cabeça."""
    limpar()
    br = mat("Pelo", (0.97, 0.97, 0.98), 0.0, 1.0)
    pr = mat("Preto", (0.06, 0.06, 0.07), 0.0, 1.0)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.07), (0, 0, 0.03), br), caixa("Tras", (larg, 0.07, 0.56), (0, -prof * 0.5 + 0.035, -0.25), br),
         caixa("Brim", (larg, 0.07, 0.11), (0, prof * 0.5 - 0.035, -0.02), br), caixa("Gola", (larg + 0.02, prof + 0.02, 0.12), (0, 0, -0.58), br),
         caixa("Queixo", (larg - 0.04, 0.06, 0.10), (0, prof * 0.5 - 0.03, -0.56), br)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.07, prof, 0.56), (sx * (larg * 0.5 - 0.035), 0, -0.25), br))
        p.append(caixa("Bochecha", (0.09, 0.07, 0.40), (sx * (CAB_L * 0.5), prof * 0.5 - 0.035, -0.31), br))
        p.append(caixa("Orelha", (0.15, 0.10, 0.15), (sx * 0.20, -0.08, 0.14), pr))
        p.append(caixa("OrelhaBranca", (0.08, 0.03, 0.08), (sx * 0.20, -0.025, 0.14), br))
        p.append(caixa("Mancha", (0.13, 0.025, 0.09), (sx * 0.12, prof * 0.5 + 0.0, -0.025), pr))
        p.append(caixa("Cordao", (0.02, 0.02, 0.30), (sx * 0.12, prof * 0.5 + 0.0, -0.72), pr))
        p.append(caixa("Pompom", (0.05, 0.05, 0.05), (sx * 0.12, prof * 0.5 + 0.0, -0.89), br))
    exportar(p, "acessorios", "capuz_panda")


# ======================================================================= lote 9
def mergulhador():
    mats = {"c": ("Casaco", (0.08, 0.13, 0.32), 0.0, 0.5), "t": ("Turquesa", (0.10, 0.70, 0.68), 0.0, 0.5), "k": ("Preto", (0.05, 0.05, 0.07), 0.0, 0.6)}
    tronco = _base("c") + [((0.575, 0.385, 0.05), (0, 0, 0.15), "t"), ((0.09, 0.04, 0.50), (0.17, 0.19, -0.04), "t"), ((0.09, 0.04, 0.50), (-0.17, 0.19, -0.04), "t"), ((0.02, 0.04, 0.50), (0, 0.19, -0.04), "k"),
                           ((0.34, 0.33, 0.07), (0, 0, 0.27), "c"), ((0.58, 0.39, 0.05), (0, 0, -0.29), "t")]
    sup, inf = _bracos("c")
    vestir("mergulhador", mats, tronco=tronco, manga_sup=sup + [((0.30, 0.30, 0.12), (0, 0, -0.06), "t")], manga_inf=inf + [((0.29, 0.29, 0.04), (0, 0, -0.19), "t")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.27, 0.36), (0.09, 0, -0.18), "t")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.10, 0.27, 0.285), (0.09, 0, -0.1425), "t"), ((0.275, 0.275, 0.04), (0, 0, -0.26), "k")],
           pe=[((0.27, 0.32, 0.09), (0, 0, -0.05), "c"), ((0.30, 0.30, 0.03), (0, 0.25, -0.09), "t"), ((0.26, 0.20, 0.03), (0, 0.45, -0.09), "t"), ((0.05, 0.40, 0.04), (0, 0.38, -0.07), "k")])
    limpar()
    tq = mat("Turquesa", (0.10, 0.70, 0.68), 0.0, 0.5); vi = mat("Vidro", (0.72, 0.90, 0.95), 0.1, 0.05); pr = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.6); az = mat("Azul", (0.08, 0.13, 0.32), 0.0, 0.5)
    p = [caixa("Aro", (0.52, 0.06, 0.22), (0, 0.03, 0.06), tq), caixa("Vidro", (0.44, 0.07, 0.15), (0, 0.04, 0.06), vi), caixa("Nariz", (0.10, 0.08, 0.06), (0, 0.04, -0.07), pr),
         caixa("TiraT", (0.54, 0.03, 0.06), (0, -0.755, 0.06), pr), caixa("Bocal", (0.10, 0.06, 0.06), (0, 0.06, -0.14), tq)]
    for sx in (1, -1):
        p.append(caixa("TiraL", (0.03, 0.78, 0.06), (sx * 0.265, -0.37, 0.06), pr))
    p += [caixa("Tubo", (0.04, 0.04, 0.60), (0.28, 0.03, 0.30), az), caixa("TuboTopo", (0.06, 0.06, 0.06), (0.28, 0.03, 0.62), tq), caixa("Clipe", (0.06, 0.06, 0.06), (0.275, 0.0, 0.07), tq)]
    exportar(p, "acessorios", "mascara_snorkel")


def capacete_esferico():
    limpar()
    vi = mat("Vidro", (0.78, 0.90, 0.96), 0.1, 0.05)
    try:
        vi.surface_render_method = "BLENDED"
    except Exception:
        pass
    b = next(n for n in vi.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Alpha"].default_value = 0.35
    pr = mat("Aco", (0.78, 0.80, 0.84), 0.9, 0.3); ouro = mat("Ouro", (0.98, 0.82, 0.30), 0.0, 0.5)
    r = 0.50
    p = [caixa("Anel", (0.76, 0.96, 0.08), (0, 0, -0.50), pr)]
    n = 10
    for i in range(1, n):
        a = i / n * 3.14159
        import math
        w = 0.88 * math.sin(a); z = 0.10 + 0.55 * math.cos(a) - 0.38
        p.append(caixa("Casca%d" % i, (max(w * 0.9, 0.12), max(w * 1.05, 0.12), 0.07), (0, 0, z), vi))
    p.append(caixa("Luz", (0.06, 0.04, 0.06), (0.43, 0.2, -0.50), ouro)); p.append(caixa("Luz2", (0.06, 0.04, 0.06), (-0.43, 0.2, -0.50), ouro))
    exportar(p, "acessorios", "capacete_esferico")


def safari():
    mats = {"c": ("Casaco", (0.62, 0.50, 0.30), 0.0, 0.9), "v": ("Vinco", (0.48, 0.38, 0.22), 0.0, 0.9), "b": ("Branco", (0.88, 0.82, 0.68), 0.0, 0.9),
            "k": ("Preto", (0.08, 0.08, 0.09), 0.0, 0.5)}
    tronco = _tronco_aberto("c", 0.52, -0.06) + [((0.08, 0.04, 0.50), (0.0, 0.19, 0.0), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"), ((0.12, 0.05, 0.10), (0.15, 0.2, -0.04), "v"), ((0.12, 0.05, 0.10), (-0.15, 0.2, -0.04), "v"),
              ((0.12, 0.05, 0.10), (0.15, 0.2, -0.20), "v"), ((0.12, 0.05, 0.10), (-0.15, 0.2, -0.20), "v"), ((0.50, 0.12, 0.30), (0, -0.21, 0.0), "v"),
              ((0.09, 0.07, 0.16), (-0.07, 0.22, 0.05), "k"), ((0.09, 0.07, 0.16), (0.07, 0.22, 0.05), "k"), ((0.22, 0.05, 0.03), (0, 0.21, 0.15), "k")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "b")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "b"), ((0.31, 0.31, 0.05), (0, 0, -0.19), "v")]
    vestir("safari", mats, tronco=tronco, manga_sup=sup, manga_inf=inf)
    limpar()
    pa = mat("Palha", (0.82, 0.68, 0.45), 0.0, 0.95); fi = mat("Fita", (0.45, 0.30, 0.15), 0.0, 0.85)
    exportar([caixa("Aba", (0.80, 0.98, 0.035), (0, 0, 0.0), pa), caixa("Aba2", (0.68, 0.86, 0.03), (0, 0, 0.03), pa), caixa("Copa", (0.52, 0.66, 0.16), (0, 0, 0.11), pa),
              caixa("CopaTopo", (0.40, 0.54, 0.04), (0, 0, 0.20), pa), caixa("Fita", (0.54, 0.68, 0.05), (0, 0, 0.065), fi)], "acessorios", "chapeu_safari")


def bombeiro():
    mats = {"c": ("Casaco", (0.96, 0.72, 0.08), 0.0, 0.8), "r": ("Espinho", (0.82, 0.96, 0.25), 0.0, 0.4), "v": ("Vinco", (0.78, 0.56, 0.05), 0.0, 0.8), "k": ("Preto", (0.08, 0.08, 0.09), 0.0, 0.7)}
    tronco = _base("c") + [((0.34, 0.33, 0.10), (0, 0, 0.28), "c"), ((0.575, 0.385, 0.05), (0, 0, 0.14), "r"), ((0.575, 0.385, 0.05), (0, 0, -0.26), "r"), ((0.03, 0.04, 0.50), (0.0, 0.195, -0.04), "k"),
                           ((0.13, 0.05, 0.12), (0.15, 0.2, -0.10), "v"), ((0.13, 0.05, 0.12), (-0.15, 0.2, -0.10), "v")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.30, 0.30, 0.04), (0, 0, -0.10), "r")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.04), (0, 0, -0.10), "r"), ((0.31, 0.31, 0.04), (0, 0, -0.19), "v")]
    vestir("bombeiro", mats, tronco=tronco, saia=[((0.60, 0.40, 0.26), (0, 0, 0.04), "c"), ((0.61, 0.41, 0.04), (0, 0, -0.04), "r"), ((0.61, 0.41, 0.04), (0, 0, -0.12), "v")], manga_sup=sup, manga_inf=inf)
    limpar()
    am = mat("Amarelo", (0.98, 0.78, 0.10), 0.0, 0.5); pr = mat("Preto", (0.08, 0.08, 0.09), 0.0, 0.6); lu = mat("Luz", (1.0, 0.95, 0.75), 0.0, 0.3)
    exportar([caixa("Casco", (0.60, 0.84, 0.16), (0, 0, 0.08), am), caixa("Topo", (0.46, 0.66, 0.06), (0, 0, 0.19), am), caixa("Crista", (0.06, 0.80, 0.05), (0, 0, 0.23), am),
              caixa("Aba", (0.62, 0.90, 0.03), (0, 0.03, 0.0), am), caixa("Nuca", (0.64, 0.12, 0.14), (0, -0.46, -0.04), am), caixa("Lanterna", (0.14, 0.06, 0.10), (0, 0.46, 0.12), pr),
              caixa("Luz", (0.10, 0.03, 0.07), (0, 0.50, 0.12), lu)], "acessorios", "capacete_bombeiro")


def abelha():
    mats = {"c": ("Casaco", (0.98, 0.80, 0.10), 0.0, 0.9), "k": ("Preto", (0.07, 0.07, 0.08), 0.0, 0.9), "a": ("Espinho", (0.98, 0.84, 0.18), 0.0, 0.8), "b": ("Branco", (0.92, 0.95, 0.98), 0.0, 0.3)}
    tronco = _base("c") + [((0.575, 0.385, 0.08), (0, 0, 0.18 - k * 0.20), "k") for k in range(3)]
    tronco += [((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
               ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "c"),
               ((0.64, 0.10, 0.08), (0, -0.30, 0.70), "k"), ((0.64, 0.60, 0.05), (0, -0.01, 0.80), "k")]
    for sx in (1, -1):
        tronco += [((0.03, 0.03, 0.12), (sx * 0.15, -0.0, 0.90), "k"), ((0.04, 0.04, 0.04), (sx * 0.15 + sx * 0.03, 0.0, 0.97), "a"), ((0.14, 0.04, 0.22), (sx * 0.36, -0.20, 0.10), "b"), ((0.11, 0.04, 0.16), (sx * 0.38, -0.21, -0.10), "b")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.30, 0.30, 0.07), (0, 0, -0.10), "k"), ((0.30, 0.30, 0.07), (0, 0, -0.26), "k")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.29, 0.29, 0.06), (0, 0, -0.05), "k"), ((0.29, 0.29, 0.06), (0, 0, -0.17), "k")]
    vestir("abelha", mats, tronco=tronco, manga_sup=sup, manga_inf=inf)


def cientista():
    mats = {"c": ("Casaco", (0.94, 0.95, 0.96), 0.0, 0.9), "v": ("Vinco", (0.80, 0.82, 0.86), 0.0, 0.9), "k": ("Preto", (0.10, 0.10, 0.12), 0.0, 0.7), "r": ("Gravata", (0.75, 0.10, 0.12), 0.0, 0.7)}
    tronco = _tronco_aberto("c") + [((0.14, 0.04, 0.46), (0, 0.195, 0.0), "k"), ((0.16, 0.05, 0.05), (0, 0.22, 0.19), "r"), ((0.34, 0.33, 0.08), (0, 0, 0.275), "c"),
              ((0.10, 0.05, 0.10), (0.16, 0.2, -0.02), "v"), ((0.025, 0.06, 0.10), (0.14, 0.21, 0.07), "r"), ((0.025, 0.06, 0.10), (0.18, 0.21, 0.07), "r")]
    sup, inf = _bracos("c")
    vestir("cientista", mats, tronco=tronco, saia=_saia_aberta("c", 0.76, -0.21), manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.04), (0, 0, -0.19), "v")])


def cabelo_cientista():
    import random
    limpar()
    random.seed(88)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab), caixa("Nuca", (L, 0.12, 0.30), (0, -(P * 0.5 - 0.06), -0.15), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.62, 0.30), (sx * (L * 0.5 - 0.02), -P * 0.10, -0.15), cab))
    for i in range(46):
        x = random.uniform(-L * 0.62, L * 0.62); y = random.uniform(-P * 0.5, P * 0.46); z = random.uniform(-0.28, 0.22)
        if abs(x) < L * 0.38 and y > P * 0.2 and z < -0.12:
            continue
        t = random.uniform(0.08, 0.15)
        p.append(caixa("Tufo", (t, t, t), (x, y, z), cab))
    exportar(p, "cabelos", "cabelo_cientista")
    limpar()
    az = mat("Lente", (0.55, 0.78, 0.90), 0.2, 0.1); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6); la = mat("Aro", (0.75, 0.77, 0.80), 0.9, 0.3)
    yf = P * 0.5 + 0.03
    p = []
    for sx in (1, -1):
        p.append(caixa("Aro", (0.20, 0.07, 0.17), (sx * 0.115, yf, -0.07), la)); p.append(caixa("Lente", (0.15, 0.075, 0.11), (sx * 0.115, yf + 0.004, -0.07), az))
        p.append(caixa("TiraL", (0.035, P + 0.02, 0.07), (sx * 0.267, 0, -0.07), pr))
    p += [caixa("Ponte", (0.05, 0.05, 0.04), (0, yf, -0.07), la), caixa("TiraF", (0.53, 0.04, 0.07), (0, P * 0.5 + 0.005, -0.07), pr), caixa("TiraT", (0.53, 0.035, 0.07), (0, -P * 0.5 - 0.005, -0.07), pr)]
    exportar(p, "acessorios", "oculos_protecao_testa")


def fantasma_pirata():
    import random
    random.seed(15)
    mats = {"c": ("Casaco", (0.42, 0.78, 0.90), 0.0, 0.3), "v": ("Vinco", (0.30, 0.60, 0.74), 0.0, 0.3), "b": ("Lapela", (0.62, 0.90, 0.97), 0.0, 0.2)}
    tronco = _tronco_aberto("c") + [((0.34, 0.33, 0.08), (0, 0, 0.275), "b"), ((0.14, 0.05, 0.40), (0, 0.205, 0.04), "b"), ((0.58, 0.40, 0.05), (0, 0, -0.30), "v"), ((0.08, 0.04, 0.08), (0, 0.22, -0.30), "b")]
    saia = [((0.60, 0.40, 0.22), (0, 0, 0.06), "c")]
    for i in range(7):
        saia.append(((0.085, 0.42, random.uniform(0.18, 0.46)), (-0.255 + i * 0.085, 0, -0.14 - random.uniform(0.0, 0.1)), "c" if i % 2 else "v"))
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + [((0.05, 0.30, random.uniform(0.06, 0.14)), (-0.12 + k * 0.06, 0, 0.0), "b") for k in range(5)]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c")] + [((0.06, 0.29, random.uniform(0.06, 0.16)), (-0.12 + k * 0.06, 0, -0.21 - 0.03), "v") for k in range(5)]
    vestir("fantasma", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=inf)
    limpar()
    az = mat("Fantasma", (0.45, 0.80, 0.92), 0.0, 0.3); br = mat("Osso", (0.80, 0.95, 0.98), 0.0, 0.3); pr = mat("Vazio", (0.05, 0.10, 0.14), 0.0, 0.5)
    p = [caixa("Copa", (0.50, 0.66, 0.15), (0, 0, 0.085), az), caixa("Aba", (0.74, 0.96, 0.04), (0, 0, 0.0), az), caixa("Faixa", (0.52, 0.68, 0.05), (0, 0, 0.04), br)]
    for sx in (1, -1):
        p.append(caixa("AbaLado", (0.05, 0.86, 0.11), (sx * 0.385, 0, 0.065), az))
    p += [caixa("AbaFrente", (0.60, 0.05, 0.13), (0, 0.48, 0.075), az), caixa("Caveira", (0.12, 0.03, 0.10), (0, 0.51, 0.08), br), caixa("OlhoE", (0.03, 0.035, 0.03), (-0.03, 0.52, 0.09), pr), caixa("OlhoD", (0.03, 0.035, 0.03), (0.03, 0.52, 0.09), pr)]
    for k in range(5):
        p.append(caixa("Pena%d" % k, (0.06, 0.04, 0.09), (0.28 + k * 0.04, 0.10 - k * 0.04, 0.12 + k * 0.08), br))
    exportar(p, "acessorios", "chapeu_fantasma")


def armadura_cristal():
    mats = {"c": ("Casaco", (0.60, 0.80, 0.96), 0.0, 0.2), "b": ("Lapela", (0.85, 0.95, 1.0), 0.0, 0.1), "g": ("Cruz", (0.15, 0.40, 0.85), 0.0, 0.2)}
    tronco = [((0.46, 0.05, 0.28), (0, 0.19, 0.10), "c"), ((0.34, 0.05, 0.22), (0, 0.19, -0.14), "c"), ((0.20, 0.05, 0.08), (0, 0.19, -0.28), "c"), ((0.46, 0.055, 0.04), (0, 0.19, 0.24), "b"),
              ((0.07, 0.07, 0.10), (0, 0.225, 0.12), "g"), ((0.46, 0.05, 0.56), (0, -0.19, -0.02), "c"), ((0.07, 0.07, 0.10), (0, -0.225, 0.12), "g")]
    for sx in (1, -1):
        tronco += [((0.06, 0.40, 0.04), (sx * 0.15, 0, 0.265), "c"), ((0.04, 0.30, 0.32), (sx * 0.27, 0, -0.04), "c")]
    ombro = [((0.34, 0.34, 0.07), (0, 0, 0.03), "c"), ((0.12, 0.10, 0.22), (0.0, 0.0, 0.17), "b"), ((0.10, 0.12, 0.18), (0.10, 0.04, 0.12), "b"), ((0.10, 0.12, 0.18), (-0.10, -0.04, 0.12), "b"),
             ((0.34, 0.34, 0.06), (0, 0, -0.05), "b"), ((0.30, 0.30, 0.06), (0, 0, -0.11), "c")]
    vestir("gelo", mats, tronco=tronco, manga_sup=ombro)


def yukata_fogos():
    mats = {"c": ("Casaco", (0.16, 0.14, 0.45), 0.0, 0.85), "o": ("Ouro", (0.98, 0.78, 0.18), 0.0, 0.7), "r": ("Gravata", (0.85, 0.12, 0.20), 0.0, 0.7),
            "z": ("Rosa", (0.98, 0.60, 0.78), 0.0, 0.7), "g": ("Espinho", (0.45, 0.85, 0.35), 0.0, 0.7), "b": ("Branco", (0.96, 0.96, 0.98), 0.0, 0.9)}
    tronco = _tronco_aberto("c") + [((0.09, 0.04, 0.46), (0.0, 0.195, 0.02), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"),
              ((0.58, 0.40, 0.13), (0, 0, -0.24), "o"), ((0.04, 0.05, 0.10), (0.0, 0.215, -0.24), "r"),
              ((0.38, 0.09, 0.28), (0, -0.23, -0.20), "o"), ((0.10, 0.10, 0.10), (0, -0.23, -0.20), "r"), ((0.10, 0.06, 0.26), (-0.14, -0.22, -0.44), "o"), ((0.10, 0.06, 0.26), (0.14, -0.22, -0.44), "o")]
    for x, z, k in ((-0.15, 0.10, "z"), (0.17, 0.0, "r"), (-0.12, -0.05, "o"), (0.15, 0.17, "g")):
        tronco.append(((0.08, 0.02, 0.08), (x, 0.2, z), k))
    saia = _saia_aberta("c", 0.76, -0.2) + [((0.62, 0.42, 0.04), (0, 0, -0.60), "z")]
    for x, z, k in ((-0.18, -0.15, "o"), (0.15, -0.25, "z"), (-0.12, -0.40, "r"), (0.18, -0.50, "g"), (0.0, -0.32, "o")):
        saia.append(((0.08, 0.02, 0.08), (x, 0.205, z), k))
    sup = [((0.31, 0.31, 0.34), (0, 0, -0.15), "c"), ((0.08, 0.08, 0.08), (0.15, 0.0, -0.10), "z")]
    vestir("yukata", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=[((0.40, 0.30, 0.21), (0, 0, -0.105), "c"), ((0.41, 0.31, 0.03), (0, 0, -0.21), "z")])
    limpar()
    ou = mat("Papel", (1.0, 0.88, 0.62), 0.0, 0.3)
    b = next(n for n in ou.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Emission Color"].default_value = (1.0, 0.65, 0.25, 1.0); b.inputs["Emission Strength"].default_value = 1.8
    mad = mat("Madeira", (0.45, 0.22, 0.10), 0.0, 0.7); rd = mat("Gravata", (0.85, 0.12, 0.20), 0.0, 0.7)
    exportar([caixa("Alca", (0.09, 0.02, 0.02), (0, 0, -0.145), mad), caixa("AlcaE", (0.02, 0.02, 0.05), (-0.04, 0, -0.17), mad), caixa("AlcaD", (0.02, 0.02, 0.05), (0.04, 0, -0.17), mad),
              caixa("Tampa", (0.12, 0.12, 0.03), (0, 0, -0.215), mad), caixa("Corpo", (0.14, 0.14, 0.17), (0, 0, -0.32), ou), caixa("Meio", (0.15, 0.15, 0.03), (0, 0, -0.32), rd),
              caixa("Base", (0.12, 0.12, 0.03), (0, 0, -0.425), mad), caixa("Franja", (0.025, 0.025, 0.10), (0, 0, -0.50), rd)], "acessorios", "lanterna_papel")


def viking_peles():
    mats = {"c": ("Casaco", (0.78, 0.66, 0.46), 0.0, 0.9), "a": ("Hakama", (0.12, 0.18, 0.34), 0.0, 0.85), "p": ("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0),
            "k": ("Couro", (0.40, 0.24, 0.12), 0.0, 0.75), "o": ("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)}
    tronco = _base("c") + [((0.62, 0.44, 0.10), (0, 0, 0.28), "p"), ((0.68, 0.48, 0.06), (0, 0, 0.33), "p"), ((0.20, 0.12, 0.28), (0.20, 0.23, 0.12), "p"), ((0.20, 0.12, 0.28), (-0.20, 0.23, 0.12), "p"),
                           ((0.58, 0.39, 0.06), (0, 0, -0.28), "k"), ((0.07, 0.04, 0.07), (0, 0.21, -0.28), "o"), ((0.07, 0.04, 0.07), (0.0, 0.2, 0.08), "o")]
    sup, inf = _bracos("c")
    vestir("viking_peles", mats, tronco=tronco,
           saia=[((0.60, 0.40, 0.20), (0, 0, 0.08), "k"), ((0.64, 0.46, 0.60), (0, -0.04, -0.15), "a"), ((0.66, 0.47, 0.04), (0, -0.04, -0.46), "p"), ((0.62, 0.40, 0.03), (0, -0.04, -0.03), "o")],
           manga_sup=sup + [((0.33, 0.33, 0.09), (0, 0, 0.0), "p")], manga_inf=inf + [((0.31, 0.31, 0.06), (0, 0, -0.18), "p")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "k")] + [((0.31, 0.31, 0.08), (0, 0, -0.04), "p")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k"), ((0.30, 0.34, 0.04), (0, 0, 0.0), "p")])
    limpar()
    cz = mat("Pelo", (0.62, 0.64, 0.68), 0.0, 1.0); es = mat("PeloEscuro", (0.32, 0.33, 0.37), 0.0, 1.0); br = mat("Branco", (0.95, 0.95, 0.96), 0.0, 1.0); pr = mat("Preto", (0.05, 0.05, 0.06), 0.0, 0.7)
    g = 0.05
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.08), (0, 0, 0.04), cz), caixa("Tras", (larg, 0.08, 0.55), (0, -prof * 0.5 + 0.04, -0.23), cz), caixa("Focinho", (0.22, 0.30, 0.14), (0, prof * 0.5 + 0.12, -0.04), cz),
         caixa("Nariz", (0.07, 0.05, 0.06), (0, prof * 0.5 + 0.28, -0.02), pr), caixa("Dente1", (0.03, 0.03, 0.05), (-0.06, prof * 0.5 + 0.2, -0.13), br), caixa("Dente2", (0.03, 0.03, 0.05), (0.06, prof * 0.5 + 0.2, -0.13), br),
         caixa("Brim", (larg, 0.08, 0.10), (0, prof * 0.5 - 0.04, -0.02), cz)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, prof, 0.55), (sx * (larg * 0.5 - 0.04), 0, -0.23), cz))
        for i, w in enumerate((0.13, 0.10, 0.07)):
            p.append(caixa("Orelha%d" % i, (w, 0.07, 0.05), (sx * 0.17, -0.08, 0.10 + i * 0.05), es))
        p.append(caixa("Olho", (0.03, 0.03, 0.03), (sx * 0.12, prof * 0.5 + 0.0, 0.0), pr))
    exportar(p, "acessorios", "capuz_lobo")


def abobora():
    import math
    limpar()
    lar = mat("Abobora", (0.96, 0.52, 0.08), 0.0, 0.5); esc = mat("AboboraSombra", (0.78, 0.38, 0.05), 0.0, 0.5); ver = mat("Folha", (0.30, 0.62, 0.22), 0.0, 0.8); pr = mat("Preto", (0.18, 0.08, 0.02), 0.0, 0.9)
    lum = mat("Luz", (1.0, 0.85, 0.35), 0.0, 0.3)
    p = [caixa("Corpo", (0.70, 0.56, 0.58), (0, 0.05, -0.03), lar), caixa("Cima", (0.58, 0.46, 0.08), (0, 0.05, 0.28), lar), caixa("Baixo", (0.58, 0.46, 0.08), (0, 0.05, -0.34), lar)]
    for sx in (-0.2, 0.0, 0.2):
        p.append(caixa("Gomo", (0.03, 0.58, 0.60), (sx, 0.05, -0.03), esc))
    p += [caixa("Olho", (0.10, 0.03, 0.09), (-0.15, 0.345, 0.08), pr), caixa("Olho2", (0.10, 0.03, 0.09), (0.15, 0.345, 0.08), pr), caixa("Boca", (0.30, 0.03, 0.10), (0, 0.345, -0.10), pr),
          caixa("BocaLuz", (0.26, 0.032, 0.06), (0, 0.346, -0.10), lum), caixa("Nariz", (0.05, 0.03, 0.06), (0, 0.345, 0.0), pr)]
    for sx in (1, -1):
        p.append(caixa("Folha", (0.12, 0.05, 0.05), (sx * 0.22, 0.05, 0.33), ver)); p.append(caixa("Folha2", (0.08, 0.05, 0.05), (sx * 0.32, 0.05, 0.31), ver))
    exportar(p, "acessorios", "fantasia_abobora")
    limpar()
    la = mat("Laranja", (0.98, 0.52, 0.10), 0.0, 0.85); fi = mat("Fita", (0.30, 0.14, 0.40), 0.0, 0.85); ou = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3); lu = mat("Luz", (1.0, 0.85, 0.35), 0.0, 0.3)
    p = [caixa("Aba", (0.86, 0.96, 0.035), (0, 0, 0.0), la), caixa("Aba2", (0.74, 0.84, 0.03), (0, 0, 0.03), la), caixa("Fita", (0.54, 0.64, 0.07), (0, 0, 0.085), fi), caixa("Fivela", (0.10, 0.04, 0.09), (0, 0.325, 0.085), ou)]
    z = 0.12
    for i, w in enumerate([0.48, 0.42, 0.36, 0.30, 0.25, 0.20, 0.15]):
        p.append(caixa("Camada%d" % i, (w, w * 1.12, 0.095), (0, -0.025 * i, z + 0.0475), la)); z += 0.095
    p += [caixa("Ponta1", (0.10, 0.10, 0.09), (0.0, -0.20, z + 0.045), la), caixa("Ponta2", (0.08, 0.08, 0.08), (0.04, -0.24, z + 0.12), la), caixa("Lant", (0.05, 0.05, 0.07), (0.10, -0.27, z + 0.02), lu)]
    exportar(p, "acessorios", "chapeu_bruxa_laranja")


def cabelo_preto_franja_flores():
    import random
    limpar()
    random.seed(6)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    flo = mat("Flor", (0.98, 0.90, 0.92), 0.0, 0.8)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Franja", (L + 0.02, 0.09, 0.22), (0, P * 0.5 - 0.005, -0.11), cab),
         caixa("Costas", (L + 0.03, 0.13, 1.20), (0, -(P * 0.5 - 0.05), -0.60), cab), caixa("CostasBaixo", (L * 0.9, 0.12, 0.10), (0, -(P * 0.5 - 0.05), -1.25), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.62, 1.0), (sx * (L * 0.5 + 0.02), -P * 0.12, -0.5), cab))
        p.append(caixa("Mecha", (0.09, 0.10, 0.80), (sx * (L * 0.5 + 0.02), P * 0.5 - 0.1, -0.42), cab))
        p.append(caixa("Flor", (0.07, 0.03, 0.07), (sx * (L * 0.5 + 0.06), P * 0.5 - 0.05, -0.08), flo))
        p.append(caixa("FlorMeio", (0.03, 0.035, 0.03), (sx * (L * 0.5 + 0.06), P * 0.5 - 0.04, -0.08), mat("Miolo", (0.95, 0.80, 0.30), 0.0, 0.8)))
    exportar(p, "cabelos", "cabelo_preto_franja_flores")


def papai_noel():
    mats = {"c": ("Casaco", (0.78, 0.07, 0.09), 0.0, 0.85), "p": ("Pelo", (0.97, 0.97, 0.98), 0.0, 1.0), "k": ("Preto", (0.07, 0.07, 0.08), 0.0, 0.6), "o": ("Ouro", (0.92, 0.72, 0.18), 0.9, 0.3)}
    tronco = _base("c") + [((0.14, 0.05, 0.50), (0.0, 0.195, -0.04), "p"), ((0.34, 0.33, 0.07), (0, 0, 0.28), "p"), ((0.575, 0.385, 0.07), (0, 0, -0.29), "k"), ((0.10, 0.04, 0.08), (0, 0.215, -0.29), "o")]
    sup, inf = _bracos("c")
    vestir("noel", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.33, 0.33, 0.08), (0, 0, -0.17), "p")],
           saia=[((0.60, 0.40, 0.26), (0, 0, 0.04), "c"), ((0.61, 0.41, 0.05), (0, 0, -0.10), "p")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.30, 0.30, 0.07), (0, 0, -0.245), "p")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k"), ((0.28, 0.33, 0.04), (0, 0, 0.01), "p")])
    limpar()
    ve = mat("Gorro", (0.78, 0.07, 0.09), 0.0, 0.9); br = mat("Pelo", (0.97, 0.97, 0.98), 0.0, 1.0)
    p = [caixa("Barra", (0.58, 0.82, 0.09), (0, 0, 0.02), br), caixa("Copa", (0.50, 0.70, 0.14), (0, 0, 0.13), ve), caixa("Cone", (0.38, 0.54, 0.12), (0, -0.05, 0.25), ve), caixa("Cone2", (0.26, 0.36, 0.12), (0, -0.14, 0.34), ve),
         caixa("Cone3", (0.18, 0.22, 0.10), (0, -0.24, 0.30), ve), caixa("Pompom", (0.12, 0.12, 0.12), (0, -0.32, 0.20), br)]
    p += [caixa("Barba", (0.54, 0.10, 0.22), (0, 0.33, -0.28), br), caixa("Barba2", (0.46, 0.12, 0.24), (0, 0.35, -0.50), br), caixa("Barba3", (0.36, 0.12, 0.22), (0, 0.36, -0.70), br),
          caixa("Barba4", (0.24, 0.12, 0.18), (0, 0.36, -0.88), br), caixa("Bigode", (0.40, 0.09, 0.07), (0, 0.38, -0.20), br), caixa("Sobrancelha", (0.40, 0.06, 0.06), (0, 0.37, 0.0), br)]
    exportar(p, "acessorios", "gorro_barba_noel")


def noiva():
    mats = {"c": ("Casaco", (0.97, 0.96, 0.98), 0.0, 0.7), "v": ("Vinco", (0.88, 0.86, 0.92), 0.0, 0.7), "f": ("Pelo", (0.93, 0.86, 0.70), 0.0, 0.8)}
    tronco = [((0.52, 0.355, 0.50), (0, 0, -0.07), "c"), ((0.50, 0.38, 0.05), (0, 0, 0.20), "v"), ((0.14, 0.38, 0.04), (0.18, 0, 0.26), "c"), ((0.14, 0.38, 0.04), (-0.18, 0, 0.26), "c"),
              ((0.575, 0.385, 0.05), (0, 0, -0.31), "v"), ((0.16, 0.05, 0.10), (0, -0.20, -0.18), "v"), ((0.06, 0.05, 0.22), (0.07, -0.20, -0.34), "v"), ((0.06, 0.05, 0.22), (-0.07, -0.20, -0.34), "v")]
    saia = [((0.58, 0.40, 0.08), (0, 0, 0.13), "v")]
    for i, (w, d, z) in enumerate([(0.64, 0.44, 0.04), (0.80, 0.56, -0.10), (0.96, 0.68, -0.24), (1.12, 0.80, -0.38), (1.26, 0.92, -0.52), (1.38, 1.04, -0.64)]):
        saia.append(((w, d, 0.15), (0, 0, z), "c" if i % 2 == 0 else "v"))
    saia.append(((0.50, 0.50, 0.12), (0, -0.52, -0.62), "c"))
    vestir("noiva", mats, tronco=tronco, saia=saia, manga_sup=[((0.30, 0.30, 0.12), (0, 0, -0.04), "c")], manga_inf=[((0.27, 0.27, 0.21), (0, 0, -0.105), "v")])
    limpar()
    br = mat("Veu", (0.97, 0.97, 0.99), 0.0, 0.6); fl = mat("Flor", (0.98, 0.94, 0.96), 0.0, 0.8); ve = mat("Folha", (0.55, 0.75, 0.40), 0.0, 0.8)
    import math
    p = []
    for i in range(18):
        t = i / 18 * 2 * math.pi
        p.append(caixa("Flor", (0.07, 0.07, 0.05), (0.27 * math.cos(t), 0.39 * math.sin(t), 0.0), fl))
        if i % 3 == 0:
            p.append(caixa("Folha", (0.05, 0.04, 0.04), (0.27 * math.cos(t + 0.1), 0.39 * math.sin(t + 0.1), 0.02), ve))
    p.append(caixa("VeuTopo", (0.58, 0.82, 0.03), (0, -0.02, 0.03), br)); p.append(caixa("VeuCostas", (0.58, 0.05, 1.20), (0, -0.44, -0.60), br))
    p.append(caixa("VeuBaixo", (0.80, 0.07, 0.30), (0, -0.46, -1.35), br))
    for sx in (1, -1):
        p.append(caixa("VeuLado", (0.05, 0.60, 0.70), (sx * 0.30, -0.18, -0.38), br))
    exportar(p, "acessorios", "veu_noiva")


def cabelo_azul_mechas():
    import random
    limpar()
    random.seed(52)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.95, P * 0.9, 0.08), (0, -0.01, 0.04), cab), caixa("Nuca", (L + 0.03, 0.14, 0.46), (0, -(P * 0.5 - 0.04), -0.23), cab)]
    for i in range(9):
        p.append(caixa("Franja", (0.07, 0.08, random.uniform(0.14, 0.26)), (-0.25 + i * 0.062, P * 0.5 - 0.005, -0.07), cab))
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.64, 0.38), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.19), cab))
        p.append(caixa("Mecha", (0.09, 0.11, 0.78), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.45), cab))
        p.append(caixa("MechaPonta", (0.07, 0.09, 0.14), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, -0.91), cab))
    for i in range(12):
        p.append(caixa("Topo%d" % i, (0.11, 0.11, 0.07), (random.uniform(-0.2, 0.2), random.uniform(-0.3, 0.3), 0.09), cab))
    exportar(p, "cabelos", "cabelo_azul_mechas")


def cabelo_pixie():
    import random
    limpar()
    random.seed(19)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.85)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab), caixa("Nuca", (L, 0.10, 0.22), (0, -(P * 0.5 - 0.05), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.58, 0.18), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.09), cab))
    for i in range(32):
        x = random.uniform(-L * 0.45, L * 0.45); y = random.uniform(-P * 0.42, P * 0.44); h = random.uniform(0.05, 0.13); w = random.uniform(0.07, 0.12)
        p.append(caixa("Camada%d" % i, (w, w * 1.3, h), (x + (0.03 if y > 0 else 0.0), y, h * 0.5 - 0.01), cab))
    for k in range(6):
        p.append(caixa("Franja%d" % k, (0.10, 0.07, 0.07), (-0.28 + k * 0.1 - 0.0, P * 0.5 - 0.02, -0.04 - k * 0.018), cab))
    exportar(p, "cabelos", "cabelo_pixie")


def cabelo_rosa_topete():
    import random
    limpar()
    random.seed(29)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    fio = mat("Faixa", (0.18, 0.14, 0.16), 0.0, 0.7); fl = mat("Flor", (0.98, 0.90, 0.70), 0.0, 0.7)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Nuca", (L + 0.02, 0.12, 0.30), (0, -(P * 0.5 - 0.05), -0.15), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.6, 0.26), (sx * (L * 0.5 + 0.0), -P * 0.10, -0.13), cab))
    for i in range(7):    # topete varrido
        p.append(caixa("Topete%d" % i, (0.12, 0.10, 0.10), (-0.18 + i * 0.045, P * 0.5 - 0.1 - i * 0.02, 0.10 + 0.02 * i), cab))
    for i in range(18):
        p.append(caixa("Mecha%d" % i, (0.085, 0.085, random.uniform(0.06, 0.12)), (random.uniform(-0.24, 0.24), random.uniform(-0.3, 0.3), 0.05 + random.uniform(0, 0.05)), cab))
    for i in range(7):
        p.append(caixa("Franja%d" % i, (0.09, 0.07, random.uniform(0.10, 0.20)), (-0.2 + i * 0.07, P * 0.5 - 0.03, -0.07), cab))
    p.append(caixa("Tiara", (0.56, 0.03, 0.05), (0, P * 0.5 + 0.01, 0.0), fio)); p.append(caixa("TiaraT", (0.56, 0.03, 0.05), (0, -P * 0.5 - 0.01, 0.0), fio))
    for sx in (1, -1):
        p.append(caixa("TiaraL", (0.03, P, 0.05), (sx * 0.28, 0, 0.0), fio))
    p.append(caixa("Flor", (0.08, 0.04, 0.08), (0.18, P * 0.5 + 0.03, 0.0), fl))
    exportar(p, "cabelos", "cabelo_rosa_topete")


def cabelo_tranca_coroa():
    import math, random
    limpar()
    random.seed(37)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.9, P * 0.88, 0.07), (0, -0.01, 0.045), cab), caixa("Nuca", (L + 0.03, 0.14, 0.40), (0, -(P * 0.5 - 0.04), -0.20), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.64, 0.32), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.16), cab))
    for i in range(10):
        p.append(caixa("Franja", (0.08, 0.07, random.uniform(0.12, 0.20)), (-0.22 + i * 0.049, P * 0.5 - 0.005, -0.06), cab))
    n = 30
    for i in range(n):
        t = i / n * 2 * math.pi
        zz = -0.03 + 0.02 * (1 if i % 2 else 0)
        p.append(caixa_rot("Tranca", (0.12, 0.08, 0.07), (0.29 * math.cos(t), 0.41 * math.sin(t), zz), cab, math.degrees(t) + 90 + (20 if i % 2 else -20)))
    exportar(p, "cabelos", "cabelo_tranca_coroa")


def cauboi_neon():
    mats = {"c": ("Casaco", (0.07, 0.07, 0.09), 0.0, 0.6), "v": ("Vinco", (0.16, 0.16, 0.19), 0.0, 0.5), "n": ("Neon", (0.20, 0.75, 1.0), 0.0, 0.3)}
    tronco = _tronco_aberto("c") + [((0.36, 0.34, 0.14), (0, 0, 0.30), "c"), ((0.34, 0.03, 0.03), (0, 0.19, 0.37), "n"), ((0.03, 0.04, 0.50), (0.075, 0.205, -0.04), "n"), ((0.03, 0.04, 0.50), (-0.075, 0.205, -0.04), "n"),
              ((0.58, 0.40, 0.07), (0, 0, -0.28), "v"), ((0.11, 0.04, 0.07), (0, 0.22, -0.28), "n"), ((0.02, 0.05, 0.50), (0, -0.215, -0.04), "n"), ((0.12, 0.04, 0.03), (0, -0.215, 0.20), "n")]
    for sx in (1, -1):
        tronco += [((0.14, 0.40, 0.04), (sx * 0.27, 0, 0.26), "v"), ((0.03, 0.12, 0.08), (sx * 0.31, 0, 0.23), "n")]
    sup, inf = _bracos("c")
    vestir("cauboi_neon", mats, tronco=tronco,
           saia=_saia_aberta("c", 0.80, -0.23) + [((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "n"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "n"), ((0.59, 0.38, 0.05), (0, 0, -0.62), "v"),
                                                    ((0.02, 0.055, 0.60), (0, -0.18, -0.20), "n"), ((0.09, 0.03, 0.025), (0.18, 0.205, -0.52), "n"), ((0.09, 0.03, 0.025), (-0.18, 0.205, -0.52), "n")],
           manga_sup=sup + [((0.31, 0.31, 0.05), (0, 0, -0.06), "v"), ((0.03, 0.31, 0.03), (0.15, 0, -0.06), "n")], manga_inf=inf + [((0.31, 0.31, 0.07), (0, 0, -0.16), "v"), ((0.03, 0.31, 0.03), (0.155, 0, -0.16), "n")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "c"), ((0.12, 0.03, 0.03), (0, 0.165, -0.07), "n")])
    limpar()
    pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6); cz = mat("Vinco", (0.16, 0.16, 0.19), 0.0, 0.5); ne = mat("Neon", (0.20, 0.75, 1.0), 0.0, 0.3)
    b = next(n for n in ne.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Emission Color"].default_value = (0.2, 0.75, 1.0, 1.0); b.inputs["Emission Strength"].default_value = 3.0
    exportar([caixa("Aba", (0.80, 0.98, 0.035), (0, 0, 0.0), pr), caixa("Copa", (0.50, 0.66, 0.16), (0, 0, 0.10), pr), caixa("CopaTopo", (0.46, 0.60, 0.04), (0, 0, 0.20), pr),
              caixa("Entalhe", (0.16, 0.30, 0.05), (0, 0.15, 0.225), pr), caixa("Faixa", (0.52, 0.68, 0.04), (0, 0, 0.055), cz), caixa("NeonF", (0.20, 0.03, 0.03), (0, 0.34, 0.06), ne),
              caixa("NeonE", (0.07, 0.03, 0.025), (-0.26, 0.2, 0.06), ne), caixa("NeonD", (0.07, 0.03, 0.025), (0.26, 0.2, 0.06), ne), caixa("NeonAba", (0.16, 0.03, 0.02), (0.0, 0.47, 0.02), ne)], "acessorios", "chapeu_cauboi_neon")


# ======================================================================= lote 10
def esquiador():
    mats = {"c": ("Casaco", (0.12, 0.30, 0.78), 0.0, 0.5), "o": ("Ouro", (0.98, 0.58, 0.10), 0.0, 0.5), "v": ("Vinco", (0.08, 0.20, 0.55), 0.0, 0.5), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.6)}
    tronco = _base("c") + [((0.575, 0.385, 0.05), (0, 0, 0.14 - k * 0.15), "v") for k in range(4)] + [((0.34, 0.33, 0.10), (0, 0, 0.29), "c"), ((0.03, 0.04, 0.55), (0, 0.195, -0.04), "k"),
              ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.60, 0.10, 0.20), (0, -0.30, 0.20), "c"), ((0.12, 0.04, 0.05), (0.2, 0.2, 0.18), "o")]
    for sx in (1, -1):
        tronco += [((0.16, 0.40, 0.04), (sx * 0.26, 0, 0.255), "o"), ((0.14, 0.09, 0.30), (sx * 0.27, 0.0, 0.40), "c")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.31, 0.31, 0.06), (0, 0, -0.07), "v"), ((0.31, 0.31, 0.06), (0, 0, -0.17), "v"), ((0.05, 0.31, 0.05), (0.0, 0.0, 0.01), "o")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.07), (0, 0, -0.17), "k")]
    vestir("esquiador", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, saia=[((0.60, 0.40, 0.18), (0, 0, 0.08), "c"), ((0.60, 0.40, 0.04), (0, 0, -0.03), "v")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")],
           coxa=[((0.30, 0.30, 0.36), (0, 0, -0.18), "c"), ((0.14, 0.04, 0.14), (0.0, 0.155, -0.16), "v"), ((0.31, 0.31, 0.05), (0, 0, -0.28), "o")],
           canela=[((0.30, 0.30, 0.285), (0, 0, -0.1425), "c"), ((0.31, 0.31, 0.05), (0, 0, -0.04), "o")],
           pe=[((0.28, 0.34, 0.10), (0, 0, -0.05), "k"), ((0.29, 0.35, 0.03), (0, 0, -0.095), "o")])
    limpar()
    az = mat("Azul", (0.12, 0.30, 0.78), 0.0, 0.8); ve = mat("Gravata", (0.85, 0.15, 0.15), 0.0, 0.8); am = mat("Ouro", (0.98, 0.80, 0.18), 0.0, 0.8); lr = mat("Faixa", (0.98, 0.58, 0.10), 0.0, 0.8)
    pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6); vd = mat("Vidro", (0.40, 0.80, 0.95), 0.2, 0.1)
    p = [caixa("Barra", (0.58, 0.82, 0.09), (0, 0, 0.02), az), caixa("Copa", (0.52, 0.72, 0.14), (0, 0, 0.13), az), caixa("Topo", (0.40, 0.56, 0.08), (0, 0, 0.24), lr), caixa("Topo2", (0.28, 0.40, 0.06), (0, 0, 0.31), ve),
         caixa("Pompom", (0.12, 0.12, 0.10), (0, 0, 0.37), am), caixa("Tira", (0.60, 0.84, 0.04), (0, 0, -0.04), pr), caixa("Aro", (0.52, 0.08, 0.20), (0, P * 0.5 + 0.03, -0.10), az), caixa("Lente", (0.44, 0.09, 0.14), (0, P * 0.5 + 0.035, -0.10), vd)]
    exportar(p, "acessorios", "gorro_esqui_oculos")


def surfista():
    mats = {"c": ("Casaco", (0.10, 0.45, 0.45), 0.0, 0.5), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.6), "v": ("Vinco", (0.06, 0.30, 0.30), 0.0, 0.5)}
    tronco = _base("c") + [((0.03, 0.04, 0.50), (0, 0.195, -0.04), "v"), ((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.10, 0.04, 0.12), (0.17, 0.2, 0.18), "k"), ((0.575, 0.385, 0.04), (0, 0, -0.30), "v")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.29, 0.29, 0.04), (0, 0, -0.19), "v")]
    vestir("surfista", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.04, 0.27, 0.36), (0.09, 0, -0.18), "v")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")])
    limpar()
    br = mat("Branco", (0.97, 0.95, 0.88), 0.0, 0.6); la = mat("Laranja", (0.98, 0.50, 0.15), 0.0, 0.6); am = mat("Ouro", (0.98, 0.80, 0.25), 0.0, 0.6); az = mat("Azul", (0.15, 0.55, 0.75), 0.0, 0.5)
    pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6)
    p = [caixa("Prancha", (0.34, 0.06, 1.30), (0.0, -0.31, -0.10), br)]
    for i, (w, z, m) in enumerate(((0.30, 0.50, la), (0.30, 0.38, am), (0.28, 0.26, br))):
        p.append(caixa("Ponta%d" % i, (w, 0.065, 0.10), (0, -0.315, z + 0.12), m))
    for k in range(5):
        p.append(caixa("Onda%d" % k, (0.14 + 0.02 * k, 0.065, 0.045), (-0.04 + 0.02 * k, -0.315, -0.05 - 0.07 * k), az))
    p += [caixa("Quilha", (0.04, 0.05, 0.20), (0, -0.36, -0.70), pr), caixa("Tira", (0.40, 0.03, 0.05), (0, -0.25, 0.05), pr), caixa("Tira2", (0.40, 0.03, 0.05), (0, -0.25, -0.20), pr)]
    for sx in (1, -1):
        p.append(caixa("Alca", (0.05, 0.03, 0.54), (sx * 0.14, 0.19, 0.0), pr)); p.append(caixa("AlcaOmbro", (0.05, 0.40, 0.03), (sx * 0.14, -0.02, 0.255), pr)); p.append(caixa("AlcaT", (0.05, 0.03, 0.40), (sx * 0.14, -0.19, 0.05), pr))
    exportar(p, "acessorios", "prancha_surf")


def basquete():
    mats = {"c": ("Casaco", (0.96, 0.50, 0.08), 0.0, 0.8), "v": ("Vinco", (0.80, 0.38, 0.05), 0.0, 0.8), "b": ("Branco", (0.97, 0.97, 0.98), 0.0, 0.7)}
    tronco = [((0.46, 0.34, 0.54), (0, 0, -0.05), "c"), ((0.10, 0.38, 0.03), (0.15, 0, 0.255), "c"), ((0.10, 0.38, 0.03), (-0.15, 0, 0.255), "c"), ((0.34, 0.04, 0.06), (0, 0.18, 0.21), "v"), ((0.50, 0.36, 0.05), (0, 0, -0.30), "v"),
              ((0.12, 0.04, 0.16), (0, 0.185, 0.0), "b")]
    vestir("basquete", mats, tronco=tronco, cintura=[((0.55, 0.31, 0.16), (0, 0, 0.09), "c"), ((0.56, 0.32, 0.03), (0, 0, 0.16), "v")],
           coxa=[((0.34, 0.34, 0.36), (0, 0, -0.18), "c"), ((0.35, 0.35, 0.05), (0, 0, -0.34), "v"), ((0.04, 0.35, 0.34), (0.1, 0, -0.18), "b")], canela=[((0.32, 0.32, 0.12), (0, 0, -0.06), "c")])
    limpar()
    la = mat("Laranja", (0.98, 0.50, 0.10), 0.0, 0.6); br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.7); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6)
    exportar([caixa("Sola", (0.29, 0.35, 0.05), (0, 0.0, -0.075), br), caixa("Corpo", (0.27, 0.27, 0.12), (0, -0.02, 0.0), br), caixa("Bico", (0.26, 0.10, 0.09), (0, 0.18, -0.02), la),
              caixa("Cano", (0.29, 0.22, 0.22), (0, -0.06, 0.15), la), caixa("Boca", (0.30, 0.24, 0.04), (0, -0.06, 0.27), br), caixa("Lingua", (0.13, 0.04, 0.20), (0, 0.10, 0.17), br),
              caixa("Cadarco", (0.15, 0.03, 0.025), (0, 0.15, 0.05), pr)], "acessorios", "tenis_alto_laranja")


def flamenco():
    mats = {"c": ("Casaco", (0.78, 0.07, 0.10), 0.0, 0.8), "v": ("Vinco", (0.55, 0.04, 0.07), 0.0, 0.85)}
    tronco = [((0.53, 0.36, 0.52), (0, 0, -0.07), "c"), ((0.40, 0.04, 0.04), (0, 0.19, 0.20), "v"), ((0.14, 0.38, 0.04), (0.18, 0, 0.26), "c"), ((0.14, 0.38, 0.04), (-0.18, 0, 0.26), "c"), ((0.575, 0.385, 0.05), (0, 0, -0.31), "v")]
    saia = [((0.60, 0.40, 0.20), (0, 0, 0.07), "c")]
    for i, (w, d, z) in enumerate([(0.74, 0.50, -0.08), (0.92, 0.62, -0.22), (1.06, 0.74, -0.36), (1.18, 0.84, -0.50), (1.26, 0.92, -0.62)]):
        saia.append(((w, d, 0.14), (0, 0, z), "c" if i % 2 == 0 else "v"))
    vestir("flamenco", mats, tronco=tronco, saia=saia, manga_sup=[((0.29, 0.29, 0.34), (0, 0, -0.15), "c"), ((0.34, 0.34, 0.05), (0, 0, 0.0), "v")],
           manga_inf=[((0.28, 0.28, 0.12), (0, 0, -0.06), "c"), ((0.36, 0.36, 0.05), (0, 0, -0.14), "v"), ((0.33, 0.33, 0.04), (0, 0, -0.20), "c")])
    limpar()
    pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6); ve = mat("Gravata", (0.78, 0.07, 0.10), 0.0, 0.8); ou = mat("Ouro", (0.90, 0.72, 0.20), 0.8, 0.4)
    p = [caixa("Cabo", (0.04, 0.04, 0.22), (0, 0, -0.18), pr)]
    for k in range(5):
        p.append(caixa("Vara%d" % k, (0.30 - 0.02 * abs(k - 2), 0.025, 0.04), (-0.0, 0.04 + k * 0.02, -0.33 - 0.0), ve)) if False else None
        p.append(caixa("Pano%d" % k, (0.06, 0.04, 0.30), (-0.12 + k * 0.06, 0.04, -0.40), ve if k % 2 == 0 else pr))
    p.append(caixa("Argola", (0.06, 0.05, 0.03), (0, 0, -0.30), ou))
    exportar(p, "acessorios", "leque_vermelho")


def ballet():
    mats = {"c": ("Casaco", (0.12, 0.12, 0.14), 0.0, 0.6), "v": ("Vinco", (0.08, 0.08, 0.10), 0.0, 0.6), "r": ("Rosa", (0.98, 0.78, 0.82), 0.0, 0.6)}
    tronco = [((0.50, 0.34, 0.50), (0, 0, -0.06), "c"), ((0.10, 0.37, 0.03), (0.15, 0, 0.255), "c"), ((0.10, 0.37, 0.03), (-0.15, 0, 0.255), "c"), ((0.30, 0.04, 0.05), (0, 0.18, 0.21), "v"), ((0.52, 0.355, 0.06), (0, 0, -0.30), "c")]
    vestir("ballet", mats, tronco=tronco, cintura=[((0.51, 0.29, 0.15), (0, 0, 0.09), "c")],
           pe=[((0.26, 0.31, 0.08), (0, 0, -0.06), "r"), ((0.12, 0.28, 0.03), (0, 0.0, -0.01), "r")])


def sari():
    mats = {"c": ("Casaco", (0.72, 0.07, 0.12), 0.0, 0.8), "o": ("Ouro", (0.92, 0.72, 0.22), 0.8, 0.4), "v": ("Vinco", (0.52, 0.04, 0.08), 0.0, 0.85)}
    tronco = [((0.545, 0.37, 0.34), (0, 0, 0.07), "c"), ((0.38, 0.04, 0.06), (0, 0.19, 0.15), "o"), ((0.14, 0.38, 0.04), (0.18, 0, 0.26), "c"), ((0.575, 0.385, 0.04), (0, 0, -0.10), "o")]
    for k in range(5):
        tronco.append(((0.09, 0.06, 0.62 - k * 0.0), (0.22 - k * 0.11, 0.21, -0.04 - k * 0.04), "c"))
        tronco.append(((0.09, 0.062, 0.05), (0.22 - k * 0.11, 0.21, 0.24 - k * 0.12), "o"))
    tronco += [((0.20, 0.08, 0.50), (-0.18, -0.20, -0.08), "c"), ((0.03, 0.09, 0.50), (-0.28, -0.20, -0.08), "o")]
    saia = [((0.62, 0.42, 0.78), (0, 0, -0.22), "c"), ((0.63, 0.43, 0.06), (0, 0, -0.60), "o"), ((0.62, 0.42, 0.05), (0, 0, -0.52), "v")]
    for x, z in ((-0.15, -0.10), (0.12, -0.20), (-0.10, -0.32), (0.16, -0.42)):
        saia.append(((0.04, 0.02, 0.04), (x, 0.215, z), "o"))
    vestir("sari", mats, tronco=tronco, saia=saia, manga_sup=[((0.29, 0.29, 0.18), (0, 0, -0.06), "c"), ((0.30, 0.30, 0.03), (0, 0, -0.16), "o")])


def karate():
    mats = {"c": ("Casaco", (0.96, 0.96, 0.98), 0.0, 0.9), "v": ("Vinco", (0.82, 0.82, 0.86), 0.0, 0.9), "k": ("Preto", (0.06, 0.06, 0.08), 0.0, 0.7)}
    tronco = _base("c") + [((0.08, 0.04, 0.46), (0.07, 0.195, 0.0), "v"), ((0.08, 0.04, 0.46), (-0.07, 0.195, 0.0), "v"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "c"), ((0.58, 0.39, 0.06), (0, 0, -0.26), "k"), ((0.07, 0.05, 0.20), (0.05, 0.215, -0.36), "k"), ((0.07, 0.05, 0.18), (-0.04, 0.215, -0.35), "k")]
    sup = [((0.32, 0.32, 0.34), (0, 0, -0.15), "c")]
    inf = [((0.34, 0.34, 0.21), (0, 0, -0.105), "c")]
    vestir("karate", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, saia=[((0.60, 0.40, 0.18), (0, 0, 0.08), "c")], cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")],
           coxa=[((0.31, 0.31, 0.36), (0, 0, -0.18), "c")], canela=[((0.30, 0.30, 0.285), (0, 0, -0.1425), "c")])
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9)
    p = [caixa("Faixa", (0.55, 0.78, 0.09), (0, 0, -0.07), br), caixa("No", (0.12, 0.07, 0.10), (0, -0.40, -0.07), br), caixa("Ponta1", (0.05, 0.04, 0.18), (-0.05, -0.43, -0.17), br), caixa("Ponta2", (0.05, 0.04, 0.16), (0.05, -0.43, -0.15), br)]
    exportar(p, "acessorios", "faixa_karate")


def hanbok():
    mats = {"c": ("Casaco", (0.96, 0.64, 0.74), 0.0, 0.85), "b": ("Branco", (0.97, 0.93, 0.85), 0.0, 0.85), "r": ("Rosa", (0.98, 0.80, 0.86), 0.0, 0.85), "v": ("Vinco", (0.80, 0.46, 0.58), 0.0, 0.85)}
    tronco = [((0.55, 0.37, 0.36), (0, 0, 0.04), "c"), ((0.34, 0.33, 0.07), (0, 0, 0.28), "b"), ((0.10, 0.04, 0.30), (0.08, 0.195, 0.08), "b"), ((0.10, 0.04, 0.30), (-0.08, 0.195, 0.08), "b"),
              ((0.58, 0.39, 0.05), (0, 0, -0.14), "b"), ((0.06, 0.05, 0.24), (-0.05, 0.21, -0.26), "r"), ((0.06, 0.05, 0.20), (0.06, 0.21, -0.25), "r"), ((0.10, 0.05, 0.08), (0.0, 0.21, -0.14), "r"),
              ((0.06, 0.02, 0.06), (0.15, 0.2, 0.12), "b"), ((0.06, 0.02, 0.06), (-0.17, 0.2, 0.02), "b")]
    saia = [((0.60, 0.40, 0.14), (0, 0, 0.12), "c")]
    for i in range(9):
        saia.append(((0.10, 0.52 + (0.06 if i % 2 else 0.0), 0.62), (-0.36 + i * 0.09, 0, -0.30), "c" if i % 2 == 0 else "v"))
    saia += [((0.84, 0.62, 0.10), (0, 0, -0.60), "b"), ((0.85, 0.63, 0.03), (0, 0, -0.55), "r")]
    vestir("hanbok", mats, tronco=tronco, saia=saia, manga_sup=[((0.31, 0.31, 0.34), (0, 0, -0.15), "c")], manga_inf=[((0.34, 0.34, 0.21), (0, 0, -0.105), "c"), ((0.35, 0.35, 0.05), (0, 0, -0.20), "b")])


def egipcio():
    mats = {"c": ("Branco", (0.96, 0.94, 0.88), 0.0, 0.85), "o": ("Ouro", (0.92, 0.72, 0.20), 0.9, 0.3), "a": ("Azul", (0.10, 0.20, 0.60), 0.0, 0.6), "t": ("Cruz", (0.15, 0.40, 0.85), 0.0, 0.2)}
    cintura = [((0.55, 0.31, 0.05), (0, 0, 0.12), "o"), ((0.10, 0.04, 0.08), (0, 0.17, 0.12), "t")]
    saia = [((0.60, 0.40, 0.28), (0, 0, 0.0), "c")]
    for i in range(7):
        saia.append(((0.03, 0.41, 0.28), (-0.27 + i * 0.09, 0, 0.0), "o" if i % 2 else "a"))
    saia += [((0.14, 0.04, 0.34), (0, 0.205, -0.02), "o"), ((0.60, 0.40, 0.03), (0, 0, -0.14), "o")]
    vestir("egipcio", mats, cintura=cintura, saia=saia, manga_sup=[((0.30, 0.30, 0.04), (0, 0, -0.04), "o"), ((0.30, 0.30, 0.04), (0, 0, -0.10), "a")],
           manga_inf=[((0.28, 0.28, 0.04), (0, 0, -0.17), "o")])
    limpar()
    o = mat("Ouro", (0.92, 0.72, 0.20), 0.9, 0.3); a = mat("Azul", (0.10, 0.20, 0.60), 0.0, 0.6); t = mat("Turquesa", (0.10, 0.70, 0.70), 0.2, 0.3)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), a), caixa("Tras", (larg, 0.10, 0.62), (0, -prof * 0.5 + 0.05, -0.25), a), caixa("Testa", (larg, 0.05, 0.05), (0, prof * 0.5 - 0.02, -0.02), o), caixa("Cobra", (0.06, 0.06, 0.10), (0, prof * 0.5 + 0.02, 0.02), o)]
    for k in range(5):
        p.append(caixa("Lista%d" % k, (larg + 0.01, prof + 0.01, 0.03), (0, 0, 0.0 - 0.1 * k - 0.0), o)) if k < 0 else None
        p.append(caixa("Faixa%d" % k, (0.62, 0.84, 0.035), (0, -0.04, 0.095 - 0.11 * k - 0.0 if False else -0.05 - 0.11 * k), o if k % 2 == 0 else a)) if False else None
    for sx in (1, -1):
        p.append(caixa("Lado", (0.10, 0.58, 0.60), (sx * (larg * 0.5 + 0.02), 0.04, -0.25), a))
        for k in range(6):
            p.append(caixa("ListraL%d" % k, (0.105, 0.58, 0.035), (sx * (larg * 0.5 + 0.02), 0.04, -0.06 - 0.10 * k), o))
        p.append(caixa("Pano", (0.12, 0.20, 0.30), (sx * (larg * 0.5 + 0.03), 0.20, -0.65), a))
        for k in range(3):
            p.append(caixa("ListraP%d" % k, (0.125, 0.20, 0.03), (sx * (larg * 0.5 + 0.03), 0.20, -0.55 - 0.08 * k), o))
    for k in range(7):
        p.append(caixa("ListraT%d" % k, (larg + 0.01, 0.105, 0.03), (0, -prof * 0.5 + 0.05, -0.04 - 0.09 * k), o))
    exportar(p, "acessorios", "nemes_farao")
    limpar()
    o = mat("Ouro", (0.92, 0.72, 0.20), 0.9, 0.3); a = mat("Azul", (0.10, 0.20, 0.60), 0.0, 0.6); t = mat("Turquesa", (0.10, 0.70, 0.70), 0.2, 0.3); v = mat("Vermelho", (0.80, 0.12, 0.12), 0.2, 0.3)
    p = []
    for k, (w, d, z, m) in enumerate(((0.72, 0.50, 0.24, o), (0.84, 0.56, 0.18, a), (0.92, 0.60, 0.12, o), (0.84, 0.56, 0.06, t), (0.72, 0.50, 0.0, o))):
        p.append(caixa("Fiada%d" % k, (w, d, 0.06), (0, 0.0, z - 0.04), m))
    p.append(caixa("Peitoral", (0.16, 0.05, 0.16), (0, 0.29, -0.05), v))
    exportar(p, "acessorios", "colar_egipcio")


def poncho_arco_iris():
    limpar()
    cores = [(0.85, 0.12, 0.15), (0.96, 0.52, 0.12), (0.98, 0.82, 0.15), (0.30, 0.70, 0.30), (0.15, 0.50, 0.85), (0.55, 0.30, 0.80)]
    fr = mat("Franja", (0.96, 0.92, 0.78), 0.0, 0.9)
    p = [caixa("Gola", (0.40, 0.34, 0.07), (0, 0, 0.275), mat("Faixa0", cores[0], 0.0, 0.9))]
    for k, c in enumerate(cores):
        m = mat("Faixa%d" % k, c, 0.0, 0.9)
        w = 0.58 + 0.07 * k
        p.append(caixa("Frente%d" % k, (w, 0.05, 0.10), (0, 0.22 + 0.01 * k, 0.17 - 0.095 * k), m))
        p.append(caixa("Costas%d" % k, (w, 0.05, 0.10), (0, -0.22 - 0.01 * k, 0.17 - 0.095 * k), m))
        for sx in (1, -1):
            p.append(caixa("Lado%d" % k, (0.06, 0.40, 0.10), (sx * (w * 0.5 + 0.0), 0, 0.17 - 0.095 * k), m))
    for i in range(10):
        p.append(caixa("Franja", (0.03, 0.03, 0.06), (-0.40 + i * 0.088, 0.27, -0.45), fr))
        p.append(caixa("FranjaT", (0.03, 0.03, 0.06), (-0.40 + i * 0.088, -0.27, -0.45), fr))
    exportar(p, "acessorios", "poncho_arco_iris")
    limpar()
    pa = mat("Palha", (0.92, 0.78, 0.42), 0.0, 0.95); ve = mat("Faixa0", (0.85, 0.12, 0.15), 0.0, 0.8); am = mat("Faixa2", (0.98, 0.82, 0.15), 0.0, 0.8); vd = mat("Faixa3", (0.30, 0.70, 0.30), 0.0, 0.8)
    p = [caixa("Aba", (1.04, 1.18, 0.035), (0, 0, 0.0), pa), caixa("BordaV", (1.06, 1.20, 0.025), (0, 0, 0.0), ve), caixa("Borda2", (0.90, 1.04, 0.03), (0, 0, 0.03), am), caixa("Copa", (0.46, 0.62, 0.16), (0, 0, 0.11), pa),
         caixa("CopaTopo", (0.40, 0.54, 0.04), (0, 0, 0.20), pa), caixa("Fita", (0.48, 0.64, 0.05), (0, 0, 0.07), vd)]
    exportar(p, "acessorios", "sombrero_colorido")


def astronauta_retro():
    mats = {"c": ("Casaco", (0.96, 0.97, 0.98), 0.0, 0.6), "t": ("Turquesa", (0.10, 0.60, 0.58), 0.0, 0.5), "g": ("Aco", (0.60, 0.62, 0.66), 0.5, 0.5)}
    tronco = _base("c") + [((0.575, 0.385, 0.05), (0, 0, 0.0), "t"), ((0.12, 0.04, 0.50), (0.17, 0.195, -0.04), "t"), ((0.12, 0.04, 0.50), (-0.17, 0.195, -0.04), "t"), ((0.34, 0.33, 0.07), (0, 0, 0.27), "g"),
                           ((0.575, 0.385, 0.05), (0, 0, -0.30), "g"), ((0.14, 0.04, 0.10), (0, 0.2, 0.10), "t")]
    sup, inf = _bracos("c")
    vestir("astronauta_retro", mats, tronco=tronco, manga_sup=sup + [((0.30, 0.30, 0.05), (0, 0, -0.30), "t")], manga_inf=inf + [((0.31, 0.31, 0.07), (0, 0, -0.17), "g")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.55, 0.31, 0.04), (0, 0, 0.03), "g")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.27, 0.36), (0.09, 0, -0.18), "t")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.10, 0.27, 0.285), (0.09, 0, -0.1425), "t"), ((0.275, 0.275, 0.05), (0, 0, -0.04), "g")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "t"), ((0.26, 0.06, 0.07), (0, 0.17, -0.06), "c")])


def cabelo_coque_rede():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L, P, 0.10), (0, 0, -0.05), cab), caixa("Franja", (L, 0.07, 0.12), (0, P * 0.5 - 0.035, -0.06), cab), caixa("Nuca", (L, 0.10, 0.22), (0, -(P * 0.5 - 0.05), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.20), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.10), cab))
    p += [caixa("CoqueBase", (0.30, 0.18, 0.30), (0, -P * 0.5 - 0.05, -0.10), cab), caixa("Coque", (0.34, 0.20, 0.34), (0, -P * 0.5 - 0.10, -0.12), cab)]
    for k in range(4):
        p.append(caixa("Rede%d" % k, (0.36, 0.215, 0.015), (0, -P * 0.5 - 0.10, -0.26 + 0.09 * k), mat("Rede", (0.30, 0.20, 0.14), 0.0, 0.9)))
    exportar(p, "cabelos", "cabelo_coque_rede")


def peruca_mechas_rosa_azul():
    import random
    limpar()
    random.seed(70)
    base = mat("Base", (0.18, 0.10, 0.28), 0.0, 0.9); ro = mat("Rosa", (0.98, 0.25, 0.62), 0.0, 0.8); az = mat("Azul", (0.20, 0.60, 0.98), 0.0, 0.8)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), base), caixa("Franja", (L + 0.02, 0.08, 0.18), (0, P * 0.5 - 0.005, -0.09), base)]
    for i in range(10):
        z = -0.10 - i * 0.10
        wob = 0.04 if (i // 2) % 2 == 0 else -0.04
        p.append(caixa("Costas%d" % i, (L, 0.12, 0.10), (wob, -(P * 0.5 - 0.05), z), base))
        for sx in (1, -1):
            p.append(caixa("Lado%d" % i, (0.09, 0.30, 0.10), (sx * (L * 0.5 + 0.01) + wob * sx * 0.5, -0.1, z), base))
            p.append(caixa("Mecha%d" % i, (0.09, 0.10, 0.10), (sx * (L * 0.5 + 0.01), P * 0.5 - 0.08, z + 0.03), ro if sx > 0 else az))
        p.append(caixa("StreakR%d" % i, (0.06, 0.13, 0.10), (-0.12 + wob, -(P * 0.5 - 0.05), z), ro)); p.append(caixa("StreakA%d" % i, (0.06, 0.13, 0.10), (0.12 + wob, -(P * 0.5 - 0.05), z), az))
    exportar(p, "acessorios", "peruca_rosa_azul")


def cabelo_crespo_curto():
    import random
    limpar()
    random.seed(55)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.03, P + 0.03, 0.12), (0, 0, -0.04), cab), caixa("Nuca", (L + 0.04, 0.12, 0.30), (0, -(P * 0.5 - 0.04), -0.15), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.62, 0.28), (sx * (L * 0.5 + 0.02), -P * 0.12, -0.14), cab))
    for i in range(70):
        x = random.uniform(-L * 0.58, L * 0.58); y = random.uniform(-P * 0.52, P * 0.40); z = random.uniform(-0.2, 0.16)
        if abs(x) < L * 0.40 and y > P * 0.28 and z < 0.0:
            continue
        t = random.uniform(0.07, 0.12)
        p.append(caixa("Crespo", (t, t, t), (x, y, z), cab))
    exportar(p, "cabelos", "cabelo_crespo_curto")
    limpar()
    ve = mat("Faixa0", (0.72, 0.10, 0.14), 0.0, 0.9); br = mat("Branco", (0.97, 0.95, 0.92), 0.0, 0.9)
    p = []
    for k in range(10):
        m = ve if k % 2 == 0 else br
        p.append(caixa("Frente%d" % k, (0.06, 0.03, 0.09), (-0.27 + k * 0.06, P * 0.5 + 0.02, -0.03), m))
        p.append(caixa("Tras%d" % k, (0.06, 0.03, 0.09), (-0.27 + k * 0.06, -P * 0.5 - 0.02, -0.03), m))
    for sx in (1, -1):
        for k in range(9):
            p.append(caixa("Lado%d" % k, (0.03, 0.08, 0.09), (sx * (L * 0.5 + 0.02), -P * 0.5 + 0.05 + k * 0.09, -0.03), ve if k % 2 == 0 else br))
    p += [caixa("No", (0.12, 0.08, 0.12), (0, -P * 0.5 - 0.07, -0.03), ve), caixa("Ponta1", (0.06, 0.04, 0.22), (-0.06, -P * 0.5 - 0.10, -0.16), br), caixa("Ponta2", (0.06, 0.04, 0.20), (0.06, -P * 0.5 - 0.10, -0.14), ve)]
    exportar(p, "acessorios", "bandana_listrada")


def kilt():
    mats = {"c": ("Casaco", (0.10, 0.30, 0.20), 0.0, 0.9), "r": ("Gravata", (0.62, 0.10, 0.14), 0.0, 0.9), "a": ("Azul", (0.10, 0.20, 0.60), 0.0, 0.9), "k": ("Couro", (0.30, 0.17, 0.09), 0.0, 0.7),
            "p": ("Prata", (0.78, 0.80, 0.84), 0.9, 0.3), "b": ("Branco", (0.93, 0.90, 0.80), 0.0, 0.9)}
    tronco = [((0.02, 0.01, 0.01), (0, 0, 0), "c")]
    sash = []
    for i in range(7):
        t = i / 6
        sash.append(((0.10, 0.05, 0.10), (0.20 - 0.40 * t, 0.205, 0.22 - 0.50 * t), "c" if i % 2 == 0 else "r"))
        sash.append(((0.04, 0.052, 0.10), (0.20 - 0.40 * t, 0.206, 0.22 - 0.50 * t), "a"))
    sash += [((0.07, 0.06, 0.07), (0.0, 0.215, 0.0), "p"), ((0.58, 0.39, 0.05), (0, 0, -0.29), "k"), ((0.09, 0.05, 0.08), (0, 0.215, -0.29), "p")]
    saia = [((0.60, 0.40, 0.08), (0, 0, 0.13), "k")]
    for i in range(8):
        for j in range(4):
            saia.append(((0.075, 0.44 + (0.02 if i % 2 else 0.0), 0.085), (-0.26 + i * 0.075, 0, 0.06 - j * 0.085), ("c", "r", "a", "c")[(i + j) % 4]))
    saia += [((0.15, 0.04, 0.16), (0, 0.23, -0.02), "b"), ((0.04, 0.04, 0.10), (-0.05, 0.23, -0.14), "b"), ((0.04, 0.04, 0.10), (0.05, 0.23, -0.14), "b")]
    vestir("kilt", mats, tronco=sash, saia=saia)
    limpar()
    ve = mat("Casaco", (0.10, 0.30, 0.20), 0.0, 0.9); rd = mat("Gravata", (0.62, 0.10, 0.14), 0.0, 0.9); mad = mat("Madeira", (0.25, 0.14, 0.08), 0.0, 0.7); osso = mat("Marfim", (0.93, 0.90, 0.80), 0.0, 0.6)
    couro = mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.7)
    p = [caixa("Bolsa", (0.34, 0.14, 0.30), (0, -0.27, -0.10), ve), caixa("BolsaXadrez", (0.34, 0.145, 0.04), (0, -0.27, -0.10), rd), caixa("Cinta", (0.40, 0.03, 0.05), (0, -0.2, 0.0), couro),
         caixa("CintaV", (0.05, 0.03, 0.50), (0.0, -0.205, -0.05), couro)]
    for k, (x, tz) in enumerate(((-0.10, 0.34), (0.10, 0.30), (0.0, 0.40))):
        p.append(caixa("Dreno%d" % k, (0.045, 0.045, 0.56), (x, -0.30 - 0.02 * k, 0.28 + (tz - 0.34) * 0.5), mad)); p.append(caixa("Anel%d" % k, (0.06, 0.06, 0.04), (x, -0.30 - 0.02 * k, 0.45 + (tz - 0.34) * 0.5), osso)); p.append(caixa("Borla%d" % k, (0.03, 0.03, 0.10), (x, -0.30 - 0.02 * k, 0.20 + (tz - 0.34) * 0.5), rd))
    p += [caixa("Gaita", (0.04, 0.04, 0.30), (0.12, -0.27, -0.40), mad), caixa("Alca", (0.03, 0.40, 0.03), (0.15, -0.02, 0.255), couro), caixa("Alca2", (0.03, 0.40, 0.03), (-0.15, -0.02, 0.255), couro)]
    exportar(p, "acessorios", "gaita_de_fole")


def quiton_grego():
    mats = {"c": ("Casaco", (0.90, 0.90, 0.92), 0.0, 0.9), "v": ("Vinco", (0.76, 0.76, 0.80), 0.0, 0.9), "k": ("Couro", (0.30, 0.17, 0.09), 0.0, 0.7), "p": ("Prata", (0.78, 0.80, 0.84), 0.9, 0.3)}
    tronco = [((0.545, 0.365, 0.58), (0, 0, -0.04), "c"), ((0.24, 0.04, 0.16), (0.12, 0.19, 0.16), "v"), ((0.30, 0.04, 0.14), (-0.10, 0.19, 0.10), "v"), ((0.50, 0.04, 0.04), (0, 0.195, 0.05), "v"),
              ((0.58, 0.39, 0.05), (0, 0, -0.27), "k"), ((0.08, 0.05, 0.08), (0, 0.215, -0.27), "p"), ((0.06, 0.40, 0.03), (0.2, 0, 0.255), "v"), ((0.06, 0.40, 0.03), (-0.2, 0, 0.255), "v"),
              ((0.05, 0.05, 0.05), (0.2, 0.19, 0.25), "p"), ((0.05, 0.05, 0.05), (-0.2, 0.19, 0.25), "p")]
    saia = [((0.60, 0.40, 0.60), (0, 0, -0.14), "c")]
    for i in range(5):
        saia.append(((0.04, 0.41, 0.58), (-0.24 + i * 0.12, 0, -0.14), "v"))
    saia += [((0.62, 0.42, 0.03), (0, 0, -0.45), "v")]
    vestir("quiton", mats, tronco=tronco, saia=saia, manga_sup=[((0.29, 0.29, 0.06), (0, 0, -0.01), "c")])


def toga_romana():
    mats = {"c": ("Casaco", (0.97, 0.94, 0.84), 0.0, 0.9), "o": ("Ouro", (0.92, 0.72, 0.20), 0.9, 0.3), "v": ("Vinco", (0.86, 0.82, 0.70), 0.0, 0.9)}
    tronco = [((0.545, 0.365, 0.58), (0, 0, -0.04), "v")]
    for i in range(6):
        t = i / 5
        tronco.append(((0.14, 0.05, 0.14), (0.22 - 0.44 * t, 0.205, 0.26 - 0.50 * t), "c"))
        tronco.append(((0.15, 0.052, 0.025), (0.22 - 0.44 * t, 0.207, 0.19 - 0.50 * t), "o"))
    tronco += [((0.09, 0.07, 0.09), (0.22, 0.22, 0.20), "o"), ((0.20, 0.08, 0.50), (-0.20, 0.20, -0.04), "c"), ((0.5, 0.04, 0.3), (0, -0.20, -0.1), "c")]
    saia = [((0.62, 0.42, 0.78), (0, 0, -0.22), "c"), ((0.63, 0.43, 0.04), (0, 0, -0.60), "o"), ((0.63, 0.43, 0.025), (0, 0, -0.54), "o"), ((0.20, 0.08, 0.60), (-0.22, 0.22, -0.20), "v"), ((0.22, 0.08, 0.60), (0.18, 0.22, -0.25), "v")]
    for i in range(8):
        saia.append(((0.04, 0.44, 0.04), (-0.27 + i * 0.077, 0.0, -0.57), "o"))
    vestir("toga", mats, tronco=tronco, saia=saia, manga_sup=[((0.29, 0.29, 0.10), (0, 0, -0.03), "c")])
    limpar()
    ou = mat("Ouro", (0.95, 0.76, 0.18), 0.9, 0.3)
    import math
    p = []
    for sx in (1, -1):
        for k in range(8):
            a = math.radians(-30 + k * 18)
            p.append(caixa_rot("Folha", (0.12, 0.05, 0.04), (sx * (0.15 + 0.12 * math.sin(a)), P * 0.5 - 0.02 - 0.02 * k if False else (0.35 - 0.10 * k), -0.03), ou, (25 if sx > 0 else -25) + 0 - k * 0))
    for i in range(24):
        t = i / 24 * 2 * math.pi
        p.append(caixa_rot("Louro", (0.10, 0.05, 0.04), (0.272 * math.cos(t), 0.392 * math.sin(t), -0.03 + 0.01 * (i % 2)), ou, math.degrees(t) + 90 + (24 if i % 2 else -24)))
    exportar(p, "acessorios", "coroa_louros_dourada")


def cabelo_undercut_topete():
    import random
    limpar()
    random.seed(8)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.85)
    p = [caixa("Calota", (L, P, 0.07), (0, 0, -0.035), cab), caixa("Nuca", (L, 0.05, 0.14), (0, -(P * 0.5 - 0.025), -0.07), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.035, P * 0.58, 0.14), (sx * (L * 0.5 - 0.0175), -P * 0.12, -0.07), cab))
    for i in range(6):    # topete grande varrido para trás
        p.append(caixa("Topete%d" % i, (L * 0.78 - 0.02 * i, 0.16, 0.12), (0, P * 0.30 - i * 0.11, 0.07 + 0.015 * i), cab))
    for i in range(5):
        p.append(caixa("Onda%d" % i, (0.14, 0.10, 0.07), (random.uniform(-0.12, 0.12), P * 0.40 - i * 0.12, 0.15 + 0.02 * i), cab))
    p.append(caixa("Franja", (0.40, 0.09, 0.14), (0, P * 0.5 - 0.0, 0.0), cab))
    exportar(p, "cabelos", "cabelo_undercut_topete")


# ======================================================================= lote 11
def futebol():
    mats = {"c": ("Casaco", (0.15, 0.45, 0.92), 0.0, 0.85), "b": ("Branco", (0.97, 0.97, 0.98), 0.0, 0.85), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)}
    tronco = _base("b") + [((0.065, 0.375, 0.55), (-0.24 + i * 0.12, 0, -0.04), "c") for i in range(5)] + [((0.30, 0.30, 0.06), (0, 0, 0.275), "c")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "b")] + [((0.06, 0.30, 0.34), (-0.1 + k * 0.1, 0, -0.15), "c") for k in range(3)]
    vestir("futebol", mats, tronco=tronco, manga_sup=[((0.30, 0.30, 0.20), (0, 0, -0.07), "b"), ((0.06, 0.30, 0.20), (0.0, 0, -0.07), "c"), ((0.31, 0.31, 0.04), (0, 0, -0.17), "c")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "b")], coxa=[((0.30, 0.30, 0.34), (0, 0, -0.17), "b")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "b"), ((0.27, 0.27, 0.04), (0, 0, -0.10), "c"), ((0.27, 0.27, 0.04), (0, 0, -0.18), "c")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k"), ((0.05, 0.05, 0.03), (0.08, 0.1, -0.10), "k"), ((0.05, 0.05, 0.03), (-0.08, 0.1, -0.10), "k"), ((0.05, 0.05, 0.03), (0, -0.1, -0.10), "k")])


def peruca_dreads_coloridos():
    import random
    limpar()
    random.seed(14)
    cores = [(0.55, 0.15, 0.75), (0.15, 0.40, 0.90), (0.15, 0.75, 0.70), (0.30, 0.78, 0.30), (0.98, 0.80, 0.15), (0.98, 0.50, 0.12), (0.90, 0.15, 0.40)]
    ms = [mat("Dread%d" % i, c, 0.0, 0.9) for i, c in enumerate(cores)]
    p = [caixa("Calota", (L, P, 0.09), (0, 0, -0.045), ms[0])]
    for i in range(34):
        x = random.uniform(-L * 0.46, L * 0.46); y = random.uniform(-P * 0.46, P * 0.44)
        h = random.uniform(0.16, 0.34)
        if abs(x) < L * 0.30 and y > P * 0.3:
            h = random.uniform(0.10, 0.16)
        m = ms[i % len(ms)]
        p.append(caixa("Dread", (0.075, 0.075, h), (x, y, -h * 0.5 + 0.03), m))
        p.append(caixa("DreadPonta", (0.06, 0.06, 0.05), (x, y, -h + 0.0), ms[(i + 3) % len(ms)]))
    for sx in (1, -1):
        for j in range(7):
            h = random.uniform(0.22, 0.38)
            p.append(caixa("DreadL", (0.075, 0.075, h), (sx * (L * 0.5 + 0.01), -0.30 + j * 0.10, -h * 0.5 - 0.0), ms[(j * 2 + (sx > 0)) % len(ms)]))
    exportar(p, "acessorios", "peruca_dreads_coloridos")


def samurai_feminina():
    mats = {"c": ("Casaco", (0.55, 0.08, 0.12), 0.0, 0.8), "k": ("Preto", (0.08, 0.08, 0.10), 0.0, 0.7), "b": ("Branco", (0.93, 0.90, 0.85), 0.0, 0.9), "v": ("Vinco", (0.38, 0.05, 0.08), 0.0, 0.8)}
    tronco = _tronco_aberto("c", 0.50, -0.04) + [((0.09, 0.04, 0.46), (0.07, 0.195, 0.02), "b"), ((0.09, 0.04, 0.46), (-0.07, 0.195, 0.02), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"),
              ((0.58, 0.40, 0.14), (0, 0, -0.26), "k"), ((0.16, 0.06, 0.16), (0.0, 0.23, -0.26), "k"), ((0.06, 0.06, 0.22), (0.07, 0.23, -0.42), "k"), ((0.06, 0.06, 0.22), (-0.07, 0.23, -0.42), "k")]
    sup, inf = _bracos("c")
    saia = [((0.60, 0.40, 0.18), (0, 0, 0.08), "c")]
    for i in range(7):
        saia.append(((0.095, 0.44 + (0.04 if i % 2 else 0.0), 0.62), (-0.27 + i * 0.09, 0, -0.30), "k"))
    saia.append(((0.72, 0.48, 0.03), (0, 0, -0.62), "k"))
    vestir("samurai_fem", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=inf + [((0.34, 0.34, 0.12), (0, 0, -0.14), "b")])


def sailor():
    mats = {"c": ("Casaco", (0.96, 0.96, 0.98), 0.0, 0.9), "a": ("Hakama", (0.10, 0.14, 0.34), 0.0, 0.85), "r": ("Gravata", (0.85, 0.12, 0.18), 0.0, 0.8), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)}
    tronco = _base("c") + [((0.60, 0.06, 0.20), (0, -0.21, 0.16), "a"), ((0.60, 0.065, 0.03), (0, -0.215, 0.07), "c"), ((0.30, 0.34, 0.07), (0, 0, 0.27), "a"), ((0.14, 0.05, 0.20), (0.0, 0.20, 0.22), "a"),
                           ((0.16, 0.06, 0.08), (0, 0.22, 0.14), "r"), ((0.05, 0.05, 0.16), (-0.03, 0.22, 0.05), "r"), ((0.05, 0.05, 0.14), (0.04, 0.22, 0.06), "r"), ((0.575, 0.385, 0.04), (0, 0, -0.30), "a")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.03), (0, 0, -0.12), "a"), ((0.30, 0.30, 0.03), (0, 0, -0.17), "a")]
    saia = [((0.60, 0.40, 0.16), (0, 0, 0.09), "a")]
    for i in range(10):
        saia.append(((0.07, 0.45 + (0.04 if i % 2 else 0.0), 0.20), (-0.32 + i * 0.071, 0, -0.04), "a"))
    vestir("sailor", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=inf, canela=[((0.28, 0.28, 0.285), (0, 0, -0.1425), "c")], pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "k")])


def punk():
    mats = {"c": ("Casaco", (0.08, 0.08, 0.09), 0.0, 0.45), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.25), "r": ("Gravata", (0.70, 0.08, 0.12), 0.0, 0.9), "k": ("Preto", (0.05, 0.05, 0.06), 0.0, 0.8), "v": ("Vinco", (0.14, 0.14, 0.16), 0.0, 0.5)}
    tronco = _tronco_aberto("c", 0.50, -0.04) + [((0.34, 0.33, 0.08), (0, 0, 0.27), "v"), ((0.11, 0.05, 0.40), (0.08, 0.195, 0.03), "v"), ((0.11, 0.05, 0.40), (-0.08, 0.195, 0.03), "v"), ((0.02, 0.05, 0.40), (0.0, 0.2, 0.03), "k"),
              ((0.18, 0.05, 0.32), (0.0, 0.18, -0.02), "k"), ((0.58, 0.40, 0.05), (0, 0, -0.27), "v")]
    for sx in (1, -1):
        for k in range(5):
            tronco.append(((0.03, 0.03, 0.03), (sx * (0.14 + k * 0.025), 0.0, 0.265), "p"))
        for k in range(3):
            tronco.append(((0.03, 0.03, 0.03), (sx * 0.13, 0.205, 0.05 - k * 0.08), "p"))
    sup, inf = _bracos("c")
    p_cuff = [((0.31, 0.31, 0.04), (0, 0, -0.18), "v")] + [((0.03, 0.03, 0.03), (0.0 + dx, 0.15, -0.18), "p") for dx in (-0.08, 0.0, 0.08)]
    plaid_t = []
    for i in range(4):
        for j in range(5):
            plaid_t.append(((0.065, 0.28 + 0.0, 0.075), (-0.10 + i * 0.065, 0, -0.04 - j * 0.075), "k" if (i + j) % 2 == 0 else "r"))
    vestir("punk", mats, tronco=tronco, manga_sup=sup + [((0.03, 0.03, 0.03), (0.1, 0.15, 0.0), "p")], manga_inf=inf + p_cuff,
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "r"), ((0.55, 0.31, 0.04), (0, 0, 0.14), "k"), ((0.07, 0.03, 0.06), (0, 0.16, 0.12), "p")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "r")] + [((0.27, 0.04 + 0.0, 0.36), (-0.06 + k * 0.06, 0.14, -0.18), "k") for k in range(3)] + [((0.04, 0.27, 0.36), (0.0 + k * 0.1 - 0.05, 0, -0.18), "k") for k in range(2)] + [((0.04, 0.03, 0.20), (0.12, 0.15, -0.20), "p")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "r")] + [((0.27, 0.04, 0.285), (-0.06 + k * 0.06, 0.14, -0.1425), "k") for k in range(3)] + [((0.275, 0.275, 0.04), (0, 0, -0.10), "k")],
           pe=[((0.28, 0.33, 0.11), (0, 0, -0.05), "k"), ((0.03, 0.03, 0.03), (0.08, 0.12, 0.0), "p"), ((0.03, 0.03, 0.03), (-0.08, 0.12, 0.0), "p")])


def hiphop():
    mats = {"c": ("Casaco", (0.50, 0.52, 0.56), 0.0, 0.95), "v": ("Vinco", (0.38, 0.40, 0.44), 0.0, 0.95), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.25), "k": ("Preto", (0.08, 0.08, 0.10), 0.0, 0.8)}
    tronco = [((0.60, 0.42, 0.60), (0, 0, -0.04), "c"), ((0.46, 0.05, 0.16), (0, 0.22, -0.14), "v"), ((0.58, 0.44, 0.07), (0, 0, -0.32), "v"), ((0.36, 0.36, 0.10), (0, 0, 0.28), "c"),
              ((0.46, 0.20, 0.14), (0, -0.28, 0.24), "c"), ((0.44, 0.04, 0.10), (0, 0.19, 0.28), "v"), ((0.02, 0.02, 0.14), (0.06, 0.22, 0.16), "k"), ((0.02, 0.02, 0.14), (-0.06, 0.22, 0.16), "k")]
    for k in range(7):
        t = k / 6
        tronco.append(((0.04, 0.03, 0.04), (-0.12 + 0.24 * t, 0.22, 0.24 - 0.10 * (1 - (2 * t - 1) ** 2)), "p"))
    sup = [((0.34, 0.34, 0.34), (0, 0, -0.15), "c")]
    inf = [((0.33, 0.33, 0.21), (0, 0, -0.105), "c"), ((0.34, 0.34, 0.05), (0, 0, -0.19), "v")]
    vestir("hiphop", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.55, 0.31, 0.15), (0, 0, 0.09), "k")],
           coxa=[((0.34, 0.34, 0.36), (0, 0, -0.18), "k")], canela=[((0.34, 0.34, 0.285), (0, 0, -0.1425), "k"), ((0.36, 0.36, 0.06), (0, 0, -0.24), "c")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "c")])
    limpar()
    gr = mat("Boné", (0.50, 0.52, 0.56), 0.0, 0.9); es = mat("BoneSombra", (0.38, 0.40, 0.44), 0.0, 0.9)
    exportar([caixa("Copa", (0.58, 0.80, 0.20), (0, 0, 0.10), gr), caixa("Topo", (0.54, 0.74, 0.03), (0, 0, 0.215), es), caixa("Aba", (0.50, 0.40, 0.035), (0, P * 0.5 + 0.20, 0.03), es), caixa("Fecho", (0.18, 0.04, 0.08), (0, -P * 0.5 - 0.02, 0.07), es)], "acessorios", "bone_aba_reta")


def lolita():
    mats = {"c": ("Casaco", (0.08, 0.08, 0.10), 0.0, 0.8), "b": ("Branco", (0.97, 0.97, 0.98), 0.0, 0.9), "v": ("Vinco", (0.18, 0.18, 0.22), 0.0, 0.8)}
    tronco = [((0.53, 0.36, 0.50), (0, 0, -0.07), "c"), ((0.30, 0.04, 0.34), (0, 0.19, 0.0), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"), ((0.18, 0.05, 0.10), (0, 0.215, 0.12), "c"),
              ((0.20, 0.05, 0.09), (0, 0.205, -0.20), "c"), ((0.575, 0.385, 0.05), (0, 0, -0.31), "b"), ((0.04, 0.05, 0.18), (0.08, 0.215, -0.04), "b"), ((0.04, 0.05, 0.18), (-0.08, 0.215, -0.04), "b")]
    saia = [((0.60, 0.40, 0.08), (0, 0, 0.13), "b")]
    for i, (w, d, z) in enumerate([(0.74, 0.50, 0.00), (0.90, 0.62, -0.14), (1.04, 0.72, -0.28), (1.14, 0.80, -0.42)]):
        saia.append(((w, d, 0.14), (0, 0, z), "c" if i % 2 == 0 else "v"))
        saia.append(((w + 0.02, d + 0.02, 0.03), (0, 0, z - 0.06), "b"))
    sup = [((0.29, 0.29, 0.18), (0, 0, -0.07), "c"), ((0.34, 0.34, 0.05), (0, 0, -0.17), "b")]
    vestir("lolita", mats, tronco=tronco, saia=saia, manga_sup=sup, manga_inf=[((0.28, 0.28, 0.21), (0, 0, -0.105), "b")],
           canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "b"), ((0.30, 0.30, 0.06), (0, 0, -0.04), "b")], pe=[((0.28, 0.33, 0.11), (0, 0, -0.05), "c"), ((0.10, 0.03, 0.03), (0, 0.17, 0.0), "b")])
    limpar()
    pr = mat("Preto", (0.08, 0.08, 0.10), 0.0, 0.8); br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9)
    p = [caixa("No", (0.14, 0.10, 0.12), (0, 0.0, 0.10), pr), caixa("Base", (0.54, 0.36, 0.05), (0, 0.0, 0.02), br)]
    for sx in (1, -1):
        p += [caixa("Laco", (0.22, 0.08, 0.20), (sx * 0.17, 0.0, 0.14), pr), caixa("LacoBorda", (0.24, 0.09, 0.03), (sx * 0.17, 0.0, 0.25), br), caixa("Ponta", (0.08, 0.06, 0.22), (sx * 0.06, -0.05, -0.06), pr)]
    exportar(p, "acessorios", "laco_gotico")


def steampunk():
    mats = {"c": ("Casaco", (0.42, 0.24, 0.12), 0.0, 0.7), "o": ("Ouro", (0.82, 0.62, 0.20), 0.85, 0.35), "b": ("Branco", (0.90, 0.86, 0.74), 0.0, 0.9), "k": ("Couro", (0.28, 0.16, 0.08), 0.0, 0.75)}
    tronco = _tronco_aberto("c", 0.46, 0.0) + [((0.34, 0.33, 0.06), (0, 0, 0.255), "b"), ((0.08, 0.04, 0.40), (0.0, 0.195, 0.02), "b"), ((0.08, 0.06, 0.08), (0.0, 0.21, 0.19), "k"),
              ((0.58, 0.40, 0.05), (0, 0, -0.26), "k"), ((0.08, 0.05, 0.08), (0, 0.215, -0.26), "o"), ((0.07, 0.04, 0.07), (0.14, 0.2, 0.0), "o"), ((0.01, 0.045, 0.14), (0.14, 0.2, -0.05), "o")]
    for sx in (1, -1):
        for k in range(3):
            tronco.append(((0.04, 0.03, 0.04), (sx * 0.05, 0.205, 0.15 - k * 0.12), "o"))
    for (x, z, w) in ((0.0, 0.02, 0.20), (0.14, -0.14, 0.14), (-0.13, -0.12, 0.16)):
        tronco.append(((w, 0.04, w), (x, -0.215, z), "o"))
        tronco.append(((w * 0.5, 0.05, w * 0.5), (x, -0.22, z), "k"))
    sup, inf = _bracos("b")
    vestir("steampunk", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.07), (0, 0, -0.15), "k"), ((0.04, 0.04, 0.04), (0, 0.16, -0.15), "o")])
    limpar()
    la = mat("Latao", (0.72, 0.52, 0.18), 0.85, 0.4); vd = mat("Vidro", (0.55, 0.78, 0.92), 0.2, 0.1); cou = mat("Couro", (0.34, 0.18, 0.09), 0.0, 0.75); ou = mat("Ouro", (0.82, 0.62, 0.20), 0.85, 0.35)
    yf = P * 0.5 + 0.03
    p = []
    for sx in (1, -1):
        p += [caixa("Aro", (0.20, 0.07, 0.17), (sx * 0.115, yf, -0.07), la), caixa("Lente", (0.15, 0.075, 0.11), (sx * 0.115, yf + 0.004, -0.07), vd), caixa("Eng", (0.08, 0.05, 0.08), (sx * 0.20, yf, 0.02), ou),
              caixa("TiraL", (0.035, P + 0.02, 0.07), (sx * 0.267, 0, -0.07), cou)]
    p += [caixa("Ponte", (0.05, 0.05, 0.04), (0, yf, -0.07), la), caixa("TiraF", (0.53, 0.04, 0.07), (0, P * 0.5 + 0.005, -0.07), cou), caixa("TiraT", (0.53, 0.035, 0.07), (0, -P * 0.5 - 0.005, -0.07), cou)]
    exportar(p, "acessorios", "goggles_steampunk")


def mago_sombrio():
    mats = {"c": ("Casaco", (0.30, 0.10, 0.45), 0.0, 0.85), "o": ("Ouro", (0.82, 0.62, 0.22), 0.8, 0.4), "v": ("Vinco", (0.20, 0.06, 0.32), 0.0, 0.85), "g": ("Rosa", (0.72, 0.40, 0.90), 0.0, 0.3)}
    tronco = _tronco_aberto("c") + [((0.36, 0.34, 0.12), (0, 0, 0.29), "v"), ((0.58, 0.40, 0.06), (0, 0, -0.27), "o"), ((0.07, 0.04, 0.07), (0, 0.215, -0.27), "g"), ((0.09, 0.05, 0.09), (0, 0.205, 0.20), "g"),
              ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.44, 0.30, 0.10), (0, -0.15, 0.90), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "v"),
              ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"), ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"),
              ((0.11, 0.05, 0.05), (0.12, 0.25, 0.52), "g"), ((0.11, 0.05, 0.05), (-0.12, 0.25, 0.52), "g"), ((0.62, 0.04, 0.04), (0, 0.31, 0.76), "o")]
    for sx in (1, -1):
        tronco += [((0.16, 0.40, 0.04), (sx * 0.27, 0, 0.26), "v"), ((0.17, 0.41, 0.015), (sx * 0.27, 0, 0.285), "o")]
    sup, inf = _bracos("c")
    vestir("mago_sombrio", mats, tronco=tronco, saia=_saia_aberta("c", 0.80, -0.23) + [((0.59, 0.38, 0.04), (0, 0, -0.62), "o"), ((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "o"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "o"), ((0.06, 0.04, 0.16), (0.0, 0.21, -0.45), "g")],
           manga_sup=sup + [((0.31, 0.31, 0.04), (0, 0, -0.03), "o")], manga_inf=inf + [((0.34, 0.34, 0.12), (0, 0, -0.14), "v"), ((0.35, 0.35, 0.03), (0, 0, -0.20), "o")])


def druida():
    mats = {"c": ("Casaco", (0.28, 0.52, 0.22), 0.0, 0.85), "v": ("Vinco", (0.18, 0.36, 0.14), 0.0, 0.85), "b": ("Pelo", (0.93, 0.86, 0.70), 0.0, 0.95), "k": ("Couro", (0.38, 0.22, 0.10), 0.0, 0.8), "e": ("Espinho", (0.55, 0.78, 0.25), 0.0, 0.8)}
    tronco = _base("b") + [((0.64, 0.10, 0.54), (0, -0.30, 0.50), "v")] if False else _base("b")
    import random
    random.seed(24)
    for i in range(16):
        tronco.append(((random.uniform(0.07, 0.14), 0.04, random.uniform(0.07, 0.14)), (random.uniform(-0.24, 0.24), random.choice((0.2, -0.2)), random.uniform(-0.28, 0.20)), random.choice(("c", "v", "e"))))
    tronco += [((0.60, 0.42, 0.10), (0, 0, 0.27), "c"), ((0.64, 0.46, 0.06), (0, 0, 0.22), "v"), ((0.58, 0.40, 0.05), (0, 0, -0.27), "k"), ((0.08, 0.05, 0.08), (0, 0.215, -0.27), "e")]
    sup, inf = _bracos("b")
    saia = [((0.60, 0.40, 0.20), (0, 0, 0.08), "c")]
    for i in range(7):
        saia.append(((0.09, 0.44, random.uniform(0.25, 0.55)), (-0.27 + i * 0.09, 0, -0.12 - random.uniform(0.0, 0.2)), "c" if i % 2 else "b"))
    vestir("druida", mats, tronco=tronco, saia=saia, manga_sup=sup + [((0.08, 0.31, 0.10), (0.05, 0, -0.05), "c"), ((0.10, 0.31, 0.08), (-0.05, 0, -0.18), "e")], manga_inf=inf + [((0.31, 0.31, 0.04), (0, 0, -0.18), "k")])
    limpar()
    gal = mat("Galho", (0.35, 0.20, 0.10), 0.0, 0.9); fol = mat("Folha", (0.32, 0.65, 0.20), 0.0, 0.8)
    import math
    p = []
    for i in range(26):
        t = i / 26 * 2 * math.pi
        p.append(caixa_rot("Galho", (0.10, 0.045, 0.045), (0.272 * math.cos(t), 0.392 * math.sin(t), -0.02 + 0.015 * (i % 2)), gal, math.degrees(t) + 90 + (20 if i % 2 else -20)))
        if i % 2 == 0:
            p.append(caixa("Folha", (0.07, 0.04, 0.05), (0.29 * math.cos(t), 0.41 * math.sin(t), 0.02), fol))
    for k in range(5):
        p.append(caixa("Ramo%d" % k, (0.03, 0.03, 0.10 + 0.02 * k), (0.0, P * 0.5 + 0.02 - 0.0, 0.05 + k * 0.0), gal)) if False else None
    exportar(p, "acessorios", "coroa_galhos")


def pirata_sereia():
    mats = {"c": ("Casaco", (0.30, 0.50, 0.72), 0.0, 0.85), "t": ("Turquesa", (0.10, 0.62, 0.58), 0.0, 0.7), "k": ("Couro", (0.38, 0.22, 0.10), 0.0, 0.8), "b": ("Branco", (0.97, 0.94, 0.86), 0.0, 0.7), "o": ("Ouro", (0.90, 0.70, 0.30), 0.7, 0.4), "r": ("Rosa", (0.98, 0.74, 0.80), 0.0, 0.7)}
    tronco = [((0.52, 0.36, 0.40), (0, 0, 0.02), "c"), ((0.60, 0.40, 0.12), (0, 0, 0.14), "c"), ((0.30, 0.04, 0.14), (0, 0.19, 0.07), "k"), ((0.52, 0.37, 0.18), (0, 0, -0.18), "k"), ((0.02, 0.04, 0.18), (0.0, 0.205, -0.18), "b")]
    for k in range(8):
        tronco.append(((0.04, 0.04, 0.04), (-0.18 + k * 0.05, 0.2, 0.17 - 0.03 * (1 - (k - 3.5) ** 2 / 12)), "b"))
    tronco += [((0.07, 0.04, 0.07), (0.0, 0.205, 0.0), "r"), ((0.07, 0.04, 0.05), (0.14, 0.2, -0.04), "b")]
    saia = [((0.60, 0.40, 0.10), (0, 0, 0.12), "k")]
    for i, (w, z, m) in enumerate(((0.80, 0.0, "t"), (0.95, -0.14, "c"), (1.05, -0.28, "t"), (1.10, -0.42, "c"))):
        saia.append(((w, w * 0.72, 0.13), (0, 0, z), m))
    for x, z in ((-0.30, -0.10), (0.2, -0.25), (-0.1, -0.40), (0.35, -0.38)):
        saia.append(((0.08, 0.02, 0.08), (x, 0.36, z), "b"))
    vestir("pirata_sereia", mats, tronco=tronco, saia=saia, manga_sup=[((0.32, 0.32, 0.14), (0, 0, -0.05), "c"), ((0.34, 0.34, 0.04), (0, 0, -0.11), "b")], manga_inf=[((0.30, 0.30, 0.04), (0, 0, -0.04), "b")])


def leao():
    import random
    random.seed(99)
    mats = {"c": ("Casaco", (0.93, 0.62, 0.15), 0.0, 1.0), "v": ("Vinco", (0.72, 0.42, 0.08), 0.0, 1.0), "p": ("Pelo", (0.95, 0.80, 0.50), 0.0, 1.0), "k": ("Preto", (0.07, 0.05, 0.04), 0.0, 0.7)}
    tronco = _base("c") + [((0.28, 0.04, 0.46), (0, 0.19, -0.03), "p")]
    for i in range(46):
        a = random.uniform(0, 6.283); r = random.uniform(0.28, 0.42)
        import math
        t = random.uniform(0.10, 0.17)
        tronco.append(((t, t, t), (r * math.cos(a) * 0.9, r * math.sin(a) * 0.9 - 0.02, random.uniform(0.28, 0.80)), random.choice(("c", "v", "p"))))
    tronco += [((0.50, 0.12, 0.36), (0, 0.33, 0.55), "p"), ((0.30, 0.06, 0.20), (0, 0.40, 0.50), "p"), ((0.08, 0.05, 0.06), (0, 0.44, 0.52), "k")]
    cintura = [((0.53, 0.30, 0.15), (0, 0, 0.09), "c")]
    for i in range(5):
        cintura.append(((0.06, 0.06, 0.07), (0, -0.16 - i * 0.08, 0.05 - i * 0.08 + (0.04 if i > 2 else 0.0)), "c"))
    cintura += [((0.12, 0.12, 0.12), (0, -0.56, -0.28), "v")]
    sup, inf = _bracos("c")
    vestir("leao", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.30, 0.30, 0.05), (0, 0, -0.19), "p")], cintura=cintura, coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "p")])


def coelha_pascoa():
    mats = {"c": ("Casaco", (0.97, 0.94, 0.92), 0.0, 1.0), "r": ("Rosa", (0.98, 0.74, 0.82), 0.0, 0.9), "l": ("Cruz", (0.62, 0.55, 0.90), 0.0, 0.9), "a": ("Azul", (0.60, 0.80, 0.95), 0.0, 0.9), "y": ("Ouro", (0.98, 0.88, 0.45), 0.0, 0.9)}
    tronco = _base("c") + [((0.14, 0.05, 0.40), (0.0, 0.195, -0.04), "c"), ((0.16, 0.06, 0.08), (0, 0.22, 0.22), "r"), ((0.06, 0.06, 0.14), (0.05, 0.22, 0.12), "r"), ((0.06, 0.06, 0.14), (-0.05, 0.22, 0.12), "r"),
                           ((0.04, 0.04, 0.04), (0.0, 0.215, 0.0), "y"), ((0.04, 0.04, 0.04), (0.0, 0.215, -0.1), "y"), ((0.07, 0.04, 0.09), (0.15, 0.2, -0.20), "r"), ((0.07, 0.04, 0.09), (-0.15, 0.2, -0.22), "a")]
    tronco += [((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
               ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "r"), ((0.62, 0.09, 0.03), (0, 0.285, 0.70), "l")]
    for sx in (1, -1):
        for i in range(5):
            tronco.append(((0.11 - 0.005 * i, 0.07, 0.07), (sx * 0.14, -0.10, 0.90 + 0.07 * i), "c"))
        tronco.append(((0.06, 0.02, 0.26), (sx * 0.14, -0.07, 1.00), "r"))
    sup, inf = _bracos("c")
    vestir("coelha_pascoa", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "l")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.16, 0.16, 0.16), (0, -0.20, 0.0), "c")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.275, 0.275, 0.04), (0, 0, -0.20), "a"), ((0.275, 0.275, 0.04), (0, 0, -0.26), "r")], pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "c")])


def robo_retro():
    mats = {"c": ("Casaco", (0.62, 0.64, 0.68), 0.0, 0.6), "v": ("Vinco", (0.48, 0.50, 0.54), 0.0, 0.6), "r": ("Gravata", (0.85, 0.12, 0.14), 0.0, 0.5), "g": ("Espinho", (0.35, 0.78, 0.30), 0.0, 0.5), "y": ("Ouro", (0.98, 0.82, 0.18), 0.0, 0.5),
            "a": ("Azul", (0.15, 0.40, 0.90), 0.0, 0.5), "k": ("Preto", (0.08, 0.08, 0.10), 0.0, 0.6)}
    tronco = _base("c") + [((0.40, 0.05, 0.30), (0, 0.205, 0.04), "v"), ((0.12, 0.06, 0.10), (-0.08, 0.225, 0.08), "k"), ((0.04, 0.07, 0.04), (0.08, 0.23, 0.10), "g"), ((0.04, 0.07, 0.04), (0.14, 0.23, 0.10), "r"),
                           ((0.04, 0.07, 0.04), (0.08, 0.23, 0.02), "y"), ((0.04, 0.07, 0.04), (0.14, 0.23, 0.02), "a"), ((0.50, 0.12, 0.40), (0, -0.25, 0.0), "v"), ((0.30, 0.02, 0.16), (0, -0.32, 0.04), "k"),
                           ((0.40, 0.40, 0.44), (0, 0, 0.30 + 0.35), "c")]
    tronco += [((0.50, 0.50, 0.40), (0, 0, 0.60), "c"), ((0.46, 0.04, 0.30), (0, 0.27, 0.60), "k"), ((0.09, 0.03, 0.09), (-0.10, 0.285, 0.64), "g"), ((0.09, 0.03, 0.09), (0.10, 0.285, 0.64), "g"),
               ((0.34, 0.03, 0.05), (0, 0.285, 0.52), "v"), ((0.04, 0.04, 0.12), (0.12, 0.0, 0.86), "k"), ((0.04, 0.04, 0.12), (-0.12, 0.0, 0.86), "k"), ((0.08, 0.08, 0.06), (0.12, 0.0, 0.94), "r"), ((0.08, 0.08, 0.06), (-0.12, 0.0, 0.94), "r"),
               ((0.10, 0.20, 0.14), (0.30, 0.0, 0.60), "v"), ((0.10, 0.20, 0.14), (-0.30, 0.0, 0.60), "v")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + [((0.31, 0.31, 0.06), (0, 0, -0.06 - 0.07 * k), "v") for k in range(3)]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c")] + [((0.30, 0.30, 0.05), (0, 0, -0.06 - 0.06 * k), "v") for k in range(2)]
    vestir("robo_retro", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.27, 0.27, 0.05), (0, 0, -0.10), "v")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.27, 0.27, 0.05), (0, 0, -0.06), "v"), ((0.27, 0.27, 0.05), (0, 0, -0.18), "v")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "v")])


def esqueleto():
    mats = {"c": ("Casaco", (0.06, 0.06, 0.08), 0.0, 0.85), "b": ("Branco", (0.96, 0.96, 0.94), 0.0, 0.7)}
    tronco = _base("c") + [((0.04, 0.03, 0.46), (0, 0.19, -0.02), "b"), ((0.03, 0.04, 0.46), (0, -0.19, -0.02), "b")]
    for k in range(5):
        w = 0.30 - 0.025 * k
        tronco.append(((w, 0.03, 0.035), (0, 0.19, 0.15 - 0.075 * k), "b")); tronco.append(((w, 0.03, 0.035), (0, -0.19, 0.15 - 0.075 * k), "b"))
    tronco += [((0.46, 0.03, 0.04), (0, 0.19, 0.25), "b"), ((0.12, 0.03, 0.12), (0, 0.19, 0.30 - 0.0), "b")]
    vestir("esqueleto", mats, tronco=tronco, manga_sup=[(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.05, 0.03, 0.32), (0, 0.15, -0.15), "b"), ((0.08, 0.03, 0.06), (0, 0.15, -0.31), "b")],
           manga_inf=[(MANGA_INF[0], MANGA_INF[1], "c"), ((0.05, 0.03, 0.18), (0, 0.15, -0.105), "b"), ((0.08, 0.03, 0.05), (0, 0.15, -0.20), "b")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.36, 0.03, 0.10), (0, 0.155, 0.07), "b"), ((0.04, 0.03, 0.12), (0, 0.155, 0.0), "b")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c"), ((0.06, 0.03, 0.32), (0, 0.135, -0.18), "b"), ((0.10, 0.03, 0.06), (0, 0.135, -0.35), "b")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.05, 0.03, 0.24), (0, 0.135, -0.14), "b"), ((0.09, 0.03, 0.05), (0, 0.135, -0.26), "b")],
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "c"), ((0.04, 0.03, 0.05), (0.06, 0.17, -0.04), "b"), ((0.04, 0.03, 0.05), (-0.06, 0.17, -0.04), "b")])


def mumia():
    import random
    random.seed(4)
    mats = {"c": ("Casaco", (0.90, 0.80, 0.58), 0.0, 0.95), "v": ("Vinco", (0.76, 0.66, 0.46), 0.0, 0.95)}
    def faixas(cx, w, d, z0, z1, n):
        out = []
        for i in range(n):
            z = z0 + (z1 - z0) * i / (n - 1)
            out.append(((w + 0.015, d + 0.015, (z1 - z0) / n * 1.3), (0, 0, z), "c" if i % 2 == 0 else "v"))
            out.append(((0.07, d + 0.02, 0.05), (random.uniform(-w * 0.4, w * 0.4), 0, z), "v"))
        return out
    tronco = _base("c") + faixas(0, 0.545, 0.365, -0.30, 0.22, 9)
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + faixas(0, 0.29, 0.29, -0.30, 0.0, 5)
    inf = [(MANGA_INF[0], MANGA_INF[1], "c")] + faixas(0, 0.285, 0.285, -0.20, 0.0, 4)
    vestir("mumia", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")] + faixas(0, 0.53, 0.30, 0.02, 0.16, 3),
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")] + faixas(0, 0.26, 0.26, -0.34, -0.02, 7), canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")] + faixas(0, 0.26, 0.26, -0.26, -0.02, 6),
           pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "c")])
    limpar()
    c = mat("Casaco", (0.90, 0.80, 0.58), 0.0, 0.95); v = mat("Vinco", (0.76, 0.66, 0.46), 0.0, 0.95)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), c)]
    for k in range(9):
        z = -0.40 + k * 0.05
        p.append(caixa("Faixa%d" % k, (larg + 0.01 * (k % 2), prof + 0.01 * (k % 2), 0.055), (0, 0, z + 0.05), c if k % 2 == 0 else v))
    p.append(caixa("Vao", (0.3, 0.02, 0.01), (0, prof * 0.5 + 0.02, -0.1), v)) if False else None
    exportar([x for x in p if x is not None and x.name != "Faixa4" and x.name != "Faixa5"], "acessorios", "ataduras_cabeca")


def rei_mares():
    limpar()
    az = mat("CapaAzul", (0.08, 0.16, 0.55), 0.0, 0.8); pr = mat("Prata", (0.80, 0.84, 0.90), 0.8, 0.3); ci = mat("CiaAzul", (0.45, 0.70, 0.92), 0.2, 0.3)
    p = [caixa("Gola", (0.50, 0.14, 0.14), (0, -0.19, 0.06), pr), caixa("Manto", (0.94, 0.54, 0.10), (0, -0.07, -0.12), az), caixa("MantoBorda", (0.98, 0.58, 0.03), (0, -0.07, -0.18), pr), caixa("Gema", (0.06, 0.04, 0.06), (0, 0.16, -0.02), ci)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.96, 1.04, 1.12]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), az))
        z -= 0.22
    p.append(caixa("Barra", (1.14, 0.07, 0.06), (0, -0.25, z + 0.03), pr))
    for k in range(4):
        p.append(caixa("Onda%d" % k, (0.14, 0.06, 0.03), (-0.4 + k * 0.27, -0.285, -1.05 + 0.0), pr)); p.append(caixa("OndaC%d" % k, (0.08, 0.06, 0.08), (-0.4 + k * 0.27, -0.285, -0.98), pr))
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.90), (sx * 0.46, -0.07, -0.62), az)); p.append(caixa("PanoBorda", (0.055, 0.04, 0.90), (sx * 0.46, 0.13, -0.62), pr))
        p.append(caixa("Ombro", (0.12, 0.30, 0.04), (sx * 0.38, 0.0, -0.08), pr)); p.append(caixa("Pedra", (0.05, 0.04, 0.05), (sx * 0.38, 0.17, -0.08), ci))
    for k in range(6):
        p.append(caixa("Linha", (0.03, 0.012, 0.10), (0.0, -0.285, -0.2 - k * 0.14), pr))
    exportar(p, "acessorios", "manto_ondas")
    limpar()
    co = mat("Coral", (0.92, 0.35, 0.28), 0.0, 0.7); cl = mat("CoralClaro", (0.98, 0.78, 0.60), 0.0, 0.7); ou = mat("Ouro", (0.92, 0.74, 0.30), 0.85, 0.35); pe = mat("Perola", (0.98, 0.96, 0.94), 0.3, 0.2)
    p = [caixa("Aro", (0.54, P + 0.04, 0.10), (0, 0, 0.02), ou), caixa("PerolaC", (0.07, 0.04, 0.07), (0, P * 0.5 + 0.03, 0.02), pe)]
    for k, (x, y, h) in enumerate(((0.0, 0.34, 0.22), (-0.14, 0.34, 0.16), (0.14, 0.34, 0.16), (-0.24, 0.1, 0.18), (0.24, 0.1, 0.18), (-0.20, -0.2, 0.20), (0.20, -0.2, 0.20), (0.0, -0.34, 0.22))):
        p.append(caixa("Ramo%d" % k, (0.05, 0.05, h), (x, y, 0.07 + h * 0.5), co)); p.append(caixa("Ponta%d" % k, (0.07, 0.07, 0.05), (x, y, 0.07 + h + 0.0), cl))
        p.append(caixa("Galho%d" % k, (0.04, 0.04, 0.08), (x + (0.04 if x >= 0 else -0.04), y, 0.07 + h * 0.7), co))
    exportar(p, "acessorios", "coroa_coral")


def cabelo_chonmage():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L, P, 0.05), (0, 0, -0.025), cab), caixa("Nuca", (L, 0.07, 0.22), (0, -(P * 0.5 - 0.035), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.05, P * 0.62, 0.20), (sx * (L * 0.5 - 0.025), -P * 0.12, -0.10), cab))
    p += [caixa("Franja", (L * 0.9, 0.05, 0.06), (0, P * 0.5 - 0.02, -0.03), cab), caixa("Base", (0.14, 0.12, 0.10), (0, -0.12, 0.08), cab), caixa("Rabo", (0.10, 0.18, 0.08), (0, 0.0, 0.14), cab),
          caixa("Ponta", (0.12, 0.12, 0.08), (0, 0.10, 0.20), cab), caixa("Elo", (0.16, 0.14, 0.03), (0, -0.12, 0.05), mat("Fita", (0.85, 0.85, 0.85), 0.0, 0.8))]
    exportar(p, "cabelos", "cabelo_chonmage")


def barba_curta():
    limpar()
    pelo = mat("Barba", (0.22, 0.14, 0.09), 0.0, 0.95)
    p = [caixa("Queixo", (0.44, 0.06, 0.12), (0, 0.03, -0.20), pelo), caixa("QueixoBaixo", (0.34, 0.07, 0.06), (0, 0.035, -0.26), pelo), caixa("Bigode", (0.26, 0.05, 0.045), (0, 0.05, -0.095), pelo)]
    for sx in (1, -1):
        p.append(caixa("Costeleta", (0.04, 0.26, 0.20), (sx * 0.27, -0.13, -0.10), pelo))
    exportar(p, "acessorios", "barba_curta")


def peruca_barroca():
    import random, math
    limpar()
    random.seed(32)
    br = mat("Peruca", (0.96, 0.94, 0.92), 0.0, 0.95); ro = mat("Rosa", (0.88, 0.62, 0.68), 0.0, 0.8); pe = mat("Perola", (0.98, 0.96, 0.94), 0.3, 0.2)
    p = [caixa("Calota", (L + 0.04, P + 0.04, 0.12), (0, 0, -0.04), br), caixa("Franja", (L + 0.04, 0.10, 0.20), (0, P * 0.5 - 0.0, -0.10), br)]
    for i in range(60):
        a = random.uniform(0, 6.283); r = random.uniform(0.25, 0.40)
        t = random.uniform(0.12, 0.18)
        p.append(caixa("Cacho", (t, t, t), (r * math.cos(a) * 0.85, r * math.sin(a) * 0.95 - 0.04, random.uniform(0.02, 0.40)), br))
    for sx in (1, -1):
        for j in range(6):
            p.append(caixa("CachoL", (0.14, 0.14, 0.14), (sx * 0.33, -0.1 + j * 0.0 + (0.05 if j % 2 else 0.0), -0.05 - j * 0.12), br))
        p.append(caixa("Laco", (0.14, 0.06, 0.12), (sx * 0.34, 0.14, 0.12), ro)); p.append(caixa("LacoNo", (0.05, 0.07, 0.05), (sx * 0.34, 0.14, 0.12), ro))
    p += [caixa("Concha", (0.18, 0.05, 0.14), (0, 0.10, 0.45), pe), caixa("LacoTopo", (0.22, 0.06, 0.10), (0, -0.1, 0.46), ro)]
    for i in range(10):
        p.append(caixa("Costas", (0.52, 0.12, 0.11), (0, -(P * 0.5 + 0.03), -0.05 - i * 0.12), br))
    exportar(p, "acessorios", "peruca_barroca")


def cabelo_spiky_curto():
    import random, math
    limpar()
    random.seed(61)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L, P, 0.12), (0, 0, -0.06), cab), caixa("Nuca", (L, 0.10, 0.22), (0, -(P * 0.5 - 0.05), -0.11), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.06, P * 0.6, 0.20), (sx * (L * 0.5 - 0.03), -P * 0.10, -0.10), cab))
    for k in range(16):
        a = random.uniform(0, 6.283); r = random.uniform(0.0, 0.30)
        x, y = r * math.cos(a) * 0.8, r * math.sin(a) * 1.1
        dx, dy = (math.cos(a) * 0.6, math.sin(a) * 0.6)
        for j, w in enumerate((0.15, 0.12, 0.09, 0.06)):
            t = 0.04 + 0.05 * j
            p.append(caixa("Espeto%d_%d" % (k, j), (w, w, w), (x + dx * t, y + dy * t, 0.02 + t * 1.2), cab))
    for k in range(7):
        p.append(caixa("Franja%d" % k, (0.08, 0.07, random.uniform(0.10, 0.2)), (-0.2 + k * 0.067, P * 0.5 - 0.03, -0.07), cab))
    exportar(p, "cabelos", "cabelo_spiky_curto")
    limpar()
    pr = mat("Prata", (0.80, 0.82, 0.86), 0.9, 0.25)
    exportar([caixa("Argola", (0.035, 0.03, 0.035), (0.07, P * 0.5 + 0.012, -0.28), pr), caixa("Brinco", (0.03, 0.03, 0.03), (-0.26, 0.0, -0.24), pr)], "acessorios", "piercing_prata")


def cabelo_odango():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Franja", (L + 0.02, 0.08, 0.20), (0, P * 0.5 - 0.005, -0.10), cab), caixa("Costas", (L + 0.03, 0.13, 1.05), (0, -(P * 0.5 - 0.05), -0.52), cab),
         caixa("CostasBaixo", (L * 0.9, 0.12, 0.08), (0, -(P * 0.5 - 0.05), -1.08), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.62, 0.8), (sx * (L * 0.5 + 0.02), -P * 0.12, -0.40), cab))
        p.append(caixa("Mecha", (0.09, 0.10, 0.72), (sx * (L * 0.5 + 0.02), P * 0.5 - 0.08, -0.38), cab))
        p.append(caixa("OdangoBase", (0.20, 0.20, 0.10), (sx * 0.22, -0.02, 0.07), cab)); p.append(caixa("Odango", (0.28, 0.28, 0.24), (sx * 0.24, -0.02, 0.18), cab)); p.append(caixa("OdangoTopo", (0.20, 0.20, 0.08), (sx * 0.24, -0.02, 0.32), cab))
    exportar(p, "cabelos", "cabelo_odango")


def cabelo_rabo_lateral():
    import random
    limpar()
    random.seed(77)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.92)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.92, P * 0.86, 0.06), (0, -0.01, 0.035), cab), caixa("Nuca", (L + 0.02, 0.12, 0.30), (0, -(P * 0.5 - 0.05), -0.15), cab)]
    for i in range(9):
        p.append(caixa("Franja", (0.07, 0.08, random.uniform(0.12, 0.22)), (-0.24 + i * 0.062, P * 0.5 - 0.005, -0.07), cab))
    p.append(caixa("Lado", (0.08, P * 0.6, 0.26), (-(L * 0.5 + 0.0), -P * 0.12, -0.13), cab))
    p.append(caixa("LadoD", (0.08, P * 0.6, 0.26), ((L * 0.5 + 0.0), -P * 0.12, -0.13), cab))
    p.append(caixa("Elo", (0.12, 0.14, 0.05), (L * 0.5 + 0.08, -0.05, 0.06), mat("Fita", (0.80, 0.78, 0.76), 0.0, 0.8)))
    for i, (x, y, z, w) in enumerate(((0.40, -0.05, 0.0, 0.16), (0.46, -0.07, -0.12, 0.17), (0.50, -0.10, -0.26, 0.16), (0.50, -0.14, -0.40, 0.13), (0.46, -0.18, -0.52, 0.09))):
        p.append(caixa("Rabo%d" % i, (w, w + 0.02, 0.14), (x, y, z), cab))
    exportar(p, "cabelos", "cabelo_rabo_lateral")


# ======================================================================= lote 12
def mecanico_espacial():
    mats = {"c": ("Casaco", (0.96, 0.46, 0.08), 0.0, 0.75), "v": ("Vinco", (0.78, 0.34, 0.05), 0.0, 0.8), "k": ("Preto", (0.08, 0.08, 0.10), 0.0, 0.7), "r": ("Prata", (0.86, 0.88, 0.92), 0.5, 0.3),
            "y": ("Ouro", (0.98, 0.82, 0.18), 0.0, 0.5)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "k"), ((0.575, 0.385, 0.04), (0, 0, 0.10), "r"), ((0.575, 0.385, 0.04), (0, 0, -0.14), "r"),
                           ((0.12, 0.05, 0.12), (0.15, 0.2, 0.0), "v"), ((0.12, 0.05, 0.12), (-0.15, 0.2, -0.03), "v"), ((0.50, 0.14, 0.34), (0, -0.22, 0.02), "k")]
    for sx in (1, -1):
        tronco += [((0.06, 0.40, 0.03), (sx * 0.12, 0, 0.255), "k"), ((0.06, 0.04, 0.48), (sx * 0.12, 0.205, 0.02), "k"), ((0.06, 0.04, 0.48), (sx * 0.12, -0.205, 0.0), "k"), ((0.05, 0.05, 0.05), (sx * 0.12, 0.23, 0.24), "y")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.30, 0.30, 0.04), (0, 0, -0.12), "r")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.30, 0.30, 0.04), (0, 0, -0.10), "r"), ((0.31, 0.31, 0.05), (0, 0, -0.19), "k")]
    cint = [((0.53, 0.30, 0.15), (0, 0, 0.09), "c"), ((0.57, 0.32, 0.05), (0, 0, 0.12), "k"), ((0.10, 0.04, 0.07), (0, 0.17, 0.12), "y")]
    for sx in (1, -1):
        cint += [((0.10, 0.12, 0.14), (sx * 0.31, 0.04, 0.0), "k"), ((0.025, 0.03, 0.16), (sx * 0.29, 0.14, -0.02), "r")]
    vestir("mecanico_espacial", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=cint,
           coxa=[((0.28, 0.28, 0.36), (0, 0, -0.18), "c"), ((0.29, 0.29, 0.04), (0, 0, -0.20), "r"), ((0.10, 0.05, 0.12), (0.12, 0.15, -0.10), "k")],
           canela=[((0.28, 0.28, 0.285), (0, 0, -0.1425), "c"), ((0.29, 0.29, 0.04), (0, 0, -0.10), "r"), ((0.29, 0.29, 0.06), (0, 0, -0.24), "k")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.98), 0.0, 0.5); la = mat("Laranja", (0.96, 0.46, 0.08), 0.0, 0.5); am = mat("Ouro", (0.98, 0.82, 0.18), 0.0, 0.5); pr = mat("Preto", (0.08, 0.08, 0.10), 0.0, 0.6)
    p = [caixa("Topo", (0.62, 0.86, 0.10), (0, 0, 0.05), br), caixa("Tras", (0.62, 0.10, 0.50), (0, -0.42, -0.20), br), caixa("Faixa", (0.12, 0.88, 0.11), (0, 0, 0.06), la), caixa("Brim", (0.62, 0.10, 0.14), (0, 0.42, -0.03), br),
         caixa("Visor", (0.50, 0.06, 0.08), (0, 0.44, -0.12), pr)]
    for sx in (1, -1):
        p += [caixa("Lado", (0.10, 0.86, 0.50), (sx * 0.31, 0, -0.20), br), caixa("Concha", (0.10, 0.26, 0.26), (sx * 0.36, -0.02, -0.28), am), caixa("ConchaP", (0.11, 0.18, 0.18), (sx * 0.365, -0.02, -0.28), pr)]
    exportar(p, "acessorios", "capacete_mecanico")


def aviador():
    mats = {"c": ("Casaco", (0.38, 0.20, 0.10), 0.0, 0.75), "p": ("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0), "v": ("Vinco", (0.26, 0.14, 0.07), 0.0, 0.8), "o": ("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)}
    tronco = _base("c") + [((0.62, 0.44, 0.10), (0, 0, 0.28), "p"), ((0.20, 0.10, 0.18), (0.18, 0.21, 0.18), "p"), ((0.20, 0.10, 0.18), (-0.18, 0.21, 0.18), "p"), ((0.62, 0.42, 0.06), (0, 0, -0.30), "v"),
                           ((0.03, 0.04, 0.46), (0, 0.195, -0.02), "o"), ((0.13, 0.05, 0.12), (0.15, 0.2, -0.12), "v"), ((0.13, 0.05, 0.12), (-0.15, 0.2, -0.12), "v"), ((0.58, 0.04, 0.04), (0, 0.205, -0.27), "v"), ((0.07, 0.05, 0.06), (0, 0.22, -0.27), "o")]
    sup, inf = _bracos("c")
    vestir("aviador", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.33, 0.33, 0.08), (0, 0, -0.17), "p")])
    limpar()
    co = mat("Couro", (0.38, 0.20, 0.10), 0.0, 0.7); es = mat("CouroEscuro", (0.24, 0.12, 0.06), 0.0, 0.7); la = mat("Latao", (0.72, 0.52, 0.18), 0.85, 0.4); vd = mat("Vidro", (0.55, 0.78, 0.92), 0.2, 0.1); pe = mat("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), co), caixa("Tras", (larg, 0.08, 0.54), (0, -prof * 0.5 + 0.04, -0.23), co), caixa("Costura", (0.04, prof, 0.05), (0, 0, 0.10), es),
         caixa("Brim", (larg, 0.08, 0.09), (0, prof * 0.5 - 0.04, -0.01), co), caixa("Queixo", (larg - 0.04, 0.06, 0.07), (0, prof * 0.5 - 0.03, -0.50), pe)]
    for sx in (1, -1):
        p += [caixa("Lado", (0.08, prof, 0.54), (sx * (larg * 0.5 - 0.04), 0, -0.23), co), caixa("Orelha", (0.10, 0.20, 0.20), (sx * (larg * 0.5), -0.02, -0.24), es), caixa("Bochecha", (0.09, 0.10, 0.30), (sx * (larg * 0.5 - 0.04), prof * 0.5 - 0.05, -0.32), pe)]
        p += [caixa("Aro", (0.20, 0.07, 0.17), (sx * 0.115, prof * 0.5 + 0.03, 0.05), la), caixa("Lente", (0.15, 0.075, 0.11), (sx * 0.115, prof * 0.5 + 0.034, 0.05), vd)]
    p.append(caixa("Ponte", (0.05, 0.05, 0.04), (0, prof * 0.5 + 0.03, 0.05), la))
    exportar(p, "acessorios", "capacete_aviador")


def jardineiro():
    limpar()
    ve = mat("Verde", (0.28, 0.50, 0.20), 0.0, 0.85); es = mat("VerdeEscuro", (0.18, 0.36, 0.13), 0.0, 0.85); pr = mat("Prata", (0.80, 0.82, 0.86), 0.9, 0.3); mad = mat("Madeira", (0.55, 0.32, 0.14), 0.0, 0.7)
    p = [caixa("Peito", (0.30, 0.04, 0.26), (0, 0.205, 0.10), ve), caixa("Saia", (0.50, 0.04, 0.50), (0, 0.205, -0.20), ve), caixa("Bolso", (0.36, 0.05, 0.16), (0, 0.22, -0.18), es), caixa("Cinta", (0.58, 0.40, 0.04), (0, 0, -0.04), es),
         caixa("Laco", (0.18, 0.06, 0.10), (0, -0.215, -0.04), ve), caixa("LacoT1", (0.06, 0.05, 0.24), (0.05, -0.215, -0.22), ve), caixa("LacoT2", (0.06, 0.05, 0.22), (-0.05, -0.215, -0.20), ve),
         caixa("Pa", (0.03, 0.03, 0.14), (-0.07, 0.25, -0.12), mad), caixa("PaFerro", (0.06, 0.03, 0.05), (-0.07, 0.25, -0.20), pr), caixa("Tesoura", (0.02, 0.03, 0.14), (0.0, 0.25, -0.12), pr), caixa("Muda", (0.05, 0.03, 0.10), (0.09, 0.25, -0.13), ve)]
    for sx in (1, -1):
        p.append(caixa("Alca", (0.05, 0.04, 0.30), (sx * 0.12, 0.205, 0.17), ve)); p.append(caixa("AlcaO", (0.05, 0.40, 0.03), (sx * 0.12, 0, 0.255), ve)); p.append(caixa("AlcaT", (0.05, 0.03, 0.46), (sx * 0.12, -0.195, 0.02), ve))
    exportar(p, "acessorios", "avental_jardineiro")
    limpar()
    pa = mat("Palha", (0.92, 0.76, 0.34), 0.0, 0.95); fi = mat("Fita", (0.22, 0.42, 0.16), 0.0, 0.8)
    exportar([caixa("Aba", (0.92, 1.06, 0.035), (0, 0, 0.0), pa), caixa("Aba2", (0.76, 0.90, 0.03), (0, 0, 0.03), pa), caixa("Copa", (0.50, 0.66, 0.15), (0, 0, 0.10), pa), caixa("CopaTopo", (0.44, 0.60, 0.03), (0, 0, 0.19), pa),
              caixa("Fita", (0.52, 0.68, 0.05), (0, 0, 0.065), fi)], "acessorios", "chapeu_jardineiro")
    limpar()
    pe = mat("Pele", (0.85, 0.70, 0.45), 0.0, 0.8); co = mat("Couro", (0.40, 0.24, 0.10), 0.0, 0.75)
    exportar([caixa("Punho", (0.26, 0.26, 0.07), (0, 0, 0.04), co), caixa("Palma", (0.21, 0.16, 0.11), (0, 0, -0.055), pe), caixa("Dedos", (0.20, 0.15, 0.05), (0, 0, -0.13), pe)], "acessorios", "luvas_jardim")


def avental_branco():
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9); sb = mat("Sombra", (0.84, 0.85, 0.88), 0.0, 0.9)
    p = [caixa("Peito", (0.28, 0.04, 0.26), (0, 0.205, 0.10), br), caixa("Saia", (0.50, 0.04, 0.60), (0, 0.205, -0.22), br), caixa("Bolso", (0.26, 0.05, 0.14), (0, 0.22, -0.20), sb), caixa("Cinta", (0.58, 0.40, 0.04), (0, 0, -0.04), br),
         caixa("Laco", (0.16, 0.06, 0.10), (0, -0.215, -0.04), br), caixa("T1", (0.06, 0.05, 0.28), (0.05, -0.215, -0.24), br), caixa("T2", (0.06, 0.05, 0.26), (-0.05, -0.215, -0.22), br)]
    for sx in (1, -1):
        p += [caixa("Alca", (0.05, 0.04, 0.30), (sx * 0.12, 0.205, 0.17), br), caixa("AlcaO", (0.05, 0.40, 0.03), (sx * 0.12, 0, 0.255), br), caixa("AlcaT", (0.05, 0.03, 0.46), (sx * 0.12, -0.195, 0.02), br)]
    exportar(p, "acessorios", "avental_branco")


def pintor():
    import random
    random.seed(31)
    mats = {"c": ("Casaco", (0.93, 0.88, 0.76), 0.0, 0.9), "v": ("Vinco", (0.78, 0.72, 0.60), 0.0, 0.9), "r": ("Gravata", (0.85, 0.15, 0.20), 0.0, 0.7), "a": ("Azul", (0.15, 0.40, 0.90), 0.0, 0.7), "y": ("Ouro", (0.98, 0.82, 0.18), 0.0, 0.7),
            "g": ("Espinho", (0.40, 0.78, 0.30), 0.0, 0.7), "z": ("Rosa", (0.75, 0.40, 0.85), 0.0, 0.7)}
    def manchas(n, w, d, z0, z1):
        out = []
        for i in range(n):
            out.append(((random.uniform(0.03, 0.07), 0.01, random.uniform(0.03, 0.07)), (random.uniform(-w / 2, w / 2), d / 2 + 0.006, random.uniform(z0, z1)), random.choice(("r", "a", "y", "g", "z"))))
        return out
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "v"), ((0.13, 0.05, 0.12), (0.15, 0.2, -0.05), "v"), ((0.13, 0.05, 0.12), (-0.15, 0.2, -0.05), "v"), ((0.575, 0.385, 0.04), (0, 0, -0.30), "v")] + manchas(16, 0.50, 0.37, -0.28, 0.22)
    sup, inf = _bracos("c")
    vestir("pintor", mats, tronco=tronco, manga_sup=sup + manchas(4, 0.26, 0.29, -0.3, 0.0), manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v")] + manchas(3, 0.24, 0.285, -0.2, 0.0),
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.27, 0.27, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.04, 0.10), (0.1, 0.14, -0.12), "v")] + manchas(5, 0.22, 0.27, -0.34, -0.02),
           canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "c"), ((0.28, 0.28, 0.04), (0, 0, -0.26), "v")] + manchas(3, 0.22, 0.27, -0.25, -0.02), pe=[((0.28, 0.33, 0.10), (0, 0, -0.05), "v")])
    limpar()
    ve = mat("Boina", (0.55, 0.10, 0.20), 0.0, 0.95)
    exportar([caixa("Faixa", (0.52, 0.70, 0.04), (0, 0, 0.0), ve), caixa("Disco", (0.64, 0.84, 0.07), (0.04, 0.0, 0.055), ve), caixa("Topo", (0.52, 0.68, 0.05), (0.06, 0.0, 0.115), ve), caixa("Cabo", (0.045, 0.045, 0.06), (0.06, 0.0, 0.17), ve)], "acessorios", "boina_bordo")
    limpar()
    mad = mat("Madeira", (0.62, 0.38, 0.16), 0.0, 0.7)
    cores = [(0.85, 0.15, 0.20), (0.15, 0.40, 0.90), (0.98, 0.82, 0.18), (0.40, 0.78, 0.30), (0.75, 0.40, 0.85)]
    p = [caixa("Paleta", (0.06, 0.26, 0.30), (0.0, 0.08, -0.22), mad), caixa("Cabo", (0.04, 0.05, 0.08), (0, 0.0, -0.10), mad)]
    for k, c in enumerate(cores):
        p.append(caixa("Tinta%d" % k, (0.04, 0.06, 0.06), (0.04, 0.0 + 0.05 * (k % 3), -0.14 - 0.06 * (k // 3 + k % 2)), mat("Tinta%d" % k, c, 0.0, 0.5)))
    exportar(p, "acessorios", "paleta_tinta")


def carteiro():
    limpar()
    az = mat("Azul", (0.12, 0.22, 0.62), 0.0, 0.8); ou = mat("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)
    exportar([caixa("Copa", (0.56, 0.78, 0.16), (0, 0, 0.08), az), caixa("Topo", (0.50, 0.70, 0.04), (0, 0, 0.18), az), caixa("Faixa", (0.58, 0.80, 0.035), (0, 0, 0.035), ou), caixa("Visor", (0.40, 0.24, 0.03), (0, P * 0.5 + 0.10, 0.0), pr),
              caixa("Emblema", (0.10, 0.03, 0.08), (0, P * 0.5 + 0.02, 0.10), ou)], "acessorios", "bone_carteiro")
    limpar()
    co = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.7); es = mat("CouroEscuro", (0.26, 0.14, 0.07), 0.0, 0.7); ouro = mat("Ouro", (0.88, 0.68, 0.20), 0.8, 0.4)
    p = [osso("Alca", (0.22, 0.20, 0.25), (-0.26, 0.20, -0.22), 0.05, es), osso("AlcaT", (0.22, -0.20, 0.25), (-0.26, -0.20, -0.22), 0.05, es), caixa("AlcaO", (0.06, 0.40, 0.03), (0.2, 0, 0.255), es),
         caixa("Bolsa", (0.26, 0.12, 0.22), (-0.30, 0.10, -0.32), co), caixa("Aba", (0.27, 0.13, 0.08), (-0.30, 0.10, -0.23), es), caixa("Fecho", (0.05, 0.14, 0.05), (-0.30, 0.10, -0.26), ouro)]
    exportar(p, "acessorios", "bolsa_carteiro")


def garcom():
    mats = {"c": ("Branco", (0.96, 0.96, 0.98), 0.0, 0.9), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.8), "v": ("Vinco", (0.82, 0.83, 0.87), 0.0, 0.9)}
    tronco = _base("c") + [((0.50, 0.04, 0.46), (0, 0.19, -0.02), "k"), ((0.50, 0.04, 0.46), (0, -0.19, -0.02), "k"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "c"), ((0.12, 0.06, 0.06), (0, 0.22, 0.22), "k"),
                           ((0.40, 0.04, 0.04), (0, 0.19, 0.22), "k"), ((0.025, 0.05, 0.30), (0.0, 0.215, -0.02), "v")]
    for sx in (1, -1):
        tronco += [((0.08, 0.38, 0.03), (sx * 0.14, 0, 0.255), "k"), ((0.58, 0.04, 0.04), (0, -0.2, -0.22), "k")]
    sup, inf = _bracos("c")
    vestir("garcom", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.33, 0.33, 0.07), (0, 0, -0.17), "v")], saia=[((0.40, 0.04, 0.34), (0, 0.205, -0.10), "c"), ((0.42, 0.045, 0.04), (0, 0.205, 0.07), "v")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "k")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "k")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "k")], pe=[((0.28, 0.33, 0.11), (0, 0, -0.05), "k")])


def caminhoneiro():
    mats = {"c": ("Casaco", (0.16, 0.30, 0.58), 0.0, 0.85), "v": ("Vinco", (0.10, 0.20, 0.42), 0.0, 0.85), "o": ("Ouro", (0.90, 0.72, 0.22), 0.8, 0.4), "k": ("Couro", (0.38, 0.22, 0.10), 0.0, 0.75), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.3)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "v"), ((0.14, 0.05, 0.13), (0.14, 0.2, 0.05), "v"), ((0.14, 0.05, 0.13), (-0.14, 0.2, 0.05), "v"),
                           ((0.58, 0.40, 0.06), (0, 0, -0.28), "k"), ((0.16, 0.06, 0.09), (0, 0.22, -0.28), "o"), ((0.10, 0.07, 0.05), (0, 0.225, -0.28), "p")]
    for sx in (1, -1):
        for k in range(2):
            tronco.append(((0.03, 0.03, 0.03), (sx * 0.14, 0.23, 0.07 - k * 0.0), "p")) if False else None
    sup, inf = _bracos("c")
    vestir("caminhoneiro", mats, tronco=tronco, manga_sup=sup + [((0.03, 0.03, 0.03), (0.11, 0.15, 0.0), "p")], manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v"), ((0.035, 0.035, 0.035), (0, 0.15, -0.18), "p")])
    limpar()
    az = mat("Azul", (0.16, 0.30, 0.58), 0.0, 0.85); be = mat("Boné", (0.86, 0.78, 0.60), 0.0, 0.9); es = mat("BoneSombra", (0.10, 0.20, 0.42), 0.0, 0.85)
    exportar([caixa("Copa", (0.54, 0.76, 0.16), (0, 0, 0.08), az), caixa("Frente", (0.54, 0.04, 0.16), (0, P * 0.5 - 0.02, 0.08), be), caixa("Topo", (0.50, 0.70, 0.04), (0, 0, 0.18), az), caixa("Aba", (0.42, 0.26, 0.03), (0, P * 0.5 + 0.12, 0.02), es),
              caixa("Tras", (0.30, 0.05, 0.10), (0, -P * 0.5 - 0.02, 0.07), es)], "acessorios", "bone_caminhoneiro")


def rockstar():
    import random
    random.seed(48)
    mats = {"c": ("Casaco", (0.10, 0.10, 0.14), 0.0, 0.4), "p": ("Prata", (0.88, 0.90, 0.95), 0.9, 0.2), "k": ("Preto", (0.05, 0.05, 0.07), 0.0, 0.7), "v": ("Vinco", (0.18, 0.18, 0.24), 0.0, 0.4)}
    brilhos = lambda n, w, d, z0, z1: [((0.03, 0.01, 0.03), (random.uniform(-w / 2, w / 2), d / 2 + 0.006, random.uniform(z0, z1)), "p") for _ in range(n)]
    tronco = _tronco_aberto("c", 0.50, -0.05) + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.20, 0.04, 0.44), (0.0, 0.19, -0.02), "k"), ((0.58, 0.40, 0.05), (0, 0, -0.27), "v")] + brilhos(26, 0.50, 0.375, -0.28, 0.22)
    for k in range(7):
        tronco.append(((0.035, 0.035, 0.035), (-0.10 + 0.20 * k / 6, 0.22, 0.24 - 0.10 * (1 - (2 * k / 6 - 1) ** 2)), "p"))
    sup, inf = _bracos("c")
    vestir("rockstar", mats, tronco=tronco, manga_sup=sup + brilhos(6, 0.26, 0.29, -0.3, 0.0), manga_inf=inf + brilhos(4, 0.24, 0.285, -0.2, 0.0) + [((0.31, 0.31, 0.04), (0, 0, -0.18), "v")])
    limpar()
    pr = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.4); la = mat("Aro", (0.78, 0.80, 0.84), 0.9, 0.3)
    yf = P * 0.5 + 0.03
    p = []
    for sx in (1, -1):
        p += [caixa("Lente", (0.20, 0.07, 0.15), (sx * 0.115, yf, -0.07), pr), caixa("TiraL", (0.035, P + 0.02, 0.07), (sx * 0.267, 0, -0.07), pr)]
    p += [caixa("Ponte", (0.06, 0.06, 0.04), (0, yf, -0.06), pr), caixa("Arco", (0.50, 0.04, 0.06), (0, P * 0.5 + 0.005, -0.07), pr)]
    exportar(p, "acessorios", "oculos_escuros_grandes")
    limpar()
    pr = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.3); ve = mat("Branco", (0.95, 0.95, 0.97), 0.0, 0.5); pa = mat("Prata", (0.80, 0.82, 0.86), 0.9, 0.3); co = mat("Couro", (0.28, 0.16, 0.08), 0.0, 0.7)
    p = [caixa("Corpo", (0.30, 0.10, 0.34), (0.0, -0.30, -0.32), pr), caixa("Cintura", (0.24, 0.10, 0.12), (0.0, -0.30, -0.50), pr), caixa("Braco", (0.06, 0.07, 0.46), (0.0, -0.30, 0.0), pr), caixa("Cabeca", (0.10, 0.08, 0.16), (0.0, -0.30, 0.31), pr),
         caixa("Ponte", (0.08, 0.04, 0.12), (0.0, -0.355, -0.28), ve), caixa("Mic", (0.06, 0.03, 0.16), (0.0, -0.355, -0.46), pa), caixa("Alca", (0.06, 0.40, 0.03), (0.22, -0.02, 0.255), co), caixa("AlcaT", (0.06, 0.03, 0.60), (0.20, -0.19, -0.10), co)]
    exportar(p, "acessorios", "guitarra_costas")


def baile_azul():
    mats = {"c": ("Casaco", (0.62, 0.78, 0.96), 0.0, 0.7), "v": ("Vinco", (0.78, 0.88, 0.99), 0.0, 0.7), "b": ("Branco", (0.97, 0.98, 1.0), 0.0, 0.7), "g": ("Cruz", (0.15, 0.40, 0.85), 0.0, 0.2)}
    tronco = [((0.52, 0.355, 0.50), (0, 0, -0.07), "c"), ((0.44, 0.04, 0.05), (0, 0.19, 0.19), "b"), ((0.14, 0.38, 0.05), (0.18, 0, 0.25), "v"), ((0.14, 0.38, 0.05), (-0.18, 0, 0.25), "v"), ((0.575, 0.385, 0.05), (0, 0, -0.31), "b"),
              ((0.16, 0.06, 0.10), (0, -0.20, -0.20), "b"), ((0.06, 0.05, 0.26), (0.07, -0.20, -0.38), "b"), ((0.06, 0.05, 0.26), (-0.07, -0.20, -0.38), "b"), ((0.06, 0.04, 0.06), (0, 0.20, 0.0), "g")]
    for k in range(3):
        tronco.append(((0.03, 0.03, 0.40), (-0.06 + k * 0.06, -0.205, -0.07), "b"))
    saia = [((0.58, 0.40, 0.08), (0, 0, 0.13), "b")]
    for i, (w, d, z) in enumerate([(0.64, 0.44, 0.04), (0.82, 0.58, -0.10), (1.00, 0.72, -0.24), (1.16, 0.86, -0.38), (1.30, 0.98, -0.52), (1.40, 1.08, -0.64)]):
        saia.append(((w, d, 0.15), (0, 0, z), "c" if i % 2 == 0 else "v")); saia.append(((w * 0.6, 0.04, 0.10), (0, d * 0.5, z), "b"))
    vestir("baile_azul", mats, tronco=tronco, saia=saia, manga_sup=[((0.30, 0.30, 0.12), (0, 0, -0.03), "v")], manga_inf=[((0.27, 0.27, 0.21), (0, 0, -0.105), "b")])
    limpar()
    pr = mat("Prata", (0.86, 0.90, 0.96), 0.9, 0.25); az = mat("Azul", (0.40, 0.70, 0.98), 0.2, 0.2)
    zc = -0.03
    p = [caixa("Frente", (0.54, 0.025, 0.04), (0, P * 0.5 + 0.012, zc), pr), caixa("Tras", (0.54, 0.025, 0.04), (0, -P * 0.5 - 0.012, zc), pr)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.025, P, 0.04), (sx * 0.27, 0, zc), pr))
        for h, dx in ((0.10, 0.12), (0.07, 0.20)):
            p.append(caixa("Pico", (0.05, 0.03, h), (sx * dx, P * 0.5 + 0.012, zc + 0.02 + h * 0.5), pr))
    p += [caixa("PicoC", (0.06, 0.03, 0.16), (0, P * 0.5 + 0.012, zc + 0.02 + 0.08), pr), caixa("Gema", (0.05, 0.04, 0.05), (0, P * 0.5 + 0.03, zc + 0.0), az)]
    exportar(p, "acessorios", "tiara_baile")


def princesa_guerreira():
    mats = {"c": ("Casaco", (0.70, 0.72, 0.78), 0.0, 0.55), "v": ("Vinco", (0.54, 0.56, 0.62), 0.0, 0.6), "p": ("Prata", (0.86, 0.88, 0.92), 0.9, 0.3), "o": ("Ouro", (0.90, 0.72, 0.25), 0.8, 0.4)}
    tronco = _base("c") + [((0.50, 0.04, 0.20), (0, 0.19, 0.12), "v"), ((0.07, 0.07, 0.07), (0, 0.22, 0.12), "o"), ((0.34, 0.33, 0.06), (0, 0, 0.27), "p"), ((0.58, 0.40, 0.05), (0, 0, -0.28), "v"), ((0.07, 0.05, 0.07), (0, 0.215, -0.28), "o")]
    for sx in (1, -1):
        for k, (w, z) in enumerate(((0.34, 0.03), (0.34, -0.03), (0.34, -0.09))):
            tronco.append(((0.16 + 0.02 * k, w, 0.07), (sx * (0.27 + 0.01 * k), 0, 0.255 + z * 0.0 - 0.06 * k), "p"))
    saia = [((0.60, 0.40, 0.12), (0, 0, 0.10), "v")]
    for i in range(9):
        saia.append(((0.07, 0.46 + (0.03 if i % 2 else 0.0), 0.22), (-0.32 + i * 0.08, 0, -0.05), "c"))
    sup, inf = _bracos("c")
    vestir("princesa_guerreira", mats, tronco=tronco, saia=saia, manga_sup=[((0.31, 0.31, 0.10), (0, 0, -0.04), "p")], manga_inf=[((0.30, 0.30, 0.10), (0, 0, -0.05), "p"), ((0.29, 0.29, 0.06), (0, 0, -0.17), "c")])
    limpar()
    az = mat("CapaVermelha", (0.60, 0.62, 0.70), 0.0, 0.75); pr = mat("Prata", (0.86, 0.88, 0.92), 0.9, 0.3)
    p = [caixa("Gola", (0.46, 0.06, 0.10), (0, -0.20, 0.05), az), caixa("Manto", (0.92, 0.52, 0.10), (0, -0.07, -0.12), az), caixa("Fecho", (0.30, 0.03, 0.03), (0, 0.15, -0.04), pr)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.90, 1.00, 1.10]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), az)); z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.78), (sx * 0.46, -0.07, -0.55), az))
    exportar(p, "acessorios", "capa_princesa")


def rei_elfo():
    mats = {"c": ("Casaco", (0.86, 0.88, 0.90), 0.0, 0.6), "v": ("Vinco", (0.66, 0.70, 0.60), 0.0, 0.7), "o": ("Ouro", (0.88, 0.80, 0.50), 0.7, 0.4), "g": ("Espinho", (0.42, 0.55, 0.30), 0.0, 0.8)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "o"), ((0.12, 0.04, 0.50), (0.0, 0.195, -0.04), "o"), ((0.58, 0.40, 0.05), (0, 0, -0.28), "o"), ((0.08, 0.05, 0.08), (0, 0.22, -0.28), "g")]
    for k in range(4):
        tronco.append(((0.12, 0.04, 0.05), (0.0, 0.215, 0.08 - k * 0.12), "g")) if False else None
    for sx in (1, -1):
        tronco += [((0.14, 0.40, 0.04), (sx * 0.27, 0, 0.26), "g"), ((0.15, 0.41, 0.015), (sx * 0.27, 0, 0.285), "o")]
    sup, inf = _bracos("c")
    saia = _saia_aberta("c", 0.50, -0.05) + [((0.59, 0.38, 0.04), (0, 0, -0.30), "o")]
    vestir("rei_elfo", mats, tronco=tronco, saia=saia, manga_sup=sup + [((0.31, 0.31, 0.04), (0, 0, -0.03), "o")], manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "o")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c"), ((0.275, 0.275, 0.04), (0, 0, -0.04), "o")], pe=[((0.27, 0.32, 0.10), (0, 0, -0.05), "v")])
    limpar()
    pr = mat("Prata", (0.86, 0.88, 0.92), 0.9, 0.3); ve = mat("Folha", (0.42, 0.60, 0.30), 0.0, 0.8)
    import math
    p = [caixa("Aro", (0.54, P + 0.04, 0.06), (0, 0, -0.02), pr)]
    for sx in (1, -1):
        for k in range(5):
            p.append(caixa_rot("Folha", (0.12, 0.05, 0.04), (sx * (0.10 + 0.04 * k) , P * 0.5 - 0.05 - 0.0 - k * 0.0 + 0.0 - 0.0, 0.01 + 0.015 * k), ve, (30 if sx > 0 else -30) + 0)) if False else None
    for i in range(22):
        t = i / 22 * 2 * math.pi
        p.append(caixa_rot("Folha", (0.10, 0.05, 0.04), (0.285 * math.cos(t), 0.405 * math.sin(t), 0.03), ve, math.degrees(t) + 90 + (24 if i % 2 else -24)))
    p += [caixa("Gema", (0.06, 0.04, 0.07), (0, P * 0.5 + 0.03, 0.0), pr), caixa("Pico", (0.07, 0.04, 0.12), (0, P * 0.5 + 0.03, 0.08), pr)]
    exportar(p, "acessorios", "coroa_elfica")


def bruxa_floresta():
    limpar()
    vd = mat("CapaVerde", (0.28, 0.45, 0.20), 0.0, 0.95); es = mat("MantoSombra", (0.18, 0.32, 0.13), 0.0, 0.95); fl = mat("Rosa", (0.98, 0.80, 0.85), 0.0, 0.8); lu = mat("Luz", (1.0, 0.85, 0.40), 0.0, 0.3)
    co = mat("Couro", (0.38, 0.22, 0.10), 0.0, 0.8)
    p = [caixa("Capelo", (0.50, 0.14, 0.18), (0, -0.20, 0.08), es), caixa("Manto", (0.94, 0.54, 0.12), (0, -0.07, -0.12), vd), caixa("Cinta", (0.58, 0.40, 0.04), (0, 0, -0.30), co)]
    z = -0.18
    for i, larg in enumerate([0.80, 0.88, 0.96, 1.04, 1.12]):
        p.append(caixa("Costas%d" % i, (larg, 0.055, 0.22), (0, -0.25, z - 0.11), vd if i % 2 == 0 else es)); z -= 0.22
    for sx in (1, -1):
        p.append(caixa("Pano", (0.05, 0.36, 0.84), (sx * 0.46, -0.07, -0.60), vd)); p.append(caixa("Lanterna", (0.08, 0.08, 0.12), (sx * 0.30, 0.2, -0.36), lu)); p.append(caixa("Flor", (0.06, 0.03, 0.06), (sx * 0.38, 0.0, -0.08), fl))
    exportar(p, "acessorios", "manto_musgo")
    limpar()
    ve = mat("Cogumelo", (0.80, 0.14, 0.14), 0.0, 0.5); br = mat("Branco", (0.97, 0.95, 0.90), 0.0, 0.6); fo = mat("Folha", (0.30, 0.55, 0.22), 0.0, 0.8)
    p = [caixa("Aba", (0.94, 1.04, 0.04), (0, 0, 0.0), ve), caixa("Aba2", (0.80, 0.90, 0.04), (0, 0, 0.04), ve), caixa("Copa", (0.50, 0.66, 0.14), (0, 0, 0.12), ve), caixa("Copa2", (0.38, 0.50, 0.12), (0, -0.05, 0.24), ve),
         caixa("Ponta", (0.24, 0.30, 0.12), (0, -0.12, 0.35), ve), caixa("Ponta2", (0.14, 0.16, 0.10), (0.0, -0.22, 0.43), ve)]
    for x, y, z in ((0.20, 0.30, 0.05), (-0.25, 0.1, 0.05), (0.1, -0.35, 0.05), (-0.1, 0.38, 0.05), (0.3, -0.1, 0.05)):
        p.append(caixa("Pinta", (0.10, 0.10, 0.03), (x, y, z), br))
    for k in range(10):
        p.append(caixa("Folha", (0.07, 0.04, 0.05), (-0.4 + k * 0.09, 0.42 if k % 2 else -0.42, 0.01), fo))
    exportar(p, "acessorios", "chapeu_cogumelo")


def samurai_espectral():
    mats = {"c": ("Casaco", (0.30, 0.72, 0.92), 0.0, 0.3), "v": ("Vinco", (0.18, 0.52, 0.78), 0.0, 0.3), "b": ("Lapela", (0.62, 0.90, 0.98), 0.0, 0.2)}
    tronco = _base("c") + [((0.575, 0.385, 0.04), (0, 0, 0.17 - k * 0.11), "b" if k % 2 else "v") for k in range(5)] + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.58, 0.40, 0.08), (0, 0, -0.26), "b"), ((0.10, 0.05, 0.12), (0.05, 0.22, -0.36), "b")]
    for sx in (1, -1):
        tronco.append(((0.07, 0.40, 0.03), (sx * 0.15, 0, 0.26), "v"))
    saia = []
    for i in range(7):
        saia.append(((0.095, 0.44, 0.50), (-0.27 + i * 0.09, 0, -0.10), "c" if i % 2 else "v")); saia.append(((0.10, 0.45, 0.03), (-0.27 + i * 0.09, 0, -0.35), "b"))
    saia.append(((0.60, 0.40, 0.18), (0, 0, 0.08), "v"))
    vestir("samurai_espectral", mats, tronco=tronco, saia=saia,
           manga_sup=[((0.37, 0.37, 0.07), (0, 0, 0.03), "c"), ((0.38, 0.38, 0.03), (0, 0, 0.07), "b"), ((0.38, 0.38, 0.07), (0, 0, -0.05), "v"), ((0.39, 0.39, 0.03), (0, 0, -0.09), "b"), ((0.38, 0.38, 0.07), (0, 0, -0.14), "c"), ((0.39, 0.39, 0.03), (0, 0, -0.18), "b"), ((0.27, 0.27, 0.15), (0, 0, -0.24), "v")],
           manga_inf=[((0.27, 0.27, 0.13), (0, 0, -0.065), "v"), ((0.31, 0.31, 0.11), (0, 0, -0.16), "c"), ((0.315, 0.315, 0.025), (0, 0, -0.115), "b")])
    limpar()
    az = mat("Casaco", (0.30, 0.72, 0.92), 0.0, 0.3); cl = mat("Lapela", (0.62, 0.90, 0.98), 0.0, 0.2)
    p = [caixa("Casco", (0.56, 0.78, 0.14), (0, 0, 0.07), az), caixa("Topo", (0.44, 0.62, 0.08), (0, 0, 0.17), az), caixa("Pico", (0.28, 0.40, 0.06), (0, 0, 0.24), az), caixa("Aba", (0.62, 0.84, 0.04), (0, 0, -0.01), cl),
         caixa("Pescoco", (0.64, 0.10, 0.22), (0, -0.40, -0.10), az), caixa("Crista", (0.05, 0.22, 0.05), (0, 0.38, 0.12), cl)]
    for sx in (1, -1):
        p += [caixa("Orelha", (0.07, 0.30, 0.24), (sx * 0.34, -0.05, -0.12), az)]
        for j in range(3):
            p.append(caixa("Chifre%d" % j, (0.045, 0.045, 0.07), (sx * (0.06 + j * 0.05), 0.38, 0.17 + j * 0.06), cl))
    exportar(p, "acessorios", "kabuto_espectral")


def chef_sushi():
    mats = {"c": ("Branco", (0.95, 0.95, 0.97), 0.0, 0.9), "v": ("Vinco", (0.78, 0.80, 0.86), 0.0, 0.9), "k": ("Preto", (0.08, 0.08, 0.10), 0.0, 0.7)}
    tronco = _tronco_aberto("c") + [((0.09, 0.04, 0.46), (0.07, 0.195, 0.0), "v"), ((0.09, 0.04, 0.46), (-0.07, 0.195, 0.0), "v"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "v"), ((0.58, 0.39, 0.06), (0, 0, -0.26), "k"),
              ((0.05, 0.05, 0.22), (0.05, 0.215, -0.40), "k"), ((0.05, 0.05, 0.18), (-0.04, 0.215, -0.38), "k")]
    sup, inf = _bracos("c")
    vestir("sushi", mats, tronco=tronco, saia=_saia_aberta("c", 0.56, -0.10) + [((0.40, 0.04, 0.50), (0, 0.205, -0.10), "v")], manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.04), (0, 0, -0.18), "v")])
    limpar()
    br = mat("Branco", (0.95, 0.95, 0.97), 0.0, 0.9); vi = mat("Vinco", (0.78, 0.80, 0.86), 0.0, 0.9)
    exportar([caixa("Faixa", (0.58, 0.80, 0.08), (0, 0, 0.04), vi), caixa("Copa", (0.56, 0.76, 0.12), (0, 0, 0.14), br), caixa("Topo", (0.50, 0.70, 0.06), (0, 0, 0.23), br), caixa("Frente", (0.52, 0.04, 0.20), (0, P * 0.5 - 0.02, 0.10), br)], "acessorios", "chapeu_sushi")


def fada_flores():
    mats = {"c": ("Casaco", (0.96, 0.58, 0.72), 0.0, 0.8), "v": ("Vinco", (0.82, 0.42, 0.58), 0.0, 0.8), "g": ("Espinho", (0.45, 0.65, 0.28), 0.0, 0.8), "r": ("Rosa", (0.98, 0.80, 0.88), 0.0, 0.8), "y": ("Ouro", (0.98, 0.85, 0.30), 0.0, 0.8)}
    tronco = [((0.52, 0.355, 0.46), (0, 0, -0.06), "c"), ((0.44, 0.04, 0.05), (0, 0.19, 0.18), "g"), ((0.10, 0.38, 0.04), (0.18, 0, 0.255), "r"), ((0.10, 0.38, 0.04), (-0.18, 0, 0.255), "r"), ((0.56, 0.37, 0.04), (0, 0, -0.27), "g"),
              ((0.09, 0.04, 0.09), (0.0, 0.205, 0.10), "r"), ((0.04, 0.045, 0.04), (0.0, 0.215, 0.10), "y")]
    for sx in (1, -1):
        tronco += [((0.08, 0.04, 0.40), (sx * 0.17, 0.195, 0.02), "g"), ((0.08, 0.04, 0.40), (sx * 0.17, -0.195, 0.0), "g")]
    saia = [((0.58, 0.40, 0.08), (0, 0, 0.13), "v")]
    for r in range(3):
        for k in range(8):
            ang = k / 8 * 6.2832
            import math
            saia.append(((0.20 + 0.04 * r, 0.06, 0.18), (math.cos(ang) * (0.22 + 0.06 * r), math.sin(ang) * (0.18 + 0.06 * r) * 1.15, -0.04 - 0.09 * r), "r" if (k + r) % 2 == 0 else "c"))
    vestir("fada", mats, tronco=tronco, saia=saia)
    limpar()
    ve = mat("Folha", (0.45, 0.65, 0.28), 0.0, 0.8); fl = mat("Rosa", (0.98, 0.80, 0.88), 0.0, 0.8); mei = mat("Miolo", (0.98, 0.85, 0.30), 0.0, 0.8)
    p = []
    for sx in (1, -1):
        p += [caixa("Folhas", (0.30, 0.31, 0.04), (0, 0, -0.04), ve) if False else caixa("Gal", (0.30, 0.30, 0.04), (0, 0, -0.04), ve), caixa("Flor", (0.08, 0.08, 0.05), (0.12, 0.15, -0.04), fl), caixa("FlorMeio", (0.03, 0.03, 0.05), (0.12, 0.15, -0.04), mei)]
        break
    exportar(p, "acessorios", "tornozeleira_flores")


def cabelo_assimetrico_mecha():
    import random
    limpar()
    random.seed(13)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9); br = mat("Mecha", (0.97, 0.97, 0.98), 0.0, 0.9)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L, P * 0.9, 0.08), (0, -0.01, 0.04), cab), caixa("Nuca", (L + 0.03, 0.13, 0.34), (0, -(P * 0.5 - 0.04), -0.17), cab)]
    for i in range(10):
        h = 0.22 - 0.014 * i if i < 5 else 0.10 + 0.01 * (i - 5)
        p.append(caixa("Franja%d" % i, (0.08, 0.07, h + 0.12), (0.26 - i * 0.052, P * 0.5 - 0.005, -0.05 - h * 0.5), cab))
    for i in range(5):
        p.append(caixa("Mecha%d" % i, (0.06, 0.08, 0.10), (0.04 + i * 0.045, P * 0.5 - 0.005 - i * 0.04, 0.05 - 0.03 * i), br)) if False else None
        p.append(caixa("MechaB%d" % i, (0.06, 0.085, 0.12 + 0.02 * i), (-0.02 - i * 0.04, P * 0.5 - 0.01, -0.10 - 0.04 * i), br))
    for sx in (1, -1):
        p.append(caixa("Lado", (0.09, P * 0.64, 0.30 if sx < 0 else 0.20), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.15 if sx < 0 else -0.10), cab))
    for i in range(14):
        p.append(caixa("Topo%d" % i, (0.10, 0.10, 0.07), (random.uniform(-0.22, 0.22), random.uniform(-0.30, 0.30), 0.09), cab))
    exportar(p, "cabelos", "cabelo_assimetrico_mecha")


def cabelo_ruivo_ondulado_trancas():
    import random
    limpar()
    random.seed(18)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95); el = mat("Elastico", (0.85, 0.70, 0.25), 0.3, 0.6)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.92, P * 0.86, 0.06), (0, -0.01, 0.035), cab), caixa("Franja", (L + 0.02, 0.08, 0.16), (0, P * 0.5 - 0.005, -0.08), cab)]
    for i in range(12):
        z = -0.12 - i * 0.09
        dx = 0.05 if (i // 2) % 2 == 0 else -0.05
        p.append(caixa("Costas%d" % i, (L + 0.02, 0.12, 0.095), (dx, -(P * 0.5 - 0.05) - 0.01 * (i % 3), z), cab))
        for sx in (1, -1):
            if i < 10:
                p.append(caixa("Lado%d" % i, (0.085, 0.13, 0.095), (sx * (L * 0.5 + 0.02) + sx * 0.02 * (1 if i % 2 else -1), -0.12 + 0.0, z - 0.02), cab))
    for sx in (1, -1):
        for j in range(8):
            dx = 0.02 if j % 2 else -0.02
            p.append(caixa("Tranca%d" % j, (0.07, 0.07, 0.09), (sx * (L * 0.5 + 0.06) + dx, P * 0.5 - 0.12, -0.10 - j * 0.07), cab))
        p.append(caixa("Elo", (0.08, 0.08, 0.03), (sx * (L * 0.5 + 0.06), P * 0.5 - 0.12, -0.67), el))
    exportar(p, "cabelos", "cabelo_ruivo_ondulado_trancas")


def cabelo_louro_curto_ondulado():
    import random
    limpar()
    random.seed(23)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.9)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.10), (0, 0, -0.05), cab), caixa("Nuca", (L + 0.03, 0.12, 0.26), (0, -(P * 0.5 - 0.04), -0.13), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.62, 0.24), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.12), cab))
        for j in range(3):
            p.append(caixa("Onda", (0.10, 0.11, 0.07), (sx * (L * 0.5 + 0.02), -0.0 + 0.12 * j - 0.1, -0.24 - 0.0), cab))
    for i in range(26):
        x = random.uniform(-L * 0.46, L * 0.46); y = random.uniform(-P * 0.44, P * 0.44); h = random.uniform(0.04, 0.12); w = random.uniform(0.09, 0.15)
        p.append(caixa("Onda%d" % i, (w, w * 1.2, h), (x, y, 0.06 + h * 0.5 - 0.0), cab))
    for k in range(8):
        p.append(caixa("Franja%d" % k, (0.10, 0.07, random.uniform(0.10, 0.18)), (-0.28 + k * 0.08, P * 0.5 - 0.01, -0.05 - 0.01 * (k % 3)), cab))
    exportar(p, "cabelos", "cabelo_louro_curto_ondulado")


# ======================================================================= lote 13
def cacador_tesouros():
    mats = {"c": ("Casaco", (0.38, 0.20, 0.10), 0.0, 0.75), "v": ("Vinco", (0.26, 0.14, 0.07), 0.0, 0.8), "b": ("Branco", (0.88, 0.78, 0.58), 0.0, 0.9), "o": ("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)}
    tronco = _tronco_aberto("c", 0.52, -0.04) + [((0.14, 0.04, 0.46), (0.0, 0.195, 0.0), "b"), ((0.34, 0.33, 0.06), (0, 0, 0.27), "c"), ((0.58, 0.40, 0.05), (0, 0, -0.26), "v"), ((0.08, 0.05, 0.07), (0, 0.22, -0.26), "o")]
    for sx in (1, -1):
        tronco.append(((0.05, 0.04, 0.48), (sx * 0.12, 0.205, 0.0), "v"))
    tronco.append(osso("Cinta", (0.2, 0.0, 0.25), (-0.26, 0.0, -0.22), 0.05, mat("Couro", (0.30, 0.17, 0.09), 0.0, 0.75))) if False else None
    sup, inf = _bracos("c")
    vestir("cacador", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v")])
    limpar()
    pa = mat("Chapeu", (0.40, 0.22, 0.10), 0.0, 0.8); fi = mat("Fita", (0.24, 0.12, 0.06), 0.0, 0.8); ou = mat("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)
    exportar([caixa("Aba", (0.84, 1.00, 0.035), (0, 0, 0.0), pa), caixa("Copa", (0.50, 0.66, 0.17), (0, 0, 0.105), pa), caixa("CopaTopo", (0.44, 0.60, 0.04), (0, 0, 0.20), pa), caixa("Vinco", (0.08, 0.60, 0.04), (0, 0, 0.225), fi),
              caixa("Fita", (0.52, 0.68, 0.055), (0, 0, 0.06), fi), caixa("Fivela", (0.07, 0.04, 0.06), (0, 0.345, 0.06), ou)], "acessorios", "chapeu_aventureiro")
    limpar()
    co = mat("Couro", (0.40, 0.22, 0.10), 0.0, 0.75); es = mat("CouroEscuro", (0.26, 0.14, 0.07), 0.0, 0.75); ou = mat("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)
    p = [caixa("Corpo", (0.34, 0.16, 0.38), (0, -0.29, 0.0), co), caixa("Aba", (0.35, 0.17, 0.10), (0, -0.29, 0.20), es), caixa("Bolso", (0.22, 0.06, 0.16), (0, -0.39, -0.06), es), caixa("Fecho", (0.05, 0.05, 0.05), (0, -0.38, 0.17), ou),
         caixa("Rolo", (0.30, 0.14, 0.08), (0, -0.29, 0.28), es)]
    for sx in (1, -1):
        p += [caixa("Alca", (0.06, 0.04, 0.50), (sx * 0.12, 0.205, 0.0), es), caixa("AlcaO", (0.06, 0.40, 0.03), (sx * 0.12, 0, 0.255), es), caixa("AlcaT", (0.06, 0.03, 0.40), (sx * 0.12, -0.2, 0.06), es)]
    exportar(p, "acessorios", "mochila_aventura")
    limpar()
    co = mat("Couro", (0.46, 0.26, 0.12), 0.0, 0.75); ou = mat("Ouro", (0.82, 0.62, 0.20), 0.8, 0.4)
    p = [caixa("Argola", (0.09, 0.03, 0.04), (0.24, 0.15, 0.08), ou)]
    for k in range(5):
        p.append(caixa("Volta%d" % k, (0.14 - 0.01 * k, 0.04, 0.035), (0.30, 0.15, 0.03 - k * 0.04), co))
    exportar(p, "acessorios", "chicote_cinto")


def detetive():
    mats = {"c": ("Casaco", (0.78, 0.62, 0.42), 0.0, 0.85), "v": ("Vinco", (0.62, 0.48, 0.30), 0.0, 0.85), "b": ("Branco", (0.94, 0.94, 0.96), 0.0, 0.9), "k": ("Couro", (0.40, 0.24, 0.12), 0.0, 0.75), "r": ("Gravata", (0.40, 0.18, 0.14), 0.0, 0.8)}
    tronco = _tronco_aberto("c") + [((0.12, 0.04, 0.46), (0.0, 0.195, 0.0), "b"), ((0.34, 0.33, 0.10), (0, 0, 0.29), "c"), ((0.12, 0.05, 0.12), (0.12, 0.21, 0.20), "v"), ((0.12, 0.05, 0.12), (-0.12, 0.21, 0.20), "v"),
              ((0.06, 0.05, 0.22), (0.0, 0.215, 0.10), "r"), ((0.58, 0.40, 0.05), (0, 0, -0.26), "k"), ((0.09, 0.05, 0.07), (0, 0.22, -0.26), "k"), ((0.62, 0.10, 0.20), (0, -0.20, 0.17), "v")]
    for sx in (1, -1):
        tronco += [((0.14, 0.40, 0.04), (sx * 0.27, 0, 0.26), "v"), ((0.05, 0.40, 0.03), (sx * 0.30, 0, 0.30), "v")]
    sup, inf = _bracos("c")
    vestir("detetive", mats, tronco=tronco, saia=_saia_aberta("c", 0.84, -0.25) + [((0.59, 0.38, 0.03), (0, 0, -0.66), "v"), ((0.12, 0.05, 0.16), (0.17, 0.205, -0.30), "v"), ((0.12, 0.05, 0.16), (-0.17, 0.205, -0.30), "v"), ((0.02, 0.055, 0.34), (0, -0.18, -0.42), "v")],
           manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v"), ((0.30, 0.30, 0.03), (0, 0, -0.10), "k")])
    limpar()
    be = mat("Chapeu", (0.80, 0.66, 0.46), 0.0, 0.85); fi = mat("Fita", (0.40, 0.24, 0.12), 0.0, 0.8)
    exportar([caixa("Aba", (0.80, 0.96, 0.035), (0, 0, 0.0), be), caixa("Copa", (0.50, 0.66, 0.15), (0, 0, 0.095), be), caixa("CopaTopo", (0.44, 0.60, 0.04), (0, 0, 0.18), be), caixa("Vinco", (0.08, 0.58, 0.04), (0, 0, 0.205), be),
              caixa("Fita", (0.52, 0.68, 0.05), (0, 0, 0.06), fi), caixa("AbaFrente", (0.60, 0.07, 0.05), (0, 0.46, 0.03), be)], "acessorios", "fedora_detetive")
    limpar()
    ou = mat("Latao", (0.82, 0.62, 0.20), 0.85, 0.4); vd = mat("Vidro", (0.75, 0.90, 0.96), 0.2, 0.05)
    exportar([caixa("Cabo", (0.04, 0.04, 0.16), (0, 0, -0.10), ou), caixa("Aro", (0.16, 0.04, 0.16), (0, 0, -0.26), ou), caixa("Vidro", (0.12, 0.045, 0.12), (0, 0, -0.26), vd), caixa("Ponta", (0.06, 0.05, 0.05), (0, 0, -0.03), ou)], "acessorios", "lupa_detetive")


def bombeiro_resgate():
    mats = {"c": ("Casaco", (0.22, 0.22, 0.26), 0.0, 0.8), "r": ("Gravata", (0.82, 0.10, 0.12), 0.0, 0.7), "y": ("Espinho", (0.86, 0.96, 0.18), 0.0, 0.4), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.3), "v": ("Vinco", (0.14, 0.14, 0.17), 0.0, 0.8)}
    tronco = _base("c") + [((0.575, 0.385, 0.04), (0, 0, 0.06), "p"), ((0.575, 0.385, 0.04), (0, 0, -0.18), "p"), ((0.34, 0.33, 0.07), (0, 0, 0.27), "v")]
    for sx in (1, -1):
        tronco += [((0.20, 0.06, 0.46), (sx * 0.15, 0.22, 0.0), "r"), ((0.10, 0.065, 0.46), (sx * 0.13, 0.225, 0.0), "y"), ((0.09, 0.06, 0.07), (sx * 0.17, 0.24, 0.12), "v"), ((0.09, 0.06, 0.07), (sx * 0.17, 0.24, -0.08), "v"),
                   ((0.06, 0.40, 0.03), (sx * 0.15, 0, 0.26), "y")]
    tronco += [((0.50, 0.06, 0.46), (0, -0.22, 0.0), "r"), ((0.40, 0.065, 0.06), (0, -0.225, 0.10), "y"), ((0.40, 0.065, 0.06), (0, -0.225, -0.10), "y")]
    sup, inf = _bracos("c")
    vestir("bombeiro_resgate", mats, tronco=tronco, manga_sup=sup + [((0.30, 0.30, 0.05), (0, 0, -0.12), "y")], manga_inf=inf + [((0.30, 0.30, 0.05), (0, 0, -0.10), "y"), ((0.31, 0.31, 0.04), (0, 0, -0.19), "p")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.28, 0.28, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.05, 0.14), (0.12, 0.16, -0.14), "v")],
           canela=[((0.28, 0.28, 0.285), (0, 0, -0.1425), "c"), ((0.29, 0.29, 0.05), (0, 0, -0.10), "y"), ((0.29, 0.29, 0.03), (0, 0, -0.14), "p"), ((0.29, 0.29, 0.05), (0, 0, -0.22), "y")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "v")])
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.5); am = mat("Espinho", (0.86, 0.96, 0.18), 0.0, 0.4); vm = mat("Gravata", (0.82, 0.10, 0.12), 0.0, 0.5); pr = mat("Preto", (0.08, 0.08, 0.10), 0.0, 0.6); lu = mat("Luz", (1.0, 0.95, 0.75), 0.0, 0.3)
    exportar([caixa("Casco", (0.60, 0.84, 0.16), (0, 0, 0.08), br), caixa("Topo", (0.46, 0.66, 0.06), (0, 0, 0.19), br), caixa("Crista", (0.06, 0.80, 0.05), (0, 0, 0.23), vm), caixa("Faixa", (0.61, 0.85, 0.03), (0, 0, 0.06), am),
              caixa("Aba", (0.62, 0.90, 0.03), (0, 0.03, 0.0), br), caixa("Nuca", (0.64, 0.12, 0.14), (0, -0.46, -0.04), br), caixa("Lanterna", (0.14, 0.06, 0.10), (0, 0.46, 0.12), pr), caixa("Luz", (0.10, 0.03, 0.07), (0, 0.50, 0.12), lu)], "acessorios", "capacete_resgate")


def cirurgiao():
    mats = {"c": ("Casaco", (0.30, 0.58, 0.82), 0.0, 0.85), "v": ("Vinco", (0.20, 0.44, 0.66), 0.0, 0.85), "b": ("Branco", (0.92, 0.95, 0.98), 0.0, 0.9)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.58, 0.40, 0.04), (0, -0.0, -0.26), "v"), ((0.10, 0.05, 0.16), (0.0, -0.21, -0.26), "c")]
    sup, inf = _bracos("c")
    vestir("cirurgiao", mats, tronco=tronco, saia=[((0.60, 0.40, 0.70), (0, 0, -0.18), "c"), ((0.61, 0.41, 0.04), (0, 0, -0.51), "v")], manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.06), (0, 0, -0.18), "v")])
    limpar()
    az = mat("Casaco", (0.30, 0.58, 0.82), 0.0, 0.85); br = mat("Branco", (0.92, 0.95, 0.98), 0.0, 0.9); ma = mat("Mascara", (0.62, 0.84, 0.95), 0.0, 0.8)
    g = 0.03
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.08), (0, 0, 0.04), az), caixa("Faixa", (larg + 0.01, prof + 0.01, 0.06), (0, 0, -0.02), az), caixa("Tras", (larg, 0.05, 0.16), (0, -prof * 0.5 + 0.025, -0.12), az), caixa("No", (0.10, 0.06, 0.12), (0, -prof * 0.5 - 0.03, -0.04), az),
         caixa("Ponta", (0.05, 0.04, 0.16), (-0.04, -prof * 0.5 - 0.05, -0.16), az), caixa("Ponta2", (0.05, 0.04, 0.14), (0.04, -prof * 0.5 - 0.05, -0.14), az)]
    exportar(p, "acessorios", "touca_cirurgica")
    limpar()
    br = mat("Branco", (0.92, 0.95, 0.98), 0.0, 0.9); ma = mat("Mascara", (0.62, 0.84, 0.95), 0.0, 0.8)
    p = [caixa("Corpo", (0.36, 0.04, 0.22), (0, 0.02, -0.17), ma), caixa("Prega", (0.34, 0.045, 0.02), (0, 0.025, -0.14), br), caixa("Prega2", (0.34, 0.045, 0.02), (0, 0.025, -0.20), br)]
    for sx in (1, -1):
        p.append(caixa("Elastico", (0.02, 0.76, 0.02), (sx * 0.265, -0.37, -0.16), br))
    exportar(p, "acessorios", "mascara_cirurgica")


def agente_secreto():
    mats = {"c": ("Casaco", (0.06, 0.06, 0.08), 0.0, 0.6), "v": ("Vinco", (0.12, 0.12, 0.15), 0.0, 0.6), "b": ("Branco", (0.95, 0.95, 0.97), 0.0, 0.9), "k": ("Preto", (0.04, 0.04, 0.05), 0.0, 0.7)}
    tronco = _tronco_aberto("c", 0.58, -0.04) + [((0.12, 0.04, 0.46), (0, 0.195, 0.0), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"), ((0.05, 0.05, 0.30), (0, 0.215, 0.07), "k"), ((0.34, 0.05, 0.05), (0, 0.205, 0.20), "v"),
              ((0.03, 0.04, 0.03), (0.0, 0.2, -0.04), "v"), ((0.10, 0.05, 0.03), (0.15, 0.205, 0.08), "b")]
    for sx in (1, -1):
        tronco += [((0.11, 0.05, 0.30), (sx * 0.12, 0.205, 0.04), "v")]
    sup, inf = _bracos("c")
    vestir("agente", mats, tronco=tronco, saia=_saia_aberta("c", 0.40, -0.06), manga_sup=sup, manga_inf=inf + [((0.30, 0.30, 0.03), (0, 0, -0.19), "b")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    pr = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.4); br = mat("Branco", (0.90, 0.90, 0.92), 0.0, 0.5)
    yf = P * 0.5 + 0.03
    p = [caixa("Ponte", (0.06, 0.06, 0.04), (0, yf, -0.06), pr), caixa("Arco", (0.50, 0.04, 0.06), (0, P * 0.5 + 0.005, -0.07), pr)]
    for sx in (1, -1):
        p += [caixa("Lente", (0.20, 0.07, 0.15), (sx * 0.115, yf, -0.07), pr), caixa("TiraL", (0.035, P + 0.02, 0.07), (sx * 0.267, 0, -0.07), pr)]
    p += [caixa("Fone", (0.03, 0.04, 0.05), (0.27, -0.0, -0.24), br), caixa("Fio", (0.02, 0.02, 0.22), (0.28, -0.0, -0.36), pr)]
    exportar(p, "acessorios", "oculos_fone_agente")


def cacafantasma():
    mats = {"c": ("Casaco", (0.78, 0.65, 0.42), 0.0, 0.85), "v": ("Vinco", (0.62, 0.50, 0.30), 0.0, 0.85), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7), "r": ("Gravata", (0.85, 0.12, 0.14), 0.0, 0.7), "b": ("Branco", (0.96, 0.96, 0.97), 0.0, 0.8)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "v"), ((0.58, 0.40, 0.05), (0, 0, -0.27), "k"), ((0.07, 0.05, 0.07), (0, 0.22, -0.27), "v"), ((0.07, 0.03, 0.07), (0.16, 0.2, 0.10), "r"), ((0.04, 0.04, 0.04), (0.16, 0.21, 0.10), "b"),
                           ((0.12, 0.05, 0.12), (-0.15, 0.2, 0.0), "v")]
    for sx in (1, -1):
        tronco += [((0.06, 0.04, 0.48), (sx * 0.15, 0.2, 0.02), "k"), ((0.06, 0.40, 0.03), (sx * 0.15, 0, 0.255), "k")]
    sup, inf = _bracos("c")
    cint = [((0.53, 0.30, 0.15), (0, 0, 0.09), "c")]
    vestir("cacafantasma", mats, tronco=tronco, manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v")], cintura=cint,
           coxa=[((0.27, 0.27, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.05, 0.14), (0.12, 0.15, -0.10), "v")], canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "c"), ((0.28, 0.28, 0.05), (0, 0, -0.24), "v")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    k = mat("Preto", (0.08, 0.08, 0.10), 0.0, 0.6); ci = mat("Ciano", (0.30, 0.85, 1.0), 0.0, 0.3); ou = mat("Ouro", (0.98, 0.78, 0.15), 0.0, 0.4); lar = mat("Laranja", (0.98, 0.50, 0.10), 0.0, 0.5); cz = mat("Prata", (0.55, 0.58, 0.62), 0.5, 0.5)
    for m in (ci,):
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"); b.inputs["Emission Color"].default_value = (0.3, 0.85, 1.0, 1.0); b.inputs["Emission Strength"].default_value = 2.0
    p = [caixa("Corpo", (0.44, 0.16, 0.52), (0, -0.30, -0.02), k), caixa("Painel", (0.30, 0.03, 0.20), (0, -0.395, 0.04), cz), caixa("Visor", (0.18, 0.035, 0.12), (0, -0.405, -0.02), ci), caixa("Luz", (0.06, 0.05, 0.05), (0.14, -0.40, 0.22), ou),
         caixa("TuboE", (0.07, 0.08, 0.40), (-0.18, -0.34, -0.04), ci), caixa("TuboD", (0.07, 0.08, 0.40), (0.18, -0.34, -0.04), ci), caixa("Cano", (0.05, 0.05, 0.30), (0.26, -0.28, -0.20), lar), caixa("Antena", (0.04, 0.04, 0.12), (0.18, -0.30, 0.30), k),
         caixa("AntenaLuz", (0.06, 0.06, 0.06), (0.18, -0.30, 0.38), ou)]
    for sx in (1, -1):
        p += [caixa("Alca", (0.06, 0.04, 0.50), (sx * 0.15, 0.205, 0.0), k), caixa("AlcaO", (0.06, 0.40, 0.03), (sx * 0.15, 0, 0.255), k), caixa("AlcaT", (0.06, 0.03, 0.40), (sx * 0.15, -0.2, 0.05), k)]
    exportar(p, "acessorios", "mochila_protons")


def explorador_polar():
    mats = {"c": ("Casaco", (0.12, 0.26, 0.62), 0.0, 0.7), "v": ("Vinco", (0.08, 0.18, 0.44), 0.0, 0.7), "p": ("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0), "k": ("Couro", (0.32, 0.18, 0.09), 0.0, 0.75), "g": ("Aco", (0.72, 0.74, 0.78), 0.2, 0.7)}
    tronco = [((0.60, 0.42, 0.58), (0, 0, -0.04), "c"), ((0.36, 0.34, 0.12), (0, 0, 0.30), "c"), ((0.62, 0.44, 0.08), (0, 0, 0.30), "p"), ((0.64, 0.14, 0.28), (0, -0.28, 0.28), "c"), ((0.62, 0.46, 0.06), (0, 0, -0.30), "v"), ((0.03, 0.04, 0.58), (0, 0.215, -0.04), "k"),
              ((0.14, 0.05, 0.14), (0.16, 0.22, -0.04), "v"), ((0.14, 0.05, 0.14), (-0.16, 0.22, -0.04), "v"), ((0.08, 0.05, 0.10), (0.16, 0.24, -0.04), "k"), ((0.08, 0.05, 0.10), (-0.16, 0.24, -0.04), "k")]
    sup = [((0.34, 0.34, 0.34), (0, 0, -0.15), "c"), ((0.35, 0.35, 0.04), (0, 0, -0.05), "v")]
    inf = [((0.33, 0.33, 0.21), (0, 0, -0.105), "c"), ((0.36, 0.36, 0.07), (0, 0, -0.19), "p"), ((0.14, 0.05, 0.08), (0, 0.17, -0.07), "v")]
    vestir("polar", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, saia=[((0.62, 0.44, 0.18), (0, 0, 0.09), "c")],
           cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "g")], coxa=[((0.28, 0.28, 0.36), (0, 0, -0.18), "g"), ((0.10, 0.04, 0.12), (0.12, 0.15, -0.14), "v")],
           canela=[((0.28, 0.28, 0.285), (0, 0, -0.1425), "g"), ((0.14, 0.03, 0.12), (0, 0.145, -0.04), "v"), ((0.31, 0.31, 0.07), (0, 0, -0.24), "p")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k"), ((0.30, 0.36, 0.04), (0, 0, 0.0), "p")])
    limpar()
    mar = mat("Couro", (0.40, 0.24, 0.12), 0.0, 0.8); pe = mat("Pelo", (0.93, 0.86, 0.70), 0.0, 1.0); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6); az = mat("Lente", (0.30, 0.70, 0.95), 0.2, 0.1)
    g = 0.045
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Topo", (larg, prof, 0.09), (0, 0, 0.045), mar), caixa("Tras", (larg, 0.08, 0.50), (0, -prof * 0.5 + 0.04, -0.20), mar), caixa("Borda", (larg + 0.04, 0.08, 0.08), (0, prof * 0.5 - 0.04, -0.02), pe), caixa("Tira", (larg + 0.01, prof + 0.01, 0.06), (0, 0, -0.10), pr),
         caixa("Aro", (0.52, 0.07, 0.20), (0, prof * 0.5 + 0.03, -0.12), pr), caixa("Lente", (0.44, 0.075, 0.14), (0, prof * 0.5 + 0.034, -0.12), az)]
    for sx in (1, -1):
        p += [caixa("Aba", (0.10, 0.50, 0.46), (sx * (larg * 0.5 + 0.04), -0.0, -0.26), pe), caixa("AbaForro", (0.11, 0.30, 0.30), (sx * (larg * 0.5 + 0.045), 0.0, -0.30), mar)]
    exportar(p, "acessorios", "chapeu_polar")


def pirata_neve():
    mats = {"c": ("Casaco", (0.50, 0.68, 0.84), 0.0, 0.8), "p": ("Pelo", (0.97, 0.98, 1.0), 0.0, 1.0), "o": ("Ouro", (0.92, 0.74, 0.25), 0.85, 0.35), "v": ("Vinco", (0.32, 0.50, 0.68), 0.0, 0.8), "k": ("Couro", (0.38, 0.22, 0.10), 0.0, 0.75)}
    tronco = _tronco_aberto("c") + [((0.62, 0.44, 0.08), (0, 0, 0.30), "p"), ((0.16, 0.06, 0.40), (0.12, 0.215, 0.06), "p"), ((0.16, 0.06, 0.40), (-0.12, 0.215, 0.06), "p"), ((0.58, 0.40, 0.05), (0, 0, -0.26), "k"), ((0.08, 0.05, 0.07), (0, 0.22, -0.26), "o"),
              ((0.03, 0.385, 0.58), (0.0375, 0, -0.04), "o"), ((0.03, 0.385, 0.58), (-0.0375, 0, -0.04), "o"), ((0.12, 0.04, 0.12), (0.22, 0.2, 0.08), "p")]
    for sx in (1, -1):
        tronco += [((0.16, 0.40, 0.04), (sx * 0.27, 0, 0.26), "o"), ((0.10, 0.12, 0.07), (sx * 0.27, 0, 0.22), "p")]
    sup, inf = _bracos("c")
    vestir("pirata_neve", mats, tronco=tronco, saia=_saia_aberta("c") + [((0.59, 0.38, 0.06), (0, 0, -0.62), "p"), ((0.03, 0.385, 0.80), (0.0425, 0, -0.23), "o"), ((0.03, 0.385, 0.80), (-0.0425, 0, -0.23), "o"), ((0.02, 0.055, 0.30), (0, -0.18, -0.50), "v")],
           manga_sup=sup + [((0.31, 0.31, 0.04), (0, 0, -0.03), "o")], manga_inf=inf + [((0.34, 0.34, 0.09), (0, 0, -0.15), "p"), ((0.35, 0.35, 0.025), (0, 0, -0.10), "o")])
    limpar()
    br = mat("Chapeu", (0.95, 0.97, 0.99), 0.0, 0.8); ou = mat("Ouro", (0.92, 0.74, 0.25), 0.85, 0.35); az = mat("Gelo", (0.60, 0.80, 0.95), 0.0, 0.5)
    p = [caixa("Copa", (0.50, 0.66, 0.15), (0, 0, 0.085), br), caixa("Aba", (0.74, 0.96, 0.04), (0, 0, 0.0), br)]
    for sx in (1, -1):
        p += [caixa("AbaLado", (0.05, 0.86, 0.11), (sx * 0.385, 0, 0.065), br), caixa("AbaLadoOuro", (0.055, 0.88, 0.025), (sx * 0.385, 0, 0.125), ou)]
    p += [caixa("AbaFrente", (0.60, 0.05, 0.13), (0, 0.48, 0.075), br), caixa("AbaFrenteOuro", (0.62, 0.055, 0.025), (0, 0.48, 0.14), ou), caixa("Timao", (0.12, 0.03, 0.12), (0, 0.51, 0.08), ou), caixa("TimaoMeio", (0.05, 0.035, 0.05), (0, 0.52, 0.08), br)]
    for k in range(5):
        p.append(caixa("Pena%d" % k, (0.06, 0.04, 0.09), (0.28 + k * 0.04, 0.10 - k * 0.04, 0.12 + k * 0.08), az))
    exportar(p, "acessorios", "chapeu_pirata_neve")


def pizzaiolo():
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9); vm = mat("Gravata", (0.82, 0.10, 0.12), 0.0, 0.8)
    p = [caixa("Peito", (0.28, 0.04, 0.26), (0, 0.205, 0.10), br), caixa("Saia", (0.50, 0.04, 0.50), (0, 0.205, -0.20), br), caixa("Cinta", (0.58, 0.40, 0.04), (0, 0, -0.04), vm), caixa("Laco", (0.16, 0.06, 0.10), (0, 0.22, -0.04), vm),
         caixa("T1", (0.06, 0.05, 0.20), (0.05, 0.22, -0.16), vm), caixa("T2", (0.06, 0.05, 0.18), (-0.05, 0.22, -0.15), vm)]
    for k in range(4):
        for j in range(4):
            if (k + j) % 2 == 0:
                p.append(caixa("Xadrez", (0.11, 0.045, 0.11), (-0.17 + k * 0.115, 0.207, -0.43 + j * 0.12 + 0.16), vm))
    for sx in (1, -1):
        p += [caixa("Alca", (0.05, 0.04, 0.30), (sx * 0.12, 0.205, 0.17), vm), caixa("AlcaO", (0.05, 0.40, 0.03), (sx * 0.12, 0, 0.255), vm), caixa("AlcaT", (0.05, 0.03, 0.46), (sx * 0.12, -0.195, 0.02), vm)]
    exportar(p, "acessorios", "avental_xadrez")
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.95); vm = mat("Gravata", (0.82, 0.10, 0.12), 0.0, 0.8)
    p = [caixa("Aba", (0.52, 0.76, 0.10), (0, 0, 0.05), br), caixa("Faixa", (0.54, 0.78, 0.04), (0, 0, 0.08), vm)]
    for i in range(5):
        p.append(caixa("Prega", (0.10, 0.62, 0.30 + 0.02 * (i % 2)), (-0.19 + i * 0.095, 0, 0.26), br))
    p.append(caixa("Topo", (0.50, 0.70, 0.06), (0, 0, 0.43), br))
    exportar(p, "acessorios", "toque_pizzaiolo")


def ciclista():
    mats = {"c": ("Casaco", (0.92, 0.12, 0.45), 0.0, 0.7), "o": ("Ouro", (0.98, 0.60, 0.10), 0.0, 0.6), "y": ("Espinho", (0.88, 0.96, 0.18), 0.0, 0.5), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7), "b": ("Branco", (0.96, 0.96, 0.98), 0.0, 0.7)}
    tronco = _base("c") + [((0.30, 0.30, 0.06), (0, 0, 0.27), "k"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "y"), ((0.20, 0.04, 0.30), (0.1, -0.19, 0.04), "o"), ((0.575, 0.385, 0.04), (0, 0, -0.28), "y")]
    for k in range(3):
        tronco.append(((0.22 - 0.04 * k, 0.375, 0.06), (0.14 - k * 0.0, 0, 0.18 - k * 0.12), "o"))
    vestir("ciclista", mats, tronco=tronco, manga_sup=[((0.30, 0.30, 0.20), (0, 0, -0.07), "c"), ((0.31, 0.31, 0.03), (0, 0, -0.17), "y")], cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "k")],
           coxa=[((0.26, 0.26, 0.28), (0, 0, -0.14), "k"), ((0.27, 0.27, 0.03), (0, 0, -0.27), "c"), ((0.02, 0.27, 0.28), (0.12, 0, -0.14), "y")], canela=[((0.26, 0.26, 0.12), (0, 0, -0.06), "k")] if False else [((0.27, 0.27, 0.10), (0, 0, -0.20), "b"), ((0.275, 0.275, 0.03), (0, 0, -0.14), "y")],
           pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "b"), ((0.25, 0.04, 0.03), (0, 0.1, -0.02), "k")])
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.98), 0.0, 0.5); am = mat("Espinho", (0.88, 0.96, 0.18), 0.0, 0.4); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.6)
    g = 0.04
    larg, prof = CAB_L + g * 2, CAB_P + g * 2
    p = [caixa("Casco", (larg, prof, 0.12), (0, 0, 0.06), br), caixa("Topo", (larg - 0.1, prof - 0.12, 0.06), (0, 0, 0.15), br), caixa("Crista", (0.08, prof - 0.04, 0.04), (0, 0, 0.19), am), caixa("Visor", (larg, 0.10, 0.05), (0, prof * 0.5 + 0.03, 0.0), br),
         caixa("Tira", (0.03, 0.04, 0.30), (0.17, prof * 0.5 - 0.1, -0.15), pr), caixa("Tira2", (0.03, 0.04, 0.30), (-0.17, prof * 0.5 - 0.1, -0.15), pr), caixa("Queixo", (0.30, 0.04, 0.04), (0, prof * 0.5 - 0.1, -0.31), pr)]
    for k in range(4):
        p.append(caixa("Abertura", (0.06, prof - 0.04, 0.02), (-0.15 + k * 0.1, 0, 0.12), pr))
    exportar(p, "acessorios", "capacete_ciclista")


def mawashi_sumo():
    limpar()
    az = mat("Casaco", (0.10, 0.16, 0.40), 0.0, 0.85); es = mat("Vinco", (0.06, 0.10, 0.28), 0.0, 0.85)
    p = [caixa("Cinto", (0.57, 0.36, 0.14), (0, 0, 0.06), az), caixa("Frente", (0.22, 0.05, 0.26), (0, 0.19, -0.08), az), caixa("Tras", (0.30, 0.05, 0.24), (0, -0.19, -0.04), az), caixa("No", (0.20, 0.10, 0.16), (0, -0.24, 0.06), es),
         caixa("Dobra", (0.58, 0.37, 0.03), (0, 0, 0.115), es)]
    exportar(p, "acessorios", "mawashi_sumo")


def yoga():
    mats = {"c": ("Casaco", (0.90, 0.90, 0.92), 0.0, 0.95), "v": ("Vinco", (0.74, 0.74, 0.78), 0.0, 0.95), "t": ("Turquesa", (0.10, 0.52, 0.52), 0.0, 0.9)}
    tronco = [((0.60, 0.42, 0.48), (0, 0, -0.04), "c"), ((0.34, 0.34, 0.08), (0, 0, 0.27), "c"), ((0.04, 0.05, 0.14), (0, 0.22, -0.30), "v"), ((0.60, 0.42, 0.03), (0, 0, -0.29), "v")]
    sup = [((0.34, 0.34, 0.34), (0, 0, -0.15), "c")]; inf = [((0.33, 0.33, 0.21), (0, 0, -0.105), "c"), ((0.34, 0.34, 0.03), (0, 0, -0.20), "v")]
    vestir("yoga", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "t"), ((0.55, 0.31, 0.03), (0, 0, 0.15), "v")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "t"), ((0.02, 0.27, 0.36), (0.1, 0, -0.18), "v")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "t"), ((0.02, 0.27, 0.285), (0.1, 0, -0.1425), "v")])
    limpar()
    tq = mat("Turquesa", (0.10, 0.52, 0.52), 0.0, 0.9)
    p = [caixa("Faixa", (0.55, 0.78, 0.10), (0, 0, -0.06), tq), caixa("No", (0.12, 0.06, 0.12), (0.0, P * 0.5 + 0.04, -0.06), tq), caixa("Ponta", (0.06, 0.05, 0.14), (-0.07, P * 0.5 + 0.05, -0.14), tq), caixa("Ponta2", (0.06, 0.05, 0.12), (0.07, P * 0.5 + 0.05, -0.13), tq)]
    exportar(p, "acessorios", "faixa_yoga")


def goleiro():
    mats = {"c": ("Casaco", (0.45, 0.92, 0.12), 0.0, 0.8), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7), "b": ("Branco", (0.96, 0.96, 0.98), 0.0, 0.8), "v": ("Vinco", (0.30, 0.66, 0.08), 0.0, 0.8)}
    tronco = _base("c") + [((0.30, 0.30, 0.06), (0, 0, 0.27), "k"), ((0.03, 0.375, 0.55), (-0.18, 0, -0.04), "v"), ((0.03, 0.375, 0.55), (0.18, 0, -0.04), "v"), ((0.575, 0.385, 0.04), (0, 0, -0.28), "k")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c"), ((0.03, 0.30, 0.34), (0.1, 0, -0.15), "k")]
    inf = [(MANGA_INF[0], MANGA_INF[1], "c"), ((0.31, 0.31, 0.06), (0, 0, -0.16), "k"), ((0.03, 0.30, 0.21), (0.1, 0, -0.105), "k")]
    vestir("goleiro", mats, tronco=tronco, manga_sup=sup, manga_inf=inf, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "k")], coxa=[((0.28, 0.28, 0.30), (0, 0, -0.15), "k")],
           canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "b"), ((0.27, 0.27, 0.04), (0, 0, -0.10), "k"), ((0.27, 0.27, 0.04), (0, 0, -0.18), "k")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    br = mat("Branco", (0.96, 0.96, 0.98), 0.0, 0.7); vd = mat("Verde", (0.45, 0.92, 0.12), 0.0, 0.7); pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)
    p = [caixa("Punho", (0.30, 0.30, 0.08), (0, 0, 0.05), pr), caixa("Palma", (0.30, 0.20, 0.20), (0, 0.0, -0.10), br), caixa("Dedos", (0.30, 0.22, 0.12), (0, 0.0, -0.24), br), caixa("Topo", (0.30, 0.04, 0.30), (0, -0.12, -0.14), vd),
         caixa("Polegar", (0.08, 0.14, 0.14), (0.18, 0.04, -0.10), br)]
    for k in range(3):
        p.append(caixa("Listra", (0.03, 0.21, 0.30), (-0.08 + k * 0.08, 0.0, -0.14), vd)) if False else None
    exportar(p, "acessorios", "luvas_goleiro")


def cabelo_marias_chiquinhas():
    import random
    limpar()
    random.seed(40)
    cab = mat("Cabelo", NEUTRO, 0.0, 0.92); el = mat("Elastico", (0.30, 0.18, 0.10), 0.0, 0.7)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.92, P * 0.86, 0.07), (0, -0.01, 0.04), cab), caixa("Franja", (L + 0.02, 0.08, 0.17), (0, P * 0.5 - 0.005, -0.085), cab),
         caixa("Costas", (L + 0.03, 0.12, 0.32), (0, -(P * 0.5 - 0.05), -0.16), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.64, 0.28), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.14), cab))
        p.append(caixa("Elo", (0.09, 0.12, 0.05), (sx * 0.34, -0.12, 0.02), el))
        for i in range(8):
            a = random.uniform(0, 6.283)
            import math
            p.append(caixa("Cacho", (0.15, 0.15, 0.15), (sx * 0.42 + 0.07 * math.cos(a), -0.12 + 0.07 * math.sin(a), -0.10 - random.uniform(0.0, 0.26)), cab))
    exportar(p, "cabelos", "cabelo_marias_chiquinhas")


def fazendeiro():
    mats = {"c": ("Casaco", (0.16, 0.32, 0.62), 0.0, 0.9), "v": ("Vinco", (0.10, 0.22, 0.45), 0.0, 0.9), "o": ("Ouro", (0.85, 0.65, 0.20), 0.8, 0.4), "g": ("Espinho", (0.30, 0.45, 0.20), 0.0, 0.8)}
    tronco = [((0.30, 0.04, 0.26), (0, 0.205, 0.10), "c"), ((0.50, 0.04, 0.30), (0, 0.205, -0.16), "c"), ((0.56, 0.04, 0.30), (0, -0.205, -0.16), "c"), ((0.16, 0.05, 0.12), (0, 0.215, -0.14), "v"), ((0.58, 0.40, 0.04), (0, 0, -0.30), "v")]
    for sx in (1, -1):
        tronco += [((0.06, 0.04, 0.34), (sx * 0.14, 0.205, 0.18), "c"), ((0.06, 0.40, 0.03), (sx * 0.14, 0, 0.255), "c"), ((0.06, 0.04, 0.46), (sx * 0.14, -0.205, 0.04), "c"), ((0.05, 0.05, 0.05), (sx * 0.14, 0.22, 0.20), "o")]
    vestir("fazendeiro", mats, tronco=tronco, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.27, 0.27, 0.36), (0, 0, -0.18), "c"), ((0.10, 0.04, 0.12), (0.1, 0.14, -0.1), "v")],
           canela=[((0.27, 0.27, 0.285), (0, 0, -0.1425), "c"), ((0.285, 0.285, 0.04), (0, 0, -0.25), "v")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "g")])
    limpar()
    gr = mat("Verde", (0.30, 0.45, 0.20), 0.0, 0.8)
    exportar([caixa("Bota", (0.28, 0.28, 0.22), (0, 0, 0.12), gr), caixa("Sola", (0.30, 0.36, 0.05), (0, 0.0, -0.075), mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.7)), caixa("Bico", (0.26, 0.10, 0.08), (0, 0.19, -0.03), gr),
              caixa("Boca", (0.30, 0.30, 0.03), (0, 0, 0.24), mat("VerdeEscuro", (0.20, 0.32, 0.14), 0.0, 0.8))], "acessorios", "botas_borracha")


def patinador():
    mats = {"c": ("Casaco", (0.16, 0.32, 0.85), 0.0, 0.4), "v": ("Vinco", (0.50, 0.70, 0.98), 0.0, 0.3), "b": ("Branco", (0.92, 0.96, 1.0), 0.0, 0.3)}
    tronco = [((0.52, 0.355, 0.52), (0, 0, -0.06), "c"), ((0.34, 0.33, 0.07), (0, 0, 0.27), "b"), ((0.12, 0.04, 0.24), (0, 0.19, 0.04), "v"), ((0.12, 0.04, 0.24), (0, -0.19, 0.04), "v"), ((0.575, 0.385, 0.04), (0, 0, -0.30), "b")]
    saia = [((0.60, 0.40, 0.08), (0, 0, 0.13), "c")]
    for i, (w, d, z) in enumerate([(0.74, 0.50, 0.04), (0.88, 0.62, -0.08), (0.98, 0.72, -0.18)]):
        saia.append(((w, d, 0.12), (0, 0, z), "v" if i % 2 else "c"))
    vestir("patinador", mats, tronco=tronco, saia=saia, manga_sup=[((0.29, 0.29, 0.34), (0, 0, -0.15), "v")], manga_inf=[((0.28, 0.28, 0.21), (0, 0, -0.105), "v"), ((0.29, 0.29, 0.03), (0, 0, -0.20), "b")])


def dj():
    mats = {"c": ("Casaco", (0.48, 0.12, 0.80), 0.0, 0.5), "n": ("Neon", (0.82, 0.40, 1.0), 0.0, 0.3), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7), "v": ("Vinco", (0.32, 0.08, 0.55), 0.0, 0.5)}
    tronco = _tronco_aberto("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.14, 0.04, 0.50), (0, 0.195, -0.04), "k"), ((0.03, 0.05, 0.50), (0.075, 0.205, -0.04), "n"), ((0.03, 0.05, 0.50), (-0.075, 0.205, -0.04), "n"),
              ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
              ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "v"), ((0.03, 0.02, 0.46), (0, -0.37, 0.50), "n"), ((0.03, 0.60, 0.03), (0, -0.01, 0.855), "n"), ((0.58, 0.40, 0.05), (0, 0, -0.30), "k")]
    sup, inf = _bracos("c")
    vestir("dj", mats, tronco=tronco, manga_sup=sup + [((0.03, 0.30, 0.34), (0.15, 0, -0.15), "n")], manga_inf=inf + [((0.31, 0.31, 0.06), (0, 0, -0.17), "v"), ((0.03, 0.30, 0.21), (0.15, 0, -0.105), "n")])
    limpar()
    k = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.5); n = mat("Neon", (0.82, 0.40, 1.0), 0.0, 0.3)
    b = next(x for x in n.node_tree.nodes if x.type == "BSDF_PRINCIPLED"); b.inputs["Emission Color"].default_value = (0.82, 0.4, 1.0, 1.0); b.inputs["Emission Strength"].default_value = 2.5
    p = [caixa("Arco", (0.64, 0.12, 0.06), (0, 0, 0.05), k), caixa("ArcoNeon", (0.60, 0.13, 0.025), (0, 0, 0.09), n)]
    for sx in (1, -1):
        p += [caixa("Haste", (0.05, 0.10, 0.28), (sx * 0.31, 0, -0.10), k), caixa("Concha", (0.12, 0.26, 0.26), (sx * 0.34, -0.02, -0.26), k), caixa("Anel", (0.125, 0.18, 0.18), (sx * 0.35, -0.02, -0.26), n), caixa("Pad", (0.04, 0.2, 0.2), (sx * 0.29, -0.02, -0.26), k)]
    exportar(p, "acessorios", "fones_dj_neon")
    limpar()
    k = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.7); n2 = mat("Neon", (0.82, 0.40, 1.0), 0.0, 0.3)
    exportar([caixa("Punho", (0.26, 0.26, 0.07), (0, 0, 0.04), k), caixa("Palma", (0.21, 0.16, 0.11), (0, 0, -0.055), k), caixa("Faixa", (0.27, 0.27, 0.02), (0, 0, 0.0), n2)], "acessorios", "luvas_dj")


def cabelo_longo_laco():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95); vm = mat("Fita", (0.85, 0.08, 0.10), 0.0, 0.7)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Franja", (L + 0.02, 0.09, 0.22), (0, P * 0.5 - 0.005, -0.11), cab), caixa("Costas", (L + 0.03, 0.13, 1.00), (0, -(P * 0.5 - 0.05), -0.50), cab), caixa("Ponta", (L * 0.7, 0.12, 0.10), (0, -(P * 0.5 - 0.05), -1.04), cab)]
    for sx in (1, -1):
        p += [caixa("Lado", (0.09, P * 0.62, 0.9), (sx * (L * 0.5 + 0.02), -P * 0.12, -0.45), cab), caixa("Mecha", (0.09, 0.10, 0.70), (sx * (L * 0.5 + 0.02), P * 0.5 - 0.08, -0.34), cab),
              caixa("LacoAsa", (0.26, 0.10, 0.20), (sx * 0.15, 0.0, 0.16), vm), caixa("LacoBorda", (0.27, 0.105, 0.03), (sx * 0.15, 0.0, 0.26), vm)]
    p.append(caixa("LacoNo", (0.12, 0.12, 0.12), (0, 0.0, 0.14), vm))
    exportar(p, "cabelos", "cabelo_longo_laco")


def cabelo_sabio_barba():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.95)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Franja", (L + 0.02, 0.09, 0.16), (0, P * 0.5 - 0.005, -0.08), cab), caixa("Costas", (L + 0.03, 0.13, 1.1), (0, -(P * 0.5 - 0.05), -0.55), cab)]
    for sx in (1, -1):
        p += [caixa("Lado", (0.09, P * 0.62, 0.9), (sx * (L * 0.5 + 0.02), -P * 0.12, -0.45), cab), caixa("Costeleta", (0.09, 0.10, 0.40), (sx * (L * 0.5 + 0.02), P * 0.5 - 0.08, -0.25), cab)]
    for i, (w, z, y) in enumerate(((0.50, -0.32, 0.34), (0.44, -0.52, 0.36), (0.36, -0.72, 0.37), (0.28, -0.90, 0.37), (0.18, -1.04, 0.37))):
        p.append(caixa("Barba%d" % i, (w, 0.12, 0.20), (0, y, z), cab))
    p.append(caixa("Bigode", (0.36, 0.09, 0.07), (0, 0.38, -0.20), cab))
    exportar(p, "cabelos", "cabelo_sabio_barba")


def cabelo_azul_topete_raspado():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.85)
    p = [caixa("Casca", (L, P, 0.04), (0, 0, -0.02), cab), caixa("Nuca", (L, 0.05, 0.12), (0, -(P * 0.5 - 0.025), -0.06), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.035, P * 0.58, 0.12), (sx * (L * 0.5 - 0.0175), -P * 0.12, -0.06), cab))
    for i in range(6):
        p.append(caixa("Topete%d" % i, (0.26 - 0.01 * i, 0.20, 0.10), (0.0, P * 0.30 - i * 0.12, 0.05 + 0.03 * i), cab))
    for i in range(5):
        p.append(caixa("Onda%d" % i, (0.14, 0.14, 0.08), (-0.1 + i * 0.05, P * 0.45 - i * 0.04, 0.14 + 0.01 * i), cab))
    exportar(p, "cabelos", "cabelo_azul_topete_raspado")


def cabelo_duas_trancas_longas():
    limpar()
    cab = mat("Cabelo", NEUTRO, 0.0, 0.92); el = mat("Elastico", (0.85, 0.85, 0.88), 0.2, 0.6)
    p = [caixa("Calota", (L + 0.02, P + 0.02, 0.11), (0, 0, -0.045), cab), caixa("Volume", (L * 0.92, P * 0.86, 0.07), (0, -0.01, 0.04), cab), caixa("Franja", (L + 0.02, 0.08, 0.17), (0, P * 0.5 - 0.005, -0.085), cab),
         caixa("Costas", (L + 0.03, 0.12, 0.34), (0, -(P * 0.5 - 0.05), -0.17), cab)]
    for sx in (1, -1):
        p.append(caixa("Lado", (0.08, P * 0.64, 0.28), (sx * (L * 0.5 + 0.01), -P * 0.12, -0.14), cab))
        for j in range(12):
            dx = 0.025 if j % 2 else -0.025
            p.append(caixa("Tranca%d" % j, (0.12, 0.11, 0.095), (sx * 0.20 + dx, P * 0.5 - 0.18, -0.34 - j * 0.085), cab))
        p.append(caixa("Elo", (0.10, 0.12, 0.04), (sx * 0.20, P * 0.5 - 0.18, -1.38), el))
    exportar(p, "cabelos", "cabelo_duas_trancas_longas")


# ======================================================================= lote 14
def escoteiro():
    mats = {"c": ("Casaco", (0.76, 0.62, 0.40), 0.0, 0.9), "r": ("Gravata", (0.78, 0.12, 0.14), 0.0, 0.8), "k": ("Couro", (0.40, 0.24, 0.12), 0.0, 0.75), "o": ("Ouro", (0.88, 0.68, 0.22), 0.8, 0.4), "b": ("Branco", (0.93, 0.88, 0.74), 0.0, 0.9)}
    tronco = _base("c") + [((0.34, 0.33, 0.06), (0, 0, 0.27), "c"), ((0.40, 0.34, 0.14), (0, -0.02, 0.27), "r"), ((0.10, 0.05, 0.26), (0.0, 0.205, 0.12), "r"), ((0.04, 0.04, 0.50), (0.0, 0.195, -0.04), "k"), ((0.13, 0.05, 0.13), (0.15, 0.2, 0.0), "c"), ((0.13, 0.05, 0.13), (-0.15, 0.2, 0.0), "c"),
                           ((0.58, 0.40, 0.04), (0, 0, -0.27), "k"), ((0.07, 0.05, 0.06), (0, 0.22, -0.27), "o")]
    sup = [(MANGA_SUP[0], MANGA_SUP[1], "c")] + [((0.30, 0.30, 0.05), (0, 0, -0.20), "c")]
    vestir("escoteiro", mats, tronco=tronco, manga_sup=[((0.30, 0.30, 0.20), (0, 0, -0.07), "c"), ((0.31, 0.31, 0.03), (0, 0, -0.17), "k")], cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "k")],
           coxa=[((0.28, 0.28, 0.30), (0, 0, -0.15), "k")], canela=[((0.28, 0.28, 0.12), (0, 0, -0.06), "k")] if False else [((0.27, 0.27, 0.10), (0, 0, -0.22), "b")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    be = mat("Chapeu", (0.58, 0.42, 0.20), 0.0, 0.85); es = mat("Fita", (0.34, 0.20, 0.10), 0.0, 0.85); ou = mat("Ouro", (0.88, 0.68, 0.22), 0.8, 0.4)
    exportar([caixa("Aba", (0.80, 0.96, 0.035), (0, 0, 0.0), be), caixa("Copa", (0.50, 0.64, 0.16), (0, 0, 0.10), be), caixa("Topo", (0.44, 0.58, 0.04), (0, 0, 0.19), be), caixa("Fita", (0.52, 0.66, 0.05), (0, 0, 0.065), es), caixa("Fivela", (0.07, 0.04, 0.06), (0, 0.335, 0.065), ou)], "acessorios", "chapeu_escoteiro")


def piloto_comercial():
    mats = {"c": ("Casaco", (0.07, 0.10, 0.30), 0.0, 0.7), "o": ("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4), "b": ("Branco", (0.96, 0.96, 0.98), 0.0, 0.9), "k": ("Preto", (0.05, 0.05, 0.07), 0.0, 0.7), "v": ("Vinco", (0.12, 0.16, 0.42), 0.0, 0.7)}
    tronco = _tronco_aberto("c", 0.58, -0.04) + [((0.12, 0.04, 0.44), (0, 0.195, 0.0), "b"), ((0.30, 0.30, 0.06), (0, 0, 0.27), "b"), ((0.05, 0.05, 0.28), (0, 0.215, 0.07), "v"), ((0.34, 0.05, 0.05), (0, 0.205, 0.20), "v"), ((0.07, 0.05, 0.07), (0.13, 0.205, 0.10), "o")]
    for sx in (1, -1):
        for k in range(3):
            tronco.append(((0.04, 0.05, 0.04), (sx * 0.075, 0.215, 0.10 - k * 0.12), "o"))
    sup, inf = _bracos("c")
    cuff = [((0.30, 0.30, 0.025), (0, 0, -0.10 - 0.04 * k), "o") for k in range(3)]
    vestir("piloto_comercial", mats, tronco=tronco, saia=_saia_aberta("c", 0.40, -0.06), manga_sup=sup, manga_inf=inf + cuff, cintura=[((0.53, 0.30, 0.15), (0, 0, 0.09), "c")], coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "c")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "c")], pe=[((0.28, 0.34, 0.11), (0, 0, -0.05), "k")])
    limpar()
    az = mat("Azul", (0.07, 0.10, 0.30), 0.0, 0.75); ou = mat("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4); pr = mat("Preto", (0.05, 0.05, 0.07), 0.0, 0.7)
    exportar([caixa("Copa", (0.54, 0.76, 0.16), (0, 0, 0.08), az), caixa("Topo", (0.50, 0.72, 0.04), (0, 0, 0.18), az), caixa("Faixa", (0.56, 0.78, 0.035), (0, 0, 0.035), ou), caixa("Viseira", (0.36, 0.22, 0.03), (0, P * 0.5 + 0.10, 0.0), pr),
              caixa("Emblema", (0.12, 0.03, 0.08), (0, P * 0.5 + 0.02, 0.10), ou), caixa("AsaE", (0.07, 0.03, 0.03), (-0.09, P * 0.5 + 0.025, 0.10), ou), caixa("AsaD", (0.07, 0.03, 0.03), (0.09, P * 0.5 + 0.025, 0.10), ou)], "acessorios", "quepe_piloto")


def formatura():
    mats = {"c": ("Casaco", (0.07, 0.07, 0.09), 0.0, 0.85), "v": ("Vinco", (0.14, 0.14, 0.17), 0.0, 0.85)}
    tronco = _tronco_aberto("c") + [((0.40, 0.30, 0.10), (0, 0, 0.29), "v"), ((0.16, 0.05, 0.40), (0.12, 0.205, 0.06), "v"), ((0.16, 0.05, 0.40), (-0.12, 0.205, 0.06), "v"), ((0.60, 0.10, 0.22), (0, -0.20, 0.16), "v")]
    saia = _saia_aberta("c", 0.84, -0.25) + [((0.59, 0.38, 0.03), (0, 0, -0.66), "v")]
    for i in range(6):
        saia.append(((0.02, 0.381, 0.80), (-0.25 + i * 0.1, 0, -0.23), "v"))
    vestir("formatura", mats, tronco=tronco, saia=saia, manga_sup=[((0.31, 0.31, 0.34), (0, 0, -0.15), "c")], manga_inf=[((0.36, 0.36, 0.21), (0, 0, -0.105), "c"), ((0.37, 0.37, 0.03), (0, 0, -0.20), "v")])
    limpar()
    pr = mat("Preto", (0.07, 0.07, 0.09), 0.0, 0.85); ou = mat("Ouro", (0.92, 0.74, 0.22), 0.8, 0.4)
    exportar([caixa("Base", (0.54, 0.76, 0.08), (0, 0, 0.04), pr), caixa("Tampo", (0.76, 0.76, 0.03), (0, 0, 0.10), pr), caixa("Botao", (0.06, 0.06, 0.03), (0, 0, 0.13), ou), caixa("Fio", (0.20, 0.03, 0.025), (0.12, 0, 0.12), ou),
              caixa("Fio2", (0.025, 0.03, 0.20), (0.25, 0.0, 0.0), ou), caixa("Borla", (0.05, 0.05, 0.10), (0.25, 0.0, -0.12), ou)], "acessorios", "capelo_formatura")


def confeiteiro():
    limpar()
    rs = mat("Rosa", (0.96, 0.58, 0.72), 0.0, 0.85); cl = mat("RosaClaro", (0.98, 0.78, 0.86), 0.0, 0.85); br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.9)
    p = [caixa("Peito", (0.28, 0.04, 0.26), (0, 0.205, 0.10), rs), caixa("Saia", (0.50, 0.04, 0.52), (0, 0.205, -0.20), rs), caixa("Bolso", (0.24, 0.05, 0.14), (0, 0.22, -0.18), cl), caixa("Barra", (0.52, 0.045, 0.04), (0, 0.205, -0.45), cl),
         caixa("Cinta", (0.58, 0.40, 0.04), (0, 0, -0.04), cl), caixa("Laco", (0.18, 0.06, 0.10), (0, -0.215, -0.04), rs), caixa("T1", (0.06, 0.05, 0.28), (0.05, -0.215, -0.24), rs), caixa("T2", (0.06, 0.05, 0.26), (-0.05, -0.215, -0.22), rs)]
    for sx in (1, -1):
        p += [caixa("Alca", (0.05, 0.04, 0.30), (sx * 0.12, 0.205, 0.17), rs), caixa("AlcaO", (0.05, 0.40, 0.03), (sx * 0.12, 0, 0.255), rs), caixa("AlcaT", (0.05, 0.03, 0.46), (sx * 0.12, -0.195, 0.02), rs)]
    exportar(p, "acessorios", "avental_rosa")
    limpar()
    br = mat("Branco", (0.97, 0.97, 0.98), 0.0, 0.95); rs = mat("Rosa", (0.96, 0.58, 0.72), 0.0, 0.85)
    p = [caixa("Aba", (0.52, 0.76, 0.10), (0, 0, 0.05), br), caixa("Faixa", (0.54, 0.78, 0.04), (0, 0, 0.08), rs)]
    for i in range(5):
        p.append(caixa("Prega", (0.10, 0.62, 0.22 + 0.02 * (i % 2)), (-0.19 + i * 0.095, 0, 0.22), br))
    p.append(caixa("Topo", (0.50, 0.70, 0.06), (0, 0, 0.35), br))
    exportar(p, "acessorios", "touca_confeiteiro")


def pescador():
    mats = {"c": ("Casaco", (0.96, 0.78, 0.08), 0.0, 0.45), "v": ("Vinco", (0.80, 0.60, 0.05), 0.0, 0.5), "k": ("Preto", (0.07, 0.07, 0.09), 0.0, 0.7), "g": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.3), "z": ("Cinza", (0.26, 0.27, 0.30), 0.0, 0.8)}
    tronco = _base("c") + [((0.34, 0.33, 0.07), (0, 0, 0.27), "v"), ((0.64, 0.10, 0.54), (0, -0.30, 0.50), "c"), ((0.64, 0.60, 0.09), (0, -0.01, 0.81), "c"), ((0.08, 0.60, 0.56), (0.32, -0.01, 0.52), "c"), ((0.08, 0.60, 0.56), (-0.32, -0.01, 0.52), "c"),
                           ((0.11, 0.09, 0.50), (0.265, 0.285, 0.50), "c"), ((0.11, 0.09, 0.50), (-0.265, 0.285, 0.50), "c"), ((0.62, 0.08, 0.11), (0, 0.285, 0.77), "c"), ((0.62, 0.04, 0.04), (0, 0.31, 0.74), "v"), ((0.03, 0.04, 0.50), (0, 0.195, -0.04), "v"),
                           ((0.14, 0.05, 0.14), (0.15, 0.205, -0.14), "v"), ((0.14, 0.05, 0.14), (-0.15, 0.205, -0.14), "v"), ((0.03, 0.02, 0.16), (0.07, 0.22, 0.20), "k"), ((0.03, 0.02, 0.16), (-0.07, 0.22, 0.20), "k")]
    sup, inf = _bracos("c")
    vestir("pescador", mats, tronco=tronco, saia=[((0.62, 0.42, 0.40), (0, 0, -0.02), "c"), ((0.63, 0.43, 0.04), (0, 0, -0.22), "v")], manga_sup=sup, manga_inf=inf + [((0.31, 0.31, 0.05), (0, 0, -0.18), "v")],
           coxa=[((0.26, 0.26, 0.36), (0, 0, -0.18), "z")], canela=[((0.26, 0.26, 0.285), (0, 0, -0.1425), "z")], pe=[((0.28, 0.34, 0.20), (0, 0, 0.0), "k"), ((0.30, 0.36, 0.04), (0, 0, -0.09), "z")])


def campista():
    mats = {"c": ("Casaco", (0.30, 0.38, 0.22), 0.0, 0.85), "v": ("Vinco", (0.20, 0.26, 0.14), 0.0, 0.85), "k": ("Couro", (0.34, 0.20, 0.10), 0.0, 0.75), "p": ("Prata", (0.80, 0.82, 0.86), 0.9, 0.3)}
    tronco = [((0.52, 0.04, 0.50), (0, 0.19, -0.02), "c"), ((0.52, 0.04, 0.50), (0, -0.19, -0.02), "c"), ((0.30, 0.04, 0.18), (0, 0.19, 0.24), "v")]
    for sx in (1, -1):
        tronco += [((0.20, 0.06, 0.20), (sx * 0.16, 0.21, 0.04), "v"), ((0.20, 0.06, 0.20), (sx * 0.16, 0.21, -0.18), "v"), ((0.06, 0.40, 0.03), (sx * 0.12, 0, 0.255), "k"), ((0.05, 0.05, 0.06), (sx * 0.16, 0.24, 0.04), "p")]
    tronco += [((0.10, 0.05, 0.10), (0.0, 0.22, 0.12), "k"), ((0.58, 0.04, 0.04), (0, 0.205, -0.28), "k")]
    vestir("campista", mats, tronco=tronco)
    limpar()
    k = mat("Couro", (0.34, 0.20, 0.10), 0.0, 0.75); vd = mat("Casaco", (0.30, 0.38, 0.22), 0.0, 0.85); es = mat("Vinco", (0.20, 0.26, 0.14), 0.0, 0.85); lu = mat("Luz", (1.0, 0.90, 0.60), 0.0, 0.3); cz = mat("Aco", (0.55, 0.58, 0.62), 0.5, 0.5); ro = mat("Rolo", (0.72, 0.58, 0.38), 0.0, 0.9)
    p = [caixa("Corpo", (0.38, 0.18, 0.44), (0, -0.30, -0.02), vd), caixa("Aba", (0.39, 0.19, 0.12), (0, -0.30, 0.22), es), caixa("BolsoB", (0.30, 0.08, 0.20), (0, -0.41, -0.10), es), caixa("Rolo", (0.40, 0.14, 0.14), (0, -0.30, 0.34), ro),
         caixa("Fivela", (0.05, 0.05, 0.05), (0, -0.405, 0.18), cz)]
    for sx in (1, -1):
        p += [caixa("Alca", (0.06, 0.04, 0.50), (sx * 0.12, 0.205, 0.0), k), caixa("AlcaO", (0.06, 0.40, 0.03), (sx * 0.12, 0, 0.255), k), caixa("AlcaT", (0.06, 0.03, 0.42), (sx * 0.12, -0.2, 0.06), k), caixa("BolsoL", (0.08, 0.14, 0.24), (sx * 0.23, -0.30, -0.06), es)]
    exportar(p, "acessorios", "mochila_camping")
    limpar()
    k = mat("Couro", (0.34, 0.20, 0.10), 0.0, 0.75); lu = mat("Luz", (1.0, 0.90, 0.60), 0.0, 0.3); cz = mat("Aco", (0.55, 0.58, 0.62), 0.5, 0.5)
    exportar([caixa("TiraF", (0.54, 0.04, 0.06), (0, P * 0.5 + 0.02, 0.03), k), caixa("TiraT", (0.54, 0.035, 0.06), (0, -P * 0.5 - 0.02, 0.03), k), caixa("TiraL1", (0.035, P, 0.06), (0.27, 0, 0.03), k), caixa("TiraL2", (0.035, P, 0.06), (-0.27, 0, 0.03), k),
              caixa("Lanterna", (0.16, 0.08, 0.10), (0.0, P * 0.5 + 0.07, 0.03), cz), caixa("Luz", (0.12, 0.03, 0.07), (0.0, P * 0.5 + 0.12, 0.03), lu)], "acessorios", "lanterna_testa")


PECAS = {
    "escoteiro": escoteiro,
    "piloto_comercial": piloto_comercial,
    "formatura": formatura,
    "confeiteiro": confeiteiro,
    "pescador": pescador,
    "campista": campista,
    "fazendeiro": fazendeiro,
    "patinador": patinador,
    "dj": dj,
    "cabelo_longo_laco": cabelo_longo_laco,
    "cabelo_sabio_barba": cabelo_sabio_barba,
    "cabelo_azul_topete_raspado": cabelo_azul_topete_raspado,
    "cabelo_duas_trancas_longas": cabelo_duas_trancas_longas,
    "pizzaiolo": pizzaiolo,
    "ciclista": ciclista,
    "mawashi_sumo": mawashi_sumo,
    "yoga": yoga,
    "goleiro": goleiro,
    "cabelo_marias_chiquinhas": cabelo_marias_chiquinhas,
    "cirurgiao": cirurgiao,
    "agente_secreto": agente_secreto,
    "cacafantasma": cacafantasma,
    "explorador_polar": explorador_polar,
    "pirata_neve": pirata_neve,
    "cacador_tesouros": cacador_tesouros,
    "detetive": detetive,
    "bombeiro_resgate": bombeiro_resgate,
    "samurai_espectral": samurai_espectral,
    "chef_sushi": chef_sushi,
    "fada_flores": fada_flores,
    "cabelo_assimetrico_mecha": cabelo_assimetrico_mecha,
    "cabelo_ruivo_ondulado_trancas": cabelo_ruivo_ondulado_trancas,
    "cabelo_louro_curto_ondulado": cabelo_louro_curto_ondulado,
    "garcom": garcom,
    "caminhoneiro": caminhoneiro,
    "rockstar": rockstar,
    "baile_azul": baile_azul,
    "princesa_guerreira": princesa_guerreira,
    "rei_elfo": rei_elfo,
    "bruxa_floresta": bruxa_floresta,
    "mecanico_espacial": mecanico_espacial,
    "aviador": aviador,
    "jardineiro": jardineiro,
    "avental_branco": avental_branco,
    "pintor": pintor,
    "carteiro": carteiro,
    "esqueleto": esqueleto,
    "mumia": mumia,
    "rei_mares": rei_mares,
    "cabelo_chonmage": cabelo_chonmage,
    "barba_curta": barba_curta,
    "peruca_barroca": peruca_barroca,
    "cabelo_spiky_curto": cabelo_spiky_curto,
    "cabelo_odango": cabelo_odango,
    "cabelo_rabo_lateral": cabelo_rabo_lateral,
    "lolita": lolita,
    "steampunk": steampunk,
    "mago_sombrio": mago_sombrio,
    "druida": druida,
    "pirata_sereia": pirata_sereia,
    "leao": leao,
    "coelha_pascoa": coelha_pascoa,
    "robo_retro": robo_retro,
    "futebol": futebol,
    "peruca_dreads_coloridos": peruca_dreads_coloridos,
    "samurai_feminina": samurai_feminina,
    "sailor": sailor,
    "punk": punk,
    "hiphop": hiphop,
    "kilt": kilt,
    "quiton_grego": quiton_grego,
    "toga_romana": toga_romana,
    "cabelo_undercut_topete": cabelo_undercut_topete,
    "hanbok": hanbok,
    "egipcio": egipcio,
    "poncho_arco_iris": poncho_arco_iris,
    "astronauta_retro": astronauta_retro,
    "cabelo_coque_rede": cabelo_coque_rede,
    "peruca_mechas_rosa_azul": peruca_mechas_rosa_azul,
    "cabelo_crespo_curto": cabelo_crespo_curto,
    "esquiador": esquiador,
    "surfista": surfista,
    "basquete": basquete,
    "flamenco": flamenco,
    "ballet": ballet,
    "sari": sari,
    "karate": karate,
    "cauboi_neon": cauboi_neon,
    "papai_noel": papai_noel,
    "noiva": noiva,
    "cabelo_azul_mechas": cabelo_azul_mechas,
    "cabelo_pixie": cabelo_pixie,
    "cabelo_rosa_topete": cabelo_rosa_topete,
    "cabelo_tranca_coroa": cabelo_tranca_coroa,
    "fantasma_pirata": fantasma_pirata,
    "armadura_cristal": armadura_cristal,
    "yukata_fogos": yukata_fogos,
    "viking_peles": viking_peles,
    "abobora": abobora,
    "cabelo_preto_franja_flores": cabelo_preto_franja_flores,
    "mergulhador": mergulhador,
    "capacete_esferico": capacete_esferico,
    "safari": safari,
    "bombeiro": bombeiro,
    "abelha": abelha,
    "cientista": cientista,
    "cabelo_cientista": cabelo_cientista,
    "orelhas_elfo": orelhas_elfo,
    "capuz_panda": capuz_panda,
    "piloto_corrida": piloto_corrida,
    "enfermagem_antiga": enfermagem_antiga,
    "lenhador": lenhador,
    "junina": junina,
    "gato_preto": gato_preto,
    "asas_anjo_grandes": asas_anjo_grandes,
    "cabelo_cornrows": cabelo_cornrows,
    "elfico_arqueiro": elfico_arqueiro,
    "oficial_vermelho": oficial_vermelho,
    "bardo": bardo,
    "kamishimo": kamishimo,
    "sacerdote": sacerdote,
    "presas_vampiro": presas_vampiro,
    "capa_vampiro": capa_vampiro,
    "chifres_diabinho": chifres_diabinho,
    "cauda_diabo": cauda_diabo,
    "peruca_arco_iris": peruca_arco_iris,
    "cabelo_afro_puff_duplo": cabelo_afro_puff_duplo,
    "cabelo_cacheado_lenco": cabelo_cacheado_lenco,
    "cabelo_ruivo_cacheado": cabelo_ruivo_cacheado,
    "orelhas_cachorro": orelhas_cachorro,
    "coleira_couro": coleira_couro,
    "tiara_gelo": tiara_gelo,
    "capa_neve": capa_neve,
    "mascara_coruja": mascara_coruja,
    "tatuagem_braco": tatuagem_braco,
    "mascara_domino": mascara_domino,
    "cabelo_curto_volumoso": cabelo_curto_volumoso,
    "elmo_cavaleiro": elmo_cavaleiro,
    "chapeu_mago_azul": chapeu_mago_azul,
    "asas_dragao_pequenas": asas_dragao_pequenas,
    "colar_dentes": colar_dentes,
    "braceletes_dentes": braceletes_dentes,
    "bailarina_tule": bailarina_tule,
    "jaqueta_jeans": jaqueta_jeans,
    "jeans_rasgado_regata": jeans_rasgado_regata,
    "capa_super_heroi": capa_super_heroi,
    "pintura_facial_listras": pintura_facial_listras,
    "tenis_chunky_colorido": tenis_chunky_colorido,
    "botas_cauboi_esporas": botas_cauboi_esporas,
    "sandalias_gladiador": sandalias_gladiador,
    "luvas_boxe_vermelhas": luvas_boxe_vermelhas,
    "tee_estrela_shorts": tee_estrela_shorts,
    "elmo_viking_barba": elmo_viking_barba,
    "cinto_bussola_mapas": cinto_bussola_mapas,
    "aureola_neon": aureola_neon,
    "cabelo_longo_camadas": cabelo_longo_camadas,
    "roupa_aventureiro": roupa_aventureiro,
    "vestido_verao": vestido_verao,
    "cabelo_menta_rabo_baixo": cabelo_menta_rabo_baixo,
    "orelhas_lobo": orelhas_lobo,
    "cauda_lobo": cauda_lobo,
    "chifres_cervo": chifres_cervo,
    "cabelo_curto_prateado_mecha": cabelo_curto_prateado_mecha,
    "coroa_flores": coroa_flores,
    "asas_borboleta": asas_borboleta,
    "capa_viajante_remendos": capa_viajante_remendos,
    "hakama_haori": hakama_haori,
    "traje_ninja": traje_ninja,
    "roupa_medica": roupa_medica,
    "uniforme_marinha_branco": uniforme_marinha_branco,
    "tunica_monge": tunica_monge,
    "gorro_la_pompom": gorro_la_pompom,
    "colete_salva_vidas": colete_salva_vidas,
    "casaco_pirata_vermelho": casaco_pirata_vermelho,
    "papagaio_ombro": papagaio_ombro,
    "chapeu_capitao_pirata": chapeu_capitao_pirata,
    "armadura_samurai": armadura_samurai,
    "barbatana_sereia": barbatana_sereia,
    "pelucia_urso": pelucia_urso,
    "cabelo_longo_ondulado_flores": cabelo_longo_ondulado_flores,
    "cabelo_anime_azul_espetado": cabelo_anime_azul_espetado,
    "cabelo_duas_trancas_curtas": cabelo_duas_trancas_curtas,
    "fantasia_dinossauro": fantasia_dinossauro,
    "smoking_capa": smoking_capa,
    "cocar_grande_penas": cocar_grande_penas,
    "coroa_rei": coroa_rei,
    "manto_arminho": manto_arminho,
    "visor_realidade_virtual": visor_realidade_virtual,
    "asas_fada_translucidas": asas_fada_translucidas,
    "capa_mago_estrelas": capa_mago_estrelas,
    "armadura_ladino": armadura_ladino,
    "traje_astronauta": traje_astronauta,
    "roupa_chef": roupa_chef,
    "roupao_banho": roupao_banho,
    "uniforme_marinheiro": uniforme_marinheiro,
    "pijama_nuvens": pijama_nuvens,
    "macacao_mecanico": macacao_mecanico,
    "casaco_gola_felpuda": casaco_gola_felpuda,
    "monoculo_corrente": monoculo_corrente,
    "cabelo_finger_waves_curto": cabelo_finger_waves_curto,
    "boina_francesa": boina_francesa,
    "cachecol_curto_vermelho": cachecol_curto_vermelho,
    "gancho_pirata": gancho_pirata,
    "perna_de_pau": perna_de_pau,
    "cabelo_box_braids_longas": cabelo_box_braids_longas,
    "furisode_laco": furisode_laco,
    "brincos_longos_piercing": brincos_longos_piercing,
    "cabelo_rabo_cavalo_laco": cabelo_rabo_cavalo_laco,
    "capuz_gato_orelhas": capuz_gato_orelhas,
    "tiara_joias": tiara_joias,
    "polainas_arco_iris": polainas_arco_iris,
    "chapeu_panama_palha": chapeu_panama_palha,
    "joelheiras_couro": joelheiras_couro,
    "cotoveleiras_couro": cotoveleiras_couro,
    "cinto_ferramentas_bolsas": cinto_ferramentas_bolsas,
    "sueter_trico": sueter_trico,
    "orelhas_coelho": orelhas_coelho,
    "cauda_pompom": cauda_pompom,
    "jaqueta_motoqueiro": jaqueta_motoqueiro,
    "terno_blazer": terno_blazer,
    "uniforme_escolar": uniforme_escolar,
    "cicatriz_rosto": cicatriz_rosto,
    "bone_capitao_naval": bone_capitao_naval,
    "cajado_mago_mao": cajado_mago_mao,
    "machado_batalha_costas": machado_batalha_costas,
    "cauda_dragao_lagarto": cauda_dragao_lagarto,
    "tentaculos_bracos_extras": tentaculos_bracos_extras,
    "aureola_asas_anjo": aureola_asas_anjo,
    "asas_morcego_grandes": asas_morcego_grandes,
    "chapeu_cauboi": chapeu_cauboi,
    "mascara_gas_respirador": mascara_gas_respirador,
    "barba_cheia_bigode": barba_cheia_bigode,
    "cabelo_coque_alto_palitos": cabelo_coque_alto_palitos,
    "cabelo_bob_chanel_franja": cabelo_bob_chanel_franja,
    "vestido_gala": vestido_gala,
    "camisa_pirata": camisa_pirata,
    "capa_chuva_amarela": capa_chuva_amarela,
    "cabelo_mohawk_punk": cabelo_mohawk_punk,
    "kimono_yukata": kimono_yukata,
    "armadura_aco": armadura_aco,
    "mascara_oni": mascara_oni,
    "lanterna_mao": lanterna_mao,
    "escudo_redondo_costas": escudo_redondo_costas,
    "coroa_louros": coroa_louros,
    "katana_wakizashi_cintura_direita": katana_wakizashi_cintura_direita,
    "capuz_manto": capuz_manto,
    "fone_ouvido_headset": fone_ouvido_headset,
    "bainhas_duas_espadas_cruzadas": bainhas_duas_espadas_cruzadas,
    "bracadeiras_metal": bracadeiras_metal,
    "mochila_viagem": mochila_viagem,
    "colar_pingente": colar_pingente,
    "oculos_aviador_testa": oculos_aviador_testa,
    "chapeu_pirata_tricornio": chapeu_pirata_tricornio,
    "chapeu_feiticeiro_bruxa": chapeu_feiticeiro_bruxa,
    "cabelo_tranca_lateral": cabelo_tranca_lateral,
    "cabelo_rabo_duplo": cabelo_rabo_duplo,
    "cabelo_ruivo_curto_baguncado": cabelo_ruivo_curto_baguncado,
    "cachecol_longo_vermelho": cachecol_longo_vermelho,
    "botas_altas_fivelas": botas_altas_fivelas,
    "luvas_couro_garras": luvas_couro_garras,
    "ombreira_armadura": ombreira_armadura,
    "cauda_raposa": cauda_raposa,
    "jaqueta_curta": jaqueta_curta,
    "casaco_capitao": casaco_capitao,
    "bandana_faixa": bandana_faixa,
    "tapa_olho": tapa_olho,
    "asas_pequenas": asas_pequenas,
    "cabelo_afro_volumoso": cabelo_afro_volumoso,
    "chifres_oni_par": chifres_oni_par,
    "orelhas_gato_raposa": orelhas_gato_raposa,
    "capa_com_gola": capa_com_gola,
    "espada_katana": espada_katana,
    "cabelo_coque_samurai": cabelo_coque_samurai,
    "espada_larga_cerimonial": espada_larga_cerimonial,
    "cabelo_longo_liso": cabelo_longo_liso,
    "chifre_unico": chifre_unico,
}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nome in (args or PECAS):
        PECAS[nome]()
