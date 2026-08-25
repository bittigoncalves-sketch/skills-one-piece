class_name SkeletonDriver
extends Node
# Ponte entre o rig LÓGICO (13 papéis, nós-proxy) e um Skeleton3D real.
#
# O jogo tem UM esqueleto só — os 13 papéis do rig A (BodyScanner.ROLES). Os
# personagens voxel (.scn/.glb) já nascem com nós que têm esses nomes. Os modelos
# SKINNADOS (Meshy AI) são Skeleton3D, então não têm nós pra girar.
#
# Solução: criar 13 Node3D "proxy" (um por papel) e deixar o ProceduralAnimator
# girar os proxies exatamente como faz num personagem voxel — ele nem sabe que o
# personagem é skinnado. Depois, todo frame, este driver COPIA a rotação de cada
# proxy pro osso correspondente. Assim as 29 animações do Mixamo e toda a
# locomoção/parkour procedural funcionam igual nos dois tipos de personagem.
#
# MATEMÁTICA (a parte que é fácil errar):
#
# O que o animador escreve num proxy é a rotação LOCAL de uma junta do rig voxel,
# cujas juntas de repouso são alinhadas com os eixos do personagem. Num esqueleto
# de verdade nada disso vale: cada osso tem uma orientação de repouso própria
# (aponta ao longo do osso) e o esqueleto inteiro pode estar num espaço girado.
# Então o offset NÃO pode ser aplicado direto no osso. O caminho correto é:
#
#  1. Acumular o delta pela hierarquia do RIG (não a dos ossos), montando a
#     rotação de cada papel no espaço do JOGO:  W[papel] = W[pai] * offset.
#  2. Converter esse delta pro espaço do ESQUELETO por conjugação:
#     d_skel = A⁻¹ · W · A, onde A é a basis que leva do espaço do esqueleto
#     pro do personagem. Os modelos Meshy vêm **Z-up** (altura no Z, com a
#     Armature girada −90° em X pra corrigir) — sem esta conjugação os membros
#     giram nos eixos errados e colapsam pra dentro do corpo.
#  3. Compor com o repouso GLOBAL do osso e converter pra pose local dividindo
#     pela pose global do pai:  local = global(pai)⁻¹ · d_skel · rest_global.
#
# O passo 3 percorre TODOS os ossos (não só os 13 papéis) porque ossos
# intermediários não mapeados — Shoulder, Spine01, Neck — entram na cadeia entre
# um papel e outro e precisam da pose global correta.

# ---------------------------------------------------------------------------
# O CONTRATO DO RIG (papéis, hierarquia, aliases de osso) mora em
# `src/anim/RigContrato.gd`. Ficava duplicado aqui e no `tools/bake_mixamo.gd`,
# e as duas cópias discordavam da árvore real dos modelos — era o bug dos 64° de
# rotação parasita na cabeça (ver o cabeçalho do RigContrato).
# ---------------------------------------------------------------------------
const BONE_ALIASES := RigContrato.ALIASES
const RIG_PARENT := RigContrato.PAI
# Pais antes dos filhos — a acumulação de `push()` depende disso.
const ROLE_ORDER := RigContrato.PAPEIS

# Comprimento de perna do rig voxel de referência (Thigh->Shin->Foot = 0.30+0.30).
# Serve pra normalizar deslocamentos (bob) em modelos de escala diferente.
const REF_LEG_LEN := 0.60

var _skel: Skeleton3D = null
var _bone: Dictionary = {}         # papel -> índice do osso
var _role_of: Dictionary = {}      # índice do osso -> papel
var _proxy: Dictionary = {}        # papel -> Node3D proxy
var _rest_global: Dictionary = {}  # índice do osso -> Basis de repouso GLOBAL
var _axis := Basis()               # esqueleto -> personagem (Z-up nos Meshy)
var _axis_inv := Basis()
var _root_bone := -1               # osso raiz (Hips) — recebe o bob vertical
var _root_rest_pos := Vector3.ZERO
var _pos_scale := 1.0              # escala do esqueleto vs. rig voxel de referência

# Monta os proxies e o mapa de ossos. `holder` é quem adota os proxies (eles
# precisam existir na árvore pra terem global_position válido nas métricas).
# Devolve o dicionário {papel -> Node3D} pro BodyScanner.
func setup(skel: Skeleton3D, holder: Node3D) -> Dictionary:
	_skel = skel

	# Cadeia de transformações do ESQUELETO até o holder, percorrida UMA vez.
	# Ela rende duas coisas diferentes, e confundir as duas já custou caro:
	#
	#  - `to_holder`: a transformação COMPLETA (com escala). Converte o repouso
	#    dos ossos, que vem em unidades CRUAS do esqueleto, para o espaço do
	#    holder — que é onde os proxies vivem e onde o BodyScanner mede o corpo.
	#    Num FBX a cadeia é rotação pura (escala 1) e isto não muda nada; num GLB
	#    exportado pelo Blender a Armature carrega `scale 0.01`, e sem a
	#    conversão TODA métrica (thigh_len, shin_len, leg_len…) sai 100× maior —
	#    o que joga a cadência da marcha para ~1/100 e o personagem desliza com
	#    as pernas quase paradas.
	#
	#  - `_axis`: a MESMA cadeia, mas ortonormalizada (só rotação). É a basis que
	#    leva do espaço do esqueleto pro espaço do personagem, usada na
	#    conjugação dos deltas em `push()`. Nos modelos Meshy a Armature está
	#    girada −90° em X (o esqueleto é Z-up).
	var to_holder := Transform3D()
	var b := Basis()
	var n: Node3D = skel
	while n != null and n != holder:
		to_holder = n.transform * to_holder
		b = n.transform.basis.orthonormalized() * b
		n = n.get_parent() as Node3D
	_axis = b
	_axis_inv = b.inverse()

	for role in BONE_ALIASES:
		var idx := -1
		for alias in BONE_ALIASES[role]:
			idx = skel.find_bone(alias)
			if idx >= 0:
				break
		if idx < 0:
			continue
		_bone[role] = idx
		_role_of[idx] = role

		# Proxy posicionado onde o osso descansa, para o BodyScanner medir o
		# corpo (passada, balanço, IK) com os números reais deste modelo.
		#
		# NOME = o papel PURO, sem prefixo. Não é cosmético: `PlayerRig._attach_pistol`,
		# a âncora da cabeça do fôlego (`Player.gd`) e `BukiFX._membro` acham o
		# membro por `find_child("<papel>")`. Com o antigo `RoleProxy_<papel>` os
		# três recebiam `null` em TODO personagem skinnado (ver docs/erros.md,
		# 2026-08-10) — a arma da Buki Buki chegava a nascer na origem do mundo.
		#
		# Colisão de nome é impossível por construção: o BodyScanner só cria o
		# driver quando NENHUM nó do modelo se chama como um papel (`_collect`
		# varre a árvore inteira e, se achar algum, usa os nós direto e nem
		# instancia o driver). Medido nos 4 Meshy + no GLB novo: `find_child` dos
		# 13 papéis → null antes de criar os proxies.
		var p := Node3D.new()
		p.name = role
		p.position = to_holder * skel.get_bone_global_rest(idx).origin
		holder.add_child(p)
		_proxy[role] = p

	# Repouso GLOBAL de cada osso (não só dos papéis: a cadeia passa por ossos
	# intermediários como Shoulder e Spine01).
	for i in skel.get_bone_count():
		_rest_global[i] = skel.get_bone_global_rest(i).basis.orthonormalized()

	# (`_axis`/`_axis_inv` já saíram da mesma cadeia percorrida no topo do setup.)

	# Osso raiz (sem pai): é ele que sobe/desce no bob do torso.
	for i in skel.get_bone_count():
		if skel.get_bone_parent(i) == -1:
			_root_bone = i
			_root_rest_pos = skel.get_bone_rest(i).origin
			break

	# Normaliza deslocamentos: o bob é autorado pro rig voxel (perna 0.60).
	#
	# ⚠️ Esta perna fica de propósito em unidades CRUAS do esqueleto — NÃO passe
	# por `to_holder`. O bob sai daqui em unidades de osso e é escrito com
	# `set_bone_pose_position`, que o `Armature` reaplica com a própria escala
	# (0.01 no GLB do Blender): o mesmo fator se cancela nas duas pontas. Dividir
	# aqui deixaria o bob 100× pequeno. Só as MÉTRICAS do BodyScanner (acima)
	# precisam do espaço do holder, porque são consumidas em metros do jogo.
	if _bone.has("Thigh_L") and _bone.has("Foot_L"):
		var hip: Vector3 = skel.get_bone_global_rest(_bone["Thigh_L"]).origin
		var foot: Vector3 = skel.get_bone_global_rest(_bone["Foot_L"]).origin
		var leg := hip.distance_to(foot)
		if leg > 0.001:
			_pos_scale = leg / REF_LEG_LEN

	return _proxy

func is_valid() -> bool:
	return _skel != null and not _bone.is_empty()

# Copia proxies -> ossos. Chamado pelo ProceduralAnimator no fim de cada update.
func push() -> void:
	if _skel == null:
		return

	# 1. Delta acumulado por papel, no espaço do JOGO, pela hierarquia do RIG.
	var w: Dictionary = {}
	for role in ROLE_ORDER:
		if not _proxy.has(role):
			continue
		var pai: String = RIG_PARENT.get(role, "")
		var base: Basis = w.get(pai, Basis()) if pai != "" else Basis()
		w[role] = base * Basis.from_euler((_proxy[role] as Node3D).rotation)

	# 2/3. Resolve a cadeia de OSSOS (índices vêm com pai antes de filho).
	var glob: Dictionary = {}
	for i in _skel.get_bone_count():
		var bp := _skel.get_bone_parent(i)
		var base_g: Basis = glob[bp] if bp >= 0 else Basis()
		var g: Basis
		if _role_of.has(i) and w.has(_role_of[i]):
			# delta do jogo -> espaço do esqueleto, composto com o repouso global
			var d: Basis = _axis_inv * w[_role_of[i]] * _axis
			g = d * _rest_global[i]
			_skel.set_bone_pose_rotation(i, (base_g.inverse() * g).get_rotation_quaternion())
		else:
			g = base_g * _skel.get_bone_rest(i).basis.orthonormalized()
		glob[i] = g

	# Bob vertical: o animador escreve na POSIÇÃO do proxy do Torso; no
	# esqueleto quem sobe o corpo inteiro é o osso raiz (Hips). O deslocamento
	# também precisa ir pro espaço do esqueleto.
	if _root_bone >= 0 and _proxy.has("Torso"):
		var torso: Node3D = _proxy["Torso"]
		var d3: Vector3 = _axis_inv * ((torso.position - _torso_rest_pos) * _pos_scale)
		_skel.set_bone_pose_position(_root_bone, _root_rest_pos + d3)

# Posição de repouso do proxy do Torso (fixada no setup do animador).
var _torso_rest_pos := Vector3.ZERO

func set_torso_rest(p: Vector3) -> void:
	_torso_rest_pos = p
