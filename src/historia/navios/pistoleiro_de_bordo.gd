class_name PistoleiroDeBordo
extends Node
# ============================================================================
#  BARBA NEGRA A BORDO (15/10/2026) — atira de pistola, de dentro do barco, em qualquer
#  inimigo. Decisão do dono; "qualquer inimigo" = o grupo `enemy` até `ALCANCE` m.
#
#  Pendurado no `TripulanteHumano` (que é filho do barco): vira o corpo para o alvo, sacode
#  o coice e solta uma bala — uma `DamageZone` pequena e rápida, com o JOGADOR como autor
#  (então o jogador não leva o tiro, o placar credita a ele e o dono do dano é dele). O
#  casco do próprio barco é poupado (a bala nasce dentro dele).
#
#  Os números vivem aqui, num lugar só: `DANO` e `INTERVALO` são ESCOLHA minha (o dono só
#  pediu a pistola) — a Buki usa 16 por bala; 12 a cada 0,9 s é um aliado, não um segundo jogador.
# ============================================================================

const ALCANCE := 45.0
const INTERVALO := 0.9
const DANO := 12.0
const VELOCIDADE := 95.0
const RAIO_DA_BALA := 0.22

var tripulante: Node3D            # o TripulanteHumano
var barco: Node3D
var dono: Node                    # quem assina o dano: o jogador
var disparos := 0
var passeio: Node                 # o `PasseioNoConves` dele: para de andar enquanto mira
var _recarga := 0.4
var _pistola: Node3D


func _ready() -> void:
	_pistola = _montar_pistola()
	var mao: Node3D = tripulante.call("mao") if tripulante != null and tripulante.has_method("mao") else null
	(mao if mao != null else tripulante).add_child(_pistola)
	# A pistola está na mão desde o início (ele já embarca armado).
	_pistola.position = Vector3(0, -0.05, -0.08)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(tripulante) or not is_instance_valid(barco) or not tripulante.is_inside_tree():
		return
	_recarga -= delta
	var alvo := Tripulacao.inimigo_mais_proximo(get_tree(), boca(), ALCANCE)
	if is_instance_valid(passeio):
		passeio.set("parado", alvo != null)      # com inimigo ao alcance ele para e atira
	if alvo == null:
		return
	var rumo := alvo.global_position - tripulante.global_position
	tripulante.call("virar_para", rumo, 1.0 - exp(-12.0 * delta))
	if _recarga <= 0.0:
		_recarga = INTERVALO
		disparar(alvo)


## A boca do cano (no mundo). Sem pistola montada ainda, a altura do peito.
func boca() -> Vector3:
	if is_instance_valid(_pistola) and _pistola.is_inside_tree():
		return _pistola.global_position
	return tripulante.global_position + Vector3.UP * 1.3


func disparar(alvo: Node3D) -> Node:
	var origem := boca()
	var dir := (alvo.global_position + Vector3.UP * 0.9 - origem).normalized()
	var mundo := barco.get_parent()
	var zona := DamageZone.new()
	mundo.add_child(zona)
	zona.global_position = origem
	zona.look_at(origem + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	zona.setup(DANO, 6.0, dir * VELOCIDADE, ALCANCE / VELOCIDADE + 0.2, dono, RAIO_DA_BALA)
	zona.is_projectile = true
	zona.feedback_global = false          # sem tremor de tela: quem atira é o aliado
	zona._hit[barco] = true               # o casco que nasce em volta da bala não é alvo
	zona.add_child(_rastro())
	_clarao(mundo, origem)
	AudioFX.pistol(mundo, origem, 0.85)
	disparos += 1
	return zona


func _rastro() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.05, 0.05, 1.1)
	m.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.25)
	mat.emission_energy_multiplier = 3.0
	m.material_override = mat
	m.position.z = 0.55
	return m


func _clarao(mundo: Node, origem: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.75, 0.35)
	luz.light_energy = 2.5
	luz.omni_range = 4.0
	mundo.add_child(luz)
	luz.global_position = origem
	var t := luz.create_tween()
	t.tween_property(luz, "light_energy", 0.0, 0.08)
	t.tween_callback(luz.queue_free)


static func _montar_pistola() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Pistola"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.14, 0.14, 0.16)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var corpo := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.05, 0.08, 0.2)
	corpo.mesh = caixa
	corpo.material_override = metal
	raiz.add_child(corpo)
	var cano := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.016
	cil.bottom_radius = 0.016
	cil.height = 0.16
	cano.mesh = cil
	cano.material_override = metal
	cano.rotation.x = PI * 0.5
	cano.position = Vector3(0, 0.02, -0.16)
	raiz.add_child(cano)
	return raiz
