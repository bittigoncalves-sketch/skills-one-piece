class_name ChegadaDoBuggy
extends Node3D
# ============================================================================
#  CHEGADA DO BUGGY NO CAIS (21/11/2026) — os ATORES e o ROTEIRO de câmera da cena. O fluxo (quando toca, bússola, corrida, copos) é do `DesafioDoBuggy`.
#  O píer da vila corre ao longo de X (de terra, x≈258, até a ponta, x≈280) em z≈33–47. `ancora` = a ponta do píer, no chão. Tudo é relativo a ela:
#    • navio: vem do LESTE (+X) e atraca na ponta (proa para −X);   • Buggy: na ponta, de frente para a terra (olha para −X), a mesa dos copos entre ele e a vila;
#    • tripulação: atrás do Buggy;   • plateia: a vila, de costas para a terra, olhando para a ponta (+X).
#  Os modelos são os do catálogo do mapa (`mp_*`, `mpe_ship_*`; arte provisória, ver memória). GATILHO: o storyboard do Codex
#  (`art_src/references/desafio_buggy/PLANO.md`) manda nos tempos/enquadramentos: mexer só em `planos()`.
# ============================================================================
const NAVIO := "mpe_ship_pirate_mini_1"
const CHEFE := "mp_buggy"
const TRIPULANTES := ["mp_cabaji", "mp_richie", "mp_pirate_pirate4", "mp_pirate_pirate5"]      # a ficha do Codex (Richie é um leão quadrúpede)
const DISTANCIA_INICIAL_DO_NAVIO := 95.0       # m ao leste do ponto de atracação
const ATRACACAO := Vector3(17.0, 0.0, -2.0)     # onde o navio para, relativo à âncora
const T_CHEGADA_DO_NAVIO := 12.0                # s até o navio parar (planos 1 e 2; o dono pediu a cena mais lenta, 21/11)
const POS_BUGGY := Vector3(-1.4, 0.0, 0.0)
## A PRAIA (pedido do dono, 21/11/2026: o jogo dos copos é na praia, numa mesa, não no píer). Areia sólida (y 0,4) em x 244–256, z 36–46 (medido).
const POS_MESA := Vector3(-20.0, 0.0, 0.0)      # centro da mesa dos copos, na areia
const PRAIA_BUGGY := Vector3(-17.2, 0.0, 0.0)   # o Buggy atrás da mesa (lado do mar), olhando para a vila
const PRAIA_TRIPULACAO_DX := 1.7                # a tripulação fica uns passos atrás dele, em linha
const RAIO_DA_PLATEIA := 5.8                    # m em volta da mesa
const ALTURA_DA_MESA := 0.85
const DURACAO_DO_DESEMBARQUE := 6.0       # s do convés ao píer, somando os planos 3a e 3b
const DURACAO_3A := 4.5
const DURACAO_DA_CAMINHADA := 9.0               # s do deck até a praia
const PISO_DO_CAIS := 0.2                       # y do deck: o píer é só visual (sem colisão; raios caem no fundo raso, ~−0,5) e começa no nível da areia (medido: 0,4 em x 244–256)

var biblioteca: BibliotecaDeModelos
var ancora := Vector3.ZERO
var buggy: Node3D
var tripulacao: Array[Node3D] = []
var navio: Node3D
var mesa: Node3D
var animadores: Dictionary = {}          # modelo → `AnimacoesDoElenco`
const COR_DO_REMENDO := Color(0.62, 0.08, 0.1)   # onde o modelo do navio traz material SEM textura em magenta (bug de arte visto nos prints): vermelho-bandeira do Buggy
var prancha: MeshInstance3D              # a prancha do navio ao píer: só durante o desembarque
var _espuma: CPUParticles3D              # esteira/espuma da proa: só enquanto o navio anda
var _pisou: Dictionary = {}              # ator → já levantou poeira / fez o gesto ao pisar no píer
var _y_agua := 0.0
var _quilha := 0.0          # y mais baixo do casco no espaço do modelo (a origem do modelo é o centro, não a quilha)
const CALADO := 1.6          # m da quilha abaixo da linha d'água


func montar(ancora_no_chao: Vector3, bib: BibliotecaDeModelos) -> void:
	ancora = ancora_no_chao
	biblioteca = bib
	name = "ChegadaDoBuggy"
	_y_agua = AguaDoMundo.nivel_em(ancora.x + ATRACACAO.x, ancora.z + ATRACACAO.z)
	navio = _modelo(NAVIO)
	navio.name = "NavioDoBuggy"
	add_child(navio)
	_corrigir_magenta(navio)
	_quilha = _menor_y(navio)
	navio.global_position = _pos_do_navio(0.0)
	navio.rotation.y = PI / 2.0                        # a proa (−Z do modelo) aponta para −X
	buggy = _modelo(CHEFE)
	buggy.name = "Buggy"
	buggy.set_meta("modelo_id", CHEFE)
	add_child(buggy)
	var rotulo := Label3D.new()
	rotulo.text = "Buggy"
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0035
	rotulo.outline_size = 10
	rotulo.modulate = Color(0.95, 0.35, 0.3)
	rotulo.position = Vector3.UP * 3.0
	buggy.add_child(rotulo)
	for id in TRIPULANTES:
		var t := _modelo(id)
		t.name = id
		add_child(t)
		tripulacao.append(t)
	for no: Node3D in [buggy] + tripulacao:
		ExpressoesDoBuggy.textura_do_corpo(no, str(no.get_meta("modelo_id", no.name)))       # texturas novas do Codex, se já existirem
		animadores[no] = AnimacoesDoElenco.de(no)
	esconder_tripulacao()                                          # só aparecem quando desembarcam (plano 3): antes ficavam "boiando" no convés
	_montar_mesa()
	_montar_espuma()
	_montar_prancha()
	colocar_no_navio()


## O modelo do navio tem uma superfície MAGENTA sem textura (material de teste esquecido): vira o vermelho do Buggy.
func _corrigir_magenta(raiz: Node) -> int:
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


func esconder_tripulacao() -> void:
	buggy.visible = false
	for t in tripulacao:
		t.visible = false


func mostrar_tripulacao() -> void:
	buggy.visible = true
	for t in tripulacao:
		t.visible = true


func andar_elenco(sim: bool) -> void:
	for no in animadores:
		var a: AnimacoesDoElenco = animadores[no]
		if a != null:
			a.andar(sim)


func animador_do_buggy() -> AnimacoesDoElenco:
	return animadores.get(buggy)


## Onde fica o ROSTO do Buggy no mundo (o nó `head` do modelo; sem ele, 1,9 m acima dos pés).
func rosto_do_buggy() -> Vector3:
	var cabeca := buggy.find_child("head", true, false) as Node3D
	return cabeca.global_position + Vector3.UP * 0.12 if cabeca != null else buggy.global_position + Vector3.UP * 1.9


## Caixa (espaço local do modelo) que envolve as malhas; `has_surface()` falso = sem malhas.
func _caixa_local(raiz: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh != null:
			var t: Transform3D = raiz.global_transform.affine_inverse() * m.global_transform if raiz.is_inside_tree() else m.transform
			var a: AABB = t * m.mesh.get_aabb()
			caixa = a if primeira else caixa.merge(a)
			primeira = false
	return caixa


## Menor y (espaço local do modelo) entre as malhas: onde fica a quilha.
func _menor_y(raiz: Node3D) -> float:
	var c := _caixa_local(raiz)
	return c.position.y if c.size != Vector3.ZERO else 0.0


## Esteira de espuma na proa (partículas soltas no mundo: ficam para trás quando o navio avança). Só liga enquanto ele anda.
func _montar_espuma() -> void:
	var c := _caixa_local(navio)
	_espuma = CPUParticles3D.new()
	_espuma.name = "EspumaDaProa"
	var bola := SphereMesh.new()
	bola.radius = 0.28
	bola.height = 0.56
	bola.radial_segments = 6
	bola.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.93, 0.97, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	bola.material = mat
	_espuma.mesh = bola
	_espuma.amount = 70
	_espuma.lifetime = 2.6
	_espuma.local_coords = false
	_espuma.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_espuma.emission_box_extents = Vector3(maxf(c.size.x * 0.42, 1.0), 0.05, 0.6)
	_espuma.direction = Vector3(0.0, 0.25, -1.0)
	_espuma.spread = 40.0
	_espuma.initial_velocity_min = 0.6
	_espuma.initial_velocity_max = 2.2
	_espuma.gravity = Vector3(0.0, -0.8, 0.0)
	_espuma.scale_amount_min = 0.5
	_espuma.scale_amount_max = 1.4
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0.75))
	rampa.set_color(1, Color(1, 1, 1, 0.0))
	_espuma.color_ramp = rampa
	_espuma.position = Vector3(0.0, _quilha + CALADO, c.position.z + 0.5 if c.size != Vector3.ZERO else -4.0)      # na linha d'água, junto à proa (−Z do modelo)
	_espuma.emitting = false
	navio.add_child(_espuma)


## A prancha de desembarque: tábua larga ao longo da linha do convés ao píer (a mesma que o elenco percorre), na metade final.
func _montar_prancha() -> void:
	prancha = MeshInstance3D.new()
	prancha.name = "PranchaDoNavio"
	var b := BoxMesh.new()
	b.size = Vector3(1.0, 0.14, 4.4)
	prancha.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.27, 0.14)
	prancha.material_override = m
	prancha.visible = false
	add_child(prancha)


func _posicionar_prancha() -> void:
	var de := tripulacao_no_convés().lerp(ponto_no_chao(POS_BUGGY), 0.5)
	var ate := ponto_no_chao(POS_BUGGY) + Vector3(0.9, 0.0, 0.0)
	var d := ate - de
	(prancha.mesh as BoxMesh).size.x = d.length()
	prancha.global_position = (de + ate) * 0.5 - Vector3.UP * 0.1
	var x := d.normalized()                                # o comprimento do BoxMesh (X) acompanha a rampa
	var z := x.cross(Vector3.UP).normalized()
	prancha.global_basis = Basis(x, z.cross(x).normalized(), z)
	prancha.visible = true


## A mesa dos copos: tampo de madeira + 4 pés, em caixas (a estética do jogo). Fica escondida até o Buggy chegar à praia. O tampo está a `ALTURA_DA_MESA`.
func _montar_mesa() -> void:
	mesa = Node3D.new()
	mesa.name = "MesaDosCopos"
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.45, 0.29, 0.15)
	var tampo := MeshInstance3D.new()
	var bt := BoxMesh.new()
	bt.size = Vector3(1.2, 0.12, 3.0)                  # o comprimento (Z) acomoda os 3 copos lado a lado
	tampo.mesh = bt
	tampo.material_override = madeira
	tampo.position.y = ALTURA_DA_MESA - 0.06
	mesa.add_child(tampo)
	var toalha := MeshInstance3D.new()
	var bn := BoxMesh.new()
	bn.size = Vector3(1.24, 0.02, 3.04)
	toalha.mesh = bn
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color(0.12, 0.42, 0.22)
	toalha.material_override = verde
	toalha.position.y = ALTURA_DA_MESA + 0.002
	mesa.add_child(toalha)
	for dx in [-0.5, 0.5]:
		for dz in [-1.35, 1.35]:
			var pe := MeshInstance3D.new()
			var bp := BoxMesh.new()
			bp.size = Vector3(0.14, ALTURA_DA_MESA - 0.12, 0.14)
			pe.mesh = bp
			pe.material_override = madeira
			pe.position = Vector3(dx, (ALTURA_DA_MESA - 0.12) * 0.5, dz)
			mesa.add_child(pe)
	mesa.visible = false
	add_child(mesa)


## Onde o jogo dos copos fica: o TAMPO da mesa (centro).
func tampo_da_mesa() -> Vector3:
	return ponto_no_chao(POS_MESA) + Vector3.UP * ALTURA_DA_MESA


func ponto_do_buggy_na_praia() -> Vector3:
	return ponto_no_chao(PRAIA_BUGGY)


func _praia_da_tripulacao(i: int) -> Vector3:
	return ponto_no_chao(Vector3(PRAIA_BUGGY.x + PRAIA_TRIPULACAO_DX, 0.0, (i - (tripulacao.size() - 1) * 0.5) * 1.8))


func colocar_na_praia() -> void:
	mostrar_tripulacao()
	andar_elenco(false)
	mesa.global_position = ponto_no_chao(POS_MESA)
	mesa.visible = true
	_encerrar_efeitos_do_navio()
	buggy.global_position = ponto_do_buggy_na_praia()
	virar_para_terra(buggy)
	for i in tripulacao.size():
		tripulacao[i].global_position = _praia_da_tripulacao(i)
		virar_para_terra(tripulacao[i])
	navio.global_position = _pos_do_navio(1.0)


## Navio parado: sem espuma, sem balanço forçado e sem a prancha.
func _encerrar_efeitos_do_navio() -> void:
	if _espuma != null:
		_espuma.emitting = false
	if prancha != null:
		prancha.visible = false
	navio.rotation.x = 0.0
	navio.rotation.z = 0.0


## A caminhada do deck até a praia: `t` s desde o fim da cena. Devolve true quando chegou.
func caminhar_para_a_praia(t: float) -> bool:
	mesa.global_position = ponto_no_chao(POS_MESA)
	mesa.visible = true
	var k := smoothstep(0.0, 1.0, clampf(t / DURACAO_DA_CAMINHADA, 0.0, 1.0))
	var passada := 0.0
	andar_elenco(t < DURACAO_DA_CAMINHADA)
	_mover(buggy, ponto_no_chao(POS_BUGGY), ponto_do_buggy_na_praia(), k, passada)
	for i in tripulacao.size():
		var atraso := clampf((k - 0.06 * float(i)) / (1.0 - 0.06 * float(tripulacao.size())), 0.0, 1.0)
		_mover(tripulacao[i], posicao_da_tripulacao(i), _praia_da_tripulacao(i), atraso, passada)
	return t >= DURACAO_DA_CAMINHADA


func _mover(no: Node3D, de: Vector3, para: Vector3, k: float, passada: float) -> void:
	var p := de.lerp(para, k)
	p.y = chao(p.x, p.z) + passada
	no.global_position = p
	virar_para_terra(no)


func _modelo(id: String) -> Node3D:
	if biblioteca != null and biblioteca.tem(id):
		var cena := load(biblioteca.caminho_do_arquivo(id)) as PackedScene
		if cena != null:
			return cena.instantiate() as Node3D
	var caixa := MeshInstance3D.new()                  # sem o modelo (cópia sem os assets locais): um bloco, para a cena não quebrar
	var b := BoxMesh.new()
	b.size = Vector3(1, 2, 1)
	caixa.mesh = b
	return caixa


func chao(x: float, z: float) -> float:
	return maxf(_raio_no_chao(x, z), PISO_DO_CAIS)


func _raio_no_chao(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, ancora.y + 12.0, z), Vector3(x, ancora.y - 12.0, z))
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) if not r.is_empty() else ancora.y


func ponto_no_chao(local: Vector3) -> Vector3:
	var p := ancora + local
	return Vector3(p.x, chao(p.x, p.z), p.z)


func _pos_do_navio(k: float) -> Vector3:
	var fim := Vector3(ancora.x + ATRACACAO.x, _y_agua, ancora.z + ATRACACAO.z)
	var ini := fim + Vector3(DISTANCIA_INICIAL_DO_NAVIO, 0.0, 6.0)
	var e := 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 2.2)            # desacelera até parar
	var p := ini.lerp(fim, e)
	p.y = _y_agua - _quilha - CALADO + 0.12 * sin(k * 40.0) * (1.0 - e * 0.7)        # quilha CALADO m abaixo da água, com balanço do mar
	return p


## Navio em `t` s desde o começo da cena (0 → longe; ≥ `T_CHEGADA_DO_NAVIO` → atracado).
func andar_navio(t: float) -> void:
	var k := t / T_CHEGADA_DO_NAVIO
	navio.global_position = _pos_do_navio(k)
	var calma := 1.0 - 0.6 * (1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 2.2))      # o balanço diminui ao atracar, sem sumir
	navio.rotation.z = deg_to_rad(1.6) * sin(t * 1.25) * calma                  # jogo de lado
	navio.rotation.x = deg_to_rad(0.9) * sin(t * 0.9 + 1.2) * calma             # cabeceio
	if _espuma != null:
		_espuma.emitting = k < 0.92


func tripulacao_no_convés() -> Vector3:
	return navio.global_position + Vector3(0.0, 4.0, 0.0)


func colocar_no_navio() -> void:
	buggy.global_position = tripulacao_no_convés()
	for i in tripulacao.size():
		tripulacao[i].global_position = tripulacao_no_convés() + Vector3(0.0, 0.0, (i - 1.5) * 1.6)


## Posições finais no píer (a tripulação em linha atrás do Buggy, todos de frente para a terra).
func posicao_da_tripulacao(i: int) -> Vector3:
	return ponto_no_chao(Vector3(POS_BUGGY.x + 2.2, 0.0, (i - (tripulacao.size() - 1) * 0.5) * 2.2))


func virar_para_terra(no: Node3D) -> void:
	no.rotation.y = PI / 2.0                           # a frente (−Z) aponta para −X


func colocar_no_pier() -> void:
	_encerrar_efeitos_do_navio()
	mostrar_tripulacao()
	andar_elenco(false)
	buggy.global_position = ponto_no_chao(POS_BUGGY)
	virar_para_terra(buggy)
	for i in tripulacao.size():
		tripulacao[i].global_position = posicao_da_tripulacao(i)
		virar_para_terra(tripulacao[i])
	navio.global_position = _pos_do_navio(1.0)


## Desembarque: Buggy e tripulação andam do convés ao píer em `dur` s (deslocamento em linha, com um pulinho de passada).
func desembarcar(t: float, dur: float) -> void:
	andar_elenco(t < dur)
	if prancha != null and not prancha.visible:
		_posicionar_prancha()
	var k := smoothstep(0.0, 1.0, clampf(t / dur, 0.0, 1.0))
	var passada := 0.0                                   # quem anda é a animação `walk` do próprio modelo
	var de_b := tripulacao_no_convés()
	buggy.global_position = de_b.lerp(ponto_no_chao(POS_BUGGY), clampf(k * 1.1, 0.0, 1.0)) + Vector3.UP * passada
	virar_para_terra(buggy)
	for i in tripulacao.size():
		var kk := clampf((k - 0.12 * float(i)) / (1.0 - 0.12 * float(tripulacao.size())), 0.0, 1.0)
		var de := tripulacao_no_convés() + Vector3(0.0, 0.0, (i - 1.5) * 1.6)
		tripulacao[i].global_position = de.lerp(posicao_da_tripulacao(i), kk) + Vector3.UP * passada
		virar_para_terra(tripulacao[i])
		if kk >= 1.0:
			_ao_pisar(tripulacao[i], 0.35 * float(i + 1))
	if k * 1.1 >= 1.0:
		_ao_pisar(buggy, 0.0)


## Primeira vez que o ator chega ao ponto final: nuvem de poeira nos pés e (se o modelo tiver) um gesto de "cheguei" — o Buggy de braços ao alto, o bando batendo palmas.
func _ao_pisar(no: Node3D, atraso: float) -> void:
	if _pisou.has(no):
		return
	_pisou[no] = true
	_poeira(no.global_position)
	var a: AnimacoesDoElenco = animadores.get(no)
	if a != null:
		if no == buggy:
			a.gesto("both_arm_up")
		else:
			get_tree().create_timer(atraso).timeout.connect(func() -> void: a.gesto("clap"))


## Nuvem curta de poeira (uma vez só) que se desfaz sozinha.
func _poeira(onde: Vector3) -> void:
	var p := CPUParticles3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.2
	bola.height = 0.4
	bola.radial_segments = 6
	bola.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.78, 0.7, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	bola.material = mat
	p.mesh = bola
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0.0, -1.2, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0.6))
	rampa.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = rampa
	add_child(p)
	p.global_position = onde + Vector3.UP * 0.1
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Plateia em ANEL em volta da mesa (raio `RAIO_DA_PLATEIA`), deixando livres o lado da vila (oeste, de onde o jogador chega) e o do Buggy (leste): os lugares se alternam norte/sul
## entre 75° e 140° a partir do eixo do Buggy (longe da tripulação). Cada um olha para a mesa (a orientação é feita pelo chamador: `olhar_para`).
func posicoes_da_plateia(n: int) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	var centro := ponto_no_chao(POS_MESA)
	var por_lado := int(ceil(n / 2.0))
	for i in n:
		var norte := i % 2 == 0
		var j := i / 2
		var f := (float(j) + 0.5) / maxf(float(por_lado), 1.0)
		var ang := deg_to_rad(lerpf(75.0, 140.0, f))
		var z := sin(ang) * RAIO_DA_PLATEIA * (1.0 if norte else -1.0)
		var x := cos(ang) * RAIO_DA_PLATEIA * -1.0        # o ângulo é medido a partir do Buggy (leste): cos>0 = mais perto dele
		saida.append(ponto_no_chao(Vector3(POS_MESA.x - x, 0.0, POS_MESA.z + z)))
	return saida


## O roteiro = o storyboard do Codex (`art_src/references/desafio_buggy/PLANO.md`), 4 planos: 1 navio aparece, 2 atraca, 3 desembarque, 4 CLOSE NO ROSTO do Buggy (a ÚNICA legenda,
## `chegada[0]`; o dono pediu foco no rosto quando ele fala). Mais lenta (21/11, pedido do dono): ~26 s. `legendas` = as falas do estado "chegada"; só a primeira entra na cena.
func planos(legendas: Array[Dictionary]) -> Array[Dictionary]:
	var A := ancora
	var y := chao(A.x - 2.0, A.z)
	var l1: Dictionary = legendas[0] if legendas.size() > 0 else {}
	# Onde o ROSTO estará quando ele terminar de descer: põe o Buggy (escondido) no ponto final, lê o nó `head` do modelo e devolve-o onde estava.
	var guardado := buggy.global_position
	buggy.global_position = ponto_no_chao(POS_BUGGY)
	virar_para_terra(buggy)
	var rosto := rosto_do_buggy()
	var pe := ponto_no_chao(POS_BUGGY)
	buggy.global_position = guardado
	return [
		# 1 — da terra para o mar: o navio aparece e se aproxima (devagar).
		{"dur": 6.5, "de": Vector3(A.x - 9.0, y + 3.2, A.z + 9.0), "de_fim": Vector3(A.x - 6.0, y + 3.0, A.z + 7.0),
			"para": Vector3(A.x + 55.0, _y_agua + 6.0, A.z - 2.0), "para_fim": Vector3(A.x + 38.0, _y_agua + 7.0, A.z - 2.0), "fov": 50.0,
			"fade_in": 1.4, "tremor": 0.02},
		# 2 — plano médio-geral lateral: o navio reduz e atraca.
		{"dur": 6.0, "de": Vector3(A.x + 12.0, _y_agua + 4.0, A.z + 34.0), "de_fim": Vector3(A.x + 14.0, _y_agua + 4.5, A.z + 30.0),
			"para": Vector3(A.x + 24.0, _y_agua + 8.0, A.z - 2.0), "para_fim": Vector3(A.x + 18.0, _y_agua + 7.0, A.z - 2.0), "fov": 52.0,
			"tremor": 0.03, "balanco": Vector2(0.7, 0.12)},
		# 3a — câmera baixa no cais, três quartos, DE LONGE do costado do navio (colada nele, a tela ficava toda de casco): o Buggy desembarca pela prancha e a tripulação vem atrás.
		{"dur": DURACAO_3A, "de": Vector3(A.x - 6.5, y + 1.3, A.z + 4.8), "de_fim": Vector3(A.x - 5.0, y + 1.5, A.z + 4.0),
			"para": Vector3(A.x + 4.0, y + 2.8, A.z - 1.0), "para_fim": Vector3(A.x + 1.0, y + 2.2, A.z), "fov": 52.0, "tremor": 0.015,
			"ao_entrar": Callable(self, "mostrar_tripulacao"), "atualizar": Callable(self, "_atualizar_desembarque")},
		# 3b — contra-plongée de frente para o Buggy pisando no píer (poeira, braços ao alto), o bando chegando atrás: ele ganha estatura antes do close.
		{"dur": 3.0, "de": pe + Vector3(-3.4, 0.35, 1.9), "de_fim": pe + Vector3(-2.8, 0.55, 1.5),
			"para": pe + Vector3(0.0, 1.5, 0.0), "para_fim": pe + Vector3(0.4, 1.9, 0.0), "fov": 46.0, "tremor": 0.01,
			"atualizar": Callable(self, "_atualizar_desembarque_b")},
		# 4 — CLOSE no rosto do Buggy (câmera se aproxima devagar) com a legenda.
		{"dur": 7.0, "de": rosto + Vector3(-2.3, 0.15, 0.9), "de_fim": rosto + Vector3(-1.5, 0.08, 0.45),
			"para": rosto, "para_fim": rosto + Vector3(0.0, -0.02, 0.0), "fov": 32.0, "legenda": l1, "tremor": 0.005,
			"ao_entrar": Callable(self, "_close_do_buggy")},
	]


## Entrou no close: ele ri (rosto) e gesticula enquanto fala.
func _close_do_buggy() -> void:
	ExpressoesDoBuggy.expressao(buggy, "riso")
	var a := animador_do_buggy()
	if a != null:
		a.falar(true)


func _atualizar_desembarque(t: float, _dur: float) -> void:
	desembarcar(t, DURACAO_DO_DESEMBARQUE)


## Segunda metade do desembarque (plano 3b): o tempo continua de onde o plano 3a parou.
func _atualizar_desembarque_b(t: float, _dur: float) -> void:
	desembarcar(t + DURACAO_3A, DURACAO_DO_DESEMBARQUE)
