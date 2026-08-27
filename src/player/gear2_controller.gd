class_name Gear2Controller
extends Node
# ============================================================================
#  GEAR 2 — a primeira TRANSFORMAÇÃO do jogo.
#
#  Decisão do dono (2026-08-27): o slot V da Gomu Gomu deixa de ser um golpe e
#  vira transformação. Enquanto dura, o personagem ganha o efeito do Gear 2 e
#  (quando a pesquisa dos golpes fechar) um conjunto próprio de golpes.
#
#  --------------------------------------------------------- POR QUE UM ESTADO
#  Um golpe nasce, resolve e morre no mesmo instante. Uma transformação tem
#  ENTRADA, DURAÇÃO e SAÍDA — e a saída pode chegar por caminhos que não são o
#  relógio: morrer, trocar de fruta, trocar de personagem. Cada um desses larga
#  o corpo num estado diferente, e é por isso que o desligamento mora todo aqui,
#  num lugar só.
#
#  ⚠️ O QUE ESTA CLASSE **NÃO** FAZ (ainda): remapear Z/X/C para os golpes do
#  Gear 2. Isso depende da pesquisa dos golpes do Luffy, que continua aberta na
#  `docs/FILA_DE_TAREFAS.md` — sem ela não há o que remapear. O visual e o
#  estado ficam prontos aqui; o conteúdo entra depois, e entra por este mesmo
#  ponto (`ativar` / `desativar`).
#
#  ⚠️ E O RED HAWK NÃO FOI APAGADO. Ele era o V antigo e continua em
#  `GomuFX._red_hawk` (variante 3), agora sem tecla. É o candidato natural ao
#  conjunto transformado — apagá-lo agora seria jogar fora trabalho pronto por
#  causa de uma tecla.
#
#  --------------------------------------------------- QUANDO VIRAR UM MOTOR
#  Isto é deliberadamente a Gear 2, e não um "motor de transformações". Com UMA
#  transformação, generalizar seria adivinhar. **Gatilho para extrair o motor:**
#  quando a SEGUNDA transformação entrar (Gear 3, ou outra fruta). Aí o que for
#  comum — relógio, salvar/restaurar visual, os quatro caminhos de saída — sobe
#  para uma base e a Gear 2 vira só a configuração dela.
#
#  ------------------------------------------------------------- MULTIJOGADOR
#  Ligado a partir de `Player._fire_skill`, que é a APRESENTAÇÃO do golpe e roda
#  em TODOS os peers. Então todo mundo vê a fumaça, a pele e o chapéu. O relógio
#  corre local em cada peer: para efeito cosmético isso basta, e evita um RPC por
#  segundo só para sincronizar um número que ninguém lê.
# ============================================================================

const DURACAO := 30.0

## Pele do Gear 2: o sangue bombeado deixa o corpo AVERMELHADO. Não é o tom de
## pele normal — se fosse, a transformação não leria na tela, que é o ponto dela.
const COR_PELE := Color(0.93, 0.51, 0.40)

const CAMINHO_CHAPEU := "res://assets/models/acessorios/chapeu_palha.glb"

## Que fração da cabeça a copa do chapéu engole, contada do topo para baixo.
## Decisão do dono (2026-08-27): 1/3. É o que faz o chapéu ficar VESTIDO em vez
## de pousado — a versão anterior apoiava no topo e lia como prato na cabeça.
const FRACAO_ENGOLIDA := 1.0 / 3.0

signal mudou(ativo: bool)

var _dono: Node3D = null
var _rig = null
var _restante := 0.0
var _ativo := false

# id da malha -> material_override que ela tinha ANTES. Guardar o anterior (em
# vez de repintar com a cor do time no fim) é o que faz a saída devolver o corpo
# EXATAMENTE como estava — inclusive quando não havia tinta nenhuma.
var _materiais_antes: Dictionary = {}
var _chapeu: Node3D = null
var _fumaca: GPUParticles3D = null


func montar(dono: Node3D, rig) -> void:
	_dono = dono
	_rig = rig


func esta_ativo() -> bool:
	return _ativo


func tempo_restante() -> float:
	return _restante


func ativar() -> void:
	if _ativo:
		# Reativar RENOVA o relógio em vez de empilhar. Empilhar duração é a
		# porta de entrada para "fiquei transformado a partida inteira".
		_restante = DURACAO
		return
	_ativo = true
	_restante = DURACAO
	_pintar_pele()
	_ligar_fumaca()
	_por_chapeu()
	mudou.emit(true)
	print("⚙️  GEAR 2 ativado — %.0f s" % DURACAO)


func desativar() -> void:
	if not _ativo:
		return
	_ativo = false
	_restante = 0.0
	_restaurar_pele()
	_desligar_fumaca()
	_tirar_chapeu()
	mudou.emit(false)
	print("⚙️  Gear 2 encerrado")


func atualizar(delta: float) -> void:
	if not _ativo:
		return
	# ⚠️ O modelo pode ter sido reconstruído embaixo de nós (troca de personagem
	# refaz o rig inteiro). Aí o chapéu e as malhas pintadas já não existem, e
	# insistir no estado deixaria um chapéu órfão em cena.
	if _chapeu != null and not is_instance_valid(_chapeu):
		desativar()
		return
	_restante -= delta
	if _restante <= 0.0:
		desativar()


# ------------------------------------------------------------------ a pele
func _pintar_pele() -> void:
	_materiais_antes.clear()
	for m in _malhas_do_corpo():
		_materiais_antes[m.get_instance_id()] = m.material_override
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COR_PELE
		# Um mínimo de emissão pelo mesmo motivo do `_tingir_modelo`: sem ela a
		# silhueta some contra a sombra dura do cel shading.
		mat.emission_enabled = true
		mat.emission = COR_PELE
		mat.emission_energy_multiplier = 0.45
		m.material_override = mat


func _restaurar_pele() -> void:
	for id in _materiais_antes:
		var m = instance_from_id(id)
		if m is MeshInstance3D and is_instance_valid(m):
			(m as MeshInstance3D).material_override = _materiais_antes[id]
	_materiais_antes.clear()


## As malhas do CORPO — sem o chapéu, que é acessório e não pode virar pele.
func _malhas_do_corpo() -> Array:
	var out: Array = []
	if _rig == null:
		return out
	var modelo = _rig.modelo() if _rig.has_method("modelo") else null
	if modelo == null or not is_instance_valid(modelo):
		return out
	var todas: Array = []
	FxUtil._collect_meshes(modelo, todas)
	for m in todas:
		if m is MeshInstance3D and not _e_do_chapeu(m):
			out.append(m)
	return out


func _e_do_chapeu(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p == _chapeu:
			return true
		p = p.get_parent()
	return false


# ---------------------------------------------------------------- a fumaça
func _ligar_fumaca() -> void:
	if _fumaca != null and is_instance_valid(_fumaca):
		return
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)     # vapor SOBE
	# ⚠️ GRÃO PEQUENO. A primeira versão usava `grain(0.16)` com escala até 1,3 —
	# quadrados de 21 cm, que na tela leem como CAIXAS flutuando, não como vapor.
	# O jogo é anguloso, mas fumaça é a única coisa aqui que não pode ser.
	pm.scale_min = 0.35
	pm.scale_max = 0.9
	# Emite de dentro do corpo inteiro, não de um ponto: é vapor saindo da pele.
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.26, 0.60, 0.20)
	pm.color_ramp = FxUtil.gradient([
		Color(1.0, 0.98, 0.95, 0.55),
		Color(0.95, 0.92, 0.90, 0.30),
		Color(0.90, 0.88, 0.88, 0.0)])
	# `FxUtil.grain` já vem com material billboard que usa a `color_ramp` como
	# albedo — e MISTURADO, não aditivo. Vapor branco somado estoura em branco
	# puro e vira uma mancha; fumaça é mistura, não brilho.
	_fumaca = FxUtil.particles(80, 1.3, false, pm, FxUtil.grain(0.085))
	_fumaca.name = "Gear2Vapor"
	_fumaca.position = Vector3(0, 0.9, 0)
	_dono.add_child(_fumaca)


func _desligar_fumaca() -> void:
	if _fumaca != null and is_instance_valid(_fumaca):
		# `emitting = false` e só então liberar: matar na hora corta as partículas
		# que ainda estão no ar e o vapor SOME de um quadro para o outro.
		_fumaca.emitting = false
		FxUtil.autofree(_fumaca, 1.5)
	_fumaca = null


# ---------------------------------------------------------------- o chapéu
func _por_chapeu() -> void:
	if _chapeu != null and is_instance_valid(_chapeu):
		return
	var cabeca: Node3D = _rig.cabeca() if _rig != null and _rig.has_method("cabeca") else null
	if cabeca == null or not is_instance_valid(cabeca):
		push_warning("[Gear2] sem nó de cabeça — o chapéu não foi invocado")
		return
	if not ResourceLoader.exists(CAMINHO_CHAPEU):
		push_warning("[Gear2] chapéu ausente: " + CAMINHO_CHAPEU)
		return
	var cena: PackedScene = load(CAMINHO_CHAPEU)
	_chapeu = cena.instantiate() as Node3D
	_chapeu.name = "ChapeuDePalha"
	cabeca.add_child(_chapeu)
	# ⚠️ ALTURA MEDIDA DA PRÓPRIA CABEÇA, não chutada. A caixa do chapéu foi
	# modelada nas dimensões desta AABB (ver `tools/blender/chapeu_palha.py`), e
	# a origem dele é a linha de 2/3. Tirar os dois números da mesma fonte é o
	# que mantém o encaixe se o modelo mudar de proporção — em vez de repetir
	# aqui um número que mora no `.scn`.
	var cx := _caixa_da_cabeca(cabeca)
	_chapeu.position = Vector3(0, cx.end.y - cx.size.y * FRACAO_ENGOLIDA, 0)


## A AABB da cabeça em espaço LOCAL dela — que é o mesmo espaço do chapéu, já que
## ele entra como filho. Por isso não há conversão de escala aqui.
func _caixa_da_cabeca(cabeca: Node3D) -> AABB:
	if cabeca is MeshInstance3D and (cabeca as MeshInstance3D).mesh != null:
		return (cabeca as MeshInstance3D).mesh.get_aabb()
	var uniao := AABB()
	var primeiro := true
	var malhas: Array = []
	FxUtil._collect_meshes(cabeca, malhas)
	for m in malhas:
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			var a: AABB = (m as MeshInstance3D).mesh.get_aabb()
			uniao = a if primeiro else uniao.merge(a)
			primeiro = false
	# Sem malha nenhuma: uma caixa de cabeça plausível, para o chapéu não nascer
	# no chão. Avisa, porque isso significa que o modelo mudou de forma.
	if primeiro:
		push_warning("[Gear2] cabeça sem malha — usando caixa padrão para o chapéu")
		return AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 0.5, 0.5))
	return uniao


func _tirar_chapeu() -> void:
	if _chapeu != null and is_instance_valid(_chapeu):
		_chapeu.queue_free()
	_chapeu = null
