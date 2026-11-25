class_name VistaDoMapa
extends Node3D
# ============================================================================
#  VISTA DO MAPA — o documento desenhado na cena, peça a peça, em tempo real.
#
#  Escuta os sinais do `DocumentoMapa` e usa o MESMO `MapaMontador` do Modo
#  História para criar e atualizar os nós. O que se vê editando é o que se joga.
#
#  COMO O CLIQUE ACHA A PEÇA
#  -------------------------
#  Cada peça ganha um filho "Selecao": um StaticBody3D só na CAMADA 20, com a
#  mesma forma. O raio do clique consulta só essa camada. Motivos:
#    • peça com `colisao = false` não tem forma de jogo, mas precisa ser clicável;
#    • o jogador (máscara 1) nunca esbarra na camada 20.
#  ⚠️ Mas raio de parkour e de câmera usam máscara "tudo" por padrão. Por isso,
#  durante o TESTAR, `modo_teste(true)` zera a camada desses corpos — senão o
#  jogador escalaria uma peça sem colisão pela forma de seleção.
# ============================================================================

const CAMADA_SELECAO := 1 << 19          # camada 20 do painel de física
const COR_SELECAO := Color(0.25, 0.75, 1.0)
const COR_SPAWN := Color(0.2, 0.9, 0.45, 0.55)
## HITBOX (23/09/2026): verde, e DESENHADA POR CIMA de tudo (`no_depth_test`) —
## o volume quase sempre mora dentro de um modelo opaco, e sem isso não se veria
## justamente a hitbox que se está ajustando.
const COR_HITBOX := Color(0.30, 1.0, 0.45)
const COR_HITBOX_CHEIA := Color(0.30, 1.0, 0.45, 0.16)
# O marcador do spawn tem o tamanho do COLISOR do jogador (Player.COLISOR_BASE),
# centrado no ponto — é exatamente o corpo que vai nascer ali.
const CORPO_DO_JOGADOR := Vector3(1.0, 1.6, 1.0)

var _doc: DocumentoMapa
var _raiz: Node3D
var _materiais := {}
var _spawn: StaticBody3D
var _linhas: MeshInstance3D
var _ids_desenhados: Array[String] = []
var _hitboxes: MeshInstance3D          # arestas do volume (seleção ou mapa inteiro)
var _volume: MeshInstance3D            # preenchimento translúcido, só de uma peça
var _ver_todas_hitboxes := false
var _cursor: MeshInstance3D            # círculo do pincel de relevo


func ligar(doc: DocumentoMapa) -> void:
	_doc = doc
	_raiz = MapaMontador.montar(self, doc.para_mapa(), _materiais)
	var oceano := preload("res://src/world/oceano_historia.gd").new()
	oceano.name = "Oceano"
	add_child(oceano)
	oceano.ligar_editor(doc)
	for id in doc.ids():
		_criar_selecao(_raiz.get_node(id) as StaticBody3D, doc.peca(id))
	_criar_spawn()
	_criar_linhas()
	_criar_hitboxes()
	_criar_cursor()
	doc.peca_adicionada.connect(_ao_adicionar)
	doc.peca_mudou.connect(_ao_mudar)
	doc.peca_removida.connect(_ao_remover)
	doc.spawn_mudou.connect(_ao_mover_spawn)


func corpo_de(id: String) -> Node3D:
	if id == SelecaoDoEditor.SPAWN:
		return _spawn
	return _raiz.get_node_or_null(NodePath(id)) as Node3D


## O que está sob o ponto da tela: id da peça, `SelecaoDoEditor.SPAWN` ou "".
func escolher(camera: Camera3D, ponto: Vector2) -> String:
	var origem := camera.project_ray_origin(ponto)
	var consulta := PhysicsRayQueryParameters3D.create(
		origem, origem + camera.project_ray_normal(ponto) * camera.far, CAMADA_SELECAO)
	consulta.collide_with_areas = false
	var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if acerto.is_empty():
		return ""
	return String((acerto["collider"] as Node).get_meta("peca_id", ""))


## O ponto do RELEVO sob o ponto da tela (pincel): atravessa casas, árvores e o
## resto até achar um bloco `terreno`. null = não há relevo ali.
func ponto_no_relevo(camera: Camera3D, ponto: Vector2) -> Variant:
	var origem := camera.project_ray_origin(ponto)
	var fim := origem + camera.project_ray_normal(ponto) * camera.far
	var pular: Array[RID] = []
	for _tentativa in 16:
		var consulta := PhysicsRayQueryParameters3D.create(origem, fim, CAMADA_SELECAO, pular)
		var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
		if acerto.is_empty():
			return null
		var id := String((acerto["collider"] as Node).get_meta("peca_id", ""))
		if _doc.tem(id) and _doc.ler(id)["tipo"] == "terreno":
			return acerto["position"]
		pular.append(acerto["rid"])
	return null


## Círculo do pincel pousado no relevo (null esconde). A cor diz o modo.
func desenhar_pincel(centro: Variant, raio: float, cor: Color) -> void:
	var malha := _cursor.mesh as ImmediateMesh
	malha.clear_surfaces()
	_cursor.visible = centro != null
	if centro == null:
		return
	var c: Vector3 = centro
	var terrenos := PincelDeRelevo._terrenos(_doc)
	(_cursor.material_override as StandardMaterial3D).albedo_color = cor
	malha.surface_begin(Mesh.PRIMITIVE_LINES)
	var anterior := Vector3.INF
	for k in 65:
		var a := TAU * k / 64.0
		var xz := Vector2(c.x + cos(a) * raio, c.z + sin(a) * raio)
		var y := PincelDeRelevo.chao_em(terrenos, xz)
		var ponto := Vector3(xz.x, (c.y if is_nan(y) else y) + 0.08, xz.y)
		if anterior != Vector3.INF:
			malha.surface_add_vertex(anterior)
			malha.surface_add_vertex(ponto)
		anterior = ponto
	# Cruz no centro: onde o pincel puxa mais.
	for eixo in [Vector3(0.6, 0, 0), Vector3(0, 0, 0.6)]:
		malha.surface_add_vertex(c + eixo + Vector3.UP * 0.08)
		malha.surface_add_vertex(c - eixo + Vector3.UP * 0.08)
	malha.surface_end()


func cursor_do_pincel_visivel() -> bool:
	return _cursor.visible


## Onde uma peça nova deve nascer: em cima do que está no centro da tela, ou a
## 12 m da câmera se o centro aponta para o céu.
func ponto_de_insercao(camera: Camera3D, altura: float) -> Vector3:
	return ponto_sob(camera, camera.get_viewport().get_visible_rect().size * 0.5, altura)


## Centro de uma peça de `altura` pousada no que está sob o ponto da tela. Sem
## nada embaixo, pousa no plano y = 0; olhando para o céu, a 12 m da câmera.
func ponto_sob(camera: Camera3D, ponto: Vector2, altura: float) -> Vector3:
	var origem := camera.project_ray_origin(ponto)
	var direcao := camera.project_ray_normal(ponto)
	var consulta := PhysicsRayQueryParameters3D.create(origem, origem + direcao * 400.0, CAMADA_SELECAO)
	var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not acerto.is_empty():
		return (acerto["position"] as Vector3) + (acerto["normal"] as Vector3) * (altura * 0.5)
	var no_chao: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origem, direcao)
	if no_chao != null:
		return (no_chao as Vector3) + Vector3.UP * (altura * 0.5)
	return origem + direcao * 12.0


## Depois de a loja apagar (ou reimportar) um modelo: as peças que o usam são
## montadas de novo — o que sumiu da loja vira marcador na hora, sem reabrir.
func remontar_modelos() -> void:
	for id in _doc.ids():
		var p := _doc.peca(id)
		if p["tipo"] != "modelo":
			continue
		var corpo := corpo_de(id) as StaticBody3D
		var velho := corpo.get_node_or_null("Modelo")
		if velho:
			corpo.remove_child(velho)
			velho.free()
		corpo.set_meta("forma_chave", "")
		MapaMontador.atualizar_peca(corpo, p, _materiais)


## Peças cujo CENTRO cai dentro do retângulo da tela (seleção por arraste).
func ids_no_retangulo(camera: Camera3D, retangulo: Rect2) -> Array[String]:
	var dentro: Array[String] = []
	for id in _doc.ids():
		var p := (corpo_de(id) as Node3D).global_position
		if not camera.is_position_behind(p) and retangulo.has_point(camera.unproject_position(p)):
			dentro.append(id)
	if not camera.is_position_behind(_spawn.global_position) \
			and retangulo.has_point(camera.unproject_position(_spawn.global_position)):
		dentro.append(SelecaoDoEditor.SPAWN)
	return dentro


## Caixa de linhas em volta de cada item selecionado (a caixa da peça GIRADA,
## não a caixa alinhada ao mundo — é o que mostra para onde a peça aponta).
func desenhar_selecao(ids: Array[String]) -> void:
	_ids_desenhados = ids.duplicate()
	var malha := _linhas.mesh as ImmediateMesh
	malha.clear_surfaces()
	# Junta antes de abrir a superfície: `surface_end` sem vértice nenhum é erro.
	var caixas := []
	for id in ids:
		if _doc.tem_grupo(id):
			# Grupo: UMA caixa alinhada ao mundo em volta de todas as peças dele.
			var envolve := _caixa_do_grupo(id)
			if envolve.size != Vector3.ZERO:
				caixas.append([Transform3D(Basis.IDENTITY, envolve.get_center()), envolve.size * 0.5 + Vector3.ONE * 0.08])
			continue
		var no := corpo_de(id)
		if no == null:
			continue
		var meio := CORPO_DO_JOGADOR * 0.5
		if id != SelecaoDoEditor.SPAWN:
			meio = (_doc.peca(id)["tamanho"] as Vector3) * 0.5
		caixas.append([no.global_transform, meio + Vector3.ONE * 0.03])
	if caixas.is_empty():
		return
	malha.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in caixas:
		_caixa(malha, c[0], c[1])
	malha.surface_end()


func _caixa_do_grupo(gid: String) -> AABB:
	var caixa := AABB()
	var primeira := true
	for pid in _doc.pecas_de(gid):
		var corpo := corpo_de(pid) as Node3D
		if corpo == null:
			continue
		var meio: Vector3 = (_doc.peca(pid)["tamanho"] as Vector3) * 0.5
		var local := corpo.global_transform * AABB(-meio, meio * 2.0)
		caixa = local if primeira else caixa.merge(local)
		primeira = false
	return caixa


func redesenhar_selecao() -> void:
	desenhar_selecao(_ids_desenhados)
	desenhar_hitboxes(_ids_desenhados)


func _criar_hitboxes() -> void:
	_hitboxes = MeshInstance3D.new()
	_hitboxes.name = "Hitboxes"
	_hitboxes.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COR_HITBOX
	mat.no_depth_test = true
	mat.render_priority = 6      # acima das linhas de seleção (5)
	_hitboxes.material_override = mat
	_hitboxes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hitboxes)
	_volume = MeshInstance3D.new()
	_volume.name = "VolumeDaHitbox"
	var cheio := StandardMaterial3D.new()
	cheio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cheio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cheio.albedo_color = COR_HITBOX_CHEIA
	cheio.cull_mode = BaseMaterial3D.CULL_DISABLED   # visto de dentro também
	cheio.no_depth_test = true
	cheio.render_priority = 4
	_volume.material_override = cheio
	_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_volume.visible = false
	add_child(_volume)


## Liga/desliga as hitboxes do mapa INTEIRO (tecla H). A da peça selecionada
## aparece sempre, com ou sem isto.
func ver_todas_as_hitboxes(ligado: bool) -> void:
	_ver_todas_hitboxes = ligado
	desenhar_hitboxes(_ids_desenhados)


func vendo_todas_as_hitboxes() -> bool:
	return _ver_todas_hitboxes


## O que a FÍSICA usa, desenhado. O volume vem de `MapaMontador.volume_de_colisao`,
## a mesma conta que monta a forma de colisão — e peça com a colisão desligada não
## desenha nada, porque ela não colide com nada.
func desenhar_hitboxes(ids: Array[String]) -> void:
	var malha := _hitboxes.mesh as ImmediateMesh
	malha.clear_surfaces()
	_volume.visible = false
	var alvos: Array[String] = []
	if _ver_todas_hitboxes:
		alvos = _doc.ids()
	else:
		for id in ids:
			if _doc.tem(id):
				alvos.append(id)
			elif _doc.tem_grupo(id):
				alvos.append_array(_doc.pecas_de(id))
	var volumes := []
	var arestas_de_partes := PackedVector3Array()
	for id in alvos:
		var p := _doc.peca(id)
		if not p["colisao"]:
			continue
		var v := MapaMontador.volume_de_colisao(p)
		if v.is_empty():
			# Colisão em PARTES convexas (construções, 01/10/2026): desenha as arestas
			# de cada parte como a física as tem. Malha comum: não há volume honesto
			# para mostrar, como antes.
			arestas_de_partes.append_array(_arestas_das_partes(corpo_de(id)))
			continue
		var mundo := Transform3D(Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0)),
			p["posicao"]) * (v["local"] as Transform3D)
		volumes.append([mundo, v["forma"], v["tamanho"]])
	# Uma peça só selecionada ganha também o volume CHEIO: é a que está sendo ajustada.
	if not _ver_todas_hitboxes and volumes.size() == 1:
		_volume.mesh = MapaMontador.malha_de(volumes[0][1], volumes[0][2])
		_volume.global_transform = volumes[0][0]
		_volume.visible = _linhas.visible
	if volumes.is_empty() and arestas_de_partes.is_empty():
		return
	malha.surface_begin(Mesh.PRIMITIVE_LINES)
	for v in volumes:
		_arestas(malha, v[0], v[1], v[2])
	for ponto in arestas_de_partes:
		malha.surface_add_vertex(ponto)
	malha.surface_end()


## Arestas (pares de pontos, em coordenada de mundo) das partes convexas de um corpo.
static func _arestas_das_partes(corpo: Node3D) -> PackedVector3Array:
	var saida := PackedVector3Array()
	if corpo == null:
		return saida
	for filho in corpo.get_children():
		var cs := filho as CollisionShape3D
		if cs == null or not (cs.shape is ConvexPolygonShape3D):
			continue
		var linhas := (cs.shape as ConvexPolygonShape3D).get_debug_mesh()
		if linhas == null or linhas.get_surface_count() == 0:
			continue
		var pts: PackedVector3Array = linhas.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		saida.append_array(cs.global_transform * pts)
	return saida


## As arestas de cada forma. Caixa e cunha saem da caixa envolvente; as redondas
## ganham anéis, senão uma esfera desenhada como caixa mentiria sobre o volume.
static func _arestas(malha: ImmediateMesh, t: Transform3D, forma: String, tamanho: Vector3) -> void:
	var meio := tamanho * 0.5
	match forma:
		"esfera":
			_anel(malha, t, meio.x, 0, 1, 0.0)
			_anel(malha, t, meio.x, 0, 2, 0.0)
			_anel(malha, t, meio.x, 1, 2, 0.0)
		"cilindro", "capsula":
			_anel(malha, t, meio.x, 0, 2, meio.y)
			_anel(malha, t, meio.x, 0, 2, -meio.y)
			for canto in [Vector3(meio.x, 0, 0), Vector3(-meio.x, 0, 0), Vector3(0, 0, meio.z), Vector3(0, 0, -meio.z)]:
				malha.surface_add_vertex(t * (canto + Vector3.UP * meio.y))
				malha.surface_add_vertex(t * (canto - Vector3.UP * meio.y))
		_:
			_caixa(malha, t, meio)


## Um círculo de 24 lados no plano dos eixos `a` e `b`, deslocado `altura` no eixo
## que sobra. Traçado em espaço LOCAL e levado para o mundo pelo transform.
static func _anel(malha: ImmediateMesh, t: Transform3D, raio: float, a: int, b: int, altura: float) -> void:
	var eixo_livre := 3 - a - b
	var lados := 24
	for i in lados:
		var p1 := Vector3.ZERO
		var p2 := Vector3.ZERO
		var ang1 := TAU * i / lados
		var ang2 := TAU * (i + 1) / lados
		p1[a] = cos(ang1) * raio
		p1[b] = sin(ang1) * raio
		p1[eixo_livre] = altura
		p2[a] = cos(ang2) * raio
		p2[b] = sin(ang2) * raio
		p2[eixo_livre] = altura
		malha.surface_add_vertex(t * p1)
		malha.surface_add_vertex(t * p2)


## Liga/desliga o que só existe para editar: formas de seleção, marcador do
## spawn e linhas. Ver o ⚠️ do cabeçalho.
func modo_teste(ligado: bool) -> void:
	for id in _doc.ids():
		var sel := (corpo_de(id) as Node3D).get_node_or_null("Selecao") as StaticBody3D
		if sel:
			sel.collision_layer = 0 if ligado else CAMADA_SELECAO
	_spawn.collision_layer = 0 if ligado else CAMADA_SELECAO
	_spawn.visible = not ligado
	_linhas.visible = not ligado
	if ligado:
		_cursor.visible = false
	_hitboxes.visible = not ligado
	_volume.visible = _volume.visible and not ligado


# ----------------------------------------------------------------- sinais
func _ao_adicionar(id: String) -> void:
	var p := _doc.peca(id)
	var corpo := MapaMontador.montar_peca(_raiz, p, _materiais)
	_criar_selecao(corpo, p)
	redesenhar_selecao()


func _ao_mudar(id: String) -> void:
	var corpo := corpo_de(id) as StaticBody3D
	var p := _doc.peca(id)
	var chave_antes: String = corpo.get_meta("forma_chave", "")
	MapaMontador.atualizar_peca(corpo, p, _materiais)
	if corpo.get_meta("forma_chave", "") != chave_antes:
		var forma := corpo.get_node("Selecao/Forma") as CollisionShape3D
		forma.shape = MapaMontador.forma_de_selecao(corpo, p)
	redesenhar_selecao()


func _ao_remover(id: String) -> void:
	var corpo := corpo_de(id)
	if corpo:
		# `free` imediato: um "desfazer" no mesmo quadro recria o nó com o MESMO
		# nome, e o antigo ainda na árvore faria o Godot renomear o novo.
		_raiz.remove_child(corpo)
		corpo.free()
	redesenhar_selecao()


func _ao_mover_spawn() -> void:
	_spawn.position = _doc.spawn
	redesenhar_selecao()


# ----------------------------------------------------------------- montagem
func _criar_selecao(corpo: StaticBody3D, p: Dictionary) -> void:
	var sel := StaticBody3D.new()
	sel.name = "Selecao"
	sel.collision_layer = CAMADA_SELECAO
	sel.collision_mask = 0
	sel.set_meta("peca_id", p["id"])
	corpo.add_child(sel)
	var forma := CollisionShape3D.new()
	forma.name = "Forma"
	# Terreno: a malha do relevo, não a caixa — senão o bloco engole o clique de
	# tudo o que está pousado nele (e a loja não acharia o chão para soltar a peça).
	forma.shape = MapaMontador.forma_de_selecao(corpo, p)
	sel.add_child(forma)


func _criar_cursor() -> void:
	_cursor = MeshInstance3D.new()
	_cursor.name = "CursorDoPincel"
	_cursor.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 7
	_cursor.material_override = mat
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false
	add_child(_cursor)


func _criar_spawn() -> void:
	_spawn = StaticBody3D.new()
	_spawn.name = "MarcadorSpawn"
	_spawn.collision_layer = CAMADA_SELECAO
	_spawn.collision_mask = 0
	_spawn.set_meta("peca_id", SelecaoDoEditor.SPAWN)
	add_child(_spawn)
	_spawn.position = _doc.spawn
	var visual := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = CORPO_DO_JOGADOR
	visual.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = COR_SPAWN
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spawn.add_child(visual)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = CORPO_DO_JOGADOR
	forma.shape = box
	_spawn.add_child(forma)


func _criar_linhas() -> void:
	_linhas = MeshInstance3D.new()
	_linhas.name = "LinhasDeSelecao"
	_linhas.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COR_SELECAO
	mat.no_depth_test = true
	mat.render_priority = 5
	_linhas.material_override = mat
	_linhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_linhas)


static func _caixa(malha: ImmediateMesh, t: Transform3D, meio: Vector3) -> void:
	var c: Array[Vector3] = []
	for i in 8:
		c.append(t * Vector3(meio.x * (1 if i & 1 else -1), meio.y * (1 if i & 2 else -1), meio.z * (1 if i & 4 else -1)))
	for aresta in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		malha.surface_add_vertex(c[aresta[0]])
		malha.surface_add_vertex(c[aresta[1]])
