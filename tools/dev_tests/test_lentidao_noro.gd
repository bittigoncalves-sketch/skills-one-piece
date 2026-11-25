extends SceneTree
# ============================================================================
#  LENTIDÃO DE MOVIMENTO E AÇÕES (Noro Noro no Mi, 06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_lentidao_noro.gd
#
#  Pedido do dono: o raio desacelera "qualquer ser atingido" por 3 s; a Z deixa 5×
#  mais lento. Decisão: MOVIMENTO E AÇÕES. Cada caso mede o mesmo ser livre e lento
#  (razão ≈ 0,2), no Modo História de verdade.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://test_lentidao_mapa.json"
const PROGRESSO := "user://test_lentidao.json"
const LENTO := 0.2

var _ok_n := 0
var _falhas := 0
var p: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var tam := bib.info("pirate_captain")["tamanho"] as Vector3
	mapa["pecas"].append({"id": "pirata", "tipo": "modelo", "modelo": "pirate_captain",
		"posicao": Vector3(-30, tam.y * 0.5, -10), "rotacao_graus": Vector3.ZERO, "tamanho": tam,
		"cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	TempoLocal.jogador = null     # esta bateria mede só a lentidão de skill (o tempo local tem teste próprio)

	# --- prazo e aura
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(20, 1.0, -10)          # posição ANTES de entrar (armadilha de 16/09)
	current_scene.add_child(boneco)
	await _fisica(20)
	boneco.call("parar")
	Lentidao.aplicar(boneco, LENTO, 1.0)
	_ok("aplicar: fator 0,2 e aura no corpo", is_equal_approx(Lentidao.fator(boneco), LENTO) and boneco.get_node_or_null(Lentidao.AURA) != null)
	await _fisica(20)
	_ok("a aura deixa rastro fantasma no mundo", not current_scene.find_children("FantasmaDeLentidao*", "", false, false).is_empty())
	await _fisica(60)
	_ok("passado o prazo, volta a 1 e a aura some", is_equal_approx(Lentidao.fator(boneco), 1.0))
	await _fisica(30)
	_ok("... a aura foi embora (com fade)", boneco.get_node_or_null(Lentidao.AURA) == null)

	# --- andar do boneco
	var livre := await _andar_boneco(boneco, 1.0)
	Lentidao.aplicar(boneco, LENTO, 5.0)
	var lento := await _andar_boneco(boneco, 1.0)
	_ok("boneco ANDA a 1/5 (%.2f m × %.2f m = %.2f)" % [lento, livre, lento / maxf(livre, 0.001)], absf(lento / maxf(livre, 0.001) - LENTO) < 0.06)
	boneco.remove_meta(Lentidao.META)

	# --- golpe corpo a corpo do boneco (ação)
	var t_livre := await _golpe_do_boneco(boneco)
	Lentidao.aplicar(boneco, LENTO, 10.0)
	var t_lento := await _golpe_do_boneco(boneco)
	_ok("boneco GOLPEIA 5× mais devagar (%.2f s × %.2f s)" % [t_lento, t_livre], t_livre > 0.0 and absf(t_lento / t_livre - 5.0) < 0.8)
	boneco.remove_meta(Lentidao.META)

	# --- animador procedural (ação: a pose anda no tempo do corpo)
	var anim: Node = null
	for c in p.get_children():
		if c is ProceduralAnimator:
			anim = c
	var a0 := float(anim.get("_t"))
	await _fisica(60)
	var da_livre := float(anim.get("_t")) - a0
	Lentidao.aplicar(p, LENTO, 3.0)
	a0 = float(anim.get("_t"))
	await _fisica(60)
	var da_lento := float(anim.get("_t")) - a0
	_ok("animação do jogador a 1/5 (%.2f s × %.2f s)" % [da_lento, da_livre], absf(da_lento / maxf(da_livre, 0.001) - LENTO) < 0.03)
	_ok("jogador lento também anda a 1/5 (fator do movimento = %.2f)" % ExecutorDeSkill.fator_de_lentidao(p), is_equal_approx(ExecutorDeSkill.fator_de_lentidao(p), LENTO))
	p.remove_meta(Lentidao.META)

	# --- vaca (andar e cérebro)
	var vaca := AnimalDaIlha.new()
	vaca.montar(bib, "cow", FichaDeAnimal.normalizar(bib.ficha_de_animal("cow")), {"especie": "cow", "base": Basis(), "centro": Vector3(40, 0, -10), "meio": Vector3(30, 1, 30)})
	current_scene.add_child(vaca)
	vaca.global_position = Vector3(40, 0, -10)
	vaca.alvo = null
	await _fisica(20)
	var v_livre := await _andar_vaca(vaca)
	Lentidao.aplicar(vaca, LENTO, 5.0)
	var v_lento := await _andar_vaca(vaca)
	_ok("vaca ANDA a 1/5 (%.2f m/s × %.2f m/s)" % [v_lento, v_livre], v_livre > 0.3 and absf(v_lento / v_livre - LENTO) < 0.06)
	vaca.remove_meta(Lentidao.META)

	# --- skill de um ator lento anda devagar
	var s := Dados.novo()
	s.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.5, "duracao": 0.2, "habilitado": true, "parametros": {}}]
	s.configuracoes.duracao = 0.8
	s.dano.empurrao = 0.0
	s.dano.atordoamento = 0.0
	boneco.global_position = Vector3(20, 1.0, -10)
	var alvo_s := BonecoDeDuelo.new()
	alvo_s.position = Vector3(20, 1.0, -12)
	current_scene.add_child(alvo_s)
	await _fisica(20)
	alvo_s.call("parar")
	Lentidao.aplicar(boneco, LENTO, 10.0)
	var vida := float(alvo_s.get("health"))
	ExecutorDeSkill.lancar(current_scene, boneco, s, Vector3.FORWARD)
	await _fisica(90)                     # 1,5 s: livre teria acertado em 0,5 s
	var antes := is_equal_approx(float(alvo_s.get("health")), vida)
	await _fisica(90)                     # 3,0 s: lento acerta em 2,5 s
	_ok("skill de ator lento: o acerto de 0,5 s sai em ~2,5 s (aos 1,5 s ainda não; aos 3 s sim)",
		antes and float(alvo_s.get("health")) < vida - 0.5)
	boneco.remove_meta(Lentidao.META)

	# --- o RAIO: qualquer ser atingido fica 5× lento por 3 s
	var raio := Dados.novo()
	raio.dano.lentidao = 80.0
	raio.dano.duracao_efeito = 3.0
	raio.dano.empurrao = 0.0
	raio.dano.atordoamento = 0.0
	raio.eventos = [{"id": "feixe", "tipo": "hitbox", "inicio": 0.0, "duracao": 0.2, "habilitado": true,
		"parametros": {"forma": "Caixa", "largura": 60.0, "altura": 6.0, "profundidade": 3.0, "z": -2.0}}]
	raio.configuracoes.duracao = 0.3
	var pirata := current_scene.find_child("pirata", true, false)
	vaca.global_position = Vector3(10, 0, -12)
	alvo_s.global_position = Vector3(0, 1.0, -12)
	(pirata as Node3D).global_position = Vector3(-10, (pirata as Node3D).global_position.y, -12)
	p.global_position = Vector3(25, 0.8, -12)
	p.remove_meta("damage_immune")
	var lancador := BonecoDeDuelo.new()
	lancador.position = Vector3(0, 1.0, -9.5)
	current_scene.add_child(lancador)
	await _fisica(20)
	ExecutorDeSkill.lancar(current_scene, lancador, raio, Vector3.FORWARD)
	await _fisica(20)
	var seres := {"boneco": alvo_s, "vaca": vaca, "inimigo do mapa": pirata, "jogador": p}
	var todos := true
	var linha := ""
	for nome in seres:
		var f := Lentidao.fator(seres[nome])
		linha += " %s=%.2f(%.1fs)" % [nome, f, Lentidao.resta(seres[nome])]
		todos = todos and is_equal_approx(f, LENTO) and Lentidao.resta(seres[nome]) > 2.5
	_ok("raio de lentidão 80 %% por 3 s deixa TODOS 5× lentos:%s" % linha, todos)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nLENTIDAO_NORO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _andar_boneco(b: Node3D, segundos: float) -> float:
	b.global_position = Vector3(20, 1.0, -10)
	await _fisica(10)
	var de := b.global_position
	for i in int(segundos * 60):
		b.call("andar", Vector3(3.0, 0, 0))
		await physics_frame
	b.call("andar", Vector3.ZERO)
	return Vector2(b.global_position.x - de.x, b.global_position.z - de.z).length()


## Segundos do pedido de golpe até o executor voltar a neutro.
func _golpe_do_boneco(b: Node) -> float:
	var cc: Object = b.get("combate_direcional")
	await _fisica(30)
	cc.call("pedir_ataque", GolpeDirecional.Direcao.values()[0])
	var t := 0
	await physics_frame
	while cc.call("ocupado") and t < 1200:
		await physics_frame
		t += 1
	return t / 60.0


## A maior velocidade de passeio que a vaca pede nos primeiros quadros (o resto do
## passeio é a lógica de área/empaque dela, que não é o que se mede aqui).
func _andar_vaca(v: Node3D) -> float:
	v.global_position = Vector3(40, 0, -10)
	await _fisica(10)
	v.set("estado", AnimalDaIlha.Estado.PASSEANDO)
	v.set("_destino", Vector3(40, 0, -60))
	v.set("_melhor_distancia", INF)
	v.set("_relogio", 100.0)
	var maior := 0.0
	for i in 15:
		await physics_frame
		maior = maxf(maior, Vector2(v.velocity.x, v.velocity.z).length())
	v.set("estado", AnimalDaIlha.Estado.PARADO)
	return maior


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
