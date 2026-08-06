class_name SkillBar
extends PanelContainer
# Barra de técnicas no canto inferior esquerdo, no estilo do OnePiece-Voxel
# (combat_hud): painel transparente cinza/branco, lista vertical [tecla] + nome.
#
# As SKILLS foram REMOVIDAS de propósito — serão criadas mais tarde. Por ora os
# slots ficam vazios ("—"). Basta preencher SLOTS quando as técnicas existirem.

const SLOTS := ["Z", "X", "C", "V"]

var _skill_labels: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_bottom_left()
	_build()

func _anchor_bottom_left() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 14.0
	offset_top = -14.0
	offset_right = 14.0
	offset_bottom = -14.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN

var _title_lbl: Label

func _build() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.12, 0.15, 0.40)
	bg.set_corner_radius_all(10)
	bg.border_color = Color(0.85, 0.88, 0.92, 0.50)
	bg.set_border_width_all(1)
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
	var player := get_tree().get_first_node_in_group("player")
	if not player or not ("_skill_cooldowns" in player):
		return
	for slot in SLOTS:
		if _skill_labels.has(slot) and player._skill_cooldowns.has(slot):
			var cd: float = player._skill_cooldowns[slot]
			var lbl: Label = _skill_labels[slot]
			var base: String = lbl.get_meta("base_name", "—")
			if cd > 0.05:
				lbl.text = base + ("  ⏳ [%.1fs]" % cd)
				lbl.modulate = Color(1.0, 0.45, 0.45, 0.95) # Vermelho suave em recarga
			else:
				if lbl.text != base:
					lbl.text = base
				lbl.modulate = Color(1.0, 1.0, 1.0, 1.0) # Disponível

func update_skills_for_fruit(fruit_id: String) -> void:
	if _title_lbl:
		_title_lbl.text = "FRUTA: %s [R: Alternar]" % fruit_id.to_upper().replace("_", " ")
	var fruit_skills := SkillSystem.get_fruit_skills()
	if fruit_skills.has(fruit_id):
		var fskills: Dictionary = fruit_skills[fruit_id]
		for slot in SLOTS:
			if fskills.has(slot) and _skill_labels.has(slot):
				var nm: String = fskills[slot].get("nome", "—")
				_skill_labels[slot].set_meta("base_name", nm)
				_skill_labels[slot].text = nm

func update_skills_for_style(style_id: String) -> void:
	if FightingStyles.STYLES.has(style_id):
		var sdata: Dictionary = FightingStyles.STYLES[style_id]
		if _title_lbl:
			_title_lbl.text = "ESTILO: %s [R: Alternar]" % sdata.get("nome", style_id).to_upper()
		var skills: Dictionary = sdata.get("skills", {})
		for slot in SLOTS:
			if skills.has(slot) and _skill_labels.has(slot):
				var nm: String = skills[slot].get("nome", "—")
				_skill_labels[slot].set_meta("base_name", nm)
				_skill_labels[slot].text = nm
