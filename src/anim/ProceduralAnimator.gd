class_name ProceduralAnimator
extends Node
# Animação PROCEDURAL em tempo real do rig articulado (nós, não skinado).
# Lê o estado do Player (velocidade, corrida/shift, no chão, escalando, pitch da mira) e gera
# idle / walk / sprint-run / jump-fall / climb em runtime.

const SPEED_REF := 4.2     # SPEED do Player (para normalizar 0..1)
# Rigidez do lerp das juntas. 16 era folgado demais depois que a marcha passou a
# ter ciclo curto (11-25 quadros): o filtro atrasava e atenuava a perna, o pé
# plantado deixava de cancelar a subida do corpo e voltava a flutuar. 38 segue o
# alvo de perto sem perder a suavidade das transições (que têm blend próprio).
const STIFFNESS := 38.0
# Passadas por metro percorrido (cadência ligada à DISTÂNCIA, não ao tempo).
# Menor = animação de walk/run mais lenta e calma; maior = passos mais curtos/rápidos.
const STRIDE_GAIN := 1.0
# ------------------------------------------------------- RITMO DA MARCHA
# O personagem tem 1,5 m e anda a 4,2 m/s. Casar o pé com o chão nessa
# combinação exige ~7,9 passos por segundo (medido) — o dobro de um humano
# correndo, e era isso que deixava a animação frenética.
#
# ⚠️ LEIA ANTES DE MEXER (medido em 2026-08-10, os números anteriores aqui
# estavam errados: falavam em "8% de deslize", e o valor real é 45%):
#
#   deslize ≡ 1 − CADENCIA_ESCALA
#
# Isso é IDENTIDADE, não coincidência, e vale enquanto `CADENCIA_MAX` não morder:
# a velocidade do pé no apoio é passada/π·ω, e ω já traz a passada no
# denominador, então ela CANCELA. Consequências práticas:
#   • o deslize NÃO depende do porte do personagem (base 0,47 m de perna e nami
#     0,61 m dão os mesmos 45%), nem da passada, nem da altura do quadril;
#   • `CADENCIA_ESCALA` é a ÚNICA alavanca de deslize que existe aqui;
#   • quando `CADENCIA_MAX` morde, o deslize passa de 1 − CADENCIA_ESCALA sem
#     avisar (o teste tem um item só para pegar isso).
#
# As outras duas alavancas mexem no RITMO e na SILHUETA, não no deslize:
#   • ALTURA DO QUADRIL — agachar alonga o alcance do pé (√(alcance² − H²)), o
#     que alonga a passada e DERRUBA a cadência na mesma proporção. Como o
#     deslize não muda sozinho, ela só vira ganho de deslize se `CADENCIA_ESCALA`
#     subir junto, mantendo a cadência. Medido em base/WALK, cadência fixa:
#         H=0,80·perna → passada 0,49 m, deslize 45%, coxa  87°  (hoje)
#         H=0,70·perna → passada 0,59 m, deslize 34%, coxa 108°
#         H=0,60·perna → passada 0,65 m, deslize 26%, coxa 125°
#     Ou seja: dá para comprar deslize com agachamento, pagando em silhueta.
#   • `PASSADA_GANHO` está INERTE no regime de jogo: a passada pedida (1,52·perna
#     a plena velocidade) estoura o teto geométrico (1,13·perna) e é cortada por
#     ele. Trocar 1,6 por 1,3 não muda um milímetro na medição; só abaixo de ~1,1
#     o valor volta a ter efeito.
#
# Zerar o deslize mantendo a cadência de hoje exigiria passada 1,83× maior, ou
# seja, o quadril a 10 cm do chão numa perna de 47 cm: geometricamente
# impossível. Os 45% são o preço ESCOLHIDO para não virar hélice; o walk que saiu
# daqui foi aprovado pelo dono do projeto. O conserto de verdade é reduzir
# `Player.SPEED` — 4,2 m/s num corpo de 1,5 m é um humano a ~11 m/s.
const CADENCIA_ESCALA := 0.55
const PASSADA_GANHO := 1.6
# Teto da cadência (rad/s). Serve para as pernas não virarem hélice num pico de
# velocidade; no sprint normal a conta fica abaixo dele.
const CADENCIA_MAX := 30.0
# Altura do quadril como fração da perna esticada. Nunca 1.0: o joelho precisa
# sobrar dobrado, senão a IK satura e o pé sobe em vez de esticar.
const H_PARADO := 0.94
const H_CORRIDA := 0.80
const H_SPRINT := 0.76   # corrida agacha mais -> o pé alcança mais longe

var _n: Dictionary = {}     # papel -> Node3D
var _rest: Dictionary = {}  # papel -> Vector3 (rotação de descanso)
var _m: Dictionary = {}     # métricas do corpo
var _rest_torso_pos := Vector3.ZERO
var _bob_suave := 0.0   # bob filtrado com a MESMA rigidez das juntas

var _phase := 0.0
var _air_w := 0.0
var _climb_w := 0.0
var _charge_w := 0.0        # peso da pose de "estilingue" (segurando a skill)
var _wallrun_w := 0.0       # parkour: corrida na parede (#3)
var _roll_w := 0.0          # parkour: rolamento do pouso de precisão (#4)
var _ljump_w := 0.0         # parkour: salto longo / vault no ar (#1, #2)
var _gun_w := 0.0           # rajada Z (mera/hie): pose de dedo-revólver mirando
var _hibashira_w := 0.0     # pose de entrada e sustentação do Hibashira (soca o chão, pernas abertas)
var _gura_x_charge_w := 0.0 # pose de carregamento da Skill X (braço direito esticado para captura)
var _gura_rush_w := 0.0     # pose assimétrica de investida do Barba Branca (braço direito levantado)
var _kurouzu_w := 0.0       # pose de atração do Kurouzu (braço à frente)
var _black_hole_w := 0.0    # pose do Barba Negra no Black Hole (pernas abertas, mão pro chão)
var _gura_v_w := 0.0        # peso da ultimate V da Gura Gura
var _gura_v_state := ""     # estado interno da ultimate V
var _recovery_t := 0.0      # timer do tranco elástico de recepção (chicote)
var _t := 0.0

# Clipe BAKED (ex.: Mixamo retargetado): dirige os nós por role, sobrepondo a
# animação procedural enquanto toca. Cada faixa tem path "<Role>:rotation".
var _baked: Animation = null
var _baked_t := 0.0
var _baked_speed := 1.0

# Presente só em personagens SKINNADOS: espelha os proxies nos ossos.
var _driver: SkeletonDriver = null

const REC_DUR := 0.35       # duração da recepção (recovery)

# Toca um clipe retargetado (Animation com faixas <Role>:rotation) por cima do rig.
# `speed` acelera o clipe sem reassá-lo: os golpes do Mixamo são autorados em
# ~2 s, tempo demais para um combo de corpo a corpo encadeado em 2 s.
#
# `start` PULA o começo do clipe. Os golpes do Mixamo abrem com uma guarda parada
# (medido: o `right_upper_hook_from_guard` só mexe o braço aos 0,392 s de 1,77 s —
# 22% do clipe é pose de espera). Sem isso a única forma de o soco CONECTAR rápido
# é acelerar o clipe inteiro, e é a aceleração que borra qual braço saiu. Cortar a
# espera e tocar o golpe MAIS DEVAGAR dá as duas coisas: resposta e leitura.
func play_baked(anim: Animation, speed: float = 1.0, start: float = 0.0) -> void:
	_baked = anim
	_baked_t = 0.0 if anim == null else clampf(start, 0.0, maxf(anim.length - 0.01, 0.0))
	_baked_speed = maxf(speed, 0.01)

func is_playing_baked() -> bool:
	return _baked != null

func _apply_baked(delta: float) -> void:
	_baked_t += delta * _baked_speed
	for i in _baked.get_track_count():
		var role := String(_baked.track_get_path(i)).get_slice(":", 0)
		if _n.has(role):
			var euler = _baked.value_track_interpolate(i, _baked_t)
			if euler is Vector3:
				(_n[role] as Node3D).rotation = euler
	if _driver:
		_driver.push()
	if _baked_t >= _baked.length:
		_baked = null

func setup(profile: Dictionary) -> void:
	_n = profile.get("nodes", {})
	_rest = profile.get("rest", {})
	_m = profile.get("metrics", {})
	# Personagem SKINNADO: os nós acima são proxies; o driver copia a rotação
	# deles pros ossos do Skeleton3D depois que os geradores rodam.
	_driver = profile.get("driver")
	if _n.has("Torso"):
		_rest_torso_pos = (_n["Torso"] as Node3D).position
		if _driver:
			_driver.set_torso_rest(_rest_torso_pos)

# Chamado todo frame pelo Player (suporta is_sprinting pelo Shift).
func update(velocity: Vector3, on_floor: bool, climbing: bool, delta: float, pitch: float, is_sprinting: bool = false, charging: bool = false, charge_slot: String = "", parkour: String = "", aim_gun: bool = false, gun_recoil: float = 0.0) -> void:
	_t += delta
	# Clipe retargetado (Mixamo) sobrepõe TUDO enquanto toca.
	if _baked != null:
		_apply_baked(delta)
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var speed01: float = clampf(planar / SPEED_REF, 0.0, 1.8)

	# ---- pesos de estado (blend suave) ----
	var climb_target := 1.0 if climbing else 0.0
	_climb_w = lerpf(_climb_w, climb_target, 1.0 - exp(-14.0 * delta))

	var air_target := 0.0 if (on_floor or climbing) else 1.0
	_air_w = lerpf(_air_w, air_target, 1.0 - exp(-10.0 * delta))

	var charge_target := 1.0 if charging else 0.0
	_charge_w = lerpf(_charge_w, charge_target, 1.0 - exp(-18.0 * delta))

	# ---- pesos PARKOUR (blend rápido; sobrepõem locomoção/ar) ----
	_wallrun_w = lerpf(_wallrun_w, 1.0 if parkour == "wall_run" else 0.0, 1.0 - exp(-16.0 * delta))
	_roll_w    = lerpf(_roll_w,    1.0 if parkour == "roll" else 0.0,     1.0 - exp(-22.0 * delta))
	_ljump_w   = lerpf(_ljump_w,   1.0 if parkour == "long_jump" else 0.0, 1.0 - exp(-12.0 * delta))
	_gun_w     = lerpf(_gun_w,     1.0 if aim_gun else 0.0,               1.0 - exp(-20.0 * delta))
	var custom_pose: String = get_parent().get_meta("custom_pose", "") if get_parent() else ""
	_hibashira_w  = lerpf(_hibashira_w,  1.0 if custom_pose == "hibashira" else 0.0,  1.0 - exp(-20.0 * delta))
	_kurouzu_w    = lerpf(_kurouzu_w,    1.0 if custom_pose == "kurouzu" else 0.0,    1.0 - exp(-20.0 * delta))
	_black_hole_w = lerpf(_black_hole_w, 1.0 if custom_pose == "black_hole" else 0.0, 1.0 - exp(-20.0 * delta))
	_gura_x_charge_w = lerpf(_gura_x_charge_w, 1.0 if custom_pose == "gura_x_charge" else 0.0, 1.0 - exp(-20.0 * delta))
	_gura_rush_w  = lerpf(_gura_rush_w,  1.0 if custom_pose == "gura_rush" else 0.0,  1.0 - exp(-25.0 * delta))
	
	if custom_pose.begins_with("gura_v_"):
		_gura_v_state = custom_pose
		_gura_v_w = lerpf(_gura_v_w, 1.0, 1.0 - exp(-15.0 * delta))
	else:
		_gura_v_w = lerpf(_gura_v_w, 0.0, 1.0 - exp(-15.0 * delta))
		
	var parkour_w: float = maxf(_wallrun_w, maxf(_roll_w, _ljump_w))
	var upper_free: float = (1.0 - parkour_w) * (1.0 - _hibashira_w) * (1.0 - _kurouzu_w) * (1.0 - _black_hole_w) * (1.0 - _gura_v_w)   # as poses especiais assumem o corpo todo (exceto mira Z no _gun_w!)

	var ground_w := (1.0 - _air_w) * (1.0 - _climb_w)
	var loco_w: float = ground_w * smoothstep(0.05, 0.35, speed01) * upper_free
	var idle_w: float = ground_w * (1.0 - smoothstep(0.05, 0.25, speed01)) * upper_free

	# ---- fase da marcha: DERIVADA DA PASSADA -> zero deslize ----
	# Enquanto um pé está no chão, ele tem que andar para trás EXATAMENTE na
	# velocidade do corpo. Cada perna fica em apoio metade do ciclo, e nessa
	# metade o corpo avança uma passada. Logo:
	#   T_ciclo = 2·passada / velocidade   ->   ω = π · velocidade / passada
	# (Usar 2π aqui, como eu tinha feito, deixa a cadência DOBRADA e o pé patina.)
	# A cadência passa a sair da geometria — perna curta dá passo mais rápido —
	# em vez de um fator mágico.
	var leg: float = maxf(_m.get("leg_len", 0.8), 0.3)
	var passada: float = _passada(speed01, is_sprinting)

	if climbing:
		_phase += 6.5 * delta
	elif parkour == "wall_run":
		_phase += maxf(planar, 3.5) * delta * (STRIDE_GAIN / leg)   # pernas correndo na parede
	elif on_floor and planar > 0.15:
		_phase += cadencia(planar, speed01, is_sprinting) * delta

	# ---- acumula offsets de rotação por junta ----
	var off: Dictionary = {}
	_idle(off, idle_w * (1.0 - _charge_w))
	_climb(off, _climb_w, _phase)
	_locomotion(off, loco_w, _phase, speed01, is_sprinting)
	_air(off, _air_w * upper_free, velocity.y)
	_parkour(off, _phase)
	_finger_gun(off, _gun_w, pitch, gun_recoil)
	_hibashira_pose(off, _hibashira_w)
	_kurouzu_pose(off, _kurouzu_w)
	_black_hole_pose(off, _black_hole_w)
	_gura_rush_pose(off, _gura_rush_w) # Pose assimétrica sobreposta
	_gura_x_charge_pose(off, _gura_x_charge_w)
	_gura_v_poses(off, _gura_v_w, _gura_v_state)
	_charge(off, _charge_w, charge_slot)
	
	# Se não estiver em charge, mas tem charge_slot = "C" (Gatling firing) -> aplica shake no torso.
	# NUNCA durante a pose de pistola (aim_gun), senão sacode a mira.
	if not charging and charge_slot == "C" and not aim_gun:
		_add(off, "Torso", Vector3(randf_range(-0.06, 0.06), randf_range(-0.1, 0.1), randf_range(-0.05, 0.05)))
		_add(off, "Head", Vector3(0, 0, 0)) # estabiliza
		
	_recovery(off, delta)
	_lookat(off, pitch, ground_w * (1.0 - _charge_w))

	# ---- aplica rotação (lerp suave) ----
	var a: float = 1.0 - exp(-STIFFNESS * delta)
	for role in _n:
		var target: Vector3 = _rest.get(role, Vector3.ZERO) + off.get(role, Vector3.ZERO)
		var node: Node3D = _n[role]
		node.rotation = node.rotation.lerp(target, a)

	# ---- bob do torso (oscilação vertical) ----
	if _n.has("Torso"):
		var bob := 0.0
		bob += 0.010 * sin(_t * 2.2) * idle_w
		bob += 0.05 * sin(2.0 * _phase) * _climb_w   # puxada vertical da escalada (2 por ciclo)
		# QUADRIL SEGUE OS PÉS. O sobe/desce da caminhada não vem de fórmula: é
		# MEDIDO na pose que de fato saiu (já filtrada pela rigidez) e ajustado
		# para o pé mais baixo encostar sempre na mesma altura. Calcular por
		# fórmula não fecha — o filtro atenua ângulo e altura de formas
		# diferentes, e sobra o pé flutuando.
		# Só o idle/escalada passam pelo filtro. A parte da caminhada NÃO pode ser
		# filtrada: ela já foi medida na pose pós-filtro, e filtrar de novo
		# reintroduziria exatamente o atraso que ela existe para cancelar.
		_bob_suave = lerpf(_bob_suave, bob, a)
		var bob_final := _bob_suave
		if loco_w > 0.001:
			bob_final += _bob_dos_pes(speed01, is_sprinting) * loco_w
		(_n["Torso"] as Node3D).position = _rest_torso_pos + Vector3(0, bob_final, 0)

	# Skinnado: espelha os proxies recém-escritos nos ossos do Skeleton3D.
	if _driver:
		_driver.push()

var is_backwards: bool = false

# ---------------------------------------------------------------- geradores ---
func _add(off: Dictionary, role: String, v: Vector3) -> void:
	if is_backwards:
		v.x = -v.x
		v.z = -v.z
	if _n.has(role):
		off[role] = off.get(role, Vector3.ZERO) + v

# IDLE — parado, mas PRONTO. Não é repouso neutro: é a postura de quem está
# esperando briga, que é o que a referência de One Piece pede.
#
# Três frequências diferentes de propósito (0,55 / 0,9 / 1,7 Hz). Se respiração,
# balanço e cabeça compartilham o mesmo período, o corpo pulsa inteiro no mesmo
# compasso e lê como boneco de mola. Períodos primos entre si nunca repetem o
# mesmo instante e o parado fica "vivo".
func _idle(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	var resp := sin(_t * 1.7)               # respiração (mais rápida)
	var peso := sin(_t * 0.55)              # troca de peso de uma perna p/ outra
	var giro := sin(_t * 0.9 + 1.0)         # deriva lenta do olhar

	# tronco: peito sobe na inspiração, e o corpo pende p/ o lado que aguenta o peso
	_add(off, "Torso", Vector3(-0.015 - 0.012 * resp, 0.03 * giro, 0.035 * peso) * w)
	_add(off, "Neck", Vector3(0.01 * resp, 0, -0.02 * peso) * w)
	# cabeça contra o giro do tronco (olhar fica firme) e varre devagar
	_add(off, "Head", Vector3(0.02 * resp, 0.09 * giro - 0.03 * giro, 0) * w)

	# pernas: uma sustenta, a outra relaxa — o joelho de apoio estica um pouco
	_add(off, "Thigh_L", Vector3(0.02 * peso, 0, 0.02 * peso) * w)
	_add(off, "Thigh_R", Vector3(-0.02 * peso, 0, 0.02 * peso) * w)
	_add(off, "Shin_L", Vector3(-0.05 - 0.03 * maxf(peso, 0.0), 0, 0) * w)
	_add(off, "Shin_R", Vector3(-0.05 - 0.03 * maxf(-peso, 0.0), 0, 0) * w)

	# braços soltos, um pouco à frente e afastados: guarda baixa, não em posição
	# de sentido. O `_gun_w` tira o balanço quando a pistola está erguida.
	var arm_w: float = w * (1.0 - _gun_w)
	var arm_r_w: float = arm_w * (1.0 - _gura_rush_w) # Isola o braço direito da animação normal
	_add(off, "UpperArm_L", Vector3(0.10 + 0.05 * resp, 0, 0.13) * arm_w)
	_add(off, "UpperArm_R", Vector3(0.10 - 0.05 * resp, 0, -0.13) * arm_r_w)
	_add(off, "ForeArm_L", Vector3(0.34 + 0.05 * peso, 0, 0.10) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.34 - 0.05 * peso, 0, -0.10) * arm_r_w)
	_add(off, "Torso", Vector3(0.04 + 0.02 * resp, 0, 0) * w)

func _locomotion(off: Dictionary, w: float, phase: float, speed01: float, is_sprinting: bool) -> void:
	if w <= 0.001:
		return

	# Amplitudes calibradas contra movimento humano real (em radianos).
	# ATENÇÃO ao mexer: o braço parte do repouso PENDURADO (−90° de elevação), então
	# A_arm é o quanto ele sobe. A_arm=1.55 punha o braço quase na HORIZONTAL andando
	# (elevação −21°) — era o bug do "andando com os braços para cima".
	# Referência: caminhada ~20° de braço; corrida ~45°. As PERNAS não têm amplitude
	# aqui — elas vêm da IK em _perna_ik(), que resolve a partir do alvo do pé.
	var t: float = clampf(speed01, 0.0, 1.0)
	var A_arm   := lerpf(0.15, 0.40, t)
	# Inclinação do tronco p/ FRENTE.
	var lean    := lerpf(0.02, 0.08, t)

	if is_sprinting:
		A_arm *= 2.0
		lean += 0.18

	var sL := sin(phase)
	var sR := sin(phase + PI)

	# PERNAS por IK, não por balanço solto. Antes as duas coxas oscilavam com o
	# mesmo padrão de joelho, então no cruzamento do ciclo as DUAS ficavam
	# dobradas e o corpo afundava — o personagem parecia quicar em vez de pisar.
	# Agora cada pé recebe um ALVO: no apoio ele fica na altura do chão (o corpo
	# passa por cima dele), e na balanço levanta num arco.
	# `lean` entra porque as coxas são FILHAS do torso: sem devolver a inclinação,
	# a perna herda o tombo do tronco e o pé plantado sobe/desce junto.
	_perna_ik(off, "Thigh_L", "Shin_L", "Foot_L", phase, speed01, is_sprinting, w, lean)
	_perna_ik(off, "Thigh_R", "Shin_R", "Foot_R", phase + PI, speed01, is_sprinting, w, lean)

	# Braços SOLTOS, OPOSTOS às pernas (não balançam com pistola erguida, _gun_w).
	# COSSENO, não seno: a perna agora vem da IK, cuja posição à frente é máxima
	# em fase 0 (rampa linear de +passada/2 a −passada/2). Com seno o braço ficava
	# 90° fora de fase — nem oposto nem junto, só estranho.
	var cL := cos(phase)
	var cR := cos(phase + PI)
	var arm_out: float = lerpf(0.09, 0.15, t)   # afasta do corpo; muito abre "asa de galinha"
	var sL_lag := cos(phase - 0.6)   # atraso -> sensação de braço "solto"
	var sR_lag := cos(phase + PI - 0.6)
	var arm_w: float = w * (1.0 - _gun_w)
	var arm_r_w: float = arm_w * (1.0 - _gura_rush_w) # Isola o braço direito
	_add(off, "UpperArm_L", Vector3(-A_arm * cL, 0, 0.08 + arm_out) * arm_w)
	_add(off, "UpperArm_R", Vector3(-A_arm * cR, 0, -0.08 - arm_out) * arm_r_w)
	# Cotovelo: dobra um pouco mais quando o braço vem à frente (não fica esticado).
	var A_elbow: float = lerpf(0.10, 0.25, t) * (2.0 if is_sprinting else 1.0)
	_add(off, "ForeArm_L", Vector3(0.18 + A_elbow * maxf(sL_lag, 0.0), 0, 0.08) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.18 + A_elbow * maxf(sR_lag, 0.0), 0, -0.08) * arm_r_w)

	# Torso inclina p/ FRENTE (-Z) + BALANÇO DOS OMBROS: giro no eixo Y (ombros gingam
	# opostos ao passo) e leve rolamento no Z. rot.x+ joga o topo p/ +Z (trás), logo a
	# inclinação p/ frente é NEGATIVA. Amplitude do giro sobe com a velocidade.
	var shoulder: float = lerpf(0.07, 0.15, t) * (1.6 if is_sprinting else 1.0)
	_add(off, "Torso", Vector3(-lean, shoulder * sin(phase), 0.05 * sin(phase)) * w)
	# QUADRIL contra-rotaciona os ombros — é isso que dá sensação de peso e de
	# impulso. O rig não tem osso de pelve, então o giro entra nas duas coxas,
	# no sentido oposto ao do torso.
	var quadril: float = shoulder * 0.55
	_add(off, "Thigh_L", Vector3(0, -quadril * sin(phase), 0) * w)
	_add(off, "Thigh_R", Vector3(0, -quadril * sin(phase), 0) * w)
	# Cabeça compensa a inclinação do tronco (senão o personagem corre olhando pro
	# chão) e estabiliza o giro dos ombros. 0.75 = quase nivelada, mas ainda
	# sobra um resto pra frente, que lê como "determinado".
	_add(off, "Head", Vector3(lean * 0.75, -shoulder * 0.4 * sin(phase), 0) * w)

# Altura do quadril acima do chão. Agacha com a velocidade (corrida é mais baixa).
func _altura_quadril(speed01: float, sprint: bool) -> float:
	var perna: float = _perna_len()
	if sprint:
		return perna * H_SPRINT
	return perna * lerpf(H_PARADO, H_CORRIDA, clampf(speed01, 0.0, 1.0))

func _perna_len() -> float:
	return maxf(_m.get("thigh_len", 0.30), 0.05) + maxf(_m.get("shin_len", 0.30), 0.05)

# Passada = quanto o pé viaja de frente a trás num ciclo. É a MESMA conta usada
# pela cadência (em update) e pela IK — se as duas discordarem, o pé desliza.
# Velocidade angular da marcha (rad/s). FONTE ÚNICA — o teste chama esta mesma
# função. Já teve uma cópia da fórmula no teste, e ela ficou para trás quando o
# freio de cadência entrou: os números continuavam mostrando o estado antigo.
func cadencia(planar: float, speed01: float, sprint: bool) -> float:
	var p: float = _passada(speed01, sprint)
	return minf(PI * planar / p * CADENCIA_ESCALA, CADENCIA_MAX)

# Deslize PREVISTO do pé no apoio, em fração da velocidade do corpo (0 = cravado).
# É o MODELO, não a medição: ignora o que o filtro de rigidez faz com a amplitude
# (com ciclo curto ele come passada e o deslize real fica maior). O teste mede o
# deslize na pose que saiu e usa esta função só para comparar as duas coisas.
func deslize(planar: float, speed01: float, sprint: bool) -> float:
	if planar < 0.01:
		return 0.0
	var v_pe: float = _passada(speed01, sprint) / PI * cadencia(planar, speed01, sprint)
	return absf(v_pe - planar) / planar

func _passada(speed01: float, sprint: bool) -> float:
	var perna: float = _perna_len()
	var p: float = perna * lerpf(0.45, 0.95, clampf(speed01, 0.0, 1.0)) * PASSADA_GANHO
	if sprint:
		p *= 1.25
	# TETO GEOMÉTRICO: com o quadril a H do chão, o pé só alcança
	# sqrt(alcance² − H²) para a frente. Pedir mais satura a IK e o pé sobe.
	var H: float = _altura_quadril(speed01, sprint)
	var alcance: float = perna * 0.98
	var meia_max: float = sqrt(maxf(alcance * alcance - H * H, 0.0))
	return maxf(minf(p, meia_max * 2.0), 0.05)

# Sobe/desce do quadril ao longo do ciclo. O corpo está MAIS ALTO no meio de cada
# apoio (perna esticada por baixo) e mais baixo no duplo apoio — duas subidas por
# ciclo. É o "vault" que dá peso à caminhada, e a spec pede esse movimento
# vertical do tronco. Vai somado tanto no torso quanto no alvo do pé, senão o pé
# plantado subiria junto com o corpo.
func _vault(speed01: float, sprint: bool) -> float:
	var amp: float = _perna_len() * lerpf(0.012, 0.030, clampf(speed01, 0.0, 1.0))
	if sprint:
		amp *= 1.35
	return amp * (0.5 - 0.5 * cos(2.0 * _phase))

# Quanto o quadril precisa subir para o pé MAIS BAIXO encostar sempre na mesma
# altura. Lê as rotações que realmente ficaram nas juntas (depois do filtro de
# rigidez), então é exato por construção: seja qual for o atraso do filtro, o
# porte do personagem ou a velocidade, o pé de apoio não flutua.
func _bob_dos_pes(speed01: float, sprint: bool) -> float:
	if not (_n.has("Torso") and _n.has("Thigh_L") and _n.has("Shin_L")):
		return 0.0
	var L1: float = maxf(_m.get("thigh_len", 0.30), 0.05)
	var L2: float = maxf(_m.get("shin_len", 0.30), 0.05)
	var tronco: float = (_n["Torso"] as Node3D).rotation.x
	var mais_baixo := 0.0
	var achou := false
	for lado in ["L", "R"]:
		if not (_n.has("Thigh_" + lado) and _n.has("Shin_" + lado)):
			continue
		# ângulo da coxa no espaço do PERSONAGEM (a coxa carrega +lean, o torso −lean)
		var ac: float = (_n["Thigh_" + lado] as Node3D).rotation.x + tronco
		var aj: float = ac + (_n["Shin_" + lado] as Node3D).rotation.x
		var y: float = -(L1 * cos(ac) + L2 * cos(aj))
		if not achou or y < mais_baixo:
			mais_baixo = y
			achou = true
	if not achou:
		return 0.0
	# O pé de apoio deve ficar sempre a _altura_quadril abaixo do quadril de
	# repouso; o que sobrar vira subida do corpo.
	return -_altura_quadril(speed01, sprint) - mais_baixo

# IK de duas juntas para uma perna, no plano sagital (frente/trás).
#
# Recebe o pé como ALVO e resolve coxa+joelho, em vez de girar as juntas às
# cegas. É isso que faz o pé PLANTAR: durante o apoio o alvo fica na altura do
# chão, então o joelho estica ou dobra sozinho para o corpo passar por cima do
# pé — o "vault" que dá peso à caminhada.
#
# Convenção do rig: o membro pende em -Y e girar +X leva o pé para -Z (frente).
# Com o joelho dobrando PARA TRÁS (como o humano), o ângulo do joelho é NEGATIVO.
func _perna_ik(off: Dictionary, papel_coxa: String, papel_canela: String,
		papel_pe: String, fase: float, speed01: float, sprint: bool, w: float,
		lean: float = 0.0) -> void:
	if w <= 0.001:
		return
	var L1: float = maxf(_m.get("thigh_len", 0.30), 0.05)
	var L2: float = maxf(_m.get("shin_len", 0.30), 0.05)
	var perna := L1 + L2

	var H: float = _altura_quadril(speed01, sprint)
	var passada: float = _passada(speed01, sprint)
	var levanta: float = perna * lerpf(0.10, 0.22, clampf(speed01, 0.0, 1.0))

	# Alvo do pé em relação ao quadril.
	# APOIO (meia volta): trajetória LINEAR de +passada/2 até −passada/2. Tem que
	# ser reta — com uma senoide o pé varreria rápido no meio e devagar nas pontas,
	# e como o corpo avança a velocidade constante isso VIRA DESLIZE. Combinada
	# com ω = π·v/passada, a linear dá velocidade do pé = −v exata: pé cravado.
	# BALANÇO: volta à frente com entrada/saída suaves e levantando num arco.
	var ciclo: float = fposmod(fase, TAU)
	var apoio: bool = ciclo < PI
	var frente: float
	var sobe := 0.0
	if apoio:
		frente = (passada * 0.5) * (1.0 - 2.0 * (ciclo / PI))
	else:
		var u: float = (ciclo - PI) / PI            # 0 -> 1
		frente = -passada * 0.5 + passada * (1.0 - cos(PI * u)) * 0.5
		sobe = sin(PI * u) * levanta
	# O corpo sobe no meio do apoio; o pé plantado NÃO pode subir junto, então a
	# distância quadril->pé cresce na mesma medida.
	var h: float = maxf(H + _vault(speed01, sprint) - sobe, perna * 0.30)

	# --- IK analítica de 2 elos ---
	var d: float = clampf(sqrt(h * h + frente * frente), absf(L1 - L2) + 0.001, perna - 0.001)
	var cos_j: float = clampf((d * d - L1 * L1 - L2 * L2) / (2.0 * L1 * L2), -1.0, 1.0)
	var joelho: float = -acos(cos_j)              # negativo = dobra p/ trás
	var coxa: float = atan2(frente, h) - atan2(L2 * sin(joelho), L1 + L2 * cos(joelho))

	# +lean devolve a inclinação que a perna herdou do torso, para a IK resolver
	# num plano de fato vertical.
	var coxa_final: float = coxa + lean
	_add(off, papel_coxa, Vector3(coxa_final, 0, 0) * w)
	_add(off, papel_canela, Vector3(joelho, 0, 0) * w)

	# PÉ: no apoio fica PLANO no chão (cancela as duas juntas, exatamente — é o
	# "pé toca completamente o chão" da spec). No balanço, ponta levantada para
	# não raspar e para atacar o solo de calcanhar.
	var pe_ang: float = -(coxa_final + joelho)
	if not apoio:
		pe_ang += 0.30 * maxf(0.0, -sin(fase))
	_add(off, papel_pe, Vector3(pe_ang, 0, 0) * w)

func _air(off: Dictionary, w: float, vy: float) -> void:
	if w <= 0.001:
		return
	var rising := vy > 0.0
	if rising:
		_add(off, "Thigh_L", Vector3(0.7, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.7, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-1.1, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.1, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.4, 0, 0.2) * w)
		_add(off, "UpperArm_R", Vector3(-1.4, 0, -0.2) * w)
	else:
		_add(off, "Thigh_L", Vector3(0.25, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.25, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.3, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.3, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.2, 0, 0.5) * w)
		_add(off, "UpperArm_R", Vector3(0.2, 0, -0.5) * w)

func _climb(off: Dictionary, w: float, phase: float) -> void:
	# ESCALADA hand-over-hand REFEITA: coordenação CONTRALATERAL (mão de um lado sobe
	# junto com o joelho do lado OPOSTO), com PESO — pausa nos extremos (agarra firme /
	# puxa forte), transferência de peso no tronco e follow-through do cotovelo.
	# Um ciclo completo (0..2PI) = duas braçadas (uma de cada braço).
	if w <= 0.001:
		return
	var s := sin(phase)
	# Timing com DWELL nos extremos: em vez de swing senoidal constante, segura o
	# agarre no topo e a puxada embaixo (smoothstep concentra o tempo nas pontas).
	var reach_l: float = smoothstep(-0.85, 0.85, s)     # 0=puxando(baixo) .. 1=agarrando(alto)
	var reach_r: float = 1.0 - reach_l
	var knee_l := reach_r                                # contralateral
	var knee_r := reach_l
	# Follow-through: o antebraço atrasa ~meia fase em relação ao ombro (2ário orgânico).
	var lag_l: float = smoothstep(-0.85, 0.85, sin(phase - 0.7))
	var lag_r: float = 1.0 - lag_l

	# --- BRAÇOS: alcançam BEM alto ao agarrar; dobram e PUXAM forte ao descer ---
	# UpperArm x muito negativo = braço estendido pra cima (agarre alto); z abre o cotovelo.
	_add(off, "UpperArm_L", Vector3(lerpf(-0.9, -3.0, reach_l), 0.0, lerpf(0.42, 0.06, reach_l)) * w)
	_add(off, "UpperArm_R", Vector3(lerpf(-0.9, -3.0, reach_r), 0.0, -lerpf(0.42, 0.06, reach_r)) * w)
	# ForeArm: reto no topo (mão agarra), flexiona profundo na puxada — com follow-through.
	_add(off, "ForeArm_L", Vector3(lerpf(1.75, 0.02, lag_l), 0.0, 0.05) * w)
	_add(off, "ForeArm_R", Vector3(lerpf(1.75, 0.02, lag_r), 0.0, -0.05) * w)

	# --- PERNAS: joelho sobe a um apoio novo e depois ESTENDE empurrando o corpo ---
	_add(off, "Thigh_L", Vector3(lerpf(0.05, 1.78, knee_l), 0.0, 0.12) * w)
	_add(off, "Thigh_R", Vector3(lerpf(0.05, 1.78, knee_r), 0.0, -0.12) * w)
	_add(off, "Shin_L", Vector3(lerpf(-0.10, -1.7, knee_l), 0.0, 0.0) * w)
	_add(off, "Shin_R", Vector3(lerpf(-0.10, -1.7, knee_r), 0.0, 0.0) * w)
	# Pé aponta pra dentro da parede quando o joelho dobra (busca o apoio).
	_add(off, "Foot_L", Vector3(lerpf(0.10, 0.65, knee_l), 0.0, 0.0) * w)
	_add(off, "Foot_R", Vector3(lerpf(0.10, 0.65, knee_r), 0.0, 0.0) * w)

	# --- TRONCO/CABEÇA: cola na parede + TRANSFERÊNCIA DE PESO (torção+rolagem) ---
	# pitch pequeno p/ dentro; twist(Y) e roll(Z) seguem o lado que puxa dando swing ao corpo.
	_add(off, "Torso", Vector3(0.08, 0.20 * s, 0.11 * s) * w)
	_add(off, "Head", Vector3(-0.34, -0.16 * s, 0.0) * w)   # olha pra cima acompanhando as mãos

# Poses de PARKOUR (aditivas, ver pesos _wallrun_w/_roll_w/_ljump_w).
func _parkour(off: Dictionary, phase: float) -> void:
	# WALL RUN (#3): corrida intensa inclinada — pernas/braços bombando, tronco à frente.
	if _wallrun_w > 0.001:
		var w := _wallrun_w
		var s := sin(phase * 1.5)
		_add(off, "Thigh_L", Vector3(1.1 * s, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(-1.1 * s, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.9 * clampf(s, 0.0, 1.0), 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.9 * clampf(-s, 0.0, 1.0), 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.5 * s, 0, 0.25) * w)
		_add(off, "UpperArm_R", Vector3(1.5 * s, 0, -0.25) * w)
		_add(off, "ForeArm_L", Vector3(0.9, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(0.9, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.4, 0, 0) * w)    # inclina forte p/ frente (-x = frente)
		_add(off, "Head", Vector3(0.25, 0, 0) * w)     # cabeça estabiliza, olhando à frente
	# ROLL do POUSO (#4): encolhe — joelhos ao peito, tronco dobrado, braços recolhidos.
	if _roll_w > 0.001:
		var w := _roll_w
		_add(off, "Thigh_L", Vector3(1.4, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(1.4, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-1.7, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.7, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.9, 0, 0) * w)    # dobra bem p/ frente
		_add(off, "Head", Vector3(0.45, 0, 0) * w)     # queixo ao peito
		_add(off, "UpperArm_L", Vector3(-0.8, 0, 0.6) * w)
		_add(off, "UpperArm_R", Vector3(-0.8, 0, -0.6) * w)
		_add(off, "ForeArm_L", Vector3(1.6, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(1.6, 0, 0) * w)
	# SALTO LONGO / VAULT (#1,#2): corpo estendido no ar — braços à frente, pernas atrás.
	if _ljump_w > 0.001:
		var w := _ljump_w
		_add(off, "UpperArm_L", Vector3(-2.4, 0, 0.2) * w)
		_add(off, "UpperArm_R", Vector3(-2.4, 0, -0.2) * w)
		_add(off, "ForeArm_L", Vector3(0.1, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(0.1, 0, 0) * w)
		_add(off, "Thigh_L", Vector3(-0.5, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(-0.5, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.2, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.2, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.35, 0, 0) * w)   # corpo mais horizontal (mergulho)

# DEDO-REVÓLVER (rajada Z mera/hie): braço direito ESTICADO à frente mirando como
# uma pistola; o modelo já vira p/ o alvo no yaw, então o -Z do braço aponta no alvo.
# gun_recoil (1->0 por tiro) dá o COICE: braço pula pra cima e o tronco recua.
func _finger_gun(off: Dictionary, w: float, pitch: float, gun_recoil: float) -> void:
	if w <= 0.001:
		return
	# x POSITIVO (~+1.5 = ~90°) estende o braço pra FRENTE (-Z); pitch inclina o cano
	# p/ cima/baixo. (x negativo puxaria pra TRÁS, como o _charge faz — era o bug.)
	var aim_x := 1.5 + clampf(pitch, -1.2, 1.2) * 0.9
	var kick := gun_recoil * 0.5                         # coice do disparo (muzzle sobe)
	# AMBOS os braços estendidos à frente (akimbo) mirando as duas pistolas; cotovelos
	# quase retos (canos) e ombros à frente com o coice.
	_add(off, "UpperArm_R", Vector3(aim_x + kick, 0.0, -0.14) * w)
	_add(off, "ForeArm_R", Vector3(0.05, 0.0, 0.0) * w)
	_add(off, "UpperArm_L", Vector3(aim_x + kick, 0.0, 0.14) * w)
	_add(off, "ForeArm_L", Vector3(0.05, 0.0, 0.0) * w)
	# APENAS os braços empunhando as armas ficam fixos à frente! As pernas e o corpo ficam livres!
	_add(off, "Head", Vector3(0.0, -pitch * 0.5, 0.0) * w)

# Pose Especial Assimétrica: Gura Gura Z Rush (Apenas o braço direito reage)
func _gura_rush_pose(off: Dictionary, w: float) -> void:
	if w <= 0.001: return
	
	# Torso inclinado para frente e um pouco torcido para dar o "balanço do corpo"
	_add(off, "Torso", Vector3(0.3, -0.2, 0) * w)
	
	# Braço direito socando/investindo para a frente (-Z = X positivo)
	# e levemente aberto para a direita (+X = Z positivo)
	_add(off, "UpperArm_R", Vector3(1.4, 0.1, 0.3) * w)
	
	# Cotovelo com leve flexão (ForeArm_R X = 0.5) para quebrar a rigidez total
	_add(off, "ForeArm_R", Vector3(-0.4, 0.0, -0.2) * w)
	
	_add(off, "Head", Vector3(-0.1, 0.2, 0) * w)

# Pose Especial de Carregamento: Gura Gura X (Captura Sísmica)
func _gura_x_charge_pose(off: Dictionary, w: float) -> void:
	if w <= 0.001: return
	# Braço direito estendido diretamente na direção da mira para capturar o alvo,
	# X = 1.5 aponta perfeitamente para frente (-Z).
	var vib_y = sin(_t * 30.0) * 0.02
	var vib_z = cos(_t * 35.0) * 0.02
	_add(off, "UpperArm_R", Vector3(1.5 + vib_y, vib_y, 0.1 + vib_z) * w)
	_add(off, "ForeArm_R", Vector3(-0.1 + vib_y, 0.0, 0.0) * w)
	_add(off, "Torso", Vector3(0.1, 0.0, 0.0) * w)
	_add(off, "Head", Vector3(0.1, 0.0, 0.0) * w)

# --- Poses da Ultimate V da Gura Gura (Sequência de 4s) ---
func _gura_v_poses(off: Dictionary, w: float, state: String) -> void:
	if w <= 0.001: return
	
	if state == "gura_v_prep":
		# Preparação (0.0s): Postura firme, respira fundo
		var resp = sin(_t * 3.0) * 0.05
		_add(off, "Torso", Vector3(0.1 - resp, 0, 0) * w)
		_add(off, "Head", Vector3(-0.1 + resp, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.2, 0.0, 0.1) * w)
		_add(off, "UpperArm_R", Vector3(0.2, 0.0, -0.1) * w)
		
	elif state == "gura_v_squat":
		# Agachamento (1.0s): Flexiona joelhos, braços pra trás
		_add(off, "Thigh_L", Vector3(0.8, 0.1, 0) * w)
		_add(off, "Thigh_R", Vector3(0.8, -0.1, 0) * w)
		_add(off, "Shin_L", Vector3(-1.0, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.0, 0, 0) * w)
		_add(off, "Torso", Vector3(0.3, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.2, 0.0, 0.2) * w)
		_add(off, "UpperArm_R", Vector3(-1.2, 0.0, -0.2) * w)
		
	elif state == "gura_v_gather":
		# Reúne energia (2.0s): Agachado vibrando fortemente
		var vib = sin(_t * 45.0) * 0.03
		_add(off, "Thigh_L", Vector3(0.9, 0.1, 0) * w)
		_add(off, "Thigh_R", Vector3(0.9, -0.1, 0) * w)
		_add(off, "Shin_L", Vector3(-1.1, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.1, 0, 0) * w)
		_add(off, "Torso", Vector3(0.4 + vib, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.3, 0.0, 0.3 + vib) * w)
		_add(off, "UpperArm_R", Vector3(-1.3, 0.0, -0.3 - vib) * w)
		_add(off, "ForeArm_L", Vector3(0.5, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(0.5, 0, 0) * w)
		
	elif state == "gura_v_lift":
		# Levanta os braços (3.0s): Braços sobem lentamente
		var vib = sin(_t * 30.0) * 0.02
		_add(off, "Torso", Vector3(0.0, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.0, 0.2, 0.8 + vib) * w)
		_add(off, "UpperArm_R", Vector3(0.0, -0.2, -0.8 - vib) * w)
		
	elif state == "gura_v_tpose":
		# Pose em T (4.0s): Braços totalmente horizontais, vibração máxima
		var vib = sin(_t * 50.0) * 0.05
		_add(off, "Torso", Vector3(-0.1, 0, 0) * w)
		_add(off, "Head", Vector3(0.1, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.0, 0.0, 1.4 + vib) * w)
		_add(off, "UpperArm_R", Vector3(0.0, 0.0, -1.4 - vib) * w)
		_add(off, "ForeArm_L", Vector3(-0.1, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(-0.1, 0, 0) * w)

func _lookat(off: Dictionary, pitch: float, w: float) -> void:
	if w <= 0.001:
		return
	_add(off, "Head", Vector3(clampf(-pitch * 0.6, -0.5, 0.5), 0, 0) * w)

# Pose de CHARGE (estilingue):
# - Z (Pistol): braço direito puxado p/ trás+cima, cotovelo dobrado, tronco em leve torção/recuo (tensão).
# - X (Bazooka): dois braços simultaneamente para trás, peito avança, cotovelos flexionam levemente.
func _charge(off: Dictionary, w: float, slot: String) -> void:
	if w <= 0.001:
		return
	if slot == "X":
		_add(off, "UpperArm_R", Vector3(-1.8, 0, -0.4) * w)   
		_add(off, "ForeArm_R", Vector3(1.6, 0, 0) * w)          
		_add(off, "UpperArm_L", Vector3(-1.8, 0, 0.4) * w)     
		_add(off, "ForeArm_L", Vector3(1.6, 0, 0) * w)         
		_add(off, "Torso", Vector3(0.2, 0, 0) * w)            
		_add(off, "Head", Vector3(-0.15, 0, 0) * w)
	elif slot == "C":
		# Gatling Charge: postura agressiva, joelhos flexionados, braços recuados e tensionados, tronco inclinado
		_add(off, "Thigh_L", Vector3(0.4, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.4, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.6, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.6, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.25, 0, 0) * w)
		_add(off, "UpperArm_R", Vector3(-1.4, 0, -0.2) * w)
		_add(off, "ForeArm_R", Vector3(1.7, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.4, 0, 0.2) * w)
		_add(off, "ForeArm_L", Vector3(1.7, 0, 0) * w)
		_add(off, "Head", Vector3(0.25, 0, 0) * w)
	elif slot == "V":
		# Red Hawk Charge: Postura agressiva extrema, braço direito puxado para trás
		_add(off, "Thigh_L", Vector3(0.5, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.5, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.7, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.7, 0, 0) * w)
		_add(off, "Torso", Vector3(0.1, -0.4, 0) * w)
		_add(off, "UpperArm_R", Vector3(-1.9, 0, -0.5) * w)
		_add(off, "ForeArm_R", Vector3(1.8, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.4, 0, 0.3) * w)
		_add(off, "Head", Vector3(0.1, 0.4, 0) * w)
	else:
		_add(off, "UpperArm_R", Vector3(-1.7, 0, -0.35) * w)   
		_add(off, "ForeArm_R", Vector3(1.5, 0, 0) * w)          
		_add(off, "UpperArm_L", Vector3(0.35, 0, 0.15) * w)     
		_add(off, "Torso", Vector3(0.06, -0.32, 0) * w)         
		_add(off, "Head", Vector3(0, 0.26, 0) * w)              

var _recovery_slot := "Z"
# Dispara o tranco elástico de RECEPÇÃO (chicote) quando o punho volta ao corpo.
func trigger_recovery(slot: String = "Z") -> void:
	_recovery_t = REC_DUR
	_recovery_slot = slot

# Recepção: solavanco decaindo — ombro, tronco p/ frente, saltinho dos pés e chicote.
func _recovery(off: Dictionary, delta: float) -> void:
	if _recovery_t <= 0.0:
		return
	_recovery_t = maxf(_recovery_t - delta, 0.0)
	var k := _recovery_t / REC_DUR                 # 1 -> 0
	var whip := sin((1.0 - k) * PI * 2.5) * k      # oscila e decai (chicote)
	var pull := absf(whip)
	
	if _recovery_slot == "X":
		_add(off, "Torso", Vector3(-0.85 * whip, 0, 0))   # tranco muito maior p/ frente
		_add(off, "UpperArm_R", Vector3(-1.9 * whip, 0, -0.2)) # ambos solavancos violentos
		_add(off, "UpperArm_L", Vector3(-1.9 * whip, 0, 0.2))  
		_add(off, "ForeArm_R", Vector3(1.4 * pull, 0, 0))
		_add(off, "ForeArm_L", Vector3(1.4 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.85 * pull, 0, 0))             
		_add(off, "Thigh_R", Vector3(0.85 * pull, 0, 0))
		_add(off, "Head", Vector3(-0.35 * whip, 0, 0))
	elif _recovery_slot == "C":
		_add(off, "Torso", Vector3(-0.45 * whip, 0, 0.1 * whip))
		_add(off, "UpperArm_R", Vector3(-1.2 * whip, 0, 0))
		_add(off, "UpperArm_L", Vector3(-1.2 * whip, 0, 0))
		_add(off, "ForeArm_R", Vector3(0.7 * pull, 0, 0))
		_add(off, "ForeArm_L", Vector3(0.7 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.3 * pull, 0, 0))
		_add(off, "Thigh_R", Vector3(0.3 * pull, 0, 0))
	elif _recovery_slot == "V":
		# Red Hawk Recovery: Ajoelhado após o impacto massivo
		# T = 1 -> 0. Puxa forte p/ baixo, levanta no final.
		_add(off, "Thigh_L", Vector3(1.2 * k, 0, 0))
		_add(off, "Thigh_R", Vector3(1.2 * k, 0, 0))
		_add(off, "Shin_L", Vector3(-1.5 * k, 0, 0))
		_add(off, "Shin_R", Vector3(-1.5 * k, 0, 0))
		_add(off, "Torso", Vector3(0.4 * k, 0, 0))
		_add(off, "UpperArm_R", Vector3(0.5 * k, 0, -0.3 * k))
		_add(off, "Head", Vector3(-0.2 * k, 0, 0))
	else:
		_add(off, "Torso", Vector3(-0.55 * whip, 0, 0.12 * whip))   
		_add(off, "UpperArm_R", Vector3(-1.5 * whip, 0, 0))          
		_add(off, "ForeArm_R", Vector3(0.9 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.55 * pull, 0, 0))             
		_add(off, "Thigh_R", Vector3(0.55 * pull, 0, 0))
		_add(off, "Head", Vector3(-0.22 * whip, 0, 0))

# POSE DE ENTRADA DO HIBASHIRA (Mera Mera C): Soca o chão no centro e abre as pernas numa
# postura de firmeza de combate (power stance), permanecendo em imobilidade imune e imponente.
func _hibashira_pose(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	# Base de combate: pernas bem abertas lateralmente e joelhos flexionados firmes na terra.
	_add(off, "Thigh_L", Vector3(0.5, 0.0, 0.45) * w)
	_add(off, "Thigh_R", Vector3(0.5, 0.0, -0.45) * w)
	_add(off, "Shin_L", Vector3(-0.85, 0.0, 0.0) * w)
	_add(off, "Shin_R", Vector3(-0.85, 0.0, 0.0) * w)
	_add(off, "Foot_L", Vector3(0.35, 0.0, -0.2) * w)
	_add(off, "Foot_R", Vector3(0.35, 0.0, 0.2) * w)
	# Tronco dobrado profundamente para frente em direção ao centro da erupção de chamas.
	_add(off, "Torso", Vector3(-0.85, 0.25, 0.1) * w)
	# Cabeça erguida com olhar feroz à frente (superando a inclinação do tronco).
	_add(off, "Head", Vector3(0.65, -0.2, 0.0) * w)
	# Braço Direito socando o chão à frente/centro (punho cravado na erupção).
	_add(off, "UpperArm_R", Vector3(-1.1, -0.3, -0.35) * w)
	_add(off, "ForeArm_R", Vector3(0.15, 0.0, 0.0) * w)
	# Braço Esquerdo flexionado para trás em equilíbrio dinâmico de chamas.
	_add(off, "UpperArm_L", Vector3(0.6, 0.0, 0.5) * w)
	_add(off, "ForeArm_L", Vector3(1.1, 0.0, 0.0) * w)

# POSE DE ESPIRAL NEGRA / KUROUZU (Yami Yami X): Levanta o braço direito diretamente à frente
# para atrair e segurar a vítima firmemente no ar pela força da gravidade abissal.
func _kurouzu_pose(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	_add(off, "UpperArm_R", Vector3(1.55, 0.0, -0.2) * w)
	_add(off, "ForeArm_R", Vector3(0.05, 0.0, 0.0) * w)
	_add(off, "Torso", Vector3(-0.15, -0.25, 0.0) * w)
	_add(off, "Thigh_L", Vector3(0.35, 0.0, 0.2) * w)
	_add(off, "Thigh_R", Vector3(-0.25, 0.0, -0.2) * w)
	_add(off, "Shin_L", Vector3(-0.4, 0.0, 0.0) * w)

# POSE DO BARBA NEGRA / BLACK HOLE (Yami Yami C): Pernas afastadas em base firme e uma
# mão para baixo direcionada ao solo gerando o pântano de trevas.
func _black_hole_pose(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	_add(off, "Thigh_L", Vector3(0.4, 0.0, 0.45) * w)
	_add(off, "Thigh_R", Vector3(0.4, 0.0, -0.45) * w)
	_add(off, "Shin_L", Vector3(-0.65, 0.0, 0.0) * w)
	_add(off, "Shin_R", Vector3(-0.65, 0.0, 0.0) * w)
	_add(off, "Torso", Vector3(-0.6, 0.3, 0.1) * w)
	_add(off, "Head", Vector3(0.45, -0.25, 0.0) * w)
	_add(off, "UpperArm_R", Vector3(-0.9, -0.2, -0.4) * w)
	_add(off, "ForeArm_R", Vector3(0.2, 0.0, 0.0) * w)
	_add(off, "UpperArm_L", Vector3(0.4, 0.0, 0.4) * w)
