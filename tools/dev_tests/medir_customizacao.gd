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
	_ok("há duas categorias à esquerda", cats.size() == 2)
	_ok("uma delas é ACESSÓRIOS", cats.has("acessorios"))
	_ok("a outra é COR", cats.has("cor"))
	_ok("o personagem foi montado no centro", menu._modelo != null and is_instance_valid(menu._modelo))
	_ok("o viewport tem mundo próprio (não mostra a arena)", menu._viewport.own_world_3d)

	var modelo: Node3D = menu._modelo

	# ---------- equipar ----------
	print("\n--- equipar ---")
	_ok("começa sem acessório na cabeça", Acessorios.equipado_na_parte(modelo, "cabeca") == "")
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	_ok("o chapéu foi equipado", Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha")
	_ok("o chapéu está no nó Head", _pai_do_acessorio(modelo, "chapeu_palha") == "Head")
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
	intruso.name = Acessorios.MARCA + "_outro_chapeu"
	cabeca.add_child(intruso)
	for i in 3: await process_frame
	_ok("cenário montado: dois acessórios na cabeça", _contar_acessorios(modelo) == 2)
	Acessorios.equipar(modelo, "chapeu_palha")
	for i in 5: await process_frame
	_ok("equipar na MESMA parte não empilha", _contar_acessorios(modelo) == 1)
	_ok("o intruso saiu sozinho", not is_instance_valid(intruso) or intruso.get_parent() == null)
	_ok("o novo ficou equipado", Acessorios.equipado_na_parte(modelo, "cabeca") == "chapeu_palha")
	Acessorios.desequipar(modelo, "cabeca")

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

	# ---------- captura ----------
	menu._selecionar_categoria("acessorios")
	for i in 25: await process_frame
	get_root().get_texture().get_image().save_png("%s/menu_acessorios.png" % saida)
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

func _pai_do_acessorio(modelo: Node, id: String) -> String:
	var no := modelo.find_child(Acessorios.MARCA + id, true, false)
	if no == null:
		return ""
	var pai: Node = no.get_parent()
	return String(pai.name) if pai else ""

func _fracao(modelo: Node) -> float:
	var no := modelo.find_child(Acessorios.MARCA + "chapeu_palha", true, false) as Node3D
	if no == null:
		return -1.0
	var cab := no.get_parent() as Node3D
	var a := Acessorios.caixa_do_no(cab)
	return (a.end.y - no.position.y) / a.size.y

func _cor_de(modelo: Node, nome: String) -> Color:
	for x in _todos(modelo):
		if x.name == nome and x is MeshInstance3D:
			var mo := (x as MeshInstance3D).material_override
			if mo is StandardMaterial3D:
				return (mo as StandardMaterial3D).albedo_color
	return Color(0, 0, 0, 0)

func _acessorio_pintado(modelo: Node) -> bool:
	var no := modelo.find_child(Acessorios.MARCA + "chapeu_palha", true, false)
	if no == null:
		return false
	var malhas: Array = []
	FxUtil._collect_meshes(no, malhas)
	for m in malhas:
		if m is MeshInstance3D and (m as MeshInstance3D).material_override != null:
			return true
	return false

func _todos(n: Node) -> Array:
	var o: Array = [n]
	for f in n.get_children(): o.append_array(_todos(f))
	return o
