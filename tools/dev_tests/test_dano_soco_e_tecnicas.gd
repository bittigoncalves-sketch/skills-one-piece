extends SceneTree
# ============================================================================
#  SOCO −50 %, TÉCNICAS +50 % NO MODO HISTÓRIA (23/10/2026, `Balance.HISTORIA_*`):
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_dano_soco_e_tecnicas.gd
#
#    • o boxe do jogador sai com metade (o estilo é o mesmo dos inimigos: eles não mudam);
#    • técnica de fruta da história: escala do perfil × TECNICAS; soco do Mine Piece: × 0,5;
#    • a Rocket (dano escrito na técnica) também × TECNICAS; a arena (sem perfil) fica × 1.
# ============================================================================

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


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_dano_soco_e_tecnicas.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p: CharacterBody3D = get_first_node_in_group("player")

	print("\n-- soco (boxe) --")
	var ex = p.get("combate_direcional")
	ok(ex != null and is_equal_approx(ex.multiplicador_desarmado, 0.5) and is_equal_approx(ex.multiplicador_de_dano, 1.0),
		"boxe do jogador × %.2f; a espada/machado (outro estilo) × 1" % (ex.multiplicador_desarmado if ex else -1.0))
	ok(Balance.HISTORIA_SOCO == 0.5 and Balance.HISTORIA_TECNICAS == 2.0 and Balance.HISTORIA_TECNICAS_ESTILO_BASE == 1.5, "tabela: soco 0,5, frutas 2,0, estilo base 1,5 (22/11/2026)")

	print("\n-- técnicas e soco do Mine Piece --")
	var perfil := PerfilDeFrutas.da_arena("gomu_gomu")
	p.set("perfil_de_frutas", perfil)
	var e: float = PerfilDeFrutas.ESCALA_DA_ARENA
	ok(is_equal_approx(p.escala_de_dano_da_fruta("gomu_gomu"), e * Balance.HISTORIA_TECNICAS), "técnica: escala %.4f = %.4f × TECNICAS" % [p.escala_de_dano_da_fruta("gomu_gomu"), e])
	ok(is_equal_approx(p.escala_de_dano_da_fruta("gomu_gomu", false), e * 0.5), "soco do Mine Piece: escala × 0,5")
	ok(is_equal_approx(perfil.escala_das_tecnicas(), e * Balance.HISTORIA_TECNICAS), "perfil.escala_das_tecnicas() (Mine Piece/Goro)")
	# (30/10/2026) A Luta é NATIVA (`luta.gd`, `test_luta_nativa`): o kit do Builder não tem mais "socos importados".
	var spec := Balance.novo("gomu_gomu", "Z", p.escala_de_dano_da_fruta("gomu_gomu"))
	var arena := Balance.novo("gomu_gomu", "Z")
	ok(spec != null and arena != null and is_equal_approx(spec.dano, arena.dano * e * Balance.HISTORIA_TECNICAS),
		"Z da Gomu na história: %.1f (arena %.1f × %.4f × TECNICAS)" % [spec.dano if spec else -1.0, arena.dano if arena else -1.0, e])
	print("\n-- TODAS as frutas: x2,0; estilo base (kit do Builder) fica x1,5 --")
	var ids: Array[String] = PerfilDeFrutas.frutas_da_arena()
	var erradas: Array[String] = []
	for id in ids:
		var pf := PerfilDeFrutas.da_arena(id)
		if pf == null:
			continue
		var esperado: float = pf.escala_de_dano * (1.0 if id in Balance.HISTORIA_SEM_BONUS_DE_TECNICA else 2.0)
		if not is_equal_approx(pf.escala_das_tecnicas(), esperado):
			erradas.append(id)
		p.set("perfil_de_frutas", pf)
		for slot in ["Z", "X", "C", "V"]:
			if id in Balance.HISTORIA_SEM_BONUS_DE_TECNICA:
				continue          # a Magu tem tabela própria na história (`MAGU_HISTORIA`): só a escala é conferida, acima
			var sp := Balance.novo(id, slot, p.escala_de_dano_da_fruta(id))
			var ar := Balance.novo(id, slot)
			if sp != null and ar != null and not is_equal_approx(sp.dano, ar.dano * esperado):
				erradas.append("%s/%s" % [id, slot])
	ok(erradas.is_empty() and ids.size() > 10, "%d frutas da arena: técnica = arena x escala x 2,0 (Magu sem bônus); fora do padrão: %s" % [ids.size(), erradas])
	var base := PerfilDeFrutas.new()
	base.fruta = KitDoBuilder.ID
	base.escala_de_dano = PerfilDeFrutas.ESCALA_DA_ARENA
	ok(is_equal_approx(base.escala_das_tecnicas(), PerfilDeFrutas.ESCALA_DA_ARENA * 1.5), "estilo base (kit_builder): x1,5, não sobe com as frutas")
	p.set("perfil_de_frutas", base)
	ok(is_equal_approx(p.escala_de_dano_da_fruta(KitDoBuilder.ID), PerfilDeFrutas.ESCALA_DA_ARENA * 1.5), "Player aplica x1,5 ao estilo base")
	p.set("perfil_de_frutas", perfil)
	var magu := PerfilDeFrutas.da_arena("magu_magu")
	ok(is_equal_approx(magu.escala_das_tecnicas(), e), "Magu fora do +50 %% (dano próprio da história): × %.4f" % magu.escala_das_tecnicas())
	# Fruta importada do Mine Piece: o mod manda, sem fator da história (A4/A5 da auditoria).
	var mod := PerfilDeFrutas.new()
	mod.fruta = "pika_pika_mine_piece"
	mod.escala_de_dano = PerfilDeFrutas.ESCALA_DO_MOD
	mod.fiel_ao_mod = true
	p.set("perfil_de_frutas", mod)
	ok(is_equal_approx(p.escala_de_dano_da_fruta("pika_pika_mine_piece"), PerfilDeFrutas.ESCALA_DO_MOD)
		and is_equal_approx(p.escala_de_dano_da_fruta("pika_pika_mine_piece", false), PerfilDeFrutas.ESCALA_DO_MOD),
		"fruta do mod: técnica e soco só × ESCALA_DO_MOD (sem 1,5 nem 0,5)")
	ok(is_equal_approx(PerfilDeFrutas.ESCALA_DO_MOD * 10.0, 1.0), "dano do mod × 10 (formato interno) × ESCALA_DO_MOD = dano do mod")
	for id in ["pika_pika_mine_piece", "hie_hie_mine_piece", "moku_moku_mine_piece", "ope_ope_mine_piece"]:
		var pf := CatalogoFrutasMinePiece.perfil(id)
		if pf != null:
			ok(pf.fiel_ao_mod and is_equal_approx(pf.escala_das_tecnicas(), PerfilDeFrutas.ESCALA_DO_MOD), "perfil real de %s é fiel ao mod" % id)
	p.set("perfil_de_frutas", null)
	ok(is_equal_approx(p.escala_de_dano_da_fruta("gomu_gomu"), 1.0), "sem perfil (arena): × 1")

	print("\n-- Rocket (dano na técnica) --")
	var rocket := load("res://src/historia/frutas/rocket.tres") as PerfilDeFrutas
	var t := rocket.tecnica("Z")
	var rc = load("res://src/combat/rocket_controller.gd").new()
	rc.set("_tecnica", t)
	var s_r: DamageSpec = rc.call("_nova_spec", "Z")
	ok(t != null and is_equal_approx(s_r.dano, t.dano * Balance.HISTORIA_TECNICAS), "Z da Rocket: %.1f = %.1f × TECNICAS" % [s_r.dano, t.dano if t else -1.0])
	if rc is Node:
		rc.free()

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
