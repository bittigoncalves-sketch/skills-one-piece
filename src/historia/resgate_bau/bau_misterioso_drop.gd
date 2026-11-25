class_name BauMisteriosoDrop
extends Node3D
# ============================================================================
#  O DROP "BAÚ MISTERIOSO" (21/11/2026) — um baú pequeno e brilhante no chão onde o mímico caiu, com o nome flutuando em cima. O jogador o PEGA chegando perto (`RAIO_DE_PEGAR`).
#  Sinal `pegou` UMA vez. Texturas: `res://assets/textures/resgate_bau/bau_misterioso.png` (16×16, arte do Codex) se existir.
# ============================================================================
signal pegou

const RAIO_DE_PEGAR := 2.0
const GRUPO := "drop_de_missao"

var jogador_de: Callable = Callable()
var _pego := false
var _t := 0.0
var _corpo: Node3D


func _ready() -> void:
	add_to_group(GRUPO)
	name = "BauMisteriosoDrop"
	_corpo = Node3D.new()
	add_child(_corpo)
	# O baú é de MADEIRA (as mesmas texturas do mímico, como no conceito do Codex) com um brilho roxo DISCRETO; o ícone `bau_misterioso.png` (16×16, com alfa) flutua em cima como `Sprite3D`.
	var madeira := _material_madeira("mimico_corpo", Color(0.52, 0.33, 0.14))
	var tampa := _material_madeira("mimico_tampa", Color(0.6, 0.38, 0.17))
	var corpo := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.62, 0.34, 0.44)
	corpo.mesh = b
	corpo.material_override = madeira
	corpo.position.y = 0.4
	_corpo.add_child(corpo)
	var tp := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.64, 0.16, 0.46)
	tp.mesh = tb
	tp.material_override = tampa
	tp.position.y = 0.65
	_corpo.add_child(tp)
	var aro := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(0.66, 0.05, 0.48)
	aro.mesh = ab
	var ouro := StandardMaterial3D.new()
	ouro.albedo_color = Color(0.95, 0.8, 0.25)
	aro.material_override = ouro
	aro.position.y = 0.57
	_corpo.add_child(aro)
	var icone := "res://assets/textures/resgate_bau/bau_misterioso.png"
	if ResourceLoader.exists(icone):
		var sp := Sprite3D.new()
		sp.texture = load(icone) as Texture2D
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.pixel_size = 0.04
		sp.position.y = 1.45
		sp.name = "Icone"
		add_child(sp)
	var rotulo := Label3D.new()
	rotulo.text = "Baú misterioso"
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 36
	rotulo.pixel_size = 0.004
	rotulo.outline_size = 10
	rotulo.modulate = Color(0.85, 0.7, 1.0)
	rotulo.position.y = 1.9
	add_child(rotulo)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.7, 0.5, 1.0)
	luz.light_energy = 0.7
	luz.omni_range = 4.0
	luz.position.y = 0.5
	add_child(luz)


func _material_madeira(textura: String, cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	var caminho := "res://assets/textures/resgate_bau/%s.png" % textura
	if ResourceLoader.exists(caminho):
		m.albedo_texture = load(caminho) as Texture2D
		m.albedo_color = Color.WHITE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.emission_enabled = true                          # brilho roxo discreto: não apaga o desenho da madeira
	m.emission = Color(0.45, 0.25, 0.8)
	m.emission_energy_multiplier = 0.18
	return m


func _process(delta: float) -> void:
	_t += delta
	_corpo.position.y = 0.12 * sin(_t * 2.4)           # flutua
	_corpo.rotation.y += delta * 1.2
	if _pego:
		return
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j != null and j.global_position.distance_to(global_position) <= RAIO_DE_PEGAR:
		pegar()


## A mochila estava cheia: o drop continua no chão e volta a poder ser pego depois de 2,5 s (para o aviso não repetir a cada quadro).
func soltar_de_novo() -> void:
	await get_tree().create_timer(2.5).timeout
	_pego = false


## Chegou perto: AVISA (`pegou`); quem decide é o orquestrador (cabe na mochila?) e chama `aceitar` ou `soltar_de_novo`.
func pegar() -> void:
	if _pego:
		return
	_pego = true
	pegou.emit()


## O jogador ficou com o item: o drop some (sobe e encolhe).
func aceitar() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector3.ONE * 0.05, 0.3)
	t.tween_property(self, "position:y", position.y + 1.0, 0.3)
	t.chain().tween_callback(queue_free)
