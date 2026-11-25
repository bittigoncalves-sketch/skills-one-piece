extends SceneTree
# ============================================================================
#  ANIMAÇÕES DO MOD NO CORPO DO JOGADOR (03/11/2026): pacote MinepieceModAnimationMessage → AnimacaoDoMod → meta
#  `pose_do_mod` → ProceduralAnimator → nós do rig. Mede a DIREÇÃO do braço no rig, não só que o meta existe.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_animacao_do_mod.gd
# ============================================================================
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

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_animacao_do_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ej := McEntidade.de(jogador)
	var proc = jogador.get("_proc_anim")
	ok(proc != null, "o jogador tem o animador procedural (rig voxel)")
	var braco: Node3D = proc._n.get("UpperArm_R") if proc != null else null
	ok(braco != null, "o rig tem o papel UpperArm_R")
	await quadros(30)
	var repouso: Vector3 = braco.basis * Vector3.DOWN
	ok(jogador.get_node_or_null("AnimacaoDoMod") == null, "sem pacote: nenhum nó de animação do mod")

	# 1) o pacote do mod, pela rede da camada
	var msg = Mc.novo(&"MinepieceModAnimationMessage", ["right_arm_front", ej.getId(), true])
	McRede.instancia().send(null, msg)
	var no: AnimacaoDoMod = jogador.get_node_or_null("AnimacaoDoMod")
	ok(no != null and no.clipe == "right_arm_front", "o pacote criou o nó e começou o clipe")
	await quadros(6)                       # 0,1 s: dentro do clipe (dura 0,25 s)
	var dir: Vector3 = braco.basis * Vector3.DOWN
	ok(jogador.has_meta("pose_do_mod"), "o meta pose_do_mod está publicado")
	ok(dir.distance_to(repouso) > 0.8, "o braço direito saiu do repouso no rig (Δ=%.2f)" % dir.distance_to(repouso))
	ok(dir.dot(Vector3.FORWARD) > 0.6 or dir.dot(Vector3.BACK) > 0.6, "o braço aponta ao longo do eixo da frente do corpo (%.2f)" % dir.z)
	# 2) override=false não troca o clipe ativo; override=true troca
	McRede.instancia().send(null, Mc.novo(&"MinepieceModAnimationMessage", ["both_arm_up", ej.getId(), false]))
	ok(no.clipe == "right_arm_front", "override=falso não interrompe o clipe ativo")
	McRede.instancia().send(null, Mc.novo(&"MinepieceModAnimationMessage", ["both_arm_up", ej.getId(), true]))
	ok(no.clipe == "both_arm_up", "override=verdadeiro troca o clipe")
	# 3) acabou o clipe (0,25 s, sem hold): a pose some e o meta é removido
	await quadros(60)
	ok(no.clipe == "" and not jogador.has_meta("pose_do_mod"), "fim do clipe: volta à locomoção (meta removido)")
	var depois: Vector3 = braco.basis * Vector3.DOWN
	ok(depois.distance_to(repouso) < 0.25, "o braço voltou ao repouso (Δ=%.2f)" % depois.distance_to(repouso))
	# 3b) posição de raiz: `gear_2` (2 s) desce o Torso; depois do clipe o Torso volta ao lugar
	var torso: Node3D = proc._n.get("Torso")
	await quadros(20)
	var y0: float = torso.position.y
	McRede.instancia().send(null, Mc.novo(&"MinepieceModAnimationMessage", ["gear_2", ej.getId(), true]))
	await quadros(30)                      # 0,5 s: o clipe sobe até 0,25 s e segura a pose
	var y1: float = torso.position.y
	ok(y1 < y0 - 0.1, "gear_2: o Torso desceu no rig (%.3f → %.3f)" % [y0, y1])
	no.parar()
	await quadros(40)
	ok(absf(torso.position.y - y0) < 0.05, "depois do clipe o Torso volta (%.3f)" % torso.position.y)
	# 4) clipe inexistente é contado, não quebra
	McRede.instancia().send(null, Mc.novo(&"MinepieceModAnimationMessage", ["nao_existe", ej.getId(), true]))
	ok(Mc.pedidos_sem_implementacao.has("animacao:clipe_ausente:nao_existe"), "clipe ausente é contado como falta")

	# 5) caminho completo: golpe da Gomu escolhido pelo mod → animação do mod no corpo
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	v.PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item("minepiece:item_devil_fruit_gomu_gomu")])
	v.PlayerSkill1 = 1.0
	v.PlayerEnergy = 100000.0
	v.PlayerEnergyMAX = 100000.0
	v.UseDevilAbilities = true
	no.historico.clear()
	Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(ej.level(), ej, v.PlayerDevilFruit, 21.0, 1.0)
	Mc.proc(&"KeyStartTechniqueOnKeyPressedProcedure").execute(ej)
	await quadros(30)
	Mc.proc(&"KeyStartTechniqueOnKeyReleasedProcedure").execute(ej)
	await quadros(60)
	print("   clipes tocados pelo golpe da Gomu: %s" % str(no.historico))
	ok(no.historico.any(func(c): return c.begins_with("punch_gomu_pistol")), "o golpe da Gomu fez o mod mandar o clipe punch_gomu_pistol* (%s)" % str(no.historico))
	ok(not Mc.pedidos_sem_implementacao.has("new:MinepieceModAnimationMessage"), "o pacote deixou de ser só contado")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
