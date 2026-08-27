extends SceneTree
# ============================================================================
#  SONDA DA CONVENÇÃO DE DIREÇÃO — a tabela da rosa é a que o JOGO usa?
# ============================================================================
#
#  Uso:
#    godot --headless --path . -s tools/dev_tests/medir_rosa_dos_ventos.gd
#
#  NÃO SOBE O JOGO. É matemática e chamada direta ao código do jogo, então roda
#  em ~1 s, não disputa a porta com ninguém e pode rodar em paralelo com
#  qualquer outra coisa.
#
#  POR QUE ELA EXISTE
#  ------------------
#  `src/world/RosaDosVentos.gd` DECLARA uma convenção (norte = −Z, frente =
#  −Basis.z, yaw crescente gira para a esquerda). Declaração sem prova é
#  opinião: se a rosa dissesse uma coisa e o jogo fizesse outra, toda medição
#  feita contra ela estaria errada com aparência de certa — que é exatamente o
#  modo de falha do bug de 2026-08-25.
#
#  Então aqui a rosa é confrontada com QUATRO fontes independentes:
#
#    1. as constantes do MOTOR (`Vector3.FORWARD` e companhia);
#    2. o código de LOCOMOÇÃO do jogo, EXECUTADO — `MoveFrame.ler()`, que é
#       quem decide para onde o W anda (`src/player/move_frame.gd:65-67`);
#    3. a expressão da HITBOX do corpo a corpo, `-Basis.from_euler(0,yaw,0).z`
#       (`src/player/melee_controller.gd:154`) e a do KNOCKBACK
#       (`src/player/health_controller.gd:161`);
#    4. a geometria do próprio NÓ da rosa em cena (os pontos invisíveis).
#
#  E, no meio, reproduz de propósito a LINHA ERRADA de 2026-08-25
#  (`-Vector3.FORWARD.rotated(Vector3.UP, yaw)`) para provar que a rosa a
#  reprova com −1,00, e não por acaso.
#
#  ⚠️ Chama-se `medir_*` e não `test_*` de propósito: `validar.sh` descobre a
#  bateria varrendo `tools/dev_tests/test_*.gd` do disco, e o contrato do dono
#  é que ela continue em 34 passam / 0 falham. GATILHO para promover a
#  `test_convencao_direcao.gd`: quando a contagem da bateria deixar de ser um
#  número combinado (ou na próxima vez que alguém mexer em `_yaw`).
# ============================================================================

const YAWS_DE_PROVA := [0.0, 0.3, 0.7853981634, 1.5707963268, 2.0, 3.1415926536,
	-0.5, -1.5707963268, -2.5, 4.2, 5.5, 6.2831853072]
const TOL := 1e-5

var _ok := 0
var _mau := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║  ROSA DOS VENTOS — a convenção declarada é a do jogo?         ║")
	print("╚══════════════════════════════════════════════════════════════╝")

	_bloco_1_motor()
	_bloco_2_familias()
	_bloco_3_locomocao()
	_bloco_4_hitbox_e_knockback()
	_bloco_5_a_linha_errada()
	_bloco_6_sentido_do_yaw()
	_bloco_7_ida_e_volta()
	_bloco_8_mao_direita()
	_bloco_9_o_no_em_cena()

	print("\n──────────────────────────────────────────────────────────────")
	print("  %d conferem | %d divergem" % [_ok, _mau])
	if _mau > 0:
		print("❌ A CONVENÇÃO DECLARADA NÃO É A DO JOGO — a rosa está mentindo.")
		quit(1)
		return
	print("✓ convenção declarada = convenção usada pelo jogo, em %d ângulos" % YAWS_DE_PROVA.size())
	quit(0)

# ---------------------------------------------------------------- 1. o motor
func _bloco_1_motor() -> void:
	print("\n1. AS CONSTANTES DO MOTOR (a tabela eixo ↔ cardeal)")
	# ⚠️ Esta é a única vez que `Vector3.FORWARD` aparece ligado ao jogo: para
	# provar que ele é o NORTE do mundo, e NÃO "a frente do personagem".
	_igual("NORTE  == −Z == Vector3.FORWARD", RosaDosVentos.NORTE, Vector3.FORWARD)
	_igual("SUL    == +Z == Vector3.BACK   ", RosaDosVentos.SUL, Vector3.BACK)
	_igual("LESTE  == +X == Vector3.RIGHT  ", RosaDosVentos.LESTE, Vector3.RIGHT)
	_igual("OESTE  == −X == Vector3.LEFT   ", RosaDosVentos.OESTE, Vector3.LEFT)
	_igual("CIMA   == +Y == Vector3.UP     ", RosaDosVentos.CIMA, Vector3.UP)
	_igual("BAIXO  == −Y == Vector3.DOWN   ", RosaDosVentos.BAIXO, Vector3.DOWN)

# ---------------------------------------- 2. as três famílias falam a mesma língua
func _bloco_2_familias() -> void:
	print("\n2. AS TRÊS FAMÍLIAS SÃO A MESMA GEOMETRIA (mundo / eixos crus / corpo)")
	_igual("NORTE == eixo −Z", RosaDosVentos.MUNDO["NORTE"], RosaDosVentos.EIXOS["-Z"])
	_igual("SUL   == eixo +Z", RosaDosVentos.MUNDO["SUL"], RosaDosVentos.EIXOS["+Z"])
	_igual("LESTE == eixo +X", RosaDosVentos.MUNDO["LESTE"], RosaDosVentos.EIXOS["+X"])
	_igual("OESTE == eixo −X", RosaDosVentos.MUNDO["OESTE"], RosaDosVentos.EIXOS["-X"])
	_igual("CIMA  == eixo +Y", RosaDosVentos.MUNDO["CIMA"], RosaDosVentos.EIXOS["+Y"])
	_igual("BAIXO == eixo −Y", RosaDosVentos.MUNDO["BAIXO"], RosaDosVentos.EIXOS["-Y"])
	# Toda direção da rosa tem de ser unitária: uma direção de comprimento 0,7
	# estraga qualquer produto escalar sem nunca inverter sinal — erro que passa.
	var todas: Dictionary = {}
	todas.merge(RosaDosVentos.MUNDO)
	todas.merge(RosaDosVentos.EIXOS)
	todas.merge(RosaDosVentos.relativas(1.234))
	var fora := 0
	for nome in todas:
		if absf((todas[nome] as Vector3).length() - 1.0) > TOL:
			fora += 1
			print("   ✗ %s não é unitária (|v| = %.6f)" % [nome, (todas[nome] as Vector3).length()])
	_afirmar("as %d direções são unitárias" % todas.size(), fora == 0)

# ------------------------------------------------- 3. o código de LOCOMOÇÃO
func _bloco_3_locomocao() -> void:
	print("\n3. CONTRA O CÓDIGO DE LOCOMOÇÃO DO JOGO, EXECUTADO (`MoveFrame.ler`)")
	print("   — é quem decide para onde o W anda: src/player/move_frame.gd:65-67")
	var mf := MoveFrame.new()
	var pior_f := 1.0
	var pior_d := 1.0
	for yaw in YAWS_DE_PROVA:
		# `menu_fechado = false` deixa `ativo` falso: sem tela não há tecla, e o
		# que interessa (frente/direita) é calculado fora do `if ativo`.
		mf.ler(yaw, false)
		pior_f = minf(pior_f, mf.frente.dot(RosaDosVentos.frente(yaw)))
		pior_d = minf(pior_d, mf.direita.dot(RosaDosVentos.direita(yaw)))
	print("   pior dot(rosa.frente , MoveFrame.frente ) = %+.4f" % pior_f)
	print("   pior dot(rosa.direita, MoveFrame.direita) = %+.4f" % pior_d)
	_afirmar("a FRENTE da rosa é a frente da locomoção", pior_f > 1.0 - 1e-4)
	_afirmar("a DIREITA da rosa é a direita da locomoção", pior_d > 1.0 - 1e-4)

# --------------------------------------------- 4. hitbox do soco e knockback
func _bloco_4_hitbox_e_knockback() -> void:
	print("\n4. CONTRA A EXPRESSÃO DA HITBOX E A DO KNOCKBACK")
	print("   — melee_controller.gd:154 e health_controller.gd:161")
	var pior_h := 1.0
	var pior_k := 1.0
	for yaw in YAWS_DE_PROVA:
		# cópia LITERAL das duas linhas do jogo, sem passar pela rosa
		var fwd_hitbox := -Basis.from_euler(Vector3(0, yaw, 0)).z
		var base_cam := Basis.from_euler(Vector3(0, yaw, 0))
		var fwd_kb := -base_cam.z
		var dir_kb := base_cam.x
		pior_h = minf(pior_h, fwd_hitbox.dot(RosaDosVentos.frente(yaw)))
		pior_k = minf(pior_k, minf(fwd_kb.dot(RosaDosVentos.frente(yaw)),
			dir_kb.dot(RosaDosVentos.direita(yaw))))
	print("   pior dot(rosa, hitbox do soco)  = %+.4f" % pior_h)
	print("   pior dot(rosa, base do knockback) = %+.4f" % pior_k)
	_afirmar("a rosa é a direção que a HITBOX usa", pior_h > 1.0 - 1e-4)
	_afirmar("a rosa é a base que o KNOCKBACK usa", pior_k > 1.0 - 1e-4)

# ----------------------------------------------------- 5. a linha errada
func _bloco_5_a_linha_errada() -> void:
	print("\n5. A LINHA ERRADA DE 2026-08-25, REPRODUZIDA DE PROPÓSITO")
	print("   `-Vector3.FORWARD.rotated(Vector3.UP, yaw)` — o que estava no")
	print("   find_best_melee_target e no perform_melee_lunge. Tem que dar −1.")
	var pior := -1.0
	var melhor := 1.0
	for yaw in YAWS_DE_PROVA:
		var errada := -Vector3.FORWARD.rotated(Vector3.UP, yaw)
		var d := errada.dot(RosaDosVentos.frente(yaw))
		pior = maxf(pior, d)
		melhor = minf(melhor, d)
		if YAWS_DE_PROVA.find(yaw) < 3:
			print("      yaw=%+.4f  errada=(%+.2f,%+.2f,%+.2f)  rosa=(%+.2f,%+.2f,%+.2f)  dot=%+.2f"
				% [yaw, errada.x, errada.y, errada.z,
					RosaDosVentos.frente(yaw).x, RosaDosVentos.frente(yaw).y,
					RosaDosVentos.frente(yaw).z, d])
	print("   dot com a linha errada: entre %+.4f e %+.4f" % [melhor, pior])
	_afirmar("a rosa reprova a linha errada com −1,00 em TODO yaw", pior < -1.0 + 1e-4)

# --------------------------------------------------- 6. o sentido do yaw
func _bloco_6_sentido_do_yaw() -> void:
	print("\n6. O SENTIDO DO YAW (o jeito silencioso de errar 90°/180°)")
	# Se alguém trocar o sinal do yaw, NORTE e SUL continuam certos e
	# LESTE/OESTE trocam de lugar — por isso os quatro são conferidos.
	_igual("yaw = 0     → FRENTE = NORTE (−Z)", RosaDosVentos.frente(0.0), RosaDosVentos.NORTE)
	_igual("yaw = +π/2  → FRENTE = OESTE (−X)", RosaDosVentos.frente(PI * 0.5), RosaDosVentos.OESTE)
	_igual("yaw = +π    → FRENTE = SUL   (+Z)", RosaDosVentos.frente(PI), RosaDosVentos.SUL)
	_igual("yaw = −π/2  → FRENTE = LESTE (+X)", RosaDosVentos.frente(-PI * 0.5), RosaDosVentos.LESTE)
	_igual("yaw = 0     → DIREITA = LESTE (+X)", RosaDosVentos.direita(0.0), RosaDosVentos.LESTE)
	_igual("yaw = 0     → ESQUERDA = OESTE (−X)", RosaDosVentos.esquerda(0.0), RosaDosVentos.OESTE)
	_igual("yaw = 0     → TRÁS = SUL (+Z)", RosaDosVentos.tras(0.0), RosaDosVentos.SUL)

# ------------------------------------------------------- 7. ida e volta
func _bloco_7_ida_e_volta() -> void:
	print("\n7. IDA E VOLTA: `frente(yaw_para(d)) == d`")
	print("   — `yaw_para` é o `atan2(-x,-z)` que o lunge e a mira já usam")
	var pior := 1.0
	for nome in RosaDosVentos.CARDEAIS:
		var d: Vector3 = RosaDosVentos.MUNDO[nome]
		pior = minf(pior, RosaDosVentos.frente(RosaDosVentos.yaw_para(d)).dot(d))
	# diagonais, que é onde um atan2 com argumentos trocados se denuncia
	for d in [Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized(),
			Vector3(1, 0, 1).normalized(), Vector3(-3, 0, 1).normalized()]:
		pior = minf(pior, RosaDosVentos.frente(RosaDosVentos.yaw_para(d)).dot(d))
	print("   pior dot da ida-e-volta = %+.6f" % pior)
	_afirmar("a volta (direção → yaw) é a inversa exata da ida", pior > 1.0 - 1e-5)

# -------------------------------------------------------- 8. mão direita
func _bloco_8_mao_direita() -> void:
	print("\n8. O TRIEDRO É DESTRO (direita × frente = cima), em todo yaw")
	var pior := 1.0
	for yaw in YAWS_DE_PROVA:
		var c := RosaDosVentos.direita(yaw).cross(RosaDosVentos.frente(yaw))
		pior = minf(pior, c.dot(RosaDosVentos.CIMA))
	print("   pior dot(direita × frente, CIMA) = %+.6f" % pior)
	_afirmar("quem olha o NORTE tem o LESTE à direita", pior > 1.0 - 1e-5)

# ----------------------------------------------- 9. o nó (pontos invisíveis)
func _bloco_9_o_no_em_cena() -> void:
	print("\n9. O NÓ EM CENA — os pontos existem, seguem o yaw e NÃO APARECEM")
	var mundo := Node3D.new()
	get_root().add_child(mundo)
	var rosa: RosaDosVentos = RosaDosVentos.instalar(mundo)

	# 9a. cada ponto do mundo está exatamente em direção × RAIO
	var fora := 0
	for nome in RosaDosVentos.MUNDO:
		var p: Node3D = rosa.ponto(nome)
		if p == null or (p.position - (RosaDosVentos.MUNDO[nome] as Vector3) * RosaDosVentos.RAIO).length() > TOL:
			fora += 1
			print("   ✗ ponto %s fora do lugar" % nome)
	_afirmar("os 6 pontos cardeais estão no lugar declarado", fora == 0)

	# 9b. as relativas acompanham o yaw — medido na POSIÇÃO GLOBAL do ponto,
	#     não na conta que as criou (senão o teste provaria a si mesmo).
	var corpo := rosa.get_node("CORPO") as Node3D
	var pior := 1.0
	for yaw in YAWS_DE_PROVA:
		corpo.rotation.y = yaw
		mundo.force_update_transform()
		corpo.force_update_transform()
		var esperado := RosaDosVentos.relativas(yaw)
		for nome in RosaDosVentos.RELATIVAS:
			var p := rosa.ponto(nome)
			p.force_update_transform()
			var medido: Vector3 = (p.global_position - rosa.global_position).normalized()
			pior = minf(pior, medido.dot(esperado[nome]))
	print("   pior dot(ponto relativo medido, direção declarada) = %+.6f" % pior)
	_afirmar("os 6 pontos relativos acompanham o yaw do corpo", pior > 1.0 - 1e-4)

	# 9c. INVISÍVEL: nenhum VisualInstance3D e nenhum `_process`.
	var visuais := _contar_visuais(rosa)
	print("   VisualInstance3D dentro da rosa: %d | _process ligado: %s"
		% [visuais, "SIM" if rosa.is_processing() else "não"])
	_afirmar("a rosa não tem UMA malha sequer com a visualização desligada", visuais == 0)
	_afirmar("a rosa não roda `_process` em partida normal (custo zero de quadro)",
		not rosa.is_processing())

	# 9d. e quando LIGA, aparece — e ao desligar some TUDO (senão a rosa
	#     "invisível" passaria a ser cenário permanente).
	rosa.definir_visivel(true)
	var ligada := _contar_visuais(rosa)
	rosa.definir_visivel(false)
	var depois := _contar_visuais(rosa)
	print("   malhas: desligada=%d | ligada=%d | desligada de novo=%d" % [visuais, ligada, depois])
	_afirmar("F9/SOP_ROSA de fato cria a visualização", ligada > 0)
	_afirmar("desligar devolve a rosa ao estado invisível", depois == 0)
	mundo.queue_free()


# ⚠️ NÃO CONTA O QUE JÁ FOI DESCARTADO. `queue_free()` é DIFERIDO: o nó só sai
# da árvore no fim do quadro, então contar logo depois de desligar a
# visualização encontrava as 54 malhas ainda lá e acusava um vazamento que não
# existe — o `RosaDosVentos` estava certo, a conta é que estava errada.
#
# ⚠️ E A CORREÇÃO ÓBVIA ERA PIOR: esperar `await process_frame` aqui TRUNCAVA a
# sonda. Esta função é chamada SEM `await`, então o primeiro `await` devolve o
# controle ao chamador e as duas asserções seguintes nunca rodam — em silêncio,
# com o placar caindo de 33 para 31 sem nenhum erro. É a armadilha do `await`
# que este projeto já pagou três vezes (ver docs/erros.md).
func _contar_visuais(n: Node) -> int:
	var t := 0
	if n is VisualInstance3D and not n.is_queued_for_deletion():
		t += 1
	for c in n.get_children():
		t += _contar_visuais(c)
	return t

# ------------------------------------------------------------- utilidades
func _igual(rotulo: String, a: Vector3, b: Vector3) -> void:
	_afirmar("%s   (%+.0f,%+.0f,%+.0f)" % [rotulo, a.x, a.y, a.z], (a - b).length() <= TOL)


func _afirmar(rotulo: String, ok: bool) -> void:
	if ok:
		_ok += 1
		print("   ✓ %s" % rotulo)
	else:
		_mau += 1
		print("   ✗ %s" % rotulo)
