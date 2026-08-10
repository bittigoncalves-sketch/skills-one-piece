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
#  ⏱️ TEMPO DO IMPACTO — medido, não estimado. `atraso` é o instante, JÁ na
#  velocidade tocada, em que o membro atinge a extensão máxima:
#
#    | clipe                       | duração | impacto | vel  | impacto tocado |
#    | right_upper_hook_from_guard | 1,77 s  | 0,67 s  | 1,9x | 0,35 s |
#    | left_uppercut_from_guard    | 1,37 s  | 0,37 s  | 1,25x| 0,30 s |
#    | kicking                     | 2,30 s  | 1,38 s  | 2,4x | 0,58 s |
#
#  (O `kicking` gasta 60% do clipe em preparação — por isso a velocidade dele é
#  a mais alta das três; sem isso o finalizador demoraria quase 1 s para tocar
#  no alvo.)
# ============================================================================

const JANELA := 2.0        # tempo pra encadear o próximo golpe (pedido do usuário)

# Cada passo do combo.
#
# `atraso` = quando a hitbox nasce dentro da animação. O golpe tem que CONECTAR
# no frame do impacto, não no frame do clique — e esses valores agora saem da
# MEDIÇÃO acima. Os anteriores eram estimados no olho e erravam para menos: o
# `punching` conecta em 0,43 s na velocidade tocada, e a hitbox nascia em 0,22 s,
# ou seja o dano saía antes do punho estender.
const COMBO := [
	{
		"nome": "Soco Direito", "anim": "right_upper_hook_from_guard", "espelhar": false, "vel": 1.9,
		"dano": 30.0, "kb": 11.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.35, "vida": 0.18, "recuo": 0.40, "shake": 0.25,
	},
	{
		"nome": "Soco Esquerdo", "anim": "left_uppercut_from_guard", "espelhar": false, "vel": 1.25,
		"dano": 34.0, "kb": 13.0, "alcance": 1.5, "raio": 1.5,
		"atraso": 0.30, "vida": 0.18, "recuo": 0.36, "shake": 0.30,
	},
	{
		# O finalizador é o que joga pra fora do mapa: mais alcance e o dobro
		# de knockback dos socos.
		"nome": "Chute", "anim": "kicking", "espelhar": false, "vel": 2.4,
		"dano": 70.0, "kb": 26.0, "alcance": 2.0, "raio": 1.9,
		"atraso": 0.58, "vida": 0.22, "recuo": 0.62, "shake": 0.6,
	},
]

static var _cache: Dictionary = {}   # "anim|espelhado" -> Animation

static func passo(i: int) -> Dictionary:
	return COMBO[clampi(i, 0, COMBO.size() - 1)]

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
	var timer := world.get_tree().create_timer(float(g["atraso"]))
	timer.timeout.connect(func():
		if not is_instance_valid(caster) or not is_instance_valid(world):
			return
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = origem + fwd * float(g["alcance"])
		# vel = 0: a hitbox do corpo a corpo fica onde nasceu; alcance é o braço,
		# não um projétil.
		zone.setup(float(g["dano"]), float(g["kb"]), Vector3.ZERO,
			float(g["vida"]), caster, float(g["raio"]))
		_impacto(world, zone.global_position, i))

# Fiapo visual do golpe: um anel achatado que abre e some no lugar do impacto.
# Curto de propósito — o corpo a corpo tem que ler pela ANIMAÇÃO, não por VFX.
static func _impacto(world: Node, pos: Vector3, i: int) -> void:
	AudioFX.whoosh(world, pos, 1.15 if i < 2 else 0.85)
	var m := MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.25
	anel.outer_radius = 0.45
	m.mesh = anel
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.8, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.5)
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
