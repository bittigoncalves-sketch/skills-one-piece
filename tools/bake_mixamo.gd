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
#
# CONTRATO v2 — faixas do CORPO (02/10/2026, docs/PARKOUR_MIRRORS_EDGE_PLANO.md,
# "Contrato dos clipes de locomoção/parkour"). Todo .glb FORA de
# LEGADO_SO_ROTACAO sai com, além das 13 faixas <Papel>:rotation:
#   Corpo:altura        float   (y do quadril − y em repouso) ÷ y em repouso
#   Corpo:giro          float   rumo do quadril em volta da vertical, rad, relativo
#                               ao 1º quadro, + = para a esquerda, contínuo
#   Corpo:deslocamento  Vector3 posição do quadril − a do 1º quadro, espaço do JOGO
#                               (frente −Z, direita +X, cima +Y) ÷ y em repouso
# e os metadados altura_quadril_m, origem, espelhado. O giro é RETIRADO das
# rotações dos papéis (o jogo aplica uma vez só, no corpo). As faixas novas não
# têm nó no rig, então o ProceduralAnimator._apply_baked as ignora.
#
# ⚠️ O espaço do esqueleto NÃO é o do mundo: o glTF do Blender põe o
# Skeleton3D sob um nó "Armature" girado 90° em X e com escala 0,01 (o esqueleto
# fica Z-para-baixo-é-cima, em centímetros). Posição e vertical do quadril são
# medidas no MUNDO (skel.global_transform).
#
# CONVERSÃO v3 — rotações no MUNDO + repouso dos braços (07/10/2026, docs/erros.md
# "clipes bakeados no espaço do esqueleto"). Até aqui o giro de cada osso era
# convertido no espaço do ESQUELETO (yflip ali). Como esse espaço está girado 90°
# em X, todo giro em volta da vertical saía como tombo para o lado (e vice-versa):
# o quadril que gira no soco/chute deitava o boneco, o braço que cruza o peito
# saía para fora (antebraço até 100° errado). Na corrida quase tudo é giro em X
# (que a troca preserva) e por isso ela passava. Medido contra o .glb, por
# segmento (tools/dev_tests/medir_clipes_do_builder.gd): 13°–120° → 1°–4°.
# Agora:   global(papel) = yflip · A · pose · repouso⁻¹ · A⁻¹ · yflip⁻¹ · Q(papel)
# com A = giro do esqueleto no mundo e Q = do braço PENDURADO (o zero do rig: as
# poses procedurais, as MeleePoses e as do Builder partem dele) até a pose T do
# repouso do Mixamo. Só braço e antebraço têm Q: tronco e pernas em repouso já
# querem dizer "em pé" nos dois. Toda saída leva o metadado conversao = 3.
#
# ESPELHO: os nomes de ESPELHAR (e os de --espelhar=a,b) saem também como
# <nome>_espelhado.res: troca _L<->_R, euler (x, −y, −z), giro −g,
# deslocamento x -> −x, altura igual.
#   godot --headless --path . -s tools/bake_mixamo.gd -- wall_run --espelhar=sprint

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

# Quadril: origem das faixas do Corpo.
const HIPS_ALIASES := ["mixamorig_Hips", "Hips", "hips"]

# Assados no contrato v1 (SÓ rotação) e mantidos assim de propósito: nos golpes
# que giram o corpo (armada, meia-lua, chapa giratória, pivot) o giro mora DENTRO
# do Torso, e o ProceduralAnimator ainda não aplica Corpo:giro — tirar o giro
# deles mudaria o golpe em jogo. (Desde a conversão v3, o rebake destes NÃO sai
# mais idêntico ao do baker antigo: as rotações mudam; o contrato só-rotação fica.)
# Gatilho para rever: quando o ProceduralAnimator passar a aplicar Corpo:giro e
# Corpo:deslocamento, reassar estes no v2 e apagar a lista.
const LEGADO_SO_ROTACAO := [
	"armada", "au_to_role", "bencao", "bouncing_fight_idle", "boxing", "boxing_1",
	"boxing_2", "boxing_3", "chapa_2", "chapa_giratoria_2", "dying", "flying_kick",
	"gunplay", "jab_to_elbow_punch", "jumping_over_into_combat", "kicking",
	"meia_lua_de_compasso", "meshy_blue_block_buddy", "pivot", "pontera",
	"punching", "quad_punch", "roundhouse_kick", "roundhouse_kick_2",
	"running_dive_roll", "smash", "stabbing", "uppercut_jab",
]

# Conversão v3: a mão de cada antebraço (direção do osso no repouso).
const MAO := {"ForeArm_L": ["LeftHand", "mixamorig_LeftHand"], "ForeArm_R": ["RightHand", "mixamorig_RightHand"]}
## Versão da conversão gravada em todo .res (metadado `conversao`).
const CONVERSAO := 3

# Saem também espelhados (<nome>_espelhado.res): wall run na parede do outro lado.
const ESPELHAR := ["wall_run", "diagonal_wall_run"]

# Rumo do quadril (Corpo:giro): segue inteiro com o quadril inclinado até
# CONFIA graus da vertical, fica parado a partir de SEGURA, e segue em parte
# entre os dois. Ver _rumo().
const RUMO_CONFIA_GRAUS := 50.0
const RUMO_SEGURA_GRAUS := 80.0

# Refino de chaves (só v2; ver _meios_ruins): divide o intervalo ao meio
# enquanto a interpolação do euler passar REFINO_EXCESSO_DEG do giro real
# (gimbal) ou percorrer mais de REFINO_PERCURSO_DEG (movimento rápido de verdade:
# o braço do sprinting_forward_roll anda 38,7° em 1/60 s), até REFINO_VOLTAS
# vezes (1/60 -> 1/480 s).
const REFINO_EXCESSO_DEG := 3.0
const REFINO_PERCURSO_DEG := 20.0
const REFINO_VOLTAS := 3
const REFINO_DT_MIN := 1.0 / 480.0

var out_dir := OUT_DIR
var src_dir := SRC_DIR   # `--origem=<pasta res://>` (ex.: os .glb do Epic Fight em res://assets/epic_fight/glb/)

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var dir := DirAccess.open(src_dir)
	if dir == null:
		print("✗ pasta ausente: ", src_dir, " — rode antes o tools/fbx_to_glb.py")
		quit(1)
		return
	# Sem argumentos assa a pasta inteira; com argumentos, só os .glb citados
	# (pelo nome sem extensão). O bake sobrescreve em lote — prefira a lista.
	var filtro := PackedStringArray()
	var espelhar := PackedStringArray(ESPELHAR)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--espelhar="):
			for nm in a.trim_prefix("--espelhar=").split(",", false):
				if not espelhar.has(nm):
					espelhar.append(nm)
		elif a.begins_with("--origem="):
			src_dir = a.trim_prefix("--origem=").trim_suffix("/") + "/"
		elif a.begins_with("--saida="):
			# Assa noutra pasta (conferir antes de sobrescrever os do projeto).
			out_dir = a.trim_prefix("--saida=").trim_suffix("/") + "/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
		elif a.begins_with("--"):
			print("✗ opção desconhecida: ", a, "  (aceito: --espelhar=a,b  --saida=<pasta>  --origem=<pasta>)")
			quit(1)
			return
		else:
			filtro.append(a)
	if not filtro.is_empty():
		print("filtro: ", ", ".join(filtro))
	dir = DirAccess.open(src_dir)   # reabre: `--origem` só é conhecido depois de ler os argumentos
	if dir == null:
		print("✗ pasta ausente: ", src_dir)
		quit(1)
		return
	var ok := 0
	var fail := 0
	for f in dir.get_files():
		if not f.to_lower().ends_with(".glb"):
			continue
		var nome := f.get_basename()
		if not filtro.is_empty() and not filtro.has(nome):
			continue
		var r := _bake_file(src_dir + f, nome, espelhar.has(nome))
		ok += r.x
		fail += r.y
		if r.x == 0 and r.y == 0:
			fail += 1
			print("  ✗ ", nome, ": nenhum clipe assável no arquivo")
	print("BAKE FINAL: ok=", ok, " fail=", fail)
	quit(1 if fail > 0 else 0)

# Retorna Vector2i(assados, falhos).
func _bake_file(glb_path: String, file_stem: String, espelhar: bool) -> Vector2i:
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

	# ---- conversão v3 (ver o cabeçalho): giro do esqueleto no mundo e Q dos braços ----
	var yflip := Basis(Vector3.UP, PI)
	var A3 := skel.global_transform.basis.orthonormalized()
	var conv := {"L": yflip * A3, "R": A3.inverse() * yflip.inverse(), "q": {}}
	for papel in bone:
		var filho := -1
		if papel.begins_with("UpperArm_"):
			filho = bone.get(papel.replace("UpperArm_", "ForeArm_"), -1)
		elif MAO.has(papel):
			for alias in MAO[papel]:
				filho = skel.find_bone(alias)
				if filho >= 0:
					break
		if filho < 0:
			conv.q[papel] = Basis()
			continue
		var d: Vector3 = (yflip * A3 * (skel.get_bone_global_rest(filho).origin - skel.get_bone_global_rest(bone[papel]).origin)).normalized()
		conv.q[papel] = Basis(Quaternion(Vector3.DOWN, d))
	if conv.q.size() > 0:
		var tpose := []
		for papel in ["UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R"]:
			if conv.q.has(papel):
				tpose.append("%s %.0f°" % [papel, rad_to_deg((conv.q[papel] as Basis).get_rotation_quaternion().get_angle())])
		print("    repouso dos braços → pendurado: ", ", ".join(tpose))

	# ---- contrato v2: contexto do quadril (vazio = v1, só rotação) ----
	var corpo := {}
	if not LEGADO_SO_ROTACAO.has(file_stem):
		var hips := -1
		for alias in HIPS_ALIASES:
			hips = skel.find_bone(alias)
			if hips >= 0:
				break
		# esqueleto -> mundo glTF (Y-up, metros). Ver o aviso do cabeçalho.
		var A: Transform3D = skel.global_transform
		var h: float = (A * skel.get_bone_global_rest(hips).origin).y if hips >= 0 else 0.0
		if hips < 0 or h < 0.1:
			# Mesma regra do BUG A: sem quadril o clipe sairia sem as faixas do
			# Corpo e "com sucesso". Aborta.
			push_error("bake_mixamo: quadril ausente/inválido em %s" % file_stem)
			print("  ✗ ", file_stem, ": ABORTADO — quadril não achado (", ", ".join(HIPS_ALIASES),
				") ou altura em repouso %.3f m" % h)
			scene.queue_free()
			return Vector2i(0, 1)
		var A_rot := A.basis.orthonormalized()
		corpo = {
			"hips": hips, "A": A, "A_rot": A_rot, "A_rot_inv": A_rot.inverse(), "h": h,
			"rest_hips_inv": skel.get_bone_global_rest(hips).basis.orthonormalized().inverse(),
		}

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
		var origem: String = glb_path if clipes.size() == 1 else "%s#%s" % [glb_path, clip]
		if _bake_clip(ap, skel, clip, bone, rest, out_dir + out_name + ".res", corpo, espelhar, origem, conv):
			ok += 1
		else:
			fail += 1
	scene.queue_free()
	return Vector2i(ok, fail)

func _bake_clip(ap: AnimationPlayer, skel: Skeleton3D, clip: String,
		bone: Dictionary, rest: Dictionary, out_path: String,
		corpo: Dictionary, espelhar: bool, origem: String, conv: Dictionary) -> bool:
	var src: Animation = ap.get_animation(clip)
	var dur: float = src.length
	var fps := BAKE_FPS
	var v2 := not corpo.is_empty()
	# Arredonda: a última chave cai em `dur` (o v1 truncava — 0,9667 s × 60 =
	# 57,99999 -> 57 — e perdia o último 1/60 s; desde a v3 todos arredondam).
	var n := roundi(dur * fps) + 1
	var tempos: Array = []
	for fr in range(n):
		tempos.append(min(fr / fps, dur))
	ap.play(clip)
	var am := _amostrar(ap, skel, bone, rest, corpo, tempos, conv)
	# Refino perto do gimbal (ver _meios_ruins), em TODOS os clipes desde a
	# conversão v3: os braços erguidos à frente (socos) caem em x ≈ ±90°.
	var refinos := 0
	for volta in REFINO_VOLTAS:
		var meios := _meios_ruins(am, tempos, bone)
		if meios.is_empty():
			break
		refinos += meios.size()
		tempos.append_array(meios)
		tempos.sort()
		am = _amostrar(ap, skel, bone, rest, corpo, tempos, conv)
	var out := Animation.new()
	out.length = dur
	var chaves := 0
	for papel in bone:
		var ti := out.add_track(Animation.TYPE_VALUE)
		out.track_set_path(ti, NodePath(papel + ":rotation"))
		var es: Array = am.e[papel]
		for k in tempos.size():
			out.track_insert_key(ti, tempos[k], es[k])
			chaves += 1
	if v2:
		for faixa in [["Corpo:altura", am.altura], ["Corpo:giro", am.giro], ["Corpo:deslocamento", am.desl]]:
			var ti := out.add_track(Animation.TYPE_VALUE)
			out.track_set_path(ti, NodePath(faixa[0]))
			var vs: Array = faixa[1]
			for k in tempos.size():
				out.track_insert_key(ti, tempos[k], vs[k])
	if chaves == 0:
		push_error("bake_mixamo: 0 chaves em %s" % out_path)
		print("  ✗ ", out_path.get_file(), ": ABORTADO — 0 chaves inseridas")
		return false
	out.set_meta("conversao", CONVERSAO)
	if v2:
		out.set_meta("altura_quadril_m", corpo.h)
		out.set_meta("origem", origem)
		out.set_meta("espelhado", false)
	var err := ResourceSaver.save(out, out_path)
	if err == OK:
		var salto_max: float = am.salto_max
		var aviso := "   <<< SALTO ALTO" if rad_to_deg(salto_max) > SALTO_ALERTA_DEG else ""
		print("  ✓ %-34s (%.2fs, %df, %d chaves, salto cru %.1f° -> destorcido %.1f°)%s"
			% [out_path.get_file(), dur, tempos.size(), chaves, rad_to_deg(am.salto_cru), rad_to_deg(salto_max), aviso])
		if v2:
			var h: float = corpo.h
			var giro: float = am.giro[-1]
			var desl: Vector3 = am.desl[-1]
			var alt: Array = am.altura
			print("      corpo: h=%.3f m  giro final %.1f° (maior passo %.1f°)  desl final (%.2f, %.2f, %.2f) m  altura %.2f..%.2f m  refino +%d chaves/faixa%s"
				% [h, rad_to_deg(giro), rad_to_deg(am.giro_salto),
				desl.x * h, desl.y * h, desl.z * h, (1.0 + alt.min()) * h, (1.0 + alt.max()) * h, refinos,
				"  [quadril deitado em %d chaves: rumo segurado]" % am.reserva if am.reserva > 0 else ""])
	else:
		print("  ✗ ", out_path.get_file(), ": ResourceSaver err=", err)
		return false
	if espelhar:
		var esp_path := out_path.get_basename() + "_espelhado.res"
		var err2 := ResourceSaver.save(_espelhar(out), esp_path)
		if err2 == OK:
			print("  ✓ %-34s (espelho de %s)" % [esp_path.get_file(), out_path.get_file()])
		else:
			print("  ✗ ", esp_path.get_file(), ": ResourceSaver err=", err2)
			return false
	return true

# Amostra o clipe nos instantes `tempos` (em ordem): euler contínuo por papel e,
# no v2, as faixas do Corpo, com o giro do quadril tirado das poses globais.
# Sequencial de propósito: a continuidade do euler e do rumo depende da chave
# anterior. A conversão de cada papel é a v3 (ver o cabeçalho), no v1 e no v2.
func _amostrar(ap: AnimationPlayer, skel: Skeleton3D, bone: Dictionary,
		rest: Dictionary, corpo: Dictionary, tempos: Array, conv: Dictionary) -> Dictionary:
	var v2 := not corpo.is_empty()
	var L: Basis = conv.L
	var R: Basis = conv.R
	var e := {}
	for papel in bone:
		e[papel] = []
	var altura := []
	var giro := []
	var desl := []
	var prev := {}          # papel -> último euler gravado (para continuidade)
	var salto_max := 0.0
	var salto_cru := 0.0
	var rumo0 := 0.0
	var rumo_ant := 0.0
	var p0 := Vector3.ZERO
	var giro_salto := 0.0
	var reserva := 0        # chaves com o quadril deitado demais (ver _rumo)
	for k in tempos.size():
		var t: float = tempos[k]
		ap.seek(t, true)
		var tira := Basis()   # v2: tira o giro do quadril das poses globais
		if v2:
			var q := _quadril(skel, corpo)
			var rr := _rumo(q.w, rumo_ant, k == 0)
			if rr.y > 0.5:
				reserva += 1
			if k == 0:
				rumo0 = rr.x
				p0 = _no_jogo(q.p)
			else:
				giro_salto = maxf(giro_salto, absf(rr.x - rumo_ant))
			rumo_ant = rr.x
			var g := rr.x - rumo0
			var h: float = corpo.h
			altura.append((q.p.y - h) / h)
			giro.append(g)
			desl.append((_no_jogo(q.p) - p0) / h)
			# Giro em volta da vertical do MUNDO, levado ao espaço do esqueleto.
			tira = corpo.A_rot_inv * Basis(Vector3.UP, -g) * corpo.A_rot
		var wdelta := {}
		for papel in bone:
			# Compõe a pose global à mão a partir das poses LOCAIS: o
			# get_bone_global_pose() não é reavaliado logo após o seek() num
			# script headless e devolveria sempre a pose do t=0.
			var cur := _global_pose_basis(skel, bone[papel])
			if v2:
				cur = tira * cur
			# v3: o giro desde o repouso levado ao MUNDO (L/R), depois o Q do braço.
			wdelta[papel] = L * cur * rest[papel].inverse() * R * (conv.q[papel] as Basis)
		for papel in bone:
			var par: String = MAP[papel][1]
			var local: Basis = wdelta[par].inverse() * wdelta[papel] if (par != "" and wdelta.has(par)) else wdelta[papel]
			var cru := local.get_euler()
			var ev: Vector3 = cru
			if prev.has(papel):
				salto_cru = maxf(salto_cru, _maior_eixo(cru - prev[papel].cru))
				ev = _euler_continuo(cru, prev[papel].e)
				salto_max = maxf(salto_max, _maior_eixo(ev - prev[papel].e))
			prev[papel] = {"e": ev, "cru": cru}
			e[papel].append(ev)
	return {"e": e, "altura": altura, "giro": giro, "desl": desl,
		"salto_max": salto_max, "salto_cru": salto_cru, "giro_salto": giro_salto, "reserva": reserva}

# Intervalos entre chaves vizinhas em que a interpolação LINEAR do euler (o que
# o jogo toca) (a) percorre mais que REFINO_EXCESSO_DEG além do giro real entre
# as duas poses — o sintoma do gimbal: perto de x = ±90° (joelho dobrado além de
# 90°, tronco deitado no rolamento) uma rotação real de 7° pede 80°+ de euler, e
# o meio da interpolação passa longe das duas poses — ou (b) percorre mais que
# REFINO_PERCURSO_DEG (passo grande demais para a reta do euler seguir o arco).
# Devolve o ponto médio de cada intervalo ruim que ainda pode ser dividido
# (passo mínimo REFINO_DT_MIN).
func _meios_ruins(am: Dictionary, tempos: Array, bone: Dictionary) -> Array:
	var meios := []
	for k in range(1, tempos.size()):
		var dt: float = tempos[k] - tempos[k - 1]
		if dt * 0.5 < REFINO_DT_MIN * 0.999:
			continue
		for papel in bone:
			var a: Vector3 = am.e[papel][k - 1]
			var b: Vector3 = am.e[papel][k]
			var perc := rad_to_deg(_percurso(a, b))
			if perc - rad_to_deg(_giro_real(a, b)) > REFINO_EXCESSO_DEG or perc > REFINO_PERCURSO_DEG:
				meios.append((tempos[k - 1] + tempos[k]) * 0.5)
				break
	return meios

# Rotação percorrida pela interpolação LINEAR de euler de `a` até `b` (rad).
func _percurso(a: Vector3, b: Vector3) -> float:
	var soma := 0.0
	var ant := a
	for s in range(1, 9):
		var m := a.lerp(b, s / 8.0)
		soma += _giro_real(ant, m)
		ant = m
	return soma

# Ângulo da rotação entre duas poses (geodésico, rad). Por atan2 e não pelo
# Quaternion.angle_to: aquele é 2·acos(dot), e em float32 o dot de duas poses
# IGUAIS já sai 1 − 1 ulp — 0,056° de "giro" onde não há nenhum.
func _giro_real(a: Vector3, b: Vector3) -> float:
	var d := Basis.from_euler(a).get_rotation_quaternion().inverse() * Basis.from_euler(b).get_rotation_quaternion()
	return 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w))

# Espelho esquerda <-> direita (reflexão no plano sagital, normal = X).
# Rotação: troca _L<->_R e euler (x, −y, −z) — vale na ordem YXZ porque
# M·Ry(y)·Rx(x)·Rz(z)·M = Ry(−y)·Rx(x)·Rz(−z) com M = diag(−1, 1, 1), e o eixo
# lateral é X tanto no mundo quanto no espaço das faixas. Corpo: giro −g,
# deslocamento x -> −x, altura igual.
# (Não é o Melee.espelhar: aquele nega y e z de TODO Vector3, o que viraria o
# deslocamento de cabeça para baixo e de trás para frente.)
func _espelhar(a: Animation) -> Animation:
	var out: Animation = a.duplicate(true)
	for i in out.get_track_count():
		var caminho := String(out.track_get_path(i))
		var papel := caminho.get_slice(":", 0)
		var prop := caminho.get_slice(":", 1)
		if papel.ends_with("_L"):
			papel = papel.left(-2) + "_R"
		elif papel.ends_with("_R"):
			papel = papel.left(-2) + "_L"
		out.track_set_path(i, NodePath(papel + ":" + prop))
		for k in out.track_get_key_count(i):
			var v = out.track_get_key_value(i, k)
			if prop == "rotation":
				v = Vector3(v.x, -v.y, -v.z)
			elif caminho == "Corpo:giro":
				v = -v
			elif caminho == "Corpo:deslocamento":
				v = Vector3(-v.x, v.y, v.z)
			out.track_set_key_value(i, k, v)
	out.set_meta("espelhado", true)
	return out

# Quadril no MUNDO glTF (Y-up, metros; o personagem em repouso olha +Z, esquerda
# = +X): posição e delta de rotação desde o repouso. Compõe pelas poses LOCAIS,
# pelo mesmo motivo do _global_pose_basis.
func _quadril(skel: Skeleton3D, c: Dictionary) -> Dictionary:
	var tr := skel.get_bone_pose(c.hips)
	var p := skel.get_bone_parent(c.hips)
	while p >= 0:
		tr = skel.get_bone_pose(p) * tr
		p = skel.get_bone_parent(p)
	var A: Transform3D = c.A
	var A_rot: Basis = c.A_rot
	var rest_inv: Basis = c.rest_hips_inv
	var A_rot_inv: Basis = c.A_rot_inv
	return {"p": A * tr.origin, "w": A_rot * tr.basis.orthonormalized() * rest_inv * A_rot_inv}

# Mundo glTF -> jogo: o Mixamo olha +Z, o jogo −Z (mesmo giro de 180° do yflip).
func _no_jogo(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)

# RUMO do quadril em volta da vertical (rad, + = esquerda), contínuo com `ant`.
# Devolve Vector2(rumo, 1 se o quadril estava deitado demais para o rumo valer).
#
# Vem do eixo LATERAL do quadril projetado no chão, e só enquanto o quadril está
# de pé: deitado (rolamento, deslize, queda), "para onde o corpo aponta" não tem
# resposta, e qualquer leitura vira ruído no Corpo:giro. Tentativas que falharam,
# medidas nos 30 clipes (Blender + este baker):
#  - Basis.get_euler().y: no rolamento o YXZ entra em gimbal e o "yaw" dá a
#    volta — sprinting_forward_roll −365°, falling_to_roll +171°, sem o corpo girar;
#  - média ponderada lateral+frontal: −185° no mesmo rolamento;
#  - lateral, trocando para o frontal quando inclina > 60°: passo de 84,9° em
#    1/60 s no rolamento;
#  - lateral com peso pela inclinação DELE: o rolamento é diagonal (por cima do
#    ombro), o lateral precessa e o giro ia de −55° a +78° e voltava em 0,25 s.
# Por isso o peso `c` vem de quanto o quadril está DE PÉ (eixo de cima dele contra
# a vertical): c = 1 até RUMO_CONFIA_GRAUS de inclinação, 0 a partir de
# RUMO_SEGURA_GRAUS, e o rumo anda só a fração c do caminho. O que não vai para
# o giro fica na pose dos papéis — a decomposição é EXATA em toda chave, qualquer
# que seja c, porque os papéis perdem exatamente o giro gravado. De pé o lateral
# nunca passa pela vertical, então a continuidade é de 2π (rumo verdadeiro).
func _rumo(w: Basis, ant: float, primeiro: bool) -> Vector2:
	var lat := w * Vector3.RIGHT
	var r := atan2(-lat.z, lat.x)
	if primeiro:
		return Vector2(r, 0.0)
	r += TAU * roundf((ant - r) / TAU)
	var c := smoothstep(cos(deg_to_rad(RUMO_SEGURA_GRAUS)), cos(deg_to_rad(RUMO_CONFIA_GRAUS)), (w * Vector3.UP).y)
	return Vector2(ant + c * (r - ant), 1.0 if c < 1.0 else 0.0)

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
