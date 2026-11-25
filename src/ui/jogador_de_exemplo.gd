extends Node
# ============================================================================
#  JOGADOR DE EXEMPLO — o mínimo que as janelas da HUD leem de um corpo, para o
#  EDITOR DE JANELAS mostrá-las sem jogo rodando (05/10/2026). Não é o Player: só
#  os campos que `VidaEnergiaHud`, `TecnicasHud` e o menu de pets consultam.
# ============================================================================

var health := 14.0
var max_health := 20.0
var energy := 7.0
var max_energy := 10.0
var perfil_de_frutas: PerfilDeFrutas = null
var _fruit_cooldowns := {"X": 4.2}
var nome_exibido := "Gaivota"
var modo: StringName = &"seguir"
