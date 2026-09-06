class_name PikaPoses
extends RefCounted
## Poses autorais dos ataques de luz da Pika Pika.
##
## O C ergue os dois braços e sustenta a barragem. O V ergue somente o braço
## direito para ativar o céu. As poses são aditivas e usam os mesmos papéis de
## rig que GuraPoses/FruitPoses, funcionando em personagens voxel e skinnados.

const C_YASAKANI := "pika_c_yasakani"
const V_ATIVACAO := "pika_v_ativacao"
const GOLPES := [C_YASAKANI, V_ATIVACAO]


static func e_golpe(nome: String) -> bool:
	return GOLPES.has(nome)


static func golpe(add: Callable, off: Dictionary, w: float, t: float,
		fase: float, estado: String) -> void:
	if w <= 0.001:
		return
	match estado:
		C_YASAKANI: _yasakani(add, off, w, t, fase)
		V_ATIVACAO: _chuva(add, off, w, t, fase)


static func _yasakani(add: Callable, off: Dictionary, w: float, t: float,
		fase: float) -> void:
	# 0,0–0,6: ambos os braços sobem. 0,6–2,7: sustentação com vibração curta,
	# sem transformar o personagem numa hélice durante a rajada.
	var k := _suave(clampf(fase / 0.60, 0.0, 1.0))
	var sustenta := 1.0 - _suave(clampf((fase - 2.70) / 0.60, 0.0, 1.0))
	var peso := k * sustenta * w
	add.call(off, "Torso", Vector3(-0.10, 0.0, 0.0) * peso)
	add.call(off, "Head", Vector3(0.14, 0.0, 0.0) * peso)
	add.call(off, "UpperArm_L", Vector3(0.35, 0.0, -2.20) * peso)
	add.call(off, "UpperArm_R", Vector3(0.35, 0.0, 2.20) * peso)
	add.call(off, "ForeArm_L", Vector3(0.18, 0.0, 0.0) * peso)
	add.call(off, "ForeArm_R", Vector3(0.18, 0.0, 0.0) * peso)
	add.call(off, "Thigh_L", Vector3(0.0, 0.0, -0.32) * peso)
	add.call(off, "Thigh_R", Vector3(0.0, 0.0, 0.32) * peso)
	add.call(off, "Shin_L", Vector3(-0.28, 0.0, 0.0) * peso)
	add.call(off, "Shin_R", Vector3(-0.28, 0.0, 0.0) * peso)
	if fase >= 1.0 and fase <= 2.5:
		var pulso := sin(t * 42.0) * 0.035 * peso
		add.call(off, "UpperArm_L", Vector3(pulso, 0.0, -pulso) * w)
		add.call(off, "UpperArm_R", Vector3(-pulso, 0.0, pulso) * w)
		add.call(off, "Torso", Vector3(pulso * 0.5, 0.0, 0.0) * w)


static func _chuva(add: Callable, off: Dictionary, w: float, t: float,
		fase: float) -> void:
	# Ativação de 2 s: o braço direito aponta para o céu; o esquerdo estabiliza.
	var k := _suave(clampf(fase / 0.65, 0.0, 1.0))
	var peso := k * w
	add.call(off, "Torso", Vector3(0.05, -0.08, 0.0) * peso)
	add.call(off, "Head", Vector3(0.24, 0.0, 0.0) * peso)
	add.call(off, "UpperArm_R", Vector3(0.22, 0.0, 2.62) * peso)
	add.call(off, "ForeArm_R", Vector3(-0.08, 0.0, 0.0) * peso)
	add.call(off, "UpperArm_L", Vector3(0.18, 0.0, -0.30) * peso)
	add.call(off, "ForeArm_L", Vector3(0.45, 0.0, 0.0) * peso)
	add.call(off, "Thigh_L", Vector3(0.0, 0.0, -0.36) * peso)
	add.call(off, "Thigh_R", Vector3(0.0, 0.0, 0.36) * peso)
	add.call(off, "Shin_L", Vector3(-0.32, 0.0, 0.0) * peso)
	add.call(off, "Shin_R", Vector3(-0.32, 0.0, 0.0) * peso)
	var pulso := sin(t * 18.0) * 0.018 * peso
	add.call(off, "UpperArm_R", Vector3(pulso, 0.0, pulso) * w)


static func _suave(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

