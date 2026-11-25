extends SceneTree
## O marcador real da vila concede um pet persistente, sem corpo até chamar().
const Companhia := preload("res://src/historia/pets/companhia.gd")
const SAVE := "user://test_cavalo_guardado/progresso.json"
var falhas := 0
var gravacoes := 0

func _initialize() -> void:
	_executar.call_deferred()

func verificar(condicao: bool, mensagem: String) -> void:
	print(("PASS " if condicao else "FAIL ") + mensagem)
	if not condicao:
		falhas += 1

func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	var p := {"id": Companhia.CAVALO_DA_VILA, "tipo": "modelo", "modelo": "cavalo_da_vila_leve",
		"posicao": Vector3(12, 1.2, 0), "rotacao_graus": Vector3.ZERO,
		"tamanho": bib.tamanho_padrao("cavalo_da_vila_leve"), "cor": Color.WHITE,
		"material": "liso", "grade_celula": 4.0, "colisao": true}
	mapa["pecas"].append(p)
	var original := mapa.duplicate(true)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var raiz := MapaMontador.montar(mundo, mapa)
	var dono := Node3D.new()
	mundo.add_child(dono)
	dono.position = Vector3(0, 1, 0)
	var progresso := ProgressaoDoPersonagem.new()
	var companhia := Companhia.new()
	companhia.progressao = progresso
	companhia.alvo_de = func(): return dono
	mundo.add_child(companhia)
	progresso.mudou.connect(func():
		gravacoes += 1
		verificar(progresso.salvar(SAVE) == OK, "autosave grava concessão e inventário"))
	var iniciais := progresso.pets.size()
	verificar(companhia.ligar_no_mapa(raiz, mapa, bib) == 1, "marcador da vila interpretado no fluxo do mapa")
	verificar(progresso.pets.size() == iniciais + 1 and gravacoes == 1, "concede exatamente um cavalo em uma gravação")
	var id := ""
	for chave in progresso.pets:
		if progresso.especie_do_pet(chave) == "cavalo_da_vila_leve":
			id = chave
	verificar(not id.is_empty() and progresso.nome_do_pet(id) == "Cavalo da vila", "cavalo aparece no inventário com nome")
	verificar(companhia.quantos_fora() == 0 and get_nodes_in_group("pets_historia").is_empty(), "guardado não cria corpo nem IA capaz de teleportar")
	verificar(raiz.get_node_or_null(NodePath(Companhia.CAVALO_DA_VILA)) == null, "remove só o marcador runtime")
	verificar(mapa == original, "documento do mapa permanece intacto")
	await physics_frame
	await physics_frame
	# Simula reentrada com o arquivo que o sinal mudou acabou de salvar.
	var recarregado := ProgressaoDoPersonagem.carregar(SAVE)
	companhia.progressao = recarregado
	MapaMontador.montar_peca(raiz, p)
	companhia.ligar_no_mapa(raiz, mapa, bib)
	verificar(recarregado.pets.size() == iniciais + 1 and recarregado.tem_pet(id), "save/reload e reentrada não duplicam o pet")
	verificar(companhia.quantos_fora() == 0, "recarregar continua com o cavalo guardado")
	verificar(companhia.chamar(id), "invocação pelo fluxo companhia cria o cavalo")
	var pet := companhia.pet_fora(id)
	verificar(pet != null and pet is PetDomado and pet.especie == "cavalo_da_vila_leve", "corpo invocado usa a espécie e o controlador corretos")
	verificar(pet != null and pet.global_position.distance_to(dono.global_position) < 5.0, "invocação posiciona pet perto do dono")
	companhia.recolher(id)
	await process_frame
	verificar(companhia.quantos_fora() == 0 and recarregado.tem_pet(id) and get_nodes_in_group("pets_historia").is_empty(), "recolher remove corpo e conserva inventário")
	verificar(companhia.chamar(id), "pet pode ser invocado novamente")
	pet = companhia.pet_fora(id)
	if pet != null:
		pet.take_damage(10000.0, Vector3.ZERO)
	verificar(not recarregado.tem_pet(id) and companhia.quantos_fora() == 0, "morte remove pet definitivamente pelo fluxo normal")
	verificar(recarregado.salvar(SAVE) == OK, "salva perda do pet mantendo concessão")
	companhia.progressao = ProgressaoDoPersonagem.carregar(SAVE)
	MapaMontador.montar_peca(raiz, p)
	companhia.ligar_no_mapa(raiz, mapa, bib)
	verificar(not companhia.progressao.tem_pet(id) and companhia.progressao.pets.size() == iniciais, "reentrada após morte não ressuscita nem duplica cavalo")
	verificar(not companhia.chamar(id), "pet morto não pode ser invocado")
	companhia.progressao.reiniciar()
	verificar(companhia.progressao.pets_do_mapa_recebidos.is_empty(), "nova campanha limpa concessões da campanha anterior")
	mundo.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("CAVALO_GUARDADO_RESULTADO falhas=", falhas)
	quit(1 if falhas else 0)
