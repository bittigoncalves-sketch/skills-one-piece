extends SceneTree
# ============================================================================
#  NPCs E LOJAS — pescador, domador e vendedor de frutas (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_npcs_e_lojas.gd
#
#  Pedidos do dono: pescador dá a vara de graça e COMPRA peixe (1 moeda cada);
#  domador vende pets (domáveis + selvagens) por 1 moeda; vendedor de frutas vende as
#  Akuma no Mi da arena por 1 moeda, que vão para o inventário e se comem trocando a
#  atual. NPCs na loja do editor (aba NPCs), corpo Base pintado, E para conversar.
#    • loja do editor: os três na categoria npcs com o comportamento certo; o
#      exportador é idempotente e o .glb sai pintado;
#    • jogo: cada peça vira o NPC vivo (pintado, pés no chão, colisão); E perto abre a
#      loja dele, longe não; E/ESC fecham; mouse solto com a loja aberta;
#    • lojas: pegar a vara, vender peixe (moedas sobem), comprar pet (vai para o N,
#      selvagem também, chefe não), comprar fruta (vai para o N), sem moeda não compra;
#    • N: comer a fruta comprada (com fruta no corpo pede confirmação) — a fruta nova
#      fica no corpo com a ficha da arena na escala da história;
#    • save guarda moedas, pets e frutas compradas.
#  Mapa de TESTE (plano + as três peças) e progresso de TESTE.
# ============================================================================

const MAPA := "user://test_npcs_e_lojas_mapa.json"
const PROGRESSO := "user://test_npcs_e_lojas.json"
const ONDE := {"npc_pescador": Vector3(5, 0, 3), "npc_domador": Vector3(-6, 0, 3), "npc_vendedor_frutas": Vector3(0, 0, -8)}

var _ok_n := 0
var _falhas := 0
var p: Node3D
var prog: ProgressaoDoPersonagem
var hud                         # sem tipo: tipar `HistoriaHud` compila o HUD inteiro e, em modo `--script`, os autoloads (GameFlow, FruitNet) ainda não são identificadores
var npcs: NpcsDaIlha
var avisos: Array[String] = []


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	print("\n===== loja do editor =====")
	_loja_do_editor()
	print("\n===== jogo =====")
	await _jogo()
	print("\nNPCS_E_LOJAS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _loja_do_editor() -> void:
	var bib := MapaMontador.biblioteca_em_uso()
	for tipo: String in NpcDaIlha.FICHAS:
		var achou := ""
		for id in bib.ids():
			if bib.comportamento_do_modelo(id) == tipo:
				achou = id
		_ok("loja do dono: %s na aba NPCs (%s)" % [NpcDaIlha.ficha(tipo)["nome"], achou],
			not achou.is_empty() and bib.categorias_do_modelo(achou).has("npcs") and bib.info(achou)["nome"] == NpcDaIlha.ficha(tipo)["nome"])
	# Exportador numa loja descartável (nunca a do dono).
	var raiz := "user://test_loja_npcs"
	var abs := ProjectSettings.globalize_path(raiz)
	DirAccess.make_dir_recursive_absolute(abs)
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	var cat := FileAccess.open(raiz.path_join("catalogo.json"), FileAccess.WRITE)
	cat.store_string(JSON.stringify({"formato": BibliotecaDeModelos.FORMATO, "versao": 1, "categorias": [], "modelos": []}))
	cat.close()
	var loja := BibliotecaDeModelos.new(raiz)
	var ferramenta = load("res://tools/importar_npcs_na_loja.gd")
	var r1: Array = ferramenta.importar_todos(loja)
	var r2: Array = ferramenta.importar_todos(loja)
	var ok1 := r1.all(func(r): return r["ok"])
	# Um modelo por ficha (06/10/2026: entrou o organizador da corrida; antes eram 3).
	var fichas := NpcDaIlha.FICHAS.size()
	_ok("exportador cria a aba NPCs e um modelo por ficha (%d de %d)" % [loja.ids().size(), fichas], ok1 and loja.tem_categoria("npcs") and loja.ids().size() == fichas)
	_ok("exportador é idempotente (2ª rodada: %s)" % str(r2.map(func(r): return r["mensagem"].left(14))),
		r2.all(func(r): return r["ok"] and str(r["mensagem"]).begins_with("já está")) and loja.ids().size() == fichas)
	for r in r1:
		var tipo := loja.comportamento_do_modelo(r["id"])
		var modelo := loja.instanciar(r["id"])
		_ok("%s: o .glb sai pintado com a cor da ficha" % tipo, _tem_cor(modelo, NpcDaIlha.ficha(tipo)["capa"]))
		modelo.free()


func _jogo() -> void:
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var bib0 := BibliotecaDeModelos.padrao()
	for tipo: String in ONDE:
		var tam := bib0.info(tipo)["tamanho"] as Vector3
		mapa["pecas"].append({"id": "peca_" + tipo, "tipo": "modelo", "modelo": tipo,
			"posicao": ONDE[tipo] + Vector3.UP * tam.y * 0.5, "rotacao_graus": Vector3(0, 90, 0), "tamanho": tam,
			"cor": Color.WHITE, "material": "liso", "colisao": true})
	_ok("mapa de teste gravado", MapaArquivo.salvar(MAPA, mapa) == OK)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	var cena := current_scene
	npcs = cena.get("_npcs")
	prog = cena.get("progressao")
	hud = cena.get("_hud")
	hud.janela_de_loja().aviso.connect(func(t: String): avisos.append(t))
	p.set_meta("damage_immune", true)
	_ok("as três peças viraram NPCs vivos", npcs != null and npcs.npcs.size() == 3)
	if npcs == null or npcs.npcs.size() != 3:
		return
	for npc in npcs.npcs:
		var pos: Vector3 = ONDE[npc.tipo]
		_ok("%s: no chão e no giro da peça, pés no chão (y %.2f), pintado, com colisão" % [npc.nome(), _mais_baixo(npc.get("_rig").modelo())],
			npc.global_position.distance_to(pos) < 0.05 and absf(rad_to_deg(npc.rotation.y) - 90.0) < 0.5
			and absf(_mais_baixo(npc.get("_rig").modelo()) - pos.y) < 0.12
			and npc.get("_rig").modelo() != null          # (a pintura por cor da capa saiu: os moradores agora vestem `VisualDeMorador`)
			and npc.find_children("*", "CollisionShape3D", true, false).size() > 0)
		_ok("%s: a peça do editor saiu do mapa" % npc.nome(), cena.find_child("peca_" + npc.tipo, true, false) == null)
	var pescador := _npc("npc_pescador")
	_ok("o pescador segura a vara", (pescador.get("_vara") as VaraDePescaVisual).segurando())

	# --- longe: nada
	await _ir(pescador, 8.0)
	await _tecla(KEY_E)
	_ok("longe (8 m): sem dica e E não abre loja", not "Pescador" in hud._dica_de_interacao() and not hud.loja_aberta())
	if hud.central_aberta():
		hud.alternar_central()                  # longe de NPC o E abre a MOCHILA (estilo Minecraft); fecha para a dica do NPC voltar a valer
		await _quadros()

	# --- pescador
	await _ir(pescador, 2.0)
	_ok("perto: dica \"%s\"" % hud._dica_de_interacao(), hud._dica_de_interacao() == "E — falar com o Pescador")
	await _tecla(KEY_E)
	var janela = hud.janela_de_loja()
	_ok("E abre a loja do pescador, com fala e moedas (mouse solto)", hud.loja_aberta() and janela.npc == pescador
		and not (janela.get("_fala") as Label).text.is_empty() and pescador.falando() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	_ok("E de novo fecha", await _tecla_e_fecha())
	await _tecla(KEY_E)
	_ok("a vara aparece de graça", janela.find_child("pegar_vara_vara", true, false) != null)
	janela.executar("pegar_vara", "vara")
	_ok("Pegar: ganha a vara (%s)" % avisos.back(), prog.equipamentos.has("vara_de_pesca") and "vara de pesca" in avisos.back())
	await _quadros()
	_ok("pegou: a linha da vara não tem mais botão", janela.find_child("pegar_vara_vara", true, false) == null)
	prog.guardar_item_de_pesca("tuna", 3)
	prog.guardar_item_de_pesca("goldfish", 2)
	var ouro0 := prog.ouro
	await _quadros()
	_ok("os peixes aparecem à venda", janela.find_child("vender_1_tuna", true, false) != null and janela.find_child("vender_tudo_todos", true, false) != null)
	janela.executar("vender_1", "tuna")
	_ok("Vender 1 Atum: +1 moeda (%d → %d), sobram 2" % [ouro0, prog.ouro], prog.ouro == ouro0 + 1 and int(prog.pesca.get("tuna", 0)) == 2)
	janela.executar("vender_tudo", "todos")
	_ok("Vender tudo: +4 moedas, sem peixe (%s)" % avisos.back(), prog.ouro == ouro0 + 5 and not prog.pesca.has("tuna") and not prog.pesca.has("goldfish"))
	await _quadros()
	_ok("a janela mostra as moedas (%s)" % (janela.get("_moedas") as Label).text, (janela.get("_moedas") as Label).text == "%d moedas" % prog.ouro)
	hud.fechar_loja()

	# --- domador
	var domador := _npc("npc_domador")
	await _ir(domador, 2.0)
	await _tecla(KEY_E)
	var especies: Array = load("res://src/historia/npcs/loja_do_domador.gd").especies(MapaMontador.biblioteca_em_uso())
	var ids: Array = especies.map(func(e): return e["id"])
	_ok("domador vende %d animais: domáveis, selvagens e os pets de corpo próprio, sem chefe" % ids.size(),
		ids.has("cow") and ids.has("bear") and ids.has("gaivota") and not ids.has("gorilla_-_animated_low_poly") and not ids.has("caranguejo_grande"))
	var pets0 := prog.pets.size()
	var ouro1 := prog.ouro
	janela.executar("comprar", "bear")
	_ok("Comprar urso: −1 moeda e vai para o N (%s)" % avisos.back(), prog.ouro == ouro1 - 1 and prog.pets.size() == pets0 + 1 and "inventário" in avisos.back())
	var id_urso := ""
	for id in prog.pets:
		if prog.especie_do_pet(id) == "bear":
			id_urso = id
	var inv = hud.inventario()
	hud.fechar_loja()
	var comp: Node = cena.get("_companhia")
	var saiu: bool = comp.chamar(id_urso)
	await _quadros()
	_ok("o urso comprado sai do N como pet de verdade", saiu and comp.esta_fora(id_urso))

	# --- vendedor de frutas
	var vendedor := _npc("npc_vendedor_frutas")
	await _ir(vendedor, 2.0)
	await _tecla(KEY_E)
	await _quadros()
	var frutas := PerfilDeFrutas.frutas_da_arena()
	var catalogo := PerfilDeFrutas.frutas_a_venda()
	var ofertadas: Array[String] = []
	for linha in vendedor.loja().linhas(prog, MapaMontador.biblioteca_em_uso()):
		ofertadas.append(str(linha.id))
	var todos_os_botoes := true
	for id in catalogo:
		todos_os_botoes = todos_os_botoes and janela.find_child("comprar_" + id, true, false) != null
	_ok("vendedor oferece todo o catálogo atual, sem Rocket ou transformação Gear 2",
		not frutas.has("rocket") and not frutas.has("gomu_gomu_gear2") and not ofertadas.has("rocket")
		and ofertadas.size() == catalogo.size() and todos_os_botoes)
	prog.ouro = PerfilDeFrutas.preco_na_loja("mera_mera") + PerfilDeFrutas.preco_na_loja("gomu_gomu")
	janela.executar("comprar", "mera_mera")
	janela.executar("comprar", "gomu_gomu")
	_ok("Comprar: vão para o inventário (itens), não para o corpo (%s)" % str(prog.akumas_guardadas()),
		prog.quantas_akuma("mera_mera") == 1 and prog.quantas_akuma("gomu_gomu") == 1 and prog.fruta.is_empty()
		and prog.inventario.contar("akuma:mera_mera") == 1)
	var ouro2 := prog.ouro
	prog.ouro = 0
	janela.executar("comprar", "hie_hie")
	_ok("sem moeda não compra (%s)" % avisos.back(), prog.quantas_akuma("hie_hie") == 0 and "Sem moedas" in avisos.back())
	prog.ouro = ouro2
	hud.fechar_loja()

	# --- N: comer
	hud.alternar_inventario()
	await _quadros()
	_ok("as Akuma compradas são itens `akuma:` no inventário", prog.inventario.contar("akuma:mera_mera") == 1 and prog.inventario.contar("akuma:gomu_gomu") == 1)
	var r := ItensDeFruta.comer(prog, "akuma:mera_mera", false)
	_ok("sem fruta no corpo: comer come na hora", r.estado == "comeu" and prog.fruta == "mera_mera" and prog.quantas_akuma("mera_mera") == 0)
	for i in 10:
		await physics_frame
	var perfil: PerfilDeFrutas = p.get("perfil_de_frutas")
	_ok("no corpo: Mera com a ficha da arena na escala da história (custo Z %.0f, recarga Z %.0f s, escala %.3f)" % [
		perfil.custo_de_energia("Z", -1) if perfil else -1.0, perfil.recarga("Z", -1) if perfil else -1.0, perfil.escala_de_dano if perfil else -1.0],
		p.get("current_fruit_id") == "mera_mera" and perfil != null and perfil.fruta == "mera_mera" and perfil.escala_de_dano < 0.2)
	r = ItensDeFruta.comer(prog, "akuma:gomu_gomu", false)
	_ok("com fruta no corpo: pede confirmação e nada muda", r.estado == "confirmar" and prog.fruta == "mera_mera" and prog.quantas_akuma("gomu_gomu") == 1)
	r = ItensDeFruta.comer(prog, "akuma:gomu_gomu", true)
	_ok("confirmado: troca (perdeu a Mera)", r.estado == "comeu" and prog.fruta == "gomu_gomu" and prog.quantas_akuma("gomu_gomu") == 0 and "perdeu a" in str(r.texto))
	hud.alternar_inventario()

	var lido2 := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok("save guarda moedas, vara, urso, fruta comida (%d, %s)" % [lido2.ouro, lido2.fruta],
		lido2.ouro == prog.ouro and lido2.equipamentos.has("vara_de_pesca") and lido2.pets.has(id_urso) and lido2.fruta == "gomu_gomu")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")


func _npc(tipo: String) -> NpcDaIlha:
	for n in npcs.npcs:
		if n.tipo == tipo:
			return n
	return null


func _ir(npc: Node3D, distancia: float) -> void:
	p.global_position = npc.global_position + Vector3(0, 1, distancia)
	p.velocity = Vector3.ZERO
	for i in 15:
		await physics_frame


func _tecla_e_fecha() -> bool:
	await _tecla(KEY_E)
	return not hud.loja_aberta()


func _quadros() -> void:
	for i in 3:
		await process_frame


## Y (mundo) do ponto mais baixo das malhas visíveis.
func _mais_baixo(raiz: Node) -> float:
	var y := INF
	# Só o que se VÊ: o rig pendura as armas escondidas (Buki, pistolas) nas mãos.
	if raiz is MeshInstance3D and (raiz as MeshInstance3D).is_visible_in_tree():
		var mi := raiz as MeshInstance3D
		y = (mi.global_transform * mi.get_aabb()).position.y
	for f in raiz.get_children():
		y = minf(y, _mais_baixo(f))
	return y


func _tem_cor(raiz: Node, cor: Color) -> bool:
	if raiz is MeshInstance3D:
		var mi := raiz as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				var c := (m as StandardMaterial3D).albedo_color
				# Pintura proporcional ao cinza original (juntas um tom abaixo).
				if absf(c.r / maxf(c.g, 0.001) - cor.r / cor.g) < 0.05 and absf(c.b / maxf(c.g, 0.001) - cor.b / cor.g) < 0.05:
					return true
	for f in raiz.get_children():
		if _tem_cor(f, cor):
			return true
	return false


func _tecla(codigo: Key) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = codigo
		ev.keycode = codigo
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await physics_frame
	await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
