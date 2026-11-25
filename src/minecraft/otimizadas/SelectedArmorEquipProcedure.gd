# OTIMIZADA/SUBSTITUÍDA a partir de gerado/procedures/SelectedArmorEquipProcedure.gd (09/11/2026) — NÃO é gerada: ver `Mc.OTIMIZADAS`.
#
# O QUE FAZIA: depois de escolher uma classe/estilo (`Select*`), vestia o TRAJE do estilo (capacete/peitoral/calça/botas do mod) no inventário de ARMADURA do
# Minecraft (`getInventory().armor`, `setItemSlot`). O jogo não tem slots de armadura do Minecraft nem as 213 roupas do mod como equipamento (item 9 da auditoria,
# "roupas como armadura do jogador") — a versão gerada abortava com erro de script no meio do fluxo de escolha de estilo.
# O QUE FAZ AGORA: nada (a escolha de estilo termina limpa). GATILHO: quando as roupas do mod entrarem como equipamento do jogador, restaurar a lógica
# (a original continua em gerado/) trocando o inventário de armadura do Minecraft pelo do jogo.
extends RefCounted

static func execute(entity, armor_chest, armor_feet, armor_head, armor_legs, other_item1, other_item2, weapon_mainhand, weapon_offhand) -> void:
	pass
