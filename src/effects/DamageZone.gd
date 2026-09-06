class_name DamageZone
extends Area3D
# Área de dano móvel: aplica dano + knockback em corpos com take_damage() (menos
# o próprio caster). Já pronta para inimigos futuros; hoje só não acha alvos.

signal hit_landed(target: Node)
## ⚠️ EMITIDO ANTES DE O DANO SER APLICADO, e é para isso que ele existe.
##
## `hit_landed` chega tarde demais para quem precisa saber o ESTADO do alvo no
## instante do impacto: quando ele dispara, o `take_damage` já rodou e já
## interrompeu o golpe que o alvo estava carregando. O counter hit depende
## exatamente dessa informação — "ele estava em startup?" — e a leria sempre
## como falsa.
signal antes_do_acerto(target: Node)
signal collided_with_any(body: Node)

# ⚠️ O `DAMAGE_SCALE` de 0,12 QUE MORAVA AQUI FOI REMOVIDO (2026-08-21).
#
# Ele existia porque o foco do jogo é knockback e o dano precisava ser baixo —
# mas estava no lugar errado, e isso tinha consequência: quem criava hitbox
# levava o corte de 8,3x, e quem chamava `take_damage()` direto (seis efeitos,
# entre eles o Liberation da Yami e o Domínio da Bara) entregava o número cru.
# A mesma tabela produzia golpes de 2,4 e de 1811 contra uma vida de 2048.
#
# Agora o número que chega em `damage` é FINAL, vem de `src/combat/Balance.gd` e
# não é multiplicado por nada no caminho. Ver `src/combat/CombatResolver.gd`.

var damage: float = 0.0
var knockback: float = 0.0
var hitstun: float = 0.3
var derruba: float = 0.0
var vel: Vector3 = Vector3.ZERO
var caster: Node = null

# ---------------------------------------------------- ORÇAMENTO DA CONJURAÇÃO
# Quem carimba estes dois é a `DamageSpec` do golpe (`spec.marcar(zona)`). Todas
# as hitboxes nascidas do mesmo aperto de tecla compartilham o `cast_id`, e o
# `CombatResolver` corta o que passar do `teto` — é o que impede um Gatling de
# 16 socos ou um Liberation de 25 escombros de somar dano sem limite.
#
# Zerados = golpe avulso, sem orçamento: entrega o valor cheio a cada acerto.
# É o caso legítimo do golpe de um acerto só, e o caso das auditorias de
# `tools/dev_tests/`, que criam zonas sem passar pela tabela.
var cast_id: int = 0
var teto: float = 0.0
# Parte do teto guardada para o acerto de clímax, e se ESTA zona é ele.
# Carimbados por `DamageSpec.marcar(zona, e_climax)`.
var reserva: float = 0.0
var reservado: bool = false
var override_kb_dir: Vector3 = Vector3.ZERO
var _hit: Dictionary = {}
var is_weapon_swing: bool = false
var is_projectile: bool = false
var _clashed: bool = false

# Explosoes normalmente atravessavam qualquer parede porque o overlap da esfera
# nao conhece cobertura. A opcao e desligada por padrao para nao mudar golpes
# antigos; o Tri-Beam a liga explicitamente e fornece o ponto do impacto.
var exige_linha_de_visao: bool = false
var origem_linha_de_visao: Vector3 = Vector3.ZERO

# Cria a colisão e a agenda de vida. Chamar logo após add_child.
#
# `forma` é OPCIONAL e existe por um caso concreto: os tsunamis da ultimate da
# Gura Gura têm 70 m de frente por 24 m de altura, e a esfera que cobrisse isso
# teria 35 m de raio — ela acertaria quem estivesse 35 m ATRÁS da onda, que é o
# oposto do que o olho promete. Quem passa uma `forma` manda nela; quem não
# passa (todo o resto do jogo, inclusive o C do Karatê Tritão) continua com a
# esfera de `radius`, exatamente como antes.
func setup(dmg: float, kb: float, velocity: Vector3, life: float, caster_node: Node,
		radius: float, forma: Shape3D = null, hitstun_dur: float = 0.3) -> void:
	damage = dmg
	knockback = kb
	hitstun = hitstun_dur
	vel = velocity
	caster = caster_node

	var col := CollisionShape3D.new()
	if forma != null:
		col.shape = forma
	else:
		var shape := SphereShape3D.new()
		shape.radius = radius
		col.shape = shape
	add_child(col)

	# A MESMA esfera serve de colisor e de sonda da varredura — se um dia
	# alguém mudar o raio, os dois mudam juntos por construção. Forma
	# customizada (a parede de tsunami da Gura é uma caixa de 200 m) devolve
	# `null` aqui e continua na varredura por raio, exatamente como antes.
	_forma_varredura = col.shape as SphereShape3D

	# ⚠️ GRUPO "hitbox" (2026-08-22): é assim que a visão do E (`ScreenFX`) acha os
	# ataques em voo para desenhá-los através das paredes. Sem grupo, a única
	# alternativa seria varrer a cena inteira a cada 0,15 s.
	add_to_group("hitbox")
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)
	FxUtil.autofree(self, life)

# PARALISIA opcional: > 0 = o alvo congela por esse tempo em vez de ser
# empurrado. Usado pelos raios do El Thor, que prendem em vez de arremessar.
var paralisa: float = 0.0

func _physics_process(delta: float) -> void:
	if vel == Vector3.ZERO:
		return
	var antes := global_position
	global_position += vel * delta
	_varrer_caminho(antes, global_position)

# ⚠️ PROJÉTIL RÁPIDO ATRAVESSAVA O ALVO — e ninguém sabia.
#
# A zona anda por TELEPORTE (`global_position += vel * delta`), e a `Area3D` só
# enxerga quem está sobreposto NAQUELE quadro. A 60 Hz o passo é `vel / 60`:
# com alvo de 1,0 m e raio 0,16, a janela de acerto é ~1,32 m, ou seja acima de
# ~79 m/s a bala pula o alvo entre dois quadros.
#
# Medido em 2026-08-12 (24 disparos por velocidade):
#     79 m/s -> 24/24 acertos      125 m/s -> 16/24
#     95 m/s -> 20/24              200 m/s ->  9/24
# A sniper estava em 95: perdia 1 tiro em 6, sem o jogador ter como saber.
#
# Sub-passo de POSIÇÃO não resolve: a `Area3D` detecta uma vez por quadro de
# física, então mover em pedaços dentro do mesmo quadro não gera detecção nova.
# O que resolve é VARRER O CAMINHO.
#
# ------------------------------- ⚠️ O RAIO RESOLVIA METADE DO PROBLEMA (2026-09-06)
# A varredura acima era um `intersect_ray`, e RAIO NÃO TEM ESPESSURA. Ou seja:
# entre dois quadros a hitbox de uma bala deixava de ser a esfera anunciada e
# virava a LINHA DO CENTRO dela. Quem passasse de raspão saía ileso, e o
# jogador não tinha como saber por quê — a bola brilhante atravessou o peito
# do adversário e não aconteceu nada.
#
# Medido nesta máquina (Godot 4.6.3, alvo-cápsula de raio 0,4 deslocado 0,45 m
# do eixo, passo de 1,30 m — que é o do Z da Pika a 78 m/s):
#     intersect_ray ....... PASSOU DIRETO
#     cast_motion ......... acertou na fração 0,340 do passo
#
# Agora a varredura é uma ESFERA VARRIDA: `cast_motion` acha o instante do
# primeiro contato ao longo do passo e `intersect_shape` diz quem estava lá.
# A hitbox passa a valer o raio inteiro em todo o percurso, que é o que o
# `radius` sempre prometeu.
#
# CUSTO, medido no caso que domina (voando no vazio, 2.000 chamadas):
#     intersect_ray ....... 0,105 us      cast_motion ..... 0,176 us
# São 21 us por quadro com 120 projéteis vivos — 0,13% de um quadro de 60 Hz.
# O número assustador de 48x que aparece numa medição ingênua é o caso de
# ACERTO, que acontece uma vez na vida de cada projétil.
const MAX_ALVOS_VARREDURA := 8
var _forma_varredura: SphereShape3D = null

func _varrer_caminho(de: Vector3, ate: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return                      # só o servidor decide acerto
	var mundo := get_world_3d()
	if mundo == null:
		return
	var espaco := mundo.direct_space_state
	var excluir: Array[RID] = []
	if is_instance_valid(caster) and caster is CollisionObject3D:
		excluir.append((caster as CollisionObject3D).get_rid())

	if _forma_varredura == null:
		# Forma customizada: segue no raio de sempre. A parede de tsunami da
		# Gura tem 12 m de profundidade justamente para não tunelar, e varrer
		# uma caixa de 200 m custaria caro para resolver um problema que ela
		# não tem.
		_varrer_por_raio(espaco, de, ate, excluir, true, is_projectile)
		return

	_varrer_por_esfera(espaco, de, ate, excluir)
	# ⚠️ `cast_motion` NÃO enxerga `Area3D` — medido, não suposto. O clash de
	# espada e o corte de projétil dependem de encontrar áreas, então eles
	# continuam no raio. Fica barato porque só projétil paga por isso.
	if is_projectile:
		_varrer_por_raio(espaco, de, ate, excluir, false, true)


# A esfera varrida. Quem tunelava agora acerta.
func _varrer_por_esfera(espaco: PhysicsDirectSpaceState3D, de: Vector3,
		ate: Vector3, excluir: Array[RID]) -> void:
	var par := PhysicsShapeQueryParameters3D.new()
	par.shape = _forma_varredura
	par.transform = Transform3D(Basis(), de)
	par.motion = ate - de
	par.collision_mask = 15
	par.collide_with_bodies = true
	par.collide_with_areas = false
	par.exclude = excluir

	var fracao := espaco.cast_motion(par)
	# [1,1] significa DUAS coisas: caminho livre, ou a esfera já nasceu
	# sobreposta a alguém (medido: o Godot devolve o passo inteiro nesse caso,
	# não zero). Os dois saem daqui, e o segundo está coberto — a própria
	# `Area3D` emite `body_entered` para quem já está dentro dela.
	if fracao.size() < 2 or fracao[1] >= 1.0:
		return

	par.transform = Transform3D(Basis(), de.lerp(ate, fracao[1]))
	par.motion = Vector3.ZERO
	# TODOS os resultados, não o primeiro: dois corpos colados na fração do
	# contato são dois acertos legítimos, e ficar com um só recriaria em outro
	# lugar o mesmo buraco que esta varredura fecha.
	for resultado in espaco.intersect_shape(par, MAX_ALVOS_VARREDURA):
		var corpo = resultado.get("collider")
		if corpo is Node3D and not _hit.has(corpo):
			_on_body(corpo as Node3D)


func _varrer_por_raio(espaco: PhysicsDirectSpaceState3D, de: Vector3,
		ate: Vector3, excluir: Array[RID], corpos: bool, areas: bool) -> void:
	var par := PhysicsRayQueryParameters3D.create(de, ate)
	par.collide_with_areas = areas
	par.collide_with_bodies = corpos
	par.collision_mask = 15
	par.exclude = excluir
	var hit := espaco.intersect_ray(par)
	if hit.is_empty():
		return
	var corpo = hit.get("collider")
	if corpo is Area3D:
		_on_area(corpo as Area3D)
	elif corpo is Node3D and not _hit.has(corpo):
		_on_body(corpo as Node3D)

func _on_area(area: Area3D) -> void:
	if _clashed or not multiplayer.is_server(): return
	if area is DamageZone and area != self and area.caster != caster:
		if is_weapon_swing:
			if area.is_weapon_swing and not area._clashed:
				# Clash (Espada vs Espada)
				_clashed = true
				area._clashed = true
				set_deferred("monitoring", false)
				area.set_deferred("monitoring", false)
				_do_clash_effects()
				queue_free()
				area.queue_free()
			elif area.is_projectile and not area._clashed:
				# Deflexão/Corte (Espada vs Projétil)
				area._clashed = true
				area.set_deferred("monitoring", false)
				_do_deflect_effects()
				area.queue_free()

@rpc("call_local", "reliable")
func _net_clash_effects() -> void:
	var gf := get_node_or_null("/root/GameFlow")
	if gf and gf.has_method("hit_stop"): gf.hit_stop()
	var sfx := get_node_or_null("/root/ScreenFX")
	if sfx and sfx.has_method("flash"): sfx.flash(Color(1.0, 0.9, 0.6), 0.1)
	# TODO: Spawnar sparks de metal

func _do_clash_effects() -> void:
	if multiplayer.has_multiplayer_peer():
		rpc("_net_clash_effects")
	else:
		_net_clash_effects()

func _do_deflect_effects() -> void:
	# O corte de projétil pode ter efeitos menores
	_do_clash_effects()

func _on_body(body: Node3D) -> void:
	# Autoridade de combate: só o SERVIDOR aplica dano/knockback. Em clientes a zona
	# é apenas visual/inerte (sem peer = SP -> is_server true -> aplica normalmente).
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if body == caster or _hit.has(body):
		return
	if exige_linha_de_visao and not _tem_linha_de_visao(body):
		return
		
	collided_with_any.emit(body)
	
	if body.has_method("take_damage"):
		# A camuflagem só quebra ao acertar OUTRO jogador, não ao tocar dummy.
		if body.is_in_group("player") and is_instance_valid(caster) and caster.has_method("revelar_invisibilidade"):
			caster.revelar_invisibilidade()
		_hit[body] = true
		
		# KNOCKBACK -> src/mechanics/Knockback.gd (2026-08-14).
		# A conta é a MESMA de sempre, inclusive o 0.35 vertical; ela só deixou de
		# morar aqui dentro. Motivo: o dono trata "knockback horizontal" e
		# "knockback vertical" como duas mecânicas, e o vertical era uma constante
		# escondida no meio de uma expressão — invisível para quem quisesse
		# ajustar, e impossível de testar em separado.
		var kb: Vector3 = Knockback.calcular(
			global_position, body.global_position, knockback,
			Knockback.PADRAO, override_kb_dir)

		# PARALISIA: prende em vez de arremessar. O `is_frozen` é o mesmo sinal
		# que o gelo já usa, e o `_etapa_travamento` do Player o respeita.
		if paralisa > 0.0:
			kb = Vector3.ZERO
			body.set_meta("is_frozen", true)
			StatusFX.aplicar(body, StatusFX.CONGELADO, paralisa)
			var t := get_tree().create_timer(paralisa)
			t.timeout.connect(func():
				if is_instance_valid(body):
					body.set_meta("is_frozen", false))
		
		# DERRUBAR: Marca o corpo para que a recepção de dano toque a animação
		# de cair no chão durante o tempo especificado.
		if derruba > 0.0:
			body.set_meta("knockdown_dur", derruba)
			
		# ⚠️ NÃO chama `take_damage` direto — quem aplica é o `CombatResolver`, e é
		# ele que consulta o orçamento da conjuração antes de deixar o dano passar.
		# Chamar direto aqui reabriria exatamente o buraco que esta refatoração
		# fechou: hitboxes irmãs somando dano sem teto.
		#
		# O empurrão vai SEMPRE, mesmo quando o orçamento já acabou e o dano sai 0.
		# Dano e knockback são mecânicas separadas neste jogo — quem mata é o
		# buraco do mapa — e um golpe que parasse de empurrar ao esgotar o teto
		# perderia a sua função principal.
		antes_do_acerto.emit(body)
		CombatResolver.aplicar(body, damage, cast_id, teto, global_position, kb, hitstun,
			reserva, reservado)
		hit_landed.emit(body)
		# Crédito de kill: registra quem bateu por último em quem. Se o alvo cair
		# do mapa nos próximos segundos, a kill é de quem empurrou.
		var placar := get_tree().get_first_node_in_group("scoreboard")
		if placar and placar.has_method("register_hit"):
			placar.register_hit(body, caster)
		# Camera Feel no impacto: micro-pausa + flash quente + aberração cromática.
		var gf := get_node_or_null("/root/GameFlow")
		if gf and gf.has_method("hit_stop"):
			gf.hit_stop()
		var sfx := get_node_or_null("/root/ScreenFX")
		if sfx and sfx.has_method("flash"):
			sfx.flash(Color(1.0, 0.9, 0.6), 0.22)
			sfx.chromatic_pulse(0.5)


## Personagens nao servem de parede para uma explosao; cenario solido, sim.
## A iteracao evita que outro combatente esconda a parede que deve bloquear o
## alvo verdadeiro.
func _tem_linha_de_visao(body: Node3D) -> bool:
	var de := origem_linha_de_visao
	var ate := body.global_position + Vector3.UP * 0.35
	var excluidos: Array[RID] = []
	if caster is CollisionObject3D:
		excluidos.append((caster as CollisionObject3D).get_rid())
	for _i in 16:
		var par := PhysicsRayQueryParameters3D.create(de, ate)
		par.collision_mask = 15
		par.collide_with_areas = false
		par.collide_with_bodies = true
		par.exclude = excluidos
		var hit := get_world_3d().direct_space_state.intersect_ray(par)
		if hit.is_empty():
			return true
		var encontrado = hit.get("collider")
		if encontrado == body:
			return true
		if encontrado is CollisionObject3D and encontrado.has_method("take_damage"):
			excluidos.append((encontrado as CollisionObject3D).get_rid())
			continue
		return false
	return true
