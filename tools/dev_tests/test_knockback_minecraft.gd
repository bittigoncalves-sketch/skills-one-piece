extends SceneTree
# ============================================================================
#  KNOCKBACK NO ESTILO MINECRAFT (23/10/2026, src/player/knockback_minecraft.gd) — o
#  jogador do Modo História apanhando de verdade (`take_damage`):
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_knockback_minecraft.gd
#
#    • pulinho de ~1 bloco e empurrão para LONGE de quem bateu (~2–3 m), já no quadro
#      seguinte (sem a pausa de impacto que congelava e apagava o pulinho);
#    • 0,5 s invulnerável: o mesmo golpe não entra; um maior tira só a diferença e não
#      empurra; passada a janela, entra inteiro de novo;
#    • o som de recepção de dano do jogador toca.
# ============================================================================

const SOM := "res://assets/audio/dano_do_jogador.wav"

var p: CharacterBody3D           # sem `Player`: tipar compila o Player antes dos autoloads
var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func sons() -> int:
	var n := 0
	for f in current_scene.get_children():
		if f is AudioStreamPlayer3D and f.stream != null and f.stream.resource_path == SOM:
			n += 1
	return n


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_knockback_minecraft.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	ok(p.knockback_minecraft != null, "o Modo História instala o knockback Minecraft no jogador")
	# Vida baixa: a regeneração é 0,5 % do máximo por segundo e devolveria o dano medido.
	p._vida.vida_max = 200.0
	p._vida.vida = 200.0
	await quadros(30)

	print("\n-- empurrão e pulinho --")
	var inicio := p.global_position
	var atacante := inicio + Vector3(0, 0, -1.5)            # bate pela frente (−z): vai para +z
	var sons_antes := sons()
	var vida0: float = p._vida.vida
	p.take_damage(4.0, atacante, Vector3(0, 0, 3.0), 0.3)
	var tirou0: float = vida0 - p._vida.vida
	await quadros(2)
	ok(p.global_position.distance_to(inicio) > 0.05, "começa a voar já no 2º quadro (%.2f m)" % p.global_position.distance_to(inicio))
	ok(sons() > sons_antes, "tocou o som de recepção de dano do jogador")
	var pico := 0.0
	for i in 60:
		await physics_frame
		pico = maxf(pico, p.global_position.y - inicio.y)
	var fim := p.global_position
	var ida := fim - inicio
	ok(absf(pico - KnockbackMinecraft.ALTURA_DO_PULINHO) < 0.2, "pulinho de ~1 bloco (%.2f m)" % pico)
	ok(ida.z > 1.8 and ida.z < 3.2 and absf(ida.x) < 0.2, "empurrado para longe de quem bateu (z +%.2f m, x %.2f)" % [ida.z, ida.x])
	ok(p.is_on_floor(), "pousou de novo")
	ok(tirou0 > 0.0, "o golpe tirou vida (%.1f)" % tirou0)

	print("\n-- invulnerável por 0,5 s --")
	atacante = p.global_position + Vector3(0, 0, -1.5)
	p.take_damage(4.0, atacante, Vector3(0, 0, 3.0), 0.3)  # abre a janela
	await quadros(1)
	var vida1: float = p._vida.vida
	p.take_damage(4.0, atacante, Vector3(0, 0, 3.0), 0.3)
	var tirou_igual: float = vida1 - p._vida.vida
	await quadros(5)
	vida1 = p._vida.vida
	p.take_damage(10.0, atacante, Vector3(0, 0, 3.0), 0.3)
	var tirou_maior: float = vida1 - p._vida.vida
	ok(tirou_igual == 0.0,
		"golpe igual dentro da janela não entra (tirou %.1f)" % tirou_igual)
	# 4 → 10 dentro da janela: entra a diferença (6, menos a armadura). Sem empurrão.
	ok(tirou_maior > 0.0 and tirou_maior < 10.0, "golpe maior dentro da janela tira só a diferença (%.1f)" % tirou_maior)
	await quadros(40)                                       # > 0,5 s desde o 1º golpe
	var vida2: float = p._vida.vida
	var pos2 := p.global_position
	p.take_damage(4.0, pos2 + Vector3(-1.5, 0, 0), Vector3(3.0, 0, 0), 0.3)
	var tirou2: float = vida2 - p._vida.vida
	await quadros(30)
	ok(is_equal_approx(tirou2, tirou0) and p.global_position.x - pos2.x > 1.5,
		"passada a janela, entra inteiro e empurra de novo (tirou %.1f = %.1f, x +%.2f m)" % [tirou2, tirou0, p.global_position.x - pos2.x])

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
