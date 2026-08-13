class_name Hud
extends CanvasLayer
# HUD fino: monta a barra de técnicas, inventário, menu de personagens e o menu principal.

const MainMenuClass := preload("res://src/ui/MainMenu.gd")
const StatsHudClass := preload("res://src/ui/StatsHud.gd")
# `Player.local_player(tree)` = o corpo DESTE peer. Ver o comentário lá: no
# cliente, `get_first_node_in_group("player")` devolve o corpo do HOST.
const PlayerScript := preload("res://Player.gd")

var _inv: Inventory
var _skill_bar: SkillBar
var _char_menu: CharacterMenu
var _main_menu: Node
var _stats: Node
var _match: MatchHud
var _status: StatusEffectsHud
var _ammo: AmmoHud
var _scope: SniperScope

func _ready() -> void:
	add_to_group("hud")   # o Player encontra a HUD por este grupo ao equipar fruta
	_skill_bar = SkillBar.new()
	_skill_bar.name = "SkillBar"
	add_child(_skill_bar)

	_char_menu = CharacterMenu.new()
	_char_menu.name = "CharacterMenu"
	add_child(_char_menu)

	_inv = Inventory.new()
	_inv.name = "Inventory"
	add_child(_inv)

	_main_menu = MainMenuClass.new()
	_main_menu.name = "MainMenu"
	_main_menu.setup(self)
	add_child(_main_menu)

	_stats = StatsHudClass.new()
	_stats.name = "StatsHud"
	add_child(_stats)

	_match = MatchHud.new()
	_match.name = "MatchHud"
	add_child(_match)

	_status = StatusEffectsHud.new()
	_status.name = "StatusEffectsHud"
	add_child(_status)

	# LUNETA DA SNIPER (Buki Buki, slot C). Vem ANTES do AmmoHud de propósito: a
	# máscara é preta opaca e cobre os irmãos somados antes dela, e o contador de
	# balas é a única coisa que precisa continuar legível com o zoom ligado.
	_scope = SniperScope.new()
	_scope.name = "SniperScope"
	add_child(_scope)

	# Munição da Buki Buki (canto inferior direito). Só aparece com arma na mão.
	_ammo = AmmoHud.new()
	_ammo.name = "AmmoHud"
	add_child(_ammo)

	# Itens iniciais de exemplo.
	_inv.add_item({"nome": "Suna Suna no Mi", "tipo": "Logia", "cor": Color(0.95, 0.8, 0.45)})
	_inv.add_item({"nome": "Gomu Gomu no Mi", "tipo": "Paramecia", "cor": Color(0.79, 0.29, 0.23)})
	_inv.add_item({"nome": "Mera Mera no Mi", "tipo": "Logia", "cor": Color(1.0, 0.42, 0.12)})

func toggle_main_menu() -> void:
	if _main_menu:
		_main_menu.toggle()

# ---- status (vida/energia/aim assist/contador de dano) ----
func set_aim_assist(on: bool) -> void:
	if _stats:
		_stats.set_aim_assist(on)

func on_player_damaged(amount: float, hp: float, mhp: float) -> void:
	if _stats:
		_stats.on_player_damaged(amount, hp, mhp)

func add_damage_dealt(amount: float) -> void:
	if _stats:
		_stats.add_damage_dealt(amount)

func show_anim_name(text: String) -> void:
	if _stats:
		_stats.show_anim_name(text)

func is_char_menu_open() -> bool:
	return _char_menu and _char_menu.is_open()

func is_menu_open() -> bool:
	if _main_menu and _main_menu.is_open():
		return true
	if _inv and _inv.is_open():
		return true
	if _char_menu and _char_menu.is_open():
		return true
	return false

func add_item(item: Dictionary) -> void:
	_inv.add_item(item)
	var fid: String = str(item.get("id", item.get("nome", ""))).to_lower().replace(" no mi", "").replace(" ", "_")
	if _skill_bar:
		_skill_bar.update_skills_for_fruit(fid)

# Chamado pelo Player.equip_fruit (via grupo "hud") — atualiza a barra de técnicas.
func update_skills_for_fruit(fruit_id: String) -> void:
	if _skill_bar:
		_skill_bar.update_skills_for_fruit(fruit_id)

func update_combat_mode(mode: String, style_id: String, fruit_id: String) -> void:
	if _skill_bar:
		if mode == "fruit":
			_skill_bar.update_skills_for_fruit(fruit_id)
		else:
			_skill_bar.update_skills_for_style(style_id)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	var key: int = event.keycode

	if event.pressed and key == KEY_ESCAPE:
		if _inv and _inv.is_open():
			_inv.toggle()
			return
		if _char_menu and _char_menu.is_open():
			_char_menu.toggle()
			return
		toggle_main_menu()
		return

	if event.pressed and key == KEY_I:
		if _inv and _inv.is_open():
			_inv.toggle()
			return
		if not is_menu_open():
			_inv.toggle()
			return

	if event.pressed and key == KEY_M:
		if _char_menu and _char_menu.is_open():
			_char_menu.toggle()
			return
		if not is_menu_open():
			_char_menu.toggle()
			return

	if is_menu_open():
		return

	var slot := ""
	match key:
		KEY_Z: slot = "Z"
		KEY_X: slot = "X"
		KEY_C: slot = "C"
		KEY_V: slot = "V"
	if slot == "":
		return

	var player := PlayerScript.local_player(get_tree())   # o MEU corpo, não o 1º da árvore
	if player == null:
		return
	# Segura = carrega/mira; solta = dispara (hold-to-cast).
	if event.pressed:
		if player.has_method("begin_charge"):
			player.begin_charge(slot)
	elif player.has_method("release_charge"):
		player.release_charge(slot)

