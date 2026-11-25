extends SceneTree
const Dados := preload("res://src/skills_builder/dados_skill.gd")
var Transformacao: GDScript
var Executor: GDScript
var falhas := 0
var total := 0
var cena: Node3D
var usuario: CharacterBody3D
var proximo: CharacterBody3D
var longe: CharacterBody3D
var objeto: CharacterBody3D

class CorpoTransformavelDeTeste extends CharacterBody3D:
	var health := 100.0
	func take_damage(dano: float) -> void: health -= dano


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("OK " if cond else "FALHA ") + msg)


func skill(alvo := "Usuário", visual := "Fumaça") -> Dictionary:
	var s := Dados.novo()
	s.configuracoes.duracao = 2.0
	s.condicoes.exige_alvo = false
	s.transformacao.alvo = alvo
	s.transformacao.visual = visual
	s.eventos = [{"id": "forma", "tipo": "transformacao", "inicio": .2,
		"duracao": .8, "habilitado": true, "parametros": {}}]
	return s


func corpo(nome: String, pos: Vector3, grupo: String = "") -> CharacterBody3D:
	var n := CorpoTransformavelDeTeste.new()
	n.name = nome
	cena.add_child(n)
	n.position = pos
	if not grupo.is_empty(): n.add_to_group(grupo)
	var mesh := MeshInstance3D.new()
	mesh.name = "Visual"
	mesh.mesh = CapsuleMesh.new()
	n.add_child(mesh)
	var oculto := MeshInstance3D.new()
	oculto.name = "OcultoAntes"
	oculto.mesh = SphereMesh.new()
	oculto.visible = false
	n.add_child(oculto)
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	n.add_child(cs)
	return n


func rodar() -> void:
	await process_frame
	Transformacao = load("res://src/skills_builder/transformacao_de_skill.gd")
	Executor = load("res://src/skills_builder/executor_de_skill.gd")
	if not Transformacao.can_instantiate() or not Executor.can_instantiate():
		ok(false, "componentes compilam")
		quit(1)
		return
	var antiga := Dados.novo()
	antiga.erase("transformacao")
	var migrada := Dados.validar(antiga)
	ok(migrada.ok and migrada.skill.has("transformacao"), "skill antiga continua válida e recebe padrões")
	ok(Dados.validar(skill()).ok, "bloco novo válido")
	for campo in [{"alvo": "qualquer_coisa"}, {"raio": -1}, {"modelo": "../codigo"}, {"escala": 999}, {"visual": "script"}]:
		var s := skill()
		s.transformacao.merge(campo, true)
		ok(not Dados.validar(s).ok, "parâmetro inválido recusado: " + str(campo))
	var s := skill()
	s.eventos[0].parametros = {"visual": "Luz", "raio": 3.0}
	ok(Dados.parametros(s, s.eventos[0]).visual == "Luz", "bloco sobrescreve a forma global")
	var caminho := "user://transformacao_roundtrip.json"
	var gravado := Dados.salvar_em(s, caminho)
	var lido := Dados.carregar(caminho)
	ok(gravado.ok and lido.ok and lido.skill == JSON.parse_string(JSON.stringify(s)), "salvar e reabrir preserva transformação")
	if not gravado.ok or not lido.ok: print("IO_TRANSFORMACAO ", gravado, " ", lido)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	cena = Node3D.new()
	root.add_child(cena)
	usuario = corpo("Usuario", Vector3.ZERO, "player")
	proximo = corpo("Proximo", Vector3(0, 0, -2), "enemy")
	longe = corpo("Longe", Vector3(0, 0, -20), "enemy")
	objeto = corpo("Asset", Vector3(2, 0, 0), "assets_transformaveis")
	var p: Dictionary = skill().transformacao
	ok(Transformacao.selecionar(usuario, p) == [usuario], "seleção do próprio usuário")
	p.alvo = "Inimigo mais próximo"
	ok(Transformacao.selecionar(usuario, p) == [proximo], "inimigo mais próximo dentro do raio")
	p.alvo = "Inimigos ao redor"
	ok(Transformacao.selecionar(usuario, p) == [proximo], "área ignora inimigo distante e assets")
	p.alvo = "Assets ao redor"
	ok(Transformacao.selecionar(usuario, p) == [objeto], "assets excluem personagens")
	p.alvo = "Inimigos e assets ao redor"
	ok(Transformacao.selecionar(usuario, p).size() == 2, "área mista seleciona personagem e objeto")
	proximo.health = 0
	ok(Transformacao.selecionar(usuario, p) == [objeto], "morto não é transformado")
	proximo.health = 100
	p = skill().transformacao
	var forma: Node3D = Transformacao.iniciar(usuario, usuario, p)
	ok(not usuario.get_node("Visual").visible and usuario.visible, "esconde geometria sem esconder o corpo lógico")
	ok(usuario.collision_layer == 1 and usuario.collision_mask == 1, "colisão conservada")
	usuario.take_damage(7)
	ok(usuario.health == 93, "alvo transformado continua recebendo dano")
	var antes: Vector3 = forma.get_child(0).global_position
	usuario.position.x += 2
	forma.atualizar(.3)
	ok(is_equal_approx(forma.get_child(0).global_position.x - antes.x, 2.0), "forma acompanha movimento")
	ok(forma.get_child_count() == 1, "não captura a própria forma na busca da geometria")
	p.visual = "Luz"
	var segunda: Node3D = Transformacao.iniciar(cena, usuario, p)
	forma.atualizar(.3)
	ok(not forma.get_child(0).visible and segunda.get_child(0).visible, "última transformação prevalece")
	segunda.encerrar()
	ok(not usuario.get_node("Visual").visible and forma.get_child(0).visible, "fim da última volta à transformação anterior")
	forma.encerrar()
	ok(usuario.get_node("Visual").visible and not usuario.get_node("OcultoAntes").visible, "restaura visibilidade original, inclusive partes já ocultas")
	await process_frame
	forma = Transformacao.iniciar(cena, usuario, p)
	segunda = Transformacao.iniciar(cena, usuario, p)
	forma.encerrar()
	ok(not usuario.get_node("Visual").visible and segunda.get_child(0).visible, "fim da transformação anterior conserva a última")
	var equipamento := MeshInstance3D.new()
	equipamento.mesh = BoxMesh.new()
	usuario.add_child(equipamento)
	segunda.atualizar(.2)
	ok(not equipamento.visible, "equipamento criado durante transformação também fica oculto")
	usuario.health = 0
	segunda.atualizar(.3)
	ok(segunda.get("_entradas").is_empty() and usuario.get_node("Visual").visible and equipamento.visible, "morte encerra forma e restaura corpo e equipamento")
	segunda.encerrar()
	equipamento.queue_free()
	usuario.health = 100
	await process_frame
	usuario.position = Vector3.ZERO
	p.visual = "Modelo da loja"
	p.modelo = "barrel"
	forma = Transformacao.iniciar(cena, usuario, p)
	ok(forma.get_child_count() == 1 and not usuario.get_node("Visual").visible, "modelo da loja substitui visual")
	ok(forma.find_children("*", "CollisionShape3D", true, false).is_empty(), "modelo de transformação não traz colisão")
	forma.encerrar()
	await process_frame
	p.modelo = "id_inexistente_para_teste"
	forma = Transformacao.iniciar(cena, usuario, p)
	ok(forma.get_child_count() == 0 and usuario.get_node("Visual").visible, "asset ausente não deixa corpo invisível")
	forma.encerrar()
	await process_frame
	# O próprio executor deve abrir/fechar o bloco, cancelar e limpar ao sair da árvore.
	s = skill()
	var e: Node = Executor.lancar(cena, usuario, s, Vector3.FORWARD)
	e.set_physics_process(false)
	e._physics_process(.1)
	ok(usuario.get_node("Visual").visible, "antes do início mantém visual original")
	e._physics_process(.2)
	ok(not usuario.get_node("Visual").visible, "executor inicia transformação no bloco")
	e._physics_process(.8)
	ok(usuario.get_node("Visual").visible, "duração do bloco restaura visual")
	e.cancelar()
	await process_frame
	e = Executor.lancar(cena, usuario, s, Vector3.FORWARD)
	e.set_physics_process(false)
	e._physics_process(.3)
	e.cancelar()
	ok(usuario.get_node("Visual").visible, "cancelamento restaura imediatamente")
	await process_frame
	e = Executor.lancar(cena, usuario, s, Vector3.FORWARD)
	e.set_physics_process(false)
	e._physics_process(.3)
	e.free()
	ok(usuario.get_node("Visual").visible, "remover executor restaura alvo")
	var novo: Node3D = Transformacao.iniciar(cena, proximo, skill().transformacao)
	proximo.free()
	novo.atualizar(.2)
	ok(novo.get("_entradas").is_empty(), "alvo removido limpa referências")
	novo.encerrar()
	cena.queue_free()
	await process_frame
	await testar_previa()
	print("TRANSFORMACAO: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)


func testar_previa() -> void:
	var arena: Node3D = load("res://src/skills_builder/arena_preview.gd").new()
	root.add_child(arena)
	arena.set_process(false)
	for destino in ["Usuário", "Inimigo mais próximo", "Assets ao redor"]:
		arena.configurar(skill(destino, "Luz"))
		arena.buscar(.5)
		var esperado: Node3D = arena.ator if destino == "Usuário" else arena.alvo
		if destino == "Assets ao redor": esperado = arena.get_node("AssetDeEnsaio0")
		ok(esperado.has_meta("transformacoes_visuais"), "prévia aplica: " + destino)
		arena.buscar(1.4)
		ok(not esperado.has_meta("transformacoes_visuais"), "buscar após bloco restaura: " + destino)
		arena.buscar(.5)
		arena.parar()
		ok(not esperado.has_meta("transformacoes_visuais"), "Parar restaura: " + destino)
	arena.free()
