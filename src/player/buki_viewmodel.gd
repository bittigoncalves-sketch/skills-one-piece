class_name BukiViewmodel
extends Node3D
# ============================================================================
#  ARMA NA FRENTE DA TELA (FPS da Buki Buki, 22/11/2026)
#
#  Em 1ª pessoa o corpo some — e as armas da Buki moram no antebraço dele. Aqui
#  nasce uma CÓPIA da arma, pendurada na câmera do dono, com coice. Só existe no
#  dono do corpo (o adversário continua vendo a arma no braço do modelo).
#  Eixos: as peças de `BukiFX.arma_do_slot` nascem giradas para a mão do rig
#  (cano em −Y); aqui o cano é levado para −Z da câmera.
# ============================================================================

# slot -> onde a BOCA do cano fica na câmera (`pos`) e o comprimento visível da arma (`len`, em m). O corpo da arma se estende
# da boca para trás (+Z). Tamanho e centro são AUTO-AJUSTADOS pela caixa da peça: nada de número por tentativa e erro.
const POSE := {
	"Z": {"pos": Vector3(0.15, -0.15, -0.62), "len": 0.26},
	"C": {"pos": Vector3(0.17, -0.16, -1.00), "len": 0.80},
	"V": {"pos": Vector3(0.21, -0.21, -0.95), "len": 0.48},
	"X": {"pos": Vector3(0.0, -0.34, -1.40), "len": 1.10},
}
var _slot := ""
var _arma: Node3D = null
var _coice := 0.0

func mostrar(slot: String) -> void:
	esconder()
	if not POSE.has(slot):
		return
	var a := BukiFX.arma_do_slot(slot)
	if a == null:
		return
	var p: Dictionary = POSE[slot]
	# Zera a pose de "mão do rig" e leva o cano para −Z.
	a.rotation = Vector3.ZERO
	a.position = Vector3.ZERO
	a.scale = Vector3.ONE
	if slot == "Z":
		a.rotation_degrees.x = 90.0
	_desligar_sombras(a)
	var caixa := _caixa(a, Transform3D.IDENTITY)
	var s := float(p["len"]) / maxf(caixa.size.z, 0.001)
	var c := caixa.get_center()
	a.scale = Vector3.ONE * s
	# boca (z mínimo da caixa) em z=0; centro em x/y = 0
	a.position = Vector3(-c.x * s, -c.y * s, -caixa.position.z * s)
	add_child(a)
	position = p["pos"]
	_arma = a
	_slot = slot
	visible = true

# Caixa da peça no espaço do pai (acumula as transformações dos filhos).
static func _caixa(n: Node3D, acima: Transform3D) -> AABB:
	var t := acima * n.transform
	var r := AABB()
	var tem := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		r = t * (n as MeshInstance3D).mesh.get_aabb()
		tem = true
	for f in n.get_children():
		if f is Node3D:
			var cf := _caixa(f as Node3D, t)
			if cf.size != Vector3.ZERO:
				r = cf if not tem else r.merge(cf)
				tem = true
	return r

func esconder() -> void:
	if _arma != null and is_instance_valid(_arma):
		_arma.queue_free()
	_arma = null
	_slot = ""
	visible = false

func ativo() -> bool:
	return _arma != null and visible

# Luneta da sniper: a arma sai da frente da lente.
func luneta(sim: bool) -> void:
	if _arma != null:
		visible = not sim

func coice(forca: float = 1.0) -> void:
	_coice = clampf(_coice + forca, 0.0, 1.5)

# Ponto do mundo da boca do cano (origem das balas e do fogacho em 1ª pessoa).
func boca() -> Vector3:
	return global_position

func _process(delta: float) -> void:
	if _arma == null:
		return
	_coice = maxf(_coice - delta * 8.0, 0.0)
	var p: Vector3 = POSE[_slot]["pos"]
	position = p + Vector3(0, 0, _coice * 0.07)
	rotation_degrees.x = _coice * 4.0

static func _desligar_sombras(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_desligar_sombras(c)
