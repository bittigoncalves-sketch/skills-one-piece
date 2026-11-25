extends Node
## ▶ TESTAR NO JOGO do Skills Builder (07/10/2026). Pedido do dono: "adicionar uma
## plataforma e um botão de play para teste das skills". Decisão: o JOGADOR de verdade
## (Modo História), a fruta/skill do editor já comida, energia cheia e bonecos de treino;
## Esc (ou o botão) volta ao editor com a skill como estava.
##
## Nada do jogo de verdade é tocado:
##   • o catálogo publicado é COPIADO para `user://teste_do_builder/skills` e a skill aberta
##     é publicada SÓ lá (`SkillsPublicadas.pasta_forcada`);
##   • o mapa é uma plataforma gerada aqui (60 × 60 m, bordas para o vazio e uma parede a
##     26 m — para "Parar antes do vazio" e "pára na parede");
##   • o save é um progresso de TESTE (`ModoHistoria.progresso_forcado`), apagado a cada vez.
## Este nó mora na RAIZ (atravessa a troca de cena) e desfaz tudo ao voltar — e também se
## o jogador sair do teste por outro caminho (menu), para o catálogo de teste não vazar.

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MODO := "res://src/historia/ModoHistoria.gd"
const PASTA := "user://teste_do_builder"
const SKILLS := PASTA + "/skills"
const MAPA := PASTA + "/plataforma.json"
const PROGRESSO := PASTA + "/progresso.json"
const BONECOS := [Vector3(0, 1, -6), Vector3(4, 1, -12), Vector3(-5, 1, -18), Vector3(7, 1, -3)]
const REVIVER_EM := 2.0

var documento := {}
var fruta := ""
var _cena_do_teste: Node = null
var _voltando := false
var _bonecos: Array[Node3D] = []
var _hud: CanvasLayer


## Abre o teste com a skill do editor `ed`. Devolve "" ou o motivo de não abrir.
static func abrir(ed: Control) -> String:
	var skill: Dictionary = ed.skill
	var v := Dados.validar(skill)
	if not v.ok:
		return "Corrija antes de testar: " + "; ".join(v.erros)
	if str(skill.identificacao.dono) != SkillsPublicadas.DONO_DO_KIT:
		return "O teste no jogo é para skills do Usuário Jogador."
	var erro := _copiar_catalogo()
	if not erro.is_empty():
		return erro
	SkillsPublicadas.pasta_forcada = SKILLS
	SkillsPublicadas.recarregar()
	var r := SkillsPublicadas.publicar(skill)
	if not r.ok:
		_desfazer_forcados()
		return "Não deu para testar: " + "; ".join(r.erros)
	# O mapa vai como TEXTO no formato do arquivo (o `MapaArquivo.salvar` quer o mapa já
	# carregado, com Vector3/Color); quem lê e valida é o Modo História, como sempre.
	var arquivo_do_mapa := FileAccess.open(MAPA, FileAccess.WRITE)
	if arquivo_do_mapa == null:
		_desfazer_forcados()
		return "Não deu para preparar a plataforma: " + error_string(FileAccess.get_open_error())
	arquivo_do_mapa.store_string(JSON.stringify(_plataforma(), "\t"))
	arquivo_do_mapa.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	var modo = load(MODO)
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", PROGRESSO)
	var t: Node = load("res://src/skills_builder/teste_no_jogo.gd").new()
	t.name = "TesteNoJogo"
	t.documento = skill.duplicate(true)
	var f := str(skill.identificacao.get("fruta", ""))
	t.fruta = f if not f.is_empty() else KitDoBuilder.ID
	ed.get_tree().root.add_child(t)
	ed.get_tree().root.get_node("GameFlow").start_story()
	return ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preparar.call_deferred()


## Espera a cena da história nascer e arma o teste nela.
func _preparar() -> void:
	var jogador: Node3D = null
	for i in 600:
		await get_tree().process_frame
		var cena := get_tree().current_scene
		if cena != null and cena.get("progressao") != null:
			jogador = get_tree().get_first_node_in_group("player") as Node3D
			if jogador != null:
				_cena_do_teste = cena
				break
	if jogador == null:
		_encerrar()
		return
	for i in 10:
		await get_tree().physics_frame
	var prog: ProgressaoDoPersonagem = _cena_do_teste.get("progressao")
	prog.nivel = 22      # nenhuma skill barrada por nível (o antigo teto absoluto)
	prog.mudou.emit()
	prog.comer_fruta(fruta)
	await get_tree().physics_frame
	jogador.set("energy", float(jogador.get("max_energy")))
	for pos: Vector3 in BONECOS:
		var b := BonecoDeDuelo.new()
		b.position = pos
		_cena_do_teste.add_child(b)
		b.derrotado.connect(_reviver)
		_bonecos.append(b)
	_montar_hud()


func _process(_delta: float) -> void:
	# Saiu do teste por outro caminho (menu, troca de cena): desfaz e some.
	if _cena_do_teste != null and not _voltando and (not is_instance_valid(_cena_do_teste) \
			or get_tree().current_scene != _cena_do_teste):
		print("[TesteNoJogo] saiu do teste por fora: desfazendo")
		_encerrar()


func _input(evento: InputEvent) -> void:
	if _cena_do_teste == null or _voltando:
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and (evento as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		voltar()


## De volta ao editor, com a skill como estava.
func voltar() -> void:
	if _voltando:
		return
	_voltando = true
	_desfazer_forcados()
	get_tree().root.get_node("GameFlow").start_skills_builder()
	for i in 600:
		await get_tree().process_frame
		var ed := get_tree().current_scene
		if ed != null and ed.has_method("_documento"):
			for k in 3:
				await get_tree().process_frame
			ed.call("_documento", documento)
			if ed.has_method("_avisar"):
				ed.call("_avisar", "Voltou do teste no jogo.")
			break
	queue_free()


## Enche a energia e devolve os bonecos (botão).
func reiniciar() -> void:
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador != null:
		jogador.set("energy", float(jogador.get("max_energy")))
	for b in _bonecos:
		if is_instance_valid(b):
			b.health = b.max_health


func _reviver(b: BonecoDeDuelo) -> void:
	await get_tree().create_timer(REVIVER_EM).timeout    # ferramenta de teste: não é regra de jogo
	if is_instance_valid(b):
		b.health = b.max_health


func _encerrar() -> void:
	_desfazer_forcados()
	queue_free()


static func _desfazer_forcados() -> void:
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	var modo = load(MODO)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")


func _montar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 60
	add_child(_hud)
	var painel := PanelContainer.new()
	# Canto superior DIREITO: o esquerdo é da vida/energia (no centro cobria a barra — foto).
	painel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	painel.offset_top = 12
	painel.offset_right = -12
	painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.03, 0.08, 0.1, 0.85)
	caixa.set_corner_radius_all(6)
	caixa.set_content_margin_all(10)
	painel.add_theme_stylebox_override("panel", caixa)
	_hud.add_child(painel)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	painel.add_child(linha)
	var texto := Label.new()
	texto.name = "AvisoDoTeste"
	var tecla := str(documento.get("ativacao", {}).get("tecla", "?"))
	texto.text = "TESTE DA SKILL  ·  %s na tecla %s  ·  Esc volta ao editor" % [str(documento.identificacao.nome), tecla]
	linha.add_child(texto)
	var reiniciar_b := Button.new()
	reiniciar_b.text = "Energia e bonecos"
	reiniciar_b.focus_mode = Control.FOCUS_NONE
	reiniciar_b.pressed.connect(reiniciar)
	linha.add_child(reiniciar_b)
	var voltar_b := Button.new()
	voltar_b.name = "VoltarAoEditor"
	voltar_b.text = "◀ Voltar ao editor"
	voltar_b.focus_mode = Control.FOCUS_NONE
	voltar_b.pressed.connect(voltar)
	linha.add_child(voltar_b)


## O catálogo publicado do projeto, copiado para a pasta de teste.
static func _copiar_catalogo() -> String:
	var destino := ProjectSettings.globalize_path(SKILLS)
	DirAccess.make_dir_recursive_absolute(destino)
	for velho in DirAccess.get_files_at(destino):
		DirAccess.remove_absolute(destino.path_join(velho))
	for nome in DirAccess.get_files_at(SkillsPublicadas.PASTA):
		if not nome.ends_with(".json"):
			continue
		var texto := FileAccess.get_file_as_string(SkillsPublicadas.PASTA.path_join(nome))
		var f := FileAccess.open(destino.path_join(nome), FileAccess.WRITE)
		if f == null:
			return "Não deu para preparar o teste: " + error_string(FileAccess.get_open_error())
		f.store_string(texto)
		f.close()
	return ""


## A plataforma de teste: chão 60 × 60 m (bordas para o vazio) e uma parede a 26 m.
static func _plataforma() -> Dictionary:
	return {"formato": "skills-one-piece/mapa", "versao": 1, "nome": "Plataforma de teste de skills",
		"spawn": {"posicao": [0, 3, 0]},
		"pecas": [
			{"id": "plataforma", "tipo": "caixa", "posicao": [0, -1, -10], "rotacao_graus": [0, 0, 0],
				"tamanho": [60, 2, 60], "cor": "#56677a", "material": "grade", "grade_celula": 2, "colisao": true},
			{"id": "parede", "tipo": "caixa", "posicao": [0, 2, -26], "rotacao_graus": [0, 0, 0],
				"tamanho": [14, 4, 1], "cor": "#8a6f52", "material": "grade", "grade_celula": 1, "colisao": true},
		]}
