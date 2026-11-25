extends SceneTree
## História real + população real para a seleção; controles públicos nas bordas.
## Progresso isolado. Execute em série com os outros testes (porta 24565).
const ID := "harpia_-_animated_low_poly"
const HARPIA := "res://src/historia/bosses/harpia/harpia_da_ilha.gd"
var falhas := 0
var j: CharacterBody3D
var bib: BibliotecaDeModelos
var modo: GDScript

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, texto: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + texto)
	if not cond: falhas += 1

func quadros(n: int) -> void:
	for i in n: await physics_frame

func rodar() -> void:
	seed(20261004)
	modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://test_harpia_investida.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	bib = MapaMontador.biblioteca_em_uso()
	if j == null:
		ok(false, "história oferece jogador real")
		terminar(); return
	await selecao_real()
	await borda("imune")
	await borda("esquiva")
	await borda("parede")
	await borda("cancelamento")
	await morte_e_retorno()
	terminar()

func terminar() -> void:
	modo.mapa_forcado = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	modo.progresso_forcado = ""
	print("HARPIA_INVESTIDA_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)

func preparar_jogador() -> void:
	j.net_force_respawn()
	await quadros(8)
	j.global_position = Vector3(0, .9, 0)
	j.velocity = Vector3.ZERO
	j.remove_meta("damage_immune")
	await quadros(4)

func area() -> Dictionary:
	return {"id": "harpia_teste", "especie": ID, "quantidade": 1,
		"centro": Vector3.ZERO, "meio": Vector3(70, 40, 70), "base": Basis.IDENTITY,
		"ficha": bib.ficha_de_animal(ID)}

func novo_boss() -> AnimalDaIlha:
	var b: AnimalDaIlha = load(HARPIA).new()
	b.montar(bib, ID, bib.ficha_de_animal(ID), area())
	b.position = Vector3(0, 10, -15)
	b.ponto_de_origem = b.position
	current_scene.add_child(b)
	# Só os cenários auxiliares fornecem alvo diretamente ao comando público.
	# A seleção automática é coberta separadamente pela população de produção.
	return b

func selecao_real() -> void:
	await preparar_jogador()
	var pop := PopulacaoDeAnimais.new()
	current_scene.add_child(pop)
	pop.definir_jogador(j)
	pop.ligar(current_scene, {"pecas": [{"id": "harpia_probe", "tipo": "area_animais",
		"especie": ID, "quantidade": 1, "posicao": Vector3.ZERO,
		"tamanho": Vector3(32, 30, 32), "rotacao_graus": Vector3.ZERO}]}, bib)
	await quadros(3)
	ok(pop.animais.size() == 1, "população instancia a Harpia do catálogo")
	if pop.animais.is_empty():
		pop.queue_free(); return
	var b: AnimalDaIlha = pop.animais[0]
	ok(b.get_script().resource_path == HARPIA, "modelo Harpia recebe controlador específico pela população")
	if b.get("combate") == null:
		pop.queue_free(); return
	var c: Node = b.get("combate")
	var hp: float = j.health
	var perdas := 0
	var viu_preparo := false
	var viu_avanco := false
	var viu_arremesso := false
	var origem := j.global_position
	var afastamento := 0.0
	var retirou_boss := false
	for i in 420:
		await physics_frame
		if is_instance_valid(c) and str(c.habilidade) == "investida":
			viu_preparo = viu_preparo or "prepar" in str(c.fase)
			viu_avanco = viu_avanco or str(c.fase) in ["investida"]
		if not retirou_boss and perdas > 0 and is_instance_valid(c) and str(c.fase).is_empty():
			pop.queue_free()
			retirou_boss = true
		if j.health < hp - .001: perdas += 1
		hp = j.health
		viu_arremesso = viu_arremesso or j.esta_arremessado()
		afastamento = maxf(afastamento, Vector2(j.position.x - origem.x, j.position.z - origem.z).length())
		if perdas > 0 and not j.esta_arremessado(): break
	ok(viu_preparo, "IA anuncia a investida antes de avançar")
	ok(viu_avanco, "IA entra no avanço da investida")
	ok(perdas == 1, "uma conjuração desconta vida uma única vez (%d perdas)" % perdas)
	ok(viu_arremesso and afastamento > 6, "arremesso real afasta o jogador %.2f m e usa PlayerArremesso" % afastamento)
	ok(not j.esta_arremessado() and j.corpo_livre_para_golpe(), "jogador recupera controle após queda")
	if is_instance_valid(c): c.cancelar()
	if is_instance_valid(pop): pop.queue_free()
	await quadros(3)

func borda(caso: String) -> void:
	await preparar_jogador()
	var b := novo_boss()
	var c: Node = b.get("combate")
	var parede: StaticBody3D
	if caso == "imune": j.set_meta("damage_immune", true)
	if caso == "parede":
		parede = StaticBody3D.new()
		var col := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = Vector3(16, 20, .6)
		col.shape = forma
		parede.add_child(col)
		parede.position = Vector3(0, 10, -7)
	await quadros(2)
	var hp: float = j.health
	ok(c.iniciar_investida(j), "comando inicia cenário " + caso)
	await quadros(44)
	if caso == "parede": current_scene.add_child(parede)
	if caso == "esquiva":
		# Atravessar lateralmente a linha após fixação; não altera a IA.
		j.global_position.x = 9
	if caso == "cancelamento": c.cancelar()
	var maior_z := b.position.z
	var arremessou := false
	for i in 170:
		await physics_frame
		maior_z = maxf(maior_z, b.position.z)
		arremessou = arremessou or j.esta_arremessado()
	ok(is_equal_approx(float(j.health), hp) and not arremessou, caso + ": sem dano nem arremesso indevido")
	ok(b.global_position.is_finite(), caso + ": movimento finito")
	if caso == "parede": ok(maior_z < -6.7, "parede encerra avanço sem atravessar (z máximo %.2f)" % maior_z)
	c.cancelar()
	b.queue_free()
	if parede: parede.queue_free()
	j.remove_meta("damage_immune")
	await quadros(3)

func morte_e_retorno() -> void:
	await preparar_jogador()
	var b := novo_boss()
	var c: Node = b.get("combate")
	ok(c.iniciar_investida(j), "prepara ataque antes da morte")
	await quadros(20)
	b.take_damage(b.max_health + 1.0, j.global_position)
	await quadros(70)
	ok(not b.vivo() and not j.esta_arremessado(), "morte da Harpia interrompe ataque sem impacto atrasado")
	b.reviver(Vector3(0, 10, -15))
	await quadros(2)
	ok(b.vivo() and not b.has_meta("captura_vento"), "reviver conserva ciclo de vida sem vínculo de captura")
	c.cancelar()
	b.queue_free()
	await quadros(3)
