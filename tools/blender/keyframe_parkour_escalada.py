"""Clipes de ESCALADA autorados por keyframe no esqueleto do X Bot (Mixamo).

Gera do zero, de forma reproduzível, os 8 clipes de escalada do plano
docs/PARKOUR_MIRRORS_EDGE_PLANO.md ("Clipes autorados por keyframe"):

    hang_idle, jump_to_hang, climb_up_loop, climb_down_loop,
    climb_shimmy_left, climb_shimmy_right, ledge_climb_up, wall_jump_off

Como funciona
-------------
1. Importa o `X Bot.fbx` de dentro do "Action Adventure Pack.zip" (o mesmo
   esqueleto `mixamorig:*` e as mesmas proporções dos clipes Mixamo do pacote).
2. Monta um rig de controle: alvos de IK (vazios) para mãos e pés com polos
   de cotovelo/joelho, um controle de quadril (Copy Location/Rotation), e o
   resto (coluna, pescoço, cabeça, dedos, artelhos) em FK.
3. Cada clipe é uma função pose(t) — curvas suaves (Hermite monotônica, cíclica
   quando o clipe é ciclo) para quadril, alvos e coluna, com antecipação, arcos
   e atraso (o quadril lidera; braços e cabeça seguem).
4. Grava as curvas nos controles, ASSA para FK (nla.bake com visual keying),
   salva a fonte `art_src/animacoes_parkour/escalada.blend`, remove as
   restrições e exporta `art_src/animacoes_parkour/glb/<clipe>.glb`
   (só a armature + 1 ação, 30 qps, nomes `mixamorig:*` intactos).
5. Mede (contato, ciclo, continuidade, folga da parede, juntas), renderiza
   folhas de quadros e grava `art_src/validation/parkour_keyframe/medidas.json`.

Convenção de cena (Blender): personagem olha −Y, Z para cima, parede no plano
y = −0,30 (sólido em y < −0,30); borda (topo) a 2,20 m em `ledge_climb_up`.

Uso:
  blender -b --python tools/blender/keyframe_parkour_escalada.py -- [opções]
    --clipes a,b,c     só esses clipes (padrão: todos)
    --sem-render       pula as folhas de quadros
    --sem-export       pula os GLB
    --sem-blend        não salva o .blend fonte
"""
import bpy
import json
import math
import os
import sys
import tempfile
import zipfile
from pathlib import Path

import numpy as np
from mathutils import Matrix, Quaternion, Vector

# ----------------------------------------------------------------------------
# caminhos e constantes
# ----------------------------------------------------------------------------
REPO = Path(__file__).resolve().parents[2]
PASTA_MIXAMO = Path.home() / "Downloads/Assets/animações importadas do mixamo"
ZIP_PACOTE = PASTA_MIXAMO / "Action Adventure Pack.zip"
FBX_REFERENCIA = PASTA_MIXAMO / "Climbing Up Wall.fbx"
DIR_FONTE = REPO / "art_src/animacoes_parkour"
DIR_GLB = DIR_FONTE / "glb"
DIR_VAL = REPO / "art_src/validation/parkour_keyframe"
ARQ_BLEND = DIR_FONTE / "escalada.blend"

FPS = 30
PAREDE_Y = -0.30          # plano da parede (sólido em y < PAREDE_Y)
BORDA_Z = 2.20            # topo da parede em ledge_climb_up / altura das mãos no hang
FOLGA_PEGA = 0.012        # ponto de pega fica 1,2 cm abaixo do canto da agarra/borda

P = "mixamorig:"
LADOS = ("L", "R")
NOME_LADO = {"L": "Left", "R": "Right"}


def osso(lado, parte):
    return P + NOME_LADO[lado] + parte


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    op = {"clipes": None, "render": True, "export": True, "blend": True}
    i = 0
    while i < len(a):
        if a[i] == "--clipes":
            op["clipes"] = a[i + 1].split(",")
            i += 1
        elif a[i] == "--sem-render":
            op["render"] = False
        elif a[i] == "--sem-export":
            op["export"] = False
        elif a[i] == "--sem-blend":
            op["blend"] = False
        i += 1
    return op


# ----------------------------------------------------------------------------
# matemática
# ----------------------------------------------------------------------------
def rx(g):
    return Matrix.Rotation(math.radians(g), 3, "X")


def ry(g):
    return Matrix.Rotation(math.radians(g), 3, "Y")


def rz(g):
    return Matrix.Rotation(math.radians(g), 3, "Z")


def rot_corpo(inclina=0.0, rola=0.0, gira=0.0):
    """Rotação no referencial limpo do mundo (personagem olhando −Y).

    inclina > 0: topo vai para a frente (−Y, para a parede)
    rola    > 0: topo vai para a esquerda do personagem (+X)
    gira    > 0: vira para a esquerda (sentido do jogo: + = esquerda)
    """
    return rz(gira) @ ry(rola) @ rx(inclina)


def v3(*a):
    return Vector(a if len(a) == 3 else a[0])


def lerp(a, b, u):
    return a + (b - a) * u


def suave(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3.0 - 2.0 * u)


def suave5(u):
    u = min(1.0, max(0.0, u))
    return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


def janela(t, a, b):
    """0 antes de a, 1 depois de b, suave entre."""
    if b <= a:
        return 1.0 if t >= a else 0.0
    return suave((t - a) / (b - a))


def onda(t, periodo, fase=0.0):
    return math.sin(2.0 * math.pi * (t / periodo + fase))


def slerp_m(a, b, u):
    qa, qb = a.to_quaternion(), b.to_quaternion()
    if qa.dot(qb) < 0:
        qb.negate()
    return qa.slerp(qb, u).to_matrix()


class Curva:
    """Hermite cúbica monotônica (PCHIP) por componente.

    keys: [(t, valor)] com valor float ou tupla. Sem overshoot: segmentos
    planos ficam EXATAMENTE planos (apoio não escorrega) e extremos locais têm
    tangente zero (arcos). `ciclo=T` torna a curva periódica (com
    `passo` somado a cada período, p.ex. subir 0,60 m por ciclo).
    ini/fim: tangente nas pontas de curva não cíclica ('auto' ou número).
    """

    def __init__(self, keys, ciclo=None, passo=None, ini="auto", fim="auto"):
        ks = sorted(keys, key=lambda k: k[0])
        self.t = np.array([k[0] for k in ks], dtype=float)
        vals = [np.atleast_1d(np.array(k[1], dtype=float)) for k in ks]
        self.y = np.vstack(vals)
        self.dim = self.y.shape[1]
        self.escalar = not hasattr(ks[0][1], "__len__")
        self.ciclo = ciclo
        self.passo = np.zeros(self.dim) if passo is None else np.atleast_1d(np.array(passo, float))
        if ciclo is not None:
            # estende com vizinhos do ciclo anterior/seguinte para tangentes contínuas
            t = np.concatenate([self.t[-3:-1] - ciclo, self.t, self.t[1:3] + ciclo])
            y = np.vstack([self.y[-3:-1] - self.passo, self.y, self.y[1:3] + self.passo])
            d = self._tangentes(t, y, "auto", "auto")
            self.d = d[2:-2]
        else:
            self.d = self._tangentes(self.t, self.y, ini, fim)

    @staticmethod
    def _tangentes(t, y, ini, fim):
        n = len(t)
        d = np.zeros_like(y)
        if n < 2:
            return d
        h = np.diff(t)
        dl = np.diff(y, axis=0) / h[:, None]
        for k in range(1, n - 1):
            for c in range(y.shape[1]):
                a, b = dl[k - 1, c], dl[k, c]
                if a * b <= 0:
                    d[k, c] = 0.0
                else:
                    w1 = 2 * h[k] + h[k - 1]
                    w2 = h[k] + 2 * h[k - 1]
                    d[k, c] = (w1 + w2) / (w1 / a + w2 / b)
        for idx, modo, (k0, k1) in ((0, ini, (0, 1)), (n - 1, fim, (n - 2, n - 3))):
            if modo != "auto":
                d[idx, :] = modo
                continue
            if n == 2:
                d[idx, :] = dl[0]
                continue
            # fórmula de 3 pontos do PCHIP na ponta
            if idx == 0:
                h0, h1, m0, m1 = h[0], h[1], dl[0], dl[1]
            else:
                h0, h1, m0, m1 = h[-1], h[-2], dl[-1], dl[-2]
            dd = ((2 * h0 + h1) * m0 - h0 * m1) / (h0 + h1)
            for c in range(y.shape[1]):
                if np.sign(dd[c]) != np.sign(m0[c]):
                    dd[c] = 0.0
                elif np.sign(m0[c]) != np.sign(m1[c]) and abs(dd[c]) > abs(3 * m0[c]):
                    dd[c] = 3 * m0[c]
            d[idx] = dd
        return d

    def __call__(self, tt):
        k_extra = np.zeros(self.dim)
        if self.ciclo is not None:
            n_ciclos = math.floor((tt - self.t[0]) / self.ciclo)
            tt = tt - n_ciclos * self.ciclo
            k_extra = self.passo * n_ciclos
        if tt <= self.t[0]:
            r = self.y[0] + self.d[0] * (tt - self.t[0]) * 0  # segura a ponta
        elif tt >= self.t[-1]:
            r = self.y[-1].copy()
        else:
            i = int(np.searchsorted(self.t, tt) - 1)
            h = self.t[i + 1] - self.t[i]
            s = (tt - self.t[i]) / h
            h00 = 2 * s ** 3 - 3 * s ** 2 + 1
            h10 = s ** 3 - 2 * s ** 2 + s
            h01 = -2 * s ** 3 + 3 * s ** 2
            h11 = s ** 3 - s ** 2
            r = h00 * self.y[i] + h10 * h * self.d[i] + h01 * self.y[i + 1] + h11 * h * self.d[i + 1]
        r = r + k_extra
        if self.escalar:
            return float(r[0])
        return Vector(r) if self.dim == 3 else tuple(r)


# ----------------------------------------------------------------------------
# cena e rig
# ----------------------------------------------------------------------------
class Rig:
    """Guarda a armature, os controles e as medidas de repouso do X Bot."""

    def __init__(self):
        self.arm = None
        self.malhas = []
        self.ctrl = {}
        self.rest = {}       # osso -> Matrix 3x3 rotação de repouso no mundo
        self.cabeca = {}     # osso -> Vector posição de repouso (cabeça do osso) no mundo
        self.pega_local = {}  # lado -> ponto de pega no referencial do osso da mão
        self.ponta_local = {}  # lado -> ponta do pé no referencial do osso do pé
        self.G = {}           # lado -> rotação de mundo do osso da mão na pega canônica


def limpar_e_importar(rig):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.render.fps_base = 1.0
    tmp = Path(tempfile.mkdtemp(prefix="xbot_"))
    with zipfile.ZipFile(ZIP_PACOTE) as z:
        z.extract("X Bot.fbx", tmp)
    bpy.ops.wm.fbx_import(filepath=str(tmp / "X Bot.fbx"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.name = "XBot"
    rig.arm = arm
    rig.malhas = [o for o in bpy.data.objects if o.type == "MESH"]
    # a ação "mixamo.com" do X Bot é só a T-pose em 2 quadros: descarta
    if arm.animation_data:
        arm.animation_data.action = None
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    mw = arm.matrix_world
    R = mw.to_3x3().normalized()
    for b in arm.data.bones:
        rig.rest[b.name] = (R @ b.matrix_local.to_3x3()).normalized()
        rig.cabeca[b.name] = mw @ b.head_local
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def novo_vazio(nome, tam=0.08, tipo="PLAIN_AXES", pai=None, col=None):
    e = bpy.data.objects.new(nome, None)
    e.empty_display_type = tipo
    e.empty_display_size = tam
    (col or bpy.context.scene.collection).objects.link(e)
    e.rotation_mode = "QUATERNION"
    if pai is not None:
        e.parent = pai
    return e


def montar_rig(rig):
    arm = rig.arm
    col = bpy.data.collections.new("Controles")
    bpy.context.scene.collection.children.link(col)
    c = rig.ctrl

    # --- quadril: controle limpo + filho com a orientação de repouso do osso
    c["quadril"] = novo_vazio("CTRL_quadril", 0.25, "CUBE", col=col)
    filho = novo_vazio("OSSO_quadril", 0.05, pai=c["quadril"], col=col)
    filho.rotation_quaternion = rig.rest[P + "Hips"].to_quaternion()
    pb = arm.pose.bones[P + "Hips"]
    k = pb.constraints.new("COPY_LOCATION")
    k.name = "quadril_loc"
    k.target = filho
    k = pb.constraints.new("COPY_ROTATION")
    k.name = "quadril_rot"
    k.target = filho

    # pega canônica (rotação de mundo do osso da mão): dedos (Y do osso) para
    # cima, palma (Z do osso) para a parede (−Y). Igual para as duas mãos: o
    # polegar (X do osso na direita, −X na esquerda) fica para dentro.
    G = Matrix.Identity(3)
    G.col[0] = (1, 0, 0)
    G.col[1] = (0, 0, 1)
    G.col[2] = (0, -1, 0)

    for s in LADOS:
        mao, ante, braco, omb = osso(s, "Hand"), osso(s, "ForeArm"), osso(s, "Arm"), osso(s, "Shoulder")
        coxa, perna, pe, art = osso(s, "UpLeg"), osso(s, "Leg"), osso(s, "Foot"), osso(s, "ToeBase")
        rig.G[s] = G.copy()
        # ponto de pega: lado da palma (+Z local) sob a junta do dedo médio
        Rm = rig.rest[mao]
        pulso = rig.cabeca[mao]
        mcp = rig.cabeca[osso(s, "HandMiddle1")]
        rig.pega_local[s] = Rm.transposed() @ (mcp - pulso) + Vector((0, 0, 0.018))
        # ponta do pé (= cabeça do Toe_End, a ponta da malha)
        Rp = rig.rest[pe]
        rig.ponta_local[s] = Rp.transposed() @ (rig.cabeca[osso(s, "Toe_End")] - rig.cabeca[pe])

        # --- mão
        cm = c["mao_" + s] = novo_vazio("CTRL_mao_" + s, 0.07, "SPHERE", col=col)
        fm = novo_vazio("OSSO_mao_" + s, 0.04, pai=cm, col=col)
        fm.rotation_quaternion = G.to_quaternion()
        fm.location = -(G @ rig.pega_local[s])
        c["osso_mao_" + s] = fm
        pol = c["polo_cot_" + s] = novo_vazio("POLO_cotovelo_" + s, 0.06, "CONE", col=col)
        k = arm.pose.bones[ante].constraints.new("IK")
        k.name = "ik"
        k.target = fm
        k.pole_target = pol
        k.chain_count = 2
        k = arm.pose.bones[mao].constraints.new("COPY_ROTATION")
        k.name = "rot_mao"
        k.target = fm
        k = arm.pose.bones[omb].constraints.new("DAMPED_TRACK")
        k.name = "ombro_segue"
        k.target = cm
        k.influence = 0.22

        # --- pé
        cp = c["pe_" + s] = novo_vazio("CTRL_pe_" + s, 0.07, "SPHERE", col=col)
        fp = novo_vazio("OSSO_pe_" + s, 0.04, pai=cp, col=col)
        fp.rotation_quaternion = Rp.to_quaternion()
        fp.location = -(Rp @ rig.ponta_local[s])
        c["osso_pe_" + s] = fp
        polj = c["polo_joe_" + s] = novo_vazio("POLO_joelho_" + s, 0.06, "CONE", col=col)
        k = arm.pose.bones[perna].constraints.new("IK")
        k.name = "ik"
        k.target = fp
        k.pole_target = polj
        k.chain_count = 2
        k = arm.pose.bones[pe].constraints.new("COPY_ROTATION")
        k.name = "rot_pe"
        k.target = fp

        # dobradiças puras: joelho só em X local, cotovelo só em Z local, e só
        # no sentido natural (sem hiperextensão). Flexão: cotovelo esquerdo +Z,
        # direito −Z; joelho −X nos dois (eixos de repouso do X Bot).
        pbl = arm.pose.bones[perna]
        pbl.lock_ik_y = pbl.lock_ik_z = True
        pbl.use_ik_limit_x = True
        pbl.ik_min_x, pbl.ik_max_x = math.radians(-155), math.radians(-1)
        pba = arm.pose.bones[ante]
        pba.lock_ik_x = pba.lock_ik_y = True
        pba.use_ik_limit_z = True
        if s == "L":
            pba.ik_min_z, pba.ik_max_z = math.radians(1), math.radians(155)
        else:
            pba.ik_min_z, pba.ik_max_z = math.radians(-155), math.radians(-1)
    return col


# O antebraço do X Bot é PERFEITAMENTE reto na T-pose: o IK do Blender não
# consegue dobrar uma cadeia reta (gradiente nulo) e deixa o braço esticado
# com o pulso a 3-30 cm do alvo. Uma pré-dobra FK pequena no sentido natural
# resolve (medido: erro do pulso 0,0 cm). Os joelhos já vêm levemente dobrados.
PRE_DOBRA = {"L": Quaternion((0, 0, 1), math.radians(15)),
             "R": Quaternion((0, 0, 1), math.radians(-15))}
PRE_DOBRA_JOELHO = Quaternion((1, 0, 0), math.radians(-8))


def aplicar_pre_dobra(rig):
    for s in LADOS:
        rig.arm.pose.bones[osso(s, "ForeArm")].rotation_quaternion = PRE_DOBRA[s]
        rig.arm.pose.bones[osso(s, "Leg")].rotation_quaternion = PRE_DOBRA_JOELHO


def pose_calibracao(rig):
    """Pose com cotovelos e joelhos bem dobrados (plano do polo bem definido)."""
    H = Matrix.Identity(3)
    q = rig.cabeca[P + "Hips"].copy()
    pose = {"quadril_pos": q, "quadril_rot": H, "fk": {}, "mao": {}, "pe": {}, "polo": {}}
    for s, sx in (("L", 1), ("R", -1)):
        omb = rig.cabeca[osso(s, "Arm")]
        pose["mao"][s] = {"pos": omb + Vector((sx * 0.15, -0.25, 0.20)), "rot": Matrix.Identity(3)}
        pose["pe"][s] = {"pos": Vector((sx * 0.10, -0.25, 0.40)), "rot": Matrix.Identity(3)}
        pose["polo"]["cot_" + s] = omb + Vector((sx * 0.8, 0.3, -0.2))
        pose["polo"]["joe_" + s] = q + Vector((sx * 0.2, -0.9, -0.4))
    return pose


def ajustar_polos(rig):
    """Calibra pole_angle: o cotovelo/joelho tem de cair NO plano do polo."""
    aplicar_pose(rig, pose_calibracao(rig))
    aplicar_pre_dobra(rig)
    arm = rig.arm
    mw = arm.matrix_world
    for s in LADOS:
        for cadeia, polo in ((osso(s, "ForeArm"), "polo_cot_" + s), (osso(s, "Leg"), "polo_joe_" + s)):
            k = arm.pose.bones[cadeia].constraints["ik"]
            for _ in range(4):
                bpy.context.view_layer.update()
                pb = arm.pose.bones[cadeia]
                raiz = mw @ pb.parent.head
                meio = mw @ pb.head
                ponta = mw @ pb.tail
                pv = rig.ctrl[polo].matrix_world.translation
                eixo = (ponta - raiz).normalized()

                def proj(v):
                    v = v - eixo * v.dot(eixo)
                    return v.normalized()
                a, b = proj(meio - raiz), proj(pv - raiz)
                ang = math.atan2(eixo.dot(a.cross(b)), a.dot(b))
                if abs(ang) < 1e-4:
                    break
                k.pole_angle += ang
            print(f"[polo] {cadeia}: pole_angle={math.degrees(k.pole_angle):.1f}° (erro {math.degrees(ang):.3f}°)")


# ----------------------------------------------------------------------------
# pose -> controles
# ----------------------------------------------------------------------------
def q_local(rig, nome, D):
    """Rotação D (eixos do mundo, relativa ao pai) -> quaternion local do osso."""
    B = rig.rest[nome]
    return (B.transposed() @ D @ B).to_quaternion()


DEDOS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


def aplicar_pose(rig, pose):
    """Escreve uma pose (dict) nos controles e ossos FK (sem gravar chave)."""
    c = rig.ctrl
    arm = rig.arm
    qd = c["quadril"]
    qd.location = pose["quadril_pos"]
    qd.rotation_quaternion = pose["quadril_rot"].to_quaternion()
    for nome, D in pose["fk"].items():
        arm.pose.bones[nome].rotation_quaternion = q_local(rig, nome, D)
    for s in LADOS:
        m = pose["mao"][s]
        c["mao_" + s].location = m["pos"]
        c["mao_" + s].rotation_quaternion = m["rot"].to_quaternion()
        arm.pose.bones[osso(s, "Hand")].constraints["rot_mao"].influence = m.get("rot_inf", 1.0)
        p = pose["pe"][s]
        c["pe_" + s].location = p["pos"]
        c["pe_" + s].rotation_quaternion = p["rot"].to_quaternion()
        arm.pose.bones[osso(s, "Foot")].constraints["rot_pe"].influence = p.get("rot_inf", 1.0)
        c["polo_cot_" + s].location = pose["polo"]["cot_" + s]
        c["polo_joe_" + s].location = pose["polo"]["joe_" + s]


# ----------------------------------------------------------------------------
# construtor de pose
# ----------------------------------------------------------------------------
# dedos: ângulos (graus) das juntas 1/2/3 em torno do X local (+ = fecha p/ a palma)
DEDOS_SOLTO = {"Index": (12, 18, 10), "Middle": (14, 22, 12), "Ring": (16, 26, 14),
               "Pinky": (18, 30, 16)}
# pega de borda: a falange proximal passa por cima da quina, a média deita no
# topo e a ponta apoia (fechar mais faz a ponta voltar para baixo da quina e
# entrar na parede: medido -5,3 cm com 30/82/32°)
DEDOS_PEGA = {"Index": (8, 56, 18), "Middle": (10, 60, 20), "Ring": (12, 54, 14),
              "Pinky": (14, 44, 10)}
DEDOS_ABERTO = {"Index": (2, 4, 2), "Middle": (2, 4, 2), "Ring": (3, 5, 3), "Pinky": (4, 6, 4)}
ABERTURA = {"Index": -6, "Middle": 0, "Ring": 5, "Pinky": 10}  # leque (Z local, graus)


def pose_dedos(rig, s, pega=0.0, aberto=0.0):
    """Quaternions locais dos dedos: mistura solto/pega/aberto."""
    out = {}
    sinal = 1.0 if s == "R" else -1.0
    for d in ("Index", "Middle", "Ring", "Pinky"):
        for j in range(3):
            a = lerp(DEDOS_SOLTO[d][j], DEDOS_PEGA[d][j], pega)
            a = lerp(a, DEDOS_ABERTO[d][j], aberto)
            q = Quaternion((1, 0, 0), math.radians(a))
            if j == 0:
                q = Quaternion((0, 0, 1), math.radians(sinal * ABERTURA[d] * (0.4 + 0.6 * aberto))) @ q
            out[osso(s, "Hand" + d + str(j + 1))] = q
    # polegar: encosta ao lado do indicador na pega
    t1 = lerp(8, 2, pega) * (1 - aberto)
    # na T-pose o polegar já sai 28° para o lado da palma: na pega ele gira de
    # volta (X local −28°) e fica paralelo à palma, ao lado do indicador, sem
    # entrar na parede
    out[osso(s, "HandThumb1")] = (Quaternion((0, 0, 1), math.radians(sinal * lerp(4, 8, pega) * (1 - aberto)))
                                  @ Quaternion((1, 0, 0), math.radians(-33 * pega * (1 - aberto))))
    out[osso(s, "HandThumb2")] = Quaternion((1, 0, 0), math.radians(t1))
    out[osso(s, "HandThumb3")] = Quaternion((1, 0, 0), math.radians(lerp(10, 2, pega) * (1 - aberto)))
    return out


def no_quadril(pos, H, v):
    return pos + H @ Vector(v)


def montar_pose(rig, quadril_pos, quadril_rot, coluna, olhar, maos, pes, polos=None,
                ombros=None, apoio=None):
    """Pose completa (dict) a partir de parâmetros de alto nível.

    coluna: (inclina, rola, gira) total da coluna, ou lista de 3 tuplas
            (Spine, Spine1, Spine2) — permite atraso entre vértebras.
    olhar:  (inclina, gira, rola) do pescoço+cabeça (40 % / 60 %).
    maos[s]: pos (pega), rot (limpa), rot_inf, pega, aberto
    pes[s]:  pos (ponta), rot (limpa), rot_inf, artelho (graus, + = dedos p/ cima)
    polos:  dict opcional cot_L/cot_R/joe_L/joe_R (mundo); padrão relativo ao quadril
    ombros: dict opcional s -> graus de elevação da clavícula (FK, antes do damped track)
    apoio:  dict opcional membro -> bool (para as medições de escorregamento)
    """
    qp, H = Vector(quadril_pos), quadril_rot
    fk = {}
    if isinstance(coluna, list):
        cs = coluna
    else:
        cs = [tuple(x * f for x in coluna) for f in (0.34, 0.36, 0.30)]
    for nome, c in zip(("Spine", "Spine1", "Spine2"), cs):
        fk[P + nome] = rot_corpo(*c)
    oi, og, orr = olhar
    fk[P + "Neck"] = rot_corpo(inclina=oi * 0.4, gira=og * 0.4, rola=orr * 0.4)
    fk[P + "Head"] = rot_corpo(inclina=oi * 0.6, gira=og * 0.6, rola=orr * 0.6)
    for s, sx in (("L", 1), ("R", -1)):
        el = (ombros or {}).get(s, 0.0)
        fk[osso(s, "Shoulder")] = rot_corpo(rola=-sx * el)
    pose = {"quadril_pos": qp, "quadril_rot": H, "fk": fk, "mao": {}, "pe": {}, "polo": {},
            "local": {}, "apoio": apoio or {}}
    for s, sx in (("L", 1), ("R", -1)):
        m = dict(maos[s])
        pose["mao"][s] = m
        pose["local"].update(pose_dedos(rig, s, m.get("pega", 1.0), m.get("aberto", 0.0)))
        p = dict(pes[s])
        pose["pe"][s] = p
        pose["local"][osso(s, "ToeBase")] = Quaternion((1, 0, 0), math.radians(p.get("artelho", 0.0)))
        pol = polos or {}
        # cotovelo: mão alta -> cotovelo para fora/cima; mão baixa (puxando) -> para fora/baixo
        hz = (H.transposed() @ (Vector(m["pos"]) - qp)).z
        pz = min(0.55, max(-0.70, 0.55 + (hz - 1.0) * 2.2))
        pose["polo"]["cot_" + s] = pol.get("cot_" + s, no_quadril(qp, H, (sx * 0.85, 0.35, pz)))
        jp = HANG["joelho_polo"]
        pose["polo"]["joe_" + s] = pol.get("joe_" + s, no_quadril(qp, H, (sx * jp[0], jp[1], jp[2])))
    return pose


def _mix_m(a, b, u):
    return slerp_m(a, b, u)


def misturar_pose(a, b, u):
    """Pose intermediária a→b (u em [0,1]): lerp de posições, slerp de rotações."""
    if u <= 0.0:
        return a
    if u >= 1.0:
        return b
    r = {"quadril_pos": lerp(a["quadril_pos"], b["quadril_pos"], u),
         "quadril_rot": _mix_m(a["quadril_rot"], b["quadril_rot"], u),
         "fk": {k: _mix_m(a["fk"][k], b["fk"][k], u) for k in a["fk"]},
         "local": {}, "mao": {}, "pe": {}, "polo": {}, "apoio": dict(b.get("apoio", {}))}
    for k in a["local"]:
        qa, qb = a["local"][k], b["local"][k].copy()
        if qa.dot(qb) < 0:
            qb.negate()
        r["local"][k] = qa.slerp(qb, u)
    for grupo in ("mao", "pe"):
        for s in LADOS:
            ma, mb = a[grupo][s], b[grupo][s]
            m = {"pos": lerp(ma["pos"], mb["pos"], u), "rot": _mix_m(ma["rot"], mb["rot"], u)}
            for k in set(ma) | set(mb):
                if k in ("pos", "rot"):
                    continue
                va, vb = ma.get(k, 1.0 if k in ("rot_inf", "pega") else 0.0), mb.get(k, 1.0 if k in ("rot_inf", "pega") else 0.0)
                m[k] = lerp(va, vb, u)
            r[grupo][s] = m
    for k in a["polo"]:
        r["polo"][k] = lerp(a["polo"][k], b["polo"][k], u)
    return r


def aplicar_pose_completa(rig, pose):
    aplicar_pose(rig, pose)
    aplicar_pre_dobra(rig)
    for nome, q in pose["local"].items():
        rig.arm.pose.bones[nome].rotation_quaternion = q


# ----------------------------------------------------------------------------
# cena de validação (parede, agarras, câmeras)
# ----------------------------------------------------------------------------
COR = {"corpo": (0.56, 0.63, 0.78, 1), "juntas": (0.22, 0.24, 0.28, 1),
       "parede": (0.80, 0.74, 0.64, 1), "chao": (0.52, 0.56, 0.50, 1),
       "agarra": (0.30, 0.20, 0.14, 1), "topo": (0.70, 0.64, 0.55, 1)}


def caixa(nome, x0, x1, y0, y1, z0, z1, cor, col):
    me = bpy.data.meshes.new(nome)
    vs = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me.from_pydata(vs, [], fs)
    ob = bpy.data.objects.new(nome, me)
    ob.color = cor
    col.objects.link(ob)
    return ob


def montar_cenario(nome, agarras_mao, agarras_pe, com_borda):
    """Parede (sólido y < PAREDE_Y), chão e marcas das agarras usadas no clipe."""
    col = bpy.data.collections.new("Cenario_" + nome)
    bpy.context.scene.collection.children.link(col)
    topo = BORDA_Z if com_borda else 5.0
    caixa("parede_" + nome, -1.6, 1.6, PAREDE_Y - (2.5 if com_borda else 0.5), PAREDE_Y, 0.0, topo,
          COR["parede"], col)
    caixa("chao_" + nome, -3, 3, -3.5, 3.5, -0.02, 0.0, COR["chao"], col)
    for i, (x, z) in enumerate(agarras_mao):
        # rasgo/borda da agarra: a quina fica em z, a pega 2 cm abaixo
        caixa(f"agarra_{nome}_{i}", x - 0.08, x + 0.08, PAREDE_Y - 0.004, PAREDE_Y + 0.004,
              z - 0.035, z, COR["agarra"], col)
    for i, (x, z) in enumerate(agarras_pe):
        caixa(f"apoio_pe_{nome}_{i}", x - 0.05, x + 0.05, PAREDE_Y - 0.004, PAREDE_Y + 0.004,
              z - 0.03, z + 0.03, COR["agarra"], col)
    return col


def preparar_render(rig):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.show_shadows = False
    if sc.world is None:
        sc.world = bpy.data.worlds.new("Mundo")
    sc.world.color = (0.93, 0.93, 0.95)
    sc.render.resolution_x = 300
    sc.render.resolution_y = 420
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.use_stamp = True
    for k in ("date", "time", "render_time", "frame", "scene", "camera", "lens", "filename",
              "marker", "sequencer_strip", "memory", "frame_range", "hostname"):
        if hasattr(sc.render, "use_stamp_" + k):
            setattr(sc.render, "use_stamp_" + k, False)
    sc.render.use_stamp_note = True
    sc.render.stamp_font_size = 13
    sc.render.stamp_background = (1, 1, 1, 0.7)
    sc.render.stamp_foreground = (0, 0, 0, 1)
    for o in rig.malhas:
        o.color = COR["corpo"] if "Surface" in o.name else COR["juntas"]
    cams = {}
    for nome in ("lado", "tres_quartos"):
        cd = bpy.data.cameras.new("cam_" + nome)
        cam = bpy.data.objects.new("cam_" + nome, cd)
        sc.collection.objects.link(cam)
        cams[nome] = cam
    return cams


def enquadrar(cams, centro, altura_vista):
    """Câmera de lado (ortográfica, olhando −X) e de 3/4 por trás-esquerda."""
    c = Vector(centro)
    lado = cams["lado"]
    lado.data.type = "ORTHO"
    lado.data.ortho_scale = altura_vista
    lado.location = (c.x + 8.0, c.y, c.z)
    lado.rotation_euler = (math.radians(90), 0, math.radians(90))
    tq = cams["tres_quartos"]
    tq.data.type = "PERSP"
    tq.data.lens = 40
    d = Vector((2.3, 3.3, 1.2)).normalized() * (altura_vista * 1.05 + 0.6)
    tq.location = c + d
    tq.rotation_mode = "QUATERNION"
    tq.rotation_quaternion = (-d).to_track_quat("-Z", "Y")


def renderizar_quadro(cam, caminho, nota):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.stamp_note_text = nota
    sc.render.filepath = str(caminho)
    bpy.ops.render.render(write_still=True)


def folha(caminhos_linhas, saida):
    """Junta PNGs numa grade (linhas = vistas, colunas = quadros)."""
    linhas = []
    for linha in caminhos_linhas:
        ims = []
        for p in linha:
            im = bpy.data.images.load(str(p))
            w, h = im.size
            a = np.empty(w * h * 4, dtype=np.float32)
            im.pixels.foreach_get(a)
            ims.append(a.reshape(h, w, 4))
            bpy.data.images.remove(im)
        linhas.append(np.concatenate(ims, axis=1))
    # imagens do Blender são de baixo para cima: a 1ª linha vai para o topo
    grade = np.concatenate(linhas[::-1], axis=0)
    h, w = grade.shape[:2]
    out = bpy.data.images.new("folha", w, h, alpha=False)
    out.pixels.foreach_set(grade.ravel())
    out.filepath_raw = str(saida)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


# ----------------------------------------------------------------------------
# CLIPES
# ----------------------------------------------------------------------------
# Pose "braced hang": mãos em duas agarras na largura dos ombros, braços quase
# estendidos, peito ~0,30 m da parede, pés na parede ~0,9 m abaixo do quadril.
HANG = dict(
    mao_x=0.20,                       # meia distância entre as mãos
    mao_z=BORDA_Z - FOLGA_PEGA,       # ponto de pega (2 cm abaixo da quina)
    mao_y=PAREDE_Y + 0.010,           # pega rente à parede
    mao_inclina=18.0,                 # dedos inclinados para a parede (passam a quina)
    mao_rola=12.0,                    # dedos levemente para dentro: o lado do mínimo sobe
    quadril=(0.0, 0.02, 1.185),       # quadril ~0,32 m da parede, braços ~155°
    quadril_inclina=8.0,
    coluna=(4.0, 0.0, 0.0),
    olhar=(-18.0, 0.0, 0.0),
    pe_x=0.17,
    pe_dz=0.90,                       # ponta do pé abaixo do quadril
    pe_y=PAREDE_Y + 0.004,
    pe_inclina=12.0,
    artelho=18.0,
    joelho_polo=(0.85, -0.55, -0.15),  # joelhos para fora e para a frente ("sapo")
)


def rot_mao_pega(s):
    """Orientação limpa da mão agarrada (pega de borda)."""
    return rot_corpo(HANG["mao_inclina"], rola=(-1 if s == "L" else 1) * HANG["mao_rola"])


def mao_hang(s, dx=0.0, dz=0.0):
    sx = 1 if s == "L" else -1
    return Vector((sx * HANG["mao_x"] + dx, HANG["mao_y"], HANG["mao_z"] + dz))


def pe_hang(s, dx=0.0, dz=0.0):
    sx = 1 if s == "L" else -1
    return Vector((sx * HANG["pe_x"] + dx, HANG["pe_y"], HANG["quadril"][2] - HANG["pe_dz"] + dz))


def params_hang(t):
    """Parâmetros do hang_idle no instante t (ciclo de 2,0 s).

    Respiração (1 por ciclo) e troca de peso lateral; peito e cabeça seguem o
    quadril com atraso. Os outros clipes partem/terminam em params_hang(0).
    """
    T = 2.0
    w = 2.0 * math.pi * t / T
    resp = math.sin(w)                 # inspira no 1º quarto
    peso = math.sin(w + 0.5)           # quadril vai à esquerda e volta
    atraso = math.sin(w + 0.5 - 0.9)   # cabeça/peito seguem o quadril com atraso
    return {
        "dq": Vector((0.026 * peso, 0.010 * math.sin(2 * w + 0.3), 0.007 * resp)),
        "incl": 0.8 * resp, "rola": -2.2 * peso, "gira": 1.6 * math.sin(w + 0.9),
        "coluna": [(HANG["coluna"][0] * 0.34 + 0.0 - 0.5 * resp, 1.2 * atraso, 0.8 * atraso),
                   (HANG["coluna"][0] * 0.36 + 0.0 - 0.8 * resp, 1.0 * atraso, 0.8 * atraso),
                   (HANG["coluna"][0] * 0.30 + 0.0 - 1.1 * resp, 0.6 * atraso, 0.6 * atraso)],
        "olhar": (HANG["olhar"][0] + 2.0 * math.sin(w - 1.2), 5.0 * atraso, 0.0),
        "ombros": {"L": 1.5 * resp, "R": 1.5 * resp},
    }


def somar_coluna(coluna, delta):
    """Soma (inclina, rola, gira) total distribuído nas 3 vértebras (34/36/30 %)."""
    return [tuple(c[i] + delta[i] * f for i in range(3)) for c, f in zip(coluna, (0.34, 0.36, 0.30))]


def pose_hang_base(rig, p=None, maos=None, pes=None, apoio=None, polos=None):
    """Pose de hang a partir dos parâmetros p (padrão: hang parado).

    maos/pes: substituem os apoios do hang (dicts por lado) quando dados.
    """
    p = p or params_hang(0.0)
    qp = Vector(HANG["quadril"]) + Vector(p["dq"])
    H = rot_corpo(HANG["quadril_inclina"] + p["incl"], p["rola"], p["gira"])
    m = {s: {"pos": mao_hang(s), "rot": rot_mao_pega(s), "pega": 1.0} for s in LADOS}
    m.update(maos or {})
    pe = {s: {"pos": pe_hang(s), "rot": rot_corpo(HANG["pe_inclina"]), "artelho": HANG["artelho"]}
          for s in LADOS}
    pe.update(pes or {})
    ap = {"mao_L": True, "mao_R": True, "pe_L": True, "pe_R": True}
    ap.update(apoio or {})
    return montar_pose(rig, qp, H, p["coluna"], p["olhar"], m, pe, polos=polos,
                       ombros=p.get("ombros"), apoio=ap)


def viagem(t, t0, t1, p0, p1, afasta=0.08, arco_z=0.0):
    """Trajeto de mão/pé entre dois apoios: descola da parede (+Y) em arco e
    assenta com velocidade zero. Devolve (pos, u, no_ar)."""
    if t <= t0:
        return Vector(p0), 0.0, False
    if t >= t1:
        return Vector(p1), 1.0, False
    u = (t - t0) / (t1 - t0)
    e = suave5(u)
    pos = Vector(p0).lerp(Vector(p1), e)
    pos.y += afasta * math.sin(math.pi * u)
    pos.z += arco_z * math.sin(math.pi * u)
    return pos, u, True


class Clipe:
    """Um clipe: nome, duração, função pose(rig, t) e o que medir nele."""

    def __init__(self, nome, duracao, pose_fn, ciclo=False, passo=(0, 0, 0), com_borda=False,
                 continuidade=None, giro_esperado=0.0):
        self.nome = nome
        self.n = int(round(duracao * FPS))
        self.duracao = self.n / FPS
        self.pose_fn = pose_fn
        self.ciclo = ciclo
        self.passo = Vector(passo)
        self.com_borda = com_borda
        # continuidade: [("fim"|"inicio", "hang_idle")] — comparar com hang_idle quadro 0
        self.continuidade = continuidade or []
        self.giro_esperado = giro_esperado
        self.apoio = {}      # quadro -> dict membro -> bool
        self.quadril = {}    # quadro -> Vector (do pose_fn, para enquadrar)
        self.alvos = {}      # quadro -> membro -> Vector (alvo de contato pedido)

    def agarras(self):
        """Apoios usados (mão: (x, z da quina); pé: (x, z)), sem repetição."""
        maos, pes = [], []
        for f in sorted(self.apoio):
            for m, ok in self.apoio[f].items():
                if not ok:
                    continue
                p = self.alvos[f][m]
                if m.startswith("mao"):
                    item, lista = (p.x, p.z + FOLGA_PEGA), maos
                else:
                    item, lista = (p.x, p.z), pes
                if all(abs(item[0] - a) > 0.03 or abs(item[1] - b) > 0.03 for a, b in lista):
                    lista.append(item)
        return maos, pes

    def pose(self, rig, f):
        return self.pose_fn(rig, f / FPS)


def pose_hang_idle(rig, t):
    """Ciclo de 2,0 s: respiração (1 por ciclo) e troca de peso lateral."""
    return pose_hang_base(rig, params_hang(t))


# ----------------------------------------------------------------------------
# gravação, bake, medição, render, export
# ----------------------------------------------------------------------------
CONTROLES = ("quadril", "mao_L", "mao_R", "pe_L", "pe_R", "polo_cot_L", "polo_cot_R",
             "polo_joe_L", "polo_joe_R")


def _q_cont(q, ant):
    if ant is not None and q.dot(ant) < 0:
        q = q.copy()
        q.negate()
    return q


def gravar_controles(rig, clipe):
    """Grava as curvas do clipe nos controles (1 chave por quadro, Bezier)."""
    acao = bpy.data.actions.new(clipe.nome + "_controle")
    acao.use_fake_user = True
    objs = [rig.arm] + [rig.ctrl[k] for k in CONTROLES]
    for o in objs:
        ad = o.animation_data_create()
        ad.action = acao
        if ad.action_slot is None:
            slot = acao.slots.new(id_type="OBJECT", name=o.name)
            ad.action_slot = slot
    ant = {}
    arm = rig.arm
    for f in range(clipe.n + 1):
        pose = clipe.pose(rig, f)
        clipe.apoio[f] = dict(pose.get("apoio", {}))
        clipe.quadril[f] = pose["quadril_pos"].copy()
        clipe.alvos[f] = {"mao_" + s: pose["mao"][s]["pos"].copy() for s in LADOS}
        clipe.alvos[f].update({"pe_" + s: pose["pe"][s]["pos"].copy() for s in LADOS})
        aplicar_pose_completa(rig, pose)
        for k in CONTROLES:
            o = rig.ctrl[k]
            o.keyframe_insert("location", frame=f)
            if not k.startswith("polo"):
                o.rotation_quaternion = _q_cont(o.rotation_quaternion, ant.get(k))
                ant[k] = o.rotation_quaternion.copy()
                o.keyframe_insert("rotation_quaternion", frame=f)
        for nome in list(pose["fk"]) + list(pose["local"]):
            pb = arm.pose.bones[nome]
            pb.rotation_quaternion = _q_cont(pb.rotation_quaternion, ant.get(nome))
            ant[nome] = pb.rotation_quaternion.copy()
            pb.keyframe_insert("rotation_quaternion", frame=f)
        for s in LADOS:
            arm.pose.bones[osso(s, "Hand")].constraints["rot_mao"].keyframe_insert("influence", frame=f)
            arm.pose.bones[osso(s, "Foot")].constraints["rot_pe"].keyframe_insert("influence", frame=f)
    return acao


def assar(rig, clipe):
    """IK + restrições -> FK puro (visual keying), numa ação nova com o nome do clipe."""
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, clipe.n
    arm = rig.arm
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=0, frame_end=clipe.n, step=1, only_selected=True,
                     visual_keying=True, clear_constraints=False, clear_parents=False,
                     use_current_action=False, clean_curves=False, bake_types={"POSE"},
                     channel_types={"LOCATION", "ROTATION", "SCALE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    acao = arm.animation_data.action
    acao.name = clipe.nome
    acao.use_fake_user = True
    return acao


def usar_acao(rig, acao):
    ad = rig.arm.animation_data_create()
    ad.action = acao
    if len(acao.slots):
        ad.action_slot = acao.slots[0]


def remover_restricoes(rig):
    for pb in rig.arm.pose.bones:
        for k in list(pb.constraints):
            pb.constraints.remove(k)


def exportar_glb(rig, clipe, acao):
    DIR_GLB.mkdir(parents=True, exist_ok=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, clipe.n
    usar_acao(rig, acao)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.arm.select_set(True)
    bpy.context.view_layer.objects.active = rig.arm
    caminho = DIR_GLB / (clipe.nome + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=str(caminho), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_range=True, export_anim_single_armature=True,
        export_skins=True, export_def_bones=False, export_leaf_bone=False,
        export_nla_strips_merged_animation_name=clipe.nome)
    return caminho


# ---- medição ----------------------------------------------------------------
def classificar_vertices(rig):
    """Parte do corpo de cada vértice (grupo de maior peso)."""
    partes = {}
    for ob in rig.malhas:
        nomes = [g.name for g in ob.vertex_groups]
        rot = []
        for v in ob.data.vertices:
            melhor, peso = "", -1.0
            for g in v.groups:
                if g.weight > peso:
                    melhor, peso = nomes[g.group], g.weight
            n = melhor.replace(P, "")
            if "Hand" in n:
                parte = "maos"
            elif any(k in n for k in ("Foot", "ToeBase", "Toe_End")):
                parte = "pes"
            elif n in ("Hips", "Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder"):
                parte = "tronco"
            elif n in ("Neck", "Head", "HeadTop_End"):
                parte = "cabeca"
            else:
                parte = "membros"
            rot.append(parte)
        partes[ob.name] = np.array(rot)
    return partes


def dist_parede(pts, com_borda, agarras_mao=(), eh_mao=False):
    """Distância com sinal ao sólido da parede (>0 fora, <0 dentro), em metros."""
    y, z = pts[:, 1], pts[:, 2]
    if not com_borda:
        d = y - PAREDE_Y
    else:
        dy, dz = y - PAREDE_Y, z - BORDA_Z
        d = np.where((dy >= 0) & (dz >= 0), np.sqrt(np.maximum(dy, 0) ** 2 + np.maximum(dz, 0) ** 2),
                     np.where(dy >= 0, dy, np.where(dz >= 0, dz, -np.minimum(-dy, -dz))))
    if eh_mao:
        # os dedos entram no rasgo da agarra (acima da quina, até 6 cm de fundo)
        for hx, hz in agarras_mao:
            dentro = (np.abs(pts[:, 0] - hx) <= 0.09) & (z >= hz - 0.002) & (z <= hz + 0.07) & \
                     (y >= PAREDE_Y - 0.06)
            d = np.where(dentro, np.maximum(d, 0.0), d)
    return d


def swing_twist_y(q):
    """Separa q em torção em torno do Y local (graus) e o resto."""
    tw = Quaternion((q.w, 0.0, q.y, 0.0))
    if tw.magnitude < 1e-9:
        return 180.0, q
    tw.normalize()
    ang = math.degrees(2.0 * math.atan2(tw.y, tw.w))
    ang = (ang + 180.0) % 360.0 - 180.0
    return ang, q @ tw.inverted()


def ang_q(a, b):
    return math.degrees(a.rotation_difference(b).angle) % 360.0


def ang_q_min(a, b):
    x = ang_q(a, b)
    return min(x, 360.0 - x)


def pose_local(rig):
    arm = rig.arm
    return {pb.name: pb.matrix_basis.to_quaternion().normalized() for pb in arm.pose.bones}


def pos_osso(rig, nome):
    return rig.arm.matrix_world @ rig.arm.pose.bones[nome].head


def ponto_pega(rig, s):
    arm = rig.arm
    k = 1.0 / arm.matrix_world.to_scale()[0]
    pb = arm.pose.bones[osso(s, "Hand")]
    return arm.matrix_world @ (pb.matrix @ (rig.pega_local[s] * k))


def rumo_quadril(rig):
    """Rumo (rad) da frente do quadril; + = virou para a esquerda (sentido do jogo)."""
    arm = rig.arm
    M = arm.matrix_world.to_3x3().normalized() @ arm.pose.bones[P + "Hips"].matrix.to_3x3()
    frente = M.col[2]  # Z local do Hips = frente (−Y em repouso)
    return math.atan2(frente.x, -frente.y)


def medir_clipe(rig, clipe, acao, partes):
    usar_acao(rig, acao)
    sc = bpy.context.scene
    maos_ag, _ = clipe.agarras()
    contato = {}
    folga = {k: math.inf for k in ("maos", "pes", "tronco", "cabeca", "membros")}
    folga_q = {k: None for k in folga}
    juntas = {"cotovelo_interno_min": 180.0, "cotovelo_interno_max": 0.0, "cotovelo_hiperext_max": 0.0,
              "cotovelo_fora_do_eixo_max": 0.0, "joelho_interno_min": 180.0, "joelho_interno_max": 0.0,
              "joelho_hiperext_max": 0.0, "joelho_torcao_max": 0.0, "joelho_fora_do_eixo_max": 0.0,
              "punho_max": 0.0}
    poses = {}
    rumo0, rumo_ant, giro = None, None, 0.0
    quadril = {}
    ref_rt = {}
    for f in range(clipe.n + 1):
        sc.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        poses[f] = pose_local(rig)
        quadril[f] = pos_osso(rig, P + "Hips")
        if f in (0, clipe.n // 3, (2 * clipe.n) // 3, clipe.n):
            ref_rt[f] = {pb.name: list(rig.arm.matrix_world @ pb.head) for pb in rig.arm.pose.bones}
        r = rumo_quadril(rig)
        if rumo0 is None:
            rumo0 = rumo_ant = r
        else:
            dr = (r - rumo_ant + math.pi) % (2 * math.pi) - math.pi
            giro += dr
            rumo_ant = r
        # pontos de contato
        for s in LADOS:
            for m, p in (("mao_" + s, ponto_pega(rig, s)), ("pe_" + s, pos_osso(rig, osso(s, "Toe_End")))):
                contato.setdefault(m, {})[f] = p.copy()
        # folga da parede por parte do corpo (vértices deformados)
        for ob in rig.malhas:
            ev = ob.evaluated_get(dg)
            me = ev.to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            ev.to_mesh_clear()
            W = np.array(ob.matrix_world)
            pts = co.reshape(-1, 3) @ W[:3, :3].T + W[:3, 3]
            for parte in folga:
                sel = partes[ob.name] == parte
                if not sel.any():
                    continue
                d = dist_parede(pts[sel], clipe.com_borda, maos_ag, eh_mao=(parte == "maos")).min()
                if d < folga[parte]:
                    folga[parte], folga_q[parte] = float(d), f
        # juntas
        for s, sinal_cot in (("L", 1.0), ("R", -1.0)):
            q = poses[f][osso(s, "ForeArm")]
            tw, sw = swing_twist_y(q)
            flex = math.degrees(2 * math.atan2(sw.z, sw.w)) * sinal_cot
            fora = math.degrees(2 * math.asin(min(1.0, abs(sw.x))))
            juntas["cotovelo_interno_min"] = min(juntas["cotovelo_interno_min"], 180 - flex)
            juntas["cotovelo_interno_max"] = max(juntas["cotovelo_interno_max"], 180 - flex)
            juntas["cotovelo_hiperext_max"] = max(juntas["cotovelo_hiperext_max"], -flex)
            juntas["cotovelo_fora_do_eixo_max"] = max(juntas["cotovelo_fora_do_eixo_max"], fora)
            q = poses[f][osso(s, "Leg")]
            tw, sw = swing_twist_y(q)
            flex = -math.degrees(2 * math.atan2(sw.x, sw.w))
            fora = math.degrees(2 * math.asin(min(1.0, abs(sw.z))))
            juntas["joelho_interno_min"] = min(juntas["joelho_interno_min"], 180 - flex)
            juntas["joelho_interno_max"] = max(juntas["joelho_interno_max"], 180 - flex)
            juntas["joelho_hiperext_max"] = max(juntas["joelho_hiperext_max"], -flex)
            juntas["joelho_torcao_max"] = max(juntas["joelho_torcao_max"], abs(tw))
            juntas["joelho_fora_do_eixo_max"] = max(juntas["joelho_fora_do_eixo_max"], fora)
            juntas["punho_max"] = max(juntas["punho_max"], ang_q_min(poses[f][osso(s, "Hand")], Quaternion()))
    # escorregamento: por intervalo contínuo de apoio, maior desvio do 1º quadro
    escorrega = {}
    for m in contato:
        pior, ini = 0.0, None
        for f in range(clipe.n + 1):
            ap = clipe.apoio.get(f, {}).get(m, False)
            if ap and ini is None:
                ini = f
            if ap:
                pior = max(pior, (contato[m][f] - contato[m][ini]).length)
            else:
                ini = None
        quadros_apoio = sum(1 for f in range(clipe.n + 1) if clipe.apoio.get(f, {}).get(m, False))
        escorrega[m] = {"max_cm": round(pior * 100, 3), "quadros_apoiado": quadros_apoio}
    res = {
        "duracao_s": round(clipe.duracao, 4), "quadros": clipe.n + 1, "qps": FPS,
        "deslocamento_quadril_m": [round(v, 4) for v in (quadril[clipe.n] - quadril[0])],
        "deslocamento_quadril_jogo_m": [round(v, 4) for v in blender_para_jogo(quadril[clipe.n] - quadril[0])],
        "quadril_inicio_m": [round(v, 4) for v in quadril[0]],
        "quadril_fim_m": [round(v, 4) for v in quadril[clipe.n]],
        "giro_quadril_graus": round(math.degrees(giro), 2),
        "escorregamento_contato": escorrega,
        "folga_parede_cm": {k: (round(v * 100, 2), folga_q[k]) for k, v in folga.items()},
        "juntas_graus": {k: round(v, 2) for k, v in juntas.items()},
    }
    if clipe.ciclo:
        dif = max(ang_q_min(poses[0][b], poses[clipe.n][b]) for b in poses[0] if b != P + "Hips")
        dif_q = ang_q_min(poses[0][P + "Hips"], poses[clipe.n][P + "Hips"])
        erro_passo = ((quadril[clipe.n] - quadril[0]) - clipe.passo).length
        res["ciclo"] = {"dif_max_osso_graus": round(max(dif, dif_q), 4),
                        "erro_deslocamento_ciclo_cm": round(erro_passo * 100, 4),
                        "passo_esperado_m": list(clipe.passo)}
    return res, poses, quadril, ref_rt


def blender_para_jogo(v):
    """Vetor da cena do Blender -> espaço do JOGO do contrato (frente −Z, direita +X, cima +Y).

    O glTF leva (x, y, z) -> (x, z, −y) (o personagem fica olhando +Z) e o baker
    gira 180° em Y (yflip): resultado (−x, z, y). Frente do Blender (−Y) vira −Z
    e a esquerda do personagem (+X no Blender) vira −X.
    """
    return Vector((-v.x, v.z, v.y))


def comparar_poses(pa, pb_):
    return max(ang_q_min(pa[b], pb_[b]) for b in pa)


# ---- render das folhas ---------------------------------------------------------
def quadros_folha(n, k=8):
    return [int(round(i * n / (k - 1))) for i in range(k)]


def enquadramento(pontos):
    ys = [p.y for p in pontos]
    zs = [p.z for p in pontos]
    centro = Vector((0.0, (min(ys) + max(ys)) / 2 - 0.05, (min(zs) + max(zs)) / 2 + 0.25))
    altura = max(2.9, (max(zs) - min(zs)) + 2.3, (max(ys) - min(ys)) * 1.4 + 2.0)
    return centro, altura


def renderizar_clipe(rig, clipe, acao, cams, colecoes, tmp):
    usar_acao(rig, acao)
    for nome, col in colecoes.items():
        col.hide_render = nome != clipe.nome
    centro, altura = enquadramento([clipe.quadril[f] for f in clipe.quadril])
    enquadrar(cams, centro, altura)
    linhas = {"lado": [], "tres_quartos": []}
    for f in quadros_folha(clipe.n):
        bpy.context.scene.frame_set(f)
        for vista in linhas:
            arq = Path(tmp) / f"{clipe.nome}_{vista}_{f:03d}.png"
            renderizar_quadro(cams[vista], arq, f"{clipe.nome}  q{f}  {f / FPS:.2f}s")
            linhas[vista].append(arq)
    DIR_VAL.mkdir(parents=True, exist_ok=True)
    saida = DIR_VAL / f"{clipe.nome}.png"
    folha([linhas["lado"], linhas["tres_quartos"]], saida)
    return saida


def comparar_com_referencia(rig, clipe, acao, cams, colecoes, tmp):
    """Folha lado a lado: Mixamo 'Climbing Up Wall' x nosso climb_up_loop."""
    antes = set(bpy.data.objects)
    bpy.ops.wm.fbx_import(filepath=str(FBX_REFERENCIA))
    novos = [o for o in bpy.data.objects if o not in antes]
    ref = next(o for o in novos if o.type == "ARMATURE")
    ref_malhas = [o for o in novos if o.type == "MESH"]
    for o in ref_malhas:
        o.color = COR["corpo"] if "Surface" in o.name else COR["juntas"]
    acao_ref = ref.animation_data.action
    f0, f1 = int(acao_ref.frame_range[0]), int(acao_ref.frame_range[1])
    for nome, col in colecoes.items():
        col.hide_render = nome != clipe.nome
    mw = ref.matrix_world
    pts_ref = []
    for f in range(f0, f1 + 1, 4):
        bpy.context.scene.frame_set(f)
        pts_ref.append(mw @ ref.pose.bones[P + "Hips"].head)
    c_ref, h_ref = enquadramento(pts_ref)
    c_meu, h_meu = enquadramento([clipe.quadril[f] for f in clipe.quadril])
    altura = max(h_ref, h_meu)
    linhas = []
    usar_acao(rig, acao)
    for vista in ("lado", "tres_quartos"):
        for quem in ("ref", "meu"):
            for o in rig.malhas:
                o.hide_render = quem == "ref"
            for o in ref_malhas:
                o.hide_render = quem == "meu"
            enquadrar(cams, c_ref if quem == "ref" else c_meu, altura)
            linha = []
            if quem == "ref":
                fs = [int(round(f0 + i * (f1 - f0) / 7)) for i in range(8)]
                rot = "Mixamo Climbing Up Wall"
            else:
                fs = quadros_folha(clipe.n)
                rot = clipe.nome
            for f in fs:
                bpy.context.scene.frame_set(f)
                arq = Path(tmp) / f"cmp_{quem}_{vista}_{f:03d}.png"
                renderizar_quadro(cams[vista], arq, f"{rot}  q{f}")
                linha.append(arq)
            linhas.append(linha)
    saida = DIR_VAL / "comparacao_climbing_up_wall.png"
    folha(linhas, saida)
    for o in rig.malhas:
        o.hide_render = False
    for o in novos:
        bpy.data.objects.remove(o, do_unlink=True)
    return saida


def ida_e_volta_glb(ref_por_clipe):
    """Reimporta cada GLB numa cena limpa e compara posições de osso (mm)."""
    out = {}
    for nome, ref in ref_por_clipe.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps = FPS
        caminho = DIR_GLB / f"{nome}.glb"
        bpy.ops.import_scene.gltf(filepath=str(caminho))
        arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        acao = arm.animation_data.action
        ini = int(round(acao.frame_range[0]))
        pior = 0.0
        for f, pos in ref.items():
            bpy.context.scene.frame_set(ini + f)
            for nb, p in pos.items():
                if nb not in arm.pose.bones:
                    continue
                q = arm.matrix_world @ arm.pose.bones[nb].head
                pior = max(pior, (q - Vector(p)).length)
        out[nome] = {"erro_max_mm": round(pior * 1000, 3), "acao": acao.name,
                     "quadro_inicial": ini, "faixa": list(acao.frame_range)}
        out[nome].update(inspecionar_glb(caminho))
    return out


def inspecionar_glb(caminho):
    import struct
    b = Path(caminho).read_bytes()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    an = j.get("animations", [])
    tempos = []
    for a in an:
        for smp in a["samplers"]:
            acc = j["accessors"][smp["input"]]
            tempos.append((acc["min"][0], acc["max"][0], acc["count"]))
    return {"animacoes": [a["name"] for a in an], "canais": sum(len(a["channels"]) for a in an),
            "malhas": len(j.get("meshes", [])), "skins": len(j.get("skins", [])),
            "tempo_min_s": min(t[0] for t in tempos), "tempo_max_s": max(t[1] for t in tempos),
            "amostras": max(t[2] for t in tempos),
            "ossos_mixamorig": sum(1 for nd in j["nodes"] if nd.get("name", "").startswith(P))}


# ---- escalada tipo escada (subir / descer) -----------------------------------
SUBIDA = dict(T=0.9, passo=0.60, mao_x=0.20, pe_x=0.17,
              folga_alcance=0.035,  # mão de cima 3,5 cm abaixo da do hang (que já é ~alcance máx.)
              alto_pe=-0.60,     # pé de cima: relativo ao quadril
              amp_x=0.045, k_ritmo=0.55)


def _g_ritmo(u, k):
    """Progresso do quadril na meia-fase: lento nas trocas de apoio, rápido no meio."""
    return u - k * math.sin(2 * math.pi * u) / (2 * math.pi)


# Descendo, o quadril só pode baixar ~4 cm antes de a mão de cima soltar (ela já
# está perto do alcance máximo, +1,06 m) e precisa ter baixado >= 0,22 m para o
# pé alcançar o apoio novo. Curva cíclica (passo 1 por meia-fase) com essas chaves.
G_DESCE = Curva([(0.0, 0.0), (0.18, 0.12), (0.45, 0.42), (0.72, 0.78), (1.0, 1.0)], ciclo=1.0,
                passo=1.0)


def pose_escalada(rig, t, sentido):
    """Meia-fase u em [0,1]: a mão de baixo (subindo) ou de cima (descendo) e o pé
    contralateral trocam de apoio, 0,60 m; o quadril anda 0,30 m. A meia-fase
    seguinte é o espelho (esquerda<->direita) — o ciclo de 0,9 s fecha em 0,60 m.

    Pose de troca (u=0): mão E em cima (= altura do hang), mão D 0,30 abaixo;
    pé D em cima (−0,60), pé E embaixo (−0,90). Subir e descer começam nela.
    """
    c = SUBIDA
    meia = c["T"] / 2
    k = min(int(math.floor(t / meia + 1e-9)), 2)
    u = (t - k * meia) / meia
    if k == 2:
        k, u = 1, 1.0
    alto_mao = HANG["mao_z"] - HANG["quadril"][2] - c["folga_alcance"]
    sobe = 1.0 if sentido > 0 else -1.0
    # descer começa 0,60 m mais alto e termina na pose inicial da subida
    z0 = HANG["quadril"][2] + (0.0 if sentido > 0 else 0.60) + sobe * 0.30 * k
    # quem se move nesta meia-fase
    if sentido > 0:
        mao_mov = "R" if k % 2 == 0 else "L"
    else:
        mao_mov = "L" if k % 2 == 0 else "R"
    mao_fix = "L" if mao_mov == "R" else "R"
    pe_mov, pe_fix = mao_fix, mao_mov
    sxm = 1.0 if mao_mov == "L" else -1.0   # lado (x) da mão que se move
    if sentido > 0:
        zm0, zm1 = z0 + alto_mao - 0.30, z0 + alto_mao + 0.30
        zmf = z0 + alto_mao
        zp0, zp1 = z0 - 0.90, z0 - 0.30
        zpf = z0 - 0.60
        jm, jp = (0.12, 0.80), (0.02, 0.60)
    else:
        zm0, zm1 = z0 + alto_mao, z0 + alto_mao - 0.60
        zmf = z0 + alto_mao - 0.30
        zp0, zp1 = z0 - 0.60, z0 - 1.20
        zpf = z0 - 0.90
        jm, jp = (0.18, 0.80), (0.0, 0.72)   # descendo: o pé busca o apoio primeiro
    # quadril: sobe/desce contínuo, balança para o lado do pé de apoio
    g = _g_ritmo(u, c["k_ritmo"]) if sentido > 0 else G_DESCE(u)
    sn = math.sin(math.pi * u)
    base = params_hang(0.0)
    dq = Vector((sxm * c["amp_x"] * sn, (0.0 if sentido > 0 else 0.015) * sn * sn,
                 z0 + sobe * 0.30 * g - HANG["quadril"][2]))
    sn_at = math.sin(math.pi * min(1.0, max(0.0, u - 0.10)) / 0.90) if u > 0.10 else 0.0
    p = {"dq": dq, "incl": 1.0 * sn * sn, "rola": sobe * sxm * 3.0 * sn, "gira": 0.0,
         "coluna": somar_coluna([(1.36, 0, 0), (1.44, 0, 0), (1.2, 0, 0)],
                                (-2.0 * sn * sn, -sobe * sxm * 8.0 * sn_at, -sxm * 3.0 * sn_at)),
         "ombros": {mao_mov: 4.0 * sn_at * sobe, mao_fix: 0.0}}
    if sentido > 0:
        p["olhar"] = (HANG["olhar"][0] - 10.0 * sn_at, sxm * 9.0 * sn_at, 0.0)
    else:
        # olha o pé por cima do ombro (vira a cabeça) em vez de baixar o queixo na parede
        p["olhar"] = (HANG["olhar"][0] + 14.0 * sn_at, -sxm * 30.0 * sn_at, -sxm * 6.0 * sn_at)
    # membros
    mx = {"L": c["mao_x"], "R": -c["mao_x"]}
    px = {"L": c["pe_x"], "R": -c["pe_x"]}
    t_u = u  # trajetos na escala da meia-fase
    pm, um, no_ar_m = viagem(t_u, jm[0], jm[1], (mx[mao_mov], HANG["mao_y"], zm0),
                             (mx[mao_mov], HANG["mao_y"], zm1), afasta=0.09)
    pp, up, no_ar_p = viagem(t_u, jp[0], jp[1], (px[pe_mov], HANG["pe_y"], zp0),
                             (px[pe_mov], HANG["pe_y"], zp1), afasta=0.11)
    smu = math.sin(math.pi * um)
    spu = math.sin(math.pi * up)
    maos = {
        mao_mov: {"pos": pm, "rot": rot_corpo(-20.0 * smu) @ rot_mao_pega(mao_mov),
                  "pega": 1.0 - 0.75 * smu ** 0.6},
        mao_fix: {"pos": Vector((mx[mao_fix], HANG["mao_y"], zmf)), "rot": rot_mao_pega(mao_fix),
                  "pega": 1.0},
    }
    pes = {
        pe_mov: {"pos": pp, "rot": rot_corpo(HANG["pe_inclina"] - (28.0 if sentido > 0 else -22.0) * spu),
                 "artelho": HANG["artelho"] * (1 - 0.6 * spu)},
        pe_fix: {"pos": Vector((px[pe_fix], HANG["pe_y"], zpf)), "rot": rot_corpo(HANG["pe_inclina"]),
                 "artelho": HANG["artelho"]},
    }
    apoio = {"mao_" + mao_mov: not no_ar_m, "pe_" + pe_mov: not no_ar_p,
             "mao_" + mao_fix: True, "pe_" + pe_fix: True}
    return pose_hang_base(rig, p, maos, pes, apoio)


def pose_climb_up(rig, t):
    return pose_escalada(rig, t, +1)


def pose_climb_down(rig, t):
    return pose_escalada(rig, t, -1)


# ----------------------------------------------------------------------------
# registro dos clipes e main
# ----------------------------------------------------------------------------
def todos_os_clipes():
    return [
        Clipe("hang_idle", 2.0, pose_hang_idle, ciclo=True),
        Clipe("climb_up_loop", SUBIDA["T"], pose_climb_up, ciclo=True, passo=(0, 0, 0.60)),
        Clipe("climb_down_loop", SUBIDA["T"], pose_climb_down, ciclo=True, passo=(0, 0, -0.60)),
    ]


LEIA_ME = """escalada.blend — fonte dos clipes de escalada por keyframe (X Bot / mixamorig).

Gerado por tools/blender/keyframe_parkour_escalada.py (rode de novo para refazer tudo;
o script é a fonte de verdade, este arquivo é para inspecionar e retocar).

- Rig de controle VIVO: CTRL_quadril (Copy Location/Rotation no Hips), CTRL_mao_L/R e
  CTRL_pe_L/R (alvos de IK no ponto de pega / ponta do pé; filhos OSSO_* carregam a
  orientação do osso), POLO_cotovelo_*/POLO_joelho_* (polos), damped track nas clavículas.
- Ações <clipe>_controle: curvas dos controles (slots por objeto). Para ver um clipe vivo,
  atribua a ação <clipe>_controle à armature E a todos os CTRL_/POLO_ (slot de mesmo nome).
- Ações <clipe>: o resultado ASSADO em FK (é o que vai para o GLB, sem restrições).
- Coleções Cenario_<clipe>: parede (sólido em y < -0,30), agarras usadas e chão.
"""


def main():
    op = args()
    rig = Rig()
    limpar_e_importar(rig)
    montar_rig(rig)
    ajustar_polos(rig)
    clipes = [c for c in todos_os_clipes() if op["clipes"] is None or c.nome in op["clipes"]]
    ctrl_acoes, acoes = {}, {}
    for c in clipes:
        ctrl_acoes[c.nome] = gravar_controles(rig, c)
        acoes[c.nome] = assar(rig, c)
        print(f"[assado] {c.nome}: {c.n + 1} quadros")
    cams = preparar_render(rig)
    colecoes = {}
    for c in clipes:
        maos, pes = c.agarras()
        colecoes[c.nome] = montar_cenario(c.nome, maos, pes, c.com_borda)
    if op["blend"]:
        DIR_FONTE.mkdir(parents=True, exist_ok=True)
        txt = bpy.data.texts.get("LEIA-ME") or bpy.data.texts.new("LEIA-ME")
        txt.from_string(LEIA_ME)
        primeira = ctrl_acoes[clipes[0].nome]
        for o in [rig.arm] + [rig.ctrl[k] for k in CONTROLES]:
            o.animation_data.action = primeira
            o.animation_data.action_slot = next(sl for sl in primeira.slots if sl.name_display == o.name)
        for nome, col in colecoes.items():
            col.hide_viewport = nome != clipes[0].nome
            col.hide_render = nome != clipes[0].nome
        bpy.ops.wm.save_as_mainfile(filepath=str(ARQ_BLEND), copy=True)
        print("[blend]", ARQ_BLEND)
    # exportação: só FK, sem restrições
    remover_restricoes(rig)
    partes = classificar_vertices(rig)
    medidas, poses, refs = {}, {}, {}
    tmp = tempfile.mkdtemp(prefix="folhas_")
    for c in clipes:
        res, ps, quad, ref_rt = medir_clipe(rig, c, acoes[c.nome], partes)
        medidas[c.nome], poses[c.nome], refs[c.nome] = res, ps, ref_rt
        res["quadril_pos"] = quad
        if op["export"]:
            exportar_glb(rig, c, acoes[c.nome])
        if op["render"]:
            res["folha"] = str(renderizar_clipe(rig, c, acoes[c.nome], cams, colecoes, tmp).relative_to(REPO))
    # continuidade com o hang_idle quadro 0
    if "hang_idle" in poses:
        h0 = poses["hang_idle"][0]
        hq0 = medidas["hang_idle"]["quadril_pos"][0]
        for c in clipes:
            for qual in c.continuidade:
                f = c.n if qual == "fim" else 0
                medidas[c.nome].setdefault("continuidade_hang_idle_q0", {})[qual] = {
                    "dif_max_osso_graus": round(comparar_poses(h0, poses[c.nome][f]), 4),
                    "dif_quadril_cm": round((medidas[c.nome]["quadril_pos"][f] - hq0).length * 100, 4)}
    for c in clipes:
        medidas[c.nome].pop("quadril_pos", None)
    if op["render"] and "climb_up_loop" in acoes:
        comparar_com_referencia(rig, next(c for c in clipes if c.nome == "climb_up_loop"),
                                acoes["climb_up_loop"], cams, colecoes, tmp)
    if op["export"]:
        rt = ida_e_volta_glb(refs)
        for nome, r in rt.items():
            medidas[nome]["glb"] = r
    DIR_VAL.mkdir(parents=True, exist_ok=True)
    arq = DIR_VAL / "medidas.json"
    antigo = json.loads(arq.read_text()) if arq.exists() and op["clipes"] else {}
    antigo.update(medidas)
    arq.write_text(json.dumps(antigo, indent=2, ensure_ascii=False))
    print("[medidas]", arq)
    for nome, m in medidas.items():
        print(f"== {nome}: " + json.dumps({k: v for k, v in m.items() if k not in ("folha",)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
