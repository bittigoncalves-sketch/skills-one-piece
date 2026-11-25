class_name SkillBar
extends PanelContainer
# Barra de técnicas no canto inferior direito, no estilo do OnePiece-Voxel
# (combat_hud): painel transparente cinza/branco, lista vertical [tecla] + nome.
#
# Nomes e recargas acompanham fruta, estilo ou Yoru do jogador local.

const SLOTS := ["Z", "X", "C", "V"]
# Os cooldowns exibidos são os do corpo DESTE peer — ver Player.local_player().
const PlayerScript := preload("res://Player.gd")

var _skill_labels: Dictionary = {}
var _ope_icons: Dictionary = {}
var _ope_equipped := false
var _sword_equipped := false
const OPE_ICONS := {"Z": "room", "X": "shambles", "C": "takt", "V": "gamma"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_bottom_right()
	_build()

func _anchor_bottom_right() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -14.0
	offset_top = -14.0
	offset_right = -14.0
	offset_bottom = -14.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

var _title_lbl: Label

func _build() -> void:
	# Fase 6 do plano visual: a caixa passou a usar o estilo compartilhado, para
	# falar a mesma língua das barras e do contorno 3D. Antes era borda de 1 px
	# clara — que a 1 px some, e clara briga com a linha escura da cena.
	var bg := Estilo.painel()
	bg.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	bg.shadow_size = 10
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 14 if m.ends_with("top") or m.ends_with("bottom") else 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ⚠️ LARGURA MÍNIMA, E ELA NÃO É COSMÉTICA (2026-09-06).
	#
	# O `ToqueHud` posiciona os botões de toque A PARTIR desta barra: a coluna
	# Z/X/C/V fica à ESQUERDA dela (`r.position.x - FOLGA - RAIO`) e a fileira
	# PULO/DASH/F é alinhada à DIREITA. Ou seja, a largura da barra — que depende
	# do TEXTO dentro dela — decide se os botões de toque se encostam.
	#
	# Descobri pelo `test_toque`: ao encurtar os títulos de "[R: Alternar]" para
	# "[1]" e "[2]", a barra estreitou, a borda esquerda andou para a direita, a
	# coluna de skills foi junto e colidiu com o PULO — 77 px onde eram precisos
	# 84. Um rótulo de HUD quebrou o alcance do dedo no celular.
	#
	# A largura mínima corta a dependência: mudar texto deixa de mover botão.
	custom_minimum_size.x = 300.0

	_title_lbl = Label.new()
	_title_lbl.text = "TÉCNICAS [R: Estilo]"
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	vbox.add_child(_title_lbl)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.85, 0.88, 0.92, 0.25)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	for tecla in SLOTS:
		vbox.add_child(_make_row(tecla))

func _make_row(tecla: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	var key_lbl := Label.new()
	key_lbl.text = "[%s]" % tecla
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_lbl.add_theme_font_size_override("font_size", 15)
	key_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.22, 0.24, 0.28, 0.60)
	ks.set_corner_radius_all(5)
	ks.set_border_width_all(1)
	ks.border_color = Color(0.75, 0.78, 0.85, 0.50)
	ks.content_margin_left = 7.0
	ks.content_margin_right = 7.0
	ks.content_margin_top = 2.0
	ks.content_margin_bottom = 2.0
	key_lbl.add_theme_stylebox_override("normal", ks)
	row.add_child(key_lbl)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	_ope_icons[tecla] = icon
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = "—"
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82, 0.9))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	name_lbl.set_meta("base_name", "—")
	_skill_labels[tecla] = name_lbl

	return row

func _process(_delta: float) -> void:
	if get_tree() == null:
		return
	_atualizar_posicao_ope()
	var player := PlayerScript.local_player(get_tree())
	if not is_instance_valid(player) or not ("_skill_cooldowns" in player):
		return
	for slot in SLOTS:
		if _skill_labels.has(slot) and player._skill_cooldowns.has(slot):
			var cd: float = player._skill_cooldowns[slot]
			if player.combat_mode == "sword" and is_instance_valid(player.get("_yoru_combat")):
				cd = player._yoru_combat.cooldown(slot)
			var lbl: Label = _skill_labels[slot]
			var base: String = lbl.get_meta("base_name", "—")
			if player.combat_mode == "sword" and slot == "C" and player._yoru_combat.riposte > 0.0:
				lbl.text = "APARO — M1 para responder"
				lbl.modulate = Color(0.5,1,0.65)
				continue
			if cd > 0.05:
				lbl.text = base + ("  ⏳ [%.1fs]" % cd)
				lbl.modulate = Color(1.0, 0.45, 0.45, 0.95) # Vermelho suave em recarga
			else:
				if lbl.text != base:
					lbl.text = base
				lbl.modulate = Color(1.0, 1.0, 1.0, 1.0) # Disponível
				if _ope_equipped and slot != "Z":
					var room := player.get_meta("ope_room") as Node if player.has_meta("ope_room") else null
					var ready := is_instance_valid(room) and not room.is_queued_for_deletion()
					if ready:
						var center: Vector3 = room.get("center")
						ready = player.global_position.distance_to(center) <= float(room.get("radius"))
					if not ready:
						lbl.modulate = Color(0.52, 0.65, 0.69, 0.85)

const GOMU_ICONS_BASE := {"Z": "pistol", "X": "bazooka", "C": "gatling", "V": "gear2"}
const GOMU_ICONS_GEAR2 := {"Z": "jet_pistol", "X": "jet_bazooka", "C": "gear3_gigant", "V": "gear2_cancel"}
const GORO_ICONS := {"Z": "sango", "X": "elthor", "C": "shunshin", "V": "mamaragan"}

## Fruta -> [pasta em `assets/ui/`, mapa slot->nome do arquivo]. Virou tabela na
## terceira fruta com ícone (Goro, 2026-09-12): a cadeia `if is_gomu ... elif
## is_ope ...` ia ganhar um ramo por fruta, e o nome do arquivo do ícone já
## estava escrito em dois lugares para cada uma.
const ICONES_POR_FRUTA := {
	"bara_bara": ["bara_bara", {"Z": "punch", "X": "pincer", "C": "cannon", "V": "festival"}],
	"ope_ope": ["ope_ope", OPE_ICONS],
	"gomu_gomu": ["gomu_gomu", GOMU_ICONS_BASE],
	"gomu_gomu_gear2": ["gomu_gomu", GOMU_ICONS_GEAR2],
	"goro_goro": ["goro_goro", GORO_ICONS],
}

## Caminho do SVG de um slot, ou "" quando a fruta não tem arte própria.
static func caminho_do_icone(fruit_id: String, slot: String) -> String:
	if not ICONES_POR_FRUTA.has(fruit_id):
		return ""
	var entrada: Array = ICONES_POR_FRUTA[fruit_id]
	var mapa: Dictionary = entrada[1]
	if not mapa.has(slot):
		return ""
	return "res://assets/ui/%s/%s.svg" % [entrada[0], mapa[slot]]

func update_skills_for_fruit(fruit_id: String) -> void:
	_sword_equipped = false
	var is_gomu_gear2 := (fruit_id == "gomu_gomu_gear2")
	# Sobe a barra para o painel de treino (F1/F2) não cobrir os slots C e V.
	# Valia só para a Ope; a Goro entrou junto em 2026-09-12, quando ganhou
	# ícones próprios e o painel passou a comer metade da barra dela.
	# ⚠️ As DEMAIS frutas continuam cobertas — é anterior a esta mudança e está
	# registrado em docs/LISTA_DE_CORRECOES.md, esperando decisão do dono.
	_set_ope_icons(fruit_id in ["ope_ope", "goro_goro"])

	if ICONES_POR_FRUTA.has(fruit_id):
		for tecla in SLOTS:
			if _ope_icons.has(tecla):
				var ic: TextureRect = _ope_icons[tecla]
				var caminho := caminho_do_icone(fruit_id, tecla)
				ic.texture = load(caminho) if caminho != "" else null
				ic.visible = (caminho != "")
	else:
		for ic in _ope_icons.values():
			(ic as TextureRect).visible = false

	if _title_lbl:
		if is_gomu_gear2:
			_title_lbl.text = "FRUTA: GOMU GOMU [GEAR 2]"
		else:
			_title_lbl.text = "FRUTA: %s [1]" % fruit_id.to_upper().replace("_", " ")
	if fruit_id == "tori_tori_phoenix" and _title_lbl:
		_title_lbl.text = "PHOENIX · F: VOO (APÓS Z)"
	if KitDoBuilder.e_do_builder(fruit_id):
		# Kit do Builder (06/10/2026): os nomes das skills publicadas; o F vale pela tecla.
		if _title_lbl:
			_title_lbl.text = "%s [1]" % KitDoBuilder.nome(fruit_id).to_upper()
		for slot in SLOTS:
			if _skill_labels.has(slot):
				var nm := KitDoBuilder.nome_da_tecla(slot, fruit_id) if KitDoBuilder.tem(slot, fruit_id) else "—"
				_skill_labels[slot].set_meta("base_name", nm)
				_skill_labels[slot].text = nm
		return
	var fruit_skills := SkillSystem.get_fruit_skills()
	if fruit_skills.has(fruit_id):
		var fskills: Dictionary = fruit_skills[fruit_id]
		for slot in SLOTS:
			if fskills.has(slot) and _skill_labels.has(slot):
				var nm: String = fskills[slot].get("nome", "—")
				# Fruta da arena refeita no Builder (Pika, 06/10/2026): a tecla publicada
				# mostra o nome da skill do Builder.
				if KitDoBuilder.pelo_builder(fruit_id, slot):
					nm = KitDoBuilder.nome_da_tecla(slot, fruit_id)
				_skill_labels[slot].set_meta("base_name", nm)
				_skill_labels[slot].text = nm

func update_skills_for_style(style_id: String) -> void:
	_sword_equipped = false
	_set_ope_icons(false)
	if FightingStyles.STYLES.has(style_id):
		var sdata: Dictionary = FightingStyles.STYLES[style_id]
		if _title_lbl:
			_title_lbl.text = "ESTILO: %s [2]" % sdata.get("nome", style_id).to_upper()
		var skills: Dictionary = sdata.get("skills", {})
		for slot in SLOTS:
			if skills.has(slot) and _skill_labels.has(slot):
				var nm: String = skills[slot].get("nome", "—")
				_skill_labels[slot].set_meta("base_name", nm)
				_skill_labels[slot].text = nm

## Técnicas próprias do modo espada; recargas lidas no controlador Yoru.
func update_skills_for_sword() -> void:
	_sword_equipped = true
	_set_ope_icons(false)
	if _title_lbl:
		_title_lbl.text = "ESPADA: YORU [3]"
	var passos := ["Corte do Horizonte", "Passo do Predador", "Guarda da Cruz", "Ruptura da Noite"]
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		if not _skill_labels.has(slot):
			continue
		var texto: String = passos[i]
		_skill_labels[slot].set_meta("base_name", texto)
		_skill_labels[slot].text = texto


func _set_ope_icons(enabled: bool) -> void:
	_ope_equipped = enabled
	_atualizar_posicao_ope()
	for icon in _ope_icons.values():
		(icon as TextureRect).visible = enabled

func _atualizar_posicao_ope() -> void:
	# No PC reserva o painel de treino. No toque conserva a régua original:
	# elevar a barra também elevaria PULO para dentro da zona de câmera.
	var bottom := -108.0 if (_ope_equipped or _sword_equipped) and not ToqueHud.ativo() else -14.0
	if not is_equal_approx(offset_bottom, bottom):
		offset_bottom = bottom
		offset_top = bottom
