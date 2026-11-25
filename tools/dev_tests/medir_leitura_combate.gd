extends SceneTree
# ============================================================================
#  MEDIR A LEITURA DOS GOLPES NA CÂMERA REAL — sonda de autoria (não é teste de bateria).
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (§8.3). Com a câmera de 3ª pessoa do jogo
#  (ombro direito, 4 m), mede para cada golpe — duas vezes: o golpe do PRÓPRIO jogador
#  (o que ele vê de si) e o golpe do ADVERSÁRIO vindo nele (é essa a leitura que decide
#  a defesa):
#    • onde o punho do efetor cai NA TELA no fim da carga e no contato;
#    • para onde o punho VAI na tela da guarda ao fim da carga (vetor em px) e o menor
#      ÂNGULO entre as 4 direções — é o que o defensor lê ("armou para a esquerda", "subiu").
#      A posição absoluta não serve: punhos das duas mãos vivem perto da linha central, e a
#      5 m da câmera 0,38 m de braço aberto são ~40 px (medido em 17/09);
#    • se o punho está ESCONDIDO atrás do tronco (visto pela câmera): o raio câmera→punho
#      atravessa a caixa do peito/cintura antes de chegar a ele.
#
#  Com tela (a projeção usa o tamanho real da janela):
#    godot --path . --resolution 1280x720 --script tools/dev_tests/medir_leitura_combate.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://medir_leitura_combate.json"
## Papéis cujas malhas (filhas diretas) escondem o punho: tronco e cabeça.
const OCLUSORES := ["Pelvis", "SpineLower", "SpineMid", "Chest", "Head"]


func _init() -> void:
	await process_frame
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var jogador: Node = null
	for p in get_root().get_tree().get_nodes_in_group("player"):
		jogador = p
	jogador.capacidades = CapacidadesDoJogador.completas()
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	var ap := AplicadorDePose.new()
	ap.montar(jogador.modelo_visual())
	var caixas := _caixas_do_tronco(jogador.modelo_visual())
	print("tronco: %d malhas de referência" % caixas.size())
	var na_carga := {}
	for golpe in e.estilo.golpes:
		for i in 60:
			await physics_frame
		jogador._yaw = 0.0
		jogador._pitch = -0.15
		for i in 20:
			await physics_frame
		e.pedir_ataque(golpe.direcao)
		var linha := "%-20s" % golpe.id
		for marco in [["carga", golpe.preparo * 0.92], ["contato", golpe.preparo + golpe.ativo * 0.5]]:
			while e.atacando() and e.tempo_da_acao() < marco[1]:
				await physics_frame
			await process_frame
			var cam := get_root().get_viewport().get_camera_3d()
			var punho := ap.posicao_global(golpe.efetor)
			var tela := cam.unproject_position(punho)
			var escondido := _escondido(cam.global_position, punho, caixas)
			if marco[0] == "carga":
				na_carga[golpe.direcao] = tela
			linha += " | %s: tela (%4.0f, %4.0f) %s" % [marco[0], tela.x, tela.y, "ESCONDIDO" if escondido else "visível"]
		print(linha)
		while e.atacando():
			await physics_frame
	_separacao("do PRÓPRIO jogador", na_carga)

	# O adversário: boneco a 1,1 m, de frente, golpeando o jogador. É o que se lê para defender.
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.vida_maxima = 100000.0
	boneco.position = Vector3(0, 0.8, -4.0)
	current_scene.add_child(boneco)
	for i in 60:
		await physics_frame
	jogador.velocity = Vector3.ZERO
	jogador.global_position = Vector3(0, jogador.global_position.y, 0)
	await physics_frame
	await physics_frame
	boneco.parar()
	boneco.global_position = Vector3(0, jogador.global_position.y, -1.1)
	boneco.encarar_yaw(PI)
	boneco.modelo_visual().rotation.y = PI
	var b: ExecutorCorpoACorpo = boneco.combate_direcional
	var apb := AplicadorDePose.new()
	apb.montar(boneco.modelo_visual())
	var caixas_b := _caixas_do_tronco(boneco.modelo_visual())
	var do_boneco := {}
	# Aquecimento: sem uma ação recente o corpo ainda está com o animador (a camada de
	# combate entra em `transicao_entrada`), e a "guarda" de referência sairia dos braços
	# caídos do idle — foi o que inverteu o vetor do jab na primeira medição.
	b.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	while b.atacando():
		await physics_frame
	for golpe in b.estilo.golpes:
		for i in 60:
			await physics_frame
		jogador._yaw = 0.0
		jogador._pitch = -0.15
		boneco.global_position = Vector3(0, jogador.global_position.y, -1.1)
		for i in 10:
			await physics_frame
		b.pedir_ataque(golpe.direcao)
		var linha := "adversário %-9s" % GolpeDirecional.Direcao.keys()[golpe.direcao]
		for marco in [["guarda", 0.0], ["meio da carga", golpe.preparo * 0.5], ["carga", golpe.preparo * 0.92]]:
			while b.atacando() and b.tempo_da_acao() < marco[1]:
				await physics_frame
			await process_frame
			var cam := get_root().get_viewport().get_camera_3d()
			var punho := apb.posicao_global(golpe.efetor)
			var tela := cam.unproject_position(punho)
			if marco[0] == "guarda":
				do_boneco[golpe.direcao] = tela
			elif marco[0] == "carga":
				do_boneco[golpe.direcao] = tela - (do_boneco[golpe.direcao] as Vector2)
			linha += " | %s: tela (%4.0f, %4.0f) %s" % [marco[0], tela.x, tela.y,
				"ESCONDIDO" if _escondido(cam.global_position, punho, caixas_b) else "visível"]
		print(linha)
		while b.atacando():
			await physics_frame
	_separacao("do ADVERSÁRIO (a que decide a defesa)", do_boneco)
	_angulos(do_boneco)
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	quit(0)


func _separacao(rotulo: String, pontos: Dictionary) -> void:
	var menor := INF
	var par := ""
	var chaves := pontos.keys()
	for i in chaves.size():
		for j in range(i + 1, chaves.size()):
			var d: float = (pontos[chaves[i]] as Vector2).distance_to(pontos[chaves[j]])
			if d < menor:
				menor = d
				par = "%s × %s" % [GolpeDirecional.Direcao.keys()[chaves[i]], GolpeDirecional.Direcao.keys()[chaves[j]]]
	print("tela %s — golpe %s: menor separação entre direções no fim da carga %.0f px (%s)"
		% [get_root().get_viewport().get_visible_rect().size, rotulo, menor, par])


## `vetores`: direção → deslocamento do punho na tela, da guarda ao fim da carga.
func _angulos(vetores: Dictionary) -> void:
	var menor := INF
	var par := ""
	var chaves := vetores.keys()
	var linha := "   carga do adversário (px, guarda → fim da carga):"
	for k in chaves:
		var v: Vector2 = vetores[k]
		linha += " %s (%+.0f, %+.0f) |%.0f|;" % [GolpeDirecional.Direcao.keys()[k], v.x, v.y, v.length()]
	print(linha)
	for i in chaves.size():
		for j in range(i + 1, chaves.size()):
			var a: Vector2 = vetores[chaves[i]]
			var b: Vector2 = vetores[chaves[j]]
			if a.length() < 0.5 or b.length() < 0.5:
				continue
			var ang := rad_to_deg(absf(a.angle_to(b)))
			if ang < menor:
				menor = ang
				par = "%s × %s" % [GolpeDirecional.Direcao.keys()[chaves[i]], GolpeDirecional.Direcao.keys()[chaves[j]]]
	print("   menor ângulo entre as cargas de duas direções: %.0f° (%s)" % [menor, par])


func _caixas_do_tronco(modelo: Node3D) -> Array:
	var caixas := []
	for papel in OCLUSORES:
		var n := modelo.find_child(papel, true, false)
		if n == null:
			continue
		for filho in n.get_children():
			if filho is MeshInstance3D:
				caixas.append(filho)
	return caixas


## O segmento câmera→punho atravessa alguma caixa do tronco (no espaço de cada malha)?
func _escondido(de: Vector3, ate: Vector3, caixas: Array) -> bool:
	for m in caixas:
		var mi := m as MeshInstance3D
		var inv := mi.global_transform.affine_inverse()
		var a := inv * de
		var b := inv * ate
		var aabb := mi.get_aabb()
		if _segmento_cruza(a, b, aabb):
			return true
	return false


static func _segmento_cruza(a: Vector3, b: Vector3, caixa: AABB) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 0.97   # para um pouco antes do punho: tocar o próprio peito não é esconder
	for eixo in 3:
		if absf(d[eixo]) < 0.000001:
			if a[eixo] < caixa.position[eixo] or a[eixo] > caixa.end[eixo]:
				return false
		else:
			var ta := (caixa.position[eixo] - a[eixo]) / d[eixo]
			var tb := (caixa.end[eixo] - a[eixo]) / d[eixo]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return false
	return true
