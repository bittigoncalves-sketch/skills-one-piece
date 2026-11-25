class_name AplicadorDePose
extends RefCounted
# ============================================================================
#  APLICADOR DE POSE — leva a pose do combate ao corpo, DEPOIS do animador.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D7, decisão 21). Recebe a saída de
#  `PoseDeCombate` e um peso, e escreve nos nós do rig por nós (`base_v2`).
#
#  ------------------------------------------------ POR QUE DEPOIS, E NÃO DENTRO
#  O `ProceduralAnimator` soma offsets por papel e suaviza. Entrar nele exigiria
#  editar um arquivo de 1.400 linhas com trabalho aberto de outra frente, e ainda
#  converter alvo de mão em ângulo antes de saber onde o ombro ficou naquele quadro.
#  Aplicando depois (a ordem da árvore garante: o executor é filho do corpo), o
#  animador faz a locomoção de sempre e esta camada substitui, com peso, só os papéis
#  que a pose escreve — e a IK resolve a mão a partir do ombro REAL do quadro.
#  É o mesmo lugar em que a Yoru aplica a pose dela (prioridade após o Player).
#
#  Com peso 1 a pose sai exata; entre 0 e 1 ela mistura com o que o animador fez,
#  e é essa mistura, na entrada e na saída da ação, que evita estalo.
#
#  ------------------------------------------------------------------ A IK
#  Dois ossos, sem esticar: ombro→cotovelo→punho, com a direção do cotovelo vinda da
#  chave. A MESMA matemática de `YoruRig.solve_two_bone`, reescrita aqui de
#  propósito: citar o YoruRig prenderia o combate da história aos arquivos da frente
#  da espada (fora do git, em mudança). GATILHO: um terceiro IK de dois ossos no
#  projeto → extrair um compartilhado.
#
#  Nas PERNAS a mesma conta acha o joelho, mas a coxa e a canela recebem a base
#  montada por inteiro (dobra no eixo X, a dobradiça do rig) em vez da rotação
#  mínima dos braços: a rotação mínima herdaria o giro que a marcha deixou na coxa,
#  e num membro de bloco isso torce o joelho para fora do plano do passo.
#
#  -------------------------------------------------------------- O QUADRIL
#  O animador reescreve a posição do `Torso` a cada quadro — menos quando um clipe
#  gravado assume. Somar o deslocamento às cegas afundaria o quadril quadro a quadro
#  nesse caso; por isso a camada lembra o que escreveu e, se ninguém reescreveu,
#  desfaz o próprio deslocamento antes de pôr o novo.
#
#  ----------------------------------------------------------- PÉ DE APOIO
#  O alvo do pé vem no espaço do CORPO, mas o corpo anda: o avanço do golpe (que
#  para quando o golpe conecta) e o giro levariam os dois pés junto — patinação.
#  Compensar nos dados erraria justo no acerto. Então o pé com alvo na altura de
#  apoio TRAVA no mundo onde pisou; se o lugar que a pose pede se afasta demais, ou a
#  âncora sai do alcance da perna, ele dá um passo curto em arco até lá. Pé erguido
#  pela pose (o passo do jab) segue a pose. Os números são do estilo.
#  A âncora é o ANTEPÉ (nó `Ball_*`), não o tornozelo: o pivô do gancho gira o pé
#  sobre a bola do pé — ancorado no tornozelo, girar o pé varria a ponta pelo chão
#  (medido: 10,8 cm no gancho de esquerda).
#
#  ------------------------------------------------- SÓ ROTAÇÃO LOCAL, NUNCA ESCALA
#  Toda orientação que esta camada calcula é GLOBAL, mas é escrita como rotação LOCAL
#  (`_girar_global`), e a escala do osso nunca é tocada. Até 21/09 as escritas eram
#  `global_basis = R * from_scale(global_basis.get_scale())`: com o pai levemente fora
#  de escala uniforme (erro numérico da própria IK), o cisalhamento virava escala LOCAL
#  do pé, e o animador — que só escreve `rotation` — a guardava para o quadro seguinte.
#  Somava sem parar: pé em (0,61; 1,67) depois de 13 golpes, (0,38; 0,00003; 233.120)
#  numa sessão longa (docs/erros.md, 21/09; `test_contato_historia`, seção G).
# ============================================================================

## Pernas: com o corpo ANDANDO, ficam com a marcha do animador. O GIRO do quadril
## (`Torso`) não entra aqui — ele é elo da cadeia do golpe e vale mesmo andando; só o
## DESLOCAMENTO do quadril acompanha as pernas (ver `_quadril`).
## Tronco e cabeça: em guarda, andando, ficam com a marcha (contragiro da corrida) em vez
## de congelar na pose. Só vale quando o corpo NÃO está golpeando — num golpe o giro do
## tronco é elo da cadeia e entra com o peso cheio.
const TRONCO := ["Torso", "SpineMid", "Head"]
const PERNAS := ["Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R", "Ball_L", "Ball_R"]
## Com menos que isto das pernas para a pose (o resto é marcha) o corpo está ANDANDO:
## nada trava. É a fração peso_pernas/peso — a transição de entrada não conta como andar.
const PESO_MINIMO_PARA_TRAVAR := 0.5
## A âncora solta antes de a perna esticar de todo: perto do limite a IK já arrastaria o pé.
const ALCANCE_DA_ANCORA := 0.97
## Pé a menos que isto do alvo ao entrar na base não dá passo (seria um toque no lugar).
const PASSO_MINIMO := 0.03
## Alvo da mão a menos que esta fração do braço do ombro: a IK não resolve (ver `_braco`).
const ALCANCE_MINIMO_DO_BRACO := 0.3
## Em guarda, o osso do braço gira no máximo isto por quadro. Nenhum movimento de guarda
## (entrar, mudar de mão) precisa de mais; um estalo de 100°+ é sempre defeito da IK.
const PASSO_MAXIMO_DO_BRACO := deg_to_rad(28.0)

var _modelo: Node3D
var _nos := {}   # nome → Node3D (cache; nome do nó = papel no base_v2)
var _quadril_escrito := Vector3.INF   # posição do Torso que esta camada deixou
var _quadril_somado := Vector3.ZERO   # deslocamento (espaço do pai) que ela somou
## Por pé: âncora no mundo (INF = solto) e o passo em curso (de onde, há quanto tempo).
var _pes := {"L": {"ancora": Vector3.INF, "de": Vector3.INF, "t": INF},
	"R": {"ancora": Vector3.INF, "de": Vector3.INF, "t": INF}}
var _ultimo_quadro := -1
## Última solução da IK de cada braço (quaternios locais ombro/antebraço). A IK parte
## dela, e não do que o clipe de marcha deixou no osso: com o braço do clipe balançando
## para trás e o alvo na guarda, a rotação mínima passa perto de 180° e o giro do osso
## pula de um quadro para o outro (medido: antebraço a cos -0,99, cotovelo estalando 170°).
var _semente_braco := {}
## Metade da dobra de cada tampa (cotovelo/joelho) no quadro anterior: a metade de uma
## rotação perto de 180° tem DUAS respostas, e a escolha tem que seguir a anterior.
var _tampa_anterior := {}
var _em_repouso := false   # sem golpe em curso: o braço não pode estalar entre quadros
var _travando := false   # no quadro anterior os pés podiam travar (parado, com estilo)


func montar(modelo: Node3D) -> void:
	if modelo != _modelo:
		_nos.clear()
		_quadril_escrito = Vector3.INF
		_quadril_somado = Vector3.ZERO
		_soltar_pes()
	_modelo = modelo


## Para medir: "travado" (no chão, preso no mundo), "passo" (indo para o alvo) ou "solto".
func estado_do_pe(lado: String) -> String:
	if _pes[lado]["t"] < INF:
		return "passo"
	return "solto" if _pes[lado]["ancora"] == Vector3.INF else "travado"


func valido() -> bool:
	return is_instance_valid(_modelo) and _modelo.is_inside_tree()


func no(nome: StringName) -> Node3D:
	# Ausência também fica no cache: um papel que o rig não tem não pode custar uma
	# busca na árvore a cada quadro. Trocar de modelo (`montar`) limpa tudo.
	if _nos.has(nome):
		var guardado = _nos[nome]
		if guardado == null or is_instance_valid(guardado):
			return guardado
	var n: Node3D = _modelo.find_child(String(nome), true, false) as Node3D if valido() else null
	_nos[nome] = n
	return n


## Base do corpo SEM escala (frente = −Z). O modelo é escalado para caber no colisor;
## as posições das chaves são em metros de mundo.
func base() -> Basis:
	return _modelo.global_basis.orthonormalized()


func para_mundo(local: Vector3) -> Vector3:
	return _modelo.global_position + base() * local


func para_corpo(mundo: Vector3) -> Vector3:
	return base().inverse() * (mundo - _modelo.global_position)


func posicao_global(nome: StringName) -> Vector3:
	var n := no(nome)
	return n.global_position if n != null else Vector3.INF


## Aplica `pose` com `peso` (0..1). `peso_pernas` escala só pernas e quadril — andando,
## a marcha do animador fica com eles e os pés não patinam. O `estilo` dá a forma dos
## dedos e os números do pé de apoio; `delta` anda o passo (0 = congelado, hitstop).
## `travar` falso: os pés seguem a pose sem âncora (corpo empurrado derrapa).
func aplicar(pose: Dictionary, peso: float, peso_pernas: float, estilo: EstiloCorpoACorpo = null,
		delta := 0.0, travar := true, tronco_na_marcha := false) -> void:
	_em_repouso = tronco_na_marcha
	if peso <= 0.0 or not valido():
		return
	# Camada que ficou fora por algum quadro (peso zero, outro modelo): âncora velha
	# puxaria o pé para onde o corpo ESTAVA.
	var quadro := Engine.get_physics_frames()
	if quadro > _ultimo_quadro + 1:
		_soltar_pes()
		_travando = false
		_semente_braco.clear()
		_tampa_anterior.clear()
	_ultimo_quadro = quadro
	var maos: Dictionary = estilo.maos if estilo != null else {}
	var rot: Dictionary = pose.get("rot", {})
	var pes_por_alvo := pose.has("pe_R")
	for papel in rot:
		if estilo != null and estilo.orientar_punhos and String(papel).begins_with("Wrist_"):
			continue # orientação global só depois da IK; não somar rotação local primeiro
		if pes_por_alvo and String(papel).begins_with("Foot_"):
			continue   # orientação do pé em relação ao CORPO: resolvida com a perna
		var n := no(papel)
		if n == null:
			continue
		var w := peso_pernas if PERNAS.has(papel) or (tronco_na_marcha and TRONCO.has(papel)) else peso
		n.rotation = n.rotation.lerp(rot[papel], w)
	# Quadril e pernas ANTES dos braços: o ombro pende do quadril, e a IK do braço
	# precisa partir do ombro já no lugar deste quadro.
	if pes_por_alvo:
		_quadril(pose["quadril"], peso_pernas)
		var trava := travar and peso_pernas >= PESO_MINIMO_PARA_TRAVAR * peso and estilo != null
		if not trava:
			_soltar_pes()
		# Entrar na base (do idle, ou parando de andar) é um PASSO de onde o pé estava —
		# senão ele desliza até a base na transição (medido: ~15 cm no jab do idle).
		var entrando := trava and not _travando
		_travando = trava
		_perna("R", pose, rot, peso_pernas, estilo, delta, entrando)
		_perna("L", pose, rot, peso_pernas, estilo, delta, entrando)
	_braco("R", pose, peso)
	_braco("L", pose, peso)
	if estilo != null and estilo.orientar_punhos:
		for lado in ["R", "L"]:
			var papel: String = "Wrist_" + lado
			var punho := no(papel)
			if punho != null and rot.has(papel):
				var alvo := base() * Basis.from_euler(rot[papel])
				var atual := punho.global_basis.orthonormalized()
				_girar_global(punho, atual.slerp(alvo, peso).get_rotation_quaternion())
	for papel in maos:
		var dedo := no(papel)
		if dedo != null:
			dedo.rotation = dedo.rotation.lerp((maos[papel] as Vector3) * (PI / 180.0), peso)
	for lado in ["L", "R"]:
		var joelho := no("Knee_" + lado)
		var canela := no("Shin_" + lado)
		if joelho != null and canela != null and (pes_por_alvo or rot.has("Shin_" + lado)):
			joelho.quaternion = _metade("joelho_" + lado, canela.quaternion)


# ------------------------------------------------------------------ interno
func _quadril(deslocamento: Vector3, peso: float) -> void:
	var torso := no("Torso")
	if torso == null:
		return
	if torso.position == _quadril_escrito:
		torso.position -= _quadril_somado   # ninguém reescreveu: tira o do quadro anterior
	var pai := torso.get_parent() as Node3D
	var local := deslocamento * peso
	if pai != null:
		local = pai.global_basis.inverse() * (base() * local)
	torso.position += local
	_quadril_somado = local
	_quadril_escrito = torso.position


func _perna(lado: String, pose: Dictionary, rot: Dictionary, peso: float, estilo: EstiloCorpoACorpo,
		delta: float, entrando := false) -> void:
	var coxa := no("Thigh_" + lado)
	var canela := no("Shin_" + lado)
	var pe := no("Foot_" + lado)
	if coxa == null or canela == null or pe == null or peso <= 0.0:
		return
	var q_coxa := coxa.quaternion
	var q_canela := canela.quaternion
	var q_pe := pe.global_basis.get_rotation_quaternion()
	var escala_pe := pe.global_basis.get_scale()
	var polo: Vector3 = base() * (pose["joelho_" + lado] as Vector3)
	var local: Vector3 = pose["pe_" + lado]
	var alvo := para_mundo(local)
	var q_alvo := (base() * Basis.from_euler(rot.get("Foot_" + lado, Vector3.ZERO))).get_rotation_quaternion()
	if entrando and pe.global_position.distance_to(alvo) > PASSO_MINIMO:
		_pes[lado]["de"] = pe.global_position
		_pes[lado]["t"] = 0.0
	if estilo != null and _travando:
		var perna := coxa.global_position.distance_to(canela.global_position) \
			+ canela.global_position.distance_to(pe.global_position)
		var bola := no("Ball_" + lado)
		var ate_a_bola := Basis(q_alvo) * (escala_pe * bola.position) if bola != null else Vector3.ZERO
		alvo = _apoio(lado, alvo, ate_a_bola, local.y, coxa.global_position, perna, estilo, delta)
	_perna_ik(coxa, canela, pe, alvo, polo)
	if peso < 1.0:
		coxa.quaternion = q_coxa.slerp(coxa.quaternion, peso)
		canela.quaternion = q_canela.slerp(canela.quaternion, peso)
	_girar_global(pe, q_pe.slerp(q_alvo, peso))


## Onde o tornozelo vai NESTE quadro: preso pelo antepé ancorado (pé no chão), no passo
## em curso, ou no alvo da pose (pé no ar). `ate_a_bola`: do tornozelo ao antepé, já na
## orientação que a pose pede para o pé.
func _apoio(lado: String, alvo: Vector3, ate_a_bola: Vector3, altura: float, quadril: Vector3,
		perna: float, estilo: EstiloCorpoACorpo, delta: float) -> Vector3:
	var p: Dictionary = _pes[lado]
	var no_chao := altura <= estilo.altura_de_apoio
	var bola_alvo := alvo + ate_a_bola
	var ancora: Vector3 = p["ancora"]
	# Onde o tornozelo fica com o antepé travado: o CHÃO (x, z) vem da âncora e a altura
	# vem da pose — é ela que tira o calcanhar do chão no pivô.
	var travado := Vector3(ancora.x, bola_alvo.y, ancora.z) - ate_a_bola if ancora != Vector3.INF else alvo
	if ancora != Vector3.INF:
		var longe := Vector2(ancora.x - bola_alvo.x, ancora.z - bola_alvo.z).length() > estilo.soltar_pe_a
		var fora_de_alcance := travado.distance_to(quadril) > perna * ALCANCE_DA_ANCORA
		# Um pé de cada vez: com o outro no ar, este segura a base mesmo passando do ponto
		# (medido no overhand: os dois pés em passo juntos pareciam uma corrida).
		var outro: Dictionary = _pes["R" if lado == "L" else "L"]
		var outro_no_ar: bool = outro["t"] < estilo.duracao_do_passo or outro["ancora"] == Vector3.INF
		# TODA soltura passa por PASSO, inclusive a da pose erguendo o pé: soltar devolvendo
		# o alvo cru fazia o pé pagar num quadro tudo o que a base tinha derivado
		# (medido em 17/09: 14,9 cm num quadro no overhand, 8,9 m/s — mais rápido que o punho).
		# Fora do alcance solta SEMPRE: esticar a perna além do osso é pior que os dois pés
		# no ar por um instante (medido: 7,2 cm de arrasto no pé de trás do overhand).
		if not no_chao or fora_de_alcance or (longe and not outro_no_ar):
			p["de"] = travado
			p["t"] = 0.0
			p["ancora"] = Vector3.INF
			ancora = Vector3.INF
	if p["t"] < estilo.duracao_do_passo:
		p["t"] += delta
		var u := clampf(p["t"] / estilo.duracao_do_passo, 0.0, 1.0)
		var k := ChaveDePose.aplicar_curva(ChaveDePose.Curva.SUAVE, u)
		if u >= 1.0:
			p["t"] = INF
			p["ancora"] = bola_alvo if no_chao else Vector3.INF
		# Arco só quando o passo é rente ao chão; se a pose já ergue o pé, ela manda na altura.
		var arco := estilo.altura_do_passo * sin(PI * u) if no_chao else 0.0
		return (p["de"] as Vector3).lerp(alvo, k) + Vector3.UP * arco
	if not no_chao:
		return alvo
	if ancora == Vector3.INF:
		p["ancora"] = bola_alvo
		return alvo
	return travado


func _soltar_pes() -> void:
	for lado in _pes:
		_pes[lado]["ancora"] = Vector3.INF
		_pes[lado]["t"] = INF


static func _perna_ik(coxa: Node3D, canela: Node3D, pe: Node3D, alvo: Vector3, polo: Vector3) -> void:
	var quadril := coxa.global_position
	var l1 := quadril.distance_to(canela.global_position)
	var l2 := canela.global_position.distance_to(pe.global_position)
	var joelho := _junta_do_meio(quadril, l1, l2, alvo, polo)
	if joelho == Vector3.INF:
		return
	var alcance := clampf(quadril.distance_to(alvo), absf(l1 - l2) + 0.00001, l1 + l2 - 0.00001)
	var tornozelo := quadril + (alvo - quadril).normalized() * alcance
	# O osso dobra no X local (a dobradiça): ela fica perpendicular ao plano da perna. Só
	# a parte do polo PERPENDICULAR à perna entra — a componente ao longo dela inverteria
	# o sinal.
	var eixo := (alvo - quadril).normalized()
	var dobradica := eixo.cross(polo - eixo * polo.dot(eixo))
	if dobradica.length_squared() < 0.0001:
		dobradica = eixo.cross(Vector3.UP)
	# A direção do osso é a do FILHO real, não −Y: no base_v2 canela e pé ficam ~4° de
	# lado (Shin_L em (−0,026, −0,343)). Supor −Y deixava o tornozelo 3,9 cm fora do alvo.
	for par in [[coxa, canela, joelho - quadril], [canela, pe, tornozelo - joelho]]:
		var osso: Node3D = par[0]
		var d_local := ((par[1] as Node3D).position).normalized()
		var x_local := (Vector3.RIGHT - d_local * d_local.x).normalized()
		var d_mundo := (par[2] as Vector3).normalized()
		var x_mundo := (dobradica - d_mundo * dobradica.dot(d_mundo)).normalized()
		if x_mundo.length_squared() < 0.5 or x_local.length_squared() < 0.5:
			continue
		var local := Basis(x_local, d_local, x_local.cross(d_local))
		var mundo := Basis(x_mundo, d_mundo, x_mundo.cross(d_mundo))
		_girar_global(osso, (mundo * local.transposed()).get_rotation_quaternion())


func _braco(lado: String, pose: Dictionary, peso: float) -> void:
	var ombro := no("UpperArm_" + lado)
	var antebraco := no("ForeArm_" + lado)
	var punho := no("Wrist_" + lado)
	if ombro == null or antebraco == null or punho == null:
		return
	var q_ombro := ombro.quaternion
	var q_antebraco := antebraco.quaternion
	if _semente_braco.has(lado):
		ombro.quaternion = _semente_braco[lado][0]
		antebraco.quaternion = _semente_braco[lado][1]
	var alvo := para_mundo(pose["mao_" + lado])
	var cotovelo_dir: Vector3 = base() * (pose["cotovelo_" + lado] as Vector3)
	# Alvo colado no ombro (guarda autorada para um corpo maior que o escalado): a direção
	# ombro→alvo vira ruído e o braço estala de um quadro para o outro (medido: 98° andando).
	# Com solução anterior, o braço fica nela até o alvo se afastar.
	var alcance := ombro.global_position.distance_to(antebraco.global_position) \
		+ antebraco.global_position.distance_to(punho.global_position)
	if not (_semente_braco.has(lado) and ombro.global_position.distance_to(alvo) < ALCANCE_MINIMO_DO_BRACO * alcance):
		_dois_ossos(ombro, antebraco, punho, alvo, cotovelo_dir)
	if _em_repouso and _semente_braco.has(lado):
		ombro.quaternion = _passo_limitado(_semente_braco[lado][0], ombro.quaternion)
		antebraco.quaternion = _passo_limitado(_semente_braco[lado][1], antebraco.quaternion)
	_semente_braco[lado] = [ombro.quaternion, antebraco.quaternion]
	if peso < 1.0:
		ombro.quaternion = q_ombro.slerp(ombro.quaternion, peso)
		antebraco.quaternion = q_antebraco.slerp(antebraco.quaternion, peso)
	# A tampa do cotovelo copia metade da dobra, como `RigDetalhado.juntas` faz para
	# o animador. Sem isto a malha do cotovelo ficaria reta com o braço dobrado.
	var tampa := no("Elbow_" + lado)
	if tampa != null:
		tampa.quaternion = _metade("cotovelo_" + lado, antebraco.quaternion)


## Metade da rotação de `q`. `euler * 0.5` PULAVA quando o ângulo do euler dava a volta
## (±180°) e `slerp(identidade, q, 0.5)` pula quando `q` cruza 180° (o antebraço do rig
## chega a w≈0): a tampa do cotovelo estalava 170° num quadro, correndo de machado.
## Das duas metades possíveis (`q` e `-q`) fica a mais próxima da do quadro anterior.
func _metade(chave: String, q: Quaternion) -> Quaternion:
	# `slerp` já pega o caminho curto, então `q` e `-q` dariam a MESMA metade; a outra é
	# a do arco longo (ângulo/2 - 180°).
	var eixo := Vector3(q.x, q.y, q.z)
	if eixo.length_squared() < 0.000001:
		return Quaternion.IDENTITY
	eixo = eixo.normalized()
	var angulo := 2.0 * acos(clampf(q.w, -1.0, 1.0))
	var a := Quaternion(eixo, angulo * 0.5)
	var b := Quaternion(eixo, angulo * 0.5 - PI)
	var escolhida := a
	if _tampa_anterior.has(chave):
		var ant: Quaternion = _tampa_anterior[chave]
		escolhida = a if a.angle_to(ant) <= b.angle_to(ant) else b
	_tampa_anterior[chave] = escolhida
	return escolhida


static func _passo_limitado(de: Quaternion, para: Quaternion) -> Quaternion:
	var angulo := de.angle_to(para)
	return para if angulo <= PASSO_MAXIMO_DO_BRACO else de.slerp(para, PASSO_MAXIMO_DO_BRACO / angulo)


static func _dois_ossos(upper: Node3D, lower: Node3D, end: Node3D, alvo: Vector3, polo: Vector3) -> void:
	var origem := upper.global_position
	var l1 := origem.distance_to(lower.global_position)
	var l2 := lower.global_position.distance_to(end.global_position)
	var cotovelo := _junta_do_meio(origem, l1, l2, alvo, polo)
	if cotovelo == Vector3.INF:
		return
	var distancia := clampf(origem.distance_to(alvo), absf(l1 - l2) + 0.00001, l1 + l2 - 0.00001)
	_apontar(upper, lower, cotovelo)
	_apontar(lower, end, origem + (alvo - origem).normalized() * distancia)


## Onde fica a junta do meio (cotovelo/joelho) de uma cadeia `l1`+`l2` que sai de
## `origem` e alcança `alvo` — sem esticar —, dobrando para o lado do `polo`.
## `Vector3.INF` se a cadeia é degenerada.
static func _junta_do_meio(origem: Vector3, l1: float, l2: float, alvo: Vector3, polo: Vector3) -> Vector3:
	if l1 < 0.001 or l2 < 0.001:
		return Vector3.INF
	var eixo := (alvo - origem).normalized()
	if eixo.length_squared() < 0.5:
		return Vector3.INF
	var distancia := clampf(origem.distance_to(alvo), absf(l1 - l2) + 0.00001, l1 + l2 - 0.00001)
	var projecao := (l1 * l1 - l2 * l2 + distancia * distancia) / (2.0 * distancia)
	var dobra := polo - eixo * polo.dot(eixo)
	if dobra.length_squared() < 0.0001:
		dobra = eixo.cross(Vector3.UP)
	return origem + eixo * projecao + dobra.normalized() * sqrt(maxf(0.0, l1 * l1 - projecao * projecao))


static func _apontar(pai: Node3D, filho: Node3D, alvo: Vector3) -> void:
	var de := (filho.global_position - pai.global_position).normalized()
	var para := (alvo - pai.global_position).normalized()
	if de.length_squared() < 0.5 or para.length_squared() < 0.5:
		return
	_girar_global(pai, Quaternion(de, para) * pai.global_basis.get_rotation_quaternion())


## Leva `osso` à orientação GLOBAL `q` escrevendo só a rotação LOCAL: a escala dele não
## é lida nem escrita, então não há erro para acumular (ver o cabeçalho). Vale porque toda
## a cadeia do rig tem escala uniforme (só a raiz do personagem escala, igual nos 3 eixos).
static func _girar_global(osso: Node3D, q: Quaternion) -> void:
	var pai := osso.get_parent() as Node3D
	var q_pai := pai.global_basis.get_rotation_quaternion() if pai != null else Quaternion.IDENTITY
	osso.quaternion = (q_pai.inverse() * q).normalized()
