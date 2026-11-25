#!/usr/bin/env python3
"""Converte um personagem do Mine Piece (GeckoLib/Bedrock) num .glb para o Godot.

    python3 -I tools/mine_piece/geo_para_glb.py [--fonte DIR] [--ficha ARQ] [--saida DIR] [--so ID ...]

Para cada personagem da ficha (`extrair_east_blue.py`) monta:
  • o corpo: `geo/<x>.geo.json` + a textura da entidade;
  • as roupas: o geo e a textura do item de cada slot (cabeça, peito, pernas, pés), presos
    aos ossos `armor*` do corpo, como o GeckoLib faz;
  • a arma da mão principal: o modelo de item Java (`elements`) ou o sprite extrudado;
  • as animações do `.animation.json`, amostradas a 20 quadros/s (Molang avaliado).
Gera nós rígidos (um nó por osso, malha de cubos) e animação por nó — o Minecraft não usa
skinning. Unidade: 16 px = 1 m. Frente: −Z (a do Godot).

PROVISÓRIO (decisão do dono, 17/10/2026): a arte é do mod e fica fora do git; a saída padrão
é `build/mine_piece/mp_<id>.glb` (ignorada); `registrar_na_loja.gd` os põe na loja do editor.
"""
import argparse
import base64
import json
import math
import os
import re
import struct
import sys
import zlib

FONTE = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
QPS = 20                              # quadros por segundo das animações
SLOTS_DE_ROUPA = {                    # slot do item → ossos do geo de roupa que ele desenha
    "HEAD": ["armorHead"], "CHEST": ["armorBody", "armorRightArm", "armorLeftArm"],
    "LEGS": ["armorRightLeg", "armorLeftLeg"], "FEET": ["armorRightBoot", "armorLeftBoot"],
}


# ------------------------------------------------------------------ matemática

def quat_euler_zyx(rx, ry, rz):
    """Graus → quaternion (x, y, z, w) de M = Rz · Ry · Rx (a ordem do Blockbench)."""
    hx, hy, hz = (math.radians(a) * 0.5 for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(hx), math.sin(hx), math.cos(hy), math.sin(hy), math.cos(hz), math.sin(hz)
    # q = qz * qy * qx
    w = cz * cy * cx + sz * sy * sx
    x = cz * cy * sx - sz * sy * cx
    y = cz * sy * cx + sz * cy * sx
    z = sz * cy * cx - cz * sy * sx
    return (x, y, z, w)


def rot_ponto(p, rx, ry, rz, piv):
    """Gira `p` em torno de `piv` pela mesma ordem (Rz·Ry·Rx)."""
    x, y, z = p[0] - piv[0], p[1] - piv[1], p[2] - piv[2]
    a = math.radians(rx)
    y, z = y * math.cos(a) - z * math.sin(a), y * math.sin(a) + z * math.cos(a)
    a = math.radians(ry)
    x, z = x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)
    a = math.radians(rz)
    x, y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
    return (x + piv[0], y + piv[1], z + piv[2])


# ------------------------------------------------------------------ Molang (subconjunto)

_MOLANG_FUNC = {
    "math.sin": lambda a: math.sin(math.radians(a)), "math.cos": lambda a: math.cos(math.radians(a)),
    "math.abs": abs, "math.sqrt": lambda a: math.sqrt(max(a, 0.0)), "math.pow": lambda a, b: math.pow(a, b),
    "math.clamp": lambda a, lo, hi: max(lo, min(hi, a)), "math.lerp": lambda a, b, t: a + (b - a) * t,
    "math.min": min, "math.max": max, "math.floor": math.floor, "math.ceil": math.ceil,
    "math.round": round, "math.mod": lambda a, b: math.fmod(a, b) if b else 0.0, "math.exp": math.exp,
    "math.pi": math.pi, "math.random": lambda a=0.0, b=1.0: (a + b) * 0.5,
}
_cache_molang = {}


def _avaliar(no, tempo, funcs):
    """Avalia a AST de uma expressão Molang SEM eval: só números, operadores, condicionais,
    as funções de `_MOLANG_FUNC` e variáveis `Q_*` (a expressão vem de arquivo do mod)."""
    import ast
    if isinstance(no, ast.Expression):
        return _avaliar(no.body, tempo, funcs)
    if isinstance(no, ast.Constant) and isinstance(no.value, (int, float, bool)):
        return float(no.value)
    if isinstance(no, ast.Name):
        if no.id in ("Q_anim_time", "Q_life_time"):
            return tempo
        if no.id.startswith("Q_"):
            return 0.0
        if no.id == "math_pi":
            return math.pi
        raise ValueError(no.id)
    if isinstance(no, ast.UnaryOp):
        v = _avaliar(no.operand, tempo, funcs)
        return -v if isinstance(no.op, ast.USub) else (float(not v) if isinstance(no.op, ast.Not) else v)
    if isinstance(no, ast.BinOp):
        a, b = _avaliar(no.left, tempo, funcs), _avaliar(no.right, tempo, funcs)
        op = type(no.op)
        if op is ast.Add: return a + b
        if op is ast.Sub: return a - b
        if op is ast.Mult: return a * b
        if op is ast.Div: return a / b if b else 0.0
        if op is ast.Mod: return math.fmod(a, b) if b else 0.0
        if op is ast.Pow: return a ** b
        raise ValueError(op)
    if isinstance(no, ast.BoolOp):
        vals = [_avaliar(v, tempo, funcs) for v in no.values]
        return float(all(vals) if isinstance(no.op, ast.And) else any(vals))
    if isinstance(no, ast.Compare) and len(no.ops) == 1:
        a, b = _avaliar(no.left, tempo, funcs), _avaliar(no.comparators[0], tempo, funcs)
        op = type(no.ops[0])
        return float({ast.Lt: a < b, ast.LtE: a <= b, ast.Gt: a > b, ast.GtE: a >= b, ast.Eq: a == b, ast.NotEq: a != b}[op])
    if isinstance(no, ast.IfExp):
        return _avaliar(no.body if _avaliar(no.test, tempo, funcs) else no.orelse, tempo, funcs)
    if isinstance(no, ast.Call) and isinstance(no.func, ast.Name) and no.func.id in funcs and not no.keywords:
        return float(funcs[no.func.id](*[_avaliar(a, tempo, funcs) for a in no.args]))
    raise ValueError(type(no).__name__)


def molang(expr, t):
    """Avalia um número ou expressão Molang no tempo t (s). Variável desconhecida = 0;
    expressão que não se entende = 0 (o osso fica na pose de repouso naquele eixo)."""
    import ast
    if isinstance(expr, (int, float)):
        return float(expr)
    texto = str(expr).strip().lower()
    if texto not in _cache_molang:
        py = texto.replace("math.", "math_")
        py = re.sub(r"\b(query|q|variable|v|temp|t|context|c)\.(\w+)", lambda m: "Q_" + m.group(2), py)
        py = py.replace("&&", " and ").replace("||", " or ")
        py = re.sub(r"!(?!=)", " not ", py)
        m = re.match(r"^(.+?)\?(.+):(.+)$", py)
        if m:
            py = f"({m.group(2)}) if ({m.group(1)}) else ({m.group(3)})"
        try:
            _cache_molang[texto] = ast.parse(py.rstrip(";"), mode="eval")
        except SyntaxError:
            _cache_molang[texto] = None
    arvore = _cache_molang[texto]
    if arvore is None:
        return 0.0
    try:
        return _avaliar(arvore, t, {k.replace(".", "_"): v for k, v in _MOLANG_FUNC.items()})
    except (ValueError, TypeError, OverflowError, ZeroDivisionError, KeyError):
        return 0.0


def vetor(v, t):
    if isinstance(v, dict):
        v = v.get("vector", v.get("post", v.get("pre", [0, 0, 0])))
        if isinstance(v, dict):
            v = v.get("vector", [0, 0, 0])
    if not isinstance(v, list):
        v = [v, v, v]
    return [molang(c, t) for c in (list(v) + [0, 0, 0])[:3]]


def amostrar(trilha, t):
    """Valor [x, y, z] de uma trilha Bedrock (constante ou quadros-chave) no tempo t."""
    if not isinstance(trilha, dict) or "vector" in trilha or not trilha:
        return vetor(trilha, t)
    chaves = sorted(((float(k), v) for k, v in trilha.items() if re.match(r"^-?[\d.]+$", str(k))), key=lambda kv: kv[0])
    if not chaves:
        return vetor(trilha, t)
    if t <= chaves[0][0]:
        return vetor(chaves[0][1], t)
    for (t0, v0), (t1, v1) in zip(chaves, chaves[1:]):
        if t0 <= t <= t1:
            a = vetor(v0.get("post", v0) if isinstance(v0, dict) else v0, t)
            b = vetor(v1.get("pre", v1) if isinstance(v1, dict) else v1, t)
            u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            if isinstance(v1, dict) and v1.get("lerp_mode") == "step":
                u = 0.0
            return [a[i] + (b[i] - a[i]) * u for i in range(3)]
    return vetor(chaves[-1][1], t)


# ------------------------------------------------------------------ malha

class Malha:
    """Triângulos por material: {material: (posições, normais, uvs, índices)}."""
    def __init__(self):
        self.partes = {}

    def quad(self, mat, cantos, normal, uvs):
        pos, nor, uv, idx = self.partes.setdefault(mat, ([], [], [], []))
        base = len(pos)
        pos.extend(cantos)
        nor.extend([normal] * 4)
        uv.extend(uvs)
        idx.extend([base, base + 1, base + 2, base, base + 2, base + 3])

    def vazia(self):
        return not self.partes


def faces_box_uv(u, v, sx, sy, sz, espelho):
    sx, sy, sz = math.floor(sx + 1e-6), math.floor(sy + 1e-6), math.floor(sz + 1e-6)
    f = {
        "north": [u + sz, v + sz, u + sz + sx, v + sz + sy],
        "east": [u, v + sz, u + sz, v + sz + sy],
        "south": [u + 2 * sz + sx, v + sz, u + 2 * sz + 2 * sx, v + sz + sy],
        "west": [u + sz + sx, v + sz, u + 2 * sz + sx, v + sz + sy],
        "up": [u + sz, v, u + sz + sx, v + sz],
        "down": [u + sz + sx, v + sz, u + sz + 2 * sx, v],
    }
    if espelho:
        f = {k: [r[2], r[1], r[0], r[3]] for k, r in f.items()}
        f["east"], f["west"] = f["west"], f["east"]
    return f


def cubo(malha, mat, de, ate, faces_uv, tex_w, tex_h, rot=None, piv=None, origem_osso=(0, 0, 0)):
    """Cubo de `de` a `ate` (px, espaço Blockbench) com UVs por face, girado e relativo ao osso."""
    x0, y0, z0 = de
    x1, y1, z1 = ate
    # Cantos de cada face vistos de fora: sup-esq, sup-dir, inf-dir, inf-esq.
    defs = {
        "north": ([(x1, y1, z0), (x0, y1, z0), (x0, y0, z0), (x1, y0, z0)], (0, 0, -1)),
        "south": ([(x0, y1, z1), (x1, y1, z1), (x1, y0, z1), (x0, y0, z1)], (0, 0, 1)),
        "east": ([(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)], (1, 0, 0)),
        "west": ([(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)], (-1, 0, 0)),
        "up": ([(x1, y1, z1), (x0, y1, z1), (x0, y1, z0), (x1, y1, z0)], (0, 1, 0)),
        "down": ([(x1, y0, z0), (x0, y0, z0), (x0, y0, z1), (x1, y0, z1)], (0, -1, 0)),
    }
    for nome, (cantos, normal) in defs.items():
        r = faces_uv.get(nome)
        if r is None:
            continue
        u0, v0, u1, v1 = r
        if u0 == u1 or v0 == v1:
            continue
        uvs = [(u0 / tex_w, v0 / tex_h), (u1 / tex_w, v0 / tex_h), (u1 / tex_w, v1 / tex_h), (u0 / tex_w, v1 / tex_h)]
        if rot is not None and any(rot):
            cantos = [rot_ponto(c, rot[0], rot[1], rot[2], piv) for c in cantos]
            normal = rot_ponto(normal, rot[0], rot[1], rot[2], (0, 0, 0))
        cantos = [((c[0] - origem_osso[0]) / 16.0, (c[1] - origem_osso[1]) / 16.0, (c[2] - origem_osso[2]) / 16.0) for c in cantos]
        malha.quad(mat, cantos, normal, uvs)


def cubos_bedrock(malha, mat, osso, tex_w, tex_h, origem_osso):
    for c in osso.get("cubes", []):
        o, s = c["origin"], c["size"]
        inf = float(c.get("inflate", 0.0))
        # Bedrock → Blockbench: x espelhado.
        de = [-(o[0] + s[0]) - inf, o[1] - inf, o[2] - inf]
        ate = [-o[0] + inf, o[1] + s[1] + inf, o[2] + s[2] + inf]
        uv = c.get("uv", [0, 0])
        if isinstance(uv, list):
            faces = faces_box_uv(uv[0], uv[1], s[0], s[1], s[2], bool(c.get("mirror", osso.get("mirror", False))))
        else:
            faces = {}
            for nome, f in uv.items():
                u, v = f["uv"]
                w, h = f.get("uv_size", [0, 0])
                faces[nome] = [u, v, u + w, v + h]
        rot, piv = None, None
        if "rotation" in c:
            r = c["rotation"]
            rot = [-r[0], -r[1], r[2]]
            p = c.get("pivot", [0, 0, 0])
            piv = [-p[0], p[1], p[2]]
        cubo(malha, mat, de, ate, faces, tex_w, tex_h, rot, piv, origem_osso)


def elementos_java(malha, materiais_por_textura, modelo, origem_osso, transformar):
    """Elementos de um modelo de bloco Java (0..16 px), cada ponto passado por `transformar`."""
    for el in modelo.get("elements", []):
        de, ate = el["from"], el["to"]
        rot = el.get("rotation")
        for nome, face in el.get("faces", {}).items():
            mat = materiais_por_textura.get(face.get("texture", "").lstrip("#"))
            if mat is None:
                continue
            u0, v0, u1, v1 = face.get("uv", [0, 0, 16, 16])
            x0, y0, z0 = de
            x1, y1, z1 = ate
            defs = {
                "north": [(x1, y1, z0), (x0, y1, z0), (x0, y0, z0), (x1, y0, z0)],
                "south": [(x0, y1, z1), (x1, y1, z1), (x1, y0, z1), (x0, y0, z1)],
                "east": [(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)],
                "west": [(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)],
                "up": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
                "down": [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
            }
            cantos = defs[nome]
            uvs = [(u0 / 16, v0 / 16), (u1 / 16, v0 / 16), (u1 / 16, v1 / 16), (u0 / 16, v1 / 16)]
            giro = int(face.get("rotation", 0)) // 90 % 4
            uvs = uvs[giro:] + uvs[:giro]
            if rot:
                eixo, ang, o = rot["axis"], float(rot["angle"]), rot["origin"]
                rr = {"x": (ang, 0, 0), "y": (0, ang, 0), "z": (0, 0, ang)}[eixo]
                cantos = [rot_ponto(c, rr[0], rr[1], rr[2], o) for c in cantos]
            pts = [transformar(c) for c in cantos]
            a, b, c = pts[0], pts[1], pts[2]
            n = ((b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]),
                 (b[2] - a[2]) * (c[0] - a[0]) - (b[0] - a[0]) * (c[2] - a[2]),
                 (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]))
            m = math.sqrt(sum(x * x for x in n)) or 1.0
            n = tuple(x / m for x in n)
            malha.quad(mat, [((p[0] - origem_osso[0]) / 16, (p[1] - origem_osso[1]) / 16, (p[2] - origem_osso[2]) / 16) for p in pts], n, uvs)


# ------------------------------------------------------------------ PNG (sprite extrudado)

def ler_png_rgba(caminho):
    with open(caminho, "rb") as f:
        dados = f.read()
    assert dados[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, w, h, tipo, prof, pal, trns = 8, b"", 0, 0, 0, 8, None, None
    while pos < len(dados):
        n = struct.unpack(">I", dados[pos:pos + 4])[0]
        nome = dados[pos + 4:pos + 8]
        bloco = dados[pos + 8:pos + 8 + n]
        if nome == b"IHDR":
            w, h, prof, tipo = struct.unpack(">IIBB", bloco[:10])
        elif nome == b"PLTE":
            pal = [tuple(bloco[i:i + 3]) for i in range(0, len(bloco), 3)]
        elif nome == b"tRNS":
            trns = bloco
        elif nome == b"IDAT":
            idat += bloco
        pos += 12 + n
    if prof != 8 or tipo not in (2, 3, 6, 4, 0):
        return None
    canais = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[tipo]
    cru = zlib.decompress(idat)
    linha = w * canais
    pixels, ant, p = [], [0] * linha, 0
    for _ in range(h):
        filtro = cru[p]
        atual = list(cru[p + 1:p + 1 + linha])
        p += 1 + linha
        for i in range(linha):
            a = atual[i - canais] if i >= canais else 0
            b, c = ant[i], (ant[i - canais] if i >= canais else 0)
            if filtro == 1: atual[i] = (atual[i] + a) & 255
            elif filtro == 2: atual[i] = (atual[i] + b) & 255
            elif filtro == 3: atual[i] = (atual[i] + (a + b) // 2) & 255
            elif filtro == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                atual[i] = (atual[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        row = []
        for x in range(w):
            px = atual[x * canais:(x + 1) * canais]
            if tipo == 6: row.append(tuple(px))
            elif tipo == 2: row.append((px[0], px[1], px[2], 255))
            elif tipo == 4: row.append((px[0], px[0], px[0], px[1]))
            elif tipo == 0: row.append((px[0], px[0], px[0], 255))
            else:
                cor = pal[px[0]]
                alfa = trns[px[0]] if trns is not None and px[0] < len(trns) else 255
                row.append((cor[0], cor[1], cor[2], alfa))
        pixels.append(row)
        ant = atual
    return w, h, pixels


def sprite_extrudado(malha, mat, png, origem_osso, transformar):
    """Item plano do Minecraft: cada pixel opaco vira um prisma de 1 px (frente/verso e bordas)."""
    lido = ler_png_rgba(png)
    if lido is None:
        return
    w, h, px = lido
    esc = 16.0 / w
    # Frente e verso: um quadrado cada, com a textura inteira (o alfa recorta, MASK).
    for cantos, n, uvs in (([(0, 16, 8.5), (16, 16, 8.5), (16, 0, 8.5), (0, 0, 8.5)], (0, 0, 1), [(0, 0), (1, 0), (1, 1), (0, 1)]),
                           ([(16, 16, 7.5), (0, 16, 7.5), (0, 0, 7.5), (16, 0, 7.5)], (0, 0, -1), [(1, 0), (0, 0), (0, 1), (1, 1)])):
        pts = [transformar(c) for c in cantos]
        nn, o = transformar((n[0] + 8, n[1] + 8, n[2] + 8)), transformar((8, 8, 8))
        nv = (nn[0] - o[0], nn[1] - o[1], nn[2] - o[2])
        m = math.sqrt(sum(a * a for a in nv)) or 1.0
        malha.quad(mat, [((p[0] - origem_osso[0]) / 16, (p[1] - origem_osso[1]) / 16, (p[2] - origem_osso[2]) / 16) for p in pts],
                   tuple(a / m for a in nv), uvs)
    def opaco(x, y):
        return 0 <= x < w and 0 <= y < h and px[y][x][3] > 8
    for y in range(h):
        for x in range(w):
            if not opaco(x, y):
                continue
            x0, x1 = x * esc, (x + 1) * esc
            y1, y0 = 16 - y * esc, 16 - (y + 1) * esc
            z0, z1 = 7.5, 8.5
            uv = [(x + 0.5) / w, (y + 0.5) / h]
            uvs = [tuple(uv)] * 4
            quads = []
            if not opaco(x - 1, y): quads.append(([(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)], (-1, 0, 0)))
            if not opaco(x + 1, y): quads.append(([(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)], (1, 0, 0)))
            if not opaco(x, y - 1): quads.append(([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, 1, 0)))
            if not opaco(x, y + 1): quads.append(([(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)], (0, -1, 0)))
            for cantos, n in quads:
                pts = [transformar(c) for c in cantos]
                nn = transformar((n[0] + 8, n[1] + 8, n[2] + 8))
                o = transformar((8, 8, 8))
                nv = (nn[0] - o[0], nn[1] - o[1], nn[2] - o[2])
                m = math.sqrt(sum(a * a for a in nv)) or 1.0
                malha.quad(mat, [((p[0] - origem_osso[0]) / 16, (p[1] - origem_osso[1]) / 16, (p[2] - origem_osso[2]) / 16) for p in pts],
                           tuple(a / m for a in nv), uvs)


# ------------------------------------------------------------------ glTF

class Gltf:
    def __init__(self):
        self.g = {"asset": {"version": "2.0", "generator": "skills-one-piece/geo_para_glb"}, "scene": 0,
                  "scenes": [{"nodes": [0]}], "nodes": [], "meshes": [], "materials": [], "textures": [],
                  "images": [], "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
                  "accessors": [], "bufferViews": [], "buffers": [], "animations": []}
        self.bin = bytearray()
        self.mat_de_png = {}

    def _view(self, dados, alvo=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        v = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(dados)}
        if alvo:
            v["target"] = alvo
        self.bin.extend(dados)
        self.g["bufferViews"].append(v)
        return len(self.g["bufferViews"]) - 1

    def _acc(self, valores, tipo, comp=5126, alvo=None, minmax=False):
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[tipo]
        fmt = "<" + ("f" if comp == 5126 else "I") * (len(valores) * n if n > 1 else len(valores))
        plano = [c for v in valores for c in v] if n > 1 else list(valores)
        a = {"bufferView": self._view(struct.pack(fmt, *plano), alvo), "componentType": comp, "count": len(valores), "type": tipo}
        if minmax:
            a["min"] = [min(v[i] for v in valores) for i in range(n)]
            a["max"] = [max(v[i] for v in valores) for i in range(n)]
        self.g["accessors"].append(a)
        return len(self.g["accessors"]) - 1

    def material(self, png, nome):
        if png in self.mat_de_png:
            return self.mat_de_png[png]
        with open(png, "rb") as f:
            dados = f.read()
        self.g["images"].append({"bufferView": self._view(dados), "mimeType": "image/png", "name": nome})
        self.g["textures"].append({"source": len(self.g["images"]) - 1, "sampler": 0})
        self.g["materials"].append({"name": nome, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": len(self.g["textures"]) - 1}, "metallicFactor": 0.0, "roughnessFactor": 1.0},
            "alphaMode": "MASK", "alphaCutoff": 0.1, "doubleSided": True})
        self.mat_de_png[png] = len(self.g["materials"]) - 1
        return self.mat_de_png[png]

    def malha(self, m, nome):
        prims = []
        for mat, (pos, nor, uv, idx) in m.partes.items():
            prims.append({"attributes": {"POSITION": self._acc(pos, "VEC3", alvo=34962, minmax=True),
                                         "NORMAL": self._acc(nor, "VEC3", alvo=34962),
                                         "TEXCOORD_0": self._acc(uv, "VEC2", alvo=34962)},
                          "indices": self._acc(idx, "SCALAR", 5125, 34963), "material": mat})
        self.g["meshes"].append({"name": nome, "primitives": prims})
        return len(self.g["meshes"]) - 1

    def no(self, nome, t=None, r=None, s=None, malha=None):
        n = {"name": nome}
        if t: n["translation"] = list(t)
        if r: n["rotation"] = list(r)
        if s: n["scale"] = list(s)
        if malha is not None: n["mesh"] = malha
        self.g["nodes"].append(n)
        return len(self.g["nodes"]) - 1

    def filho(self, pai, filho):
        self.g["nodes"][pai].setdefault("children", []).append(filho)

    @staticmethod
    def _enxugar(tempos, valores, eps=1e-4):
        """Tira quadros que a interpolação linear dos vizinhos já reproduz (trilha constante
        vira 2 quadros). Sem isso, 87 animações a 20 q/s davam ~9 MB por personagem."""
        if len(tempos) <= 2:
            return tempos, valores
        kt, kv = [tempos[0]], [valores[0]]
        for i in range(1, len(tempos) - 1):
            t0, v0 = kt[-1], kv[-1]
            t1, v1 = tempos[i + 1], valores[i + 1]
            u = (tempos[i] - t0) / ((t1 - t0) or 1.0)
            if any(abs(v0[c] + (v1[c] - v0[c]) * u - valores[i][c]) > eps for c in range(len(v0))):
                kt.append(tempos[i])
                kv.append(valores[i])
        kt.append(tempos[-1])
        kv.append(valores[-1])
        return kt, kv

    def animacao(self, nome, canais):
        """canais: [(nó, 'rotation'|'translation'|'scale', tempos, valores)]."""
        amostras, ch = [], []
        for no, caminho, tempos, valores in canais:
            tempos, valores = self._enxugar(tempos, valores)
            entrada = self._acc(tempos, "SCALAR")
            self.g["accessors"][entrada]["min"] = [min(tempos)]
            self.g["accessors"][entrada]["max"] = [max(tempos)]
            saida = self._acc(valores, "VEC4" if caminho == "rotation" else "VEC3")
            amostras.append({"input": entrada, "output": saida, "interpolation": "LINEAR"})
            ch.append({"sampler": len(amostras) - 1, "target": {"node": no, "path": caminho}})
        if ch:
            self.g["animations"].append({"name": nome, "samplers": amostras, "channels": ch})

    def gravar(self, caminho):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.g["buffers"] = [{"byteLength": len(self.bin)}]
        for k in ("animations", "textures", "images", "materials"):
            if not self.g[k]:
                del self.g[k]
        js = json.dumps(self.g, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(caminho, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942) + bytes(self.bin))


# ------------------------------------------------------------------ montagem

def ler_json(caminho):
    with open(caminho, encoding="utf-8") as f:
        return json.load(f)


def geo_de(fonte, rel):
    d = ler_json(os.path.join(fonte, "assets/minepiece", rel))
    g = d["minecraft:geometry"][0]
    desc = g["description"]
    return g["bones"], desc.get("texture_width", 64), desc.get("texture_height", 64)


def png_de_recurso(fonte, recurso, pasta):
    """'minepiece:block/x' → caminho do png (ou None). Recursos do minecraft não estão no JAR."""
    ns, _, caminho = recurso.partition(":") if ":" in recurso else ("minecraft", "", recurso)
    if ns != "minepiece":
        return None
    p = os.path.join(fonte, "assets/minepiece/textures", caminho + ".png")
    return p if os.path.exists(p) else None


def textura_padrao(fonte, classe):
    """Textura que a entidade declara em `defineSynchedData` (a que vale até um `setTexture`), ou None."""
    arq = os.path.join(fonte, f"net/mcreator/minepiece/entity/{classe}Entity.java")
    if not os.path.exists(arq):
        return None
    m = re.search(r'm_135372_\(TEXTURE, "([^"]+)"\)', open(arq, encoding="utf-8").read())
    if not m:
        return None
    rel = f"textures/entities/{m.group(1)}.png"
    return rel if os.path.exists(os.path.join(fonte, "assets/minepiece", rel)) else None


def equipamento(fonte, classe):
    """Itens do construtor da entidade: {slot: ITEM}. Sem classe/arquivo: nada."""
    arq = os.path.join(fonte, f"net/mcreator/minepiece/entity/{classe}Entity.java")
    if not classe or not os.path.exists(arq):
        return {}
    texto = open(arq, encoding="utf-8").read()
    return {m.group(1): m.group(2) for m in re.finditer(r"m_8061_\(EquipmentSlot\.(\w+),\s*new ItemStack\(\(ItemLike\)MinepieceModItems\.(\w+)\.get\(\)", texto)}


def item_camel(item):
    return "".join(p.capitalize() for p in item.lower().split("_"))


def roupa(fonte, item):
    """Geo e textura de um item de roupa (GeckoLib) ou None."""
    # CLOTHES_LUFFY_HELMET → ClothesLuffyModel: o modelo é do conjunto, não da peça.
    conjunto = re.sub(r"_(HELMET|CHESTPLATE|LEGGINGS|BOOTS)$", "", item)
    arq = os.path.join(fonte, f"net/mcreator/minepiece/item/model/{item_camel(conjunto)}Model.java")
    if not os.path.exists(arq):
        return None
    t = open(arq, encoding="utf-8").read()
    g = re.search(r'"(geo/[^"]+)"', t)
    x = re.search(r'"(textures/[^"]+)"', t)
    if not g or not x:
        return None
    return g.group(1), os.path.join(fonte, "assets/minepiece", x.group(1))


def modelo_de_item(fonte, item):
    """(modelo java com elements, {textura: png}) ou ('sprite', png) ou None."""
    base = os.path.join(fonte, "assets/minepiece/models")
    arq = os.path.join(base, "item", item.lower() + ".json")
    if not os.path.exists(arq):
        return None
    d = ler_json(arq)
    texturas = dict(d.get("textures", {}))
    pai = d.get("parent", "")
    visitados = 0
    while "elements" not in d and pai.startswith("minepiece:") and visitados < 5:
        p = os.path.join(base, pai.split(":", 1)[1] + ".json")
        if not os.path.exists(p):
            break
        d2 = ler_json(p)
        texturas = {**d2.get("textures", {}), **texturas}
        d = {**d2, "textures": texturas}
        pai = d2.get("parent", "")
        visitados += 1
    if "elements" in d:
        pngs = {}
        for k, v in texturas.items():
            while isinstance(v, str) and v.startswith("#"):
                v = texturas.get(v[1:], "")
            p = png_de_recurso(fonte, v, "")
            if p:
                pngs[k] = p
        return d, pngs
    camada = texturas.get("layer0")
    p = png_de_recurso(fonte, camada, "") if camada else None
    return ("sprite", p) if p else None


def malha_de_arma(fonte, arma, gl, malha, p):
    """Preenche `malha` com o item `arma` NO ESPAÇO DO OSSO DA MÃO (pivô em `p`, como o GeckoLib). Devolve True se há modelo."""
    m = modelo_de_item(fonte, arma)
    if not m:
        return False
    modelo, pngs = m
    disp = (modelo.get("display", {}) if modelo != "sprite" else {}).get("thirdperson_righthand", {})
    dr = disp.get("rotation", [0, 0, 0])
    dt = disp.get("translation", [0, 0, 0])
    ds = disp.get("scale", [1, 1, 1])

    def transformar(c, dr=dr, dt=dt, ds=ds, p=p):
        x, y, z = (c[0] - 8) * ds[0], (c[1] - 8) * ds[1], (c[2] - 8) * ds[2]
        x, y, z = rot_ponto((x, y, z), dr[0], dr[1], dr[2], (0, 0, 0))
        x, y, z = x + dt[0], y + dt[1], z + dt[2]
        x, y, z = rot_ponto((x, y, z), -90, 0, 0, (0, 0, 0))
        return (p[0] + x, p[1] + y - 1.0, p[2] + z - 1.0)
    if modelo == "sprite":
        sprite_extrudado(malha, gl.material(pngs, arma.lower()), pngs, p, transformar)
    else:
        mats = {k: gl.material(v, f"{arma.lower()}_{k}") for k, v in pngs.items()}
        elementos_java(malha, mats, modelo, p, transformar)
    return True


def converter_item(fonte, arma, saida):
    """`mpi_<item>.glb`: o item sozinho, no espaço do osso da mão — o jogo o prende na mão em tempo de execução
    (a IA do mod saca a arma no meio do combate; o modelo do personagem só traz a do construtor)."""
    gl = Gltf()
    malha = Malha()
    if not malha_de_arma(fonte, arma, gl, malha, [0.0, 0.0, 0.0]) or malha.vazia():
        return None
    raiz = gl.no(f"mpi_{arma.lower()}", malha=gl.malha(malha, arma.lower()))
    destino = os.path.join(saida, f"mpi_{arma.lower()}.glb")
    gl.gravar(destino)
    return destino


def adicionar_animacoes(gl, nos, rest, caminho):
    """Amostra o .animation.json (Molang avaliado) e grava um clipe por animação nos nós `nos`.
    Reutilizada pela reconstrução própria (reconstruir_primeira_ilha.py): os dados de tempo/pose
    do mod entram como estão; só a malha muda."""
    n_anim = 0
    anims = ler_json(caminho).get("animations", {})
    for nome_a, a in anims.items():
        ossos_a = a.get("bones", {})
        tempos_chave = [0.0]
        for b in ossos_a.values():
            for trilha in b.values():
                if isinstance(trilha, dict):
                    tempos_chave += [float(k) for k in trilha if re.match(r"^-?[\d.]+$", str(k))]
        dur = float(a.get("animation_length", max(tempos_chave) or 1.0)) or 1.0
        n = max(2, int(round(dur * QPS)) + 1)
        tempos = [min(dur, i / QPS) for i in range(n)]
        canais = []
        for osso, trilhas in ossos_a.items():
            if osso not in nos:
                continue
            if "rotation" in trilhas:
                vals = []
                for t in tempos:
                    v = amostrar(trilhas["rotation"], t)
                    r0 = rest[osso]
                    vals.append(quat_euler_zyx(r0[0] - v[0], r0[1] - v[1], r0[2] + v[2]))
                canais.append((nos[osso], "rotation", tempos, vals))
            if "position" in trilhas:
                base = gl.g["nodes"][nos[osso]].get("translation", [0, 0, 0])
                vals = []
                for t in tempos:
                    v = amostrar(trilhas["position"], t)
                    vals.append((base[0] - v[0] / 16.0, base[1] + v[1] / 16.0, base[2] + v[2] / 16.0))
                canais.append((nos[osso], "translation", tempos, vals))
            if "scale" in trilhas:
                vals = [tuple(amostrar(trilhas["scale"], t)) for t in tempos]
                vals = [tuple(1.0 if c == 0 and False else c for c in v) for v in vals]
                canais.append((nos[osso], "scale", tempos, vals))
        sufixo = "_loop" if a.get("loop") in (True, "true", "loop") else ""
        gl.animacao(nome_a + sufixo, canais)
        n_anim += 1
    return n_anim


def converter(fonte, ficha, saida, sem_equipamento=False):
    gl = Gltf()
    raiz = gl.no(f"mp_{ficha['id']}", r=quat_euler_zyx(0, 0, 0))
    ossos, tw, th = geo_de(fonte, ficha["modelo"]["geo"])
    tex = os.path.join(fonte, "assets/minepiece", ficha["modelo"]["textura"])
    mat_corpo = gl.material(tex, "corpo")
    por_nome = {o["name"]: o for o in ossos}
    piv = {o["name"]: [-o.get("pivot", [0, 0, 0])[0], o.get("pivot", [0, 0, 0])[1], o.get("pivot", [0, 0, 0])[2]] for o in ossos}
    nos, rest = {}, {}
    malhas = {o["name"]: Malha() for o in ossos}
    for o in ossos:
        cubos_bedrock(malhas[o["name"]], mat_corpo, o, tw, th, piv[o["name"]])
    # Roupas: o geo do item, osso a osso, no osso de mesmo nome do corpo.
    equip = {} if sem_equipamento else equipamento(fonte, ficha["classe"])
    for slot, item in equip.items():
        if slot not in SLOTS_DE_ROUPA:
            continue
        r = roupa(fonte, item)
        if not r:
            continue
        g_rel, png = r
        r_ossos, rtw, rth = geo_de(fonte, g_rel)
        mat = gl.material(png, item.lower())
        for ro in r_ossos:
            if ro["name"] in SLOTS_DE_ROUPA[slot] and ro["name"] in malhas:
                cubos_bedrock(malhas[ro["name"]], mat, ro, rtw, rth, piv[ro["name"]])
    # Arma na mão principal, no osso itemMainHand (ou na mão direita).
    arma = equip.get("MAINHAND")
    osso_mao = "itemMainHand" if "itemMainHand" in malhas else ("right_arm" if "right_arm" in malhas else None)
    if arma and osso_mao:
        m = modelo_de_item(fonte, arma)
        p = piv[osso_mao]
        if m:
            modelo, pngs = m
            disp = (modelo.get("display", {}) if modelo != "sprite" else {}).get("thirdperson_righthand", {})
            dr = disp.get("rotation", [0, 0, 0])
            dt = disp.get("translation", [0, 0, 0])
            ds = disp.get("scale", [1, 1, 1])
            # Como o GeckoLib desenha o item no osso: centro do item no osso, girado −90° em X
            # (o cabo na mão, a lâmina para a frente), mais a transformação "terceira pessoa".
            def transformar(c, dr=dr, dt=dt, ds=ds, p=p):
                x, y, z = (c[0] - 8) * ds[0], (c[1] - 8) * ds[1], (c[2] - 8) * ds[2]
                x, y, z = rot_ponto((x, y, z), dr[0], dr[1], dr[2], (0, 0, 0))
                x, y, z = x + dt[0], y + dt[1], z + dt[2]
                x, y, z = rot_ponto((x, y, z), -90, 0, 0, (0, 0, 0))
                return (p[0] + x, p[1] + y - 1.0, p[2] + z - 1.0)
            if modelo == "sprite":
                sprite_extrudado(malhas[osso_mao], gl.material(pngs, arma.lower()), pngs, p, transformar)
            else:
                mats = {k: gl.material(v, f"{arma.lower()}_{k}") for k, v in pngs.items()}
                elementos_java(malhas[osso_mao], mats, modelo, p, transformar)
    # Nós (hierarquia dos ossos).
    for o in ossos:
        nome = o["name"]
        pai = o.get("parent")
        base = piv[pai] if pai in piv else [0, 0, 0]
        t = [(piv[nome][i] - base[i]) / 16.0 for i in range(3)]
        rr = o.get("rotation", [0, 0, 0])
        rest[nome] = [-rr[0], -rr[1], rr[2]]
        malha = gl.malha(malhas[nome], nome) if not malhas[nome].vazia() else None
        nos[nome] = gl.no(nome, t=t, r=quat_euler_zyx(*rest[nome]), malha=malha)
    for o in ossos:
        pai = o.get("parent")
        gl.filho(nos[pai] if pai in nos else raiz, nos[o["name"]])
    # Animações.
    anim_rel = ficha["modelo"].get("animacao")
    n_anim = 0
    if anim_rel and os.path.exists(os.path.join(fonte, "assets/minepiece", anim_rel)):
        n_anim = adicionar_animacoes(gl, nos, rest, os.path.join(fonte, "assets/minepiece", anim_rel))
    destino = os.path.join(saida, f"mp_{ficha['id']}.glb")
    gl.gravar(destino)
    return destino, n_anim, sorted(equip.items())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fonte", default=FONTE)
    ap.add_argument("--ficha", default="docs/referencias/mine_piece/east_blue/personagens.json")
    # Fora do jogo: `tools/mine_piece/registrar_na_loja.gd` importa daqui para a loja
    # (mapas/modelos/mp_*.glb, ignorados pelo git).
    ap.add_argument("--saida", default="build/mine_piece")
    ap.add_argument("--so", nargs="*", default=[])
    ap.add_argument("--itens", nargs="*", default=None,
                    help="gera mpi_<item>.glb (arma solta) dos itens da lista; sem nomes: todos os de itens_do_mod.json")
    a = ap.parse_args()
    if a.itens is not None:
        nomes = a.itens or [k for k in ler_json("mapas/east_blue/itens_do_mod.json")["itens"] if "devil_fruit" not in k]
        os.makedirs(a.saida, exist_ok=True)
        feitos = 0
        for n in nomes:
            d = converter_item(a.fonte, n, a.saida)
            if d:
                feitos += 1
        print(f"{feitos} de {len(nomes)} itens com modelo → {a.saida}/mpi_*.glb")
        return 0
    fichas = ler_json(a.ficha)["personagens"]
    # Peles sorteadas pelo mod nos piratas genéricos (SetTagPirate: steve_pirate1..8; raid do
    # Arlong: steve_fishman1..4). Cada uma vira um modelo `mp_pirate_<pele>`.
    extras = []
    for f in fichas:
        if f["id"] == "pirate":
            for pele in [f"steve_pirate{i}" for i in range(1, 9)] + [f"steve_fishman{i}" for i in range(1, 5)]:
                g = json.loads(json.dumps(f))
                g["id"] = "pirate_" + pele.replace("steve_", "")
                g["modelo"]["textura"] = f"textures/entities/{pele}.png"
                extras.append(g)
    fichas = fichas + extras
    os.makedirs(a.saida, exist_ok=True)
    falhas = 0
    for f in fichas:
        if a.so and f["id"] not in a.so and f["classe"] not in a.so:
            continue
        try:
            destino, n, equip = converter(a.fonte, f, a.saida)
            print(f"OK   {f['id']:22} {n:3} animações  {os.path.getsize(destino)//1024:5} KB  {equip}")
        except Exception as e:                      # um personagem quebrado não para os outros
            falhas += 1
            print(f"ERRO {f['id']:22} {type(e).__name__}: {e}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
