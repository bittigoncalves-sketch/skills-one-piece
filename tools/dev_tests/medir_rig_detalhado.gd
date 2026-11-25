extends SceneTree
# ============================================================================
#  MEDIR RIG DETALHADO — as três contas que sustentam `src/anim/RigDetalhado.gd`.
#
#  godot --headless --path . -s tools/dev_tests/medir_rig_detalhado.gd
#
#  Não é um teste (não reprova nada): é o instrumento. Todo número escrito nos
#  comentários do `RigDetalhado` e do `ProceduralAnimator` sai daqui, e é para cá
#  que se volta antes de mudar qualquer amplitude.
#
#   1. AMPLITUDE POR JUNTA — quanto cada papel de fato gira no idle/walk/run.
#      Junta com 0,0° é junta que o rig tem e a animação não usa.
#   2. A/B DO PÉ — o desenrolar do pé afunda a sola quanto, em unidades de jogo?
#      Compara com a MESMA cena sem a camada (papéis extras removidos do perfil).
#   3. ASSENTAMENTO — o corpo continua no chão quando anda? (Ver o achado de
#      08/09/2026 sobre a flutuação do `base`.)
# ============================================================================
const DT := 1.0 / 60.0
const CASOS := [["IDLE", Vector3.ZERO, false], ["WALK", Vector3(0, 0, -4.2), false],
	["RUN", Vector3(0, 0, -7.0), true]]

func _init() -> void:
	await process_frame
	_amplitudes()
	_pe_ab()
	_assentamento()
	quit()

# Monta o personagem já normalizado como o jogo faz (1,9775 m -> 1,5 m).
func _montar(cid: String, com_detalhe: bool) -> Dictionary:
	var m := CharacterBuilder.build_character(cid)["node"] as Node3D
	get_root().add_child(m)
	var caixa := PlayerModelKit.model_aabb(m)
	var ky: float = PlayerRig.CHAR_TARGET_H / caixa.size.y
	m.scale = Vector3(ky, ky, ky)
	m.position.y = PlayerRig.FEET_Y - ky * caixa.position.y
	await process_frame
	var prof := BodyScanner.scan(m)
	if not com_detalhe:
		for r in prof.nodes.keys():
			if not BodyScanner.ROLES.has(r):
				prof.nodes.erase(r)
				prof.rest.erase(r)
	var anim := ProceduralAnimator.new()
	m.add_child(anim)
	anim.setup(prof)
	return {"modelo": m, "anim": anim, "perfil": prof}

func _rodar(c: Dictionary, caso: Array, quadros: int) -> void:
	for i in quadros:
		(c.anim as ProceduralAnimator).update(caso[1], true, false, DT, 0.0, caso[2])

# --------------------------------------------------------------- 1. amplitude
func _amplitudes() -> void:
	for caso in CASOS:
		var c := await _montar("base", true)
		_rodar(c, caso, 200)
		var mn := {}
		var mx := {}
		var nodes: Dictionary = c.perfil.nodes
		for i in 600:
			(c.anim as ProceduralAnimator).update(caso[1], true, false, DT, 0.0, caso[2])
			for r in nodes:
				var rot: Vector3 = (nodes[r] as Node3D).rotation
				mn[r] = (mn[r] as Vector3).min(rot) if mn.has(r) else rot
				mx[r] = (mx[r] as Vector3).max(rot) if mx.has(r) else rot
		var linhas := []
		for r in nodes:
			var v: Vector3 = (mx[r] as Vector3) - (mn[r] as Vector3)
			linhas.append([maxf(maxf(v.x, v.y), v.z), r, v])
		linhas.sort_custom(func(a, b): return a[0] > b[0])
		print("\n########## AMPLITUDE — %s (%d papéis no perfil)" % [caso[0], nodes.size()])
		var mudas := 0
		for l in linhas:
			if l[0] < deg_to_rad(0.25):
				mudas += 1
				continue
			print("  %-16s x %6.1f°  y %6.1f°  z %6.1f°" % [l[1],
				rad_to_deg(l[2].x), rad_to_deg(l[2].y), rad_to_deg(l[2].z)])
		print("  (%d papéis abaixo de 0,25° — praticamente parados)" % mudas)
		(c.modelo as Node3D).queue_free()
		await process_frame

# ------------------------------------------------------------------ 2. pé A/B
func _pe_ab() -> void:
	for caso in [CASOS[1], CASOS[2]]:
		print("\n########## PÉ A/B — %s (sola do pé de apoio, unidades de jogo)" % caso[0])
		for detalhe in [false, true]:
			var c := await _montar("base", detalhe)
			_rodar(c, caso, 300)
			var m: Node3D = c.modelo
			var pe_r := m.find_child("Foot_R", true, false) as Node3D
			var pe_l := m.find_child("Foot_L", true, false) as Node3D
			var lo := 1e9
			var hi := -1e9
			var lo_ciclo := 1e9
			for i in 400:
				(c.anim as ProceduralAnimator).update(caso[1], true, false, DT, 0.0, caso[2])
				lo_ciclo = minf(lo_ciclo, _min_y(pe_r))
				if pe_r.global_position.y > pe_l.global_position.y:
					continue                       # quem apoia é o esquerdo
				var y := _min_y(pe_r)
				lo = minf(lo, y)
				hi = maxf(hi, y)
			print("  detalhe=%-3s  apoio: mín %.4f máx %.4f (varia %.4f) | ciclo inteiro: mín %.4f"
				% ["SIM" if detalhe else "não", lo, hi, hi - lo, lo_ciclo])
			m.queue_free()
			await process_frame

# ----------------------------------------------------------- 3. assentamento
func _assentamento() -> void:
	for cid in ["base", "buggy"]:
		print("\n########## ASSENTAMENTO — %s (piso da colisão = %.3f)" % [cid, PlayerRig.FEET_Y])
		var c := await _montar(cid, true)
		for caso in CASOS:
			_rodar(c, caso, 200)
			var lo := 1e9
			for i in 300:
				(c.anim as ProceduralAnimator).update(caso[1], true, false, DT, 0.0, caso[2])
				lo = minf(lo, _min_y(c.modelo))
			print("  %-5s ponto mais baixo %+.4f  ->  %+.1f cm em relação ao piso"
				% [caso[0], lo, (lo - PlayerRig.FEET_Y) * 100.0])
		(c.modelo as Node3D).queue_free()
		await process_frame

func _min_y(n: Node) -> float:
	var y := 1e9
	if n is MeshInstance3D:
		var caixa: AABB = (n as MeshInstance3D).get_aabb()
		for i in 8:
			y = minf(y, ((n as MeshInstance3D).global_transform * caixa.get_endpoint(i)).y)
	for f in n.get_children():
		y = minf(y, _min_y(f))
	return y
