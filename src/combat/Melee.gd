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
#  acaba. Dano moderado e knockback crescente — quem mata é o buraco, não o
#  dano. Os valores vêm de `Balance.MELEE`; ver a nota sobre a reescala em
#  `COMBO`, embaixo.
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
#    | roundhouse_kick             | 2,17s | perna E | 0,442  | 1,100        | 1,367 |
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
#
#  🦵 O CHUTE VIROU LATERAL (2026-08-18, pedido do dono). O passo 2 tocava
#  `kicking` (chute FRONTAL, perna D indo pra frente — alcance frontal 2,30 nas
#  unidades de osso da medição). O dono queria um chute de LADO no lugar.
#
#  CANDIDATOS TESTADOS (`medir_impacto_res.gd kicking roundhouse_kick
#  roundhouse_kick_2 flying_kick chapa_2 chapa_giratoria_2`), com o alcance
#  FRONTAL (−Z) de cada perna como pista de "quão de frente" o chute é — não
#  como medida final (o próprio cabeçalho deste arquivo já avisa que o alcance
#  frontal erra o uppercut; num chute de verdade lateral ele SUBESTIMA o pico,
#  porque o pé cruza mais pro lado que pra frente):
#   • `roundhouse_kick` / `roundhouse_kick_2` — alcance frontal baixo nas duas
#     pernas (0,26 e 0,83): o pé nunca vai muito à frente, sinal de arco
#     LATERAL de verdade. "Roundhouse" É a lateral/giratória do jargão (o nome
#     já entrega). As duas variações são **pose-idênticas** (comparado clipe a
#     clipe por cinemática direta: diferença máxima 0,000 em todo o comprimento
#     — mesma dupla do `Punching`/`punching` já catalogada na seção 2 do
#     `docs/ANIMACOES_MIXAMO.md`); ficou a `roundhouse_kick` (nome canônico,
#     sem sufixo de variação).
#   • `chapa_2` — alcance frontal alto (1,15) E a maior amplitude de perna de
#     todos os candidatos (826° só na canela). "Chapa" aqui é o chute de
#     EMPURRÃO reto (tipo teep de Muay Thai): frontal, não lateral — descartado
#     pelo próprio movimento medido, não só pelo nome.
#   • `chapa_giratoria_2` — "giratória" é lateral no jargão, mas é um chute
#     GIRATÓRIO (o corpo roda quase 360°): golpe vistoso demais pro combo
#     básico de 3 cliques, mesmo problema de escopo do `flying_kick` (chute
#     COM SALTO) — o dono pediu um chute lateral simples, não um especial.
#
#  ESCOLHIDO: `roundhouse_kick`. A perna que soca é a ESQUERDA — não a direita
#  como no `kicking` antigo — confirmado por dois sinais concordantes:
#  amplitude (coxa+canela E = 354° contra D = 200°, via
#  `medir_amplitude_res.gd`) e alcance frontal (perna E = 0,83 contra D = 0,26,
#  via `medir_impacto_res.gd`). Por isso o `melee_guarda` deste passo é
#  `"perna_L"`, não `"perna_R"`.
#
#  RECALIBRAÇÃO (mesmo método do resto deste arquivo — ver `_janela_acao` em
#  `tools/dev_tests/test_arena.gd`, que é quem de fato mede "começa"/PICO/
#  "acaba" pelo DESLOCAMENTO do efetor relativo ao t=0 do clipe, não pelo
#  alcance frontal usado só para triar candidato acima):
#   • `começa` (perna E passa de 25% do pico) = 0,442s — não há guarda parada
#     de verdade pra cortar (a perna já está saindo da pose de repouso desde
#     ~0,03s, diferente do `kicking`, que ficava 0,45s imóvel); `inicio` = 0,40
#     corta só o início lento do arremesso do quadril, igual ao `kicking`
#     antigo, sem entrar na guarda.
#   • PICO (=impacto) = 1,10s. É MAIS TARDE que o pico do alcance frontal
#     (0,83 em t=1,02) — esperado num chute lateral: o pé continua abrindo
#     para o lado depois de passar pelo ponto mais à frente, e o deslocamento
#     TOTAL (o sinal que este arquivo já usa pros outros 3 golpes) pega esse
#     instante, não o alcance frontal isolado.
#   • `vel` = 1,5 (mesma da soco rápido/finalizador — dá 1,18s de golpe em
#     tela, no mesmo talho dos outros três passos do combo).
#   • `atraso` = (1,10 − 0,40) / 1,5 = 0,4667.
#  `dano`/`kb`/`alcance`/`raio`/`vida`/`shake` ficaram OS MESMOS: são parâmetros
#  de JOGO (a hitbox nasce à frente do jogador ao longo da mira, ver
#  `golpear()`) e não da pose — o chute virar lateral em tela não muda pra
#  onde a hitbox precisa alcançar.
# ============================================================================

const JANELA := 2.0        # tempo pra encadear o próximo golpe (pedido do usuário)

# Cada passo do combo.
#
# `inicio` = de onde o clipe começa a tocar (corta a guarda parada da abertura).
# `atraso` = quando a hitbox nasce, contado do CLIQUE. É (pico − inicio) / vel, ou
#            seja uma FRAÇÃO do clipe — mexeu em `vel` ou `inicio`, recalcule.
#            O teste `test_arena.gd` (seção 4) confere essa conta.
#
# ⚠️ NÃO EXISTE MAIS UM `recuo` AQUI. Ele era escrito à mão golpe a golpe e virou
# conta derivada da animação em 2026-08-15 — ver `static func recuo()` embaixo e
# o `tools/dev_tests/medir_tempos_melee.gd`, que mede a defasagem que motivou a
# troca. Quem quiser um golpe mais lento mexe em `vel`/`inicio`: a trava segue.
# ⚠️ OS VALORES DE `dano` FORAM REESCALADOS EM 2026-08-21, junto com o resto do
# jogo. Eram 30/34/40/70, números da escala antiga, em que a `DamageZone` ainda
# multiplicava tudo por 0,12 — o combo inteiro tirava 20,9 de uma vida de 2048.
#
# Agora são os de `Balance.MELEE`, e o combo completo vale 278: pouco mais que
# um golpe Z de fruta. Sem este realinhamento o corpo a corpo ficaria trinta
# vezes mais fraco que as frutas e deixaria de ser uma opção.
#
# ⚠️ Eles ficam AQUI, e não só no `Balance`, de propósito: cada passo é uma
# linha de frame data (`vel`, `inicio`, `atraso`, `vida`, `shake`) e separar só
# a coluna `dano` para outro arquivo tornaria ilegível a leitura de um golpe.
# O `test_balance.gd` confere que as duas tabelas continuam batendo.
const COMBO := [
	{
		"nome": "Soco Direito", "anim": "boxing_1", "espelhar": false,
		"vel": 1.5, "inicio": 0.00,
		"dano": 48.0, "kb": 11.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.3780, "vida": 0.18, "shake": 0.25,
		"melee_guarda": "R",
	},
	{
		"nome": "Soco Esquerdo", "anim": "left_uppercut_from_guard", "espelhar": false,
		"vel": 1.05, "inicio": 0.10,
		"dano": 54.0, "kb": 13.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.25, "vida": 0.18, "shake": 0.30,
		"melee_guarda": "L",
	},
	{
		# Chute LATERAL (2026-08-18, era "Chute Frontal" com `kicking`). Ver a
		# nota datada no cabeçalho do arquivo pra escolha do clipe e a conta do
		# `atraso`. Perna que golpeia é a ESQUERDA — daí `melee_guarda` ser
		# "perna_L" e não "perna_R".
		"nome": "Chute Lateral", "anim": "roundhouse_kick", "espelhar": false,
		"vel": 1.5, "inicio": 0.40,
		"dano": 64.0, "kb": 15.0, "alcance": 2.0, "raio": 1.9,
		"atraso": 0.4667, "vida": 0.22, "shake": 0.4,
		"melee_guarda": "perna_L",
	},
	{
		"nome": "Finalizador", "anim": "meia_lua_de_compasso", "espelhar": false,
		"vel": 1.5, "inicio": 0.00,
		"dano": 112.0, "kb": 26.0, "alcance": 2.2, "raio": 2.0,
		"atraso": 0.7113, "vida": 0.25, "shake": 0.6,
	},
]

const COMBO_SWORD := [
	{
		"nome": "Corte Direita-Esquerda", "anim": "boxing_1", "espelhar": false,
		"vel": 1.5, "inicio": 0.00,
		"dano": 64.0, "kb": 15.0, "alcance": 2.5, "raio": 2.0,
		"atraso": 0.35, "vida": 0.20, "shake": 0.35,
	},
	{
		"nome": "Corte Esquerda-Direita", "anim": "boxing_1", "espelhar": true,
		"vel": 1.4, "inicio": 0.00,
		"dano": 72.0, "kb": 18.0, "alcance": 2.5, "raio": 2.0,
		"atraso": 0.35, "vida": 0.20, "shake": 0.40,
	},
	{
		"nome": "Corte Vertical", "anim": "boxing_2", "espelhar": false,
		"vel": 1.2, "inicio": 0.10,
		"dano": 96.0, "kb": 25.0, "alcance": 3.0, "raio": 2.5,
		"atraso": 0.30, "vida": 0.25, "shake": 0.50,
		"projetil": true
	},
]

static var _cache: Dictionary = {}   # "anim|espelhado" -> Animation

static func passo(i: int, weapon: String = "") -> Dictionary:
	if weapon == "sword":
		return COMBO_SWORD[clampi(i, 0, COMBO_SWORD.size() - 1)]
	return COMBO[clampi(i, 0, COMBO.size() - 1)]

# ---------------------------------------------------------------- RECUPERAÇÃO
#
#  ⏱️ A TRAVA É A ANIMAÇÃO (2026-08-15, pedido do dono).
#
#  Até aqui `recuo` era um número escrito à mão em cada golpe, sem nada que o
#  ligasse ao clipe que estava em tela. Medido pelo
#  `tools/dev_tests/medir_tempos_melee.gd`, a defasagem era de 0,30 s a 1,00 s
#  nos SETE golpes — o clique seguinte SEMPRE abria com o golpe anterior ainda
#  correndo, e o clipe novo cortava o antigo no meio. Era a causa mecânica do
#  sintoma que o cabeçalho lá em cima já descrevia por outro ângulo ("os dois
#  socos liam igual"): o que sobrava em tela era a guarda, comum aos dois.
#
#  Agora sai da conta `(comprimento − inicio) / vel` — a mesma que a espada já
#  usava. Mexer em `vel` ou `inicio` reajusta a trava sozinho, que é o ponto.
#
#  ⚠️ A CAUDA FOI MEDIDA ANTES DE DECIDIR. Clipe com sobra parada no fim faria a
#  trava prender o jogador olhando para um boneco imóvel. Medido: a cauda é
#  0,00–0,03 s nos sete golpes — os clipes se mexem até o último quadro. Por isso
#  a duração cheia serve como trava sem ajuste.
const MARGEM_POS_IMPACTO := 0.15

# A ÚNICA ALAVANCA. 1,0 = trava até o último quadro da animação. Baixar para
# ~0,55 devolve o combo antigo (2,6 s nos quatro golpes contra 5,0 s de hoje)
# sem tocar em mais nada.
const TRAVA_DA_ANIMACAO := 1.0

# Quanto tempo o golpe segura o CLIQUE seguinte e o CORPO. São o mesmo número de
# propósito: é isso que "correlacionar a animação com o próximo clique" quer.
static func recuo(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	var d := duracao_tocada(i, weapon) * TRAVA_DA_ANIMACAO
	# PISO: a regra antiga (`recuo >= atraso + 0,15`) não era capricho — garante
	# ~9 quadros de membro estendido depois de a hitbox nascer. Ela sobrevive para
	# o dia em que entrar um clipe curto demais.
	return maxf(d, float(g["atraso"]) + MARGEM_POS_IMPACTO)

# Quanto tempo o clipe do passo `i` fica em tela, já com `inicio` e `vel`.
# É o teto de tudo que é temporal no golpe — e, desde 2026-08-15, também o CHÃO:
# a trava do próximo clique e a do corpo saem daqui (ver `recuo`).
static func duracao_tocada(i: int, weapon: String = "") -> float:
	var a := clipe(i, weapon)
	if a == null:
		return 0.0
	var g := passo(i, weapon)
	return maxf(a.length - float(g.get("inicio", 0.0)), 0.0) / float(g["vel"])

# Instante do clipe (tempo de CLIPE, não de tela) em que a hitbox nasce. Serve
# para o teste conferir que o `atraso` continua casado com o pico medido do membro
# depois de qualquer mexida em `vel`/`inicio`.
static func impacto_no_clipe(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	return float(g.get("inicio", 0.0)) + float(g["atraso"]) * float(g["vel"])

# ------------------------------------------------------------------ animação
# Devolve o clipe do passo, já espelhado se for o caso (e memorizado — espelhar
# percorre todas as faixas, não vale refazer a cada soco).
static func clipe(i: int, weapon: String = "") -> Animation:
	var g := passo(i, weapon)
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
		# O caminho é hierárquico ("Torso/Thigh_L/Shin_L:rotation"), então TODO
		# segmento precisa virar de lado — trocar só o último deixaria o caminho
		# apontando para um nó que não existe. Ver src/anim/RigContrato.gd.
		out.track_set_path(i, RigContrato.espelha_caminho(out.track_get_path(i)))
		for k in out.track_get_key_count(i):
			var v = out.track_get_key_value(i, k)
			if v is Vector3:
				out.track_set_key_value(i, k, Vector3(v.x, -v.y, -v.z))
	return out

# --------------------------------------------------------------------- golpe
# Cria a hitbox do passo `i` à frente de `caster`. RODA NO SERVIDOR (é ele que
# instancia a DamageZone; ver Player._do_server_melee).
static func golpear(world: Node, caster: Node3D, i: int, origem: Vector3, dir: Vector3) -> void:
	var weapon = caster.equipped_weapon if caster and "equipped_weapon" in caster else ""
	var g := passo(i, weapon)
	var fwd := dir.normalized()
	var alto: float = origem.y - caster.global_position.y   # altura do peito, relativa
	
	var s := 1.0
	if "scale" in caster:
		s = caster.scale.y
		
	var timer := world.get_tree().create_timer(float(g["atraso"]) * s)
	timer.timeout.connect(func():
		if not is_instance_valid(caster) or not is_instance_valid(world):
			return
		var zone := DamageZone.new()
		world.add_child(zone)
		
		zone.hit_landed.connect(func(target):
			if is_instance_valid(caster) and "hit_confirmed" in caster:
				caster.hit_confirmed = true
		)
		
		# A hitbox segue o CORPO até o instante do soco. `origem` foi capturada no
		# clique, e agora o clique fica até 0,50 s à frente do impacto — correndo a
		# 4,2 m/s isso são 2,1 m de defasagem, ou seja a hitbox nascia ATRÁS do
		# jogador. A DIREÇÃO continua a do clique: o golpe se compromete com o lado
		# para onde você olhou ao apertar, e girar o mouse no meio não teleguia.
		zone.global_position = caster.global_position + Vector3.UP * alto + fwd * (float(g["alcance"]) * s)
		
		var forma: Shape3D = null
		if weapon == "sword":
			zone.is_weapon_swing = true
			# Cria uma BoxShape3D longa para simular o arco do corte da espada
			var box = BoxShape3D.new()
			box.size = Vector3(float(g["raio"]) * 2.0 * s, float(g["raio"]) * 0.5 * s, float(g["alcance"]) * 1.5 * s)
			forma = box
			zone.basis = Basis.looking_at(fwd, Vector3.UP)
			
		# vel = 0: a hitbox do corpo a corpo fica onde nasceu; alcance é o braço,
		# não um projétil.
		zone.setup(float(g["dano"]) * s, float(g["kb"]) * s, Vector3.ZERO,
			float(g["vida"]) * s, caster, float(g["raio"]) * s, forma, float(g.get("hitstun", 0.3)))
		_impacto(world, zone.global_position, i, cor_do_impacto(caster), s)
		
		# Dispara projétil se o passo definir
		if g.get("projetil", false):
			_spawn_air_slash(world, caster, fwd, g, s)
	)

# ============================================================================
#  PROJÉTIL: MEIA LUA (Corte Aéreo)
# ============================================================================
static func _spawn_air_slash(world: Node, caster: Node3D, fwd: Vector3, g: Dictionary, s: float) -> void:
	var proj := DamageZone.new()
	world.add_child(proj)
	proj.is_projectile = true
	proj.global_position = caster.global_position + Vector3.UP * (1.5 * s) + fwd * 2.0 * s
	proj.basis = Basis.looking_at(fwd, Vector3.UP)
	
	var box = BoxShape3D.new()
	box.size = Vector3(4.0 * s, 0.5 * s, 1.0 * s) # Larga e fina (meia-lua)
	
	# Velocidade do projétil: 25 m/s
	proj.setup(float(g["dano"]) * Balance.MELEE["projetil_mult"] * s, float(g["kb"]) * 1.5 * s, fwd * 25.0, 1.5, caster, 1.0, box)
	
	# Visual da meia-lua
	var m := MeshInstance3D.new()
	var meia_lua := TorusMesh.new()
	meia_lua.inner_radius = 1.8 * s
	meia_lua.outer_radius = 2.2 * s
	m.mesh = meia_lua
	
	var mat := StandardMaterial3D.new()
	var cor = cor_do_impacto(caster).lightened(0.2)
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	
	proj.add_child(m)
	# Rotaciona para ficar em pé, parecendo um arco vertical viajando para frente
	m.rotation = Vector3(PI/2.0, 0, 0)
	
	# Deleta a metade de trás do Torus girando e escalando, ou apenas deixa o anel inteiro brilhante viajando
	# Por simplicidade e robustez, usamos o Torus escalado.
	m.scale = Vector3(1.0, 0.2, 1.0)

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
static func _impacto(world: Node, pos: Vector3, i: int, cor: Color = Color(1.0, 0.95, 0.8), s_factor: float = 1.0) -> void:
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
	var escala: float = (1.0 if i < 2 else 1.7) * s_factor
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * escala * 2.2, 0.20).from(Vector3.ONE * 0.3 * s_factor)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.20)
	tw.chain().tween_callback(m.queue_free)
