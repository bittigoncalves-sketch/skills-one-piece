extends RefCounted
## Versioned working document. Pure data: no scene or UI dependencies.
const FPS := 30.0
const EPS := 0.00001
## Distancia da chave-sombra que representa o degrau ate a chave seguinte.
## Animation.track_insert_key funde chaves quase coincidentes: medido em Godot
## 4.6.3, 0,00001 s some (a seguinte a substitui) e 0,0001 s sobrevive. 0,001 s
## fica com folga sobre esse limite e ainda e 3% de um quadro a 30 fps.
const HOLD_GAP := 0.001
var data: Dictionary = fresh()

static func fresh() -> Dictionary:
	return {"version": 2, "name": "nova_skill", "length": 2.0, "loop": true,
		"rig": "base_v2", "setup": {}, "tracks": {}, "points": [], "weapon": false}

static func vector(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

static func array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func snap_time(t: float) -> float:
	return snappedf(t, 1.0 / FPS)

static func sample_keys(keys: Array, t: float) -> Array:
	if keys.is_empty(): return []
	if t < float(keys[0][0]): return keys[0][1].duplicate()
	for i in range(keys.size() - 1, -1, -1):
		if t + EPS >= float(keys[i][0]):
			if i == keys.size() - 1 or (keys[i].size() > 2 and bool(keys[i][2])):
				return keys[i][1].duplicate()
			var f := clampf((t - float(keys[i][0])) / (float(keys[i+1][0]) - float(keys[i][0])), 0, 1)
			return array(vector(keys[i][1]).lerp(vector(keys[i+1][1]), f))
	return keys[0][1].duplicate()

func sample(t: float) -> Dictionary:
	var out: Dictionary = {}
	for path in data.tracks:
		var v := sample_keys(data.tracks[path], t)
		if not v.is_empty(): out[path] = v
	return out

func point_at(t: float) -> int:
	for i in data.points.size():
		if absf(float(data.points[i].time) - t) < EPS: return i
	return -1

func key(path: String, t: float, value: Array, hold: bool = true) -> void:
	var keys: Array = data.tracks.get(path, [])
	for k in keys:
		if absf(float(k[0]) - t) < EPS:
			k[1] = value.duplicate()
			k.resize(3)
			k[2] = hold
			data.tracks[path] = keys
			return
	keys.append([t, value.duplicate(), hold])
	keys.sort_custom(func(a, b): return a[0] < b[0])
	data.tracks[path] = keys

func mark(t: float, pose: Dictionary, label: String = "") -> void:
	var idx := point_at(t)
	var hold := false if idx < 0 else bool(data.points[idx].hold)
	for path in pose: key(path, t, pose[path], hold)
	if idx < 0:
		data.points.append({"time": t, "label": label if label != "" else "Pose %d" % (data.points.size()+1), "hold": false})
		data.points.sort_custom(func(a, b): return a.time < b.time)

func transition(t: float, hold: bool) -> void:
	var idx := point_at(t)
	if idx < 0: return
	data.points[idx].hold = hold
	for keys in data.tracks.values():
		for k in keys:
			if absf(float(k[0]) - t) < EPS:
				k.resize(3)
				k[2] = hold

func move_point(old: float, target: float) -> bool:
	var idx := point_at(old)
	if idx < 0 or target < 0 or target > float(data.length): return false
	if absf(old - target) < EPS: return true
	if point_at(target) >= 0: return false
	data.points[idx].time = target
	data.points.sort_custom(func(a, b): return a.time < b.time)
	for keys in data.tracks.values():
		for k in keys:
			if absf(float(k[0]) - old) < EPS: k[0] = target
		keys.sort_custom(func(a, b): return a[0] < b[0])
	return true

func remove_point(t: float) -> void:
	var idx := point_at(t)
	if idx < 0: return
	data.points.remove_at(idx)
	for path in data.tracks.keys():
		data.tracks[path] = data.tracks[path].filter(func(k): return absf(float(k[0]) - t) >= EPS)
		if data.tracks[path].is_empty(): data.tracks.erase(path)

func load_file(path: String) -> String:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return "Arquivo JSON inválido."
	if not parser.data is Dictionary: return "O arquivo não contém uma animação."
	var incoming: Dictionary = parser.data
	if not incoming.get("tracks") is Dictionary: return "Faltam as faixas da animação."
	var length_value = incoming.get("length",0)
	if not (length_value is int or length_value is float) or not is_finite(float(length_value)) or float(length_value) <= 0: return "A duração deve ser positiva e finita."
	if int(incoming.get("version", 1)) > 2: return "Versão de arquivo mais nova que este editor."
	var candidate := fresh()
	for field in candidate:
		if incoming.has(field): candidate[field] = incoming[field]
	if not candidate.setup is Dictionary or not candidate.points is Array: return "Montagem ou pontos inválidos."
	for info in candidate.setup.values():
		if not info is Dictionary: return "Transformação de montagem inválida."
		for prop in ["position","rotation","scale"]:
			if not info.get(prop) is Array or info[prop].size() != 3: return "Transformação de montagem incompleta."
			for v in info[prop]:
				if not (v is int or v is float) or not is_finite(float(v)): return "Valor de montagem inválido."
				if prop == "scale" and float(v) <= 0: return "O tamanho precisa ser maior que zero."
	var tracks: Dictionary = {}
	for path_key in incoming.tracks:
		var path_name := str(path_key)
		if not ":" in path_name: path_name += ":rotation"
		if not path_name.get_slice(":", 1) in ["position", "rotation", "scale"]: return "Propriedade de animação desconhecida."
		var keys = incoming.tracks[path_key]
		if not keys is Array: return "Faixa inválida."
		var times: Dictionary = {}
		for k in keys:
			if not k is Array or k.size() < 2 or not k[1] is Array or k[1].size() != 3: return "Chave inválida."
			if not (k[0] is float or k[0] is int) or not is_finite(float(k[0])) or float(k[0]) < 0: return "Tempo inválido."
			if float(k[0]) > float(candidate.length) + EPS: return "Há chaves depois do fim da animação."
			for v in k[1]:
				if not (v is float or v is int) or not is_finite(float(v)): return "Valor de pose inválido."
			if times.has(float(k[0])): return "Duas chaves no mesmo instante."
			times[float(k[0])] = true
		keys.sort_custom(func(a,b): return a[0] < b[0])
		tracks[path_name] = keys
	candidate.tracks = tracks
	if int(incoming.get("version", 1)) < 2:
		candidate.points = []
		var times: Dictionary = {}
		for keys in tracks.values():
			for k in keys: times[float(k[0])] = true
		for t in times:
			candidate.points.append({"time": t, "label": "Chave importada", "hold": false})
		candidate.points.sort_custom(func(a,b): return a.time < b.time)
	var point_times: Dictionary = {}
	for p in candidate.points:
		if not p is Dictionary or not p.has("time") or not p.has("label") or not p.has("hold"): return "Ponto inválido."
		if not (p.time is int or p.time is float) or not is_finite(float(p.time)): return "Tempo de ponto inválido."
		if float(p.time) < 0 or float(p.time) > float(candidate.length) or point_times.has(float(p.time)): return "Ponto duplicado ou fora da duração."
		point_times[float(p.time)] = true
	candidate.points.sort_custom(func(a,b): return a.time < b.time)
	candidate.version = 2
	data = candidate
	return ""

static func save_json(path: String, value: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK: return err
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return write_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func save(path: String) -> Error:
	return save_json(path, data)

func animation() -> Animation:
	var anim := Animation.new()
	anim.resource_name = str(data.name)
	anim.length = float(data.length)
	anim.loop_mode = Animation.LOOP_LINEAR if bool(data.loop) else Animation.LOOP_NONE
	anim.set_meta("studio_version", 2)
	anim.set_meta("studio_setup", data.setup.duplicate(true))
	anim.set_meta("studio_weapon", bool(data.weapon))
	anim.set_meta("studio_points", data.points.duplicate(true))
	for path in data.tracks:
		var keys: Array = data.tracks[path]
		if keys.is_empty(): continue
		var idx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(idx, NodePath(path))
		anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
		anim.track_set_interpolation_loop_wrap(idx, false)
		for i in keys.size():
			var k: Array = keys[i]
			anim.track_insert_key(idx, float(k[0]), vector(k[1]))
			if k.size() > 2 and bool(k[2]) and i + 1 < keys.size():
				var end := float(keys[i+1][0])
				var shadow := end - minf(HOLD_GAP, (end-float(k[0])) * .5)
				anim.track_insert_key(idx, shadow, vector(k[1]))
	return anim
