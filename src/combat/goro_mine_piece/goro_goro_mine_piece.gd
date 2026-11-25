class_name GoroGoroMinePiece
extends Node
# ============================================================================
#  GORO GORO (MINE PIECE) — a Goro Goro no Mi do Mine Piece v14, importada por
#  tradução de código (18/10/2026, pedido do dono). Não passa pelo Skills Builder.
#
#  Filho do Player enquanto ele come a fruta (`ModoHistoria.equipar_fruta`).
#  Teclas do mod "por enquanto" (decisão do dono): R troca a técnica selecionada
#  (Shift+R volta, como agachado no mod), Z usa — segurar Z carrega, soltar dispara.
#  Shift no disparo do El Thor faz o pilar cair do céu (ElThorFall).
#  Eventos do mod que o jogo não tinha e que foram criados aqui:
#    • toque duplo em W/S → a passiva 28 (teleporte elétrico, sem custo);
#    • defesa perfeita → Kari Krash (27): o aparo do combate direcional (`aparou`);
#    • efeito MAMARAGAN (60 s de tempestade) e a técnica 29 que só existe com ele;
#    • a recarga GLOBAL do mod (COOLDOWN_TIME: nenhuma técnica enquanto corre) e o
#      `invulnerableTime` do Minecraft por alvo (`MundoMinePiece`).
#  Regra do Skills One Piece por cima (dono, 18/10/2026): a transformação elemental
#  das logias (`TransformacaoElemental`) com o voo das logias do mod — REMOVIDA em 24/11/2026 (`SEM_LOGIA`):
#  a Goro refatorada não vira raio nem voa à força; fica a aura da Mamaragan.
#  24/11/2026: técnicas em PARALELO — cada tecla abre uma `SessaoGoroMinePiece` com o próprio `D`, `z` e recarga
#  (`recargas`); `D` do controlador espelha a sessão mais recente (testes e HUD leem `D.skill`).
#
#  Economia (energia = custo do mod, sem conversão desde 27/10/2026; antes / 100: Vari 2,
#  El Thor e Sango 4, Mamaragan 8, Raigo 15); recarga = max(custo × 0,5, 5) ticks
#  (StartCursedTechniqueProcedure). Dano: ver `MundoMinePiece` e `Balance`.
#  Sem a trava de grau (advancements grade_*) do mod: o custo de energia é a trava.
#  O ataque físico do ciclo do R no mod (número 1, os socos) fica fora: o clique já é.
#  Decide tudo no servidor; em rede, o dono só manda as teclas (`_pedido`).
# ============================================================================

## Sem transformação elemental nem voo forçado (decisão do dono, 24/11/2026). GATILHO: se o dono quiser a regra de volta, trocar para false.
const SEM_LOGIA := true
const ID := "goro_goro_mine_piece"
const NOME := "Goro Goro (Mine Piece)"
const META_ATIVA := "combate_mine_piece"
const META_INVISIVEL := "goro_mp_invisivel"
const POSES := "res://assets/mine_piece/goro/poses.json"
const Tecnicas := preload("res://src/combat/goro_mine_piece/tecnicas_goro_mine_piece.gd")
const Meteoro := preload("res://src/combat/goro_mine_piece/meteoro_raigo.gd")
const Onda := preload("res://src/combat/goro_mine_piece/onda_de_impacto.gd")
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")

## A ordem do R (KeyChangeTechniqueDevilFruitLogiaProcedure, Goro Goro) e o custo do mod.
const CICLO := [
	{"numero": 21, "nome": "Vari", "custo": 200.0},
	{"numero": 22, "nome": "El Thor", "custo": 400.0},
	{"numero": 23, "nome": "Sango", "custo": 400.0},
	{"numero": 25, "nome": "Mamaragan", "custo": 800.0},
	{"numero": 29, "nome": "Raigo", "custo": 1500.0},
]
## Energia = custo do mod, sem conversão (A9, 27/10/2026; era 0,1 desde 23/10 e / 100 antes).
const ENERGIA_POR_CUSTO := 1.0
## MamaraganProcedure: MobEffectInstance(MAMARAGAN, 1200 ticks).
const DURACAO_MAMARAGAN := 1200 * B.TICK
## PlayerTickEvent2: o toque duplo é lido a cada 2 ticks com janela 3.
const JANELA_TOQUE_DUPLO := 3.0

var ator: Player
var D := {"skill": 0}
var tick := 0
var z := false               # PRESS_Z
var s := false               # PRESS_S
var shift := false           # isShiftKeyDown
var selecao := 21
var recarga := 0.0              # a maior recarga em curso (resumo para testes/HUD); a de cada técnica está em `recargas`
var recarga_total := 0.0
var recargas := {}              # número da técnica → segundos que faltam
var sessoes: Array = []         # SessaoGoroMinePiece em curso
var mamaragan := 0.0
var imunidade := {}
## O tamanho do jogador no mod (ReturnEntitySizeProcedure): ≈ 1.
var r := B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)
var tecnicas: TecnicasGoroMinePiece
var elemental := TransformacaoElemental.new()
var voo := VooLogiaMinePiece.new()

var _acumulado := 0.0
var _travado := false
var _parado := false
var _meio := Vector3.ZERO
var _flags := {"w": 0.0, "s": 0.0}
var _tick_local := 0
var _acumulado_local := 0.0
var _voo_tick := 0
var _voo_acumulado := 0.0
var _velocidade_antes := 1.0
var _clipe := ""
var _clipe_t := 0.0
var _invisivel_ate := 0.0
var _aparo_ligado: Object = null
static var _brilho_de_raio: ShaderMaterial
static var _poses: Dictionary = {}


## A ficha da fruta no Modo História: só energia e regeneração. As técnicas não estão
## nela (não usam Z/X/C/V da arena): a HUD lê `estado_das_tecnicas()`.
static func perfil() -> PerfilDeFrutas:
	var p := PerfilDeFrutas.new()
	p.fruta = ID
	p.regen_de_energia = PerfilDeFrutas.REGEN_DA_ARENA
	p.escala_de_dano = PerfilDeFrutas.ESCALA_DO_MOD
	p.fiel_ao_mod = true
	return p


static func de(jogador: Node) -> GoroGoroMinePiece:
	return jogador.get_node_or_null("GoroGoroMinePiece") as GoroGoroMinePiece if jogador != null else null


func _ready() -> void:
	ator = get_parent() as Player
	tecnicas = Tecnicas.new(self)
	if _poses.is_empty() and FileAccess.file_exists(POSES):
		_poses = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	_meio = ator.global_position - _pe_do_colisor()
	_velocidade_antes = ator.speed_multiplier


func _exit_tree() -> void:
	if elemental.ativa:
		_desfazer_elemental()
	_limpar_corpo()


func servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## A fruta está comida e o item dela ativo na barra?
func fruta_ativa() -> bool:
	return is_instance_valid(ator) and ator.current_fruit_id == ID and ator.capacidades.can_use_fruit


# ------------------------------------------------------------------ teclas
## R: KeyChangeTechniqueOnKeyPressed. `para_tras` = Shift (agachado no mod).
func trocar(para_tras := false) -> void:
	_pedir("trocar", 1 if para_tras else 0)


## Z apertado (true) ou solto (false).
func usar(apertou: bool) -> void:
	_pedir("z", 1 if apertou else 0)


## Z X C V B N (08/11/2026): cada técnica do ciclo na sua tecla, na ordem do R.
const TECLAS := ["Z", "X", "C", "V", "B", "N"]


func tem_teclas_diretas() -> bool:
	return true


func usar_tecla(tecla: String, apertou: bool) -> void:
	_pedir("tecla_" + tecla.to_lower(), 1 if apertou else 0)


func _numero_da_tecla(tecla: String) -> int:
	var i := TECLAS.find(tecla.to_upper())
	var validos := numeros_validos()
	return int(validos[i]) if i >= 0 and i < validos.size() else -1


func _pedir(acao: String, valor: int) -> void:
	if servidor():
		_executar(acao, valor)
	else:
		_pedido.rpc_id(1, acao, valor)


@rpc("any_peer", "call_remote", "reliable")
func _pedido(acao: String, valor: int) -> void:
	if not servidor() or multiplayer.get_remote_sender_id() != ator.get_multiplayer_authority():
		return
	_executar(acao, valor)


func _executar(acao: String, valor: int) -> void:
	match acao:
		"trocar":
			if fruta_ativa():
				_ciclar(-1 if valor == 1 else 1)
		"z":
			z = valor == 1
			if z:
				comecar(selecao)
			else:
				_soltar(selecao)
		"tecla_z", "tecla_x", "tecla_c", "tecla_v", "tecla_b", "tecla_n":
			var numero := _numero_da_tecla(acao.substr(6))
			if numero < 0:
				return
			if valor == 1:
				selecao = numero
				z = true
				comecar(numero)
			else:
				_soltar(numero)
				if selecao == numero:
					z = false
		"shift":
			shift = valor == 1
		"toque_duplo":
			s = valor < 0
			if fruta_ativa() and sessao_de(28) == null and ator.corpo_livre_para_golpe():
				_iniciar(28, {"cnt1": float(valor)})


func _ciclar(passo: int) -> void:
	var validos := numeros_validos()
	var i := validos.find(selecao)
	selecao = validos[posmod((i if i >= 0 else 0) + passo, validos.size())]


## As técnicas que o R oferece agora: o Raigo só com o efeito Mamaragan.
func numeros_validos() -> Array:
	var saida := []
	for t in CICLO:
		if t.numero != 29 or mamaragan > 0.0:
			saida.append(t.numero)
	return saida


static func ficha(numero: int) -> Dictionary:
	for t in CICLO:
		if t.numero == numero:
			return t
	return {}


static func energia_de(numero: int) -> float:
	return float(ficha(numero).get("custo", 0.0)) * ENERGIA_POR_CUSTO


## StartCursedTechnique: max(custo × 0,5, 5) ticks.
static func recarga_de(numero: int) -> float:
	return maxf(float(ficha(numero).get("custo", 0.0)) * 0.5, 5.0) * B.TICK


## A sessão desta técnica, se estiver em curso.
func sessao_de(numero: int) -> SessaoGoroMinePiece:
	for sessao: SessaoGoroMinePiece in sessoes:
		if sessao.numero == numero and sessao.ativa():
			return sessao
	return null


## Soltou a tecla: só a técnica DELA deixa de ser segurada.
func _soltar(numero: int) -> void:
	var sessao := sessao_de(numero)
	if sessao != null:
		sessao.z = false


## Z: começa a técnica se der. Só valem a recarga DELA, a energia e o corpo livre: uma técnica em curso não trava as outras.
func comecar(numero: int) -> bool:
	if not fruta_ativa() or not ator.corpo_livre_para_golpe() or sessao_de(numero) != null:
		return false
	if float(recargas.get(numero, 0.0)) > 0.0:
		return false
	if not numero in numeros_validos() or float(ator.energy) + 0.001 < energia_de(numero):
		return false
	ator.gastar_energia(energia_de(numero))
	recarga_total = recarga_de(numero)
	recargas[numero] = recarga_total
	recarga = maxf(recarga, recarga_total)
	if elemental.ativa:
		_desfazer_elemental()
	_iniciar(numero)
	return true


## ResetCounterProcedure + "skill" = número: abre a sessão (o `D` próprio da técnica).
func _iniciar(numero: int, extra := {}) -> void:
	var sessao := SessaoGoroMinePiece.new(self, numero, extra)
	sessoes.append(sessao)
	D = sessao.D
	ator.set_meta(META_ATIVA, get_instance_id())


## Fim de TUDO (morte, troca de fruta, corpo preso): cancela todas as sessões.
func encerrar() -> void:
	sessoes.clear()
	D = {"skill": 0}
	_limpar_corpo()


func _limpar_corpo() -> void:
	_clipe = ""
	if not is_instance_valid(ator):
		return
	if int(ator.get_meta(META_ATIVA, 0)) == get_instance_id():
		ator.remove_meta(META_ATIVA)
	for meta in ["pose_de_skill", "posicoes_mine_piece"]:
		if ator.has_meta(meta):
			ator.remove_meta(meta)
	if ator.get_meta(META_INVISIVEL, false):
		ator.set_meta(META_INVISIVEL, false)
		ator._atualizar_visibilidade_corpo()


# ------------------------------------------------------------------ o tempo
func _physics_process(delta: float) -> void:
	if not is_instance_valid(ator):
		return
	if ator._is_authority:
		_ler_teclado(delta)
		if not sessoes.is_empty():
			ator.aplicar_mira(ator._yaw, ator._pitch, delta, 20.0)
	if servidor():
		_acumulado += delta
		while _acumulado >= B.TICK:
			_acumulado -= B.TICK
			_tick()
	_aplicar_pose(delta)
	if _invisivel_ate > 0.0 and Time.get_ticks_msec() / 1000.0 >= _invisivel_ate:
		_invisivel_ate = 0.0
		ator.set_meta(META_INVISIVEL, false)
		ator._atualizar_visibilidade_corpo()


func _tick() -> void:
	tick += 1
	_travado = false
	_parado = false
	recarga = 0.0
	for numero in recargas.keys():
		recargas[numero] = maxf(float(recargas[numero]) - B.TICK, 0.0)
		recarga = maxf(recarga, float(recargas[numero]))
	_ligar_aparo()
	var vivo := float(ator.health) > 0.0
	if not sessoes.is_empty():
		if not vivo or ator.current_fruit_id != ID or not ator.corpo_livre_para_golpe():
			encerrar()
		else:
			for sessao: SessaoGoroMinePiece in sessoes.duplicate():
				sessao.passo()
				if not sessao.ativa():
					sessoes.erase(sessao)
			if sessoes.is_empty():
				encerrar()
			else:
				D = (sessoes.back() as SessaoGoroMinePiece).D
	if mamaragan > 0.0:
		mamaragan = maxf(mamaragan - B.TICK, 0.0) if vivo else 0.0
		if mamaragan > 0.0:
			tecnicas.tempestade()
			_aura_eletrica(2)
		elif selecao == 29:
			selecao = 25
	_observar_elemental(vivo)


## PlayerTickEvent2Procedure: a cada 2 ticks, os contadores de toque duplo de W e S.
func _ler_teclado(delta: float) -> void:
	var com_shift := Input.is_key_pressed(KEY_SHIFT)
	if com_shift != shift:
		shift = com_shift
		_pedir("shift", 1 if com_shift else 0)
	_acumulado_local += delta
	while _acumulado_local >= B.TICK:
		_acumulado_local -= B.TICK
		_tick_local += 1
		if _tick_local % 2 != 0:
			continue
		var menu := ator._menu_de_tela_aberto()
		var w_agora := Input.is_physical_key_pressed(KEY_W) and not menu
		var s_agora := Input.is_physical_key_pressed(KEY_S) and not menu
		var direcao := 0
		for tecla in ["w", "s"]:
			var flag: float = _flags[tecla]
			if (w_agora if tecla == "w" else s_agora):
				if flag > 0.0 and flag < JANELA_TOQUE_DUPLO:
					direcao = 1 if tecla == "w" else -1
					flag = 20.0
				_flags[tecla] = maxf(flag + 1.0, JANELA_TOQUE_DUPLO)
			else:
				_flags[tecla] = maxf(minf(flag, JANELA_TOQUE_DUPLO if flag <= 5.0 else 0.0) - 1.0, 0.0)
		if direcao != 0 and fruta_ativa():
			_pedir("toque_duplo", direcao)


# --------------------------------------------------------- Kari Krash (27)
func _ligar_aparo() -> void:
	var executor: Object = ator.combate_direcional
	if executor == _aparo_ligado:
		return
	if is_instance_valid(_aparo_ligado) and _aparo_ligado.aparou.is_connected(_ao_aparar):
		_aparo_ligado.aparou.disconnect(_ao_aparar)
	_aparo_ligado = executor
	if executor != null and not executor.aparou.is_connected(_ao_aparar):
		executor.aparou.connect(_ao_aparar)


## JustGuardProcedure: defesa perfeita sem técnica em curso → Kari Krash, sem custo.
func _ao_aparar(_golpe: GolpeDirecional, _posicao: Vector3) -> void:
	if not servidor() or not fruta_ativa() or sessao_de(27) != null or float(ator.health) <= 0.0:
		return
	fx_som(pe(), "guard_just")
	_iniciar(27, {"cnt2": 1.0})


# ------------------------------------------------------------- Mamaragan
func iniciar_mamaragan() -> void:
	mamaragan = DURACAO_MAMARAGAN
	_ciclar(1)   # noChangeTechnique + KeyChangeTechnique: o R já cai no Raigo


# --------------------------------------------- transformação elemental + voo
func _observar_elemental(vivo: bool) -> void:
	if SEM_LOGIA:
		return
	if not vivo or not fruta_ativa():
		if elemental.ativa:
			_desfazer_elemental()
		elemental.observar(float(ator.health), float(ator.max_health), tick * B.TICK)
		return
	if elemental.observar(float(ator.health), float(ator.max_health), tick * B.TICK):
		_velocidade_antes = ator.speed_multiplier
		ator.speed_multiplier = _velocidade_antes * TransformacaoElemental.BONUS_DE_VELOCIDADE
		voo.comecar(ator.velocity)
		_voo_tick = 0
		fx_som(pe(), "electric_shock", 0.0)
		fx_clarao(pe() + Vector3.UP, 3.0)
		_corpo_de_raio(true)
	if elemental.ativa:
		_aura_eletrica(3)
	if elemental.ativa and tick % 3 == 1:
		fx_faiscas(pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 6, B.m(B.LARGURA_JOGADOR), 1.5)


## Aura do corpo de raio (Mamaragan e forma elemental): a cada `cada` ticks um arco curto sai do tronco para um ponto qualquer em volta e o corpo pulsa em azul —
## antes só havia faíscas minúsculas, e a forma quase não se lia a distância. Visual só (sem dano).
func _aura_eletrica(cada: int) -> void:
	if tick % cada != 0:
		return
	var meio := pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	for k in 2:
		var rumo := Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 1.0), randf_range(-1.0, 1.0)).normalized()
		var fim := meio + rumo * B.m(randf_range(2.0, 3.6))
		var pontos := VfxGoroMinePiece.zigue_zague(meio, fim, 0.35, 5)
		VfxGoroMinePiece.relampago(ator, pontos, 0.22, 0.25)
		VfxGoroMinePiece.relampago(ator, PackedVector3Array([meio, fim]), 0.1, 0.25, VfxGoroMinePiece.COR_NUCLEO)
	VfxGoroMinePiece.clarao(ator, meio, B.m(B.ALTURA_JOGADOR) * 1.4, 0.22)


func _desfazer_elemental() -> void:
	elemental.desfazer()
	if is_instance_valid(ator):
		ator.speed_multiplier = _velocidade_antes
	_corpo_de_raio(false)


## O corpo virando raio: borda elétrica tremulando em todas as malhas do personagem.
func _corpo_de_raio(ligar: bool) -> void:
	var modelo: Node3D = ator._char_model if is_instance_valid(ator) else null
	if modelo == null:
		return
	if _brilho_de_raio == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 cor : source_color = vec4(0.55, 0.85, 1.0, 1.0);
void fragment() {
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float tremor = 0.65 + 0.35 * sin(TIME * 37.0 + VERTEX.y * 9.0);
	ALBEDO = cor.rgb;
	ALPHA = clamp(borda * 2.4 * tremor + 0.22, 0.0, 1.0);
}"""
		_brilho_de_raio = ShaderMaterial.new()
		_brilho_de_raio.shader = sh
	for malha in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		if ligar:
			mi.material_overlay = _brilho_de_raio
		elif mi.material_overlay == _brilho_de_raio:
			mi.material_overlay = null


## Gancho do `Player._physics_process` (como o Phoenix): no tick em que a técnica
## pede Lentidão X o corpo não anda, com setDeltaMovement(0) nem cai; transformado, voa.
func controla_movimento() -> bool:
	return fruta_ativa() and (not sessoes.is_empty() or elemental.ativa)


func velocidade(delta: float, atual: Vector3, q: MoveFrame) -> Vector3:
	if not sessoes.is_empty():
		if _parado:
			return Vector3.ZERO
		return Vector3(0.0, atual.y, 0.0) if _travado else atual
	var saida := voo.v * B.VELOCIDADE
	_voo_acumulado += delta
	while _voo_acumulado >= B.TICK:
		_voo_acumulado -= B.TICK
		_voo_tick += 1
		saida = voo.tick(_voo_tick, q.espaco_segurado, signf(q.f), olhar(),
			TransformacaoElemental.BONUS_DE_VELOCIDADE, ator.is_on_floor())
		if _voo_tick % 3 == 1:
			pose("fly_back" if q.f < 0.0 else "fly_front")
	return saida


# --------------------------------------------- o que as técnicas pedem ao corpo
## O pé do corpo (o `getY()` do Minecraft).
func pe() -> Vector3:
	return ator.global_position - _meio


func _pe_do_colisor() -> Vector3:
	for filho in ator.get_children():
		var cs := filho as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var meia := -1.0
		if cs.shape is CapsuleShape3D:
			meia = (cs.shape as CapsuleShape3D).height * 0.5
		elif cs.shape is BoxShape3D:
			meia = (cs.shape as BoxShape3D).size.y * 0.5
		if meia >= 0.0:
			return cs.global_position - Vector3.UP * meia * cs.global_basis.get_scale().y
	return ator.global_position - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)


func olhos() -> Vector3:
	return pe() + Vector3.UP * B.m(B.OLHOS_JOGADOR)


## A direção da mira (o `getLookAngle` do mod): dos olhos até o ponto do retículo.
func olhar(com_pitch := true) -> Vector3:
	var dir: Vector3
	var cam: Camera3D = ator._cam
	if cam != null and cam.is_inside_tree():
		var ponto := AlvosDeGolpe.ponto_mirado(ator.get_world_3d(), cam.global_position,
			-cam.global_basis.z, B.m(64.0), [ator.get_rid()])
		dir = (ponto - olhos())
	else:
		dir = ator._mira_do_voo()
	if not com_pitch:
		dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else RosaDosVentos.frente(ator._yaw)


## O ponto à frente usado pelo mod: pé + altura × `altura`, + `blocos` na mira.
## `giro` gira a direção no plano (π = atrás, o yaw + 270° do El Thor).
func frente(blocos: float, altura: float, com_pitch := true, giro := 0.0) -> Vector3:
	var dir := olhar(com_pitch).rotated(Vector3.UP, giro)
	return pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * altura) + dir * B.m(blocos)


## A busca de alvo do Sango e do ElThorFall: `passos` raios da vista a 6, 12, 18…
## blocos; em volta de cada ponto, um cubo de `lado`. Sem alvo, o último ponto.
func alvo_na_mira(passos: int, passo_b: float, lado_b: float) -> Vector3:
	var ponto := olhos()
	var dir := olhar()
	for i in passos:
		var ate := olhos() + dir * B.m(passo_b * (i + 1))
		var hit := ator.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(olhos(), ate, B.MASCARA_MUNDO, [ator.get_rid()]))
		ponto = hit.position if not hit.is_empty() else ate
		var alvo := B.primeiro_no_cubo(ator, ponto, lado_b)
		if alvo != null:
			return AlvosDeGolpe.centro(alvo)
	return ponto


## Até onde a caixa de `lado_b` blocos desce numa coluna, em passos de 2 blocos.
func chao_da_coluna(topo: Vector3, lado_b: float, maximo: float) -> float:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * B.m(lado_b)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis.IDENTITY, topo + Vector3.UP * B.m(lado_b) * 0.5)
	q.motion = Vector3.DOWN * maximo
	q.collision_mask = B.MASCARA_MUNDO
	q.exclude = [ator.get_rid()]
	var fracao := ator.get_world_3d().direct_space_state.cast_motion(q)
	var passo := B.m(2.0)
	var desceu := maximo * (fracao[1] if fracao.size() > 1 else 1.0)
	return topo.y - ceilf(desceu / passo) * passo


func solido(onde: Vector3, altura_b := B.ALTURA_JOGADOR, largura_b := B.LARGURA_JOGADOR) -> bool:
	return B.solido(ator.get_world_3d(), onde, altura_b, largura_b)


func teleportar(novo_pe: Vector3) -> void:
	ator.global_position = novo_pe + _meio
	ator.velocity = Vector3.ZERO


func atacar(centro: Vector3, a: MundoMinePiece.Ataque, origem: Variant = null) -> int:
	var perfil_atual: PerfilDeFrutas = ator.perfil_de_frutas
	var escala := perfil_atual.escala_das_tecnicas() if perfil_atual != null else 1.0
	var bloqueio := perfil_atual.dano_bloqueado if perfil_atual != null else 1.0
	var de_onde: Vector3 = origem if origem is Vector3 else pe()
	return B.ataque_em_area(ator, de_onde, centro, a, tick, imunidade, escala, bloqueio)


## Lentidão X: o corpo não anda neste tick (a gravidade continua).
func travar() -> void:
	_travado = true


## setDeltaMovement(0): nem a gravidade neste tick.
func parar() -> void:
	_parado = true


func invisivel(segundos: float) -> void:
	_invisivel_ate = Time.get_ticks_msec() / 1000.0 + segundos
	ator.set_meta(META_INVISIVEL, true)
	ator._atualizar_visibilidade_corpo()


func criar_onda(onde: Vector3, cnt6: float) -> void:
	var onda := Onda.new()
	onda.c = self
	onda.cnt6 = cnt6
	VfxGoroMinePiece._raiz(ator).add_child(onda)
	onda.global_position = onde


func criar_meteoro(base: Vector3) -> void:
	var m := Meteoro.new()
	m.c = self
	VfxGoroMinePiece._raiz(ator).add_child(m)
	m.global_position = base


# ------------------------------------------------------------------ pose
## PlayAnimationPlayerProcedure: o clipe do player_animation (importar_goro.py).
## O mesmo clipe pedido de novo não recomeça; outro clipe entra por cima.
func pose(nome: String) -> void:
	if nome != _clipe:
		_clipe = nome
		_clipe_t = 0.0


func _aplicar_pose(delta: float) -> void:
	if _clipe.is_empty() or not _poses.has(_clipe):
		return
	if int(D.skill) == 0 and not elemental.ativa:
		_clipe = ""
		ator.remove_meta("pose_de_skill")
		ator.remove_meta("posicoes_mine_piece")
		return
	_clipe_t += delta
	var clipe: Dictionary = _poses[_clipe]
	var quadros: Array = clipe.quadros
	var quadro := minf(clamp(_clipe_t, 0.0, float(clipe.duracao)) * float(clipe.fps), quadros.size() - 1)
	var i := int(quadro)
	var j := mini(i + 1, quadros.size() - 1)
	var t := fmod(quadro, 1.0)
	var peso := smoothstep(0.0, 0.08, _clipe_t)
	var rotacoes := {}
	for papel in quadros[i]:
		var a: Array = quadros[i][papel]
		var b: Array = quadros[j][papel]
		rotacoes[papel] = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t) * PI / 180.0 * peso
	ator.set_meta("pose_de_skill", rotacoes)
	var posicoes := {}
	for papel in clipe.posicoes[i]:
		var a: Array = clipe.posicoes[i][papel]
		var b: Array = clipe.posicoes[j][papel]
		posicoes[papel] = Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), t) * peso
	ator.set_meta("posicoes_mine_piece", posicoes)


# ------------------------------------------------------------------ HUD
## Uma linha por técnica do R, para a `TecnicasHud`.
func estado_das_tecnicas() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for numero in numeros_validos():
		var custo := energia_de(numero)
		saida.append({"numero": numero, "nome": ficha(numero).nome, "custo": custo, "tecla": TECLAS[mini(saida.size(), TECLAS.size() - 1)],
			"selecionada": numero == selecao, "recarga": float(recargas.get(numero, 0.0)), "recarga_total": recarga_de(numero),
			"sem_energia": float(ator.energy) + 0.001 < custo,
			"bloqueada": custo > float(ator.max_energy) + 0.001})
	return saida


## O que a HUD escreve embaixo: tempestade e corpo elétrico.
func avisos() -> String:
	var partes: Array[String] = []
	if mamaragan > 0.0:
		partes.append("Mamaragan %d s" % ceili(mamaragan))
	if elemental.ativa:
		partes.append("corpo de raio · técnica desfaz")
	return "  ·  ".join(partes)


# ------------------------------------------------------------------ efeitos
func fx_faiscas(onde: Vector3, n: int, espalhar: float, vel := 2.0) -> void:
	VfxGoroMinePiece.faiscas(ator, onde, n, espalhar, vel)

func fx_fumaca(onde: Vector3, n: int, espalhar: float, vel := 1.0) -> void:
	VfxGoroMinePiece.fumaca(ator, onde, n, espalhar, vel)

func fx_clarao(onde: Vector3, raio: float, duracao := 0.15) -> void:
	VfxGoroMinePiece.clarao(ator, onde, raio, duracao)

func fx_som(onde: Vector3, nome: String, volume := -6.0) -> void:
	VfxGoroMinePiece.som(ator, onde, nome, volume)

func fx_marca(onde: Vector3, raio: float) -> void:
	VfxGoroMinePiece.marca(ator, onde, raio)

func fx_raio(pontos: PackedVector3Array, largura: float) -> void:
	VfxGoroMinePiece.relampago(ator, pontos, largura, 0.15)

func fx_relampago(de_p: Vector3, ate: Vector3) -> void:
	VfxGoroMinePiece.relampago(ator, VfxGoroMinePiece.zigue_zague(de_p, ate, 0.35, 6), 0.18, 0.1)

## O feixe do El Thor: o ParticleGenerator do mod envolve a reta com faíscas num raio
## de 3 × tamanho; aqui, núcleo claro, zigue-zague em volta e as faíscas.
func fx_feixe(de_p: Vector3, ate: Vector3, largura: float) -> void:
	var trechos := maxi(int(de_p.distance_to(ate) / 2.0), 2)
	VfxGoroMinePiece.relampago(ator, VfxGoroMinePiece.zigue_zague(de_p, ate, largura, trechos), largura * 1.2, 0.12)
	VfxGoroMinePiece.relampago(ator, PackedVector3Array([de_p, ate]), largura * 0.6, 0.12, VfxGoroMinePiece.COR_NUCLEO)
	VfxGoroMinePiece.faiscas_na_linha(ator, de_p, ate, int(de_p.distance_to(ate) * 0.8), largura * 2.0)

func fx_descarga(centro: Vector3, raio: float) -> void:
	VfxGoroMinePiece.descarga(ator, centro, raio, 4)

func fx_raio_do_ceu(onde: Vector3) -> void:
	VfxGoroMinePiece.raio_do_ceu(ator, onde)
