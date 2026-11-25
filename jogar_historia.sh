#!/usr/bin/env bash
# Abre o jogo DIRETO no Modo História, pulando o menu. Ver docs/MODO_HISTORIA.md.
# Mesmo preparo do jogar.sh (cache de class_name e driver Wayland — o motivo do
# driver está explicado lá).
set -e
PROJ="$(cd "$(dirname "$0")" && pwd)"
GODOT="$("$PROJ/find_godot.sh" || true)"
[ -n "$GODOT" ] || { echo "Godot 4.6 não encontrado. Use: GODOT=/caminho ./jogar_historia.sh" >&2; exit 1; }
GODOT="$GODOT" "$PROJ/checar_cache.sh"
exec "$GODOT" --display-driver wayland --path "$PROJ" -- --historia "$@"
