#!/usr/bin/env bash
# ============================================================================
#  IMPORTAR UMA ANIMAÇÃO DO MIXAMO — FBX -> glTF -> .res, com validação.
#
#  Uso:
#     ./tools/importar_animacao.sh ~/Downloads/"Hurricane Kick.fbx"
#     ./tools/importar_animacao.sh ~/Downloads/"Hurricane Kick.fbx" hurricane_kick
#
#  O segundo argumento é o nome que o clipe terá no jogo. Sem ele, o nome sai do
#  arquivo em snake_case.
#
#  POR QUE ESTE SCRIPT EXISTE: o `hurricane_kick` passou meses quebrado com todos
#  os indicadores verdes. O arquivo tinha duração, faixas e chaves — só não tinha
#  MOVIMENTO nos membros, porque veio assim do próprio Mixamo. Contar faixas ou
#  chaves não detecta isso; só medir amplitude por osso detecta.
#
#  Então aqui a validação vem junto e é OBRIGATÓRIA: se o clipe entrar congelado,
#  o script FALHA e diz para baixar de novo, em vez de instalar em silêncio um
#  arquivo que só se revela quebrado meses depois, em jogo.
#
#  Ver docs/erros.md (entrada de 2026-08-10) e docs/ANIMACOES_MIXAMO.md.
# ============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

GODOT="${GODOT:-/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64}"
BLENDER="${BLENDER:-/home/gabriel-bitti/opt/blender/blender}"

if [ $# -lt 1 ]; then
	echo "uso: $0 <arquivo.fbx> [nome_no_jogo]" >&2
	exit 2
fi

FBX="$1"
if [ ! -f "$FBX" ]; then
	echo "❌ não achei o arquivo: $FBX" >&2
	exit 2
fi

# Nome no jogo: 2º argumento, ou o nome do arquivo em snake_case.
if [ $# -ge 2 ]; then
	NOME="$2"
else
	NOME="$(basename "$FBX" .fbx | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9_')"
fi

for exe in "$GODOT" "$BLENDER"; do
	[ -x "$exe" ] || { echo "❌ não é executável: $exe (defina GODOT= / BLENDER=)" >&2; exit 2; }
done

echo "══ importando '$NOME' de $(basename "$FBX") ══"

# ---------------------------------------------------------------- 1. backup
# O bake sobrescreve. Se já existe um clipe com esse nome, guarda antes.
CARIMBO="$(date +%Y%m%d-%H%M%S)"
BACKUP="$RAIZ/../_backups/skills-one-piece/anim-$NOME-$CARIMBO"
if [ -f "assets/animations/$NOME.res" ]; then
	mkdir -p "$BACKUP"
	cp "assets/animations/$NOME.res" "$BACKUP/"
	[ -f "assets/animations_glb/$NOME.glb" ] && cp "assets/animations_glb/$NOME.glb" "$BACKUP/"
	echo "  backup do clipe anterior -> $BACKUP"
fi

# ------------------------------------------------------------ 2. FBX -> glTF
# O importador FBX do Godot lê 1 chave por osso de membro; o do Blender lê
# todas. Por isso a conversão passa pelo Blender e o Godot só vê glTF.
echo "── 1/3  convertendo pelo Blender…"
mkdir -p assets/animations_glb
"$BLENDER" --background --python tools/fbx_to_glb.py -- \
	"$FBX" "assets/animations_glb/$NOME.glb" 2>&1 |
	grep -viE "^Blender|^Read prefs|Color management|^$" | tail -5

[ -f "assets/animations_glb/$NOME.glb" ] || { echo "❌ a conversão não gerou o .glb" >&2; exit 1; }

# ---- checagem NA FONTE, antes de assar ----
# É aqui que dá para pegar o arquivo que veio quebrado do Mixamo, sem gastar o
# bake: se todo osso de membro tiver 2 amostras ou menos, não há animação.
echo "── 2/3  conferindo o .glb na origem…"
python3 - "assets/animations_glb/$NOME.glb" <<'PY'
import json, struct, sys, os
MEMBROS = {"LeftArm","LeftForeArm","RightArm","RightForeArm",
           "LeftUpLeg","LeftLeg","RightUpLeg","RightLeg"}
p = sys.argv[1]
d = open(p, 'rb').read()
j = json.loads(d[20:20+struct.unpack('<I', d[12:16])[0]].decode('utf-8'))
if not j.get("animations"):
    print("  ❌ o .glb não tem nenhum clipe de animação"); sys.exit(1)
a = j["animations"][0]
nomes = {i: n.get("name", "") for i, n in enumerate(j["nodes"])}
am = [j["accessors"][a["samplers"][c["sampler"]]["output"]]["count"]
      for c in a["channels"]
      if c["target"]["path"] == "rotation"
      and nomes.get(c["target"]["node"], "").replace("mixamorig:", "")
               .replace("mixamorig_", "") in MEMBROS]
if not am:
    print("  ❌ nenhuma faixa de rotação de membro no arquivo"); sys.exit(1)
if max(am) <= 2:
    print("  ❌ ARQUIVO VEIO QUEBRADO DO MIXAMO: %d amostras por osso de membro." % max(am))
    print("     Um clipe sadio tem dezenas (o `kicking` tem 69). Não há conserto")
    print("     local — baixe de novo em mixamo.com e rode este script outra vez.")
    sys.exit(1)
print("  ✓ origem sadia: %d..%d amostras de rotação por osso de membro" % (min(am), max(am)))
PY

# ------------------------------------------------------------------ 3. bake
echo "── 3/3  assando para o rig de 13 papéis…"
"$GODOT" --headless --path . --script tools/bake_mixamo.gd -- "$NOME" 2>&1 |
	grep -viE "^Godot Engine|Display Server" | tail -8

[ -f "assets/animations/$NOME.res" ] || { echo "❌ o bake não gerou o .res" >&2; exit 1; }

# ------------------------------------------------------------- 4. validação
echo "── validando o clipe assado…"
SAIDA="$("$GODOT" --headless --path . --script tools/dev_tests/medir_amplitude_res.gd -- "$NOME" 2>&1 |
	grep -i "$NOME" || true)"
echo "  $SAIDA"

if echo "$SAIDA" | grep -q "CONGELADO"; then
	echo
	echo "❌ FALHOU: o clipe assou CONGELADO — os membros não se mexem."
	echo "   Amplitude zero em braços e pernas. O arquivo de origem não presta."
	exit 1
fi

echo
echo "✅ '$NOME' pronto e com movimento de verdade nos membros."
echo "   Confira o percurso entre chaves (estalo de gimbal) com:"
echo "     $GODOT --headless --path . --script tools/dev_tests/medir_salto_res.gd"
