class_name Povoamento
extends RefCounted
## POVOAMENTO POR ILHA (10/11/2026, pedido do dono: "o spawn das criaturas fica restrito à ilha em que o jogador se encontra").
## Uma criatura de OUTRA ilha fica LATENTE: sai dos grupos (ninguém a enxerga como alvo/inimigo), não colide, some e não processa.
## Voltar ao jogador = `latente(no, false)` devolve tudo como estava (grupos, colisão, visibilidade, modo de processo).
## Não destrói nada: estado (vida, posição, renascimento pendente) fica guardado até o jogador voltar à ilha.
const META := "latente_estado"


static func esta_latente(no: Node) -> bool:
	return is_instance_valid(no) and no.has_meta(META)


static func latente(no: Node, sim: bool) -> void:
	if not is_instance_valid(no):
		return
	if sim:
		if no.has_meta(META):
			return
		var estado := {"grupos": {}, "colisao": {}, "visivel": (no as Node3D).visible if no is Node3D else true, "modo": no.process_mode}
		var donos: Array[Node] = [no]
		donos.append_array(no.get_children())               # ninho → boneco; os grupos que importam moram na raiz e nos filhos diretos
		for d in donos:
			var gs := []
			for g in d.get_groups():
				if not String(g).begins_with("_"):
					gs.append(String(g))
			if not gs.is_empty():
				estado.grupos[d.get_path()] = gs
				for g in gs:
					d.remove_from_group(g)
		var corpos: Array[Node] = [no]
		corpos.append_array(no.find_children("*", "CollisionObject3D", true, false))
		for c in corpos:
			if c is CollisionObject3D:
				estado.colisao[c.get_path()] = [(c as CollisionObject3D).collision_layer, (c as CollisionObject3D).collision_mask]
				(c as CollisionObject3D).collision_layer = 0
				(c as CollisionObject3D).collision_mask = 0
		no.set_meta(META, estado)
		if no is Node3D:
			(no as Node3D).visible = false
		no.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		if not no.has_meta(META):
			return
		var estado: Dictionary = no.get_meta(META)
		no.remove_meta(META)
		no.process_mode = int(estado.modo)
		if no is Node3D:
			(no as Node3D).visible = bool(estado.visivel)
		for caminho in estado.colisao:
			var c := no.get_node_or_null(_relativo(no, caminho)) as CollisionObject3D
			if c == null and String(no.get_path()) == String(caminho):
				c = no as CollisionObject3D
			if c != null:
				c.collision_layer = int(estado.colisao[caminho][0])
				c.collision_mask = int(estado.colisao[caminho][1])
		for caminho in estado.grupos:
			var d := no.get_node_or_null(_relativo(no, caminho))
			if d == null and String(no.get_path()) == String(caminho):
				d = no
			if d != null:
				for g in estado.grupos[caminho]:
					d.add_to_group(g)


static func _relativo(raiz: Node, caminho: NodePath) -> NodePath:
	var base := String(raiz.get_path())
	var s := String(caminho)
	return NodePath(s.trim_prefix(base).trim_prefix("/")) if s.begins_with(base) and s != base else NodePath(".")
