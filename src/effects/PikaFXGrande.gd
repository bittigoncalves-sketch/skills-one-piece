class_name PikaFXGrande
extends RefCounted
const PikaPoses = preload("res://src/anim/PikaPoses.gd")
## C/V da Pika Pika. A densidade visual e a quantidade de hitboxes são
## deliberadamente separadas: o brilho comunica escala; DamageSpec limita dano.

const COR_NUCLEO := Color(1.0, 0.99, 0.86, 1.0)
const COR_OURO := Color(1.0, 0.78, 0.16, 0.92)

const C_PREPARO := 0.60
const C_CARGA_FIM := 1.00
const C_RAJA_INICIO := 1.00
const C_RAJA_FIM := 2.50
const C_TOTAL := 3.70
const C_INTERVALO := 0.050
const C_POR_PULSO := 3
const C_VELOCIDADE := 92.0
const C_ALCANCE := 46.0
const C_RASTRO := 2.4
const C_TELEPORTE_ALTURA := 7.0
const C_ALCANCE_ALVO := 70.0

# ⚠️ A ABERTURA DO LEQUE, EM UM LUGAR SÓ. Estes dois números eram literais soltos
# dentro do `_direcao()`, e agora a hitbox do C é traçada a partir deles — o
# volume de dano nasce dos MESMOS cantos que os fragmentos desenham. Se virarem
# duas cópias, a hitbox passa a mentir sobre o visual no dia em que alguém
# ajustar um e esquecer o outro; por isso os dois usos leem daqui.
const C_ABERTURA_H := 0.72       # desvio lateral máximo somado ao `fwd` unitário
const C_ABERTURA_V := 0.26       # idem, vertical
# Tique da zona sustentada. Igual ao `C_INTERVALO` de propósito: é a mesma
# cadência dos pulsos de fragmento, então o dano por segundo continua sendo o
# que a tabela sempre descreveu.
const C_TIQUE := C_INTERVALO
const C_PARALISIA := 0.45        # renovada durante a barragem; solta ao fim dela
const C_PARALISIA_A_CADA := 4    # tiques entre renovações (0,20 s)

# ⚠️ TEMPORÁRIO, A PEDIDO DO DONO (2026-09-06): desenha a hitbox do C em vermelho
# transparente para conferência em tela. Vira `false` quando não for mais preciso
# ver — nada além do desenho depende desta constante.
const C_MOSTRAR_HITBOX := true

const V_ATIVACAO_FIM := 1.00
const V_CHUVA_INICIO := 2.00
const V_MAX_INICIO := 11.00
const V_CHUVA_FIM := 12.00
const V_TOTAL := 14.00
const V_RAIO_ARENA := 44.0
const V_ALTURA := 28.0

# Vários jogadores podem manter uma Chuva de Luz ao mesmo tempo. O céu usa a
# maior intensidade ativa e só volta ao azul quando o último controlador sair.
static var _v_ceu_intensidades: Dictionary = {}


static func yasakani(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, spec: DamageSpec, cast_token: int = 0) -> void:
	if not _mundo_pronto(world,
			yasakani.bind(world, origin, dir, damage, caster, spec, cast_token)):
		return
	var alvo_dir := _teleportar_e_alvejar(world, caster, dir)
	var ctrl := YasakaniController.new()
	ctrl.caster = caster
	ctrl.spec = spec if spec != null else DamageSpec.avulso(damage)
	ctrl.fwd = alvo_dir
	ctrl.cast_token = cast_token
	world.add_child(ctrl)
	ctrl.global_position = ((caster as Node3D).global_position + Vector3(0, 1.22, 0)
		if caster is Node3D else origin)


static func chuva_de_luz(world: Node, origin: Vector3, damage: float,
		caster: Node, spec: DamageSpec) -> void:
	if not _mundo_pronto(world, chuva_de_luz.bind(world, origin, damage, caster, spec)):
		return
	var ctrl := ChuvaDeLuzController.new()
	ctrl.caster = caster
	ctrl.spec = spec if spec != null else DamageSpec.avulso(damage)
	ctrl.centro_global = Vector3(origin.x, 0.0, origin.z)
	world.add_child(ctrl)
	ctrl.global_position = ctrl.centro_global


static func _mundo_pronto(world: Node, repetir: Callable) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	if world.is_inside_tree():
		return true
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore != null:
		arvore.process_frame.connect(repetir, CONNECT_ONE_SHOT)
	return false


static func _atualizar_ceu_dourado(dono: Node3D, intensidade: float) -> void:
	if not is_instance_valid(dono) or dono.get_world_3d() == null:
		return
	_v_ceu_intensidades[dono.get_instance_id()] = clampf(intensidade, 0.0, 1.0)
	_aplicar_ceu_dourado(dono)


static func _remover_ceu_dourado(dono: Node3D) -> void:
	if not is_instance_valid(dono):
		return
	_v_ceu_intensidades.erase(dono.get_instance_id())
	_aplicar_ceu_dourado(dono)


static func _aplicar_ceu_dourado(dono: Node3D) -> void:
	var mundo := dono.get_world_3d()
	if mundo == null or mundo.environment == null or mundo.environment.sky == null:
		return
	var material := mundo.environment.sky.sky_material
	if not (material is ShaderMaterial):
		return
	var maior := 0.0
	for valor in _v_ceu_intensidades.values():
		maior = maxf(maior, float(valor))
	(material as ShaderMaterial).set_shader_parameter("pika_v_dourado", maior)


static func _teleportar_e_alvejar(world: Node, caster: Node,
		direcao: Vector3) -> Vector3:
	var fallback := direcao.normalized() if direcao.length_squared() > 0.01 else Vector3.FORWARD
	if not (caster is Node3D) or not is_instance_valid(caster):
		return fallback
	var corpo := caster as Node3D
	var antes := corpo.global_position
	corpo.global_position += Vector3.UP * C_TELEPORTE_ALTURA
	if corpo is CharacterBody3D:
		(corpo as CharacterBody3D).velocity = Vector3.ZERO
	_efeito_teleporte(world, antes, corpo.global_position)

	var melhor: Node3D = null
	var distancia := C_ALCANCE_ALVO
	var arvore := corpo.get_tree()
	if arvore != null:
		for grupo in ["enemy", "player"]:
			for candidato in arvore.get_nodes_in_group(grupo):
				if candidato == caster or not (candidato is Node3D) \
						or not is_instance_valid(candidato):
					continue
				var d := corpo.global_position.distance_to((candidato as Node3D).global_position)
				if d < distancia:
					distancia = d
					melhor = candidato as Node3D
	if melhor != null:
		return (melhor.global_position + Vector3.UP * 0.8 - corpo.global_position).normalized()
	return fallback


static func _efeito_teleporte(world: Node, de: Vector3, para: Vector3) -> void:
	if world == null or not is_instance_valid(world):
		return
	var raiz := Node3D.new()
	raiz.name = "PikaTeleporteVertical"
	world.add_child(raiz)
	var halo := BeamVisual3D.criar(raiz, de, para, 0.16, COR_OURO, 8.0, true)
	var nucleo := BeamVisual3D.criar(raiz, de, para, 0.065, COR_NUCLEO, 12.0, true)
	var tw := raiz.create_tween().set_parallel()
	tw.tween_property(halo.material_override, "albedo_color:a", 0.0, 0.20)
	tw.tween_property(nucleo.material_override, "albedo_color:a", 0.0, 0.15)
	var fag := GoroFX.sparks(36, 0.34, Vector3.UP, 22.0, 3.0, 10.0, 0.12)
	raiz.add_child(fag)
	fag.global_position = para
	FxUtil.autofree(raiz, 0.42)
	PikaAudio.play(world, para, "teleporte")


class YasakaniController extends Node3D:
	const Poses = preload("res://src/anim/PikaPoses.gd")
	var caster: Node = null
	var spec: DamageSpec = null
	var fwd := Vector3.FORWARD
	var cast_token := 0
	var _t := 0.0
	var _proximo := C_RAJA_INICIO
	var _indice := 0
	var _carga: Node3D = null
	var _particulas: GPUParticles3D = null
	var _leito: AudioStreamPlayer3D = null
	var _zona: ZonaBarragem = null

	func _ready() -> void:
		name = "PikaCYasakani"
		if is_instance_valid(caster):
			caster.set_meta("pika_c_active", true)
			caster.set_meta("pika_c_token", cast_token)
			caster.set_meta("custom_pose", Poses.C_YASAKANI)
			# ⚠️ A TRAVA COBRE SÓ O PREPARO, NÃO O GOLPE INTEIRO (2026-09-06).
			#
			# Era `lock_movement(C_TOTAL)` — 3,7 s. E `Player.lock_movement` não
			# tem timer próprio ("ignora o timer, a FSM cuida"), então soltar o C
			# mais cedo NÃO devolvia o controle: o jogador largava a tecla e
			# ficava parado pelo resto do tempo, sem animação de caminhada,
			# depois de ter sido teleportado 7 m para cima e cair. É a leitura
			# mais provável do "o personagem para de exibir animações após usar
			# o C".
			#
			# Agora trava só até a barragem começar. Dali em diante o jogador
			# ANDA e MIRA enquanto desfere — a mecânica pedida.
			if caster.has_method("lock_movement"):
				caster.lock_movement(C_RAJA_INICIO, "C")
		_criar_carga()
		PikaAudio.play(get_parent(), global_position, "carga", 0.88)
		# O próprio relógio encerra em C_TOTAL. Não há autofree redundante aqui:
		# soltar C remove este nó antes e uma lambda temporizada reteria referência
		# para um objeto já liberado.

	func _process(delta: float) -> void:
		_t += delta
		_seguir_caster()
		_remirar()
		if not is_instance_valid(caster) or not bool(caster.get_meta("pika_c_active", false)):
			_encerrar(false)
			return
		if _t >= C_RAJA_INICIO and _t < C_RAJA_FIM:
			# Cama contínua por baixo dos fragmentos. Sem ela, 60 disparos por
			# segundo soam a pipoca; com ela, soam a uma coisa só que dura.
			if _leito == null:
				_leito = PikaAudio.play_loop(get_parent(), global_position, "barragem")
			if is_instance_valid(_leito):
				_leito.global_position = global_position
			# O volume de dano nasce junto com o primeiro pulso e vive enquanto a
			# barragem durar. Filho DESTE nó de propósito: o controlador já se
			# reposiciona sobre o caster a cada quadro (`_seguir_caster`), então
			# a zona o acompanha sem código de sincronia próprio.
			if _zona == null:
				_zona = ZonaBarragem.new()
				_zona.cantos = _cantos()
				_zona.caster = caster
				_zona.spec_do_golpe = spec
				add_child(_zona)
				_zona.apontar(fwd)
			while _t >= _proximo:
				for j in C_POR_PULSO:
					_disparar(_indice)
					_indice += 1
				_proximo += C_INTERVALO
		if _t >= C_CARGA_FIM and is_instance_valid(_carga):
			_carga.visible = false
		if _t >= C_RAJA_FIM and is_instance_valid(_particulas):
			_particulas.emitting = false
		if _t >= C_TOTAL:
			_encerrar(true)

	func _encerrar(natural: bool) -> void:
		if is_queued_for_deletion():
			return
		if is_instance_valid(_particulas):
			_particulas.emitting = false
		# Soltar o C encerra a barragem: o leito morre junto, senão continua
		# tocando um golpe que o jogador já parou.
		PikaAudio.parar(_leito)
		_leito = null
		# A paralisia que a zona renova morre com ela: quem estava preso é solto
		# em no máximo C_PARALISIA depois do fim da barragem.
		if is_instance_valid(_zona):
			_zona.queue_free()
		_zona = null
		_limpar_pose()
		if natural and is_instance_valid(caster) and bool(caster.get("_is_authority")) \
				and caster.has_method("finalizar_skill_pika_c"):
			caster.finalizar_skill_pika_c(cast_token)
		queue_free()

	func _seguir_caster() -> void:
		if is_instance_valid(caster) and caster is Node3D:
			global_position = (caster as Node3D).global_position + Vector3(0, 1.22, 0)

	# ====================================================================
	#  MIRAR ENQUANTO DESFERE — mecânica pedida pelo dono em 2026-09-06
	# ====================================================================
	#  *"é possível mover o efeito e a área de dano enquanto o desfere"*.
	#
	#  O `fwd` era fixado no primeiro quadro (teleporte + trava no inimigo mais
	#  próximo) e valia até o fim. Agora ele acompanha o corpo: os fragmentos,
	#  que já nascem de `_direcao(indice)` a partir do `fwd`, passam a sair para
	#  onde o jogador está virado, e a `ZonaBarragem` gira junto — efeito e área
	#  de dano andam como uma coisa só, que é o que o pedido descreve.
	#
	#  ⚠️ A HORIZONTAL VEM DO CORPO, NÃO DA CÂMERA, e a escolha é de REDE.
	#  `mira_do_cast()` lê a câmera, que só existe na máquina do dono — usá-la
	#  faria o servidor e os outros peers verem a barragem parada na direção do
	#  primeiro quadro enquanto o dono a vê girar, e quem decide dano é o
	#  servidor. O giro do CORPO já é replicado (`net_facing`), então mirar por
	#  ele sai sincronizado de graça, sem um RPC novo por quadro.
	#
	#  ⚠️ A VERTICAL É PRESERVADA da mira inicial. O C começa teleportando 7 m
	#  para cima e a trava automática aponta para BAIXO, na direção do alvo; a
	#  frente do corpo é horizontal por definição. Trocar tudo pela frente do
	#  corpo levantaria a barragem para o horizonte no primeiro quadro — o golpe
	#  deixaria de mirar quem ele acabou de escolher.
	var _inclinacao := 0.0
	var _inclinacao_lida := false

	func _remirar() -> void:
		if not is_instance_valid(caster) or not (caster is Node3D):
			return
		if not _inclinacao_lida:
			_inclinacao_lida = true
			_inclinacao = clampf(fwd.normalized().y, -0.98, 0.98)
		var frente := -(caster as Node3D).global_transform.basis.z
		frente.y = 0.0
		if frente.length_squared() < 0.001:
			return
		frente = frente.normalized()
		var horizontal := sqrt(maxf(1.0 - _inclinacao * _inclinacao, 0.0))
		fwd = (frente * horizontal + Vector3.UP * _inclinacao).normalized()
		if is_instance_valid(_zona):
			_zona.apontar(fwd)

	func _criar_carga() -> void:
		_carga = Node3D.new()
		add_child(_carga)
		for lado in [-1.0, 1.0]:
			var orb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.10
			sm.height = 0.20
			orb.mesh = sm
			orb.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 10.0, true)
			orb.position = Vector3(0.34 * lado, 0.34, -0.05)
			orb.scale = Vector3.ONE * 0.08
			_carga.add_child(orb)
			var tw := orb.create_tween()
			tw.tween_property(orb, "scale", Vector3.ONE * 2.4, C_CARGA_FIM) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 1.05
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 1.1
		pm.gravity = Vector3(0, 0.7, 0)
		pm.scale_min = 0.035
		pm.scale_max = 0.10
		pm.color_ramp = FxUtil.gradient([Color(1, 0.7, 0.1, 0), COR_NUCLEO, COR_OURO, Color(1, 0.7, 0.1, 0)])
		_particulas = FxUtil.particles(90, 0.7, false, pm, FxUtil.grain(0.11), 0.0, "hero")
		add_child(_particulas)

	func _disparar(indice: int) -> void:
		var mundo := get_parent()
		if mundo == null:
			return
		var direcao := _direcao(indice)
		var lado := fwd.cross(Vector3.UP).normalized()
		if lado.length_squared() < 0.01:
			lado = Vector3.RIGHT
		var origem := global_position + lado * (0.30 if indice % 2 == 0 else -0.30)

		# ⚠️ O FRAGMENTO NÃO MACHUCA MAIS — ele só desenha (mudança pedida pelo
		# dono em 2026-09-06). Quem aplica dano no C agora é a `ZonaBarragem`,
		# um volume único que cobre a área inteira do golpe: estar dentro dela
		# basta, e não é mais preciso que este projétil em particular conecte.
		#
		# O visual é EXATAMENTE o de antes. O que sumiu é a `DamageZone` que
		# vinha embaixo — com ela sai também a varredura de física por quadro de
		# cada um dos ~30 fragmentos vivos, então a troca ainda é mais barata do
		# que era.
		var cabeca := FragmentoVisual.new()
		cabeca.direcao = direcao
		cabeca.alcance = _ate_a_parede(origem, direcao)
		mundo.add_child(cabeca)
		# ⚠️ O NOME VEM DEPOIS DO `add_child`, E A ORDEM NÃO É ESTILO.
		# Nomear ANTES faz o Godot resolver a colisão de irmãos com o formato
		# interno `@PikaFragmentoC@2`; nomear DEPOIS, já dentro da árvore, gera
		# `PikaFragmentoC2`. Só o segundo casa com `begins_with("PikaFragmentoC")`,
		# que é como o `test_pika_c_v` conta a barragem. Inverti isso ao trocar o
		# fragmento por nó visual e o teste passou a ver 1 fragmento onde havia 90.
		cabeca.name = "PikaFragmentoC"
		cabeca.global_position = origem

		var nucleo := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.075
		sm.height = 0.15
		nucleo.mesh = sm
		nucleo.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 12.0, true)
		cabeca.add_child(nucleo)

		var rastro := RastroCurto.new()
		rastro.cabeca = cabeca
		rastro.direcao = direcao
		rastro.origem = origem
		rastro.indice = indice
		mundo.add_child(rastro)
		# Um em cada 3, e o teto de vozes do `PikaAudio` corta o resto. Antes era
		# um em 9 para não empilhar; agora quem controla o empilhamento é o teto,
		# então dá para soar mais denso sem risco — e barragem tem de soar densa.
		if indice % 3 == 0:
			PikaAudio.play(mundo, origem, "fragmento",
				0.94 + float(indice % 7) * 0.02)

	# Onde este fragmento deve parar de ser desenhado. UM raio no nascimento, em
	# vez da varredura por quadro que a `DamageZone` fazia: o fragmento não
	# machuca mais, então basta saber de antemão até onde ele aparece. São ~90
	# raios ao longo da barragem inteira, contra ~30 varreduras POR QUADRO antes.
	func _ate_a_parede(origem: Vector3, direcao: Vector3) -> float:
		var mundo3d := get_world_3d()
		if mundo3d == null:
			return C_ALCANCE
		var par := PhysicsRayQueryParameters3D.create(origem, origem + direcao * C_ALCANCE)
		par.collision_mask = 15
		par.collide_with_areas = false
		if caster is CollisionObject3D:
			par.exclude = [(caster as CollisionObject3D).get_rid()]
		var bateu := mundo3d.direct_space_state.intersect_ray(par)
		if bateu.is_empty():
			return C_ALCANCE
		return origem.distance_to(bateu["position"] as Vector3)

	# Os QUATRO CANTOS do leque, em ordem de contorno (anti-horária vista de
	# frente): (-,-) (-,+) (+,+) (+,-). A ordem importa para o desenho fechar a
	# base da pirâmide sem triângulo cruzado; para a `ConvexPolygonShape3D` ela é
	# indiferente, porque envoltória convexa não liga para ordem de entrada.
	#
	# ⚠️ EM ESPAÇO CANÔNICO (frente = -Z), não no mundo (2026-09-06). Antes eles
	# saíam já rotacionados pelo `fwd` do instante da conjuração, o que fixava a
	# hitbox na direção do primeiro quadro para sempre. Com o C agora podendo ser
	# MIRADO durante a rajada, a forma precisa ser construída uma vez e depois
	# GIRADA — e girar uma `ConvexPolygonShape3D` é girar o nó, não recalcular os
	# pontos. Daí os cantos nascerem no referencial da própria zona.
	func _cantos() -> Array[Vector3]:
		var saida: Array[Vector3] = []
		for par in [[-1.0, -1.0], [-1.0, 1.0], [1.0, 1.0], [1.0, -1.0]]:
			saida.append(Vector3(
				C_ABERTURA_H * float(par[0]),
				C_ABERTURA_V * float(par[1]),
				-1.0).normalized())
		return saida

	func _direcao(indice: int) -> Vector3:
		var lado := fwd.cross(Vector3.UP).normalized()
		if lado.length_squared() < 0.01:
			lado = Vector3.RIGHT
		var cima := lado.cross(fwd).normalized()
		# Duas sequências irracionais dão cobertura densa e determinística sem
		# padrões em grade nem rajadas que mudam de hitbox entre peers.
		var h := (fposmod(float(indice) * 0.6180339, 1.0) * 2.0 - 1.0) * C_ABERTURA_H
		var v := (fposmod(float(indice) * 0.4142135, 1.0) * 2.0 - 1.0) * C_ABERTURA_V
		return (fwd + lado * h + cima * v).normalized()

	func _limpar_pose() -> void:
		if is_instance_valid(caster) \
				and String(caster.get_meta("custom_pose", "")) == Poses.C_YASAKANI:
			caster.remove_meta("custom_pose")

	# ⚠️ O LEITO É EM LAÇO, logo NUNCA emite `finished` — o `queue_free` pendurado
	# nesse sinal não vem salvar ninguém aqui. Ele é filho do mundo, não deste
	# nó, então se o controlador morrer por um caminho que não passa pelo
	# `_encerrar` a barragem continuaria soando sozinha, sem golpe nenhum na
	# tela. Parar aqui também cobre esse caso; parar duas vezes é inofensivo
	# (`parar` checa `is_instance_valid`).
	func _exit_tree() -> void:
		PikaAudio.parar(_leito, 0.0)
		_leito = null
		_limpar_pose()


class RastroCurto extends Node3D:
	const Impacto = preload("res://src/effects/PikaLightImpact.gd")
	var cabeca: Node3D = null
	var direcao := Vector3.FORWARD
	var origem := Vector3.ZERO
	var indice := 0
	var _externo: MeshInstance3D = null
	var _interno: MeshInstance3D = null
	var _ultima := Vector3.ZERO
	var _morrendo := 0.0

	func _ready() -> void:
		name = "PikaRastroCurto"
		_externo = BeamVisual3D.criar(self, origem, origem, 0.034, COR_OURO, 7.0, true)
		_interno = BeamVisual3D.criar(self, origem, origem, 0.014, COR_NUCLEO, 12.0, true)

	func _process(delta: float) -> void:
		if is_instance_valid(cabeca) and not bool(cabeca.get_meta("pika_encerrado", false)):
			_ultima = cabeca.global_position
			var percorrido := _ultima.distance_to(origem)
			var inicio := _ultima - direcao * minf(C_RASTRO, percorrido)
			BeamVisual3D.atualizar(_externo, inicio, _ultima)
			BeamVisual3D.atualizar(_interno, inicio, _ultima)
			return
		if is_instance_valid(cabeca):
			_ultima = cabeca.global_position
			cabeca = null
		if _morrendo == 0.0:
			Impacto.criar(get_parent(), _ultima, indice % 12 == 0, indice % 9 == 0)
		_morrendo += delta
		var alpha := 1.0 - clampf(_morrendo / 0.12, 0.0, 1.0)
		for feixe in [_externo, _interno]:
			if is_instance_valid(feixe):
				var mat := feixe.material_override as StandardMaterial3D
				if mat != null:
					mat.albedo_color.a = alpha
		if _morrendo >= 0.12:
			queue_free()


# ============================================================================
#  A HITBOX DO C — um volume só, no lugar de 90 projéteis
# ============================================================================
#  Mudança pedida pelo dono em 2026-09-06: "se o inimigo estiver na área de
#  efeito do ataque ele obrigatoriamente recebe o dano e fica paralisado, ao
#  invés de ter que ficar acertando ataque por ataque".
#
#  O SINTOMA que motivou: o C tendia a não acertar. E não era azar — era
#  aritmética. Cada fragmento tinha 0,16 m de raio e voava a 92 m/s, o leque
#  espalhava 90 deles por 52 m de frente, e o alvo precisava estar no caminho de
#  um EM PARTICULAR. A barragem parecia cobrir tudo e cobria quase nada.
#
#  ------------------------------------------------------------ A FORMA
#  Uma pirâmide: o ápice no peito do caster e os quatro cantos do leque a
#  `C_ALCANCE`. Os cantos saem de `_cantos()`, que lê `C_ABERTURA_H/V` — as
#  MESMAS constantes que `_direcao()` usa para espalhar os fragmentos. Por
#  construção, então, a hitbox é o envelope exato do que se vê; ela não pode
#  divergir do visual sem que alguém mude os dois números.
#
#  `ConvexPolygonShape3D` recebe os 5 pontos e liga todos entre si — é a
#  envoltória convexa deles, que é literalmente o "todos os pontos se
#  interligam" do pedido.
#
#  ⚠️ MEDIDO: com `C_ABERTURA_H = 0,72` e `C_ALCANCE = 46`, o volume tem
#  **52,6 m de largura** e 19,0 m de altura na boca, com 36,5 m de alcance
#  frontal. A arena tem 88 m de diâmetro. É uma área enorme — e é a área que os
#  fragmentos sempre cobriram. Se ficar demais, os botões para girar são
#  `C_ABERTURA_H` e `C_ALCANCE`, e o desenho vermelho mostra o efeito na hora.
#
#  ---------------------------------------------------------- POR QUE TICA
#  O golpe é SUSTENTADO (1,5 s de barragem), então a zona aplica dano em pulsos
#  na mesma cadência dos fragmentos: `C_POR_PULSO` acertos a cada `C_TIQUE`. São
#  os mesmos 8 x 48 da tabela, e o `teto` de 384 da conjuração continua sendo o
#  que limita o total — quem for preso a barragem inteira chega exatamente nele.
#  Ficar um instante dentro custa proporcionalmente menos.
#
#  É `DamageZone`, e não uma `Area3D` crua como o campo de gelo da Hie Hie, por
#  dois motivos: herda o funil de dano inteiro (cast_id, teto, crédito de kill,
#  autoridade de servidor) e continua sendo contada como hitbox por
#  `test_frutas` — que conta `DamageZone`, e leria "golpe mudo" se o C passasse
#  a ser outra coisa.
#
#  --------------------------------------------------- KNOCKBACK ZERO, DE PROPÓSITO
#  Mesmo raciocínio já escrito no El Thor (`GoroFXGrande`): empurrar espalha o
#  alvo para FORA da área antes de o golpe terminar, e o golpe se sabota. Aqui é
#  mais forte ainda, porque a paralisia é metade do pedido.
class ZonaBarragem extends DamageZone:
	var cantos: Array[Vector3] = []
	var spec_do_golpe: DamageSpec = null
	var _resto := 0.0
	var _conta := 0

	func _ready() -> void:
		name = "PikaZonaBarragemC"
		var pontos := PackedVector3Array()
		pontos.append(Vector3.ZERO)              # ápice, no peito do caster
		for c in cantos:
			pontos.append(c * C_ALCANCE)
		var forma := ConvexPolygonShape3D.new()
		forma.points = pontos

		# ⚠️ A BASE NÃO PARALISA — o tique paralisa. `DamageZone.paralisa` escreve
		# `is_frozen` na mão e aplica `StatusFX` direto; `paralisar_com_animacao`
		# faz isso E anima a recepção de dano, além de marcar `_dano_paralisia`
		# para não brigar com o congelamento da Hie Hie no mesmo `is_frozen`
		# (ver o aviso em `RecepcaoDeDano`). Ligar os dois seria duas mecânicas
		# escrevendo no mesmo sinal — exatamente o que aquele aviso pede para não
		# fazer. Então `paralisa` fica em zero e o tique é o dono único.
		#
		# O `body_entered` da base ainda entrega o primeiro acerto com o peso
		# completo (hitstop, flash de tela, crédito de kill). É o instante de
		# impacto do golpe; os tiques seguintes somam dano em silêncio.
		setup(_dano_do_pulso(), 0.0, Vector3.ZERO,
			C_RAJA_FIM - C_RAJA_INICIO + 0.25, caster, 0.0, forma)
		if spec_do_golpe != null:
			spec_do_golpe.marcar(self)
		if C_MOSTRAR_HITBOX:
			add_child(_desenho(pontos))


	## Vira o volume para onde o jogador está mirando AGORA. Chamado por quadro
	## pelo controlador: é isto que faz "mover a área de dano enquanto desfere".
	##
	## Girar o NÓ, e não recalcular os pontos da forma, é o que torna isso
	## barato — trocar `ConvexPolygonShape3D.points` a 60 Hz obrigaria a física a
	## reconstruir a envoltória convexa a cada quadro.
	func apontar(direcao: Vector3) -> void:
		if direcao.length_squared() < 0.001:
			return
		var d := direcao.normalized()
		# `looking_at` degenera quando a mira encosta na vertical — e o C mira
		# para baixo com frequência, porque ele começa teleportando 7 m para cima.
		var cima := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		basis = Basis.looking_at(d, cima)

	func _dano_do_pulso() -> float:
		var por_hit: float = spec_do_golpe.valor_do_hit() if spec_do_golpe != null else damage
		return por_hit * float(C_POR_PULSO)

	func _process(delta: float) -> void:
		_resto -= delta
		if _resto > 0.0:
			return
		_resto = C_TIQUE
		# ⚠️ Só o servidor decide acerto — a mesma regra do resto da `DamageZone`.
		# Sem esta linha cada cliente aplicaria a própria barragem.
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			return
		# Renova no PRIMEIRO tique (1, 5, 9…) e não no quarto: quem entra não
		# pode esperar 0,20 s para ser preso, senão sai andando.
		var renova := _conta % C_PARALISIA_A_CADA == 0
		_conta += 1
		for corpo in get_overlapping_bodies():
			if corpo == caster or not is_instance_valid(corpo):
				continue
			if not corpo.has_method("take_damage"):
				continue
			# Direto no `CombatResolver`, como o campo de gelo: passar pelo
			# `_on_body` da base traria hitstop e flash de tela A CADA TIQUE —
			# 20 por segundo travariam o jogo, que é o mesmo motivo pelo qual o
			# Z só pede peso uma vez por salva.
			CombatResolver.aplicar(corpo, damage, cast_id, teto, global_position)
			if renova:
				RecepcaoDeDano.paralisar_com_animacao(corpo, C_PARALISIA)

	# A pirâmide desenhada. Quatro triângulos de lado mais dois que fecham a
	# base. `CULL_DISABLED` porque a câmera fica DENTRO do volume (o ápice está
	# no peito do jogador) e com face única não se veria nada de dentro.
	func _desenho(pontos: PackedVector3Array) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 4:
			st.add_vertex(pontos[0])
			st.add_vertex(pontos[1 + i])
			st.add_vertex(pontos[1 + (i + 1) % 4])
		st.add_vertex(pontos[1]); st.add_vertex(pontos[3]); st.add_vertex(pontos[2])
		st.add_vertex(pontos[1]); st.add_vertex(pontos[4]); st.add_vertex(pontos[3])
		var mi := MeshInstance3D.new()
		mi.name = "PikaHitboxVisivel"
		mi.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.0, 0.0, 0.16)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		# Fora do alcance do olho do E (`ScreenFX` desenha o grupo "hitbox"
		# através das paredes): isto aqui já É a hitbox, desenhá-la duas vezes
		# só empilharia vermelho.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


# O fragmento do C depois que o dano saiu dele: PURO DESENHO. Sem `Area3D`, sem
# corpo físico, sem varredura por quadro — some da conta de física os ~30
# fragmentos que ficavam vivos ao mesmo tempo.
#
# O contrato com o `RastroCurto` é a meta `pika_encerrado`, a mesma de antes:
# enquanto ela for falsa o rastro segue a cabeça; quando virar, ele desenha o
# clarão ali e apaga. Por isso o rastro não precisou mudar uma linha.
class FragmentoVisual extends Node3D:
	var direcao := Vector3.FORWARD
	var alcance := C_ALCANCE
	var _andado := 0.0

	func _ready() -> void:
		FxUtil.autofree(self, C_ALCANCE / C_VELOCIDADE + 0.3)

	func _process(delta: float) -> void:
		if bool(get_meta("pika_encerrado", false)):
			return
		var passo := C_VELOCIDADE * delta
		if _andado + passo >= alcance:
			global_position += direcao * maxf(alcance - _andado, 0.0)
			_andado = alcance
			set_meta("pika_encerrado", true)   # o rastro lê isto e fecha o clarão
			return
		_andado += passo
		global_position += direcao * passo


class ChuvaDeLuzController extends Node3D:
	const Poses = preload("res://src/anim/PikaPoses.gd")
	const Impacto = preload("res://src/effects/PikaLightImpact.gd")
	var caster: Node = null
	var spec: DamageSpec = null
	var centro_global := Vector3.ZERO
	var _rng := RandomNumberGenerator.new()
	var _t := 0.0
	var _proximo := V_CHUVA_INICIO
	var _indice := 0
	var _luz: OmniLight3D = null
	var _campo: GPUParticles3D = null
	var _estrelas: GPUParticles3D = null
	var _ativacao: Node3D = null
	var _estrelas_iniciadas := false
	var _chuva_iniciada := false
	var _dissipando := false

	func _ready() -> void:
		name = "PikaVChuvaDeLuz"
		_rng.seed = maxi(spec.cast_id, 1) * 7919 + 41
		if is_instance_valid(caster):
			caster.set_meta("custom_pose", Poses.V_ATIVACAO)
			if caster.has_method("lock_movement"):
				caster.lock_movement(V_CHUVA_INICIO, "V")
		_criar_ativacao()
		_criar_atmosfera()
		# O controlador encerra pelo próprio relógio em V_TOTAL.

	func _process(delta: float) -> void:
		_t += delta
		var dourado := 0.0
		if _t >= 0.55 and _t < V_CHUVA_FIM:
			dourado = smoothstep(0.55, 1.75, _t)
		elif _t >= V_CHUVA_FIM:
			dourado = 1.0 - smoothstep(V_CHUVA_FIM, V_TOTAL, _t)
		PikaFXGrande._atualizar_ceu_dourado(self, dourado)

		if _t >= 0.70 and not _estrelas_iniciadas:
			_estrelas_iniciadas = true
			_estrelas.emitting = true
		if _t >= V_CHUVA_INICIO and not _chuva_iniciada:
			_chuva_iniciada = true
			_campo.emitting = true
			_limpar_pose()
			GoroFX._screen_flash(get_parent(), COR_NUCLEO, 0.16)
		if _t >= V_CHUVA_INICIO and _t < V_CHUVA_FIM:
			while _t >= _proximo:
				_descarga()
				var intensidade := clampf((_t - V_CHUVA_INICIO) / (V_MAX_INICIO - V_CHUVA_INICIO), 0.0, 1.0)
				var intervalo := lerpf(0.18, 0.065, intensidade)
				if _t >= V_MAX_INICIO:
					intervalo = 0.038
				_proximo += intervalo
		if _t >= V_CHUVA_FIM and not _dissipando:
			_dissipando = true
			_campo.emitting = false
			_estrelas.emitting = false
			var tw := create_tween()
			tw.tween_property(_luz, "light_energy", 0.0, 1.0)
		if _t >= V_TOTAL:
			queue_free()

	func _criar_ativacao() -> void:
		_ativacao = Node3D.new()
		add_child(_ativacao)
		var pos := Vector3(0, 1.75, 0)
		if is_instance_valid(caster) and caster is Node3D:
			pos = to_local((caster as Node3D).global_position + Vector3(0.32, 1.80, 0))
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		orb.mesh = sm
		orb.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 12.0, true)
		orb.position = pos
		orb.scale = Vector3.ONE * 0.08
		_ativacao.add_child(orb)
		var tw := orb.create_tween()
		tw.tween_property(orb, "scale", Vector3.ONE * 2.7, V_ATIVACAO_FIM) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(8.0, 0.2, 8.0)
		pm.direction = Vector3.UP
		pm.spread = 14.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 5.5
		pm.gravity = Vector3(0, 0.8, 0)
		pm.scale_min = 0.04
		pm.scale_max = 0.13
		pm.color_ramp = FxUtil.gradient([Color(1, 0.8, 0.2, 0), COR_NUCLEO, COR_OURO, Color(1, 0.7, 0.1, 0)])
		var subida := FxUtil.particles(140, 1.4, false, pm, FxUtil.grain(0.13), 0.0, "hero")
		_ativacao.add_child(subida)
		FxUtil.autofree(_ativacao, V_CHUVA_INICIO + 1.2)
		PikaAudio.play(get_parent(), global_position, "ceu")

	func _criar_atmosfera() -> void:
		_luz = OmniLight3D.new()
		_luz.light_color = Color(1.0, 0.82, 0.42)
		_luz.light_energy = 0.0
		_luz.omni_range = V_RAIO_ARENA * 1.4
		_luz.shadow_enabled = false
		_luz.position.y = V_ALTURA * 0.55
		add_child(_luz)
		var tw_luz := create_tween()
		tw_luz.tween_interval(0.55)
		tw_luz.tween_property(_luz, "light_energy", 2.0, 1.20)

		# Primeiro estágio da referência: pontos imóveis e cintilantes ocupam o
		# céu antes de se alongarem nos riscos descendentes da chuva.
		var pm_estrelas := ParticleProcessMaterial.new()
		pm_estrelas.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm_estrelas.emission_box_extents = Vector3(V_RAIO_ARENA, 4.5, V_RAIO_ARENA)
		pm_estrelas.direction = Vector3.UP
		pm_estrelas.spread = 180.0
		pm_estrelas.initial_velocity_min = 0.02
		pm_estrelas.initial_velocity_max = 0.10
		pm_estrelas.gravity = Vector3.ZERO
		pm_estrelas.scale_min = 0.70
		pm_estrelas.scale_max = 1.85
		pm_estrelas.color_ramp = FxUtil.gradient([
			Color(1, 0.70, 0.10, 0), COR_NUCLEO,
			Color(1.0, 0.68, 0.08, 0.92), Color(1, 0.70, 0.10, 0)])
		var mat_estrela := FxUtil.particle_material(COR_NUCLEO, 9.0, true)
		var estrela_vertical := QuadMesh.new()
		estrela_vertical.size = Vector2(0.055, 0.46)
		estrela_vertical.material = mat_estrela
		var estrela_horizontal := QuadMesh.new()
		estrela_horizontal.size = Vector2(0.30, 0.050)
		estrela_horizontal.material = mat_estrela
		_estrelas = FxUtil.particles(320, 3.6, false, pm_estrelas,
			estrela_vertical, 0.58, "hero")
		_estrelas.draw_passes = 2
		_estrelas.draw_pass_2 = estrela_horizontal
		_estrelas.name = "PikaEstrelasDoCeu"
		_estrelas.position.y = V_ALTURA - 8.0
		_estrelas.visibility_aabb = AABB(
			Vector3(-V_RAIO_ARENA, -7, -V_RAIO_ARENA),
			Vector3(V_RAIO_ARENA * 2.0, 14, V_RAIO_ARENA * 2.0))
		_estrelas.emitting = false
		add_child(_estrelas)

		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(V_RAIO_ARENA, 1.0, V_RAIO_ARENA)
		pm.direction = Vector3.DOWN
		pm.spread = 3.5
		pm.initial_velocity_min = 58.0
		pm.initial_velocity_max = 86.0
		pm.gravity = Vector3(0, -4.0, 0)
		pm.scale_min = 0.55
		pm.scale_max = 1.25
		pm.color_ramp = FxUtil.gradient([Color(1, 0.75, 0.15, 0), COR_NUCLEO, COR_OURO, Color(1, 0.75, 0.15, 0)])
		var risco := QuadMesh.new()
		risco.size = Vector2(0.045, 3.2)
		risco.material = FxUtil.particle_material(COR_NUCLEO, 9.0, true)
		_campo = FxUtil.particles(420, 0.48, false, pm, risco, 0.0, "hero")
		_campo.position.y = V_ALTURA
		_campo.visibility_aabb = AABB(
			Vector3(-V_RAIO_ARENA, -V_ALTURA - 4, -V_RAIO_ARENA),
			Vector3(V_RAIO_ARENA * 2.0, V_ALTURA + 8, V_RAIO_ARENA * 2.0))
		_campo.emitting = false
		add_child(_campo)

	func _descarga() -> void:
		var solo := _ponto_da_arena()
		solo = _ajustar_ao_solo(solo)
		_criar_feixe_visual(solo, true)
		# A chuva visual é mais densa que a cadência de dano: todos os riscos
		# comunicam perigo, mas apenas o primeiro por descarga recebe DamageSpec.
		# Assim o clímax cobre a arena sem multiplicar o teto de dano ou hitboxes.
		var extras := 5 if _t >= V_MAX_INICIO else 3
		for _i in extras:
			_criar_feixe_visual(_ponto_da_arena(), false)

		var grande := _indice % 13 == 0
		# O raio da hitbox vira o raio do ANEL desenhado. Eram 2,2 m de dano sob
		# um anel de 1,7 m: o jogador recuava até a borda do que via e levava o
		# golpe mesmo assim.
		var raio := 4.2 if grande else 2.2
		Impacto.criar(self, to_global(solo), grande, false, raio)
		PikaAudio.play(self, to_global(solo), "chuva",
			0.90 + float(_indice % 9) * 0.025)
		var zona := DamageZone.new()
		add_child(zona)
		zona.position = solo + Vector3.UP * 0.45
		zona.setup(spec.valor_do_hit(), 8.0 if not grande else 15.0, Vector3.ZERO,
			0.22, caster, raio)
		spec.marcar(zona)
		_indice += 1

	func _ponto_da_arena() -> Vector3:
		var ang := _rng.randf() * TAU
		var raio := V_RAIO_ARENA * sqrt(_rng.randf())
		return Vector3(cos(ang) * raio, 0.08, sin(ang) * raio)

	func _criar_feixe_visual(solo: Vector3, principal: bool) -> void:
		var desvio := Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8))
		var topo := solo + Vector3.UP * V_ALTURA + desvio
		var feixe := Node3D.new()
		feixe.name = "PikaFeixeV"
		add_child(feixe)
		var halo := BeamVisual3D.criar(feixe, topo, solo,
			0.055 if principal else 0.034, COR_OURO, 7.0, true)
		var nucleo := BeamVisual3D.criar(feixe, topo, solo,
			0.022 if principal else 0.012, COR_NUCLEO, 12.0, true)
		var tw := feixe.create_tween().set_parallel()
		tw.tween_property(halo.material_override, "albedo_color:a", 0.0, 0.26)
		tw.tween_property(nucleo.material_override, "albedo_color:a", 0.0, 0.20)
		FxUtil.autofree(feixe, 0.30)

	func _ajustar_ao_solo(local: Vector3) -> Vector3:
		var mundo := get_world_3d()
		if mundo == null:
			return local
		var alto := to_global(Vector3(local.x, V_ALTURA + 8.0, local.z))
		var baixo := to_global(Vector3(local.x, -20.0, local.z))
		var q := PhysicsRayQueryParameters3D.create(alto, baixo)
		q.collide_with_areas = false
		if caster is CollisionObject3D:
			q.exclude = [(caster as CollisionObject3D).get_rid()]
		var hit := mundo.direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return to_local(hit["position"]) + Vector3.UP * 0.06
		return local

	func _limpar_pose() -> void:
		if is_instance_valid(caster) \
				and String(caster.get_meta("custom_pose", "")) == Poses.V_ATIVACAO:
			caster.remove_meta("custom_pose")

	func _exit_tree() -> void:
		PikaFXGrande._remover_ceu_dourado(self)
		_limpar_pose()
