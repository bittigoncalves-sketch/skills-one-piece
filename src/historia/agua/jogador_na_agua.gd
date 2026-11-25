class_name JogadorNaAgua
extends Node
# ============================================================================
#  JOGADOR NA ÁGUA — rasa, nado, mergulho e fôlego do personagem (01/10/2026).
#
#  docs/AGUA_PLANO.md. Decisões do dono:
#    • água rasa deixa mais lento (canela −15 %, joelho −30 %, cintura −50 %);
#    • água no peito: NADA — flutua com a cabeça para fora; Espaço sobe, Ctrl desce
#      (mergulho);
#    • fôlego de 30 s com a cabeça submersa; acabou, perde vida aos poucos até subir;
#    • usuário de Akuma no Mi NÃO nada: na água rasa só fica lento; quando o corpo fica
#      COMPLETAMENTE submerso, afunda; no fundo anda devagar até a margem, sem técnicas.
#  O `Player` só recebe: `fator_da_agua` (velocidade), `modo_na_agua` e `agua_vertical`
#  (a velocidade vertical pedida, no lugar da gravidade). O corpo mede 1,6 m (a cápsula)
#  com os pés 0,8 m abaixo do centro.
# ============================================================================

signal folego_mudou(fracao: float)

const ALTURA := 1.6
const PES_ABAIXO_DO_CENTRO := 0.8
const CABECA_ACIMA_DO_CENTRO := 0.65
const NADA_A_PARTIR := 0.68          # água no peito (fração do corpo)
const SAI_ABAIXO_DE := 0.58          # histerese: para de nadar quando dá pé de novo
## Boiando, a água fica nesta fração do corpo (dos pés). Nadando para a frente o corpo
## sobe: com o tronco inclinado do crawl, costas e ombros rompem a superfície — com
## 0,66 só a cabeça aparecia (o mar é opaco; captura de 01/10/2026).
const LINHA_DAGUA_NADANDO := 0.62
const LINHA_DAGUA_EM_CRAWL := 0.40
const VELOCIDADE_VERTICAL := 2.6     # subir/descer nadando (m/s)
const AFUNDA_A := -1.4               # usuário de fruta submerso (m/s)
const FATOR_NADO := 0.62
const FATOR_NO_FUNDO := 0.3          # usuário de fruta andando no fundo
const FOLEGO_MAXIMO := 30.0
const RECUPERA_POR_SEGUNDO := 8.0
const VIDA_POR_SEGUNDO_SEM_AR := 1.0

var jogador_de: Callable
var progressao: ProgressaoDoPersonagem = null
## Quanto do corpo está submerso agora (0–1). Público para o HUD e os testes.
var submerso := 0.0
var folego := FOLEGO_MAXIMO
var cabeca_submersa := false
var nado_rapido := false
var _exausto := false

var _sem_ar_acumulado := 0.0
var _capacidades_guardadas := {}     # can_use_fruit/can_fly de antes de afundar


func _physics_process(delta: float) -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or not is_instance_valid(j):
		return
	j.set("controle_da_agua", self)
	var centro := j.global_position
	var pes := centro - Vector3.UP * PES_ABAIXO_DO_CENTRO
	var nivel := AguaDoMundo.nivel_em(centro.x, centro.z)
	submerso = 0.0 if is_nan(nivel) else clampf((nivel - pes.y) / ALTURA, 0.0, 1.0)
	cabeca_submersa = not is_nan(nivel) and nivel > centro.y + CABECA_ACIMA_DO_CENTRO
	var modo: String = j.get("modo_na_agua")
	# Fruta DESLIGADA no M (decisão do dono): nada como quem nunca comeu.
	var fruta := progressao != null and progressao.fruta_em_uso()

	if fruta:
		# Não nada: rasa = lento; corpo TODO submerso = afunda e anda devagar no fundo.
		if submerso >= 0.999:
			_entrar(j, "afundando")
			j.set("agua_vertical", 0.0 if (j as CharacterBody3D).is_on_floor() else AFUNDA_A)
			j.set("fator_da_agua", FATOR_NO_FUNDO)
		else:
			_sair(j)
			j.set("fator_da_agua", AguaDoMundo.fator_de_andar(submerso))
	else:
		var nadar := submerso >= NADA_A_PARTIR
		if modo == "nadando":
			# A linha do crawl (0,40) fica abaixo da saída em pé (0,58).
			# Sem apoio no fundo, mantenha a flutuação em vez de alternar estados.
			nadar = submerso >= (SAI_ABAIXO_DE if (j as CharacterBody3D).is_on_floor() else LINHA_DAGUA_EM_CRAWL - .08)
		if nadar:
			_entrar(j, "nadando")
			j.set("agua_vertical", 0.0)   # o nado livre manda no vertical (`velocidade_de_nado`)
			j.set("fator_da_agua", FATOR_NADO)
		else:
			_sair(j)
			j.set("fator_da_agua", AguaDoMundo.fator_de_andar(submerso))
	_folego(j, delta)


## NADO LIVRE (14/10/2026, pedido do dono): o mouse (inclinação da câmera) e W/A/S/D
## escolhem a direção em 3D — olhando para baixo, W mergulha; para cima, W sobe. Sem tecla o
## corpo fica PARADO onde está (antes ele subia sozinho até a superfície). Espaço sobe e Ctrl
## desce como extra. A superfície é o teto: o corpo não sai voando da água.
## `mira` = direção da câmera com a inclinação; `velocidade` = a do nado (já com fatores).
func velocidade_de_nado(centro: Vector3, q: MoveFrame, mira: Vector3, velocidade: float) -> Vector3:
	var nivel := AguaDoMundo.nivel_em(centro.x, centro.z)
	var pedido := mira.normalized() * q.f + q.direita * q.r
	if pedido.length() > 1.0:
		pedido = pedido.normalized()
	var v := pedido * velocidade
	if Input.is_physical_key_pressed(KEY_CTRL):
		v.y -= VELOCIDADE_VERTICAL
	if Input.is_physical_key_pressed(KEY_SPACE):
		v.y += VELOCIDADE_VERTICAL
	if not is_nan(nivel):
		var andando := pedido.length() > 0.05
		var linha := LINHA_DAGUA_EM_CRAWL if andando else LINHA_DAGUA_NADANDO
		var teto := nivel - ALTURA * linha + PES_ABAIXO_DO_CENTRO    # centro do corpo boiando
		# Perto do teto a subida se desfaz; acima dele, o corpo é empurrado de volta.
		v.y = minf(v.y, (teto - centro.y) * 4.0)
	return v


func _entrar(j: Node3D, modo: String) -> void:
	if j.get("modo_na_agua") == modo:
		return
	j.set("modo_na_agua", modo)
	if modo == "afundando":
		# Submerso: sem técnicas de fruta (decisão do dono). Guarda para devolver.
		var c: Object = j.get("capacidades")
		if c != null and _capacidades_guardadas.is_empty():
			_capacidades_guardadas = {"can_use_fruit": c.get("can_use_fruit"), "can_fly": c.get("can_fly")}
			c.set("can_use_fruit", false)
			c.set("can_fly", false)
	else:
		_devolver_capacidades(j)


func _sair(j: Node3D) -> void:
	if not str(j.get("modo_na_agua")).is_empty():
		j.set("modo_na_agua", "")
		j.set("agua_vertical", 0.0)
	_devolver_capacidades(j)


func _devolver_capacidades(j: Node3D) -> void:
	if _capacidades_guardadas.is_empty():
		return
	var c: Object = j.get("capacidades")
	if c != null:
		for k in _capacidades_guardadas:
			c.set(k, _capacidades_guardadas[k])
	_capacidades_guardadas.clear()


## Cabeça submersa gasta fôlego; acabou, perde vida aos poucos (1 por segundo).
func _folego(j: Node3D, delta: float) -> void:
	var antes := folego
	if respiracao_infinita():
		folego = FOLEGO_MAXIMO
		_sem_ar_acumulado = 0.0
	elif cabeca_submersa:
		folego = maxf(folego - delta, 0.0)
		if folego <= 0.0:
			_sem_ar_acumulado += delta * VIDA_POR_SEGUNDO_SEM_AR
			if _sem_ar_acumulado >= 1.0:
				_sem_ar_acumulado -= 1.0
				if j.has_method("take_damage"):
					j.call("take_damage", 1.0, j.global_position, Vector3.ZERO, 0.0)
	else:
		_sem_ar_acumulado = 0.0
		folego = minf(folego + delta * RECUPERA_POR_SEGUNDO, FOLEGO_MAXIMO)
	if not is_equal_approx(antes, folego):
		folego_mudou.emit(folego / FOLEGO_MAXIMO)


func respiracao_infinita() -> bool:
	return progressao != null and progressao.raca == "sharkman"


## Chamado pela locomoção com a entrada já filtrada por menus e travas do corpo.
func fator_de_movimento(j: Node, q: MoveFrame, delta: float) -> float:
	nado_rapido = false
	if not respiracao_infinita() or j.modo_na_agua != "nadando":
		_exausto = false
		return (1.5 if q.sprint else 1.0) * j.fator_da_agua
	if not q.sprint or j.energy >= j.max_energy * .2:
		_exausto = false
	var custo := maxf(2.0, j.max_energy * .2) * delta
	if q.sprint and q.dir.length_squared() > .01 and not _exausto:
		if j.energy >= custo:
			j.gastar_energia(custo)
			nado_rapido = true
		else:
			_exausto = true
	# Andar na terra = 1×; correr = 1,5×. Nado rápido é 2× o nado normal.
	return 3.0 if nado_rapido else 1.5
