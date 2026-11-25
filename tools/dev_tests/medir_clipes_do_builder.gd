extends SceneTree
# ============================================================================
#  CLIPES DO SKILLS BUILDER × O ORIGINAL DO MIXAMO — medição (07/10/2026). Não conserta.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/medir_clipes_do_builder.gd [-- clipe ...]
#
#  Relato do dono: "as animações do skill builder continuam a aparentar estarem bugadas,
#  além de em grande parte ficarem muito parecidas". Para cada clipe:
#    1. CERTO? Em 9 instantes, a direção de cada segmento (braço, antebraço, coxa, canela,
#       coluna) no esqueleto ORIGINAL (o .glb do Mixamo, no espaço do mundo, virado para
#       −Z) × no nosso boneco tocando o .res. Erro em
#       graus. O `running` (que está certo em jogo) é o controle do método.
#    2. PARECIDO? Quanto o clipe se mexe (maior ângulo de um segmento longe da 1ª pose) e
#       os pares de clipes com poses quase iguais.
# ============================================================================

const Clipes := preload("res://src/skills_builder/clipes_de_skill.gd")
const SEGMENTOS := {
	"braço E": [["mixamorig_LeftArm", "mixamorig_LeftForeArm"], ["UpperArm_L", "ForeArm_L"]],
	"antebraço E": [["mixamorig_LeftForeArm", "mixamorig_LeftHand"], ["ForeArm_L", "#mao_L"]],
	"braço D": [["mixamorig_RightArm", "mixamorig_RightForeArm"], ["UpperArm_R", "ForeArm_R"]],
	"antebraço D": [["mixamorig_RightForeArm", "mixamorig_RightHand"], ["ForeArm_R", "#mao_R"]],
	"coxa E": [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["Thigh_L", "Shin_L"]],
	"canela E": [["mixamorig_LeftLeg", "mixamorig_LeftFoot"], ["Shin_L", "Foot_L"]],
	"coxa D": [["mixamorig_RightUpLeg", "mixamorig_RightLeg"], ["Thigh_R", "Shin_R"]],
	"canela D": [["mixamorig_RightLeg", "mixamorig_RightFoot"], ["Shin_R", "Foot_R"]],
	"coluna": [["mixamorig_Hips", "mixamorig_Neck"], ["Torso", "Head"]],
	"ombros": [["mixamorig_LeftArm", "mixamorig_RightArm"], ["UpperArm_L", "UpperArm_R"]],
	"quadril": [["mixamorig_LeftUpLeg", "mixamorig_RightUpLeg"], ["Thigh_L", "Thigh_R"]],
}
## Duração padrão do bloco Animação (`dados_skill`): o que o dono vê sem mexer em nada.
const JANELA := 0.9
## Variáveis de ambiente: INSTANTES (padrão 9), PERSONAGEM (padrão base; o buggy tem
## o zero canônico, braço reto para baixo), PASTA_RES (ler os .res de outra pasta, ex.
## um bake de teste com `--saida=`).
## Registro da investigação de 07/10/2026: a coluna "cru → corrigido" comparava o .res
## sem e com a antiga correção do tronco (`endireitar`, removida com o bake v3; hoje as
## duas colunas são iguais) e a PROPOSTA é a conversão v3 calculada em memória antes de
## virar o baker. O guarda permanente é `test_fidelidade_dos_clipes.gd`.
var INSTANTES := int(OS.get_environment("INSTANTES")) if OS.has_environment("INSTANTES") else 9

var nos: Dictionary
var rest: Dictionary
var base: Node3D


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var modelo: Node3D = CharacterBuilder.build_character(OS.get_environment("PERSONAGEM") if OS.has_environment("PERSONAGEM") else "base").node
	root.add_child(modelo)
	await process_frame
	var rig := BodyScanner.scan(modelo)
	nos = rig.nodes
	rest = rig.rest
	base = (nos.Torso as Node3D).get_parent() as Node3D
	var lista: Array = OS.get_cmdline_user_args()
	if lista.is_empty():
		lista = ["running", "sprint", "idle"] + Clipes.COMBATE + Clipes.ROLAMENTO + ["walking", "jumping_up", "falling_idle", "hard_landing", "bencao", "idle_2", "idle_4"]
	var poses := {}
	var janelas := {}
	_zero_do_rig()
	print("clipe                        erro médio (cru → corrigido) | pior segmento | mexe no clipe | PROPOSTA (conversão no mundo + repouso) | duração | mexe nos 1os 0,9 s")
	for clipe: String in lista:
		var r := await _comparar(clipe)
		if r.is_empty():
			continue
		poses[clipe] = r.assinatura
		print("%-28s %5.1f° → %5.1f° | %-12s %5.1f° | %5.1f° | %5.1f° (pior %s %.1f°) | %4.2f s | %5.1f°" % [clipe, r.erro_cru, r.erro_corrigido, r.pior_nome, r.pior, r.movimento, r.erro_proposta, r.pior_prop_nome, r.pior_prop, r.duracao, r.mov_janela])
		janelas[clipe] = r.janela
		if OS.has_environment("DETALHE"):
			print("      ", r.detalhe)
	# Pares quase iguais (assinatura = direções dos segmentos nos 9 instantes).
	var nomes := poses.keys()
	var parecidos: Array[String] = []
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var d := _distancia(poses[nomes[i]], poses[nomes[j]])
			if d < 8.0:
				parecidos.append("%s ≈ %s (%.1f°)" % [nomes[i], nomes[j], d])
	print("\nPARES QUASE IGUAIS no clipe inteiro (< 8° em média): ", parecidos.size())
	for p in parecidos:
		print("   ", p)
	# O que se vê num bloco padrão: os primeiros 0,9 s.
	var nomes_j := janelas.keys()
	var iguais_j: Array[String] = []
	for i in nomes_j.size():
		for j in range(i + 1, nomes_j.size()):
			var d := _distancia(janelas[nomes_j[i]], janelas[nomes_j[j]])
			if d < 15.0:
				iguais_j.append("%s ≈ %s (%.1f°)" % [nomes_j[i], nomes_j[j], d])
	print("PARES PARECIDOS nos 1os 0,9 s (< 15° em média): ", iguais_j.size())
	for p in iguais_j:
		print("   ", p)
	quit(0)


## Erro do nosso boneco contra o original, e a assinatura do clipe.
func _comparar(clipe: String) -> Dictionary:
	var caminho := Clipes.caminho(clipe)
	if OS.has_environment("PASTA_RES"):
		caminho = OS.get_environment("PASTA_RES").path_join(clipe + ".res")
	var info := ProceduralAnimator._clipe(caminho)
	var glb := ProjectSettings.globalize_path("res://assets/animations_glb/%s.glb" % clipe)
	if not info.has("anim") or not FileAccess.file_exists(glb):
		print("%-28s (sem .res ou .glb)" % clipe)
		return {}
	# Como o baker: o .glb não passa pelo importador; abre com GLTFDocument.
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb, st) != OK:
		print("%-28s (.glb não abriu)" % clipe)
		return {}
	var cena: Node3D = doc.generate_scene(st)
	root.add_child(cena)
	await process_frame
	var skel := _achar(cena, "Skeleton3D") as Skeleton3D
	var ap := _achar(cena, "AnimationPlayer") as AnimationPlayer
	var nome_anim := ""
	for n in ap.get_animation_list():
		if n != "RESET" and (nome_anim.is_empty() or ap.get_animation(n).length > ap.get_animation(nome_anim).length):
			nome_anim = n
	ap.play(nome_anim)
	ap.pause()
	var anim: Animation = info.anim
	var corr := Quaternion.IDENTITY
	if OS.has_environment("DETALHE"):
		print("      esqueleto no mundo: euler %s escala %s (pai %s)" % [skel.global_transform.basis.get_euler() * 180.0 / PI, skel.global_transform.basis.get_scale(), skel.get_parent().name])
	var repouso_mix := _repouso_mixamo(skel)
	var soma_prop := 0.0
	var por_seg_prop := {}
	var janela: Array = []
	var mov_janela := 0.0
	var ini := {}
	for k in 10:
		ap.seek(minf(JANELA, anim.length) * k / 9.0, true)
		var o := _direcoes_mixamo(skel)
		for seg in o:
			if not ini.has(seg):
				ini[seg] = o[seg]
			mov_janela = maxf(mov_janela, rad_to_deg((ini[seg] as Vector3).angle_to(o[seg])))
			janela.append(o[seg])
	var soma_cru := 0.0
	var soma_cor := 0.0
	var n := 0
	var por_seg := {}
	var assinatura: Array = []
	var primeira := {}
	var movimento := 0.0
	for k in INSTANTES:
		var t := anim.length * (k + 0.5) / INSTANTES
		ap.seek(minf(t, ap.get_animation(nome_anim).length), true)
		var orig := _direcoes_mixamo(skel)
		var cru := _direcoes_rig(anim, info, t, Quaternion.IDENTITY)
		var cor := _direcoes_rig(anim, info, t, corr)
		var prop := _direcoes_proposta(skel, repouso_mix)
		for seg in SEGMENTOS:
			if not orig.has(seg) or not cru.has(seg):
				continue
			var e1 := rad_to_deg((orig[seg] as Vector3).angle_to(cru[seg]))
			var e2 := rad_to_deg((orig[seg] as Vector3).angle_to(cor[seg]))
			if OS.get_environment("SEG") == seg:
				print("   t=%.2f %s original %s | nosso %s | erro %.0f°" % [t, seg, _r(orig[seg]), _r(cor[seg]), e2])
			var e3 := rad_to_deg((orig[seg] as Vector3).angle_to(prop[seg]))
			soma_prop += e3
			por_seg_prop[seg] = float(por_seg_prop.get(seg, 0.0)) + e3
			soma_cru += e1
			soma_cor += e2
			n += 1
			por_seg[seg] = float(por_seg.get(seg, 0.0)) + e2
			assinatura.append(orig[seg])
			if not primeira.has(seg):
				primeira[seg] = orig[seg]
			movimento = maxf(movimento, rad_to_deg((primeira[seg] as Vector3).angle_to(orig[seg])))
	cena.queue_free()
	var pior_nome := ""
	var pior := 0.0
	for seg in por_seg:
		var m: float = por_seg[seg] / INSTANTES
		if m > pior:
			pior = m
			pior_nome = seg
	var pior_prop_nome := ""
	var pior_prop := 0.0
	for seg in por_seg_prop:
		if por_seg_prop[seg] / INSTANTES > pior_prop:
			pior_prop = por_seg_prop[seg] / INSTANTES
			pior_prop_nome = seg
	var detalhe := "dur .res %.2f / .glb %.2f |" % [anim.length, ap.get_animation(nome_anim).length]
	for seg in por_seg:
		detalhe += " %s %.0f" % [seg, por_seg[seg] / INSTANTES]
	return {"janela": janela, "mov_janela": mov_janela, "duracao": anim.length, "erro_proposta": soma_prop / maxf(n, 1), "pior_prop_nome": pior_prop_nome, "pior_prop": pior_prop, "detalhe": detalhe, "erro_cru": soma_cru / maxf(n, 1), "erro_corrigido": soma_cor / maxf(n, 1), "pior_nome": pior_nome,
		"pior": pior, "movimento": movimento, "assinatura": assinatura}


## Direções dos segmentos no ORIGINAL: poses locais compostas (o global não é refeito
## logo após o seek no headless), levadas ao mundo e viradas para −Z (o Mixamo olha +Z).
func _direcoes_mixamo(skel: Skeleton3D) -> Dictionary:
	var glob := {}
	var saida := {}
	var vira := Basis(Vector3.UP, PI)
	for seg in SEGMENTOS:
		var a := _osso(skel, SEGMENTOS[seg][0][0], glob)
		var b := _osso(skel, SEGMENTOS[seg][0][1], glob)
		if a.is_finite() and b.is_finite():
			saida[seg] = (vira * (b - a)).normalized()
	return saida


func _osso(skel: Skeleton3D, nome: String, cache: Dictionary) -> Vector3:
	var i := skel.find_bone(nome)
	if i < 0:
		i = skel.find_bone(nome.replace("mixamorig_", "mixamorig:"))
	if i < 0:
		return Vector3.INF
	var t := skel.get_bone_pose(i)
	var p := skel.get_bone_parent(i)
	while p >= 0:
		t = skel.get_bone_pose(p) * t
		p = skel.get_bone_parent(p)
	return skel.global_transform * t.origin


## Direções no NOSSO boneco tocando o .res no tempo `t` (o tronco com a correção `corr`).
func _direcoes_rig(anim: Animation, info: Dictionary, t: float, corr: Quaternion) -> Dictionary:
	for papel in nos:
		(nos[papel] as Node3D).rotation = rest.get(papel, Vector3.ZERO)
	for papel in info.faixas:
		if nos.has(papel):
			var q := Quaternion.from_euler(anim.value_track_interpolate(info.faixas[papel], t))
			if papel == "Torso":
				q = corr * q
			(nos[papel] as Node3D).quaternion = q
	if info.has("giro"):                    # como o jogo e a prévia
		var tronco := nos.Torso as Node3D
		tronco.basis = Basis(Vector3.UP, float(anim.value_track_interpolate(info.giro, t))) * tronco.basis
	var saida := {}
	var inv := base.global_transform.affine_inverse()
	for seg in SEGMENTOS:
		var a := _ponto(SEGMENTOS[seg][1][0])
		var b := _ponto(SEGMENTOS[seg][1][1])
		if a.is_finite() and b.is_finite():
			saida[seg] = (inv.basis * (b - a)).normalized()
	return saida


func _ponto(nome: String) -> Vector3:
	if nome.begins_with("#mao_"):
		var braco := nos.get("ForeArm_" + nome.right(1)) as Node3D
		return braco.global_transform * Vector3(0, -0.36, 0.02) if braco else Vector3.INF
	var n := nos.get(nome) as Node3D
	return n.global_position if n else Vector3.INF


# ---------------------------------------------------------------------------
#  PROPOSTA de conversão (o que um baker corrigido gravaria), calculada em memória:
#    W  = giro do osso desde o repouso, no MUNDO (o esqueleto do .glb está sob um nó
#         girado; o baker atual faz a conta no espaço do esqueleto);
#    Q  = do "zero" do nosso rig até o repouso do Mixamo (braços: de pendurados à pose T);
#    global do papel = virada · W · Q;  local = global(pai)⁻¹ · global(papel).
# ---------------------------------------------------------------------------
const PROP := {     # papel -> [osso, filho para a direção (ou ""), pai no rig]
	"Torso": ["Spine1", "Neck", ""], "Neck": ["Neck", "", "Torso"], "Head": ["Head", "", "Torso"],
	"UpperArm_L": ["LeftArm", "LeftForeArm", "Torso"], "ForeArm_L": ["LeftForeArm", "LeftHand", "UpperArm_L"],
	"UpperArm_R": ["RightArm", "RightForeArm", "Torso"], "ForeArm_R": ["RightForeArm", "RightHand", "UpperArm_R"],
	"Thigh_L": ["LeftUpLeg", "LeftLeg", "Torso"], "Shin_L": ["LeftLeg", "LeftFoot", "Thigh_L"], "Foot_L": ["LeftFoot", "", "Shin_L"],
	"Thigh_R": ["RightUpLeg", "RightLeg", "Torso"], "Shin_R": ["RightLeg", "RightFoot", "Thigh_R"], "Foot_R": ["RightFoot", "", "Shin_R"],
}
const FILHO_NO_RIG := {"Torso": "Neck", "UpperArm_L": "ForeArm_L", "ForeArm_L": "#mao_L", "UpperArm_R": "ForeArm_R",
	"ForeArm_R": "#mao_R", "Thigh_L": "Shin_L", "Shin_L": "Foot_L", "Thigh_R": "Shin_R", "Shin_R": "Foot_R"}
var zero_rig := {}


func _zero_do_rig() -> void:
	for papel in nos:
		(nos[papel] as Node3D).rotation = Vector3.ZERO
	var inv := base.global_transform.affine_inverse()
	for papel in FILHO_NO_RIG:
		zero_rig[papel] = (inv.basis * (_ponto(FILHO_NO_RIG[papel]) - _ponto(papel))).normalized()


func _id_mix(skel: Skeleton3D, nome: String) -> int:
	for n in ["mixamorig_" + nome, "mixamorig:" + nome, nome]:
		var i := skel.find_bone(n)
		if i >= 0:
			return i
	return -1


## Repouso no mundo virado (bases e direções) e o Q de cada papel.
func _repouso_mixamo(skel: Skeleton3D) -> Dictionary:
	var vira := Basis(Vector3.UP, PI)
	var A := skel.global_transform.basis.orthonormalized()
	var r := {}
	for papel in PROP:
		var i := _id_mix(skel, PROP[papel][0])
		var base_rest := vira * A * skel.get_bone_global_rest(i).basis.orthonormalized()
		var q := Quaternion.IDENTITY
		if str(PROP[papel][1]) != "" and zero_rig.has(papel):
			var f := _id_mix(skel, PROP[papel][1])
			var d := (vira * A * (skel.get_bone_global_rest(f).origin - skel.get_bone_global_rest(i).origin)).normalized()
			q = Quaternion(zero_rig[papel], d)
		r[papel] = {"i": i, "rest_inv": base_rest.inverse(), "q": Basis(q)}
	return r


func _direcoes_proposta(skel: Skeleton3D, rep: Dictionary) -> Dictionary:
	var vira := Basis(Vector3.UP, PI)
	var A := skel.global_transform.basis.orthonormalized()
	var glob := {}
	for papel in rep:
		var cur := vira * A * _base_global(skel, rep[papel].i)
		glob[papel] = cur * rep[papel].rest_inv * rep[papel].q
	for papel in nos:
		(nos[papel] as Node3D).rotation = Vector3.ZERO
	for papel in rep:
		var pai: String = PROP[papel][2]
		var local: Basis = glob[papel] if pai == "" else (glob[pai] as Basis).inverse() * glob[papel]
		(nos[papel] as Node3D).quaternion = local.get_rotation_quaternion()
	var saida := {}
	var inv := base.global_transform.affine_inverse()
	for seg in SEGMENTOS:
		saida[seg] = (inv.basis * (_ponto(SEGMENTOS[seg][1][1]) - _ponto(SEGMENTOS[seg][1][0]))).normalized()
	return saida


func _base_global(skel: Skeleton3D, i: int) -> Basis:
	var b := skel.get_bone_pose(i).basis
	var p := skel.get_bone_parent(i)
	while p >= 0:
		b = skel.get_bone_pose(p).basis * b
		p = skel.get_bone_parent(p)
	return b.orthonormalized()


func _r(v: Vector3) -> String:
	return "(%+.2f %+.2f %+.2f)" % [v.x, v.y, v.z]


func _distancia(a: Array, b: Array) -> float:
	var s := 0.0
	var n := mini(a.size(), b.size())
	for i in n:
		s += rad_to_deg((a[i] as Vector3).angle_to(b[i]))
	return s / maxf(n, 1)


func _achar(n: Node, classe: String) -> Node:
	if n.get_class() == classe:
		return n
	for f in n.get_children():
		var r := _achar(f, classe)
		if r:
			return r
	return null
