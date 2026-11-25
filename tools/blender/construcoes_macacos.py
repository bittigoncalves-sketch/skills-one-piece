"""CONSTRUÇÕES TEMÁTICAS DA ILHA DOS MACACOS (22/11/2026). Voxel (só caixas), texturas pixel-art do Codex.

    blender -b --python tools/blender/construcoes_macacos.py [-- --previa]

Pedido do dono: a ilha só mantém árvores; construções novas só se forem temáticas. Referências do Codex em art_src/references/ilha_macacos_v2_codex/
(`construcao_*.png`) e texturas em assets/textures/ilha_macacos/. Cada modelo sai em mapas/modelos/<id>.glb (a ferramenta do Godot os registra no catálogo).
Eixos: X largura, Y profundidade (a FRENTE é −Y → +Z no jogo), Z acima; origem no centro da base (o piso do modelo em z = 0).
"""
import math
import os
import sys

import bpy

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TEX = os.path.join(RAIZ, "assets", "textures", "ilha_macacos")
LOJA = os.path.join(RAIZ, "mapas", "modelos")
PREVIAS = os.path.join(RAIZ, "art_src", "validation", "ilha_macacos", "construcoes")
FONTES = os.path.join(RAIZ, "art_src", "blender", "ilha_macacos")
LADO_DA_TEXTURA = 1.6          # m por repetição da textura 32 px (pixel-art grosso, coerente com o voxel do resto)

TEXTURAS = {"madeira": "madeira_tabua.png", "bambu": "bambu.png", "palha": "palha_telhado.png", "corda": "corda.png",
            "pedra": "pedra_trono.png", "calcada": "calcamento_musgoso.png", "terra": "terra_batida.png", "grama": "grama_praca.png"}
CORES = {"fogo": ((1.0, 0.45, 0.08, 1), 4.0), "brasa": ((0.9, 0.2, 0.05, 1), 1.5), "banana": ((0.95, 0.8, 0.12, 1), 0.0),
         "banana_verde": ((0.55, 0.7, 0.2, 1), 0.0), "folha": ((0.18, 0.5, 0.2, 1), 0.0), "folha_escura": ((0.1, 0.32, 0.14, 1), 0.0),
         "dourado": ((1.0, 0.78, 0.15, 1), 1.2), "osso": ((0.83, 0.79, 0.65, 1), 0.0), "vermelho": ((0.72, 0.14, 0.12, 1), 0.0),
         "preto": ((0.06, 0.06, 0.07, 1), 0.0), "tronco": ((0.38, 0.26, 0.14, 1), 0.0), "pano": ((0.78, 0.2, 0.15, 1), 0.0),
         "agua": ((0.3, 0.55, 0.7, 1), 0.0)}


def materiais():
    mats = {}
    for nome, arq in TEXTURAS.items():
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        nos, lig = m.node_tree.nodes, m.node_tree.links
        bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
        tex = nos.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(TEX, arq))
        tex.image.pack()
        tex.interpolation = "Closest"
        tex.extension = "REPEAT"
        lig.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 1.0
        mats[nome] = m
    for nome, (cor, brilho) in CORES.items():
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = cor
        bsdf.inputs["Roughness"].default_value = 1.0
        if brilho > 0.0:
            bsdf.inputs["Emission Color"].default_value = cor
            bsdf.inputs["Emission Strength"].default_value = brilho
        mats[nome] = m
    return mats


class Modelo:
    def __init__(self, nome, mats):
        self.nome = nome
        self.mats = mats
        self.nomes = list(mats)
        self.verts, self.faces, self.uvs, self.indices = [], [], [], []

    def caixa(self, centro, tamanho, mat):
        x, y, z = centro
        a, b, c = (v / 2 for v in tamanho)
        v = [(x - a, y - b, z - c), (x + a, y - b, z - c), (x + a, y + b, z - c), (x - a, y + b, z - c),
             (x - a, y - b, z + c), (x + a, y - b, z + c), (x + a, y + b, z + c), (x - a, y + b, z + c)]
        ini = len(self.verts)
        self.verts.extend(v)
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.faces.append(tuple(ini + i for i in f))
            self.indices.append(self.nomes.index(mat))
            # UV por projeção do mundo no eixo dominante da face, em repetições de LADO_DA_TEXTURA
            pts = [v[i] for i in f]
            eixo = ("z", "z", "y", "x", "y", "x")[len(self.faces) % 6 - 1] if False else None
            xs = {p[0] for p in pts}
            ys = {p[1] for p in pts}
            if len(zs := {p[2] for p in pts}) == 1:
                uv = [(p[0] / LADO_DA_TEXTURA, p[1] / LADO_DA_TEXTURA) for p in pts]
            elif len(ys) == 1:
                uv = [(p[0] / LADO_DA_TEXTURA, p[2] / LADO_DA_TEXTURA) for p in pts]
            else:
                uv = [(p[1] / LADO_DA_TEXTURA, p[2] / LADO_DA_TEXTURA) for p in pts]
            self.uvs.append(uv)

    def construir(self):
        malha = bpy.data.meshes.new(self.nome)
        malha.from_pydata(self.verts, [], self.faces)
        malha.update()
        uv = malha.uv_layers.new(name="UVMap")
        for poly, pts in zip(malha.polygons, self.uvs):
            for k, li in enumerate(poly.loop_indices):
                uv.data[li].uv = pts[k]
        for nome in self.nomes:
            malha.materials.append(self.mats[nome])
        for poly, i in zip(malha.polygons, self.indices):
            poly.material_index = i
        obj = bpy.data.objects.new(self.nome, malha)
        bpy.context.collection.objects.link(obj)
        return obj


# ----------------------------------------------------------------------------------------------- peças comuns
def telhado(m, w, d, z, passos=6, altura=0.5, mat="palha", beiral=1.2):
    """Telhado de palha em degraus (silhueta voxel)."""
    for i in range(passos):
        sw, sd = w + beiral * 2 - i * 1.1, d + beiral * 2 - i * 1.1
        if sw < 0.6 or sd < 0.6:
            break
        m.caixa((0, 0, z + altura / 2 + i * altura), (sw, sd, altura), mat)
    m.caixa((0, 0, z + passos * altura + 0.2), (0.7, 0.7, 0.5), "madeira")


def cabana(m, w, d, h, enfeites):
    # piso elevado e degraus
    m.caixa((0, 0, 0.3), (w + 1.2, d + 1.2, 0.6), "madeira")
    m.caixa((0, -(d / 2 + 0.9), 0.15), (2.6, 0.9, 0.3), "madeira")
    base = 0.6
    esp = 0.35
    # paredes de bambu (porta na frente)
    m.caixa((0, d / 2 - esp / 2, base + h / 2), (w, esp, h), "bambu")
    m.caixa((-(w / 2 - esp / 2), 0, base + h / 2), (esp, d, h), "bambu")
    m.caixa((w / 2 - esp / 2, 0, base + h / 2), (esp, d, h), "bambu")
    lado = (w - 2.4) / 2
    for s in (-1, 1):
        m.caixa((s * (1.2 + lado / 2), -(d / 2 - esp / 2), base + h / 2), (lado, esp, h), "bambu")
    m.caixa((0, -(d / 2 - esp / 2), base + h - 0.4), (2.4, esp, 0.8), "madeira")            # verga
    # postes de canto
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.caixa((sx * (w / 2), sy * (d / 2), base + (h + 0.8) / 2), (0.5, 0.5, h + 0.8), "madeira")
    m.caixa((0, 0, base + h + 0.2), (w + 0.6, d + 0.6, 0.4), "madeira")                       # viga de topo
    telhado(m, w, d, base + h + 0.4)
    # janelas: quadros de madeira nas laterais
    for s in (-1, 1):
        m.caixa((s * (w / 2 + 0.02), 0, base + h * 0.55), (0.12, 1.8, 1.1), "preto")
        m.caixa((s * (w / 2 + 0.06), 0, base + h * 0.55 + 0.7), (0.12, 2.1, 0.18), "madeira")
        m.caixa((s * (w / 2 + 0.06), 0, base + h * 0.55 - 0.7), (0.12, 2.1, 0.18), "madeira")
    enfeites(m, w, d, h, base)


def enfeites_geppo(m, w, d, h, base):
    # postes de treino de bambu na frente e pano vermelho
    for i, x in enumerate((-3.6, 3.6)):
        m.caixa((x, -(d / 2 + 2.2), 1.8), (0.4, 0.4, 3.6), "bambu")
        m.caixa((x, -(d / 2 + 2.2), 3.7), (0.7, 0.7, 0.3), "madeira")
    m.caixa((0, -(d / 2 + 2.2), 3.4), (7.2, 0.15, 0.7), "pano")
    m.caixa((0, -(d / 2 - 0.1), base + h + 0.1), (3.4, 0.2, 0.8), "vermelho")                  # faixa sobre a porta
    m.caixa((w / 2 + 0.9, -1.2, 0.5), (0.9, 0.9, 1.0), "madeira")                                # barril
    m.caixa((w / 2 + 0.9, 0.3, 0.5), (0.9, 0.9, 1.0), "madeira")


def enfeites_curandeiro(m, w, d, h, base):
    # ervas penduradas, potes e um canteiro
    for i, x in enumerate((-2.6, -1.3, 0.0, 1.3, 2.6)):
        m.caixa((x, -(d / 2 + 0.8), base + h - 0.9), (0.15, 0.15, 1.1), "corda")
        m.caixa((x, -(d / 2 + 0.8), base + h - 1.7), (0.5, 0.5, 0.6), "folha" if i % 2 else "folha_escura")
    for s in (-1, 1):
        m.caixa((s * (w / 2 + 1.4), -1.0, 0.5), (1.4, 1.4, 1.0), "terra")
        m.caixa((s * (w / 2 + 1.4), -1.0, 1.15), (1.2, 1.2, 0.4), "folha")
        m.caixa((s * (w / 2 + 1.4), 1.4, 0.35), (0.7, 0.7, 0.7), "calcada")


def modelo_cabana_geppo(m):
    cabana(m, 7.0, 6.0, 3.6, enfeites_geppo)


def modelo_cabana_curandeiro(m):
    cabana(m, 6.0, 5.0, 3.2, enfeites_curandeiro)


def modelo_tenda(m):
    w, d = 4.4, 4.4
    m.caixa((0, 0, 0.1), (w + 0.6, d + 0.6, 0.2), "madeira")
    for i in range(8):
        s = w - i * 0.55
        m.caixa((0, 0, 0.2 + 0.4 * i + 0.2), (s, d + 0.4, 0.4), "palha")
    for sx in (-1, 1):
        m.caixa((sx * (w / 2 + 0.1), -d / 2, 1.4), (0.3, 0.3, 2.8), "bambu")
    m.caixa((0, -(d / 2 + 0.25), 0.9), (1.6, 0.2, 1.7), "preto")                                   # entrada
    m.caixa((0, 0, 4.4), (0.4, d + 0.8, 0.4), "madeira")


def modelo_torre(m):
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.caixa((sx * 1.7, sy * 1.7, 6.2), (0.55, 0.55, 12.4), "madeira")
    for z in (2.5, 5.5, 8.5, 11.2):
        for s in (-1, 1):
            m.caixa((0, s * 1.7, z), (3.6, 0.3, 0.3), "bambu")
            m.caixa((s * 1.7, 0, z + 0.4), (0.3, 3.6, 0.3), "bambu")
    m.caixa((0, 0, 12.6), (5.2, 5.2, 0.4), "madeira")                                              # plataforma
    for s in (-1, 1):                                                                              # guarda-corpo
        m.caixa((0, s * 2.5, 13.35), (5.2, 0.25, 1.1), "bambu")
        m.caixa((s * 2.5, 0, 13.35), (0.25, 5.2, 1.1), "bambu")
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.caixa((sx * 2.3, sy * 2.3, 14.4), (0.4, 0.4, 3.2), "madeira")
    telhado(m, 4.6, 4.6, 15.6, passos=5, altura=0.5, beiral=0.8)
    for i in range(12):                                                                            # escada na frente
        m.caixa((0, -2.0, 0.6 + i * 1.0), (1.1, 0.2, 0.18), "madeira")
    for s in (-1, 1):
        m.caixa((s * 0.65, -2.0, 6.4), (0.15, 0.2, 12.4), "bambu")
    m.caixa((0, -1.85, 0.2), (5.0, 1.3, 0.4), "pedra")                                              # base da escada
    m.caixa((0, 2.8, 13.9), (1.2, 0.2, 0.9), "vermelho")                                           # bandeira


def modelo_cais(m):
    comp, larg = 22.0, 5.0
    topo = 2.6
    for i in range(int(comp)):
        m.caixa((0, -comp / 2 + 0.5 + i, topo - 0.15), (larg, 0.92, 0.3), "madeira")                 # tábuas (juntas visíveis)
    for s in (-1, 1):
        m.caixa((s * (larg / 2 - 0.2), 0, topo - 0.5), (0.35, comp, 0.4), "tronco")                   # vigas longitudinais
    for i in range(6):
        y = -comp / 2 + 1.0 + i * 4.0
        for s in (-1, 1):
            m.caixa((s * (larg / 2 - 0.1), y, topo / 2 - 0.2), (0.6, 0.6, topo + 0.0), "tronco")   # estacas
            m.caixa((s * (larg / 2 - 0.1), y, topo + 0.45), (0.45, 0.45, 1.1), "madeira")           # postes de amarração
            m.caixa((s * (larg / 2 - 0.1), y, topo + 0.75), (0.55, 0.55, 0.14), "corda")
    for i in range(5):
        y = -comp / 2 + 3.0 + i * 4.0
        for s in (-1, 1):
            m.caixa((s * (larg / 2 - 0.1), y, topo + 0.8), (0.1, 4.0, 0.12), "corda")                # corda entre postes
    m.caixa((0, comp / 2 - 0.4, topo + 1.7), (0.5, 0.5, 2.6), "madeira")                            # poste do lampião na ponta
    m.caixa((0, comp / 2 - 0.4, topo + 3.3), (0.9, 0.9, 0.9), "fogo")
    m.caixa((0, -comp / 2 + 1.2, topo + 0.4), (1.4, 1.2, 0.8), "madeira")                           # caixote na ponta de terra
    m.caixa((1.0, -comp / 2 + 2.2, topo + 0.3), (0.9, 0.9, 0.6), "madeira")


def modelo_portal(m):
    for s in (-1, 1):
        m.caixa((s * 4.2, 0, 3.4), (1.5, 1.5, 6.8), "calcada")
        m.caixa((s * 4.2, 0, 6.9), (1.9, 1.9, 0.5), "pedra")
        m.caixa((s * 4.2, 0, 0.3), (2.1, 2.1, 0.6), "pedra")
        for z in (1.7, 3.6, 5.5):
            m.caixa((s * 4.2, -0.8, z), (1.1, 0.2, 0.5), "corda")                                   # faixas de corda
    m.caixa((0, 0, 7.4), (10.4, 1.3, 1.0), "madeira")                                               # verga
    m.caixa((0, 0, 8.2), (8.0, 1.0, 0.6), "tronco")
    # rosto de macaco no centro
    m.caixa((0, -0.8, 7.5), (1.8, 0.4, 1.5), "pedra")
    for s in (-1, 1):
        m.caixa((s * 0.5, -1.05, 7.85), (0.35, 0.12, 0.3), "osso")
        m.caixa((s * 0.5, -1.1, 7.85), (0.15, 0.1, 0.18), "preto")
        m.caixa((s * 1.1, -0.8, 7.7), (0.5, 0.4, 0.6), "pedra")                                       # orelhas
    m.caixa((0, -1.05, 7.1), (0.9, 0.12, 0.3), "preto")
    for s in (-1, 1):                                                                                # bananas penduradas
        m.caixa((s * 2.6, -0.8, 6.5), (0.3, 0.3, 0.9), "banana")


def totem(m, altura, tipo):
    m.caixa((0, 0, 0.3), (2.4, 2.4, 0.6), "calcada")
    z = 0.6
    camadas = {"alegre": [(1.8, 1.0), (1.6, 1.1), (1.5, 1.0)], "guardiao": [(2.0, 1.3), (1.8, 1.3), (1.6, 0.9)],
               "sabio": [(1.4, 1.2), (1.3, 1.2), (1.2, 1.2), (1.1, 1.0)]}[tipo]
    for k, (larg, alt) in enumerate(camadas):
        m.caixa((0, 0, z + alt / 2), (larg, larg, alt), "pedra" if k % 2 == 0 else "calcada")
        # rosto: olhos e boca em cada camada
        for s in (-1, 1):
            m.caixa((s * larg * 0.23, -(larg / 2 + 0.03), z + alt * 0.65), (0.28, 0.08, 0.28), "osso")
            m.caixa((s * larg * 0.23, -(larg / 2 + 0.06), z + alt * 0.65), (0.14, 0.08, 0.14), "vermelho" if tipo == "guardiao" else "preto")
        m.caixa((0, -(larg / 2 + 0.03), z + alt * 0.25), (larg * 0.5, 0.08, 0.2), "preto" if tipo != "alegre" else "banana")
        z += alt
    if tipo == "alegre":
        for s in (-1, 1):
            m.caixa((s * 1.3, 0, z - 1.4), (1.0, 0.5, 0.4), "madeira")                               # braços abertos
        m.caixa((0, 0, z + 0.3), (1.0, 1.0, 0.6), "banana")
    elif tipo == "guardiao":
        for sx in (-1, 1):
            m.caixa((sx * 0.9, 0, z + 0.4), (0.4, 0.4, 0.8), "osso")                                  # chifres/presas
        m.caixa((0, 0, z + 0.3), (1.5, 1.5, 0.6), "pedra")
    else:
        m.caixa((0, 0, z + 0.3), (1.0, 1.0, 0.6), "tronco")
        for i in range(3):
            m.caixa((-0.4 + i * 0.4, 0, z + 0.85), (0.18, 0.18, 0.5), "coroa" if False else "madeira")


def modelo_totem_alegre(m):
    totem(m, 4.0, "alegre")


def modelo_totem_guardiao(m):
    totem(m, 4.0, "guardiao")


def modelo_totem_sabio(m):
    totem(m, 5.0, "sabio")


def modelo_altar(m):
    m.caixa((0, 0, 0.3), (6.0, 6.0, 0.6), "calcada")
    m.caixa((0, 0, 0.9), (5.0, 5.0, 0.6), "pedra")
    m.caixa((0, 0.4, 1.9), (3.2, 2.0, 1.4), "pedra")
    m.caixa((0, 0.4, 2.7), (3.5, 2.3, 0.3), "calcada")
    for i, (x, y) in enumerate(((-1.0, 0.0), (0.0, 0.7), (1.0, 0.2), (-0.4, 0.9))):
        for k in range(4):
            m.caixa((x + k * 0.05, y, 3.1 + (k % 2) * 0.1), (0.9 - k * 0.12, 0.35, 0.28), "banana" if k % 3 else "banana_verde")
    for s in (-1, 1):                                                                                # tochas
        m.caixa((s * 2.3, -2.0, 1.6), (0.4, 0.4, 2.0), "madeira")
        m.caixa((s * 2.3, -2.0, 2.9), (0.7, 0.7, 0.6), "fogo")


def modelo_trono(m):
    # três degraus, assento, encosto alto e crânios de osso
    for i, (w, d) in enumerate(((13.0, 9.0), (10.0, 7.0), (7.0, 5.0))):
        m.caixa((0, i * -0.0, 0.4 + i * 0.8), (w, d, 0.8), "calcada" if i % 2 == 0 else "pedra")
    m.caixa((0, 0.8, 3.2), (3.6, 3.0, 1.0), "pedra")                                                   # assento
    m.caixa((0, 2.2, 5.6), (4.2, 0.9, 5.0), "pedra")                                                   # encosto
    m.caixa((0, 2.2, 8.5), (5.0, 1.1, 0.9), "calcada")
    for s in (-1, 1):
        m.caixa((s * 2.2, 0.8, 4.0), (0.9, 3.0, 1.6), "pedra")                                         # braços
        m.caixa((s * 2.5, 2.2, 8.9), (0.7, 0.7, 0.9), "osso")
        m.caixa((s * 5.6, 0.6, 3.9), (1.3, 1.3, 2.6), "calcada")                                       # pilares de crânio
        m.caixa((s * 5.6, 0.5, 5.5), (1.0, 1.0, 0.9), "osso")
        m.caixa((s * 5.6, -0.1, 5.5), (0.3, 0.1, 0.3), "preto")
    m.caixa((0, 0.8, 4.1), (2.0, 1.8, 0.4), "banana")                                                  # almofada de bananas
    m.caixa((0, 1.8, 9.2), (1.2, 0.8, 0.8), "dourado")                                                  # coroa no topo
    for s in (-1, 1):
        m.caixa((s * 5.9, -3.2, 1.6), (0.5, 0.5, 2.4), "madeira")
        m.caixa((s * 5.9, -3.2, 3.2), (0.9, 0.9, 0.7), "fogo")


def modelo_fogueira(m):
    for i in range(10):
        a = i * math.tau / 10
        m.caixa((math.cos(a) * 1.4, math.sin(a) * 1.4, 0.3), (0.7, 0.7, 0.6), "pedra" if i % 2 else "calcada")
    m.caixa((0, 0, 0.15), (2.0, 2.0, 0.3), "preto")
    for k in range(3):
        m.caixa((0, 0, 0.55 + k * 0.01), (2.0, 0.3, 0.3), "tronco")
    m.caixa((0, 0, 0.8), (0.3, 2.0, 0.3), "tronco")
    m.caixa((0, 0, 1.2), (0.9, 0.9, 0.9), "fogo")
    m.caixa((0, 0, 1.9), (0.5, 0.5, 0.7), "fogo")
    m.caixa((0.35, 0.2, 1.0), (0.4, 0.4, 0.4), "brasa")


def modelo_cacho_banana(m):
    m.caixa((0, 0, 0.55), (0.18, 0.18, 1.1), "tronco")
    for i in range(6):
        a = i * math.tau / 6
        m.caixa((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.45 + (i % 2) * 0.15), (0.2, 0.2, 0.7), "banana" if i % 3 else "banana_verde")


def modelo_fruto_dourado(m):
    m.caixa((0, 0, 0.9), (1.2, 1.2, 1.2), "dourado")
    m.caixa((0, 0, 0.9), (0.8, 1.6, 0.8), "dourado")
    m.caixa((0, 0, 0.9), (1.6, 0.8, 0.8), "dourado")
    m.caixa((0, 0, 1.8), (0.15, 0.15, 0.5), "tronco")
    m.caixa((0.25, 0, 2.05), (0.5, 0.3, 0.1), "folha")


def modelo_bananeira(m):
    for k in range(6):
        m.caixa((0, 0, 0.4 + k * 0.7), (0.9 - k * 0.05, 0.9 - k * 0.05, 0.7), "tronco" if k % 2 else "banana_verde")
    topo = 4.4
    for i in range(8):
        a = i * math.tau / 8
        for j, (r, dz, w) in enumerate(((0.9, 0.0, 0.8), (1.8, -0.25, 0.7), (2.7, -0.7, 0.55))):
            m.caixa((math.cos(a) * r, math.sin(a) * r, topo + dz), (0.9 if i % 2 == 0 else 0.7, 0.9 if i % 2 else 0.7, 0.15), "folha" if j % 2 == 0 else "folha_escura")
    m.caixa((0.5, 0, 3.7), (0.2, 0.2, 0.9), "tronco")
    for i in range(5):
        m.caixa((0.5 + (i % 2) * 0.15, -0.15 + i * 0.08, 3.2), (0.18, 0.18, 0.6), "banana")


MODELOS = {
    "macacos_cabana_geppo": modelo_cabana_geppo, "macacos_cabana_curandeiro": modelo_cabana_curandeiro, "macacos_tenda": modelo_tenda,
    "macacos_torre_vigia": modelo_torre, "macacos_cais": modelo_cais, "macacos_portal": modelo_portal,
    "macacos_totem_alegre": modelo_totem_alegre, "macacos_totem_guardiao": modelo_totem_guardiao, "macacos_totem_sabio": modelo_totem_sabio,
    "macacos_altar_bananas": modelo_altar, "macacos_trono": modelo_trono, "macacos_fogueira": modelo_fogueira,
    "macacos_cacho_banana": modelo_cacho_banana, "macacos_fruto_dourado": modelo_fruto_dourado, "macacos_bananeira": modelo_bananeira,
}


def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(bloco):
            bloco.remove(item)


def principal():
    previa = "--previa" in sys.argv
    os.makedirs(PREVIAS, exist_ok=True)
    os.makedirs(FONTES, exist_ok=True)
    for id_, fn in MODELOS.items():
        limpar()
        mats = materiais()
        m = Modelo(id_, mats)
        fn(m)
        obj = m.construir()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=os.path.join(LOJA, id_ + ".glb"), export_format="GLB", use_selection=True, export_yup=True,
                                  export_animations=False)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(FONTES, id_ + ".blend"))
        print("CONSTRUCAO", id_, "caixas:", len(m.verts) // 8)
        if previa:
            fotografar(obj, id_)


def fotografar(obj, id_):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 420
    scene.render.resolution_y = 420
    dims = max(obj.dimensions)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = dims * 1.35
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (dims * 1.1, -dims * 1.3, obj.dimensions.z * 0.5 + dims * 0.7)
    d = (obj.location + __import__("mathutils").Vector((0, 0, obj.dimensions.z * 0.45))) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(PREVIAS, id_ + ".png")
    bpy.ops.render.render(write_still=True)


principal()
