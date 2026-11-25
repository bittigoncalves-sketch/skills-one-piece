extends SceneTree
# ============================================================================
#  CORRIDA DE CARANGUEJOS — a pista e uma corrida inteira em jogo (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --fixed-fps 60 --path . --script tools/dev_tests/test_corrida_de_caranguejos.gd
#
#  `--fixed-fps` tira a física do relógio de parede (a corrida simula minutos).
#  Pedido do dono: pista gigante, corrida de caranguejos com NPC, prêmio de 10 moedas,
#  exige um caranguejo, obstáculos e parkour, não dá para sair do caranguejo até o fim,
#  5 minutos. Decisões dele: mapa próprio; rivais com IA E prêmio para quem completar
#  em até 5:00.
#  Prova: o circuito fecha e cada vão/degrau cabe no pulo (conta); o caranguejo do
#  JOGADOR, pilotado pela mesma IA dos rivais, completa a volta em menos de 5:00 (a pista
#  é completável de verdade, com obstáculos e quedas); as regras (exige caranguejo,
#  Y não desmonta, não dá para guardar o caranguejo, prêmio, tempo esgotado sem prêmio,
#  volta à ilha) e os 5 rivais terminando. Mapa e progresso de TESTE.
# ============================================================================

const MAPA := "user://test_corrida_mapa.json"
const PROGRESSO := "user://test_corrida.json"
const Piloto := preload("res://src/historia/corrida/piloto_de_caranguejo.gd")
const SALTO := 6.0                     # perfil do caranguejo grande (ficha_montaria)
const GRAVIDADE := 26.0                # locomoção da montaria
const CORRENDO := 8.5

var _ok_n := 0
var _falhas := 0
var _piloto: RefCounted
var _corrida: Node
var _montaria: Node
var _cores_da_primeira: Array[Color] = []


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_dados()
	_npc()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	_corrida = current_scene.get("corrida")
	_montaria = current_scene.get("_montarias")
	await _corrida_inteira()
	await _tempo_esgotado()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nCORRIDA_DE_CARANGUEJOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ dados

func _npc() -> void:
	var f := NpcDaIlha.ficha("npc_corrida")
	_ok("o organizador da corrida é um NPC com loja (%s)" % str(f.get("nome", "?")), not f.is_empty() and str(f.loja).ends_with("loja_da_corrida.gd"))
	var bib := BibliotecaDeModelos.padrao()
	var na_loja := false
	for id in bib.ids():
		na_loja = na_loja or bib.comportamento_do_modelo(id) == "npc_corrida"
	_ok("e está na loja do editor, aba NPCs (o dono põe no mapa)", na_loja)
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_corrida"
	npc.biblioteca = bib
	root.add_child(npc)
	_ok("com a bandeira quadriculada ao lado", npc.get_node_or_null("Bandeira") != null)
	npc.queue_free()


func _dados() -> void:
	var d := PistaDosCaranguejos.gerar()
	_ok("o circuito fecha na largada (sobra %.3f m, giro %.0f°)" % [(d.fim as Vector3).length(), rad_to_deg(d.rumo_final)],
		(d.fim as Vector3).length() < 0.05 and is_equal_approx(float(d.rumo_final), -TAU))
	_ok("pista gigante: %.0f m por volta" % float(d.comprimento), float(d.comprimento) > 1200.0 and float(d.comprimento) < 1400.0)
	var lido := MapaArquivo.validar(PistaDosCaranguejos.mapa(d))
	_ok("as %d peças formam um mapa válido do editor" % d.pecas.size(), lido.ok)
	var portoes: Array = d.portoes
	_ok("portões em ordem: %d (o primeiro e o último na linha de chegada)" % portoes.size(),
		(portoes[0].p as Vector3).length() < 0.01 and (portoes[-1].p as Vector3).length() < 0.05 and portoes.size() >= 16)
	# Cada vão das ilhotas cabe no pulo correndo (o corpo pode sobrar 0,5 m de cada borda).
	var alturas: Array = [0.0] + PistaDosCaranguejos.ALTURAS_DAS_ILHOTAS + [0.0]
	var pior := INF
	for k in PistaDosCaranguejos.VAOS_DAS_ILHOTAS.size():
		var sobe := float(alturas[k + 1]) - float(alturas[k])
		var voo := (SALTO + sqrt(maxf(SALTO * SALTO - 2.0 * GRAVIDADE * sobe, 0.0))) / GRAVIDADE
		pior = minf(pior, CORRENDO * voo + 1.0 - float(PistaDosCaranguejos.VAOS_DAS_ILHOTAS[k]))
	_ok("todo vão das ilhotas cabe no pulo correndo (folga mínima %.2f m)" % pior, pior > 0.4)
	var teto := SALTO * SALTO / (2.0 * GRAVIDADE)
	_ok("o degrau (0,5 m) sobe com um pulo (teto do pulo %.2f m)" % teto, 0.5 < teto - 0.1)
	_ok("o vão das plataformas móveis (%.1f m) cabe no pulo" % PistaDosCaranguejos.VAO_DAS_PLATAFORMAS,
		PistaDosCaranguejos.VAO_DAS_PLATAFORMAS < CORRENDO * 2.0 * SALTO / GRAVIDADE)
	var tipos := {}
	for o: Dictionary in d.obstaculos:
		tipos[o.tipo] = int(tipos.get(o.tipo, 0)) + 1
	_ok("obstáculos: %s" % str(tipos), tipos.has("tora") and tipos.has("martelo") and tipos.has("braco") and tipos.has("parede") and tipos.has("plataforma"))


# ------------------------------------------------------------------ corrida

func _corrida_inteira() -> void:
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var p: Node3D = get_first_node_in_group("player")
	var companhia: Node = current_scene.get("_companhia")
	var pets_antes: Dictionary = prog.pets.duplicate(true)
	for id in prog.pets.keys():
		if CorridaDeCaranguejos.e_caranguejo(prog.especie_do_pet(str(id))):
			prog.pets.erase(id)
	var loja: Object = load("res://src/historia/npcs/loja_da_corrida.gd").new()
	var linha: Dictionary = loja.linhas(prog, null)[0]
	_ok("o organizador mostra Correr apagado, com o motivo, sem caranguejo", not bool(linha.botoes[0].ativo) and "caranguejo" in str(linha.detalhe))
	var recusa: String = _corrida.pedir_largada()
	_ok("sem caranguejo a corrida recusa (\"%s\")" % recusa, not recusa.is_empty() and not _corrida.ativa())
	prog.pets = pets_antes
	_ok("com caranguejo o botão Correr acende", bool(loja.linhas(prog, null)[0].botoes[0].ativo))
	var ouro := prog.ouro
	var antes := p.global_position
	_piloto = Piloto.new()
	_piloto.configurar(42, 0.0, 0.0)
	_corrida.piloto_do_jogador = _piloto
	var r: String = loja.executar(prog, null, "correr", "corrida")
	_ok("Correr no organizador larga a corrida e fecha a janela (\"%s\")" % r, _corrida.ativa() and loja.fecha_a_janela())
	await _fisica(3)
	var eu: Dictionary = _corrida.corredores[0]
	_ok("o jogador vai montado no próprio caranguejo, longe da ilha (%.0f m)" % p.global_position.distance_to(antes),
		_montaria.ativa() and _montaria.pet == eu.corpo and p.global_position.distance_to(antes) > 1000.0)
	var rivais := 0
	for c: Dictionary in _corrida.corredores:
		if not c.jogador and not (c.joquei as Dictionary).is_empty():
			rivais += 1
	_ok("cinco rivais com piloto montado", rivais == 5)
	_cores_da_largada()
	_cores_da_primeira = _cores_dos_rivais()
	_montaria.interagir()
	_ok("Y não desmonta durante a corrida", _montaria.ativa())
	var id: String = _corrida.caranguejo_do_jogador()
	companhia.recolher(id)
	_ok("e não dá para guardar o caranguejo no inventário", companhia.pet_fora(id) != null and _montaria.ativa())

	_corrida.mostra_resultado = 200.0
	var quadros := 0
	var portao := 0
	while _corrida.estado != CorridaDeCaranguejos.Estado.RESULTADO and quadros < 60 * 340:
		await physics_frame
		quadros += 1
		if quadros % 1800 == 0:
			print("      t=%5.1f s  portão %d/%d  pos %dº  quedas %d" % [_corrida.tempo, int(eu.proximo) - 1,
				_corrida.dados.portoes.size() - 1, _corrida._posicao_do_jogador(), int(eu.quedas)])
		portao = int(eu.proximo)
	var res: Dictionary = _corrida.resultado_final
	print("      resultado: %s" % str(res))
	_ok("o caranguejo do jogador completa a volta em %.1f s (< 5:00), %d quedas" % [float(res.get("tempo", -1)), int(res.get("quedas", -1))],
		bool(res.get("completou", false)) and float(res.tempo) < 300.0)
	_ok("prêmio: 10 moedas (%d → %d)" % [ouro, prog.ouro], prog.ouro == ouro + 10)
	_montaria.interagir()
	_ok("até voltar à ilha, Y segue sem desmontar", _montaria.ativa())

	var espera := 0
	while _rivais_na_pista() > 0 and espera < 60 * 150:
		await physics_frame
		espera += 1
	var tempos: Array[String] = []
	var chegaram := 0
	for c: Dictionary in _corrida.corredores:
		if not c.jogador:
			tempos.append("%s %s (%d quedas)" % [c.nome, "%.0f s" % c.tempo_final if float(c.tempo_final) >= 0.0 else "—", int(c.quedas)])
			if float(c.tempo_final) >= 0.0:
				chegaram += 1
	print("      rivais: %s" % ", ".join(tempos))
	_ok("os rivais completam a pista sozinhos (%d de 5)" % chegaram, chegaram == 5)

	_corrida.voltar()
	await _fisica(3)
	_ok("de volta à ilha, perto de onde saiu (%.1f m)" % p.global_position.distance_to(antes), p.global_position.distance_to(antes) < 5.0)
	_ok("destravado: a corrida acabou, Y volta a desmontar", not _corrida.ativa() and str(_montaria.trava).is_empty())
	_ok("a pista some ao voltar", _corrida.get_node_or_null("PistaDosCaranguejos") == null)
	var siri: Node = companhia.pet_fora(id)
	_ok("o caranguejo já pode ser guardado", siri != null and not siri.has_meta(companhia.EM_CORRIDA))


## Pedido do dono (06/10): cor dos rivais ALEATÓRIA, viva e distinta; a do jogador fica.
func _cores_da_largada() -> void:
	var cores := _cores_dos_rivais()
	var menor := 1.0
	var sat := 1.0
	for a in cores.size():
		sat = minf(sat, cores[a].s)
		for b in range(a + 1, cores.size()):
			menor = minf(menor, CoresDosCaranguejos_distancia(cores[a], cores[b]))
	_ok("cores dos rivais vivas e distintas (matiz ≥ %.2f entre eles; saturação ≥ %.2f)" % [menor, sat], menor >= 0.12 and sat >= 0.7)
	var pintados := 0
	for c: Dictionary in _corrida.corredores:
		if c.jogador:
			continue
		var casco := _primeira_malha(c.corpo)
		var m: Variant = casco.get_surface_override_material(0) if casco != null else null
		if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("tinta") == c.cor:
			pintados += 1
	_ok("o caranguejo de cada rival foi pintado na cor dele (%d de 5)" % pintados, pintados == 5)
	var meu := _primeira_malha(_corrida.corredores[0].corpo)
	_ok("o caranguejo do jogador mantém a cor dele", meu != null and meu.get_surface_override_material(0) == null)


func _cores_dos_rivais() -> Array[Color]:
	var cores: Array[Color] = []
	for c: Dictionary in _corrida.corredores:
		if not c.jogador:
			cores.append(c.cor)
	return cores


func _primeira_malha(siri: Node) -> MeshInstance3D:
	var visual: Node = siri.get("visual")
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null and not String(mi.get_path()).contains("Bandeirola"):
			return mi
	return null


func CoresDosCaranguejos_distancia(a: Color, b: Color) -> float:
	return (load("res://src/historia/corrida/cores_dos_caranguejos.gd") as GDScript).distancia_de_matiz(a, b)


func _rivais_na_pista() -> int:
	var n := 0
	for c: Dictionary in _corrida.corredores:
		if not c.jogador and float(c.tempo_final) < 0.0:
			n += 1
	return n


func _tempo_esgotado() -> void:
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var ouro := prog.ouro
	_corrida.limite = 15.0
	_piloto = Piloto.new()
	_piloto.configurar(7, 0.0, 0.0)
	_corrida.piloto_do_jogador = _piloto
	var r: String = _corrida.pedir_largada()
	_corrida.mostra_resultado = 1.0
	var iguais := 0
	var novas := _cores_dos_rivais()
	for k in novas.size():
		if novas[k].is_equal_approx(_cores_da_primeira[k]):
			iguais += 1
	_ok("outra corrida sorteia outras cores (%d de 5 iguais à anterior)" % iguais, iguais == 0)
	var quadros := 0
	while _corrida.estado != CorridaDeCaranguejos.Estado.RESULTADO and quadros < 60 * 30:
		await physics_frame
		quadros += 1
	var res: Dictionary = _corrida.resultado_final
	_ok("com o limite estourado: tempo esgotado, sem prêmio (%s, ouro %d → %d)" % [r, ouro, prog.ouro],
		r.is_empty() and not bool(res.get("completou", true)) and int(res.get("premio", -1)) == 0 and prog.ouro == ouro)
	while _corrida.ativa() and quadros < 60 * 40:
		await physics_frame
		quadros += 1
	_ok("e volta sozinho para a ilha depois do resultado", not _corrida.ativa() and str(_montaria.trava).is_empty())
	_corrida.limite = CorridaDeCaranguejos.LIMITE


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
