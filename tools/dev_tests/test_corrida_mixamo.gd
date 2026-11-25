extends SceneTree
# ============================================================================
#  CORRIDA DO MIXAMO — especificação (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_corrida_mixamo.gd
#
#  Pedido do dono: "tira a animação de correr do Naruto e coloca uma animação da
#  Mixamo". Correndo (4,2 m/s) e no sprint (7 m/s) os clipes `running`/`sprint`
#  tomam o corpo (`ProceduralAnimator._aplicar_corrida`). Mede na POSE QUE SAIU,
#  por geometria (posição dos nós), nunca pelo euler — o euler do clipe passa de ±π:
#    • o clipe está tocando;
#    • braços OPOSTOS às pernas (mão à frente quando o pé do mesmo lado vai atrás);
#    • a mão vai à frente E atrás do ombro (nada de braço travado para trás);
#    • pé de apoio: deslize dentro do orçamento da marcha (45 %);
#    • cadência dentro do teto (4,8 / 7,2 passos/s);
#    • olhar a até 12° do horizonte;
#    • o laço não salta (maior giro de um nó num quadro).
#  `nami` é skinnado (nós intermediários soltos, a hierarquia está no esqueleto):
#  lá só entram os itens que não dependem da posição dos nós.
#  A marcha PROCEDURAL (arrancada lenta, Mink, quem não tem clipe) é medida no
#  `test_walk_run.gd`, com o clipe desligado.
# ============================================================================

const DT := 1.0 / 60.0
const DESLIZE_TETO := 0.45
var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	for cid in ["base", "nami"]:
		for caso in [["CORRIDA", 4.2, false], ["SPRINT", 7.0, true]]:
			var data := CharacterBuilder.build_character(cid)
			var modelo: Node3D = data["node"]
			var skinnado: bool = data.get("skinned", false)
			get_root().add_child(modelo)
			var ab: AABB = PlayerModelKit.skeleton_aabb(modelo) if skinnado else PlayerModelKit.model_aabb(modelo)
			var k: float = 1.5 / ab.size.y
			modelo.scale = Vector3(k, k, k)
			await process_frame
			var prof := BodyScanner.scan(modelo)
			var anim := ProceduralAnimator.new()
			modelo.add_child(anim)
			anim.setup(prof)
			print("\n===== %s / %s =====" % [cid, caso[0]])
			_medir(anim, prof["nodes"], modelo, float(caso[1]), caso[2], skinnado, "%s %s" % [cid, caso[0]])
			modelo.queue_free()
			await process_frame
	print("\nCORRIDA_MIXAMO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _medir(anim, n: Dictionary, modelo: Node3D, v: float, sprint: bool, skinnado: bool, rotulo: String) -> void:
	var vel := Vector3(0, 0, -v)
	for i in 120:
		anim.update(vel, true, false, DT, 0.0, sprint)
	var quadros := 240
	var mao := []
	var pe_mesmo_lado := []
	var pe_apoio_v := []
	var olhar := []
	var giro_max := 0.0
	var giro_onde := ""
	var giro_volta := 0.0
	var antes_q := {}
	var antes_pe := {}
	var u0: float = anim._corrida_u
	var voltas := 0
	var u_antes := u0
	for i in quadros:
		anim.update(vel, true, false, DT, 0.0, sprint)
		if anim._corrida_u < u_antes:
			voltas += 1
		u_antes = anim._corrida_u
		# Salto do laço: maior giro de um nó num quadro.
		for papel in ["Torso", "Head", "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Thigh_L", "Thigh_R", "Shin_L", "Shin_R"]:
			if n.has(papel):
				var q: Quaternion = (n[papel] as Node3D).quaternion
				if antes_q.has(papel):
					var g: float = (antes_q[papel] as Quaternion).angle_to(q)
					if g > giro_max:
						giro_max = g
						giro_onde = "%s em u=%.2f" % [papel, anim._corrida_u]
					if anim._corrida_u < 0.08:
						giro_volta = maxf(giro_volta, g)
				antes_q[papel] = q
		olhar.append(_olhar(n, modelo))
		if skinnado:
			continue
		var m := _local(modelo, n["Hand_L"]) if n.has("Hand_L") else Vector3.ZERO
		var o := _local(modelo, n["UpperArm_L"])
		mao.append(-(m.z - o.z))
		var pl := _local(modelo, n["Foot_L"])
		var pr := _local(modelo, n["Foot_R"])
		pe_mesmo_lado.append(-_local(modelo, n["Shin_L"]).z)   # joelho: acompanha a coxa
		# Amostra (altura, velocidade para trás) de CADA pé; o apoio se decide no fim.
		# "O pé mais baixo" não serve: correndo há fase de VOO, e nela o mais baixo
		# pode ser o que balança para a frente (medido 03/10: 35 % das amostras).
		for lado in ["L", "R"]:
			var pe := pl if lado == "L" else pr
			if antes_pe.has(lado):
				pe_apoio_v.append(Vector2(pe.y, (pe.z - (antes_pe[lado] as Vector3).z) / DT))
		antes_pe = {"L": pl, "R": pr}
	var cadencia: float = 2.0 * (float(voltas) + (u_antes - u0)) / (quadros * DT)
	var teto: float = anim.CADENCIA_MAX_SPRINT if sprint else anim.CADENCIA_MAX_CORRIDA
	var olhar_medio := 0.0
	for x in olhar:
		olhar_medio += x
	olhar_medio = rad_to_deg(olhar_medio / olhar.size())
	_ok("%s: o clipe do Mixamo está tocando (peso %.2f)" % [rotulo, anim._corrida_w], anim._corrida_w > 0.95)
	_ok("%s: cadência %.2f passos/s dentro do teto %.1f" % [rotulo, cadencia, teto], cadencia <= teto + 0.05)
	_ok("%s: olhar a %+.1f° do horizonte (≤ 12°)" % [rotulo, olhar_medio], absf(olhar_medio) <= 12.0)
	print("   maior giro num quadro: %.2f rad (%s); na emenda do laço: %.2f rad" % [giro_max, giro_onde, giro_volta])
	_ok("%s: o laço não salta (giro na emenda %.2f ≤ maior giro fora dela %.2f)" % [rotulo, giro_volta, giro_max], giro_volta <= giro_max + 0.001 and giro_max <= 0.8)
	if skinnado:
		return
	var corr := _corr(mao, pe_mesmo_lado)
	_ok("%s: braço oposto à perna (correlação mão × joelho do mesmo lado %+.2f ≤ −0,3)" % [rotulo, corr], corr <= -0.3)
	_ok("%s: a mão vai à frente E atrás do ombro (%+.2f → %+.2f m)" % [rotulo, mao.min(), mao.max()], mao.max() > 0.08 and mao.min() < 0.03)
	# Apoio = pé a até 3 cm da menor altura que os pés atingem (no chão de fato).
	var y_min := INF
	for a in pe_apoio_v:
		y_min = minf(y_min, a.x)
	var apoio := []
	for a in pe_apoio_v:
		if a.x <= y_min + 0.03:
			apoio.append(a.y)
	apoio.sort()
	var mediana: float = apoio[apoio.size() / 2] if not apoio.is_empty() else 0.0
	var deslize := 1.0 - mediana / v
	_ok("%s: pé de apoio %.2f m/s contra o corpo %.1f → deslize %.0f%% (≤ 45%%)" % [rotulo, mediana, v, deslize * 100.0], absf(deslize) <= DESLIZE_TETO)


## Pitch do olhar em relação à raiz do personagem (rad; − = para baixo).
func _olhar(n: Dictionary, modelo: Node3D) -> float:
	var cabeca: Node3D = n["Head"]
	var tronco: Node3D = n["Torso"]
	var rel: Basis
	if tronco.is_ancestor_of(cabeca):
		rel = modelo.global_basis.orthonormalized().inverse() * cabeca.global_basis.orthonormalized()
	else:
		rel = tronco.basis.orthonormalized() * cabeca.basis.orthonormalized()
	return rel.get_euler().x


## Posição no espaço do modelo, em metros do mundo (frente = −Z).
func _local(modelo: Node3D, no: Node3D) -> Vector3:
	var m := modelo.global_transform
	return (m.affine_inverse() * no.global_position) * m.basis.get_scale().x


func _corr(a: Array, b: Array) -> float:
	var ma := 0.0
	var mb := 0.0
	for i in a.size():
		ma += a[i]
		mb += b[i]
	ma /= a.size()
	mb /= b.size()
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in a.size():
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	return sab / sqrt(maxf(saa * sbb, 1e-12))


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
