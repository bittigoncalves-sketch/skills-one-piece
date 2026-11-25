extends Node3D
## Relógio e estados por conjuração. Dano só no servidor; visuais em cada peer.
const Visual := preload("res://src/effects/magu/visual_magu.gd")
# Formar o golpe é rápido; a lentidão do Magu está na VELOCIDADE do projétil.
const PREPARACAO := {"Z": .3, "X": .4, "C": .2, "V": .5}
# O vulcão nasce sempre ATRÁS do jogador; ESCALA_VULCAO amplia malha, campo e dano.
# 14/10/2026: vulcão x1,5 (1,6 -> 2,4); a distância acompanha para manter a folga até o jogador.
const ESCALA_VULCAO := 2.4
const DISTANCIA_VULCAO := 13.5
# Punho e onda x2 (malha e volume de contato). O punho nasce na mão, a onda no corpo.
const ESCALA_PUNHO := 2.0
const ESCALA_ONDA := 2.0
const DURACAO_CAO := 6.0
const VELOCIDADE := {"Z": 12.0, "X": 6.0}
const ALCANCE := {"Z": 30.0, "X": 24.0}
const RAIO_EXPLOSAO := 5.0
const DURACAO_CAMPO := 8.0
# Boca do vulcão (y do lábio da cratera x ESCALA_VULCAO) e ritmo das bolas de lava.
const BOCA_Y := 2.9
const INTERVALO_BOLAS := .35
var ator: Node3D
var slot := ""
var token := 0
var spec: DamageSpec
var rumo := Vector3.FORWARD
var tempo := 0.0
var fase := "preparacao"
var visual: Node3D
var mat: ShaderMaterial
var _origem := Vector3.ZERO
var _anterior := Vector3.ZERO
var _atingidos := {}
var _placas: Array[Dictionary] = []
var _pulso := 0.0
var _prox_bola := 0.0
var _prancha: Node3D
var _surfando := false
var _fumaca: GPUParticles3D
var _gotas: GPUParticles3D
var _vulcao_pedra := -1.0
var _limpo := false
var _modelo: Node3D
var _visivel := true

static func lancar(mundo: Node3D, dono: Node3D, tecla: String, direcao: Vector3, dano: DamageSpec, identidade := 0) -> Node3D:
	var e = load("res://src/effects/magu/tecnica_magu.gd").new()
	e.ator = dono
	e.slot = tecla
	e.spec = dano
	e.token = identidade
	e.rumo = direcao.normalized()
	if tecla != "Z":
		e.rumo.y = 0
		e.rumo = e.rumo.normalized() if e.rumo.length_squared() > .001 else Vector3.FORWARD
	mundo.add_child(e)
	e.global_position = dono.global_position
	e._origem = e.global_position
	e._anterior = e.global_position
	e.mat = Visual.material()
	e.visual = Visual.punho(e.mat) if tecla == "Z" else Visual.elipsoide(e,Vector3.ZERO,Vector3.ONE,e.mat)
	if e.visual.get_parent() == null: e.add_child(e.visual)
	e.visual.scale = Vector3.ONE*.2
	dono.set_meta("magu_acao",e)
	# Poses próprias (src/anim/MaguPoses.gd): Z arma o braço; X já assume a base de surfe.
	if tecla == "Z" or tecla == "X":
		dono.set_meta("custom_pose","magu_z_prep" if tecla == "Z" else "magu_x_surf")
	dono.set_meta("is_casting",true)
	e.add_to_group("magu_efeito")
	return e

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ator) or ator.is_queued_for_deletion():
		encerrar()
		return
	if (ator.get("health") != null and float(ator.get("health")) <= 0) or str(ator.get("current_fruit_id")) != "magu_magu":
		encerrar()
		return
	tempo += delta
	if fase == "pedra":
		mat.set_shader_parameter("fria",1.0)
		visual.scale *= maxf(0.0,1.0-delta*3.0)
		if tempo >= .65: encerrar()
		return
	if fase == "explosao":
		visual.scale = Vector3.ONE * lerpf(1.0,RAIO_EXPLOSAO*2.0,clampf(tempo/.35,0,1))
		Visual.animar_brasas(self,delta)
		if tempo > .6: encerrar()
		return
	if fase == "preparacao":
		if ator.has_method("corpo_livre_para_golpe") and not ator.corpo_livre_para_golpe():
			encerrar()
			return
		global_position = _origem_da_tecnica()
		visual.scale = Vector3.ONE*_escala_visual()*lerpf(.2,1.0,tempo/float(PREPARACAO[slot]))
		if _molhado(global_position,.5):
			_solidificar()
		elif tempo >= float(PREPARACAO[slot]):
			_ativar()
		return
	if slot == "C":
		_atualizar_cao(delta)
	elif slot == "V":
		_atualizar_campo(delta)
	else:
		_atualizar_projetil(delta)

func _ativar() -> void:
	tempo = 0
	fase = "ativo"
	visual.queue_free()
	match slot:
		"Z": visual = Visual.punho(mat)
		"X": visual = Visual.onda(mat)
		"C": visual = Visual.cao(mat, _altura_do_ator()*2.0)
		"V": visual = Visual.vulcao(mat)
	add_child(visual)
	visual.scale = Vector3.ONE*_escala_visual()
	if slot == "Z" or slot == "X":
		global_position = _origem_da_tecnica()
		look_at(global_position+rumo, Vector3.RIGHT if absf(rumo.y)>.98 else Vector3.UP)
		_liberar_acao()
		if slot == "Z": ator.set_meta("custom_pose","magu_z_soco")
		else: _subir_na_prancha()
	elif slot == "C":
		ator.set_meta("magu_cao_ativo",true)
		_modelo = ator.modelo_visual() if ator.has_method("modelo_visual") else null
		if is_instance_valid(_modelo):
			_visivel = _modelo.visible
			_modelo.hide()
		var combate = ator.get("combate_direcional")
		if combate != null: combate.cancelar(&"magu_cao")
	else:
		global_position = _chao(ator.global_position-rumo*DISTANCIA_VULCAO)
		_criar_campo()
		Visual.faiscas(self,mat,24)
		var boca := Vector3.UP*BOCA_Y*ESCALA_VULCAO
		_fumaca = Visual.fumaca_negra(self,boca,ESCALA_VULCAO)
		_gotas = Visual.gotas_de_lava(self,boca,.7*ESCALA_VULCAO,40)
		_liberar_acao()
	AudioFX.whoosh(self,global_position,.65)
	_anterior = global_position
	_origem = global_position

func _atualizar_projetil(delta: float) -> void:
	if slot == "Z" and tempo >= .35: _limpar_pose()
	if slot == "X": _surfar()
	var de := global_position
	var ate := de + rumo*float(VELOCIDADE[slot])*delta
	# A onda segue o relevo (e o jogador que a surfa), em vez de flutuar numa colina.
	if slot == "X": ate.y = _chao(ate).y
	var raio := .8*ESCALA_PUNHO if slot == "Z" else 1.4*ESCALA_ONDA
	# Amostrar o volume no percurso também pega água rasa e bordas estreitas.
	var passos := maxi(1,ceili(de.distance_to(ate)/.2))
	for i in range(passos+1):
		var p := de.lerp(ate,float(i)/passos)
		var molhou := _molhado(p,raio)
		if slot == "X":
			for lado in [-3.6,-1.8,1.8,3.6]:
				molhou = molhou or _molhado(p+global_basis.x*lado*ESCALA_ONDA,.15)
		if molhou:
			global_position=p
			_solidificar()
			return
	var elevacao := Vector3.UP*.35 if slot == "X" else Vector3.ZERO
	var consulta := PhysicsRayQueryParameters3D.create(de+elevacao,ate+elevacao,1)
	if ator is CollisionObject3D: consulta.exclude=[ator.get_rid()]
	var parede := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not parede.is_empty():
		global_position=parede.position
		_explodir(2.0 if slot=="Z" else 3.0)
		return
	global_position=ate
	if _servidor():
		for alvo in AlvosDeGolpe.todos(get_tree()):
			if not _alvo_valido(alvo) or _atingidos.has(alvo.get_instance_id()): continue
			var centro := AlvosDeGolpe.centro(alvo)
			var perto := Geometry3D.get_closest_point_to_segment(centro,de,ate)
			var acerta := _toca(alvo,de,ate,raio+.65)
			if slot=="X":
				# A onda tem 8,6 m de boca: mede o CORPO ao longo dela, não o centro.
				acerta=false
				for lado in [-4.0,-2.0,0.0,2.0,4.0]:
					var d: Vector3 = global_basis.x*lado*ESCALA_ONDA+Vector3.UP*.8*ESCALA_ONDA
					acerta = acerta or _toca(alvo,de+d,ate+d,1.2*ESCALA_ONDA)
			if acerta and _linha_livre(perto + (Vector3.UP*.35 if slot == "X" else Vector3.ZERO),alvo):
				_atingidos[alvo.get_instance_id()]=true
				if slot=="Z":
					_explodir(2.5)
					return
				_dano(alvo,global_position)
	if global_position.distance_to(_origem)>=float(ALCANCE[slot]): encerrar()

func _atualizar_cao(delta: float) -> void:
	global_position=_pes_do_ator()
	if is_instance_valid(_modelo): _modelo.hide()
	var v: Vector3 = ator.get("velocity") if ator.get("velocity") != null else Vector3.ZERO
	v.y=0
	Visual.animar_cao(visual,v.length())
	if v.length_squared()>.1: rumo=v.normalized()
	look_at(global_position+rumo)
	# O balanço segue a velocidade real; parado não há galope no lugar.
	visual.position.y=absf(sin(tempo*12.0))*.12*clampf(v.length()/12.6,0,1)
	var raio_contato := _altura_do_ator()
	if _molhado(global_position+Vector3.UP*(raio_contato+.1),raio_contato):
		_solidificar()
		return
	if _servidor():
		for alvo in AlvosDeGolpe.todos(get_tree()):
			if not _alvo_valido(alvo): continue
			var centro := AlvosDeGolpe.centro(alvo)
			var perto := Geometry3D.get_closest_point_to_segment(centro,_anterior+Vector3.UP,global_position+Vector3.UP)
			if _toca(alvo,_anterior+Vector3.UP,global_position+Vector3.UP,_altura_do_ator()*1.25) and _linha_livre(perto,alvo):
				_explodir(RAIO_EXPLOSAO)
				return
	_anterior=global_position
	if tempo>=DURACAO_CAO: encerrar()

func _criar_campo() -> void:
	# Placas independentes: a costa solidifica apenas a lava que tocou a água.
	for anel in range(1,5):
		for i in anel*10:
			var a := i*TAU/(anel*10.0)
			var offset := Vector3(cos(a),0,sin(a))*anel*2.0*ESCALA_VULCAO
			var pos := _chao(global_position+offset)
			var m := Visual.material()
			var placa := Visual.elipsoide(self,Vector3.ZERO,Vector3(2.7,.16,2.7)*ESCALA_VULCAO,m)
			placa.global_position=pos+Vector3.UP*.06
			placa.visible=false
			_placas.append({"no":placa,"mat":m,"inicio":anel*.45,"pedra":-1.0})

func _atualizar_campo(delta: float) -> void:
	if _vulcao_pedra < 0:
		visual.scale=Vector3.ONE*ESCALA_VULCAO*minf(1.0,.2+tempo*1.4)
	else:
		visual.scale*=maxf(0.0,1.0-delta*3.0)
		visual.visible=tempo-_vulcao_pedra<.65
	Visual.animar_brasas(self,delta)
	_lancar_bolas(delta)
	_pulso+=delta
	var causar := _pulso>=1.0
	if causar: _pulso-=1.0
	var alvos_do_pulso := {}
	for placa in _placas:
		if not is_instance_valid(placa.no): continue
		var n: Node3D=placa.no
		if tempo<float(placa.inicio): continue
		n.visible=true
		if float(placa.pedra)>=0:
			n.scale*=maxf(0,1.0-delta*3.0)
			if tempo-float(placa.pedra)>.65: n.queue_free()
			continue
		if _molhado(n.global_position,.15):
			placa.pedra=tempo
			placa.mat.set_shader_parameter("fria",1.0)
			continue
		if causar and _servidor():
			for alvo in AlvosDeGolpe.todos(get_tree()):
				if not _alvo_valido(alvo) or alvos_do_pulso.has(alvo): continue
				if AlvosDeGolpe.distancia_ao_corpo(alvo,n.global_position+Vector3.UP*.3)<1.7*ESCALA_VULCAO and _linha_livre(n.global_position+Vector3.UP*.3,alvo):
					alvos_do_pulso[alvo]=true
					_dano(alvo,n.global_position)
	if _vulcao_pedra < 0 and _molhado(global_position,.15):
		_vulcao_pedra=tempo
		mat.set_shader_parameter("fria",1.0)
	if tempo>=DURACAO_CAMPO: encerrar()

## Enquanto o vulcão está ativo, cospe bolas de lava em todas as direções (só visual).
func _lancar_bolas(delta: float) -> void:
	Visual.animar_bolas(self,delta,func(p: Vector3) -> float: return _chao(p).y)
	if _vulcao_pedra >= 0:
		for f in [_fumaca,_gotas]:
			if is_instance_valid(f): f.emitting = false
		return
	_prox_bola -= delta
	if _prox_bola > 0.0: return
	_prox_bola = INTERVALO_BOLAS
	var a := randf()*TAU
	var horizontal := randf_range(3.0,10.0)*ESCALA_VULCAO/1.6
	var vel := Vector3(cos(a)*horizontal,randf_range(9.0,15.0),sin(a)*horizontal)
	Visual.bola_de_lava(self,mat,global_position+Vector3.UP*BOCA_Y*ESCALA_VULCAO,vel,randf_range(.3,.65))

func _explodir(raio: float, notificar := true) -> void:
	_soltar_corpo()
	if notificar: _publicar_fim(false)
	AudioFX.impact(self,global_position,.65)
	_destransformar()
	if _servidor():
		for alvo in AlvosDeGolpe.todos(get_tree()):
			if _alvo_valido(alvo) and AlvosDeGolpe.distancia_ao_corpo(alvo,global_position)<raio and _linha_livre(global_position+Vector3.UP*.3,alvo):
				_dano(alvo,global_position)
	visual.queue_free()
	visual=Visual.elipsoide(self,Vector3.ZERO,Vector3.ONE,mat)
	Visual.faiscas(self,mat)
	fase="explosao"
	tempo=0
	_liberar_acao()

func _solidificar(notificar := true) -> void:
	_soltar_corpo()
	if notificar: _publicar_fim(true)
	_destransformar()
	_liberar_acao()
	fase="pedra"
	tempo=0
	mat.set_shader_parameter("fria",1.0)

func _dano(alvo: Node3D, origem: Vector3) -> void:
	var dano := spec.dano
	var defensor = alvo.get("combate_direcional")
	if defensor != null:
		match ResolucaoDeContato.resolver_tecnica(origem,defensor,35.0):
			ResolucaoDeContato.Resultado.BLOQUEIO:
				defensor.receber_bloqueio_de_postura(35.0)
				dano*=.3
			ResolucaoDeContato.Resultado.QUEBRA_DE_GUARDA: defensor.quebrar_guarda(null)
	var impulso := (AlvosDeGolpe.centro(alvo)-origem).normalized()*4.0
	CombatResolver.aplicar(alvo,dano,spec.cast_id,spec.teto,origem,impulso,.35,0,false,ator)

## O segmento de→ate passa a menos de `raio` do CORPO do alvo (não do centro).
func _toca(alvo: Node3D, de: Vector3, ate: Vector3, raio: float) -> bool:
	var passos := maxi(1,ceili(de.distance_to(ate)/1.0))
	for i in range(passos+1):
		if AlvosDeGolpe.distancia_ao_corpo(alvo,de.lerp(ate,float(i)/passos))<=raio: return true
	return false

func _alvo_valido(n: Node) -> bool:
	return is_instance_valid(n) and n!=ator and n is Node3D and n.has_method("take_damage") and (n.get("health")==null or float(n.get("health"))>0)

func _linha_livre(de: Vector3, alvo: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de,AlvosDeGolpe.centro(alvo),1)
	if ator is CollisionObject3D: q.exclude=[ator.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider==alvo

static func _molhado(p: Vector3, raio: float) -> bool:
	for d in [Vector3.ZERO,Vector3.RIGHT*raio,Vector3.LEFT*raio,Vector3.FORWARD*raio,Vector3.BACK*raio]:
		var agua := AguaDoMundo.superficie_em(p.x+d.x,p.z+d.z)
		if not is_nan(agua) and p.y-raio<=agua: return true
	return false

func _chao(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*4,p-Vector3.UP*12,1)
	if ator is CollisionObject3D: q.exclude=[ator.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty(): return hit.position
	var agua := AguaDoMundo.nivel_em(p.x,p.z)
	return Vector3(p.x,agua if not is_nan(agua) else p.y-.8,p.z)

## Onde a técnica nasce: Z na mão direita (o braço que soca), X no corpo (pés, centrada
## no jogador), V atrás do jogador. Com `rumo` o Z sai um pouco à frente da mão.
func _origem_da_tecnica() -> Vector3:
	match slot:
		"Z": return _mao_do_ator() + rumo*.35
		"X": return _chao(ator.global_position)
		_: return ator.global_position - rumo*.9

## Mão direita do rig (nó Hand_R, ou a ponta do antebraço); sem rig, ombro direito estimado.
func _mao_do_ator() -> Vector3:
	var mao := ator.find_child("Hand_R",true,false) as Node3D
	if mao == null:
		var h = ator.get("item_handle")
		if h is Node3D and is_instance_valid(h): mao = h
	if mao == null:
		var braco := ator.find_child("ForeArm_R",true,false) as Node3D
		if braco != null: return braco.global_position
		var frente := -ator.global_basis.z
		return _pes_do_ator() + Vector3.UP*_altura_do_ator()*.7 + frente.cross(Vector3.UP).normalized()*.35
	return mao.global_position

func _escala_visual() -> float:
	match slot:
		"Z": return ESCALA_PUNHO
		"X": return ESCALA_ONDA
		_: return 1.0

## X: o jogador sobe na CRISTA da onda, numa prancha de lava, e ela o carrega
## (Player.gd lê `magu_surf`: rumo da onda e o ponto da crista onde ficam os pés).
func _subir_na_prancha() -> void:
	_surfando = true
	_prancha = Visual.prancha(mat)
	_prancha.top_level = true
	add_child(_prancha)
	_surfar()

## Mantém a prancha sob os pés e solta o jogador se ele não acompanha mais a onda
## (atordoado, congelado, preso numa parede ou largado para trás).
func _surfar() -> void:
	if not _surfando: return
	var livre: bool = not ator.has_method("corpo_livre_para_golpe") or ator.corpo_livre_para_golpe()
	if not livre:
		_soltar_corpo()
		return
	# Pés no topo da crista, com um leve sobe-e-desce de quem cavalga a onda.
	var crista := global_position + global_basis*(Visual.CRISTA_LOCAL*ESCALA_ONDA) + Vector3.UP*(.08+.06*sin(tempo*5.0))
	ator.set_meta("magu_surf",{"rumo":rumo,"pes":crista,"base":_pes_do_ator_y_offset()})
	if is_instance_valid(_prancha):
		_prancha.global_transform = Transform3D(Basis.looking_at(rumo,Vector3.UP),crista)

## Distância do centro do corpo (origem do Player) até os pés, para pousar os pés na crista.
func _pes_do_ator_y_offset() -> float:
	return ator.global_position.y-_pes_do_ator().y

## Remove tudo o que a técnica pôs no corpo: surfe, pose e prancha. Idempotente.
func _soltar_corpo() -> void:
	_surfando = false
	if is_instance_valid(ator):
		ator.remove_meta("magu_surf")
		_limpar_pose()
	if is_instance_valid(_prancha):
		_prancha.queue_free()
	_prancha = null

func _limpar_pose() -> void:
	if is_instance_valid(ator) and str(ator.get_meta("custom_pose","")).begins_with("magu_") and slot in ["Z","X"]:
		ator.remove_meta("custom_pose")

func _servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _liberar_acao() -> void:
	if is_instance_valid(ator) and ator.has_meta("magu_acao") and ator.get_meta("magu_acao")==self:
		ator.remove_meta("magu_acao")
		ator.set_meta("is_casting",false)

func _destransformar() -> void:
	if slot!="C" or not is_instance_valid(ator): return
	ator.remove_meta("magu_cao_ativo")
	if ator.has_method("_atualizar_visibilidade_corpo"): ator._atualizar_visibilidade_corpo()
	elif is_instance_valid(_modelo): _modelo.visible=_visivel

func encerrar() -> void:
	if _limpo: return
	_limpo=true
	_soltar_corpo()
	_destransformar()
	_liberar_acao()
	if spec!=null: CombatResolver.encerrar(spec.cast_id)
	queue_free()

func _exit_tree() -> void:
	_soltar_corpo()
	_destransformar()
	_liberar_acao()
	if spec!=null: CombatResolver.encerrar(spec.cast_id)

func _publicar_fim(pedra: bool) -> void:
	if slot == "C" and _servidor() and multiplayer.has_multiplayer_peer() and ator.has_method("_net_magu_fim"):
		ator.rpc("_net_magu_fim",token,global_position,pedra)

func receber_fim(posicao: Vector3, pedra: bool) -> void:
	if fase in ["pedra","explosao"]: return
	global_position=posicao
	if pedra: _solidificar(false)
	else: _explodir(RAIO_EXPLOSAO,false)

func _altura_do_ator() -> float:
	var col := ator.get("_colisor") as CollisionShape3D
	if is_instance_valid(col):
		if col.shape is CapsuleShape3D: return col.shape.height*col.global_basis.get_scale().y
		if col.shape is BoxShape3D: return col.shape.size.y*col.global_basis.get_scale().y
	return 1.6

func _pes_do_ator() -> Vector3:
	var col := ator.get("_colisor") as CollisionShape3D
	if is_instance_valid(col): return col.global_position-Vector3.UP*_altura_do_ator()*.5
	return ator.global_position-Vector3.UP*.8
