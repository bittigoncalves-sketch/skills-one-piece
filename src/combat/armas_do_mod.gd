class_name ArmasDoMod
extends RefCounted
## HABILIDADE DAS ARMAS DO MOD (09/11/2026, item 5 da auditoria): `WeaponAbilityProcedure(entity, itemstack)` define a técnica (`skill`) e a recarga de cada arma
## — martelo do Bramenko, Battle Smasher, Raiu, Daisenso, Murakumogiri, Sword King… 14 itens. Esta é a API: `usar(jogador, id_do_item)` faz o que o clique direito
## do mod faz (inclusive a recarga por item, `WeaponAbilityUsed`). O que NÃO existe ainda: o jogador SEGURAR esses itens (o inventário/armas do jogo não tem
## os itens do mod) e a tecla/clique que chama `usar`. GATILHO: ao entrarem as armas do mod no inventário (`itens_do_mod.json`, aba ARMAS), ligar o clique
## direito do item em mão a `ArmasDoMod.usar`. Os `Slot0–5`/`SlotUpdate` do mod são a GUI de equipamento do Minecraft (containerMenu): não se aplicam.

const IDS := ["arm_axe", "battle_smasher", "bramenko_hammer", "daisenso", "kiribachi", "masakari", "metal_rod", "mogura", "murakumogiri", "onitake",
	"pencil", "pretzel", "raiu", "sword_king"]


static func tem_habilidade(id: String) -> bool:
	return IDS.has(id)


## Usa a habilidade da arma `id` (sem o prefixo `minepiece:`). Devolve true se a técnica começou.
static func usar(jogador: Node, id: String) -> bool:
	if not tem_habilidade(id) or jogador == null or not is_instance_valid(jogador):
		return false
	var e := McEntidade.de(jogador)
	var item := Mc.item(StringName("minepiece:" + id))
	if e.getCooldowns().isOnCooldown(item):
		return false                                      # a arma ainda recarrega
	if e.getPersistentData().getDouble("skill") != 0.0:
		return false                                      # já há técnica em curso
	var pilha := McItem.pilha(item, 1)
	Mc.proc(&"WeaponAbilityProcedure").execute(e, pilha)
	if e.getPersistentData().getDouble("skill") == 0.0:
		return false                                      # a procedure não achou habilidade para esta arma nas condições atuais
	Mc.proc(&"WeaponAbilityUsedProcedure").execute(e, pilha)
	return true
