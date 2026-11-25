class_name XpFlutuante
extends Node3D
## XP GANHO no nome do inimigo derrotado (pedido do dono, 15/11/2026): no lugar da plaqueta de nome aparece "Nome" e, abaixo, "+N XP" em dourado;
## o conjunto sobe ~1,3 m e desbota em ~2,4 s. Só desenho: o XP é concedido por `ProgressaoDoPersonagem.ganhar_xp_de_abate`, esta classe apenas mostra o número
## que o chamador já calculou (`previa_do_abate`). Vive na cena (o inimigo pode ter sumido), sempre de frente para a câmera, visível através de parede leve.
const DURACAO := 2.4
const SUBIDA := 1.3
const COR_NOME := Color(1, 1, 1)
const COR_XP := Color(1.0, 0.82, 0.25)


## Mostra sobre `no` (altura = `altura` do corpo + 0,45, a da plaqueta; 2,2 m se o corpo não declara). Devolve o nó (ou null se não há cena).
static func sobre(no: Node3D, nome: String, xp: int) -> XpFlutuante:
	if no == null or not is_instance_valid(no) or not no.is_inside_tree():
		return null
	var tem_plaqueta := not no.find_children("*", "Label3D", false, false).is_empty()
	var altura := 2.2
	var ficha: Variant = no.get("ficha")          # personagens do East Blue: a altura da ficha (a mesma da plaqueta de nome)
	if ficha is Dictionary and (ficha as Dictionary).has("altura"):
		altura = float((ficha as Dictionary).altura) + 0.45
	return mostrar(no.get_tree().current_scene, no.global_position + Vector3.UP * altura, "" if tem_plaqueta else nome, xp)


static func mostrar(cena: Node, onde: Vector3, nome: String, xp: int) -> XpFlutuante:
	if cena == null or xp <= 0:
		return null
	var n := XpFlutuante.new()
	cena.add_child(n)
	n.global_position = onde
	n._montar(nome, xp)
	return n


func _montar(nome: String, xp: int) -> void:
	# Com plaqueta de nome no corpo, ela fica onde está e o XP nasce LOGO ACIMA dela; sem plaqueta (`nome` != ""), o nome vem junto, abaixo do XP.
	var rotulos: Array[Label3D] = []
	var rotulo_xp := _texto("+%d XP" % xp, COR_XP, 64, 0.38)
	add_child(rotulo_xp)
	rotulos.append(rotulo_xp)
	if nome != "":
		var rotulo_nome := _texto(nome, COR_NOME, 44, 0.0)
		add_child(rotulo_nome)
		rotulos.append(rotulo_nome)
	# Estoura (cresce de 60% a 100%) e sobe, depois desbota.
	rotulo_xp.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(rotulo_xp, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y + SUBIDA, DURACAO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for r in rotulos:
		tw.tween_property(r, "modulate:a", 0.0, DURACAO * 0.4).set_delay(DURACAO * 0.6)
	tw.chain().tween_callback(queue_free)


func _texto(t: String, cor: Color, tamanho: int, y: float) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = tamanho
	l.pixel_size = 0.008
	l.outline_size = 14
	l.modulate = cor
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.no_depth_test = true
	l.fixed_size = false
	l.position.y = y
	return l
