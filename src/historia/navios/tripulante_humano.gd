class_name TripulanteHumano
extends Node3D
# ============================================================================
#  TRIPULANTE HUMANO A BORDO (15/10/2026) — o personagem do elenco parado no convés.
#
#  O mesmo corpo dos NPCs da ilha (`PlayerRig` com o rig do `CatalogoDeTripulantes`), sem
#  colisão nem lógica: a função dele (a Nami aponta o rumo) mora no `comando.gd`. Fixo no
#  convés, filho do barco, então vai e volta com ele.
# ============================================================================

const ALTURA_DO_COZINHEIRO := 1.75

var tripulante := ""
var _rig: PlayerRig
var _clipes: AnimationPlayer       # os cozinheiros: clipes `descanso` / `caminhada` do GLB
var _velocidade := 0.0             # m/s do passeio (a animação segue)
var _acao := 0.0


## `bib` só é preciso para os tripulantes que vêm da biblioteca do mapa (os cozinheiros).
func montar(a_tripulante: String, bib: BibliotecaDeModelos = null, recrutado: Dictionary = {}) -> void:
	tripulante = a_tripulante
	name = "Tripulante_" + a_tripulante
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	add_child(corpo)
	var da_biblioteca := str(recrutado.get("modelo", "")) if not recrutado.is_empty() else CatalogoDeTripulantes.modelo_da_biblioteca(a_tripulante)
	if not da_biblioteca.is_empty():
		# O pé do modelo fica em y=0 do corpo (já ajustado ao chão).
		var modelo: Node3D = bib.instanciar(da_biblioteca) if bib != null and bib.tem(da_biblioteca) else null
		if modelo != null:
			corpo.add_child(Tripulacao.ajustar_ao_chao(modelo, ALTURA_DO_COZINHEIRO))
			var players := modelo.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				_clipes = players[0] as AnimationPlayer
				_tocar("descanso")
	else:
		corpo.position = Vector3.UP * NpcDaIlha.CENTRO_DO_CORPO
		_rig = PlayerRig.new()
		_rig.name = "Rig"
		corpo.add_child(_rig)
		_rig.montar_em(corpo)
		_rig.montar(str(CatalogoDeTripulantes.TRIPULANTES[a_tripulante]["rig"]))
	var rotulo := Label3D.new()
	rotulo.name = "Nome"
	rotulo.text = str(recrutado.get("nome", a_tripulante)) if not recrutado.is_empty() else CatalogoDeTripulantes.nome(a_tripulante)
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 40
	rotulo.pixel_size = 0.0035
	rotulo.outline_size = 10
	rotulo.modulate = Color.LIGHT_GRAY if not recrutado.is_empty() else CatalogoDeTripulantes.cor_da_raridade(CatalogoDeTripulantes.raridade(a_tripulante))
	rotulo.position = Vector3.UP * (NpcDaIlha.ALTURA + 0.35)
	add_child(rotulo)
	if not recrutado.is_empty():
		max_health = maxf(1, float(recrutado.get("vida", 100)))
		health = max_health


## O nó do corpo (gira e inclina com o personagem).
func corpo() -> Node3D:
	return get_node_or_null("Corpo") as Node3D


## A mão direita do rig — onde a pistola do Barba Negra se pendura.
func mao() -> Node3D:
	return _rig.item_handle if _rig != null else null


func esqueleto() -> Skeleton3D:
	if _rig == null or _rig.modelo() == null:
		return null
	var achados := _rig.modelo().find_children("*", "Skeleton3D", true, false)
	return achados[0] as Skeleton3D if not achados.is_empty() else null


## Vira o corpo para `direcao` (plano XZ) com a suavidade de `peso` (0..1). O personagem olha −Z.
func virar_para(direcao: Vector3, peso := 1.0) -> void:
	var c := corpo()
	if c == null or Vector2(direcao.x, direcao.z).length_squared() < 0.0001:
		return
	var alvo := atan2(-direcao.x, -direcao.z) - global_rotation.y
	c.rotation.y = lerp_angle(c.rotation.y, alvo, clampf(peso, 0.0, 1.0))


## Velocidade do passeio (m/s): o rig anda no ritmo dela e o cozinheiro troca o clipe.
func definir_velocidade(v: float) -> void:
	_velocidade = v
	if _clipes != null and _acao <= 0:
		_tocar("caminhada" if v > 0.05 else "descanso")


func _process(delta: float) -> void:
	_acao = maxf(0, _acao - delta)
	var animador := _rig.procedural() if _rig != null else null
	if animador != null:
		animador.update(Vector3(0, 0, -_velocidade), true, false, delta, 0.0)


func _tocar(clipe: String) -> void:
	if _clipes != null and not _clipes.has_animation(clipe):
		var termos := ["walk", "run", "caminhada"] if clipe == "caminhada" else ["idle", "stand", "descanso"]
		for nome in _clipes.get_animation_list():
			if termos.any(func(t: String): return t in nome.to_lower()):
				clipe = nome
				break
	if _clipes != null and _clipes.has_animation(clipe) and _clipes.current_animation != clipe:
		_clipes.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR
		_clipes.play(clipe)

# Só o corpo de bordo recebe isto; o visual filho do aliado terrestre não vira outro alvo.
var health := 100.0
var max_health := 100.0
var sistema_tripulacao: Node
var membro_id := ""
func ligar_sobrevivencia(sistema: Node, id: String) -> void:
	sistema_tripulacao = sistema
	membro_id = id
	set_meta("membro_tripulacao", id)
	add_to_group("alvo_de_besta")
	if get_node_or_null("AlvoTripulante") != null: return
	var hb := StaticBody3D.new()
	hb.name = "AlvoTripulante"
	hb.collision_layer = HurtboxDeCombate.CAMADA
	hb.collision_mask = 0
	hb.set_meta("hurtbox_de", self)
	var c := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.height = 1.8
	forma.radius = 0.35
	c.shape = forma
	c.position.y = 0.9
	hb.add_child(c)
	add_child(hb)

func take_damage(amount: float, _de := Vector3.ZERO, _kb := Vector3.ZERO, _stun := 0.0) -> void:
	if bool(get_meta("dano_do_jogador", false)): return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	if health <= 0 or amount <= 0 or not is_instance_valid(sistema_tripulacao): return
	if sistema_tripulacao.proteger(self, amount): return
	health = maxf(0, health - amount)
	if health <= 0:
		sistema_tripulacao.registrar_morte(membro_id)
		queue_free()

func golpear() -> void:
	if _rig != null and _rig.procedural() != null:
		_rig.procedural().play_baked(load("res://assets/animations/boxing.res") as Animation)
	elif _clipes != null:
		for clipe in _clipes.get_animation_list():
			if "attack" in clipe.to_lower() or "ataque" in clipe.to_lower():
				_clipes.get_animation(clipe).loop_mode = Animation.LOOP_NONE
				_clipes.play(clipe)
				_acao = minf(1.2, _clipes.get_animation(clipe).length)
				break
