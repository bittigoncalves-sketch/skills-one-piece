"""Arrancada (`run_start`) e virada correndo 180° (`run_turn_180`) por keyframe.

Fatia 1 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (itens 4 e 6). Esqueleto `mixamorig`
do X Bot do "Action Adventure Pack" (Mixamo) — o MESMO dos clipes `idle`, `running`
e `run to stop` do pacote, de onde saem as poses de partida e de chegada.

Uso (Blender 5.2, headless):
  blender -b --python tools/blender/keyframe_parkour_chao.py -- [--sem-folhas] [--sem-glb]

Saídas:
  art_src/animacoes_parkour/chao.blend                fonte (Armature + as 2 ações + boneco)
  art_src/animacoes_parkour/glb/run_start.glb         só armature + ação, 30 qps
  art_src/animacoes_parkour/glb/run_turn_180.glb
  art_src/validation/parkour_keyframe/*.png           folhas de quadros
  art_src/validation/parkour_keyframe/medidas_chao.json

Como é feito (o script É a fonte; os números de autoria estão nas funções `plano_*`):
  * Corpo de cima, quadril (rotação) e dedos: misturas das poses REAIS do pacote
    (idle quadro 1 → running com fase e amplitude crescentes; run to stop nos braços da
    frenagem) + camadas aditivas (inclinação do tronco, cabeça que estabiliza o olhar,
    peito e cabeça liderando o giro).
  * Raiz: a velocidade do quadril é a do JOGO, simulada quadro a quadro com as
    constantes de src/player/locomocao_chao.gd (arrancada 17→8 m/s²; giro: freia a
    28 m/s² até 0,9 m/s, vira em 0,14 s, arranca) — o root motion casa com a física.
  * Pernas: IK do Blender (alvo no tornozelo, polo do joelho para a frente) + Copy
    Rotation no pé; pé plantado = ponto de contato FIXO (calcanhar no toque, bola do pé
    no apoio e no pivô). Depois ASSA para FK (bpy.ops.nla.bake, visual keying), tira as
    restrições e funde as pontas com a pose-fonte exata (correção que some em 3 quadros).
"""
import bpy
import json
import math
import os
import struct
import sys
import tempfile
import time
import zipfile

import numpy as np
from mathutils import Matrix, Quaternion, Vector

# ----------------------------------------------------------------------------- caminhos
try:
    _AQUI = os.path.abspath(__file__)
except NameError:  # pragma: no cover
    _AQUI = os.path.abspath(sys.argv[sys.argv.index("--python") + 1])
REPO = os.path.dirname(os.path.dirname(os.path.dirname(_AQUI)))
ZIP = os.path.expanduser(
    "~/Downloads/Assets/animações importadas do mixamo/Action Adventure Pack.zip")
DIR_ART = os.path.join(REPO, "art_src", "animacoes_parkour")
BLEND = os.path.join(DIR_ART, "chao.blend")
DIR_GLB = os.path.join(DIR_ART, "glb")
DIR_VAL = os.path.join(REPO, "art_src", "validation", "parkour_keyframe")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

FPS = 30
P_RUN = 21           # período do `running` em quadros (o quadro 22 repete o 1)
SC = None            # bpy.context.scene
ARM = None           # armature alvo ("Armature", rest idêntico aos clipes do pacote)
XB = None            # boneco X Bot (malha) que copia o ARM — só para render/medida
MALHAS = []
ESC = 0.01           # escala do objeto armature (cm → m)


def B(n):
    return "mixamorig:" + n


HIPS = B("Hips")
LADOS = ("Left", "Right")
SPINE3 = [B("Spine"), B("Spine1"), B("Spine2")]


# ============================================================================ utilidades
def clamp01(u):
    return 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)


def smooth(u):
    u = clamp01(u)
    return u * u * (3 - 2 * u)


def smoother(u):
    u = clamp01(u)
    return u * u * u * (u * (6 * u - 15) + 10)


def rampa(t, a, b, f=smooth):
    return f((t - a) / (b - a)) if b != a else (1.0 if t >= b else 0.0)


def q_rot(M):
    return M.to_3x3().normalized().to_quaternion()


def compat(q, ref):
    q = q.copy()
    if q.dot(ref) < 0:
        q.negate()
    return q


def slerp(a, b, t):
    return a.slerp(compat(b, a), t)


def rz(ang):
    return Quaternion((0.0, 0.0, 1.0), ang)


def q_eixo(eixo, ang):
    return Quaternion(eixo.normalized(), ang)


def yaw_vec(v):
    """0 = olhando −Y (frente do pacote); + = para a esquerda (+X), sentido do jogo."""
    return math.atan2(v.x, -v.y)


def wrap(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def frente_de(q):
    """Frente do quadril/peito/cabeça: eixo Z local do osso no mundo."""
    return q @ Vector((0, 0, 1))


def frente_pe(q):
    """Frente do pé: eixo Y local (tornozelo → bola)."""
    return q @ Vector((0, 1, 0))


def horiz(v):
    w = Vector((v.x, v.y, 0.0))
    return w.normalized() if w.length > 1e-9 else Vector((0, -1, 0))


def esquerda_de(f):
    """Eixo lateral horizontal à esquerda de uma frente f. Girar +ang nele = cabeça
    da frente desce (tronco para a frente / calcanhar sobe)."""
    return Vector((0, 0, 1)).cross(horiz(f)).normalized()


def log_q(q):
    q = compat(q, Quaternion())
    eixo, ang = q.to_axis_angle()
    return Vector(eixo) * ang


def exp_v(v):
    ang = v.length
    return Quaternion(v / ang, ang) if ang > 1e-9 else Quaternion()


class Curva:
    """Hermite cúbica por chaves (t, valor[, inclinação por quadro]). Sem inclinação
    dada, PCHIP (Fritsch–Carlson): não passa do ponto entre chaves (sem barriga)."""

    def __init__(self, chaves):
        ks = sorted(chaves, key=lambda k: k[0])
        self.t = [float(k[0]) for k in ks]
        self.y = [float(k[1]) for k in ks]
        n = len(ks)
        t, y = self.t, self.y
        d = [(y[i + 1] - y[i]) / (t[i + 1] - t[i]) for i in range(n - 1)]
        m = [0.0] * n
        for i in range(n):
            if len(ks[i]) > 2 and ks[i][2] is not None:
                m[i] = float(ks[i][2])
            elif n == 1:
                m[i] = 0.0
            elif i == 0:
                m[i] = d[0]
            elif i == n - 1:
                m[i] = d[-1]
            elif d[i - 1] * d[i] <= 0:
                m[i] = 0.0
            else:
                h0, h1 = t[i] - t[i - 1], t[i + 1] - t[i]
                w1, w2 = 2 * h1 + h0, h1 + 2 * h0
                m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
        self.m = m

    def __call__(self, x):
        t, y, m = self.t, self.y, self.m
        if x <= t[0]:
            return y[0] + m[0] * (x - t[0])
        if x >= t[-1]:
            return y[-1] + m[-1] * (x - t[-1])
        i = max(j for j in range(len(t) - 1) if t[j] <= x)
        h = t[i + 1] - t[i]
        u = (x - t[i]) / h
        h00 = 2 * u ** 3 - 3 * u ** 2 + 1
        h10 = u ** 3 - 2 * u ** 2 + u
        h01 = -2 * u ** 3 + 3 * u ** 2
        h11 = u ** 3 - u ** 2
        return h00 * y[i] + h10 * h * m[i] + h01 * y[i + 1] + h11 * h * m[i + 1]


class CurvaVec:
    def __init__(self, chaves):  # (t, Vector[, Vector inclinação])
        self.c = [Curva([(k[0], k[1][i]) + ((k[2][i],) if len(k) > 2 and k[2] is not None else ())
                         for k in chaves]) for i in range(3)]

    def __call__(self, x):
        return Vector([c(x) for c in self.c])


class CurvaRot:
    """Rotações por chaves (t, Quaternion): interpola o vetor-rotação relativo à chave
    do meio com Hermite PCHIP por componente (suave, sem estalo de slerp por trecho)."""

    def __init__(self, chaves):
        self.ref = chaves[len(chaves) // 2][1].copy()
        vs = [(t, log_q(self.ref.inverted() @ compat(q, self.ref))) for t, q in chaves]
        self.c = CurvaVec(vs)

    def __call__(self, x):
        return self.ref @ exp_v(self.c(x))


# ============================================================================ fontes
def importar_fbx(path):
    antes = set(bpy.data.objects)
    if hasattr(bpy.ops.wm, "fbx_import"):
        bpy.ops.wm.fbx_import(filepath=path)
    else:  # pragma: no cover
        bpy.ops.import_scene.fbx(filepath=path)
    novos = [o for o in bpy.data.objects if o not in antes]
    return next(o for o in novos if o.type == "ARMATURE"), novos


class Clipe:
    """Poses amostradas de um clipe do pacote: base local (loc, quat) e mundo."""

    def __init__(self, arm, nome):
        self.nome = nome
        act = arm.animation_data.action
        f0, f1 = (int(round(x)) for x in act.frame_range)
        self.f0, self.n = f0, f1 - f0 + 1
        self.base, self.mundo = [], []
        for f in range(f0, f1 + 1):
            SC.frame_set(f)
            self.base.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy())
                              for pb in arm.pose.bones})
            self.mundo.append({pb.name: (arm.matrix_world @ pb.matrix).copy()
                               for pb in arm.pose.bones})

    def q(self, bn, i):
        return self.base[i][bn][1]

    def loc(self, bn, i):
        return self.base[i][bn][0]

    def R(self, bn, i):
        return q_rot(self.mundo[i][bn])

    def p(self, bn, i):
        return self.mundo[i][bn].to_translation()


IDLE = RUN = STOP = None
F = {}   # fatos derivados das fontes (médias, geometria do pé, ...)


def run_k(phi):
    k = math.floor(phi)
    return int(k) % P_RUN, phi - k, int(k) // P_RUN


def run_q(bn, phi):
    k, f, _ = run_k(phi)
    return slerp(RUN.q(bn, k), RUN.q(bn, k + 1), f)


def run_loc(bn, phi):
    k, f, _ = run_k(phi)
    return RUN.loc(bn, k).lerp(RUN.loc(bn, k + 1), f)


def run_R(bn, phi):
    k, f, _ = run_k(phi)
    return slerp(RUN.R(bn, k), RUN.R(bn, k + 1), f)


def run_p(bn, phi):
    """Posição de mundo no `running` desenrolado (cada ciclo avança F['ciclo'])."""
    k, f, c = run_k(phi)
    return RUN.p(bn, k).lerp(RUN.p(bn, k + 1), f) + F["ciclo"] * c


def run_v(bn, phi, h=0.5):
    """Velocidade de mundo (m/quadro) no `running`."""
    return (run_p(bn, phi + h) - run_p(bn, phi - h)) / (2 * h)


def stop_q(bn, psi):
    k = int(math.floor(psi))
    k = max(0, min(STOP.n - 2, k))
    return slerp(STOP.q(bn, k), STOP.q(bn, k + 1), clamp01(psi - k))


def media_q(lista):
    ref = lista[0]
    acc = Vector((0, 0, 0, 0))
    for q in lista:
        q = compat(q, ref)
        acc += Vector((q.w, q.x, q.y, q.z))
    acc.normalize()
    return Quaternion(acc)


def carregar_fontes(tmp):
    """Extrai do zip, importa, amostra as poses e monta o ARM e o boneco."""
    global IDLE, RUN, STOP, ARM, XB, MALHAS, ESC
    with zipfile.ZipFile(ZIP) as z:
        for nome in ("X Bot.fbx", "idle.fbx", "running.fbx", "run to stop.fbx"):
            z.extract(nome, tmp)
    xb, novos = importar_fbx(os.path.join(tmp, "X Bot.fbx"))
    xb.name = "XBot_boneco"
    MALHAS = [o for o in novos if o.type == "MESH"]
    if xb.animation_data:
        xb.animation_data.action = None
    for pb in xb.pose.bones:
        pb.matrix_basis = Matrix()

    clipes = {}
    for nome, arq in (("idle", "idle.fbx"), ("run_to_stop", "run to stop.fbx"),
                      ("running", "running.fbx")):
        arm, novos = importar_fbx(os.path.join(tmp, arq))
        clipes[nome] = Clipe(arm, nome)
        act = arm.animation_data.action
        act.name = "ref_" + nome
        act.use_fake_user = True
        if nome != "running":
            for o in novos:
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            ARM = arm
    IDLE, STOP, RUN = clipes["idle"], clipes["run_to_stop"], clipes["running"]
    ARM.name = "Armature"
    ARM.data.name = "Armature"
    ARM.animation_data.action = None
    ESC = ARM.matrix_world.to_scale()[0]

    # Boneco: cada osso copia o osso de mesmo nome do ARM (espaço de mundo). O rest do
    # X Bot está 1,55 cm deslocado do rest dos clipes; copiar o MUNDO anula isso.
    for pb in xb.pose.bones:
        c = pb.constraints.new("COPY_TRANSFORMS")
        c.target = ARM
        c.subtarget = pb.name
    XB = xb

    # ---- fatos derivados
    F["ciclo"] = RUN.p(HIPS, P_RUN) - RUN.p(HIPS, 0)
    F["q_media"] = {bn: media_q([RUN.q(bn, k) for k in range(P_RUN)]) for bn in RUN.base[0]}
    F["R_quadril_media"] = media_q([RUN.R(HIPS, k) for k in range(P_RUN)])
    ossos = ARM.data.bones
    F["L_coxa"] = ossos[B("LeftLeg")].head_local.copy()  # só para existir; abaixo o real
    F["coxa"] = (ossos[B("LeftLeg")].head_local - ossos[B("LeftUpLeg")].head_local).length * ESC
    F["canela"] = ossos[B("LeftLeg")].length * ESC
    F["pe"] = ossos[B("LeftFoot")].length * ESC
    F["alcance"] = 0.985 * (F["coxa"] + F["canela"])
    # rotação de repouso do dedo relativa ao pé (constante de rig)
    for lado in LADOS:
        bf, bt = ossos[B(lado + "Foot")], ossos[B(lado + "ToeBase")]
        F["rest_dedo_" + lado] = (bf.matrix_local.inverted() @ bt.matrix_local).to_quaternion()
    # calcanhar: vértice mais baixo e mais atrás do pé na malha do X Bot (pose de bind),
    # no espaço local do osso do pé (só rotação, metros)
    for lado in LADOS:
        F["calc_" + lado] = _calcanhar_da_malha(lado)
    # referências de pé chato (idle quadro 1: tornozelo a 8,8 cm, bola no chão)
    for lado in LADOS:
        F["pe_chato_" + lado] = IDLE.R(B(lado + "Foot"), 0)
        F["dedo_chato_" + lado] = IDLE.R(B(lado + "ToeBase"), 0)
    F["v_run_fim"] = None


def _calcanhar_da_malha(lado):
    surf = next(o for o in MALHAS if "Surface" in o.name)
    vg = surf.vertex_groups.get(B(lado + "Foot"))
    pts = []
    Mw = surf.matrix_world
    for v in surf.data.vertices:
        for g in v.groups:
            if g.group == vg.index and g.weight > 0.5:
                pts.append(Mw @ v.co)
    zmin = min(p.z for p in pts)
    baixo = [p for p in pts if p.z < zmin + 0.012]
    calc = max(baixo, key=lambda p: p.y)  # +Y = para trás
    bone = XB.data.bones[B(lado + "Foot")]
    Mb = XB.matrix_world @ bone.matrix_local
    A = Mb.to_translation()
    return q_rot(Mb).inverted() @ (Vector((calc.x, calc.y, zmin)) - A)


# ============================================================================ física do jogo
# Cópia fiel do laço de src/player/locomocao_chao.gd a 60 Hz (velocidade nova por tique,
# move_and_slide anda v·dt). Só leitura: as constantes estão aqui para o root motion
# do clipe casar com a física.
ACEL_ARRANQUE, ACEL_FINAL = 17.0, 8.0
FRENAGEM_GIRO, VEL_FIM_FRENAGEM, TEMPO_GIRO = 28.0, 0.9, 0.14
HZ = 60


def sim_arrancada(alvo):
    dt = 1.0 / HZ
    v, t, s, pts = 0.0, 0.0, 0.0, [(0.0, 0.0, 0.0)]
    while v < alvo - 1e-9:
        acel = ACEL_ARRANQUE + (ACEL_FINAL - ACEL_ARRANQUE) * min(v / alvo, 1.0)
        v = min(v + acel * dt, alvo)
        t += dt
        s += v * dt
        pts.append((t, s, v))
    return pts


def sim_giro(v0, alvo):
    """s = deslocamento na frente ANTIGA (+). Devolve tiques e marcos."""
    dt = 1.0 / HZ
    v, est, tg, t, s = v0, "freando_giro", 0.0, 0.0, 0.0
    pts, marcos = [(0.0, 0.0, v0)], {}
    while True:
        if est == "freando_giro":
            v = max(v - FRENAGEM_GIRO * dt, 0.0)
            prox = "girando" if v <= VEL_FIM_FRENAGEM else est
        elif est == "girando":
            tg += dt
            r = FRENAGEM_GIRO * dt
            resto = v - r if v > r else (v + r if v < -r else 0.0)
            v = resto - min(ACEL_ARRANQUE * tg * 0.5, alvo)
            prox = "arrancando" if tg / TEMPO_GIRO >= 1.0 else est
        else:
            m = -v
            acel = ACEL_ARRANQUE + (ACEL_FINAL - ACEL_ARRANQUE) * min(m / alvo, 1.0)
            v = -min(m + acel * dt, alvo)
            prox = est
        t += dt
        s += v * dt
        pts.append((t, s, v))
        if prox != est:
            marcos["fim_" + est] = t
        est = prox
        if est == "arrancando" and -v >= alvo - 1e-9:
            marcos["velocidade_cheia"] = t
            return pts, marcos


def s_de_pts(pts, t_seg):
    """Deslocamento no instante t (s) a partir dos tiques (velocidade constante no tique)."""
    if t_seg <= 0:
        return 0.0
    for i in range(1, len(pts)):
        if pts[i][0] >= t_seg:
            t0, s0, _ = pts[i - 1]
            t1, s1, _ = pts[i]
            return s0 + (s1 - s0) * (t_seg - t0) / (t1 - t0)
    t1, s1, v1 = pts[-1]
    return s1 + v1 * (t_seg - t1)


def suavizar(vals, sigma):
    """Suaviza uma série por quadro (gaussiana), mantendo as pontas."""
    n = len(vals)
    out = []
    for i in range(n):
        acc = w = 0.0
        for j in range(n):
            k = math.exp(-0.5 * ((i - j) / sigma) ** 2)
            acc += k * vals[j]
            w += k
        out.append(acc / w)
    out[0], out[-1] = vals[0], vals[-1]
    return out


# ============================================================================ pose por quadro
def atualizar():
    bpy.context.view_layer.update()


def R_mundo(bn):
    return q_rot(ARM.matrix_world @ ARM.pose.bones[bn].matrix)


def p_mundo(bn):
    return ARM.matrix_world @ ARM.pose.bones[bn].head


def quadril_de_mundo(pos, rot):
    pb = ARM.pose.bones[HIPS]
    Mw = Matrix.Translation(pos) @ rot.to_matrix().to_4x4() @ Matrix.Scale(ESC, 4)
    pb.matrix = ARM.matrix_world.inverted() @ Mw


def girar_mundo(bn, eixo, ang, cache):
    """Pós-multiplica a base local para girar o osso `ang` em volta de um eixo de MUNDO
    (válido para vários ossos da mesma cadeia se o eixo é o mesmo — ele não muda)."""
    pb = ARM.pose.bones[bn]
    loc = cache[bn].inverted() @ eixo
    pb.rotation_quaternion = pb.rotation_quaternion @ Quaternion(loc.normalized(), ang)


PERNA = {lado: [B(lado + n) for n in ("UpLeg", "Leg", "Foot", "ToeBase", "Toe_End")]
         for lado in LADOS}
OSSOS_PERNA = set(PERNA["Left"] + PERNA["Right"])


def ossos_cima():
    return [pb.name for pb in ARM.pose.bones if pb.name != HIPS and pb.name not in OSSOS_PERNA]


def montar_tronco(spec):
    """Aplica quadril + corpo de cima com as camadas aditivas; deixa a pose no ARM."""
    for bn, (loc, q) in spec["base"].items():
        pb = ARM.pose.bones[bn]
        pb.location = loc
        pb.rotation_quaternion = q
    quadril_de_mundo(*spec["quadril"])
    atualizar()
    Rq = R_mundo(HIPS)
    # peito liderando o giro (torção em Z distribuída na coluna)
    lead = spec.get("lead_peito", 0.0)
    if abs(lead) > 1e-6:
        cache = {bn: R_mundo(bn) for bn in SPINE3}
        for bn, fr in zip(SPINE3, (0.3, 0.35, 0.35)):
            girar_mundo(bn, Vector((0, 0, 1)), lead * fr, cache)
        atualizar()
    # inclinação do tronco (graus extra, em volta do eixo lateral do quadril)
    inc = math.radians(spec.get("inclinacao", 0.0))
    if abs(inc) > 1e-6:
        eixo = esquerda_de(frente_de(Rq))
        cache = {bn: R_mundo(bn) for bn in SPINE3}
        for bn, fr in zip(SPINE3, (0.4, 0.3, 0.3)):
            girar_mundo(bn, eixo, inc * fr, cache)
        atualizar()
    # cabeça: guinada extra (liderança) e/ou alvo absoluto; arfagem estabilizada
    for _ in range(2):
        f = frente_de(R_mundo(B("Head")))
        dyaw = 0.0
        if spec.get("cabeca_yaw") is not None:
            dyaw = wrap(spec["cabeca_yaw"] - yaw_vec(f))
        if abs(dyaw) > 1e-5:
            cache = {bn: R_mundo(bn) for bn in (B("Neck"), B("Head"))}
            girar_mundo(B("Neck"), Vector((0, 0, 1)), 0.4 * dyaw, cache)
            girar_mundo(B("Head"), Vector((0, 0, 1)), 0.6 * dyaw, cache)
            atualizar()
        if spec.get("cabeca_pitch") is not None:
            f = frente_de(R_mundo(B("Head")))
            dp = spec["cabeca_pitch"] - math.asin(max(-1, min(1, f.z)))
            if abs(dp) > 1e-5:
                eixo = horiz(f).cross(Vector((0, 0, 1))).normalized()
                cache = {bn: R_mundo(bn) for bn in (B("Neck"), B("Head"))}
                girar_mundo(B("Neck"), eixo, 0.4 * dp, cache)
                girar_mundo(B("Head"), eixo, 0.6 * dp, cache)
                atualizar()


def dedo_local(lado, Q_pe, Q_dedo_mundo):
    return F["rest_dedo_" + lado].inverted() @ Q_pe.inverted() @ Q_dedo_mundo


def dedo_chato(lado, Q_pe):
    """Dedo apoiado no chão com a guinada do pé (mundo)."""
    dpsi = yaw_vec(frente_pe(Q_pe)) - yaw_vec(frente_pe(F["pe_chato_" + lado]))
    return rz(dpsi) @ F["dedo_chato_" + lado]


def tornozelo_pela_bola(bola, Q):
    return bola - Q @ Vector((0, F["pe"], 0))


def tornozelo_pelo_calc(calc, Q, lado):
    return calc - Q @ F["calc_" + lado]


def bola_pelo_tornozelo(A, Q):
    return A + Q @ Vector((0, F["pe"], 0))


def calc_pelo_tornozelo(A, Q, lado):
    return A + Q @ F["calc_" + lado]


# ============================================================================ plano: arrancada
def plano_run_start():
    """`run_start`: idle quadro 1 → running quadro 21 (índice 20). 15 quadros (0,50 s)."""
    N = 15
    FIM = 20                      # índice do running na chegada (quadro 21)
    a0 = 1.5                      # fim da antecipação (peso desce/recua 1,5 quadro)
    v_fim = -run_v(HIPS, FIM).y * FPS
    pts = sim_arrancada(v_fim)
    t_cheia = pts[-1][0] * FPS + a0
    # deslocamento à frente (s, m) por quadro: recuo na antecipação + física do jogo
    s = []
    for f in range(N + 1):
        if f <= a0:
            s.append(-0.016 * smooth(f / a0) + 0.0)
        else:
            s.append(-0.016 + s_de_pts(pts, (f - a0) / FPS))
    s_raw = s[:]
    H0 = IDLE.p(HIPS, 0)
    # o running é colocado de modo que o quadro 21 caia na chegada
    off = Vector((0, (H0.y - s[N]) - RUN.p(HIPS, FIM).y, 0))
    HF = RUN.p(HIPS, FIM) + off

    def s_t(t):
        if t <= 0:
            return 0.0
        if t >= N:
            return s[N] + v_fim / FPS * (t - N)
        i = int(math.floor(t))
        return s[i] + (s[i + 1] - s[i]) * (t - i)

    vz_fim = run_v(HIPS, FIM).z
    vx_fim = run_v(HIPS, FIM).x
    cz = Curva([(0, H0.z, 0.0), (1.5, H0.z - 0.020), (3.5, H0.z - 0.032), (6.5, 0.950),
                (9.0, 0.968), (10.5, 0.982), (11.8, 0.972), (13.3, 0.945), (N, HF.z, vz_fim)])
    cx = Curva([(0, H0.x, 0.0), (3, H0.x + 0.004), (7, 0.010), (10.5, 0.010), (13, 0.002),
                (N, HF.x, vx_fim)])
    phi = lambda t: FIM - 0.95 * (N - t)                      # fase do running (braços)
    amp = lambda t: 0.3 + 0.7 * rampa(t, 1.5, N)              # 30 % → 100 %
    w_cima = lambda t: rampa(t, 0.5, 7.0, smoother)           # idle → corrida no tronco
    w_quad = lambda t: rampa(t, 1.0, 11.0, smoother)          # quadril gira com o 1º passo
    inc = lambda t: 9.0 * math.sin(math.pi * clamp01((t - 1.0) / (N - 1.0))) ** 2 \
        if t < 7.5 else 9.0 * (1 - rampa(t, 7.5, N, smooth))  # +9° extra, pico no 1º passo
    tilt = lambda t: math.radians(4.0) * math.sin(math.pi * clamp01((t - 1.5) / (N - 2.5)))

    # ---------------- pés
    # ESQUERDO: pé da frente, empurra. Bola fixa; pivota sobre ela (guinada do idle →
    # guinada do running no desprendimento) e o calcanhar sobe até o desprendimento.
    t_toL = 10.0
    QL0 = IDLE.R(B("LeftFoot"), 0)
    bolaL = IDLE.p(B("LeftToeBase"), 0)
    QL_to = run_R(B("LeftFoot"), 12.0)
    dpsiL = wrap(yaw_vec(frente_pe(QL_to)) - yaw_vec(frente_pe(QL0)))
    # depois do desprendimento: caminho relativo ao quadril tirado do running (12 → 20),
    # com a fase acelerada no começo e inclinação 1 na chegada
    gL = Curva([(t_toL, 12.0, 2.6), (N, float(FIM), 1.0)])
    # DIREITO: pé de trás, 1º passo longo. Calcanhar sobe (bola fixa), sai, voa baixo e
    # pousa onde o running o tem no quadro 20 (bola), girado para a frente.
    t_toR, t_landR = 3.5, 12.6
    QR0 = IDLE.R(B("RightFoot"), 0)
    bolaR0 = IDLE.p(B("RightToeBase"), 0)
    psiR0 = yaw_vec(frente_pe(QR0))
    bolaR1 = RUN.p(B("RightToeBase"), 19) + off
    bolaR1.z = RUN.p(B("RightToeBase"), 19).z

    def QR_planta(t):  # 0 → t_toR: calcanhar sobe, pé pivota um pouco para a frente
        u = rampa(t, 1.2, t_toR, smooth)
        Q = rz(math.radians(35.0) * u) @ QR0
        return q_eixo(esquerda_de(frente_pe(Q)), math.radians(38.0) * u ** 1.3) @ Q

    QR_to = QR_planta(t_toR)
    AR_to = tornozelo_pela_bola(bolaR0, QR_to)
    QR_land = run_R(B("RightFoot"), 19.0)
    AR_land = tornozelo_pela_bola(bolaR1, QR_land)
    vR_land = run_v(B("RightFoot"), 18.6)
    Hy = lambda t: H0.y - s_t(t)
    swR = CurvaVec([
        (t_toR, AR_to, Vector((0.0, -0.010, 0.022))),
        (6.6, Vector((cx(6.6) - 0.105, Hy(6.6) + 0.10, 0.245))),
        (9.6, Vector((-0.085, Hy(9.6) - 0.23, 0.215))),
        (t_landR, AR_land, vR_land),
    ])
    rotR = CurvaRot([(t_toR, QR_to), (8.0, run_R(B("RightFoot"), 14.5)),
                     (t_landR, QR_land)])
    gR = Curva([(t_landR, 19.0, None), (N, float(FIM), None)])

    def pes(t):
        out = {}
        # ---- esquerdo
        if t <= t_toL:
            yaw_u = rampa(t, 2.0, 8.5, smoother)
            Qy = rz(dpsiL * yaw_u) @ QL0
            alfa = math.radians(8.0) * rampa(t, 2.0, 4.5)
            Qp = q_eixo(esquerda_de(frente_pe(Qy)), alfa) @ Qy
            Q = slerp(Qp, QL_to, rampa(t, 5.5, t_toL, lambda u: u ** 1.6))
            A = tornozelo_pela_bola(bolaL, Q)
            contato = 1.0
        else:
            ph = gL(t)
            Q = run_R(B("LeftFoot"), ph)
            rel = run_p(B("LeftFoot"), ph) - run_p(HIPS, ph)
            corr0 = tornozelo_pela_bola(bolaL, QL_to) - (Vector((cx(t_toL), Hy(t_toL), 0))
                                                        + rel_z0(run_p(B("LeftFoot"), 12.0) - run_p(HIPS, 12.0)))
            A = Vector((cx(t), Hy(t), 0)) + rel_z0(rel) + corr0 * (1 - rampa(t, t_toL, t_toL + 3.0))
            contato = 1 - rampa(t, t_toL, t_toL + 2.0)
        out["Left"] = (A, Q, contato, gL(t) if t > t_toL else 12.0)
        # ---- direito
        if t <= t_toR:
            Q = QR_planta(t)
            A = tornozelo_pela_bola(bolaR0, Q)
            contato = 1.0
            ph = 2.0
        elif t < t_landR:
            Q = rotR(t)
            A = swR(t)
            contato = rampa(t, t_landR - 1.5, t_landR) * 0 + (1 - rampa(t, t_toR, t_toR + 2.0))
            contato = max(contato, rampa(t, t_landR - 1.5, t_landR))
            ph = 2.0 + 17.0 * (t - t_toR) / (t_landR - t_toR)
        else:
            ph = gR(t)
            Q = run_R(B("RightFoot"), ph)
            A = tornozelo_pela_bola(bolaR1, Q)
            contato = 1.0
        out["Right"] = (A, Q, contato, ph)
        return out

    def rel_z0(rel):  # relativo ao quadril no plano, altura absoluta
        return Vector((rel.x, rel.y, 0))

    # altura absoluta do tornozelo no running (rel_z0 zera z; somo a altura da fonte)
    def pes_corrigido(t):
        out = pes(t)
        A, Q, c, ph = out["Left"]
        if t > t_toL:
            zfonte = run_p(B("LeftFoot"), gL(t)).z
            z0 = tornozelo_pela_bola(bolaL, QL_to).z
            A = Vector((A.x, A.y, zfonte + (z0 - run_p(B("LeftFoot"), 12.0).z)
                        * (1 - rampa(t, t_toL, t_toL + 3.0))))
            out["Left"] = (A, Q, c, ph)
        return out

    def spec(t):
        ph = phi(t)
        a = amp(t)
        Rrun = slerp(F["R_quadril_media"], run_R(HIPS, ph), a)
        Rq = slerp(IDLE.R(HIPS, 0), Rrun, w_quad(t))
        Rq = q_eixo(esquerda_de(frente_de(Rq)), tilt(t)) @ Rq
        pos = Vector((cx(t), Hy(t), cz(t)))
        base = {}
        for bn in ossos_cima():
            qr = slerp(F["q_media"][bn], run_q(bn, ph), a)
            w = w_cima(t)
            base[bn] = (IDLE.loc(bn, 0).lerp(run_loc(bn, ph), w), slerp(IDLE.q(bn, 0), qr, w))
        fH_i = frente_de(IDLE.R(B("Head"), 0))
        fH_r = frente_de(run_R(B("Head"), ph))
        w = w_cima(t)
        yaw_alvo = yaw_vec(fH_i) + wrap(yaw_vec(fH_r) - yaw_vec(fH_i)) * w
        pit_alvo = math.asin(fH_i.z) * (1 - w) + math.asin(fH_r.z) * w
        return {"quadril": (pos, Rq), "base": base, "inclinacao": inc(t),
                "cabeca_yaw": yaw_alvo, "cabeca_pitch": pit_alvo, "pes": pes_corrigido(t),
                "fase_toe": {"Left": None, "Right": None}}

    info = {
        "N": N, "fonte_inicio": ("idle", 0), "fonte_fim": ("running", FIM),
        "transf_fim": Matrix.Translation(off), "v_fim": v_fim,
        "fisica": {"alvo_m_s": round(v_fim, 3), "antecipacao_quadros": a0,
                   "velocidade_cheia_quadro": round(t_cheia, 2),
                   "s_m_por_quadro": [round(x, 4) for x in s_raw]},
        "apoios": {"Left": [(0, t_toL)], "Right": [(0, t_toR), (t_landR, N)]},
        "fases": {"antecipacao": [0, a0], "empurrao_pe_esq": [a0, t_toL],
                  "pouso_1o_passo_dir": t_landR},
    }
    return spec, info


# ============================================================================ plano: giro 180°
def plano_run_turn():
    """`run_turn_180`: running quadro 7 (índice 6, voo, pé esq. descendo à frente) →
    freia plantando o pé ESQUERDO → pivô na bola dele, quadril gira 180° para a
    ESQUERDA → arranca → running quadro 11 (índice 10) girado 180° (apoio esquerdo)."""
    INI, FIM = 6, 10
    v0 = -run_v(HIPS, INI).y * FPS
    v_fim = -run_v(HIPS, FIM).y * FPS
    pts, marcos = sim_giro(v0, v_fim)
    f_b = marcos["fim_freando_giro"] * FPS     # fim da frenagem (quadro)
    f_g = marcos["fim_girando"] * FPS          # fim do giro
    f_c = marcos["velocidade_cheia"] * FPS
    N = 16
    s_raw = [s_de_pts(pts, f / FPS) for f in range(N + 1)]
    # velocidade por quadro suavizada (a física tem quinas de 1 tique); reintegra
    v = [(s_raw[min(f + 1, N)] - s_raw[max(f - 1, 0)]) / (2 if 0 < f < N else 1) for f in range(N + 1)]
    v[0], v[N] = v0 / FPS, -v_fim / FPS
    vs = suavizar(v, 0.7)
    s = [0.0]
    for f in range(1, N + 1):
        s.append(s[-1] + 0.5 * (vs[f - 1] + vs[f]))
    escala = (s_raw[N] - 0.0) / s[N] if abs(s[N]) > 1e-6 else 1.0
    # mantém o ponto de virada e o fim: corrige só a parte de volta
    smax_i = max(range(N + 1), key=lambda i: s[i])
    smax_raw = max(s_raw)
    s = [x * (smax_raw / s[smax_i]) if i <= smax_i else x for i, x in enumerate(s)]
    k_volta = (smax_raw - s_raw[N]) / (s[smax_i] - s[N])
    s = [x if i <= smax_i else s[smax_i] - (s[smax_i] - x) * k_volta for i, x in enumerate(s)]
    del escala

    def s_t(t):
        if t <= 0:
            return v0 / FPS * t
        if t >= N:
            return s[N] - v_fim / FPS * (t - N)
        i = int(math.floor(t))
        return s[i] + (s[i + 1] - s[i]) * (t - i)

    H0 = RUN.p(HIPS, INI)
    Hy = lambda t: H0.y - s_t(t)
    # guinada do quadril: 10 %→90 % dentro da janela "girando" do jogo
    meio = 0.5 * (f_b + f_g)
    larg = (f_g - f_b) / 0.59 / 2       # cosseno: 10–90 % ocupa 59 % do trecho
    g0, g1 = meio - larg, meio + larg

    def psi(t):
        return math.pi * (0.5 - 0.5 * math.cos(math.pi * clamp01((t - g0) / (g1 - g0))))

    d_peito, d_cabeca = 0.6, 1.4        # liderança (quadros): cabeça > ombros > quadril

    # posição final: running índice 10 girado 180° em volta do próprio quadril
    xF = H0.x + 0.20
    HF_src = RUN.p(HIPS, FIM)
    HF = Vector((xF, Hy(N), HF_src.z))
    T_fim = Matrix.Translation(HF) @ rz(math.pi).to_matrix().to_4x4() @ Matrix.Translation(-HF_src)
    R180 = rz(math.pi)

    def fim_p(bn, ph):  # posição de mundo da pose final (running girado), fase ph
        return T_fim @ (run_p(bn, ph) - F["ciclo"] * 0) if False else T_fim @ run_p(bn, ph)

    vz0 = run_v(HIPS, INI).z
    cz = Curva([(0, H0.z, vz0), (1.2, 0.975), (3.0, 0.900), (5.0, 0.860), (7.0, 0.865),
                (9.0, 0.900), (10.8, 0.935), (12.3, 0.950), (N - 2.3, 0.972), (N, HF_src.z, run_v(HIPS, FIM).z)])
    cx = Curva([(0, H0.x, run_v(HIPS, INI).x), (2.5, H0.x + 0.012), (4.5, H0.x + 0.05),
                (7.0, H0.x + 0.14), (9.0, H0.x + 0.19), (11.0, xF), (N, xF, 0.0)])
    # fase do running para tronco/braços: começa em 6 e termina em 10+21 (inclinação 1)
    ph_c = Curva([(0, float(INI), 1.0), (9.0, 22.5), (N, float(FIM + P_RUN), 1.0)])
    amp = lambda t: 1.0 - 0.65 * (rampa(t, 0.5, 3.5) - rampa(t, 9.5, N - 1.0))
    w_freio = lambda t: rampa(t, 0.5, 3.0) - rampa(t, 8.0, 12.5)   # braços do run to stop
    psi_stop = Curva([(0.5, 4.0), (8.0, 9.5), (12.5, 12.0)])
    inc_c = Curva([(0, 0.0, 0.0), (1.5, -6.0), (3.2, -17.0), (5.2, -9.0), (7.5, 6.0),
                   (9.5, 14.0), (11.5, 11.0), (13.5, 4.0), (N, 0.0, 0.0)])
    tilt_c = Curva([(0, 0.0, 0.0), (2.5, -7.0), (5.0, -3.0), (8.0, 5.0), (11.0, 4.0), (N, 0.0, 0.0)])

    # ---------------- pés
    # ESQUERDO: toca de calcanhar à frente, rola, pivota na bola (0 → 180°), empurra,
    # sai; 2º passo na direção nova até o apoio do running índice 10 (girado).
    t_hs, t_flat, t_toL = 1.0, 2.4, 9.4
    t_L2 = N - 2.3
    psi_plant = math.radians(18.0)
    Qref = F["pe_chato_Left"]
    yaw_ref = yaw_vec(frente_pe(Qref))
    Q_flat = rz(psi_plant + yaw_vec(frente_pe(run_R(B("LeftFoot"), 9.5))) - yaw_ref) @ Qref
    lat = esquerda_de(frente_pe(Q_flat))
    Q_hs = q_eixo(lat, math.radians(-20.0)) @ Q_flat
    calcL = Vector((cx(t_hs) + 0.105, Hy(t_hs) - 0.30, 0.0))
    calcL.z = -(Q_flat @ F["calc_Left"]).z - (Q_flat @ Vector((0, 0, 0))).z  # placeholder
    # o calcanhar no chão: z do calcanhar = 0 com o pé chato → z do tornozelo = −(Q·calc).z
    A_flat_calc = calcL - Q_flat @ F["calc_Left"]
    calcL.z = 0.0
    A_flat = Vector((A_flat_calc.x, A_flat_calc.y, -(Q_flat @ F["calc_Left"]).z))
    bolaL = bola_pelo_tornozelo(A_flat, Q_flat)
    calcL = calc_pelo_tornozelo(A_flat, Q_flat, "Left")
    QL_to = R180 @ run_R(B("LeftFoot"), 12.0)
    psi_push = yaw_vec(frente_pe(QL_to))
    dpsi_piv = wrap(psi_push - yaw_vec(frente_pe(Q_flat)))
    if dpsi_piv < 0:
        dpsi_piv += 2 * math.pi      # gira para a ESQUERDA (sentido +)
    A_ini = RUN.p(B("LeftFoot"), INI)
    v_ini = run_v(B("LeftFoot"), INI)
    A_hs = tornozelo_pelo_calc(calcL, Q_hs, "Left")
    swL1 = CurvaVec([(0, A_ini, v_ini), (t_hs, A_hs, Vector((0, -0.02, -0.03)))])
    rotL1 = CurvaRot([(0, RUN.R(B("LeftFoot"), INI)), (t_hs * 0.5, slerp(RUN.R(B("LeftFoot"), INI), Q_hs, 0.6)), (t_hs, Q_hs)])
    bolaL2 = fim_p(B("LeftToeBase"), 8.0)
    bolaL2.z = RUN.p(B("LeftToeBase"), 8).z
    QL_land = R180 @ run_R(B("LeftFoot"), 7.8)
    AL_land = tornozelo_pela_bola(bolaL2, QL_land)
    vL_land = R180 @ run_v(B("LeftFoot"), 7.6)
    A_toL = tornozelo_pela_bola(bolaL, QL_to)
    t_midL = 0.5 * (t_toL + t_L2)
    fwd_new = Vector((0, 1, 0))
    swL2 = CurvaVec([(t_toL, A_toL, Vector((0, 0.01, 0.02))),
                     (t_midL, Vector((xF + 0.095, Hy(t_midL) - 0.02, 0.27))),
                     (t_L2, AL_land, vL_land)])
    rotL2 = CurvaRot([(t_toL, QL_to), (t_midL, R180 @ run_R(B("LeftFoot"), 2.0)), (t_L2, QL_land)])
    gL2 = Curva([(t_L2, 7.8, None), (N, float(FIM), None)])

    # DIREITO: está no ar (meio do balanço). Varre em volta com o quadril (chaves no
    # referencial que gira com ele), pousa como 1º passo na direção nova, empurra, sai.
    t_R1, t_toR = f_g + 0.2, f_g + 3.4
    QR_ini = RUN.R(B("RightFoot"), INI)
    AR_ini = RUN.p(B("RightFoot"), INI)

    def no_quadril(t, esq, frente, z):
        fw = rz(psi(t)) @ Vector((0, -1, 0))
        lf = rz(psi(t)) @ Vector((1, 0, 0))
        return Vector((cx(t), Hy(t), 0)) + lf * esq + fw * frente + Vector((0, 0, z))

    QR_land = R180 @ run_R(B("RightFoot"), 19.2)
    bolaR1 = Vector((cx(t_R1) + 0.10, Hy(t_R1) + 0.11, RUN.p(B("RightToeBase"), 20).z))
    AR_land = tornozelo_pela_bola(bolaR1, QR_land)
    swR1 = CurvaVec([
        (0, AR_ini, run_v(B("RightFoot"), INI)),
        (2.6, no_quadril(2.6, -0.12, -0.32, 0.47)),
        (4.8, no_quadril(4.8, -0.15, -0.02, 0.36)),
        (6.8, no_quadril(6.8, -0.13, 0.14, 0.23)),
        (t_R1, AR_land, Vector((0, 0.0, -0.012))),
    ])
    rotR1 = CurvaRot([
        (0, QR_ini),
        (4.8, rz(psi(4.8)) @ run_R(B("RightFoot"), 12.0)),
        (t_R1, QR_land),
    ])
    QR_to = R180 @ run_R(B("RightFoot"), 22.0)
    gRs = Curva([(t_R1, 19.2, None), (t_toR, 22.0, None)])
    gR2 = Curva([(t_toR, 22.0, 2.4), (N, float(FIM + P_RUN), 1.0)])

    def pes(t):
        out = {}
        # ---- esquerdo
        if t < t_hs:
            Q, A, c = rotL1(t), swL1(t), rampa(t, t_hs - 1.0, t_hs)
        elif t < t_flat:                                   # rola no calcanhar
            u = rampa(t, t_hs, t_flat, lambda x: x ** 1.4)
            Q = q_eixo(lat, math.radians(-20.0) * (1 - u)) @ Q_flat
            A, c = tornozelo_pelo_calc(calcL, Q, "Left"), 1.0
        elif t <= t_toL:                                   # bola fixa: pivô e empurrão
            yaw_u = rampa(t, g0 - 0.3, g1 + 0.2, smooth)
            Qy = rz(dpsi_piv * yaw_u) @ Q_flat
            alfa = math.radians(13.0) * rampa(t, 2.8, 4.2)
            Qp = q_eixo(esquerda_de(frente_pe(Qy)), alfa) @ Qy
            Q = slerp(Qp, QL_to, rampa(t, f_g - 1.2, t_toL, lambda x: x ** 1.5))
            A, c = tornozelo_pela_bola(bolaL, Q), 1.0
        elif t < t_L2:
            Q, A = rotL2(t), swL2(t)
            c = max(1 - rampa(t, t_toL, t_toL + 1.5), rampa(t, t_L2 - 1.2, t_L2))
        else:
            ph = gL2(t)
            Q = R180 @ run_R(B("LeftFoot"), ph)
            A, c = tornozelo_pela_bola(bolaL2, Q), 1.0
        out["Left"] = (A, Q, c, None)
        # ---- direito
        if t < t_R1:
            Q, A = rotR1(t), swR1(t)
            c = rampa(t, t_R1 - 1.2, t_R1)
        elif t <= t_toR:
            Q = R180 @ run_R(B("RightFoot"), gRs(t))
            A, c = tornozelo_pela_bola(bolaR1, Q), 1.0
        else:
            ph = gR2(t)
            Q = R180 @ run_R(B("RightFoot"), ph)
            rel = run_p(B("RightFoot"), ph) - run_p(HIPS, ph)
            rel0 = run_p(B("RightFoot"), 22.0) - run_p(HIPS, 22.0)
            A_to = tornozelo_pela_bola(bolaR1, QR_to)
            base0 = Vector((cx(t_toR), Hy(t_toR), 0)) + R180 @ Vector((rel0.x, rel0.y, 0))
            corr = Vector((A_to.x - base0.x, A_to.y - base0.y, A_to.z - run_p(B("RightFoot"), 22.0).z))
            A = (Vector((cx(t), Hy(t), 0)) + R180 @ Vector((rel.x, rel.y, 0))
                 + Vector((0, 0, run_p(B("RightFoot"), ph).z)) + corr * (1 - rampa(t, t_toR, t_toR + 3.0)))
            c = 1 - rampa(t, t_toR, t_toR + 1.5)
        out["Right"] = (A, Q, c, None)
        return out

    def spec(t):
        ph = ph_c(t)
        a = amp(t)
        p = psi(t)
        Rbase = slerp(F["R_quadril_media"], run_R(HIPS, ph), a)
        Rbase = q_eixo(Vector((1, 0, 0)), math.radians(tilt_c(t))) @ Rbase
        Rq = rz(p) @ Rbase
        pos = Vector((cx(t), Hy(t), cz(t)))
        base = {}
        wf = w_freio(t)
        for bn in ossos_cima():
            q = slerp(F["q_media"][bn], run_q(bn, ph), a)
            if wf > 0 and ("Arm" in bn or "Hand" in bn or "Shoulder" in bn):
                q = slerp(q, stop_q(bn, psi_stop(t)), wf)
            base[bn] = (run_loc(bn, ph), q)
        lead_peito = psi(t + d_peito) - p
        # cabeça: alvo = guinada que a pose já tem + liderança extra
        fH = frente_de(run_R(B("Head"), ph))
        fQ = frente_de(run_R(HIPS, ph))
        yaw_cab = yaw_vec(fQ) * a + p + wrap(yaw_vec(fH) - yaw_vec(fQ)) + (psi(t + d_cabeca) - p)
        return {"quadril": (pos, Rq), "base": base, "inclinacao": inc_c(t),
                "lead_peito": lead_peito, "cabeca_yaw": yaw_cab,
                "cabeca_pitch": math.asin(fH.z), "pes": pes(t)}

    info = {
        "N": N, "fonte_inicio": ("running", INI), "fonte_fim": ("running", FIM),
        "transf_fim": T_fim, "v_fim": v_fim, "v_ini": v0,
        "fisica": {"v0_m_s": round(v0, 3), "alvo_m_s": round(v_fim, 3),
                   "fim_frenagem_quadro": round(f_b, 2), "fim_giro_quadro": round(f_g, 2),
                   "velocidade_cheia_quadro": round(f_c, 2),
                   "s_jogo_m_por_quadro": [round(x, 4) for x in s_raw]},
        "giro_janela_quadros": [round(g0, 2), round(g1, 2)],
        "apoios": {"Left": [(t_hs, t_toL), (t_L2, N)], "Right": [(t_R1, t_toR)]},
        "fases": {"frenagem": [0, round(f_b, 2)], "giro": [round(f_b, 2), round(f_g, 2)],
                  "arranque": [round(f_g, 2), round(f_c, 2)], "toque_calcanhar_esq": t_hs,
                  "desprende_esq": t_toL, "pouso_dir": round(t_R1, 2), "desprende_dir": round(t_toR, 2),
                  "pouso_esq_2": round(t_L2, 2)},
    }
    return spec, info


# ============================================================================ autoria + assar
def polo_dir(lado, Rq, Q_pe):
    return horiz(horiz(frente_de(Rq)) + horiz(frente_pe(Q_pe)))


def criar_vazio(nome):
    o = bpy.data.objects.new(nome, None)
    SC.collection.objects.link(o)
    o.rotation_mode = "QUATERNION"
    o.empty_display_size = 0.05
    return o


def autorar(nome, spec_fn, info):
    N = info["N"]
    act = bpy.data.actions.new(nome)
    act.use_fake_user = True
    if ARM.animation_data is None:
        ARM.animation_data_create()
    ARM.animation_data.action = act
    for pb in ARM.pose.bones:
        pb.matrix_basis = Matrix()

    # ---- 1ª passada: monta e corrige o alcance (abaixa o quadril se a perna esticar)
    specs = [spec_fn(float(f)) for f in range(N + 1)]
    queda = []
    for f, sp in enumerate(specs):
        montar_tronco(sp)
        q = 0.0
        for lado in LADOS:
            H = p_mundo(B(lado + "UpLeg"))
            A = sp["pes"][lado][0]
            dxy = math.hypot(H.x - A.x, H.y - A.y)
            if dxy < F["alcance"]:
                dz = (H.z - A.z) - math.sqrt(F["alcance"] ** 2 - dxy ** 2)
                q = max(q, dz)
        queda.append(max(0.0, q))
    if max(queda) > 0:
        q2 = [max(queda[max(0, i - 1):i + 2]) for i in range(N + 1)]
        q2 = suavizar(q2, 0.8)
        q2 = [max(a, b) for a, b in zip(q2, queda)]
        for f, sp in enumerate(specs):
            if q2[f] > 0:
                pos, rot = sp["quadril"]
                sp["quadril"] = (pos - Vector((0, 0, q2[f])), rot)
    info["queda_quadril_alcance_cm"] = round(100 * max(queda), 2)

    # ---- 2ª passada: chaves FK do tronco, dedos; vazios do IK por quadro
    alvo = {l: criar_vazio("ik_alvo_" + l) for l in LADOS}
    polo = {l: criar_vazio("ik_polo_" + l) for l in LADOS}
    ant = {}
    for f, sp in enumerate(specs):
        fr = f + 1
        montar_tronco(sp)
        Rq = R_mundo(HIPS)
        for lado in LADOS:
            A, Q, contato, _ = sp["pes"][lado]
            # dedo: chato no chão quando apoiado, solto (pose da corrida) no ar
            q_solto = run_q(B(lado + "ToeBase"), 10.0)
            q_chao = dedo_local(lado, Q, dedo_chato(lado, Q))
            ARM.pose.bones[B(lado + "ToeBase")].rotation_quaternion = slerp(q_solto, q_chao, contato)
            H = p_mundo(B(lado + "UpLeg"))
            d = (A - H).normalized()
            n = polo_dir(lado, Rq, Q)
            n = (n - d * n.dot(d)).normalized()
            alvo[lado].location = A
            alvo[lado].rotation_quaternion = compat(Q, ant.get(lado, Q))
            ant[lado] = alvo[lado].rotation_quaternion.copy()
            polo[lado].location = (H + A) * 0.5 + n * 0.5
            alvo[lado].keyframe_insert("location", frame=fr)
            alvo[lado].keyframe_insert("rotation_quaternion", frame=fr)
            polo[lado].keyframe_insert("location", frame=fr)
        for pb in ARM.pose.bones:
            if pb.name in (B("LeftUpLeg"), B("LeftLeg"), B("LeftFoot"),
                           B("RightUpLeg"), B("RightLeg"), B("RightFoot")):
                continue
            q = pb.rotation_quaternion.copy()
            if (pb.name, "q") in ant:
                q = compat(q, ant[(pb.name, "q")])
                pb.rotation_quaternion = q
            ant[(pb.name, "q")] = q.copy()
            pb.keyframe_insert("rotation_quaternion", frame=fr)
            pb.keyframe_insert("location", frame=fr)
    # ---- restrições
    for lado in LADOS:
        c = ARM.pose.bones[B(lado + "Leg")].constraints.new("IK")
        c.target = alvo[lado]
        c.pole_target = polo[lado]
        c.pole_angle = math.radians(90.0)
        c.chain_count = 2
        c.use_tail = True
        c.iterations = 500
        cr = ARM.pose.bones[B(lado + "Foot")].constraints.new("COPY_ROTATION")
        cr.target = alvo[lado]
    SC.frame_start, SC.frame_end = 1, N + 1
    # ---- assa para FK
    assar(N)
    for o in list(alvo.values()) + list(polo.values()):
        if o.animation_data and o.animation_data.action:
            bpy.data.actions.remove(o.animation_data.action)
        bpy.data.objects.remove(o, do_unlink=True)
    act = ARM.animation_data.action
    act.name = nome
    act.use_fake_user = True
    # ---- funde as pontas com as poses-fonte exatas
    fundir_pontas(info)
    dedos_acima_do_chao(info)
    continuidade_quaternions(N)
    act.use_frame_range = True
    act.frame_start, act.frame_end = 1, N + 1
    return act


def assar(N):
    for o in SC.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ARM
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    for pb in ARM.pose.bones:
        pb.bone.select = True
    try:
        bpy.ops.nla.bake(frame_start=1, frame_end=N + 1, step=1, only_selected=False,
                         visual_keying=True, clear_constraints=True, clear_parents=False,
                         use_current_action=True, clean_curves=False, bake_types={"POSE"})
        F.setdefault("assado_por", "bpy.ops.nla.bake")
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ARM.pose.bones:  # garantia: nenhuma restrição sobra
        for c in list(pb.constraints):
            pb.constraints.remove(c)


def pose_fonte(clipe_nome, idx):
    return {"idle": IDLE, "running": RUN, "run_to_stop": STOP}[clipe_nome].base[idx]


def fundir_pontas(info, W=3.0):
    """Correção que vale 100 % na ponta e some em W quadros: q' = q · slerp(1, δ, w)."""
    N = info["N"]
    pontas = [(1, pose_fonte(*info["fonte_inicio"])), (N + 1, pose_fonte(*info["fonte_fim"]))]
    deltas = []
    for fr, fonte in pontas:
        SC.frame_set(fr)
        d = {}
        for pb in ARM.pose.bones:
            if pb.name == HIPS:
                continue
            d[pb.name] = pb.rotation_quaternion.inverted() @ compat(fonte[pb.name][1], pb.rotation_quaternion)
        deltas.append((fr, d))
    for fr in range(1, N + 2):
        ws = [(1 - smooth(abs(fr - fp) / W), d) for fp, d in deltas]
        if all(w <= 0 for w, _ in ws):
            continue
        SC.frame_set(fr)
        for pb in ARM.pose.bones:
            if pb.name == HIPS:
                continue
            q = pb.rotation_quaternion.copy()
            for w, d in ws:
                if w > 0:
                    q = q @ Quaternion().slerp(d[pb.name], w)
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=fr)


def dedos_acima_do_chao(info, folga=0.002):
    N = info["N"]
    n = 0
    for fr in range(1, N + 2):
        SC.frame_set(fr)
        mexeu = False
        for lado in LADOS:
            pb = ARM.pose.bones[B(lado + "ToeBase")]
            for _ in range(4):
                atualizar()
                z = p_mundo(B(lado + "Toe_End")).z
                if z >= folga - 1e-4:
                    break
                comp = ARM.data.bones[B(lado + "ToeBase")].length * ESC
                ang = math.asin(min(1.0, (folga - z) / comp)) + 0.002
                # gira o dedo para CIMA em volta do eixo lateral do pé
                Rt = R_mundo(B(lado + "ToeBase"))
                eixo = esquerda_de(frente_pe(Rt))
                girar_mundo(B(lado + "ToeBase"), eixo, -ang, {B(lado + "ToeBase"): Rt})
                mexeu = True
            if mexeu:
                pb.keyframe_insert("rotation_quaternion", frame=fr)
        n += mexeu
    info["quadros_dedo_corrigido"] = n


def continuidade_quaternions(N):
    ant = {}
    for fr in range(1, N + 2):
        SC.frame_set(fr)
        for pb in ARM.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in ant and q.dot(ant[pb.name]) < 0:
                q.negate()
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=fr)
            ant[pb.name] = q


def usar_acao(act):
    ARM.animation_data.action = act
    if act.slots:
        ARM.animation_data.action_slot = act.slots[0]


# ============================================================================ medidas
def flexao_joelho(q):
    """Flexão do joelho (graus): giro da canela em volta de −X local (eixo da dobra no
    rig Mixamo). Negativo = hiperextensão."""
    q = compat(q, Quaternion())
    return math.degrees(2 * math.atan2(-q.x, q.w))


def min_z_malha():
    dg = bpy.context.evaluated_depsgraph_get()
    zmin = 1e9
    for o in MALHAS:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        M = np.array(ev.matrix_world)
        z = co @ M[2, :3] + M[2, 3]
        zmin = min(zmin, float(z.min()))
        ev.to_mesh_clear()
    return zmin


def amostrar(act, N):
    usar_acao(act)
    linhas = []
    for fr in range(1, N + 2):
        SC.frame_set(fr)
        L = {"quadril": p_mundo(HIPS).copy(), "R_quadril": R_mundo(HIPS),
             "R_peito": R_mundo(B("Spine2")), "R_cabeca": R_mundo(B("Head")),
             "pescoco": p_mundo(B("Neck")).copy(), "malha_z": min_z_malha(),
             "base": {pb.name: pb.rotation_quaternion.copy() for pb in ARM.pose.bones}}
        for lado in LADOS:
            Qp = R_mundo(B(lado + "Foot"))
            A = p_mundo(B(lado + "Foot")).copy()
            L[lado] = {"tornozelo": A, "bola": p_mundo(B(lado + "ToeBase")).copy(),
                       "ponta": p_mundo(B(lado + "Toe_End")).copy(),
                       "calcanhar": calc_pelo_tornozelo(A, Qp, lado),
                       "joelho": flexao_joelho(ARM.pose.bones[B(lado + "Leg")].rotation_quaternion)}
        linhas.append(L)
    return linhas


def escorregamento(linhas, lado, ponto, lim=0.012):
    """Maior deslocamento horizontal (cm) de um ponto do pé enquanto ele está no chão
    (z < lim), por trecho contínuo de apoio."""
    piores = []
    ini = None
    for i, L in enumerate(linhas + [None]):
        p = L[lado][ponto] if L else None
        if p is not None and p.z < lim:
            if ini is None:
                ini = i
        elif ini is not None:
            ref = linhas[ini][lado][ponto]
            d = max(math.hypot(linhas[j][lado][ponto].x - ref.x, linhas[j][lado][ponto].y - ref.y)
                    for j in range(ini, i))
            piores.append({"quadros": [ini, i - 1], "cm": round(100 * d, 2)})
            ini = None
    return piores


def ang_q(a, b):
    return math.degrees(a.rotation_difference(b).angle) % 360.0


def ang_min(a, b):
    g = ang_q(a, b)
    return min(g, 360.0 - g)


def erro_emenda(base_out, fonte_base, R_out, R_fonte_mundo):
    pior, osso = 0.0, None
    for bn, (loc, q) in fonte_base.items():
        if bn == HIPS:
            continue
        g = ang_min(base_out[bn], q)
        if g > pior:
            pior, osso = g, bn
    return {"max_graus_por_osso": round(pior, 3), "osso": osso,
            "quadril_mundo_graus": round(ang_min(R_out, R_fonte_mundo), 3)}


def yaw_unwrap(vals):
    out = [vals[0]]
    for v in vals[1:]:
        out.append(out[-1] + wrap(v - out[-1]))
    return out


def inclinacao_tronco(L):
    d = L["pescoco"] - L["quadril"]
    f = horiz(frente_de(L["R_quadril"]))
    return math.degrees(math.atan2(d.dot(f), d.z))


def medir(nome, act, info):
    N = info["N"]
    linhas = amostrar(act, N)
    hips = [L["quadril"] for L in linhas]
    # velocidade (m/s) — diferença central; pontas: unilateral
    vel = []
    for i in range(N + 1):
        a, b = max(0, i - 1), min(N, i + 1)
        vel.append((hips[b] - hips[a]) * (FPS / (b - a)))
    frente0 = Vector((0, -1, 0))
    v_frente = [v.dot(frente0) for v in vel]
    m = {"duracao_s": round(N / FPS, 4), "quadros": N + 1, "fps": FPS}
    m["deslocamento_quadril_m"] = [round(x, 4) for x in (hips[-1] - hips[0])]
    m["velocidade_quadril_frente_m_s"] = [round(x, 3) for x in v_frente]
    m["altura_quadril_m"] = [round(h.z, 4) for h in hips]
    # emendas
    fi, ii = info["fonte_inicio"]
    ff, ifim = info["fonte_fim"]
    clipe = {"idle": IDLE, "running": RUN}
    m["emenda_inicio"] = dict(fonte=f"{fi} quadro {ii + 1} (índice {ii})",
                              **erro_emenda(linhas[0]["base"], clipe[fi].base[ii], linhas[0]["R_quadril"],
                                            clipe[fi].R(HIPS, ii)))
    R_fim_fonte = q_rot(info["transf_fim"]) @ clipe[ff].R(HIPS, ifim)
    m["emenda_fim"] = dict(fonte=f"{ff} quadro {ifim + 1} (índice {ifim})",
                           **erro_emenda(linhas[-1]["base"], clipe[ff].base[ifim], linhas[-1]["R_quadril"],
                                         R_fim_fonte))
    p_fim_fonte = info["transf_fim"] @ clipe[ff].p(HIPS, ifim)
    m["emenda_fim"]["quadril_posicao_cm"] = round(100 * (hips[-1] - p_fim_fonte).length, 3)
    m["emenda_inicio"]["quadril_posicao_cm"] = round(100 * (hips[0] - clipe[fi].p(HIPS, ii)).length, 3)
    # pés
    m["escorregamento_cm"] = {}
    for lado in LADOS:
        m["escorregamento_cm"][lado] = {"bola": escorregamento(linhas, lado, "bola"),
                                        "calcanhar": escorregamento(linhas, lado, "calcanhar")}
    todos = [t["cm"] for l in LADOS for k in ("bola", "calcanhar") for t in m["escorregamento_cm"][l][k]]
    m["escorregamento_max_cm"] = max(todos) if todos else 0.0
    m["joelho_flexao_min_graus"] = {l: round(min(L[l]["joelho"] for L in linhas), 2) for l in LADOS}
    m["chao_min_cm"] = {
        "malha": round(100 * min(L["malha_z"] for L in linhas), 2),
        "pontos_do_pe": round(100 * min(min(L[l][k].z for k in ("bola", "ponta", "calcanhar"))
                                        for L in linhas for l in LADOS), 2)}
    m["inclinacao_tronco_graus"] = [round(inclinacao_tronco(L), 1) for L in linhas]
    yq = yaw_unwrap([yaw_vec(frente_de(L["R_quadril"])) for L in linhas])
    yp = yaw_unwrap([yaw_vec(frente_de(L["R_peito"])) for L in linhas])
    yc = yaw_unwrap([yaw_vec(frente_de(L["R_cabeca"])) for L in linhas])
    m["guinada_graus"] = {"quadril": [round(math.degrees(y - yq[0]), 1) for y in yq],
                          "peito": [round(math.degrees(y - yp[0]), 1) for y in yp],
                          "cabeca": [round(math.degrees(y - yc[0]), 1) for y in yc]}
    m["giro_quadril_graus"] = round(math.degrees(yq[-1] - yq[0]), 2)
    info_pub = {k: v for k, v in info.items() if k not in ("transf_fim",)}
    m["plano"] = json.loads(json.dumps(info_pub, default=lambda o: list(o) if hasattr(o, "__iter__") else str(o)))
    return m, linhas


def medir_fontes():
    """Linha de base: o que o próprio pacote faz (escorregamento, chão)."""
    out = {}
    for nome, act_nome, n in (("running", "ref_running", RUN.n - 1), ("run_to_stop", "ref_run_to_stop", STOP.n - 1),
                              ("idle_30q", "ref_idle", 29)):
        act = bpy.data.actions[act_nome]
        linhas = amostrar(act, n)
        esc = []
        for lado in LADOS:
            for k in ("bola", "calcanhar"):
                esc += [t["cm"] for t in escorregamento(linhas, lado, k)]
        out[nome] = {"escorregamento_max_cm": max(esc) if esc else 0.0,
                     "chao_min_malha_cm": round(100 * min(L["malha_z"] for L in linhas), 2),
                     "inclinacao_tronco_graus": [round(inclinacao_tronco(L), 1) for L in linhas][:12]}
    return out


# ============================================================================ folhas
CAM = TXT = None


def preparar_cena_render():
    global CAM, TXT
    for o in MALHAS:
        o.color = (0.80, 0.52, 0.27, 1) if "Surface" in o.name else (0.18, 0.18, 0.22, 1)
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0, -1.5, 0))
    chao = bpy.context.object
    chao.name = "chao"
    chao.color = (0.86, 0.86, 0.83, 1)
    for i in range(-28, 29):
        for eixo in (0, 1):
            bpy.ops.mesh.primitive_cube_add(size=1)
            c = bpy.context.object
            c.name = "grade"
            forte = i % 4 == 0
            w = 0.006 if forte else 0.003
            if eixo == 0:
                c.scale = (7.0, w, 0.0008)
                c.location = (0, -1.5 + i * 0.25, 0.0008)
            else:
                c.scale = (w, 7.0, 0.0008)
                c.location = (i * 0.25, -1.5, 0.0008)
            c.color = (0.35, 0.35, 0.35, 1) if forte else (0.6, 0.6, 0.58, 1)
    SC.render.engine = "BLENDER_WORKBENCH"
    sh = SC.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_cavity = True
    sh.show_shadows = False
    SC.render.resolution_x, SC.render.resolution_y = 300, 380
    SC.render.resolution_percentage = 100
    if SC.world is None:
        SC.world = bpy.data.worlds.new("mundo")
    SC.world.color = (0.97, 0.97, 0.97)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    CAM = bpy.data.objects.new("cam", cam)
    SC.collection.objects.link(CAM)
    SC.camera = CAM
    cur = bpy.data.curves.new("rotulo", "FONT")
    cur.size = 0.11
    TXT = bpy.data.objects.new("rotulo", cur)
    SC.collection.objects.link(TXT)
    TXT.color = (0.05, 0.05, 0.05, 1)
    TXT.parent = CAM


def posicionar_cam(alvo, vista, escala):
    CAM.data.ortho_scale = escala
    if vista == "lado":
        e = math.radians(12.0)
        CAM.location = alvo + Vector((math.cos(e), 0, math.sin(e))) * 8.0
        CAM.rotation_euler = (math.radians(90) - e, 0, math.radians(90))
    else:
        CAM.location = alvo + Vector((0, 0, 8.0))
        CAM.rotation_euler = (0, 0, math.radians(90))
    hh = escala / 2
    hw = hh * SC.render.resolution_x / SC.render.resolution_y
    TXT.location = (-hw + 0.04, hh - 0.14, -1.0)
    TXT.rotation_euler = (0, 0, 0)


def render_png(caminho):
    SC.render.filepath = caminho
    bpy.ops.render.render(write_still=True)


def compor(linhas_png, saida):
    linhas = []
    for row in linhas_png:
        ims = []
        for p in row:
            im = bpy.data.images.load(p)
            a = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
            ims.append(a)
            bpy.data.images.remove(im)
        linhas.append(np.concatenate(ims, axis=1))
    W = max(l.shape[1] for l in linhas)
    linhas = [np.pad(l, ((0, 0), (0, W - l.shape[1]), (0, 0)), constant_values=1.0) for l in linhas]
    full = np.concatenate(linhas[::-1], axis=0)
    im = bpy.data.images.new("folha", full.shape[1], full.shape[0], alpha=True)
    im.pixels[:] = full.ravel()
    im.filepath_raw = saida
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def quadros_8(n_ult):
    return sorted(set(int(round(i * n_ult / 7.0)) for i in range(8)))


def folha_clipe(nome, act, N, tmp):
    usar_acao(act)
    fs = quadros_8(N)
    pos = []
    for f in range(N + 1):
        SC.frame_set(f + 1)
        pos.append(p_mundo(HIPS).copy())
    xs, ys = [p.x for p in pos], [p.y for p in pos]
    centro = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0.85))
    vao = max(max(ys) - min(ys), max(xs) - min(xs))
    rows = []
    for vista in ("lado", "cima"):
        row = []
        for f in fs:
            SC.frame_set(f + 1)
            alvo = centro if vista == "lado" else Vector((centro.x, centro.y, 0))
            posicionar_cam(alvo, vista, max(2.3, vao + 1.3))
            TXT.data.body = f"{nome} q{f}" if f == fs[0] else f"q{f}"
            p = os.path.join(tmp, f"{nome}_{vista}_{f}.png")
            render_png(p)
            row.append(p)
        rows.append(row)
    compor(rows, os.path.join(DIR_VAL, nome + ".png"))


def folha_comparacao(acoes, tmp):
    rows = []
    for rot, act, n_ult in acoes:
        usar_acao(act)
        row = []
        for f in quadros_8(n_ult):
            SC.frame_set(f + 1)
            h = p_mundo(HIPS)
            posicionar_cam(Vector((h.x, h.y, 0.85)), "lado", 2.2)
            TXT.data.body = f"{rot} q{f}" if f == 0 else f"q{f}"
            p = os.path.join(tmp, f"cmp_{rot}_{f}.png")
            render_png(p)
            row.append(p)
        rows.append(row)
    compor(rows, os.path.join(DIR_VAL, "comparacao_ator.png"))


# ============================================================================ GLB
def ler_glb_json(path):
    with open(path, "rb") as fh:
        b = fh.read()
    n = struct.unpack("<I", b[12:16])[0]
    return json.loads(b[20:20 + n])


def resumo_glb(path):
    j = ler_glb_json(path)
    raiz = j["nodes"][j["scenes"][0]["nodes"][0]]
    an = j["animations"]
    s = an[0]["samplers"][0]
    acc = j["accessors"][s["input"]]
    return {"animacoes": [a["name"] for a in an], "canais": len(an[0]["channels"]),
            "chaves": acc["count"], "t_s": [acc["min"][0], acc["max"][0]],
            "raiz": raiz["name"], "raiz_rot": raiz.get("rotation"), "raiz_escala": raiz.get("scale"),
            "juntas_skin": len(j["skins"][0]["joints"]) if j.get("skins") else 0,
            "malhas": len(j.get("meshes", [])), "interpolacao": s["interpolation"]}


def exportar_glb(nome_acao, N, saida):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arm = bpy.data.objects["Armature"]
    for o in list(bpy.data.objects):
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    act = bpy.data.actions[nome_acao]
    for a in list(bpy.data.actions):
        if a != act:
            bpy.data.actions.remove(a)
    arm.animation_data.action = act
    arm.animation_data.action_slot = act.slots[0]
    sc = bpy.context.scene
    sc.render.fps, sc.render.fps_base = FPS, 1.0
    sc.frame_start, sc.frame_end = 1, N + 1
    bpy.ops.export_scene.gltf(filepath=saida, export_format="GLB", export_animations=True,
                              export_force_sampling=True, export_bake_animation=True,
                              export_anim_single_armature=True, export_skins=True)


def conferir_glb(path, ref):
    """Reimporta o GLB e compara posições de ossos com as do .blend (cm)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    pior = 0.0
    for fr, ossos in ref.items():
        sc.frame_set(int(fr))
        for bn, p in ossos.items():
            q = arm.matrix_world @ arm.pose.bones[bn].head
            pior = max(pior, (q - Vector(p)).length)
    return round(100 * pior, 4)


# ============================================================================ principal
def main():
    global SC
    t0 = time.time()
    os.makedirs(DIR_GLB, exist_ok=True)
    os.makedirs(DIR_VAL, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="chao_")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SC = bpy.context.scene
    SC.render.fps, SC.render.fps_base = FPS, 1.0
    carregar_fontes(tmp)

    clipes = {}
    for nome, plano in (("run_start", plano_run_start), ("run_turn_180", plano_run_turn)):
        spec, info = plano()
        act = autorar(nome, spec, info)
        clipes[nome] = (act, info)
        print(f"[chao] {nome}: {info['N'] + 1} quadros, queda p/ alcance "
              f"{info['queda_quadril_alcance_cm']} cm")

    medidas = {"gerado_em": time.strftime("%Y-%m-%d %H:%M"), "script": os.path.relpath(_AQUI, REPO),
               "fonte": ZIP, "fps": FPS, "assado_por": F.get("assado_por")}
    for nome, (act, info) in clipes.items():
        m, _ = medir(nome, act, info)
        medidas[nome] = m
    medidas["referencias_pacote"] = medir_fontes()

    if "--sem-folhas" not in ARGS:
        preparar_cena_render()
        for nome, (act, info) in clipes.items():
            folha_clipe(nome, act, info["N"], tmp)
        folha_comparacao([("running", bpy.data.actions["ref_running"], P_RUN - 1),
                          ("run_start", clipes["run_start"][0], clipes["run_start"][1]["N"]),
                          ("run_to_stop", bpy.data.actions["ref_run_to_stop"], STOP.n - 1),
                          ("run_turn_180", clipes["run_turn_180"][0], clipes["run_turn_180"][1]["N"])], tmp)

    # referência para conferir o GLB
    refs = {}
    for nome, (act, info) in clipes.items():
        usar_acao(act)
        N = info["N"]
        refs[nome] = {}
        for fr in sorted({1, N // 2 + 1, N + 1}):
            SC.frame_set(fr)
            refs[nome][fr] = {bn: tuple(p_mundo(bn)) for bn in
                              (HIPS, B("LeftFoot"), B("RightFoot"), B("LeftHand"), B("RightHand"), B("Head"))}
    usar_acao(clipes["run_start"][0])
    SC.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, check_existing=False, compress=True)
    Ns = {nome: info["N"] for nome, (act, info) in clipes.items()}
    caminho_json = os.path.join(DIR_VAL, "medidas_chao.json")
    if "--sem-glb" not in ARGS:
        medidas["glb"] = {}
        for nome, N in Ns.items():
            saida = os.path.join(DIR_GLB, nome + ".glb")
            exportar_glb(nome, N, saida)
            medidas["glb"][nome] = resumo_glb(saida)
        for nome in Ns:
            medidas["glb"][nome]["erro_reimportado_cm"] = conferir_glb(
                os.path.join(DIR_GLB, nome + ".glb"), refs[nome])
    with open(caminho_json, "w", encoding="utf-8") as fh:
        json.dump(medidas, fh, ensure_ascii=False, indent=1)
    print(f"[chao] pronto em {time.time() - t0:.1f} s → {caminho_json}")


main()
