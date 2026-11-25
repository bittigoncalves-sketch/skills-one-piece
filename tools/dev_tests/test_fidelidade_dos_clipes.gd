extends SceneTree
# ============================================================================
#  FIDELIDADE DOS CLIPES BAKEADOS AO ORIGINAL DO MIXAMO (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_fidelidade_dos_clipes.gd
#
#  Relato do dono: "as animações do skill builder continuam a aparentar estarem bugadas,
#  além de em grande parte ficarem muito parecidas". Causa: o baker convertia as rotações
#  no espaço do ESQUELETO do .glb (girado 90° em X): giro do quadril virava tombo e o
#  antebraço saía espelhado — 28°–50° de erro médio nos golpes, até 120° nos de cobertura.
#  O teste de paridade prévia × jogo NÃO pegava (os dois tocavam o mesmo .res errado), e
#  a corrida passava (quase só giro em X, que a troca preserva). Por isso aqui a régua é o
#  .glb ORIGINAL:
#    em 21 instantes de cada clipe, a direção de cada segmento no esqueleto do Mixamo
#    (mundo, virado para −Z) × no Base tocando o .res como o jogo toca. Limites:
#      • antebraço, coxa e canela: erro médio ≤ 8°;
#      • coluna (quadril → pescoço): ≤ 15° (o nosso tronco é um bloco só);
#      • braço: o erro é a abertura do ZERO do Base (o braço dele pende aberto, o do
#        canônico reto para baixo): tem que ficar a ≤ 4° dessa abertura, medida aqui.
#  Inclui golpes que giram o corpo, a guarda, a corrida, o roll do Q e o deslize.
# ============================================================================

const Clipes := preload("res://src/skills_builder/clipes_de_skill.gd")
const CLIPES := ["running", "sprint", "punching", "kicking", "roundhouse_kick", "uppercut_jab",
	"armada", "boxing", "idle", "sprinting_forward_roll", "running_slide", "left_cover_sneak", "hard_landing"]
const INSTANTES := 21
## [osso A, osso B do Mixamo], [papel A, papel B do rig]
const SEGMENTOS := {
	"braço": [["LeftArm", "LeftForeArm"], ["UpperArm_L", "ForeArm_L"]],
	"braço D": [["RightArm", "RightForeArm"], ["UpperArm_R", "ForeArm_R"]],
	"antebraço": [["LeftForeArm", "LeftHand"], ["ForeArm_L", "#mao_L"]],
	"antebraço D": [["RightForeArm", "RightHand"], ["ForeArm_R", "#mao_R"]],
	"coxa": [["LeftUpLeg", "LeftLeg"], ["Thigh_L", "Shin_L"]],
	"coxa D": [["RightUpLeg", "RightLeg"], ["Thigh_R", "Shin_R"]],
	"canela": [["LeftLeg", "LeftFoot"], ["Shin_L", "Foot_L"]],
	"canela D": [["RightLeg", "RightFoot"], ["Shin_R", "Foot_R"]],
	"coluna": [["Hips", "Neck"], ["Torso", "Head"]],
}

var nos: Dictionary
var base: Node3D
var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modelo: Node3D = CharacterBuilder.build_character("base").node
	root.add_child(modelo)
	await process_frame
	nos = BodyScanner.scan(modelo).nodes
	base = (nos.Torso as Node3D).get_parent() as Node3D
	# A abertura do zero do Base: o braço com rotação nula × reto para baixo.
	for papel in nos:
		(nos[papel] as Node3D).rotation = Vector3.ZERO
	var abertura := rad_to_deg(_dir("UpperArm_L", "ForeArm_L").angle_to(Vector3.DOWN))
	print("abertura do braço no zero do Base: %.1f°" % abertura)
	for clipe in CLIPES:
		var e := await _erros(clipe)
		if e.is_empty():
			_ok("%s: .res e .glb existem" % clipe, false)
			continue
		var membros := maxf(maxf(e["antebraço"], e["antebraço D"]), maxf(maxf(e.coxa, e["coxa D"]), maxf(e.canela, e["canela D"])))
		var braco := maxf(absf(e["braço"] - abertura), absf(e["braço D"] - abertura))
		_ok("%-22s membros %.1f° (≤ 8) | coluna %.1f° (≤ 15) | braço a %.1f° da abertura (≤ 4)" % [clipe, membros, e.coluna, braco],
			membros <= 8.0 and e.coluna <= 15.0 and braco <= 4.0)
	print("FIDELIDADE_DOS_CLIPES %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Erro médio (graus) por segmento ao longo do clipe.
func _erros(clipe: String) -> Dictionary:
	var info := ProceduralAnimator._clipe(Clipes.caminho(clipe))
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if not info.has("anim") or doc.append_from_file(ProjectSettings.globalize_path("res://assets/animations_glb/%s.glb" % clipe), st) != OK:
		return {}
	var cena: Node3D = doc.generate_scene(st)
	root.add_child(cena)
	await process_frame
	var skel: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var nome: String = Array(ap.get_animation_list()).filter(func(n): return n != "RESET")[0]
	ap.play(nome)
	ap.pause()
	var anim: Animation = info.anim
	var soma := {}
	for k in INSTANTES:
		var t := anim.length * (k + 0.5) / INSTANTES
		ap.seek(t, true)
		_tocar(info, t)
		for seg in SEGMENTOS:
			var orig := _dir_mixamo(skel, SEGMENTOS[seg][0][0], SEGMENTOS[seg][0][1])
			var nosso := _dir(SEGMENTOS[seg][1][0], SEGMENTOS[seg][1][1])
			soma[seg] = float(soma.get(seg, 0.0)) + rad_to_deg(orig.angle_to(nosso))
	cena.queue_free()
	for seg in soma:
		soma[seg] /= INSTANTES
	return soma


## Como o jogo toca (`ProceduralAnimator._aplicar_acao` com peso 1): rotações do clipe e
## o giro do Corpo no tronco.
func _tocar(info: Dictionary, t: float) -> void:
	var anim: Animation = info.anim
	for papel in nos:
		(nos[papel] as Node3D).rotation = Vector3.ZERO
	for papel in info.faixas:
		if nos.has(papel):
			(nos[papel] as Node3D).quaternion = Quaternion.from_euler(anim.value_track_interpolate(info.faixas[papel], t))
	if info.has("giro"):
		var tronco: Node3D = nos.Torso
		tronco.basis = Basis(Vector3.UP, float(anim.value_track_interpolate(info.giro, t))) * tronco.basis


func _dir(a: String, b: String) -> Vector3:
	return (base.global_transform.basis.inverse() * (_ponto(b) - _ponto(a))).normalized()


func _ponto(nome: String) -> Vector3:
	if nome.begins_with("#mao_"):
		return (nos["ForeArm_" + nome.right(1)] as Node3D).global_transform * Vector3(0, -0.36, 0.02)
	return (nos[nome] as Node3D).global_position


## No original: poses locais compostas (o global não é refeito logo após o seek no
## headless), no mundo, viradas para −Z (o Mixamo olha +Z).
func _dir_mixamo(skel: Skeleton3D, a: String, b: String) -> Vector3:
	return (Basis(Vector3.UP, PI) * (_osso(skel, b) - _osso(skel, a))).normalized()


func _osso(skel: Skeleton3D, nome: String) -> Vector3:
	var i := skel.find_bone("mixamorig_" + nome)
	if i < 0:
		i = skel.find_bone(nome)
	var t := skel.get_bone_pose(i)
	var p := skel.get_bone_parent(i)
	while p >= 0:
		t = skel.get_bone_pose(p) * t
		p = skel.get_bone_parent(p)
	return skel.global_transform * t.origin


func _ok(texto: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
		print("  ✅ ", texto)
	else:
		_falhas += 1
		print("  ❌ ", texto)
