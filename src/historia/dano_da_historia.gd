class_name DanoDaHistoria
extends RefCounted
## DANO DE COMBATE NO MODO HISTÓRIA. Dois fatores, um por ponta: o dano que chega aos alvos que não são o jogador (`fator`, em
## `CombatResolver.aplicar`) e o que o jogador recebe (`fator_recebido`, em `Player.take_damage`).
## 08/11/2026 (dono: "o jogador não só dá como também recebe muito dano"): metade nas duas pontas.
## 11/11/2026 (dono: "jogador recebendo muito pouco dano"): o recebido volta a 1.0 — o dobro do que era; o causado segue em 0,5.
## A armadura/tenacidade/Resistência do nível (`AtributosMinePiece.dano_recebido`) continuam cortando por cima.
##
## Só vale na campanha de verdade. Quem força o save/mapa (`ModoHistoria.progresso_forcado`, o que todo teste faz) roda com 1.0, para os
## testes de balanceamento continuarem medindo os números brutos. Arena e PvP nunca ligam (fica em 1.0).
const FATOR_DA_CAMPANHA := 0.5
const FATOR_RECEBIDO_DA_CAMPANHA := 1.0
static var fator := 1.0
static var fator_recebido := 1.0


static func ligar_para(campanha_de_verdade: bool) -> void:
	fator = FATOR_DA_CAMPANHA if campanha_de_verdade else 1.0
	fator_recebido = FATOR_RECEBIDO_DA_CAMPANHA if campanha_de_verdade else 1.0
