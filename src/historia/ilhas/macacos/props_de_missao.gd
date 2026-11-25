extends Node3D
## Props interativos das missões da Ilha dos Macacos v2 (22/11/2026): cachos de banana, os quatro totens e o fruto dourado. Tudo com E, como o baú de chefe.
## Cada prop só vale com a missão dele ACEITA (conta o evento com `contar_abate`); colhido/desperto, fica gravado no save (`sistemas["macacos_props"]`)
## e não volta. Os modelos são peças do mapa (`macacos_cacho_banana`, `macacos_sitio_totem_*`, `macacos_fruto_dourado`): aqui só ganham a interação.
const Missoes := preload("res://src/historia/missoes/missoes.gd")
const SISTEMA := "macacos_props"
const MarcadorDeMissao := preload("res://src/ui/marcador_de_missao.gd")
## altura do losango do marcador acima da origem de cada tipo de prop
const ALTURA_DO_MARCADOR := {"macacos_sitio_cacho_": 3.2, "macacos_sitio_totem_": 6.0, "macacos_sitio_fruto_dourado": 4.0}
const ALCANCE := 3.6
## prefixo do ID da peça no mapa (`colocar_construcoes_macacos.gd`) → [evento, missão, rótulo do E, mensagem]
const TIPOS := {
	"macacos_sitio_cacho_": ["banana", "cesto_de_bananas", "colher o cacho de banana", "Cacho colhido"],
	"macacos_sitio_totem_": ["totem", "os_quatro_totens", "despertar o totem", "Totem desperto"],
	"macacos_sitio_fruto_dourado": ["fruto_dourado", "fruto_dourado", "colher o fruto dourado", "Fruto dourado colhido"],
}
var progressao: ProgressaoDoPersonagem
var hud: Node
var jogador_de: Callable
var props := {}                          # id da peça → {corpo, tipo, feito}


func ligar(contexto: Dictionary, jogador: Callable) -> void:
	jogador_de = jogador
	progressao = contexto.get("progressao")
	hud = contexto.get("hud")
	if hud != null and hud.has_method("ligar_interagivel"):
		hud.ligar_interagivel(self)


## Uma ilha foi montada (carga por distância: `ModoHistoria._ligar_ilha`): acha as peças de prop dela. Pode ser chamada várias vezes.
func ligar_no_mapa(raiz: Node, sub: Dictionary) -> void:
	if raiz == null or progressao == null:
		return
	var feitos: Array = progressao.dados_de(SISTEMA).get("feitos", [])
	for p: Dictionary in sub.get("pecas", []):
		var id := String(p.get("id", ""))
		var tipo := _tipo_de(id)
		if tipo.is_empty():
			continue
		var corpo := raiz.get_node_or_null(NodePath(id)) as Node3D
		if corpo == null:
			continue
		props[id] = {"corpo": corpo, "tipo": tipo, "feito": feitos.has(id)}
		_aplicar(id)


func _tipo_de(id: String) -> String:
	for prefixo in TIPOS:
		if id.begins_with(prefixo):
			return prefixo
	return ""


## Estado visual: colhido some; totem desperto ganha uma luz.
func _aplicar(id: String) -> void:
	var d: Dictionary = props[id]
	var corpo: Node3D = d["corpo"]
	var missao := str((TIPOS[d["tipo"]] as Array)[1])
	MarcadorDeMissao.marcar(corpo, missao, float(ALTURA_DO_MARCADOR.get(d["tipo"], 3.5)), not bool(d["feito"]))     # cada cacho/totem/fruto pendente é um objetivo marcado
	if not bool(d["feito"]):
		return
	if d["tipo"] == "macacos_sitio_totem_":
		if corpo.get_node_or_null("LuzDoTotem") == null:
			var luz := OmniLight3D.new()
			luz.name = "LuzDoTotem"
			luz.light_color = Color(1.0, 0.78, 0.3)
			luz.light_energy = 2.0
			luz.omni_range = 9.0
			luz.position = Vector3(0, 3.5, -0.5)
			corpo.add_child(luz)
	else:
		corpo.visible = false
		if corpo is CollisionObject3D:
			(corpo as CollisionObject3D).collision_layer = 0
			(corpo as CollisionObject3D).collision_mask = 0


func _mais_perto() -> String:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return ""
	var melhor := ""
	var menor := ALCANCE
	for id in props:
		var d: Dictionary = props[id]
		if bool(d["feito"]) or not is_instance_valid(d["corpo"]):
			continue
		var dist := (d["corpo"] as Node3D).global_position.distance_to(j.global_position)
		# totem e árvore são grandes: mede até o pé do modelo
		dist = minf(dist, Vector2((d["corpo"] as Node3D).global_position.x - j.global_position.x, (d["corpo"] as Node3D).global_position.z - j.global_position.z).length())
		if dist < menor:
			menor = dist
			melhor = id
	return melhor


## Interagível da HUD (`HistoriaHud.ligar_interagivel`).
func dica() -> String:
	var id := _mais_perto()
	if id.is_empty():
		return ""
	var t: Array = TIPOS[props[id]["tipo"]]
	if progressao.estado_da_missao(str(t[1])) != Missoes.ACEITA:
		return "(aceite a missão %s para %s)" % [Missoes.dados(str(t[1]))["nome"], t[2]]
	return "E — %s" % t[2]


func interagir() -> bool:
	var id := _mais_perto()
	if id.is_empty():
		return false
	var t: Array = TIPOS[props[id]["tipo"]]
	if progressao.estado_da_missao(str(t[1])) != Missoes.ACEITA:
		return false
	return coletar(id)


## Marca o prop como feito (gravado) e conta o evento da missão. Devolve false se já estava feito.
func coletar(id: String) -> bool:
	if not props.has(id) or bool(props[id]["feito"]):
		return false
	var t: Array = TIPOS[props[id]["tipo"]]
	props[id]["feito"] = true
	var d := progressao.dados_de(SISTEMA)
	var feitos: Array = d.get("feitos", [])
	feitos.append(id)
	d["feitos"] = feitos
	progressao.gravar_dados(SISTEMA, d)
	_aplicar(id)
	var texto := str(t[3])
	for m in progressao.contar_abate(str(t[0])):
		var dados := Missoes.dados(m)
		texto += "  ·  %s %d / %d" % [dados["nome"], progressao.abates_da_missao(m), int(dados["meta"])]
	if hud != null and hud.has_method("avisar"):
		hud.avisar(texto)
	return true
