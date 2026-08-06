class_name ProceduralAnimator
extends Node
# Animação PROCEDURAL em tempo real do rig articulado (nós, não skinado).
# Lê o estado do Player (velocidade, corrida/shift, no chão, escalando, pitch da mira) e gera
# idle / walk / sprint-run / jump-fall / climb em runtime.

const SPEED_REF := 4.2     # SPEED do Player (para normalizar 0..1)
const STIFFNESS := 16.0    # rigidez do lerp (resposta fluida e ágil)
# Passadas por metro percorrido (cadência ligada à DISTÂNCIA, não ao tempo).
# Menor = animação de walk/run mais lenta e calma; maior = passos mais curtos/rápidos.
const STRIDE_GAIN := 1.0

var _n: Dictionary = {}     # papel -> Node3D
var _rest: Dictionary = {}  # papel -> Vector3 (rotação de descanso)
var _m: Dictionary = {}     # métricas do corpo
var _rest_torso_pos := Vector3.ZERO

var _phase := 0.0
var _air_w := 0.0
var _climb_w := 0.0
var _charge_w := 0.0        # peso da pose de "estilingue" (segurando a skill)
var _wallrun_w := 0.0       # parkour: corrida na parede (#3)
var _roll_w := 0.0          # parkour: rolamento do pouso de precisão (#4)
var _ljump_w := 0.0         # parkour: salto longo / vault no ar (#1, #2)
var _gun_w := 0.0           # rajada Z (mera/hie): pose de dedo-revólver mirando
var _hibashira_w := 0.0     # pose de entrada e sustentação do Hibashira (soca o chão, pernas abertas)
var _kurouzu_w := 0.0       # pose de atração do Kurouzu (braço à frente)
var _black_hole_w := 0.0    # pose do Barba Negra no Black Hole (pernas abertas, mão pro chão)
var _recovery_t := 0.0      # timer do tranco elástico de recepção (chicote)
var _t := 0.0

# Clipe BAKED (ex.: Mixamo retargetado): dirige os nós por role, sobrepondo a
# animação procedural enquanto toca. Cada faixa tem path "<Role>:rotation".
var _baked: Animation = null
var _baked_t := 0.0

# Presente só em personagens SKINNADOS: espelha os proxies nos ossos.
var _driver: SkeletonDriver = null

const REC_DUR := 0.35       # duração da recepção (recovery)

# Toca um clipe retargetado (Animation com faixas <Role>:rotation) por cima do rig.
func play_baked(anim: Animation) -> void:
	_baked = anim
	_baked_t = 0.0

func is_playing_baked() -> bool:
	return _baked != null

func _apply_baked(delta: float) -> void:
	_baked_t += delta
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
	var parkour_w: float = maxf(_wallrun_w, maxf(_roll_w, _ljump_w))
	var upper_free: float = (1.0 - parkour_w) * (1.0 - _hibashira_w) * (1.0 - _kurouzu_w) * (1.0 - _black_hole_w)   # as poses especiais assumem o corpo todo (exceto mira Z no _gun_w!)

	var ground_w := (1.0 - _air_w) * (1.0 - _climb_w)
	var loco_w: float = ground_w * smoothstep(0.05, 0.35, speed01) * upper_free
	var idle_w: float = ground_w * (1.0 - smoothstep(0.05, 0.25, speed01)) * upper_free

	# ---- fase da marcha: LIGADA À DISTÂNCIA percorrida (não ao tempo) ----
	# O pé acompanha o chão -> acaba o deslize/moonwalk, e a cadência acelera junto
	# com a velocidade real (andar x correr no Shift) sem número mágico de frequência.
	var leg: float = maxf(_m.get("leg_len", 0.8), 0.3)

	if climbing:
		_phase += 6.5 * delta
	elif parkour == "wall_run":
		_phase += maxf(planar, 3.5) * delta * (STRIDE_GAIN / leg)   # pernas correndo na parede
	elif on_floor and planar > 0.15:
		_phase += planar * delta * (STRIDE_GAIN / leg)

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
		var bob_mult := 1.6 if is_sprinting else 1.0
		bob += 0.010 * sin(_t * 2.2) * idle_w
		bob += 0.06 * bob_mult * (0.5 - 0.5 * cos(2.0 * _phase)) * loco_w
		bob += 0.05 * sin(2.0 * _phase) * _climb_w   # puxada vertical da escalada (2 por ciclo)
		(_n["Torso"] as Node3D).position = _rest_torso_pos + Vector3(0, bob, 0)

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

func _idle(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	var s := sin(_t * 0.9)
	var s2 := sin(_t * 0.7 + 1.0)
	_add(off, "Torso", Vector3(0, 0.02 * s2, 0) * w)
	_add(off, "Head",  Vector3(0.03 * sin(_t * 0.6), 0.05 * s2, 0) * w)
	var arm_w: float = w * (1.0 - _gun_w)
	_add(off, "UpperArm_L", Vector3(0.06 * s, 0, 0.05) * arm_w)
	_add(off, "UpperArm_R", Vector3(-0.06 * s, 0, -0.05) * arm_w)
	_add(off, "ForeArm_L", Vector3(0.10, 0, 0) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.10, 0, 0) * arm_w)

func _locomotion(off: Dictionary, w: float, phase: float, speed01: float, is_sprinting: bool) -> void:
	if w <= 0.001:
		return

	# Amplitudes calibradas contra movimento humano real (em radianos).
	# ATENÇÃO ao mexer: o braço parte do repouso PENDURADO (−90° de elevação), então
	# A_arm é o quanto ele sobe. A_arm=1.55 punha o braço quase na HORIZONTAL andando
	# (elevação −21°) — era o bug do "andando com os braços para cima".
	# Referência: caminhada ~20° de braço e ~25° de coxa; corrida ~45° e ~40°.
	var t: float = clampf(speed01, 0.0, 1.0)
	var A_thigh := lerpf(0.18, 0.44, t)   # coxa:  10° -> 25°
	var A_knee  := lerpf(0.25, 0.85, t)   # joelho: 14° -> 49°
	var A_arm   := lerpf(0.12, 0.35, t)   # braço:   7° -> 20°
	# Inclinação do tronco p/ FRENTE. Não é realismo puro — é leitura: sem ela o
	# personagem anda "de pé reto" e parece deslizar em vez de se impulsionar.
	# O corpo tem que apontar pra onde vai.
	var lean    := lerpf(0.05, 0.17, t)   # tronco:  3° -> 10°

	if is_sprinting:
		A_thigh *= 1.55   # -> 39°
		A_knee *= 1.50    # -> 73°
		A_arm *= 2.20     # -> 44°
		lean += 0.16      # -> 19°  (corrida joga o peito à frente)

	var sL := sin(phase)
	var sR := sin(phase + PI)

	# Pernas balançam opostas; joelho dobra para trás na passada
	_add(off, "Thigh_L", Vector3(A_thigh * sL, 0, 0) * w)
	_add(off, "Thigh_R", Vector3(A_thigh * sR, 0, 0) * w)
	_add(off, "Shin_L", Vector3(-A_knee * clampf(sin(phase + 1.9), 0, 1), 0, 0) * w)
	_add(off, "Shin_R", Vector3(-A_knee * clampf(sin(phase + PI + 1.9), 0, 1), 0, 0) * w)
	_add(off, "Foot_L", Vector3(-(A_thigh * sL) * 0.5, 0, 0) * w)
	_add(off, "Foot_R", Vector3(-(A_thigh * sR) * 0.5, 0, 0) * w)

	# Braços SOLTOS, opostos às pernas (não balançam quando atirando com pistola em _gun_w!)
	var arm_out: float = lerpf(0.09, 0.15, t)   # afasta do corpo; muito abre "asa de galinha"
	var sL_lag := sin(phase - 0.6)   # atraso -> sensação de braço "solto"
	var sR_lag := sin(phase + PI - 0.6)
	var arm_w: float = w * (1.0 - _gun_w)
	_add(off, "UpperArm_L", Vector3(-A_arm * sL, 0, 0.08 + arm_out) * arm_w)
	_add(off, "UpperArm_R", Vector3(-A_arm * sR, 0, -0.08 - arm_out) * arm_w)
	# Cotovelo: dobra um pouco mais quando o braço vem à frente (não fica esticado).
	var A_elbow: float = lerpf(0.16, 0.34, t) * (1.6 if is_sprinting else 1.0)
	_add(off, "ForeArm_L", Vector3(0.18 + A_elbow * maxf(sL_lag, 0.0), 0, 0.08) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.18 + A_elbow * maxf(sR_lag, 0.0), 0, -0.08) * arm_w)

	# Torso inclina p/ FRENTE (-Z) + BALANÇO DOS OMBROS: giro no eixo Y (ombros gingam
	# opostos ao passo) e leve rolamento no Z. rot.x+ joga o topo p/ +Z (trás), logo a
	# inclinação p/ frente é NEGATIVA. Amplitude do giro sobe com a velocidade.
	var shoulder: float = lerpf(0.05, 0.11, t)
	_add(off, "Torso", Vector3(-lean, shoulder * sin(phase), 0.05 * sin(phase)) * w)
	# Cabeça compensa a inclinação do tronco (senão o personagem corre olhando pro
	# chão) e estabiliza o giro dos ombros. 0.75 = quase nivelada, mas ainda
	# sobra um resto pra frente, que lê como "determinado".
	_add(off, "Head", Vector3(lean * 0.75, -shoulder * 0.4 * sin(phase), 0) * w)

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
	_add(off, "Torso", Vector3(-0.05 - gun_recoil * 0.1, -0.02, 0.0) * w)
	_add(off, "Head", Vector3(clampf(-pitch * 0.5, -0.5, 0.5), -0.02, 0.0) * w)

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
