extends Control
# ============================================================================
#  MARCADOR DE MISSÃO NA TELA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#  Pedido do dono: "colocar um marcador no local em que se deve realizar a missão; por
#  exemplo, se a missão é matar 5 bandidos, o marcador fica nos bandidos até o fim da
#  missão; se a missão é completada, ela aponta para o NPC que irá pagar".
#
#  O QUE MARCA, por missão (`Missoes.TABELA[...]["marcar"]`):
#    • aceita, `{"inimigos": c}` → cada inimigo VIVO de comportamento `c` (os bandidos);
#    • aceita, `{"npc": tipo}`   → o NPC onde a tarefa se resolve (domador, vendedor…);
#    • pronta (meta cumprida)    → o NPC que dá a missão e paga (`"npc"` da tabela).
#    • aceita, `{"alvos_de_golpe": id}` → os (até 6 mais perto) animais/personagens vivos daquela espécie/ficha (o Gorila-rei, os macacos saqueadores);
#    • aceita, nós que um sistema registrou com `MarcadorDeMissao.marcar(no, missao, altura, ligado)` (grupo `objetivo_de_missao`): cachos, totens, o fruto
#      dourado, o Buggy, o instrutor, o baú… — cada objetivo na tela (22/11/2026, pedido do dono: "um marcador em cada um dos objetivos").
#  Nenhuma em andamento (17/10/2026, pedido do dono: "quando uma missão acaba sempre
#  deixar marcado onde o jogador pode iniciar a próxima") → o NPC da próxima missão
#  disponível, com o "?" (`Missoes.proximas`). Entregue: nada.
#
#  COMO DESENHA: losango dourado sobre a cabeça do alvo, com a distância embaixo; na
#  entrega, um "?" dentro (o mesmo sinal do NPC). Visto através de paredes, como todo
#  marcador de objetivo. Alvo a menos de 6 m esmaece (não cobre a luta). Nenhum alvo na
#  tela: só o MAIS PERTO aparece preso à borda, com a seta apontando para onde ele está;
#  atrás da câmera ele vai para a LATERAL do lado em que está ("vire para cá"), não para
#  baixo, onde fica a barra de itens. A distância vai ACIMA do losango (embaixo dele, no
#  NPC, fica a "?" e o nome). Some com menu aberto.
# ============================================================================

const Missoes := preload("res://src/historia/missoes/missoes.gd")

const COR := EstiloDaHistoria.DOURADO
const COR_BORDA := Color(0.16, 0.1, 0.0, 0.95)
const RAIO := 12.0                 # meia diagonal do losango (px)
const MARGEM := 54.0               # das bordas laterais (px), para o indicador preso
const MARGEM_CIMA := 170.0         # abaixo do nível, das barras de vida/energia e do rastreador
const MARGEM_BAIXO := 150.0        # acima da barra de itens 1–6
const PERTO := 6.0                 # m: abaixo disto o marcador esmaece
const ALTURA_INIMIGO := 1.75       # acima da origem (centro do corpo) do boneco
const ALTURA_NPC := 3.45           # acima dos pés do NPC (a "?" fica a 2,65)
const REVISAR := 0.25              # s entre buscas dos alvos
const GRUPO_OBJETIVO := "objetivo_de_missao"
const META_MISSAO := "missao_do_objetivo"
const META_ALTURA := "altura_do_marcador"
const MAX_POR_MISSAO := 6          # objetivos de uma mesma missão marcados ao mesmo tempo (os mais perto)
const ALTURA_PADRAO_DO_ALVO := 2.8
const ALTURAS_DE_ALVO := {"gorila_rei": 7.5}

var progressao: ProgressaoDoPersonagem
var npcs: NpcsDaIlha
var jogador_de: Callable

## [{no: Node3D, altura: float, entregar: bool}] — revisto a cada `REVISAR`.
var _alvos: Array[Dictionary] = []
var _relogio := 0.0
var _t := 0.0


func _ready() -> void:
	name = "MarcadorDeMissao"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = REVISAR
		_alvos = alvos()
	var hud := get_parent()
	visible = not _alvos.is_empty() and not (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open"))
	if visible:
		queue_redraw()


## Os alvos de agora (todas as missões aceitas ou prontas).
func alvos() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if progressao == null:
		return saida
	for id in Missoes.TABELA:
		var d := Missoes.dados(id)
		match progressao.estado_da_missao(id):
			Missoes.ACEITA:
				var marcar: Dictionary = d.get("marcar", {})
				if marcar.get("vegetacao", false):
					var planta := _vegetacao_mais_proxima()
					if planta != null:
						saida.append({"no": planta, "altura": planta.altura_do_marcador(), "entregar": false})
				if marcar.has("inimigos"):
					for no in get_tree().get_nodes_in_group("ninhos_de_inimigo"):
						if str(no.get("comportamento")) != str(marcar["inimigos"]):
							continue
						var b: Node3D = no.get("boneco")
						if is_instance_valid(b) and b.is_inside_tree() and float(b.get("health")) > 0.0:
							saida.append({"no": b, "altura": ALTURA_INIMIGO, "entregar": false})
				if marcar.has("npc"):
					var n := _npc(str(marcar["npc"]))
					if n != null:
						saida.append({"no": n, "altura": ALTURA_NPC, "entregar": false})
				if marcar.has("alvos_de_golpe"):
					for no in _mais_perto_de(_alvos_de_golpe(str(marcar["alvos_de_golpe"]))):
						saida.append({"no": no, "altura": float(ALTURAS_DE_ALVO.get(str(marcar["alvos_de_golpe"]), ALTURA_PADRAO_DO_ALVO)), "entregar": false})
				for no in _mais_perto_de(_objetivos_registrados(id)):
					saida.append({"no": no, "altura": float(no.get_meta(META_ALTURA, ALTURA_NPC)), "entregar": false})
			Missoes.PRONTA:
				var n := _npc(str(d["npc"]))
				if n != null:
					saida.append({"no": n, "altura": ALTURA_NPC, "entregar": true})
	for id in Missoes.proximas(progressao):
		var n := _npc(str(Missoes.dados(id)["npc"]))
		if n != null and not saida.any(func(a: Dictionary) -> bool: return a["no"] == n):
			saida.append({"no": n, "altura": ALTURA_NPC, "entregar": true})
	return saida


## Liga/desliga um nó como OBJETIVO da missão `missao` (o marcador o mostra enquanto ela estiver aceita). `altura` = metros acima da origem do nó.
static func marcar(no: Node, missao: String, altura: float, ligado: bool) -> void:
	if no == null or not is_instance_valid(no):
		return
	if ligado:
		no.set_meta(META_MISSAO, missao)
		no.set_meta(META_ALTURA, altura)
		if not no.is_in_group(GRUPO_OBJETIVO):
			no.add_to_group(GRUPO_OBJETIVO)
	elif no.is_in_group(GRUPO_OBJETIVO) and str(no.get_meta(META_MISSAO, "")) == missao:
		no.remove_from_group(GRUPO_OBJETIVO)


func _objetivos_registrados(missao: String) -> Array[Node3D]:
	var saida: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(GRUPO_OBJETIVO):
		if n is Node3D and is_instance_valid(n) and n.is_inside_tree() and (n as Node3D).visible and str(n.get_meta(META_MISSAO, "")) == missao:
			saida.append(n)
	return saida


## Animais/personagens vivos cujo `especie` (animais) ou `ficha.id` (personagens do East Blue) é `id`.
func _alvos_de_golpe(id: String) -> Array[Node3D]:
	var saida: Array[Node3D] = []
	for n in AlvosDeGolpe.todos(get_tree()):
		if not (n is Node3D) or not is_instance_valid(n) or not n.is_inside_tree() or float(n.get("health") if n.get("health") != null else 1.0) <= 0.0:
			continue
		var ficha: Variant = n.get("ficha")
		if str(n.get("especie")) == id or (ficha is Dictionary and str((ficha as Dictionary).get("id", "")) == id):
			saida.append(n)
	return saida


## Só os `MAX_POR_MISSAO` mais perto do jogador (um bando de 40 macacos não vira 40 losangos).
func _mais_perto_de(nos: Array[Node3D]) -> Array[Node3D]:
	if nos.size() <= MAX_POR_MISSAO:
		return nos
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return nos.slice(0, MAX_POR_MISSAO)
	var ordenados := nos.duplicate()
	ordenados.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(j.global_position) < b.global_position.distance_squared_to(j.global_position))
	var saida: Array[Node3D] = []
	for i in MAX_POR_MISSAO:
		saida.append(ordenados[i])
	return saida


func _vegetacao_mais_proxima() -> Node3D:
	var jogador: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if jogador == null:
		return null
	var perto: Node3D = null
	var distancia := INF
	for planta in get_tree().get_nodes_in_group("vegetacao_coletavel"):
		if not is_instance_valid(planta) or planta.derrubada:
			continue
		var delta: Vector3 = planta.global_position - jogador.global_position
		delta.y = 0.0
		if delta.length_squared() < distancia:
			distancia = delta.length_squared()
			perto = planta
	return perto


func _npc(tipo: String) -> Node3D:
	if npcs == null:
		return null
	for n in npcs.npcs:
		if is_instance_valid(n) and n.tipo == tipo:
			return n
	return null


## Onde cada alvo cai na tela agora: [{tela: Vector2, dentro: bool, metros: float,
## entregar: bool, direcao: Vector2}]. `direcao` (para fora do centro) vale para quem
## está fora da tela ou atrás da câmera.
func projecoes() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return saida
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var de := j.global_position if j != null else cam.global_position
	var area := _area_segura()
	for a in _alvos:
		# Checa ANTES de atribuir a uma variável tipada: o NPC pode ter saído com a ilha (carga por distância) desde a última busca.
		if not is_instance_valid(a["no"]):
			continue
		var no: Node3D = a["no"]
		var p: Vector3 = no.global_position + Vector3.UP * float(a["altura"])
		var atras := cam.is_position_behind(p)
		var s := cam.unproject_position(p)
		var local := cam.global_transform.affine_inverse() * p
		var direcao := Vector2(local.x, -local.y)
		if local.z > 0.0:
			# Atrás: para o lado em que está (exatamente atrás = direita), levemente abaixo.
			direcao = Vector2(1.0 if local.x >= 0.0 else -1.0, 0.35)
		if direcao.length_squared() < 0.0001:
			direcao = Vector2.RIGHT
		saida.append({"tela": s, "dentro": not atras and area.has_point(s), "metros": de.distance_to(no.global_position),
			"entregar": bool(a["entregar"]), "direcao": direcao.normalized()})
	return saida


func _draw() -> void:
	var lista := projecoes()
	if lista.is_empty():
		return
	var pulso := 1.0 + 0.1 * sin(_t * TAU * 0.8)
	var algum_dentro := false
	for p in lista:
		if p["dentro"]:
			algum_dentro = true
			var alfa := lerpf(0.35, 1.0, clampf((float(p["metros"]) - 2.0) / (PERTO - 2.0), 0.0, 1.0))
			_losango(p["tela"], RAIO * pulso, alfa, bool(p["entregar"]))
			_distancia(p["tela"] - Vector2(0, RAIO + 12.0), float(p["metros"]), alfa)
	if algum_dentro:
		return
	# Nenhum na tela: o mais perto, preso à borda, com a seta para ele.
	var perto: Dictionary = lista[0]
	for p in lista:
		if float(p["metros"]) < float(perto["metros"]):
			perto = p
	var area := _area_segura()
	var centro := area.get_center()
	var dir: Vector2 = perto["direcao"]
	var meia := area.size * 0.5
	var escala := minf(meia.x / maxf(absf(dir.x), 0.001), meia.y / maxf(absf(dir.y), 0.001))
	var ponto := centro + dir * escala
	_losango(ponto, RAIO * pulso, 1.0, bool(perto["entregar"]))
	var ponta := ponto + dir * (RAIO + 16.0)
	var lado := Vector2(-dir.y, dir.x)
	var seta := PackedVector2Array([ponta, ponto + dir * (RAIO + 5.0) + lado * 7.0, ponto + dir * (RAIO + 5.0) - lado * 7.0])
	draw_colored_polygon(seta, COR)
	draw_polyline(PackedVector2Array([seta[0], seta[1], seta[2], seta[0]]), COR_BORDA, 1.5, true)
	_distancia(ponto - Vector2(0, RAIO + 12.0), float(perto["metros"]), 1.0)


## Onde um marcador pode ficar sem cobrir a HUD fixa (barras, rastreador, barra de itens).
func _area_segura() -> Rect2:
	var tela := get_viewport_rect().size
	return Rect2(Vector2(MARGEM, MARGEM_CIMA), tela - Vector2(MARGEM * 2.0, MARGEM_CIMA + MARGEM_BAIXO))


func _losango(c: Vector2, r: float, alfa: float, entregar: bool) -> void:
	var pontos := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pontos, Color(COR, alfa))
	var contorno := pontos.duplicate()
	contorno.append(pontos[0])
	draw_polyline(contorno, Color(COR_BORDA, alfa * COR_BORDA.a), 2.0, true)
	if entregar:
		var fonte := get_theme_default_font()
		var t := 17
		var largura := fonte.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
		draw_string(fonte, c + Vector2(-largura * 0.5, t * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, t, Color(COR_BORDA, alfa))
	else:
		var m := r * 0.38
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -m), c + Vector2(m, 0), c + Vector2(0, m), c + Vector2(-m, 0)]),
			Color(COR_BORDA, alfa * 0.85))


func _distancia(c: Vector2, metros: float, alfa: float) -> void:
	var texto := "%d m" % roundi(metros) if metros < 1000.0 else ("%.1f km" % (metros / 1000.0)).replace(".", ",")
	var fonte := get_theme_default_font()
	var t := 14
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	var onde := c + Vector2(-largura * 0.5, t * 0.35)
	draw_string_outline(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t, 4, Color(0, 0, 0, 0.85 * alfa))
	draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, t, Color(EstiloDaHistoria.TEXTO, alfa))
