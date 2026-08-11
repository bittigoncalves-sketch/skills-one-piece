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

# Sem o cache de class_name COMPLETO o Player.gd não compila e o jogo abre em
# TELA CINZA — o clique em JOGAR parece não funcionar. Vale para o clone novo
# (cache ausente) e para o cache defasado, quando uma classe nova foi criada
# desde o último preparo. Ver checar_cache.sh.
GODOT="$GODOT" "$PROJ/checar_cache.sh"

exec "$GODOT" --display-driver wayland --path "$PROJ"
