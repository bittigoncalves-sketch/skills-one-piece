extends SceneTree
# Baker de animações Mixamo/Meshy -> rig por-nós do jogo.
# Bakeia .glb de res://assets/animations_glb/ para
# res://assets/animations/<nome>.res (Animation com faixas <Role>:rotation),
# tocável por ProceduralAnimator.play_baked().
#
# POR QUE GLB E NÃO FBX (descoberto em 2026-08-06): o importador FBX do Godot
# (ufbx) lê só 1 chave por osso de MEMBRO nos arquivos do Mixamo — as curvas
# existem no FBX, mas se perdem no import, e o bake saía todo ZERADO. Os .fbx
# são convertidos p/ .glb pelo Blender (tools/fbx_to_glb.py), que preserva as
# 520 fcurves, e o Godot lê glTF de forma confiável (57 chaves por osso).
#
# Pipeline completo:
#   1) blender --background --python tools/fbx_to_glb.py -- assets/animations assets/animations_glb
#   2) godot --headless --path . -s tools/bake_mixamo.gd
#
# Assar SÓ alguns arquivos (o bake sobrescreve em lote — use sempre que puder):
#   godot --headless --path . -s tools/bake_mixamo.gd -- punching meshy_socos
#
# TRÊS ARMADILHAS JÁ PAGAS (ver docs/erros.md, 2026-08-10):
#
# 1) NOMES DE OSSO. O MAP mapeava só "mixamorig_*". Num esqueleto Meshy (que usa
#    os nomes do Mixamo SEM prefixo) casavam 0 de 12 ossos, o laço pulava toda
#    inserção de chave e o baker **salvava sem erro e reportava sucesso** — .res
#    com faixas e zero chaves. Agora cada papel tem lista de aliases (a mesma do
#    SkeletonDriver.BONE_ALIASES) e o bake **ABORTA** se resolver zero ossos ou
#    inserir zero chaves. Falha silenciosa em passo de asset é o modo mais caro
#    de errar neste projeto.
#
# 2) UM CLIPE POR ARQUIVO. O baker pegava só o clipe mais longo. Um .glb de
#    animações mescladas (Meshy exporta assim) traz vários — os outros sumiam.
#    Agora assa TODOS. Com 1 clipe o nome de saída é o do ARQUIVO (compatível
#    com os 28 .res existentes, todos vindos de um clipe "mixamo_com"); com 2+
#    o nome sai do CLIPE em snake_case.
#
# 3) SALTO DE EULER (gimbal). As faixas são Vector3 euler com interpolação
#    LINEAR; Basis.get_euler() devolve sempre o representante canônico, então
#    duas poses vizinhas podiam sair como +179° e -179° — a interpolação faz o
#    caminho longo e vira um estalo visível em jogo (medido: 350.8° entre duas
#    chaves a 1/30 s). Agora cada chave escolhe o euler EQUIVALENTE mais próximo
#    da chave anterior (_euler_continuo).

# papel -> [aliases de osso, papel pai]. Os aliases têm que bater com
# SkeletonDriver.BONE_ALIASES; a hierarquia, com SkeletonDriver.RIG_PARENT.
const MAP := {
	"Torso":      [["Spine", "mixamorig_Spine1", "Spine1", "Chest"], ""],
	"Neck":       [["neck", "Neck", "mixamorig_Neck"], "Torso"],
	"Head":       [["Head", "mixamorig_Head"], "Torso"],
	"UpperArm_L": [["LeftArm", "mixamorig_LeftArm"], "Torso"],
	"ForeArm_L":  [["LeftForeArm", "mixamorig_LeftForeArm"], "UpperArm_L"],
	"UpperArm_R": [["RightArm", "mixamorig_RightArm"], "Torso"],
	"ForeArm_R":  [["RightForeArm", "mixamorig_RightForeArm"], "UpperArm_R"],
	"Thigh_L":    [["LeftUpLeg", "mixamorig_LeftUpLeg"], "Torso"],
	"Shin_L":     [["LeftLeg", "mixamorig_LeftLeg"], "Thigh_L"],
	"Foot_L":     [["LeftFoot", "mixamorig_LeftFoot"], "Shin_L"],
	"Thigh_R":    [["RightUpLeg", "mixamorig_RightUpLeg"], "Torso"],
	"Shin_R":     [["RightLeg", "mixamorig_RightLeg"], "Thigh_R"],
	"Foot_R":     [["RightFoot", "mixamorig_RightFoot"], "Shin_R"],
}

const SRC_DIR := "res://assets/animations_glb/"
const OUT_DIR := "res://assets/animations/"
# Acima disto, o salto entre duas chaves vizinhas vira estalo visível em jogo.
const SALTO_ALERTA_DEG := 30.0
# Taxa de amostragem do bake. A faixa é LINEAR, então a densidade de chaves é o
# ÚNICO controle sobre o erro de interpolação: dobrar o fps corta o desvio pela
# metade. A 30 fps os socos Meshy percorriam até 34.5° de giro real entre duas
# chaves (movimento rápido de verdade, não gimbal); a 60 fps caem para 17.2°.
# Custo: 2× chaves num arquivo de dezenas de KB. Os 28 .res antigos ficaram a
# 30 fps — só mudam se forem reassados.
const BAKE_FPS := 60.0

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var dir := DirAccess.open(SRC_DIR)
	if dir == null:
		print("✗ pasta ausente: ", SRC_DIR, " — rode antes o tools/fbx_to_glb.py")
		quit(1)
		return
	# Sem argumentos assa a pasta inteira; com argumentos, só os .glb citados
	# (pelo nome sem extensão). O bake sobrescreve em lote — prefira a lista.
	var filtro := PackedStringArray(OS.get_cmdline_user_args())
	if not filtro.is_empty():
		print("filtro: ", ", ".join(filtro))
	var ok := 0
	var fail := 0
	for f in dir.get_files():
		if not f.to_lower().ends_with(".glb"):
			continue
		var nome := f.get_basename()
		if not filtro.is_empty() and not filtro.has(nome):
			continue
		var r := _bake_file(SRC_DIR + f, nome)
		ok += r.x
		fail += r.y
		if r.x == 0 and r.y == 0:
			fail += 1
			print("  ✗ ", nome, ": nenhum clipe assável no arquivo")
	print("BAKE FINAL: ok=", ok, " fail=", fail)
	quit(1 if fail > 0 else 0)

# Retorna Vector2i(assados, falhos).
func _bake_file(glb_path: String, file_stem: String) -> Vector2i:
	# GLTFDocument em runtime: pula o pipeline de import do editor.
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(glb_path), st) != OK:
		print("  ✗ ", file_stem, ": glTF não abriu")
		return Vector2i(0, 1)
	var scene = doc.generate_scene(st)
	if scene == null:
		print("  ✗ ", file_stem, ": cena vazia")
		return Vector2i(0, 1)
	get_root().add_child(scene)
	var skel: Skeleton3D = _find(scene, "Skeleton3D")
	var ap: AnimationPlayer = _find_ap(scene)
	if skel == null or ap == null or ap.get_animation_list().is_empty():
		print("  ✗ ", file_stem, ": sem Skeleton3D ou sem AnimationPlayer/clipes")
		scene.queue_free()
		return Vector2i(0, 1)

	# As faixas do glTF são "Armature/Skeleton3D:<osso>", relativas à RAIZ da
	# cena — não ao pai do esqueleto (isso quebrava a resolução das faixas).
	ap.root_node = ap.get_path_to(scene)

	# ---- resolução de ossos (BUG A): uma vez por arquivo, com aliases ----
	var bone := {}          # papel -> índice do osso
	var faltando := []
	for papel in MAP:
		var bi := -1
		for alias in MAP[papel][0]:
			bi = skel.find_bone(alias)
			if bi >= 0:
				break
		if bi >= 0:
			bone[papel] = bi
		else:
			faltando.append(papel)
	print("  • ", file_stem, ": ossos resolvidos ", bone.size(), "/", MAP.size(),
		("" if faltando.is_empty() else "  (sem: %s)" % ", ".join(faltando)))
	if bone.is_empty():
		# ABORTA. Antes daqui o baker salvava .res sem uma única chave e dizia
		# que tinha dado certo — a falha mais cara já vista neste projeto.
		push_error("bake_mixamo: 0 ossos resolvidos em %s — esqueleto com nomes fora do MAP" % file_stem)
		print("  ✗ ", file_stem, ": ABORTADO — 0 de ", MAP.size(),
			" ossos resolvidos. Acrescente os nomes deste esqueleto ao MAP.")
		scene.queue_free()
		return Vector2i(0, 1)

	var rest := {}
	for papel in bone:
		rest[papel] = skel.get_bone_global_rest(bone[papel]).basis.orthonormalized()

	# ---- clipes (BUG B): assa TODOS, não só um ----
	var clipes := []
	for c in ap.get_animation_list():
		if c.to_lower().contains("reset"):
			continue
		clipes.append(c)
	var ok := 0
	var fail := 0
	for clip in clipes:
		# 1 clipe -> nome do ARQUIVO (mantém os 28 .res atuais, todos de
		# "mixamo_com"); 2+ -> nome do CLIPE em snake_case.
		var out_name: String = file_stem if clipes.size() == 1 else clip.to_snake_case()
		if _bake_clip(ap, skel, clip, bone, rest, OUT_DIR + out_name + ".res"):
			ok += 1
		else:
			fail += 1
	scene.queue_free()
	return Vector2i(ok, fail)

func _bake_clip(ap: AnimationPlayer, skel: Skeleton3D, clip: String,
		bone: Dictionary, rest: Dictionary, out_path: String) -> bool:
	var src: Animation = ap.get_animation(clip)
	var dur: float = src.length
	var fps := BAKE_FPS
	var n := int(dur * fps) + 1
	var out := Animation.new()
	out.length = dur
	var tracks := {}
	for papel in bone:
		var ti := out.add_track(Animation.TYPE_VALUE)
		out.track_set_path(ti, NodePath(papel + ":rotation"))
		tracks[papel] = ti
	var yflip := Basis(Vector3.UP, PI)
	var prev := {}          # papel -> último euler gravado (para continuidade)
	var salto_max := 0.0
	var salto_cru := 0.0
	var chaves := 0
	ap.play(clip)
	for fr in range(n):
		var t: float = min(fr / fps, dur)
		ap.seek(t, true)
		var wdelta := {}
		for papel in bone:
			# Compõe a pose global à mão a partir das poses LOCAIS: o
			# get_bone_global_pose() não é reavaliado logo após o seek() num
			# script headless e devolveria sempre a pose do t=0.
			var cur := _global_pose_basis(skel, bone[papel])
			wdelta[papel] = yflip * cur * rest[papel].inverse() * yflip.inverse()
		for papel in bone:
			var par: String = MAP[papel][1]
			var local: Basis = wdelta[par].inverse() * wdelta[papel] if (par != "" and wdelta.has(par)) else wdelta[papel]
			var cru := local.get_euler()
			var e: Vector3 = cru
			if prev.has(papel):
				salto_cru = maxf(salto_cru, _maior_eixo(cru - prev[papel].cru))
				e = _euler_continuo(cru, prev[papel].e)
				salto_max = maxf(salto_max, _maior_eixo(e - prev[papel].e))
			prev[papel] = {"e": e, "cru": cru}
			out.track_insert_key(tracks[papel], t, e)
			chaves += 1
	if chaves == 0:
		push_error("bake_mixamo: 0 chaves em %s" % out_path)
		print("  ✗ ", out_path.get_file(), ": ABORTADO — 0 chaves inseridas")
		return false
	var err := ResourceSaver.save(out, out_path)
	if err == OK:
		var aviso := "   <<< SALTO ALTO" if rad_to_deg(salto_max) > SALTO_ALERTA_DEG else ""
		print("  ✓ %-34s (%.2fs, %df, %d chaves, salto cru %.1f° -> destorcido %.1f°)%s"
			% [out_path.get_file(), dur, n, chaves, rad_to_deg(salto_cru), rad_to_deg(salto_max), aviso])
	else:
		print("  ✗ ", out_path.get_file(), ": ResourceSaver err=", err)
	return err == OK

# BUG C — destorcimento contínuo do euler.
# Basis.get_euler() devolve o representante canônico (x em [-π/2, π/2]), então
# a mesma rotação pode aparecer como +179° num frame e -179° no seguinte: a
# faixa é LINEAR, a interpolação faz o caminho longo e o membro dá um giro.
# Toda rotação tem infinitos eulers equivalentes na ordem YXZ do Godot:
#   (a) (x, y, z) + múltiplos de 2π em cada eixo;
#   (b) o "flip": (π−x, y+π, z+π), também + múltiplos de 2π.
# (verificado numericamente: as duas famílias reconstroem a MESMA Basis, erro
#  máximo 0.000000° em 2000 rotações aleatórias)
# Escolhemos o equivalente que fica mais perto da chave anterior.
func _euler_continuo(e: Vector3, ant: Vector3) -> Vector3:
	var melhor := e
	var custo := INF
	for c in [e, Vector3(PI - e.x, e.y + PI, e.z + PI)]:
		var w := Vector3(
			c.x + TAU * roundf((ant.x - c.x) / TAU),
			c.y + TAU * roundf((ant.y - c.y) / TAU),
			c.z + TAU * roundf((ant.z - c.z) / TAU))
		var d := _maior_eixo(w - ant)
		if d < custo:
			custo = d
			melhor = w
	return melhor

func _maior_eixo(v: Vector3) -> float:
	return maxf(absf(v.x), maxf(absf(v.y), absf(v.z)))

# Pose global do osso, composta subindo a cadeia de pais pelas poses LOCAIS.
func _global_pose_basis(skel: Skeleton3D, idx: int) -> Basis:
	var b := skel.get_bone_pose(idx).basis
	var p := skel.get_bone_parent(idx)
	while p >= 0:
		b = skel.get_bone_pose(p).basis * b
		p = skel.get_bone_parent(p)
	return b.orthonormalized()

func _find(n, cls):
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r:
			return r
	return null

func _find_ap(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null
