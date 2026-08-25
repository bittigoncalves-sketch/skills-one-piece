class_name AutoDummy
extends TrainingDummy

var _target: Node3D = null
var _melee_passo: int = 0
var _melee_janela: float = 0.0
var _trava: float = 0.0

func _ready() -> void:
	super._ready()
	# Colorir o dummy de vermelho para diferenciar
	_recolor_model(Color(1.0, 0.2, 0.2))
	if _ap:
		_ap.active = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# ⚠️ A guarda do pai SAI CEDO no cliente, mas o `super` não interrompe ESTE
	# corpo — a IA abaixo continuaria correndo (2026-08-22). Sem repetir a guarda,
	# o boneco automático perseguiria alvos e atacaria no cliente, produzindo
	# golpes que o servidor nunca autorizou.
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	if _trava > 0.0:
		_trava = maxf(_trava - delta, 0.0)
	if _melee_janela > 0.0:
		_melee_janela -= delta
		if _melee_janela <= 0.0:
			_melee_passo = 0
	
	if has_meta("is_frozen") and get_meta("is_frozen"):
		return
	# ⚠️ CONTROLE DE MULTIDÃO TAMBÉM VALE PARA A IA (2026-08-23).
	#
	# O pai (`TrainingDummy._physics_process`) já sai cedo em `in_vortex`,
	# `in_kurouzu` e `in_black_hole` — mas `super._physics_process()` NÃO
	# interrompe este corpo, exatamente como a guarda de autoridade logo acima
	# já documenta. Só `is_frozen` era repetido aqui, então o boneco automático
	# perseguia e socava normalmente DENTRO do Black Hole da Yami.
	#
	# Medido antes da correção: com `in_black_hole = true` o AutoDummy chegava a
	# 3,10 m/s (a velocidade cheia de perseguição, 3,5) e escapava do poço,
	# enquanto o TrainingDummy ao lado ficava nos ~0,4 m/s da sucção. O C é
	# CONTROLE PURO (ver docs/frutas/yami_yami.md) e o inimigo que anda enquanto
	# preso apaga a única coisa que o golpe faz.
	#
	# A lista é a MESMA do pai de propósito: um estado que prende o boneco parado
	# tem de prender a IA junto, senão o alvo de teste mente sobre o golpe.
	if (has_meta("in_vortex") and get_meta("in_vortex")) \
			or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) \
			or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		return
	if has_meta("custom_pose") and get_meta("custom_pose") == "knockdown":
		return
	if health <= 0.0:
		return
		
	if not is_instance_valid(_target):
		_find_target()
		
	if is_instance_valid(_target):
		var to_target: Vector3 = _target.global_position - global_position
		var dist: float = to_target.length()
		
		# Move towards target
		if dist > 2.0:
			var dir = to_target.normalized()
			velocity.x = dir.x * 3.5
			velocity.z = dir.z * 3.5
			
			if _ap and _ap.current_animation != "run" and _ap.current_animation != "punching" and _ap.current_animation != "damage":
				_ap.play("run")
			
			# Face target
			if _model:
				_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
		else:
			velocity.x = 0
			velocity.z = 0
			
			if _ap and _ap.current_animation != "idle" and _ap.current_animation != "punching" and _ap.current_animation != "damage":
				_ap.play("idle")
				
			# Attack
			if _trava <= 0.0:
				_attack()
				
func _find_target() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			_target = node
			break

func _attack() -> void:
	# ⚠️ `self.get(...)` e não o identificador nu. O guarda `"x" in self` é uma
	# checagem de RUNTIME, mas `equipped_weapon` ainda precisa resolver em tempo
	# de PARSE — e o `AutoDummy` não declara essa propriedade (o `TrainingDummy`
	# também não). Escrito direto, o arquivo inteiro deixava de compilar, e como
	# o `Main.gd` carrega o dummy em toda partida, o erro entrava no log de
	# TODOS os testes e derrubava a suíte inteira.
	var w: String = str(self.get("equipped_weapon")) if "equipped_weapon" in self else ""
	var combo_len = Melee.COMBO_SWORD.size() if w == "sword" else Melee.COMBO.size()
	
	if _melee_janela <= 0.0 or _melee_passo >= combo_len:
		_melee_passo = 0
		
	var s := 1.0
	if "scale" in self:
		s = scale.y

	var g = Melee.passo(_melee_passo, w)
	# O `recuo` deixou de ser chave da tabela em 2026-08-15: virou conta derivada
	# da duração da animação (`Melee.recuo()`). O `+ 0,8` é intenção deste dummy e
	# fica — ele ataca de propósito mais devagar que um jogador, para dar tempo de
	# treinar esquiva. O `* s` saiu junto com o do jogador: o clipe toca no mesmo
	# `vel` seja qual for o porte, então a trava não tem por que crescer com ele.
	_trava = Melee.recuo(_melee_passo, w) + 0.8
	_melee_janela = Melee.JANELA
	
	var clipe = Melee.clipe(_melee_passo, w)
	if _rig and _rig.animador() and _rig.procedural():
		_rig.procedural().play_baked(clipe, float(g["vel"]) / s, float(g.get("inicio", 0.0)))
		
	var fwd = -global_transform.basis.z
	if _model:
		fwd = -_model.global_transform.basis.z
		
	Melee.golpear(get_tree().current_scene, self, _melee_passo, global_position + Vector3.UP * (1.0 * s), fwd)
	
	_melee_passo += 1

# A assinatura tem que bater com a do `TrainingDummy` — 4 parâmetros. Faltava o
# `hitstun`, e sem ele o GDScript recusa o arquivo inteiro ("doesn't match the
# parent"). Repassado ao `super` em vez de descartado: quem bate no dummy define
# quanto tempo ele fica atordoado, e engolir o valor aqui faria o dummy ignorar
# o hitstun de todo golpe do jogo.
func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO, hitstun: float = 0.0) -> void:
	super.take_damage(amount, from_pos, knockback, hitstun)
	if _ap and health > 0:
		_ap.play("damage")

func _recolor_model(c: Color) -> void:
	if not _model:
		return
	for child in _meshes(_model):
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c
			child.material_override = mat

