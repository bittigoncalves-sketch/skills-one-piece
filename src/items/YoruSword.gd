class_name YoruSword
extends Node3D
## GLB em metros: origem na pega direita, fio +Y, segunda pega -0,17 m.
const CAMINHO := "res://assets/models/weapons/yoru_v2.glb"
const ESCALA := 1.0
const LAMINA_BASE := 0.39
const LAMINA_PONTA := 1.77
var grip_l: Node3D
var handle: Node3D = null
var lamina: SwordBlade = null
## Onde o fio começa e acaba, como NÓS. O rastro do golpe se pendura neles em
## vez de chutar um ponto a partir do cotovelo — ver
## `ProceduralAnimator.usar_lamina_no_rastro`.
var guarda: Node3D = null
var ponta: Node3D = null
var _modelo: Node3D = null


func _ready() -> void:
	name = "Yoru"
	_montar_modelo()

	# O `handle` é a ORIGEM desta cena. Ele não desloca nada — existe para que
	# "onde a espada é segurada" seja um nó que dá para selecionar, mover e
	# imprimir, em vez de um número dentro de uma expressão.
	handle = Node3D.new()
	handle.name = "handle"
	add_child(handle)

	grip_l = Node3D.new()
	grip_l.name = "grip_l"
	add_child(grip_l)
	grip_l.position.y = -0.17

	lamina = SwordBlade.new()
	lamina.base = LAMINA_BASE
	lamina.ponta = LAMINA_PONTA
	add_child(lamina)

	guarda = Node3D.new()
	guarda.name = "guarda"
	add_child(guarda)
	guarda.position = Vector3(0.0, LAMINA_BASE, 0.0)

	ponta = Node3D.new()
	ponta.name = "ponta"
	add_child(ponta)
	ponta.position = Vector3(0.0, LAMINA_PONTA, 0.0)

	if MOSTRAR_FIO:
		_marcar_fio_e_dorso()


func _montar_modelo() -> void:
	var cena := load(CAMINHO) as PackedScene
	if cena == null:
		push_warning("YoruSword: não achei %s" % CAMINHO)
		return
	_modelo = cena.instantiate() as Node3D
	if _modelo == null:
		return
	_modelo.name = "modelo"
	add_child(_modelo)

	_modelo.transform = Transform3D.IDENTITY


## Liga a espada à mão nomeada do rig. Uma função porque o pedido era
## explicitamente "ligue os dois": quem lê o código vê a ligação acontecer, em
## vez de deduzi-la de um `add_child` solto no meio de outra coisa.
static func ligar_na_mao(mao: Node3D) -> YoruSword:
	if mao == null or not is_instance_valid(mao):
		return null
	var espada := YoruSword.new()
	mao.add_child(espada)
	espada.position = Vector3.ZERO      # handle sobre Hand_R, sem folga
	espada.rotation = Vector3.ZERO
	return espada


# ============================================================================
#  MARCADOR DE FIO E DORSO — qual aresta é a FRENTE da lâmina
# ============================================================================
#  Pedido do dono, 09/09/2026: "coloque um marcador na parte da lâmina indicando
#  a frente e as costas desta". O motivo estava no mesmo pedido: o corte vertical
#  saía com a lâmina deitada e NÃO DAVA PARA VER — uma espada de bloco escuro,
#  vista de longe, esconde de que lado está o fio. O que não se vê, não se
#  corrige; o marcador existe para tornar a orientação VISÍVEL.
#
#  Ele é a contraparte visual do que `tools/dev_tests/medir_fio_yoru.gd` mede em
#  número, e do rolamento que `YoruRig.ROLAMENTO_VERTICAL` corrige.
#
#      FIO   (frente) -> faixa CIANA, contínua, no lado que corta
#      DORSO (costas) -> faixa ÂMBAR, TRACEJADA, no lado cego
#
#  ⚠️ A cor não é o único sinal. A faixa do dorso é tracejada de propósito: em
#  captura sem cor, em preto e branco, ou para quem não separa ciano de âmbar, a
#  CONTINUIDADE ainda distingue os dois lados. Marcador que só funciona colorido
#  é meio marcador.
#
#  ⚠️ LIGADO POR PADRÃO porque foi pedido agora, para diagnosticar. Trocar para
#  `false` devolve a espada limpa — mesma convenção do `SwordBlade.MOSTRAR_ZONAS`.
#  GATILHO para desligar: quando o corte vertical estiver aprovado pelo dono, ou
#  antes de qualquer captura de apresentação.
const MOSTRAR_FIO := true
const SEGMENTOS := 12
const COR_FIO := Color(0.15, 0.95, 1.0)
const COR_DORSO := Color(1.0, 0.5, 0.05)


## Onde o fio e o dorso passam, na altura `t` (0 = guarda, 1 = ponta).
##
## ⚠️ ESTA CURVA É A DA MALHA, não uma reta aproximada. Ela é a mesma conta de
## `tools/blender/yoru_master.py` (a lâmina é CURVA: o centro foge até +0,095 m e
## a largura varia com o comprimento). Conferida contra a geometria exportada em
## `tools/dev_tests/medir_lamina_yoru.gd`: em y = 1,00 a fórmula dá fio +0,1844 e
## a malha mede +0,1833 — 1 mm, que é a folga do chanfro.
##
## O sinal do `centro` é o mesmo `BLADE_BELLY` do gerador, e é POSITIVO desde
## 10/09/2026: a barriga da curva fica do lado do fio. Se os dois divergirem, o
## marcador desenha faixas no ar ao lado da lâmina, e não sobre as arestas dela.
##
## Devolve Vector2(x_do_fio, x_do_dorso) no espaço local da arma.
static func _laterais(t: float) -> Vector2:
	var centro: float = 0.095 * sin(PI * t) * (0.5 + 0.5 * t)
	var meia: float = (0.084 + 0.03 * sin(PI * t)) * (1.0 - pow(t, 7.0))
	return Vector2(centro + meia, centro - meia)


## De que lado fica o fio, segundo o PRÓPRIO asset.
##
## O `yoru_v2.glb` traz um nó autoral `edge_direction` em (+0,1, 0,9, 0) — ele
## existia desde a exportação e NINGUÉM no jogo lia. Ler daqui em vez de chumbar
## "+X" faz o asset ser a fonte da verdade: se a arma for reexportada com o fio
## do outro lado, o marcador acompanha sozinho em vez de mentir.
func _lado_do_fio() -> float:
	var marcador := find_child("edge_direction", true, false) as Node3D
	if marcador == null:
		push_warning("YoruSword: sem `edge_direction` no GLB — assumindo o fio em +X (o medido)")
		return 1.0
	return signf(marcador.position.x) if absf(marcador.position.x) > 1e-4 else 1.0


func _marcar_fio_e_dorso() -> void:
	var sinal := _lado_do_fio()
	var raiz := Node3D.new()
	raiz.name = "MarcadorDoFio"
	add_child(raiz)
	# Recursos COMPARTILHADOS: 24 blocos por espada, 2 malhas e 2 materiais.
	var bloco := BoxMesh.new()
	bloco.size = Vector3(0.028, (LAMINA_PONTA - LAMINA_BASE) / float(SEGMENTOS) * 0.86, 0.034)
	var mats := {}
	for par in [["fio", COR_FIO], ["dorso", COR_DORSO]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = par[1]
		mat.emission_enabled = true
		mat.emission = par[1]
		mat.emission_energy_multiplier = 2.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mats[par[0]] = mat
	for i in SEGMENTOS:
		var t: float = (float(i) + 0.5) / float(SEGMENTOS)
		var lados := _laterais(t)
		var y: float = lerpf(LAMINA_BASE, LAMINA_PONTA, t)
		# FIO: contínuo. DORSO: um sim, um não — a leitura sem cor.
		for papel in ["fio", "dorso"]:
			if papel == "dorso" and i % 2 == 1:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "%s_%02d" % [papel, i]
			mi.mesh = bloco
			mi.material_override = mats[papel]
			# `sinal` troca os dois lados de uma vez se o asset mudar de mão.
			var x: float = lados.x if papel == "fio" else lados.y
			mi.position = Vector3(x * sinal, y, 0.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			raiz.add_child(mi)
