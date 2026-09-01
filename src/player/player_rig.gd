class_name PlayerRig
extends Node
# ============================================================================
#  PLAYER RIG — o CORPO VISÍVEL do jogador: montar, medir, vestir.
#
#  Fase 3 de docs/ARQUITETURA_PLAYER.md. O corte 2 do relatório: 248 linhas,
#  sem RPC nenhum, e o `_setup_character_model` sozinho tinha 124.
#
#  ------------------------------------------------------- A FRONTEIRA EXATA
#  Medição que decidiu o desenho: **TODA escrita** nestes campos acontecia
#  dentro do bloco de construção (Player.gd 977–1149). Nenhuma fora. Ou seja,
#  o domínio já era naturalmente "um construtor e muitos leitores" — só não
#  tinha nome.
#
#      O RIG CONSTRÓI.  O PLAYER USA.
#
#  O rig é dono do CICLO DE VIDA: criar o modelo, medir e assentar no chão,
#  pendurar pistolas e o arsenal da Buki, ligar o animador procedural, soltar
#  tudo na troca de personagem. Quem usa por quadro (facing, pose, visibilidade,
#  mira) continua no Player, que lê pelos getters abaixo.
#
#  ------------------------------------- POR QUE ELE NÃO É O PAI DOS NÓS
#  Este componente é um `Node` puro e adiciona os filhos ao DONO, não a si
#  mesmo — a árvore fica **idêntica** à de antes. Foi decisão de risco, não
#  preguiça:
#
#   • `_char_model.rotation.y` / `.position.y` são escritos direto pelo facing
#     e pelo fit. Um nó intermediário entra na conta das transformações.
#   • `_animator.animation_player.root_node = NodePath("..")` resolve pelo PAI.
#     Com o rig no meio, ".." passaria a ser o rig e não o Player.
#
#  **Gatilho para revisitar:** se o rig algum dia precisar de transformação
#  própria (ex.: inclinar o corpo inteiro sem mexer no facing), aí vale pagar
#  o custo de virar `Node3D` e reapontar o `root_node`.
#
#  A POLÍTICA de elenco (quem pode ser carregado) fica no Player: é regra de
#  jogo, não de montagem. O rig monta o que mandarem.
# ============================================================================

# Altura ÚNICA de TODOS os personagens jogáveis (voxel + skinnado) -> todos do
# mesmo tamanho. Basta mudar este número p/ deixar todos maiores/menores.
const CHAR_TARGET_H := 1.5
const MODEL_TARGET_H := CHAR_TARGET_H    # voxel
const SKINNED_TARGET_H := CHAR_TARGET_H  # skinnado (Meshy)
const FEET_Y := -0.8                     # fundo da colisão = chão

var _dono: Node3D = null            # o Player: pai real dos nós (ver cabeçalho)

var character_id: String = "base"
var _animator: CharacterAnimator = null
var _char_model: Node3D = null
var _proc_anim: ProceduralAnimator = null   # animação procedural do rig em runtime
var _skel_anim: SkeletalAnimator = null     # animador ESQUELETAL (skinnados)
var _is_skinned: bool = false               # o personagem atual é skinnado?
var _head_node: Node3D = null               # cabeça do modelo (âncora do fôlego)
var _pistols: Array = []                    # pistolas nas DUAS mãos
var _pistol_holster: Node3D = null          # suporte temporário na cintura (saque da Mera Z)
var _pistols_in_draw: bool = false          # impede o Player de esconder a arma entre carga e disparo
var _buki_armas: Dictionary = {}            # slot -> Node3D pré-construído (oculto)
var _buki_pivot: Node3D = null              # pivô do canhão-corpo (X)
var item_handle: Node3D = null              # ponto de ancoragem para itens segurados na mão direita

func montar_em(dono: Node3D) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
# O Player expõe estes valores como propriedades que encaminham para cá, então
# os ~42 pontos de uso e o `caster.get("_char_model")` do BukiFX continuam
# funcionando sem saber que o dono mudou. Um dono só, muitos leitores.
func modelo() -> Node3D:            return _char_model
func animador() -> CharacterAnimator: return _animator
func procedural() -> ProceduralAnimator: return _proc_anim
func esqueletal() -> SkeletalAnimator: return _skel_anim
func cabeca() -> Node3D:            return _head_node
func pistolas() -> Array:           return _pistols
func pistolas_em_saque() -> bool:    return _pistols_in_draw
func armas_buki() -> Dictionary:    return _buki_armas
func pivo_buki() -> Node3D:         return _buki_pivot
func skinnado() -> bool:            return _is_skinned

# ----------------------------------------------------------------- montagem
# Troca o personagem inteiro. Recebe o id JÁ VALIDADO pelo Player — a trava de
# elenco é política de jogo e mora lá.
func montar(cid: String) -> void:
	if _dono == null:
		push_error("[PlayerRig] montar() sem dono — chame montar_em(player) antes")
		return

	if _char_model:
		_char_model.queue_free()
	if _animator:
		_animator.queue_free()

	character_id = cid
	# limpa estado do modelo anterior
	if _skel_anim:
		_skel_anim.queue_free()
		_skel_anim = null
	if _proc_anim:
		_proc_anim.queue_free()
		_proc_anim = null
	_pistols = []
	_pistol_holster = null
	_pistols_in_draw = false
	_buki_armas = {}          # morrem junto com o _char_model; o pivô do X é solto abaixo
	_is_skinned = false

	var char_data := CharacterBuilder.build_character(cid)
	_char_model = char_data["node"]
	_is_skinned = char_data.get("skinned", false)   # antes do fit (afeta a escala)
	_dono.add_child(_char_model)
	_fit_model_to_body()   # normaliza tamanho e assenta os pés no chão

	# --- PERSONAGEM SKINNADO (Skeleton3D, ex.: Meshy AI) ---
	# RIG ÚNICO: o esqueleto do Meshy é mapeado nos 13 papéis do rig A pelo
	# SkeletonDriver (via BodyScanner), então ele usa o MESMO ProceduralAnimator
	# e os MESMOS clipes do Mixamo que os personagens voxel. O SkeletalAnimator
	# e os walks nativos por modelo ficaram obsoletos.
	if _is_skinned:
		_animator = null   # skinnado não usa CharacterAnimator (rig por-nós)
		# DIREÇÃO: modelos Meshy nascem olhando +Z (pra câmera); a convenção do jogo é
		# FRENTE = -Z. Giro a Armature 180° pra alinhar (o facing gira o _char_model).
		var arm := _char_model.find_child("Armature", true, false)
		if arm is Node3D:
			(arm as Node3D).rotation.y += PI
		# O AnimationPlayer do próprio modelo brigaria com o driver pelos ossos.
		var model_ap: AnimationPlayer = char_data.get("anim_player")
		if model_ap:
			model_ap.active = false
		_setup_procedural_anim(cid)
		_head_node = _char_model.find_child("Head", true, false) as Node3D
		# A pistola TAMBÉM vale no skinnado. Ela ficava de fora por acidente: o
		# `return` logo abaixo pulava a chamada que está depois deste bloco, então
		# nenhum personagem skinnado nunca teve pistola no golpe Z.
		#
		# Isso só passou a funcionar agora porque o `_attach_pistol` acha o membro
		# por `find_child("ForeArm_R")`, e até hoje os proxies do rig se chamavam
		# `RoleProxy_ForeArm_R` (ver docs/erros.md, 2026-08-10). Consertar um sem
		# o outro não adiantaria nada.
		#
		# ⚠️ O proxy GIRA com a animação mas não TRANSLADA — a pistola nasce na
		# posição de repouso da mão e acompanha a rotação, não o deslocamento do
		# osso. Mesma limitação das armas da Buki Buki.
		_attach_pistol(_char_model)
		_attach_buki_arsenal(_char_model)   # arsenal da Buki (oculto até empunhar)
		_attach_item_handle(_char_model)
		return

	_attach_pistol(_char_model)   # pistola na mão direita (oculta até a rajada Z)
	_attach_item_handle(_char_model)
	_attach_buki_arsenal(_char_model)   # arsenal da Buki (oculto até empunhar)

	# Marcador Visual de COSTAS: Mochila Dourada Emissiva em z = -0.35
	var back_marker := MeshInstance3D.new()
	back_marker.name = "BackMarkerVisual"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.42, 0.52, 0.18)
	back_marker.mesh = marker_mesh
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.8, 0.1)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(1.0, 0.75, 0.1)
	marker_mat.emission_energy_multiplier = 2.5
	back_marker.material_override = marker_mat
	back_marker.position = Vector3(0, 0.1, 0.35)
	_char_model.add_child(back_marker)

	# Marcador Visual de FRENTE (PEITO): Insígnia Vermelha no Peito em z = -0.35
	var chest_marker := MeshInstance3D.new()
	chest_marker.name = "ChestMarkerFront"
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.35, 0.35, 0.15)
	chest_marker.mesh = chest_mesh
	var chest_mat := StandardMaterial3D.new()
	chest_mat.albedo_color = Color(1.0, 0.15, 0.15)
	chest_mat.emission_enabled = true
	chest_mat.emission = Color(1.0, 0.2, 0.1)
	chest_mat.emission_energy_multiplier = 3.0
	chest_marker.material_override = chest_mat
	chest_marker.position = Vector3(0, 0.15, -0.35)
	_char_model.add_child(chest_marker)

	_animator = CharacterAnimator.new()
	_animator.character_id = cid
	_animator.animation_player = char_data["anim_player"]
	_dono.add_child(_animator)
	# Os paths procedurais das animações são relativos ao CharacterRoot.
	# Deixamos isso explícito para não depender do valor padrão do Godot.
	if _animator.animation_player:
		_animator.animation_player.root_node = NodePath("..")
		# Desliga o AnimationPlayer antigo: ele mira nomes de nós antigos e
		# brigaria com a animação procedural que dirige o rig novo diretamente.
		_animator.animation_player.active = false

	_setup_procedural_anim(cid)

	# Fôlego (VFX): cacheia a cabeça (âncora da boca). O componente do fôlego em
	# si é do Player — ele vive além do modelo e o Player o reaproveita entre
	# trocas de personagem.
	_head_node = _char_model.find_child("Head", true, false) as Node3D

	print("🎭 Modelo 3D Voxel Carregado: ", cid.capitalize())

# Animação PROCEDURAL: mede o corpo (BodyScanner) e dirige o rig em runtime.
# Serve os DOIS tipos de personagem — o BodyScanner resolve os 13 papéis em nós
# (voxel) ou em ossos via SkeletonDriver (skinnado), e devolve o mesmo perfil.
func _setup_procedural_anim(cid: String) -> void:
	if _proc_anim:
		_proc_anim.queue_free()
	_proc_anim = ProceduralAnimator.new()
	_dono.add_child(_proc_anim)
	_proc_anim.setup(BodyScanner.scan(_char_model))
	# Corpo girado 180° em Y: os offsets são autorados p/ FRENTE = -Z e precisam
	# ser espelhados. Vale só pro SkinPivot do Buggy — no SKINNADO a basis do
	# SkeletonDriver já inclui o giro da Armature, então marcar aqui aplicaria a
	# correção DUAS vezes e os membros balançariam ao contrário.
	if not _is_skinned and cid == "buggy" and _char_model.has_node("SkinPivot"):
		_proc_anim.is_backwards = true

# Normaliza o modelo importado (que vem grande) para a altura do jogador e
# assenta os PÉS no fundo da colisão (senão o boneco fica gigante e flutuando).
func _fit_model_to_body() -> void:
	if _char_model == null:
		return
	var ab := PlayerModelKit.skeleton_aabb(_char_model) if _is_skinned else PlayerModelKit.model_aabb(_char_model)
	# Altura-alvo: skinnado (Meshy) é mais encorpado -> um pouco menor p/ casar com o mundo.
	var target_h := SKINNED_TARGET_H if _is_skinned else MODEL_TARGET_H
	if character_id == "blackbeard":
		target_h *= 1.5   # Barba Negra tem 1.5 de tamanho em comparação aos demais
	var ky := 1.0
	if ab.size.y > 0.01:
		ky = target_h / ab.size.y
	# Voxel: engrossa o eixo Z (1.85x). SKINNADO (Skeleton3D): escala UNIFORME —
	# escala não-uniforme num skeleton corrompe o skinning (transform NaN -> tela cinza).
	_char_model.scale = Vector3(ky, ky, ky)
	if not _is_skinned:
		PlayerModelKit.bake_depth(_char_model, 1.85)
		
	# pés (base da AABB) no fundo da colisão
	_char_model.position.y = FEET_Y - ky * ab.position.y

# Cria as duas pistolas da Mera Z. Elas são as MESMAS instâncias que aparecem
# durante o saque e que definem a origem do projétil: não há arma visual separada
# do cano usado no combate.
func _attach_pistol(model: Node3D) -> void:
	_pistols = []
	_pistols_in_draw = false
	if model == null:
		return
	_pistol_holster = Node3D.new()
	_pistol_holster.name = "MeraPistolHolsters"
	model.add_child(_pistol_holster)
	for side in ["ForeArm_L", "ForeArm_R"]:
		var arm := model.find_child(side, true, false)
		if not (arm is Node3D):
			continue
		var gun := PlayerModelKit.build_mera_pistol()
		gun.name = "MeraPistol_" + side
		gun.position = Vector3(0, -0.36, 0.02)   # ponta do antebraço (mão)
		gun.visible = false
		(arm as Node3D).add_child(gun)
		_pistols.append(gun)

# Mera Z começa com as armas visíveis nos coldres. A animação de carga leva as
# mãos até a cintura; no fim, `empunhar_pistolas_mera` as transfere para as mãos.
# O coldre é filho do modelo, não do torso, para também funcionar no rig skinnado.
func guardar_pistolas_mera() -> void:
	if _pistol_holster == null:
		return
	_pistols_in_draw = true
	for i in _pistols.size():
		var gun := _pistols[i] as Node3D
		if not is_instance_valid(gun):
			continue
		if gun.get_parent() != _pistol_holster:
			gun.reparent(_pistol_holster, false)
		var side := -1.0 if i == 0 else 1.0
		gun.position = Vector3(0.27 * side, 0.24, 0.13)
		gun.rotation_degrees = Vector3(0.0, 0.0, -10.0 * side)
		gun.visible = true

# Final da carga: encaixa cada pistola na mão correspondente já apontada pela
# pose de mira. O cano continua no eixo -Y local, que é o eixo lido por Mira.
func empunhar_pistolas_mera() -> void:
	if _char_model == null:
		return
	_pistols_in_draw = true
	for i in _pistols.size():
		var gun := _pistols[i] as Node3D
		if not is_instance_valid(gun):
			continue
		var side_name := "ForeArm_L" if i == 0 else "ForeArm_R"
		var arm := _char_model.find_child(side_name, true, false) as Node3D
		if arm == null:
			continue
		if gun.get_parent() != arm:
			gun.reparent(arm, false)
		gun.position = Vector3(0, -0.36, 0.02)
		gun.rotation = Vector3.ZERO
		gun.visible = true

func esconder_pistolas_mera() -> void:
	_pistols_in_draw = false
	for gun in _pistols:
		if is_instance_valid(gun):
			gun.visible = false

# Ponto de ancoragem para itens (como a espada). No voxel vai no braço,
# no esqueleto usamos BoneAttachment3D para herdar posição E rotação.
func _attach_item_handle(model: Node3D) -> void:
	if model == null:
		return
	if _is_skinned:
		var skel := BodyScanner._find_skeleton(model)
		if skel:
			var ba := BoneAttachment3D.new()
			ba.bone_name = "ForeArm_R"
			skel.add_child(ba)
			item_handle = Node3D.new()
			item_handle.position = Vector3(0, 0.36, 0.0) # Ponta do osso
			ba.add_child(item_handle)
	else:
		var arm := model.find_child("ForeArm_R", true, false)
		if arm is Node3D:
			item_handle = Node3D.new()
			item_handle.position = Vector3(0, -0.36, 0.02)
			arm.add_child(item_handle)

# ---------------------------------------------------------------- BUKI BUKI ---
# Constrói as QUATRO armas da fruta UMA VEZ, ocultas, junto com o personagem —
# exatamente como a pistola acima. Empunhar depois é só ligar a visibilidade.
#
# ⚠️ Por que não criar a arma na hora do saque: nó criado no golpe e mantido
# vivo entre golpes é indistinguível de VAZAMENTO para a auditoria
# (tools/dev_tests/test_frutas.gd conta nós antes/depois) — e, pior, cada troca
# de arma deixaria lixo na cena se um `queue_free` escapasse. Pré-construir
# custa 3 instâncias de .glb por personagem e elimina a classe de bug inteira.
#
# FRONTEIRA COM A BUKI: o rig MONTA as armas; quem decide QUAL aparece é o
# combate (`_buki_mostrar_arma`, no Player). Era o conflito que o relatório
# apontou — `_buki_armas` e `_buki_visual` tinham dois donos. Agora `_buki_armas`
# é do rig (existe enquanto o modelo existir) e `_buki_visual` é do combate.
func _attach_buki_arsenal(model: Node3D) -> void:
	for n in _buki_armas.values():
		if is_instance_valid(n):
			(n as Node).queue_free()
	_buki_armas = {}
	if is_instance_valid(_buki_pivot):
		_buki_pivot.queue_free()
	_buki_pivot = null
	if model == null:
		return
	# O canhão do X não mora no braço: mora num pivô do CORPO, que gira com a
	# mira (o jogador inteiro virou o canhão).
	_buki_pivot = Node3D.new()
	_buki_pivot.name = "BukiPivot"
	_buki_pivot.position = Vector3(0, -0.15, 0)
	_dono.add_child(_buki_pivot)
	var braco := model.find_child("ForeArm_R", true, false) as Node3D
	for slot in BukiFX.SLOTS:
		var arma := BukiFX.arma_do_slot(slot)
		if arma == null:
			continue
		var papel := BukiFX.papel_do_slot(slot)
		var pai: Node3D = _buki_pivot if papel == "" else braco
		if pai == null:
			arma.free()          # rig sem ForeArm_R: essa arma simplesmente não existe
			continue
		arma.visible = false
		pai.add_child(arma)
		_buki_armas[slot] = arma
