extends Node
## Cérebro de combate do Gorila-rei (22/11/2026). SEM skill builder: tudo aqui. Decisão e dano só no servidor; o desenho vermelho (`AvisoVermelho`) usa a
## MESMA geometria do dano.
##
## Ciclo de um golpe: ESCOLHER (por distância e recarga) → AVISO (a área vermelha enche; o chefe se prepara e acompanha o alvo até ~65 %, quando TRAVA a
## mira) → CONTATO (dano uma vez, só a quem está dentro da área mostrada) → RECUPERAÇÃO (parado: a janela de contra-ataque) → livre.
## Golpes: `soco_chao` (disco à frente), `pulo_esmagar` (disco no alvo, ele salta), `investida` (faixa), `giro` (disco em volta), `arremesso` (disco no alvo,
## pedra no ar) e a FÚRIA (fase 2, abaixo de 55 % da vida: rugido + anel grande). Na fúria o aviso é 20 % mais curto, o dano 15 % maior e o intervalo menor.
## Os clipes vêm do Blender (`tools/blender/gorila_rei.py`, manifesto com o quadro de contato): a velocidade do clipe é ajustada para o contato cair
## exatamente no fim do aviso.
signal iniciou(golpe: String)
signal terminou(golpe: String)

const Aviso := preload("res://src/historia/bosses/gorila_rei/aviso_vermelho.gd")
const LOOPS := ["idle", "walk", "run", "investida"]
## Quadro de contato (s) de cada clipe, o mesmo de `art_src/blender/gorila_rei/manifesto.json` (24 quadros/s).
const CONTATO_DO_CLIPE := {"soco_chao": 21.0 / 24.0, "pulo_esmagar": 30.0 / 24.0, "giro": 18.0 / 24.0, "arremesso": 26.0 / 24.0, "roar": 22.0 / 24.0, "furia": 20.0 / 24.0}
const GRAVIDADE := 32.0

var corpo: AnimalDaIlha
var config: Resource
var fase_da_luta := 1
var golpe := ""                       # "" = livre
var etapa := ""                       # aviso | voo | investida | recuperacao
var t := 0.0
var _alvo: Node3D
var _aviso: Node3D
var _ap: AnimationPlayer
var _clipe := ""
var _recargas := {}
var _intervalo := 1.0
var _ultimo := ""
var _marca := Vector3.ZERO            # centro do disco travado (pulo, arremesso)
var _direcao := Vector3.FORWARD       # direção travada (soco, investida)
var _travado := false
var _de := Vector3.ZERO               # onde o pulo/investida começou
var _fim_investida := Vector3.ZERO
var _acertou := false
var _pedra: Node3D
var _cast := 0
static var _proximo_cast := 700000      # único no jogo todo: o orçamento de dano do `CombatResolver` é por id de golpe
var _tempo_do_rugido := 0.0
var _morto := false


func _ready() -> void:
	_aviso = Aviso.new()
	_aviso.name = "AvisoVermelho"
	add_child(_aviso)
	_ap = _achar_ap(corpo._modelo)
	if _ap != null:
		for nome in LOOPS:
			if _ap.has_animation(nome):
				_ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	corpo.animador.exclusivo = true
	_tocar("idle")


func _achar_ap(n: Node) -> AnimationPlayer:
	if n == null:
		return null
	for filho in n.find_children("*", "AnimationPlayer", true, false):
		return filho as AnimationPlayer
	return null


func ativo() -> bool:
	return not golpe.is_empty()


func _tocar(nome: String, velocidade := 1.0, mistura := 0.15) -> void:
	if _ap == null or not _ap.has_animation(nome):
		return
	if _clipe == nome and _ap.is_playing() and absf(_ap.speed_scale - velocidade) < 0.01:
		return
	_clipe = nome
	_ap.play(nome, mistura, velocidade)


func _aviso_do(valor: float) -> float:
	return valor * (float(config.aviso_mais_curto_fase_2) if fase_da_luta == 2 else 1.0)


func _dano_de(valor: float) -> float:
	return valor * (float(config.dano_mais_forte_fase_2) if fase_da_luta == 2 else 1.0) * float(corpo.get_meta("fator_dano_nivel", 1.0))


func _e_servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


# ------------------------------------------------------------------ escolha
## Chamado pelo cérebro do animal a cada quadro de perseguição. Decide se começa um golpe.
func escolher(quem: Node3D, d: float) -> void:
	if ativo() or _intervalo > 0.0 or _morto or not _e_servidor():
		return
	_alvo = quem
	var opcoes: Array[String] = []
	if d <= 7.5:
		if _pronto("soco_chao"):
			opcoes.append("soco_chao")
		if _pronto("giro"):
			opcoes.append("giro")
	if d >= float(config.pulo_alcance_minimo) and d <= float(config.pulo_alcance_maximo) and _pronto("pulo_esmagar"):
		opcoes.append("pulo_esmagar")
	if d >= 5.0 and d <= 20.0 and _pronto("investida"):
		opcoes.append("investida")
	if d >= float(config.arremesso_alcance_minimo) and d <= float(config.arremesso_alcance_maximo) and _pronto("arremesso"):
		opcoes.append("arremesso")
	if opcoes.is_empty():
		return
	if opcoes.size() > 1 and opcoes.has(_ultimo):
		opcoes.erase(_ultimo)
	iniciar(opcoes[randi() % opcoes.size()], quem)


func _pronto(nome: String) -> bool:
	return float(_recargas.get(nome, 0.0)) <= 0.0


func iniciar(nome: String, quem: Node3D) -> void:
	_alvo = quem
	golpe = nome
	etapa = "aviso"
	t = 0.0
	_travado = false
	_acertou = false
	_ultimo = nome
	_proximo_cast += 1
	_cast = _proximo_cast
	corpo.estado = AnimalDaIlha.Estado.PERSEGUINDO
	var aviso := _duracao_do_aviso()
	var clipe := "pulo_esmagar" if nome == "pulo_esmagar" else nome
	match nome:
		"investida":
			_tocar("investida", 1.0, 0.1)
		"pulo_esmagar":
			_tocar("pulo_esmagar", float(CONTATO_DO_CLIPE["pulo_esmagar"]) / (aviso + float(config.pulo_voo)), 0.1)
		_:
			_tocar(clipe, float(CONTATO_DO_CLIPE.get(clipe, 1.0)) / aviso, 0.1)
	_mostrar_aviso()
	iniciou.emit(nome)


func _duracao_do_aviso() -> float:
	match golpe:
		"soco_chao": return _aviso_do(float(config.soco_aviso))
		"pulo_esmagar": return _aviso_do(float(config.pulo_aviso))
		"investida": return _aviso_do(float(config.investida_aviso))
		"giro": return _aviso_do(float(config.giro_aviso))
		"arremesso": return _aviso_do(float(config.arremesso_aviso))
		"furia": return float(config.furia_aviso)
	return 1.0


# ------------------------------------------------------------------ geometria (a mesma do desenho)
func _frente() -> Vector3:
	return Vector3(sin(corpo._yaw), 0.0, cos(corpo._yaw))


## Chão sob `p`: o raio ignora gente (jogador, pets, o próprio chefe), senão o "chão" seria a cabeça do jogador e o chefe pousaria em cima dele.
func _chao_em(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 6.0, p.z), Vector3(p.x, p.y - 30.0, p.z), 1)
	var fora: Array[RID] = [corpo.get_rid()]
	for grupo in ["player", "pets_historia", "enemy", "animais"]:
		for n in corpo.get_tree().get_nodes_in_group(grupo):
			if n is CollisionObject3D:
				fora.append((n as CollisionObject3D).get_rid())
	q.exclude = fora
	var h := corpo.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else Vector3(p.x, corpo.global_position.y, p.z)


func _pes() -> Vector3:
	return corpo.global_position


func _centro_do_soco() -> Vector3:
	return _chao_em(_pes() + _direcao * float(config.soco_alcance_do_centro))


func _mostrar_aviso() -> void:
	var pos := _pes()
	match golpe:
		"soco_chao":
			_direcao = _frente()
			_aviso.disco(_centro_do_soco(), float(config.soco_raio))
		"pulo_esmagar":
			_marca = _chao_em(_alvo.global_position)
			_aviso.disco(_marca, float(config.pulo_raio))
		"investida":
			_direcao = _frente()
			_aviso.faixa(pos, _chao_em(pos + _direcao * float(config.investida_comprimento)), float(config.investida_largura))
		"giro":
			_aviso.disco(pos, float(config.giro_raio))
		"arremesso":
			_marca = _chao_em(_alvo.global_position)
			_aviso.disco(_marca, float(config.arremesso_raio))
		"furia":
			_aviso.anel(pos, 0.0, float(config.furia_raio))


## O aviso acompanha o alvo até 65 % do tempo; daí a mira trava (dá tempo de sair).
func _seguir_alvo(delta: float, fracao: float) -> void:
	if _travado:
		return
	if fracao >= 0.65:
		_travado = true
		return
	if not _vivo(_alvo):
		return
	var para := _alvo.global_position - _pes()
	para.y = 0.0
	if para.length() > 0.1:
		corpo._yaw = lerp_angle(corpo._yaw, atan2(para.x, para.z), clampf(8.0 * delta, 0.0, 1.0))
		corpo._visual.rotation.y = corpo._yaw
	match golpe:
		"soco_chao":
			_direcao = _frente()
			_aviso.disco(_centro_do_soco(), float(config.soco_raio))
		"pulo_esmagar", "arremesso":
			_marca = _chao_em(_alvo.global_position)
			_aviso.disco(_marca, float(config.pulo_raio if golpe == "pulo_esmagar" else config.arremesso_raio))
		"investida":
			_direcao = _frente()
			_aviso.faixa(_pes(), _chao_em(_pes() + _direcao * float(config.investida_comprimento)), float(config.investida_largura))
	_aviso.preencher(fracao)


# ------------------------------------------------------------------ quadro a quadro
## `true` = o golpe controla o corpo neste quadro (o cérebro de perseguição fica de fora).
func atualizar(delta: float) -> bool:
	if _morto:
		return false
	if not _e_servidor():
		return false
	if not corpo.vivo():
		cancelar()
		return false
	for k in _recargas.keys():
		_recargas[k] = maxf(0.0, float(_recargas[k]) - delta)
	_intervalo = maxf(0.0, _intervalo - delta)
	_tempo_do_rugido = maxf(0.0, _tempo_do_rugido - delta)
	if golpe.is_empty():
		# Fase 2: ao cair abaixo do limiar, FÚRIA (uma vez); depois, o rugido volta de tempos em tempos.
		if fase_da_luta == 1 and corpo.health <= corpo.max_health * float(config.vida_da_fase_2) and corpo.em_combate():
			fase_da_luta = 2
			_comecar_furia()
			return true
		if fase_da_luta == 2 and _tempo_do_rugido <= 0.0 and corpo.em_combate() and _vivo(corpo.oponente):
			_comecar_furia()
			return true
		return false
	t += delta
	match etapa:
		"aviso":
			_parar(delta)
			var dur := _duracao_do_aviso()
			_seguir_alvo(delta, t / dur)
			_aviso.preencher(t / dur)
			if golpe == "furia":
				_aviso.preencher(t / dur)
			if t >= dur:
				_contato()
		"voo":
			_voar(delta)
		"investida":
			_investir(delta)
		"recuperacao":
			_parar(delta)
			if t >= _recuperacao():
				_finalizar()
	return true


## Fase 2: os olhos acendem em vermelho (a célula `olho_furia` do atlas, como material emissivo); `reiniciar` os apaga.
func _olhos_da_furia(ligar: bool) -> void:
	for mi in corpo._modelo.find_children("Olhos*", "MeshInstance3D", true, false):
		if ligar:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.93, 0.14, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.05)
			m.emission_energy_multiplier = 3.0
			(mi as MeshInstance3D).material_override = m
		else:
			(mi as MeshInstance3D).material_override = null


func _comecar_furia() -> void:
	_olhos_da_furia(true)
	_tempo_do_rugido = float(config.furia_recarga_do_rugido)
	_alvo = corpo.oponente if _vivo(corpo.oponente) else corpo.alvo
	golpe = "furia"
	etapa = "aviso"
	t = 0.0
	_travado = true
	_acertou = false
	_proximo_cast += 1
	_cast = _proximo_cast
	_tocar("furia", float(CONTATO_DO_CLIPE["furia"]) / float(config.furia_aviso), 0.1)
	_mostrar_aviso()
	iniciou.emit("furia")


func _contato() -> void:
	match golpe:
		"soco_chao":
			_aviso.estourar()
			_ferir(func(p: Vector3) -> bool: return Aviso.dentro_disco(p, _centro_do_soco(), float(config.soco_raio)), _dano_de(float(config.soco_dano)), 6.0, 7.0)
			_recargas["soco_chao"] = float(config.soco_recarga)
			etapa = "recuperacao"
			t = 0.0
		"giro":
			_aviso.estourar()
			_ferir(func(p: Vector3) -> bool: return Aviso.dentro_disco(p, _pes(), float(config.giro_raio)), _dano_de(float(config.giro_dano)), 11.0, 6.0)
			_recargas["giro"] = float(config.giro_recarga)
			etapa = "recuperacao"
			t = 0.0
		"furia":
			_chamar_macacos()
			_aviso.estourar()
			_ferir(func(p: Vector3) -> bool: return Aviso.dentro_disco(p, _pes(), float(config.furia_raio)), float(config.furia_dano) * float(corpo.get_meta("fator_dano_nivel", 1.0)), 13.0, 9.0)
			etapa = "recuperacao"
			t = 0.0
		"pulo_esmagar":
			etapa = "voo"
			t = 0.0
			_de = _pes()
		"investida":
			etapa = "investida"
			t = 0.0
			_de = _pes()
			var chao := _chao_em(_de + _direcao * float(config.investida_comprimento))
			_fim_investida = Vector3(chao.x, _de.y, chao.z)
		"arremesso":
			_soltar_pedra()
			etapa = "recuperacao"
			t = 0.0
			_recargas["arremesso"] = float(config.arremesso_recarga)


## O rugido ACORDA os macacos humanoides num raio de 70 m (a mesma "acordar por dano" da IA unificada): eles vêm para cima de quem está na arena.
const RAIO_DO_CHAMADO := 70.0


func _chamar_macacos() -> int:
	var chamados := 0
	for n in corpo.get_tree().get_nodes_in_group("enemy"):
		var no := n as Node3D
		if no == null or no == corpo or str(no.get("id_personagem")) != "macaco_humanoide":
			continue
		if no.global_position.distance_to(corpo.global_position) <= RAIO_DO_CHAMADO:
			IaUnificada.acordar_por_dano(no)
			chamados += 1
	return chamados


func _recuperacao() -> float:
	match golpe:
		"soco_chao": return float(config.soco_recuperacao)
		"pulo_esmagar": return float(config.pulo_recuperacao)
		"investida": return float(config.investida_recuperacao)
		"giro": return float(config.giro_recuperacao)
		"arremesso": return float(config.arremesso_recuperacao)
		"furia": return float(config.recuperacao_da_onda)
	return 1.0


func _finalizar() -> void:
	var feito := golpe
	golpe = ""
	etapa = ""
	_aviso.esconder()
	_intervalo = float(config.intervalo_fase_2 if fase_da_luta == 2 else config.intervalo)
	corpo.estado = AnimalDaIlha.Estado.PERSEGUINDO if corpo.em_combate() or _vivo(corpo.oponente) else corpo.estado
	_tocar("idle")
	terminou.emit(feito)


## Parado no chão, com gravidade.
func _parar(delta: float) -> void:
	corpo.velocity.x = 0.0
	corpo.velocity.z = 0.0
	corpo.velocity.y = maxf(corpo.velocity.y - GRAVIDADE * delta, -30.0)
	corpo.move_and_slide()


## O salto: arco do ponto de partida até o disco travado; o contato é o pouso.
func _voar(delta: float) -> void:
	var voo := float(config.pulo_voo)
	var f := clampf(t / voo, 0.0, 1.0)
	var alvo := Vector3(_marca.x, _marca.y, _marca.z)
	var plano := _de.lerp(alvo, f)
	var arco := 4.0 * 4.5 * f * (1.0 - f)                      # 4,5 m de altura no topo
	var y := lerpf(_de.y, alvo.y, f) + arco
	var anterior := corpo.global_position
	corpo.global_position = Vector3(plano.x, y, plano.z)
	corpo.velocity = (corpo.global_position - anterior) / maxf(delta, 0.001)
	var para := alvo - _de
	para.y = 0.0
	if para.length() > 0.1:
		corpo._yaw = atan2(para.x, para.z)
		corpo._visual.rotation.y = corpo._yaw
	if f >= 1.0:
		corpo.global_position = alvo
		corpo.velocity = Vector3.ZERO
		_aviso.estourar()
		_ferir(func(p: Vector3) -> bool: return Aviso.dentro_disco(p, _marca, float(config.pulo_raio)), _dano_de(float(config.pulo_dano)), 11.0, 9.0, _marca)
		_recargas["pulo_esmagar"] = float(config.pulo_recarga)
		etapa = "recuperacao"
		t = 0.0


## A investida: corre pela faixa travada; fere uma vez quem está dentro da faixa a cada passo; para na parede ou no fim.
func _investir(delta: float) -> void:
	var passo := _direcao * float(config.investida_velocidade)
	corpo.velocity.x = passo.x
	corpo.velocity.z = passo.z
	corpo.velocity.y = maxf(corpo.velocity.y - GRAVIDADE * delta, -30.0)
	corpo.move_and_slide()
	_ferir(func(p: Vector3) -> bool: return Aviso.dentro_faixa(p, _de, _pes() + _direcao * 2.5, float(config.investida_largura) + 1.0), _dano_de(float(config.investida_dano)), 12.0, 7.0, _de, true)
	var andou := Vector2(_pes().x - _de.x, _pes().z - _de.z).length()
	var parou := corpo.get_real_velocity().length() < 2.0 and t > 0.15
	if andou >= float(config.investida_comprimento) - 0.5 or parou:
		_aviso.estourar()
		_recargas["investida"] = float(config.investida_recarga)
		etapa = "recuperacao"
		t = 0.0


# ------------------------------------------------------------------ arremesso
func _soltar_pedra() -> void:
	_pedra = Node3D.new()
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(1.3, 1.1, 1.2)
	malha.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.46, 0.44)
	mat.roughness = 1.0
	malha.material_override = mat
	_pedra.add_child(malha)
	corpo.get_parent().add_child(_pedra)
	var origem := _pes() + Vector3.UP * 5.2 + _frente() * 0.8
	_pedra.global_position = origem
	var destino := _marca
	var voo := float(config.arremesso_voo)
	var tween := _pedra.create_tween()
	tween.tween_method(_mover_pedra.bind(origem, destino), 0.0, 1.0, voo)
	tween.tween_callback(_pedra_caiu)


func _mover_pedra(f: float, origem: Vector3, destino: Vector3) -> void:
	if not is_instance_valid(_pedra):
		return
	var p := origem.lerp(destino, f)
	p.y = lerpf(origem.y, destino.y, f) + 4.0 * 7.0 * f * (1.0 - f)
	_pedra.global_position = p
	_pedra.rotation += Vector3(0.18, 0.12, 0.0)


func _pedra_caiu() -> void:
	if is_instance_valid(_pedra):
		_pedra.queue_free()
	if _morto:
		return
	_aviso.estourar()
	_ferir(func(p: Vector3) -> bool: return Aviso.dentro_disco(p, _marca, float(config.arremesso_raio)), _dano_de(float(config.arremesso_dano)), 9.0, 8.0, _marca)


# ------------------------------------------------------------------ dano
func _ferir(dentro: Callable, dano: float, empurrao: float, subida: float, centro: Variant = null, uma_vez := false) -> void:
	if _acertou and uma_vez:
		return
	var origem: Vector3 = centro if centro is Vector3 else _pes()
	var alvos: Array[Node] = []
	alvos.append_array(corpo.get_tree().get_nodes_in_group("player"))
	alvos.append_array(corpo.get_tree().get_nodes_in_group("pets_historia"))
	for n in alvos:
		var a := n as Node3D
		if a == null or a == corpo or not _vivo(a) or not a.has_method("take_damage"):
			continue
		if not dentro.call(a.global_position):
			continue
		var para := Vector3(a.global_position.x - origem.x, 0.0, a.global_position.z - origem.z)
		if para.length() < 0.1:
			para = _frente()
		para = para.normalized()
		CombatResolver.aplicar(a, dano, _cast, dano, corpo.global_position, para * empurrao + Vector3.UP * subida, 0.4, 0.0, false, null, corpo)
		if uma_vez:
			_acertou = true


func _vivo(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var vida: Variant = n.get("health")
	return vida == null or float(vida) > 0.0


## Locomoção entre golpes: idle, andar, correr, pela velocidade real.
func locomocao() -> void:
	if ativo() or _morto:
		return
	var v := Vector2(corpo.velocity.x, corpo.velocity.z).length()
	if v > 5.0:
		_tocar("run", clampf(v / 6.0, 0.7, 1.6))
	elif v > 0.4:
		_tocar("walk", clampf(v / 1.8, 0.6, 1.6))
	else:
		_tocar("idle")


func reagir_ao_golpe() -> void:
	# Levar golpe NÃO interrompe aviso nem golpe (chefe): só pisca (o `take_damage` do animal faz isso). Parado e livre, toca o recuo.
	if golpe.is_empty() and _clipe in ["idle", "walk"]:
		_tocar("hurt", 1.0, 0.05)


func morreu() -> void:
	_morto = true
	cancelar()
	_tocar("morte", 1.0, 0.1)


func cancelar() -> void:
	golpe = ""
	etapa = ""
	if is_instance_valid(_aviso):
		_aviso.esconder()
	if is_instance_valid(_pedra):
		_pedra.queue_free()


func reiniciar() -> void:
	_morto = false
	fase_da_luta = 1
	_recargas.clear()
	_intervalo = 1.0
	_tempo_do_rugido = 0.0
	corpo.animador.exclusivo = true
	_olhos_da_furia(false)
	cancelar()
	_tocar("idle")
