class_name IaDoMod
extends Node
# ============================================================================
#  A IA DO MOD num personagem do Mine Piece (23/10/2026; decisão do dono: "junto, atrás de
#  chave"). O cérebro do jogo (`CerebroMinePiece`) continua perseguindo e escolhendo alvo; este
#  nó roda, a 20 ticks/s, as procedures do `baseTick` da classe do mod (ficha do mod:
#  `Mc.ficha_do_mod(id).tick`, ex.: `AIArlongProcedure`) — golpes, técnicas, armas, efeitos.
#  Ao primeiro tick roda as do `finalizeSpawn` (`SetTagPirateProcedure`…), como ao nascer.
#
#  ⚠️ Começa DESLIGADA: o dano é de verdade, mas partículas, sons, animações das técnicas e
#  projéteis do mod ainda não são desenhados (golpe "invisível"). F8 → "IA do mod" liga.
#  Os argumentos de cada procedure saem do NOME dos parâmetros traduzidos (world, x, y, z, entity).
# ============================================================================

const TICK := MundoMinePiece.TICK

## Chave geral (painel F8). Ligada por padrão desde 24/10/2026: as habilidades dos inimigos são as do mod.
static var ligada := true
## Fase inicial aleatória do relógio de ticks (04/11/2026). Sem isto, todo personagem criado junto tica no MESMO quadro: medido
## 70 a 77 ticks (de ~81 personagens) num quadro só, p95 do quadro em 28 ms ao acordar o acampamento. Desligar só nas medições.
static var espalhar_fases := true

## FAIXA DE ATIVAÇÃO (04/11/2026; decisão do dono: "sim, conservadora"). Idéia do ServerCore (padrão do mob: 20 blocos, 1 tick em 6).
## Medido: dos 81 personagens do East Blue só 7 estavam a < 20 m do jogador e 74 a > 80 m, todos com IA a 20 Hz (~3,2 ms/quadro).
## Além de ALCANCE_ATIVO do jogador mais próximo, e FORA de combate, a IA tica 1 vez em TICKS_POR_UM_INATIVO. Fica ATIVO (taxa cheia) se:
## chefe · tem alvo ou revide · levou dano há menos de ACORDADO_POR_DANO · jogador dentro do alcance. Só vale para PersonagemMinePiece.
## Desligar só nas medições, ou se um personagem distante precisar agir com o jogador longe (ex.: evento de missão).
static var faixa_de_ativacao := true
const ALCANCE_ATIVO := 80.0
const TICKS_POR_UM_INATIVO := 6
const ACORDADO_POR_DANO := 8.0
static var _jogadores: Array = []
static var _jogadores_quadro := -1
var _inativo := false
var _ticks_inativos := 0
var _acordado_ate_ms := 0

var _corpo: Node3D
var _ent: McEntidade
var _tick: Array = []            # [script, nomes dos parâmetros]
## `tick()` da CLASSE do mod (não o `baseTick`): roda depois dele a cada tick. A flecha do Aro Aro depende disto — o `AIArrowBarrier` faz a flecha de
## carga seguir o dono e SUMIR quando a técnica acaba; sem ele ela ficava girando parada no ponto onde nasceu e nunca sumia. Projéteis
## (AbstractArrow…) já rodam o `tick_classe` no `McCorpoDoMod._tick_de_projetil`: aqui ficam de fora para não rodar duas vezes.
var _tick_classe: Array = []
var _ao_nascer: Array = []
var _nasceu := false
var _acumulado := 0.0


## `id`: o id do mod (`arlong`). Sem procedure de tick na ficha do mod, o nó fica sem fazer nada.
func montar(corpo: Node3D, id: String) -> void:
	_corpo = corpo
	var ficha := Mc.ficha_do_mod(id)
	_tick = _carregar(ficha.get("tick", []))
	_ao_nascer = _carregar(ficha.get("ao_nascer", []))
	if not str(ficha.get("base", "")) in ["AbstractArrow", "ThrowableItemProjectile", "ThrowableProjectile"]:
		_tick_classe = _carregar(ficha.get("tick_classe", []))
	if espalhar_fases:
		_acumulado = randf() * TICK


func tem_ia() -> bool:
	return not _tick.is_empty()


static func _carregar(nomes: Array) -> Array:
	var saida := []
	for nome in nomes:
		var s := Mc.proc(StringName(str(nome)))
		if s == null:
			continue
		for m in s.get_script_method_list():
			if m["name"] == "execute":
				saida.append([s, m["args"].map(func(a): return str(a["name"]))])
				break
	return saida


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"IaDoMod.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if not ligada or (_tick.is_empty() and _tick_classe.is_empty()) or not is_instance_valid(_corpo) or not _corpo.is_inside_tree():
		return
	if _corpo.has_method("vivo") and not _corpo.vivo():
		return
	if _corpo is McCorpoDoMod and (_corpo as McCorpoDoMod).id_personagem != McVisual.RAIO:
		delta *= MundoMinePiece.FATOR_DE_PROJETIL       # entidade/projétil do mod: mesmo relógio lento do corpo
	_acumulado += delta
	_inativo = faixa_de_ativacao and _fora_da_faixa()
	while _acumulado >= TICK:
		_acumulado -= TICK
		if _inativo:
			_ticks_inativos += 1
			if (_ticks_inativos + get_instance_id()) % TICKS_POR_UM_INATIVO != 0:
				Cronometro.contar(&"IaDoMod.tick_pulado")
				continue
		var t_tick := Cronometro.ini()
		um_tick()
		Cronometro.fim(&"IaDoMod.um_tick", t_tick)


## Fora da faixa de ativação? (ver o bloco no topo.) Só personagens do East Blue; outros corpos nunca ficam inativos.
func _fora_da_faixa() -> bool:
	var c := _corpo as PersonagemMinePiece
	if c == null or Time.get_ticks_msec() < _acordado_ate_ms or bool(c.ficha.get("chefe", false)):
		return false
	var cerebro = c.get("cerebro")
	if cerebro != null and (cerebro.alvo != null or cerebro.get("_revide") != null):
		return false
	var quadro := Engine.get_physics_frames()
	if _jogadores_quadro != quadro:
		_jogadores_quadro = quadro
		_jogadores = get_tree().get_nodes_in_group("player")
	var limite := ALCANCE_ATIVO * ALCANCE_ATIVO
	for j in _jogadores:
		if is_instance_valid(j) and (j as Node3D).global_position.distance_squared_to(c.global_position) < limite:
			return false
	return not _jogadores.is_empty()


## Golpe recebido (`take_damage` do personagem, com a chave ligada), na ordem do Minecraft:
## LivingAttack (cancelável) e LivingHurt ANTES da armadura — devolve o dano (< 0 = cancelado);
## `dano_final` dispara o LivingDamage DEPOIS da armadura.
func ao_receber_dano(quantidade: float, de_quem: Node3D) -> float:
	if not ligada or _tick.is_empty():
		return quantidade
	_acordado_ate_ms = Time.get_ticks_msec() + int(ACORDADO_POR_DANO * 1000.0)
	_inativo = false
	if _ent == null:
		_ent = McEntidade.de(_corpo)
	_fonte_do_golpe = _fonte(de_quem)
	for tipo in [&"LivingAttackEvent", &"LivingHurtEvent"]:
		var e := McEvento.disparar(tipo, _ent, _fonte_do_golpe, quantidade)
		if e.cancelado:
			return -1.0
		quantidade = e.quantidade
	return quantidade


func dano_final(quantidade: float) -> float:
	if not ligada or _tick.is_empty() or _ent == null:
		return quantidade
	var e := McEvento.disparar(&"LivingDamageEvent", _ent, _fonte_do_golpe, quantidade)
	return 0.0 if e.cancelado else e.quantidade


var _fonte_do_golpe: McFonteDeDano


func _fonte(de_quem: Node3D) -> McFonteDeDano:
	var verdadeira: Variant = _corpo.get_meta("fonte_mc") if is_instance_valid(_corpo) and _corpo.has_meta("fonte_mc") else null
	if verdadeira is McFonteDeDano:
		return verdadeira
	var atacante := McEntidade.de(de_quem) if de_quem != null and is_instance_valid(de_quem) else null
	return McFonteDeDano.de(&"minecraft:mob_attack" if atacante != null else &"minecraft:generic", atacante)


func ao_morrer(de_quem: Node3D) -> void:
	if not ligada or _tick.is_empty() or _ent == null:
		return
	McEvento.disparar(&"LivingDeathEvent", _ent, _fonte(de_quem))


## Um tick do mod (público para o teste).
func um_tick() -> void:
	var t := Cronometro.ini()
	if _ent == null:
		_ent = McEntidade.de(_corpo)
		Cronometro.fim(&"IaDoMod.criar_entidade", t)
	if not _nasceu:
		_nasceu = true
		var t_n := Cronometro.ini()
		for p in _ao_nascer:
			var t_p := Cronometro.ini()
			_rodar(p)
			if Cronometro.ligado:
				Cronometro.fim(StringName("nascer:" + (p[0] as Script).resource_path.get_file()), t_p)
		Cronometro.fim(&"IaDoMod.ao_nascer", t_n)
	var t_t := Cronometro.ini()
	for p in _tick:
		_rodar(p)
	for p in _tick_classe:
		if is_instance_valid(_corpo) and not _corpo.is_queued_for_deletion():
			_rodar(p)
	Cronometro.fim(&"IaDoMod.procs_do_tick", t_t)
	# As técnicas rodam no LivingTickEvent (EntityActiveProcedure), não no baseTick.
	var t_e := Cronometro.ini()
	McEvento.disparar(&"LivingTickEvent", _ent)
	Cronometro.fim(&"IaDoMod.evento_tick", t_e)


func _rodar(p: Array) -> void:
	var t_a := Cronometro.ini()
	var valores := Mc.argumentos_de(_ent)
	var args: Array = (p[1] as Array).map(func(n): return valores.get(n))
	Cronometro.fim(&"IaDoMod.montar_args", t_a)
	var t_x := Cronometro.ini()
	(p[0] as GDScript).callv("execute", args)
	Cronometro.fim(&"IaDoMod.executar_proc", t_x)
