#!/bin/bash
# Roda os 5 bots da régua do Boss numa rodada, em série (uma sala ENet por vez).
# Uso: art_src/validation/boss_ia/rodar_regua.sh <rodada> [semente=1] [porta=25000] [hitstop=1] [bots...]
#   ex.: art_src/validation/boss_ia/rodar_regua.sh A 1 25000 1
#        art_src/validation/boss_ia/rodar_regua.sh C 1 25000 0            (determinístico)
#        art_src/validation/boss_ia/rodar_regua.sh E 1 25000 1 strafe     (um bot só)
# Teto de duração: MAX=240 art_src/validation/boss_ia/rodar_regua.sh ... (padrão 120 s)
# Saída: art_src/validation/boss_ia/rodada_<rodada>/{resumo,decisao,stdout}_<bot>.*
set -u
cd /home/gabriel-bitti/dev/skills-one-piece
GODOT=/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64
R=${1:?rodada}; SEM=${2:-1}
export SOP_PORTA=${3:-${SOP_PORTA:-25000}}
HS=${4:-1}
shift $(( $# < 4 ? $# : 4 ))
BOTS=${*:-parado strafe recuo kite circulo}   # zigzag: passe explicitamente
OUT=art_src/validation/boss_ia/rodada_$R
mkdir -p "$OUT"
for b in $BOTS; do
  timeout 400 "$GODOT" --headless --path . --script tools/dev_tests/medir_boss_ia.gd \
    -- --bot=$b --semente=$SEM --rodada=$R --hitstop=$HS --max=${MAX:-120} > "$OUT/stdout_$b.log" 2>&1
  echo "$b saida=$?"
done
