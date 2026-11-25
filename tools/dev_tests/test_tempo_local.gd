extends SceneTree
## Tempo local do Modo História: vida baixa do jogador desacelera o mundo ao redor (20 m), mostra as
## hitboxes dos disparos na zona vermelha e a morte toca o clipe `dying` e segura o corpo no chão.
## godot --headless --path . --script tools/dev_tests/test_tempo_local.gd

var _falhas := 0
var _n := 0

func _ok(cond: bool, msg: String) -> void:
	_n += 1
	if cond:
		print("  ✅ ", msg)
	else:
		_falhas += 1
		print("  ❌ ", msg)

class Fantoche extends Node3D:
	var health := 100.0
	var max_health := 100.0

func _init() -> void:
	_rodar.call_deferred()

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _rodar() -> void:
	await process_frame
	_curva()
	_visao()
	await _unidades()
	await _historia()
	print("\nTEMPO_LOCAL %d/%d; falhas=%d" % [_n - _falhas, _n, _falhas])
	quit(_falhas)

# ---------------------------------------------------------------- A. a curva
func _curva() -> void:
	print("\n-- A. curva de vida -> escala do tempo --")
	_ok(is_equal_approx(TempoLocal.curva(1.0), 1.0), "vida cheia: tempo normal")
	_ok(is_equal_approx(TempoLocal.curva(0.6), 1.0), "60 % de vida: ainda normal (a lentidão começa aqui)")
	_ok(TempoLocal.curva(0.59) < 1.0 and TempoLocal.curva(0.59) > 0.98, "logo abaixo de 60 %%: começa suave (%.3f)" % TempoLocal.curva(0.59))
	_ok(is_equal_approx(TempoLocal.curva(0.01), 0.25), "1 %% de vida: 0,25× (%.3f)" % TempoLocal.curva(0.01))
	_ok(is_equal_approx(TempoLocal.curva(0.0), 0.25), "vida zero não passa do mínimo")
	var mono := true
	var anterior := 0.0
	for i in 101:
		var e := TempoLocal.curva(i / 100.0)
		if e < anterior - 0.0001:
			mono = false
		anterior = e
	_ok(mono, "quanto menor a vida, mais lento (monótona)")
	_ok(TempoLocal.fator_em(Vector3.ZERO) == 1.0 and TempoLocal.fator_de(null) == 1.0 and not TempoLocal.zona_vermelha(),
		"sem jogador ligado (arena, menus): tudo em 1 e sem zona vermelha")

func _visao() -> void:
	print("\n-- A2. a tela acompanha a vida --")
	_ok(VisaoDeVida.forca_para(1.0) == 0.0 and VisaoDeVida.forca_para(0.6) == 0.0, "vida boa (≥ 60 %): tela normal")
	_ok(is_equal_approx(VisaoDeVida.forca_para(0.01), 1.0) and VisaoDeVida.forca_para(0.0) == 1.0, "vida no fim: efeito no máximo")
	var mono := true
	var anterior := -1.0
	for i in range(100, -1, -1):
		var f := VisaoDeVida.forca_para(i / 100.0)
		if f < anterior - 0.0001:
			mono = false
		anterior = f
	_ok(mono, "quanto menos vida, mais cor some e mais escurece (monótona)")
	_ok(VisaoDeVida.ritmo_para(0.5) == 0.0 and VisaoDeVida.ritmo_para(0.0) == 0.0, "sem pulso fora da zona vermelha")
	_ok(VisaoDeVida.ritmo_para(0.05) > VisaoDeVida.ritmo_para(0.2) and VisaoDeVida.ritmo_para(0.2) > 0.0, "o coração acelera quanto menos vida")


# ------------------------------------------------- B. fatores, DamageZone, marcas
func _unidades() -> void:
	print("\n-- B. raio de 20 m, Lentidao.fator, disparo e hitbox visível (fantoche) --")
	var j := Fantoche.new()
	root.add_child(j)
	TempoLocal.jogador = j
	j.health = 10.0       # 10 % de vida: escala = 0,25 + 0,75 * (0,09 / 0,59)
	var esperado := TempoLocal.curva(0.10)
	var perto := Node3D.new()
	root.add_child(perto)
	perto.position = Vector3(5, 0, 0)
	var longe := Node3D.new()
	root.add_child(longe)
	longe.position = Vector3(25, 0, 0)
	var borda := Node3D.new()
	root.add_child(borda)
	borda.position = Vector3(18.5, 0, 0)
	_ok(is_equal_approx(TempoLocal.fator_de(perto), esperado), "a 5 m: tempo %.3f (curva)" % esperado)
	_ok(TempoLocal.fator_de(longe) == 1.0, "a 25 m: tempo normal")
	var fb := TempoLocal.fator_de(borda)
	_ok(fb > esperado and fb < 1.0, "a 18,5 m (borda suave): entre os dois (%.3f)" % fb)
	_ok(TempoLocal.fator_de(j) == 1.0, "o próprio jogador fica em tempo normal")
	_ok(is_equal_approx(Lentidao.fator(perto), esperado), "Lentidao.fator inclui o tempo local")
	_ok(Lentidao.fator_proprio(perto) == 1.0, "…mas fator_proprio (a aura de lentidão) não")
	Lentidao.aplicar_local(perto, 0.5, 5.0)
	_ok(is_equal_approx(Lentidao.fator(perto), 0.5 * esperado), "lentidão de skill e tempo local se multiplicam")
	perto.remove_meta(Lentidao.META)
	j.health = 70.0
	_ok(TempoLocal.fator_de(perto) == 1.0, "70 % de vida: nada desacelera")

	# --- DamageZone: o disparo dos outros anda devagar; o do jogador não
	j.health = 10.0
	var alheia := _zona(Vector3(3, 1, 0), null)
	var propria := _zona(Vector3(3, 1, 4), j)
	await _quadros(30)
	var d_alheia := alheia.global_position.x - 3.0
	var d_propria := propria.global_position.x - 3.0
	_ok(d_propria > 4.0, "disparo do jogador: tempo normal (andou %.2f m em 0,5 s)" % d_propria)
	_ok(d_alheia > 0.0 and absf(d_alheia - d_propria * esperado * esperado) < 0.25,
		"disparo alheio na zona: anda no QUADRADO do tempo do mundo (%.2f m; esperado ≈ %.2f, ×%.3f)" % [d_alheia, d_propria * esperado * esperado, esperado * esperado])
	_ok(TempoLocal.fator_de_disparo(Vector3(5, 0, 0), null) < TempoLocal.fator_em(Vector3(5, 0, 0)),
		"o disparo é mais lento que o resto do mundo na mesma posição")
	_ok(TempoLocal.fator_de_disparo(Vector3(5, 0, 0), j) == 1.0, "o disparo do próprio jogador segue normal")
	_ok(TempoLocal.fator_de_disparo(Vector3(40, 0, 0), null) == 1.0, "disparo a 40 m: tempo normal")
	var fora := _zona(Vector3(40, 1, 0), null)
	await _quadros(30)
	_ok(fora.global_position.x - 40.0 > 4.0, "disparo fora dos 20 m: tempo normal")

	# --- hitbox visível só na zona vermelha, só dos outros, só no raio
	var gestor := TempoLocalDaHistoria.new()
	gestor.jogador = j
	root.add_child(gestor)      # o _ready repete TempoLocal.jogador = j
	j.health = 20.0             # < 25 %
	gestor.atualizar_hitboxes()
	_ok(alheia.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA) != null, "vida em 20 %: hitbox do disparo alheio visível")
	var marca := alheia.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA)
	var visual := marca.get_child(0) as MeshInstance3D if marca != null and marca.get_child_count() > 0 else null
	_ok(visual != null and visual.mesh is SphereMesh and is_equal_approx((visual.mesh as SphereMesh).radius, 0.5),
		"a marca é a esfera REAL do colisor (raio 0,5)")
	_ok(propria.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA) == null, "o disparo do jogador não ganha marca")
	_ok(fora.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA) == null, "a 40 m: sem marca")
	var parede := _zona(Vector3(2, 1, 8), null, BoxShape3D.new())
	(parede.get_child(0) as CollisionShape3D).shape = _caixa(Vector3(70, 24, 2))
	gestor.atualizar_hitboxes()
	var m2 := parede.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA)
	_ok(m2 != null and (m2.get_child(0) as MeshInstance3D).mesh is ArrayMesh,
		"parede gigante (70 m) vira só contorno em linhas, não um bloco vermelho")
	j.health = 40.0             # fora do vermelho (mas ainda em câmera lenta)
	gestor.atualizar_hitboxes()
	await process_frame
	_ok(alheia.get_node_or_null(TempoLocalDaHistoria.NOME_MARCA) == null or alheia.get_node(TempoLocalDaHistoria.NOME_MARCA).is_queued_for_deletion(),
		"vida em 40 %: as marcas somem")
	gestor.queue_free()
	for n in [alheia, propria, fora, parede, perto, longe, borda]:
		n.queue_free()
	TempoLocal.jogador = null
	j.queue_free()
	await process_frame

func _caixa(t: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = t
	return b

func _zona(pos: Vector3, autor: Node, forma: Shape3D = null) -> DamageZone:
	var z := DamageZone.new()
	root.add_child(z)
	z.global_position = pos
	z.setup(1.0, 0.0, Vector3(10, 0, 0), 5.0, autor, 0.5, forma)
	return z

# ---------------------------------------------------- C. no Modo História de verdade
func _historia() -> void:
	print("\n-- C. Modo História: ligação e morte com o clipe dying --")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_tempo_local.json")
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var p: Node3D = null
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
	_ok(p != null, "o Modo História abriu com o jogador")
	if p == null:
		return
	_ok(TempoLocal.jogador == p and p.get_node_or_null("TempoLocalDaHistoria") != null, "o gerenciador do tempo local está ligado ao jogador")
	await _quadros(30)
	var visao := p.get_node_or_null("TempoLocalDaHistoria/VisaoDeVida") as VisaoDeVida
	_ok(visao != null and visao.layer < 5, "a tela de vida existe, abaixo do HUD (camada %d)" % (visao.layer if visao != null else -1))
	p.health = p.max_health
	await _quadros(20)
	_ok(visao != null and visao.forca == 0.0 and not visao._veu.visible, "vida cheia: a tela fica como está")
	p.health = p.max_health * 0.3
	for i in 90:
		await process_frame
	_ok(visao != null and visao.forca > 0.3 and visao._veu.visible, "vida a 30 %%: a tela tinge (força %.2f)" % (visao.forca if visao != null else -1.0))
	var f30: float = visao.forca
	p.health = p.max_health * 0.05
	for i in 120:
		await process_frame
	_ok(visao.forca > f30 and visao.forca > 0.85, "vida a 5 %%: ainda mais forte (%.2f > %.2f)" % [visao.forca, f30])
	p.health = p.max_health
	for i in 120:
		await process_frame
	_ok(visao.forca == 0.0, "curar desbota o efeito até sumir")
	p.health = p.max_health
	_ok(TempoLocal.escala_do_jogador() == 1.0, "vida cheia: o mundo roda normal")
	p.health = p.max_health * 0.05
	_ok(TempoLocal.escala_do_jogador() < 0.5, "vida a 5 %%: mundo a %.2f×" % TempoLocal.escala_do_jogador())
	p.health = p.max_health

	# morte: tira a imunidade e mata; o clipe toca e a pose fica
	p.set_meta("damage_immune", false)
	var y_antes: float = p._char_model.position.y
	p.net_eliminar()
	_ok(p._morte_corpo_baixado and p._proc_anim.is_playing_baked(), "a morte tocou o clipe `dying` no rig")
	await _quadros(60)
	await _quadros(900)         # muito além da janela do clipe: tem que SEGURAR a pose
	_ok(p._proc_anim.is_playing_baked(), "a pose final é segurada (o corpo não levanta)")
	var chao: float = p.global_position.y - (p.topo_da_cabeca() - p.global_position.y)
	var mais_baixo := INF
	for mi in p._char_model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).visible:
			mais_baixo = minf(mais_baixo, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).position.y)
	_ok(mais_baixo - chao < 0.15, "o corpo deitado pousou no chão (folga %.2f m)" % (mais_baixo - chao))
	_ok(p._char_model.position.y < y_antes - 0.2, "o modelo foi baixado %.2f m para deitar no chão" % (y_antes - p._char_model.position.y))
	p.net_force_respawn()
	await _quadros(5)
	_ok(not p._morte_corpo_baixado and not p._proc_anim.is_playing_baked() and is_equal_approx(p._char_model.position.y, y_antes),
		"no respawn o clipe solta e o corpo volta à altura de sempre")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
