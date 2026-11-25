extends RefCounted
## Montagem em um ponto: não há dependência do sistema de sobrevivência na arena.
const P := preload("res://src/historia/tripulantes/provisoes.gd")
static func ligar(modo: Node) -> void:
	var prog: ProgressaoDoPersonagem = modo.progressao
	var sistema := preload("res://src/historia/tripulantes/sobrevivencia.gd").new()
	sistema.name = "Sobrevivencia"
	sistema.progressao = prog
	sistema.caminho_progresso = modo.caminho_do_progresso()
	sistema.jogador_de = modo.jogador_local
	sistema.companhia = modo.get("_companhia")
	sistema.navegacao = modo.get("_navegacao")
	sistema.biblioteca = MapaMontador.biblioteca_em_uso()
	modo.add_child(sistema)
	var hud: Node = modo.get("_hud")
	sistema.aviso.connect(hud.avisar)
	hud.menu_de_comportamento().ligar(prog, sistema)
	var ciclo := modo.get_node("CicloDiaNoite")
	ciclo.tempo_passou.connect(sistema.avancar)
	ciclo.set("hud_de_pausa", hud)
	var status := preload("res://src/ui/SobrevivenciaHud.gd").new()
	status.progressao = prog
	hud.add_child(status)
	# Saves anteriores: entradas das missões antigas (cadeia da vara, retirada em 20/11/2026) ficam no arquivo mas são ignoradas (`Missoes.dados` devolve {}).
	# `RegrasDoTreino.migrar_save_acima_do_limite(prog)` está DESLIGADA de propósito: grava em save real e a decisão do dono (o que fazer com quem já passou do nível 3 sem a missão) está pendente.
	# Ligar aqui, uma linha, quando ele decidir (a função e o teste isolado continuam em `regras_do_treino.gd`).
	prog.mudou.emit()

static func colocar_npcs(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, controlador: NpcsDaIlha) -> void:
	var colocados := {}
	for npc in controlador.npcs: colocados[npc.tipo] = true
	for p: Dictionary in mapa.get("pecas", []):
		var modelo := str(p.get("modelo", ""))
		var tipo := "npc_comida" if modelo == "market_stalls_compact" else ("npc_treinador" if modelo == "centro_treino_voxel" else ("npc_ferreiro" if modelo == "blacksmith" else ""))
		if tipo.is_empty() or colocados.has(tipo): continue
		var npc := NpcDaIlha.new()
		npc.name = "Jornada_" + tipo
		npc.tipo = tipo
		npc.biblioteca = bib
		var centro: Vector3 = p.posicao
		var tamanho: Vector3 = p.tamanho
		var giro := deg_to_rad((p.rotacao_graus as Vector3).y)
		var offset := Vector3(0, 0, tamanho.z * 0.5 + 1.8).rotated(Vector3.UP, giro)
		npc.position = Vector3(centro.x + offset.x, centro.y - tamanho.y * 0.5, centro.z + offset.z)
		npc.rotation.y = giro + (PI if tipo == "npc_treinador" else 0.0)      # o instrutor encara quem chega (para FORA do pavilhão), não o fundo
		raiz.add_child(npc)
		controlador.npcs.append(npc)
		colocados[tipo] = true
	var d := P.estado(controlador.progressao)
	var vitimas: Dictionary = d.get("vitimas", {})
	for npc in controlador.npcs:
		var politica := str(vitimas.get(str(npc.name), ""))
		if politica == "matar":
			npc.set_meta("morto", true)
			npc.hide()
			npc.collision_layer = 0
		elif politica == "escravizar":
			npc.set_meta("capturado", true)
			npc.set_meta("escravizado", true)
		elif politica == "roubar": npc.set_meta("capturado", true)
