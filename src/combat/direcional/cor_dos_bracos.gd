class_name CorDosBracos
extends Node
# ============================================================================
#  COR DOS BRAÇOS — azul defendendo, vermelho atacando (30/09/2026).
#
#  Pedido do dono, para o jogador do Modo História e para o boneco de duelo (os dois
#  lutam pelo MESMO executor). Decisões dele: vermelho no GOLPE INTEIRO (preparo,
#  impacto e recuperação — `atacando()`), azul com a GUARDA erguida (`em_guarda()`);
#  tinta TRANSLÚCIDA por cima do braço, mantendo a luz e o contorno do modelo, com
#  transição rápida.
#
#  Só apresentação: lê o estado do executor, não decide nada. Nasce junto com a
#  `ApresentacaoDeCombate` — um ponto de instalação só para jogador e boneco.
#
#  ⚠️ O FLASH DE DANO GANHA. Ele também usa `material_overlay` e, ao terminar, o
#  zera. Por isso a cor só é posta em malha com a sobreposição VAZIA, e só é tirada
#  da malha onde ela é a NOSSA: durante o flash o braço pisca como o resto do corpo,
#  e a cor volta sozinha no quadro seguinte.
# ============================================================================

const AZUL := Color(0.22, 0.55, 1.0)
const VERMELHO := Color(1.0, 0.16, 0.10)
## Quanto a tinta cobre o braço: o bastante para ler de longe, sem apagar a forma.
const OPACIDADE := 0.75
## Tempo da troca de cor (entrar, sair, azul ↔ vermelho).
const TRANSICAO := 0.08
## Os braços inteiros: no rig o antebraço e a mão são filhos do braço.
const OSSOS: Array[StringName] = [&"UpperArm_L", &"UpperArm_R"]

var _executor: ExecutorCorpoACorpo
var _material: StandardMaterial3D
var _malhas: Array[GeometryInstance3D] = []
var _modelo: Node3D = null
var _procurou := false
var _cor := AZUL
var _alfa := 0.0


func montar(executor: ExecutorCorpoACorpo) -> void:
	_executor = executor
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Com luz (e não unshaded): a tinta escurece na sombra junto com o braço, e a forma
	# continua legível. O brilho leve segura a cor no lado escuro.
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 0.35
	_material.disable_receive_shadows = true
	_aplicar_cor()


## A cor que o estado pede agora (`Color(0, 0, 0, 0)` = nenhuma).
func cor_pedida() -> Color:
	if _executor == null:
		return Color(0, 0, 0, 0)
	if _executor.atacando():
		return VERMELHO
	if _executor.em_guarda():
		return AZUL
	return Color(0, 0, 0, 0)


## A tinta que está nos braços agora (cor e opacidade de fato aplicadas).
func tinta() -> Color:
	return Color(_cor, _alfa)


func malhas() -> Array[GeometryInstance3D]:
	return _malhas


func _process(delta: float) -> void:
	if _executor == null or _material == null:
		return
	var pedida := cor_pedida()
	var passo := delta / TRANSICAO
	if pedida.a > 0.0:
		# Entrando do nada: já nasce na cor certa (sem passar por roxo); trocando de uma
		# cor para a outra, cruza as duas no tempo da transição.
		_cor = Color(pedida.r, pedida.g, pedida.b) if _alfa < 0.01 else _cor.lerp(pedida, minf(passo, 1.0))
		_alfa = move_toward(_alfa, OPACIDADE, passo * OPACIDADE)
	else:
		_alfa = move_toward(_alfa, 0.0, passo * OPACIDADE)
	_garantir_malhas()
	_aplicar_cor()
	var ligada := _alfa > 0.001
	for m in _malhas:
		if not is_instance_valid(m):
			continue
		if ligada and m.material_overlay == null:
			m.material_overlay = _material
		elif not ligada and m.material_overlay == _material:
			m.material_overlay = null


func _aplicar_cor() -> void:
	_material.albedo_color = Color(_cor, _alfa)
	_material.emission = _cor


## Acha as malhas dos braços; de novo quando o modelo é remontado (troca de
## personagem, Gear 2) ou alguma malha sumiu.
func _garantir_malhas() -> void:
	var modelo := _executor.ator.modelo_visual() if _executor.ator != null else null
	var validas := modelo == _modelo and _procurou
	if validas:
		for m in _malhas:
			if not is_instance_valid(m):
				validas = false
				break
	if validas:
		return
	_modelo = modelo
	_malhas.clear()
	_procurou = is_instance_valid(modelo)
	if not _procurou:
		return
	for osso in OSSOS:
		var raiz := modelo.find_child(String(osso), true, false)
		if raiz == null:
			continue
		var pilha: Array[Node] = [raiz]
		while not pilha.is_empty():
			var n: Node = pilha.pop_back()
			if n is GeometryInstance3D:
				_malhas.append(n)
			pilha.append_array(n.get_children())


func _exit_tree() -> void:
	# Saindo (troca de modo, corpo liberado): não deixa braço tingido para trás.
	for m in _malhas:
		if is_instance_valid(m) and m.material_overlay == _material:
			m.material_overlay = null
