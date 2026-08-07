#!/usr/bin/env bash
# Abre o Editor de Animação. Feito para ser chamado pelo lançador da área de
# trabalho, então não pode contar com nada do ambiente do terminal:
#   * um .desktop roda com PATH enxuto — o python3 do miniconda pode não estar lá
#   * sem terminal, um erro seria invisível: tudo vai pro log e pra uma janela
#   * clone novo não tem rigs/clips exportados — gera na hora, avisando que demora
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$AQUI/../.." && pwd)"
LOG="$AQUI/abrir.log"
: > "$LOG"

avisar() {   # título, mensagem
    echo "[$1] $2" >> "$LOG"
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="$1" --width=460 --text="$2" 2>/dev/null
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "$1" "$2"
    fi
}

# ---------------------------------------------------------------- Python
# Precisa de tkinter, que nem toda instalação traz. Testa antes de escolher.
PY=""
for c in "$HOME/miniconda3/bin/python3" python3 python3.13 python3.12 /usr/bin/python3; do
    p="$(command -v "$c" 2>/dev/null || echo "$c")"
    [ -x "$p" ] || continue
    if "$p" -c "import tkinter" >/dev/null 2>&1; then
        PY="$p"
        break
    fi
done
if [ -z "$PY" ]; then
    avisar "Editor de Animação" "Nenhum Python com tkinter encontrado.\n\nInstale com:\n  sudo apt install python3-tk"
    exit 1
fi
echo "python: $PY" >> "$LOG"

# ------------------------------------------------- dados do rig e dos clipes
# São gerados pelo Godot (o Python não lê .scn/.fbx/.res, que são binários).
if [ ! -f "$AQUI/rigs/index.json" ] || [ ! -f "$AQUI/clips/index.json" ]; then
    GODOT="$("$PROJ/find_godot.sh" 2>/dev/null || true)"
    if [ -z "$GODOT" ]; then
        avisar "Editor de Animação" \
            "Faltam os dados do rig e o Godot não foi encontrado.\n\nRode uma vez no terminal:\n  cd $PROJ\n  ./tools/anim_editor/abrir.sh"
        exit 1
    fi
    # A exportação NUNCA pode rodar dentro de um pipe para o zenity: se a janela
    # fecha, o pipe quebra e o subshell morre por SIGPIPE no meio do caminho —
    # foi assim que os rigs saíram e os clipes não. O aviso é só aviso.
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Editor de Animação" \
            "Primeira execução — preparando os dados. Isso leva alguns minutos." 2>/dev/null
    fi
    "$GODOT" --headless --path "$PROJ" -s tools/export_rig.gd >> "$LOG" 2>&1
    "$GODOT" --headless --path "$PROJ" -s tools/export_anims.gd >> "$LOG" 2>&1

    faltou=""
    [ -f "$AQUI/rigs/index.json" ]  || faltou="rigs"
    [ -f "$AQUI/clips/index.json" ] || faltou="${faltou:+$faltou e }clipes"
    if [ -n "$faltou" ]; then
        avisar "Editor de Animação" "A exportação de $faltou falhou.\n\nDetalhes em:\n$LOG"
        exit 1
    fi
fi

# ------------------------------------------------------------------ abrir
cd "$AQUI"
"$PY" main.py >> "$LOG" 2>&1
codigo=$?
if [ $codigo -ne 0 ]; then
    avisar "Editor de Animação" "O editor fechou com erro (código $codigo).\n\nÚltimas linhas:\n$(tail -n 12 "$LOG")"
fi
exit $codigo
