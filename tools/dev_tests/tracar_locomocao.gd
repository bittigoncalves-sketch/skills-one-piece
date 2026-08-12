extends SceneTree
## TRAÇO DE LOCOMOÇÃO — rede de segurança da Fase 4 (partição do movimento).
##
## O caminho de todo quadro é o código mais perigoso do Player: um erro aqui
## aparece como "o personagem não anda" ou "atravessa parede", e NENHUMA suíte
## atual pega isso. Este script dirige o player com um roteiro de teclas fixo e
## grava a trajetória quadro a quadro.
##
## USO: rode ANTES de mexer, guarde o arquivo, mexa, rode de novo e compare.
## Se um único número mudar sem que a mudança fosse intencional, é regressão.
##
##   godot --path . --script tools/dev_tests/tracar_locomocao.gd -- saida.txt
##
## PRECISA de janela (DISPLAY): a locomoção só lê teclado com o mouse CAPTURADO,
## e não dá pra capturar mouse sem servidor de vídeo.

# ROTEIRO: [quadros, teclas]. Cobre de propósito andar, correr, pular, salto
# longo, dash, geppo (pulo duplo no ar) e queda.
const ROTEIRO := [
	[30, []],                       # parado: assenta no chão
	[45, [KEY_W]],                  # andar
	[45, [KEY_W, KEY_SHIFT]],       # correr
	[10, [KEY_W, KEY_SHIFT, KEY_SPACE]],   # SALTO LONGO (borda do espaço)
	[35, [KEY_W, KEY_SHIFT]],       # ...no ar
	[6,  [KEY_W, KEY_SPACE]],       # GEPPO (2º pulo no ar)
	[40, [KEY_W]],                  # queda
	[20, [KEY_W, KEY_Q]],           # arma o dash (segurando Q)
	[30, [KEY_W]],                  # solta Q -> DASH dispara
	[25, [KEY_A]],                  # strafe
	[25, [KEY_S]],                  # ré
	[30, []],                       # parar
]

var _teclas_ativas := {}

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "traco.txt"

	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	var p: Node = null
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	if p == null:
		print("### SEM PLAYER — a porta 24565 pode estar ocupada"); quit(1); return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("### mouse nao capturou — rode COM janela (DISPLAY=:1)"); quit(1); return

	# Posição e mira fixas: o traço tem que ser reproduzível.
	p.global_position = Vector3(0, 3, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	await _quadros(5)

	var linhas: Array[String] = []
	var n := 0
	for passo in ROTEIRO:
		_aplicar(passo[1])
		for i in int(passo[0]):
			await _quadros(1)
			n += 1
			linhas.append("%04d pos=%s vel=%s chao=%s esc=%s dash=%.3f roll=%.3f lj=%.3f geppo=%d" % [
				n, _v(p.global_position), _v(p.velocity), "1" if p.is_on_floor() else "0",
				"1" if p._is_climbing else "0", p._dash_t, p._roll_t, p._long_jump_t, p._geppo_count])
	_aplicar([])

	# ---------------------------------------------------------------- PAREDE
	# O trecho acima é todo em chão plano — e parkour de parede (wall run,
	# escalada, mantle) é justamente o que a Fase 4 mais mexe. Aqui a gente acha
	# uma parede DE VERDADE no mapa e corre contra ela. A parede é escolhida por
	# varredura determinística, então o traço continua reproduzível.
	var parede := _achar_parede(p)
	if parede == Vector3.ZERO:
		linhas.append("SEM PAREDE ENCONTRADA")
	else:
		linhas.append("parede em %s" % _v(parede))
		for roteiro_parede in [
			[35, [KEY_W, KEY_SHIFT]],   # correr contra ela: vault ou wall run
			[30, [KEY_W, KEY_SPACE]],   # ESCALADA (espaço + avançar na parede)
			[20, [KEY_W]],              # soltar espaço: cai
		]:
			# reposiciona antes de cada tentativa p/ o teste não depender da anterior
			p.global_position = parede
			p.velocity = Vector3.ZERO
			p._is_climbing = false
			await _quadros(3)
			_aplicar(roteiro_parede[1])
			for i in int(roteiro_parede[0]):
				await _quadros(1)
				n += 1
				linhas.append("%04d pos=%s vel=%s chao=%s esc=%s dash=%.3f roll=%.3f lj=%.3f geppo=%d" % [
					n, _v(p.global_position), _v(p.velocity), "1" if p.is_on_floor() else "0",
					"1" if p._is_climbing else "0", p._dash_t, p._roll_t, p._long_jump_t, p._geppo_count])
		_aplicar([])

	var f := FileAccess.open(saida, FileAccess.WRITE)
	for l in linhas: f.store_line(l)
	f.close()
	print("### traco gravado: ", saida, "  (", linhas.size(), " quadros)")
	quit(0)

# Varre o mapa em espiral procurando uma superfície VERTICAL e devolve um ponto
# no chão logo à frente dela, com o player já olhando para -Z contra a parede.
# Determinístico: mesma ordem de varredura, mesmo mapa, mesma resposta.
func _achar_parede(p: Node3D) -> Vector3:
	var espaco := p.get_world_3d().direct_space_state
	for raio in [6.0, 10.0, 14.0, 20.0, 28.0]:
		for passo in 16:
			var ang := TAU * float(passo) / 16.0
			var centro := Vector3(sin(ang) * raio, 2.0, cos(ang) * raio)
			var par := PhysicsRayQueryParameters3D.create(centro, centro + Vector3(0, 0, -6.0))
			par.exclude = [p.get_rid()]
			var hit := espaco.intersect_ray(par)
			if hit.is_empty():
				continue
			var nrm: Vector3 = hit["normal"]
			if absf(nrm.y) > 0.3:
				continue                       # chão ou teto, não serve
			# 1,2 m à frente da parede, no chão
			var ponto: Vector3 = hit["position"] + nrm * 1.2
			ponto.y = 1.0
			return ponto
	return Vector3.ZERO

# Solta o que saiu do roteiro e aperta o que entrou (senão a tecla fica grudada).
func _aplicar(teclas: Array) -> void:
	for k in _teclas_ativas.keys():
		if not teclas.has(k): _tecla(k, false)
	for k in teclas:
		if not _teclas_ativas.has(k): _tecla(k, true)
	_teclas_ativas.clear()
	for k in teclas: _teclas_ativas[k] = true

func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)

func _v(v: Vector3) -> String:
	return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]

func _quadros(n: int) -> void:
	for i in n: await physics_frame

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0): await process_frame
