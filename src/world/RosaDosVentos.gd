class_name RosaDosVentos
extends Node3D
# ============================================================================
#  ROSA DOS VENTOS — os pontos invisíveis que dizem para onde é cada lado.
# ============================================================================
#
#  POR QUE ISTO EXISTE
#  -------------------
#  Em 2026-08-25 descobriu-se que `find_best_melee_target()` e
#  `perform_melee_lunge()` calculavam a frente do jogador como
#  `-Vector3.FORWARD.rotated(Vector3.UP, _yaw)`. `Vector3.FORWARD` **já é**
#  (0, 0, −1): negá-la dá (0, 0, +1) — PARA TRÁS. Medido contra a direção que a
#  hitbox realmente usa, o produto escalar era **−1,00 em TODO yaw**.
#
#      yaw= 0.00  dot = −1.00
#      yaw= 1.57  dot = −1.00
#      yaw= 3.14  dot = −1.00
#
#  O cone de auto-mira escolhia alvos ATRÁS do jogador e o lunge o empurrava
#  para LONGE do alvo. Passou semanas despercebido porque a hitbox usava a
#  direção certa e o golpe acertava — só o auxílio estava invertido.
#
#  A causa de fundo não é a linha errada: é que **a convenção de direção deste
#  jogo nunca esteve escrita em lugar nenhum**. Ela vivia repetida em quatro
#  expressões espalhadas (`move_frame.gd:65`, `melee_controller.gd:154`,
#  `health_controller.gd:161`, `Player.gd:1736`) e, quando a quinta cópia saiu
#  errada, não havia contra o que conferir. Este arquivo é esse "contra o que".
#
# ============================================================================
#  A TABELA DA CONVENÇÃO — eixo ↔ cardeal ↔ corpo
# ============================================================================
#
#  Esta é a informação que some primeiro e custa mais caro. Ela é DECLARADA
#  aqui e PROVADA em `tools/dev_tests/medir_rosa_dos_ventos.gd`, que compara
#  cada linha com a expressão que o jogo de fato usa.
#
#  ┌──────────┬────────────────┬─────────────────┬──────────────────────────┐
#  │ cardeal  │ eixo do mundo  │ Vector3         │ constante do Godot       │
#  ├──────────┼────────────────┼─────────────────┼──────────────────────────┤
#  │ NORTE    │ −Z             │ ( 0,  0, −1)    │ Vector3.FORWARD          │
#  │ SUL      │ +Z             │ ( 0,  0, +1)    │ Vector3.BACK             │
#  │ LESTE    │ +X             │ (+1,  0,  0)    │ Vector3.RIGHT            │
#  │ OESTE    │ −X             │ (−1,  0,  0)    │ Vector3.LEFT             │
#  │ CIMA     │ +Y             │ ( 0, +1,  0)    │ Vector3.UP               │
#  │ BAIXO    │ −Y             │ ( 0, −1,  0)    │ Vector3.DOWN             │
#  └──────────┴────────────────┴─────────────────┴──────────────────────────┘
#
#  ⚠️ `Vector3.FORWARD` É (0, 0, −1), NÃO "a frente do personagem".
#  O nome engana: ele é a constante de eixo, e é igual ao NORTE do mundo. A
#  frente do PERSONAGEM só coincide com ele quando `yaw == 0`. Foi exatamente
#  essa leitura ("FORWARD é a frente, então −FORWARD deve ser 'para frente a
#  partir de mim'") que produziu o bug. Neste arquivo `Vector3.FORWARD` NÃO é
#  usado para nada relativo ao corpo — só aparece na prova de que NORTE == −Z.
#
#  RELATIVAS AO CORPO — a partir do `_yaw` do Player:
#
#  ┌────────────────┬───────────────────────────────┬──────────────────────┐
#  │ relativa       │ expressão canônica            │ com yaw = 0 dá       │
#  ├────────────────┼───────────────────────────────┼──────────────────────┤
#  │ FRENTE         │ −Basis.from_euler(0,yaw,0).z  │ (0,0,−1)  = NORTE    │
#  │ TRÁS           │ +Basis.from_euler(0,yaw,0).z  │ (0,0,+1)  = SUL      │
#  │ DIREITA        │ +Basis.from_euler(0,yaw,0).x  │ (+1,0,0)  = LESTE    │
#  │ ESQUERDA       │ −Basis.from_euler(0,yaw,0).x  │ (−1,0,0)  = OESTE    │
#  │ CIMA_DO_CORPO  │ +Basis.from_euler(0,yaw,0).y  │ (0,+1,0)  = CIMA     │
#  │ BAIXO_DO_CORPO │ −Basis.from_euler(0,yaw,0).y  │ (0,−1,0)  = BAIXO    │
#  └────────────────┴───────────────────────────────┴──────────────────────┘
#
#  SENTIDO DO YAW (o outro jeito de errar por 180°, e o mais silencioso):
#  o eixo Y do Godot é destro, então **yaw crescente gira para a ESQUERDA**
#  vista de cima. Consequências medíveis, todas conferidas pela sonda:
#
#      yaw = 0      → FRENTE = NORTE (−Z)
#      yaw = +π/2   → FRENTE = OESTE (−X)      ← e NÃO leste
#      yaw = +π     → FRENTE = SUL   (+Z)
#      yaw = −π/2   → FRENTE = LESTE (+X)
#
#  Isso combina com o mouse: `Player._yaw -= event.relative.x * sens` — puxar o
#  mouse para a direita DIMINUI o yaw, e o personagem vira para o LESTE. Se
#  alguém "consertar" esse sinal, a rosa denuncia na hora.
#
#  A VOLTA (direção → yaw) é `atan2(-dir.x, -dir.z)`, que é o que o
#  `perform_melee_lunge` e o `Player.aplicar_mira` já usam. `yaw_para()` é essa
#  mesma conta com nome, e a sonda prova a ida-e-volta: `frente(yaw_para(d)) == d`.
#
# ============================================================================
#  O QUE ESTE NÓ É, E O QUE ELE NÃO É
# ============================================================================
#
#  A VERDADE são as funções `static` — elas não precisam de nó, de cena nem de
#  jogo rodando, e é por isso que a sonda de convenção roda em 1 s sem subir a
#  partida (e sem disputar a porta com ninguém).
#
#  O NÓ é só a MATERIALIZAÇÃO: um ponto (Node3D **sem malha**) por direção,
#  pendurado no mundo, para que qualquer medição tenha um alvo geométrico de
#  verdade em vez de um número solto. Em partida normal ele:
#    • não tem malha nenhuma  → não aparece;
#    • não tem `_process`     → custo ZERO de quadro (`set_process(false)`);
#    • não tem estado         → nada a replicar em rede.
#
#  LIGAR A VISUALIZAÇÃO (senão ninguém confere com o olho):
#    • tecla **F9** em jogo (é `_unhandled_key_input`: só roda quando alguém
#      aperta uma tecla, nunca por quadro);
#    • `SOP_ROSA=1` no ambiente, para já nascer ligada num teste com tela;
#    • `VISIVEL_POR_PADRAO = true` aqui embaixo, para quem estiver depurando.
#  As malhas e os rótulos são criados na PRIMEIRA vez que liga e destruídos ao
#  desligar — quem nunca liga nunca paga.
#
#  DECISÃO DECLARADA (regra de complexidade adequada):
#    • benefício imediato: existe UM lugar que diz onde é o norte, e ele é
#      testável;
#    • impacto futuro: toda sonda de direção nova compara contra a rosa em vez
#      de reescrever `Basis.from_euler` pela quinta vez;
#    • manutenção: ~1 arquivo, sem estado, sem rede, sem quadro;
#    • extensão: direção nova = uma linha em `MUNDO`/`RELATIVAS`;
#    • custo: um Node3D com 18 filhos vazios por partida;
#    • riscos: se alguém mudar a convenção do jogo e não a tabela, a sonda passa
#      a reprovar — que é o comportamento desejado, não o risco.
# ============================================================================

## Distância dos pontos ao centro da rosa. Só afeta a visualização e a
## conveniência de quem quiser um alvo no mundo; as direções são normalizadas.
const RAIO := 12.0

## Ligue aqui para nascer visível (ou use F9 / SOP_ROSA=1).
const VISIVEL_POR_PADRAO := false

# ------------------------------------------------------------ MUNDO (cardeal)
const NORTE := Vector3(0, 0, -1)
const SUL := Vector3(0, 0, 1)
const LESTE := Vector3(1, 0, 0)
const OESTE := Vector3(-1, 0, 0)
const CIMA := Vector3(0, 1, 0)
const BAIXO := Vector3(0, -1, 0)

## Nome → direção, no referencial do MUNDO. A ordem é a de leitura da tabela.
const MUNDO := {
	"NORTE": NORTE,
	"SUL": SUL,
	"LESTE": LESTE,
	"OESTE": OESTE,
	"CIMA": CIMA,
	"BAIXO": BAIXO,
}

## Só os quatro do plano do chão, em ordem de bússola (N → L → S → O). É esta
## lista que as sondas varrem: um yaw errado por sinal troca LESTE com OESTE e
## deixa NORTE/SUL intactos, então varrer os quatro separa "invertido 180°" de
## "espelhado no yaw" — coisa que dois testes frontais não conseguem.
const CARDEAIS := ["NORTE", "LESTE", "SUL", "OESTE"]

# ------------------------------------------------------------- EIXOS (crus)
## Os eixos sem apelido. Existem para que uma medição possa ser expressa no
## vocabulário do motor ("foi para +Z") sem passar pela tradução cardeal — e
## para que a tradução em si seja conferível.
const EIXOS := {
	"+X": Vector3(1, 0, 0),
	"-X": Vector3(-1, 0, 0),
	"+Y": Vector3(0, 1, 0),
	"-Y": Vector3(0, -1, 0),
	"+Z": Vector3(0, 0, 1),
	"-Z": Vector3(0, 0, -1),
}

## Nomes das direções relativas ao corpo, na ordem da tabela do cabeçalho.
const RELATIVAS := ["FRENTE", "TRAS", "DIREITA", "ESQUERDA", "CIMA_DO_CORPO", "BAIXO_DO_CORPO"]

# ============================================================================
#  API ESTÁTICA — a fonte da verdade. Não precisa de nó nem de jogo rodando.
# ============================================================================

## A base do corpo a partir do yaw. É a MESMA expressão de `move_frame.gd:65`,
## `melee_controller.gd:154` e `health_controller.gd:161` — escrita uma vez.
static func base_do_corpo(yaw: float) -> Basis:
	return Basis.from_euler(Vector3(0, yaw, 0))


## ⚠️ A frente é `-base.z`, NUNCA `-Vector3.FORWARD.rotated(...)`.
static func frente(yaw: float) -> Vector3:
	return -base_do_corpo(yaw).z


static func tras(yaw: float) -> Vector3:
	return base_do_corpo(yaw).z


static func direita(yaw: float) -> Vector3:
	return base_do_corpo(yaw).x


static func esquerda(yaw: float) -> Vector3:
	return -base_do_corpo(yaw).x


## O "cima do corpo" só difere do CIMA do mundo quando houver pitch/roll no
## corpo — hoje não há (o Player só gira em yaw). Existe para que a rosa cubra
## as seis relativas pedidas e para que, no dia em que houver, a conta já esteja
## no lugar certo em vez de virar mais um `Vector3.UP` chumbado.
static func cima_do_corpo(yaw: float) -> Vector3:
	return base_do_corpo(yaw).y


static func baixo_do_corpo(yaw: float) -> Vector3:
	return -base_do_corpo(yaw).y


## Todas as relativas de uma vez, nome → direção.
static func relativas(yaw: float) -> Dictionary:
	var b := base_do_corpo(yaw)
	return {
		"FRENTE": -b.z,
		"TRAS": b.z,
		"DIREITA": b.x,
		"ESQUERDA": -b.x,
		"CIMA_DO_CORPO": b.y,
		"BAIXO_DO_CORPO": -b.y,
	}


## Uma direção pelo nome, olhando as três famílias (mundo, eixos, corpo).
## `yaw` só é usado pelas relativas.
static func direcao(nome: String, yaw: float = 0.0) -> Vector3:
	var n := nome.to_upper()
	if MUNDO.has(n):
		return MUNDO[n]
	if EIXOS.has(nome):
		return EIXOS[nome]
	var rel := relativas(yaw)
	if rel.has(n):
		return rel[n]
	push_warning("[RosaDosVentos] direção desconhecida: '%s'" % nome)
	return Vector3.ZERO


## A VOLTA: que yaw faz o personagem encarar esta direção.
## É `atan2(-x, -z)`, a mesma conta de `Player.perform_melee_lunge` e
## `Player.aplicar_mira` — aqui com nome e com teste de ida-e-volta.
static func yaw_para(dir: Vector3) -> float:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 1e-9:
		return 0.0
	d = d.normalized()
	return atan2(-d.x, -d.z)


## Classifica um vetor medido: devolve o nome da direção do MUNDO mais próxima.
## É o que transforma "foi para (0.02, 0, 0.99)" em "foi para o SUL" no relatório.
static func nome_mais_proximo(v: Vector3) -> String:
	if v.length_squared() < 1e-9:
		return "?"
	var d := v.normalized()
	var melhor := "?"
	var maior := -2.0
	for nome in MUNDO:
		var p: float = d.dot(MUNDO[nome])
		if p > maior:
			maior = p
			melhor = nome
	return melhor


## O nome da relativa mais próxima, dado o yaw do corpo. Serve para dizer
## "o golpe saiu para TRÁS" em vez de "para o sul", que é a leitura que importa
## quando o defeito é de frente invertida.
static func nome_relativo_mais_proximo(v: Vector3, yaw: float) -> String:
	if v.length_squared() < 1e-9:
		return "?"
	var d := v.normalized()
	var melhor := "?"
	var maior := -2.0
	for nome in relativas(yaw):
		var p: float = d.dot(relativas(yaw)[nome])
		if p > maior:
			maior = p
			melhor = nome
	return melhor

# ============================================================================
#  O NÓ — a materialização. Invisível por padrão.
# ============================================================================

var _visivel := false
var _grupo_corpo: Node3D = null
var _jogador: Node3D = null
var _pontos: Dictionary = {}     # nome -> Node3D (o ponto invisível)
var _visual: Array[Node] = []    # tudo que a visualização criou (some junto)


## Único jeito correto de pôr a rosa no mundo. Chamado por `Main._ready()`,
## ao lado de `WorldEnv.apply` / `MapBuilder.build` — mesma família de sistemas.
static func instalar(pai: Node) -> RosaDosVentos:
	var r := RosaDosVentos.new()
	r.name = "RosaDosVentos"
	pai.add_child(r)
	return r


func _ready() -> void:
	_montar_pontos()
	# ⚠️ CUSTO ZERO DE QUADRO. Sem isto o nó rodaria `_process` a partida
	# inteira para atualizar pontos que ninguém está vendo.
	set_process(false)
	if VISIVEL_POR_PADRAO or OS.get_environment("SOP_ROSA") == "1":
		definir_visivel(true)


# Um Node3D por direção. SEM malha: é ponto de referência, não é cenário.
func _montar_pontos() -> void:
	var g_mundo := Node3D.new()
	g_mundo.name = "MUNDO"
	add_child(g_mundo)
	for nome in MUNDO:
		_ponto(g_mundo, nome, MUNDO[nome])

	var g_eixos := Node3D.new()
	g_eixos.name = "EIXOS"
	add_child(g_eixos)
	for nome in EIXOS:
		# `+`/`-` não são nomes de nó legíveis num caminho; o eixo vira palavra.
		var seguro: String = ("EIXO_MAIS_" if nome.begins_with("+") else "EIXO_MENOS_") + nome.substr(1)
		_ponto(g_eixos, seguro, EIXOS[nome])

	# ⚠️ AS RELATIVAS ACOMPANHAM O YAW POR CONSTRUÇÃO, não por conta repetida:
	# os seis filhos nascem na pose de yaw=0 e é o GRUPO que gira. Assim é
	# impossível um ponto relativo discordar do outro — eles compartilham a
	# única rotação. (`_atualizar()` só escreve `_grupo_corpo.rotation.y`.)
	_grupo_corpo = Node3D.new()
	_grupo_corpo.name = "CORPO"
	add_child(_grupo_corpo)
	var base := relativas(0.0)
	for nome in RELATIVAS:
		_ponto(_grupo_corpo, nome, base[nome])


func _ponto(pai: Node3D, nome: String, dir: Vector3) -> void:
	var n := Node3D.new()
	n.name = nome
	n.position = dir * RAIO
	pai.add_child(n)
	_pontos[nome] = n


## O ponto invisível de uma direção, pelo nome — para quem quiser um alvo no
## mundo em vez de um vetor.
func ponto(nome: String) -> Node3D:
	return _pontos.get(nome, null)


## O yaw que a rosa está usando hoje (o do jogador local, se houver).
func yaw_atual() -> float:
	return _grupo_corpo.rotation.y if _grupo_corpo else 0.0

# ------------------------------------------------------------- visualização
## F9. `_unhandled_key_input` só é chamado quando alguém aperta uma tecla —
## nunca por quadro. É o único custo que a rosa tem com a visualização desligada.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F9:
		definir_visivel(not _visivel)
		get_viewport().set_input_as_handled()


func definir_visivel(ligar: bool) -> void:
	if ligar == _visivel:
		return
	_visivel = ligar
	set_process(ligar)
	if ligar:
		_criar_visual()
		_atualizar()
		print("🧭 Rosa dos Ventos VISÍVEL (F9 desliga) — norte = −Z, frente = −Basis.z")
	else:
		# ⚠️ TUDO que a visualização cria vai para `_visual` e some junto. A
		# primeira versão pendurava as esferas nos PONTOS e só liberava a lista:
		# desligar deixava as esferas em cena, ou seja, a rosa "invisível"
		# passaria a aparecer no jogo — exatamente o que ela não pode fazer.
		for n in _visual:
			if is_instance_valid(n):
				n.queue_free()
		_visual.clear()
		print("🧭 Rosa dos Ventos oculta")


func _criar_visual() -> void:
	for nome in _pontos:
		var alvo: Node3D = _pontos[nome]
		var cor := Color(0.55, 0.85, 1.0)               # relativas ao corpo: ciano
		if MUNDO.has(nome):
			cor = Color(1.0, 0.85, 0.25)                # cardeais do mundo: âmbar
		elif nome.begins_with("EIXO_"):
			cor = Color(0.75, 0.75, 0.8)                # eixos crus: cinza
		_marcador(alvo, nome, cor)
		# O rastro nasce no GRUPO (MUNDO/EIXOS/CORPO), não no ponto: assim a
		# linha do CORPO gira junto com o yaw, sem nenhuma conta extra.
		_rastro(alvo.get_parent(), alvo.position, cor)


func _marcador(pai: Node3D, nome: String, cor: Color) -> void:
	var esfera := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.35
	m.height = 0.7
	esfera.mesh = m
	esfera.material_override = _mat(cor)
	pai.add_child(esfera)
	_visual.append(esfera)

	var rot := Label3D.new()
	rot.text = nome
	rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rot.no_depth_test = true
	rot.modulate = cor
	rot.pixel_size = 0.012
	rot.position = Vector3(0, 0.8, 0)
	pai.add_child(rot)
	_visual.append(rot)


# Uma linha do centro do grupo até o ponto, para o olho seguir a direção.
func _rastro(grupo: Node3D, ate: Vector3, cor: Color) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _mat(cor))
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(ate)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	grupo.add_child(mi)
	_visual.append(mi)


# ⚠️ Sem `emission`: material unshaded DESCARTA emissão (docs/NUMEROS_MEDIDOS
# §3). Cor forte no albedo é o que de fato se vê.
func _mat(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = cor
	return mat


# Só roda com a visualização LIGADA (`set_process` é falso fora disso).
func _process(_delta: float) -> void:
	_atualizar()


func _atualizar() -> void:
	if not is_instance_valid(_jogador):
		_jogador = _achar_jogador_local()
	if is_instance_valid(_jogador):
		global_position = _jogador.global_position
		# As relativas acompanham o `_yaw` do personagem — uma rotação só.
		if _grupo_corpo and "_yaw" in _jogador:
			_grupo_corpo.rotation.y = _jogador._yaw


func _achar_jogador_local() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and p.is_multiplayer_authority():
			return p
	return null
