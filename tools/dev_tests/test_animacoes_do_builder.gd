extends SceneTree
# ============================================================================
#  ANIMAÇÕES DO SKILLS BUILDER: a prévia e o jogo tocam o MESMO clipe (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_animacoes_do_builder.gd
#
#  Pedido do dono: "adicionar mais animações ao skill builder e corrigir as animações
#  atuais, adicionar as animações do rolamento e de combate também". Antes, a prévia
#  tocava um clipe e o jogo uma pose antiga. Confere:
#    1. o campo Clipe lista os 58 clipes do jogo (61 menos os 3 repetidos) + os 5 atalhos,
#       e todo valor tem arquivo; os repetidos ainda valem pelo gêmeo;
#    2. no JOGO (Modo História, mapa/progresso de TESTE), um bloco Animação toca o clipe
#       pelo clipe de ação do animador, no tempo do bloco, e os ossos batem com o clipe;
#    3. na PRÉVIA, o mesmo bloco no mesmo instante dá os mesmos ângulos que o jogo;
#    4. atalho antigo ("Ataque" = punching) e o roll do Q funcionam nos dois;
#    6. (08/10/2026) a lista mostra a duração na frente do nome ("1,27 s · punching");
#    5. (07/10/2026, "todas viram o personagem meio de lado") todo clipe da lista saiu do
#       bake na conversão v3 (metadado `conversao`); a fidelidade ao original do Mixamo é
#       medida em `test_fidelidade_dos_clipes.gd`.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Clipes := preload("res://src/skills_builder/clipes_de_skill.gd")
const PAPEIS := ["Torso", "UpperArm_L", "UpperArm_R", "ForeArm_R", "Thigh_L", "Thigh_R", "Shin_L"]
const INSTANTE := 0.5

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	# 1. A lista.
	var opcoes := Clipes.opcoes()
	var sem_arquivo: Array = []
	for c in opcoes:
		if Clipes.caminho(c).is_empty() or not ResourceLoader.exists(Clipes.caminho(c)):
			sem_arquivo.append(c)
	var campo := {}
	for secao in Dados.secoes():
		if secao.id == "animacao":
			for c in secao.campos:
				if c.id == "clipe":
					campo = c
	_ok("o campo Clipe lista %d opções (58 clipes + 5 atalhos), todas com arquivo (faltam: %s)" % [opcoes.size(), str(sem_arquivo)],
		opcoes.size() == 63 and sem_arquivo.is_empty() and (campo.get("opcoes", []) as Array).size() == 63)
	_ok("roll do Q e combate estão na lista", "sprinting_forward_roll" in opcoes and "roundhouse_kick" in opcoes and "punching" in opcoes)
	# 08/10/2026, "adicionar na frente do nome o tempo de cada animação": a lista MOSTRA a
	# duração; o valor gravado continua o nome.
	var rotulos: Dictionary = campo.get("rotulos", {})
	var punching := load(Clipes.caminho("punching")) as Animation
	_ok("a lista mostra o tempo na frente do nome: \"%s\", \"%s\" (todas as %d opções)" % [rotulos.get("punching", "?"), rotulos.get("Ataque", "?"), rotulos.size()],
		rotulos.size() == opcoes.size() and str(rotulos.get("punching", "")) == ("%.2f s · punching" % punching.length).replace(".", ",")
		and str(rotulos.get("Ataque", "")).ends_with(" s · Ataque"))
	# Repetidos: fora da lista, mas a skill antiga (o Z da Hie usa `boxing_1`) valida e toca o gêmeo.
	var antiga := Dados.novo()
	antiga.animacao.clipe = "boxing_1"
	_ok("repetido fora da lista, mas vale: boxing_1 → %s, validação %s" % [Clipes.caminho("boxing_1").get_file(), Dados.validar(antiga).ok],
		not "boxing_1" in opcoes and not "roundhouse_kick_2" in opcoes and not "run_to_stop_2" in opcoes
		and Clipes.caminho("boxing_1") == Clipes.PASTA + "boxing.res" and Dados.validar(antiga).ok)
	_ok("os parados (guarda, gunplay, queda) estão em Postura, fora de Combate",
		"bouncing_fight_idle" in Clipes.POSTURA and "gunplay" in Clipes.POSTURA and not "gunplay" in Clipes.COMBATE)
	var antigos: Array[String] = []
	for c in opcoes:
		var anim := load(Clipes.caminho(c)) as Animation
		if int(anim.get_meta("conversao", 0)) != 3:
			antigos.append(str(c))
	_ok("todo clipe da lista saiu do bake v3 (antigos: %s)" % str(antigos), antigos.is_empty())

	# 2. No jogo.
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_animacoes_do_builder.json")
	root.get_node("GameFlow").start_story()
	await _fisica(150)
	var p: Node3D = get_first_node_in_group("player")
	var no_jogo := {}
	for clipe in ["roundhouse_kick", "Ataque", "sprinting_forward_roll"]:
		p.global_position = Vector3(0, 0.8, 0)
		p.velocity = Vector3.ZERO
		await _fisica(30)
		var e := ExecutorDeSkill.lancar(p.call("_get_skills_container"), p, _skill(clipe), Vector3.FORWARD)
		var anim_proc: Node = p.get("_proc_anim")
		var tempo := -1.0
		while is_instance_valid(e) and float(e.get("_t")) < INSTANTE:
			await physics_frame
		await process_frame                 # o animador aplica no quadro de processo
		tempo = float(anim_proc.get("acao_tempo"))
		var caminho := Clipes.caminho(clipe)
		_ok("jogo, %s: o animador toca %s (clipe de ação) no tempo do bloco (%.2f s)" % [clipe, caminho.get_file(), tempo],
			str(anim_proc.get("acao_clipe")) == caminho and absf(tempo - INSTANTE) < 0.05)
		var nos: Dictionary = anim_proc.get("_n")
		var erro := _erro_contra_o_clipe(nos, caminho, tempo)
		_ok("jogo, %s: os ossos batem com o clipe (pior %.1f°)" % [clipe, erro], erro < 6.0)
		no_jogo[clipe] = {"t": tempo, "q": _quats(nos)}
		await _fisica(60)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")

	# 3. Na prévia, o mesmo instante.
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(60)
	var ed := current_scene
	for clipe in no_jogo:
		ed.call("_documento", _skill(clipe))
		await _quadros(5)
		var arena: Node = ed.get("arena")
		arena.call("buscar", float(no_jogo[clipe].t))
		await _quadros(2)
		var nos: Dictionary = (arena.get("_rig") as Dictionary).get("nodes", {})
		var erro := _erro_contra_o_clipe(nos, Clipes.caminho(clipe), float(no_jogo[clipe].t))
		var diferenca := _diferenca(no_jogo[clipe].q, _quats(nos))
		_ok("prévia, %s: os ossos batem com o clipe (pior %.1f°) e com o jogo no mesmo instante (pior %.1f°)" % [clipe, erro, diferenca],
			erro < 6.0 and diferenca < 8.0)
	print("\nANIMACOES_DO_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Uma skill só com o bloco Animação (1 s) do clipe.
func _skill(clipe: String) -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = "teste_clipe"
	s.configuracoes.duracao = 1.0
	s.configuracoes.custo = 0.0
	s.condicoes.exige_alvo = false
	s.eventos = [{"id": "anim", "tipo": "animacao", "inicio": 0.0, "duracao": 1.0, "habilitado": true,
		"parametros": {"clipe": clipe, "velocidade": 1.0, "intensidade": 1.0}}]
	return s


## Maior ângulo (graus) entre os ossos e o clipe no tempo `t`.
func _erro_contra_o_clipe(nos: Dictionary, caminho: String, t: float) -> float:
	var info := ProceduralAnimator._clipe(caminho)
	var anim: Animation = info.anim
	var pior := 0.0
	for papel in PAPEIS:
		# Clipe com trilha de giro do corpo (o roll): o tronco gira por cima da rotação
		# gravada, de propósito (`_aplicar_acao`); a paridade prévia × jogo cobre o tronco.
		if papel == "Torso" and info.has("giro"):
			continue
		if nos.has(papel) and (info.faixas as Dictionary).has(papel):
			var quer := Quaternion.from_euler(anim.value_track_interpolate(info.faixas[papel], t))
			pior = maxf(pior, rad_to_deg((nos[papel] as Node3D).quaternion.angle_to(quer)))
	return pior


func _quats(nos: Dictionary) -> Dictionary:
	var q := {}
	for papel in PAPEIS:
		if nos.has(papel):
			q[papel] = (nos[papel] as Node3D).quaternion
	return q


func _diferenca(a: Dictionary, b: Dictionary) -> float:
	var pior := 0.0
	for papel in a:
		if b.has(papel):
			pior = maxf(pior, rad_to_deg((a[papel] as Quaternion).angle_to(b[papel])))
	return pior


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
