"""Ponte de madeira low poly em arco, para o rio em S da Ilha Inicial (Modo História).

Regenerar (na raiz do projeto):
  /home/gabriel-bitti/opt/blender/blender --background --python tools/blender/ponte_rio.py
  ... --python tools/blender/ponte_rio.py -- --capturar     # + capturas de validação

Autoria em coordenadas do Godot (metros, Y para cima, frente -Z); v() converte para o
Blender (Z para cima) e o GLB sai com export_yup=True, como em areia_praia.py.
Comprimento em Z (-17..+17), largura em X (-3..+3). Deck em y=0 nas pontas e y=+2,4 no
meio. Origem = centro da ponte na altura das pontas do deck. Semente fixa: mesma saída.

Cada peça é um sólido fechado; peças que se tocam se SOBREPÕEM alguns centímetros (sem
vértices quase coincidentes entre cores diferentes, que abrem frestas no Godot).
O topo do deck é uma laje ÚNICA e lisa (o colisor do jogador é uma caixa e não sobe degrau
nenhum): as tábuas aparecem só pela cor e pelas pontas irregulares fora do vão útil.

O GLB leva também o objeto `Colisao` (invisível no jogo: a loja usa SÓ ele como colisão):
piso com o mesmo topo do deck + duas paredes de guarda-corpo. Cavaletes, cabeceiras, cordas e
pilares ficam só visuais (no trimesh do modelo inteiro, as arestas deles travavam a caixa).
"""
import bpy
import json
import math
import random
import struct
import sys
from collections import defaultdict
from pathlib import Path

from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
FONTE = ROOT / 'art_src' / 'ponte'
VALID = ROOT / 'art_src' / 'validation' / 'ponte'
BLEND = FONTE / 'ponte_rio.blend'
GLB = FONTE / 'ponte_rio_low_poly.glb'
ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
CAPTURAR = '--capturar' in ARGS
rng = random.Random(300930)


def v(x, y, z):
    """Godot (Y para cima) -> Blender (Z para cima). É uma rotação: preserva o giro das faces."""
    return (x, -z, y)


# ---------------------------------------------------------------- medidas (Godot, metros)
L2 = 17.0                  # meio comprimento: deck de z=-17 a z=+17
H_ARCO = 2.4               # altura do deck no meio
N_SEG = 16                 # arco segmentado em trechos de 2,125 m
TAB_SEG = 4                # tábuas por trecho (0,53 m cada, 64 no total)
ESP_TAB = 0.10             # espessura da laje do deck
X_TAB = 2.60               # meia largura das tábuas (pontas irregulares, ±6 cm: |x| >= 2,54)
TRANS = 0.02               # transição de 2 cm entre as pontas de uma tábua e as da próxima
X_LONG = ((-2.08, 0.24), (-0.70, 0.20), (0.70, 0.20), (2.08, 0.24))  # longarinas (x, largura)
ALT_LONG = 0.40
Z_LONG = 13.45             # longarinas entram 21 cm na face das cabeceiras
X_POSTE, LADO_POSTE = 2.29, 0.22   # face interna em 2,18: vão útil de 4,36 m
CORR_BASE, CORR_TOPO = 0.97, 1.10  # corrimão: topo 1,10 m acima do deck
CORDA_Y, CORDA_R = 0.55, 0.035
Z_PILAR, X_PILAR = 16.0, 2.48      # pilares de pedra nas pontas
Z_CAVALETES = (-6.375, 0.0, 6.375)  # coincidem com vértices do arco (k = 5, 8, 11)
Y_FUNDO = -3.2             # leito do rio: nada abaixo disto
X_MAX = 3.0
Z_CAB = 13.0               # cabeceiras de |z| = 13 a 17
X_COL, ESP_COL = 2.2, 0.30         # colisão: piso em |x| <= 2,2, 30 cm de espessura
ESP_PAREDE = 0.15                  # paredes de colisão em 2,2 <= |x| <= 2,35
Z_PAREDE = Z_PILAR + 0.29          # paredes até a face externa dos pilares; pontas abertas

# Paleta do kit medieval da loja (mesmos valores lineares de Wood/Wood_Light/Stone/Stone_Light).
MATERIAIS = [
    ('Madeira_Escura', (0.25, 0.14, 0.05)),    # estrutura
    ('Madeira_Clara', (0.38, 0.24, 0.10)),     # tábuas A e corrimão
    ('Madeira_Media', (0.285, 0.165, 0.062)),  # tábuas B (contraste ~1,33x com as A)
    ('Pedra', (0.24, 0.25, 0.22)),
    ('Pedra_Clara', (0.45, 0.46, 0.40)),       # capeamento e capitéis
    ('Corda', (0.46, 0.37, 0.21)),
]
ESCURA, CLARA, MEDIA, PEDRA, PEDRA_CL, CORDA = range(6)

PASSO = 2 * L2 / N_SEG
Z_K = [-L2 + k * PASSO for k in range(N_SEG + 1)]
# Perfil cosseno: tangente ao chão nas pontas e plano no topo; inclinação máx. ~12,2° nos trechos.
Y_K = [round(H_ARCO * 0.5 * (1 + math.cos(math.pi * z / L2)), 6) for z in Z_K]


def deck(z):
    """Altura do deck (linha poligonal do arco segmentado), simétrica em z."""
    z = max(-L2, min(L2, z))
    k = min(N_SEG - 1, int((z + L2) // PASSO))
    return Y_K[k] + (Y_K[k + 1] - Y_K[k]) * (z - Z_K[k]) / PASSO


# ---------------------------------------------------------------- construção
class Malha:
    def __init__(self):
        self.v, self.f, self.m = [], [], []

    def solido(self, pts, faces, mats):
        # Volume com sinal: se negativo (peça espelhada, por exemplo), inverte tudo.
        vol = sum(pts[f[0]].dot(pts[f[i]].cross(pts[f[i + 1]]))
                  for f in faces for i in range(1, len(f) - 1))
        if vol < 0:
            faces = [f[::-1] for f in faces]
        base = len(self.v)
        self.v += pts
        for f, m in zip(faces, mats):
            self.f.append(tuple(base + i for i in f))
            self.m.append(m)

    def loft(self, aneis, mat, apice=None):
        """Sólido fechado ligando anéis de mesmo número de vértices (mesma ordem angular).
        mat: índice do material, ou função (trecho r -> material) para colorir por trecho."""
        cor = mat if callable(mat) else (lambda r: mat)
        n = len(aneis[0])
        pts = [p for anel in aneis for p in anel]
        faces, mats = [tuple(range(n))[::-1]], [cor(0)]
        for r in range(len(aneis) - 1):
            for i in range(n):
                j = (i + 1) % n
                faces.append((r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i))
                mats.append(cor(r))
        topo = (len(aneis) - 1) * n
        if apice is None:
            faces.append(tuple(topo + i for i in range(n)))
            mats.append(cor(len(aneis) - 2))
        else:
            pts.append(Vector(apice))
            a = len(pts) - 1
            faces += [(topo + i, topo + (i + 1) % n, a) for i in range(n)]
            mats += [cor(len(aneis) - 2)] * n
        self.solido(pts, faces, mats)


def contorno(hx, hz, c):
    """Retângulo (c=0) ou octógono de cantos chanfrados, anti-horário visto de cima."""
    if c <= 0:
        return [(hx, hz), (hx, -hz), (-hx, -hz), (-hx, hz)]
    return [(hx, hz - c), (hx, -hz + c), (hx - c, -hz), (-hx + c, -hz),
            (-hx, -hz + c), (-hx, hz - c), (-hx + c, hz), (hx - c, hz)]


def caixa(M, x0, x1, y0, y1, z0, z1, mat):
    cx, cz, hx, hz = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2
    M.loft([[Vector((cx + a, y, cz + b)) for a, b in contorno(hx, hz, 0)] for y in (y0, y1)], mat)


def viga(M, p0, p1, w, h, up, mat):
    """Viga de seção w x h entre dois pontos; 'up' orienta a espessura h."""
    p0, p1, up = Vector(p0), Vector(p1), Vector(up)
    a = (p1 - p0).normalized()
    s = up.cross(a).normalized()
    u = a.cross(s)
    sec = [(w / 2, h / 2), (-w / 2, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
    M.loft([[p + s * i + u * j for i, j in sec] for p in (p0, p1)], mat)


def tabuas(M):
    """Deck: UMA laje contínua, de topo liso, em 64 faixas de 0,53 m (uma por tábua).
    As faixas alternam a cor e compartilham os vértices da costura: sem degrau, sem fresta
    e sem face vertical no vão útil. Topo = linha poligonal do arco, exata (y=0 nas pontas,
    2,4 no meio). As pontas irregulares de cada tábua ficam em |x| >= 2,54 (fora do vão
    útil, além dos postes): a largura muda numa transição de 2 cm no fim de cada tábua."""
    n = N_SEG * TAB_SEG
    dz = 2 * L2 / n
    for _ in range(n):           # sorteio do antigo relevo (removido): mantém a sequência
        rng.choice((0, 1, 2))    # da semente, e as cabeceiras ficam idênticas às de antes
    aneis, cores, tom = [], [], 0
    for i in range(n):
        if rng.random() > 0.2:                 # faixas alternadas, às vezes duas iguais
            tom ^= 1
        k = i // TAB_SEG
        incl = (Y_K[k + 1] - Y_K[k]) / PASSO   # faixa plana no plano do seu trecho do arco
        za, zb = -L2 + i * dz, -L2 + (i + 1) * dz
        xra, xrb = (X_TAB + rng.uniform(-.06, .06) for _ in range(2))
        xla, xlb = (-X_TAB + rng.uniform(-.06, .06) for _ in range(2))
        zfim = zb if i == n - 1 else zb - TRANS
        for z, xr, xl in ((za, xra, xla), (zfim, xrb, xlb)):
            y = Y_K[k] + incl * (z - Z_K[k])
            aneis.append([Vector((xr, y, z)), Vector((xl, y, z)),
                          Vector((xl, y - ESP_TAB, z)), Vector((xr, y - ESP_TAB, z))])
        cores.append((CLARA, MEDIA)[tom])
    # Trecho r: 2i = corpo da tábua i, 2i+1 = transição até a i+1 (ainda com a cor da i).
    M.loft(aneis, lambda r: cores[r // 2])


def longarinas(M):
    zs = [-Z_LONG] + [z for z in Z_K if abs(z) < Z_LONG] + [Z_LONG]
    for xc, w in X_LONG:
        aneis = []
        for z in zs:
            yt = deck(z) - ESP_TAB + 0.02          # entra 2 a 4,4 cm nas tábuas
            yb = yt - ALT_LONG
            aneis.append([Vector((xc + w / 2, yt, z)), Vector((xc - w / 2, yt, z)),
                          Vector((xc - w / 2, yb, z)), Vector((xc + w / 2, yb, z))])
        M.loft(aneis, ESCURA)


def guarda_corpos(M):
    h = LADO_POSTE / 2
    ang = [math.pi / 6 + i * math.pi / 3 for i in range(6)]
    for sx in (-1, 1):
        xc = sx * X_POSTE
        # Postes presos por fora da longarina, descendo 4 cm abaixo dela.
        for k in range(1, N_SEG):
            z, yd = Z_K[k], Y_K[k]
            caixa(M, xc - h, xc + h, yd - ESP_TAB + 0.02 - ALT_LONG - 0.04,
                  yd + CORR_BASE + 0.06, z - h, z + h, ESCURA)
        zs = [-Z_PILAR] + Z_K[1:N_SEG] + [Z_PILAR]
        # Corrimão sobre os postes, de pilar a pilar.
        M.loft([[Vector((xc + .08, deck(z) + CORR_TOPO, z)), Vector((xc - .08, deck(z) + CORR_TOPO, z)),
                 Vector((xc - .08, deck(z) + CORR_BASE, z)), Vector((xc + .08, deck(z) + CORR_BASE, z))]
                for z in zs], CLARA)
        # Corda a meia altura, atravessando os postes e caindo um pouco em cada vão.
        est = []
        for a, b in zip(zs[:-1], zs[1:]):
            est.append((a, deck(a) + CORDA_Y))
            est.append(((a + b) / 2, (deck(a) + deck(b)) / 2 + CORDA_Y - 0.035 * (b - a)))
        est.append((zs[-1], deck(zs[-1]) + CORDA_Y))
        M.loft([[Vector((xc + CORDA_R * math.cos(t), y + CORDA_R * math.sin(t), z)) for t in ang]
                for z, y in est], CORDA)


def cavalete(M, zt):
    yd = deck(zt)
    topo = yd - ESP_TAB + 0.02 - ALT_LONG + 0.06   # travessa entra 6 cm nas longarinas
    yc0 = topo - 0.34
    caixa(M, -X_MAX, X_MAX, yc0, topo, zt - .17, zt + .17, ESCURA)
    ytp = yc0 + 0.05

    def xe(y):  # eixo da perna externa (inclinada: 2,75 no leito, 2,08 sob a longarina)
        return 2.75 + (2.08 - 2.75) * (y - Y_FUNDO) / (ytp - Y_FUNDO)
    h = 0.14
    for sx in (-1, 1):
        M.loft([[Vector((sx * xe(y) + a, y, zt + b)) for a, b in contorno(h, h, 0)]
                for y in (Y_FUNDO, ytp)], ESCURA)
        caixa(M, sx * .70 - h, sx * .70 + h, Y_FUNDO, ytp, zt - h, zt + h, ESCURA)
        yk = yc0 - 1.1
        for dz in (-1.6, 1.6):   # mãos-francesas no plano lateral: desenham o leque na silhueta
            yl = deck(zt + dz) - ESP_TAB + 0.02 - ALT_LONG + 0.06
            viga(M, (sx * xe(yk), yk, zt), (sx * 2.08, yl, zt + dz), .16, .16, (1, 0, 0), ESCURA)
        # Escora externa: ponta da travessa -> poste do guarda-corpo.
        viga(M, (sx * 2.84, yc0 + .17, zt), (sx * 2.33, yd + .55, zt), .14, .14, (0, 0, 1), ESCURA)
    yw = -1.25   # travessa baixa na face -Z, cruz de São André na face +Z
    caixa(M, -(xe(yw) + .30), xe(yw) + .30, yw - .11, yw + .11, zt - .22, zt - .12, ESCURA)
    ya, yb = -2.55, yc0 - .20
    for sx in (-1, 1):
        viga(M, (-sx * xe(ya), ya, zt + .16), (sx * xe(yb), yb, zt + .16), .20, .08, (0, 0, 1), ESCURA)


def bloco(M, sz, x0, x1, y0, ytopo, z0, z1, mat, c=0.07, ct=0.07, jit=0.025):
    """Pedra facetada: arestas verticais e do topo chanfradas, cantos com jitter.
    Autoria em z' = |z| (entre 13 e 17); sz espelha para a cabeceira do lado certo."""
    cx, cz, hx, hz = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2

    def anel(d, yf, j, jy):
        pts = []
        for a, b in contorno(hx - d, hz - d, c):
            x = min(X_MAX, max(-X_MAX, cx + a + rng.uniform(-j, j)))
            z = min(L2, max(Z_CAB, cz + b + rng.uniform(-j, j)))
            pts.append(Vector((x, yf(z) - rng.uniform(0, jy), sz * z)))
        return pts
    M.loft([anel(0, lambda z: y0, jit * .5, 0),
            anel(0, lambda z: ytopo(z) - ct, jit, jit * .6),
            anel(ct, ytopo, jit * .6, jit * .6)], mat)


def pilar(M, x, z):
    zl = abs(z)
    y0 = deck(zl) - 0.07 - 0.10          # entra 10 cm no capeamento
    yb = deck(zl) + 1.24
    M.loft([[Vector((x + a, y, z + b)) for a, b in contorno(.29, .29, .06)] for y in (y0, yb)], PEDRA)
    M.loft([[Vector((x + a, y, z + b)) for a, b in contorno(.35, .35, 0)] for y in (yb - .06, yb + .06)],
           PEDRA_CL, apice=(x, yb + .26, z))


def cabeceira(M, sz):
    """Cabeceira de pedra em três fiadas recuadas (talude), de y=-2,5 até sob as tábuas."""
    def topo(z):  # 7 cm abaixo do deck: entra 3 a 5,4 cm na face de baixo das tábuas
        return deck(z) - 0.07
    fiadas = [  # (base, topo, frente z', fundo da fileira da frente, divisões em x)
        (-2.50, -1.60, 13.00, 14.60, [-3.0, -1.05, 0.95, 3.0]),
        (-1.63, -0.70, 13.12, 14.45, [-3.0, -1.95, 0.05, 2.0, 3.0]),
        (-0.73, None, 13.24, 14.875, [-3.0, -0.90, 1.10, 3.0]),   # capeamento segue o arco
    ]
    sob = 0.04
    for y0, y1, zf, zt, xs in fiadas:
        ytopo = topo if y1 is None else (lambda z, y1=y1: y1)
        xs = [xs[0]] + [x + rng.uniform(-.22, .22) for x in xs[1:-1]] + [xs[-1]]
        for i in range(len(xs) - 1):
            mat = PEDRA_CL if y1 is None else rng.choices((PEDRA, PEDRA_CL), (3, 2))[0]
            bloco(M, sz, xs[i] - (sob if i else 0), xs[i + 1] + (sob if i < len(xs) - 2 else 0),
                  y0, ytopo, zf, zt + sob, mat)
        # Fileira de trás: dois blocos por fiada ao longo de z, para a lateral (x = ±3) ler
        # como alvenaria e não como laje lisa; ocupam a largura toda (o miolo fica escondido).
        zm = (zt + L2) / 2 + rng.uniform(-.25, .25)
        for za, zb in ((zt - sob, zm + sob), (zm - sob, L2)):
            mat = PEDRA if y1 is not None else rng.choices((PEDRA, PEDRA_CL), (1, 1))[0]
            bloco(M, sz, -X_MAX, X_MAX, y0, ytopo, za, zb, mat)
    for sx in (-1, 1):
        pilar(M, sx * X_PILAR, sz * Z_PILAR)


def construir():
    M = Malha()
    tabuas(M)
    longarinas(M)
    guarda_corpos(M)
    for zt in Z_CAVALETES:
        cavalete(M, zt)
    for sz in (-1, 1):
        cabeceira(M, sz)
    return M


def construir_colisao():
    """Malha de colisão: 3 sólidos fechados e nada mais.
    Piso: topo = a mesma linha poligonal do deck visual (os 17 vértices do arco; as estações
    intermediárias do visual são colineares a ela), sem nenhum vértice no interior do topo.
    Paredes: |x| de 2,2 a 2,35, do fundo do piso até 1,10 m acima do deck, abertas nas pontas;
    não têm vértice na altura do piso (a face interna vai inteira de y-0,30 a y+1,10)."""
    C = Malha()

    def anel(x0, x1, y0, y1, z):
        return [Vector((x1, y1, z)), Vector((x0, y1, z)), Vector((x0, y0, z)), Vector((x1, y0, z))]
    C.loft([anel(-X_COL, X_COL, Y_K[k] - ESP_COL, Y_K[k], Z_K[k]) for k in range(N_SEG + 1)], 0)
    zs = [-Z_PAREDE] + Z_K[1:N_SEG] + [Z_PAREDE]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * X_COL, sx * (X_COL + ESP_PAREDE)))
        C.loft([anel(x0, x1, deck(z) - ESP_COL, deck(z) + CORR_TOPO, z) for z in zs], 0)
    return C


# ---------------------------------------------------------------- objeto, materiais, saída
def criar_objeto(M):
    me = bpy.data.meshes.new('Ponte_rio')
    me.from_pydata([v(*p) for p in M.v], [], M.f)
    me.update()
    obj = bpy.data.objects.new('Ponte_rio_low_poly', me)
    bpy.context.scene.collection.objects.link(obj)
    for nome, cor in MATERIAIS:
        mat = bpy.data.materials.new(nome)
        mat.diffuse_color = (*cor, 1)
        if bpy.app.version < (5, 0, 0):   # no Blender 5 o material já nasce com nós
            mat.use_nodes = True
        bs = mat.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value = (*cor, 1)
        bs.inputs['Roughness'].default_value = .92
        mat.roughness = .92
        # Todas as peças são sólidos fechados: sem dupla face (como o kit da loja). Face
        # invertida aparece como buraco no Godot em vez de ficar mascarada.
        mat.use_backface_culling = True
        me.materials.append(mat)
    for p, mi in zip(me.polygons, M.m):
        p.material_index = mi
        p.use_smooth = False
    normais_para_fora(obj)
    return obj


def normais_para_fora(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')


def criar_colisao(C):
    """Objeto e malha chamados 'Colisao': a loja reconhece pelo prefixo do nome."""
    me = bpy.data.meshes.new('Colisao')
    me.from_pydata([v(*p) for p in C.v], [], C.f)
    me.update()
    obj = bpy.data.objects.new('Colisao', me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new('Colisao')
    mat.diffuse_color = (0.5, 0.5, 0.5, 1)
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (0.5, 0.5, 0.5, 1)
    mat.use_backface_culling = True
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    normais_para_fora(obj)
    return obj


def ler_glb(caminho):
    dados = caminho.read_bytes()
    n = struct.unpack('<I', dados[12:16])[0]
    j = json.loads(dados[20:20 + n])
    malhas = {}
    for mesh in j['meshes']:
        tris, mn, mx = 0, [math.inf] * 3, [-math.inf] * 3
        for pr in mesh['primitives']:
            tris += j['accessors'][pr['indices']]['count'] // 3
            pos = j['accessors'][pr['attributes']['POSITION']]
            mn = [min(a, b) for a, b in zip(mn, pos['min'])]
            mx = [max(a, b) for a, b in zip(mx, pos['max'])]
        malhas[mesh['name']] = {'triangulos': tris, 'min': mn, 'max': mx,
                                'superficies': len(mesh['primitives'])}
    nos = [{k: no[k] for k in ('name', 'mesh', 'translation', 'rotation', 'scale') if k in no}
           for no in j['nodes']]
    return {'malhas': malhas, 'materiais': [m['name'] for m in j['materials']], 'nos': nos}


def medir(obj, M):
    me = obj.data
    # 1) Normais: cada ilha fechada deve ter volume positivo (faces para fora).
    ilhas, neg, abertas = fechamento(me)
    # 2) Topo do deck por raios verticais no vão útil (|x| <= 2,1), z a cada 1 cm.
    #    Degrau = descontinuidade entre vizinhos depois de descontar a rampa do arco
    #    (resíduo y_raio - deck(z)). A diferença bruta entre vizinhos também é registrada:
    #    num deck liso ela é só a inclinação (<= tan 12,2° x 1 cm = 2,16 mm) e encolhe
    #    junto com o passo (varredura fina de 1 mm em x = -2,1, 0 e 2,1).
    bvh = BVHTree.FromPolygons([vv.co for vv in me.vertices], [p.vertices for p in me.polygons])
    xs = [round(-2.1 + 0.1 * i, 2) for i in range(43)]
    zs = [round(-16.995 + 0.01 * i, 3) for i in range(3400)]
    degrau, bruto, desvio, frestas, onde, ny_raio = 0.0, 0.0, 0.0, 0, None, 1.0
    for x in xs:
        ant = None
        for z in zs:
            loc, nor, _, _ = bvh.ray_cast(Vector(v(x, 10.0, z)), Vector((0, 0, -1)))
            if loc is None or loc.z < deck(z) - 0.05:
                frestas += 1
                ant = None
                continue
            r = loc.z - deck(z)
            desvio, ny_raio = max(desvio, abs(r)), min(ny_raio, abs(nor.z))
            if ant is not None:
                if abs(r - ant[0]) > degrau:
                    degrau, onde = abs(r - ant[0]), (x, z)
                bruto = max(bruto, abs(loc.z - ant[1]))
            ant = (r, loc.z)
    bruto_fino = 0.0
    for x in (-2.1, 0.0, 2.1):
        ant = None
        for j in range(33999):
            y = bvh.ray_cast(Vector(v(x, 10.0, -16.999 + 0.001 * j)), Vector((0, 0, -1)))[0].z
            if ant is not None:
                bruto_fino = max(bruto_fino, abs(y - ant))
            ant = y
    # 3) Faces do topo: cruzam a faixa |x| <= 2,1 e encostam na superfície do deck (algum
    #    vértice a menos de 5 mm de deck(z)). As tampas da laje em z = ±17 (a espessura da
    #    ponta, que fica sob a terra) são contadas à parte.
    topo, pontas = [], 0
    for p in me.polygons:
        co = [me.vertices[i].co for i in p.vertices]
        if min(c.x for c in co) > 2.1 or max(c.x for c in co) < -2.1:
            continue
        if not any(c.z >= deck(-c.y) - 0.005 for c in co if abs(c.y) <= L2):
            continue
        if all(abs(abs(c.y) - L2) < 1e-6 for c in co):
            pontas += 1
            continue
        topo.append(abs(p.normal.z))

    def y_deck(x, z):
        return bvh.ray_cast(Vector(v(x, 10.0, z)), Vector((0, 0, -1)))[0].z
    incl_faces = max(math.degrees(math.acos(min(1.0, p.normal.z))) for p in me.polygons
                     if p.material_index in (CLARA, MEDIA) and abs(p.center.x) < 2.15 and p.normal.z > .5)
    incl_arco = max(math.degrees(math.atan(abs(Y_K[k + 1] - Y_K[k]) / PASSO)) for k in range(N_SEG))
    ys = [vv.co.z for vv in me.vertices]
    return {
        'ilhas': ilhas, 'ilhas_volume_negativo': neg, 'arestas_abertas_ou_nao_manifold': abertas,
        'triangulos_malha': sum(len(p.vertices) - 2 for p in me.polygons),
        'menor_y_vertice': round(min(ys), 4), 'maior_y_vertice': round(max(ys), 4),
        'deck_y_ponta_menos_z': round(y_deck(0.0, -16.999), 4),
        'deck_y_ponta_mais_z': round(y_deck(0.0, 16.999), 4),
        'deck_y_meio': round(y_deck(0.0, 0.0), 4),
        'deck_amostras': len(xs) * len(zs), 'deck_frestas': frestas,
        'deck_maior_degrau_m': round(degrau, 7), 'deck_maior_degrau_em_xz': onde,
        'deck_maior_desvio_do_arco_m': round(desvio, 7),
        'deck_maior_diferenca_bruta_vizinhos_1cm_m': round(bruto, 5),
        'deck_maior_diferenca_bruta_vizinhos_1mm_m': round(bruto_fino, 6),
        'deck_menor_normal_y_nos_raios': round(ny_raio, 4),
        'deck_faces_topo': len(topo), 'deck_faces_topo_normal_y_min': round(min(topo), 4),
        'deck_faces_topo_normal_y_abaixo_0_9': sum(1 for n in topo if n < 0.9),
        'deck_faces_verticais_nas_pontas_z17': pontas,
        'deck_inclinacao_max_faces_graus': round(incl_faces, 2),
        'arco_inclinacao_max_trechos_graus': round(incl_arco, 2),
        'vao_util_entre_postes_m': round(2 * (X_POSTE - LADO_POSTE / 2), 3),
        'corrimao_acima_do_deck_m': CORR_TOPO,
    }


def fechamento(me):
    """(ilhas, ilhas com volume <= 0, arestas com != 2 faces) de uma malha."""
    pai = list(range(len(me.vertices)))

    def raiz(a):
        while pai[a] != a:
            pai[a] = pai[pai[a]]
            a = pai[a]
        return a
    for p in me.polygons:
        r = raiz(p.vertices[0])
        for i in p.vertices[1:]:
            ri = raiz(i)
            if ri != r:
                pai[ri] = r
    vol = defaultdict(float)
    arestas = defaultdict(int)
    for p in me.polygons:
        co = [me.vertices[i].co for i in p.vertices]
        for i in range(1, len(co) - 1):
            vol[raiz(p.vertices[0])] += co[0].dot(co[i].cross(co[i + 1])) / 6
        for e in p.edge_keys:
            arestas[e] += 1
    return len(vol), sum(1 for x in vol.values() if x <= 0), sum(1 for n in arestas.values() if n != 2)


def medir_colisao(col, vis):
    """Topo do Colisao contra o topo do deck visual, pelos mesmos raios (|x| <= 2,1, 1 cm)."""
    mc, mv = col.data, vis.data
    ilhas, neg, abertas = fechamento(mc)
    bc = BVHTree.FromPolygons([vv.co for vv in mc.vertices], [p.vertices for p in mc.polygons])
    bv = BVHTree.FromPolygons([vv.co for vv in mv.vertices], [p.vertices for p in mv.polygons])
    dif, falhas, ny = 0.0, 0, 1.0
    for i in range(43):
        x = round(-2.1 + 0.1 * i, 2)
        for j in range(3400):
            z = round(-16.995 + 0.01 * j, 3)
            hc = bc.ray_cast(Vector(v(x, 10.0, z)), Vector((0, 0, -1)))
            hv = bv.ray_cast(Vector(v(x, 10.0, z)), Vector((0, 0, -1)))
            if hc[0] is None or hv[0] is None:
                falhas += 1
                continue
            dif, ny = max(dif, abs(hc[0].z - hv[0].z)), min(ny, abs(hc[1].z))
    co = [vv.co for vv in mc.vertices]
    paredes = [c for c in co if abs(c.x) > X_COL + 1e-6]
    altura = [c.z - deck(-c.y) for c in paredes if c.z > deck(-c.y)]
    return {
        'triangulos': sum(len(p.vertices) - 2 for p in mc.polygons),
        'ilhas': ilhas, 'ilhas_volume_negativo': neg, 'arestas_abertas_ou_nao_manifold': abertas,
        'vertices_no_interior_do_topo': sum(1 for c in co if abs(c.x) < X_COL - 1e-6),
        'topo_diferenca_max_para_deck_visual_m': round(dif, 7),
        'topo_amostras': 43 * 3400, 'topo_raios_sem_acerto': falhas,
        'topo_menor_normal_y': round(ny, 4),
        'piso_x': [-X_COL, X_COL], 'piso_espessura_m': ESP_COL,
        'paredes_x_abs': [X_COL, X_COL + ESP_PAREDE], 'paredes_z': [-Z_PAREDE, Z_PAREDE],
        'paredes_altura_acima_do_deck_m': [round(min(altura), 4), round(max(altura), 4)],
    }


# ---------------------------------------------------------------- capturas (não vão para o GLB)
def camera(nome, loc, alvo, lente=35.0, orto=None, up=(0, 1, 0)):
    dados = bpy.data.cameras.new(nome)
    if orto:
        dados.type, dados.ortho_scale = 'ORTHO', orto
    else:
        dados.lens = lente
    dados.clip_start, dados.clip_end = 0.05, 500
    cam = bpy.data.objects.new(nome, dados)
    bpy.context.scene.collection.objects.link(cam)
    orientar(cam, loc, alvo, up)
    return cam


def orientar(obj, loc, alvo, up=(0, 1, 0)):
    """Aponta o -Z local (câmera ou sol) de loc para alvo, em coordenadas do Godot."""
    pos, al, upb = Vector(v(*loc)), Vector(v(*alvo)), Vector(v(*up))
    f = (al - pos).normalized()
    r = f.cross(upb).normalized()
    u = r.cross(f)
    obj.matrix_world = Matrix.Translation(pos) @ Matrix((r, u, -f)).transposed().to_4x4()


def capsula(x, z):
    """Cápsula de 1,6 m (raio 0,3) em pé sobre o deck: referência de escala humana."""
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.3)
    for vert in bm.verts:
        if vert.co.z > 1e-6:
            vert.co.z += 1.0
        vert.co.z += 0.3
    me = bpy.data.meshes.new('Capsula_1_6m')
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.new('Capsula')
    mat.diffuse_color = (0.95, 0.32, 0.06, 1)
    if bpy.app.version < (5, 0, 0):
        mat.use_nodes = True
    mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (0.95, 0.32, 0.06, 1)
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    obj = bpy.data.objects.new('Capsula_1_6m', me)
    obj.location = v(x, deck(z), z)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def capturar(vis, col):
    VALID.mkdir(parents=True, exist_ok=True)
    col.hide_render = True              # o Colisao não aparece no jogo nem nas capturas 01-06
    sc = bpy.context.scene
    # EEVEE com um sol fixo e céu ambiente: luz parecida com a do jogo (a 'studio' do
    # Workbench acompanha a câmera e falseia o deck visto de perto). O backface culling
    # dos materiais vale aqui também: face invertida apareceria como buraco.
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = 32
    sc.view_settings.view_transform = 'Standard'
    ceu = bpy.data.worlds.new('Ceu')
    if bpy.app.version < (5, 0, 0):
        ceu.use_nodes = True
    fundo = ceu.node_tree.nodes.get('Background')
    fundo.inputs['Color'].default_value = (0.55, 0.66, 0.78, 1)
    fundo.inputs['Strength'].default_value = 0.55
    sc.world = ceu
    sol = bpy.data.objects.new('Sol', bpy.data.lights.new('Sol', 'SUN'))
    sol.data.energy, sol.data.angle = 2.4, math.radians(3)
    sc.collection.objects.link(sol)
    orientar(sol, (10, 14, -7), (0, 0, 0))
    sc.render.image_settings.file_format = 'PNG'
    capsula(0.9, -1.6)
    tomadas = [
        ('01_tres_quartos_alto', camera('c1', (19, 12, -24), (0, -0.2, 0), 30), (1600, 900)),
        ('02_lateral', camera('c2', (45, 0.15, 0), (0, 0.15, 0), orto=37.0), (1920, 760)),
        ('03_topo', camera('c3', (0, 40, 0), (0, 0, 0), orto=37.0, up=(1, 0, 0)), (1920, 760)),
        ('04_deck_perto', camera('c4', (-1.0, deck(-11) + 1.65, -11), (0.6, deck(-2) + 0.9, -2), 24),
         (1600, 900)),
        ('05_baixo_rio', camera('c5', (12, -2.3, -10), (0, -0.6, -1.5), 22), (1600, 900)),
        ('06_tres_quartos_oposto', camera('c6', (-18, 7, 21), (0, -0.4, 0), 30), (1600, 900)),
    ]
    renderizar(sc, tomadas)
    # 07: só o Colisao (cinza chapado). 08: Colisao em arame magenta sobre a ponte, perto do
    # cavalete de z = -6,375 e do fim da cabeceira, onde a caixa travava no trimesh antigo.
    col.hide_render, vis.hide_render = False, True
    renderizar(sc, [('07_colisao_sozinha', camera('c7', (19, 12, -24), (0, -0.2, 0), 30), (1600, 900))])
    arame = bpy.data.materials.new('Colisao_arame')
    if bpy.app.version < (5, 0, 0):
        arame.use_nodes = True
    bs = arame.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (1.0, 0.05, 0.6, 1)
    bs.inputs['Emission Color'].default_value = (1.0, 0.05, 0.6, 1)
    bs.inputs['Emission Strength'].default_value = 1.5
    col.data.materials[0] = arame
    mod = col.modifiers.new('Arame', 'WIREFRAME')
    mod.thickness, mod.use_replace = 0.03, True
    vis.hide_render = False
    renderizar(sc, [('08_colisao_sobre_ponte', camera('c8', (8.5, 5.5, -16.5), (0, 0.6, -8.5), 26),
                     (1600, 900))])


def renderizar(sc, tomadas):
    for nome, cam, (rx, ry) in tomadas:
        sc.camera = cam
        sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = rx, ry, 100
        sc.render.filepath = str(VALID / (nome + '.png'))
        bpy.ops.render.render(write_still=True)
        print('CAPTURA', sc.render.filepath)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = construir()
    obj = criar_objeto(M)
    col = criar_colisao(construir_colisao())
    FONTE.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0   # sem ponte_rio.blend1 de backup
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (obj, col))
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', use_selection=True, export_yup=True)
    medidas = medir(obj, M)
    medidas['colisao'] = medir_colisao(col, obj)
    medidas['glb'] = ler_glb(GLB)
    g = medidas['glb']['malhas']['Ponte_rio']        # caixa do VISUAL (o Colisao fica fora dela)
    medidas['caixa_tamanho'] = [round(b - a, 4) for a, b in zip(g['min'], g['max'])]
    medidas['altura_pontas_deck_desde_fundo_caixa'] = round(medidas['deck_y_ponta_mais_z'] - g['min'][1], 4)
    VALID.mkdir(parents=True, exist_ok=True)
    (VALID / 'medidas.json').write_text(json.dumps(medidas, indent=2, ensure_ascii=False) + '\n')
    print('PONTE_EXPORTADA', json.dumps(medidas, ensure_ascii=False))
    if CAPTURAR:
        capturar(obj, col)

main()
