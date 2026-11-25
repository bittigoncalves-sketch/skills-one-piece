extends RefCounted
## Clipes do bloco Animação do Skills Builder (07/10/2026). UMA lista para o editor, a
## prévia e o jogo.
##
## Pedido do dono: "adicionar mais animações ao skill builder e corrigir as animações
## atuais, adicionar as animações do rolamento e de combate também". Antes, a prévia
## tocava um clipe do AnimationPlayer do modelo (Ataque = `punching`) e o jogo ligava uma
## pose procedural antiga (Ataque = `bomu_z_strike`): o que se via no editor não era o
## que saía no jogo. Agora os dois aplicam o MESMO clipe bakeado
## (`assets/animations/<id>.res`, trilhas por papel do rig) no tempo do bloco: no jogo
## pelo "clipe de ação" do `ProceduralAnimator` (o caminho do roll do Q, replicado em
## rede); na prévia pelos mesmos papéis (`BodyScanner`).
##
## "Todas viram o personagem meio de lado" e "muito parecidas" (relatos do dono, 07/10):
## a causa era o BAKE, não o editor — a conversão no espaço do esqueleto do .glb deitava o
## corpo em todo golpe que gira o quadril e espelhava os antebraços. Os clipes foram
## reassados na conversão v3 (`tools/bake_mixamo.gd`); a correção do tronco que existia
## aqui (`endireitar`) tratava só o sintoma e saiu.

const PASTA := "res://assets/animations/"
## Os cinco nomes de antes viram atalhos (skills antigas continuam valendo).
const ATALHOS := {"Preparar": "bouncing_fight_idle", "Ataque": "punching", "Planar": "falling_idle",
	"Investida": "sprint", "Vendaval": "roundhouse_kick"}
## Repetidos que saíram da lista (07/10/2026, medido: mesmo conteúdo do gêmeo). Skills
## antigas que usam o nome continuam valendo: a validação aceita e o clipe é o do gêmeo.
const RENOMEADOS := {"boxing_1": "boxing", "roundhouse_kick_2": "roundhouse_kick", "run_to_stop_2": "run_to_stop"}
const COMBATE := ["punching", "boxing", "boxing_2", "quad_punch",
	"jab_to_elbow_punch", "uppercut_jab", "left_uppercut_from_guard", "right_upper_hook_from_guard",
	"stabbing", "smash", "kicking", "roundhouse_kick", "flying_kick", "pontera",
	"chapa_2", "chapa_giratoria_2", "meia_lua_de_compasso", "armada", "jumping_over_into_combat"]
## O roll do Q é o `sprinting_forward_roll`; o deslize do Ctrl, o `running_slide`.
const ROLAMENTO := ["sprinting_forward_roll", "running_dive_roll", "falling_to_roll", "au_to_role",
	"pivot", "running_slide"]
const MOVIMENTO := ["walking", "running", "sprint", "run_to_stop", "left_turn",
	"right_turn", "jumping_up", "hard_landing", "climbing_up_wall", "wall_run",
	"wall_run_espelhado", "diagonal_wall_run", "diagonal_wall_run_espelhado", "crouched_to_sprinting",
	"crouched_sneaking_left", "crouched_sneaking_right", "stand_to_cover", "stand_to_cover_2",
	"cover_to_stand", "cover_to_stand_2", "left_cover_sneak", "right_cover_sneak"]
## Os que quase não se mexem (medido: < 15° no clipe inteiro) ficam aqui, fora de Combate.
const POSTURA := ["idle", "idle_2", "idle_3", "idle_4", "idle_5", "bouncing_fight_idle", "boxing_3",
	"gunplay", "falling_idle", "bencao", "dying"]


## Os valores aceitos pelo campo Clipe (atalhos antigos primeiro, depois por categoria).
static func opcoes() -> Array:
	var saida: Array = ATALHOS.keys()
	saida.append_array(COMBATE)
	saida.append_array(ROLAMENTO)
	saida.append_array(MOVIMENTO)
	saida.append_array(POSTURA)
	return saida


## O que a lista do campo Clipe MOSTRA (08/10/2026, pedido do dono: "adicionar na frente do
## nome o tempo de cada animação"): "1,27 s · punching". O valor gravado continua o nome.
static var _rotulos := {}

static func rotulos() -> Dictionary:
	if _rotulos.is_empty():
		for c in opcoes():
			var anim := load(caminho(c)) as Animation
			var segundos := ("%.2f" % (anim.length if anim else 0.0)).replace(".", ",")
			_rotulos[c] = "%s s · %s" % [segundos, c]
	return _rotulos


## O arquivo do clipe ("" se o nome não é um clipe conhecido).
static func caminho(clipe: String) -> String:
	var id := str(ATALHOS.get(clipe, clipe))
	id = str(RENOMEADOS.get(id, id))
	if not (id in COMBATE or id in ROLAMENTO or id in MOVIMENTO or id in POSTURA):
		return ""
	return PASTA + id + ".res"
