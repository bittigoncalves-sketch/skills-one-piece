extends SceneTree
# ============================================================================
#  CAMADA MINECRAFT — E1, fatia 1 (23/10/2026, docs/MINE_PIECE_COMPLETO_MEDICAO.md):
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_camada_minecraft.gd
#
#  A. valores (NBT, Vec3, AABB, efeitos, atributos) contra as regras do Minecraft;
#  B. o adaptador num personagem do Mine Piece vivo e no jogador (unidades em blocos, giro,
#     dano, efeitos andando por tick, atributo levando a vida ao corpo, instanceof, busca);
#  C. procedures TRADUZIDAS do mod rodando de verdade sobre eles.
# ============================================================================

const B := MundoMinePiece.METROS_POR_BLOCO

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _albedo_de(corpo: Node) -> Texture2D:
	for m: Node in corpo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var mat := (mi.get_surface_override_material(0) if mi.mesh.get_surface_count() > 0 else null) as StandardMaterial3D
		if mat == null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
		if mat != null:
			return mat.albedo_texture
	return null


func perto(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol


func rodar() -> void:
	print("\n-- A. valores --")
	var nbt := McNbt.new()
	ok(nbt.getDouble("cnt1") == 0.0 and not nbt.getBoolean("flag") and nbt.getString("x") == "", "NBT: chave ausente devolve o padrão")
	nbt.putDouble("cnt1", 10.0)
	nbt.putBoolean("flag", true)
	ok(nbt.getDouble("cnt1") == 10.0 and nbt.getBoolean("flag") and nbt.getInt("cnt1") == 10, "NBT: guarda e lê")
	var v := McVec3.de(3, 0, 4)
	ok(perto(v.length(), 5.0) and perto(v.normalize().x, 0.6) and perto(v.add(1, 2, 3).y, 2.0), "Vec3: comprimento, normalizar, somar")
	ok(perto(McVec3.de(1, 0, 0).yRot(PI / 2).z, -1.0), "Vec3.yRot: giro do Minecraft (x·cos + z·sen, z·cos − x·sen)")
	var caixa := McAabb.de_tamanho(McVec3.de(0, 0, 0), 2, 2, 2).inflate(1)
	ok(caixa.contains(1.5, 0, 0) and not caixa.contains(2.5, 0, 0), "AABB: ofSize + inflate + contains")
	var lento := Mc.efeito(&"minecraft:movement_slowdown")
	ok(lento == Mc.efeito(&"minecraft:movement_slowdown"), "efeito: um tipo por id (== funciona)")
	var i1 := McEfeito.instancia(lento, 100, 1)
	ok(not i1.atualizar(McEfeito.instancia(lento, 200, 0)) and i1.amplificador == 1 and i1.duracao == 100,
		"efeito: amplificador menor não troca")
	ok(i1.atualizar(McEfeito.instancia(lento, 300, 1)) and i1.duracao == 300, "efeito: mesmo amplificador, duração maior troca")
	var vida_max := Mc.atributo(&"minecraft:max_health")
	ok(vida_max.id == &"minecraft:generic.max_health" and vida_max.padrao == 20.0, "atributo: campo Java → id do registro, padrão 20")
	var inst := McAtributo.Instancia.new()
	inst.atributo = vida_max
	inst.base = 10.0
	for m in [["a", 2.0, &"ADDITION"], ["b", 0.5, &"MULTIPLY_BASE"], ["c", 0.1, &"MULTIPLY_TOTAL"]]:
		inst.addTransientModifier(Mc.novo(&"AttributeModifier", [m[0], m[0], m[1], m[2]]))
	ok(perto(inst.getValue(), 19.8), "atributo: (10 + 2) + 12×0,5 = 18; × 1,1 = 19,8 (%.3f)" % inst.getValue())
	inst.base = 5000.0
	ok(inst.getValue() == 1024.0, "atributo: limitado ao máximo do registro (1024)")
	ok(Mc._snake("GolDRoger") == "gol_d_roger" and Mc._snake("Arlong") == "arlong", "classe do mod → id da ficha")

	print("\n-- B. adaptador --")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_camada_minecraft.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var pers := PersonagemMinePiece.new()
	pers.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	pers.position = jogador.global_position + Vector3(0, 0, -6)
	pers.ponto_de_origem = pers.position
	current_scene.add_child(pers)
	await quadros(5)
	var ent := McEntidade.de(pers)
	var mundo: McMundo = ent.level()
	await quadros(2)
	ok(ent == McEntidade.de(pers), "um adaptador por corpo (identidade)")
	ok(perto(ent.getX(), pers.global_position.x / B) and perto(ent.getZ(), pers.global_position.z / B), "posição em blocos (m ÷ 0,88)")
	ent.setYRot(90.0)
	var olhar := ent.getViewVector(1.0)
	ok(perto(ent.getYRot(), 90.0, 0.01) and perto(olhar.x, -1.0, 0.001) and perto(olhar.z, 0.0, 0.001),
		"yRot 90 = olhando para −X, como no Minecraft (%s)" % olhar)
	var vida0 := ent.getHealth()
	ok(perto(ent.getAttribute(Mc.atributo(&"minecraft:max_health")).getValue(), float(DadosEastBlue.ficha("arlong")["vida"])),
		"MAX_HEALTH vem da ficha (%.0f)" % ent.getMaxHealth())
	ent.hurt(ent.damageSources().generic(), 5.0)
	ok(ent.getHealth() < vida0, "hurt tira vida pelo funil do jogo (%.1f → %.1f)" % [vida0, ent.getHealth()])
	ent.getAttribute(Mc.atributo(&"minecraft:max_health")).setBaseValue(200.0)
	ok(perto(pers.max_health, 200.0), "setBaseValue(MAX_HEALTH) leva a vida máxima ao corpo")
	ent.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito(&"minepiece:stun"), 40, 2]))
	ok(ent.hasEffect(Mc.efeito(&"minepiece:stun")) and ent.getEffect(Mc.efeito(&"minepiece:stun")).getAmplifier() == 2, "addEffect / hasEffect / getAmplifier")
	for t in 39:
		mundo.tick()
	var ainda := ent.hasEffect(Mc.efeito(&"minepiece:stun"))
	mundo.tick()
	ok(ainda and not ent.hasEffect(Mc.efeito(&"minepiece:stun")), "efeito de 40 ticks dura 40 ticks")
	ent.getPersistentData().putDouble("cnt1", 7.0)
	ok(McEntidade.de(pers).getPersistentData().getDouble("cnt1") == 7.0, "getPersistentData persiste no corpo")
	var ej := McEntidade.de(jogador)
	ok(Mc.e(ent, &"LivingEntity") and Mc.e(ent, &"Mob") and Mc.e(ent, &"ArlongEntity") and not Mc.e(ent, &"Player")
		and not Mc.e(ent, &"BuggyEntity"), "instanceof: personagem é LivingEntity/Mob/ArlongEntity, não Player/Buggy")
	ok(Mc.e(ej, &"Player") and Mc.e(ej, &"LivingEntity") and not Mc.e(ej, &"Mob") and Mc.e(mundo, &"ServerLevel"),
		"instanceof: jogador é Player e não Mob; o mundo é ServerLevel")
	var achados := mundo.getEntitiesOfClass(&"LivingEntity", McAabb.de_tamanho(ent.position(), 4, 4, 4), func(e): return true)
	ok(achados.has(ent) and not achados.has(ej), "getEntitiesOfClass acha o personagem e não o jogador a 6 m (%d)" % achados.size())

	print("\n-- agendador do servidor (MinepieceMod.queueServerWork) --")
	var ordem: Array = []
	Mc.estatico(&"MinepieceMod", &"queueServerWork", [3, func(): ordem.append("três")])
	Mc.estatico(&"MinepieceMod", &"queueServerWork", [1, func(): ordem.append("um")])
	Mc.estatico(&"MinepieceMod", &"queueServerWork", [0, func(): ordem.append("zero")])
	Mc.estatico(&"MinepieceMod", &"queueServerWork", [1, func():
		ordem.append("um-b")
		Mc.estatico(&"MinepieceMod", &"queueServerWork", [1, func(): ordem.append("filho")])])
	mundo.tick()
	ok(ordem == ["um", "um-b"], "tick 1: roda quem chegou a 0, na ordem em que entrou %s" % str(ordem))
	mundo.tick()
	ok(ordem == ["um", "um-b", "filho"], "trabalho agendado DENTRO de uma ação conta a partir do tick seguinte %s" % str(ordem))
	mundo.tick()
	ok(ordem == ["um", "um-b", "filho", "três"], "tick 3: o de 3 ticks roda %s" % str(ordem))
	for i in 5:
		mundo.tick()
	ok(not ("zero" in ordem), "ticks = 0 nunca roda (o contador do mod passa direto do 0)")
	ok(ordem.count("três") == 1, "cada trabalho roda UMA vez")

	print("\n-- blocos dinâmicos (setBlock) --")
	var gelo := Mc.bloco(&"minecraft:ice").defaultBlockState()
	var pos_b := McVec3.de(40.0, 12.0, 40.0)               # no ar, longe do relevo
	ok(mundo.getBlockState(pos_b).isAir(), "célula livre começa como ar")
	ok(mundo.setBlock(pos_b, gelo, 3), "setBlock(gelo) devolve true")
	await quadros(2)
	ok(mundo.getBlockState(pos_b).getBlock().id == &"minecraft:ice" and mundo.getBlockState(pos_b).isSolid(), "getBlockState lê o bloco colocado (gelo, sólido)")
	var raio := PhysicsRayQueryParameters3D.create(Vector3(40.44, 20.0, 40.44) * B, Vector3(40.44, 5.0, 40.44) * B)
	raio.collision_mask = MundoMinePiece.MASCARA_MUNDO
	var topo := get_root().get_world_3d().direct_space_state.intersect_ray(raio)
	ok(not topo.is_empty() and perto(topo.position.y, 13.0 * B, 0.01), "o bloco tem colisão: raio de cima para no topo da célula (%.3f m)" % (topo.position.y if not topo.is_empty() else -1.0))
	mundo.setBlock(pos_b, Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
	ok(mundo.getBlockState(pos_b).isAir(), "setBlock(air) tira o bloco dinâmico")
	await quadros(2)
	ok(get_root().get_world_3d().direct_space_state.intersect_ray(raio).is_empty(), "…e a colisão some")
	var fogo_pos := McVec3.de(44.0, 12.0, 40.0)
	mundo.setBlock(fogo_pos, Mc.bloco(&"minecraft:fire").defaultBlockState(), 3)
	await quadros(2)
	ok(mundo.getBlockState(fogo_pos).getBlock().id == &"minecraft:fire" and not mundo.getBlockState(fogo_pos).isSolid(), "fogo é lido como fogo e não é sólido")
	mundo.blocos.colocar(Vector3i(48, 12, 40), &"minecraft:sand", 3)
	for i in 2:
		mundo.tick()
	ok(mundo.blocos.id_em(Vector3i(48, 12, 40)) == &"minecraft:sand", "bloco com vida 3 ainda existe aos 2 ticks")
	mundo.tick()
	ok(mundo.blocos.id_em(Vector3i(48, 12, 40)) == &"", "…e some ao 3º tick (vida)")
	var antes_n := mundo.blocos.tamanho()
	for i in McBlocosDinamicos.MAX_CELULAS + 40:
		mundo.blocos.colocar(Vector3i(100 + i, 30, 100), &"minecraft:sand", -1)
	ok(mundo.blocos.tamanho() <= McBlocosDinamicos.MAX_CELULAS and mundo.blocos.id_em(Vector3i(100, 30, 100)) == &"", "teto de células: o mais antigo sai (%d)" % mundo.blocos.tamanho())
	mundo.blocos.limpar()
	ok(mundo.blocos.tamanho() == 0, "limpar() esvazia a sobreposição")

	print("\n-- bloco que cai, NBT de bloco, setblock/fill, levelEvent --")
	var tag_estado: McNbt = Mc.estatico(&"NbtUtils", &"writeBlockState", [Mc.bloco(&"minecraft:sand").defaultBlockState()])
	ok(tag_estado.getString("Name") == "minecraft:sand", "NbtUtils.writeBlockState guarda o nome do bloco")
	ok(Mc.estatico(&"Block", &"getId", [Mc.bloco(&"minecraft:sand").defaultBlockState()]) == Mc.estatico(&"Block", &"getId", [Mc.bloco(&"minecraft:sand").defaultBlockState()]), "Block.getId é estável")
	mundo.setBlock(McVec3.de(60.0, 10.0, 60.0), Mc.bloco(&"minecraft:packed_ice").defaultBlockState(), 3)     # chão do teste
	await quadros(2)
	var queda_ent: McEntidade = Mc.tipo_entidade(&"minecraft:falling_block").create(mundo)
	ok(queda_ent != null and queda_ent.no is McBlocoQueda, "EntityType falling_block.create devolve um bloco em queda")
	var tag_q := queda_ent.saveWithoutId(McNbt.new())
	Mc.por(tag_q, "BlockState", tag_estado)
	queda_ent.load(tag_q)
	ok((queda_ent.no as McBlocoQueda).bloco_id == &"minecraft:sand", "load(BlockState) troca o bloco que cai (areia)")
	queda_ent.setPos(60.5, 16.0, 60.5)
	queda_ent.setDeltaMovement(0.0, 0.0, 0.0)
	await quadros(140)
	ok(not is_instance_valid(queda_ent.no) or queda_ent.no.is_queued_for_deletion(), "o bloco em queda some ao pousar")
	ok(mundo.blocos.id_em(Vector3i(60, 11, 60)) == &"minecraft:sand", "…e vira bloco de verdade em cima do chão (areia em y=11)")
	var livres := 0
	for i in McBlocoQueda.MAX + 5:
		var q: McEntidade = Mc.tipo_entidade(&"minecraft:falling_block").create(mundo, null, null, McVec3.de(80.0, 40.0, 80.0))
		if q != null:
			livres += 1
	ok(livres == McBlocoQueda.MAX and Mc.pedidos_sem_implementacao.has("bloco:queda_cheia"), "teto de %d blocos em queda ao mesmo tempo; o excedente é contado" % McBlocoQueda.MAX)
	for n in get_nodes_in_group(McBlocoQueda.GRUPO):
		n.queue_free()
	mundo.blocos.limpar()
	await quadros(2)
	var fonte_b := McComandos.Fonte.new()
	fonte_b.mundo = mundo
	var cmd2 := mundo.getServer().getCommands()
	ok(cmd2.performPrefixedCommand(fonte_b, "setblock 70 12 70 minecraft:ice") == 1 and mundo.blocos.id_em(Vector3i(70, 12, 70)) == &"minecraft:ice", "setblock põe o bloco")
	ok(cmd2.performPrefixedCommand(fonte_b, "setblock 70 12 70 minecraft:sand keep") == 0 and mundo.blocos.id_em(Vector3i(70, 12, 70)) == &"minecraft:ice", "setblock keep não substitui")
	ok(cmd2.performPrefixedCommand(fonte_b, "fill 72 12 70 73 13 71 minecraft:packed_ice") == 8, "fill 2×2×2 = 8 blocos")
	ok(cmd2.performPrefixedCommand(fonte_b, "fill 72 12 70 73 13 71 minecraft:air replace minecraft:packed_ice") == 8 and mundo.blocos.tamanho() == 1, "fill air replace desfaz só o que casa com o filtro")
	ok(cmd2.performPrefixedCommand(fonte_b, "fill 0 0 0 40 40 40 minecraft:ice") == 0 and Mc.pedidos_sem_implementacao.has("comando:fill:grande_demais"), "fill grande demais é recusado e contado")
	Mc.pedidos_sem_implementacao.clear()
	mundo.levelEvent(2001, McVec3.de(70.0, 12.0, 70.0), 1)
	ok(not Mc.pedidos_sem_implementacao.has("visual:levelEvent:2001"), "levelEvent 2001 (quebrar bloco) tem som e poeira")
	mundo.blocos.limpar()

	print("\n-- entidades invisíveis do mod (entity_impact, haki) --")
	ok(McVisual.e_invisivel("entity_impact") and McVisual.e_invisivel("entity_armament_haki") and McVisual.e_invisivel("entity_haoshoku_haki"),
		"o renderer do mod não desenha impact nem as de haki (isBodyVisible=false, textura clear)")
	ok(McVisual.e_invisivel("entity_impact_wave") and not McVisual.e_invisivel("entity_zeus"),
		"impact_wave usa a textura clear.png do mod (invisível); zeus tem modelo e NÃO é invisível")
	print("\n-- modelos GeckoLib das entidades de efeito --")
	var com_modelo := ["tornado", "entity_bird", "entity_ice_ball", "entity_zeus", "entity_negative_hollow", "entity_haoshoku_haki_2", "entity_partisan"]
	var faltam := com_modelo.filter(func(i: String) -> bool: return McVisual.modelo_de(i) == "")
	ok(faltam.is_empty(), "os modelos convertidos existem e importam: %s" % str(faltam))
	ok(McVisual.modelo_de("kumacy").ends_with("mp_kumacy.glb"), "personagem com ficha (kumacy) usa o modelo da loja, com roupa")
	ok(McVisual.modelo_de("entity_strike") == "" and McVisual.tem_corpo("entity_strike"), "os planos do mod continuam sendo o desenho de entity_strike (precedência)")
	Mc.pedidos_sem_implementacao.clear()
	var gelo_e: McEntidade = Mc.tipo_entidade(&"minepiece:entity_ice_ball").create(mundo, null, null, McVec3.de(95.0, 20.0, 95.0))
	var gelo_no := gelo_e.no as McCorpoDoMod
	ok(gelo_no != null and gelo_no.get("_desenho") != null and not Mc.pedidos_sem_implementacao.has("visual:entidade:entity_ice_ball"),
		"entity_ice_ball nasce com corpo (sem contar falta de visual)")
	var ap := gelo_no.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ok(ap != null and ap.is_playing(), "o modelo anima no ciclo base (%s)" % (ap.current_animation if ap != null else "sem AnimationPlayer"))
	gelo_no.tocar_tecnica("spin")
	ok(ap != null and ap.current_animation.begins_with("spin"), "triggerAnim(\"spin\") toca o clipe spin (%s)" % (ap.current_animation if ap != null else ""))
	gelo_no.tocar_tecnica("empty")
	ok(ap != null and "idle" in ap.current_animation, "triggerAnim(\"empty\") volta ao ciclo base (%s)" % (ap.current_animation if ap != null else ""))
	var antes_tex := _albedo_de(gelo_no)
	gelo_e.setTexture("slash_black")
	await quadros(3)
	ok(_albedo_de(gelo_no) != antes_tex and _albedo_de(gelo_no) != null, "setTexture troca a textura do modelo")
	gelo_no.queue_free()
	Mc.pedidos_sem_implementacao.clear()
	var impacto: McEntidade = Mc.tipo_entidade(&"minepiece:entity_impact").create(mundo, null, null, McVec3.de(90.0, 20.0, 90.0))
	ok(impacto != null and not Mc.pedidos_sem_implementacao.has("visual:entidade:entity_impact"), "criar entity_impact não conta falta de visual")
	var impacto_no := impacto.no
	await quadros(60)
	ok(not is_instance_valid(impacto_no) or impacto_no.is_queued_for_deletion(), "a IA do mod roda e a entidade some sozinha (AIEntityImpact: tickCount ≥ 5 → discard)")
	ok(not Mc.pedidos_sem_implementacao.has("visual:entidade:entity_impact"), "…sem pedir desenho em nenhum momento")

	print("\n-- DecimalFormat do Java --")
	var d2 := McFormatoDecimal.de("0.##")
	ok(d2.format(3.14159) == "3.14" and d2.format(2.0) == "2" and d2.format(0.5) == "0.5" and d2.format(-1.256) == "-1.26", "0.## : 3.14159→3.14, 2→2, 0.5→0.5, −1.256→−1.26")
	ok(McFormatoDecimal.de("0.##").format(0.125) == "0.12" and McFormatoDecimal.de("0.##").format(0.135) == "0.14", "arredonda HALF_EVEN como o Java (0.125→0.12; 0.135→0.14)")
	ok(McFormatoDecimal.de("0.0").format(2) == "2.0" and McFormatoDecimal.de("#.##").format(0.5) == ".5", "0.0 mantém o zero; #.## não põe zero à esquerda (.5)")
	ok(McFormatoDecimal.de("#").format(7.5) == "8" and McFormatoDecimal.de("000").format(7) == "007", "# arredonda ao inteiro (half-even: 7.5→8); 000 completa zeros")

	print("\n-- C. procedures do mod --")
	var tamanho: float = Mc.proc(&"ReturnEntitySizeProcedure").execute(ent)
	var esperado := pow((ent.getBbHeight() + ent.getBbWidth()) * 0.42, 1.0 / 3.0)
	ok(perto(tamanho, esperado), "ReturnEntitySizeProcedure = ∛((altura + largura) × 0,42) = %.4f (%.4f)" % [esperado, tamanho])
	Mc.pedidos_sem_implementacao.clear()
	var pode: Variant = Mc.proc(&"LogicAttackProcedure").execute(mundo, ej, ent)
	# Erro de script dentro da função aborta e devolve false: o teste exige o resultado CERTO.
	ok(pode == true, "LogicAttackProcedure: o jogador pode atacar o Arlong (%s)" % str(pode))
	var ao_contrario: Variant = Mc.proc(&"LogicAttackProcedure").execute(mundo, ent, ent)
	ok(ao_contrario == false, "LogicAttackProcedure: ninguém ataca a si mesmo")
	print("  pedidos sem implementação na LogicAttack: ", Mc.pedidos_sem_implementacao)

	print("\n-- D. comandos em texto --")
	var fonte = Mc.novo(&"CommandSourceStack", [null, ent.position(), null, mundo, 4, "", null, mundo, ent])
	mundo.getServer().getCommands().performPrefixedCommand(fonte, "effect give @s minepiece:double_jump_effect infinite 4 true")
	var dj := ent.getEffect(Mc.efeito(&"minepiece:double_jump_effect"))
	ok(dj != null and dj.isInfiniteDuration() and dj.getAmplifier() == 4 and not dj.isVisible(), "effect give … infinite 4 true")
	mundo.getServer().getCommands().performPrefixedCommand(fonte, "data merge entity @s {Invulnerable:1b,NoAI:1b}")
	var vida_antes: float = ent.getHealth()
	pers.take_damage(10.0)
	ok(pers.get_meta("mc_sem_ia", false) and is_equal_approx(ent.getHealth(), vida_antes), "data merge {Invulnerable:1b,NoAI:1b}: não toma dano, cérebro para")
	mundo.getServer().getCommands().performPrefixedCommand(fonte, "data merge entity @s {Invulnerable:0b,NoAI:0b,Attributes:[{Name:generic.follow_range,Base:40.0d}]}")
	ok(not pers.get_meta("damage_immune", true) and perto(ent.getAttribute(Mc.atributo(&"minecraft:follow_range")).getValue(), 40.0),
		"data merge desliga as marcas e põe follow_range 40")
	var x0 := ent.getX()
	mundo.getServer().getCommands().performPrefixedCommand(fonte, "execute as @s run tp @s ~2 ~ ~")
	ok(perto(ent.getX(), x0 + 2.0, 0.01), "execute … run tp @s ~2 ~ ~ (2 blocos)")
	# particle / playsound: desenho e áudio de verdade (McVisual), sem contar falta; nome inválido é erro do comando original.
	Mc.pedidos_sem_implementacao.clear()
	var cmds := mundo.getServer().getCommands()
	ok(cmds.performPrefixedCommand(fonte, "particle minecraft:cloud ~ ~ ~ 1 1 1 0 10") == 10, "particle com nome vanilla desenha (10)")
	ok(cmds.performPrefixedCommand(fonte, "particle minepiece:particle_flame ~ ~1 ~ 0.2 0.2 0.2 0.1 5 force") == 5, "particle do mod com 'force' desenha (5)")
	ok(cmds.performPrefixedCommand(fonte, "particle flash") == 1, "particle só com o nome usa a posição da fonte (1)")
	ok(cmds.performPrefixedCommand(fonte, "particle dust 1 0.5 0 2 ~ ~ ~ 0.3 0.3 0.3 0 4") == 4, "particle dust leva a cor no comando (4)")
	ok(cmds.performPrefixedCommand(fonte, "particle minecraft:smoke_large ~ ~ ~ 0 0 0 0 1") == 0 and not Mc.pedidos_sem_implementacao.has("particula:minecraft:smoke_large"),
		"partícula que não existe no 1.20.1 é erro do comando, não falta nossa")
	ok(cmds.performPrefixedCommand(fonte, "playsound entity.wither.spawn master @a") == 1, "playsound com nome vanilla toca")
	ok(cmds.performPrefixedCommand(fonte, "playsound minepiece:punch master @a ~ ~ ~ 0.8 1.2") == 1, "playsound do mod com posição, volume e tom")
	ok(cmds.performPrefixedCommand(fonte, "playsound ui.toast.challenge_complete master @s") == 1, "playsound de interface (conquista) toca")
	ok(not Mc.pedidos_sem_implementacao.has("comando:particle") and not Mc.pedidos_sem_implementacao.has("comando:playsound"),
		"particle e playsound saíram da lista de comandos pendentes")
	Mc.pedidos_sem_implementacao.clear()
	cmds.performPrefixedCommand(fonte, "title @a title \"x\"")
	ok(Mc.pedidos_sem_implementacao.has("comando:title"), "comando ainda sem sistema é CONTADO (title)")
	mundo.getServer().getCommands().performPrefixedCommand(fonte, "kill @s")
	await quadros(2)
	ok(not ent.isAlive() or not is_instance_valid(pers) or pers.health <= 0.0, "kill @s")

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
