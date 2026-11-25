extends SceneTree
# ============================================================================
#  RAID OBRIGATÓRIA A CADA 10 MINUTOS (18/11/2026).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_raid_obrigatoria.gd
#  Na cena real: o relógio nasce em 10 min; aos 60/30/10 s avisa; zerado, a raid COMEÇA sozinha (sem bandeira nem Z); menu aberto ou barco ADIAM e avisam
#  o motivo; cada fim de raid e cada raid manual recomeçam os 10 min; desligada, nunca começa.
# ============================================================================
var total := 0
var falhas := 0
class HudParado extends Node:
	var menu := false
	var avisos: Array[String] = []
	func is_menu_open() -> bool: return menu
	func avisar(t: String) -> void: avisos.append(t)
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_raid_obrigatoria.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_raid_obrigatoria.json"))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena := current_scene
	var raid: Node = cena.get("raid")
	var jogador: Node3D = get_first_node_in_group("player")
	ok(raid != null and jogador != null, "a raid e o jogador existem")
	if raid == null or jogador == null:
		quit(1)
		return
	jogador.set_meta("damage_immune", true)
	cena.call("ir_a_ilha", "ilha_east_blue")
	await quadros(30)
	ok(raid.INTERVALO_OBRIGATORIA == 600.0, "o intervalo é de 10 minutos (600 s)")
	ok(raid.proxima_em > 500.0 and raid.proxima_em <= 600.0 and not raid.ativa, "o relógio corre desde o começo (%.0f s) sem raid" % raid.proxima_em)
	ok(raid.contagem_em_texto().length() == 5 and raid.contagem_em_texto()[2] == ":", "contagem em mm:ss (%s)" % raid.contagem_em_texto())
	# avisos
	var hud_real: Node = raid.hud
	var falso := HudParado.new()
	root.add_child(falso)
	raid.hud = falso
	raid.proxima_em = 61.0
	await quadros(90)
	var contou := falso.avisos.filter(func(a): return a.begins_with("RAID obrigatória em")).size()
	ok(contou >= 1 and contou <= 3, "avisa a contagem aos 60/30/10 s (%d aviso(s): %s)" % [contou, str(falso.avisos)])
	# menu aberto ADIA
	falso.avisos.clear()
	raid.proxima_em = 0.2
	falso.menu = true
	await quadros(60)
	ok(not raid.ativa and raid.adiada_por == "menu aberto" and falso.avisos.any(func(a): return a.contains("adiada")), "com o menu aberto a raid é adiada e avisa (%s)" % raid.adiada_por)
	# fechado o menu, começa sozinha — sem bandeira, sem Z
	falso.menu = false
	await quadros(30)
	ok(raid.ativa and raid.mar == "east_blue" and raid.adiada_por == "", "fechado o menu, a raid obrigatória COMEÇA sozinha (mar %s, estágio %d)" % [raid.mar, raid.estagio])
	ok(falso.avisos.any(func(a): return a == "RAID OBRIGATÓRIA!"), "avisa que a raid obrigatória começou")
	ok(raid.proxima_em == raid.INTERVALO_OBRIGATORIA, "o relógio recomeça quando a raid começa")
	# cancelar / vencer recomeçam o relógio
	raid.proxima_em = 123.0
	raid.cancelar("teste")
	ok(not raid.ativa and raid.proxima_em == raid.INTERVALO_OBRIGATORIA, "raid cancelada: os 10 min recomeçam")
	# barco ADIA (a viagem de barco ligada na navegação real)
	var nav := get_first_node_in_group("navegacao_historia")
	ok(nav != null, "a navegação do Modo História existe")
	if nav != null:
		nav.set("viagem_ativa", true)
		ok(raid.motivo_de_adiar(jogador) == "você está num barco", "viagem de barco adia (%s)" % raid.motivo_de_adiar(jogador))
		nav.set("viagem_ativa", false)
		ok(raid.motivo_de_adiar(jogador) == "", "em terra firme, sem menu, nada adia")
	# desligada: nunca começa
	raid.obrigatoria = false
	raid.proxima_em = 0.0
	await quadros(60)
	ok(not raid.ativa, "desligada, a raid obrigatória não começa")
	ok(not raid._contagem_rotulo.visible, "desligada, o rótulo de contagem some")
	raid.obrigatoria = true
	raid.hud = hud_real
	falso.queue_free()
	print("RAID_OBRIGATORIA: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
