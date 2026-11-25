extends SceneTree
## Vai até os personagens da Marinha do East Blue (Marinheiro, Coby, Helmeppo), deixa a IA atacar e registra TUDO que nasce em
## cena durante o ataque: classe/script, se tem desenho (MeshInstance3D com malha, visível na árvore) e quantos quadros viveu.
## Responde "os projéteis dos marinheiros estão visíveis?". 30/10/2026.
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/medir_projeteis_marinha.gd -- [captura]
## Com janela e o argumento `captura`, salva um PNG da tela no quadro em que cada projétil aparece (user://captura_projeteis/).
const QUEM := ["marine_fuzil", "coby", "helmeppo"]
var _nascidos: Array[Dictionary] = []
var _janela := false

func _init() -> void:
	call_deferred("_r")

func _desenho(no: Node) -> Dictionary:
	var malhas := 0
	var visiveis := 0
	var estaticos: Array = no.find_children("*", "MeshInstance3D", true, false)
	for m in estaticos:
		if (m as MeshInstance3D).mesh != null:
			malhas += 1
			if (m as MeshInstance3D).is_visible_in_tree():
				visiveis += 1
	var particulas := no.find_children("*", "GPUParticles3D", true, false).size() + no.find_children("*", "CPUParticles3D", true, false).size()
	return {"malhas": malhas, "visiveis": visiveis, "particulas": particulas, "sprites": no.find_children("*", "Sprite3D", true, false).size()}

func _nasceu(no: Node) -> void:
	if not (no is Node3D) or not is_instance_valid(no):
		return
	var sp := ""
	if no.get_script() != null:
		sp = str((no.get_script() as Script).resource_path)
	_nascidos.append({"no": no, "classe": no.get_class(), "script": sp, "nome": str(no.name), "quadro": Engine.get_physics_frames()})

func _r() -> void:
	await process_frame
	_janela = DisplayServer.get_name() != "headless"
	var captura := "captura" in OS.get_cmdline_user_args() and _janela
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_projeteis.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://medir_projeteis.json"))
	root.get_node("GameFlow").start_story()
	var j: Node3D = null
	var limite := Time.get_ticks_msec() + 150000
	while j == null and Time.get_ticks_msec() < limite:
		await physics_frame
		j = get_first_node_in_group("player")
	for i in 240: await physics_frame
	j.set_meta("damage_immune", true)
	var cena := current_scene
	# As IAs do mod só rodam PERTO do jogador (o LOD congela quem está longe): vai até o acampamento dos marinheiros, espera
	# eles "nascerem" (o mod equipa no nascimento: SetTagMarine 30 % fuzil, 5 % lança-foguetes) e vê quem pegou arma.
	var marinheiros := get_nodes_in_group("personagens_east_blue").filter(func(p): return str(p.ficha.get("id", "")) == "marine")
	var alvo0: Node3D = marinheiros[0]
	j.global_position = alvo0.global_position + Vector3(0, 0.5, 14.0)
	j.set("velocity", Vector3.ZERO)
	for i in 900: await physics_frame
	var armados: Array = []
	var por_id := {}
	for p in get_nodes_in_group("personagens_east_blue"):
		var ee := McEntidade.de(p)
		var mao := ee.getMainHandItem()
		var id := str(p.ficha.get("id", "?"))
		por_id[id] = por_id.get(id, 0) + 1
		if not mao.isEmpty():
			armados.append(p)
			print("PROJ   armado: ", id, " ", mao.item.id, " | nasceu=", p.ia_do_mod.get("_nasceu"))
	var nascidos := 0
	for p in marinheiros:
		if p.ia_do_mod != null and p.ia_do_mod.get("_nasceu"):
			nascidos += 1
	print("PROJ marinheiros que já nasceram (IA do mod rodou): ", nascidos, "/", marinheiros.size(), " | com arma na mão: ", armados.size())
	var atirador: Node3D = null
	for p in armados:
		if str(p.ficha.get("id", "")) == "marine" and "rifle" in str(McEntidade.de(p).getMainHandItem().item.id):
			atirador = p
			break
	if atirador == null:
		print("PROJ nenhum marinheiro com fuzil entre os que nasceram")
	else:
		print("PROJ atirador escolhido: ", atirador.get_path(), " fuzil na mão; observando 20 s a 10 m")
		_nascidos.clear()
		var ouvinte := func(no: Node): _nasceu(no)
		node_added.connect(ouvinte)
		for o in get_nodes_in_group("enemy"):
			if o != atirador and o is Node3D and o != j:
				o.process_mode = Node.PROCESS_MODE_DISABLED
				(o as Node3D).global_position = Vector3(0, -800, 0)
		j.global_position = atirador.global_position + Vector3(0, 0.5, 10.0)
		for i in 1200:
			await physics_frame
			if i % 200 == 0:
				j.global_position = atirador.global_position + Vector3(0, 0.3, 10.0)
				j.set("velocity", Vector3.ZERO)
				var cer: Variant = atirador.get("cerebro")
				print("PROJ   t=%ds alvo=%s dist=%.1f" % [i / 60, str(cer.get("alvo")) if cer != null else "?", atirador.global_position.distance_to(j.global_position)])
		node_added.disconnect(ouvinte)
		var grupos := {}
		for n in _nascidos:
			var chave := "%s|%s" % [n.classe, n.script.get_file() if n.script != "" else "-"]
			if not grupos.has(chave):
				grupos[chave] = {"n": 0, "exemplo": n.no, "nome": n.nome}
			grupos[chave].n += 1
		for chave in grupos:
			var g: Dictionary = grupos[chave]
			var ex: Node = g.exemplo
			print("PROJ   nasceu %-46s x%-4d ex=%s desenho=%s" % [chave, g.n, g.nome, str(_desenho(ex)) if is_instance_valid(ex) else "(já sumiu)"])
	modo.set("progresso_forcado", "")
	quit()
