class_name AnimadorDeAnimal
extends RefCounted
# ============================================================================
#  ANIMADOR DE ANIMAL — o corpo dos animais da ilha em movimento (01/10/2026).
#
#  Decisão do dono: animação PROCEDURAL por tipo de corpo; longe do jogador o animal
#  anda SEM animação (`ligado = false`, quem decide é a `PopulacaoDeAnimais`).
#
#  Três caminhos, escolhidos pelo que o modelo TEM:
#    • esqueleto + clipes (os riggados no Blender por tools/blender/rig_animais.py e os
#      que já vieram com ossos — búfalo, macaco, águia...): toca o clipe certo por
#      palavra-chave (idle/walk/run/damage/attack/death/fly), com o ritmo do andar
#      casado com o passeio da ficha e o do correr com a corrida (o clipe do rig foi
#      feito para essas velocidades: a pata não escorrega);
#    • caranguejo: o animador das oito patas do pet (`animador_caranguejo.gd`);
#    • malha única (os 22 do pacote estático — nenhuma perna separada): movimento de
#      CORPO INTEIRO por tipo: quadrúpede trota (sobe-desce, balanço), saltador pula
#      (arco + achatamento na chegada), ave de chão bamboleia e bica, rastejante
#      serpenteia, voador plana e inclina na curva.
#
#  Mexe só no NÓ DO MODELO (posição/rotação/escala relativas ao repouso guardado em
#  `montar`); o corpo físico é do `AnimalDaIlha`.
# ============================================================================

## Palavras-chave dos clipes, por intenção, em ordem de preferência.
const CLIPES := {
	"parado": ["idle", "eat", "look"],
	"andando": ["walk", "trot", "fastwalk"],
	"correndo": ["gallop", "run", "trot", "fastwalk"],
	"atacando": ["attack_headbutt", "attack", "chestdrum", "leap"],
	"dano": ["damage", "hurt", "hit"],
	"morto": ["death", "sleep"],
	"voando": ["fly", "flapping"],
	"planando": ["gliding", "glide", "idle", "fly"],   # o voador riggado plana no "idle"
}
const LOOPS := ["parado", "andando", "correndo", "voando", "planando"]

var ligado := true
## Uma habilidade controla a pose final; locomoção e reação não trocam o clipe.
var exclusivo := false
var corpo := "quadrupede"

var _modelo: Node3D
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _base_escala := Vector3.ONE
var _altura := 1.0
var _comprimento := 1.0
var _ap: AnimationPlayer = null
var _clipes := {}            # intenção -> nome do clipe
var _atual := ""
var _caranguejo: Node3D = null
var _fase := 0.0
var _tempo := 0.0
var _ataque := 0.0
var _dano := 0.0
var _morte := 0.0
var _bicada := 0.0
var _proxima_bicada := 3.0
var _guinada := 0.0          # para inclinar na curva
## Vértices dos PÉS (a faixa mais baixa da malha, no espaço do modelo) e a altura do
## mais baixo em repouso: toda pose procedural é corrigida para o pé mais baixo
## continuar rente ao chão — inclinar não afunda a pata nem levanta o bicho.
var _pes := PackedVector3Array()
var _chao_em_repouso := 0.0
const FAIXA_DOS_PES := 0.12  # fração da altura
const MAX_PES := 96


func montar(modelo: Node3D, tipo_de_corpo: String, altura: float, comprimento: float) -> void:
	_modelo = modelo
	corpo = tipo_de_corpo
	_altura = maxf(altura, 0.05)
	_comprimento = maxf(comprimento, 0.05)
	_base_pos = modelo.position
	_base_rot = modelo.rotation
	_base_escala = modelo.scale
	_fase = randf() * TAU
	_proxima_bicada = randf_range(1.5, 5.0)
	var aps := modelo.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_ap = aps[0]
		var lista := _ap.get_animation_list()
		for intencao in CLIPES:
			for chave in CLIPES[intencao]:
				var achado := _clipe_por_chave(lista, chave)
				if not achado.is_empty():
					_clipes[intencao] = achado
					break
		for intencao in LOOPS:
			if _clipes.has(intencao):
				var anim := _ap.get_animation(_clipes[intencao])
				if anim != null:
					anim.loop_mode = Animation.LOOP_LINEAR
		_tocar("parado", 1.0)
	elif tipo_de_corpo == "caranguejo" and modelo.find_child("Corpo", true, false) != null:
		_caranguejo = preload("res://src/historia/pets/animador_caranguejo.gd").new()
		_caranguejo.name = "Patas"
		modelo.add_child(_caranguejo)
		_caranguejo.call("montar", modelo)
	else:
		_guardar_pes()


## O clipe para uma palavra-chave: nome exato, depois começo do nome, por fim "contém"
## ("idle" casava com "Idle_HitReact_Left" do búfalo; só a ordem alfabética salvava).
static func _clipe_por_chave(lista: PackedStringArray, chave: String) -> String:
	var melhor := ""
	var nota := 0
	for nome in lista:
		# "Rig|Rig|Gorilla_walk" -> "gorilla_walk", "extra/damage" -> "damage": o nome que
		# importa é o último (biblioteca extra: clipes gerados para modelo que já tinha ossos).
		var curto := String(nome).get_slice("|", String(nome).get_slice_count("|") - 1).to_lower()
		curto = curto.get_slice("/", curto.get_slice_count("/") - 1)
		var n := 0
		if curto == chave or curto.ends_with("_" + chave):
			n = 3
		elif curto.begins_with(chave) or curto.contains("_" + chave):
			n = 2
		elif curto.contains(chave):
			n = 1
		if n > nota:
			melhor = nome
			nota = n
	return melhor


func tem_clipes() -> bool:
	return _ap != null and not _clipes.is_empty()


func atacar() -> void:
	if exclusivo:
		return
	_ataque = 0.45
	_dano = 0.0
	if tem_clipes() and ligado and _clipes.has("atacando"):
		_ataque = _tocar_uma_vez("atacando", 0.1)
	if _caranguejo != null:
		_caranguejo.call("beliscar")


## Golpe recebido: o clipe de dano (sem ele, um recuo do corpo). Não interrompe o próprio
## ataque — o bicho que já está dando a cabeçada termina a cabeçada.
func tomar_dano() -> void:
	if exclusivo:
		return
	if _morte > 0.0 or (_ataque > 0.0 and _atual == "atacando"):
		return
	_dano = 0.3
	if tem_clipes() and ligado and _clipes.has("dano"):
		_dano = _tocar_uma_vez("dano", 0.05)


## Toca um clipe sem laço do começo; devolve quanto ele dura.
func _tocar_uma_vez(intencao: String, mistura: float) -> float:
	_ap.speed_scale = 1.0
	_ap.play(_clipes[intencao], mistura)
	_ap.seek(0.0, true)
	_atual = intencao
	return maxf(_ap.get_animation(_clipes[intencao]).length, 0.1)


func morrer() -> void:
	_morte = 0.001
	if tem_clipes() and _clipes.has("morto"):
		_ap.speed_scale = 1.0
		_ap.play(_clipes["morto"], 0.15)
		_atual = "morto"


func reviver() -> void:
	exclusivo = false
	_morte = 0.0
	_ataque = 0.0
	_dano = 0.0
	if _modelo != null:
		_modelo.position = _base_pos
		_modelo.rotation = _base_rot
		_modelo.scale = _base_escala
	if tem_clipes():
		_atual = ""
		_tocar("parado", 1.0)


## `vel_local`: velocidade no espaço do MODELO (z = para frente). `vel_andar` e
## `vel_correr`: passeio e corrida da ficha (o ritmo dos clipes). `estado`: parado,
## andando, correndo, voando.
func animar(delta: float, vel_local: Vector3, vel_andar: float, vel_correr: float, estado: String, curva: float) -> void:
	if exclusivo:
		return
	if _modelo == null:
		return
	_tempo += delta
	_ataque = maxf(0.0, _ataque - delta)
	_dano = maxf(0.0, _dano - delta)
	_guinada = lerpf(_guinada, curva, clampf(delta * 4.0, 0.0, 1.0))
	if _morte > 0.0:
		_morte += delta
		if not tem_clipes():
			_tombar()
		return
	if not ligado:
		# LONGE DO JOGADOR: sem animação (pedido do dono). Clipe congelado, corpo em
		# repouso — o animal só desliza.
		if _ap != null and _ap.is_playing():
			_ap.pause()
		return
	var rapidez := Vector2(vel_local.x, vel_local.z).length()
	if tem_clipes():
		if (_ataque > 0.0 and _atual == "atacando") or (_dano > 0.0 and _atual == "dano"):
			return
		var intencao := estado if _clipes.has(estado) else ("andando" if rapidez > 0.15 else "parado")
		if estado == "correndo" and not _clipes.has("correndo"):
			intencao = "andando"
		var ritmo := 1.0
		if intencao in ["andando", "correndo"]:
			var ref := vel_correr if intencao == "correndo" and _clipes.has("correndo") else vel_andar
			ritmo = clampf(rapidez / maxf(ref, 0.1), 0.5, 2.2)
		_tocar(intencao, ritmo)
		return
	if _caranguejo != null:
		_caranguejo.call("animar", delta, vel_local, true, 0.0)
		return
	_procedural(delta, rapidez, estado)


func atualizar_base_exclusiva() -> void:
	_ataque = 0.0
	_dano = 0.0
	if _ap != null and _clipes.has("planando"):
		_tocar("planando", 1.0)


func _tocar(intencao: String, ritmo: float) -> void:
	if not _clipes.has(intencao):
		return
	if _atual != intencao or not _ap.is_playing():
		_ap.play(_clipes[intencao], 0.25)
		_atual = intencao
	if intencao != "andando" and intencao != "correndo":
		ritmo *= Lentidao.fator(_modelo.get_parent() if _modelo != null else null)     # parado/ataque/dano no tempo do bicho (andar já segue a velocidade dele)
	_ap.speed_scale = ritmo


# ------------------------------------------------------------- procedural
func _procedural(delta: float, rapidez: float, estado: String) -> void:
	var pos := _base_pos
	var rot := _base_rot
	var esc := _base_escala
	var passada := _comprimento * (0.7 if corpo == "quadrupede" else 0.5)
	_fase += delta * TAU * rapidez / maxf(passada, 0.05)
	var andando := clampf(rapidez / 0.6, 0.0, 1.0)
	var bob := 0.0               # subida do passo (fora da correção dos pés)
	match corpo:
		"quadrupede":
			bob = absf(sin(_fase)) * _altura * 0.035 * andando
			rot.x += sin(2.0 * _fase) * 0.025 * andando
			rot.z += sin(_fase) * 0.035 * andando
			# Parado: respira e olha em volta. (Sem esqueleto não dá para baixar SÓ a
			# cabeça; inclinar o corpo todo para pastar levantava a traseira.)
			esc.y *= 1.0 + 0.012 * sin(_tempo * 2.1) * (1.0 - andando)
			rot.y += sin(_tempo * 0.45 + _fase) * 0.14 * (1.0 - andando)
		"saltador":
			# Um pulo por passada: arco, frente inclinada no ar, achata ao tocar o chão.
			var u := fposmod(_fase / TAU, 1.0)
			var arco := sin(PI * u) * andando
			bob = arco * _altura * 0.55
			rot.x += (0.25 - 0.5 * u) * andando
			var chegada := clampf(1.0 - u * 6.0, 0.0, 1.0) * andando
			esc.y *= 1.0 - 0.18 * chegada
			esc.x *= 1.0 + 0.10 * chegada
			esc.z *= 1.0 + 0.10 * chegada
		"ave_chao":
			rot.z += sin(_fase) * 0.16 * andando
			bob = absf(sin(_fase)) * _altura * 0.04 * andando
			rot.x += _pastar(delta, andando) * 0.45      # bicar o chão
		"rastejante":
			rot.y += sin(_fase * 2.0) * 0.28 * andando
			rot.z += sin(_fase * 2.0 + 1.2) * 0.05 * andando
		"voador":
			# Sem asa separada: inclina na curva, arfa com a subida e "bate" a asa
			# esticando a envergadura no ritmo do voo.
			rot.z += clampf(-_guinada * 0.5, -0.7, 0.7)
			pos.y += sin(_tempo * 7.0) * _altura * 0.15
			esc.x *= 1.0 + 0.07 * sin(_tempo * 14.0)
	if _ataque > 0.0:
		# Investida: o corpo avança e baixa a frente.
		var k := sin(PI * (1.0 - _ataque / 0.45))
		pos.z += k * _comprimento * 0.25
		rot.x += k * 0.25
	elif _dano > 0.0:
		# Golpe recebido: recua e ergue a frente.
		var k := sin(PI * (1.0 - _dano / 0.3))
		pos.z -= k * _comprimento * 0.08
		rot.x -= k * 0.12
	_modelo.rotation = rot
	_modelo.scale = esc
	_modelo.position = pos + Vector3.UP * (_correcao_dos_pes(pos, rot, esc) + bob)


## Quanto subir (ou descer) o modelo para o pé mais baixo ficar onde fica em repouso.
func _correcao_dos_pes(pos: Vector3, rot: Vector3, esc: Vector3) -> float:
	if _pes.is_empty():
		return 0.0
	var pose := Transform3D(Basis.from_euler(rot) * Basis.from_scale(esc), pos)
	var lo := INF
	for v in _pes:
		lo = minf(lo, (pose * v).y)
	return _chao_em_repouso - lo


func _guardar_pes() -> void:
	var faces := PackedVector3Array()
	for mi: MeshInstance3D in _modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or BibliotecaDeModelos.e_malha_de_colisao(mi):
			continue
		faces.append_array(BibliotecaDeModelos._transformacao_ate(mi, _modelo) * mi.mesh.get_faces())
	if faces.is_empty():
		return
	var lo := INF
	var hi := -INF
	for v in faces:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	var corte := lo + (hi - lo) * FAIXA_DOS_PES
	var vistos := {}
	for v in faces:
		if v.y <= corte and not vistos.has(v):
			vistos[v] = true
	var todos: Array = vistos.keys()
	var passo := maxi(1, ceili(float(todos.size()) / MAX_PES))
	for i in range(0, todos.size(), passo):
		_pes.append(todos[i])
	var repouso := Transform3D(Basis.from_euler(_base_rot) * Basis.from_scale(_base_escala), _base_pos)
	_chao_em_repouso = INF
	for v in _pes:
		_chao_em_repouso = minf(_chao_em_repouso, (repouso * v).y)


## Cabeça baixa de vez em quando, só parado. Devolve 0..1.
func _pastar(delta: float, andando: float) -> float:
	_proxima_bicada -= delta
	if _proxima_bicada <= 0.0 and andando < 0.1:
		_bicada = 1.4 if corpo == "quadrupede" else 0.35
		_proxima_bicada = randf_range(2.5, 7.0)
	_bicada = maxf(0.0, _bicada - delta)
	var dur := 1.4 if corpo == "quadrupede" else 0.35
	return sin(clampf(_bicada / dur, 0.0, 1.0) * PI) * (1.0 - andando)


func _tombar() -> void:
	var k := clampf(_morte / 0.5, 0.0, 1.0)
	var rot := _base_rot + Vector3(0, 0, k * PI * 0.5)
	_modelo.rotation = rot
	# Deitado de lado: o flanco encosta no chão (a correção dos pés vale para o
	# corpo todo aqui — o ponto mais baixo passa a ser o lado).
	_modelo.position = _base_pos + Vector3.UP * _correcao_dos_pes(_base_pos, rot, _base_escala)
