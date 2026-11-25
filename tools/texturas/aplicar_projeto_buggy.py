#!/usr/bin/env python3
"""Aplica o projeto de texturas do Codex (art_src/textures/desafio_buggy/projeto.json) aos atlas ORIGINAIS 64×64 e grava os PNGs finais em assets/textures/desafio_buggy/.
Regras (do projeto.json `convencoes`): recolor por região comparando o RGB exato do atlas ORIGINAL (sem cascata), alfa de cada pixel preservado, pixels transparentes intactos;
depois, para o Buggy, cada expressão = base recolorida + a grade facial 8×8 (x=8..15, y=8..15; '.' preserva). Rodar da raiz:   python3 tools/texturas/aplicar_projeto_buggy.py
Valida no fim: 64×64 RGBA, alfa idêntico ao original, variantes só diferem da base dentro da região do rosto. Código de saída ≠ 0 se algo falhar."""
import json, os, sys
from PIL import Image

PROJETO = "art_src/textures/desafio_buggy/projeto.json"
ORIGINAIS = "mapas/modelos/"
SAIDA = "assets/textures/desafio_buggy/"


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def recolorir(original, regras, nome):
    saida = original.copy()
    px_o = original.load()
    px_s = saida.load()
    for r in regras:
        x0, y0, x1, y1 = r["regiao"]
        de, para = hexrgb(r["de"]), hexrgb(r["para"])
        achou = 0
        for y in range(y0, y1):
            for x in range(x0, x1):
                p = px_o[x, y]
                if p[3] == 0:
                    continue
                if p[:3] == de:
                    px_s[x, y] = para + (p[3],)
                    achou += 1
        if achou == 0:
            print("  AVISO %s: regra sem pixel de origem %s em %s" % (nome, r["de"], r["regiao"]))
    return saida


def aplicar_pontos(img, pontos, paleta):
    px = img.load()
    for p in pontos:
        cor = hexrgb(paleta.get(p["cor"], p["cor"]))
        a = px[p["x"], p["y"]][3]
        if a > 0:
            px[p["x"], p["y"]] = cor + (a,)


def main():
    proj = json.load(open(PROJETO))
    os.makedirs(SAIDA, exist_ok=True)
    erros = 0
    bases = {}
    for pid, dados in proj["personagens"].items():
        original = Image.open(ORIGINAIS + pid + "_corpo.png").convert("RGBA")
        if original.size != (64, 64):
            print("ERRO %s: atlas original não é 64×64" % pid)
            erros += 1
            continue
        base = recolorir(original, dados["recores"], pid)
        aplicar_pontos(base, dados.get("pixels", []), dados.get("paleta", {}))
        base.save(SAIDA + pid + "_corpo.png")
        bases[pid] = (original, base)
        # validação: mesmo tamanho e alfa idêntico
        if [p[3] for p in original.getdata()] != [p[3] for p in base.getdata()]:
            print("ERRO %s: o alfa mudou" % pid)
            erros += 1
        mudou = sum(1 for a, b in zip(original.getdata(), base.getdata()) if a != b)
        print("ok %s_corpo.png: %d pixels recoloridos" % (pid, mudou))
    # expressões do Buggy
    ex = proj["expressoes_buggy"]
    x0, y0, x1, y1 = ex["regiao"]
    paleta = {k: hexrgb(v) for k, v in ex["paleta"].items()}
    original, base = bases["mp_buggy"]
    for nome, grade in ex["grades"].items():
        if len(grade) != 8 or any(len(l) != 8 for l in grade):
            print("ERRO grade %s não é 8×8" % nome)
            erros += 1
            continue
        var = base.copy()
        px = var.load()
        for j, linha in enumerate(grade):
            for i, c in enumerate(linha):
                if c == ".":
                    continue
                a = px[x0 + i, y0 + j][3]
                if a > 0:
                    px[x0 + i, y0 + j] = paleta[c] + (a,)
        var.save(SAIDA + "buggy_rosto_%s.png" % nome)
        # validação: fora do rosto idêntica à base; alfa idêntico
        for y in range(64):
            for x in range(64):
                dentro = x0 <= x < x1 and y0 <= y < y1
                if not dentro and var.getpixel((x, y)) != base.getpixel((x, y)):
                    print("ERRO %s: pixel fora do rosto mudou em (%d,%d)" % (nome, x, y))
                    erros += 1
        if [p[3] for p in var.getdata()] != [p[3] for p in original.getdata()]:
            print("ERRO %s: alfa mudou" % nome)
            erros += 1
        print("ok buggy_rosto_%s.png" % nome)
    if erros:
        print("%d ERRO(S)" % erros)
        sys.exit(1)
    print("TUDO OK")


if __name__ == "__main__":
    main()
