extends Node
## Equipamento exclusivo da história: cliques no executor comum; Z em GiroDaEspada.
const MODELO := preload("res://mapas/modelos/sword.glb")
const ESTILO := preload("res://src/combat/direcional/estilos/espada.tres")
const BOXE := preload("res://src/combat/direcional/estilos/boxe.tres")
# Modelo importado em metros, pega na origem; lâmina +Y (catalogo.json).
const BASE := Vector3(0, 0.16, 0)
const PONTA := Vector3(0.032, 1.08, 0)

var giro: Node
var habilidades_da_lamina: HabilidadesDaLamina
var ativa := false
## Espada que uma fruta põe na mão no lugar desta (Ama no Murakumo da Pika Mine Piece):
## outro modelo, outros pontos de base/ponta e o dano escalado no executor.
var _cena_alt: PackedScene
var _base_alt := Vector3.ZERO
var _ponta_alt := Vector3.ZERO
var _mult_antes := 1.0
var _visual: Node3D
var _jogador: Node3D


func _ready() -> void:
	_jogador = get_parent() as Node3D
	# Antes do executor: remonta o encaixe após troca de aparência, antes da varredura.
	process_physics_priority = -1
	giro = preload("res://src/historia/equipamentos/giro_da_espada.gd").new()
	giro.name = "GiroDaEspada"
	add_child(giro)
	habilidades_da_lamina = HabilidadesDaLamina.new()
	habilidades_da_lamina.name = "HabilidadesDaLamina"
	add_child(habilidades_da_lamina)


func aplicar(sim: bool) -> void:
	if not sim and _cena_alt != null:
		# Quem desliga a espada (trocar de item, de fruta) desfaz também a da fruta.
		_cena_alt = null
		var ex_alt: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
		if ex_alt != null:
			ex_alt.multiplicador_de_dano = _mult_antes
			ex_alt.max_alvos = 0
			ex_alt.sons_da_arma = {}
			var anim_alt = _jogador.get("_proc_anim")
			if anim_alt != null:
				anim_alt.definir_locomocao_de_arma({})
	if ativa == sim:
		return
	if not sim and is_instance_valid(giro):
		giro.encerrar()
	if not sim and is_instance_valid(habilidades_da_lamina):
		habilidades_da_lamina.abortar()
	ativa = sim
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	ex.trocar_estilo(_estilo_da_espada() if ativa else BOXE)
	var entrada: EntradaCorpoACorpo = _jogador.get("entrada_combate_direcional")
	entrada.atualizar_defesa(false)
	entrada.esquecer_gesto()
	if not ativa:
		_tirar_visual()
	else:
		_montar_visual()


## Liga/desliga a espada de uma fruta. Desligar só mexe se ela estiver ligada.
func aplicar_espada_de_fruta(sim: bool, cena: PackedScene = null, base := Vector3.ZERO,
		ponta := Vector3.ZERO, multiplicador := 1.0) -> void:
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if sim:
		if espada_de_fruta() and ativa:
			return
		if ativa:
			aplicar(false)
		_cena_alt = cena
		_base_alt = base
		_ponta_alt = ponta
		if ex != null:
			_mult_antes = ex.multiplicador_de_dano
			ex.multiplicador_de_dano = multiplicador
		aplicar(true)
	elif espada_de_fruta():
		aplicar(false)


## Lâmina do Epic Fight (10/11/2026): reaproveita o encaixe da espada de fruta — outro modelo, base/ponta e dano.
var lamina_ef := ""
## Segunda arma do Epic Fight na MÃO ESQUERDA (estilo dual do mod). Ver `definir_secundaria`.
var lamina_ef_sec := ""
var _visual_l: Node3D
## HABILIDADE INATA da arma (Epic Fight, `HabilidadesDeArma`): a barra de carga sobe com o dano de cada golpe que acerta e a tecla R usa a habilidade com ela cheia.
var carga := 0.0
var carga_max := 0.0
var habilidade := {}
var _modo_ate_ms := 0
var _parte_da_habilidade := 0          # 0 = fora; 1..3 = parte em curso das habilidades de várias partes
var _acertou_parte := false
## PASSIVA DO BATTOJUTSU (uchigatana, `BattojutsuPassive`): depois de 5 s sem agir a arma volta para a BAINHA (moveset `UCHIGATANA_SHEATHED`: um auto sacando, dash e airslash da bainha,
## `hold/walk/run_uchigatana_sheath`); qualquer golpe saca e zera a espera. A lâmina fica escondida na bainha.
const ESPERA_DA_BAINHA := 5.0
var embainhada := false
var _clipe_bloqueio := ""
var _ocioso := 0.0
var _carga_desde_ms := -1               # habilidade CARREGADA (Steel Whirlwind): quando a tecla foi apertada (−1 = não está carregando)
signal carga_mudou(carga: float, maximo: float)
signal habilidade_usada(nome: String)
## A lâmina do Epic Fight acertou um alvo (gasta 1 uso). Quem tem a progressão (o Modo História) escuta.
signal acertou_com_lamina(id: String)

## Estilo da espada em uso: a cadeia de golpes do Epic Fight para a categoria da lâmina (se o mod local está extraído) ou a espada da história.
func _estilo_da_espada() -> EstiloCorpoACorpo:
	if lamina_ef != "":
		var dl := LaminasEpicFight.dados_dual(lamina_ef, lamina_ef_sec)
		var variante: String = str(habilidade.get("variante", "")) if _modo_ate_ms > 0 else ("sheath" if embainhada else "")
		var ef := EstiloEpicFight.criar(str(dl.get("tipo", "")), float(dl.get("velocidade", 0.0)), dl.get("dual", false), variante)
		if ef != null:
			return ef
	return ESTILO


func aplicar_lamina_ef(id: String) -> void:
	var d := LaminasEpicFight.dados(id)
	if d.is_empty():
		return
	if lamina_ef == id and ativa:
		return
	limpar_lamina_ef()
	lamina_ef = id
	aplicar_espada_de_fruta(true, LaminasEpicFight.cena(id), d.base, d.ponta, d.multiplicador)
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if ex != null and not ex.contato.is_connected(_ao_contato_da_lamina):
		ex.contato.connect(_ao_contato_da_lamina)
		ex.golpe_encerrado.connect(_ao_encerrar_golpe)
		ex.golpe_iniciado.connect(func(_g, _i): _ao_iniciar_golpe_da_lamina())
		ex.bloqueou.connect(func(_g, _p): _ao_bloquear_com_lamina())
	if ex != null:
		ex.sons_da_arma = d.sons
		_ligar_rastro(ex)
		_ligar_locomocao(str(d.tipo))
		lamina_ef_sec = ""
		_atualizar_habilidade(str(d.tipo), false)
		ex.max_alvos = int(d.max_alvos)       # `max_strikes` do item (adaga/uchigatana/tachi/espada longa…: o mod limita os alvos por golpe)


func _ao_contato_da_lamina(_id: int, _alvo: Node3D, resultado: int, _lado: int, _posicao: Vector3, _golpe: GolpeDirecional) -> void:
	if lamina_ef != "" and resultado == ResolucaoDeContato.Resultado.ACERTO:
		acertou_com_lamina.emit(lamina_ef)
		if _parte_da_habilidade > 0:
			_acertou_parte = true
		_carregar(float(LaminasEpicFight.dados_dual(lamina_ef, lamina_ef_sec).get("dano_do_mod", 0.0)))


## O rastro do mod (`RastroDeArma`) acompanha o golpe: criado uma vez, vale enquanto há arma do Epic Fight na mão.
## Locomoção do mod para a categoria (`hold_*`/`walk_*`/`run_*` de `armas.json`): o animador toca os clipes em laço enquanto a arma está na mão.
## Liga/desliga a segunda arma: troca o estilo para o dual do mod (`dagger_dual_*`), põe o 2º modelo na mão esquerda e refaz dano/alvos/sons.
func definir_secundaria(id: String) -> void:
	id = LaminasEpicFight.resolver(id)
	var valida := lamina_ef != "" and id != "" and LaminasEpicFight.pode_dual(lamina_ef, id)
	var novo := id if valida else ""
	if novo == lamina_ef_sec:
		return
	lamina_ef_sec = novo
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if lamina_ef == "" or ex == null:
		_tirar_visual_l()
		return
	var d := LaminasEpicFight.dados_dual(lamina_ef, lamina_ef_sec)
	ex.trocar_estilo(_estilo_da_espada())
	ex.multiplicador_de_dano = float(d.multiplicador)
	ex.max_alvos = int(d.max_alvos)
	_ligar_locomocao(str(d.tipo), lamina_ef_sec != "")
	_atualizar_habilidade(str(d.tipo), lamina_ef_sec != "")
	if lamina_ef_sec == "":
		_tirar_visual_l()
	elif ativa:
		_montar_visual()


func _passiva_da_bainha(delta: float) -> void:
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if lamina_ef == "" or ex == null or str(LaminasEpicFight.dados(lamina_ef).get("tipo", "")) != "uchigatana":
		if embainhada:
			_definir_bainha(false)
		_ocioso = 0.0
		return
	if ex.atacando() or ex.estado == ExecutorCorpoACorpo.Estado.REACAO:
		_ocioso = 0.0
		return
	_ocioso += delta
	if _ocioso >= ESPERA_DA_BAINHA and not embainhada:
		_definir_bainha(true)


func _definir_bainha(sim: bool) -> void:
	if embainhada == sim:
		return
	embainhada = sim
	if not sim:
		_ocioso = 0.0
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if ex != null:
		ex.trocar_estilo(_estilo_da_espada())
	_ligar_locomocao("uchigatana", false)
	if is_instance_valid(_visual):
		_visual.visible = not sim


func _atualizar_habilidade(tipo: String, dual: bool) -> void:
	var nova := HabilidadesDeArma.para(tipo, dual)
	if str(nova.get("id", "")) != str(habilidade.get("id", "")):
		carga = 0.0                              # outra habilidade = barra nova
	habilidade = nova
	_modo_ate_ms = 0
	carga_max = float(nova.get("consumo", 0.0))
	carga = minf(carga, carga_max)
	carga_mudou.emit(carga, carga_max)


## Cada golpe que acerta soma o dano dele à barra (`ServerPlayerPatch`: recurso + dano), até o máximo; com a habilidade em modo ativo a barra não enche.
func _carregar(dano: float) -> void:
	if carga_max <= 0.0 or _modo_ate_ms > 0 or _parte_da_habilidade > 0 or carga >= carga_max:
		return
	carga = minf(carga + dano, carga_max)
	carga_mudou.emit(carga, carga_max)


func carga_cheia() -> bool:
	return carga_max > 0.0 and carga >= carga_max - 0.001


## Tecla R: usa a habilidade inata se a barra está cheia e o corpo livre. `golpe` = o golpe do mod no encaixe HABILIDADE; `modo` = Liechtenauer (cadeia própria por 12 s).
func usar_habilidade() -> bool:
	if lamina_ef == "" or habilidade.is_empty() or not carga_cheia():
		return false
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if ex == null or (ex.estado != ExecutorCorpoACorpo.Estado.NEUTRO and ex.estado != ExecutorCorpoACorpo.Estado.GUARDA):
		return false
	if str(habilidade.tipo) == "golpe":
		var encaixe := GolpeDirecional.Direcao.HABILIDADE
		var corrida := habilidade.has("clipe_corrida") and ex.ator != null and ex.ator.em_corrida() and ex.estilo.golpe_para(GolpeDirecional.Direcao.HABILIDADE_3) != null
		if corrida:
			encaixe = GolpeDirecional.Direcao.HABILIDADE_3          # Battojutsu correndo = battojutsu_dash
		if ex.estilo.golpe_para(encaixe) == null or not ex.pedir_ataque(encaixe):
			return false
		_parte_da_habilidade = 0 if corrida else 1
		_acertou_parte = false
	else:
		_modo_ate_ms = Time.get_ticks_msec() + int(float(habilidade.duracao) * 1000.0)
		ex.trocar_estilo(_estilo_da_espada())
	carga = 0.0
	carga_mudou.emit(carga, carga_max)
	habilidade_usada.emit(str(habilidade.nome))
	return true


func modo_ativo() -> bool:
	return _modo_ate_ms > 0


## Habilidade de várias partes: acertou a parte em curso → a próxima começa assim que ela termina; errou (ou acabou) → a cadeia para.
## Bloqueou um golpe com a arma do mod na mão: toca a reação `guard_<categoria>_hit` do mod (uma vez).
func _ao_bloquear_com_lamina() -> void:
	var anim = _jogador.get("_proc_anim")
	if anim != null and lamina_ef != "" and ResourceLoader.exists(_clipe_bloqueio):
		anim.play_baked(load(_clipe_bloqueio), 1.0)


func _ao_iniciar_golpe_da_lamina() -> void:
	_ocioso = 0.0
	if embainhada:
		embainhada = false                       # o golpe saca a lâmina (o estilo da bainha já está valendo para ESTE golpe; o normal volta no fim)
		if is_instance_valid(_visual):
			_visual.visible = true
		_ligar_locomocao("uchigatana", false)
		_trocar_estilo_ao_fim = true


var _trocar_estilo_ao_fim := false


func _ao_encerrar_golpe(_id: int, motivo: StringName) -> void:
	if _trocar_estilo_ao_fim:
		_trocar_estilo_ao_fim = false
		var ex0: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
		if ex0 != null:
			ex0.trocar_estilo.call_deferred(_estilo_da_espada())
	if _parte_da_habilidade == 0:
		return
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	var proxima := GolpeDirecional.Direcao.HABILIDADE + _parte_da_habilidade
	if motivo == &"fim" and _acertou_parte and ex != null and ex.estilo.golpe_para(proxima as GolpeDirecional.Direcao) != null:
		_parte_da_habilidade += 1
		_acertou_parte = false
		ex.pedir_ataque.call_deferred(proxima as GolpeDirecional.Direcao)
	else:
		_parte_da_habilidade = 0


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.keycode == KEY_R and not evento.echo:
		if evento.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var ok_ := iniciar_carga() if habilidade.has("clipe_carga") else usar_habilidade()
			if ok_:
				get_viewport().set_input_as_handled()
		elif not evento.pressed and _carga_desde_ms >= 0:
			soltar_carga()


## Habilidade CARREGADA (Steel Whirlwind): segurar R toca o clipe de carga e deixa o corpo mais lento (até −80 % em 1,5 s); soltar com pelo menos 0,3 s executa; menos que isso, cancela sem gastar a barra.
func iniciar_carga() -> bool:
	if lamina_ef == "" or not habilidade.has("clipe_carga") or not carga_cheia() or _carga_desde_ms >= 0:
		return false
	var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
	if ex == null or (ex.estado != ExecutorCorpoACorpo.Estado.NEUTRO and ex.estado != ExecutorCorpoACorpo.Estado.GUARDA):
		return false
	_carga_desde_ms = Time.get_ticks_msec()
	var anim = _jogador.get("_proc_anim")
	var clipe := "res://assets/epic_fight/res/ef_%s.res" % str(habilidade.clipe_carga)
	if anim != null and ResourceLoader.exists(clipe):
		anim.play_baked(load(clipe), 1.0, 0.0, "", -1, true)         # segura a última pose enquanto carrega
	return true


func segundos_de_carga() -> float:
	return 0.0 if _carga_desde_ms < 0 else (Time.get_ticks_msec() - _carga_desde_ms) / 1000.0


func soltar_carga() -> bool:
	if _carga_desde_ms < 0:
		return false
	var segundos := segundos_de_carga()
	_carga_desde_ms = -1
	_jogador.set_meta("ef_fator_velocidade", 1.0)
	var anim = _jogador.get("_proc_anim")
	if anim != null:
		anim.play_baked(null)
	if segundos < float(habilidade.get("carga_min", 0.3)):
		return false
	return usar_habilidade()


func _tirar_visual_l() -> void:
	if is_instance_valid(_visual_l):
		_visual_l.get_parent().remove_child(_visual_l)
		_visual_l.queue_free()
	_visual_l = null


func _ligar_locomocao(tipo: String, dual := false) -> void:
	var anim = _jogador.get("_proc_anim")
	if anim == null:
		return
	var clipes := {}
	var lista: Array = EpicFightDados.categoria(tipo).get("locomocao", [])
	if dual:
		lista = ["hold_dual", "walk_dual", "run_dual"]           # o estilo dual tem os seus (`ef_hold_dual`, `ef_run_dual`)
	for nome in lista:
		var n := str(nome)
		if n.ends_with("_sheath") != embainhada:
			continue                                   # embainhada usa os `*_sheath`; desembainhada, os normais
		var chave := n.get_slice("_", 0)
		var caminho := "res://assets/epic_fight/res/ef_%s.res" % n
		if chave in ["hold", "walk", "run"] and ResourceLoader.exists(caminho):
			clipes[chave] = load(caminho)
	# Pose de guarda e reação ao bloqueio do mod (`skill/guard_<categoria>` e `_hit`): longsword, greatsword, spear, uchigatana, sword (bokken) e o dual (`guard_dualsword`).
	var guarda := "dualsword" if dual else tipo
	var g_clipe := "res://assets/epic_fight/res/ef_guard_%s.res" % guarda
	if ResourceLoader.exists(g_clipe):
		clipes["guard"] = load(g_clipe)
	_clipe_bloqueio = "res://assets/epic_fight/res/ef_guard_%s_hit.res" % guarda
	anim.definir_locomocao_de_arma(clipes)


func _ligar_rastro(ex: ExecutorCorpoACorpo) -> void:
	if has_node("RastroDeArma"):
		return
	var r := RastroDeArma.new()
	r.name = "RastroDeArma"
	r.executor = ex
	r.arma = self
	add_child(r)


func limpar_lamina_ef() -> void:
	if lamina_ef != "":
		lamina_ef = ""
		habilidade = {}
		_parte_da_habilidade = 0
		_carga_desde_ms = -1
		_jogador.set_meta("ef_fator_velocidade", 1.0)
		carga_max = 0.0
		_modo_ate_ms = 0
		carga_mudou.emit(carga, carga_max)
		lamina_ef_sec = ""
		_tirar_visual_l()
		aplicar_espada_de_fruta(false)


func espada_de_fruta() -> bool:
	return _cena_alt != null


func visual() -> Node3D:
	return _visual if is_instance_valid(_visual) else null


func _physics_process(delta: float) -> void:
	if ativa:
		_montar_visual()
	_passiva_da_bainha(delta)
	if _carga_desde_ms >= 0:
		var seg := segundos_de_carga()
		_jogador.set_meta("ef_fator_velocidade", 1.0 - 0.8 * minf(seg / float(habilidade.get("carga_max", 1.5)), 1.0))
		if seg >= float(habilidade.get("carga_max", 1.5)) + 0.5:
			soltar_carga()                          # tempo máximo permitido: solta sozinho (`getAllowedMaxChargingTicks` 60)
	if _modo_ate_ms > 0 and Time.get_ticks_msec() >= _modo_ate_ms:
		_modo_ate_ms = 0                          # acabou o Liechtenauer: volta a cadeia normal
		var ex: ExecutorCorpoACorpo = _jogador.get("combate_direcional")
		if ex != null and lamina_ef != "":
			ex.trocar_estilo(_estilo_da_espada())


func _montar_visual() -> void:
	var modelo: Node3D = _jogador.modelo_visual()
	if not is_instance_valid(modelo):
		return
	var mao: Node3D = _jogador.get("_rig").item_handle
	if mao == null:
		return
	if is_instance_valid(_visual) and _visual.get_parent() == mao:
		_montar_visual_esquerdo()                # a direita já está; a esquerda pode ter mudado
		return
	_tirar_visual()
	_visual = (_cena_alt if _cena_alt != null else MODELO).instantiate() as Node3D
	_visual.name = "EspadaInicial"
	mao.add_child(_visual)
	# Escala uniforme em metros, mesmo em personagens com escala de rig diferente.
	var escala := mao.global_basis.get_scale()
	_visual.scale = Vector3(1.0 / escala.x, 1.0 / escala.y, 1.0 / escala.z)
	_montar_visual_esquerdo()


func _montar_visual_esquerdo() -> void:
	if lamina_ef_sec == "":
		_tirar_visual_l()
		return
	var mao_l: Node3D = _jogador.get("_rig").item_handle_l
	if mao_l == null or (is_instance_valid(_visual_l) and _visual_l.get_parent() == mao_l):
		return
	_tirar_visual_l()
	_visual_l = LaminasEpicFight.cena(lamina_ef_sec).instantiate() as Node3D
	_visual_l.name = "ArmaEsquerda"
	mao_l.add_child(_visual_l)
	var escala := mao_l.global_basis.get_scale()
	_visual_l.scale = Vector3(1.0 / escala.x, 1.0 / escala.y, 1.0 / escala.z)


func ponto(nome: StringName) -> Vector3:
	if nome == &"EspadaBaseL" or nome == &"EspadaPontaL":
		if not ativa or not is_instance_valid(_visual_l) or lamina_ef_sec == "":
			return Vector3.INF
		var ds := LaminasEpicFight.dados(lamina_ef_sec)
		return _visual_l.to_global(ds.base if nome == &"EspadaBaseL" else ds.ponta)
	if not ativa or not is_instance_valid(_visual):
		return Vector3.INF
	if _cena_alt != null:
		return _visual.to_global(_base_alt if nome == &"EspadaBase" else _ponta_alt)
	return _visual.to_global(BASE if nome == &"EspadaBase" else PONTA)


func _tirar_visual() -> void:
	_tirar_visual_l()
	if is_instance_valid(_visual):
		_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null


func _exit_tree() -> void:
	_tirar_visual()
