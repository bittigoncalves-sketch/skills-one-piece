extends SceneTree
## Chefes e capangas (08/11/2026): dano ×0,5; capanga = 5 golpes (desligado), COM XP desde 19/11/2026, derrubado por 3 s se o golpe passaria da vida; chefe persegue
## (missão = sempre; senão, metade da ilha depois de apanhar) e teleporta para desviar de projétil a cada 15 s.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_chefes_e_capangas.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _nascer(id: String, pos: Vector3) -> PersonagemMinePiece:
	var p := PersonagemMinePiece.new()
	p.montar(DadosEastBlue.ficha(id), "mp_" + id)
	p.position = pos
	p.ponto_de_origem = pos
	current_scene.add_child(p)
	return p

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_chefes_e_capangas.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var prog = current_scene.progressao

	print("-- dano de combate ×0,5 (só na campanha; o teste força o save, então liga na mão) --")
	ok(DanoDaHistoria.fator == 1.0, "teste com save forçado roda com o dano bruto (fator %.1f)" % DanoDaHistoria.fator)
	DanoDaHistoria.ligar_para(true)
	var alvo := _nascer("higuma", j.global_position + Vector3(0, 0, -30))
	alvo.max_health = 1000.0
	alvo.health = 1000.0
	CombatResolver.aplicar(alvo, 100.0, 0, 0.0, j.global_position)
	var tirou := 1000.0 - alvo.health
	DanoDaHistoria.ligar_para(false)
	var alvo2 := _nascer("higuma", j.global_position + Vector3(8, 0, -30))
	alvo2.max_health = 1000.0
	alvo2.health = 1000.0
	CombatResolver.aplicar(alvo2, 100.0, 0, 0.0, j.global_position)
	var tirou_bruto := 1000.0 - alvo2.health
	ok(tirou_bruto > 0.0 and absf(tirou - tirou_bruto * 0.5) < 0.01, "o dano que o jogador causa cai pela metade (%.2f contra %.2f)" % [tirou, tirou_bruto])
	var vida0: float = j.get("health") if j.get("health") != null else 0.0
	j.remove_meta("damage_immune")
	j._vida.vida = 100.0
	DanoDaHistoria.ligar_para(true)
	j.knockback_minecraft._resta = 0.0      # a janela de invulnerabilidade do Minecraft (0,5 s) só deixaria passar a diferença
	j.take_damage(10.0)
	var perdeu_meio: float = 100.0 - float(j.get("health"))
	DanoDaHistoria.ligar_para(false)
	j._vida.vida = 100.0
	j.knockback_minecraft._resta = 0.0
	j.take_damage(10.0)
	var perdeu_cheio: float = 100.0 - float(j.get("health"))
	ok(perdeu_cheio > 0.0 and absf(perdeu_meio - perdeu_cheio * DanoDaHistoria.FATOR_RECEBIDO_DA_CAMPANHA) < 0.01, "o dano que o jogador recebe segue o fator da campanha (%.2f contra %.2f bruto)" % [perdeu_meio, perdeu_cheio])
	j.set_meta("damage_immune", true)
	j._vida.vida = 100.0

	print("\n-- capanga: vida NORMAL (sem a regra dos 5 golpes, 13/11/2026), COM XP (19/11/2026) --")
	var bandido := _nascer("bandit", j.global_position + Vector3(0, 0, -40))
	var chefe_h := _nascer("higuma", j.global_position + Vector3(14, 0, -40))
	ok(bandido.capanga and not chefe_h.capanga, "o bandido é capanga; Higuma (chefe) não")
	ok(not PersonagemMinePiece.e_capanga(DadosEastBlue.ficha("zoro_east_blue")) and not PersonagemMinePiece.e_capanga(DadosEastBlue.ficha("benn_beckman")),
		"aliados e o bando do Shanks não são capangas")
	ok(not PersonagemMinePiece.CAPANGA_POR_GOLPES, "a regra dos 5 golpes está desligada")
	bandido.max_health = 100.0
	bandido.health = 100.0
	for i in 4:
		bandido.take_damage(10.0, j.global_position)
	ok(bandido.vivo() and bandido.health < 100.0 and bandido.health > 0.0 and not bandido.esta_caido(), "4 golpes: a vida cai pela conta normal (%.0f) e ele não é derrubado" % bandido.health)
	bandido.take_damage(100000.0, j.global_position)
	ok(not bandido.vivo(), "um golpe que passa da vida MATA (sem precisar de 5 golpes)")
	# Compara a RECOMPENSA TOTAL (nível + XP), não `prog.xp`: o XP zera ao subir de nível (1912 → 96 era uma subida, não ausência de XP) e o teto anti-farm
	# (`limite_de_recompensa`) pode cortar o ganho; o controle do chefe sobe o teto para medir só se o chefe paga.
	prog.limite_de_recompensa = maxf(prog.limite_de_recompensa, 1000000.0)      # sem o teto anti-farm: o teste mede se PAGA, não o teto
	var xp0: int = prog.recompensa_total()
	var ouro0: int = prog.ouro
	modo_ao_derrotar(current_scene, bandido)
	ok(prog.recompensa_total() > xp0, "capanga derrotado (marinheiro/pirata) dá XP (%d → %d)" % [xp0, prog.recompensa_total()])
	ok(prog.ouro - ouro0 == (prog.recompensa_total() - xp0) / 50, "e dá ouro: 1 moeda a cada 50 de XP (%d de XP → %d moedas)" % [prog.recompensa_total() - xp0, prog.ouro - ouro0])
	prog.limite_de_recompensa = maxf(prog.limite_de_recompensa, 1000000.0)
	xp0 = prog.recompensa_total()
	ouro0 = prog.ouro
	chefe_h.max_health = 100.0
	chefe_h.health = 100.0
	chefe_h.take_damage(100000.0, j.global_position)
	modo_ao_derrotar(current_scene, chefe_h)
	ok(prog.recompensa_total() > xp0, "controle: o chefe derrotado dá XP (%d → %d)" % [xp0, prog.recompensa_total()])
	ok(prog.ouro - ouro0 == (prog.recompensa_total() - xp0) / 50 and prog.ouro > ouro0, "chefe derrotado também dá ouro (%d XP → %d moedas)" % [prog.recompensa_total() - xp0, prog.ouro - ouro0])

	print("\n-- perseguição do chefe --")
	var boss := _nascer("higuma", j.global_position + Vector3(-20, 0, -40))
	var cer: CerebroMinePiece = boss.cerebro
	ok(is_equal_approx(cer.zona_de_perseguicao(), CerebroMinePiece.ZONA), "sem missão e sem dano: a zona de casa (%.0f m)" % cer.zona_de_perseguicao())
	cer.foi_atacado(j)
	ok(cer.zona_de_perseguicao() >= CerebroMinePiece.ZONA and cer.zona_de_perseguicao() < INF, "depois de apanhar: metade da ilha (%.0f m)" % cer.zona_de_perseguicao())
	# A missão de combate dos bandidos saiu em 20/11/2026: sem missão de combate no jogo, a regra "o chefe nunca desiste" fica latente (reativar com a primeira missão de combate nova).
	prog.missoes["bandidos"] = {"estado": "aceita", "abates": 0}
	ok(not prog.tem_missao_de_combate() and cer.zona_de_perseguicao() < INF, "entrada antiga de save ('bandidos') é ignorada: sem missão de combate, o chefe não persegue sem fim")
	prog.missoes.erase("bandidos")
	var comum := _nascer("bandit", j.global_position + Vector3(-30, 0, -40))
	comum.cerebro.foi_atacado(j)
	ok(is_equal_approx(comum.cerebro.zona_de_perseguicao(), CerebroMinePiece.ZONA), "mob comum não muda: segue a zona de casa")

	print("\n-- desvio de projétil (teleporte, 15 s) --")
	var chefe_d := _nascer("higuma", j.global_position + Vector3(0, 0.5, -20))      # dentro da zona: o cérebro não solta o alvo
	await quadros(5)
	chefe_d.cerebro.alvo = j
	var desvio: DesvioDeChefe = chefe_d.get_node("DesvioDeChefe")
	var antes := chefe_d.global_position
	_lancar(j, chefe_d, 40.0)
	await quadros(12)
	ok(desvio.desvios == 1 and chefe_d.global_position.distance_to(antes) > 3.0, "projétil a caminho: o chefe teleporta (%.1f m)" % chefe_d.global_position.distance_to(antes))
	ok(desvio.recarga > 14.0, "e fica %.0f s em recarga" % desvio.recarga)
	var chao := PhysicsRayQueryParameters3D.create(chefe_d.global_position + Vector3.UP * 0.5, chefe_d.global_position + Vector3.DOWN * 1.5, 1)
	chao.exclude = [chefe_d.get_rid()]
	ok(not chefe_d.get_world_3d().direct_space_state.intersect_ray(chao).is_empty(), "o destino tem chão sob os pés")
	_lancar(j, chefe_d, 40.0)
	await quadros(12)
	ok(desvio.desvios == 1 and desvio.recarga > 13.0, "dentro dos 15 s não desvia de novo (desvios %d, recarga %.1f s)" % [desvio.desvios, desvio.recarga])
	print("\nCHEFES_E_CAPANGAS %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)


func modo_ao_derrotar(cena: Node, p: PersonagemMinePiece) -> void:
	cena._ao_derrotar_personagem_east_blue(p)


## Um DamageZone do jogador a 12 m do chefe, voando na direção dele a `velocidade` m/s.
func _lancar(j: Node3D, chefe: Node3D, velocidade: float) -> void:
	var z := DamageZone.new()
	current_scene.add_child(z)
	var dir := (chefe.global_position + Vector3.UP * 0.9 - (chefe.global_position + Vector3(0, 0.9, 12.0))).normalized()
	z.setup(10.0, 1.0, dir * velocidade, 3.0, j, 0.4)
	z.global_position = chefe.global_position + Vector3(0, 0.9, 12.0)
