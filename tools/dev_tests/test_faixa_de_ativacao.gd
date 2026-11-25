extends SceneTree
# ============================================================================
#  FAIXA DE ATIVAÇÃO DA IA DO MOD (04/11/2026; src/minecraft/ia_do_mod.gd; decisão do dono: "sim, conservadora").
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_faixa_de_ativacao.gd
#
#  Além de 80 m do jogador mais próximo e FORA de combate, a IA tica 1 vez em 6 (ideia do ServerCore). Aqui se prova os DOIS lados:
#    • o distante tica menos (≈ 1/6 dos 40 ticks de 120 quadros físicos);
#    • perto, chefe, com alvo, com revide, levado dano há pouco e com a chave desligada NÃO dormem (40 ticks).
# ============================================================================

const QUADROS := 120                 # 2 s = 40 ticks do mod a 20 Hz
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


## Quantos `um_tick` da IA rodaram em QUADROS quadros físicos (o cronômetro conta; só existe esse personagem na cena).
func ticks_em(n: int) -> int:
	Cronometro.ligado = true
	Cronometro.fechar_quadro()
	var soma := 0
	for i in n:
		await physics_frame
		var q := Cronometro.fechar_quadro()
		if q.has(&"IaDoMod.um_tick"):
			soma += int(q[&"IaDoMod.um_tick"][1])
	Cronometro.ligado = false
	return soma


func marinheiro(jogador: Node3D, distancia: float, chefe := false) -> PersonagemMinePiece:
	var ficha: Dictionary = DadosEastBlue.ficha("marine").duplicate(true)
	ficha["chefe"] = chefe
	var p := PersonagemMinePiece.new()
	p.montar(ficha, "mp_marine")
	p.position = jogador.global_position + Vector3(distancia, 0, 0)
	p.ponto_de_origem = p.position
	current_scene.add_child(p)
	return p


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_faixa_de_ativacao.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	ok(IaDoMod.faixa_de_ativacao, "a faixa de ativação começa ligada")
	ok(await ticks_em(30) == 0, "linha de base: sem personagem na cena, nenhum tick (o teste não mede lixo de outro)")

	# 1) perto: ativo, 40 ticks
	var perto := marinheiro(jogador, 20.0)
	await quadros(30)
	ok(perto.ia_do_mod != null and perto.ia_do_mod.tem_ia(), "o marinheiro tem IA do mod (pré-condição do teste)")
	var n_perto := await ticks_em(QUADROS)
	ok(n_perto >= 36, "perto (20 m): taxa cheia (%d de ~40 ticks)" % n_perto)
	ok(not perto.ia_do_mod._inativo, "perto: não está marcado como inativo")
	perto.queue_free()
	await quadros(5)

	# 2) longe e quieto: inativo, ~1/6
	var longe := marinheiro(jogador, 120.0)
	await quadros(30)
	var n_longe := await ticks_em(QUADROS)
	ok(longe.ia_do_mod._inativo, "longe (120 m) e fora de combate: marcado como inativo")
	ok(n_longe >= 3 and n_longe <= 12, "longe: tica ~1 em 6, não para (%d de ~40 ticks; esperado ~7)" % n_longe)

	# 3) a chave desligada devolve a taxa cheia
	IaDoMod.faixa_de_ativacao = false
	var n_chave := await ticks_em(QUADROS)
	ok(n_chave >= 36, "chave desligada: o distante volta à taxa cheia (%d)" % n_chave)
	IaDoMod.faixa_de_ativacao = true

	# 4) levou dano: acorda
	longe.ia_do_mod.ao_receber_dano(1.0, jogador)
	var n_dano := await ticks_em(QUADROS)
	ok(n_dano >= 36, "levou dano: acorda e fica em taxa cheia (%d)" % n_dano)
	longe.ia_do_mod._acordado_ate_ms = 0                         # o tempo de dano já passou
	await quadros(10)
	ok(longe.ia_do_mod._inativo, "passado o tempo, volta a ficar inativo")

	# 5) em combate: a decisão é testada NO INSTANTE em que o alvo existe (o cérebro limpa um alvo fora do alcance a cada 0,5 s,
	#    e um jogador a 120 m está fora). Sem alvo e sem revide o personagem está fora da faixa; com qualquer um, não.
	ok(longe.ia_do_mod._fora_da_faixa(), "sem alvo nem revide: está fora da faixa (pré-condição)")
	longe.cerebro.alvo = jogador
	ok(not longe.ia_do_mod._fora_da_faixa(), "com alvo: NÃO está fora da faixa (em combate fica ativo)")
	longe.cerebro.alvo = null
	longe.cerebro.foi_atacado(jogador)
	ok(not longe.ia_do_mod._fora_da_faixa(), "com revide (foi atacado): NÃO está fora da faixa")
	longe.cerebro.reiniciar()
	await quadros(2)
	ok(longe.ia_do_mod._fora_da_faixa(), "sem alvo e sem revide de novo: volta a estar fora da faixa")
	longe.queue_free()
	await quadros(5)

	# 6) chefe: nunca dorme
	var chefe := marinheiro(jogador, 120.0, true)
	await quadros(30)
	var n_chefe := await ticks_em(QUADROS)
	ok(n_chefe >= 36 and not chefe.ia_do_mod._inativo, "chefe longe: nunca dorme (%d)" % n_chefe)
	chefe.queue_free()

	print("\n%d/%d" % [total - falhas, total])
	if falhas > 0:
		print("===== %d FALHA(S) =====" % falhas)
	quit(1 if falhas > 0 else 0)
