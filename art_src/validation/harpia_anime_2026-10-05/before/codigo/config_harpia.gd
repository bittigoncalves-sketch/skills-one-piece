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
