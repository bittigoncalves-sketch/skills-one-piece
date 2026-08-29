extends SceneTree
# ============================================================================
#  A CUSTOMIZAÇÃO CHEGA AO MUNDO? (pedido do dono, 2026-08-29)
#
#  Até esta data o menu de Customização era um efeito colateral da tela: o
#  jogador montava o personagem e entrava na partida com o boneco padrão. Agora
#  há UM estado (`Visual`) e UMA função que o aplica, usada pela prévia e pela
#  partida — e este teste é o que prova que os dois caminhos dão no mesmo.
#
#  O que ele mede:
#    1. TODO item do catálogo equipa no modelo DO JOGO, sem exceção
#    2. um estado completo (cabelo+boca+chapéu+máscara+raça+olho+cores)
#       sobrevive à entrada no singleplayer
#    3. a cor do cabelo que chega é a ESCOLHIDA, não a do modelo
#    4. o estado sobrevive ao disco (salvar -> zerar -> carregar)
#    5. remontar o rig (troca de personagem) NÃO perde a customização
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_visual_no_jogo.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	var modelo: Node3D = p._char_model
	if modelo == null:
		print("❌ o jogador não tem modelo"); quit(1); return

	# ---------- 1. todo item do catálogo equipa no modelo DO JOGO ----------
	# ⚠️ NO MODELO DO JOGO, não no da prévia: as duas cabeças têm profundidades
	# diferentes (docs/erros.md, 2026-08-29), e um .glb ausente ou um nó de
	# destino inexistente só aparecem como AVISO — silenciosos em partida.
	print("=== 1. todo item do catálogo equipa no modelo do jogo ===")
	var por_parte := {}
	for id in Acessorios.ids():
		var parte := Acessorios.parte_de(id)
		por_parte[parte] = int(por_parte.get(parte, 0)) + 1
		Acessorios.desequipar(modelo, parte)
		await _quadros(2)
		var no := Acessorios.equipar(modelo, id, Color(0.5, 0.3, 0.1, 1.0))
		await _quadros(2)
		if no == null or not _tem(modelo, parte, id):
			_ok("'%s' equipa" % id, false)
		else:
			_ok_n += 1
		Acessorios.desequipar(modelo, parte)
	print("   %d itens, por parte: %s" % [Acessorios.ids().size(), str(por_parte)])
	_ok("as 12 bocas estão no catálogo", int(por_parte.get("boca", 0)) == 12)
	_ok("os 12 cabelos estão no catálogo", int(por_parte.get("cabelo", 0)) == 12)

	# ⚠️ NENHUM CABELO PODE TRAZER OLHO — instrução explícita do dono. O olho é
	# do `Corpo.gd`; um cabelo que trouxesse o seu daria dois pares na cara.
	print("\n=== 2. nenhum cabelo traz olhos ===")
	var com_olho: Array[String] = []
	for id in Acessorios.por_parte("cabelo"):
		Acessorios.desequipar(modelo, "cabelo")
		await _quadros(2)
		Acessorios.equipar(modelo, id)
		await _quadros(2)
		# o olho do jogo é branco quase puro sobre pupila quase preta; um cabelo
		# que trouxesse olho teria as duas coisas dentro da própria peça
		if _tem_branco_e_preto(modelo, "cabelo", id):
			com_olho.append(id)
		Acessorios.desequipar(modelo, "cabelo")
	_ok("nenhum dos 12 cabelos tem olho embutido", com_olho.is_empty())
	if not com_olho.is_empty():
		print("      ❗ com olho: %s" % str(com_olho))

	# ---------- 3. um estado completo sobrevive ao jogo ----------
	print("\n=== 3. um personagem inteiro sobrevive à partida ===")
	Visual.acessorios = {}
	Visual.equipar("cabelo", "cabelo_moicano")
	Visual.equipar("boca", "boca_sorriso_com_dentes")
	Visual.equipar("cabeca", "cartola")
	Visual.equipar("rosto", "mascara_peste")
	Visual.raca = Racas.ids()[0]
	Visual.olho = "olho_grande"
	Visual.cor_grupo = "pele"
	Visual.cor_idx = 2
	Visual.cabelo_idx = 2                      # loiro
	Visual.aplicar(modelo, true)
	await _quadros(10)

	_ok("o cabelo (moicano) está no jogador", _tem(modelo, "cabelo", "cabelo_moicano"))
	_ok("a boca está no jogador", _tem(modelo, "boca", "boca_sorriso_com_dentes"))
	_ok("a cartola está no jogador", _tem(modelo, "cabeca", "cartola"))
	_ok("a máscara está no jogador", _tem(modelo, "rosto", "mascara_peste"))
	_ok("a raça está no jogador", _conta_marca(modelo, Racas.MARCA) > 0)
	_ok("os olhos estão no jogador", _conta_marca(modelo, Corpo.MARCA) > 0)
	_ok("chapéu e máscara convivem no jogo",
		_tem(modelo, "cabeca", "cartola") and _tem(modelo, "rosto", "mascara_peste"))

	# ---------- 4. a cor do cabelo é a ESCOLHIDA ----------
	var alvo: Color = Paleta.CABELOS[2]["cor"]
	var vista := _cor_da_peca(modelo, "cabelo", "cabelo_moicano")
	print("   cor do cabelo: escolhida %s | no jogador %s" % [str(alvo), str(vista)])
	_ok("o cabelo saiu na cor escolhida (loiro)", _perto(vista, alvo))

	# ⚠️ CONTROLE: sem ele o teste acima passaria se TODA peça saísse loira.
	var cor_cartola := _cor_da_peca(modelo, "cabeca", "cartola")
	_ok("a cartola NÃO foi tingida de loiro (só cabelo é tingível)",
		not _perto(cor_cartola, alvo))

	# ---------- 5. remontar o rig não perde nada ----------
	# É o caso real: trocar de personagem e o Gear 2 reconstroem o modelo, e a
	# peça equipada morre junto com o modelo antigo.
	print("\n=== 4. remontar o rig (troca de personagem) ===")
	p._setup_character_model(p.character_id)
	await _quadros(20)
	var m2: Node3D = p._char_model
	_ok("o cabelo sobreviveu à remontagem", _tem(m2, "cabelo", "cabelo_moicano"))
	_ok("a cartola sobreviveu à remontagem", _tem(m2, "cabeca", "cartola"))
	_ok("a boca sobreviveu à remontagem", _tem(m2, "boca", "boca_sorriso_com_dentes"))

	# ---------- 6. o disco ----------
	print("\n=== 5. a escolha sobrevive ao disco ===")
	Visual.salvar()
	var guardado := Visual.acessorios.duplicate()
	var guardado_cabelo := Visual.cabelo_idx
	Visual.acessorios = {}
	Visual.raca = ""
	Visual.olho = ""
	Visual.cabelo_idx = 0
	Visual.carregar()
	_ok("os acessórios voltaram do disco", Visual.acessorios == guardado)
	_ok("a cor do cabelo voltou do disco", Visual.cabelo_idx == guardado_cabelo)
	_ok("a raça voltou do disco", Visual.raca == Racas.ids()[0])
	_ok("o olho voltou do disco", Visual.olho == "olho_grande")

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ---------------------------------------------------------------- auxiliares
func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tem(modelo: Node, parte: String, id: String) -> bool:
	var alvo := "%s%s_%s_" % [Acessorios.MARCA, parte, id]
	for x in _todos(modelo):
		if String(x.name).begins_with(alvo):
			return true
	return false


func _conta_marca(modelo: Node, marca: String) -> int:
	var n := 0
	for x in _todos(modelo):
		if String(x.name).begins_with(marca):
			n += 1
	return n


func _raiz_da_peca(modelo: Node, parte: String, id: String) -> Node:
	var alvo := "%s%s_%s_" % [Acessorios.MARCA, parte, id]
	for x in _todos(modelo):
		if String(x.name).begins_with(alvo):
			return x
	return null


func _cor_da_peca(modelo: Node, parte: String, id: String) -> Color:
	var raiz := _raiz_da_peca(modelo, parte, id)
	if raiz == null:
		return Color(0, 0, 0, 0)
	for x in _todos(raiz):
		if not (x is MeshInstance3D):
			continue
		var mi := x as MeshInstance3D
		for si in mi.get_surface_override_material_count():
			var c := _cor_do_material(mi.get_surface_override_material(si))
			if c.a > 0.0:
				return c
	return Color(0, 0, 0, 0)


## Um par branco+preto dentro da MESMA peça é a assinatura de um olho embutido.
func _tem_branco_e_preto(modelo: Node, parte: String, id: String) -> bool:
	var raiz := _raiz_da_peca(modelo, parte, id)
	if raiz == null:
		return false
	var claro := false
	var escuro := false
	for x in _todos(raiz):
		if not (x is MeshInstance3D):
			continue
		var mi := x as MeshInstance3D
		for si in mi.get_surface_override_material_count():
			var c := _cor_do_material(mi.get_surface_override_material(si))
			if c.a <= 0.0:
				continue
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
				claro = true
			if c.r < 0.15 and c.g < 0.15 and c.b < 0.20:
				escuro = true
	return claro and escuro


func _cor_do_material(mo: Material) -> Color:
	if mo is ShaderMaterial:
		var v = (mo as ShaderMaterial).get_shader_parameter("cor")
		if v is Color:
			return v
	elif mo is BaseMaterial3D:
		return (mo as BaseMaterial3D).albedo_color
	return Color(0, 0, 0, 0)


func _perto(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _todos(n: Node) -> Array:
	var o: Array = [n]
	for f in n.get_children():
		o.append_array(_todos(f))
	return o


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
