class_name WeaponPoses
extends RefCounted
# ============================================================================
#  POSES DE ARMAS (Weapons)
#
#  Segrega as poses procedurais de armas das poses de Akuma no Mi para manter o 
#  Princípio de Responsabilidade Única (SRP) e evitar que módulos inchem.
# ============================================================================

static func two_handed_sword_idle(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	
	# Tronco levemente rotacionado para alinhar os ombros com a espada à frente
	add.call(off, "Torso", Vector3(0.05, -0.1, 0.0) * w)
	add.call(off, "Head", Vector3(-0.05, 0.1, 0.0) * w)
	
	# Pernas abertas em V (Base Firme de Combate)
	add.call(off, "Thigh_R", Vector3(0.0, 0.4, 0.2) * w)
	add.call(off, "Thigh_L", Vector3(0.0, -0.4, -0.2) * w)
	
	# Braço Direito (mão principal no punho/hilt) estendido à frente, levemente dobrado
	add.call(off, "UpperArm_R", Vector3(0.7, -0.1, 0.1) * w)
	add.call(off, "ForeArm_R", Vector3(0.1, 0.0, 0.0) * w)
	
	# Braço Esquerdo (segunda mão no pomo/base da espada) cruza o corpo para alcançar o cabo
	add.call(off, "UpperArm_L", Vector3(0.8, 0.5, 0.4) * w)
	add.call(off, "ForeArm_L", Vector3(0.2, 0.2, 0.0) * w)

static func ease_in_cubic(x: float) -> float:
	return x * x * x

static func ease_out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)

static func ease_out_elastic(x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	var c4 = (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0

static func _get_slash_frame(t: float) -> float:
	if t < 0.2:
		var preparo = clampf(t / 0.2, 0.0, 1.0)
		return lerpf(0.0, -0.4, ease_in_cubic(preparo)) # puxa pra trás
	elif t < 0.26:
		var golpe = clampf((t - 0.2) / 0.06, 0.0, 1.0)
		return lerpf(-0.4, 1.0, ease_out_expo(golpe)) # joga pra frente rápido
	else:
		var recuo = clampf((t - 0.26) / 0.74, 0.0, 1.0)
		return lerpf(1.0, 0.0, ease_out_elastic(recuo)) # volta pro repouso com bounce

static func two_handed_sword_slash(add: Callable, off: Dictionary, w: float, t: float, type: int) -> void:
	if w <= 0.001:
		return
	
	# Progresso do golpe usando delays para criar Cadeia Cinética (Chicote)
	# Delays aumentados para enfatizar a "fluidez" (os braços e a arma vêm BEM depois do corpo)
	var frame_torso = _get_slash_frame(t)
	var frame_upper = _get_slash_frame(clampf(t - 0.05, 0.0, 1.0))
	var frame_fore  = _get_slash_frame(clampf(t - 0.10, 0.0, 1.0))
	
	# Pernas flexionam e abrem mais durante o golpe para criar momento de base
	add.call(off, "Thigh_R", Vector3(0.2, 0.5, 0.3) * absf(frame_torso) * w)
	add.call(off, "Thigh_L", Vector3(0.2, -0.5, -0.3) * absf(frame_torso) * w)

	# Como as duas mãos seguram a mesma espada, o ForeArm_L e UpperArm_L seguem o direito
	match type:
		0: # Corte Direita para Esquerda (Over-extension extremo p/ fluidez)
			add.call(off, "Torso", Vector3(0.4, -0.9, 0.2) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.2, -0.4, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(1.6, -1.0, 0.5) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.6, 0.6, 0.0) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(1.6, 0.5, 1.0) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.6, 0.8, 0.0) * frame_fore * w)
		1: # Corte Esquerda para Direita
			add.call(off, "Torso", Vector3(0.4, 1.0, -0.2) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.2, 0.5, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(1.4, 1.4, -0.9) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.6, 0.0, -0.6) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(1.4, 1.4, 0.3) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.6, 0.4, -0.3) * frame_fore * w)
		2: # Corte Vertical (Cima para Baixo)
			add.call(off, "Torso", Vector3(0.8, 0.0, 0.0) * frame_torso * w)
			add.call(off, "Head", Vector3(0.3, 0.0, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(2.4, 0.0, 0.0) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(1.0, 0.0, 0.0) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(2.4, 0.6, 0.5) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(1.0, 0.3, 0.0) * frame_fore * w)

