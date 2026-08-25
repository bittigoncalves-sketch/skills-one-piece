class_name RigContrato
extends RefCounted
# ============================================================================
#  O CONTRATO DO RIG — fonte ÚNICA dos 13 papéis, da hierarquia e do formato
#  das faixas de animação.
#
#  POR QUE ESTE ARQUIVO EXISTE
#  ---------------------------
#  A hierarquia do rig estava declarada em TRÊS lugares independentes
#  (`SkeletonDriver.RIG_PARENT`, `bake_mixamo.MAP` e a tabela do
#  `docs/ANIMACOES_MIXAMO.md`), e os três discordavam da árvore real dos
#  modelos: os três diziam `Head` filho de `Torso`, enquanto no `base.scn` e no
#  `buggy.scn` o pai de `Head` é `Neck`.
#
#  Consequência medida (`tools/dev_tests/medir_erro_cabeca.gd`): como as faixas
#  de `Neck` e de `Head` eram as DUAS gravadas como delta relativo ao `Torso`, a
#  rotação do pescoço entrava duas vezes na cabeça — até **64,01°** de rotação
#  parasita (`armada.res`), mediana ~20° nos 29 clipes.
#
#  Agora a hierarquia mora aqui, e quem precisa dela importa daqui.
#
#  ----------------------------------------------------------------------
#  O FORMATO DA FAIXA
#  ----------------------------------------------------------------------
#  Uma faixa de clipe do jogo é `TYPE_VALUE` com caminho
#  **hierárquico** e propriedade `rotation`:
#
#      NodePath("Torso/Neck/Head:rotation")     ← certo
#      NodePath("Head:rotation")                ← formato ANTIGO
#
#  O caminho hierárquico não é cosmética: é o que faz a faixa RESOLVER como
#  `NodePath` de verdade na árvore do personagem. Com o formato antigo, 12 das
#  13 faixas de todo clipe apontavam para lugar nenhum
#  (`tools/dev_tests/testar_export_gltf.gd` mede: 1/13). O clipe só tocava
#  porque o `ProceduralAnimator._apply_baked` lia a string do caminho à mão.
#
#  O que o caminho hierárquico destrava:
#   • `AnimationPlayer` toca o clipe direto, e o dock de animação do Godot faz
#     preview em cima do personagem de verdade;
#   • o exportador glTF resolve as 13 faixas e escreve 13 canais de quaternion —
#     que o Blender importa nativamente, sem script
#     (`tools/exportar_para_blender.gd`);
#   • a volta do Blender é simétrica (`tools/importar_do_blender.gd`).
#
#  `papel_de()` aceita os DOIS formatos de propósito: um `.res` antigo continua
#  tocando enquanto não for reassado.
# ============================================================================

# Papéis na ordem de resolução: PAI SEMPRE ANTES DO FILHO. O
# `SkeletonDriver.push()` acumula a cadeia nesta ordem e quebra se ela mudar.
const PAPEIS := [
	"Torso", "Neck", "Head",
	"UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
	"Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R",
]

# Hierarquia do rig. `""` = raiz.
#
# ⚠️ `Head` é filho de `Neck`, não de `Torso`. É a árvore REAL do `base.scn` e do
# `buggy.scn`, e é também a cadeia real dos esqueletos skinnados (Spine → Neck →
# Head). Ver o cabeçalho: declarar `Torso` aqui era o bug dos 64°.
const PAI := {
	"Torso": "",
	"Neck": "Torso",
	"Head": "Neck",
	"UpperArm_L": "Torso", "ForeArm_L": "UpperArm_L",
	"UpperArm_R": "Torso", "ForeArm_R": "UpperArm_R",
	"Thigh_L": "Torso", "Shin_L": "Thigh_L", "Foot_L": "Shin_L",
	"Thigh_R": "Torso", "Shin_R": "Thigh_R", "Foot_R": "Shin_R",
}

# Aliases de nome de osso por papel. Meshy AI usa os nomes do Mixamo SEM o
# prefixo "mixamorig_"; a lista aceita as duas convenções (e o "neck" minúsculo
# que o Meshy exporta), então um modelo rigado no Mixamo entra de graça.
const ALIASES := {
	"Torso":      ["Spine", "mixamorig_Spine1", "Spine1", "Chest"],
	"Neck":       ["neck", "Neck", "mixamorig_Neck"],
	"Head":       ["Head", "mixamorig_Head"],
	"UpperArm_L": ["LeftArm", "mixamorig_LeftArm"],
	"ForeArm_L":  ["LeftForeArm", "mixamorig_LeftForeArm"],
	"UpperArm_R": ["RightArm", "mixamorig_RightArm"],
	"ForeArm_R":  ["RightForeArm", "mixamorig_RightForeArm"],
	"Thigh_L":    ["LeftUpLeg", "mixamorig_LeftUpLeg"],
	"Shin_L":     ["LeftLeg", "mixamorig_LeftLeg"],
	"Foot_L":     ["LeftFoot", "mixamorig_LeftFoot"],
	"Thigh_R":    ["RightUpLeg", "mixamorig_RightUpLeg"],
	"Shin_R":     ["RightLeg", "mixamorig_RightLeg"],
	"Foot_R":     ["RightFoot", "mixamorig_RightFoot"],
}

const PROPRIEDADE := "rotation"

# "Head" -> "Torso/Neck/Head"
static func caminho(papel: String) -> String:
	if not PAI.has(papel):
		return papel
	var partes := [papel]
	var p: String = PAI[papel]
	while p != "":
		partes.push_front(p)
		p = PAI.get(p, "")
	return "/".join(partes)

# "Head" -> NodePath("Torso/Neck/Head:rotation")
static func faixa(papel: String) -> NodePath:
	return NodePath(caminho(papel) + ":" + PROPRIEDADE)

# Caminho de faixa -> papel. Aceita os dois formatos:
#   "Torso/Neck/Head:rotation" -> "Head"      (atual)
#   "Head:rotation"            -> "Head"      (clipes ainda não reassados)
static func papel_de(caminho_da_faixa) -> String:
	var s := String(caminho_da_faixa).get_slice(":", 0)
	var barra := s.rfind("/")
	return s if barra < 0 else s.substr(barra + 1)

# Acha a faixa de um papel num clipe, seja qual for o formato do caminho.
# Devolve -1 se não existir.
static func acha_faixa(anim: Animation, papel: String) -> int:
	var direto := anim.find_track(faixa(papel), Animation.TYPE_VALUE)
	if direto >= 0:
		return direto
	for i in anim.get_track_count():
		if papel_de(anim.track_get_path(i)) == papel:
			return i
	return -1

# Espelha um papel: "Shin_L" -> "Shin_R". Papel sem lado volta igual.
static func espelha_papel(papel: String) -> String:
	if papel.ends_with("_L"):
		return papel.substr(0, papel.length() - 2) + "_R"
	if papel.ends_with("_R"):
		return papel.substr(0, papel.length() - 2) + "_L"
	return papel

# Espelha um CAMINHO inteiro, segmento a segmento — "Torso/Thigh_L/Shin_L"
# vira "Torso/Thigh_R/Shin_R". Trocar só o último segmento deixaria o caminho
# apontando para um nó que não existe.
static func espelha_caminho(caminho_da_faixa) -> NodePath:
	var s := String(caminho_da_faixa)
	var i := s.find(":")
	var corpo := s if i < 0 else s.substr(0, i)
	var resto := "" if i < 0 else s.substr(i)
	var saida := PackedStringArray()
	for seg in corpo.split("/"):
		saida.append(espelha_papel(seg))
	return NodePath("/".join(saida) + resto)
