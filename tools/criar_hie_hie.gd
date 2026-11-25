extends SceneTree
# ============================================================================
#  HIE HIE NO MI REFEITA NO SKILLS BUILDER — o Z novo (07/10/2026). Fonte reproduzível.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/criar_hie_hie.gd [-- <pasta>]
#
#  Pedido do dono: "preparar redesenvolvimento da fruta do gelo que existe atualmente,
#  hie hie no mi. todos os golpes irão congelar por 0.7 segundos. deixar o novo teste de
#  skill Z fruta do gelo no lugar do Z antigo e melhorar o teste, no caso o novo Z."
#  Decisões: a `hie_hie` vira fruta reconstruída (Z do Builder; X/C/V do código); a
#  "fruta do gelo" de teste sai do catálogo; o Z mantém a IDEIA do dono (recua disparando
#  três rajadas de estacas de gelo) e ganha acabamento.
#
#  PARTE DO `Z_ice` DO DONO (o publicado) e opera o EDITOR: "Refazer fruta do jogo",
#  campos, poses, timeline, "Publicar na loja" e "Salvar". O rascunho original do dono
#  fica na biblioteca do editor como `Z_ice_original`.
#
#  O QUE MUDOU no Z (e por quê):
#    • dano 15 → 8 por estaca: 24 estacas × 8 = 192, o teto do Z antigo (16 × 12);
#    • cada estaca CONGELA 0,7 s (+ 0,5 s de imunidade: a 1ª salva que pega prende, as
#      outras não prendem de novo em cadeia); 10/10/2026, no Modo História: só a 3ª salva
#      deixa a imunidade, e as anteriores esticam o gelo (a sequência prende até o fim);
#    • custo 10 % → 4,4 % (os 180 da arena) e recarga 2 → 5 s (a do Z antigo);
#    • as estacas saem ENTRE AS MÃOS (a pose do dono estende os dois braços), em leque
#      de 26°, e estouram num jato de gelo ao tocar (raio 0,8 m: o estouro fere e congela);
#    • a cada salva: cristais se juntando nas mãos antes, um tranco dos braços (pose
#      "Disparo") e o estalo cristalino do Z antigo; no recuo, um sopro frio, a geada
#      girando em volta do corpo e um anel de gelo no chão onde ele começou.
#  Sem pasta: publica no PROJETO (res://mapas/skills). Com pasta: na pasta (teste).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const FRUTA := "hie_hie"
const FRUTA_DE_TESTE := "fruta_do_gelo"
const ID := "Z_ice"
const GELO := "#9fe8ff"
const GELO_2 := "#f2fdff"
const SALVAS := [0.4, 0.8, 1.15]          # os tempos do dono

var ed: Node


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		SkillsPublicadas.pasta_forcada = args[0]
		SkillsPublicadas.recarregar()
	var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(SkillsPublicadas.pasta().path_join(ID + ".json")))
	if not original is Dictionary:
		push_error("Z_ice do dono não encontrado em " + SkillsPublicadas.pasta())
		quit(1)
		return
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	ed = current_scene
	# O rascunho original do dono, guardado (uma vez) na biblioteca do editor.
	var guarda := str(ed.pasta_skills).path_join(ID + "_original.json")
	if not FileAccess.file_exists(guarda):
		var copia: Dictionary = (original as Dictionary).duplicate(true)
		copia.identificacao.id = ID + "_original"
		copia.identificacao.nome = str(copia.identificacao.nome) + " (original)"
		var guardada := Dados.salvar(_inteiros(copia), str(ed.pasta_skills))
		print("rascunho original guardado (%s): %s %s" % [guarda, guardada.ok, str(guardada.erros)])
	# A Hie reconstruída (como a Pika): Z do Builder, X/C/V do código.
	if SkillsPublicadas.fruta(FRUTA).is_empty():
		SkillsPublicadas.reconstruir_fruta_da_arena(FRUTA, "Hie Hie no Mi", GELO)
	var novo := _melhorado(_inteiros(original as Dictionary))
	ed._documento(novo)
	await _quadros(3)
	var v := Dados.validar(ed.skill)
	if not v.ok:
		push_error("Z recusado: " + str(v.erros))
		quit(1)
		return
	(ed.find_child("Publicar", true, false) as Button).pressed.emit()
	await _quadros(3)
	print("HIE Z: %s" % (ed.get("_status") as Label).text)
	# "Salvar" sobre um arquivo que já existe pede confirmação; aqui é o "Substituir".
	ed._gravar()
	await _quadros(2)
	print("biblioteca: %s" % (ed.get("_status") as Label).text)
	# A fruta de teste sai do catálogo (e da loja).
	if not SkillsPublicadas.fruta(FRUTA_DE_TESTE).is_empty():
		var r := SkillsPublicadas.apagar_fruta(FRUTA_DE_TESTE)
		print("fruta de teste \"%s\" apagada: %s" % [FRUTA_DE_TESTE, r.ok])
	var ok := str(KitDoBuilder.skill("Z", FRUTA).get("identificacao", {}).get("id", "")) == ID \
		and not KitDoBuilder.pelo_builder(FRUTA, "X") and SkillsPublicadas.fruta(FRUTA_DE_TESTE).is_empty()
	print("HIE refeita no Builder: Z = %s; X/C/V do código; fruta de teste fora: %s" % [ID, ok])
	quit(0 if ok else 1)


## O Z do dono com o acabamento (a ideia dele fica: recua disparando três salvas).
func _melhorado(s: Dictionary) -> Dictionary:
	s.identificacao.nome = "Espinhos de Gelo"
	s.identificacao.descricao = "Recua deslizando no gelo e dispara três salvas de estacas entre as mãos; cada estaca estoura em gelo e congela quem acerta por 0,7 s."
	s.identificacao.fruta = FRUTA
	s.identificacao.dono = "Jogador"
	s.configuracoes.merge({"duracao": 1.5, "recarga": 5.0, "custo": 4.4, "alcance": 30.0, "intervalo_depois": 0.5}, true)
	s.ativacao.merge({"modo": "Pressionar", "tecla": "Z"}, true)
	s.dano.merge({"valor": 8.0, "tipo": "Gelo", "congelar": 0.7, "atordoamento": 0.0, "empurrao": 0.6,
		"critico": 0.0, "lentidao": 0.0}, true)
	s.vfx.merge({"cor": GELO, "cor_2": GELO_2}, true)
	s.condicoes.merge({"exige_alvo": false}, true)
	# As poses do dono: "recuo" (braços estendidos) fica; a "Pose 2" vazia vira o tranco.
	var poses: Array = s.get("poses", [])
	var recuo := "pose_1"
	var disparo := "pose_2"
	for p in poses:
		if str(p.nome) == "Pose 2" or (p.ossos as Dictionary).is_empty():
			p.nome = "Disparo"
			p.ossos = {"Torso": [-6, 0, 0], "UpperArm_L": [96, -8, 0], "UpperArm_R": [96, 8, 0],
				"ForeArm_L": [0, 0, 0], "ForeArm_R": [0, 0, 0], "Thigh_L": [51, 0, 0], "Thigh_R": [21, 0, 0]}
			disparo = str(p.id)
		elif str(p.nome) == "recuo":
			recuo = str(p.id)
	var eventos: Array = []
	eventos.append(_e("recuo", "movimento", 0.0, 1.35, {"direcao": "Trás", "distancia": 8.0, "velocidade": 5.0, "curva": "Suave"}))
	eventos.append(_e("sopro", "audio", 0.0, 0.4, {"som": "Gelo: rajada", "volume": -10.0, "tom": 1.3}))
	eventos.append(_e("anel_no_chao", "vfx", 0.0, 0.9, {"estilo": "Anel", "escala": 1.1, "ancora": "Mundo", "altura": 0.08, "frente": 0.0}))
	eventos.append(_e("geada", "vfx", 0.05, 1.3, {"estilo": "Fótons", "escala": 0.8, "altura": 1.0, "frente": 0.0}))
	# Pose: entra no recuo; em cada salva, o tranco dos braços e volta.
	var t := 0.0
	var k := 0
	for salva in SALVAS:
		eventos.append(_e("pose_recuo_%d" % k, "animacao", t, salva - 0.08 - t, {"pose": recuo, "transicao": 0.08 if k == 0 else 0.1}))
		eventos.append(_e("pose_disparo_%d" % k, "animacao", salva - 0.08, 0.16, {"pose": disparo, "transicao": 0.05}))
		t = salva + 0.08
		k += 1
	eventos.append(_e("pose_fim", "animacao", t, 1.5 - t, {"pose": recuo, "transicao": 0.12}))
	k = 0
	for salva in SALVAS:
		eventos.append(_e("cristais_%d" % k, "vfx", salva - 0.12, 0.16, {"estilo": "Carga", "escala": 0.45, "ancora": "Osso do jogador", "osso": "Mão direita"}))
		eventos.append(_e("cristais_e_%d" % k, "vfx", salva - 0.12, 0.16, {"estilo": "Carga", "escala": 0.45, "ancora": "Osso do jogador", "osso": "Mão esquerda"}))
		eventos.append(_e("salva_%d" % k, "projetil", salva, 0.05, {"quantidade": 8, "abertura": 26.0, "velocidade": 30.0,
			"raio": 0.22, "vida": 1.2, "gravidade": 0.0, "perfurar": false, "visual": "Estaca de gelo", "rastro": "Gelo",
			"direcao_disparo": "Mira", "sai_de": "Entre as mãos", "explosao": 0.8, "som_explosao": "Gelo: disparo",
			# Só a 3ª salva deixa imunidade ao gelo (10/10/2026, Modo História): as duas
			# primeiras prendem e esticam o gelo, a última fecha a sequência.
			"imunidade_gelo": k == SALVAS.size() - 1}))
		eventos.append(_e("estalo_%d" % k, "audio", salva, 0.25, {"som": "Gelo: disparo", "volume": -6.0, "tom": 1.5}))
		eventos.append(_e("tremor_%d" % k, "camera", salva, 0.1, {"tremor": 0.06}))
		k += 1
	s.eventos = eventos
	return s


## JSON lido traz número inteiro como float (8.0); o contrato quer inteiro.
func _inteiros(s: Dictionary) -> Dictionary:
	s.versao = 1
	if s.has("projeteis"):
		s.projeteis.quantidade = int(s.projeteis.get("quantidade", 1))
	if s.has("condicoes"):
		s.condicoes.nivel_minimo = int(s.condicoes.get("nivel_minimo", 1))
	for e in s.get("eventos", []):
		if (e.parametros as Dictionary).has("quantidade"):
			e.parametros.quantidade = int(e.parametros.quantidade)
	return s


func _e(id: String, tipo: String, inicio: float, duracao: float, p: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": p}


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
