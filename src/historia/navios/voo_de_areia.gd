class_name VooDeAreia
extends Node
# ============================================================================
#  CROCODILE A BORDO (15/10/2026) — voa em volta do barco e dispara o Z da Suna Suna em
#  qualquer inimigo; durante o voo a parte de baixo dele vira areia. Decisão do dono.
#
#  • VOO: sobe do convés e circula o barco (`RAIO` m, `ALTURA` m) no referencial DO BARCO,
#    então acompanha o casco onde ele for. O corpo se inclina para a frente (voando) e olha
#    na tangente; ao atirar, vira para o alvo.
#  • AREIA: as pernas encolhem (`PernasDeAreia`) e no lugar vêm um cone de areia girando e
#    grãos caindo, presos ao quadril. Ao pousar (dispensar) tudo some junto com o nó.
#  • Z: o MESMO `SandFX` da lâmina de areia do jogador (Desert Spada), com a spec do
#    `Balance` da `suna_suna/Z` na escala `ESCALA_DE_DANO` — ESCOLHA minha (o dono não disse
#    quanto): 0,5 faz dele um aliado, não um segundo jogador. O jogador assina o dano (não leva
#    o corte) e o casco é poupado.
# ============================================================================

const RAIO := 7.0
const ALTURA := 5.5
const VELOCIDADE_ANGULAR := 0.55
const SUBIDA := 0.7             # 1/s: a transição do convés para o voo leva ~1,4 s
const INCLINACAO := -1.0        # rad no eixo X do corpo (cabeça para a frente)
const ALCANCE := 45.0
const INTERVALO := 2.6
const ESCALA_DE_DANO := 0.5
const COR_AREIA := Color(0.93, 0.78, 0.45)

var tripulante: Node3D            # o TripulanteHumano
var barco: Node3D
var dono: Node
var disparos := 0
var progresso := 0.0              # 0 = no convés, 1 = voando
var _angulo := randf() * TAU
var _recarga := 1.5
var _convez := Vector3.ZERO
var _pernas: PernasDeAreia
var _areia: Node3D
var _montou := false


func _ready() -> void:
	_convez = tripulante.position
	var sk: Skeleton3D = tripulante.call("esqueleto")
	if sk != null:
		_pernas = PernasDeAreia.new()
		_pernas.name = "PernasDeAreia"
		sk.add_child(_pernas)


func esta_voando() -> bool:
	return progresso >= 0.99


func forca_da_areia() -> float:
	return _pernas.forca if _pernas != null else 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(tripulante) or not is_instance_valid(barco) or not tripulante.is_inside_tree():
		return
	progresso = move_toward(progresso, 1.0, SUBIDA * delta)
	var suave := smoothstep(0.0, 1.0, progresso)
	_angulo += VELOCIDADE_ANGULAR * delta
	var orbita := Vector3(cos(_angulo) * RAIO, ALTURA + sin(_angulo * 2.3) * 0.4, sin(_angulo) * RAIO)
	var antes := tripulante.position
	tripulante.position = _convez.lerp(orbita, suave)
	var corpo: Node3D = tripulante.call("corpo")
	if corpo != null:
		corpo.rotation.x = lerpf(0.0, INCLINACAO, suave)
	if _pernas != null:
		_pernas.forca = suave
	_atualizar_areia(suave, corpo)
	_recarga -= delta
	var alvo := Tripulacao.inimigo_mais_proximo(get_tree(), tripulante.global_position, ALCANCE)
	if alvo != null:
		tripulante.call("virar_para", alvo.global_position - tripulante.global_position, 1.0 - exp(-8.0 * delta))
		if _recarga <= 0.0 and esta_voando():
			_recarga = INTERVALO
			disparar(alvo)
	else:
		var tangente := barco.to_global(tripulante.position) - barco.to_global(antes)
		tripulante.call("virar_para", tangente, 1.0 - exp(-4.0 * delta))


## O Z: a lâmina de areia (Desert Spada) rumo ao alvo, partindo da frente do Crocodile.
func disparar(alvo: Node3D) -> Node:
	var origem := tripulante.global_position + Vector3.UP * 0.4
	var dir := (alvo.global_position + Vector3.UP * 0.9 - origem).normalized()
	var spec := Balance.novo("suna_suna", "Z", ESCALA_DE_DANO)
	if spec == null:
		spec = DamageSpec.avulso(0.0)
	var zona := SandFX.cast(barco.get_parent(), origem + dir * 1.0, dir, 0, spec.dano, dono, spec)
	if zona != null:
		zona._hit[barco] = true            # a lâmina nasce perto do casco: ele não é alvo
	disparos += 1
	return zona


# ------------------------------------------------------------------ a areia no lugar das pernas

func _atualizar_areia(suave: float, corpo: Node3D) -> void:
	if corpo == null:
		return
	if _areia == null and suave > 0.0:
		_areia = _montar_areia(corpo)
	if _areia != null:
		_areia.visible = suave > 0.02
		_areia.scale = Vector3.ONE * clampf(suave, 0.05, 1.0)


func _montar_areia(corpo: Node3D) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "AreiaDasPernas"
	corpo.add_child(raiz)
	raiz.position = _quadril(corpo)
	# O cone: largo no quadril, afilando para baixo (−Y do corpo), em facetas — a areia é
	# feita de blocos neste jogo (ver `SandFX`).
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	var malha := CylinderMesh.new()
	malha.top_radius = 0.30
	malha.bottom_radius = 0.03
	malha.height = 1.15
	malha.radial_segments = 8
	malha.rings = 3
	cone.mesh = malha
	cone.position.y = -malha.height * 0.5
	cone.material_override = _material_da_areia()
	raiz.add_child(cone)
	# Grãos soltos caindo da ponta.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.color_ramp = FxUtil.gradient([COR_AREIA, Color(COR_AREIA, 0.0)])
	var graos := FxUtil.particles(70, 0.9, false, pm, FxUtil.grain(0.1))
	graos.name = "Graos"
	graos.position.y = -malha.height
	raiz.add_child(graos)
	return raiz


## Onde fica o quadril, no referencial do corpo (lido do esqueleto; sem esqueleto, 0,95 m).
func _quadril(corpo: Node3D) -> Vector3:
	var sk: Skeleton3D = tripulante.call("esqueleto")
	if sk != null:
		var i := sk.find_bone("Hips")
		if i >= 0:
			return corpo.to_local(sk.to_global(sk.get_bone_global_rest(i).origin))
	return Vector3(0, 0.95, 0)


static func _material_da_areia() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform vec4 areia : source_color = vec4(0.93, 0.78, 0.45, 1.0);
void fragment() {
	// Faixas que sobem pelo cone: a areia escoando, sem textura.
	float faixa = 0.5 + 0.5 * sin(UV.y * 34.0 - TIME * 7.0 + UV.x * 18.0);
	ALBEDO = areia.rgb * (0.78 + 0.22 * faixa);
	EMISSION = areia.rgb * 0.12;
	ROUGHNESS = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
