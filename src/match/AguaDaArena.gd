class_name AguaDaArena
extends Node3D
# ============================================================================
#  A ÁGUA QUE ALAGA A ARENA no fim da rodada.
#
#  Pedido do dono (2026-09-01): "a plataforma começa a alagar (não permitir que
#  a água vaze da plataforma), a água vai subindo…"
#
#  ------------------------------------------------------------ NÃO VAZA COMO?
#  Não há simulação de fluido: a água é uma CAIXA do tamanho exato da
#  plataforma (200 x 200), que cresce para cima. Ela não vaza porque nunca
#  passa da borda — e cobre os buracos do mapa pelo mesmo motivo, já que a
#  caixa é maciça e o piso furado fica dentro dela. Simular escoamento pelos
#  buracos custaria um sistema inteiro para um efeito que dura 20 segundos por
#  rodada e que o dono descreveu como "não deixar vazar".
#
#  ------------------------------------------------------------- SEM COLISÃO
#  De propósito: o jogador CAI na água (é o que mata), não anda sobre ela.
#
#  --------------------------------------------------------------- SEM ESTADO
#  Este nó não decide nada. O nível é do `Scoreboard`, que é servidor-autoridade
#  e já replica — aqui só se lê e se desenha. Dois donos para o mesmo número é
#  como nascem as divergências entre o que se vê e o que mata.
# ============================================================================

const LADO := MapBuilder.PLATFORM_SIZE      # 200 m: o mesmo lado da plataforma
const FUNDO := -MapBuilder.PLATFORM_THICK   # começa na base da laje, não no topo
const COR := Color(0.16, 0.42, 0.62, 0.55)

# Acima desta diferença o nível VISUAL salta em vez de perseguir: significa que
# não é deriva, é troca de estado — entrou na partida agora, a fase começou, ou
# a fase terminou e a água tem de sumir na hora.
const AJUSTE_MAXIMO := 0.6
# 1/s: com que pressa a deriva do servidor é absorvida. Precisa ser rápido o
# bastante para engolir uma correção INTEIRA dentro do intervalo de sync
# (SYNC_INTERVAL = 0,5 s) — senão o erro se acumula de pacote em pacote até
# passar de AJUSTE_MAXIMO, e aí a água salta. Medido: com 3.0 sobrava resíduo e
# aparecia 1 salto de 0,63 m; com 8.0, nenhum.
const AMORTECIMENTO := 8.0

var _malha: MeshInstance3D = null
var _placar: Node = null
var _y_visual: float = FUNDO
var _alagava: bool = false


func _ready() -> void:
	name = "AguaDaArena"
	_malha = MeshInstance3D.new()
	# Caixa unitária + escala, em vez de redimensionar a `BoxMesh` por quadro:
	# mexer em `size` regenera os vértices a cada quadro da subida. Medido, isto
	# NÃO era o gargalo (a troca não mudou o tempo de quadro em nada) — ficou por
	# ser o jeito certo, não por ganho. O custo era outro, ver abaixo.
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE
	_malha.mesh = caixa
	# Uma laje de 200 x 200 projetando sombra escureceria a arena inteira, e
	# sombra de água transparente não significa nada.
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Vista de DENTRO também: quem afunda continua vendo a superfície acima dele,
	# e sem isto a caixa desapareceria assim que a câmera entrasse nela.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# ⚠️ AQUI ESTAVA O CUSTO DA ENCHENTE, e não onde eu procurei primeiro.
	#   Iluminar por pixel uma superfície de 200 x 200 m custava +13,5% de tempo
	#   de quadro; sem sombreamento, +2,8%. Medido com
	#   `tools/dev_tests/medir_fps_enchente.gd`, que separa desenho de lógica —
	#   a lógica da fase (subida, varredura, afogamento) custa +0,3%, ou seja,
	#   nada. E a água ficou MELHOR: iluminada, o sol lavava o azul.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.10, 0.30, 0.45)
	mat.emission_energy_multiplier = 0.35
	mat.metallic = 0.2
	mat.roughness = 0.15
	_malha.material_override = mat
	add_child(_malha)
	visible = false


var _delta_de_render: float = 0.0


func _process(delta: float) -> void:
	_delta_de_render = delta
	if not is_instance_valid(_placar):
		_placar = get_tree().get_first_node_in_group("scoreboard")
		if _placar == null:
			return
	var alagando: bool = bool(_placar.get("flooding"))
	if not alagando:
		visible = false
		_alagava = false
		return

	var alvo: float = float(_placar.get("flood_y"))
	# ⚠️ POR QUE O NÍVEL VISUAL É PRÓPRIO, E NÃO `flood_y` DIRETO:
	#   `flood_y` só muda no `_physics_process` (60 Hz) e a tela desenha bem mais
	#   rápido. Copiar o valor cru fazia a água andar em DEGRAUS — medido: metade
	#   dos quadros não subia nada e a outra metade subia o dobro. Aqui ela sobe
	#   por quadro de render, e o valor do servidor entra como CORREÇÃO. É o mesmo
	#   arranjo do cronômetro da rodada, pelo mesmo motivo.
	#
	#   Quem mata continua sendo o `flood_y` do placar: isto é desenho.
	if not _alagava:
		_y_visual = alvo          # a fase começou: sem transição, começa onde está
		_alagava = true
	else:
		_y_visual += float(_placar.FLOOD_RISE) * _delta_de_render
		var erro: float = alvo - _y_visual
		if absf(erro) > AJUSTE_MAXIMO:
			_y_visual = alvo      # não é deriva, é outro estado: salta
		else:
			_y_visual += erro * minf(_delta_de_render * AMORTECIMENTO, 1.0)

	var altura: float = maxf(_y_visual - FUNDO, 0.01)
	visible = true
	_malha.scale = Vector3(LADO, altura, LADO)
	# A caixa cresce para os dois lados a partir do centro: o centro tem de ficar
	# na metade, senão o topo da água não bate com o nível que mata.
	_malha.position.y = FUNDO + altura * 0.5
