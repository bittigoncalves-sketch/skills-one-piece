extends SceneTree
## GORILA-REI (22/11/2026): a luta de verdade, no Modo História com a população real da carga.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_gorila_rei.gd
## Prova: cada golpe MOSTRA a área vermelha e só fere quem está DENTRO dela (dentro vs fora, mesma geometria do desenho); nada fere antes do contato;
## fase 2 entra abaixo de 55 % da vida; morte e reinício. NÃO prova a vista (foto) nem a sensação de jogar.
const ID := "gorila_rei"
const CLASSE := "res://src/historia/bosses/gorila_rei/gorila_rei_da_ilha.gd"
var falhas := 0
var j: CharacterBody3D
var bib: BibliotecaDeModelos
var modo: GDScript
const Aviso := preload("res://src/historia/bosses/gorila_rei/aviso_vermelho.gd")
var boss: AnimalDaIlha


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, texto: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + texto)
	if not cond:
		falhas += 1


func vida() -> float:
	return float(j.get("health"))


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	seed(22112026)
	modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://test_gorila_rei.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	bib = MapaMontador.biblioteca_em_uso()
	if j == null:
		ok(false, "história oferece jogador real")
		terminar()
		return
	ok(bib.tem(ID) and not bib.ficha_de_animal(ID).is_empty(), "o Gorila-rei está no catálogo com ficha")
	var ficha := bib.ficha_de_animal(ID)
	ok(bool(ficha.get("boss", false)) and float(ficha.get("vida", 0.0)) >= 1000.0, "ficha de chefe com vida alta (%d)" % int(ficha.get("vida", 0.0)))
	await criar_boss()
	ok(boss.combate != null and boss.combate._ap != null, "tem cérebro de golpes e o AnimationPlayer do GLB")
	var ap: AnimationPlayer = boss.combate._ap
	var faltam: PackedStringArray = []
	for c in ["idle", "walk", "run", "hurt", "roar", "furia", "soco_chao", "pulo_esmagar", "investida", "giro", "arremesso", "morte"]:
		if not ap.has_animation(c):
			faltam.append(c)
	ok(faltam.is_empty(), "os 12 clipes do Blender estão no modelo %s" % str(faltam))
	await golpe("soco_chao", func() -> Vector3: return boss.global_position + boss.combate._frente() * 4.2, func() -> Vector3: return boss.global_position + boss.combate._frente() * 14.0)
	await golpe("giro", func() -> Vector3: return boss.global_position + Vector3(3.0, 0, 0), func() -> Vector3: return boss.global_position + Vector3(0, 0, 13.0))
	await golpe("arremesso", func() -> Vector3: return j.global_position, func() -> Vector3: return j.global_position + Vector3(-10, 0, 0), true)
	await golpe("pulo_esmagar", func() -> Vector3: return j.global_position, func() -> Vector3: return j.global_position + Vector3(-9, 0, 0), true)
	await golpe("investida", func() -> Vector3: return boss.global_position + boss.combate._frente() * 8.0, func() -> Vector3: return boss.global_position + boss.combate._frente() * 8.0 + Vector3(9.0, 0, 0))
	await fase_2_e_morte()
	terminar()


func terminar() -> void:
	modo.mapa_forcado = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	modo.progresso_forcado = ""
	print("GORILA_REI_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)


func area() -> Dictionary:
	return {"id": "gorila_teste", "especie": ID, "quantidade": 1, "centro": Vector3(0, 0, -10), "meio": Vector3(60, 30, 60),
		"base": Basis.IDENTITY, "ficha": bib.ficha_de_animal(ID)}


func criar_boss() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = load(CLASSE).new()
	boss.montar(bib, ID, bib.ficha_de_animal(ID), area())
	boss.position = Vector3(0, 1.0, -22)
	boss.ponto_de_origem = boss.position
	current_scene.add_child(boss)
	boss._yaw = 0.0
	boss._visual.rotation.y = 0.0
	await quadros(6)


func preparar_jogador(onde: Vector3) -> void:
	j.net_force_respawn()
	await quadros(40)           # o respawn termina (e reajusta a vida) alguns quadros depois
	j.global_position = onde + Vector3.UP * 0.9
	j.velocity = Vector3.ZERO
	j.remove_meta("damage_immune")
	# Vida alta para não morrer (a morte dispara o respawn, que teletransporta o jogador no meio do teste); o dano medido é a diferença.
	j.max_health = 1000.0
	j.health = 1000.0
	if j.has_meta("mc_inv_ate"):
		j.remove_meta("mc_inv_ate")
	await quadros(4)


## Um golpe com o jogador DENTRO da área (deve apanhar) e FORA (não deve). `dentro_em`/`fora_em` dão o ponto (do mundo) em que o jogador fica.
## `no_alvo`: o golpe mira o jogador (a área nasce onde ele está); o jogador dentro é o que NÃO se mexe, o de fora é o que corre depois do aviso travar.
func golpe(nome: String, dentro_em: Callable, fora_em: Callable, no_alvo := false) -> void:
	print("— %s" % nome)
	await criar_boss()
	boss.combate._intervalo = 0.0
	await preparar_jogador(Vector3(0, 0, 0) if no_alvo else boss.global_position + Vector3(0, 0, 3.0))
	var antes := vida()
	boss.combate.iniciar(nome, j)
	await quadros(4)
	var aviso: Node3D = boss.combate._aviso
	ok(aviso.visible, "%s: a área vermelha aparece no aviso" % nome)
	ok(vida() >= antes, "%s: nada fere durante o aviso (%.1f → %.1f)" % [nome, antes, vida()])
	# ainda no aviso, a ~40 %: mede a vida de novo
	var dur: float = boss.combate._duracao_do_aviso()
	await quadros(int(dur * 60.0 * 0.4))
	ok(vida() >= antes, "%s: segue sem ferir a 40 %% do aviso" % nome)
	if no_alvo:
		# a mira trava a 65 %: o jogador fica parado DENTRO e leva; num segundo teste foge depois de travar.
		pass
	else:
		await posicionar(dentro_em.call())
	if OS.get_environment("GORILA_DEBUG") == "1":
		print("   [dbg] %s antes: jogador=%s boss=%s" % [nome, str(j.global_position), str(boss.global_position)])
	var dano_dentro: float = await esperar_fim(nome)
	ok(dano_dentro > 0.0, "%s: quem fica DENTRO da área apanha (dano %.1f)" % [nome, dano_dentro])
	# FORA: mesmo golpe, o jogador sai da área depois de a mira travar
	await criar_boss()
	boss.combate._intervalo = 0.0
	await preparar_jogador(Vector3(0, 0, 0) if no_alvo else boss.global_position + Vector3(0, 0, 3.0))
	boss.combate.iniciar(nome, j)
	await quadros(int(boss.combate._duracao_do_aviso() * 60.0 * 0.75))      # já travou (65 %)
	await posicionar(fora_em.call())
	var dano_fora: float = await esperar_fim(nome)
	ok(dano_fora <= 0.0, "%s: quem sai da área mostrada NÃO apanha (dano %.1f)" % [nome, dano_fora])


func posicionar(p: Vector3) -> void:
	j.global_position = Vector3(p.x, 0.9, p.z)
	j.velocity = Vector3.ZERO
	await quadros(1)


## Espera o golpe chegar à recuperação (e, no arremesso, a pedra cair). Devolve o DANO total tomado: a vida é recolocada em 1000 a cada quadro,
## porque o Modo História reajusta a vida máxima do jogador de tempos em tempos (24 no nível 1) e isso escondia o dano.
func esperar_fim(nome: String) -> float:
	var dano := 0.0
	var extra := 70 if nome == "arremesso" else 4
	var restante := -1
	j.max_health = 1000.0
	j.health = 1000.0
	for i in 900:
		await physics_frame
		if OS.get_environment("GORILA_DEBUG") == "1" and vida() < 1000.0:
			print("   [dbg] quadro %d: vida=%.1f golpe=%s etapa=%s jogador=%s boss=%s" % [i, vida(), boss.combate.golpe, boss.combate.etapa, str(j.global_position), str(boss.global_position)])
		if float(j.get("max_health")) == 1000.0:           # senão foi o reajuste da vida máxima pelo Modo História, não um golpe
			dano += maxf(1000.0 - vida(), 0.0)
		j.max_health = 1000.0
		j.health = 1000.0
		if restante < 0 and (boss.combate.golpe != nome or boss.combate.etapa == "recuperacao"):
			restante = extra
		if restante >= 0:
			restante -= 1
			if restante < 0:
				break
	return dano


func fase_2_e_morte() -> void:
	print("— fase 2 e morte")
	await criar_boss()
	await preparar_jogador(Vector3(0, 0, 0))
	boss.estado = AnimalDaIlha.Estado.PERSEGUINDO
	boss.oponente = j
	var src := GDScript.new()
	src.source_code = "extends Node3D\nvar id_personagem := \"macaco_humanoide\"\n"
	src.reload()
	var perto := Node3D.new()
	perto.set_script(src)
	perto.add_to_group("enemy")
	current_scene.add_child(perto)
	perto.global_position = boss.global_position + Vector3(20, 0, 0)
	var longe := Node3D.new()
	longe.set_script(src)
	longe.add_to_group("enemy")
	current_scene.add_child(longe)
	longe.global_position = boss.global_position + Vector3(200, 0, 0)
	ok(boss.combate.fase_da_luta == 1, "começa na fase 1")
	boss.health = boss.max_health * 0.5
	await quadros(4)
	ok(boss.combate.fase_da_luta == 2 and boss.combate.golpe == "furia", "abaixo de 55 %% da vida entra na fase 2 com a FÚRIA (golpe=%s)" % boss.combate.golpe)
	ok(boss.combate._aviso.visible and boss.combate._aviso.forma == Aviso.Forma.ANEL and boss.combate._aviso.raio >= 9.0, "a fúria mostra o anel vermelho grande (raio %.1f)" % boss.combate._aviso.raio)
	var olhos: Array = boss._modelo.find_children("Olhos*", "MeshInstance3D", true, false)
	ok(not olhos.is_empty() and (olhos[0] as MeshInstance3D).material_override != null, "na fúria os olhos acendem em vermelho")
	await esperar_fim("furia")
	ok(perto.has_meta("ia_acordada_ate_ms"), "o rugido acordou o macaco a 20 m")
	ok(not longe.has_meta("ia_acordada_ate_ms"), "e não o macaco a 200 m")
	ok(boss.combate._aviso_do(1.0) < 1.0, "na fase 2 o aviso é mais curto (×%.2f)" % boss.combate._aviso_do(1.0))
	boss.health = 1.0                  # a última barra (o chefe tem 10 barras: `VidaEmBarras` limita cada golpe a uma barra)
	boss.take_damage(500.0, j.global_position)
	await quadros(6)
	ok(boss.estado == AnimalDaIlha.Estado.MORTO and not boss.combate._aviso.visible, "morre: o aviso some e o cérebro para (estado=%d, vida=%.0f, aviso=%s)" % [boss.estado, boss.health, str(boss.combate._aviso.visible)])
	boss.reviver(Vector3(0, 1.0, -22))
	await quadros(4)
	ok(boss.vivo() and boss.combate.fase_da_luta == 1 and boss.combate.golpe.is_empty(), "reviver: fase 1 de novo e sem golpe em curso")
	var olhos2: Array = boss._modelo.find_children("Olhos*", "MeshInstance3D", true, false)
	ok(olhos2.is_empty() or (olhos2[0] as MeshInstance3D).material_override == null, "reviver: olhos voltam ao normal")
