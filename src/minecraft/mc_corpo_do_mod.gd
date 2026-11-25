class_name McCorpoDoMod
extends Node3D
# ============================================================================
#  CORPO VIRTUAL de uma entidade do Mine Piece que o jogo não tem como corpo próprio — a
#  entidade de ataque (`entity_strike`), projéteis, ondas, tornados (os 47 "efeito/projétil") e
#  qualquer `EntityType.X.create/spawn` do mod (23/10/2026, E1). Tem posição e movimento (blocos/
#  tick, sem colisão), vida pela ficha do mod, dono (`setOwner`) e a PRÓPRIA IA do mod (IaDoMod),
#  que é quem faz o golpe varrer partículas, tocar som, procurar alvo e sumir.
#  Sem desenho ainda: o visual (modelo GeckoLib, partículas) é a próxima fatia — contado em
#  `Mc.pedidos_sem_implementacao` como "visual:entidade:<id>".
# ============================================================================

const GRUPO := "mc_corpos_do_mod"

var id_personagem := ""
var ficha: Dictionary = {}
var health := 1.0
var max_health := 1.0
var velocity := Vector3.ZERO
var ia_do_mod: IaDoMod
## Projétil do Minecraft (`AbstractArrow`, 8 entidades do mod): anda por TICK com gravidade 0,05
## bloco/tick² e arrasto 0,99, procura acerto no segmento do tick e chama os ganchos da classe.
var projetil := false
var _ganchos := {}
var _desenho: Node3D
var _textura_vista := "?"
var _acumulado := 0.0
var _perfurados: Dictionary = {}       # alvos já atravessados (perfuração: `AbstractArrow.piercedEntities`)
const GRAVIDADE_FLECHA := 0.05
const ARRASTO := 0.99


static func criar(id: String, mundo: McMundo, pos_blocos: McVec3) -> McCorpoDoMod:
	var c := McCorpoDoMod.new()
	c.id_personagem = id
	c.name = "MC_%s_%d" % [id, Time.get_ticks_usec()]
	var do_mod := Mc.ficha_do_mod(id)
	c.max_health = float(do_mod.get("atributos", {}).get("max_health", 1.0))
	c.health = c.max_health
	c.ficha = {"altura": 0.5, "largura": 0.5}
	c.position = pos_blocos.para_godot() if pos_blocos != null else Vector3.ZERO
	c.add_to_group(GRUPO)
	c.ia_do_mod = IaDoMod.new()
	c.ia_do_mod.name = "IaDoMod"
	c.add_child(c.ia_do_mod)
	c.ia_do_mod.montar(c, id)
	c.projetil = str(do_mod.get("base", "")) in ["AbstractArrow", "ThrowableItemProjectile", "ThrowableProjectile"]
	c._ganchos = do_mod
	var raiz: Node = mundo.arvore.current_scene if mundo != null and mundo.arvore != null else null
	if raiz != null:
		raiz.add_child(c)
		if id == "entity_arrow":        # a flecha do Aro Aro: hitbox maior (ver `FrutasDoMod.ALCANCE_DO_ARO_ARO`)
			McEntidade.de(c).getPersistentData().fator_de_alcance = FrutasDoMod.ALCANCE_DO_ARO_ARO
	if McVisual.tem_corpo(id):
		c._desenho = McVisual.corpo(id)
		c.add_child(c._desenho)
		if c._desenho.has_meta(&"mc_modelo"):
			McVisual.ciclo_base(c._desenho)
	elif not McVisual.e_invisivel(id):
		Mc._falta("visual", "entidade:" + id)       # (as invisíveis do mod não pedem desenho: ver `e_invisivel`)
	return c


## Troca o desenho do corpo por outro (o ASSET da técnica, `AssetsDeTecnica`): o antigo sai, o novo entra com a mesma regra de atualização do `_process`.
func trocar_desenho(novo: Node3D) -> void:
	if is_instance_valid(_desenho):
		remove_child(_desenho)       # sai já: o nome "Desenho" tem de ficar livre para o novo
		_desenho.queue_free()
	_desenho = novo
	add_child(novo)


func vivo() -> bool: return health > 0.0 and not is_queued_for_deletion()
func nome_de_exibicao() -> String: return id_personagem


func take_damage(amount: float, _de: Vector3 = Vector3.ZERO, _kb: Vector3 = Vector3.ZERO, _hs: float = 0.0) -> void:
	if get_meta("damage_immune", false) or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		queue_free()


func _process(_d: float) -> void:
	if _desenho == null:
		return
	if _desenho.has_meta(&"mc_modelo"):
		_atualizar_modelo()
		return
	# Sprito e míssil têm textura própria (não vem de `setTexture`); o míssil aponta o +Y para onde anda.
	if _desenho.has_meta(McVisual.META_FIXO):
		if _desenho.has_meta(&"mc_escala_size"):
			var tam_fixo := McEntidade.de(self).getAttributeValue(Mc.atributo(&"minepiece:size"))
			_desenho.scale = Vector3.ONE * maxf(tam_fixo if tam_fixo > 0.0 else 1.0, 0.1) * McEntidade.de(self).escala(&"height")
		if _desenho.has_meta(&"mc_alinhar_y") and velocity.length_squared() > 0.0001:
			var para := velocity.normalized()
			var eixo := Vector3.UP.cross(para)
			_desenho.basis = Basis(eixo.normalized(), Vector3.UP.angle_to(para)) if eixo.length_squared() > 0.000001 \
				else (Basis.IDENTITY if para.y > 0.0 else Basis(Vector3.RIGHT, PI))
		return
	var t := McEntidade.de(self).getTexture()
	if t != _textura_vista:
		_textura_vista = t
		McVisual.texturizar(_desenho, t)
	# Tamanho do mod (atributo SIZE, em blocos); ausente: 1.
	var tam := McEntidade.de(self).getAttributeValue(Mc.atributo(&"minepiece:size"))
	if tam <= 0.0:
		tam = 1.0
	_desenho.scale = Vector3.ONE * maxf(tam, 0.1) * McEntidade.de(self).escala(&"height")


## Modelo GeckoLib: textura do `setTexture` (só quando muda) e tamanho do mod (atributo SIZE, em blocos; ausente: 1).
func _atualizar_modelo() -> void:
	if not _cubico and McEntidade.de(self).getPersistentData().getDouble("forma_cubica") > 0.0:
		_tornar_cubico()
	if _cubico and is_instance_valid(_cubo):
		_cubo.rotation += Vector3(0.9, 1.3, 0.4) * get_process_delta_time()          # o bloco gira enquanto cai
	var t := McEntidade.de(self).getTexture()
	if t != _textura_vista:
		_textura_vista = t
		McVisual.texturizar_modelo(_desenho, t)
	var tam := McEntidade.de(self).getAttributeValue(Mc.atributo(&"minepiece:size"))
	_desenho.scale = Vector3.ONE * maxf(tam if tam > 0.0 else 1.0, 0.1) * McEntidade.de(self).escala(&"height")


var _cubico := false
var _cubo: MeshInstance3D


## Meteoros QUADRADOS da Zushi Zushi X (pedido do dono, 13/11/2026): troca o desenho do modelo por um cubo da mesma caixa e da mesma textura. Marca: `forma_cubica` no
## PersistentData da entidade (a procedure ajustada `FujitoraMeteorSmallProcedure` a põe). O modelo original só fica escondido (a animação e o ciclo seguem rodando).
func _tornar_cubico() -> void:
	_cubico = true
	var caixa := AABB()
	var primeira := true
	var material: Material
	for m: Node in _desenho.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var a := mi.mesh.get_aabb()
		caixa = a if primeira else caixa.merge(a)
		primeira = false
		if material == null:
			material = mi.get_active_material(0)
		mi.visible = false
	if primeira:
		return
	_cubo = MeshInstance3D.new()
	var bm := BoxMesh.new()
	var lado := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
	bm.size = Vector3.ONE * lado
	# material OPACO (a textura do meteoro é vazada: com o alfa dela o cubo saía só como arestas) e com brasa por dentro
	var sol := StandardMaterial3D.new()
	var base := material as BaseMaterial3D
	sol.albedo_color = Color(0.22, 0.16, 0.14)
	if base != null and base.albedo_texture != null:
		sol.albedo_texture = base.albedo_texture
		sol.albedo_color = Color(0.42, 0.32, 0.30)
	sol.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sol.emission_enabled = true
	sol.emission = Color(1.0, 0.35, 0.08)
	sol.emission_energy_multiplier = 0.5
	sol.roughness = 0.9
	bm.material = sol
	_cubo.mesh = bm
	_cubo.position = caixa.get_center()
	_cubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_desenho.add_child(_cubo)


## `triggerAnim` (GeckoLib): toca o clipe do modelo; "empty" devolve ao ciclo base.
func tocar_tecnica(nome: String) -> void:
	if _desenho == null or not _desenho.has_meta(&"mc_modelo"):
		return
	if nome == "empty" or not McVisual.tocar(_desenho, nome):
		McVisual.ciclo_base(_desenho)


# ------------------------------------------------------------ relâmpago (`minecraft:lightning_bolt`)
## `LightningBolt.tick`: vida 2 e 1–3 reclarões. Cada tick `vida--`; abaixo de 0, sem reclarões some, senão quando
## `vida < -rand(0..9)` gasta um reclarão e volta a `vida = 1` com outro traçado. Só desenha com `vida >= 0`.
## Na PRIMEIRA batida (`vida == 2`): trovão + impacto e `thunderHit` em quem estiver a 3 blocos (x, z), de −3 a +9 em y:
## 5 de dano do tipo `lightning_bolt` e fogo (o que já queima ganha +1 tick; quem não queima, 8 s).
var _raio_vida := 2
var _raio_reclaroes := 1 + randi() % 3


func _passo_do_raio() -> void:
	var eu := McEntidade.de(self)
	if _raio_vida == 2:
		var p := eu.position()
		McVisual.som(get_tree(), "entity.lightning_bolt.thunder", p, 3.0, randf_range(0.8, 1.0))
		McVisual.som(get_tree(), "entity.lightning_bolt.impact", p, 2.0, 0.5 + randf() * 0.2)
		for e: McEntidade in eu.level().getEntitiesOfClass(&"LivingEntity", McAabb.de(p.add(-3.0, -3.0, -3.0), p.add(3.0, 9.0, 3.0))):
			if e == eu or not e.isAlive():
				continue
			var ardendo := e.getRemainingFireTicks()
			e.setRemainingFireTicks(ardendo + 1)
			if ardendo == 0:
				e.setSecondsOnFire(8)
			e.hurt(McFonteDeDano.de(&"minecraft:lightning_bolt", null, eu), 5.0)
	_raio_vida -= 1
	if _raio_vida < 0:
		if _raio_reclaroes == 0:
			queue_free()
			return
		if _raio_vida < -randi_range(0, 9):
			_raio_reclaroes -= 1
			_raio_vida = 1
			if _desenho != null:
				McVisual.raio_reforma(_desenho)
	if _desenho != null:
		_desenho.visible = _raio_vida >= 0


func _physics_process(delta: float) -> void:
	if id_personagem == McVisual.RAIO:
		_acumulado += delta
		while _acumulado >= MundoMinePiece.TICK and is_inside_tree() and not is_queued_for_deletion():
			_acumulado -= MundoMinePiece.TICK
			_passo_do_raio()
		return
	delta *= MundoMinePiece.FATOR_DE_PROJETIL
	if TempoLocal.jogador != null:      # vida baixa do jogador: o disparo alheio anda devagar
		var dono_mc := McEntidade.de(self).getOwner()
		delta *= TempoLocal.fator_de_disparo(global_position, dono_mc.no if dono_mc != null else null)
	if not projetil:
		position += velocity * delta
		return
	_acumulado += delta
	while _acumulado >= MundoMinePiece.TICK and is_inside_tree() and not is_queued_for_deletion():
		_acumulado -= MundoMinePiece.TICK
		_tick_de_projetil()


func _tick_de_projetil() -> void:
	var eu := McEntidade.de(self)
	for p in _ganchos.get("tick_classe", []):
		Mc.chamar(StringName(str(p)), Mc.argumentos_de(eu))
	if is_queued_for_deletion():
		return
	var v := McVec3.de(velocity.x, velocity.y, velocity.z).scale(MundoMinePiece.TICK / MundoMinePiece.METROS_POR_BLOCO)
	var de := eu.position()
	var ate := de.add(v)
	# Entidade no caminho (menos o dono): a mais perto do início do segmento.
	var dono := eu.getOwner()
	var melhor: McEntidade = null
	var perfurou_agora := false       # acertou um alvo e atravessou: neste tick não testa a parede (o segmento já foi dado)
	var menor := INF
	var caixa := McAabb.de(de, ate).inflate(0.5)
	for e: McEntidade in eu.level().getEntitiesOfClass(&"LivingEntity", caixa):
		if e == eu or e == dono or not e.isAlive() or _perfurados.has(e.no.get_instance_id()):
			continue
		var d := e.position().add(0.0, e.getBbHeight() * 0.5, 0.0).distanceToSqr(de)
		if d < menor and _segmento_toca(de, ate, e):
			melhor = e
			menor = d
	if melhor != null:
		# `AbstractArrow.onHitEntity`: com perfuração, só some depois de n+1 alvos (a checagem vem ANTES de contar o novo).
		var perfura := eu.getPierceLevel()
		if perfura > 0:
			if _perfurados.size() >= perfura + 1:
				queue_free()
				return
			_perfurados[melhor.no.get_instance_id()] = true
			perfurou_agora = true
		# dano = ⌈|v| × dano-base⌉, depois o gancho do mod.
		melhor.hurt(McFonteDeDano.de(&"minecraft:arrow", dono, eu), ceilf(v.length() * eu.getBaseDamage()))
		for p in _ganchos.get("ao_acertar_entidade", []):
			Mc.chamar(StringName(str(p)), Mc.argumentos_de(eu))
		if perfura <= 0:
			queue_free()
			return
	var parede := eu.level().clip(McMundo.Raio.de([de, ate, null, null, eu])) if not perfurou_agora else null
	if parede != null and parede.getType() == &"BLOCK":
		position = parede.getLocation().para_godot()
		var bloco := parede.getBlockPos()
		for p in _ganchos.get("ao_acertar_bloco", []):
			Mc.chamar(StringName(str(p)), Mc.argumentos_de(eu, {"x": bloco.x, "y": bloco.y, "z": bloco.z}))
		queue_free()
		return
	position = ate.para_godot()
	var nova := v.scale(ARRASTO).add(0.0, 0.0 if eu.isNoGravity() else -GRAVIDADE_FLECHA, 0.0)
	velocity = nova.para_godot() / MundoMinePiece.TICK


## A caixa da entidade toca o segmento? (amostras ao longo do tick; o passo de uma bala é curto).
static func _segmento_toca(de: McVec3, ate: McVec3, e: McEntidade) -> bool:
	var caixa := e.getBoundingBox().inflate(0.3)
	for i in 9:
		var t := i / 8.0
		if caixa.contains(de.x + (ate.x - de.x) * t, de.y + (ate.y - de.y) * t, de.z + (ate.z - de.z) * t):
			return true
	return false
