extends SceneTree
# ============================================================================
#  CLIPES ANTIGOS INTACTOS? — original x reexportado pelo Blender (02/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/comparar_clipes_riggados.gd -- monkey_-_animated_low_poly [...]
#
#  tools/blender/clipes_riggados.py importa o modelo com ossos, soma clipes novos e exporta
#  de novo. Esta conferência garante que os clipes QUE JÁ EXISTIAM saem iguais: carrega
#  art_src/animais/originais/<id>.glb e art_src/animais/rig/<id>.glb, toca cada clipe antigo
#  (pelo nome curto, depois do último "|") em 5 instantes e compara a posição de cada osso
#  (por nome) no espaço do esqueleto. Falha se algum desviar mais que 1 % do tamanho.
# ============================================================================

const INSTANTES := [0.0, 0.25, 0.5, 0.75, 0.999]


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var falhas := 0
	for id: String in OS.get_cmdline_user_args():
		var a := BibliotecaDeModelos.carregar_glb("res://art_src/animais/originais/%s.glb" % id)
		var b := BibliotecaDeModelos.carregar_glb("res://art_src/animais/rig/%s.glb" % id)
		if a == null or b == null:
			push_error("%s: não carregou" % id)
			falhas += 1
			continue
		root.add_child(a)
		root.add_child(b)
		var ap_a := _ap(a)
		var ap_b := _ap(b)
		var sk_a := a.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var sk_b := b.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var caixa: AABB = BibliotecaDeModelos.medir(a)["aabb"]
		var tam: float = caixa.size.length()
		var novos := {}
		for n in ap_b.get_animation_list():
			novos[_curto(n)] = n
		var pior := 0.0
		var onde := ""
		for n in ap_a.get_animation_list():
			var curto := _curto(n)
			if not novos.has(curto):
				print("  FALTA no reexportado: ", curto)
				falhas += 1
				continue
			var dur := ap_a.get_animation(n).length
			for t in INSTANTES:
				_pose(ap_a, n, dur * t)
				_pose(ap_b, novos[curto], dur * t)
				for i in sk_a.get_bone_count():
					# Ponta "_end" (nó-folha do exportador original, sem peso na malha): o
					# importador do Blender não sabe onde pô-la; não deforma nada.
					if sk_a.get_bone_name(i).contains("_end"):
						continue
					var j := sk_b.find_bone(sk_a.get_bone_name(i))
					if j < 0:
						continue
					var d := (sk_a.global_transform * sk_a.get_bone_global_pose(i).origin - sk_b.global_transform * sk_b.get_bone_global_pose(j).origin).length()
					if d > pior:
						pior = d
						onde = "%s t=%.2f osso %s" % [curto, dur * t, sk_a.get_bone_name(i)]
		var ok: bool = pior <= 0.01 * tam
		falhas += int(not ok)
		print("COMPARAR %s: %d clipes antigos, pior desvio %.4f (%.2f %% do tamanho) em %s %s" % [id,
			ap_a.get_animation_list().size(), pior, 100.0 * pior / tam, onde, "OK" if ok else "FALHA"])
		a.free()
		b.free()
	quit(1 if falhas else 0)


func _ap(no: Node) -> AnimationPlayer:
	var aps := no.find_children("*", "AnimationPlayer", true, false)
	var ap := aps[0] as AnimationPlayer
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return ap


func _curto(nome: String) -> String:
	return nome.get_slice("|", nome.get_slice_count("|") - 1)


func _pose(ap: AnimationPlayer, nome: String, t: float) -> void:
	ap.play(nome)
	ap.seek(t, true)
	ap.advance(0.0)
