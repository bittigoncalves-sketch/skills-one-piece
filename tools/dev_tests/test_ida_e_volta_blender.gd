extends SceneTree
# IDA E VOLTA: .res -> .glb -> .res, e mede se a POSE sobreviveu.
#
# É o critério de aceite da Fase 1 de docs/AUDITORIA_ANIMACAO.md: um clipe do
# jogo tem que poder ir ao Blender, voltar, e continuar sendo o mesmo movimento.
#
# O ciclo inteiro roda AQUI, em memória, pela MESMA `src/anim/PonteBlender.gd`
# que o `tools/exportar_para_blender.gd` e o `tools/importar_do_blender.gd`
# usam. Reimplementar a conversão no teste o deixaria passar com as ferramentas
# quebradas.
#
# Mede em ROTAÇÃO (geodésica), não em euler: desdobrar o euler muda o número sem
# o membro se mexer, e isso já enganou uma medição neste projeto.
#
#   godot --headless --path . -s tools/dev_tests/test_ida_e_volta_blender.gd
#   godot --headless --path . -s tools/dev_tests/test_ida_e_volta_blender.gd -- punching kicking

# Teto do desvio. O transporte glTF em si é exato (medido: 0,000° nos 33), então
# o que sobra aqui é a DECIMAÇÃO que o importador aplica na volta — limitada por
# construção a `PonteBlender.DECIMA_TOL_DEG`. O teto é essa tolerância com folga
# para o dia em que um clipe novo tiver movimento mais rápido que tudo que há
# hoje; não é espaço para acomodar regressão.
const TETO_DEG := PonteBlender.DECIMA_TOL_DEG * 3.0
const ANIM_DIR := "res://assets/animations/"
const TMP := "user://ida_e_volta_teste.glb"

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var alvos := []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			alvos.append(a)
	if alvos.is_empty():
		var d := DirAccess.open(ANIM_DIR)
		for f in d.get_files():
			if (f.ends_with(".res") or f.ends_with(".tres")) and not f.begins_with("_"):
				alvos.append(f.get_basename())
		alvos.sort()

	# Rig do personagem, montado UMA vez. Os clipes viajam todos no mesmo .glb.
	var data := CharacterBuilder.build_character("base")
	var personagem: Node3D = data["node"]
	get_root().add_child(personagem)
	var raiz: Node3D = PonteBlender.soltar_rig(personagem, get_root())
	if raiz == null:
		print("❌ o rig do 'base' não tem nó 'Torso'")
		quit(1)
		return
	personagem.queue_free()

	var originais := {}
	var lib := AnimationLibrary.new()
	for nome in alvos:
		var a := _carrega(String(nome))
		if a == null:
			continue
		originais[nome] = a
		lib.add_animation(PonteBlender.nome_exportado(String(nome)), PonteBlender.preparar(a))
	if originais.is_empty():
		print("❌ nenhum clipe carregado de ", ANIM_DIR)
		quit(1)
		return

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	raiz.add_child(ap)
	ap.add_animation_library("", lib)
	ap.root_node = NodePath("..")
	_adota(raiz, raiz)
	await process_frame

	# ---- IDA ----
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_scene(raiz, st) != OK:
		print("❌ append_from_scene falhou")
		quit(1)
		return
	var caminho := ProjectSettings.globalize_path(TMP)
	if doc.write_to_filesystem(st, caminho) != OK:
		print("❌ write_to_filesystem falhou")
		quit(1)
		return

	# ---- VOLTA ----
	var st2 := GLTFState.new()
	var doc2 := GLTFDocument.new()
	if doc2.append_from_file(caminho, st2) != OK:
		print("❌ o .glb escrito não reabriu")
		quit(1)
		return
	var cena = doc2.generate_scene(st2)
	var ap2 := PonteBlender.achar_animation_player(cena)
	if ap2 == null:
		print("❌ o .glb voltou sem AnimationPlayer — nenhuma faixa sobreviveu")
		quit(1)
		return

	var voltaram := {}
	for clip in ap2.get_animation_list():
		var id: Dictionary = PonteBlender.nome_importado(String(clip))
		var r: Dictionary = PonteBlender.converter(ap2.get_animation(clip), float(id["escala"]))
		if r["anim"] == null:
			print("  ✗ ", id["nome"], ": voltou sem os papéis ", ", ".join(r["faltando"]))
			continue
		# o importador decima na volta — o teste tem que medir o arquivo que a
		# ferramenta de fato grava, não uma versão idealizada dele
		PonteBlender.decimar(r["anim"])
		voltaram[String(id["nome"])] = r["anim"]

	# ---- COMPARAÇÃO ----
	var falhas := 0
	print("clipe                        dur_ida  dur_volta   desvio     papel        instante")
	for nome in alvos:
		if not originais.has(nome):
			continue
		if not voltaram.has(nome):
			print("%-28s  NÃO VOLTOU  ❌" % nome)
			falhas += 1
			continue
		var a: Animation = originais[nome]
		var b: Animation = voltaram[nome]
		var c: Dictionary = PonteBlender.comparar(a, b)
		var desvio: float = c["desvio"]
		var dur_ok: bool = absf(a.length - b.length) < 0.02
		var mau: bool = desvio > TETO_DEG or not dur_ok
		if mau:
			falhas += 1
		print("%-28s %7.3fs  %7.3fs  %7.3f°%s  %-11s t=%.3fs" % [
			nome, a.length, b.length, desvio, "  ❌" if mau else "  ✓",
			c["papel"], c["t"]])

	DirAccess.remove_absolute(caminho)
	# solta as malhas antes do quit — senão o renderizador headless reclama de
	# RIDs vazadas na saída e polui o log do validar.sh
	if is_instance_valid(cena):
		cena.queue_free()
	raiz.queue_free()
	await process_frame
	print("\n================================")
	if falhas == 0:
		print("✅ IDA E VOLTA pelo Blender preserva a pose em %d clipes (teto %.1f°)"
			% [originais.size(), TETO_DEG])
		print("   (o transporte glTF é exato; o desvio impresso é a decimação de %.1f° da volta)"
			% PonteBlender.DECIMA_TOL_DEG)
	else:
		print("❌ ", falhas, " clipe(s) fora do teto de ", TETO_DEG, "°")
	quit(1 if falhas > 0 else 0)

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
