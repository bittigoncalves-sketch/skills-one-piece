extends Label
# ============================================================================
#  MISSÕES EM ANDAMENTO NA TELA (08/10/2026): "Bandidos no campo — 2 / 5", e quando
#  a meta chega, "volte ao Guarda da vila". Abaixo das barras de vida e energia (17/10/2026,
#  pedido do dono; era o canto superior direito); sem missão em andamento mostra a PRÓXIMA
#  que já dá para começar. Some sem texto e com menu aberto. Atualiza quando o progresso muda.
# ============================================================================

const Missoes := preload("res://src/historia/missoes/missoes.gd")

const ESPACO := 10.0
const LARGURA := 340.0   # a das barras

var progressao: ProgressaoDoPersonagem
var abaixo_de: Control   # as barras de vida e energia
var espaco_extra := 0.0
var _ilha_vista := ""
var _icones: HBoxContainer      # ícones (do Codex) das missões em andamento que têm `icone`, abaixo do texto (Ilha dos Macacos v2)


func _ready() -> void:
	name = "RastreadorDeMissoes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20.0, 120.0)
	size = Vector2(LARGURA, 0.0)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Texto longo ("volte ao Guarda da vila") quebra dentro da caixa, não passa da borda.
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 17)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	_icones = HBoxContainer.new()
	_icones.name = "Icones"
	_icones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icones.add_theme_constant_override("separation", 6)
	add_child(_icones)
	if progressao != null:
		progressao.mudou.connect(atualizar)
	atualizar()


func _process(_delta: float) -> void:
	if progressao != null and progressao.ilha != _ilha_vista:
		_ilha_vista = progressao.ilha            # trocar de ilha muda as missões "Próxima" (o detector não emite `mudou`)
		atualizar()
	if abaixo_de != null:
		position = abaixo_de.position + Vector2(0.0, abaixo_de.size.y + ESPACO + espaco_extra)
		size = Vector2(LARGURA, 0.0)   # a altura encolhe até o texto
	if _icones != null:
		_icones.position = Vector2(0.0, get_combined_minimum_size().y + 4.0)
	var hud := get_parent()
	visible = not text.is_empty() and not (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open"))


func atualizar() -> void:
	var partes: PackedStringArray = []
	if progressao != null:
		for id in Missoes.TABELA:
			var d := Missoes.dados(id)
			match progressao.estado_da_missao(id):
				Missoes.ACEITA:
					partes.append("◆ %s — %s" % [d["nome"], Missoes.contagem(id, progressao)])
				Missoes.PRONTA:
					partes.append("◆ %s — volte ao %s" % [d["nome"], NpcDaIlha.ficha(str(d["npc"])).get("nome", "NPC")])
	for id in Missoes.proximas(progressao):
		var d := Missoes.dados(id)
		partes.append("◇ Próxima: %s — fale com %s" % [d["nome"], NpcDaIlha.ficha(str(d["npc"])).get("nome", "NPC")])
	text = "\n".join(partes)
	_atualizar_icones()


func _atualizar_icones() -> void:
	if _icones == null:
		return
	for filho in _icones.get_children():
		filho.queue_free()
	if progressao == null:
		return
	for id in Missoes.TABELA:
		var d := Missoes.dados(id)
		var estado: String = progressao.estado_da_missao(id)
		if not d.has("icone") or not (estado == Missoes.ACEITA or estado == Missoes.PRONTA):
			continue
		var imagem := Image.load_from_file(ProjectSettings.globalize_path(str(d["icone"])))
		if imagem == null:
			continue
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(imagem)
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.tooltip_text = str(d["nome"])
		tr.modulate = Color(0.75, 1.0, 0.75) if estado == Missoes.PRONTA else Color.WHITE
		_icones.add_child(tr)
