class_name IaDosInimigos
extends IaUnificada
## IA UNIFICADA DOS INIMIGOS, SEPARADOS POR FACÇÃO (10/11/2026). Uma IA de esquadrão por facção, não uma por inimigo:
##  • facção = `ficha.faccao` do East Blue ("pirata:arlong", "pirata:buggy", "marinha", "raid:loguetown", "mod", "nenhuma"…) e "bandidos" para os
##    bonecos de duelo/bandidos do mapa; cada bando pirata é uma facção própria. "aliado" nunca é inimigo (nem entra no grupo `enemy`);
##  • o esquadrão fica acordado junto (coesão de 30 m): quem está perto de um companheiro acordado por si não congela no meio da luta;
##  • ALERTA: quem leva dano acorda os aliados da MESMA facção a até `ALERTA_RAIO` (40 m) e eles ficam acordados por 8 s;
##  • o CHEFE nunca dorme e é a âncora da facção dele: os capangas perto do chefe ficam acordados.

const ALERTA_RAIO := 40.0
const COESAO := 30.0
const FACCAO_DOS_BANDIDOS := "bandidos"
const FACCAO_DOS_BONECOS := "bonecos"
## Inimigo de PEÇA do editor (categoria "inimigos"; `InimigoDoMapa`): saco de pancadas que não anda. Uma facção só.
const FACCAO_DO_MAPA := "mapa"


func membros() -> Array:
	return get_tree().get_nodes_in_group("enemy")


static func faccao_de(no: Node) -> String:
	if no is PersonagemMinePiece:
		var f := str((no as PersonagemMinePiece).ficha.get("faccao", "nenhuma"))
		return f if not f.is_empty() else "nenhuma"
	if no is InimigoDoMapa:
		return FACCAO_DO_MAPA
	if no is BonecoDeDuelo:
		if no.has_meta("faccao"):
			return str(no.get_meta("faccao"))        # o ninho grava ao criar o boneco
		return FACCAO_DOS_BANDIDOS if str(no.name) == "Bandido" else FACCAO_DOS_BONECOS
	return "nenhuma"


func chave(no: Node) -> String:
	return faccao_de(no)


func e_ancora(no: Node) -> bool:
	if not (no is Node3D) or not is_instance_valid(no) or not no.is_inside_tree():
		return false
	if no is PersonagemMinePiece:
		return bool((no as PersonagemMinePiece).ficha.get("chefe", false)) and (no as PersonagemMinePiece).vivo()
	return no.is_in_group("chefes") or no.is_in_group("boss")


func e_gerenciavel(no: Node) -> bool:
	return gerenciavel(no)


## PersonagemMinePiece, BonecoDeDuelo e InimigoDoMapa (peça do editor), vivos, e nunca chefe.
static func gerenciavel(no: Node) -> bool:
	if not (no is PersonagemMinePiece or no is BonecoDeDuelo or no is InimigoDoMapa) or not is_instance_valid(no) or not no.is_inside_tree():
		return false
	if no.is_in_group("chefes") or no.is_in_group("boss"):
		return false
	if no is PersonagemMinePiece and bool((no as PersonagemMinePiece).ficha.get("chefe", false)):
		return false
	if no.has_method("vivo") and not no.vivo():
		return false
	return true


func raios(_chave: String) -> Vector2:
	return Vector2(60.0, 80.0)


func coesao(_chave: String) -> float:
	return COESAO


func em_combate(no: Node) -> bool:
	if no.has_method("em_combate"):
		return bool(no.em_combate())
	# BonecoDeDuelo: o cérebro é filho; fora de "em casa" ele está perseguindo, lutando ou voltando.
	for filho in no.get_children():
		if filho is CerebroDeInimigo:
			return (filho as CerebroDeInimigo).estado != CerebroDeInimigo.Estado.EM_CASA
	var c = no.get("combate_direcional")
	return c != null and c.has_method("atacando") and bool(c.atacando())


## Alerta de facção: os aliados do mesmo bando perto de quem apanhou acordam e ficam acordados.
func alertar(origem: Node) -> void:
	if not ligada or not (origem is Node3D) or not gerenciavel(origem):
		return
	var k := faccao_de(origem)
	var r2 := ALERTA_RAIO * ALERTA_RAIO
	var ate := Time.get_ticks_msec() + int(FICA_ACORDADO_S * 1000.0)
	for no in membros():
		if no == origem or not gerenciavel(no) or faccao_de(no) != k:
			continue
		if (no as Node3D).global_position.distance_squared_to((origem as Node3D).global_position) <= r2:
			no.set_meta(META_ATE, ate)
			acordar(no)
