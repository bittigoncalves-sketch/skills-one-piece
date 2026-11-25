class_name McMundo
extends Node
# ============================================================================
#  O `Level`/`ServerLevel` do Minecraft que as procedures recebem como `world` (E1). Um por
#  cena (`Mc.mundo(tree)`). Conta os ticks (20/s) e anda os efeitos das entidades adaptadas.
#  Busca em área: os corpos do jogo nos grupos "player" e de alvos de golpe.
#  O que ainda não existe (som, partícula, explosão, comandos, blocos) é CONTADO em
#  `Mc.pedidos_sem_implementacao` — a próxima fatia da E1.
# ============================================================================

const TICK := MundoMinePiece.TICK
const GRUPOS_DE_ENTIDADE := ["player", AlvosDeGolpe.GRUPO, McCorpoDoMod.GRUPO]

## A árvore da cena: vale antes de o nó entrar nela (o `Mc.mundo` adiciona no quadro seguinte).
var arvore: SceneTree
var _entidades: Array[McEntidade] = []
var _acumulado := 0.0
var tempo_de_jogo := 0


func registrar(e: McEntidade) -> void:
	if not _entidades.has(e):
		_entidades.append(e)


func _physics_process(delta: float) -> void:
	_acumulado += delta
	while _acumulado >= TICK:
		_acumulado -= TICK
		tick()


## Um tick do Minecraft (público para os testes andarem o tempo exato).
func tick() -> void:
	tempo_de_jogo += 1
	_estados.clear()
	info_de_celulas.clear()
	var vivas: Array[McEntidade] = []
	var t_ef := Cronometro.ini()
	for e in _entidades:
		if e.valida():
			e.tick_efeitos()
			vivas.append(e)
	_entidades = vivas
	Cronometro.fim(&"McMundo.tick_efeitos_total", t_ef)
	_rodar_agendadas()
	var t_bl := Cronometro.ini()
	blocos.tick(tempo_de_jogo)
	relevo.tick(tempo_de_jogo)
	Cronometro.fim(&"McMundo.blocos_e_relevo_tick", t_bl)
	_estados.clear()
	info_de_celulas.clear()


## `MinepieceMod.queueServerWork(ticks, acao)` — a fila de trabalho do servidor do mod (MinepieceMod.java).
## Fiel ao original: a cada FIM de tick todo item perde 1; quem chega a EXATAMENTE 0 roda, na ordem em que
## entrou, e sai da fila. Trabalho agendado durante a execução só começa a contar no tick seguinte, e
## `ticks <= 0` nunca roda (o contador passa direto do 0) — o mod é assim, e as procedures dependem disso.
## Blocos que as técnicas colocam (sobreposição sobre o relevo): ver `McBlocosDinamicos`.
var blocos := McBlocosDinamicos.new(self)
## Crateras no relevo das ilhas (reversíveis): ver `McRelevoCavavel`.
var relevo := McRelevoCavavel.new(self)
var _agendadas: Array = []                  # [Callable, ticks_restantes]


func queueServerWork(ticks: int, acao: Callable) -> void:
	_agendadas.append([acao, ticks])


func _rodar_agendadas() -> void:
	var prontas: Array = []
	for w in _agendadas:
		w[1] -= 1
		if w[1] == 0:
			prontas.append(w)
	for w in prontas:
		(w[0] as Callable).call()
	for w in prontas:
		_agendadas.erase(w)


# ------------------------------------------------------------ identidade do mundo
func isClientSide() -> bool: return false
func registryAccess() -> McMundo: return self
func registryOrThrow(chave: Variant) -> McRegistro: return McRegistro.de(str(chave).to_upper())
func registry(chave: Variant) -> McEntidade.Opcional:
	var o := McEntidade.Opcional.new()
	o.valor = registryOrThrow(chave)
	return o


## `noCollision(entidade)` / `noCollision(entidade, caixa)` / `noCollision(caixa)`: a caixa não toca o mundo.
func noCollision(a: Variant, b: Variant = null) -> bool:
	var caixa: McAabb = b if b is McAabb else (a if a is McAabb else (a as McEntidade).getBoundingBox())
	var tam := (caixa.max_.para_godot() - caixa.min_.para_godot()).abs()
	if tam.length_squared() < 0.000001:
		return true
	var forma := BoxShape3D.new()
	forma.size = tam
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), caixa.getCenter().para_godot())
	q.collision_mask = MundoMinePiece.MASCARA_MUNDO
	if a is McEntidade and (a as McEntidade).no is CollisionObject3D:
		q.exclude = [((a as McEntidade).no as CollisionObject3D).get_rid()]
	return arvore.root.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
func dimension() -> StringName: return &"minecraft:overworld"
func getGameTime() -> int: return tempo_de_jogo
func getDayTime() -> int: return tempo_de_jogo
func getServer() -> McMundo: return self
func getLevel() -> McMundo: return self
func damageSources() -> McFonteDeDano.Fontes: return McFonteDeDano.Fontes.new()
func getRandom() -> McAleatorio: return McAleatorio.de()


# ------------------------------------------------------------ entidades
## FOTO DAS CAIXAS (09/11/2026): `getEntitiesOfClass` varria TODAS as entidades do mapa e refazia a caixa de cada uma (alocações de McVec3/McAabb,
## ficha, escala) a cada consulta. O X do Batto Batto faz ~53 consultas por tick (lâminas × passos): no mapa real eram 2,2 ms por consulta e o jogo
## caía de 60 para ~8 FPS. Agora a caixa de cada corpo é calculada uma vez por quadro de física; a foto é refeita se o quadro mudou, se a
## quantidade de corpos nos grupos mudou (spawn/morte). Posição escrita pelo mod (`teleportTo`/`setPos`/`connection.teleport`) atualiza SÓ a caixa de quem
## se mexeu (`foto_atualizar`): a lâmina do X se teleporta 3× por passo, e invalidar a foto inteira a cada vez anulava o ganho.
var _foto_indice: Dictionary = {}       # McEntidade → posição em `_foto`
var _foto_quadro := -1
var _foto_contagem := -1
var _foto: Array = []                   # [McEntidade, McAabb]


func _contagem_dos_grupos() -> int:
	var n := 0
	for grupo in GRUPOS_DE_ENTIDADE:
		n += arvore.get_node_count_in_group(grupo)
	return n


func _foto_das_entidades() -> Array:
	var quadro := Engine.get_physics_frames()
	var contagem := _contagem_dos_grupos()
	if quadro == _foto_quadro and contagem == _foto_contagem:
		return _foto
	_foto_quadro = quadro
	_foto_contagem = contagem
	_foto = []
	_foto_indice.clear()
	var vistos := {}
	for grupo in GRUPOS_DE_ENTIDADE:
		for no in arvore.get_nodes_in_group(grupo):
			if not (no is Node3D) or vistos.has(no) or not is_instance_valid(no) or no.is_queued_for_deletion():
				continue
			vistos[no] = true
			var e := McEntidade.de(no)
			_foto_indice[e] = _foto.size()
			_foto.append([e, e.getBoundingBox()])
	return _foto


## O mod escreveu a posição de `e`: refaz só a caixa dele na foto do quadro (se ele estiver nela).
func foto_atualizar(e: McEntidade) -> void:
	var i: Variant = _foto_indice.get(e)
	if i != null and int(i) < _foto.size():
		_foto[int(i)][1] = e.getBoundingBox()


## `getEntitiesOfClass(Classe.class, caixa, filtro)`: corpos cuja caixa toca a caixa pedida.
func getEntitiesOfClass(classe: Variant, caixa: McAabb, filtro: Variant = null) -> Array:
	var t_e := Cronometro.ini()
	var r := _getEntitiesOfClass(classe, caixa, filtro)
	Cronometro.fim(&"McMundo.getEntitiesOfClass", t_e)
	return r


func _getEntitiesOfClass(classe: Variant, caixa: McAabb, filtro: Variant = null) -> Array:
	Mc.contar("busca:" + str(classe))
	var saida := []
	for par in _foto_das_entidades():
		if not (par[1] as McAabb).intersects(caixa):
			continue
		var e: McEntidade = par[0]
		if not e.valida():
			continue
		if classe != null and not Mc.e(e, StringName(str(classe))):
			continue
		if filtro is Callable and not (filtro as Callable).call(e):
			continue
		saida.append(e)
	return saida


func getAdvancements() -> McConquistas.Registro: return McConquistas.Registro.new()


## `server.getPlayerList()` / `level.players()` (pacote de servidor: ver `McServidor`).
func getPlayerList() -> McServidor.ListaDeJogadores:
	var l := McServidor.ListaDeJogadores.new()
	l.mundo = self
	return l


func players() -> Array:
	var saida := []
	for no in arvore.get_nodes_in_group("player"):
		if no is Node3D and is_instance_valid(no) and not no.is_queued_for_deletion():
			saida.append(McEntidade.de(no))
	return saida


## `server.getLootData()`: as loot tables do mod (ver `McLoot`).
func getLootData() -> McLoot.Dados: return McLoot.Dados.new()


## O jogo não tem entidades de bloco (baús, spawners do mod): quem pergunta recebe `null`, como o Minecraft para bloco sem entidade.
func getBlockEntity(_pos: Variant) -> Variant: return null
func sendBlockUpdated(_pos: Variant, _antes: Variant = null, _depois: Variant = null, _flags: Variant = 3) -> void: pass
func getDifficulty() -> StringName: return &"NORMAL"


## `ServerLevel.getAllEntities()`: todas as entidades vivas da cena.
func getAllEntities() -> Array:
	var saida := []
	var vistos := {}
	for grupo in GRUPOS_DE_ENTIDADE:
		for no in arvore.get_nodes_in_group(grupo):
			if no is Node3D and not vistos.has(no) and is_instance_valid(no) and not no.is_queued_for_deletion():
				vistos[no] = true
				saida.append(McEntidade.de(no))
	return saida


func getEntities(_quem: Variant, caixa: McAabb, filtro: Variant = null) -> Array:
	return getEntitiesOfClass(&"Entity", caixa, filtro)


# ------------------------------------------------------------ variáveis do mod (SavedData)
var _variaveis := {}


## `MapVariables`/`WorldVariables` deste mundo (uma instância cada, com os padrões do mod).
func variaveis(tipo: String) -> Variant:
	if not _variaveis.has(tipo):
		_variaveis[tipo] = McVariaveisDoMod.MapVariables.new() if tipo == "MapVariables" else McVariaveisDoMod.WorldVariables.new()
	return _variaveis[tipo]


# ------------------------------------------------------------ regras de jogo (GameRules)
## As do mod com o padrão do mod (`McVariaveisDoMod.REGRAS`); as vanilla que o mod lê, com o padrão
## do Minecraft. `getRule(r).get()` passa por `Mc.obter0` → `obter()`.
const REGRAS_VANILLA := {&"RULE_MOBGRIEFING": true, &"RULE_DOFIRETICK": true, &"RULE_KEEPINVENTORY": false,
	&"RULE_DOBLOCKDROPS": true, &"RULE_DOMOBLOOT": true, &"RULE_DOENTITYDROPS": true,
	&"RULE_DOMOBSPAWNING": true, &"RULE_NATURAL_REGENERATION": true, &"RULE_DAYLIGHT": true}


class ValorDeRegra:
	extends RefCounted
	var mundo: McMundo
	var regra: StringName
	func obter() -> Variant: return mundo.valor_da_regra(regra)
	func definir(v: Variant) -> void: mundo._regras[regra] = v
	func getValue() -> Variant: return obter()


var _regras := {}


func valor_da_regra(r: StringName) -> Variant:
	if _regras.has(r):
		return _regras[r]
	if McVariaveisDoMod.REGRAS.has(r):
		return McVariaveisDoMod.REGRAS[r]
	if REGRAS_VANILLA.has(r):
		return REGRAS_VANILLA[r]
	Mc._falta("regra", String(r))
	return false


func getLevelData() -> McMundo: return self
func getGameRules() -> McMundo: return self
func getBoolean(r: Variant) -> bool: return bool(valor_da_regra(StringName(str(r))))
func getInt(r: Variant) -> int: return int(valor_da_regra(StringName(str(r))))
func getRule(r: Variant) -> ValorDeRegra:
	var v := ValorDeRegra.new()
	v.mundo = self
	v.regra = StringName(str(r))
	return v


# ------------------------------------------------------------ placar (times = tripulação do mod)
## `Scoreboard` do Minecraft: times por NOME, com membros por nome (jogador) ou UUID (os outros). O mod cria
## e preenche os times sozinho (bandeira pirata, marinha…); aqui só guardamos o estado como o Minecraft.
## (Ligar o time do mod à tripulação do jogo é decisão à parte — ver o checkpoint.)
class Equipe:
	extends RefCounted
	var nome := ""
	var membros: Array = []
	func getName() -> String: return nome
	func getPlayers() -> Array: return membros
	func getColor() -> String: return "reset"
	func setColor(_c: Variant = null) -> void: pass
	func setAllowFriendlyFire(_b: Variant = true) -> void: pass
	func setSeeFriendlyInvisibles(_b: Variant = true) -> void: pass
	func setDisplayName(_t: Variant = null) -> void: pass
	func setPlayerPrefix(_t: Variant = null) -> void: pass


class Placar:
	extends RefCounted
	var equipes := {}
	## Time DO JOGADOR/ENTIDADE `nome` (ou null).
	func getPlayersTeam(nome: Variant) -> Variant:
		for e: Equipe in equipes.values():
			if str(nome) in e.membros:
				return e
		return _equipe_do_jogo(str(nome))

	## Os times que o JOGO já tem (decisão: facção do jogo → time do mod): o jogador e os personagens da facção
	## "aliado" (a tag group_1 do mod: Luffy, Zoro, Sanji…) são UMA tripulação. Sem isso o mod ferira o próprio
	## aliado, porque quem o põe no time do jogador é o recrutamento do mod, que o jogo não usa.
	const TRIPULACAO_DO_JOGADOR := "tripulacao_do_jogador"
	var _tripulacao: Equipe
	func _equipe_do_jogo(nome: String) -> Variant:
		var arvore := Engine.get_main_loop() as SceneTree
		if arvore == null:
			return null
		var no: Node = null
		# Jogador primeiro: o nome dele pode ser só dígitos (o id do peer, "1"), igual a um id de instância.
		for j in arvore.get_nodes_in_group("player"):
			if McEntidade.de(j).getName().getString() == nome:
				no = j
				break
		if no == null and nome.is_valid_int():
			no = instance_from_id(int(nome)) as Node
		if no == null or not is_instance_valid(no):
			return null
		var aliado: bool = no.is_in_group("player") \
			or (no.get("ficha") is Dictionary and str((no.get("ficha") as Dictionary).get("faccao", "")) == "aliado")
		if not aliado:
			return null
		if _tripulacao == null:
			_tripulacao = Equipe.new()
			_tripulacao.nome = TRIPULACAO_DO_JOGADOR
		return _tripulacao
	## Time pelo NOME DO TIME (ou null).
	func getPlayerTeam(nome_do_time: Variant) -> Variant: return equipes.get(str(nome_do_time), null)
	func addPlayerTeam(nome_do_time: Variant) -> Equipe:
		var n := str(nome_do_time)
		if not equipes.has(n):
			var e := Equipe.new()
			e.nome = n
			equipes[n] = e
		return equipes[n]
	func addPlayerToTeam(nome: Variant, equipe: Variant) -> bool:
		if not (equipe is Equipe):
			return false
		var atual: Variant = getPlayersTeam(nome)
		if atual != null:
			(atual as Equipe).membros.erase(str(nome))
		(equipe as Equipe).membros.append(str(nome))
		return true
	func removePlayerFromTeam(nome: Variant, equipe: Variant) -> void:
		if equipe is Equipe:
			(equipe as Equipe).membros.erase(str(nome))
	func getPlayerTeams() -> Array: return equipes.values()
	func removePlayerTeam(equipe: Variant) -> void:
		if equipe is Equipe:
			equipes.erase((equipe as Equipe).nome)


var _placar := Placar.new()
func getScoreboard() -> Placar: return _placar


# ------------------------------------------------------------ ainda não implementado (contado)
## Efeito de nível (`LevelEvent`): 2001 = bloco quebrando (som do bloco + poeira). Os outros tipos continuam contados.
func levelEvent(tipo: Variant = 0, pos: Variant = null, _dado: Variant = 0) -> void:
	if int(tipo) == 2001 and pos is McVec3:
		McVisual.som(arvore, "minecraft:block.stone.break", pos, 1.0, 1.0)
		McVisual.particula(arvore, "minecraft:block", pos, 12, 0.35, 0.35, 0.35, 0.15)
		return
	Mc._falta("visual", "levelEvent:" + str(tipo))


## `playSound(jogador, posição, som, fonte, volume, tom)`; o desenho/áudio é do `McVisual` (nome → arquivo do jar).
func playSound(_a: Variant = null, pos: Variant = null, som: Variant = null, _d: Variant = null, vol: Variant = 1.0,
		tom: Variant = 1.0) -> void:
	var p: McVec3 = pos if pos is McVec3 else null
	if som == null or not McVisual.som(arvore, str(som), p, float(vol), float(tom)):
		Mc._falta("som", str(som))


func playLocalSound(x: Variant = 0.0, y: Variant = 0.0, z: Variant = 0.0, som: Variant = null, _e: Variant = null,
		vol: Variant = 1.0, tom: Variant = 1.0, _h: Variant = null) -> void:
	if som == null or not McVisual.som(arvore, str(som), McVec3.de(float(x), float(y), float(z)), float(vol), float(tom)):
		Mc._falta("som", str(som))


func sendParticles(particula: Variant, x: float = 0, y: float = 0, z: float = 0, n: int = 0, dx: float = 0,
		dy: float = 0, dz: float = 0, vel: float = 0) -> int:
	var t_sp := Cronometro.ini()
	var r := _sendParticles(particula, x, y, z, n, dx, dy, dz, vel)
	Cronometro.fim(&"McMundo.sendParticles", t_sp)
	return r


func _sendParticles(particula: Variant, x: float, y: float, z: float, n: int, dx: float, dy: float, dz: float, vel: float) -> int:
	if particula == null or not McVisual.particula(arvore, str(particula), McVec3.de(x, y, z), n, dx, dy, dz, vel):
		Mc._falta("particula", str(particula))
		return 0
	return maxi(n, 1)


## `level.explode(quem, x, y, z, força, …)`: o dano e o empurrão de entidade do `Explosion` do Minecraft
## (raio 2 × força; impacto = (1 − d/raio) × exposição; dano = (i² + i)/2 × 7 × raio + 1; exposição = 1:
## sem o raycast de blocos). Quebrar blocos e o desenho ficam para as fatias de blocos/visual (contados).
func explode(quem: Variant = null, x: Variant = 0.0, y: Variant = 0.0, z: Variant = 0.0, forca: Variant = 0.0,
		_a: Variant = null, _b: Variant = null) -> void:
	# Sobrecargas: explode(quem, x, y, z, força, interação) e explode(quem, fonte, calc, x, y, z, força, fogo, interação).
	var args := [x, y, z, forca, _a, _b]
	while not args.is_empty() and not (args[0] is float or args[0] is int):
		args.pop_front()
	if args.size() < 4:
		Mc._falta("mundo", "explode (formato)")
		return
	var centro := McVec3.de(float(args[0]), float(args[1]), float(args[2]))
	var raio := 2.0 * float(args[3])
	var autor: McEntidade = quem if quem is McEntidade else null
	for e: McEntidade in getEntitiesOfClass(&"Entity", McAabb.de_tamanho(centro, raio * 2.0, raio * 2.0, raio * 2.0)):
		var d := sqrt(e.position().distanceToSqr(centro)) / raio
		if d > 1.0 or e == autor:
			continue
		var impacto := 1.0 - d
		e.hurt(McFonteDeDano.de(&"minecraft:explosion", autor), floorf((impacto * impacto + impacto) / 2.0 * 7.0 * raio + 1.0))
		var dir := e.position().subtract(centro).normalize()
		e.push(dir.scale(impacto))
	McVisual.particula(arvore, "minecraft:explosion", centro, 6, raio * 0.3, raio * 0.3, raio * 0.3, 0.1)
	McVisual.particula(arvore, "minecraft:flash", centro, 1, 0.0, 0.0, 0.0, 0.0)
	McVisual.som(arvore, "entity.generic.explode", centro, minf(float(args[3]), 2.0), 1.0)


## O corpo virtual já nasce no mundo (`McTipoEntidade.create`): adicionar de novo não faz nada.
func addFreshEntity(e: Variant) -> bool:
	return e is McEntidade and (e as McEntidade).valida()


## Só leitura (ver `McBloco`): o cubo do bloco tem colisão? → pedra; abaixo do mar → água; senão ar.
## CACHE DO ESTADO DE BLOCO (09/11/2026): as lâminas do X do Batto Batto varrem cubos sobrepostos (`BlockDestroyAllDirection`, ~150 chamadas por
## tick, cada uma com dezenas de células, várias vezes a MESMA célula) e cada consulta custava ~6 µs. O estado de uma célula só muda por
## `setBlock` ou pelo `tick` de `blocos`/`relevo` (expiração/cratera que se refaz): o cache vale por quadro de física e é zerado nesses pontos.
var _estados: Dictionary = {}                # Vector3i → McBloco.Estado
var _estados_quadro := -1
## Classificação da célula para quem varre cubos (`BlockDestroyAllDirection`, versão otimizada): Vector3i → [estado, dureza ajustada, líquido?]
## ou `true` para vazia. É intrínseca da célula (não depende de quem pergunta), vale por tick e é refeita célula a célula no `setBlock`.
var info_de_celulas: Dictionary = {}


func _estado_pronto() -> void:
	var quadro := Engine.get_physics_frames()
	if quadro != _estados_quadro:
		_estados_quadro = quadro
		_estados.clear()
		info_de_celulas.clear()


func getBlockState(pos: Variant) -> McBloco.Estado:
	var t_bs := Cronometro.ini()
	Cronometro.amostrar(&"getBlockState")
	var r := _getBlockState(pos)
	Cronometro.fim(&"McMundo.getBlockState", t_bs)
	return r


func _getBlockState(pos: Variant) -> McBloco.Estado:
	var p := pos as McVec3
	if p == null or arvore == null or arvore.root.get_world_3d() == null:
		return McBloco.Estado.de(Mc.bloco(&"minecraft:air"))
	_estado_pronto()
	var cel: Vector3i = McBlocosDinamicos.celula(p)
	var guardado: Variant = _estados.get(cel)
	if guardado != null:
		return guardado
	var estado: McBloco.Estado
	var sobreposto := blocos.id_em(cel)
	if sobreposto != &"":
		estado = McBloco.Estado.de(Mc.bloco(sobreposto))
	elif _terreno_solido(p):
		estado = McBloco.Estado.de(Mc.bloco(&"minecraft:stone"))
	else:
		var centro := Vector3(floorf(p.x) + 0.5, floorf(p.y) + 0.5, floorf(p.z) + 0.5) * MundoMinePiece.METROS_POR_BLOCO
		estado = McBloco.Estado.de(Mc.bloco(&"minecraft:water" if centro.y < 0.0 else &"minecraft:air"))
	_estados[cel] = estado
	return estado


## O RELEVO (não os blocos dinâmicos) tem algo sólido nesta célula? Pela física do jogo.
func _terreno_solido(p: McVec3) -> bool:
	var t_ts := Cronometro.ini()
	var r := _terreno_solido_medido(p)
	Cronometro.fim(&"McMundo.terreno_solido", t_ts)
	return r


func _terreno_solido_medido(p: McVec3) -> bool:
	return _terreno_solido_celula(McBlocosDinamicos.celula(p))


func _terreno_solido_celula(cel: Vector3i) -> bool:
	var da_ilha := relevo.terra_em(cel)
	if da_ilha != -1:
		return da_ilha == 1                      # ilha: o mapa de alturas manda (a malha é uma casca)
	var centro := (Vector3(cel) + Vector3.ONE * 0.5) * MundoMinePiece.METROS_POR_BLOCO
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * MundoMinePiece.METROS_POR_BLOCO * 0.98
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), centro)
	q.collision_mask = MundoMinePiece.MASCARA_MUNDO
	for r in arvore.root.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c := r.collider as Node
		if c != null and not c.has_meta("bloco_mc"):         # blocos dinâmicos são lidos pelo `blocos`
			return true
	return false


## `getBlockState` PELA CÉLULA (11/11/2026): o mesmo estado e o mesmo cache por quadro, sem montar `McVec3`/`BlockPos` — para as varreduras de cubo do mod
## (`BlockDestroyAllDirection` otimizada), onde esse custo se repete dezenas de milhares de vezes por quadro.
func estado_da_celula(cel: Vector3i) -> McBloco.Estado:
	var t_bs := Cronometro.ini()
	Cronometro.amostrar(&"getBlockState")
	var r := _estado_da_celula(cel)
	Cronometro.fim(&"McMundo.getBlockState", t_bs)
	return r


func _estado_da_celula(cel: Vector3i) -> McBloco.Estado:
	if arvore == null or arvore.root.get_world_3d() == null:
		return McBloco.Estado.de(Mc.bloco(&"minecraft:air"))
	_estado_pronto()
	var guardado: Variant = _estados.get(cel)
	if guardado != null:
		return guardado
	var estado: McBloco.Estado
	var sobreposto := blocos.id_em(cel)
	if sobreposto != &"":
		estado = McBloco.Estado.de(Mc.bloco(sobreposto))
	elif _terreno_solido_celula(cel):
		estado = McBloco.Estado.de(Mc.bloco(&"minecraft:stone"))
	else:
		var centro_y := (float(cel.y) + 0.5) * MundoMinePiece.METROS_POR_BLOCO
		estado = McBloco.Estado.de(Mc.bloco(&"minecraft:water" if centro_y < 0.0 else &"minecraft:air"))
	_estados[cel] = estado
	return estado


func getFluidState(pos: Variant) -> McBloco.Estado: return getBlockState(pos)
func isEmptyBlock(pos: Variant) -> bool: return getBlockState(pos).isAir()
## `level.setBlock(pos, estado, flags)`. Ar tira o bloco dinâmico, ou CAVA o relevo da ilha (`McRelevoCavavel`, cratera que se refaz);
## qualquer outro bloco entra na sobreposição (sólido ou não, conforme `McBlocosDinamicos`). Sobre relevo
## sólido não se desenha nada (o terreno já está ali) — conta como feito, como no Minecraft.
func setBlock(pos: Variant, estado: Variant, _flags: int = 3) -> bool:
	var t_sb := Cronometro.ini()
	var r := _setBlock(pos, estado, _flags)
	Cronometro.fim(&"McMundo.setBlock", t_sb)
	return r


func _setBlock(pos: Variant, estado: Variant, _flags: int = 3) -> bool:
	var p := pos as McVec3
	if p == null or not (estado is McBloco.Estado):
		return false
	var id: StringName = (estado as McBloco.Estado).bloco.id
	var c := McBlocosDinamicos.celula(p)
	_estados.erase(c)                            # o estado de uma célula só muda aqui (e nos ticks de `blocos`/`relevo`, que zeram tudo)
	info_de_celulas.erase(c)
	if id == &"minecraft:air":
		if blocos.remover(c):
			return true
		if _terreno_solido(p):
			if relevo.ilha_em(c) != null:
				relevo.cavar(c)
			else:
				Mc._falta("bloco", "cavar_fora_de_ilha")
		return true
	if blocos.id_em(c) == &"" and _terreno_solido(p):
		Mc._falta("bloco", "sobre_relevo")
		return true
	return blocos.colocar(c, id)
func setBlockAndUpdate(pos: Variant, estado: Variant) -> bool: return setBlock(pos, estado, 3)
func removeBlock(pos: Variant, _movido: Variant = false) -> bool: return setBlock(pos, McBloco.Estado.de(Mc.bloco(&"minecraft:air")), 3)
func destroyBlock(pos: Variant, _soltar: Variant = false, _quem: Variant = null) -> bool:
	return setBlock(pos, McBloco.Estado.de(Mc.bloco(&"minecraft:air")), 3)


## `level.clip(new ClipContext(de, até, bloco, fluido, entidade))`: raycast pela física do jogo.
class Raio:
	extends RefCounted
	var inicio := McVec3.new()
	var fim := McVec3.new()
	var quem: McEntidade
	static func de(args: Array) -> Raio:
		var r := Raio.new()
		r.inicio = args[0]
		r.fim = args[1]
		r.quem = args[4] if args.size() > 4 and args[4] is McEntidade else null
		return r


class Acerto:
	extends RefCounted
	var ponto := McVec3.new()
	var tipo: StringName = &"MISS"
	func getLocation() -> McVec3: return ponto
	func getBlockPos() -> McVec3: return ponto.containing()
	func getType() -> StringName: return tipo


func clip(r: Raio) -> Acerto:
	var a := Acerto.new()
	a.ponto = r.fim
	var q := PhysicsRayQueryParameters3D.create(r.inicio.para_godot(), r.fim.para_godot(), MundoMinePiece.MASCARA_MUNDO)
	if r.quem != null and r.quem.no is CollisionObject3D:
		q.exclude = [(r.quem.no as CollisionObject3D).get_rid()]
	var h := arvore.root.get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		a.ponto = McVec3.de_godot(h["position"])
		a.tipo = &"BLOCK"
	return a


## `level.getEntity(uuid ou id)`: o UUID da camada é o id de instância do corpo.
func getEntity(id: Variant) -> McEntidade:
	var n := int(str(id)) if str(id).is_valid_int() else 0
	if n == 0 or not is_instance_id_valid(n):
		return null
	var o := instance_from_id(n)
	return McEntidade.de(o) if o is Node3D else null


## `getServer().getCommands()` → este mesmo objeto; `performPrefixedCommand(fonte, texto)`.
func getCommands() -> McMundo: return self
func performPrefixedCommand(fonte: Variant, comando: String) -> int:
	return McComandos.executar(fonte, comando)
