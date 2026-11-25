extends Node3D
# ============================================================================
#  ENCONTROS NO MAR — besta agressiva surgindo com o jogador navegando
#  (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5).
#
#  Decisões do dono (14/10):
#   - surge por CHANCE só com o jogador PILOTANDO em mar aberto; ~1 encontro a cada
#     5–6 min (sorteio a cada `INTERVALO` s com chance de média `MEDIA_ENTRE_ENCONTROS`);
#   - COMEÇA ATACANDO O BARCO; se o jogador a acertar, passa a atacar o jogador (isso já é
#     o `take_damage` da besta: o alvo vira quem bateu);
#   - barco a zero AFUNDA e é PERDIDO (`barco.gd` + `Navegacao._barco_afundou`).
#  Escolhas minhas (ajustáveis): aviso de redemoinho por 3 s antes de surgir; máximo uma
#  por vez; nada a menos de 150 m da costa nem com menos de 25 m de água; serpente só com
#  mais de 45 m de água (mar aberto/fossa); a besta desiste depois de 2 min de caça, se o
#  barco chegar perto da costa ou se o jogador ficar a mais de 250 m — mergulha e some.
#  Folga de 90 s entre um encontro e o próximo.
# ============================================================================

const Besta := preload("res://src/historia/bestas_mar/besta_do_mar.gd")
const REDEMOINHO := preload("res://src/historia/mar/redemoinho.gdshader")

const INTERVALO := 20.0
const MEDIA_ENTRE_ENCONTROS := 330.0
const LONGE_DA_COSTA := 150.0
const PROFUNDIDADE_MINIMA := 25.0
const PROFUNDIDADE_SERPENTE := 45.0
const DURACAO_DO_AVISO := 3.0
const DISTANCIA_DE_SURGIR := 38.0
const DURACAO_MAXIMA := 120.0
const DESISTE_LONGE := 250.0
const FOLGA_ENTRE_ENCONTROS := 90.0
const PESOS := {"besta_mar_bovina": 30.0, "besta_mar_girafa": 30.0, "besta_mar_javali": 25.0, "besta_mar_serpente": 15.0}

enum Fase { ESPERA, AVISO, COMBATE, RECUO }

signal comecou(besta: Node3D)
signal terminou(motivo: String)

var relevo: RelevoMarinho
var jogador_de: Callable
var navegacao_de: Callable
var ao_abater_besta: Callable
var hud: Node
var rng := RandomNumberGenerator.new()
var fase := Fase.ESPERA
var besta: Node3D
var barco_alvo: Node3D
var _bib: BibliotecaDeModelos
var _relogio := INTERVALO
var _folga := 0.0
var _tempo := 0.0
var _ponto := Vector3.ZERO
var _aviso: MeshInstance3D
var _bolhas: GPUParticles3D
## Giro do redemoinho guardado aqui: `get_shader_parameter` de uniforme nunca definido
## devolve null (a mesma armadilha do `oceano_historia.gd`, docs/erros.md).
var _giro := 0.0


## Chance de um sorteio dar encontro: média de `MEDIA_ENTRE_ENCONTROS` s entre eles.
static func chance_por_sorteio() -> float:
	return 1.0 - exp(-INTERVALO / MEDIA_ENTRE_ENCONTROS)


func ligar(contexto: Dictionary, campo: RelevoMarinho, jogador: Callable) -> void:
	relevo = campo
	jogador_de = jogador
	navegacao_de = contexto.get("navegacao", Callable())
	ao_abater_besta = contexto.get("ao_abater_besta", Callable())
	hud = contexto.get("hud")
	_bib = contexto.get("bib")
	rng.randomize()


## Barco que o jogador pilota agora, ou null.
func barco_pilotado() -> Node3D:
	var nav: Node = navegacao_de.call() if navegacao_de.is_valid() else null
	if nav == null or not nav.ativo():
		return null
	return nav.get("barco")


## Mar aberto: longe da costa e fundo.
func mar_aberto(p: Vector3) -> bool:
	var d := INF
	for r in relevo.ilhas:
		d = minf(d, RelevoMarinho._fora(r, Vector2(p.x, p.z)))
	return d >= LONGE_DA_COSTA and relevo.profundidade(p.x, p.z) >= PROFUNDIDADE_MINIMA


func _process(delta: float) -> void:
	if relevo == null or _bib == null:
		return
	match fase:
		Fase.ESPERA:
			_folga = maxf(0.0, _folga - delta)
			_relogio -= delta
			if _relogio > 0.0:
				return
			_relogio = INTERVALO
			var b := barco_pilotado()
			if _folga <= 0.0 and b != null and mar_aberto(b.global_position) and rng.randf() < chance_por_sorteio():
				avisar(b)
		Fase.AVISO:
			_tempo += delta
			_animar_aviso(delta)
			if _tempo >= DURACAO_DO_AVISO:
				_surgir()
		Fase.COMBATE:
			_vigiar(delta)


## Força um encontro com o barco pilotado (F8 e testes). "" ou o motivo de não dar.
func forcar() -> String:
	if fase != Fase.ESPERA:
		return "Já há um encontro em andamento."
	var b := barco_pilotado()
	if b == null:
		return "Pilote um barco para chamar uma besta do mar."
	return "" if avisar(b) else "Sem água funda o bastante perto do barco."


## Começa o aviso perto do barco. false se não achou água funda para surgir.
func avisar(b: Node3D) -> bool:
	var frente := -b.global_basis.z
	frente.y = 0.0
	frente = frente.normalized() if frente.length() > 0.01 else Vector3.FORWARD
	for tentativa in 8:
		var ang := deg_to_rad(rng.randf_range(-60.0, 60.0))
		var p := b.global_position + frente.rotated(Vector3.UP, ang) * DISTANCIA_DE_SURGIR
		if relevo.profundidade(p.x, p.z) >= PROFUNDIDADE_MINIMA - 5.0:
			_ponto = Vector3(p.x, relevo.nivel, p.z)
			barco_alvo = b
			fase = Fase.AVISO
			_tempo = 0.0
			_criar_aviso()
			if hud != null and hud.has_method("avisar"):
				hud.avisar("A água borbulha ao lado do barco… algo enorme está subindo!")
			return true
	return false


func _criar_aviso() -> void:
	_aviso = MeshInstance3D.new()
	_aviso.name = "Redemoinho"
	var disco := PlaneMesh.new()
	disco.size = Vector2(24, 24)
	_aviso.mesh = disco
	var m := ShaderMaterial.new()
	m.shader = REDEMOINHO
	_aviso.material_override = m
	_giro = 0.0
	_aviso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aviso)
	_aviso.global_position = _ponto + Vector3.UP * 0.4     # acima das cristas (±0,65 m)
	_bolhas = GPUParticles3D.new()
	_bolhas.name = "Bolhas"
	_bolhas.amount = 48
	_bolhas.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.5
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	_bolhas.process_material = pm
	var bola := SphereMesh.new()
	bola.radius = 0.16
	bola.height = 0.32
	bola.radial_segments = 8
	bola.rings = 4
	var branco := StandardMaterial3D.new()
	branco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	branco.albedo_color = Color(0.85, 0.97, 1.0)
	bola.material = branco
	_bolhas.draw_pass_1 = bola
	add_child(_bolhas)
	_bolhas.global_position = _ponto + Vector3.UP * 0.1


func _animar_aviso(delta: float) -> void:
	if not is_instance_valid(_aviso):
		return
	var t := _tempo / DURACAO_DO_AVISO
	var m := _aviso.material_override as ShaderMaterial
	m.set_shader_parameter("forca", smoothstep(0.0, 0.25, t))
	_giro += delta * (0.4 + t * 1.6)
	m.set_shader_parameter("giro", _giro)
	_aviso.scale = Vector3.ONE * lerpf(0.5, 1.15, t)


func _sortear_especie(prof: float) -> String:
	var total := 0.0
	for id in PESOS:
		if id == "besta_mar_serpente" and prof < PROFUNDIDADE_SERPENTE:
			continue
		if _bib.tem(id):
			total += PESOS[id]
	var u := rng.randf() * total
	for id in PESOS:
		if (id == "besta_mar_serpente" and prof < PROFUNDIDADE_SERPENTE) or not _bib.tem(id):
			continue
		u -= PESOS[id]
		if u <= 0.0:
			return id
	return "besta_mar_bovina"


func _surgir() -> void:
	_apagar_aviso()
	if not is_instance_valid(barco_alvo) or float(barco_alvo.get("health")) <= 0.0:
		_fim("o barco já não existe")
		return
	var id := _sortear_especie(relevo.profundidade(_ponto.x, _ponto.z))
	var b := Besta.new()
	b.name = "BestaDoEncontro"
	b.alvo_de = jogador_de
	b.position = _ponto - Vector3.UP * 5.0
	add_child(b)
	var para := barco_alvo.global_position - _ponto
	b.montar(_bib, id, {"tamanho": _bib.tamanho_padrao(id), "rotacao_graus": Vector3(0, rad_to_deg(atan2(-para.x, -para.z)), 0)})
	b.set("origem", b.global_position)
	b.set("praia", b.global_position)
	b.set("mar", b.global_position)
	b.morreu.connect(_ao_morrer)
	if not b.is_in_group(BarrasDeChefes.GRUPO):
		b.add_to_group(BarrasDeChefes.GRUPO)      # vida no topo da tela durante a luta
	b.add_to_group("enemy")
	b.set("agressiva", true)
	b.set("alvo", barco_alvo)
	b.mudar("irritado")
	besta = b
	fase = Fase.COMBATE
	_tempo = 0.0
	comecou.emit(b)
	if hud != null and hud.has_method("avisar"):
		hud.avisar("%s ataca o barco!" % str(b.get("ficha").get("nome", "Uma besta do mar")))


func _vigiar(delta: float) -> void:
	if not is_instance_valid(besta):
		_fim("sumiu")
		return
	if str(besta.get("estado")) == "morto":
		_tempo += delta
		if _tempo > 5.0:
			besta.queue_free()
			_fim("abatida")
		return
	_tempo += delta
	# A coleira é a VISÃO até o alvo, não a distância do ponto onde surgiu.
	besta.set("origem", besta.global_position)
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var longe := j == null or j.global_position.distance_to(besta.global_position) > DESISTE_LONGE
	var alvo: Node3D = besta.get("alvo")
	var na_costa := is_instance_valid(alvo) and not mar_aberto(alvo.global_position) \
		and relevo.profundidade(alvo.global_position.x, alvo.global_position.z) < PROFUNDIDADE_MINIMA
	if not besta.get("agressiva") or _tempo > DURACAO_MAXIMA or longe or na_costa:
		recuar()


## A besta desiste: para de atacar, mergulha e some.
func recuar() -> void:
	if not is_instance_valid(besta):
		_fim("sumiu")
		return
	fase = Fase.RECUO
	besta.call("iniciar_rotina")
	besta.set_physics_process(false)
	besta.set_process(false)
	besta.remove_from_group("enemy")
	besta.remove_from_group(BarrasDeChefes.GRUPO)
	var b := besta
	var t := create_tween()
	t.tween_property(b, "global_position:y", b.global_position.y - 14.0, 3.0).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		if is_instance_valid(b):
			b.queue_free()
		_fim("recuou"))


func _ao_morrer(b: Node3D) -> void:
	_tempo = 0.0
	if ao_abater_besta.is_valid():
		ao_abater_besta.call(b)


func _apagar_aviso() -> void:
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	if is_instance_valid(_bolhas):
		_bolhas.emitting = false
		var bolhas := _bolhas
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(bolhas):
				bolhas.queue_free())


func _fim(motivo: String) -> void:
	_apagar_aviso()
	besta = null
	barco_alvo = null
	fase = Fase.ESPERA
	_relogio = INTERVALO
	_folga = FOLGA_ENTRE_ENCONTROS
	terminou.emit(motivo)
