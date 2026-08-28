class_name Adornos
extends RefCounted
# ============================================================================
#  O NÚCLEO COMUM DAS PEÇAS PENDURADAS NO CORPO.
#
#  Três sistemas precisam da MESMA mecânica: `Acessorios` (chapéu), `Racas`
#  (asas, chifres, rabos, membros longos) e `Corpo` (olhos). Todos:
#    • penduram peças em nós do rig, posicionadas por FRAÇÃO da caixa do nó;
#    • trocam por exclusão dentro de um grupo;
#    • podem mudar ESCALA de nós existentes, e precisam desfazer isso;
#    • podem ter peça que ACOMPANHA a cor do personagem.
#
#  ⚠️ POR QUE GENERALIZAR AGORA, E NÃO ANTES. Com um sistema seria adivinhação;
#  com dois, otimismo. Com TRÊS pedindo o mesmo, a duplicação é fato medido — e
#  este projeto já pagou caro por código repetido sem fonte única (a direção da
#  frente estava em cinco cópias, e a quinta saiu negada).
#
#  O que NÃO subiu para cá: a regra de EXCLUSÃO. Ela é diferente em cada um
#  (acessório exclui por parte do corpo, raça exclui globalmente, olho exclui
#  outro olho), e forçar as três num molde só criaria um parâmetro que ninguém
#  entende. Cada catálogo decide o que apagar; aqui só existe o "como apagar".
#
#  --------------------------------------------------------- MEDIDAS RELATIVAS
#  `ancora` é 0..1 DENTRO da AABB do nó de destino e `tam` é fração do tamanho
#  dela. Nunca metros: o modelo da prévia e o de jogo têm proporções diferentes
#  (a cabeça tem 0,40 de profundidade num e 0,74 no outro), e número absoluto
#  quebraria em um dos dois sem avisar.
#
#  Na âncora, **z = 0 é a FRENTE** — o personagem olha para −Z e a AABB começa
#  no menor z.
# ============================================================================

const META_SEGUE_COR := "segue_cor"
const META_ESCALA := "escala_antes"
const META_DONO := "adorno_dono"


## Cria uma peça de caixa pendurada num nó do rig.
## `peca` = {no, tam, ancora, rot?, cor?, segue_cor?}
static func criar_peca(modelo: Node3D, marca: String, id: String,
		peca: Dictionary, indice: int) -> MeshInstance3D:
	var destino := modelo.find_child(String(peca["no"]), true, false) as Node3D
	if destino == null:
		push_warning("[Adornos] nó '%s' não existe neste modelo" % peca["no"])
		return null
	var cx := Acessorios.caixa_do_no(destino)

	var m := MeshInstance3D.new()
	m.name = "%s%s_%d" % [marca, id, indice]
	var caixa := BoxMesh.new()
	var tam: Vector3 = peca["tam"]
	caixa.size = Vector3(cx.size.x * tam.x, cx.size.y * tam.y, cx.size.z * tam.z)
	m.mesh = caixa

	var a: Vector3 = peca["ancora"]
	m.position = cx.position + Vector3(cx.size.x * a.x, cx.size.y * a.y, cx.size.z * a.z)
	if peca.has("rot"):
		m.rotation = peca["rot"]

	if bool(peca.get("segue_cor", false)):
		# Sem material próprio: quem pinta o corpo pinta esta peça junto.
		m.set_meta(META_SEGUE_COR, true)
	else:
		# ⚠️ O MESMO MATERIAL DO MUNDO (`Materiais.superficie`), e não um
		# `StandardMaterial3D` avulso. É ele que traz a banda de luz e o
		# especular desligado do cel shading — peça com material padrão fica
		# LISA e brilhante ao lado de um corpo chapado, e denuncia que foi
		# colada depois.
		m.material_override = Materiais.superficie(peca.get("cor", Color(0.6, 0.6, 0.6)))
	destino.add_child(m)
	return m


## Apaga tudo o que tiver a marca. Varre por PREFIXO de propósito: peça de um
## catálogo antigo, cujo id não existe mais, também tem de sair — senão vira
## órfão inarredável.
static func remover_marca(modelo: Node3D, marca: String) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	for n in todos(modelo):
		if String(n.name).begins_with(marca):
			n.get_parent().remove_child(n)
			n.queue_free()


## Multiplica a escala de nós existentes, guardando a original.
##
## ⚠️ Guarda a escala ORIGINAL em vez de assumir `Vector3.ONE`: este rig nasce
## com escala 1,8, e devolver ONE deformaria o corpo.
##
## ⚠️ E quem chama precisa passar só o TOPO de cada cadeia. `ForeArm` é filho de
## `UpperArm`: escalar os dois MULTIPLICA (medido: 1,80 → 4,32 em vez de 2,79).
static func aplicar_escalas(modelo: Node3D, escalas: Dictionary, dono: String) -> void:
	for nome_no in escalas:
		var no := modelo.find_child(String(nome_no), true, false) as Node3D
		if no == null:
			push_warning("[Adornos] nó '%s' não existe neste modelo" % nome_no)
			continue
		no.set_meta(META_ESCALA, no.scale)
		no.set_meta(META_DONO, dono)
		no.scale = no.scale * (escalas[nome_no] as Vector3)


static func restaurar_escalas(modelo: Node3D, dono: String) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	for n in todos(modelo):
		if not (n is Node3D):
			continue
		var no := n as Node3D
		if not no.has_meta(META_ESCALA):
			continue
		if dono != "" and String(no.get_meta(META_DONO, "")) != dono:
			continue
		no.scale = no.get_meta(META_ESCALA)
		no.remove_meta(META_ESCALA)
		if no.has_meta(META_DONO):
			no.remove_meta(META_DONO)


## Qual id está aplicado sob esta marca, ou "". Lê do NOME do nó
## (`<marca><id>_<i>`), então não depende de guardar referência — o modelo pode
## ter sido reconstruído por baixo.
static func id_aplicado(modelo: Node3D, marca: String, dono_escala := "") -> String:
	if modelo == null or not is_instance_valid(modelo):
		return ""
	for n in todos(modelo):
		var nome := String(n.name)
		if nome.begins_with(marca):
			var resto := nome.substr(marca.length())
			var corte := resto.rfind("_")
			return resto.substr(0, corte) if corte > 0 else resto
	# Item que só mexe em escala não deixa peça: a marca fica no nó escalado.
	if dono_escala != "":
		for n in todos(modelo):
			if n is Node3D and (n as Node3D).has_meta(META_ESCALA) \
					and String((n as Node3D).get_meta(META_DONO, "")) == dono_escala:
				return String((n as Node3D).get_meta("item_id", ""))
	return ""


## true se a malha deve acompanhar a cor do personagem.
static func segue_cor(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is Node3D and (p as Node3D).has_meta(META_SEGUE_COR):
			return bool((p as Node3D).get_meta(META_SEGUE_COR))
		p = p.get_parent()
	return false


static func todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(todos(f))
	return out
