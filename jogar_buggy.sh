#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT:-$("$PROJECT_DIR/find_godot.sh")}"
GODOT="$GODOT_BIN" "$PROJECT_DIR/checar_cache.sh"
# Opção local e temporária: nenhum arquivo de customização é salvo.
# Feche esta sessão e use jogar.sh para voltar aos modelos originais.
export SOP_TEST_CHARACTER_VISUAL="res://assets/models/bosses/buggy/buggy_boss_visual.tres"
exec "$GODOT_BIN" --path "$PROJECT_DIR" "$@"
