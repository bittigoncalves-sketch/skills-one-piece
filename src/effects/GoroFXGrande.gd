class_name GoroFXGrande
extends RefCounted

const GoroPoses = preload("res://src/anim/GoroPoses.gd")
# ============================================================================
#  GORO GORO — OS DOIS ESPETÁCULOS: X (El Thor) e V (Mamaragan).
#
#  Saíram do `GoroFX.gd` pelo mesmo critério que separou `FireFXGrande`: são os
#  golpes que não participam do combate do dia a dia (Z e C são o uso normal da
#  fruta) e são os que ocupam mais linhas. O teto do projeto é 900 linhas por
#  script — docs/LIMITE_DE_TAMANHO.md.
#
#  A PALETA e a OFICINA DE RAIO (Bolt, storm_cloud, shock_ring, volt_material)
#  continuam no `GoroFX` e são chamadas daqui. Duplicá-las criaria duas fontes
#  de verdade para a cor do trovão.
#
#  📏 GATILHO DE TAMANHO: este arquivo está em ~807 linhas, dentro do teto de
#  900 mas sem folga grande. Se o El Thor ou o Mamaragan crescerem de novo,
#  cortar por GOLPE (`GoroFXThor.gd` / `GoroFXMamaragan.gd`) — nunca por
#  "helpers vs. golpes", que é o corte que espalha a paleta.
#
#  ── O PEDIDO, COMO ELE FOI ESCRITO ───────────────────────────────────────
#  X — "nuvem azul-escura se formando, o jogador levanta o braço para cima e
#       uma grande quantidade de raios cai das nuvens para onde a mira estiver
#       apontando."
#  V — "nuvens se juntam no céu ao redor do jogador, o jogador começa a
#       flutuar, as mãos viram correntes elétricas e vão para as nuvens, então
#       uma bola azul-escura começa a se formar e só poderá ser arremessada
#       quando estiver completa."
#
#  ⚠️ A BOLA DO V É PARAMETRIZÁVEL DE PROPÓSITO. O charge-up (segurar a tecla
#  para a bola crescer) ainda NÃO existe como mecânica. Quando existir, quem
#  ligar não precisa mexer em VFX nenhum: basta chamar
#  `ThunderOrb.set_charge(tempo_segurado / tempo_maximo)` a cada quadro —
#  a bola inteira (núcleo, casca, anéis, gaiola de raios e luz) escala junto,
#  porque tudo é construído em RAIO 1.0 e a carga só mexe na escala do nó.
#  `ThunderOrb.raio_para_carga(t)` é a curva; RAIO_MIN/RAIO_MAX são os limites.
# ============================================================================

# ============================================================================
#  X — EL THOR
# ============================================================================
#
#  Roteiro (≈4,2 s, tudo livre da cena até ~5,3 s):
#    0,00  o jogador levanta o braço; carga elétrica sobe da mão para o céu
#    0,00  a NUVEM AZUL-ESCURA se forma sobre o ponto de mira (2 camadas de
#          massa + 1 luz que pisca por dentro + fumaça escura descendo)
#    0,95  começa a CHUVA DE RAIOS: 11 descargas caindo da nuvem, uma a cada
#          0,115 s, espalhadas num raio de 7 m em volta do ponto de mira
#    ≈2,2  COLUNA final no ponto exato da mira (3 cilindros concêntricos +
#          raio gigante no eixo + 2 anéis de choque) — é ela que carrega a
#          hitbox principal do golpe
#    4,20  a nuvem se abre e dissipa; o controlador se liberta
static func el_thor(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd: Vector3 = dir.normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, -1)

	var alvo := _ponto_de_mira(world, origin, fwd, 60.0, caster)

	# BRAÇO LEVANTADO. `custom_pose` é o canal que Yami e Mera já usam para pedir
	# uma pose ao ProceduralAnimator. A pose foi escrita em 2026-09-12 e vive em
	# `GoroPoses.EL_THOR`: braço à vertical no instante em que o gatilho sai do
	# `ForeArm_R`, e um tranco no ombro a cada um dos 11 raios que caem.
	if is_instance_valid(caster):
		# A pose existe desde 2026-09-12 (`GoroPoses.EL_THOR`); o comentário acima
		# descrevia o tempo em que ela era só uma marca posta à espera.
		caster.set_meta("custom_pose", GoroPoses.EL_THOR)
		# Remove, não zera: meta presente e parada congela a pose. Ver GoroFX._sango.
		caster.remove_meta("goro_pose_t")
		if caster.has_method("lock_movement"):
			caster.lock_movement(1.6, "X")

	# (a carga do braço já saiu no APERTO — ver `gatilho_do_braco`)

	var ctrl := ElThorController.new(alvo, damage, caster, spec)
	world.add_child(ctrl)
	FxUtil.autofree(ctrl, ElThorController.TOTAL + 1.6)   # rede de segurança

# Para ONDE a mira está apontando: raio de mira até 60 m e, do que ele achar,
# desce até o chão. Antes o El Thor caía sempre 5 m à frente do peito — o que
# quer dizer que ele NÃO seguia a mira, só a direção do corpo.
## ⚠️ O `world` NÃO SERVE DE REFERÊNCIA NO PRIMEIRO GOLPE DE UMA VIDA.
##
## Ele é o `Skills_<jogador>` de `Player._get_skills_container()`, que entra na
## cena por `add_child.call_deferred(...)`: no primeiro cast ainda está FORA da
## árvore, `get_world_3d()` devolve null e a função caía no fallback — mira
## ignorada, alvo a `alcance` metros à frente e y = 0. É a mesma armadilha que
## `FxUtil.autofree` e `YamiFX._find_closest_entity` já documentam.
##
## O `caster` está sempre na árvore, então ele é a referência preferida. Medido
## em 2026-09-12 com o Mamaragan; o El Thor sofria do mesmo defeito em silêncio,
## porque um alvo "à frente do peito" é plausível demais para denunciar o erro.
static func _ponto_de_mira(world: Node, origin: Vector3, fwd: Vector3, alcance: float, caster: Node) -> Vector3:
	var alvo: Vector3 = origin + fwd * alcance
	var space: PhysicsDirectSpaceState3D = null
	for referencia in [caster, world]:
		if referencia is Node3D and (referencia as Node3D).is_inside_tree() \
				and (referencia as Node3D).get_world_3d() != null:
			space = (referencia as Node3D).get_world_3d().direct_space_state
			break
	if space == null:
		alvo.y = 0.0
		return alvo

	var excluir: Array[RID] = []
	if caster is CollisionObject3D:
		excluir.append((caster as CollisionObject3D).get_rid())

	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * alcance)
	q.collide_with_areas = false
	q.exclude = excluir
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		alvo = hit["position"]

	var q2 := PhysicsRayQueryParameters3D.create(alvo + Vector3.UP * 3.0, alvo + Vector3.DOWN * 90.0)
	q2.collide_with_areas = false
	q2.exclude = excluir
	var hit2: Dictionary = space.intersect_ray(q2)
	if not hit2.is_empty():
		return hit2["position"]
	alvo.y = 0.0
	return alvo

# A carga que sobe do braço erguido até o céu: bola de luz na mão + raio subindo
# + fagulhas. É o elo visual entre o jogador e a nuvem lá em cima.
# GATILHO DO EL THOR — o raio que sobe do BRAÇO.
#
# ⚠️ Ele NÃO é o ataque, é o que INICIA a reação: por isso dispara no APERTO da
# tecla e não espera a soltura (pedido do dono, 2026-08-12). Quem chama é o
# `CastController.comecar`, não o cast.
#
# A origem é o ANTEBRAÇO DIREITO do rig, não o peito: "este mesmo raio deve
# partir do braço do jogador para cima". Sem rig na árvore, cai no peito.
static func gatilho_do_braco(world: Node, caster: Node) -> void:
	if not is_instance_valid(caster):
		return
	_carga_do_braco(world, _ponto_do_braco(caster), caster)

# Ponta do antebraço direito, em mundo. O rig é montado pelo `PlayerRig` e o
# papel se chama `ForeArm_R` nos 13 papéis canônicos do projeto.
static func _ponto_do_braco(caster: Node) -> Vector3:
	var modelo = caster.get("_char_model")
	if modelo is Node3D and is_instance_valid(modelo):
		var braco := (modelo as Node3D).find_child("ForeArm_R", true, false)
		if braco is Node3D and (braco as Node3D).is_inside_tree():
			return (braco as Node3D).global_position
	return (caster as Node3D).global_position + Vector3(0, 1.05, 0)

static func _carga_do_braco(world: Node, origin: Vector3, caster: Node) -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = origin

	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.34
	sm.height = 0.68
	orb.mesh = sm
	orb.material_override = GoroFX.volt_material(GoroFX.FLASH_WHITE, 9.0)
	orb.scale = Vector3(0.05, 0.05, 0.05)
	root.add_child(orb)
	var tw := orb.create_tween()
	tw.tween_property(orb, "scale", Vector3(1.4, 1.4, 1.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(orb, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_trans(Tween.TRANS_QUAD)

	var b := GoroFX.Bolt.new(Vector3.ZERO, Vector3(0, 16.0, 0),
		GoroFX.ELECTRIC_YELLOW, 8.0, 18, 0.80, 0.14, 3)
	b.flick = 0.03
	root.add_child(b)

	var luz := GoroFX.Flicker.new(GoroFX.LIGHTNING_CYAN, 7.0, 14.0)
	luz.velocidade = 24.0
	root.add_child(luz)

	root.add_child(GoroFX.sparks(120, 0.6, Vector3.UP, 45.0, 3.0, 9.0, 0.30))
	AudioFX.whoosh(world, root.global_position, 0.5)
	FxUtil.autofree(root, 1.0)


class ElThorController extends Node3D:
	const ALTURA_NUVEM := 24.0
	const RAIO_NUVEM   := 9.5
	const ESPALHA      := 7.0      # em que raio ao redor da mira os raios caem
	const INICIO_CHUVA := 0.95
	const INTERVALO    := 0.115
	const RAIOS        := 11
	const TOTAL        := 4.2

	var damage: float
	var caster: Node
	var _t := 0.0
	var _prox := 0.0
	var _restam := RAIOS
	var _finale := false
	var _dissipou := false
	var _nuvem: Node3D
	var _luz: GoroFX.Flicker
	var _mats: Array = []

	var spec: DamageSpec = null

	func _init(centro: Vector3, dmg: float, c: Node, s: DamageSpec = null) -> void:
		damage = dmg
		caster = c
		spec = s if s != null else DamageSpec.avulso(dmg)
		position = centro

	func _ready() -> void:
		# ---- A NUVEM AZUL-ESCURA SE FORMANDO ----
		_nuvem = Node3D.new()
		add_child(_nuvem)
		_nuvem.position = Vector3(0, ALTURA_NUVEM, 0)
		_nuvem.scale = Vector3(0.04, 0.04, 0.04)
		for camada in range(2):
			var interna: bool = camada == 0
			var mm := GoroFX.storm_cloud(
				RAIO_NUVEM * (0.72 if interna else 1.0),
				16 if interna else 20,
				GoroFX.STORM_NAVY if interna else GoroFX.STORM_BLUE,
				0.5 if interna else 0.42)
			_nuvem.add_child(mm)
			_mats.append(mm.material_override)
		var tw := _nuvem.create_tween()
		tw.tween_property(_nuvem, "scale", Vector3.ONE, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Luz que pisca DENTRO da massa escura (o relâmpago preso na nuvem).
		_luz = GoroFX.Flicker.new(GoroFX.STORM_GLOW, 12.0, 42.0)
		add_child(_luz)
		_luz.position = Vector3(0, ALTURA_NUVEM - 2.5, 0)

		# Fumaça escura descendo da barriga da nuvem.
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = RAIO_NUVEM
		pm.direction = Vector3.DOWN
		pm.spread = 35.0
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 3.0
		pm.gravity = Vector3(0, -0.6, 0)
		pm.scale_min = 1.6
		pm.scale_max = 4.2
		pm.color_ramp = FxUtil.gradient([Color(0, 0, 0, 0), GoroFX.STORM_NAVY, GoroFX.STORM_BLUE, Color(0, 0, 0, 0)])
		var bruma := FxUtil.particles(150, 2.4, false, pm, FxUtil.grain(2.0), 0.0, "hero")
		add_child(bruma)
		bruma.position = Vector3(0, ALTURA_NUVEM - 1.5, 0)

		var mundo := get_tree().current_scene if get_tree() else null
		if mundo:
			AudioFX.cannon(mundo, global_position + Vector3.UP * ALTURA_NUVEM, 0.42)   # trovão distante
			GoroFX._screen_flash(mundo, Color(0.35, 0.5, 1.0), 0.22)

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(_nuvem):
			_nuvem.rotation.y += 0.28 * delta

		if _restam > 0 and _t >= INICIO_CHUVA and _t >= _prox:
			_prox = _t + INTERVALO
			_restam -= 1
			_descarga()
			if _restam <= 0:
				_prox = _t + 0.10

		if _restam <= 0 and not _finale and _t >= _prox:
			_finale = true
			_coluna()

		if _t >= TOTAL and not _dissipou:
			_dissipou = true
			_dissipar()

	# UM raio da chuva: 2 camadas de zigue-zague + anel no chão + fagulhas +
	# hitbox própria. A luz da nuvem PULA para o ponto atingido — é o que faz o
	# clarão parecer vir do raio e não de um poste no céu.
	func _descarga() -> void:
		var ang := randf() * TAU
		var r: float = ESPALHA * sqrt(randf())
		var solo := Vector3(cos(ang) * r, 0.12, sin(ang) * r)
		var topo := Vector3(solo.x * 0.30, ALTURA_NUVEM - 2.0, solo.z * 0.30)

		for camada in range(2):
			var grosso: bool = camada == 0
			var b := GoroFX.Bolt.new(topo, solo,
				GoroFX.ELECTRIC_YELLOW if grosso else GoroFX.FLASH_WHITE,
				6.5 if grosso else 11.0,
				16, 1.55 if grosso else 0.70,
				0.40 if grosso else 0.15,
				3 if grosso else 1)
			b.flick = 0.028
			add_child(b)
			FxUtil.autofree(b, 0.30)

		GoroFX.shock_ring(self, solo, GoroFX.ELECTRIC_YELLOW, 5.5, 0.38)
		var fag := GoroFX.sparks(120, 0.55, Vector3.UP, 65.0, 6.0, 16.0, 0.42)
		add_child(fag)
		fag.position = solo
		FxUtil.autofree(fag, 0.9)

		if is_instance_valid(_luz):
			_luz.position = solo + Vector3.UP * 2.0
			_luz.base_energy = 20.0
			var tw := _luz.create_tween()
			tw.tween_property(_luz, "base_energy", 11.0, 0.22)

		var mundo := get_tree().current_scene if get_tree() else null
		if mundo:
			var pos_global: Vector3 = global_position + solo
			var zona := DamageZone.new()
			mundo.add_child(zona)
			zona.global_position = pos_global + Vector3.UP * 0.6
			# ⚠️ OS RAIOS QUE CAEM PARALISAM, NÃO EMPURRAM (pedido do dono,
			# 2026-08-12). Empurrar aqui espalhava o alvo para fora da área
			# antes de a COLUNA FINAL chegar — o golpe se sabotava.
			# ⚠️ ERA `damage * 0.35`. Cada raio que cai vale o dano cheio de um acerto
			# MULTI (64); quem limita o total dos 11 é o teto do slot, não uma fração
			# escrita aqui.
			zona.setup(spec.dano, 0.0, Vector3.ZERO, 0.22, caster, 2.8)
			spec.marcar(zona)
			zona.paralisa = 1.2
			AudioFX.snap(mundo, pos_global, randf_range(1.15, 1.75))
			if _restam % 4 == 0:
				AudioFX.cannon(mundo, pos_global, randf_range(0.55, 0.8))

	# A COLUNA final, no ponto exato da mira. É ela que carrega a hitbox
	# principal do El Thor (os mesmos números de dano/knockback/raio de antes).
	func _coluna() -> void:
		var col := Node3D.new()
		add_child(col)

		var raios := [0.9, 2.1, 3.4]
		var cores := [GoroFX.FLASH_WHITE, GoroFX.ELECTRIC_YELLOW, GoroFX.LIGHTNING_CYAN]
		var energias := [10.0, 7.0, 4.0]
		var alfas := [0.95, 0.6, 0.28]
		for i in range(3):
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = float(raios[i])
			cyl.bottom_radius = float(raios[i]) * 1.2
			cyl.height = ALTURA_NUVEM * 1.7
			cyl.radial_segments = 16
			mi.mesh = cyl
			var mat := GoroFX.volt_material(cores[i], energias[i])
			mat.albedo_color.a = float(alfas[i])
			mi.material_override = mat
			mi.position.y = ALTURA_NUVEM * 0.85
			col.add_child(mi)

		var b := GoroFX.Bolt.new(Vector3(0, ALTURA_NUVEM, 0), Vector3(0, 0.1, 0),
			GoroFX.FLASH_WHITE, 12.0, 24, 1.7, 0.55, 5)
		b.flick = 0.03
		col.add_child(b)

		GoroFX.shock_ring(self, Vector3(0, 0.16, 0), GoroFX.FLASH_WHITE, 16.0, 0.55)
		GoroFX.shock_ring(self, Vector3(0, 0.10, 0), GoroFX.LIGHTNING_CYAN, 26.0, 0.85, 0.18)

		var estouro := GoroFX.sparks(420, 1.1, Vector3.UP, 80.0, 14.0, 30.0, 0.9)
		col.add_child(estouro)

		if is_instance_valid(_luz):
			_luz.position = Vector3(0, 4.0, 0)
			_luz.base_energy = 30.0

		var mundo := get_tree().current_scene if get_tree() else null
		if mundo:
			var zona := DamageZone.new()
			mundo.add_child(zona)
			zona.global_position = global_position + Vector3.UP * 1.2
			# ⚠️ A velocidade era `Vector3.UP * 15.0`: em 3,2 s de vida a hitbox
			# subia 48 m e abandonava a coluna no primeiro instante. Agora ela fica
			# ONDE O RAIO CAIU. Dano, knockback, vida e raio continuam os de antes.
			# A COLUNA FINAL é a única que arremessa — é o clímax do golpe.
			# A COLUNA vale o dobro de um raio (`partes.coluna`): é o clímax do golpe
			# e a única parte que arremessa.
			zona.setup(spec.parte("coluna", spec.dano * 2.0), 22.0, Vector3.ZERO, 3.2, caster, 3.5)
			# Clímax: gasta a `reserva`. Os 11 raios que caem antes só enxergam
			# `teto - reserva`, então sempre sobra orçamento para a coluna.
			spec.marcar(zona, true)
			AudioFX.cannon(mundo, global_position, 0.34)
			AudioFX.impact(mundo, global_position, 0.5)
			# A assinatura da fruta entra na COLUNA, o clímax do X — não na
			# abertura: o estalo do `elthor` precisa coincidir com o que a tela
			# mostra, e o que a tela mostra aqui é a coluna descendo.
			GoroAudio.play(mundo, global_position, "elthor")
			GoroFX._screen_flash(mundo, Color(1.0, 1.0, 0.85), 0.75)
		GoroFX._shake(caster, 0.7)

		# A coluna se fecha em ~0,9 s e vira brasa; o clarão do chão fica mais um
		# pouco, que é o tempo em que a hitbox ainda vale.
		var tw := col.create_tween().set_parallel(true)
		tw.tween_property(col, "scale", Vector3(0.02, 1.0, 0.02), 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(col.queue_free)

	func _dissipar() -> void:
		if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == "el_thor":
			caster.set_meta("custom_pose", "")
		var tw := create_tween().set_parallel(true)
		if is_instance_valid(_nuvem):
			tw.tween_property(_nuvem, "scale", Vector3(1.9, 0.25, 1.9), 0.75).set_trans(Tween.TRANS_SINE)
		for m in _mats:
			GoroFX.dissipar_material(tw, m, 0.75)
		if is_instance_valid(_luz):
			tw.tween_property(_luz, "base_energy", 0.0, 0.7)
		tw.chain().tween_callback(queue_free)

	func _exit_tree() -> void:
		if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == "el_thor":
			caster.set_meta("custom_pose", "")


# ============================================================================
#  V — MAMARAGAN
# ============================================================================
# Entrada CARREGÁVEL: devolve o controlador para quem vai segurá-lo. O golpe
# começa na hora (a execução 3D nasce no CLIQUE, como o dono pediu) e só é
# liberado por `soltar()`.
static func mamaragan_carregado(world: Node, origin: Vector3, dir: Vector3,
		damage: float, caster: Node, spec: DamageSpec = null) -> Node:
	var c := _novo_mamaragan(world, origin, dir, damage, caster, spec)
	c.segurando = true
	return c

static func mamaragan(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null, charge: float = 0.0) -> void:
	_novo_mamaragan(world, origin, dir, damage, caster, spec, charge)

# Monta o golpe e devolve o controlador. Separado porque a versão CARREGÁVEL
# precisa da referência para poder soltar depois.
static func _novo_mamaragan(world: Node, origin: Vector3, dir: Vector3,
		damage: float, caster: Node, spec: DamageSpec = null,
		charge: float = 0.0) -> MamaraganController:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd: Vector3 = dir.normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, -1)

	# ⚠️ NENHUM `lock_movement` DESDE 2026-09-12. O golpe deixou de acontecer em
	# cima do jogador — ele aponta, a tempestade se junta longe e ele continua
	# jogando. Decisão do dono na remodelação; travar aqui devolveria o custo que
	# a remodelação tirou de propósito.
	if is_instance_valid(caster):
		caster.set_meta("custom_pose", "mamaragan")

	# ONDE A TEMPESTADE VAI CAIR: o mesmo raycast do El Thor, que segue a mira e
	# desce até o chão. Sem isto o golpe cairia sempre à frente do peito, que é
	# justamente o defeito que o El Thor já teve.
	var alvo := _ponto_de_mira(world, origin, fwd, MamaraganController.ALCANCE_MIRA, caster)

	var ctrl := MamaraganController.new(origin, fwd, damage, caster, spec)
	ctrl.alvo = alvo
	# ⚠️ CARGA VINDA DA REDE (2026-08-22). Quando o golpe chega por
	# `_net_play_cast`, a carga JÁ ACONTECEU na tela de quem conjurou — o
	# `MamaraganChargeNode` desenhou nuvens, orbe e flutuação lá, e mandou o
	# tempo junto. Aqui a linha do tempo pula direto para o arremesso: replayá-la
	# do zero atrasaria a bola em 3,3 s depois da soltura, que é o oposto do que
	# o jogador acabou de pedir.
	if charge > 0.0:
		var t_max: float = spec.tempo_de_carga if spec.tempo_de_carga > 0.0 else 3.0
		ctrl.travar_carga(clampf(charge / t_max, 0.0, 1.0))
		# A carga JÁ FOI VISTA na tela de quem conjurou: as nuvens deste caminho
		# nascem prontas. Sem isto elas apareceriam em escala 0,02 no mesmo quadro
		# em que a bola despenca, e a queda sairia de um céu vazio.
		ctrl.ceu_imediato = true
	world.add_child(ctrl)
	FxUtil.autofree(ctrl, MamaraganController.TOTAL + 1.6)   # rede de segurança
	return ctrl


# ---------------------------------------------------------------------------
#  ThunderOrb — A BOLA AZUL-ESCURA.
#
#  TUDO é construído em RAIO 1.0 e a carga só mexe na ESCALA DO NÓ. É por isso
#  que ela cresce sem retrabalho: quando o charge-up existir, o Player chama
#  `set_charge(t)` a cada quadro e a bola inteira acompanha.
#
#  Camadas (6):
#    1. núcleo azul-escuro quase opaco  (a "bola azul-escura" do pedido)
#    2. casca azul translúcida em volta (dá profundidade e borda)
#    3+4. dois anéis elétricos girando em eixos diferentes (amarelo-branco)
#    5. gaiola de 3 raios contornando a esfera, tremendo o tempo todo
#    6. luz azul pulsante por dentro + partículas sendo SUGADAS para o centro
# ---------------------------------------------------------------------------
class ThunderOrb extends Node3D:
	const RAIO_MIN := 0.30    # bola recém-nascida
	const RAIO_MAX := 2.30    # bola COMPLETA (pronta para arremessar)

	var carga := 0.0
	var _anel1: MeshInstance3D
	var _anel2: MeshInstance3D
	var _gaiola: Node3D
	var _luz: GoroFX.Flicker
	var _t := 0.0

	# A CURVA da carga -> raio. Trocar aqui muda o crescimento inteiro.
	static func raio_para_carga(t: float) -> float:
		return lerpf(RAIO_MIN, RAIO_MAX, clampf(t, 0.0, 1.0))

	func _ready() -> void:
		var nucleo := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 24
		sm.rings = 14
		nucleo.mesh = sm
		nucleo.material_override = GoroFX.storm_material(GoroFX.STORM_NAVY)
		add_child(nucleo)

		var casca := MeshInstance3D.new()
		var sm2 := SphereMesh.new()
		sm2.radius = 1.28
		sm2.height = 2.56
		sm2.radial_segments = 20
		sm2.rings = 12
		casca.mesh = sm2
		casca.material_override = GoroFX.storm_material(GoroFX.STORM_BLUE)
		add_child(casca)

		_anel1 = _anel(1.45, 0.10, GoroFX.ELECTRIC_YELLOW, 7.0)
		add_child(_anel1)
		_anel2 = _anel(1.62, 0.07, GoroFX.LIGHTNING_CYAN, 5.0)
		_anel2.rotation_degrees = Vector3(58, 0, 34)
		add_child(_anel2)

		_gaiola = Node3D.new()
		add_child(_gaiola)
		for i in range(3):
			var a := (float(i) / 3.0) * TAU
			var p := Vector3(cos(a) * 1.15, 0.9, sin(a) * 1.15)
			var b := GoroFX.Bolt.new(p, -p, GoroFX.FLASH_WHITE, 9.0, 12, 0.55, 0.075, 1)
			b.flick = 0.045
			_gaiola.add_child(b)

		_luz = GoroFX.Flicker.new(GoroFX.STORM_GLOW, 9.0, 12.0)
		_luz.velocidade = 16.0
		add_child(_luz)

		# Partículas SUGADAS para dentro (velocidade negativa = vêm de fora).
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 3.4
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = -5.0
		pm.initial_velocity_max = -9.0
		pm.scale_min = 0.25
		pm.scale_max = 0.7
		pm.color_ramp = FxUtil.gradient([GoroFX.FLASH_WHITE, GoroFX.ELECTRIC_YELLOW, GoroFX.STORM_GLOW, Color(0, 0, 0, 0)])
		add_child(FxUtil.particles(180, 0.5, false, pm, FxUtil.grain(0.32)))

		set_charge(carga)

	func _anel(raio: float, grossura: float, cor: Color, energia: float) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = raio - grossura
		tm.outer_radius = raio
		tm.rings = 36
		tm.ring_segments = 10
		mi.mesh = tm
		mi.material_override = GoroFX.volt_material(cor, energia)
		return mi

	# ⚡ ESTE É O PONTO DE ENGATE DO CHARGE-UP FUTURO.
	# `t` em 0..1. 0 = bola recém-nascida, 1 = COMPLETA (pode ser arremessada).
	func set_charge(t: float) -> void:
		carga = clampf(t, 0.0, 1.0)
		var r := raio_para_carga(carga)
		scale = Vector3(r, r, r)
		if is_instance_valid(_luz):
			_luz.base_energy = 4.0 + 12.0 * carga
			_luz.velocidade = 10.0 + 22.0 * carga

	func esta_completa() -> bool:
		return carga >= 0.999

	func _process(delta: float) -> void:
		_t += delta
		var vel: float = 1.6 + 5.0 * carga
		if is_instance_valid(_anel1):
			_anel1.rotation.y += vel * delta
			_anel1.rotation.x += vel * 0.35 * delta
		if is_instance_valid(_anel2):
			_anel2.rotation.y -= vel * 1.3 * delta
		if is_instance_valid(_gaiola):
			_gaiola.rotation.y += vel * 0.8 * delta
			_gaiola.rotation.z += vel * 0.4 * delta


# ---------------------------------------------------------------------------
#  MamaraganController — a cerimônia inteira.
#
#  ⚠️ REMODELADO EM 2026-09-12. Antes o golpe era um ARREMESSO HORIZONTAL: as
#  nuvens nasciam sobre o JOGADOR, ele flutuava preso, a bola crescia entre as
#  mãos e voava reto na direção da mira (`VEL 27`) até bater em alguma coisa.
#  Hoje é ARTILHARIA VERTICAL, por decisão do dono: as nuvens se juntam sobre o
#  PONTO DE MIRA, a bola cresce lá em cima e CAI. O jogador fica livre o tempo
#  todo — não flutua e não trava.
#
#  Linha do tempo (≈4,6 s, tudo livre da cena até ~5,6 s):
#    0,00  acha o ponto de mira no chão (até 60 m, igual ao El Thor) e abre ali
#          uma MARCA DE AVISO; 7 nuvens azul-escuras se juntam num anel de 7 m
#          a 14 m ACIMA dela, cada uma com atraso próprio; o anel gira devagar
#    0,35  sai do BRAÇO do jogador uma corrente elétrica até as nuvens — o elo
#          que mostra quem está canalizando, e de onde, para quem estiver perto
#    0,60  a BOLA AZUL-ESCURA começa a se formar no centro do anel, lá em cima
#    2,90  a bola fica COMPLETA -> clarão, anel de choque e trovão
#    3,30  SOLTA: a bola despenca na vertical, acelerando, e detona no chão
#    4,60  as nuvens se abrem; o controlador se liberta
#
#  A carga não mudou de regra: segurar faz a bola crescer (512 -> 768 de dano) e
#  soltar derruba. Levar dano DISPARA em vez de cancelar — ver PEDIDO_2026-08-12.
# ---------------------------------------------------------------------------
class MamaraganController extends Node3D:
	const NUVENS       := 7
	const ALCANCE_MIRA := 60.0    # o mesmo do El Thor
	const ALT_NUVENS   := 14.0    # altura das nuvens ACIMA DO ALVO
	const RAIO_ANEL    := 7.0     # anel concentrado sobre o alvo, não sobre o mapa
	const T_CORRENTES  := 0.35
	const T_ORB        := 0.60
	const T_CARGA      := 2.30    # quanto leva para a bola ficar COMPLETA
	const T_LANCA      := 3.30
	const LIBERA_EM    := 3.30    # o jogador nunca é travado; mantido p/ a rede
	const TOTAL        := 4.60

	var damage: float
	var caster: Node
	var fwd: Vector3
	## Ponto NO CHÃO sobre o qual as nuvens se juntam. É o centro de tudo: o anel
	## nasce acima dele, a bola cai nele e a marca de aviso fica nele.
	var alvo := Vector3.ZERO
	## Caminho de REDE: a carga já foi vista na tela de quem conjurou, então as
	## nuvens precisam nascer PRONTAS em vez de crescerem de novo do zero.
	var ceu_imediato := false
	var _t := 0.0
	var _completou := false
	var _lancou := false
	var _fechou := false
	var _marca: Node3D = null
	var _som_carga: AudioStreamPlayer3D = null
	var _marca_mat: ShaderMaterial = null
	var _pose_t := 0.0

	# ---------------------------------------------------- CHARGE-UP (tarefa 5)
	# `segurando` = a linha do tempo PARA no fim da carga e espera a tecla soltar.
	# Sem isto o golpe é um relógio: nasce, carrega e lança sozinho.
	#
	# ⚠️ A regra que o dono definiu: soltar OU levar dano libera — e o dano libera
	# **com a carga que tiver**, ao contrário de todas as outras skills, que são
	# canceladas pelo dano. Está no docs/PEDIDO_2026-08-12.md.
	var segurando := false
	var _carga_travada := 0.0
	var _ceu: Node3D
	var _orb: ThunderOrb
	var _correntes: Array = []
	var _ancoras: Array = []
	var _mats: Array = []

	var spec: DamageSpec = null

	func _init(origem: Vector3, direcao: Vector3, dmg: float, c: Node, s: DamageSpec = null) -> void:
		damage = dmg
		caster = c
		spec = s if s != null else DamageSpec.avulso(dmg)
		fwd = direcao
		position = origem

	func _ready() -> void:
		# O controlador MORA no alvo, não no jogador: tudo que ele desenha é em
		# volta do ponto que vai ser atingido, e o jogador pode sair andando.
		global_position = alvo

		# ---- AS NUVENS SE JUNTANDO NO CÉU, ACIMA DO ALVO ----
		_ceu = Node3D.new()
		add_child(_ceu)
		for i in range(NUVENS):
			var a: float = (float(i) / float(NUVENS)) * TAU
			var pivo := Node3D.new()
			_ceu.add_child(pivo)
			pivo.position = Vector3(cos(a) * RAIO_ANEL, ALT_NUVENS + randf_range(-1.2, 1.2), sin(a) * RAIO_ANEL)
			for camada in range(2):
				var interna: bool = camada == 0
				var mm := GoroFX.storm_cloud(
					4.6 * (0.7 if interna else 1.0),
					10 if interna else 13,
					GoroFX.STORM_NAVY if interna else GoroFX.STORM_BLUE,
					0.5 if interna else 0.4)
				pivo.add_child(mm)
				_mats.append(mm.material_override)
			if ceu_imediato:
				pivo.scale = Vector3.ONE
			else:
				pivo.scale = Vector3(0.02, 0.02, 0.02)
				var tw := pivo.create_tween()
				tw.tween_interval(float(i) * 0.055)
				tw.tween_property(pivo, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if i < 2:
				_ancoras.append(pivo)

		for i in range(3):
			var a2: float = (float(i) / 3.0) * TAU
			var luz := GoroFX.Flicker.new(GoroFX.STORM_GLOW, 10.0, 38.0)
			_ceu.add_child(luz)
			luz.position = Vector3(cos(a2) * RAIO_ANEL * 0.8, ALT_NUVENS - 2.0, sin(a2) * RAIO_ANEL * 0.8)

		_abrir_marca()

		var mundo := get_tree().current_scene if get_tree() else null
		if mundo:
			AudioFX.cannon(mundo, global_position + Vector3.UP * ALT_NUVENS, 0.35)
			AudioFX.whoosh(mundo, global_position, 0.4)
			GoroFX._screen_flash(mundo, Color(0.3, 0.45, 1.0), 0.35)
		GoroFX._shake(caster, 0.35)

	## A MARCA DE AVISO no chão. Um golpe que cai de cima sem anunciar onde vai
	## cair não tem contra-jogo: quem está embaixo precisa poder sair.
	##
	## ⚠️ NÃO usa `GoroFX.shock_ring`: aquele anel nasce para SUMIR (tween até
	## alpha 0 e `queue_free`), e esta marca precisa ficar enquanto a bola
	## carrega. Passar `grossura = 0.0` para ele ainda degenera o TorusMesh
	## (`inner_radius == outer_radius`) e suja o log com
	## "_create_mesh_array must return at least a vertex array".
	func _abrir_marca() -> void:
		_marca = Node3D.new()
		add_child(_marca)
		_marca.position = Vector3(0, 0.06, 0)

		# Um PLANO no chão, não um torus: o `goro_marca.gdshader` desenha aro,
		# raias e o pulso a partir da UV, então precisa de uma superfície com UV
		# 0..1 — e um plano paga 2 triângulos onde o torus pagava centenas.
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(RAIO_ANEL * 2.0, RAIO_ANEL * 2.0)
		mi.mesh = pm
		_marca_mat = GoroFX.marca_material()
		mi.material_override = _marca_mat
		mi.scale = Vector3(0.05, 1.0, 0.05)
		_marca.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		var faisca := GoroFX.sparks(90, 1.2, Vector3.UP, 25.0, 1.0, 3.0, 0.30)
		faisca.one_shot = false
		_marca.add_child(faisca)

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(_ceu):
			_ceu.rotation.y += 0.32 * delta

		_seguir_mira(delta)

		# O RELÓGIO DA POSE. Enquanto canaliza, ele PARA no fim do gesto de erguer
		# (a pose sustenta) — a carga não tem duração prevista, quem decide é o
		# dedo do jogador. Depois de soltar, ele corre normalmente para o gesto de
		# derrubar acontecer inteiro.
		if is_instance_valid(caster):
			if _lancou:
				_pose_t += delta
			else:
				_pose_t = minf(_pose_t + delta, GoroPoses.DURATIONS[GoroPoses.MAMARAGAN])
			caster.set_meta("goro_pose_t", _pose_t)

		# `age` alimenta o pulso da marca e o relâmpago interno das nuvens.
		for m in _mats:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("age", _t)
		if is_instance_valid(_marca_mat):
			_marca_mat.set_shader_parameter("age", _t)

		if _t >= T_CORRENTES and _correntes.is_empty():
			_ligar_correntes()
		_atualizar_correntes()

		if _t >= T_ORB and _orb == null and not _lancou:
			_orb = ThunderOrb.new()
			add_child(_orb)
			_orb.set_charge(0.0)
			# O zumbido da carga sai DAS NUVENS, que é onde a bola cresce desde a
			# remodelação — não mais das mãos do jogador.
			_som_carga = GoroAudio.play(self, global_position + _pos_bola(), "carga")

		if is_instance_valid(_orb) and not _lancou:
			_orb.position = _pos_bola()
			_orb.set_charge(carga_atual())
			# As nuvens piscam por dentro no ritmo da carga: quem está embaixo lê
			# no céu quanto falta, sem precisar olhar o HUD de quem conjurou.
			for m in _mats:
				if m is ShaderMaterial:
					(m as ShaderMaterial).set_shader_parameter("charge", carga_atual())
			if is_instance_valid(_marca_mat):
				_marca_mat.set_shader_parameter("charge", carga_atual())
			if _orb.esta_completa() and not _completou:
				_completou = true
				_bola_completa()

		# SEGURANDO: a bola cresce até o teto e ESPERA. O tempo não avança para o
		# arremesso — quem decide o instante é o dedo do jogador.
		if segurando:
			_t = minf(_t, T_LANCA - 0.01)
		elif _t >= T_LANCA and not _lancou:
			_lancou = true
			_derrubar()

		if _t >= TOTAL - 0.9 and not _fechou:
			_fechou = true
			_fechar_ceu()

		if _t >= TOTAL:
			queue_free()

	# Quanto a bola já cresceu, de 0 a 1.
	# Fixa a carga e manda a linha do tempo direto para o arremesso. Usada pelo
	# caminho de REDE — ver `_novo_mamaragan`.
	func travar_carga(valor: float) -> void:
		_carga_travada = clampf(valor, 0.0, 1.0)
		segurando = false
		_t = T_LANCA

	func carga_atual() -> float:
		if _carga_travada > 0.0:
			return _carga_travada
		return clampf((_t - T_ORB) / T_CARGA, 0.0, 1.0)

	# SOLTAR: dispara na direção pedida, com a carga que houver.
	# `direcao` é a mira NO INSTANTE DA LIBERAÇÃO — não a de quando começou.
	func soltar(direcao: Vector3) -> void:
		if _lancou or not segurando:
			return
		segurando = false
		_carga_travada = carga_atual()
		if direcao.length_squared() > 0.01:
			fwd = direcao.normalized()
		# ⚠️ SOLTAR CEDO NÃO PODE DEIXAR O JOGADOR PRESO NO AR.
		#
		# O `lock_movement(LIBERA_EM)` foi armado para a duração CHEIA do golpe.
		# Quem soltava a tecla em 1 s ficava flutuando e travado até o prazo
		# original vencer — relatado jogando em 2026-08-12.
		#
		# Pular o tempo para o instante do arremesso resolve as duas pontas: a
		# bola sai agora, e a descida/destravamento vêm logo atrás, no ritmo que
		# a linha do tempo já previa.
		_t = T_LANCA

	# Já dá para arremessar? A bola só existe depois de T_ORB.
	func pode_soltar() -> bool:
		return is_instance_valid(_orb)

	## ENQUANTO CARREGA, A TEMPESTADE SEGUE A MIRA.
	##
	## Sem isto o alvo congelaria no instante do APERTO, e como a soltura manda
	## para a rede a mira do instante da LIBERAÇÃO, as nuvens carregariam num
	## lugar e a bola cairia em outro — o jogador veria o golpe mentir sobre onde
	## vai bater. Depois de soltar o alvo trava: quem está embaixo tem o anel no
	## chão como aviso, e ele não pode fugir junto com a mira.
	##
	## O raycast roda a cada INTERVALO_MIRA, não todo quadro; entre uma medida e
	## outra o nó desliza, senão a tempestade inteira pularia a cada leitura.
	const INTERVALO_MIRA := 0.08
	var _prox_mira := 0.0

	func _seguir_mira(delta: float) -> void:
		if not segurando or _lancou:
			return
		if not is_instance_valid(caster) or not caster.has_method("mira_do_cast"):
			return
		_prox_mira -= delta
		if _prox_mira <= 0.0:
			_prox_mira = INTERVALO_MIRA
			var mira: Dictionary = caster.mira_do_cast()
			var dir: Vector3 = mira.get("aim", fwd)
			var org: Vector3 = mira.get("origem", global_position)
			if dir.length_squared() > 0.01:
				fwd = dir.normalized()
				var mundo := get_tree().current_scene if get_tree() else null
				if mundo:
					alvo = GoroFXGrande._ponto_de_mira(mundo, org, fwd, ALCANCE_MIRA, caster)
		global_position = global_position.lerp(alvo, 1.0 - exp(-9.0 * delta))

	# ---- O ELO ELÉTRICO: DO BRAÇO DO JOGADOR ATÉ AS NUVENS ----
	## Duas correntes ligam as MÃOS do jogador a duas das nuvens. Depois da
	## remodelação elas atravessam a distância até o alvo (até 60 m, contra os
	## 15 m verticais de antes), por isso mais segmentos: um raio de 60 m com 20
	## segmentos vira uma linha reta e perde o tremor que o faz parecer elétrico.
	func _ligar_correntes() -> void:
		for i in range(2):
			var b := GoroFX.Bolt.new(Vector3.ZERO, Vector3(0, ALT_NUVENS, 0),
				GoroFX.ELECTRIC_YELLOW, 8.0, 34, 1.4, 0.16, 2)
			b.flick = 0.04
			add_child(b)
			_correntes.append(b)
			var crepitar := GoroFX.sparks(70, 0.5, Vector3.UP, 90.0, 1.5, 4.5, 0.26)
			crepitar.one_shot = false
			add_child(crepitar)
			_correntes.append(crepitar)

	func _atualizar_correntes() -> void:
		if _correntes.is_empty() or not is_instance_valid(caster) or not (caster is Node3D):
			return
		for i in range(2):
			var b = _correntes[i * 2]
			var fag = _correntes[i * 2 + 1]
			if not is_instance_valid(b):
				continue
			var mao := to_local(_mao(i == 0))
			(b as GoroFX.Bolt).from_p = mao
			if i < _ancoras.size() and is_instance_valid(_ancoras[i]):
				(b as GoroFX.Bolt).to_p = to_local((_ancoras[i] as Node3D).global_position)
			if is_instance_valid(fag):
				(fag as Node3D).position = mao

	# Posição aproximada de uma das mãos. Sai da MIRA (não da rotação do corpo):
	# o modelo do personagem gira num nó filho do Player, e alcançá-lo daqui seria
	# depender da estrutura interna dele.
	func _mao(esquerda: bool) -> Vector3:
		var base: Vector3 = (caster as Node3D).global_position
		var lado: Vector3 = fwd.cross(Vector3.UP).normalized()
		var s: float = -0.55 if esquerda else 0.55
		return base + Vector3(0, 1.45, 0) + lado * s + fwd * 0.15

	## A bola cresce NO CENTRO DO ANEL DE NUVENS, lá em cima — não mais entre as
	## mãos do jogador. Local, porque o controlador já mora no alvo.
	func _pos_bola() -> Vector3:
		return Vector3(0, ALT_NUVENS - 1.2, 0)

	func _bola_completa() -> void:
		var mundo := get_tree().current_scene if get_tree() else null
		if mundo:
			AudioFX.cannon(mundo, global_position, 0.4)
			GoroFX._screen_flash(mundo, Color(0.55, 0.7, 1.0), 0.5)
		GoroFX._shake(caster, 0.4)
		if is_instance_valid(_orb):
			GoroFX.shock_ring(self, _orb.position, GoroFX.LIGHTNING_CYAN, 9.0, 0.45, 0.15)

	## A QUEDA. Antes isto era `_arremessar()` e mandava a bola na horizontal, na
	## direção da mira. Agora ela despenca do centro do anel direto no alvo, e o
	## alvo já estava anunciado no chão desde o começo.
	func _derrubar() -> void:
		var mundo := get_tree().current_scene if get_tree() else null
		var origem: Vector3 = global_position + _pos_bola()
		if is_instance_valid(_orb):
			origem = _orb.global_position
			_orb.queue_free()
			_orb = null
		# O braço DESCE junto com a bola: troca do gesto de canalizar para o de
		# derrubar, com o relógio zerado para o novo gesto sair do início.
		if is_instance_valid(caster):
			caster.set_meta("custom_pose", GoroPoses.MAMARAGAN_SOLTA)
			_pose_t = 0.0
			caster.set_meta("goro_pose_t", 0.0)
			FxUtil.limpar_pose(caster, GoroPoses.MAMARAGAN_SOLTA,
				GoroPoses.DURATIONS[GoroPoses.MAMARAGAN_SOLTA])

		# O zumbido da carga acabou no instante em que a bola saiu: deixá-lo
		# rolando por cima da queda embola as duas leituras.
		if is_instance_valid(_som_carga):
			_som_carga.stop()
			_som_carga.queue_free()
			_som_carga = null
		# A marca cumpriu o papel de avisar; some junto com a queda.
		if is_instance_valid(_marca):
			var tw_marca := _marca.create_tween()
			tw_marca.tween_property(_marca, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
			FxUtil.autofree(_marca, 0.4)
			_marca = null
		for c in _correntes:
			if is_instance_valid(c) and c is GoroFX.Bolt:
				(c as GoroFX.Bolt).apagar(0.25)
			elif is_instance_valid(c) and c is GPUParticles3D:
				(c as GPUParticles3D).emitting = false
		_correntes.clear()
		if mundo:
			# A bola herda a spec do controlador: voo e detonação dividem o orçamento.
			#
			# O dano da DETONAÇÃO é o da carga no instante da soltura — a mesma
			# interpolação 512 -> 768 das outras duas skills carregáveis do jogo.
			# `carga_atual()` devolve 0..1 e `valor_do_hit` espera SEGUNDOS, daí a
			# multiplicação pelo tempo de carga da tabela.
			var dano_carregado := spec.valor_do_hit(carga_atual() * spec.tempo_de_carga)
			# `Vector3.DOWN`: a bola não é mais arremessada, ela CAI. O chão de
			# destino é o alvo — a bola detona ao alcançar aquela altura, não numa
			# altura fixa do mapa, senão ela atravessaria plataformas altas.
			var bola := MamaraganBall.new(origem, Vector3.DOWN, dano_carregado, caster, spec)
			bola.y_do_alvo = alvo.y
			mundo.add_child(bola)
			AudioFX.impact(mundo, origem, 0.55)
			AudioFX.whoosh(mundo, origem, 0.75)
		GoroFX._shake(caster, 0.45)

	func _fechar_ceu() -> void:
		var tw := create_tween().set_parallel(true)
		if is_instance_valid(_ceu):
			tw.tween_property(_ceu, "scale", Vector3(1.6, 0.3, 1.6), 0.85).set_trans(Tween.TRANS_SINE)
		for m in _mats:
			GoroFX.dissipar_material(tw, m, 0.85)

	## Limpeza da marca de pose. Desde a remodelação de 2026-09-12 o jogador NÃO
	## é mais travado nem suspenso por este golpe — não há aderência ao chão nem
	## `lock_movement` para desfazer, só a `custom_pose` a devolver.
	func _liberar_jogador() -> void:
		if not is_instance_valid(caster):
			return
		var atual := str(caster.get_meta("custom_pose", ""))
		if atual == GoroPoses.MAMARAGAN or atual == GoroPoses.MAMARAGAN_SOLTA:
			caster.set_meta("custom_pose", "")
		# ⚠️ A META DO RELÓGIO TEM DE SAIR JUNTO. O V é o único golpe que publica
		# `goro_pose_t`, e quando este controlador morre ninguém mais a atualiza:
		# deixá-la no ator faria o PRÓXIMO golpe da Goro nascer com o relógio
		# parado num valor velho — a pose congelaria no quadro errado.
		caster.remove_meta("goro_pose_t")

	func _exit_tree() -> void:
		_liberar_jogador()


# ---------------------------------------------------------------------------
#  MamaraganBall — a bola COMPLETA voando e o estouro no fim.
# ---------------------------------------------------------------------------
class MamaraganBall extends Node3D:
	## A bola CAINDO. Até 2026-09-12 ela era arremessada na horizontal a 27 m/s e
	## morria por tempo ou ao passar de y = 0,7. Agora despenca acelerando, e o
	## fim dela é o CHÃO DO ALVO — o `y_do_alvo` que o controlador passa.
	const VEL_INICIAL := 9.0
	const GRAVIDADE   := 38.0
	const VEL_MAX     := 62.0
	const VIDA        := 2.2      # rede de segurança, não o fim esperado

	var dir: Vector3
	var damage: float
	var caster: Node
	## Altura do chão no ponto visado. A bola detona ao alcançá-la, em vez de uma
	## altura fixa do mapa: assim o golpe funciona em cima de plataforma também.
	var y_do_alvo := 0.7
	var _vel := VEL_INICIAL
	var _t := 0.0
	var _morreu := false
	var _tocou_som := false

	## O `goro_mamaragan.wav` tem o assobio da queda nos primeiros 384 ms e só
	## então o estalo do impacto (medido no arquivo, não estimado). Tocá-lo ao
	## SAIR da nuvem adiantaria a batida em ~0,2 s, porque a queda leva ~0,6 s.
	## Então ele entra quando faltar exatamente esse tempo para o chão.
	const SOM_ANTES_DO_IMPACTO := 0.384

	var spec: DamageSpec = null

	func _init(origem: Vector3, direcao: Vector3, dmg: float, c: Node, s: DamageSpec = null) -> void:
		position = origem
		dir = direcao.normalized()
		damage = dmg
		caster = c
		spec = s if s != null else DamageSpec.avulso(dmg)

	func _ready() -> void:
		var orb := ThunderOrb.new()
		add_child(orb)
		orb.set_charge(1.0)

		var rastro := GoroFX.sparks(200, 0.45, -dir, 40.0, 4.0, 12.0, 0.5)
		rastro.one_shot = false
		add_child(rastro)

		# A hitbox viaja PRESA à bola (vel = ZERO + o pai andando): assim ela não
		# descola do visual como acontecia na coluna do El Thor.
		var zona := DamageZone.new()
		add_child(zona)
		# A bola em VOO fere quem ela atravessa (`partes.orbe`); o grosso do golpe
		# é a detonação. Era `damage * 0.6` escrito aqui dentro.
		zona.setup(spec.parte("orbe", 256.0), 26.0, Vector3.ZERO, VIDA + 0.05, caster, 2.6)
		spec.marcar(zona)

	func _process(delta: float) -> void:
		if _morreu:
			return
		_t += delta
		# Acelera enquanto cai: o peso do golpe se lê na velocidade crescendo.
		_vel = minf(_vel + GRAVIDADE * delta, VEL_MAX)
		global_position += dir * _vel * delta

		if not _tocou_som:
			var falta: float = global_position.y - (y_do_alvo + 0.6)
			if _vel > 0.01 and falta / _vel <= SOM_ANTES_DO_IMPACTO:
				_tocou_som = true
				var cena := get_tree().current_scene if get_tree() else null
				if cena:
					GoroAudio.play(cena, Vector3(global_position.x, y_do_alvo, global_position.z),
						"mamaragan")
		if _t >= VIDA or global_position.y <= y_do_alvo + 0.6:
			_morreu = true
			_detonar()

	func _detonar() -> void:
		set_process(false)
		var mundo := get_tree().current_scene if get_tree() else null
		if mundo == null:
			queue_free()
			return
		var pos := global_position

		var boom := Node3D.new()
		mundo.add_child(boom)
		boom.global_position = pos

		GoroFX.shock_ring(boom, Vector3.ZERO, GoroFX.FLASH_WHITE, 22.0, 0.5)
		GoroFX.shock_ring(boom, Vector3(0, 0.2, 0), GoroFX.LIGHTNING_CYAN, 34.0, 0.8, 0.16)
		boom.add_child(GoroFX.sparks(520, 1.0, Vector3.UP, 90.0, 16.0, 34.0, 0.85))

		# Leque de raios saindo do ponto de impacto para o chão em volta.
		for i in range(6):
			var a: float = (float(i) / 6.0) * TAU + randf() * 0.4
			var alvo := Vector3(cos(a) * randf_range(6.0, 11.0), -pos.y + 0.2, sin(a) * randf_range(6.0, 11.0))
			var b := GoroFX.Bolt.new(Vector3.ZERO, alvo, GoroFX.ELECTRIC_YELLOW, 8.0, 14, 1.3, 0.30, 2)
			b.flick = 0.03
			boom.add_child(b)

		var luz := GoroFX.Flicker.new(GoroFX.FLASH_WHITE, 26.0, 40.0)
		luz.velocidade = 30.0
		boom.add_child(luz)
		var tw := boom.create_tween()
		tw.tween_interval(0.35)
		tw.tween_property(luz, "base_energy", 0.0, 0.5)
		FxUtil.autofree(boom, 1.5)

		var zona := DamageZone.new()
		mundo.add_child(zona)
		zona.global_position = pos
		# A DETONAÇÃO leva o valor da carga — mínimo 512, cheia 768.
		zona.setup(damage, 30.0, Vector3.ZERO, 0.5, caster, 12.0)
		spec.marcar(zona)

		AudioFX.cannon(mundo, pos, 0.3)
		AudioFX.impact(mundo, pos, 0.42)
		GoroFX._screen_flash(mundo, Color(1.0, 1.0, 0.9), 0.9)
		GoroFX._shake(caster, 0.85)
		queue_free()
