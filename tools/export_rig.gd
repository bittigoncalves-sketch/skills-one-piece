extends SceneTree
# Exporta o PERFIL DO RIG de cada personagem para JSON, que o editor de animação
# em Python consome. Usa o próprio BodyScanner, então o editor enxerga
# exatamente o mesmo rig que o jogo — voxel ou skinnado, sem caminho especial.
#
# Uso: godot --headless --path . -s tools/export_rig.gd

const SAIDA := "res://tools/anim_editor/rigs/"
const PERSONAGENS := ["base", "buggy", "nami", "ace", "blackbeard", "crocodile"]

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var indice: Array = []
	for cid in PERSONAGENS:
		var d := CharacterBuilder.build_character(cid)
		var modelo: Node3D = d["node"]
		get_root().add_child(modelo)
		var prof := BodyScanner.scan(modelo)
		var nodes: Dictionary = prof["nodes"]
		if nodes.is_empty():
			print("  ✗ ", cid, ": sem papéis")
			modelo.queue_free()
			continue

		var papeis := {}
		var skinnado: bool = d.get("skinned", false)
		var drv = prof.get("driver")

		if skinnado and drv != null:
			# SKINNADO: os proxies do SkeletonDriver são irmãos SOLTOS (position é
			# global, não local ao papel-pai) e vivem no espaço do ESQUELETO, que
			# nos modelos Meshy é Z-UP. Sem converter pela basis do driver e sem
			# tirar a posição do pai, o editor monta o boneco deitado e espalhado.
			var A: Basis = drv._axis
			var glob := {}
			for papel in BodyScanner.ROLES:
				if nodes.has(papel):
					glob[papel] = A * (nodes[papel] as Node3D).position
			for papel in BodyScanner.ROLES:
				if not glob.has(papel):
					continue
				var pai: String = SkeletonDriver.RIG_PARENT.get(papel, "")
				if not glob.has(pai):
					pai = ""
				var local: Vector3 = glob[papel] - (glob[pai] if pai != "" else Vector3.ZERO)
				papeis[papel] = {
					"parent": pai,
					"pos": _v(local),
					"rest": [0.0, 0.0, 0.0],   # proxies nascem sem rotação
					"box": _caixa(null, papel, prof["metrics"]),
				}
		else:
			for papel in BodyScanner.ROLES:
				if not nodes.has(papel):
					continue
				var n: Node3D = nodes[papel]
				papeis[papel] = {
					"parent": _papel_pai(n, nodes),
					"pos": _v(n.position),
					"rest": _v(n.rotation),
					"box": _caixa(n, papel, prof["metrics"]),
				}

		var dados := {
			"character": cid,
			"skinned": d.get("skinned", false),
			"metrics": _metricas(prof["metrics"]),
			"order": _ordem(papeis),
			"roles": papeis,
		}
		var caminho: String = SAIDA + cid + ".json"
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		f.store_string(JSON.stringify(dados, "  "))
		f.close()
		indice.append(cid)
		print("  ✓ ", cid, "  papéis=", papeis.size(), "  skinnado=", d.get("skinned", false))
		modelo.queue_free()

	var fi := FileAccess.open(SAIDA + "index.json", FileAccess.WRITE)
	fi.store_string(JSON.stringify({"characters": indice}, "  "))
	fi.close()
	print("RIGS EXPORTADOS: ", indice.size())
	quit()

# Papel-pai = o primeiro ancestral que também é um papel do rig.
func _papel_pai(n: Node3D, nodes: Dictionary) -> String:
	var p := n.get_parent()
	while p != null:
		for papel in nodes:
			if nodes[papel] == p:
				return papel
		p = p.get_parent()
	return ""

# Caixa para desenhar o membro. Nos modelos voxel o próprio nó (ou um filho
# "<papel>M") é a malha; no skinnado não há caixa, então sintetizo uma a partir
# do comprimento do segmento.
func _caixa(n, papel: String, met: Dictionary) -> Dictionary:
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi == null and n != null:
		var filho = (n as Node3D).get_node_or_null(NodePath(papel + "M"))
		if filho is MeshInstance3D:
			mi = filho
	if mi != null and mi.mesh != null:
		var ab: AABB = mi.mesh.get_aabb()
		var off := ab.position + ab.size * 0.5
		if mi != n:
			off += mi.position
		return {"size": _v(ab.size), "offset": _v(off)}

	# skinnado: caixa sintética pendurada em -Y
	var comp := 0.28
	if papel.begins_with("Thigh"):
		comp = met.get("thigh_len", 0.3)
	elif papel.begins_with("Shin"):
		comp = met.get("shin_len", 0.3)
	elif papel.begins_with("UpperArm") or papel.begins_with("ForeArm"):
		comp = met.get("upper_arm", 0.3)
	elif papel == "Torso":
		comp = 0.55
	elif papel == "Head":
		comp = 0.4
	var esp: float = clampf(comp * 0.45, 0.08, 0.42)
	if papel == "Torso":
		return {"size": [esp * 1.7, comp, esp], "offset": [0.0, 0.0, 0.0]}
	if papel == "Head":
		return {"size": [comp, comp, comp], "offset": [0.0, comp * 0.4, 0.0]}
	if papel.begins_with("Foot"):
		return {"size": [esp, esp * 0.5, comp * 0.9], "offset": [0.0, -esp * 0.3, -comp * 0.25]}
	return {"size": [esp, comp, esp], "offset": [0.0, -comp * 0.5, 0.0]}

func _metricas(m: Dictionary) -> Dictionary:
	var o := {}
	for k in m:
		o[k] = float(m[k])
	return o

# Pais antes dos filhos — o editor faz cinemática direta nessa ordem.
func _ordem(papeis: Dictionary) -> Array:
	var out: Array = []
	var pend: Array = papeis.keys()
	while not pend.is_empty():
		var mexeu := false
		for papel in pend.duplicate():
			var pai: String = papeis[papel]["parent"]
			if pai == "" or out.has(pai):
				out.append(papel)
				pend.erase(papel)
				mexeu = true
		if not mexeu:
			out.append_array(pend)
			break
	return out

func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.00001), snappedf(v.y, 0.00001), snappedf(v.z, 0.00001)]
