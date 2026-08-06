#!/usr/bin/env bash
# Preparo obrigatório em CLONE NOVO (roda sozinho pelo jogar.sh/servidor.sh).
#
# POR QUE ISTO EXISTE: a pasta .godot/ não vai pro repositório (150 MB de cache
# regenerável). Dentro dela mora o `global_script_class_cache.cfg`, que registra
# todos os `class_name` do projeto. Sem ele, scripts que citam MapBuilder, Hud,
# TreeScatter etc. NÃO COMPILAM — o Main.gd inteiro falha ao carregar, a cena
# fica sem script, ninguém spawna, não há câmera, e o jogo mostra uma TELA CINZA
# permanente ao entrar no singleplayer. Também é aqui que os .fbx/.glb/.png são
# importados pela primeira vez.
set -e

PROJ="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-$("$PROJ/find_godot.sh" 2>/dev/null || true)}"

if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
    echo "Godot não encontrado. Defina a variável GODOT:" >&2
    echo "  GODOT=/caminho/do/godot ./setup.sh" >&2
    exit 1
fi

echo "==> Importando assets (a primeira vez demora — são ~275 MB)"
"$GODOT" --headless --path "$PROJ" --import

echo "==> Registrando os class_name (gera o cache global)"
"$GODOT" --headless --path "$PROJ" --editor --quit

if [ -f "$PROJ/.godot/global_script_class_cache.cfg" ]; then
    echo "==> Pronto. Rode ./jogar.sh"
else
    echo "AVISO: o cache de class_name não foi gerado — o jogo vai dar tela cinza." >&2
    exit 1
fi
