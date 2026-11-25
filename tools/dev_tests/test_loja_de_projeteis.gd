extends SceneTree
# ============================================================================
#  LOJA DE PROJÉTEIS do Skills Builder (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_loja_de_projeteis.gd
#
#  Pedido do dono: "loja de projéteis na aba de projéteis a serem disparados no editor";
#  decisão: catálogo PRONTO (forma + rastro + valores) e modelos .glb da loja do editor.
#  Confere: contrato (campos novos opcionais, id de modelo seguro), desenho de cada forma,
#  modelo da loja no tamanho do raio, orientação e giro, a loja no editor (pronto, modelo,
#  desfazer, bloco aberto) e o executor do jogo disparando a forma escolhida.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Catalogo := preload("res://src/skills_builder/catalogo_de_projeteis.gd")

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_contrato()
	await _desenhos()
	await _editor()
	await _jogo()
	print("\nLOJA_DE_PROJETEIS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ contrato

func _contrato() -> void:
	var todos_validos := true
	for forma: String in Catalogo.PRONTOS:
		var s := Dados.novo()
		(s.projeteis as Dictionary).merge(Catalogo.valores_do_pronto(forma), true)
		if not Dados.validar(s).ok:
			todos_validos = false
			print("      recusado: %s %s" % [forma, str(Dados.validar(s).erros)])
	_ok("os %d prontos cabem no contrato" % Catalogo.PRONTOS.size(), todos_validos and Catalogo.PRONTOS.size() == 10)
	_ok("toda forma pronta está na lista de formas", Catalogo.PRONTOS.keys().all(func(f): return f in Catalogo.FORMAS))
	var velha := Dados.novo()
	for k in ["visual", "modelo", "giro", "rastro"]:
		(velha.projeteis as Dictionary).erase(k)
	_ok("skill de antes (sem os campos novos) continua válida", Dados.validar(velha).ok)
	var ruim := Dados.novo()
	ruim.projeteis.visual = MODELO_FALSO
	_ok("forma que não existe é recusada", not Dados.validar(ruim).ok)
	ruim = Dados.novo()
	ruim.projeteis.visual = Catalogo.MODELO
	ruim.projeteis.modelo = "../../etc/passwd"
	_ok("id de modelo com caminho é recusado", not Dados.validar(ruim).ok)
	ruim = Dados.novo()
	ruim.eventos.append({"id": "p", "tipo": "projetil", "inicio": 0.0, "duracao": 0.1, "habilitado": true, "parametros": {"modelo": "a/b"}})
	_ok("… também no bloco de projétil", not Dados.validar(ruim).ok)

const MODELO_FALSO := "Canhão de plasma"


# ------------------------------------------------------------------ desenhos

func _desenhos() -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	var ruins: Array[String] = []
	for forma: String in Catalogo.PRONTOS:
		var no := Catalogo.criar(Catalogo.valores_do_pronto(forma), Color("#ff7ad9"))
		var malhas := no.find_children("*", "MeshInstance3D", true, false).size()
		var rastro := no.get_node_or_null("Rastro") != null
		var quer_rastro := str(Catalogo.PRONTOS[forma].valores.rastro) != "Nenhum"
		if str(no.get_meta("forma")) != forma or malhas < 1 or rastro != quer_rastro:
			ruins.append("%s (malhas %d, rastro %s)" % [forma, malhas, rastro])
		no.free()
	_ok("cada pronto desenha a sua forma, com rastro só quando tem %s" % str(ruins), ruins.is_empty())

	var bib := MapaMontador.biblioteca_em_uso()
	var id := "bomb" if bib.tem("bomb") else bib.ids()[0]
	var p := {"visual": Catalogo.MODELO, "modelo": id, "raio": 0.5}
	var no := Catalogo.criar(p, Color.WHITE, bib)
	cena.add_child(no)
	var caixa := _caixa(no.get_node("Corpo/Modelo"))
	var maior := maxf(maxf(caixa.size.x, caixa.size.y), caixa.size.z)
	_ok("modelo da loja (%s) vira projétil do tamanho do raio (maior medida %.2f m, quer 1,00)" % [id, maior],
		str(no.get_meta("forma")) == Catalogo.MODELO and absf(maior - 1.0) < 0.12)
	_ok("e fica centrado no ponto do projétil (centro a %.2f m)" % caixa.get_center().distance_to(no.global_position),
		caixa.get_center().distance_to(no.global_position) < 0.12)
	no.queue_free()
	var some := Catalogo.criar({"visual": Catalogo.MODELO, "modelo": "nao_existe_mais"}, Color.WHITE, bib)
	_ok("modelo que sumiu da loja desenha a Energia", str(some.get_meta("forma")) == Catalogo.PADRAO)
	some.free()

	var flecha := Catalogo.criar(Catalogo.valores_do_pronto("Flecha"), Color.WHITE)
	cena.add_child(flecha)
	Catalogo.animar(flecha, Vector3(10, 0, 0), 0.016)
	var frente := -flecha.global_basis.z
	_ok("a flecha aponta para onde vai (frente · rumo = %.2f)" % frente.dot(Vector3.RIGHT), frente.dot(Vector3.RIGHT) > 0.99)
	var shuriken := Catalogo.criar(Catalogo.valores_do_pronto("Shuriken"), Color.WHITE)
	cena.add_child(shuriken)
	var corpo := shuriken.get_node("Corpo") as Node3D
	for i in 10:
		Catalogo.animar(shuriken, Vector3(0, 0, -10), 0.01)
	var girou := rad_to_deg(corpo.basis.get_euler().y)
	_ok("a shuriken gira deitada (%.0f° em 0,1 s, quer ~144°)" % absf(girou), absf(absf(girou) - 144.0) < 3.0)
	cena.queue_free()
	await process_frame


## Caixa (mundo) que as malhas debaixo de `no` ocupam.
func _caixa(no: Node) -> AABB:
	var total := AABB()
	var primeiro := true
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var c: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		total = c if primeiro else total.merge(c)
		primeiro = false
	return total


# ------------------------------------------------------------------ editor

func _editor() -> void:
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	var ed := current_scene
	ed.pasta_skills = "user://test_loja_projeteis_rascunho"
	ed._mostrar_secao("projeteis")
	await _quadros(3)
	var loja := ed.find_child("LojaDeProjeteis", true, false)
	var prontos := loja.find_child("Prontos", true, false) if loja else null
	_ok("a seção Projéteis abre com a loja (%d prontos)" % (prontos.get_child_count() if prontos else 0),
		prontos != null and prontos.get_child_count() == 10)
	(loja.find_child("Pronto_Flecha", true, false) as Button).pressed.emit()
	await _quadros(3)
	var pr: Dictionary = ed.skill.projeteis
	_ok("clicar na Flecha grava forma, rastro e valores (%s, %.0f m/s, %s)" % [pr.visual, pr.velocidade, pr.rastro],
		pr.visual == "Flecha" and is_equal_approx(float(pr.velocidade), 36.0) and pr.rastro == "Vento")
	loja = ed.find_child("LojaDeProjeteis", true, false)
	_ok("o cartão da Flecha fica marcado", (loja.find_child("Pronto_Flecha", true, false) as Button).button_pressed)
	ed.desfazer()
	await _quadros(3)
	_ok("desfazer volta para a Energia (%s)" % ed.skill.projeteis.visual, ed.skill.projeteis.visual == "Energia")

	ed._construir_inspector()
	await _quadros(2)
	loja = ed.find_child("LojaDeProjeteis", true, false)
	var bib := MapaMontador.biblioteca_em_uso()
	var id := "bomb" if bib.tem("bomb") else bib.ids()[0]
	var busca := loja.find_child("BuscaDeModelo", true, false) as LineEdit
	busca.text = id
	busca.text_changed.emit(id)
	await _quadros(2)
	var vel_antes := float(ed.skill.projeteis.velocidade)
	var cartao := loja.find_child("Modelo_" + id, true, false) as Button
	_ok("a busca acha o modelo \"%s\" na loja do editor" % id, cartao != null)
	if cartao != null:
		cartao.pressed.emit()
		await _quadros(3)
	pr = ed.skill.projeteis
	_ok("clicar no modelo troca só a forma (%s, %s, velocidade %.0f)" % [pr.visual, pr.modelo, pr.velocidade],
		pr.visual == Catalogo.MODELO and pr.modelo == id and is_equal_approx(float(pr.velocidade), vel_antes))

	var novo: Dictionary = ed.skill.duplicate(true)
	novo.eventos.append({"id": "disparo", "tipo": "projetil", "inicio": 0.1, "duracao": 0.2, "habilitado": true, "parametros": {}})
	ed._aplicar_edicao(novo)
	ed.selecionar_evento("disparo")
	await _quadros(3)
	loja = ed.find_child("LojaDeProjeteis", true, false)
	(loja.find_child("Pronto_Bomba", true, false) as Button).pressed.emit()
	await _quadros(3)
	var ev: Dictionary = ed._evento_por_id("disparo")
	_ok("com o bloco aberto, a Bomba vai para o bloco (%s) e a seção fica (%s)" % [ev.parametros.get("visual", "—"), ed.skill.projeteis.visual],
		ev.parametros.get("visual", "") == "Bomba" and ed.skill.projeteis.visual == Catalogo.MODELO)


# ------------------------------------------------------------------ jogo

func _jogo() -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	var ator := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	ator.add_child(cs)
	ator.position = Vector3(0, 0.8, 0)
	cena.add_child(ator)
	var s := Dados.novo()
	s.eventos = [{"id": "disparo", "tipo": "projetil", "inicio": 0.0, "duracao": 0.1, "habilitado": true,
		"parametros": Catalogo.valores_do_pronto("Flecha")}]
	s.configuracoes.duracao = 0.1
	_ok("skill com Flecha é válida", Dados.validar(s).ok)
	await physics_frame
	ExecutorDeSkill.lancar(cena, ator, s, Vector3.FORWARD)
	for i in 6:
		await physics_frame
	var zonas := cena.find_children("*", "DamageZone", true, false)
	var desenho: Node3D = (zonas[0] as Node).get_node_or_null("Projetil") if not zonas.is_empty() else null
	_ok("o executor do jogo dispara a Flecha (%s)" % (str(desenho.get_meta("forma")) if desenho else "nada"),
		desenho != null and str(desenho.get_meta("forma")) == "Flecha")
	if desenho == null:
		return
	for i in 24:
		await physics_frame
	var vel: Vector3 = (zonas[0] as DamageZone).vel
	var frente := -desenho.global_basis.z
	_ok("em voo ela cai (vel.y %.2f) e o bico acompanha a queda (%.3f)" % [vel.y, frente.dot(vel.normalized())],
		vel.y < -0.5 and frente.dot(vel.normalized()) > 0.999)
	cena.queue_free()


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
