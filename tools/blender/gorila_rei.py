"""GORILA-REI — chefe da Ilha dos Macacos (22/11/2026). Voxel, esqueleto próprio e animações por quadros-chave.

    blender -b --python tools/blender/gorila_rei.py            # modelo + rig + clipes -> GLB
    blender -b --python tools/blender/gorila_rei.py -- --previa  # também renderiza as folhas de pose

Saídas:
  art_src/blender/gorila_rei/gorila_rei.blend              fonte
  mapas/modelos/gorila_rei.glb                             modelo da loja (a ferramenta do Godot o registra no catálogo)
  art_src/blender/gorila_rei/manifesto.json                clipes: duração, impacto (s), loop
  art_src/validation/ilha_macacos/gorila_rei/*.png         prévias (com --previa)

Decisão do dono (22/11/2026): gorila feito no Blender, estilo voxel, sem skill builder. As imagens/texturas são do Codex:
  atlas 128x128 em assets/textures/ilha_macacos/gorila_rei_atlas.png (grade 4x4 de células de 32 px; contrato em
  docs/ILHA_DOS_MACACOS_V2_PLANO.md). Sem o arquivo, usa-se um atlas PROVISÓRIO gerado aqui (cores chapadas com ruído de pixel).
Eixos do Blender: X largura, Y para trás (a FRENTE é −Y: o exportador a leva a +Z, que é a frente dos modelos do jogo), Z acima. Origem no chão.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SAIDA_BLEND = os.path.join(RAIZ, "art_src", "blender", "gorila_rei", "gorila_rei.blend")
SAIDA_GLB = os.path.join(RAIZ, "mapas", "modelos", "gorila_rei.glb")
MANIFESTO = os.path.join(RAIZ, "art_src", "blender", "gorila_rei", "manifesto.json")
ATLAS_CODEX = os.path.join(RAIZ, "assets", "textures", "ilha_macacos", "gorila_rei_atlas.png")
ATLAS_PROVISORIO = os.path.join(RAIZ, "art_src", "blender", "gorila_rei", "atlas_provisorio.png")
PREVIAS = os.path.join(RAIZ, "art_src", "validation", "ilha_macacos", "gorila_rei")
FPS = 24

# Células do atlas (coluna, linha; linha 0 = topo).
CELULA = {
    "pelagem": (0, 0), "pelagem_clara": (1, 0), "dorso_claro": (2, 0), "dorso_escuro": (3, 0),
    "rosto": (0, 1), "focinho": (1, 1), "palma": (2, 1), "unha": (3, 1),
    "coroa": (0, 2), "osso": (1, 2), "pedra": (2, 2), "musgo": (3, 2),
    "olho": (0, 3), "olho_furia": (1, 3), "boca": (2, 3), "reserva": (3, 3),
}
COR_PROVISORIA = {
    "pelagem": (34, 38, 52), "pelagem_clara": (52, 60, 84), "dorso_claro": (170, 178, 190), "dorso_escuro": (118, 124, 138),
    "rosto": (24, 22, 28), "focinho": (46, 40, 44), "palma": (70, 56, 52), "unha": (200, 190, 170),
    "coroa": (122, 78, 38), "osso": (226, 218, 196), "pedra": (112, 116, 112), "musgo": (70, 110, 58),
    "olho": (240, 240, 230), "olho_furia": (230, 30, 20), "boca": (150, 40, 50), "reserva": (90, 90, 90),
}


# ----------------------------------------------------------------------------------------------- atlas
def preparar_atlas() -> str:
    if os.path.exists(ATLAS_CODEX):
        return ATLAS_CODEX
    from PIL import Image
    import random
    random.seed(22112026)
    img = Image.new("RGB", (128, 128))
    px = img.load()
    for nome, (c, r) in CELULA.items():
        base = COR_PROVISORIA[nome]
        for y in range(32):
            for x in range(32):
                k = random.randint(-10, 10)
                px[c * 32 + x, r * 32 + y] = tuple(max(0, min(255, v + k)) for v in base)
    os.makedirs(os.path.dirname(ATLAS_PROVISORIO), exist_ok=True)
    img.save(ATLAS_PROVISORIO)
    return ATLAS_PROVISORIO


# ----------------------------------------------------------------------------------------------- cena
def limpar():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials, bpy.data.images):
        for item in list(bloco):
            bloco.remove(item)


def material(caminho: str, nome: str = "gorila_rei"):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nos = m.node_tree.nodes
    ligacoes = m.node_tree.links
    bsdf = next(n for n in nos if n.type == "BSDF_PRINCIPLED")
    tex = nos.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(caminho)
    tex.image.pack()
    tex.interpolation = "Closest"
    ligacoes.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return m


# Ossos: nome -> (pai, cabeça, cauda). Frente é −Y.
OSSOS = {
    "root": (None, (0, 0, 0), (0, 0, 0.3)),
    "hips": ("root", (0, 0.1, 1.9), (0, 0.1, 2.4)),
    "spine": ("hips", (0, 0.1, 2.4), (0, -0.1, 3.0)),
    "chest": ("spine", (0, -0.1, 3.0), (0, -0.3, 3.9)),
    "neck": ("chest", (0, -0.45, 3.85), (0, -0.7, 4.15)),
    "head": ("neck", (0, -0.7, 4.15), (0, -0.9, 4.85)),
    "jaw": ("head", (0, -1.0, 4.2), (0, -1.4, 4.15)),
}
for lado, sx in (("L", 1.0), ("R", -1.0)):
    OSSOS["upper_arm_" + lado] = ("chest", (sx * 1.45, -0.4, 3.7), (sx * 1.6, -0.55, 2.5))
    OSSOS["forearm_" + lado] = ("upper_arm_" + lado, (sx * 1.6, -0.55, 2.5), (sx * 1.65, -0.75, 1.3))
    OSSOS["fist_" + lado] = ("forearm_" + lado, (sx * 1.65, -0.75, 1.3), (sx * 1.65, -0.85, 0.45))
    OSSOS["thigh_" + lado] = ("hips", (sx * 0.7, 0.1, 2.0), (sx * 0.8, -0.05, 1.1))
    OSSOS["shin_" + lado] = ("thigh_" + lado, (sx * 0.8, -0.05, 1.1), (sx * 0.85, 0.1, 0.4))
    OSSOS["foot_" + lado] = ("shin_" + lado, (sx * 0.85, 0.1, 0.4), (sx * 0.85, -0.5, 0.12))

PARTES = []     # (osso, centro, tamanho, célula)


def parte(osso, centro, tamanho, celula):
    PARTES.append((osso, centro, tamanho, celula))


def desenhar_corpo():
    # tronco e costas
    parte("hips", (0, 0.1, 2.15), (1.6, 1.25, 0.95), "pelagem")
    parte("spine", (0, -0.05, 2.7), (2.0, 1.5, 0.85), "pelagem")
    parte("chest", (0, -0.3, 3.45), (2.75, 1.75, 1.05), "pelagem")
    parte("chest", (0, -1.2, 3.4), (1.9, 0.12, 0.85), "pelagem_clara")            # peito claro
    parte("chest", (0, 0.5, 3.5), (2.3, 0.45, 1.05), "dorso_claro")               # dorso prateado
    parte("spine", (0, 0.5, 2.75), (1.7, 0.4, 0.75), "dorso_escuro")
    parte("hips", (0, 0.75, 2.2), (1.2, 0.3, 0.7), "dorso_escuro")
    # pescoço e cabeça
    parte("neck", (0, -0.6, 3.95), (1.0, 0.9, 0.55), "pelagem")
    parte("head", (0, -0.85, 4.45), (1.5, 1.4, 1.1), "pelagem")
    parte("head", (0, -1.58, 4.32), (1.15, 0.12, 0.8), "rosto")                  # placa do rosto
    parte("head", (0, -1.78, 4.15), (0.95, 0.5, 0.5), "focinho")
    parte("head", (-0.2, -2.05, 4.25), (0.16, 0.1, 0.16), "rosto")               # narinas
    parte("head", (0.2, -2.05, 4.25), (0.16, 0.1, 0.16), "rosto")
    parte("head", (0, -1.5, 4.78), (1.55, 0.5, 0.34), "pelagem")                   # sobrancelha
    parte("head", (0, -0.75, 5.0), (0.4, 1.0, 0.3), "pelagem")                    # crista sagital
    parte("jaw", (0, -1.55, 3.95), (1.0, 0.85, 0.34), "rosto")
    parte("jaw", (-0.32, -1.98, 4.15), (0.16, 0.14, 0.22), "osso")                # presas
    parte("jaw", (0.32, -1.98, 4.15), (0.16, 0.14, 0.22), "osso")
    parte("jaw", (0, -1.55, 4.13), (0.85, 0.65, 0.08), "boca")
    # coroa de madeira e ossos
    parte("head", (0, -0.85, 5.18), (1.25, 1.25, 0.16), "coroa")
    for x, y, h in ((-0.5, -0.5, 0.55), (0.5, -0.5, 0.55), (-0.5, -1.2, 0.45), (0.5, -1.2, 0.45), (0, -0.85, 0.7)):
        parte("head", (x, y, 5.45 + (h - 0.5) * 0.4), (0.2, 0.2, h), "coroa")
    parte("head", (0, -0.85, 5.95), (0.18, 0.18, 0.5), "osso")
    for lado, sx in (("L", 1.0), ("R", -1.0)):
        # ombros, ombreiras de pedra com musgo
        parte("chest", (sx * 1.5, -0.4, 3.75), (1.15, 1.15, 1.0), "pelagem")
        parte("chest", (sx * 1.55, -0.4, 4.3), (1.2, 1.25, 0.4), "pedra")
        parte("chest", (sx * 1.55, -0.4, 4.55), (0.8, 0.9, 0.18), "musgo")
        parte("chest", (sx * 1.55, -0.4, 4.78), (0.3, 0.3, 0.3), "pedra")
        # braços
        parte("upper_arm_" + lado, (sx * 1.6, -0.55, 3.05), (1.0, 1.0, 1.55), "pelagem")
        parte("forearm_" + lado, (sx * 1.65, -0.75, 1.9), (1.1, 1.05, 1.4), "pelagem")
        parte("forearm_" + lado, (sx * 1.65, -0.75, 1.35), (1.2, 1.15, 0.22), "pedra")        # braçadeira
        parte("fist_" + lado, (sx * 1.65, -0.85, 0.85), (1.7, 1.6, 1.25), "pelagem")
        parte("fist_" + lado, (sx * 1.65, -1.67, 0.7), (1.4, 0.08, 0.9), "palma")
        for dx in (-0.4, 0.0, 0.4):
            parte("fist_" + lado, (sx * 1.65 + dx * 1.3, -1.72, 0.3), (0.34, 0.14, 0.24), "unha")
        # pernas
        parte("thigh_" + lado, (sx * 0.75, 0.0, 1.6), (1.05, 1.05, 1.0), "pelagem")
        parte("shin_" + lado, (sx * 0.85, 0.05, 0.8), (0.95, 0.95, 0.95), "pelagem")
        parte("foot_" + lado, (sx * 0.85, -0.25, 0.2), (1.05, 1.35, 0.4), "palma")
        for dx in (-0.3, 0.0, 0.3):
            parte("foot_" + lado, (sx * 0.85 + dx, -0.98, 0.15), (0.24, 0.14, 0.18), "unha")
    # ---- v2.1 (22/11): silhueta de gorila (conceito do Codex): corcova, peitorais, pelo em camadas, saiote de folhas, colar de presas, cordas nos punhos
    parte("chest", (0, 0.15, 4.3), (2.6, 1.5, 0.75), "pelagem")                       # corcova dos trapézios: o pescoço some entre os ombros
    parte("chest", (-0.7, -1.2, 3.6), (1.25, 0.28, 0.9), "pelagem_clara")             # peitorais
    parte("chest", (0.7, -1.2, 3.6), (1.25, 0.28, 0.9), "pelagem_clara")
    for i, x in enumerate((-0.95, -0.5, 0.0, 0.5, 0.95)):                              # colar de presas
        parte("chest", (x, -1.42, 3.98 - abs(x) * 0.25 - (0.2 if i == 2 else 0.0)), (0.16, 0.14, 0.42 if i == 2 else 0.3), "osso")
    parte("chest", (0, -1.38, 4.08), (2.0, 0.1, 0.1), "coroa")                        # fio do colar
    parte("hips", (0, -0.8, 2.3), (1.7, 0.2, 0.22), "coroa")                           # cinto de corda
    parte("hips", (0, -0.95, 2.28), (0.45, 0.2, 0.42), "osso")                         # crânio no cinto
    for i, x in enumerate((-0.65, -0.2, 0.25, 0.7)):                                   # saiote de folhas (verde e vermelho)
        parte("hips", (x, -0.85, 1.85), (0.42, 0.12, 0.85), "reserva" if i % 2 == 0 else "olho_furia")
    for lado, sx in (("L", 1.0), ("R", -1.0)):
        # pelo em camadas: mechas nas laterais dos braços e das pernas e no dorso
        parte("upper_arm_" + lado, (sx * 2.18, -0.55, 3.2), (0.28, 0.9, 1.2), "pelagem_clara")
        parte("upper_arm_" + lado, (sx * 2.18, -0.55, 2.55), (0.28, 0.8, 0.7), "pelagem")
        parte("forearm_" + lado, (sx * 2.28, -0.75, 1.95), (0.28, 0.9, 1.0), "pelagem_clara")
        parte("thigh_" + lado, (sx * 1.3, 0.0, 1.7), (0.26, 0.9, 0.8), "pelagem_clara")
        parte("chest", (sx * 0.9, 0.95, 3.0), (0.7, 0.3, 0.8), "pelagem_clara")      # mechas do dorso
        # cordas e presas nos punhos
        parte("forearm_" + lado, (sx * 1.65, -0.75, 1.12), (1.35, 1.25, 0.2), "coroa")
        parte("forearm_" + lado, (sx * 1.65, -1.38, 1.12), (0.16, 0.14, 0.4), "osso")
        parte("forearm_" + lado, (sx * 1.1, -1.36, 1.12), (0.16, 0.14, 0.34), "osso")
        parte("forearm_" + lado, (sx * 2.2, -1.36, 1.12), (0.16, 0.14, 0.34), "osso")
        # pés maiores
        parte("foot_" + lado, (sx * 0.85, -0.45, 0.14), (1.25, 1.7, 0.28), "palma")
    # olhos (malha separada para a fúria trocar o material)
    OLHOS.extend([("head", (-0.36, -1.66, 4.55), (0.24, 0.08, 0.16)), ("head", (0.36, -1.66, 4.55), (0.24, 0.08, 0.16))])


OLHOS = []


def caixa_uv(nome, centro, tamanho, celula, osso, material_):
    """Cubo com UV inteiro na célula do atlas (cada face mostra a célula; o pixel-art repete por parte)."""
    mesh = bpy.data.meshes.new(nome)
    x, y, z = centro
    a, b, c = (v / 2 for v in tamanho)
    verts = [(x - a, y - b, z - c), (x + a, y - b, z - c), (x + a, y + b, z - c), (x - a, y + b, z - c),
             (x - a, y - b, z + c), (x + a, y - b, z + c), (x + a, y + b, z + c), (x - a, y + b, z + c)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh.from_pydata(verts, [], faces)
    col, lin = CELULA[celula]
    margem = 0.5 / 128.0     # meio texel para dentro: sem sangrar a célula do lado
    u0, u1 = col / 4 + margem, (col + 1) / 4 - margem
    v0, v1 = 1 - (lin + 1) / 4 + margem, 1 - lin / 4 - margem
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for k, li in enumerate(poly.loop_indices):
            uv.data[li].uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)][k]
    mesh.materials.append(material_)
    obj = bpy.data.objects.new(nome, mesh)
    bpy.context.collection.objects.link(obj)
    grupo = obj.vertex_groups.new(name=osso)
    grupo.add(list(range(8)), 1.0, "REPLACE")
    return obj


def juntar(objs, nome):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = nome
    obj.data.name = nome
    return obj


def esqueleto():
    arm = bpy.data.armatures.new("GorilaReiArmature")
    obj = bpy.data.objects.new("GorilaReiRig", arm)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for nome, (pai, cab, cau) in OSSOS.items():
        b = arm.edit_bones.new(nome)
        b.head = Vector(cab)
        b.tail = Vector(cau) if (Vector(cau) - Vector(cab)).length > 1e-4 else Vector(cab) + Vector((0, 0, 0.3))
        b.roll = 0.0
    for nome, (pai, cab, cau) in OSSOS.items():
        if pai:
            arm.edit_bones[nome].parent = arm.edit_bones[pai]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


# ----------------------------------------------------------------------------------------------- animação
# Postura de repouso: tronco inclinado para a frente, cabeça levantada, braços um pouco atrás para as juntas dos punhos tocarem o chão.
POSTURA = {"spine": (8,), "chest": (14,), "head": (-16,)}


class Clipes:
    """Pose por (avanço, lado, giro) em graus, nos eixos do ESQUELETO (não do osso): `avanco` > 0 leva a ponta do osso PARA A FRENTE
    (−Y), seja o osso de cima para baixo (perna, braço) ou de baixo para cima (coluna); `lado` > 0 leva a ponta para FORA do corpo;
    `giro` gira em torno do eixo vertical. `raw` abre a mandíbula."""

    def __init__(self, rig):
        self.rig = rig
        self.manifesto = {}
        self.M = {}
        for pb in rig.pose.bones:
            self.M[pb.name] = pb.bone.matrix_local.to_3x3()
            pb.rotation_mode = "QUATERNION"

    def _quat(self, nome, avanco=0.0, lado=0.0, giro=0.0, lean=0.0):
        avanco_cru = avanco
        osso = self.rig.pose.bones[nome].bone
        braco = nome.startswith("upper_arm_")
        if nome.startswith("forearm_"):
            avanco = -avanco                # antebraço: chave NEGATIVA = flexiona para a frente; o resto usa positivo = frente
        sobe = osso.tail_local.z > osso.head_local.z + 1e-4 and abs(osso.tail_local.y - osso.head_local.y) < 0.25 and nome != "jaw"
        lateral = 1.0 if osso.head_local.x >= 0 else -1.0
        if nome == "jaw":
            rx = math.radians(avanco)          # mandíbula: + abre
            ry = 0.0
        else:
            rx = math.radians(avanco if sobe else -avanco)
            if braco:
                # Braço: a chave é o ângulo NO MUNDO (negativo = para a frente, 0 = pendurado, −170 = acima da cabeça). O tronco inclinado para a frente (`lean`)
                # já gira o braço para trás; compensa-se aqui para que o desenho da chave seja o do mundo.
                rx = math.radians(avanco_cru - lean)
            ry = math.radians(-lado * lateral) if not sobe else math.radians(lado * lateral)
        R = Euler((0.0, 0.0, math.radians(giro)), "XYZ").to_matrix() @ Euler((0.0, ry, 0.0), "XYZ").to_matrix() @ Euler((rx, 0.0, 0.0), "XYZ").to_matrix()
        M = self.M[nome]
        return (M.inverted() @ R @ M).to_quaternion()

    def clipe(self, nome, quadros, chaves, laco=False, impacto=None, **extra):
        """`chaves`: {quadro: {osso: (avanco, lado, giro) ou (avanco,), 'root_z': m}}. Ossos ausentes ficam em repouso nesse quadro."""
        acao = bpy.data.actions.new(nome)
        acao.use_fake_user = True
        self.rig.animation_data_create()
        self.rig.animation_data.action = acao
        for pb in self.rig.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        for q in sorted(chaves):
            for pb in self.rig.pose.bones:
                pb.rotation_quaternion = (1, 0, 0, 0)
                pb.location = (0, 0, 0)
            chaves_q = dict(chaves[q])
            for osso, base in POSTURA.items():           # postura curvada de gorila em TODO quadro, somada ao que o clipe pede
                v0 = tuple(chaves_q.get(osso, ())) + (0.0,) * 3
                chaves_q[osso] = (v0[0] + base[0], v0[1], v0[2])
            for osso, v in chaves_q.items():
                if osso == "root_z":
                    self.rig.pose.bones["root"].location = (0, 0, float(v))
                    continue
                if osso == "root_y":
                    self.rig.pose.bones["root"].location = (0, float(v), self.rig.pose.bones["root"].location[2])
                    continue
                v = tuple(v) + (0.0,) * (3 - len(v))
                lean = chaves_q.get("spine", (0,))[0] + chaves_q.get("chest", (0,))[0]
                self.rig.pose.bones[osso].rotation_quaternion = self._quat(osso, *v, lean=lean)
            for pb in self.rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=q)
                pb.keyframe_insert("location", frame=q)
        if laco:
            for fc in acao.fcurves if hasattr(acao, "fcurves") else []:
                m = fc.modifiers.new("CYCLES")
        self.manifesto[nome] = {"quadros": quadros, "duracao": quadros / FPS, "laco": laco,
                                "impacto": (impacto / FPS if impacto is not None else None)}
        self.manifesto[nome].update(extra)
        self.rig.animation_data.action = None
        return acao


def montar_clipes(c: Clipes):
    D = ("upper_arm_L", "upper_arm_R")
    # ---------- idle: respira e balança de leve (laço de 2 s)
    c.clipe("idle", 48, {
        0: {"chest": (0,), "head": (0,), "upper_arm_L": (2, 3), "upper_arm_R": (2, 3), "forearm_L": (4,), "forearm_R": (4,)},
        24: {"chest": (-3,), "spine": (2,), "head": (4,), "upper_arm_L": (-2, 5), "upper_arm_R": (-2, 5), "forearm_L": (6,), "forearm_R": (6,), "root_z": 0.04},
        48: {"chest": (0,), "head": (0,), "upper_arm_L": (2, 3), "upper_arm_R": (2, 3), "forearm_L": (4,), "forearm_R": (4,)},
    }, laco=True)

    # ---------- andar nos nós dos dedos (laço de 1 s)
    def ciclo(n, p, braco, lean, bob, perna_amp):
        # p = quadros por meio ciclo
        a, b = perna_amp, perna_amp * 0.8
        def fase(f, s):
            # s = +1: perna L à frente
            return {"thigh_L": (s * a,), "thigh_R": (-s * a,), "shin_L": ((-30 if s < 0 else -8),), "shin_R": ((-30 if s > 0 else -8),),
                    "upper_arm_L": (-s * braco, 4), "upper_arm_R": (s * braco, 4), "forearm_L": (6,), "forearm_R": (6,),
                    "chest": (lean,), "spine": (lean * 0.4,), "head": (-lean * 0.6,), "hips": (0, 0, s * 4), "root_z": bob if f % (2 * p) else 0.0}
        k = {0: fase(0, 1), p: fase(p, -1), 2 * p: fase(2 * p, 1)}
        k[p // 2] = {**fase(0, 0), "root_z": bob, "shin_L": (-38,), "shin_R": (-6,), "thigh_L": (0,), "thigh_R": (0,)}
        k[p + p // 2] = {**fase(0, 0), "root_z": bob, "shin_L": (-6,), "shin_R": (-38,), "thigh_L": (0,), "thigh_R": (0,)}
        return k
    c.clipe("walk", 24, ciclo("walk", 12, 22, 10, 0.07, 24), laco=True)
    c.clipe("run", 16, ciclo("run", 8, 45, 22, 0.16, 42), laco=True)

    # ---------- golpeado
    c.clipe("hurt", 12, {0: {}, 4: {"chest": (-14,), "spine": (-6,), "head": (-18,), "upper_arm_L": (14, 8), "upper_arm_R": (14, 8), "root_z": -0.05}, 12: {}})

    # ---------- rugido: bate no peito (aviso do pulo/chamada)
    def soco_no_peito(lado, q):
        return {f"upper_arm_{lado}": (-55, 6), f"forearm_{lado}": (-95,)}
    c.clipe("roar", 60, {
        0: {},
        10: {"spine": (-8,), "chest": (-18,), "head": (-30,), "jaw": (35,), "upper_arm_L": (-30, 30), "upper_arm_R": (-30, 30), "forearm_L": (-40,), "forearm_R": (-40,), "root_z": 0.12},
        16: {"spine": (-8,), "chest": (-18,), "head": (-30,), "jaw": (45,), **soco_no_peito("L", 0), "upper_arm_R": (-20, 40), "forearm_R": (-20,), "root_z": 0.12},
        22: {"spine": (-8,), "chest": (-14,), "head": (-26,), "jaw": (40,), "upper_arm_L": (-20, 40), "forearm_L": (-20,), **soco_no_peito("R", 0), "root_z": 0.1},
        28: {"spine": (-8,), "chest": (-18,), "head": (-30,), "jaw": (45,), **soco_no_peito("L", 0), "upper_arm_R": (-20, 40), "forearm_R": (-20,), "root_z": 0.12},
        34: {"spine": (-8,), "chest": (-14,), "head": (-26,), "jaw": (40,), "upper_arm_L": (-20, 40), "forearm_L": (-20,), **soco_no_peito("R", 0), "root_z": 0.1},
        46: {"spine": (-6,), "chest": (-12,), "head": (-20,), "jaw": (30,), "upper_arm_L": (-10, 40), "upper_arm_R": (-10, 40), "forearm_L": (-10,), "forearm_R": (-10,)},
        60: {},
    }, impacto=22)
    c.clipe("furia", 96, {
        0: {},
        12: {"spine": (-10,), "chest": (-22,), "head": (-38,), "jaw": (50,), "upper_arm_L": (-30, 40), "upper_arm_R": (-30, 40), "forearm_L": (-30,), "forearm_R": (-30,), "root_z": 0.2},
        **{q: {"spine": (-10,), "chest": (-20 + (q // 8 % 2) * 6,), "head": (-34,), "jaw": (52,), **soco_no_peito("L" if (q // 8) % 2 else "R", 0),
                "upper_arm_R" if (q // 8) % 2 else "upper_arm_L": (-18, 44), "forearm_R" if (q // 8) % 2 else "forearm_L": (-18,), "root_z": 0.16 + (q // 8 % 2) * 0.06}
           for q in (20, 28, 36, 44, 52, 60, 68, 76)},
        96: {},
    }, impacto=20)

    # ---------- soco duplo no chão (impacto no quadro 21)
    c.clipe("soco_chao", 40, {
        0: {},
        10: {"spine": (-6,), "chest": (-16,), "head": (-8,), "upper_arm_L": (-165, 8), "upper_arm_R": (-165, 8), "forearm_L": (-14,), "forearm_R": (-14,),
             "thigh_L": (10,), "thigh_R": (10,), "shin_L": (-16,), "shin_R": (-16,), "root_z": -0.1},
        18: {"spine": (-8,), "chest": (-22,), "head": (-12,), "upper_arm_L": (-172, 10), "upper_arm_R": (-172, 10), "forearm_L": (-18,), "forearm_R": (-18,),
             "thigh_L": (14,), "thigh_R": (14,), "shin_L": (-20,), "shin_R": (-20,), "root_z": -0.14},
        21: {"spine": (14,), "chest": (36,), "head": (14,), "upper_arm_L": (-30, 8), "upper_arm_R": (-30, 8), "forearm_L": (0,), "forearm_R": (0,),
             "thigh_L": (22,), "thigh_R": (22,), "shin_L": (-30,), "shin_R": (-30,), "root_z": -0.3},
        26: {"spine": (12,), "chest": (32,), "head": (10,), "upper_arm_L": (-30, 8), "upper_arm_R": (-30, 8), "forearm_L": (0,), "forearm_R": (0,),
             "thigh_L": (20,), "thigh_R": (20,), "shin_L": (-28,), "shin_R": (-28,), "root_z": -0.28},
        40: {},
    }, impacto=21)

    # ---------- pulo esmagador (agacha, voa, cai com os dois punhos; impacto no 30)
    c.clipe("pulo_esmagar", 52, {
        0: {},
        8: {"spine": (14,), "chest": (28,), "head": (6,), "upper_arm_L": (-26, 8), "upper_arm_R": (-26, 8), "thigh_L": (44,), "thigh_R": (44,), "shin_L": (-64,), "shin_R": (-64,), "root_z": -0.55},
        14: {"spine": (-6,), "chest": (-10,), "head": (-12,), "upper_arm_L": (-150, 10), "upper_arm_R": (-150, 10), "forearm_L": (-12,), "forearm_R": (-12,),
             "thigh_L": (-10,), "thigh_R": (-10,), "shin_L": (-8,), "shin_R": (-8,), "root_z": 0.35},
        22: {"spine": (-4,), "chest": (-8,), "head": (-8,), "upper_arm_L": (-170, 12), "upper_arm_R": (-170, 12), "thigh_L": (16,), "thigh_R": (16,), "shin_L": (-24,), "shin_R": (-24,), "root_z": 0.6},
        30: {"spine": (14,), "chest": (38,), "head": (14,), "upper_arm_L": (-30, 8), "upper_arm_R": (-30, 8), "forearm_L": (0,), "forearm_R": (0,),
             "thigh_L": (36,), "thigh_R": (36,), "shin_L": (-50,), "shin_R": (-50,), "root_z": -0.4},
        38: {"spine": (10,), "chest": (30,), "head": (10,), "upper_arm_L": (-26, 8), "upper_arm_R": (-26, 8), "thigh_L": (30,), "thigh_R": (30,), "shin_L": (-40,), "shin_R": (-40,), "root_z": -0.34},
        52: {},
    }, impacto=30)

    # ---------- investida de ombro (laço enquanto avança)
    k = ciclo("investida", 8, 30, 38, 0.1, 44)
    for q in k:
        k[q]["head"] = (-24,)
        k[q]["spine"] = (18,)
    c.clipe("investida", 16, k, laco=True)

    # ---------- giro (impacto contínuo entre 10 e 26)
    ks = {0: {}}
    ks[6] = {"chest": (10,), "upper_arm_L": (0, 88), "upper_arm_R": (0, 88), "forearm_L": (0, 0), "forearm_R": (0, 0), "thigh_L": (14,), "thigh_R": (14,), "shin_L": (-20,), "shin_R": (-20,), "root_z": -0.2}
    for q, g in ((12, 90), (18, 180), (24, 270), (30, 340)):
        ks[q] = {**ks[6], "hips": (0, 0, g), "root_z": -0.2}
    ks[36] = {}
    c.clipe("giro", 40, ks, impacto=18)

    # ---------- arremesso de pedra (solta no quadro 26)
    c.clipe("arremesso", 50, {
        0: {},
        10: {"spine": (14,), "chest": (36,), "head": (10,), "upper_arm_L": (-44, 6), "upper_arm_R": (-44, 6), "forearm_L": (-50,), "forearm_R": (-50,), "thigh_L": (30,), "thigh_R": (30,), "shin_L": (-44,), "shin_R": (-44,), "root_z": -0.35},
        18: {"spine": (-6,), "chest": (-12,), "head": (-12,), "upper_arm_L": (-150, 14), "upper_arm_R": (-150, 14), "forearm_L": (-45,), "forearm_R": (-45,), "root_z": 0.0},
        26: {"spine": (12,), "chest": (30,), "head": (6,), "upper_arm_L": (-40, 10), "upper_arm_R": (-70, 6), "forearm_L": (-10,), "forearm_R": (-5,), "thigh_L": (18,), "thigh_R": (10,), "shin_L": (-26,), "shin_R": (-16,), "root_z": -0.18},
        34: {"spine": (8,), "chest": (24,), "upper_arm_L": (-30, 10), "upper_arm_R": (-52, 6), "root_z": -0.12},
        50: {},
    }, impacto=26)

    # ---------- morte (cai de joelhos e de bruços)
    c.clipe("morte", 72, {
        0: {},
        16: {"spine": (10,), "chest": (24,), "head": (22,), "thigh_L": (50,), "thigh_R": (50,), "shin_L": (-80,), "shin_R": (-80,), "upper_arm_L": (10, 20), "upper_arm_R": (10, 20), "root_z": -0.9},
        36: {"spine": (28,), "chest": (46,), "head": (32,), "thigh_L": (60,), "thigh_R": (60,), "shin_L": (-95,), "shin_R": (-95,), "upper_arm_L": (-10, 30), "upper_arm_R": (-10, 30), "root_z": -1.3},
        54: {"spine": (36,), "chest": (58,), "head": (36,), "thigh_L": (70,), "thigh_R": (70,), "shin_L": (-100,), "shin_R": (-100,), "upper_arm_L": (-30, 36), "upper_arm_R": (-30, 36), "forearm_L": (-20,), "forearm_R": (-20,), "root_z": -1.55},
        72: {"spine": (36,), "chest": (60,), "head": (36,), "thigh_L": (72,), "thigh_R": (72,), "shin_L": (-100,), "shin_R": (-100,), "upper_arm_L": (-32, 36), "upper_arm_R": (-32, 36), "forearm_L": (-20,), "forearm_R": (-20,), "root_z": -1.6},
    })


# ----------------------------------------------------------------------------------------------- principal
def principal():
    previa = "--previa" in sys.argv
    limpar()
    caminho = preparar_atlas()
    mat = material(caminho)
    desenhar_corpo()
    objs = [caixa_uv(f"p{i}_{p[0]}", p[1], p[2], p[3], p[0], mat) for i, p in enumerate(PARTES)]
    corpo = juntar(objs, "GorilaRei")
    mat_olho = material(caminho, "gorila_rei_olho")
    olhos = [caixa_uv(f"olho{i}", o[1], o[2], "olho", o[0], mat_olho) for i, o in enumerate(OLHOS)]
    olho = juntar(olhos, "Olhos")
    rig = esqueleto()
    for o in (corpo, olho):
        o.parent = rig
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    clipes = Clipes(rig)
    montar_clipes(clipes)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Clipes com laço: o último quadro igual ao primeiro, já escrito nas chaves; o exportador toca em laço pelo `loop_mode` do Godot.
    os.makedirs(os.path.dirname(SAIDA_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA_BLEND)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (rig, corpo, olho):
        o.select_set(True)
    os.makedirs(os.path.dirname(SAIDA_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=SAIDA_GLB, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_skins=True, export_yup=True, export_force_sampling=True,
                              export_frame_range=False)
    with open(MANIFESTO, "w", encoding="utf-8") as f:
        json.dump({"fps": FPS, "clipes": clipes.manifesto, "atlas": os.path.relpath(caminho, RAIZ)}, f, indent=1, ensure_ascii=False)
    print("GORILA_REI glb:", SAIDA_GLB, "partes:", len(PARTES), "clipes:", list(clipes.manifesto))
    if previa:
        fotografar(rig, clipes)


def fotografar(rig, clipes: Clipes):
    """Folhas de pose: cada clipe em 4 quadros, visto de lado e de frente, num PNG por clipe (Workbench, sem luz pesada)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = 360
    scene.render.resolution_y = 360
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 8.0
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(os.path.join(PREVIAS, "quadros"), exist_ok=True)
    for nome, info in clipes.manifesto.items():
        rig.animation_data.action = bpy.data.actions[nome]
        n = info["quadros"]
        quadros = [0, n // 4, n // 2, (3 * n) // 4]
        if info.get("impacto"):
            quadros[2] = int(round(info["impacto"] * FPS))
        for col, q in enumerate(quadros):
            scene.frame_set(q)
            for lin, (loc, rot) in enumerate((((11, 0, 3.2), (math.radians(90), 0, math.radians(90))),     # de lado (frente à esquerda)
                                              ((0, -11, 3.2), (math.radians(90), 0, 0)))):                  # de frente
                cam.location = loc
                cam.rotation_euler = rot
                scene.render.filepath = os.path.join(PREVIAS, "quadros", f"{nome}_{col}_{lin}.png")
                bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None
    print("PREVIAS em", PREVIAS)


principal()
