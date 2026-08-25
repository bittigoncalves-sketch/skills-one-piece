extends SceneTree
## PLAYER RIG (Fase 3) — prova que o corpo visível ainda é montado direito.
##
## A fronteira da fase é "o rig CONSTRÓI, o Player USA". Então isto mede as duas
## metades: o componente é dono dos nós, e as vistas do Player continuam
## entregando os mesmos objetos (senão os ~42 pontos de uso e o BukiFX quebram
## em silêncio).
var _f := 0
func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _w(4.0)
	var p: Node = null
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	var rig = p.get_node_or_null("PlayerRig")
	_ok(rig != null, "o PlayerRig esta na arvore do player")

	print("\n-- o rig e dono do corpo --")
	_ok(rig.modelo() != null, "o modelo foi construido (%s)" % rig.modelo())
	_ok(rig.procedural() != null, "o animador procedural existe")
	_ok(rig.cabeca() != null, "a cabeca foi cacheada (ancora do folego)")
	_ok(rig.pistolas().size() == 2, "duas pistolas penduradas (%d)" % rig.pistolas().size())
	_ok(rig.armas_buki().size() > 0, "arsenal da Buki montado (%d armas)" % rig.armas_buki().size())
	_ok(rig.pivo_buki() != null, "o pivo do canhao-corpo existe")

	print("\n-- as vistas do Player entregam o MESMO objeto --")
	_ok(p._char_model == rig.modelo(), "_char_model == rig.modelo()")
	_ok(p._proc_anim == rig.procedural(), "_proc_anim == rig.procedural()")
	_ok(p._head_node == rig.cabeca(), "_head_node == rig.cabeca()")
	_ok(p.character_id == rig.character_id, "character_id encaminha ('%s')" % p.character_id)
	_ok(p._buki_armas.size() == rig.armas_buki().size(), "_buki_armas encaminha")
	# O BukiFX pega o modelo de FORA, por nome. Se isto quebrar, as armas somem.
	_ok(p.get("_char_model") == rig.modelo(), "get(\"_char_model\") ainda funciona (BukiFX)")

	print("\n-- a arvore NAO mudou de forma (o rig nao virou pai) --")
	_ok(rig.modelo().get_parent() == p, "o modelo continua filho direto do Player")
	_ok(rig.pivo_buki().get_parent() == p, "o BukiPivot continua filho direto do Player")

	# -- o modelo foi medido e assentado --
	#
	# NAO da pra reconferir a altura aqui: a AABB visivel de agora ja inclui a
	# escala, as pistolas e os marcadores, entao ela nao e a altura do corpo (dava
	# 2.11 e nao 1.5). O que se pode afirmar sem inventar metrica sao as REGRAS
	# documentadas do fit. Os numeros exatos do fit foram conferidos por A/B
	# contra o commit anterior a esta fase (2026-08-11): escala
	# (0.416667, 0.416667, 0.770833) e pos.y -0.8000, identicos.
	print("\n-- as regras do fit valem --")
	var esc: Vector3 = rig.modelo().scale
	_ok(absf(esc.x - esc.y) < 0.0001, "escala X e Y iguais (%.4f)" % esc.x)
	# ⚠️ A ESPESSURA MUDOU DE LUGAR — teste reescrito em 2026-08-25.
	#
	# Ele cobrava `esc.z == esc.y * 1.85`, ou seja a espessura do voxel como
	# ESCALA DO NO. O rig deixou de fazer assim: agora a escala é UNIFORME nos
	# dois casos e o 1.85 é ASSADO NA MALHA (`PlayerModelKit.bake_depth`, que
	# multiplica o z de cada vértice e regrava o ArrayMesh).
	#
	# A troca é uma melhoria, não um descuido: escala não-uniforme no nó pai
	# distorce todo filho que gire — um braço a 90° ficaria achatado no eixo
	# errado —, e é a mesma classe de problema que já obrigava o skinnado a usar
	# escala uniforme (transform NaN -> tela cinza).
	#
	# Então a asserção certa agora é a OPOSTA da antiga: escala uniforme SEMPRE,
	# e a espessura conferida na geometria.
	_ok(absf(esc.z - esc.y) < 0.0001,
		"escala do nó UNIFORME (%.4f) — a espessura não mora mais aqui" % esc.z)
	if not rig.skinnado():
		var prof := _profundidade_do_torso(rig.modelo())
		var larg := _largura_do_torso(rig.modelo())
		_ok(prof > 0.0 and larg > 0.0, "o torso do voxel foi medido (%.3f fundo x %.3f largo)" % [prof, larg])
		# O torso da base nasce mais largo que fundo; depois do bake de 1,85x o
		# fundo tem que ter ENCOSTADO na largura. Sem número mágico: o que se
		# afirma é que o bake ACONTECEU, não um valor exato de malha.
		_ok(prof > larg * 0.8,
			"a espessura FOI ASSADA na malha: fundo/largura = %.2f (sem o bake ficaria ~%.2f)"
				% [prof / maxf(larg, 0.0001), prof / maxf(larg, 0.0001) / 1.85])
	_ok(rig.modelo().position.y <= -0.8 + 0.0001,
		"pes no fundo da colisao ou abaixo (y=%.4f)" % rig.modelo().position.y)

	print("\n-- troca de personagem reconstroi tudo --")
	var antes = rig.modelo()
	p._setup_character_model("base")
	await _w(1.0)
	_ok(rig.modelo() != null and rig.modelo() != antes, "o modelo foi refeito")
	_ok(rig.pistolas().size() == 2, "pistolas rependuradas (%d)" % rig.pistolas().size())
	_ok(p._char_model == rig.modelo(), "a vista do Player acompanhou o modelo novo")

	print("\n===== %s =====" % ("PLAYER RIG OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _ok(c: bool, m: String) -> void:
	print(("  OK  " if c else "  XX  ") + m)
	if not c: _f += 1
func _w(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec()-t < int(s*1000.0): await process_frame


# ---------------------------------------------------------------- medição
# Fundo (Z) e largura (X) do TORSO, na malha local — sem escala de nó nenhuma.
# É onde a espessura passou a morar depois do `bake_depth`.
func _profundidade_do_torso(modelo: Node3D) -> float:
	return _aabb_do_torso(modelo).size.z

func _largura_do_torso(modelo: Node3D) -> float:
	return _aabb_do_torso(modelo).size.x

func _aabb_do_torso(modelo: Node3D) -> AABB:
	if modelo == null:
		return AABB()
	var torso := modelo.find_child("Torso", true, false)
	if not (torso is MeshInstance3D):
		return AABB()
	var mesh: Mesh = (torso as MeshInstance3D).mesh
	if mesh == null:
		return AABB()
	return mesh.get_aabb()
