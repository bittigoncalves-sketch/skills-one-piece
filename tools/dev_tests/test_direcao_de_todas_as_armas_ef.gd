extends SceneTree
## Direção de ataque de TODAS as armas do Epic Fight (13/11/2026, pedido do dono: "promover o teste de todas as espadas do epic fight para confirmação da direção que atacam e em
## seguida a correção"). Para cada arma × cada golpe da cadeia (3 autos + AUTO_4 quando existe) × câmera em ângulos diferentes, mede NA JANELA DE DANO (fase ATIVO):
##  • `rumo`      — para onde a PONTA aponta (em relação à mira, graus) no MEIO da janela de dano: acima de 75° o corte acontece de lado/atrás;
##  • `cobre`     — o ângulo mais próximo da mira que a ponta atinge na janela: acima de 35° o corte nunca atravessa a frente;
##  • `ponta_max` — o mais à frente que a ponta chega (m): menor que 0,3 = a lâmina nem passa pela frente;
##  • `avanco`    — quanto o corpo andou para a frente da mira (m): menor que −0,05 = recuou.
## O giro do torso é só informado. Argumentos: `desvio=0` (mede SEM a correção de `RumoDosGolpes`), `giro=N` (rad; limite de giro do quadril), `cam=0,135` (ângulos da câmera); o resto são ids de arma.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_direcao_de_todas_as_armas_ef.gd [-- giro=0 cam=0 ef_iron_greatsword ...]
const LIM_RUMO := 75.0
const LIM_COBERTURA := 35.0
const LIM_PONTA_MAX := 0.3
const LIM_AVANCO := -0.05
const DIRECOES := [1, 2, 0, 4]       # PARA_ESQUERDA, PARA_DIREITA, FRENTE e o 4º auto (AUTO_4) — o executor ignora a que a arma não tem

var total := 0
var falhas := 0
var reprovadas: Array[String] = []


func _init() -> void:
	rodar.call_deferred()


func q(n: int) -> void:
	for i in n:
		await physics_frame


func _bearing(v: Vector3, fr: Vector3) -> float:
	# ângulo (graus, 0..180) entre o vetor horizontal `v` e a mira `fr`
	var h := Vector3(v.x, 0, v.z)
	if h.length() < 0.05:
		return 90.0
	return rad_to_deg(h.normalized().angle_to(fr))


## Mesmo ângulo, COM sinal (graus; + = a ponta está à ESQUERDA da mira, − = à direita): é o que a tabela de correção usa.
func _bearing_s(v: Vector3, fr: Vector3) -> float:
	var h := Vector3(v.x, 0, v.z)
	if h.length() < 0.05:
		return 0.0
	return rad_to_deg(fr.signed_angle_to(h.normalized(), Vector3.UP))


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_dir_todas_ef.json"))
	modo.set("progresso_forcado", "user://test_dir_todas_ef.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	var esp = j.get_node("EspadaDaHistoria")
	var anim = j.get("_proc_anim")
	var armas: Array = []
	var cams: Array = [0, 135]
	for a in OS.get_cmdline_user_args():
		if a == "desvio=0":
			Engine.set_meta(&"sem_desvio_de_rumo", true)          # medição BRUTA (sem a correção de `RumoDosGolpes`)
		elif a.begins_with("giro="):
			j.set("giro_maximo_do_quadril_no_golpe", float(a.trim_prefix("giro=")))
		elif a.begins_with("cam="):
			cams = []
			for c in a.trim_prefix("cam=").split(","):
				cams.append(int(c))
		else:
			armas.append(a)
	if armas.is_empty():
		armas = LaminasEpicFight.ids()
	for arma in armas:
		if not LaminasEpicFight.existe(arma):
			continue
		prog.equipar_lamina(arma, true)
		await q(40)
		for dir in DIRECOES:
			if ex.estilo == null or ex.estilo.golpe_para(dir) == null:
				continue
			for graus in cams:
				j.set("_yaw", deg_to_rad(graus))
				j.global_position = Vector3(0, 1, 0)
				j.velocity = Vector3.ZERO
				await q(25)
				var yaw: float = j.get("_yaw")
				var fr := Vector3(-sin(yaw), 0, -cos(yaw))
				var p0: Vector3 = j.global_position
				if not ex.pedir_ataque(dir):
					await q(20)
					continue
				var nome := str(ex.golpe_atual.id) if ex.golpe_atual != null else "?"
				var janela: Array = []                         # rel. da ponta (Vector3) em cada quadro ATIVO
				var giro := 0.0
				for f in 100:
					await q(1)
					if not ex.atacando() and f > 6:
						break
					var pt: Vector3 = esp.ponto(&"EspadaPonta")
					if pt != Vector3.INF and ex.fase() == GolpeDirecional.Fase.ATIVO:
						janela.append(pt - j.global_position)
					var t3: Node3D = anim._n["Torso"]
					var f_t: Vector3 = t3.global_basis * Vector3.BACK
					giro = maxf(giro, absf(rad_to_deg(wrapf(atan2(f_t.x, f_t.z) - atan2(fr.x, fr.z) - PI, -PI, PI))))
				var avanco: float = (j.global_position - p0).dot(fr)
				var rumo := 90.0
				var rumo_s := 0.0
				var cobre := 180.0
				var ponta_max := -99.0
				if not janela.is_empty():
					rumo = _bearing(janela[janela.size() / 2], fr)
					rumo_s = _bearing_s(janela[janela.size() / 2], fr)
					for rel: Vector3 in janela:
						cobre = minf(cobre, _bearing(rel, fr))
						ponta_max = maxf(ponta_max, rel.dot(fr))
				var sem_dado := janela.is_empty()
				var ok_r: bool = rumo <= LIM_RUMO
				var ok_c: bool = cobre <= LIM_COBERTURA
				var ok_m: bool = ponta_max >= LIM_PONTA_MAX
				var ok_a: bool = avanco >= LIM_AVANCO
				var aprovado: bool = ok_r and ok_c and ok_m and ok_a and not sem_dado
				total += 1
				print("%s %-36s cam%4d° rumo=%4.0f° cobre=%4.0f° ponta_max=%5.2f avanço=%5.2f (giro do torso %3.0f°, %d am.) rumo_s=%+.0f" % [
					"✅" if aprovado else "❌", arma + "/" + nome, graus, rumo, cobre, ponta_max, avanco, giro, janela.size(), rumo_s])
				if not aprovado:
					falhas += 1
					var porque := ""
					porque += " sem janela medida" if sem_dado else ""
					porque += " rumo>75°" if not ok_r else ""
					porque += " nunca cruza a frente" if not ok_c else ""
					porque += " ponta<0,3m" if not ok_m else ""
					porque += " recuou" if not ok_a else ""
					reprovadas.append("%s/%s cam%d:%s" % [arma, nome, graus, porque])
				await q(50)
	print("\nDIREÇÃO DAS ARMAS EF: %d golpes medidos, %d reprovados" % [total, falhas])
	for r in reprovadas:
		print("  REPROVADA ", r)
	quit(1 if falhas > 0 else 0)
