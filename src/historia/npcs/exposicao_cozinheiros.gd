extends Node
## Modelos de apresentação (15/10/2026), sem loja ou combate.
## Os clipes e os pesos vêm do GLB, editável em art_src/cozinheiros/.
const NOMES := {
	"cozinheiro_sanji": "Sanji",
	"cozinheiro_beto": "Beto · Mestre do fogão",
	"cozinheiro_iara": "Iara · Confeiteira",
	"cozinheiro_ravi": "Ravi · Cozinha do mar",
	"cozinheiro_otto": "Otto · Padeiro",
}
const CICLO := ["descanso", "saudacao", "cozinhar", "descanso", "caminhada"]
const DURACOES := [5.0, 3.0, 9.0, 4.0, 3.6]
var animador: AnimationPlayer
var _utensilios: Array[Node3D] = []
var _fase := 0
var _tempo := 0.0


## Idempotente: conserva a peça e o modelo do editor, acrescentando só apresentação.
static func ligar(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos) -> void:
	for p: Dictionary in mapa.get("pecas", []):
		var id: String = str(p.get("modelo", ""))
		if not NOMES.has(id) or not biblioteca.tem(id):
			continue
		var peca := raiz.get_node_or_null(NodePath(str(p["id"]))) as Node3D
		if peca == null or peca.has_node("ApresentacaoCozinheiro"):
			continue
		var modelo := peca.get_node_or_null("Modelo") as Node3D
		if modelo == null:
			continue
		var controlador := load("res://src/historia/npcs/exposicao_cozinheiros.gd").new() as Node
		controlador.name = "ApresentacaoCozinheiro"
		peca.add_child(controlador)
		controlador.configurar(modelo, id, NOMES.keys().find(id))
		peca.add_to_group("cozinheiros_exposicao")
		# A história marcou o mapa antes de ligar NPCs. Roupas não são cenário
		# para os decalques de gelo, como ocorre com os NPCs que substituem peças.
		for visual in modelo.find_children("*", "GeometryInstance3D", true, false):
			visual.layers &= ~MapaMontador.CAMADA_CENARIO
		# O volume do corpo permite circular em volta sem colidir com braços/utensílios.
		for filho in peca.get_children():
			if filho is CollisionShape3D:
				var capsula := CapsuleShape3D.new()
				capsula.height = (p["tamanho"] as Vector3).y
				capsula.radius = 0.30
				filho.shape = capsula
		var nome := Label3D.new()
		nome.name = "NomeCozinheiro"
		nome.text = NOMES[id]
		nome.position.y = (p["tamanho"] as Vector3).y * 0.5 + 0.20
		nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nome.font_size = 32
		nome.pixel_size = 0.003
		nome.outline_size = 8
		nome.modulate = Color(1.0, 0.88, 0.59)
		peca.add_child(nome)


func configurar(modelo: Node3D, id: String, indice: int) -> void:
	var players := modelo.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Cozinheiro sem AnimationPlayer: " + id)
		set_process(false)
		return
	animador = players[0] as AnimationPlayer
	for no in modelo.find_children("Utensilio*", "MeshInstance3D", true, false):
		_utensilios.append(no as Node3D)
	for clipe: String in CICLO:
		if not animador.has_animation(clipe):
			push_error("Cozinheiro sem clipe: %s / %s" % [id, clipe])
			set_process(false)
			return
		# O GLB mantém ações editáveis; looping é configuração da apresentação.
		# A biblioteca é partilhada entre instâncias: duplicar antes de configurar.
	var biblioteca := animador.get_animation_library("").duplicate(true) as AnimationLibrary
	animador.remove_animation_library("")
	animador.add_animation_library("", biblioteca)
	for clipe: String in CICLO:
		animador.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
	_fase = indice % CICLO.size()
	mostrar(CICLO[_fase])


func mostrar(clipe: String) -> void:
	if animador == null or not animador.has_animation(clipe):
		return
	for objeto in _utensilios:
		objeto.visible = clipe == "cozinhar"
	animador.play(clipe, 0.25)


func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= DURACOES[_fase]:
		_tempo = fmod(_tempo, DURACOES[_fase])
		_fase = (_fase + 1) % CICLO.size()
		mostrar(CICLO[_fase])
