class_name LutaDoBuggy
extends Node
# ============================================================================
#  A LUTA DO BUGGY NO RINGUE (22/11/2026) — minigame de teclas na MESMA estrutura do treino (`TreinoDeSoco`): máquina de estados por enum, um nó só, jogador congelado,
#  câmera própria ao lado dos dois, teclas lidas em `_input` e consumidas. As contas (11 vidas, 0,6 s, Z/X/C ataca, F defende, 350 moedas + 6500 XP) estão em
#  `RegrasDaLutaDoBuggy`; quem MONTA o palco (ringue, Buggy, jogador) e DESFAZ depois é o `DesafioDoBuggy`. Aqui: luvas vermelhas nos dois, ringue, golpes, UI.
#
#  Rodada: sai UMA tecla. Z/X/C = ataque do jogador (acertou: soco no Buggy, −1 de vida dele). F = o Buggy ataca e o jogador DEFENDE (acertou: bloqueia; errou ou
#  estourou o tempo: −1 de vida do jogador). 11 acertos = vitória; 11 defesas falhas = o Buggy vence.
#  GATILHO: o clipe de soco/câmera/UI repetem o `TreinoDeSoco`; um 3º minigame de teclas → extrair `CameraDeCena`, `PoseDeClipe` e `PainelDeTecla` dos dois.
# ============================================================================
signal aviso(texto: String)
signal terminou(resultado: Dictionary)

enum Fase { PARADO, ENTRANDO, ESPERANDO, GOLPE, FIM, SAINDO }

const Regras := preload("res://src/historia/buggy_cais/regras_da_luta_do_buggy.gd")
const Detalhes := preload("res://src/player/detalhes_historia.gd")
const Visual := preload("res://src/combat/frutas_mine_piece/luta_visual.gd")
const PASTA_SOM := "res://assets/mine_piece/combate/"
const POSES := "res://assets/mine_piece/combate/poses.json"
const LUVA := "luvas_boxe_vermelhas"
const LUVA_GLB := "res://assets/models/acessorios/luvas_boxe_vermelhas.glb"
const AFASTAMENTO_DA_CAMERA := 5.6
const DISTANCIA_ENTRE_LUTADORES := 1.7
const TEMPO_DE_ENTRADA := 1.0
const TEMPO_DO_FIM := 2.6
const FALAS := "res://data/dialogos/luta_do_buggy.json"          # as 18 falas do Codex (docs/LUTA_DO_BUGGY_FALAS.md): `entrada`, `acerta`, `acertado`, `defesa`, `derrota`, `vitoria`
const INTERVALO_DE_FALA := 1.8                                      # s: o Buggy não fala em cima de si mesmo
## Guarda de boxe: as DUAS mãos à frente do rosto, cotovelos dobrados e fechados, tronco levemente agachado (as rotações do rig: +x levanta o braço à frente).
const POSE_DE_GUARDA := {"UpperArm_R": Vector3(0.62, 0.0, -0.18), "ForeArm_R": Vector3(-1.95, 0.0, 0.0), "UpperArm_L": Vector3(0.62, 0.0, 0.18), "ForeArm_L": Vector3(1.95, 0.0, 0.0),
	"Torso": Vector3(0.1, 0.0, 0.0)}
const POSE_DE_DANO := {"Torso": Vector3(-0.35, 0.0, 0.0), "UpperArm_R": Vector3(0.4, 0.0, -0.4), "UpperArm_L": Vector3(0.4, 0.0, 0.4)}

var progressao: ProgressaoDoPersonagem
var regras: RegrasDaLutaDoBuggy
var fase := Fase.PARADO
var tecla_atual := ""
var tipo_atual := Regras.Tipo.ATAQUE
var ringue: RingueDoBuggy

var _jogador: Node3D            # (não tipado como `Player`: citar a classe puxa os autoloads e quebra o `--script` dos testes)
var _buggy: Node3D
var _anim: AnimacoesDoElenco
var _eixo := Vector3.RIGHT              # jogador → Buggy (horizontal)
var _yaw := 0.0
var _centro := Vector3.ZERO
var _camera: Camera3D
var _camera_anterior: Camera3D
var _de_onde: Transform3D
var _ate_onde: Transform3D
var _tempo_restante := 0.0
var _t_fase := 0.0
var _tremor := 0.0
var _golpe_t := 0.0
var _golpe_do_jogador := true
var _braco_direito := true
var _tecla_do_golpe := ""
var _golpe := "Z"                       # qual dos três golpes (Z/X/C) a rodada executa — do jogador ou do Buggy
var _contatos := 0
var _golpe_do_buggy := "Z"
var _bloqueou := false
var _poses := {}
var _resultado := {}
var _buggy_base := Transform3D.IDENTITY
var _reacao: Tween
var _luvas: Array[Node] = []
var _imune_antes := false
var _ui: CanvasLayer
var _pips_jogador: Array[ColorRect] = []
var _pips_buggy: Array[ColorRect] = []
var _caixa: PanelContainer
var _rotulo_tecla: Label
var _rotulo_dica: Label
var _barra: ProgressBar
var _fill: StyleBoxFlat
var _rotulo_feedback: Label
var _rng := RandomNumberGenerator.new()
var _pago := false
var _falas := {}
var _rotulo_fala: Label
var _selo_f: TextureRect
var _fala_ate := 0.0


func _ready() -> void:
	add_to_group("luta_do_buggy")
	set_process(false)
	set_process_input(false)


func ativa() -> bool:
	return fase != Fase.PARADO


## Uma fala do Buggy para `situacao` (sorteada das falas do Codex; "" se o arquivo não existir). Estática: o `DesafioDoBuggy` a usa nas falas de fim.
static func fala_do_buggy(situacao: String, semente := -1) -> String:
	if not FileAccess.file_exists(FALAS):
		return ""
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(FALAS))
	if not (dados is Dictionary) or not (dados as Dictionary).has(situacao):
		return ""
	var lista: Array = (dados as Dictionary)[situacao]
	if lista.is_empty():
		return ""
	return str(lista[(randi() if semente < 0 else semente) % lista.size()])


## Mostra a fala do Buggy num balão no topo (some sozinho em ~2,4 s). Respeita o intervalo; `forcar` ignora (a entrada e o fim).
func _falar(situacao: String, forcar := false) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if _rotulo_fala == null or (not forcar and agora < _fala_ate):
		return
	var texto := fala_do_buggy(situacao)
	if texto.is_empty():
		return
	_fala_ate = agora + INTERVALO_DE_FALA
	_rotulo_fala.text = "Buggy: " + texto
	_rotulo_fala.modulate.a = 1.0
	var t := _rotulo_fala.create_tween()
	t.tween_interval(1.6)
	t.tween_property(_rotulo_fala, "modulate:a", 0.0, 0.8)


## Começa a luta. `centro_chao` = o ponto no chão onde o ringue é montado. Devolve "" se começou, ou o motivo.
func iniciar(jogador: Node3D, buggy: Node3D, animador: AnimacoesDoElenco, centro_chao: Vector3, semente := 0) -> String:
	if fase != Fase.PARADO:
		return "A luta já está em andamento."
	if jogador == null or jogador.health <= 0.0 or buggy == null:
		return "Sem lutadores."
	_jogador = jogador
	_buggy = buggy
	_anim = animador
	_rng.seed = semente if semente != 0 else Time.get_ticks_usec()
	regras = Regras.new()
	_pago = false
	_resultado = {}
	if _poses.is_empty():
		_poses = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	_montar_palco(centro_chao)
	_vestir_luvas()
	_preparar_camera()
	_montar_ui()
	_imune_antes = bool(_jogador.get_meta("damage_immune", false))
	_jogador.set_meta("damage_immune", true)             # nada de fora (criatura, queda) derruba o jogador no meio da luta
	_ir_para(Fase.ENTRANDO)
	set_process(true)
	set_process_input(true)
	return ""


## Cancela sem pagar nada (Esc, morte, mudança de cena): conta como derrota sem punição.
func cancelar() -> void:
	if fase == Fase.PARADO:
		return
	_resultado = {"cancelado": true, "venceu": false, "acertos": regras.acertos}
	_limpar()
	terminou.emit(_resultado)


# ------------------------------------------------------------------ palco
func _montar_palco(centro_chao: Vector3) -> void:
	ringue = RingueDoBuggy.new()
	add_child(ringue)
	ringue.montar(centro_chao)
	_centro = ringue.topo()
	_eixo = Vector3.RIGHT                                # o jogador (vila) a oeste, o Buggy a leste
	_yaw = atan2(-_eixo.x, -_eixo.z)
	var altura := 1.0                                    # a origem do jogador é o centro da cápsula
	_jogador.global_position = _centro - _eixo * (DISTANCIA_ENTRE_LUTADORES * 0.5) + Vector3.UP * (altura + 0.05)
	_jogador.velocity = Vector3.ZERO
	_jogador.set_meta("is_frozen", true)
	_jogador._yaw = _yaw
	_jogador._update_pivot()
	_virar_jogador()
	_buggy.global_position = _centro + _eixo * (DISTANCIA_ENTRE_LUTADORES * 0.5)
	_buggy.rotation.y = PI / 2.0                         # a frente (−Z) aponta para −X: de frente para o jogador (o mesmo `virar_para_terra`)
	_buggy_base = _buggy.global_transform


func _virar_jogador() -> void:
	if is_instance_valid(_jogador) and _jogador.get("_char_model") != null:
		(_jogador.get("_char_model") as Node3D).rotation.y = _yaw


## Luvas vermelhas no punho dos dois. Jogador: o acessório "luvas_boxe_vermelhas" que já existe (encaixe `Hand_*`), se ele ainda não as veste. Buggy: o mesmo GLB nos
## nós de mão do modelo dele (`itemMainHand`/`itemOffHand`).
func _vestir_luvas() -> void:
	var modelo := _jogador.get("_char_model") as Node3D
	if modelo != null and modelo.find_child("Acessorio_" + LUVA, true, false) == null:
		var antes := modelo.find_children("Acessorio_" + LUVA, "Node3D", true, false)
		Detalhes._acessorio(modelo, str(_jogador.get_meta("corpo_historia", "masculino")), LUVA)
		for n in modelo.find_children("Acessorio_" + LUVA, "Node3D", true, false):
			if not antes.has(n):
				_luvas.append(n)
	if not ResourceLoader.exists(LUVA_GLB):
		return
	for nome in ["itemMainHand", "itemOffHand"]:
		var mao := _buggy.find_child(nome, true, false) as Node3D
		if mao == null:
			continue
		var peca := (load(LUVA_GLB) as PackedScene).instantiate() as Node3D
		peca.name = "Luva_" + nome
		peca.position = Vector3(0.0, 0.3, 0.0)
		peca.scale = Vector3.ONE * 1.25
		Acessorios._fixar_ao_rig(peca)
		Acessorios._converter_materiais(peca, false)
		mao.add_child(peca)
		_luvas.append(peca)


func _preparar_camera() -> void:
	_camera_anterior = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CameraDaLuta"
	_camera.fov = 55.0
	add_child(_camera)
	var meio := _centro + Vector3.UP * 1.45
	var lado := _eixo.cross(Vector3.UP).normalized()
	_ate_onde = Transform3D(Basis.IDENTITY, meio + lado * AFASTAMENTO_DA_CAMERA + Vector3.UP * 1.0)       # acima da corda de cima: as cordas não tapam a luta.looking_at(meio, Vector3.UP)
	_de_onde = _camera_anterior.global_transform if _camera_anterior != null else _ate_onde
	_camera.global_transform = _de_onde
	_camera.make_current()


# ------------------------------------------------------------------ UI
func _montar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(raiz)
	_pips_jogador = _barra_de_vida(raiz, "VOCÊ", Vector2(-420, 150), Color(0.2, 0.75, 0.3), false)
	_pips_buggy = _barra_de_vida(raiz, "BUGGY", Vector2(40, 150), Color(0.9, 0.2, 0.2), true)
	_caixa = PanelContainer.new()
	_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caixa.position = Vector2(-72, 236)
	_caixa.custom_minimum_size = Vector2(144, 124)
	raiz.add_child(_caixa)
	_rotulo_tecla = Label.new()
	_rotulo_tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo_tecla.add_theme_font_size_override("font_size", 84)
	_rotulo_tecla.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))
	_caixa.add_child(_rotulo_tecla)
	_selo_f = TextureRect.new()                                      # o escudo do Codex ao lado da tecla F
	_selo_f.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_selo_f.position = Vector2(-150, 244)
	_selo_f.custom_minimum_size = Vector2(64, 64)
	_selo_f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selo_f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_selo_f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/textures/luta_do_buggy/luta_selo_f.png"):
		_selo_f.texture = load("res://assets/textures/luta_do_buggy/luta_selo_f.png") as Texture2D
	raiz.add_child(_selo_f)
	_rotulo_dica = Label.new()
	_rotulo_dica.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_rotulo_dica.position = Vector2(-160, 202)
	_rotulo_dica.custom_minimum_size = Vector2(320, 30)
	_rotulo_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_dica.add_theme_font_size_override("font_size", 24)
	raiz.add_child(_rotulo_dica)
	_barra = ProgressBar.new()
	_barra.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_barra.position = Vector2(-190, 378)
	_barra.custom_minimum_size = Vector2(380, 22)
	_barra.size = Vector2(380, 22)
	_barra.show_percentage = false
	_barra.min_value = 0.0
	_barra.max_value = Regras.TEMPO_DO_PROMPT
	_barra.add_theme_stylebox_override("background", _estilo(Color(0.12, 0.13, 0.17), Color(0.9, 0.9, 0.92), 11, 3, 0))
	_fill = _estilo(Color(1.0, 0.82, 0.12), Color(1.0, 0.82, 0.12), 8, 0, 0)
	_barra.add_theme_stylebox_override("fill", _fill)
	raiz.add_child(_barra)
	_rotulo_fala = Label.new()
	_rotulo_fala.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_rotulo_fala.position = Vector2(-380, -250)
	_rotulo_fala.custom_minimum_size = Vector2(760, 40)
	_rotulo_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_fala.add_theme_font_size_override("font_size", 24)
	_rotulo_fala.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_rotulo_fala.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_rotulo_fala.add_theme_constant_override("outline_size", 8)
	_rotulo_fala.modulate.a = 0.0
	raiz.add_child(_rotulo_fala)
	_rotulo_feedback = Label.new()
	_rotulo_feedback.set_anchors_preset(Control.PRESET_CENTER)
	_rotulo_feedback.position = Vector2(-220, -40)
	_rotulo_feedback.custom_minimum_size = Vector2(440, 60)
	_rotulo_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_feedback.add_theme_font_size_override("font_size", 46)
	raiz.add_child(_rotulo_feedback)
	_atualizar_ui()


## Nome + 11 quadradinhos de vida. `a_direita`: o Buggy, que esvazia da esquerda para a direita (o lado de dentro).
func _barra_de_vida(raiz: Control, nome: String, pos: Vector2, cor: Color, a_direita: bool) -> Array[ColorRect]:
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caixa.position = pos
	raiz.add_child(caixa)
	var titulo := Label.new()
	titulo.text = nome
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", cor)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if a_direita else HORIZONTAL_ALIGNMENT_LEFT
	caixa.add_child(titulo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 3)
	caixa.add_child(linha)
	var pips: Array[ColorRect] = []
	for i in Regras.VIDA:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(26, 20)
		p.color = cor
		linha.add_child(p)
		pips.append(p)
	return pips


func _estilo(fundo: Color, borda: Color, raio: int, largura_borda: int, sombra_baixo: int) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.border_color = borda
	e.set_corner_radius_all(raio)
	e.set_border_width_all(largura_borda)
	e.border_width_bottom = largura_borda + sombra_baixo
	return e


func _atualizar_ui() -> void:
	if _rotulo_tecla == null:
		return
	for i in Regras.VIDA:
		_pips_jogador[i].modulate.a = 1.0 if i < regras.vida_jogador else 0.15
		_pips_buggy[i].modulate.a = 1.0 if i < regras.vida_buggy else 0.15
	var esperando := fase == Fase.ESPERANDO
	var defesa := tipo_atual == Regras.Tipo.DEFESA
	_caixa.visible = esperando
	_barra.visible = esperando
	_rotulo_dica.visible = esperando
	_rotulo_tecla.text = tecla_atual if esperando else ""
	_selo_f.visible = esperando and defesa
	_rotulo_dica.text = "DEFENDA!" if defesa else "ATAQUE!"
	_rotulo_dica.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0) if defesa else Color(1.0, 0.82, 0.2))
	_caixa.add_theme_stylebox_override("panel", _estilo(Color(0.78, 0.9, 1.0) if defesa else Color(0.96, 0.94, 0.89), Color(0.13, 0.13, 0.17), 14, 4, 12))


# ------------------------------------------------------------------ fluxo
func _ir_para(nova: Fase) -> void:
	fase = nova
	_t_fase = 0.0
	match nova:
		Fase.ENTRANDO:
			_falar("entrada", true)
			_rotulo_feedback.text = "LUTA!"
			_rotulo_feedback.modulate = Color(1.0, 0.85, 0.3)
		Fase.ESPERANDO:
			var r := regras.proxima(_rng.randf(), _rng.randf())
			tipo_atual = r["tipo"]
			tecla_atual = r["tecla"]
			_tempo_restante = Regras.TEMPO_DO_PROMPT
			_rotulo_feedback.text = ""
			if tipo_atual == Regras.Tipo.DEFESA:
				_golpe_do_buggy = Regras.TECLAS_DE_ATAQUE[_rng.randi() % Regras.TECLAS_DE_ATAQUE.size()]
				_telegrafar_buggy()                  # o Buggy arma o golpe (Z/X/C) durante a janela: é o aviso da defesa
		Fase.GOLPE:
			_golpe_t = 0.0
			_contatos = 0
			_braco_direito = not _braco_direito
			_golpe = _tecla_do_golpe if _golpe_do_jogador and _tecla_do_golpe in Regras.GOLPES else _golpe_do_buggy
			if not _golpe_do_jogador and _golpe_t == 0.0 and _golpe == "X":
				_tremor = maxf(_tremor, 0.2)
		Fase.FIM:
			_encerrar()
	_atualizar_ui()


func _process(delta: float) -> void:
	if not is_instance_valid(_jogador) or not is_instance_valid(_buggy) or _jogador.health <= 0.0:
		cancelar()
		return
	_jogador.velocity = Vector3.ZERO
	_virar_jogador()
	_t_fase += delta
	_atualizar_camera(delta)
	match fase:
		Fase.ENTRANDO:
			if _t_fase >= TEMPO_DE_ENTRADA:
				_ir_para(Fase.ESPERANDO)
		Fase.ESPERANDO:
			_tempo_restante -= delta
			_barra.value = maxf(_tempo_restante, 0.0)
			_fill.bg_color = Color(1.0, 0.82, 0.12) if _tempo_restante > Regras.TEMPO_DO_PROMPT * 0.3 else Color(0.95, 0.25, 0.2)
			if _tempo_restante <= 0.0:
				_resolver(false, "TEMPO!")
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
	if letra in Regras.TECLAS_DE_ATAQUE or letra == Regras.TECLA_DE_DEFESA:
		get_viewport().set_input_as_handled()          # Z/X/C/F são da luta enquanto ela durar
		if fase == Fase.ESPERANDO:
			_resolver(letra == tecla_atual, "BOA!" if letra == tecla_atual else "ERROU!", letra)


## Aperta uma tecla (também é o ponto de entrada dos testes).
func apertar(letra: String) -> void:
	if fase == Fase.ESPERANDO:
		_resolver(letra == tecla_atual, "BOA!" if letra == tecla_atual else "ERROU!", letra)


func _resolver(acertou: bool, texto: String, letra := "") -> void:
	var tipo := tipo_atual
	var efeito := regras.resolver(tipo, acertou)
	_golpe_do_jogador = tipo == Regras.Tipo.ATAQUE
	_bloqueou = bool(efeito["bloqueou"])
	_tecla_do_golpe = letra
	if tipo == Regras.Tipo.ATAQUE:
		_rotulo_feedback.text = texto
		_rotulo_feedback.modulate = Color(0.4, 1.0, 0.4) if acertou else Color(1.0, 0.35, 0.3)
		if acertou:
			_ir_para(Fase.GOLPE)
			return
	else:
		_rotulo_feedback.text = "DEFENDEU!" if acertou else ("TEMPO!" if texto == "TEMPO!" else "LEVOU!")
		_rotulo_feedback.modulate = Color(0.45, 0.75, 1.0) if acertou else Color(1.0, 0.35, 0.3)
		_ir_para(Fase.GOLPE)                         # o golpe do Buggy acontece de qualquer jeito: defendido ou não
		return
	_tremor = maxf(_tremor, 0.15)
	_anim_do_buggy("guard")                           # errou o ataque: o Buggy se defende
	_proxima_rodada()


func _proxima_rodada() -> void:
	_atualizar_ui()
	if regras.terminou():
		_ir_para(Fase.FIM)
	else:
		_ir_para(Fase.ESPERANDO)


## O Buggy arma o golpe sorteado durante a janela da defesa: a animação do modelo dele em câmera lenta (para o impacto cair quando o tempo acaba).
func _telegrafar_buggy() -> void:
	if _anim == null:
		return
	var lenta := 0.5
	match _golpe_do_buggy:
		"X":
			_anim.gesto("punch_overhead", false, lenta)          # carregado: o soco por cima
		"C":
			_anim.gesto("punch_right", false, lenta)             # múltiplo: começa o primeiro de três
		_:
			_anim.gesto("punch_right" if _braco_direito else "punch_left", false, lenta)


## Um golpe (Z/X/C) do jogador OU do Buggy: arma (X), acerta uma ou três vezes e acaba. O contato muda conforme quem bate e se foi bloqueado.
func _andar_golpe(delta: float) -> void:
	_golpe_t += delta
	var g: Dictionary = Regras.GOLPES[_golpe]
	var carga := float(g["carga"])
	var total := int(g["golpes"])
	var primeiro := carga + Regras.INSTANTE_DO_CONTATO
	if _golpe_do_jogador:
		var indice := clampi(int(maxf(_golpe_t - carga, 0.0) / Regras.INTERVALO_ENTRE_GOLPES), 0, total - 1) if total > 1 else 0
		var direito := (indice % 2 == 0) == _braco_direito
		if _golpe_t < carga:
			_aplicar_pose("punch_right" if _braco_direito else "punch_left", 0.0)            # carregando: o braço armado, parado
		else:
			_aplicar_pose("punch_right" if direito else "punch_left", _golpe_t - carga - indice * Regras.INTERVALO_ENTRE_GOLPES)
	elif _bloqueou:
		_jogador.set_meta("pose_externa", POSE_DE_GUARDA)
	while _contatos < total and _golpe_t >= primeiro + _contatos * Regras.INTERVALO_ENTRE_GOLPES:
		_contato_do_golpe(g, _contatos)
		_contatos += 1
	if _golpe_t >= float(g["duracao"]):
		if _golpe_do_jogador:
			_tirar_pose()
		elif is_instance_valid(_jogador):
			_jogador.remove_meta("pose_externa")
		_proxima_rodada()


func _contato_do_golpe(g: Dictionary, indice: int) -> void:
	var forca := float(g["forca"])
	if _golpe_do_jogador:
		_contato_no_buggy(forca, _golpe == "X")
		return
	if _anim != null and indice > 0:                                # o 2º e o 3º soco do múltiplo do Buggy
		_anim.gesto("punch_left" if indice % 2 == 1 else "punch_right")
	if _bloqueou:
		_contato_bloqueado(forca)
	else:
		_contato_no_jogador(forca)


# ------------------------------------------------------------------ contatos
func _contato_no_buggy(forca: float, pesado: bool) -> void:
	var onde := _buggy.global_position - _eixo * 0.35 + Vector3.UP * 1.25
	Visual.estourar(self, onde, _eixo, forca)
	_tremor = maxf(_tremor, 0.35 + 0.65 * forca)
	_reagir(_buggy, _eixo, forca, 0.6)
	_falar("acertado")
	_som(pesado, _buggy.global_position)
	_atualizar_ui()


func _contato_no_jogador(forca := 0.6) -> void:
	var onde := _jogador.global_position + _eixo * 0.35 + Vector3.UP * 0.3
	Visual.estourar(self, onde, -_eixo, 0.4 + 0.5 * forca)
	_tremor = maxf(_tremor, 0.3 + 0.5 * forca)
	_jogador.set_meta("pose_externa", POSE_DE_DANO)
	_falar("acerta")
	get_tree().create_timer(0.25, true).timeout.connect(func() -> void:
		if is_instance_valid(_jogador) and _jogador.get_meta("pose_externa", {}) == POSE_DE_DANO:
			_jogador.remove_meta("pose_externa"))
	_som(false, _jogador.global_position)
	_atualizar_ui()


func _contato_bloqueado(forca := 0.3) -> void:
	var onde := (_jogador.global_position + _buggy.global_position) * 0.5 + Vector3.UP * 0.9
	Visual.estourar(self, onde, _eixo, 0.2 + 0.3 * forca)
	_tremor = maxf(_tremor, 0.15 + 0.2 * forca)
	_reagir(_buggy, _eixo, 0.15 + 0.2 * forca, 0.4)                     # o Buggy é rebatido, para longe do jogador
	_falar("defesa")
	_som(true, onde)


func _reagir(no: Node3D, rumo: Vector3, forca: float, volta: float) -> void:
	if _reacao != null and _reacao.is_valid():
		_reacao.kill()
	no.global_transform = _buggy_base if no == _buggy else no.global_transform
	var base := no.global_transform
	var eixo_de_giro := rumo.cross(Vector3.UP).normalized()
	var inclinado := base
	inclinado.origin += rumo * (0.08 + 0.2 * forca)
	inclinado.basis = Basis(eixo_de_giro, -deg_to_rad(6.0 + 14.0 * forca)) * base.basis
	_reacao = no.create_tween()
	_reacao.tween_property(no, "global_transform", inclinado, 0.07).set_ease(Tween.EASE_OUT)
	_reacao.tween_property(no, "global_transform", base, volta).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _som(pesado: bool, onde: Vector3) -> void:
	var caminho := PASTA_SOM + ("hit_strong.ogg" if pesado else "punch_hit1.ogg")
	if not ResourceLoader.exists(caminho):
		return
	var som := AudioStreamPlayer3D.new()
	som.stream = load(caminho)
	som.volume_db = -8.0
	add_child(som)
	som.global_position = onde
	som.finished.connect(som.queue_free)
	som.play()


func _anim_do_buggy(nome: String) -> void:
	if _anim != null:
		_anim.gesto(nome)


# ------------------------------------------------------------------ pose (o mesmo caminho do treino: metas lidas pelo ProceduralAnimator)
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


func _atualizar_camera(delta: float) -> void:
	if _camera == null:
		return
	var k := smoothstep(0.0, 1.0, clampf(_t_fase / TEMPO_DE_ENTRADA, 0.0, 1.0)) if fase == Fase.ENTRANDO else 1.0
	if fase == Fase.SAINDO:
		k = 1.0 - smoothstep(0.0, 1.0, clampf(_t_fase / 0.5, 0.0, 1.0))
	_camera.global_transform = _de_onde.interpolate_with(_ate_onde, k)
	if _tremor > 0.0:
		var t := _tremor * 0.08
		_camera.global_position += Vector3(randf_range(-t, t), randf_range(-t, t), randf_range(-t, t))
		_tremor = maxf(_tremor - delta * 3.2, 0.0)


# ------------------------------------------------------------------ fim
func _encerrar() -> void:
	if _pago:
		return
	_pago = true
	var venceu := regras.jogador_venceu()
	_resultado = {"venceu": venceu, "acertos": regras.acertos, "defesas": regras.defesas, "erros": regras.erros,
		"vida_jogador": regras.vida_jogador, "vida_buggy": regras.vida_buggy}
	_tirar_pose()
	_rotulo_tecla.text = ""
	if venceu:
		_falar("derrota", true)
		_rotulo_feedback.text = "VOCÊ VENCEU!"
		_rotulo_feedback.modulate = Color(1.0, 0.9, 0.3)
		if _anim != null:
			_anim.gesto("death", true)             # fica caído até `soltar()` (quem desmonta o palco)
		_derrubar_buggy()
	else:
		_falar("vitoria", true)
		_rotulo_feedback.text = "O BUGGY VENCEU"
		_rotulo_feedback.modulate = Color(1.0, 0.4, 0.35)
		_anim_do_buggy("clap")
	_atualizar_ui()


## O Buggy nocauteado cai de lado, para o lado da câmera (a animação `death` do modelo só toca o rig; o corpo inteiro cai aqui).
func _derrubar_buggy() -> void:
	if _reacao != null and _reacao.is_valid():
		_reacao.kill()
	_reacao = _buggy.create_tween().set_parallel(true)
	_reacao.tween_property(_buggy, "rotation:z", PI / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_reacao.tween_property(_buggy, "global_position:y", _centro.y + 0.35, 0.45)


func _limpar() -> void:
	_tirar_pose()
	if is_instance_valid(_buggy):
		_buggy.rotation.x = 0.0                    # de pé de novo (o `DesafioDoBuggy` o devolve à praia)
		_buggy.rotation.z = 0.0
	if is_instance_valid(_jogador):
		_jogador.remove_meta("pose_externa")
		_jogador.set_meta("is_frozen", false)
		if _imune_antes:
			_jogador.set_meta("damage_immune", true)
		else:
			_jogador.remove_meta("damage_immune")
	if _reacao != null and _reacao.is_valid():
		_reacao.kill()
	for l in _luvas:
		if is_instance_valid(l):
			l.queue_free()
	_luvas.clear()
	if is_instance_valid(_camera_anterior):
		_camera_anterior.make_current()
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _ui != null:
		_ui.queue_free()
		_ui = null
	if ringue != null:
		ringue.queue_free()
		ringue = null
	fase = Fase.PARADO
	set_process(false)
	set_process_input(false)
