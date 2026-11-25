#!/usr/bin/env python3
"""Converte as grades 16×16 do Codex (art_src/references/resgate_bau/texturas.json) em PNGs RGBA em assets/textures/resgate_bau/ (3ª missão, 21/11/2026).
'.' = transparente; as demais chaves = cor opaca da paleta. Saídas: mimico_tampa, mimico_corpo, mimico_boca, bau_misterioso. Rodar da raiz:  python3 tools/texturas/aplicar_texturas_bau.py"""
import json, os, sys
from PIL import Image

ENTRADA = "art_src/references/resgate_bau/texturas.json"
SAIDA = "assets/textures/resgate_bau/"
ICONE_DO_ITEM = "assets/ui/itens/bau_misterioso.png"        # o mesmo ícone, para a mochila
NOMES = {"tampa_disfarce": "mimico_tampa", "corpo_disfarce": "mimico_corpo", "boca_revelada": "mimico_boca", "icone_bau_misterioso": "bau_misterioso"}


def hexrgba(h):
    h = h.lstrip("#")
    if len(h) == 6:
        h += "ff"
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))


def main():
    d = json.load(open(ENTRADA))
    paleta = {k: hexrgba(v) for k, v in d["paleta"].items()}
    os.makedirs(SAIDA, exist_ok=True)
    erros = 0
    for chave, saida in NOMES.items():
        grade = d["texturas"][chave]["grade"]
        if len(grade) != 16 or any(len(l) != 16 for l in grade):
            print("ERRO %s: não é 16×16" % chave)
            erros += 1
            continue
        im = Image.new("RGBA", (16, 16))
        for y, linha in enumerate(grade):
            for x, c in enumerate(linha):
                if c not in paleta:
                    print("ERRO %s: chave '%s' fora da paleta" % (chave, c))
                    erros += 1
                    continue
                im.putpixel((x, y), paleta[c])
        im.save(SAIDA + saida + ".png")
        if saida == "bau_misterioso":
            os.makedirs(os.path.dirname(ICONE_DO_ITEM), exist_ok=True)
            im.save(ICONE_DO_ITEM)
        print("ok", saida + ".png")
    if erros:
        sys.exit(1)
    print("TUDO OK")


if __name__ == "__main__":
    main()
