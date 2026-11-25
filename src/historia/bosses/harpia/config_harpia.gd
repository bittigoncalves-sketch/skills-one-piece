extends Resource
## Parâmetros do encontro; dano final na escala de vida da campanha.
@export_range(0.1, 3.0) var preparo_investida := 0.8
@export_range(0.1, 2.0) var duracao_investida := 0.6
@export_range(1.0, 60.0) var velocidade_investida := 40.0
@export_range(0.1, 4.0) var raio_impacto := 1.2
@export var dano_investida := 8.0
@export var arremesso_horizontal := 32.0
@export var arremesso_vertical := 12.0
@export var recuperacao := 1.0
@export var recarga_investida := 8.0
@export var preparo_vendaval := 1.1
@export var recarga_vendaval := 15.0
@export var intervalo := 2.0
# Voo entre as pedras e órbita dos picos (10/10/2026, pedido do dono: "após a investida
# ela já ganha velocidade novamente voando ao redor dos picos"). Escolhas minhas.
@export var raio_de_combate := 60.0        # m: até onde enfrenta quem está no território
@export var velocidade_patrulha := 9.0     # m/s rondando os picos sem ninguém
@export var velocidade_orbita := 16.0      # m/s rondando os picos em combate
@export var velocidade_ataque := 21.0      # m/s chegando para a investida
@export var velocidade_saida := 26.0       # m/s no arranque depois da investida
@export var saida := 0.8                   # s de arremetida (asas abrindo) depois da investida
@export var raio_orbita := 16.0            # m em volta do pico
@export var altura_orbita := 8.0           # m acima do topo do pico
@export var decolar := 0.45                # s subindo ao levar um golpe, antes da investida
@export var recarga_reacao := 4.0          # s entre duas reações a golpe
@export var velocidade_tornado := 14.0     # m/s (era 8; pedido do dono: tornado mais rápido)
