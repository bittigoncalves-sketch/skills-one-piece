# OTIMIZADA a partir de gerado/procedures/ReturnDevilFruitEatenProcedure.gd (09/11/2026) — NÃO é gerada: ver `Mc.OTIMIZADAS`.
#
# POR QUE: toda IA do mod (e o `DamageFix` de cada `RangeAttack`) pergunta "que fruta esta entidade comeu?" — e para quem não é jogador a resposta só
# depende da CLASSE da entidade, mas o original varre ~100 entradas com `Mc.e` a cada pergunta (0,14 ms). A lâmina do X faz 1.350 por tick.
# O QUE MUDA (só isto): `execute` guarda o resultado no corpo (`mc_fruta_cache`), validado pelo `id_personagem` do corpo; o jogador nunca é guardado
# (a fruta dele muda). O resultado guardado é uma cópia e é devolvido sempre por CÓPIA (quem altera a pilha recebida não corrompe o cache). O cálculo é o original, em `_calcular`.
# EQUIVALÊNCIA: `tools/dev_tests/test_procedures_otimizadas.gd`. GATILHO: ao regerar a original com mudança, refazer esta cópia.
# GERADO por tools/mine_piece/tradutor/traduzir.py de ReturnDevilFruitEatenProcedure.java — não editar.
extends RefCounted


static func execute(entity):
	if entity == null or not (entity is McEntidade) or Mc.e(entity, &"Player"):
		return _calcular(entity)
	var no: Node = (entity as McEntidade).no
	var id := str(no.get("id_personagem")) if "id_personagem" in no else ""
	if no.has_meta(&"mc_fruta_cache"):
		var c: Array = no.get_meta(&"mc_fruta_cache")
		if c[0] == id:
			return c[1].copy()
	var r = _calcular(entity)
	no.set_meta(&"mc_fruta_cache", [id, r.copy()])      # guarda UMA CÓPIA e devolve sempre cópia: quem altera a pilha recebida não corrompe o cache
	return r


static var ENTITY_DEVIL_FRUIT_MAP = {}
static func _calcular(entity):
	if (entity == null):
		return Mc.campo(&"ItemStack", &"EMPTY")
	if (Mc.e(entity, &"Player")):
		return (entity.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(Mc.novo(&"PlayerVariables", []))).PlayerDevilFruit
	for entry in Mc.entradas(ENTITY_DEVIL_FRUIT_MAP):
		if (Mc.e(entity, entry.getKey())):
			return Mc.obter0(entry.getValue())
	return (Mc.campo(&"ItemStack", &"EMPTY") if not ((Mc.e(entity, &"BrookEntity"))) and not ((Mc.e(entity, &"BuggyEntity"))) and not ((Mc.e(entity, &"Alvida2Entity"))) and not ((Mc.e(entity, &"KalifaCP9Entity"))) and not ((Mc.e(entity, &"BluenoCP9Entity"))) and not ((Mc.e(entity, &"BonClayEntity"))) and not ((Mc.e(entity, &"ScratchmenApooEntity"))) and not ((Mc.e(entity, &"XDrakeEntity"))) and not ((Mc.e(entity, &"BramenkoEntity"))) and not ((Mc.e(entity, &"PageOneEntity"))) and not ((Mc.e(entity, &"JackEntity"))) and not ((Mc.e(entity, &"SSharkEntity"))) else Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit")]))

static func _static_init() -> void:
	var _lambda_1 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gomu_gomu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"LuffyEastBlueEntity", _lambda_1)
	var _lambda_2 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gomu_gomu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Luffy1Entity", _lambda_2)
	var _lambda_3 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gomu_gomu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Luffy2YearsLaterEntity", _lambda_3)
	var _lambda_4 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gomu_gomu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"LuffyWanoCountryEntity", _lambda_4)
	var _lambda_5 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mera_mera")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Ace1Entity", _lambda_5)
	var _lambda_6 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mera_mera")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SaboEntity", _lambda_6)
	var _lambda_7 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mera_mera")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SaboFlameEmperorEntity", _lambda_7)
	var _lambda_8 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_moku_moku")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SmokerEntity", _lambda_8)
	var _lambda_9 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_moku_moku")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Smoker2YearsEntity", _lambda_9)
	var _lambda_10 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_kiro_kiro")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"MsValentineEntity", _lambda_10)
	var _lambda_11 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_bomu_bomu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Mr5Entity", _lambda_11)
	var _lambda_12 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_supa_supa")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"Mr1Entity", _lambda_12)
	var _lambda_13 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_suna_suna")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CrocodileEntity", _lambda_13)
	var _lambda_14 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_suna_suna")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CrocodileCrossGuildEntity", _lambda_14)
	var _lambda_15 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_riki_riki")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"JesusBurgess2Entity", _lambda_15)
	var _lambda_16 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_yami_yami")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"MarshallDTeachEntity", _lambda_16)
	var _lambda_17 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_yami_yami")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"MarshallDTeachFourEmperorsEntity", _lambda_17)
	var _lambda_18 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_goro_goro")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"EnelEntity", _lambda_18)
	var _lambda_19 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_neko_neko_leopard")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"LucciCP0Entity", _lambda_19)
	var _lambda_20 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_neko_neko_leopard")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"LucciCP9Entity", _lambda_20)
	var _lambda_21 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ushi_ushi_giraffe")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KakuCP0Entity", _lambda_21)
	var _lambda_22 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ushi_ushi_giraffe")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KakuCP9Entity", _lambda_22)
	var _lambda_23 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_inu_inu_wolf")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"JabraCP9Entity", _lambda_23)
	var _lambda_24 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_batto_batto")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"StussyEntity", _lambda_24)
	var _lambda_25 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_horo_horo")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"PeronaEntity", _lambda_25)
	var _lambda_26 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_kage_kage")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"GeckoMoriaEntity", _lambda_26)
	var _lambda_27 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ope_ope")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"TrafalgarDWaterLawGrandLineEntity", _lambda_27)
	var _lambda_28 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ope_ope")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"TrafalgarDWaterLawWanoCountryEntity", _lambda_28)
	var _lambda_29 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ope_ope")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"TrafalgarDWaterLawSevenWarlordsoftheSeaEntity", _lambda_29)
	var _lambda_30 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_tori_tori_phoenix")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"MarcoEntity", _lambda_30)
	var _lambda_31 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_kira_kira")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"JozuEntity", _lambda_31)
	var _lambda_32 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gura_gura")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"EdwardNewgateEntity", _lambda_32)
	var _lambda_33 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gura_gura")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"EdwardNewgateHeydayEntity", _lambda_33)
	var _lambda_34 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_nikyu_nikyu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KumaEntity", _lambda_34)
	var _lambda_35 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mero_mero")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"BoaHancockEntity", _lambda_35)
	var _lambda_36 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mori_mori")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"RyokugyuEntity", _lambda_36)
	var _lambda_37 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_zushi_zushi")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"FujitoraEntity", _lambda_37)
	var _lambda_38 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_pika_pika")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KizaruEntity", _lambda_38)
	var _lambda_39 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_hie_hie")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"AokijiEntity", _lambda_39)
	var _lambda_40 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_hie_hie")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KuzanEntity", _lambda_40)
	var _lambda_41 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_magu_magu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"AkainuEntity", _lambda_41)
	var _lambda_42 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_magu_magu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"AkainuFleetAdmiraEntity", _lambda_42)
	var _lambda_43 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_hito_hito_daibutsu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SengokuEntity", _lambda_43)
	var _lambda_44 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_bisu_bisu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CharlotteCrackerEntity", _lambda_44)
	var _lambda_45 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mochi_mochi")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CharlotteKatakuriEntity", _lambda_45)
	var _lambda_46 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_soru_soru")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CharlotteLinlinEntity", _lambda_46)
	var _lambda_47 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_soru_soru")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"CharlotteLinlinWanoCountryEntity", _lambda_47)
	var _lambda_48 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ryu_ryu_pachycephalosaurus")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"UltiEntity", _lambda_48)
	var _lambda_49 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_neko_neko_sabertiger")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"WhosWhoEntity", _lambda_49)
	var _lambda_50 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ryu_ryu_brachiosaurus")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"QueenEntity", _lambda_50)
	var _lambda_51 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_ryu_ryu_pteranodon")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KingEntity", _lambda_51)
	var _lambda_52 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_inu_inu_okuchi_no_makami")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"YamatoEntity", _lambda_52)
	var _lambda_53 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_uo_uo_seiryu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"KaidouEntity", _lambda_53)
	var _lambda_54 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_nikyu_nikyu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SBearEntity", _lambda_54)
	var _lambda_55 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_supa_supa")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SHawkEntity", _lambda_55)
	var _lambda_56 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mero_mero")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"SSnakeEntity", _lambda_56)
	var _lambda_57 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_aro_aro")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"GunkoEntity", _lambda_57)
	var _lambda_58 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_imu")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"ImuEntity", _lambda_58)
	var _lambda_59 = func():
		return Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_uta_uta")])
	Mc.por(ENTITY_DEVIL_FRUIT_MAP, &"UtaEntity", _lambda_59)

