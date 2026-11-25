class_name YoruRig
extends RefCounted
## Curva da arma em coordenadas do rig; IK de dois segmentos sem esticar ossos.

# ============================================================================
#  A ORIENTAÇÃO DO FIO — o rolamento da lâmina em torno do próprio eixo
# ============================================================================
#  MEDIDO em `assets/models/weapons/yoru_v2.glb`, por seção transversal ao longo
#  do comprimento (`tools/dev_tests/medir_lamina_yoru.gd`):
#
#      +X local = FIO    -> a espessura afina até 0,0000 m (a aresta)
#      -X local = DORSO  -> chanfro de 0,006·(1-t) m
#      +Y local = comprimento (guarda 0,39 -> ponta 1,77)
#      ±Z local = as duas FACES (a chapa)
#
#  Bate com `tools/blender/yoru_master.py` ("spine front -> ridge -> edge") e com
#  o nó autoral `edge_direction`, que fica em +X.
#
#  ------------------------------------------------------------- O GRAU DE LIBERDADE
#  Pós-multiplicar a base por `Basis(Vector3.UP, θ)` gira a lâmina em torno do
#  PRÓPRIO comprimento. Muda para onde o FIO aponta sem mexer um milímetro em
#  para onde a ESPADA aponta. É o único eixo que decide entre CORTAR e BATER DE
#  CHAPA, e era o único que ninguém estava controlando.
#
#  ⚠️ Os dois números abaixo não são gosto — saem de medição. Relato do dono em
#  09/09/2026, com vídeo: "no golpe vertical está sendo executado com a lâmina na
#  horizontal, o que é um erro e deve ser executada na vertical".
#
#    corte      | fio·deslocamento    | plano x deslocamento | plano x vertical
#    -----------|---------------------|----------------------|------------------
#    vertical   | 0,00 -> +1,00       | 88,9° -> 0,0°        | 42° -> 90° (EM PÉ)
#    horizontal | -1,00 -> +1,00      | 0,0° (inalterado)    | 0° (inalterado)
#
#  (`fio·deslocamento`: +1 = o fio lidera o corte; 0 = o fio aponta para o lado;
#   -1 = está cortando com o DORSO. `plano x deslocamento`: 0° = a lâmina viaja
#   dentro do próprio plano e corta; 90° = viaja perpendicular e bate de chapa.)

# UM QUARTO de volta. O fio apontava para o lado do personagem enquanto a lâmina
# descia, então o plano dela viajava perpendicular ao próprio movimento: 88,9° de
# desalinho, que é a definição de bater de chapa. É este o defeito relatado.
const ROLAMENTO_VERTICAL := PI / 2

# MEIA volta. Aqui o plano já estava certo (deitado, 0° de desalinho) e a
# varredura já cortava dentro dele — com a aresta ERRADA. Cortava de dorso nos
# 24 de 24 quadros medidos. Não foi relatado pelo dono; foi achado ao medir o
# vertical, e é o mesmo defeito com outra roupa.
const ROLAMENTO_HORIZONTAL := PI

#  ⚠️ NÃO MEXE NA HITBOX. As bolinhas da `SwordBlade` moram no eixo +Y local
#  (guarda -> ponta), e rolar a lâmina em torno de +Y não desloca nenhuma delas.
#  Dano, alcance e varredura ficam idênticos: esta correção é de ORIENTAÇÃO.
# ============================================================================
#  A GUARDA PARADA — a pose de quem está esperando, não de quem está de pé
# ============================================================================
#  Pedido do dono em 10/09/2026, com referência desenhada (`~/Downloads/pose.webp`)
#  e corrigido por ele depois de ver a primeira versão rodando: pernas afastadas,
#  joelhos flexionados, corpo baixo, AS DUAS MÃOS no cabo, a lâmina recuada PARA
#  TRÁS, o tronco torcido para a direita e a cabeça olhando para a frente. A pose
#  que existia aqui deixava a espada para cima com as pernas retas e juntas — lia
#  como "personagem parado segurando espada", não como guarda.
#
#  ⚠️ ISTO MUDA DE QUEM SÃO AS PERNAS. Até aqui, parado, este rig só acoplava
#  braços e arma: o bloco de `Thigh/Shin/Foot` rodava dentro de `if id != ""`, e
#  quem mandava nas pernas era a locomoção. A guarda precisa delas, então elas
#  passam a ser disputadas — e é por isso que existe `_guarda` abaixo, em vez de
#  um simples liga/desliga. O peso vai a zero assim que o jogador anda, e a IK
#  parte da posição REAL do pé naquele quadro, senão a perna congela no meio do
#  passo quando a guarda entra ou sai.
#  ⚠️ A LÂMINA APONTA PARA TRÁS, e isso é correção do dono em 10/09/2026 depois
#  de ver a primeira versão no jogo: "deveria estar para trás e o corpo à direita
#  enquanto a cabeça olha para frente". A primeira leitura que fiz do desenho
#  colocou a espada à frente; o que ele quer é a guarda CARREGADA — arma recuada
#  do lado direito, tronco torcido para trás com ela, e o olhar já no alvo. É a
#  pose de quem está prestes a cortar, não a de quem está apontando.
const GUARDA_HANDLE := Vector3(0.24, 1.22, -0.14)   # cabo junto ao peito, lado direito
const GUARDA_INCLINACAO := -1.42                    # ~81°: lâmina quase horizontal
const GUARDA_GIRO := PI + 0.35                      # para TRÁS e um pouco para a direita
#  ⚠️ O CORPO INTEIRO VIRA DE LADO — segunda correção do dono, 10/09/2026:
#  "gira o corpo do personagem de lado e deixa a cabeça para frente assim como a
#  lâmina para trás". Antes só o `Chest` torcia 19°, o que dava um busto virado
#  sobre pernas de frente. Agora quem gira é o `Torso`, a raiz do corpo, e as
#  pernas vão junto: os pés deixam de ficar lado a lado e passam a ficar um à
#  frente do outro, que é como um espadachim de perfil realmente pisa.
#
#  Y NEGATIVO leva a frente do corpo para +X: o ombro DIREITO — o que segura a
#  espada recuada — vai para trás, e o esquerdo aponta para o alvo.
const GUARDA_CORPO := -1.05                         # ~60°: o corpo de perfil
#  O peito volta um pouco contra o giro do corpo. Sem isso o busto fica tão de
#  lado quanto o quadril e a pose lê como se o personagem estivesse torto, não
#  em guarda — e sobra torção demais para o pescoço desfazer sozinho.
const GUARDA_TRONCO := 0.30                         # contra-torção do peito
const GUARDA_QUADRIL := 0.055                       # quanto o tronco desce (joelho dobrado)
const GUARDA_PES := 0.045                           # quanto cada pé abre para fora
const GUARDA_TRANSICAO := 0.22                      # segundos para entrar e sair da guarda
const GUARDA_PARADO := 0.35                         # m/s abaixo dos quais o jogador conta como parado
const GUARDA_QUEDA := 1.2                           # m/s em Y acima dos quais ele está no ar, não parado

#  A respiração. Sem ela a guarda lê como bug de animação — arma pesada parada em
#  pixel fixo é a leitura de "travou", não de "esperando".
const RESPIRO_CICLO := 3.4
const RESPIRO_QUADRIL := 0.011
const RESPIRO_PONTA := 0.028

var player: Node3D
var sword: Node3D
var model: Node3D
var nodes: Dictionary = {}
var detailed := false
var grip_error := 0.0
var _rest: Dictionary = {}
var _guarda := 0.0          # 0 = locomoção manda; 1 = guarda cheia

func setup(p: Node3D, weapon: Node3D) -> void:
	player = p
	sword = weapon
	model = p.get("_char_model")
	if not is_instance_valid(model): return
	nodes.clear()
	_collect(model)
	detailed = nodes.has("Wrist_R") and nodes.has("Chest")
	for key in nodes: _rest[key] = nodes[key].transform

func _collect(n: Node) -> void:
	if n is Node3D: nodes[str(n.name)] = n
	for child in n.get_children(): _collect(child)

static func sample(id: String, time: float) -> Dictionary:
	var guard := Vector3(0.04,1.40,-0.36)
	var start := guard
	var finish := guard
	var a := Basis(Vector3.RIGHT,-0.644)
	var b := a
	var chest_a := 0.0
	var chest_b := 0.0
	# Rolamento do FIO em torno do próprio comprimento da lâmina. Fica FORA de
	# `a`/`b` de propósito — ver o bloco `roll` em `pose()`.
	var roll := 0.0
	if id in ["M1_1","Z","X"]:
		start = Vector3(0.12,1.32,-0.28)
		finish = Vector3(-0.10,1.30,-0.30)
		a = Basis(Vector3.UP,-1.15)*Basis(Vector3.RIGHT,-PI/2)
		b = Basis(Vector3.UP,1.10)*Basis(Vector3.RIGHT,-PI/2)
		if id == "X":
			a = a*Basis(Vector3.FORWARD,0.12)
			b = b*Basis(Vector3.FORWARD,0.12)
		roll = ROLAMENTO_HORIZONTAL
		chest_a = -0.22
		chest_b = 0.22
	elif id in ["M1_2","V"]:
		start = Vector3(0.02,1.63,-0.22)
		finish = Vector3(0.02,1.22,-0.36)
		a = Basis(Vector3.RIGHT,0.12)
		b = Basis(Vector3.RIGHT,-1.91)
		roll = ROLAMENTO_VERTICAL
	elif id == "C":
		start = Vector3(0.00,1.45,-0.30)
		finish = start
		a = Basis(Vector3.FORWARD,0.30)*Basis(Vector3.RIGHT,-0.35)
		b = a
	# O idle não é mais uma constante: ele mistura a pose solta de sempre com a
	# guarda, na proporção que `pose()` decidiu, e respira. `time` aqui é o
	# relógio do idle, não a fração de um golpe.
	if id == "": return guarda_parada(time, 0.0)
	var m := YoruMoves.get_move(id)
	var h: Vector3
	var basis: Basis
	var chest: float
	var stance: float
	if time < float(m.startup):
		var t := smoothstep(0.0,1.0,time/float(m.startup))
		h = guard.lerp(start,t)
		basis = Basis(Vector3.RIGHT,-0.644).slerp(a,t)
		chest = chest_a*t
		stance = t
	elif time < float(m.startup)+float(m.active):
		var t := smoothstep(0.0,1.0,(time-float(m.startup))/float(m.active))
		h = start.lerp(finish,t)
		basis = a.slerp(b,t)
		chest = lerpf(chest_a,chest_b,t)
		stance = 1.0
	else:
		var t := smoothstep(0.0,1.0,(time-float(m.startup)-float(m.active))/float(m.recovery))
		h = finish.lerp(guard,t)
		basis = b.slerp(Basis(Vector3.RIGHT,-0.644),t)
		chest = chest_b*(1.0-t)
		stance = 1.0-t
	return {"handle":h,"basis":basis,"chest":chest,"stance":stance,"roll":roll,"olhar":0.0,"corpo":0.0}

## A pose parada, misturando a neutra solta (peso 0) com a guarda (peso 1).
##
## Separada de `sample` e pública porque é a única parte do idle que dá para
## conferir sem árvore montada — `tools/dev_tests/test_yoru_guarda.gd` mede os
## números daqui direto, sem precisar de cena, rig nem física.
static func guarda_parada(time: float, peso: float) -> Dictionary:
	var neutro_h := Vector3(0.04,1.40,-0.36)
	var neutro_b := Basis(Vector3.RIGHT,-0.644)
	peso = clampf(peso, 0.0, 1.0)
	if peso <= 0.0:
		return {"handle":neutro_h,"basis":neutro_b,"chest":0.0,"stance":0.0,"roll":0.0,"pes":0.0,"corpo":0.0,"olhar":0.0}
	var onda := sin(time * TAU / RESPIRO_CICLO)
	var guarda_h := GUARDA_HANDLE + Vector3(0.0, RESPIRO_QUADRIL * onda, 0.0)
	# A respiração inclina a PONTA, não translada a arma: é o peso da lâmina
	# subindo e descendo na mão, que é o que se vê em quem segura algo pesado.
	var guarda_b := Basis(Vector3.UP, GUARDA_GIRO) \
		* Basis(Vector3.RIGHT, GUARDA_INCLINACAO + RESPIRO_PONTA * onda)
	return {
		"handle": neutro_h.lerp(guarda_h, peso),
		"basis": neutro_b.slerp(guarda_b, peso),
		# O corpo vira; o peito volta um pouco; a cabeça desfaz o resto em `pose()`.
		"corpo": GUARDA_CORPO * peso,
		"chest": GUARDA_TRONCO * peso,
		"olhar": peso,
		# `stance` já era o quanto o tronco desce num golpe; aqui ele carrega a
		# mesma ideia para a guarda, e `pes` diz o quanto os pés abrem.
		"stance": peso * (GUARDA_QUADRIL / 0.04),
		"pes": peso * GUARDA_PES,
		"roll": ROLAMENTO_VERTICAL * peso,
	}


## Devolve a cabeça à frente contra a torção do tronco.
##
## O `Chest` gira e leva o pescoço e a cabeça junto — sem isto o personagem em
## guarda olha para o próprio ombro. `quanto` é a fração da torção que a cabeça
## desfaz: 1,0 devolve o olhar exatamente à frente.
##
## Dividido entre pescoço e cabeça de propósito. Toda a compensação num nó só
## produz o pescoço quebrado clássico; repartida, lê como alguém que virou o
## corpo mas manteve os olhos no alvo.
func _olhar_para_frente(torcao: float, quanto: float) -> void:
	if is_zero_approx(torcao) or is_zero_approx(quanto):
		return
	var devolver := -torcao * quanto
	for par in [["Neck", 0.4], ["Head", 0.6]]:
		var nome: String = par[0]
		if not nodes.has(nome):
			continue
		var no: Node3D = nodes[nome]
		no.transform = _rest[nome]
		no.rotation.y += devolver * float(par[1])


## Quanto da guarda vale AGORA. Sobe parado, cai andando, pulando ou caindo.
##
## ⚠️ DE PROPÓSITO SEM `is_on_floor()`. O servidor não roda `move_and_slide` em
## Players remotos, então aquele cache mente para todo mundo que não é o dono —
## e a guarda simplesmente nunca apareceria nos outros jogadores da partida. É a
## mesma armadilha que `YoruController._has_floor()` já contorna com raycast; aqui
## nem isso é preciso, porque a VELOCIDADE responde à pergunta certa: quem está
## parado tem velocidade quase nula nos três eixos, e quem está no ar tem `y`
## grande. Um número replicado vale mais que um cache local.
func _peso_da_guarda(delta: float) -> float:
	var quer := 0.0
	if player is CharacterBody3D:
		var v: Vector3 = player.velocity
		if Vector3(v.x, 0.0, v.z).length() < GUARDA_PARADO and absf(v.y) < GUARDA_QUEDA:
			quer = 1.0
	_guarda = move_toward(_guarda, quer, delta / maxf(GUARDA_TRANSICAO, 0.001))
	return _guarda


func pose(id: String, time: float, facing: Vector3) -> void:
	if not is_instance_valid(model) or not is_instance_valid(sword): return
	var data := sample(id,time)
	if id == "":
		var delta := 1.0/60.0
		if is_instance_valid(player) and player.is_inside_tree():
			delta = player.get_physics_process_delta_time()
		data = guarda_parada(time, _peso_da_guarda(delta))
	else:
		_guarda = 0.0
	if id != "": model.global_rotation.y = atan2(-facing.x,-facing.z)
	if not detailed:
		_legacy_pose(id,time)
		return
	for side in ["L","R"]:
		for part in ["Clavicle_","Scapula_","UpperArm_","ForeArm_","Wrist_","Hand_"]:
			var key: String = part+side
			if nodes.has(key): nodes[key].transform = _rest[key]
	# Parado, as pernas só entram aqui quando a guarda tem peso: com peso zero
	# elas continuam sendo da locomoção, como sempre foram.
	var mistura: float = 1.0 if id != "" else clampf(_guarda, 0.0, 1.0)
	var giro: float = float(data.get("corpo", 0.0))
	if id != "" or mistura > 0.001:
		nodes.Torso.transform = _rest.Torso
		nodes.Torso.position.y -= 0.04*float(data.stance)
		# O corpo de perfil. Gira a RAIZ, não `model`: `model.global_rotation.y` é
		# para onde o personagem encara, e mexer ali torceria mira, movimento e a
		# direção do próprio golpe junto com a pose.
		nodes.Torso.rotation.y += giro
		var abertura: float = float(data.get("pes", 0.0))
		for side in ["L","R"]:
			var foot: Node3D = nodes["Foot_"+side]
			# ⚠️ LIDO ANTES DO RESET. Este é o pé onde a locomoção o deixou neste
			# quadro; é dele que a guarda parte. Sem isso, entrar ou sair da
			# guarda no meio de um passo teleporta o pé para a posição de
			# descanso e a perna pisca.
			var atual := foot.global_position
			for part in ["Thigh_","Shin_","Foot_","Ball_"]:
				var key: String = part+side
				nodes[key].transform = _rest[key]
			var lado: float = -1.0 if side == "L" else 1.0
			# Os pés giram COM o corpo: numa guarda de perfil eles ficam um à
			# frente do outro, não lado a lado. Sem rotacionar o alvo, o quadril
			# vira e as pernas ficam plantadas de frente, torcendo os joelhos.
			var alvo := model.to_global(
				Vector3(lado*(0.195+abertura),0.224,0).rotated(Vector3.UP, giro))
			var anchor: Vector3 = atual.lerp(alvo, mistura) if id == "" else alvo
			solve_two_bone(nodes["Thigh_"+side],nodes["Shin_"+side],foot,anchor,model.global_basis.orthonormalized()*Vector3.FORWARD)
			# O PÉ TAMBÉM VIRA. Forçar `model.global_basis` aqui deixava os dois pés
			# apontados para a frente sob um quadril de perfil — o corpo virava e os
			# pés ficavam para trás, que é o que a captura mostrou.
			#
			# O de trás (direito, o que recuou com a espada) acompanha o giro
			# inteiro; o da frente vira só metade, como quem apoia o passo à frente
			# sem abrir o quadril de todo. Com `giro` zero os dois voltam a ser o
			# que sempre foram, e nenhum golpe muda de comportamento.
			var vira: float = giro * (1.0 if side == "R" else 0.5)
			foot.global_basis = model.global_basis * Basis(Vector3.UP, vira)
	nodes.Chest.rotation = Vector3(0,float(data.chest),0)
	# A cabeça desfaz TUDO o que veio abaixo dela: o giro do corpo mais a torção
	# do peito. Somar os dois aqui é o que garante o olhar na frente qualquer que
	# seja a divisão entre eles.
	_olhar_para_frente(giro + float(data.chest), float(data.get("olhar", 0.0)))
	var model_basis := model.global_basis.orthonormalized()
	var desired_basis := model_basis * Basis(data.basis)
	var target := model.to_global(Vector3(data.handle))
	var wrist_basis := desired_basis * Basis(Vector3.RIGHT,PI)
	_arm("R",target,wrist_basis)
	# ⚠️ O ROLAMENTO DO FIO ENTRA AQUI, E SÓ NA LÂMINA — o punho fica com
	# `desired_basis` limpo. Isso não é atalho: o CABO É REDONDO (a malha `Grip`
	# mede 0,092 × 0,092), então girar a espada em torno dele é REEMPUNHAR, não
	# torcer o braço. A mão continua fechada no mesmo cilindro.
	#
	# Medido, com o punho arrastado junto (a primeira versão desta correção):
	# a mão esquerda ficava a 0,070 m do cabo nos três cortes horizontais, contra
	# um teto de 0,030 m no `test_yoru_rig` — o ombro deste rig não translada,
	# então a IK simplesmente não alcança a empunhadura girada meia volta.
	# Absorvendo o giro no cabo, o erro de pega volta a 0,000 m e o fio continua
	# liderando o corte.
	#
	# `Basis(Vector3.UP, ...)` pós-multiplicado gira em torno do +Y LOCAL da arma,
	# que é o comprimento da lâmina. Ver o cabeçalho deste arquivo.
	# O handle é a origem do socket; a arma tem tamanho de mundo constante.
	sword.global_basis = desired_basis * Basis(Vector3.UP,float(data.get("roll",0.0)))
	var right_grip: Node3D = nodes.get("Grip_R")
	if right_grip: sword.global_position = right_grip.global_position
	var left_target := sword.global_position + desired_basis*Vector3(0,-0.17,0)
	_arm("L",left_target,wrist_basis)
	var left_grip: Node3D = nodes.get("Grip_L")
	grip_error = left_grip.global_position.distance_to(left_target) if left_grip else 0.0
	# Fechar cada falange mantém o cabo no volume dos dedos.
	for side in ["L","R"]:
		for finger in ["Index","Middle","Ring","Little"]:
			for segment in range(1,4):
				var key := "%s%d_%s" % [finger,segment,side]
				if nodes.has(key): nodes[key].rotation.x = -0.65

func _arm(side: String, grip_target: Vector3, wrist_basis: Basis) -> void:
	var upper: Node3D = nodes["UpperArm_"+side]
	var fore: Node3D = nodes["ForeArm_"+side]
	var wrist: Node3D = nodes["Wrist_"+side]
	var grip: Node3D = nodes.get("Grip_"+side)
	if not grip: return
	var s := wrist.global_basis.get_scale()
	var offset := wrist.to_local(grip.global_position)
	var target := grip_target - wrist_basis*(offset*s)
	solve_two_bone(upper,fore,wrist,target,model.global_basis.orthonormalized()*Vector3(-1 if side == "L" else 1,-0.65,0.15))
	wrist.global_basis = wrist_basis.scaled(s)

static func solve_two_bone(upper: Node3D, lower: Node3D, end: Node3D, target: Vector3, pole: Vector3) -> void:
	var origin := upper.global_position
	var l1 := origin.distance_to(lower.global_position)
	var l2 := lower.global_position.distance_to(end.global_position)
	var axis := (target-origin).normalized()
	var distance := clampf(origin.distance_to(target),absf(l1-l2)+0.00001,l1+l2-0.00001)
	var projection := (l1*l1-l2*l2+distance*distance)/(2.0*distance)
	var bend := (pole-axis*pole.dot(axis)).normalized()
	if bend.length_squared() < 0.1: bend = axis.cross(Vector3.FORWARD).normalized()
	var elbow := origin+axis*projection+bend*sqrt(maxf(0,l1*l1-projection*projection))
	_aim_child(upper,lower,elbow)
	_aim_child(lower,end,origin+axis*distance)

static func _aim_child(parent: Node3D, child: Node3D, target: Vector3) -> void:
	var from := (child.global_position-parent.global_position).normalized()
	var to := (target-parent.global_position).normalized()
	if from.length_squared() < 0.5 or to.length_squared() < 0.5: return
	parent.global_basis = Basis(Quaternion(from,to))*parent.global_basis


func _legacy_pose(id: String, time: float) -> void:
	var offsets := {}
	var add := func(off: Dictionary, key: String, value: Vector3) -> void:
		off[key] = Vector3(off.get(key,Vector3.ZERO))+value
	WeaponPoses.two_handed_sword_idle(add,offsets,1.0,0.0)
	if id != "":
		var m := YoruMoves.get_move(id)
		var duration := YoruMoves.duration(id)
		var kind := 1 if id in ["M1_2","V"] else 0
		var ini := float(m.startup)/duration
		var end := (float(m.startup)+float(m.active))/duration
		WeaponPoses.two_handed_sword_slash(add,offsets,1.0,time/duration,kind,ini,end)
		sword.rotation = WeaponPoses.postura_da_arma(kind,WeaponPoses._get_slash_frame(time/duration,ini,end))
	else: sword.rotation = Vector3.ZERO
	for key in offsets:
		if nodes.has(key): nodes[key].rotation = Transform3D(_rest[key]).basis.get_euler()+Vector3(offsets[key])
	var animator = player.get("_proc_anim")
	if is_instance_valid(animator) and animator.get("_driver") != null:
		animator.get("_driver").push()
