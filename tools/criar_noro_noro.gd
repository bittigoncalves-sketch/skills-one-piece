extends SceneTree
# ============================================================================
#  NORO NORO NO MI — feita NO Skills Builder (06/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_noro_noro.gd [-- <pasta>]
#
#  Pedido do dono: "construindo uma nova fruta a noro noro no mi que permite
#  desacelerar qualquer ser atingido pelo raio por 3 segundos, apenas a skill Z o
#  inimigo fica 5 vezes mais lento, criar pose de carregamento do ataque pose para
#  segurar o ataque, pose para soltar o ataque e pose final, intercalar animações entre
#  as poses e fazer a vfx para tal."
#
#  Este script OPERA O EDITOR (o mesmo caminho dos cliques): "Criar fruta", seção
#  Poses (Nova + juntas), campos das seções, blocos da timeline e "Publicar". O que
#  sai é o que o dono veria fazendo à mão. Rodar de novo refaz e republica a skill.
#  Sem pasta: publica no PROJETO (res://mapas/skills). Com pasta: publica nela (teste).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTA_NOME := "Noro Noro no Mi"
const FRUTA_COR := "#ff7ad9"
const SKILL_ID := "noro_noro_beam"

## As quatro poses (graus por junta; +X no braço = para a FRENTE, convenção do rig).
const POSES := [
	# Carregar: baixo e TORCIDO para trás, mãos juntas na altura da barriga (junta fótons).
	["Carregar", {"Torso": [10, 35, 0], "Head": [-6, -28, 0],
		"UpperArm_L": [20, 0, -10], "ForeArm_L": [80, 0, 0], "UpperArm_R": [15, 0, 10], "ForeArm_R": [85, 0, 0],
		"Thigh_L": [35, 0, 0], "Shin_L": [-55, 0, 0], "Thigh_R": [-12, 0, 0], "Shin_R": [-38, 0, 0]}],
	# Segurar: de frente, COMPACTO e tenso, mãos na frente do peito (o pulso vibra).
	["Segurar", {"Torso": [14, 5, 0], "Head": [-10, -4, 0],
		"UpperArm_L": [60, 0, -18], "ForeArm_L": [48, 0, 0], "UpperArm_R": [60, 0, 18], "ForeArm_R": [48, 0, 0],
		"Thigh_L": [38, 0, 0], "Shin_L": [-58, 0, 0], "Thigh_R": [-22, 0, 0], "Shin_R": [-40, 0, 0]}],
	# Soltar: braços TODO esticados para a frente, avanço com a perna da frente.
	["Soltar", {"Torso": [18, 0, 0], "Head": [-12, 0, 0],
		"UpperArm_L": [92, 0, -8], "ForeArm_L": [5, 0, 0], "UpperArm_R": [92, 0, 8], "ForeArm_R": [5, 0, 0],
		"Thigh_L": [45, 0, 0], "Shin_L": [-30, 0, 0], "Thigh_R": [-30, 0, 0], "Shin_R": [-10, 0, 0]}],
	# Final: recupera — braços baixando à frente, tronco volta, pernas fecham.
	["Final", {"Torso": [6, -8, 0], "Head": [0, 5, 0],
		"UpperArm_L": [40, 0, -12], "ForeArm_L": [35, 0, 0], "UpperArm_R": [30, 0, 12], "ForeArm_R": [25, 0, 0],
		"Thigh_L": [15, 0, 0], "Shin_L": [-15, 0, 0], "Thigh_R": [-8, 0, 0], "Shin_R": [-8, 0, 0]}],
]

## Linha do tempo (s). O jogo PÁRA em PONTO_SEGURAR enquanto a tecla está apertada.
const PONTO_SEGURAR := 0.45
const DURACAO := 1.6
const COMPRIMENTO := 12.0
const ALTURA_DAS_MAOS := 1.3

var ed: Node


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		SkillsPublicadas.pasta_forcada = args[0]
		SkillsPublicadas.recarregar()
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	ed = current_scene
	ed.pasta_skills = "user://skills_builder"

	# 1. Identificação e a fruta.
	ed._mostrar_secao("identificacao")
	await _quadros(2)
	_editar("identificacao", "id", SKILL_ID)
	_editar("identificacao", "nome", "Noro Noro Beam")
	_editar("identificacao", "descricao", "Raio de fótons cintilantes: quem é atingido fica 5× mais lento por 3 s (movimento e ações). Segure para carregar; solte para disparar.")
	_editar("identificacao", "dono", "Jogador")
	var fid := SkillsPublicadas.id_de_nome(FRUTA_NOME)
	if SkillsPublicadas.fruta(fid).is_empty():
		ed._construir_inspector()
		await _quadros(2)
		(ed.find_child("NomeDaNovaFruta", true, false) as LineEdit).text = FRUTA_NOME
		(ed.find_child("CorDaNovaFruta", true, false) as ColorPickerButton).color = Color(FRUTA_COR)
		(ed.find_child("CriarFruta", true, false) as Button).pressed.emit()
		await _quadros(3)
	_editar("identificacao", "fruta", fid)

	# 2. Configurações, ativação, dano e cor.
	_editar("configuracoes", "duracao", DURACAO)
	_editar("configuracoes", "recarga", 8.0)
	_editar("configuracoes", "custo", 25.0)
	_editar("configuracoes", "alcance", COMPRIMENTO)
	_editar("ativacao", "tecla", "Z")
	_editar("ativacao", "modo", "Carregar e soltar")
	_editar("ativacao", "ponto_segurar", PONTO_SEGURAR)
	_editar("ativacao", "segurar_max", 4.0)
	_editar("dano", "valor", 0.0)            # o raio NÃO fere: só deixa lento (como no anime)
	_editar("dano", "empurrao", 0.0)
	_editar("dano", "atordoamento", 0.0)
	_editar("dano", "lentidao", 80.0)         # 5× mais lento
	_editar("dano", "duracao_efeito", 3.0)    # por 3 s
	_editar("condicoes", "exige_alvo", false)
	_editar("vfx", "cor", FRUTA_COR)

	# 3. As poses, pelo editor de poses.
	var novo: Dictionary = ed.skill.duplicate(true)
	novo.poses = []
	novo.eventos = []
	ed._aplicar_edicao(novo, false)
	ed._mostrar_secao("poses")
	await _quadros(2)
	var ids: Array[String] = []
	for par in POSES:
		(ed.find_child("NovaPose", true, false) as Button).pressed.emit()
		await _quadros(3)
		var nome_campo := ed.find_child("NomeDaPose", true, false) as LineEdit
		nome_campo.text = par[0]
		ed._poses.renomear(par[0])
		var ossos: Dictionary = par[1]
		for papel in ossos:
			for k in 3:
				if float(ossos[papel][k]) != 0.0:
					var spin := ed.find_child("%s_%s" % [papel, ["x", "y", "z"][k]], true, false) as SpinBox
					spin.value = float(ossos[papel][k])
		await _quadros(2)
		ids.append(str(ed._poses.sel))

	# 4. A timeline: poses encadeadas, VFX, hitbox do feixe, som, câmera e recuo.
	var ev: Array = [
		_e("pose_carregar", "animacao", 0.0, 0.45, {"pose": ids[0], "transicao": 0.15}),
		_e("pose_segurar", "animacao", 0.40, 0.30, {"pose": ids[1], "transicao": 0.12, "pulso": 0.6}),
		_e("pose_soltar", "animacao", 0.70, 0.45, {"pose": ids[2], "transicao": 0.06}),
		_e("pose_final", "animacao", 1.15, 0.45, {"pose": ids[3], "transicao": 0.25}),
		_e("vfx_carga", "vfx", 0.0, 0.72, {"estilo": "Carga", "altura": ALTURA_DAS_MAOS, "frente": 0.45, "escala": 1.0}),
		_e("vfx_feixe", "vfx", 0.70, 0.55, {"estilo": "Feixe", "altura": ALTURA_DAS_MAOS, "frente": 0.55, "comprimento": COMPRIMENTO, "escala": 1.0}),
		_e("vfx_fotons", "vfx", 0.70, 0.60, {"estilo": "Fótons", "altura": ALTURA_DAS_MAOS, "frente": 0.6, "escala": 0.8}),
		_e("feixe", "hitbox", 0.75, 0.40, {"forma": "Caixa", "largura": 1.2, "altura": 1.4, "profundidade": COMPRIMENTO,
			"x": 0.0, "y": ALTURA_DAS_MAOS, "z": -(0.55 + COMPRIMENTO * 0.5), "unicos": true}),
		_e("som_carga", "audio", 0.0, 0.45, {"som": "Vento", "volume": -14.0, "tom": 0.6}),
		_e("som_disparo", "audio", 0.70, 0.30, {"som": "Disparo", "volume": -8.0, "tom": 1.35}),
		_e("tremor", "camera", 0.70, 0.25, {"tremor": 0.18}),
		_e("recuo", "movimento", 0.70, 0.15, {"direcao": "Trás", "velocidade": 2.0, "distancia": 0.3, "curva": "Suave"}),
	]
	novo = ed.skill.duplicate(true)
	novo.eventos = ev
	if not ed._aplicar_edicao(novo, false):
		push_error("timeline recusada: " + str(Dados.validar(novo).erros))
		quit(1)
		return

	# 5. Publicar (o botão do editor).
	(ed.find_child("Publicar", true, false) as Button).pressed.emit()
	await _quadros(3)
	var aviso: Label = ed.get("_status")
	print("NORO: ", aviso.text)
	var ok := not KitDoBuilder.skill("Z", fid).is_empty()
	print("NORO publicada na fruta %s: %s" % [fid, ok])
	quit(0 if ok else 1)


func _editar(secao: String, chave: String, valor: Variant) -> void:
	var novo: Dictionary = ed.skill.duplicate(true)
	novo[secao][chave] = valor
	if not ed._aplicar_edicao(novo, false):
		push_error("campo recusado %s.%s = %s" % [secao, chave, str(valor)])


func _e(id: String, tipo: String, inicio: float, duracao: float, p: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": p}


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
