extends SceneTree
# ============================================================================
#  MOKU MOKU NO MI REFEITA NO SKILLS BUILDER (11/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_moku_moku.gd [-- <pasta>]
#
#  OPERA O EDITOR (o mesmo caminho dos cliques): "Criar fruta" / campos das seções,
#  blocos da timeline e "Publicar".
#  Constrói e publica as técnicas:
#    - Z: Investida de Fumaça (moku_white_dash_z)
#    - X: Punho de Fumaça (moku_white_blow_x)
#    - C: Vórtice de Fumaça (moku_white_whirlwind_c)
#    - V: Tempestade de Fumaça (moku_white_out_v)
#    - F: Voo de Fumaça (moku_white_flight_f)
#
#  Sem pasta: publica no PROJETO (res://mapas/skills). Com pasta: na pasta (teste).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTA_NOME := "Moku Moku no Mi"
const FRUTA_ID := "moku_moku"
const COR_FUMACA := "#dcdde1"
const COR_SECUNDARIA := "#8395a7"

var ed: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		SkillsPublicadas.pasta_forcada = args[0]
		SkillsPublicadas.recarregar()

	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	ed = current_scene
	ed.pasta_skills = "user://skills_builder"

	# Garante que a fruta existe no catálogo
	if SkillsPublicadas.fruta(FRUTA_ID).is_empty():
		ed._mostrar_secao("identificacao")
		await _quadros(2)
		ed._construir_inspector()
		await _quadros(2)
		var txt_nome := ed.find_child("NomeDaNovaFruta", true, false) as LineEdit
		var cp_cor := ed.find_child("CorDaNovaFruta", true, false) as ColorPickerButton
		var btn_criar := ed.find_child("CriarFruta", true, false) as Button
		if txt_nome != null and cp_cor != null and btn_criar != null:
			txt_nome.text = FRUTA_NOME
			cp_cor.color = Color(COR_FUMACA)
			btn_criar.pressed.emit()
			await _quadros(3)

	var skills := [
		_def_z(),
		_def_x(),
		_def_c(),
		_def_v(),
		_def_f()
	]

	var ok_todas := true
	for s in skills:
		var ok := await _construir_e_publicar(s)
		if not ok:
			ok_todas = false
			push_error("Falha ao publicar skill: %s" % s.id)

	print("\nRESULTADO MOKU MOKU NO MI NO BUILDER: %s" % ("SUCESSO" if ok_todas else "FALHA"))
	quit(0 if ok_todas else 1)


func _def_z() -> Dictionary:
	return {
		"id": "moku_white_dash_z",
		"nome": "Investida de Fumaça",
		"descricao": "Converte a parte inferior do corpo em um jato de fumaça densa e dispara velozmente à frente, atravessando a área e colidindo com o oponente.",
		"tecla": "Z",
		"modo": "Pressionar",
		"duracao": 0.7,
		"recarga": 3.5,
		"custo": 10.0,
		"alcance": 14.0,
		"flutuar": true,
		"parar_no_vazio": true,
		"inicio_do_fim": 0.45,
		"fim_sobre_alvo": 3.0,
		"dano": 85.0,
		"empurrao": 5.5,
		"atordoamento": 0.25,
		"lentidao": 20.0,
		"duracao_efeito": 1.5,
		"tipo_dano": "Vento",
		"eventos": [
			_e("anim_arrancada", "animacao", 0.0, 0.65, {"clipe": "sprint", "intensidade": 1.0, "velocidade": 1.2}),
			_e("vfx_partida", "vfx", 0.0, 0.4, {"estilo": "Vento", "altura": 0.5, "frente": 0.2, "escala": 1.5, "cor": COR_FUMACA}),
			_e("som_vento", "audio", 0.0, 0.5, {"som": "Vento", "tom": 1.1, "volume": -8.0}),
			_e("arrancada", "movimento", 0.05, 0.4, {"direcao": "Frente", "distancia": 8.5, "velocidade": 22.0, "curva": "Suave", "inclinacao": 0.0, "angulo": 0.0, "so_do_chao": false, "teleporte": false}),
			_e("vfx_rastro", "vfx", 0.05, 0.45, {"estilo": "Cometa", "escala": 1.3, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
			_e("hitbox_colisao", "hitbox", 0.08, 0.38, {"forma": "Caixa", "largura": 2.2, "altura": 2.0, "profundidade": 3.0, "x": 0.0, "y": 1.0, "z": -1.5, "unicos": true}),
			_e("vfx_impacto", "vfx", 0.42, 0.25, {"estilo": "Impacto", "escala": 1.4, "frente": 1.2, "altura": 1.0, "cor": COR_FUMACA}),
			_e("som_impacto", "audio", 0.42, 0.25, {"som": "Impacto", "tom": 0.95, "volume": -9.0}),
			_e("tremor_cam", "camera", 0.42, 0.2, {"tremor": 0.25, "zoom": 40.0})
		]
	}


func _def_x() -> Dictionary:
	return {
		"id": "moku_white_blow_x",
		"nome": "Punho de Fumaça",
		"descricao": "Dispara o punho envolto em fumaça densa em alta velocidade na direção mirada, gerando uma explosão de vapor cinzento ao colidir.",
		"tecla": "X",
		"modo": "Pressionar",
		"duracao": 0.9,
		"recarga": 4.5,
		"custo": 14.0,
		"alcance": 28.0,
		"flutuar": false,
		"dano": 140.0,
		"empurrao": 4.0,
		"atordoamento": 0.2,
		"lentidao": 0.0,
		"duracao_efeito": 1.0,
		"tipo_dano": "Vento",
		"eventos": [
			_e("anim_soco", "animacao", 0.0, 0.8, {"clipe": "punching", "intensidade": 1.0, "velocidade": 1.1}),
			_e("som_disparo", "audio", 0.08, 0.3, {"som": "Disparo", "tom": 1.05, "volume": -8.0}),
			_e("vfx_anel_disparo", "vfx", 0.08, 0.35, {"estilo": "Anel", "escala": 1.2, "frente": 1.0, "altura": 1.2, "cor": COR_FUMACA}),
			_e("tiro_fumaca", "projetil", 0.1, 0.75, {
				"velocidade": 26.0, "raio": 0.45, "quantidade": 1, "abertura": 20.0, "gravidade": 0.0,
				"vida": 2.5, "perfurar": false, "visual": "Bala de canhão", "rastro": "Fumaça",
				"direcao_disparo": "Mira", "explosao": 2.8, "som_explosao": "Impacto", "sem_dano": false
			}),
			_e("vfx_fumaca_mao", "vfx", 0.1, 0.4, {"estilo": "Vento", "escala": 0.9, "na_mao": true, "cor": COR_FUMACA})
		]
	}


func _def_c() -> Dictionary:
	return {
		"id": "moku_white_whirlwind_c",
		"nome": "Vórtice de Fumaça",
		"descricao": "Gera um turbilhão giratório de fumaça que suga e atordoa os oponentes na área, aplicando forte lentidão e dano contínuo.",
		"tecla": "C",
		"modo": "Pressionar",
		"duracao": 1.8,
		"recarga": 7.0,
		"custo": 22.0,
		"alcance": 12.0,
		"flutuar": false,
		"dano": 185.0,
		"empurrao": 2.0,
		"atordoamento": 0.4,
		"lentidao": 60.0,
		"duracao_efeito": 3.0,
		"tipo_dano": "Vento",
		"eventos": [
			_e("anim_giro", "animacao", 0.0, 1.6, {"clipe": "chapa_giratoria_2", "intensidade": 1.0, "velocidade": 1.0}),
			_e("som_vento_inicio", "audio", 0.0, 0.8, {"som": "Vento", "tom": 0.9, "volume": -6.0}),
			_e("vfx_tornado", "vfx", 0.1, 1.5, {"estilo": "Tornado", "escala": 2.4, "frente": 1.5, "altura": 1.0, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
			_e("som_vento_continuo", "audio", 0.6, 0.9, {"som": "Vento", "tom": 1.1, "volume": -7.0}),
			_e("hitbox_vortice_1", "hitbox", 0.2, 0.6, {"forma": "Esfera", "largura": 3.0, "altura": 3.0, "profundidade": 3.0, "raio": 3.5, "x": 0.0, "y": 1.0, "z": -1.5, "unicos": true}),
			_e("hitbox_vortice_2", "hitbox", 0.8, 0.7, {"forma": "Esfera", "largura": 3.0, "altura": 3.0, "profundidade": 3.0, "raio": 3.8, "x": 0.0, "y": 1.0, "z": -1.5, "unicos": true}),
			_e("tremor_giro", "camera", 0.2, 0.5, {"tremor": 0.15, "zoom": 40.0})
		]
	}


func _def_v() -> Dictionary:
	return {
		"id": "moku_white_out_v",
		"nome": "Tempestade de Fumaça",
		"descricao": "Libera uma colossal massa de fumaça sob extrema pressão ao redor do usuário, gerando uma detonação em 360 graus que arremessa e causa dano massivo.",
		"tecla": "V",
		"modo": "Pressionar",
		"duracao": 2.0,
		"recarga": 12.0,
		"custo": 32.0,
		"alcance": 16.0,
		"flutuar": false,
		"dano": 280.0,
		"empurrao": 8.5,
		"atordoamento": 0.5,
		"lentidao": 30.0,
		"duracao_efeito": 2.0,
		"tipo_dano": "Vento",
		"eventos": [
			_e("anim_carga", "animacao", 0.0, 0.45, {"clipe": "bouncing_fight_idle", "intensidade": 1.0, "velocidade": 1.0}),
			_e("vfx_carga", "vfx", 0.0, 0.4, {"estilo": "Carga", "escala": 1.5, "altura": 1.0, "frente": 0.0, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
			_e("anim_impacto", "animacao", 0.4, 1.5, {"clipe": "smash", "intensidade": 1.0, "velocidade": 1.2}),
			_e("som_impacto_massivo", "audio", 0.42, 0.7, {"som": "Impacto", "tom": 0.8, "volume": -5.0}),
			_e("vfx_explosao_fumaca", "vfx", 0.42, 1.2, {"estilo": "Explosão", "escala": 4.5, "altura": 1.0, "frente": 0.0, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
			_e("vfx_anel_onda", "vfx", 0.45, 0.8, {"estilo": "Anel", "escala": 5.0, "altura": 0.5, "frente": 0.0, "cor": COR_FUMACA}),
			_e("som_vento_onda", "audio", 0.45, 0.8, {"som": "Vento", "tom": 0.85, "volume": -6.0}),
			_e("hitbox_onda_360", "hitbox", 0.44, 0.6, {"forma": "Esfera", "largura": 3.0, "altura": 3.0, "profundidade": 3.0, "raio": 5.8, "x": 0.0, "y": 1.0, "z": 0.0, "unicos": true}),
			_e("tremor_impacto", "camera", 0.42, 0.6, {"tremor": 0.6, "zoom": 40.0})
		]
	}


func _def_f() -> Dictionary:
	var eventos_f: Array = [
		_e("impulso_inicial", "movimento", 0.0, 0.05, {"direcao": "Acima", "distancia": 1.5, "velocidade": 100.0, "teleporte": true, "so_do_chao": true}),
		_e("vfx_decolagem", "vfx", 0.0, 0.35, {"estilo": "Vento", "altura": 0.4, "frente": 0.0, "escala": 1.6, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
		_e("som_decolagem", "audio", 0.0, 0.4, {"som": "Vento", "tom": 1.2, "volume": -6.0}),
		_e("corpo_fumaca_rastro", "vfx", 0.0, 6.0, {"estilo": "Cometa", "altura": 0.8, "frente": 0.0, "escala": 1.3, "cor": COR_FUMACA, "cor_2": COR_SECUNDARIA}),
		_e("voo_direcional", "movimento", 0.05, 5.95, {"direcao": "Mira", "distancia": 100.0, "velocidade": 28.0, "curva": "Linear"})
	]
	for k in 6:
		eventos_f.append(_e("som_voo_%d" % (k + 1), "audio", 0.05 + k * 0.99, 0.95, {"som": "Vento", "tom": 1.05, "volume": -8.0}))

	return {
		"id": "moku_white_flight_f",
		"nome": "Voo de Fumaça",
		"descricao": "Converte o corpo em fumaça densa e voa livremente na direção da mira (28 m/s, até 6 s). Solte para parar. Consome energia continuamente durante o voo.",
		"tecla": "F",
		"modo": "Sustentar",
		"duracao": 6.0,
		"recarga": 4.0,
		"custo": 2.0,
		"custo_por_segundo": 5.0,
		"alcance": 10.0,
		"flutuar": true,
		"dano": 0.0,
		"empurrao": 0.0,
		"atordoamento": 0.0,
		"lentidao": 0.0,
		"duracao_efeito": 1.0,
		"tipo_dano": "Vento",
		"eventos": eventos_f
	}


func _construir_e_publicar(d: Dictionary) -> bool:
	ed._documento(Dados.novo())
	await _quadros(2)
	ed._mostrar_secao("identificacao")
	await _quadros(2)

	_editar("identificacao", "id", d.id)
	_editar("identificacao", "nome", d.nome)
	_editar("identificacao", "descricao", d.descricao)
	_editar("identificacao", "dono", "Jogador")
	_editar("identificacao", "fruta", FRUTA_ID)

	var limpa: Dictionary = ed.skill.duplicate(true)
	limpa.poses = []
	limpa.eventos = []
	ed._aplicar_edicao(limpa, false)

	_editar("configuracoes", "duracao", float(d.duracao))
	_editar("configuracoes", "recarga", float(d.recarga))
	_editar("configuracoes", "custo", float(d.custo))
	_editar("configuracoes", "alcance", float(d.alcance))
	_editar("configuracoes", "flutuar", bool(d.get("flutuar", false)))
	_editar("configuracoes", "mirar_no_alvo", false)
	_editar("configuracoes", "intervalo_depois", 0.5)

	if d.has("custo_por_segundo"):
		_editar("configuracoes", "custo_por_segundo", float(d.custo_por_segundo))
	if d.has("parar_no_vazio"):
		_editar("configuracoes", "parar_no_vazio", bool(d.parar_no_vazio))
	if d.has("inicio_do_fim"):
		_editar("configuracoes", "inicio_do_fim", float(d.inicio_do_fim))
	if d.has("fim_sobre_alvo"):
		_editar("configuracoes", "fim_sobre_alvo", float(d.fim_sobre_alvo))

	_editar("ativacao", "tecla", d.tecla)
	_editar("ativacao", "modo", d.modo)

	_editar("dano", "valor", float(d.dano))
	_editar("dano", "tipo", str(d.tipo_dano))
	_editar("dano", "empurrao", float(d.empurrao))
	_editar("dano", "atordoamento", float(d.atordoamento))
	_editar("dano", "lentidao", float(d.lentidao))
	_editar("dano", "duracao_efeito", float(d.duracao_efeito))

	_editar("condicoes", "exige_alvo", false)
	_editar("vfx", "cor", COR_FUMACA)
	_editar("vfx", "cor_2", COR_SECUNDARIA)

	var novo: Dictionary = ed.skill.duplicate(true)
	novo.eventos = d.eventos
	if not ed._aplicar_edicao(novo, false):
		push_error("%s: timeline recusada: %s" % [d.id, str(Dados.validar(novo).erros)])
		return false

	(ed.find_child("Publicar", true, false) as Button).pressed.emit()
	await _quadros(3)
	print("MOKU %s [%s]: %s" % [d.nome, d.tecla, (ed.get("_status") as Label).text])
	return str(KitDoBuilder.skill(d.tecla, FRUTA_ID).get("identificacao", {}).get("id", "")) == d.id


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
