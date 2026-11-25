class_name PoderDaFruta
extends RefCounted
## Liga as camadas do HTCS (`PoderVfx`) às frutas do mod (13/11/2026): uma cor e uma forma de onda de choque por fruta, a CARGA enquanto se segura a tecla e o
## IMPACTO + SOLO + TREMOR no contato do dano (`McEntidade.hurt`). Só visual: não muda dano nem mecânica.
const COR := {
	"aro_aro": Color(0.35, 0.8, 0.4), "batto_batto": Color(0.85, 0.85, 0.92), "bisu_bisu": Color(0.95, 0.85, 0.55), "bomu_bomu": Color(1.0, 0.6, 0.25),
	"gomu_gomu": Color(0.95, 0.3, 0.3), "goro_goro": Color(0.6, 0.85, 1.0), "gura_gura": Color(0.85, 0.95, 1.0), "hie_hie": Color(0.6, 0.88, 1.0),
	"hito_hito_daibutsu": Color(1.0, 0.85, 0.3), "horo_horo": Color(1.0, 0.6, 0.9), "imu": Color(0.55, 0.1, 0.65), "inu_inu_okuchi_no_makami": Color(0.85, 0.85, 0.9),
	"inu_inu_wolf": Color(0.7, 0.7, 0.8), "kage_kage": Color(0.4, 0.2, 0.6), "kira_kira": Color(0.85, 0.9, 1.0), "kiro_kiro": Color(0.75, 0.75, 0.8),
	"magu_magu": Color(1.0, 0.35, 0.1), "mera_mera": Color(1.0, 0.5, 0.12), "mero_mero": Color(1.0, 0.5, 0.8), "mochi_mochi": Color(0.95, 0.8, 0.7),
	"moku_moku": Color(0.9, 0.9, 0.92), "mori_mori": Color(0.3, 0.75, 0.3), "neko_neko_leopard": Color(0.95, 0.75, 0.3), "neko_neko_sabertiger": Color(0.95, 0.7, 0.35),
	"nikyu_nikyu": Color(0.95, 0.7, 0.5), "ope_ope": Color(0.35, 0.65, 1.0), "pika_pika": Color(1.0, 0.9, 0.25), "riki_riki": Color(0.75, 0.55, 0.35),
	"ryu_ryu_brachiosaurus": Color(0.55, 0.7, 0.35), "ryu_ryu_pachycephalosaurus": Color(0.6, 0.65, 0.4), "ryu_ryu_pteranodon": Color(0.5, 0.75, 0.55),
	"soru_soru": Color(0.9, 0.9, 0.5), "suna_suna": Color(0.85, 0.75, 0.45), "supa_supa": Color(0.75, 0.85, 0.9), "tori_tori_phoenix": Color(0.3, 0.7, 1.0),
	"uo_uo_seiryu": Color(0.2, 0.6, 0.9), "ushi_ushi_giraffe": Color(0.9, 0.75, 0.4), "uta_uta": Color(1.0, 0.75, 0.9), "yami_yami": Color(0.45, 0.15, 0.6),
	"zushi_zushi": Color(0.7, 0.35, 1.0),
}
## Forma da onda de choque: a assinatura da fruta (o resto é círculo).
const FORMA := {
	"zushi_zushi": PoderVfx.Forma.TRIANGULO, "hie_hie": PoderVfx.Forma.TRIANGULO, "tori_tori_phoenix": PoderVfx.Forma.TRIANGULO, "ryu_ryu_pteranodon": PoderVfx.Forma.TRIANGULO,
	"ope_ope": PoderVfx.Forma.QUADRADO, "goro_goro": PoderVfx.Forma.QUADRADO, "kiro_kiro": PoderVfx.Forma.QUADRADO, "riki_riki": PoderVfx.Forma.QUADRADO,
	"mori_mori": PoderVfx.Forma.QUADRADO, "suna_suna": PoderVfx.Forma.QUADRADO, "batto_batto": PoderVfx.Forma.QUADRADO, "imu": PoderVfx.Forma.QUADRADO,
}
const INTERVALO_MS := 140          # um impacto por "cacho" de alvos: golpe em área não dispara 20 anéis
const DISTANCIA_DO_CACHO := 2.5

static var _ultimo_ms := 0
static var ultimo_contato_ms := 0
static var _ultimo_ponto := Vector3.INF


static func cor(fruta: String) -> Color:
	return COR.get(fruta, PoderVfx.COR_PADRAO)


static func forma(fruta: String) -> int:
	return int(FORMA.get(fruta, PoderVfx.Forma.CIRCULO))


## Contato do dano de uma técnica do jogador: impacto (clarão + anel) + solo (se pesado) + tremor proporcional ao dano.
static func contato(ator: Node, onde: Vector3, dano: float) -> void:
	if ator == null or not is_instance_valid(ator) or not ator.is_in_group("player"):
		return
	var fruta := str(ator.get("current_fruit_id"))
	if fruta == "" or not COR.has(fruta):
		return
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_ms < INTERVALO_MS and _ultimo_ponto.distance_to(onde) < DISTANCIA_DO_CACHO:
		return
	_ultimo_ms = agora
	ultimo_contato_ms = agora
	_ultimo_ponto = onde
	var peso := clampf(dano / 80.0, 0.4, 1.0)      # piso 0,15 → 0,4 (15/11/2026): acerto fraco (7 de dano) virava brilho de 1,6 m e a técnica não se lia
	# FEIXE: acerto à distância (> 3,5 m) liga a mão do jogador ao ponto do contato com a textura esticada que troca de forma
	var mao := _mao(ator)
	if mao != Vector3.INF and mao.distance_to(onde) > 3.5:
		PoderVfx.feixe(ator, mao, onde + Vector3.UP * 1.0, cor(fruta), 0.25 + peso * 0.5, 0.25)
	PoderVfx.golpe(ator, onde + Vector3.UP * 0.2, cor(fruta), 1.2 + peso * 2.6, peso, forma(fruta) as PoderVfx.Forma, peso >= 0.4)


## RASTRO EM VOO (15/11/2026): projétil/corte/nota/bala criado durante a técnica do jogador ganha uma trilha luminosa da cor da fruta enquanto viaja.
## Presa à entidade (some com ela). No máximo `MAX_RASTROS` vivas ao mesmo tempo, para chuva de projéteis não pesar.
const PROJETEIS := ["slash", "sweep", "arrow", "energy", "bullet", "note", "heart", "projectile", "wave", "fist", "ball", "rock", "stone", "bat", "dragon", "spike"]
const MAX_RASTROS := 14
static var _rastros_vivos := 0

static func rastro_em_voo(entidade: Node3D, id_entidade: String, fruta: String) -> void:
	if entidade == null or not is_instance_valid(entidade) or not COR.has(fruta) or _rastros_vivos >= MAX_RASTROS:
		return
	var id := id_entidade.to_lower()
	var e_projetil := false
	for t in PROJETEIS:
		if t in id:
			e_projetil = true
			break
	if not e_projetil:
		return
	var p := CPUParticles3D.new()
	p.name = "RastroEmVoo"
	p.amount = 44
	p.lifetime = 0.55
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.6
	p.gravity = Vector3.ZERO
	var c := cor(fruta)
	var rampa := Gradient.new()
	rampa.colors = PackedColorArray([Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.9), Color(c.r, c.g, c.b, 0.0)])
	p.color_ramp = rampa
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.1))
	p.scale_amount_curve = curva
	var malha := QuadMesh.new()
	malha.size = Vector2(0.85, 0.85)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = McVisual._textura_suave()
	malha.material = mat
	p.mesh = malha
	entidade.add_child(p)
	p.emitting = true
	# CORPO do projétil (15/11/2026): a maioria das entidades do mod não tem malha visível e o golpe lia como "fagulhas soltas". Núcleo quente + halo
	# billboard da cor da fruta, presos à entidade, legíveis a 14 m.
	var nucleo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.22
	esf.height = 0.44
	nucleo.mesh = esf
	nucleo.material_override = FxUtil.mesh_emissive_material(Color(1.0, 0.97, 0.9, 0.95), 2.6, true)
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entidade.add_child(nucleo)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = McVisual._textura_suave()
	hm.albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 0.85)
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entidade.add_child(halo)
	_rastros_vivos += 1
	p.tree_exited.connect(func() -> void: _rastros_vivos = maxi(_rastros_vivos - 1, 0))


## NASCIMENTO DE ENTIDADE (15/11/2026): durante uma técnica do jogador, toda entidade que o mod cria (clone, nota, corte, flecha, pedra) nasce
## com um clarão e um anel da cor da fruta. Medido: invocações e projéteis nasciam sem marca e a técnica não se lia (Kage C, Uta Z, Leopard X…).
## Tamanho pelo tipo: invocação > corte/flecha/energia > o resto. Limite de taxa para chuvas de projéteis (1 sinal por 90 ms e 1,5 m).
const INVOCACOES := ["doppelman", "hollow", "warrior", "donatsu", "kumacy", "zeus", "prometheus", "fist", "tornado", "pad"]
const LANCAMENTOS := ["slash", "sweep", "arrow", "energy", "bullet", "projectile", "wave"]
static var _sinal_ms := 0
static var _sinal_ponto := Vector3.INF

static func sinal_de_nascimento(ator: Node3D, id_entidade: String, onde: Vector3) -> void:
	if ator == null or not is_instance_valid(ator) or not ator.is_in_group("player"):
		return
	var fruta := str(ator.get("current_fruit_id"))
	if not COR.has(fruta):
		return
	var agora := Time.get_ticks_msec()
	if agora - _sinal_ms < 90 and _sinal_ponto.distance_to(onde) < 1.5:
		return
	_sinal_ms = agora
	_sinal_ponto = onde
	var id := id_entidade.to_lower()
	var raio := 0.7
	for t in INVOCACOES:
		if t in id:
			raio = 1.7
			break
	if raio < 1.0:
		for t in LANCAMENTOS:
			if t in id:
				raio = 1.0
				break
	VfxGoroMinePiece.clarao(ator, onde, raio, 0.28, cor(fruta))
	VfxFrutaMinePiece.onda_de_choque(ator, onde, raio * 1.3, cor(fruta), 0.4)
	if "donatsu" in id:      # Muso Donuts: tentáculos de mochi sobem do chão e se enrolam na rosquinha (One Piece Wiki)
		var chao := onde - Vector3.UP * 1.1
		for k in 3:
			var ang := TAU * float(k) / 3.0
			var base := chao + Vector3(cos(ang), 0.0, sin(ang)) * 0.9
			VfxFrutaMinePiece.braco_esticado(ator, base, base + Vector3.UP * 2.6 + Vector3(-cos(ang), 0.0, -sin(ang)) * 0.7, 0.34, Color(1.0, 0.93, 0.82), 0.28, 0.3, 0.35)



## ATIVAÇÃO (15/11/2026): ao soltar a tecla, um anel no chão sob o jogador, da cor da fruta, com raio proporcional ao custo da técnica (técnica
## forte LÊ forte; 2–8 m) e um segundo anel atrasado nas caras (custo ≥ 400). Legível de qualquer ângulo — a medição de 105 técnicas do mod
## mostrou que 45 mudavam <8% da imagem porque o efeito próprio era pequeno ou ficava longe do alvo. Só visual.
static func ativacao(ator: Node3D, fruta: String, custo := 200.0) -> void:
	if ator == null or not is_instance_valid(ator) or not COR.has(fruta):
		return
	var pe := _pe(ator)
	var raio := clampf(3.0 + custo / 150.0, 3.0, 10.0)
	VfxFrutaMinePiece.onda_de_choque(ator, pe, raio, cor(fruta), 0.55)
	if custo >= 400.0:
		ator.get_tree().create_timer(0.12, false).timeout.connect(func() -> void:
			if is_instance_valid(ator):
				VfxFrutaMinePiece.onda_de_choque(ator, _pe(ator), raio * 1.5, cor(fruta), 0.7))


## O chão sob o jogador: o pé do modelo (o pivô do corpo fica no meio da cápsula).
static func _pe(ator: Node3D) -> Vector3:
	var modelo: Variant = ator.get("_char_model")
	return (modelo as Node3D).global_position if modelo is Node3D else ator.global_position - Vector3.UP * 1.0


## CARGA enquanto o botão está apertado: partículas puxadas para o peito do jogador. Devolve o emissor (ou null) para soltar depois.
## `custo` = custo de energia da técnica (0–1250): quanto mais cara, maior a casca de onde as partículas vêm e mais partículas (técnica forte LÊ forte).
static func carga(ator: Node3D, fruta: String, custo := 200.0) -> Node3D:
	if ator == null or not COR.has(fruta):
		return null
	var k := clampf(custo / 400.0, 0.4, 3.0)
	return PoderVfx.carga(ator, ator, Vector3(0, 1.1, 0), cor(fruta), 1.0, 1.2 + k * 0.9, int(18 + k * 22.0))


## A mão direita do jogador (mundo) para origem do feixe; `Vector3.INF` se o rig não a expõe.
static func _mao(ator: Node) -> Vector3:
	var anim = ator.get("_proc_anim")
	if anim != null and anim._n.has("ForeArm_R"):
		return (anim._n["ForeArm_R"] as Node3D).global_position
	return (ator as Node3D).global_position + Vector3.UP * 1.2 if ator is Node3D else Vector3.INF


## RASTRO da mão que executa a técnica (liga ao iniciar, ~0,6 s). Devolve a fita (some sozinha).
static func rastro_da_mao(ator: Node3D, fruta: String) -> Node3D:
	if ator == null or not COR.has(fruta):
		return null
	var anim = ator.get("_proc_anim")
	if anim == null or not anim._n.has("ForeArm_R"):
		return null
	return PoderVfx.rastro(ator, anim._n["ForeArm_R"], cor(fruta), 0.3, 0.6)


## Clímax sem alvo (HTCS: toda técnica tem retorno): `ao_soltar` roda ~0,5 s depois de soltar a tecla; se NENHUM contato de dano aconteceu desde `desde_ms`
## (buff, invocação, área que errou, tiro no vazio), faz o impacto leve no ponto de mira (raio de 12 m) com a cor da fruta.
static func climax_sem_alvo(ator: Node3D, fruta: String, desde_ms: int, custo := 200.0) -> void:
	if ator == null or not is_instance_valid(ator) or not COR.has(fruta) or ultimo_contato_ms >= desde_ms:
		return
	var cam := ator.get_viewport().get_camera_3d() if ator.is_inside_tree() else null
	if cam == null:
		return
	var de := cam.global_position
	var para := de - cam.global_basis.z * 12.0
	var hit := ator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(de, para, 1, [ator.get_rid()]))
	var onde: Vector3 = hit.position if not hit.is_empty() else (ator.global_position + (-cam.global_basis.z * Vector3(1, 0, 1)).normalized() * 6.0)
	var k := clampf(custo / 400.0, 0.4, 3.0)
	PoderVfx.impacto(ator, onde + Vector3.UP * 0.2, cor(fruta), 1.6 + k * 1.2, forma(fruta) as PoderVfx.Forma)
	if k >= 1.0:
		PoderVfx.solo(ator, onde, 1.0 + k * 0.5)
	PoderVfx.tremor(ator, 0.08 + k * 0.06)


## ASSINATURA por técnica (a forma que identifica o golpe): hoje o TIGRE da Zushi Zushi C (Raging Tiger, número 24 do mod). `numero` = técnica do mod em uso.
static func assinatura(ator: Node3D, fruta: String, numero: int) -> void:
	if ator == null or not is_instance_valid(ator):
		return
	if fruta == "zushi_zushi" and numero == 24:
		var cam := ator.get_viewport().get_camera_3d()
		var dir := (-cam.global_basis.z) if cam != null else Vector3.FORWARD
		var direita := cam.global_basis.x if cam != null else Vector3.RIGHT
		PoderVfx.tigre(ator, ator.global_position + Vector3.UP * 0.1 + dir * Vector3(1, 0, 1).normalized() * 1.5, dir, cor(fruta), 1.5, 9.0, 1.0, direita)
	# Assinaturas de 15/11/2026 para as técnicas que a medição achou abaixo de 6% da imagem (cada uma com a identidade do golpe):
	elif fruta == "uta_uta" and numero == 21:
		_pauta(ator, cor(fruta))                     # Note: a pauta musical (5 linhas) à frente
	elif fruta == "mero_mero" and numero == 22:
		_chute_circular(ator, cor(fruta))            # Roundhouse Kick: arco de chute em volta do corpo
	elif fruta == "kage_kage" and numero == 24:
		_espinhos_de_sombra(ator, cor(fruta))        # Spiky Shadow Lizard: espinhos de sombra saindo do chão à frente
	# 15/11/2026 (2ª passada, técnicas entre 5 e 8% na medição): identidade por TIPO de golpe, na cor da fruta.
	elif numero == 23 and fruta in ["ushi_ushi_giraffe", "neko_neko_leopard", "batto_batto"]:
		_chute_circular(ator, cor(fruta))            # Tempest Kick
	elif (fruta == "neko_neko_leopard" and numero == 26) or (fruta == "neko_neko_sabertiger" and numero == 23) \
			or (fruta == "supa_supa" and numero == 21) or (fruta == "inu_inu_okuchi_no_makami" and numero == 24) \
			or (fruta == "ryu_ryu_pteranodon" and numero == 23):
		_linha_de_golpe(ator, cor(fruta))            # Hand/Finger Pistol, Projectile Slash, Narikabura, Imperial Archer: a linha do tiro
	elif (fruta == "batto_batto" and numero == 26) or (fruta == "kage_kage" and numero == 25):
		_pilar(ator, cor(fruta))                     # Forgive Me / Doppelman: coluna de luz/sombra sobre quem usa
	elif (fruta == "riki_riki" and numero == 24) or (fruta == "kiro_kiro" and numero == 26):
		_aura_ascendente(ator, cor(fruta))           # Stone Throwing / Weight Manipulation: anéis que sobem pelo corpo
	elif fruta == "mochi_mochi" and numero in [22, 23]:
		_bracos_de_mochi(ator, numero == 22)         # Punch Mochi (punho QUADRADO, Kaku Mochi) / Elephant Gun: braços da mão e de cada rosquinha até o alvo
	elif fruta == "mochi_mochi" and numero == 24:
		_antebraco_que_infla(ator)                   # Burning Mochi = Yaki Mochi: o antebraço infla até estourar
	elif fruta == "mochi_mochi" and numero == 25:
		_rosquinha_giratoria(ator)                   # Buzz Cut Mochi = Zan Giri Mochi: o corpo vira uma rosquinha que gira
	elif fruta == "mochi_mochi" and numero == 29:
		_aura_ascendente(ator, cor(fruta))           # Unstoppable Donuts: os anéis (donuts) sobem em volta do corpo
		_pilar(ator, cor(fruta))


static func _direcao_da_mira(ator: Node3D) -> Vector3:
	var cam := ator.get_viewport().get_camera_3d()
	var d := (-cam.global_basis.z) if cam != null else Vector3.FORWARD
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


## Yaki Mochi: esfera de mochi que INFLA no antebraço (0,12 → 0,6 m em 0,35 s, pulsando) e ESTOURA (anel + clarão). Referência: One Piece Wiki, Mochi Mochi no Mi.
static func _antebraco_que_infla(ator: Node3D) -> void:
	var raiz := VfxGoroMinePiece._raiz(ator)
	if raiz == null:
		return
	var mao := ator.global_position + Vector3.UP * 0.1 + ator.global_basis.x * 0.5
	var bola := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 1.0
	bola.mesh = esf
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.93, 0.82)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.6)
	mat.emission_energy_multiplier = 0.5
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(bola)
	bola.global_position = mao
	bola.scale = Vector3.ONE * 0.24
	var tw := bola.create_tween()
	tw.tween_property(bola, "scale", Vector3.ONE * 1.2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		VfxFrutaMinePiece.onda_de_choque(ator, bola.global_position, 2.6, Color(1.0, 0.93, 0.82), 0.4)
		VfxGoroMinePiece.clarao(ator, bola.global_position, 1.4, 0.2, Color(1.0, 0.9, 0.7)))
	tw.tween_property(bola, "scale", Vector3.ONE * 0.01, 0.1)
	tw.tween_callback(bola.queue_free)


## Zan Giri Mochi: o corpo vira uma ROSQUINHA que gira — toro de mochi na altura da cintura, girando rápido em volta do jogador por ~1 s. Referência: One Piece Wiki.
static func _rosquinha_giratoria(ator: Node3D) -> void:
	var raiz := Node3D.new()
	ator.add_child(raiz)
	raiz.position = Vector3(0, -0.1, 0)
	var toro := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.7
	t.outer_radius = 1.25
	t.rings = 28
	t.ring_segments = 10
	toro.mesh = t
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.93, 0.82, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.7)
	mat.emission_energy_multiplier = 0.5
	toro.material_override = mat
	toro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	toro.rotation_degrees = Vector3(70, 0, 0)       # inclinado: lê como rosquinha e não como disco chato
	raiz.add_child(toro)
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_method(func(a: float) -> void:
		if is_instance_valid(raiz):
			raiz.rotation.y = a, 0.0, TAU * 5.0, 1.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_delay(0.75)
	tw.chain().tween_callback(raiz.queue_free)


## Alvo do soco esticado: o inimigo mais perto da linha da mira (até 25 m); sem inimigo, 9 m à frente.
static func _ponto_do_soco(ator: Node3D) -> Vector3:
	var d := _direcao_da_mira(ator)
	var melhor := Vector3.INF
	var melhor_t := 25.0
	for alvo in AlvosDeGolpe.todos(ator.get_tree()):
		if not MundoMinePiece.atacavel(ator, alvo):
			continue
		var c := AlvosDeGolpe.centro(alvo)
		var v := c - ator.global_position
		var t := v.dot(d)
		if t > 0.5 and t < melhor_t and (v - d * t).length() < 6.0:
			melhor_t = t
			melhor = c
	return melhor if melhor != Vector3.INF else ator.global_position + d * 9.0 + Vector3.UP * 0.4


## Mochi Mochi: de cada rosquinha viva do jogador (e da mão dele) sai um braço de massa que estica até o alvo e recolhe — o golpe clássico do anime.
static func _bracos_de_mochi(ator: Node3D, quadrado := false) -> void:
	var cremoso := Color(1.0, 0.93, 0.82)
	var alvo := _ponto_do_soco(ator)
	var maos: Array[Vector3] = [ator.global_position + Vector3.UP * 0.2 + ator.global_basis.x * 0.5]
	for donut in ator.get_tree().get_nodes_in_group("invocados_do_jogador"):
		if donut is Node3D and is_instance_valid(donut) and McAliadoDoMod.id_de(donut) == "entity_muso_donatsu":      # pelo ID: o nó da 2ª rosquinha nasce sem nome
			maos.append((donut as Node3D).global_position + Vector3.UP * 0.5)
	var i := 0
	for origem in maos:
		var espera := 0.05 * i
		var o := origem
		ator.get_tree().create_timer(espera, false).timeout.connect(func() -> void:
			if is_instance_valid(ator):
				var rumo := (alvo - o)
				var ponta := o + rumo.normalized() * minf(rumo.length(), 24.0)
				VfxFrutaMinePiece.braco_esticado(ator, o, ponta, 0.38 if o != maos[0] else 0.3, cremoso, 0.12, 0.1, 0.16, quadrado))
		i += 1


## A linha do tiro: feixe fino de 1 a 9 m na mira, à altura do peito, com um anel pequeno na ponta.
static func _linha_de_golpe(ator: Node3D, c: Color) -> void:
	var d := _direcao_da_mira(ator)
	var base := ator.global_position + Vector3.UP * 0.5
	VfxFrutaMinePiece.feixe(ator, base + d * 1.0, base + d * 9.0, 0.55, c, 0.35)
	VfxFrutaMinePiece.onda_de_choque(ator, ator.global_position - Vector3.UP * 0.9 + d * 9.0, 1.8, c, 0.4)


## Coluna de luz (ou sombra) do chão a 7 m sobre o jogador, 0,5 s.
static func _pilar(ator: Node3D, c: Color) -> void:
	var pe := ator.global_position - Vector3.UP * 0.9
	VfxFrutaMinePiece.feixe(ator, pe + Vector3.UP * 7.0, pe, 1.1, c, 0.55)
	VfxFrutaMinePiece.onda_de_choque(ator, pe, 3.0, c, 0.5)


## Três anéis a alturas crescentes (0, 0,8 e 1,6 m), 90 ms entre eles: efeito que sobe pelo corpo.
static func _aura_ascendente(ator: Node3D, c: Color) -> void:
	for i in 3:
		ator.get_tree().create_timer(0.09 * i, false).timeout.connect(func() -> void:
			if is_instance_valid(ator):
				VfxFrutaMinePiece.onda_de_choque(ator, ator.global_position - Vector3.UP * (0.9 - 0.8 * i), 2.0 + 0.4 * i, c, 0.4))


## Cinco linhas paralelas de luz, a 0,25 m umas das outras, de 1 a 7 m à frente: a pauta da Uta Uta.
static func _pauta(ator: Node3D, c: Color) -> void:
	var d := _direcao_da_mira(ator)
	var base := ator.global_position + Vector3.UP * 0.7
	var lado := d.cross(Vector3.UP).normalized()
	for i in 5:
		var y := Vector3.UP * (0.25 * i)
		VfxFrutaMinePiece.feixe(ator, base + d * 1.0 + y, base + d * 7.0 + y, 0.4, c, 0.6)
	VfxFrutaMinePiece.onda_de_choque(ator, ator.global_position - Vector3.UP * 0.9 + d * 4.0, 2.2, c, 0.5)


## Dois arcos concêntricos no plano do chute (altura da cintura), do tamanho do alcance do golpe.
static func _chute_circular(ator: Node3D, c: Color) -> void:
	var meio := ator.global_position + Vector3.UP * 0.1
	VfxFrutaMinePiece.onda_de_choque(ator, meio, 3.2, c, 0.35)
	ator.get_tree().create_timer(0.1, false).timeout.connect(func() -> void:
		if is_instance_valid(ator):
			VfxFrutaMinePiece.onda_de_choque(ator, ator.global_position + Vector3.UP * 0.1, 4.6, c, 0.4))


## Sete espinhos escuros que sobem do chão em fila (1–9 m), cada um um pouco depois do anterior, e afundam.
static func _espinhos_de_sombra(ator: Node3D, c: Color) -> void:
	var d := _direcao_da_mira(ator)
	var chao := ator.global_position - Vector3.UP * 0.95
	var raiz := VfxGoroMinePiece._raiz(ator)
	if raiz == null:
		return
	for i in 7:
		var cone := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.35
		m.height = 1.0
		m.radial_segments = 6
		cone.mesh = m
		cone.material_override = FxUtil.mesh_emissive_material(Color(c.r * 0.7, c.g * 0.5, c.b * 1.0, 0.85), 1.4, false)
		raiz.add_child(cone)
		cone.global_position = chao + d * (1.0 + 1.3 * i)
		cone.scale = Vector3(1.0, 0.01, 1.0)
		var tw := cone.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(cone, "scale", Vector3(1.0, 2.6, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(cone, "position:y", cone.position.y + 1.3, 0.14)
		tw.tween_interval(0.35)
		tw.tween_property(cone, "scale", Vector3(1.0, 0.01, 1.0), 0.2)
		tw.tween_callback(cone.queue_free)
