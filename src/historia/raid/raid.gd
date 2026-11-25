extends Node
# ============================================================================
#  RAID DO MINE PIECE (18/10/2026, docs/MINE_PIECE_SISTEMAS_PLANO.md, F8).
#
#  Pedido do dono: "o sistema de raid que poderá ser iniciado ao selecionar a bandeira
#  preta e segurar Z"; decisão dele: "como no mod". Porta de `RaidFlagRightclicked`,
#  `RaidGetLevel`, `RaidStartEastBlue`, `RaidEastBlue1..8/20`, `RaidFinish` (mod v14):
#    • o ESTÁGIO é o primeiro do mar ainda não vencido; com os 8 vencidos, o EX (20), repetível;
#    • ondas em volta do jogador, no máximo 5 vivos; o grupo do CHEFE nasce por último;
#    • VENCE quando todos caem (marca o estágio); CANCELA se o jogador morre ou se afasta
#      mais de `DISTANCIA_MAXIMA` do centro. A recompensa é a de cada abate (XP do mod).
#  Inimigos da raid: facção "raid:<mar>" (o cérebro já trata: hostil ao jogador), não
#  renascem; os comuns derrotados têm a escolha recrutar/finalizar, como qualquer humanoide.
#  Grand Line: os personagens dessas raids ainda não foram extraídos do mod — a raid avisa.
#
#  RAID OBRIGATÓRIA (18/11/2026, pedido do dono: "ao invés de o jogador apenas iniciar a raid quando quer, ele terá uma raid obrigatória a cada 10 minutos"):
#    • o relógio `proxima_em` (10 min de jogo) corre sempre que NÃO há raid e o jogador está vivo; avisos aos 60, 30 e 10 s e a contagem fica no topo da tela;
#    • zerou → a raid do estágio do mar onde ele está COMEÇA, queira ou não. Só se ADIA (e avisa o motivo) com o jogador num menu, a nado, de barco ou a bordo
#      de viagem: nascer inimigos no mar não funciona (`_ponto_de_nascer`) e o jogador nem poderia reagir. Adiada = tenta de novo a cada quadro;
#    • o relógio recomeça a CADA fim de raid (vencida, cancelada, jogador caído) e a cada raid iniciada à mão (bandeira + Z): quem acabou de lutar não ganha outra
#      na cara. A raid manual continua existindo ("ao invés de apenas" = além dela).
#    • NÃO vai para o save (abrir o jogo recomeça os 10 min). GATILHO: se virar exploit (fechar o jogo para fugir da raid), gravar `proxima_em` em `sistemas`.
#  Gatilho: extrair os personagens da Grand Line → preencher `ESTAGIOS["grand_line"]`.
# ============================================================================

signal mudou

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const SEGURAR := 1.0
const MAX_VIVOS := 5
const INTERVALO := 0.8
const DISTANCIA_MAXIMA := 120.0
## Raid obrigatória: intervalo (s) e os instantes (s restantes) em que o jogador é avisado.
const INTERVALO_OBRIGATORIA := 600.0
const AVISOS_DA_CONTAGEM := [10, 30, 60]        # do menor para o maior: avisa o MENOR que já vale
const NASCER_ENTRE := Vector2(8.0, 16.0)
## Decisão do dono (15/11/2026): o ATIRADOR nasce mais longe que o espadachim (e atira de mais longe: fuzil até 48 m). Começa onde o anel do
## espadachim termina, para a classe de arma seguir a distância (`ArmaUnica.DISTANCIA_DO_FUZIL`).
const NASCER_ENTRE_ATIRADOR := Vector2(18.0, 34.0)
const PIRATAS := ["mp_pirate_pirate1", "mp_pirate_pirate2", "mp_pirate_pirate3", "mp_pirate_pirate4",
	"mp_pirate_pirate5", "mp_pirate_pirate6", "mp_pirate_pirate7", "mp_pirate_pirate8"]
## Mar → estágio → {total (com os chefes), comuns, chefes (nascem por último), nome}.
const ESTAGIOS := {
	"east_blue": {
		1: {"total": 15, "comuns": ["mp_bandit"], "chefes": ["mp_higuma"], "nome": "Bandidos de Higuma"},
		2: {"total": 15, "comuns": ["mp_pirate_pirate1", "mp_pirate_pirate2", "mp_pirate_pirate3"], "chefes": ["mp_alvida"], "nome": "Piratas da Alvida"},
		3: {"total": 20, "comuns": ["mp_marine"], "chefes": ["mp_helmeppo", "mp_morgan"], "nome": "Marinha 153"},
		4: {"total": 20, "comuns": ["mp_pirate_pirate4", "mp_pirate_pirate5", "mp_pirate_pirate6"], "chefes": ["mp_cabaji", "mp_richie", "mp_buggy"], "nome": "Piratas do Buggy"},
		5: {"total": 30, "comuns": ["mp_pirate_pirate7", "mp_pirate_pirate8"], "chefes": ["mp_sham", "mp_buchi", "mp_jango", "mp_kuro"], "nome": "Piratas do Gato Preto"},
		6: {"total": 80, "comuns": PIRATAS, "chefes": ["mp_gin", "mp_krieg"], "nome": "Piratas do Krieg"},
		7: {"total": 15, "comuns": ["mp_pirate_fishman1", "mp_pirate_fishman2", "mp_pirate_fishman3", "mp_pirate_fishman4"], "chefes": ["mp_chu", "mp_kuroobi", "mp_hatchan", "mp_arlong"], "nome": "Piratas do Arlong"},
		8: {"total": 30, "comuns": ["mp_marine"], "chefes": ["mp_girl_icecream", "mp_alvida_2", "mp_buggy", "mp_tashigi", "mp_smoker"], "nome": "Loguetown"},
		20: {"total": 48, "comuns": PIRATAS, "chefes": ["mp_monster_1", "mp_building_snake", "mp_bonk_punch", "mp_gab", "mp_hongo", "mp_lime_juice", "mp_yasopp", "mp_lucky_roux", "mp_benn_beckman", "mp_shanks"], "nome": "Bando do Ruivo (EX)"},
	},
	"grand_line": {},
}

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var hud: Node
var raiz: Node3D                      # onde os inimigos entram (a raiz do mapa)
var caixas := {}                      # ilhas → Rect2 (DetectorDeIlha)
var ao_derrotar: Callable             # XP e aviso de cada abate (ModoHistoria)

var ativa := false
## Liga/desliga a raid obrigatória (testes e modos sem raid); `proxima_em` = segundos até ela (testes escrevem aqui).
var obrigatoria := true
var proxima_em := INTERVALO_OBRIGATORIA
## Motivo do adiamento em curso ("" = nenhum), para o rótulo e o teste.
var adiada_por := ""
var _ultimo_aviso := 1 << 30
var _vermelho := false
var mar := ""
var estagio := 0
var centro := Vector3.ZERO
var restantes := 0                    # ainda por nascer
var vivos: Array[Node] = []
var _segurando := 0.0
var _relogio := 0.0
var _rng := RandomNumberGenerator.new()
var _painel: CanvasLayer
var _rotulo: Label
## Contagem para a próxima raid (sem raid em curso): à esquerda das barras de fome/sede, longe do contador de ressurreição e da barra de chefe.
var _contagem_rotulo: Label
var _barra: ProgressBar


func _ready() -> void:
	add_to_group("raid_historia")
	_montar_painel()
	var brilho := BrilhoDeRaid.new()      # inimigos da raid atrás de estruturas, fora da visão do jogador, brilham em amarelo
	brilho.name = "BrilhoDeRaid"
	brilho.raid = self
	add_child(brilho)


## Estágios vencidos do mar (no save, `sistemas.raids`).
## ⚠️ INTEIROS: o JSON do save devolve `1.0`, e em Godot `[1.0].has(1)` é falso — a raid achava que nenhum estágio fora vencido ao reabrir o jogo
## (10/11/2026, "o avanço das raids reseta ao fechar o jogo").
func vencidos(m: String) -> Array:
	var saida: Array = []
	if progressao != null:
		for n in (progressao.dados_de("raids").get(m, []) as Array):
			saida.append(int(n))
	return saida


## O estágio que a bandeira chama neste mar: o primeiro não vencido; todos vencidos → 20.
func proximo_estagio(m: String) -> int:
	var tabela: Dictionary = ESTAGIOS.get(m, {})
	for n in [1, 2, 3, 4, 5, 6, 7, 8]:
		if tabela.has(n) and not vencidos(m).has(n):
			return n
	return 20 if tabela.has(20) else 0


## O mar de um ponto: o da ilha em que está, ou o da ilha mais perto (no mar aberto).
func mar_em(p: Vector3) -> String:
	var melhor := ""
	var menor := INF
	for id in caixas:
		var d := Ilhas.distancia(caixas[id], p)
		if d < menor:
			menor = d
			melhor = id
	return Ilhas.mar(melhor)


## Começa a raid onde o jogador está. Devolve "" ou o motivo de não começar.
func iniciar() -> String:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or ativa:
		return "Já há uma raid em andamento." if ativa else ""
	var m := mar_em(j.global_position)
	var n := proximo_estagio(m)
	if n == 0:
		return "Raid da Grand Line: os personagens dela ainda não foram trazidos do Mine Piece."
	var e: Dictionary = ESTAGIOS[m][n]
	ativa = true
	mar = m
	estagio = n
	centro = j.global_position
	restantes = int(e["total"])
	vivos.clear()
	_relogio = 0.0
	proxima_em = INTERVALO_OBRIGATORIA
	adiada_por = ""
	_avisar("RAID · %s · %s — %d inimigos" % [_nome_do_mar(m), str(e["nome"]), restantes])
	_atualizar_painel()
	mudou.emit()
	return ""


func cancelar(motivo: String) -> void:
	if not ativa:
		return
	for v in vivos:
		if is_instance_valid(v):
			v.queue_free()
	vivos.clear()
	ativa = false
	_reiniciar_contagem()
	_avisar("RAID CANCELADA · " + motivo)
	_atualizar_painel()
	mudou.emit()


func _process(delta: float) -> void:
	_entrada(delta)
	if not ativa:
		_contagem(delta)
		return
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or float(j.get("health")) <= 0.0:
		cancelar("você caiu")
		return
	if Vector2(j.global_position.x - centro.x, j.global_position.z - centro.z).length() > DISTANCIA_MAXIMA:
		cancelar("você se afastou demais")
		return
	vivos = vivos.filter(func(v): return is_instance_valid(v) and not v.get_meta("raid_caiu", false))
	_relogio -= delta
	if restantes > 0 and vivos.size() < MAX_VIVOS and _relogio <= 0.0:
		_relogio = INTERVALO
		_nascer(j)
	if restantes == 0 and vivos.is_empty():
		_vencer()
	_atualizar_painel()


func _reiniciar_contagem() -> void:
	proxima_em = INTERVALO_OBRIGATORIA
	adiada_por = ""
	_ultimo_aviso = 1 << 30


## O relógio da raid obrigatória (só sem raid em andamento; jogador vivo).
func _contagem(delta: float) -> void:
	_atualizar_painel()
	if not obrigatoria or progressao == null:
		return
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or float(j.get("health")) <= 0.0:
		return
	if proxima_em > 0.0:
		proxima_em = maxf(proxima_em - delta, 0.0)
		for marca: int in AVISOS_DA_CONTAGEM:
			if proxima_em <= float(marca):
				if marca >= _ultimo_aviso:
					break
				_ultimo_aviso = marca
				_avisar("RAID obrigatória em %d s — prepare-se" % marca)
				break
	if proxima_em > 0.0:
		return
	var motivo := motivo_de_adiar(j)
	if not motivo.is_empty():
		if motivo != adiada_por:
			_avisar("RAID adiada: " + motivo)
		adiada_por = motivo
		return
	var recusa := iniciar()
	if not recusa.is_empty():                       # Grand Line sem personagens: avisa e tenta daqui a 10 min
		_avisar(recusa)
		_reiniciar_contagem()
	elif ativa:
		_avisar("RAID OBRIGATÓRIA!")


## Por que a raid obrigatória não pode começar agora ("" = pode): menu aberto, a nado, de barco ou numa viagem.
func motivo_de_adiar(j: Node3D) -> String:
	if hud != null and hud.has_method("is_menu_open") and hud.is_menu_open():
		return "menu aberto"
	var nav := get_tree().get_first_node_in_group("navegacao_historia")
	if nav != null and (bool(nav.get("viagem_ativa")) or nav.get("barco") != null):
		return "você está num barco"
	var agua := AguaDoMundo.nivel_em(j.global_position.x, j.global_position.z)
	if not is_nan(agua) and j.global_position.y < agua - 0.3:
		return "você está na água"
	return ""


## "09:41" (o que o rótulo e os testes leem).
func contagem_em_texto() -> String:
	var t := ceili(proxima_em)
	return "%02d:%02d" % [t / 60, t % 60]


## Bandeira na mão + Z segurado por `SEGURAR` segundos.
func _entrada(delta: float) -> void:
	var pronto: bool = not ativa and progressao != null and progressao.item_em_uso() == "bandeira" \
		and Input.is_physical_key_pressed(KEY_Z) and not (hud != null and hud.has_method("is_menu_open") and hud.is_menu_open())
	_segurando = _segurando + delta if pronto else 0.0
	_barra.visible = _segurando > 0.0
	_barra.value = clampf(_segurando / SEGURAR, 0.0, 1.0)
	if _segurando >= SEGURAR:
		_segurando = 0.0
		var motivo := iniciar()
		if not motivo.is_empty():
			_avisar(motivo)


func _nascer(j: Node3D) -> void:
	var e: Dictionary = ESTAGIOS[mar][estagio]
	var chefes: Array = e["chefes"]
	# Os últimos a nascer são o grupo do chefe, na ordem (o principal fecha a raid).
	var modelo := str(chefes[chefes.size() - restantes]) if restantes <= chefes.size() \
		else str((e["comuns"] as Array)[_rng.randi() % (e["comuns"] as Array).size()])
	var ficha := DadosEastBlue.ficha_do_modelo(modelo).duplicate(true)
	restantes -= 1
	if ficha.is_empty():
		push_warning("[Raid] sem ficha: " + modelo)
		return
	ficha["faccao"] = "raid:" + mar
	ficha["alcance_de_perseguicao"] = DISTANCIA_MAXIMA
	var p := PersonagemMinePiece.new()
	p.montar(ficha, modelo)
	p.renasce = false
	p.set_meta("raider", true)
	p.name = "Raid_%s_%d" % [modelo, restantes]
	var atirador := TaticaDeMissao.papel_de(ficha, modelo) == TaticaDeMissao.Papel.ATIRADOR
	p.position = _ponto_de_nascer(j, NASCER_ENTRE_ATIRADOR if atirador else NASCER_ENTRE)
	p.rotation.y = _rng.randf() * TAU
	p.ponto_de_origem = centro
	p.yaw_de_origem = p.rotation.y
	raiz.add_child(p)
	# Fuzil E espada na mesma mão não: uma só, o fuzil de preferência (depende da distância de nascimento). Depois do `ao_nascer` do mod,
	# que é quem sorteia as armas; repete mais tarde caso a IA do mod recoloque alguma.
	var d_nascer := p.global_position.distance_to(j.global_position)
	for espera in [0.4, 2.0]:
		get_tree().create_timer(espera).timeout.connect(func() -> void:
			if is_instance_valid(p):
				ArmaUnica.aplicar(p, ArmaUnica.preferir_fogo(d_nascer)))
	p.derrotado.connect(func(quem):
		quem.set_meta("raid_caiu", true)
		if ao_derrotar.is_valid():
			ao_derrotar.call(quem))
	vivos.append(p)


## No chão, na faixa `entre` (m) do jogador, fora d'água; senão, perto dele.
func _ponto_de_nascer(j: Node3D, entre := NASCER_ENTRE) -> Vector3:
	var espaco := j.get_world_3d().direct_space_state
	for tentativa in 8:
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(entre.x, entre.y)
		var alto := j.global_position + Vector3(cos(ang) * d, 30.0, sin(ang) * d)
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(alto, alto + Vector3.DOWN * 60.0, 1))
		if hit.is_empty():
			continue
		var y: float = hit["position"].y
		var agua := AguaDoMundo.nivel_em(alto.x, alto.z)
		if not is_nan(agua) and y < agua + 0.2:
			continue
		return hit["position"] + Vector3.UP * 0.05
	return j.global_position + Vector3(2, 0.5, 0)


func _vencer() -> void:
	ativa = false
	var dados := progressao.dados_de("raids")
	var lista: Array = vencidos(mar)
	if not lista.has(estagio):
		lista.append(estagio)
	dados[mar] = lista
	progressao.gravar_dados("raids", dados)
	_reiniciar_contagem()
	_avisar("RAID VENCIDA! · %s" % str(ESTAGIOS[mar][estagio]["nome"]))
	_atualizar_painel()
	mudou.emit()


func _avisar(texto: String) -> void:
	if is_instance_valid(hud) and hud.has_method("avisar"):
		hud.call("avisar", texto)


static func _nome_do_mar(m: String) -> String:
	return {"east_blue": "East Blue", "grand_line": "Grand Line"}.get(m, m)


# ------------------------------------------------------------------ painel
func _montar_painel() -> void:
	_painel = CanvasLayer.new()
	_painel.name = "PainelDaRaid"
	_painel.layer = 40
	add_child(_painel)
	_rotulo = Label.new()
	_rotulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_rotulo.offset_top = 52.0
	_rotulo.offset_left = -260.0
	_rotulo.offset_right = 260.0
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.add_theme_font_size_override("font_size", 18)
	_rotulo.add_theme_color_override("font_color", Color("#ff5a4a"))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	_rotulo.visible = false
	_painel.add_child(_rotulo)
	_contagem_rotulo = Label.new()
	_contagem_rotulo.name = "ContagemDaRaid"
	_contagem_rotulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_contagem_rotulo.offset_left = -640.0
	_contagem_rotulo.offset_right = -(VidaEnergiaHud.LARGURA + VidaEnergiaHud.MARGEM + 12.0)
	_contagem_rotulo.offset_top = 50.0
	_contagem_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_contagem_rotulo.add_theme_font_size_override("font_size", 16)
	_contagem_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_contagem_rotulo.add_theme_constant_override("outline_size", 5)
	_contagem_rotulo.visible = false
	_painel.add_child(_contagem_rotulo)
	_barra = ProgressBar.new()
	_barra.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_barra.offset_top = 60.0
	_barra.offset_bottom = 74.0
	_barra.offset_left = -90.0
	_barra.offset_right = 90.0
	_barra.max_value = 1.0
	_barra.show_percentage = false
	_barra.visible = false
	_painel.add_child(_barra)


func _atualizar_painel() -> void:
	var no_menu: bool = hud != null and hud.has_method("is_menu_open") and hud.is_menu_open()
	if not ativa:
		_rotulo.visible = false
		_contagem_rotulo.visible = obrigatoria and progressao != null and not no_menu
		_contagem_rotulo.text = "Raid adiada: %s" % adiada_por if not adiada_por.is_empty() else "Próxima raid  %s" % contagem_em_texto()
		var urgente := proxima_em <= 60.0
		if urgente != _vermelho or not _contagem_rotulo.has_theme_color_override("font_color"):
			_vermelho = urgente
			_contagem_rotulo.add_theme_color_override("font_color", Color("#ff5a4a") if urgente else Color(1, 1, 1, 0.8))
		return
	_contagem_rotulo.visible = false
	_rotulo.add_theme_color_override("font_color", Color("#ff5a4a"))
	_rotulo.offset_top = 52.0
	_rotulo.visible = true
	_rotulo.text = "RAID · %s %s · %s\nrestam %d" % [_nome_do_mar(mar), "EX" if estagio == 20 else str(estagio),
		str(ESTAGIOS[mar][estagio]["nome"]), restantes + vivos.size()]
