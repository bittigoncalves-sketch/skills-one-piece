class_name ReanimacaoDoCoracao
extends Node
# ============================================================================
#  REANIMAÇÃO DO CORAÇÃO (04/11/2026). Pedido do dono: "quando a vida chegar a zero, ao invés de o
#  jogador morrer aparece um coração voxel e ele entra num minigame no estilo da pesca para fazer o
#  coração voltar a bater. A vida recuperada é no máximo 50 % e compatível com a nota. O corpo e a
#  tela tremem, assim como o som, a cada batida. O jogador pode fazer esse minigame até 3 vezes
#  dentro de 30 minutos; se morrer mais de 3 vezes é morte certa."
#
#  ATUALIZAÇÃO 18/11/2026: o limite caiu de 3 para 1 (`MAX_TENTATIVAS`); o contador fica ao lado da vida (`VidaEnergiaHud`).
#
#  Instalado pelo ModoHistoria no lugar de `MorteDoJogador.iniciar` (`Player.ao_morrer`); a arena
#  segue com o respawn do placar. Decisões do dono para os cantos:
#   • nota < 10 % → o coração não volta: vale a sequência de morte de sempre (`MorteDoJogador`);
#   • queda no vazio não ativa o minigame (não há corpo para reanimar) e NÃO gasta chance;
#   • as 3 chances são uma janela deslizante de 30 min de RELÓGIO REAL, GRAVADA NO SAVE
#     (`ProgressaoDoPersonagem.reanimacoes_ms`, formato v3): fechar o jogo não zera. Mudar o
#     relógio do computador burla (aceito); reiniciar a campanha zera junto com o resto.
#
#  Enquanto o minigame roda: o corpo cai no chão (clipe `dying`, controles travados por
#  `net_eliminar`), o mundo anda a ×0,15 e o relógio do minigame é o REAL (não o do mundo).
# ============================================================================

const JANELA_MS := 30 * 60 * 1000
## Pedido do dono (18/11/2026): no máximo 1 ressurreição por janela de 30 min (antes 3).
const MAX_TENTATIVAS := 1
const ESCALA_DO_MUNDO := 0.15
const ACAO := &"combate_atacar"
const TREMOR_DO_CORPO := 0.06            # m, na batida mais forte
const PAUSA_DEPOIS_DA_NOTA := 1.9        # s reais mostrando a nota antes de agir
const IMUNIDADE_AO_VOLTAR := 2.5         # s reais de imunidade depois de levantar

## Desliga o recurso (testes da morte de sempre).
static var habilitada := true
## Testes: devolve o "agora" em ms no lugar do relógio real.
static var relogio_ms := Callable()
static var _tentativas: Array[int] = []
static var _som: AudioStreamWAV = null

signal terminou(voltou: bool)

var jogador: Node3D
## Testes: recebe a `BatidaDoCoracao` e devolve true para "segurando".
var robo := Callable()
## Testes: roda o minigame N vezes mais rápido (N passos por quadro).
var acelerar := 1
var batida: BatidaDoCoracao
var resultado := ""                      # "" | "voltou" | "morreu"
var batidas := 0

var _imune_antes := false
var _ultimo_us := 0
var _proxima_batida := 0.3
var _t_nota := 0.0
var _tremor := 0.0
var _base_x := 0.0
var _base_z := 0.0
var _camada: CanvasLayer
var _conteudo: Control
var _coracao: CoracaoVoxel
var _barra_pressao: BarraDoCoracao
var _barra_nota: BarraDoCoracao
var _titulo: Label
var _dica: Label
var _aviso: Label
var _info: Label
var _cartao: Label


# ------------------------------------------------------------------ chances
## Relógio real em ms (época Unix): é o que vai para o save, então vale entre sessões.
static func agora() -> int:
	return int(relogio_ms.call()) if relogio_ms.is_valid() else int(Time.get_unix_time_from_system() * 1000.0)


## A progressão da campanha (onde as chances são gravadas); null em testes isolados — aí vale a lista
## em memória.
static func _progressao() -> ProgressaoDoPersonagem:
	var arvore := Engine.get_main_loop() as SceneTree
	var cena := arvore.current_scene if arvore != null else null
	return (cena.get("progressao") as ProgressaoDoPersonagem) if cena != null else null


## Quantas reanimações já foram feitas nos últimos 30 minutos.
static func tentativas_na_janela() -> int:
	var prog := _progressao()
	if prog != null:
		return prog.reanimacoes_na_janela(agora(), JANELA_MS)
	var limite := agora() - JANELA_MS
	_tentativas = _tentativas.filter(func(t: int) -> bool: return t > limite)
	return _tentativas.size()


static func chances_restantes() -> int:
	return maxi(MAX_TENTATIVAS - tentativas_na_janela(), 0)


## Marca uma reanimação agora (ou em `ms`, nos testes). Com campanha, grava no save.
static func registrar(ms := -1) -> void:
	var quando := agora() if ms < 0 else ms
	var prog := _progressao()
	if prog != null:
		prog.registrar_reanimacao(quando)
	else:
		_tentativas.append(quando)


static func esquecer_tentativas() -> void:
	_tentativas.clear()
	var prog := _progressao()
	if prog != null:
		prog.reanimacoes_ms.clear()


## Gancho de `Player.ao_morrer`: minigame, ou a morte de sempre quando não vale.
static func iniciar(quem: Node3D, caiu := false) -> void:
	if not habilitada or caiu or quem == null or chances_restantes() <= 0:
		MorteDoJogador.iniciar(quem, caiu)
		return
	var cena := quem.get_tree().current_scene
	if cena == null:
		MorteDoJogador.iniciar(quem, caiu)
		return
	registrar()
	var r := ReanimacaoDoCoracao.new()
	r.name = "ReanimacaoDoCoracao"
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	r.jogador = quem
	cena.add_child(r)


# --------------------------------------------------------------------- vida
func _ready() -> void:
	_imune_antes = bool(jogador.get_meta("damage_immune", false))
	jogador.set_meta("damage_immune", true)           # coração parado não leva mais dano
	jogador.set_meta("morte_ja_animada", true)
	jogador.net_eliminar()                            # trava os controles, vida 0, o corpo cai (clipe `dying`)
	var corpo := jogador.get("_char_model") as Node3D
	if corpo != null:
		_base_x = corpo.position.x
		_base_z = corpo.position.z
	Engine.time_scale = ESCALA_DO_MUNDO
	batida = BatidaDoCoracao.new(int(Time.get_ticks_usec() & 0x7fffffff))
	_ultimo_us = Time.get_ticks_usec()
	_montar_tela()


func _process(_delta: float) -> void:
	var agora_us := Time.get_ticks_usec()
	var dt := clampf((agora_us - _ultimo_us) / 1000000.0, 0.0, 0.1)    # tempo REAL, não o do mundo
	_ultimo_us = agora_us
	if resultado.is_empty():
		for i in maxi(acelerar, 1):
			if resultado.is_empty():
				_jogar(dt)
	else:
		_t_nota += dt
		if _t_nota >= PAUSA_DEPOIS_DA_NOTA:
			_concluir()
			return
	_tremer(dt)


func _jogar(dt: float) -> void:
	var segurando: bool
	if robo.is_valid():
		segurando = bool(robo.call(batida))
	else:
		segurando = Input.is_action_pressed(ACAO) or Input.is_key_pressed(KEY_SPACE)
	var fim := batida.passo(dt, segurando)
	_proxima_batida -= dt
	if _proxima_batida <= 0.0:
		_bater()
		_proxima_batida = lerpf(1.5, 0.7, batida.progresso)      # recupera: o ritmo acelera
	_atualizar_tela(segurando)
	if fim:
		_terminar()


## Uma batida: som, pulso do coração, tremor da tela e do corpo.
func _bater() -> void:
	batidas += 1
	var forca := 0.55 + 0.45 * batida.progresso
	_tremor = forca
	_coracao.bater(forca)
	_tocar_som(forca)
	var camera = jogador.get("_camera")
	if camera != null and camera.has_method("pedir_shake"):
		camera.pedir_shake(0.35 + 0.35 * forca)


func _terminar() -> void:
	var voltou := batida.voltou()
	resultado = "voltou" if voltou else "morreu"
	_coracao.definir_batendo(voltou)
	var nota := int(round(batida.nota() * 100.0))
	if voltou:
		_cartao.text = "NOTA %d%%\nvolta com %d%% de vida" % [nota, int(round(batida.vida_devolvida() * 100.0))]
		_cartao.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5))
	else:
		_cartao.text = "NOTA %d%%\no coração não voltou" % nota
		_cartao.add_theme_color_override("font_color", Color(0.85, 0.15, 0.18))
	_cartao.visible = true
	_dica.visible = false
	_aviso.visible = false


func _concluir() -> void:
	set_process(false)
	_restaurar_mundo()
	var voltou := resultado == "voltou"
	if is_instance_valid(jogador):
		if voltou:
			jogador.reviver_do_coracao(batida.vida_devolvida())
			if not _imune_antes:
				get_tree().create_timer(IMUNIDADE_AO_VOLTAR, true, false, true).timeout.connect(
					_fim_da_imunidade.bind(jogador))
			else:
				jogador.set_meta("damage_immune", true)
		else:
			# A morte de verdade: devolve a imunidade ao que era antes (senão ela ficaria presa) e
			# deixa a sequência de morte do História tocar. O corpo já está caído (`net_eliminar`).
			if not _imune_antes:
				jogador.remove_meta("damage_immune")
			jogador.remove_meta("morte_ja_animada")
			MorteDoJogador.iniciar(jogador, false)
	terminou.emit(voltou)
	queue_free()


static func _fim_da_imunidade(quem: Node3D) -> void:
	if is_instance_valid(quem):
		quem.remove_meta("damage_immune")


func _restaurar_mundo() -> void:
	Engine.time_scale = 1.0
	var corpo := jogador.get("_char_model") as Node3D if is_instance_valid(jogador) else null
	if corpo != null:
		corpo.position.x = _base_x
		corpo.position.z = _base_z


func _tremer(dt: float) -> void:
	_tremor = maxf(_tremor - dt * 4.0, 0.0)
	var corpo := jogador.get("_char_model") as Node3D if is_instance_valid(jogador) else null
	if corpo != null:
		corpo.position.x = _base_x + randf_range(-1.0, 1.0) * TREMOR_DO_CORPO * _tremor
		corpo.position.z = _base_z + randf_range(-1.0, 1.0) * TREMOR_DO_CORPO * _tremor
	if _conteudo != null:
		_conteudo.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 14.0 * _tremor


func _exit_tree() -> void:
	# A cena mudou no meio: não deixa o mundo lento nem o jogador preso e imune.
	if resultado.is_empty() and is_instance_valid(jogador):
		_restaurar_mundo()
		if jogador.morrendo:
			jogador.morrendo = false
			if jogador.has_meta("morte_ja_animada"):
				jogador.remove_meta("morte_ja_animada")
			if not _imune_antes and jogador.has_meta("damage_immune"):
				jogador.remove_meta("damage_immune")
	elif Engine.time_scale == ESCALA_DO_MUNDO:
		Engine.time_scale = 1.0


# ------------------------------------------------------------------ som
## Batimento sintetizado (lub-dub), o mesmo timbre grave da morte, sem arquivo.
func _tocar_som(forca: float) -> void:
	if _som == null:
		var n := int(MorteDoJogador.TAXA * 0.8)
		var a := PackedFloat32Array()
		a.resize(n)
		for i in n:
			var t := float(i) / MorteDoJogador.TAXA
			var v := sin(TAU * 54.0 * t) * exp(-t * 15.0)
			var t2 := t - 0.24
			if t2 > 0.0:
				v += 0.75 * sin(TAU * 47.0 * t2) * exp(-t2 * 17.0)
			a[i] = v * 0.95
		_som = MorteDoJogador._wav(a)
	var p := AudioStreamPlayer.new()
	p.stream = _som
	p.volume_db = linear_to_db(clampf(forca, 0.1, 1.0)) - 2.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ------------------------------------------------------------------ tela
func _montar_tela() -> void:
	_camada = CanvasLayer.new()
	_camada.layer = 99
	_camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_camada)
	var veu := ColorRect.new()
	veu.color = Color(0.16, 0.0, 0.02, 0.62)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(veu)
	_conteudo = Control.new()
	_conteudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_conteudo)
	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 8)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conteudo.add_child(coluna)
	_titulo = _rotulo("O CORAÇÃO PAROU", 46, Color(0.9, 0.12, 0.16))
	coluna.add_child(_titulo)
	_coracao = CoracaoVoxel.new()
	_coracao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_coracao)
	_aviso = _rotulo("!", 48, Color(1.0, 0.85, 0.2))
	_aviso.visible = false
	coluna.add_child(_aviso)
	_barra_pressao = BarraDoCoracao.new()
	_barra_pressao.zona = Vector2(BatidaDoCoracao.ZONA_MIN, BatidaDoCoracao.ZONA_MAX)
	_barra_pressao.custom_minimum_size = Vector2(460, 30)
	_barra_pressao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_barra_pressao)
	_barra_nota = BarraDoCoracao.new()
	_barra_nota.custom_minimum_size = Vector2(460, 16)
	_barra_nota.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coluna.add_child(_barra_nota)
	_dica = _rotulo("SEGURE o clique para bombear · SOLTE para dar folga · mantenha o marcador no VERDE", 17, Color(0.9, 0.86, 0.84))
	coluna.add_child(_dica)
	_info = _rotulo("", 18, Color(0.8, 0.74, 0.72))
	coluna.add_child(_info)
	_cartao = _rotulo("", 40, Color.WHITE)
	_cartao.visible = false
	coluna.add_child(_cartao)
	_atualizar_tela(false)


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _atualizar_tela(segurando: bool) -> void:
	_barra_pressao.valor = batida.pressao
	_barra_pressao.destaque = segurando
	_barra_pressao.queue_redraw()
	_barra_nota.valor = batida.progresso
	_barra_nota.queue_redraw()
	_aviso.visible = (batida.avisando or batida.arritmia) and resultado.is_empty() \
		and int(Time.get_ticks_msec() / 110) % 2 == 0
	_info.text = "%02d s · chances: %d de %d (30 min)" % [int(ceil(batida.restante())),
		chances_restantes(), MAX_TENTATIVAS]


## Barra horizontal: fundo, zona verde opcional (pressão) e preenchimento ou marcador.
class BarraDoCoracao extends Control:
	var valor := 0.0
	var zona := Vector2.ZERO          # != 0 => barra de pressão (marcador na zona verde)
	var destaque := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.05, 0.02, 0.03, 0.85))
		if zona != Vector2.ZERO:
			draw_rect(Rect2(zona.x * size.x, 0, (zona.y - zona.x) * size.x, size.y), Color(0.2, 0.75, 0.3, 0.55))
			var x := valor * size.x
			var dentro := valor >= zona.x and valor <= zona.y
			draw_rect(Rect2(x - 3, -4, 6, size.y + 8), Color(0.55, 1.0, 0.55) if dentro else Color(1.0, 0.3, 0.3))
		else:
			draw_rect(Rect2(0, 0, valor * size.x, size.y), Color(0.85, 0.12, 0.18).lerp(Color(0.95, 0.85, 0.3), valor))
		draw_rect(r, Color(0.9, 0.8, 0.8, 0.9) if destaque else Color(0.6, 0.5, 0.5, 0.8), false, 2.0)
