class_name Melee
extends RefCounted
# ============================================================================
#  CORPO A CORPO — simples e eficaz, no botão esquerdo do mouse.
#
#  COMBO (definido pelo usuário):
#    clique 1  -> SOCO com o braço DIREITO
#    clique 2  -> SOCO com o braço ESQUERDO   (se vier em até JANELA segundos)
#    clique 3  -> CHUTE, que fecha o combo    (idem)
#  Passou a janela sem clicar, o combo volta ao primeiro soco.
#
#  Sem custo de energia, de propósito: é o golpe que sobra quando a barra azul
#  acaba. Dano baixo e knockback crescente — quem mata é o buraco, não o dano
#  (mesma filosofia da DamageZone, ver DAMAGE_SCALE lá).
#
#  OS DOIS SOCOS SÃO CLIPES DE VERDADE, um de cada lado. Vieram do pacote
#  Meshy "Blue Block Buddy" e foram medidos (soma UpperArm + ForeArm):
#
#    right_upper_hook_from_guard   braço D 477°  x  braço E 144°   (3,3x)
#    left_uppercut_from_guard      braço E 276°  x  braço D  56°   (4,9x)
#
#  Antes disso o combo usava UM clipe só (`punching`, de braço esquerdo — 210°
#  contra 84°) e produzia o soco direito ESPELHANDO-o. `espelhar()` continua
#  aqui embaixo, e continua correta, mas o combo não depende mais dela: clipe
#  autoral lê melhor que reflexão, porque a reflexão também espelha o passo, o
#  ombro e a guarda.
#
#  ⏱️ ANATOMIA MEDIDA DOS CLIPES (2026-08-11). O sinal é o DESLOCAMENTO DO EFETOR
#  (punho / pé) em relação à posição dele em t=0, por cinemática direta no
#  referencial do tronco — o mesmo número para soco reto, hook e chute, e o único
#  dos três candidatos testados que acerta os três (o desvio ANGULAR erra o chute
#  em 0,22 s, porque a perna continua girando na retração; o alcance FRONTAL erra
#  o uppercut, que sobe em vez de ir pra frente). Tudo em TEMPO DE CLIPE, antes de
#  aplicar `inicio`/`vel`:
#
#    | clipe                       | dur   | membro  | começa | PICO=impacto | acaba |
#    | right_upper_hook_from_guard | 1,77s | braço D | 0,217  | 0,633        | 0,933 |
#    | left_uppercut_from_guard    | 1,37s | braço E | 0,217  | 0,367        | 0,783 |
#    | kicking                     | 2,30s | perna D | 0,450  | 1,233        | 1,775 |
#
#  ⚠️ POR QUE OS DOIS SOCOS LIAM IGUAL (relato do dono, medido em 2026-08-11).
#  Não era clipe errado — o contraste entre os braços é enorme nos dois casos
#  (hook: 234° no D contra 52° no E; uppercut: 157° no E contra 30° no D). Eram
#  duas outras coisas, ambas de TEMPO:
#
#   1. VELOCIDADE. A 1,9x, o golpe inteiro do braço direito (0,716 s de clipe)
#      passava em 0,377 s — 23 quadros a 60 fps para 234° de braço. Nesse borrão o
#      olho vê "um braço", não "o braço DIREITO". O esquerdo, a 1,25x, tinha
#      0,453 s. Hoje são 0,597 s e 0,539 s.
#   2. INTERRUPÇÃO. `recuo` era 0,40 s e o impacto do hook caía em 0,368 s (na
#      medição antiga): sobravam **32 ms — 2 quadros** com o braço estendido antes
#      de o clique seguinte TROCAR o clipe. E os dois clipes partem da MESMA pose
#      de guarda (medido: UpperArm_R (50,26,-45)°, ForeArm_L (16,-106,-15)° em
#      ambos, idênticos ao grau). Se o instante que os distingue dura 2 quadros,
#      o que sobra em tela é a guarda — que é comum aos dois.
#
#  A correção tem três partes, e as três dependem uma da outra:
#   • `inicio` corta a guarda parada da abertura (o hook gastava 0,217 s e o chute
#     0,450 s sem mexer o membro) — é isso que paga a desaceleração sem atrasar o
#     soco;
#   • `vel` cai (1,9→1,2 / 1,25→1,05 / 2,4→1,7);
#   • `recuo` passa a ser >= atraso + 0,15 s, garantindo pelo menos 9 quadros de
#     membro estendido antes de o clique seguinte poder cortar (hoje 13, 15 e 14).
# ============================================================================

const JANELA := 2.0        # tempo pra encadear o próximo golpe (pedido do usuário)

# Cada passo do combo.
#
# `inicio` = de onde o clipe começa a tocar (corta a guarda parada da abertura).
# `atraso` = quando a hitbox nasce, contado do CLIQUE. É (pico − inicio) / vel, ou
#            seja uma FRAÇÃO do clipe — mexeu em `vel` ou `inicio`, recalcule.
#            O teste `test_arena.gd` (seção 4) confere essa conta.
# `recuo`  = trava do próximo clique. Também é o tempo mínimo que o golpe fica em
#            tela: enquanto ele corre, nenhum clique troca o clipe.
const COMBO := [
	{
		# Hook de direita. Impacto em 0,633 s de clipe -> (0,633−0,20)/1,2 = 0,361 s.
		"nome": "Soco Direito", "anim": "right_upper_hook_from_guard", "espelhar": false,
		"vel": 1.2, "inicio": 0.20,
		"dano": 30.0, "kb": 11.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.36, "vida": 0.18, "recuo": 0.58, "shake": 0.25,
	},
	{
		# Uppercut de esquerda. Impacto em 0,367 -> (0,367−0,10)/1,05 = 0,254 s.
		# Mais rápido a responder que o hook DE PROPÓSITO: o contraste de ritmo
		# entre os dois é metade da leitura de "trocou de braço".
		"nome": "Soco Esquerdo", "anim": "left_uppercut_from_guard", "espelhar": false,
		"vel": 1.05, "inicio": 0.10,
		"dano": 34.0, "kb": 13.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.25, "vida": 0.18, "recuo": 0.50, "shake": 0.30,
	},
	{
		# O finalizador é o que joga pra fora do mapa: mais alcance e o dobro
		# de knockback dos socos.
		# O `kicking` gasta 0,450 s de clipe só armando — daí o `inicio` alto.
		# Impacto em 1,233 -> (1,233−0,40)/1,7 = 0,490 s.
		# O valor antigo (0,58 a 2,4x = 1,392 s de clipe) nascia 0,16 s DEPOIS de o
		# pé chegar: a hitbox saía na retração, não no chute.
		"nome": "Chute", "anim": "kicking", "espelhar": false,
		"vel": 1.7, "inicio": 0.40,
		"dano": 70.0, "kb": 26.0, "alcance": 2.0, "raio": 1.9,
		"atraso": 0.49, "vida": 0.22, "recuo": 0.72, "shake": 0.6,
	},
]

static var _cache: Dictionary = {}   # "anim|espelhado" -> Animation

static func passo(i: int) -> Dictionary:
	return COMBO[clampi(i, 0, COMBO.size() - 1)]

# Quanto tempo o clipe do passo `i` fica em tela, já com `inicio` e `vel`.
# É o teto de tudo que é temporal no golpe: a hitbox e o recuo têm que caber aqui,
# senão o dano sai depois de a animação acabar (ou o golpe some antes do soco).
static func duracao_tocada(i: int) -> float:
	var a := clipe(i)
	if a == null:
		return 0.0
	var g := passo(i)
	return maxf(a.length - float(g.get("inicio", 0.0)), 0.0) / float(g["vel"])

# Instante do clipe (tempo de CLIPE, não de tela) em que a hitbox nasce. Serve
# para o teste conferir que o `atraso` continua casado com o pico medido do membro
# depois de qualquer mexida em `vel`/`inicio`.
static func impacto_no_clipe(i: int) -> float:
	var g := passo(i)
	return float(g.get("inicio", 0.0)) + float(g["atraso"]) * float(g["vel"])

# ------------------------------------------------------------------ animação
# Devolve o clipe do passo, já espelhado se for o caso (e memorizado — espelhar
# percorre todas as faixas, não vale refazer a cada soco).
static func clipe(i: int) -> Animation:
	var g := passo(i)
	var chave: String = "%s|%s" % [g["anim"], g["espelhar"]]
	if _cache.has(chave):
		return _cache[chave]
	var caminho: String = "res://assets/animations/%s.res" % g["anim"]
	if not ResourceLoader.exists(caminho):
		push_warning("[Melee] clipe ausente: " + caminho)
		return null
	var a: Animation = load(caminho)
	if g["espelhar"]:
		a = espelhar(a)
	_cache[chave] = a
	return a

# Espelha um clipe do rig de papéis (esquerda <-> direita).
#
# NÃO é usada pelo combo desde que entraram os dois socos autorais — fica porque
# a biblioteca do Mixamo é quase toda de um lado só, e o dia que um golpe novo
# precisar do lado oposto, isto resolve sem reexportar nada. Validada: no
# `punching`, 56°/159° vira 159°/56°.
# Gatilho para apagar: se daqui a alguns golpes nenhum tiver usado, é dívida.
static func espelhar(orig: Animation) -> Animation:
	var out: Animation = orig.duplicate(true)
	for i in out.get_track_count():
		var caminho := String(out.track_get_path(i))
		var papel := caminho.get_slice(":", 0)
		var resto := caminho.substr(papel.length())
		if papel.ends_with("_L"):
			papel = papel.substr(0, papel.length() - 2) + "_R"
		elif papel.ends_with("_R"):
			papel = papel.substr(0, papel.length() - 2) + "_L"
		out.track_set_path(i, NodePath(papel + resto))
		for k in out.track_get_key_count(i):
			var v = out.track_get_key_value(i, k)
			if v is Vector3:
				out.track_set_key_value(i, k, Vector3(v.x, -v.y, -v.z))
	return out

# --------------------------------------------------------------------- golpe
# Cria a hitbox do passo `i` à frente de `caster`. RODA NO SERVIDOR (é ele que
# instancia a DamageZone; ver Player._do_server_melee).
static func golpear(world: Node, caster: Node3D, i: int, origem: Vector3, dir: Vector3) -> void:
	var g := passo(i)
	var fwd := dir.normalized()
	var alto: float = origem.y - caster.global_position.y   # altura do peito, relativa
	var timer := world.get_tree().create_timer(float(g["atraso"]))
	timer.timeout.connect(func():
		if not is_instance_valid(caster) or not is_instance_valid(world):
			return
		var zone := DamageZone.new()
		world.add_child(zone)
		# A hitbox segue o CORPO até o instante do soco. `origem` foi capturada no
		# clique, e agora o clique fica até 0,50 s à frente do impacto — correndo a
		# 4,2 m/s isso são 2,1 m de defasagem, ou seja a hitbox nascia ATRÁS do
		# jogador. A DIREÇÃO continua a do clique: o golpe se compromete com o lado
		# para onde você olhou ao apertar, e girar o mouse no meio não teleguia.
		zone.global_position = caster.global_position + Vector3.UP * alto + fwd * float(g["alcance"])
		# vel = 0: a hitbox do corpo a corpo fica onde nasceu; alcance é o braço,
		# não um projétil.
		zone.setup(float(g["dano"]), float(g["kb"]), Vector3.ZERO,
			float(g["vida"]), caster, float(g["raio"]))
		_impacto(world, zone.global_position, i, cor_do_impacto(caster)))

# COR DO SOCO = cor do ESTILO em uso (pedido do dono, 2026-08-12: "quando
# equipado os efeitos do combate corpo a corpo mudam para azul" — o Tritão já é
# azul em `FightingStyles.STYLES["karate_tritao"]["cor"]`).
#
# Genérico de propósito. Um `if estilo == "karate_tritao": azul` resolveria hoje
# e obrigaria a mexer aqui a cada estilo novo; ler a cor que o estilo JÁ declara
# não custa mais e faz o Pacifista sair vermelho e o Mink amarelo de graça.
# No modo FRUTA fica o branco-quente de sempre: lá o soco é o golpe "sem poder",
# e pintá-lo da cor da fruta confundiria com as skills dela.
static func cor_do_impacto(caster: Node) -> Color:
	const PADRAO := Color(1.0, 0.95, 0.8)
	if caster == null or str(caster.get("combat_mode")) != "style":
		return PADRAO
	if not caster.has_method("estilo_atual"):
		return PADRAO
	var estilo: String = caster.estilo_atual()
	if not FightingStyles.STYLES.has(estilo):
		return PADRAO
	return FightingStyles.STYLES[estilo].get("cor", PADRAO)

# Fiapo visual do golpe: um anel achatado que abre e some no lugar do impacto.
# Curto de propósito — o corpo a corpo tem que ler pela ANIMAÇÃO, não por VFX.
static func _impacto(world: Node, pos: Vector3, i: int, cor: Color = Color(1.0, 0.95, 0.8)) -> void:
	AudioFX.whoosh(world, pos, 1.15 if i < 2 else 0.85)
	var m := MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.25
	anel.outer_radius = 0.45
	m.mesh = anel
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.55)
	mat.emission_enabled = true
	# A emissão é a mesma cor puxada pro brilho — `lightened` em vez de um segundo
	# valor escrito à mão, senão cada cor de estilo precisaria de DUAS entradas na
	# tabela e as duas poderiam divergir.
	mat.emission = cor.lightened(0.15)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	world.add_child(m)
	m.global_position = pos
	m.rotation.x = PI * 0.5
	var escala: float = 1.0 if i < 2 else 1.7
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * escala * 2.2, 0.20).from(Vector3.ONE * 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.20)
	tw.chain().tween_callback(m.queue_free)
