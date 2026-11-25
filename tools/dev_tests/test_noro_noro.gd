extends SceneTree
# ============================================================================
#  NORO NORO NO MI — a fruta feita no Skills Builder, em jogo (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_noro_noro.gd
#
#  Lê a fruta PUBLICADA NO PROJETO (`res://mapas/skills`, feita por
#  `tools/criar_noro_noro.gd`) e confere o pedido do dono:
#    • raio que deixa "qualquer ser atingido" lento por 3 s; a Z deixa 5× mais lento;
#    • poses de carregar, segurar, soltar e final, encadeadas com transição;
#    • a fruta vendida e comida como as outras.
#  Mapa e progresso de TESTE.
# ============================================================================

const MAPA := "user://test_noro_mapa.json"
const PROGRESSO := "user://test_noro.json"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	SkillsPublicadas.recarregar()
	var s := KitDoBuilder.skill("Z", "noro_noro")
	_ok("a Noro Noro no Mi está no catálogo do projeto, pronta, com a Z", KitDoBuilder.frutas_prontas().has("noro_noro") and not s.is_empty())
	if s.is_empty():
		_fim()
		return
	_ok("Z: \"Carregar e soltar\", 5× mais lento (80 %%) por 3 s", s.ativacao.modo == "Carregar e soltar"
		and is_equal_approx(float(s.dano.lentidao), 80.0) and is_equal_approx(float(s.dano.duracao_efeito), 3.0))
	var nomes: Array = (s.poses as Array).map(func(p): return str(p.nome))
	_ok("quatro poses: %s" % str(nomes), nomes == ["Carregar", "Segurar", "Soltar", "Final"])
	var blocos: Array = []
	for e: Dictionary in s.eventos:
		if e.tipo == "animacao":
			blocos.append([float(e.inicio), str(e.parametros.get("pose", ""))])
	blocos.sort()
	var ordem: Array = blocos.map(func(b): return _nome_da_pose(s, b[1]))
	_ok("timeline encadeia as poses com transição: %s" % str(ordem), ordem == ["Carregar", "Segurar", "Soltar", "Final"])

	# --- jogo
	var bib := BibliotecaDeModelos.padrao()
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
	var preco := PerfilDeFrutas.preco_na_loja("noro_noro")       # o preço vem do poder (mínimo 1000), não é mais fixo em 100
	prog.ouro = preco
	var loja: Object = load("res://src/historia/npcs/loja_de_frutas.gd").new()
	loja.executar(prog, null, "comprar", "noro_noro")
	_ok("comprada no vendedor pelo preço da loja (%d moedas)" % preco, prog.quantas_akuma("noro_noro") == 1 and prog.ouro == 0)
	prog.comer_fruta_comprada("noro_noro")
	await _fisica(20)
	_ok("comida: o corpo é Noro Noro", str(p.get("current_fruit_id")) == "noro_noro")

	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(0, 1.0, -5)
	current_scene.add_child(boneco)
	var vaca := AnimalDaIlha.new()
	vaca.montar(bib, "cow", FichaDeAnimal.normalizar(bib.ficha_de_animal("cow")), {"especie": "cow", "base": Basis(), "centro": Vector3(0.8, 0, -9), "meio": Vector3(2, 1, 2)})
	current_scene.add_child(vaca)
	vaca.global_position = Vector3(0.8, 0, -9)
	vaca.alvo = null
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.08)
	p.call("_update_pivot")
	await _fisica(30)
	boneco.call("parar")
	vaca.set("estado", AnimalDaIlha.Estado.PARADO)
	var vida_b := float(boneco.get("health"))
	var vida_v := float(vaca.get("health"))

	var anim: Node = null
	for c in p.get_children():
		if c is ProceduralAnimator:
			anim = c
	var braco: Node3D = (anim.get("_n") as Dictionary).get("UpperArm_R")
	var rep: Vector3 = (anim.get("_rest") as Dictionary).get("UpperArm_R", Vector3.ZERO)
	p.set("energy", float(p.get("max_energy")))
	p.begin_charge("Z")
	await _fisica(18)                         # 0,3 s: carregando
	var a_carregar := rad_to_deg(braco.rotation.x - rep.x)
	await _fisica(45)                         # ~1,05 s: segurando (parado no ponto)
	var a_segurar := rad_to_deg(braco.rotation.x - rep.x)
	_ok("segurando a tecla, ninguém é atingido ainda", is_equal_approx(Lentidao.fator(boneco), 1.0))
	p.release_charge("Z")
	await _fisica(22)                         # soltou: raio saindo
	var a_soltar := rad_to_deg(braco.rotation.x - rep.x)
	await _fisica(34)                         # final
	var a_final := rad_to_deg(braco.rotation.x - rep.x)
	print("   braço direito (X): carregar %.0f° · segurar %.0f° · soltar %.0f° · final %.0f°" % [a_carregar, a_segurar, a_soltar, a_final])
	_ok("as poses se sucedem no corpo (carregar < segurar < soltar; final abaixa)",
		a_carregar < a_segurar and a_segurar < a_soltar and a_final < a_soltar - 15.0 and a_soltar > 70.0)

	_ok("o raio pega o boneco: 5× lento (%.2f), ~3 s (%.1f s), com aura" % [Lentidao.fator(boneco), Lentidao.resta(boneco)],
		is_equal_approx(Lentidao.fator(boneco), 0.2) and Lentidao.resta(boneco) > 2.0 and boneco.get_node_or_null(Lentidao.AURA) != null)
	_ok("e a vaca atrás dele também (%.2f)" % Lentidao.fator(vaca), is_equal_approx(Lentidao.fator(vaca), 0.2))
	_ok("o raio não fere (só deixa lento)", is_equal_approx(float(boneco.get("health")), vida_b) and is_equal_approx(float(vaca.get("health")), vida_v))
	await _fisica(170)
	_ok("passados 3 s, o boneco volta ao normal", is_equal_approx(Lentidao.fator(boneco), 1.0))
	_fim()


func _nome_da_pose(s: Dictionary, id: String) -> String:
	for p in s.poses:
		if str(p.id) == id:
			return str(p.nome)
	return "?"


func _fim() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nNORO_NORO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
