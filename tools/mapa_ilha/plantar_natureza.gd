extends SceneTree
# ============================================================================
#  PLANTAR A NATUREZA no mapa vivo da Ilha Inicial (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/plantar_natureza.gd
#
#  Lê `natureza_plantio.json` (regiões e quantas peças de cada modelo) e SOMA as peças
#  ao mapa que o dono edita — nunca regenera a ilha. Monta o mapa para ter a física e
#  sorteia (semente fixa) pontos que valem:
#    • dentro da região e fora das exclusões (o coliseu);
#    • o raio de cima bate no RELEVO (não em casa, pedra ou árvore já posta);
#    • fora d'água, da estrada/praça (solo terra) e da areia da margem;
#    • declive pequeno sob a base (o tronco não fica com um lado no ar);
#    • longe de qualquer peça (consulta de esfera) e das já plantadas nesta rodada.
#  A base afunda até o ponto mais baixo do chão sob ela (+ 8 cm), giro e escala variam.
#  Idempotente: troca só as peças "natureza_*"; cópia do mapa antes.
# ============================================================================

const FONTE := "res://tools/mapa_ilha/natureza_plantio.json"
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const PREFIXO := "natureza_"
const GRUPO := "natureza"
const TENTATIVAS := 60
const SOLOS_PROIBIDOS := [2, 3, 6]     # terra (estrada/praça), areia, leito

var _rng := RandomNumberGenerator.new()
var _terrenos := {}
var _postas: Array[Dictionary] = []    # {pos: Vector2, raio: float}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var fonte: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONTE))
	var lido := MapaArquivo.carregar(MAPA)
	if not (fonte is Dictionary) or not lido["ok"]:
		push_error("fonte ou mapa ilegível")
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = lido["mapa"]
	_rng.seed = int(fonte.get("semente", 1))
	# Sem as peças desta ferramenta (rodada anterior): o sorteio parte do mapa do dono.
	var pecas: Array = (mapa["pecas"] as Array).filter(func(p: Dictionary) -> bool:
		return not String(p["id"]).begins_with(PREFIXO))
	var trocadas := (mapa["pecas"] as Array).size() - pecas.size()
	mapa["pecas"] = pecas
	for p: Dictionary in pecas:
		if p["tipo"] == "terreno":
			_terrenos[p["id"]] = p
	var mundo := Node3D.new()
	root.add_child(mundo)
	MapaMontador.montar(mundo, mapa)
	for i in 3:
		await physics_frame
	var espaco := mundo.get_world_3d().direct_space_state

	var novas: Array = []
	var erros := 0
	for linha: Dictionary in fonte["plantio"]:
		var regiao: Dictionary = fonte["regioes"][linha["regiao"]]
		var postas := 0
		for k in int(linha["quantidade"]):
			var modelo: String = (linha["modelos"] as Array)[_rng.randi() % (linha["modelos"] as Array).size()]
			if not bib.tem(modelo):
				push_error("fora da loja: " + modelo)
				erros += 1
				continue
			var peca := _plantar_uma(espaco, bib, modelo, regiao, float(linha["espaco"]), float(linha.get("variar", 0.1)), novas.size())
			if peca.is_empty():
				continue
			novas.append(peca)
			postas += 1
		print("PLANTIO %-18s %-34s %2d de %2d" % [linha["regiao"], str(linha["modelos"][0]).left(34), postas, linha["quantidade"]])
	mundo.queue_free()
	if erros:
		quit(1)
		return
	var grupos: Array = mapa["grupos"]
	if not grupos.any(func(g: Dictionary) -> bool: return g["id"] == GRUPO):
		grupos.append({"id": GRUPO, "pai": ""})
	pecas.append_array(novas)
	var original := FileAccess.get_file_as_string(MAPA)
	var copia := BACKUPS.path_join("baseplate_antes_natureza_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("NATUREZA_PLANTADA %d peças (trocadas %d), mapa com %d, grava=%s" % [novas.size(), trocadas, pecas.size(), error_string(err)])
	quit(0 if err == OK else 1)


func _plantar_uma(espaco: PhysicsDirectSpaceState3D, bib: BibliotecaDeModelos, modelo: String, regiao: Dictionary,
		distancia: float, variar: float, n: int) -> Dictionary:
	var r: Array = regiao["retangulo"]
	var escala := 1.0 + _rng.randf_range(-variar, variar)
	var t := bib.tamanho_padrao(modelo) * escala
	var arvore := bib.categorias_do_modelo(modelo).has("arvores")
	# Raio da BASE (o que encosta no chão): tronco das árvores, a peça toda nas pequenas.
	var raio_base := 0.7 * escala if arvore else maxf(t.x, t.z) * 0.4
	var desnivel_max := 1.0 if arvore else maxf(0.25, t.y * 0.5)
	for _t in TENTATIVAS:
		var c := Vector2(_rng.randf_range(r[0], r[1]), _rng.randf_range(r[2], r[3]))
		if (regiao.get("fora", []) as Array).any(func(e: Array) -> bool: return c.distance_to(Vector2(e[0], e[1])) < e[2]):
			continue
		if _postas.any(func(o: Dictionary) -> bool: return c.distance_to(o["pos"]) < maxf(distancia, o["raio"])):
			continue
		var chao := _chao_do_relevo(espaco, c)
		if is_nan(chao):
			continue
		var minimo := chao
		var maximo := chao
		var ok := true
		for a in 6:
			var v := c + Vector2(cos(a * TAU / 6.0), sin(a * TAU / 6.0)) * raio_base
			var y := _chao_do_relevo(espaco, v)
			if is_nan(y):
				ok = false
				break
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		if not ok or maximo - minimo > desnivel_max:
			continue
		# Nada por perto (casa, pedra, árvore, ponte...): esfera no meio da altura.
		var q := PhysicsShapeQueryParameters3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = distancia * 0.5
		q.shape = esfera
		q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, chao + esfera.radius + 0.3, c.y))
		q.collision_mask = 1
		var bate := false
		for hit in espaco.intersect_shape(q, 8):
			if not _terrenos.has(String((hit["collider"] as Node).get_meta("peca_id", ""))):
				bate = true
				break
		if bate:
			continue
		_postas.append({"pos": c, "raio": distancia})
		return {"id": "%s%d" % [PREFIXO, n], "tipo": "modelo", "modelo": modelo, "grupo": GRUPO,
			"posicao": Vector3(c.x, minimo - 0.08 + t.y * 0.5, c.y),
			"rotacao_graus": Vector3(0, snappedf(_rng.randf_range(0.0, 360.0), 1.0), 0), "tamanho": t,
			"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": not bib.atravessavel(modelo)}
	return {}


## Chão do RELEVO sob c (NAN se o raio bater antes em outra peça, ou cair em água,
## estrada ou areia).
func _chao_do_relevo(espaco: PhysicsDirectSpaceState3D, c: Vector2) -> float:
	var h := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, 300, c.y), Vector3(c.x, -50, c.y), 1))
	if h.is_empty():
		return NAN
	var id := String((h["collider"] as Node).get_meta("peca_id", ""))
	if not _terrenos.has(id):
		return NAN
	var t: Dictionary = _terrenos[id]
	var pos: Vector3 = t["posicao"]
	var lx := c.x - pos.x
	var lz := c.y - pos.z
	if TerrenoDoMapa.molhado_local(t["relevo"], t["tamanho"], lx, lz):
		return NAN
	if SOLOS_PROIBIDOS.has(TerrenoDoMapa.solo_local(t["relevo"], t["tamanho"], lx, lz)):
		return NAN
	return (h["position"] as Vector3).y
