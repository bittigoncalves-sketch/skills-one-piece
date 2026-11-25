extends SceneTree
## Amostra o rig real e verifica continuidade/limpeza da apresentação.
const POSE = preload("res://src/historia/bosses/harpia/pose_harpia.gd")
const VENTO = preload("res://src/historia/bosses/harpia/vento_harpia.gd")
const PULSO = preload("res://src/historia/bosses/harpia/pulso_de_ar.gd")
var falhas := 0
var _pose: SkeletonModifier3D
var _sk: Skeleton3D
var _ap: AnimationPlayer

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, mensagem: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + mensagem)
	if not cond: falhas += 1

func amostra(fase: String, p: float) -> Array[Quaternion]:
	_pose.active = false
	_sk.reset_bone_poses()
	_ap.seek(.3, true)
	_pose.atualizar(fase, p, 1.0 / 60.0)
	_pose._process_modification()
	var dados: Array[Quaternion] = []
	for i in _sk.get_bone_count():
		dados.append(_sk.get_bone_pose_rotation(i))
	return dados

func diferenca(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var maior := 0.0
	for i in a.size(): maior = maxf(maior, rad_to_deg(a[i].angle_to(b[i])))
	return maior

func rodar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var bib := BibliotecaDeModelos.new("res://mapas/modelos")
	var modelo := bib.instanciar("harpia_-_animated_low_poly")
	mundo.add_child(modelo)
	_sk = modelo.find_children("*", "Skeleton3D", true, false)[0]
	_ap = modelo.find_children("*", "AnimationPlayer", true, false)[0]
	for nome in _ap.get_animation_list():
		if String(nome).to_lower().ends_with("gliding"):
			_ap.play(nome)
			_ap.pause()
			break
	_pose = POSE.new()
	_pose.montar(modelo)
	var inicio := amostra("preparar_investida", 0)
	var final := amostra("preparar_investida", 1)
	var amplitude := diferenca(inicio, final)
	ok(amplitude > 45.0, "fechamento real das asas: amplitude máxima %.2f graus" % amplitude)
	ok(diferenca(final, amostra("investida", 0)) < .1, "preparação termina na pose inicial da investida")
	var interrompida := amostra("investida", .25)
	ok(diferenca(interrompida, amostra("recuperar", 0)) < .1, "colisão precoce inicia recuperação sem salto de osso")
	var alta := amostra("preparar_vendaval", .78)
	var fim_preparo := amostra("preparar_vendaval", 1)
	var baixa := amostra("lancar_vendaval", 0)
	ok(diferenca(fim_preparo, baixa) < .1, "batida conecta ao lançamento do vendaval sem salto")
	ok(diferenca(alta, baixa) > 45, "batida move os ossos do rig, não só o efeito")
	var assentada := amostra("lancar_vendaval", 1)
	ok(diferenca(assentada, amostra("recuperar", 0)) < .1, "vendaval não reativa uma pose diferente na recuperação")
	var finito := true
	for fase in ["preparar_investida", "investida", "recuperar", "preparar_vendaval", "lancar_vendaval"]:
		for i in 61:
			for q in amostra(fase, float(i) / 60.0):
				finito = finito and q.is_finite() and absf(q.length() - 1.0) < .001
	ok(finito, "305 poses amostradas mantêm todos os ossos finitos e normalizados")
	var primeira := amostra("preparar_investida", .5)
	ok(diferenca(primeira, amostra("preparar_investida", .5)) < .1, "pose não acumula rotação ao reaplicar")
	_pose.restaurar()
	ok(not _pose.active, "cancelamento devolve o rig ao AnimationPlayer")
	var vento := VENTO.new()
	mundo.add_child(vento)
	var antes := get_node_count()
	for i in 12:
		for modo in ["preparacao", "investida", "tornado"]:
			vento.configurar(modo)
			vento.atualizar(.5, .8)
			vento.limpar()
		await process_frame
	ok(not vento.visible and not vento._audio.playing, "limpeza interrompe malhas e áudio após 36 configurações")
	vento.queue_free()
	var pulso := PULSO.new()
	mundo.add_child(pulso)
	pulso.montar(.85, true)
	await create_timer(.6).timeout
	ok(not is_instance_valid(pulso), "pulso de impacto se remove ao fim")
	ok(get_node_count() <= antes, "repetição de VFX não deixa nós residuais")
	mundo.queue_free()
	await process_frame
	print("HARPIA_APRESENTACAO_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)
