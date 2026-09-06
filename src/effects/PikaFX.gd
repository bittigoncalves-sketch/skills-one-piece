class_name PikaFX
extends RefCounted
const PikaFXGrande = preload("res://src/effects/PikaFXGrande.gd")
# ============================================================================
#  PIKA PIKA NO MI — a fruta da LUZ.
#
#  Z — YASAKANI NO MAGATAMA: a salva de projéteis de luz. Sete raios saem da
#  mão em leque, cada um deixando um rastro reto atrás da cabeça.
#
#  ------------------------------------------------- DE ONDE VIERAM OS NÚMEROS
#  Da análise multimodal da gravação `VIdeo para Skill Z.mp4` (sessão
#  `multimodal/sessions/20260904-084346-pika_pika_z_yasakani/`), que é o **laser
#  do estilo Pacifista** rodando no próprio jogo. O que foi MEDIDO por ffmpeg:
#
#    1,83 s  o jogador para de correr e se firma      (ANTICIPATION)
#    1,90 s  clarão omnidirecional no tronco/mãos     (RELEASE)
#    2,02 s  braço ergue ~45°, energia junta na mão   (CHARGE)
#    3,02 s  o feixe sai                              (~1,0 s de carga)
#    3,57 s  impacto                                  (~0,55 s depois)
#
#  ------------------------------------- ⚠️ POR QUE A CARGA AQUI É 0,22 s, E NÃO 1,0 s
#  A referência mede 1,0 s de carga — e essa carga **não transfere**. Ela é de um
#  feixe SUSTENTADO (o `LaserPX` do Pacifista, que vive 3 s enquanto o Z fica
#  segurado); carga longa ali paga por si mesma, porque o golpe dura. O Yasakani
#  é SALVA: sai e acaba. Um Z de cooldown 5 s com 1,0 s de espera na frente
#  reprovaria no critério de responsividade da rubrica de qualidade, e brigaria
#  com o padrão "nota 10" da casa (a Gomu Pistol: wind-up curto → disparo rápido
#  → impacto → recovery).
#
#  Então a decisão, declarada: TIMING DA REFERÊNCIA é `REFERENCE_EVIDENCE`, mas
#  perde para `PROJECT_REQUIREMENT` (responsividade + frame data). O que a
#  referência DECIDE aqui é a ordem das fases e a leitura visual — não a duração.
#
#  --------------------------------------------------------- O QUE FOI REUTILIZADO
#  `BeamVisual3D` (src/combat/beam_visual_3d.gd) desenha cada rastro. Ele já
#  resolve orientação, comprimento, ponto médio e o caso vertical — e usa
#  `FxUtil.mesh_emissive_material`, que é `BILLBOARD_DISABLED`. Isso NÃO é
#  detalhe: o laser do Pacifista saía vertical porque o material antigo era
#  `BILLBOARD_PARTICLES` e a GPU girava o cilindro para encarar a câmera DEPOIS
#  da conta da CPU — teste de vetor passava e a tela continuava errada
#  (docs/ESTILO_PACIFISTA.md). Reusar o helper é o que impede o bug de voltar.
#
#  A estrutura "cabeça que voa + rastro ancorado" é a do `GoroFX._sango`.
#
#  ----------------------------------------------------------------- FRONTEIRA
#  Este arquivo é NOVO e não toca no estilo Pacifista. `laser_px.gd`,
#  `beam_visual_3d.gd` e `px_tri_beam.gd` são trabalho não commitado do dono e
#  entram aqui apenas como LEITURA.
# ============================================================================

# Branco levemente dourado no núcleo, âmbar no halo: é o que separa a luz da
# Pika do amarelo-PX do Pacifista sem sair da paleta cel-shading do jogo.
const COR_NUCLEO := Color(1.0, 0.98, 0.86, 1.0)
const COR_HALO := Color(1.0, 0.86, 0.38, 0.95)

const FEIXES := 7                # a "salva" do Yasakani
const CARGA := 0.22              # ver o bloco de decisão acima
const INTERVALO := 0.055         # entre um raio e o seguinte — 0,33 s de salva
const VELOCIDADE := 78.0         # m/s da cabeça
const ALCANCE := 40.0
# Era 0,42 com núcleo visível a 0,85x — 0,71 m de diâmetro POR RAIO. Sete deles
# nascendo juntos na mão viravam um borrão branco que cobria a cabeça do
# personagem de 0,50 s a 0,70 s (medido na captura, /tmp/mm_denso). O que lê como
# raio de luz é um ponto brilhante puxando um rastro, não uma bola.
const RAIO_HITBOX := 0.32
const ESPALHAMENTO := 0.17       # radianos (~9,7°). Era 0,10 e os sete raios
                                 # liam como dois ou três: de perto, 5,7° não
                                 # separa nada. Medido na primeira captura.
const VIDA_RASTRO := 0.16        # quanto o rastro sobrevive à cabeça
const ALTURA_MAO := 1.25         # de onde a luz sai, relativo ao pé do caster

# ------------------------------------------------------- X: YATA NO KAGAMI
#  ⚠️ TODOS OS NÚMEROS ABAIXO SÃO ESCOLHA MINHA, NÃO LEITURA DA REFERÊNCIA.
#  A spec do dono (2026-09-04) fixou o COMPORTAMENTO — esquerda, direita,
#  esquerda; avanço para frente em cada perna; mergulho de luz sobre inimigo
#  próximo com explosão — e deixou amplitude, avanço, duração, raio de detecção
#  e dano em aberto. Ele mandou seguir e ajustar depois. Então estes valores são
#  ponto de partida para o dono girar, e estão todos juntos aqui de propósito.
const PERNAS := 3                # esquerda → direita → esquerda. Três segmentos,
                                 # como na cena do anime (direcionamento X skill.webp).
const DUR_PERNA := 0.17          # 0,51 s de viagem inteira: rápido, como luz
const LATERAL := 5.0             # m de desvio lateral por perna
const AVANCO := 7.0              # m para frente por perna → 21 m no total
const RAIO_DETECCAO := 6.0       # o que conta como "inimigo próximo" nos ciclos
const ALTURA_MERGULHO := 6.0     # de que altura a luz cai sobre o alvo
const DUR_MERGULHO := 0.18
const RAIO_EXPLOSAO := 4.5


static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int,
		damage: float, caster: Node, spec: DamageSpec = null,
		cast_token: int = 0) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _yasakani(world, origin, dir, damage, caster, spec)
		1: _yata(world, origin, dir, damage, caster, spec)
		2: PikaFXGrande.yasakani(world, origin, dir, damage, caster, spec, cast_token)
		3: PikaFXGrande.chuva_de_luz(world, origin, damage, caster, spec)


# ---------------------------------------------------------------- Z: YASAKANI
#
#  ⚠️ O `world` PODE NÃO ESTAR NA ÁRVORE NO PRIMEIRO GOLPE.
#  `Player._get_skills_container()` cria o contêiner e o pendura com
#  `add_child.call_deferred(...)` (Player.gd:3641) — ou seja, devolve o nó um
#  quadro ANTES de ele entrar na cena. Tudo que se pendura nele nesse intervalo
#  fica fora da árvore junto, e aí `global_position`, `get_tree()` e
#  `create_tween()` falham todos de uma vez:
#
#      ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
#      ERROR: Parameter "data.tree" is null.
#
#  Só acontece no PRIMEIRO cast de uma fruta, que é justamente o que nenhum
#  teste de unidade pega — a árvore nua do `test_pika_yasakani` já estava
#  montada. Quem pegou foi o `test_frutas`, subindo o jogo de verdade.
#  Esperar um quadro resolve, porque o `call_deferred` corre no fim deste.
static func _yasakani(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, spec: DamageSpec, tentativa: int = 0) -> void:
	if not world.is_inside_tree():
		# Uma tentativa só: se depois de um quadro o contêiner ainda não entrou,
		# o problema é outro e insistir viraria laço infinito.
		var arvore := Engine.get_main_loop() as SceneTree
		if tentativa == 0 and arvore != null:
			arvore.process_frame.connect(
				_yasakani.bind(world, origin, dir, damage, caster, spec, 1),
				CONNECT_ONE_SHOT)
		return

	var fwd: Vector3 = dir.normalized()
	if fwd.length_squared() < 0.01:
		fwd = Vector3(0, 0, -1)

	var salva := Node3D.new()
	world.add_child(salva)
	salva.global_position = origin
	FxUtil.autofree(salva, CARGA + FEIXES * INTERVALO + VIDA_RASTRO + 0.5)

	_carga(salva, world, origin)

	# A salva inteira é agendada de uma vez. Timer por raio, e não um
	# `_process` com contador, porque não há estado entre os raios: cada um nasce
	# independente e some sozinho.
	for i in FEIXES:
		var atraso := CARGA + i * INTERVALO
		var t := salva.get_tree().create_timer(atraso)
		t.timeout.connect(_disparar_um.bind(world, caster, fwd, damage, spec, i))


# A luz que junta na mão antes da salva. É o que dá a leitura em UM quadro
# (critério 1 da rubrica): pausando aqui, dá para dizer que golpe vem.
static func _carga(pai: Node3D, world: Node, origin: Vector3) -> void:
	# ⚠️ POSIÇÃO ZERO, NÃO `ALTURA_MAO`. O `origin` que chega do `_fire_skill` já
	# vem na altura do peito, e o `salva` já está nele — somar ALTURA_MAO de novo
	# jogava a carga para ~2,25 m, ACIMA DA CABEÇA. Só apareceu na captura: o
	# teste de unidade não olha para onde a luz fica.
	var nucleo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	nucleo.mesh = sm
	nucleo.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 11.0, true)
	pai.add_child(nucleo)
	nucleo.position = Vector3.ZERO

	var halo := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.16
	sm2.height = 0.32
	halo.mesh = sm2
	var mat_halo := FxUtil.mesh_emissive_material(COR_HALO, 4.0, true)
	mat_halo.albedo_color.a = 0.30
	halo.material_override = mat_halo
	pai.add_child(halo)
	halo.position = Vector3.ZERO

	# Cresce e estoura: o estouro é o quadro em que a salva começa.
	# Escala menor que a primeira versão: com 2,6x/3,4x a bola de carga ficava do
	# tamanho do tronco e roubava a leitura do golpe.
	var tw := nucleo.create_tween().set_parallel()
	tw.tween_property(nucleo, "scale", Vector3(2.0, 2.0, 2.0), CARGA)
	tw.tween_property(halo, "scale", Vector3(2.2, 2.2, 2.2), CARGA)
	FxUtil.autofree(nucleo, CARGA + 0.05)
	FxUtil.autofree(halo, CARGA + 0.05)

	PikaAudio.play(world, origin, "carga")


static func _disparar_um(world: Node, caster: Node, fwd: Vector3, damage: float,
		spec: DamageSpec, indice: int) -> void:
	if not is_instance_valid(world):
		return

	var origem: Vector3 = fwd * 0.0
	if is_instance_valid(caster) and caster is Node3D:
		origem = (caster as Node3D).global_position + Vector3(0, ALTURA_MAO, 0)
	var dir := _direcao_do_leque(fwd, indice)

	# ⚠️ SERVIDOR-AUTORIDADE. O rastro e o clarão rodam em todo cliente; quem
	# machuca é só o servidor. A `DamageZone` já é criada apenas aqui, mas a
	# regra fica escrita porque este arquivo vai ser copiado para o X/C/V.
	var cabeca := DamageZone.new()
	world.add_child(cabeca)
	cabeca.global_position = origem
	var por_hit: float = spec.valor_do_hit() if spec != null else damage
	cabeca.setup(por_hit, 9.0, dir * VELOCIDADE, ALCANCE / VELOCIDADE, caster,
		RAIO_HITBOX)
	if spec != null:
		spec.marcar(cabeca)

	# ⚠️ PESO. Sem isto o acerto passa e o jogo não reage — foi o critério que
	# mais derrubou a nota na avaliação (4/10). O rig da câmera é DONO do tremor
	# e do soco de FOV; quem quer PEDE (`pedir_shake`, `pedir_fov_punch`,
	# camera_rig.gd:24). O hitstop já existe pronto no animador.
	# Um disparo só por salva: sete hitstops seguidos travariam o jogo.
	#
	# ⚠️ `hit_landed`, NÃO `body_entered` (2026-09-06). O sinal `body_entered` é
	# da `Area3D` e só nasce quando a FÍSICA vê a sobreposição naquele quadro.
	# A 78 m/s o passo é 1,30 m e quem detecta quase sempre é a varredura da
	# `DamageZone`, que chama `_on_body()` direto e não emite `body_entered`
	# nenhum. Resultado: o peso do acerto — o item que tirou 4/10 — dependia de
	# o alvo cair na fatia certa do quadro. `hit_landed` sai nos DOIS caminhos.
	cabeca.hit_landed.connect(_ao_acertar.bind(caster), CONNECT_ONE_SHOT)

	# ⚠️ O RAIO NÃO PARAVA NO QUE ACERTAVA. A cabeça seguia viagem até vencer o
	# alcance, e o `_Rastro` só desenha o clarão quando ela morre — então o
	# impacto do Yasakani aparecia 40 m adiante do corpo que ele atravessou, e
	# atravessava parede no caminho. O fragmento do C já parava assim desde
	# sempre (`_parar_projetil`); o Z é que estava sozinho.
	cabeca.collided_with_any.connect(_parar_cabeca.bind(cabeca), CONNECT_ONE_SHOT)

	# Núcleo visível DENTRO da hitbox: o que o jogador vê é onde o dano está
	# (critério 8 — hitbox condiz com o visual).
	# ⚠️ Era 0,55 do raio, e a auditoria mediu a hitbox valendo ~1,8x o que se
	# via. Passou a 0,78 agora que a varredura por esfera faz o raio de 0,32
	# valer no percurso inteiro: a hitbox virou verdade, então o desenho tem de
	# acompanhar. Fica em 0,50 m de diâmetro — longe dos 0,71 m que na primeira
	# versão viraram borrão branco por cima da cabeça do personagem.
	var nucleo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RAIO_HITBOX * 0.78
	sm.height = RAIO_HITBOX * 1.56
	nucleo.mesh = sm
	nucleo.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 12.0, true)
	cabeca.add_child(nucleo)

	# O rastro: um feixe reto da mão até a cabeça, redesenhado por quadro pelo
	# `_Rastro`. É aqui que o `BeamVisual3D` do Pacifista é reaproveitado.
	var rastro := _Rastro.new()
	rastro.cabeca = cabeca
	rastro.caster = caster if caster is Node3D else null
	rastro.origem_fixa = origem
	world.add_child(rastro)

	# Cada raio soa um pouco mais agudo que o anterior: a salva SOBE, e é isso
	# que faz sete disparos lerem como uma frase e não como sete cliques.
	PikaAudio.play(world, origem, "disparo", 0.96 + indice * 0.035)


# Para a cabeça onde ela encostou, sem tirá-la da árvore: o `autofree` da
# própria `DamageZone` continua dono do ciclo de vida (remover cedo deixa a
# lambda do temporizador com captura morta — erro já pago neste projeto), e o
# `_Rastro` lê a marca para desenhar o clarão AQUI em vez de lá na frente.
static func _parar_cabeca(_corpo: Node, cabeca: Node) -> void:
	if not is_instance_valid(cabeca):
		return
	cabeca.set("vel", Vector3.ZERO)
	cabeca.set_meta("pika_encerrado", true)
	cabeca.set_deferred("monitoring", false)


# ------------------------------------------------------- X: YATA NO KAGAMI
#  O jogador VIRA LUZ e viaja em ziguezague. Não é um feixe — foi a spec do dono
#  que corrigiu isso, contra o vídeo gerado por IA (que desenhou um raio
#  ricocheteando). Ver a specification.md da sessão `20260904-093047-pika_x`.
#
#  Precedente reusado: `GoroFX._shunshin` já move o caster
#  (`(caster as CharacterBody3D).global_position += fwd * 12.0`) dentro do
#  `_fire_skill`, que é presentation e roda em TODOS os peers — então mover o
#  corpo em todos mantém a sincronia sem replicar nada novo. A diferença é que
#  o Shunshin teleporta num quadro e este viaja ao longo do tempo, e viagem com
#  tempo precisa de um nó com `_process` — mesma razão pela qual o `LaserPX` é
#  um nó e não uma função.
static func _yata(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, spec: DamageSpec) -> void:
	if not (caster is Node3D):
		return
	if not world.is_inside_tree():
		var arvore := Engine.get_main_loop() as SceneTree
		if arvore != null:
			arvore.process_frame.connect(
				_yata.bind(world, origin, dir, damage, caster, spec),
				CONNECT_ONE_SHOT)
		return
	var v := _ViagemDeLuz.new()
	v.caster = caster as Node3D
	v.fwd = dir.normalized() if dir.length_squared() > 0.01 else Vector3(0, 0, -1)
	v.dano = damage
	v.spec = spec
	world.add_child(v)


# O que acontece quando um raio ACERTA alguém. Só o primeiro da salva dá peso:
# sete hitstops em 0,33 s viraria travamento, não impacto.
static func _ao_acertar(corpo: Node, caster: Node) -> void:
	if not is_instance_valid(corpo) or not is_instance_valid(caster):
		return
	if corpo == caster:
		return
	# Chão e bloco não valem peso — só corpo que sente.
	if not (corpo.is_in_group("player") or corpo.is_in_group("enemy")):
		return
	if caster.get_meta("pika_peso_dado", false):
		return
	caster.set_meta("pika_peso_dado", true)
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore != null:
		arvore.create_timer(0.6).timeout.connect(
			func(): if is_instance_valid(caster): caster.set_meta("pika_peso_dado", false))

	# ⚠️ `_proc_anim`, NÃO `_animator`. São dois animadores diferentes no Player:
	# `_animator` é `CharacterAnimator` e NÃO tem `trigger_hitstop`; quem tem é
	# `_proc_anim: ProceduralAnimator` (Player.gd:509). Escrevi errado primeiro,
	# o teste passou porque o meu dublê tinha a interface errada, e só o jogo de
	# verdade acusou: "Nonexistent function 'trigger_hitstop' in base
	# 'Node (CharacterAnimator)'". O `has_method` abaixo é para tipo trocado
	# degradar em silêncio em vez de derrubar o golpe.
	_pedir_peso(caster, 0.09, 0.05, 0.22, 2.5)


# Peso do acerto num lugar só: hitstop no animador procedural, tremor e soco de
# FOV no rig da câmera — que é DONO dos dois e atende por pedido
# (camera_rig.gd:24). Nada aqui é obrigatório: se o caster não tiver a peça, o
# golpe continua, só sem o tempero.
static func _pedir_peso(caster: Node, hitstop: float, tremor_anim: float,
		shake: float, fov: float) -> void:
	if not is_instance_valid(caster):
		return
	var anim = caster.get("_proc_anim")
	if anim != null and anim.has_method("trigger_hitstop"):
		anim.trigger_hitstop(hitstop, tremor_anim)
	var cam = caster.get("_camera")
	if cam != null and cam.has_method("pedir_shake"):
		cam.pedir_shake(shake)
		if cam.has_method("pedir_fov_punch"):
			cam.pedir_fov_punch(fov)


# O clarão onde o raio morre. NÃO existia na primeira versão: os sete raios
# voavam e sumiam no nada, e a captura mostrou um golpe que "acaba sem acabar" —
# reprovaria no critério de feedback de impacto da rubrica. A referência resolve
# isso com uma explosão; aqui é um clarão curto, porque a salva tem sete e sete
# explosões viram sopa.
static func _impacto(world: Node, pos: Vector3) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree():
		return
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	flash.mesh = sm
	flash.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 14.0, true)
	world.add_child(flash)
	flash.global_position = pos
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3(3.2, 3.2, 3.2), 0.14)
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.14)
	FxUtil.autofree(flash, 0.20)

	# Camadas, para o clarão não ser um blob aditivo só: um anel que abre no
	# plano do impacto e fagulhas saindo dele. Ambos os helpers já existem no
	# `GoroFX` e são estáticos — reusar é mais barato e mais consistente do que
	# reinventar partícula nova.
	var palco := Node3D.new()
	world.add_child(palco)
	palco.global_position = pos
	GoroFX.shock_ring(palco, Vector3.ZERO, COR_HALO, 1.6, 0.22, 0.18)
	palco.add_child(GoroFX.sparks(28, 0.30, Vector3.UP, 90.0, 3.0, 8.0, 0.10))
	FxUtil.autofree(palco, 0.55)

	PikaAudio.play(world, pos, "impacto", 1.0 + randf_range(-0.06, 0.06))


# Leque determinístico: ângulo fixo por índice, não aleatório. Salva que muda de
# forma a cada conjuração é salva que o adversário não aprende a ler — e golpe
# ilegível reprova no critério de leitura.
static func _direcao_do_leque(fwd: Vector3, indice: int) -> Vector3:
	var meio := (FEIXES - 1) * 0.5
	var passo := (indice - meio) / maxf(meio, 1.0)          # -1 .. +1
	var lado := fwd.cross(Vector3.UP).normalized()
	if lado.length_squared() < 0.01:
		lado = Vector3.RIGHT
	var cima := lado.cross(fwd).normalized()
	# Horizontal abre em leque; vertical faz um leve arco, para a salva não ser
	# uma linha reta de sete pontos.
	var h := passo * ESPALHAMENTO
	var v := (1.0 - absf(passo)) * ESPALHAMENTO * 0.35
	return (fwd + lado * h + cima * v).normalized()


# ---------------------------------------------------------------- o rastro
# Nó próprio porque o feixe precisa de um quadro para se redesenhar enquanto a
# cabeça se afasta. Mesmo motivo pelo qual o `LaserPX` é um nó e não uma função.
class _Rastro extends Node3D:
	var cabeca: Node3D = null
	var caster: Node3D = null
	var origem_fixa := Vector3.ZERO
	var _feixe: MeshInstance3D = null
	var _morrendo := 0.0
	var _ultima_pos := Vector3.ZERO
	var _impacto_feito := false

	func _ready() -> void:
		# Nome fixo: classe interna não tem `class_name`, então o nó nasce como
		# "@Node3D@N" e some de qualquer varredura por tipo — inclusive da do
		# teste, que por isso contava zero rastro num golpe que tinha sete.
		name = "PikaRastro"
		_feixe = BeamVisual3D.criar(self, _origem(), _origem(), 0.055,
			PikaFX.COR_HALO, 7.0, true)

	func _process(delta: float) -> void:
		if _feixe == null:
			return
		# `pika_encerrado` = a cabeça encostou em algo e parou. Sem ler essa
		# marca o rastro continuaria acompanhando um projétil imóvel e só
		# desenharia o clarão meio segundo depois, quando o `autofree` o
		# removesse — que era o bug do impacto aparecer no lugar errado.
		if is_instance_valid(cabeca) and not bool(cabeca.get_meta("pika_encerrado", false)):
			_ultima_pos = cabeca.global_position
			BeamVisual3D.atualizar(_feixe, _origem(), _ultima_pos)
			return
		if is_instance_valid(cabeca):
			_ultima_pos = cabeca.global_position
			cabeca = null
		# A cabeça morreu (bateu ou venceu o alcance): clarão de impacto uma vez
		# só, e o rastro apaga sozinho.
		if not _impacto_feito:
			_impacto_feito = true
			PikaFX._impacto(get_parent(), _ultima_pos)
		_morrendo += delta
		var t := clampf(_morrendo / PikaFX.VIDA_RASTRO, 0.0, 1.0)
		var mat := _feixe.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = (1.0 - t) * PikaFX.COR_HALO.a
		if t >= 1.0:
			queue_free()

	# A mão continua sendo a origem mesmo se o jogador girar: seguir o caster é
	# de graça e evita o rastro descolar do corpo.
	func _origem() -> Vector3:
		if is_instance_valid(caster):
			return caster.global_position + Vector3(0, PikaFX.ALTURA_MAO, 0)
		return origem_fixa


# ------------------------------------------------------ o nó da viagem de luz
#  Estados: PERNA (ziguezague) → MERGULHO (só se achou alvo) → morre.
#  O corpo do jogador é reposicionado por quadro; a `velocity` é zerada junto,
#  senão a gravidade e o `move_and_slide` do Player brigam com a viagem e o
#  ziguezague vira queda.
class _ViagemDeLuz extends Node3D:
	var caster: Node3D = null
	var fwd := Vector3.FORWARD
	var dano := 0.0
	var spec = null

	var _perna := 0
	var _t := 0.0
	var _de := Vector3.ZERO
	var _para := Vector3.ZERO
	var _lado := Vector3.RIGHT
	var _origem := Vector3.ZERO
	var _feixe: MeshInstance3D = null
	var _alvo: Node3D = null
	var _mergulhando := false
	var _acabou := false
	var _brilho: MeshInstance3D = null

	func _ready() -> void:
		name = "PikaViagemDeLuz"
		if not is_instance_valid(caster):
			queue_free()
			return
		_origem = caster.global_position
		_lado = fwd.cross(Vector3.UP).normalized()
		if _lado.length_squared() < 0.01:
			_lado = Vector3.RIGHT
		# Trava o movimento pelo tempo todo da viagem: sem isto o input do
		# jogador empurra o corpo no meio do ziguezague.
		var total := PikaFX.PERNAS * PikaFX.DUR_PERNA + PikaFX.DUR_MERGULHO + 0.05
		if caster.has_method("lock_movement"):
			caster.lock_movement(total, "pika_x")
		_brilho = _halo_no_corpo()
		_iniciar_perna()
		PikaAudio.play(get_parent(), _origem, "viagem")

	# O corpo vira luz: um halo aditivo grudado nele durante a viagem.
	func _halo_no_corpo() -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		# ⚠️ Era raio 0,55 × altura 2,2 com alpha 0,45 — MAIOR que o personagem e
		# aditivo, então de 0,22 s a 0,76 s da captura o jogador virava um blob
		# branco e sumia. Luz tem que envolver o corpo, não apagá-lo.
		var cap := CapsuleMesh.new()
		cap.radius = 0.36
		cap.height = 1.85
		mi.mesh = cap
		var mat := FxUtil.mesh_emissive_material(PikaFX.COR_NUCLEO, 3.2, true)
		mat.albedo_color.a = 0.22
		mi.material_override = mat
		caster.add_child(mi)
		mi.position = Vector3(0, 1.1, 0)
		return mi

	# ⚠️ A perna é CLAMPADA por raio. 21 m de viagem sem checar chão nem parede
	# põe o jogador dentro de um prédio ou por cima de um buraco — e neste mapa
	# cair no buraco MATA (Scoreboard.VOID_Y = -40). O `_shunshin`, que é o
	# precedente, teleporta 12 m sem checar nada; aqui a distância é o dobro.
	func _iniciar_perna() -> void:
		_de = caster.global_position
		var centro := _origem + fwd * PikaFX.AVANCO * float(_perna + 1)
		var sinal := -1.0 if _perna % 2 == 0 else 1.0   # esquerda, direita, esquerda
		_para = centro + _lado * (PikaFX.LATERAL * sinal)
		_para.y = _de.y
		_para = _clampar(_de, _para)
		_t = 0.0
		_feixe = BeamVisual3D.criar(self, _de, _de, 0.30, PikaFX.COR_HALO, 6.0, true)

	# ⚠️ SÓ CENÁRIO SEGURA O ZIGUEZAGUE. Antes daqui o raio saía com máscara
	# cheia e SEM excluir ninguém além do próprio caster — e neste projeto os
	# personagens vivem na mesma camada do mapa. Consequência: passar perto de
	# qualquer jogador travava a perna 1 m antes dele, e o X — que é a técnica
	# de ATRAVESSAR o campo virando luz — parava justamente quando encontrava
	# alguém, que é quando ele deveria seguir. Gente não é parede.
	func _corpos_a_ignorar() -> Array[RID]:
		var fora: Array[RID] = []
		if caster is CollisionObject3D:
			fora.append((caster as CollisionObject3D).get_rid())
		var arvore := get_tree()
		if arvore == null:
			return fora
		for grupo in ["player", "enemy"]:
			for n in arvore.get_nodes_in_group(grupo):
				if n is CollisionObject3D and is_instance_valid(n):
					fora.append((n as CollisionObject3D).get_rid())
		return fora

	func _clampar(de: Vector3, para: Vector3) -> Vector3:
		var espaco := get_world_3d().direct_space_state
		var ignorar := _corpos_a_ignorar()
		var par := PhysicsRayQueryParameters3D.create(de, para)
		par.exclude = ignorar
		var bateu := espaco.intersect_ray(par)
		var destino := para
		if not bateu.is_empty():
			# Para um metro antes da parede, para não encravar no colisor.
			var p: Vector3 = bateu["position"]
			destino = p - (para - de).normalized() * 1.0
		return _com_chao(espaco, de, destino, ignorar)

	# ⚠️ O X ERA UM BOTÃO DE SUICÍDIO SOBRE OS BURACOS. A perna viaja com
	# `_para.y = _de.y`, ou seja em altura fixa, e esta arena tem 16 buracos
	# quadrados em que CAIR MATA (`Scoreboard.VOID_Y = -40`). O clamp antigo só
	# olhava para frente, nunca para baixo: dava para atravessar 21 m em linha
	# reta e ser largado no ar exatamente por cima de um buraco.
	#
	# Agora o destino recua ao longo do próprio segmento até achar chão. Oito
	# amostras porque o passo fica em ~12% da perna — fino o bastante para não
	# desperdiçar metros bons, grosseiro o bastante para custar quase nada.
	#
	# ⚠️ SEM CHÃO EM LUGAR NENHUM = SEGUE VIAGEM, e isso é decisão, não desleixo.
	# A primeira versão devolvia `de` nesse caso e o X virava um no-op: quem
	# usasse a técnica no AR, ou num trecho de mapa sem colisor sob o segmento
	# inteiro, apertava a tecla e não saía do lugar. Quando nenhuma amostra acha
	# chão, a sonda não está dizendo "é perigoso" — está dizendo "não sei", e
	# travar o golpe por falta de informação é pior do que deixá-lo correr.
	# Só recua quando ACHOU chão em algum ponto e o destino não tinha.
	func _com_chao(espaco: PhysicsDirectSpaceState3D, de: Vector3, para: Vector3,
			ignorar: Array[RID]) -> Vector3:
		for i in 9:
			var k := 1.0 - float(i) / 8.0
			var ponto := de.lerp(para, k)
			if _tem_chao(espaco, ponto, ignorar):
				return ponto
		return para

	func _tem_chao(espaco: PhysicsDirectSpaceState3D, ponto: Vector3,
			ignorar: Array[RID]) -> bool:
		var par := PhysicsRayQueryParameters3D.create(
			ponto + Vector3.UP * 1.5, ponto - Vector3.UP * 5.0)
		par.collision_mask = 15
		par.collide_with_areas = false
		par.exclude = ignorar
		return not espaco.intersect_ray(par).is_empty()

	func _process(delta: float) -> void:
		if _acabou or not is_instance_valid(caster):
			return
		if _mergulhando:
			_passo_mergulho(delta)
			return
		_passo_perna(delta)

	func _passo_perna(delta: float) -> void:
		_t += delta
		var k := clampf(_t / PikaFX.DUR_PERNA, 0.0, 1.0)
		caster.global_position = _de.lerp(_para, k)
		if caster is CharacterBody3D:
			(caster as CharacterBody3D).velocity = Vector3.ZERO
		if _feixe != null:
			BeamVisual3D.atualizar(_feixe, _de, caster.global_position)
		_procurar_alvo()

		if k < 1.0:
			return
		# Fim da perna: o rastro fica e apaga sozinho; a próxima começa.
		if _feixe != null:
			FxUtil.autofree(_feixe, 0.28)
			_feixe = null
		# `add_child`, não `reparent`: `GoroFX.sparks` devolve um nó SEM PAI, e
		# reparent nele dá "Node needs a parent to be reparented" e ainda derruba
		# um `!is_inside_tree()` junto.
		var fagulhas := GoroFX.sparks(20, 0.25, fwd, 70.0, 3.0, 9.0, 0.10)
		add_child(fagulhas)
		fagulhas.global_position = caster.global_position
		FxUtil.autofree(fagulhas, 0.45)
		_perna += 1
		if _perna < PikaFX.PERNAS:
			_iniciar_perna()
		else:
			_terminar_ciclos()

	# "se houver um inimigo próximo DURANTE os ciclos" — a busca roda em toda
	# perna, não só no fim: passar raspando por alguém conta.
	func _procurar_alvo() -> void:
		if _alvo != null:
			return
		var arvore := get_tree()
		if arvore == null:
			return
		for grupo in ["enemy", "player"]:
			for n in arvore.get_nodes_in_group(grupo):
				if n == caster or not (n is Node3D) or not is_instance_valid(n):
					continue
				if caster.global_position.distance_to((n as Node3D).global_position) \
						<= PikaFX.RAIO_DETECCAO:
					_alvo = n as Node3D
					return

	func _terminar_ciclos() -> void:
		if _alvo != null and is_instance_valid(_alvo):
			_mergulhando = true
			_t = 0.0
			_de = _alvo.global_position + Vector3.UP * PikaFX.ALTURA_MERGULHO
			_para = _alvo.global_position
			caster.global_position = _de
			_feixe = BeamVisual3D.criar(self, _de, _de, 0.34, PikaFX.COR_NUCLEO, 9.0, true)
			return
		_encerrar()

	func _passo_mergulho(delta: float) -> void:
		_t += delta
		var k := clampf(_t / PikaFX.DUR_MERGULHO, 0.0, 1.0)
		caster.global_position = _de.lerp(_para, k)
		if caster is CharacterBody3D:
			(caster as CharacterBody3D).velocity = Vector3.ZERO
		if _feixe != null:
			BeamVisual3D.atualizar(_feixe, _de, caster.global_position)
		if k >= 1.0:
			_explodir(caster.global_position)
			_encerrar()

	func _explodir(pos: Vector3) -> void:
		var mundo := get_parent()
		if mundo == null:
			return
		var zona := DamageZone.new()
		mundo.add_child(zona)
		zona.global_position = pos + Vector3.UP * 0.2
		var d: float = spec.valor_do_hit() if spec != null else dano
		zona.setup(d, 26.0, Vector3.UP * 18.0, 0.28, caster, PikaFX.RAIO_EXPLOSAO)
		# ⚠️ 4,5 m de esfera ATRAVESSAVAM PAREDE. A sobreposição de uma esfera
		# não sabe o que é cobertura, e quem estivesse do outro lado de um muro
		# a 4 m do mergulho levava a explosão inteira. A `DamageZone` já tinha a
		# solução pronta desde o Tri-Beam e ninguém tinha ligado aqui.
		zona.exige_linha_de_visao = true
		zona.origem_linha_de_visao = pos + Vector3.UP * 0.2
		if spec != null:
			spec.marcar(zona, true)
		# O anel desenhado passa a ter o MESMO raio da explosão. Anel menor que
		# a hitbox promete um perigo menor do que existe, e o jogador aprende a
		# distância errada.
		GoroFX.shock_ring(zona, Vector3.ZERO, PikaFX.COR_HALO, PikaFX.RAIO_EXPLOSAO, 0.30, 0.30)
		zona.add_child(GoroFX.sparks(60, 0.45, Vector3.UP, 85.0, 5.0, 14.0, 0.16))
		PikaFX._impacto(mundo, pos)
		PikaAudio.play(mundo, pos, "explosao")
		PikaFX._pedir_peso(caster, 0.11, 0.06, 0.45, 5.0)

	func _encerrar() -> void:
		_acabou = true
		if is_instance_valid(_brilho):
			_brilho.queue_free()
		FxUtil.autofree(self, 0.40)
