extends RefCounted
## EDITOR DE POSES do Skills Builder (seção "Poses").
##
## Pedido do dono (06/10/2026): as poses do golpe feitas no próprio Builder. Cada junta
## do rig A tem X/Y/Z em graus; a prévia mostra a pose parada enquanto esta seção está
## aberta. Nos blocos de Animação, a Pose escolhida e a Transição encadeiam as poses.
##
## Saiu do `SkillsBuilder.gd` em 06/10/2026 (teto de 900 linhas do projeto). Escreve na
## skill SÓ pelo `_aplicar_edicao` do editor: desfazer, refazer e validação valem igual.

const Estilo = preload("res://src/skills_builder/estilo_builder.gd")
const Basicas = preload("res://src/skills_builder/poses_basicas.gd")
const NOMES_DAS_JUNTAS := {
	"Torso": "Tronco", "Neck": "Pescoço", "Head": "Cabeça",
	"UpperArm_L": "Braço esquerdo", "ForeArm_L": "Antebraço esquerdo",
	"UpperArm_R": "Braço direito", "ForeArm_R": "Antebraço direito",
	"Thigh_L": "Coxa esquerda", "Shin_L": "Canela esquerda", "Foot_L": "Pé esquerdo",
	"Thigh_R": "Coxa direita", "Shin_R": "Canela direita", "Foot_R": "Pé direito",
}

## A pose aberta (id).
var sel := ""
var ed: Control


func _init(editor: Control) -> void:
	ed = editor


func construir() -> void:
	var inspector: VBoxContainer = ed._inspector
	inspector.add_child(Estilo.rotulo("Poses", 19))
	ed._explicacao("Gire as juntas do personagem; a prévia mostra a pose. Num bloco de Animação, escolha a Pose: blocos seguidos fazem a transição entre elas.")
	var poses: Array = ed.skill.get("poses", [])
	var ids := PosesDeSkill.ids(ed.skill)
	if not sel in ids:
		sel = ids[0] if not ids.is_empty() else ""
	var linha := HBoxContainer.new()
	inspector.add_child(linha)
	var lista := OptionButton.new()
	lista.name = "PoseSelecionada"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p: Dictionary in poses:
		lista.add_item(str(p.nome))
		lista.set_item_metadata(lista.item_count - 1, str(p.id))
		if str(p.id) == sel:
			lista.select(lista.item_count - 1)
	lista.item_selected.connect(_escolher.bind(lista))
	linha.add_child(lista)
	var acoes := HBoxContainer.new()
	inspector.add_child(acoes)
	var nova_b := Estilo.botao("Nova", nova, "Pose nova (parte do repouso)")
	nova_b.name = "NovaPose"
	acoes.add_child(nova_b)
	# Poses básicas (pedido do dono, 07/10/2026): prontas, para usar ou editar.
	var basicas := MenuButton.new()
	basicas.name = "PosesBasicas"
	basicas.text = "Poses básicas"
	basicas.tooltip_text = "Põe na skill uma pose pronta (guarda, socos, chute, braços abertos...)"
	basicas.flat = false
	for i in Basicas.nomes().size():
		basicas.get_popup().add_item(Basicas.nomes()[i], i)
	basicas.get_popup().id_pressed.connect(func(i: int) -> void: adicionar_basica(Basicas.nomes()[i]))
	acoes.add_child(basicas)
	if sel.is_empty():
		ed._explicacao("Nenhuma pose ainda. Clique em Nova.")
		ed.arena.mostrar_pose("")
		return
	for par in [["Duplicar", duplicar, "DuplicarPose"], ["Espelhar", espelhar, "EspelharPose"], ["Apagar", apagar, "ApagarPose"]]:
		var b := Estilo.botao(par[0], par[1])
		b.name = par[2]
		acoes.add_child(b)
	var atual := _pose_dict(sel)
	ed._adicionar_campo({"id": "NomeDaPose", "nome": "Nome", "tipo": "texto"}, atual.nome, renomear)
	for papel: String in PosesDeSkill.PAPEIS:
		var g: Array = (atual.ossos as Dictionary).get(papel, [0, 0, 0])
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 2)
		inspector.add_child(coluna)
		coluna.add_child(Estilo.rotulo(str(NOMES_DAS_JUNTAS.get(papel, papel)), 13, true))
		var eixos := HBoxContainer.new()
		coluna.add_child(eixos)
		for k in 3:
			var spin: SpinBox = ed._numero(-180, 180, 1, float(g[k]))
			spin.name = "%s_%s" % [papel, ["x", "y", "z"][k]]
			spin.custom_minimum_size.x = 72
			spin.prefix = ["X", "Y", "Z"][k]
			spin.value_changed.connect(mudar_junta.bind(papel, k))
			eixos.add_child(spin)
	var zerar_b := Estilo.botao("Zerar pose", zerar)
	zerar_b.name = "ZerarPose"
	inspector.add_child(zerar_b)
	ed.arena.mostrar_pose(sel)


func _pose_dict(id: String) -> Dictionary:
	for p: Dictionary in ed.skill.get("poses", []):
		if str(p.id) == id:
			return p
	return {}


## Aplica `mudar` na pose selecionada (com desfazer/refazer e validação do contrato).
func _mudar(mudar: Callable, reconstruir := false) -> void:
	if ed._atualizando: return
	var novo: Dictionary = ed.skill.duplicate(true)
	for p: Dictionary in novo.get("poses", []):
		if str(p.id) == sel:
			mudar.call(p)
	if ed._aplicar_edicao(novo, false):
		ed.arena.mostrar_pose(sel)
		if reconstruir: ed._construir_inspector.call_deferred()


func _escolher(i: int, lista: OptionButton) -> void:
	sel = str(lista.get_item_metadata(i))
	ed._construir_inspector.call_deferred()


func renomear(v: Variant) -> void:
	var nome := str(v).strip_edges().left(40)
	if not nome.is_empty():
		_mudar(_definir_nome.bind(nome))


static func _definir_nome(p: Dictionary, nome: String) -> void:
	p.nome = nome


func zerar() -> void:
	_mudar(_limpar_ossos)


static func _limpar_ossos(p: Dictionary) -> void:
	p.ossos = {}


func mudar_junta(graus: float, papel: String, eixo: int) -> void:
	_mudar(_definir_junta.bind(papel, eixo, graus))


static func _definir_junta(p: Dictionary, papel: String, eixo: int, graus: float) -> void:
	var antes: Array = (p.ossos as Dictionary).get(papel, [0.0, 0.0, 0.0])
	var g: Array = [float(antes[0]), float(antes[1]), float(antes[2])]   # sempre float, como o JSON relido
	g[eixo] = snappedf(graus, 0.1)
	if g.all(func(v): return absf(float(v)) < 0.001):
		(p.ossos as Dictionary).erase(papel)
	else:
		p.ossos[papel] = g


func _id_livre(base: String) -> String:
	var ids := PosesDeSkill.ids(ed.skill)
	var n := 1
	while ids.has("%s_%d" % [base, n]): n += 1
	return "%s_%d" % [base, n]


func nova(ossos: Dictionary = {}, nome := "") -> void:
	if (ed.skill.get("poses", []) as Array).size() >= PosesDeSkill.MAX_POSES:
		ed._avisar("Limite de %d poses." % PosesDeSkill.MAX_POSES, true)
		return
	var novo: Dictionary = ed.skill.duplicate(true)
	if not novo.has("poses"): novo.poses = []
	var id := _id_livre("pose")
	novo.poses.append({"id": id, "nome": nome if not nome.is_empty() else "Pose %d" % (novo.poses.size() + 1), "ossos": ossos.duplicate(true)})
	if ed._aplicar_edicao(novo, false):
		sel = id
		ed._construir_inspector.call_deferred()


## Uma pose básica entra na skill com o nome dela (e fica aberta para editar).
func adicionar_basica(nome: String) -> void:
	nova(Basicas.ossos(nome), nome)


func duplicar() -> void:
	var atual := _pose_dict(sel)
	nova(atual.get("ossos", {}), (str(atual.get("nome", "Pose")) + " (cópia)").left(40))


## Troca esquerda ↔ direita (e inverte Y/Z), para fazer o lado oposto de uma pose.
func espelhar() -> void:
	_mudar(_espelhar, true)


static func _espelhar(p: Dictionary) -> void:
	var novos := {}
	for papel in p.ossos:
		var g: Array = p.ossos[papel]
		var outro := str(papel).replace("_L", "_X").replace("_R", "_L").replace("_X", "_R")
		novos[outro] = [g[0], -float(g[1]), -float(g[2])]
	p.ossos = novos


func apagar() -> void:
	var novo: Dictionary = ed.skill.duplicate(true)
	novo.poses = (novo.get("poses", []) as Array).filter(func(p): return str(p.id) != sel)
	# Blocos que usavam a pose voltam ao clipe (senão o contrato recusa).
	for e: Dictionary in novo.eventos:
		if e.tipo == "animacao" and str((e.parametros as Dictionary).get("pose", "")) == sel:
			e.parametros.erase("pose")
	if ed._aplicar_edicao(novo, false):
		sel = ""
		ed._construir_inspector.call_deferred()
