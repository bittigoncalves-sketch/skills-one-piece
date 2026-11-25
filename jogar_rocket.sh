#!/usr/bin/env bash
set -e
ROCKET_PROJECT="$(cd "$(dirname "$0")" && pwd)"
ROCKET_GODOT="$("$ROCKET_PROJECT/find_godot.sh")"
GODOT="$ROCKET_GODOT" "$ROCKET_PROJECT/checar_cache.sh"
exec "$ROCKET_GODOT" --path "$ROCKET_PROJECT" --script tools/rocket_preview.gd "$@"
