extends Node
## ESTILO DE COMBATE BASE, a Luta (Mine Piece v14) — o porte NATIVO (A11, 30/10/2026), sem Skills Builder.
##
## Três técnicas desarmadas, nas teclas Z/X/C (`teclas_diretas` da ficha; o `Controlador` as chama), traduzidas das procedures do mod:
##   1 Soco (Z)         AttackWeakPunchProcedure   — golpe no 2º tick (cnt2 == 1), cubo de 6 × alcance a 2,5 × alcance, dura 10 ticks.
##   2 Soco pesado (X)  AttackStrongPunchProcedure — 8 ticks de preparo (Lentidão IV), depois golpe; aqui, segurar X carrega até 25 ticks.
##   3 Sequência (C)    adaptação do projeto (o `AttackContinue` do mod é a barragem do clique): rajada a cada 2 ticks e um golpe final.
## Números do mod: dano 9 / 11 (× CNT6), cubo de 6 blocos, Lentidão IV (amp. 3) no preparo e III (amp. 2) no golpe. O empurrão e a paralisia
## do C são decisão do dono (30/10/2026, `Balance.MINE_PIECE_LUTA`): Z e X empurram forte; no C só o ÚLTIMO golpe empurra e os da rajada paralisam.
## Tempo em TICKS do mod (0,05 s; `passo()` roda um por tick). O dano é do `DamageZone` (servidor); aparência e som são locais.
##
## Desvios declarados: sem a entidade `entity_strike` do mod (vira o `mp_impacto.glb` com as animações idle1/2/3 importadas), sem
## `HakiEffect`, sem `BlockDestroyAllDirection` (o mapa não tem a grade de blocos) e o custo de energia é simbólico (o mod não cobra).
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const PASTA := "res://assets/mine_piece/combate/"
const PRIMEIRO_SOCO := 2            # ticks até o golpe (cnt2 == 1 no 2º tick do Java)
const FIM_DO_GOLPE := 10            # ticks do golpe até o fim (cnt2 >= 10)
const PREPARO_DO_PESADO := 7        # ticks (0,35 s) antes do golpe pesado, sem segurar
const INICIO_DA_CARGA := 6          # ticks (0,3 s): daí em diante segurar X carrega
const CARGA_MAXIMA := 25            # ticks (1,25 s) de carga do X: +50 % de dano e de empurrão
const INICIO_RAJADA := 11           # ticks (0,55 s)
const INTERVALO_RAJADA := 2         # ticks (0,1 s)
const MINIMO_RAJADA := 25           # ticks (1,25 s): soltar antes só vale a partir daqui
const MAXIMO_RAJADA := 51           # ticks (2,55 s): o teto
## Mãos vazias, tamanho base ≈ 1: centro 2,5 blocos à frente, cubo de 6 × alcance.
const CENTRO_DO_GOLPE := 2.5
const LADO_DA_AREA := 6.0
const VIDA_DO_EFEITO := 0.3

## Pose ÚNICA de segurar o X (20/11/2026): corpo agachado e torcido para trás, punho direito recolhido na cintura, esquerdo na guarda,
## cabeça olhando para a frente. Um quadro só e SEM reiniciar: reiniciar o clipe a cada tick mantinha o peso de entrada perto de zero e o
## braço piscava. O soco (`punch_right`) só começa a tocar na liberação.
const POSE_CARGA := {
	"Torso": Vector3(0, -60, 0), "Head": Vector3(0, 60, 0),
	"UpperArm_R": Vector3(25, 50, 0), "ForeArm_R": Vector3(90, 0, 0),
	"UpperArm_L": Vector3(75, 0, 25), "ForeArm_L": Vector3(60, 0, 0),
	"Thigh_R": Vector3(-20, 0, 0), "Thigh_L": Vector3(25, 0, 0), "Shin_R": Vector3(30, 0, 0),
}

const Visual := preload("res://src/combat/frutas_mine_piece/luta_visual.gd")

static var _impacto: PackedScene
var c                              # o `ControladorFrutaMinePiece`
var tecnica := 0
var t := 0                         # ticks desde o início
var _carga := 0                    # ticks segurados (X)
var _final_em := -1                # tick em que a rajada decidiu acabar (C)
var _proximo := INICIO_RAJADA
var _golpes := 0
var _acertou_final := false
var _soco_da_direita := true       # braço do soco em curso: o Z começa pelo direito (pose `punch_right`) e alterna ao repetir
var _vida0 := INF
var _efeitos: Array[Dictionary] = []
var _presos: Array[Node] = []      # quem a rajada deste C paralisou: só ESSES são soltos para o golpe final
var _aura: Node3D = null           # a aura do punho que carrega (X)
var _nivel_da_aura := 0
var _soltou := false               # o X já saiu da pose de carga para o soco


func iniciar(numero: int) -> void:
	tecnica = numero
	t = 0
	_carga = 0
	_final_em = -1
	_proximo = INICIO_RAJADA
	_golpes = 0
	_acertou_final = false
	_soco_da_direita = true
	_vida0 = float(c.ator.health)
	_presos.clear()
	_soltou = false
	_soltar_aura()
	if _impacto == null:
		_impacto = load(PASTA + "mp_impacto.glb") as PackedScene
	c.registrar_pose("carga_x", POSE_CARGA)
	c.pose("carga_x" if numero == 2 else "punch_right", true)


func cancelar() -> void:
	_soltar_aura()
	c.pose_extra = {}
	_limpar_efeitos()


func manter() -> void:
	# O efeito de impacto vive 0,3 s e some por conta própria, mesmo com a técnica já encerrada.
	pass


func _process(delta: float) -> void:
	for i in range(_efeitos.size() - 1, -1, -1):
		_efeitos[i].idade += delta
		if _efeitos[i].idade >= VIDA_DO_EFEITO:
			if is_instance_valid(_efeitos[i].no):
				_efeitos[i].no.queue_free()
			_efeitos.remove_at(i)


func passo() -> void:
	t += 1
	if _interrompido():
		_soltar_aura()
		c.pose_extra = {}
		c.pose_fim()
		c.terminar()
		return
	match tecnica:
		1:
			_soco()
		2:
			_pesado()
		3:
			_sequencia()
		_:
			c.terminar()


## Apanhar, morrer, congelar ou estar em pose de dano cancela, como no Builder antes (e como o mod, que interrompe o skill).
func _interrompido() -> bool:
	if float(c.ator.health) <= 0.0 or float(c.ator.health) < _vida0:
		return true
	return float(c.ator.get_meta("_dano_pose_t", 0.0)) > 0.0 or bool(c.ator.get_meta("is_frozen", false))


# ---------------------------------------------------------------- 1 Soco (Z)
func _soco() -> void:
	c.lentidao = 3 if t < PRIMEIRO_SOCO else 2
	_inclinar_braco(_soco_da_direita)
	if t == PRIMEIRO_SOCO:
		_golpear("soco", "idle3", _soco_da_direita)
	if t >= FIM_DO_GOLPE:
		# Segurar Z repete o soco (decisão do dono, 20/11/2026): o dano é SEMPRE o do soco avulso — segurar só dá cadência.
		# Cada repetição paga a energia do soco e para quando ela acaba; soltar Z encerra no fim do golpe em curso.
		if c.segurando and _pagar_repeticao():
			t = 0
			_soco_da_direita = not _soco_da_direita
			c.pose("punch_right" if _soco_da_direita else "punch_left", true)
		else:
			_encerrar()


## Energia de uma repetição do Z (a mesma do soco avulso). Sem energia, a sequência acaba.
func _pagar_repeticao() -> bool:
	var custo: float = float(c.ficha_selecionada().get("custo_mod", 0.0)) * float(c.ENERGIA_POR_CUSTO)
	if c.ator.energy + 0.001 < custo:
		return false
	c.ator.gastar_energia(custo)
	return true


# ------------------------------------------------------------ 2 Soco pesado (X)
func _pesado() -> void:
	c.lentidao = 3 if t < PREPARO_DO_PESADO + _carga + PRIMEIRO_SOCO else 2
	if t >= INICIO_DA_CARGA and c.segurando and _carga < CARGA_MAXIMA:
		_carga += 1
		c.pose("carga_x")                   # pose própria, sem reiniciar o clipe (ver POSE_CARGA)
		_atualizar_aura()
		return
	if t < INICIO_DA_CARGA and c.segurando:
		return                              # tecla ainda segurada antes de a carga começar: continua na pose de carga
	var preparo := PREPARO_DO_PESADO + _carga
	if not _soltou:
		_soltou = true
		c.pose("punch_right", true)         # a liberação: agora o soco toca desde o começo
	_inclinar_braco(true)
	if t == preparo + PRIMEIRO_SOCO:
		_soltar_aura()
		_golpear("pesado", "idle3")
	if t >= preparo + FIM_DO_GOLPE:
		_encerrar()


# ----------------------------------------------------------- 3 Sequência (C)
func _sequencia() -> void:
	c.lentidao = 3
	if _final_em < 0 and (t >= MAXIMO_RAJADA or (not c.segurando and t >= MINIMO_RAJADA)):
		_final_em = mini(t, MAXIMO_RAJADA)
	while _final_em < 0 and t >= _proximo:
		var direita := _golpes % 2 == 0
		_inclinar_braco(direita)
		c.pose("punch_right" if direita else "punch_left", true)
		_golpear("rajada", "idle1" if direita else "idle2", direita)
		_golpes += 1
		_proximo += INTERVALO_RAJADA
	if _final_em >= 0 and not _acertou_final and t >= _final_em + PRIMEIRO_SOCO:
		_acertou_final = true
		_inclinar_braco(true)
		c.pose("punch_right", true)
		_golpear("final", "idle3")
	if _final_em >= 0 and t >= _final_em + FIM_DO_GOLPE:
		_encerrar()


func _encerrar() -> void:
	_soltar_aura()
	c.pose_extra = {}
	c.pose_fim()
	c.terminar()


# --------------------------------------------------------------------- golpe
func _golpear(tipo: String, animacao: String, direita := true) -> void:
	var dados: Dictionary = Balance.MINE_PIECE_LUTA[tipo]
	var frente := _direcao_do_golpe()
	var origem: Vector3 = c.pe() + Vector3.UP * 1.3
	var centro := origem + frente * CENTRO_DO_GOLPE
	# A área não pode nascer atrás de uma parede entre o corpo e o impacto.
	var raio := PhysicsRayQueryParameters3D.create(origem, centro)
	raio.collision_mask = 1
	if c.ator is CollisionObject3D:
		raio.exclude = [c.ator.get_rid()]
	var bateu: Dictionary = c.ator.get_world_3d().direct_space_state.intersect_ray(raio)
	var forca_visual := _forca_visual(tipo)
	if not bateu.is_empty() and not bateu.collider.has_method("take_damage"):
		_efeito(bateu.position, frente, animacao)
		_registrar(Visual.estourar(self, bateu.position, frente, forca_visual * 0.5))
		return
	_efeito(centro, frente, animacao)
	# No vazio só um clarão pequeno; o estouro cheio nasce no CONTATO (`hit_landed`), em cima de quem foi atingido.
	if tipo != "rajada":                    # a rajada já tem o fantasma e o contato; o clarão no vazio só acumularia
		_registrar(Visual.estourar(self, centro, frente, forca_visual * 0.35))
	var lado_do_fantasma := 0.0
	if tipo == "rajada" or tipo == "soco":
		lado_do_fantasma = 1.0 if direita else -1.0
		var fantasma := Visual.fantasma(self, origem, frente, lado_do_fantasma, CENTRO_DO_GOLPE + 0.6)
		if fantasma != null:
			_registrar([fantasma] as Array[Node3D])
	c.mostrar_golpe(centro, frente, forca_visual * 0.35 if tipo != "rajada" else 0.0, origem, lado_do_fantasma)      # mesmos cubos nos clientes remotos
	if tipo == "final":
		# O golpe final lança: só quem ESTA rajada paralisou é solto — nada de soltar quem outra técnica congelou,
		# nem alvos que a barragem nunca atingiu.
		# Posse por origem: remove só o token DESTA rajada; se outra técnica prendeu o alvo (antes, depois ou recriou), ela continua valendo.
		for alvo in _presos:
			if is_instance_valid(alvo):
				ImobilizacaoMinePiece.liberar_origem(alvo, _origem())
		_presos.clear()
	var zona := DamageZone.new()
	add_child(zona)
	zona.global_position = centro
	var carga := 1.0 + 0.5 * float(_carga) / float(CARGA_MAXIMA) if tipo == "pesado" else 1.0
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * LADO_DA_AREA
	zona.setup(float(dados.dano) * PerfilDeFrutas.ESCALA_DO_MOD * carga, float(dados.empurrao) * carga, Vector3.ZERO,
		0.065, c.ator, 0.0, forma, float(dados.stun))
	zona.cast_id = CombatResolver.novo_cast()      # cada soco pode acertar uma vez
	zona.corpo_a_corpo = true
	zona.sem_janela_de_acerto = true        # a cadência é da técnica (rajada a cada 0,1 s), não do clique rápido
	zona.override_kb_dir = frente
	zona.exige_linha_de_visao = true
	zona.origem_linha_de_visao = origem
	zona.feedback_global = false
	var paralisia := float(dados.get("paralisia", 0.0))
	zona.hit_landed.connect(func(atingido: Node):
		if paralisia > 0.0:
			ImobilizacaoMinePiece.aplicar(atingido, paralisia, _origem())      # token próprio: o final só remove este
			if not _presos.has(atingido):
				_presos.append(atingido)
		var onde := centro
		if atingido is Node3D:
			# Na LINHA do golpe, a meio caminho do alvo — não na origem dele (pé num NPC, centro no jogador): o clarão fica na altura do punho em qualquer corpo.
			var ate := clampf((((atingido as Node3D).global_position - origem).dot(frente)) - 0.4, 0.9, CENTRO_DO_GOLPE + 0.6)
			onde = origem + frente * ate
		_registrar(Visual.estourar(self, onde, frente, forca_visual))
		c.mostrar_golpe(onde, frente, forca_visual, origem, 0.0)
		_som(tipo, centro))


## Para onde o soco vai. No CHÃO fica horizontal (a área de 6 m já cobre quem está um pouco acima ou abaixo, e um soco mirado no
## piso nasceria enterrado); NO AR segue a mira da câmera inteira — para os lados, para cima e para baixo (combate aéreo, 20/11/2026).
func _direcao_do_golpe() -> Vector3:
	var mira: Vector3 = c.olhar()
	if not _no_ar():
		mira.y = 0.0
	if mira.length_squared() < 0.0001:
		return -c.ator.global_basis.z
	return mira.normalized()


## Visual do contato (0..1): leve no Z, pequeno na rajada, cresce com a carga no X, forte no final.
func _forca_visual(tipo: String) -> float:
	match tipo:
		"pesado":
			return 0.45 + 0.55 * float(_carga) / float(CARGA_MAXIMA)
		"final":
			return 0.85
		"rajada":
			return 0.1
	return 0.3


func _registrar(nos: Array[Node3D]) -> void:
	for no in nos:
		if is_instance_valid(no):
			_efeitos.append({"no": no, "idade": 0.0})


## A aura do punho enquanto o X carrega: cresce e clareia por nível (terços da carga) e solta um clarão ao subir de nível.
func _atualizar_aura() -> void:
	var nivel: int = Visual.nivel_de_carga(_carga, CARGA_MAXIMA)
	var frente := _direcao_do_golpe()
	var e: Array[Vector3] = Visual.eixos(frente)
	var mao: Vector3 = c.pe() + Vector3.UP * 1.4 + frente * 1.0 + e[0] * 0.45     # à frente do punho, fora do braço e do corpo
	_aura = Visual.aura(self, _aura, mao, frente, nivel, float(t) * 0.05)
	if nivel > _nivel_da_aura and nivel > 0:
		_registrar(Visual.estourar(self, mao, frente, 0.2 * float(nivel)))
	_nivel_da_aura = nivel


func _soltar_aura() -> void:
	Visual.liberar_aura(_aura)
	_aura = null
	_nivel_da_aura = 0


## Combate aéreo: o braço que bate sobe ou desce com a mira (ombro: 90° é horizontal, 180° é para cima). No chão não mexe.
func _inclinar_braco(direito: bool) -> void:
	if not _no_ar():
		c.pose_extra = {}
		return
	var elevacao := rad_to_deg(asin(clampf(_direcao_do_golpe().y, -1.0, 1.0)))
	c.pose_extra = {"UpperArm_R" if direito else "UpperArm_L": Vector3(elevacao, 0.0, 0.0)}


## Identidade desta rajada no token de imobilização (uma por executor, logo por jogador).
func _origem() -> String:
	return "luta_%d" % get_instance_id()


func _no_ar() -> bool:
	return c.ator is CharacterBody3D and not (c.ator as CharacterBody3D).is_on_floor()


## O desenho do golpe: o `mp_impacto.glb` do mod com o clipe idle1/2/3 (a entidade `entity_strike` do Java), 0,3 s.
func _efeito(onde: Vector3, frente: Vector3, animacao: String) -> void:
	if _impacto == null:
		return
	var visual := _impacto.instantiate() as Node3D
	add_child(visual)
	visual.global_position = onde
	# Para cima/baixo o eixo UP é paralelo à direção: `looking_at` degenera, então troca o vetor de referência.
	visual.basis = Basis.looking_at(frente, Vector3.UP if absf(frente.y) < 0.98 else Vector3.RIGHT)
	visual.scale = Vector3.ONE * 2.0
	for malha in visual.find_children("*", "MeshInstance3D", true, false):
		malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if DisplayServer.get_name() == "headless":
			continue
		for i in malha.get_surface_override_material_count():
			var material := malha.get_active_material(i) as BaseMaterial3D
			if material != null:
				material = material.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				malha.set_surface_override_material(i, material)
	var animador := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animador != null and animador.has_animation(animacao):
		animador.play(animacao)
		animador.advance(0)
	_efeitos.append({"no": visual, "idade": 0.0})


func _som(tipo: String, onde: Vector3) -> void:
	var som := AudioStreamPlayer3D.new()
	som.stream = load(PASTA + ("hit_strong.ogg" if tipo in ["pesado", "final"] else "punch_hit1.ogg"))
	som.volume_db = -14.0
	add_child(som)
	som.global_position = onde
	som.finished.connect(som.queue_free)
	som.play()


func _limpar_efeitos() -> void:
	for e in _efeitos:
		if is_instance_valid(e.no):
			e.no.queue_free()
	_efeitos.clear()


func _exit_tree() -> void:
	_soltar_aura()
	_limpar_efeitos()
