extends SceneTree
# ============================================================================
#  .res  ->  .glb   —  a ida para o Blender
#
#  Monta o personagem `base` com um AnimationPlayer de verdade tocando os
#  clipes do jogo e exporta tudo como glTF. No Blender é
#  `File > Import > glTF 2.0` e pronto: as 13 juntas viram objetos numa
#  hierarquia, e cada clipe vira uma **Action** no Action Editor.
#
#  POR QUE ISSO SÓ FUNCIONA AGORA. As faixas dos `.res` tinham caminho PLANO
#  ("Head:rotation"), que não resolve na árvore do personagem — 12 das 13
#  faixas apontavam para lugar nenhum e o exportador glTF do Godot recusava
#  cada uma com `Cannot get node for animated track`. Desde que o baker passou
#  a gravar o caminho hierárquico do `src/anim/RigContrato.gd`
#  ("Torso/Neck/Head:rotation"), as 13 resolvem e o clipe atravessa inteiro.
#
#  USO
#    # todos os clipes num arquivo só (recomendado: 1 import, N actions)
#    godot --headless --path . -s tools/exportar_para_blender.gd
#
#    # só alguns, um arquivo por clipe
#    godot --headless --path . -s tools/exportar_para_blender.gd -- punching kicking
#
#    # outro personagem (o rig é o mesmo em todos)
#    godot --headless --path . -s tools/exportar_para_blender.gd -- --char=buggy
#
#  A VOLTA é o `tools/importar_do_blender.gd`.
#
#  ⚠️ O exportador glTF do Godot REAMOSTRA a animação — aqui a 60 fps, a mesma
#  grade do baker. O `.glb` não é bit-a-bit o `.res`; o desvio da ida-e-volta é
#  medido pelo `tools/dev_tests/test_ida_e_volta_blender.gd`. A fonte canônica
#  continua sendo o `.res`.
# ============================================================================

const OUT_DIR := "res://assets/blender/"
const ANIM_DIR := "res://assets/animations/"

# A conversão (reamostragem + esticamento do tempo) mora em
# `src/anim/PonteBlender.gd`, que o importador e o teste de ida-e-volta usam
# também. Ver o cabeçalho de lá para o porquê de cada passo.

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var args := PackedStringArray(OS.get_cmdline_user_args())
	var cid := "base"
	var alvos := []
	for a in args:
		if a.begins_with("--char="):
			cid = a.substr(7)
		elif not a.begins_with("--"):
			alvos.append(a)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	if alvos.is_empty():
		var d := DirAccess.open(ANIM_DIR)
		if d == null:
			print("✗ pasta ausente: ", ANIM_DIR)
			quit(1)
			return
		for f in d.get_files():
			if f.ends_with(".res") or f.ends_with(".tres"):
				alvos.append(f.get_basename())
		alvos.sort()
		# Todos juntos: 1 arquivo, N actions no Blender.
		var n := await _exporta(cid, alvos, OUT_DIR + "rig_%s_completo.glb" % cid)
		print("\nFEITO: %d clipe(s) em %s" % [n, OUT_DIR + "rig_%s_completo.glb" % cid])
		quit(0 if n > 0 else 1)
		return

	var ok := 0
	for nome in alvos:
		ok += 1 if await _exporta(cid, [nome], OUT_DIR + nome + ".glb") > 0 else 0
	print("\nFEITO: %d de %d" % [ok, alvos.size()])
	quit(0 if ok == alvos.size() else 1)

# Monta modelo + AnimationPlayer e grava o .glb. Devolve quantos clipes entraram.
func _exporta(cid: String, nomes: Array, out_path: String) -> int:
	var data := CharacterBuilder.build_character(cid)
	var personagem: Node3D = data["node"]
	get_root().add_child(personagem)
	# A raiz exportada é o nó que tem o `Torso` como filho direto — ver
	# `PonteBlender.soltar_rig` para o porquê (uma raiz errada faz o exportador
	# descartar as faixas EM SILÊNCIO e gravar o arquivo assim mesmo).
	var raiz: Node3D = PonteBlender.soltar_rig(personagem, get_root())
	if raiz == null:
		print("  ✗ ", cid, ": sem nó 'Torso' — não é um rig de 13 papéis")
		personagem.queue_free()
		return 0
	raiz.name = "SkillsOnePiece_%s" % cid
	var modelo := raiz
	personagem.queue_free()

	var lib := AnimationLibrary.new()
	var entraram := 0
	var faltando := []
	for nome in nomes:
		var anim: Animation = _carrega(String(nome))
		if anim == null:
			faltando.append(nome)
			continue
		# Confere que TODA faixa resolve — é exatamente o que o exportador glTF
		# exige, e falhar aqui com nome é melhor que 13 erros anônimos depois.
		var sem_no := []
		for i in anim.get_track_count():
			var alvo := String(anim.track_get_path(i)).get_slice(":", 0)
			if modelo.get_node_or_null(NodePath(alvo)) == null:
				sem_no.append(alvo)
		if not sem_no.is_empty():
			print("  ⚠ %s: %d faixa(s) sem nó no rig -> %s  (reassar: tools/bake_mixamo.gd)"
				% [nome, sem_no.size(), ", ".join(sem_no)])
		lib.add_animation(PonteBlender.nome_exportado(String(nome)), PonteBlender.preparar(anim))
		entraram += 1
	if not faltando.is_empty():
		print("  ✗ não encontrados: ", ", ".join(faltando))
	if entraram == 0:
		raiz.queue_free()
		return 0

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	modelo.add_child(ap)
	ap.add_animation_library("", lib)
	ap.root_node = NodePath("..")   # os caminhos do clipe começam em "Torso"

	_adota(raiz, raiz)
	await process_frame

	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(raiz, st)
	if err != OK:
		print("  ✗ ", out_path.get_file(), ": append_from_scene err=", err)
		raiz.queue_free()
		return 0
	err = doc.write_to_filesystem(st, ProjectSettings.globalize_path(out_path))
	if err != OK:
		print("  ✗ ", out_path.get_file(), ": write err=", err)
		raiz.queue_free()
		return 0
	var conf := _confere(out_path, entraram)
	print("  %s %-32s %d clipe(s), personagem '%s'%s" % [
		"✓" if conf.x == entraram and conf.y == 13 else "⚠", out_path.get_file(), entraram, cid,
		"  [reimport: %d clipe(s), %d faixas no 1º]" % [conf.x, conf.y]])
	raiz.queue_free()
	return entraram

# Reabre o .glb recém-escrito e conta o que sobreviveu. Sem isto, uma faixa
# descartada pelo exportador some sem aviso — e o arquivo continua sendo gravado.
func _confere(path: String, esperados: int) -> Vector2i:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
		return Vector2i(0, 0)
	var cena = doc.generate_scene(st)
	if cena == null:
		return Vector2i(0, 0)
	var ap = PonteBlender.achar_animation_player(cena)
	if ap == null:
		return Vector2i(0, 0)
	var lista: PackedStringArray = ap.get_animation_list()
	var faixas := 0
	if lista.size() > 0:
		faixas = (ap.get_animation(lista[0]) as Animation).get_track_count()
	return Vector2i(lista.size(), faixas)

func _carrega(nome: String) -> Animation:
	for ext in [".res", ".tres"]:
		var p: String = ANIM_DIR + nome + ext
		if ResourceLoader.exists(p):
			var a = load(p)
			if a is Animation:
				return a
	return null

# O exportador glTF percorre a cena pelo `owner`; sem isso só a raiz sai.
func _adota(n: Node, dono: Node) -> void:
	for c in n.get_children():
		c.owner = dono
		_adota(c, dono)
