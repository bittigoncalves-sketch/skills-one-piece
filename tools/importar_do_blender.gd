extends SceneTree
# ============================================================================
#  .glb  ->  .res   —  a VOLTA do Blender
#
#  Lê um `.glb` exportado pelo Blender cujos objetos se chamam como os 13
#  papéis do rig (Torso, Neck, Head, UpperArm_L, …) e grava o `.res` que o jogo
#  toca — mesmo formato que o `tools/bake_mixamo.gd` produz.
#
#  Isto fecha o ciclo aberto pelo `tools/exportar_para_blender.gd`:
#
#      .res  --exportar_para_blender-->  .glb  --[Blender]-->  .glb
#                                                                │
#            assets/animations/<nome>.res  <--importar_do_blender┘
#
#  O `bake_mixamo.gd` continua sendo o caminho do MIXAMO (esqueleto
#  `mixamorig_*`, com Skeleton3D e retarget). Este aqui é o caminho de quem
#  editou o rig do JOGO à mão.
#
#  USO
#    # um arquivo -> um .res por animação que ele contiver
#    godot --headless --path . -s tools/importar_do_blender.gd -- caminho/do/arquivo.glb
#
#    # a pasta inteira
#    godot --headless --path . -s tools/importar_do_blender.gd -- assets/blender/
#
#    # renomeando a saída (só faz sentido com 1 animação no arquivo)
#    godot --headless --path . -s tools/importar_do_blender.gd -- soco_novo.glb --nome=punching
#
#    # gravando ao lado dos originais, sem sobrescrever (usado pelos testes)
#    godot --headless --path . -s tools/importar_do_blender.gd -- x.glb --prefixo=_rt_
#
#  O QUE ELE FAZ POR DENTRO
#   1. abre o glTF e acha o AnimationPlayer;
#   2. para cada animação, converte as faixas de ROTAÇÃO (quaternion, que é
#      como o glTF grava) para faixas VALUE de Euler — o formato do jogo;
#   3. **destorce o euler chave a chave** (`_euler_continuo`): a faixa do jogo é
#      LINEAR, e sem isso duas chaves vizinhas podem sair como +179° e −179° e o
#      membro dá uma volta completa entre elas. É a mesma armadilha que o
#      `bake_mixamo` documenta como BUG C;
#   4. reescreve o caminho na forma canônica do `src/anim/RigContrato.gd`;
#   5. RECUSA o arquivo se algum papel do rig ficar sem faixa — importar meio
#      clipe é pior que não importar, porque o membro que faltou fica congelado
#      na pose de repouso e ninguém percebe até ver em jogo.
# ============================================================================

const OUT_DIR := "res://assets/animations/"
# Abaixo disto o clipe é considerado vazio (o Blender exporta faixa constante
# quando o osso não foi tocado).
# A conversão em si mora em `src/anim/PonteBlender.gd`, que o exportador e o
# teste de ida-e-volta usam também.

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var args := PackedStringArray(OS.get_cmdline_user_args())
	var nome_forcado := ""
	var prefixo := ""
	var entradas := []
	for a in args:
		if a.begins_with("--nome="):
			nome_forcado = a.substr(7)
		elif a.begins_with("--prefixo="):
			prefixo = a.substr(10)
		elif not a.begins_with("--"):
			entradas.append(a)
	if entradas.is_empty():
		print("uso: godot --headless --path . -s tools/importar_do_blender.gd -- <arquivo.glb|pasta/>")
		quit(1)
		return

	var arquivos := []
	for e in entradas:
		var abs: String = ProjectSettings.globalize_path(e) if e.begins_with("res://") else String(e)
		if DirAccess.dir_exists_absolute(abs):
			var d := DirAccess.open(abs)
			for f in d.get_files():
				if f.to_lower().ends_with(".glb") or f.to_lower().ends_with(".gltf"):
					arquivos.append(abs.path_join(f))
		elif FileAccess.file_exists(abs):
			arquivos.append(abs)
		else:
			print("  ✗ não existe: ", e)
	arquivos.sort()

	var ok := 0
	var fail := 0
	for f in arquivos:
		var r := _importa(f, nome_forcado if arquivos.size() == 1 else "", prefixo)
		ok += r.x
		fail += r.y
	print("\nIMPORT FINAL: ok=", ok, " fail=", fail)
	quit(1 if fail > 0 or ok == 0 else 0)

func _importa(glb: String, nome_forcado: String, prefixo: String = "") -> Vector2i:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb, st) != OK:
		print("  ✗ ", glb.get_file(), ": glTF não abriu")
		return Vector2i(0, 1)
	var cena = doc.generate_scene(st)
	if cena == null:
		print("  ✗ ", glb.get_file(), ": cena vazia")
		return Vector2i(0, 1)
	get_root().add_child(cena)
	var ap = PonteBlender.achar_animation_player(cena)
	if ap == null or ap.get_animation_list().is_empty():
		print("  ✗ ", glb.get_file(), ": sem AnimationPlayer ou sem animações")
		cena.queue_free()
		return Vector2i(0, 1)

	var ok := 0
	var fail := 0
	var lista: PackedStringArray = ap.get_animation_list()
	for clip in lista:
		if clip.to_lower().contains("reset"):
			continue
		# Desfaz a superamostragem, se o nome disser que ela existe.
		var id: Dictionary = PonteBlender.nome_importado(String(clip))
		var escala: float = id["escala"]
		var saida: String = nome_forcado if (nome_forcado != "" and lista.size() == 1) else String(id["nome"]).to_snake_case()
		if _converte(ap.get_animation(clip), OUT_DIR + prefixo + saida + ".res", escala):
			ok += 1
		else:
			fail += 1
	cena.queue_free()
	return Vector2i(ok, fail)

func _converte(src: Animation, out_path: String, escala: float = 1.0) -> bool:
	var r: Dictionary = PonteBlender.converter(src, escala)
	var out: Animation = r["anim"]
	if out == null:
		# RECUSA. Um papel sem faixa fica congelado na pose de repouso, e isso
		# não aparece em teste automático nenhum — só em jogo, tarde.
		var faltando: Array = r["faltando"]
		push_error("importar_do_blender: %s sem faixa para %s" % [out_path.get_file(), ", ".join(faltando)])
		print("  ✗ %s: ABORTADO — %d papel(is) sem faixa: %s"
			% [out_path.get_file(), faltando.size(), ", ".join(faltando)])
		return false

	# Decima com a MESMA tolerância do baker. Sem isto o clipe volta do Blender
	# com uma chave por quadro e o ganho de edição some na primeira ida-e-volta.
	var antes := 0
	for i in out.get_track_count():
		antes += out.track_get_key_count(i)
	var erro := PonteBlender.decimar(out)

	var err := ResourceSaver.save(out, out_path)
	if err != OK:
		print("  ✗ ", out_path.get_file(), ": ResourceSaver err=", err)
		return false
	var chaves := 0
	for i in out.get_track_count():
		chaves += out.track_get_key_count(i)
	var parados: Array = r["parados"]
	var aviso := "" if parados.is_empty() else "   ⚠ parado(s): %s" % ", ".join(parados)
	var esc := "" if is_equal_approx(escala, 1.0) else " | tempo /%.0f" % escala
	print("  ✓ %-34s (%.2fs, %d faixas, %d chaves)%s | decimado %d->%d (%.0f%%, erro %.2f°)%s"
		% [out_path.get_file(), out.length, out.get_track_count(), chaves, esc,
			antes, chaves, 100.0 * chaves / maxf(antes, 1), rad_to_deg(erro), aviso])
	return true

