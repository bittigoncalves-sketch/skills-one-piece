"""Gera as 9 comidas e bebidas em VOXEL (16³) no Blender (headless) e exporta GLB para a mão do jogador.

    blender -b -P tools/alimentos_voxel/gerar_alimentos.py -- [--so ID ...]

Reaproveita `tools/akuma_no_mi/gerar_frutas.py` (grade voxel, atlas de 6 vistas, exportação): atlas 48×32 = 3×2 vistas 16×16
(frente|tras|direita / esquerda|topo|base; ver o cabeçalho de gerar_frutas.py). A silhueta de cada item é descrita aqui por
primitivas (caixa, elipsoide, cilindro vertical) pintadas em ordem; papel "_" apaga.
Saída: assets/models/alimentos_voxel/<id>.glb, art_src/alimentos_voxel/guias/<id>_guia.png (silhueta) e <id>_reserva.png (cores lisas).
Textura do Codex (opcional): art_src/alimentos_voxel/texturas/<id>.png (48×32).
Eixos do desenho = Godot (y para cima, frente = -Z). Origem = centro da grade; o jogo posiciona na mão (tabela em alimentos_voxel.gd).
"""
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "tools", "akuma_no_mi"))
import gerar_frutas as G  # noqa: E402

N = 16
G.configurar(N, 0.02)                                    # 16 × 0,02 = 32 cm de aresta máxima
ARTE = os.path.join(RAIZ, "art_src/alimentos_voxel")
SAIDA = os.path.join(RAIZ, "assets/models/alimentos_voxel")


def box(a, b, papel):
    return {"t": "box", "a": a, "b": b, "papel": papel}


def elip(c, r, papel):
    return {"t": "elip", "c": c, "r": r, "papel": papel}


def cil(c, y, r, papel):
    return {"t": "cil", "c": c, "y": y, "r": r, "papel": papel}


ITENS = {
    "pao": {"paleta": {"crosta": "#b9803c", "topo": "#d9a65a", "corte": "#f0d9a0"}, "prims": [
        elip((8, 6, 8), (7.2, 4.2, 4.8), "crosta"), elip((8, 8.4, 8), (5.2, 1.8, 3.6), "topo"),
        box((4, 9, 7), (6, 10, 9), "corte"), box((7, 9, 7), (9, 10, 9), "corte"), box((10, 9, 7), (12, 10, 9), "corte")]},
    "maca": {"paleta": {"casca": "#c8312b", "caule": "#5a3a1e", "folha": "#3f8f3a"}, "prims": [
        elip((8, 7, 8), (5.4, 4.9, 5.4), "casca"), elip((8, 11.2, 8), (1.6, 1.2, 1.6), "_"),
        box((8, 10, 8), (9, 13, 9), "caule"), box((9, 12, 8), (12, 13, 9), "folha"), box((10, 11, 8), (12, 12, 9), "folha")]},
    "peixe_assado": {"paleta": {"corpo": "#c98a45", "barriga": "#e6c58a", "palito": "#8a5a2a", "cauda": "#a8672b", "olho": "#1a1a1a"}, "prims": [
        box((7, 0, 1), (8, 1, 15), "palito"), box((8, 5, 1), (9, 6, 15), "palito"),
        elip((8, 5.5, 7), (3.1, 3.6, 5.2), "corpo"), elip((8, 3.2, 7), (2.6, 1.6, 4.2), "barriga"),
        box((7, 4, 12), (9, 8, 14), "cauda"), box((6, 3, 13), (10, 9, 15), "cauda"),
        box((5, 6, 3), (6, 7, 4), "olho"), box((10, 6, 3), (11, 7, 4), "olho")]},
    "sopa_de_peixe": {"paleta": {"tigela": "#b8a07a", "sopa": "#d9822b", "borda": "#8a6b3d", "peixe": "#e6c58a"}, "prims": [
        cil((8, 8), (1, 3), 3.2, "borda"), cil((8, 8), (3, 9), 6.4, "tigela"), cil((8, 8), (5, 9), 5.3, "_"),
        cil((8, 8), (5, 7), 5.0, "sopa"), box((6, 7, 6), (9, 8, 8), "peixe"), box((9, 7, 9), (11, 8, 10), "peixe")]},
    "refeicao": {"paleta": {"prato": "#e8e0c8", "borda": "#c8c0a8", "carne": "#8a4a2a", "legume": "#4f9a3a", "arroz": "#f2efe2"}, "prims": [
        cil((8, 8), (2, 4), 7.2, "prato"), cil((8, 8), (3, 4), 7.6, "borda"), elip((6, 5.2, 7), (3.4, 1.8, 3.6), "carne"),
        elip((11, 5, 6), (2.3, 1.4, 2.3), "legume"), elip((10, 5, 11), (3.2, 1.6, 2.6), "arroz")]},
    "carne_assada": {"paleta": {"carne": "#9a4a2a", "tostado": "#6e2f1a", "osso": "#f0e6c8"}, "prims": [
        elip((7, 7, 8), (5.2, 4.6, 4.6), "carne"), elip((6, 9.6, 8), (3.6, 1.6, 3.2), "tostado"),
        box((11, 6, 7), (15, 8, 9), "osso"), box((14, 5, 6), (16, 9, 8), "osso"), box((14, 5, 8), (16, 9, 10), "osso")]},
    "agua_potavel": {"paleta": {"vidro": "#a8d8f0", "agua": "#4a9ad8", "tampa": "#d8d8e0", "rotulo": "#ffffff"}, "prims": [
        cil((8, 8), (1, 10), 4.2, "vidro"), cil((8, 8), (10, 13), 2.2, "vidro"), cil((8, 8), (13, 15), 2.6, "tampa"),
        cil((8, 8), (2, 9), 3.6, "agua"), box((4, 4, 4), (12, 8, 5), "rotulo")]},
    "leite": {"paleta": {"caixa": "#f4f4f4", "topo": "#d8e4f0", "faixa": "#3a7ad8", "bico": "#e8e8e8"}, "prims": [
        box((4, 1, 5), (12, 11, 11), "caixa"), box((4, 11, 6), (12, 13, 10), "topo"), box((6, 13, 7), (10, 14, 9), "topo"),
        box((6, 4, 4), (10, 8, 5), "faixa"), box((7, 14, 7), (9, 15, 9), "bico")]},
    "suco_de_laranja": {"paleta": {"copo": "#e8f0f4", "suco": "#f08a1c", "laranja": "#f5a623", "casca": "#d9701a", "canudo": "#e8e0c8"}, "prims": [
        cil((8, 8), (1, 11), 4.6, "copo"), cil((8, 8), (3, 10), 3.9, "suco"), box((9, 7, 7), (10, 16, 8), "canudo"),
        elip((12, 10, 8), (2.6, 2.6, 0.9), "casca"), elip((12, 10, 8), (2.0, 2.0, 1.0), "laranja")]},
}


def voxels(spec):
    cheio = {}
    for p in spec["prims"]:
        for ix in range(N):
            for iy in range(N):
                for iz in range(N):
                    c = (ix + 0.5, iy + 0.5, iz + 0.5)
                    if p["t"] == "box":
                        dentro = all(p["a"][k] <= c[k] < p["b"][k] for k in range(3))
                    elif p["t"] == "elip":
                        dentro = sum(((c[k] - p["c"][k]) / p["r"][k]) ** 2 for k in range(3)) <= 1.0
                    else:
                        dx, dz = c[0] - p["c"][0], c[2] - p["c"][1]
                        dentro = p["y"][0] <= c[1] < p["y"][1] and dx * dx + dz * dz <= p["r"] ** 2
                    if dentro:
                        if p["papel"] == "_":
                            cheio.pop((ix, iy, iz), None)
                        else:
                            cheio[(ix, iy, iz)] = p["papel"]
    if not cheio:
        raise SystemExit("silhueta vazia")
    return cheio


def reserva(cheio, paleta):
    W, H = G.ATLAS
    pix = [0.0] * (W * H * 4)
    vis = {}
    for idx in cheio:
        for v in G.VISTAS:
            n = v[0]
            if (idx[0] + n[0], idx[1] + n[1], idx[2] + n[2]) in cheio:
                continue
            t = G.texel(v, idx)
            prof = G.dot(idx, n)
            if t not in vis or prof > vis[t][0]:
                vis[t] = (prof, idx, v[1])
    for (x, y), (_, idx, nome) in vis.items():
        base = G.hex_rgb(paleta.get(cheio[idx], "#cccccc"))
        s = G.SOMBRA[nome]
        o = ((H - 1 - y) * W + x) * 4
        pix[o:o + 4] = [min(1, base[0] * s), min(1, base[1] * s), min(1, base[2] * s), 1.0]
    return pix


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    so = args[args.index("--so") + 1:] if "--so" in args else []
    os.makedirs(os.path.join(ARTE, "guias"), exist_ok=True)
    os.makedirs(SAIDA, exist_ok=True)
    for fid, spec in ITENS.items():
        if so and fid not in so:
            continue
        cheio = voxels(spec)
        fora = [k for k in cheio if not all(0 <= k[j] < N for j in range(3))]
        if fora:
            raise SystemExit(f"{fid}: {len(fora)} voxels fora da grade")
        pix = reserva(cheio, spec["paleta"])
        res = os.path.join(ARTE, "guias", f"{fid}_reserva.png")
        G.gravar_png(f"{fid}_reserva", pix, res)
        guia = [0.0] * len(pix)
        for i in range(0, len(pix), 4):
            if pix[i + 3] > 0:
                guia[i:i + 4] = [0.85, 0.85, 0.85, 1.0]
        G.gravar_png(f"{fid}_guia", guia, os.path.join(ARTE, "guias", f"{fid}_guia.png"))
        do_codex = os.path.join(ARTE, "texturas", f"{fid}.png")
        tex = do_codex if os.path.exists(do_codex) else res
        vazios = G.texels_sem_pintura(cheio, tex) if tex == do_codex else 0
        if vazios:
            print(f"AVISO {fid}: {vazios} texels usados pelo modelo estão transparentes no atlas (repintar contra a guia atual)")
        destino, nf = G.exportar(fid, cheio, tex, SAIDA)
        print(f"OK {fid:16} {len(cheio):4} voxels {nf:4} faces  textura {'Codex' if tex == do_codex else 'reserva'}")


if __name__ == "__main__":
    main()
