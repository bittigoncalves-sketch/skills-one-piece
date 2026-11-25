extends SceneTree
# ============================================================================
#  NIKYU NIKYU NO MI — feita com o Skills Builder (14/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_nikyu_nikyu.gd [-- <pasta>]
#
#  Pedido do dono: Z = uma pata do DOBRO do tamanho do jogador; X = metralhadora de patas
#  em volta do jogador; C = "Dor", pata vermelha que cura o usuário pelo dano; V = pata
#  pequena na mão, em alta velocidade, que explode com grande empurrão.
#
#  Monta as quatro skills com os MESMOS dados que o editor grava (Dados.novo + campos +
#  blocos da timeline + poses) e as publica pela API do editor (`SkillsPublicadas`),
#  que valida tudo. Rodar de novo refaz e republica. Sem pasta: publica no PROJETO
#  (res://mapas/skills). Com pasta: publica nela (teste).
#  Números em escala da ARENA (a história multiplica por ESCALA_DA_ARENA = 250/2048).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTA_NOME := "Nikyu Nikyu no Mi"
const FRUTA_COR := "#ff8fb8"

var _falhas := 0


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		SkillsPublicadas.pasta_forcada = args[0]
		SkillsPublicadas.recarregar()
	var fid := SkillsPublicadas.id_de_nome(FRUTA_NOME)
	if SkillsPublicadas.fruta(fid).is_empty():
		var r := SkillsPublicadas.criar_fruta(FRUTA_NOME, FRUTA_COR)
		if not r.ok:
			push_error("criar fruta: %s" % str(r.erros))
			quit(1)
			return
	for s in [_z(fid), _x(fid), _c(fid), _v(fid)]:
		var p := SkillsPublicadas.publicar(s)
		print("%s %s %s" % ["OK  " if p.ok else "ERRO", s.identificacao.id, str(p.get("erros", []))])
		if not p.ok:
			_falhas += 1
	quit(1 if _falhas > 0 else 0)


# ---------------------------------------------------------------- blocos

func _base(fid: String, id: String, nome: String, desc: String, tecla: String, cor: String) -> Dictionary:
	var s := Dados.novo()
	s.eventos = []
	s.identificacao.merge({"id": id, "nome": nome, "descricao": desc, "dono": "Jogador", "fruta": fid}, true)
	# Segurar a tecla trava o corpo ONDE ESTÁ, gravidade incluída (pedido do dono, 14/10/2026).
	s.ativacao.merge({"modo": "Pressionar", "tecla": tecla, "paralisar_segurando": true}, true)
	s.condicoes.merge({"exige_alvo": false, "distancia_maxima": 60.0}, true)
	s.vfx.merge({"cor": cor, "cor_2": "#ffffff"}, true)
	s.animacao.merge({"clipe": "Ataque", "pose": ""}, true)
	return s


func _pose(id: String, nome: String, ossos: Dictionary) -> Dictionary:
	return {"id": id, "nome": nome, "ossos": ossos}


func _ev(tipo: String, id: String, inicio: float, duracao: float, parametros: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": parametros}


func _pose_ev(id: String, inicio: float, duracao: float, pose: String, transicao := 0.1) -> Dictionary:
	return _ev("animacao", id, inicio, duracao, {"pose": pose, "transicao": transicao})


func _carga_na_mao(id: String, inicio: float, duracao: float, escala: float, osso := "Mão direita") -> Dictionary:
	return _ev("vfx", id, inicio, duracao, {"estilo": "Carga", "ancora": "Osso do jogador", "osso": osso, "escala": escala})


func _som(id: String, inicio: float, som: String, tom: float, volume := -6.0) -> Dictionary:
	return _ev("audio", id, inicio, 0.3, {"som": som, "tom": tom, "volume": volume})


# ---------------------------------------------------------------- as quatro skills

## Z — a pata grande (3,2 m = o dobro do jogador de 1,6 m), lenta e pesada.
func _z(fid: String) -> Dictionary:
	var s := _base(fid, "nikyu_pata_gigante_z", "Pata Gigante",
		"Recua o braço e lança uma pata de pelúcia com o dobro do tamanho do jogador.", "Z", "#ffcfe0")
	s.configuracoes.merge({"duracao": 1.15, "recarga": 6.0, "custo": 14.0, "alcance": 30.0}, true)
	s.dano.merge({"valor": 170.0, "tipo": "Físico", "empurrao": 9.0, "atordoamento": 0.5}, true)
	s.projeteis.merge({"visual": "Pata", "raio": 1.6, "raio_de_acerto": 0.6, "velocidade": 22.0, "vida": 1.5, "quantidade": 1,
		"abertura": 0.0, "gravidade": 0.0, "rastro": "Vento", "sai_de": "Mão direita"}, true)
	s.poses = [
		_pose("pose_1", "Recuo", {"UpperArm_R": [-60.0, 0.0, 12.0], "ForeArm_R": [100.0, 0.0, 0.0],
			"Torso": [4.0, -38.0, 0.0], "UpperArm_L": [35.0, 0.0, -18.0], "ForeArm_L": [60.0, 0.0, 0.0],
			"Thigh_L": [30.0, 0.0, -5.0], "Shin_L": [-40.0, 0.0, 0.0], "Thigh_R": [-18.0, 0.0, 6.0], "Shin_R": [-25.0, 0.0, 0.0]}),
		_pose("pose_2", "Soco", {"UpperArm_R": [95.0, 0.0, 4.0], "ForeArm_R": [4.0, 0.0, 0.0],
			"Torso": [14.0, 32.0, 0.0], "UpperArm_L": [-30.0, 0.0, -22.0], "ForeArm_L": [70.0, 0.0, 0.0],
			"Thigh_L": [42.0, 0.0, -5.0], "Shin_L": [-55.0, 0.0, 0.0], "Thigh_R": [-28.0, 0.0, 6.0], "Shin_R": [-15.0, 0.0, 0.0]}),
		_pose("pose_3", "Recuperar", {"UpperArm_R": [40.0, 0.0, 8.0], "ForeArm_R": [30.0, 0.0, 0.0], "Torso": [6.0, 8.0, 0.0],
			"Thigh_L": [14.0, 0.0, 0.0], "Shin_L": [-14.0, 0.0, 0.0], "Thigh_R": [-8.0, 0.0, 0.0], "Shin_R": [-8.0, 0.0, 0.0]}),
	]
	s.eventos = [
		_pose_ev("recuo", 0.0, 0.5, "pose_1", 0.18),
		_carga_na_mao("pata_cresce", 0.05, 0.5, 1.3),
		_som("som_carga", 0.0, "Vento", 0.7, -12.0),
		_ev("vfx", "anel_no_chao", 0.1, 0.8, {"estilo": "Anel", "ancora": "Mundo", "altura": 0.08, "escala": 1.2}),
		_pose_ev("soco", 0.5, 0.35, "pose_2", 0.05),
		_ev("projetil", "pata", 0.55, 0.05, {}),
		_som("som_soco", 0.55, "Disparo", 0.55, -4.0),
		_ev("camera", "tremor", 0.55, 0.3, {"tremor": 0.28}),
		_pose_ev("fim", 0.85, 0.3, "pose_3", 0.2),
	]
	return s


## X — metralhadora: cinco salvas de oito patas nascendo em volta do jogador.
func _x(fid: String) -> Dictionary:
	var s := _base(fid, "nikyu_metralhadora_x", "Metralhadora de Patas",
		"Conjura patas em volta do corpo e as dispara, em cinco rajadas, para onde o jogador mira.", "X", "#ffd9ea")
	s.configuracoes.merge({"duracao": 1.9, "recarga": 9.0, "custo": 22.0, "alcance": 30.0}, true)
	s.dano.merge({"valor": 9.0, "tipo": "Físico", "empurrao": 2.0, "atordoamento": 0.1}, true)
	s.projeteis.merge({"visual": "Pata", "raio": 0.45, "velocidade": 34.0, "vida": 1.1, "quantidade": 8,
		"abertura": 16.0, "gravidade": 0.0, "rastro": "Vento", "direcao_disparo": "Anel", "raio_do_anel": 2.6}, true)
	s.poses = [
		_pose("pose_1", "Chamar", {"UpperArm_R": [15.0, 0.0, 78.0], "UpperArm_L": [15.0, 0.0, -78.0],
			"ForeArm_R": [30.0, 0.0, 0.0], "ForeArm_L": [30.0, 0.0, 0.0], "Torso": [-8.0, 0.0, 0.0],
			"Thigh_L": [22.0, 0.0, -18.0], "Thigh_R": [22.0, 0.0, 18.0], "Shin_L": [-38.0, 0.0, 0.0], "Shin_R": [-38.0, 0.0, 0.0]}),
		_pose("pose_2", "Metralhar", {"UpperArm_R": [92.0, 0.0, 8.0], "UpperArm_L": [92.0, 0.0, -8.0],
			"ForeArm_R": [6.0, 0.0, 0.0], "ForeArm_L": [6.0, 0.0, 0.0], "Torso": [14.0, 0.0, 0.0],
			"Thigh_L": [30.0, 0.0, -10.0], "Thigh_R": [-12.0, 0.0, 10.0], "Shin_L": [-42.0, 0.0, 0.0], "Shin_R": [-26.0, 0.0, 0.0]}),
	]
	s.eventos = [
		_pose_ev("chamar", 0.0, 0.35, "pose_1", 0.12),
		_ev("vfx", "anel_de_patas", 0.0, 1.1, {"estilo": "Anel", "ancora": "Jogador", "altura": 1.2, "escala": 1.6}),
		_ev("vfx", "brilho_em_volta", 0.05, 1.0, {"estilo": "Fótons", "ancora": "Jogador", "altura": 1.2, "escala": 1.1, "frente": 0.0}),
		_som("som_chamar", 0.0, "Vento", 1.1, -10.0),
	]
	for i in 5:
		var t := 0.4 + 0.2 * i
		s.eventos.append(_pose_ev("metralhar_%d" % i, t - 0.02, 0.17, "pose_2", 0.04))
		s.eventos.append(_ev("projetil", "rajada_%d" % i, t, 0.05, {}))
		s.eventos.append(_som("tiro_%d" % i, t, "Disparo", 1.3 + 0.05 * i, -8.0))
		s.eventos.append(_ev("camera", "tremor_%d" % i, t, 0.12, {"tremor": 0.07}))
	return s


## C — Dor: pata vermelha enorme; o que causa de dano volta como vida.
func _c(fid: String) -> Dictionary:
	var s := _base(fid, "nikyu_dor_c", "Dor",
		"Lança uma grande pata vermelha. Se acertar, o usuário recupera vida em proporção ao dano causado.", "C", "#e0182d")
	s.configuracoes.merge({"duracao": 1.2, "recarga": 10.0, "custo": 20.0, "alcance": 28.0}, true)
	s.dano.merge({"valor": 150.0, "tipo": "Físico", "empurrao": 6.0, "atordoamento": 0.4, "cura_do_dano": 70.0}, true)
	s.projeteis.merge({"visual": "Pata", "raio": 1.3, "raio_de_acerto": 0.8, "velocidade": 19.0, "vida": 1.5, "quantidade": 1,
		"abertura": 0.0, "gravidade": 0.0, "rastro": "Fogo", "sai_de": "Mão esquerda"}, true)
	s.poses = [
		_pose("pose_1", "Puxar", {"UpperArm_L": [-55.0, 0.0, -12.0], "ForeArm_L": [100.0, 0.0, 0.0],
			"Torso": [4.0, 38.0, 0.0], "UpperArm_R": [35.0, 0.0, 18.0], "ForeArm_R": [60.0, 0.0, 0.0],
			"Thigh_R": [30.0, 0.0, 5.0], "Shin_R": [-40.0, 0.0, 0.0], "Thigh_L": [-18.0, 0.0, -6.0], "Shin_L": [-25.0, 0.0, 0.0]}),
		_pose("pose_2", "Dor", {"UpperArm_L": [98.0, 0.0, -4.0], "ForeArm_L": [4.0, 0.0, 0.0],
			"Torso": [14.0, -32.0, 0.0], "UpperArm_R": [-30.0, 0.0, 22.0], "ForeArm_R": [70.0, 0.0, 0.0],
			"Thigh_R": [42.0, 0.0, 5.0], "Shin_R": [-55.0, 0.0, 0.0], "Thigh_L": [-28.0, 0.0, -6.0], "Shin_L": [-15.0, 0.0, 0.0]}),
	]
	s.eventos = [
		_pose_ev("puxar", 0.0, 0.45, "pose_1", 0.15),
		_carga_na_mao("sangue_na_mao", 0.05, 0.45, 1.2, "Mão esquerda"),
		_som("som_puxar", 0.0, "Vento", 0.55, -10.0),
		_pose_ev("dor", 0.45, 0.4, "pose_2", 0.05),
		_ev("projetil", "pata_vermelha", 0.5, 0.05, {}),
		_som("som_dor", 0.5, "Disparo", 0.5, -3.0),
		_ev("camera", "tremor", 0.5, 0.25, {"tremor": 0.22}),
	]
	return s


## V — pata pequena na mão, muito rápida; explode com empurrão enorme.
func _v(fid: String) -> Dictionary:
	var s := _base(fid, "nikyu_repulsao_v", "Repulsão",
		"Forma uma patinha na mão e a dispara em altíssima velocidade; ao acertar, explode e arremessa o inimigo longe.", "V", "#ffe9a8")
	s.configuracoes.merge({"duracao": 1.0, "recarga": 8.0, "custo": 18.0, "alcance": 45.0}, true)
	s.dano.merge({"valor": 140.0, "tipo": "Físico", "empurrao": 30.0, "atordoamento": 0.8}, true)
	s.projeteis.merge({"visual": "Pata", "raio": 0.22, "velocidade": 62.0, "vida": 1.0, "quantidade": 1,
		"abertura": 0.0, "gravidade": 0.0, "rastro": "Faísca", "sai_de": "Mão direita",
		"explosao": 4.6, "som_explosao": "Impacto"}, true)
	s.poses = [
		_pose("pose_1", "Formar", {"UpperArm_R": [55.0, 0.0, 14.0], "ForeArm_R": [70.0, 0.0, 0.0],
			"Torso": [6.0, -10.0, 0.0], "UpperArm_L": [20.0, 0.0, -14.0], "ForeArm_L": [40.0, 0.0, 0.0],
			"Thigh_L": [22.0, 0.0, 0.0], "Shin_L": [-30.0, 0.0, 0.0], "Thigh_R": [-12.0, 0.0, 0.0], "Shin_R": [-18.0, 0.0, 0.0]}),
		_pose("pose_2", "Atirar", {"UpperArm_R": [92.0, 0.0, 2.0], "ForeArm_R": [8.0, 0.0, 0.0],
			"Torso": [10.0, 14.0, 0.0], "UpperArm_L": [-12.0, 0.0, -18.0], "ForeArm_L": [50.0, 0.0, 0.0],
			"Thigh_L": [34.0, 0.0, 0.0], "Shin_L": [-44.0, 0.0, 0.0], "Thigh_R": [-20.0, 0.0, 0.0], "Shin_R": [-14.0, 0.0, 0.0]}),
	]
	s.eventos = [
		_pose_ev("formar", 0.0, 0.4, "pose_1", 0.12),
		_carga_na_mao("patinha", 0.0, 0.4, 0.55),
		_som("som_formar", 0.0, "Vento", 1.4, -12.0),
		_pose_ev("atirar", 0.4, 0.35, "pose_2", 0.04),
		_ev("projetil", "patinha_disparada", 0.42, 0.05, {}),
		_som("som_atirar", 0.42, "Disparo", 1.6, -3.0),
		_ev("camera", "tremor", 0.42, 0.18, {"tremor": 0.14}),
	]
	return s
