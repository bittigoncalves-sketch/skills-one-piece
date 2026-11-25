class_name IaUnificada
extends Node
## BASE DA IA UNIFICADA (10/11/2026, pedido do dono). Antes, cada criatura longe do jogador rodava a PRÓPRIA IA (a do mod, cérebro, corpo,
## animação): com ~90 acordadas o passo de física passava de 16 ms e o jogo caía a ~8 FPS (docs/DESEMPENHO_PASSOS_DE_FISICA.md).
## Agora há UM gerenciador por família de criaturas — `IaDosInimigos` (por FACÇÃO) e `IaDosAnimais` (por LOCOMOÇÃO) — e a criatura
## longe do jogador e fora de combate fica DORMENTE: corpo, cérebro, IA do mod, executor e animação deixam de processar (custo ~0).
## O gerenciador decide quem dorme e quem acorda numa passada a cada `CICLO` e cuida do repouso de todos os dormentes.
## Esta base tem o motor; as filhas dizem QUEM gerencia, a CHAVE do grupo, os RAIOS de cada grupo e a COESÃO.
##  • raios = (acordar, dormir): histerese, para não piscar na borda;
##  • coesão: quem está a menos de `coesao` m de um companheiro do mesmo grupo que está acordado POR SI (perto do jogador, em combate,
##    ferido, ou chefe-âncora) fica acordado também — o grupo não fica metade congelado no meio da luta;
##  • chefes nunca dormem; servem de âncora ao grupo deles.
## Ligar/desligar: `ligada` (só em medições, ou se algo distante precisar agir com o jogador longe).

const CICLO := 0.5
## Depois de acordar por dano/combate, não volta a dormir por este tempo.
const FICA_ACORDADO_S := 8.0
## Repouso dos dormentes: fração da vida máxima recuperada por segundo.
const REPOUSO_POR_SEGUNDO := 0.02
const META_ATE := "ia_acordada_ate_ms"
const GRUPO_DOS_GERENCIADORES := "ia_unificada"
## Latentes que saem da latência por quadro (acordar 63 de uma vez era um engasgo de ~1 s: cada um roda o `ao_nascer` do mod).
const POR_QUADRO := 3

static var ligada := true

var dormentes := 0             # quantos estão dormindo agora (leitura/teste)
var _relogio := 0.0
var _repouso := 0.0
var _fila: Array = []


func _ready() -> void:
	add_to_group(GRUPO_DOS_GERENCIADORES)


# ------------------------------------------------------- a sobrescrever
## Candidatos (nós vivos na árvore). A base não gerencia ninguém.
func membros() -> Array:
	return []


## Esta criatura entra no gerenciamento (vivo, do tipo certo, não-chefe)?
func e_gerenciavel(_no: Node) -> bool:
	return false


## Chefe/líder que nunca dorme mas ancora o grupo.
func e_ancora(_no: Node) -> bool:
	return false


## Grupo da criatura (facção, locomoção…).
func chave(_no: Node) -> String:
	return ""


## (distância para acordar, distância para dormir) em metros.
func raios(_chave: String) -> Vector2:
	return Vector2(60.0, 80.0)


func coesao(_chave: String) -> float:
	return 0.0


## Chamado quando `origem` leva dano: o gerenciador pode acordar o grupo dela.
func alertar(_origem: Node) -> void:
	pass


# ------------------------------------------------------------- o motor
func _process(delta: float) -> void:
	var n := 0
	while n < POR_QUADRO and not _fila.is_empty():
		Povoamento.latente(_fila.pop_front(), false)
		n += 1
	_relogio -= delta
	_repouso += delta
	if _relogio > 0.0:
		return
	_relogio = CICLO
	varrer(_repouso)
	_repouso = 0.0


## Uma passada. `dt` = tempo desde a anterior (repouso dos dormentes).
func varrer(dt: float) -> void:
	if not ligada or not is_inside_tree():
		return
	var jogadores := get_tree().get_nodes_in_group("player")
	if jogadores.is_empty():
		return
	var agora := Time.get_ticks_msec()
	var grupos := {}                         # chave → Array de {no, d2, por_si, fixo}
	for no in membros():
		var gerenciavel := e_gerenciavel(no)
		if not gerenciavel and not e_ancora(no):
			continue
		var d2 := INF
		for j in jogadores:
			if is_instance_valid(j):
				d2 = minf(d2, (j as Node3D).global_position.distance_squared_to((no as Node3D).global_position))
		var k := chave(no)
		if not grupos.has(k):
			grupos[k] = []
		grupos[k].append({"no": no, "d2": d2, "fixo": not gerenciavel, "por_si": not gerenciavel})
	var n_dormindo := 0
	for k in grupos:
		var lista: Array = grupos[k]
		var r := raios(k)
		var acordar2 := r.x * r.x
		var dormir2 := r.y * r.y
		# 1) quem fica acordado POR SI (histerese: dormindo só acorda dentro de `acordar`; acordado só dorme além de `dormir`)
		for it in lista:
			if it.fixo:
				continue
			var no: Node = it.no
			if dormindo(no):
				it.por_si = it.d2 < acordar2
			else:
				it.por_si = it.d2 <= dormir2 or agora < int(no.get_meta(META_ATE, 0)) or em_combate(no)
		# 2) coesão com os companheiros que estão acordados por si
		var raio_coesao := coesao(k)
		var coes2 := raio_coesao * raio_coesao
		for it in lista:
			it.acordado = it.por_si
			if not it.acordado and raio_coesao > 0.0:
				var p: Vector3 = (it.no as Node3D).global_position
				for outro in lista:
					if outro != it and outro.por_si and p.distance_squared_to((outro.no as Node3D).global_position) < coes2:
						it.acordado = true
						break
		# 3) aplica
		for it in lista:
			if it.fixo:
				continue
			var no2: Node = it.no
			if it.acordado:
				acordar(no2)
			else:
				if not dormindo(no2):
					dormir(no2)
				n_dormindo += 1
				repousar(no2, dt)
	dormentes = n_dormindo


func em_combate(no: Node) -> bool:
	return no.has_method("em_combate") and bool(no.em_combate())


## Rotina única dos dormentes: recuperam vida devagar (capanga não: a vida dele é por golpes).
func repousar(no: Node, dt: float) -> void:
	if no.get("capanga") == true and PersonagemMinePiece.CAPANGA_POR_GOLPES:
		return
	var vida := float(no.get("health"))
	var maxima := float(no.get("max_health"))
	if maxima > 0.0 and vida < maxima:
		no.set("health", minf(maxima, vida + maxima * REPOUSO_POR_SEGUNDO * dt))


## Enfileira criaturas latentes para ativar em lotes (mais perto do `centro` primeiro).
func ativar_em_lotes(nos: Array, centro: Vector3) -> void:
	var validos := nos.filter(func(n): return is_instance_valid(n) and n is Node3D)
	validos.sort_custom(func(a, b): return (a as Node3D).global_position.distance_squared_to(centro) < (b as Node3D).global_position.distance_squared_to(centro))
	_fila.append_array(validos)


func cancelar_fila() -> void:
	_fila.clear()


func pendentes_de_ativacao() -> int:
	return _fila.size()


# ------------------------------------------------------ estado da criatura
static func dormindo(no: Node) -> bool:
	return no.has_meta("ia_dormente")


## Corpo e filhos (cérebro, IA do mod, executor, animação) param de processar. Guarda o modo de cada filho para devolver igual.
static func dormir(no: Node) -> void:
	if dormindo(no):
		return
	no.set_meta("ia_dormente", true)
	no.set_physics_process(false)
	no.set_process(false)
	if no is CharacterBody3D:
		(no as CharacterBody3D).velocity = Vector3.ZERO
	for filho in no.get_children():
		filho.set_meta("ia_modo_antes", filho.process_mode)
		filho.process_mode = Node.PROCESS_MODE_DISABLED


static func acordar(no: Node) -> void:
	if not dormindo(no):
		return
	no.remove_meta("ia_dormente")
	no.set_physics_process(true)
	no.set_process(true)
	for filho in no.get_children():
		if filho.has_meta("ia_modo_antes"):
			filho.process_mode = int(filho.get_meta("ia_modo_antes"))
			filho.remove_meta("ia_modo_antes")


## Chamado pelo `take_damage` da criatura: acorda na hora, fica acordada por `FICA_ACORDADO_S` e avisa o gerenciador (alerta do grupo).
static func acordar_por_dano(no: Node) -> void:
	no.set_meta(META_ATE, Time.get_ticks_msec() + int(FICA_ACORDADO_S * 1000.0))
	acordar(no)
	if no.is_inside_tree():
		no.get_tree().call_group(GRUPO_DOS_GERENCIADORES, "alertar", no)
