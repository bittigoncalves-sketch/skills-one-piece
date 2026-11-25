extends SceneTree
# ============================================================================
#  FRUTA DA ARENA RECONSTRUÍDA NO BUILDER — o Builder por TECLA (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_fruta_reconstruida.gd
#
#  Pedido do dono: "reconstrução da pika pika no mi através do editor com exceção do V".
#  Decisão: o Z/X/C publicados no Builder substituem os da `pika_pika`, o V segue o
#  código. Aqui, com uma skill de TESTE na Z (pasta de teste, nunca `res://mapas/skills`):
#  catálogo, regra por tecla, ficha da história, golpe da Z pelo Builder e o V pelo
#  código. Mapa e progresso de TESTE.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "user://test_fruta_reconstruida"
const MAPA := "user://test_fruta_reconstruida_mapa.json"
const PROGRESSO := "user://test_fruta_reconstruida.json"
const DANO := 400.0

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_esvaziar()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()

	_ok("só fruta da arena pode ser reconstruída", not SkillsPublicadas.reconstruir_fruta_da_arena("nao_existe", "X", "#ffffff").ok)
	var r := SkillsPublicadas.reconstruir_fruta_da_arena("pika_pika", "Pika Pika no Mi", "#ffd23f")
	_ok("reconstruir a Pika no catálogo (%s)" % str(r), r.ok and SkillsPublicadas.e_reconstruida("pika_pika"))
	_ok("ela NÃO vira fruta do Builder inteira", not KitDoBuilder.e_do_builder("pika_pika"))
	var z := Dados.novo()
	z.identificacao.id = "pika_teste_z"
	z.identificacao.nome = "Raio de teste"
	z.identificacao.dono = "Jogador"
	z.identificacao.fruta = "pika_pika"
	z.ativacao.tecla = "Z"
	z.condicoes.exige_alvo = false
	z.dano.valor = DANO
	z.dano.empurrao = 0.0
	z.dano.atordoamento = 0.0
	z.configuracoes.recarga = 2.5
	z.configuracoes.duracao = 0.3
	z.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.0, "duracao": 0.3, "habilitado": true,
		"parametros": {"forma": "Esfera", "raio": 1.5, "z": -2.0, "y": 1.0}}]
	var pub := SkillsPublicadas.publicar(z)
	_ok("publicar na Z da Pika (%s)" % str(pub.get("erros", [])), pub.ok and pub.get("fruta") == "pika_pika")
	_ok("Z pelo Builder, V pelo código", KitDoBuilder.pelo_builder("pika_pika", "Z") and not KitDoBuilder.pelo_builder("pika_pika", "V")
		and not KitDoBuilder.pelo_builder("pika_pika", "X"))
	_ok("a Pika não aparece de novo como fruta do Builder à venda (%s)" % str(KitDoBuilder.frutas_prontas()),
		not KitDoBuilder.frutas_prontas().has("pika_pika") and PerfilDeFrutas.frutas_a_venda().count("pika_pika") == 1)
	var perfil := PerfilDeFrutas.da_arena("pika_pika")
	_ok("ficha da história: Z com o nome e a recarga do Builder (%s, %.1f s)" % [perfil.tecnica("Z").nome, perfil.tecnica("Z").recarga],
		perfil.tecnica("Z").nome == "Raio de teste" and is_equal_approx(perfil.tecnica("Z").recarga, 2.5))
	_ok("…e o V com o nome do jogo (%s)" % perfil.tecnica("V").nome, perfil.tecnica("V").nome != "Raio de teste" and perfil.tecnica("V").comportamento != KitDoBuilder.COMPORTAMENTO)

	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	var p: Node3D = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _fisica(20)
	_ok("comeu a Pika (%s)" % p.get("current_fruit_id"), str(p.get("current_fruit_id")) == "pika_pika")
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(0, 1.0, -2.2)
	current_scene.add_child(boneco)
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	await _fisica(20)
	boneco.call("parar")
	_ok("recarga da Z = a do Builder (%.1f s)" % float(p.call("recarga_do_cast", "Z")), is_equal_approx(float(p.call("recarga_do_cast", "Z")), 2.5))
	var vida := float(boneco.get("health"))
	p.set("energy", float(p.get("max_energy")))
	p.begin_charge("Z")
	await physics_frame
	var executou := not current_scene.find_children("SkillBuilder_*", "", true, false).is_empty()
	p.release_charge("Z")
	await _fisica(40)
	var esperado := DANO * PerfilDeFrutas.ESCALA_DA_ARENA * float(boneco.get("max_health")) / ExecutorDeSkill.VIDA_DA_ARENA
	var caiu := vida - float(boneco.get("health"))
	print("   dano da Z no boneco: %.2f" % caiu)
	_ok("a Z saiu pelo executor do Builder e feriu o boneco (%.2f)" % caiu, executou and caiu > 0.5)
	p.set("energy", float(p.get("max_energy")))
	p.call("_fire_skill", "V", Vector3.FORWARD, p.global_position, 0.0, 0, "fruit", "pika_pika")
	await _fisica(4)
	var execs_v := current_scene.find_children("SkillBuilder_*", "", true, false).size()
	_ok("o V segue o código da Pika (nenhum executor do Builder: %d)" % execs_v, execs_v == 0)
	p.call("clear_spawned_skills") if p.has_method("clear_spawned_skills") else null
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	_esvaziar()
	print("\nFRUTA_RECONSTRUIDA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _esvaziar() -> void:
	var d := DirAccess.open(ProjectSettings.globalize_path(PASTA))
	if d:
		for nome in d.get_files():
			d.remove(nome)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
