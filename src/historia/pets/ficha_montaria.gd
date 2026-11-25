extends RefCounted
## A categoria da loja é a classificação editável. Apenas pets vivos podem usá-la.
const CATEGORIA := "montarias"

static func modelo(pet: Node) -> String:
	var especie := str(pet.get("especie"))
	return "caranguejo_grande" if especie == "caranguejo" else especie

static func classificado(bib: BibliotecaDeModelos, id: String) -> bool:
	return bib.tem(id) and bib.categorias_do_modelo(id).has(CATEGORIA)

static func animal(bib: BibliotecaDeModelos, id: String) -> Dictionary:
	var f := bib.ficha_de_animal(id)
	if f.is_empty() and classificado(bib, id):
		f = FichaDeAnimal.nova("domestico", "quadrupede", {"vida": 120, "corrida": 7.0, "nome": bib.info(id)["nome"]})
	return f

static func orientar(pet: PetDomado) -> void:
	# Estes GLBs de cavalo têm o focinho para +Z; a locomoção usa -Z.
	if pet.especie in ["horse", "cavalo_da_vila_leve", "animals__farm__horse_1__base"]:
		pet._desvio_yaw = PI
		pet._visual.rotation.y = pet._yaw + pet._desvio_yaw

static func redimensionar(pet: PetDomado, tamanho: Vector3, bib: BibliotecaDeModelos) -> void:
	# Preserve os três eixos editados sem escalar o CharacterBody3D ou sua cápsula.
	var fator := tamanho / bib.tamanho_padrao(pet.especie)
	pet._modelo.scale *= fator
	pet._modelo.position *= fator
	pet._altura *= fator.y
	pet._comprimento = maxf(tamanho.x, tamanho.z)
	pet._raio = maxf(.06, minf(tamanho.x, tamanho.z) * .5)
	var col := pet.get_node("Colisao") as CollisionShape3D
	var capsula := col.shape as CapsuleShape3D
	capsula.radius = pet._raio
	capsula.height = maxf(pet._altura, pet._raio * 2.0 + .01)
	col.position.y = capsula.height * .5
	pet.animador._pes.clear()
	pet.animador.montar(pet._modelo, str(pet.ficha.get("corpo", "quadrupede")), pet._altura, pet._comprimento)

static func perfil(pet: Node3D) -> Dictionary:
	var largo := modelo(pet) == "caranguejo_grande"
	var escala: Vector3 = pet.get("escala_modelo") if largo and pet.get("escala_modelo") != null else Vector3.ONE
	var altura := 1.48 * escala.y if largo else float(pet.call("altura"))
	var escala_corpo := pet.global_basis.get_scale()
	# Assento é local do visual; o caranguejo já escala esse nó no editor.
	return {"largo": largo, "altura": altura, "assento": Vector3(0, 1.34 if largo else altura * .63, 0.08 if largo else 0),
		"desvio_yaw": PI * .5 if largo else float(pet.get("_desvio_yaw")),
		"andar": 3.6, "correr": 8.5 if largo else 7.0, "salto": 6.0,
		"raio": (maxf(escala.x, escala.z) if largo else float(pet.get("_raio"))) * maxf(escala_corpo.x, escala_corpo.z)}
