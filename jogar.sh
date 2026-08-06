#!/usr/bin/env bash
set -e
# Câmera / mouse capturado: no Godot 4.6 o driver WAYLAND NATIVO implementa o
# protocolo zwp_relative_pointer (feito p/ mouse capturado/FPS) e o movimento
# relativo funciona mesmo segurando WASD. Forçar X11 numa sessão Wayland cai no
# XWayland, cujo pointer warping emulado TRAVA o relative ao andar (era o bug).
# Numa sessão X11 pura o driver "wayland" indisponível faz o Godot cair em x11.

PROJ="$(cd "$(dirname "$0")" && pwd)"
GODOT="$("$PROJ/find_godot.sh" || true)"

if [ -z "$GODOT" ]; then
    echo "Godot 4.6 não encontrado. Baixe em https://godotengine.org e rode:" >&2
    echo "  GODOT=/caminho/do/godot ./jogar.sh" >&2
    exit 1
fi

# CLONE NOVO: sem o cache de class_name o Main.gd não compila e o jogo abre em
# TELA CINZA permanente. Preparar sozinho evita o tropeço.
if [ ! -f "$PROJ/.godot/global_script_class_cache.cfg" ]; then
    echo "Primeira execução — preparando o projeto (demora alguns minutos)..."
    GODOT="$GODOT" "$PROJ/setup.sh"
fi

exec "$GODOT" --display-driver wayland --path "$PROJ"
