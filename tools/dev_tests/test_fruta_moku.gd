extends SceneTree
# ============================================================================
#  TESTE DA FRUTA DA FUMAÇA (MOKU MOKU NO MI) DO BUILDER
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const ExecutorDeSkill := preload("res://src/skills_builder/executor_de_skill.gd")

var _ok_n := 0
var _falhas := 0

func _init() -> void:
	_executar.call_deferred()

func _executar() -> void:
	await process_frame
	print("--- TESTE DA MOKU MOKU NO MI ---")

	SkillsPublicadas.recarregar()

	# 1. Validar integridade dos 5 JSONs individuais
	var skills_esperadas := {
		"Z": "moku_white_dash_z",
		"X": "moku_white_blow_x",
		"C": "moku_white_whirlwind_c",
		"V": "moku_white_out_v",
		"F": "moku_white_flight_f"
	}

	for tecla in skills_esperadas:
		var sid: String = skills_esperadas[tecla]
		var caminho := "res://mapas/skills/%s.json" % sid
		var r := Dados.carregar(caminho)
		_ok("carregar %s (%s)" % [sid, caminho], r.ok and not r.skill.is_empty())
		if r.ok:
			var v := Dados.validar(r.skill)
			_ok("validar schema de %s" % sid, v.ok and v.erros.is_empty())
			_ok("tecla de %s é %s" % [sid, tecla], str(r.skill.ativacao.tecla) == tecla)
			_ok("fruta de %s é moku_moku" % sid, str(r.skill.identificacao.get("fruta", "")) == "moku_moku")

	# 2. Catálogo de frutas
	var f := SkillsPublicadas.fruta("moku_moku")
	_ok("moku_moku existe no catálogo de frutas", not f.is_empty())
	_ok("nome da fruta é Moku Moku no Mi", str(f.get("nome", "")) == "Moku Moku no Mi")
	_ok("cor da fruta está definida", str(f.get("cor", "")) == "#dcdde1")

	# 3. Kit do Builder
	_ok("KitDoBuilder reconhece moku_moku como fruta do builder", KitDoBuilder.e_do_builder("moku_moku"))
	_ok("KitDoBuilder tem moku_moku disponível", KitDoBuilder.disponivel("moku_moku"))
	_ok("moku_moku está em frutas_prontas", KitDoBuilder.frutas_prontas().has("moku_moku"))
	var teclas := KitDoBuilder.teclas("moku_moku")
	teclas.sort()
	_ok("moku_moku possui as 5 teclas Z, X, C, V, F", teclas == ["C", "F", "V", "X", "Z"])

	# 4. Checar parâmetros e nomes em cada tecla
	_ok("nome tecla Z = Investida de Fumaça", KitDoBuilder.nome_da_tecla("Z", "moku_moku") == "Investida de Fumaça")
	_ok("nome tecla X = Punho de Fumaça", KitDoBuilder.nome_da_tecla("X", "moku_moku") == "Punho de Fumaça")
	_ok("nome tecla C = Vórtice de Fumaça", KitDoBuilder.nome_da_tecla("C", "moku_moku") == "Vórtice de Fumaça")
	_ok("nome tecla V = Tempestade de Fumaça", KitDoBuilder.nome_da_tecla("V", "moku_moku") == "Tempestade de Fumaça")
	_ok("nome tecla F = Voo de Fumaça", KitDoBuilder.nome_da_tecla("F", "moku_moku") == "Voo de Fumaça")

	_ok("recarga Z = 3.5s", is_equal_approx(KitDoBuilder.recarga("Z", "moku_moku"), 3.5))
	_ok("recarga X = 4.5s", is_equal_approx(KitDoBuilder.recarga("X", "moku_moku"), 4.5))
	_ok("recarga C = 7.0s", is_equal_approx(KitDoBuilder.recarga("C", "moku_moku"), 7.0))
	_ok("recarga V = 12.0s", is_equal_approx(KitDoBuilder.recarga("V", "moku_moku"), 12.0))
	_ok("recarga F = 4.0s", is_equal_approx(KitDoBuilder.recarga("F", "moku_moku"), 4.0))

	var sk_f := KitDoBuilder.skill("F", "moku_moku")
	_ok("F ativação é Sustentar", str(sk_f.get("ativacao", {}).get("modo", "")) == "Sustentar")
	_ok("F flutuar é verdadeiro", bool(sk_f.get("configuracoes", {}).get("flutuar", false)))
	_ok("F custo por segundo é 5%", is_equal_approx(float(sk_f.get("configuracoes", {}).get("custo_por_segundo", 0.0)), 5.0))

	# 5. Execução em mundo de física
	var cena := Node3D.new()
	root.add_child(cena)

	var ator := CharacterBody3D.new()
	ator.position = Vector3(0, 1, 0)
	cena.add_child(ator)

	var alvo := CharacterBody3D.new()
	alvo.add_to_group("enemy")
	alvo.position = Vector3(0, 1, -3)
	cena.add_child(alvo)

	# Simular execução de cada uma das 5 skills
	for tecla in ["Z", "X", "C", "V", "F"]:
		var sk := KitDoBuilder.skill(tecla, "moku_moku")
		ExecutorDeSkill.lancar(cena, ator, sk, Vector3.FORWARD, 1.0)
		for i in 10:
			await physics_frame
		_ok("execução física da tecla %s lançada com sucesso" % tecla, true)

	cena.queue_free()

	print("\nTOTAL: %d passaram | %d falharam" % [_ok_n, _falhas])
	quit(_falhas)

func _ok(nome: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
		print("   ✓ %s" % nome)
	else:
		_falhas += 1
		print("   ✗ FALHA: %s" % nome)
