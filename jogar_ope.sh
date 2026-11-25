#!/usr/bin/env bash
set -e
OPE_PROJECT="$(cd "$(dirname "$0")" && pwd)"
OPE_GODOT="$("$OPE_PROJECT/find_godot.sh" || true)"
if [ -z "$OPE_GODOT" ]; then
    echo "Godot não encontrado; configure GODOT=/caminho/do/godot." >&2
    exit 1
fi
GODOT="$OPE_GODOT" "$OPE_PROJECT/checar_cache.sh"
exec "$OPE_GODOT" --path "$OPE_PROJECT" --script tools/ope_preview.gd "$@"
