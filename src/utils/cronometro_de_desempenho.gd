class_name Cronometro
extends RefCounted
# ============================================================================
#  CRONÔMETRO DE DESEMPENHO (04/11/2026). Pedido do dono: "instrumenta os maiores candidatos com cronômetro e mede" —
#  o FPS cai quando várias ações acontecem juntas e quando há muitos inimigos.
#
#  Custo DESLIGADO: um `if` numa variável estática por chamada (ini devolve 0, fim sai na primeira linha).
#  Ligado só pelos medidores de tools/dev_tests; o jogo normal nunca liga.
#
#  Uso nos scripts do jogo (envolve a função inteira, sem mexer na lógica):
#      func _physics_process(delta):
#          var t := Cronometro.ini()
#          _physics_process_corpo(delta)
#          Cronometro.fim(&"Rotulo", t)
#  O medidor chama `Cronometro.fechar_quadro()` uma vez por quadro: devolve {rotulo: [microssegundos, chamadas]} do quadro
#  que passou e zera. Somar por quadro (e não por chamada) é o que mostra PICO: 81 ticks no mesmo quadro = 81 × 347 µs.
#
#  Limite: mede tempo de relógio da função, inclusive o que ela espera (move_and_slide entra no tempo do corpo).
#  Rótulos aninhados se SOBREPÕEM (o tempo do corpo contém o do que ele chama): não somar rótulos entre si.
# ============================================================================

static var ligado := false
static var _us: Dictionary = {}
static var _n: Dictionary = {}


static func ini() -> int:
	return Time.get_ticks_usec() if ligado else 0


static func fim(rotulo: StringName, t0: int) -> void:
	if not ligado:
		return
	_us[rotulo] = int(_us.get(rotulo, 0)) + (Time.get_ticks_usec() - t0)
	_n[rotulo] = int(_n.get(rotulo, 0)) + 1


## Conta um evento sem tempo (ex.: quantos ticks da IA rodaram neste quadro).
static func contar(rotulo: StringName, quantos: int = 1) -> void:
	if ligado:
		_n[rotulo] = int(_n.get(rotulo, 0)) + quantos


## AMOSTRA DE PILHA (11/11/2026): quem está chamando uma função quente? A cada `cada` chamadas guarda o arquivo da procedure (de `procedures/`
## ou `otimizadas/`) mais perto do topo da pilha. Só vale ligado (o jogo normal não paga nada) e só em build com pilha (editor/debug).
static var _perfil: Dictionary = {}
static var _contagem_perfil: Dictionary = {}


static func amostrar(rotulo: StringName, cada: int = 512) -> void:
	if not ligado:
		return
	var n := int(_contagem_perfil.get(rotulo, 0)) + 1
	_contagem_perfil[rotulo] = n
	if n % cada != 0:
		return
	for quadro in get_stack():
		var fonte := String(quadro.get("source", ""))
		if fonte.contains("/procedures/") or fonte.contains("/otimizadas/"):
			var chave := StringName(fonte.get_file().get_basename())
			_perfil[chave] = int(_perfil.get(chave, 0)) + 1
			return
	_perfil[&"(fora de procedure)"] = int(_perfil.get(&"(fora de procedure)", 0)) + 1


## {procedure: amostras} desde a última chamada, zerando.
static func fechar_perfil() -> Dictionary:
	var saida := _perfil.duplicate()
	_perfil.clear()
	_contagem_perfil.clear()
	return saida


static func fechar_quadro() -> Dictionary:
	var saida := {}
	for k in _n:
		saida[k] = [int(_us.get(k, 0)), int(_n[k])]
	_us.clear()
	_n.clear()
	return saida
