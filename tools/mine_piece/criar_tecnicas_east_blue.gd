extends SceneTree
# ============================================================================
#  TÉCNICAS DOS PERSONAGENS DO EAST BLUE (Mine Piece) — skills do Builder (17/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mine_piece/criar_tecnicas_east_blue.gd [-- <pasta>]
#
#  Cada técnica lida no mod (docs/referencias/mine_piece/east_blue/tecnicas.json: dano,
#  alcance, duração, projétil, investida) vira uma skill `mpeb_*` de Usuário "Chefe". Quem
#  as lança é o `CerebroMinePiece` (tabela em mapas/east_blue/personagens.json), com a
#  escala de dano = o multiplicador de força do personagem (fórmula do mod). A animação NÃO
#  está na skill: o cérebro toca o clipe original do modelo (campo `anim` abaixo, gravado em
#  mapas/east_blue/animacoes.json).
#
#  Números na escala da HISTÓRIA (vida do jogador nível 1 = 20, a do Minecraft): o valor é o
#  "Damage" base do mod. Provisório — o dono vai recalibrar.
#  Sem pasta: grava em res://mapas/skills (projeto). Com pasta: nela (teste).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const ANIMACOES := "res://mapas/east_blue/animacoes.json"

var _anims := {}       # skill → {"punho": clipe, "espada": clipe}
var _falhas := 0


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var pasta := "res://mapas/skills"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		pasta = args[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for s in _todas():
		var r: Dictionary = Dados.salvar_em(s, pasta.path_join(str(s.identificacao.id) + ".json"))
		print("%s %s %s" % ["OK  " if r.ok else "ERRO", s.identificacao.id, str(r.get("erros", []))])
		if not r.ok:
			_falhas += 1
	var f := FileAccess.open(ANIMACOES if args.is_empty() else pasta.path_join("animacoes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"formato": "skills-one-piece/east-blue-animacoes", "versao": 1, "skills": _anims}, "\t", true) + "\n")
	f.close()
	quit(1 if _falhas > 0 else 0)


# ---------------------------------------------------------------- blocos

func _base(id: String, nome: String, desc: String, anim_punho: String, anim_espada := "") -> Dictionary:
	var s := Dados.novo()
	s.eventos = []
	s.identificacao.merge({"id": id, "nome": nome, "descricao": "[East Blue · Mine Piece] " + desc,
		"dono": "Chefe", "atribuida_a": "", "fruta": ""}, true)
	s.ativacao.merge({"modo": "Pressionar", "tecla": "Z"}, true)
	s.condicoes.merge({"exige_alvo": false, "distancia_maxima": 64.0}, true)
	s.configuracoes.merge({"recarga": 0.0, "custo": 0.0, "alcance": 64.0, "intervalo_depois": 0.0}, true)
	s.vfx.merge({"cor": "#ffffff", "cor_2": "#ffffff"}, true)
	_anims[id] = {"punho": anim_punho, "espada": anim_espada if not anim_espada.is_empty() else anim_punho}
	return s


func _ev(tipo: String, id: String, inicio: float, duracao: float, p: Dictionary) -> Dictionary:
	return {"id": id, "tipo": tipo, "inicio": inicio, "duracao": duracao, "habilitado": true, "parametros": p}


func _acerto(id: String, t: float, dur: float, diametro: float, frente: float, unicos := true, y := 1.0) -> Dictionary:
	return _ev("hitbox", id, t, dur, {"forma": "Esfera", "raio": diametro * 0.5, "largura": diametro, "altura": diametro,
		"profundidade": diametro, "x": 0.0, "y": y, "z": -frente, "unicos": unicos, "mirar": false, "na_mao": false})


func _vfx(id: String, t: float, dur: float, estilo: String, escala: float, extra := {}) -> Dictionary:
	var p := {"estilo": estilo, "escala": escala}
	p.merge(extra, true)
	return _ev("vfx", id, t, dur, p)


func _som(id: String, t: float, som: String, tom := 1.0, volume := -6.0) -> Dictionary:
	return _ev("audio", id, t, 0.3, {"som": som, "tom": tom, "volume": volume})


func _mov(id: String, t: float, dur: float, distancia: float, velocidade: float, extra := {}) -> Dictionary:
	var p := {"direcao": "Frente", "distancia": distancia, "velocidade": velocidade, "curva": "Suave"}
	p.merge(extra, true)
	return _ev("movimento", id, t, dur, p)


func _tremor(id: String, t: float, dur: float, forca: float) -> Dictionary:
	return _ev("camera", id, t, dur, {"tremor": forca})


func _dano(s: Dictionary, valor: float, empurrao: float, atordoamento := 0.2, tipo := "Físico") -> void:
	s.dano.merge({"valor": valor, "empurrao": empurrao, "atordoamento": atordoamento, "tipo": tipo}, true)


func _projeteis(s: Dictionary, p: Dictionary) -> void:
	s.projeteis.merge({"quantidade": 1, "abertura": 0.0, "gravidade": 0.0, "perfurar": false, "explosao": 0.0,
		"rastro": "Nenhum", "visual": "Energia"}, true)
	s.projeteis.merge(p, true)


## Fecha a skill: a duração cobre o último evento.
func _fim(s: Dictionary) -> Dictionary:
	var fim := 0.2
	for e: Dictionary in s.eventos:
		fim = maxf(fim, float(e.inicio) + float(e.duracao))
	s.configuracoes.duracao = snappedf(fim + 0.05, 0.01)
	return s


# ---------------------------------------------------------------- as técnicas

func _todas() -> Array:
	return [
		_comum_soco(), _comum_corte(), _comum_forte(), _comum_tiro(),
		_ataque_salto(), _ataque_investida(), _ataque_por_cima(), _ataque_veloz(),
		_rankyaku(), _galaxy_divide(), _fresh_fire(), _shakushi(), _cat_the_funjatta(), _krieg_balas(),
		_chute_sete_mil(), _mouton_shoot(), _chute_giratorio(), _concasse(), _uchimizu(),
		_haki_do_rei(), _corte_projetado(), _investida_de_espada(), _griffon_estocada(), _kamusari(),
		_tiro_forte(), _lucky_roux_meteoro(), _lucky_roux_investida(), _narikabura(), _gomu_rocket(),
		_tatsumaki(), _iai(), _sanzen_sekai(), _ashura(),
		_moku_white_blow(), _moku_white_vine(), _moku_white_launcher(), _moku_white_out(),
	]


## WeakAttack / AttackWeakPunch: Damage 9, raio ~3, 10 tiques.
func _comum_soco() -> Dictionary:
	var s := _base("mpeb_comum_soco", "Soco", "Ataque comum: soco curto.", "punch_right")
	_dano(s, 9.0, 2.0, 0.1)
	s.eventos = [_acerto("soco", 0.2, 0.1, 2.4, 1.2), _som("som", 0.2, "Impacto", 1.2, -10.0)]
	return _fim(s)


func _comum_corte() -> Dictionary:
	var s := _base("mpeb_comum_corte", "Corte", "Ataque comum com a arma da mão: corte curto.", "sword_to_right", "sword_to_right")
	_dano(s, 9.0, 2.0, 0.1)
	s.eventos = [_acerto("corte", 0.2, 0.1, 2.8, 1.3), _vfx("arco", 0.18, 0.2, "Vento", 0.6, {"frente": 1.2}),
		_som("som", 0.2, "Vento", 1.4, -10.0)]
	return _fim(s)


## AttackStrongPunch/Sword: Damage 11, empurrão 1,5×, 17 tiques.
func _comum_forte() -> Dictionary:
	var s := _base("mpeb_comum_forte", "Golpe forte", "Ataque comum carregado: golpe que arremessa.", "punch_overhead", "sword_overhead")
	_dano(s, 11.0, 7.0, 0.3)
	s.eventos = [_acerto("forte", 0.45, 0.12, 3.0, 1.5), _vfx("impacto", 0.45, 0.3, "Impacto", 1.2, {"frente": 1.4}),
		_som("som", 0.45, "Impacto", 0.8, -6.0), _tremor("tremor", 0.45, 0.15, 0.1)]
	return _fim(s)


## AttackRifle: bala de Damage 9 (11 no tiro forte), 2,5 tiques.
func _comum_tiro() -> Dictionary:
	var s := _base("mpeb_comum_tiro", "Tiro", "Ataque comum com arma de fogo: um tiro.", "right_arm_front")
	_dano(s, 9.0, 1.5, 0.1)
	_projeteis(s, {"visual": "Bala de canhão", "raio": 0.12, "velocidade": 60.0, "vida": 0.8, "rastro": "Fumaça"})
	s.eventos = [_ev("projetil", "bala", 0.15, 0.05, {}), _som("som", 0.15, "Disparo", 1.4, -6.0)]
	return _fim(s)


## AttackJump → AttackOverhead: salta (6–24 m) e desce golpeando.
func _ataque_salto() -> Dictionary:
	var s := _base("mpeb_ataque_salto", "Salto", "Salta na direção do alvo e desce golpeando.", "head_overhead", "sword_overhead")
	_dano(s, 10.0, 6.0, 0.3)
	s.eventos = [_mov("salto", 0.1, 0.5, 12.0, 26.0, {"inclinacao": 30.0}), _acerto("queda", 0.65, 0.15, 5.0, 1.0),
		_vfx("chao", 0.65, 0.5, "Rachadura", 1.6, {"frente": 1.0}), _som("som", 0.65, "Impacto", 0.7, -5.0),
		_tremor("tremor", 0.65, 0.2, 0.15)]
	return _fim(s)


## AttackTackle: corre e atropela (Damage 8, até 60 tiques).
func _ataque_investida() -> Dictionary:
	var s := _base("mpeb_ataque_investida", "Investida", "Corre na direção do alvo e atropela.", "sprint")
	_dano(s, 8.0, 5.0, 0.3)
	s.eventos = [_mov("corrida", 0.0, 0.7, 16.0, 24.0), _acerto("atropelo", 0.05, 0.7, 2.2, 0.8),
		_vfx("poeira", 0.0, 0.7, "Vento", 0.7), _som("som", 0.05, "Vento", 0.8, -8.0)]
	return _fim(s)


## AttackOverhead: golpe de cima para baixo (Damage 15 no centro, onda 10), 5 tiques.
func _ataque_por_cima() -> Dictionary:
	var s := _base("mpeb_ataque_por_cima", "Golpe por cima", "Golpe de cima para baixo que racha o chão em volta.", "punch_overhead", "sword_overhead")
	_dano(s, 15.0, 6.0, 0.4)
	s.eventos = [_acerto("golpe", 0.3, 0.12, 4.0, 1.5), _vfx("racha", 0.3, 0.6, "Rachadura", 2.0, {"frente": 1.5}),
		_vfx("onda", 0.3, 0.4, "Anel", 1.6, {"frente": 1.5, "altura": 0.1}), _som("som", 0.3, "Impacto", 0.6, -4.0),
		_tremor("tremor", 0.3, 0.25, 0.2)]
	return _fim(s)


## AttackSpeed: some, reaparece colado no alvo e golpeia (AttackStrong: 11).
func _ataque_veloz() -> Dictionary:
	var s := _base("mpeb_ataque_veloz", "Golpe veloz", "Avança num piscar até o alvo e golpeia.", "speed_attack_punch", "speed_attack_sword")
	_dano(s, 11.0, 6.0, 0.3)
	s.configuracoes.mirar_no_alvo = true
	s.configuracoes.alcance = 24.0
	s.eventos = [_vfx("rastro", 0.0, 0.2, "Vento", 0.8), _mov("piscar", 0.15, 0.05, 20.0, 100.0, {"teleporte": true}),
		_acerto("golpe", 0.3, 0.12, 3.0, 1.3), _vfx("impacto", 0.3, 0.3, "Impacto", 1.2, {"frente": 1.3}),
		_som("som", 0.3, "Impacto", 1.0, -5.0)]
	return _fim(s)


## Rankyaku (Coby): chute que solta uma lâmina de vento (PROJECTILE_SLASH, Damage 11).
func _rankyaku() -> Dictionary:
	var s := _base("mpeb_rankyaku", "Rankyaku", "Chuta o ar e solta uma lâmina de vento.", "kick_right")
	_dano(s, 11.0, 4.0, 0.2, "Vento")
	_projeteis(s, {"visual": "Rajada", "raio": 0.9, "raio_de_acerto": 0.6, "velocidade": 30.0, "vida": 1.4, "perfurar": true, "rastro": "Vento"})
	s.eventos = [_ev("projetil", "lamina", 0.2, 0.05, {}), _som("som", 0.2, "Vento", 1.5, -5.0)]
	return _fim(s)


## Galaxy Divide (Coby): avança e dá um soco enorme (Damage 26, raio 20 × tamanho).
func _galaxy_divide() -> Dictionary:
	var s := _base("mpeb_galaxy_divide", "Galaxy Divide", "Concentra força, avança até o alvo e solta um soco que explode.", "punch_right")
	_dano(s, 26.0, 12.0, 0.6)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_vfx("carga", 0.0, 0.8, "Carga", 1.4, {"ancora": "Osso do jogador", "osso": "Mão direita"}),
		_som("som_carga", 0.0, "Vento", 0.6, -8.0), _mov("avanco", 0.8, 0.25, 20.0, 60.0),
		_acerto("soco", 1.05, 0.15, 8.0, 2.0), _vfx("explosao", 1.05, 0.5, "Explosão", 1.5, {"frente": 2.0}),
		_som("som", 1.05, "Impacto", 0.5, -2.0), _tremor("tremor", 1.05, 0.4, 0.35)]
	return _fim(s)


## Fresh Fire (Cabaji): cospe fogo por 1,5 s (Damage 15 em área curta, efeito fogo).
func _fresh_fire() -> Dictionary:
	var s := _base("mpeb_fresh_fire", "Fresh Fire", "Cospe uma labareda à frente por um segundo e meio.", "right_arm_front")
	_dano(s, 5.0, 1.0, 0.05, "Fogo")
	_projeteis(s, {"visual": "Bola de fogo", "raio": 0.35, "velocidade": 16.0, "vida": 0.6, "quantidade": 3, "abertura": 24.0, "rastro": "Fogo"})
	for i in 5:
		s.eventos.append(_ev("projetil", "fogo_%d" % i, 0.1 + 0.28 * i, 0.05, {}))
	s.eventos.append(_som("som", 0.1, "Disparo", 0.6, -6.0))
	return _fim(s)


## Shakushi (Kuro): 6 s de cortes velozes em volta (Damage 12 por acerto, raio 6).
func _shakushi() -> Dictionary:
	var s := _base("mpeb_shakushi", "Shakushi", "Some em velocidade e corta tudo em volta por vários segundos.", "speed_attack_sword", "speed_attack_sword")
	_dano(s, 12.0, 1.0, 0.15)
	s.eventos = [_vfx("sumir", 0.0, 5.6, "Cometa", 0.6)]
	var angulos := [0.0, 120.0, -100.0, 60.0, -150.0, 170.0, -40.0, 90.0, -120.0, 30.0, 140.0]
	for i in angulos.size():
		var t := 0.3 + 0.5 * i
		s.eventos.append(_mov("passo_%d" % i, t, 0.05, 4.0, 100.0, {"angulo": angulos[i], "teleporte": true}))
		s.eventos.append(_acerto("corte_%d" % i, t + 0.05, 0.12, 12.0, 0.0))
		s.eventos.append(_vfx("risco_%d" % i, t + 0.05, 0.25, "Vento", 1.2, {"frente": 0.0}))
		s.eventos.append(_som("som_%d" % i, t + 0.05, "Vento", 1.6 + 0.04 * i, -9.0))
	return _fim(s)


## Cat the Funjatta (Buchi): salta alto e pisa (AttackOverhead).
func _cat_the_funjatta() -> Dictionary:
	var s := _base("mpeb_cat_the_funjatta", "Cat the Funjatta", "Salta bem alto e cai pisando no alvo.", "both_arm_up")
	_dano(s, 15.0, 7.0, 0.5)
	s.eventos = [_mov("sobe", 0.0, 0.35, 6.0, 20.0, {"direcao": "Acima"}), _mov("avanca", 0.35, 0.3, 10.0, 34.0, {"inclinacao": -40.0}),
		_acerto("pisao", 0.7, 0.15, 6.0, 0.5), _vfx("racha", 0.7, 0.6, "Rachadura", 2.4), _som("som", 0.7, "Impacto", 0.5, -3.0),
		_tremor("tremor", 0.7, 0.3, 0.3)]
	return _fim(s)


## Balas do Krieg: rajada de balas (BULLET, Damage 2) por 25 tiques.
func _krieg_balas() -> Dictionary:
	var s := _base("mpeb_krieg_balas", "Balas do Krieg", "Dispara uma rajada de balas da armadura.", "both_arm_front")
	_dano(s, 2.0, 0.5, 0.05)
	_projeteis(s, {"visual": "Bala de canhão", "raio": 0.1, "velocidade": 50.0, "vida": 0.9, "quantidade": 3, "abertura": 30.0, "rastro": "Fumaça"})
	for i in 6:
		s.eventos.append(_ev("projetil", "rajada_%d" % i, 0.1 + 0.2 * i, 0.05, {}))
		s.eventos.append(_som("som_%d" % i, 0.1 + 0.2 * i, "Disparo", 1.3, -8.0))
	return _fim(s)


## Karate 7000 tijolos (Hongo, Building Snake; o do Sanji usa o mesmo): golpe forte (11) que arremessa.
func _chute_sete_mil() -> Dictionary:
	var s := _base("mpeb_chute_sete_mil_tijolos", "Chute dos 7000 tijolos", "Chute giratório forte que arremessa.", "kick_rotate1")
	_dano(s, 11.0, 12.0, 0.4)
	s.eventos = [_acerto("chute", 0.3, 0.12, 3.2, 1.3), _vfx("impacto", 0.3, 0.3, "Impacto", 1.3, {"frente": 1.3}),
		_som("som", 0.3, "Impacto", 0.9, -4.0), _tremor("tremor", 0.3, 0.2, 0.15)]
	return _fim(s)


## Mouton Shoot (Sanji): avança girando e chuta (AttackStrongPunch ao chegar).
func _mouton_shoot() -> Dictionary:
	var s := _base("mpeb_mouton_shoot", "Mouton Shoot", "Avança girando e chuta o alvo para longe.", "kick_flying")
	_dano(s, 11.0, 12.0, 0.4)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("avanco", 0.1, 0.4, 14.0, 34.0), _acerto("chute", 0.15, 0.4, 2.6, 1.0),
		_vfx("vento", 0.1, 0.4, "Vento", 0.9), _som("som", 0.45, "Impacto", 0.8, -4.0)]
	return _fim(s)


## Chute giratório (Sanji): giro que varre em volta (ENTITY_SWEEP).
func _chute_giratorio() -> Dictionary:
	var s := _base("mpeb_chute_giratorio", "Chute giratório", "Gira o corpo e varre tudo em volta com a perna.", "kick_rotate2")
	_dano(s, 11.0, 6.0, 0.3)
	s.eventos = [_acerto("giro", 0.25, 0.2, 7.0, 0.0), _vfx("anel", 0.25, 0.35, "Anel", 1.6, {"frente": 0.0, "altura": 0.9}),
		_som("som", 0.25, "Vento", 1.1, -5.0)]
	return _fim(s)


## Concasse (Sanji): salta e desce o calcanhar (Damage 25, depois onda 30 em volta).
func _concasse() -> Dictionary:
	var s := _base("mpeb_concasse", "Concasse", "Salta e desce o calcanhar sobre o alvo, rachando o chão.", "kick_flying")
	_dano(s, 25.0, 8.0, 0.5)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("salto", 0.0, 0.35, 10.0, 30.0, {"inclinacao": 35.0}), _acerto("calcanhar", 0.45, 0.15, 6.0, 0.8),
		_vfx("racha", 0.45, 0.6, "Rachadura", 2.2), _som("som", 0.45, "Impacto", 0.6, -3.0), _tremor("tremor", 0.45, 0.3, 0.25)]
	return _fim(s)


## Uchimizu (Arlong, Chu): gotas d'água disparadas como balas (Damage 2,2).
func _uchimizu() -> Dictionary:
	var s := _base("mpeb_uchimizu", "Uchimizu", "Atira gotas d'água tão rápidas quanto balas.", "right_arm_front")
	_dano(s, 2.2, 1.0, 0.1)
	_projeteis(s, {"visual": "Bolha", "raio": 0.15, "velocidade": 45.0, "vida": 0.8, "rastro": "Brilho"})
	for i in 3:
		s.eventos.append(_ev("projetil", "gota_%d" % i, 0.15 + 0.12 * i, 0.05, {}))
	s.eventos.append(_som("som", 0.15, "Disparo", 1.8, -7.0))
	return _fim(s)


## Haki do Rei (Shanks, Luffy): onda de 32 m que atordoa (Damage 3, efeito 7).
func _haki_do_rei() -> Dictionary:
	var s := _base("mpeb_haki_do_rei", "Haki do Rei", "Solta a vontade num estrondo: quem está perto fica atordoado.", "energy_charge")
	_dano(s, 3.0, 0.0, 2.5)
	s.eventos = [_vfx("onda", 0.2, 0.8, "Anel", 8.0, {"frente": 0.0, "altura": 1.0}),
		_vfx("clarao", 0.2, 0.5, "Explosão", 0.9, {"frente": 0.0}), _acerto("vontade", 0.25, 0.3, 32.0, 0.0),
		_som("som", 0.2, "Impacto", 0.3, -2.0), _tremor("tremor", 0.2, 0.6, 0.4)]
	return _fim(s)


## Corte projetado (Shanks, Zoro): lâmina de ar (PROJECTILE_SLASH, AttackStrongSword 11).
func _corte_projetado() -> Dictionary:
	var s := _base("mpeb_corte_projetado", "Corte voador", "Corta o ar e manda uma lâmina para a frente.", "sword_to_left", "sword_to_left")
	_dano(s, 11.0, 4.0, 0.2, "Vento")
	_projeteis(s, {"visual": "Rajada", "raio": 1.1, "raio_de_acerto": 0.7, "velocidade": 32.0, "vida": 1.5, "perfurar": true, "rastro": "Vento"})
	s.eventos = [_ev("projetil", "lamina", 0.2, 0.05, {}), _som("som", 0.2, "Vento", 1.3, -4.0)]
	return _fim(s)


## Investida de espada (Shanks: SkillAssault): avança e corta (Damage 11 → 15).
func _investida_de_espada() -> Dictionary:
	var s := _base("mpeb_investida_de_espada", "Investida de espada", "Avança como um raio e corta ao passar.", "speed_attack_sword", "speed_attack_sword")
	_dano(s, 15.0, 6.0, 0.3)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("avanco", 0.1, 0.25, 16.0, 64.0), _acerto("corte", 0.1, 0.3, 3.0, 1.0),
		_vfx("risco", 0.1, 0.3, "Vento", 1.2), _som("som", 0.15, "Vento", 1.2, -4.0)]
	return _fim(s)


## Estocada do Griffon (Shanks): estocada que lança a força para a frente (ENTITY_GRYPHON).
func _griffon_estocada() -> Dictionary:
	var s := _base("mpeb_griffon_estocada", "Estocada do Griffon", "Estoca com o Griffon e a força segue em linha reta.", "right_arm_front", "right_arm_front")
	_dano(s, 11.0, 8.0, 0.3)
	_projeteis(s, {"visual": "Rajada", "raio": 1.4, "raio_de_acerto": 0.9, "velocidade": 40.0, "vida": 1.4, "perfurar": true, "rastro": "Vento"})
	s.eventos = [_mov("passo", 0.0, 0.2, 3.0, 15.0), _ev("projetil", "forca", 0.25, 0.05, {}),
		_som("som", 0.25, "Vento", 0.9, -3.0), _tremor("tremor", 0.25, 0.2, 0.15)]
	return _fim(s)


## Kamusari (Shanks): golpe supremo (Damage 35 em 10 × tamanho, e cortes em 32).
func _kamusari() -> Dictionary:
	var s := _base("mpeb_kamusari", "Kamusari", "Ergue o Griffon envolto em haki e desce um corte que racha a área.", "sword_overhead", "sword_overhead")
	_dano(s, 35.0, 14.0, 0.8)
	s.eventos = [_vfx("haki", 0.0, 1.4, "Carga", 1.8, {"ancora": "Osso do jogador", "osso": "Mão direita"}),
		_som("som_carga", 0.0, "Vento", 0.4, -6.0), _acerto("corte", 1.5, 0.2, 20.0, 3.0),
		_vfx("explosao", 1.5, 0.6, "Explosão", 2.0, {"frente": 3.0}), _vfx("racha", 1.5, 0.9, "Rachadura", 5.0, {"frente": 3.0}),
		_vfx("onda", 1.5, 0.6, "Anel", 5.0, {"frente": 3.0, "altura": 0.2}), _som("som", 1.5, "Impacto", 0.3, 0.0),
		_tremor("tremor", 1.5, 0.6, 0.6)]
	return _fim(s)


## Tiro forte (Benn Beckman, Yasopp: RifleStrong): Damage 16, empurrão.
func _tiro_forte() -> Dictionary:
	var s := _base("mpeb_tiro_forte", "Tiro certeiro", "Mira com calma e dispara um tiro pesado.", "right_arm_front")
	_dano(s, 16.0, 6.0, 0.3)
	_projeteis(s, {"visual": "Bala de canhão", "raio": 0.15, "velocidade": 80.0, "vida": 0.8, "explosao": 1.2, "rastro": "Fumaça", "som_explosao": "Impacto"})
	s.eventos = [_ev("projetil", "bala", 0.35, 0.05, {}), _som("som", 0.35, "Disparo", 0.8, -3.0), _tremor("tremor", 0.35, 0.1, 0.08)]
	return _fim(s)


## Meteoro do Lucky Roux: salta e cai de corpo (Damage 25, onda 30).
func _lucky_roux_meteoro() -> Dictionary:
	var s := _base("mpeb_lucky_roux_meteoro", "Meteoro", "Salta e cai com o corpo inteiro sobre o alvo.", "both_arm_up")
	_dano(s, 25.0, 10.0, 0.6)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("sobe", 0.0, 0.4, 8.0, 22.0, {"direcao": "Acima"}), _mov("cai", 0.4, 0.35, 12.0, 36.0, {"inclinacao": -45.0}),
		_acerto("queda", 0.8, 0.15, 8.0, 0.5), _vfx("explosao", 0.8, 0.5, "Explosão", 1.4), _vfx("racha", 0.8, 0.7, "Rachadura", 3.0),
		_som("som", 0.8, "Impacto", 0.4, -2.0), _tremor("tremor", 0.8, 0.4, 0.4)]
	return _fim(s)


## Investida do Lucky Roux: rola e atropela (Damage 18).
func _lucky_roux_investida() -> Dictionary:
	var s := _base("mpeb_lucky_roux_investida", "Rolo", "Rola como uma bola e atropela o que estiver na frente.", "sprint")
	_dano(s, 18.0, 9.0, 0.4)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("rolo", 0.0, 0.9, 20.0, 24.0), _acerto("atropelo", 0.05, 0.9, 3.0, 0.8), _vfx("poeira", 0.0, 0.9, "Vento", 1.0),
		_som("som", 0.0, "Vento", 0.6, -6.0)]
	return _fim(s)


## Narikabura (Hongo, Gab): golpe que solta energia à distância (ENTITY_ENERGY).
func _narikabura() -> Dictionary:
	var s := _base("mpeb_narikabura", "Golpe à distância", "Soca o ar e a força voa até o alvo.", "punch_right")
	_dano(s, 11.0, 5.0, 0.3)
	_projeteis(s, {"visual": "Energia", "raio": 0.6, "velocidade": 30.0, "vida": 1.6, "explosao": 1.8, "rastro": "Brilho", "som_explosao": "Impacto"})
	s.eventos = [_ev("projetil", "energia", 0.25, 0.05, {}), _som("som", 0.25, "Disparo", 1.0, -5.0)]
	return _fim(s)


## Gomu Gomu no Rocket (Luffy): estica e se lança até o alvo (Damage 14).
func _gomu_rocket() -> Dictionary:
	var s := _base("mpeb_gomu_rocket", "Gomu Gomu no Rocket", "Estica os braços e se lança como um foguete até o alvo.", "punch_gomu_pistol1")
	_dano(s, 14.0, 10.0, 0.4)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_mov("foguete", 0.15, 0.35, 24.0, 60.0), _acerto("impacto", 0.2, 0.35, 2.6, 0.8),
		_vfx("vento", 0.15, 0.35, "Vento", 1.0), _som("som", 0.45, "Impacto", 0.9, -4.0)]
	return _fim(s)


## Tatsumaki (Zoro): gira as espadas e levanta um tornado em volta (TORNADO).
func _tatsumaki() -> Dictionary:
	var s := _base("mpeb_tatsumaki", "Tatsumaki", "Gira as espadas e levanta um tornado em volta.", "sword_rotate", "sword_rotate")
	_dano(s, 11.0, 4.0, 0.3, "Vento")
	s.eventos = [_vfx("tornado", 0.1, 0.8, "Tornado", 1.6, {"frente": 0.0}), _acerto("giro", 0.15, 0.7, 8.0, 0.0, false),
		_som("som", 0.1, "Vento", 0.8, -4.0)]
	return _fim(s)


## Iai (Zoro): passa pelo alvo cortando (Damage 20).
func _iai() -> Dictionary:
	var s := _base("mpeb_iai", "Iai", "Atravessa o alvo num corte só.", "speed_attack_sword", "speed_attack_sword")
	_dano(s, 20.0, 4.0, 0.5)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_ev("hitbox", "trilha", 0.2, 0.1, {"forma": "Caixa", "largura": 2.0, "altura": 2.0, "profundidade": 10.0,
			"x": 0.0, "y": 1.0, "z": -5.0, "unicos": true, "mirar": false, "na_mao": false}),
		_mov("passa", 0.2, 0.05, 10.0, 100.0, {"teleporte": true}), _vfx("risco", 0.2, 0.3, "Vento", 1.4),
		_som("som", 0.2, "Vento", 1.6, -3.0)]
	return _fim(s)


## Sanzen Sekai (Zoro): avança girando as três espadas (Damage 24).
func _sanzen_sekai() -> Dictionary:
	var s := _base("mpeb_sanzen_sekai", "Sanzen Sekai", "Gira as três espadas e avança cortando.", "sword_rotate", "sword_rotate")
	_dano(s, 24.0, 8.0, 0.5)
	s.configuracoes.mirar_no_alvo = true
	s.eventos = [_vfx("giro", 0.0, 0.6, "Tornado", 0.9, {"frente": 0.0}), _mov("avanco", 0.5, 0.3, 12.0, 40.0),
		_acerto("corte", 0.55, 0.3, 3.4, 1.0), _vfx("risco", 0.6, 0.35, "Vento", 1.6), _som("som", 0.6, "Vento", 1.2, -2.0),
		_tremor("tremor", 0.6, 0.2, 0.2)]
	return _fim(s)


## Ashura (Zoro): aura de nove espadas e três cortes enormes (Damage 44, raio 12).
func _ashura() -> Dictionary:
	var s := _base("mpeb_ashura", "Ashura", "Uma aura de nove espadas e três cortes que varrem a área.", "sword_rotate", "sword_rotate")
	_dano(s, 44.0, 10.0, 0.6)
	s.eventos = [_vfx("aura", 0.0, 2.4, "Carga", 2.2, {"frente": 0.0, "altura": 1.2}), _som("som_aura", 0.0, "Vento", 0.4, -6.0)]
	for i in 3:
		var t := 1.2 + 0.4 * i
		s.eventos.append(_acerto("corte_%d" % i, t, 0.12, 12.0, 2.0))
		s.eventos.append(_vfx("risco_%d" % i, t, 0.3, "Vento", 2.2, {"frente": 2.0}))
		s.eventos.append(_som("som_%d" % i, t, "Vento", 0.9 + 0.1 * i, -2.0))
	s.eventos.append(_tremor("tremor", 1.2, 1.0, 0.35))
	return _fim(s)


# ------------------------------------------------ Moku Moku (Smoker), números da ficha

func _moku_white_blow() -> Dictionary:
	var s := _base("mpeb_moku_white_blow", "White Blow", "Dispara um punho de fumaça.", "punch_right")
	_dano(s, 11.0, 6.0, 0.3, "Vento")
	_projeteis(s, {"visual": "Bala de canhão", "raio": 0.6, "velocidade": 26.0, "vida": 1.2, "explosao": 2.4, "rastro": "Fumaça", "som_explosao": "Impacto"})
	s.vfx.merge({"cor": "#dcdde1"}, true)
	s.eventos = [_ev("projetil", "punho", 0.3, 0.05, {}), _som("som", 0.3, "Disparo", 0.7, -5.0)]
	return _fim(s)


func _moku_white_vine() -> Dictionary:
	var s := _base("mpeb_moku_white_vine", "White Vine", "Lança um redemoinho de fumaça que corta em arco.", "sword_to_right", "sword_to_right")
	_dano(s, 15.0, 5.0, 0.3, "Vento")
	_projeteis(s, {"visual": "Energia", "raio": 1.0, "raio_de_acerto": 0.7, "velocidade": 14.0, "vida": 1.4, "perfurar": true, "rastro": "Fumaça"})
	s.vfx.merge({"cor": "#f4f6f8"}, true)
	s.eventos = [_vfx("arco", 0.3, 0.4, "Vento", 1.8), _ev("projetil", "redemoinho", 0.5, 0.05, {}), _som("som", 0.5, "Vento", 0.7, -5.0)]
	return _fim(s)


func _moku_white_launcher() -> Dictionary:
	var s := _base("mpeb_moku_white_launcher", "White Launcher", "Vira fumaça e se lança contra o alvo.", "speed_attack_punch", "speed_attack_sword")
	_dano(s, 11.0, 8.0, 0.4, "Vento")
	s.configuracoes.mirar_no_alvo = true
	s.vfx.merge({"cor": "#dcdde1"}, true)
	s.eventos = [_mov("lanca", 0.45, 0.4, 24.0, 48.0), _acerto("impacto", 0.5, 0.4, 3.0, 1.0), _vfx("fumaca", 0.45, 0.4, "Vento", 1.2),
		_som("som", 0.85, "Impacto", 0.7, -4.0)]
	return _fim(s)


func _moku_white_out() -> Dictionary:
	var s := _base("mpeb_moku_white_out", "White Out", "Cobre a área de fumaça e detona em volta, prendendo quem está perto.", "both_arm_up")
	_dano(s, 18.0, 8.0, 1.0, "Vento")
	s.dano.merge({"lentidao": 60.0, "duracao_efeito": 1.0}, true)
	s.vfx.merge({"cor": "#dcdde1"}, true)
	s.eventos = [_vfx("nevoa", 0.25, 1.0, "Vento", 4.0, {"frente": 0.0}), _som("som_nevoa", 0.25, "Vento", 0.5, -6.0),
		_acerto("detonacao", 1.25, 0.25, 20.0, 0.0), _vfx("onda", 1.25, 0.6, "Anel", 5.0, {"frente": 0.0, "altura": 0.5}),
		_som("som", 1.25, "Impacto", 0.4, -2.0), _tremor("tremor", 1.25, 0.4, 0.35)]
	return _fim(s)
