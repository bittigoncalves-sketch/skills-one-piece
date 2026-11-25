extends SceneTree
## Mede o fio físico (-X no GLB) contra a viagem transversal de sua lâmina (+Y).
## Campo de prova sem inimigos/hitstop, mesmo Player/executor que o modo história.
var falhas := 0
var jogador: Node
var ex: Node

func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_fio_espada_historia.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_fio_espada_historia.json"))
	root.get_node("GameFlow").start_story()
	for i in 900:                          # espera o jogador nascer: 120 quadros fixos não bastam mais (a carga cresceu) e, sem jogador, o script abortava SEM `quit` e o teste travava
		await physics_frame
		if i >= 60 and get_first_node_in_group("player") != null:
			break
	for i in 30:
		await physics_frame
	jogador = get_first_node_in_group("player")
	current_scene.progressao.equipamentos["espada"] = 1      # a espada inicial saiu do kit (só as lâminas do Epic Fight): concede a clássica para medir o fio
	current_scene.progressao.equipar_espada(true)
	ex = jogador.combate_direcional
	await quadros(30)
	for yaw in [0.0, PI * 0.5]:
		jogador._yaw = yaw
		jogador.modelo_visual().rotation.y = yaw
		for direcao in [1, 2, 3]:
			await quadros(60)
			ex.pedir_ataque(direcao)
			var visual: Node3D = jogador.get_node("EspadaDaHistoria").get("_visual")
			if visual == null:             # falha RÁPIDA e dita: antes o script abortava sem `quit` e o teste ficava pendurado até o timeout
				print("FALHA: EspadaDaHistoria._visual é nulo (a espada não montou o visual; o sistema da espada mudou?)")
				quit(1)
				return
			var anterior := Vector3.INF
			var fio_anterior := Vector3.ZERO
			var eixo_anterior := Vector3.ZERO
			var minimo := 1.0
			var soma := 0.0
			var amostras := 0
			var inicio_ativo := Vector3.INF
			var fim_ativo := Vector3.ZERO
			while ex.atacando():
				await quadros(1)
				var centro := visual.to_global(Vector3(0, 0.7, 0))
				var eixo := visual.global_basis.y.normalized()
				var fio := -visual.global_basis.x.normalized()
				if ex.estado == ex.Estado.ATIVO and anterior != Vector3.INF:
					if inicio_ativo == Vector3.INF:
						inicio_ativo = centro
					fim_ativo = centro
					var viagem := centro - anterior
					var eixo_medio := (eixo + eixo_anterior).normalized()
					var transversal := viagem - eixo_medio * viagem.dot(eixo_medio)
					if transversal.length() > 0.001:
						var alinhamento := (fio + fio_anterior).normalized().dot(transversal.normalized())
						minimo = minf(minimo, alinhamento)
						soma += alinhamento
						amostras += 1
				anterior = centro
				fio_anterior = fio
				eixo_anterior = eixo
			var viagem_local: Vector3 = ex.ator.base_do_corpo().inverse() * (fim_ativo - inicio_ativo)
			var sentido_certo: bool = viagem_local.x < -0.5 if direcao == 1 else viagem_local.x > 0.5 if direcao == 2 else viagem_local.y < -0.5
			var passou := amostras >= 5 and minimo >= 0.85 and sentido_certo
			print("viagem no espaço do corpo: ", viagem_local)
			print("%s fio direção %d yaw %.0f: mínimo %.3f, média %.3f, amostras %d" % ["OK" if passou else "FALHA", direcao, rad_to_deg(yaw), minimo, soma / maxf(amostras, 1), amostras])
			if not passou:
				falhas += 1
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_fio_espada_historia.json"))
	print("FIO DA ESPADA: %d/6 passaram" % (6 - falhas))
	quit(1 if falhas else 0)
