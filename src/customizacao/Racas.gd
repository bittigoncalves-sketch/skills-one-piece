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
## Mantidos como apelido: a bateria e o menu já os usavam por este nome, e o
## núcleo comum agora mora em `Adornos`.
const META_SEGUE_COR := Adornos.META_SEGUE_COR
const META_ESCALA := Adornos.META_ESCALA

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
			{"no": "Head", "tam": Vector3(0.26, 0.95, 0.26), "ancora": Vector3(0.20, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, 0.30), "cor": OSSO},
			{"no": "Head", "tam": Vector3(0.26, 0.95, 0.26), "ancora": Vector3(0.80, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, -0.30), "cor": OSSO},
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
			{"no": "Head", "tam": Vector3(0.26, 1.45, 0.18), "ancora": Vector3(0.30, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.10), "cor": PELE},
			{"no": "Head", "tam": Vector3(0.26, 1.45, 0.18), "ancora": Vector3(0.70, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.10), "cor": PELE},
			# "rabinho de coelho QUADRADO" — o dono foi explícito, e cubo é o que
			# combina com um jogo feito de caixas.
			{"no": "Torso", "tam": Vector3(0.46, 0.46, 0.46), "ancora": Vector3(0.5, 0.14, 1.0),
			 "pivo": Vector3(0, 0, -0.6), "cor": Color(0.98, 0.97, 0.95)},
		],
	},
	"mink_lobo": {
		"nome": "Mink Lobo",
		"descricao": "orelhas e rabo na cor do personagem",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.32, 0.80, 0.22), "ancora": Vector3(0.26, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.28), "segue_cor": true},
			{"no": "Head", "tam": Vector3(0.32, 0.80, 0.22), "ancora": Vector3(0.74, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.28), "segue_cor": true},
			# ⚠️ `pivo` na face DIANTEIRA: a cauda tem 3× a profundidade do tronco
			# e, centrada na âncora, atravessava o corpo e vazava pela FRENTE.
			{"no": "Torso", "tam": Vector3(0.40, 0.40, 3.0), "ancora": Vector3(0.5, 0.26, 1.0),
			 "rot": Vector3(-0.60, 0.0, 0.0), "pivo": Vector3(0, 0, -1), "segue_cor": true},
		],
	},
}


static func ids() -> Array:
	return CATALOGO.keys()


static func dados(id: String) -> Dictionary:
	return CATALOGO.get(id, {})


static func atual(modelo: Node3D) -> String:
	return Adornos.id_aplicado(modelo, MARCA, MARCA)


## Troca a raça. Tira a anterior INTEIRA antes — ninguém é de duas raças.
## É esta a diferença para os acessórios, que excluem só por parte do corpo.
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
		Adornos.criar_peca(modelo, MARCA, id, p, i)
		i += 1
	var escalas: Dictionary = d.get("escalas", {})
	if not escalas.is_empty():
		Adornos.aplicar_escalas(modelo, escalas, MARCA)
		for nome_no in escalas:
			var no := modelo.find_child(String(nome_no), true, false) as Node3D
			if no:
				no.set_meta("item_id", id)
	return true


static func remover(modelo: Node3D) -> void:
	Adornos.remover_marca(modelo, MARCA)
	Adornos.restaurar_escalas(modelo, MARCA)


static func segue_cor(n: Node) -> bool:
	return Adornos.segue_cor(n)
