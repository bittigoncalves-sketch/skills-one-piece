extends SceneTree
# ============================================================================
#  TESTE DA RESOLUÇÃO DE CONTATO — o lado do impacto, pela geometria.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D6, D11). Atacante e defensor frente a
#  frente em 8 orientações do mundo; o golpe viaja para a esquerda, para a direita
#  ou para a frente DO ATACANTE, e o lado tem que sair do ponto de vista do DEFENSOR.
#
#  Base do corpo pela expressão literal (`Basis.from_euler`), não pela RosaDosVentos:
#  comparar a rosa com ela mesma passaria com a convenção errada (docs/DIRECOES.md).
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_resolucao_de_contato.gd
# ============================================================================

const L := ResolucaoDeContato.Lado

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== RESOLUÇÃO DE CONTATO =====")
	var erros := 0
	var casos := 0
	for i in 8:
		var yaw_mundo := TAU * i / 8.0
		# Defensor na origem, olhando para yaw_mundo; atacante 1 m à frente dele,
		# olhando de volta para ele.
		var base_def := Basis.from_euler(Vector3(0, yaw_mundo, 0))
		var frente_def := -base_def.z
		var pos_def := Vector3(3, 0, -2)
		var pos_atk := pos_def + frente_def * 1.0
		var base_atk := Basis.from_euler(Vector3(0, yaw_mundo + PI, 0))
		var esquerda_atk := -base_atk.x
		var direita_atk := base_atk.x
		var frente_atk := -base_atk.z
		for c in [
				[esquerda_atk, L.ESQUERDA, "golpe viaja para a ESQUERDA do atacante → defensor atingido pela ESQUERDA"],
				[direita_atk, L.DIREITA, "golpe viaja para a DIREITA do atacante → defensor atingido pela DIREITA"],
				[frente_atk, L.FRENTE, "golpe viaja para a frente → FRENTE"],
				[frente_atk * 0.7 + Vector3.DOWN * 0.7, L.FRENTE, "golpe de cima (desce e avança) → FRENTE"]]:
			casos += 1
			var obtido := ResolucaoDeContato.lado_do_impacto(c[0], pos_atk, pos_def, base_def)
			if obtido != c[1]:
				erros += 1
				print("  ❌ yaw %.0f°: %s (obteve %s)" % [rad_to_deg(yaw_mundo), c[2], L.keys()[obtido]])
		# Pelas costas: atacante atrás, golpe para a esquerda dele — tanto faz o sentido.
		casos += 1
		var obtido_costas := ResolucaoDeContato.lado_do_impacto(esquerda_atk, pos_def - frente_def * 1.0, pos_def, base_def)
		if obtido_costas != L.COSTAS:
			erros += 1
			print("  ❌ yaw %.0f°: atacante atrás → COSTAS (obteve %s)" % [rad_to_deg(yaw_mundo), L.keys()[obtido_costas]])
	_ok(erros == 0, "%d casos em 8 orientações do mundo, %d errado(s)" % [casos, erros])

	# Sabotagem: se a conta ignorasse o referencial do defensor (usasse o do
	# atacante), esquerda e direita inverteriam. O teste precisa ver essa diferença.
	var base_def := Basis.from_euler(Vector3(0, 0.3, 0))
	var base_atk := Basis.from_euler(Vector3(0, 0.3 + PI, 0))
	var pos_def := Vector3.ZERO
	var pos_atk := -base_def.z
	var com_base_certa := ResolucaoDeContato.lado_do_impacto(-base_atk.x, pos_atk, pos_def, base_def)
	var com_base_errada := ResolucaoDeContato.lado_do_impacto(-base_atk.x, pos_atk, pos_def, base_atk)
	_ok(com_base_certa == L.ESQUERDA and com_base_errada != com_base_certa,
		"controle: usar a base do ATACANTE daria outro lado (%s × %s) — o teste sabe reprovar"
		% [L.keys()[com_base_certa], L.keys()[com_base_errada]])
	_defesa()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _defesa() -> void:
	print("\n-- defesa: cone e postura --")
	var R := ResolucaoDeContato.Resultado
	var estilo := load("res://src/combat/direcional/estilos/boxe.tres") as EstiloCorpoACorpo
	var golpe := estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA)
	var cone := estilo.cone_da_guarda
	var erros := 0
	var casos := 0
	for i in 8:
		var yaw := TAU * i / 8.0
		var base := Basis.from_euler(Vector3(0, yaw, 0))
		var pos_def := Vector3(-2, 0, 5)
		for c in [
				[0.0, true, 100.0, R.BLOQUEIO, "de frente, com guarda e postura"],
				[45.0, true, 100.0, R.BLOQUEIO, "45° do eixo (dentro do cone de 120°)"],
				[-45.0, true, 100.0, R.BLOQUEIO, "−45° do eixo"],
				[70.0, true, 100.0, R.ACERTO, "70° do eixo (fora do cone)"],
				[180.0, true, 100.0, R.ACERTO, "pelas costas, mesmo com guarda"],
				[0.0, false, 100.0, R.ACERTO, "de frente, SEM guarda"],
				[0.0, true, golpe.dano_de_postura, R.QUEBRA_DE_GUARDA, "postura igual ao dano do golpe: quebra"],
				[0.0, true, golpe.dano_de_postura + 0.5, R.BLOQUEIO, "controle: meio ponto a mais segura"]]:
			casos += 1
			# Atacante a 1 m, `c[0]` graus a partir da frente do defensor.
			var dir := base * Basis.from_euler(Vector3(0, deg_to_rad(c[0]), 0)) * Vector3.FORWARD
			var obtido := ResolucaoDeContato.resolver(golpe, pos_def + dir, c[1], false, c[2], cone, pos_def, base)
			if obtido != c[3]:
				erros += 1
				print("  ❌ yaw %.0f°: %s → %s (obteve %s)" % [rad_to_deg(yaw), c[4], R.keys()[c[3]], R.keys()[obtido]])
	_ok(erros == 0, "%d casos de defesa em 8 orientações, %d errado(s)" % [casos, erros])
	_ok(ResolucaoDeContato.resolver_entre(golpe, Vector3.ZERO, null) == R.ACERTO,
		"alvo sem combate direcional (inimigo estático) é sempre ACERTO")


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1
