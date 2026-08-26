class_name GoroFX
extends RefCounted
# ============================================================================
#  GORO GORO NO MI — Trovão. Paleta, oficina de raios e os golpes do dia a dia.
#
#  Este arquivo guarda:
#    • a PALETA da fruta (nuvem azul-escura vs. raio amarelo-branco);
#    • a OFICINA de raio (Bolt / bolt_fill / volt_material / storm_cloud / ...),
#      que é o vocabulário visual compartilhado por todos os quatro golpes;
#    • Z (Sango) e C (Shunshin).
#
#  Os dois ESPETÁCULOS — X (El Thor) e V (Mamaragan) — moram em
#  `GoroFXGrande.gd`, pelo mesmo motivo que o Hibashira/Inferno saíram do
#  `FireFX`: são blocos grandes que não participam do combate normal, e o
#  projeto tem teto de 900 linhas por script (docs/LIMITE_DE_TAMANHO.md).
#  A oficina fica AQUI e é chamada de lá — duplicá-la criaria duas fontes de
#  verdade para a paleta do trovão.
#
#  ── REGRA DE OURO DA PALETA ──────────────────────────────────────────────
#  A NUVEM e a BOLA do Mamaragan são AZUL-ESCURAS. O RAIO é amarelo-branco.
#  O efeito é o CONTRASTE entre os dois: nuvem escura como fundo, descarga
#  clara por cima. Se a nuvem ficar clara, o raio some dentro dela.
#  Por isso as nuvens NÃO usam blend aditivo (aditivo sobre escuro = nada):
#  elas são alpha opaco e sem emissão. Só o raio é aditivo/emissivo.
# ============================================================================

# ---- Raio: claro, quente, aditivo ----
const ELECTRIC_YELLOW := Color(1.0, 0.95, 0.35, 0.95)
const LIGHTNING_CYAN  := Color(0.65, 0.95, 1.0, 0.9)
const FLASH_WHITE     := Color(1.0, 1.0, 1.0, 1.0)

# ---- Tempestade: azul-escuro, opaco, sem emissão ----
const STORM_NAVY  := Color(0.045, 0.065, 0.20, 0.96)   # miolo da nuvem / núcleo da bola
const STORM_BLUE  := Color(0.10, 0.16, 0.42, 0.62)     # borda da nuvem / casca da bola
const STORM_GLOW  := Color(0.25, 0.45, 1.0, 1.0)       # luz interna que pulsa na nuvem

# ============================================================================
#  OFICINA DE RAIO
# ============================================================================

# Material de MALHA elétrica (NÃO é partícula: `FxUtil.particle_material` liga
# billboard, o que faria os segmentos de raio virarem de frente pra câmera e
# destruiria o zigue-zague 3D).
static func volt_material(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = FxUtil.brilho(col, energy)
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# Material de NUVEM / massa escura: alpha puro, sem aditivo e sem emissão.
static func storm_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# Pontos em zigue-zague entre dois pontos (coordenadas LOCAIS do nó do raio).
# A amplitude é um FUSO — zero nas duas pontas, máxima no meio. É isso que faz o
# raio "grudar" na origem e no alvo em vez de flutuar solto perto deles.
static func bolt_points(from: Vector3, to: Vector3, segments: int, jag: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var axis: Vector3 = to - from
	var comp: float = axis.length()
	if comp < 0.001:
		axis = Vector3.UP
		comp = 1.0
	var dir: Vector3 = axis / comp
	var side: Vector3 = Vector3.UP.cross(dir)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT.cross(dir)
	side = side.normalized()
	var side2: Vector3 = dir.cross(side).normalized()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = from + axis * t
		if i > 0 and i < segments:
			var amp: float = jag * sin(t * PI)
			p += side * randf_range(-amp, amp) + side2 * randf_range(-amp, amp)
		pts.append(p)
	return pts

# Transform de UM segmento: caixa unitária esticada de `a` até `b`.
# (BoxMesh 1×1×1 é centrada, então a origem vai no MEIO do segmento.)
static func seg_xform(a: Vector3, b: Vector3, thick: float) -> Transform3D:
	var d: Vector3 = b - a
	var comp: float = d.length()
	if comp < 0.0001:
		return Transform3D(Basis().scaled(Vector3(thick, 0.001, thick)), a)
	var ey: Vector3 = d / comp
	var ref: Vector3 = Vector3.UP if absf(ey.y) < 0.95 else Vector3.RIGHT
	var ex: Vector3 = ref.cross(ey).normalized()
	var ez: Vector3 = ex.cross(ey).normalized()
	return Transform3D(Basis(ex * thick, ey * comp, ez * thick), a + d * 0.5)

const FORK_SEGS := 4   # segmentos de cada ramificação (fixo: o MultiMesh tem contagem fixa)

# Quantas instâncias um raio com N segmentos e F ramos ocupa.
static func bolt_instance_count(segments: int, forks: int) -> int:
	return segments + forks * FORK_SEGS

# Redesenha o zigue-zague DENTRO de um MultiMesh já dimensionado.
# Chamar isto de tempos em tempos é o que dá o TREMELIQUE do raio — um raio
# parado lê como um tubo de neon, não como uma descarga.
static func bolt_fill(mm: MultiMesh, from: Vector3, to: Vector3,
		segments: int, jag: float, thick: float, forks: int) -> void:
	var pts := bolt_points(from, to, segments, jag)
	var idx := 0
	for i in range(segments):
		mm.set_instance_transform(idx, seg_xform(pts[i], pts[i + 1], thick))
		idx += 1
	if forks <= 0:
		return
	var eixo: Vector3 = (to - from)
	var comp: float = maxf(eixo.length(), 0.001)
	var dir: Vector3 = eixo / comp
	for _f in range(forks):
		var base_i: int = 1 + (randi() % maxi(segments - 2, 1))
		var base: Vector3 = pts[base_i]
		var desvio := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		if desvio.length_squared() < 0.01:
			desvio = Vector3.RIGHT
		var tip: Vector3 = base + (dir * 0.45 + desvio.normalized()).normalized() * comp * randf_range(0.12, 0.30)
		var bp := bolt_points(base, tip, FORK_SEGS, jag * 0.55)
		for i in range(FORK_SEGS):
			mm.set_instance_transform(idx, seg_xform(bp[i], bp[i + 1], thick * 0.55))
			idx += 1

# Massa de nuvem AZUL-ESCURA: um punhado de esferas achatadas num MultiMesh só
# (1 nó por camada, não 1 nó por bolha — é o mesmo truque do oceano de chamas do
# Inferno). O chamador empilha duas camadas: miolo NAVY + borda BLUE.
static func storm_cloud(radius: float, puffs: int, col: Color, achatamento: float = 0.55) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = puffs
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 10
	sph.rings = 6
	mm.mesh = sph
	mmi.multimesh = mm
	mmi.material_override = storm_material(col)
	for i in range(puffs):
		var ang: float = randf() * TAU
		var r: float = radius * sqrt(randf())
		var p := Vector3(cos(ang) * r, randf_range(-0.30, 0.30) * radius * achatamento, sin(ang) * r)
		var s: float = radius * randf_range(0.42, 0.95)
		var b := Basis().rotated(Vector3.UP, randf() * TAU).scaled(Vector3(s, s * achatamento, s))
		mm.set_instance_transform(i, Transform3D(b, p))
	return mmi

# Anel de choque no chão (ou no ar): cresce e some. Já se liberta sozinho.
static func shock_ring(parent: Node3D, pos: Vector3, col: Color,
		escala_final: float, dur: float, grossura: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0 - grossura
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 10
	mi.mesh = tm
	var mat := volt_material(col, 7.0)
	mi.material_override = mat
	mi.scale = Vector3(0.2, 0.2, 0.2)
	parent.add_child(mi)
	mi.position = pos
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(escala_final, escala_final * 0.06, escala_final), dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

# Fagulhas voltaicas padrão da fruta.
static func sparks(amount: int, vida: float, dir: Vector3, spread: float,
		vmin: float, vmax: float, tam: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = tam * 0.5
	pm.scale_max = tam * 1.4
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, ELECTRIC_YELLOW, LIGHTNING_CYAN, Color(0, 0, 0, 0)])
	return FxUtil.particles(amount, vida, true, pm, FxUtil.grain(tam * 0.4), 0.85)

static func _screen_flash(world: Node, col: Color, forca: float) -> void:
	var sfx := world.get_node_or_null("/root/ScreenFX") if is_instance_valid(world) else null
	if sfx and sfx.has_method("flash"):
		sfx.flash(col, forca)

static func _shake(caster: Node, forca: float) -> void:
	if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(forca)

# ---------------------------------------------------------------------------
#  Bolt — UM raio. Um nó, um MultiMesh, e o tremelique de graça.
#
#  `anchor` existe para o Sango: o corpo do jogador fica parado e a cabeça do
#  raio voa; o pé do raio precisa ser recalculado todo quadro no espaço LOCAL
#  do nó que voa. Sem isso o raio "descola" do peito do personagem.
# ---------------------------------------------------------------------------
class Bolt extends MultiMeshInstance3D:
	var from_p := Vector3.ZERO
	var to_p := Vector3.ZERO
	var segs := 10
	var jag := 0.4
	var thick := 0.12
	var forks := 2
	var flick := 0.035          # segundos entre redesenhos (0 = raio parado)
	var anchor: Node3D = null   # se definido, `from_p` vira a posição dele
	var anchor_offset := Vector3.ZERO
	var _acc := 999.0

	func _init(a: Vector3, b: Vector3, cor: Color, energia: float,
			n_segs: int, amp: float, grossura: float, n_forks: int) -> void:
		from_p = a
		to_p = b
		segs = n_segs
		jag = amp
		thick = grossura
		forks = n_forks
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = GoroFX.bolt_instance_count(segs, forks)
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		multimesh = mm
		material_override = GoroFX.volt_material(cor, energia)

	func _process(delta: float) -> void:
		_acc += delta
		if flick > 0.0 and _acc < flick:
			return
		_acc = 0.0
		if anchor != null and is_instance_valid(anchor) and is_inside_tree():
			from_p = to_local(anchor.global_position + anchor_offset)
		GoroFX.bolt_fill(multimesh, from_p, to_p, segs, jag, thick, forks)

	# Some suavemente e se liberta (usado quando o raio tem que "apagar").
	func apagar(dur: float) -> void:
		set_process(false)
		var mat := material_override as StandardMaterial3D
		if mat == null:
			queue_free()
			return
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, dur)
		tw.tween_callback(queue_free)


# ---------------------------------------------------------------------------
#  Flicker — a luz que mora DENTRO da nuvem. É ela que faz a massa escura
#  parecer carregada em vez de parecer um borrão cinza pendurado no céu.
# ---------------------------------------------------------------------------
class Flicker extends OmniLight3D:
	var base_energy := 6.0
	var velocidade := 11.0
	var _t := 0.0

	func _init(cor: Color, energia: float, alcance: float) -> void:
		light_color = Color(cor.r, cor.g, cor.b)
		base_energy = energia
		omni_range = alcance
		light_energy = energia * 0.5

	func _process(delta: float) -> void:
		_t += delta * velocidade
		var n: float = 0.35 + 0.35 * absf(sin(_t) * sin(_t * 2.7))
		if randf() < 0.05:
			n = 2.1          # o "clarão" de relâmpago dentro da nuvem
		light_energy = base_energy * n


# ============================================================================
#  DESPACHO
# ============================================================================
static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null, charge: float = 0.0) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _sango(world, origin, dir, damage, caster, spec)
		1: GoroFXGrande.el_thor(world, origin, dir, damage, caster, spec)
		2: _shunshin(world, origin, dir, damage, caster, spec)
		_: GoroFXGrande.mamaragan(world, origin, dir, damage, caster, spec, charge)

# ---------- Z: Sango — o raio que SAI DO CORPO do jogador ----------
#
#  Camadas (6):
#    1. cabeça: núcleo branco incandescente que voa na frente da hitbox
#    2. halo ciano ao redor da cabeça (dá volume ao ponto de luz)
#    3. o RAIO em si: zigue-zague ancorado no PEITO do jogador, esticando
#       enquanto a cabeça se afasta — é isso que faz ele "sair do corpo"
#    4. um segundo raio, mais fino e mais nervoso, na mesma linha (espessura)
#    5. fagulhas voltaicas saindo da cabeça
#    6. descarga de saída no peito + luz + estalo + flash de tela
#  Duração: raio-tether apaga em ~0,45 s; a cabeça e a hitbox vivem 1,1 s.
static func _sango(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd: Vector3 = dir.normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, -1)

	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	# 1. Cabeça: núcleo branco.
	var nucleo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.30
	sm.height = 0.60
	nucleo.mesh = sm
	nucleo.material_override = volt_material(FLASH_WHITE, 9.0)
	zone.add_child(nucleo)

	# 2. Halo ciano.
	var halo := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.75
	sm2.height = 1.50
	halo.mesh = sm2
	var halo_mat := volt_material(LIGHTNING_CYAN, 3.2)
	halo_mat.albedo_color.a = 0.35
	halo.material_override = halo_mat
	zone.add_child(halo)
	var tw_halo := halo.create_tween().set_loops()
	tw_halo.tween_property(halo, "scale", Vector3(1.35, 1.35, 1.35), 0.09)
	tw_halo.tween_property(halo, "scale", Vector3(0.85, 0.85, 0.85), 0.09)

	# 3 + 4. Os dois raios ancorados no peito do jogador.
	var peito_offset := Vector3(0, 1.15, 0)
	for camada in range(2):
		var grosso: bool = camada == 0
		var b := Bolt.new(Vector3.ZERO, Vector3.ZERO,
			ELECTRIC_YELLOW if grosso else FLASH_WHITE,
			7.0 if grosso else 10.0,
			20 if grosso else 20,
			0.85 if grosso else 0.35,
			0.20 if grosso else 0.08,
			3 if grosso else 1)
		b.flick = 0.03
		zone.add_child(b)
		if is_instance_valid(caster) and caster is Node3D:
			b.anchor = caster as Node3D
			b.anchor_offset = peito_offset
		else:
			b.from_p = -fwd * 3.0
		FxUtil.autofree(b, 0.45)

	# 5. Fagulhas na cabeça do raio.
	zone.add_child(sparks(200, 0.45, -fwd, 55.0, 6.0, 15.0, 0.34))

	# 6. Descarga de SAÍDA no peito: anel + estouro + luz + som.
	var saida := Node3D.new()
	world.add_child(saida)
	saida.global_position = origin
	var luz := Flicker.new(LIGHTNING_CYAN, 9.0, 12.0)
	luz.velocidade = 26.0
	saida.add_child(luz)
	saida.add_child(sparks(90, 0.35, fwd, 70.0, 4.0, 11.0, 0.28))
	shock_ring(saida, Vector3.ZERO, LIGHTNING_CYAN, 3.6, 0.30)
	var tw_luz := saida.create_tween()
	tw_luz.tween_interval(0.18)
	tw_luz.tween_property(luz, "base_energy", 0.0, 0.25)
	FxUtil.autofree(saida, 0.75)

	AudioFX.snap(world, origin, 1.55)
	AudioFX.impact(world, origin, 1.35)
	_screen_flash(world, Color(0.85, 0.95, 1.0), 0.30)
	_shake(caster, 0.22)

	zone.setup(spec.dano, 14.0, fwd * 32.0, 1.1, caster, 1.0)
	spec.marcar(zone)

# ---------- C: Shunshin — Dash / Teleporte Elétrico Instantâneo ----------
# NÃO MEXER: decisão do dono do projeto — o C fica para bem mais tarde.
static func _shunshin(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()

	# Rastro instantâneo de faíscas
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd   # segue a mira (-Z), não o eixo Z do mundo
	pm.spread = 20.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 14.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, LIGHTNING_CYAN, Color(0, 0, 0, 0)])

	var flash := FxUtil.particles(200, 0.4, true, pm, FxUtil.grain(0.4))
	zone.add_child(flash)

	# Se o invocador for o jogador, projeta o corpo 12m pra frente
	if caster is CharacterBody3D:
		(caster as CharacterBody3D).global_position += fwd * 12.0

	zone.setup(spec.dano, 10.0, fwd * 25.0, 0.6, caster, 1.2)
	spec.marcar(zone)
