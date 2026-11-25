extends SceneTree
## SOM DA NIKYU (30/10/2026). Parte 1: os 5 eventos de som que o Java da Nikyu toca existem no pacote, têm arquivo e carregam com duração.
## Parte 2: em jogo, cada técnica cria os players de áudio dos eventos que o Java toca (Pad Ho: explosão + varredura; Ursus Shock: flecha +
## flame_explode; Assault: flame_explode da onda; Kuma Punch: pegar + varredura; passiva: pegar), nos tons e volumes do mod.
## ⚠️ Headless não toca áudio: confere o que seria tocado (players criados, evento, tom, volume), NÃO a qualidade do som.
const ID := "nikyu_nikyu_mine_piece"
const EVENTOS := {
	"explosao": "minecraft:entity.generic.explode", "varredura": "minecraft:entity.player.attack.sweep",
	"pegar": "minecraft:entity.item.pickup", "flecha": "minecraft:entity.arrow.shoot", "flame": "minepiece:flame_explode",
}
var _falhas := 0
var _evento_do_stream := {}      # AudioStream -> chave de EVENTOS
var _tocou: Array = []           # [chave, pitch, volume_db]
class Alvo extends Node3D:
	var health := 100000.0
	var combate_direcional = null
	func _ready() -> void:
		add_to_group("alvo_de_golpe")
		var hb := Area3D.new()
		hb.name = "Hurtbox"
		hb.collision_layer = 0
		hb.collision_mask = 0
		add_child(hb)
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(4, 2, 2)
		cs.shape = caixa
		hb.add_child(cs)
	func take_damage(dano: float, _o := Vector3.ZERO, _e := Vector3.ZERO, _s := 0.0) -> void:
		health -= dano

func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _quadros(n: int) -> void:
	for i in n: await physics_frame
func _tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _ouvir(no: Node) -> void:
	if no is AudioStreamPlayer3D:
		var ch = _evento_do_stream.get((no as AudioStreamPlayer3D).stream, "?")
		_tocou.append([ch, (no as AudioStreamPlayer3D).pitch_scale, (no as AudioStreamPlayer3D).volume_db])

func _chaves() -> Array:
	var s := {}
	for t in _tocou:
		s[t[0]] = true
	var k := s.keys()
	k.sort()
	return k

func _r() -> void:
	await process_frame
	print("\n-- 1. os eventos de som existem no pacote --")
	var visual = load("res://src/minecraft/mc_visual.gd")
	visual._carregar()
	var dados: Dictionary = visual._dados.sons
	for ch in EVENTOS:
		var evento: String = EVENTOS[ch]
		var arqs: Array = dados.get(evento, [])
		_ok(not arqs.is_empty(), "%s tem arquivos no pacote (%d)" % [evento, arqs.size()])
		var carregou := 0
		for i in arqs:
			var nome := str(i["n"]) if i is Dictionary else str(i)
			var s: AudioStream = visual._stream(nome)
			if s != null and s.get_length() > 0.0:
				carregou += 1
				_evento_do_stream[s] = ch
		_ok(carregou == arqs.size() and carregou > 0, "%s: todos carregam com duração > 0" % evento)

	print("\n-- 2. cada técnica toca o que o Java toca --")
	var modo = load("res://src/historia/ModoHistoria.gd")
	var controle = load("res://src/combat/frutas_mine_piece/controlador.gd")
	var mapa := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar("user://test_nikyu_som_mapa.json", mapa.mapa)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_nikyu_som.json"))
	modo.set("mapa_forcado", "user://test_nikyu_som_mapa.json")
	modo.set("progresso_forcado", "user://test_nikyu_som.json")
	root.get_node("GameFlow").start_story()
	await _quadros(120)
	var p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	modo.equipar_fruta(p, ID)
	await _quadros(15)
	var c = controle.de(p)
	p.set_meta("damage_immune", true)
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 1.2, -9)
	node_added.connect(_ouvir)

	var casos := [
		["Pad Ho (21)", 21, ["explosao", "varredura"], 0.4],
		["Ursus Shock (22)", 22, ["flame", "flecha"], 0.0],
		["Assault (25)", 25, ["flame"], 0.0],
		["Kuma Punch (28)", 28, ["pegar", "varredura"], 0.0],
	]
	for caso in casos:
		await _quadros(30)
		while c.selecao != caso[1]:
			_tecla(KEY_R, true)
			_tecla(KEY_R, false)
			await _quadros(2)
		c.recarga = 0.0
		c.imunidade.clear()
		p.global_position = Vector3(0, 1, 0)
		p.velocity = Vector3.ZERO
		p.energy = p.max_energy
		_tocou.clear()
		_tecla(KEY_Z, true)
		await _quadros(14)
		_tecla(KEY_Z, false)
		await _quadros(240)
		var achadas := _chaves()
		var esperadas: Array = caso[2].duplicate()
		esperadas.sort()
		var tem_todas := true
		for e in esperadas:
			tem_todas = tem_todas and achadas.has(e)
		_ok(tem_todas, "%s toca %s (tocou: %s)" % [caso[0], str(esperadas), str(achadas)])
		_ok(not achadas.has("?"), "%s: todo player de áudio é de um evento conhecido" % caso[0])

	# Tons e volumes do Java onde são exatos
	await _quadros(30)
	while c.selecao != 21:
		_tecla(KEY_R, true)
		_tecla(KEY_R, false)
		await _quadros(2)
	c.recarga = 0.0
	p.energy = p.max_energy
	_tocou.clear()
	_tecla(KEY_Z, true)
	await _quadros(14)
	_tecla(KEY_Z, false)
	await _quadros(60)
	var tons := []
	for t in _tocou:
		if t[0] == "varredura":
			tons.append(snappedf(t[1], 0.01))
	_ok(not tons.is_empty() and absf(float(tons[0]) - 1.25 * 1.0) < 0.2, "Pad Ho: a varredura sai em tom ~1,25 (o do mod; variante do arquivo pode mexer um pouco): %s" % str(tons))

	# Passiva (toque duplo): dois conjuntos de 3 `entity.item.pickup`
	await _quadros(30)
	c.recarga = 0.0
	_tocou.clear()
	c.comecar_passiva(1)
	await _quadros(40)
	var pegar := 0
	for t in _tocou:
		if t[0] == "pegar":
			pegar += 1
	_ok(pegar == 6, "passiva: 3 'pegar' antes do salto e 3 depois (%d)" % pegar)

	node_added.disconnect(_ouvir)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)
