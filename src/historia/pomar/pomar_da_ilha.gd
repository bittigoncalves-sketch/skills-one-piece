class_name PomarDaIlha
extends Node3D
# ============================================================================
#  POMAR DA ILHA — frutas penduradas nas árvores frutíferas do mapa (01/10/2026).
#
#  Decisões do dono:
#    • frutas GRUDADAS nas árvores: cada árvore frutífera da loja (`frutas_da_arvore`)
#      ganha uma fruta em cada ponto `Fruta_*` da copa (o .glb os traz — gerados por
#      tools/blender/preparar_natureza.py); UMA espécie por árvore, sorteada pelo id da
#      peça (estável entre sessões);
#    • a cada 5 min cai uma fruta de UMA árvore sorteada da ilha e vira item no chão;
#    • o galho rebrota 5 min depois;
#    • no chão, até ser pega; no máximo 30 na ilha (passou, some a mais antiga);
#    • coleta passando por cima (`FrutaNoChao`).
# ============================================================================

signal fruta_coletada(fruta_id: String)
signal fruta_caiu(arvore_id: String, fruta_id: String)

## `static var` (e não constante) só para o teste encurtar a espera.
static var intervalo_de_queda := 300.0
static var tempo_de_rebrotar := 300.0
const MAX_NO_CHAO := 30
const TAMANHO_DA_FRUTA := 0.3      # fallback; o normal é o tamanho padrão da loja

## {id, fruta, galhos: [{pos, visual, presente, volta_em}]}
var arvores: Array[Dictionary] = []
var no_chao: Array[FrutaNoChao] = []

var _bib: BibliotecaDeModelos
var _terrenos := {}
var _relogio := 0.0
var _agora := 0.0


func ligar(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, ilha := "") -> void:
	_bib = bib
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "terreno":
			_terrenos[p["id"]] = true
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] != "modelo":
			continue
		var frutas := bib.frutas_da_arvore(p["modelo"])
		if frutas.is_empty():
			continue
		var corpo := raiz.get_node_or_null(NodePath(String(p["id"]))) as Node3D
		var modelo := corpo.get_node_or_null("Modelo") as Node3D if corpo else null
		if modelo == null:
			continue
		var pontos := modelo.find_children("Fruta_*", "", true, false)
		if pontos.is_empty():
			continue
		var fruta: String = frutas[absi(String(p["id"]).hash()) % frutas.size()]
		if not bib.tem(fruta):
			push_warning("[Pomar] %s: fruta \"%s\" fora da loja" % [p["id"], fruta])
			continue
		var arvore := {"id": p["id"], "fruta": fruta, "galhos": [], "ilha": ilha}
		for ponto: Node3D in pontos:
			var visual := montar_fruta(fruta)
			add_child(visual)
			visual.global_position = ponto.global_position
			(arvore["galhos"] as Array).append({"pos": ponto.global_position, "visual": visual,
				"presente": true, "volta_em": 0.0})
		arvores.append(arvore)
	_relogio = intervalo_de_queda


## A ilha foi descarregada: saem as árvores dela e as frutas penduradas nelas.
func descarregar_ilha(ilha: String) -> void:
	for arvore in arvores:
		if str(arvore.get("ilha", "")) != ilha:
			continue
		for g: Dictionary in arvore["galhos"]:
			if is_instance_valid(g.get("visual")):
				(g["visual"] as Node).queue_free()
	arvores.assign(arvores.filter(func(a: Dictionary) -> bool: return str(a.get("ilha", "")) != ilha))


## A fruta no tamanho da loja, com o centro na origem e um giro qualquer.
func montar_fruta(fruta: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Fruta_" + fruta
	var m := _bib.instanciar(fruta)
	if m == null:
		return raiz
	var e: Dictionary = _bib.info(fruta)
	var t: Vector3 = e["tamanho"]
	var alvo := _bib.tamanho_padrao(fruta)
	var k := alvo.y / maxf(t.y, 0.0001) if alvo.y > 0.0 else TAMANHO_DA_FRUTA / maxf(t.y, 0.0001)
	m.scale = Vector3.ONE * k
	m.position = -(e["centro"] as Vector3) * k
	for gi: GeometryInstance3D in m.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # muitas e pequenas
	raiz.add_child(m)
	raiz.rotation.y = randf() * TAU
	return raiz


func _process(delta: float) -> void:
	_agora += delta
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = intervalo_de_queda
		derrubar_uma()
	for arvore in arvores:
		if not arvore.get("disponivel", true): continue
		for g: Dictionary in arvore["galhos"]:
			if not g["presente"] and _agora >= g["volta_em"]:
				_rebrotar(g)


## Cai uma fruta de uma árvore sorteada (entre as que têm alguma no galho). `false` se
## nenhuma árvore tem fruta agora. Público para o teste e o painel F8.
func derrubar_uma() -> bool:
	var com_fruta := arvores.filter(func(a: Dictionary) -> bool:
		return a.get("disponivel", true) and (a["galhos"] as Array).any(func(g: Dictionary) -> bool: return g["presente"]))
	if com_fruta.is_empty():
		return false
	var arvore: Dictionary = com_fruta.pick_random()
	var g: Dictionary = (arvore["galhos"] as Array).filter(func(x: Dictionary) -> bool: return x["presente"]).pick_random()
	g["presente"] = false
	g["volta_em"] = _agora + tempo_de_rebrotar
	var visual: Node3D = g["visual"]
	visual.visible = false
	var item := FrutaNoChao.new()
	add_child(item)
	item.global_position = g["pos"]
	item.preparar(arvore["fruta"], montar_fruta(arvore["fruta"]), _chao_abaixo(g["pos"]), _agora)
	item.coletada.connect(_ao_coletar)
	no_chao.append(item)
	while no_chao.size() > MAX_NO_CHAO:
		var velha: FrutaNoChao = no_chao.pop_front()
		if is_instance_valid(velha):
			velha.queue_free()
	fruta_caiu.emit(arvore["id"], arvore["fruta"])
	return true


func _rebrotar(g: Dictionary) -> void:
	g["presente"] = true
	var visual: Node3D = g["visual"]
	visual.visible = true
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_coletar(item: FrutaNoChao) -> void:
	no_chao.erase(item)
	fruta_coletada.emit(item.fruta_id)


## Chão do RELEVO sob o ponto (a fruta não para em telhado nem em tronco).
func _chao_abaixo(p: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	var excluir: Array[RID] = []
	var de := p + Vector3.UP * 0.5
	for _t in 6:
		var q := PhysicsRayQueryParameters3D.create(de, Vector3(p.x, -50.0, p.z), 1, excluir)
		var h := espaco.intersect_ray(q)
		if h.is_empty():
			break
		if _terrenos.has(String((h["collider"] as Node).get_meta("peca_id", ""))) or RelevoEmBlocos.e_relevo(h["collider"]):
			return (h["position"] as Vector3).y + 0.15
		excluir.append(h["rid"])
	return p.y - 6.0


## O corte suspende as frutas dos galhos; as já caídas continuam coletáveis.
func disponibilizar_arvore(id: String, sim: bool) -> void:
	for arvore in arvores:
		if arvore.id != id: continue
		arvore["disponivel"] = sim
		for galho: Dictionary in arvore.galhos:
			(galho.visual as Node3D).visible = sim and galho.presente
