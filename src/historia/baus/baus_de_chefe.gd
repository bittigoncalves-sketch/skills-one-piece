extends Node3D
# ============================================================================
#  BAÚS DE CHEFE (18/11/2026, pedido do dono: "baú como drop ao derrotar chefes no modo história, cada baú dropa uma fruta e a raridade varia de acordo
#  com a força do chefe").
#
#  • Todo CHEFE derrotado solta UM baú onde caiu: personagem do Mine Piece com `chefe` na ficha (do mapa ou de raid; capanga não) e animal-chefe (a Harpia).
#  • A FORÇA do chefe é a recompensa do abate (`Recompensa.xp_de_abate`/`xp_da_ficha`, a conta do mod): vai de ~100 (Higuma) a ~340 mil (Mihawk, Garp). Quatro
#    limites logarítmicos (`LIMITES_DE_FAMA`) dão o PODER base de 1 a 5 — a mesma escala de preço e raridade das frutas (`PerfilDeFrutas.PODER_DAS_FRUTAS`).
#  • O sorteio mexe um pouco no resultado: 75 % o poder base, 20 % um abaixo, 5 % um acima (nunca fora de 1–5). O baú nasce já com a fruta e a raridade
#    SORTEADAS (a cor e o rótulo mostram a raridade; a fruta só aparece ao abrir). Dentro do poder, evita as frutas que o jogador já tem; se tem todas, repete.
#  • Abre com E, ao alcance; a fruta vai para as frutas guardadas (N › FRUTAS). O baú FICA até ser aberto e entra no save (`sistemas.baus_de_chefe`).
#  • 18/11/2026 (decisão do dono): é AQUI que se obtêm as armas do Epic Fight, já que ninguém mais as recebe de graça. `CHANCE_DE_ARMA` (25 %) dos baús trazem uma
#    arma no lugar da fruta, com o poder do material (madeira/ouro/bokken 1, pedra 2, ferro 3, diamante e uchigatana 4, netherite 5); só sai arma que o jogador não tem.
#  Riscos conhecidos: chefe do mapa que renasce (300 s) solta outro baú a cada morte (farm de frutas baixas; sem como vender, então só enche o N);
#  no máximo `MAX_PENDENTES` baús no chão (o mais antigo some quando passa).
#  GATILHO para rever os limites: um chefe novo com fama fora de 99–340 mil, ou o dono achar as raridades raras/comuns demais.
# ============================================================================
const BauTesouros := preload("res://src/inventario/bau_de_tesouros.gd")
const SISTEMA := "baus_de_chefe"
const ID_DO_BAU_FIXO_DO_TOPO := "macacos_topo"
const ALCANCE := 3.4
const MAX_PENDENTES := 24
## Fama do chefe → poder: < 1000 = 1, < 10 mil = 2, < 150 mil = 3, < 250 mil = 4, acima = 5. (Chefes de hoje: Higuma 99 · Buggy 2 mil · Smoker 14 mil ·
## Crocodile 108 mil · Sabo 166 mil · Aokiji 275 mil · Mihawk 338 mil.)
const LIMITES_DE_FAMA := [1000, 10000, 150000, 250000]
const CHANCE_DE_DESCER := 0.20
const CHANCE_DE_SUBIR := 0.05
const CHANCE_DE_ARMA := 0.25
const PODER_DO_MATERIAL := {"wooden": 1, "golden": 1, "stone": 2, "iron": 3, "diamond": 4, "netherite": 5}
## Raridade no masculino, para "baú" (`PerfilDeFrutas.NOMES_DO_PODER` é feminino, de "fruta").
const NOMES_DO_BAU := ["comum", "incomum", "raro", "épico", "lendário"]
const COR_DO_PODER := [Color(0.88, 0.88, 0.88), Color(0.35, 0.92, 0.42), Color(0.35, 0.62, 1.0), Color(0.72, 0.42, 1.0), Color(1.0, 0.8, 0.25)]

var progressao: ProgressaoDoPersonagem
var hud: Node
var jogador_de: Callable
var rng := RandomNumberGenerator.new()
## {"id": int, "pos": Vector3, "fruta": String, "poder": int, "no": Node3D}, do mais antigo ao mais novo.
var baus: Array[Dictionary] = []
var _proximo_id := 1
## Baús FIXOS já entregues (chave → uma vez por personagem; `garantir_fixo`).
var _fixos: Array = []


## Liga ao save (reabre os baús que ficaram no chão) e à HUD (a tecla E).
func ligar(prog: ProgressaoDoPersonagem, a_hud: Node, jogador: Callable) -> void:
	progressao = prog
	hud = a_hud
	jogador_de = jogador
	rng.randomize()
	var d := progressao.dados_de(SISTEMA)
	_proximo_id = int(d.get("proximo", 1))
	_fixos = (d.get("fixos", []) as Array).duplicate()
	for b: Variant in (d.get("lista", []) as Array):
		if b is Dictionary and (PerfilDeFrutas.frutas_a_venda().has(str(b.get("fruta", ""))) or LaminasEpicFight.existe(str(b.get("arma", "")))):
			var p := int(clampi(int(b.get("poder", 1)), 1, 5))
			_criar(int(b.get("id", _proximo_id)), Vector3(float(b.get("x", 0)), float(b.get("y", 0)), float(b.get("z", 0))), str(b.get("fruta", "")), p, str(b.get("arma", "")))
	if hud != null and hud.has_method("ligar_interagivel"):
		hud.ligar_interagivel(self)


# ------------------------------------------------------------------ o sorteio
## O poder base (1–5) de um chefe de `fama`.
static func poder_do_chefe(fama: float) -> int:
	var p := 1
	for limite: int in LIMITES_DE_FAMA:
		if fama >= float(limite):
			p += 1
	return p


## 75 % o base, 20 % um abaixo, 5 % um acima; sempre dentro de 1–5.
func sortear_poder(base: int) -> int:
	var r := rng.randf()
	var p := base - 1 if r < CHANCE_DE_DESCER else (base + 1 if r < CHANCE_DE_DESCER + CHANCE_DE_SUBIR else base)
	return clampi(p, 1, 5)


## Uma fruta do poder `poder`, de preferência que o jogador ainda não tem; poder vazio → o mais perto com frutas. "" só se NÃO houver nenhuma fruta à venda.
func sortear_fruta(poder: int) -> String:
	for desvio in [0, -1, 1, -2, 2, -3, 3, -4, 4]:
		var alvo: int = poder + desvio
		if alvo < 1 or alvo > 5:
			continue
		var pool := PerfilDeFrutas.frutas_do_poder(alvo)
		if pool.is_empty():
			continue
		var novas := pool.filter(func(id: String) -> bool: return not _ja_tem(id))
		var fonte: Array = novas if not novas.is_empty() else pool
		return str(fonte[rng.randi() % fonte.size()])
	return ""


## Poder (1–5) de uma arma do Epic Fight pelo material do id (`ef_iron_tachi` → 3); bokken = 1, uchigatana = 4.
static func poder_da_arma(id: String) -> int:
	if id == "ef_uchigatana":
		return 4
	for material: String in PODER_DO_MATERIAL:
		if id.begins_with("ef_" + material + "_"):
			return int(PODER_DO_MATERIAL[material])
	return 1


## Uma arma que o jogador ainda não tem, do poder `poder` ou do mais perto que tenha; "" se já tem todas.
func sortear_arma(poder: int) -> String:
	var faltam: Array[String] = []
	for id in LaminasEpicFight.ids():
		if progressao != null and not progressao.equipamentos.has(id) and not progressao.ef_quebradas.has(id):
			faltam.append(id)
	for desvio in [0, -1, 1, -2, 2, -3, 3, -4, 4]:
		var alvo: int = poder + desvio
		var pool := faltam.filter(func(id: String) -> bool: return poder_da_arma(id) == alvo)
		if not pool.is_empty():
			return str(pool[rng.randi() % pool.size()])
	return ""


func _ja_tem(id: String) -> bool:
	return progressao != null and (progressao.quantas_akuma(id) > 0 or progressao.fruta == id)


# ------------------------------------------------------------------ soltar e abrir
## Solta o baú de um chefe de `fama` em `onde` (no chão abaixo). Devolve o registro, ou {} sem fruta para dar.
func soltar(onde: Vector3, fama: float, de_quem := "", no_chao := true) -> Dictionary:
	var poder := sortear_poder(poder_do_chefe(fama))
	var arma := sortear_arma(poder) if rng.randf() < CHANCE_DE_ARMA else ""
	var fruta := "" if not arma.is_empty() else sortear_fruta(poder)
	if fruta.is_empty() and arma.is_empty():
		return {}
	poder = poder_da_arma(arma) if not arma.is_empty() else PerfilDeFrutas.poder_da_fruta(fruta)    # se o poder sorteado estava vazio, vale o do item que saiu
	var b := _criar(_proximo_id, _no_chao(onde) if no_chao else onde, fruta, poder, arma)
	_proximo_id += 1
	while baus.size() > MAX_PENDENTES:
		_remover(baus[0])
	_gravar()
	if hud != null and hud.has_method("avisar"):
		hud.avisar("Baú %s caiu%s  ·  E para abrir" % [NOMES_DO_BAU[poder - 1], (" de " + de_quem) if not de_quem.is_empty() else ""])
	return b


## Baú FIXO do mapa (ex.: o do topo das plataformas do Geppo): entregue UMA vez por personagem, em `onde` (sem descer ao chão), com a força de um chefe de `fama`.
## Devolve true se soltou agora. A chave vai para o save: abrir ou não o baú, ele não volta.
func garantir_fixo(chave: String, onde: Vector3, fama: float) -> bool:
	if _fixos.has(chave):
		return false
	_fixos.append(chave)
	var b := soltar(onde, fama, "", false)
	if b.is_empty():
		_fixos.erase(chave)
		return false
	return true


## O baú mais perto ao alcance do jogador ({} = nenhum).
func ao_alcance() -> Dictionary:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return {}
	var melhor := {}
	var menor := ALCANCE
	for b in baus:
		var d: float = (b["pos"] as Vector3).distance_to(j.global_position)
		if d < menor:
			menor = d
			melhor = b
	return melhor


## Interagível da HUD (`HistoriaHud.ligar_interagivel`).
func dica() -> String:
	var b := ao_alcance()
	return "" if b.is_empty() else "E — abrir o baú %s" % NOMES_DO_BAU[int(b["poder"]) - 1]


func interagir() -> bool:
	var b := ao_alcance()
	return false if b.is_empty() else abrir(b)


## Abre: a fruta vai para as guardadas e o baú some. Devolve false sem progressão ou se a fruta não existe mais.
func abrir(b: Dictionary) -> bool:
	if progressao == null or not baus.has(b):
		return false
	var arma := str(b.get("arma", ""))
	if not arma.is_empty():
		if not progressao.receber_arma(arma):
			if hud != null and hud.has_method("avisar"):
				hud.avisar("Libere um espaço na mochila para pegar a arma do baú.")
			return false
	elif not progressao.receber_fruta(str(b["fruta"])):
		return false
	var nome: String = LaminasEpicFight.dados(arma).nome if not arma.is_empty() else PerfilDeFrutas.nome_da_fruta(str(b["fruta"]))
	var raridade: String = PerfilDeFrutas.NOMES_DO_PODER[int(b["poder"]) - 1]
	_remover(b, true)
	_gravar()
	if hud != null and hud.has_method("avisar"):
		hud.avisar(("%s  ·  %s  ·  na mochila" if not arma.is_empty() else "%s  ·  %s  ·  guardada em N › FRUTAS") % [nome, raridade])
	return true


# ------------------------------------------------------------------ cena e save
func _criar(id: int, pos: Vector3, fruta: String, poder: int, arma := "") -> Dictionary:
	var no := Node3D.new()
	no.name = "BauDeChefe_%d" % id
	add_child(no)
	no.global_position = pos
	no.rotation.y = rng.randf() * TAU
	var cor: Color = COR_DO_PODER[poder - 1]
	var modelo := BauTesouros.modelo()
	if modelo != null:
		modelo.scale = Vector3.ONE * (1.1 + 0.1 * poder)
		no.add_child(modelo)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.2 + 0.4 * poder
	luz.omni_range = 4.0 + poder
	luz.shadow_enabled = false
	no.add_child(luz)
	luz.position = Vector3(0, 1.1, 0)
	var rotulo := Label3D.new()
	rotulo.text = "BAÚ " + str(NOMES_DO_BAU[poder - 1]).to_upper()
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.modulate = cor
	rotulo.outline_size = 10
	rotulo.pixel_size = 0.008
	rotulo.font_size = 40
	rotulo.no_depth_test = false
	no.add_child(rotulo)
	rotulo.position = Vector3(0, 1.9, 0)
	var b := {"id": id, "pos": pos, "fruta": fruta, "arma": arma, "poder": poder, "no": no}
	baus.append(b)
	return b


func _remover(b: Dictionary, abrindo := false) -> void:
	baus.erase(b)
	var no := b.get("no") as Node3D
	if not is_instance_valid(no):
		return
	if abrindo and is_inside_tree():
		var t := create_tween().set_parallel(true)
		t.tween_property(no, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(no.queue_free)
	else:
		no.queue_free()


func _gravar() -> void:
	if progressao == null:
		return
	var lista: Array = []
	for b in baus:
		var p: Vector3 = b["pos"]
		lista.append({"id": b["id"], "x": p.x, "y": p.y, "z": p.z, "fruta": b["fruta"], "arma": b.get("arma", ""), "poder": b["poder"]})
	progressao.gravar_dados(SISTEMA, {"lista": lista, "proximo": _proximo_id, "fixos": _fixos})


## Raio de cima para baixo até o terreno (até 12 m abaixo); sem chão achado, fica onde está.
func _no_chao(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var espaco := get_world_3d().direct_space_state
	var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 12.0, 1))
	return (hit["position"] as Vector3) + Vector3.UP * 0.02 if not hit.is_empty() else p
