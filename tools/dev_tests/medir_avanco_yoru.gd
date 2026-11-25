extends SceneTree
## Mede o AVANÇO do clique da Yoru: quanto o corpo anda quando o golpe erra, e
## se ele para de andar quando o golpe conecta.
## godot --headless --path . -s tools/dev_tests/medir_avanco_yoru.gd
##
## O par de casos é o ponto: um número sozinho não distingue "avançou certo" de
## "avançou sempre". A diferença entre errar e acertar É a mecânica pedida.
class Fighter extends CharacterBody3D:
	var health := 2048.0
	var combat_mode := "sword"
	var _char_model: Node3D
	var _yoru: YoruSword
	var _yoru_combat: YoruController
	func lamina_da_espada() -> SwordBlade: return _yoru.lamina

class Target extends StaticBody3D:
	var hits := 0
	func take_damage(_v: float, _o: Vector3, _kb: Vector3, _s: float) -> void:
		hits += 1

const HZ := 1.0 / 60.0
var world: Node3D
var player: Fighter
var target: Target
var checks := 0
var failures := 0
var seq := 0


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS " if condition else "FAIL ") + label)


func box(body: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)


func _init() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = Fighter.new()
	world.add_child(player)
	player.position.y = 0.8
	box(player, Vector3(0.4, 1.6, 0.4))
	player._char_model = CharacterBuilder.build_character("base").node
	player.add_child(player._char_model)
	var bounds := PlayerModelKit.model_aabb(player._char_model)
	var factor := 1.5 / bounds.size.y
	player._char_model.scale = Vector3.ONE * factor
	player._char_model.position.y = -0.8 - factor * bounds.position.y
	var handle: Node3D = player._char_model.find_child("Weapon_R", true, false)
	handle.rotation.x = PI
	player._yoru = YoruSword.ligar_na_mao(handle)
	player._yoru.lamina.dono = player
	player._yoru_combat = YoruController.new()
	player.add_child(player._yoru_combat)
	player._yoru_combat.setup(player)
	player._yoru_combat.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	box(floor_body, Vector3(60, 0.2, 60))
	target = Target.new()
	world.add_child(target)
	box(target, Vector3(0.5, 1.6, 0.5))
	# ⚠️ O alvo fica numa camada que a LÂMINA vê (a varredura cobre as camadas
	# 1-4) mas que NÃO bloqueia o corpo do jogador, cuja máscara é a 1. Sem isso
	# o teste não mede nada: o alvo sólido barra o `move_and_collide` e o número
	# curto sairia igual com ou sem a mecânica. No jogo o inimigo bloqueia mesmo
	# — as duas coisas se somam lá; aqui separa-se a que está sendo medida.
	target.collision_layer = 2
	await physics_frame
	await physics_frame

	print("=== avanço do clique da Yoru ===")
	for id in ["M1_1", "M1_2", "X"]:
		var esperado := float(YoruMoves.get_move(id).get("advance",
			YoruMoves.get_move(id).get("step", 0.0)))
		var errando := await percorrido(id, 40.0)
		var margem: float = maxf(0.06, esperado * 0.06)
		ok(absf(errando - esperado) <= margem,
			"%s errando anda %.2f m (pedido %.2f m)" % [id, errando, esperado])
		# O X precisa de um alvo mais longe: a passada de 2,8 m acontece ANTES da
		# janela de dano, então com o alvo a 1,3 m o jogador já passou dele quando
		# a lâmina arma. É a mesma distância que `test_yoru_combat` usa.
		var acertando := await percorrido(id, 4.1 if id == "X" else 1.3)
		ok(target.hits == 1, "%s acertou uma vez no caso curto" % id)
		if id == "X":
			# A passada da técnica é a técnica: ela roda inteira ANTES do corte,
			# e por isso acertar não pode encurtá-la.
			ok(absf(acertando - esperado) <= margem,
				"X acertando mantém a passada: %.2f m" % acertando)
		else:
			ok(acertando < errando - 0.15,
				"%s acertando para antes: %.2f m contra %.2f m" % [id, acertando, errando])

	print("AVANCO YORU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Roda a ação inteira e devolve quantos metros o corpo andou. `distancia` põe o
## alvo à frente: grande o bastante e o golpe erra.
func percorrido(id: String, distancia: float) -> float:
	player.position = Vector3(0, 0.82, 0)
	player.velocity = Vector3.ZERO
	target.position = Vector3(0, 0.8, -distancia)
	target.hits = 0
	seq += 1
	await physics_frame
	var partida := player.global_position
	player._yoru_combat.start_action(id, seq, Vector3.FORWARD)
	var passos := int(ceil(YoruMoves.duration(id) / HZ)) + 4
	for i in passos:
		player._yoru_combat._physics_process(HZ)
		await physics_frame
	return partida.distance_to(player.global_position)
