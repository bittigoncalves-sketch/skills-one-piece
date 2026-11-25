extends SceneTree
# ============================================================================
#  FRUTAS "(MINE PIECE)" — feitas com o Skills Builder (17/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_mine_piece.gd [-- <pasta>]
#
#  Pedido do dono: levar para o jogo (singleplayer e Modo História) os golpes do mod
#  Mine Piece v14 estudados na biblioteca de mecânicas. Decisão do dono (17/10/2026):
#  FRUTAS NOVAS "(Mine Piece)" no catálogo, sem mexer nos kits atuais da Pika, Hie, Moku
#  e Nikyu. Fichas: ~/dev/biblioteca-de-mecanicas/fichas/poder/*-mine-piece.md.
#  Referência e rascunhos de origem: docs/referencias/mine_piece/.
#
#  Só o DESENHO dos golpes vem do mod (fases, carga, alcance, quem acerta); nenhum
#  código, som ou textura. Números em escala da ARENA (a história multiplica por
#  ESCALA_DA_ARENA = 250/2048); âncora de dano: Laser 1 do mod (17) = Raio de Luz (98).
#
#  Rodar de novo refaz e republica. Sem pasta: publica no PROJETO (res://mapas/skills).
#  Com pasta: publica nela (teste).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTAS := {
	"pika": {"nome": "Pika Pika no Mi (Mine Piece)", "cor": "#ffd23f"},
	"hie": {"nome": "Hie Hie no Mi (Mine Piece)", "cor": "#9fe8ff"},
	"moku": {"nome": "Moku Moku no Mi (Mine Piece)", "cor": "#dcdde1"},
	"nikyu": {"nome": "Nikyu Nikyu no Mi (Mine Piece)", "cor": "#ff8fb8"},
}

var _falhas := 0


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		SkillsPublicadas.pasta_forcada = args[0]
		SkillsPublicadas.recarregar()
	var ids := {}
	for chave in FRUTAS:
		var nome: String = FRUTAS[chave].nome
		var fid := SkillsPublicadas.id_de_nome(nome)
		if SkillsPublicadas.fruta(fid).is_empty():
			var r := SkillsPublicadas.criar_fruta(nome, FRUTAS[chave].cor)
			if not r.ok:
				push_error("criar fruta %s: %s" % [nome, str(r.erros)])
				quit(1)
				return
		ids[chave] = fid
	var skills := [
		_pika_laser_pesado(ids.pika), _pika_velocidade_e_poder(ids.pika), _pika_chute_de_luz(ids.pika),
		_hie_bola_de_gelo(ids.hie), _hie_bico_de_faisao(ids.hie), _hie_campo_de_estacas(ids.hie),
		_moku_cipo_branco(ids.moku),
		_nikyu_tapa_de_pata(ids.nikyu), _nikyu_soco_do_urso(ids.nikyu), _nikyu_choque_do_urso(ids.nikyu),
	]
	for s in skills:
		var p := SkillsPublicadas.publicar(s)
		print("%s %s %s" % ["OK  " if p.ok else "ERRO", s.identificacao.id, str(p.get("erros", []))])
		if not p.ok:
			_falhas += 1
	quit(1 if _falhas > 0 else 0)


# ---------------------------------------------------------------- blocos

func _base(fid: String, id: String, nome: String, desc: String, tecla: String, cor: String, cor_2 := "#ffffff") -> Dictionary:
	var s := Dados.novo()
	s.eventos = []
	s.identificacao.merge({"id": id, "nome": nome, "descricao": desc, "dono": "Jogador", "fruta": fid}, true)
	s.ativacao.merge({"modo": "Pressionar", "tecla": tecla, "paralisar_segurando": true}, true)
	s.condicoes.merge({"exige_alvo": false, "distancia_maxima": 60.0}, true)
	s.vfx.merge({"cor": cor, "cor_2": cor_2}, true)
	s.animacao.merge({"clipe": "Ataque", "pose": ""}, true)
	return s


func _carregar(s: Dictionary, carga: float, ponto: float) -> void:
	s.ativacao.merge({"modo": "Carregar e soltar", "carga": carga, "ponto_segurar": ponto,
		"segurar_max": 4.0, "empurrao_carga_max": 1.5}, true)


func _pose(id: String, nome: String, ossos: Dictionary) -> Dictionary:
	return {"id": id, "nome": nome, "ossos": ossos}


func _ev(tipo: String, id: String, inicio: float, duracao: float, parametros: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": parametros}


func _pose_ev(id: String, inicio: float, duracao: float, pose: String, transicao := 0.1) -> Dictionary:
	return _ev("animacao", id, inicio, duracao, {"pose": pose, "transicao": transicao})


func _clipe_ev(id: String, inicio: float, duracao: float, clipe: String, velocidade := 1.0) -> Dictionary:
	return _ev("animacao", id, inicio, duracao, {"clipe": clipe, "pose": "", "velocidade": velocidade})


func _som(id: String, inicio: float, som: String, tom: float, volume := -6.0) -> Dictionary:
	return _ev("audio", id, inicio, 0.3, {"som": som, "tom": tom, "volume": volume})


func _tremor(id: String, inicio: float, duracao: float, forca: float) -> Dictionary:
	return _ev("camera", id, inicio, duracao, {"tremor": forca})


## Esfera de acerto à frente do ator (z negativo = frente).
func _acerto(id: String, inicio: float, duracao: float, diametro: float, frente: float, unicos := true) -> Dictionary:
	return _ev("hitbox", id, inicio, duracao, {"forma": "Esfera", "raio": diametro * 0.5, "largura": diametro,
		"altura": diametro, "profundidade": diametro, "x": 0.0, "y": 1.0, "z": -frente, "unicos": unicos,
		"mirar": false, "na_mao": false})


# Poses de braço estendido (reaproveitadas): um braço apontando, os dois empurrando.
const OSSOS_APONTAR := {"ForeArm_L": [38.0, 0.0, 0.0], "ForeArm_R": [4.0, 0.0, 0.0], "Head": [-4.0, 12.0, 0.0],
	"Shin_L": [-22.0, 0.0, 0.0], "Shin_R": [-12.0, 0.0, 0.0], "Thigh_L": [22.0, 0.0, 0.0], "Thigh_R": [-10.0, 0.0, 0.0],
	"Torso": [8.0, -18.0, 0.0], "UpperArm_L": [18.0, 0.0, -12.0], "UpperArm_R": [88.0, 0.0, 6.0]}
const OSSOS_RECOLHER := {"UpperArm_R": [-50.0, 0.0, 14.0], "ForeArm_R": [105.0, 0.0, 0.0], "UpperArm_L": [-45.0, 0.0, -14.0],
	"ForeArm_L": [105.0, 0.0, 0.0], "Torso": [-6.0, 0.0, 0.0], "Thigh_L": [26.0, 0.0, -10.0], "Shin_L": [-44.0, 0.0, 0.0],
	"Thigh_R": [-14.0, 0.0, 10.0], "Shin_R": [-30.0, 0.0, 0.0]}
const OSSOS_EMPURRAR := {"UpperArm_R": [92.0, 0.0, 10.0], "ForeArm_R": [4.0, 0.0, 0.0], "UpperArm_L": [92.0, 0.0, -10.0],
	"ForeArm_L": [4.0, 0.0, 0.0], "Torso": [16.0, 0.0, 0.0], "Thigh_L": [40.0, 0.0, -6.0], "Shin_L": [-50.0, 0.0, 0.0],
	"Thigh_R": [-26.0, 0.0, 6.0], "Shin_R": [-16.0, 0.0, 0.0]}
const OSSOS_ERGUER := {"UpperArm_R": [-10.0, 0.0, 150.0], "ForeArm_R": [20.0, 0.0, 0.0], "UpperArm_L": [-10.0, 0.0, -150.0],
	"ForeArm_L": [20.0, 0.0, 0.0], "Torso": [-12.0, 0.0, 0.0], "Head": [-14.0, 0.0, 0.0], "Thigh_L": [18.0, 0.0, -14.0],
	"Shin_L": [-30.0, 0.0, 0.0], "Thigh_R": [18.0, 0.0, 14.0], "Shin_R": [-30.0, 0.0, 0.0]}
const OSSOS_BATER_NO_CHAO := {"UpperArm_R": [70.0, 0.0, 20.0], "ForeArm_R": [10.0, 0.0, 0.0], "UpperArm_L": [70.0, 0.0, -20.0],
	"ForeArm_L": [10.0, 0.0, 0.0], "Torso": [42.0, 0.0, 0.0], "Head": [10.0, 0.0, 0.0], "Thigh_L": [70.0, 0.0, -10.0],
	"Shin_L": [-100.0, 0.0, 0.0], "Thigh_R": [-10.0, 0.0, 10.0], "Shin_R": [-60.0, 0.0, 0.0]}


# ================================================================ PIKA PIKA (Mine Piece)

## Z — Laser 2 do mod: preparo longo, raio instantâneo e explosão onde parar.
func _pika_laser_pesado(fid: String) -> Dictionary:
	var s := _base(fid, "mp_pika_laser_pesado", "Raio de Luz Pesado",
		"Segure: a luz se concentra na mão por até 1,5 s. Solte: um raio grosso e instantâneo até a mira (40 m) que explode onde para; a carga cheia dá 1,5× de impulso.",
		"Z", "#ffd23f", "#fff1b8")
	_carregar(s, 1.5, 0.6)
	s.configuracoes.merge({"duracao": 1.35, "recarga": 8.0, "custo": 16.0, "alcance": 40.0}, true)
	s.dano.merge({"valor": 138.0, "tipo": "Físico", "empurrao": 4.0, "atordoamento": 0.3}, true)
	s.poses = [_pose("pose_1", "Apontar", OSSOS_APONTAR)]
	s.eventos = [
		_pose_ev("apontar", 0.0, 1.0, "pose_1", 0.12),
		_ev("vfx", "estrela", 0.0, 0.65, {"estilo": "Estrela", "escala": 0.9, "na_mao": true}),
		_ev("vfx", "fotons_carga", 0.0, 0.65, {"estilo": "Fótons", "escala": 0.5, "na_mao": true}),
		_som("som_carga", 0.0, "Luz: carga", 0.8, -8.0),
		_ev("vfx", "raio", 0.65, 0.4, {"estilo": "Feixe", "comprimento": 40.0, "escala": 1.0, "mirar": true, "na_mao": true}),
		_ev("hitbox", "acerto", 0.66, 0.12, {"forma": "Caixa", "largura": 1.6, "altura": 1.6, "profundidade": 40.0,
			"x": 0.0, "y": 1.35, "z": 0.0, "unicos": true, "mirar": true, "na_mao": true}),
		# Escala < 1 = explosão SEM luz (`visual_de_skill._montar_explosao`): com luz, o ponto
		# mirado longe acendia o chão em blocos (capturas de 17/10/2026 com escala 2,4 e 1,6,
		# art_src/validation/mine_piece/pika_Z_2_acerto.png).
		_ev("vfx", "explosao", 0.7, 0.5, {"estilo": "Explosão", "ancora": "Ponto mirado", "escala": 0.95}),
		_som("som_raio", 0.65, "Luz: disparo", 0.8, -3.0),
		_som("som_explosao", 0.72, "Luz: explosão", 0.9, -5.0),
		_tremor("tremor", 0.66, 0.25, 0.18),
	]
	return s


## X — Speed Is Power do mod: some, reaparece colado no alvo e dá dois socos.
func _pika_velocidade_e_poder(fid: String) -> Dictionary:
	var s := _base(fid, "mp_pika_velocidade_e_poder", "Velocidade é Poder",
		"Com um inimigo a até 8 m: o corpo vira luz, reaparece colado nele e dá dois socos, o segundo com onda de impacto.",
		"X", "#ffd23f", "#fff1b8")
	s.configuracoes.merge({"duracao": 1.1, "recarga": 9.0, "custo": 16.0, "alcance": 8.0, "mirar_no_alvo": true}, true)
	s.condicoes.merge({"exige_alvo": true, "distancia_maxima": 8.0}, true)
	s.dano.merge({"valor": 70.0, "tipo": "Físico", "empurrao": 3.0, "atordoamento": 0.35}, true)
	s.eventos = [
		_ev("vfx", "virar_luz", 0.0, 0.25, {"estilo": "Cometa", "escala": 1.0}),
		_som("som_sumir", 0.0, "Luz: teleporte", 1.0, -6.0),
		_ev("movimento", "aparecer", 0.2, 0.05, {"direcao": "Frente", "distancia": 8.0, "velocidade": 100.0, "teleporte": true}),
		_clipe_ev("socos", 0.25, 0.8, "jab_to_elbow_punch", 1.2),
		_acerto("soco_1", 0.38, 0.1, 2.4, 1.0),
		_ev("vfx", "impacto_1", 0.38, 0.25, {"estilo": "Impacto", "escala": 1.0}),
		_som("som_soco_1", 0.38, "Impacto", 1.2, -6.0),
		_acerto("soco_2", 0.7, 0.12, 5.0, 1.5),
		_ev("vfx", "onda", 0.7, 0.4, {"estilo": "Anel", "escala": 2.0}),
		_som("som_soco_2", 0.7, "Luz: impacto", 0.9, -4.0),
		_tremor("tremor", 0.7, 0.2, 0.16),
	]
	return s


## C — Chute do mod: só colado (até 5 m); o corpo vira luz e chuta com explosão.
func _pika_chute_de_luz(fid: String) -> Dictionary:
	var s := _base(fid, "mp_pika_chute_de_luz", "Chute de Luz",
		"Só com inimigo a até 5 m: o corpo vira luz, cola nele e solta um chute que explode em luz e o arremessa.",
		"C", "#ffd23f", "#fff1b8")
	s.configuracoes.merge({"duracao": 0.85, "recarga": 6.0, "custo": 10.0, "alcance": 5.0, "mirar_no_alvo": true}, true)
	s.condicoes.merge({"exige_alvo": true, "distancia_maxima": 5.0}, true)
	s.dano.merge({"valor": 98.0, "tipo": "Físico", "empurrao": 14.0, "atordoamento": 0.4}, true)
	s.eventos = [
		_ev("vfx", "virar_luz", 0.0, 0.12, {"estilo": "Cometa", "escala": 0.9}),
		_ev("movimento", "colar", 0.08, 0.05, {"direcao": "Frente", "distancia": 5.0, "velocidade": 100.0, "teleporte": true}),
		_clipe_ev("chute", 0.12, 0.7, "flying_kick", 1.3),
		_acerto("acerto_chute", 0.32, 0.12, 3.0, 1.2),
		_ev("vfx", "explosao", 0.32, 0.4, {"estilo": "Explosão", "escala": 1.4}),
		_som("som_chute", 0.32, "Luz: impacto", 1.1, -4.0),
		_tremor("tremor", 0.32, 0.2, 0.14),
	]
	return s


# ================================================================ HIE HIE (Mine Piece)

## Z — Ice Ball do mod: rajadas de bolas de gelo que congelam.
func _hie_bola_de_gelo(fid: String) -> Dictionary:
	var s := _base(fid, "mp_hie_bola_de_gelo", "Chuva de Bolas de Gelo",
		"Junta as mãos e solta três rajadas de bolas de gelo em leque; cada uma estoura e congela quem acerta por 0,7 s.",
		"Z", "#9fe8ff", "#e8fbff")
	s.configuracoes.merge({"duracao": 1.05, "recarga": 7.0, "custo": 14.0, "alcance": 30.0}, true)
	s.dano.merge({"valor": 22.0, "tipo": "Gelo", "empurrao": 1.0, "atordoamento": 0.1, "congelar": 0.7}, true)
	s.projeteis.merge({"visual": "Bolha", "raio": 0.35, "velocidade": 30.0, "vida": 1.0, "quantidade": 5,
		"abertura": 28.0, "gravidade": 0.0, "rastro": "Gelo", "sai_de": "Entre as mãos", "explosao": 1.2,
		"som_explosao": "Gelo: rajada", "imunidade_gelo": false}, true)
	s.poses = [_pose("pose_1", "Recolher", OSSOS_RECOLHER), _pose("pose_2", "Empurrar", OSSOS_EMPURRAR)]
	s.eventos = [
		_pose_ev("recolher", 0.0, 0.25, "pose_1", 0.1),
		_ev("vfx", "frio", 0.0, 0.3, {"estilo": "Vento", "escala": 0.8}),
		_pose_ev("empurrar", 0.25, 0.75, "pose_2", 0.06),
	]
	for i in 3:
		var t := 0.3 + 0.2 * i
		s.eventos.append(_ev("projetil", "rajada_%d" % i, t, 0.05, {}))
		s.eventos.append(_som("som_%d" % i, t, "Gelo: disparo", 1.0 + 0.1 * i, -7.0))
		s.eventos.append(_tremor("tremor_%d" % i, t, 0.1, 0.06))
	return s


## X — Pheasant Beak do mod: um bico de gelo enorme empurrado à frente.
func _hie_bico_de_faisao(fid: String) -> Dictionary:
	var s := _base(fid, "mp_hie_bico_de_faisao", "Bico de Faisão",
		"Segure para o gelo crescer entre as mãos (até 1,2 s); solte e um bico de gelo enorme avança, atravessando e congelando quem tocar.",
		"X", "#9fe8ff", "#e8fbff")
	_carregar(s, 1.2, 0.4)
	s.configuracoes.merge({"duracao": 1.2, "recarga": 9.0, "custo": 16.0, "alcance": 26.0}, true)
	s.dano.merge({"valor": 120.0, "tipo": "Gelo", "empurrao": 8.0, "atordoamento": 0.3, "congelar": 0.7}, true)
	s.projeteis.merge({"visual": "Estaca de gelo", "raio": 1.5, "raio_de_acerto": 1.0, "velocidade": 20.0, "vida": 1.3,
		"quantidade": 1, "abertura": 0.0, "gravidade": 0.0, "rastro": "Gelo", "sai_de": "Entre as mãos",
		"perfurar": true, "imunidade_gelo": true}, true)
	s.poses = [_pose("pose_1", "Recolher", OSSOS_RECOLHER), _pose("pose_2", "Empurrar", OSSOS_EMPURRAR)]
	s.eventos = [
		_pose_ev("recolher", 0.0, 0.4, "pose_1", 0.15),
		_ev("vfx", "gelo_cresce", 0.0, 0.45, {"estilo": "Carga", "ancora": "Osso do jogador", "osso": "Mão direita", "escala": 1.4}),
		_som("som_carga", 0.0, "Gelo: rajada", 0.6, -10.0),
		_pose_ev("empurrar", 0.4, 0.6, "pose_2", 0.05),
		_ev("projetil", "bico", 0.45, 0.05, {}),
		_som("som_bico", 0.45, "Gelo: disparo", 0.6, -3.0),
		_tremor("tremor", 0.45, 0.25, 0.18),
	]
	return s


## C — Ice Spikes do mod: o chão racha em volta do ponto mirado e chovem estacas.
func _hie_campo_de_estacas(fid: String) -> Dictionary:
	var s := _base(fid, "mp_hie_campo_de_estacas", "Campo de Estacas",
		"Bate as mãos no chão: o solo racha no ponto mirado e uma chuva de estacas de gelo cai num círculo de 6 m em volta dele, congelando.",
		"C", "#9fe8ff", "#e8fbff")
	s.configuracoes.merge({"duracao": 1.5, "recarga": 12.0, "custo": 22.0, "alcance": 28.0}, true)
	s.dano.merge({"valor": 30.0, "tipo": "Gelo", "empurrao": 1.5, "atordoamento": 0.15, "congelar": 0.7}, true)
	s.projeteis.merge({"visual": "Estaca de gelo", "raio": 0.4, "velocidade": 26.0, "vida": 2.0, "quantidade": 8,
		"abertura": 0.0, "gravidade": 20.0, "rastro": "Gelo", "direcao_disparo": "Chuva", "area_chuva": 6.0,
		"explosao": 1.0, "som_explosao": "Gelo: rajada", "imunidade_gelo": false}, true)
	s.poses = [_pose("pose_1", "Erguer", OSSOS_ERGUER), _pose("pose_2", "Bater no chão", OSSOS_BATER_NO_CHAO)]
	s.eventos = [
		_pose_ev("erguer", 0.0, 0.3, "pose_1", 0.12),
		_pose_ev("bater", 0.3, 0.9, "pose_2", 0.06),
		_ev("vfx", "rachadura", 0.32, 1.0, {"estilo": "Rachadura", "ancora": "Ponto mirado", "escala": 4.0}),
		_som("som_bater", 0.3, "Impacto", 0.6, -5.0),
		_tremor("tremor", 0.3, 0.3, 0.2),
		_ev("projetil", "estacas_1", 0.4, 0.05, {}),
		_ev("projetil", "estacas_2", 0.65, 0.05, {}),
		_som("som_estacas", 0.4, "Gelo: disparo", 0.7, -6.0),
	]
	return s


# ================================================================ MOKU MOKU (Mine Piece)

## Z — White Vine do mod: corte em arco de fumaça e um redemoinho que avança.
func _moku_cipo_branco(fid: String) -> Dictionary:
	var s := _base(fid, "mp_moku_cipo_branco", "Cipó Branco",
		"Gira o braço num arco de fumaça que corta em volta e solta à frente um redemoinho que atravessa os inimigos.",
		"Z", "#f4f6f8", "#ffffff")
	s.configuracoes.merge({"duracao": 1.25, "recarga": 7.0, "custo": 18.0, "alcance": 20.0}, true)
	s.dano.merge({"valor": 60.0, "tipo": "Vento", "empurrao": 5.0, "atordoamento": 0.3, "lentidao": 40.0, "duracao_efeito": 1.0}, true)
	# Acerto menor que o desenho: a esfera de 1,2 m nascendo a 1 m do chão encostava no piso e
	# cravava no cenário logo na saída (medido 17/10/2026: o redemoinho ficava parado).
	s.projeteis.merge({"visual": "Energia", "raio": 1.0, "raio_de_acerto": 0.7, "velocidade": 14.0, "vida": 1.4, "quantidade": 1,
		"abertura": 0.0, "gravidade": 0.0, "rastro": "Fumaça", "perfurar": true}, true)
	s.eventos = [
		_clipe_ev("giro", 0.0, 0.9, "roundhouse_kick", 1.1),
		_ev("vfx", "arco", 0.2, 0.4, {"estilo": "Vento", "escala": 1.8}),
		_ev("hitbox", "corte", 0.25, 0.15, {"forma": "Caixa", "largura": 6.0, "altura": 2.0, "profundidade": 3.5,
			"x": 0.0, "y": 1.0, "z": -1.5, "unicos": true, "mirar": false, "na_mao": false}),
		_som("som_corte", 0.25, "Vento", 1.2, -6.0),
		_ev("projetil", "redemoinho", 0.45, 0.05, {}),
		# Sem o VFX "Tornado" preso ao projétil: na captura de 17/10/2026 ele cobria a Rajada
		# (branca, aditiva) com uma bola escura listrada.
		_som("som_redemoinho", 0.45, "Vento", 0.7, -5.0),
		_tremor("tremor", 0.25, 0.15, 0.1),
	]
	return s


# ================================================================ NIKYU NIKYU (Mine Piece)

## Z — Pad Ho do mod: tapa de pata enorme, de curto alcance.
func _nikyu_tapa_de_pata(fid: String) -> Dictionary:
	var s := _base(fid, "mp_nikyu_tapa_de_pata", "Tapa de Pata",
		"Segure para a pata crescer na palma (até 1 s); solte e um tapa de pata enorme varre a frente e arremessa.",
		"Z", "#ff8fb8", "#ffffff")
	_carregar(s, 1.0, 0.35)
	s.configuracoes.merge({"duracao": 0.95, "recarga": 6.0, "custo": 12.0, "alcance": 12.0}, true)
	s.dano.merge({"valor": 100.0, "tipo": "Físico", "empurrao": 14.0, "atordoamento": 0.4}, true)
	s.projeteis.merge({"visual": "Pata", "raio": 1.8, "raio_de_acerto": 1.0, "velocidade": 22.0, "vida": 0.55,
		"quantidade": 1, "abertura": 0.0, "gravidade": 0.0, "rastro": "Vento", "sai_de": "Mão direita"}, true)
	s.poses = [_pose("pose_1", "Recolher", OSSOS_RECOLHER), _pose("pose_2", "Tapa", OSSOS_APONTAR)]
	s.eventos = [
		_pose_ev("recolher", 0.0, 0.35, "pose_1", 0.12),
		_ev("vfx", "pata_cresce", 0.0, 0.4, {"estilo": "Carga", "ancora": "Osso do jogador", "osso": "Mão direita", "escala": 1.2}),
		_som("som_carga", 0.0, "Vento", 0.8, -10.0),
		_pose_ev("tapa", 0.35, 0.5, "pose_2", 0.04),
		_ev("projetil", "pata", 0.38, 0.05, {}),
		_som("som_tapa", 0.38, "Disparo", 0.6, -3.0),
		_tremor("tremor", 0.38, 0.2, 0.2),
	]
	return s


## X — Kuma Punch do mod: investe até o alvo e solta uma sequência de socos.
func _nikyu_soco_do_urso(fid: String) -> Dictionary:
	var s := _base(fid, "mp_nikyu_soco_do_urso", "Soco do Urso",
		"Com inimigo a até 10 m: avança até ele, dá um soco forte e emenda uma rajada de socos que racha o chão.",
		"X", "#ff8fb8", "#ffffff")
	s.configuracoes.merge({"duracao": 1.6, "recarga": 9.0, "custo": 18.0, "alcance": 10.0, "mirar_no_alvo": true}, true)
	s.condicoes.merge({"exige_alvo": true, "distancia_maxima": 10.0}, true)
	s.dano.merge({"valor": 40.0, "tipo": "Físico", "empurrao": 2.0, "atordoamento": 0.3}, true)
	s.eventos = [
		_clipe_ev("investir", 0.0, 0.35, "sprint", 1.4),
		_ev("movimento", "avancar", 0.05, 0.3, {"direcao": "Frente", "distancia": 9.0, "velocidade": 30.0}),
		_ev("vfx", "vento", 0.05, 0.3, {"estilo": "Vento", "escala": 0.8}),
		_clipe_ev("socos", 0.35, 1.2, "quad_punch", 1.2),
		_acerto("soco_forte", 0.45, 0.12, 3.0, 1.2),
		_ev("vfx", "impacto_forte", 0.45, 0.3, {"estilo": "Impacto", "escala": 1.6, "frente": 1.3}),
		_som("som_forte", 0.45, "Impacto", 0.7, -4.0),
		_tremor("tremor_forte", 0.45, 0.2, 0.18),
		_acerto("rajada", 0.7, 0.75, 2.4, 1.2, false),
		_ev("vfx", "rachadura", 0.7, 0.8, {"estilo": "Rachadura", "ancora": "Alvo", "escala": 2.2}),
	]
	# Cada soco da rajada com estalo visível e som (captura de 17/10/2026: sem eles a
	# rajada não se lia na tela).
	for i in 4:
		var t := 0.72 + 0.18 * i
		s.eventos.append(_ev("vfx", "impacto_%d" % i, t, 0.16, {"estilo": "Impacto", "escala": 0.9, "frente": 1.2, "altura": 1.0 + 0.25 * (i % 2)}))
		s.eventos.append(_som("som_rajada_%d" % i, t, "Impacto", 1.1 + 0.08 * i, -9.0))
	return s


## C — Ursus Shock do mod: concentra uma pata enorme e solta uma onda de choque em volta.
func _nikyu_choque_do_urso(fid: String) -> Dictionary:
	var s := _base(fid, "mp_nikyu_choque_do_urso", "Choque do Urso",
		"Ergue os braços e concentra o ar numa pata enorme por quase 1 s; ela explode numa onda de choque de 8 m em volta, arremessando.",
		"C", "#ff8fb8", "#ffffff")
	s.configuracoes.merge({"duracao": 1.5, "recarga": 12.0, "custo": 24.0, "alcance": 8.0}, true)
	s.dano.merge({"valor": 140.0, "tipo": "Físico", "empurrao": 18.0, "atordoamento": 0.6}, true)
	s.poses = [_pose("pose_1", "Erguer", OSSOS_ERGUER), _pose("pose_2", "Bater no chão", OSSOS_BATER_NO_CHAO)]
	s.eventos = [
		_pose_ev("erguer", 0.0, 0.85, "pose_1", 0.15),
		_ev("vfx", "pata_concentra", 0.0, 0.85, {"estilo": "Carga", "escala": 2.6, "altura": 3.0, "frente": 0.0}),
		_som("som_concentra", 0.0, "Vento", 0.5, -8.0),
		_pose_ev("bater", 0.85, 0.5, "pose_2", 0.05),
		_ev("hitbox", "onda", 0.9, 0.2, {"forma": "Esfera", "raio": 8.0, "largura": 16.0, "altura": 16.0,
			"profundidade": 16.0, "x": 0.0, "y": 1.0, "z": 0.0, "unicos": true, "mirar": false, "na_mao": false}),
		_ev("vfx", "anel", 0.9, 0.5, {"estilo": "Anel", "escala": 4.0, "altura": 0.1, "frente": 0.0}),
		_ev("vfx", "explosao", 0.9, 0.4, {"estilo": "Explosão", "escala": 2.5, "frente": 0.0}),
		_som("som_onda", 0.9, "Impacto", 0.5, -2.0),
		_tremor("tremor", 0.9, 0.4, 0.3),
	]
	return s
