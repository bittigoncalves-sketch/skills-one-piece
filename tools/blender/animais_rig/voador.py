"""Voador (pardal, andorinha): modelo em pose de voo, asas abertas em X.

  * MEIA-LARGURA DO CORPO: cortes perpendiculares a X a partir do meio; onde a espessura
    (altura do contorno) cai abaixo de 40 % da do centro começa a asa (a asa é chapada).
  * ASA: os cortes em X dali até a ponta — o centro de todos os contornos do corte (as
    penas são contornos soltos) dá a linha do ombro à ponta; cotovelo a 45 % da envergadura.
  * COLUNA: cortes em Y no meio (só o que está dentro da largura do corpo): traseira do
    corpo = onde a espessura sobe (a cauda é um leque fino), cabeça = a frente, bico = o
    vértice mais à frente.

Esqueleto: raiz, tronco, quadril -> cauda_1 -> cauda_2, peito -> pescoco -> cabeca e
asa_1/asa_2 de cada lado. Pesos por região: asa pela posição ao longo da envergadura,
cauda atrás do corpo, cadeia do corpo por planos nas juntas (como o quadrúpede).
"""
import bmesh
from mathutils import Vector

from .geometria import fatiar, caixa
from .quadrupede import UP, _f, _mistura, suavizar, gravar_pesos

X = Vector((1, 0, 0))


def analisar(obj, perfil):
    lo, hi = caixa(obj)
    H = hi.z - lo.z
    L = hi.y - lo.y
    W = max(hi.x, -lo.x)
    z0 = lo.z
    fmin, fmax = -hi.y, -lo.y
    verts = [v.co.copy() for v in obj.data.vertices]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    m = {"H": H, "L": L, "W": W, "z0": z0, "fmin": fmin, "fmax": fmax, "pernas": {}}

    def corte_x(x):
        return fatiar(bm, Vector((x, 0, 0)), X)

    centro = max(corte_x(1e-4), key=lambda k: k.perimetro)
    espessura0 = centro.ext.z
    meia = W
    for i in range(1, 50):
        x = W * i / 50
        cs = corte_x(x)
        if not cs or max(cs, key=lambda k: k.perimetro).ext.z < 0.4 * espessura0:
            meia = x
            break
    m["meia_largura"] = meia

    # ---------------------------------------------------------------- asas
    asas = {}
    for lado, sinal in ((".L", 1.0), (".R", -1.0)):
        linha = []
        for i in range(0, 41):
            x = meia + (W - meia) * i / 40 * 0.98
            cs = corte_x(sinal * x)
            if not cs:
                continue
            soma, tot = Vector(), 0.0
            for k in cs:
                soma += k.centro * k.perimetro
                tot += k.perimetro
            linha.append(soma / tot)
        if len(linha) < 3:
            raise RuntimeError("asa %s: só %d cortes" % (lado, len(linha)))
        ombro, ponta = linha[0], linha[-1]
        cot = min(linha, key=lambda p: abs(abs(p.x) - (abs(ombro.x) + 0.45 * (abs(ponta.x) - abs(ombro.x)))))
        # Faixa de comprimento (f) onde a asa existe: fora dela, largo não é asa (cabeça).
        fs = [_f(a) for x in (meia * 1.05, (meia + W) * 0.5) for k in corte_x(sinal * x) for seg in k.segmentos for a in seg]
        asas[lado] = {"ombro": Vector((sinal * meia * 0.6, ombro.y, ombro.z)), "cotovelo": cot, "ponta": ponta,
                      "linha": linha, "f": (min(fs) - 0.03 * L, max(fs) + 0.03 * L)}
    m["asas"] = asas

    # -------------------------------------------------------------- coluna
    amostras = []
    for i in range(41):
        f = fmin + L * (0.005 + 0.99 * i / 40)
        cs = fatiar(bm, Vector((0, -f, 0)), Vector((0, 1, 0)))
        pts = [a for k in cs for seg in k.segmentos for a in seg if abs(a.x) < meia * 1.1]
        if pts:
            zs = [p.z for p in pts]
            amostras.append((f, 0.5 * (min(zs) + max(zs)), max(zs) - min(zs)))
    esp = max(a[2] for a in amostras)
    corpo = [a for a in amostras if a[2] > 0.45 * esp]
    f_tras = corpo[0][0]

    def z_em(f):
        return min(amostras, key=lambda a: abs(a[0] - f))[1]

    f_ombro = -0.5 * (asas[".L"]["ombro"].y + asas[".R"]["ombro"].y)
    f_c = f_ombro - perfil.get("centro_atras", 0.06) * L
    f_hj = fmax - perfil.get("cabeca", 0.22) * L
    f_nb = f_ombro + 0.85 * (f_hj - f_ombro)     # pescoço curto: o ombro e o bordo da asa ficam no peito
    m["C"] = Vector((0, -f_c, z_em(f_c)))
    f_tras = min(f_tras, f_c - 0.08 * L)        # corpo curto (pardal): a anca fica atrás do centro
    m["R"] = Vector((0, -f_tras, z_em(f_tras)))
    m["Nb"] = Vector((0, -f_nb, z_em(f_nb)))
    m["Hj"] = Vector((0, -f_hj, z_em(f_hj)))
    bico = max(verts, key=_f)
    m["N"] = Vector((0, bico.y, bico.z))
    rabo = min(verts, key=_f)
    f_meio = 0.5 * (f_tras + _f(rabo))
    m["cauda"] = [m["R"], Vector((0, -f_meio, z_em(f_meio))), Vector((0, rabo.y, rabo.z))]
    bm.free()
    return m


def montar_esqueleto(m, nome="Armature"):
    import bpy
    arm_data = bpy.data.armatures.new(nome)
    arm = bpy.data.objects.new(nome, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    H, z0 = m["H"], m["z0"]

    def osso(n, a, b, pai=None, liga=False):
        o = eb.new(n)
        o.head, o.tail = a, b
        if (b - a).length < 1e-4:
            o.tail = a + UP * 0.05 * H
        if pai:
            o.parent = eb[pai]
            o.use_connect = liga
        return o

    C = m["C"]
    osso("raiz", Vector((C.x, C.y, z0)), Vector((C.x, C.y, z0 + 0.3 * H)))
    osso("tronco", C, C + UP * 0.2 * H, "raiz")
    osso("quadril", C, m["R"], "tronco")
    osso("cauda_1", m["cauda"][0], m["cauda"][1], "quadril")
    osso("cauda_2", m["cauda"][1], m["cauda"][2], "cauda_1", True)
    osso("peito", C, m["Nb"], "tronco")
    osso("pescoco", m["Nb"], m["Hj"], "peito", True)
    osso("cabeca", m["Hj"], m["N"], "pescoco", True)
    for lado, a in m["asas"].items():
        osso("asa_1" + lado, a["ombro"], a["cotovelo"], "peito")
        osso("asa_2" + lado, a["cotovelo"], a["ponta"], "asa_1" + lado, True)
    bpy.ops.object.mode_set(mode='OBJECT')
    for n in ("raiz", "tronco"):
        arm_data.bones[n].use_deform = False
    return arm


def pesar(obj, arm, m):
    H, L = m["H"], m["L"]
    meia = m["meia_largura"]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    cadeia = [m["R"], m["C"], m["Nb"], m["Hj"], m["N"]]
    juntas = []
    for i in (1, 2, 3):
        d1 = (cadeia[i] - cadeia[i - 1]).normalized()
        d2 = (cadeia[i + 1] - cadeia[i]).normalized()
        juntas.append((cadeia[i], (d1 + d2).normalized()))
    larguras = [0.2 * L, 0.08 * L, 0.04 * L]
    ossos = ["quadril", "peito", "pescoco", "cabeca"]
    f_tras = _f(m["R"])
    f_ponta = _f(m["cauda"][2])
    pesos = []
    for v in bm.verts:
        co = v.co
        w = {}
        pos = [_mistura((co - j).dot(nrm), lg) for (j, nrm), lg in zip(juntas, larguras)]
        t = [1 - pos[0], pos[0] * (1 - pos[1]), pos[1] * (1 - pos[2]), pos[2]]
        for n, pe in zip(ossos, t):
            if pe > 1e-4:
                w[n] = pe
        # Cauda: atrás da traseira do corpo, pelo comprimento até a ponta do leque.
        if _f(co) < f_tras:
            s = (f_tras - _f(co)) / max(f_tras - f_ponta, 1e-6)          # 0 raiz .. 1 ponta
            q = _mistura(s - 0.12, 0.2)
            w = {n: pe * (1 - q) for n, pe in w.items()}
            w["cauda_1"] = q * (1 - _mistura(s - 0.55, 0.3))
            w["cauda_2"] = q * _mistura(s - 0.55, 0.3)
        # Asa: fora da largura do corpo, pela posição ao longo da envergadura.
        lado = ".L" if co.x > 0 else ".R"
        a = m["asas"][lado]
        if abs(co.x) > meia * 0.8 and a["f"][0] < _f(co) < a["f"][1]:
            envergadura = abs(a["ponta"].x) - meia
            s = (abs(co.x) - meia) / max(envergadura, 1e-6)
            q = _mistura(s - 0.05, 0.2)
            # Raiz da asa mistura com o PEITO (o osso onde ela se prende), não com o que a
            # cadeia der ali — à frente do plano do pescoço o bordo da asa esticava.
            w = {"peito": 1 - q} if q < 1 else {}
            cot = (abs(a["cotovelo"].x) - meia) / max(envergadura, 1e-6)
            k = _mistura(s - cot, 0.15)
            w["asa_1" + lado] = q * (1 - k)
            w["asa_2" + lado] = q * k
        pesos.append(w)
    pesos = suavizar(bm, pesos, H)
    bm.free()
    return gravar_pesos(obj, arm, pesos)
