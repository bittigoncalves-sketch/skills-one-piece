extends SceneTree
# ============================================================================
#  MENU DE CUSTOMIZAÇÃO — faz o que foi pedido?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_customizacao.gd -- <pasta>
#
#  Confere item por item o pedido do dono, e captura a tela para o resto:
#    • as duas categorias à esquerda
#    • o personagem no centro, em 3D
#    • escolher acessório EQUIPA na hora
#    • dois da MESMA parte não convivem — o antigo sai sozinho
#    • "Nenhum" tira o acessório (senão só dá para trocar, nunca tirar)
#    • a cor pinta o corpo e NÃO pinta o acessório
# ============================================================================

var _ok_n := 0
var _falhas := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/custom"
	DirAccess.make_dir_recursive_absolute(saida)
	await process_frame

	var menu := CustomizacaoMenu.new()
	get_root().add_child(menu)
	for i in 30: await process_frame

	# ---------- estrutura ----------
	var cats: Dictionary = menu._botoes_categoria
	_ok("há quatro categorias à esquerda", cats.size() == 4)
	for c in ["acessorios", "raca", "corpo", "cor"]:
		_ok("categoria '%s' existe" % c, cats.has(c))
	_ok("o personagem foi montado no centro", menu._modelo != null and is_instance_valid(menu._modelo))
	_ok("o viewport tem mundo próprio (não mostra a arena)", menu._viewport.own_world_3d)

	# ⚠️ A TELA TEM DE CABER. Com os seis acessórios a lista da direita fez o
	# menu chegar a 1.022 px numa tela de 720: o viewport 3D ficou com 818 px de
	# altura e só a parte de cima aparecia — parecia defeito de CÂMERA, e era de
	# LAYOUT. A lista agora rola; esta conferência impede a volta.
	var tela: Vector2i = get_root().size
	var fora := _fora_da_tela(menu, tela, false)
	_ok("nada passa da tela (%dx%d)" % [tela.x, tela.y], fora.is_empty())
	for f in fora:
		print("      ❗ %s" % f)
	_ok("o viewport 3D cabe na tela", menu._viewport.size.y <= tela.y)

	var modelo: Node3D = menu._modelo

	# ---------- equipar ----------
	print("\n--- equipar ---")
	_ok("começa sem acessório na cabeça", Acessorios.equipado_na_parte(modelo, "cabeca") == "")
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	_ok("o chapéu foi equipado", Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha")
	_ok("o chapéu está no nó Head", _pai_do_acessorio(modelo, "cabeca", "chapeu_palha_0") == "Head")
	_ok("o chapéu engole 1/3 da cabeça", _fracao(modelo) > 0.31 and _fracao(modelo) < 0.35)

	# ---------- exclusão mútua ----------
	# ⚠️ O catálogo é `const`, e no Godot 4 dicionário constante é IMUTÁVEL — não
	# dá para inventar um segundo item nele. Em vez disso o teste pendura um nó
	# com a marca de acessório direto no nó da parte, que é exatamente o estado
	# que "já havia outro acessório aqui" produz. E isso testa a versão FORTE da
	# regra: `desequipar` varre por PREFIXO, então tira até peça cujo id o
	# catálogo não conhece mais.
	print("\n--- exclusão mútua (o pedido central) ---")
	var cabeca := Acessorios.no_da_parte(modelo, "cabeca")
	var intruso := Node3D.new()
	intruso.name = Acessorios._prefixo("cabeca") + "outro_chapeu_0"
	cabeca.add_child(intruso)
	for i in 3: await process_frame
	_ok("cenário montado: dois acessórios na cabeça", _contar_acessorios(modelo) == 2)
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	_ok("equipar na MESMA parte não empilha", _contar_acessorios(modelo) == 1)
	_ok("o intruso saiu sozinho", not is_instance_valid(intruso) or intruso.get_parent() == null)
	_ok("o novo ficou equipado", Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha")
	Acessorios.desequipar(modelo, "cabeca")

	# ---------- partes que compartilham o MESMO nó ----------
	# ⚠️ A ASSERÇÃO QUE FALTAVA. "tronco", "costas", "cintura" e "pernas" penduram
	# todas no nó `Torso`. Com a limpeza varrendo o nó inteiro por prefixo,
	# equipar as espadas (cintura) APAGAVA o colete (tronco) — e a bateria passava
	# assim mesmo, porque só testava uma parte de cada vez.
	print("\n--- partes que dividem o mesmo nó ---")
	Acessorios.equipar(modelo, "luffy_camisa")
	Acessorios.equipar(modelo, "espadas_zoro")
	Acessorios.equipar(modelo, "luffy_calcao")
	Acessorios.equipar(modelo, "capa_marinha")
	for i in 4: await process_frame
	_ok("colete (tronco) sobrevive", Acessorios.equipado_na_parte(modelo, "tronco") == "luffy_camisa")
	_ok("espadas (cintura) sobrevivem", Acessorios.equipado_na_parte(modelo, "cintura") == "espadas_zoro")
	_ok("calção (pernas) sobrevive", Acessorios.equipado_na_parte(modelo, "pernas") == "luffy_calcao")
	_ok("capa (costas) sobrevive", Acessorios.equipado_na_parte(modelo, "costas") == "capa_marinha")
	print("   as 4 peças no Torso: %d nós de acessório" % _contar_acessorios(modelo))
	_ok("as quatro convivem no mesmo nó", _contar_acessorios(modelo) == 4)
	# e trocar UMA delas não derruba as outras
	Acessorios.desequipar(modelo, "cintura")
	for i in 3: await process_frame
	_ok("tirar a cintura NÃO tira o tronco",
		Acessorios.equipado_na_parte(modelo, "tronco") == "luffy_camisa")
	for parte in Acessorios.PARTES:
		Acessorios.desequipar(modelo, String(parte))

	# ---------- os pés são DOIS nós ----------
	Acessorios.equipar(modelo, "chinelo")
	for i in 3: await process_frame
	_ok("o chinelo cria uma peça em CADA pé", _contar_acessorios(modelo) == 2)
	Acessorios.desequipar(modelo, "pes")
	_ok("tirar o chinelo tira os dois", _contar_acessorios(modelo) == 0)

	# ---------- tirar ----------
	print("\n--- tirar ---")
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	Acessorios.desequipar(modelo, "cabeca")
	for i in 5: await process_frame
	_ok("'Nenhum' tira o acessório", Acessorios.equipado_na_parte(modelo, "cabeca") == "")
	_ok("não sobra nó de acessório", _contar_acessorios(modelo) == 0)

	# ---------- cor ----------
	print("\n--- cor ---")
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	menu._cor_idx = 1
	menu._pintar()
	for i in 5: await process_frame
	_ok("a cor pinta o CORPO", _cor_de(modelo, "Torso") == Paleta.CORES[1]["cor"])
	_ok("a cor NÃO pinta o acessório", not _acessorio_pintado(modelo))

	# ---------- raças ----------
	print("\n--- raças ---")
	Acessorios.desequipar(modelo, "cabeca")
	menu._cor_idx = -1
	menu._pintar()
	_ok("as 8 raças estão no catálogo", Racas.ids().size() == 8)
	_ok("começa sem raça", Racas.atual(modelo) == "")

	# cada raça acrescenta peça OU muda escala — nenhuma pode ser inerte
	for id in Racas.ids():
		Racas.aplicar(modelo, id)
		for i in 3: await process_frame
		var pecas := _contar_racas(modelo)
		var escalado := _tem_escala_mudada(modelo)
		_ok("%s muda o corpo (peças=%d, escala=%s)" % [id, pecas, str(escalado)],
			pecas > 0 or escalado)
		_ok("%s é reconhecida como a raça atual" % id, Racas.atual(modelo) == id)

	# exclusão GLOBAL: trocar de raça não acumula
	print("\n--- exclusão global de raça ---")
	Racas.aplicar(modelo, "oni")
	for i in 3: await process_frame
	var n_oni := _contar_racas(modelo)
	Racas.aplicar(modelo, "mink_coelho")
	for i in 3: await process_frame
	_ok("trocar de raça não acumula peças", _contar_racas(modelo) == 3)
	_ok("a raça anterior sumiu", Racas.atual(modelo) == "mink_coelho")
	print("   (oni tinha %d peças; mink_coelho tem %d)" % [n_oni, _contar_racas(modelo)])

	# escala volta ao original
	print("\n--- a escala desfaz ---")
	var braco := modelo.find_child("UpperArm_R", true, false) as Node3D
	var esc0: Vector3 = braco.scale
	Racas.aplicar(modelo, "bracos_longos")
	for i in 3: await process_frame
	var esc1: Vector3 = braco.scale
	_ok("braços longos ESTICAM o braço", esc1.y > esc0.y * 1.4)
	Racas.aplicar(modelo, "oni")
	for i in 3: await process_frame
	_ok("trocar de raça DEVOLVE a escala original", braco.scale.is_equal_approx(esc0))
	print("   escala do braço: %.2f → %.2f → %.2f" % [esc0.y, esc1.y, braco.scale.y])

	# ⚠️ A ASSERÇÃO QUE FALTAVA. `ForeArm` é FILHO de `UpperArm`: escalar os dois
	# MULTIPLICA, e o antebraço ia a 2,4× em vez de 1,55×. A bateria passava
	# assim mesmo, porque só olhava a escala LOCAL do ombro — que estava certa.
	# Quem denuncia é a escala GLOBAL da ponta da cadeia.
	var antebraco := modelo.find_child("ForeArm_R", true, false) as Node3D
	var g0: float = antebraco.global_transform.basis.get_scale().y
	Racas.aplicar(modelo, "bracos_longos")
	for i in 5: await process_frame
	var g1: float = antebraco.global_transform.basis.get_scale().y
	var fator: float = g1 / g0
	print("   escala GLOBAL do antebraço: %.2f → %.2f (fator %.2f×)" % [g0, g1, fator])
	_ok("o alongamento NÃO compõe pela hierarquia (fator ~1,55×)",
		absf(fator - 1.55) < 0.06)
	Racas.remover(modelo)

	# a cor do mink lobo
	print("\n--- o Mink Lobo segue a cor ---")
	Racas.aplicar(modelo, "mink_lobo")
	menu._cor_idx = 2
	menu._pintar()
	for i in 3: await process_frame
	_ok("as peças do Mink Lobo ficam da cor do personagem",
		_cor_da_peca_raca(modelo) == Paleta.CORES[2]["cor"])
	Racas.aplicar(modelo, "oni")
	menu._pintar()
	for i in 3: await process_frame
	_ok("as peças do Oni NÃO seguem a cor",
		_cor_da_peca_raca(modelo) != Paleta.CORES[2]["cor"])
	Racas.remover(modelo)
	menu._cor_idx = 1
	menu._pintar()

	# ---------- corpo: os olhos ----------
	print("\n--- olhos ---")
	Racas.remover(modelo)
	_ok("os três tamanhos estão no catálogo", Corpo.ids().size() == 3)
	_ok("começa sem olhos", Corpo.atual(modelo) == "")
	var largs: Dictionary = {}
	for id in Corpo.ids():
		Corpo.aplicar(modelo, id)
		for i in 3: await process_frame
		_ok("%s foi aplicado" % id, Corpo.atual(modelo) == id)
		_ok("%s cria 4 peças (2 olhos + 2 pupilas)" % id, _contar_marca(modelo, Corpo.MARCA) == 4)
		largs[id] = _larg_olho(modelo)
	print("   largura do branco do olho: pequeno %.4f | médio %.4f | grande %.4f" % [
		largs["olho_pequeno"], largs["olho_medio"], largs["olho_grande"]])
	_ok("pequeno < médio < grande", largs["olho_pequeno"] < largs["olho_medio"]
		and largs["olho_medio"] < largs["olho_grande"])
	_ok("trocar de tamanho não empilha", _contar_marca(modelo, Corpo.MARCA) == 4)

	# os três eixos são independentes
	print("\n--- os eixos não se atropelam ---")
	Racas.aplicar(modelo, "oni")
	Acessorios.equipar(modelo, "chapeu_palha")
	Corpo.aplicar(modelo, "olho_grande")
	for i in 4: await process_frame
	_ok("raça + acessório + olhos convivem",
		Racas.atual(modelo) == "oni" and Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha"
		and Corpo.atual(modelo) == "olho_grande")
	Corpo.aplicar(modelo, "olho_pequeno")
	for i in 3: await process_frame
	_ok("trocar o olho NÃO tira a raça", Racas.atual(modelo) == "oni")
	_ok("trocar o olho NÃO tira o chapéu",
		Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha")
	Racas.remover(modelo); Corpo.remover(modelo); Acessorios.desequipar(modelo, "cabeca")

	# ---------- o giro é por arrasto, não automático ----------
	print("\n--- giro ---")
	_ok("o menu não roda `_process` (sem giro automático)", not menu.is_processing())
	var y0: float = modelo.rotation.y
	var apertar := InputEventMouseButton.new()
	apertar.button_index = MOUSE_BUTTON_LEFT
	apertar.pressed = true
	menu._ao_arrastar(apertar)
	var mover := InputEventMouseMotion.new()
	mover.relative = Vector2(100, 0)
	menu._ao_arrastar(mover)
	_ok("arrastar com o botão apertado GIRA", absf(modelo.rotation.y - y0) > 0.5)
	apertar.pressed = false
	menu._ao_arrastar(apertar)
	var y1: float = modelo.rotation.y
	menu._ao_arrastar(mover)
	_ok("mover SEM apertar não gira", is_equal_approx(modelo.rotation.y, y1))

	# ---------- captura ----------
	menu._selecionar_categoria("acessorios")
	for i in 25: await process_frame
	get_root().get_texture().get_image().save_png("%s/menu_acessorios.png" % saida)
	menu._selecionar_categoria("raca")
	for i in 20: await process_frame
	get_root().get_texture().get_image().save_png("%s/menu_raca.png" % saida)
	Corpo.aplicar(menu._modelo, "olho_grande")
	menu._selecionar_categoria("corpo")
	for i in 20: await process_frame
	get_root().get_texture().get_image().save_png("%s/menu_corpo.png" % saida)
	menu._selecionar_categoria("cor")
	for i in 20: await process_frame
	get_root().get_texture().get_image().save_png("%s/menu_cor.png" % saida)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])

func _contar_acessorios(modelo: Node) -> int:
	var n := 0
	for x in _todos(modelo):
		if String(x.name).begins_with(Acessorios.MARCA):
			n += 1
	return n

func _pai_do_acessorio(modelo: Node, parte: String, id: String) -> String:
	var no := modelo.find_child(Acessorios._prefixo(parte) + id, true, false)
	if no == null:
		return ""
	var pai: Node = no.get_parent()
	return String(pai.name) if pai else ""

func _fracao(modelo: Node) -> float:
	var no := modelo.find_child(Acessorios._prefixo("cabeca") + "chapeu_palha_0", true, false) as Node3D
	if no == null:
		return -1.0
	var cab := no.get_parent() as Node3D
	var a := Acessorios.caixa_do_no(cab)
	return (a.end.y - no.position.y) / a.size.y

## ⚠️ Lê os DOIS tipos. A prévia passou a usar o material do jogo
## (`Materiais.superficie`, um `ShaderMaterial` de cel shading), onde a cor mora
## no parâmetro `cor` e não em `albedo_color`. Ler só `StandardMaterial3D`
## reprovava a mudança certa.
func _cor_do_material(mo: Material) -> Color:
	if mo is StandardMaterial3D:
		return (mo as StandardMaterial3D).albedo_color
	if mo is ShaderMaterial:
		var v = (mo as ShaderMaterial).get_shader_parameter("cor")
		if v != null:
			return v
	return Color(0, 0, 0, 0)

func _cor_de(modelo: Node, nome: String) -> Color:
	for x in _todos(modelo):
		if x.name == nome and x is MeshInstance3D:
			return _cor_do_material((x as MeshInstance3D).material_override)
	return Color(0, 0, 0, 0)

func _acessorio_pintado(modelo: Node) -> bool:
	var no := modelo.find_child(Acessorios._prefixo("cabeca") + "chapeu_palha_0", true, false)
	if no == null:
		return false
	var malhas: Array = []
	FxUtil._collect_meshes(no, malhas)
	for m in malhas:
		if m is MeshInstance3D and (m as MeshInstance3D).material_override != null:
			return true
	return false

## Controles que passam da tela. ⚠️ Ignora o INTERIOR de `ScrollContainer`: ali o
## conteúdo passar da área visível é o comportamento correto, não defeito.
func _fora_da_tela(n: Node, tela: Vector2i, dentro_de_rolagem: bool) -> Array:
	var out: Array = []
	var rolando := dentro_de_rolagem or (n is ScrollContainer)
	if n is Control and not dentro_de_rolagem:
		var c := n as Control
		var r := c.get_global_rect()
		if r.size.x > 0.0 and (r.end.x > tela.x + 1 or r.end.y > tela.y + 1
				or r.position.x < -1 or r.position.y < -1):
			out.append("%s tam(%.0f,%.0f) fim(%.0f,%.0f)" % [
				c.name, r.size.x, r.size.y, r.end.x, r.end.y])
	for f in n.get_children():
		out.append_array(_fora_da_tela(f, tela, rolando))
	return out


func _contar_marca(modelo: Node, marca: String) -> int:
	var n := 0
	for x in _todos(modelo):
		if String(x.name).begins_with(marca):
			n += 1
	return n

func _larg_olho(modelo: Node) -> float:
	for x in _todos(modelo):
		if String(x.name).begins_with(Corpo.MARCA) and x is MeshInstance3D:
			var mm := (x as MeshInstance3D).mesh
			if mm is BoxMesh:
				return (mm as BoxMesh).size.x
	return 0.0

func _contar_racas(modelo: Node) -> int:
	var n := 0
	for x in _todos(modelo):
		if String(x.name).begins_with(Racas.MARCA):
			n += 1
	return n

func _tem_escala_mudada(modelo: Node) -> bool:
	for x in _todos(modelo):
		if x is Node3D and (x as Node3D).has_meta(Racas.META_ESCALA):
			return true
	return false

func _cor_da_peca_raca(modelo: Node) -> Color:
	for x in _todos(modelo):
		if String(x.name).begins_with(Racas.MARCA) and x is MeshInstance3D:
			return _cor_do_material((x as MeshInstance3D).material_override)
	return Color(0, 0, 0, 0)

func _todos(n: Node) -> Array:
	var o: Array = [n]
	for f in n.get_children(): o.append_array(_todos(f))
	return o
