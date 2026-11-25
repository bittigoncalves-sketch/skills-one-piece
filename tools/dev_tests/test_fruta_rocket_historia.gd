extends SceneTree
# ============================================================================
#  ROCKET NO MODO HISTÓRIA — fundação (Fase 1 do plano da fruta, 22/09/2026).
#
#  A fruta em si é a do Codex (`src/combat/rocket_controller.gd`, caminho da arena).
#  O que se prova aqui é a CAMADA DA HISTÓRIA por cima dela:
#    1. sem fruta comida, nenhuma técnica sai (Civil continua Civil);
#    2. comer a fruta dá Fruta 1, equipa o corpo e liga só `can_use_fruit`/`can_fly`
#       — `can_use_skills` CONTINUA falso (senão abriria modos 1/2/3, T, E e Corpo de Ferro);
#    3. custo de energia e recarga vêm do PERFIL da história (2 de 10), não do 180 da arena;
#    4. o V da arena não existe na história (a ficha não tem V);
#    5. a fruta comida fica no progresso salvo e volta ao carregar;
#    6. a HUD mostra as técnicas da ficha;
#    7. tirar a fruta desliga tudo de novo;
#    8. o Z da história é o MÍSSIL do vídeo (e não o soco da arena): acerta longe, com o
#       dano da ficha, e a GUARDA do combate direcional segura (30% do dano + postura);
#    9. o F é o VOO (Blast Off): sobe, plana o tempo da ficha, deixa atacar no ar e
#       termina em POUSO SUAVE — acabar o voo não mata de queda;
#   10. o X é o BOMBARDEIO em linha (explode em cadeia e lança o alvo para cima) e o C é o
#       MERGULHO (cruza até o ponto mirado, explode e dá o close curto de câmera).
#   11. cada golpe da história tem POSE PRÓPRIA (rocket_missil/bombardeio/mergulho) e não
#       cai mais na sequência genérica de soco.
#   12. as camadas visuais do vídeo existem de verdade: paleta medida, foguete com malha,
#       retículo antes da explosão, mancha preta no chão e pilar de chamas no C.
#   13. segurar a tecla MOSTRA onde o golpe vai cair (linha no Z, três pontos no X, ponto
#       de queda no C) e soltar apaga; o que se vê é o lugar onde o golpe realmente sai.
#   14. (30/09/2026, pedidos do dono depois de jogar) o F TRANSFORMA o jogador num foguete
#       até o chão e golpe no ar desfaz a forma; o MOUSE pilota o voo em 3D (WASD não);
#       o X solta três explosões ENCOSTADAS a distância fixa; nenhum golpe acende mais o
#       "escapamento" de bocais em cima da cabeça.
#
#  ⚠️ Mapa e progresso FIXOS: o mapa vivo do dono nunca é lido nem gravado.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_fruta_rocket_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_fruta_rocket_historia.json"
const PERFIL := "res://src/historia/frutas/rocket.tres"

var _falhas := 0
var _token := 0


func _init() -> void:
	await process_frame
	print("\n===== ROCKET NO MODO HISTÓRIA =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 900:                          # espera o jogador nascer: 120 quadros fixos não bastam mais (a carga cresceu) e, sem jogador, o script abortava SEM `quit` e o teste travava
		await process_frame
		if i >= 60 and get_first_node_in_group("player") != null:
			break
	for i in 30:
		await process_frame

	var cena := current_scene
	var jogador := _jogador_local()
	_ok(jogador != null, "o Modo História montou o jogador local")
	if jogador == null:
		await _fim(mh)
		return

	_ficha()
	await _sem_fruta(jogador)
	await _comer(cena, jogador)
	_travas(jogador)
	await _custo_e_recarga(jogador)
	await _v_nao_existe(jogador)
	_hud(jogador)
	await _missil(cena, jogador)
	await _voo(cena, jogador)
	await _voo_pilotagem(cena, jogador)
	await _x_e_c(cena, jogador)
	await _bombardeio_encostado(cena, jogador)
	_poses()
	await _camadas_visuais(cena, jogador)
	await _sem_escapamento(cena, jogador)
	await _indicador_de_mira(cena, jogador)
	await _tirar(cena, jogador)
	_progresso_salvo(cena)
	await _fim(mh)


func _fim(mh: GDScript) -> void:
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	# Fechar com som TOCANDO faz o Godot acusar "ObjectDB instances leaked"
	# (AudioStreamWAV + AudioStreamPlaybackWAV): é áudio em curso no encerramento, não
	# vazamento do jogo — e aparecia ou não conforme o último canhão tivesse acabado.
	# Esperar o som (até 3 s) mantém o "log limpo" valendo como parte do PASS.
	for i in 180:
		if not _algum_som_tocando():
			break
		await process_frame
	quit(1 if _falhas > 0 else 0)


func _algum_som_tocando() -> bool:
	for tipo in ["AudioStreamPlayer3D", "AudioStreamPlayer"]:
		for n in get_root().find_children("*", tipo, true, false):
			if n.playing:
				return true
	return false


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _jogador_local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


## Espera a ação em curso acabar. O Z dura 0,44 s: medir antes disso mede o golpe
## anterior, não o que o teste acabou de pedir.
func _esperar_livre(jogador: Node) -> void:
	var rocket: Node = jogador.get("_rocket")
	for i in 180:
		if rocket == null or not rocket.ocupado():
			return
		await physics_frame


# ---------------------------------------------------------------------- 1
func _ficha() -> void:
	print("\n-- 1. a ficha da fruta --")
	var perfil := load(PERFIL) as PerfilDeFrutas
	_ok(perfil != null, "o perfil carrega (%s)" % PERFIL)
	if perfil == null:
		return
	_ok(perfil.problemas().is_empty(), "a ficha está completa (%s)" % ", ".join(perfil.problemas()))
	var teclas: Array = perfil.slots()
	_ok(teclas == ["Z", "X", "C", "F"],
		"as teclas são Z, X, C e F — sem V, como a fruta do vídeo (%s)" % str(teclas))
	# Custos ×10 em 23/10/2026 (energia 100 por nível; era a barra de 10).
	_ok(perfil.custo_de_energia("Z", 180.0) == 20.0 and perfil.recarga("Z", 99.0) == 6.0,
		"o Z custa 20 de energia e recarrega em 6 s")
	_ok(perfil.custo_de_energia("V", 180.0) == 180.0,
		"tecla fora da ficha devolve o padrão da arena (V = %.0f)" % perfil.custo_de_energia("V", 180.0))


# ---------------------------------------------------------------------- 2
func _sem_fruta(jogador: Node) -> void:
	print("\n-- 2. Civil sem fruta não usa técnica --")
	# Desde a A11 (30/10/2026) o Civil nasce com o item "Luta" na mão: o estilo base ocupa o perfil e responde ao Z. "Sem fruta" é MÃOS LIVRES: solta o item antes.
	var prog: ProgressaoDoPersonagem = current_scene.progressao
	if prog.item_em_uso() == "luta":
		prog.ativar_item("luta")
	await _quadros(60)
	_ok(jogador.perfil_de_frutas == null, "nasce sem perfil de fruta")
	_ok(not jogador.capacidades.can_use_fruit and not jogador.capacidades.can_fly,
		"nasce sem `can_use_fruit` e sem `can_fly`")
	var antes: float = jogador.energy
	jogador.begin_charge("Z")
	await _quadros(5)
	_ok(not bool(jogador.get_meta("is_casting", false)) and is_equal_approx(jogador.energy, antes),
		"Z não faz nada e não gasta energia")


# ---------------------------------------------------------------------- 3
func _comer(cena: Node, jogador: Node) -> void:
	print("\n-- 3. comer a Rocket --")
	cena.dar_fruta("rocket")
	await _quadros(10)
	_ok(cena.progressao.fruta == "rocket" and int(cena.progressao.skills["fruta"]) >= 1,
		"o progresso guarda a fruta e sobe a skill Fruta para %d" % int(cena.progressao.skills["fruta"]))
	_ok(jogador.current_fruit_id == "rocket" and jogador.combat_mode == "fruit",
		"o corpo está com a Rocket equipada no modo fruta (%s/%s)" % [jogador.current_fruit_id, jogador.combat_mode])
	_ok(jogador.perfil_de_frutas != null and jogador.perfil_de_frutas.fruta == "rocket",
		"o perfil da história foi instalado no corpo")
	_ok(is_equal_approx(jogador._vida.regen_energia_do_modo, 10.0),
		"a regeneração de energia da história entrou (%.2f/s; a da arena daria 0,05/s)" % jogador._vida.regen_energia_do_modo)


func _travas(jogador: Node) -> void:
	print("\n-- 4. o que a fruta libera (e o que NÃO libera) --")
	_ok(jogador.capacidades.can_use_fruit and jogador.capacidades.can_fly,
		"liberou as técnicas e o voo")
	_ok(not jogador.capacidades.can_use_skills,
		"`can_use_skills` continua falso: modos 1/2/3, T, E e Corpo de Ferro seguem travados")
	_ok(not jogador.capacidades.can_dash and not jogador.capacidades.can_double_jump,
		"dash e pulo duplo continuam travados (são desbloqueios de história)")


# ---------------------------------------------------------------------- 5
func _custo_e_recarga(jogador: Node) -> void:
	print("\n-- 5. custo e recarga saem da ficha da história --")
	# A ficha diz 20 (custo base); o corpo cobra a ficha × `fator_de_custo_fora_do_mod` (cresce com o nível: a barra de energia é de 600+, não de 100) — 20 × fator.
	var fator_custo: float = jogador._fator_de_custo_fora_do_mod()
	_ok(is_equal_approx(jogador.custo_de_energia_do_cast("Z"), 20.0 * fator_custo)
		and is_equal_approx(jogador.recarga_do_cast("Z"), 6.0),
		"o corpo cobra 20 × %.2f = %.1f de energia e 6 s no Z (arena: %.0f)" % [fator_custo, 20.0 * fator_custo, jogador.ENERGY_SKILL])
	# ⚠️ A energia REGENERA entre os quadros medidos: a da história (1/s) devolveria 0,2 em
	# 12 quadros, e mesmo desligada o corpo cai na regra da arena (0,5%/s = 0,05/s). Por isso
	# a medição desliga a da história E compara com folga de 0,05.
	var regen: float = jogador._vida.regen_energia_do_modo
	jogador._vida.regen_energia_do_modo = 0.0
	jogador.energy = jogador.max_energy
	var antes: float = jogador.energy
	# 23/09: segurar MIRA e soltar dispara. Apertar sem soltar não gasta nada — é o
	# soltar que pede o golpe.
	jogador.begin_charge("Z")
	await _quadros(2)
	jogador.release_charge("Z")
	await _quadros(12)
	var gasto := antes - float(jogador.energy)
	_ok(absf(gasto - 20.0 * fator_custo) < 3.0,       # folga de ~3: a energia ainda regenera um pouco nos 12 quadros medidos
		 "um Z gastou 20 × %.2f de energia (gastou %.2f)" % [fator_custo, gasto])
	_ok(float(jogador._fruit_cooldowns.get("Z", 0.0)) > 4.0,
		"o Z entrou em recarga (%.1f s)" % float(jogador._fruit_cooldowns.get("Z", 0.0)))
	await _esperar_livre(jogador)
	jogador.energy = 1.0   # menos que os 2 do Z
	jogador._fruit_cooldowns["Z"] = 0.0
	jogador._server_cast_next_ms.clear()
	await _quadros(2)
	var antes_pobre: float = jogador.energy
	jogador.begin_charge("Z")
	await _quadros(2)
	jogador.release_charge("Z")
	await _quadros(6)
	var rocket_pobre: Node = jogador.get("_rocket")
	_ok(float(jogador.energy) >= antes_pobre - 0.001 and not rocket_pobre.ocupado(),
		"sem energia suficiente o Z não sai: a energia não caiu (%.2f → %.2f)" % [antes_pobre, jogador.energy])
	jogador._vida.regen_energia_do_modo = regen
	jogador.energy = jogador.max_energy


func _v_nao_existe(jogador: Node) -> void:
	print("\n-- 6. a história não tem V --")
	var rocket: Node = jogador.get("_rocket")
	await _esperar_livre(jogador)
	_ok(rocket != null and rocket.slot_permitido("Z") and not rocket.slot_permitido("V"),
		"o controlador aceita Z e recusa V enquanto há perfil da história")
	jogador._fruit_cooldowns.clear()
	jogador._server_cast_next_ms.clear()
	var regen: float = jogador._vida.regen_energia_do_modo
	jogador._vida.regen_energia_do_modo = 0.0
	var antes: float = jogador.energy
	jogador.begin_charge("V")
	_ok(float(jogador.energy) >= antes - 0.001 and not rocket.ocupado(),
		"apertar V não gasta energia nem começa ação (%.2f → %.2f)" % [antes, jogador.energy])
	jogador._vida.regen_energia_do_modo = regen


func _hud(jogador: Node) -> void:
	print("\n-- 7. a HUD das técnicas --")
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	var tecnicas: Control = hud.get_node_or_null("Tecnicas") if hud != null else null
	_ok(tecnicas != null, "a HUD do Modo História tem a barra de técnicas")
	if tecnicas == null:
		return
	tecnicas.atualizar(jogador)
	_ok(tecnicas.visible and tecnicas.slots_na_tela() == ["Z", "X", "C", "F"],
		"mostra as quatro teclas da ficha (%s)" % str(tecnicas.slots_na_tela()))
	_ok(tecnicas.texto_da_linha("Z").begins_with("Missile Fist"),
		"a linha do Z mostra o nome do golpe (\"%s\")" % tecnicas.texto_da_linha("Z"))



## ---------------------------------------------------------------------------
## 13. POSE PRÓPRIA POR GOLPE. `_pose()` do controlador pede "rocket_" + comportamento
## da ficha: rocket_missil, rocket_bombardeio, rocket_mergulho. Até 23/09 essas chaves
## não existiam no amostrador e caíam no padrão GUARDA→RECUO→SOCO→SOCO→GUARDA — os três
## golpes da fruta eram socos. O controle desta seção é a chave inventada: ela TEM que
## cair no padrão, senão o teste não sabe distinguir pose autorada de pose genérica.
## ---------------------------------------------------------------------------
func _poses() -> void:
	print("\n-- 13. pose própria de cada golpe --")
	var P: GDScript = load("res://src/anim/rocket_poses.gd")
	var padrao: Dictionary = P.amostrar("rocket_inventado_pelo_teste", 0.5)
	# t=0,5 cai entre os dois quadros de SOCO: o padrão é o soco puro.
	_ok(is_equal_approx(padrao.UpperArm_R.x, deg_to_rad(92.0)),
			"chave desconhecida cai no soco genérico (UpperArm_R %.0f°)" % rad_to_deg(padrao.UpperArm_R.x))

	for chave in ["rocket_missil", "rocket_bombardeio", "rocket_mergulho"]:
		var dados: Dictionary = P.amostrar(chave, 0.5)
		_ok(dados.size() == P.PAPEIS.size(), "%s devolve os %d papéis do rig" % [chave, P.PAPEIS.size()])
		_ok(dados.UpperArm_R != padrao.UpperArm_R or dados.Torso != padrao.Torso,
				"%s tem pose PRÓPRIA (não é o soco genérico)" % chave)
		var fim: Dictionary = P.amostrar(chave, 1.0)
		_ok(is_equal_approx(fim.Torso.x, deg_to_rad(-4.0)),
				"%s volta à guarda no fim (Torso %.1f°)" % [chave, rad_to_deg(fim.Torso.x)])

	# Z: o foguete fica no braço ERGUIDO até o disparo (0,35 s de 0,60 = t 0,58) e depois
	# vem o coice. Braço erguido = acima do soco horizontal (92°).
	var mira: Dictionary = P.amostrar("rocket_missil", 0.58)
	var coice: Dictionary = P.amostrar("rocket_missil", 0.72)
	_ok(mira.UpperArm_R.x > deg_to_rad(110.0),
			"Z: braço erguido no disparo (%.0f° > 110°)" % rad_to_deg(mira.UpperArm_R.x))
	_ok(mira.Torso.y < deg_to_rad(-20.0),
			"Z: corpo de lado no disparo (torso %.0f°)" % rad_to_deg(mira.Torso.y))
	_ok(coice.Torso.x < mira.Torso.x - deg_to_rad(5.0),
			"Z: coice joga o tronco para trás depois do disparo")

	# X: mãos juntas no peito, simétricas, no aperto (0,65 s de 1,15 = t 0,57).
	var det: Dictionary = P.amostrar("rocket_bombardeio", 0.57)
	_ok(det.ForeArm_R.x > deg_to_rad(90.0) and det.ForeArm_L.x > deg_to_rad(90.0),
			"X: antebraços dobrados no peito (%.0f°)" % rad_to_deg(det.ForeArm_R.x))
	_ok(absf(det.UpperArm_R.z + det.UpperArm_L.z) < 0.001,
			"X: as duas mãos espelhadas (detonador, não soco de um braço só)")

	# C: mergulha de cabeça no ar e aterrissa agachado no impacto (0,52 s de 1,40 = t 0,37).
	var voo: Dictionary = P.amostrar("rocket_mergulho", 0.30)
	var chao: Dictionary = P.amostrar("rocket_mergulho", 0.37)
	_ok(voo.Torso.x > deg_to_rad(20.0) and voo.Head.x < 0.0,
			"C: mergulha de cabeça (tronco %.0f°, cabeça %.0f°)" % [rad_to_deg(voo.Torso.x), rad_to_deg(voo.Head.x)])
	_ok(chao.Thigh_R.x > deg_to_rad(50.0) and chao.Shin_R.x < deg_to_rad(-80.0),
			"C: aterrissa agachado no instante do impacto (coxa %.0f°, canela %.0f°)"
					% [rad_to_deg(chao.Thigh_R.x), rad_to_deg(chao.Shin_R.x)])


## ---------------------------------------------------------------------------
## 14. AS CAMADAS VISUAIS DO VÍDEO. Até 23/09 o efeito inteiro era duas cores, uma esfera
## com um toro e um rastro: o aviso do X era a mesma explosão genérica, o C não tinha
## pilar, o Z não tinha foguete e o chão não guardava nada. Aqui se prova o que EXISTE
## desenhado, não se julga se está bonito — isso é captura e olho do dono.
## ---------------------------------------------------------------------------
func _camadas_visuais(cena: Node, jogador: Node) -> void:
	print("\n-- 14. as camadas visuais do vídeo --")
	var V: GDScript = load("res://src/effects/rocket_vfx.gd")
	var mapa: Dictionary = V.get_script_constant_map()
	# As oito cores medidas com ffmpeg nos quadros de explosão (docs/frutas/rocket.md).
	var medidas := {"PRETO": "#050102", "FUMACA": "#2c0b0b", "VERMELHO": "#911f1c",
		"BRASA": "#e34030", "FOGO": "#f2a148", "AMARELO": "#fcd13c",
		"CLARAO": "#f6f25a", "CREME": "#ede3c8"}
	var fora: Array = []
	for nome in medidas:
		var c: Color = mapa.get(nome, Color.MAGENTA)
		if not _mesma_cor(c, Color.html(medidas[nome])):
			fora.append(nome)
	_ok(fora.is_empty(), "as 8 cores são as MEDIDAS no vídeo (divergem: %s)" % str(fora))
	_ok(not _mesma_cor(mapa.get("BRASA", Color.MAGENTA), Color.html("#00ff00")),
			"controle: a checagem de cor sabe reprovar")

	await _esperar_livre(jogador)
	for i in 90:
		await _quadros(1)
		if jogador.is_on_floor():
			break

	# Z: o foguete é um OBJETO que cruza o cenário, e não desenha retículo nenhum.
	var z: Dictionary = await _observar_fx(jogador, "Z", Vector3.FORWARD, 60)
	_ok(z.missil, "Z: o foguete aparece com malha própria e voa")
	_ok(z.reticulo == 0, "controle: o Z não desenha retículo (só o X avisa o chão)")
	await _esperar_livre(jogador)
	await _quadros(70)

	# X: retículo ANTES, mancha DEPOIS — a ordem é o que faz o aviso valer.
	var x: Dictionary = await _observar_fx(jogador, "X", Vector3.FORWARD, 150)
	_ok(x.reticulo >= 1, "X: retículo no chão antes da explosão (%d ao mesmo tempo)" % x.reticulo)
	_ok(x.mancha >= 1, "X: a explosão deixa mancha preta no chão (%d)" % x.mancha)
	_ok(x.q_reticulo >= 0 and (x.q_mancha < 0 or x.q_reticulo < x.q_mancha),
			"X: o aviso vem ANTES do estrago (retículo no quadro %d, mancha no %d)"
					% [x.q_reticulo, x.q_mancha])
	await _esperar_livre(jogador)
	await _quadros(70)

	# C: pilar vertical de chamas no impacto.
	var c_obs: Dictionary = await _observar_fx(jogador, "C", Vector3.FORWARD, 200)
	_ok(c_obs.pilar, "C: o impacto sobe o pilar de chamas")
	await _esperar_livre(jogador)


func _mesma_cor(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Dispara e OLHA o efeito quadro a quadro: o que ficou visível, e em que quadro apareceu.
func _observar_fx(jogador: Node, slot: String, direcao: Vector3, quadros: int) -> Dictionary:
	var obs := {"reticulo": 0, "mancha": 0, "pilar": false, "missil": false,
		"q_reticulo": -1, "q_mancha": -1}
	var rocket: Node = jogador.get("_rocket")
	_disparar(jogador, slot, direcao.normalized())
	for i in quadros:
		await _quadros(1)
		var fx: Node = rocket.get("_fx")
		if not is_instance_valid(fx):
			continue
		var vis_r := 0
		for item in fx.get("_reticulos"):
			if item.raiz.visible:
				vis_r += 1
		if vis_r > 0 and obs.q_reticulo < 0:
			obs.q_reticulo = i
		obs.reticulo = maxi(obs.reticulo, vis_r)
		var vis_m := 0
		for item in fx.get("_manchas"):
			if item.no.visible:
				vis_m += 1
		if vis_m > 0 and obs.q_mancha < 0:
			obs.q_mancha = i
		obs.mancha = maxi(obs.mancha, vis_m)
		var pil: Node3D = fx.get("_pilar")
		if is_instance_valid(pil) and pil.visible:
			obs.pilar = true
		var mis: Node3D = fx.get("_missil")
		if is_instance_valid(mis) and mis.visible:
			obs.missil = true
	return obs


## ---------------------------------------------------------------------------
## 15. O INDICADOR DE MIRA. Decisão do dono: segurar mostra, soltar apaga. O que importa
## provar não é que apareceu um anel — é que o anel está ONDE O GOLPE CAI: a mira e o
## controlador usam a mesma conta (`MiraDeRocket`). Origem errada (a de `mira_do_cast`,
## 1,5 m à frente do corpo) põe o anel mais de um metro fora do buraco.
## ---------------------------------------------------------------------------
func _indicador_de_mira(cena: Node, jogador: Node) -> void:
	print("\n-- 15. o indicador de mira --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	await _esperar_livre(jogador)
	for i in 90:
		await _quadros(1)
		if jogador.is_on_floor():
			break

	jogador._skill_cooldowns.clear()
	jogador._fruit_cooldowns.clear()
	jogador.begin_charge("Z")
	await _quadros(2)
	var mira: Node = jogador.get("_mira_fruta")
	_ok(is_instance_valid(mira) and mira.visible and mira.mostrando() == "Z",
			"segurar Z mostra o indicador")
	_ok(is_instance_valid(mira) and mira.get("_linha").visible,
			"Z: desenha a LINHA do tiro")
	jogador.release_charge("Z")
	await _quadros(2)
	_ok(not mira.visible and mira.mostrando() == "",
			"soltar Z apaga o indicador")

	await _esperar_livre(jogador)
	jogador._skill_cooldowns.clear()
	jogador._fruit_cooldowns.clear()
	jogador.begin_charge("X")
	await _quadros(2)
	var aneis := 0
	for m in mira.get("_aneis"):
		if m.visible:
			aneis += 1
	_ok(aneis == 3, "X: mostra os TRÊS pontos do bombardeio (%d)" % aneis)
	jogador.release_charge("X")
	await _quadros(2)

	# O F não tem alvo no chão: o controle que mostra que a seção sabe reprovar.
	await _esperar_livre(jogador)
	jogador.begin_charge("F")
	await _quadros(2)
	_ok(not mira.visible, "controle: o F (voo) não desenha alvo nenhum")
	jogador.release_charge("F")
	await _quadros(2)
	if jogador.voando():
		# O voo inteiro leva ~5 s desde 30/09/2026 (arco na virada + pouso por retrofoguete);
		# com 4 s de espera a fruta era tirada NO AR e o teste fechava com o som do puff
		# tocando ("ObjectDB instances leaked": AudioStreamPlaybackWAV).
		for i in 480:
			await _quadros(1)
			if not jogador.voando():
				break
	await _esperar_livre(jogador)
	for i in 120:
		await _quadros(1)
		if jogador.is_on_floor():
			break

	# C: o anel mostrado ENQUANTO SE MIRA tem que ser onde o corpo vai aterrissar. A
	# captura vem ANTES do pedido, de propósito: depois do pedido os dois leem a direção
	# travada no controlador e a comparação não provaria nada. Assim, mira e golpe partem
	# de contas independentes — foi com esta checagem que a origem errada apareceu.
	var de_onde: Vector3 = jogador.global_position
	var rocket: Node = jogador.get("_rocket")
	jogador._skill_cooldowns.clear()
	jogador._fruit_cooldowns.clear()
	jogador.begin_charge("C")
	var anel_em := Vector3.INF
	for i in 6:
		await _quadros(1)
		if mira.visible:
			for m in mira.get("_aneis"):
				if m.visible:
					anel_em = m.global_position
					break
		if anel_em != Vector3.INF:
			break
	if not rocket.ocupado():
		_disparar(jogador, "C", jogador.mira_do_cast().aim)
	for i in 200:
		await _quadros(1)
		if not rocket.ocupado() and jogador.global_position.distance_to(de_onde) > 3.0:
			break
	jogador.release_charge("C")
	_ok(anel_em != Vector3.INF, "C: mostra o ponto de queda")
	if anel_em != Vector3.INF:
		var caiu := Vector2(jogador.global_position.x, jogador.global_position.z)
		var anel := Vector2(anel_em.x, anel_em.z)
		_ok(caiu.distance_to(anel) < 0.6,
				"C: o corpo caiu ONDE o anel mostrou (%.2f m de diferença)" % caiu.distance_to(anel))
	await _esperar_livre(jogador)

# ---------------------------------------------------------------------- 8
func _tirar(cena: Node, jogador: Node) -> void:
	print("\n-- 8. tirar a fruta desliga tudo --")
	cena.tirar_fruta()
	await _quadros(10)
	# Tirar a fruta devolve o Civil ao estado de ORIGEM: desde a A11 (30/10/2026) é o Estilo de Combate Base (item "Luta"), não "sem perfil": o que importa é que NADA da Rocket sobrou.
	_ok(jogador.perfil_de_frutas != null and jogador.perfil_de_frutas.fruta == "estilo_de_combate_base" and jogador.current_fruit_id == "estilo_de_combate_base",
		"o corpo volta ao estilo base e a Rocket sai do perfil (%s)" % jogador.current_fruit_id)
	_ok(not jogador.capacidades.can_fly, "o voo da Rocket sai (can_fly volta a falso)")
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	var tecnicas: Control = hud.get_node_or_null("Tecnicas") if hud != null else null
	if tecnicas != null:
		tecnicas.atualizar(jogador)
		_ok(not tecnicas.visible, "a barra de técnicas some")


func _progresso_salvo(cena: Node) -> void:
	print("\n-- 9. a fruta atravessa o salvamento --")
	cena.progressao.comer_fruta("rocket")
	var erro: int = cena.progressao.salvar(cena.caminho_do_progresso())
	_ok(erro == OK, "o progresso gravou (%s)" % error_string(erro))
	var lido: ProgressaoDoPersonagem = ProgressaoDoPersonagem.carregar(cena.caminho_do_progresso())
	_ok(lido.fruta == "rocket" and lido.tem_fruta(), "ao carregar, a fruta volta (%s)" % lido.fruta)
	var sujo := ProgressaoDoPersonagem.de_dict({"formato": ProgressaoDoPersonagem.FORMATO, "fruta": "fruta_inventada"})
	_ok(sujo.fruta == "", "controle: fruta que não existe no jogo é recusada no carregamento")


# ---------------------------------------------------------------------- 10
## Dispara pelo caminho do SERVIDOR (o mesmo do `test_rocket`), com direção explícita.
func _disparar(jogador: Node, slot: String, direcao: Vector3) -> void:
	jogador._fruit_cooldowns.clear()
	jogador._server_cast_next_ms.clear()
	jogador.energy = jogador.max_energy
	# Identidade CRESCENTE, continuando de onde o controlador parou: ele recusa token menor
	# ou igual ao último aceito (anti-repetição), e os pedidos anteriores deste teste (pelo
	# `begin_charge`) já gravaram um número alto lá.
	var rocket_do_corpo: Node = jogador.get("_rocket")
	_token = maxi(_token, int(rocket_do_corpo._ultimo_token)) + 1
	jogador._do_server_cast(slot, direcao.normalized(),
		jogador.global_position + Vector3.UP, 0.0, _token, "fruit", "rocket")


## Uma laje sólida grande sob `centro`, para o teste não depender da física do mapa.
func _piso_de_teste(cena: Node, centro: Vector3) -> void:
	var piso := StaticBody3D.new()
	piso.name = "PisoDeTeste"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(80, 1, 80)
	forma.shape = caixa
	piso.add_child(forma)
	cena.add_child(piso)
	piso.global_position = centro + Vector3.DOWN * 1.4


## Direção do tiro: do ponto de saída do foguete (altura do braço) até o centro do alvo.
## Mirar só "para frente" no plano faz o míssil passar por cima — ele sai a 1,25 m.
func _mira_no_alvo(jogador: Node, alvo: Node3D) -> Vector3:
	var de: Vector3 = jogador.global_position + Vector3.UP * 1.25
	return (alvo.global_position - de).normalized()


func _missil(cena: Node, jogador: Node) -> void:
	print("\n-- 10. o Z da história é o míssil do vídeo --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	var ficha: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("Z")
	var rocket: Node = jogador.get("_rocket")
	# ⚠️ CHÃO DE TESTE, como o `test_rocket` faz: nesta cena o jogador não fica parado no
	# chão do mapa, e um alvo a 12 m some da linha de tiro em meio segundo de queda. Com o
	# piso sólido os dois ficam onde o teste os coloca.
	_piso_de_teste(cena, jogador.global_position)
	var y_antes: float = jogador.global_position.y
	var parado := 0
	for i in 120:
		await _quadros(1)
		var y: float = jogador.global_position.y
		parado = parado + 1 if absf(y - y_antes) < 0.005 else 0
		y_antes = y
		if parado >= 10:
			break
	_ok(parado >= 10, "(pré-condição) o jogador parou de cair no chão de teste (y=%.2f, no_chao=%s)"
		% [jogador.global_position.y, jogador.is_on_floor()])
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.name = "AlvoRocket"
	boneco.vida_maxima = 100000.0
	# ⚠️ POSIÇÃO ANTES DE ENTRAR NA ÁRVORE. Nascer na origem, em cima do jogador, faz o
	# corpo virar PLATAFORMA: medido aqui em 22/09 — o jogador subiu 0,8 m no primeiro
	# quadro e foi CARREGADO 12 m no segundo, junto com o alvo (docs/erros.md, 16/09).
	boneco.position = cena.to_local(jogador.global_position + Vector3.FORWARD * 12.0)
	cena.add_child(boneco)
	# Física desligada (como o `test_rocket` faz com o alvo dele): sem isso ele cai, e em
	# meio segundo já está fora da linha do míssil. O executor (guarda) é filho e continua.
	boneco.set_physics_process(false)
	await _quadros(10)

	# A. longe, sem guarda: o dano da ficha chega aos 12 m (o soco da arena alcança 2,8 m).
	var vida: float = boneco.health
	var t0 := Time.get_ticks_msec()
	_ok(absf(jogador.global_position.y - boneco.global_position.y) < 0.2,
		"(pré-condição) alvo na mesma altura do jogador (jogador %s, alvo %s)"
			% [jogador.global_position, boneco.global_position])
	_disparar(jogador, "Z", _mira_no_alvo(jogador, boneco))
	for i in 120:
		await _quadros(1)
		if boneco.health < vida:
			break
	var levou := vida - float(boneco.health)
	var atraso := (Time.get_ticks_msec() - t0) / 1000.0
	# Técnicas da história +50 % (23/10/2026, `Balance.HISTORIA_TECNICAS`) sobre a ficha.
	_ok(is_equal_approx(levou, ficha.dano * Balance.HISTORIA_TECNICAS), "acertou a 12 m com o dano da ficha × 1,5 (%.0f de %.0f)" % [levou, ficha.dano * Balance.HISTORIA_TECNICAS])
	_ok(atraso < 0.9, "do pedido ao impacto: %.2f s (preparo 0,35 s + voo)" % atraso)
	await _esperar_livre(jogador)

	# B. de guarda: a explosão é segurada — dano reduzido e postura gasta.
	boneco.combate_direcional.erguer_guarda()
	# ⚠️ Com a física do alvo desligada ele NÃO gira sozinho (quem gira é o `_physics_process`
	# dele). Sem virar para o jogador, a explosão chega pelas COSTAS e fica fora do cone da
	# guarda — foi assim que o bloqueio não aconteceu na primeira medição.
	var para_o_jogador: Vector3 = (jogador.global_position - boneco.global_position).normalized()
	var yaw: float = RosaDosVentos.yaw_para(para_o_jogador)
	boneco.encarar_yaw(yaw)
	boneco.modelo_visual().rotation.y = yaw
	for i in 30:
		await _quadros(1)
		if boneco.combate_direcional.em_guarda():
			break
	_ok(boneco.combate_direcional.em_guarda(), "(pré-condição) o boneco está de guarda")
	for i in 300:                          # janela de APARO (0,2 s de jogo) fechada: o executor conta pelo delta de processo, não por quadros de física
		if not boneco.combate_direcional.aparando():
			break
		await _quadros(1)
	var postura_antes: float = boneco.combate_direcional.postura
	vida = boneco.health
	_disparar(jogador, "Z", _mira_no_alvo(jogador, boneco))
	for i in 120:
		await _quadros(1)
		if boneco.health < vida:
			break
	var bloqueado := vida - float(boneco.health)
	# Conta do jogo (`RocketController._nova_spec`): dano da ficha × HISTORIA_TECNICAS, e a guarda deixa passar `dano_bloqueado`. Hoje o bloqueio mede +3,0 sobre isto (13,5 → 16,5):
	# dano extra no bloqueio vindo da reforma da defesa (mesmo domínio de `test_defesa_historia`) — divergência REAL deixada à vista, não escondida.
	var esperado: float = ficha.dano * Balance.HISTORIA_TECNICAS * jogador.perfil_de_frutas.dano_bloqueado
	_ok(absf(bloqueado - esperado) < 0.5,
		"a guarda segurou: passou %.1f de %.0f (%.0f%% da ficha)" % [bloqueado, ficha.dano, jogador.perfil_de_frutas.dano_bloqueado * 100.0])
	_ok(is_equal_approx(postura_antes - boneco.combate_direcional.postura, ficha.dano_de_postura),
		"a postura caiu o da ficha (%.0f)" % (postura_antes - boneco.combate_direcional.postura))
	await _esperar_livre(jogador)

	# C. postura no fim: a guarda QUEBRA e o dano entra inteiro.
	boneco.combate_direcional.postura = 5.0
	vida = boneco.health
	_disparar(jogador, "Z", _mira_no_alvo(jogador, boneco))
	for i in 120:
		await _quadros(1)
		if boneco.health < vida:
			break
	_ok(boneco.combate_direcional.estado == ExecutorCorpoACorpo.Estado.QUEBRA,
		"postura no fim: a guarda quebrou (%s)" % ExecutorCorpoACorpo.Estado.keys()[boneco.combate_direcional.estado])
	_ok(is_equal_approx(vida - float(boneco.health), ficha.dano * Balance.HISTORIA_TECNICAS),
		"na quebra o dano entra inteiro (%.0f)" % (vida - float(boneco.health)))
	boneco.queue_free()
	await _quadros(2)


# ---------------------------------------------------------------------- 11
func _voo(cena: Node, jogador: Node) -> void:
	print("\n-- 11. o F é o voo (Blast Off) e o jogador VIRA o foguete --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	var ficha: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("F")
	jogador._fruit_cooldowns.clear()
	jogador.energy = jogador.max_energy
	await _esperar_livre(jogador)
	await _no_chao(jogador)
	var y0: float = jogador.global_position.y
	var energia: float = jogador.energy
	var regen: float = jogador._vida.regen_energia_do_modo
	jogador._vida.regen_energia_do_modo = 0.0

	_ok(jogador.pedir_voo_de_fruta(), "o F decola")
	_ok(absf((energia - float(jogador.energy)) - ficha.custo_de_energia) < 0.05,
		"custou a energia da ficha (%.1f)" % (energia - float(jogador.energy)))
	_ok(float(jogador._fruit_cooldowns.get("F", 0.0)) > ficha.recarga - 0.5,
		"entrou em recarga (%.1f s)" % float(jogador._fruit_cooldowns.get("F", 0.0)))
	jogador._vida.regen_energia_do_modo = regen

	await _quadros(2)
	var forma: Node3D = jogador.get("_forma_de_foguete")
	_ok(is_instance_valid(forma) and jogador._voo.forma_de_foguete(),
		"decolou e VIROU o foguete")
	_ok(not jogador._char_model.visible, "o corpo some enquanto ele é o foguete")

	# O voo inteiro, sem golpe: sobe, plana o tempo da ficha e pousa como foguete.
	var alto := 0.0
	var t_inicio := Time.get_ticks_msec()
	var nariz := 1.0
	var forma_ate_o_chao := true
	var descidas: Array[float] = []
	for i in 700:
		await _quadros(1)
		alto = maxf(alto, jogador.global_position.y - y0)
		# Depois de 0,3 s de planagem: antes disso o nariz ainda está DEITANDO da subida
		# vertical (a curva suavizada é o arco da decolagem, não desalinhamento).
		if jogador._voo.fase() == "planando" and jogador._voo.tempo() > 0.3 \
				and is_instance_valid(forma) and jogador.velocity.length() > 1.0:
			nariz = minf(nariz, (-forma.global_basis.z).normalized().dot(jogador.velocity.normalized()))
		if not jogador.voando():
			break
		if jogador._voo.fase() == "pousando":
			descidas.append(-jogador.velocity.y)
		if not jogador._voo.forma_de_foguete():
			forma_ate_o_chao = false
	var duracao := (Time.get_ticks_msec() - t_inicio) / 1000.0
	_ok(alto > 4.0, "subiu no impulso (ganhou %.1f m de altura)" % alto)
	_ok(duracao > ficha.duracao and duracao < ficha.duracao + 4.0,
		"o voo durou %.1f s (planagem da ficha: %.1f s + subida e pouso)" % [duracao, ficha.duracao])
	_ok(nariz > 0.9, "o nariz do foguete aponta para onde ele vai (pior alinhamento %.2f)" % nariz)
	_ok(forma_ate_o_chao, "continuou foguete até tocar o chão")
	# Retrofoguete: rápido longe do chão, freando perto dele. Os últimos 0,1 s antes do
	# toque ficam abaixo dos 2 m/s que fazem o `FallImpactController` rachar o chão.
	var final := 0.0
	for v in descidas.slice(maxi(0, descidas.size() - 6)):
		final = maxf(final, v)
	var maior := 0.0
	for v in descidas:
		maior = maxf(maior, v)
	_ok(final < 2.0, "tocou o chão freando (%.1f m/s nos últimos 0,1 s)" % final)
	_ok(maior > 3.0, "controle: longe do chão o retrofoguete desce rápido (%.1f m/s)" % maior)
	await _quadros(3)
	_ok(not is_instance_valid(jogador.get("_forma_de_foguete")) and jogador._char_model.visible,
		"no chão o foguete some e o personagem volta")
	_ok(jogador.is_on_floor() or absf(jogador.velocity.y) < 6.0,
		"terminou pousando devagar (vy %.1f m/s), não em queda livre" % jogador.velocity.y)
	_ok(float(jogador.health) > 0.0, "chegou vivo ao chão (vida %.0f)" % jogador.health)

	# Golpe no ar DESFAZ a forma (decisão do dono, 30/09/2026): o personagem reaparece para
	# dar o golpe e desce pelo pouso suave.
	jogador._fruit_cooldowns.clear()
	jogador.energy = jogador.max_energy
	await _no_chao(jogador)
	y0 = jogador.global_position.y
	_ok(jogador.pedir_voo_de_fruta(), "decola de novo")
	var atacou_no_ar := false
	var desfez := false
	for i in 500:
		await _quadros(1)
		if not atacou_no_ar and jogador.voando() and (jogador.global_position.y - y0) > 3.0:
			jogador._fruit_cooldowns["Z"] = 0.0
			jogador._server_cast_next_ms.clear()
			jogador.energy = jogador.max_energy
			jogador.begin_charge("Z")
			await _quadros(2)
			jogador.release_charge("Z")
			await _quadros(2)
			atacou_no_ar = jogador.get("_rocket").ocupado()
			desfez = not jogador._voo.forma_de_foguete() \
					and not is_instance_valid(jogador.get("_forma_de_foguete")) \
					and jogador._char_model.visible
		if not jogador.voando() and not jogador.get("_rocket").ocupado():
			break
	_ok(atacou_no_ar, "deu para pedir o Z no meio do voo")
	_ok(desfez, "o Z no ar desfez a forma: o personagem reaparece para dar o golpe")
	_ok(float(jogador.health) > 0.0, "e desceu vivo pelo pouso suave (vida %.0f)" % jogador.health)

	# Sem a capacidade não voa: a mesma trava das técnicas.
	var capacidade: bool = jogador.capacidades.can_fly
	jogador.capacidades.can_fly = false
	jogador._fruit_cooldowns.clear()
	_ok(not jogador.pedir_voo_de_fruta(), "sem `can_fly` o F não decola")
	jogador.capacidades.can_fly = capacidade


# ---------------------------------------------------------------------- 12
func _x_e_c(cena: Node, jogador: Node) -> void:
	print("\n-- 12. o X (bombardeio) e o C (mergulho) --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	await _esperar_livre(jogador)
	for i in 90:
		await _quadros(1)
		if jogador.is_on_floor():
			break
	var rocket: Node = jogador.get("_rocket")
	var ficha_x: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("X")
	var ficha_c: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("C")

	# X: alvo a 10 m na linha de tiro — é bombardeio em LINHA, não círculo no alvo.
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.name = "AlvoBombardeio"
	boneco.vida_maxima = 100000.0
	boneco.position = cena.to_local(jogador.global_position + Vector3.FORWARD * 10.0)
	cena.add_child(boneco)
	await _quadros(12)
	var vida: float = boneco.health
	var y_alvo: float = boneco.global_position.y
	_disparar(jogador, "X", Vector3.FORWARD)
	var subiu := 0.0
	for i in 150:
		await _quadros(1)
		subiu = maxf(subiu, boneco.global_position.y - y_alvo)
		if not rocket.ocupado() and boneco.health < vida:
			break
	var levou := vida - float(boneco.health)
	_ok(levou >= ficha_x.dano - 0.5,
		"o bombardeio acertou o alvo na linha (%.0f de dano; %.0f por ponto)" % [levou, ficha_x.dano])
	_ok(subiu > 0.3, "o alvo foi lançado para cima (subiu %.2f m)" % subiu)
	boneco.queue_free()
	await _esperar_livre(jogador)

	# C: mergulho até o ponto mirado, com close de câmera no impacto.
	var alvo2: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	alvo2.name = "AlvoMergulho"
	alvo2.vida_maxima = 100000.0
	alvo2.position = cena.to_local(jogador.global_position + Vector3.FORWARD * 9.0)
	cena.add_child(alvo2)
	await _quadros(12)
	var de_onde: Vector3 = jogador.global_position
	var vida2: float = alvo2.health
	var alto := 0.0
	var close := false
	_disparar(jogador, "C", _mira_no_alvo(jogador, alvo2))
	for i in 200:
		await _quadros(1)
		alto = maxf(alto, jogador.global_position.y - de_onde.y)
		if jogador.get("_camera") != null and jogador._camera.em_close():
			close = true
		if not rocket.ocupado() and alvo2.health < vida2:
			break
	_ok(alto > 2.0, "o mergulho passou pelo alto (subiu %.1f m no arco)" % alto)
	_ok(jogador.global_position.distance_to(de_onde) > 5.0,
		"o corpo cruzou até o ponto mirado (%.1f m)" % jogador.global_position.distance_to(de_onde))
	_ok(is_equal_approx(vida2 - float(alvo2.health), ficha_c.dano * Balance.HISTORIA_TECNICAS),
		"a queda tirou o dano da ficha (%.0f de %.0f)" % [vida2 - float(alvo2.health), ficha_c.dano])
	_ok(close, "a câmera deu o close curto no impacto (exceção aprovada pelo dono)")
	alvo2.queue_free()
	await _quadros(2)


func _no_chao(jogador: Node) -> void:
	for i in 400:
		await _quadros(1)
		if jogador.is_on_floor() and not jogador.voando():
			return


func _tecla(tecla: Key, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	ev.keycode = tecla
	ev.pressed = apertada
	Input.parse_input_event(ev)


## Decola com a câmera no ângulo de descanso e espera o impulso acabar.
func _decolar(jogador: Node) -> Vector3:
	jogador._fruit_cooldowns.clear()
	jogador.energy = jogador.max_energy
	await _no_chao(jogador)
	jogador._pitch = jogador.PITCH_DE_DESCANSO
	jogador.pedir_voo_de_fruta()
	for i in 90:
		await _quadros(1)
		if jogador._voo.fase() != "impulso":
			break
	return jogador._voo.rumo()


# ---------------------------------------------------------------------- 11b
## Pedido do dono (30/09/2026): "o F não está sendo possível a mudança de direção".
## Medido antes: girar a câmera 90° desviava o voo 0°. Decisão: o MOUSE pilota em 3D, com
## curva limitada; o WASD deixa de mexer no rumo.
func _voo_pilotagem(cena: Node, jogador: Node) -> void:
	print("\n-- 11b. o MOUSE pilota o F em 3D (o WASD não) --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	var yaw0: float = jogador._yaw

	# Voo A: mouse parado = nivelado; depois a câmera gira 90°. Mede DEPOIS do arco da
	# virada (`VooFoguete.ARCO`), que ainda sobe de propósito.
	var r0: Vector3 = await _decolar(jogador)
	for i in 40:
		if jogador._voo.tempo() >= VooFoguete.ARCO + 0.05:
			break
		await _quadros(1)
	var y_a: float = jogador.global_position.y
	await _quadros(45)
	var variou: float = jogador.global_position.y - y_a
	_ok(absf(variou) < 0.3, "com o mouse parado o voo é nivelado (variou %.2f m em 0,75 s)" % variou)
	r0 = jogador._voo.rumo()
	jogador._yaw = yaw0 + PI * 0.5
	await _quadros(6)
	var logo: float = rad_to_deg(r0.angle_to(jogador._voo.rumo()))
	await _quadros(54)
	var depois: float = rad_to_deg(r0.angle_to(jogador._voo.rumo()))
	_ok(absf(depois - 90.0) < 3.0, "girar a câmera 90° vira o foguete %.0f°" % depois)
	_ok(logo > 8.0 and logo < 30.0, "vira em ARCO, não na hora: %.0f° no primeiro 0,1 s" % logo)
	var v: Vector3 = jogador.velocity
	var r: Vector3 = jogador._voo.rumo()
	_ok(Vector3(v.x, 0.0, v.z).normalized().dot(Vector3(r.x, 0.0, r.z).normalized()) > 0.95,
		"o corpo vai para onde o foguete aponta")
	jogador._yaw = yaw0
	await _no_chao(jogador)

	# Voo B: o D não vira mais; olhar para cima sobe.
	r0 = await _decolar(jogador)
	_tecla(KEY_D, true)
	await _quadros(40)
	_tecla(KEY_D, false)
	var com_d: float = rad_to_deg(r0.angle_to(jogador._voo.rumo()))
	_ok(com_d < 2.0, "segurar D não vira o foguete (%.1f°)" % com_d)
	var y_b: float = jogador.global_position.y
	jogador._pitch = 0.5
	await _quadros(60)
	var subiu: float = jogador.global_position.y - y_b
	_ok(subiu > 3.0, "olhar para cima faz o foguete subir (%.1f m em 1 s)" % subiu)
	var inclinacao: float = rad_to_deg(asin(clampf(jogador._voo.rumo().y, -1.0, 1.0)))
	_ok(inclinacao <= 60.5, "o nariz para em 60° mesmo com a câmera mais alta (%.0f°)" % inclinacao)
	jogador._pitch = jogador.PITCH_DE_DESCANSO
	await _no_chao(jogador)

	# Voo C: mergulhar até o chão encerra o voo antes do tempo, sem morrer.
	await _decolar(jogador)
	var inicio := Time.get_ticks_msec()
	jogador._pitch = -1.2
	for i in 400:
		await _quadros(1)
		if not jogador.voando():
			break
	var levou := (Time.get_ticks_msec() - inicio) / 1000.0
	jogador._pitch = jogador.PITCH_DE_DESCANSO
	var ficha: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("F")
	_ok(levou < ficha.duracao and jogador.is_on_floor(),
		"mergulhar até o chão encerra o voo (%.1f s de %.1f)" % [levou, ficha.duracao])
	_ok(float(jogador.health) > 0.0, "e o mergulho não mata (vida %.0f)" % jogador.health)
	await _quadros(3)
	_ok(jogador._char_model.visible, "e o personagem volta ao tocar o chão")


# ---------------------------------------------------------------------- 12b
## Pedido do dono (30/09/2026): "espaçamento muito grande entre as áreas de dano do X".
## Medido antes: 3 pontos espalhados pelos 25 m do alcance (8,3 / 16,7 / 25 m) com raio
## de 2 m = 4,3 m de chão sem dano entre um e outro. Decisão: ENCOSTADAS, a distância fixa.
func _bombardeio_encostado(cena: Node, jogador: Node) -> void:
	print("\n-- 12b. o X solta explosões ENCOSTADAS, a distância fixa --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	var ficha: TecnicaDeFruta = jogador.perfil_de_frutas.tecnica("X")
	var raio: float = ficha.raio
	var MIRA: GDScript = load("res://src/combat/mira_de_rocket.gd")
	var d: Array = MIRA.distancias_do_bombardeio(raio, 3)
	var buraco := -INF
	for i in range(1, d.size()):
		buraco = maxf(buraco, float(d[i]) - float(d[i - 1]) - 2.0 * raio)
	_ok(buraco <= 0.0, "vizinhas se sobrepõem (%.1f m), sem chão livre entre elas" % -buraco)
	var borda: float = float(d[0]) - raio
	_ok(borda > 0.2 and borda < 1.0, "a primeira começa logo à frente (borda a %.1f m do corpo)" % borda)
	_ok(25.0 / 3.0 - 2.0 * raio > 0.0,
		"controle: a conta antiga (25 m em 3 pontos) deixava %.1f m de buraco" % (25.0 / 3.0 - 2.0 * raio))

	# No golpe de verdade: a mesma distância mirando reto ou mirando o chão perto.
	var rocket: Node = jogador.get("_rocket")
	var medidas: Array = []
	for mira in [Vector3.FORWARD, Vector3(0.0, -0.5, -1.0).normalized()]:
		await _esperar_livre(jogador)
		await _no_chao(jogador)
		_disparar(jogador, "X", mira)
		for i in 90:
			await _quadros(1)
			if rocket._alvos_do_bombardeio.size() == 3:
				break
		var de: Vector3 = rocket.posicao
		var dist: Array = []
		for p in rocket._alvos_do_bombardeio:
			dist.append(snappedf(Vector2(p.x - de.x, p.z - de.z).length(), 0.01))
		medidas.append(dist)
	var iguais: bool = medidas.size() == 2 and medidas[0].size() == 3 and medidas[1].size() == 3
	if iguais:
		for i in 3:
			iguais = iguais and absf(float(medidas[0][i]) - float(medidas[1][i])) < 0.2 \
					and absf(float(medidas[0][i]) - float(d[i])) < 0.2
	_ok(iguais, "no golpe real as explosões caem a %s m, mirando reto ou para baixo" % str(medidas))
	await _esperar_livre(jogador)


# ---------------------------------------------------------------------- 14b
## Pedido do dono (30/09/2026): "em qualquer ataque está sendo criado acima da cabeça do
## jogador uma espécie de escapamento com fogo". Eram os bocais do `rocket_vfx` (2 bocais,
## fogo, fumaça e luz na altura da cabeça sempre que a fruta estava ocupada). Removidos
## nos dois modos: nenhuma partícula ou luz acende no efeito durante Z, X e C.
func _sem_escapamento(cena: Node, jogador: Node) -> void:
	print("\n-- 14b. nenhum golpe acende escapamento na cabeça --")
	if jogador.perfil_de_frutas == null:
		cena.dar_fruta("rocket")
		await _quadros(10)
	var acesos := 0
	var viu_efeito := false
	for slot in ["Z", "X", "C"]:
		await _esperar_livre(jogador)
		await _no_chao(jogador)
		_disparar(jogador, slot, Vector3.FORWARD)
		for i in 50:
			await _quadros(1)
			for fx in get_nodes_in_group("rocket_vfx"):
				viu_efeito = true
				acesos += _acesos(fx)
	_ok(viu_efeito, "os golpes criaram o efeito da Rocket (a varredura olhou alguma coisa)")
	_ok(acesos == 0, "Z, X e C: nenhuma partícula ou luz de propulsão acesa (%d)" % acesos)

	# Controle: a mesma varredura ENXERGA partícula e luz acesas — na forma de foguete.
	await _esperar_livre(jogador)
	jogador._fruit_cooldowns.clear()
	jogador.energy = jogador.max_energy
	await _no_chao(jogador)
	jogador.pedir_voo_de_fruta()
	await _quadros(10)
	var forma: Node = jogador.get("_forma_de_foguete")
	var na_forma: int = _acesos(forma) if is_instance_valid(forma) else 0
	_ok(na_forma > 0, "controle: a varredura enxerga o que está aceso (forma de foguete: %d)" % na_forma)
	await _no_chao(jogador)


func _acesos(raiz: Node) -> int:
	var n := 0
	for filho in raiz.find_children("*", "GPUParticles3D", true, false):
		if filho.emitting and filho.is_visible_in_tree():
			n += 1
	for filho in raiz.find_children("*", "OmniLight3D", true, false):
		if filho.is_visible_in_tree() and filho.light_energy > 0.0:
			n += 1
	return n
