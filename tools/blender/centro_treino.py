# -*- coding: utf-8 -*-
"""
Assets do CENTRO DE TREINO do Modo História (docs/PLANO_CENTRO_TREINO.md).

Referências (CONCEITOS, não modelos aprovados): art_src/conceitos/centro_treino/
  boneco_de_treino.png  -> referência principal do boneco
  centro_de_treino.png  -> pavilhão e adereços (o personagem ilustrado é só escala)

Rodar (reproduz tudo):
    blender --background --python tools/blender/centro_treino.py
    blender --background --python tools/blender/centro_treino.py -- boneco      # só o boneco
    blender --background --python tools/blender/centro_treino.py -- boneco_voxel   # boneco em blocos -> boneco_de_treino_voxel.glb

Saída:  assets/models/centro_treino/<peca>.glb
        art_src/blender/centro_treino/centro_treino.blend   (fonte editável, com a prévia)

Convenção (a mesma de customizacao_codex.py): Blender X = largura, Y = FRENTE, Z = para cima;
o exportador glTF converte para Y-up. Origem de cada peça no CHÃO, no centro da base.
Materiais: cores lisas no Principled (sem textura ainda) — a madeira varia por 3 tons.

BONECO — esqueleto (um mesh só, skin por grupos de vértices):
  Base (raiz) > Torso > Cabeca | Braco_E > Antebraco_E | Braco_D > Antebraco_D
  "Esquerda/Direita" são do PRÓPRIO boneco: ele olha para +Y, a direita dele é +X.
Animações (24 fps, nomes exatos no glTF):
  idle (loop 2 s) · hit_frente / hit_costas / hit_esq / hit_dir (0,5 s, mola amortecida)
  guarda (pose de defesa, 0,4 s) · ataque_esq / ataque_dir (golpe LENTO e AVISADO:
  armar 0,7 s -> golpe 0,12 s -> recuperar 0,5 s; o pico do golpe é o quadro "impacto") ·
  reset (volta ao repouso, 0,3 s)
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Quaternion, Vector

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "models", "centro_treino")
FONTE = os.path.join(RAIZ, "art_src", "blender", "centro_treino", "centro_treino.blend")

VOXEL = False         # True: só caixas alinhadas aos eixos (boneco_de_treino_voxel); cilindro/esfera/toro/cone viram blocos
_mats = {}
_partes = {}          # osso -> [objetos]  (só o boneco)
_osso = None          # osso atual: o que for criado entra no grupo dele


# =============================================================== materiais
def mat(nome, cor, metal=0.0, rug=0.85, emissao=None):
    if nome in _mats:
        return _mats[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*cor, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rug
    if emissao:
        b.inputs["Emission Color"].default_value = (*emissao, 1.0)
        b.inputs["Emission Strength"].default_value = 3.0
    _mats[nome] = m
    return m


def paleta():
    return {
        "mad_clara": mat("MadeiraClara", (0.62, 0.40, 0.20)),
        "mad_media": mat("MadeiraMedia", (0.50, 0.31, 0.15)),
        "mad_escura": mat("MadeiraEscura", (0.36, 0.22, 0.11)),
        "juta": mat("Juta", (0.78, 0.62, 0.40), rug=0.95),
        "juta_esc": mat("JutaEscura", (0.64, 0.49, 0.30), rug=0.95),
        "corda": mat("Corda", (0.74, 0.58, 0.32), rug=0.95),
        "ferro": mat("Ferro", (0.20, 0.20, 0.22), metal=0.8, rug=0.5),
        "couro": mat("Couro", (0.34, 0.16, 0.09), rug=0.7),
        "palha": mat("Palha", (0.90, 0.72, 0.25), rug=0.95),
        "vermelho": mat("Vermelho", (0.72, 0.10, 0.12), rug=0.8),
        "creme": mat("Creme", (0.92, 0.85, 0.70), rug=0.9),
        "azul": mat("Remendo", (0.25, 0.38, 0.62), rug=0.9),
        "pedra": mat("Pedra", (0.52, 0.50, 0.46), rug=0.95),
        "terra": mat("Terra", (0.70, 0.55, 0.38), rug=1.0),
        "lona": mat("Lona", (0.90, 0.84, 0.68), rug=0.95),
        "telha": mat("Telha", (0.70, 0.24, 0.16), rug=0.85),
        "lanterna": mat("Lanterna", (1.0, 0.72, 0.30), emissao=(1.0, 0.62, 0.20)),
    }


# ============================================================== primitivas
def _reg(o, m):
    o.data.materials.append(m)
    if _osso is not None:
        _partes.setdefault(_osso, []).append(o)
    return o


def _aplicar(o, loc=False, rot=True, esc=True):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=loc, rotation=rot, scale=esc)


def _bisel(o, largura):
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("Bisel", "BEVEL")
    md.width = largura
    md.segments = 2
    md.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=md.name)


def _cubo(nome, tam, centro, m):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    _aplicar(o)
    return _reg(o, m)


def _anel_quadrado(nome, R, r, centro, m, eixo, esc):
    """Toro -> aro quadrado de 4 caixas (R = meia-largura, r = meia-espessura)."""
    cx, cy, cz = centro
    a, b = R * esc[0], R * esc[1] if eixo == "Z" else R * esc[2]
    t = 2 * r
    if eixo == "Z":
        for sx, sy, tm in ((1, 0, (t, 2 * b + t, t)), (-1, 0, (t, 2 * b + t, t)), (0, 1, (2 * a + t, t, t)), (0, -1, (2 * a + t, t, t))):
            _cubo(nome, tm, (cx + sx * a, cy + sy * b, cz), m)
    elif eixo == "X":
        for sy, sz, tm in ((1, 0, (t, t, 2 * R + t)), (-1, 0, (t, t, 2 * R + t)), (0, 1, (t, 2 * R + t, t)), (0, -1, (t, 2 * R + t, t))):
            _cubo(nome, tm, (cx, cy + sy * R, cz + sz * R), m)
    else:
        for sx, sz, tm in ((1, 0, (t, t, 2 * R + t)), (-1, 0, (t, t, 2 * R + t)), (0, 1, (2 * R + t, t, t)), (0, -1, (2 * R + t, t, t))):
            _cubo(nome, tm, (cx + sx * R, cy, cz + sz * R), m)


def caixa(nome, tam, centro, m, rot=(0, 0, 0), bisel=0.0):
    if VOXEL:
        return _cubo(nome, tam, centro, m)           # sem rotação e sem bisel: bloco puro
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tam
    o.rotation_euler = Euler(rot)
    _aplicar(o)
    if bisel > 0:
        _bisel(o, bisel)
    return _reg(o, m)


def cilindro(nome, r, h, centro, m, eixo="Z", seg=12, esc=(1, 1, 1)):
    if VOXEL:
        d = {"Z": (2 * r * esc[0], 2 * r * esc[1], h * esc[2]), "X": (h, 2 * r, 2 * r), "Y": (2 * r, h, 2 * r)}[eixo]
        return _cubo(nome, d, centro, m)
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=seg, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = esc
    if eixo == "X":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif eixo == "Y":
        o.rotation_euler = (math.pi / 2, 0, 0)
    _aplicar(o)
    return _reg(o, m)


def esfera(nome, r, centro, m, esc=(1, 1, 1), seg=16):
    if VOXEL:
        return _cubo(nome, (2 * r * esc[0], 2 * r * esc[1], 2 * r * esc[2]), centro, m)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=max(6, seg // 2), location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = esc
    _aplicar(o)
    return _reg(o, m)


def toro(nome, R, r, centro, m, esc=(1, 1, 1), seg=18, eixo="Z"):
    if VOXEL:
        return _anel_quadrado(nome, R, r, centro, m, eixo, esc)
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg,
                                     minor_segments=6, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.scale = esc
    if eixo == "X":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif eixo == "Y":
        o.rotation_euler = (math.pi / 2, 0, 0)
    _aplicar(o)
    return _reg(o, m)


def cone(nome, r, h, centro, m, rot=(0, 0, 0), seg=6):
    if VOXEL:
        return _cubo(nome, (2 * r, 2 * r, h), centro, m)
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=0.0, depth=h, vertices=seg, location=centro)
    o = bpy.context.active_object
    o.name = nome
    o.rotation_euler = Euler(rot)
    _aplicar(o)
    return _reg(o, m)


def _entre(a, b, nome, m, caixa_sec=None, raio=None, seg=8, bisel=0.0):
    """Viga (seção w×h) ou cilindro (raio) ligando os pontos a e b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    if VOXEL:                                        # diagonal em degraus: cubos ao longo da reta
        lado = max(caixa_sec) if caixa_sec else 2 * raio
        n = max(2, int(d.length / (lado * 0.9)))
        for i in range(n + 1):
            _cubo(nome, (lado, lado, lado), a + d * (i / n), m)
        return None
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    meio = (a + b) / 2
    if raio is not None:
        bpy.ops.mesh.primitive_cylinder_add(radius=raio, depth=d.length, vertices=seg, location=meio)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=meio)
    o = bpy.context.active_object
    o.name = nome
    if raio is None:
        o.scale = (caixa_sec[0], caixa_sec[1], d.length)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = q
    _aplicar(o)
    if bisel > 0 and raio is None:
        _bisel(o, bisel)
    return _reg(o, m)


def viga(a, b, w, h, m, nome="Viga", bisel=0.012):
    return _entre(a, b, nome, m, caixa_sec=(w, h), bisel=bisel)


def poste(a, b, r, m, nome="Poste", seg=8):
    return _entre(a, b, nome, m, raio=r, seg=seg)


def limpar():
    global _osso
    _osso = None
    _partes.clear()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for bloco in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.actions,
                  bpy.data.armatures):
        for item in list(bloco):
            bloco.remove(item)
    _mats.clear()


def unir(partes, nome):
    bpy.ops.object.select_all(action="DESELECT")
    for o in partes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = nome
    o.data.name = nome
    if not VOXEL:
        bpy.ops.object.shade_smooth()
    return o


def exportar(objs, arquivo, animacoes=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(SAIDA, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, arquivo + ".glb"), export_format="GLB",
                              use_selection=True, export_apply=False, export_yup=True,
                              export_animations=animacoes,
                              export_animation_mode="ACTIONS" if animacoes else "ACTIVE_ACTIONS")
    caixa_mundo = [Vector(c) for o in objs for c in o.bound_box]
    if caixa_mundo:
        dx = max(v.x for v in caixa_mundo) - min(v.x for v in caixa_mundo)
        dy = max(v.y for v in caixa_mundo) - min(v.y for v in caixa_mundo)
        dz = max(v.z for v in caixa_mundo) - min(v.z for v in caixa_mundo)
        print("[centro] %-22s X=%.2f Y=%.2f Z=%.2f m" % (arquivo, dx, dy, dz))


# ================================================================= BONECO
def _boneco_partes(P):
    """Modela o boneco por osso. Alturas: base 0–0,16; poste até 1,0; torso 1,0–1,62; cabeça até 2,0."""
    global _osso
    # ---------------- Base (raiz): plataforma octogonal, poste e escoras
    _osso = "Base"
    cilindro("Plataforma", 0.78, 0.16, (0, 0, 0.08), P["mad_media"], seg=8)
    cilindro("PlataformaTopo", 0.70, 0.04, (0, 0, 0.175), P["mad_clara"], seg=8)
    if VOXEL:                                # plataforma quadrada: cantoneiras nos 4 cantos, pés e frisos retos
        for sx in (-1, 1):
            for sy in (-1, 1):
                caixa("Cantoneira", (0.22, 0.22, 0.07), (0.62 * sx, 0.62 * sy, 0.20), P["ferro"])
                caixa("Rebite", (0.05, 0.05, 0.03), (0.62 * sx, 0.62 * sy, 0.25), P["ferro"])
                caixa("Pe", (0.18, 0.18, 0.05), (0.72 * sx, 0.72 * sy, 0.025), P["mad_escura"])
        for k in range(-3, 4):
            caixa("Friso", (0.012, 1.40, 0.012), (0.2 * k, 0, 0.198), P["mad_escura"])
    else:
        for k in range(8):                   # tábuas: frisos escuros entre elas
            a = k * math.pi / 4
            caixa("Friso%d" % k, (0.70, 0.012, 0.012), (0, 0, 0.198), P["mad_escura"], rot=(0, 0, a))
            c = a + math.pi / 8              # cantoneiras de ferro nos cantos
            caixa("Cantoneira%d" % k, (0.20, 0.20, 0.07), (0.74 * math.cos(c), 0.74 * math.sin(c), 0.12),
                  P["ferro"], rot=(0, 0, c), bisel=0.01)
            for s_ in (-1, 1):               # rebites
                caixa("Rebite%d_%d" % (k, s_), (0.025, 0.025, 0.02),
                      (0.74 * math.cos(c) - s_ * 0.05 * math.sin(c), 0.74 * math.sin(c) + s_ * 0.05 * math.cos(c), 0.165),
                      P["ferro"], bisel=0.006)
            caixa("Pe%d" % k, (0.16, 0.16, 0.05), (0.80 * math.cos(c), 0.80 * math.sin(c), 0.025),
                  P["mad_escura"], rot=(0, 0, c), bisel=0.01)
    caixa("Poste", (0.22, 0.22, 0.86), (0, 0, 0.58), P["mad_escura"], bisel=0.02)
    caixa("ColarFerro", (0.30, 0.30, 0.12), (0, 0, 0.72), P["ferro"], bisel=0.015)
    caixa("ColarFerroTopo", (0.28, 0.28, 0.07), (0, 0, 0.97), P["ferro"], bisel=0.012)
    for k, (sx, sy) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):      # 4 escoras diagonais
        viga((0.50 * sx, 0.50 * sy, 0.19), (0.11 * sx, 0.11 * sy, 0.70), 0.12, 0.10, P["mad_clara"], "Escora%d" % k)
        caixa("EscoraFerro%d" % k, (0.15, 0.15, 0.04), (0.50 * sx, 0.50 * sy, 0.20), P["ferro"], bisel=0.008)
        toro("EscoraCorda%d" % k, 0.07, 0.016, (0.40 * sx, 0.40 * sy, 0.28), P["corda"],
             esc=(1, 1, 1.0), seg=10)

    # ---------------- Torso: saco de juta preso ao poste (pivô z = 1,0), frente achatada com placa de alvo
    _osso = "Torso"
    cilindro("Corpo", 0.33, 0.64, (0, 0, 1.30), P["juta"], seg=16, esc=(1.0, 0.78, 1.0))
    cilindro("OmbrosMadeira", 0.26, 0.10, (0, 0, 1.63), P["mad_clara"], seg=10, esc=(1.25, 0.9, 1.0))
    yf = 0.262                                                        # face da placa frontal
    caixa("Placa", (0.50, 0.07, 0.56), (0, yf - 0.03, 1.30), P["juta"], bisel=0.035)
    for nome, r, d, cor in (("AlvoR1", 0.20, 0.004, "vermelho"), ("AlvoR2", 0.14, 0.010, "creme"),
                            ("AlvoR3", 0.075, 0.016, "vermelho")):
        cilindro(nome, r, 0.01, (0.0, yf + d, 1.18), P[cor], eixo="Y", seg=24)
    cilindro("AlvoP1", 0.085, 0.01, (0.13, yf + 0.004, 1.52), P["vermelho"], eixo="Y", seg=18)
    cilindro("AlvoP2", 0.05, 0.01, (0.13, yf + 0.010, 1.52), P["creme"], eixo="Y", seg=18)
    cilindro("AlvoP3", 0.02, 0.01, (0.13, yf + 0.016, 1.52), P["vermelho"], eixo="Y", seg=12)
    caixa("RemendoCostura", (0.17, 0.012, 0.16), (-0.15, yf + 0.003, 1.04), P["juta_esc"], rot=(0, 0, 0), bisel=0.004)
    caixa("Remendo", (0.14, 0.012, 0.13), (-0.15, yf + 0.008, 1.04), P["azul"], bisel=0.004)
    for z, r in ((1.05, 0.335), (1.57, 0.325)):                       # cintas de corda
        toro("Cinta%.2f" % z, r, 0.032, (0, 0, z), P["corda"], esc=(1.0, 0.78, 1.0), seg=24)
    toro("CintaDiag", 0.33, 0.024, (0, 0, 1.31), P["corda"], esc=(1.0, 0.78, 1.0), seg=24)
    esfera("No", 0.06, (0.14, yf + 0.02, 1.05), P["corda"], seg=8)
    for k in range(20):                                              # saia de palha
        a = k * 2 * math.pi / 20
        cone("Palha%d" % k, 0.04, 0.22, (0.35 * math.cos(a), 0.29 * math.sin(a), 0.96), P["palha"],
             rot=(math.pi + 0.35 * math.sin(a), -0.35 * math.cos(a), 0), seg=5)
    for k in range(14):                                              # gola de palha
        a = k * 2 * math.pi / 14
        cone("Gola%d" % k, 0.035, 0.15, (0.22 * math.cos(a), 0.19 * math.sin(a), 1.68), P["palha"],
             rot=(0.7 * math.sin(a), -0.7 * math.cos(a), 0), seg=5)

    # ---------------- Cabeça: cilindro de madeira com faixa vermelha e palha
    _osso = "Cabeca"
    cilindro("Cabeca", 0.20, 0.32, (0, 0, 1.80), P["mad_clara"], seg=12)
    for k in range(5):                                               # tábuas verticais
        caixa("CabTabua%d" % k, (0.012, 0.012, 0.30), (-0.14 + k * 0.07, 0.195, 1.80), P["mad_escura"])
    cilindro("Faixa", 0.212, 0.09, (0, 0, 1.85), P["vermelho"], seg=12)
    caixa("FaixaNo", (0.08, 0.05, 0.07), (0.12, -0.20, 1.85), P["vermelho"], bisel=0.01)
    viga((0.12, -0.21, 1.85), (0.34, -0.30, 1.74), 0.05, 0.012, P["vermelho"], "FaixaPonta1", 0.004)
    viga((0.12, -0.21, 1.85), (0.30, -0.32, 1.96), 0.05, 0.012, P["vermelho"], "FaixaPonta2", 0.004)
    for k in range(11):                                              # cabelo de palha
        a = k * 2 * math.pi / 11
        cone("Cabelo%d" % k, 0.045, 0.15, (0.12 * math.cos(a), 0.12 * math.sin(a), 2.03), P["palha"],
             rot=(0.6 * math.sin(a), -0.6 * math.cos(a), 0), seg=5)
    cone("CabeloTopo", 0.05, 0.16, (0, 0, 2.06), P["palha"], seg=5)

    # ---------------- Braços (T): ombro de ferro, braço de madeira, antebraço + luva/escudo
    for lado, sx, osso_b, osso_a in (("E", -1, "Braco_E", "Antebraco_E"), ("D", 1, "Braco_D", "Antebraco_D")):
        _osso = osso_b
        cilindro("Ombro" + lado, 0.135, 0.08, (sx * 0.30, 0, 1.45), P["ferro"], eixo="X", seg=12)
        cilindro("Braco" + lado, 0.10, 0.30, (sx * 0.44, 0, 1.45), P["mad_clara"], eixo="X", seg=10)
        for x in (0.36, 0.52):
            cilindro("Banda%s%.2f" % (lado, x), 0.118, 0.04, (sx * x, 0, 1.45), P["ferro"], eixo="X", seg=10)
        toro("CordaBraco" + lado, 0.108, 0.018, (sx * 0.43, 0, 1.45), P["corda"], seg=10)
        _osso = osso_a
        cilindro("Cotovelo" + lado, 0.125, 0.07, (sx * 0.585, 0, 1.45), P["ferro"], eixo="X", seg=12)
        cilindro("Antebraco" + lado, 0.09, 0.16, (sx * 0.69, 0, 1.45), P["mad_media"], eixo="X", seg=10)
        cilindro("Punho" + lado, 0.13, 0.05, (sx * 0.77, 0, 1.45), P["couro"], eixo="X", seg=12)
        if lado == "E":      # luva de boxe de juta, costurada
            esfera("Luva", 0.24, (sx * 0.95, 0, 1.45), P["juta"], esc=(1.0, 0.95, 1.0), seg=20)
            if VOXEL:
                for k in range(4):           # listras de costura nas faces da luva
                    caixa("Costura%d" % k, (0.46, 0.02, 0.04), (sx * 0.95, 0.235, 1.45 - 0.13 + k * 0.087), P["juta_esc"])
            else:
                toro("LuvaCostura", 0.236, 0.012, (sx * 0.95, 0, 1.45), P["juta_esc"], eixo="X", seg=20)
                toro("LuvaCostura2", 0.236, 0.012, (sx * 0.95, 0, 1.45), P["juta_esc"], eixo="Y", seg=20)
                for k in range(10):          # pontos cruzando a costura frontal
                    a = k * 2 * math.pi / 10
                    caixa("Ponto%d" % k, (0.012, 0.03, 0.05), (sx * 0.95 + 0.236 * math.cos(a), 0.0,
                          1.45 + 0.236 * math.sin(a)), P["couro"], rot=(0, -a, 0))
            toro("LuvaFaixa", 0.20, 0.024, (sx * 0.78, 0, 1.45), P["couro"], eixo="X", seg=14)
        else:                # escudo de bater: moldura de couro + face acolchoada de juta
            caixa("EscudoMoldura", (0.36, 0.17, 0.56), (sx * 0.95, 0.0, 1.45), P["couro"], bisel=0.05)
            caixa("EscudoFace", (0.30, 0.10, 0.48), (sx * 0.95, 0.07, 1.45), P["juta"], bisel=0.05)
            for k in range(6):
                caixa("EscudoPonto%d" % k, (0.32, 0.012, 0.012), (sx * 0.95, 0.125, 1.45 - 0.20 + k * 0.08), P["juta_esc"])
            caixa("EscudoAlca", (0.07, 0.07, 0.30), (sx * 0.95, -0.09, 1.45), P["couro"], bisel=0.015)


def _esqueleto():
    arm = bpy.data.armatures.new("EsqueletoBoneco")
    obj = bpy.data.objects.new("Esqueleto", arm)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    ossos = {}

    def osso(nome, cabeca, cauda, pai=None):
        b = arm.edit_bones.new(nome)
        b.head, b.tail = Vector(cabeca), Vector(cauda)
        if pai:
            b.parent = ossos[pai]
        ossos[nome] = b

    osso("Base", (0, 0, 0.0), (0, 0, 0.30))
    osso("Torso", (0, 0, 1.0), (0, 0, 1.62), "Base")
    osso("Cabeca", (0, 0, 1.62), (0, 0, 2.0), "Torso")
    osso("Braco_E", (-0.30, 0, 1.45), (-0.585, 0, 1.45), "Torso")
    osso("Antebraco_E", (-0.585, 0, 1.45), (-1.10, 0, 1.45), "Braco_E")
    osso("Braco_D", (0.30, 0, 1.45), (0.585, 0, 1.45), "Torso")
    osso("Antebraco_D", (0.585, 0, 1.45), (1.10, 0, 1.45), "Braco_D")
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def _q(eixo, graus):
    return Quaternion(Vector(eixo), math.radians(graus))


def _pose(arm, quadro, poses):
    """poses: {osso: [(eixo_no_espaço_do_esqueleto, graus), ...]} — o resto volta ao repouso."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        q = Quaternion((1, 0, 0, 0))
        for eixo, graus in poses.get(pb.name, []):
            q = _q(eixo, graus) @ q
        R = pb.bone.matrix_local.to_3x3().to_quaternion()
        pb.rotation_quaternion = R.inverted() @ q @ R          # eixo do esqueleto -> eixo local do osso
        pb.keyframe_insert("rotation_quaternion", frame=quadro)


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def _acao(arm, nome, quadros, loop=False):
    act = bpy.data.actions.new(nome)
    act.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    for q, poses in quadros:
        _pose(arm, q, poses)
    if loop:
        for fc in act.fcurves if hasattr(act, "fcurves") else []:
            pass
    return act


def _mola(amp, base_quadro=1):
    """Fatores de uma mola amortecida em 12 quadros (0,5 s): ida, volta, ida menor, assenta."""
    return [(base_quadro, 0.0), (base_quadro + 3, 1.0), (base_quadro + 6, -0.45), (base_quadro + 9, 0.2),
            (base_quadro + 12, 0.0)]


def _animacoes(arm):
    # idle: respiração, 48 quadros, volta ao início (loop)
    _acao(arm, "idle", [
        (1, {}),
        (13, {"Torso": [(X, -1.2)], "Braco_E": [(Z, 2)], "Braco_D": [(Z, -2)]}),
        (25, {}),
        (37, {"Torso": [(X, 1.0)], "Braco_E": [(Z, -2)], "Braco_D": [(Z, 2)]}),
        (49, {}),
    ], loop=True)
    # hits: o corpo vai para longe do golpe; braços e cabeça sacodem com atraso
    hits = {
        "hit_frente": lambda f: {"Torso": [(X, 14 * f)], "Cabeca": [(X, -7 * f)],
                                 "Braco_E": [(Z, 10 * f)], "Braco_D": [(Z, -10 * f)]},
        "hit_costas": lambda f: {"Torso": [(X, -12 * f)], "Cabeca": [(X, 6 * f)],
                                 "Braco_E": [(Z, -8 * f)], "Braco_D": [(Z, 8 * f)]},
        "hit_esq": lambda f: {"Torso": [(Y, 13 * f)], "Cabeca": [(Y, -8 * f)],
                              "Braco_E": [(Z, 6 * f)], "Braco_D": [(Z, 6 * f)]},
        "hit_dir": lambda f: {"Torso": [(Y, -13 * f)], "Cabeca": [(Y, 8 * f)],
                              "Braco_E": [(Z, -6 * f)], "Braco_D": [(Z, -6 * f)]},
    }
    for nome, fn in hits.items():
        _acao(arm, nome, [(q, fn(f)) for q, f in _mola(1.0)])
    # guarda: antebraços cruzam à frente do tronco (no espaço do esqueleto, +Z gira o braço D para +Y/frente; o E é o espelho)
    guarda = {"Braco_E": [(Z, -55)], "Antebraco_E": [(Z, -85)], "Braco_D": [(Z, 55)], "Antebraco_D": [(Z, 85)],
              "Torso": [(X, -3)]}
    _acao(arm, "guarda", [(1, {}), (6, {k: [(e, g * 0.6) for e, g in v] for k, v in guarda.items()}), (10, guarda)])
    # ataques lentos e avisados: armar (recuo e elevação) -> golpe -> recuperar
    for lado, sx in (("esq", -1), ("dir", 1)):
        b, a = ("Braco_E", "Antebraco_E") if sx < 0 else ("Braco_D", "Antebraco_D")
        armar = {b: [(Z, -sx * 55), (Y, sx * -20)], a: [(Z, -sx * 35)], "Torso": [(Z, sx * 10)]}
        golpe = {b: [(Z, sx * 75)], a: [(Z, sx * 40)], "Torso": [(Z, sx * -14)]}
        _acao(arm, "ataque_" + lado, [(1, {}), (9, {k: [(e, g * 0.5) for e, g in v] for k, v in armar.items()}),
                                      (17, armar), (20, armar), (23, golpe),     # 23 = impacto
                                      (30, {k: [(e, g * 0.5) for e, g in v] for k, v in golpe.items()}), (36, {})])
    _acao(arm, "reset", [(1, {"Torso": [(X, 4)], "Braco_E": [(Z, -20)], "Braco_D": [(Z, 20)]}), (8, {})])
    arm.animation_data.action = bpy.data.actions["idle"]


def boneco_de_treino(voxel=False):
    global VOXEL
    VOXEL = voxel
    P = paleta()
    _boneco_partes(P)
    arm = _esqueleto()
    grupos = []
    for osso, objs in _partes.items():
        o = unir(objs, "G_" + osso)
        vg = o.vertex_groups.new(name=osso)
        vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
        grupos.append(o)
    corpo = unir(grupos, "BonecoDeTreino")
    corpo.parent = arm
    md = corpo.modifiers.new("Esqueleto", "ARMATURE")
    md.object = arm
    bpy.context.scene.render.fps = 24
    _animacoes(arm)
    bpy.context.scene.frame_end = 49
    exportar([arm, corpo], "boneco_de_treino_voxel" if voxel else "boneco_de_treino", animacoes=True)
    VOXEL = False
    return arm, corpo


# ============================================================ CENÁRIO
def toco_treino(P):
    r = []
    r.append(cilindro("Toco", 0.20, 0.34, (0, 0, 0.17), P["mad_clara"], seg=12, esc=(1, 1, 1)))
    r.append(cilindro("TocoTopo", 0.185, 0.02, (0, 0, 0.345), P["mad_escura"], seg=12))
    r.append(toro("TocoCorda", 0.205, 0.014, (0, 0, 0.12), P["corda"], seg=14))
    return unir(r, "toco_treino")


def cerca_corda_modulo(P):
    """Módulo de 2,0 m: um poste (em x=0) e a corda até o próximo (x=2). Poste 0,9 m."""
    r = []
    r.append(poste((0, 0, 0), (0, 0, 0.92), 0.075, P["mad_clara"], "Poste", 8))
    r.append(cilindro("PosteTopo", 0.082, 0.04, (0, 0, 0.93), P["mad_escura"], seg=8))
    r.append(toro("PosteCorda", 0.085, 0.018, (0, 0, 0.82), P["corda"], seg=10))
    for z in (0.78, 0.50):
        pts = [(0.0, z), (0.5, z - 0.05), (1.0, z - 0.075), (1.5, z - 0.05), (2.0, z)]
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            r.append(poste((x0, 0, z0), (x1, 0, z1), 0.022, P["corda"], "Corda", 6))
    return unir(r, "cerca_corda_modulo")


def barreira_tronco(P):
    """Obstáculo de esquiva/pulo: tronco horizontal 2,4 m a 0,55 m do chão em dois cavaletes."""
    r = []
    for x in (-0.9, 0.9):
        r.append(viga((x, -0.22, 0), (x, 0.0, 0.55), 0.10, 0.10, P["mad_escura"], "PernaA"))
        r.append(viga((x, 0.22, 0), (x, 0.0, 0.55), 0.10, 0.10, P["mad_escura"], "PernaB"))
        r.append(toro("Amarra", 0.075, 0.02, (x, 0, 0.55), P["corda"], seg=10))
    r.append(poste((-1.2, 0, 0.62), (1.2, 0, 0.62), 0.11, P["mad_clara"], "Tronco", 10))
    for x in (-1.2, 1.2):
        r.append(cilindro("Corte", 0.09, 0.02, (x, 0, 0.62), P["mad_escura"], eixo="X", seg=10))
    for x in (-0.55, 0.55):
        r.append(toro("TroncoCorda", 0.115, 0.02, (x, 0, 0.62), P["corda"], esc=(1, 1, 1), seg=12))
    return unir(r, "barreira_tronco")


def estrutura_rede(P):
    """Pórtico em A com rede de corda para escalada: 3,2 m de largura × 3,0 m de altura."""
    r = []
    for x in (-1.5, 1.5):
        r.append(viga((x, -0.5, 0), (x, 0.0, 3.0), 0.14, 0.14, P["mad_clara"], "PernaFrente"))
        r.append(viga((x, 0.5, 0), (x, 0.0, 3.0), 0.14, 0.14, P["mad_clara"], "PernaTras"))
        r.append(caixa("Pe", (0.30, 1.1, 0.06), (x, 0, 0.03), P["mad_escura"], bisel=0.01))
    r.append(viga((-1.65, 0, 2.95), (1.65, 0, 2.95), 0.16, 0.16, P["mad_escura"], "Travessa"))
    r.append(viga((-1.5, 0, 1.05), (1.5, 0, 1.05), 0.10, 0.10, P["mad_media"], "TravessaBaixa"))
    for x in (-1.5, 1.5):
        r.append(toro("Amarra", 0.09, 0.02, (x, 0, 2.95), P["corda"], seg=10))
    for i in range(1, 8):                                 # rede: 7 verticais × 6 horizontais
        x = -1.5 + i * 0.375
        r.append(poste((x, 0.0, 1.05), (x, 0.0, 2.95), 0.014, P["corda"], "RedeV", 5))
    for j in range(1, 7):
        z = 1.05 + j * (1.9 / 7)
        r.append(poste((-1.5, 0.0, z), (1.5, 0.0, z), 0.014, P["corda"], "RedeH", 5))
    return unir(r, "estrutura_rede")


def cavalete_lona(P):
    """Cavalete com lona esticada (abrigo/obstáculo): 1,9 m × 1,1 m × 1,3 m."""
    r = []
    for x in (-0.9, 0.9):
        r.append(viga((x, -0.40, 0), (x, 0.0, 1.30), 0.09, 0.09, P["mad_clara"], "PernaA"))
        r.append(viga((x, 0.40, 0), (x, 0.0, 1.30), 0.09, 0.09, P["mad_clara"], "PernaB"))
    r.append(viga((-1.0, 0, 1.28), (1.0, 0, 1.28), 0.10, 0.10, P["mad_escura"], "Cumeeira"))
    r.append(viga((-0.9, 0, 0.55), (0.9, 0, 0.55), 0.06, 0.06, P["mad_media"], "Travessa"))
    r.append(caixa("Lona", (1.76, 0.06, 0.62), (0, 0.0, 0.90), P["lona"], bisel=0.015))
    for x in (-0.8, -0.27, 0.27, 0.8):
        r.append(toro("Ilhos", 0.03, 0.012, (x, 0.04, 1.14), P["corda"], seg=8))
    return unir(r, "cavalete_lona")


def barril(P):
    r = [cilindro("Barril", 0.30, 0.78, (0, 0, 0.39), P["mad_clara"], seg=14, esc=(1, 1, 1))]
    for z in (0.14, 0.64):
        r.append(toro("Aro", 0.305, 0.022, (0, 0, z), P["ferro"], seg=16))
    r.append(toro("AroMeio", 0.34, 0.022, (0, 0, 0.39), P["ferro"], seg=16))
    r.append(cilindro("Tampa", 0.27, 0.03, (0, 0, 0.79), P["mad_escura"], seg=14))
    return unir(r, "barril")


def caixote(P):
    r = [caixa("Caixote", (0.62, 0.50, 0.50), (0, 0, 0.25), P["mad_clara"], bisel=0.015)]
    for dz in (0.10, 0.40):
        r.append(caixa("Tabua", (0.64, 0.52, 0.04), (0, 0, dz), P["mad_media"], bisel=0.008))
    for sx in (-1, 1):
        r.append(caixa("Quina", (0.06, 0.54, 0.52), (sx * 0.29, 0, 0.25), P["mad_escura"], bisel=0.01))
    r.append(viga((-0.28, -0.26, 0.06), (0.28, -0.26, 0.44), 0.05, 0.02, P["mad_escura"], "Diagonal", 0.004))
    return unir(r, "caixote")


def banco(P):
    r = [caixa("Assento", (1.5, 0.30, 0.06), (0, 0, 0.46), P["mad_clara"], bisel=0.012)]
    for x in (-0.6, 0.6):
        r.append(caixa("Pe", (0.08, 0.26, 0.44), (x, 0, 0.22), P["mad_escura"], bisel=0.01))
    r.append(caixa("Travessa", (1.2, 0.05, 0.05), (0, 0, 0.18), P["mad_media"], bisel=0.008))
    return unir(r, "banco")


def estante_armas(P):
    """Estante de espadas de treino (madeira): 1,6 m × 0,4 m × 1,2 m."""
    r = []
    for x in (-0.75, 0.75):
        r.append(caixa("Pilar", (0.10, 0.12, 1.2), (x, 0, 0.6), P["mad_escura"], bisel=0.012))
        r.append(caixa("Pe", (0.14, 0.45, 0.06), (x, 0, 0.03), P["mad_escura"], bisel=0.01))
    for z in (0.55, 0.95):
        r.append(caixa("Barra", (1.6, 0.09, 0.07), (0, 0, z), P["mad_media"], bisel=0.012))
    for i, x in enumerate((-0.55, -0.20, 0.15, 0.5)):
        r.append(viga((x, 0.0, 0.52), (x + 0.04, 0.0, 1.32), 0.05, 0.016, P["mad_clara"], "EspadaLamina", 0.004))
        r.append(caixa("Guarda", (0.16, 0.03, 0.03), (x + 0.0, 0.0, 0.48), P["couro"], bisel=0.006))
        r.append(cilindro("Cabo", 0.022, 0.16, (x, 0, 0.38), P["couro"], seg=6))
    return unir(r, "estante_armas")


def lanterna(P):
    r = [cilindro("Corpo", 0.085, 0.20, (0, 0, -0.10), P["lanterna"], seg=8),
         cilindro("Tampa", 0.105, 0.03, (0, 0, 0.015), P["ferro"], seg=8),
         cilindro("Base", 0.095, 0.03, (0, 0, -0.215), P["ferro"], seg=8)]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        r.append(cilindro("Barra", 0.008, 0.20, (0.087 * math.cos(a), 0.087 * math.sin(a), -0.10), P["ferro"], seg=4))
    r.append(poste((0, 0, 0.03), (0, 0, 0.25), 0.007, P["ferro"], "Corrente", 4))
    return unir(r, "lanterna")


def pavilhao_treino(P):
    """Pavilhão aberto, 10 × 6 m de planta, em plataforma de 0,5 m; frente (escada) para +Y.
    Telhado de uma água (frente 3,0 m, fundos 3,7 m), toldos de lona nas laterais.
    Origem: centro da planta, ao nível do chão."""
    W, D, H0 = 10.0, 6.0, 0.50
    r = []
    # base de pedra e plataforma de tábuas
    r.append(caixa("BasePedra", (W + 0.4, D + 0.4, H0 - 0.06), (0, 0, (H0 - 0.06) / 2), P["pedra"], bisel=0.04))
    for i in range(int(W / 0.25)):
        x = -W / 2 + 0.125 + i * 0.25
        m = P["mad_clara"] if i % 3 else P["mad_media"]
        r.append(caixa("Tabua%d" % i, (0.235, D, 0.06), (x, 0, H0 - 0.03), m, bisel=0.008))
    # escada frontal (3 degraus)
    for i in range(3):
        r.append(caixa("Degrau%d" % i, (2.2, 0.38, 0.17), (1.0, D / 2 + 0.38 * (2 - i) + 0.19, 0.085 + i * 0.165),
                       P["mad_media"], bisel=0.012))
    # postes (8) e travessas
    xs = [-W / 2 + 0.3 + i * (W - 0.6) / 3 for i in range(4)]
    for x in xs:
        for y, h in ((D / 2 - 0.3, 3.0), (-D / 2 + 0.3, 3.7)):
            r.append(caixa("Poste", (0.28, 0.28, h), (x, y, H0 + h / 2), P["mad_clara"], bisel=0.025))
            r.append(toro("PosteCorda", 0.19, 0.03, (x, y, H0 + 1.0), P["corda"], esc=(1, 1, 1), seg=12))
            r.append(caixa("PosteBase", (0.38, 0.38, 0.12), (x, y, H0 + 0.06), P["pedra"], bisel=0.02))
    zf, zt = H0 + 3.0, H0 + 3.7
    for y, z in ((D / 2 - 0.3, zf), (-D / 2 + 0.3, zt)):
        r.append(caixa("VigaMestra", (W, 0.30, 0.34), (0, y, z - 0.05), P["mad_escura"], bisel=0.03))
    for x in xs:                                            # vigas transversais (inclinadas)
        r.append(viga((x, D / 2 - 0.3, zf + 0.12), (x, -D / 2 + 0.3, zt + 0.12), 0.24, 0.24, P["mad_escura"], "Caibro", 0.02))
        r.append(viga((x, D / 2 - 0.3, zf - 0.20), (x + 0.6 * (1 if x < 0 else -1), D / 2 - 0.3, zf - 0.9), 0.14, 0.14,
                      P["mad_media"], "MaoFrancesa", 0.012))
    # telhado: tiras de telha vermelha com ripas, inclinado
    ang = math.atan2(zt - zf, -D + 0.6)
    comp = math.hypot(D + 0.6 + 0.8, zt - zf)
    n = 20
    for i in range(n):
        x = -W / 2 - 0.3 + i * (W + 0.6) / n + (W + 0.6) / n / 2
        m = P["telha"] if i % 4 else P["mad_escura"]
        a = Vector((x, D / 2 + 0.4, zf - 0.16))
        b = Vector((x, -D / 2 - 0.4, zt - 0.16 + (zt - zf) * 0.0))
        r.append(viga(a, b, (W + 0.6) / n * 0.96, 0.07, m, "Telha", 0.01))
    # toldos de lona nas laterais e na frente
    r.append(viga((-W / 2 - 0.1, D / 2 - 0.3, zf - 0.3), (-W / 2 - 0.1, -D / 2 + 0.3, zt - 0.3), 0.05, 0.9, P["lona"], "ToldoE", 0.01))
    r.append(viga((W / 2 + 0.1, D / 2 - 0.3, zf - 0.3), (W / 2 + 0.1, -D / 2 + 0.3, zt - 0.3), 0.05, 0.9, P["lona"], "ToldoD", 0.01))
    r.append(caixa("ToldoFundos", (W - 0.6, 0.05, 1.5), (0, -D / 2 + 0.35, H0 + 2.8), P["lona"], bisel=0.01))
    # corrimão baixo e guarda-corpo dos fundos
    for y in (-D / 2 + 0.05,):
        r.append(caixa("GuardaFundos", (W, 0.12, 0.12), (0, y, H0 + 1.0), P["mad_media"], bisel=0.02))
    # lanternas penduradas na viga frontal
    for x in xs:
        r.append(poste((x, D / 2 - 0.3, zf - 0.22), (x, D / 2 - 0.3, zf - 0.42), 0.008, P["ferro"], "Corrente", 4))
        r.append(esfera("Lanterna", 0.11, (x, D / 2 - 0.3, zf - 0.55), P["lanterna"], esc=(1, 1, 1.3), seg=10))
    return unir(r, "pavilhao_treino")


CENARIO = ("toco_treino", "cerca_corda_modulo", "barreira_tronco", "estrutura_rede", "cavalete_lona",
           "barril", "caixote", "banco", "estante_armas", "lanterna", "pavilhao_treino")


def cenario(P, so=None):
    feitos = {}
    for nome in CENARIO:
        if so and nome not in so:
            continue
        o = globals()[nome](P)
        exportar([o], nome)
        feitos[nome] = o
    return feitos


# ================================================================ PRÉVIA
def previa(feitos, boneco_corpo, arm):
    """Monta o pátio (cópias vinculadas) numa coleção 'Previa' para o render de revisão.
    NÃO é exportada: é só para conferir escala e leitura. Sol, chão de terra e câmera de 3/4."""
    col = bpy.data.collections.new("Previa")
    bpy.context.scene.collection.children.link(col)

    def poe(obj, x, y, z=0.0, rz=0.0, nome=None):
        c = obj.copy()
        c.data = obj.data
        c.name = nome or obj.name
        c.location = (x, y, z)
        c.rotation_euler = (0, 0, math.radians(rz))
        col.objects.link(c)
        return c

    P = paleta()
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 1.5, -0.01))
    chao = bpy.context.active_object
    chao.scale = (17, 13, 1)
    chao.name = "ChaoDeTerra"
    chao.data.materials.append(P["terra"])
    for c in chao.users_collection:
        c.objects.unlink(chao)
    col.objects.link(chao)
    pav = poe(feitos["pavilhao_treino"], 0, -5.5)
    for i, (x, y) in enumerate(((-1.8, 1.6), (1.8, 1.6))):
        poe(boneco_corpo, x, y, 0, 180 if False else 0, "BonecoPrevia%d" % i)
    # cerca de corda em volta do pátio
    for i in range(8):
        poe(feitos["cerca_corda_modulo"], -8.0 + i * 2.0, 7.2)
    poe(feitos["cerca_corda_modulo"], 8.0, 7.2)
    for i in range(6):
        poe(feitos["cerca_corda_modulo"], -8.0, 7.2 - (i + 1) * 2.0, 0, -90)
    for i, x in enumerate(range(-5, 5)):
        poe(feitos["toco_treino"], 3.0 + 0.7 * i, 4.2 - 0.25 * i)
    poe(feitos["barreira_tronco"], -3.2, 3.8, 0, 8)
    poe(feitos["barreira_tronco"], 2.5, 0.0, 0, -20)
    poe(feitos["estrutura_rede"], 6.5, -2.5, 0, 90)
    poe(feitos["cavalete_lona"], -6.2, 1.4, 0, -20)
    for x, y in ((-6.2, -2.8), (-5.5, -3.2)):
        poe(feitos["barril"], x, y)
    poe(feitos["caixote"], -6.9, -2.9, 0, 15)
    poe(feitos["banco"], -4.5, -3.0, 0.5)
    poe(feitos["banco"], 3.2, -2.6, 0.5)
    poe(feitos["estante_armas"], 1.0, -8.2, 0.5)
    # escala: uma figura 1,80 m (cilindro + esfera) — só para comparar com o boneco
    esc = bpy.data.objects.new("EscalaPlaceholder", None)
    bpy.context.scene.collection.objects.link(esc)
    # luz e câmera
    luz = bpy.data.lights.new("Sol", "SUN")
    luz.energy = 4.0
    lo = bpy.data.objects.new("Sol", luz)
    lo.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(lo)
    cam = bpy.data.cameras.new("CamPrevia")
    co = bpy.data.objects.new("CamPrevia", cam)
    bpy.context.scene.collection.objects.link(co)
    co.location = (-3.5, 14.0, 9.0)
    co.rotation_euler = Euler((math.radians(60), 0, math.radians(180))) if False else Euler((0, 0, 0))
    d = Vector((0, -2.5, 1.0)) - co.location
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    bpy.data.objects.remove(esc)
    # as peças soltas na origem saem do render
    for o in list(feitos.values()):
        o.hide_render = True
        o.hide_viewport = True
    boneco_corpo.hide_render = True
    arm.hide_render = True


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    limpar()
    P = paleta()
    if not args or "boneco" in args:
        arm, corpo = boneco_de_treino()
    if "boneco_voxel" in args:        # numa execução PRÓPRIA: as ações (idle, hit_*...) têm de sair com os nomes exatos
        arm_v, corpo_v = boneco_de_treino(voxel=True)
    if not args or "cenario" in args or any(a in CENARIO for a in args):
        feitos = cenario(P, [a for a in args if a in CENARIO] or None)
    if not args:
        previa(feitos, corpo, arm)
        os.makedirs(os.path.dirname(FONTE), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=FONTE)
        print("[centro] fonte salva em", FONTE)


if bpy.app.background:
    main()
