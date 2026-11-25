extends RefCounted
## Os clipes vêm dos .blend/GLB. Aqui ficam blend, loops e relógio de gameplay.
const LOOPS := ["idle", "dormindo", "nadando_walk", "nadando_run", "nadando_submerso", "comendo", "repouso",
	"boiando", "andando_terra", "correndo_terra"]
## Clipes com o corpo deitado (postura de foca, 08/10/2026): dormir e nadar. Os outros
## ficam em pé — inclusive andar em terra ("as bestas devem ficar eretas quando andam
## em terra como antes", correção do dono).
const DEITADOS := ["dormindo", "nadando_walk", "nadando_run", "mergulhando", "nadando_submerso",
	"emergindo"]
## Transição: dentro da mesma postura é curta; deitar ou levantar um corpo de 14 m em
## 0,2 s parecia um estalo.
const TRANSICAO := 0.25
const TRANSICAO_DE_POSTURA := 0.9
## Cabeça estabilizada (08/10/2026, pedido do dono: "adicionar movimentação à cabeça
## quando estiver nadando e dormindo para sempre estar olhando para frente, na
## horizontal"): nesses clipes, depois da animação, a cabeça é girada para olhar à
## frente do CORPO (o rumo da besta), nivelada — compensa a ondulação do pescoço, o
## nariz do mergulho e a inclinação na curva. Entra e sai no tempo da troca de postura.
const NIVELA := DEITADOS
var player: AnimationPlayer
var rig: Skeleton3D
## Nó cujo rumo a cabeça segue (a besta). Sem ele, não nivela.
var corpo: Node3D
var nivelar := 0.0              # peso de agora (0 = clipe puro, 1 = cabeça nivelada)
var _cabeca := -1
var _cabeca_no_corpo := Basis() # a cabeça no repouso, vista do corpo (olhando à frente)
var _pronto := false
var boca_local := Vector3(0, 1.7, -0.45)
var atual := ""
var tempo := 0.0


func montar(modelo: Node3D) -> void:
	var players := modelo.find_children("*", "AnimationPlayer", true, false)
	var rigs := modelo.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or rigs.is_empty():
		push_error("Besta do mar sem rig/clipes: " + str(modelo))
		return
	player = players[0]
	rig = rigs[0]
	_cabeca = rig.find_bone("cabeca")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for nome in player.get_animation_list():
		# Recursos importados são compartilhados: a configuração não deve vazar ao editor.
		var lib := player.get_animation_library(player.find_animation_library(player.get_animation(nome)))
		var anim := player.get_animation(nome).duplicate() as Animation
		anim.loop_mode = Animation.LOOP_LINEAR if nome in LOOPS else Animation.LOOP_NONE
		lib = lib.duplicate()
		var biblioteca := player.find_animation_library(player.get_animation(nome))
		lib.remove_animation(nome.get_slice("/", 1) if nome.contains("/") else nome)
		lib.add_animation(nome.get_slice("/", 1) if nome.contains("/") else nome, anim)
		player.remove_animation_library(biblioteca)
		player.add_animation_library(biblioteca, lib)
	mudar("idle")


func mudar(nome: String) -> void:
	if nome == atual or player == null:
		return
	if not player.has_animation(nome):
		push_error("Clipe marinho ausente: " + nome)
		return
	var troca_postura := (atual in DEITADOS) != (nome in DEITADOS)
	atual = nome
	tempo = 0.0
	player.play(nome, TRANSICAO_DE_POSTURA if troca_postura else TRANSICAO)
	player.advance(0.0)


func avancar(delta: float) -> void:
	if player == null:
		return
	tempo += delta
	player.advance(delta)
	nivelar = move_toward(nivelar, 1.0 if atual in NIVELA else 0.0, delta / TRANSICAO_DE_POSTURA)
	if nivelar > 0.001:
		_nivelar_cabeca()


## Gira a cabeça (depois do clipe) para a orientação que ela tem no repouso — olhando à
## frente, nivelada — em relação ao corpo, misturando pelo peso `nivelar`.
func _nivelar_cabeca() -> void:
	if corpo == null or _cabeca < 0 or not rig.is_inside_tree() or not corpo.is_inside_tree():
		return
	var rel := (corpo.global_transform.affine_inverse() * rig.global_transform).basis.orthonormalized()
	if not _pronto:
		# Primeira vez (sem inclinação na curva ainda): a cabeça de repouso no corpo.
		_cabeca_no_corpo = rel * rig.get_bone_global_rest(_cabeca).basis.orthonormalized()
		_pronto = true
	rig.force_update_all_bone_transforms()
	var querida := rel.inverse() * _cabeca_no_corpo             # no espaço do esqueleto
	var pai := rig.get_bone_parent(_cabeca)
	var pai_global := rig.get_bone_global_pose(pai).basis.orthonormalized() if pai >= 0 else Basis()
	var local := (pai_global.inverse() * querida).get_rotation_quaternion()
	var agora := rig.get_bone_pose_rotation(_cabeca)
	rig.set_bone_pose_rotation(_cabeca, agora.slerp(local, nivelar))


## Para medir: frente e "cima" da cabeça no mundo (como no repouso: frente = −Z do
## corpo, cima = +Y). Uma cabeça nivelada tem frente horizontal e cima vertical.
func eixos_da_cabeca() -> Basis:
	if not _pronto or corpo == null:
		return Basis()
	rig.force_update_all_bone_transforms()
	var rel := (corpo.global_transform.affine_inverse() * rig.global_transform).basis.orthonormalized()
	var no_corpo := rel * rig.get_bone_global_pose(_cabeca).basis.orthonormalized()
	return corpo.global_basis.orthonormalized() * no_corpo * _cabeca_no_corpo.inverse()


func deitada() -> bool:
	return atual in DEITADOS


func duracao() -> float:
	return player.get_animation(atual).length if player != null and not atual.is_empty() else 1.0


func boca() -> Vector3:
	if rig == null:
		return Vector3.ZERO
	var osso := rig.find_bone("cabeca")
	rig.force_update_all_bone_transforms()
	return rig.global_transform * (rig.get_bone_global_pose(osso) * boca_local)
