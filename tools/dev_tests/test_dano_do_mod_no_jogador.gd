extends SceneTree
## REGRESSÃO (10/11/2026): "os inimigos aplicam empurrão mas a vida não diminui". O golpe de um personagem do mod chega como
## `damage_curse` grande; o mod o cancela e REAPLICA um dano menor dentro do evento. O filtro de invulnerabilidade de 0,5 s do
## Minecraft rodava ANTES e recusava o dano menor ("menor ou igual ao último"). Agora filtra o dano FINAL.
const MAPA := "user://test_dano_mod_jogador.json"
const SAVE := "user://test_dano_mod_jogador_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(64, 2, 64)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	m.get("progressao").fruta = "aro_aro"
	m.call("aplicar_progressao_ao_jogador") if m.has_method("aplicar_progressao_ao_jogador") else m.call("equipar_fruta", j, "aro_aro")
	await quadros(60)
	var jm = j.get_node_or_null("JogadorDoMod")
	ok(jm != null, "com a fruta do mod o jogador tem o JogadorDoMod (eventos do Forge)")
	if jm == null:
		print("test_dano_do_mod_no_jogador: sem JogadorDoMod — não deu para exercitar o pipeline"); quit(1); return
	# atacante do mod com jjkChara = true (o caso que zerava o dano)
	var atq := PersonagemMinePiece.new()
	atq.montar(DadosEastBlue.ficha("alvida"), "alvida")
	current_scene.add_child(atq)
	atq.global_position = j.global_position + Vector3(3, 0, 0)
	await quadros(30)
	var ent_atq := McEntidade.de(atq)
	var ent_jog := McEntidade.de(j)
	var fonte := McFonteDeDano.de(&"minepiece:damage_curse", ent_atq)
	j._vida.vida = j._vida.vida_max
	var v0: float = j.health
	ent_jog.hurt(fonte, 20.0)
	ok(j.health < v0, "golpe do mod (damage_curse 20) tira vida: %.2f -> %.2f" % [v0, j.health])
	# 10/11/2026: o golpe de criatura do mod chega ×3 (ESCALA_DO_GOLPE_DE_MOB); antes ~1, agora ~3–9 de 32 de vida
	ok(v0 - j.health >= 2.0, "o golpe do mod tira pelo menos 2 de vida (tirou %.2f)" % (v0 - j.health))
	# golpes seguidos, espaçados além da janela, continuam tirando
	var antes: float = j.health
	for i in 3:
		await quadros(40)
		ent_jog.hurt(fonte, 20.0)
	ok(j.health < antes, "golpes seguidos continuam tirando vida: %.2f -> %.2f" % [antes, j.health])
	# a invulnerabilidade de 0,5 s do Minecraft continua valendo para dano igual logo em seguida
	# (com o dano ×3 as pancadas acima podem ter matado o jogador: limpa a imunidade do respawn antes)
	await quadros(60)
	j.set_meta("damage_immune", false)
	j._vida.vida = j._vida.vida_max
	var kb: KnockbackMinecraft = j.knockback_minecraft
	kb.cancelar()
	for meta in ["autor_do_dano", "fonte_mc"]:      # sem autor do mod de golpes anteriores: dano direto, sem o pipeline do mod
		if j.has_meta(meta): j.remove_meta(meta)
	j.take_damage(6.0, Vector3(4, 0, 0))
	var depois1: float = j.health
	j.take_damage(6.0, Vector3(4, 0, 0))
	ok(is_equal_approx(j.health, depois1), "dano igual dentro de 0,5 s segue recusado (invulnerabilidade preservada)")
	j.take_damage(40.0, Vector3(4, 0, 0))
	ok(j.health < depois1, "dano maior dentro da janela tira só a diferença")
	print("test_dano_do_mod_no_jogador: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
