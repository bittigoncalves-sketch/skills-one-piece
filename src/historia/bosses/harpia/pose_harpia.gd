extends SkeletonModifier3D
## Pose autoral sobre o rig original. O modifier roda APÓS o AnimationPlayer;
## não grava recursos compartilhados nem acumula rotações entre quadros.
## montar() anexa este nó ao Skeleton3D. O chamador só conserva a referência.

var _sk: Skeleton3D
var _modelo: Node3D
var _ossos: Dictionary = {}
var _globais: Array[Transform3D] = []
var _ordem: Array[int] = []
var _fase := ""
var _p := 0.0
var _inicio_recuperacao: Dictionary = {}
## Graus por junta no espaço do modelo; editáveis para ajuste de silhueta.
@export var dobra_braco := 100.0
@export var dobra_cotovelo := -155.0
@export var dobra_punho := 140.0

func montar(modelo: Node3D) -> void:
	_modelo = modelo
	var achados := modelo.find_children("*", "Skeleton3D", true, false)
	if achados.is_empty():
		push_warning("Harpia: modelo sem Skeleton3D; pose não instalada")
		return
	_sk = achados[0] as Skeleton3D
	if get_parent() == null:
		_sk.add_child(self)
	for i in _sk.get_bone_count():
		_globais.append(_sk.get_bone_global_rest(i))
		_ordem.append(i)
		var nome := String(_sk.get_bone_name(i)).to_lower()
		for chave in ["shoulder.l", "shoulder.r", "arm_stretch.l", "arm_stretch.r", "forearm_stretch.l", "forearm_stretch.r", "hand.l", "hand.r", "head", "neck", "tail"]:
			if nome.begins_with(chave) and not _ossos.has(chave):
				_ossos[chave] = i
	_ordem.sort_custom(func(a: int, b: int) -> bool: return _profundidade(a) < _profundidade(b))
	_ler_planagem()
	active = false

func _ler_planagem() -> void:
	# O bind pose do GLB tem asas ABAIXADAS. A base autoral é o clipe gliding,
	# amostrado sem tocar/parar o AnimationPlayer que pertence ao animal.
	var players := _modelo.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var ap := players[0] as AnimationPlayer
	var clipe: Animation
	for nome in ap.get_animation_list():
		if String(nome).to_lower().ends_with("gliding"):
			clipe = ap.get_animation(nome)
			break
	if clipe == null:
		return
	var locais: Array[Transform3D] = []
	for i in _sk.get_bone_count():
		locais.append(_sk.get_bone_rest(i))
	for tr in clipe.get_track_count():
		var caminho := clipe.track_get_path(tr)
		if caminho.get_subname_count() == 0:
			continue
		var i := _sk.find_bone(caminho.get_subname(0))
		if i < 0:
			continue
		match clipe.track_get_type(tr):
			Animation.TYPE_ROTATION_3D:
				locais[i].basis = Basis(clipe.rotation_track_interpolate(tr, 0.3))
			Animation.TYPE_POSITION_3D:
				locais[i].origin = clipe.position_track_interpolate(tr, 0.3)
	for i in _ordem:
		var pai := _sk.get_bone_parent(i)
		_globais[i] = (_globais[pai] if pai >= 0 else Transform3D.IDENTITY) * locais[i]

func atualizar(fase: String, p: float, _delta: float) -> void:
	if fase == "recuperar" and _fase != fase:
		# Colisão pode encerrar a investida cedo. Partir do gesto efetivo evita
		# saltar para uma pose terminal que a asa ainda não alcançou.
		_inicio_recuperacao = _gesto()
	_fase = fase
	_p = clampf(p, 0.0, 1.0)
	active = is_instance_valid(_sk) and fase in ["preparar_investida", "investida", "recuperar", "preparar_vendaval", "lancar_vendaval"]

func restaurar() -> void:
	_fase = ""
	_inicio_recuperacao.clear()
	active = false

func _profundidade(i: int) -> int:
	var n := 0
	while i >= 0:
		n += 1
		i = _sk.get_bone_parent(i)
	return n

func _gesto() -> Dictionary:
	var g := {"braco": 0.0, "cotovelo": 0.0, "punho": 0.0,
		"sobe": 0.0, "cotovelo_sobe": 0.0, "punho_sobe": 0.0,
		"cabeca": 0.0, "pescoco": 0.0, "cauda": 0.0, "peso": 0.0}
	match _fase:
		"preparar_investida":
			# A ponta acompanha o fechamento com atraso, sem mudar o instante
			# em que a IA dispara. Todas as juntas chegam à silhueta original.
			g.braco = smoothstep(0.18, 0.80, _p)
			g.cotovelo = smoothstep(0.27, 0.89, _p)
			g.punho = smoothstep(0.36, 0.98, _p)
			g.sobe = sin(_p * PI) * 15.0 - 9.0 * g.braco
			g.cabeca = -7.0 * g.braco
			g.pescoco = 4.0 * sin(_p * PI)
			g.cauda = 8.0 * g.punho
			g.peso = smoothstep(0.0, 0.22, _p)
		"investida":
			g.braco = 1.0
			g.cotovelo = 1.0
			g.punho = 1.0
			g.sobe = -9.0
			g.cabeca = -7.0
			g.cauda = 8.0 + sin(_p * PI) * 3.0
			g.peso = 1.0
		"recuperar":
			for chave in g:
				g[chave] = float(_inicio_recuperacao.get(chave, 0.0)) * (1.0 - smoothstep(0.0, 0.85, _p))
			# O antebraço e a ponta terminam depois do úmero, como uma asa
			# que abre para frear. Peso zero do vendaval continua zero.
			g.braco = float(_inicio_recuperacao.get("braco", 0.0)) * (1.0 - smoothstep(0.0, 0.52, _p))
			g.cotovelo = float(_inicio_recuperacao.get("cotovelo", 0.0)) * (1.0 - smoothstep(0.0, 0.63, _p))
			g.punho = float(_inicio_recuperacao.get("punho", 0.0)) * (1.0 - smoothstep(0.0, 0.74, _p))
			g.sobe += sin(_p * PI) * 20.0 * float(_inicio_recuperacao.get("braco", 0.0))
			g.peso = float(_inicio_recuperacao.get("peso", 0.0)) * (1.0 - smoothstep(0.70, 1.0, _p))
		"preparar_vendaval":
			# A batida chega ao ponto de força no fim da preparação, no tick
			# em que o controlador cria o tornado (sem atrasar o gameplay).
			g.sobe = 62.0 * smoothstep(0.0, 0.70, _p) - 100.0 * smoothstep(0.80, 1.0, _p)
			g.cotovelo_sobe = 8.0 * sin(_p * PI)
			g.punho_sobe = -9.0 * sin(_p * PI)
			g.cabeca = 7.0 * smoothstep(0.0, 0.82, _p)
			g.pescoco = -4.0 * smoothstep(0.0, 0.82, _p)
			g.cauda = -10.0 * smoothstep(0.1, 0.95, _p)
			g.peso = smoothstep(0.0, 0.18, _p)
		"lancar_vendaval":
			# Continuação da batida e assentamento nos mesmos 0,7 s de pose.
			g.sobe = -38.0 * (1.0 - smoothstep(0.08, 1.0, _p))
			g.cotovelo_sobe = -12.0 * sin(smoothstep(0.08, 0.82, _p) * PI)
			g.punho_sobe = -10.0 * sin(smoothstep(0.18, 0.96, _p) * PI)
			g.cabeca = 7.0 * (1.0 - smoothstep(0.0, 0.40, _p)) - 6.0 * sin(_p * PI)
			g.pescoco = -4.0 * (1.0 - smoothstep(0.0, 0.45, _p))
			g.cauda = -10.0 * (1.0 - smoothstep(0.0, 0.36, _p)) + 12.0 * sin(_p * PI)
			g.peso = 1.0 - smoothstep(0.76, 1.0, _p)
	return g

func _process_modification() -> void:
	if _sk == null or _fase.is_empty():
		return
	var gesto := _gesto()
	var peso: float = gesto.peso
	var deltas := {}
	for lado in ["l", "r"]:
		var sinal := 1.0 if lado == "l" else -1.0
		# Dobra em Z: úmero recua, cotovelo retorna e punho fecha as rémiges.
		# Eixos do MODELO (+Z é o bico), convertidos abaixo ao espaço do rig.
		_adicionar(deltas, "arm_stretch." + lado, Basis(Vector3.BACK, deg_to_rad(gesto.sobe) * sinal) * Basis(Vector3.UP, deg_to_rad(dobra_braco * gesto.braco) * sinal))
		_adicionar(deltas, "forearm_stretch." + lado, Basis(Vector3.BACK, deg_to_rad(gesto.cotovelo_sobe) * sinal) * Basis(Vector3.UP, deg_to_rad(dobra_cotovelo * gesto.cotovelo) * sinal))
		_adicionar(deltas, "hand." + lado, Basis(Vector3.BACK, deg_to_rad(gesto.punho_sobe) * sinal) * Basis(Vector3.UP, deg_to_rad(dobra_punho * gesto.punho) * sinal))
	_adicionar(deltas, "head", Basis(Vector3.RIGHT, deg_to_rad(gesto.cabeca)))
	_adicionar(deltas, "neck", Basis(Vector3.RIGHT, deg_to_rad(gesto.pescoco)))
	_adicionar(deltas, "tail", Basis(Vector3.RIGHT, deg_to_rad(gesto.cauda)))
	# Calcula toda a cadeia em ordem: cada articulação herda a dobra do pai.
	var para_modelo := (_modelo.global_transform.affine_inverse() * _sk.global_transform).basis.orthonormalized()
	var novos: Array[Transform3D] = []
	novos.resize(_sk.get_bone_count())
	for i in _ordem:
		var pai := _sk.get_bone_parent(i)
		var g := _globais[i]
		if pai >= 0:
			g = novos[pai] * _globais[pai].affine_inverse() * g
		if deltas.has(i):
			var d: Basis = para_modelo.inverse() * (deltas[i] as Basis) * para_modelo
			g.basis = d * g.basis
		novos[i] = g
		# Só substitui juntas autorais; pernas, peito e expressões mantêm o clipe.
		if deltas.has(i):
			var local := (novos[pai].affine_inverse() if pai >= 0 else Transform3D.IDENTITY) * g
			var atual := _sk.get_bone_pose_rotation(i)
			_sk.set_bone_pose_rotation(i, atual.slerp(local.basis.orthonormalized().get_rotation_quaternion(), peso))

func _adicionar(d: Dictionary, chave: String, valor: Basis) -> void:
	if _ossos.has(chave):
		d[_ossos[chave]] = valor
