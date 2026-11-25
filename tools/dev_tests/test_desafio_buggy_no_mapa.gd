extends SceneTree
# (etapas: 1 CENA, 2 CORRIDA, 3 FALANDO, 4 JOGANDO, 5 OFERTA; fase do jogo 3 = ESCOLHA — o --script não pode citar classes que usam autoloads)
# Desafio do Buggy no MAPA REAL (21/11/2026): cena, corrida dos moradores, conversa, copos, erro → missão da luta (instrutor até o nível 3, depois o Buggy). Rodar:
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_desafio_buggy_no_mapa.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	print("\n===== DESAFIO DO BUGGY NO MAPA =====")
	var R := RegrasDoDesafioBuggy
	var caminho := "user://teste_desafio_buggy.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 2400:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("desafio_buggy") != null:
			d = current_scene.desafio_buggy
			break
	ok("o orquestrador existe no modo história", d != null)
	if d == null:
		quit(1); return
	await frames(30)
	var hud = d.hud
	# 1. A cena toca sozinha (treino entregue, fase vazia)
	for i in 400:
		await physics_frame
		if d.etapa == 1: break
	ok("a cena começa sozinha após o treino entregue", d.etapa == 1 and d.cena.rodando())
	ok("HUD escondida e jogador congelado (is_menu_open)", hud.is_menu_open())
	ok("TRÉGUA: o combate do jogador fica desligado desde o começo da cena", d.tregua_ativa() and not p.capacidades.can_attack and not p.capacidades.can_use_skills and not p.capacidades.can_use_fruit)
	ok("Buggy e tripulação ficam escondidos no começo da cena (antes do desembarque)", not d.chegada.buggy.visible and d.chegada.tripulacao.all(func(t): return not t.visible))
	var magenta := 0
	for mi in d.chegada.navio.find_children("*", "MeshInstance3D", true, false):
		for sf in mi.mesh.get_surface_count():
			var mt = mi.get_active_material(sf)
			if mt != null and mt.albedo_texture == null and mt.albedo_color.r > 0.9 and mt.albedo_color.b > 0.9 and mt.albedo_color.g < 0.1: magenta += 1
	ok("o navio não tem mais superfície magenta sem textura", magenta == 0)
	ok("cena lenta: soma dos planos ≥ 24 s", d.cena._planos.reduce(func(a, p2): return a + float(p2.dur), 0.0) >= 24.0)
	var x0 = d.chegada.navio.global_position.x
	await frames(120)
	var x1 = d.chegada.navio.global_position.x
	ok("o navio avança em direção ao cais (x diminui %.1f → %.1f)" % [x0, x1], x1 < x0 - 3.0)
	ok("a câmera da cena é a atual", get_root_camera_is_cena())
	ok("o mar sob o navio é água (nível acima do fundo)", AguaDoMundo.nivel_em(d.chegada.navio.global_position.x, d.chegada.navio.global_position.z) > -50.0)
	ok("SEM MÚSICA: a trilha da chegada não toca durante a cena (pedido do dono, 22/11)", not d.musica.tocando("res://assets/audio/musica/buggy_chegada.ogg") and d.musica.get_child_count() == 0)
	d.cena.pular()
	await frames(90)
	ok("pular termina a cena e o jogador já está na conversa com o Buggy", (d.etapa == 2 or d.etapa == 3) and not d.cena.rodando())
	ok("fase = chegou e missão dos copos aceita", R.fase(d.progressao) == R.CHEGOU and d.progressao.estado_da_missao(R.MISSAO_COPOS) == "aceita")
	ok("ao pular a cena todos aparecem", d.chegada.buggy.visible and d.chegada.tripulacao.all(func(t): return t.visible))
	var ancora = d.chegada.ancora
	var db = d.chegada.buggy.global_position.distance_to(ancora)
	print("  buggy a %.1f m da âncora; pos %s ; âncora %s" % [db, d.chegada.buggy.global_position, ancora])
	ok("o Buggy já está na praia, sem caminhada (≤ 1 m do ponto dele)", d.chegada.buggy.global_position.distance_to(d.chegada.ponto_do_buggy_na_praia()) < 1.0)
	ok("Barba Negra (rig próprio) não corre com a vila", d.npcs.npcs.all(func(n): return not (is_instance_valid(n) and n.tipo == "npc_barba_negra" and n.correndo())))
	# 22/11/2026 (pedido do dono): ao fim da cena o jogador NASCE de frente para o bando e a conversa abre sozinha — sem bússola, sem correr.
	ok("sem bússola: o jogador já está no Buggy", d.ponto_da_bussola() == null)
	var dist_buggy: float = p.global_position.distance_to(d.chegada.buggy.global_position)
	ok("o jogador foi posto perto do Buggy (%.1f m, dentro de 6 m)" % dist_buggy, dist_buggy <= d.RAIO_DO_BUGGY)
	var rumo: Vector3 = d.chegada.buggy.global_position - p.global_position
	rumo.y = 0.0
	ok("e de frente para ele (olha para o Buggy)", RosaDosVentos.frente(p._yaw).dot(rumo.normalized()) > 0.95)
	var a_oeste: bool = p.global_position.x < d.chegada.ponto_no_chao(d.chegada.POS_MESA).x
	ok("do lado da vila (oeste da mesa)", a_oeste)
	for i in 240:
		await physics_frame
		if d.etapa == 3: break
	ok("a conversa do desafio abre sozinha", d.etapa == 3 and hud.caixa_de_fala().ativa())
	ok("moradores já estão em volta da mesa, sem correr", d.npcs.npcs.all(func(n): return not (is_instance_valid(n) and n.correndo())))
	var mesa_pos = d.chegada.ponto_no_chao(d.chegada.POS_MESA)
	var corredores = d.npcs.npcs.filter(func(n): return is_instance_valid(n) and n.global_position.distance_to(d.chegada.ancora) <= d.RAIO_DA_ILHA and not n.has_meta("morto") and not n.get_meta("escravizado", false) and n.tipo != "npc_barba_negra")      # os mesmos que a plateia chama
	var longe = corredores.filter(func(n): return n.global_position.distance_to(mesa_pos) > 7.5)
	ok("todos a ≤ 7,5 m da mesa, na praia (%d longe)" % longe.size(), longe.is_empty())
	var na_areia = corredores.all(func(n): return n.global_position.y > 0.1)
	ok("todos em chão firme (y > 0,1: areia, não água)", na_areia)
	ok("a mesa apareceu na praia", d.chegada.mesa.visible and d.chegada.mesa.global_position.distance_to(mesa_pos) < 0.5)
	var anim = d.chegada.animador_do_buggy()
	ok("o Buggy tem animações (idle quando parado)", anim != null and anim.tem("idle") and anim.tem("walk") and anim.atual == "idle")
	var buggy_praia = d.chegada.buggy.global_position
	ok("o Buggy andou do deck até a praia (≤ 1 m do ponto dele; a %.1f m)" % buggy_praia.distance_to(d.chegada.ponto_do_buggy_na_praia()), buggy_praia.distance_to(d.chegada.ponto_do_buggy_na_praia()) < 1.0)
	ok("a tripulação está ao lado dele na praia", d.chegada.tripulacao.all(func(t): return t.global_position.distance_to(buggy_praia) < 6.0 and t.global_position.y > 0.1))
	var caixa = hud.caixa_de_fala()
	ok("a conversa do desafio está aberta", d.etapa == 3 and caixa.ativa())
	ok("FOCO: a câmera vai para o rosto do Buggy enquanto ele fala", root.get_viewport().get_camera_3d() != null and root.get_viewport().get_camera_3d().name == "CameraDoRosto")
	var cam_rosto = root.get_viewport().get_camera_3d()
	ok("a câmera do rosto está perto dele (< 3 m) e olha para a cabeça", cam_rosto.global_position.distance_to(d.chegada.rosto_do_buggy()) < 3.0)
	var gesticulou := false
	for i in 400:
		await physics_frame
		if d.chegada.animador_do_buggy().atual != "idle": gesticulou = true
	ok("falando, ele gesticula (animação de gesto tocada)", gesticulou)
	caixa.pular()
	for i in 120:
		await physics_frame
		if d.etapa == 4: break
	ok("fim da conversa: a câmera do jogador volta", root.get_viewport().get_camera_3d() != null and root.get_viewport().get_camera_3d().name != "CameraDoRosto")
	ok("fim da conversa → jogo dos copos", d.etapa == 4 and d._jogo != null)
	var jogo = d._jogo
	ok("SEM MÚSICA: o loop dos copos não toca durante o jogo", not d.musica.tocando("res://assets/audio/musica/buggy_copos_loop.ogg"))
	ok("os copos estão em cima da mesa (y do jogo = tampo %.2f)" % d.chegada.tampo_da_mesa().y, absf(jogo.global_position.y - d.chegada.tampo_da_mesa().y) < 0.05 and jogo.global_position.distance_to(d.chegada.tampo_da_mesa()) < 0.1)
	for i in 60 * 14:
		await physics_frame
		if jogo.fase == 3: break
	ok("o embaralho chega à escolha", jogo.fase == 3)
	var errado = (jogo.pedra_no_copo() + 1) % 3
	var xp_antes = d.progressao.xp; var nivel_antes = d.progressao.nivel
	jogo.escolher(errado)
	await frames(60 * 3)
	ok("erro: sem XP; a missão da luta JÁ é entregue (fase aceitou, missão aceita)", R.fase(d.progressao) == R.ACEITOU and d.progressao.estado_da_missao(R.MISSAO_LUTA) == "aceita" and d.progressao.xp == xp_antes and d.progressao.nivel == nivel_antes)
	ok("o Buggy fala o erro_n7 (caixa ativa)", caixa.ativa() or d.etapa == 2)
	if caixa.ativa(): caixa.pular()
	await frames(60)
	ok("sem pergunta de aceitar: nenhuma janela de oferta abre", not hud.loja_aberta() and d.etapa == 2)
	ok("nível %d < %d: o jogador deve TREINAR e a luta ainda não abre" % [d.progressao.nivel, R.NIVEL_DA_LUTA], R.deve_treinar(d.progressao) and not R.luta_disponivel(d.progressao))
	var instrutor = d._achar_instrutor()
	var ponto = d.ponto_da_bussola()
	ok("a bússola aponta o INSTRUTOR (não o Buggy nem a Alvida)", instrutor != null and ponto is Vector3 and (ponto as Vector3).distance_to(instrutor.global_position) < 0.5)
	var objetivos := get_nodes_in_group("objetivo_de_missao")
	ok("MARCADOR: o instrutor é objetivo marcado da missão da luta (falta nível)", instrutor != null and objetivos.has(instrutor) and str(instrutor.get_meta("missao_do_objetivo", "")) == R.MISSAO_LUTA)
	ok("MARCADOR: o Buggy ainda não é objetivo (falta nível)", not objetivos.has(d.chegada.buggy))
	var alvida = current_scene.get("missao_da_alvida")
	ok("a bússola da Alvida fica escondida para quem não venceu o Buggy", alvida == null or alvida.ponto_da_bussola() == null)
	d.progressao.nivel = R.NIVEL_DA_LUTA
	await frames(60)
	ok("nível %d: a luta fica disponível" % R.NIVEL_DA_LUTA, R.luta_disponivel(d.progressao) and not R.deve_treinar(d.progressao))
	p.global_position = d.chegada.buggy.global_position + Vector3(-40.0, 0.8, 0.0)      # longe do Buggy: perto dele a bússola se esconde
	await frames(10)
	var ponto2 = d.ponto_da_bussola()
	var objetivos2 := get_nodes_in_group("objetivo_de_missao")
	ok("MARCADOR: com o nível, o Buggy vira o objetivo marcado e o instrutor deixa de ser", objetivos2.has(d.chegada.buggy) and not objetivos2.has(instrutor))
	ok("agora a bússola aponta o Buggy (cais)", ponto2 is Vector3 and (ponto2 as Vector3).distance_to(d.chegada.ponto_do_buggy_na_praia()) < 0.5)
	ok("TRÉGUA: depois de aceitar, o combate volta", not d.tregua_ativa() and p.capacidades.can_attack and d._caps_antes.is_empty())      # can_use_skills/fruit já eram falsos no nível 1 (Civil)
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func get_root_camera_is_cena() -> bool:
	var c := root.get_viewport().get_camera_3d()
	return c != null and c.name == "CameraDaCena"
