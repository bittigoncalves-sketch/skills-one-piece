extends SceneTree
# ============================================================================
#  ANIMAIS RIGGADOS NA LOJA — troca o modelo estático pelo riggado (02/10/2026).
#
#    ~/opt/blender/blender -b --python tools/blender/rig_animais.py -- cow [horse ...]
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/atualizar_animais_riggados.gd [-- cow horse]
#    "$(./find_godot.sh)" --headless --path . --import       (reimporta os .glb trocados)
#
#  Lê art_src/animais/rig/manifesto.json (gerado pelo Blender) e, para cada espécie (ou
#  só as passadas na linha de comando):
#    • copia art_src/animais/rig/<id>.glb para a loja (o original sem ossos fica em
#      art_src/animais/originais/);
#    • regrava a entrada com SHA, caixa e triângulos novos — `adicionar` preserva ficha,
#      tamanho padrão, categorias e o resto;
#    • grava na ficha o `golpe_em` (segundos até o impacto do clipe de ataque).
#  A loja é COMPARTILHADA (outra sessão grava os seabeasts): carrega do disco, grava em
#  seguida e confere a hora do catalogo.json antes e depois.
# ============================================================================

const ORIGEM := "res://art_src/animais/rig"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var manifesto: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORIGEM.path_join("manifesto.json")))
	if not (manifesto is Dictionary):
		push_error("manifesto ilegível — rode tools/blender/rig_animais.py")
		quit(1)
		return
	var pedidos := Array(OS.get_cmdline_user_args())
	var ids: Array = pedidos if not pedidos.is_empty() else (manifesto as Dictionary).keys()
	var bib := BibliotecaDeModelos.padrao()
	var catalogo := ProjectSettings.globalize_path(bib.raiz.path_join("catalogo.json"))
	var hora_antes := FileAccess.get_modified_time(catalogo)
	var erros := 0
	for id: String in ids:
		if not manifesto.has(id) or not bib.tem(id):
			push_error("%s: fora do manifesto ou da loja" % id)
			erros += 1
			continue
		var origem := ORIGEM.path_join(id + ".glb")
		var destino := bib.caminho_do_arquivo(id)
		var sha := FileAccess.get_sha256(origem)
		if sha.is_empty():
			push_error("%s: sem %s" % [id, origem])
			erros += 1
			continue
		if FileAccess.get_sha256(destino) != sha:
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(origem), ProjectSettings.globalize_path(destino)) != OK:
				push_error("%s: não copiou" % id)
				erros += 1
				continue
		var cena := BibliotecaDeModelos.carregar_glb(destino)
		if cena == null:
			push_error("%s: o Godot não leu o .glb" % id)
			erros += 1
			continue
		var medida := BibliotecaDeModelos.medir(cena)
		var clipes := _clipes(cena)
		cena.free()
		var antigo := bib.info(id)
		var caixa: AABB = medida["aabb"]
		erros += int(bib.adicionar({"id": id, "nome": antigo["nome"], "sha256": sha, "centro": caixa.get_center(),
			"tamanho": caixa.size, "triangulos": medida["triangulos"], "categorias": bib.categorias_do_modelo(id)}) != OK)
		var ficha := bib.ficha_de_animal(id)
		var ataque: Dictionary = manifesto[id]["clipes"].get("attack", {})
		if not ficha.is_empty() and ataque.has("golpe"):
			ficha["golpe_em"] = float(ataque["golpe"])
			erros += int(bib.definir_ficha_de_animal(id, ficha) != OK)
		print("RIGGADO %s: %d triângulos, caixa %s, clipes %s, golpe_em %s" % [id, medida["triangulos"],
			str(caixa.size), ", ".join(clipes), str(ficha.get("golpe_em", "-"))])
	var hora_depois := FileAccess.get_modified_time(catalogo)
	print("ANIMAIS_RIGGADOS %d espécies, erros=%d (catálogo: %d -> %d)" % [ids.size(), erros, hora_antes, hora_depois])
	quit(1 if erros else 0)


func _clipes(cena: Node) -> PackedStringArray:
	var nomes := PackedStringArray()
	for ap: AnimationPlayer in cena.find_children("*", "AnimationPlayer", true, false):
		for n in ap.get_animation_list():
			nomes.append(String(n))
	return nomes
