"""Fontes autorais das skins. Execute com python3; gera SVGs importáveis no Godot.
Atlas: seis faces por linha (-Z,+Z,-X,+X,+Y,-Y), oito partes, células 64px.
Não depende de IA, bibliotecas externas ou texturas de terceiros.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/textures/skins_historia"
OUT.mkdir(parents=True, exist_ok=True)

def rect(x, y, w, h, c):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'

def path(d, c, stroke="none", width=1):
    return f'<path d="{d}" fill="{c}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"/>'

def face(row, side, female, tone):
    skin, shade, light = tone["pele"], tone["sombra"], tone["luz"]
    hair, shine = "#35251f", "#654032"
    cloth = "#c65e50" if female else "#246d79"
    dark = "#873f40" if female else "#194d5b"
    cream, gold = "#f4dfb3", "#dba95a"
    base = [skin, cloth, cloth, "#253d55", "#2d475f", "#47342c", cloth, skin][row]
    s = rect(0, 0, 64, 64, base)
    if row == 0:
        if side == 0:
            s += path("M0 0H64V18L55 14L49 18L43 10L27 16L16 13L8 24H0Z" if female else
                      "M0 0H64V20H57V13H42V10H20V15H7V28H0Z", hair)
            s += path("M3 3H57V7H38V10H18V7H3Z", shine)
            if female:
                for x in (12, 38):
                    s += path(f"M{x} 30l3 -3h10l3 3v8l-3 3h-10l-3 -3z", "#fff1dc")
                    s += rect(x+6, 29, 7, 12, "#43776a") + rect(x+8, 29, 4, 10, "#182c32")
                    s += rect(x+7, 30, 3, 3, "#ffffff")
                    s += path(f"M{x-3} 26l4 3h13l3 2", "none", hair, 2)
                    s += path(f"M{x} 23l6 -2l8 1", "none", shine, 2)
                s += path("M29 36l-2 8h6", "none", shade, 2)
                s += path("M25 50l7 -2l7 2l-7 4z", tone["labio"])
                s += path("M28 50h8", "none", tone["brilho_labio"], 1)
                s += rect(10, 43, 9, 2, tone["bochecha"]) + rect(45, 43, 9, 2, tone["bochecha"])
            else:
                for x in (11, 39):
                    s += rect(x, 28, 15, 8, "#f9e6cb") + rect(x+5, 28, 6, 8, "#3a5149")
                    s += rect(x+7, 28, 4, 7, "#172c30") + rect(x+6, 29, 2, 2, "#ffffff")
                    s += path(f"M{x-1} 21l16 2v3l-16 -1z", hair)
                s += path("M30 34l-3 10h8", "none", shade, 2)
                s += path("M24 51h16", "none", tone["boca"], 2)
                s += path("M18 55l7 4h14l7 -4", "none", shade, 2)
            s += path("M7 40v11l7 8h36l7 -8V40", "none", shade, 1)
        elif side == 1 or side == 4:
            s = rect(0, 0, 64, 64, hair)
            for x in (7, 17, 29, 42, 54):
                s += path(f"M{x} 2v45l-3 14", "none", shine, 2)
            if not female and side == 1:
                s += path("M0 49l10 -3l4 7h36l4 -7l10 3v15H0Z", skin)
        elif side in (2, 3):
            s += path("M0 0H64V48L52 53V24H39V20H0Z" if female else "M0 0H64V28H45V22H16V37H8V20H0Z", hair)
            s += rect(27, 30, 11, 16, light) + rect(31, 34, 4, 8, shade)
            s += path("M5 6h49v9", "none", shine, 2)
    elif row in (1, 2, 6):
        s += rect(0, 0, 5, 64, dark) + rect(59, 0, 5, 64, dark)
        s += path("M8 3v58M56 3v58", "none", "#db8570" if female else "#408593", 1)
        if row == 1 and side == 0:
            s += path("M18 0h28L32 36Z", skin)
            s += path("M12 0h8l12 27L44 0h8L38 42H26Z", cream)
            s += path("M14 3l18 32L50 3", "none", gold, 2)
            s += path("M32 31l-7 13l7 8l7 -8z", "#284b61" if female else "#a4483c")
            s += rect(9, 46, 9, 2, gold) + rect(46, 46, 9, 2, gold)
        if row == 2 and side == 0:
            if female:
                s += path("M7 8l49 44M7 28l38 29", "none", "#e8967c", 2)
                s += rect(0, 53, 64, 11, dark)
                s += rect(29, 54, 7, 8, gold)
            else:
                s += rect(19, 0, 26, 64, skin)
                s += path("M31 2v55M22 16h19M22 33h19M23 49h17", "none", shade, 2)
                s += path("M17 0v64M47 0v64", "none", gold, 2)
        if row == 1 and side == 1:
            s += path("M8 0l24 23L56 0", "none", cream, 5)
        if row == 6:
            s += rect(0, 46, 64, 12, cream) + rect(0, 60, 64, 4, gold)
    elif row == 3:
        s += rect(0, 0, 64, 34, "#654234") + rect(0, 4, 64, 3, "#ab8052")
        if side == 0:
            s += rect(25, 5, 14, 26, gold) + rect(29, 9, 6, 18, "#533b32")
        s += path("M5 37l20 6M59 37l-20 6", "none", "#44607a", 2)
    elif row == 4:
        s += rect(2, 0, 3, 64, "#58718a") + rect(59, 0, 3, 64, "#1c3045")
        if side in (0, 1):
            s += path("M10 8h32l10 8M12 50l33 -4M18 56h33", "none", "#3c5870", 2)
    elif row == 5:
        s += rect(0, 52, 64, 12, "#29282b") + rect(0, 0, 64, 7, "#815638")
        if side in (0, 2, 3):
            s += rect(0, 18, 64, 8, "#71513b") + rect(43, 17, 10, 10, gold)
        if side == 0:
            s += path("M10 43h44M14 48h36", "none", "#896044", 2)
    elif row == 7:
        s += rect(0, 0, 4, 64, shade) + rect(60, 0, 4, 64, shade)
    return s

def main():
    tones = json.loads((OUT / "tons.json").read_text())
    for female in (False, True):
        for tone_id, tone in tones.items():
            svg = '<svg xmlns="http://www.w3.org/2000/svg" width="384" height="512" viewBox="0 0 384 512">'
            for row in range(8):
                for side in range(6):
                    svg += f'<g transform="translate({side*64} {row*64})">{face(row, side, female, tone)}</g>'
            svg += '</svg>'
            name = 'feminino' if female else 'masculino'
            suffix = '' if tone_id == 'medio' else '_' + tone_id
            (OUT / (name + suffix + '.svg')).write_text(svg)
    print(f'{len(tones) * 2} skins autorais exportadas para', OUT)


if __name__ == '__main__':
    main()
