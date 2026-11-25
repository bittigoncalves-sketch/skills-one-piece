#!/usr/bin/env bash
set -euo pipefail
PHOENIX_PROJECT="$(cd "$(dirname "$0")" && pwd)"
PHOENIX_GODOT="$("$PHOENIX_PROJECT/find_godot.sh" || true)"
if [ -z "$PHOENIX_GODOT" ]; then
    echo "Godot não encontrado; configure GODOT=/caminho/do/godot."
    exit 1
fi
GODOT="$PHOENIX_GODOT" "$PHOENIX_PROJECT/checar_cache.sh"
exec "$PHOENIX_GODOT" --path "$PHOENIX_PROJECT" --script tools/phoenix_preview.gd "$@"
