class_name BukiFX
extends RefCounted
const FxQualityPolicy = preload("res://src/effects/FxQuality.gd")
# ============================================================================
#  BUKI FX — Buki Buki no Mi (fruta da Baby 5). Paramecia: o corpo vira arma.
#
#  ⚠️ REGRA DA FRUTA — TROCADA PELO DONO DO PROJETO (2026-08-11).
#
#  ANTES: transformação INSTANTÂNEA no golpe (a arma nascia, disparava e sumia;
#  nada ficava ativo entre golpes). Essa regra MORREU — se você achar doc que
#  ainda a descreva, ela está velha.
#
#  AGORA a fruta é um JOGO DE FPS:
#    • a tecla do slot EMPUNHA a arma, e ela FICA na mão. SACAR NÃO ATIRA
#      (regra do dono, 2026-08-11): a arma sai com a munição CHEIA e o primeiro
#      tiro é decisão do jogador, no botão esquerdo;
#    • o botão ESQUERDO atira enquanto houver bala;
#    • MUNIÇÃO é a penalidade da fruta — cada arma tem um número fixo de balas;
#    • acabou a bala (ou trocou de slot) -> a arma some e AQUELE slot entra em
#      recarga. É isso que empurra o jogador pro rodízio de armas.
#    • botão DIREITO = auxílio de mira (habilidade ativa da fruta), MENOS na
#      sniper, onde ele vira luneta e o auxílio fica desligado.
#
#  ARSENAL:
#   Z: Pistola  —  12 balas, mão direita.
#   X: Canhão   —   3 tiros, o jogador vira o canhão INTEIRO (corpo some).
#   C: Sniper   —   5 tiros, braço vira fuzil de precisão (+ luneta no Bt Dir).
#   V: Minigun  — 100 balas, cadência absurda, dano por bala ridículo.
#
#  A máquina de estado (empunhar / trocar / acabar munição), a munição e a rede
#  vivem no Player.gd — aqui só mora a APARÊNCIA e o disparo. Ver:
#  `Player._buki_empunhar`, `_process_buki_arma`, `_do_server_bullet`.
# ============================================================================

# ---------------------------------------------------------------- O ARSENAL
# Uma linha por slot. `balas` é a penalidade da fruta; `cadencia` é o intervalo
# mínimo entre disparos (segundos). O dano POR BALA vem de `src/combat/Balance.gd`
# e sai de `teto do slot / nº de balas` — é por isso que o minigun tem bala fraca
# e o canhão bala pesada sem que nenhum dos dois passe do teto.
# (o `dano_mult` que este comentário citava nunca existiu no dicionário abaixo.)
#
# `som` e `fogacho` entraram em 2026-08-11, junto com a munição com cara própria
# (ver src/effects/BukiProjeteis.gd). Antes o slot escolhia o som e o tamanho do
# clarão num `if slot == "X" ... else` espalhado pelo `disparo`; com quatro armas
# distintas isso vira escada de exceção. Aqui é uma linha por arma, do calibre ao
# som — mudar a identidade de uma arma é editar uma linha.
const ARSENAL := {
	"Z": {"nome": "Pistola", "balas": 12,  "cadencia": 0.20, "raio": 0.18, "vel": 42.0, "kb": 4.0,  "shake": 0.12, "recuo": 0.0,  "papel": "ForeArm_R", "som": "pistol",  "fogacho": 0.34},
	"X": {"nome": "Canhão",  "balas": 3,   "cadencia": 0.95, "raio": 0.55, "vel": 22.0, "kb": 24.0, "shake": 0.90, "recuo": 11.0, "papel": "",          "som": "cannon",  "fogacho": 1.00},
	# ⚠️ `vel` da sniper (95 -> 125 em 2026-08-13, a pedido do dono: "quase
	# instantânea"). O TETO NÃO É DE GOSTO, É DE FÍSICA: a DamageZone anda por
	# teleporte (`global_position += vel * delta`, 60 Hz) e a Area3D só percebe
	# quem estiver sobreposto NO QUADRO. Com raio 0,16 contra o colisor de 1,0 m
	# do jogador, a janela de acerto tem 1,32 m -> acima de 79 m/s a bala começa
	# a ATRAVESSAR o alvo entre dois quadros. Medido (24 fases, tiro frontal no
	# centro): 79->24/24, 95->20/24, 110->17/24, 125->16/24, 200->9/24.
	# Enquanto a DamageZone não andar em sub-passos, subir daqui é trocar
	# consistência por velocidade (o dano ESPERADO não muda: acima de 79 m/s
	# velocidade x chance de acerto é constante).
	"C": {"nome": "Sniper",  "balas": 5,   "cadencia": 1.05, "raio": 0.16, "vel": 250.0, "kb": 10.0, "shake": 0.45, "recuo": 0.0,  "papel": "ForeArm_R", "som": "sniper",  "fogacho": 0.55},
	"V": {"nome": "Minigun", "balas": 100, "cadencia": 0.06, "raio": 0.14, "vel": 46.0, "kb": 1.6,  "shake": 0.05, "recuo": 0.0,  "papel": "ForeArm_R", "som": "minigun", "fogacho": 0.18},
}
const SLOTS := ["Z", "X", "C", "V"]

static func municao(slot: String) -> int:
	return int(ARSENAL[slot]["balas"]) if ARSENAL.has(slot) else 0

static func cadencia(slot: String) -> float:
	return float(ARSENAL[slot]["cadencia"]) if ARSENAL.has(slot) else 0.5

static func nome_da_arma(slot: String) -> String:
	return str(ARSENAL[slot]["nome"]) if ARSENAL.has(slot) else ""

# Onde a arma se pendura: "" = no CORPO INTEIRO (o X vira canhão).
static func papel_do_slot(slot: String) -> String:
	return str(ARSENAL[slot]["papel"]) if ARSENAL.has(slot) else ""

const ACO := Color(0.74, 0.78, 0.84)
const ACO_QUENTE := Color(1.0, 0.72, 0.30)
const FAISCA := [
	Color(1.0, 0.95, 0.7, 1.0),
	Color(1.0, 0.7, 0.25, 0.9),
	Color(0.7, 0.35, 0.1, 0.4),
	Color(0.3, 0.3, 0.3, 0.0),
]

const ALCANCE_MIRA := 60.0     # alcance da busca de alvo teleguiado
const CONE_MIRA := 0.82        # cos do cone de aquisição (~35°)

# Entrada do `Player._fire_skill` — UM disparo do slot.
#
# ⚠️ Em JOGO ninguém passa por aqui: com a fruta equipada, `begin_charge` e
# `cast_skill_slot` desviam para `_buki_empunhar` e voltam antes do
# `_request_cast`. Quem chega neste `cast` é a AUDITORIA
# (tools/dev_tests/test_frutas.gd), que chama `_fire_skill` direto — e é por isso
# que os 4 slots continuam contando "hitbox: SIM" lá.
# Mantido de propósito: é a única prova automática de que os quatro slots ainda
# produzem DamageZone de verdade, munição à parte.
static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	var slot: String = SLOTS[variant] if variant >= 0 and variant < SLOTS.size() else "Z"
	disparo(world, origin, dir, slot, damage, caster, null, spec)

# UM TIRO da arma empunhada. Chamado no saque (via `cast`) e a cada clique do
# botão esquerdo (via `Player._net_bullet_play`, que nasce no SERVIDOR).
static func disparo(world: Node, origin: Vector3, dir: Vector3, slot: String,
		damage: float, caster: Node, alvo: Node3D = null, spec: DamageSpec = null) -> void:
	if world == null or not (world is Node) or not world.is_inside_tree():
		return
	var d: Dictionary = ARSENAL.get(slot, ARSENAL["Z"])
	_projetil(world, origin, dir, damage, caster, slot, alvo, spec)
	_fogacho(world, origin, dir, float(d.get("fogacho", 0.35)))
	_som(world, origin, str(d.get("som", "pistol")))
	if slot != "X":
		_capsulas(world, origin, dir)   # latão saltando: dá cadência VISÍVEL à rajada

# O som é da ARMA, não "tiro genérico" (2026-08-11). A janela de pitch também
# muda por arma: o canhão quase não varia (±4%) porque calibre grande soa igual
# toda vez; o minigun varia ±14%, que é o que impede 17 tiros por segundo de
# virarem um bipe único.
static func _som(world: Node, origin: Vector3, som: String) -> void:
	match som:
		"cannon":  AudioFX.cannon(world, origin, randf_range(0.96, 1.04))
		"sniper":  AudioFX.sniper(world, origin, randf_range(0.97, 1.03))
		"minigun": AudioFX.minigun(world, origin, randf_range(0.86, 1.14))
		_:         AudioFX.pistol(world, origin, randf_range(0.94, 1.08))

# ----------------------------------------------------------------- MATERIAIS
static func _mat_aco(emissivo: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ACO
	m.metallic = 0.95
	m.roughness = 0.28
	if emissivo:
		m.emission_enabled = true
		m.emission = ACO_QUENTE
		m.emission_energy_multiplier = 2.2
	return m

# ------------------------------------------------------- ANEXO NO MEMBRO
# Acha o membro no rig e pendura a arma nele. Funciona nos dois tipos de
# personagem: no voxel os papéis são nós; no skinnado o BodyScanner criou
# proxies com os mesmos nomes (ver src/anim/SkeletonDriver.gd).
#
# ⚠️ No skinnado o proxy GIRA com a animação mas não TRANSLADA: ele fica parado
# na posição de repouso do osso, e quem se move de verdade é o osso dentro do
# Skeleton3D. Então a arma nasce no lugar certo do corpo e acompanha a rotação
# do membro, mas não segue o osso quando o pai o desloca. Se um dia isso
# incomodar, o caminho é um BoneAttachment3D — e aí cuidado: ele herda a escala
# e o espaço Z-up do esqueleto, o que não vale pros proxies.
static func _membro(caster: Node, papel: String) -> Node3D:
	if caster == null:
		return null
	var m = caster.get("_char_model")
	if m is Node3D:
		var n = (m as Node3D).find_child(papel, true, false)
		if n is Node3D:
			return n
	# Fallback: procura o papel em qualquer lugar sob o conjurador. Cobre quem
	# guarda o modelo com outro nome e o caso do rig skinnado (proxies).
	var d = caster.find_child(papel, true, false)
	return d as Node3D if d is Node3D else null

# ============================================================================
#  AS ARMAS EMPUNHADAS
#
#  ⚠️ Elas são construídas UMA VEZ (junto com o personagem, em
#  `PlayerRig._attach_buki_arsenal`) e depois só ligam/desligam a visibilidade —
#  como já era a pistola da rajada Z. Fazer nascer/morrer nó a cada saque
#  transformava arma empunhada em "vazamento de nó" na auditoria e enchia a
#  cena de lixo a cada troca.
#
#  Convenção de eixo: os .glb do Blender apontam pra −Z; a MÃO do rig usa −Y
#  (é o eixo do antebraço, e é onde a pistola do jogo já mira). Por isso as
#  armas de braço nascem com rotation.x = −90°, que leva −Z em −Y. Sem isso a
#  arma aponta pro lado enquanto a pose de mira aponta pra frente.
# ============================================================================
static func arma_do_slot(slot: String) -> Node3D:
	match slot:
		"Z": return _montar_pistola()
		"X": return _montar_canhao_corpo()
		"C": return _montar_sniper()
		"V": return _montar_minigun()
	return null

# Z — a MÃO vira pistola. Reusa a mesma peça da pistola do jogo (PlayerModelKit),
# que já nasce com o cano em −Y: nada a girar aqui.
static func _montar_pistola() -> Node3D:
	var g := PlayerModelKit.build_pistol()
	g.name = "BukiArma_Z"
	g.position = Vector3(0, -0.36, 0.02)
	return g

# C — SNIPER. ⚠️ NÃO EXISTE .glb de sniper (ver relatório): esticamos a
# metralhadora no eixo do cano e pregamos uma luneta em cima. É um remendo
# C — SNIPER: modelo próprio (`buki_sniper.glb`), feito no Blender em
# `tools/blender/buki_weapons.py`. Antes era a metralhadora esticada 1,75× com
# uma luneta colada por cima — funcionava, mas de longe lia como "a mesma arma
# de sempre, só maior", que é justamente o que uma sniper não pode ser.
#
# O que o modelo próprio dá e o esticão não dava: cano longo E FINO (é a
# proporção que diz "precisão"), luneta com os dois corpos de lente, freio de
# boca e guarda-mão com respiros.
static func _montar_sniper() -> Node3D:
	var r := _arma("sniper")
	r.name = "BukiArma_C"
	r.rotation_degrees.x = -90.0
	r.position = Vector3(0, -0.30, 0)
	return r

static func _montar_minigun() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiArma_V"
	var corpo := _arma("metralhadora")
	corpo.scale = Vector3(1.35, 1.35, 1.15)
	r.add_child(corpo)
	r.rotation_degrees.x = -90.0
	r.position = Vector3(0, -0.30, 0)
	return r

# X — o jogador vira o CANHÃO INTEIRO. Este nó não mora no braço: mora num pivô
# preso ao corpo (o Player esconde o modelo enquanto o canhão está empunhado).
static func _montar_canhao_corpo() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiArma_X"
	var corpo := _arma("canhao")
	corpo.scale = Vector3(1.6, 1.6, 2.0)     # ~0.67 x 0.74 x 2.0 m: lê como canhão de gente
	r.add_child(corpo)
	return r

# O AÇO SE ESPALHANDO PELA PELE — é isto que faz a fruta ler como "o corpo virou
# arma" em vez de "apareceu uma arma na mão". Um anel incandescente desce pelo
# membro no instante da transformação, com fagulhas atrás.
#
# Fica preso ao MEMBRO (não ao mundo), então acompanha o braço no meio do golpe.
static func onda_de_aco(membro: Node) -> void:
	if not (membro is Node3D):
		return
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.10
	toro.outer_radius = 0.19
	toro.rings = 12
	anel.mesh = toro
	var m := StandardMaterial3D.new()
	m.albedo_color = FxUtil.brilho(Color(1.0, 0.78, 0.35, 0.9), 5.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anel.material_override = m
	anel.rotation_degrees.x = 90.0        # o anel abraça o membro (eixo do braço)
	membro.add_child(anel)

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.30
	pm.color_ramp = FxUtil.gradient(FAISCA)
	anel.add_child(FxUtil.particles(24, 0.30, true, pm, FxUtil.grain(0.05), 0.85))

	# Desce do ombro/quadril até a ponta e some.
	var tw := anel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anel, "position:y", -0.75, 0.18).from(0.05)
	tw.tween_property(anel, "scale", Vector3(1.5, 1.5, 1.5), 0.18).from(Vector3(0.4, 0.4, 0.4))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.20)
	tw.chain().tween_callback(anel.queue_free)

# ------------------------------------------------------------ ALVO TELEGUIADO
# Inimigo mais próximo da MIRA (não o mais próximo do corpo) — o V trava nele.
static func alvo_da_mira(caster: Node, origin: Vector3, dir: Vector3) -> Node3D:
	if caster == null or not caster.is_inside_tree():
		return null
	var fwd := dir.normalized()
	var best: Node3D = null
	var best_align := CONE_MIRA
	for e in caster.get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or e == caster:
			continue
		var to: Vector3 = (e.global_position + Vector3.UP * 0.6) - origin
		var d := to.length()
		if d > ALCANCE_MIRA or d < 0.5:
			continue
		var align := fwd.dot(to / d)
		if align > best_align:
			best_align = align
			best = e
	return best

# ------------------------------------------------------------------ PROJÉTIL
# `alvo` != null -> teleguiado: corrige o rumo por frame até acertar.
#
# O MODELO da bala mora em `BukiProjeteis` — um por arma (2026-08-11). Aqui só
# fica o que é MECÂNICA: a zona de dano, a velocidade e a perseguição.
#
# ⚠️ A zona nasce OLHANDO pro rumo do tiro. Antes ela nascia sem rotação e a
# cápsula era deitada com um `rotation.x = 90` fixo — ou seja, a bala só ficava
# alinhada com a trajetória quando o jogador atirava na direção do Z do MUNDO.
# Em qualquer outra direção ela voava de lado. Só não gritava porque era uma
# cápsula quase simétrica; com obus e dardo, gritaria.
static func _projetil(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, slot: String, alvo: Node3D, spec: DamageSpec = null) -> void:
	var d: Dictionary = ARSENAL.get(slot, ARSENAL["Z"])
	var raio := float(d["raio"])
	var velocidade := float(d["vel"])
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	# `look_at` explode se o rumo for paralelo ao "up"; tiro pra cima é normal
	# (canhão como mobilidade), então o up vira lateral nesse caso.
	var cima := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	zone.look_at(origin + fwd, cima)
	# O PENTE INTEIRO divide um orçamento: as 100 balas do minigun somam o mesmo
	# teto que os 3 tiros do canhão. Sem isso, a arma com mais munição seria
	# automaticamente a mais forte — e era: o minigun somava 108 contra os 32 do
	# canhão. Ver `Player._spec_do_disparo`.
	zone.setup(damage, float(d["kb"]), fwd * velocidade, 3.0, caster, raio)
	if spec != null:
		spec.marcar(zone)
	zone.add_child(BukiProjeteis.montar(slot, raio, velocidade))

	if alvo != null and is_instance_valid(alvo):
		_perseguir(zone, alvo, velocidade)

# Correção de rumo por frame. Fica na própria zona (morre junto com ela).
static func _perseguir(zone: Node3D, alvo: Node3D, velocidade: float) -> void:
	var t := Timer.new()
	t.wait_time = 0.02
	t.autostart = true
	zone.add_child(t)
	t.timeout.connect(func():
		if not is_instance_valid(alvo) or not is_instance_valid(zone):
			return
		var para: Vector3 = (alvo.global_position + Vector3.UP * 0.6) - zone.global_position
		if para.length() < 0.05:
			return
		# vira devagar pro alvo: teleguiado, não instantâneo (dá pra desviar)
		var novo: Vector3 = zone.vel.normalized().slerp(para.normalized(), 0.25)
		zone.vel = novo * velocidade
		zone.look_at(zone.global_position + novo, Vector3.UP)
	)

# Fogacho na boca do cano. `escala` 1.0 = canhão, 0.35 = metralhadora.
static func _fogacho(world: Node, origin: Vector3, dir: Vector3, escala: float) -> void:
	if world == null or not world.is_inside_tree():
		return
	var fwd := dir.normalized()
	var flash := GPUParticles3D.new()
	flash.amount = FxQualityPolicy.quantidade(int(40 * escala) + 8, "essencial")
	flash.lifetime = FxQualityPolicy.duracao(0.18 + 0.22 * escala, "essencial")
	flash.one_shot = true
	flash.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 28.0
	pm.initial_velocity_min = 4.0 * escala
	pm.initial_velocity_max = 11.0 * escala
	pm.scale_min = 0.4 * escala
	pm.scale_max = 1.3 * escala
	pm.color_ramp = FxUtil.gradient(FAISCA)
	flash.process_material = pm
	flash.draw_pass_1 = SphereMesh.new()
	world.add_child(flash)
	(flash as Node3D).global_position = origin + fwd * 0.8
	world.get_tree().create_timer(1.2).timeout.connect(flash.queue_free)

	# LUZ DO DISPARO. É o que mais rende no fogacho: sem ela o clarão não toca no
	# personagem nem no chão, e o tiro parece um adesivo colado na tela. Vive
	# 0,07 s — arma de fogo pisca, não ilumina.
	if FxQualityPolicy.permite_luz("padrao"):
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.80, 0.45)
		luz.light_energy = (7.0 * escala + 1.5) * FxQualityPolicy.fator("padrao")
		luz.omni_range = (5.0 + 7.0 * escala) * FxQualityPolicy.fator("padrao")
		luz.shadow_enabled = false          # 6 tiros x sombra = tranco de frame
		world.add_child(luz)
		(luz as Node3D).global_position = origin + fwd * 0.7
		var tw := luz.create_tween()
		tw.tween_property(luz, "light_energy", 0.0, 0.07)
		tw.tween_callback(luz.queue_free)

	# FUMAÇA — cinza, lenta, subindo. Fica DEPOIS do clarão, senão some junto.
	var fumaca := GPUParticles3D.new()
	fumaca.amount = FxQualityPolicy.quantidade(int(10 * escala) + 4, "padrao")
	fumaca.lifetime = FxQualityPolicy.duracao(0.9 + 0.6 * escala, "padrao")
	fumaca.one_shot = true
	fumaca.emitting = true
	var fp := ParticleProcessMaterial.new()
	fp.direction = fwd + Vector3.UP * 0.5
	fp.spread = 40.0
	fp.initial_velocity_min = 0.6 * escala
	fp.initial_velocity_max = 2.2 * escala
	fp.gravity = Vector3(0, 0.7, 0)      # fumaça SOBE
	fp.scale_min = 0.5 * escala
	fp.scale_max = 1.8 * escala
	fp.color_ramp = FxUtil.gradient([
		Color(0.55, 0.55, 0.58, 0.55),
		Color(0.45, 0.45, 0.48, 0.30),
		Color(0.40, 0.40, 0.42, 0.0),
	])
	fumaca.process_material = fp
	fumaca.draw_pass_1 = FxUtil.grain(0.5)
	world.add_child(fumaca)
	(fumaca as Node3D).global_position = origin + fwd * 0.85
	world.get_tree().create_timer(2.5).timeout.connect(fumaca.queue_free)

# CÁPSULAS EJETADAS — em todas as armas de braço (o canhão fica de fora: obus não
# ejeta estojo). Latão saltando pra direita e caindo. Detalhe pequeno, mas é o
# que dá CADÊNCIA visível à rajada do minigun: sem ele os tiros viram um borrão.
static func _capsulas(world: Node, origin: Vector3, dir: Vector3) -> void:
	if world == null or not world.is_inside_tree():
		return
	var lado := dir.normalized().cross(Vector3.UP).normalized()
	var p := GPUParticles3D.new()
	p.amount = 2
	p.lifetime = 1.1
	p.one_shot = true
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = lado + Vector3.UP * 0.9
	pm.spread = 18.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 3.6
	pm.gravity = Vector3(0, -9.0, 0)
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.5
	pm.scale_max = 0.7
	pm.color_ramp = FxUtil.gradient([
		Color(0.86, 0.68, 0.28, 1.0),
		Color(0.80, 0.62, 0.24, 1.0),
		Color(0.70, 0.55, 0.20, 0.0),
	])
	p.process_material = pm
	var casq := BoxMesh.new()
	casq.size = Vector3(0.035, 0.10, 0.035)
	p.draw_pass_1 = casq
	world.add_child(p)
	(p as Node3D).global_position = origin
	world.get_tree().create_timer(2.0).timeout.connect(p.queue_free)

# ============================================================================
#  ARMAS — agora são ASSETS (.glb), não geometria montada em código.
#
#  Modeladas em tools/blender/buki_weapons.py (Blender headless) e exportadas
#  pra assets/models/weapons/. Mexer na arte deixou de ser mexer em GDScript:
#  edita o script do Blender, roda, e o jogo pega o arquivo novo.
#
#  Os construtores voxel antigos continuam logo abaixo como PLANO B — se o .glb
#  sumir (clone sem os assets, import ainda não rodou), a fruta continua
#  jogável em vez de disparar arma invisível.
#
#  As quatro armas do arsenal têm modelo próprio. A LÂMINA foi APAGADA em
#  2026-08-11: com a fruta virando kit de FPS não sobrou golpe de corte, e
#  manter asset que nada instancia é peso morto que dá falsa impressão de
#  cobertura. Está no histórico do git se um golpe de corte voltar.
# ============================================================================
const ARMAS := {
	"metralhadora": "res://assets/models/weapons/buki_metralhadora.glb",
	"sniper": "res://assets/models/weapons/buki_sniper.glb",
	"canhao": "res://assets/models/weapons/buki_canhao.glb",
}

static var _cache_armas: Dictionary = {}

static func _arma(nome: String) -> Node3D:
	if not _cache_armas.has(nome):
		var caminho: String = ARMAS.get(nome, "")
		_cache_armas[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
	var cena = _cache_armas[nome]
	if cena is PackedScene:
		var n := (cena as PackedScene).instantiate() as Node3D
		n.name = "Buki_" + nome
		return n
	# Plano B: a versão voxel montada em código.
	match nome:
		"metralhadora": return _voxel_metralhadora()
		"sniper": return _voxel_metralhadora()   # plano B: a metralhadora serve de fuzil
		_: return _voxel_canhao()

# --------------------------------------------------------------- CONSTRUTORES
# PLANO B — armas em estilo voxel montadas em código (ver bloco acima).
static func _caixa(tam: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	return mi

static func _cil(raio: float, alt: float, pos: Vector3, mat: StandardMaterial3D,
		eixo := "z") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = alt
	c.radial_segments = 10          # facetado: combina com o resto do jogo
	mi.mesh = c
	mi.position = pos
	# CylinderMesh nasce ao longo de +Y; deitar em Z é o eixo de tiro (frente = −Z)
	if eixo == "z":
		mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	return mi

# METRALHADORA — cano, camisa de refrigeração, tambor de munição e alça de mira.
# O tambor e as ranhuras da camisa são o que fazem ler como "metralhadora" em vez
# de "cano genérico"; sem eles vira um tubo.
static func _voxel_metralhadora() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiMetralhadora"
	var aco := _mat_aco()
	var escuro := _mat_escuro()
	var quente := _mat_aco(true)
	var y := -0.34                       # ponta do antebraço

	r.add_child(_caixa(Vector3(0.20, 0.17, 0.30), Vector3(0, y + 0.02, -0.08), escuro))  # culatra
	r.add_child(_cil(0.075, 0.60, Vector3(0, y, -0.42), aco))                            # cano
	for i in 5:                                                                          # camisa
		r.add_child(_cil(0.105, 0.028, Vector3(0, y, -0.22 - i * 0.085), escuro))
	r.add_child(_cil(0.055, 0.10, Vector3(0, y, -0.76), quente))                          # boca
	r.add_child(_cil(0.13, 0.10, Vector3(0, y - 0.13, -0.10), escuro, "y"))               # tambor
	r.add_child(_caixa(Vector3(0.02, 0.07, 0.02), Vector3(0, y + 0.13, -0.20), escuro))   # alça
	r.add_child(_caixa(Vector3(0.02, 0.05, 0.02), Vector3(0, y + 0.12, -0.62), escuro))   # massa
	return r

static func _voxel_canhao() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiCanhao"
	var aco := _mat_aco()
	var escuro := _mat_escuro()
	var boca := _mat_aco(true)
	var y := -0.30

	r.add_child(_cil(0.19, 0.30, Vector3(0, y, -0.06), escuro))        # câmara (traseira)
	r.add_child(_cil(0.155, 0.56, Vector3(0, y, -0.44), aco))          # corpo do cano
	for i in 3:                                                        # aros de reforço
		r.add_child(_cil(0.185, 0.05, Vector3(0, y, -0.26 - i * 0.20), escuro))
	r.add_child(_cil(0.215, 0.14, Vector3(0, y, -0.78), aco))          # boca alargada
	r.add_child(_cil(0.145, 0.06, Vector3(0, y, -0.83), boca))         # interior quente
	r.add_child(_caixa(Vector3(0.10, 0.16, 0.10), Vector3(0, y - 0.17, -0.14), escuro))  # punho
	return r

static func _mat_escuro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.21, 0.24)
	m.metallic = 0.85
	m.roughness = 0.45
	return m
