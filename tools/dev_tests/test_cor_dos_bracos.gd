extends SceneTree
# ============================================================================
#  TESTE DA COR DOS BRAÇOS — azul defendendo, vermelho atacando (30/09/2026).
#
#  Pedido do dono, para o jogador do Modo História e o boneco de duelo. Decisões:
#  vermelho no GOLPE INTEIRO (preparo, impacto e recuperação), azul com a guarda
#  erguida, tinta translúcida com transição rápida.
#
#    1. parado: braço sem cor;
#    2. guarda: os DOIS braços azuis — e o tronco/pernas não (controle);
#    3. golpe: vermelho do preparo ao fim da recuperação, e apaga depois;
#    4. o flash de dano ganha da cor e ela volta sozinha;
#    5. o boneco de duelo faz o mesmo (guarda azul, golpe vermelho).
#
#  ⚠️ Mapa e progresso FIXOS: o mapa vivo do dono nunca é lido nem gravado.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_cor_dos_bracos.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_cor_dos_bracos.json"

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== COR DOS BRAÇOS NO COMBATE =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var cena := current_scene
	var jogador: Node = cena.call("jogador_local") if cena != null and cena.has_method("jogador_local") else null
	_ok(jogador != null and jogador.get("combate_direcional") != null, "o Modo História subiu com o jogador lutando")
	if jogador != null and jogador.get("combate_direcional") != null:
		await _quadros(30)
		var ex: ExecutorCorpoACorpo = jogador.combate_direcional
		var cor := ex.find_child("CorDosBracos", true, false) as CorDosBracos
		_ok(cor != null, "o jogador tem a CorDosBracos (nasce com a apresentação do combate)")
		if cor != null:
			await _jogador(jogador, ex, cor)
			await _boneco(cena)
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


## Quantas malhas dos braços estão com a NOSSA tinta.
func _tingidas(cor: CorDosBracos) -> int:
	var n := 0
	for m in cor.malhas():
		if is_instance_valid(m) and m.material_overlay != null and m.material_overlay == cor.get("_material"):
			n += 1
	return n


## Malhas FORA dos braços (tronco, cabeça, pernas) com a nossa tinta — deve ser zero.
func _fora_dos_bracos(modelo: Node3D, cor: CorDosBracos) -> Array:
	var todas: Array = []
	var pilha: Array[Node] = [modelo]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n is GeometryInstance3D and not cor.malhas().has(n):
			todas.append(n)
		pilha.append_array(n.get_children())
	return todas


static func _parecida(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.08 and absf(a.g - b.g) < 0.08 and absf(a.b - b.b) < 0.08


func _jogador(jogador: Node, ex: ExecutorCorpoACorpo, cor: CorDosBracos) -> void:
	print("\n-- 1–4. o jogador --")
	var modelo: Node3D = ex.ator.modelo_visual()
	await _quadros(5)
	var total := cor.malhas().size()
	_ok(total >= 6, "achou as malhas dos DOIS braços (%d, braço + antebraço + mão)" % total)
	_ok(_tingidas(cor) == 0 and cor.tinta().a < 0.01, "parado: braço sem cor")

	ex.erguer_guarda()
	await _quadros(20)
	_ok(ex.em_guarda(), "(pré-condição) a guarda está erguida")
	_ok(_tingidas(cor) == total and _parecida(cor.tinta(), CorDosBracos.AZUL)
		and is_equal_approx(cor.tinta().a, CorDosBracos.OPACIDADE),
		"guarda: os dois braços AZUIS (%d de %d, opacidade %.2f)" % [_tingidas(cor), total, cor.tinta().a])
	var fora := _fora_dos_bracos(modelo, cor)
	var fora_tingidas := fora.filter(func(m): return m.material_overlay == cor.get("_material")).size()
	_ok(fora.size() > 0 and fora_tingidas == 0,
		"controle: tronco, cabeça e pernas sem cor (%d malhas, %d tingidas)" % [fora.size(), fora_tingidas])

	# Flash de dano com a guarda erguida: o flash ganha, e a cor volta.
	FxUtil.flash_dano(modelo)
	await _quadros(2)
	_ok(_tingidas(cor) == 0, "o flash de dano toma o braço (a nossa tinta sai durante ele)")
	await _quadros(45)
	_ok(_tingidas(cor) == total, "terminado o flash, o azul volta sozinho (%d de %d)" % [_tingidas(cor), total])

	ex.baixar_guarda()
	await _quadros(30)
	_ok(_tingidas(cor) == 0 and cor.tinta().a < 0.01, "baixou a guarda: a cor some")

	# Golpe: vermelho do preparo ao fim da recuperação.
	var vermelho_em := {}
	_ok(ex.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "(pré-condição) o golpe começou")
	var t := 0
	while ex.atacando() and t < 180:
		await _quadros(1)
		t += 1
		var fase := ex.estado
		if cor.tinta().a > 0.3 and _parecida(cor.tinta(), CorDosBracos.VERMELHO) and _tingidas(cor) == total:
			vermelho_em[fase] = true
	_ok(vermelho_em.has(ExecutorCorpoACorpo.Estado.PREPARO), "vermelho no PREPARO")
	_ok(vermelho_em.has(ExecutorCorpoACorpo.Estado.ATIVO), "vermelho no IMPACTO (ativo)")
	_ok(vermelho_em.has(ExecutorCorpoACorpo.Estado.RECUPERACAO), "vermelho na RECUPERAÇÃO (o golpe inteiro)")
	await _quadros(15)
	_ok(not ex.atacando() and _tingidas(cor) == 0, "acabou o golpe: a cor some")


func _boneco(cena: Node) -> void:
	print("\n-- 5. o boneco de duelo --")
	var boneco: BonecoDeDuelo = cena.call("invocar_boneco", &"guarda")
	_ok(boneco != null, "(pré-condição) o boneco foi invocado em \"Só guarda\"")
	if boneco == null:
		return
	await _quadros(40)
	var cor := boneco.combate_direcional.find_child("CorDosBracos", true, false) as CorDosBracos
	_ok(cor != null and cor.malhas().size() >= 6, "o boneco tem a mesma CorDosBracos")
	if cor == null:
		return
	_ok(boneco.combate_direcional.em_guarda() and _tingidas(cor) == cor.malhas().size()
		and _parecida(cor.tinta(), CorDosBracos.AZUL), "boneco de guarda: braços azuis")
	cena.call("invocar_boneco", &"ataca")
	var viu_vermelho := false
	for i in 240:
		await _quadros(1)
		if boneco.combate_direcional.atacando() and _parecida(cor.tinta(), CorDosBracos.VERMELHO) \
				and _tingidas(cor) == cor.malhas().size():
			viu_vermelho = true
			break
	_ok(viu_vermelho, "boneco atacando: braços vermelhos")
	cena.call("remover_boneco")
