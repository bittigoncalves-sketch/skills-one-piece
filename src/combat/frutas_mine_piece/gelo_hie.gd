extends CharacterBody3D
## EntityIceBall (Mine Piece v14) com o Effect12Procedure que a cria: o golpe de gelo
## prende o alvo numa bola de gelo com vida própria. Enquanto o alvo estiver a menos de
## 1 bloco, a bola o segura no lugar (sem andar, golpear, voar ou usar técnica); some
## depois de 300 ticks, quando quebra ou quando o alvo escapa.
## Adaptações declaradas: o empurrão do golpe que congela é anulado (o Effect12 zera a
## velocidade do alvo; o empurrão que o RangeAttack aplica depois o tiraria do gelo no
## tick seguinte); quem está preso quebra o gelo com o clique (no mod, congelado só pode
## atacar a própria bola — LogicAttack), com o dano do soco simples.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const PASTA := "res://assets/mine_piece/frutas/hie/"
const META := "gelo_hie_mine_piece"

var dono: Node3D
var alvo: Node3D
var health := 30.0
var tamanho := 1.0          # atributo SIZE (blocos)
var _cnt1 := 0
var _cnt3 := 0
var _tempo := 0.0
var _parou_fisica := false
var _ponto := Vector3.ZERO


## Effect12Procedure: `atacante` é quem fere (o jogador ou a lança/pássaro), `cnt6` o
## dele. Devolve a bola criada, ou null se o alvo já estava preso.
static func congelar(atacante: Node3D, dono_do_golpe: Node3D, alvo_: Node3D, cnt6: float,
		altura_atacante_b: float, largura_atacante_b: float) -> Node:
	if not is_instance_valid(alvo_) or not alvo_.is_inside_tree():
		return null
	VfxFrutaMinePiece.som(alvo_, PASTA + "sons/hie_impacto.wav", alvo_.global_position, 0.25)
	if alvo_ is CharacterBody3D:
		(alvo_ as CharacterBody3D).velocity = Vector3.ZERO
	if alvo_.has_meta(META) and is_instance_valid(alvo_.get_meta(META)):
		return null
	var g = load("res://src/combat/frutas_mine_piece/gelo_hie.gd").new()
	g.dono = dono_do_golpe
	g.alvo = alvo_
	var cnt6_k := 1.0 + cnt6 * 0.1
	g.health = float(Balance.MINE_PIECE_HIE.vida_gelo) * cnt6_k
	var corpo := B.dimensoes_b(alvo_)
	g.tamanho = maxf(maxf((corpo.x + corpo.y) * 0.3, (altura_atacante_b + largura_atacante_b) * 0.15), 1.0)
	g.set_meta(B.DONO, dono_do_golpe.get_instance_id() if is_instance_valid(dono_do_golpe) else 0)
	alvo_.get_tree().current_scene.add_child(g)
	g.global_position = B.pe_de(alvo_)
	VfxFrutaMinePiece.som(alvo_, PASTA + "sons/hie_congelar.wav", alvo_.global_position, 1.0)
	return g


func _ready() -> void:
	add_to_group(AlvosDeGolpe.GRUPO)
	add_to_group("gelo_hie_mine_piece")
	collision_layer = 0
	collision_mask = 0
	# EntityIceBall: 2,5 × 2,5 blocos × SIZE.
	var lado := B.m(2.5 * tamanho)
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * lado
	var hb := Area3D.new()
	hb.name = "Hurtbox"
	hb.collision_layer = 4
	hb.collision_mask = 0
	add_child(hb)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.position.y = lado * 0.5
	hb.add_child(cs)
	var caminho := PASTA + "mp_bola_de_gelo.glb"
	if ResourceLoader.exists(caminho):
		var v: Node3D = (load(caminho) as PackedScene).instantiate()
		add_child(v)
		VfxFrutaMinePiece.render_do_mod(v)
		v.scale = Vector3.ONE * B.METROS_POR_BLOCO * tamanho
	health *= B.DANO_DA_ARENA_POR_DANO_DO_MOD * PerfilDeFrutas.ESCALA_DO_MOD
	_prender(true)


func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * B.m(2.5 * tamanho) * 0.5


func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
	if not _servidor() or (is_instance_valid(dono) and int(get_meta("autor_do_dano", 0)) == dono.get_instance_id()):
		return
	health -= dano
	if health <= 0.0:
		_sumir()


func _servidor() -> bool:
	var mp := multiplayer if is_inside_tree() else null
	return mp == null or not mp.has_multiplayer_peer() or mp.is_server()


## Quem está preso só pode atacar a própria bola (LogicAttack com FROZEN).
func _unhandled_input(event: InputEvent) -> void:
	var jogador := alvo as Player
	if jogador == null or not jogador._is_authority or not _servidor():
		return
	var botao := event as InputEventMouseButton
	if botao != null and botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT:
		set_meta("autor_do_dano", jogador.get_instance_id())
		take_damage(float(Balance.MINE_PIECE_LUTA.soco.dano) * PerfilDeFrutas.ESCALA_DO_MOD)


func _physics_process(delta: float) -> void:
	if not _servidor():
		return
	_tempo += delta
	while _tempo >= B.TICK and not is_queued_for_deletion():
		_tempo -= B.TICK
		_passo()


func _passo() -> void:
	_cnt1 += 1
	if _cnt1 == 1:
		_ponto = global_position   # a posição chega depois do _ready (add_child antes)
	if _cnt1 > 1:
		_cnt3 += 1
		if _cnt3 > int(Balance.MINE_PIECE_HIE.gelo_ticks):
			_sumir()
			return
	if not is_instance_valid(alvo) or not alvo.is_inside_tree() or float(alvo.get("health") if alvo.get("health") != null else 1.0) <= 0.0:
		_sumir()
		return
	# GetDistanceIterator < 1 bloco: segura; senão o alvo escapou e a bola some.
	if B.pe_de(alvo).distance_to(_ponto) >= B.METROS_POR_BLOCO:
		_sumir()
		return
	alvo.global_position += _ponto - B.pe_de(alvo)
	if alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = Vector3.ZERO
	StatusFX.aplicar(alvo, StatusFX.CONGELADO, B.TICK * 2.0)


func _prender(ligar: bool) -> void:
	if not is_instance_valid(alvo):
		return
	if ligar:
		alvo.set_meta(META, self)
		alvo.set_meta("is_frozen", true)
		if not alvo.is_in_group("player") and alvo.is_physics_processing():
			alvo.set_physics_process(false)
			_parou_fisica = true
	elif alvo.has_meta(META) and alvo.get_meta(META) == self:
		alvo.remove_meta(META)
		alvo.set_meta("is_frozen", false)
		StatusFX.remover(alvo, StatusFX.CONGELADO)
		if _parou_fisica:
			alvo.set_physics_process(true)


func _sumir() -> void:
	if is_queued_for_deletion():
		return
	_prender(false)
	VfxFrutaMinePiece.particulas(self, PASTA + "particle_ice.png", 12, centro_do_corpo(), 12,
		Vector3.ONE * B.m(tamanho), 2.0)
	VfxFrutaMinePiece.som(self, PASTA + "sons/hie_quebrar.wav", centro_do_corpo(), 0.7)
	queue_free()


func _exit_tree() -> void:
	_prender(false)
