"""Quadrúpede: acha pernas, coluna, pescoço, cabeça e cauda na casca e monta o esqueleto.

Tudo em metros, no espaço do Blender (o bicho olha para -Y; `f` = -y é "para a frente").

  * PERNAS: a fatia horizontal perto do chão corta 4 contornos (um por pata). Cada um é
    seguido para cima, fatia a fatia, até se fundir no tronco (o contorno cresce de uma
    vez): esse é o TOPO da perna. Joelho/jarrete = maior dobra da linha de centro (ou
    uma fração da altura), tornozelo = 13 % da altura da perna.
  * CAUDA: parte da ponta (dada no perfil da espécie, porque há rabo pendurado, em pé,
    enrolado e horizontal) e é seguida do mesmo jeito até entrar na anca.
  * COLUNA: fatias transversais (planos y) do rabo ao focinho; o centro do contorno
    ACIMA da barriga dá a linha do tronco, do pescoço e da cabeça.

Pesos por REGIÃO (a casca é segmentada pela topologia, não por distância): o que está
abaixo do topo de uma perna e ligado à pata é perna; o tubo da cauda ligado à ponta é
cauda; o resto é tronco. Dentro de cada região, faixas de mistura em volta das juntas.
Assim o peso da cauda não vaza para a anca, nem o chifre para o pescoço.
"""
import math
import bmesh
from mathutils import Vector

from .geometria import fatiar, caixa

UP = Vector((0, 0, 1))
FRENTE = Vector((0, -1, 0))


def _f(v):
    return -v.y


class Membro:
    """Uma perna (ou a cauda): linha de centro seguida fatia a fatia."""

    def __init__(self, nome):
        self.nome = nome
        self.linha = []          # pontos de centro, da ponta para a raiz
        self.raios = []          # meio tamanho do contorno em cada ponto
        self.topo = None         # último ponto antes de fundir no tronco
        self.vertices = set()


def rastrear(bm, inicio, eixo, passo, max_passos, raio_busca, cresce=1.7):
    """Segue um membro a partir de `inicio` na direção `eixo`.

    Para quando não há contorno perto (fim do membro) ou o contorno cresce de uma vez
    (fundiu no tronco). Devolve (linha, raios) — os centros dos contornos.
    """
    linha, raios = [], []
    c = inicio.copy()
    anterior = None
    s0 = inicio.dot(eixo)
    for i in range(1, max_passos + 1):
        s = s0 + passo * i
        p = c + eixo * (s - c.dot(eixo))
        melhor, dmin = None, 1e9
        for k in fatiar(bm, p, eixo):
            d = k.centro - p
            d -= eixo * d.dot(eixo)
            if d.length < dmin:
                melhor, dmin = k, d.length
        if melhor is None or dmin > raio_busca:
            break
        if anterior is not None and melhor.perimetro > cresce * anterior.perimetro:
            break
        linha.append(melhor.centro.copy())
        e = melhor.ext
        raios.append(0.5 * max(e.x, e.y, e.z) if eixo.z == 0 else 0.5 * max(e.x, e.y))
        anterior = melhor
        c = melhor.centro.copy()
    return linha, raios


def _no_lado(pontos, lado, h):
    """Ponto mais perto (na vista de lado, f e z) de `lado` = (f normalizado, z normalizado)."""
    lo, hi = h
    L = hi.y - lo.y
    H = hi.z - lo.z
    alvo_f = -hi.y + lado[0] * L
    alvo_z = lo.z + lado[1] * H
    return min(pontos, key=lambda v: (_f(v) - alvo_f) ** 2 + (v.z - alvo_z) ** 2)


def analisar(obj, perfil):
    lo, hi = caixa(obj)
    H = hi.z - lo.z
    L = hi.y - lo.y
    z0 = lo.z
    fmin, fmax = -hi.y, -lo.y
    verts = [v.co.copy() for v in obj.data.vertices]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    m = {"H": H, "L": L, "z0": z0, "fmin": fmin, "fmax": fmax}

    # ---------------------------------------------------------------- pernas
    zb = z0 + H * perfil.get("fatia_pes", 0.08)
    base = [k for k in fatiar(bm, Vector((0, 0, zb)), UP) if abs(k.centro.x) > 0.01 * H]
    if len(base) < 4:
        raise RuntimeError("achou %d contornos de pata a %.2f m (esperava 4)" % (len(base), zb))
    f_meio = sum(_f(k.centro) for k in sorted(base, key=lambda k: -k.perimetro)[:4]) / 4
    pernas = {}
    for frente_ in (True, False):
        for esq in (True, False):
            nome = ("frente" if frente_ else "tras") + (".L" if esq else ".R")
            cand = [k for k in base if (_f(k.centro) > f_meio) == frente_ and (k.centro.x > 0) == esq]
            if not cand:
                raise RuntimeError("sem pata no quadrante " + nome)
            k = max(cand, key=lambda k: k.perimetro)
            p = Membro(nome)
            p.frente = frente_
            p.esquerda = esq
            linha, raios = rastrear(bm, k.centro, UP, H * 0.02, 60, max(k.ext.x, k.ext.y) * 1.5 + 0.02 * H)
            p.linha = [k.centro.copy()] + linha
            p.raios = [0.5 * max(k.ext.x, k.ext.y)] + raios
            p.topo = p.linha[-1]
            pernas[nome] = p
    m["pernas"] = pernas
    for p in pernas.values():
        # Pé no chão: centro dos vértices mais baixos perto da pata (casco/pata vai para a frente).
        r = max(p.raios[0] * 2.5, 0.03 * H)
        baixos = [v for v in verts if v.z < z0 + 0.04 * H and (Vector((v.x, v.y)) - p.linha[0].xy).length < r]
        if baixos:
            g = sum(baixos, Vector()) / len(baixos)
            p.chao = Vector((g.x, g.y, z0))
        else:
            p.chao = Vector((p.linha[0].x, p.linha[0].y, z0))
        p.ponta_pe = max(baixos, key=_f) if baixos else p.chao

    # ---------------------------------------------------------------- coluna
    f_h = sum(_f(pernas[n].topo) for n in ("tras.L", "tras.R")) / 2
    f_s = sum(_f(pernas[n].topo) for n in ("frente.L", "frente.R")) / 2
    z_h = min(pernas[n].topo.z for n in ("tras.L", "tras.R"))
    z_s = min(pernas[n].topo.z for n in ("frente.L", "frente.R"))

    def barriga(f):
        t = max(0.0, min(1.0, (f - f_h) / max(f_s - f_h, 1e-6)))
        return z_h + (z_s - z_h) * t

    perfil_coluna = []      # (f, centro_z, topo_z, baixo_z, largura_x)
    passos = 50
    for i in range(passos + 1):
        f = fmin + L * (0.01 + 0.98 * i / passos)
        cs = fatiar(bm, Vector((0, -f, 0)), Vector((0, 1, 0)))
        if not cs:
            continue
        k = max(cs, key=lambda k: k.perimetro)
        corte = barriga(f) + 0.02 * H if f_h - 0.1 * L < f < f_s + 0.1 * L else -1e9
        soma, tot, top, bot = Vector(), 0.0, -1e9, 1e9
        for a, b in k.segmentos:
            if a.z < corte and b.z < corte:
                continue
            if a.z < corte or b.z < corte:      # corta o segmento na altura da barriga
                if a.z > b.z:
                    a, b = b, a
                t = (corte - a.z) / max(b.z - a.z, 1e-9)
                a = a + (b - a) * t
            comp = (b - a).length
            soma += (a + b) * 0.5 * comp
            tot += comp
            top = max(top, a.z, b.z)
            bot = min(bot, a.z, b.z)
        if tot <= 0:
            continue
        perfil_coluna.append((f, (soma / tot).z, top, bot, k.ext.x))
    m["coluna_amostras"] = perfil_coluna

    def coluna(f):
        """Centro, topo e base do tronco/pescoço/cabeça na posição f (interpolado)."""
        pts = perfil_coluna
        if f <= pts[0][0]:
            return pts[0][1:4]
        for a, b in zip(pts, pts[1:]):
            if a[0] <= f <= b[0]:
                t = (f - a[0]) / max(b[0] - a[0], 1e-9)
                return tuple(a[j] + (b[j] - a[j]) * t for j in (1, 2, 3))
        return pts[-1][1:4]

    def ponto(f, sobe=0.1):
        c, t, b = coluna(f)
        return Vector((0, -f, c + sobe * (t - b)))

    # Traseira do tronco: a fatia mais de trás que já é larga (a cauda é fina).
    largura = max(p[4] for p in perfil_coluna)
    f_traseira = next(p[0] for p in perfil_coluna if p[4] > 0.45 * largura)
    # Cauda larga (raposa) passa no teste de largura: a anca não vai além de 12 % do
    # comprimento atrás das patas traseiras.
    f_traseira = max(f_traseira, f_h - 0.12 * L)
    f_c = (f_h + f_s) / 2
    m["C"] = ponto(f_c, 0.1)
    m["P"] = ponto(f_h, 0.1)
    m["R"] = Vector((0, -(f_traseira + 0.03 * L), m["P"].z))
    m["S"] = ponto(f_s, 0.1)
    # Base do pescoço: quem pasta tem na cernelha (sobre as patas da frente) — alavanca
    # longa para levar o focinho ao chão; carnívoro, mais à frente (senão o peito todo sobe
    # com o pescoço na mordida: o corgi virava lhama).
    m["Nb"] = ponto(f_s + perfil.get("pescoco", 0.0 if perfil.get("parado") == "pastar" else 0.07) * L, 0.12)
    f_hj = fmax - perfil.get("cabeca", 0.2) * L
    m["Hj"] = ponto(f_hj, 0.15)
    # Sem pescoço (sapo: as patas da frente ficam sob a cabeça): a base do pescoço nunca
    # passa da junta da cabeça.
    if _f(m["Nb"]) > _f(m["Hj"]) - 0.08 * L:
        m["Nb"] = ponto(_f(m["Hj"]) - 0.08 * L, 0.12)
    m["N"] = ponto(fmax - 0.01 * L, 0.0)
    m["cabeca_acima"] = perfil.get("cabeca_acima", 0.5)
    m["faixa_chao"] = perfil.get("faixa_chao", 0.0)
    m["pernas_laterais"] = perfil.get("corpo") == "rastejante"
    for chave, valor in perfil.get("ajustes", {}).items():
        # Ajuste fino por espécie, em fração (f, z) da caixa: {"Hj": (0.8, 0.85)}.
        m[chave] = Vector((0, -(fmin + valor[0] * L), z0 + valor[1] * H))

    # Juntas das pernas.
    for p in pernas.values():
        topo = p.topo
        alvo = m["S"] if p.frente else m["P"]
        p.J = Vector((topo.x * 0.85, topo.y, topo.z + 0.45 * (alvo.z - topo.z)))
        altura = topo.z - z0
        p.K = _junta(p.linha, z0 + altura * (perfil.get("joelho_frente", 0.5) if p.frente else perfil.get("joelho_tras", 0.62)),
                     dobra=not p.frente, faixa=(z0 + 0.3 * altura, z0 + 0.85 * altura))
        p.A = _no_z(p.linha, z0 + altura * perfil.get("tornozelo", 0.13))
        p.G = Vector((p.chao.x, p.chao.y, z0))

    m["cauda"] = achar_cauda(bm, verts, perfil.get("cauda"), lo, hi)
    bm.free()
    return m


def achar_cauda(bm, verts, cauda, lo, hi):
    """A cauda do perfil: seguida a partir da dica da ponta (`ponta` + `eixo`) ou marcada à
    mão (`pontos`, da raiz para a ponta, em fração da caixa). None = sem cauda."""
    if not cauda:
        return None
    H = hi.z - lo.z
    L = hi.y - lo.y
    z0, fmin = lo.z, -hi.y
    if "pontos" in cauda:
        # "pontos" vêm da raiz para a ponta; a linha seguida vai da ponta para a raiz.
        linha = [Vector((0, -(fmin + a * L), z0 + b * H)) for a, b in reversed(cauda["pontos"])]
        raios = [cauda.get("raio", 0.03) * H] * len(linha)
    else:
        ponta = _no_lado(verts, cauda["ponta"], (lo, hi))
        # Começa do centro dos vértices em volta da ponta (o vértice extremo fica na borda).
        perto = [v for v in verts if (v - ponta).length < 0.05 * H]
        inicio = sum(perto, Vector()) / len(perto)
        eixo = {"z+": UP, "z-": -UP, "f+": FRENTE}[cauda["eixo"]]
        linha, raios = rastrear(bm, inicio, eixo, H * 0.015, 80, 0.09 * H, cresce=cauda.get("cresce", 1.6))
        linha = [ponta.copy()] + linha
        raios = [raios[0] if raios else 0.02 * H] + raios
    if len(linha) < 3:
        raise RuntimeError("cauda com %d pontos: confira a dica 'ponta' do perfil (ou use 'pontos')" % len(linha))
    c = Membro("cauda")
    c.linha = list(reversed(linha))           # da raiz para a ponta
    c.raios = list(reversed(raios))
    c.raio = max(c.raios) * 1.25 + 0.01 * H
    return c


def _no_z(linha, z):
    """Ponto da linha (de baixo para cima) na altura z."""
    for a, b in zip(linha, linha[1:]):
        if a.z <= z <= b.z:
            t = (z - a.z) / max(b.z - a.z, 1e-9)
            return a.lerp(b, t)
    return linha[0] if z < linha[0].z else linha[-1]


def _junta(linha, z_padrao, dobra, faixa):
    """Joelho/jarrete: a maior dobra da linha de centro dentro da faixa; senão, a altura padrão."""
    if dobra and len(linha) >= 5:
        melhor, ang = None, 0.0
        for i in range(2, len(linha) - 2):
            if not (faixa[0] <= linha[i].z <= faixa[1]):
                continue
            a = (linha[i] - linha[i - 2]).normalized()
            b = (linha[i + 2] - linha[i]).normalized()
            d = math.degrees(a.angle(b, 0.0))
            if d > ang:
                melhor, ang = linha[i], d
        if melhor is not None and ang > 12.0:
            return melhor.copy()
    return _no_z(linha, z_padrao)


# ======================================================================= esqueleto
OSSOS_SEM_PESO = ("raiz", "tronco")
SUAVIZAR_PASSADAS = 3


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
            o.tail = a + UP * 0.02 * H
        if pai:
            o.parent = eb[pai]
            o.use_connect = liga
        o.align_roll(Vector((1, 0, 0)) if abs((o.tail - o.head).normalized().x) < 0.9 else Vector((0, 0, 1)))
        return o

    C = m["C"]
    osso("raiz", Vector((C.x, C.y, z0)), Vector((C.x, C.y, z0 + 0.2 * H)))
    osso("tronco", C, C + UP * 0.12 * H, "raiz")
    osso("quadril", C, m["R"], "tronco")
    osso("peito", C, m["Nb"], "tronco")
    osso("pescoco", m["Nb"], m["Hj"], "peito", True)
    osso("cabeca", m["Hj"], m["N"], "pescoco", True)
    for n, p in m["pernas"].items():
        lado = n[-2:]
        pai = "peito" if p.frente else "quadril"
        pre = "perna_" + n[:-2]
        osso(pre + "_1" + lado, p.J, p.K, pai)
        osso(pre + "_2" + lado, p.K, p.A, pre + "_1" + lado, True)
        osso(pre + "_3" + lado, p.A, p.G + FRENTE * 0.0, pre + "_2" + lado, True)
    if m["cauda"]:
        c = m["cauda"]
        pts = _reamostrar(c.linha, 3)
        osso("cauda_1", pts[0], pts[1], "quadril")
        osso("cauda_2", pts[1], pts[2], "cauda_1", True)
        osso("cauda_3", pts[2], pts[3], "cauda_2", True)
    bpy.ops.object.mode_set(mode='OBJECT')
    for n in OSSOS_SEM_PESO:
        arm_data.bones[n].use_deform = False
    return arm


def _reamostrar(linha, segmentos):
    comp = [0.0]
    for a, b in zip(linha, linha[1:]):
        comp.append(comp[-1] + (b - a).length)
    total = comp[-1]
    out = []
    for i in range(segmentos + 1):
        alvo = total * i / segmentos
        for j in range(len(linha) - 1):
            if comp[j] <= alvo <= comp[j + 1] or j == len(linha) - 2:
                t = (alvo - comp[j]) / max(comp[j + 1] - comp[j], 1e-9)
                out.append(linha[j].lerp(linha[j + 1], min(max(t, 0.0), 1.0)))
                break
    return out


# ========================================================================== pesos
def _suave(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def _mistura(s, largura):
    """0 antes da junta, 1 depois; faixa de mistura de `largura` centrada nela."""
    return _suave(0.5 + s / max(largura, 1e-9))


def _regiao(bm, sementes, aceita):
    vistos = set()
    pilha = list(sementes)
    while pilha:
        v = pilha.pop()
        if v.index in vistos or not aceita(v):
            continue
        vistos.add(v.index)
        for e in v.link_edges:
            o = e.other_vert(v)
            if o.index not in vistos:
                pilha.append(o)
    return vistos


def _rotular(bm, m):
    """{índice do vértice: rótulo} — nome da perna ou "cauda"; tronco fica de fora.

    Perna: abaixo do topo, ligado à pata e mais perto da linha de centro DESTA perna do que
    de qualquer outra (as coxas de dentro do cão se tocam: sem isso a perna direita
    vazava para a esquerda). Cauda: tubo em volta da linha, ligado à ponta.
    """
    H, L, z0 = m["H"], m["L"], m["z0"]
    pernas = list(m["pernas"].values())

    def dist(p, co):
        return (co.xy - _no_z(p.linha, co.z).xy).length

    rotulo = {}
    for p in pernas:
        topo_z = p.topo.z

        def aceita(v, p=p, topo_z=topo_z):
            if v.co.z > topo_z + 0.005 * H:
                return False
            d = dist(p, v.co)
            lim = max(1.7 * _raio_no_z(p, v.co.z), 0.03 * H)
            if v.co.z < z0 + 0.15 * (topo_z - z0):
                lim = max(lim, 2.6 * p.raios[0], 0.06 * H)    # pata/casco vai para a frente
            return d < lim and all(dist(o, v.co) >= d for o in pernas if o is not p)

        sementes = [v for v in bm.verts if v.co.z < z0 + 0.03 * H and (v.co.xy - p.chao.xy).length < max(3 * p.raios[0], 0.05 * H)]
        for i in _regiao(bm, sementes, aceita):
            rotulo[i] = p.nome

    c = m["cauda"]
    if c:
        def dist_cauda(co):
            return min(_dist_seg(co, a, b) for a, b in zip(c.linha, c.linha[1:]))
        base = c.linha[0]
        dir0 = (c.linha[min(2, len(c.linha) - 1)] - base).normalized()

        def aceita_c(v):
            return v.index not in rotulo and dist_cauda(v.co) < c.raio and (v.co - base).dot(dir0) > -0.01 * H
        ponta = c.linha[-1]
        for i in _regiao(bm, sorted(bm.verts, key=lambda v: (v.co - ponta).length)[:4], aceita_c):
            rotulo[i] = "cauda"

    # Rente ao chão nunca é tronco: ponta de casco/dedo que a busca da perna não alcançou
    # (bisão, raposa: ganhava peso do pescoço e subia com a cabeça ao pastar) vai para a
    # pata mais perto. Abaixo de 12 % da altura só há patas (a cauda já foi separada).
    # Bicho rasteiro (lagarto: 13 cm de altura, dedos chatos a 1–3 cm do chão): o perfil
    # dá a faixa em fração da altura da perna mais baixa (`faixa_chao`).
    faixa_chao = max(0.12 * H, m.get("faixa_chao", 0.0) * min(p.topo.z - z0 for p in pernas))
    for v in bm.verts:
        if v.index in rotulo or v.co.z > z0 + faixa_chao:
            continue
        p = min(pernas, key=lambda q: (v.co.xy - q.chao.xy).length)
        # Do lado da pata, nunca na linha do meio (a barriga do lagarto encosta no chão).
        if (v.co.xy - p.chao.xy).length < 0.2 * L and abs(v.co.x) > 0.4 * abs(p.chao.x):
            rotulo[v.index] = p.nome
    # Perna que sai DE LADO (lagarto: braço horizontal): o que está para fora do corpo, do
    # lado e na altura de uma pata, é dessa perna.
    if m.get("pernas_laterais"):
        for v in bm.verts:
            if v.index in rotulo:
                continue
            p = min(pernas, key=lambda q: (v.co.xy - q.chao.xy).length)
            if (v.co.x > 0) == p.esquerda and abs(v.co.x) > 0.55 * abs(p.chao.x) \
                    and abs(v.co.y - p.chao.y) < 0.08 * L and v.co.z < p.topo.z + 0.02 * H:
                rotulo[v.index] = p.nome
    return rotulo


def descosturar(obj, m):
    """Separa na malha as partes RÍGIDAS diferentes que só se encostam (pata com pata,
    pata com cauda): a ponta da cauda do corgi tocava as duas patas traseiras no chão e o
    triângulo da junção esticava ×16 no galope. Tronco com perna/cauda continua ligado
    (lá a mistura dos pesos faz a transição). Devolve {índice: rótulo} da malha final.
    """
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    rotulo = _rotular(bm, m)
    nomes = sorted(set(rotulo.values()))
    camada = bm.verts.layers.int.new("rotulo")
    for v in bm.verts:
        v[camada] = nomes.index(rotulo[v.index]) + 1 if v.index in rotulo else 0
    # Rótulo da face: o dos seus vértices rotulados (maioria).
    rot_face = {}
    for f in bm.faces:
        cont = {}
        for v in f.verts:
            if v[camada]:
                cont[v[camada]] = cont.get(v[camada], 0) + 1
        rot_face[f.index] = max(cont, key=cont.get) if cont else 0
    # Só costura NÃO-manifold (aresta com 3+ faces: peças que a solda juntou por se
    # encostarem). Aresta comum a duas faces é superfície contínua (a cauda do corgi É a
    # pele de trás da coxa): cortá-la abre buraco — lá a suavização dos pesos resolve.
    costura = [e for e in bm.edges if len(e.link_faces) > 2
               and len({rot_face[f.index] for f in e.link_faces if rot_face[f.index]}) > 1]
    if costura:
        normais = [n.vector.copy() for n in me.corner_normals]
        faces_antes = len(bm.faces)
        # Os vértices da fronteira também: aresta cortada no meio de um leque fecha de novo
        # no vértice se ele não for dividido junto.
        juntas_rigidas = list({v for e in costura for v in e.verts})
        bmesh.ops.split_edges(bm, edges=costura, verts=juntas_rigidas, use_verts=True)
        bm.faces.index_update()


        # Depois de separar, cada vértice segue o rótulo das faces rígidas que restaram nele.
        for v in bm.verts:
            rs = {rot_face[f.index] for f in v.link_faces if rot_face[f.index]}
            if v[camada] and len(rs) == 1 and v[camada] not in rs:
                v[camada] = rs.pop()
        if len(bm.faces) != faces_antes:
            raise RuntimeError("descosturar mudou o número de faces")

        bm.to_mesh(me)
        me.normals_split_custom_set(normais)
        me.update()
        bm.free()
        bm = bmesh.new()
        bm.from_mesh(me)
        camada = bm.verts.layers.int["rotulo"]
    bm.verts.ensure_lookup_table()
    final = {v.index: nomes[v[camada] - 1] for v in bm.verts if v[camada]}
    bm.free()
    if "rotulo" in me.attributes:
        me.attributes.remove(me.attributes["rotulo"])
    return final, len(costura)


def pesar(obj, arm, m):
    """Grupos de vértices por região + faixas de mistura. Devolve {osso: n_vertices}."""
    H, L, z0 = m["H"], m["L"], m["z0"]
    rotulo, costuras = descosturar(obj, m)
    m["costuras"] = costuras
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    pesos = [dict() for _ in bm.verts]
    regiao_perna = {i: r for i, r in rotulo.items() if r != "cauda"}
    regiao_cauda = {i for i, r in rotulo.items() if r == "cauda"}
    for p in m["pernas"].values():
        p.vertices = {i for i, r in regiao_perna.items() if r == p.nome}
    c = m["cauda"]

    cadeia = [m["R"], m["C"], m["Nb"], m["Hj"], m["N"]]
    ossos_cadeia = ["quadril", "peito", "pescoco", "cabeca"]
    # Planos das juntas C, Nb, Hj (normal = bissetriz das direções vizinhas).
    juntas = []
    for i in (1, 2, 3):
        d1 = (cadeia[i] - cadeia[i - 1]).normalized()
        d2 = (cadeia[i + 1] - cadeia[i]).normalized()
        juntas.append((cadeia[i], (d1 + d2).normalized()))
    larguras = [0.22 * L, 0.10 * L, 0.035 * L]

    def tronco(co):
        """Pesos da cadeia quadril/peito/pescoço/cabeça num ponto (sem ombro/anca)."""
        pos = [_mistura((co - j).dot(nrm), lg) for (j, nrm), lg in zip(juntas, larguras)]
        # Chifre/galhada/orelha: acima da junta da cabeça e na frente do pescoço é cabeça,
        # mesmo que vá para trás do plano da junta (a galhada do alce varre o pescoço).
        f_lim = _f(m["Nb"]) + m.get("cabeca_acima", 0.5) * (_f(m["Hj"]) - _f(m["Nb"]))
        if co.z > m["Hj"].z + 0.03 * H and _f(co) > f_lim:
            pos[2] = max(pos[2], _suave((co.z - m["Hj"].z - 0.03 * H) / (0.05 * H)))
        # pos[i] = 1 depois da junta i. Pesos dos 4 trechos:
        t = [1 - pos[0], pos[0] * (1 - pos[1]), pos[1] * (1 - pos[2]), pos[2]]
        return {n: pe for n, pe in zip(ossos_cadeia, t) if pe > 1e-4}

    for v in bm.verts:
        w = pesos[v.index]
        co = v.co
        if v.index in regiao_perna:
            p = m["pernas"][regiao_perna[v.index]]
            pre = "perna_" + p.nome[:-2]
            lado = p.nome[-2:]
            # De baixo para cima: pé -> canela -> coxa, com faixas no tornozelo e no joelho.
            a = _mistura(co.z - p.A.z, 0.05 * H)          # 0 = pé, 1 = canela
            k = _mistura(co.z - p.K.z, 0.07 * H)          # 0 = canela, 1 = coxa
            w[pre + "_3" + lado] = 1 - a
            w[pre + "_2" + lado] = a * (1 - k)
            w[pre + "_1" + lado] = a * k
            # Topo da perna: metade tronco, como o vizinho do outro lado da fronteira (sem
            # isso a borda era 100 % coxa contra 45 % pescoço — o peito do bisão rasgava).
            faixa = min(0.06 * H, 0.35 * (p.topo.z - z0))      # perna curta (corgi): faixa curta
            q = 0.5 * _suave((co.z - (p.topo.z - faixa)) / faixa)
            if q > 0:
                for kk in list(w):
                    w[kk] *= (1 - q)
                for kk, pe in tronco(co).items():
                    w[kk] = w.get(kk, 0.0) + q * pe
            continue
        if v.index in regiao_cauda:
            pts = _reamostrar(c.linha, 3)
            s = _param(co, pts)                            # 0..3 ao longo da cauda
            w["cauda_1"] = 1.0 - _mistura(s - 1.0, 0.5)
            w["cauda_2"] = _mistura(s - 1.0, 0.5) * (1.0 - _mistura(s - 2.0, 0.5))
            w["cauda_3"] = _mistura(s - 2.0, 0.5)
            # Raiz da cauda: mistura com a anca.
            q = 1.0 - _mistura(s - 0.4, 0.8)
            if q > 0:
                for kk in list(w):
                    w[kk] *= (1 - q)
                w["quadril"] = w.get("quadril", 0.0) + q
            continue
        # Tronco: qual trecho da cadeia, com faixas nos planos das juntas.
        for nome_, peso in tronco(co).items():
            w[nome_] = w.get(nome_, 0.0) + peso
        # Ombro/anca: a parte do tronco logo acima da perna acompanha a coxa.
        for n, p in m["pernas"].items():
            if co.z > p.J.z or co.z < p.topo.z - 0.02 * H:
                continue
            r = max(_raio_no_z(p, p.topo.z) * 1.6, 0.04 * H)
            d = (co.xy - p.topo.xy).length
            if d > r or (co.x > 0) != p.esquerda and abs(co.x) > 0.02 * H:
                continue
            alt = 1 - _suave((co.z - p.topo.z) / max(p.J.z - p.topo.z, 1e-6))
            perto = 1 - _suave(d / r)
            q = 0.5 * alt * perto        # mesmo teto do topo da perna (0,5): a borda casa
            if q <= 0:
                continue
            for kk in list(w):
                w[kk] *= (1 - q)
            nome_osso = "perna_" + p.nome[:-2] + "_1" + p.nome[-2:]
            w[nome_osso] = w.get(nome_osso, 0.0) + q

    pesos = suavizar(bm, pesos, H)

    bm.free()
    return gravar_pesos(obj, arm, pesos)


def suavizar(bm, pesos, H):
    """Suaviza pela malha (como o Smooth de pesos do Blender): fronteira dura cauda/tronco
    (o rabo enrolado do cão encosta a ponta nas costas) vira transição. Partes rígidas
    separadas por `descosturar` não têm aresta em comum, então não se misturam. Vizinhos
    ponderados pela proximidade. TODAS as arestas entram: cortar as longas (tentativa de
    02/10, por um diagnóstico errado na galinha) deixou fronteira dura onde o modelo de
    poucas faces só tem aresta longa — cauda da raposa, peito do bisão."""
    vizinhos = [[(e.other_vert(v).index, 1.0 / max(e.calc_length(), 1e-4)) for e in v.link_edges]
                for v in bm.verts]
    for _ in range(SUAVIZAR_PASSADAS):
        novos = []
        for i, w in enumerate(pesos):
            if not vizinhos[i]:
                novos.append(w)
                continue
            media = {}
            soma = sum(k for _, k in vizinhos[i])
            for j, k in vizinhos[i]:
                for n_, pe in pesos[j].items():
                    media[n_] = media.get(n_, 0.0) + pe * k / soma
            novos.append({n_: 0.5 * w.get(n_, 0.0) + 0.5 * media.get(n_, 0.0) for n_ in set(w) | set(media)})
        pesos = novos
    return pesos


def gravar_pesos(obj, arm, pesos, padrao="peito"):
    """Grava os grupos: 4 influências no máximo (o glTF exporta 4), normalizado."""
    grupos = {b.name: obj.vertex_groups.new(name=b.name) for b in arm.data.bones if b.use_deform}
    contagem = {}
    for i, w in enumerate(pesos):
        itens = sorted(((p, n) for n, p in w.items() if p > 1e-3 and n in grupos), reverse=True)[:4]
        tot = sum(p for p, _ in itens)
        if tot <= 0:
            itens, tot = [(1.0, padrao)], 1.0
        for p, n in itens:
            grupos[n].add([i], p / tot, 'REPLACE')
            contagem[n] = contagem.get(n, 0) + 1
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    obj.parent = arm
    return contagem


def _raio_no_z(p, z):
    for (a, ra), (b, rb) in zip(zip(p.linha, p.raios), zip(p.linha[1:], p.raios[1:])):
        if a.z <= z <= b.z:
            t = (z - a.z) / max(b.z - a.z, 1e-9)
            return ra + (rb - ra) * t
    return p.raios[0] if z < p.linha[0].z else p.raios[-1]


def _dist_seg(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def _param(p, pts):
    """Parâmetro contínuo (0..n) do ponto mais perto na polilinha."""
    melhor, dmin = 0.0, 1e9
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
        d = (p - (a + ab * t)).length
        if d < dmin:
            melhor, dmin = i + t, d
    return melhor
