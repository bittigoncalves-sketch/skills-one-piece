class_name InimigoDoMapa
extends StaticBody3D
# ============================================================================
#  INIMIGO DO MAPA — peça `modelo` do Modo História cujo modelo está na categoria
#  "inimigos" da loja. Decisão do dono (16/09/2026): a CATEGORIA é o marcador;
#  não existe um tipo de peça "inimigo" no arquivo de mapa.
#
#  Faz: tem vida, pisca vermelho ao tomar dano, some ao chegar a zero e emite
#  `derrotado` (quem dá o XP é o `ModoHistoria`: 5 a 20, aleatório).
#  RENASCE (decisão do dono, 30/09/2026): 1 minuto depois, no MESMO lugar do editor,
#  com a vida cheia. Vale para todos os inimigos que não sejam chefe — e chefe ainda
#  não existe no Modo História. GATILHO: o primeiro chefe → marcar no catálogo (campo
#  `comportamento`) e não renascer.
#  Recebe empurrão com colisão. Não anda por conta própria nem reage com hitstun.
#
#  Peça com COMPORTAMENTO no catálogo não é daqui: o boneco de duelo que luta é do
#  `NinhoDeInimigo`.
#
#  POR QUE `set_script` NUM CORPO JÁ MONTADO, e não uma classe no `MapaMontador`:
#  o montador é o mesmo do editor de mapa, e lá uma peça não pode sumir ao
#  "morrer" — o editor perderia o nó que representa a peça no documento. Só o
#  jogo transforma a peça em inimigo (`ligar_no_mapa`).
#
#  ⚠️ O golpe só ENCONTRA o inimigo pela colisão: a `DamageZone` dispara em
#  `body_entered`. Peça com "Colisão" desligada no editor não toma dano — avisado
#  no log ao ligar.
# ============================================================================

signal derrotado(inimigo: InimigoDoMapa)

## Id da categoria no catálogo da loja (o id não muda quando a categoria é renomeada).
const CATEGORIA := "inimigos"
## O mesmo grupo da arena: mira assistida e técnicas de área já procuram por ele.
const GRUPO := "enemy"
## Igual para todos por enquanto: um combo M1 completo (278) derruba.
## Gatilho: o primeiro inimigo que precise de dificuldade própria → campo `vida`
## no catálogo (por modelo) ou na peça (por posição no mapa).
const VIDA_PADRAO := 250.0
## Quanto um inimigo morto demora a voltar (pedido do dono: 1 minuto). Também o do
## `NinhoDeInimigo`. `static var` e não constante só para o teste encurtar a espera.
static var tempo_de_renascer := 60.0

var max_health: float = VIDA_PADRAO
var health: float = VIDA_PADRAO
var _camada := 0
var _relogio: Timer = null
var _empurrao := Vector3.ZERO
var _origem := Vector3.INF


## Transforma em inimigo cada peça do mapa montado cujo modelo tem a categoria.
## Devolve os inimigos ligados, para quem monta a cena conectar `derrotado`.
static func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos) -> Array[InimigoDoMapa]:
	var ligados: Array[InimigoDoMapa] = []
	if raiz == null or biblioteca == null:
		return ligados
	for p: Dictionary in mapa["pecas"]:
		if not eh_inimigo(p, biblioteca) or not biblioteca.comportamento_do_modelo(p["modelo"]).is_empty():
			continue
		var corpo := raiz.get_node_or_null(NodePath(String(p["id"]))) as StaticBody3D
		if corpo == null:
			continue
		corpo.set_script(InimigoDoMapa)
		var inimigo := corpo as InimigoDoMapa
		inimigo.set_meta("modelo_recrutavel", String(p["modelo"]))
		inimigo.add_to_group(GRUPO)
		inimigo.add_to_group(AlvosDeGolpe.GRUPO)
		inimigo.criar_nucleo_solido()
		# Skills do Builder atribuídas a este modelo (Usuário Inimigo, 06/10/2026).
		UsuarioDeSkills.ligar(inimigo, String(p["modelo"]))
		if not p["colisao"]:
			push_warning("[Modo História] inimigo \"%s\" está sem colisão: golpes não o encontram" % p["id"])
		ligados.append(inimigo)
	return ligados


static func eh_inimigo(p: Dictionary, biblioteca: BibliotecaDeModelos) -> bool:
	return p["tipo"] == "modelo" and biblioteca.tem(p["modelo"]) \
		and biblioteca.categorias_do_modelo(p["modelo"]).has(CATEGORIA)


## Mesma assinatura do resto do jogo (`CombatResolver.aplicar` e golpes chamam
## direto). O impulso desloca a peça respeitando colisões; hitstun não muda sua IA.
func take_damage(amount: float, _from_pos: Vector3 = Vector3.ZERO, _knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
	IaUnificada.acordar_por_dano(self)      # IA unificada: levar dano acorda (10/11/2026)
	if health > 0.0 and _knockback.length_squared() > 0.0:
		if _origem == Vector3.INF:
			_origem = global_position
		_empurrao += Vector3(_knockback.x, 0.0, _knockback.z)
	if health > 0.0 and amount > 0.0 and Vector2(_knockback.x, _knockback.z).length() < 0.1:
		var kb := KnockbackMinecraft.padrao(self, _from_pos)      # golpe cru: o empurrão do Minecraft
		if kb != Vector3.ZERO:
			if _origem == Vector3.INF:
				_origem = global_position
			_empurrao += kb
	# Golpe com dano 0 pode empurrar, mas não pisca.
	if amount <= 0.0 or health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	FxUtil.flash_red(get_node_or_null("Modelo") as Node3D)
	if health <= 0.0:
		_morrer()


func _physics_process(delta: float) -> void:
	if health <= 0.0 or _empurrao.length_squared() < 0.0001:
		return
	var colisao := move_and_collide(_empurrao * delta)
	_empurrao = Vector3.ZERO if colisao != null else _empurrao.move_toward(Vector3.ZERO, 24.0 * delta)


## NÚCLEO SÓLIDO (05/10/2026): a colisão do modelo é uma malha de triângulos OCA. Uma
## zona de golpe (Area3D) que ENVOLVE o modelo inteiro, ou nasce dentro dele, não cruza
## triângulo nenhum e não detecta o corpo — os golpes de área das frutas da arena
## passavam pelo inimigo sem dano (medido: `test_frutas_acertam_npcs`). Uma caixa
## sólida um pouco MENOR que o modelo, dentro da malha, é vista pelas zonas e não muda
## o contorno que o jogador toca.
const ESCALA_DO_NUCLEO := 0.8

func criar_nucleo_solido() -> void:
	if get_node_or_null("NucleoSolido") != null:
		return
	var caixa := AABB()
	var achou := false
	for cs in find_children("*", "CollisionShape3D", false, false):
		var forma := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
		if forma == null:
			continue
		for v in forma.get_faces():
			var local: Vector3 = (cs as CollisionShape3D).transform * v
			if not achou:
				caixa = AABB(local, Vector3.ZERO)
				achou = true
			else:
				caixa = caixa.expand(local)
	if not achou or caixa.size.length() < 0.01:
		return
	var nucleo := CollisionShape3D.new()
	nucleo.name = "NucleoSolido"
	var box := BoxShape3D.new()
	box.size = caixa.size * ESCALA_DO_NUCLEO
	nucleo.shape = box
	nucleo.position = caixa.get_center()
	add_child(nucleo)


## Segundos até renascer (0 com o inimigo vivo).
func falta_para_renascer() -> float:
	return _relogio.time_left if _relogio != null and not _relogio.is_stopped() else 0.0


func vivo() -> bool:
	return health > 0.0


func _morrer() -> void:
	_empurrao = Vector3.ZERO
	# Sai da física JÁ: outra hitbox do mesmo golpe, no mesmo quadro, não acha mais
	# o corpo. O NÓ FICA (adormecido): é ele que renasce no mesmo lugar — o id da peça
	# e a posição do editor continuam nele.
	_camada = collision_layer
	collision_layer = 0
	visible = false
	remove_from_group(GRUPO)
	remove_from_group(AlvosDeGolpe.GRUPO)
	derrotado.emit(self)
	if _relogio == null:
		_relogio = Timer.new()
		_relogio.name = "Renascer"
		_relogio.one_shot = true
		_relogio.timeout.connect(_renascer)
		add_child(_relogio)
	_relogio.start(tempo_de_renascer)


func _renascer() -> void:
	if _origem != Vector3.INF:
		global_position = _origem
	health = max_health
	collision_layer = _camada
	visible = true
	add_to_group(GRUPO)
	add_to_group(AlvosDeGolpe.GRUPO)
