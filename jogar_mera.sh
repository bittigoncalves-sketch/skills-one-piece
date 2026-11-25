#!/usr/bin/env bash
# Abre a arena com a Mera Mera no Mi equipada e o boneco de treino.
#   ./jogar_mera.sh              -> jogável
#   ./jogar_mera.sh -- --capture -> salva as fases em PNG e sai
# Espelha o jogar_ope.sh. PRECISA DE TELA nos dois modos.
set -e
MERA_PROJECT="$(cd "$(dirname "$0")" && pwd)"
MERA_GODOT="$("$MERA_PROJECT/find_godot.sh" || true)"
if [ -z "$MERA_GODOT" ]; then
    echo "Godot não encontrado; configure GODOT=/caminho/do/godot." >&2
    exit 1
fi
GODOT="$MERA_GODOT" "$MERA_PROJECT/checar_cache.sh"
exec "$MERA_GODOT" --path "$MERA_PROJECT" --script tools/mera_preview.gd "$@"
