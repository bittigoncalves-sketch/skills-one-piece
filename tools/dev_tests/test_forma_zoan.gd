extends SceneTree
# ============================================================================
#  FORMAS ZOAN DO JOGADOR (09/11/2026): J muda o atributo do mod E o jogo desenha a forma (modelo + textura do mod) seguindo o corpo.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_forma_zoan.gd
# ============================================================================
const PE_PELO_VISUAL := ["ryu_ryu_pteranodon", "tori_tori_phoenix"]
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _aabb(no: Node3D) -> AABB:
	var r := AABB()
	var primeiro := true
	for m in no.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		r = a if primeiro else r.merge(a)
		primeiro = false
	return r

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_forma_zoan.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var formas: Dictionary = FormaZoan.dados()
	ok(formas.size() == 14, "o JSON traz as 14 frutas da tag can_transform (%d)" % formas.size())
	for id in formas:
		modo.equipar_fruta(j, "")
		await quadros(3)
		modo.equipar_fruta(j, id)
		await quadros(8)
		var c = j.get_node_or_null("FrutaMinePiece")
		ok(j.get_node_or_null("FormaZoan") == null, "%s: antes de transformar não há forma" % id)
		c.transformar(false)
		await quadros(6)
		var f: FormaZoan = j.get_node_or_null("FormaZoan")
		ok(f != null, "%s: J desenha a forma (forma do mod = %d)" % [id, c.forma_atual()])
		if f == null:
			continue
		var malhas := f.find_children("*", "MeshInstance3D", true, false)
		ok(malhas.size() > 0, "%s: %d peças com malha" % [id, malhas.size()])
		var tex_ok := malhas.all(func(m):
			var mat := m.material_override as StandardMaterial3D
			return mat != null and (mat.vertex_color_use_as_albedo if id == "hito_hito_daibutsu" else mat.albedo_texture != null))
		ok(tex_ok, "%s: todas as peças têm textura ou paleta autoral do mod" % id)
		var sem_junta: Array = []
		for nome in f._topo:
			if f._juntas.get(nome) == null:
				sem_junta.append(nome)
		ok(sem_junta.is_empty(), "%s: toda peça de topo achou sua junta no rig (%s)" % [id, str(sem_junta)])
		var orfas: Array = []
		for filho in f.get_children():
			if filho is Node3D and not f._topo.values().has(filho):
				orfas.append(str(filho.name))
		ok(orfas.is_empty(), "%s: nenhuma peça de topo fica parada, sem seguir o corpo (órfãs: %s)" % [id, str(orfas)])
		var a := _aabb(f)
		var pes: float = j._char_model.global_position.y
		var capsula: float = j._colisor.shape.height
		ok(a.size.y > capsula * 0.7 and a.size.y < capsula * 2.0, "%s: altura da forma %.2f m com cápsula %.2f (esperado 0,7–2× a cápsula)" % [id, a.size.y, capsula])
		# Pteranodon e Fênix: o AABB inclui asa/cauda fora das pernas (pernas curtas/aves) e não mede o pé — validação VISUAL pendente.
		ok(PE_PELO_VISUAL.has(id) or absf(a.position.y - pes) < 0.15 * maxf(1.0, capsula), "%s: base da forma perto dos pés (%.2f vs %.2f)" % [id, a.position.y, pes])
		var esconde := FormaZoan.substitui_corpo(id)
		ok(j._char_model.visible == not esconde, "%s: corpo do jogador %s" % [id, "escondido" if esconde else "mantido (só acrescenta peças)"])
		# orientação: a frente do modelo do mod (+Z no espaço dele) tem de ser a frente do corpo (−Z), e o braço direito, o direito.
		var frente: Vector3 = f.global_basis * Vector3(0, 0, 1)
		var frente_jogador: Vector3 = -j._char_model.global_basis.z.normalized()
		ok(frente.dot(frente_jogador) > 0.99, "%s: a forma olha para onde o jogador olha (%.2f)" % [id, frente.dot(frente_jogador)])
		var braco_d: Node3D = f._topo.get("RightArm")
		if braco_d != null:
			var lado: float = (braco_d.global_position - f.global_position).dot(j._char_model.global_basis.x.normalized())
			ok(lado > 0.0, "%s: o braço direito da forma fica do lado direito do jogador (%.2f m)" % [id, lado])
		# a forma segue o corpo: mexer o braço direito do jogador mexe a peça RightArm
		var junta: Node3D = f._juntas.get("RightArm")
		var peca: Node3D = f._topo.get("RightArm")
		if junta != null and peca != null:
			var antes := peca.basis
			junta.rotate_x(0.9)
			await quadros(2)
			ok(not peca.basis.is_equal_approx(antes), "%s: braço da forma acompanha o braço do jogador" % id)
			junta.rotate_x(-0.9)
		if id == "ushi_ushi_giraffe":
			# Três formas (21/11/2026): o 2º J vira a girafa quadrúpede; só o 3º volta ao normal.
			c.transformar(false)
			await quadros(50)                      # a troca de forma trava o corpo por 0,6 s
			ok(j.get_node_or_null("FormaGirafa") != null and j.get_node_or_null("FormaZoan") == null, "ushi_ushi_giraffe: 2º J vira a girafa quadrúpede")
		c.transformar(false)
		await quadros(6)
		ok(j.get_node_or_null("FormaZoan") == null and j.get_node_or_null("FormaGirafa") == null and j._char_model.visible, "%s: J de novo volta ao normal (forma %d)" % [id, c.forma_atual()])
	# Desequipar a fruta ESTANDO transformado (caminho do `_exit_tree`): volta ao normal sem forma sobrando nem travar.
	modo.equipar_fruta(j, "")
	await quadros(3)
	modo.equipar_fruta(j, "batto_batto")
	await quadros(8)
	j.get_node("FrutaMinePiece").transformar(false)
	await quadros(6)
	ok(j.get_node_or_null("FormaZoan") != null, "Batto: transformado")
	modo.equipar_fruta(j, "gomu_gomu")
	await quadros(8)
	ok(j.get_node_or_null("FormaZoan") == null and j._char_model.visible and not j.get_meta(FormaZoan.META_ATIVA, false), "trocar de fruta transformado desfaz a forma e devolve o corpo")
	print("\nforma zoan: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
