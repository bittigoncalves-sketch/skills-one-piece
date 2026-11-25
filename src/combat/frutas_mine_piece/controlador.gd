class_name ControladorFrutaMinePiece
extends Node
## Adaptador nativo R/Z; os executores traduzem contadores e entidades do Java.
## Não passa por SkillsPublicadas, ExecutorDeSkill ou fábrica do Builder.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const META := "combate_mine_piece"
## Energia = custo do mod × isto. 1: as unidades do mod, sem conversão (A9, 27/10/2026; era 0,1 desde 23/10 e / 100 antes).
const ENERGIA_POR_CUSTO := 1.0
var fruta_id := ""
var ator: Player
var executor: Node
var selecao := 0
var segurando := false
## Rotação extra (graus, por papel do osso) somada à pose do clipe — a Luta inclina o braço com a mira no ar.
var pose_extra := {}
var shift := false   # isShiftKeyDown, lido no dono e enviado ao servidor
var tras := false    # PRESS_S (S segurado), idem
var recarga := 0.0
var recarga_total := 0.0
## ESTILO com teclas diretas (a Luta: Z/X/C = técnicas 1/2/3, sem o R): cada técnica tem a própria recarga (`recargas`, número → s, contada
## do início do golpe). As frutas do mod seguem com a recarga GLOBAL de sempre.
var recargas := {}
var tick := 0
var ativo := false
var acao := 0
var imunidade := {} # invulnerableTime compartilhado pelos projéteis da fruta.
## MobEffect SLOWNESS que a técnica aplica neste tick (amplificador; −1 = nenhuma).
## Minecraft: −15% de velocidade por nível; a partir do amplificador 6 o corpo não anda.
var lentidao := -1
var corpo: CorpoLogiaMinePiece   # só nas logias antigas ("familia": "logia" sem "sem_logia")
## Frutas "paralelas" (ficha `"paralelo": true`): cada técnica roda na própria sessão e nenhuma trava as outras.
var paralelo := false
var sessoes: Array[SessaoDeTecnicaMinePiece] = []
var _manutencao: Node   # paralelo: executor que só roda `manter()` por quadro (a espada de luz da Pika)
## setDeltaMovement da técnica neste tick (m/s): a investida manda no corpo. Zera a cada tick.
var impulso := Vector3.ZERO
var impulso_ativo := false
const META_INVISIVEL := "mine_piece_invisivel"
## PlayerTickEvent2: toque duplo de W/S lido a cada 2 ticks com janela 3 → a passiva da
## ficha ("toque_duplo": número), sem custo nem recarga (Pika e Goro: 28).
const JANELA_TOQUE_DUPLO := 3.0
var toque := 0          # +1 W, −1 S: a direção do último toque duplo (o cnt1 da passiva)
var _toques := {"w": 0.0, "s": 0.0}
var _tick_local := 0
var _acumulado_local := 0.0
var _tempo := 0.0
var _clipe := ""
var _clipe_t := 0.0
var _poses := {}

static func de(jogador: Node) -> ControladorFrutaMinePiece:
	return jogador.get_node_or_null("FrutaMinePiece") as ControladorFrutaMinePiece if jogador != null else null

func _ready() -> void:
	ator = get_parent() as Player
	var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS[fruta_id]
	selecao = int(ficha.ciclo[0].numero)
	paralelo = bool(ficha.get("paralelo", false))
	# `sem_logia` (decisão do dono, 24/11/2026): a logia refatorada não ganha transformação elemental nem voo forçado.
	if str(ficha.get("familia", "")) == "logia" and not bool(ficha.get("sem_logia", false)):
		corpo = CorpoLogiaMinePiece.new()
		corpo.c = self
		corpo.cor = ficha.get("cor", Color.WHITE)
		corpo.particula = ficha.get("particula_elemento", {})
	executor = load(ficha.executor).new()
	executor.c = self
	if paralelo and not executor.has_method("manter"):
		executor.free()   # as sessões criam os próprios executores; só quem mantém algo por quadro (a espada da Pika) fica
		executor = null
	else:
		add_child(executor)
	_manutencao = executor if paralelo else null
	var caminho := str(ficha.get("poses", ""))
	if not caminho.is_empty() and FileAccess.file_exists(caminho):
		_poses = JSON.parse_string(FileAccess.get_file_as_string(caminho))

func controlador() -> ControladorFrutaMinePiece:
	return self

func servidor() -> bool:
	var mp := multiplayer if is_inside_tree() else null
	return mp == null or not mp.has_multiplayer_peer() or mp.is_server()

func fruta_ativa() -> bool:
	return is_instance_valid(ator) and ator.current_fruit_id == fruta_id and ator.capacidades.can_use_fruit

func trocar(para_tras := false) -> void:
	_pedir("trocar", para_tras)

func usar(apertou: bool) -> void:
	_pedir("usar", apertou)


## Teclas das técnicas (08/11/2026, pedido do dono): cada uma na sua tecla, na ordem do ciclo — Z X C V e, havendo mais, B N.
const TECLAS := ["Z", "X", "C", "V", "B", "N"]


## tecla → número da técnica. A ficha pode fixar (`"teclas_diretas"`, a Luta); senão vale a ordem do ciclo.
func mapa_de_teclas() -> Dictionary:
	var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS.get(fruta_id, {})
	if ficha.has("teclas_diretas"):
		return ficha.teclas_diretas
	var mapa := {}
	var ciclo: Array = ficha.get("ciclo", [])
	for i in mini(ciclo.size(), TECLAS.size()):
		mapa[TECLAS[i]] = int(ciclo[i].numero)
	return mapa


## Recarga própria de cada técnica (a Luta) em vez da global do mod.
func recarga_por_tecnica() -> bool:
	return paralelo or CatalogoFrutasMinePiece.FICHAS.get(fruta_id, {}).has("teclas_diretas")


## Estilo de teclas diretas: `tecla` = "Z", "X", "C", "V", "B" ou "N".
func usar_tecla(tecla: String, apertou: bool) -> void:
	_pedir("tecla_" + tecla.to_lower(), apertou)


func tem_teclas_diretas() -> bool:
	return CatalogoFrutasMinePiece.FICHAS.has(fruta_id)

## Visual do golpe nos OUTROS peers (só apresentação, sem dano): o executor roda no servidor, então o cliente não veria os cubos da Luta.
## `unreliable`: perder um clarão não importa. O cliente só aceita do servidor (id 1).
func mostrar_golpe(centro: Vector3, frente: Vector3, forca: float, origem: Vector3, lado: float) -> void:
	if servidor() and is_inside_tree() and multiplayer.has_multiplayer_peer():
		_golpe_visual.rpc(centro, frente, forca, origem, lado)

@rpc("any_peer", "call_remote", "unreliable")
func _golpe_visual(centro: Vector3, frente: Vector3, forca: float, origem: Vector3, lado: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 or servidor():
		return
	var Visual := preload("res://src/combat/frutas_mine_piece/luta_visual.gd")
	if forca > 0.0:
		Visual.estourar(self, centro, frente, forca)
	if lado != 0.0:
		Visual.fantasma(self, origem, frente, lado, 3.1)

func _pedir(tipo: String, valor: bool) -> void:
	if servidor():
		_executar(tipo, valor)
	else:
		_pedido.rpc_id(1, tipo, valor)

@rpc("any_peer", "call_remote", "reliable")
func _pedido(tipo: String, valor: bool) -> void:
	if servidor() and multiplayer.get_remote_sender_id() == ator.get_multiplayer_authority():
		_executar(tipo, valor)

func _executar(tipo: String, valor: bool) -> void:
	if tipo == "shift":
		shift = valor
	elif tipo == "tras":
		tras = valor
	elif tipo == "toque_duplo":
		comecar_passiva(1 if valor else -1)
	elif tipo == "usar":
		segurando = valor
		if valor:
			comecar()
		elif paralelo:
			for s in sessoes:
				if s.tecla.is_empty():
					s.segurando = false
	elif tipo.begins_with("tecla_"):
		_tecla_direta(tipo.substr(6).to_upper(), valor)
	elif tipo == "trocar" and fruta_ativa() and (paralelo or not ativo):
		var ciclo: Array = CatalogoFrutasMinePiece.FICHAS[fruta_id].ciclo
		var indice := 0
		for i in ciclo.size():
			if int(ciclo[i].numero) == selecao:
				indice = i
		selecao = int(ciclo[posmod(indice + (-1 if valor else 1), ciclo.size())].numero)

func _ler_toque_duplo(delta: float) -> void:
	_acumulado_local += delta
	while _acumulado_local >= B.TICK:
		_acumulado_local -= B.TICK
		_tick_local += 1
		if _tick_local % 2 != 0:
			continue
		var menu: bool = ator._menu_de_tela_aberto()
		var direcao := 0
		for tecla in ["w", "s"]:
			var flag: float = _toques[tecla]
			if Input.is_physical_key_pressed(KEY_W if tecla == "w" else KEY_S) and not menu:
				if flag > 0.0 and flag < JANELA_TOQUE_DUPLO:
					direcao = 1 if tecla == "w" else -1
					flag = 20.0
				_toques[tecla] = maxf(flag + 1.0, JANELA_TOQUE_DUPLO)
			else:
				_toques[tecla] = maxf(minf(flag, JANELA_TOQUE_DUPLO if flag <= 5.0 else 0.0) - 1.0, 0.0)
		if direcao != 0 and (corpo == null or not corpo.voando()):
			_pedir("toque_duplo", direcao > 0)


## Z/X/C de um estilo: apertar escolhe a técnica da tecla e começa; soltar só vale para a que está em curso.
func _tecla_direta(tecla: String, apertou: bool) -> void:
	var mapa := mapa_de_teclas()
	if not mapa.has(tecla):
		return
	if paralelo:
		if apertou:
			comecar_paralela(int(mapa[tecla]), tecla)
		else:
			var s := sessao_de(int(mapa[tecla]))
			if s != null:
				s.segurando = false
		return
	if apertou:
		if ativo:
			return
		selecao = int(mapa[tecla])
		segurando = true
		if not comecar():
			segurando = false
	elif ativo and selecao == int(mapa[tecla]):
		segurando = false


## A passiva do toque duplo: sem custo e sem recarga, só sem técnica em curso.
func comecar_passiva(direcao: int) -> bool:
	var numero := int(CatalogoFrutasMinePiece.FICHAS[fruta_id].get("toque_duplo", 0))
	if numero == 0 or not servidor() or not fruta_ativa() or not ator.corpo_livre_para_golpe():
		return false
	if paralelo:
		if sessao_de(numero) != null:
			return false
		toque = direcao
		_abrir_sessao(numero)   # a passiva (dash do toque duplo) não espera nem trava as técnicas
		return true
	if ativo:
		return false
	toque = direcao
	ativo = true
	acao += 1
	ator.set_meta(META, get_instance_id())
	executor.iniciar(numero)
	return true


func ficha_selecionada() -> Dictionary:
	for f: Dictionary in CatalogoFrutasMinePiece.FICHAS[fruta_id].ciclo:
		if int(f.numero) == selecao:
			return f
	return {}

func sessao_de(numero: int) -> SessaoDeTecnicaMinePiece:
	for s in sessoes:
		if s.numero == numero and not s.acabou:
			return s
	return null


## Abre a sessão de uma técnica SEM olhar o que as outras estão fazendo: só vale a recarga DELA, a energia e o corpo livre.
func comecar_paralela(numero: int, tecla := "") -> bool:
	if not servidor() or not fruta_ativa() or not ator.corpo_livre_para_golpe() or sessao_de(numero) != null:
		return false
	var f := {}
	for ficha_t: Dictionary in CatalogoFrutasMinePiece.FICHAS[fruta_id].ciclo:
		if int(ficha_t.numero) == numero:
			f = ficha_t
	if f.is_empty() or float(recargas.get(numero, 0.0)) > 0.0:
		return false
	var custo := float(f.custo_mod) * ENERGIA_POR_CUSTO
	if ator.energy + 0.001 < custo:
		return false
	ator.gastar_energia(custo)
	selecao = numero
	recarga_total = float(f.get("recarga", maxf(float(f.custo_mod) * 0.5, 5.0) * B.TICK))
	recargas[numero] = recarga_total
	_abrir_sessao(numero, tecla)
	return true


## Cria a sessão (executor próprio) e a põe para rodar; sem custo nem recarga — quem cobra é `comecar_paralela`.
func _abrir_sessao(numero: int, tecla := "") -> void:
	var s := SessaoDeTecnicaMinePiece.new()
	s.ctl = self
	s.numero = numero
	s.tecla = tecla
	s.recarga_total = recarga_total
	s.acao_inicial = acao
	var ex: Node = load(CatalogoFrutasMinePiece.FICHAS[fruta_id].executor).new()
	ex.c = s
	s.executor = ex
	s.add_child(ex)
	add_child(s)
	sessoes.append(s)
	executor = ex   # o da técnica mais recente (testes e HUD)
	ativo = true
	acao += 1
	ator.set_meta(META, get_instance_id())
	ex.iniciar(numero)


func _passo_paralelo() -> void:
	if sessoes.is_empty():
		return
	if not fruta_ativa() or ator.health <= 0.0 or not ator.corpo_livre_para_golpe():
		cancelar()
		return
	for s in sessoes.duplicate():
		s.lentidao = -1
		s.passo()
		if s.recarga > 0.0:   # a carga renova a recarga DESTA técnica, não a das outras
			recargas[s.numero] = maxf(float(recargas.get(s.numero, 0.0)), s.recarga)
			s.recarga = 0.0
		lentidao = maxi(lentidao, s.lentidao)
		if s.acabou:
			sessoes.erase(s)
			s.queue_free()
	if sessoes.is_empty():
		terminar()


func comecar() -> bool:
	if paralelo:
		return comecar_paralela(selecao)
	if not servidor() or not fruta_ativa() or ativo or not ator.corpo_livre_para_golpe():
		return false
	var f := ficha_selecionada()
	if f.is_empty():
		return false
	var direta := recarga_por_tecnica()
	if direta:
		if float(recargas.get(selecao, 0.0)) > 0.0:
			return false
	elif recarga > 0.0:
		return false
	if ator.energy + 0.001 < float(f.custo_mod) * ENERGIA_POR_CUSTO:
		return false
	ator.gastar_energia(float(f.custo_mod) * ENERGIA_POR_CUSTO)
	if corpo != null:
		corpo.desfazer()   # regra do dono: disparar uma técnica desfaz a transformação
	if direta:
		recarga_total = float(f.get("recarga", 1.0))
		recargas[selecao] = recarga_total
	else:
		recarga_total = maxf(float(f.custo_mod) * 0.5, 5.0) * B.TICK
		recarga = recarga_total
	ativo = true
	acao += 1
	ator.set_meta(META, get_instance_id())
	executor.iniciar(selecao)
	return true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ator):
		return
	if ator._is_authority and fruta_ativa():
		var com_shift := Input.is_key_pressed(KEY_SHIFT)
		if com_shift != shift:
			_pedir("shift", com_shift)
			shift = com_shift
		var com_s := Input.is_physical_key_pressed(KEY_S) and not ator._menu_de_tela_aberto()
		if com_s != tras:
			_pedir("tras", com_s)
			tras = com_s
		if CatalogoFrutasMinePiece.FICHAS[fruta_id].has("toque_duplo"):
			_ler_toque_duplo(delta)
	if paralelo:
		if is_instance_valid(_manutencao):
			_manutencao.manter()
	elif executor != null and executor.has_method("manter"):
		executor.manter()
	if servidor():
		_tempo += delta
		while _tempo >= B.TICK:
			_tempo -= B.TICK
			tick += 1
			recarga = maxf(0.0, recarga - B.TICK)
			for n in recargas.keys():
				recargas[n] = maxf(0.0, float(recargas[n]) - B.TICK)
			lentidao = -1
			impulso_ativo = false
			if corpo != null:
				corpo.observar(ator.health > 0.0)
			if paralelo:
				_passo_paralelo()
			elif ativo:
				if not fruta_ativa() or ator.health <= 0.0 or not ator.corpo_livre_para_golpe():
					cancelar()
				else:
					executor.passo()
	_aplicar_pose(delta)

func terminar() -> void:
	ativo = false
	segurando = false
	lentidao = -1
	impulso_ativo = false
	invisivel(false)
	_limpar_pose()

func cancelar() -> void:
	acao += 1
	if paralelo:
		for s in sessoes:
			s.cancelar()
			s.queue_free()
		sessoes.clear()
		if is_instance_valid(_manutencao):
			_manutencao.cancelar()
	elif is_instance_valid(executor):
		executor.cancelar()
	terminar()

func _exit_tree() -> void:
	cancelar()
	if corpo != null:
		corpo.desfazer()


## Gancho do `Player._physics_process`: técnica que pede Lentidão X prende o corpo;
## logia transformada voa.
func controla_movimento() -> bool:
	return fruta_ativa() and ((ativo and (lentidao >= 0 or impulso_ativo)) or (corpo != null and corpo.voando()))


func velocidade(delta: float, atual: Vector3, q: MoveFrame) -> Vector3:
	if ativo and impulso_ativo:
		return impulso
	if ativo and lentidao >= 0:
		var v := Player.SPEED * ator.speed_multiplier * maxf(0.0, 1.0 - 0.15 * float(lentidao + 1))
		return Vector3(q.dir.x * v, atual.y, q.dir.z * v)
	if corpo == null:
		return atual
	return corpo.velocidade(delta, q)

func _limpar_pose() -> void:
	_clipe = ""
	if is_instance_valid(ator) and int(ator.get_meta(META, 0)) == get_instance_id():
		ator.remove_meta(META)
		ator.remove_meta("pose_de_skill")
		ator.remove_meta("posicoes_mine_piece")

func pe() -> Vector3:
	for filho in ator.get_children():
		var cs := filho as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is CapsuleShape3D:
			return cs.global_position - Vector3.UP * cs.shape.height * 0.5 * cs.global_basis.get_scale().y
		if cs.shape is BoxShape3D:
			return cs.global_position - Vector3.UP * cs.shape.size.y * 0.5 * cs.global_basis.get_scale().y
	return ator.global_position - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)

## Para onde o jogador mira: o raio da câmera até o mundo, visto dos olhos. O raio começa NO PLANO DO JOGADOR, não na câmera
## (09/11/2026, "o personagem aponta para o lugar errado"): a câmera fica ~4 m atrás do ombro, e um inimigo colado em você ou uma
## parede às costas é "acertado" a 1–3 m da câmera — o ponto cai atrás do jogador e a direção `ponto − olhos` aponta para trás/para
## o lado. Quem está entre a câmera e o jogador não é alvo. Ponto colado nos olhos (< 0,3 m) cai na direção da câmera.
func olhar() -> Vector3:
	var olhos := pe() + Vector3.UP * B.m(B.OLHOS_JOGADOR)
	if is_instance_valid(ator._cam):
		var cam: Vector3 = ator._cam.global_position
		var frente: Vector3 = -ator._cam.global_basis.z
		var inicio := cam + frente * maxf(0.0, (olhos - cam).dot(frente))
		var ponto := AlvosDeGolpe.ponto_mirado(ator.get_world_3d(), inicio, frente, B.m(64.0), [ator.get_rid()])
		var d := ponto - olhos
		return d.normalized() if d.length() > 0.3 else frente
	return ator._mira_do_voo().normalized()

## A técnica acabou o gesto: o corpo volta à pose normal (sem terminar a técnica).
func pose_fim() -> void:
	_clipe = ""
	_limpar_pose()


## Clipe de um quadro só, criado em código (graus por papel do osso). A Luta usa para a pose de carga do X.
func registrar_pose(nome: String, rotacoes: Dictionary) -> void:
	var quadro := {}
	for papel: String in rotacoes:
		var v: Vector3 = rotacoes[papel]
		quadro[papel] = [v.x, v.y, v.z]
	_poses[nome] = {"duracao": 1.0, "fps": 1, "quadros": [quadro], "posicoes": [{}]}


## `reiniciar`: recomeça o clipe mesmo que seja o mesmo (cada soco da rajada da Luta).
func pose(nome: String, reiniciar := false) -> void:
	if nome != _clipe or reiniciar:
		_clipe = nome
		_clipe_t = 0.0

func _aplicar_pose(delta: float) -> void:
	if not ativo or _clipe.is_empty() or not _poses.has(_clipe):
		return
	_clipe_t += delta
	var clipe: Dictionary = _poses[_clipe]
	var quadro := mini(int(_clipe_t * float(clipe.fps)), clipe.quadros.size() - 1)
	var rotacoes := {}
	var posicoes := {}
	var peso := smoothstep(0.0, 0.08, _clipe_t)
	for papel: String in clipe.quadros[quadro]:
		var a: Array = clipe.quadros[quadro][papel]
		rotacoes[papel] = Vector3(a[0], a[1], a[2]) * PI / 180.0 * peso
	for papel: String in pose_extra:
		rotacoes[papel] = rotacoes.get(papel, Vector3.ZERO) + (pose_extra[papel] as Vector3) * PI / 180.0 * peso
	for papel: String in clipe.posicoes[quadro]:
		var a: Array = clipe.posicoes[quadro][papel]
		posicoes[papel] = Vector3(a[0], a[1], a[2]) * peso
	ator.set_meta("pose_de_skill", rotacoes)
	ator.set_meta("posicoes_mine_piece", posicoes)

## A técnica impõe a velocidade do corpo neste tick (blocos/tick do mod).
func impulsionar(blocos_por_tick: Vector3) -> void:
	impulso = blocos_por_tick * B.VELOCIDADE
	impulso_ativo = true


## MobEffect INVISIBILITY no dono (White Vine…): o modelo some para todos.
func invisivel(ligar: bool) -> void:
	if is_instance_valid(ator):
		if ligar:
			ator.set_meta(META_INVISIVEL, true)
		elif ator.has_meta(META_INVISIVEL):
			ator.remove_meta(META_INVISIVEL)


func estado_das_tecnicas() -> Array:
	var saida := []
	var direta := recarga_por_tecnica()
	var teclas: Dictionary = {}
	var mapa := mapa_de_teclas()
	for t: String in mapa:
		teclas[int(mapa[t])] = t
	for f: Dictionary in CatalogoFrutasMinePiece.FICHAS[fruta_id].ciclo:
		var custo := float(f.custo_mod) * ENERGIA_POR_CUSTO
		var espera := float(recargas.get(int(f.numero), 0.0)) if direta else recarga
		saida.append({"nome": f.nome, "selecionada": int(f.numero) == selecao, "custo": custo, "tecla": str(teclas.get(int(f.numero), "")),
			"recarga": espera, "recarga_total": float(f.get("recarga", 1.0)) if direta else maxf(float(f.custo_mod) * 0.5, 5.0) * B.TICK,
			"sem_energia": ator.energy + 0.001 < custo, "bloqueada": ator.max_energy + 0.001 < custo})
	return saida

func avisos() -> String:
	return ""
