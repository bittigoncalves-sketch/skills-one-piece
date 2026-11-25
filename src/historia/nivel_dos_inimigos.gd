class_name NivelDosInimigos
extends Node
## NÍVEL DOS INIMIGOS DO MAPA (10/11/2026, pedido do dono: "deixar os inimigos que spawnam no mapa sempre próximos ou superior ao nível do
## jogador"). Criatura comum com nível abaixo do PISO (= nível do jogador − `FOLGA`) sobe até o piso: o nível mostrado na barra (`nivel`)
## e os números que o fazem valer o nível — vida ×(1 + 0,15 por nível) e dano ×(1 + 0,08 por nível), com teto. Nunca BAIXA quem já é forte.
## Reaplica sozinha quando o jogador sobe de nível (relativo ao que já foi aplicado, sem acumular) e quando a criatura acorda/renasce.
## O XP do abate acompanha (ele sai da vida/ataque da vítima). Fora: chefes, chefes de raid e inimigos de raid (têm estágio próprio),
## aliados do jogador, pets e NPCs. O fator de dano vai na meta `fator_dano_nivel` (lida por `JogadorDoMod`, `AnimalDaIlha` e o boneco).
## Os coeficientes são palpite meu: ajuste `VIDA_POR_NIVEL`/`DANO_POR_NIVEL`. Sem janela: medido por `test_nivel_dos_inimigos`.

const Barras := preload("res://src/ui/barras_de_criaturas.gd")
const FOLGA := 1
const VIDA_POR_NIVEL := 0.15
const DANO_POR_NIVEL := 0.08
const TETO_DE_VIDA := 8.0
const TETO_DE_DANO := 4.0
const INTERVALO := 2.0
const GRUPOS := ["enemy", "animais", "bestas_do_mar", "personagens_east_blue"]
const META_NIVEL_BASE := "nivel_base"
const META_APLICADO := "nivel_aplicado"        # níveis acima da base já aplicados

var progressao: ProgressaoDoPersonagem
var _relogio := 0.0


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	prog.subiu_de_nivel.connect(func(_de: int, _para: int): varrer())


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = INTERVALO
	varrer()


func piso() -> int:
	return maxi(1, (progressao.nivel if progressao != null else 1) - FOLGA)


func varrer() -> void:
	if progressao == null or not is_inside_tree():
		return
	var vistos := {}
	for g in GRUPOS:
		for no in get_tree().get_nodes_in_group(g):
			if vistos.has(no):
				continue
			vistos[no] = true
			ajustar(no)


static func e_elegivel(no: Node) -> bool:
	if not is_instance_valid(no) or not (no is Node3D) or no.is_queued_for_deletion():
		return false
	return not (no.is_in_group("player") or no.is_in_group(BarrasDeChefes.GRUPO) or no.is_in_group("invocados_do_jogador")
		or no.is_in_group("invocados_do_mod") or no.is_in_group("pets_historia") or no.is_in_group("npc") or no.has_meta("raider")
		or bool(no.get("ficha").get("chefe", false) if no.get("ficha") is Dictionary else false)
		or (no.has_method("boss") and bool(no.call("boss"))) or no.get("max_health") == null)


## Leva `no` ao piso. Devolve o nível final.
func ajustar(no: Node) -> int:
	if not e_elegivel(no):
		return 0
	if not no.has_meta(META_NIVEL_BASE):
		no.set_meta(META_NIVEL_BASE, Barras.nivel_de(no))
		no.set_meta(META_APLICADO, 0)
	var base: int = int(no.get_meta(META_NIVEL_BASE))
	var alvo := maxi(base, piso())
	var novo := alvo - base
	var antigo: int = int(no.get_meta(META_APLICADO))
	if novo == antigo:
		return alvo
	var f_vida_antigo := fator_de_vida(antigo)
	var f_vida := fator_de_vida(novo)
	var razao := f_vida / f_vida_antigo
	no.max_health = float(no.max_health) * razao
	no.health = float(no.health) * razao
	no.set_meta("fator_dano_nivel", fator_de_dano(novo))
	var ex: Variant = no.get("combate_direcional")                 # boneco de duelo: o dano mora no executor
	if ex != null and "multiplicador_de_dano" in ex:
		ex.multiplicador_de_dano = float(ex.multiplicador_de_dano) * fator_de_dano(novo) / fator_de_dano(antigo)
	if "nivel" in no:
		no.nivel = alvo
	no.set_meta("nivel", alvo)
	no.set_meta(META_APLICADO, novo)
	return alvo


static func fator_de_vida(niveis: int) -> float:
	return minf(1.0 + VIDA_POR_NIVEL * float(niveis), TETO_DE_VIDA)


static func fator_de_dano(niveis: int) -> float:
	return minf(1.0 + DANO_POR_NIVEL * float(niveis), TETO_DE_DANO)
