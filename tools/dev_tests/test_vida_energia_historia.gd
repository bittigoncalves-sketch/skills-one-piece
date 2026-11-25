extends SceneTree
# ============================================================================
#  TESTE DA VIDA E ENERGIA NA TELA DO MODO HISTÓRIA (pedido de 21/09/2026).
#
#  Prova, com o jogador real montado pelo Modo História:
#    1. as duas barras aparecem com os números do corpo (Civil: 20 e 10);
#    2. dano e gasto de energia mudam o texto (controle: o texto de antes era outro);
#    3. a HUD e a janela de status (M) mostram o MESMO número de vida — com a
#       regeneração ligada, arredondar para cima mostrava 18 com a vida em 17,00x;
#    4. sem corpo, as barras somem;
#    5. layout medido: as barras não encostam no aviso do topo (Level Up) nem no
#       painel F10 do combate.
#
#  ⚠️ Mapa e progresso FIXOS: o mapa vivo do dono nunca é lido nem gravado.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_vida_energia_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_vida_energia_historia_progresso.json"
## O aviso mais comprido que a HUD mostra hoje (barreira do nível 7).
const AVISO_MAIS_LONGO := "Nível 7: EVOLUÇÃO BLOQUEADA — complete a missão especial"

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== VIDA E ENERGIA NA TELA DO MODO HISTÓRIA =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var jogador := _jogador_local()
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	var barras: Control = hud.get_node_or_null("VidaEnergia") if hud != null else null
	_ok(jogador != null and barras != null, "o Modo História montou o jogador e a HUD tem as barras")
	if jogador != null and barras != null:
		_numeros_iniciais(jogador, barras)
		await _dano_e_energia(jogador, barras, hud)
		_regra_do_numero()
		await _sem_corpo(barras)
		await _layout(barras, hud, jogador)

	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _jogador_local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


# ---------------------------------------------------------------------- 1
func _numeros_iniciais(jogador: Node, barras: Control) -> void:
	print("\n-- 1. as barras mostram o corpo --")
	_ok(barras.visible, "as barras estão visíveis com o jogador em cena")
	# Os números vêm do corpo (progressão: `hp_maximo()`/`energia_maxima()`): literais 20/100 envelheceram (hoje 24/600 no nível 1).
	var hp := int(round(jogador.max_health))
	var en := int(round(jogador.max_energy))
	_ok(hp > 0 and en > 0, "(pré-condição) Civil nível 1: vida %d, energia %d" % [hp, en])
	_ok(barras.texto_da_vida() == "VIDA  %d / %d" % [hp, hp], "vida: \"%s\"" % barras.texto_da_vida())
	_ok(barras.texto_da_energia() == "ENERGIA  %d / %d" % [en, en], "energia: \"%s\"" % barras.texto_da_energia())
	_ok(barras.texto_do_nivel() == "NIVEL:%d" % int(jogador.get_meta("nivel", 1)), "nível acima da vida: \"%s\"" % barras.texto_do_nivel())


# ---------------------------------------------------------------------- 2 e 3
func _dano_e_energia(jogador: Node, barras: Control, hud: Node) -> void:
	print("\n-- 2. dano e gasto mudam o número; 3. a janela M concorda --")
	var antes: String = barras.texto_da_vida()
	var hp := int(round(jogador.max_health))
	var en := int(round(jogador.max_energy))
	jogador.take_damage(3.0)
	# Meio segundo de regeneração: a vida sai do inteiro (medido 17,0042 em 21/09). É
	# nesse trecho que arredondar para cima mostraria 18.
	var fim := Time.get_ticks_msec() + 200      # 200 ms (eram 500): a regeneração agora é mais rápida e 500 ms passava dos 0,5 que separam o arredondamento
	while Time.get_ticks_msec() < fim:
		await physics_frame
	await _quadros(1)
	# O dano de 3 chega reduzido pela escala da história e deixa a vida FRACIONÁRIA (ex.: 21,63) — é isso que separa "arredondar para o mais perto" de "para cima/baixo".
	var esperado: int = VidaEnergiaHud.vida_exibida(jogador.health)
	_ok(jogador.health < hp and jogador.health > hp - 3.5 and absf(jogador.health - round(jogador.health)) > 0.01,
		"(pré-condição) a vida ficou fracionária depois do dano (%.4f de %d)" % [jogador.health, hp])
	_ok(antes != barras.texto_da_vida() and barras.texto_da_vida() == "VIDA  %d / %d" % [esperado, hp],
		"3 de dano: \"%s\" → \"%s\" (vida real %.4f, esperado %d)" % [antes, barras.texto_da_vida(), jogador.health, esperado])
	var janela: Node = hud.janela_de_status()
	janela.jogador = jogador
	janela.atualizar()
	_ok(janela._rotulos["hp"].text == "%d / %d" % [esperado, hp],
		"a janela M mostra o mesmo número (\"%s\"; vida real %.4f)" % [janela._rotulos["hp"].text, jogador.health])

	jogador.energy = 4.7
	await _quadros(2)
	_ok(barras.texto_da_energia() == "ENERGIA  4 / %d" % en, "energia 4,7 aparece 4 (\"%s\")" % barras.texto_da_energia())
	jogador.energy = jogador.max_energy
	jogador.health = jogador.max_health
	await _quadros(2)
	_ok(barras.texto_da_vida() == "VIDA  %d / %d" % [hp, hp] and barras.texto_da_energia() == "ENERGIA  %d / %d" % [en, en],
		"cheio de novo, os dois voltam ao máximo")


func _regra_do_numero() -> void:
	print("\n-- regra do número de vida --")
	var casos := [[17.002, 17], [17.6, 18], [0.3, 1], [0.0, 0], [24.0, 24]]
	var erros := []
	for c in casos:
		if VidaEnergiaHud.vida_exibida(c[0]) != c[1]:
			erros.append("%s→%d" % [c[0], VidaEnergiaHud.vida_exibida(c[0])])
	_ok(erros.is_empty(), "arredonda para o mais perto e nunca mostra 0 com o corpo vivo %s" % str(erros))


# ---------------------------------------------------------------------- 4
func _sem_corpo(barras: Control) -> void:
	print("\n-- 4. sem corpo, sem barras --")
	barras.atualizar(null)
	_ok(not barras.visible, "sem jogador, as barras somem")
	await _quadros(2)
	_ok(barras.visible, "controle: com o jogador de volta no quadro seguinte, elas reaparecem")


# ---------------------------------------------------------------------- 5
func _layout(barras: Control, hud: Node, jogador: Node) -> void:
	print("\n-- 5. layout medido --")
	# O topo do painel F10 lido do nó de verdade (`DepuracaoDeCombate`, filho do executor).
	var painel: Node = jogador.combate_direcional.get_node_or_null("DepuracaoDeCombate")
	_ok(painel != null and painel.get_child_count() > 0 and painel.get_child(0) is Control,
		"(pré-condição) o painel F10 do combate existe no jogador")
	if painel == null or painel.get_child_count() == 0:
		return
	var TOPO_DO_PAINEL_F10: float = (painel.get_child(0) as Control).position.y
	var r: Rect2 = barras.get_global_rect()
	for b in barras.get_children():
		if b is Control:
			r = r.merge((b as Control).get_global_rect())
	_ok(r.end.y < TOPO_DO_PAINEL_F10, "as barras acabam em y=%.0f, antes do painel F10 (y=%.0f)" % [r.end.y, TOPO_DO_PAINEL_F10])
	hud.avisar(AVISO_MAIS_LONGO)
	await _quadros(2)
	var aviso: Label = hud.get_node("AvisoDeNivel")
	var largura_do_texto: float = aviso.get_theme_font("font").get_string_size(AVISO_MAIS_LONGO,
		HORIZONTAL_ALIGNMENT_LEFT, -1, aviso.get_theme_font_size("font_size")).x
	_ok(aviso.offset_bottom < TOPO_DO_PAINEL_F10,
		"o aviso (y %.0f–%.0f) acaba antes do painel F10 (y=%.0f)" % [aviso.offset_top, aviso.offset_bottom, TOPO_DO_PAINEL_F10])
	for largura_da_tela in [1280.0, 1024.0, 800.0]:
		var texto := Rect2((largura_da_tela - largura_do_texto) * 0.5, aviso.offset_top,
			largura_do_texto, aviso.offset_bottom - aviso.offset_top)
		_ok(not texto.intersects(r),
			"tela de %.0f px: o aviso mais longo (x %.0f–%.0f, y %.0f–%.0f) não cobre as barras (x %.0f–%.0f, y %.0f–%.0f)" \
				% [largura_da_tela, texto.position.x, texto.end.x, texto.position.y, texto.end.y,
					r.position.x, r.end.x, r.position.y, r.end.y])
