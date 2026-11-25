extends SceneTree
# ============================================================================
#  TRIPULANTES DE BORDO — Barba Negra atira, Crocodile voa e usa areia (15/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_tripulantes_de_bordo.gd
#
#  Pedido do dono: o Barba Negra dispara com uma pistola de dentro do barco em qualquer
#  inimigo; o Crocodile voa em volta do barco e dispara o Z da Suna Suna em qualquer
#  inimigo, e durante o voo a parte de baixo dele vira areia. Aqui, com o fluxo de verdade
#  (Y → Sim → zarpar) e um inimigo parado a 25 m.
# ============================================================================

const FONTE_DO_ALVO := """
extends CharacterBody3D
var health := 5000.0
var golpes: Array = []
func take_damage(amount: float, _de := Vector3.ZERO, _kb := Vector3.ZERO, _stun := 0.0) -> void:
	golpes.append(amount)
	health -= amount
"""

var _ok_n := 0
var _falhas := 0
var p: Node3D
var nav: Node
var hud: Node
var prog: ProgressaoDoPersonagem
var barco: CharacterBody3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_tripulantes_de_bordo.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_tripulantes_de_bordo.json"))
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	nav = current_scene.get("_navegacao")
	hud = current_scene.get("_hud")
	prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)
	var bib := MapaMontador.biblioteca_em_uso()
	barco = load("res://src/historia/navios/barco.gd").new()
	barco.configurar(bib, "small_ship", bib.tamanho_padrao("small_ship"))
	barco.position = Vector3(300, AguaDoMundo.superficie_em(300, 0) + 0.6, 0)
	current_scene.add_child(barco)
	nav.barcos.append(barco)
	prog.recrutados = {"nami": true, "crocodile": true, "barba_negra": true}
	for i in 60:
		await physics_frame

	# Sem inimigo por perto: ninguém atira.
	await _zarpar(["humano_barba_negra", "humano_crocodile", "caranguejo"])
	var bn: Node3D = barco.find_child("Tripulante_barba_negra", true, false)
	var croc: Node3D = barco.find_child("Tripulante_crocodile", true, false)
	_ok("os dois humanos estão a bordo", bn != null and croc != null)
	var pistoleiro: PistoleiroDeBordo = bn.get_node_or_null("Pistoleiro")
	var voo: VooDeAreia = croc.get_node_or_null("VooDeAreia")
	_ok("o Barba Negra tem a pistola e o Crocodile o voo de areia", pistoleiro != null and voo != null)
	_ok("a pistola está na mão do Barba Negra", pistoleiro != null and bn.find_child("Pistola", true, false) != null)
	for i in 200:
		await physics_frame
	_ok("sem inimigo, ninguém atira (%d / %d)" % [pistoleiro.disparos, voo.disparos], pistoleiro.disparos == 0 and voo.disparos == 0)

	# VOO: o Crocodile sobe e circula o barco.
	_ok("o Crocodile está voando (altura %.1f m acima do barco)" % croc.position.y, voo.esta_voando() and croc.position.y > 4.0)
	var raios: Array[float] = []
	var minimo_y := INF
	for i in 240:
		await physics_frame
		raios.append(Vector2(croc.position.x, croc.position.z).length())
		minimo_y = minf(minimo_y, croc.position.y)
	_ok("circula em volta do barco (raio %.1f–%.1f m)" % [raios.min(), raios.max()], raios.min() > 5.5 and raios.max() < 8.5)
	_ok("e continua no alto durante o voo (mínimo %.1f m)" % minimo_y, minimo_y > 4.0)
	var corpo: Node3D = croc.get_node("Corpo")
	_ok("inclinado para a frente, voando (%.0f°)" % rad_to_deg(corpo.rotation.x), corpo.rotation.x < -0.8)

	# AREIA: as pernas viram areia durante o voo.
	var sk: Skeleton3D = croc.call("esqueleto")
	_ok("o esqueleto do Crocodile tem o modificador das pernas (força %.2f)" % voo.forca_da_areia(), sk != null and voo.forca_da_areia() > 0.95)
	await physics_frame
	# O pé deve colar no quadril: a distância (no espaço do esqueleto) cai a quase zero.
	# O esqueleto restaura a pose original depois de cada atualização; o que vai para a tela é a
	# pose DURANTE `skeleton_updated`. É nela que se mede: o pé tem de colar na articulação da coxa.
	var medida := [-1.0]
	var ler := func():
		var q := sk.get_bone_global_pose(sk.find_bone("LeftUpLeg")).origin
		var f := sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin
		medida[0] = q.distance_to(f)
	sk.skeleton_updated.connect(ler)
	for i in 3:
		await process_frame
	sk.skeleton_updated.disconnect(ler)
	var repouso := (sk.get_bone_global_rest(sk.find_bone("LeftFoot")).origin - sk.get_bone_global_rest(sk.find_bone("LeftUpLeg")).origin).length()
	_ok("o pé cola na coxa (%.3f de %.3f de repouso)" % [medida[0], repouso], medida[0] >= 0.0 and medida[0] < repouso * 0.1)
	var cone := croc.find_child("Cone", true, false)
	var graos := croc.find_child("Graos", true, false)
	_ok("um cone de areia e grãos tomam o lugar das pernas", cone != null and cone.is_visible_in_tree() and graos != null)
	_ok("o cone nasce no quadril, abaixo dele (y local %.2f)" % (cone.position.y if cone != null else 0.0), cone != null and cone.position.y < 0.0)

	# INIMIGO: os dois atiram.
	var alvo := CharacterBody3D.new()
	var script := GDScript.new()
	script.source_code = FONTE_DO_ALVO
	script.reload()
	alvo.set_script(script)
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.height = 1.8
	forma.shape = capsula
	alvo.add_child(forma)
	alvo.add_to_group("enemy")
	current_scene.add_child(alvo)
	alvo.global_position = barco.global_position + Vector3(0, 3.0, -25)
	var vida_do_barco := float(barco.get("health"))
	var vida_do_jogador: float = p.health
	for i in 420:
		await physics_frame
	var golpes: Array = alvo.get("golpes")
	var balas := golpes.filter(func(g): return is_equal_approx(float(g), PistoleiroDeBordo.DANO))
	var laminas := golpes.filter(func(g): return float(g) > PistoleiroDeBordo.DANO + 1.0)
	_ok("o Barba Negra acertou o inimigo de pistola (%d balas de %.0f)" % [balas.size(), PistoleiroDeBordo.DANO], balas.size() >= 3)
	_ok("o Crocodile acertou a lâmina de areia (%d, dano %s)" % [laminas.size(), str(laminas.slice(0, 1))], laminas.size() >= 1)
	_ok("o dano da lâmina é o do Z da Suna na escala do aliado", laminas.size() > 0 and absf(float(laminas[0]) - 92.0 * VooDeAreia.ESCALA_DE_DANO) < 1.0)
	_ok("o barco não levou nem um tiro dos próprios aliados", is_equal_approx(float(barco.get("health")), vida_do_barco))
	_ok("o jogador também não", is_equal_approx(p.health, vida_do_jogador))

	# Inimigo longe demais (>45 m): nada.
	var antes := golpes.size()
	alvo.global_position = barco.global_position + Vector3(0, 3.0, -120)
	for i in 240:
		await physics_frame
	_ok("inimigo além do alcance (45 m) não leva tiro", (alvo.get("golpes") as Array).size() == antes)

	# Dispensar: tudo some.
	nav.sair(true)
	nav.dispensar_tripulacao()
	await physics_frame
	_ok("dispensar tira os três do barco", barco.find_child("Tripulante_*", true, false) == null)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nTRIPULANTES_DE_BORDO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _zarpar(ids: Array) -> void:
	p.global_position = barco.leme.global_position + Vector3.UP * 0.9
	p.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	await _tecla_toque(KEY_Y)
	var jan: JanelaDaTripulacao = hud.janela_da_tripulacao()
	jan.responder_sim()
	for i in ids.size():
		jan.colocar(i, str(ids[i]))
	jan.zarpar()
	for i in 5:
		await physics_frame


func _tecla_toque(codigo: Key) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = codigo
		ev.keycode = codigo
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
