"""Ave de chão (galinha, pintinho, pato): 2 pernas, corpo, pescoço que SOBE, cabeça, cauda.

Mesmo esqueleto e mesmos pesos do quadrúpede (`quadrupede.montar_esqueleto` / `pesar`), com
só as patas de trás; o que muda é achar o pescoço. Nas aves ele sobe do peito, então é
seguido por fatias HORIZONTAIS: acima do meio do corpo, o contorno mais à frente é o do
pescoço e depois o da cabeça (o de trás, na galinha, é a cauda). Asa colada ao corpo (sem
asa separada nos modelos do pacote): nenhum osso de asa.
"""
import bmesh
from mathutils import Vector

from .geometria import fatiar, caixa
from .quadrupede import Membro, rastrear, _no_z, _junta, achar_cauda, UP, _f


def analisar(obj, perfil):
    lo, hi = caixa(obj)
    H = hi.z - lo.z
    L = hi.y - lo.y
    z0 = lo.z
    fmin, fmax = -hi.y, -lo.y
    verts = [v.co.copy() for v in obj.data.vertices]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    m = {"H": H, "L": L, "z0": z0, "fmin": fmin, "fmax": fmax}

    # ---------------------------------------------------------------- pernas
    zb = z0 + H * perfil.get("fatia_pes", 0.08)
    base = [k for k in fatiar(bm, Vector((0, 0, zb)), UP) if abs(k.centro.x) > 0.01 * H]
    pernas = {}
    for esq in (True, False):
        cand = [k for k in base if (k.centro.x > 0) == esq]
        if not cand:
            raise RuntimeError("sem pata do lado %s a %.3f m" % ("esquerdo" if esq else "direito", zb))
        k = max(cand, key=lambda k: k.perimetro)
        p = Membro("tras" + (".L" if esq else ".R"))
        p.frente = False
        p.esquerda = esq
        linha, raios = rastrear(bm, k.centro, UP, H * 0.02, 60, max(k.ext.x, k.ext.y) * 1.5 + 0.02 * H)
        p.linha = [k.centro.copy()] + linha
        p.raios = [0.5 * max(k.ext.x, k.ext.y)] + raios
        p.topo = p.linha[-1]
        r = max(p.raios[0] * 3.0, 0.04 * H)
        baixos = [v for v in verts if v.z < z0 + 0.04 * H and (Vector((v.x, v.y)) - p.linha[0].xy).length < r]
        g = sum(baixos, Vector()) / len(baixos) if baixos else p.linha[0]
        p.chao = Vector((g.x, g.y, z0))
        pernas[p.nome] = p
    m["pernas"] = pernas
    z_pernas = max(p.topo.z for p in pernas.values())

    # ----------------------------------------------------------------- corpo
    # Fatias transversais acima das pernas: o corpo é onde o contorno é largo.
    amostras = []
    for i in range(41):
        f = fmin + L * (0.01 + 0.98 * i / 40)
        cs = fatiar(bm, Vector((0, -f, 0)), Vector((0, 1, 0)))
        if not cs:
            continue
        k = max(cs, key=lambda k: k.perimetro)
        pts = [a for seg in k.segmentos for a in seg if a.z > z_pernas + 0.01 * H]
        if pts:
            amostras.append((f, sum((p.z for p in pts)) / len(pts), k.ext.x))
    largura = max(a[2] for a in amostras)
    corpo = [a for a in amostras if a[2] > 0.6 * largura]
    f_tras, f_frente = corpo[0][0], corpo[-1][0]
    f_c = 0.5 * (f_tras + f_frente)
    z_c = min(corpo, key=lambda a: abs(a[0] - f_c))[1]
    m["C"] = Vector((0, -f_c, z_c))
    m["R"] = Vector((0, -(f_tras + 0.04 * L), z_c))
    m["P"] = m["C"]
    m["S"] = m["C"]

    # ------------------------------------------------------ pescoço e cabeça
    # Fatias horizontais do meio do corpo para cima: o contorno mais à frente.
    cadeia = []
    z = z_c
    while z < hi.z - 0.01 * H:
        cs = [k for k in fatiar(bm, Vector((0, 0, z)), UP) if _f(k.centro) > f_c - 0.1 * L]
        if cs:
            k = max(cs, key=lambda k: _f(k.centro))
            cadeia.append((k.centro.copy(), k.ext.y))
        z += 0.02 * H
    z_hj = hi.z - perfil.get("cabeca", 0.22) * H
    hj = min((c for c, _ in cadeia), key=lambda c: abs(c.z - z_hj))
    m["Hj"] = Vector((0, hj.y, hj.z))
    # Base do pescoço: o primeiro corte em que o contorno da frente encolhe (sai do peito),
    # no mínimo 8 % da altura abaixo da cabeça (pintinho quase não tem pescoço).
    maior = max(ef for _, ef in cadeia)
    nb = next((c for c, ef in cadeia if ef < 0.6 * maior), hj)
    if nb.z > hj.z - 0.08 * H:
        nb = min((c for c, _ in cadeia), key=lambda c: abs(c.z - (hj.z - 0.08 * H)))
    m["Nb"] = Vector((0, nb.y, nb.z))
    bico = max((v for v in verts if v.z > m["Hj"].z - 0.05 * H), key=_f)
    m["N"] = Vector((0, bico.y, bico.z))
    m["cabeca_acima"] = perfil.get("cabeca_acima", 0.0)
    m["inclina_pastar"] = perfil.get("inclina_pastar", 0.4)

    # ------------------------------------------------------------- juntas
    for p in pernas.values():
        topo = p.topo
        p.J = Vector((topo.x * 0.85, topo.y, topo.z + 0.45 * (z_c - topo.z)))
        altura = topo.z - z0
        p.K = _junta(p.linha, z0 + altura * perfil.get("joelho_tras", 0.62), dobra=True,
                     faixa=(z0 + 0.3 * altura, z0 + 0.85 * altura))
        p.A = _no_z(p.linha, z0 + altura * perfil.get("tornozelo", 0.13))
        p.G = Vector((p.chao.x, p.chao.y, z0))

    m["cauda"] = achar_cauda(bm, verts, perfil.get("cauda"), lo, hi)
    bm.free()
    return m
