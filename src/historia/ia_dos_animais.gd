class_name IaDosAnimais
extends IaUnificada
## IA UNIFICADA DOS ANIMAIS (10/11/2026): uma só IA para todos os animais — bichos da ilha (`AnimalDaIlha`) e bestas do mar (`Besta`) —
## e a ÚNICA diferença entre eles é a LOCOMOÇÃO: voador, aquático ou terrestre. A locomoção só muda os RAIOS de sono/despertar, porque o
## que muda é o que o jogador enxerga de longe: um voador no céu é visto de mais longe (acorda e dorme mais longe) que um bicho no chão;
## o aquático fica entre os dois. O resto — dormir, acordar por dano ou combate, repouso — é igual para todos.
## Chefes (harpia, serpente do mar…) nunca dormem. Não há coesão nem facção: animal não anda em esquadrão.

const VOADOR := "voador"
const AQUATICO := "aquatico"
const TERRESTRE := "terrestre"
## locomoção → (acordar, dormir) em metros
const RAIOS := {VOADOR: Vector2(80.0, 110.0), AQUATICO: Vector2(60.0, 90.0), TERRESTRE: Vector2(50.0, 70.0)}


func membros() -> Array:
	return get_tree().get_nodes_in_group("animais") + get_tree().get_nodes_in_group("bestas_do_mar")


## voador (corpo "voador"), aquático (besta do mar) ou terrestre (o resto).
static func locomocao_de(no: Node) -> String:
	if no.is_in_group("bestas_do_mar"):
		return AQUATICO
	var ficha = no.get("ficha")
	if ficha is Dictionary and FichaDeAnimal.voa(ficha):
		return VOADOR
	return TERRESTRE


func chave(no: Node) -> String:
	return locomocao_de(no)


func raios(k: String) -> Vector2:
	return RAIOS.get(k, RAIOS[TERRESTRE])


func e_gerenciavel(no: Node) -> bool:
	if not (no is Node3D) or not is_instance_valid(no) or not no.is_inside_tree():
		return false
	if no.is_in_group("chefes") or no.is_in_group("boss"):
		return false
	return not no.has_method("vivo") or bool(no.vivo())
