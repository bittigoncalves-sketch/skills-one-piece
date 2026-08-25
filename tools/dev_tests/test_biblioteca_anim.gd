extends SceneTree
# A BIBLIOTECA DE CLIPES ESTÁ INTEIRA? — varre TODO `.res`/`.tres` de
# `res://assets/animations/` e confere o contrato do `src/anim/RigContrato.gd`.
#
# POR QUE ISTO EXISTE. Duas falhas SILENCIOSAS já passaram por aqui:
#
#  • 2026-08-10 — o baker resolvia 0 ossos num esqueleto Meshy, salvava um
#    `.res` com faixas e ZERO chaves, e reportava sucesso. Só apareceu em jogo.
#  • 2026-08-25 — 12 das 13 faixas de todo clipe tinham caminho PLANO, que não
#    resolve como `NodePath`. Tocava mesmo assim (o `_apply_baked` lê a string à
#    mão), então nada reprovava — mas o dock de animação do Godot e o exportador
#    glTF ficavam de fora, e com eles o Blender.
#
# Nos dois casos o arquivo existia, o jogo rodava e nenhum teste falhava. Este
# aqui olha o que a pasta REALMENTE contém, clipe a clipe — inclusive os que
# nenhum código chama, que é como os quatro clipes de locomoção do
# `meshy_blue_block_buddy` entraram sem ninguém decidir.
#
#   godot --headless --path . -s tools/dev_tests/test_biblioteca_anim.gd

const DIR := "res://assets/animations/"
# Abaixo disto o papel não se mexe no clipe inteiro (giro geodésico máximo
# contra a primeira chave). Um clipe em que TUDO fica abaixo está congelado.
const PARADO_DEG := 1.0
# Um clipe marcado com `loop_mode` tem que fechar o ciclo. Mesmo teto do
# `FECHA_TOL_DEG` do baker.
const FECHA_TOL_DEG := 5.0

var _f := 0

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame

	# Rig real do jogo — é contra ele que os caminhos têm que resolver.
	var data := CharacterBuilder.build_character("base")
	var personagem: Node3D = data["node"]
	get_root().add_child(personagem)
	var rig: Node3D = PonteBlender.soltar_rig(personagem, get_root())
	if rig == null:
		print("❌ o rig do 'base' não tem nó 'Torso'")
		quit(1)
		return
	personagem.queue_free()

	var d := DirAccess.open(DIR)
	if d == null:
		print("❌ pasta ausente: ", DIR)
		quit(1)
		return
	var nomes := []
	for f in d.get_files():
		if f.ends_with(".res") or f.ends_with(".tres"):
			nomes.append(f)
	nomes.sort()
	if nomes.is_empty():
		print("❌ nenhum clipe em ", DIR)
		quit(1)
		return

	print("%-34s %5s %6s %7s %8s  %s" % ["clipe", "faixas", "chaves", "loop", "fecha", "veredito"])
	for f in nomes:
		_confere(String(f), rig)

	print("\n================================")
	if _f == 0:
		print("✅ BIBLIOTECA ÍNTEGRA — %d clipe(s) no contrato do RigContrato" % nomes.size())
	else:
		print("❌ %d problema(s) em %d clipe(s) varridos" % [_f, nomes.size()])
	quit(1 if _f > 0 else 0)

func _confere(arquivo: String, rig: Node3D) -> void:
	var a = load(DIR + arquivo)
	if not (a is Animation):
		_falha(arquivo, "não carregou como Animation")
		return
	var anim := a as Animation
	var problemas := []

	# 1) os 13 papéis, todos
	var papeis := {}
	for i in anim.get_track_count():
		papeis[RigContrato.papel_de(anim.track_get_path(i))] = i
	var faltando := []
	for r in RigContrato.PAPEIS:
		if not papeis.has(r):
			faltando.append(r)
	if not faltando.is_empty():
		problemas.append("sem faixa para %s" % ", ".join(faltando))

	# 2) o caminho resolve na árvore REAL do personagem
	var nao_resolve := []
	for i in anim.get_track_count():
		var alvo := String(anim.track_get_path(i)).get_slice(":", 0)
		if rig.get_node_or_null(NodePath(alvo)) == null:
			nao_resolve.append(alvo)
	if not nao_resolve.is_empty():
		problemas.append("caminho não resolve no rig: %s (reassar com tools/bake_mixamo.gd)"
			% ", ".join(nao_resolve))

	# 3) chaves de verdade, e 4) o clipe se mexe
	var chaves := 0
	var vazias := []
	var maior_amp := 0.0
	for i in anim.get_track_count():
		var n := anim.track_get_key_count(i)
		chaves += n
		if n < 2:
			vazias.append(RigContrato.papel_de(anim.track_get_path(i)))
			continue
		var base = anim.track_get_key_value(i, 0)
		if not (base is Vector3):
			continue
		var b0: Basis = Basis.from_euler(base)
		for k in range(1, n):
			var v = anim.track_get_key_value(i, k)
			if v is Vector3:
				var dd: Basis = b0.inverse() * Basis.from_euler(v)
				maior_amp = maxf(maior_amp, rad_to_deg(absf(dd.get_rotation_quaternion().get_angle())))
	if not vazias.is_empty():
		problemas.append("faixa com menos de 2 chaves: %s" % ", ".join(vazias))
	if maior_amp < PARADO_DEG:
		problemas.append("CONGELADO — nenhum papel se move (amplitude máx %.2f°)" % maior_amp)

	# 5) marcado como cíclico? então tem que fechar
	var fecha := _fechamento(anim)
	if anim.loop_mode != Animation.LOOP_NONE and fecha > FECHA_TOL_DEG:
		problemas.append("loop_mode ligado mas o ciclo abre %.2f° (teto %.1f°)" % [fecha, FECHA_TOL_DEG])

	if problemas.is_empty():
		print("%-34s %5d %6d %7s %7.2f°  ok" % [arquivo, anim.get_track_count(), chaves,
			("sim" if anim.loop_mode != Animation.LOOP_NONE else "-"), fecha])
	else:
		for p in problemas:
			_falha(arquivo, String(p))

func _fechamento(anim: Animation) -> float:
	var pior := 0.0
	for i in anim.get_track_count():
		var n := anim.track_get_key_count(i)
		if n < 2:
			continue
		var a0 = anim.track_get_key_value(i, 0)
		var b0 = anim.track_get_key_value(i, n - 1)
		if a0 is Vector3 and b0 is Vector3:
			var dd: Basis = Basis.from_euler(a0).inverse() * Basis.from_euler(b0)
			pior = maxf(pior, rad_to_deg(absf(dd.get_rotation_quaternion().get_angle())))
	return pior

func _falha(arquivo: String, msg: String) -> void:
	_f += 1
	print("%-34s  ❌ %s" % [arquivo, msg])
