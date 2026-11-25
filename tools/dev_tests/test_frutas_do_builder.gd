extends SceneTree
# ============================================================================
#  FRUTAS DO SKILLS BUILDER (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_frutas_do_builder.gd
#
#  Decisão do dono: o Builder faz FRUTA PRÓPRIA (nome + skills Z/X/C/V) que vira fruta
#  de verdade — vendedor na história, menu do M na arena. Catálogo, publicação, o
#  editor (campo Fruta + Criar fruta), compra/comer/golpe/save no Modo História e o
#  botão no menu do M. Pasta de TESTE (nunca `res://mapas/skills`).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "user://test_frutas_do_builder"
const MAPA := "user://test_frutas_builder_mapa.json"
const PROGRESSO := "user://test_frutas_builder.json"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_esvaziar()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()

	# --- catálogo
	_ok("id de \"Noro Noro no Mi\" = noro_noro", SkillsPublicadas.id_de_nome("Noro Noro no Mi") == "noro_noro")
	var r := SkillsPublicadas.criar_fruta("Noro Noro no Mi", "#ff7ad9")
	_ok("criar a fruta (%s)" % str(r), r.ok and r.id == "noro_noro")
	_ok("nome repetido é recusado", not SkillsPublicadas.criar_fruta("Noro Noro no Mi", "#ffffff").ok)
	_ok("nome de fruta da arena é recusado (mera_mera)", not SkillsPublicadas.criar_fruta("Mera Mera no Mi", "#ff0000").ok)
	_ok("fruta sem skill ainda não está pronta", not KitDoBuilder.disponivel("noro_noro") and KitDoBuilder.frutas_prontas().is_empty())

	# --- publicar na fruta
	var z := _skill("noro_z", "Z", "noro_noro")
	var pub := SkillsPublicadas.publicar(z)
	_ok("publicar na fruta: tecla Z da noro_noro (%s)" % str(pub), pub.ok and pub.tecla == "Z" and pub.get("fruta") == "noro_noro")
	_ok("o kit não ganhou a skill", SkillsPublicadas.dono_da_tecla("Z") == "")
	_ok("a fruta está pronta: %s" % str(KitDoBuilder.frutas_prontas()), KitDoBuilder.frutas_prontas() == _txt(["noro_noro"]))
	_ok("e_do_builder / nome / teclas", KitDoBuilder.e_do_builder("noro_noro") and KitDoBuilder.nome("noro_noro") == "Noro Noro no Mi"
		and KitDoBuilder.teclas("noro_noro") == _txt(["Z"]))
	_ok("à venda junto das da arena, com o nome", PerfilDeFrutas.frutas_a_venda().has("noro_noro") and PerfilDeFrutas.nome_da_fruta("noro_noro") == "Noro Noro no Mi")
	var ruim := _skill("ruim", "X", "fruta_que_nao_existe")
	_ok("publicar numa fruta que não existe é recusado", not SkillsPublicadas.publicar(ruim).ok)
	var para_o_kit := _skill("noro_z", "Z", "")
	SkillsPublicadas.publicar(para_o_kit)
	_ok("republicar sem fruta tira da fruta e põe no kit", SkillsPublicadas.dono_da_tecla("Z") == "noro_z" and not KitDoBuilder.disponivel("noro_noro"))
	SkillsPublicadas.publicar(z)
	SkillsPublicadas.recarregar()
	_ok("relido do disco: a fruta tem Z = noro_z", KitDoBuilder.skill("Z", "noro_noro").get("identificacao", {}).get("id", "") == "noro_z")

	# --- editor: campo Fruta e Criar fruta
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	var ed := current_scene
	ed.pasta_skills = "user://test_frutas_do_builder_rascunho"
	ed._mostrar_secao("identificacao")
	await _quadros(3)
	var lista := ed.find_child("fruta", true, false) as OptionButton
	_ok("Identificação de skill de Jogador tem a lista Fruta (Kit + noro)", lista != null and lista.item_count == 2)
	(ed.find_child("NomeDaNovaFruta", true, false) as LineEdit).text = "Hie Teste no Mi"
	(ed.find_child("CriarFruta", true, false) as Button).pressed.emit()
	await _quadros(4)
	_ok("Criar fruta cria no catálogo e escolhe para a skill (%s)" % str(ed.skill.identificacao.get("fruta", "")),
		not SkillsPublicadas.fruta("hie_teste").is_empty() and str(ed.skill.identificacao.get("fruta", "")) == "hie_teste")

	# --- Modo História: comprar, comer, golpe, save
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	var p: Node3D = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var preco := PerfilDeFrutas.preco_na_loja("noro_noro")        # preço por poder (mínimo 1000), não mais 100
	prog.ouro = preco + 5
	var loja: Object = load("res://src/historia/npcs/loja_de_frutas.gd").new()
	var ids: Array = loja.linhas(prog, null).map(func(l): return str(l.id))
	_ok("o vendedor de frutas vende a Noro Noro no Mi", ids.has("noro_noro"))
	loja.executar(prog, null, "comprar", "noro_noro")
	_ok("comprar: preço da loja (%d), vai para o inventário" % preco, prog.ouro == 5 and prog.quantas_akuma("noro_noro") == 1)
	_ok("comer a comprada", prog.comer_fruta_comprada("noro_noro"))
	await _fisica(20)
	_ok("o corpo está com a Noro (%s) e a ficha tem Z" % p.get("current_fruit_id"), str(p.get("current_fruit_id")) == "noro_noro"
		and (p.get("perfil_de_frutas") as PerfilDeFrutas).slots() == _txt(["Z"]))
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(0, 1.0, -2.2)
	current_scene.add_child(boneco)
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	await _fisica(20)
	boneco.call("parar")
	var vida := float(boneco.get("health"))
	p.set("energy", float(p.get("max_energy")))
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	await _fisica(40)
	_ok("Z da Noro acerta o boneco (%.1f → %.1f)" % [vida, float(boneco.get("health"))], float(boneco.get("health")) < vida - 0.5)
	prog.salvar(PROGRESSO)
	var relido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok("o save guarda a fruta do Builder", relido != null and relido.fruta == "noro_noro")

	# --- arena: botão no menu do M
	# Carregado na HORA: citar a classe no topo compila o Player.gd antes dos autoloads e
	# quebra as classes de combate no resto do teste (armadilha registrada em 06/10).
	var menu: Control = load("res://src/ui/CharacterMenu.gd").new()
	root.add_child(menu)
	await _quadros(2)
	_ok("o menu do M tem o botão da Noro Noro no Mi", menu.find_child("Fruta_noro_noro", true, false) != null)
	menu.queue_free()

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	_esvaziar()
	print("\nFRUTAS_DO_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill(id: String, tecla: String, fruta: String) -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = id
	s.identificacao.nome = id
	s.identificacao.dono = "Jogador"
	s.identificacao.fruta = fruta
	s.ativacao.tecla = tecla
	s.condicoes.exige_alvo = false
	s.dano.empurrao = 0.0
	s.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.0, "duracao": 0.3, "habilitado": true, "parametros": {}}]
	s.configuracoes.duracao = 0.3
	return s


## Lista tipada para comparar com Array[String] (`a == [..] as Array[String]` vira
## `(a == [..]) as Array[String]` — precedência do `as`).
func _txt(a: Array) -> Array[String]:
	var t: Array[String] = []
	for v in a:
		t.append(str(v))
	return t


func _esvaziar() -> void:
	var d := DirAccess.open(ProjectSettings.globalize_path(PASTA))
	if d:
		for nome in d.get_files():
			d.remove(nome)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
