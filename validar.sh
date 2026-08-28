#!/usr/bin/env bash
# ============================================================================
#  VALIDAR — roda a bateria inteira e diz, numa tabela, o que está de pé.
#
#  POR QUE ISTO EXISTE
#  -------------------
#  Os testes vinham sendo rodados um a um, na mão. Isso tem três problemas:
#
#   1. TODOS hospedam na porta 24565. Dois ao mesmo tempo = o segundo não acha
#      servidor, não spawna player e TRAVA até o timeout. Aqui rodam em série.
#   2. É fácil rodar só os que a gente lembra e concluir "a suíte passou".
#      Aqui a lista é descoberta do disco: `test_*.gd`, sem curadoria.
#   3. Cada teste sinaliza falha de um jeito. A regra única está no `_falhou`.
#
#  USO
#     ./validar.sh              # tudo
#     ./validar.sh rapido       # pula os lentos (frutas, traço)
#     ./validar.sh camera rig   # só os que casarem com esses nomes
#
#  Sai com código 0 só se TUDO passou.
# ============================================================================
set -uo pipefail

PROJ="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJ"
GODOT="${GODOT:-$("$PROJ/find_godot.sh" 2>/dev/null || true)}"
[ -x "$GODOT" ] || { echo "Godot não encontrado. Use: GODOT=/caminho ./validar.sh" >&2; exit 1; }

TIMEOUT="${TIMEOUT:-120}"

# Timeout POR TESTE. Um número só não serve: o `test_frutas` conjura os 4 golpes
# das 9 frutas e mede dano e vazamento em cada um — medido, leva ~330 s. Com o
# teto padrão ele "falhava" por tempo enquanto passava em tudo, que é o pior
# tipo de falso positivo: some a confiança na bateria inteira.
tempo_de() {
	case "$1" in
		test_frutas)    echo 480 ;;
		test_gomu_leak) echo 240 ;;   # medido: ~131 s
		*)              echo "$TIMEOUT" ;;
	esac
}
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# O cache de class_name defasado derruba o Player inteiro e faz TODO teste
# falhar por um motivo que não é o do teste. Ver docs/erros.md.
GODOT="$GODOT" "$PROJ/checar_cache.sh" || exit 1

# --------------------------------------------------------------- utilidades
verde()  { printf '\033[32m%s\033[0m' "$1"; }
vermelho() { printf '\033[31m%s\033[0m' "$1"; }
amarelo() { printf '\033[33m%s\033[0m' "$1"; }

# Regra ÚNICA de falha, porque cada teste sinaliza do seu jeito:
#   • código de saída != 0
#   • marcador de falha impresso (✗, ❌, "XX  ")
#   • o test_compila imprime um contador em vez de marcador
_falhou() {
	local cod="$1" log="$2"
	[ "$cod" -ne 0 ] && return 0
	grep -qE '✗|❌|^  XX  ' "$log" && return 0
	grep -qE 'scripts que nao compilam: [1-9]' "$log" && return 0
	# ⚠️ CENÁRIO QUE NÃO MONTA NÃO É TESTE QUE PASSOU (2026-08-25). O `BaseTest`
	# aborta com esta frase quando falta um pré-requisito da cena, e o aborto é
	# UMA linha no fim de centenas de `MoveFrame: ...`. Entre 2026-08-23 e
	# 2026-08-25 os três testes de `src/tests/` abortaram assim, todo dia, e
	# ninguém viu — ver `docs/erros.md`.
	grep -qE 'cenário não montou|cenario nao montou' "$log" && return 0
	_parse_error_real "$log" && return 0
	return 1
}

# Autoloads NÃO viram identificador num `godot --script`, então o erro
# "Identifier \"GameFlow\" not declared" é esperado e não significa nada.
AUTOLOADS_TOLERADOS='GameFlow|ServerManager|ClientManager|FruitNet|ScreenFX|AudioManager|SoundLibrary'

# QUALQUER outro `Parse Error` é defeito de verdade.
#
# ⚠️ ISTO EXISTE PORQUE O `test_compila` TEM UM PONTO CEGO: a tolerância dele é
# por TEXTO DO ARQUIVO (`if texto.find("ScreenFX") >= 0`), então qualquer script
# que apenas MENCIONE um autoload fica imune a erro de compilação.
#
# Custou caro em 2026-08-12: o `GoroFX.gd` ficou totalmente quebrado
# (`class_name GoroFXGrande` fora do cache) e o `test_compila` respondeu
# "0 falhas", porque o arquivo cita "ScreenFX". Só o `test_frutas` pegou.
#
# Aqui a tolerância é pela MENSAGEM do erro, não pelo conteúdo do arquivo.
_parse_error_real() {
	grep -E 'Parse Error|Compile Error' "$1" 2>/dev/null \
		| grep -vE "Identifier \"($AUTOLOADS_TOLERADOS)\" not declared" \
		| grep -vE "Identifier not found: ($AUTOLOADS_TOLERADOS)\$" \
		| grep -vE 'Compile Error: Failed to compile depended scripts' \
		| grep -q .
}

PASSOU=0; FALHOU=0; PULADO=0
declare -a FALHAS=()

# roda <nome> <comando...>
roda() {
	local nome="$1"; shift
	local log="$TMP/$nome.log"
	local limite; limite="$(tempo_de "$nome")"
	local t0=$SECONDS
	printf '  %-24s ' "$nome"
	timeout "$limite" "$@" >"$log" 2>&1
	local cod=$?
	local dt=$((SECONDS - t0))
	if [ $cod -eq 124 ]; then
		echo "$(vermelho TIMEOUT) (${limite}s)"
		FALHOU=$((FALHOU+1)); FALHAS+=("$nome (timeout — log em $TMP)")
		cp "$log" "/tmp/validar_$nome.log" 2>/dev/null
	elif _falhou "$cod" "$log"; then
		local n; n=$(grep -cE '✗|❌|^  XX  ' "$log")
		echo "$(vermelho FALHOU) ${n} problema(s), ${dt}s"
		FALHOU=$((FALHOU+1)); FALHAS+=("$nome")
		cp "$log" "/tmp/validar_$nome.log" 2>/dev/null
		grep -E '✗|❌|^  XX  ' "$log" | head -3 | sed 's/^/        /'
	else
		echo "$(verde ok) (${dt}s)"
		PASSOU=$((PASSOU+1))
	fi
}

# ------------------------------------------------------- seleção do que rodar
FILTRO=("$@")
RAPIDO=0
if [ "${1:-}" = "rapido" ]; then RAPIDO=1; FILTRO=(); fi

quer() {
	[ ${#FILTRO[@]} -eq 0 ] && return 0
	local nome="$1" f
	for f in "${FILTRO[@]}"; do [[ "$nome" == *"$f"* ]] && return 0; done
	return 1
}

echo
echo "=== BATERIA DO SKILLS ONE PIECE ==="
echo "godot: $GODOT"
echo

# ---------------------------------------------------------- 1. testes headless
echo "-- testes (headless, em série: todos disputam a porta 24565) --"
LENTOS="test_frutas"
for arq in tools/dev_tests/test_*.gd; do
	nome="$(basename "$arq" .gd)"
	quer "$nome" || continue
	# O teste de LAN NÃO é de um processo só: um lado anuncia (farol) e o outro
	# procura. Rodado sozinho ele "falha" sempre, porque não há ninguém
	# anunciando — falso positivo que escondia o resultado de verdade.
	[ "$nome" = "test_lan_discovery" ] && continue
	# A trava do corpo a corpo mede DISTÂNCIA percorrida segurando W, e o
	# `MoveFrame.ler()` ignora o teclado sem o mouse capturado. Headless ele
	# mediria zero em tudo — inclusive no controle — e "passaria" medindo o
	# vazio. Roda no bloco com tela, lá embaixo.
	[ "$nome" = "test_melee_trava" ] && continue
	# Mesma razão: mede a distância andada com a tecla do golpe SEGURADA.
	[ "$nome" = "test_segurar_ataque" ] && continue
	if [ $RAPIDO -eq 1 ] && [[ " $LENTOS " == *" $nome "* ]]; then
		printf '  %-24s %s\n' "$nome" "$(amarelo pulado)"; PULADO=$((PULADO+1)); continue
	fi
	roda "$nome" "$GODOT" --headless --path "$PROJ" --script "$arq"
done

# --------------------------------------------- 1b. testes de cena (src/tests)
# ⚠️ ESTES ESTAVAM FORA DA BATERIA ATÉ 2026-08-25, e foi por isso que a suíte
# inteira de `src/tests/` pôde abortar por dois dias sem ninguém notar: o laço
# acima varre só `tools/dev_tests/test_*.gd`.
#
# Eles montam uma arena mínima com um Player de verdade (`src/tests/BaseTest.gd`)
# e por isso disputam a mesma porta 24565 — rodam em série, como o bloco 1.
echo
echo "-- testes de cena (src/tests: arena mínima com Player de verdade) --"
for arq in src/tests/test_*.gd; do
	nome="$(basename "$arq" .gd)"
	quer "$nome" || continue
	roda "$nome" "$GODOT" --headless --path "$PROJ" --script "$arq"
done

# ------------------------------------------------ 2. LAN: dois processos
# A descoberta automática é um diálogo por UDP em difusão: um lado ANUNCIA
# (farol) e o outro PROCURA. Testar só um lado não testa nada — por isso aqui a
# bateria sobe os dois e mata o farol no fim.
if quer "lan"; then
	echo
	echo "-- descoberta na LAN (dois processos: farol + busca) --"
	printf '  %-24s ' "test_lan_discovery"
	"$GODOT" --headless --path "$PROJ" --script tools/dev_tests/test_lan_discovery.gd \
		-- farol >"$TMP/farol.log" 2>&1 &
	FAROL_PID=$!
	sleep 2                                    # deixa o farol subir e anunciar
	t0=$SECONDS
	timeout 60 "$GODOT" --headless --path "$PROJ" \
		--script tools/dev_tests/test_lan_discovery.gd -- buscar >"$TMP/lan.log" 2>&1
	cod=$?
	dt=$((SECONDS - t0))
	kill "$FAROL_PID" 2>/dev/null; wait "$FAROL_PID" 2>/dev/null
	if _falhou "$cod" "$TMP/lan.log"; then
		echo "$(vermelho FALHOU) (${dt}s)"
		grep -E '✗|❌' "$TMP/lan.log" | head -2 | sed 's/^/        /'
		cp "$TMP/lan.log" /tmp/validar_test_lan_discovery.log
		cp "$TMP/farol.log" /tmp/validar_lan_farol.log
		FALHOU=$((FALHOU+1)); FALHAS+=("test_lan_discovery")
	else
		echo "$(verde ok) (${dt}s)"
		PASSOU=$((PASSOU+1))
	fi
fi

# ------------------------------------- 3. multiplayer: dois processos
# Mesma receita do teste de LAN: o host sobe primeiro (a porta 24565 é única),
# o cliente age, e o host fecha o relatório sozinho quando o cliente anuncia a
# última fase. Sem isso, nada aqui cobre "morrer, respawnar e regenerar EM REDE".
if quer "mp"; then
	echo
	echo "-- multiplayer (dois processos: host juiz + cliente ator) --"
	printf '  %-24s ' "net_mp_probe"
	timeout 300 "$GODOT" --headless --path "$PROJ" \
		--script tools/dev_tests/net_mp_host_probe.gd >"$TMP/mp_host.log" 2>&1 &
	MP_PID=$!
	sleep 5                                    # o host precisa estar no ar antes
	t0=$SECONDS
	timeout 300 "$GODOT" --headless --path "$PROJ" \
		--script tools/dev_tests/net_mp_client_probe.gd >"$TMP/mp_cli.log" 2>&1
	cod=$?
	wait "$MP_PID" 2>/dev/null; cod_host=$?
	dt=$((SECONDS - t0))
	if _falhou "$cod" "$TMP/mp_cli.log" || _falhou "$cod_host" "$TMP/mp_host.log"; then
		echo "$(vermelho FALHOU) (${dt}s)"
		grep -E '✗|❌' "$TMP/mp_host.log" "$TMP/mp_cli.log" | head -3 | sed 's/^/        /'
		cp "$TMP/mp_host.log" /tmp/validar_mp_host.log
		cp "$TMP/mp_cli.log" /tmp/validar_mp_cli.log
		FALHOU=$((FALHOU+1)); FALHAS+=("net_mp_probe")
	else
		echo "$(verde ok) (${dt}s)"
		PASSOU=$((PASSOU+1))
	fi
fi

# ------------------------------ 3b. dano recíproco em rede: dois processos
# Complementa o net_mp_probe, que bate no cliente até matar (um sentido, e só
# a morte). Aqui os DOIS corpos apanham na mesma partida, a QUANTIA é conferida
# contra o que foi pedido, e o cliente confere o mesmo par de vidas do lado dele
# — que é o único jeito de pegar "o dano do servidor não atravessou a rede",
# invisível no processo do host.
if quer "mp"; then
	echo
	echo "-- dano recíproco (dois processos: host algoz + cliente testemunha) --"
	printf '  %-24s ' "net_dano_probe"
	timeout 200 "$GODOT" --headless --path "$PROJ" \
		--script tools/dev_tests/net_dano_host_probe.gd >"$TMP/dano_host.log" 2>&1 &
	DANO_PID=$!
	sleep 5                                    # o host precisa estar no ar antes
	t0=$SECONDS
	timeout 200 "$GODOT" --headless --path "$PROJ" \
		--script tools/dev_tests/net_dano_client_probe.gd >"$TMP/dano_cli.log" 2>&1
	cod=$?
	wait "$DANO_PID" 2>/dev/null; cod_host=$?
	dt=$((SECONDS - t0))
	if _falhou "$cod" "$TMP/dano_cli.log" || _falhou "$cod_host" "$TMP/dano_host.log"; then
		echo "$(vermelho FALHOU) (${dt}s)"
		grep -E '✗|❌' "$TMP/dano_host.log" "$TMP/dano_cli.log" | head -4 | sed 's/^/        /'
		cp "$TMP/dano_host.log" /tmp/validar_dano_host.log
		cp "$TMP/dano_cli.log" /tmp/validar_dano_cli.log
		FALHOU=$((FALHOU+1)); FALHAS+=("net_dano_probe")
	else
		echo "$(verde ok) (${dt}s)"
		PASSOU=$((PASSOU+1))
	fi
fi

# ------------------------------------------ 4. regressão de locomoção (golden)
# Este é diferente dos outros: compara a trajetória com um arquivo de
# referência commitado. É o que pega "o personagem não anda" / "atravessa
# parede" — que nenhum teste headless acusa. Precisa de tela: a locomoção só lê
# teclado com o mouse capturado.
# TRAVA DO CORPO A CORPO — precisa de tela pelo mesmo motivo do traço: a
# medição é a DISTÂNCIA andada com W segurado, e sem mouse capturado o
# `MoveFrame` não lê tecla nenhuma.
if quer "melee" || quer "trava"; then
	if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
		printf '  %-24s %s\n' "test_melee_trava" "$(amarelo 'pulado — sem tela')"
		PULADO=$((PULADO+1))
	else
		roda "test_melee_trava" "$GODOT" --path "$PROJ" \
			--script tools/dev_tests/test_melee_trava.gd
	fi
fi

# SEGURAR UM ATAQUE NÃO PODE DEIXAR ANDAR — varre as 9 frutas × 4 slots.
# Pega a classe de bug que uma tabulação errada no `_etapa_travamento` causou:
# o quadro não era cortado e a locomoção reescrevia a velocidade congelada.
if quer "segurar" || quer "ataque"; then
	if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
		printf '  %-24s %s\n' "test_segurar_ataque" "$(amarelo 'pulado — sem tela')"
		PULADO=$((PULADO+1))
	else
		roda "test_segurar_ataque" "$GODOT" --path "$PROJ" \
			--script tools/dev_tests/test_segurar_ataque.gd
	fi
fi

ESPERADO="$PROJ/tools/dev_tests/traco_esperado.txt"
if quer "traco" && [ $RAPIDO -eq 0 ]; then
	echo
	echo "-- regressão de locomoção ($(wc -l < "$ESPERADO") quadros vs. referência) --"
	if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
		printf '  %-24s %s\n' "traco_locomocao" "$(amarelo 'pulado — sem tela')"
		PULADO=$((PULADO+1))
	elif [ ! -f "$ESPERADO" ]; then
		printf '  %-24s %s\n' "traco_locomocao" "$(amarelo 'sem referência — gere com --gravar')"
		PULADO=$((PULADO+1))
	else
		printf '  %-24s ' "traco_locomocao"
		t0=$SECONDS
		timeout "$TIMEOUT" "$GODOT" --path "$PROJ" \
			--script tools/dev_tests/tracar_locomocao.gd -- "$TMP/traco.txt" \
			>"$TMP/traco.log" 2>&1
		dt=$((SECONDS - t0))
		if [ ! -s "$TMP/traco.txt" ]; then
			echo "$(vermelho 'NAO GEROU') — veja /tmp/validar_traco.log"
			cp "$TMP/traco.log" /tmp/validar_traco.log
			FALHOU=$((FALHOU+1)); FALHAS+=("traco_locomocao (não gerou)")
		elif diff -q "$ESPERADO" "$TMP/traco.txt" >/dev/null; then
			echo "$(verde ok) ($(wc -l < "$TMP/traco.txt") quadros idênticos, ${dt}s)"
			PASSOU=$((PASSOU+1))
		else
			n=$(diff "$ESPERADO" "$TMP/traco.txt" | grep -c '^<')
			echo "$(vermelho REGRESSAO) — $n quadros diferentes"
			diff "$ESPERADO" "$TMP/traco.txt" | head -6 | sed 's/^/        /'
			cp "$TMP/traco.txt" /tmp/validar_traco_atual.txt
			echo "        traço atual salvo em /tmp/validar_traco_atual.txt"
			FALHOU=$((FALHOU+1)); FALHAS+=("traco_locomocao (regressão de física)")
		fi
	fi
fi

# ------------------------------------------------------------------ resultado
echo
echo "=================================================="
printf 'passou: %s   falhou: %s   pulado: %s\n' \
	"$(verde "$PASSOU")" "$([ "$FALHOU" -gt 0 ] && vermelho "$FALHOU" || echo 0)" "$PULADO"
if [ "$FALHOU" -gt 0 ]; then
	echo
	echo "FALHAS:"
	for f in "${FALHAS[@]}"; do echo "  - $f"; done
	echo
	echo "Logs completos em /tmp/validar_*.log"
	exit 1
fi
echo "$(verde 'tudo de pé.')"
