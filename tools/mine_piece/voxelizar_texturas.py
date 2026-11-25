#!/usr/bin/env python3
"""Voxeliza as TEXTURAS dos personagens do Mine Piece (regra do dono: toda arte de mod entra em estilo voxel; ver docs/MODS_VOXELIZACAO.md).

O problema: parte das skins vem em 256/512 px (pintura suave, 4–8× o layout 64×64 do Minecraft) e destoa dos blocos do jogo. Aqui cada
textura `mp_*.png` maior que o alvo é reduzida para a grade de pixels grossos do Minecraft:
  • skins e armaduras quadradas (128/256/512 px) → 64 px (a mesma proporção do layout: o UV do modelo é normalizado e continua valendo);
  • retangulares (256×128) → 64×32;
  • sprites de item/partícula (321, 348 px, `*_cutlass`, `*_particle`) → 32 px;
  • tudo que já é ≤ alvo fica como está.
Redução por BOX (média) + paleta limitada (`--cores`, padrão 40) para o desenho ficar em manchas de cor chapadas, não em degradê; alfa em corte seco
(≥ 50 % opaco vira opaco; o resto some) — pixel-art não tem meio-transparente.
Os originais vão para `build/mine_piece/texturas_originais/` (ignorado pelo git) na PRIMEIRA execução, e toda execução parte deles: idempotente
e reversível (`--restaurar`). Depois de rodar, reimportar no Godot (`godot --headless --path . --import`).
    python3 -I tools/mine_piece/voxelizar_texturas.py [--cores 40] [--so mp_buggy_corpo ...] [--restaurar] [--seco]
"""
import argparse, shutil, sys
from pathlib import Path
from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]
PASTA = RAIZ / "mapas" / "modelos"
BACKUP = RAIZ / "build" / "mine_piece" / "texturas_originais"
SPRITES = ("_cutlass", "_particle")


def alvo(nome: str, w: int, h: int):
    """(largura, altura) final, ou None se já está no padrão voxel."""
    if nome.endswith(SPRITES) or w in (321, 348) or h in (321, 348):
        lado = 32
        return (lado, lado) if max(w, h) > lado else None
    if max(w, h) <= 64:
        return None
    escala = 64 / max(w, h)
    return (max(1, round(w * escala)), max(1, round(h * escala)))


def reduzir(img: Image.Image, tam, cores: int) -> Image.Image:
    img = img.convert("RGBA")
    pequeno = img.resize(tam, Image.BOX)
    alfa = pequeno.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    rgb = pequeno.convert("RGB")
    if cores > 0:
        rgb = rgb.quantize(colors=cores, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    saida = rgb.convert("RGBA")
    saida.putalpha(alfa)
    return saida


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cores", type=int, default=40)
    ap.add_argument("--so", nargs="*", default=[], help="nomes (sem .png) a processar")
    ap.add_argument("--restaurar", action="store_true")
    a = ap.parse_args()
    BACKUP.mkdir(parents=True, exist_ok=True)
    if a.restaurar:
        for f in BACKUP.glob("*.png"):
            shutil.copy2(f, PASTA / f.name)
        print("restauradas %d texturas" % len(list(BACKUP.glob("*.png"))))
        return 0
    feitas = puladas = 0
    for f in sorted(PASTA.glob("mp_*.png")):
        if a.so and f.stem not in a.so:
            continue
        original = BACKUP / f.name
        fonte = original if original.exists() else f
        try:
            img = Image.open(fonte)
            img.load()
        except Exception as e:
            print("pulou %s: %s" % (f.name, e), file=sys.stderr)
            continue
        tam = alvo(f.stem, *img.size)
        if tam is None:
            puladas += 1
            continue
        if not original.exists():
            shutil.copy2(f, original)
        reduzir(img, tam, a.cores).save(f, optimize=True)
        feitas += 1
    print("voxelizadas: %d | já no padrão: %d" % (feitas, puladas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
