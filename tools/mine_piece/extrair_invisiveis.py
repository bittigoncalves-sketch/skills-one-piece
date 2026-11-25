#!/usr/bin/env python3
"""Entidades do Mine Piece que o jogo original NUNCA desenha (31/10/2026).

O renderer do mod diz `isBodyVisible(entity) { return false; }` (e a textura é `clear.png`): a entidade existe só
para a IA dela — soltar partículas, som, dano em área — e some. Hoje são `entity_impact`, `entity_armament_haki` e
`entity_haoshoku_haki`. Para a fidelidade isso NÃO é falta de modelo: desenhar algo seria INVENTAR. A camada
(`McVisual.e_invisivel`) usa esta lista para não contar `visual:entidade:<id>` como pendência.

Lê `client/renderer/*Renderer.java` do mod e acrescenta `invisiveis` em `mapas/east_blue/visual_do_mod.json`.

    python3 -I tools/mine_piece/extrair_invisiveis.py
"""
import glob
import json
import os
import re

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece")
RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VISUAL = os.path.join(RAIZ, "mapas", "east_blue", "visual_do_mod.json")


def snake(nome: str) -> str:
    """`EntityImpact` → `entity_impact`, `EntityHaoshokuHaki` → `entity_haoshoku_haki`."""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", nome).lower()


def main() -> None:
    achadas = []
    for f in sorted(glob.glob(os.path.join(MOD, "client", "renderer", "*Renderer.java"))):
        src = open(f, encoding="utf-8").read()
        if re.search(r"isBodyVisible[^{]*\{\s*return false", src) and "GeoEntityRenderer" not in src:
            achadas.append(snake(os.path.basename(f)[: -len("Renderer.java")]))
    visual = json.load(open(VISUAL))
    visual["invisiveis"] = achadas
    json.dump(visual, open(VISUAL, "w"), ensure_ascii=False, indent=1)
    print(f"{len(achadas)} entidades invisíveis no mod: {', '.join(achadas)}")


if __name__ == "__main__":
    main()
