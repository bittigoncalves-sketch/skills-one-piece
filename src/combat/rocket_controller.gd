extends Node
## Estado da Rocket no servidor. A autoridade do corpo NÃO decide trajetória/hit.
## As demais frutas continuam com seus controladores e protocolos existentes.
const HITBOX := preload("res://src/combat/rocket_hitbox.gd")
const VFX := preload("res://src/effects/rocket_vfx.gd")
const ID := "rocket"
const DURACAO_BUFF := 6.0
const FATOR_VELOCIDADE := 1.30
const FATOR_ACELERACAO := 1.60
const FATOR_SOCO := 1.35
const ALCANCE_X := 11.0
const ALCANCE_X_BUFF := 15.0
const VELOCIDADE_X := 32.0
const ACELERACAO_X := 180.0
const ALCANCE_C := 15.0
const RAIO_C := 1.4
const RAIO_V := 6.0
const INTERVALO_C := 0.12
const TEMPOS := {"Z": 0.44, "X": 0.92, "C": 1.36, "carga": 0.40,
	"subida": 0.45, "mira": 0.18, "queda": 1.30, "pouso": 0.48, "missil": 0.60,
	"bombardeio": 1.15, "mergulho": 1.40}
## MISSILE FIST (Modo História, 22/09/2026). Medido no vídeo do dono: o foguete aparece
## no braço, sai ~0,35 s depois do pedido e cruza até o alvo em 0,2–0,3 s (a ~20–25 m),
## com o corpo voltando ao repouso ~0,6 s depois do disparo.
const MISSIL_PREPARO := 0.35
const MISSIL_VELOCIDADE := 90.0
const MISSIL_RECUPERACAO := 0.25
## AIR STRIKE (Modo História). Medido no vídeo: pose de detonador ~0,5 s, os RETÍCULOS
## vermelhos aparecem no chão e ~0,2 s depois as explosões vêm em cadeia, do ponto mais
## perto para o mais longe, lançando o alvo para cima.
const BOMBARDEIO_PREPARO := 0.45
const BOMBARDEIO_AVISO := 0.20
const BOMBARDEIO_ENTRE_PONTOS := 0.08
const BOMBARDEIO_PONTOS := 3
## ROCKET CRASH (Modo História). Medido no vídeo: agacha ~0,1 s, decola, ~0,4 s no ar
## cruzando até o ponto mirado e mergulha; o impacto levanta um pilar de chamas e a
## câmera dá um close curto (exceção aprovada pelo dono).
const MERGULHO_PREPARO := 0.12
const MERGULHO_NO_AR := 0.40
const MERGULHO_ALTURA := 6.0
const MERGULHO_CLOSE := 0.20
## Kit da ARENA (o do Codex). No Modo História quem manda é a ficha do perfil.
## Onde cada golpe cai: a MESMA conta do indicador de mira (src/player/mira_de_fruta.gd).
const MIRA := preload("res://src/combat/mira_de_rocket.gd")
const KIT_DA_ARENA := {"Z": "Z", "X": "X", "C": "C", "V": "carga"}

var ator: CharacterBody3D
var fase := ""
var tempo := 0.0
var buff := 0.0
var token := 0
var direcao := Vector3.FORWARD
var posicao := Vector3.ZERO
var _velocidade := Vector3.ZERO
var _percorrido := 0.0
var _disparos := 0
var _atingiu := false
var _spec: DamageSpec
var _spec_final: DamageSpec
var _fx: Node3D
var _fx_cauda := 0.0
var _envio := 0.0
var _sequencia := 0
var _ultima_sequencia := -1
var _ultimo_token := 0
var _pendente_ate := 0
var _fim_x := 0.0
var _limite_x := ALCANCE_X
var _ritmo_z := 1.0
var _zona: Node3D
var _posicao_recebida := Vector3.ZERO
var _rpc_evento := 0
var _ultimo_evento := -1
var _cancelamento_pendente := false
var _tecnica: TecnicaDeFruta = null
var _missil_pos := Vector3.ZERO
var _missil_vivo := false
var _alvos_do_bombardeio: Array[Vector3] = []
var _alvo_do_mergulho := Vector3.INF
var _de_onde_saiu := Vector3.ZERO

func _ready() -> void:
	ator = get_parent() as CharacterBody3D
	# Filho criado em runtime: não herdar autoridade do cliente sobre o corpo.
	set_multiplayer_authority(1)
	set_physics_process(false)

func servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func ocupado() -> bool:
	return fase != ""

func fator_velocidade() -> float:
	return FATOR_VELOCIDADE if buff > 0 else 1.0

func fator_aceleracao() -> float:
	return FATOR_ACELERACAO if buff > 0 else 1.0

func disponivel() -> bool:
	return is_instance_valid(ator) and ator.current_fruit_id == ID \
		and ator.combat_mode == "fruit" and ator.health > 0.0 \
		and not ator._eliminado and not ator.is_suppressed \
		and not ator.fruta_bloqueada_por_dano() \
		and not ator.get_meta("is_frozen", false) \
		and not ator.get_meta("in_black_hole", false) \
		and not ator.get_meta("in_kurouzu", false) \
		and not ator.get_meta("in_vortex", false)

## As teclas que ESTE modo tem. Com perfil (Modo História) vale a ficha — e a ficha da
## Rocket lá não tem V, porque a fruta do vídeo de referência não tem V.
func slot_permitido(slot: String) -> bool:
	var perfil: PerfilDeFrutas = ator.perfil_de_frutas if is_instance_valid(ator) else null
	if perfil != null and perfil.fruta == ID:
		return perfil.tem(slot)
	return slot in ["Z", "X", "C", "V"]

func pedir(slot: String, identidade: int) -> void:
	if not ator._is_authority or not disponivel() or ocupado(): return
	if not slot_permitido(slot): return
	if Time.get_ticks_msec() < _pendente_ate: return
	if slot == "V" and buff > 0: return
	if ator.energy < ator.custo_de_energia_do_cast(slot): return
	var mira: Dictionary = ator.mira_do_cast()
	_pendente_ate = Time.get_ticks_msec() + 1500
	ator.pedir_cast_no_servidor(slot, mira.aim, mira.origem, 0.0, identidade)

func autorizar(slot: String, mira: Vector3, origem: Vector3, identidade: int) -> bool:
	if not servidor() or not disponivel() or ocupado(): return false
	if not slot_permitido(slot): return false
	if not mira.is_finite() or mira.length_squared() < 0.001: return false
	if not origem.is_finite() or origem.distance_to(ator.global_position) > 4.5: return false
	if identidade <= _ultimo_token or identidade <= 0: return false
	if slot == "V" and buff > 0.0: return false
	if ator.get_meta("is_casting", false) or not ator.corpo_livre_para_golpe(): return false
	var chave := "fruit/rocket/" + slot
	var agora := Time.get_ticks_msec()
	if agora < int(ator._server_cast_next_ms.get(chave, 0)): return false
	if float(ator._fruit_cooldowns.get(slot, 0)) > 0: return false
	if ator.energy < ator.custo_de_energia_do_cast(slot): return false
	_ultimo_token = identidade
	# Custo e recarga saem do perfil do MODO (`Player.perfil_de_frutas`): a arena cobra
	# 180 de 4.096, a história cobra 2 de 10. Sem perfil, nada muda.
	ator._server_cast_next_ms[chave] = agora + int(ator.recarga_do_cast(slot) * 1000)
	ator.gastar_energia(ator.custo_de_energia_do_cast(slot))
	if ator._is_authority: ator.trigger_skill_cooldown(slot)
	return true

func iniciar(slot: String, mira: Vector3, identidade: int) -> void:
	_pendente_ate = 0
	if not servidor(): return # início/fases vêm do snapshot confiável, nunca do dono do corpo
	token = identidade
	direcao = mira.normalized()
	posicao = ator.global_position
	_ritmo_z = FATOR_SOCO if buff > 0 else 1.0
	_limite_x = ALCANCE_X_BUFF if buff > 0 else ALCANCE_X
	_tecnica = _ficha(slot)
	_spec = _nova_spec(slot)
	if slot == "V":
		_spec_final = _spec
	_mudar_fase(_comportamento(slot))
	_publicar()

## A ficha desta tecla no modo atual (nula na arena: lá os números são do `Balance`).
func _ficha(slot: String) -> TecnicaDeFruta:
	var perfil: PerfilDeFrutas = ator.perfil_de_frutas if is_instance_valid(ator) else null
	return perfil.tecnica(slot) if perfil != null and perfil.fruta == ID else null


## O que a tecla FAZ neste modo. Na arena, o kit do Codex; no Modo História, o
## comportamento escrito na ficha — a mesma tecla pode ser outro golpe.
func _comportamento(slot: String) -> String:
	if _tecnica != null and not _tecnica.comportamento.is_empty():
		return _tecnica.comportamento
	return KIT_DA_ARENA.get(slot, slot)


func _nova_spec(slot: String) -> DamageSpec:
	if _tecnica != null:
		# Escala da história (inimigo 250 de vida), não a da arena (2.048); + o bônus das
		# técnicas da história (`Balance.HISTORIA_TECNICAS`, 23/10/2026).
		var dano := _tecnica.dano * Balance.HISTORIA_TECNICAS
		return DamageSpec.criar(DamageSpec.Tipo.UNICO, dano, dano).para_cast()
	return Balance.novo(ID, slot)


func _mudar_fase(nova: String) -> void:
	fase = nova
	tempo = 0.0
	_missil_vivo = false
	_alvos_do_bombardeio.clear()
	_alvo_do_mergulho = Vector3.INF
	_disparos = 0
	_atingiu = false
	_fim_x = 0.0
	_percorrido = 0.0
	_velocidade = Vector3.ZERO
	_pose()
	if fase != "" or buff > 0: _garantir_fx()
	_fx_cauda = 0.8

func _garantir_fx() -> void:
	if is_instance_valid(_fx): return
	_fx = VFX.new()
	ator.get_tree().current_scene.add_child(_fx)

func _pose() -> void:
	var pose := ""
	if fase != "": pose = "rocket_" + fase.to_lower()
	ator.set_meta("custom_pose", pose)
	ator.set_meta("rocket_pose_t", clampf(tempo / _duracao(), 0, 1))
	ator.set_meta("rocket_pitch", asin(clampf(direcao.y, -1, 1)))
	ator.set_meta("is_casting", ocupado())
	ator.set_meta("active_skill", fase if fase in ["Z", "X", "C"] else "V" if ocupado() else "")

func _duracao() -> float:
	return float(TEMPOS.get(fase, 1.0)) / (_ritmo_z if fase == "Z" else 1.0)

## Chamado antes do caminho local/remoto do Player. Só consome o quadro durante
## compromisso físico; buff livre usa a locomoção normal com fatores compostos.
func tick(delta: float) -> bool:
	if fase == "" and buff <= 0 and not is_instance_valid(_fx): return false
	if (fase != "" or buff > 0) and not disponivel():
		cancelar()
	if servidor():
		if buff > 0:
			buff = maxf(0, buff - delta)
			if buff <= 0:
				_limpar_zona()
				if _spec != null and _spec != _spec_final: CombatResolver.encerrar(_spec.cast_id)
				_spec = _spec_final
				posicao = ator.global_position
				ator._melee.cancelar_golpe()
				ator._fsm.transition_to("Idle")
				_mudar_fase("subida")
		if fase != "":
			# Synchronizer do cliente não consegue reposicionar a trajetória da skill.
			ator.global_position = posicao
			tempo += delta
			_avancar(delta)
		_envio -= delta
		if _envio <= 0 and (fase != "" or buff > 0):
			_envio = 0.05
			_publicar()
	else:
		if fase != "":
			tempo += delta
			ator.global_position = ator.global_position.lerp(_posicao_recebida, 1.0 - exp(-35.0 * delta))
	# Resfriamentos/vida precisam continuar durante uma ação que desvia locomoção.
	if ocupado():
		if ator._is_authority:
			ator._etapa_estado_de_combate(delta)
			ator._cast.tick_silencio(delta)
		elif servidor() and ator._fruit_damage_lock_timer > 0:
			ator._fruit_damage_lock_timer = maxf(0, ator._fruit_damage_lock_timer - delta)
		_pose()
		_apresentar(delta)
		ator.net_velocity = _velocidade
		ator.net_on_floor = ator.is_on_floor()
	if is_instance_valid(_fx):
		_fx.atualizar(delta, ator, str(ator.get_meta("custom_pose", "")))
		if not ocupado() and buff <= 0:
			_fx_cauda -= delta
			if _fx_cauda <= 0:
				_fx.queue_free()
				_fx = null
	return ocupado()

func _avancar(delta: float) -> void:
	match fase:
		"Z":
			if tempo >= 0.12 / _ritmo_z and not _atingiu:
				_atingiu = true
				var de := posicao + Vector3.UP * 0.55
				var fim := _raio(de, de + direcao * 2.8)
				var ate: Vector3 = fim.get("position", de + direcao * 2.8)
				_zona_em(ate - direcao * 0.05, 0.65, 5.0, 0.16, de, direcao)
				_zona._varrer_caminho(de, ate)
				_evento(de, ate, 0.7, 0, -direcao)
			_gravidade(delta)
		"X":
			if tempo >= 0.18 and _fim_x == 0:
				_velocidade = _velocidade.move_toward(direcao * VELOCIDADE_X, ACELERACAO_X * delta)
				var antes := posicao
				var colisao := _mover(_velocidade * delta)
				_percorrido += antes.distance_to(posicao)
				if colisao != null or _percorrido >= _limite_x:
					_fim_x = tempo
					var ponto := posicao + direcao * 0.65
					if colisao != null: ponto = colisao.get_position() + colisao.get_normal() * 0.08
					_zona_em(ponto, 1.15, 12.0, 0.24, posicao, direcao)
					_evento(antes, ponto, 1.5 if buff > 0 else 1.05, 1)
					_velocidade = Vector3.ZERO
				else:
					# Varre inimigos que não bloqueiam fisicamente o corpo.
					var q := _raio(antes, posicao + direcao * 0.7)
					if q.has("collider") and q.collider.has_method("take_damage"):
						_fim_x = tempo
						_zona_em(q.position, 1.15, 12, 0.24, antes, direcao)
						_evento(antes, q.position, 1.15, 1)
			elif _fim_x > 0:
				_gravidade(delta)
			if _fim_x > 0 and tempo >= _fim_x + 0.22:
				_terminar_acao()
				return
		"C":
			while _disparos < 8 and tempo >= 0.18 + _disparos * INTERVALO_C:
				var de := posicao + Vector3.UP * 0.65
				var lado := direcao.cross(Vector3.UP).normalized()
				if lado.length_squared() < 0.01: lado = Vector3.RIGHT
				var espalho: float = [-0.6, 0.25, 0.55, -0.25, 0.0, -0.45, 0.4, 0.0][_disparos]
				var destino := de + direcao * ALCANCE_C + lado * espalho
				var hit := _raio(de, destino)
				var at: Vector3 = hit.get("position", destino)
				var normal: Vector3 = hit.get("normal", -direcao)
				_zona_em(at + normal * 0.06, RAIO_C, 1.5, 0.08, at + normal * 0.1)
				_evento(de, at, RAIO_C * (1.25 if buff > 0 else 1.0), _disparos, normal)
				_disparos += 1
		"missil":
			if tempo >= MISSIL_PREPARO and not _atingiu:
				if not _missil_vivo:
					_missil_vivo = true
					_missil_pos = posicao + Vector3.UP * 1.25 + direcao * 0.5
					_percorrido = 0.0
					# Clarão do disparo e, logo depois, o FOGUETE em si cruzando até o
					# fim do alcance (some sozinho ou quando a explosão dele chega).
					_evento(posicao + Vector3.UP * 1.2, _missil_pos, 0.45, 0, -direcao)
					var alcance_z: float = _tecnica.alcance if _tecnica != null else 40.0
					_evento(_missil_pos, _missil_pos + direcao * alcance_z, 0.0, 0,
							-direcao, FX_MISSIL)
				_voar_missil(delta)
			_gravidade(delta)
			if _atingiu and tempo >= _fim_x + MISSIL_RECUPERACAO:
				_terminar_acao()
				return
		"bombardeio":
			if tempo >= BOMBARDEIO_PREPARO and _alvos_do_bombardeio.is_empty():
				_marcar_bombardeio()
			while _disparos < _alvos_do_bombardeio.size() \
					and tempo >= BOMBARDEIO_PREPARO + BOMBARDEIO_AVISO + _disparos * BOMBARDEIO_ENTRE_PONTOS:
				var ponto: Vector3 = _alvos_do_bombardeio[_disparos]
				var raio_b: float = _tecnica.raio if _tecnica != null else 2.0
				_dano_em_area(ponto, raio_b, true)
				_evento(ponto + Vector3.UP * 12.0, ponto, raio_b, _disparos + 1, Vector3.UP)
				_disparos += 1
			_gravidade(delta)
		"mergulho":
			if tempo < MERGULHO_PREPARO:
				_gravidade(delta)
			elif tempo < MERGULHO_PREPARO + MERGULHO_NO_AR:
				if _alvo_do_mergulho == Vector3.INF:
					_alvo_do_mergulho = _ponto_mirado(_tecnica.alcance if _tecnica != null else 18.0)
					_de_onde_saiu = posicao
					_evento(posicao, posicao + Vector3.UP * 2.0, 0.6, 0, Vector3.UP)
				# Arco: sobe, cruza e desce no ponto — um caminho só, sem teleporte.
				var u := (tempo - MERGULHO_PREPARO) / MERGULHO_NO_AR
				var plano := _de_onde_saiu.lerp(_alvo_do_mergulho, u)
				var altura := sin(PI * u) * MERGULHO_ALTURA
				ator.global_position = plano + Vector3.UP * altura
				posicao = ator.global_position
			elif not _atingiu:
				_atingiu = true
				_fim_x = tempo
				var raio_m: float = _tecnica.raio if _tecnica != null else 3.5
				ator.global_position = _alvo_do_mergulho
				posicao = ator.global_position
				_dano_em_area(_alvo_do_mergulho, raio_m)
				_evento(_alvo_do_mergulho + Vector3.UP * 3.0, _alvo_do_mergulho, raio_m, 9,
						Vector3.UP, FX_PILAR)
				if ator._is_authority and ator.get("_camera") != null:
					# Close curto: exceção que o dono aprovou depois do vídeo, só na câmera
					# de quem deu o golpe.
					ator._camera.aproximar(0.45, MERGULHO_CLOSE)
			else:
				_gravidade(delta)
		"carga":
			if tempo >= _duracao():
				buff = DURACAO_BUFF
				_mudar_fase("")
				_publicar()
				return
		"subida":
			_mover(Vector3.UP * 18.0 * delta)
			if tempo >= _duracao():
				_mudar_fase("mira")
				_publicar()
				return
		"mira":
			if tempo >= _duracao():
				_mudar_fase("queda")
				_publicar()
				return
		"queda":
			# Solo antecipado; corpos inimigos não são solo. O corpo completo ainda
			# varre o trajeto para respeitar quinas, inclinação e plataformas finas.
			var piso := _solo(posicao, posicao + Vector3.DOWN * (65.0 * delta + 1.2))
			var colisao := _mover(Vector3.DOWN * 65.0 * delta)
			if colisao != null and colisao.get_normal().y > 0.35 and not piso.is_empty():
				var at: Vector3 = piso.position + piso.normal * 0.12
				_zona_em(at, RAIO_V, 20.0, 0.5, at)
				_evento(posicao, at, RAIO_V, 7, piso.normal)
				_mudar_fase("pouso")
				_publicar()
				return
		"pouso": _gravidade(delta)
	if fase != "X" and tempo >= _duracao(): _terminar_acao()
	# Sem alvo/colisão, X encerra ao alcançar limite; teto temporal só de proteção.
	if fase == "X" and tempo > 1.6: _terminar_acao()

## O foguete do Z: sai do braço e cruza a distância quase reto. Alcance e raio vêm da
## ficha; sem ficha (arena) este comportamento nem é usado.
func _voar_missil(delta: float) -> void:
	var de := _missil_pos
	var ate := de + direcao * MISSIL_VELOCIDADE * delta
	var alcance: float = _tecnica.alcance if _tecnica != null else 40.0
	var hit := _raio(de, ate)
	_percorrido += de.distance_to(ate)
	if not hit.is_empty():
		_explodir(hit.position, hit.get("normal", -direcao))
	elif _percorrido >= alcance:
		_explodir(ate, -direcao)
	else:
		_missil_pos = ate
		if is_instance_valid(_fx):
			_fx.traco(de, ate, 0)


func _explodir(at: Vector3, normal: Vector3) -> void:
	_missil_vivo = false
	_atingiu = true
	_fim_x = tempo
	var raio: float = _tecnica.raio if _tecnica != null else 2.0
	_dano_em_area(at, raio)
	_evento(_missil_pos, at, raio, 1, normal)


## Explosão COM DEFESA: quem está de guarda no cone do combate direcional segura o
## golpe — postura e dano reduzido — e a decisão é tomada ANTES do funil de dano. Por
## isso aqui não entra `DamageZone`: ela grava derrubada e emite `hit_landed` antes de
## qualquer defesa (achado M1 do docs/PLANO_COMBATE_HISTORIA.md).
func _dano_em_area(at: Vector3, raio: float, para_cima := false) -> void:
	if not servidor() or _spec == null or not is_instance_valid(ator):
		return
	var forma := SphereShape3D.new()
	forma.radius = raio
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, at)
	consulta.collision_mask = 15
	consulta.exclude = [ator.get_rid()]
	var perfil: PerfilDeFrutas = ator.perfil_de_frutas
	var fator_bloqueio: float = perfil.dano_bloqueado if perfil != null else 1.0
	var postura: float = _tecnica.dano_de_postura if _tecnica != null else 0.0
	var empurrao: float = _tecnica.empurrao if _tecnica != null else 5.0
	var hitstun: float = _tecnica.hitstun if _tecnica != null else 0.3
	for resultado in ator.get_world_3d().direct_space_state.intersect_shape(consulta, 16):
		var alvo: Node = resultado.collider
		if alvo == null or not alvo.has_method("take_damage") or alvo == ator:
			continue
		var dano: float = _spec.dano
		var defensor = alvo.get("combate_direcional")
		if defensor != null and _tecnica != null:
			match ResolucaoDeContato.resolver_tecnica(at, defensor, postura):
				ResolucaoDeContato.Resultado.BLOQUEIO:
					defensor.receber_bloqueio_de_postura(postura)
					dano *= fator_bloqueio
				ResolucaoDeContato.Resultado.QUEBRA_DE_GUARDA:
					defensor.quebrar_guarda(null)
		var rumo: Vector3 = alvo.global_position - at
		rumo.y = 0.0
		rumo = rumo.normalized() if rumo.length_squared() > 0.001 else direcao
		# O Air Strike LANÇA PARA CIMA (é o que o vídeo mostra); o resto empurra no plano.
		var impulso := (rumo * 0.4 + Vector3.UP) * empurrao if para_cima else rumo * empurrao
		# `ator` entra como AUTOR, não como `corpo_a_corpo_de`: fruta não recebe o bônus de Força
		# (+3,0 somado DEPOIS da guarda — medido 16,5 em vez de 13,5 no test_fruta_rocket_historia).
		CombatResolver.aplicar(alvo, dano, _spec.cast_id, _spec.teto, at,
			impulso, hitstun, 0.0, false, null, ator)


## Os pontos do Air Strike: em LINHA à frente do corpo, do mais perto ao mais longe,
## ENCOSTADOS e a distância FIXA (decisão do dono, 30/09/2026 — antes se espalhavam por
## 25 m e deixavam ~4 m de chão sem dano entre um e outro). A conta mora em
## `mira_de_rocket.gd`. O retículo avisa `BOMBARDEIO_AVISO` antes da explosão.
func _marcar_bombardeio() -> void:
	var raio_b: float = _tecnica.raio if _tecnica != null else 2.0
	for ponto in MIRA.pontos_do_bombardeio(ator.get_world_3d(), posicao, direcao,
			raio_b, BOMBARDEIO_PONTOS, _fora()):
		_alvos_do_bombardeio.append(ponto)
		# O aviso: retículo (círculo com ponto) no chão, do tamanho do estrago que vem.
		_evento(ponto, ponto, raio_b, 0, Vector3.UP, FX_RETICULO)


## O ponto do chão para onde a mira aponta, limitado por `alcance` (o salto do C).
func _ponto_mirado(alcance: float) -> Vector3:
	return MIRA.ponto_mirado(ator.get_world_3d(), posicao + Vector3.UP * 1.2, direcao,
			alcance, _fora())


func _mover(deslocamento: Vector3) -> KinematicCollision3D:
	var colisao := ator.move_and_collide(deslocamento)
	posicao = ator.global_position
	return colisao

func _gravidade(delta: float) -> void:
	_velocidade.y -= float(ator.GRAVITY) * delta
	var colisao := _mover(Vector3.UP * _velocidade.y * delta)
	if colisao != null: _velocidade = Vector3.ZERO

func _fora() -> Array[RID]:
	var lista: Array[RID] = [ator.get_rid()]
	return lista

func _raio(de: Vector3, ate: Vector3, excluir: Array[RID] = []) -> Dictionary:
	var fora := _fora()
	fora.append_array(excluir)
	return MIRA.raio(ator.get_world_3d(), de, ate, fora)

func _solo(de: Vector3, ate: Vector3) -> Dictionary:
	return MIRA.solo(ator.get_world_3d(), de, ate, _fora())

func _zona_em(at: Vector3, raio: float, kb: float, stun: float,
		origem: Vector3, direcao_kb: Vector3 = Vector3.ZERO) -> void:
	if not servidor() or _spec == null: return
	var zona := HITBOX.new()
	add_child(zona)
	zona.global_position = at
	zona.configurar(ator, _spec, raio, kb, stun, origem, direcao_kb)
	_zona = zona

func _limpar_zona() -> void:
	for filho in get_children():
		if filho.is_in_group("rocket_hitbox"): filho.queue_free()
	_zona = null

func _terminar_acao() -> void:
	_limpar_zona()
	if _spec != null and _spec != _spec_final: CombatResolver.encerrar(_spec.cast_id)
	if buff <= 0 and _spec_final != null:
		CombatResolver.encerrar(_spec_final.cast_id)
		_spec_final = null
	_spec = null
	_mudar_fase("")
	_publicar()

func cancelar() -> void:
	if not ocupado() and buff <= 0: return
	if not servidor():
		if ator._is_authority and not _cancelamento_pendente:
			_cancelamento_pendente = true
			_pedir_cancelamento.rpc_id(1)
		return
	buff = 0
	_terminar_acao()
	ator.velocity = Vector3.ZERO

@rpc("any_peer", "reliable")
func _pedir_cancelamento() -> void:
	if servidor() and multiplayer.get_remote_sender_id() == ator.get_multiplayer_authority(): cancelar()

func _publicar() -> void:
	_sequencia += 1
	var dados := {"seq": _sequencia, "token": token, "fase": fase, "tempo": tempo,
		"buff": buff, "pos": posicao if ocupado() else ator.global_position,
		"dir": direcao, "vel": _velocidade, "ritmo": _ritmo_z}
	if multiplayer.has_multiplayer_peer(): _receber.rpc(dados)

@rpc("authority", "call_remote", "reliable")
func _receber(dados: Dictionary) -> void:
	if servidor() or int(dados.seq) <= _ultima_sequencia: return
	_ultima_sequencia = int(dados.seq)
	if str(dados.fase) == "": _cancelamento_pendente = false
	var estava_ocupado := ocupado()
	token = int(dados.token)
	fase = str(dados.fase)
	tempo = float(dados.tempo)
	buff = float(dados.buff)
	direcao = dados.dir
	_velocidade = dados.vel
	_ritmo_z = float(dados.ritmo)
	_posicao_recebida = dados.pos
	if ocupado() or estava_ocupado: ator.global_position = dados.pos
	_pose()
	_garantir_fx()
	_fx_cauda = 0.8

## O que o evento DESENHA. Um tipo por linguagem visual do vídeo; o 0 é a explosão de
## sempre, e os outros três não existiam — o aviso do X e o pilar do C saíam como
## explosão genérica, e o foguete do Z não tinha objeto nenhum.
enum { FX_EXPLOSAO, FX_RETICULO, FX_PILAR, FX_MISSIL }

func _evento(de: Vector3, ate: Vector3, raio: float, indice: int,
		normal: Vector3 = Vector3.UP, tipo: int = FX_EXPLOSAO) -> void:
	_rpc_evento += 1
	if multiplayer.has_multiplayer_peer():
		_efeito.rpc(_rpc_evento, de, ate, raio, indice, normal, tipo)
	else: _efeito(_rpc_evento, de, ate, raio, indice, normal, tipo)

@rpc("authority", "call_local", "reliable")
func _efeito(seq: int, de: Vector3, ate: Vector3, raio: float, indice: int,
		normal: Vector3, tipo: int = FX_EXPLOSAO) -> void:
	if seq <= _ultimo_evento: return
	_ultimo_evento = seq
	_garantir_fx()
	match tipo:
		FX_RETICULO:
			# Só avisa. Sem tremor, sem estrago: o estrago vem depois, no ponto marcado.
			_fx.reticulo(ate, BOMBARDEIO_AVISO, raio, normal)
			return
		FX_MISSIL:
			_fx.missil_disparar(de, ate, MISSIL_VELOCIDADE)
			return
		FX_PILAR:
			_fx.pilar(ate, raio)
	_fx.impacto(ate, raio, normal)
	_fx.traco(de, ate, indice)
	if ator._is_authority:
		# Só tremor: o dono decidiu que o jogo não tem soco de FOV (distorção de lente).
		ator.add_camera_shake(0.5 if raio > 3 else 0.12)

func _apresentar(delta: float) -> void:
	var modelo: Node3D = ator.get("_char_model")
	if modelo != null and Vector2(direcao.x, direcao.z).length_squared() > 0.001:
		modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(-direcao.x, -direcao.z), 1-exp(-25*delta))
	if ator.get("_proc_anim") != null:
		ator._proc_anim.update(_velocidade, true, false, delta, 0, false,
			false, "", "", false, 0, 0, -1, 0, str(ator.get_meta("custom_pose", "")))

func _exit_tree() -> void:
	if is_instance_valid(_fx): _fx.queue_free()
	if _spec != null: CombatResolver.encerrar(_spec.cast_id)
	if _spec_final != null: CombatResolver.encerrar(_spec_final.cast_id)
