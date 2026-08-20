extends SceneTree
## ============================================================================
##  AS ANIMAÇÕES AUTORAIS DA GURA GURA — elas acontecem no rig?
##
##  O PEDIDO DO DONO (2026-08-15): "criar animações personalizadas para os
##  poderes da gura gura no mi baseado no barba branca de one piece, a única
##  animação obrigatória será a pose de T especificamente na skill V socando o
##  ar e criando rachaduras com os tremores no ar invocando ondas".
##
##  "Pose de T" e "socando" são adjetivos, e adjetivo não fecha tarefa. Aqui os
##  dois viram NÚMERO, e o número é GEOMÉTRICO — a posição real do punho depois
##  do filtro de rigidez, não o Euler que a pose escreveu. Dois eulers diferentes
##  dão o mesmo braço, e o euler sozinho já enganou este projeto antes (é a
##  mesma disciplina do `medir_gura_rush.gd`, e o aviso de anisotropia dele vale
##  igual aqui: mede-se NO ESPAÇO DO MODELO, nunca no mundo).
##
##  O QUE CADA COLUNA QUER DIZER
##    ELEV — ângulo do braço com o chão: 0° pendurado, 90° horizontal (o T).
##    FORA — quanto o punho abriu PARA O LADO, em fração do alcance do braço.
##           É esta que separa o T de um soco à frente: os dois têm ELEV ~90°.
##    FRENTE — quanto o punho foi À FRENTE. No T tem que ser ~0.
##
##  O VEREDITO DO V TEM TRÊS PARTES, e as três são obrigatórias:
##    1. O T EXISTE       — braços horizontais, abertos e simétricos ao assentar.
##    2. O SOCO SOCA      — o punho PASSA do T e volta. Sem essa ultrapassagem a
##                          leitura é "levantou os braços", que é exatamente o
##                          defeito que esta tarefa veio consertar.
##    3. TEM RECUO        — antes de sair, o punho recolhe. É o primeiro tempo de
##                          um soco; sem ele o golpe lê como empurrão.
##
##  Uso:
##    godot --headless --path . --script tools/dev_tests/test_gura_animacoes.gd
## ============================================================================

const QUADROS := 110          # ~1,8 s a 60 Hz: cobre a linha do tempo inteira do V
var _player: Node = null

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	_player = _local()
	if _player == null:
		print("❌ não achei o jogador — a cena não subiu")
		quit(1)
		return
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9

	_player.equip_fruit("gura_gura")
	await _esperar(0.6)

	print("")
	print("╔══════════════════════════════════════════════════════════════════╗")
	print("║  GURA GURA — AS ANIMAÇÕES AUTORAIS DOS QUATRO GOLPES             ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	var falhas := 0
	falhas += await _auditar_v()
	for slot in ["Z", "X", "C"]:
		falhas += await _auditar_golpe(slot)

	print("")
	if falhas == 0:
		print("✅ TUDO DE PÉ — a pose de T obrigatória e os três golpes se movem.")
	else:
		print("❌ %d verificação(ões) falharam." % falhas)
	quit(1 if falhas > 0 else 0)

# ============================================================================
#  V — A POSE DE T OBRIGATÓRIA
# ============================================================================
func _auditar_v() -> int:
	var amostras := await _conjurar("V")
	if amostras.is_empty():
		print("\n❌ V: não consegui amostrar o corpo.")
		return 1

	print("\n── V — TSUNAMIS DUPLOS (a pose de T socando o ar) ──")

	# A pose de T entra em `GuraVNode.T_SOCO` (0,45 s) e ASSENTA depois do soco.
	# Amostro o fim da janela travada, antes de as ondas soltarem o corpo.
	var assentado := _janela(amostras, 0.78, 0.90)
	var elev_l := _media(assentado, "elev_L")
	var elev_r := _media(assentado, "elev_R")
	var fora_l := _media(assentado, "out_L")
	var fora_r := _media(assentado, "out_R")
	var frente := (absf(_media(assentado, "fwd_L")) + absf(_media(assentado, "fwd_R"))) * 0.5

	print("   T assentado (0,78–0,90 s):")
	print("      braço L: ELEV %6.1f° | FORA %+.2f | FRENTE %+.2f" % [
		elev_l, fora_l, _media(assentado, "fwd_L")])
	print("      braço R: ELEV %6.1f° | FORA %+.2f | FRENTE %+.2f" % [
		elev_r, fora_r, _media(assentado, "fwd_R")])

	var falhas := 0
	# 1) O T EXISTE. Faixa larga de propósito: o número exato depende do porte do
	#    personagem e do filtro de rigidez; o que não pode é o braço estar caído
	#    (ELEV baixo), fechado (FORA baixo) ou socando à frente (FRENTE alto).
	var t_ok: bool = elev_l > 62.0 and elev_l < 118.0 and elev_r > 62.0 and elev_r < 118.0 \
		and fora_l > 0.45 and fora_r > 0.45 and frente < 0.30
	# 2) SIMETRIA — o T tem dois braços iguais. Assimetria aqui é pose de outro
	#    golpe vazando (a meia-T do Z, por exemplo) ou espelhamento errado.
	var simetria: float = absf(fora_l - fora_r)
	var sim_ok: bool = simetria < 0.14 and absf(elev_l - elev_r) < 12.0
	_dizer(t_ok, "os dois braços estão em T (horizontais, abertos, sem socar à frente)")
	_dizer(sim_ok, "o T é simétrico (ΔFORA %.3f, ΔELEV %.1f°)" % [simetria, absf(elev_l - elev_r)])
	falhas += 0 if t_ok else 1
	falhas += 0 if sim_ok else 1

	# 3) O SOCO SOCA — medido em ELEV e em FRENTE, NÃO em FORA.
	#
	# ⚠️ FORA é a métrica ERRADA para a ultrapassagem, e isso custou uma rodada:
	# a 80° o braço já está a 98% da projeção horizontal máxima, então ir de 80°
	# (o T) a 89° (o golpe) mexe FORA em 0,013 — ruído. O mesmo movimento aparece
	# inteiro em ELEV (9°) e no empurrão à FRENTE, que é o que o olho lê como
	# "socando o ar". Métrica saturada esconde movimento real.
	var pico_janela := _janela(amostras, 0.45, 0.80)
	var elev_pico: float = maxf(_maximo(pico_janela, "elev_L"), _maximo(pico_janela, "elev_R"))
	var elev_t: float = (elev_l + elev_r) * 0.5
	var frente_pico: float = maxf(_maximo(pico_janela, "fwd_L"), _maximo(pico_janela, "fwd_R"))
	var t_medio: float = (fora_l + fora_r) * 0.5
	# Passa do T por pelo menos 4° E empurra o punho à frente antes de voltar.
	var soco_ok: bool = elev_pico > elev_t + 4.0 and frente_pico > 0.12
	print("      ELEV no golpe %5.1f°  vs  T assentado %5.1f°  (ultrapassagem %+.1f°)" % [
		elev_pico, elev_t, elev_pico - elev_t])
	print("      punho à FRENTE no golpe %+.3f  (assenta em %+.3f)" % [
		frente_pico, (_media(assentado, "fwd_L") + _media(assentado, "fwd_R")) * 0.5])
	_dizer(soco_ok, "o punho PASSA do T e volta — isso é um soco, não um braço subindo")
	falhas += 0 if soco_ok else 1

	# 4) O RECUO: logo que a pose de T entra (0,45 s) os braços ainda estão
	#    RECOLHIDOS — abaixo de onde vão assentar. É o primeiro tempo do soco.
	var recuo := _janela(amostras, 0.45, 0.52)
	var fora_recuo: float = (_media(recuo, "out_L") + _media(recuo, "out_R")) * 0.5
	var recuo_ok: bool = fora_recuo < t_medio
	print("      abertura no recuo %+.3f  (assenta em %+.3f)" % [fora_recuo, t_medio])
	_dizer(recuo_ok, "há RECUO antes do golpe (o braço volta antes de ir)")
	falhas += 0 if recuo_ok else 1
	return falhas

# ============================================================================
#  Z / X / C — o corpo se MEXE, e se mexe diferente do parado?
# ============================================================================
func _auditar_golpe(slot: String) -> int:
	var amostras := await _conjurar(slot)
	if amostras.is_empty():
		print("\n❌ %s: não consegui amostrar o corpo." % slot)
		return 1
	var nome: String = {"Z": "GURA PUNCH (soco da investida)", "X": "SHOCKWAVE (arremesso)",
		"C": "KABUTSUCHI (de cima para baixo)"}[slot]
	print("\n── %s — %s ──" % [slot, nome])

	# AMPLITUDE = quanto o punho passeou durante o golpe. Uma pose que não chegou
	# ao rig dá amplitude de ruído (~0,0x, só a respiração do idle).
	var amp_r: float = _faixa(amostras, "out_R") + _faixa(amostras, "fwd_R")
	var elev_faixa: float = _faixa(amostras, "elev_R")
	print("   braço R: ELEV variou %5.1f° | passeio do punho %.3f do alcance" % [
		elev_faixa, amp_r])
	# O braço tem que ir a algum lugar. 0,25 do alcance é ~1/4 do braço — bem
	# acima do balanço do idle e abaixo de qualquer golpe de verdade.
	var ok: bool = amp_r > 0.25 and elev_faixa > 20.0
	_dizer(ok, "a animação chega ao rig e move o braço")
	return 0 if ok else 1

# ============================================================================
#  AMOSTRAGEM
# ============================================================================
# Dispara pelo caminho de verdade (`_fire_skill`, o mesmo que a tecla usa) e
# amostra o corpo quadro a quadro, guardando o INSTANTE de cada amostra — os
# vereditos do V perguntam por janelas de tempo, não por número de quadro.
func _conjurar(slot: String) -> Array:
	_player.global_position = Vector3(0, 1.5, 0)
	_player.velocity = Vector3.ZERO
	_player._skill_cooldowns[slot] = 0.0
	_player.set_meta("is_casting", false)
	_player._cast.abortar()
	_player._rapid_fire = false
	_player._movement_locked_timer = 0.0
	_player.energy = _player.max_energy
	_player.remove_meta("custom_pose")
	await _quadros(20)

	var t0 := Time.get_ticks_msec()
	_player._fire_skill(slot, Vector3(0, 0, -1), _player.global_position + Vector3.UP)

	var fora := []
	for i in QUADROS:
		await _quadros(1)
		var a := _amostra()
		if a.is_empty():
			continue
		a["t"] = float(Time.get_ticks_msec() - t0) / 1000.0
		fora.append(a)
	# Devolve o corpo ao normal antes do próximo golpe.
	_player.remove_meta("custom_pose")
	await _quadros(40)
	return fora

# Cinemática direta no ESPAÇO DO MODELO. O `_fit_model_to_body` põe escala
# NÃO-UNIFORME no `_char_model` (o voxel é engrossado 1,85× no Z); medir no mundo
# faria o mesmo braço "mudar de comprimento" conforme a pose, e o ângulo
# escorregaria para a horizontal sozinho. `affine_inverse()` devolve um rig
# rígido, onde FRENTE = −Z e CIMA = +Y.
func _amostra() -> Dictionary:
	var anim = _player.get("_proc_anim")
	var modelo = _player.get("_char_model")
	if anim == null or not (modelo is Node3D):
		return {}
	var n: Dictionary = anim._n
	if not n.has("UpperArm_R") or not n.has("ForeArm_R"):
		return {}
	var inv: Transform3D = (modelo as Node3D).global_transform.affine_inverse()
	var p_torso: Vector3 = inv * (n["Torso"] as Node3D).global_position
	var d := {}
	for lado in ["R", "L"]:
		var ombro := n["UpperArm_" + lado] as Node3D
		var cotovelo := n["ForeArm_" + lado] as Node3D
		var p_o: Vector3 = inv * ombro.global_position
		var p_c: Vector3 = inv * cotovelo.global_position
		var dir_braco: Vector3 = (p_c - p_o).normalized()
		d["elev_" + lado] = rad_to_deg(Vector3.DOWN.angle_to(dir_braco))
		var seg: float = p_o.distance_to(p_c)
		var dir_ante: Vector3 = (inv.basis * cotovelo.global_transform.basis * Vector3(0, -1, 0)).normalized()
		var punho: Vector3 = p_c + dir_ante * seg
		var rel: Vector3 = punho - p_o
		var alcance: float = maxf(2.0 * seg, 0.001)
		# "FORA" é um eixo diferente para cada lado, e ele é MEDIDO, não assumido:
		# é a direção que vai do tronco para o próprio ombro.
		#
		# ⚠️ NÃO copie a constante do `medir_gura_rush.gd` ("o braço direito fica
		# em −X"). Aquele comentário é de ANTES do commit "rig desespelhado"
		# (2026-08-14), que trocou os lados do `base.scn`; usá-lo aqui deu FORA
		# −0,98 num T perfeito e quase me fez "consertar" uma pose correta.
		# Derivar da geometria deixa a sonda imune à próxima vez que o rig virar.
		var eixo_fora: Vector3 = Vector3(p_o.x - p_torso.x, 0.0, 0.0).normalized()
		d["out_" + lado] = rel.dot(eixo_fora) / alcance
		d["fwd_" + lado] = rel.dot(Vector3(0, 0, -1)) / alcance
	return d

# ============================================================================
#  OFICINA
# ============================================================================
func _janela(a: Array, ini: float, fim: float) -> Array:
	var r := []
	for x in a:
		if float(x["t"]) >= ini and float(x["t"]) <= fim:
			r.append(x)
	return r

func _media(a: Array, ch: String) -> float:
	if a.is_empty(): return 0.0
	var s := 0.0
	for x in a: s += float(x[ch])
	return s / a.size()

func _maximo(a: Array, ch: String) -> float:
	var m := -INF
	for x in a: m = maxf(m, float(x[ch]))
	return 0.0 if m == -INF else m

func _minimo(a: Array, ch: String) -> float:
	var m := INF
	for x in a: m = minf(m, float(x[ch]))
	return 0.0 if m == INF else m

func _faixa(a: Array, ch: String) -> float:
	if a.is_empty(): return 0.0
	return _maximo(a, ch) - _minimo(a, ch)

func _dizer(ok: bool, texto: String) -> void:
	print("      %s %s" % ["✔" if ok else "✗", texto])

func _local() -> Node:
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority():
			return x
	return null

func _quadros(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		await physics_frame

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
