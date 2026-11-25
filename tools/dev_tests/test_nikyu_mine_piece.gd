extends SceneTree
## Nikyu Nikyu (Mine Piece), A10: a tradução nativa das técnicas, uma a uma. 21 Pad Ho (tapa e Tsuppari), 22 Ursus Shock, 25 Assault, 28 Kuma Punch e a passiva 29.
## Save e mapa isolados. A fruta está "em porte" (fora da loja), então é equipada direto.
const MAPA := "user://test_nikyu_mine_piece_mapa.json"
const SAVE := "user://test_nikyu_mine_piece_progresso.json"
const ID := "nikyu_nikyu_mine_piece"
const ESCALA := 1.0 / 10.0   # PerfilDeFrutas.ESCALA_DO_MOD
var falhas := 0
var passou := 0

class Alvo extends Node3D:
	var health := 100000.0
	var combate_direcional = null
	func _ready() -> void:
		add_to_group("alvo_de_golpe")
		var hb := Area3D.new()
		hb.name = "Hurtbox"
		hb.collision_layer = 0
		hb.collision_mask = 0
		add_child(hb)
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(4, 2, 2)
		cs.shape = caixa
		hb.add_child(cs)
	func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
		health -= dano

func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	await process_frame
	# Estes testes medem a duração em TICKS do mod: rodam no relógio do mod (1.0). A velocidade reduzida dos projéteis (0,5) tem teste próprio.
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	var controle = load("res://src/combat/frutas_mine_piece/controlador.gd")
	var mapa := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, mapa.mapa)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	# O ciclo dia/noite move a sobrevivência, que a cada 15 s de jogo emite `progressao.mudou` e REAPLICA o progresso, desfazendo a
	# fruta que este teste equipa direto (sem passar pelo progresso): derrubava o controlador por volta do 900º quadro (o Assault).
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	conferir("na loja e no save (A10 concluída)", CatalogoFrutasMinePiece.ids().has(ID) and CatalogoFrutasMinePiece.contem(ID))
	conferir("substitui a Nikyu do Builder: o save antigo migra para esta", CatalogoFrutasMinePiece.atual("nikyu_nikyu_no_mi_mine_piece") == ID
		and CatalogoFrutasMinePiece.substituida("nikyu_nikyu_no_mi_mine_piece"))
	var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS[ID]
	conferir("as quatro técnicas do ciclo R (21, 22, 25, 28) e o toque duplo 29", ficha.ciclo.map(func(f): return int(f.numero)) == [21, 22, 25, 28] and int(ficha.toque_duplo) == 29)
	conferir("poses importadas", FileAccess.file_exists("res://assets/mine_piece/frutas/nikyu/poses.json"))
	modo.equipar_fruta(p, ID)
	await quadros(15)
	var c = controle.de(p)
	conferir("controlador ativo", c != null and c.fruta_ativa())
	if c == null:
		finalizar(modo)
		return
	conferir("não é logia (sem corpo elemental)", c.corpo == null)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	p.set_meta("damage_immune", true)
	await quadros(30)
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 1.2, -9)
	p.max_energy = 4000.0
	p.energy = p.max_energy

	# ------------------------------------------------------------ 21 Pad Ho
	var antes: float = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("Pad Ho começa", c.ativo and c.selecao == 21)
	conferir("custo 50 de energia (%.3f)" % (antes - float(p.energy)), absf(antes - float(p.energy) - 50.0) < 0.5)
	conferir("recarga max(50 × 0,5, 5) ticks = 1,25 s", is_equal_approx(c.recarga_total, 1.25))
	await quadros(40)
	conferir("segurar prende cnt1 em 4 e carrega", c.ativo and c.executor.cnt1 == 4 and c.executor.cnt6 > 0.5)
	conferir("Lentidão V na carga", c.lentidao == 4)
	conferir("carga não cria pata", get_nodes_in_group("pata_nikyu_mine_piece").is_empty())
	var carga: float = c.executor.cnt6
	tecla_sel(c, false)
	await quadros(12)
	var patas := get_nodes_in_group("pata_nikyu_mine_piece")
	conferir("soltar cria 1 pata (cnt1 = 7)", patas.size() == 1)
	if patas.size() == 1:
		var pata = patas[0]
		var malhas := pata.find_children("*", "MeshInstance3D", true, false)
		var luminosa := false
		for m in malhas:
			var mat := (m as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
			luminosa = luminosa or (mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and mat.albedo_color.a > 0.3)
		conferir("a pata é VISÍVEL: modelo do mod (pad.geo) com o brilho do PadLayer", not malhas.is_empty() and luminosa)
		conferir("pata é a PadEntity de 1 × 1 com a carga do dono", is_equal_approx(pata.cnt6, carga) and pata.potencia == 8.0)
		conferir("tamanho = tamanho do jogador × (1 + cnt6 × 0,2)",
			absf(pata.tamanho - MundoMinePiece.tamanho(1.8, 0.6) * (1.0 + carga * 0.2)) < 0.001)
	await quadros(60)
	conferir("Pad Ho termina", not c.ativo)
	var esperado := 15.0 * (1.0 + carga * 0.1) * 10.0 * ESCALA
	var acertos := (100000.0 - alvo.health) / esperado
	conferir("a pata fere 15 × CNT6 uma vez por janela (%.2f × %.2f)" % [acertos, esperado],
		acertos > 0.99 and acertos < 2.01 and absf(acertos - roundf(acertos)) < 0.01)
	conferir("a pata some depois de 10 ticks", get_nodes_in_group("pata_nikyu_mine_piece").is_empty())

	# ------------------------------------------------ 21 com Shift: Tsuppari
	c.recarga = 0.0
	alvo.health = 100000.0
	c.imunidade.clear()
	p.energy = p.max_energy
	tecla(KEY_SHIFT, true)
	await quadros(2)
	tecla_sel(c, true)
	await quadros(60)
	conferir("Tsuppari prende em cnt1 = 14 com Z segurado", c.ativo and c.executor.cnt10 == 1 and c.executor.cnt1 == 14)
	conferir("Lentidão V o tempo todo", c.lentidao == 4)
	var vistas := 0
	for i in 12:
		vistas += get_nodes_in_group("pata_nikyu_mine_piece").size()
		await quadros(1)
	conferir("solta patas pequenas enquanto segura (%d)" % vistas, vistas > 0)
	var pequena = get_nodes_in_group("pata_nikyu_mine_piece")
	if not pequena.is_empty():
		conferir("pata do Tsuppari: 0,25 do tamanho, potência 6, cnt6 −0,15",
			absf(pequena[0].tamanho - 0.25 * MundoMinePiece.tamanho(1.8, 0.6)) < 0.001 and pequena[0].potencia == 6.0
			and is_equal_approx(pequena[0].cnt6, -0.15))
	tecla_sel(c, false)
	await quadros(90)
	conferir("Tsuppari termina depois de soltar", not c.ativo)
	conferir("e as patas somem", get_nodes_in_group("pata_nikyu_mine_piece").is_empty())
	conferir("o alvo levou dano (%.2f)" % (100000.0 - alvo.health), alvo.health < 100000.0)
	tecla(KEY_SHIFT, false)

	# ------------------------------------------------------------ 22 Ursus Shock
	await quadros(30)
	c.recarga = 0.0
	alvo.health = 100000.0
	c.imunidade.clear()
	avancar(c)
	await quadros(2)
	conferir("R passa para o 22", c.selecao == 22)
	p.energy = p.max_energy
	antes = p.energy
	tecla_sel(c, true)
	await quadros(2)
	# tolerância 3.0: a energia regenera ~0,8 em 2 quadros (máx. 4000); 0,5 era de quando a regen era menor
	conferir("Ursus Shock custa 600 e recarrega 15 s", absf(antes - float(p.energy) - 600.0) < 3.0 and is_equal_approx(c.recarga_total, 15.0))
	await quadros(3)
	conferir("Lentidão X: o corpo não anda", c.lentidao == 9 and c.controla_movimento())
	var gigante = get_nodes_in_group("pata_nikyu_mine_piece")
	conferir("nasce a pata gigante no tick 1 (modo 1, tamanho 20)", gigante.size() == 1 and gigante[0].modo == 1 and gigante[0].tamanho > 15.0)
	await quadros(90)
	conferir("segurar prende cnt1 em 19", c.ativo and c.executor.cnt1 == 19)
	var seguindo = get_nodes_in_group("pata_nikyu_mine_piece")
	conferir("a pata encolhe até 0,5 e fica colada na âncora",
		seguindo.size() == 1 and seguindo[0].modo == 1 and seguindo[0].tamanho == 0.5
		and seguindo[0].global_position.distance_to(c.executor.ancora) < 0.01)
	conferir("nada de dano enquanto segura", alvo.health == 100000.0)
	tecla_sel(c, false)
	await quadros(6)
	var solta = get_nodes_in_group("pata_nikyu_mine_piece")
	conferir("soltar vira modo 2 (voa)", solta.size() == 1 and solta[0].modo == 2)
	await quadros(150)
	conferir("a onda some e a técnica termina", get_nodes_in_group("pata_nikyu_mine_piece").is_empty() and not c.ativo)
	var golpes := (100000.0 - alvo.health) / (30.0 * 10.0 * ESCALA)
	conferir("a onda fere 30 por janela de imunidade (%.2f golpes)" % golpes, golpes > 0.99 and absf(golpes - roundf(golpes)) < 0.01)

	# ------------------------------------------------------------ 25 Assault
	await quadros(30)
	c.recarga = 0.0
	alvo.health = 100000.0
	c.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	await quadros(10)
	avancar(c)
	await quadros(2)
	conferir("R passa para o 25", c.selecao == 25)
	p.energy = p.max_energy
	antes = p.energy
	tecla_sel(c, true)
	await quadros(2)
	conferir("Assault custa 200 e recarrega 5 s (a conta geral: max(200 × 0,5; 5) ticks)", absf(antes - float(p.energy) - 200.0) < 3.0 and is_equal_approx(c.recarga_total, 5.0))
	await quadros(80)
	conferir("segurar prende cnt2 em 9 e carrega 0,125 por tick", c.ativo and c.executor.cnt2 == 9.0 and c.executor.cnt6 > 0.5
		and absf(fmod(c.executor.cnt6, 0.125)) < 0.0001)
	conferir("Lentidão X na carga", c.lentidao == 9)
	var carga_a: float = c.executor.cnt6
	var z_antes: float = p.global_position.z
	tecla_sel(c, false)
	await quadros(8)
	conferir("a investida avança em direção ao alvo", p.global_position.z < z_antes - 2.0)
	conferir("o dono fica invisível na investida e na explosão", p.has_meta("mine_piece_invisivel"))
	await quadros(12)
	var patas_a = get_nodes_in_group("pata_nikyu_mine_piece")
	await quadros(20)
	conferir("a pata de modo 3 nasce no cnt1 = 9", patas_a.size() == 1 and patas_a[0].modo == 3 or alvo.health < 100000.0)
	await quadros(80)
	conferir("Assault termina e o dono reaparece", not c.ativo and not p.has_meta("mine_piece_invisivel"))
	conferir("a pata de modo 3 some", get_nodes_in_group("pata_nikyu_mine_piece").is_empty())
	carga_a = c.executor.cnt6      # a carga ainda cresce 0,125 no tick em que Z é solto: vale o valor final
	var dano_a := 30.0 * (1.0 + (-5.0 + carga_a * 0.6) * 0.1) * 10.0 * ESCALA
	var golpes_a := (100000.0 - alvo.health) / dano_a
	conferir("a explosão fere 30 × CNT6 por janela (%.2f golpes de %.2f)" % [golpes_a, dano_a],
		golpes_a > 0.99 and absf(golpes_a - roundf(golpes_a)) < 0.01)


	# ------------------------------------------------------------ 28 Kuma Punch
	await quadros(30)
	c.recarga = 0.0
	alvo.health = 100000.0
	c.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	await quadros(10)
	avancar(c)
	await quadros(2)
	conferir("R passa para o 28", c.selecao == 28)
	p.energy = p.max_energy
	antes = p.energy
	tecla_sel(c, true)
	await quadros(2)
	conferir("Kuma Punch custa 500 e recarrega 12,5 s", absf(antes - float(p.energy) - 500.0) < 3.0 and is_equal_approx(c.recarga_total, 12.5))
	await quadros(80)
	conferir("segurar prende cnt2 em 9 e carrega 0,125 por tick", c.ativo and c.executor.cnt2 == 9.0 and c.executor.cnt6 > 0.5
		and absf(fmod(c.executor.cnt6, 0.125)) < 0.0001)
	conferir("a carga mantém a recarga cheia", is_equal_approx(c.recarga, c.recarga_total))
	conferir("sem Lentidão na carga (o mod só tira a Lentidão ao soltar)", c.lentidao == -1)
	var carga_k: float = c.executor.cnt6
	z_antes = p.global_position.z
	tecla_sel(c, false)
	await quadros(8)          # 1 tick do mod = 3 quadros: solta no 1º, lança no 2º e a investida corre no 3º
	conferir("a investida avança em direção ao alvo", p.global_position.z < z_antes - 2.0)
	conferir("o dono fica invisível na investida", p.has_meta("mine_piece_invisivel"))
	var parou_em := -1
	for i in 30:
		await quadros(1)
		if c.executor.cnt1 >= 5 and parou_em < 0:
			parou_em = int(c.executor.cnt1)
	conferir("a investida cola no alvo e passa para a fase do soco (cnt1 ≥ 5)", parou_em >= 5)
	conferir("cola no alvo (a folga até a caixa do alvo é pequena: z = %.2f)" % p.global_position.z,
		p.global_position.z < -5.0 and p.global_position.z > -8.0)
	carga_k = c.executor.cnt6      # a carga ainda cresce 0,125 no tick em que Z é solto: vale o valor final
	var k6_k := 1.0 + carga_k * 0.1
	await quadros(int((8.0 * k6_k + 25.0) * 3.0) + 30)      # termina em 8 × CNT6 + 25 TICKS (3 quadros cada)
	conferir("Kuma Punch termina e o dono reaparece", not c.ativo and not p.has_meta("mine_piece_invisivel"))
	var golpes_k := (100000.0 - alvo.health) / (24.0 * k6_k * 10.0 * ESCALA)
	conferir("o soco fere 24 × CNT6 por janela de imunidade; os de 18 passam só se excederem (%.2f golpes)" % golpes_k,
		golpes_k > 0.99 and absf(golpes_k - roundf(golpes_k)) < 0.01)

	# ------------------------------------------------------------ 29 passiva (toque duplo)
	await quadros(30)
	c.recarga = 0.0
	alvo.health = 100000.0
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	await quadros(10)
	p.energy = p.max_energy
	antes = p.energy
	conferir("a passiva começa com W duplo", c.comecar_passiva(1) and c.ativo and c.executor.tecnica == 29)
	await quadros(4)
	conferir("Lentidão X e invisível nos dois primeiros ticks", p.has_meta("mine_piece_invisivel"))
	await quadros(20)
	conferir("a passiva termina em ~5 ticks (15 quadros)", not c.ativo and not p.has_meta("mine_piece_invisivel"))
	conferir("para na frente do alvo (z = %.2f)" % p.global_position.z, p.global_position.z < -5.5 and p.global_position.z > -7.4)
	conferir("sem custo de energia", absf(antes - float(p.energy)) < 0.01)
	conferir("sem recarga", c.recarga == 0.0)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	await quadros(10)
	conferir("a passiva começa com S duplo", c.comecar_passiva(-1) and c.executor.cnt1 == 0)
	await quadros(12)
	conferir("para trás vai 48 × 0,5 blocos sem parar em alvo (z = %.2f)" % p.global_position.z,
		p.global_position.z > 15.0 and p.global_position.z < 22.0)

	modo.equipar_fruta(p, "goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove o controlador", controle.de(p) == null)
	finalizar(modo)

## 08/11/2026: o R não troca mais a técnica (cada uma tem a sua tecla). Os testes seguem a ordem do ciclo por aqui.
func avancar(c, para_tras := false) -> void:
	var ciclo: Array = CatalogoFrutasMinePiece.FICHAS[c.fruta_id].ciclo
	var i := 0
	for k in ciclo.size():
		if int(ciclo[k].numero) == c.selecao:
			i = k
	c.selecao = int(ciclo[posmod(i + (-1 if para_tras else 1), ciclo.size())].numero)


## A tecla (Z X C V B N) da técnica em `c.selecao`.
func tecla_sel(c, apertou: bool) -> void:
	var mapa: Dictionary = c.mapa_de_teclas()
	for letra: String in mapa:
		if int(mapa[letra]) == c.selecao:
			tecla(OS.find_keycode_from_string(letra), apertou)
			return


func tecla(codigo: Key, apertou: bool, shift := false) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertou
	evento.shift_pressed = shift
	Input.parse_input_event(evento)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func conferir(nome: String, ok: bool) -> void:
	if ok: passou += 1
	else: falhas += 1
	print("%s %s" % ["OK" if ok else "FALHA", nome])

func finalizar(modo) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("NIKYU_MINE_PIECE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
