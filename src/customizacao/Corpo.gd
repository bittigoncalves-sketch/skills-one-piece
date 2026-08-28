class_name Corpo
extends RefCounted
# ============================================================================
#  CORPO — traços do próprio personagem, não coisas vestidas.
#
#  Pedido do dono (2026-08-27): categoria "Corpo" no menu de Customização, com
#  tamanhos de OLHO à direita.
#
#  ⚠️ INTERPRETAÇÃO DECLARADA. O pedido dizia "olho grande, médio e grande" —
#  "grande" duas vezes. Como são três opções de TAMANHO, tratei como
#  **pequeno, médio e grande**. Se a intenção era outra (por exemplo três
#  formatos), é trocar a tabela abaixo: a mecânica não muda.
#
#  ------------------------------------------------------------- POR QUE À PARTE
#  Olho não é acessório (não se tira e põe) nem raça (não muda o que a criatura
#  É). E a exclusão é entre olhos: escolher "grande" tira "médio", mas NÃO tira
#  os chifres de Oni. Três eixos independentes, três catálogos — o que eles têm
#  em comum mora em `Adornos`.
#
#  O rig não tem rosto: o personagem é uma caixa lisa. Então o olho é peça
#  acrescentada na FRENTE da cabeça (`z = 0` na âncora), como as demais.
# ============================================================================

const MARCA := "Corpo_"

const BRANCO := Color(0.97, 0.97, 0.98)
const PUPILA := Color(0.06, 0.06, 0.09)

## Cada tamanho é o MESMO desenho em escala diferente — dois olhos, cada um com
## branco e pupila. Descrever assim (e não três listas soltas) é o que garante
## que mudar o formato do olho mude os três juntos.
const TAMANHOS := {
	"olho_pequeno": {"nome": "Olho Pequeno", "escala": 0.62},
	"olho_medio":   {"nome": "Olho Médio",   "escala": 1.0},
	"olho_grande":  {"nome": "Olho Grande",  "escala": 1.45},
}

## O desenho base, em fração da caixa da cabeça. A pupila fica um fio à FRENTE
## do branco para não brigar por profundidade (z-fighting) com ele.
const BASE := [
	{"no": "Head", "tam": Vector3(0.17, 0.22, 0.06), "ancora": Vector3(0.33, 0.60, 0.0), "cor": BRANCO},
	{"no": "Head", "tam": Vector3(0.17, 0.22, 0.06), "ancora": Vector3(0.67, 0.60, 0.0), "cor": BRANCO},
	{"no": "Head", "tam": Vector3(0.08, 0.11, 0.04), "ancora": Vector3(0.33, 0.60, -0.02), "cor": PUPILA},
	{"no": "Head", "tam": Vector3(0.08, 0.11, 0.04), "ancora": Vector3(0.67, 0.60, -0.02), "cor": PUPILA},
]


static func ids() -> Array:
	return TAMANHOS.keys()


static func dados(id: String) -> Dictionary:
	return TAMANHOS.get(id, {})


static func atual(modelo: Node3D) -> String:
	return Adornos.id_aplicado(modelo, MARCA)


static func aplicar(modelo: Node3D, id: String) -> bool:
	if modelo == null or not is_instance_valid(modelo):
		return false
	remover(modelo)
	if id == "":
		return true
	var d := dados(id)
	if d.is_empty():
		push_warning("[Corpo] tamanho desconhecido: " + id)
		return false
	var k: float = float(d["escala"])
	var i := 0
	# `base` vem de Array não tipado, logo é Variant: tipar é obrigatório aqui
	# (ver docs/erros.md, a entrada sobre o `:=` e Variant).
	for base: Dictionary in BASE:
		var p: Dictionary = base.duplicate()
		# Só o TAMANHO escala. A âncora fica: olho maior cresce no lugar, em vez
		# de escorregar pela cara.
		p["tam"] = (base["tam"] as Vector3) * k
		Adornos.criar_peca(modelo, MARCA, id, p, i)
		i += 1
	return true


static func remover(modelo: Node3D) -> void:
	Adornos.remover_marca(modelo, MARCA)
