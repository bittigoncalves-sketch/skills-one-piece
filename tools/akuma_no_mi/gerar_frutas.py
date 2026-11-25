"""Gera as Akuma no Mi em VOXEL no Blender (headless) e exporta GLB para o jogo.

    blender -b -P tools/akuma_no_mi/gerar_frutas.py -- [--so ID ...]

Entrada : art_src/akuma_no_mi/manifesto.json (ids, cores)  +  art_src/akuma_no_mi/formas.json (silhueta de cada fruta)
          + (opcional) art_src/akuma_no_mi/texturas/<id>.png  (atlas do Codex)
Saída   : assets/models/akuma_no_mi/<id>.glb
          art_src/akuma_no_mi/guias/<id>_guia.png  (silhueta das 6 vistas: o que o Codex pinta)
          art_src/akuma_no_mi/guias/<id>_reserva.png (atlas de reserva lisa, até o Codex entregar)

ATLAS (decisão 25/11/2026): 6 vistas ortográficas de N×N texels lado a lado — 3 colunas × 2 linhas:
    linha 0: frente(-Z)  tras(+Z)   direita(+X)
    linha 1: esquerda(-X) topo(+Y)  base(-Y)
  Cada vista é o que um observador FORA vê olhando para aquela face, com "cima" = +Y (topo: cima = -Z, a frente;
  base: cima = -Z). Todo voxel cuja face aponta para a vista usa o texel (coluna, linha) da sua posição naquela
  projeção — por isso pintar as 6 vistas pinta a fruta inteira, e o desenho nasce direto de imagens de referência.
Eixos do desenho = os do Godot (y para cima, frente = -Z); o Blender recebe (x, -z, y) e o exportador devolve.
"""
import json
import math
import os
import sys

import bpy

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARTE = os.path.join(RAIZ, "art_src/akuma_no_mi")
SAIDA = os.path.join(RAIZ, "assets/models/akuma_no_mi")
N = 24                      # voxels por lado da grade
VOX = 0.026                 # metros por voxel (fruta ~0,6 m)
# direção da face → (nome, direita, cima, coluna, linha)
VISTAS = [
    ((0, 0, -1), "frente", (-1, 0, 0), (0, 1, 0), 0, 0),
    ((0, 0, 1), "tras", (1, 0, 0), (0, 1, 0), 1, 0),
    ((1, 0, 0), "direita", (0, 0, -1), (0, 1, 0), 2, 0),
    ((-1, 0, 0), "esquerda", (0, 0, 1), (0, 1, 0), 0, 1),
    ((0, 1, 0), "topo", (1, 0, 0), (0, 0, -1), 1, 1),
    ((0, -1, 0), "base", (-1, 0, 0), (0, 0, -1), 2, 1),
]
ATLAS = (3 * N, 2 * N)


def configurar(n, vox):
    """Outros geradores (alimentos, 16³) reaproveitam este módulo trocando a grade."""
    global N, VOX, ATLAS
    N, VOX, ATLAS = n, vox, (3 * n, 2 * n)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


# ----------------------------------------------------------------------------- silhuetas

def corpo(familia, p, x, y, z):
    """x,y,z em [-1,1] (y para cima). True se (x,y,z) está dentro do corpo."""
    a, b, c = p.get("raio", [0.78, 0.78, 0.78])
    yy = y
    if familia == "pera":                       # estreita em cima, larga embaixo
        t = (y + 1) / 2
        k = 0.55 + 0.45 * (1 - t) ** 0.8
        a, c = a * k, c * k
    elif familia == "gomos":                    # abóbora: raio ondulado por ângulo
        ang = math.atan2(z, x)
        k = 1 + p.get("gomo", 0.10) * math.cos(p.get("n_gomos", 6) * ang)
        a, c = a * k, c * k
    elif familia == "gota":                     # ponta para cima
        t = (y + 1) / 2
        k = 1.0 - 0.6 * max(0.0, t - 0.4) ** 1.2 * 2.2
        a, c = a * max(k, 0.25), c * max(k, 0.25)
    elif familia == "cilindro":                 # cilindro de cantos chanfrados
        r = (x * x + z * z) ** 0.5 / a
        return r <= 1.0 and abs(y) <= b * (1 - 0.18 * r ** 4)
    elif familia == "coracao":                  # coração (x,y) extrudado em z, mais fino nas pontas
        hx, hy = x * 1.25, y * 1.25 + 0.05
        em_xy = (hx * hx + hy * hy - 1) ** 3 - hx * hx * hy ** 3 <= 0
        return em_xy and abs(z) <= p.get("espessura", 0.62) * (1 - 0.35 * x * x - 0.15 * y * y)
    elif familia == "cacho":                    # 3 lóbulos
        d = 0
        lobos = p.get("lobos", [(-0.35, -0.2, 0.0, 0.55, 0.55, 0.55), (0.35, -0.2, 0.0, 0.55, 0.55, 0.55), (0.0, 0.3, 0.1, 0.55, 0.55, 0.55)])
        for ox, oy, oz, rx, ry, rz in lobos:
            r2 = ((x - ox) / rx) ** 2 + ((y - oy) / ry) ** 2 + ((z - oz) / rz) ** 2
            d = max(d, 1.0 if r2 <= 1 else 0.0)
        return d > 0
    return (x / a) ** 2 + (yy / b) ** 2 + (z / c) ** 2 <= 1.0


def voxels(f):
    familia, p = f.get("familia", "esfera"), f
    c0 = (N - 1) / 2
    cheio = {}                                   # (ix,iy,iz) -> papel: corpo | caule | folha
    for ix in range(N):
        for iy in range(N):
            for iz in range(N):
                x, y, z = (ix - c0) / (N / 2), (iy - c0) / (N / 2), (iz - c0) / (N / 2)
                if corpo(familia, p, x, y, z):
                    cheio[(ix, iy, iz)] = "corpo"
    if not cheio:
        raise SystemExit("silhueta vazia: " + familia)
    topo = max(k[1] for k in cheio)
    cx = round(sum(k[0] for k in cheio if k[1] == topo) / max(1, sum(1 for k in cheio if k[1] == topo)))
    cz = round(sum(k[2] for k in cheio if k[1] == topo) / max(1, sum(1 for k in cheio if k[1] == topo)))
    for esp in f.get("espinhos", []):
        dx, dy, dz = esp[:3]
        comp = esp[3] if len(esp) > 3 else f.get("espinho_comprimento", 3)      # protuberâncias retas para fora do corpo (ex.: raios do Goro)
        corpo_ = [k for k, v in cheio.items() if v == "corpo"]
        # ponto do corpo mais distante naquela direção
        melhor = max(corpo_, key=lambda k: k[0] * dx + k[1] * dy + k[2] * dz - 0.01 * (abs(k[0] - c0) + abs(k[1] - c0) + abs(k[2] - c0)) * 0)
        for t in range(1, comp + 1):
            k = (melhor[0] + dx * t, melhor[1] + dy * t, melhor[2] + dz * t)
            if all(0 <= k[j] < N for j in range(3)):
                cheio.setdefault(k, "corpo")
    for (dx, dz, lado, alto) in f.get("bracos", []):   # braço de cacto: sai de lado `lado` voxels e sobe `alto`
        corpo_ = [k for k, v in cheio.items() if v == "corpo"]
        base = max(corpo_, key=lambda k: k[0] * dx + k[2] * dz - abs(k[1] - c0))
        for t in range(1, lado + 1):
            for a in range(2):
                for b in range(2):
                    cheio.setdefault((base[0] + dx * t + a, base[1] + b, base[2] + dz * t), "corpo")
        for h in range(0, alto + 1):
            for a in range(2):
                for b in range(2):
                    cheio.setdefault((base[0] + dx * lado + a, base[1] + h, base[2] + dz * lado + b), "corpo")
    cauda = f.get("caule", "reto")
    if cauda != "nenhum":
        alt = {"reto": 3, "curvo": 4, "grosso": 3, "zigzag": 5, "nota": 5}.get(cauda, 3)
        larg = 2 if cauda == "grosso" else 1
        for h in range(1, alt + 1):
            for dx in range(larg):
                for dz in range(larg):
                    ox = (1 if (cauda == "curvo" and h >= 3) else 0)
                    if cauda == "zigzag":
                        ox = h % 2
                    if cauda == "nota" and h == alt:
                        ox = 1
                    k = (cx + dx + ox, min(topo + h, N - 1), cz + dz)
                    cheio.setdefault(k, "caule")
    for (dx, dy, dz, w, h, d) in f.get("blocos_topo", []):   # blocos extras (ex.: orelhas) relativos ao centro do topo
        for a in range(w):
            for b in range(h):
                for c in range(d):
                    cheio.setdefault((cx + dx + a, topo + dy + b, cz + dz + c), "corpo")
    if f.get("coroa"):
        for (ox, oz) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 1), (-2, -1), (1, 2), (-1, -2)):
            for h in range(1, 5 - (abs(ox) + abs(oz)) // 2 + 1):
                k = (cx + ox + (ox // 2) * (h // 3), min(topo + h, N - 1), cz + oz + (oz // 2) * (h // 3))
                cheio.setdefault(k, "folha")
    for i, (dx, dy, dz) in enumerate(f.get("folhas", [])[:6]):
        for t in range(3):
            k = (cx + dx * (t + 1), min(topo + 1 + dy + (t // 2), N - 1), cz + dz * (t + 1))
            if all(0 <= k[j] < N for j in range(3)):
                cheio.setdefault(k, "folha")
    fora = [k for k in cheio if not all(0 <= k[j] < N for j in range(3))]
    if fora:   # nada pode sair da grade 0..N-1: o atlas só tem N×N texels por vista
        raise SystemExit(f"{len(fora)} voxels fora da grade (ex. {fora[0]}): reduza raio/braços/espinhos em formas.json")
    return cheio


# ----------------------------------------------------------------------------- atlas

def texel(v, idx):
    """Coluna/linha do atlas e (i,j) de um voxel para a vista v."""
    _, _, direita, cima, col, lin = v
    c0 = (N - 1) / 2
    c = (idx[0] - c0, idx[1] - c0, idx[2] - c0)
    i = int(round(dot(c, direita) + c0))
    j = int(round(c0 - dot(c, cima)))
    return col * N + i, lin * N + j


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


PAPEL = {"caule": (0.36, 0.24, 0.12), "folha": (0.18, 0.5, 0.2)}
SOMBRA = {"frente": 1.0, "tras": 0.82, "direita": 0.92, "esquerda": 0.88, "topo": 1.15, "base": 0.65}


def atlas_reserva(cheio, cor, cor_caule=None):
    """Pixels RGBA do atlas liso: cada texel recebe a cor do voxel VISÍVEL (o mais externo) na vista."""
    W, H = ATLAS
    pix = [0.0] * (W * H * 4)
    vis = {}
    for idx in cheio:
        for v in VISTAS:
            n = v[0]
            viz = (idx[0] + n[0], idx[1] + n[1], idx[2] + n[2])
            if viz in cheio:
                continue
            t = texel(v, idx)
            prof = dot(idx, n)
            if t not in vis or prof > vis[t][0]:
                vis[t] = (prof, idx, v[1])
    for (x, y), (_, idx, nome) in vis.items():
        base = PAPEL.get(cheio[idx], cor)
        if cheio[idx] == "caule" and cor_caule:
            base = cor_caule
        s = SOMBRA[nome]
        o = ((H - 1 - y) * W + x) * 4          # Blender guarda imagens de baixo para cima
        pix[o:o + 4] = [min(1, base[0] * s), min(1, base[1] * s), min(1, base[2] * s), 1.0]
    return pix


def texels_sem_pintura(cheio, caminho):
    """Texels que algum voxel exposto usa mas que o PNG deixa transparentes (aparecem pretos no jogo)."""
    img = bpy.data.images.load(caminho)
    W, H = ATLAS
    if (img.size[0], img.size[1]) != (W, H):
        return -1
    px = img.pixels[:]
    usados = set()
    for idx in cheio:
        for v in VISTAS:
            n = v[0]
            if (idx[0] + n[0], idx[1] + n[1], idx[2] + n[2]) not in cheio:
                usados.add(texel(v, idx))
    return sum(1 for (x, y) in usados if px[((H - 1 - y) * W + x) * 4 + 3] < 0.1)


def gravar_png(nome, pix, caminho):
    W, H = ATLAS
    img = bpy.data.images.new(nome, W, H, alpha=True)
    img.pixels = pix
    img.filepath_raw = caminho
    img.file_format = "PNG"
    img.save()
    return img


# ----------------------------------------------------------------------------- malha

QUAD = {  # normal → 4 cantos relativos (-0.5..0.5) em ordem anti-horária vista de fora, com a (direita,cima) da vista
    (0, 0, -1): [(0.5, -0.5, -0.5), (-0.5, -0.5, -0.5), (-0.5, 0.5, -0.5), (0.5, 0.5, -0.5)],
    (0, 0, 1): [(-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5)],
    (1, 0, 0): [(0.5, -0.5, 0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (0.5, 0.5, 0.5)],
    (-1, 0, 0): [(-0.5, -0.5, -0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (-0.5, 0.5, -0.5)],
    (0, 1, 0): [(-0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5)],
    (0, -1, 0): [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5)],
}


def construir(cheio):
    W, H = ATLAS
    verts, faces, uvs = [], [], []
    c0 = (N - 1) / 2
    for idx in sorted(cheio):
        for v in VISTAS:
            n, _, direita, cima = v[0], v[1], v[2], v[3]
            if (idx[0] + n[0], idx[1] + n[1], idx[2] + n[2]) in cheio:
                continue
            tx, ty = texel(v, idx)
            base = len(verts)
            for cx, cy, cz in QUAD[n]:
                p = ((idx[0] - c0 + cx) * VOX, (idx[1] - c0 + cy) * VOX + (N / 2) * VOX * 0.0, (idx[2] - c0 + cz) * VOX)
                verts.append((p[0], -p[2], p[1]))          # Godot (x,y,z) → Blender (x,-z,y)
                # UV do canto: posição do canto projetada na vista, dentro do texel (nearest: fica no meio)
                u_ = (tx + 0.5) / W
                v_ = 1.0 - (ty + 0.5) / H
                uvs.append((u_, v_))
            faces.append((base, base + 1, base + 2, base + 3))
    return verts, faces, uvs


def exportar(fid, cheio, tex, pasta=None):
    """Monta a malha voxel (uma textura de atlas) numa cena limpa do Blender e exporta `<pasta>/<fid>.glb`."""
    # cena limpa
    bpy.ops.wm.read_factory_settings(use_empty=True)
    verts, faces, uvs = construir(cheio)
    me = bpy.data.meshes.new(fid)
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for li, loop in enumerate(me.loops):
        uv.data[li].uv = uvs[loop.vertex_index]
    me.update()
    ob = bpy.data.objects.new(f"akuma_{fid}", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("fruta")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    img = bpy.data.images.load(tex)
    imgn = nodes.new("ShaderNodeTexImage")
    imgn.image = img
    imgn.interpolation = "Closest"
    mat.node_tree.links.new(imgn.outputs["Color"], bsdf.inputs["Base Color"])
    mat.node_tree.links.new(imgn.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.55
    ob.data.materials.append(mat)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    destino = os.path.join((pasta or SAIDA), f"{fid}.glb")
    bpy.ops.export_scene.gltf(filepath=destino, export_format="GLB", use_selection=True, export_yup=True)
    return destino, len(faces)


def gerar(fid, forma, cor, brilho):
    cheio = voxels(forma)
    os.makedirs(os.path.join(ARTE, "guias"), exist_ok=True)
    os.makedirs(SAIDA, exist_ok=True)
    pix = atlas_reserva(cheio, hex_rgb(cor), hex_rgb(forma["cor_caule"]) if forma.get("cor_caule") else None)
    reserva = os.path.join(ARTE, "guias", f"{fid}_reserva.png")
    gravar_png(f"{fid}_reserva", pix, reserva)
    # guia: silhueta branca/cinza das 6 vistas (o que pintar)
    guia = [0.0] * len(pix)
    for i in range(0, len(pix), 4):
        if pix[i + 3] > 0:
            guia[i:i + 4] = [0.85, 0.85, 0.85, 1.0]
    gravar_png(f"{fid}_guia", guia, os.path.join(ARTE, "guias", f"{fid}_guia.png"))
    do_codex = os.path.join(ARTE, "texturas", f"{fid}.png")
    tex = do_codex if os.path.exists(do_codex) else reserva
    vazios = texels_sem_pintura(cheio, tex) if tex == do_codex else 0
    if vazios:
        print(f"AVISO {fid}: {vazios} texels usados pelo modelo estão transparentes no atlas (repintar contra a guia atual)")
    destino, nfaces = exportar(fid, cheio, tex)
    return destino, len(cheio), nfaces, "Codex" if tex == do_codex else "reserva"


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    so = args[args.index("--so") + 1:] if "--so" in args else []
    manifesto = {f["id"]: f for f in json.load(open(os.path.join(ARTE, "manifesto.json")))["frutas"]}
    formas = json.load(open(os.path.join(ARTE, "formas.json")))["frutas"]
    for fid, f in manifesto.items():
        if so and fid not in so:
            continue
        forma = formas.get(fid, formas["_padrao"])
        d, nv, nf, origem = gerar(fid, forma, f["cor"], f["brilho"])
        print(f"OK {fid:34} {nv:5} voxels {nf:5} faces  textura {origem}")


if __name__ == "__main__":
    main()
