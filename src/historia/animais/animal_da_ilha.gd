class_name AnimalDaIlha
extends CharacterBody3D
# ============================================================================
#  ANIMAL DA ILHA — um bicho da categoria "Animais" vivendo no Modo História
#  (01/10/2026). Quem cria, faz renascer e decide o nível de detalhe é a
#  `PopulacaoDeAnimais`; o jeito de cada espécie vem da `FichaDeAnimal` do catálogo.
#
#  Comportamentos (tabela aprovada pelo dono):
#    presa        passeia; o jogador chega perto (alerta) -> FOGE; apanhou -> foge.
#    domestico    passeia devagar e fica parado/pastando; ignora o jogador; apanhou ->
#                 corre uns segundos.
#    territorial  passeia; o jogador entra no espaço dele (alerta) ou o ataca ->
#                 PERSEGUE e ataca, até o jogador se afastar ou o fôlego acabar.
#    predador     igual, mas com alerta maior (caça).
#    chefe        predador PRESO à área dele (nunca sai; volta se o jogador sair).
#  Voadores (corpo "voador") planam a `altura_voo` acima do chão; predador voador
#  mergulha para atacar.
#
#  Passeio SOLTO de propósito (pedido do dono: o cão pode sair da vila e se perder na
#  floresta): o destino sorteado é em volta de onde o animal ESTÁ, com um puxão de
#  volta só quando passa de LONGE_DE_CASA da área.
# ============================================================================

signal morreu(animal: AnimalDaIlha)

enum Estado { PARADO, PASSEANDO, FUGINDO, PERSEGUINDO, VOLTANDO, MORTO }

const GRAVIDADE := 32.0
const GIRO := 5.0                 # rad/s
const LONGE_DE_CASA := 70.0
const MARGEM_DA_ILHA := 236.0     # não passeia além disto do centro (a praia acaba)
const PERSEGUE_NO_MAXIMO := 12.0  # s de fôlego do territorial antes de desistir

var especie := ""
## Dano dos animais hostis ao jogador ×2 (10/11/2026, pedido do dono: "aumenta o dano dos mobs"). Búfalo 4 → 8, urso 5 → 10, gorila 7 → 14
## (antes da metade da campanha e da armadura do jogador).
const ESCALA_DE_DANO := 2.0   # 10/11/2026: 2,0 restaurado às 20:17 (ver `JogadorDoMod.ESCALA_DO_GOLPE_DE_MOB`)
var ficha: Dictionary = {}
## Área de origem: {centro: Vector3, meio: Vector3 (meio-tamanho), base: Basis}.
var area: Dictionary = {}
var alvo: Node3D = null           # o jogador
## Com quem está brigando agora: o jogador ou um PET que o atacou (revide, 01/10/2026).
var oponente: Node3D = null
## Quem criou (sabe onde é chão seco). null = solto, sem checagem (testes).
var populacao: PopulacaoDeAnimais = null
## Onde nasceu da primeira vez (o chefe sempre renasce aqui, no covil).
var ponto_de_origem := Vector3.ZERO
var estado: int = Estado.PARADO
var health := 1.0
var max_health := 1.0
var animador := AnimadorDeAnimal.new()
## 0 = perto (anima), 1 = médio (anda sem animar), 2 = longe (escondido e parado).
var nivel_de_detalhe := 0

var _visual: Node3D
var _modelo: Node3D
var _altura := 1.0
var _comprimento := 1.0
var _raio := 0.3
## HITBOX DE INTERAÇÃO (01/10/2026, decisão do dono): o que o golpe acerta é uma caixa do
## corpo VISÍVEL +30 % no comprimento e na largura, com altura mínima até o peito do
## jogador — a cápsula de andar é um cilindro fino no centro (a vaca tem 2,3 m de corpo e
## raio 0,31) e o coelho de 35 cm ficava abaixo do punho: nenhum soco pegava. Camada 21
## (`HurtboxDeCombate`): só a varredura do combate a enxerga e a troca pelo dono.
var _hurtbox: StaticBody3D = null
## Nadando agora (água funda). Público para a animação e os testes.
var nadando := false
const NADA_ACIMA_DE := 0.65
const LINHA_DAGUA_NADANDO := 0.6
const FATOR_NADANDO := 0.5
var _nivel_da_agua := NAN
var _passos := 1
var _quadro_lod := 0
const PASSOS_MEIA_DISTANCIA := 3
var _agua_relogio := 0.0
const HITBOX_MAIOR := 1.3
const HITBOX_ALTURA_MINIMA := 1.6
const HITBOX_LADO_MINIMO := 0.7
var _destino := Vector3.ZERO
var _relogio := 0.0
var _recarga := 0.0
## Golpe em andamento: o dano cai no quadro do impacto do clipe (`golpe_em` da ficha,
## gravado pelo rig — tools/blender/rig_animais.py), não quando o bicho começa a armar.
var _golpe_alvo: Node3D = null
var _golpe_falta := 0.0
var _ancora := Vector3.ZERO
var _perseguindo_ha := 0.0
var _sem_progresso := 0.0
var _tempo := 0.0
## Apanhou há pouco: fica bravo/assustado mesmo com fruta na mão do jogador.
var _irritado_ate := -INF
const IRRITADO_POR := 20.0
const ALCANCE_DO_REVIDE := 2.5   # m entre o ponto do golpe e quem bateu
var _melhor_distancia := INF
## Desvio de obstáculo (01/10/2026): preso, anda ±70° de lado por um instante, alternando
## o lado; depois de 3 desvios sem sair do lugar, desiste (`_ao_empacar`).
var _ultima_pos := Vector3.ZERO
var _desvio_ate := -INF
var _lado_do_desvio := 1.0
var _desvios := 0
## Último ponto onde andava LIVRE (amostrado a cada segundo andando sem travar): quem
## entra numa colisão côncava (galhos dos aglomerados de árvore) não tem saída por
## desvio nenhum — volta para cá (o urso do teste, 01/10/2026).
var _ponto_livre := Vector3.INF
var _livre_relogio := 0.0
var _empacadas := 0
const DESVIO := 1.2               # rad
const DURACAO_DO_DESVIO := 0.8    # s
var _yaw := 0.0
var _curva := 0.0
var _chao_cache := 0.0
var _chao_relogio := 0.0
var _empurrao := Vector3.ZERO
## O caranguejo anda DE LADO: o modelo dele vira 90° em relação ao caminho.
var _desvio_yaw := 0.0


## Monta o bicho a partir da loja. `escala` = tamanho padrão / tamanho do arquivo.
func montar(bib: BibliotecaDeModelos, id: String, a_ficha: Dictionary, a_area: Dictionary) -> void:
	especie = id
	ficha = a_ficha
	area = a_area
	name = "Animal_%s" % id
	max_health = float(ficha.get("vida", 30))
	health = max_health
	add_to_group("animais")
	add_to_group(AlvosDeGolpe.GRUPO)     # as frutas acertam todo animal (05/10/2026)
	if boss():
		add_to_group(BarrasDeChefes.GRUPO)   # vida no topo da tela (08/10/2026)
	if FichaDeAnimal.hostil(ficha):
		add_to_group("enemy")
	collision_layer = 1
	collision_mask = 1
	if FichaDeAnimal.voa(ficha):
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Bicho não precisa de 6 deslizes por quadro; limita o pior caso de colisão.
	max_slides = 3
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_modelo = bib.instanciar(id)
	if _modelo == null:
		_modelo = Node3D.new()
	_modelo.name = "Modelo"
	_visual.add_child(_modelo)
	var e: Dictionary = bib.info(id)
	var t: Vector3 = e["tamanho"]
	var padrao := bib.tamanho_padrao(id)
	var k := padrao.y / maxf(t.y, 0.0001)
	_modelo.scale = Vector3.ONE * k
	# O pé no chão: base da caixa do arquivo (que é a da malha) na origem do corpo.
	var c: Vector3 = e["centro"]
	_modelo.position = Vector3(-c.x * k, -(c.y - t.y * 0.5) * k, -c.z * k)
	var medidas := _medidas_reais(k, padrao)
	_altura = medidas.y
	_comprimento = maxf(medidas.x, medidas.z)
	var largura := minf(medidas.x, medidas.z)
	_raio = clampf(largura * 0.5, 0.06, 1.4)
	var forma := CapsuleShape3D.new()
	forma.radius = _raio
	forma.height = maxf(_altura, _raio * 2.0 + 0.01)
	var cs := CollisionShape3D.new()
	cs.name = "Colisao"
	cs.shape = forma
	cs.position.y = forma.height * 0.5
	add_child(cs)
	_instalar_hurtbox(medidas)
	animador.montar(_modelo, str(ficha.get("corpo", "quadrupede")), _altura, _comprimento)
	_desvio_yaw = PI * 0.5 if ficha.get("corpo", "") == "caranguejo" else 0.0
	_yaw = randf() * TAU
	_visual.rotation.y = _yaw + _desvio_yaw
	_novo_relogio(0.5, 4.0)


## A caixa gira com o bicho: filha do `Visual` (o corpo físico não gira).
func _instalar_hurtbox(m: Vector3) -> void:
	_hurtbox = StaticBody3D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = HurtboxDeCombate.CAMADA
	_hurtbox.collision_mask = 0
	_hurtbox.set_meta("hurtbox_de", self)
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(maxf(m.x * HITBOX_MAIOR, HITBOX_LADO_MINIMO), maxf(m.y * 1.1, HITBOX_ALTURA_MINIMA),
		maxf(m.z * HITBOX_MAIOR, HITBOX_LADO_MINIMO))
	var cs := CollisionShape3D.new()
	cs.name = "Forma"
	cs.shape = caixa
	cs.position.y = caixa.size.y * 0.5
	_hurtbox.add_child(cs)
	_visual.add_child(_hurtbox)


## Tamanho da hitbox (para quem mede alcance: a doma, os testes). ZERO se não tem.
func tamanho_da_hitbox() -> Vector3:
	if _hurtbox == null:
		return Vector3.ZERO
	return ((_hurtbox.get_node("Forma") as CollisionShape3D).shape as BoxShape3D).size


## Meia-largura da hitbox no chão: "encostar" no bicho é chegar a isto do centro.
func raio_de_interacao() -> float:
	var t := tamanho_da_hitbox()
	return maxf(maxf(t.x, t.z) * 0.5, _raio)


func ligar_hurtbox(ligada: bool) -> void:
	if _hurtbox != null:
		_hurtbox.collision_layer = HurtboxDeCombate.CAMADA if ligada else 0


## Medidas do corpo na pose de montagem: ossos (rigado) ou caixa (estático).
func _medidas_reais(k: float, padrao: Vector3) -> Vector3:
	var sks := _modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return padrao
	var sk := sks[0] as Skeleton3D
	# Rig nosso (tools/blender/rig_animais.py, osso "raiz"): a caixa do catálogo é a malha
	# em repouso, exata; os ossos param antes do focinho e da anca (vaca 2,24 m < 2,58 m).
	if sk.find_bone("raiz") >= 0:
		return padrao
	# Ossos no espaço do ARQUIVO (como a caixa do catálogo); a escala `k` vem depois.
	var ate_o_modelo := BibliotecaDeModelos._transformacao_ate(sk, _modelo)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for b in sk.get_bone_count():
		var p := ate_o_modelo * sk.get_bone_global_pose(b).origin
		lo = lo.min(p)
		hi = hi.max(p)
	# Ossos param no meio da cabeça e no tornozelo: +12 % (a mesma régua das fichas).
	var tam := (hi - lo) * 1.12 * k
	return Vector3(maxf(tam.x, 0.2), maxf(tam.y, 0.1), maxf(tam.z, 0.2))


func nome_de_exibicao() -> String:
	var nome := str(ficha.get("nome", ""))
	return nome if not nome.is_empty() else especie.capitalize()


func _joelho() -> float:
	return clampf(_altura * 0.4, 0.1, 1.2)


func vivo() -> bool:
	return estado != Estado.MORTO and not bool(get_meta("aguardando_recrutamento", false))


func altura() -> float:
	return _altura


## O MEIO do corpo (a origem do bicho é o pé). Quem mira ou traça linha até um alvo
## pergunta isto (`AlvosDeGolpe.centro`) — mirar no pé batia no chão antes (05/10/2026).
func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * _altura * 0.5


## Mesma assinatura do resto do jogo (golpes e `CombatResolver` chamam direto).
# ------------------------------------------------------------ ESQUIVA COM DASH (22/11/2026)
# Mesma regra do `PersonagemMinePiece`: animal HOSTIL atacado pela Buki Buki dá um dash lateral para sair da linha do tiro; recarga de 3 s.
# O dash é um impulso no `_empurrao` (decai 10 m/s²): v = 8,5 m/s -> ~3,6 m.
func esquiva_pronta() -> bool:
	return estado != Estado.MORTO and FichaDeAnimal.hostil(ficha) and EsquivaDeDisparo.pronta(self) and is_on_floor()

func esquivar_de_disparo(rumo: Vector3, _chegada_em := 0.0) -> bool:
	if not esquiva_pronta():
		return false
	var lateral := EsquivaDeDisparo.tentar(self, rumo)
	if lateral == Vector3.ZERO:
		return false
	_empurrao += lateral * EsquivaDeDisparo.IMPULSO
	return true


func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
	if amount <= 0.0 or not vivo():
		return
	if preload("res://src/historia/tripulantes/socorro.gd").proteger(self, amount): return
	IaUnificada.acordar_por_dano(self)      # IA dos animais: levar dano acorda (10/11/2026)
	if is_in_group(BarrasDeChefes.GRUPO):
		amount = VidaEmBarras.filtrar(self, amount, health, max_health)   # chefe: 10 barras (10/11/2026)
	health = maxf(health - amount, 0.0)
	FxUtil.flash_red(_modelo)
	_irritado_ate = _tempo + IRRITADO_POR
	# Bicho pequeno voa longe com o mesmo golpe; o grande quase não se mexe.
	_empurrao += knockback / clampf(_altura, 0.3, 3.0) * 0.6
	if Vector2(knockback.x, knockback.z).length() < 0.1:
		_empurrao += KnockbackMinecraft.padrao(self, from_pos) / clampf(_altura, 0.3, 3.0) * 0.6      # golpe cru: Minecraft
	if health <= 0.0:
		_morrer()
		return
	animador.tomar_dano()
	reagir_ao_golpe(from_pos)


## Quem bateu: o jogador ou um pet perto do ponto de onde veio o golpe.
func reagir_ao_golpe(from_pos: Vector3) -> void:
	match str(ficha.get("comportamento", "")):
		"presa", "domestico":
			_fugir_de(from_pos if from_pos != Vector3.ZERO else _pos_alvo())
		_:
			_perseguir(_quem_bateu(from_pos))


func _quem_bateu(from_pos: Vector3) -> Node3D:
	if from_pos == Vector3.ZERO:
		return alvo
	var melhor: Node3D = alvo if _alvo_valido() and alvo.global_position.distance_to(from_pos) <= ALCANCE_DO_REVIDE else null
	var melhor_d := alvo.global_position.distance_to(from_pos) if melhor != null else ALCANCE_DO_REVIDE
	for n in get_tree().get_nodes_in_group("pets_historia"):
		var pet := n as Node3D
		if pet == null or pet == self or not pet.is_inside_tree():
			continue
		var d := pet.global_position.distance_to(from_pos)
		if d <= melhor_d:
			melhor_d = d
			melhor = pet
	return melhor if melhor != null else alvo


## Herbívoro domável diante de fruta na mão do jogador: curioso, não foge nem ataca
## (sem isso não se chega a 3 m de um coelho). Quem apanhou há pouco não se acalma.
func calmo_com_fruta() -> bool:
	return FichaDeAnimal.domavel(ficha) and _alvo_valido() and _tempo > _irritado_ate \
		and not str(alvo.get_meta("fruta_na_mao", "")).is_empty()


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"AnimalDaIlha.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if (has_meta("captura_vento") and is_instance_valid(get_meta("captura_vento"))) or (has_meta("arremesso_vento") and is_instance_valid(get_meta("arremesso_vento"))):
		return
	# Lentidão de skill do Builder (Noro Noro, 06/10/2026): cérebro, golpe e animação no
	# tempo do bicho; a velocidade de andar cai em `_mover`.
	delta *= Lentidao.fator(self)
	# MEIA DISTÂNCIA (35–80 m, já sem animação): anda 1 quadro em 3, com passo triplo —
	# gatilho declarado no checkpoint (custo > 2 ms/quadro, medido 01/10/2026). A fase
	# vem do id, para os bichos não pesarem todos no mesmo quadro.
	_passos = 1
	if nivel_de_detalhe == 1 and estado != Estado.MORTO:
		_quadro_lod = (_quadro_lod + 1) % PASSOS_MEIA_DISTANCIA
		if _quadro_lod != get_instance_id() % PASSOS_MEIA_DISTANCIA:
			return
		_passos = PASSOS_MEIA_DISTANCIA
		delta *= PASSOS_MEIA_DISTANCIA
	if estado == Estado.MORTO:
		# Cai até o chão (o voador também) e fica lá até a população esconder.
		velocity = Vector3(0.0, maxf(velocity.y - GRAVIDADE * delta, -25.0), 0.0) + _empurrao
		_empurrao = _empurrao.move_toward(Vector3.ZERO, delta * 10.0)
		move_and_slide()
		animador.animar(delta, Vector3.ZERO, 1.0, 1.0, "morto", 0.0)
		return
	_tempo += delta
	_recarga = maxf(0.0, _recarga - delta)
	_relogio -= delta
	if _golpe_alvo != null:
		_golpe_falta -= delta
		if _golpe_falta <= 0.0:
			_acertar(_golpe_alvo, true)
	_pensar(delta)
	var vel := _mover(delta)
	# Filho estático de um corpo que se move fica UM quadro atrás no servidor de física
	# (`HurtboxDeCombate.sincronizar`): leva a caixa para onde o bicho está agora.
	if _hurtbox != null:
		PhysicsServer3D.body_set_state(_hurtbox.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, _hurtbox.global_transform)
	var local := _visual.global_transform.basis.inverse() * vel
	var est := "parado"
	if FichaDeAnimal.voa(ficha):
		est = "voando" if vel.length() > 0.5 else "planando"
	elif Vector2(vel.x, vel.z).length() > float(ficha.get("passeio", 1.0)) * 1.6:
		est = "correndo"
	elif Vector2(vel.x, vel.z).length() > 0.15:
		est = "andando"
	animador.animar(delta, local, float(ficha.get("passeio", 1.0)), float(ficha.get("corrida", 4.0)), est, _curva)


# ------------------------------------------------------------------ cérebro
func _pensar(delta: float) -> void:
	var comp := str(ficha.get("comportamento", ""))
	var alerta := float(ficha.get("alerta", 0.0))
	var d := _dist_alvo()
	match estado:
		Estado.PARADO:
			if _relogio <= 0.0:
				_passear()
		Estado.PASSEANDO:
			if _plano(_destino - global_position).length() < maxf(0.8, _raio * 2.0) or _relogio <= 0.0:
				estado = Estado.PARADO
				if comp == "domestico":
					_novo_relogio(4.0, 12.0)
				else:
					_novo_relogio(1.5, 6.0)
		Estado.FUGINDO:
			if _relogio <= 0.0 or (d > alerta * 2.2 and _relogio < 6.0):
				_passear()
		Estado.PERSEGUINDO:
			_perseguindo_ha += delta
			var quem := oponente if _vivo_no(oponente) else null
			var d_op := _plano(quem.global_position - global_position).length() if quem else INF
			var largou := d_op > maxf(alerta * 2.2, 14.0) or global_position.distance_to(_ancora) > maxf(alerta * 2.5, 20.0)
			if comp == "territorial" and _perseguindo_ha > PERSEGUE_NO_MAXIMO:
				largou = true
			if boss() and quem != null and not _dentro_da_area(quem.global_position, 4.0):
				largou = true
			if quem == alvo and calmo_com_fruta():
				largou = true          # a fruta na mão acalma quem só estava defendendo o espaço
			if largou or quem == null:
				estado = Estado.VOLTANDO
				oponente = null
				_destino = _ancora
				_novo_relogio(8.0, 12.0)
			else:
				_destino = quem.global_position
				_tentar_atacar(quem, d_op)
		Estado.VOLTANDO:
			if _plano(_destino - global_position).length() < 1.5 or _relogio <= 0.0:
				_passear()
	# Reações que valem em qualquer estado calmo.
	if estado in [Estado.PARADO, Estado.PASSEANDO] and _alvo_vivo() and not calmo_com_fruta():
		if comp == "presa" and d < alerta:
			_fugir_de(alvo.global_position)
		elif comp in ["territorial", "predador"] and d < alerta:
			if not boss() or _dentro_da_area(alvo.global_position, 0.0):
				_perseguir()


func boss() -> bool:
	return bool(ficha.get("boss", false))


## Lutando com o jogador (barra de vida dos chefes, 08/10/2026). `alvo` NÃO serve: todo
## animal guarda o jogador nele, perto ou longe.
func em_combate() -> bool:
	return estado == Estado.PERSEGUINDO


func _passear() -> void:
	estado = Estado.PASSEANDO
	var voa := FichaDeAnimal.voa(ficha)
	var destino := global_position
	# Até 4 sorteios: destino em telhado, pedra ou no rio não serve (voador não liga).
	for _t in 4:
		destino = _sortear_passeio(voa)
		if voa or populacao == null or populacao.destino_valido(destino, global_position, _joelho(), get_rid()):
			break
	_destino = destino
	_melhor_distancia = INF
	_novo_relogio(8.0, 16.0)


func _sortear_passeio(voa: bool) -> Vector3:
	if boss():
		return _ponto_na_area(0.8)
	var r := randf_range(15.0, 40.0) if voa else randf_range(6.0, 18.0)
	var ang := randf() * TAU
	var destino := global_position + Vector3(cos(ang), 0, sin(ang)) * r
	var centro: Vector3 = area.get("centro", global_position)
	# Solto, mas não perdido para sempre: longe demais de casa, puxa de volta.
	if _plano(destino - centro).length() > LONGE_DE_CASA:
		destino = global_position.lerp(centro, 0.5) + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	destino.x = clampf(destino.x, -MARGEM_DA_ILHA, MARGEM_DA_ILHA)
	destino.z = clampf(destino.z, -MARGEM_DA_ILHA, MARGEM_DA_ILHA)
	return destino


## Preso depois dos desvios. Selvagem: perseguindo, desiste e volta; senão, outro passeio.
## Preso de novo sem ter andado livre no meio: volta ao último ponto livre.
func _ao_empacar() -> void:
	_empacadas += 1
	if _empacadas >= 2 and _ponto_livre != Vector3.INF:
		_empacadas = 0
		global_position = _ponto_livre
		velocity = Vector3.ZERO
	if estado == Estado.PERSEGUINDO:
		estado = Estado.VOLTANDO
		oponente = null
		_destino = _ancora
		_novo_relogio(8.0, 12.0)
	else:
		_passear()


func _fugir_de(origem: Vector3) -> void:
	estado = Estado.FUGINDO
	var fora := _plano(global_position - origem)
	if fora.length() < 0.01:
		fora = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var dist := maxf(float(ficha.get("alerta", 6.0)) * 2.0, 12.0)
	# Foge PARA LONGE; se dali é rio ou parede, tenta de lado (±50°, ±100°).
	for desvio in [0.0, 0.87, -0.87, 1.75, -1.75]:
		_destino = global_position + fora.normalized().rotated(Vector3.UP, desvio) * dist
		_destino.x = clampf(_destino.x, -MARGEM_DA_ILHA, MARGEM_DA_ILHA)
		_destino.z = clampf(_destino.z, -MARGEM_DA_ILHA, MARGEM_DA_ILHA)
		if FichaDeAnimal.voa(ficha) or populacao == null \
				or populacao.destino_valido(_destino, global_position, _joelho(), get_rid()):
			break
	_melhor_distancia = INF
	if ficha.get("comportamento", "") == "domestico":
		_novo_relogio(3.0, 5.0)
	else:
		_novo_relogio(6.0, 9.0)


func _perseguir(quem: Node3D = null) -> void:
	if estado != Estado.PERSEGUINDO:
		_ancora = global_position
		_perseguindo_ha = 0.0
	estado = Estado.PERSEGUINDO
	oponente = quem if quem != null else alvo


func _tentar_atacar(quem: Node3D, d: float) -> void:
	var alcance := float(ficha.get("alcance", 1.8)) + _raio + 0.5
	if d > alcance or _recarga > 0.0 or not _vivo_no(quem):
		return
	# Alto demais para alcançar (a gaivota no ar; o voador acima do alvo).
	var dy := absf(quem.global_position.y - global_position.y)
	if dy > (3.0 if FichaDeAnimal.voa(ficha) else _altura + 1.2):
		return
	_recarga = float(ficha.get("recarga", 1.5))
	animador.atacar()
	var em := float(ficha.get("golpe_em", 0.0))
	if em <= 0.0:
		_acertar(quem, false)
		return
	_golpe_alvo = quem
	_golpe_falta = em


## O impacto. `conferir`: o golpe foi armado antes — só acerta quem ainda está ao
## alcance (+0,6 m de folga) e vivo; sair de perto durante a preparação é esquiva.
func _acertar(quem: Node3D, conferir: bool) -> void:
	_golpe_alvo = null
	if conferir:
		var alcance := float(ficha.get("alcance", 1.8)) + _raio + 0.5 + 0.6
		if not _vivo_no(quem) or _plano(quem.global_position - global_position).length() > alcance:
			return
	var dir := _plano(quem.global_position - global_position).normalized()
	if quem.has_method("take_damage"):
		CombatResolver.aplicar(quem, float(ficha.get("dano", 1)) * ESCALA_DE_DANO * float(get_meta("fator_dano_nivel", 1.0)), 0, 0, global_position, dir * 4.0 + Vector3.UP * 2.0, 0.2, 0, false, null, self)


## Vivo e na cena (jogador, pet ou bicho).
func _vivo_no(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	var vida: Variant = n.get("health")
	return vida == null or float(vida) > 0.0


# ---------------------------------------------------------------- movimento
## Velocidade do estado atual (o pet domado sobrescreve: corre atrás do dono).
func _velocidade() -> float:
	var velocidade := float(ficha.get("passeio", 1.0))
	if estado in [Estado.FUGINDO, Estado.PERSEGUINDO]:
		velocidade = float(ficha.get("corrida", 4.0))
	elif estado == Estado.VOLTANDO:
		velocidade *= 1.4
	return velocidade


func _mover(delta: float) -> Vector3:
	var velocidade := _velocidade()
	# Água (decisão do dono, 01/10/2026): rasa deixa mais lento; funda (mais de 65 % do
	# corpo), NADA — boia com 60 % do corpo submerso, devagar.
	# Nível da água consultado a cada 0,25 s (~7 µs por consulta; o bicho anda ~1 m/s).
	_agua_relogio -= delta
	if _agua_relogio <= 0.0:
		_agua_relogio = 0.25
		_nivel_da_agua = NAN if FichaDeAnimal.voa(ficha) else AguaDoMundo.nivel_em(global_position.x, global_position.z)
	var nivel_da_agua := _nivel_da_agua
	var submerso := 0.0 if is_nan(nivel_da_agua) else clampf((nivel_da_agua - global_position.y) / maxf(_altura, 0.05), 0.0, 1.0)
	nadando = submerso > NADA_ACIMA_DE or (nadando and submerso > NADA_ACIMA_DE - 0.1)
	if nadando:
		velocidade *= FATOR_NADANDO
	elif submerso > 0.0:
		velocidade *= AguaDoMundo.fator_de_andar(submerso)
	var querer := Vector3.ZERO
	if estado != Estado.PARADO:
		var falta := _plano(_destino - global_position)
		if falta.length() > 0.3:
			var direcao := falta.normalized()
			if _tempo < _desvio_ate:
				direcao = direcao.rotated(Vector3.UP, DESVIO * _lado_do_desvio)
			querer = direcao * velocidade
	querer *= Lentidao.fator(self)
	_empurrao = _empurrao.move_toward(Vector3.ZERO, delta * 10.0)
	if FichaDeAnimal.voa(ficha):
		var alvo_y := _chao(delta) + float(ficha.get("altura_voo", 8.0))
		if estado == Estado.PERSEGUINDO and _vivo_no(oponente):
			alvo_y = oponente.global_position.y + 1.0   # mergulho
		velocity = Vector3(querer.x, clampf((alvo_y - global_position.y) * 1.8, -8.0, 6.0), querer.z) + _empurrao
	elif nadando:
		var boia := nivel_da_agua - _altura * LINHA_DAGUA_NADANDO
		velocity = Vector3(querer.x, clampf((boia - global_position.y) * 2.5, -2.5, 2.5), querer.z) + _empurrao
	else:
		var vy := velocity.y
		velocity = Vector3(querer.x, 0, querer.z) + _empurrao
		velocity.y = vy - GRAVIDADE * delta if not is_on_floor() else -0.5
	# Parado e apoiado (ou pairando no lugar): nada a mover. O move_and_slide é quase
	# todo o custo do bicho (medido 01/10 na tomada: ~100 µs cada) e a maioria passa o tempo parada.
	var quieto := querer == Vector3.ZERO and _empurrao.length_squared() < 0.0001
	if quieto and (is_on_floor() if not FichaDeAnimal.voa(ficha) else absf(velocity.y) < 0.05):
		velocity = Vector3.ZERO
	else:
		EscaladaDeMob.ajudar(self, delta * _passos)       # sobe o relevo (degrau ou bloco inteiro); antes do passo múltiplo
		# Passo triplo da meia distância: a física anda `velocity × delta do quadro`.
		velocity *= _passos
		move_and_slide()
		velocity /= _passos
	# Empacou. Destino fixo: mede o PROGRESSO até ele, não o deslocamento — raspando numa
	# parede o bicho desliza um pouco a cada quadro e "anda" sem chegar (a ovelha na
	# plantação, 01/10/2026). Perseguindo (o alvo se move): mede se ANDA — o urso
	# encalhava parado na colisão côncava dos aglomerados de pinheiro (01/10/2026).
	# Preso: desvia de lado; 3 desvios sem resolver, `_ao_empacar`.
	if estado in [Estado.PASSEANDO, Estado.FUGINDO, Estado.VOLTANDO, Estado.PERSEGUINDO] and querer.length() > 0.1:
		var progrediu: bool
		if estado == Estado.PERSEGUINDO:
			progrediu = _plano(global_position - _ultima_pos).length() > velocidade * delta * 0.3
		else:
			var falta := _plano(_destino - global_position).length()
			progrediu = falta < _melhor_distancia - 0.5
			if progrediu:
				_melhor_distancia = falta
		if progrediu:
			_sem_progresso = 0.0
			if _tempo >= _desvio_ate:
				_desvios = 0
				_livre_relogio += delta
				if _livre_relogio >= 1.0:
					_livre_relogio = 0.0
					_ponto_livre = global_position
					_empacadas = 0
		else:
			_sem_progresso += delta
			if _sem_progresso > (0.6 if estado == Estado.PERSEGUINDO else 1.0):
				_sem_progresso = 0.0
				_desvios += 1
				if _desvios <= 3:
					_desvio_ate = _tempo + DURACAO_DO_DESVIO
					_lado_do_desvio = -_lado_do_desvio
					_melhor_distancia = INF
				else:
					_desvios = 0
					_ao_empacar()
	_ultima_pos = global_position
	# Vira para onde anda (modelos olham +Z).
	var plano := Vector2(velocity.x, velocity.z)
	var yaw_antes := _yaw
	if plano.length() > 0.2:
		var desejado := atan2(plano.x, plano.y)
		_yaw = lerp_angle(_yaw, desejado, clampf(GIRO * delta, 0.0, 1.0))
	elif estado == Estado.PERSEGUINDO and _vivo_no(oponente):
		var para := _plano(oponente.global_position - global_position)
		_yaw = lerp_angle(_yaw, atan2(para.x, para.z), clampf(GIRO * delta, 0.0, 1.0))
	_curva = wrapf(_yaw - yaw_antes, -PI, PI) / maxf(delta, 0.001)
	_visual.rotation.y = _yaw + _desvio_yaw
	return velocity


## Altura do chão sob o voador (raio a cada 0,4 s; terreno e peças).
func _chao(delta: float) -> float:
	_chao_relogio -= delta
	if _chao_relogio <= 0.0:
		_chao_relogio = 0.4
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 60.0,
			global_position + Vector3.DOWN * 200.0, 1, [get_rid()])
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		_chao_cache = h["position"].y if not h.is_empty() else 0.0
	return _chao_cache


# ------------------------------------------------------------------- morte
func _morrer() -> void:
	estado = Estado.MORTO
	_golpe_alvo = null
	collision_layer = 0
	ligar_hurtbox(false)
	velocity = Vector3.ZERO
	remove_from_group("enemy")
	remove_from_group(AlvosDeGolpe.GRUPO)
	animador.morrer()
	morreu.emit(self)


## Volta à vida em `posicao` (a população sorteia o ponto).
func reviver(posicao: Vector3) -> void:
	global_position = posicao
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	health = max_health
	collision_layer = 1
	ligar_hurtbox(true)
	collision_mask = 1
	if FichaDeAnimal.hostil(ficha):
		add_to_group("enemy")
	add_to_group(AlvosDeGolpe.GRUPO)
	visible = nivel_de_detalhe < 2
	animador.reviver()
	estado = Estado.PARADO
	_novo_relogio(0.5, 3.0)


# ------------------------------------------------------------------- apoio
func _dist_alvo() -> float:
	return _plano(alvo.global_position - global_position).length() if _alvo_valido() else INF


func _alvo_valido() -> bool:
	return alvo != null and is_instance_valid(alvo) and alvo.is_inside_tree()


func _pos_alvo() -> Vector3:
	return alvo.global_position if _alvo_valido() else global_position


func _alvo_vivo() -> bool:
	if not _alvo_valido():
		return false
	var vida: Variant = alvo.get("health")
	return vida == null or float(vida) > 0.0


func _dentro_da_area(p: Vector3, folga: float) -> bool:
	if area.is_empty():
		return true
	var local: Vector3 = (area["base"] as Basis).inverse() * (p - (area["centro"] as Vector3))
	var meio: Vector3 = area["meio"]
	return absf(local.x) <= meio.x + folga and absf(local.z) <= meio.z + folga


func _ponto_na_area(fracao: float) -> Vector3:
	var meio: Vector3 = area.get("meio", Vector3.ONE * 5.0)
	var local := Vector3(randf_range(-meio.x, meio.x) * fracao, 0, randf_range(-meio.z, meio.z) * fracao)
	return (area.get("centro", global_position) as Vector3) + (area.get("base", Basis.IDENTITY) as Basis) * local


func _novo_relogio(minimo: float, maximo: float) -> void:
	_relogio = randf_range(minimo, maximo)


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
