class_name TreinoDeSoco
extends Node
# ============================================================================
#  MINIGAME DE TREINO DE SOCOS (20/11/2026) — o instrutor (`npc_treinador`) inicia; a câmera vai para o LADO do jogador e do boneco; aparecem 6 teclas
#  (Z/X/C) uma por vez, cada uma com 1,2 s: acertou = soco no boneco (partículas, tremida de tela, boneco balança), errou/estourou o tempo = sem soco.
#  No fim paga o XP por `RegrasDoTreino` (a missão fecha na primeira vez).
#
#  PADRÃO: máquina de estados por enum (ENTRANDO → ESPERANDO → GOLPE → … → SAINDO), um nó só. Alternativa descartada: um nó por estado (`state-machine` em
#  classes) — são 5 estados e 1 consumidor, as classes só espalhariam o fluxo. GATILHO: se um segundo minigame precisar da mesma câmera/pose, extrair `CameraDeCena`/`PoseDeClipe`.
#
#  Corpo: o jogador fica CONGELADO (`is_frozen`: não anda nem golpeia; a Luta e as técnicas não disparam) e a pose do soco vem DAQUI (o `poses.json` da Luta), porque
#  no nível 1 ele nem tem combate liberado. As teclas são lidas em `_input` e consumidas, para o Z/X/C não chegar ao resto do jogo.
#  Câmera: uma `Camera3D` própria, ao lado do eixo jogador→boneco; o rig do jogador não é tocado e volta a ser a câmera ativa no fim.
# ============================================================================
signal aviso(texto: String)
signal terminou(resultado: Dictionary)

enum Fase { PARADO, ENTRANDO, ESPERANDO, GOLPE, FIM, SAINDO }

const Visual := preload("res://src/combat/frutas_mine_piece/luta_visual.gd")
const PASTA_SOM := "res://assets/mine_piece/combate/"
const POSES := "res://assets/mine_piece/combate/poses.json"
const DISTANCIA_DO_BONECO := 1.7        # onde o jogador fica em relação ao boneco
const ALCANCE_PARA_COMECAR := 25.0
const AFASTAMENTO_DA_CAMERA := 4.6
const TEMPO_DE_ENTRADA := 0.7
const TEMPO_DO_GOLPE := 0.5             # o clipe do soco
const INSTANTE_DO_CONTATO := 0.12
const TEMPO_DO_FIM := 2.0

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable

var fase := Fase.PARADO
var acertos := 0
var indice := 0                          # prompt atual (0-based)
var tecla_atual := ""
var _tempo_restante := 0.0
var _t_fase := 0.0
var _jogador: Player = null
var _boneco: Node3D = null
var _eixo := Vector3.FORWARD             # jogador → boneco, horizontal
var _yaw := 0.0
var _camera: Camera3D = null
var _camera_anterior: Camera3D = null
var _de_onde: Transform3D
var _ate_onde: Transform3D
var _tremor := 0.0
var _tecla_do_golpe := ""
var _braco_direito := true
var _golpe_t := 0.0
var _contato_feito := false
var _poses := {}
var _resultado := {}
var _boneco_base := Transform3D.IDENTITY
var _reacao: Tween = null

var _ui: CanvasLayer
var _rotulo_tecla: Label
var _rotulo_contagem: Label
var _barra: ProgressBar
var _rotulo_feedback: Label
var _caixa: PanelContainer
var _fill: StyleBoxFlat
var _selo_acertos: Label
var _selo_erros: Label
var erros := 0
var _pago := false                       # a sessão já pagou o XP (um sinal repetido não paga de novo)


func _ready() -> void:
	add_to_group("treino_de_soco")
	set_process(false)
	set_process_input(false)


func ativo() -> bool:
	return fase != Fase.PARADO


## "" = dá para começar; senão o motivo (para a janela do instrutor).
func motivo_para_nao_iniciar() -> String:
	if fase != Fase.PARADO:
		return "O treino já está em andamento."
	if progressao != null:
		var recusa := RegrasDoTreino.motivo_para_nao_treinar(progressao)
		if not recusa.is_empty():
			return recusa
	var j: Player = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or j.health <= 0.0:
		return "Sem jogador."
	if _achar_boneco(j) == null:
		return "Não há boneco de treino por perto."
	return ""


## Começa o treino. Devolve "" se começou, ou o motivo.
func pedir_inicio() -> String:
	var motivo := motivo_para_nao_iniciar()
	if not motivo.is_empty():
		return motivo
	_jogador = jogador_de.call()
	_boneco = _achar_boneco(_jogador)
	_boneco_base = _boneco.transform
	if _poses.is_empty():
		_poses = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	acertos = 0
	erros = 0
	_pago = false
	indice = 0
	_resultado = {}
	_preparar_corpo()
	_preparar_camera()
	_montar_ui()
	_ir_para(Fase.ENTRANDO)
	set_process(true)
	set_process_input(true)
	return ""


## Cancela sem pagar nada (Esc, morte, mudança de cena).
func cancelar() -> void:
	if fase == Fase.PARADO:
		return
	_resultado = {"cancelado": true, "acertos": acertos, "xp": 0}
	_limpar()
	terminou.emit(_resultado)


# ------------------------------------------------------------------ preparação
static func _achar_boneco(a_partir_de: Node3D) -> Node3D:
	var arvore := a_partir_de.get_tree()
	if arvore == null:
		return null
	var melhor: Node3D = null
	var dist := ALCANCE_PARA_COMECAR
	for no in arvore.current_scene.find_children("boneco_de_treino*", "Node3D", true, false):
		var d := a_partir_de.global_position.distance_to((no as Node3D).global_position)
		if d <= dist:
			dist = d
			melhor = no
	return melhor


func _preparar_corpo() -> void:
	var para := _boneco.global_position - _jogador.global_position
	para.y = 0.0
	_eixo = para.normalized() if para.length_squared() > 0.0001 else -_jogador.global_basis.z
	_yaw = atan2(-_eixo.x, -_eixo.z)
	var pos := _boneco.global_position - _eixo * DISTANCIA_DO_BONECO
	pos.y = _jogador.global_position.y
	_jogador.global_position = pos
	_jogador.velocity = Vector3.ZERO
	_jogador.set_meta("is_frozen", true)
	_jogador._yaw = _yaw
	_jogador._update_pivot()
	_virar_corpo()


func _virar_corpo() -> void:
	if _jogador != null and is_instance_valid(_jogador) and _jogador.get("_char_model") != null:
		(_jogador.get("_char_model") as Node3D).rotation.y = _yaw


func _preparar_camera() -> void:
	_camera_anterior = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CameraDeTreino"
	_camera.fov = 55.0
	add_child(_camera)
	var meio := (_jogador.global_position + _boneco.global_position) * 0.5 + Vector3.UP * 1.0
	var lado := _eixo.cross(Vector3.UP).normalized()
	var pos := meio + lado * AFASTAMENTO_DA_CAMERA + Vector3.UP * 0.35
	_ate_onde = Transform3D(Basis.IDENTITY, pos).looking_at(meio, Vector3.UP)
	_de_onde = _camera_anterior.global_transform if _camera_anterior != null else _ate_onde
	_camera.global_transform = _de_onde
	_camera.make_current()


func _montar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(raiz)
	_rotulo_contagem = Label.new()
	_rotulo_contagem.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rotulo_contagem.position = Vector2(-220, 96)               # abaixo do HUD de vida/raid, que ocupa o topo
	_rotulo_contagem.custom_minimum_size = Vector2(440, 36)
	_rotulo_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_contagem.add_theme_font_size_override("font_size", 26)
	raiz.add_child(_rotulo_contagem)
	_caixa = PanelContainer.new()                                  # a tecla em formato de keycap (ref. `03_interface_minigame.png`)
	_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caixa.position = Vector2(-72, 140)
	_caixa.custom_minimum_size = Vector2(144, 124)
	_caixa.add_theme_stylebox_override("panel", _estilo(Color(0.96, 0.94, 0.89), Color(0.13, 0.13, 0.17), 14, 4, 12))
	raiz.add_child(_caixa)
	_rotulo_tecla = Label.new()
	_rotulo_tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo_tecla.add_theme_font_size_override("font_size", 84)
	_rotulo_tecla.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))
	_caixa.add_child(_rotulo_tecla)
	_barra = ProgressBar.new()                                     # a barra de tempo, amarela, vira vermelha no fim
	_barra.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_barra.position = Vector2(-190, 282)
	_barra.custom_minimum_size = Vector2(380, 22)
	_barra.size = Vector2(380, 22)
	_barra.show_percentage = false
	_barra.min_value = 0.0
	_barra.max_value = RegrasDoTreino.TEMPO_DO_PROMPT
	_barra.add_theme_stylebox_override("background", _estilo(Color(0.12, 0.13, 0.17), Color(0.9, 0.9, 0.92), 11, 3, 0))
	_fill = _estilo(Color(1.0, 0.82, 0.12), Color(1.0, 0.82, 0.12), 8, 0, 0)
	_barra.add_theme_stylebox_override("fill", _fill)
	raiz.add_child(_barra)
	_selo_acertos = _selo(raiz, Vector2(-250, 112), Color(0.16, 0.65, 0.22), "BOA 0")      # canto direito, abaixo das barras de fome/sede
	_selo_erros = _selo(raiz, Vector2(-125, 112), Color(0.78, 0.17, 0.17), "ERRO 0")
	_rotulo_feedback = Label.new()
	_rotulo_feedback.set_anchors_preset(Control.PRESET_CENTER)
	_rotulo_feedback.position = Vector2(-160, -40)
	_rotulo_feedback.custom_minimum_size = Vector2(320, 60)
	_rotulo_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_feedback.add_theme_font_size_override("font_size", 44)
	raiz.add_child(_rotulo_feedback)
	_atualizar_ui()


func _estilo(fundo: Color, borda: Color, raio: int, largura_borda: int, sombra_baixo: int) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.border_color = borda
	e.set_corner_radius_all(raio)
	e.set_border_width_all(largura_borda)
	e.border_width_bottom = largura_borda + sombra_baixo          # a "espessura" do keycap
	return e


func _selo(raiz: Control, pos: Vector2, cor: Color, texto: String) -> Label:
	var caixa := PanelContainer.new()
	caixa.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	caixa.position = pos
	caixa.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	caixa.custom_minimum_size = Vector2(115, 40)
	caixa.add_theme_stylebox_override("panel", _estilo(cor, Color(0.95, 0.95, 0.95), 8, 3, 0))
	raiz.add_child(caixa)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	caixa.add_child(l)
	return l


# ---------------------------------------------------------------------- fluxo
func _ir_para(nova: Fase) -> void:
	fase = nova
	_t_fase = 0.0
	match nova:
		Fase.ESPERANDO:
			tecla_atual = _sortear_tecla()
			_tempo_restante = RegrasDoTreino.TEMPO_DO_PROMPT
			_rotulo_feedback.text = ""
		Fase.GOLPE:
			_golpe_t = 0.0
			_contato_feito = false
			_braco_direito = not _braco_direito
		Fase.FIM:
			_encerrar_sessao()
	_atualizar_ui()


func _sortear_tecla() -> String:
	var t := RegrasDoTreino.TECLAS[randi() % RegrasDoTreino.TECLAS.size()]
	if t == tecla_atual and randf() < 0.6:        # evita repetir demais a mesma tecla
		t = RegrasDoTreino.TECLAS[(RegrasDoTreino.TECLAS.find(t) + 1) % RegrasDoTreino.TECLAS.size()]
	return t


func _process(delta: float) -> void:
	if not is_instance_valid(_jogador) or _jogador.health <= 0.0:
		cancelar()
		return
	_jogador.velocity = Vector3.ZERO
	_virar_corpo()
	_t_fase += delta
	_atualizar_camera(delta)
	match fase:
		Fase.ENTRANDO:
			if _t_fase >= TEMPO_DE_ENTRADA:
				_ir_para(Fase.ESPERANDO)
		Fase.ESPERANDO:
			_tempo_restante -= delta
			_barra.value = maxf(_tempo_restante, 0.0)
			_fill.bg_color = Color(1.0, 0.82, 0.12) if _tempo_restante > RegrasDoTreino.TEMPO_DO_PROMPT * 0.3 else Color(0.95, 0.25, 0.2)
			if _tempo_restante <= 0.0:
				_errou("TEMPO!")
		Fase.GOLPE:
			_andar_golpe(delta)
		Fase.FIM:
			if _t_fase >= TEMPO_DO_FIM:
				_ir_para(Fase.SAINDO)
		Fase.SAINDO:
			if _t_fase >= 0.5:
				_limpar()
				terminou.emit(_resultado)


func _input(evento: InputEvent) -> void:
	if fase == Fase.PARADO or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	var tecla := (evento as InputEventKey).physical_keycode
	if tecla == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelar()
		return
	var letra := OS.get_keycode_string(tecla)
	if letra in RegrasDoTreino.TECLAS:
		get_viewport().set_input_as_handled()          # o Z/X/C é do treino enquanto ele durar
		if fase == Fase.ESPERANDO:
			if letra == tecla_atual:
				_acertou(letra)
			else:
				_errou("ERROU!")


func _acertou(letra: String) -> void:
	acertos += 1
	_tecla_do_golpe = letra
	_rotulo_feedback.text = "BOA!"
	_rotulo_feedback.modulate = Color(0.4, 1.0, 0.4)
	_ir_para(Fase.GOLPE)


func _errou(texto: String) -> void:
	erros += 1
	_rotulo_feedback.text = texto
	_rotulo_feedback.modulate = Color(1.0, 0.35, 0.3)
	_tremor = maxf(_tremor, 0.15)
	_proximo_prompt()


func _proximo_prompt() -> void:
	indice += 1
	if indice >= RegrasDoTreino.PROMPTS:
		_ir_para(Fase.FIM)
	else:
		_ir_para(Fase.ESPERANDO)


## O soco: o Z é um golpe, o X um golpe pesado, o C uma rajada de três. O contato (partículas, tremida, reação do boneco) acontece no instante em que o braço estica.
func _andar_golpe(delta: float) -> void:
	_golpe_t += delta
	_aplicar_pose("punch_right" if _braco_direito else "punch_left", _golpe_t)
	var golpes := 3 if _tecla_do_golpe == "C" else 1
	var intervalo := 0.12
	if not _contato_feito and _golpe_t >= INSTANTE_DO_CONTATO:
		_contato_feito = true
		_contato(_forca_do_golpe(), _tecla_do_golpe == "X")
	if golpes > 1:
		for k in range(1, golpes):
			if _golpe_t >= INSTANTE_DO_CONTATO + intervalo * k and _golpe_t - delta < INSTANTE_DO_CONTATO + intervalo * k:
				_braco_direito = not _braco_direito
				_aplicar_pose("punch_right" if _braco_direito else "punch_left", 0.0)
				_contato(0.28, false)
	if _golpe_t >= TEMPO_DO_GOLPE + (0.12 * (golpes - 1)):
		_tirar_pose()
		_proximo_prompt()


func _forca_do_golpe() -> float:
	match _tecla_do_golpe:
		"X":
			return 1.0
		"C":
			return 0.28
	return 0.5


func _contato(forca: float, pesado: bool) -> void:
	var onde := _boneco.global_position - _eixo * 0.35
	onde.y = _jogador.global_position.y + 0.35                   # na altura do punho (a origem do jogador é o centro do corpo)
	Visual.estourar(self, onde, _eixo, forca)
	_tremor = maxf(_tremor, 0.35 + 0.65 * forca)
	_reagir_boneco(forca)
	_lascas(onde, forca)
	_som(pesado)


## Lascas de madeira que saltam do boneco no contato (ref. `04_impacto_e_reacao_boneco.png`): cubos marrons em arco, que caem e somem em ~0,5 s.
func _lascas(onde: Vector3, forca: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.58, 0.34, 0.15)
	var cubo := BoxMesh.new()
	var lado_perp := _eixo.cross(Vector3.UP).normalized()
	for i in 3 + int(round(5.0 * forca)):
		var m := MeshInstance3D.new()
		m.name = "Lasca"
		m.mesh = cubo
		m.material_override = material
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = onde
		var tam := randf_range(0.05, 0.1)
		m.scale = Vector3(tam, tam, tam * randf_range(1.0, 2.0))
		var alvo := onde + _eixo * randf_range(0.2, 0.6) + lado_perp * randf_range(-0.6, 0.6) + Vector3.UP * randf_range(0.2, 0.7)
		var queda := alvo + Vector3.DOWN * randf_range(0.5, 0.9)
		var t := m.create_tween()
		t.tween_property(m, "global_position", alvo, 0.18).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "global_position", queda, 0.32).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(m, "scale", Vector3.ZERO, 0.32).set_delay(0.12)
		t.tween_callback(m.queue_free)


func _reagir_boneco(forca: float) -> void:
	if _reacao != null and _reacao.is_valid():
		_reacao.kill()
	_boneco.transform = _boneco_base
	var empurrao := _eixo * (0.08 + 0.18 * forca)
	var inclinacao := deg_to_rad(6.0 + 14.0 * forca)
	var eixo_de_giro := _eixo.cross(Vector3.UP).normalized()          # inclina para trás, para longe do soco
	var inclinado := _boneco_base
	inclinado.origin += empurrao
	inclinado.basis = Basis(eixo_de_giro, -inclinacao) * _boneco_base.basis
	_reacao = _boneco.create_tween()
	_reacao.tween_property(_boneco, "transform", inclinado, 0.07).set_ease(Tween.EASE_OUT)
	_reacao.tween_property(_boneco, "transform", _boneco_base, 0.55 + 0.3 * forca).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _som(pesado: bool) -> void:
	var som := AudioStreamPlayer3D.new()
	som.stream = load(PASTA_SOM + ("hit_strong.ogg" if pesado else "punch_hit1.ogg"))
	som.volume_db = -8.0
	add_child(som)
	som.global_position = _boneco.global_position
	som.finished.connect(som.queue_free)
	som.play()


# ---------------------------------------------------------------------- pose
## O clipe do soco da Luta tocado direto no corpo (mesmo caminho do `controlador.gd`: metas lidas pelo `ProceduralAnimator`).
func _aplicar_pose(nome: String, t: float) -> void:
	if not _poses.has(nome) or not is_instance_valid(_jogador):
		return
	var clipe: Dictionary = _poses[nome]
	var quadro := mini(int(t * float(clipe.fps)), (clipe.quadros as Array).size() - 1)
	var peso := smoothstep(0.0, 0.08, t)
	var rotacoes := {}
	var posicoes := {}
	for papel: String in clipe.quadros[quadro]:
		var a: Array = clipe.quadros[quadro][papel]
		rotacoes[papel] = Vector3(a[0], a[1], a[2]) * PI / 180.0 * peso
	for papel: String in clipe.posicoes[quadro]:
		var a: Array = clipe.posicoes[quadro][papel]
		posicoes[papel] = Vector3(a[0], a[1], a[2]) * peso
	_jogador.set_meta("pose_de_skill", rotacoes)
	_jogador.set_meta("posicoes_mine_piece", posicoes)


func _tirar_pose() -> void:
	if is_instance_valid(_jogador):
		_jogador.remove_meta("pose_de_skill")
		_jogador.remove_meta("posicoes_mine_piece")


# -------------------------------------------------------------------- câmera
func _atualizar_camera(delta: float) -> void:
	if _camera == null:
		return
	var k := clampf(_t_fase / TEMPO_DE_ENTRADA, 0.0, 1.0) if fase == Fase.ENTRANDO else 1.0
	k = smoothstep(0.0, 1.0, k)
	if fase == Fase.SAINDO:
		k = 1.0 - smoothstep(0.0, 1.0, clampf(_t_fase / 0.5, 0.0, 1.0))
	var base := _de_onde.interpolate_with(_ate_onde, k)
	_camera.global_transform = base
	if _tremor > 0.0:
		var t := _tremor * 0.08
		_camera.global_position += Vector3(randf_range(-t, t), randf_range(-t, t), randf_range(-t, t))
		_tremor = maxf(_tremor - delta * 3.2, 0.0)


# ------------------------------------------------------------------ fim / UI
func _encerrar_sessao() -> void:
	if _pago:
		return
	_pago = true
	var r := RegrasDoTreino.concluir(progressao, acertos)
	_resultado = r.duplicate()
	_resultado["acertos"] = acertos
	_rotulo_tecla.text = ""
	_barra.value = 0.0
	_resultado["erros"] = erros
	if int(r.xp) > 0:
		_rotulo_feedback.text = "BOM TRABALHO!" if bool(r.get("missao_entregue", false)) else "TREINO CONCLUÍDO"      # os números vão no aviso da HUD (sem duplicar)
		_rotulo_feedback.modulate = Color(1.0, 0.9, 0.3)
		var texto := "Treino concluído: %d de %d  ·  +%d XP" % [acertos, RegrasDoTreino.PROMPTS, int(r.xp)]
		if int(r.niveis) > 0:
			texto += "  ·  NÍVEL %d!" % progressao.nivel
		aviso.emit(texto)
		if bool(r.recusa_agora):
			aviso.emit("Instrutor: " + RegrasDoTreino.FALA_DE_RECUSA)
	else:
		_rotulo_feedback.text = "SEM ACERTOS"
		_rotulo_feedback.modulate = Color(1.0, 0.5, 0.4)
		aviso.emit("Treino sem acertos: nenhum XP.")
	_atualizar_ui()


func _atualizar_ui() -> void:
	if _rotulo_contagem == null:
		return
	_rotulo_contagem.text = "TREINO  %d / %d  ·  acertos %d" % [mini(indice + (1 if fase in [Fase.ESPERANDO, Fase.GOLPE] else 0), RegrasDoTreino.PROMPTS), RegrasDoTreino.PROMPTS, acertos]
	_rotulo_tecla.text = tecla_atual if fase == Fase.ESPERANDO else ""
	_caixa.visible = fase == Fase.ESPERANDO
	_barra.visible = fase == Fase.ESPERANDO
	_selo_acertos.text = "BOA %d" % acertos
	_selo_erros.text = "ERRO %d" % erros
	_rotulo_contagem.visible = fase != Fase.FIM and fase != Fase.SAINDO


func _limpar() -> void:
	_tirar_pose()
	if is_instance_valid(_jogador):
		_jogador.set_meta("is_frozen", false)
	if _reacao != null and _reacao.is_valid():
		_reacao.kill()
	if is_instance_valid(_boneco):
		_boneco.transform = _boneco_base
	if is_instance_valid(_camera_anterior):
		_camera_anterior.make_current()
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _ui != null:
		_ui.queue_free()
		_ui = null
	fase = Fase.PARADO
	set_process(false)
	set_process_input(false)
