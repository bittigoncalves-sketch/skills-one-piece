extends SceneTree
## Contrato mecânico do asset, independente de Player, rede e avaliação artística.
const Forma := preload("res://src/effects/phoenix/forma_phoenix.gd")
var falhas := 0
var verificacoes := 0
var _relatadas: Dictionary = {}

func _initialize() -> void:
	call_deferred("_executar")

func _check(ok: bool, contexto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		if not _relatadas.has(contexto):
			_relatadas[contexto] = true
			printerr("FALHA: ", contexto)

func _executar() -> void:
	var snapshots: Dictionary = {}
	for fps in [30, 60]:
		snapshots[fps] = _simular(fps)
	var maior_diferenca := 0.0
	for fase: String in snapshots[30]:
		var a: Dictionary = snapshots[30][fase]
		var b: Dictionary = snapshots[60][fase]
		_check(a.estado == b.estado, "30/60 FPS estado ao fim de " + fase)
		for nome: String in a.poses:
			var ta: Transform3D = a.poses[nome]
			var tb: Transform3D = b.poses[nome]
			var distancia := ta.origin.distance_to(tb.origin)
			var angulo := ta.basis.get_rotation_quaternion().angle_to(tb.basis.get_rotation_quaternion())
			maior_diferenca = maxf(maior_diferenca, maxf(distancia, angulo))
			_check(distancia < 0.025 and angulo < 0.055, "30/60 FPS pose " + fase + ":" + nome)
	print("Comparação 30/60 FPS: maior diferença posição/rad=", maior_diferenca)
	print("PHOENIX_RIG verificações=", verificacoes, " falhas=", falhas)
	quit(0 if falhas == 0 else 1)

func _simular(fps: int) -> Dictionary:
	var inicio := Time.get_ticks_usec()
	var forma := Forma.new()
	get_root().add_child(forma)
	forma.set_process(false)
	var construcao_ms := (Time.get_ticks_usec() - inicio) / 1000.0
	var pivos: Array[Node3D] = []
	var malhas: Array[MeshInstance3D] = []
	_coletar(forma, pivos, malhas)
	var triangulos := 0
	var vertices := 0
	var superficies := 0
	var caixas: Array[AABB] = []
	for malha in malhas:
		caixas.append(malha.get_aabb())
		for s in malha.mesh.get_surface_count():
			superficies += 1
			var dados := malha.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = dados[Mesh.ARRAY_INDEX] if dados[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			vertices += vs.size()
			triangulos += int(ids.size()/3) if not ids.is_empty() else int(vs.size()/3)
	print("FPS=", fps, " construção_CPU_ms=", construcao_ms, " pivôs=", pivos.size(), " meshes=", malhas.size(), " superfícies=", superficies, " vértices=", vertices, " triângulos=", triangulos)
	_check(malhas.size() > 0 and triangulos > 0, "asset tem geometria")
	var fases := [
		["parado", 1.0, Vector3.ZERO, true, false, false],
		["andando", 2.0, Vector3(0,0,-3), true, false, false],
		["parar", 0.6, Vector3.ZERO, true, false, false],
		["sentar", 1.4, Vector3.ZERO, true, false, true],
		["sentado", 0.8, Vector3.ZERO, true, false, true],
		["levantar", 1.2, Vector3.ZERO, true, false, false],
		["decolar", 0.8, Vector3(0,2,-3), false, true, false],
		["voar", 2.0, Vector3(0,0,-8), false, true, false],
		["descer", 1.0, Vector3(0,-3,-2), false, false, false],
		["pousar", 0.8, Vector3.ZERO, true, false, false],
		["repouso_final", 1.0, Vector3.ZERO, true, false, false],
	]
	var estados: Dictionary = {}
	var snapshots: Dictionary = {}
	var minimos: Dictionary = {}
	var maximos: Dictionary = {}
	var anterior: Dictionary = {}
	var maior_passo := 0.0
	var erro_comprimento := 0.0
	var erro_apoio := 0.0
	var maior_caixa := Vector3.ZERO
	var simulacao_inicio := Time.get_ticks_usec()
	for fase: Array in fases:
		var nome: String = fase[0]
		forma.atualizar_movimento(fase[2], fase[3], fase[4], fase[5])
		var frames := int(round(float(fase[1])*fps))
		for frame in frames:
			forma._animar(1.0/fps)
			var medidas := forma.medidas_rig()
			estados[medidas.estado] = true
			for comprimentos: Array in medidas.comprimentos:
				var erro := maxf(absf(comprimentos[0]-Forma.COXA), absf(comprimentos[1]-Forma.CANELA))
				erro_comprimento = maxf(erro_comprimento, erro)
				_check(erro < 0.0001, "comprimentos invariantes " + nome)
			for pivo in pivos:
				var caminho := str(forma.get_path_to(pivo))
				_check(pivo.transform.is_finite(), "transform finito " + caminho)
				_check(pivo.basis.get_scale().distance_to(Vector3.ONE) < 0.0001, "escala unitária " + caminho)
				var q := pivo.quaternion
				if anterior.has(caminho):
					var passo: float = q.angle_to(anterior[caminho])
					maior_passo = maxf(maior_passo, passo)
					_check(passo < 0.70, "continuidade angular " + caminho + ":" + nome)
				anterior[caminho] = q
			var bounds := AABB()
			for i in malhas.size():
				var caixa: AABB = malhas[i].global_transform * caixas[i]
				_check(caixa.position.is_finite() and caixa.size.is_finite(), "bounds finitos")
				bounds = caixa if i == 0 else bounds.merge(caixa)
			maior_caixa = maior_caixa.max(bounds.size)
			_check(bounds.size.length() < 24.0, "bounds sem explosão " + nome)
			var tempo_fase := float(frame+1)/fps
			if fase[3] and tempo_fase > 0.60:
				var pes: Array = medidas.pes
				var e0: float = absf(pes[0].y-Forma.CHAO)
				var e1: float = absf(pes[1].y-Forma.CHAO)
				var erro: float = minf(e0,e1) if nome == "andando" else maxf(e0,e1)
				erro_apoio = maxf(erro_apoio, erro)
				_check(erro < 0.004, "contato de apoio " + nome)
			if nome == "voar":
				for grupo: Array in [forma.asas, forma.cotovelos, forma.punhos]:
					for joint: Node3D in grupo:
						var chave := str(forma.get_path_to(joint))
						minimos[chave] = (minimos[chave] as Vector3).min(joint.rotation) if minimos.has(chave) else joint.rotation
						maximos[chave] = (maximos[chave] as Vector3).max(joint.rotation) if maximos.has(chave) else joint.rotation
				for grupo: Array in [forma.asas, forma.cotovelos, forma.punhos]:
					var e: Vector3 = grupo[0].rotation
					var d: Vector3 = grupo[1].rotation
					_check(absf(e.x-d.x)+absf(e.y+d.y)+absf(e.z+d.z) < 0.001, "simetria asas voo")
		if fase[3]:
			var menor_y := INF
			for malha in malhas:
				if not str(forma.get_path_to(malha)).contains("Ombro"): continue
				for superficie in malha.mesh.get_surface_count():
					var dados := malha.mesh.surface_get_arrays(superficie)
					for vertice in dados[Mesh.ARRAY_VERTEX]:
						menor_y = minf(menor_y,(malha.global_transform*vertice).y)
			# Reserva de 3 cm para a oscilação do shader das pontas.
			_check(menor_y >= .03, "asas acima do chão " + nome)
			print("FPS=",fps," chão ",nome," asa_min_y=",menor_y)
		var poses: Dictionary = {}
		for pivo in pivos:
			poses[str(forma.get_path_to(pivo))] = pivo.transform
		snapshots[nome] = {"estado":forma.estado_animacao, "poses":poses}
		if nome == "descer":
			print("FPS=", fps, " queda tornozelos=", forma.medidas_rig().pes, " ar=", forma.medidas_rig().ar)
	for estado in ["parado", "andando", "sentando", "sentado", "levantando", "decolando", "voando", "pousando"]:
		_check(estados.has(estado), "estado observado " + estado)
	for caminho: String in minimos:
		var amplitude: float = (maximos[caminho]-minimos[caminho]).length()
		_check(amplitude > 0.08, "amplitude articulação asa " + caminho)
		print("FPS=", fps, " amplitude_rad ", caminho, "=", amplitude)
	print("FPS=", fps, " erro_comprimento=", erro_comprimento, " erro_apoio=", erro_apoio, " maior_passo_rad=", maior_passo, " max_bounds=", maior_caixa, " simulação_CPU_ms=", (Time.get_ticks_usec()-simulacao_inicio)/1000.0)
	forma.free()
	return snapshots

func _coletar(n: Node3D, pivos: Array[Node3D], malhas: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		if n.mesh != null: malhas.append(n)
	else:
		pivos.append(n)
	for filho in n.get_children():
		if filho is Node3D: _coletar(filho, pivos, malhas)
