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

# Dicionário de Skills Z, X, C, V para as 5 Frutas
static func get_fruit_skills() -> Dictionary:
	var skills := {
		"gomu_gomu": {
			"Z": {"nome": "Gomu Gomu no Pistol", "cor": Color(0.85, 0.25, 0.2), "dano": 25, "cooldown": 5.0},
			"X": {"nome": "Gomu Gomu no Bazooka", "cor": Color(0.9, 0.35, 0.15), "dano": 40, "cooldown": 7.0},
			"C": {"nome": "Gomu Gomu no Gatling", "cor": Color(0.95, 0.5, 0.1), "dano": 55, "cooldown": 10.0},
			"V": {"nome": "Gear 2 / Red Hawk", "cor": Color(1.0, 0.15, 0.15), "dano": 80, "cooldown": 60.0}
		},
		"gura_gura": {
			"Z": {"nome": "Gura Punch (Soco do Tremor)", "cor": Color(0.85, 0.94, 1.0), "dano": 20, "cooldown": 5.0},
			"X": {"nome": "Shockwave (Onda de Choque)", "cor": Color(0.8, 0.9, 1.0), "dano": 25, "cooldown": 7.0},
			"C": {"nome": "Kabutsuchi (Erupção)", "cor": Color(0.7, 0.85, 1.0), "dano": 30, "cooldown": 10.0},
			"V": {"nome": "Tsunamis Duplos", "cor": Color(0.9, 0.96, 1.0), "dano": 85, "cooldown": 60.0}
		},
		"mera_mera": {
			"Z": {"nome": "Tiros de Pistola de Fogo", "cor": Color(1.0, 0.45, 0.1), "dano": 20, "cooldown": 5.0},
			"X": {"nome": "Hiken (Punho de Fogo)", "cor": Color(1.0, 0.25, 0.0), "dano": 45, "cooldown": 7.0},
			"C": {"nome": "Dai Enkai: Entei (Sol)", "cor": Color(1.0, 0.65, 0.1), "dano": 65, "cooldown": 10.0},
			"V": {"nome": "Inferno", "cor": Color(1.0, 0.1, 0.0), "dano": 90, "cooldown": 60.0}
		},
		"bara_bara": {
			"Z": {"nome": "Bara Bara Ho", "cor": Color(0.9, 0.3, 0.7), "dano": 22, "cooldown": 5.0},
			"X": {"nome": "Bara Bara Senbei", "cor": Color(0.8, 0.2, 0.6), "dano": 38, "cooldown": 7.0},
			"C": {"nome": "Bara Bara Car", "cor": Color(1.0, 0.4, 0.8), "dano": 35, "cooldown": 10.0},
			"V": {"nome": "Bara Bara Festival", "cor": Color(0.95, 0.15, 0.75), "dano": 75, "cooldown": 60.0}
		},
		"goro_goro": {
			"Z": {"nome": "Sango (Feixe Elétrico)", "cor": Color(0.95, 0.95, 0.3), "dano": 30, "cooldown": 5.0},
			"X": {"nome": "El Thor (Coluna de Raio)", "cor": Color(1.0, 0.85, 0.1), "dano": 50, "cooldown": 7.0},
			"C": {"nome": "Shunshin (Teleporte Raio)", "cor": Color(0.9, 0.9, 0.5), "dano": 20, "cooldown": 10.0},
			"V": {"nome": "Mamaragan (Tempestade)", "cor": Color(1.0, 1.0, 0.2), "dano": 90, "cooldown": 60.0}
		},
		"yami_yami": {
			"Z": {"nome": "Disparo de Pistola", "cor": Color(0.25, 0.1, 0.35), "dano": 25, "cooldown": 5.0},
			"X": {"nome": "Espiral Negra (Kurouzu)", "cor": Color(0.15, 0.05, 0.25), "dano": 35, "cooldown": 7.0},
			"C": {"nome": "Black Hole (Vórtice Abissal)", "cor": Color(0.1, 0.02, 0.15), "dano": 50, "cooldown": 10.0},
			"V": {"nome": "Liberation (Libertação)", "cor": Color(0.3, 0.2, 0.4), "dano": 60, "cooldown": 60.0}
		},
		"suna_suna": {
			"Z": {"nome": "Desert Spada (Lâmina de Areia)", "cor": Color(0.95, 0.8, 0.45), "dano": 35, "cooldown": 5.0},
			"X": {"nome": "Sables (Tornado de Areia)", "cor": Color(0.9, 0.72, 0.35), "dano": 50, "cooldown": 7.0},
			"C": {"nome": "Desert Girasole (Movediça)", "cor": Color(0.85, 0.65, 0.25), "dano": 65, "cooldown": 10.0},
			"V": {"nome": "Suna no Sabaku (Deserto Vivo)", "cor": Color(0.98, 0.82, 0.4), "dano": 85, "cooldown": 60.0}
		},
		# BUKI BUKI — arsenal de FPS (regra nova do dono, 2026-08-11): a tecla
		# EMPUNHA a arma, o botão esquerdo atira, e a munição é a penalidade.
		# ⚠️ `dano` aqui é POR BALA, não por golpe — por isso o minigun vale 9 e o
		# canhão 90. O nº de balas e a cadência ficam em BukiFX.ARSENAL, e a
		# recarga do slot só corre depois que a arma é largada.
		"buki_buki": {
			"Z": {"nome": "Pistola (12 balas)", "cor": Color(0.78, 0.82, 0.88), "dano": 24, "cooldown": 5.0},
			"X": {"nome": "Canhão — corpo inteiro (3 tiros)", "cor": Color(0.88, 0.92, 1.0), "dano": 90, "cooldown": 7.0},
			"C": {"nome": "Sniper (5 tiros, luneta no Bt Dir)", "cor": Color(0.70, 0.74, 0.80), "dano": 72, "cooldown": 10.0},
			"V": {"nome": "Minigun (100 balas)", "cor": Color(0.95, 0.97, 1.0), "dano": 9, "cooldown": 60.0}
		},
		"hie_hie": {
			"Z": {"nome": "Disparo de Gelo", "cor": Color(0.5, 0.8, 1.0), "dano": 28, "cooldown": 5.0},
			"X": {"nome": "Iceberg", "cor": Color(0.45, 0.75, 1.0), "dano": 45, "cooldown": 7.0},
			"C": {"nome": "Investida de Gelo", "cor": Color(0.6, 0.85, 1.0), "dano": 40, "cooldown": 10.0},
			"V": {"nome": "Ice Age (Era do Gelo)", "cor": Color(0.7, 0.9, 1.0), "dano": 85, "cooldown": 60.0}
		}
	}
	# Garante que qualquer habilidade registrada ou adicionada no futuro obedeça ao novo cooldown padronizado
	for f_id in skills:
		for slot in skills[f_id]:
			match slot:
				"Z": skills[f_id][slot]["cooldown"] = 5.0
				"X": skills[f_id][slot]["cooldown"] = 7.0
				"C": skills[f_id][slot]["cooldown"] = 10.0
				"V": skills[f_id][slot]["cooldown"] = 60.0
	return skills

static func get_slot_cooldown(slot: String) -> float:
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
		if t != yami_user and t is Node3D:
			var dist := yami_user.global_position.distance_to(t.global_position)
			if dist <= radius:
				if t.has_method("suppress_skills_temporarily"):
					t.suppress_skills_temporarily(3.0) # 3 segundos de desativação
