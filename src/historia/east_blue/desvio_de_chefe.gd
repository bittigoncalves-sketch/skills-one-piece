class_name DesvioDeChefe
extends Node
## O CHEFE DESVIA DE PROJÉTIL (08/11/2026, pedido do dono: "chefes com dash ou teleporte para desviar de projéteis, com intervalo de 15
## segundos, o destino um local sem obstáculos"). Filho do chefe (`PersonagemMinePiece` com `ficha.chefe`), instalado por ele.
##
## A cada `PERIODO` s, se o chefe está em luta (tem alvo), livre da recarga e de pé, procura um projétil DO JOGADOR que vá acertá-lo dentro
## de `JANELA` s (mesma geometria do `BossProjectileSensor`: passagem mais próxima entre a trajetória reta e o corpo). Achando, TELEPORTA
## para um ponto ao lado da trajetória, livre de obstáculos (chão sob o ponto, cápsula do corpo sem colisão, dentro da zona de perseguição)
## e fica `INTERVALO` s sem poder de novo. Sem destino livre, não gasta a recarga.
##
## Projéteis lidos: `DamageZone` em voo (grupo "hitbox"), munição das frutas nativas (`MunicaoMinePiece`) e entidades do mod que o jogador
## lançou (`McCorpoDoMod`, `getOwner()` = jogador). Golpe parado/corpo a corpo (velocidade < `VELOCIDADE_MINIMA`) não conta.

const INTERVALO := 15.0
const PERIODO := 0.1
const JANELA := 0.6
const VELOCIDADE_MINIMA := 8.0
const ALCANCE_DE_VISAO := 22.0
const MARGEM := 0.35
const DISTANCIAS: Array[float] = [5.0, 8.0, 11.0]

var corpo: PersonagemMinePiece
var recarga := 0.0               # s que faltam
var desvios := 0                 # quantos já fez (testes e HUD de debug)
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	corpo = get_parent() as PersonagemMinePiece
	_rng.randomize()
	_t = _rng.randf_range(0.0, PERIODO)


func _physics_process(delta: float) -> void:
	recarga = maxf(recarga - delta, 0.0)
	_t += delta
	if _t < PERIODO:
		return
	_t = 0.0
	if recarga > 0.0 or corpo == null or not corpo.vivo() or corpo.esta_caido():
		return
	if corpo.cerebro == null or corpo.cerebro.alvo == null:
		return
	var ameaca := mais_urgente()
	if ameaca.is_empty():
		return
	var destino: Variant = destino_livre(ameaca)
	if destino == null:
		return
	teleportar(destino)
	recarga = INTERVALO
	desvios += 1


## A ameaça mais urgente ({time, direcao, posicao}) ou {}.
func mais_urgente() -> Dictionary:
	var melhor := {}
	for c in _candidatos():
		var a := avaliar(corpo, c["posicao"], c["velocidade"], c["raio"])
		if a.is_empty():
			continue
		a["direcao"] = (c["velocidade"] as Vector3).normalized()
		a["posicao"] = c["posicao"]
		if melhor.is_empty() or float(a["time"]) < float(melhor["time"]):
			melhor = a
	return melhor


func _candidatos() -> Array:
	var saida: Array = []
	var arvore := get_tree()
	for z in arvore.get_nodes_in_group("hitbox"):
		var zona := z as DamageZone
		if zona == null or zona.corpo_a_corpo or not _do_jogador(zona.caster):
			continue
		saida.append({"posicao": zona.global_position, "velocidade": zona.vel, "raio": 0.5})
	for n in arvore.get_nodes_in_group(AlvosDeGolpe.GRUPO):
		if n is MunicaoMinePiece and is_instance_valid((n as MunicaoMinePiece).c) and _do_jogador((n as MunicaoMinePiece).c.ator):
			var m := n as MunicaoMinePiece
			var v := m.rumo.normalized() * m.velocidade * MundoMinePiece.METROS_POR_BLOCO / MundoMinePiece.TICK * MundoMinePiece.FATOR_DE_PROJETIL
			saida.append({"posicao": m.global_position, "velocidade": v, "raio": MundoMinePiece.m(m.largura_b()) * 0.5})
	for n in arvore.get_nodes_in_group(McCorpoDoMod.GRUPO):
		var p := n as CharacterBody3D
		if p == null or p.velocity.length() < VELOCIDADE_MINIMA:
			continue
		var dono := McEntidade.de(p).getOwner()
		if dono != null and _do_jogador(dono.no):
			saida.append({"posicao": p.global_position, "velocidade": p.velocity * MundoMinePiece.FATOR_DE_PROJETIL, "raio": 0.5})
	return saida


static func _do_jogador(quem: Variant) -> bool:
	return quem is Node and is_instance_valid(quem) and (quem as Node).is_in_group("player")


## Passagem mais próxima entre a trajetória reta do projétil e o corpo (cápsula = segmento vertical). Sem ameaça: {}.
static func avaliar(c: PersonagemMinePiece, posicao: Vector3, velocidade: Vector3, raio: float) -> Dictionary:
	var v2 := velocidade.length_squared()
	if v2 < VELOCIDADE_MINIMA * VELOCIDADE_MINIMA:
		return {}
	var centro := c.global_position + Vector3.UP * float(c.ficha.get("altura", 1.8)) * 0.5
	if centro.distance_to(posicao) > ALCANCE_DE_VISAO:
		return {}
	var tempo := (centro - posicao).dot(velocidade) / v2
	if tempo <= 0.0 or tempo > JANELA:
		return {}
	var ponto := posicao + velocidade * tempo
	var meia := float(c.ficha.get("altura", 1.8)) * 0.5
	var corpo_raio := float(c.ficha.get("largura", 0.6)) * 0.5
	var ao_longo := clampf(ponto.y - centro.y, -meia + corpo_raio, meia - corpo_raio)
	var erro := ponto.distance_to(centro + Vector3.UP * ao_longo)
	if erro > corpo_raio + raio + MARGEM:
		return {}
	return {"time": tempo, "miss": erro, "point": ponto}


## Um ponto ao lado da trajetória, livre de obstáculos. null se nenhum serve.
func destino_livre(ameaca: Dictionary) -> Variant:
	var dir: Vector3 = ameaca["direcao"]
	var lado := dir.cross(Vector3.UP)
	if lado.length_squared() < 0.0001:
		lado = Vector3.RIGHT
	lado = lado.normalized()
	var pontos: Array[Vector3] = []
	for d in DISTANCIAS:
		for s in [1.0, -1.0]:
			pontos.append(corpo.global_position + lado * s * d)
			pontos.append(corpo.global_position + (lado * s + Vector3(dir.x, 0.0, dir.z).normalized() * 0.6).normalized() * d)
	# Embaralha por grupo de distância (o mais perto primeiro, mas sem um lado fixo).
	for i in range(0, pontos.size(), 4):
		for k in 3:
			var a := i + _rng.randi() % mini(4, pontos.size() - i)
			var b := i + _rng.randi() % mini(4, pontos.size() - i)
			var tmp := pontos[a]
			pontos[a] = pontos[b]
			pontos[b] = tmp
	for p in pontos:
		var chao: Variant = _chao_livre(p)
		if chao != null:
			return chao
	return null


## O ponto no chão sob `p`, se a cápsula do corpo cabe ali sem tocar nada e dentro da zona de perseguição. Senão null.
func _chao_livre(p: Vector3) -> Variant:
	var espaco := corpo.get_world_3d().direct_space_state
	var raio_tiro := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 3.0, 1)
	raio_tiro.exclude = [corpo.get_rid()]
	var h := espaco.intersect_ray(raio_tiro)
	if h.is_empty() or float((h["normal"] as Vector3).y) < 0.7:
		return null
	var pe: Vector3 = h["position"] + Vector3.UP * 0.05
	var altura := float(corpo.ficha.get("altura", 1.8))
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(0.25, float(corpo.ficha.get("largura", 0.6)) * 0.5)
	cap.height = maxf(altura, cap.radius * 2.0 + 0.05)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pe + Vector3.UP * (cap.height * 0.5 + 0.12))
	q.collision_mask = 1
	q.exclude = [corpo.get_rid()]
	if not espaco.intersect_shape(q, 1).is_empty():
		return null
	var zona := corpo.cerebro.zona_de_perseguicao() if corpo.cerebro != null else INF
	if is_finite(zona) and Vector2(pe.x - corpo.ponto_de_origem.x, pe.z - corpo.ponto_de_origem.z).length() > zona:
		return null
	return pe


func teleportar(destino: Vector3) -> void:
	var de := corpo.global_position
	McVisual.particula(get_tree(), "minecraft:cloud", McVec3.de_godot(de + Vector3.UP), 14, 0.3, 0.5, 0.3, 0.05)
	corpo.global_position = destino
	corpo.velocity = Vector3.ZERO
	McVisual.particula(get_tree(), "minecraft:cloud", McVec3.de_godot(destino + Vector3.UP), 14, 0.3, 0.5, 0.3, 0.05)
	McVisual.som(get_tree(), "entity.enderman.teleport", McVec3.de_godot(destino), 1.0, 1.0)
