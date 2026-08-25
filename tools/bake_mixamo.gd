extends SceneTree
# Baker de animações Mixamo/Meshy -> rig por-nós do jogo.
# Bakeia .glb de res://assets/animations_glb/ para
# res://assets/animations/<nome>.res. O formato da faixa está em
# `src/anim/RigContrato.gd` — NodePath("Torso/Neck/Head:rotation"), hierárquico,
# que é o que faz o clipe RESOLVER na árvore do personagem (e portanto exportar
# para glTF/Blender). Tocável por ProceduralAnimator.play_baked() e por um
# AnimationPlayer comum.
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

# O CONTRATO DO RIG (papéis, hierarquia, aliases de osso) mora em
# `src/anim/RigContrato.gd` — a mesma fonte que o `SkeletonDriver` usa em jogo.
# Tinha uma cópia aqui, e a cópia discordava da árvore real dos modelos
# (`Head` sob `Torso` em vez de sob `Neck`): era o bug dos 64° de rotação
# parasita na cabeça, medido por `tools/dev_tests/medir_erro_cabeca.gd`.
const MAP := RigContrato.ALIASES
const PAI := RigContrato.PAI

const SRC_DIR := "res://assets/animations_glb/"
const OUT_DIR := "res://assets/animations/"
# O ALERTA é sobre GIMBAL, não sobre velocidade.
#
# `_euler_continuo` (BUG C, no fim do arquivo) desfaz o giro parasita: quando a
# rotação cruza uma singularidade do euler, duas chaves vizinhas podem sair como
# +179° e −179°, e a faixa LINEAR faz o caminho longo — o membro dá uma volta
# completa entre dois quadros. O baker imprime o par `euler cru -> destorcido`
# justamente para mostrar o conserto agindo (ex.: 358,8° -> 83,5°). Se o
# destorcido continuar perto de uma volta, o conserto FALHOU, e é isso que
# merece alarme.
#
# ⚠️ Já tentei alertar pelo tamanho do salto entre chaves vizinhas — nas duas
# formas, euler e geodésica. Não serve, e a razão é estrutural: a decimação
# afasta as chaves DE PROPÓSITO, e o que ela garante é o ERRO DE POSE (≤ 1°),
# não o espaçamento. Um chute rápido tem 71° de giro real entre duas chaves e
# está perfeito. Alertar por aí marcava 8 clipes sadios em 33.
#   Quem mede qualidade depois da decimação é o `erro` impresso na mesma linha.
const GIMBAL_ALERTA_DEG := 180.0
# Taxa de amostragem do bake. A faixa é LINEAR, então a densidade de chaves é o
# ÚNICO controle sobre o erro de interpolação: dobrar o fps corta o desvio pela
# metade. A 30 fps os socos Meshy percorriam até 34.5° de giro real entre duas
# chaves (movimento rápido de verdade, não gimbal); a 60 fps caem para 17.2°.
# Custo: 2× chaves num arquivo de dezenas de KB. Os 28 .res antigos ficaram a
# 30 fps — só mudam se forem reassados.
const BAKE_FPS := 60.0
# Tolerância da DECIMAÇÃO, em graus. Depois de amostrar a 60 fps, o baker joga
# fora toda chave que a reta entre as vizinhas mantidas já reproduz dentro desta
# margem — o mesmo critério de erro que o `medir_pose_res.gd` usa para provar que
# um rebake não mexeu no movimento.
#
# POR QUE DECIMAR. Amostrar todo frame de toda faixa dava 54.548 chaves nos 29
# clipes — 145 por osso. Ninguém ajusta uma curva de 145 chaves, nem no Blender
# nem no `tools/anim_editor`. A 1° sobram 12.659 (23%), ~34 por osso, e a pose
# não muda mais que 1° em NENHUM instante. Medido por
# `tools/dev_tests/medir_reducao_chaves.gd`.
#
# Passe 0.0 para desligar:  godot ... -s tools/bake_mixamo.gd -- --sem-decimar
# A implementação mora em `PonteBlender.decimar_faixa` — o importador do Blender
# usa a mesma, senão um clipe que vai ao Blender e volta chega denso outra vez e
# o ganho de edição some.
const DECIMA_TOL_DEG := PonteBlender.DECIMA_TOL_DEG

# Clipes que CICLAM. O `loop_mode` não é cosmético: é o que o exportador glTF
# leva para o Blender e o que um `AnimationPlayer` obedece. Ficava `LOOP_NONE`
# em todos os 29, inclusive no idle de combate.
#
# A lista é explícita de propósito — fechar bem o ciclo (o `boxing` fecha em
# 0,00°) NÃO quer dizer que o clipe deva ciclar. O baker confere: se um clipe
# desta lista não fechar dentro de FECHA_TOL_DEG, ele avisa.
# `running` está aqui de propósito mesmo abrindo 12,05°: é um ciclo de corrida,
# DEVE ciclar, e o aviso do baker é o jeito de a falha do clipe de origem ficar
# visível em vez de virar um `loop_mode` errado gravado em silêncio. O conserto
# dele é no Blender, pelo caminho da Fase 1.
const CICLICOS := [
	"bouncing_fight_idle",   # idle de combate
	"alert",                 # pose de alerta (fecha em 0,00°)
	"walking",               # ciclo de caminhada
	"running",               # ciclo de corrida
	"walk_backward_inplace", # ciclo de andar de ré
]
const FECHA_TOL_DEG := 5.0

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
		for alias in MAP[papel]:
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
		out.track_set_path(ti, RigContrato.faixa(papel))   # "Torso/Neck/Head:rotation"
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
			var par: String = PAI[papel]
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

	# ---- DECIMAÇÃO: joga fora a chave que a reta entre as vizinhas já dá ----
	var tol: float = 0.0 if OS.get_cmdline_user_args().has("--sem-decimar") else DECIMA_TOL_DEG
	var antes := chaves
	var erro_max := 0.0
	if tol > 0.0:
		for ti in tracks.values():
			erro_max = maxf(erro_max, PonteBlender.decimar_faixa(out, ti, deg_to_rad(tol)))
		chaves = 0
		for ti in tracks.values():
			chaves += out.track_get_key_count(ti)

	# Giro geodésico entre chaves vizinhas do arquivo final. É INFORMAÇÃO (quão
	# rápido o clipe se move), não critério — ver GIMBAL_ALERTA_DEG.
	var salto_final := 0.0
	var salto_papel := ""
	for papel in tracks:
		var ti: int = tracks[papel]
		for k in range(1, out.track_get_key_count(ti)):
			var va = out.track_get_key_value(ti, k - 1)
			var vb = out.track_get_key_value(ti, k)
			if va is Vector3 and vb is Vector3:
				var dd: Basis = Basis.from_euler(va).inverse() * Basis.from_euler(vb)
				var g := absf(dd.get_rotation_quaternion().get_angle())
				if g > salto_final:
					salto_final = g
					salto_papel = papel

	# ---- LOOP: só os clipes da lista, e só se o ciclo de fato fechar ----
	var nome := out_path.get_file().get_basename()
	var fecha := _fechamento(out)
	if CICLICOS.has(nome):
		if rad_to_deg(fecha) <= FECHA_TOL_DEG:
			out.loop_mode = Animation.LOOP_LINEAR
		else:
			print("  ⚠ ", nome, ": marcado como cíclico mas o ciclo abre %.2f° — loop NÃO aplicado" % rad_to_deg(fecha))

	var err := ResourceSaver.save(out, out_path)
	if err == OK:
		var aviso := ("   <<< GIMBAL: o euler não destorceu (%.1f°) — o membro vai dar uma volta"
			% rad_to_deg(salto_max)) if rad_to_deg(salto_max) > GIMBAL_ALERTA_DEG else ""
		var dec := "" if tol <= 0.0 else " | decimado %d->%d (%.0f%%, erro %.2f°)" % [
			antes, chaves, 100.0 * chaves / antes, rad_to_deg(erro_max)]
		var lp := "  [LOOP]" if out.loop_mode != Animation.LOOP_NONE else ""
		print("  ✓ %-34s %.2fs %3df | euler cru %5.1f° -> destorcido %5.1f° | giro máx/chave %5.1f° (%s)%s%s%s"
			% [out_path.get_file(), dur, n, rad_to_deg(salto_cru), rad_to_deg(salto_max),
				rad_to_deg(salto_final), salto_papel, dec, lp, aviso])
	else:
		print("  ✗ ", out_path.get_file(), ": ResourceSaver err=", err)
	return err == OK

# Maior abertura do ciclo: distância angular entre a PRIMEIRA e a ÚLTIMA chave,
# no pior papel. Zero = a última pose casa com a primeira e o clipe cicla limpo.
func _fechamento(anim: Animation) -> float:
	var pior := 0.0
	for i in anim.get_track_count():
		var n := anim.track_get_key_count(i)
		if n < 2:
			continue
		var a = anim.track_get_key_value(i, 0)
		var b = anim.track_get_key_value(i, n - 1)
		if a is Vector3 and b is Vector3:
			var d: Basis = Basis.from_euler(a).inverse() * Basis.from_euler(b)
			pior = maxf(pior, absf(d.get_rotation_quaternion().get_angle()))
	return pior

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
