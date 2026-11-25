extends SceneTree
## Publicação isolada -> Kit do Builder -> corpos reais do modo história.
const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://transformacao_mapa.json"
const PROGRESSO := "user://transformacao_progresso.json"
const PASTA := "user://transformacao_skills"
var total := 0
var falhas := 0
var p: Node3D

func _init() -> void: rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("OK " if cond else "FALHA ") + msg)

func quadros(n: int) -> void:
	for i in n: await physics_frame

func publicar(tecla: String, alvo: String, visual: String, modelo := "") -> void:
	var s := Dados.novo()
	s.identificacao.id = "transformacao_" + tecla.to_lower()
	s.identificacao.dono = "Jogador"
	s.ativacao.tecla = tecla
	s.configuracoes.custo = 0.0
	s.configuracoes.recarga = 0.0
	s.configuracoes.duracao = 2.5
	s.eventos = [{"id": "forma", "tipo": "transformacao", "inicio": 0.0, "duracao": 2.5,
		"habilitado": true, "parametros": {"alvo": alvo, "visual": visual, "modelo": modelo, "raio": 12.0}}]
	var r := SkillsPublicadas.publicar(s)
	ok(r.ok, "publicar transformação " + tecla + ": " + str(r.get("erros", [])))

func usar(tecla: String) -> void:
	# Respeitar o intervalo global entre skills do jogador.
	await quadros(40)
	p.begin_charge(tecla)
	await physics_frame
	p.release_charge(tecla)
	await quadros(6)

func forma(alvo: Node3D) -> Node3D:
	var pilha: Array = alvo.get_meta("transformacoes_visuais", [])
	return pilha.back() if not pilha.is_empty() else null

func rodar() -> void:
	await process_frame
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	publicar("Z", "Usuário", "Fumaça")
	publicar("X", "Inimigo mais próximo", "Modelo da loja", "barrel")
	publicar("C", "Assets ao redor", "Luz")
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json").mapa
	for par in [["inimigo_transformacao", "pirate_captain", Vector3(0, 0, -6)], ["asset_transformacao", "barrel", Vector3(3, 0, -2)]]:
		var tam: Vector3 = bib.info(par[1]).tamanho
		mapa.pecas.append({"id": par[0], "tipo": "modelo", "modelo": par[1], "posicao": par[2] + Vector3(0, tam.y * .5, 0),
			"rotacao_graus": Vector3.ZERO, "tamanho": tam, "cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	var inimigo: Node3D = current_scene.find_child("inimigo_transformacao", true, false)
	var asset: StaticBody3D = current_scene.find_child("asset_transformacao", true, false)
	# Conservar o NPC real, sem deixar sua IA interferir na janela de medição.
	inimigo.set_physics_process(false)
	inimigo.global_position = Vector3(0, 1, -6)
	p.global_position = Vector3(0, 1, 0)
	current_scene.progressao.comer_fruta(KitDoBuilder.ID)
	await quadros(20)
	ok(p.current_fruit_id == KitDoBuilder.ID, "história equipa kit publicado")
	var camada: int = p.collision_layer
	var mascara: int = p.collision_mask
	await usar("Z")
	ok(forma(p) != null and forma(p).get_meta("forma") == "Fumaça", "Z transforma Player real em fumaça")
	ok(p.collision_layer == camada and p.collision_mask == mascara and p.is_on_floor(), "Player conserva colisão e apoio no chão")
	var pos := p.global_position
	var andar := InputEventKey.new()
	andar.physical_keycode = KEY_D
	andar.keycode = KEY_D
	andar.pressed = true
	Input.parse_input_event(andar)
	await quadros(35)
	andar.pressed = false
	Input.parse_input_event(andar)
	await quadros(2)
	ok(p.global_position.distance_to(pos) > .5, "Player transformado anda pela entrada de teclado")
	ok(forma(p) != null and absf(forma(p).global_position.x - p.global_position.x) < .5, "forma acompanha deslocamento do corpo real")
	ok(p.corpo_livre_para_golpe(), "transformação permite combate corpo a corpo")
	p._request_melee()
	await quadros(2)
	ok(p.combate_direcional.atacando(), "Player desfere soco enquanto transformado")
	var vida: float = p.health
	p.take_damage(1.0, p.global_position + Vector3(0, 0, -2), Vector3.ZERO, 0.0)
	ok(p.health < vida, "fumaça mantém recebimento de dano")
	await quadros(160)
	ok(forma(p) == null and p._char_model.is_visible_in_tree(), "fim do bloco restaura personagem")
	p.global_position = pos
	await usar("X")
	ok(forma(inimigo) != null and forma(inimigo).get_meta("forma") == "Modelo da loja", "X transforma NPC real no barril selecionado")
	ok(forma(p) == null and forma(asset) == null, "alvo mais próximo preserva usuário e objeto")
	vida = inimigo.health
	inimigo.take_damage(1.0, p.global_position, Vector3.ZERO, 0.0)
	ok(inimigo.health < vida, "NPC transformado continua recebendo dano")
	p.clear_spawned_skills()
	await quadros(2)
	ok(forma(inimigo) == null, "limpar skills restaura NPC antes do prazo")
	var formas: int = asset.get_child_count()
	camada = asset.collision_layer
	mascara = asset.collision_mask
	await usar("C")
	ok(forma(asset) != null and forma(asset).get_meta("forma") == "Luz", "C transforma objeto do mapa em luz")
	ok(asset.collision_layer == camada and asset.collision_mask == mascara and asset.get_child_count() == formas, "objeto conserva corpo e formas de colisão")
	await quadros(160)
	ok(forma(asset) == null, "objeto restaura ao fim da duração")
	ok(MapaArquivo.carregar(MAPA).mapa.pecas[2].modelo == "barrel", "transformação não altera asset salvo no mapa")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	print("TRANSFORMACAO HISTORIA: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
