class_name Racas
extends RefCounted
# ============================================================================
#  RAÇAS — o que o corpo GANHA ou muda de proporção.
#
#  Pedido do dono (2026-08-27), oito raças: Skypiean (asas), Oni (chifres),
#  Sharkman (barbatana nas costas), Braços Longos, Pernas Longas, Palhaço
#  (nariz), Mink Coelho (orelhas + rabinho quadrado) e Mink Lobo (orelhas e
#  rabo NA COR DO PERSONAGEM).
#
#  ------------------------------------------- POR QUE NÃO SÃO "ACESSÓRIOS"
#  Duas diferenças de regra, e as duas mudam o código:
#
#  1. **Exclusão GLOBAL, não por parte.** Acessório convive com acessório desde
#     que sejam de partes diferentes; raça, não — ninguém é Oni e Sharkman ao
#     mesmo tempo. Trocar de raça tira a anterior INTEIRA, mesmo quando as peças
#     estão em nós diferentes.
#  2. **Nem toda raça acrescenta peça.** Braços/Pernas Longas mudam a ESCALA de
#     nós que já existem. Isso precisa de desfazer próprio: a escala original é
#     guardada na aplicação e devolvida na remoção — não dá para "apagar" uma
#     escala como se apaga uma malha.
#
#  ------------------------------------------------------- MEDIDAS RELATIVAS
#  ⚠️ Nenhuma posição ou tamanho aqui é em metros. Tudo é FRAÇÃO da caixa do nó
#  de destino: `ancora` em 0..1 dentro da AABB, `tam` como fração do tamanho
#  dela. É o mesmo princípio do chapéu, pelo mesmo motivo — o rig muda de
#  proporção entre personagens, e número em metros quebra em silêncio.
#
#  Na âncora: **z = 0 é a FRENTE**. O personagem olha para −Z, e a AABB começa
#  no menor z. Por isso o nariz do palhaço tem `z = 0` e o rabo tem `z = 1`.
#
#  -------------------------------------------------------- A COR DO MINK LOBO
#  As peças do Mink Lobo nascem com `segue_cor`, e quem pinta o corpo pinta elas
#  junto. As demais têm cor própria — chifre de Oni não fica azul porque o
#  jogador escolheu azul.
# ============================================================================

const MARCA := "Raca_"
const META_SEGUE_COR := "segue_cor"
const META_ESCALA := "escala_antes"

const PELE := Color(0.93, 0.78, 0.62)
const OSSO := Color(0.92, 0.90, 0.82)
const CINZA := Color(0.55, 0.58, 0.62)

const CATALOGO := {
	"skypiean": {
		"nome": "Skypiean",
		"descricao": "asas nas costas",
		"pecas": [
			# LARGAS e chapadas. A primeira versão era estreita (x = 0,16 do
			# tronco) e lia como duas lâminas, não como asas — asa se reconhece
			# pela ENVERGADURA, então a largura é que tem de ser grande.
			{"no": "Torso", "tam": Vector3(0.95, 1.15, 0.12), "ancora": Vector3(0.05, 0.80, 1.0),
			 "rot": Vector3(0.0, 0.0, 0.38), "cor": Color(0.97, 0.97, 1.0)},
			{"no": "Torso", "tam": Vector3(0.95, 1.15, 0.12), "ancora": Vector3(0.95, 0.80, 1.0),
			 "rot": Vector3(0.0, 0.0, -0.38), "cor": Color(0.97, 0.97, 1.0)},
		],
	},
	"oni": {
		"nome": "Oni",
		"descricao": "chifres",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.16, 0.50, 0.16), "ancora": Vector3(0.24, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, 0.22), "cor": OSSO},
			{"no": "Head", "tam": Vector3(0.16, 0.50, 0.16), "ancora": Vector3(0.76, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, -0.22), "cor": OSSO},
		],
	},
	"sharkman": {
		"nome": "Sharkman",
		"descricao": "barbatana nas costas",
		"pecas": [
			{"no": "Torso", "tam": Vector3(0.12, 0.85, 0.95), "ancora": Vector3(0.5, 0.85, 1.0),
			 "rot": Vector3(-0.30, 0.0, 0.0), "cor": CINZA},
		],
	},
	"bracos_longos": {
		"nome": "Braços Longos",
		"descricao": "braços mais compridos",
		# Só a altura estica: engrossar junto viraria braço de gorila, e o pedido
		# foi "aumenta o tamanho", que no braço se lê como comprimento.
		#
		# ⚠️ SÓ O TOPO DA CADEIA. `ForeArm` é FILHO de `UpperArm`, então escalar
		# os dois MULTIPLICA: medido, a escala global do antebraço ia de 1,8 para
		# 4,32 (= 1,8 × 1,55 × 1,55) e o braço virava um borrão maior que o
		# corpo. Escalando só o ombro, o antebraço herda o alongamento na medida
		# certa — que é justamente para o que a hierarquia serve.
		"escalas": {
			"UpperArm_R": Vector3(1.0, 1.55, 1.0),
			"UpperArm_L": Vector3(1.0, 1.55, 1.0),
		},
	},
	"pernas_longas": {
		"nome": "Pernas Longas",
		"descricao": "pernas mais compridas",
		# Mesma regra do braço: `Shin` é filho de `Thigh`, então só a coxa entra.
		"escalas": {
			"Thigh_R": Vector3(1.0, 1.55, 1.0),
			"Thigh_L": Vector3(1.0, 1.55, 1.0),
		},
	},
	"palhaco": {
		"nome": "Palhaço",
		"descricao": "nariz de palhaço",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.30, 0.30, 0.22), "ancora": Vector3(0.5, 0.45, 0.0),
			 "cor": Color(0.90, 0.13, 0.13)},
		],
	},
	"mink_coelho": {
		"nome": "Mink Coelho",
		"descricao": "orelhas e rabinho",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.16, 0.85, 0.12), "ancora": Vector3(0.32, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.10), "cor": PELE},
			{"no": "Head", "tam": Vector3(0.16, 0.85, 0.12), "ancora": Vector3(0.68, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.10), "cor": PELE},
			# "rabinho de coelho QUADRADO" — o dono foi explícito, e cubo é o que
			# combina com um jogo feito de caixas.
			{"no": "Torso", "tam": Vector3(0.26, 0.26, 0.26), "ancora": Vector3(0.5, 0.12, 1.0),
			 "cor": Color(0.98, 0.97, 0.95)},
		],
	},
	"mink_lobo": {
		"nome": "Mink Lobo",
		"descricao": "orelhas e rabo na cor do personagem",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.20, 0.42, 0.14), "ancora": Vector3(0.28, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.28), "segue_cor": true},
			{"no": "Head", "tam": Vector3(0.20, 0.42, 0.14), "ancora": Vector3(0.72, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.28), "segue_cor": true},
			{"no": "Torso", "tam": Vector3(0.24, 0.24, 2.1), "ancora": Vector3(0.5, 0.22, 1.0),
			 "rot": Vector3(-0.60, 0.0, 0.0), "segue_cor": true},
		],
	},
}


static func ids() -> Array:
	return CATALOGO.keys()


static func dados(id: String) -> Dictionary:
	return CATALOGO.get(id, {})


## Qual raça está aplicada, ou "" se nenhuma.
static func atual(modelo: Node3D) -> String:
	if modelo == null or not is_instance_valid(modelo):
		return ""
	for n in _todos(modelo):
		var nome := String(n.name)
		if nome.begins_with(MARCA):
			# `Raca_<id>_<i>` — o id é o miolo.
			var resto := nome.substr(MARCA.length())
			var corte := resto.rfind("_")
			return resto.substr(0, corte) if corte > 0 else resto
	# Raça só de escala não deixa peça: a marca fica no próprio nó escalado.
	for n in _todos(modelo):
		if n is Node3D and (n as Node3D).has_meta(META_ESCALA):
			return String((n as Node3D).get_meta("raca_id", ""))
	return ""


## Troca a raça. Tira a anterior INTEIRA antes — ninguém é de duas raças.
static func aplicar(modelo: Node3D, id: String) -> bool:
	if modelo == null or not is_instance_valid(modelo):
		return false
	remover(modelo)
	if id == "":
		return true
	var d := dados(id)
	if d.is_empty():
		push_warning("[Racas] raça desconhecida: " + id)
		return false

	var i := 0
	for p in d.get("pecas", []):
		_criar_peca(modelo, id, p, i)
		i += 1
	for nome_no in d.get("escalas", {}):
		var no := modelo.find_child(String(nome_no), true, false) as Node3D
		if no == null:
			push_warning("[Racas] nó '%s' não existe neste modelo" % nome_no)
			continue
		# ⚠️ Guardar a escala ORIGINAL, e não assumir Vector3.ONE: um rig pode
		# nascer com escala própria, e devolver ONE deformaria o corpo.
		no.set_meta(META_ESCALA, no.scale)
		no.set_meta("raca_id", id)
		no.scale = no.scale * (d["escalas"][nome_no] as Vector3)
	return true


static func remover(modelo: Node3D) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	for n in _todos(modelo):
		if String(n.name).begins_with(MARCA):
			n.get_parent().remove_child(n)
			n.queue_free()
	for n in _todos(modelo):
		if n is Node3D and (n as Node3D).has_meta(META_ESCALA):
			var no := n as Node3D
			no.scale = no.get_meta(META_ESCALA)
			no.remove_meta(META_ESCALA)
			if no.has_meta("raca_id"):
				no.remove_meta("raca_id")


## true se a malha é peça de raça que deve acompanhar a cor do personagem.
static func segue_cor(n: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is Node3D and (p as Node3D).has_meta(META_SEGUE_COR):
			return bool((p as Node3D).get_meta(META_SEGUE_COR))
		p = p.get_parent()
	return false


# --------------------------------------------------------------------------
static func _criar_peca(modelo: Node3D, id: String, p: Dictionary, i: int) -> void:
	var destino := modelo.find_child(String(p["no"]), true, false) as Node3D
	if destino == null:
		push_warning("[Racas] nó '%s' não existe neste modelo" % p["no"])
		return
	var cx := Acessorios.caixa_do_no(destino)

	var m := MeshInstance3D.new()
	m.name = "%s%s_%d" % [MARCA, id, i]
	var caixa := BoxMesh.new()
	var tam: Vector3 = p["tam"]
	caixa.size = Vector3(cx.size.x * tam.x, cx.size.y * tam.y, cx.size.z * tam.z)
	m.mesh = caixa

	# A âncora é 0..1 DENTRO da caixa do destino; a peça nasce centrada nela.
	var a: Vector3 = p["ancora"]
	m.position = cx.position + Vector3(cx.size.x * a.x, cx.size.y * a.y, cx.size.z * a.z)
	if p.has("rot"):
		m.rotation = p["rot"]

	if bool(p.get("segue_cor", false)):
		# Sem material próprio: quem pinta o corpo pinta esta peça junto.
		m.set_meta(META_SEGUE_COR, true)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = p.get("cor", CINZA)
		mat.roughness = 1.0
		m.material_override = mat
	destino.add_child(m)


static func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(_todos(f))
	return out
