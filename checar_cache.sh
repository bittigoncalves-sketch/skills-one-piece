#!/usr/bin/env bash
# Garante que o cache de `class_name` do Godot está COMPLETO antes de jogar.
#
# POR QUE ISTO EXISTE
# -------------------
# O `.godot/global_script_class_cache.cfg` registra todo `class_name` do projeto.
# Um script que cite um `class_name` ausente dali NÃO COMPILA — e, como o
# `Player.gd` é citado pela cena do mundo, o efeito em jogo é brutal e enganoso:
# o clique em JOGAR funciona, a cena troca, e aí ninguém spawna. Tela cinza.
# O sintoma que chega ao jogador é "o botão de jogar parou de funcionar".
#
# O `setup.sh` já cobria o caso do CLONE NOVO (cache ausente). O que faltava era
# o cache DEFASADO: ele existe, mas foi gerado antes de alguém criar uma classe
# nova. Aí a checagem `[ ! -f cache ]` passa batido e o jogo abre quebrado.
#
# Aconteceu de verdade em 2026-08-11, na Fase 2 da partição do Player: o
# `class_name CameraRig` nasceu, o cache não foi regenerado, e o jogo virou tela
# cinza. As fases seguintes criam mais classes — então a checagem passou a ser
# por CONTEÚDO, não por existência do arquivo.
#
# Custo: um `grep` no projeto. Quando falta algo, só o `--editor --quit`
# (segundos); o `setup.sh` completo fica reservado ao clone novo, que também
# precisa importar ~275 MB de assets.
set -e

PROJ="$(cd "$(dirname "$0")" && pwd)"
CACHE="$PROJ/.godot/global_script_class_cache.cfg"
GODOT="${GODOT:-$("$PROJ/find_godot.sh" 2>/dev/null || true)}"

# Clone novo: nem cache nem assets importados. Só o setup completo resolve.
if [ ! -f "$CACHE" ]; then
    echo "Primeira execução — preparando o projeto (demora alguns minutos)..."
    GODOT="$GODOT" "$PROJ/setup.sh"
    exit $?
fi

# `class_name` declarados no fonte (só no início da linha — evita comentário e
# texto solto). Comparados um a um com o que o cache registra.
faltando=""
while read -r classe; do
    [ -z "$classe" ] && continue
    grep -q "\"$classe\"" "$CACHE" || faltando="$faltando $classe"
done < <(grep -rhoE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
            --include='*.gd' "$PROJ" | awk '{print $2}' | sort -u)

if [ -n "$faltando" ]; then
    echo "Classes novas desde o último preparo:$faltando"
    echo "Regenerando o cache de class_name (senão o jogo abre em tela cinza)..."
    "$GODOT" --headless --path "$PROJ" --editor --quit >/dev/null 2>&1 || true
    # Confere: se ainda faltar, avisar é melhor do que abrir quebrado.
    for classe in $faltando; do
        if ! grep -q "\"$classe\"" "$CACHE"; then
            echo "AVISO: '$classe' não entrou no cache. Rode ./setup.sh" >&2
            exit 1
        fi
    done
    echo "Cache atualizado."
fi
