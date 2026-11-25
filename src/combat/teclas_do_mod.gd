class_name TeclasDoMod
extends RefCounted
## TECLAS DO MOD QUE NÃO DEPENDEM DE FRUTA (09/11/2026, itens 2 e 3 da auditoria). O mod tem 10 `KeyMapping`; o jogo já ocupa várias teclas dele, então a
## equivalência decidida (sem o dono) foi:
##   • H  = Haki do Rei  → `KeyHaoshokuHakiOnKeyPressed` (no mod é a M, que aqui abre a central). Pede a conquista `skill_haoshoku_haki`, senão o mod avisa "não pode usar".
##   • G  = Modo de batalha → `KeyBattleModeOnKeyPressed` (liga/desliga `PlayerBattleMode`; DESLIGADO o mod não deixa iniciar técnica — é assim no original).
##   • Backstep (S duplo), Forward (W duplo) e Espaço do mod NÃO foram mapeados: o jogo tem esquiva, dash e pulo nativos (Q, Espaço, pulo no ar). GATILHO: se o dono
##     quiser as conquistas `back_step`/`forward`/`space` ligadas a esses movimentos nativos, chamar as procedures `KeyBackstep…`/`KeyForward…` quando o movimento acontecer.
## Os outros `Key*` do mod (R trocar técnica, Z/X/C/V iniciar, N transformar) já estão no `ControladorFrutaDoMod` (Z X C V B N por técnica, J transforma).

const HAKI_DO_REI := KEY_H
const MODO_DE_BATALHA := KEY_G


## Trata a tecla se ela for uma das do mod. Devolve true quando consumiu (a HUD não a passa adiante).
static func tratar(jogador: Node, tecla: int) -> bool:
	if jogador == null or not is_instance_valid(jogador):
		return false
	if tecla == HAKI_DO_REI:
		haki_do_rei(jogador)
		return true
	if tecla == MODO_DE_BATALHA:
		modo_de_batalha(jogador)
		return true
	return false


static func haki_do_rei(jogador: Node) -> void:
	var e := McEntidade.de(jogador)
	Mc.proc(&"KeyHaoshokuHakiOnKeyPressedProcedure").execute(e)


## Alterna o modo de batalha e devolve o novo estado (o mod também manda a mensagem de título).
static func modo_de_batalha(jogador: Node) -> bool:
	var e := McEntidade.de(jogador)
	var v = e.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	Mc.proc(&"KeyBattleModeOnKeyPressedProcedure").execute(e.level(), e)
	var ligado: bool = bool(v.PlayerBattleMode) if v != null else true
	var hud := jogador.get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("avisar"):
		hud.avisar("Modo de batalha: %s" % ("LIGADO" if ligado else "DESLIGADO (técnicas bloqueadas)"))
	return ligado
