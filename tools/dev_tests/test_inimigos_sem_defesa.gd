extends SceneTree
## Decisão do dono (15/11/2026): inimigo não se defende; atirador nasce/atira mais longe; espadachim vai direto.
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c:
		falhas += 1

func rodar() -> void:
	await process_frame
	var Mc_ = load("res://src/minecraft/mc.gd")
	# 1. A IA do mod só ergue a guarda sem a tag `minepiece:no_guard`: na história todo tipo a tem.
	var tag = Mc_.estatico(&"TagKey", &"create", [Mc_.campo(&"Registries", &"ENTITY_TYPE"), Mc_.novo(&"ResourceLocation", ["minepiece:no_guard"])])
	ok(Mc_.tag_contem(tag, &"minepiece:mp_bandit"), "todo tipo de inimigo conta como `no_guard` (a IA do mod não guarda)")
	ok(Mc_.tag_contem("minepiece:outra_tag", &"minepiece:mp_bandit") == false, "outras tags seguem o arquivo (não viraram verdadeiras)")
	# 2. Cérebro de bandido: `defende` desligado por padrão.
	var cerebro = load("res://src/combat/direcional/cerebro_de_inimigo.gd").new()
	ok(cerebro.defende == false, "CerebroDeInimigo.defende é falso por padrão")
	cerebro.free()
	# 3. Espadachim vai direto (sem cerco) e o atirador fica mais longe.
	var Tat = load("res://src/historia/east_blue/tatica_de_missao.gd")
	ok(Tat.cercar_o_jogador == false, "espadachim não cerca nem defende por padrão (ataca direto)")
	ok(Tat.DISTANCIA_DO_POSTO.x >= 16.0, "o posto do atirador fica a %.0f m ou mais" % Tat.DISTANCIA_DO_POSTO.x)
	var Raid = load("res://src/historia/raid/raid.gd")
	ok(Raid.NASCER_ENTRE_ATIRADOR.x >= Raid.NASCER_ENTRE.y, "o atirador nasce depois de onde o espadachim termina (%s × %s)" % [Raid.NASCER_ENTRE_ATIRADOR, Raid.NASCER_ENTRE])
	# 4. O fuzil alcança 48 m: a procedure usada é a ajustada.
	ok(String(Mc_.proc(&"LogicRifleProcedure").resource_path).contains("ajustadas"), "LogicRifleProcedure é a ajustada (alcance 48 m)")
	print("===== %s =====" % ("TUDO OK" if falhas == 0 else "%d FALHA(S)" % falhas))
	quit(0 if falhas == 0 else 1)
