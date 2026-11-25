class_name FrutasDoMod
extends RefCounted
## As frutas que o jogador usa pelo FLUXO DO MOD (03/11/2026) — sem depender do `Player`, para o save, o
## `ModoHistoria` e os testes poderem consultar sem puxar o corpo do jogador. O controlador: `ControladorFrutaDoMod`.

const PREFIXO := "minepiece:item_devil_fruit_"
## Os 40 ids de fruta do mod (`DevilFruitSkill1Procedure`/`KeyChangeTechniqueDevilFruit`).
const FRUTAS := ["aro_aro", "batto_batto", "bisu_bisu", "bomu_bomu", "gomu_gomu", "goro_goro", "gura_gura", "hie_hie",
	"hito_hito_daibutsu", "horo_horo", "imu", "inu_inu_okuchi_no_makami", "inu_inu_wolf", "kage_kage", "kira_kira",
	"kiro_kiro", "magu_magu", "mera_mera", "mero_mero", "mochi_mochi", "moku_moku", "mori_mori", "neko_neko_leopard",
	"neko_neko_sabertiger", "nikyu_nikyu", "ope_ope", "pika_pika", "riki_riki", "ryu_ryu_brachiosaurus",
	"ryu_ryu_pachycephalosaurus", "ryu_ryu_pteranodon", "soru_soru", "suna_suna", "supa_supa", "tori_tori_phoenix",
	"uo_uo_seiryu", "ushi_ushi_giraffe", "uta_uta", "yami_yami", "zushi_zushi"]


## Hitbox dos golpes do Aro Aro (08/11/2026, pedido do dono: "aumenta a hitbox dos ataques da arrow"): o cubo do `RangeAttack` (chave
## "Range") do dono e das flechas dele vale este tanto do original do mod. Ajuste do jogo: a flecha rápida (ver `FATOR_DE_PROJETIL`) falhava
## alvos no meio do caminho.
const ALCANCE_DO_ARO_ARO := 2.0


static func contem(id: String) -> bool:
	return FRUTAS.has(id)


## Perfil da história: números do mod, sem escala própria (a energia e o dano vêm das procedures).
static func perfil(id: String) -> PerfilDeFrutas:
	if not contem(id):
		return null
	var p := PerfilDeFrutas.new()
	p.fruta = id
	p.regen_de_energia = PerfilDeFrutas.REGEN_DA_ARENA
	p.escala_de_dano = PerfilDeFrutas.ESCALA_DO_MOD
	p.fiel_ao_mod = true
	return p
