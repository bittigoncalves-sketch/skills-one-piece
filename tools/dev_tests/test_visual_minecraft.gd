extends SceneTree
## Visual Minecraft (12/11/2026): texturas de bloco, UV da malha, fonte bitmap e meios corações do HUD.
## godot --headless --path . --script tools/dev_tests/test_visual_minecraft.gd
var ok := 0
var falhas := 0

func confere(c: bool, m: String) -> void:
	if c:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", m)

func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	TiposDeBloco.iniciar()
	TexturasDeBloco.iniciar()
	var com_textura := TexturasDeBloco.tem_textura()
	print("texturas locais: ", com_textura)
	if com_textura:
		var topo := TexturasDeBloco.camada(TiposDeBloco.GRAMA, 3)
		var lado := TexturasDeBloco.camada(TiposDeBloco.GRAMA, 1)
		var base := TexturasDeBloco.camada(TiposDeBloco.GRAMA, 2)
		confere(topo >= 0 and lado >= 0 and base >= 0 and topo != lado and lado != base, "grama: topo, lado e base são camadas diferentes")
		confere(base == TexturasDeBloco.camada(TiposDeBloco.TERRA, 3), "a base da grama é a terra (mesma camada)")
		confere(TexturasDeBloco.camada(TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA, 3) == TexturasDeBloco.camada(TiposDeBloco.PEDRA, 3), "laje herda a textura do cubo")
		confere(TexturasDeBloco.camada(TiposDeBloco.TRONCO, 3) != TexturasDeBloco.camada(TiposDeBloco.TRONCO, 1), "tronco: topo ≠ casca")
		confere(TexturasDeBloco.camada(TiposDeBloco.PORTA_MADEIRA, 1, 16) != TexturasDeBloco.camada(TiposDeBloco.PORTA_MADEIRA, 1, 0), "porta: metade de cima ≠ de baixo")
		confere(TexturasDeBloco.matriz.get_layers() >= 10, "a matriz tem camadas")
	# meta do dono: pelo menos 64 blocos novos, todos com nome, textura e dureza
	var extras := BlocosExtras.todas()
	confere(extras.size() >= 64, "pelo menos 64 blocos extras (%d)" % extras.size())
	var ids_vistos := {}
	var nomes_vistos := {}
	var sem_textura := []
	for d: Dictionary in extras:
		confere(not ids_vistos.has(d.id) and not nomes_vistos.has(d.nome), "id/nome únicos: %s" % d.nome) if ids_vistos.has(d.id) or nomes_vistos.has(d.nome) else null
		ids_vistos[d.id] = true
		nomes_vistos[d.nome] = true
		confere(TiposDeBloco.nome[d.id] == d.nome and TiposDeBloco.forma[d.id] == TiposDeBloco.Forma.CUBO, "registrado: %s" % d.nome)
		if com_textura and TexturasDeBloco.camada(d.id, 3) < 0:
			sem_textura.append(d.nome)
	confere(sem_textura.is_empty(), "todo bloco extra tem textura (faltam: %s)" % str(sem_textura))
	confere(ItensDeBloco.tempo_de_quebra(TiposDeBloco.valor(extras[0].id)) > 0.0, "bloco extra quebra")
	# UV em unidades de bloco: dois pontos a 1 bloco de distância diferem 1.0 em u
	var b := GradeVoxel.BLOCO
	var u0 := GradeVoxel._uv_do_ponto(Vector3(0, 0, 0), Vector3.UP)
	var u1 := GradeVoxel._uv_do_ponto(Vector3(b, 0, b), Vector3.UP)
	confere(is_equal_approx(u1.x - u0.x, 1.0) and is_equal_approx(u1.y - u0.y, 1.0), "UV do topo em unidades de bloco")
	var l0 := GradeVoxel._uv_do_ponto(Vector3(0, b, 0), Vector3.RIGHT)
	var l1 := GradeVoxel._uv_do_ponto(Vector3(0, 0, 0), Vector3.RIGHT)
	confere(is_equal_approx(l1.y - l0.y, 1.0), "UV lateral: v cresce para BAIXO (a imagem)")
	# a malha leva UV e camada
	var s := PackedInt32Array()
	s.resize(GradeVoxel.VOLUME)
	s[0] = TiposDeBloco.GRAMA
	var viz: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	var r := GradeVoxel.malhar(s, viz)
	confere(r["vertices"].size() == 36 and r["uv"].size() == 36 and r["uv2"].size() == 36, "cubo: 36 vértices, 36 UV, 36 camadas")
	# fonte
	var f := FonteMinecraft.fonte()
	if f != null:
		var wi := f.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var wm := f.get_string_size("m", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		confere(wi < wm, "'i' é mais estreito que 'm' (largura variável do vanilla: %.0f < %.0f)" % [wi, wm])
		confere(f.get_string_size("ç", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 0.0, "o 'ç' existe na fonte (acentos)")
		confere(f.get_string_size("é", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 0.0, "o 'é' existe na fonte")
	# meios corações
	confere(HudMinecraft._meios(1.0) == 20 and HudMinecraft._meios(0.0) == 0 and HudMinecraft._meios(0.001) == 1, "meios corações: cheio 20, morto 0, 1 HP ainda mostra meio")
	confere(HudMinecraft._meios(0.5) == 10, "metade da vida = 5 corações")
	print("VISUAL_MINECRAFT ok=%d falhas=%d" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
