class_name MapaMontador
extends RefCounted
# ============================================================================
#  MAPA MONTADOR — transforma um mapa já VALIDADO (`MapaArquivo`) em nós.
#
#  Uma peça = um StaticBody3D com o `id` da peça como nome, uma malha e (se
#  `colisao`) uma forma. Nome = id de propósito: o editor de mapa acha a peça
#  clicada pelo nó e volta ao dado pelo mesmo nome, sem tabela paralela.
#
#  O editor usa `atualizar_peca` para refletir cada edição no MESMO nó. Por isso
#  malha, material e forma saem de funções públicas (`malha_de`, `forma_de`):
#  jogo e editor desenham a peça pelo mesmo código, e o que se vê editando é o
#  que se joga.
#
#  ⚠️ GATILHO DE REVISÃO (declarado, não esquecido): um nó por peça é o jeito
#  mais simples de o editor selecionar, mover e apagar peça a peça. O custo cresce
#  com a contagem. Quando um mapa passar de ~1.500 peças, ou a montagem passar de
#  100 ms medida no `test_modo_historia`, agrupar as peças estáticas de mesmo
#  material num MultiMesh (o `MapBuilder` da arena já faz isso) e manter os nós
#  individuais só no editor.
#
#  MEDIDO em 30/09/2026 com a Ilha Inicial (483 peças: 100 blocos de terreno + 383
#  modelos), `tools/mapa_ilha/medir_montagem.gd`: ~1,4 s com cache frio (≈1,1 s é a
#  1ª leitura dos .glb do disco, uma vez por modelo) e ~0,3 s com a biblioteca
#  carregada (quase tudo é montar a malha dos blocos de terreno em GDScript). O
#  gatilho de 100 ms foi ultrapassado e a decisão foi ACEITAR: é custo de abrir o
#  mapa, não de quadro (a vista mais pesada desenha em ~8 ms). Gatilho NOVO e
#  concreto: abrir o Modo História passar de 3 s, ou o quadro passar de 16 ms na
#  ilha → (1) malha dos blocos guardada em disco por `TerrenoDoMapa.assinatura`,
#  (2) árvores iguais num MultiMesh.
# ============================================================================

const NOME_RAIZ := "Mapa"
## Camada de DESENHO do cenário do mapa (10/10/2026): o gelo do V da Hie no Modo História
## (`EraDoGelo`, um decal) só pinta o que tem este bit — relevo, casas, árvores, pedras.
## Personagens, bichos, NPCs, barcos e o mar nascem depois, fora dele, e ficam com as
## cores deles. Câmeras e luzes enxergam todas as camadas: nada muda no desenho.
const CAMADA_CENARIO := 1 << 10

## De onde vêm os modelos das peças `modelo`. Nulo = a biblioteca do projeto;
## o teste põe uma própria, apontando para `user://`.
static var biblioteca: BibliotecaDeModelos = null


static func _biblioteca() -> BibliotecaDeModelos:
	return biblioteca if biblioteca != null else BibliotecaDeModelos.padrao()


## A biblioteca que esta montagem usa (a do teste, se houver). Quem lê o mapa
## montado depois — o Modo História procurando inimigos — consulta a MESMA.
static func biblioteca_em_uso() -> BibliotecaDeModelos:
	return _biblioteca()


## Cria o nó `Mapa` dentro de `pai` e monta todas as peças. `pai` precisa estar
## na árvore: posição se aplica depois do `add_child` (regra 3 do guia).
## No JOGO o relevo em blocos (`RelevoDasIlhas`) já desenha e dá colisão ao terreno de cada ilha, e as peças lisas teriam malha e forma
## soltas logo depois (`soltar_pecas`): com isto ligado elas nascem SEM essa geometria (economiza o tempo de gerá-la e a memória).
## O editor de mapa NUNCA liga (ele edita a peça lisa). Quem liga é o `ModoHistoria`, que desliga ao sair.
static var sem_geometria_do_terreno := false


static func montar(pai: Node, mapa: Dictionary, materiais: Dictionary = {}) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = NOME_RAIZ
	pai.add_child(raiz)
	# Materiais por (material, cor, célula) valem para o mapa inteiro: cem peças
	# da mesma cor dividem um material só em vez de cem cópias do shader.
	for p: Dictionary in mapa["pecas"]:
		montar_peca(raiz, p, materiais)
	return raiz


## `montar` em etapas, para a TELA DE CARREGAMENTO: a cada `lote` peças devolve o quadro (`ao_lote.call(feitas, total)`, que
## pode ser uma corrotina) e o resto é igual. Corrotina: use com `await`.
static func montar_com_progresso(pai: Node, mapa: Dictionary, ao_lote: Callable, lote := 12, materiais: Dictionary = {}) -> Node3D:
	var raiz := criar_raiz(pai)
	await montar_pecas_em(raiz, mapa["pecas"], ao_lote, lote, materiais)
	return raiz


## A raiz vazia do mapa (as peças entram depois, ilha por ilha: `StreamingDeIlhas`).
static func criar_raiz(pai: Node) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = NOME_RAIZ
	pai.add_child(raiz)
	return raiz


## Monta `pecas` na `raiz` que já existe, em lotes (corrotina). `materiais` pode ser o MESMO dicionário em várias chamadas: os
## materiais por (material, cor, célula) são compartilhados entre ilhas.
static func montar_pecas_em(raiz: Node3D, pecas: Array, ao_lote: Callable, lote := 12, materiais: Dictionary = {}) -> void:
	var feitas := 0
	for p: Dictionary in pecas:
		montar_peca(raiz, p, materiais)
		feitas += 1
		if feitas % lote == 0 and ao_lote.is_valid():
			await ao_lote.call(feitas, pecas.size())


## Põe `CAMADA_CENARIO` em todo desenho já montado sob `raiz` (chamar logo depois de
## `montar`, ANTES de as peças virarem NPC, inimigo ou bicho). Devolve quantos marcou.
static func marcar_cenario(raiz: Node) -> int:
	var n := 0
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		if no is VisualInstance3D:
			(no as VisualInstance3D).layers |= CAMADA_CENARIO
			n += 1
		pilha.append_array(no.get_children())
	return n


static func montar_peca(raiz: Node3D, p: Dictionary, materiais: Dictionary = {}) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = p["id"]
	raiz.add_child(corpo)
	var malha := MeshInstance3D.new()
	malha.name = "Malha"
	corpo.add_child(malha)
	atualizar_peca(corpo, p, materiais)
	return corpo


## Aplica o dado inteiro da peça num corpo que já existe. Idempotente: chamar com
## o mesmo dado não muda nada; trocar `tipo` ou `tamanho` troca malha e forma.
static func atualizar_peca(corpo: StaticBody3D, p: Dictionary, materiais: Dictionary = {}) -> void:
	corpo.set_meta("peca_id", p["id"])
	if p["tipo"] == "modelo":
		corpo.add_to_group("assets_transformaveis")
	elif corpo.is_in_group("assets_transformaveis"):
		corpo.remove_from_group("assets_transformaveis")
	# Escalada frontal (03/10/2026): a loja diz quais modelos escalam; o jogador lê
	# a meta no corpo que tocou (`src/player/escalada.gd`). Terreno nunca escala.
	corpo.set_meta("escalavel", p["tipo"] == "modelo" and _biblioteca().escalavel(str(p.get("modelo", ""))))
	corpo.position = p["posicao"]
	corpo.rotation_degrees = p["rotacao_graus"]

	# ⚠️ Malha e forma só são REFEITAS quando forma ou tamanho mudam. Arrastar no
	# editor chama esta função a cada movimento do mouse; recriar BoxMesh e
	# BoxShape3D ali, com dezenas de peças selecionadas, é alocação por quadro
	# para uma peça que só trocou de posição.
	# A HITBOX entra na chave: arrastar o volume muda só ela, e sem isto a forma de
	# física não seria refeita (a peça não mudou de tipo nem de tamanho).
	var chave := "%s|%s|%s|%s" % [p["tipo"], p["tamanho"], p.get("modelo", ""),
		p.get("hitbox", {})]
	if p["tipo"] == "terreno":
		chave += "|" + TerrenoDoMapa.assinatura(p["relevo"])
	var geometria_mudou: bool = corpo.get_meta("forma_chave", "") != chave
	corpo.set_meta("forma_chave", chave)

	var malha := corpo.get_node("Malha") as MeshInstance3D
	if p["tipo"] == "modelo":
		# O modelo desenha a si mesmo (filho "Modelo"); a malha primitiva fica vazia.
		malha.mesh = null
		_biblioteca().aplicar_em(corpo, p)
	else:
		var modelo_antigo := corpo.get_node_or_null("Modelo")
		if modelo_antigo:
			corpo.remove_child(modelo_antigo)
			modelo_antigo.free()
		if p["tipo"] == "terreno":
			_montar_terreno(corpo, malha, p, materiais, geometria_mudou)
		else:
			if geometria_mudou or malha.mesh == null:
				malha.mesh = malha_de(p["tipo"], p["tamanho"])
			malha.material_override = _material_da_area(materiais) if p["tipo"] == "area_animais" \
				else _material(p, materiais)
			# Área de animais: só o editor a vê; quem a esconde no jogo é o
			# `ModoHistoria` (o montador é o mesmo dos dois).
			malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if p["tipo"] == "area_animais" \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if p["tipo"] != "terreno":
		var agua_antiga := corpo.get_node_or_null("Agua")
		if agua_antiga:
			corpo.remove_child(agua_antiga)
			agua_antiga.free()

	var forma := corpo.get_node_or_null("Colisao") as CollisionShape3D
	if p["colisao"] and not (sem_geometria_do_terreno and p["tipo"] == "terreno"):
		if forma == null:
			forma = CollisionShape3D.new()
			forma.name = "Colisao"
			corpo.add_child(forma)
			geometria_mudou = true
		var volume := volume_de_colisao(p)
		if geometria_mudou or forma.shape == null:
			# Volume SIMPLES (hitbox própria, primitiva, ou a caixa do modelo pesado)
			# sai de `forma_de`; volume vazio quer dizer que a colisão É a malha do
			# modelo, e aí só a biblioteca sabe construí-la.
			var extras: Array[Shape3D] = []
			if not volume.is_empty():
				forma.shape = forma_de(volume["forma"], volume["tamanho"])
			elif p["tipo"] == "terreno":
				forma.shape = forma_de_selecao(corpo, p)
			else:
				# Construção com colisão em PARTES convexas: a 1ª vai em "Colisao" e as
				# outras em "Colisao_2", "Colisao_3"... (o resto dos modelos: uma só).
				var formas := _biblioteca().formas_de_colisao(p["modelo"], p["tamanho"])
				forma.shape = formas[0]
				extras = formas.slice(1)
			_partes_extras(corpo, extras)
		# Escrito SEMPRE, e não só quando a geometria muda: tirar a hitbox tem que
		# devolver o volume ao centro do corpo, sem deslocamento nem giro sobrando.
		forma.transform = volume.get("local", Transform3D.IDENTITY)
	else:
		if forma != null:
			# `free` e não `queue_free`: no mesmo quadro o editor pode religar a
			# colisão, e dois filhos chamados "Colisao" fariam o Godot renomear um.
			corpo.remove_child(forma)
			forma.free()
		_partes_extras(corpo, [] as Array[Shape3D])


## As partes de colisão além da primeira ("Colisao_2"...): cria as que faltam,
## troca a forma das que existem e apaga as que sobraram. `free` imediato pelo mesmo
## motivo do "Colisao" (nome repetido no mesmo quadro).
static func _partes_extras(corpo: StaticBody3D, formas: Array[Shape3D]) -> void:
	var n := 0
	while true:
		var nome := "Colisao_%d" % (n + 2)
		var no := corpo.get_node_or_null(nome) as CollisionShape3D
		if n < formas.size():
			if no == null:
				no = CollisionShape3D.new()
				no.name = nome
				corpo.add_child(no)
			no.shape = formas[n]
		elif no != null:
			corpo.remove_child(no)
			no.free()
		else:
			break
		n += 1


## O VOLUME DE COLISÃO de uma peça como DADO: que forma, que tamanho e onde ele fica
## dentro do corpo. Uma conta só, usada pela física (aqui em cima) e pelo desenho do
## editor — duas contas separadas virariam duas verdades, com o editor mostrando um
## volume e o jogador esbarrando em outro.
##
## Devolve {} quando NÃO existe volume simples: é o modelo leve, cuja colisão é a
## malha dele. Aí não há caixa honesta para desenhar, e quem mostra diz isso em vez
## de inventar um retângulo.
static func volume_de_colisao(p: Dictionary) -> Dictionary:
	var h: Dictionary = p.get("hitbox", {})
	if not h.is_empty():
		var giro := Basis.from_euler((h["rotacao_graus"] as Vector3) * (PI / 180.0))
		return {"forma": h["forma"], "tamanho": h["tamanho"], "origem": "propria",
			"local": Transform3D(giro, h["deslocamento"])}
	if p["tipo"] == "terreno":
		return {}    # a colisão do bloco É a malha do relevo
	if p["tipo"] == "modelo":
		if _biblioteca().colisao_e_malha(p.get("modelo", "")):
			return {}
		# Modelo pesado demais para colisão de malha: a física usa uma CAIXA do
		# tamanho da peça. É o caso que mais pede hitbox própria.
		return {"forma": "caixa", "tamanho": p["tamanho"], "origem": "caixa_do_modelo",
			"local": Transform3D.IDENTITY}
	return {"forma": p["tipo"], "tamanho": p["tamanho"], "origem": "primitiva",
		"local": Transform3D.IDENTITY}


static func malha_de(tipo: String, tamanho: Vector3) -> Mesh:
	match tipo:
		"esfera":
			var esfera := SphereMesh.new()
			esfera.radius = tamanho.x * 0.5
			esfera.height = tamanho.x
			return esfera
		"cilindro":
			var cilindro := CylinderMesh.new()
			cilindro.top_radius = tamanho.x * 0.5
			cilindro.bottom_radius = tamanho.x * 0.5
			cilindro.height = tamanho.y
			return cilindro
		"capsula":
			# Só a hitbox usa cápsula (não existe peça-cápsula): esta malha é o
			# DESENHO do volume, e a altura é a total, igual à da forma de física.
			var capsula := CapsuleMesh.new()
			capsula.radius = tamanho.x * 0.5
			capsula.height = maxf(tamanho.y, tamanho.x)
			return capsula
		"cunha":
			# `left_to_right = 0` põe a aresta de cima exatamente sobre a aresta de
			# baixo em −X: face em pé em −X, rampa descendo para +X.
			var cunha := PrismMesh.new()
			cunha.size = tamanho
			cunha.left_to_right = 0.0
			return cunha
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	return caixa


## Forma do CLIQUE do editor. Igual a `forma_de`, menos no terreno: ali é a malha
## do relevo (a mesma da colisão, guardada no corpo) — com a caixa do bloco, uma
## casa pousada nele nunca mais seria clicável.
static func forma_de_selecao(corpo: Node3D, p: Dictionary) -> Shape3D:
	if p["tipo"] != "terreno":
		return forma_de(p["tipo"], p["tamanho"])
	var chave := "%s|%s" % [p["tamanho"], TerrenoDoMapa.assinatura(p["relevo"])]
	if corpo.get_meta("terreno_forma_chave", "") != chave or not corpo.has_meta("terreno_forma"):
		corpo.set_meta("terreno_forma", TerrenoDoMapa.forma(p["relevo"], p["tamanho"]))
		corpo.set_meta("terreno_forma_chave", chave)
	return corpo.get_meta("terreno_forma")


## Forma SIMPLES da peça. Para `modelo` é a caixa que ele ocupa — é o que o clique
## do editor usa; a colisão de jogo do modelo vem de `BibliotecaDeModelos`.
static func forma_de(tipo: String, tamanho: Vector3) -> Shape3D:
	var meio := tamanho * 0.5
	match tipo:
		"esfera":
			var esfera := SphereShape3D.new()
			esfera.radius = meio.x
			return esfera
		"cilindro":
			var cilindro := CylinderShape3D.new()
			cilindro.radius = meio.x
			cilindro.height = tamanho.y
			return cilindro
		"capsula":
			# `CapsuleShape3D.height` é a altura TOTAL (as duas meias-esferas
			# incluídas), que é como uma pessoa pensa a altura de um poste. O piso em
			# um diâmetro evita a cápsula degenerada que a física recusa.
			var capsula := CapsuleShape3D.new()
			capsula.radius = tamanho.x * 0.5
			capsula.height = maxf(tamanho.y, tamanho.x)
			return capsula
		"cunha":
			# Os 6 vértices do prisma escritos à mão, iguais aos da `PrismMesh`
			# acima. Tirar do mesh (`create_convex_shape`) daria o mesmo resultado
			# com um passo de simplificação que ninguém controla.
			var cunha := ConvexPolygonShape3D.new()
			cunha.points = PackedVector3Array([
				Vector3(-meio.x, -meio.y, -meio.z), Vector3(meio.x, -meio.y, -meio.z),
				Vector3(-meio.x, -meio.y, meio.z), Vector3(meio.x, -meio.y, meio.z),
				Vector3(-meio.x, meio.y, -meio.z), Vector3(-meio.x, meio.y, meio.z),
			])
			return cunha
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	return caixa


## Bloco de relevo: malha facetada com a cor do solo e, se houver, a água do rio
## (filho "Agua"). Refeito só quando o desenho ou o tamanho mudam.
static func _montar_terreno(corpo: StaticBody3D, malha: MeshInstance3D, p: Dictionary,
		materiais: Dictionary, geometria_mudou: bool) -> void:
	if (geometria_mudou or malha.mesh == null) and not sem_geometria_do_terreno:
		malha.mesh = TerrenoDoMapa.malha(p["relevo"], p["tamanho"])
	if not materiais.has("@terreno"):
		materiais["@terreno"] = Materiais.terreno()
	malha.material_override = materiais["@terreno"]
	var agua := corpo.get_node_or_null("Agua") as MeshInstance3D
	if not geometria_mudou and (agua != null or (p["relevo"]["agua"] as PackedInt32Array).is_empty()):
		return
	var superficie := TerrenoDoMapa.malha_agua(p["relevo"], p["tamanho"])
	if superficie == null:
		if agua:
			corpo.remove_child(agua)
			agua.free()
		return
	if agua == null:
		agua = MeshInstance3D.new()
		agua.name = "Agua"
		# Água não projeta sombra no leito: ela é translúcida e a sombra dela
		# escureceria justamente o fundo que deveria aparecer.
		agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		corpo.add_child(agua)
	agua.mesh = superficie
	if not materiais.has("@agua_rio"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/world/agua_rio.gdshader")
		materiais["@agua_rio"] = m
	agua.material_override = materiais["@agua_rio"]


## Volume translúcido da área de animais (verde-água, visto de dentro também).
static func _material_da_area(materiais: Dictionary) -> Material:
	if not materiais.has("@area_animais"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.25, 0.95, 0.65, 0.16)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		materiais["@area_animais"] = m
	return materiais["@area_animais"]


# O mesmo cel shader da arena (`Materiais`), para o Modo História pertencer ao
# mesmo mundo visual. A grade é desenhada em coordenada de MUNDO pelo shader, então
# ela vale para qualquer peça horizontal, em qualquer altura.
static func _material(p: Dictionary, materiais: Dictionary) -> Material:
	var cor: Color = p["cor"]
	var chave := "%s|%s|%s" % [p["material"], cor.to_html(false), p["grade_celula"]]
	if not materiais.has(chave):
		if p["material"] == "grade":
			materiais[chave] = Materiais.chao(cor, p["grade_celula"])
		else:
			materiais[chave] = Materiais.superficie(cor)
	return materiais[chave]
