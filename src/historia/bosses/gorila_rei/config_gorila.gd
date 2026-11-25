extends Resource
## Números do Gorila-rei (22/11/2026). O dano é na escala do MOD (a armadura e a resistência do jogador o reduzem): MEDIDO em jogo com nível 14 (44 de vida):
## pedido 15 → 12 % da vida, 25 → 24 %, 35 → 39 %, 50 → 60 %. Daí: soco 28 (~27 %), pulo 36 (~40 %), investida 32 (~33 %), giro 26, pedra 26, onda da fúria 14.
## (A vida do jogador de nível 14 é ~44. Tudo editável aqui; a vida está na ficha
## do catálogo (`gorila_rei`, 1100). Todo golpe tem AVISO vermelho; as janelas de recuperação são as chances de contra-ataque.
@export var vida_da_fase_2 := 0.55           # fração da vida em que entra em FÚRIA
@export var intervalo := 1.3                 # s entre um golpe e o próximo (fase 1)
@export var intervalo_fase_2 := 0.75
@export var aviso_mais_curto_fase_2 := 0.8   # fator sobre o aviso na fúria
@export var dano_mais_forte_fase_2 := 1.15

# Soco duplo no chão: disco à frente. Perto.
@export var soco_aviso := 1.0
@export var soco_raio := 4.4
@export var soco_alcance_do_centro := 4.2    # m à frente do chefe
@export var soco_dano := 28.0
@export var soco_recuperacao := 0.9
@export var soco_recarga := 3.5
# Pulo esmagador: disco no ALVO. Médio.
@export var pulo_aviso := 0.75
@export var pulo_voo := 0.9
@export var pulo_raio := 6.5
@export var pulo_dano := 36.0
@export var pulo_recuperacao := 1.3
@export var pulo_recarga := 9.0
@export var pulo_alcance_minimo := 6.0
@export var pulo_alcance_maximo := 22.0
# Investida de ombro: faixa. Médio.
@export var investida_aviso := 0.9
@export var investida_comprimento := 16.0
@export var investida_largura := 3.6
@export var investida_velocidade := 24.0
@export var investida_dano := 32.0
@export var investida_recuperacao := 1.4
@export var investida_recarga := 10.0
# Giro: círculo em volta dele. Perto.
@export var giro_aviso := 0.8
@export var giro_raio := 6.2
@export var giro_dano := 26.0
@export var giro_recuperacao := 1.0
@export var giro_recarga := 8.0
# Arremesso de pedra: disco no alvo. Longe.
@export var arremesso_aviso := 1.1
@export var arremesso_voo := 0.75
@export var arremesso_raio := 3.3
@export var arremesso_dano := 26.0
@export var arremesso_recuperacao := 0.8
@export var arremesso_recarga := 6.5
@export var arremesso_alcance_minimo := 10.0
@export var arremesso_alcance_maximo := 34.0
# Fúria (entrada na fase 2): anel grande + onda.
@export var furia_aviso := 1.6
@export var furia_total := 2.4
@export var furia_raio := 9.5
@export var furia_dano := 14.0
@export var furia_recarga_do_rugido := 22.0  # na fase 2, rugido de novo a cada tanto (onda de choque)
@export var recuperacao_da_onda := 0.9
