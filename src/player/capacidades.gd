class_name CapacidadesDoJogador
extends RefCounted
# ============================================================================
#  CAPACIDADES DO JOGADOR — o que o corpo tem PERMISSÃO de fazer.
#
#  Existe por causa do Modo História (docs/MODO_HISTORIA.md): lá o personagem
#  começa como um civil que só anda, pula e olha em volta, e conquista combate,
#  esquiva e pulo duplo ao longo da campanha. A arena continua com tudo liberado.
#
#  POR QUE UM OBJETO E NÃO QUATRO `if` SOLTOS NO Player
#  ----------------------------------------------------
#  O desbloqueio vai ser disparado pela história (missão, treinador, level up),
#  não pelo Player. Com as quatro permissões num lugar só, quem desbloqueia mexe
#  num dado e o Player só consulta — ninguém de fora precisa conhecer as entradas
#  do Player (clique, Q, Espaço no ar, Z/X/C/V, toque no celular).
#
#  ⚠️ A trava mora na ENTRADA do pedido (`_request_melee`, `begin_charge`,
#  `dash_bloqueado`, o geppo do parkour), não na tecla. Assim o botão de toque
#  do celular, que chama os mesmos métodos, também respeita.
#
#  Os nomes são os da seção 31 do PDF de progressão, para a busca achar os dois.
# ============================================================================

## Corpo a corpo (botão esquerdo, chute giratório, queda esmagadora, quebra-combo).
var can_attack := true
## Dash no ar (Q fora do chão). O roll do chão NÃO depende disto (decisão do dono, 03/10/2026).
var can_dash := true
## Geppo — o pulo extra no ar. O pulo simples do chão nunca é travado.
var can_double_jump := true
## Energia gasta em cada pulo no ar e em cada dash no ar (Modo História, 15/10/2026). Na
## arena ficam em 0: lá os dois são de graça, como sempre foram.
var custo_pulo_no_ar := 0.0
var custo_dash_no_ar := 0.0
## Recarga do dash no ar. A arena mantém a de 1,5 s que ele tinha quando dividia o
## controlador com o roll; a história usa a dela (0,1 s).
var recarga_dash_no_ar := 1.5
## TÉCNICA GEPPO (18/11/2026, Ilha dos Macacos): vários pulos no ar e dash no ar SEM recarga (e de graça). `saltos_no_ar` < 0 = vale o `max_geppo` do corpo;
## com o Geppo aprendido a história põe `ProgressaoDoPersonagem.SALTOS_DO_GEPPO` aqui. Os custos e a recarga do Geppo vêm zerados (campos acima).
var geppo := false
var saltos_no_ar := -1
## Técnicas: Z/X/C/V, Corpo de Ferro (F), Observação (E) e a troca de modo/fruta.
var can_use_skills := true
## Técnicas Z/X/C/V da FRUTA comida. Separado de `can_use_skills` porque aquele também
## libera os modos 1/2/3, o T de trocar fruta, o E de observação e o Corpo de Ferro —
## coisas da arena que o Modo História não tem (plano da Rocket, 21/09/2026).
var can_use_fruit := true
## Voo curto da fruta (tecla F). Separado pelo mesmo motivo: no Modo História o F é o
## voo da Rocket, e não o Corpo de Ferro.
var can_fly := true
## Pescar (vara ativa na barra de itens, Modo História — 03/10/2026). A arena não pesca.
var can_fish := false


## A arena: tudo liberado. É o padrão do Player, então nada muda por lá.
static func completas() -> CapacidadesDoJogador:
	return CapacidadesDoJogador.new()


## Nível 1 do Modo História — "Civil" (PDF, seções 21 a 26): anda, pula, câmera,
## interage. Sem combate, sem dash, sem pulo duplo, sem técnicas.
static func civil() -> CapacidadesDoJogador:
	var c := CapacidadesDoJogador.new()
	c.can_attack = false
	c.can_dash = false
	c.can_double_jump = false
	c.can_use_skills = false
	c.can_use_fruit = false
	c.can_fly = false
	return c
