extends Node3D
## Os pets do jogador que estão FORA do inventário, um corpo por pet. Pets colocados no
## editor ganham o mesmo controlador. A biblioteca continua sendo dado: só o modo
## história interpreta o comportamento.
##
## 30/09/2026 (pedido do dono): vários pets (`CatalogoDePets`), tirados e guardados pelo
## inventário (tecla N), cada um com o seu comportamento (menu B, `ModoDoPet`), que fica
## salvo no progresso. `chamar()`/`recolher()` sem espécie continuam sendo o caranguejo.
##
## 01/10/2026 (pedido do dono): herbívoros domados com fruta viram pets (`PetDomado`) —
## quantos o jogador quiser, NO MÁXIMO 6 FORA ao mesmo tempo; pet que morre é apagado
## do progresso para sempre (vale também para a gaivota e o caranguejo). Tudo aqui é por
## ID DO PET (os iniciais têm id = espécie, por isso `chamar("caranguejo")` segue igual).
const Caranguejo := preload("res://src/historia/pets/caranguejo.gd")
const FichaMontaria := preload("res://src/historia/pets/ficha_montaria.gd")
const COMPORTAMENTO := "pet_caranguejo"
const MAX_FORA := 6
const EM_CORRIDA := "em_corrida"
const CAVALO_DA_VILA := "animals__farm__horse_1__base_1"
## Algo mudou (tirou, guardou, morreu): o inventário se atualiza.
signal pets_mudaram
## Um pet morreu (já apagado do progresso). O HUD avisa.
signal pet_morreu(nome: String)
var alvo_de: Callable
## Quem sabe quais pets o jogador tem e o modo de cada um. Nulo = sem restrição (teste).
var progressao: ProgressaoDoPersonagem = null
var _fora := {}   # id do pet → corpo
## Por que o último `chamar` falhou ("" = não falhou). O inventário mostra.
var motivo := ""

## O caranguejo fora (compatível com quem já usava `invocado`).
var invocado: CharacterBody3D:
	get: return pet_fora("caranguejo")


func pet_fora(id: String) -> CharacterBody3D:
	var pet: CharacterBody3D = _fora.get(id)
	return pet if is_instance_valid(pet) else null


func esta_fora(id: String) -> bool:
	return pet_fora(id) != null


## Os corpos dos pets fora do inventário agora, por id (a corrida de caranguejos pausa
## os outros enquanto corre longe da ilha).
func corpos_fora() -> Dictionary:
	var r := {}
	for id in _fora:
		if pet_fora(id) != null:
			r[id] = pet_fora(id)
	return r


func quantos_fora() -> int:
	var n := 0
	for id in _fora:
		if pet_fora(id) != null:
			n += 1
	return n


func _especie(id: String) -> String:
	return progressao.especie_do_pet(id) if progressao != null else id


## Tira o pet do inventário para perto do dono (ou o traz de volta, se já estiver fora).
## `ponto_dado` põe o pet num ponto escolhido por quem chama (a tripulação, no mar, onde não
## há chão livre ao lado do dono para a busca de sempre).
func chamar(id := "caranguejo", ponto_dado: Variant = null) -> bool:
	motivo = ""
	var alvo: Node3D = alvo_de.call() if alvo_de.is_valid() else null
	if not is_instance_valid(alvo):
		return false
	if progressao != null and not progressao.tem_pet(id):
		return false
	var especie := _especie(id)
	var pet := pet_fora(id)
	if pet != null and pet.has_meta("cavaleiro"):
		motivo = "Desmonte com Y antes de chamar esta montaria."
		return false
	if pet == null and quantos_fora() >= MAX_FORA:
		motivo = "Já há %d pets fora (máximo). Guarde um antes." % MAX_FORA
		return false
	var ponto: Variant = ponto_dado if ponto_dado is Vector3 else _ponto_para(especie, alvo, pet)
	if not ponto is Vector3:
		motivo = "Não há lugar livre por perto"
		return false
	if pet == null:
		pet = _novo_corpo(id, especie)
		if pet == null:
			motivo = "Espécie \"%s\" não existe mais na loja" % especie
			return false
		pet.position = to_local(ponto)
		add_child(pet)
		_fora[id] = pet
	else:
		pet.global_position = ponto
		pet.velocity = Vector3.ZERO
	pets_mudaram.emit()
	return true


## O corpo do pet: cena própria (gaivota, caranguejo) ou o animal da loja (domado).
func _novo_corpo(id: String, especie: String) -> CharacterBody3D:
	var modo_salvo: StringName = progressao.modo_do_pet(id) if progressao != null else CatalogoDePets.modo_inicial(especie)
	var pet: CharacterBody3D
	if CatalogoDePets.existe(especie):
		pet = (load(String(CatalogoDePets.ESPECIES[especie]["cena"])) as GDScript).new()
		pet.name = id.capitalize().replace(" ", "") + "Companheiro"
		pet.alvo_de = alvo_de
		# O modo ANTES de entrar na árvore: o `_ready` do pet já decide por ele.
		pet.modo = modo_salvo
		if progressao != null:
			pet.nome_exibido = progressao.nome_do_pet(id)
	else:
		var bib := MapaMontador.biblioteca_em_uso()
		var ficha := FichaMontaria.animal(bib, especie) if bib.tem(especie) else {}
		if ficha.is_empty():
			return null
		var domado := PetDomado.new()
		domado.montar_pet(bib, especie, ficha, id, progressao.nome_do_pet(id) if progressao != null else especie, modo_salvo)
		FichaMontaria.orientar(domado)
		domado.alvo_de = alvo_de
		domado.collision_layer = 0          # como os outros pets: não bloqueia nem é golpeado pelo dono
		pet = domado
	pet.modo_mudou.connect(func(novo: StringName):
		if progressao != null:
			progressao.definir_modo_do_pet(id, novo))
	pet.morreu.connect(func(_quem): _ao_morrer(id))
	return pet


## Herbívoro domado agora: vira pet no progresso e, se couber, já sai no lugar dele.
## Devolve {id, fora}.
func adotar(especie: String, nome: String, posicao: Vector3, yaw: float) -> Dictionary:
	var id := progressao.adicionar_pet(especie, nome) if progressao != null else especie
	if quantos_fora() >= MAX_FORA:
		pets_mudaram.emit()
		return {"id": id, "fora": false}
	var pet := _novo_corpo(id, especie)
	if pet == null:
		return {"id": id, "fora": false}
	pet.position = to_local(posicao)
	add_child(pet)
	if pet.has_method("definir_modo"):
		pet.definir_modo(ModoDoPet.SEGUIR)
	var visual: Variant = pet.get("_visual")
	if visual is Node3D:
		pet.set("_yaw", yaw)
		(visual as Node3D).rotation.y = yaw + float(pet.get("_desvio_yaw"))
	_fora[id] = pet
	pets_mudaram.emit()
	return {"id": id, "fora": true}


## Morreu: sai do progresso DE VEZ; o corpo fica um instante (animação de morte) e some.
func _ao_morrer(id: String) -> void:
	var nome := progressao.nome_do_pet(id) if progressao != null else id
	if progressao != null:
		progressao.remover_pet(id)
	var pet := pet_fora(id)
	_fora.erase(id)
	if pet != null:
		pet.remove_from_group("pets_historia")
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(pet):
				pet.queue_free())
	pet_morreu.emit(nome)
	pets_mudaram.emit()


## Guarda o pet de volta no inventário.
func recolher(id := "caranguejo") -> void:
	var pet := pet_fora(id)
	# Corrida de caranguejos: guardar o caranguejo desmontaria o jogador (a trava diz que
	# não dá para sair dele até o fim).
	if pet != null and pet.has_meta(EM_CORRIDA):
		motivo = "O caranguejo está correndo: só depois da corrida."
		return
	if pet != null:
		# O pet pode estar no convés de um barco (tripulação): o pai não é só a companhia.
		if pet.get_parent() != null:
			pet.get_parent().remove_child(pet)
		pet.queue_free()
	_fora.erase(id)
	pets_mudaram.emit()


## Onde o pet aparece: a gaivota no AR, ao lado e acima do dono (ela voa); os outros
## num chão livre ao lado.
func _ponto_para(especie: String, alvo: Node3D, pet: CharacterBody3D) -> Variant:
	if especie == "gaivota":
		var lado := alvo.global_transform.basis.x.normalized()
		return alvo.global_position + lado * 1.6 + Vector3.UP * 2.2
	if especie == "caranguejo" or pet is Caranguejo:
		return Caranguejo.ponto_seguro(alvo, pet)
	var lado2 := alvo.global_transform.basis.x.normalized()
	var p := alvo.global_position + lado2 * 2.2
	var h := alvo.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 30.0, 1))
	return (h["position"] as Vector3) + Vector3.UP * 0.05 if not h.is_empty() else p

func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos) -> int:
	var quantidade := 0
	for p: Dictionary in mapa["pecas"]:
		if _ligar_montaria_do_mapa(raiz, p, biblioteca):
			quantidade += 1
			continue
		if p["tipo"] != "modelo" or not biblioteca.tem(p["modelo"]) \
				or not biblioteca.categorias_do_modelo(p["modelo"]).has("pets") \
				or biblioteca.comportamento_do_modelo(p["modelo"]) != COMPORTAMENTO:
			continue
		var original := raiz.get_node_or_null(NodePath(str(p["id"]))) as Node3D
		if original == null:
			continue
		var pet := Caranguejo.new()
		pet.name = "Pet_" + str(p["id"])
		pet.alvo_de = alvo_de
		var info := biblioteca.info(p["modelo"])
		pet.escala_modelo = (p["tamanho"] as Vector3) / (info["tamanho"] as Vector3)
		var yaw := deg_to_rad((p["rotacao_graus"] as Vector3).y)
		pet.position = (p["posicao"] as Vector3) - Basis(Vector3.UP, yaw) * ((info["centro"] as Vector3) * pet.escala_modelo)
		pet.distancia_parar *= maxf(1.0, maxf(pet.escala_modelo.x, pet.escala_modelo.z))
		pet.distancia_retomar = pet.distancia_parar + .9
		# Escala do editor vale no visual e no colisor; o corpo mantém postura vertical.
		# Retirar o marcador remove também a colisão estática que prenderia o pet.
		raiz.remove_child(original)
		original.queue_free()
		raiz.add_child(pet)
		pet.visual.rotation.y = deg_to_rad((p["rotacao_graus"] as Vector3).y)
		quantidade += 1
	return quantidade


## Cavalos e outros pets classificados no editor ganham corpo vivo, sem exigir
## uma área de spawn nem alterar o arquivo do mapa. Caranguejo usa o caminho próprio.
func _ligar_montaria_do_mapa(raiz: Node3D, p: Dictionary, bib: BibliotecaDeModelos) -> bool:
	if p["tipo"] != "modelo" or not FichaMontaria.classificado(bib, p["modelo"]) \
			or not bib.categorias_do_modelo(p["modelo"]).has("pets") \
			or bib.comportamento_do_modelo(p["modelo"]) == COMPORTAMENTO:
		return false
	var original := raiz.get_node_or_null(NodePath(str(p["id"]))) as Node3D
	if original == null:
		return false
	# Este cavalo pertence ao jogador, mas começa guardado como os pets iniciais.
	# Não criamos um PetDomado LIVRE: sua recuperação ao empacar o traria até o
	# jogador sem invocação. Só removemos o marcador runtime; o mapa fica intacto.
	if str(p["id"]) == CAVALO_DA_VILA and str(p["modelo"]) == "cavalo_da_vila_leve":
		if progressao == null:
			return false
		var recebido := progressao.receber_pet_do_mapa(CAVALO_DA_VILA, str(p["modelo"]), "Cavalo da vila")
		raiz.remove_child(original)
		original.queue_free()
		if not recebido.is_empty():
			pets_mudaram.emit()
		return true
	var pet := PetDomado.new()
	pet.montar_pet(bib, p["modelo"], FichaMontaria.animal(bib, p["modelo"]), str(p["id"]), str(bib.info(p["modelo"])["nome"]), ModoDoPet.LIVRE)
	FichaMontaria.orientar(pet)
	pet.alvo_de = alvo_de
	pet.collision_layer = 0
	FichaMontaria.redimensionar(pet, p["tamanho"], bib)
	pet.position = p["posicao"] - Vector3.UP * (p["tamanho"] as Vector3).y * .5
	raiz.remove_child(original)
	original.queue_free()
	raiz.add_child(pet)
	pet._visual.rotation.y = deg_to_rad((p["rotacao_graus"] as Vector3).y)
	pet._yaw = pet._visual.rotation.y - pet._desvio_yaw
	return true
