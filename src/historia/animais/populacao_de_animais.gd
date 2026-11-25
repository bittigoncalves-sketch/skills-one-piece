class_name PopulacaoDeAnimais
extends Node3D
# ============================================================================
#  POPULAÇÃO DE ANIMAIS — as áreas de animais do mapa viram bichos no Modo História
#  (01/10/2026).
#
#  Para cada peça `area_animais`: esconde o volume (ele só existe no editor), sorteia
#  `quantidade` pontos no CHÃO dentro dela e cria um `AnimalDaIlha` em cada.
#  Morreu (decisão do dono): 1 XP e o item "none" (= nada, por enquanto), e volta em
#  30 s num ponto NOVO sorteado na mesma área — o cão pode morrer na floresta e
#  renascer em outro canto da vila. CHEFE não segue essa regra: volta ao centro da
#  área dele (o ponto onde nasceu), bem mais tarde (`boss_renasce_em`).
#
#  NÍVEL DE DETALHE (pedido do dono: longe, sem animação; visão restrita a um raio):
#    até ANIMADO_ATE ........ anima
#    até VISIVEL_ATE ........ anda, mas sem animação
#    além ................... escondido e parado (não pensa nem anda)
# ============================================================================

signal animal_abatido(animal: AnimalDaIlha)

const ANIMADO_ATE := 35.0
const VISIVEL_ATE := 80.0
const INTERVALO_DE_DETALHE := 0.2
## `static var` (e não constante) só para o teste encurtar a espera.
static var renasce_em := 30.0
static var boss_renasce_em := 300.0
const TENTATIVAS_DE_PONTO := 16
## ILHA TODA (10/11/2026, pedido do dono: "ao invés de spawnarem na vila, aumente o spawn para toda a ilha"): estas espécies deixam de nascer
## e de passear só no volume pequeno da vila e passam a usar a PLACA da ilha inteira. De fora: a vaca e os cavalos (ficam onde estão).
## Como a área ficou muito maior, nasce o dobro (`QUANTIDADE_NA_ILHA_TODA`) e o sorteio tenta mais pontos (a ilha tem água, telhado e pedra).
const ESPECIES_PELA_ILHA_TODA := ["beagle", "cat", "bird_2", "bird-h5izaudltz", "chicken", "chick", "duck"]
const QUANTIDADE_NA_ILHA_TODA := 2.0
const TENTATIVAS_ILHA_TODA := 48

var jogador: Node3D = null
var animais: Array[AnimalDaIlha] = []
var _areas: Array[Dictionary] = []    # {id, especie, quantidade, centro, meio, base}
var _terrenos := {}                   # id -> peça terreno (para saber se o ponto é rio)
var _relogio_detalhe := 0.0


## Liga as áreas do mapa montado. `jogador` pode chegar depois (`definir_jogador`).
## Pode ser chamada VÁRIAS vezes (uma por ilha, na carga por distância): só as áreas novas são povoadas. `ilha` marca os animais
## para `descarregar_ilha`.
func ligar(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, ilha := "", caixa_da_ilha := Rect2()) -> void:
	var novas: Array[Dictionary] = []
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "terreno":
			_terrenos[p["id"]] = p
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] != "area_animais":
			continue
		var corpo := raiz.get_node_or_null(NodePath(String(p["id"]))) as Node3D
		if corpo:
			corpo.visible = false          # a área é do editor; no jogo não se vê
		var esp: String = p["especie"]
		if not bib.tem(esp) or bib.ficha_de_animal(esp).is_empty():
			push_warning("[Animais] área \"%s\": \"%s\" não é animal da loja (sem ficha) — ninguém nasce" % [p["id"], esp])
			continue
		var nova := {"id": p["id"], "especie": esp, "quantidade": p["quantidade"],
			"centro": p["posicao"], "meio": (p["tamanho"] as Vector3) * 0.5,
			"base": Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0)),
			"ficha": bib.ficha_de_animal(esp), "ilha": ilha, "seguro": p["posicao"], "tentativas": TENTATIVAS_DE_PONTO}
		if ESPECIES_PELA_ILHA_TODA.has(esp) and caixa_da_ilha.has_area():
			expandir_para_a_ilha(nova, caixa_da_ilha)
		_areas.append(nova)
		novas.append(_areas.back())
	# Os pontos no chão precisam da física do mapa já montada: um quadro depois.
	_povoar.call_deferred(bib, novas)


## A área passa a ser a placa da ilha inteira. O ponto ORIGINAL (a vila) vira o `seguro`: onde cair se nenhum ponto livre for achado.
static func expandir_para_a_ilha(area: Dictionary, caixa: Rect2) -> void:
	var c := caixa.get_center()
	var meio: Vector3 = area["meio"]
	area["centro"] = Vector3(c.x, (area["centro"] as Vector3).y, c.y)
	area["meio"] = Vector3(caixa.size.x * 0.5, meio.y, caixa.size.y * 0.5)
	area["base"] = Basis.IDENTITY
	area["quantidade"] = maxi(int(ceil(float(area["quantidade"]) * QUANTIDADE_NA_ILHA_TODA)), 1)
	area["tentativas"] = TENTATIVAS_ILHA_TODA
	area["ilha_toda"] = true


## A ilha foi descarregada: sai quem nasceu nas áreas dela e as peças de terreno dela deixam de existir para a conta do rio.
func descarregar_ilha(ilha: String, ids_das_pecas: Array) -> void:
	for a in animais:
		if is_instance_valid(a) and str(a.get_meta("ilha", "")) == ilha:
			a.queue_free()
	_areas.assign(_areas.filter(func(area: Dictionary) -> bool: return str(area.get("ilha", "")) != ilha))
	for id in ids_das_pecas:
		_terrenos.erase(id)
	animais.assign(animais.filter(func(a: AnimalDaIlha) -> bool: return is_instance_valid(a) and not a.is_queued_for_deletion()))


func definir_jogador(j: Node3D) -> void:
	jogador = j
	for a in animais:
		if bool(a.get_meta("aguardando_recrutamento", false)): continue
		a.alvo = j


func _povoar(bib: BibliotecaDeModelos, areas: Array[Dictionary]) -> void:
	await get_tree().physics_frame
	for area in areas:
		for i in int(area["quantidade"]):
			var animal := AnimalDaIlha.new()
			if area["especie"] == "harpia_-_animated_low_poly":
				animal.free()
				animal = load("res://src/historia/bosses/harpia/harpia_da_ilha.gd").new()
			elif area["especie"] == "gorila_rei":
				animal.free()
				animal = load("res://src/historia/bosses/gorila_rei/gorila_rei_da_ilha.gd").new()
			animal.montar(bib, area["especie"], area["ficha"], area)
			add_child(animal)
			animal.global_position = sortear_ponto(area, animal)
			animal.ponto_de_origem = animal.global_position
			animal.alvo = jogador
			animal.populacao = self
			animal.set_meta("ilha", str(area.get("ilha", "")))
			animal.morreu.connect(_ao_morrer)
			animais.append(animal)


## Ponto do CHÃO dentro da área: raio de cima para baixo até um bloco de terreno,
## sem cair dentro de casa nem de pedra (a cápsula do bicho tem que caber ali).
## Voador nasce já no ar. Sem lugar livre depois das tentativas: o centro da área.
func sortear_ponto(area: Dictionary, animal: AnimalDaIlha = null) -> Vector3:
	var espaco := get_world_3d().direct_space_state
	var meio: Vector3 = area["meio"]
	var centro: Vector3 = area["centro"]
	var base: Basis = area["base"]
	var voa := FichaDeAnimal.voa(area["ficha"])
	for _t in int(area.get("tentativas", TENTATIVAS_DE_PONTO)):
		var local := Vector3(randf_range(-meio.x, meio.x), 0, randf_range(-meio.z, meio.z))
		var p := centro + base * local
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1)
		var h := espaco.intersect_ray(q)
		if h.is_empty():
			continue
		var chao: Vector3 = h["position"]
		if voa:                            # voa por cima de tudo: copa, telhado, rio
			return chao + Vector3.UP * float(area["ficha"].get("altura_voo", 8.0))
		var quem := _peca_do_chao(h["collider"], chao)
		if quem.is_empty():
			continue                       # caiu em telhado, pedra, árvore...
		if _na_agua(_terrenos[quem], chao):
			continue                       # leito do rio: é chão, mas debaixo d'água
		if animal != null and not _cabe(espaco, chao, animal):
			continue
		return chao + Vector3.UP * 0.05
	return (area.get("seguro", centro) as Vector3) + Vector3.UP * (float(area["ficha"].get("altura_voo", 0.0)) + 1.0)


## Serve de destino de passeio? Chão de terreno (não telhado nem pedra), seco e com
## CAMINHO LIVRE em linha reta desde `origem` na altura do joelho — sem casa, pedra,
## árvore ou plantação no meio (encostar numa malha densa custava 2–5 ms por quadro:
## ovelha raspando a plantação, medido 01/10/2026).
func destino_valido(p: Vector3, origem: Variant = null, joelho := 0.4, ignorar := RID()) -> bool:
	var espaco := get_world_3d().direct_space_state
	var h := espaco.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1))
	if h.is_empty():
		return false
	var quem := _peca_do_chao(h["collider"], h["position"])
	if quem.is_empty() or _na_agua(_terrenos[quem], h["position"]):
		return false
	if origem == null:
		return true
	var de: Vector3 = (origem as Vector3) + Vector3.UP * joelho
	var ate: Vector3 = (h["position"] as Vector3) + Vector3.UP * joelho
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
	if ignorar.is_valid():
		q.exclude = [ignorar]
	var bate := espaco.intersect_ray(q)
	# Bater no próprio relevo (subida) não é obstáculo; bater em peça ou bicho é.
	return bate.is_empty() or not _peca_do_chao(bate["collider"], bate["position"]).is_empty()


func _cabe(espaco: PhysicsDirectSpaceState3D, chao: Vector3, animal: AnimalDaIlha) -> bool:
	var cs := animal.get_node_or_null("Colisao") as CollisionShape3D
	if cs == null:
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.transform = Transform3D(Basis.IDENTITY, chao + Vector3.UP * (cs.position.y + 0.08))
	q.collision_mask = 1
	q.exclude = [animal.get_rid()]
	for r in espaco.intersect_shape(q, 4):
		if not (_terrenos.has(String((r["collider"] as Node).get_meta("peca_id", ""))) or RelevoEmBlocos.e_relevo(r["collider"])):
			return false
	return true


## Id da peça `terreno` sob o ponto, se o colisor é o relevo ("" se é telhado, pedra,
## bicho...). Com o relevo em blocos (22/10/2026) o colisor é o corpo da ilha: a peça é a
## que cobre o ponto.
func _peca_do_chao(colisor: Object, ponto: Vector3) -> String:
	var quem := String((colisor as Node).get_meta("peca_id", ""))
	if _terrenos.has(quem):
		return quem
	if not RelevoEmBlocos.e_relevo(colisor):
		return ""
	for id in _terrenos:
		var t: Dictionary = _terrenos[id]
		var pos: Vector3 = t["posicao"]
		var tam: Vector3 = t["tamanho"]
		if absf(ponto.x - pos.x) <= tam.x * 0.5 and absf(ponto.z - pos.z) <= tam.z * 0.5:
			return id
	return ""


func _na_agua(t: Dictionary, ponto: Vector3) -> bool:
	var base := Basis.from_euler((t["rotacao_graus"] as Vector3) * (PI / 180.0))
	var local := base.inverse() * (ponto - (t["posicao"] as Vector3))
	return TerrenoDoMapa.molhado_local(t["relevo"], t["tamanho"], local.x, local.z)


## Domado (01/10/2026): o bicho sai da natureza — vira pet na `Companhia` — e a área
## dele repõe um selvagem no mesmo prazo de quem morre, num ponto novo. Sem XP.
func retirar_domado(animal: AnimalDaIlha) -> void:
	animal.estado = AnimalDaIlha.Estado.MORTO
	animal.visible = false
	animal.collision_layer = 0
	animal.ligar_hurtbox(false)
	animal.remove_from_group("enemy")
	var espera := boss_renasce_em if animal.boss() else renasce_em
	get_tree().create_timer(espera).timeout.connect(func():
		if is_instance_valid(animal):
			animal.reviver(sortear_ponto(animal.area, animal)))


func _ao_morrer(animal: AnimalDaIlha) -> void:
	animal_abatido.emit(animal)
	var espera := boss_renasce_em if animal.boss() else renasce_em
	get_tree().create_timer(minf(1.5, espera * 0.5)).timeout.connect(func():
		if is_instance_valid(animal) and not animal.vivo():
			animal.visible = false)
	get_tree().create_timer(espera).timeout.connect(func():
		if not is_instance_valid(animal):
			return
		# Chefe volta ao covil (onde nasceu); os outros, a um ponto novo da área.
		var ponto := animal.ponto_de_origem if animal.boss() else sortear_ponto(animal.area, animal)
		animal.reviver(ponto))


func _process(delta: float) -> void:
	_relogio_detalhe -= delta
	if _relogio_detalhe > 0.0:
		return
	_relogio_detalhe = INTERVALO_DE_DETALHE
	atualizar_detalhe()


## Aplica o nível de detalhe pela distância ao jogador (público para o teste).
func atualizar_detalhe() -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	var j := jogador.global_position
	for a in animais:
		if (a.has_meta("captura_vento") and is_instance_valid(a.get_meta("captura_vento"))) or (a.has_meta("arremesso_vento") and is_instance_valid(a.get_meta("arremesso_vento"))):
			# O transporte controla o corpo até a soltura/pouso; não religar sua IA.
			a.visible = true
			continue
		var d := Vector2(a.global_position.x - j.x, a.global_position.z - j.z).length()
		var nivel := 0 if d <= ANIMADO_ATE else (1 if d <= VISIVEL_ATE else 2)
		if a.has_method("manter_ativo_para_lod") and a.manter_ativo_para_lod():
			nivel = 0
		if nivel == a.nivel_de_detalhe:
			continue
		a.nivel_de_detalhe = nivel
		a.animador.ligado = nivel == 0
		if a.vivo():
			a.visible = nivel < 2
		a.set_physics_process(nivel < 2)
