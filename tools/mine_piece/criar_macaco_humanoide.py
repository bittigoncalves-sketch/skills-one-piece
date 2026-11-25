#!/usr/bin/env python3
"""Cria os modelos dos MACACOS HUMANOIDES (18/11/2026) a partir do biped `mp_bandit.glb` (local, do mod): copia o .glb e muda só o JSON do `asset.extras`
para o SHA ser outro (a loja do editor deduplica por SHA e daria o mesmo id). A pele de macaco entra em jogo por `UniformesFaccoes` (não mexe no .glb).
    python3 -I tools/mine_piece/gerar_skin_macaco.py
    python3 -I tools/mine_piece/criar_macaco_humanoide.py
    godot --headless --path . --script tools/mine_piece/registrar_na_loja.gd      # põe os dois na loja (comportamento mine_piece)
Os .glb ficam em build/mine_piece (fora do git, arte provisória do mod); este script e a skin é que vão ao git.
"""
import json, struct, sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = RAIZ / "build" / "mine_piece" / "mp_bandit.glb"
MODELOS = ["mp_macaco_humanoide", "mp_macaco_rei"]


def reescrever(dados: bytes, marca: str) -> bytes:
    magic, versao, _ = struct.unpack("<4sII", dados[:12])
    tam_json, tipo = struct.unpack("<II", dados[12:20])
    assert tipo == 0x4E4F534A, "primeiro chunk não é JSON"
    corpo = json.loads(dados[20:20 + tam_json].decode("utf-8"))
    corpo.setdefault("asset", {}).setdefault("extras", {})["variante"] = marca
    novo = json.dumps(corpo, separators=(",", ":")).encode("utf-8")
    novo += b" " * ((4 - len(novo) % 4) % 4)
    resto = dados[20 + tam_json:]
    total = 12 + 8 + len(novo) + len(resto)
    return struct.pack("<4sII", magic, versao, total) + struct.pack("<II", len(novo), 0x4E4F534A) + novo + resto


def main() -> int:
    if not ORIGEM.exists():
        print("falta %s (converta o mod: tools/mine_piece/geo_para_glb.py)" % ORIGEM, file=sys.stderr)
        return 1
    dados = ORIGEM.read_bytes()
    for m in MODELOS:
        (ORIGEM.parent / (m + ".glb")).write_bytes(reescrever(dados, m))
        print("criado", m)
    return 0


if __name__ == "__main__":
    sys.exit(main())
