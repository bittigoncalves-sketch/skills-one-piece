class_name GuraVNode
extends Node3D
# ============================================================================
#  GURA GURA — V: "SEAQUAKE" (ultimate). REESCRITO DO ZERO em 2026-08-14.
#
#  O PEDIDO DO DONO, palavra por palavra:
#    "o personagem entra em pose de T socando o ar e rachaduras brancas como o
#     quebrar de uma tela aparecem a partir das mãos do jogador, e dos dois
#     lados do mapa são spawnados tsunamis gigantes que quando colidirem
#     encerram o ataque"
#
#  Quatro TEMPOS, e cada um tem um dono neste arquivo:
#    1. POSE DE T SOCANDO O AR ....... `_armar()` + `_socar()`
#    2. RACHADURAS SAINDO DAS MÃOS ... `_rachar_o_ar()`
#    3. TSUNAMIS NAS DUAS BORDAS ..... `_lancar_tsunamis()`
#    4. ELES SE ENCONTRAM E ACABA .... `_process()` -> `_encontro()`
#
#  ---------------------------------------------------------------------------
#  POR QUE O ARQUIVO ANTIGO FOI JOGADO FORA (e não remendado)
#  ---------------------------------------------------------------------------
#  Ele tinha quatro defeitos que se somavam para o golpe "não fazer nada":
#
#   • OS EFEITOS DO CLÍMAX NASCIAM NA ORIGEM DO MAPA. `GuraFX._ring/_bubble/
#     _debris` recebem um `parent` e NUNCA definem posição — ficam em (0,0,0)
#     LOCAL. O antigo passava `world` como pai, então a bolha, os 200 detritos e
#     os 3 anéis apareciam no centro do mapa, não no jogador. Aqui esses
#     efeitos SEMPRE recebem um nó-âncora já posicionado (`_ancora()`); é a
#     correção sem tocar no `GuraFX`, que é compartilhado com Z/X/C.
#   • `explosiveness = 2.5` — a propriedade do Godot é 0..1 e é grampeada.
#   • `pm.direction = Vector3.UP` nas partículas do tsunami: subiam em vez de
#     avançar.
#   • A `DamageZone` vivia 0,8 s a 33,5 m/s: sumia antes de o olho registrar.
#
#  E, no fundo, o antigo não tinha TSUNAMI nenhum — tinha duas nuvens de
#  partículas. Aqui a onda é a MESMA CRISTA do Karatê Tritão (lamelas de caixa
#  + lábio de espuma), em escala de ultimate, via `WaterFX.crista_de_onda`.
#
#  ---------------------------------------------------------------------------
#  DECISÕES DE PROJETO (as seis perguntas: benefício, futuro, manutenção,
#  extensão, custo, risco — o resumo está no relatório da tarefa)
#  ---------------------------------------------------------------------------
#  ▸ EIXO: o jogador escolhe, mas o jogo ARREDONDA para o eixo cardeal mais
#    próximo da mira. Benefício imediato: a ultimate responde a para onde o
#    jogador está olhando, em vez de ser sempre a mesma. Por que arredondar:
#    o mapa é um QUADRADO de 200 m; uma onda na diagonal nasceria numa quina,
#    teria 283 m de caminho e cortaria só metade da arena. No eixo, ela nasce
#    numa borda inteira e faz o caminho mínimo. Custo: quatro linhas.
#
#  ▸ VELOCIDADE: 40 m/s, 100 m até o centro = 2,5 s de travessia. O dono avisou
#    que prender o jogador 8 s é problema, não espetáculo — e a resposta aqui é
#    dupla: a travessia é curta E o jogador só fica TRAVADO durante o soco
#    (0,90 s). Depois disso ele anda, corre e desvia enquanto as ondas fecham.
#    Nada obriga um espectador a virar estátua.
#
#  ▸ BURACOS: as ondas PASSAM POR CIMA. Elas são paredes de água de 24 m; fazer
#    a crista afundar nos 16 buracos exigiria geometria por célula e uma hitbox
#    que acompanhasse — semanas de trabalho para 2,5 s de tela, e o resultado
#    ("a onda some e volta") lê pior do que a água atravessando o vão.
#    📌 GATILHO para revisitar: se os buracos ganharem parede/fundo visíveis,
#    a onda passando reta vira erro de leitura e o assunto volta.
#
#  ▸ QUEM ESTÁ NO CAMINHO: leva o dano do V — 384 por onda, de
#    `src/combat/Balance.gd` — e knockback FORTE na direção da onda com forte
#    viés para CIMA. A Gura Gura é a fruta do arremesso, e ser lançado por um
#    tsunami e apanhado pelo outro no ar é a coreografia que o golpe promete.
#    Cada onda acerta cada corpo UMA vez (`DamageZone._hit`), então o teto são
#    dois golpes — e ele bate com o teto do ORÇAMENTO da conjuração (768 = 2 x
#    384). As duas contas coincidirem é o sinal de que a skill está declarada
#    certo na tabela.
# ============================================================================

# ---- tempo (s a partir do disparo) ----
const T_SOCO := 0.45          # entra a pose de T (que ABRE pelo recuo do soco)
# O PUNHO CHEGA aqui, não em `T_SOCO`. A pose de T começa recuando os braços
# (primeiro tempo do soco) e só estala para fora em `GuraPoses.V_GOLPE_ATE`.
# As rachaduras nascem NESTE instante — antes disso elas apareceriam com os
# braços ainda voltando, que é o efeito chegando antes da causa.
const T_IMPACTO := T_SOCO + GuraPoses.V_GOLPE_ATE
const T_TSUNAMI := 0.90       # as ondas nascem; o jogador recupera o controle
const TETO_TRAVESSIA := 6.0   # rede de segurança: nunca viver além disto

# ---- geometria dos tsunamis ----
const BORDA := MapBuilder.PLATFORM_SIZE * 0.5    # 100 m: a borda da plataforma
const CHAO := 0.0                                # topo da plataforma (MapBuilder)
const VEL := 40.0                                # m/s -> 100 m em 2,50 s
const LARGURA := 200.0                           # a frente cobre a borda inteira
const ALTURA := 24.0                             # crista "gigante" de 24 m
const ESPESSURA := 7.0                           # parede de água funda
const LAMELAS := 40                              # 5 m por lamela (silhueta)
const KB := 60.0                                 # knockback de ultimate
const HITBOX_FUNDO := 12.0                       # m de profundidade da caixa de dano
const FOLGA_ENCONTRO := 8.0                      # m entre as frentes = "colidiram"

var _caster: Node
var _damage: float
var _t := 0.0
var _fase := 0                # 0 armar, 1 recuo do soco, 2 impacto, 3 travessia, 4 acabou
var _eixo := Vector3.RIGHT    # eixo em que as ondas viajam (cardeal)
var _ondas: Array[DamageZone] = []

var _spec: DamageSpec = null

func _init(c: Node, d: float, spec: DamageSpec = null) -> void:
	_caster = c
	_damage = d
	_spec = spec if spec != null else DamageSpec.avulso(d)
	name = "GuraVNode"

func _ready() -> void:
	_armar()

# ============================================================================
#  TEMPO 1 — A POSE DE T SOCANDO O AR
# ============================================================================
#
#  ⚠️ REESCRITO EM 2026-08-15. Até aqui NENHUMA pose nova tinha sido escrita: o
#  `ProceduralAnimator` estava a 9 linhas do teto de 900, e o "soco" era um SALTO
#  de um quadro de `gura_v_lift` (ombros em z=±0,8) para `gura_v_tpose` (z=±1,4),
#  contando com o filtro de rigidez para borrar a troca.
#
#  Aquilo dava um braço que SOBE E PARA — a leitura é "levantou os braços", não
#  "socou". Um soco tem três tempos e faltavam dois. Agora `gura_v_tpose` é uma
#  animação de verdade (`src/anim/GuraPoses.gd`), com RECUO, GOLPE que passa do
#  alvo (z=±1,55 contra o T de ±1,40) e ASSENTAMENTO no T exato, que é a pose
#  obrigatória do pedido e onde o corpo fica tremendo enquanto as ondas viajam.
#
#  O que isto exigiu deste arquivo: as rachaduras deixaram de nascer em `T_SOCO`
#  e passaram para `T_IMPACTO` — senão o vidro trincava com os braços ainda
#  voltando.
func _armar() -> void:
	if not _e_valido():
		return
	_caster.set_meta("custom_pose", "gura_v_lift")
	_caster.set_meta("is_casting", true)
	if _caster.has_method("lock_movement"):
		# Trava só até as ondas saírem. Ultimate não é castigo.
		_caster.lock_movement(T_TSUNAMI, "V")
	if _caster.has_method("pausar_animacao"):
		_caster.pausar_animacao(true)
	if _caster.has_method("add_camera_shake"):
		_caster.add_camera_shake(0.5)
	AudioFX.whoosh(_mundo(), _pos_do_caster(), 0.45)   # grave = massa se juntando

# Entra a pose de T. Ela ABRE recuando os braços — o golpe ainda não saiu, então
# aqui só há o tranco leve de antecipação. Quem sacode a tela é o `_impacto()`.
func _socar() -> void:
	if not _e_valido():
		return
	_caster.set_meta("custom_pose", "gura_v_tpose")
	if _caster.has_method("add_camera_shake"):
		_caster.add_camera_shake(0.35)

# O PUNHO CHEGA. Todo o estrago do tempo 2 é daqui.
func _impacto() -> void:
	if not _e_valido():
		return
	if _caster.has_method("add_camera_shake"):
		_caster.add_camera_shake(1.6)
	if _caster.has_method("pedir_soco_de_fov"):
		_caster.pedir_soco_de_fov(14.0)
	_rachar_o_ar()

# ============================================================================
#  TEMPO 2 — AS RACHADURAS BRANCAS SAINDO DAS MÃOS
# ============================================================================
#
#  A `GuraShatterMesh` é a teia radial branco-ciano de linhas (`SurfaceTool`,
#  `PRIMITIVE_LINES`) que o projeto já usa nos socos. Duas diferenças aqui:
#
#   • ela nasce EM CADA MÃO, não no meio do corpo — é o pedido literal;
#   • ela recebe uma NORMAL (o eixo do golpe), então a teia fica num PLANO DE
#     VIDRO vertical à frente da mão em vez de deitada no chão. Deitada ela lê
#     como marca no piso; em pé, como a tela do mundo trincando.
#
#  A trinca da TELA (`ScreenShatterFX`) entra junto — e por um caminho que
#  funciona: o autoload é buscado em `/root/ScreenShatterFX`.
#  ⚠️ `Engine.has_singleton("ScreenShatterFX")` é SEMPRE FALSO — esse método só
#  enxerga singleton nativo/GDExtension, e este é autoload. O golpe antigo
#  dependia dele, então o efeito NUNCA disparou uma vez sequer.
func _rachar_o_ar() -> void:
	var mundo := _mundo()
	if mundo == null:
		return
	for lado in ["R", "L"]:
		var mao := _ponto_da_mao(lado)
		GuraShatterMesh.spawn(mundo, mao, 3.2, _eixo)
		# Um segundo vidro, menor e girado, atrás do primeiro: duas teias
		# sobrepostas leem como estilhaço, uma só lê como desenho.
		GuraShatterMesh.spawn(mundo, mao + _eixo * 0.6, 1.9, _eixo)
		var anc := _ancora(mao, 1.2)
		GuraFX._ring(anc, 0.4, 5.0, GuraFX.QUAKE, 0.55)
		GuraFX._debris(anc, 0.3, 30)
		AudioFX.snap(mundo, mao, 1.4)

	AudioFX.impact(mundo, _pos_do_caster(), 1.25)
	# 0,75 e não 1,0: a 1,0 o shader branqueia a tela inteira e ENGOLE as
	# rachaduras 3D que saem das mãos — o efeito principal deste tempo.
	# (`shatter` grampeia em 0..1; qualquer número acima de 1 era o mesmo que 1.)
	_trincar_a_tela(0.75, 1.1)

	# Anel de choque no CHÃO sob o jogador: dá escala ao soco. Vai numa âncora
	# posicionada, senão nasceria na origem do mapa (o bug do arquivo antigo).
	var pes := _pos_do_caster()
	pes.y = CHAO + 0.1
	var anc_chao := _ancora(pes, 1.4)
	GuraFX._ring(anc_chao, 1.0, 26.0, GuraFX.QUAKE, 1.0)
	GuraFX._ring(anc_chao, 0.6, 16.0, Color.WHITE, 0.75)

# ============================================================================
#  TEMPO 3 — OS DOIS TSUNAMIS
# ============================================================================
#
#  A onda é a MESMA PEÇA do C do Karatê Tritão — `WaterFX.crista_de_onda`, com
#  um `PerfilDeOnda` de ultimate. Nada da crista foi copiado para cá: lamelas,
#  lábio de espuma, espuma que viaja e borrifo que fica para trás são um código
#  só, e melhorar a leitura da onda melhora as duas.
#
#  O que NÃO vem do perfil é o combate: hitbox, velocidade e vida. O C usa uma
#  ESFERA de raio 2,9; uma esfera que cobrisse 200 m de frente teria 100 m de
#  raio e acertaria quem estivesse 100 m atrás da onda. Aqui a `DamageZone`
#  recebe uma CAIXA (parâmetro opcional novo em `DamageZone.setup`), com a
#  forma da parede que o jogador está vendo.
func _lancar_tsunamis() -> void:
	var mundo := _mundo()
	if mundo == null:
		return
	# Uma onda em cada borda oposta, viajando uma contra a outra.
	_ondas.append(_um_tsunami(+1))
	_ondas.append(_um_tsunami(-1))
	AudioFX.impact(mundo, _pos_do_caster(), 0.55)   # grave e longo: a água chegando
	_trincar_a_tela(0.45, 1.6)
	if _caster.has_method("add_camera_shake"):
		_caster.add_camera_shake(2.0)

# `sinal` = de qual borda esta onda nasce (+1 ou -1 sobre `_eixo`).
func _um_tsunami(sinal: int) -> DamageZone:
	var rumo := -_eixo * float(sinal)                       # aponta para o centro
	var berco := _eixo * (BORDA * float(sinal))
	berco.y = CHAO

	var zona := DamageZone.new()
	# ⚠️ AS ONDAS SÃO FILHAS DESTE NÓ, de propósito. Quem termina a ultimate é
	# ele; se ele morrer (jogador morreu, cena trocou), as ondas morrem junto e
	# não sobra hitbox invisível varrendo o mapa. Dono único, vazamento zero.
	add_child(zona)
	zona.global_position = berco + Vector3.UP * (ALTURA * 0.5)
	zona.look_at(zona.global_position + rumo, Vector3.UP)   # -Z da zona = rumo

	var crista := WaterFX.crista_de_onda(_perfil())
	crista.position = Vector3(0, -ALTURA * 0.5, 0)          # base no chão
	zona.add_child(crista)

	# Caixa de dano com a forma da parede. Profundidade generosa (12 m) porque a
	# zona anda por teleporte: a 40 m/s o passo é 0,67 m por quadro, e uma caixa
	# rasa deixaria margem para atravessar alvo. O `_varrer_caminho` da própria
	# `DamageZone` cobre o resto.
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(LARGURA, ALTURA, HITBOX_FUNDO)

	# Vida = travessia inteira + folga. O `_encontro()` mata as ondas antes
	# disso; este número existe só para o caso de este nó sumir do mapa.
	var vida := (BORDA * 2.0) / VEL + 1.0
	# Knockback FIXO no rumo da onda + viés forte para cima. O radial padrão da
	# `DamageZone` mede alvo − centro da zona: numa parede de 200 m, o centro
	# está a até 100 m de lado, e o alvo sairia empurrado LATERALMENTE.
	zona.override_kb_dir = rumo
	# As DUAS ondas carregam a mesma spec: o teto de 768 é 2 x 384, então quem é
	# pego pelas duas leva a ultimate inteira e quem desvia de uma leva metade.
	zona.setup(_spec.dano, KB, rumo * VEL, vida, _caster, ALTURA * 0.5, caixa)
	_spec.marcar(zona)

	# A onda SOBE do chão em vez de aparecer inteira (mesma ideia do C).
	crista.scale = Vector3(1.0, 0.12, 0.7)
	var tw := crista.create_tween()
	tw.tween_property(crista, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return zona

func _perfil() -> WaterFX.PerfilDeOnda:
	var p := WaterFX.perfil_padrao()
	p.largura = LARGURA
	p.altura = ALTURA
	p.espessura = ESPESSURA
	p.lamelas = LAMELAS
	p.inclinacao = 22.0                       # tomba mais: massa de água pesada
	# ⚠️ LÁBIO FINO E MUITO QUEBRADO. Com raio 2,2 em 13 pedaços a espuma
	# virava um comprimido branco de 180 m boiando sobre a onda (visto em
	# captura). Raio 1,1 em 19 pedaços com ruído lê como rolo quebrando.
	p.labio = 1.1
	p.labio_pedacos = 19
	# ⚠️ COR E BRILHO SÃO LEITURA, NÃO GOSTO. A primeira versão usava o azul
	# médio do C com a emissão do C (1,4): numa parede de 200 m contra o céu
	# claro do mapa, a onda SUMIA — céu azul-claro, água azul-clara brilhando.
	# Medido por captura de tela. Azul de mar fundo e emissão baixa devolvem a
	# silhueta; o lábio de espuma continua branco e é ele que marca a crista.
	p.cor_corpo = WaterFX.AGUA_FUNDA.lerp(WaterFX.AGUA, 0.28)
	p.alfa_corpo = 0.90                       # 24 m de água não são vidro
	p.emissao_corpo = 0.30                    # quase só luz de cena
	p.escala_gota = 4.5                       # respingo na escala da crista
	return p

# ============================================================================
#  TEMPO 4 — O ENCONTRO ENCERRA O ATAQUE
# ============================================================================
#
#  A condição é MEDIDA, não cronometrada: a cada quadro o nó lê a posição REAL
#  das duas zonas e projeta a distância no eixo. Cronômetro mentiria se alguma
#  onda fosse destruída, atrasada ou se o `VEL` mudasse — a pergunta do dono é
#  "quando COLIDIREM", e isso é geometria.
func _process(delta: float) -> void:
	if _fase == 4:
		return
	if not _e_valido():
		_encerrar()
		return

	var antes := _t
	_t += delta

	# Enquanto travado, o corpo fica preso de verdade (um `velocity = 0` só no
	# primeiro quadro não segura ninguém: a gravidade volta no quadro seguinte).
	if _t < T_TSUNAMI and _caster.has_method("congelar_para_cast"):
		_caster.congelar_para_cast()

	if _fase == 0 and antes < T_SOCO and _t >= T_SOCO:
		_fase = 1
		_socar()
	elif _fase == 1 and antes < T_IMPACTO and _t >= T_IMPACTO:
		_fase = 2
		_impacto()
	elif _fase == 2 and antes < T_TSUNAMI and _t >= T_TSUNAMI:
		_fase = 3
		_lancar_tsunamis()
		_soltar_o_corpo()

	if _fase != 3:
		return

	# Rede de segurança: onda perdida (cena trocada, free externo) encerra.
	if _ondas.size() < 2:
		_encontro(global_position)
		return
	for z in _ondas:
		if not is_instance_valid(z):
			_encontro(global_position)
			return
	if _t > T_TSUNAMI + TETO_TRAVESSIA:
		_encontro(_ondas[0].global_position.lerp(_ondas[1].global_position, 0.5))
		return

	var vao: float = absf((_ondas[0].global_position - _ondas[1].global_position).dot(_eixo))
	if vao <= FOLGA_ENCONTRO:
		_encontro(_ondas[0].global_position.lerp(_ondas[1].global_position, 0.5))

# O CLÍMAX: as duas paredes se arrebentam uma na outra. Tudo nasce numa âncora
# POSICIONADA no ponto de encontro — era exatamente isto que faltava no golpe
# antigo, onde os mesmos efeitos apareciam na origem do mapa.
func _encontro(ponto: Vector3) -> void:
	_fase = 4
	var mundo := _mundo()
	var chao := Vector3(ponto.x, CHAO + 0.15, ponto.z)

	if mundo != null:
		var anc := _ancora(chao, 2.6)
		GuraFX._ring(anc, 2.0, 70.0, GuraFX.QUAKE, 1.2)
		GuraFX._ring(anc, 1.0, 46.0, Color.WHITE, 0.9)
		GuraFX._ring(anc, 0.5, 28.0, GuraFX.QUAKE, 0.7)
		GuraFX._bubble(anc, 22.0, 1.1)
		GuraFX._debris(anc, 1.6, 220)
		# O vidro estilhaça de novo, agora no plano de encontro das duas ondas.
		GuraShatterMesh.spawn(mundo, chao + Vector3.UP * 8.0, 9.0, _eixo)
		AudioFX.impact(mundo, chao, 0.5)
		_trincar_a_tela(0.95, 1.4)

	if is_instance_valid(_caster) and _caster.has_method("add_camera_shake"):
		_caster.add_camera_shake(2.5)

	# As ondas DESMANCHAM em vez de sumirem num quadro — sumir lê como bug.
	for z in _ondas:
		if is_instance_valid(z):
			z.vel = Vector3.ZERO
			_desmanchar(z, 0.5)
	_ondas.clear()

	# O nó vive só o tempo do desmanche; depois some inteiro (com os filhos).
	var t := get_tree().create_timer(1.3)
	t.timeout.connect(_encerrar)

func _desmanchar(zona: DamageZone, dur: float) -> void:
	var crista := zona.get_node_or_null("Crista")
	if crista == null or not crista.has_meta("mats"):
		return
	var tw := crista.create_tween()
	tw.set_parallel(true)
	for m in crista.get_meta("mats"):
		tw.tween_property(m, "albedo_color:a", 0.0, dur)

# ============================================================================
#  OFICINA
# ============================================================================

func _soltar_o_corpo() -> void:
	if not _e_valido():
		return
	_caster.remove_meta("custom_pose")
	_caster.set_meta("is_casting", false)
	if _caster.has_method("pausar_animacao"):
		_caster.pausar_animacao(false)

func _encerrar() -> void:
	_soltar_o_corpo()
	if is_inside_tree():
		queue_free()

# O eixo cardeal mais próximo da mira do conjurador. Ver a decisão no cabeçalho.
func _escolher_eixo() -> Vector3:
	if not (_caster is Node3D) or not is_instance_valid(_caster):
		return Vector3.RIGHT
	var frente := -(_caster as Node3D).global_transform.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.0001:
		return Vector3.RIGHT
	return Vector3.RIGHT if absf(frente.x) >= absf(frente.z) else Vector3.BACK

# Nó vazio, JÁ POSICIONADO, para servir de pai aos efeitos do `GuraFX`.
#
# ⚠️ ESTA FUNÇÃO É A CORREÇÃO DO BUG QUE MATOU O V ANTIGO. `GuraFX._ring`,
# `_bubble` e `_debris` recebem um `parent` e nunca definem posição: o efeito
# fica em (0,0,0) LOCAL. Com `world` de pai isso é a ORIGEM DO MAPA. Com uma
# âncora, é onde a âncora está. `GuraFX` não muda — ele é compartilhado com
# Z/X/C, e mexer nele seria arriscar três golpes para consertar um.
func _ancora(pos: Vector3, vida: float) -> Node3D:
	var n := Node3D.new()
	var mundo := _mundo()
	if mundo == null:
		return n
	mundo.add_child(n)
	n.global_position = pos
	FxUtil.autofree(n, vida)      # some com os filhos: nada fica pendurado
	return n

# PONTO DA MÃO em mundo. O rig tem 13 papéis e nenhum se chama "Hand": a mão é
# a PONTA do antebraço, que pende no -Y local do `ForeArm_` (convenção do rig).
#
# ⚠️ A CONTA É FEITA NO ESPAÇO DO MODELO. O `PlayerRig._fit_model_to_body` põe
# escala NÃO-UNIFORME no `_char_model` (o voxel é engrossado 1,85× no Z), e uma
# direção medida no mundo sob escala anisotrópica não é a direção do braço —
# esse detalhe já enganou o medidor do Z desta mesma fruta. `affine_inverse()`
# devolve um rig rígido; o resultado volta para o mundo no fim.
func _ponto_da_mao(lado: String) -> Vector3:
	var alvo := _pos_do_caster()
	if not is_instance_valid(_caster):
		return alvo
	var modelo = _caster.get("_char_model")
	if modelo is Node3D and (modelo as Node3D).is_inside_tree():
		var m3 := modelo as Node3D
		var ombro := m3.find_child("UpperArm_" + lado, true, false)
		var cotovelo := m3.find_child("ForeArm_" + lado, true, false)
		if ombro is Node3D and cotovelo is Node3D:
			var inv := m3.global_transform.affine_inverse()
			var p_o: Vector3 = inv * (ombro as Node3D).global_position
			var p_c: Vector3 = inv * (cotovelo as Node3D).global_position
			var seg := p_o.distance_to(p_c)
			var dir := (inv.basis * (cotovelo as Node3D).global_transform.basis * Vector3(0, -1, 0)).normalized()
			return m3.global_transform * (p_c + dir * seg)
	# Plano B: dois pontos abertos na horizontal, na altura do peito. É a mesma
	# LEITURA da pose de T, mesmo sem rig — a sonda headless cai aqui.
	var fora := Vector3.RIGHT if absf(_eixo.x) < 0.5 else Vector3.BACK
	var s := 1.0 if lado == "R" else -1.0
	return alvo + fora * (1.1 * s)

func _trincar_a_tela(forca: float, dur: float) -> void:
	var mundo := _mundo()
	if mundo == null:
		return
	var fx := mundo.get_node_or_null("/root/ScreenShatterFX")
	if fx and fx.has_method("shatter"):
		fx.shatter(forca, dur)

func _pos_do_caster() -> Vector3:
	if _caster is Node3D and is_instance_valid(_caster):
		return (_caster as Node3D).global_position + Vector3.UP * 1.0
	return global_position

func _mundo() -> Node:
	var p := get_parent()
	return p if p != null and p.is_inside_tree() else null

func _e_valido() -> bool:
	return is_instance_valid(_caster) and _caster is Node and (_caster as Node).is_inside_tree()

func _enter_tree() -> void:
	# O eixo é escolhido UMA vez, no nascimento: se fosse lido a cada quadro, o
	# jogador virando o corpo giraria os tsunamis já lançados.
	_eixo = _escolher_eixo()

func _exit_tree() -> void:
	# Rede final: seja qual for o caminho da morte (fim normal, jogador morreu,
	# cena trocada), o corpo NÃO pode ficar preso numa pose de ultimate.
	if is_instance_valid(_caster) and _caster.has_meta("custom_pose"):
		_caster.remove_meta("custom_pose")
	if is_instance_valid(_caster) and _caster.has_meta("is_casting"):
		_caster.set_meta("is_casting", false)
		if _caster.has_method("pausar_animacao"):
			_caster.pausar_animacao(false)
