#!/usr/bin/env bash
set -e
GORO_PROJECT="$(cd "$(dirname "$0")" && pwd)"
GORO_GODOT="$("$GORO_PROJECT/find_godot.sh" || true)"
if [ -z "$GORO_GODOT" ]; then
    echo "Godot não encontrado; configure GODOT=/caminho/do/godot." >&2
    exit 1
fi
GODOT="$GORO_GODOT" "$GORO_PROJECT/checar_cache.sh"
exec "$GORO_GODOT" --path "$GORO_PROJECT" --script tools/goro_preview.gd "$@"
