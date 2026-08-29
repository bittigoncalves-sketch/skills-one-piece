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

## As cores que uma RAÇA impõe. Ver a nota de `pele` logo abaixo do catálogo.
const VERMELHO_ONI := Color(0.70, 0.16, 0.14)
const AZUL_TUBARAO := Color(0.46, 0.67, 0.79)
const PRETO_LUNAR := Color(0.16, 0.15, 0.18)
const BRANCO_LUNAR := Color(0.95, 0.95, 0.93)
const CHIFRE := Color(0.85, 0.70, 0.22)

const CATALOGO := {
	# 1. O BASE. Existe como escolha explícita, e não como "nenhuma raça": o
	# dono listou humano entre as doze, e sem ele não há como VOLTAR ao padrão
	# depois de experimentar as outras.
	"humano": {
		"nome": "Humano",
		"descricao": "o personagem base",
		"pecas": [],
	},
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
		"descricao": "pele vermelha e chifres",
		"pele": VERMELHO_ONI,
		"pecas": [
			{"no": "Head", "tam": Vector3(0.26, 0.95, 0.26), "ancora": Vector3(0.20, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, 0.30), "cor": CHIFRE},
			{"no": "Head", "tam": Vector3(0.26, 0.95, 0.26), "ancora": Vector3(0.80, 1.0, 0.55),
			 "rot": Vector3(0.0, 0.0, -0.30), "cor": CHIFRE},
		],
	},
	"sharkman": {
		"nome": "Sharkman",
		"descricao": "cabeça de tubarão, barbatanas nas costas e nos braços",
		"pele": AZUL_TUBARAO,
		"pecas": [
			# CABEÇA DE TUBARÃO: focinho que avança, barbatana no alto do crânio
			# e a fileira de dentes. É o focinho que faz a silhueta — sem ele a
			# cabeça continua sendo um cubo azul.
			# ⚠️ O FOCINHO PRECISA DE CONTRASTE. Na primeira versão ele era da
			# mesma cor da pele (`AZUL_TUBARAO`) e SUMIA: a peça estava lá, com
			# 0,4 de profundidade, e a cabeça continuava lendo como um cubo azul.
			# Tubarão de verdade é escuro em cima e claro embaixo — é essa
			# separação que faz a forma aparecer, e não o tamanho da caixa.
			{"no": "Head", "tam": Vector3(0.62, 0.36, 0.58), "ancora": Vector3(0.5, 0.30, 0.0),
			 "pivo": Vector3(0, 0, 1), "cor": Color(0.72, 0.85, 0.92)},
			{"no": "Head", "tam": Vector3(0.66, 0.22, 0.42), "ancora": Vector3(0.5, 0.52, 0.0),
			 "pivo": Vector3(0, 0, 1), "cor": Color(0.28, 0.46, 0.62)},
			# a fileira de dentes, entre o focinho claro e o dorso escuro
			{"no": "Head", "tam": Vector3(0.60, 0.09, 0.46), "ancora": Vector3(0.5, 0.40, 0.0),
			 "pivo": Vector3(0, 0, 1), "cor": Color(0.98, 0.98, 0.96)},
			{"no": "Head", "tam": Vector3(0.14, 0.70, 0.42), "ancora": Vector3(0.5, 1.0, 0.55),
			 "rot": Vector3(-0.25, 0.0, 0.0), "cor": AZUL_TUBARAO},
			# barbatana dorsal
			{"no": "Torso", "tam": Vector3(0.12, 0.85, 0.95), "ancora": Vector3(0.5, 0.85, 1.0),
			 "rot": Vector3(-0.30, 0.0, 0.0), "cor": AZUL_TUBARAO},
			# barbatanas dos ANTEBRAÇOS — na imagem elas saem do lado de fora do
			# braço, apontando para trás.
			{"no": "ForeArm_R", "tam": Vector3(0.22, 0.75, 1.30), "ancora": Vector3(1.0, 0.55, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.35), "cor": AZUL_TUBARAO},
			{"no": "ForeArm_L", "tam": Vector3(0.22, 0.75, 1.30), "ancora": Vector3(0.0, 0.55, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.35), "cor": AZUL_TUBARAO},
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
		"descricao": "cara branca e cabelo colorido",
		# ⚠️ MUDOU EM 2026-08-29. Era só um nariz vermelho; o dono redefiniu a
		# raça como "cara branca e cabelo colorido". O nariz fica — é o que
		# sobrou de icônico e aparece na folha —, mas quem faz a raça agora é a
		# máscara branca e a juba arco-íris.
		"pecas": [
			# ⚠️ A CARA BRANCA FICA ATRÁS DOS OLHOS. Na primeira versão ela era
			# uma placa em `z = 0.0` com 0,10 de profundidade — mais funda que o
			# olho, que vive no mesmo plano — e TAPAVA os dois. O jogador
			# escolhia palhaço e perdia o rosto. Empurrada para dentro
			# (`z = 0.05`) e mais fina, ela pinta a cara e o olho fica na frente.
			{"no": "Head", "tam": Vector3(0.94, 0.94, 0.05), "ancora": Vector3(0.5, 0.52, 0.05),
			 "cor": Color(0.97, 0.97, 0.96)},
			{"no": "Head", "tam": Vector3(0.20, 0.20, 0.22), "ancora": Vector3(0.5, 0.40, 0.0),
			 "cor": Color(0.90, 0.13, 0.13)},
			# A JUBA: seis tufos em VOLTA do crânio, alternando a cor. Os quatro
			# das quinas mais o da nuca e o da testa fecham o anel — amontoados
			# de um lado, como estavam, liam como um chapéu torto.
			{"no": "Head", "tam": Vector3(0.30, 0.62, 0.30), "ancora": Vector3(0.02, 0.90, 0.18),
			 "cor": Color(0.88, 0.15, 0.15)},
			{"no": "Head", "tam": Vector3(0.30, 0.62, 0.30), "ancora": Vector3(0.98, 0.90, 0.18),
			 "cor": Color(0.20, 0.45, 0.90)},
			{"no": "Head", "tam": Vector3(0.30, 0.62, 0.30), "ancora": Vector3(0.02, 0.90, 0.82),
			 "cor": Color(0.95, 0.75, 0.15)},
			{"no": "Head", "tam": Vector3(0.30, 0.62, 0.30), "ancora": Vector3(0.98, 0.90, 0.82),
			 "cor": Color(0.20, 0.68, 0.32)},
			{"no": "Head", "tam": Vector3(0.55, 0.52, 0.26), "ancora": Vector3(0.5, 0.92, 1.0),
			 "cor": Color(0.62, 0.25, 0.80)},
			{"no": "Head", "tam": Vector3(0.55, 0.48, 0.26), "ancora": Vector3(0.5, 0.94, 0.02),
			 "cor": Color(0.95, 0.45, 0.12)},
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
	# A variante da neve é o MESMO desenho do lobo, mas branca e sem seguir a cor
	# do personagem: é isso que a distingue na folha, e é a razão de ser uma raça
	# própria em vez de um tom do Mink Lobo.
	"mink_lobo_neve": {
		"nome": "Mink Lobo da Neve",
		"descricao": "lobo branco",
		"pecas": [
			{"no": "Head", "tam": Vector3(0.32, 0.80, 0.22), "ancora": Vector3(0.26, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, 0.28), "cor": Color(0.96, 0.97, 0.98)},
			{"no": "Head", "tam": Vector3(0.32, 0.80, 0.22), "ancora": Vector3(0.74, 1.0, 0.5),
			 "rot": Vector3(0.0, 0.0, -0.28), "cor": Color(0.96, 0.97, 0.98)},
			{"no": "Torso", "tam": Vector3(0.40, 0.40, 3.0), "ancora": Vector3(0.5, 0.26, 1.0),
			 "rot": Vector3(-0.60, 0.0, 0.0), "pivo": Vector3(0, 0, -1),
			 "cor": Color(0.96, 0.97, 0.98)},
			# a gola de pelo, que na folha é o que separa o lobo da neve do outro
			{"no": "Torso", "tam": Vector3(1.15, 0.30, 1.25), "ancora": Vector3(0.5, 1.0, 0.5),
			 "cor": Color(0.99, 0.99, 1.0)},
		],
	},
	# ⚠️ SEM PEÇAS: o gigante não ganha nada pendurado, ele CRESCE. Ver
	# `escala_corpo` na nota abaixo do catálogo — é a única raça que mexe em
	# colisão e câmera, e por isso a única com efeito em jogo além do visual.
	"gigante": {
		"nome": "Gigante",
		"descricao": "muito maior que os outros",
		"escala_corpo": 1.45,
		"pecas": [],
	},
	"lunariano": {
		"nome": "Anjo Lunariano",
		"descricao": "asas negras, pele escura, cabelo branco e a chama nas costas",
		"pele": PRETO_LUNAR,
		# "cabelos sempre brancos como REGRA" — palavra do dono. A raça manda na
		# cor do cabelo, e a escolha do jogador na paleta é ignorada enquanto ela
		# estiver posta.
		"cabelo": BRANCO_LUNAR,
		# A chama das costas é VFX, não caixa: o dono pediu "literalmente uma
		# chama com animação". Ver `fx` na nota abaixo.
		"fx": "chama_lunar",
		"pecas": [
			{"no": "Torso", "tam": Vector3(1.05, 1.30, 0.12), "ancora": Vector3(0.02, 0.82, 1.0),
			 "rot": Vector3(0.0, 0.0, 0.42), "cor": Color(0.08, 0.08, 0.10)},
			{"no": "Torso", "tam": Vector3(1.05, 1.30, 0.12), "ancora": Vector3(0.98, 0.82, 1.0),
			 "rot": Vector3(0.0, 0.0, -0.42), "cor": Color(0.08, 0.08, 0.10)},
		],
	},
}


## A cor que a RAÇA impõe ao corpo, ou alpha 0 quando ela não impõe nenhuma.
##
## ⚠️ A RAÇA GANHA DA PALETA, e isso é decisão do dono: "oni: pele vermelha",
## "lunariano: pele escura". Uma raça que se define pela cor da pele não pode
## ficar verde porque o jogador escolheu verde na aba Cor — deixaria de ser a
## raça. Quem não impõe nada (humano, skypiean, minks…) continua obedecendo à
## escolha, que é o comportamento de sempre.
static func pele_de(id: String) -> Color:
	return CATALOGO.get(id, {}).get("pele", Color(0, 0, 0, 0))


## Idem para o cabelo. Hoje só o Lunariano usa — "cabelos sempre brancos como
## REGRA", palavra do dono.
static func cabelo_de(id: String) -> Color:
	return CATALOGO.get(id, {}).get("cabelo", Color(0, 0, 0, 0))


## Quanto o corpo INTEIRO cresce. 1.0 = tamanho normal. Só o Gigante usa, e é a
## única característica de raça que sai do visual e entra no jogo: mexe em
## colisão e câmera (decisão do dono, 2026-08-29).
static func escala_de(id: String) -> float:
	return float(CATALOGO.get(id, {}).get("escala_corpo", 1.0))


## O efeito animado que a raça pendura no corpo, ou "" se não tem. Hoje só a
## chama das costas do Lunariano — caixa não serve, o pedido foi "literalmente
## uma chama com animação".
static func fx_de(id: String) -> String:
	return String(CATALOGO.get(id, {}).get("fx", ""))


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
	# A CHAMA (só o Lunariano, hoje). Nasce com a MARCA no nome para sair na
	# próxima troca de raça pelo mesmo caminho das caixas — sem isso ela viraria
	# órfã inarredável, que é o mesmo problema que a varredura por prefixo já
	# resolve para as peças.
	var fx := fx_de(id)
	if fx == "chama_lunar":
		var costas := modelo.find_child("Torso", true, false) as Node3D
		if costas != null:
			var cx := Acessorios.caixa_do_no(costas)
			var chama := ChamaLunar.criar()
			chama.name = "%s%s_chama" % [MARCA, id]
			costas.add_child(chama)
			# nas costas, na altura das omoplatas
			chama.position = cx.position + Vector3(
				cx.size.x * 0.5, cx.size.y * 0.72, cx.size.z * 1.06)

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
