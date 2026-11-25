extends Node3D
# ============================================================================
#  NAUFRÁGIOS, ESQUELETOS E OURO (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3/E4).
#
#  Os cascos são PEÇAS do mapa vivo (categoria "naufragios" da loja; o dono move e apaga
#  no editor). No jogo, cada um:
#   - assenta no fundo: a altura MÍNIMA do `RelevoMarinho` sob o casco (nenhum canto
#     flutua), mesmo que o dono tenha mudado a peça de lugar no editor (lá não há fundo);
#   - troca o material pela madeira afundada (`naufragio.gdshader`: alga e cracas);
#   - ganha ESQUELETOS decorativos (decisão do dono, 14/10) nos marcadores
#     `ponto_esqueleto_*` (modelo `skeleton` da loja na pose final de "Death") e um
#     crânio solto;
#   - ganha UM BAÚ no `ponto_bau`: abre com E uma vez por save (decisão do dono, 14/10) e
#     dá ouro (a moeda das lojas): galeão 40, chalupa 25, bote 15. Fechado, brilha fraco
#     (achar debaixo d'água); aberto, vira o baú cheio de ouro, sem brilho.
#  Estado no save: `ProgressaoDoPersonagem.dados_de("mar")["baus"]` (ids das peças).
# ============================================================================

const SHADER := preload("res://src/historia/mar/naufragio.gdshader")
const CATEGORIA := "naufragios"
const RECOMPENSA := {"naufragio_galeao": 40, "naufragio_chalupa": 25, "naufragio_bote": 15}
const RECOMPENSA_PADRAO := 20
const ALCANCE_DO_BAU := 3.2
const ESCALA_ESQUELETO := 1.45

var relevo: RelevoMarinho
var progressao: ProgressaoDoPersonagem
var hud: Node
var jogador_de: Callable
## id da peça → {"corpo", "modelo", "bau": Node3D, "luz": OmniLight3D, "ponto": Vector3}
var naufragios := {}
var _bib: BibliotecaDeModelos


func ligar(contexto: Dictionary, campo: RelevoMarinho, jogador: Callable) -> void:
	relevo = campo
	jogador_de = jogador
	progressao = contexto.get("progressao")
	hud = contexto.get("hud")
	_bib = contexto.get("bib")
	var raiz: Node = contexto.get("raiz")
	var mapa: Dictionary = contexto.get("mapa", {})
	if raiz == null or _bib == null:
		return
	for p: Dictionary in mapa.get("pecas", []):
		if p.get("tipo") != "modelo" or not _bib.tem(str(p.get("modelo", ""))):
			continue
		if not _bib.categorias_do_modelo(str(p["modelo"])).has(CATEGORIA):
			continue
		var corpo := raiz.get_node_or_null(NodePath(str(p["id"]))) as Node3D
		if corpo != null:
			_preparar(corpo, p)
	add_to_group("so_submerso")          # esqueletos, baús, moedas, crânios
	if progressao != null:
		progressao.mudou.connect(_atualizar_baus)
	_atualizar_baus()
	if hud != null and hud.has_method("ligar_interagivel"):
		hud.ligar_interagivel(self)


func _preparar(corpo: Node3D, p: Dictionary) -> void:
	var modelo := str(p["modelo"])
	var tam: Vector3 = p["tamanho"]
	var info := _bib.info(modelo)
	var escala: Vector3 = tam / (info["tamanho"] as Vector3)
	# Assenta: menor altura do fundo sob a pegada do casco (9 pontos).
	var base := INF
	var eixo_x := corpo.global_basis.x.normalized()
	var eixo_z := corpo.global_basis.z.normalized()
	for fx in [-0.45, 0.0, 0.45]:
		for fz in [-0.3, 0.0, 0.3]:
			var q: Vector3 = corpo.global_position + eixo_x * tam.x * fx + eixo_z * tam.z * fz
			base = minf(base, relevo.altura(q.x, q.z))
	corpo.global_position.y = base + (info["centro"] as Vector3).y * escala.y
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("chao_y", base)
	material.set_shader_parameter("sombra_min", 0.5)
	material.set_shader_parameter("suavidade", 0.16)
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = material
	# No fundo: só aparece mergulhando (a visão submersa esconde de cima — E7).
	var desenho := corpo.get_node_or_null("Modelo")
	if desenho != null:
		desenho.add_to_group("so_submerso")
	var registro := {"corpo": corpo, "modelo": modelo, "id": str(p["id"])}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(p["id"]))
	for marca in corpo.find_children("ponto_*", "Node3D", true, false):
		var n := String(marca.name)
		var onde := _no_chao_ou_convés((marca as Node3D).global_position)
		if n.begins_with("ponto_esqueleto"):
			_esqueleto(onde, rng)
		elif n.begins_with("ponto_bau"):
			registro["ponto"] = onde
			registro["giro"] = corpo.global_rotation.y + rng.randf_range(-0.6, 0.6)
	if registro.has("ponto"):
		naufragios[registro["id"]] = registro
		_moedas(registro["ponto"], rng)
	# Um crânio solto perto do casco.
	var cranio := _bib.instanciar("skull") if _bib.tem("skull") else null
	if cranio != null:
		add_child(cranio)
		var lado := corpo.global_position + eixo_z * (tam.z * 0.5 + 1.2) + eixo_x * rng.randf_range(-3, 3)
		cranio.global_position = Vector3(lado.x, relevo.altura(lado.x, lado.z) + 0.05, lado.z)
		cranio.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		cranio.scale = Vector3.ONE * 1.3


## Marcador perto do fundo (≤ 1,5 m) assenta no fundo; senão fica (convés, porão).
func _no_chao_ou_convés(p: Vector3) -> Vector3:
	var chao := relevo.altura(p.x, p.z)
	return Vector3(p.x, chao + 0.02, p.z) if p.y - chao < 1.5 else p


func _esqueleto(onde: Vector3, rng: RandomNumberGenerator) -> void:
	if not _bib.tem("skeleton"):
		return
	var e := _bib.instanciar("skeleton")
	if e == null:
		return
	add_child(e)
	e.global_position = onde
	e.rotation.y = rng.randf() * TAU
	e.scale = Vector3.ONE * ESCALA_ESQUELETO
	# Pose final da animação de morte, aplicada uma vez: deitado, sem custo por quadro.
	var ap := e.find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty():
		var player := ap[0] as AnimationPlayer
		for nome in player.get_animation_list():
			if "Death" in nome:
				player.play(nome)
				player.seek(player.get_animation(nome).length, true)
				player.pause()
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				break


func _moedas(centro: Vector3, rng: RandomNumberGenerator) -> void:
	if not _bib.tem("coins"):
		return
	for k in 4:
		var m := _bib.instanciar("coins")
		if m == null:
			return
		add_child(m)
		var o := Vector2(rng.randf_range(1.0, 2.2), 0).rotated(rng.randf() * TAU)
		var p := centro + Vector3(o.x, 0, o.y)
		m.global_position = Vector3(p.x, maxf(relevo.altura(p.x, p.z), centro.y - 0.05), p.z)
		m.rotation.y = rng.randf() * TAU
		m.scale = Vector3.ONE * rng.randf_range(1.0, 1.6)


## Baús conforme o save (abertos = cheios de ouro, sem brilho). Chamado também quando a
## progressão muda (reiniciar a campanha fecha os baús de novo).
func _atualizar_baus() -> void:
	var abertos: Array = _abertos()
	for id in naufragios:
		var r: Dictionary = naufragios[id]
		var aberto := abertos.has(id)
		if r.get("aberto_na_cena", null) == aberto:
			continue
		if r.has("bau") and is_instance_valid(r["bau"]):
			r["bau"].queue_free()
		var bau := _bib.instanciar("chest_gold" if aberto else "chest_closed")
		if bau == null:
			continue
		add_child(bau)
		bau.global_position = r["ponto"]
		bau.rotation.y = r["giro"]
		bau.scale = Vector3.ONE * 1.2
		if not aberto:
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.82, 0.38)
			luz.light_energy = 1.6
			luz.omni_range = 5.0
			luz.shadow_enabled = false
			bau.add_child(luz)
			luz.position = Vector3(0, 1.1, 0)
		r["bau"] = bau
		r["aberto_na_cena"] = aberto


func _abertos() -> Array:
	if progressao == null:
		return []
	var d := progressao.dados_de("mar")
	var lista: Variant = d.get("baus", [])
	return (lista as Array).filter(func(v: Variant) -> bool: return v is String and naufragios.has(v)) if lista is Array else []


## Id do naufrágio com baú FECHADO ao alcance do jogador, ou "".
func bau_ao_alcance() -> String:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return ""
	var abertos := _abertos()
	var melhor := ""
	var menor := ALCANCE_DO_BAU
	for id in naufragios:
		if abertos.has(id):
			continue
		var d: float = (naufragios[id]["ponto"] as Vector3).distance_to(j.global_position)
		if d < menor:
			menor = d
			melhor = id
	return melhor


## Interagível da HUD (`HistoriaHud.ligar_interagivel`).
func dica() -> String:
	return "E — abrir o baú do naufrágio" if not bau_ao_alcance().is_empty() else ""


func interagir() -> bool:
	var id := bau_ao_alcance()
	if id.is_empty() or progressao == null:
		return false
	return abrir(id)


## Abre o baú (uma vez por save) e paga. Devolve false se já estava aberto.
func abrir(id: String) -> bool:
	if progressao == null or not naufragios.has(id) or _abertos().has(id):
		return false
	if not preload("res://src/inventario/bau_de_tesouros.gd").receber(progressao.inventario):
		if hud != null and hud.has_method("avisar"):
			hud.avisar("Libere um espaço na mochila para recolher o baú de tesouros.")
		return false
	var ouro := int(RECOMPENSA.get(naufragios[id]["modelo"], RECOMPENSA_PADRAO))
	var d := progressao.dados_de("mar")
	var lista: Array = _abertos()
	lista.append(id)
	d["baus"] = lista
	progressao.gravar_dados("mar", d)       # emite `mudou` → o baú vira o aberto
	progressao.ganhar_ouro(ouro)
	if hud != null and hud.has_method("avisar"):
		hud.avisar("Baú de tesouros na mochila  ·  +%d de ouro" % ouro)
	return true
