extends SceneTree
# ============================================================================
#  SKILLS BUILDER — o EXECUTOR do jogo (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_skills_builder_executor.gd
#
#  A skill do Builder rodando num mundo de física de verdade: `DamageZone` contra
#  corpos com `take_damage`, movimento com colisão. Alvos são dublês (cápsula +
#  `take_damage` que anota), para medir o executor sem depender de IA de inimigo.
#  O último caso compara com a PRÉVIA do Builder: mesma skill, mesmos acertos.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Arena := preload("res://src/skills_builder/arena_preview.gd")

var _ok_n := 0
var _falhas := 0
var cena: Node3D
var ator: CharacterBody3D


class Alvo extends CharacterBody3D:
	var health := 1000.0
	var acertos := 0
	var dano := 0.0
	var empurroes: Array[Vector3] = []
	var atordoamentos: Array[float] = []
	func _init() -> void:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.6
		cs.shape = cap
		add_child(cs)
	func take_damage(amount: float, _de: Vector3 = Vector3.ZERO, kb: Vector3 = Vector3.ZERO, stun: float = 0.0) -> void:
		acertos += 1
		dano += amount
		health -= amount
		empurroes.append(kb)
		atordoamentos.append(stun)


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	cena = Node3D.new()
	root.add_child(cena)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200, 1, 200)
	cs.shape = caixa
	chao.add_child(cs)
	cena.add_child(chao)
	chao.global_position = Vector3(0, -0.5, 0)
	ator = Alvo.new()          # o ator também é uma cápsula (pé em y = 0)
	ator.name = "Ator"
	cena.add_child(ator)
	ator.global_position = Vector3(0, 0.8, 0)

	await _caso_hitbox_unica()
	await _caso_hitbox_repetida()
	await _caso_projetil()
	await _caso_chao_um_segundo()
	await _caso_movimento()
	await _caso_dano()
	await _caso_rumo()
	await _caso_paridade()

	print("\nSKILLS_BUILDER_EXECUTOR %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ casos

func _caso_hitbox_unica() -> void:
	var s := _skill([_ev("hitbox", 0.0, 0.25)])
	var frente := _alvo(Vector3(0, 0.8, -2))
	var atras := _alvo(Vector3(0, 0.8, 2))
	await _rodar(s)
	_ok("hitbox única: o alvo da frente leva 1 acerto de 25 (%d, %.1f)" % [frente.acertos, frente.dano],
		frente.acertos == 1 and is_equal_approx(frente.dano, 25.0))
	_ok("hitbox única: o de trás não leva nada (%d)" % atras.acertos, atras.acertos == 0)
	_ok("o próprio ator não se acerta (%d)" % ator.acertos, ator.acertos == 0)
	_ok("o executor some ao terminar", cena.find_children("SkillBuilder_*", "", true, false).is_empty())
	_limpar()


func _caso_hitbox_repetida() -> void:
	var s := _skill([_ev("hitbox", 0.0, 0.5, {"unicos": false})])
	var a := _alvo(Vector3(0, 0.8, -2))
	await _rodar(s)
	_ok("hitbox de vários acertos: reacerta a cada 0,2 s em 0,5 s = 3 (%d)" % a.acertos, a.acertos == 3)
	_limpar()


func _caso_projetil() -> void:
	var s := _skill([_ev("projetil", 0.0, 0.1, {"velocidade": 12.0, "vida": 2.0})])
	var a := _alvo(Vector3(0, 1.0, -6))
	await _rodar(s, 1.0)
	_ok("projétil acerta o alvo a 6 m (%d)" % a.acertos, a.acertos == 1)
	_limpar()
	var b1 := _alvo(Vector3(0, 1.0, -4))
	var b2 := _alvo(Vector3(0, 1.0, -7))
	await _rodar(s, 1.0)
	_ok("sem atravessar: só o primeiro da fila (%d / %d)" % [b1.acertos, b2.acertos], b1.acertos == 1 and b2.acertos == 0)
	_limpar()
	var s2 := _skill([_ev("projetil", 0.0, 0.1, {"velocidade": 12.0, "vida": 2.0, "perfurar": true})])
	var c1 := _alvo(Vector3(0, 1.0, -4))
	var c2 := _alvo(Vector3(0, 1.0, -7))
	await _rodar(s2, 1.0)
	_ok("atravessando: os dois da fila (%d / %d)" % [c1.acertos, c2.acertos], c1.acertos == 1 and c2.acertos == 1)
	_limpar()
	var s3 := _skill([_ev("projetil", 0.0, 0.1, {"velocidade": 6.0, "vida": 3.0, "gravidade": 30.0})])
	var d := _alvo(Vector3(0, 1.0, -12))
	await _rodar(s3, 2.5)
	_ok("com gravidade forte o projétil cai antes dos 12 m (%d)" % d.acertos, d.acertos == 0)
	_ok("e morre ao bater no chão (sobrou %d executor)" % cena.find_children("SkillBuilder_*", "", true, false).size(),
		cena.find_children("SkillBuilder_*", "", true, false).is_empty())
	_limpar()
	var tres := _skill([_ev("projetil", 0.0, 0.1, {"quantidade": 3, "abertura": 40.0, "velocidade": 12.0})])
	var meio := _alvo(Vector3(0, 1.0, -5))
	var lado := _alvo(Vector3(5.0 * tan(deg_to_rad(20.0)), 1.0, -5))
	await _rodar(tres, 1.0)
	_ok("3 projéteis em leque de 40°: o do meio e o da borda acertam (%d / %d)" % [meio.acertos, lado.acertos],
		meio.acertos >= 1 and lado.acertos >= 1)
	_limpar()


## 15/10/2026: o projétil que bate no chão fica 1 s (cravado, inofensivo) e só então some.
func _caso_chao_um_segundo() -> void:
	var s := _skill([_ev("projetil", 0.0, 0.1, {"velocidade": 6.0, "vida": 5.0, "gravidade": 30.0})])
	await physics_frame
	await physics_frame
	ExecutorDeSkill.lancar(cena, ator, s, Vector3.FORWARD, 1.0)
	var zona: DamageZone = null
	var quadros_ate_cravar := 0
	while quadros_ate_cravar < 240 and zona == null:
		await physics_frame
		quadros_ate_cravar += 1
		for z in cena.find_children("*", "DamageZone", true, false):
			if z.has_meta(ExecutorDeSkill.META_CRAVADA):
				zona = z
	_ok("o projétil bateu no chão e ficou cravado (%d quadros)" % quadros_ate_cravar, zona != null)
	if zona == null:
		_limpar()
		return
	var onde := zona.global_position
	var vivo := 0
	for i in 180:
		await physics_frame
		if not is_instance_valid(zona) or zona.is_queued_for_deletion():
			break
		vivo += 1
		_ok("cravado parado (gravidade não o puxa)", zona.global_position.is_equal_approx(onde)) if vivo == 30 else null
		_ok("cravado não acerta mais ninguém", not zona.monitoring) if vivo == 30 else null
	var seg := vivo / 60.0
	_ok("ficou %.2f s antes de sumir (1 s ± 0,1)" % seg, absf(seg - ExecutorDeSkill.PERMANENCIA_NO_CENARIO) <= 0.1)
	_limpar()
	# Projétil de explosão (andam em `_manuais`): mesma regra, a explosão sai no impacto.
	var e := _skill([_ev("projetil", 0.0, 0.1, {"velocidade": 6.0, "vida": 5.0, "gravidade": 30.0, "explosao": 2.0})])
	await physics_frame
	await physics_frame
	ExecutorDeSkill.lancar(cena, ator, e, Vector3.FORWARD, 1.0)
	var exe: Node = null
	for i in 20:
		await physics_frame
		var l := cena.find_children("SkillBuilder_*", "", true, false)
		if not l.is_empty():
			exe = l[0]
			break
	var cravou := -1
	var sumiu := -1
	for i in 300:
		await physics_frame
		if not is_instance_valid(exe):         # o executor termina junto com o último projétil
			sumiu = i
			break
		var esperando := 0
		for m in exe._manuais:
			if m.has("espera"):
				esperando += 1
		if cravou < 0 and esperando > 0:
			cravou = i
		if cravou >= 0 and esperando == 0 and sumiu < 0:
			sumiu = i
			break
	_ok("projétil de explosão cravou e sumiu 1 s depois (%d → %d quadros)" % [cravou, sumiu],
		cravou >= 0 and sumiu >= 0 and absf((sumiu - cravou) / 60.0 - 1.0) <= 0.1)
	_limpar()


func _caso_movimento() -> void:
	ator.global_position = Vector3(0, 0.8, 0)
	var s := _skill([_ev("movimento", 0.0, 0.5, {"velocidade": 6.0, "distancia": 2.0, "curva": "Linear"})])
	await _rodar(s)
	_ok("movimento para a frente: min(2 m, 6 m/s × 0,5 s) = 2 m (%.2f)" % -ator.global_position.z,
		absf(-ator.global_position.z - 2.0) < 0.15)
	ator.global_position = Vector3(20, 0.8, 0)
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(4, 4, 0.4)
	cs.shape = caixa
	parede.add_child(cs)
	cena.add_child(parede)
	parede.global_position = Vector3(20, 2, -1.2)    # face de cá em z = −1,0
	await physics_frame
	await _rodar(s)
	_ok("contra a parede a 1 m o ator para antes dela (z=%.2f)" % ator.global_position.z,
		ator.global_position.z > -1.0 and ator.global_position.z < -0.3)
	parede.queue_free()
	ator.global_position = Vector3(0, 0.8, 0)
	await physics_frame


func _caso_dano() -> void:
	var s := _skill([_ev("hitbox", 0.0, 0.25)], {"critico": 100.0, "multiplicador": 2.0, "lentidao": 40.0,
		"duracao_efeito": 2.0, "atordoamento": 0.7, "empurrao": 5.0})
	var a := _alvo(Vector3(0, 0.8, -2))
	await _rodar(s)
	_ok("crítico 100 %% × 2 = 50 (%.1f)" % a.dano, is_equal_approx(a.dano, 50.0))
	_ok("atordoamento chega como hitstun 0,7 (%s)" % str(a.atordoamentos), a.atordoamentos.size() == 1 and is_equal_approx(a.atordoamentos[0], 0.7))
	var kb: Vector3 = a.empurroes[0] if not a.empurroes.is_empty() else Vector3.ZERO
	_ok("empurrão para LONGE do ator (%s)" % str(kb.snapped(Vector3.ONE * 0.01)), kb.z < -0.5)
	_ok("lentidão 40 %%: o alvo anda a 0,6 (%.2f)" % ExecutorDeSkill.fator_de_lentidao(a), is_equal_approx(ExecutorDeSkill.fator_de_lentidao(a), 0.6))
	for i in 130:
		await physics_frame
	_ok("a lentidão acaba depois da duração (%.2f)" % ExecutorDeSkill.fator_de_lentidao(a), is_equal_approx(ExecutorDeSkill.fator_de_lentidao(a), 1.0))
	_limpar()
	var h := _alvo(Vector3(0, 0.8, -2))
	await _rodar(_skill([_ev("hitbox", 0.0, 0.25)]), 0.5, PerfilDeFrutas.ESCALA_DA_ARENA)
	_ok("escala da história: 25 × 250/2048 = %.2f (%.2f)" % [25.0 * PerfilDeFrutas.ESCALA_DA_ARENA, h.dano],
		is_equal_approx(h.dano, 25.0 * PerfilDeFrutas.ESCALA_DA_ARENA))
	_limpar()


func _caso_rumo() -> void:
	var s := _skill([_ev("hitbox", 0.0, 0.25)])
	var lado := _alvo(Vector3(2, 0.8, 0))
	var frente := _alvo(Vector3(0, 0.8, -2))
	await _rodar(s, 0.5, 1.0, Vector3.RIGHT)
	_ok("lançada para +X, a hitbox \"da frente\" fica em +X (%d / frente %d)" % [lado.acertos, frente.acertos],
		lado.acertos == 1 and frente.acertos == 0)
	_limpar()


## A skill-modelo do Builder (`Dados.novo()`): a prévia e o executor contam os
## mesmos acertos contra um alvo a 4 m.
func _caso_paridade() -> void:
	var d := Dados.novo()
	var vp := SubViewport.new()
	vp.own_world_3d = true
	root.add_child(vp)
	var arena: Node3D = Arena.new()
	vp.add_child(arena)
	arena.set_process(false)
	arena.configurar(d)
	arena.buscar(float(d.configuracoes.duracao))
	var na_previa: int = arena.estado().acertos
	vp.queue_free()
	ator.global_position = Vector3(0, 0.8, 0)
	await physics_frame
	var a := _alvo(Vector3(0, 0.8, -4))
	await _rodar(d, float(d.configuracoes.duracao) + 0.2)
	_ok("paridade com a prévia (skill-modelo, alvo a 4 m): prévia %d, jogo %d" % [na_previa, a.acertos],
		na_previa == a.acertos and a.acertos > 0)
	_limpar()


# ------------------------------------------------------------------ apoio

func _skill(eventos: Array, dano: Dictionary = {}) -> Dictionary:
	var s := Dados.novo()
	s.eventos = eventos
	for k in dano:
		s.dano[k] = dano[k]
	var fim := 0.0
	for e in eventos:
		fim = maxf(fim, float(e.inicio) + float(e.duracao))
	s.configuracoes.duracao = maxf(fim, 0.1)
	var v := Dados.validar(s)
	if not v.ok:
		push_error("skill de teste inválida: %s" % str(v.erros))
	return s


func _ev(tipo: String, inicio: float, duracao: float, params: Dictionary = {}) -> Dictionary:
	return {"id": "%s_%d" % [tipo, randi() % 100000], "tipo": tipo, "inicio": inicio, "duracao": duracao,
		"habilitado": true, "parametros": params}


func _alvo(pos: Vector3) -> Alvo:
	var a := Alvo.new()
	a.add_to_group("alvo_teste")
	cena.add_child(a)
	a.global_position = pos
	return a


func _rodar(s: Dictionary, segundos: float = 0.5, escala: float = 1.0, rumo: Vector3 = Vector3.FORWARD) -> void:
	await physics_frame
	await physics_frame
	ExecutorDeSkill.lancar(cena, ator, s, rumo, escala)
	for i in int(ceil(segundos * 60.0)) + 4:
		await physics_frame


func _limpar() -> void:
	for a in get_nodes_in_group("alvo_teste"):
		a.queue_free()
	# Projétil que ainda voa de um caso não pode acertar o alvo do caso seguinte.
	for e in cena.find_children("SkillBuilder_*", "", true, false):
		e.queue_free()
	ator.acertos = 0
	ator.dano = 0.0


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
