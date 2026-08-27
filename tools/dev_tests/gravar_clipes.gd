extends SceneTree
# ============================================================================
#  GRAVADOR DE CLIPES — 12 tomadas do jogo, pela CÂMERA DE VERDADE.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/gravar_clipes.gd -- <pasta>
#  Depois:
#    ffmpeg junta cada pasta num .mp4 (ver tools/gravar_clipes.sh)
#
#  POR QUE CLIPE E NÃO CAPTURA SOLTA: os três defeitos relatados pelo dono —
#  defeito ao olhar para trás, defeito ao pular, e blocos que somem — são todos
#  de MOVIMENTO. Bloco que some é descarte de renderização (culling), e culling
#  por definição só aparece quando o que está em quadro muda. Quadro parado é
#  justamente onde esses três se escondem.
#
#  ⚠️ E É A SEGUNDA VEZ QUE ISSO MORDE. O portão visual do projeto
#  (`captura_visual.gd`) cria uma Camera3D PRÓPRIA e nunca passa pelo CameraRig,
#  então nenhum defeito de câmera cabia nele. Este gravador usa a câmera do jogo
#  e mexe nela como o jogador mexe: `_yaw`, `_pitch` e teclas de verdade.
#
#  COMO A ENTRADA É SIMULADA: o `move_frame.gd` lê `Input.is_physical_key_pressed`,
#  então apertar tecla de mentira não funciona — é preciso injetar um
#  `InputEventKey` de verdade com `Input.parse_input_event`, que é o que
#  atualiza o estado físico das teclas. Por isso o pulo aqui é um pulo REAL,
#  com a física do jogo, e não um empurrão no `velocity`.
# ============================================================================

const QUADROS := 60          # por clipe (~2 s a 30 fps)
const CLIPES := [
	"01_giro_360",              # a volta completa: o defeito "ao olhar para trás"
	"02_olhar_para_tras_lento", # o mesmo, devagar, para pegar o instante da virada
	"03_pulo_de_lado",          # o pulo visto de fora
	"04_pulo_olhando_para_tras",# pulo + rumo de trás: os dois defeitos juntos
	"05_andando_para_frente",
	"06_andando_para_tras",     # andar de costas mexe corpo e câmera em sentidos opostos
	"07_orbita_pilar",          # volta ao redor de um bloco alto
	"08_afastando_do_pilar",    # o bloco encolhendo: é onde culling por distância apareceria
	"09_pitch_cima_baixo",      # olhar para o céu e para os pés
	"10_borda_do_buraco",       # a beirada de um buraco de verdade
	"11_primeira_pessoa",       # a outra perspectiva, que tem outra cadeia de câmera
	"12_pilar_saindo_de_quadro",# bloco entrando e saindo pela BORDA: o teste de culling
]

var _p: Node3D
var _pilar: Node3D
var _buraco: Vector3

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/clipes"

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame

	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())

	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			_p = n
			break
	if _p == null:
		print("❌ sem jogador — a cena não subiu"); quit(1); return
	# Os bonecos socam sozinhos: mudariam o clipe e o jogador levaria dano.
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	_p.set_meta("damage_immune", true)

	_pilar = _achar_pilar()
	_buraco = _achar_buraco()
	print("pilar em %s (altura %.1f) | buraco em %s" % [
		str(_pilar.global_position) if _pilar else "—",
		_pilar.scale.y if _pilar else 0.0, str(_buraco)])

	for nome in CLIPES:
		var pasta := "%s/%s" % [saida, nome]
		DirAccess.make_dir_recursive_absolute(pasta)
		await _gravar(nome, pasta)
		print("  ✓ %s" % nome)

	_soltar_tudo()
	print("\n✓ %d clipes em %s" % [CLIPES.size(), saida])
	quit()

func _gravar(nome: String, pasta: String) -> void:
	_preparar(nome)
	for q in QUADROS:
		var t := float(q) / float(QUADROS - 1)   # 0 -> 1
		_atualizar(nome, t, q)
		await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/f%04d.png" % [pasta, q])
	_soltar_tudo()

# Estado inicial de cada tomada. Separado do `_atualizar` porque teleporte no
# meio do clipe estraga a leitura do movimento.
func _preparar(nome: String) -> void:
	_p.velocity = Vector3.ZERO
	match nome:
		"07_orbita_pilar", "08_afastando_do_pilar", "12_pilar_saindo_de_quadro":
			if _pilar:
				var d: Vector3 = _pilar.global_position
				_p.global_position = Vector3(d.x, 2.0, d.z + 14.0)
			else:
				_p.global_position = Vector3(0, 2.0, 0)
		"10_borda_do_buraco":
			_p.global_position = _buraco + Vector3(0, 2.0, 9.0)
		_:
			_p.global_position = Vector3(0, 2.0, 0)
	if _p._camera.em_primeira_pessoa() and nome != "11_primeira_pessoa":
		_p._camera.alternar_perspectiva()
	elif nome == "11_primeira_pessoa" and not _p._camera.em_primeira_pessoa():
		_p._camera.alternar_perspectiva()

func _atualizar(nome: String, t: float, quadro: int) -> void:
	var yaw := 0.0
	var pitch := -0.25
	match nome:
		"01_giro_360":
			yaw = t * TAU
		"02_olhar_para_tras_lento":
			yaw = t * PI
		"03_pulo_de_lado":
			yaw = PI * 0.5
			_pular_a_cada(quadro, 24)
		"04_pulo_olhando_para_tras":
			yaw = PI
			_pular_a_cada(quadro, 24)
		"05_andando_para_frente":
			_tecla(KEY_W, true)
		"06_andando_para_tras":
			_tecla(KEY_S, true)
		"07_orbita_pilar":
			# O jogador dá a volta; a câmera segue olhando para o pilar.
			if _pilar:
				var c: Vector3 = _pilar.global_position
				var a := t * TAU
				_p.global_position = Vector3(c.x + sin(a) * 14.0, 2.0, c.z + cos(a) * 14.0)
				yaw = a + PI
		"08_afastando_do_pilar":
			if _pilar:
				var c: Vector3 = _pilar.global_position
				_p.global_position = Vector3(c.x, 2.0, c.z + 6.0 + t * 70.0)
				yaw = PI
		"09_pitch_cima_baixo":
			pitch = lerpf(0.5, -1.2, t)
		"10_borda_do_buraco":
			_tecla(KEY_W, true)
			yaw = 0.0
		"11_primeira_pessoa":
			yaw = t * TAU
		"12_pilar_saindo_de_quadro":
			# Gira devagar em torno do rumo do pilar: ele entra por uma borda da
			# tela e sai pela outra. Se ele sumir ANTES de encostar na borda, é
			# descarte errado — e é isso que o clipe existe para mostrar.
			yaw = PI + sin(t * TAU) * 1.1
	_p._yaw = yaw
	_p._pitch = pitch
	_p._camera.apontar(yaw, pitch)

func _pular_a_cada(quadro: int, periodo: int) -> void:
	_tecla(KEY_SPACE, quadro % periodo < 3)

func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)

func _soltar_tudo() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_SHIFT]:
		_tecla(k, false)

# O bloco mais alto perto do centro — é o que o dono chama de "pilar".
func _achar_pilar() -> Node3D:
	var melhor: Node3D = null
	for n in _todos(get_root()):
		if not (n is StaticBody3D) or n.name == "Plataforma":
			continue
		var b := n as Node3D
		if b.scale.y < 6.0:
			continue
		var d := Vector2(b.global_position.x, b.global_position.z).length()
		if d > 60.0:
			continue
		if melhor == null or b.scale.y > melhor.scale.y:
			melhor = b
	return melhor

# Buraco DE VERDADE, achado por raio (não depende dos internos do MapBuilder).
func _achar_buraco() -> Vector3:
	var espaco := (get_root().world_3d as World3D).direct_space_state
	for gz in range(3, 18):
		for gx in range(3, 18):
			var x := (gx - 10) * MapBuilder.CELL + MapBuilder.CELL * 0.5
			var z := (gz - 10) * MapBuilder.CELL + MapBuilder.CELL * 0.5
			if Vector2(x, z).length() < MapBuilder.SAFE_RADIUS + 6.0:
				continue
			var par := PhysicsRayQueryParameters3D.create(
				Vector3(x, 30, z), Vector3(x, -30, z))
			if espaco.intersect_ray(par).is_empty():
				return Vector3(x, 0, z)
	return Vector3(40, 0, 40)

func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(_todos(f))
	return out

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)
