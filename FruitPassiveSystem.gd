class_name FruitPassiveSystem
extends Node

# ============================================================================
#  Sistema de Habilidades Passivas das Akuma no Mi (Godot 4)
#  REGRA IMPORTANTE: As frutas Logia NÃO possuem imunidade a dano elemental;
#  em vez disso, utilizam mecânicas dinâmicas de ação e combate (dashes de luz,
#  rastro de gelo, sobrecarga de voltagem, marcas de combustão, etc.).
# ============================================================================

signal passive_triggered(fruit_id: String, passive_name: String, description: String)

var active_fruit_id: String = ""
var active_passive_data: Dictionary = {}

var charge_count: int = 0
var volt_meter: float = 0.0

static func get_all_passives() -> Dictionary:
	return {
		"gomu_gomu": {
			"nome": "Corpo Elástico (Kinetic Bounce)",
			"descricao": "Pulos ganham +20% de impulso mecânico. Reduz repulsão (knockback) recebida em 40%.",
			"tipo": "Paramecia",
			"speed_mod": 1.10,
			"jump_mod": 1.20
		},
		"gura_gura": {
			"nome": "Homem-Tremor (Quake Force)",
			"descricao": "Paramecia: skills geram ondas de choque com KNOCKBACK devastador (jogam o alvo pra fora do mapa). Sem bônus de mobilidade.",
			"tipo": "Paramecia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"mera_mera": {
			"nome": "Combustão Progressiva (Overheat Charges)",
			"descricao": "Logia Ativa: Cada skill gera 1 carga de Chama. Com 5 cargas, o próximo ataque estoura em explosão de Fogo em área e +25% velocidade.",
			"tipo": "Logia",
			"speed_mod": 1.15,
			"jump_mod": 1.0
		},
		"hie_hie": {
			"nome": "Trilha Congelante (Frost Trail)",
			"descricao": "Logia Ativa: Deixa um rastro de gelo ao correr que desacelera inimigos em 35% e dá +15% de velocidade de movimento ao usuário.",
			"tipo": "Logia",
			"speed_mod": 1.15,
			"jump_mod": 1.0
		},
		"pika_pika": {
			"nome": "Fóton Reativo (Light Dash)",
			"descricao": "Logia Ativa: Após utilizar uma habilidade, o próximo dash se torna um feixe de luz instantâneo com +35% dano bônus.",
			"tipo": "Logia",
			"speed_mod": 1.25,
			"jump_mod": 1.15
		},
		"magu_magu": {
			"nome": "Núcleo Vulcânico (Volcanic Core)",
			"descricao": "Logia Ativa: Quanto menor a vida atual, maior o dano das habilidades (até +50%). Golpes normais aplicam queimadura contínua.",
			"tipo": "Logia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"goro_goro": {
			"nome": "Sobrecarga Voltáica (Volt Meter)",
			"descricao": "Logia Ativa: Movimentar-se acumula voltagem (0 a 100). Em 100, dispara um raio automático no inimigo mais próximo, atordoando por 0.5s.",
			"tipo": "Logia",
			"speed_mod": 1.15,
			"jump_mod": 1.10
		},
		"suna_suna": {
			"nome": "Drenagem Desértica (Desiccation)",
			"descricao": "Logia Ativa: Acertos absorvem a umidade do alvo, roubando estamina e curando 12% do dano infligido.",
			"tipo": "Logia",
			"speed_mod": 1.05,
			"jump_mod": 1.0
		},
		"yami_yami": {
			"nome": "Supressão Abissal (Fruit Nullification Aura)",
			"descricao": "Desativação temporária dos poderes e habilidades ativas de usuários de fruta em um raio de 8m.",
			"tipo": "Logia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"gura_gura_alt": {
			"nome": "Ruptura Tectônica (Seismic Wave)",
			"descricao": "Ataques carregados geram ondas de choque sísmicas no chão que quebram a guarda de inimigos próximos.",
			"tipo": "Paramecia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"ope_ope": {
			"nome": "Precisão Cirúrgica (Spatial Mastery)",
			"descricao": "Dentro da 'Room', a chance de acerto crítico aumenta em +30% e habilidades consomem 50% menos estamina.",
			"tipo": "Paramecia",
			"speed_mod": 1.10,
			"jump_mod": 1.10
		},
		"bara_bara": {
			"nome": "Esquiva Desmembrada (Split Reflex)",
			"descricao": "Ao receber dano físico cortante ou frontal, possui 35% de chance de desmembrar o corpo automaticamente e esquivar sem tomar dano.",
			"tipo": "Paramecia",
			"speed_mod": 1.05,
			"jump_mod": 1.0
		},
		"hana_hana": {
			"nome": "Florada Múltipla (Multi-Limb Grasp)",
			"descricao": "Golpes têm 20% de chance de fazer brotar mãos adicionais no alvo que o imobilizam por 1.0s.",
			"tipo": "Paramecia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"ito_ito": {
			"nome": "Fios Marionete (Puppet Threads)",
			"descricao": "Aplica marcas de Fio. Ao acumular 3 marcas, o inimigo fica paralisado e confuso por 1.5s.",
			"tipo": "Paramecia",
			"speed_mod": 1.10,
			"jump_mod": 1.05
		},
		"zushi_zushi": {
			"nome": "Pressão Gravitacional (Heavy Gravity)",
			"descricao": "Aumenta o peso dos alvos atingidos, reduzindo a altura do pulo deles e aplicando lentidão acumulativa.",
			"tipo": "Paramecia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		},
		"moku_moku": {
			"nome": "Cortina de Fumaça (Smokescreen Dash)",
			"descricao": "Logia Ativa: Esquivar deixa um rastro densíssimo de fumaça que cega inimigos e reduz a precisão deles em 50%.",
			"tipo": "Logia",
			"speed_mod": 1.12,
			"jump_mod": 1.0
		},
		"tori_tori_phoenix": {
			"nome": "Chamas da Renascença (Phoenix Healing)",
			"descricao": "Regenera 2.5% da vida máxima por segundo continuamente e concede pulo duplo no ar.",
			"tipo": "Zoan Mítica",
			"speed_mod": 1.10,
			"jump_mod": 1.30
		},
		"neko_neko_leopard": {
			"nome": "Instinto Predador (Predator Sprint)",
			"descricao": "Ganha +30% de velocidade de movimento ao correr na direção de inimigos feridos.",
			"tipo": "Zoan",
			"speed_mod": 1.20,
			"jump_mod": 1.15
		},
		"hito_hito_nika": {
			"nome": "Libertação Cartunesca (Joy Boy Rhythm)",
			"descricao": "Pular gera um pulso de gargalhada radiante que restaura estamina e acelera aliados próximos em +20%.",
			"tipo": "Zoan Mítica",
			"speed_mod": 1.25,
			"jump_mod": 1.35
		},
		"uo_uo_seiryu": {
			"nome": "Escamas de Dragão & Nuvens (Wind Floating)",
			"descricao": "Concede +30% de resistência a dano geral e a habilidade de planar temporariamente no ar.",
			"tipo": "Zoan Mítica",
			"speed_mod": 1.05,
			"jump_mod": 1.25
		},
		"buki_buki": {
			"nome": "Corpo-Arsenal (Weapon Body)",
			"descricao": "Paramecia: o próprio corpo vira arma. Os membros se transformam no instante do golpe e voltam ao normal logo depois.",
			"tipo": "Paramecia",
			"speed_mod": 1.0,
			"jump_mod": 1.0
		}
	}

func equip_fruit(fruit_id: String) -> void:
	active_fruit_id = fruit_id
	var all_passives := get_all_passives()
	if all_passives.has(fruit_id):
		active_passive_data = all_passives[fruit_id]
		emit_signal("passive_triggered", fruit_id, active_passive_data["nome"], active_passive_data["descricao"])
		print("⚡ Passiva Ativada: ", active_passive_data["nome"], " - ", active_passive_data["descricao"])
