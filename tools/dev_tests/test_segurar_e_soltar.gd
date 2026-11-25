extends SceneTree
# ============================================================================
#  ATIVAÇÃO "CARREGAR E SOLTAR" DO SKILLS BUILDER (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_segurar_e_soltar.gd
#
#  Pedido do dono (Noro Noro): pose de carregar, de SEGURAR e de SOLTAR o golpe. A
#  timeline pára no "ponto de segurar" enquanto a tecla está apertada; soltar
#  continua; soltar antes do ponto cancela e devolve a energia. Prévia, executor e o
#  jogador de verdade (teclas do Kit do Builder no Modo História).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Arena := preload("res://src/skills_builder/arena_preview.gd")
const MAPA := "user://test_segurar_soltar_mapa.json"
const PROGRESSO := "user://test_segurar_soltar.json"
const PASTA := "user://test_segurar_soltar_skills"

var _ok_n := 0
var _falhas := 0


class Alvo extends CharacterBody3D:
	var health := 1000.0
	var acertos := 0
	func _init() -> void:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.6
		cs.shape = cap
		add_child(cs)
	func take_damage(amount: float, _de := Vector3.ZERO, _kb := Vector3.ZERO, _st := 0.0) -> void:
		acertos += 1
		health -= amount


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var s := _skill()
	_ok("skill \"Carregar e soltar\" válida (%s)" % str(Dados.validar(s).erros), Dados.validar(s).ok)

	# ---- prévia
	var vp := SubViewport.new()
	vp.own_world_3d = true
	root.add_child(vp)
	var arena: Node = Arena.new()
	vp.add_child(arena)
	arena.set_process(false)
	arena.configurar(s)
	arena.rodar(true)
	_avancar(arena, 1.0)
	_ok("prévia: segurando, a timeline pára no ponto (0,5 s) (t=%.2f, %s)" % [arena.tempo, arena.estado().status],
		absf(arena.tempo - 0.5) < 0.01 and arena.estado().status == "Segurando" and arena.estado().acertos == 0)
	arena.soltar()
	_avancar(arena, 0.6)
	_ok("prévia: soltar continua e o golpe sai (acertos %d)" % arena.estado().acertos, arena.estado().acertos == 1)
	arena.reiniciar()
	arena.rodar(true)
	_avancar(arena, 0.2)
	arena.soltar()
	_ok("prévia: soltar antes do ponto cancela e devolve a energia (%.0f, recarga %.1f)" % [arena.energia, arena.estado().recarga],
		is_equal_approx(arena.energia, 100.0) and arena.estado().recarga <= 0.0 and not arena.rodando)
	arena.reiniciar()
	arena.rodar(false)
	_avancar(arena, 2.0)
	_ok("prévia: Rodar (sem tecla) segura um instante e solta sozinho (acertos %d)" % arena.estado().acertos, arena.estado().acertos == 1)
	vp.queue_free()

	# ---- executor
	var cena := Node3D.new()
	root.add_child(cena)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(50, 1, 50)
	cs.shape = caixa
	chao.add_child(cs)
	cena.add_child(chao)
	chao.global_position = Vector3(0, -0.5, 0)
	var ator := Alvo.new()
	cena.add_child(ator)
	ator.global_position = Vector3(0, 0.8, 0)
	var alvo := Alvo.new()
	cena.add_child(alvo)
	alvo.global_position = Vector3(0, 0.8, -2)
	await physics_frame
	var e := ExecutorDeSkill.lancar(cena, ator, s, Vector3.FORWARD)
	await _fisica(60)
	_ok("executor: segurando 1 s, não acerta (o golpe é depois do ponto)", alvo.acertos == 0 and is_instance_valid(e) and e.segurando)
	_ok("executor: soltar depois do ponto = \"soltou\"", e.soltar() == "soltou")
	await _fisica(50)
	_ok("executor: ... e o golpe sai (%d)" % alvo.acertos, alvo.acertos == 1)
	var e2 := ExecutorDeSkill.lancar(cena, ator, s, Vector3.FORWARD)
	await _fisica(12)
	_ok("executor: soltar antes do ponto = \"cancelou\"", e2.soltar() == "cancelou")
	await _fisica(70)
	_ok("executor: cancelado, nada acerta e o executor some", alvo.acertos == 1 and not is_instance_valid(e2))
	var curto := s.duplicate(true)
	curto.ativacao.segurar_max = 0.3
	ExecutorDeSkill.lancar(cena, ator, curto, Vector3.FORWARD)
	await _fisica(90)
	_ok("executor: segurou o máximo (0,3 s), solta sozinho (%d)" % alvo.acertos, alvo.acertos == 2)
	cena.queue_free()

	# ---- jogador de verdade (Kit do Builder no Modo História)
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	var pub := s.duplicate(true)
	pub.identificacao.id = "teste_segura"
	pub.identificacao.dono = "Jogador"
	pub.ativacao.tecla = "Z"
	pub.condicoes.exige_alvo = false
	SkillsPublicadas.publicar(pub)
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	var p: Node3D = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta(KitDoBuilder.ID)
	await _fisica(20)
	var boneco := BonecoDeDuelo.new()
	# Posição ANTES de entrar na árvore: nascido na origem, a hurtbox dele surge dentro do
	# jogador, vira plataforma e o carrega para cima do boneco (armadilha de 16/09,
	# docs/erros.md — o ninho do jogo já faz assim).
	boneco.position = Vector3(0, 1.0, -2.2)
	current_scene.add_child(boneco)
	boneco.call("parar")
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	await _fisica(20)
	var vida := float(boneco.get("health"))
	p.set("energy", float(p.get("max_energy")))
	p.begin_charge("Z")
	await _fisica(70)
	_ok("jogo: tecla segurada 1,2 s — o golpe espera (vida %.1f)" % float(boneco.get("health")), is_equal_approx(float(boneco.get("health")), vida))
	p.release_charge("Z")
	await _fisica(50)
	_ok("jogo: soltar a tecla solta o golpe (vida %.1f → %.1f)" % [vida, float(boneco.get("health"))], float(boneco.get("health")) < vida - 0.5)
	(p.get("_fruit_cooldowns") as Dictionary).clear()
	p.set("energy", float(p.get("max_energy")))
	var energia := float(p.get("energy"))
	vida = float(boneco.get("health"))
	p.begin_charge("Z")
	await _fisica(10)
	p.release_charge("Z")
	await _fisica(70)
	_ok("jogo: toque rápido (antes do ponto) cancela, devolve a energia e não acerta",
		is_equal_approx(float(boneco.get("health")), vida) and float(p.get("energy")) >= energia - 0.05
		and float((p.get("_fruit_cooldowns") as Dictionary).get("Z", 0.0)) <= 0.0)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	print("\nSEGURAR_E_SOLTAR %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill() -> Dictionary:
	var s := Dados.novo()
	s.ativacao.modo = "Carregar e soltar"
	s.ativacao.ponto_segurar = 0.5
	s.ativacao.segurar_max = 5.0
	s.dano.valor = 50.0
	s.dano.empurrao = 0.0
	s.dano.atordoamento = 0.0
	s.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.6, "duracao": 0.2, "habilitado": true, "parametros": {}}]
	s.configuracoes.duracao = 0.9
	s.configuracoes.recarga = 0.5
	return s


func _avancar(arena: Node, segundos: float) -> void:
	for i in int(ceil(segundos * 120)):
		arena._process(1.0 / 120.0)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
