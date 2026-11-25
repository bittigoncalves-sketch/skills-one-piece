extends Node3D
## Preenchimento local do fundo do mar. Não altera o ambiente do ciclo dia/noite.
const ALCANCE := 32.0
const ENERGIA := 2.4
var jogador_de: Callable
var luz: OmniLight3D
var intensidade := 0.0

func _ready() -> void:
	luz = OmniLight3D.new()
	luz.name = "LuzSubaquatica"
	luz.light_color = Color(.48, .79, .88)
	luz.omni_range = ALCANCE
	luz.omni_attenuation = .7
	luz.light_size = 4.0
	luz.shadow_enabled = false
	luz.light_energy = 0.0
	luz.visible = false
	add_child(luz)

func _process(delta: float) -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var alvo := 0.0
	if is_instance_valid(j):
		global_position = j.global_position + Vector3.UP * 1.5
		var nivel := AguaDoMundo.nivel_em(j.global_position.x, j.global_position.z)
		if not is_nan(nivel):
			alvo = smoothstep(0.2, 1.8, nivel - j.global_position.y)
	intensidade = lerpf(intensidade, alvo, 1.0 - exp(-5.0 * delta))
	luz.light_energy = ENERGIA * intensidade
	luz.visible = intensidade > .01
