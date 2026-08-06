#!/usr/bin/env bash
set -e
# SERVIDOR DEDICADO (Fase 10): roda o jogo headless como servidor puro (sem player
# local). Clientes conectam pelo IP desta máquina (porta 24565). Para nuvem, é só
# rodar isto numa VPS e apontar o cliente pro IP — a lógica do jogo é a mesma.
# O "-- --server" passa o argumento de usuário que o GameFlow lê p/ subir dedicado.
GODOT="/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64"
PROJ="$(cd "$(dirname "$0")" && pwd)"
exec "$GODOT" --headless --path "$PROJ" -- --server
