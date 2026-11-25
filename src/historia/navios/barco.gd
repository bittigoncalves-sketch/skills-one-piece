extends CharacterBody3D
## Corpo vertical: yaw controla rumo; modelo, conves e leme acompanham as ondas.
## Origem = centro horizontal do casco na linha d'água. Frente = -Z.
const Perfil := preload("res://src/historia/navios/perfil_barco.gd")
## Casco atacado (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5): bestas do mar miram o
## barco. Decisão do dono: a zero, ele AFUNDA e é PERDIDO (compra-se outro no vendedor).
signal afundou(barco: CharacterBody3D)
signal casco_atingido(barco: CharacterBody3D, vida: float)
## Quanto do dano o casco sente. Medido no `test_encontros_no_mar` (14/10/2026): uma besta
## parada atirando num barco parado tira ~1,9/s (muitas bolhas erram o casco pequeno). Com
## 0,3 o bote levava ~268 s — mais que os 120 s que a besta insiste: nunca afundava, e a
## decisão do dono (afunda e PERDE) não existiria. Com 1,2: bote ~1 min, chalupa ~3 min,
## galeão ~11 min — o risco é real para barco pequeno e cai com o tamanho.
const FATOR_DE_DANO_NO_CASCO := 1.2
const TEMPO_DE_AFUNDAR := 4.5
var health := 0.0
var max_health := 0.0
var afundando := false
const Esteira := preload("res://src/historia/navios/esteira.gd")
var leme: Node3D
var ficha: Dictionary = {}
var modelo_id := ""
var nome_exibido := ""
var tamanho_casco := Vector3.ONE
var altura_conves := 0.0
var perfil: Dictionary = {}
var visual: Node3D
var _modelo: Node3D
var _esteira: Node3D
var _acelerador := 0.0
var _comando_leme := 0.0
var _giro := 0.0
var _na_agua := false
var _velocidade := 0.0
var _pilotado := false
var _formas: Array[Dictionary] = []
var _h_antes := NAN          # altura da água no quadro anterior (velocidade da onda)
## Flutuação: mola até a superfície + amortecimento sobre a velocidade RELATIVA à
## onda. Com a mola antiga (ω ≈ 3,7 rad/s, amortecimento sobre a velocidade
## absoluta) o casco seguia a onda com ~46° de atraso e ficava até 0,6 m afundado
## na crista (medido 03/10/2026, chalupa e galeão).
const FLUTUA_MOLA := 40.0
const FLUTUA_AMORTECE := 12.0


func configurar(bib: BibliotecaDeModelos, id: String, tamanho: Vector3) -> bool:
	if visual != null or not bib.tem(id) or not Perfil.e_navegavel(id) or not tamanho.is_finite() or tamanho.x <= 0 or tamanho.y <= 0 or tamanho.z <= 0:
		return false
	ficha = bib.ficha_de_navio(id)
	if ficha.is_empty():
		return false
	_modelo = bib.instanciar(id)
	if _modelo == null:
		return false
	modelo_id = id
	nome_exibido = nome_do_navio(id, ficha, str(bib.info(id)["nome"]))
	perfil = Perfil.criar(bib,id,tamanho)
	tamanho_casco = perfil["tamanho_casco"]
	altura_conves = perfil["conves"]
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Um casco é obstáculo, nunca uma plataforma que transporta outro barco.
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	max_slides = 4
	safe_margin = .015
	visual = Node3D.new()
	visual.name = "Balanço"
	add_child(visual)
	var orientacao := Node3D.new()
	orientacao.name = "OrientacaoDoArquivo"
	orientacao.rotation.y = perfil["yaw_modelo"]
	visual.add_child(orientacao)
	_modelo.scale = perfil["escala"]
	_modelo.position = -perfil["origem_arquivo"] * perfil["escala"]
	orientacao.add_child(_modelo)
	if perfil.get("conves_do_modelo", false):
		_criar_conves_do_modelo(bib, id, tamanho, orientacao)
	leme = Node3D.new()
	leme.name = "Leme"
	leme.position = perfil["leme"]
	visual.add_child(leme)
	_criar_colisoes()
	_esteira = Esteira.new()
	_esteira.name = "Esteira"
	_esteira.configurar(tamanho_casco.x,tamanho_casco.z)
	add_child(_esteira)
	add_to_group("barcos_historia")
	add_to_group("alvo_de_besta")
	max_health = float(ficha.get("vida", 100))
	health = max_health
	return true


## Funil de dano (`CombatResolver.aplicar`): o casco sente `FATOR_DE_DANO_NO_CASCO`.
func take_damage(amount: float, _from_pos := Vector3.ZERO, _knockback := Vector3.ZERO, _hitstun := 0.3) -> void:
	if afundando or health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount * FATOR_DE_DANO_NO_CASCO)
	casco_atingido.emit(self, health)
	if health <= 0.0:
		_afundar()


## Some água abaixo em `TEMPO_DE_AFUNDAR`, adernando; depois sai da cena. Quem pilota é
## solto pelo `Navegacao` (sinal `afundou`, antes de sair da árvore).
func _afundar() -> void:
	afundando = true
	definir_pilotado(false)
	remove_from_group("alvo_de_besta")
	afundou.emit(self)
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(conves_do_modelo):
		conves_do_modelo.collision_layer = 0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position:y", global_position.y - maxf(8.0, tamanho_casco.y * 2.5), TEMPO_DE_AFUNDAR) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "rotation:z", rotation.z + deg_to_rad(35.0), TEMPO_DE_AFUNDAR)
	t.tween_property(self, "rotation:x", rotation.x + deg_to_rad(-12.0), TEMPO_DE_AFUNDAR)
	t.chain().tween_callback(queue_free)


## Centro para mira e visão das bestas (`AlvosDeGolpe.centro`): meio do casco.
func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * altura_conves * 0.5


## Nome em português pela classe da ficha (o nome do modelo da loja é o do arquivo,
## "Small Ship"): o que o jogador lê no leme e no vendedor de barcos.
const NOMES_DE_CLASSE := {"bote": "Bote", "chalupa": "Chalupa", "galeao": "Galeão"}

static func nome_da_classe(f: Dictionary, reserva: String) -> String:
	return str(NOMES_DE_CLASSE.get(str(f.get("classe", "")), reserva))


## Os 3 barcos antigos levam o nome da classe ("Galeão"); os do Mine Piece, o próprio
## ("Going Merry", "Moby Dick").
static func nome_do_navio(id: String, f: Dictionary, nome_do_catalogo: String) -> String:
	return nome_da_classe(f, nome_do_catalogo) if id in Perfil.LEGADO else nome_do_catalogo


## Peça do editor é centrada nos bounds do GLB. A compensação abaixo preserva
## exatamente a malha, inclusive escala XYZ e origem assimétrica do galeão.
func posicionar_no_mapa(p: Dictionary) -> void:
	if perfil.is_empty():
		return
	var yaw := deg_to_rad((p["rotacao_graus"] as Vector3).y)
	rotation = Vector3(0,yaw-float(perfil["yaw_modelo"]),0)
	var deslocamento: Vector3 = (perfil["centro_arquivo"]-perfil["origem_arquivo"]) * perfil["escala"]
	position = (p["posicao"] as Vector3) - Basis(Vector3.UP,yaw) * deslocamento


func definir_comando(acelerador: float, comando_leme: float) -> void:
	_acelerador = clampf(acelerador,-1,1) if is_finite(acelerador) else 0.0
	_comando_leme = clampf(comando_leme,-1,1) if is_finite(comando_leme) else 0.0


func limpar_comando() -> void:
	_acelerador = 0.0
	_comando_leme = 0.0


## Só o barco com piloto simula motor, ondas e espuma. Os demais conservam
## posição e colisões do convés, sem consultas de água nem movimento por quadro.
func definir_pilotado(ligado: bool) -> void:
	_pilotado = ligado and not perfil.is_empty()
	limpar_comando()
	velocity = Vector3.ZERO
	_velocidade = 0.0
	_giro = 0.0
	_h_antes = NAN
	set_physics_process(_pilotado)
	if not _pilotado:
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		if is_instance_valid(_esteira):
			_esteira.limpar()


func esta_na_agua() -> bool:
	return _na_agua


func velocidade_atual() -> float:
	return _velocidade


func _ready() -> void:
	set_physics_process(_pilotado)
	_sincronizar_conves()
	var h := AguaDoMundo.superficie_em(global_position.x,global_position.z)
	_na_agua = not is_nan(h) and global_position.y < h + float(perfil.get("calado",0.0)) + .5


func _physics_process(delta: float) -> void:
	var dt := clampf(delta,0,.05)
	if not _pilotado or dt <= 0 or perfil.is_empty():
		return
	var amostras := _amostrar()
	var h: float = amostras["altura"]
	# Faixa de contato larga (1,5 m acima da onda): com 0,45 m o casco que subia
	# com a onda "saía da água", a mola desligava e a gravidade puxava — a média
	# ficava 0,6 m abaixo da linha d'água nos cascos maiores (medido 03/10/2026).
	var contato: bool = not is_nan(h) and global_position.y < h + float(perfil["calado"]) + 1.5
	_na_agua = contato
	var frente := -global_basis.z.normalized()
	var longitudinal := velocity.dot(frente)
	var maxima := maxf(float(ficha["velocidade"]),0.0)
	# Sem água o motor não empurra. Arrasto continua até parar, inclusive na costa.
	var alvo := _acelerador * maxima * (.38 if _acelerador < 0 else 1.0) if contato else 0.0
	var resposta := .55 if absf(alvo) > .01 else .22
	longitudinal = lerpf(longitudinal,alvo,1.0-exp(-resposta*dt))
	if not contato:
		longitudinal *= exp(-2.6*dt)
	# Leme depende da água passando pelo casco; em ré o sentido se inverte.
	var fluxo := clampf(absf(longitudinal)/maxf(maxima*.45,.1),0,1)
	var giro_alvo := -_comando_leme * deg_to_rad(float(ficha["curva"])) * fluxo * signf(longitudinal) if contato else 0.0
	_giro = lerpf(_giro,giro_alvo,1.0-exp(-2.4*dt))
	_girar_sem_atravessar(_giro*dt)
	frente = -global_basis.z.normalized()
	var lateral := velocity - frente * velocity.dot(frente)
	lateral.y = 0
	var horizontal := frente * longitudinal + lateral * exp(-3.5*dt)
	# Teste da proa impede navegar sobre terra mesmo quando ela está sob o casco.
	if contato and not _rota_molhada(horizontal*dt):
		horizontal = Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if contato:
		# Mola amortecida; força limitada para não saltar após hitch ou mudança de rio.
		# O amortecimento compara com a velocidade da PRÓPRIA onda: o casco sobe e
		# desce junto com a água, sem atraso de fase.
		var erro := clampf(h-global_position.y,-2.0,2.0)
		var v_onda := clampf((h - _h_antes) / dt, -6.0, 6.0) if not is_nan(_h_antes) else 0.0
		velocity.y = clampf(velocity.y+(erro*FLUTUA_MOLA-(velocity.y-v_onda)*FLUTUA_AMORTECE)*dt,-6.0,6.0)
	else:
		velocity.y = maxf(velocity.y-14.0*dt,-20.0)
	_h_antes = h
	# ⚠️ JOGADOR NO CONVÉS NÃO SEGURA O BARCO. `move_and_slide` trata outro corpo
	# como obstáculo: quem estava em pé no convés impedia o casco de SUBIR com a
	# onda, e ele afundava 0,7–1,2 m (medido 03/10/2026, chalupa e galeão). O barco
	# ignora os jogadores SÓ durante o próprio movimento (o giro já ignorava): a
	# exceção do Godot vale para os dois lados, e deixada ligada o jogador
	# atravessava o convés. Fora daqui ele pisa no barco e é levado como plataforma.
	var ignorados: Array[PhysicsBody3D] = []
	for j in get_tree().get_nodes_in_group("player"):
		if j is PhysicsBody3D and not j in get_collision_exceptions():
			add_collision_exception_with(j)
			ignorados.append(j)
	move_and_slide()
	for j in ignorados:
		if is_instance_valid(j):
			remove_collision_exception_with(j)
	_velocidade = get_real_velocity().dot(frente)
	# move_and_slide já remove a velocidade contra obstáculos. A velocidade real
	# inclui a recuperação de sobreposição: reinjetá-la criava impulso entre cascos.
	_balançar(amostras,dt)
	_sincronizar_conves()
	_esteira.atualizar(global_position,frente,_velocidade,dt,_na_agua)


func _amostrar() -> Dictionary:
	var metade_z := tamanho_casco.z * .34
	var metade_x := tamanho_casco.x * .30
	var pontos := [Vector3(0,0,-metade_z),Vector3(0,0,metade_z),Vector3(-metade_x,0,0),Vector3(metade_x,0,0)]
	var niveis: Array[float] = []
	var soma := 0.0
	var n := 0
	for ponto: Vector3 in pontos:
		var p := to_global(ponto)
		var y := AguaDoMundo.superficie_em(p.x,p.z)
		niveis.append(y)
		if not is_nan(y):
			soma += y
			n += 1
	var centro := AguaDoMundo.superficie_em(global_position.x,global_position.z)
	var h := soma/float(n) if n >= 2 and not is_nan(centro) else centro
	var pitch := 0.0
	var roll := 0.0
	if n == 4:
		pitch = atan2(niveis[0]-niveis[1],maxf(metade_z*2,.1))
		roll = atan2(niveis[3]-niveis[2],maxf(metade_x*2,.1))
	elif not is_nan(centro):
		var normal := global_basis.inverse() * AguaDoMundo.normal_em(global_position.x,global_position.z)
		pitch = atan2(normal.z,normal.y)
		roll = atan2(-normal.x,normal.y)
	return {"altura": h,"pitch": clampf(pitch,-.14,.14),"roll": clampf(roll,-.14,.14)}


func _balançar(amostras: Dictionary, dt: float) -> void:
	var k := 1.0-exp(-3.0*dt)
	var inclinacao := -_giro * _velocidade * .008 if _na_agua else 0.0
	visual.rotation.x = lerp_angle(visual.rotation.x,float(amostras["pitch"]) if _na_agua else 0.0,k)
	visual.rotation.z = lerp_angle(visual.rotation.z,clampf(float(amostras["roll"])+inclinacao,-.14,.14) if _na_agua else 0.0,k)
	for registro in _formas:
		(registro["no"] as CollisionShape3D).transform = visual.transform * (registro["repouso"] as Transform3D)


func _rota_molhada(deslocamento: Vector3) -> bool:
	if deslocamento.length_squared() < .000001:
		return true
	var proa := -global_basis.z * (tamanho_casco.z*.42*signf(deslocamento.dot(-global_basis.z)))
	for lado: float in [-.3,0.0,.3]:
		var p: Vector3 = global_position+deslocamento+proa+global_basis.x*tamanho_casco.x*lado
		if is_nan(AguaDoMundo.nivel_em(p.x,p.z)):
			return false
	return true


func _girar_sem_atravessar(angulo: float) -> void:
	if absf(angulo) < .00001:
		return
	var proposta := global_transform
	proposta.basis = Basis(Vector3.UP,angulo)*proposta.basis
	var espaco := get_world_3d().direct_space_state
	var excluidos: Array[RID] = rids_proprios()
	for j in get_tree().get_nodes_in_group("player"):
		if j is CollisionObject3D:
			excluidos.append(j.get_rid())
	for registro in _formas:
		var col := registro["no"] as CollisionShape3D
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = col.shape
		q.transform = proposta*col.transform
		q.collision_mask = 1
		q.exclude = excluidos
		# Jogador sobre o convés não deve bloquear guinada; contato é suportado pelo piso.
		if not espaco.intersect_shape(q,1).is_empty():
			_giro = 0.0
			return
	global_transform = proposta


func _criar_colisoes() -> void:
	var casco: PackedVector2Array = perfil["casco"]
	var pts := PackedVector3Array()
	# Navio do mod: o casco convexo só vai até um palmo acima da linha d'água (bate em
	# terra, cais e outro casco); acima dele quem segura o jogador é o convés do modelo,
	# com cabines e porões abertos.
	var topo := minf(altura_conves, .6) if perfil.get("conves_do_modelo", false) else altura_conves
	for p in casco:
		pts.append(Vector3(p.x,topo,p.y))
		pts.append(Vector3(p.x*.73,-float(perfil["calado"]),p.y*.90))
	_adicionar_convexo("Casco",pts)
	if perfil["bote"]:
		# Borda em cunhas: conserva a cavidade do bote em vez de uma caixa maciça.
		for i in casco.size():
			var a := casco[i]
			var b := casco[(i+1)%casco.size()]
			var pontos := PackedVector3Array()
			for p in [a,b]:
				pontos.append(Vector3(p.x,altura_conves,p.y))
				pontos.append(Vector3(p.x*1.18,float(perfil["borda"]),p.y*1.18))
				pontos.append(Vector3(p.x*1.08,float(perfil["borda"]),p.y*1.08))
				pontos.append(Vector3(p.x*.90,altura_conves,p.y*.90))
			_adicionar_convexo("Borda%d"%i,pontos)
	for parte in perfil["partes"]:
		var forma := BoxShape3D.new()
		forma.size = parte["tamanho"]
		_adicionar_forma("ParteDoCasco",forma,Transform3D(Basis.IDENTITY,parte["centro"]))
	for rampa in perfil["rampas"]:
		_adicionar_convexo("PassagemDoConves",rampa["pontos"])


func _adicionar_convexo(nome: String, pontos: PackedVector3Array) -> void:
	var forma := ConvexPolygonShape3D.new()
	forma.points = pontos
	_adicionar_forma(nome,forma,Transform3D.IDENTITY)


func _adicionar_forma(nome: String, forma: Shape3D, repouso: Transform3D) -> void:
	var col := CollisionShape3D.new()
	col.name = nome
	col.shape = forma
	col.transform = repouso
	add_child(col)
	_formas.append({"no": col,"repouso": repouso})


## Convés andável do navio do Mine Piece (18/10/2026): a malha `Colisao` do modelo num
## AnimatableBody3D que acompanha o casco e o balanço e LEVA quem está em cima (plataforma
## que se move). Não colide com o próprio casco; dano nele vai para o casco.
## Rejeitado: a malha côncava no próprio CharacterBody3D — o teste de movimento do Godot
## não funciona com forma côncava e o navio atravessaria a terra.
var conves_do_modelo: AnimatableBody3D
## O convés é `top_level` e quem o move é o barco (`_sincronizar_conves`): AnimatableBody3D
## levado só pelo pai NÃO informa velocidade à física (medido 18/10/2026: velocidade de
## plataforma 0 com o navio a 3,7 m/s — o jogador escorregava para a popa).
var _orientacao: Node3D
var _conves_pos := Vector3.ZERO


func _criar_conves_do_modelo(bib: BibliotecaDeModelos, id: String, tamanho: Vector3, pai: Node3D) -> void:
	conves_do_modelo = load("res://src/historia/navios/conves_do_navio.gd").new()
	conves_do_modelo.name = "ConvesDoModelo"
	conves_do_modelo.set("barco", self)
	conves_do_modelo.sync_to_physics = true
	conves_do_modelo.collision_layer = 1
	conves_do_modelo.collision_mask = 0
	var info := bib.info(id)
	_orientacao = pai
	_conves_pos = _modelo.position + (info["centro"] as Vector3) * (perfil["escala"] as Vector3)
	conves_do_modelo.top_level = true
	var col := CollisionShape3D.new()
	col.name = "Colisao"
	col.shape = bib.forma_de_colisao(id, tamanho)
	conves_do_modelo.add_child(col)
	add_child(conves_do_modelo)
	add_collision_exception_with(conves_do_modelo)
	conves_do_modelo.add_collision_exception_with(self)
	set_notify_transform(true)


func _sincronizar_conves() -> void:
	if is_instance_valid(conves_do_modelo) and is_inside_tree() and _orientacao != null:
		conves_do_modelo.global_transform = _orientacao.global_transform * Transform3D(Basis.IDENTITY, _conves_pos)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sincronizar_conves()


## O casco e o convés do modelo: as consultas diretas ao espaço físico NÃO respeitam a
## exceção de colisão entre os dois — quem consulta "o barco cabe aqui?" exclui ambos.
func rids_proprios() -> Array[RID]:
	var saida: Array[RID] = [get_rid()]
	if is_instance_valid(conves_do_modelo):
		saida.append(conves_do_modelo.get_rid())
	return saida


## Retorna ponto dos pés no convés; NAN quando nenhuma saída comporta um humano.
func ponto_no_conves_livre() -> Vector3:
	var forma := CapsuleShape3D.new()
	forma.radius = .38
	forma.height = 1.6
	var excluidos: Array[RID] = []
	for j in get_tree().get_nodes_in_group("player"):
		if j is CollisionObject3D:
			excluidos.append(j.get_rid())
	for ponto: Vector3 in perfil["saidas"]:
		var p := visual.to_global(ponto)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform.origin = p+Vector3.UP*.87
		q.collision_mask = 1
		q.exclude = excluidos
		if get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():
			return p
	return Vector3(NAN,NAN,NAN)
