#!/usr/bin/env bash
# Abre o Modo História na ÚLTIMA ilha do cadastro, com dash, pulo no ar e a Pika Pika
# equipada; nasce e renasce lá. Save de TESTE próprio (o save real fica intocado).
#   ./jogar_teste_ilha.sh [--ilha=<id>] [--nivel=<n>]
# Ver src/historia/teste_de_ilha.gd e docs/ESTRUTURAS_MINE_PIECE_PLANO.md.
set -e
PROJ="$(cd "$(dirname "$0")" && pwd)"
GODOT="$("$PROJ/find_godot.sh" || true)"
[ -n "$GODOT" ] || { echo "Godot 4.6 não encontrado. Use: GODOT=/caminho ./jogar_teste_ilha.sh" >&2; exit 1; }
GODOT="$GODOT" "$PROJ/checar_cache.sh"
exec "$GODOT" --display-driver wayland --path "$PROJ" -- --teste-ilha "$@"
