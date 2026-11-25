extends SceneTree
# ============================================================================
#  PIKA PIKA NO MI REFEITA NO SKILLS BUILDER (06/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_pika_pika.gd [-- <pasta>]
#
#  Pedido do dono: "iniciar reconstrução da pika pika no mi através do editor com
#  exceção do V; Z para raio único; X para teleportar aéreo [...] e no fim, ao invés
#  de cair, atira uma esfera de luz que explode no chão; C consertar o direcionamento".
#  Decisões dele: o Z/X/C publicados SUBSTITUEM os da `pika_pika` (arena e história); o
#  V segue o código; Z = feixe instantâneo; X = sobe, zigue-zague de luz no ar (o de
#  hoje: esquerda, direita, esquerda, 21 m) e a esfera no fim, sem o mergulho.
#
#  OPERA O EDITOR (o mesmo caminho dos cliques): "Refazer fruta do jogo", seção Poses,
#  campos, blocos da timeline e "Publicar". Números de hoje (Balance): Z 98 (7 × 14),
#  X 160, C 48 por acerto (8 acertos = o teto de 384); recargas 5/7/10 s.
#  Sem pasta: publica no PROJETO (res://mapas/skills). Com pasta: na pasta (teste).
#
#  RODADA 2 (07/10/2026), pedido do dono: Z só dispara ao SOLTAR — segurando, uma
#  estrela de quatro pontas cresce na mão e o empurrão sobe até 1,5× (carga cheia em
#  1,5 s); o raio nasce na mão (mira calibrada). X termina em cima do inimigo que passar
#  perto/embaixo (6 m) e pára antes do vazio. C vira chuva de bolinhas amarelas na área
#  mirada (raio 9 m). 0,5 s entre golpes (o padrão do jogo, escrito em cada skill).
#
#  RODADA 3 (07/10/2026): F = VOO DE LUZ. Segurar F: sobe 1,5 m se estiver no chão, o
#  corpo vira cometa e voa a 30 m/s para onde a câmera aponta (até 6 s); custa 2 % da
#  energia ao apertar e 5 % por segundo; soltar pára e o jogador cai.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTA := "pika_pika"
const COR := "#ffd23f"
## Cintilas e véu do feixe em dourado claro (sem isto, o lilás padrão da Noro).
const COR_2 := "#fff1b8"
## Custo: 180 da arena numa barra de 4096 ≈ 4,4 % (o Builder cobra fração).
const CUSTO := 4.4
const MAOS := 1.35
## C em chuva: dano de cada estouro e quantas ondas (medido no `test_pika_builder`).
const DANO_C := 40.0
const ONDAS_C := 8

## Poses (graus; +X no braço = para a FRENTE, convenção do rig).
const POSES := {
	"Apontar": {"Torso": [8, -18, 0], "Head": [-4, 12, 0],
		"UpperArm_R": [88, 0, 6], "ForeArm_R": [4, 0, 0], "UpperArm_L": [18, 0, -12], "ForeArm_L": [38, 0, 0],
		"Thigh_L": [22, 0, 0], "Shin_L": [-22, 0, 0], "Thigh_R": [-10, 0, 0], "Shin_R": [-12, 0, 0]},
	"Disparo para baixo": {"Torso": [32, 0, 0], "Head": [10, 0, 0],
		"UpperArm_L": [58, 0, -10], "ForeArm_L": [10, 0, 0], "UpperArm_R": [58, 0, 10], "ForeArm_R": [10, 0, 0],
		"Thigh_L": [42, 0, 0], "Shin_L": [-62, 0, 0], "Thigh_R": [22, 0, 0], "Shin_R": [-52, 0, 0]},
	"Pouso": {"Torso": [10, 0, 0], "UpperArm_L": [28, 0, -14], "ForeArm_L": [22, 0, 0],
		"UpperArm_R": [28, 0, 14], "ForeArm_R": [22, 0, 0], "Thigh_L": [18, 0, 0], "Shin_L": [-24, 0, 0],
		"Thigh_R": [10, 0, 0], "Shin_R": [-18, 0, 0]},
	"Barragem": {"Torso": [12, 0, 0], "Head": [6, 0, 0],
		"UpperArm_L": [84, 0, -14], "ForeArm_L": [8, 0, 0], "UpperArm_R": [84, 0, 14], "ForeArm_R": [8, 0, 0],
		"Thigh_L": [26, 0, 0], "Shin_L": [-36, 0, 0], "Thigh_R": [12, 0, 0], "Shin_R": [-30, 0, 0]},
}

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
	var ok := true
	ok = await _skill(_z()) and ok
	ok = await _skill(_x()) and ok
	ok = await _skill(_c()) and ok
	ok = await _skill(_f()) and ok
	var teclas := KitDoBuilder.teclas(FRUTA)
	print("PIKA refeita no Builder: teclas %s; V pelo código: %s" % [str(teclas), not KitDoBuilder.pelo_builder(FRUTA, "V")])
	var quatro := teclas.size() == 4 and teclas.has("Z") and teclas.has("X") and teclas.has("C") and teclas.has("F")
	quit(0 if ok and quatro else 1)


# ------------------------------------------------------------------ as três

## Z: apertar acende a estrela na mão (a timeline espera em 0 s enquanto a tecla está
## apertada); soltar dispara o raio da mão até o retículo. Carga cheia em 1,5 s: o
## empurrão vai de 1× a 1,5×. Segurou 4 s: sai sozinho.
func _z() -> Dictionary:
	return {"id": "pika_raio_z", "nome": "Raio de Luz", "tecla": "Z", "modo": "Carregar e soltar",
		"descricao": "Segure: uma estrela de luz cresce na mão. Solte: um raio só, instantâneo, da mão até a mira (até 40 m); quanto mais carregado, mais forte o empurrão (até 1,5×).",
		"duracao": 0.5, "recarga": 5.0, "alcance": 40.0, "dano": 98.0, "empurrao": 2.0, "atordoamento": 0.15,
		"campos": {"ativacao": {"carga": 1.5, "ponto_segurar": 0.0, "segurar_max": 4.0, "empurrao_carga_max": 1.5,
			"paralisar_segurando": true}},
		"poses": ["Apontar"], "eventos": _eventos_z}


func _eventos_z(ids: Dictionary) -> Array:
	return [
			_e("pose", "animacao", 0.0, 0.5, {"pose": ids["Apontar"], "transicao": 0.08}),
			_e("estrela", "vfx", 0.0, 0.12, {"estilo": "Estrela", "escala": 0.6, "na_mao": true}),
			_e("som_carga", "audio", 0.0, 0.04, {"som": "Luz: carga", "volume": -10.0, "tom": 1.0}),
			_e("raio", "vfx", 0.05, 0.3, {"estilo": "Feixe", "comprimento": 40.0, "escala": 0.5, "mirar": true, "na_mao": true}),
			_e("fotons", "vfx", 0.05, 0.35, {"estilo": "Fótons", "escala": 0.4, "na_mao": true}),
			_e("acerto", "hitbox", 0.06, 0.08, {"forma": "Caixa", "largura": 1.0, "altura": 1.0, "profundidade": 40.0,
				"x": 0.0, "y": MAOS, "z": 0.0, "mirar": true, "unicos": true, "na_mao": true}),
			_e("som", "audio", 0.05, 0.4, {"som": "Luz: disparo", "volume": -6.0, "tom": 1.0}),
			_e("tremor", "camera", 0.05, 0.12, {"tremor": 0.08}),
		]


## X: sobe (só se estiver no chão), vira luz, três pernas do zigue-zague (esquerda,
## direita, esquerda: 7 m para a frente e 5 m de lado cada, 0,17 s) e a esfera para
## baixo que explode no chão (raio 4,5 m, o da explosão de hoje).
func _x() -> Dictionary:
	return {"id": "pika_yata_x", "nome": "Yata no Kagami", "tecla": "X", "modo": "Pressionar", "flutuar": true,
		"descricao": "Sobe, vira luz e cruza o ar em zigue-zague; no fim, atira para baixo uma esfera de luz que explode no chão.",
		"duracao": 1.3, "recarga": 7.0, "alcance": 25.0, "dano": 160.0, "empurrao": 6.0, "atordoamento": 0.3,
		# Termina em cima do inimigo que passar a até 6 m (no plano) e pára antes do vazio;
		# nos dois, a timeline pula para 0,6 s (a carga da esfera).
		"campos": {"configuracoes": {"fim_sobre_alvo": 6.0, "parar_no_vazio": true, "inicio_do_fim": 0.6}},
		"poses": ["Disparo para baixo", "Pouso"], "eventos": _eventos_x}


func _eventos_x(ids: Dictionary) -> Array:
	return [
			_e("sobe", "movimento", 0.0, 0.08, {"direcao": "Acima", "distancia": 6.0, "velocidade": 100.0, "teleporte": true, "so_do_chao": true}),
			_e("som_sobe", "audio", 0.0, 0.3, {"som": "Luz: teleporte", "volume": -8.0, "tom": 1.0}),
			_e("clarao", "vfx", 0.0, 0.12, {"estilo": "Carga", "altura": 1.0, "frente": 0.0, "escala": 0.9}),
			# Escala 0,6: na câmera de ombro, a 3 m, o cometa maior cobria a visão (foto).
			_e("luz", "vfx", 0.1, 0.54, {"estilo": "Cometa", "altura": 0.9, "frente": 0.0, "escala": 0.6}),
			_e("perna_1", "movimento", 0.1, 0.17, {"direcao": "Frente", "distancia": 8.6, "velocidade": 100.0, "angulo": -35.5, "curva": "Linear"}),
			_e("perna_2", "movimento", 0.27, 0.17, {"direcao": "Frente", "distancia": 12.2, "velocidade": 100.0, "angulo": 55.0, "curva": "Linear"}),
			_e("perna_3", "movimento", 0.44, 0.17, {"direcao": "Frente", "distancia": 12.2, "velocidade": 100.0, "angulo": -55.0, "curva": "Linear"}),
			_e("som_viagem", "audio", 0.1, 0.55, {"som": "Luz: viagem", "volume": -8.0, "tom": 1.0}),
			_e("pose_disparo", "animacao", 0.62, 0.4, {"pose": ids["Disparo para baixo"], "transicao": 0.06}),
			_e("carga", "vfx", 0.6, 0.12, {"estilo": "Carga", "altura": 0.6, "frente": 0.6, "escala": 0.7}),
			_e("esfera", "projetil", 0.66, 0.1, {"velocidade": 30.0, "raio": 0.55, "quantidade": 1, "abertura": 0.0, "gravidade": 0.0,
				"vida": 3.0, "perfurar": false, "visual": "Energia", "rastro": "Brilho", "direcao_disparo": "Abaixo",
				"explosao": 4.5, "som_explosao": "Luz: explosão"}),
			_e("som_esfera", "audio", 0.66, 0.3, {"som": "Luz: disparo", "volume": -8.0, "tom": 0.8}),
			_e("tremor", "camera", 0.66, 0.3, {"tremor": 0.15}),
			_e("pose_pouso", "animacao", 1.02, 0.28, {"pose": ids["Pouso"], "transicao": 0.2}),
		]


## C (rodada 2): sobe 7 m e, enquanto a tecla está apertada, despeja uma CHUVA de
## bolinhas amarelas na área mirada: 8 ondas de 14, que sobem em arco e caem espalhadas
## num círculo de 9 m em volta do chão mirado; cada uma estoura (1,6 m) e fere. Soltar
## pára as ondas; as que já saíram caem.
func _c() -> Dictionary:
	return {"id": "pika_yasakani_c", "nome": "Yasakani no Magatama", "tecla": "C", "modo": "Sustentar",
		"flutuar": true, "mirar_no_alvo": false,
		"descricao": "Sobe e, enquanto a tecla estiver apertada, faz chover bolinhas de luz numa área larga em volta da mira; cada uma estoura ao tocar.",
		"duracao": 1.9, "recarga": 10.0, "alcance": 40.0, "dano": DANO_C, "empurrao": 0.5, "atordoamento": 0.15,
		"poses": ["Barragem"], "eventos": _eventos_c}


func _eventos_c(ids: Dictionary) -> Array:
	var lista := [
				_e("sobe", "movimento", 0.0, 0.08, {"direcao": "Acima", "distancia": 7.0, "velocidade": 100.0, "teleporte": true}),
				_e("som_sobe", "audio", 0.0, 0.3, {"som": "Luz: teleporte", "volume": -8.0, "tom": 1.1}),
				_e("pose", "animacao", 0.1, 1.8, {"pose": ids["Barragem"], "transicao": 0.1, "pulso": 0.4}),
				_e("carga", "vfx", 0.1, 1.65, {"estilo": "Carga", "altura": 1.3, "frente": 0.6, "escala": 0.9}),
				_e("som_barragem", "audio", 0.2, 1.0, {"som": "Luz: barragem", "volume": -8.0, "tom": 1.0}),
				_e("som_barragem_2", "audio", 1.0, 0.75, {"som": "Luz: barragem", "volume": -8.0, "tom": 1.05}),
				_e("tremor", "camera", 0.2, 1.55, {"tremor": 0.07}),
			]
	for k in ONDAS_C:
		lista.append(_e("chuva_%d" % (k + 1), "projetil", 0.2 + k * 0.18, 0.1, {"velocidade": 20.0, "raio": 0.18,
			"quantidade": 14, "abertura": 0.0, "gravidade": 30.0, "vida": 2.0, "perfurar": false, "visual": "Energia",
			"rastro": "Brilho", "direcao_disparo": "Chuva", "area_chuva": 9.0, "explosao": 1.6,
			"som_explosao": "Luz: impacto"}))
	return lista


## F (rodada 3): voo de luz. Sustentar: a timeline anda enquanto F está apertado; o
## movimento "Mira" segue a câmera a cada quadro; Cometa esconde o corpo.
func _f() -> Dictionary:
	return {"id": "pika_voo_f", "nome": "Voo de Luz", "tecla": "F", "modo": "Sustentar", "flutuar": true,
		"descricao": "Segure: o corpo vira luz e voa para onde a câmera aponta (30 m/s, até 6 s). Solte para parar. Gasta energia enquanto voa.",
		"duracao": 6.0, "recarga": 4.0, "alcance": 10.0, "dano": 0.0, "empurrao": 0.0, "atordoamento": 0.0,
		"custo": 2.0, "campos": {"configuracoes": {"custo_por_segundo": 5.0}}, "poses": [], "eventos": _eventos_f}


func _eventos_f(_ids: Dictionary) -> Array:
	var lista := [
			_e("sobe", "movimento", 0.0, 0.05, {"direcao": "Acima", "distancia": 1.5, "velocidade": 100.0, "teleporte": true, "so_do_chao": true}),
			_e("clarao", "vfx", 0.0, 0.12, {"estilo": "Carga", "altura": 1.0, "frente": 0.0, "escala": 0.8}),
			_e("luz", "vfx", 0.0, 6.0, {"estilo": "Cometa", "altura": 0.9, "frente": 0.0, "escala": 0.6}),
			_e("voo", "movimento", 0.05, 5.95, {"direcao": "Mira", "velocidade": 30.0, "distancia": 100.0, "curva": "Linear"}),
			_e("som_sobe", "audio", 0.0, 0.3, {"som": "Luz: teleporte", "volume": -8.0, "tom": 1.15}),
		]
	for k in 6:
		lista.append(_e("som_voo_%d" % (k + 1), "audio", 0.05 + k * 0.99, 0.95, {"som": "Luz: viagem", "volume": -10.0, "tom": 1.0}))
	return lista


# ------------------------------------------------------------------ o editor

## Uma skill do zero pelo editor; devolve se publicou na tecla certa da Pika.
func _skill(d: Dictionary) -> bool:
	ed._documento(Dados.novo())
	await _quadros(2)
	ed._mostrar_secao("identificacao")
	await _quadros(2)
	_editar("identificacao", "id", d.id)
	_editar("identificacao", "nome", d.nome)
	_editar("identificacao", "descricao", d.descricao)
	_editar("identificacao", "dono", "Jogador")
	if SkillsPublicadas.fruta(FRUTA).is_empty():
		ed._construir_inspector()
		await _quadros(2)
		var jogo := ed.find_child("FrutaDoJogo", true, false) as OptionButton
		for i in jogo.item_count:
			if str(jogo.get_item_metadata(i)) == FRUTA:
				jogo.select(i)
		(ed.find_child("RefazerFruta", true, false) as Button).pressed.emit()
		await _quadros(3)
	_editar("identificacao", "fruta", FRUTA)
	# Timeline vazia ANTES da duração: os blocos padrão (até 0,9 s) não cabem em 0,5 s.
	var limpa: Dictionary = ed.skill.duplicate(true)
	limpa.poses = []
	limpa.eventos = []
	ed._aplicar_edicao(limpa, false)
	_editar("configuracoes", "duracao", d.duracao)
	_editar("configuracoes", "recarga", d.recarga)
	_editar("configuracoes", "custo", float(d.get("custo", CUSTO)))
	_editar("configuracoes", "alcance", d.alcance)
	_editar("configuracoes", "flutuar", bool(d.get("flutuar", false)))
	_editar("configuracoes", "mirar_no_alvo", bool(d.get("mirar_no_alvo", false)))
	_editar("ativacao", "tecla", d.tecla)
	_editar("ativacao", "modo", d.modo)
	_editar("dano", "valor", d.dano)
	_editar("dano", "empurrao", d.empurrao)
	_editar("dano", "atordoamento", d.atordoamento)
	_editar("configuracoes", "intervalo_depois", 0.5)
	# Campos novos da rodada 2 (seção → campo → valor), pelo mesmo caminho do clique.
	var campos: Dictionary = d.get("campos", {})
	for secao: String in campos:
		for chave: String in campos[secao]:
			_editar(secao, chave, campos[secao][chave])
	_editar("condicoes", "exige_alvo", false)
	_editar("vfx", "cor", COR)
	_editar("vfx", "cor_2", COR_2)
	# Poses pela seção Poses (Nova + juntas), como à mão.
	ed._mostrar_secao("poses")
	await _quadros(2)
	var ids := {}
	for nome: String in d.poses:
		(ed.find_child("NovaPose", true, false) as Button).pressed.emit()
		await _quadros(3)
		(ed.find_child("NomeDaPose", true, false) as LineEdit).text = nome
		ed._poses.renomear(nome)
		var ossos: Dictionary = POSES[nome]
		for papel in ossos:
			for k in 3:
				if float(ossos[papel][k]) != 0.0:
					(ed.find_child("%s_%s" % [papel, ["x", "y", "z"][k]], true, false) as SpinBox).value = float(ossos[papel][k])
		await _quadros(2)
		ids[nome] = str(ed._poses.sel)
	var novo: Dictionary = ed.skill.duplicate(true)
	novo.eventos = (d.eventos as Callable).call(ids)
	if not ed._aplicar_edicao(novo, false):
		push_error("%s: timeline recusada: %s" % [d.id, str(Dados.validar(novo).erros)])
		return false
	(ed.find_child("Publicar", true, false) as Button).pressed.emit()
	await _quadros(3)
	print("PIKA %s [%s]: %s" % [d.nome, d.tecla, (ed.get("_status") as Label).text])
	return str(KitDoBuilder.skill(d.tecla, FRUTA).get("identificacao", {}).get("id", "")) == d.id


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
