#!/usr/bin/env bash
set -euo pipefail
BARA_PROJECT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BARA_GODOT="${GODOT:-$("$BARA_PROJECT/find_godot.sh")}"
GODOT="$BARA_GODOT" "$BARA_PROJECT/checar_cache.sh"
# O ambiente SOP_TEST_CHARACTER_VISUAL continua opcional; não grava aparência.
# Use -- --capture para a sequência de revisão na arena real.
exec "$BARA_GODOT" --path "$BARA_PROJECT" --script tools/bara_preview.gd "$@"
