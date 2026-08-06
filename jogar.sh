#!/usr/bin/env bash
set -e
# Câmera / mouse capturado: no Godot 4.6 o driver WAYLAND NATIVO implementa o
# protocolo zwp_relative_pointer (feito p/ mouse capturado/FPS) e o movimento
# relativo funciona mesmo segurando WASD. Forçar X11 numa sessão Wayland cai no
# XWayland, cujo pointer warping emulado TRAVA o relative ao andar (era o bug).
# Numa sessão X11 pura o driver "wayland" indisponível faz o Godot cair em x11.
exec "/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64" \
	--display-driver wayland \
	--path "/home/gabriel-bitti/dev/skills-one-piece"
