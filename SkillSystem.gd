class_name SkillSystem
extends Node

# ============================================================================
#  SKILL SYSTEM — Definição e Execução de Habilidades (Z, X, C, V)
#  Suporta 5 Frutas Iniciais com Z, X, C, V totalmente programadas:
#   1. Gomu Gomu no Mi
#   2. Mera Mera no Mi
#   3. Bara Bara no Mi
#   4. Goro Goro no Mi
#   5. Yami Yami no Mi
#
#  MECÂNICAS DE COMBATE:
#   - Desativação/Interrupção de skill sobre dano (Hit-Stun / Stagger).
#   - Morte instantânea ao cair no Void (y < -40m; -150m no Modo História).
#   - Knockback escalado inversamente pela Vida Atual (Quanto menor HP, maior a repulsão).
#   - Passiva da Yami Yami: Desativação temporária dos poderes de usuários próximos.
# ============================================================================

# Dicionário de Skills Z, X, C, V.
#
# ⚠️ O DANO NÃO MORA MAIS AQUI (2026-08-21). Este dicionário guarda a
# IDENTIDADE da skill — nome e cor, que é o que a HUD lê — e o dano vem de
# `src/combat/Balance.gd`, a tabela única do jogo.
#
# Por que a mudança: o campo `dano` daqui significava quatro coisas diferentes
# dependendo da skill (dano de um golpe na Gomu Z, dano POR BALA na Buki,
# orçamento a dividir em 16 no Gatling, dano de CADA UM dos 25 escombros no
# Liberation), e além disso convivia com vinte e quatro multiplicadores literais
# escritos dentro dos arquivos de efeito. O número desta tabela não descrevia o
# golpe: a Gura V dizia 85 e tirava 20 de uma vida de 2048; a Yami V dizia 60 e
# tirava 1811.
#
# `dano` continua sendo devolvido, agora derivado do `Balance`, para não quebrar
# quem já lia este dicionário. Quem for aplicar dano deve usar `spec`.
static func get_fruit_skills() -> Dictionary:
	var identidade := {
		"tori_tori_phoenix": {
			"Z": {"nome": "Forma Fênix", "cor": Color("23ceff"), "alternavel": true},
			"X": {"nome": "Chama da Fênix", "cor": Color("16bfff")},
			"C": {"nome": "Garras Celestes", "cor": Color("ffc452")},
			"V": {"nome": "Renascimento", "cor": Color("59e9ff")},
			"F": {"nome": "Voo da Fênix", "cor": Color("ffc452")},
		},
		"magu_magu": {
			"Z": {"nome": "Punho de Lava", "cor": Color("ff581c")},
			"X": {"nome": "Onda de Lava", "cor": Color("ed3812")},
			"C": {"nome": "Cão de Lava", "cor": Color("ff8a25")},
			"V": {"nome": "Erupção", "cor": Color("ffb33a")},
		},
		"rocket": {
			"Z": {"nome": "Rocket Punch", "cor": Color(1.0, 0.38, 0.06)},
			"X": {"nome": "Rocket Crash", "cor": Color(1.0, 0.5, 0.1)},
			"C": {"nome": "Rocket Barrage", "cor": Color(1.0, 0.65, 0.18)},
			"V": {"nome": "Rocket Overdrive", "cor": Color(1.0, 0.85, 0.4)}
		},
		"ope_ope": {
			"Z": {"nome": "ROOM · Campo Cirúrgico", "cor": Color(0.22, 0.91, 0.95)},
			"X": {"nome": "Shambles · Troca Espacial", "cor": Color(0.55, 0.95, 1.0)},
			"C": {"nome": "Takt · Telecinese", "cor": Color(0.32, 0.82, 0.90)},
			"V": {"nome": "Gamma Knife", "cor": Color(0.55, 1.0, 0.38)}
		},
		"gomu_gomu": {
			"Z": {"nome": "Gomu Gomu no Pistol", "cor": Color(0.85, 0.25, 0.2)},
			"X": {"nome": "Gomu Gomu no Bazooka", "cor": Color(0.9, 0.35, 0.15)},
			"C": {"nome": "Gomu Gomu no Gatling", "cor": Color(0.95, 0.5, 0.1)},
			"V": {"nome": "Gear 2 (Transformação)", "cor": Color(1.0, 0.15, 0.15)}
		},
		"gomu_gomu_gear2": {
			"Z": {"nome": "Gomu Gomu no Jet Pistol", "cor": Color(1.0, 0.35, 0.3)},
			"X": {"nome": "Gomu Gomu no Jet Bazooka", "cor": Color(1.0, 0.45, 0.2)},
			"C": {"nome": "Gear 3 · Gigant Pistol", "cor": Color(1.0, 0.75, 0.15)},
			"V": {"nome": "Desativar Gear 2", "cor": Color(0.7, 0.7, 0.75)}
		},
		"gura_gura": {
			"Z": {"nome": "Gura Punch (Soco do Tremor)", "cor": Color(0.85, 0.94, 1.0)},
			"X": {"nome": "Shockwave (Onda de Choque)", "cor": Color(0.8, 0.9, 1.0)},
			"C": {"nome": "Kabutsuchi (Erupção)", "cor": Color(0.7, 0.85, 1.0)},
			"V": {"nome": "Tsunamis Duplos", "cor": Color(0.9, 0.96, 1.0)}
		},
		"mera_mera": {
			"Z": {"nome": "Tiros de Pistola de Fogo", "cor": Color(1.0, 0.45, 0.1)},
			"X": {"nome": "Hiken (Punho de Fogo)", "cor": Color(1.0, 0.25, 0.0)},
			"C": {"nome": "Vagalumes de Fogo", "cor": Color(1.0, 0.8, 0.0)},
			"V": {"nome": "Dai Enkai: Entei (Sol Quadrado)", "cor": Color(1.0, 0.65, 0.1)}
		},
		# BOMU BOMU — fruta de teste deliberadamente enxuta: só Z e X. C/V
		# permanecem visíveis na barra, mas desativados, para a tecla nunca lançar
		# um efeito genérico sem hitbox.
		"bomu_bomu": {
			"Z": {"nome": "Impacto Detonador", "cor": Color(1.0, 0.48, 0.08)},
			"X": {"nome": "Detonação Corporal", "cor": Color(1.0, 0.72, 0.12)},
			"C": {"nome": "— (sem técnica)", "cor": Color(0.35, 0.22, 0.12), "desabilitado": true},
			"V": {"nome": "— (sem técnica)", "cor": Color(0.35, 0.22, 0.12), "desabilitado": true}
		},
		"suke_suke": {
			"Z": {"nome": "Camuflagem Transparente", "cor": Color(0.62, 0.86, 1.0)},
			"X": {"nome": "— (sem técnica)", "cor": Color(0.2, 0.3, 0.4), "desabilitado": true},
			"C": {"nome": "— (sem técnica)", "cor": Color(0.2, 0.3, 0.4), "desabilitado": true},
			"V": {"nome": "— (sem técnica)", "cor": Color(0.2, 0.3, 0.4), "desabilitado": true}
		},
		"bara_bara": {
			"Z": {"nome": "Punho Destacado", "cor": Color("be65ae")},
			"X": {"nome": "Pinça Bara", "cor": Color("e5bceb")},
			"C": {"nome": "Canhão — Buggy Ball", "cor": Color("f3ad50")},
			"V": {"nome": "Festival Bara", "cor": Color("d765ad")}
		},
		"goro_goro": {
			"Z": {"nome": "Sango (Feixe Elétrico)", "cor": Color(0.95, 0.95, 0.3)},
			"X": {"nome": "El Thor (Coluna de Raio)", "cor": Color(1.0, 0.85, 0.1)},
			"C": {"nome": "Shunshin (Teleporte Raio)", "cor": Color(0.9, 0.9, 0.5)},
			"V": {"nome": "Mamaragan (Tempestade)", "cor": Color(1.0, 1.0, 0.2)}
		},
		"yami_yami": {
			"Z": {"nome": "Disparo de Pistola", "cor": Color(0.25, 0.1, 0.35)},
			"X": {"nome": "Espiral Negra (Kurouzu)", "cor": Color(0.15, 0.05, 0.25)},
			"C": {"nome": "Black Hole (Vórtice Abissal)", "cor": Color(0.1, 0.02, 0.15)},
			"V": {"nome": "Liberation (Libertação)", "cor": Color(0.3, 0.2, 0.4)}
		},
		"suna_suna": {
			"Z": {"nome": "Desert Spada (Lâmina de Areia)", "cor": Color(0.95, 0.8, 0.45)},
			"X": {"nome": "Sables (Tornado de Areia)", "cor": Color(0.9, 0.72, 0.35)},
			"C": {"nome": "Desert Girasole (Movediça)", "cor": Color(0.85, 0.65, 0.25)},
			"V": {"nome": "Suna no Sabaku (Deserto Vivo)", "cor": Color(0.98, 0.82, 0.4)}
		},
		# BUKI BUKI — arsenal de FPS (regra do dono, 2026-08-11): a tecla EMPUNHA
		# a arma, o botão esquerdo atira, e a munição é a penalidade.
		# ⚠️ O dano da Buki é POR BALA (ver `Balance.FRUTAS.buki_buki`). O nº de
		# balas e a cadência ficam em `BukiFX.ARSENAL`, e a recarga do slot só
		# corre depois que a arma é largada.
		"buki_buki": {
			"Z": {"nome": "Pistola (12 balas)", "cor": Color(0.78, 0.82, 0.88)},
			"X": {"nome": "Canhão — corpo inteiro (3 tiros)", "cor": Color(0.88, 0.92, 1.0)},
			"C": {"nome": "Sniper (5 tiros, luneta no Bt Dir)", "cor": Color(0.70, 0.74, 0.80)},
			"V": {"nome": "Minigun (100 balas)", "cor": Color(0.95, 0.97, 1.0)}
		},
		"hie_hie": {
			"Z": {"nome": "Disparo de Gelo", "cor": Color(0.5, 0.8, 1.0)},
			"X": {"nome": "Iceberg", "cor": Color(0.45, 0.75, 1.0)},
			"C": {"nome": "Investida de Gelo", "cor": Color(0.6, 0.85, 1.0)},
			"V": {"nome": "Ice Age (Era do Gelo)", "cor": Color(0.7, 0.9, 1.0)}
		},
		# PIKA PIKA — Z e X preservam as técnicas já implementadas; C é a barragem
		# massiva que nasce no personagem e V é a chuva de luz que nasce no céu.
		"pika_pika": {
			"Z": {"nome": "Salva de Luz", "cor": Color(1.0, 0.92, 0.55)},
			"X": {"nome": "Yata no Kagami", "cor": Color(1.0, 0.88, 0.42)},
			"C": {"nome": "Yasakani no Magatama", "cor": Color(1.0, 0.84, 0.28)},
			"V": {"nome": "Chuva de Luz", "cor": Color(1.0, 0.94, 0.62)}
		}
	}
	# Casa a identidade com a tabela de dano e com a recarga padronizada do slot.
	# Qualquer skill registrada aqui no futuro entra no mesmo contrato sem código
	# novo — é só ter uma linha correspondente no `Balance`.
	for f_id in identidade:
		for slot in identidade[f_id]:
			var linha: Dictionary = identidade[f_id][slot]
			var molde := Balance.spec(f_id, slot)
			linha["spec"] = molde
			linha["dano"] = molde.dano if molde != null else 0.0
			linha["cooldown"] = get_slot_cooldown(slot, f_id)
	return identidade

## A recarga que a ARENA aplica de fato ao usar a técnica (`Player.trigger_skill_cooldown`):
## Ope, Bara e Rocket usam a tabela abaixo; Bomu e Suke, 10 s; as outras, a recarga
## fixa por tecla do Player. Existe para a ficha da história gerada da arena
## (`PerfilDeFrutas.da_arena`) mostrar e aplicar o MESMO número.
## GATILHO: mudou a regra no `Player.trigger_skill_cooldown`, mudar aqui — o
## `test_frutas_na_historia` compara as duas para toda fruta e tecla.
const RECARGA_POR_SLOT_DA_ARENA := {"Z": 5.0, "X": 7.0, "C": 10.0, "V": 25.0}

static func recarga_da_arena(slot: String, fruit_id: String) -> float:
	if fruit_id in ["ope_ope", "bara_bara", "rocket", "tori_tori_phoenix"]:
		return get_slot_cooldown(slot, fruit_id)
	if fruit_id in ["bomu_bomu", "suke_suke"]:
		return 10.0
	return float(RECARGA_POR_SLOT_DA_ARENA.get(slot, 0.0))


static func get_slot_cooldown(slot: String, fruit_id: String = "") -> float:
	if fruit_id == "tori_tori_phoenix":
		return float({"Z": 1.0, "X": 7.0, "C": 10.0, "V": 25.0, "F": 1.0}.get(slot, 1.0))
	if fruit_id == "rocket":
		return float({"Z": 5.0, "X": 7.0, "C": 10.0, "V": 35.0}.get(slot, 5.0))
	if fruit_id == "bara_bara":
		return float({"Z": 5.0, "X": 7.0, "C": 10.0, "V": 25.0}.get(slot, 5.0))
	if fruit_id == "ope_ope":
		return float({"Z": 8.0, "X": 6.0, "C": 10.0, "V": 22.0}.get(slot, 8.0))
	if fruit_id == "bomu_bomu":
		return 10.0
	match slot:
		"Z": return 5.0
		"X": return 7.0
		"C": return 10.0
		"V": return 60.0
	return 5.0

# ------------------------------------------------ CALCULO DE KNOCKBACK DINAMICO
# Quanto menor a HP atual em relacao a HP Máxima, maior o knockback sofrido.
static func calculate_knockback(base_force: Vector3, current_hp: float, max_hp: float) -> Vector3:
	var hp_ratio := clampf(current_hp / max_hp, 0.05, 1.0)
	var hp_multiplier := 1.0 + 2.5 * (1.0 - hp_ratio) # Variacao de 1.0x (100% HP) ate 3.37x (5% HP)
	return base_force * hp_multiplier

# ----------------------------------------------- DESATIVAÇÂO DE ATAQUE SOBRE DANO
# Interrompe a habilidade em andamento se o personagem sofrer dano (Hit-Stun)
static func interrupt_casting(caster: CharacterBody3D) -> bool:
	if caster and caster.has_meta("is_casting") and caster.get_meta("is_casting"):
		caster.set_meta("is_casting", false)
		print("💥 ATAQUE INTERROMPIDO! Dano recebido durante o cast de skill.")
		return true
	return false

# ---------------------------------------------- SISTEMA DE VOID (MORTE AO CAIR)
# Se a posicao Y do personagem for menor que Scoreboard.void_y_de (-40m; -150m na história), aciona morte instantanea e respawn
static func process_void_check(actor: CharacterBody3D) -> bool:
	if actor and actor.global_position.y < Scoreboard.void_y_de(actor):
		print("💀 CAIU NO VOID! Morte instantânea acionada.")
		if actor.has_method("die_and_respawn"):
			actor.die_and_respawn()
		else:
			actor.global_position = Vector3(0, 6, 0)
			actor.velocity = Vector3.ZERO
		return true
	return false

# ----------------------------------- PASSIVA YAMI YAMI: SUPRESSÃO DE HABILIDADES
# Desativa temporariamente as habilidades dos alvos num raio de 8 metros
static func apply_yami_suppression(yami_user: Node3D, all_targets: Array) -> void:
	var radius := 8.0
	for t in all_targets:
		if is_instance_valid(t) and t != yami_user and t is Node3D:
			var dist := yami_user.global_position.distance_to(t.global_position)
			if dist <= radius:
				if t.has_method("suppress_skills_temporarily"):
					t.suppress_skills_temporarily(3.0) # 3 segundos de desativação
