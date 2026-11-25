class_name CorridaDeCaranguejos
extends Node3D
# ============================================================================
#  CORRIDA DE CARANGUEJOS — o controlador (06/10/2026).
#
#  Pedido do dono: "pista de corrida gigante… corrida de caranguejos, um npc para
#  iniciar a corrida, o prêmio será 10 moedas, a requisição para participar é ter um
#  caranguejo, obstáculos na pista e parkour. não é possível sair do caranguejo até o
#  fim da corrida, total 5 minutos". Decisões dele (06/10): mapa próprio; rivais com IA
#  E prêmio para quem completar em até 5:00, mesmo sem chegar em 1º.
#
#  Fluxo: `pedir_largada` (NPC ou F8) → monta a pista longe da ilha, leva o caranguejo
#  do jogador ao grid com 5 rivais, monta e TRAVA → contagem 3-2-1 → corrida pelos
#  portões em ordem (queda = volta ao último portão) → chegada ou 5:00 → resultado e
#  prêmio → volta à ilha, destrava, apaga a pista.
#
#  A pista mora NESTA cena (região à parte sobre o mar): o caranguejo, a montaria, o
#  progresso e a HUD já vivem aqui. Relógio = soma do delta da física (determinístico).
# ============================================================================

signal terminou(resultado: Dictionary)

const Ficha := preload("res://src/historia/pets/ficha_montaria.gd")
const Locomocao := preload("res://src/historia/pets/locomocao_de_montaria.gd")
const Piloto := preload("res://src/historia/corrida/piloto_de_caranguejo.gd")
const Obstaculos := preload("res://src/historia/corrida/obstaculos_da_pista.gd")
const Hud := preload("res://src/ui/hud_da_corrida.gd")
const Cores := preload("res://src/historia/corrida/cores_dos_caranguejos.gd")
const CENA_DO_CARANGUEJO := "res://src/historia/pets/caranguejo.gd"

const LIMITE := 300.0
const PREMIO := 10
const CONTAGEM := 3.0
const MOSTRA_RESULTADO := 6.0
const QUEDA_Y := -2.5                 # local: abaixo disso caiu da pista
const VOLTA_DA_QUEDA := 0.8
const PRESO := 9.0                    # s sem avançar = IA presa: volta ao portão
## A ilha vai de −280 a 333 em x e de −280 a 280 em z: a pista fica ~1,4 km ao norte.
const ORIGEM_XZ := Vector2(-110.0, -1700.0)
const TRAVA := "Não dá para descer do caranguejo durante a corrida."
## A cor de cada rival é SORTEADA a cada corrida (`CoresDosCaranguejos`, pedido do dono).
const RIVAIS := [
	{"nome": "Pinça Ligeira", "talento": 0.985, "erro": 0.03},
	{"nome": "Casco de Ferro", "talento": 0.965, "erro": 0.02},
	{"nome": "Maré Alta", "talento": 0.95, "erro": 0.05},
	{"nome": "Rei do Recife", "talento": 0.935, "erro": 0.04},
	{"nome": "Areia Veloz", "talento": 0.92, "erro": 0.07},
]
const VAGA_DO_JOGADOR := 4            # 2ª fila, no meio
const RAIAS := [-0.7, 0.0, 0.7, -0.35, 0.0, 0.35]

enum Estado { FORA, CONTAGEM, CORRENDO, RESULTADO }

var progressao: ProgressaoDoPersonagem
var companhia: Node
var montarias: Node
var jogador_de: Callable
var limite := LIMITE
## Quanto o resultado fica na tela antes de voltar à ilha (testes esticam para ver os
## rivais chegarem).
var mostra_resultado := MOSTRA_RESULTADO
## Testes: a IA que pilota o caranguejo do jogador depois da largada (no lugar do
## teclado). O controlador a liga à pista e a recoloca no caminho quando ele reaparece.
var piloto_do_jogador: RefCounted = null
## Testes: semente do sorteio das cores dos rivais (0 = sorteio de verdade a cada corrida).
var semente_das_cores := 0
var estado := Estado.FORA
var tempo := 0.0
var dados := {}
var corredores: Array[Dictionary] = []
var resultado_final := {}

var _pista: Node3D
var _obst: Node3D
var _hud: CanvasLayer
var _luzes: Array[MeshInstance3D] = []
var _relogio := 0.0
var _volta := Transform3D()
var _pets_pausados := {}
var _origem := Vector3.ZERO
var _sem_sela := 0.0


func _ready() -> void:
	add_to_group("corrida_de_caranguejos")
	_hud = Hud.new()
	add_child(_hud)


func ativa() -> bool:
	return estado != Estado.FORA


static func e_caranguejo(especie: String) -> bool:
	return especie in ["caranguejo", "caranguejo_grande"]


## O caranguejo do jogador ("" = não tem). Prefere o que já está fora do inventário.
func caranguejo_do_jogador() -> String:
	if progressao == null:
		return ""
	var achado := ""
	for id in progressao.pets:
		if e_caranguejo(progressao.especie_do_pet(str(id))):
			if companhia != null and companhia.pet_fora(str(id)) != null:
				return str(id)
			if achado.is_empty():
				achado = str(id)
	return achado


## "" se pode correr; senão o motivo (a loja do NPC mostra).
func motivo_para_nao_correr() -> String:
	if ativa():
		return "A corrida já está acontecendo."
	if caranguejo_do_jogador().is_empty():
		return "Você precisa de um caranguejo para correr."
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or companhia == null or montarias == null:
		return "A corrida não está pronta."
	return ""


## Começa: devolve o aviso (vazio = foi). O NPC e o F8 chamam.
func pedir_largada() -> String:
	var motivo := motivo_para_nao_correr()
	if not motivo.is_empty():
		return motivo
	var j: CharacterBody3D = jogador_de.call()
	var id := caranguejo_do_jogador()
	var siri: CharacterBody3D = companhia.pet_fora(id)
	if montarias.ativa() and montarias.pet != siri:
		montarias.desmontar(true)
	if siri == null:
		if not companhia.chamar(id):
			return str(companhia.motivo) if not str(companhia.motivo).is_empty() else "O caranguejo não veio."
		siri = companhia.pet_fora(id)
	_volta = j.global_transform
	_montar_pista()
	var vaga: Dictionary = dados.largada[VAGA_DO_JOGADOR]
	_por(siri, vaga.p, 0.0)
	if not montarias.ativa():
		j.global_position = _origem + vaga.p + Vector3(2.4, 1.0, 0.0)
		j.velocity = Vector3.ZERO
		if not montarias.montar(siri, true):
			_apagar_pista()
			j.global_transform = _volta
			_por_no_mundo(siri, _volta.origin + _volta.basis.x * 2.5)
			return "Não deu para montar no caranguejo agora. Tente de novo."
	montarias.trava = TRAVA
	montarias.piloto = _parado
	montarias.aviso.emit("Corrida de caranguejos! O Y fica travado até a chegada.")
	siri.set_meta(companhia.EM_CORRIDA, true)
	corredores.clear()
	corredores.append(_corredor(0, progressao.nome_do_pet(id), Color("f2c230"), siri, true, 1.0))
	var sorteio := RandomNumberGenerator.new()
	if semente_das_cores != 0:
		sorteio.seed = semente_das_cores
	else:
		sorteio.randomize()
	var cores := Cores.sortear(RIVAIS.size(), sorteio)
	var i := 0
	for v in dados.largada.size():
		if v == VAGA_DO_JOGADOR:
			continue
		corredores.append(_novo_rival(i, dados.largada[v], cores[i]))
		i += 1
	_pausar_pets(siri)
	if piloto_do_jogador != null:
		piloto_do_jogador.caminho = dados.caminho
		piloto_do_jogador.obstaculos = _obst
		piloto_do_jogador.recomecar(0)
	tempo = 0.0
	_relogio = 0.0
	resultado_final = {}
	estado = Estado.CONTAGEM
	return ""


# ------------------------------------------------------------------ pista

func _montar_pista() -> void:
	dados = PistaDosCaranguejos.gerar()
	var nivel := -0.65
	var mar := get_tree().current_scene.get_node_or_null("Oceano") if get_tree().current_scene != null else null
	if mar != null and mar.get("nivel") != null and is_finite(float(mar.get("nivel"))):
		nivel = float(mar.get("nivel"))
	_origem = Vector3(ORIGEM_XZ.x, nivel + PistaDosCaranguejos.ALTURA_DO_DECK, ORIGEM_XZ.y)
	_pista = Node3D.new()
	_pista.name = "PistaDosCaranguejos"
	add_child(_pista)
	_pista.global_position = _origem
	var lido := MapaArquivo.validar(PistaDosCaranguejos.mapa(dados))
	if lido.ok:
		MapaMontador.montar(_pista, lido.mapa)
	else:
		push_error("[Corrida] pista inválida: %s" % str(lido.erros.slice(0, 3)))
	_obst = Obstaculos.new()
	_obst.name = "Obstaculos"
	_pista.add_child(_obst)
	_obst.montar(dados.obstaculos, dados.zonas)
	_placas()
	_semaforo()


## Nome de cada trecho no alto do portão (quem vem chegando lê).
func _placas() -> void:
	var n := 0
	for g: Dictionary in dados.portoes:
		if int(g.indice) < 1:
			continue
		n += 1
		var placa := Label3D.new()
		placa.text = "%d · %s" % [n, str(g.nome).to_upper()] if int(g.indice) < PistaDosCaranguejos.TRECHOS.size() else "CHEGADA"
		placa.font_size = 96
		placa.pixel_size = 0.01
		placa.outline_size = 22
		placa.modulate = Color(0.98, 0.93, 0.78)
		placa.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_pista.add_child(placa)
		placa.position = (g.p as Vector3) + Vector3.UP * 7.6


## Três luzes no arco de largada: acendem vermelhas na contagem e ficam verdes no JÁ.
func _semaforo() -> void:
	_luzes.clear()
	for k in 3:
		var luz := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 0.55
		esf.height = 1.1
		luz.mesh = esf
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.12, 0.12)
		m.emission_enabled = true
		m.emission = Color.BLACK
		luz.material_override = m
		_pista.add_child(luz)
		luz.position = Vector3((k - 1) * 2.6, 8.9, 0.0)
		_luzes.append(luz)


func _acender(n: int, verde: bool) -> void:
	for k in _luzes.size():
		var m := _luzes[k].material_override as StandardMaterial3D
		var acesa := verde or k < n
		var cor := Color(0.25, 1.0, 0.45) if verde else Color(1.0, 0.18, 0.12)
		m.albedo_color = cor if acesa else Color(0.12, 0.12, 0.12)
		m.emission = cor if acesa else Color.BLACK
		m.emission_energy_multiplier = 2.5 if acesa else 0.0


func _apagar_pista() -> void:
	if is_instance_valid(_pista):
		_pista.queue_free()
	_pista = null
	_obst = null
	_luzes.clear()


# ------------------------------------------------------------------ corredores

func _corredor(id: int, nome: String, cor: Color, corpo: CharacterBody3D, jogador: bool, talento: float) -> Dictionary:
	return {"id": id, "nome": nome, "cor": cor, "corpo": corpo, "perfil": Ficha.perfil(corpo), "jogador": jogador,
		"talento": talento, "proximo": 1, "tempo_final": -1.0, "quedas": 0, "caindo": 0.0, "impulso": 0.0,
		"fator_impulso": 1.0, "piloto": null, "joquei": {}}


func _novo_rival(i: int, vaga: Dictionary, cor: Color) -> Dictionary:
	var f: Dictionary = RIVAIS[i]
	var siri: CharacterBody3D = (load(CENA_DO_CARANGUEJO) as GDScript).new()
	siri.name = "Rival_%d" % (i + 1)
	siri.set("nome_exibido", f.nome)
	siri.position = vaga.p
	_pista.add_child(siri)
	siri.set_physics_process(false)
	# Rival não é pet do jogador: fora do menu B, da montaria e da doma.
	siri.remove_from_group("pets_historia")
	# O caranguejo inteiro na cor sorteada; a bandeirola, o piloto e o nome também.
	Cores.pintar(siri.get("visual"), cor)
	_bandeirola(siri, cor)
	_por(siri, vaga.p, 0.0)
	var c := _corredor(i + 1, str(f.nome), cor, siri, false, float(f.talento))
	var p := Piloto.new()
	p.caminho = dados.caminho
	p.obstaculos = _obst
	p.configurar(7919 * (i + 1), float(RAIAS[i % RAIAS.size()]), float(f.erro))
	c.piloto = p
	c.joquei = _joquei(siri, cor, str(f.nome), i + 1)
	return c


## Bandeirola na cor do rival, atrás do piloto (como nos karts): lê de longe.
func _bandeirola(siri: Node, cor: Color) -> void:
	var visual: Node3D = siri.get("visual")
	if visual == null:
		return
	var b := Node3D.new()
	b.name = "Bandeirola"
	# Frente do movimento = +X local do visual (o caranguejo anda de lado): atrás = −X.
	b.position = Vector3(-0.75, 1.1, 0.0)
	visual.add_child(b)
	var mastro := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.025
	cil.bottom_radius = 0.035
	cil.height = 1.7
	mastro.mesh = cil
	var cinza := StandardMaterial3D.new()
	cinza.albedo_color = Color(0.82, 0.83, 0.86)
	mastro.material_override = cinza
	mastro.position.y = 0.85
	b.add_child(mastro)
	var pano := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(0.62, 0.5, 0.03)
	prisma.left_to_right = 0.0
	pano.mesh = prisma
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	pano.material_override = m
	# Pano para trás do mastro, perpendicular ao chão.
	pano.rotation = Vector3(0, PI * 0.5, -PI * 0.5)
	pano.position = Vector3(-0.32, 1.45, 0.0)
	b.add_child(pano)


## O piloto montado do rival: o mesmo rig do jogador e dos NPCs, sentado (a pose de
## montaria do animador lê `montado`), com a cor do rival e o nome no alto.
func _joquei(siri: Node3D, cor: Color, nome: String, numero: int) -> Dictionary:
	var corpo := Node3D.new()
	corpo.name = "Joquei"
	corpo.set_meta("montado", true)
	corpo.set_meta("montaria_larga", true)
	_pista.add_child(corpo)
	var rig := PlayerRig.new()
	rig.name = "Rig"
	corpo.add_child(rig)
	rig.montar_em(corpo)
	rig.montar("base")
	if rig.modelo() != null:
		NpcDaIlha.tingir(rig.modelo(), {"capa": cor, "calca": cor.darkened(0.55)})
	var rotulo := Label3D.new()
	rotulo.text = "%d · %s" % [numero, nome]
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0045
	rotulo.outline_size = 12
	rotulo.modulate = cor.lightened(0.35)
	rotulo.position = Vector3.UP * 3.2
	siri.add_child(rotulo)
	return {"corpo": corpo, "rig": rig}


func _assentar_joquei(c: Dictionary, delta: float) -> void:
	if (c.joquei as Dictionary).is_empty():
		return
	var siri: CharacterBody3D = c.corpo
	var corpo := c.joquei.corpo as Node3D
	var rig := c.joquei.rig as PlayerRig
	var visual := Locomocao.visual_de(siri, c.perfil)
	corpo.global_rotation = Vector3(0, visual.global_rotation.y - float(c.perfil.desvio_yaw), 0)
	var anim := rig.procedural()
	if anim == null:
		return
	anim.update(siri.velocity, true, false, delta, 0.0)
	var quadril: Node3D = anim._n.get("Torso")
	var assento: Vector3 = visual.to_global(c.perfil.assento)
	corpo.global_position = assento - (quadril.global_position - corpo.global_position) if quadril != null else assento


## Põe o corpo no ponto LOCAL da pista, parado, virado para `rumo`.
func _por(siri: CharacterBody3D, local: Vector3, rumo: float) -> void:
	_por_no_mundo(siri, _origem + local + Vector3.UP * 0.3)
	var perfil := Ficha.perfil(siri)
	Locomocao.visual_de(siri, perfil).rotation.y = rumo + float(perfil.desvio_yaw)


func _por_no_mundo(siri: CharacterBody3D, onde: Vector3) -> void:
	siri.global_position = onde
	siri.velocity = Vector3.ZERO


func _pausar_pets(siri: Node) -> void:
	_pets_pausados.clear()
	for id in companhia.corpos_fora():
		var pet: Node3D = companhia.corpos_fora()[id]
		if pet == siri:
			continue
		_pets_pausados[pet] = {"fisica": pet.is_physics_processing(), "proc": pet.is_processing(), "visivel": pet.visible}
		pet.set_physics_process(false)
		pet.set_process(false)
		pet.visible = false


func _soltar_pets() -> void:
	for pet in _pets_pausados:
		if is_instance_valid(pet):
			var s: Dictionary = _pets_pausados[pet]
			pet.set_physics_process(s.fisica)
			pet.set_process(s.proc)
			pet.visible = s.visivel
	_pets_pausados.clear()


## Quem conduz o caranguejo do jogador na corrida: o teclado (Callable vazio) ou a IA.
func _quem_pilota() -> Callable:
	return _ia_do_jogador if piloto_do_jogador != null else Callable()


func _ia_do_jogador(delta: float) -> Dictionary:
	var siri: CharacterBody3D = _eu().corpo
	return piloto_do_jogador.comando(siri.global_position - _origem, siri.velocity, siri.is_on_floor(), delta)


func _parado(_delta: float) -> Dictionary:
	return {"dir": Vector3.ZERO, "correr": false, "saltar": false}


# ------------------------------------------------------------------ corrida

func _physics_process(delta: float) -> void:
	if estado == Estado.FORA:
		return
	_relogio += delta
	match estado:
		Estado.CONTAGEM:
			var falta := CONTAGEM - _relogio
			_acender(clampi(int(_relogio) + 1, 1, 3), false)
			_hud.centro(str(int(ceil(falta))) if falta > 0.0 else "")
			_hud.atualizar(0.0, limite, _posicao_do_jogador(), corredores.size(), 0, _total_de_portoes(), "Largada")
			for c in corredores:
				if not c.jogador:
					Locomocao.mover(c.corpo, c.perfil, Vector3.ZERO, false, false, delta)
					_assentar_joquei(c, delta)
			if falta <= 0.0:
				_acender(3, true)
				_hud.centro("JÁ!", Color(0.35, 0.86, 0.55), 1.0)
				montarias.piloto = _quem_pilota()
				estado = Estado.CORRENDO
				_relogio = 0.0
		Estado.CORRENDO, Estado.RESULTADO:
			# O relógio segue depois da chegada do jogador: quem cruza depois recebe o
			# próprio tempo (parado, todos herdavam o do jogador — medido).
			tempo += delta
			_obst.atualizar(delta)
			for c in corredores:
				_passo(c, delta)
			if estado == Estado.CORRENDO:
				var eu := _eu()
				var g: Dictionary = dados.portoes[mini(int(eu.proximo) - 1, dados.portoes.size() - 1)]
				_hud.atualizar(tempo, limite, _posicao_do_jogador(), corredores.size(), int(eu.proximo) - 1, _total_de_portoes(), str(g.nome))
				if float(eu.tempo_final) >= 0.0:
					_terminar(true)
				elif tempo >= limite:
					_terminar(false)
			elif _relogio >= mostra_resultado:
				voltar()
	_segurar_na_sela(delta)


func _passo(c: Dictionary, delta: float) -> void:
	var siri: CharacterBody3D = c.corpo
	if not is_instance_valid(siri):
		return
	var pe := siri.global_position - _origem
	var z: Dictionary = _obst.zona(pe)
	if z.has("impulso"):
		c.impulso = float(z.impulso)
		c.fator_impulso = float(z.fator_impulso)
	c.impulso = maxf(0.0, float(c.impulso) - delta)
	var fator := float(c.talento) * float(z.get("lama", 1.0)) * (float(c.fator_impulso) if float(c.impulso) > 0.0 else 1.0)
	siri.set_meta(Locomocao.FATOR, fator)
	var batida: Dictionary = _obst.impacto(int(c.id), pe)
	if not batida.is_empty():
		siri.velocity += batida.impulso
		siri.set_meta(Locomocao.ATORDOADO, float(batida.atordoar))
		if c.jogador:
			_hud.centro("Ai!", Color(1.0, 0.6, 0.3), 0.5)
	if not c.jogador:
		var acabou := float(c.tempo_final) >= 0.0
		var cmd: Dictionary = _parado(delta) if acabou else c.piloto.comando(pe, siri.velocity, siri.is_on_floor(), delta)
		Locomocao.mover(siri, c.perfil, cmd.dir, cmd.correr, cmd.saltar, delta)
		_assentar_joquei(c, delta)
		if not acabou and c.piloto.parado > PRESO:
			_reaparecer(c)
	_conferir_portao(c, siri.global_position - _origem)
	if siri.global_position.y - _origem.y < QUEDA_Y:
		c.caindo = float(c.caindo) + delta
		if float(c.caindo) >= VOLTA_DA_QUEDA:
			_reaparecer(c)
			if c.jogador:
				_hud.centro("Caiu! De volta ao portão", Color(1.0, 0.6, 0.3), 1.2)
	else:
		c.caindo = 0.0


func _conferir_portao(c: Dictionary, pe: Vector3) -> void:
	if float(c.tempo_final) >= 0.0 or int(c.proximo) >= dados.portoes.size():
		return
	var g: Dictionary = dados.portoes[int(c.proximo)]
	var d: Vector3 = pe - g.p
	if d.dot(g.frente) > 0.0 and absf(d.dot(g.direita)) < float(g.largura) * 0.5 + 3.0 and absf(d.y) < 9.0:
		c.proximo = int(c.proximo) + 1
		if int(c.proximo) >= dados.portoes.size():
			c.tempo_final = tempo


## Volta ao último portão passado (queda, IA presa).
func _reaparecer(c: Dictionary) -> void:
	var g: Dictionary = dados.portoes[int(c.proximo) - 1]
	var meia := float(g.largura) * 0.5 - 1.6
	var lado := clampf((float(int(c.id) % 3) - 1.0) * 2.5, -meia, meia)
	var p: Vector3 = (g.p as Vector3) + (g.frente as Vector3) * float(g.get("volta", 4.0)) + (g.direita as Vector3) * lado
	p.y = _chao_em(p, (g.p as Vector3).y)
	var f: Vector3 = g.frente
	_por(c.corpo, p, atan2(-f.x, -f.z))
	(c.corpo as Node).set_meta(Locomocao.ATORDOADO, 0.4)
	c.quedas = int(c.quedas) + 1
	c.caindo = 0.0
	var ia: RefCounted = c.piloto if not c.jogador else piloto_do_jogador
	if ia != null:
		ia.recomecar(int(g.caminho))


## Altura (local) do chão da pista em `p`: rampa e degrau não deixam o corpo enterrado.
func _chao_em(p: Vector3, padrao: float) -> float:
	var de := _origem + p + Vector3.UP * 7.0
	var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 14.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y - _origem.y if not hit.is_empty() else padrao


## Se a sela soltar no meio da corrida (não devia), monta de novo; 2 s sem sela = fim.
func _segurar_na_sela(delta: float) -> void:
	if estado == Estado.FORA or montarias.ativa():
		_sem_sela = 0.0
		return
	var eu := _eu()
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j != null and is_instance_valid(eu.corpo):
		j.global_position = (eu.corpo as Node3D).global_position + Vector3(2.4, 1.0, 0.0)
		if montarias.montar(eu.corpo, true):
			montarias.trava = TRAVA
			montarias.piloto = _quem_pilota() if estado != Estado.CONTAGEM else _parado
			return
	_sem_sela += delta
	if _sem_sela > 2.0:
		push_warning("[Corrida] o jogador saiu da sela e não voltou: corrida encerrada.")
		if estado == Estado.CORRENDO:
			_terminar(false)
		voltar()


func _eu() -> Dictionary:
	for c in corredores:
		if c.jogador:
			return c
	return {}


func _total_de_portoes() -> int:
	return dados.portoes.size() - 1 if not dados.is_empty() else 0


## Ordem atual: quem chegou (pelo tempo), depois quem passou mais portões e está mais
## perto do próximo.
func classificacao() -> Array[Dictionary]:
	var lista: Array[Dictionary] = corredores.duplicate()
	lista.sort_custom(_na_frente)
	return lista


func _na_frente(a: Dictionary, b: Dictionary) -> bool:
	var ta := float(a.tempo_final)
	var tb := float(b.tempo_final)
	if ta >= 0.0 or tb >= 0.0:
		if ta >= 0.0 and tb >= 0.0:
			return ta < tb
		return ta >= 0.0
	if int(a.proximo) != int(b.proximo):
		return int(a.proximo) > int(b.proximo)
	return _falta(a) < _falta(b)


func _falta(c: Dictionary) -> float:
	var g: Dictionary = dados.portoes[mini(int(c.proximo), dados.portoes.size() - 1)]
	return ((c.corpo as Node3D).global_position - _origem).distance_to(g.p)


func _posicao_do_jogador() -> int:
	var lista := classificacao()
	for i in lista.size():
		if lista[i].jogador:
			return i + 1
	return lista.size()


func _terminar(completou: bool) -> void:
	var eu := _eu()
	var lista := classificacao()
	var tabela: Array[Dictionary] = []
	for c in lista:
		tabela.append({"nome": c.nome, "tempo": float(c.tempo_final), "jogador": c.jogador})
	var premio := PREMIO if completou and float(eu.tempo_final) <= limite else 0
	if premio > 0 and progressao != null:
		progressao.ganhar_ouro(premio)
	resultado_final = {"completou": completou, "posicao": _posicao_do_jogador(), "tempo": float(eu.tempo_final) if completou else tempo,
		"premio": premio, "limite": limite, "quedas": int(eu.quedas), "classificacao": tabela}
	estado = Estado.RESULTADO
	_relogio = 0.0
	montarias.piloto = _parado
	_hud.resultado(resultado_final)
	terminou.emit(resultado_final)


## Fim: leva o jogador (montado) de volta para onde saiu, destrava e apaga a pista.
func voltar() -> void:
	if estado == Estado.FORA:
		return
	var eu := _eu()
	estado = Estado.FORA
	montarias.trava = ""
	montarias.piloto = Callable()
	if not eu.is_empty() and is_instance_valid(eu.corpo):
		var siri: CharacterBody3D = eu.corpo
		siri.remove_meta(companhia.EM_CORRIDA)
		siri.set_meta(Locomocao.FATOR, 1.0)
		siri.set_meta(Locomocao.ATORDOADO, 0.0)
		_por_no_mundo(siri, _volta.origin + Vector3.UP * 0.4)
		if not montarias.ativa():
			var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
			if j != null:
				j.global_transform = _volta
	_soltar_pets()
	corredores.clear()
	_apagar_pista()
	_hud.esconder()
