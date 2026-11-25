#!/usr/bin/env python3
"""Reconstrução PRÓPRIA dos mobs da primeira ilha (pirata, galo, Chouchou).

    python3 -I tools/mine_piece/reconstruir_primeira_ilha.py [--so pirate chouchou suzume]

O Mine Piece é só REFERÊNCIA DE CONSTRUÇÃO (decisão do dono, 25/11/2026): do mod saem o
esqueleto (nomes e pivôs dos ossos que as animações usam) e os dados de tempo/pose das
animações — dados, não arte. Toda a MALHA é desenhada aqui (cubos próprios, proporções e
layout de UV próprios) e a TEXTURA é feita pelo Codex.

Saídas (tudo vai para o git; nada disto é arte do mod):
  art_src/reconstrucao/<id>.geo.json        geometria própria (formato Bedrock, 1 px = 1 voxel)
  art_src/reconstrucao/<id>.uv.json         retângulos de UV por cubo/face (briefing do Codex)
  art_src/reconstrucao/<id>_uv_guia.png     guia visual do atlas (8x)
  art_src/reconstrucao/<id>_provisoria.png  textura de reserva lisa, até o Codex entregar
  mapas/modelos/pi_<id>.glb                 modelo com as animações do esqueleto

Textura do Codex: `art_src/reconstrucao/texturas/<id>.png` (mesmo tamanho do atlas, ou múltiplo
inteiro; é reduzida sem suavizar). Existindo, entra no .glb no lugar da provisória.
`<id>` é o da ficha do personagem: pirate, chouchou e suzume (suzume vira o GALO).
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
sys.path.insert(0, AQUI)
import geo_para_glb as G  # noqa: E402

ARTE = os.path.join(RAIZ, "art_src/reconstrucao")
SAIDA = os.path.join(RAIZ, "mapas/modelos")
ANIM = os.path.join(G.FONTE, "assets/minepiece/animations")

# ----------------------------------------------------------------------------- esqueletos
# (nome, pai, pivô) — os pivôs de y/z são os do mod: as animações giram em torno deles.
# Cubo: (osso, origem, tamanho, cor, nome). Coordenadas Bedrock, px. Frente = −Z.

PIRATA = {
    "animacao": "biped.animation.json",
    "ossos": [
        ("body", None, [0, 12, 0]), ("head", "body", [0, 24, 0]), ("torso", "body", [0, 24, 0]),
        ("right_arm", "body", [-5, 22, 0]), ("itemMainHand", "right_arm", [-6, 12, -2]),
        ("left_arm", "body", [5, 22, 0]), ("itemOffHand", "left_arm", [6, 12, -2]),
        ("right_leg", "body", [-2, 12, 0]), ("left_leg", "body", [2, 12, 0]),
    ],
    "cubos": [
        ("head", [-4, 24, -4], [8, 7, 8], "#d9a074", "cabeca"),
        ("head", [-0.5, 24.5, -5], [1, 2, 1], "#c98d63", "nariz"),
        ("head", [1, 27, -5], [2, 2, 1], "#1c1c1c", "tapa_olho"),
        ("head", [-4.5, 31, -4.5], [9, 3, 9], "#2a2a33", "chapeu_copa"),
        ("head", [-6, 30.5, -6], [12, 1, 12], "#1f1f27", "chapeu_aba"),
        ("torso", [-4.5, 12, -2.5], [9, 12, 5], "#b8322f", "camisa"),
        ("torso", [-5, 13, -3], [10, 2, 6], "#5a3a1e", "cinto"),
        ("torso", [-5, 22, -3], [10, 2, 6], "#e8e0c8", "gola"),
        ("right_arm", [-8, 12, -2], [4, 12, 4], "#b8322f", "braco_d"),
        ("right_arm", [-8.5, 12, -2.5], [5, 3, 5], "#d9a074", "punho_d"),
        ("left_arm", [4, 12, -2], [4, 12, 4], "#b8322f", "braco_e"),
        ("left_arm", [3.5, 12, -2.5], [5, 3, 5], "#d9a074", "punho_e"),
        ("itemMainHand", [-6.5, 11.5, -1.5], [1, 1, 3], "#5a3a1e", "sabre_cabo"),
        ("itemMainHand", [-8, 10.5, -2.5], [4, 3, 1], "#c9a227", "sabre_guarda"),
        ("itemMainHand", [-6.5, 11, -14.5], [1, 2, 12], "#c4ccd4", "sabre_lamina"),
        ("itemMainHand", [-6.5, 11.5, -16.5], [1, 1, 2], "#e8eef2", "sabre_ponta"),
        ("right_leg", [-4, 0, -2], [4, 12, 4], "#3b3f5c", "perna_d"),
        ("right_leg", [-4.5, 0, -3.5], [5, 4, 6], "#2b1d12", "bota_d"),
        ("left_leg", [0, 0, -2], [4, 12, 4], "#3b3f5c", "perna_e"),
        ("left_leg", [-0.5, 0, -3.5], [5, 4, 6], "#2b1d12", "bota_e"),
    ],
}

CHOUCHOU = {
    "animacao": "chouchou.animation.json",
    "ossos": [
        ("body", None, [0, 10, 4]), ("head", "body", [0, 10.5, -7]), ("bone2", "head", [0, 9.75, -7.8]),
        ("bone", "bone2", [0, 6.42, -9.3]), ("tail", "body", [0, 12, 9]),
        ("leg1", "body", [-2.5, 8, 7]), ("leg2", "body", [2.5, 8, 7]),
        ("leg3", "body", [-2.5, 8, -4]), ("leg4", "body", [2.5, 8, -4]),
    ],
    "cubos": [
        ("body", [-3.5, 6.5, -6], [7, 7, 14], "#b5651d", "tronco"),
        ("body", [-4.5, 6, -8], [9, 8, 6], "#c97a2b", "juba"),
        ("head", [-3.5, 8, -13], [7, 6, 6], "#c97a2b", "cranio"),
        ("head", [-4.5, 7, -11], [9, 5, 4], "#b5651d", "bochechas"),
        ("head", [-2, 7.5, -16], [4, 3, 3], "#a8581a", "focinho"),
        ("head", [-1, 9, -17], [2, 1, 1], "#111111", "nariz"),
        ("head", [-3.5, 14, -10], [2, 2, 2], "#8a4b14", "orelha_d"),
        ("head", [1.5, 14, -10], [2, 2, 2], "#8a4b14", "orelha_e"),
        ("bone2", [-2, 6, -15], [4, 1, 4], "#a8581a", "mandibula"),
        ("bone", [-1, 3, -14.5], [2, 3, 2], "#3a4f8f", "lingua"),
        ("tail", [-1.5, 11, 8], [3, 3, 3], "#c97a2b", "rabo_base"),
        ("tail", [-1.5, 14, 6], [3, 3, 3], "#c97a2b", "rabo_curva"),
        ("leg1", [-4, 0, 5.5], [3, 8, 3], "#a8581a", "pata_td_d"),
        ("leg2", [1, 0, 5.5], [3, 8, 3], "#a8581a", "pata_td_e"),
        ("leg3", [-4, 0, -5.5], [3, 8, 3], "#a8581a", "pata_fr_d"),
        ("leg4", [1, 0, -5.5], [3, 8, 3], "#a8581a", "pata_fr_e"),
    ],
}

GALO = {
    "animacao": "suzume.animation.json",
    "ossos": [
        ("body", None, [0, 0, 0]), ("torso", "body", [0, 8, 0]), ("head", "torso", [0, 11, -3]),
        ("right_wing", "body", [-4, 11, 0]), ("left_wing", "body", [4, 11, 0]),
        ("right_leg", "body", [-1.5, 5, 1]), ("left_leg", "body", [1.5, 5, 1]),
    ],
    "cubos": [
        ("torso", [-3.5, 5, -4], [7, 7, 9], "#a8421c", "corpo"),
        ("torso", [-3, 6, -5.5], [6, 5, 2], "#d9892b", "peito"),
        ("torso", [-1, 8, 4], [2, 3, 2], "#1f6b4a", "cauda_1"),
        ("torso", [-1, 10, 5], [2, 3, 2], "#1f6b4a", "cauda_2"),
        ("torso", [-1, 12, 6], [2, 3, 2], "#2a8a5f", "cauda_3"),
        ("torso", [-2.5, 8, 4], [1, 4, 2], "#a8421c", "cauda_lado_d"),
        ("torso", [1.5, 8, 4], [1, 4, 2], "#a8421c", "cauda_lado_e"),
        ("head", [-1.5, 11, -5], [3, 4, 3], "#d9892b", "pescoco"),
        ("head", [-2, 14, -6.5], [4, 4, 4], "#e8e0c8", "cabeca"),
        ("head", [-1, 15, -8.5], [2, 1, 2], "#e0a020", "bico_cima"),
        ("head", [-1, 14, -8], [2, 1, 1], "#e0a020", "bico_baixo"),
        ("head", [-0.5, 18, -5.5], [1, 2, 4], "#c8202a", "crista"),
        ("head", [-0.5, 13, -7], [1, 2, 1], "#c8202a", "barbela"),
        ("right_wing", [-4.5, 6, -3.5], [1, 5, 7], "#8a3516", "asa_d"),
        ("left_wing", [3.5, 6, -3.5], [1, 5, 7], "#8a3516", "asa_e"),
        ("right_leg", [-2, 0, 0.5], [1, 5, 1], "#e0a020", "perna_d"),
        ("right_leg", [-3, 0, -1.5], [3, 1, 3], "#e0a020", "pe_d"),
        ("left_leg", [1, 0, 0.5], [1, 5, 1], "#e0a020", "perna_e"),
        ("left_leg", [0, 0, -1.5], [3, 1, 3], "#e0a020", "pe_e"),
    ],
}

MOBS = {"pirate": PIRATA, "chouchou": CHOUCHOU, "suzume": GALO}


# ----------------------------------------------------------------------------- atlas

def tam_caixa(s):
    sx, sy, sz = (int(v) for v in s)
    return 2 * sz + 2 * sx, sz + sy


def empacotar(cubos):
    """Acha o menor atlas (potência de 2) onde todos os UVs de caixa cabem. Devolve (w, h, [(u, v)])."""
    ordem = sorted(range(len(cubos)), key=lambda i: -tam_caixa(cubos[i][2])[1])
    for w, h in ((64, 32), (64, 64), (128, 64), (128, 128)):
        pos, x, y, alt = {}, 0, 0, 0
        ok = True
        for i in ordem:
            cw, ch = tam_caixa(cubos[i][2])
            if x + cw > w:
                x, y, alt = 0, y + alt, 0
            if y + ch > h or cw > w:
                ok = False
                break
            pos[i] = (x, y)
            x += cw
            alt = max(alt, ch)
        if ok:
            return w, h, [pos[i] for i in range(len(cubos))]
    raise SystemExit("atlas não coube em 128x128")


def faces(u, v, s):
    sx, sy, sz = (int(a) for a in s)
    return {  # retângulos x0,y0,x1,y1 da caixa (mesma convenção do geo_para_glb.faces_box_uv)
        "frente": [u + sz, v + sz, u + sz + sx, v + sz + sy],
        "direita": [u, v + sz, u + sz, v + sz + sy],
        "tras": [u + 2 * sz + sx, v + sz, u + 2 * sz + 2 * sx, v + sz + sy],
        "esquerda": [u + sz + sx, v + sz, u + 2 * sz + sx, v + sz + sy],
        "topo": [u + sz, v, u + sz + sx, v + sz],
        "base": [u + sz + sx, v, u + sz + 2 * sx, v + sz],
    }


def tom(cor, f):
    h = cor.lstrip("#")
    return tuple(max(0, min(255, int(int(h[i:i + 2], 16) * f))) for i in (0, 2, 4)) + (255,)


SOMBRA = {"topo": 1.15, "frente": 1.0, "tras": 0.85, "direita": 0.92, "esquerda": 0.92, "base": 0.7}


def desenhar(mob_id, spec, w, h, pos):
    prov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    guia = Image.new("RGBA", (w * 8, h * 8), (24, 24, 28, 255))
    dp, dg = ImageDraw.Draw(prov), ImageDraw.Draw(guia)
    tabela = []
    for i, ((osso, o, s, cor, nome), (u, v)) in enumerate(zip(spec["cubos"], pos)):
        fs = faces(u, v, s)
        for f, (x0, y0, x1, y1) in fs.items():
            if x1 > x0 and y1 > y0:
                dp.rectangle([x0, y0, x1 - 1, y1 - 1], fill=tom(cor, SOMBRA[f]))
                dg.rectangle([x0 * 8, y0 * 8, x1 * 8 - 1, y1 * 8 - 1], fill=tom(cor, SOMBRA[f]), outline=(255, 255, 255, 255))
                dg.text((x0 * 8 + 2, y0 * 8 + 1), f"{i}{f[0]}", fill=(255, 255, 255, 255))
        tabela.append({"indice": i, "cubo": nome, "osso": osso, "tamanho_px": [int(a) for a in s], "cor_sugerida": cor,
                       "faces": fs})
    return prov, guia, tabela


def gerar(mob_id, spec):
    w, h, pos = empacotar(spec["cubos"])
    os.makedirs(os.path.join(ARTE, "texturas"), exist_ok=True)
    prov, guia, tabela = desenhar(mob_id, spec, w, h, pos)
    caminho_prov = os.path.join(ARTE, f"{mob_id}_provisoria.png")
    prov.save(caminho_prov)
    guia.save(os.path.join(ARTE, f"{mob_id}_uv_guia.png"))
    with open(os.path.join(ARTE, f"{mob_id}.uv.json"), "w") as f:
        json.dump({"id": mob_id, "atlas": [w, h], "regra": "pixel transparente = nada; cada cubo é uma caixa com 6 faces "
                   "(topo/base/frente/tras/direita/esquerda); frente = -Z", "cubos": tabela}, f, ensure_ascii=False, indent=1)
    # geo.json no formato Bedrock (o mesmo que o conversor lê)
    ossos = []
    for nome, pai, piv in spec["ossos"]:
        osso = {"name": nome, "pivot": piv, "cubes": []}
        if pai:
            osso["parent"] = pai
        for (b, o, s, cor, n), (u, v) in zip(spec["cubos"], pos):
            if b == nome:
                osso["cubes"].append({"origin": o, "size": s, "uv": [u, v]})
        ossos.append(osso)
    with open(os.path.join(ARTE, f"{mob_id}.geo.json"), "w") as f:
        json.dump({"format_version": "1.12.0", "minecraft:geometry": [{
            "description": {"identifier": f"geometry.pi_{mob_id}", "texture_width": w, "texture_height": h}, "bones": ossos}]},
            f, indent=1)
    # textura final: a do Codex (se existir) ou a provisória
    tex = caminho_prov
    do_codex = os.path.join(ARTE, "texturas", f"{mob_id}.png")
    origem = "provisória"
    if os.path.exists(do_codex):
        im = Image.open(do_codex).convert("RGBA")
        if im.size != (w, h):
            if im.size[0] % w or im.size[1] % h or im.size[0] // w != im.size[1] // h:
                raise SystemExit(f"{do_codex}: {im.size} não é {w}x{h} nem múltiplo inteiro")
            im = im.resize((w, h), Image.NEAREST)
        tex = os.path.join(ARTE, f"_final_{mob_id}.png")
        im.save(tex)
        origem = "Codex"
    # malha + esqueleto + animações
    gl = G.Gltf()
    raiz = gl.no(f"pi_{mob_id}", r=G.quat_euler_zyx(0, 0, 0))
    mat = gl.material(tex, "corpo")
    piv = {n: [-p[0], p[1], p[2]] for n, _, p in spec["ossos"]}
    malhas = {n: G.Malha() for n, _, _ in spec["ossos"]}
    for o in ossos:
        G.cubos_bedrock(malhas[o["name"]], mat, o, w, h, piv[o["name"]])
    nos, rest = {}, {}
    for nome, pai, _ in spec["ossos"]:
        base = piv[pai] if pai else [0, 0, 0]
        t = [(piv[nome][i] - base[i]) / 16.0 for i in range(3)]
        rest[nome] = [0, 0, 0]
        malha = gl.malha(malhas[nome], nome) if not malhas[nome].vazia() else None
        nos[nome] = gl.no(nome, t=t, r=G.quat_euler_zyx(0, 0, 0), malha=malha)
    for nome, pai, _ in spec["ossos"]:
        gl.filho(nos[pai] if pai else raiz, nos[nome])
    n_anim = G.adicionar_animacoes(gl, nos, rest, os.path.join(ANIM, spec["animacao"]))
    destino = os.path.join(SAIDA, f"pi_{mob_id}.glb")
    gl.gravar(destino)
    print(f"OK   {mob_id:9} atlas {w}x{h}  {len(spec['cubos'])} cubos  {n_anim} animações  textura {origem}  -> {destino}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--so", nargs="*")
    a = ap.parse_args()
    for mob_id, spec in MOBS.items():
        if not a.so or mob_id in a.so:
            gerar(mob_id, spec)


if __name__ == "__main__":
    main()
