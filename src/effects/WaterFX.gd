class_name WaterFX
extends RefCounted
# ============================================================================
#  KARATE TRITÃO — a água como ARMA, não como enfeite.
#
#  POR QUE ESTE ARQUIVO EXISTE (2026-08-13)
#
#  Até aqui o estilo inteiro morava em quatro linhas dentro do
#  `FightingStyles._cast_water`: UM esguicho de partículas, o MESMO para Z, X,
#  C e V. O `variant` chegava na função e era ignorado. Ou seja: o estilo tinha
#  quatro teclas e um golpe só, com quatro nomes diferentes na HUD.
#
#  O pedido do dono separa as três teclas que sobraram por FORMA, não por
#  número:
#     Z — "disparos de água a partir da mão como se fossem tiros"
#     X — "manter como está"
#     C — "onda de água cria uma onda e a impulsiona para frente"
#
#  A regra que o dono repetiu e que manda no desenho daqui: *"coloca um visual
#  bonito, a mecânica não é difícil de alterar mas o visual depois sempre causa
#  problema"*. Por isso TODO número que afina o golpe é uma constante nomeada no
#  topo de cada bloco — velocidade, alcance, largura, altura, cadência, fração
#  de dano. Afinar o golpe é editar uma constante; não é reescrever o efeito.
#
#  ⚠️ ONDE O DANO É DECIDIDO: quem aplica é a `DamageZone`, e ela multiplica por
#  `DAMAGE_SCALE` (0.12) — o foco do projeto é knockback, não dano. Então o
#  número que sai daqui NÃO é o dano final; é o dano nominal do golpe. Ver
#  src/effects/DamageZone.gd.
#
#  ⚠️ PROJÉTIL RÁPIDO: a `DamageZone` anda por teleporte e varre o caminho com um
#  raio (`_varrer_caminho`) justamente porque `Area3D` só enxerga quem está
#  sobreposto NAQUELE quadro. Os tiros do Z dependem dessa varredura para
#  existir — foi ela que tornou seguro dar 46 m/s a um projétil de raio 0,42.
# ============================================================================

# ------------------------------------------------------------------- PALETA
# A cor do estilo (`FightingStyles.STYLES["karate_tritao"]["cor"]`) é o AZUL
# MÉDIO daqui. Repetida como constante em vez de lida da tabela porque a tabela
# guarda a cor da HUD (uma cor chapada) e o efeito precisa de uma FAMÍLIA: água
# rasa clara, água funda escura e espuma branca. Ler só a cor da HUD daria um
# jato de uma cor só, que é exatamente o que o esguicho antigo parecia.
const AGUA_CLARA := Color(0.55, 0.88, 1.00)
const AGUA := Color(0.15, 0.65, 0.95)
const AGUA_FUNDA := Color(0.04, 0.28, 0.62)
const ESPUMA := Color(0.94, 0.99, 1.00)

# Rampa das gotas: nasce espuma branca, vira azul e some transparente. É a
# leitura de "água" sem textura nenhuma — o brilho da ponta é o que separa
# respingo d'água de fumaça azul.
const GOTAS := [
	Color(0.94, 0.99, 1.00, 0.95),
	Color(0.45, 0.85, 1.00, 0.80),
	Color(0.10, 0.45, 0.85, 0.35),
	Color(0.05, 0.25, 0.55, 0.00),
]

# Altura dos PÉS abaixo do `global_position` do jogador. O colisor é uma caixa
# de 1,6 m centrada na origem do corpo (ver `Player._ready`), então o chão está
# 0,8 m abaixo do centro. A onda do C é RASTEIRA — sem isso ela nasce flutuando
# na cintura, e uma onda no ar não lê como onda.
const ALTURA_DOS_PES := 0.8

# ============================================================================
#  Z — MURASAME: TIROS D'ÁGUA SAINDO DA MÃO
# ============================================================================
#
#  A diferença entre "esguicho" e "tiro" é CADÊNCIA e SILHUETA: o esguicho é uma
#  nuvem contínua sem forma; o tiro é um corpo compacto que sai, viaja e chega.
#  Por isso aqui são 6 projéteis SEPARADOS, com intervalo audível entre eles,
#  cada um com bala modelada (cabeça + rabo + risco), e não um cone de partícula.
#
#  Saem da PONTA DO ANTEBRAÇO DIREITO, como todo disparo do projeto (o padrão é
#  o `GoroFXGrande._ponto_do_braco`). O ponto é lido A CADA TIRO, não uma vez no
#  começo: durante os ~0,45 s da rajada o braço se mexe, e uma rajada que nasce
#  toda no mesmo ponto do espaço denuncia que o efeito não está preso ao corpo.

const TIROS_QTD := 6              # projéteis por rajada
const TIROS_INTERVALO := 0.085    # s entre tiros -> rajada dura ~0,43 s
const TIRO_VEL := 46.0            # m/s (ver nota de tunelamento no cabeçalho)
const TIRO_ALCANCE := 34.0        # m; a vida do projétil sai daqui (alcance/vel)
const TIRO_RAIO := 0.42           # raio da DamageZone
const TIRO_KB := 6.0              # knockback baixo: o Z é golpe de chip, não de arremesso
const TIRO_ESPALHAMENTO := 0.030  # rad de abertura da rajada (~1,7°)
const TIRO_CALIBRE := 0.30        # m; escala TODO o modelo da bala
const TIRO_RISCO := 2.2           # m de risco d'água atrás da bala

# Fração do dano nominal do slot que CADA tiro carrega. Acertar a rajada inteira
# vale 6 × 0,30 = 1,8× o golpe antigo de um acerto só; acertar dois tiros vale
# 0,6×. É de propósito: a rajada premia mira, não a tecla.
const TIRO_DANO_FRACAO := 0.30

static func tiros_da_mao(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	if not _mundo_vivo(world):
		return
	var rumo := fwd.normalized()
	if rumo.length_squared() < 0.01:
		rumo = Vector3(0, 0, -1)
	var dano_tiro := damage * TIRO_DANO_FRACAO

	for i in TIROS_QTD:
		var atraso := float(i) * TIROS_INTERVALO
		if atraso <= 0.0:
			_um_tiro(world, _ponto_da_mao(caster, origin), rumo, dano_tiro, caster, i)
			continue
		# Agendado por timer em vez de um nó controlador (como o GomuGatling):
		# são 6 eventos sem estado entre eles. Um Node3D só para contar até 6
		# seria uma classe a mais no cache de `class_name` sem nada que a
		# justifique. GATILHO para virar controlador: se a rajada passar a
		# depender do que aconteceu no tiro anterior (recuo acumulado, trava de
		# mira, munição), aí o estado existe e o nó se paga.
		var t := world.get_tree().create_timer(atraso)
		t.timeout.connect(func() -> void:
			if not _mundo_vivo(world):
				return
			_um_tiro(world, _ponto_da_mao(caster, origin), rumo, dano_tiro, caster, i))

static func _um_tiro(world: Node, de: Vector3, fwd: Vector3, dano: float, caster: Node, indice: int) -> void:
	var dir := _com_espalhamento(fwd, indice)

	var zona := DamageZone.new()
	world.add_child(zona)
	zona.global_position = de
	# A bala é modelada apontando pra −Z (mesma convenção da munição da Buki).
	# Sem este `look_at` ela deitaria no Z do MUNDO e só ficaria certa quando o
	# jogador atirasse pro norte — bug que já custou caro na BukiProjeteis.
	if absf(dir.y) < 0.999:
		zona.look_at(de + dir, Vector3.UP)
	zona.add_child(_bala_dagua())

	var vida := TIRO_ALCANCE / TIRO_VEL
	zona.setup(dano, TIRO_KB, dir * TIRO_VEL, vida, caster, TIRO_RAIO)

	_fogacho_dagua(world, de, dir)
	# Pitch BAIXO de propósito: é o mesmo estalo da pistola, mas grave lê como
	# "arma de água" e não como "revólver". Varia a cada tiro para 6 disparos em
	# 0,43 s não virarem um bipe único.
	AudioFX.pistol(world, de, randf_range(0.68, 0.84))
	_agendar_respingo(world, zona, vida)

# Abertura da rajada: alterna lados em vez de sortear puro, senão os 6 tiros
# caem no mesmo lado com frequência e a rajada parece torta em vez de aberta.
static func _com_espalhamento(fwd: Vector3, indice: int) -> Vector3:
	var lado := 1.0 if indice % 2 == 0 else -1.0
	var ref := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.FORWARD
	var direita := fwd.cross(ref).normalized()
	var cima := direita.cross(fwd).normalized()
	var ax := TIRO_ESPALHAMENTO * lado * randf_range(0.3, 1.0)
	var ay := TIRO_ESPALHAMENTO * randf_range(-0.7, 0.7)
	return (fwd + direita * ax + cima * ay).normalized()

# A BALA D'ÁGUA. Modelada apontando pra −Z. Três peças, e cada uma resolve um
# problema de leitura diferente:
#   • cabeça  — o volume que o olho persegue;
#   • rabo    — dá DIREÇÃO à cabeça (uma esfera sozinha não tem frente);
#   • risco   — a 46 m/s a bala cruza 0,77 m por quadro; sem um traço colado
#               atrás, o tiro pisca em vez de voar. Geometria, não partícula:
#               partícula nessa velocidade sai espaçada e vira tracejado.
static func _bala_dagua() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "BalaDagua"
	var r := TIRO_CALIBRE
	var casca := _mat_agua(AGUA_CLARA, 0.78, 2.2)
	var nucleo := _mat_luz(Color(ESPUMA.r, ESPUMA.g, ESPUMA.b, 0.85))

	# cabeça (gota achatada: mais comprida que larga, senão vira bolinha)
	var cab := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.55
	sm.height = r * 1.10
	sm.radial_segments = 10
	sm.rings = 6
	cab.mesh = sm
	cab.scale = Vector3(1.0, 1.0, 1.7)
	cab.position = Vector3(0, 0, -r * 0.35)
	cab.material_override = casca
	raiz.add_child(cab)

	# núcleo brilhante dentro da cabeça: é o que separa "água" de "gel azul"
	var luz := MeshInstance3D.new()
	var sl := SphereMesh.new()
	sl.radius = r * 0.26
	sl.height = r * 0.52
	sl.radial_segments = 8
	sl.rings = 4
	luz.mesh = sl
	luz.position = Vector3(0, 0, -r * 0.45)
	luz.material_override = nucleo
	raiz.add_child(luz)

	# rabo afilado
	var rabo := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r * 0.46
	cm.height = r * 1.5
	cm.radial_segments = 8
	cm.rings = 1
	rabo.mesh = cm
	rabo.rotation_degrees.x = 90.0     # topo do cilindro (+Y) vai pra +Z: a ponta fica ATRÁS
	rabo.position = Vector3(0, 0, r * 0.85)
	rabo.material_override = casca
	raiz.add_child(rabo)

	# risco: cilindro fino e aditivo esticado pra trás
	var risco := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = r * 0.14
	rm.bottom_radius = r * 0.05
	rm.height = TIRO_RISCO
	rm.radial_segments = 6
	rm.rings = 1
	risco.mesh = rm
	risco.rotation_degrees.x = -90.0
	risco.position = Vector3(0, 0, TIRO_RISCO * 0.5)
	risco.material_override = _mat_luz(Color(AGUA_CLARA.r, AGUA_CLARA.g, AGUA_CLARA.b, 0.32))
	raiz.add_child(risco)

	# gotículas que ficam para trás no MUNDO (local_coords falso, o padrão): a
	# gota nasce e FICA, a bala vai embora — é isso que desenha o rastro. Local
	# faria a nuvem viajar junto e o tiro viraria uma bola de névoa.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, -5.5, 0)
	pm.scale_min = 0.35
	pm.scale_max = 0.9
	pm.color_ramp = FxUtil.gradient(GOTAS)
	var rastro := FxUtil.particles(14, 0.30, false, pm, FxUtil.grain(r * 0.9))
	raiz.add_child(rastro)

	return raiz

# Fogacho na mão: a "boca" do cano. Cone curto e explosivo + um anel de espuma
# que abre e some. Sem ele o tiro parece nascer 1 m à frente do corpo.
static func _fogacho_dagua(world: Node, pos: Vector3, dir: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 26.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient(GOTAS)
	var jato := FxUtil.particles(26, 0.28, true, pm, FxUtil.grain(0.22), 0.9)
	world.add_child(jato)
	jato.global_position = pos
	FxUtil.autofree(jato, 0.6)

	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.10
	tm.outer_radius = 0.20
	anel.mesh = tm
	var mat := _mat_luz(Color(ESPUMA.r, ESPUMA.g, ESPUMA.b, 0.75))
	anel.material_override = mat
	world.add_child(anel)
	anel.global_position = pos + dir * 0.12
	if absf(dir.y) < 0.999:
		anel.look_at(anel.global_position + dir, Vector3.UP)
		anel.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	anel.scale = Vector3(0.4, 0.4, 0.4)
	var tw := anel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anel, "scale", Vector3(1.6, 0.6, 1.6), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(anel.queue_free)

# RESPINGO NO FIM DO ALCANCE. A `DamageZone` não avisa quando acerta (não tem
# sinal de impacto e ela está fora do escopo desta tarefa), então o respingo é
# agendado pelo TEMPO: um pouco antes de a bala morrer, lê onde ela está e
# quebra a água ali. O efeito colateral é bom — o tiro que erra também "molha" o
# ponto onde acabou, em vez de sumir no ar.
static func _agendar_respingo(world: Node, zona: Node3D, vida: float) -> void:
	var t := world.get_tree().create_timer(vida * 0.94)
	t.timeout.connect(func() -> void:
		if not _mundo_vivo(world):
			return
		if is_instance_valid(zona) and zona.is_inside_tree():
			_respingo(world, zona.global_position))

static func _respingo(world: Node, pos: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 78.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.5
	pm.gravity = Vector3(0, -13.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 1.0
	pm.color_ramp = FxUtil.gradient(GOTAS)
	var p := FxUtil.particles(22, 0.42, true, pm, FxUtil.grain(0.20), 0.95)
	world.add_child(p)
	p.global_position = pos
	FxUtil.autofree(p, 0.8)

# ============================================================================
#  C — KARAKUSA KAWARAGETE: A ONDA EMPURRADA PRA FRENTE
# ============================================================================
#
#  O pedido é explícito no VERBO: "cria uma onda e a IMPULSIONA para frente".
#  Não é uma explosão no lugar — tem que dar pra ver a crista avançando. Por
#  isso a onda inteira é FILHA de uma `DamageZone` com velocidade: a hitbox e o
#  desenho viajam juntos por construção, e nada pode dessincronizar os dois.
#
#  ⚠️ A ONDA É RASTEIRA. O rumo tem o Y zerado mesmo que o jogador esteja
#  olhando pro céu: uma onda que sobe em diagonal não lê como onda, lê como
#  jato. Quem quiser jato tem o Z.
#
#  ⚠️ A DIREÇÃO DO KNOCKBACK é RADIAL (a `DamageZone` calcula alvo − centro da
#  zona), não `fwd` fixo. Na prática dá no mesmo: a onda só alcança quem está à
#  frente dela, então o vetor radial já aponta pra frente. Fixar o vetor exigiria
#  um campo novo na `DamageZone`, que está fora do escopo desta tarefa — ver o
#  relatório e docs/LISTA_DE_CORRECOES.md.

const ONDA_VEL := 15.0             # m/s — dá pra acompanhar com o olho
const ONDA_ALCANCE := 26.0         # m; vida = alcance/vel = ~1,73 s
const ONDA_LARGURA := 6.4          # m de frente de onda
const ONDA_ALTURA := 3.2           # m de crista
const ONDA_ESPESSURA := 0.9        # m de profundidade da parede
const ONDA_RAIO := 2.9             # raio da DamageZone (uma esfera cobre a crista)
const ONDA_KB := 34.0              # knockback FORTE: o golpe é de arremesso
const ONDA_NASCE_A := 3.0          # m à frente do jogador
const ONDA_LAMELAS := 11           # colunas da crista (silhueta recortada)
const ONDA_INCLINACAO := 16.0      # graus que a crista tomba pra frente
const ONDA_LABIO := 0.34           # raio do rolo de espuma no alto
const ONDA_CRESCIMENTO := 0.26     # s pra onda subir do chão até a altura cheia
const ONDA_DESMANCHE := 0.45       # s de dissolução no fim

# ----------------------------------------------------------- PERFIL DE ONDA
#
#  POR QUE A CRISTA VIROU PARAMÉTRICA (2026-08-14)
#
#  A ultimate da Gura Gura precisa de tsunamis de dezenas de metros. A escolha
#  era duplicar a crista (11 lamelas + lábio + espuma + borrifo) num arquivo
#  novo, ou deixar as medidas entrarem por parâmetro. Duplicar significaria que
#  toda melhoria de leitura da onda — e o lábio de espuma foi descoberto
#  justamente ajustando ISTO — passaria a ter dois donos, e um deles ia ficar
#  para trás em silêncio.
#
#  ⚠️ O C DO KARATÊ TRITÃO NÃO MUDA. Os `const` acima continuam sendo os
#  valores de hoje, e `perfil_padrao()` é a única coisa que o `onda()` usa. Um
#  perfil vazio reproduz byte a byte a onda de antes — é isso que torna a
#  mudança provável por medição (dano do C continua 36 × 0.12 = 4,32).
#
#  ⚠️ O QUE O PERFIL *NÃO* CARREGA: hitbox, velocidade da `DamageZone` e vida.
#  Isso é de propósito. A crista é DESENHO; quem decide o combate é quem a
#  monta. O `onda()` monta uma esfera de raio 2,9 que viaja 26 m; a Gura monta
#  uma CAIXA de 70 m de frente que atravessa o mapa. Amarrar os dois no mesmo
#  objeto obrigaria o C a carregar campos que ele nunca usa.
class PerfilDeOnda extends RefCounted:
	var largura: float          # m de frente de onda
	var altura: float           # m de crista
	var espessura: float        # m de profundidade da parede
	var lamelas: int            # colunas da crista (silhueta recortada)
	var inclinacao: float       # graus que a crista tomba pra frente
	var labio: float            # raio do rolo de espuma no alto
	var labio_pedacos: int      # em quantos rolos o lábio é quebrado (1 = inteiro)
	var cor_corpo: Color        # azul da massa de água
	var alfa_corpo: float       # translucidez da massa
	var emissao_corpo: float    # brilho próprio da água (0 = só luz de cena)
	var escala_gota: float      # multiplicador dos respingos (espuma/borrifo)

# Os valores de HOJE, num lugar só. Quem quiser uma onda diferente parte daqui e
# muda o que precisa — o que não mexer continua sendo o Karatê Tritão.
static func perfil_padrao() -> PerfilDeOnda:
	var p := PerfilDeOnda.new()
	p.largura = ONDA_LARGURA
	p.altura = ONDA_ALTURA
	p.espessura = ONDA_ESPESSURA
	p.lamelas = ONDA_LAMELAS
	p.inclinacao = ONDA_INCLINACAO
	p.labio = ONDA_LABIO
	p.labio_pedacos = 1        # o C sempre teve UM cilindro inteiro — não muda
	p.cor_corpo = AGUA
	p.alfa_corpo = 0.62
	p.emissao_corpo = 1.4
	p.escala_gota = 1.0
	return p

# A CRISTA como PEÇA PÚBLICA: devolve um `Node3D` pronto para ser filho de
# qualquer coisa que ande (a `DamageZone` do C, a do tsunami da Gura). Os dois
# materiais saem no meta `mats` porque quem monta precisa deles para dissolver a
# onda no fim — devolver uma tupla seria mais bonito e menos usável.
static func crista_de_onda(p: PerfilDeOnda) -> Node3D:
	var mat_corpo := _mat_agua(p.cor_corpo, p.alfa_corpo, p.emissao_corpo)
	mat_corpo.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_labio := _mat_agua(ESPUMA, 0.80, 2.4)
	var raiz := _crista(mat_corpo, mat_labio, p)
	raiz.set_meta("mats", [mat_corpo, mat_labio])
	return raiz

static func onda(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	if not _mundo_vivo(world):
		return
	var rumo := Vector3(fwd.x, 0.0, fwd.z)
	if rumo.length_squared() < 0.0001:
		rumo = Vector3(0, 0, -1)
	rumo = rumo.normalized()

	var chao := _altura_do_chao(caster, origin)
	var berco := Vector3(origin.x, chao, origin.z) + rumo * ONDA_NASCE_A

	var zona := DamageZone.new()
	world.add_child(zona)
	# A esfera de dano fica na meia-altura da crista: assim ela pega quem está de
	# pé no chão sem precisar de raio absurdo.
	zona.global_position = berco + Vector3.UP * (ONDA_ALTURA * 0.5)
	zona.look_at(zona.global_position + rumo, Vector3.UP)

	# Um material compartilhado por TODAS as lamelas. É o que permite dissolver a
	# onda inteira com um tween só, em vez de 11 tweens correndo em paralelo.
	var perfil := perfil_padrao()
	var crista := crista_de_onda(perfil)
	var mats: Array = crista.get_meta("mats")
	var mat_corpo: StandardMaterial3D = mats[0]
	var mat_labio: StandardMaterial3D = mats[1]
	crista.position = Vector3(0, -ONDA_ALTURA * 0.5, 0)   # base das lamelas no chão
	zona.add_child(crista)

	var vida := ONDA_ALCANCE / ONDA_VEL
	zona.setup(damage, ONDA_KB, rumo * ONDA_VEL, vida, caster, ONDA_RAIO)

	# SUBIDA: a onda se levanta do chão em vez de aparecer inteira. Começa baixa e
	# estreita e abre — é o que dá a sensação de água sendo EMPURRADA, e não de
	# uma parede teleportada pra frente do jogador.
	crista.scale = Vector3(0.55, 0.10, 0.6)
	var tw := crista.create_tween()
	tw.set_parallel(true)
	tw.tween_property(crista, "scale", Vector3.ONE, ONDA_CRESCIMENTO) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# DESMANCHE: a água perde corpo antes de a hitbox morrer, senão a onda some
	# num quadro só e o golpe parece ter sido cortado.
	tw.tween_property(mat_corpo, "albedo_color:a", 0.0, ONDA_DESMANCHE) \
		.set_delay(vida - ONDA_DESMANCHE)
	tw.tween_property(mat_labio, "albedo_color:a", 0.0, ONDA_DESMANCHE) \
		.set_delay(vida - ONDA_DESMANCHE)

	_erupcao(world, berco, rumo, perfil.largura)
	AudioFX.whoosh(world, berco, 0.55)      # grave = massa de água, não vento
	AudioFX.impact(world, berco, 0.70)

# A CRISTA. Lamelas de caixa em vez de um plano curvo: o jogo é voxel/facetado, e
# uma parede lisa aqui destoaria de tudo. A altura de cada lamela segue um arco
# (`sin`) com ruído — o arco dá a forma de onda, o ruído impede que 11 caixas
# iguais leiam como grade.
static func _crista(mat_corpo: StandardMaterial3D, mat_labio: StandardMaterial3D,
		p: PerfilDeOnda) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Crista"
	var passo := p.largura / float(p.lamelas)

	for i in p.lamelas:
		var t := (float(i) + 0.5) / float(p.lamelas)
		var arco := sin(t * PI)
		var alt: float = p.altura * (0.34 + 0.66 * arco) * randf_range(0.86, 1.14)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(passo * 0.96, alt, p.espessura * (0.7 + 0.5 * arco))
		mi.mesh = bm
		mi.material_override = mat_corpo
		mi.position = Vector3(-p.largura * 0.5 + passo * (float(i) + 0.5), alt * 0.5, 0.0)
		# Tombar pra frente: a onda CAI pra onde vai. Quem está no meio (arco alto)
		# tomba mais — é o que desenha o rolo.
		mi.rotation_degrees.x = -p.inclinacao * arco
		raiz.add_child(mi)

	# LÁBIO: o rolo de espuma no alto. Um cilindro deitado no eixo X, empurrado
	# pra frente. É a peça que faz a silhueta ler como "onda quebrando" e não como
	# "muro azul" — sem ele o efeito parece um portão.
	#
	# ⚠️ EM ESCALA GIGANTE UM LÁBIO INTEIRO VIRA UMA RÉGUA. Num tsunami de 200 m
	# de frente, o cilindro único desenha uma listra branca perfeitamente reta no
	# horizonte — a única peça da onda que não acompanha o arco, e a que mais
	# denuncia que aquilo é geometria. `labio_pedacos` quebra o rolo em pedaços
	# que SOBEM E DESCEM com o mesmo arco das lamelas.
	# Com `labio_pedacos = 1` (o padrão, e o que o C do Karatê Tritão usa) o
	# resultado é EXATAMENTE o cilindro único de sempre: um pedaço, no centro,
	# na altura de sempre.
	var pedacos: int = maxi(p.labio_pedacos, 1)
	for i in pedacos:
		var t := (float(i) + 0.5) / float(pedacos)
		var arco := 1.0 if pedacos == 1 else sin(t * PI)
		var labio := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = p.labio
		cm.bottom_radius = p.labio
		cm.height = (p.largura * 0.90) / float(pedacos)
		cm.radial_segments = 10
		cm.rings = 1
		labio.mesh = cm
		labio.material_override = mat_labio
		labio.rotation_degrees = Vector3(0, 0, 90)     # eixo +Y do cilindro -> eixo X
		var cx: float = 0.0 if pedacos == 1 \
			else (t - 0.5) * p.largura * 0.90
		# Acompanha a mesma curva das lamelas (0,34 + 0,66·arco), um pouco acima
		# delas — é o rolo de espuma quebrando na crista.
		# Ruído SÓ quando o lábio é quebrado: sem ele os pedaços do meio, onde o
		# arco é quase plano, encostam num sarrafo branco único — o mesmo defeito
		# que se estava tentando corrigir, só que menor. Com `pedacos == 1` a
		# conta não é tocada, e o C sai idêntico ao de sempre.
		var cy: float = p.altura * 0.90
		if pedacos > 1:
			cy *= (0.34 + 0.66 * arco) * randf_range(0.94, 1.10)
		labio.position = Vector3(cx, cy, -p.espessura * 0.55)
		raiz.add_child(labio)

	# ESPUMA que VIAJA com a onda (`local_coords` ligado): é a crista borbulhando.
	#
	# ⚠️ O RESPINGO ESCALA JUNTO, e escala DIREITO. Gota, velocidade e gravidade
	# são multiplicadas pelo mesmo `escala_gota`: o alcance balístico é v²/g, então
	# multiplicar os dois por k multiplica o alcance por k — a espuma de um
	# tsunami de 22 m sobe proporcionalmente à de uma onda de 3,2 m, em vez de
	# virar uma poeirinha grudada na base.
	var k: float = p.escala_gota
	var pe := ParticleProcessMaterial.new()
	pe.direction = Vector3(0, 0.6, -1.0)
	pe.spread = 34.0
	pe.initial_velocity_min = 1.5 * k
	pe.initial_velocity_max = 5.0 * k
	pe.gravity = Vector3(0, -9.0 * k, 0)
	pe.scale_min = 0.5 * k
	pe.scale_max = 1.6 * k
	pe.color_ramp = FxUtil.gradient(GOTAS)
	pe.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pe.emission_box_extents = Vector3(p.largura * 0.5, 0.25 * k, p.espessura * 0.4)
	var espuma := FxUtil.particles(int(90.0 * k), 0.55, false, pe, FxUtil.grain(0.30 * k))
	espuma.local_coords = true
	espuma.position = Vector3(0, p.altura * 0.86, 0)
	raiz.add_child(espuma)

	# BORRIFO que FICA para trás (mundo, o padrão): o rastro molhado que a onda
	# deixa no caminho. É o segundo sinal de que ela ANDOU — o primeiro é a crista.
	var pb := ParticleProcessMaterial.new()
	pb.direction = Vector3(0, 1.0, 0.4)
	pb.spread = 55.0
	pb.initial_velocity_min = 1.0 * k
	pb.initial_velocity_max = 4.5 * k
	pb.gravity = Vector3(0, -11.0 * k, 0)
	pb.scale_min = 0.4 * k
	pb.scale_max = 1.3 * k
	pb.color_ramp = FxUtil.gradient(GOTAS)
	pb.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pb.emission_box_extents = Vector3(p.largura * 0.45, 0.15 * k, 0.2 * k)
	var borrifo := FxUtil.particles(int(70.0 * k), 0.7, false, pb, FxUtil.grain(0.26 * k))
	borrifo.position = Vector3(0, 0.15, p.espessura * 0.5)
	raiz.add_child(borrifo)

	return raiz

# O estouro do NASCIMENTO: a água arrebentando do chão à frente do jogador. Vale
# como antecipação — o olho vê de onde a onda saiu antes de ela andar.
static func _erupcao(world: Node, pos: Vector3, rumo: Vector3, largura: float = ONDA_LARGURA) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(rumo.x * 0.4, 1.0, rumo.z * 0.4)
	pm.spread = 45.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -14.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 2.0
	pm.color_ramp = FxUtil.gradient(GOTAS)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(largura * 0.45, 0.1, 0.3)
	var jato := FxUtil.particles(120, 0.8, true, pm, FxUtil.grain(0.34), 0.85)
	world.add_child(jato)
	jato.global_position = pos
	FxUtil.autofree(jato, 1.4)

	# Anel de choque rente ao chão: marca o ponto de onde a onda partiu.
	var anel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.25
	anel.mesh = tm
	var mat := _mat_luz(Color(ESPUMA.r, ESPUMA.g, ESPUMA.b, 0.7))
	anel.material_override = mat
	world.add_child(anel)
	anel.global_position = pos + Vector3.UP * 0.08
	anel.scale = Vector3(0.4, 0.3, 0.4)
	var tw := anel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anel, "scale", Vector3(3.2, 0.1, 3.2), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(anel.queue_free)

# ============================================================================
#  X — SAMEHADA SHOTEI: O ESGUICHO, INTACTO
# ============================================================================
#
#  ⚠️ NÃO MEXER. O dono pediu "manter como está" para o X. Isto é uma cópia
#  LITERAL do corpo que o `FightingStyles._cast_water` tinha antes desta tarefa
#  — mesmos 260 grãos, mesmo spread de 35°, mesma rampa, mesma velocidade de 25
#  m/s, mesma vida de 1,2 s, mesmo raio de 1,2. Só mudou de endereço.
#
#  Ele também é o CAMINHO SEGURO de qualquer variante desconhecida (ver
#  `FightingStyles._cast_water`): estilo sem tratamento próprio continua caindo
#  aqui, exatamente como caía antes.
static func esguicho(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	if not _mundo_vivo(world):
		return
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 35.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.scale_min = 0.6
	pm.scale_max = 2.0
	pm.color_ramp = FxUtil.gradient([Color(0.2, 0.7, 1.0, 0.9), Color(0.05, 0.4, 0.9, 0.7), Color(1, 1, 1, 0)])

	var water := FxUtil.particles(260, 0.7, true, pm, FxUtil.grain(0.5))
	zone.add_child(water)

	zone.setup(damage, 14.0, fwd * 25.0, 1.2, caster, 1.2)

# ============================================================================
#  OFICINA
# ============================================================================

# Ponta do antebraço direito, em mundo — o ponto de onde TODO disparo do projeto
# sai. Cópia do `GoroFXGrande._ponto_do_braco`; o `ForeArm_R` é um dos 13 papéis
# canônicos do rig.
#
# 📌 DÍVIDA COM GATILHO: esta é a SEGUNDA cópia deste lookup no projeto. Ainda
# não vale abstrair — duas cópias de 6 linhas custam menos que um acoplamento
# novo entre efeitos. GATILHO: quando um TERCEIRO efeito precisar do ponto do
# braço, sobe para o `FxUtil` (que já é a casa comum de VFX) e as três passam a
# chamá-lo.
static func _ponto_da_mao(caster: Node, fallback: Vector3) -> Vector3:
	if caster == null or not is_instance_valid(caster):
		return fallback
	var modelo = caster.get("_char_model")
	if modelo is Node3D and is_instance_valid(modelo):
		var braco := (modelo as Node3D).find_child("ForeArm_R", true, false)
		if braco is Node3D and (braco as Node3D).is_inside_tree():
			return (braco as Node3D).global_position
	if caster is Node3D:
		return (caster as Node3D).global_position + Vector3(0, 1.05, 0)
	return fallback

# Y do CHÃO sob o conjurador. Prefere o corpo (que sabe onde tem pé); o `origin`
# é o plano B porque ele vem de `Player.mira_do_cast`, que soma exatamente
# `UP * 1.0` ao centro do corpo.
static func _altura_do_chao(caster: Node, origin: Vector3) -> float:
	if caster is Node3D and is_instance_valid(caster):
		return (caster as Node3D).global_position.y - ALTURA_DOS_PES
	return origin.y - 1.0

# Um timer disparando com a cena já derrubada (troca de mapa, fim de partida) era
# o jeito mais fácil de esta rajada virar erro no console. Um guarda só, usado em
# todas as entradas.
static func _mundo_vivo(world: Node) -> bool:
	return world != null and is_instance_valid(world) and world.is_inside_tree()

# Água com CORPO: translúcida, lisa (roughness baixa = reflexo de líquido) e com
# um pouco de emissão para não apagar em cena escura. `vertex_color_use_as_albedo`
# fica DESLIGADO de propósito — aqui a cor é do material, não da partícula.
static func _mat_agua(cor: Color, alfa: float, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.15
	m.disable_receive_shadows = true
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = Color(cor.r, cor.g, cor.b).lerp(AGUA_FUNDA, 0.25)
		m.emission_energy_multiplier = energia
	return m

# Luz pura (núcleo da bala, riscos, anéis): sem sombra, sem iluminação, aditivo.
static func _mat_luz(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	m.emission_enabled = true
	m.emission = Color(cor.r, cor.g, cor.b)
	m.emission_energy_multiplier = 2.4
	return m
