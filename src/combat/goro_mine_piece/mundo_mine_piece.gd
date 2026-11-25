class_name MundoMinePiece
extends RefCounted
# ============================================================================
#  OS UTILITÁRIOS DO MINE PIECE v14 QUE AS TÉCNICAS DA GORO GORO CHAMAM.
#
#  Tradução, procedimento a procedimento, do que o mod faz por baixo de cada
#  técnica: RangeAttackProcedure, InsideSolidCalculateProcedure,
#  ReturnEntitySizeProcedure, Effect11Procedure e a imunidade de dano do
#  Minecraft (`invulnerableTime`), que o mod NÃO reescreve e que decide quantas
#  vezes um alvo leva dano numa rajada.
#
#  Unidades: o mod conta em BLOCOS e TICKS (20/s). Aqui, 1 bloco = 0,88 m (a escala
#  das estruturas, `tools/mine_piece/estrutura_para_glb.py`) e 1 tick = 0,05 s.
#  Dano: o número do mod × 10 vira o da arena (a mesma conversão de
#  `Balance.MINE_PIECE_LUTA`); a escala da história entra por `escala`.
# ============================================================================

const METROS_POR_BLOCO := 0.88
const TICK := 0.05
## Velocidade dos PROJÉTEIS (08/11/2026, pedido do dono: "diminui a velocidade de todos os projéteis"): o relógio de cada projétil anda
## nesta fração do tempo. Anda a mesma distância em tempo real maior (vida e alcance contados em ticks não mudam). 1.0 = a do mod.
static var FATOR_DE_PROJETIL := 0.5
## Velocidade do mod (blocos por tick) → m/s.
const VELOCIDADE := METROS_POR_BLOCO / TICK
## O corpo do jogador no Minecraft (EntityType.PLAYER), em blocos.
const LARGURA_JOGADOR := 0.6
const ALTURA_JOGADOR := 1.8
## Altura dos olhos do jogador no Minecraft (`getEyeY`), em blocos.
const OLHOS_JOGADOR := 1.62
const DANO_DA_ARENA_POR_DANO_DO_MOD := 10.0
## `invulnerableTime` do Minecraft: 20 ao ferir; aceita dano de novo com ≤ 10. Dentro
## da janela só passa a DIFERENÇA para um golpe maior que o anterior.
const IMUNIDADE_TICKS := 10
## Effect11Procedure: Lentidão X e bloqueio de técnicas por 10 ticks — o choque paralisa.
const CHOQUE := 10 * TICK
## Quem o choque não paralisa (Effect11: Gomu e Goro; esqueletos e Brook não existem aqui).
const IMUNES_AO_CHOQUE := ["gomu_gomu", "goro_goro", "goro_goro_mine_piece"]
const MASCARA_MUNDO := 1
## SetRangedAmmoProcedure: a entidade criada por uma técnica guarda o id do dono aqui.
const DONO := "dono_mine_piece"
## RangeAttackProcedure.Y_limit: 0 fora do Core Crash do Sabo — o empurrão é só horizontal.
const LIMITE_VERTICAL := 0.0


static func m(blocos: float) -> float:
	return blocos * METROS_POR_BLOCO


## ReturnEntitySizeProcedure: raiz cúbica de (altura + largura) × 0,42, em blocos.
static func tamanho(altura_b: float, largura_b: float) -> float:
	return pow((altura_b + largura_b) * 0.42, 1.0 / 3.0)


## ReturnEntitySizeProcedure para entidade da tag `forge:ranged_ammo` (pata, lança, punho...): RAIZ QUADRADA, não cúbica.
static func tamanho_municao(altura_b: float, largura_b: float) -> float:
	return sqrt((altura_b + largura_b) * 0.42)


## InsideSolidCalculateProcedure: a caixa de pé em `pe` (altura e largura em blocos) toca
## o mundo? Corpos (jogador, NPC, animal) não contam: no mod a pergunta é sobre blocos.
static func solido(mundo: World3D, pe: Vector3, altura_b: float, largura_b: float) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3(m(largura_b), m(altura_b), m(largura_b))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis.IDENTITY, pe + Vector3.UP * m(altura_b) * 0.5)
	q.collision_mask = MASCARA_MUNDO
	for r in mundo.direct_space_state.intersect_shape(q, 8):
		var no: Object = r.get("collider")
		if no is CharacterBody3D or (no is Node and (AlvosDeGolpe.e_alvo(no) or no.has_method("take_damage"))):
			continue
		return true
	return false


## O corpo de `alvo` toca o cubo de lado `lado_b` blocos centrado em `centro`?
## (`AABB.inflate(Range/2)` + `getEntitiesOfClass`: caixa alinhada aos eixos.)
static func no_cubo(alvo: Node3D, centro: Vector3, lado_b: float) -> bool:
	var meio := Vector3.ONE * m(lado_b) * 0.5
	var c := AlvosDeGolpe.centro(alvo)
	var perto := c.clamp(centro - meio, centro + meio)
	return AlvosDeGolpe.distancia_ao_corpo(alvo, perto) <= 0.05


## LogicAttackProcedure, na regra deste jogo: vivo, alvo de golpe e não o próprio.
## Aliado (mesmo bando, tripulação) é decidido no alvo pelo `autor` do dano.
static func atacavel(ator: Node, alvo: Node) -> bool:
	if alvo == null or alvo == ator or not is_instance_valid(alvo) or not (alvo is Node3D):
		return false
	if not AlvosDeGolpe.e_alvo(alvo) or not alvo.has_method("take_damage"):
		return false
	# LogicAttack: a munição (OWNER_UUID) não fere o próprio dono nem a munição dele.
	if int(alvo.get_meta(DONO, 0)) == ator.get_instance_id() or \
			(ator.has_meta(DONO) and int(ator.get_meta(DONO)) == int(alvo.get_meta(DONO, -1))) or \
			(ator.has_meta(DONO) and int(ator.get_meta(DONO)) == alvo.get_instance_id()):
		return false
	var vida: Variant = alvo.get("health")
	return vida == null or float(vida) > 0.0


## (altura, largura) do corpo em blocos, pela forma do Hurtbox; sem ela, o jogador do Minecraft.
static func dimensoes_b(no: Node3D) -> Vector2:
	var hb := no.get_node_or_null("Hurtbox")
	if hb != null:
		for filho in hb.get_children():
			var cs := filho as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var k := cs.global_basis.get_scale()
			if cs.shape is BoxShape3D:
				var t: Vector3 = (cs.shape as BoxShape3D).size * k
				return Vector2(t.y, maxf(t.x, t.z)) / METROS_POR_BLOCO
			if cs.shape is CapsuleShape3D:
				var c := cs.shape as CapsuleShape3D
				return Vector2(c.height * k.y, c.radius * 2.0 * k.x) / METROS_POR_BLOCO
			if cs.shape is SphereShape3D:
				var r := (cs.shape as SphereShape3D).radius * 2.0 * k.x / METROS_POR_BLOCO
				return Vector2(r, r)
	return Vector2(ALTURA_JOGADOR, LARGURA_JOGADOR)


## O pé do corpo (o `getY()` do Minecraft). Quem responde `centro_do_corpo` tem a
## origem no pé; jogador, boneco e inimigo do mapa, no meio.
static func pe_de(no: Node3D) -> Vector3:
	if no.has_method("centro_do_corpo"):
		return no.global_position
	return no.global_position - Vector3.UP * m(dimensoes_b(no).x) * 0.5


## O primeiro alvo atacável dentro do cubo, ou null (as paradas "logic_b" do mod).
static func primeiro_no_cubo(ator: Node, centro: Vector3, lado_b: float) -> Node3D:
	for alvo in AlvosDeGolpe.todos(ator.get_tree()):
		if atacavel(ator, alvo) and no_cubo(alvo, centro, lado_b):
			return alvo
	return null


## O estado de um RangeAttack: o que o mod guarda em `getPersistentData()` antes de chamar.
class Ataque:
	var dano := 0.0          ## "Damage", unidades do mod
	var lado := 0.0          ## "Range", lado do cubo em blocos
	var empurrao := 0.0      ## "knockback"
	var choque := false      ## "effect" 11
	var ignora_guarda := false   ## "ignore": a guarda não reduz (WhenEntityTakesDamage)
	## EffectProcedure dos outros efeitos (12 da Hie…): chamado com cada alvo ferido.
	var ao_ferir := Callable()
	## D.x/y/z_knockback: velocidade da munição somada ao empurrão radial (blocos/tick).
	var empurrao_extra := Vector3.ZERO
	func _init(d: float, l: float, k: float, e11 := true) -> void:
		dano = d; lado = l; empurrao = k; choque = e11


## RangeAttackProcedure: fere todo atacável cujo corpo toca o cubo de `a.lado` blocos em
## `centro`. `origem` é de onde o mod empurra: quem ataca (o jogador, o meteoro, a onda).
## `ator` é o dono do golpe: não é ferido e assina o dano (aliado decide no alvo).
## `imunidade` é o `invulnerableTime` desta fruta (alvo → [tick, último dano]).
## Devolve quantos alvos levaram dano.
static func ataque_em_area(ator: Node3D, origem: Vector3, centro: Vector3, a: Ataque, tick: int,
		imunidade: Dictionary, escala: float, fator_bloqueio: float) -> int:
	var feridos := 0
	DestruicaoDeEstruturas.golpe(ator.get_tree(), centro, m(a.lado) * 0.5)      # construções viram blocos (08/11/2026)
	for alvo in AlvosDeGolpe.todos(ator.get_tree()):
		if not atacavel(ator, alvo) or not no_cubo(alvo, centro, a.lado):
			continue
		var dano := a.dano
		var defensor = alvo.get("combate_direcional")
		if not a.ignora_guarda and defensor != null and defensor is ExecutorCorpoACorpo:
			match ResolucaoDeContato.resolver_tecnica(centro, defensor, dano):
				ResolucaoDeContato.Resultado.BLOQUEIO:
					defensor.receber_bloqueio_de_postura(dano)
					dano *= fator_bloqueio
				ResolucaoDeContato.Resultado.QUEBRA_DE_GUARDA:
					defensor.quebrar_guarda(null)
		dano = _passar_imunidade(alvo, dano, tick, imunidade)
		if dano <= 0.0:
			continue
		var choque := a.choque and not str(alvo.get("current_fruit_id")) in IMUNES_AO_CHOQUE
		CombatResolver.aplicar(alvo, dano * DANO_DA_ARENA_POR_DANO_DO_MOD * escala, 0, 0.0,
			centro, empurrao(origem, alvo, a.empurrao) + a.empurrao_extra * VELOCIDADE, CHOQUE if choque else 0.1,
			0.0, false, null, ator)
		if a.ao_ferir.is_valid():
			a.ao_ferir.call(alvo)
		feridos += 1
	return feridos


## KnockbackProcedure: empurra (sem ferir) todo atacável no cubo de `lado_b` blocos em
## `centro`, a partir de `de` (efeito 1: do centro; senão, de quem empurra), módulo
## `knockback × 3` blocos/tick, vertical limitado a 1,5 (Y_limit do procedimento).
static func empurrar_area(ator: Node3D, de: Vector3, centro: Vector3, lado_b: float, knockback: float) -> int:
	var empurrados := 0
	for alvo in AlvosDeGolpe.todos(ator.get_tree()):
		if not atacavel(ator, alvo) or not no_cubo(alvo, centro, lado_b):
			continue
		CombatResolver.aplicar(alvo, 0.0, 0, 0.0, de, empurrao(de, alvo, knockback, 1.5), 0.0,
			0.0, false, null, ator)
		empurrados += 1
	return empurrados


## O `hurt` do Minecraft: dentro de 10 ticks do último dano só passa o que exceder o anterior.
static func _passar_imunidade(alvo: Node, dano: float, tick: int, imunidade: Dictionary) -> float:
	var id := alvo.get_instance_id()
	var antes: Array = imunidade.get(id, [-1000, 0.0])
	if tick - int(antes[0]) >= IMUNIDADE_TICKS:
		imunidade[id] = [tick, dano]
		return dano
	if dano <= float(antes[1]):
		return 0.0
	imunidade[id] = [int(antes[0]), dano]
	return dano - float(antes[1])


## ALCANCE DO EMPURRÃO (25/11/2026, pedido do dono: "cerca de 7 a 8 blocos" nas técnicas fortes). O mod empurra com `knockback × 3` blocos/tick e o
## Minecraft desacelera pelo atrito (0,546/tick no chão); este jogo desacelera LINEAR (14 m/s² no inimigo), então a velocidade do mod crua jogava o alvo
## a 100 m (valor 1,0) ou 485 m (2,5). Agora a distância de recuo vale `DISTANCIA_DO_EMPURRAO_POR_PONTO × valor` (metade do Minecraft: 2,65 m por ponto →
## 2,5 = 6,6 m ≈ 7,5 blocos) e a velocidade inicial é a que, com a desaceleração do inimigo, chega a essa distância: v = √(2·a·d).
const DISTANCIA_DO_EMPURRAO_POR_PONTO := 2.65
const DESACELERACAO_DO_INIMIGO := 14.0


## Velocidade inicial (m/s) para um empurrão de valor `knockback` do mod.
static func velocidade_do_empurrao(knockback: float) -> float:
	return sqrt(2.0 * DESACELERACAO_DO_INIMIGO * DISTANCIA_DO_EMPURRAO_POR_PONTO * maxf(knockback, 0.0))


## O empurrão do RangeAttack/KnockbackProcedure: DIREÇÃO como no mod (de quem ataca até o alvo; no chão o vertical mínimo é 0,42, depois limitado por
## `LIMITE_VERTICAL` sem perder módulo) e MÓDULO pelo alcance acima. Volta em m/s (o `take_damage` do jogo).
static func empurrao(de: Vector3, alvo: Node3D, knockback: float, limite := LIMITE_VERTICAL) -> Vector3:
	var v := (alvo.global_position - de) / METROS_POR_BLOCO
	var no_chao: bool = alvo.has_method("is_on_floor") and alvo.is_on_floor()
	if no_chao or is_zero_approx(v.y):
		v.y = maxf(absf(v.y), 0.42)
	if is_zero_approx(v.x) and is_zero_approx(v.z):
		v.x = randf_range(-v.y, v.y)
		v.z = randf_range(-v.y, v.y)
	if v.length_squared() < 0.000001:
		return Vector3.ZERO
	v = v.normalized() * knockback * 3.0
	if v.y > limite:
		var modulo := v.length()
		var horizontal := Vector2(v.x, v.z).length()
		var k := sqrt(maxf(modulo * modulo - limite * limite, 0.0)) / (horizontal if horizontal > 0.0 else 1.0)
		v = Vector3(v.x * k, limite, v.z * k)
	var bruto := knockback * 3.0                           # o módulo do mod (blocos/tick), para a razão
	return v * (velocidade_do_empurrao(knockback) / bruto if bruto > 0.0 else 0.0)
