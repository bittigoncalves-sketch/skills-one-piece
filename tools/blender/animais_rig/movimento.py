"""Movimento do quadrúpede: as 6 ações (idle, walk, run, damage, attack, death).

Cada ação é uma lista de POSES (uma por quadro, 30 qps). Uma pose diz:
  raiz_loc / raiz_rot   o corpo todo (o osso raiz fica no chão, embaixo do tronco);
  tronco, quadril, peito, pescoco, cabeca, cauda_1..3
                        rotações nos EIXOS DO REPOUSO (X = lado do bicho, Y = para trás,
                        Z = para cima), aplicadas no quadro do pai já posado — rot(pitch=+)
                        baixa o focinho, rot(yaw=+) vira para a esquerda (+X),
                        rot(roll=+) deita sobre o lado esquerdo;
  pes                   {perna: (alvo no chão, flexão do casco)} — IK de dois ossos com o
                        joelho/jarrete dobrando para o lado do repouso;
  fk / mistura_fk       pernas soltas (no ar, morto) e a mistura com o IK.

Locomoção no lugar (o jogo move o corpo): no apoio a pata corre para trás na velocidade
da ficha; no ar volta para a frente erguida. O passo casa com `v` (m/s no arquivo).
"""
import math
import bpy
from mathutils import Vector, Quaternion, Matrix

FPS = 30
X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))
FRENTE = Vector((0, -1, 0))
ID = Quaternion()


def rad(g):
    return math.radians(g)


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    return Quaternion(Z, yaw) @ Quaternion(X, pitch) @ Quaternion(Y, roll)


def suave(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def curva(t, pontos):
    """Valor em t de uma curva por pontos (tempo, valor), suavizada entre eles."""
    if t <= pontos[0][0]:
        return pontos[0][1]
    for (t0, v0), (t1, v1) in zip(pontos, pontos[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * suave((t - t0) / max(t1 - t0, 1e-9))
    return pontos[-1][1]


def _m(q):
    return q.to_matrix().to_4x4()


class Rig:
    def __init__(self, arm, m):
        self.arm = arm
        self.m = m
        ossos = arm.data.bones
        self.rest = {b.name: b.matrix_local.copy() for b in ossos}
        self.q = {n: M.to_quaternion() for n, M in self.rest.items()}
        self.h = {n: M.translation.copy() for n, M in self.rest.items()}
        self.ponta = {b.name: b.tail_local.copy() for b in ossos}
        self.pai = {b.name: (b.parent.name if b.parent else None) for b in ossos}
        self.pernas = {}
        comp = []
        for n, p in m["pernas"].items():
            pre, lado = "perna_" + n[:-2], n[-2:]
            nomes = [pre + "_1" + lado, pre + "_2" + lado, pre + "_3" + lado]
            J, K, A = self.h[nomes[0]], self.h[nomes[1]], self.h[nomes[2]]
            u = (A - J).normalized()
            fora = (K - J) - u * (K - J).dot(u)
            polo = fora.normalized() if fora.length > 0.01 * m["H"] else (FRENTE.copy() if p.frente else -FRENTE)
            self.pernas[n] = {"ossos": nomes, "frente": p.frente, "polo": polo,
                              "chao": self.ponta[nomes[2]].copy(), "esquerda": p.esquerda}
            comp.append(J.z - m["z0"])
        self.ell = sum(comp) / len(comp) if comp else 0.3 * m["H"]
        # Quanto o corpo pode avançar/recuar com as patas plantadas: perna curta (corgi)
        # não acompanha a investida de um cão de perna longa. 1 = vaca (perna 1/3 do corpo).
        self.alcance = min(1.0, self.ell / (0.3 * m["L"]))
        self.inclina = m.get("inclina_pastar", 0.1)
        self.cauda = [n for n in ("cauda_1", "cauda_2", "cauda_3") if n in self.rest]
        conhecidos = {"raiz", "tronco", "quadril", "peito", "pescoco", "cabeca"} | set(self.cauda) \
            | {n for perna in self.pernas.values() for n in perna["ossos"]}
        # Ossos além da cadeia e das pernas (asas do voador), em ordem de pai para filho.
        self.extras = [b.name for b in ossos if b.name not in conhecidos]
        self.z0 = m["z0"]
        self.H = m["H"]
        # Tamanho do bicho para medidas relativas: o pardal tem 8 cm de altura e 58 de envergadura.
        self.tamanho = max(m["H"], 0.25 * max(m["L"], 2 * m.get("W", 0.0)))
        self.L = m["L"]

    # ------------------------------------------------------------------ pose
    def _G(self, n, G, local):
        pai = self.pai[n]
        Gp = G[pai] if pai else Matrix.Identity(4)
        G[n] = Gp @ self.rest[n] @ _m(local) @ self.rest[n].inverted()

    def _local_fk(self, n, Re):
        return self.q[n].inverted() @ Re @ self.q[n]

    def pose(self, p):
        """{osso: (quaternion local, location local ou None)} e as matrizes G (delta no espaço da armature)."""
        out, G = {}, {}
        # raiz: translação + rotação em volta do pé do osso (no chão)
        Re = p.get("raiz_rot", ID)
        loc = p.get("raiz_loc", Vector())
        h = self.h["raiz"]
        G["raiz"] = Matrix.Translation(loc) @ Matrix.Translation(h) @ _m(Re) @ Matrix.Translation(-h)
        out["raiz"] = (self._local_fk("raiz", Re), self.q["raiz"].inverted() @ loc)
        for n in ["tronco", "quadril", "peito", "pescoco", "cabeca"] + self.cauda:
            local = self._local_fk(n, p.get(n, ID))
            out[n] = (local, None)
            self._G(n, G, local)
        for nome, perna in self.pernas.items():
            nomes = perna["ossos"]
            alvo = p.get("pes", {}).get(nome)
            fk = p.get("fk", {}).get(nome, [ID, ID, ID])
            b = p.get("mistura_fk", {}).get(nome, 0.0 if alvo else 1.0)
            locais_fk = [self._local_fk(n, r) for n, r in zip(nomes, fk)]
            if alvo is not None and b < 1.0:
                locais_ik = self._ik(nome, perna, alvo, G)
                locais = [a.slerp(c, b) for a, c in zip(locais_ik, locais_fk)]
            else:
                locais = locais_fk
            for n, local in zip(nomes, locais):
                out[n] = (local, None)
                self._G(n, G, local)
        for n in self.extras:
            local = self._local_fk(n, p.get(n, ID))
            out[n] = (local, None)
            self._G(n, G, local)
        return out, G

    def _ik(self, nome, perna, alvo, G):
        n1, n2, n3 = perna["ossos"]
        pos_alvo, flexao = alvo
        Gp = G[self.pai[n1]]
        Qp = Gp.to_quaternion()
        J = Gp @ self.h[n1]
        a = (self.h[n2] - self.h[n1]).length
        b = (self.h[n3] - self.h[n2]).length
        pe_repouso = self.ponta[n3] - self.h[n3]
        pe = Quaternion(X, flexao) @ pe_repouso
        A_alvo = pos_alvo - pe
        d_vec = A_alvo - J
        d = max(abs(a - b) + 1e-4, min(a + b - 1e-4, d_vec.length))
        u = d_vec.normalized()
        polo = Qp @ perna["polo"]
        v = polo - u * polo.dot(u)
        v = v.normalized() if v.length > 1e-6 else Qp @ (FRENTE if perna["frente"] else -FRENTE)
        cos_al = (a * a + d * d - b * b) / (2 * a * d)
        sin_al = math.sqrt(max(0.0, 1 - cos_al * cos_al))
        K = J + a * (cos_al * u + sin_al * v)
        A = J + u * d
        locais = []
        Gcur = Gp
        for n, base, alvo_dir in ((n1, J, K - J), (n2, K, A - K), (n3, A, pe)):
            B0 = Gcur.to_quaternion() @ self.q[n]
            atual = B0 @ Y
            qw = atual.rotation_difference(alvo_dir)
            local = B0.inverted() @ qw @ B0
            locais.append(local)
            Gcur = Gcur @ self.rest[n] @ _m(local) @ self.rest[n].inverted()
        return locais

    def ponto(self, p, osso, ponto_repouso):
        """Onde um ponto do repouso preso a `osso` vai parar nessa pose."""
        _, G = self.pose(p)
        return G[osso] @ ponto_repouso

    # ---------------------------------------------------------------- gravar
    def aplicar(self, p):
        locais, _ = self.pose(p)
        for n, (q, loc) in locais.items():
            pb = self.arm.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = q
            if loc is not None:
                pb.location = loc
        bpy.context.view_layer.update()

    def gravar(self, nome, poses):
        arm = self.arm
        arm.animation_data_create()
        act = bpy.data.actions.new(nome)
        act.use_fake_user = True
        arm.animation_data.action = act
        anterior = {}
        for f, p in enumerate(poses):
            locais, _ = self.pose(p)
            for n, (q, loc) in locais.items():
                pb = arm.pose.bones[n]
                pb.rotation_mode = 'QUATERNION'
                if n in anterior and anterior[n].dot(q) < 0:
                    q = -q
                anterior[n] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
                if loc is not None:
                    pb.location = loc
                    pb.keyframe_insert("location", frame=f, group=n)
        trilha = arm.animation_data.nla_tracks.new()
        trilha.name = nome
        trilha.strips.new(nome, 0, act)
        # Mudas até exportar: trilha ativa sobrepõe qualquer pose aplicada à mão (fotos, assentar).
        trilha.mute = True
        arm.animation_data.action = None
        return act

    def repouso(self):
        for pb in self.arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = ID
            pb.location = Vector()
        bpy.context.view_layer.update()


# =============================================================== trajetória
def _passada(tau, beta, S, ergue, flexao):
    """Pata no ciclo: (avanço para a frente, altura, flexão). tau 0 = toca o chão."""
    tau %= 1.0
    if tau < beta:
        s = tau / beta
        # Fim do apoio: o talão sobe e o casco rola na pinça (acompanha a perna inclinada).
        return S * (0.5 - s), 0.0, 0.35 * flexao * suave((s - 0.7) / 0.3)
    s = (tau - beta) / (1.0 - beta)
    e = suave(s)
    return S * (-0.5 + e), ergue * math.sin(math.pi * s) ** 0.8, flexao * math.sin(math.pi * min(1.0, s * 1.15))


def _pes_no_chao(rig, desloc=None):
    desloc = desloc or {}
    return {n: (perna["chao"] + desloc.get(n, Vector()), 0.0) for n, perna in rig.pernas.items()}


def _cauda(rig, p, pitch, yaw, atraso=0.6, fase=0.0):
    """Cauda em onda: cada gomo segue o de cima com atraso. pitch + = ergue (a ponta vai
    para trás/para cima, seja a cauda pendurada, em pé ou horizontal)."""
    for i, n in enumerate(rig.cauda):
        k = 1.0 + 0.35 * i
        p[n] = rot(pitch=pitch(i) if callable(pitch) else pitch, yaw=(yaw(fase - atraso * i) if callable(yaw) else yaw) * k)


# ==================================================================== ações
def andar(rig, v, perfil):
    l = rig.ell
    T = min(1.5, max(0.55, 1.25 * l / v))
    N = max(12, round(T * FPS))
    D = v * N / FPS
    beta = min(0.64, 0.8 * l / D)
    S = beta * D
    fases = {"tras.L": 0.0, "frente.L": 0.25, "tras.R": 0.5, "frente.R": 0.75}
    flex = rad(38 if perfil.get("casco", True) else 30)
    poses = []
    for i in range(N + 1):
        u = i / N
        pes = {}
        for n, ph in fases.items():
            df, dz, fl = _passada(u - ph, beta, S, 0.11 * l, flex)
            pes[n] = (rig.pernas[n]["chao"] + FRENTE * df + Z * dz, fl)
        p = {"pes": pes,
             "raiz_loc": Z * (-0.02 * l - 0.012 * l * math.cos(4 * math.pi * u)),
             "tronco": rot(roll=rad(1.6) * math.sin(2 * math.pi * u), yaw=rad(1.5) * math.sin(2 * math.pi * u)),
             "pescoco": rot(pitch=rad(3.5) * math.sin(4 * math.pi * u + 1.0)),
             "cabeca": rot(pitch=-rad(2.0) * math.sin(4 * math.pi * u + 1.0))}
        _cauda(rig, p, 0.0, lambda f: rad(9) * math.sin(2 * math.pi * u + f))
        poses.append(p)
    return poses, {"loop": True, "velocidade": v, "quadros": N}


def correr(rig, v, perfil):
    l = rig.ell
    flexivel = not perfil.get("casco", True)
    T = min(0.75, max(0.3, 2.6 * l / v))
    N = max(9, round(T * FPS))
    D = v * N / FPS
    beta = min(0.38, 0.75 * l / D)
    S = beta * D
    fases = {"tras.L": 0.0, "tras.R": 0.1, "frente.L": 0.45, "frente.R": 0.55}
    if flexivel:            # galope rotatório dos cães e gatos
        fases = {"tras.L": 0.0, "tras.R": 0.1, "frente.R": 0.45, "frente.L": 0.55}
    flex = rad(55 if not flexivel else 45)
    dobra = rad(12 if flexivel else 4)
    poses = []
    for i in range(N + 1):
        u = i / N
        w = 2 * math.pi * u
        pes = {}
        for n, ph in fases.items():
            df, dz, fl = _passada(u - ph, beta, S, 0.19 * l, flex)
            pes[n] = (rig.pernas[n]["chao"] + FRENTE * df + Z * dz, fl)
        curvar = dobra * math.sin(w + math.pi / 2)
        p = {"pes": pes,
             "raiz_loc": Z * (-0.04 * l + 0.05 * l * math.sin(w - 0.6)),
             "tronco": rot(pitch=rad(6) * math.sin(w - 1.0)),
             "quadril": rot(pitch=-curvar),
             "peito": rot(pitch=curvar),
             "pescoco": rot(pitch=rad(-8) + rad(7) * math.sin(w + 2.0)),
             "cabeca": rot(pitch=rad(4) * math.sin(w + 2.4))}
        _cauda(rig, p, lambda k: rad(18) if k == 0 else rad(6), lambda f: rad(7) * math.sin(w + f))
        poses.append(p)
    return poses, {"loop": True, "velocidade": v, "quadros": N}


PASTAR_MAX = rad(62)          # além disso a malha do pescoço amassa (vaca, 02/10/2026)
CABECA_MAX = rad(78)          # cabeça no máximo assim abaixo da horizontal (passou: aponta p/ trás)


def _inclinacao(rig, osso):
    """Ângulo (rad) do osso abaixo da horizontal, no repouso."""
    d = rig.ponta[osso] - rig.h[osso]
    return math.atan2(-d.z, max(1e-6, -d.y))


def _pose_de_pastar(rig, a):
    """Pescoço baixa `a`, tronco `rig.inclina` × a (ave bica inclinando o corpo todo: 0,4);
    a cabeça completa até CABECA_MAX abaixo da horizontal."""
    tronco = rig.inclina * a
    cab = CABECA_MAX - (_inclinacao(rig, "cabeca") + a + tronco)
    return {"tronco": rot(pitch=tronco), "pescoco": rot(pitch=a), "cabeca": rot(pitch=min(cab, rad(25)))}


def _angulo_de_pastar(rig, base):
    """Quanto baixar o pescoço para o focinho chegar perto do chão (busca binária, teto
    PASTAR_MAX: bicho de pescoço curto pasta com o focinho no capim alto em vez de dobrar a
    malha)."""
    alvo = rig.z0 + 0.06 * rig.H
    focinho = rig.ponta["cabeca"]
    lo, hi = 0.0, PASTAR_MAX
    for _ in range(18):
        mid = (lo + hi) / 2
        p = dict(base)
        p.update(_pose_de_pastar(rig, mid))
        if rig.ponto(p, "cabeca", focinho).z > alvo:
            lo = mid
        else:
            hi = mid
    return lo


def parado(rig, perfil):
    dur = 6.0
    N = round(dur * FPS)
    pastar = perfil.get("parado") == "pastar"
    abana = perfil.get("abana", False)
    base = {"pes": _pes_no_chao(rig)}
    ang = _angulo_de_pastar(rig, base) if pastar else rad(32)
    if pastar:
        baixa = [(0, 0), (2.3, 0), (3.1, 1), (4.7, 1), (5.5, 0), (6, 0)]
        olha = [(0, 0), (0.5, rad(16)), (1.4, rad(16)), (2.1, -rad(8)), (2.6, 0), (5.6, 0), (6, 0)]
    else:
        baixa = [(0, 0), (1.6, 0), (2.2, 0.85), (3.4, 0.85), (4.0, 0), (6, 0)]
        olha = [(0, 0), (0.6, rad(22)), (1.4, rad(22)), (2.0, 0), (4.2, 0), (4.8, -rad(20)), (5.6, -rad(20)), (6, 0)]
    poses = []
    for i in range(N + 1):
        t = i / FPS
        k = curva(t, baixa)
        mastiga = math.sin(t * 2 * math.pi * (3.0 if pastar else 4.0)) * k * rad(3 if pastar else 4)
        pose_baixa = _pose_de_pastar(rig, ang * k) if pastar else {
            "tronco": rot(pitch=0.08 * ang * k), "pescoco": rot(pitch=ang * k), "cabeca": rot(pitch=0.3 * ang * k)}
        p = {"pes": _pes_no_chao(rig),
             "raiz_loc": Z * (0.004 * rig.H * math.sin(2 * math.pi * t / 3.0)),
             "tronco": pose_baixa["tronco"],
             "peito": rot(pitch=rad(0.8) * math.sin(2 * math.pi * t / 3.0)),
             "pescoco": rot(yaw=curva(t, olha)) @ pose_baixa["pescoco"] @ rot(pitch=mastiga),
             "cabeca": rot(yaw=0.5 * curva(t, olha)) @ pose_baixa["cabeca"]}
        if abana:
            _cauda(rig, p, 0.0, lambda f: rad(22) * math.sin(2 * math.pi * t * 2.0 + f), atraso=0.9)
        else:
            _cauda(rig, p, 0.0, lambda f: rad(12) * math.sin(2 * math.pi * t / 2.0 + f))
        poses.append(p)
    return poses, {"loop": True, "quadros": N}


def dano(rig, perfil):
    dur = 0.5
    N = round(dur * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        k = 1 - (1 - t / 0.07) ** 2 if t < 0.07 else 0.5 * (1 + math.cos(math.pi * min(1.0, (t - 0.07) / 0.43)))
        p = {"pes": _pes_no_chao(rig),
             "raiz_loc": Y * 0.045 * rig.L * rig.alcance * k + Z * 0.015 * rig.H * k,
             "tronco": rot(pitch=-rad(6) * k, roll=rad(4) * k),
             "pescoco": rot(pitch=-rad(15) * k, yaw=rad(7) * k),
             "cabeca": rot(pitch=-rad(10) * k, yaw=rad(6) * k)}
        # Tranco curto: a cauda pendurada é colada na anca (cavalo, raposa, corgi) e 18°
        # esticavam as faces da colagem.
        _cauda(rig, p, rad(8) * k, 0.0)
        poses.append(p)
    return poses, {"loop": False, "quadros": N}


def _atacar_cabecada(rig, t):
    # prepara (0–0,35): recua e baixa a cabeça; golpe (0,35–0,5): avança e joga a cabeça para
    # cima; volta (0,5–0,9).
    recua = curva(t, [(0, 0), (0.35, 1), (0.42, -1.6), (0.55, -1.6), (0.9, 0)])
    cab = curva(t, [(0, 0), (0.35, 1), (0.47, -0.6), (0.6, -0.6), (0.9, 0)])
    return {"pes": _pes_no_chao(rig),
            "raiz_loc": Y * 0.06 * rig.L * rig.alcance * recua + Z * (-0.03 * rig.H * abs(recua)),
            "tronco": rot(pitch=rad(5) * max(cab, 0)),
            "pescoco": rot(pitch=rad(32) * cab),
            "cabeca": rot(pitch=rad(18) * cab)}


def _atacar_mordida(rig, t):
    agacha = curva(t, [(0, 0), (0.28, 1), (0.36, -1.4), (0.48, -1.4), (0.75, 0)])
    boca = curva(t, [(0, 0), (0.28, -1), (0.36, 1), (0.46, 1), (0.75, 0)])
    return {"pes": _pes_no_chao(rig),
            "raiz_loc": Y * 0.07 * rig.L * rig.alcance * agacha + Z * (-0.05 * rig.H * max(agacha, 0)),
            "tronco": rot(pitch=rad(5) * agacha),
            "pescoco": rot(pitch=rad(10) * agacha - rad(6) * max(-agacha, 0)),
            "cabeca": rot(pitch=rad(16) * boca)}


def _atacar_patada(rig, t):
    p = _atacar_mordida(rig, t)
    l = rig.ell
    sobe = curva(t, [(0, 0), (0.25, 1), (0.4, 0.15), (0.55, 0.15), (0.8, 0)])
    vai = curva(t, [(0, 0), (0.25, -0.3), (0.4, 1), (0.55, 1), (0.8, 0)])
    pes = p["pes"]
    alvo = rig.pernas["frente.R"]["chao"] + Z * (0.45 * l * sobe) + FRENTE * (0.35 * l * vai)
    pes["frente.R"] = (alvo, rad(50) * sobe)
    return p


def _atacar_empinar(rig, t, altura=40):
    l = rig.ell
    ergue = curva(t, [(0, 0), (0.4, 1), (0.62, 1), (0.78, -0.12), (0.95, -0.12), (1.2, 0)])
    pedala = math.sin(2 * math.pi * 3.2 * t) * min(1.0, max(0.0, (t - 0.15) / 0.2)) * (1 if t < 0.66 else 0)
    # Empina em volta da anca: o tronco gira em C e a raiz compensa a translação.
    pivo = (rig.h["perna_tras_1.L"] + rig.h["perna_tras_1.R"]) / 2
    pivo.x = 0.0
    R = rot(pitch=-rad(altura) * max(ergue, 0) + rad(6) * max(-ergue, 0))
    C = rig.h["tronco"]
    desloc = (pivo - C) - R @ (pivo - C)
    no_ar = curva(t, [(0, 0), (0.12, 1), (0.66, 1), (0.78, 0)])
    pes = _pes_no_chao(rig, {n: FRENTE * 0.18 * l * curva(t, [(0, 0), (0.7, 0), (0.78, 1), (0.95, 1), (1.2, 0)])
                             for n in ("frente.L", "frente.R")})
    fk = {}
    mistura = {}
    for n in ("frente.L", "frente.R"):
        lado = 1 if n.endswith("L") else -1
        fk[n] = [rot(pitch=-rad(35) - rad(25) * pedala * lado), rot(pitch=rad(70) + rad(15) * pedala * lado), rot(pitch=rad(30))]
        mistura[n] = no_ar
    return {"pes": pes, "fk": fk, "mistura_fk": mistura,
            "raiz_loc": desloc,
            "tronco": R,
            "pescoco": rot(pitch=rad(14) * max(ergue, 0) - rad(10) * max(-ergue, 0) * 3),
            "cabeca": rot(pitch=-rad(10) * max(ergue, 0))}


def atacar(rig, perfil):
    estilo = perfil.get("ataque", "cabecada")
    dur = {"cabecada": 0.9, "mordida": 0.75, "patada": 0.8, "empinar": 1.2, "bicada": 0.6, "bote": 0.8}[estilo]
    N = round(dur * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        if estilo == "cabecada":
            p = _atacar_cabecada(rig, t)
        elif estilo == "mordida":
            p = _atacar_mordida(rig, t)
        elif estilo == "patada":
            p = _atacar_patada(rig, t)
        elif estilo == "bicada":
            p = _atacar_bicada(rig, t)
        elif estilo == "bote":
            p = _atacar_bote(rig, t, perfil.get("bote_patas", True))
        else:
            p = _atacar_empinar(rig, t, perfil.get("empina", 40))
        _cauda(rig, p, rad(8) * suave(t / 0.3) * (1 - suave((t - dur + 0.3) / 0.3)), 0.0)
        poses.append(p)
    golpe = {"cabecada": 0.42, "mordida": 0.36, "patada": 0.4, "empinar": 0.78, "bicada": 0.28, "bote": 0.44}[estilo]
    return poses, {"loop": False, "quadros": N, "golpe": golpe}


def morrer(rig, perfil):
    dur = 1.4
    N = round(dur * FPS)
    l = rig.ell
    poses = []
    for i in range(N + 1):
        t = i / FPS
        cede = curva(t, [(0, 0), (0.35, 1)])
        tomba = curva(t, [(0.3, 0), (0.85, 1.06), (1.05, 0.97), (1.25, 1.0)])
        solta = curva(t, [(0.3, 0), (0.75, 1)])
        fk, mistura = {}, {}
        for n, perna in rig.pernas.items():
            frente = perna["frente"]
            fk[n] = [rot(pitch=-rad(18) if frente else rad(14)), rot(pitch=rad(12) if frente else -rad(8)), rot(pitch=rad(25))]
            mistura[n] = solta
        p = {"pes": _pes_no_chao(rig), "fk": fk, "mistura_fk": mistura,
             "raiz_rot": Quaternion(Y, rad(82) * tomba),
             "raiz_loc": Z * (-0.28 * l * cede),
             "tronco": rot(pitch=rad(7) * cede * (1 - tomba)),
             "pescoco": rot(pitch=rad(12) * cede, yaw=rad(30) * tomba),
             "cabeca": rot(pitch=rad(10) * cede, yaw=rad(18) * tomba)}
        _cauda(rig, p, rad(10) * tomba, rad(12) * tomba)
        poses.append(p)
    return poses, {"loop": False, "quadros": N, "assentar_desde": round(0.85 * FPS)}


# ==================================================================== saltadores
def saltar(rig, v, perfil, correndo=False):
    """Um salto por ciclo: as patas de trás (juntas) empurram, o corpo voa em arco e
    arqueia, a frente aterrissa primeiro e a traseira passa à frente dela."""
    l = rig.ell
    T = min(0.7, max(0.3, (3.0 if correndo else 2.2) * l / v))
    N = max(9, round(T * FPS))
    D = v * N / FPS
    S_tras = min(0.9 * l, 0.45 * D)
    S_frente = min(0.7 * l, 0.3 * D)
    # (fase em que toca o chão, fração no chão, avanço no apoio)
    patas = {"tras.L": (0.75, 0.45, S_tras), "tras.R": (0.77, 0.45, S_tras),
             "frente.L": (0.55, 0.32, S_frente), "frente.R": (0.58, 0.32, S_frente)}
    pulo = (0.55 if correndo else 0.35) * l
    poses = []
    for i in range(N + 1):
        u = i / N
        pes = {}
        for n, (ph, beta, S) in patas.items():
            df, dz, fl = _passada(u - ph, beta, S, 0.18 * l, rad(35))
            pes[n] = (rig.pernas[n]["chao"] + FRENTE * df + Z * dz, fl)
        # No ar entre 0,15 e 0,6; agacha ao aterrissar (0,6–0,9).
        voo = math.sin(math.pi * min(1.0, max(0.0, (u - 0.12) / 0.48)))
        agacha = math.sin(math.pi * min(1.0, max(0.0, (u - 0.6) / 0.35)))
        arco = math.sin(2 * math.pi * (u - 0.1))
        p = {"pes": pes,
             "raiz_loc": Z * (pulo * voo - 0.12 * l * agacha),
             "tronco": rot(pitch=-rad(10) * arco),
             "quadril": rot(pitch=rad(12) * agacha - rad(8) * voo),
             "peito": rot(pitch=-rad(8) * agacha + rad(4) * voo),
             "pescoco": rot(pitch=rad(8) * arco),
             "cabeca": rot(pitch=-rad(4) * arco)}
        _cauda(rig, p, rad(10) * voo, 0.0)
        poses.append(p)
    return poses, {"loop": True, "velocidade": v, "quadros": N}


# ==================================================================== rastejante
def rastejar(rig, v, perfil, correndo=False):
    """Lagarto: patas em diagonal (frente E com trás D) e a coluna ondulando para os lados
    em S — quadril e peito giram em sentidos opostos, a cauda segue a onda com atraso e a
    cabeça compensa para continuar olhando para a frente."""
    l = rig.ell
    T = min(1.0, max(0.3, (1.6 if correndo else 1.2) * rig.L * 0.35 / v))
    N = max(9, round(T * FPS))
    D = v * N / FPS
    beta = min(0.45 if correndo else 0.6, 1.2 * l / D)
    S = beta * D
    fases = {"frente.L": 0.0, "tras.R": 0.0, "frente.R": 0.5, "tras.L": 0.5}
    onda = rad(14 if correndo else 10)
    poses = []
    for i in range(N + 1):
        u = i / N
        w = 2 * math.pi * u
        pes = {}
        for n, ph in fases.items():
            df, dz, fl = _passada(u - ph, beta, S, 0.35 * l, rad(20))
            pes[n] = (rig.pernas[n]["chao"] + FRENTE * df + Z * dz, fl)
        p = {"pes": pes,
             "raiz_loc": Z * (0.06 * l * abs(math.sin(w))),
             "quadril": rot(yaw=onda * math.sin(w)),
             "peito": rot(yaw=-onda * math.sin(w)),
             "cabeca": rot(yaw=0.8 * onda * math.sin(w))}
        _cauda(rig, p, 0.0, lambda f: 1.3 * onda * math.sin(w + f), atraso=1.1)
        poses.append(p)
    return poses, {"loop": True, "velocidade": v, "quadros": N}


def parado_rastejante(rig, perfil):
    """Parado ao sol: olha de lado, duas 'flexões' (exibição de lagarto), cauda balança."""
    dur = 6.0
    N = round(dur * FPS)
    l = rig.ell
    flexao = [(0, 0), (2.0, 0), (2.25, 1), (2.5, 0), (2.75, 1), (3.0, 0), (6, 0)]
    olha = [(0, 0), (0.8, rad(25)), (1.6, rad(25)), (1.9, 0), (4.0, 0), (4.6, -rad(20)), (5.4, -rad(20)), (6, 0)]
    poses = []
    for i in range(N + 1):
        t = i / FPS
        k = curva(t, flexao)
        p = {"pes": _pes_no_chao(rig),
             "raiz_loc": Z * (0.25 * l * k + 0.004 * rig.H * math.sin(2 * math.pi * t / 2.0)),
             "tronco": rot(pitch=-rad(8) * k),
             "pescoco": rot(yaw=curva(t, olha)),
             "cabeca": rot(yaw=0.5 * curva(t, olha), pitch=-rad(10) * k)}
        _cauda(rig, p, 0.0, lambda f: rad(8) * math.sin(2 * math.pi * t / 3.0 + f), atraso=0.8)
        poses.append(p)
    return poses, {"loop": True, "quadros": N}


# ==================================================================== aves de chão
def andar_ave(rig, v, perfil, correndo=False):
    """Bípede: pernas alternadas; bamboleia (rola o corpo) e balança a cabeça 2x por ciclo.
    Correndo: inclina para a frente, pescoço esticado, passo curto e rápido."""
    l = rig.ell
    if correndo:
        T = min(0.5, max(0.25, 1.6 * l / v))
    else:
        T = min(1.2, max(0.35, 1.1 * l / v))
    N = max(8, round(T * FPS))
    D = v * N / FPS
    beta = min(0.4 if correndo else 0.62, 0.8 * l / D)
    S = beta * D
    fases = {"tras.L": 0.0, "tras.R": 0.5}
    bamboleio = rad(perfil.get("bamboleio", 5)) * (0.6 if correndo else 1.0)
    poses = []
    for i in range(N + 1):
        u = i / N
        w = 2 * math.pi * u
        pes = {}
        for n, ph in fases.items():
            df, dz, fl = _passada(u - ph, beta, S, (0.22 if correndo else 0.16) * l, rad(40))
            pes[n] = (rig.pernas[n]["chao"] + FRENTE * df + Z * dz, fl)
        inclina = rad(14) if correndo else 0.0
        p = {"pes": pes,
             "raiz_loc": Z * (-0.03 * l - 0.03 * l * abs(math.cos(w))),
             "tronco": rot(pitch=inclina, roll=bamboleio * math.sin(w), yaw=0.5 * bamboleio * math.sin(w)),
             "pescoco": rot(pitch=(rad(22) if correndo else 0.0) + rad(7) * math.sin(2 * w)),
             "cabeca": rot(pitch=-rad(5) * math.sin(2 * w) - (rad(10) if correndo else 0.0))}
        _cauda(rig, p, rad(6) * math.sin(2 * w), 0.0)
        poses.append(p)
    return poses, {"loop": True, "velocidade": v, "quadros": N}


def parado_ave(rig, perfil):
    """Olha em volta com estalos de cabeça (ave não gira a cabeça devagar) e bica o chão."""
    dur = 6.0
    N = round(dur * FPS)
    ang = _angulo_de_pastar(rig, {"pes": _pes_no_chao(rig)})
    olha = [(0, 0), (0.6, 0), (0.7, rad(28)), (1.4, rad(28)), (1.5, -rad(18)), (2.1, -rad(18)), (2.2, 0),
            (4.6, 0), (4.7, rad(20)), (5.3, rad(20)), (5.4, 0), (6, 0)]
    bicadas = [2.5, 3.1, 3.7]
    poses = []
    for i in range(N + 1):
        t = i / FPS
        k = 0.0
        for b in bicadas:
            if b <= t < b + 0.45:
                x = (t - b) / 0.45
                k = suave(x / 0.35) if x < 0.35 else (1.0 if x < 0.5 else 1 - suave((x - 0.5) / 0.5))
        pose_baixa = _pose_de_pastar(rig, ang * k)
        p = {"pes": _pes_no_chao(rig),
             "raiz_loc": Z * (0.004 * rig.H * math.sin(2 * math.pi * t / 1.5)),
             "tronco": pose_baixa["tronco"],
             "pescoco": rot(yaw=curva(t, olha)) @ pose_baixa["pescoco"],
             "cabeca": rot(yaw=0.4 * curva(t, olha)) @ pose_baixa["cabeca"]}
        _cauda(rig, p, rad(5) * math.sin(2 * math.pi * t / 1.5), 0.0)
        poses.append(p)
    return poses, {"loop": True, "quadros": N}


def _atacar_bote(rig, t, patas_no_ar=True):
    """Saltador: agacha, pula para a frente com as patas da frente esticadas e morde ao
    aterrissar (erguer o pescoço curto levava o peito junto — coelho virava lhama).
    `patas_no_ar` False (sapo: os dedos da frente e de trás são a mesma malha): a frente
    fica plantada e o bote é só do corpo."""
    l = rig.ell
    agacha = curva(t, [(0, 0), (0.2, 1), (0.28, 0), (0.8, 0)])
    pulo = curva(t, [(0.18, 0), (0.32, 1), (0.42, 0), (0.8, 0)])
    vai = curva(t, [(0.18, 0), (0.4, 1), (0.55, 1), (0.8, 0)])
    morde = curva(t, [(0.36, 0), (0.44, 1), (0.55, 1), (0.7, 0)])
    fk, mistura = {}, {}
    for n in ("frente.L", "frente.R"):
        fk[n] = [rot(pitch=-rad(40)), rot(pitch=rad(20)), rot(pitch=rad(20))]
        mistura[n] = pulo if patas_no_ar else 0.0
    alcance = 0.12 if patas_no_ar else 0.05
    return {"pes": _pes_no_chao(rig), "fk": fk, "mistura_fk": mistura,
            "raiz_loc": -Y * alcance * rig.L * rig.alcance * vai + Z * ((0.3 if patas_no_ar else 0.12) * l * pulo - 0.15 * l * agacha),
            "tronco": rot(pitch=rad(6) * agacha - rad(12) * pulo + rad(6) * morde),
            "pescoco": rot(pitch=rad(8) * morde),
            "cabeca": rot(pitch=rad(16) * morde)}


def _atacar_bicada(rig, t):
    recua = curva(t, [(0, 0), (0.22, 1), (0.28, -1), (0.38, -1), (0.6, 0)])
    return {"pes": _pes_no_chao(rig),
            "raiz_loc": Y * 0.05 * rig.L * rig.alcance * recua,
            "tronco": rot(pitch=rad(10) * max(-recua, 0)),
            "pescoco": rot(pitch=rad(30) * max(-recua, 0) - rad(22) * max(recua, 0)),
            "cabeca": rot(pitch=rad(18) * max(-recua, 0) - rad(10) * max(recua, 0))}


# ======================================================================= voadores
def _asa(lado, sobe=0.0, recua=0.0):
    """Asa em eixos do repouso: `sobe` (rad) ergue a ponta, `recua` leva a ponta para trás."""
    s_ = 1.0 if lado == ".L" else -1.0
    return rot(roll=-s_ * sobe, yaw=s_ * recua)


def _asas(p, sobe1, recua1, sobe2, recua2):
    for lado in (".L", ".R"):
        p["asa_1" + lado] = _asa(lado, sobe1, recua1)
        p["asa_2" + lado] = _asa(lado, sobe2, recua2)


def _batida(w, amplitude=1.0):
    """Uma batida de asa na fase w: sobe mais alto (55°) do que desce (35°), a ponta atrasa
    e a asa recolhe para trás na subida (menos arrasto)."""
    b = math.sin(w)
    subindo = max(0.0, math.cos(w))
    return (rad(10) + rad(45) * b * amplitude, rad(16) * subindo * amplitude,
            rad(28) * math.sin(w - 0.9) * amplitude, rad(12) * subindo * amplitude)


def voar(rig, perfil):
    T = perfil.get("batida", 0.3)
    N = max(8, round(T * FPS))
    poses = []
    for i in range(N + 1):
        u = i / N
        w = 2 * math.pi * u
        p = {"raiz_loc": Z * (-0.12 * rig.H * math.cos(w)),
             "tronco": rot(pitch=rad(3) * math.sin(w)),
             "cabeca": rot(pitch=-rad(3) * math.sin(w))}
        _asas(p, *_batida(w))
        _cauda(rig, p, rad(5) * math.sin(w + 1.0), 0.0)
        poses.append(p)
    return poses, {"loop": True, "quadros": N}


def planar(rig, perfil):
    """Plana: asas abertas com leve diedro, corpo balança; duas batidas no meio do ciclo."""
    dur = 3.0
    N = round(dur * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        p = {"raiz_loc": Z * (0.05 * rig.H * math.sin(2 * math.pi * t / dur)),
             "tronco": rot(roll=rad(5) * math.sin(2 * math.pi * t / dur), pitch=rad(2) * math.sin(4 * math.pi * t / dur))}
        if 1.6 <= t <= 2.2:
            _asas(p, *_batida(2 * math.pi * (t - 1.6) / 0.3, 0.8))
        else:
            _asas(p, rad(8) + rad(3) * math.sin(2 * math.pi * t / dur), 0.0, rad(4), 0.0)
        _cauda(rig, p, 0.0, lambda f: rad(6) * math.sin(2 * math.pi * t / dur + f))
        poses.append(p)
    return poses, {"loop": True, "quadros": N}


def dano_voador(rig, perfil):
    N = round(0.5 * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        k = 1 - (1 - t / 0.07) ** 2 if t < 0.07 else 0.5 * (1 + math.cos(math.pi * min(1.0, (t - 0.07) / 0.43)))
        p = {"raiz_loc": Y * 0.15 * rig.L * k + Z * 0.2 * rig.H * k,
             "tronco": rot(pitch=-rad(18) * k, roll=rad(12) * k),
             "cabeca": rot(pitch=-rad(15) * k)}
        _asas(p, rad(10) + rad(50) * k, rad(20) * k, rad(20) * k, 0.0)
        _cauda(rig, p, rad(20) * k, 0.0)
        poses.append(p)
    return poses, {"loop": False, "quadros": N}


def atacar_voador(rig, perfil):
    """Mergulho: recolhe as asas e aponta o bico; no golpe abre as asas para frear; volta
    batendo."""
    dur = 0.9
    N = round(dur * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        mergulho = curva(t, [(0, 0), (0.35, 1), (0.45, 0.2), (0.6, 0)])
        freia = curva(t, [(0.35, 0), (0.45, 1), (0.6, 0)])
        p = {"raiz_loc": -Y * 0.3 * rig.L * mergulho + Z * (-0.4 * rig.H * mergulho),
             "tronco": rot(pitch=rad(30) * mergulho - rad(20) * freia),
             "cabeca": rot(pitch=rad(15) * freia)}
        if t > 0.6:
            _asas(p, *_batida(2 * math.pi * (t - 0.6) / 0.3))
        else:
            _asas(p, rad(20) * mergulho - rad(10) * freia + rad(10), rad(45) * mergulho, rad(15) * mergulho, rad(15) * mergulho)
        _cauda(rig, p, rad(15) * freia, 0.0)
        poses.append(p)
    return poses, {"loop": False, "quadros": N, "golpe": 0.42}


def morrer_voador(rig, perfil):
    """Acertado no ar: asas sobem num tranco, dobram, e o corpo tomba de lado até o chão."""
    dur = 1.4
    N = round(dur * FPS)
    poses = []
    for i in range(N + 1):
        t = i / FPS
        tranco = curva(t, [(0, 0), (0.1, 1), (0.3, 0)])
        dobra = curva(t, [(0.2, 0), (0.8, 1)])
        tomba = curva(t, [(0.3, 0), (0.9, 1.05), (1.1, 1.0)])
        p = {"raiz_rot": Quaternion(Y, rad(100) * tomba) @ Quaternion(X, rad(15) * tomba),
             "tronco": rot(pitch=-rad(15) * tranco),
             "pescoco": rot(pitch=rad(25) * dobra),
             "cabeca": rot(pitch=rad(20) * dobra, yaw=rad(25) * dobra)}
        _asas(p, rad(50) * tranco - rad(25) * dobra + rad(10), rad(35) * dobra, -rad(20) * dobra, rad(25) * dobra)
        _cauda(rig, p, -rad(10) * dobra, 0.0)
        poses.append(p)
    return poses, {"loop": False, "quadros": N, "assentar_desde": round(0.9 * FPS)}


def assentar(rig, obj, poses, desde):
    """Nenhum vértice abaixo do chão; a partir de `desde`, o mais baixo fica NO chão."""
    dg = bpy.context.evaluated_depsgraph_get()
    for i, p in enumerate(poses):
        rig.aplicar(p)
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
        menor = min(v.co.z for v in me.vertices)
        ev.to_mesh_clear()
        falta = rig.z0 - menor
        if falta > 0 or i >= desde:
            p["raiz_loc"] = p.get("raiz_loc", Vector()) + Z * falta
    rig.repouso()


def todas(rig, obj, perfil, v_andar, v_correr):
    """{nome: (poses, info)} na ordem de exportação."""
    corpo = perfil.get("corpo", "quadrupede")
    if corpo == "voador":
        # Voador vive no ar (o jogo usa voando/planando): fly no lugar de walk/run.
        clipes = {"idle": planar(rig, perfil), "fly": voar(rig, perfil), "damage": dano_voador(rig, perfil),
                  "attack": atacar_voador(rig, perfil), "death": morrer_voador(rig, perfil)}
        assentar(rig, obj, clipes["death"][0], clipes["death"][1]["assentar_desde"])
        return clipes
    if corpo == "ave":
        idle, walk, run = parado_ave(rig, perfil), andar_ave(rig, v_andar, perfil), andar_ave(rig, v_correr, perfil, True)
    elif corpo == "rastejante":
        idle, walk, run = parado_rastejante(rig, perfil), rastejar(rig, v_andar, perfil), rastejar(rig, v_correr, perfil, True)
    elif corpo == "saltador":
        idle, walk, run = parado(rig, perfil), saltar(rig, v_andar, perfil), saltar(rig, v_correr, perfil, True)
    else:
        idle, walk, run = parado(rig, perfil), andar(rig, v_andar, perfil), correr(rig, v_correr, perfil)
    clipes = {
        "idle": idle,
        "walk": walk,
        "run": run,
        "damage": dano(rig, perfil),
        "attack": atacar(rig, perfil),
        "death": morrer(rig, perfil),
    }
    assentar(rig, obj, clipes["death"][0], clipes["death"][1]["assentar_desde"])
    if perfil.get("ataque") == "empinar":
        assentar(rig, obj, clipes["attack"][0], 10 ** 6)
    return clipes
