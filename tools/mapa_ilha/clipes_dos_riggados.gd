extends SceneTree
# ============================================================================
#  CLIPES QUE FALTAM NOS ANIMAIS QUE JÁ VIERAM COM OSSOS — gerados no Godot (02/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/clipes_dos_riggados.gd [-- <ids>]
#
#  Decisão do dono (docs/ANIMACOES_ANIMAIS_CHECKPOINT.md, etapa 5): os clipes que faltam
#  (damage, attack, death) são gerados AQUI, porque reexportar esses modelos pelo Blender
#  os vira de cabeça para baixo (conversão de eixos do Sketchfab num nó-junta). O .glb
#  original não é tocado: os clipes novos vão para `mapas/modelos/<id>.clipes.res` (uma
#  AnimationLibrary) e a loja a acopla ao instanciar (`BibliotecaDeModelos.instanciar`).
#
#  Cada clipe = POSES SOMADAS a um quadro do clipe-base do bicho (o idle): rotações nos
#  eixos do MODELO (X lado, Y cima, Z frente — o jogo anda para +Z) em volta da cabeça do
#  osso já posada, propagadas aos filhos e convertidas para o espaço do esqueleto (que nos
#  modelos do Sketchfab é girado e em escala 0,01). A morte assenta no chão pela malha
#  deformada (skinning na CPU). O tempo do golpe vai para a ficha (`golpe_em`).
# ============================================================================

const FPS := 30.0

## papel -> nomes dos ossos no glTF (sem o sufixo numérico; ver `_osso`).
const MODELOS := {
	"monkey_-_animated_low_poly": {
		"base": "monkey_idleA", "ataque": "tapa",
		"ossos": {"raiz": ["Spine_00"], "coluna": ["Spine.001", "Spine.002"], "pescoco": ["neck.001"], "cabeca": ["Head"],
			"braco.L": ["Arm01_L", "Arm02_L"], "braco.R": ["Arm01_R", "Arm02_R"],
			"perna.L": ["Foot_L", "Foot_L.001"], "perna.R": ["Foot_R", "Foot_R.001"],
			"cauda": ["tail.000", "tail.001", "tail.002", "tail.003"]}},
	"sheep_-_animated_low_poly": {
		"base": "idle", "ataque": "cabecada",
		# Rig ACHATADO (todos filhos de center_ctrl): a cadeia é só para propagar os deltas.
		"pais": {"chest": "spine", "neck": "chest", "head": "neck", "uparm_L": "shoulder_L", "arm_L": "uparm_L",
			"hand_L": "arm_L", "uparm_R": "shoulder_R", "arm_R": "uparm_R", "hand_R": "arm_R", "leg_L": "thigh_L",
			"foot_L": "leg_L", "toe_L": "foot_L", "leg_R": "thigh_R", "foot_R": "leg_R", "toe_R": "foot_R"},
		"ossos": {"raiz": ["center_ctrl"], "coluna": ["spine", "chest"], "pescoco": ["neck"], "cabeca": ["head"],
			"braco.L": ["uparm_L", "arm_L"], "braco.R": ["uparm_R", "arm_R"],
			"perna.L": ["thigh_L", "leg_L"], "perna.R": ["thigh_R", "leg_R"], "cauda": ["tail"]}},
	"pelican_-_animated_low_poly": {
		"base": "pelican_idle_A", "ataque": "bicada",
		"ossos": {"raiz": ["Center"], "coluna": ["Spine.001", "Spine.002", "Spine.003"],
			"pescoco": ["Neck.001", "Neck.002", "Neck.003", "Neck.004", "Neck.005", "Neck.006", "Neck.007"],
			"cabeca": ["Head"], "asa.L": ["Shoulder02_L", "Shoulder03_L"], "asa.R": ["Shoulder02_R", "Shoulder03_R"],
			"perna.L": ["Foot_01_L", "Foot_02_L"], "perna.R": ["Foot_01_R", "Foot_02_R"], "cauda": ["tail.001", "tail.002"]}},
	"gorilla_-_animated_low_poly": {
		"base": "Gorilla_idle", "ataque": "socar_chao",
		"ossos": {"raiz": ["root.x"], "coluna": ["spine_01.x", "spine_02.x"], "pescoco": ["neck.x"], "cabeca": ["head.x"],
			"braco.L": ["arm_stretch.l", "forearm_stretch.l"], "braco.R": ["arm_stretch.r", "forearm_stretch.r"],
			"perna.L": ["thigh_stretch.l", "leg_stretch.l"], "perna.R": ["thigh_stretch.r", "leg_stretch.r"]}},
	"eagle_-_animated_low_poly": {
		"base": "fly", "ataque": "garras", "voa": true,
		"ossos": {"raiz": ["root.x"], "coluna": ["spine_01.x", "spine_02.x"], "pescoco": ["neck.x"], "cabeca": ["head.x"],
			"asa.L": ["arm_stretch.l", "forearm_stretch.l"], "asa.R": ["arm_stretch.r", "forearm_stretch.r"],
			"perna.L": ["thigh_stretch.l", "leg_stretch.l"], "perna.R": ["thigh_stretch.r", "leg_stretch.r"],
			"cauda": ["c_tail_00.x", "c_tail_01.x"]}},
	"harpia_-_animated_low_poly": {
		"base": "fly", "ataque": "garras", "voa": true,
		"ossos": {"raiz": ["root.x"], "coluna": ["spine_01.x", "spine_02.x"], "pescoco": ["neck.x"], "cabeca": ["head.x"],
			"asa.L": ["arm_stretch.l", "forearm_stretch.l"], "asa.R": ["arm_stretch.r", "forearm_stretch.r"],
			"perna.L": ["thigh_stretch.l", "leg_stretch.l"], "perna.R": ["thigh_stretch.r", "leg_stretch.r"],
			"cauda": ["c_tail_00.x", "c_tail_01.x"]}},
}
const ESTILOS := {"tapa": [0.7, 0.33], "cabecada": [0.9, 0.42], "bicada": [0.6, 0.3], "socar_chao": [1.0, 0.5], "garras": [0.9, 0.45]}

var _sk: Skeleton3D
var _modelo: Node3D
var _para_esq: Transform3D        # esqueleto -> modelo
var _ordem: Array[int] = []
var _pai_virtual := {}            # osso -> osso de quem herda os deltas (rig achatado)
var _base_local: Array[Transform3D] = []
var _base_global: Array[Transform3D] = []
var _tam := 1.0


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var pedidos := Array(OS.get_cmdline_user_args())
	var ids: Array = pedidos if not pedidos.is_empty() else MODELOS.keys()
	var erros := 0
	for id: String in ids:
		var r := _processar(bib, id)
		if not r.is_empty():
			push_error("%s: %s" % [id, r])
			erros += 1
	print("CLIPES_DOS_RIGGADOS %d modelos, erros=%d" % [ids.size(), erros])
	quit(1 if erros else 0)


func _processar(bib: BibliotecaDeModelos, id: String) -> String:
	var cfg: Dictionary = MODELOS[id]
	var cena := BibliotecaDeModelos.carregar_glb(bib.caminho_do_arquivo(id))
	if cena == null:
		return "não carregou"
	root.add_child(cena)
	_modelo = cena
	_sk = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap := cena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var base := AnimadorDeAnimal._clipe_por_chave(ap.get_animation_list(), String(cfg["base"]).to_lower())
	if base.is_empty():
		return "sem clipe-base " + cfg["base"]
	ap.play(base)
	ap.seek(0.0, true)
	ap.advance(0.0)
	_para_esq = cena.global_transform.affine_inverse() * _sk.global_transform
	_pai_virtual.clear()
	for filho in cfg.get("pais", {}):
		_pai_virtual[_osso(filho)] = _osso(cfg["pais"][filho])
	_ordem = _ordem_dos_ossos()
	_base_local.clear()
	_base_global.clear()
	_base_local.resize(_sk.get_bone_count())
	_base_global.resize(_sk.get_bone_count())
	for i in _ordem:
		_base_local[i] = _sk.get_bone_pose(i)
		var pai := _sk.get_bone_parent(i)
		_base_global[i] = (_base_global[pai] if pai >= 0 else Transform3D.IDENTITY) * _base_local[i]
	var caixa: AABB = BibliotecaDeModelos.medir(cena)["aabb"]
	_tam = maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
	var o := {}
	for papel in cfg["ossos"]:
		var lista: Array[int] = []
		for n in cfg["ossos"][papel]:
			var i := _osso(n)
			if i < 0:
				return "osso %s não existe" % n
			lista.append(i)
		o[papel] = lista
	var chao := _menor_y(_poses({}, {}))
	var lib := AnimationLibrary.new()
	var caminho_ap := ap.get_node(ap.root_node).get_path_to(_sk)
	lib.add_animation("damage", _gravar(_dano(o, cfg), 0.5, caminho_ap))
	var estilo: Array = ESTILOS[cfg["ataque"]]
	lib.add_animation("attack", _gravar(_ataque(o, cfg, estilo[0]), estilo[0], caminho_ap))
	var morte := _morte(o, cfg)
	_assentar(morte, o["raiz"][0], chao, int(0.85 * FPS))
	lib.add_animation("death", _gravar(morte, 1.4, caminho_ap))
	var destino := bib.raiz.path_join(id + ".clipes.res")
	var erro := ResourceSaver.save(lib, destino)
	cena.queue_free()
	if erro != OK:
		return "não gravou %s (%s)" % [destino, error_string(erro)]
	var ficha := bib.ficha_de_animal(id)
	if not ficha.is_empty():
		ficha["golpe_em"] = float(estilo[1])
		bib.definir_ficha_de_animal(id, ficha)
	print("CLIPES %s: base %s, damage/attack(%s, golpe %.2f s)/death -> %s" % [id, base, cfg["ataque"], estilo[1], destino])
	return ""


# ------------------------------------------------------------------- poses
## Pais antes dos filhos — o pai de verdade E o virtual (rig achatado).
func _ordem_dos_ossos() -> Array[int]:
	var out: Array[int] = []
	var feito := {}
	var pendentes := range(_sk.get_bone_count())
	while not pendentes.is_empty():
		var resto := []
		for i in pendentes:
			var pai := _sk.get_bone_parent(i)
			var virtual: int = _pai_virtual.get(i, -1)
			if (pai < 0 or feito.has(pai)) and (virtual < 0 or feito.has(virtual)):
				out.append(i)
				feito[i] = true
			else:
				resto.append(i)
		if resto.size() == pendentes.size():
			push_error("hierarquia virtual em ciclo")
			break
		pendentes = resto
	return out


## O osso pelo nome do glTF, aceitando o sufixo numérico que o modelo traz (Spine.001_014).
func _osso(nome: String) -> int:
	var i := _sk.find_bone(nome)
	if i >= 0:
		return i
	var re := RegEx.create_from_string("^" + _escapar(nome) + "_\\d+$")
	for j in _sk.get_bone_count():
		if re.search(_sk.get_bone_name(j)) != null:
			return j
	return -1


static func _escapar(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if ".()[]{}+*?^$|\\".contains(c) else c
	return out


## pitch + baixa o focinho, yaw + vira para a esquerda (+X), roll + deita sobre +X.
static func rot(pitch := 0.0, yaw := 0.0, roll := 0.0) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)


## Poses locais de todos os ossos: `deltas` {osso: Basis nos eixos do modelo}, `mover`
## {osso: Vector3 no espaço do modelo}.
func _poses(deltas: Dictionary, mover: Dictionary) -> Array[Transform3D]:
	var esq_basis := _para_esq.basis
	var novo: Array[Transform3D] = []
	novo.resize(_sk.get_bone_count())
	var locais: Array[Transform3D] = []
	locais.resize(_sk.get_bone_count())
	for i in _ordem:
		var pai := _sk.get_bone_parent(i)
		var herda: int = _pai_virtual.get(i, pai)
		var g := _base_global[i]
		if herda >= 0:
			g = novo[herda] * _base_global[herda].affine_inverse() * g
		if mover.has(i):
			g.origin += esq_basis.inverse() * (mover[i] as Vector3)
		if deltas.has(i):
			var d: Basis = esq_basis.inverse() * (deltas[i] as Basis) * esq_basis
			var h := g.origin
			g = Transform3D(d, h - d * h) * g
		novo[i] = g
		locais[i] = (novo[pai].affine_inverse() if pai >= 0 else Transform3D.IDENTITY) * g
	return locais


func _gravar(quadros: Array, dur: float, caminho: NodePath) -> Animation:
	var anim := Animation.new()
	anim.length = dur
	var poses: Array = []
	for q in quadros:
		poses.append(_poses(q[0], q[1]))
	for i in _sk.get_bone_count():
		var alvo := NodePath(str(caminho) + ":" + _sk.get_bone_name(i))
		var muda := false
		for p in poses:
			if not (p[i] as Transform3D).is_equal_approx(poses[0][i]):
				muda = true
				break
		var tr := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tr, alvo)
		var trr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(trr, alvo)
		var trs := anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(trs, alvo)
		var n := poses.size() if muda else 1
		for f in n:
			var t: Transform3D = poses[f][i]
			var tempo := minf(f / FPS, dur)
			anim.position_track_insert_key(tr, tempo, t.origin)
			anim.rotation_track_insert_key(trr, tempo, t.basis.get_rotation_quaternion())
			anim.scale_track_insert_key(trs, tempo, t.basis.get_scale())
	return anim


# ---------------------------------------------------------- chão (skinning na CPU)
func _menor_y(locais: Array[Transform3D]) -> float:
	var globais: Array[Transform3D] = []
	globais.resize(_sk.get_bone_count())
	for i in _ordem:
		var pai := _sk.get_bone_parent(i)
		globais[i] = (globais[pai] if pai >= 0 else Transform3D.IDENTITY) * locais[i]
	var menor := INF
	for mi: MeshInstance3D in _modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var binds: Array[Transform3D] = []
		for b in mi.skin.get_bind_count():
			var nome := mi.skin.get_bind_name(b)
			var osso_ := _sk.find_bone(nome) if not nome.is_empty() else mi.skin.get_bind_bone(b)
			binds.append(globais[maxi(osso_, 0)] * mi.skin.get_bind_pose(b))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if ossos.is_empty():
				continue
			var k := ossos.size() / vs.size()
			for v in range(0, vs.size(), 3):
				var p := Vector3.ZERO
				for j in k:
					var w := pesos[v * k + j]
					if w > 0.0:
						p += (binds[ossos[v * k + j]] * vs[v]) * w
				menor = minf(menor, (_para_esq * p).y)
	return menor


func _assentar(quadros: Array, raiz: int, chao: float, desde: int) -> void:
	for f in quadros.size():
		var q: Array = quadros[f]
		var falta := chao - _menor_y(_poses(q[0], q[1]))
		if falta > 0.0 or f >= desde:
			q[1][raiz] = (q[1].get(raiz, Vector3.ZERO) as Vector3) + Vector3.UP * falta


# ------------------------------------------------------------------ clipes
static func _suave(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _curva(t: float, pontos: Array) -> float:
	if t <= pontos[0][0]:
		return pontos[0][1]
	for i in pontos.size() - 1:
		var a: Array = pontos[i]
		var b: Array = pontos[i + 1]
		if t <= b[0]:
			return a[1] + (b[1] - a[1]) * _suave((t - a[0]) / maxf(b[0] - a[0], 1e-9))
	return pontos[-1][1]


static func _impulso(t: float) -> float:
	if t < 0.07:
		return 1.0 - pow(1.0 - t / 0.07, 2)
	return 0.5 * (1.0 + cos(PI * minf(1.0, (t - 0.07) / 0.43)))


## O mesmo delta dividido pela cadeia (o pescoço do pelicano tem 7 ossos).
static func _espalhar(d: Dictionary, ossos: Array, b: Basis) -> void:
	if ossos.is_empty():
		return
	var q := Quaternion.IDENTITY.slerp(b.get_rotation_quaternion(), 1.0 / ossos.size())
	for i in ossos:
		d[i] = Basis(q)


static func _asa(lado: String, sobe: float, recua: float) -> Basis:
	var s := 1.0 if lado == ".L" else -1.0
	# Asa esquerda (+X): girar em volta de +Z ergue a ponta; em volta de +Y leva a ponta
	# para -Z (para trás). A direita, espelhada.
	return Basis(Vector3.BACK, s * sobe) * Basis(Vector3.UP, s * recua)


func _dano(o: Dictionary, cfg: Dictionary) -> Array:
	var quadros := []
	for f in int(0.5 * FPS) + 1:
		var k := _impulso(f / FPS)
		var d := {o["raiz"][0]: rot(-deg_to_rad(8) * k, 0.0, deg_to_rad(5) * k)}
		_espalhar(d, o.get("coluna", []), rot(-deg_to_rad(6) * k))
		_espalhar(d, o.get("pescoco", []), rot(-deg_to_rad(12) * k))
		d[o["cabeca"][0]] = rot(-deg_to_rad(12) * k, deg_to_rad(8) * k)
		for lado in [".L", ".R"]:
			if o.has("braco" + lado):
				d[o["braco" + lado][0]] = rot(-deg_to_rad(18) * k)
			if o.has("asa" + lado):
				d[o["asa" + lado][0]] = _asa(lado, deg_to_rad(40) * k, deg_to_rad(15) * k)
		_espalhar(d, o.get("cauda", []), rot(deg_to_rad(10) * k))
		quadros.append([d, {o["raiz"][0]: (Vector3.BACK * -0.06 + Vector3.UP * 0.03) * _tam * k}])
	return quadros


func _ataque(o: Dictionary, cfg: Dictionary, dur: float) -> Array:
	var quadros := []
	var raiz: int = o["raiz"][0]
	for f in int(dur * FPS) + 1:
		var t := f / FPS
		var d := {}
		var mover := {}
		match cfg["ataque"]:
			"tapa":
				var arma := _curva(t, [[0, 0], [0.25, 1], [0.36, -0.6], [0.5, -0.6], [0.7, 0]])
				# Ergue o braço direito à frente e desce o tapa ainda à frente, cruzando para o meio.
				d[o["braco.R"][0]] = rot(-deg_to_rad(70) * maxf(arma, 0) - deg_to_rad(25) * maxf(-arma, 0), deg_to_rad(15) * maxf(-arma, 0))
				_espalhar(d, o["coluna"], rot(0.0, -deg_to_rad(12) * arma))
				d[o["cabeca"][0]] = rot(deg_to_rad(10) * maxf(-arma, 0))
				mover[raiz] = Vector3.BACK * 0.08 * _tam * maxf(-arma, 0)
			"cabecada":
				var recua := _curva(t, [[0, 0], [0.35, 1], [0.42, -1.6], [0.55, -1.6], [0.9, 0]])
				var cab := _curva(t, [[0, 0], [0.35, 1], [0.47, -0.6], [0.6, -0.6], [0.9, 0]])
				_espalhar(d, o["pescoco"], rot(deg_to_rad(30) * cab))
				d[o["cabeca"][0]] = rot(deg_to_rad(15) * cab)
				mover[raiz] = Vector3.BACK * -0.06 * _tam * recua + Vector3.DOWN * 0.02 * _tam * absf(recua)
			"bicada":
				var bica := _curva(t, [[0, 0], [0.22, -1], [0.3, 1], [0.4, 1], [0.6, 0]])
				_espalhar(d, o["pescoco"], rot(deg_to_rad(40) * maxf(bica, 0) - deg_to_rad(25) * maxf(-bica, 0)))
				d[o["cabeca"][0]] = rot(deg_to_rad(15) * maxf(bica, 0))
				_espalhar(d, o["coluna"], rot(deg_to_rad(10) * maxf(bica, 0)))
			"socar_chao":
				var ergue := _curva(t, [[0, 0], [0.4, 1], [0.5, -0.4], [0.65, -0.4], [1.0, 0]])
				for lado in [".L", ".R"]:
					d[o["braco" + lado][0]] = rot(-deg_to_rad(100) * maxf(ergue, 0) + deg_to_rad(25) * maxf(-ergue, 0))
				d[raiz] = rot(-deg_to_rad(18) * maxf(ergue, 0) + deg_to_rad(10) * maxf(-ergue, 0))
				d[o["cabeca"][0]] = rot(-deg_to_rad(15) * maxf(ergue, 0))
				mover[raiz] = Vector3.UP * 0.05 * _tam * maxf(ergue, 0) + Vector3.BACK * 0.06 * _tam * maxf(-ergue, 0)
			"garras":
				var ataca := _curva(t, [[0, 0], [0.3, 0.6], [0.45, 1], [0.6, 1], [0.9, 0]])
				for lado in [".L", ".R"]:
					d[o["perna" + lado][0]] = rot(-deg_to_rad(75) * ataca)
					d[o["asa" + lado][0]] = _asa(lado, deg_to_rad(45) * ataca, -deg_to_rad(10) * ataca)
				d[raiz] = rot(-deg_to_rad(30) * ataca)
				d[o["cabeca"][0]] = rot(deg_to_rad(20) * ataca)
				_espalhar(d, o.get("cauda", []), rot(deg_to_rad(20) * ataca))
		quadros.append([d, mover])
	return quadros


func _morte(o: Dictionary, cfg: Dictionary) -> Array:
	if cfg.get("voa", false):
		return _morte_voador(o)
	var quadros := []
	var raiz: int = o["raiz"][0]
	for f in int(1.4 * FPS) + 1:
		var t := f / FPS
		var cede := _curva(t, [[0, 0], [0.35, 1]])
		var tomba := _curva(t, [[0.3, 0], [0.85, 1.06], [1.05, 0.97], [1.25, 1.0]])
		var d := {raiz: rot(0.0, 0.0, deg_to_rad(85) * tomba) * rot(deg_to_rad(8) * cede * (1 - tomba))}
		_espalhar(d, o.get("pescoco", []), rot(deg_to_rad(15) * cede, deg_to_rad(25) * tomba))
		d[o["cabeca"][0]] = rot(deg_to_rad(10) * cede, deg_to_rad(15) * tomba)
		for lado in [".L", ".R"]:
			if o.has("braco" + lado):
				d[o["braco" + lado][0]] = rot(deg_to_rad(15) * tomba)
			if o.has("asa" + lado):
				d[o["asa" + lado][0]] = _asa(lado, -deg_to_rad(20) * tomba, deg_to_rad(50) * tomba)
			if o.has("perna" + lado):
				d[o["perna" + lado][0]] = rot((-deg_to_rad(20) if cfg.get("voa", false) else deg_to_rad(10)) * tomba)
		_espalhar(d, o.get("cauda", []), rot(-deg_to_rad(8) * tomba))
		quadros.append([d, {raiz: Vector3.DOWN * 0.15 * _tam * cede * (1 - tomba)}])
	return quadros


## Ave de asa grande (águia, harpia): cai de barriga, asas abertas e caídas, cabeça no chão.
## Deitada de lado ela ficava apoiada na ponta de uma asa, com a outra para o céu.
func _morte_voador(o: Dictionary) -> Array:
	var quadros := []
	var raiz: int = o["raiz"][0]
	for f in int(1.4 * FPS) + 1:
		var t := f / FPS
		var tranco := _curva(t, [[0, 0], [0.1, 1], [0.3, 0]])
		var cai := _curva(t, [[0.2, 0], [0.9, 1.0]])
		var d := {raiz: rot(deg_to_rad(18) * cai - deg_to_rad(12) * tranco, 0.0, deg_to_rad(12) * cai)}
		_espalhar(d, o.get("pescoco", []), rot(deg_to_rad(30) * cai, deg_to_rad(20) * cai))
		d[o["cabeca"][0]] = rot(deg_to_rad(15) * cai)
		for lado in [".L", ".R"]:
			d[o["asa" + lado][0]] = _asa(lado, deg_to_rad(45) * tranco - deg_to_rad(18) * cai, deg_to_rad(25) * cai)
			if o.has("perna" + lado):
				d[o["perna" + lado][0]] = rot(deg_to_rad(40) * cai)
		_espalhar(d, o.get("cauda", []), rot(-deg_to_rad(10) * cai))
		quadros.append([d, {}])
	return quadros
