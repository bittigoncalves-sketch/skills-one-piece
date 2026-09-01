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
#   - Morte instantânea ao cair no Void (y < -40m).
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
		"gomu_gomu": {
			"Z": {"nome": "Gomu Gomu no Pistol", "cor": Color(0.85, 0.25, 0.2)},
			"X": {"nome": "Gomu Gomu no Bazooka", "cor": Color(0.9, 0.35, 0.15)},
			"C": {"nome": "Gomu Gomu no Gatling", "cor": Color(0.95, 0.5, 0.1)},
			"V": {"nome": "Gear 2 / Red Hawk", "cor": Color(1.0, 0.15, 0.15)}
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
			"Z": {"nome": "Corte Único (Dismantle)", "cor": Color(0.8, 0.1, 0.1)},
			"X": {"nome": "Buggy Ball", "cor": Color(1.0, 0.0, 0.0)},
			"C": {"nome": "Área Cortante (Cleave)", "cor": Color(0.6, 0.0, 0.0)},
			"V": {"nome": "Expansão de Domínio (Shrine)", "cor": Color(0.3, 0.0, 0.0)}
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

static func get_slot_cooldown(slot: String, fruit_id: String = "") -> float:
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
# Se a posicao Y do personagem for menor que -40m, aciona morte instantanea e respawn
static func process_void_check(actor: CharacterBody3D) -> bool:
	if actor and actor.global_position.y < -40.0:
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
