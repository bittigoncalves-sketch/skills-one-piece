extends RefCounted
## Anatomical selection is a view over the existing hierarchy, never a new rig.
const GROUPS := {
	"arm_L": {"label":"Braço esquerdo inteiro", "roots":["UpperArm_L"]},
	"arm_R": {"label":"Braço direito inteiro", "roots":["UpperArm_R"]},
	"arms": {"label":"Os dois braços", "roots":["UpperArm_L","UpperArm_R"]},
	"leg_L": {"label":"Perna esquerda inteira", "roots":["Thigh_L"]},
	"leg_R": {"label":"Perna direita inteira", "roots":["Thigh_R"]},
	"legs": {"label":"As duas pernas", "roots":["Thigh_L","Thigh_R"]},
	"head": {"label":"Cabeça e pescoço", "roots":["Neck"]},
	"hand_L": {"label":"Mão esquerda e dedos", "roots":["Hand_L"]},
	"hand_R": {"label":"Mão direita e dedos", "roots":["Hand_R"]},
	"foot_L": {"label":"Pé esquerdo e dedos", "roots":["Foot_L"]},
	"foot_R": {"label":"Pé direito e dedos", "roots":["Foot_R"]},
	"body": {"label":"Corpo inteiro", "roots":["Root"]},
}

## Membros que um clique no 3D seleciona inteiros. Um osso pertence a no maximo
## um deles, e a busca vai do mais externo para dentro: clicar num dedo pega o
## braco, nao a mao. A mao e o pe continuam alcancaveis pela arvore ou por
## Shift+clique.
const LIMBS := ["arm_L", "arm_R", "leg_L", "leg_R", "head"]

static func limb_for(key: String, rig: Node3D) -> String:
	if not rig.joints.has(key): return ""
	# A espada mora sob Grip_R, dentro do braco direito, mas nunca e "o braco".
	if str(rig.categories.get(key, "")) == "weapon": return ""
	for group in LIMBS:
		for root in GROUPS[group].roots:
			if not rig.joints.has(root): continue
			if key == root or rig.joints[root].is_ancestor_of(rig.joints[key]):
				return "#" + group
	return ""

static func roots_for(tokens: Array, rig: Node3D) -> Array:
	var candidates: Array = []
	for token in tokens:
		var keys: Array = GROUPS[str(token).substr(1)].roots if str(token).begins_with("#") else [token]
		for key in keys:
			if rig.joints.has(key) and not candidates.has(key): candidates.append(key)
	var result: Array = []
	for key in candidates:
		var covered := false
		for other in candidates:
			if other != key and rig.joints[other].is_ancestor_of(rig.joints[key]): covered = true; break
		if not covered: result.append(key)
	return result

static func members(roots: Array, rig: Node3D) -> Array:
	var result: Array = []
	for key in rig.joints:
		for parent in roots:
			if key == parent or rig.joints[parent].is_ancestor_of(rig.joints[key]):
				result.append(key)
				break
	return result

static func title(tokens: Array, fallback: String) -> String:
	if tokens.size() == 1 and str(tokens[0]).begins_with("#"):
		return GROUPS[str(tokens[0]).substr(1)].label
	return "%d partes selecionadas" % tokens.size() if tokens.size() > 1 else fallback
