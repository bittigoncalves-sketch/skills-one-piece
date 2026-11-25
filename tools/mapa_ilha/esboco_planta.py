"""Esboço da planta da Ilha Inicial, visto de cima, para aprovação do desenho.

    python3 tools/mapa_ilha/esboco_planta.py [saida.png]

Lê `tools/mapa_ilha/planta.json` (a mesma fonte do gerador). É um DESENHO de
intenção: regiões, rio, estradas e pontes. O relevo de verdade sai do gerador;
a conferência final é a captura do mapa montado no Godot.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parents[2]
PLANTA = json.loads((RAIZ / "tools/mapa_ilha/planta.json").read_text())
MEIA = PLANTA["ilha"]["meia"]
RIO = PLANTA["rio"]
LADO = 1024
MAR = 96                      # pixels de mar em volta da ilha
ESCALA = (LADO - 2 * MAR) / (2 * MEIA)


def tela(x, z):
    return (MAR + (x + MEIA) * ESCALA, MAR + (z + MEIA) * ESCALA)


def rio_x(z):
    return RIO["amplitude"] * math.sin(math.pi * z / MEIA)


def rio_largura(z):
    t = (z + MEIA) / (2 * MEIA)
    return RIO["largura_norte"] + (RIO["largura_sul"] - RIO["largura_norte"]) * t


def cruzamentos(pontos):
    """Onde a polilinha da estrada cruza o eixo do rio (troca de lado)."""
    achados = []
    for (ax, az), (bx, bz) in zip(pontos, pontos[1:]):
        lado_a = ax - rio_x(az)
        lado_b = bx - rio_x(bz)
        if lado_a * lado_b > 0:
            continue
        lo, hi = 0.0, 1.0
        for _ in range(40):
            m = (lo + hi) / 2
            x, z = ax + (bx - ax) * m, az + (bz - az) * m
            if (x - rio_x(z)) * lado_a > 0:
                lo = m
            else:
                hi = m
        achados.append((ax + (bx - ax) * lo, az + (bz - az) * lo, math.atan2(bz - az, bx - ax)))
    return achados


def main():
    saida = Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / "tools/mapa_ilha/esboco_planta.png"
    img = Image.new("RGB", (LADO, LADO), "#1f6fa8")
    d = ImageDraw.Draw(img, "RGBA")
    fonte = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 17)
    fonte_peq = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
    praia = PLANTA["ilha"]["faixa_de_praia"]
    # Ilha: areia na borda, grama por dentro.
    d.rectangle([tela(-MEIA, -MEIA), tela(MEIA, MEIA)], fill="#e3cf98")
    d.rectangle([tela(-MEIA + praia, -MEIA + praia), tela(MEIA - praia, MEIA - praia)], fill="#7cb85a")
    # Floresta: metade oeste do rio, por dentro da praia.
    for zi in range(int(-MEIA + praia), int(MEIA - praia), 4):
        borda = rio_x(zi) - rio_largura(zi) / 2 - RIO["margem"] - 6
        d.rectangle([tela(-MEIA + praia, zi), tela(borda, zi + 4)], fill=PLANTA["floresta"]["cor"])
    for r in PLANTA["regioes"]:
        cx, cz = r["centro"]
        a, b = tela(cx - r["raio"], cz - r["raio"]), tela(cx + r["raio"], cz + r["raio"])
        cor = r["cor"] + ("cc" if r["id"] != "morros" else "99")
        d.ellipse([a, b], fill=cor)
    # Rio: faixa em S.
    for zi in range(int(-MEIA), int(MEIA), 2):
        x, w = rio_x(zi), rio_largura(zi)
        d.rectangle([tela(x - w / 2 - RIO["margem"], zi), tela(x + w / 2 + RIO["margem"], zi + 2)], fill="#cdb68a")
    for zi in range(int(-MEIA), int(MEIA), 2):
        x, w = rio_x(zi), rio_largura(zi)
        d.rectangle([tela(x - w / 2, zi), tela(x + w / 2, zi + 2)], fill="#3d9fd6")
    # Estradas e pontes.
    for e in PLANTA["estradas"]:
        d.line([tela(*p) for p in e["pontos"]], fill="#8a6a43", width=7, joint="curve")
    for e in PLANTA["estradas"]:
        for x, z, ang in cruzamentos(e["pontos"]):
            comp = rio_largura(z) + 2 * RIO["margem"] + 6
            dx, dz = math.cos(ang) * comp / 2, math.sin(ang) * comp / 2
            d.line([tela(x - dx, z - dz), tela(x + dx, z + dz)], fill="#5a3b1c", width=13)
            d.text(tela(x + 10, z - 16), "ponte", fill="white", font=fonte_peq, stroke_width=2, stroke_fill="black")
    # Porto: cais saindo para o mar e navios.
    px, pz = 256, 40
    for i, off in enumerate((-22, 0, 22)):
        d.rectangle([tela(px - 4, pz + off - 4), tela(px + 30, pz + off + 4)], fill="#6b4a2a")
    for i, (sx, sz, comp, larg) in enumerate(((300, 18, 30, 9), (296, 40, 14, 5), (292, 62, 7, 3))):
        d.ellipse([tela(sx - comp / 2, sz - larg / 2), tela(sx + comp / 2, sz + larg / 2)], fill="#3a2410")
    # Rótulos.
    for r in PLANTA["regioes"]:
        cx, cz = r["centro"]
        d.text(tela(cx - 30, cz - 8), r["nome"], fill="white", font=fonte, stroke_width=3, stroke_fill="black")
    d.text(tela(-200, 40), "FLORESTA", fill="white", font=fonte, stroke_width=3, stroke_fill="black")
    d.text(tela(rio_x(-200) + 14, -200), "RIO", fill="white", font=fonte, stroke_width=3, stroke_fill="black")
    d.text(tela(270, 76), "navios", fill="white", font=fonte_peq, stroke_width=2, stroke_fill="black")
    sx, sz = PLANTA["spawn"]
    d.ellipse([tela(sx - 4, sz - 4), tela(sx + 4, sz + 4)], fill="#ff3b3b", outline="white", width=2)
    d.text(tela(sx + 6, sz + 2), "nascimento", fill="white", font=fonte_peq, stroke_width=2, stroke_fill="black")
    # Grade dos blocos de terreno.
    bloco = PLANTA["ilha"]["bloco"]
    n = int(2 * MEIA / bloco)
    for i in range(n + 1):
        v = -MEIA + i * bloco
        d.line([tela(v, -MEIA), tela(v, MEIA)], fill=(255, 255, 255, 50), width=1)
        d.line([tela(-MEIA, v), tela(MEIA, v)], fill=(255, 255, 255, 50), width=1)
    d.text((MAR, 30), "N  ↑   Ilha Inicial — 512 × 512 m — blocos de terreno de %d m (%d×%d)" % (bloco, n, n),
        fill="white", font=fonte)
    img.save(saida)
    print(saida)


if __name__ == "__main__":
    main()
