class_name VidaEnergiaHud
extends Control
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "vida_energia"
# ============================================================================
#  VIDA E ENERGIA NA TELA DO MODO HISTÓRIA (pedido do dono, 21/09/2026).
#
#  As mesmas barras da arena (`BarraHud`, cores de `Estilo`), no mesmo canto
#  superior esquerdo — mas SÓ vida e energia: dash, dano total e mira são coisas
#  da arena que o personagem da história não tem (ver cabeçalho da `HistoriaHud`).
#
#  Lê o corpo a cada quadro, como o `StatsHud`: dano, cura, renascer e ponto de
#  Vitalidade mexem na vida por caminhos diferentes, e ler o valor é mais barato
#  do que escutar todos eles. A barra só redesenha quando o valor muda.
#
#  O número é o MESMO da janela de status (M) — os dois usam `vida_exibida`:
#  vida arredonda para o mais perto, mas nunca mostra 0 com o corpo vivo (0,3 é
#  vivo). Arredondar para cima, como a janela fazia, mostrava 18 com a vida em
#  17,002: a regeneração (0,5%/s) tira a vida do inteiro logo depois do dano.
#  Energia arredonda para BAIXO (não se gasta o que não se tem).
#
#  ⚠️ Não cita `Player` por nome: quem entrega o corpo é a `HistoriaHud`. Um
#  script que cita o Player puxa o Player para a compilação de quem só usa a HUD
#  (armadilha do test_modo_historia).
#
#  Duplica as ~5 linhas de rótulo do `StatsHud._set_bar` de propósito: mexer no
#  arquivo da arena para compartilhar não muda nada que se veja. GATILHO: um
#  terceiro HUD com barra e rótulo → extrair o par para um componente comum.
# ============================================================================

const LARGURA := 340.0   # as mesmas do `StatsHud`: a barra é a mesma nos dois modos
const ALTURA := 28.0
const MARGEM := 20.0
const ESPACO := 10.0
## "NIVEL:n" acima da barra de vida (17/10/2026, pedido do dono). O rótulo mora FORA do
## retângulo do controle (y negativo), e o controle desce `FAIXA_DO_NIVEL` para ele caber.
const FAIXA_DO_NIVEL := 26.0

var _nivel_rotulo: Label
var _vida: BarraHud
var _vida_rotulo: Label
var _energia: BarraHud
var _energia_rotulo: Label
## Contador de ressurreição ao lado da vida (pedido do dono, 18/11/2026): 1 por janela de 30 min (`ReanimacaoDoCoracao.MAX_TENTATIVAS`).
var _ressurreicao: Label
var _chances := -1
var _ultimo := PackedInt32Array([-1, -1, -1, -1])   # vida, máx, energia, máx já escritos


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(MARGEM, MARGEM + FAIXA_DO_NIVEL)
	size = Vector2(LARGURA, ALTURA * 2.0 + ESPACO)
	_nivel_rotulo = Estilo.texto(18, Color(1, 1, 1))
	_nivel_rotulo.position = Vector2(2.0, -FAIXA_DO_NIVEL + 2.0)
	_nivel_rotulo.text = "NIVEL:1"
	add_child(_nivel_rotulo)
	_vida = _barra(0.0, Estilo.VIDA)
	_vida.cor_pela_vida = true
	_vida_rotulo = _rotulo(0.0)
	_energia = _barra(ALTURA + ESPACO, Estilo.ENERGIA)
	_energia_rotulo = _rotulo(ALTURA + ESPACO)
	_ressurreicao = Estilo.texto(16, Color(1, 1, 1))
	_ressurreicao.name = "Ressurreicao"
	_ressurreicao.position = Vector2(LARGURA + 8.0, 3.0)     # fora do retângulo, à direita da barra de vida (como o rótulo do nível, acima)
	add_child(_ressurreicao)
	_atualizar_ressurreicao()
	visible = false   # até existir um corpo para mostrar
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


## Mostra a vida e a energia de `jogador` (nulo esconde: sem corpo não há o que mostrar).
## Os corações do Minecraft (`HudMinecraft`) assumem a vida: some a barra verde e o seu texto; a energia continua.
func usar_coracoes() -> void:
	_vida.visible = false
	_vida_rotulo.visible = false
	_energia.position.y = -2.0
	_energia_rotulo.position.y = 3.0


func atualizar(jogador: Node) -> void:
	visible = jogador != null and is_instance_valid(jogador)
	if not visible:
		return
	var hp_max: float = jogador.max_health
	var en_max: float = jogador.max_energy
	_vida.valor(jogador.health / maxf(hp_max, 1.0))
	_energia.valor(jogador.energy / maxf(en_max, 1.0))
	_nivel_rotulo.text = "NIVEL:%d" % maxi(1, int(jogador.get_meta("nivel", 1)))
	_atualizar_ressurreicao()
	var agora := PackedInt32Array([vida_exibida(jogador.health), roundi(hp_max), floori(jogador.energy), roundi(en_max)])
	if agora == _ultimo:
		return   # texto só muda quando o número inteiro muda
	_ultimo = agora
	_vida_rotulo.text = "VIDA  %d / %d" % [agora[0], agora[1]]
	_energia_rotulo.text = "ENERGIA  %d / %d" % [agora[2], agora[3]]


func _atualizar_ressurreicao() -> void:
	var chances := ReanimacaoDoCoracao.chances_restantes()
	if chances == _chances:
		return
	_chances = chances
	_ressurreicao.text = "RESSURREIÇÃO %d/%d" % [chances, ReanimacaoDoCoracao.MAX_TENTATIVAS]
	_ressurreicao.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55) if chances > 0 else Color(0.95, 0.35, 0.3))


func texto_da_ressurreicao() -> String:
	return _ressurreicao.text


## O número de vida que as telas mostram (esta HUD e a janela de status).
static func vida_exibida(vida: float) -> int:
	return maxi(roundi(vida), 1) if vida > 0.0 else 0


func texto_da_vida() -> String:
	return _vida_rotulo.text


func texto_do_nivel() -> String:
	return _nivel_rotulo.text


func texto_da_energia() -> String:
	return _energia_rotulo.text


func _barra(y: float, cor: Color) -> BarraHud:
	var b := BarraHud.new()
	b.cor = cor
	b.position = Vector2(-2.0, y - 2.0)   # o mesmo recuo do `StatsHud`: o rótulo fica dentro
	b.size = Vector2(LARGURA, ALTURA)
	add_child(b)
	return b


func _rotulo(y: float) -> Label:
	var l := Estilo.texto(16, Color(1, 1, 1))
	l.position = Vector2(14.0, y + 3.0)
	add_child(l)
	return l
