extends SceneTree
# ============================================================================
#  VARREDURA DO RELEVO EM BLOCOS NAS ILHAS DE VERDADE (23/10/2026,
#  docs/RELEVO_EM_BLOCOS_PLANO.md). Pedido do dono: "testes com o novo relevo e a
#  interação do personagem com cada parte dele".
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_varredura_relevo.gd
#
#  Acha na grade de cada ilha bordas RETAS e limpas (platô ≥ 3 meios atrás, patamar
#  ≥ 5 meios à frente — cabe a parábola da queda —, 3 meios de largura — a cápsula tem 1 m —, acima do mar) e atravessa cada uma andando
#  com W, nas quatro direções. Esperado por desnível (em meios blocos, 0,44 m):
#    descida qualquer ... passa e pousa embaixo
#    +1 (meio bloco/escada) sobe sozinho
#    ≥ +2 (bloco inteiro) .. para na parede (certo: pede pulo)
#  O defeito de 23/10 (lâmina de 3 mm no topo da parede) aparecia como "parado com
#  só contatos de chão" — é o que este teste caça.
# ============================================================================

const M := RelevoEmBlocos.MEIO
const ILHAS := ["ilha_inicial", "ilha_wano", "ilha_dos_macacos", "ilha_shandora"]
## Amostras por (ilha, desnível): o bastante para cada tipo de borda aparecer.
const POR_CATEGORIA := 6
const QUADROS := 70
const DIRECOES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var p: CharacterBody3D
var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func tecla(codigo: Key, pressionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = pressionada
	Input.parse_input_event(evento)


static func categoria(d: int) -> String:
	if d < -4:
		return "desce ≥5"
	if d < 0:
		return "desce %d" % -d
	return "sobe 1" if d == 1 else "sobe ≥2"


## Borda reta e limpa entre (i, j) e o vizinho na direção `d`: altura do lado de cá
## e do lado de lá, ou Vector2i(SEM, SEM) se não serve.
static func borda(r: RelevoEmBlocos, i: int, j: int, d: Vector2i) -> Vector2i:
	var nada := Vector2i(RelevoEmBlocos.SEM, RelevoEmBlocos.SEM)
	var lado := Vector2i(-d.y, d.x)
	var hs := r._f(i, j)
	var hd := r._f(i + d.x, j + d.y)
	if hs == RelevoEmBlocos.SEM or hd == RelevoEmBlocos.SEM or hs == hd or mini(hs, hd) < 2:
		return nada
	for l in range(-1, 2):
		for k in 5:
			var atras := Vector2i(i, j) - d * mini(k, 2) + lado * l
			var frente := Vector2i(i, j) + d * (k + 1) + lado * l
			if r._f(atras.x, atras.y) != hs or r._f(frente.x, frente.y) != hd:
				return nada
	return Vector2i(hs, hd)


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_varredura_relevo.json")
	root.get_node("GameFlow").start_story()
	await quadros(240)
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	await quadros(30)
	var acima: float = p.global_position.y - _chao_sob(p.global_position)

	var raiz := current_scene.find_child("Mapa", true, false)
	var resumo := {}
	for corpo in raiz.get_children():
		if not corpo.has_meta(RelevoEmBlocos.META) or not ILHAS.has(corpo.get_meta("ilha")):
			continue
		var ilha: String = corpo.get_meta("ilha")
		var r: RelevoEmBlocos = corpo.get_meta(RelevoEmBlocos.META)
		var rng := RandomNumberGenerator.new()
		rng.seed = 23102026
		var feitas := {}
		var tentativas := 0
		print("\n== %s ==" % ilha)
		while tentativas < 400000 and feitas.size() < 7 * POR_CATEGORIA:
			tentativas += 1
			var i := rng.randi_range(0, r.largura - 1)
			var j := rng.randi_range(0, r.profundidade - 1)
			var d: Vector2i = DIRECOES[rng.randi_range(0, 3)]
			var h := borda(r, i, j, d)
			if h.x == RelevoEmBlocos.SEM:
				continue
			var cat := categoria(h.y - h.x)
			if int(resumo.get(ilha + "|" + cat, 0)) >= POR_CATEGORIA:
				continue
			resumo[ilha + "|" + cat] = int(resumo.get(ilha + "|" + cat, 0)) + 1
			feitas[feitas.size()] = true
			await _atravessar(r, i, j, d, h, cat, acima)
	print("\n%d/%d" % [total - falhas, total])
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)


func _chao_sob(pos: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 5.0)
	q.exclude = [p.get_rid()]
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3).y if not h.is_empty() else pos.y


func _atravessar(r: RelevoEmBlocos, i: int, j: int, d: Vector2i, h: Vector2i, cat: String, acima: float) -> void:
	var dir := Vector3(d.x, 0, d.y)
	# Linha da borda no mundo e o ponto de partida 3 meios para trás, no meio da célula.
	var centro := Vector3((r.origem.x + i + 0.5) * M, 0, (r.origem.y + j + 0.5) * M)
	var na_borda := centro + dir * (M * 0.5)
	var de := na_borda - dir * (M * 3.0)
	de.y = h.x * M + acima + 0.05
	tecla(KEY_W, false)
	p.global_position = de
	p.velocity = Vector3.ZERO
	p._yaw = atan2(-dir.x, -dir.z)
	await quadros(12)
	tecla(KEY_W, true)
	var antes := p.global_position
	var parado := 0
	var maior := 0
	var so_chao := true
	var outro := ""
	var chegada := NAN                              # pés (em meios) ao pousar do outro lado
	for q in QUADROS:
		await physics_frame
		var agora := p.global_position
		if q > 8 and Vector2(agora.x - antes.x, agora.z - antes.z).length() < 0.01:
			parado += 1
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				if c.get_normal().y < 0.7:
					so_chao = false
				if not RelevoEmBlocos.e_relevo(c.get_collider()):
					outro = str((c.get_collider() as Node).name) if c.get_collider() is Node else "?"
		else:
			parado = 0
		maior = maxi(maior, parado)
		antes = agora
		# Pousou do outro lado: mede ali e solta o W (o patamar garantido acaba logo).
		# Além do RAIO da cápsula (0,5 m): antes disso ela ainda rola na quina de cima,
		# e o Godot conta esse contato como chão.
		if (agora - na_borda).dot(dir) > 0.55 and p.is_on_floor():
			chegada = (agora.y - acima) / M
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				if c.get_normal().y > 0.7 and not RelevoEmBlocos.e_relevo(c.get_collider()):
					outro = str((c.get_collider() as Node).name) if c.get_collider() is Node else "?"
			break
	tecla(KEY_W, false)
	await quadros(6)
	var fim := p.global_position
	var alem := (fim - na_borda).dot(dir)          # > 0: passou a borda
	var em_cima_de := chegada if not is_nan(chegada) else (fim.y - acima) / M   # pés, em meios
	var esperado := ""
	var passou := false
	if outro != "":
		esperado = "pulado: esbarrou em %s (não é relevo)" % outro
		passou = true
	elif cat == "sobe ≥2":
		passou = alem < 0.0 and absf(em_cima_de - h.x) < 0.3 and not (maior > 0 and so_chao)
		esperado = "parou na parede"
	else:
		passou = alem > 0.55 and absf(em_cima_de - h.y) < 0.3
		esperado = "atravessou"
	total += 1
	falhas += 0 if passou else 1
	print("  %s %-9s (%d,%d)→%s %s: além %.2f m, pés em %.1f meios (de %d para %d), parado %d%s" % [
		"✅" if passou else "❌", cat, i, j, d, esperado, alem, em_cima_de, h.x, h.y, maior,
		" SÓ CHÃO" if maior > 0 and so_chao else ""])
