#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
GODOT_BIN="${GODOT:-/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64}"
exec "$GODOT_BIN" --path . --script tools/yoru_arena.gd "$@"
