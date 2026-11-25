class_name YoruController
extends Node
## Relógio físico único: nenhuma callback de timer pode ressuscitar um ataque.
signal action_cancelled(reason: String)
signal action_finished(id: String)
signal guard_confirmed()
var cooldowns: Dictionary = {"Z":0.0,"X":0.0,"C":0.0,"V":0.0}
var direction := Vector3.FORWARD
var action_id := ""
var elapsed := 0.0
var sequence := 0
var riposte := 0.0
var _player: Node3D
var _combo := 0
var _combo_time := 0.0
var _penalty := 0.0
var _released := false
var _armed := false
var _conectou := false
var _idle_clock := 0.0
var _cast := 0
var _rig: RefCounted
var _trail: WeaponTrail3D

# ============================================================================
#  O RASTRO DA LÂMINA — cor e janela
# ============================================================================
#  MEDIDO na referência do dono (09/09/2026), amostrando os pixels claros e
#  dessaturados do rastro quadro a quadro, fora do céu:
#
#      cor composta na tela ..... (0,74 · 0,79 · 0,76)   saturação 0,06
#      persistência ............. pico -> sumiço em ~0,17 s (zerado em 0,25 s)
#
#  Contra o que estava aqui: `Color(0,45 · 0,96 · 0,66)`, saturação **0,53**.
#  O rastro do jogo era VERDE-MENTA FORTE; o da referência é quase branco, com
#  um resto de verde. Mesma diferença na `YoruWave` (lá era saturação 0,88).
#
#  ⚠️ A cor abaixo é do MATERIAL, e por isso é mais clara que os (0,74/0,79/0,76)
#  medidos: aqueles já saíram compostos sobre o fundo, com o alfa aplicado.
#  Perseguir o número da tela no material deixaria o rastro cinza.
#
#  ⚠️ E o alvo é INTENÇÃO, não medida fina: a referência passou por realce de IA
#  (Nano Banana), que na mesma passagem inventou um nome de técnica inexistente
#  na HUD ("Guarda da Noite", mistura de "Guarda da Cruz" com "Ruptura da
#  Noite"). O que se copia dela é a LEITURA — pálido em vez de verde —, não
#  dígitos.
const RASTRO_VIDA := 0.20
const RASTRO_INICIO := Color(0.84, 0.96, 0.89, 0.55)
const RASTRO_FIM := Color(0.10, 0.16, 0.13, 0.0)
# O rastro abre um pouco antes do fio entrar e fecha depois dele sair — é o que
# lhe dá arco. Fora disso ele é uma lasca no quadro do dano.
const RASTRO_ANTECIPA := 0.05
const RASTRO_CAUDA := 0.12

# ---------------------------------------------------------------- o clique
#  O ARCO DO M1 É ROXO, e só ele. MEDIDO na segunda referência do dono
#  (`melhorar_as_skills_em_video_ta.mp4`, últimos 3 s), amostrando os pixels de
#  matiz 0,68-0,86 com saturação acima de 0,35, fora do céu, em 5 quadros:
#
#      corpo do arco ..... (0,504 · 0,266 · 0,799)   saturação 0,67
#      borda brilhante ... (0,782 · 0,421 · 0,976)   saturação 0,57
#      persistência ...... pico em +0,00 s, zerado em +0,54 s
#
#  ⚠️ ISTO NÃO REVOGA a paleta pálida acima. As duas referências mostram coisas
#  diferentes: lá era o rastro genérico da espada, aqui é a assinatura do CLIQUE.
#  Z, X, C e V continuam com o rastro quase branco de 09/09 — e é esse contraste
#  que faz o M1 ter cara própria em vez de todo golpe borrar igual.
#
#  ⚠️ A vida abaixo é 0,42 s, não os 0,54 s medidos: o fim daquela cauda são as
#  partículas soltas, que aqui são outro efeito (`YoruFX.arco_eletrico`), não a
#  fita. Perseguir o número cheio deixaria a fita pendurada no ar depois que o
#  golpe já acabou.
const RASTRO_M1_VIDA := 0.42
const RASTRO_M1_INICIO := Color(0.78, 0.42, 0.98, 0.95)
const RASTRO_M1_FIM := Color(0.16, 0.05, 0.30, 0.0)
var _trail_action := ""
var _warning: MeshInstance3D
var _weapon: Node3D

func setup(player: Node3D) -> void:
	_player = player
	process_physics_priority = 50
	_rig = preload("res://src/anim/YoruRig.gd").new()

func next_m1() -> String:
	return "M1_2" if riposte > 0.0 or (_combo == 1 and _combo_time > 0.0) else "M1_1"

func can_start(id: String) -> bool:
	if not is_instance_valid(_player) or YoruMoves.get_move(id).is_empty(): return false
	if str(_player.get("combat_mode")) != "sword" or float(_player.get("health")) <= 0.0: return false
	if _penalty > 0.0 or cooldown(id) > 0.0: return false
	if action_id != "" and not (action_id == "C" and riposte > 0.0 and id == "M1_2"): return false
	if id == "V" and not _has_floor(): return false
	for state in ["is_frozen", "in_black_hole", "in_kurouzu", "in_vortex"]:
		if _player.get_meta(state, false): return false
	return is_instance_valid(_player.get("_yoru"))

func start_action(id: String, seq: int, facing: Vector3, time: float = 0.0) -> void:
	if seq <= sequence or YoruMoves.get_move(id).is_empty(): return
	_clear_action()
	sequence = seq
	action_id = id
	elapsed = maxf(time, 0.0)
	direction = Vector3(facing.x,0,facing.z).normalized()
	if direction.length_squared() < 0.5: direction = Vector3.FORWARD
	var m := YoruMoves.get_move(id)
	if cooldowns.has(id): cooldowns[id] = maxf(0.0, float(m.cooldown) - elapsed)
	_cast = CombatResolver.novo_cast()
	_released = elapsed >= float(m.startup) # snapshots do not replay emitted projectiles
	_armed = false
	_conectou = false
	riposte = 0.0
	if id.begins_with("M1"):
		_combo = 1 if id == "M1_1" else 0
		_combo_time = YoruMoves.duration(id) + 0.9
	_player.set_meta("yoru_action", sequence)
	if elapsed < 0.05: _audio("charge" if id in ["Z","V","C"] else "swing")
	if id == "V" and not _released: _make_warning()

func cooldown(slot: String) -> float:
	return float(cooldowns.get(slot, 0.0))

func restore_cooldowns(values: Dictionary) -> void:
	for slot in cooldowns:
		cooldowns[slot] = clampf(float(values.get(slot,0.0)),0.0,60.0)

func cancel(reason: String = "") -> void:
	var had_action := action_id != ""
	if had_action and reason != "snapshot":
		_penalty = maxf(_penalty, minf(0.35, maxf(0.12,YoruMoves.duration(action_id)-elapsed)))
	_clear_action()
	_combo = 0
	riposte = 0.0
	if had_action: action_cancelled.emit(reason)

func _clear_action() -> void:
	if is_instance_valid(_player):
		var blade: SwordBlade = _player.call("lamina_da_espada")
		if blade: blade.desarmar()
		_player.remove_meta("yoru_action")
	if is_instance_valid(_trail):
		_trail.emit(false)
		_trail.clear()
	if is_instance_valid(_warning): _warning.queue_free()
	_warning = null
	if _cast: CombatResolver.encerrar(_cast)
	_cast = 0
	_armed = false
	_conectou = false
	action_id = ""
	elapsed = 0.0

func _physics_process(delta: float) -> void:
	for slot in cooldowns: cooldowns[slot] = maxf(0.0,float(cooldowns[slot])-delta)
	_penalty = maxf(0.0,_penalty-delta)
	_combo_time = maxf(0.0,_combo_time-delta)
	riposte = maxf(0.0,riposte-delta)
	if not is_instance_valid(_player): return
	if str(_player.get("combat_mode")) != "sword" or float(_player.get("health")) <= 0.0:
		if action_id != "": cancel("unavailable")
		return
	var sword: Node3D = _player.get("_yoru")
	if not is_instance_valid(sword):
		if action_id != "": cancel("weapon_removed")
		return
	if sword != _weapon:
		_weapon = sword
		_rig.call("setup",_player,sword)
		# Ligada UMA vez por arma, e não a cada golpe: uma conexão `ONE_SHOT` por
		# ação que não chegasse a acertar ficaria pendurada na lâmina e se
		# acumularia. Marcar fora de uma ação é inofensivo — `_conectou` zera em
		# todo `start_action`.
		var fio: SwordBlade = _player.call("lamina_da_espada")
		if fio and not fio.acertou.is_connected(on_hit_confirmed):
			fio.acertou.connect(on_hit_confirmed)
		if is_instance_valid(_trail): _trail.queue_free()
		_trail = WeaponTrail3D.new()
		_trail.target_base = sword.get("guarda")
		_trail.target_tip = sword.get("ponta")
		_trail.life_time = RASTRO_VIDA
		_trail.startColor = RASTRO_INICIO
		_trail.endColor = RASTRO_FIM
		add_child(_trail)
	for state in ["is_frozen", "in_black_hole", "in_kurouzu", "in_vortex"]:
		if _player.get_meta(state, false):
			cancel("status")
			return
	if action_id == "":
		# ⚠️ O CAMINHO ANTIGO AINDA CORTA, E TEM PREFERÊNCIA. `Melee` +
		# `ProceduralAnimator` executam o corte da espada sem passar por este
		# controlador; enquanto isso acontece, `action_id` está vazio aqui e a
		# pose parada entraria POR CIMA do golpe — este nó roda com prioridade
		# 50, depois do Player, então quem escreve por último é ele.
		#
		# Medido em `test_corte_horizontal`: com a guarda aplicada por cima, a
		# espada ficava presa em x=+0,78 / z=+1,53 (a própria guarda) nos 16
		# quadros do corte, e o teste subia de 9 para 11 asserções reprovadas.
		# A pose parada é de quem está PARADO — um golpe em curso, venha de onde
		# vier, é dono do corpo.
		if _golpe_procedural_em_curso():
			return
		# Relógio próprio do idle: a guarda respira, e `pose` precisa de um tempo
		# que ande. Passar 0,0 fixo, como antes, congelava a respiração no mesmo
		# ponto do ciclo. Reinicia a cada volta para não crescer sem limite.
		_idle_clock = fmod(_idle_clock + delta, 600.0)
		_rig.call("pose","",_idle_clock, direction)
		return
	var m := YoruMoves.get_move(action_id)
	var previous := elapsed
	elapsed += delta
	_rig.call("pose",action_id,elapsed,direction)
	_avancar(m, previous, elapsed)
	var active := elapsed >= float(m.startup) and elapsed < float(m.startup)+float(m.active)
	var blade: SwordBlade = _player.call("lamina_da_espada")
	if active and bool(m.get("blade",false)) and not _armed and blade:
		blade.armar(float(m.damage),float(m.kb),0.25,_cast,float(m.damage),action_id.begins_with("M1"))
		_armed = true
		# Os raios do clique nascem com a janela de dano, no fio, e são LOCAIS:
		# cada peer desenha os seus a partir da ação que já está replicada, sem
		# gastar uma mensagem para um efeito que dura 0,22 s.
		if action_id.begins_with("M1"): YoruFX.arco_eletrico(sword)
	if not active and _armed and blade: blade.desarmar()
	# ⚠️ O RASTRO NÃO É MAIS EXCLUSIVO DA JANELA DE DANO NEM DOS GOLPES DE FIO.
	#
	# Era `active and m.blade`, e isso tinha duas consequências que a referência
	# de 09/09/2026 mostra como erradas:
	#
	#  1. `Z` e `V` NÃO TINHAM RASTRO NENHUM. Nenhuma das duas carrega a flag
	#     `blade` (quem machuca nelas é a onda, não o fio), então a espada fazia
	#     o gesto inteiro da Ruptura da Noite sem deixar marca — justamente o
	#     golpe com o rastro mais largo na referência.
	#  2. O rastro NASCIA E MORRIA na janela de dano, cortado nas duas pontas. Na
	#     referência ele começa um pouco antes do fio entrar e some depois, junto
	#     com a inércia. Rastro que aparece e some no mesmo quadro do dano não
	#     tem tempo de desenhar arco nenhum.
	#
	# `varre` é ESTRUTURAL, não uma lista de nomes: quem tem `blade` corta com o
	# fio, quem tem `range` lança uma frente — os dois nascem de um golpe de
	# espada. A `C` (Guarda da Cruz) não tem nenhum dos dois porque é guarda
	# parada, e é exatamente ela que não pode borrar rastro.
	var varre: bool = bool(m.get("blade", false)) or m.has("range")
	var janela: bool = elapsed >= float(m.startup) - RASTRO_ANTECIPA \
		and elapsed <= float(m.startup) + float(m.active) + RASTRO_CAUDA
	_pintar_rastro()
	_trail.emit(varre and janela)
	if not _released and elapsed >= float(m.startup):
		_released = true
		if action_id in ["Z","V"]: _spawn_wave(m)
	if elapsed >= YoruMoves.duration(action_id):
		var finished := action_id
		_clear_action()
		action_finished.emit(finished)

## O `ProceduralAnimator` está no meio de um corte de espada?
##
## `_sword_slash_type` é o tipo do golpe em curso naquele caminho, e vale -1
## quando não há nenhum. Lido por `get` em vez de tipado porque o animador é
## opcional: personagens sem ele (e os fixtures de teste) simplesmente não têm
## o campo, e aí não há golpe antigo nenhum para respeitar.
func _golpe_procedural_em_curso() -> bool:
	var animador = _player.get("_proc_anim") if is_instance_valid(_player) else null
	if not is_instance_valid(animador):
		return false
	return int(animador.get("_sword_slash_type")) >= 0


## Troca a paleta da fita quando a AÇÃO muda, não a cada quadro: o rastro guarda
## a cor nos pontos já emitidos, então repintar no meio de um golpe mudaria a
## cauda que ainda está na tela.
func _pintar_rastro() -> void:
	if _trail_action == action_id or not is_instance_valid(_trail):
		return
	_trail_action = action_id
	var m1 := action_id.begins_with("M1")
	_trail.life_time = RASTRO_M1_VIDA if m1 else RASTRO_VIDA
	_trail.startColor = RASTRO_M1_INICIO if m1 else RASTRO_INICIO
	_trail.endColor = RASTRO_M1_FIM if m1 else RASTRO_FIM
	# O miolo escuro é do CLIQUE. Nas técnicas a fita continua lisa, como estava.
	var mat := _trail.material_override as StandardMaterial3D
	if mat:
		mat.albedo_texture = YoruFX.fita_do_clique() if m1 else null


# ============================================================================
#  O AVANÇO DO GOLPE — o corpo acompanha a espada
# ============================================================================
#  Pedido do dono (10/09/2026): "adicionar uma mecânica para o player ir para
#  frente quando ataca com a espada e não acerta o inimigo, assim ele não irá
#  ficar parando toda vez que atacar".
#
#  Quem ERRA é levado adiante pela própria inércia; quem ACERTA para onde o golpe
#  conectou, em vez de atravessar o alvo. Por isso o corte é reativo — ninguém
#  decide antes do golpe se ele vai acertar, e `on_hit_confirmed` chega da mesma
#  fonte que já desenha as fagulhas do contato.
#
#  O `step` do Passo do Predador continua sendo outra coisa: lá a passada É a
#  técnica, roda inteira na preparação e fecha distância ANTES do corte, sempre,
#  acertando ou não. Os dois perfis convivem em `_percurso`, cada um com a sua
#  janela, em vez de um `if action_id == "X"` solto no meio do processo físico.
#  ⚠️ OS DOIS NÚMEROS ABAIXO SÃO O QUE FAZ O CORTE VALER ALGUMA COISA. Na
#  primeira versão o avanço abria no meio da preparação e fechava com a janela de
#  dano; medido, isso punha **78% do percurso antes do primeiro quadro em que a
#  lâmina pode acertar** — o golpe conectava, o avanço era interrompido, e
#  sobrava um corte de 0,25 m em 1,40 m. Adiar a abertura para o fim da
#  preparação e deixar o deslize correr um pedaço da recuperação inverte a
#  proporção: ~29% antes, ~71% dentro do alcance do corte.
const AVANCO_INICIO := 0.85   # fração do startup em que o pé começa a sair
const AVANCO_CAUDA := 0.40    # fatia da recuperação em que o deslize ainda corre


## Fração da distância já percorrida no instante `t`.
##
## `step`: rampa linear dentro da preparação — é a passada de aproximação, e o
## comportamento medido e aprovado do X em 09/09/2026 não muda.
## `advance`: abre no fim da preparação, corre por toda a janela de dano e morre
## no começo da recuperação, desacelerando (ease-out) — o peso de um passo à
## frente, que sai com a lâmina e ainda escorrega um pouco quando ela já passou.
func _percurso(m: Dictionary, t: float) -> float:
	var startup := float(m.startup)
	if m.has("step"):
		return clampf(t / maxf(startup, 0.001), 0.0, 1.0)
	var inicio := startup * AVANCO_INICIO
	var fim := startup + float(m.active) + float(m.recovery) * AVANCO_CAUDA
	var f := clampf((t - inicio) / maxf(fim - inicio, 0.001), 0.0, 1.0)
	return 1.0 - pow(1.0 - f, 2.0)


## Move o corpo pela FATIA percorrida entre dois quadros, nunca pela posição
## absoluta: um quadro perdido atrasa o passo, não teleporta o jogador.
func _avancar(m: Dictionary, antes: float, agora: float) -> void:
	if _conectou:
		return
	var distancia := float(m.get("step", m.get("advance", 0.0)))
	if distancia <= 0.0 or not (_player is CharacterBody3D):
		return
	# A autoridade do Player é o cliente dono (`Main.gd` o registra por peer), e é
	# ele quem simula o próprio corpo; o servidor recebe a posição pelo sincronizador.
	if not _player.is_multiplayer_authority():
		return
	var fatia := _percurso(m, agora) - _percurso(m, antes)
	if fatia <= 0.0:
		return
	_player.move_and_collide(direction * distancia * fatia)


## O golpe encostou em alguém: o resto do avanço morre aqui.
##
## Chega por DOIS caminhos, porque nenhum dos dois cobre sozinho os casos que
## existem, e a marca é idempotente:
##
##  1. o sinal `acertou` da própria lâmina — imediato, mas só existe onde o dano
##     é resolvido (servidor e partida local);
##  2. `YoruNetwork._show_contact` — o caminho que atravessa a rede e alcança o
##     CLIENTE dono, que é quem simula o próprio corpo e portanto quem avança.
##
## ⚠️ Em rede o aviso do caminho 2 chega por RPC não confiável (o mesmo das
## fagulhas). Um pacote perdido não quebra nada — o jogador desliza o resto do
## passo — e é o preço já aceito para o feedback de contato deste projeto.
func on_hit_confirmed(_alvo: Node = null) -> void:
	_conectou = true


func is_parrying(origin: Vector3) -> bool:
	return action_id == "C" and elapsed >= 0.06 and elapsed <= 0.24 and _in_front(origin)

func guard_multiplier(origin: Vector3) -> float:
	return 0.35 if action_id == "C" and elapsed >= 0.06 and elapsed <= 0.60 and _in_front(origin) else 1.0

func _in_front(origin: Vector3) -> bool:
	var to := origin - _player.global_position
	to.y = 0.0
	return to.normalized().dot(direction) > 0.45

func on_parry(_attacker: Node, _position: Vector3) -> void:
	riposte = 1.0
	guard_confirmed.emit()

func _audio(kind: String) -> void:
	var script: Script = load("res://src/effects/YoruAudio.gd")
	if script: script.call("play",_player,kind)

func _spawn_wave(data: Dictionary) -> void:
	if is_instance_valid(_warning): _warning.queue_free()
	_warning = null
	var wave: Node3D = load("res://src/combat/YoruWave.gd").new()
	_player.get_tree().current_scene.add_child(wave)
	wave.global_position = _player.global_position + direction * 0.65
	if action_id == "V": wave.global_position.y -= 0.7
	wave.call("setup",_player,action_id,direction,data)
	_audio("wave")

func _make_warning() -> void:
	_warning = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.1,0.015,18.0)
	_warning.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.26,0.85,0.55,0.18)
	_warning.material_override = mat
	_player.get_tree().current_scene.add_child(_warning)
	_warning.global_position = _player.global_position + direction*9.0 + Vector3(0,-0.77,0)
	_warning.rotation.y = atan2(-direction.x,-direction.z)


func _has_floor() -> bool:
	# O servidor não move_and_slide em Players remotos: conferir mundo físico,
	# não confiar em net_on_floor nem no cache is_on_floor de outro peer.
	var skip: Array[RID] = []
	if _player is CollisionObject3D: skip.append(_player.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(_player.global_position, _player.global_position+Vector3(0,-1.02,0),15,skip)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and Vector3(hit.normal).y > 0.7 and not hit.collider.has_method("take_damage")
