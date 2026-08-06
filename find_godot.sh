#!/usr/bin/env bash
# Descobre o binário do Godot 4.6 nesta máquina e imprime o caminho.
# Ordem: variável GODOT -> PATH -> lugares comuns de download manual.
# Usado por jogar.sh, servidor.sh e setup.sh para o projeto rodar em qualquer
# computador, sem caminho absoluto chumbado no script.

if [ -n "$GODOT" ] && [ -x "$GODOT" ]; then
    echo "$GODOT"
    exit 0
fi

for c in godot godot4 Godot; do
    p="$(command -v "$c" 2>/dev/null || true)"
    if [ -n "$p" ]; then
        echo "$p"
        exit 0
    fi
done

for p in \
    "$HOME"/Downloads/Godot_v4.6*_linux.x86_64 \
    "$HOME"/Downloads/Godot_v4*_linux.x86_64 \
    "$HOME"/opt/godot*/godot* \
    /opt/godot*/godot* \
    /usr/local/bin/godot*
do
    if [ -x "$p" ]; then
        echo "$p"
        exit 0
    fi
done

exit 1
