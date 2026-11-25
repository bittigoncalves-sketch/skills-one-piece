class_name PalcoDaAlvida
extends Node3D
# ============================================================================
#  PALCO DA ALVIDA (22/11/2026, 5ª missão) — os ATORES e a geometria das cenas no mar: o navio da Alvida (`mpe_ship_alvida`), o barril, a Alvida (`mp_alvida`), a tripulação, a plataforma do
#  duelo e as câmeras. O FLUXO (quando toca, resultado, prêmio) é do `MissaoDaAlvida`. Modelos do catálogo do mapa (`mp_*`, `mpe_*`: arte PROVISÓRIA, ver memória); sem eles (cópia sem os assets) cada ator vira um bloco.
#
#  Coordenadas do NAVIO (locais, +Z = popa… medidas no GLB): o convés principal está em y = 8,8 (a origem do modelo é a quilha); o meio do convés (x ±7, z 7…12) é a única faixa SEM obstáculo de 3,5 m
#  (mastros, cabines e muretas ocupam o resto — grade de ocupação medida nos vértices do GLB em 22/11/2026). O duelo é aí, no eixo X: a Alvida em +X, o jogador em −X, olhando-se.
#  O modelo não garante colisão: o piso é uma caixa NOSSA (`PISO`) na altura do convés, para o jogador congelado nunca cair no mar.
# ============================================================================
const NAVIO := "mpe_ship_alvida"
const ALVIDA := "mp_alvida"
const TRIPULANTES := ["mp_pirate_pirate4", "mp_pirate_pirate5", "mp_pirate_pirate6", "mp_pirate_pirate7", "mp_pirate_pirate8", "mp_pirate_pirate3"]
## Onde a tripulação ASSISTE ao duelo (deslocamento da arena; x/z dentro da faixa livre do convés, z>0 = atrás dos lutadores para quem vê de −Z): arquibancada de pé, olhando o duelo.
const LUGARES_DA_PLATEIA := [Vector3(-2.7, 0, 2.1), Vector3(-0.5, 0, 2.3), Vector3(1.7, 0, 2.3), Vector3(3.9, 0, 2.1), Vector3(5.2, 0, 0.9), Vector3(-3.8, 0, 0.9)]
const BARRIL := "barrel_2"
const ESCALA_DO_BARRIL := 2.4                    # o barril do catálogo tem 0,7 m: aqui cabe uma pessoa (1,7 m)
const CALADO := 3.52                             # m da quilha abaixo da linha d'água (`linha` do `mpe_ship_alvida.perfil_navio.json`)
const CAMADA_DA_CAMERA := 1 << 19                # colisão do casco SÓ para raios da câmera (o jogador não a vê)
const CONVES_Y := 8.8                            # y do convés principal no espaço do modelo
const ARENA_LOCAL := Vector3(0.0, CONVES_Y, 9.5)
const DIST_DOS_LUTADORES := 2.9                  # m do centro da arena a cada lutador (6 m entre eles)
const PORTO_DO_BARRIL := Vector3(16.0, 0.0, 7.0)   # o barril boia aqui (a boreste, no mar); y = linha d'água
const GANCHO := Vector3(11.0, CONVES_Y + 9.0, 8.0)  # de onde o guincho/corda o içam
const COR_DO_REMENDO := Color(0.86, 0.36, 0.6)   # o rosa da Alvida, onde o modelo traz material SEM textura em magenta

var biblioteca: BibliotecaDeModelos
var ancora := Vector3.ZERO                       # onde o navio fica (x, z; y = linha d'água)
var agua_y := 0.0
var navio: Node3D
var alvida: Node3D
var tripulacao: Array[Node3D] = []
var barril: Node3D
var tampa: MeshInstance3D
var corda: MeshInstance3D
var animadores: Dictionary = {}                  # ator → AnimacoesDoElenco
var bocas: Dictionary = {}                       # ator → BocaFalante
var _piso: StaticBody3D
var _casco_da_camera: StaticBody3D
var _camera_do_duelo := {}


func montar(ancora_no_mar: Vector3, bib: BibliotecaDeModelos) -> void:
	biblioteca = bib
	name = "PalcoDaAlvida"
	var y := AguaDoMundo.nivel_em(ancora_no_mar.x, ancora_no_mar.z)
	agua_y = 0.0 if is_nan(y) else y
	ancora = Vector3(ancora_no_mar.x, agua_y, ancora_no_mar.z)
	navio = _modelo(NAVIO)
	navio.name = "NavioDaAlvida"
	add_child(navio)
	navio.global_position = Vector3(ancora.x, agua_y - CALADO, ancora.z)
	corrigir_magenta(navio)
	_montar_piso()
	alvida = _ator(ALVIDA, "Alvida", ponto_da_arena(Vector3(DIST_DOS_LUTADORES, 0, 0)), PI / 2.0)       # em +X, olhando para −X (o jogador)
	for i in TRIPULANTES.size():
		var t := _ator(TRIPULANTES[i], TRIPULANTES[i], ponto_da_arena(LUGARES_DA_PLATEIA[i]), 0.0)       # de frente para −Z (a câmera fica desse lado) e para o duelo
		tripulacao.append(t)
		t.set_meta("plateia", true)
	_montar_colisao_de_camera()
	_montar_barril()
	colocar_barril(0.0)


# ------------------------------------------------------------------ coordenadas
## Ponto do mundo para um ponto local do navio (o navio não gira: `rotation` = 0).
func ponto_do_navio(local: Vector3) -> Vector3:
	return navio.global_position + local


func ponto_da_arena(deslocamento := Vector3.ZERO) -> Vector3:
	return ponto_do_navio(ARENA_LOCAL + deslocamento)


## Onde cada lutador fica: o jogador a −X, a Alvida a +X.
func lugar_do_jogador() -> Vector3:
	return ponto_da_arena(Vector3(-DIST_DOS_LUTADORES, 0, 0))


func lugar_da_alvida() -> Vector3:
	return ponto_da_arena(Vector3(DIST_DOS_LUTADORES, 0, 0))


func porto_do_barril() -> Vector3:
	return Vector3(ancora.x + PORTO_DO_BARRIL.x, agua_y, ancora.z + PORTO_DO_BARRIL.z)


# ------------------------------------------------------------------ atores
func _modelo(id: String) -> Node3D:
	return carregar(biblioteca, id)


## O modelo `id` do catálogo; sem ele (cópia sem os assets) um bloco, para a cena não quebrar.
static func carregar(bib: BibliotecaDeModelos, id: String) -> Node3D:
	if bib != null and bib.tem(id):
		var modelo := bib.instanciar(id)             # a biblioteca ESCONDE a malha "Colisao" (instanciar direto a deixava aparecendo por cima do navio: o "navio bugado")
		if modelo != null:
			return modelo
	var caixa := MeshInstance3D.new()                  # sem o modelo: um bloco, para a cena não quebrar
	var b := BoxMesh.new()
	b.size = Vector3(1, 2, 1)
	caixa.mesh = b
	return caixa


func _ator(id: String, nome: String, onde: Vector3, giro: float) -> Node3D:
	var a := _modelo(id)
	a.name = nome
	a.set_meta("modelo_id", id)
	add_child(a)
	a.global_position = onde
	a.rotation.y = giro                                                # a frente do modelo é −Z: giro +90° = olha para −X, 180° = olha para +Z
	ExpressoesDoBuggy.textura_do_corpo(a, id)                         # textura nova do Codex, se existir (arquivo ausente = nada)
	animadores[a] = AnimacoesDoElenco.de(a)
	bocas[a] = BocaFalante.de(a)
	if id == ALVIDA and bocas[a] != null:
		(bocas[a] as BocaFalante).usar_boca_pintada()                  # a textura nova da Alvida tem boca desenhada
	return a


## O casco real (malha `Colisao` do modelo) numa camada SÓ de raios: a câmera do duelo escolhe um ponto de onde se vê os dois lutadores sem mastro/cabine no meio.
func _montar_colisao_de_camera() -> void:
	if biblioteca == null or not biblioteca.tem(NAVIO):
		return
	var info := biblioteca.info(NAVIO)
	_casco_da_camera = StaticBody3D.new()
	_casco_da_camera.name = "CascoParaACamera"
	_casco_da_camera.collision_layer = CAMADA_DA_CAMERA
	_casco_da_camera.collision_mask = 0
	var forma := CollisionShape3D.new()
	forma.shape = biblioteca.forma_de_colisao(NAVIO, info["tamanho"])
	_casco_da_camera.add_child(forma)
	add_child(_casco_da_camera)
	_casco_da_camera.global_position = navio.global_position + (info["centro"] as Vector3)      # a forma vem centrada (menos o centro do modelo)


func _montar_piso() -> void:
	_piso = StaticBody3D.new()
	_piso.name = "PisoDoConves"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(17.0, 0.6, 14.0)
	forma.shape = caixa
	_piso.add_child(forma)
	add_child(_piso)
	_piso.global_position = ponto_do_navio(Vector3(0.0, CONVES_Y - 0.3, 6.0))       # topo da caixa = y 8,8 (z −1…13)


func _montar_barril() -> void:
	barril = _modelo(BARRIL)
	barril.name = "Barril"
	add_child(barril)
	barril.scale = Vector3.ONE * ESCALA_DO_BARRIL
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.45, 0.28, 0.14)
	tampa = MeshInstance3D.new()
	tampa.name = "Tampa"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.33
	disco.bottom_radius = 0.33
	disco.height = 0.05
	tampa.mesh = disco
	tampa.material_override = madeira
	tampa.position = Vector3(0, 0.66 + 0.02, 0)           # topo do barril do catálogo (0,66 m, antes da escala)
	barril.add_child(tampa)
	corda = MeshInstance3D.new()
	corda.name = "Corda"
	var fio := BoxMesh.new()
	fio.size = Vector3(0.06, 1.0, 0.06)
	corda.mesh = fio
	corda.material_override = madeira
	add_child(corda)
	corda.visible = false


## O barril boiando (k=0), içado (0<k<1) até o convés (k=1). Caminho em 3 trechos que PASSA POR CIMA da amurada (o arco antigo atravessava o casco): sobe reto na água, cruza
## 4 m acima do convés e desce no meio do convés. A corda liga o gancho ao topo.
func colocar_barril(k: float) -> void:
	var conves := navio.global_position.y + CONVES_Y
	var base := porto_do_barril()
	var p0 := base + Vector3.UP * 0.25
	var p1 := Vector3(navio.global_position.x + 12.5, conves + 4.6, base.z + 0.4)            # além da amurada (x ±9,2), já acima dela (topo ≈ convés + 3,5)
	var p2 := ponto_da_arena(Vector3(5.5, 4.4, 0.0))                                          # sobre o convés, ainda alto
	var p3 := ponto_da_arena(Vector3(0.0, 0.05, 0.0))                                         # no chão, no meio da arena
	var u := clampf(k, 0.0, 1.0)
	var alvo: Vector3
	if u < 0.4:
		alvo = p0.lerp(p1, smoothstep(0.0, 1.0, u / 0.4))
	elif u < 0.7:
		alvo = p1.lerp(p2, smoothstep(0.0, 1.0, (u - 0.4) / 0.3))
	else:
		alvo = p2.lerp(p3, smoothstep(0.0, 1.0, (u - 0.7) / 0.3))
	barril.global_position = alvo
	var balanco := sin(Time.get_ticks_msec() / 1000.0 * 2.1) * (1.0 - u * 0.6)
	barril.rotation = Vector3(balanco * 0.05, 0, balanco * 0.07)
	corda.visible = u > 0.001 and u < 0.999
	if corda.visible:
		var topo := barril.global_position + Vector3.UP * 1.65
		var gancho := ponto_do_navio(GANCHO)
		var meio := (topo + gancho) * 0.5
		var eixo := (gancho - topo).normalized()
		var x := eixo.cross(Vector3.FORWARD)
		if x.length_squared() < 0.0001:
			x = eixo.cross(Vector3.RIGHT)
		x = x.normalized()
		corda.global_transform = Transform3D(Basis(x, eixo * maxf(topo.distance_to(gancho), 0.01), x.cross(eixo)), meio)


## Tampa saindo (k 0 fechada → 1 solta, caindo para o lado).
func abrir_tampa(k: float) -> void:
	var u := clampf(k, 0.0, 1.0)
	tampa.position = Vector3(0.7 * u, 0.68 + 0.5 * sin(u * PI), 0.0)       # espaço local do barril (já escalado)
	tampa.rotation = Vector3(0, 0, -u * 1.2)
	tampa.visible = u < 0.999


# ------------------------------------------------------------------ rostos e câmeras
static func rosto(ator: Node3D) -> Vector3:
	var cab := ator.find_child("head", true, false) as Node3D
	if cab == null:
		cab = ator.find_child("Head", true, false) as Node3D
	return cab.global_position + Vector3.UP * 0.12 if cab != null else ator.global_position + Vector3.UP * 1.8


## Câmera de close no rosto de `ator`: à frente dele (na direção −Z local do ator), levemente de lado e acima.
static func close_do_rosto(ator: Node3D, distancia := 1.25) -> Dictionary:
	var alvo := rosto(ator)
	var frente := -ator.global_basis.z
	var lado := frente.cross(Vector3.UP).normalized()
	return {"de": alvo + frente * distancia + lado * 0.28 + Vector3.UP * 0.06, "para": alvo, "fov": 42.0}


## Câmera do duelo: procura, entre dezenas de pontos em volta da arena, o primeiro com linha de vista LIVRE até a cabeça dos dois lutadores (e ao meio) no casco real, e fora de qualquer parede.
## Prefere o lado −Z (a tripulação assiste do lado oposto, no fundo) e alturas médias. Sem ponto livre: de cima (fallback). Resultado guardado (a cena não muda).
func plano_aberto_do_duelo() -> Dictionary:
	if not _camera_do_duelo.is_empty():
		return _camera_do_duelo
	var c := ponto_da_arena()
	var alvo := c + Vector3.UP * 1.1
	var cabecas := [lugar_do_jogador() + Vector3.UP * 1.6, lugar_da_alvida() + Vector3.UP * 1.7, alvo]
	var direcoes := [Vector2(0, -1), Vector2(-0.5, -0.87), Vector2(0.5, -0.87), Vector2(-0.87, -0.5), Vector2(0.87, -0.5), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
	var melhor := {}
	for dist in [8.0, 6.5, 5.2, 9.5]:
		for elev in [0.55, 0.8, 1.1, 0.35]:
			for d: Vector2 in direcoes:
				var pos: Vector3 = c + Vector3(d.x * dist, 1.0 + elev * dist * 0.6, d.y * dist)
				if _ponto_livre(pos, cabecas):
					melhor = {"de": pos, "para": alvo, "fov": 55.0, "livre": true}
					break
			if not melhor.is_empty():
				break
		if not melhor.is_empty():
			break
	if melhor.is_empty():
		melhor = {"de": c + Vector3(0.0, 7.5, -3.0), "para": alvo, "fov": 60.0, "livre": false}
	_camera_do_duelo = melhor
	return melhor


func _ponto_livre(pos: Vector3, alvos: Array) -> bool:
	if not is_inside_tree():
		return false
	var espaco := get_world_3d().direct_space_state
	for a: Vector3 in alvos:
		var q := PhysicsRayQueryParameters3D.create(pos, a, CAMADA_DA_CAMERA)
		q.hit_back_faces = true
		if not espaco.intersect_ray(q).is_empty():
			return false
	for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:     # dentro de parede/mastro? (algo a menos de 0,7 m em volta)
		var q2 := PhysicsRayQueryParameters3D.create(pos, pos + dir * 0.7, CAMADA_DA_CAMERA)
		q2.hit_back_faces = true
		if not espaco.intersect_ray(q2).is_empty():
			return false
	return true


func falar(ator: Node3D, sim: bool) -> void:
	var b: BocaFalante = bocas.get(ator)
	if b != null:
		b.falar(sim)
	var a: AnimacoesDoElenco = animadores.get(ator)
	if a != null:
		a.falar(sim)


func gesto(ator: Node3D, nome: String) -> bool:
	var a: AnimacoesDoElenco = animadores.get(ator)
	return a != null and a.gesto(nome)


## O modelo do navio pode trazer superfície MAGENTA sem textura (material de teste esquecido, visto no navio do Buggy): vira `COR_DO_REMENDO`. Devolve quantas trocou.
static func corrigir_magenta(raiz: Node) -> int:
	var n := 0
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as BaseMaterial3D
			if mat != null and mat.albedo_texture == null and mat.albedo_color.r > 0.9 and mat.albedo_color.b > 0.9 and mat.albedo_color.g < 0.1:
				var novo := mat.duplicate() as BaseMaterial3D
				novo.albedo_color = COR_DO_REMENDO
				m.set_surface_override_material(s, novo)
				n += 1
	return n
