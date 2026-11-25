#!/usr/bin/env python3
"""Converte as estruturas do Mine Piece (`data/minepiece/structures/*.nbt`) em .glb para o Godot.

    python3 -I tools/mine_piece/estrutura_para_glb.py [--saida DIR] [--so NOME ...] [--relatorio ARQ]

Pedido do dono (18/10/2026): "cada bloco será tanto parte do asset quanto da hitbox, se tenho
dois blocos iguais esses dois blocos são unidos assim eliminando as partes que não são
necessárias [...] trazer também a textura de cada bloco". Plano: docs/ESTRUTURAS_MINE_PIECE_PLANO.md.

  • ESCALA: 2 blocos = altura do jogador (1,6 m) + 10 % → 1 bloco = 0,88 m.
  • FORMA: a dos modelos de bloco do próprio Minecraft (blockstates → variante/multipart →
    modelo com herança → elementos), lidos dos jars locais. Escada, laje, cerca, porta, vidro
    fino etc. saem fiéis sem tabela à mão; os blocos desenhados por entidade (baú, placa,
    estandarte, cama, cabeça, sino, vaso) têm uma caixa aproximada (`ENTIDADES`).
  • UNIÃO: a face entre dois blocos opacos (ou dois blocos iguais) some; faces inteiras vizinhas
    de mesma textura, direção e orientação viram UM retângulo com a textura repetida.
  • HITBOX: a malha `Colisao` do .glb (o catálogo a usa como colisão e não a desenha): a casca
    externa dos blocos de colisão cheia, unida do mesmo jeito, + as caixas dos blocos parciais.
    Sem colisão: plantas, tochas, placas, botões, trilhos, tapetes, estandartes.

PROVISÓRIO (decisão do dono, 17/10/2026): a arte é do Minecraft/mod e fica fora do git
(saída padrão `build/mine_piece/estruturas/mpe_<nome>.glb`, ignorada).
"""
import argparse
import json
import math
import os
import re
import struct
import sys
import zipfile
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nbt  # noqa: E402
from geo_para_glb import Gltf, Malha, ler_png_rgba, faces_box_uv  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
PROJETO = os.path.dirname(os.path.dirname(AQUI))
FONTE = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
CURSE = os.path.expanduser("~/Documents/curseforge/minecraft")
JAR_VANILLA = os.path.join(CURSE, "Install/versions/1.20.1/1.20.1.jar")
JAR_EUREKA = os.path.join(CURSE, "Instances/One Piece - Sea World _ Mine Piece (Inspired by One Piece)/mods/eureka-1201-1.6.3.jar")

ALTURA_JOGADOR = 1.6
METROS_POR_BLOCO = ALTURA_JOGADOR * 1.1 / 2.0       # 0,88 m
M_POR_PX = METROS_POR_BLOCO / 16.0

IGNORADOS = {"minecraft:air", "minecraft:cave_air", "minecraft:void_air", "minecraft:structure_void",
             "minecraft:barrier", "minecraft:jigsaw", "minecraft:structure_block", "minecraft:water",
             "minecraft:lava", "minecraft:bubble_column", "minecraft:light", "minecraft:spawner",
             "minepiece:minepiece_spawner", "minepiece:minepiece_spawner_from_name"}
# Kimetsu no Yaiba: o mod não está nesta máquina. Substituto vanilla mais parecido (marcado no relatório).
SUBSTITUTOS = {
    "kimetsunoyaiba:tile": ("minecraft:deepslate_tiles", False),
    "kimetsunoyaiba:tile_stair": ("minecraft:deepslate_tile_stairs", True),
    "kimetsunoyaiba:tile_half_block": ("minecraft:deepslate_tile_slab", True),
    "kimetsunoyaiba:tatami": ("minecraft:hay_block", False),
    "kimetsunoyaiba:fusuma": ("minecraft:white_wool", False),
    "kimetsunoyaiba:fusuma_flower": ("minecraft:pink_wool", False),
    "kimetsunoyaiba:fusuma_window": ("minecraft:white_stained_glass", False),
    "kimetsunoyaiba:lantern_2": ("minecraft:lantern", False),
    "kimetsunoyaiba:lantern_3": ("minecraft:lantern", False),
    "kimetsunoyaiba:shamisen_block": ("minecraft:air", False),
}
SEM_COLISAO = re.compile(r"(^|_)(torch|sign|banner|button|pressure_plate|rail|lever|tripwire_hook|tripwire|carpet|"
                         r"grass|fern|flower|daisy|cornflower|poppy|dandelion|tulip|allium|bluet|orchid|lily_of_the_valley|"
                         r"torchflower|wheat|sapling|vine|cobweb|candle|end_rod|chain|redstone_wire|snow|propagule|"
                         r"mushroom|dead_bush|kelp|seagrass)$")
# Cor de bioma das planícies para texturas com `tintindex`.
TINTAS = [(re.compile(r"birch_leaves"), (0x80, 0xA7, 0x55)), (re.compile(r"spruce_leaves"), (0x61, 0x99, 0x61)),
          (re.compile(r"(oak|jungle|acacia|mangrove)_leaves|vine"), (0x77, 0xAB, 0x2F)),
          (re.compile(r"lily_pad"), (0x20, 0x80, 0x30)),
          (re.compile(r"grass|fern|sugar_cane"), (0x91, 0xBD, 0x59))]
SUB = 8            # subdivisões por bloco na colisão dos blocos parciais (2 px)
DIRS = {"north": (0, 0, -1), "south": (0, 0, 1), "west": (-1, 0, 0), "east": (1, 0, 0), "up": (0, 1, 0), "down": (0, -1, 0)}
# Eixos no plano de cada face (A, B) para a união: posições crescem no sentido + do mundo.
EIXOS_FACE = {"north": (0, 1), "south": (0, 1), "east": (2, 1), "west": (2, 1), "up": (0, 2), "down": (0, 2)}


# ------------------------------------------------------------------ fontes de recurso (jars)

class Recursos:
    """Procura `assets/<ns>/<caminho>` na ordem: mod (pasta extraída) > Eureka > vanilla."""
    def __init__(self):
        self.zips = [zipfile.ZipFile(j) for j in (JAR_EUREKA, JAR_VANILLA) if os.path.exists(j)]
        self._json = {}
        self._png = {}

    def bruto(self, rel):
        p = os.path.join(FONTE, rel)
        if os.path.isfile(p):
            with open(p, "rb") as f:
                return f.read()
        for z in self.zips:
            try:
                return z.read(rel)
            except KeyError:
                pass
        return None

    def json(self, rel):
        if rel not in self._json:
            b = self.bruto(rel)
            self._json[rel] = json.loads(b) if b else None
        return self._json[rel]

    def png(self, ref):
        """'minecraft:block/stone' → (w, h, pixels) do 1º quadro (texturas animadas são tiras)."""
        if ref not in self._png:
            ns, _, cam = ref.partition(":") if ":" in ref else ("minecraft", "", ref)
            b = self.bruto(f"assets/{ns}/textures/{cam}.png")
            img = None
            if b:
                tmp = os.path.join(SAIDA_TMP, "t.png")
                with open(tmp, "wb") as f:
                    f.write(b)
                img = ler_png_rgba(tmp)
                if img and img[1] > img[0] and img[1] % img[0] == 0:
                    img = (img[0], img[0], img[2][:img[0]])
            self._png[ref] = img
        return self._png[ref]


SAIDA_TMP = "/tmp"


def ns_de(ref, padrao="minecraft"):
    return ref.split(":", 1) if ":" in ref else (padrao, ref)


# ------------------------------------------------------------------ modelo de bloco

def modelo(rec, ref, cache={}):
    """Modelo resolvido: {'texturas': {...}, 'elementos': [...] | None, 'entidade': bool}."""
    if ref in cache:
        return cache[ref]
    texturas, elementos, entidade, atual = {}, None, False, ref
    for _ in range(16):
        ns, cam = ns_de(atual)
        if cam.startswith("builtin/"):
            entidade = entidade or cam == "builtin/entity"
            break
        d = rec.json(f"assets/{ns}/models/{cam}.json")
        if d is None:
            break
        for k, v in d.get("textures", {}).items():
            texturas.setdefault(k, v)
        if elementos is None and "elements" in d:
            elementos = d["elements"]
        if "parent" not in d:
            break
        atual = d["parent"]
    r = {"texturas": texturas, "elementos": elementos, "entidade": entidade}
    cache[ref] = r
    return r


def textura(texturas, chave):
    v = chave
    for _ in range(10):
        if not v.startswith("#"):
            return v if ":" in v else "minecraft:" + v
        v = texturas.get(v[1:], "")
        if not v:
            return None
    return None


def bate(cond, props):
    if "OR" in cond:
        return any(bate(c, props) for c in cond["OR"])
    if "AND" in cond:
        return all(bate(c, props) for c in cond["AND"])
    for k, v in cond.items():
        if props.get(k, "") not in str(v).split("|"):
            return False
    return True


def variantes(rec, nome, props):
    """Blockstate → lista de {'model', 'x', 'y', 'uvlock'}."""
    ns, cam = ns_de(nome)
    bs = rec.json(f"assets/{ns}/blockstates/{cam}.json")
    if bs is None:
        return None
    saida = []
    if "variants" in bs:
        for chave, v in bs["variants"].items():
            cond = dict(p.split("=") for p in chave.split(",") if "=" in p)
            if all(props.get(k) == val for k, val in cond.items()):
                saida.append(v[0] if isinstance(v, list) else v)
                break
        if not saida and bs["variants"]:
            # Substituto sem propriedades (fardo de feno, lanterna): a 1ª variante é o padrão.
            v = next(iter(bs["variants"].values()))
            saida.append(v[0] if isinstance(v, list) else v)
    for parte in bs.get("multipart", []):
        if "when" not in parte or bate(parte["when"], props):
            a = parte["apply"]
            saida.append(a[0] if isinstance(a, list) else a)
    return saida


# ------------------------------------------------------------------ geometria

def girar(p, eixo, graus, origem):
    """Rotação de mão direita em torno do eixo 'x'|'y'|'z' (graus), em px."""
    if not graus:
        return p
    r = math.radians(graus)
    c, s = math.cos(r), math.sin(r)
    x, y, z = p[0] - origem[0], p[1] - origem[1], p[2] - origem[2]
    if eixo == "x":
        y, z = y * c - z * s, y * s + z * c
    elif eixo == "y":
        x, z = x * c + z * s, -x * s + z * c
    else:
        x, y = x * c - y * s, x * s + y * c
    return (x + origem[0], y + origem[1], z + origem[2])


def cantos_da_face(face, a, b):
    """Cantos (TL, TR, BR, BL vistos de fora) da face de uma caixa a→b, em px."""
    x1, y1, z1 = a
    x2, y2, z2 = b
    return {
        "north": [(x2, y2, z1), (x1, y2, z1), (x1, y1, z1), (x2, y1, z1)],
        "south": [(x1, y2, z2), (x2, y2, z2), (x2, y1, z2), (x1, y1, z2)],
        "west": [(x1, y2, z1), (x1, y2, z2), (x1, y1, z2), (x1, y1, z1)],
        "east": [(x2, y2, z2), (x2, y2, z1), (x2, y1, z1), (x2, y1, z2)],
        "up": [(x1, y2, z1), (x2, y2, z1), (x2, y2, z2), (x1, y2, z2)],
        "down": [(x1, y1, z2), (x2, y1, z2), (x2, y1, z1), (x1, y1, z1)],
    }[face]


def uv_padrao(face, a, b):
    x1, y1, z1 = a
    x2, y2, z2 = b
    return {"down": [x1, 16 - z2, x2, 16 - z1], "up": [x1, z1, x2, z2], "north": [16 - x2, 16 - y2, 16 - x1, 16 - y1],
            "south": [x1, 16 - y2, x2, 16 - y1], "west": [z1, 16 - y2, z2, 16 - y1], "east": [16 - z2, 16 - y2, 16 - z1, 16 - y1]}[face]


def uv_do_mundo(face, p):
    """UV (px) que o Minecraft dá a um ponto de uma face pela posição (o `uv` padrão, mód 16)."""
    x, y, z = p
    return {"down": (x, -z), "up": (x, z), "north": (-x, -y), "south": (x, -y), "west": (z, -y), "east": (-z, -y)}[face]


def dir_de_normal(n):
    for nome, d in DIRS.items():
        if abs(n[0] - d[0]) < 1e-4 and abs(n[1] - d[1]) < 1e-4 and abs(n[2] - d[2]) < 1e-4:
            return nome
    return None


def girar_dir(nome, rx, ry):
    d = DIRS[nome]
    d = girar(d, "x", -rx, (0, 0, 0))
    d = girar(d, "y", -ry, (0, 0, 0))
    return dir_de_normal((round(d[0]), round(d[1]), round(d[2])))


def tinta_de(nome_bloco):
    for rx, cor in TINTAS:
        if rx.search(nome_bloco):
            return cor
    return None


class Quad:
    __slots__ = ("cantos", "uvs", "tex", "tinta", "cull", "normal", "uv_px")

    def __init__(self, cantos, uvs, tex, tinta, cull, normal, uv_px):
        self.cantos, self.uvs, self.tex, self.tinta, self.cull, self.normal, self.uv_px = cantos, uvs, tex, tinta, cull, normal, uv_px


def assar_elementos(m, var, nome_bloco, tex_dims):
    """Elementos do modelo → quads (px, no bloco) + caixas de colisão (px)."""
    quads, caixas = [], []
    rx, ry = int(var.get("x", 0)), int(var.get("y", 0))
    tinta = tinta_de(nome_bloco)
    centro = (8, 8, 8)
    for el in m["elementos"] or []:
        a, b = tuple(el["from"]), tuple(el["to"])
        rot = el.get("rotation")
        girado = bool(rot and rot.get("angle", 0))

        def transf(p):
            if girado:
                p = girar(p, rot["axis"], rot["angle"], rot.get("origin", (8, 8, 8)))
            p = girar(p, "x", -rx, centro)
            return girar(p, "y", -ry, centro)

        for face, f in el.get("faces", {}).items():
            tex = textura(m["texturas"], f.get("texture", ""))
            if tex is None:
                continue
            uv = f.get("uv") or uv_padrao(face, a, b)
            if tex.endswith("_overlay"):
                continue      # sobreposição tingida da grama: a face de baixo já tem a borda verde
            cs = [(uv[0], uv[1]), (uv[2], uv[1]), (uv[2], uv[3]), (uv[0], uv[3])]
            k = (int(f.get("rotation", 0)) // 90) % 4
            uvs = [cs[(i - k) % 4] for i in range(4)]
            uvs = [(u / 16.0, v / 16.0) for u, v in uvs]
            cantos = [transf(p) for p in cantos_da_face(face, a, b)]
            n = DIRS[face]
            if girado:
                n = girar(n, rot["axis"], rot["angle"], (0, 0, 0))
            n = girar(girar(n, "x", -rx, (0, 0, 0)), "y", -ry, (0, 0, 0))
            final = dir_de_normal(tuple(round(c, 4) for c in n))
            if var.get("uvlock") and (rx or ry) and final:
                # uvlock: a textura fica presa ao mundo, não gira com o modelo (escada, cerca).
                uvs = [tuple(w / 16.0 for w in uv_do_mundo(final, c)) for c in cantos]
            cull = girar_dir(f["cullface"], rx, ry) if f.get("cullface") in DIRS else None
            cheio_uv = sorted([uv[0], uv[2]]) == [0, 16] and sorted([uv[1], uv[3]]) == [0, 16]
            quads.append(Quad(cantos, uvs, tex, tinta if "tintindex" in f else None, cull, n, cheio_uv))
        if not girado and SEM_COLISAO.search(nome_bloco.split(":")[1]) is None:
            pa = girar(girar(a, "x", -rx, centro), "y", -ry, centro)
            pb = girar(girar(b, "x", -rx, centro), "y", -ry, centro)
            lo = tuple(round(min(pa[i], pb[i]), 4) for i in range(3))
            hi = tuple(round(max(pa[i], pb[i]), 4) for i in range(3))
            if all(hi[i] - lo[i] > 0.01 for i in range(3)):
                caixas.append((lo, hi))
    return quads, caixas


# Blocos desenhados por entidade no Minecraft: caixas aproximadas (px), textura, mapa de UV.
def entidade(nome, props):
    cam = nome.split(":")[1]
    face = props.get("facing", "north")
    ry = {"north": 0, "east": 90, "south": 180, "west": 270}.get(face, 0)
    if "rotation" in props:
        ry = int(props["rotation"]) * 22.5
    madeira = re.sub(r"_(wall_|hanging_|wall_hanging_)?sign$", "", cam)
    if cam.endswith("chest"):
        tex = "minecraft:entity/chest/" + ("trapped" if "trapped" in cam else "ender" if "ender" in cam else "normal")
        return ry + 180, [((1, 0, 1), (15, 10, 15), tex, ("box", 0, 19, 64)), ((1, 10, 1), (15, 14, 15), tex, ("box", 0, 0, 64)),
                          ((7, 7, 0), (9, 11, 1), tex, ("box", 0, 0, 64))], True
    if cam.endswith("_bed"):
        cor = cam[:-4]
        return ry, [((0, 3, 0), (16, 9, 16), f"minecraft:block/{cor}_wool", None)], True
    if cam.endswith("hanging_sign"):
        return ry, [((1, 0, 7), (15, 10, 9), f"minecraft:block/{madeira}_planks", None)], False
    if cam.endswith("wall_sign"):
        return ry, [((0, 4.5, 14), (16, 12.5, 16), f"minecraft:block/{madeira}_planks", None)], False
    if cam.endswith("sign"):
        return ry, [((0, 7, 7), (16, 15, 9), f"minecraft:block/{madeira}_planks", None),
                    ((7, 0, 7.5), (9, 7, 8.5), f"minecraft:block/{madeira}_log", None)], False
    if cam.endswith("wall_banner"):
        return ry, [((1, -6, 14.5), (15, 14, 15.5), f"minecraft:block/{cam[:-12]}_wool", None)], False
    if cam.endswith("banner"):
        return ry, [((7, 0, 7), (9, 28, 9), "minecraft:block/oak_planks", None),
                    ((1, 6, 6.5), (15, 26, 7.5), f"minecraft:block/{cam[:-7]}_wool", None)], False
    if cam.endswith("_head") or cam.endswith("_skull"):
        tex = {"piglin_head": "minecraft:entity/piglin/piglin", "zombie_head": "minecraft:entity/zombie/zombie",
               "skeleton_skull": "minecraft:entity/skeleton/skeleton"}.get(cam, "minecraft:entity/player/wide/steve")
        return ry + 180, [((4, 0, 4), (12, 8, 12), tex, ("box", 0, 0, 64))], True
    if cam == "bell":
        tex = "minecraft:entity/bell/bell_body"
        return ry, [((5, 6, 5), (11, 13, 11), tex, ("box", 0, 0, 32)), ((4, 4, 4), (12, 6, 12), tex, ("box", 0, 13, 32))], True
    if cam == "decorated_pot":
        return ry, [((1, 0, 1), (15, 16, 15), "minecraft:entity/decorated_pot/decorated_pot_side", None)], True
    return None


def assar_entidade(nome, props, tex_dims):
    e = entidade(nome, props)
    if e is None:
        return None
    ry, caixas_, solido = e
    quads, caixas = [], []
    for a, b, tex, mapa in caixas_:
        sx, sy, sz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        if mapa:
            _, u0, v0, tam = mapa
            rects = faces_box_uv(u0, v0, sx, sy, sz, False)
        for face in DIRS:
            if mapa:
                r = rects[face]
                uvs = [(r[0], r[1]), (r[2], r[1]), (r[2], r[3]), (r[0], r[3])]
                uvs = [(u / tam, v / tam) for u, v in uvs]
            else:
                r = uv_padrao(face, a, b)
                uvs = [(r[0] / 16, r[1] / 16), (r[2] / 16, r[1] / 16), (r[2] / 16, r[3] / 16), (r[0] / 16, r[3] / 16)]
            cantos = [girar(p, "y", -ry, (8, 8, 8)) for p in cantos_da_face(face, a, b)]
            n = girar(DIRS[face], "y", -ry, (0, 0, 0))
            quads.append(Quad(cantos, uvs, tex, None, None, n, False))
        if solido:
            pa, pb = girar(a, "y", -ry, (8, 8, 8)), girar(b, "y", -ry, (8, 8, 8))
            caixas.append((tuple(round(min(pa[i], pb[i]), 3) for i in range(3)), tuple(round(max(pa[i], pb[i]), 3) for i in range(3))))
    return quads, caixas


def opaca(rec, tex):
    img = rec.png(tex)
    return img is not None and all(p[3] == 255 for linha in img[2] for p in linha)


# ------------------------------------------------------------------ PNG (gravar)

def png_rgba(w, h, pixels):
    cru = b"".join(b"\x00" + bytes(c for px in linha for c in px) for linha in pixels)

    def bloco(tipo, dados):
        return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + bloco(b"IDAT", zlib.compress(cru, 9)) + bloco(b"IEND", b""))


class GltfBlocos(Gltf):
    """Gltf com materiais a partir de pixels (tinta, 1º quadro) e textura REPETIDA (união)."""
    def __init__(self):
        super().__init__()
        self.g["asset"]["generator"] = "skills-one-piece/estrutura_para_glb"
        self.g["samplers"].append({"magFilter": 9728, "minFilter": 9986, "wrapS": 10497, "wrapT": 10497})
        self.mat_de_chave = {}

    def material_px(self, chave, img, tinta):
        if chave in self.mat_de_chave:
            return self.mat_de_chave[chave]
        w, h, px = img
        if tinta:
            px = [[(r * tinta[0] // 255, g * tinta[1] // 255, b * tinta[2] // 255, a) for r, g, b, a in linha] for linha in px]
        alfas = {p[3] for linha in px for p in linha}
        modo = "OPAQUE" if alfas == {255} else ("MASK" if alfas <= {0, 255} else "BLEND")
        self.g["images"].append({"bufferView": self._view(png_rgba(w, h, px)), "mimeType": "image/png", "name": chave})
        self.g["textures"].append({"source": len(self.g["images"]) - 1, "sampler": 1})
        mat = {"name": chave, "pbrMetallicRoughness": {"baseColorTexture": {"index": len(self.g["textures"]) - 1},
               "metallicFactor": 0.0, "roughnessFactor": 1.0}, "alphaMode": modo, "doubleSided": False}
        if modo == "MASK":
            mat["alphaCutoff"] = 0.5
        self.g["materials"].append(mat)
        self.mat_de_chave[chave] = len(self.g["materials"]) - 1
        return self.mat_de_chave[chave]

    def material_cor(self):
        if "colisao" not in self.mat_de_chave:
            self.g["materials"].append({"name": "colisao", "pbrMetallicRoughness": {"baseColorFactor": [1, 0, 1, 1]}})
            self.mat_de_chave["colisao"] = len(self.g["materials"]) - 1
        return self.mat_de_chave["colisao"]


# ------------------------------------------------------------------ união (greedy)

def retangulos(celulas):
    """Conjunto de (a, b) → retângulos [(a0, b0, largura, altura)] que o cobrem sem sobrepor."""
    resto = set(celulas)
    saida = []
    for a, b in sorted(celulas, key=lambda c: (c[1], c[0])):
        if (a, b) not in resto:
            continue
        w = 1
        while (a + w, b) in resto:
            w += 1
        h = 1
        while all((a + i, b + h) in resto for i in range(w)):
            h += 1
        for j in range(h):
            for i in range(w):
                resto.discard((a + i, b + j))
        saida.append((a, b, w, h))
    return saida


def ponto_face(face, camada, a, b):
    """Ponto (em blocos) do plano da face: camada no eixo normal, (a, b) nos eixos da face."""
    ia, ib = EIXOS_FACE[face]
    eixo_n = 3 - ia - ib
    p = [0.0, 0.0, 0.0]
    p[eixo_n], p[ia], p[ib] = camada, a, b
    return p


def emitir(malha, mat, cantos, uvs, normal):
    """Quad com enrolamento anti-horário visto de fora (glTF)."""
    e1 = [cantos[1][i] - cantos[0][i] for i in range(3)]
    e2 = [cantos[2][i] - cantos[0][i] for i in range(3)]
    cr = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    if cr[0] * normal[0] + cr[1] * normal[1] + cr[2] * normal[2] < 0:
        cantos, uvs = cantos[::-1], uvs[::-1]
    malha.quad(mat, cantos, tuple(normal), uvs)


def colisao_do_minecraft(nome, props, caixas):
    """Blocos cuja colisão no Minecraft NÃO é a forma desenhada: cerca, muro e portão fecham a
    altura toda (as barras finas deixariam vãos — e milhares de faces numa grade de cercas)."""
    cam = nome.split(":")[1]
    lados = {"north": ((6, 0, 0), (10, 16, 8)), "south": ((6, 0, 8), (10, 16, 16)),
             "west": ((0, 0, 6), (8, 16, 10)), "east": ((8, 0, 6), (16, 16, 10))}
    if cam.endswith("_fence"):
        return [((6, 0, 6), (10, 16, 10))] + [lados[l] for l in lados if props.get(l) == "true"]
    if cam.endswith("_wall") and "north" in props:
        return [((4, 0, 4), (12, 16, 12))] + [lados[l] for l in lados if props.get(l) in ("low", "tall")]
    if cam.endswith("_fence_gate"):
        if props.get("open") == "true":
            return []
        return [((0, 0, 6), (16, 16, 10))] if props.get("facing") in ("north", "south") else [((6, 0, 0), (10, 16, 16))]
    return caixas


def sem_cobertas(soltas, rec):
    """Tira as faces alinhadas aos eixos cobertas por uma face opaca colada e oposta."""
    indice = {}
    info = []
    for cantos, q, _ in soltas:
        face = dir_de_normal(q.normal)
        if face is None:
            info.append(None)
            continue
        ia, ib = EIXOS_FACE[face]
        eixo_n = 3 - ia - ib
        plano = round(cantos[0][eixo_n], 4)
        ra = (min(c[ia] for c in cantos), max(c[ia] for c in cantos))
        rb = (min(c[ib] for c in cantos), max(c[ib] for c in cantos))
        cel = (math.floor((ra[0] + ra[1]) / 2), math.floor((rb[0] + rb[1]) / 2))
        sinal = DIRS[face][eixo_n]
        item = (ra, rb, opaca(rec, q.tex))
        indice.setdefault((eixo_n, plano, cel, sinal), []).append(item)
        info.append(((eixo_n, plano, cel, -sinal), ra, rb))
    for (cantos, q, nome), i in zip(soltas, info):
        if i is not None:
            chave, ra, rb = i
            if any(op and ga[0] <= ra[0] + 1e-4 and ga[1] >= ra[1] - 1e-4 and gb[0] <= rb[0] + 1e-4 and gb[1] >= rb[1] - 1e-4
                   for ga, gb, op in indice.get(chave, ())):
                continue
        yield cantos, q, nome


def presa_ao_mundo(cantos, q):
    """((face, plano px, tex, tinta), (ra, rb)) se a face é alinhada e a UV é a da posição."""
    face = dir_de_normal(q.normal)
    if face is None:
        return None
    px = [tuple(v * 16 for v in c) for c in cantos]
    desl = None
    for c, uv in zip(px, q.uvs):
        w = uv_do_mundo(face, c)
        d = (uv[0] * 16 - w[0], uv[1] * 16 - w[1])
        if abs(d[0] / 16 - round(d[0] / 16)) > 1e-3 or abs(d[1] / 16 - round(d[1] / 16)) > 1e-3:
            return None
        if desl is not None and (abs(d[0] - desl[0]) > 1e-3 or abs(d[1] - desl[1]) > 1e-3):
            return None
        desl = d
    ia, ib = EIXOS_FACE[face]
    eixo_n = 3 - ia - ib
    ra = (round(min(c[ia] for c in px), 4), round(max(c[ia] for c in px), 4))
    rb = (round(min(c[ib] for c in px), 4), round(max(c[ib] for c in px), 4))
    return (face, round(px[0][eixo_n], 4), q.tex, q.tinta), (ra, rb)


def unir_retangulos(rects):
    """Une retângulos (ra, rb) que se sobrepõem ou encostam com a mesma extensão no outro eixo."""
    atual = list(set(rects))
    while True:
        antes = len(atual)
        for eixo in (0, 1):
            outro = 1 - eixo
            grupos = {}
            for r in atual:
                grupos.setdefault(r[outro], []).append(r[eixo])
            atual = []
            for faixa, ints in grupos.items():
                ints.sort()
                ini, fim = ints[0]
                for a, b in ints[1:]:
                    if a <= fim + 1e-4:
                        fim = max(fim, b)
                    else:
                        atual.append((ini, fim, faixa))
                        ini, fim = a, b
                atual.append((ini, fim, faixa))
            atual = [((i, f), fx) if eixo == 0 else (fx, (i, f)) for i, f, fx in atual]
        if len(atual) == antes:
            return atual


def lugares(nome_est, tamanho, grade):
    """Dados para pôr a estrutura no mapa (em metros, origem = centro da base do molde):
    • chao_blocos: camadas de baixo quase cheias (o chão que veio junto) — a estrutura entra
      afundada esse tanto, com o chão dela rente ao da ilha;
    • agua_blocos: navios — blocos abaixo do nível do mar do Minecraft (63 − altura de partida);
    • lugares_internos: onde ficar de pé sob teto, perto do centro (vendedores da loja);
    • lugares_conves: onde ficar de pé no convés principal (tripulação)."""
    sx, _, sz = tamanho
    por_y = {}
    for (x, y, z) in grade:
        por_y[y] = por_y.get(y, 0) + 1
    chao = 0
    while por_y.get(chao, 0) >= 0.9 * sx * sz:
        chao += 1
    colide = {p for p, v in grade.items() if v[2] or v[1]}
    teto_de = {}
    for (x, y, z) in colide:
        teto_de.setdefault((x, z), []).append(y)
    # De pé com folga para o corpo (1 m × 1,6 m; 0,88 m por bloco): 3 × 3 livres nas TRÊS
    # camadas acima (com duas, um porão de 1,76 m expulsava o corpo pelo teto — medido no
    # navio pirata pequeno) e apoio em pelo menos 6 dos 9 blocos de baixo (não em poste).
    de_pe = []
    vizinhos = [(dx, dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1)]
    for (x, y, z) in colide:
        if any((x + dx, y + k, z + dz) in colide for dx, dz in vizinhos for k in (1, 2, 3)):
            continue
        if sum((x + dx, y, z + dz) in colide for dx, dz in vizinhos) < 6:
            continue
        coberto = any(t > y + 3 for t in teto_de[(x, z)])
        de_pe.append((x, y + 1, z, coberto))
    cx, cz = sx / 2.0, sz / 2.0

    def escolher(cands, n):
        cands = sorted(cands, key=lambda c: (c[0] + 0.5 - cx) ** 2 + (c[2] + 0.5 - cz) ** 2)
        feitos = []
        for c in cands:
            if all((c[0] - f[0]) ** 2 + (c[2] - f[2]) ** 2 >= 9 for f in feitos):
                feitos.append(c)
            if len(feitos) == n:
                break
        return [[round((c[0] + 0.5 - cx) * METROS_POR_BLOCO, 3), round(c[1] * METROS_POR_BLOCO, 3),
                 round((c[2] + 0.5 - cz) * METROS_POR_BLOCO, 3)] for c in feitos]

    r = {"chao_blocos": chao, "_de_pe": de_pe}
    internos = [c for c in de_pe if c[3] and c[1] <= chao + 2]
    r["lugares_internos"] = escolher(internos, 4)
    ws = os.path.join(FONTE, "data/minepiece/worldgen/structure", nome_est + ".json")
    if nome_est.startswith("ship_") and os.path.exists(ws):
        with open(ws) as f:
            altura = json.load(f).get("start_height", {})
        partida = altura.get("min_inclusive", altura).get("absolute") if isinstance(altura, dict) else None
        if isinstance(partida, int) and partida > 0:
            agua = 63 - partida
            r["agua_blocos"] = agua
            acima = [c for c in de_pe if c[1] > agua + 1]
            if acima:
                alturas = {}
                for c in acima:
                    alturas[c[1]] = alturas.get(c[1], 0) + 1
                conves = max(alturas, key=alturas.get)
                r["lugares_conves"] = escolher([c for c in acima if c[1] == conves], 6)
    if nome_est.startswith("ship_"):
        r["navio"] = perfil_de_navio(grade, colide, r, cx, cz)
    r.pop("_de_pe", None)
    return r


def casca_convexa(pontos):
    """Casca convexa 2D (cadeia monótona), anti-horária."""
    pts = sorted(set(pontos))
    if len(pts) < 3:
        return pts
    def giro(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    baixo, cima = [], []
    for q in pts:
        while len(baixo) >= 2 and giro(baixo[-2], baixo[-1], q) <= 0:
            baixo.pop()
        baixo.append(q)
    for q in reversed(pts):
        while len(cima) >= 2 and giro(cima[-2], cima[-1], q) <= 0:
            cima.pop()
        cima.append(q)
    return baixo[:-1] + cima[:-1]


def perfil_de_navio(grade, colide, r, cx, cz):
    """Para navegar (`PerfilBarco`), em metros na origem do molde: linha d'água, contorno
    do casco nela (casca convexa das colunas sólidas a ±1 bloco), altura do convés, leme
    (o timão do Eureka, se houver — ele marca a POPA) e saídas de pé perto do leme."""
    M = METROS_POR_BLOCO
    agua = int(r.get("agua_blocos", 1))
    colunas = {(x, z) for (x, y, z) in colide if agua - 1 <= y <= agua + 1}
    if len(colunas) < 3:
        colunas = {(x, z) for (x, y, z) in colide}
    cantos = []
    for x, z in colunas:
        for dx in (0, 1):
            for dz in (0, 1):
                cantos.append(((x + dx - cx) * M, (z + dz - cz) * M))
    casco = [[round(a, 3), round(b, 3)] for a, b in casca_convexa(cantos)]
    conves = r.get("lugares_conves", [])
    deck_y = conves[0][1] if conves else (agua + 2) * M
    timoes = [(x, y, z) for (x, y, z), v in grade.items() if v[4].endswith("_ship_helm")]
    if timoes:
        # O posto de comando: o lugar de pé (com folga) mais perto do timão — o bloco do
        # timão em si tem colisão e o piloto não cabe nele.
        hx, hy, hz = timoes[0]
        perto = min(r["_de_pe"], key=lambda c: (c[0] - hx) ** 2 + (c[2] - hz) ** 2 + 4 * (c[1] - hy) ** 2, default=None)
        x, y, z = (perto[0], perto[1], perto[2]) if perto else (hx, hy + 1, hz)
        leme = [round((x + 0.5 - cx) * M, 3), round(y * M, 3), round((z + 0.5 - cz) * M, 3)]
    elif conves:
        leme = list(max(conves, key=lambda c: abs(c[2])))
    else:
        leme = [0.0, round(deck_y, 3), 0.0]
    saidas = sorted(conves, key=lambda c: (c[0] - leme[0]) ** 2 + (c[2] - leme[2]) ** 2)[:2] or [[leme[0], leme[1], leme[2]]]
    return {"linha": round(agua * M, 3), "casco": casco, "conves": round(deck_y, 3), "leme": leme, "saidas": saidas}


# ------------------------------------------------------------------ conversão

def converter(rec, caminho_nbt, destino):
    nome_est = os.path.splitext(os.path.basename(caminho_nbt))[0]
    with open(caminho_nbt, "rb") as f:
        tamanho, blocos = nbt.estrutura(f.read())
    rel = {"estrutura": nome_est, "tamanho_blocos": tamanho, "sem_modelo": {}, "substituidos": {}, "entidade_aprox": {}}

    def dims(tex):
        img = rec.png(tex)
        return (img[0], img[1]) if img else (16, 16)

    cache = {}
    grade = {}
    for x, y, z, nome, props in blocos:
        if nome in IGNORADOS:
            continue
        if nome in SUBSTITUTOS:
            novo, manter = SUBSTITUTOS[nome]
            rel["substituidos"][nome] = novo
            nome, props = novo, (props if manter else {})
            if nome in IGNORADOS:
                continue
        chave = nome + str(sorted(props.items()))
        if chave not in cache:
            vs = variantes(rec, nome, props)
            quads, caixas, solido_cheio, opaco_cheio = [], [], False, False
            ent = None
            if vs:
                for v in vs:
                    m = modelo(rec, v["model"])
                    if m["entidade"] and not m["elementos"]:
                        ent = ent or assar_entidade(nome, props, dims)
                        continue
                    q, c = assar_elementos(m, v, nome, dims)
                    quads += q
                    caixas += c
            if ent is not None:
                rel["entidade_aprox"][nome] = rel["entidade_aprox"].get(nome, 0) + 1
                quads += ent[0]
                caixas += ent[1]
            elif not vs:
                rel["sem_modelo"][nome] = rel["sem_modelo"].get(nome, 0) + 1
            caixas = colisao_do_minecraft(nome, props, caixas)
            solido_cheio = any(lo == (0, 0, 0) and hi == (16, 16, 16) for lo, hi in caixas)
            if solido_cheio:
                caixas = []
            # Opaco e cheio: esconde as faces dos vizinhos. Vale para cubo de 1 elemento sem transparência.
            if vs and len(vs) == 1 and solido_cheio and len(quads) == 6 and all(q.uv_px for q in quads):
                opaco_cheio = all(opaca(rec, q.tex) for q in quads)
            cache[chave] = (quads, caixas, solido_cheio, opaco_cheio, nome)
        grade[(x, y, z)] = cache[chave]

    if not grade:
        return None
    rel.update(lugares(nome_est, tamanho, grade))
    gltf = GltfBlocos()
    malha = Malha()
    univeis = {}       # (face, camada, tex, tinta, padrão de uv) → {(a, b)}
    soltas = []        # faces que não entram na união por grade: (cantos em blocos, Quad)
    soltos = 0
    unidos = 0

    def vizinho(p, face):
        d = DIRS[face]
        return grade.get((p[0] + d[0], p[1] + d[1], p[2] + d[2]))

    def mat_de(q):
        img = rec.png(q.tex)
        if img is None:
            rel["sem_modelo"]["textura:" + q.tex] = 1
            img = (1, 1, [[(255, 0, 255, 255)]])
        return gltf.material_px(q.tex + ("#%02x%02x%02x" % q.tinta if q.tinta else ""), img, q.tinta)

    for p, (quads, _, _, _, nome) in grade.items():
        for q in quads:
            if q.cull:
                viz = vizinho(p, q.cull)
                if viz is not None and (viz[3] or (viz[4] == nome and viz[2])):
                    continue
            face = dir_de_normal(q.normal)
            if face and q.uv_px:
                ia, ib = EIXOS_FACE[face]
                eixo_n = 3 - ia - ib
                plano = {round(c[eixo_n], 4) for c in q.cantos}
                ext_a = sorted({round(c[ia], 4) for c in q.cantos})
                ext_b = sorted({round(c[ib], 4) for c in q.cantos})
                borda = 16 if DIRS[face][eixo_n] > 0 else 0
                if plano == {borda} and ext_a == [0, 16] and ext_b == [0, 16]:
                    # UV em cada canto (a, b) ∈ {0,1}²: o padrão que a união repete.
                    padrao = []
                    for ca, cb in ((0, 0), (1, 0), (0, 1)):
                        for c, uv in zip(q.cantos, q.uvs):
                            if round(c[ia]) == ca * 16 and round(c[ib]) == cb * 16:
                                padrao.append(uv)
                    chave = (face, p[eixo_n] + borda / 16, q.tex, q.tinta, tuple(padrao))
                    univeis.setdefault(chave, set()).add((p[ia], p[ib]))
                    continue
            cantos = [(p[0] + c[0] / 16, p[1] + c[1] / 16, p[2] + c[2] / 16) for c in q.cantos]
            soltas.append((cantos, q, nome))

    # Face parcial coberta por outra colada e virada para ela (ponta de cerca na vizinha,
    # poste sobre poste, laje encostada): as duas somem se ambas forem opacas.
    por_bloco = {}
    presas = {}        # (face, plano, tex, tinta) → [(ra, rb)] em px do mundo
    for cantos, q, nome in sem_cobertas(soltas, rec):
        chave = presa_ao_mundo(cantos, q)
        if chave is not None:
            presas.setdefault(chave[0], []).append(chave[1])
            continue
        emitir(malha, mat_de(q), cantos, q.uvs, q.normal)
        soltos += 1
        por_bloco[nome] = por_bloco.get(nome, 0) + 1
    # Faces coplanares de mesma textura com UV presa ao mundo (barras de cerca, grade, laje):
    # sobrepostas ou encostadas desenham igual juntas — viram uma tira.
    for (face, plano, tex, tinta), rects in presas.items():
        mat = mat_de(Quad(None, None, tex, tinta, None, DIRS[face], True))
        for ra, rb in unir_retangulos(rects):
            cantos = [tuple(v / 16 for v in ponto_face(face, plano, a, b)) for a, b in
                      ((ra[0], rb[0]), (ra[1], rb[0]), (ra[1], rb[1]), (ra[0], rb[1]))]
            uvs = [tuple(w / 16.0 for w in uv_do_mundo(face, tuple(v * 16 for v in c))) for c in cantos]
            emitir(malha, mat, cantos, uvs, DIRS[face])
            unidos += 1
    rel["faces_soltas_por_bloco"] = dict(sorted(por_bloco.items(), key=lambda kv: -kv[1])[:8])

    for (face, camada, tex, tinta, padrao), cels in univeis.items():
        q = Quad(None, None, tex, tinta, None, DIRS[face], True)
        mat = mat_de(q)
        uv00, uv10, uv01 = padrao
        du, dv = (uv10[0] - uv00[0], uv10[1] - uv00[1]), (uv01[0] - uv00[0], uv01[1] - uv00[1])
        for a, b, w, h in retangulos(cels):
            cantos, uvs = [], []
            for ca, cb in ((0, 0), (w, 0), (w, h), (0, h)):
                cantos.append(tuple(ponto_face(face, camada, a + ca, b + cb)))
                uvs.append((uv00[0] + ca * du[0] + cb * dv[0], uv00[1] + ca * du[1] + cb * dv[1]))
            emitir(malha, mat, cantos, uvs, DIRS[face])
            unidos += 1

    # ---- colisão: casca dos blocos de colisão cheia + caixas dos parciais
    col = Malha()
    mcol = gltf.material_cor()
    cheios = {p for p, v in grade.items() if v[2]}
    faces_col = {}
    for p in cheios:
        for face, d in DIRS.items():
            if (p[0] + d[0], p[1] + d[1], p[2] + d[2]) not in cheios:
                ia, ib = EIXOS_FACE[face]
                eixo_n = 3 - ia - ib
                faces_col.setdefault((face, p[eixo_n] + (1 if d[eixo_n] > 0 else 0)), set()).add((p[ia], p[ib]))
    for (face, camada), cels in faces_col.items():
        for a, b, w, h in retangulos(cels):
            cantos = [tuple(ponto_face(face, camada, a + ca, b + cb)) for ca, cb in ((0, 0), (w, 0), (w, h), (0, h))]
            emitir(col, mcol, cantos, [(0, 0)] * 4, DIRS[face])
    # Blocos parciais numa grade de SUB células (1/8 de bloco): as caixas de cercas, grades e
    # lajes vizinhas viram um volume só, sem paredes internas, e a casca é unida como acima.
    sub = set()
    caixas_col = 0
    for p, (_, caixas, _, _, _) in grade.items():
        for lo, hi in caixas:
            caixas_col += 1
            a = [min(SUB - 1, int(round(lo[i] / 16 * SUB))) for i in range(3)]
            b = [max(a[i] + 1, int(round(hi[i] / 16 * SUB))) for i in range(3)]
            for i in range(a[0], b[0]):
                for j in range(a[1], b[1]):
                    for k in range(a[2], b[2]):
                        sub.add((p[0] * SUB + i, p[1] * SUB + j, p[2] * SUB + k))
    faces_sub = {}
    for c in sub:
        for face, d in DIRS.items():
            n = (c[0] + d[0], c[1] + d[1], c[2] + d[2])
            if n in sub or (n[0] // SUB, n[1] // SUB, n[2] // SUB) in cheios:
                continue
            ia, ib = EIXOS_FACE[face]
            eixo_n = 3 - ia - ib
            faces_sub.setdefault((face, c[eixo_n] + (1 if d[eixo_n] > 0 else 0)), set()).add((c[ia], c[ib]))
    for (face, camada), cels in faces_sub.items():
        for a, b, w, h in retangulos(cels):
            cantos = [tuple(v / SUB for v in ponto_face(face, camada, a + ca, b + cb)) for ca, cb in ((0, 0), (w, 0), (w, h), (0, h))]
            emitir(col, mcol, cantos, [(0, 0)] * 4, DIRS[face])

    # ---- metros, pivô no centro da base
    cx, cz = tamanho[0] / 2.0, tamanho[2] / 2.0
    def em_metros(m):
        for _, (pos, _, _, _) in m.partes.items():
            for i, (x, y, z) in enumerate(pos):
                pos[i] = ((x - cx) * METROS_POR_BLOCO, y * METROS_POR_BLOCO, (z - cz) * METROS_POR_BLOCO)
    em_metros(malha)
    em_metros(col)
    raiz = gltf.no("mpe_" + nome_est)
    gltf.filho(raiz, gltf.no("Blocos", malha=gltf.malha(malha, "Blocos")))
    if not col.vazia():
        gltf.filho(raiz, gltf.no("Colisao", malha=gltf.malha(col, "Colisao")))
    gltf.gravar(destino)
    tri = sum(len(i) for _, (_, _, _, i) in malha.partes.items()) // 3
    tri_col = sum(len(i) for _, (_, _, _, i) in col.partes.items()) // 3
    rel.update({"blocos": len(grade), "faces_unidas": unidos, "faces_soltas": soltos, "triangulos": tri,
                "triangulos_colisao": tri_col, "caixas_parciais": caixas_col, "materiais": len(gltf.g["materials"]) - 1,
                "tamanho_m": [round(t * METROS_POR_BLOCO, 2) for t in tamanho], "arquivo": os.path.relpath(destino, PROJETO),
                "kb": os.path.getsize(destino) // 1024})
    return rel


def main():
    global SAIDA_TMP
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", default=os.path.join(PROJETO, "build/mine_piece/estruturas"))
    ap.add_argument("--so", nargs="*")
    ap.add_argument("--relatorio", default=os.path.join(PROJETO, "build/mine_piece/estruturas/relatorio.json"))
    a = ap.parse_args()
    os.makedirs(a.saida, exist_ok=True)
    SAIDA_TMP = a.saida
    rec = Recursos()
    pasta = os.path.join(FONTE, "data/minepiece/structures")
    nomes = sorted(os.path.splitext(n)[0] for n in os.listdir(pasta) if n.endswith(".nbt"))
    if a.so:
        nomes = [n for n in nomes if n in a.so]
    relatorio = []
    for n in nomes:
        r = converter(rec, os.path.join(pasta, n + ".nbt"), os.path.join(a.saida, f"mpe_{n}.glb"))
        if r is None:
            print(f"{n:32s} vazia (só ar/água/barreira)")
            continue
        relatorio.append(r)
        print(f"{n:32s} {r['blocos']:7d} blocos  {r['triangulos']:7d} tri  col {r['triangulos_colisao']:6d}  "
              f"mat {r['materiais']:3d}  {r['kb']:6d} KB" + (f"  SEM MODELO {r['sem_modelo']}" if r["sem_modelo"] else ""))
    try:
        os.remove(os.path.join(a.saida, "t.png"))
    except OSError:
        pass
    with open(a.relatorio, "w") as f:
        json.dump(relatorio, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
