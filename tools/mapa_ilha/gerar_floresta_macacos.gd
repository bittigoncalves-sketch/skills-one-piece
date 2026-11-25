extends SceneTree
# ============================================================================
#  FLORESTA GIGANTE DA ILHA DOS MACACOS (18/11/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_floresta_macacos.gd [-- --saida=<caminho>] [--semente=N]
#
#  Pedido do dono: "criação de uma grande floresta com árvores imensas, macacos humanoides" na Ilha dos Macacos (o plano de 08/10 deixou as árvores gigantes
#  "para depois"). O que grava, SÓ com o prefixo `macacos_floresta_` (rodar de novo troca tudo, sem duplicar; `gerar_ilha_dos_macacos.gd` também as apaga,
#  porque o prefixo dele é `macacos_`):
#    • ÁRVORES IMENSAS: carvalhos, pinheiros, olmos e árvores de parque da loja (`floresta_tree_*`) em escala 7–10 × do tamanho padrão da loja (copas de 40–80 m, 50–80 m de altura; pinheiros de 90–130 m),
#      afastadas pela copa; sobre o solo de mata, fora de trilha, clareira, praia, água e barranco;
#    • SUB-BOSQUE: árvores médias (escala 2,6–4,2 ×), arbustos, cogumelos gigantes (4 ×), pedras e troncos caídos;
#    • MACACOS HUMANOIDES (`mp_macaco_humanoide`, 4 bandos) e o MACACO-REI (o chefe agora é o Gorila-rei, v2): peças `modelo` com
#      comportamento `mine_piece`; no jogo a peça vira o personagem vivo (`PersonagensEastBlue`);
#    • o MESTRE DO GEPPO (`npc_mestre_geppo`) na clareira central, que ensina a técnica Geppo.
#  Mesma proteção do gerador da ilha: cópia do mapa antes, e NÃO grava se o arquivo mudou durante a execução.
#  Os macacos quadrúpedes (área de animais) continuam; os humanoides são ADICIONAIS.
# ============================================================================
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const PREFIXO := "macacos_floresta_"
const GRUPO := "macacos_floresta"
const Layout := preload("res://tools/mapa_ilha/layout_macacos.gd")
const CENTRO := Vector2(1500, 0)
const MEIA := 128.0
const MARGEM_DA_PRAIA := 26.0
const CLAREIRA := Layout.VILA                # a vila plana (v2, 22/11/2026)
const RAIO_DA_CLAREIRA := Layout.VILA_RAIO_LIVRE
const GIGANTES := ["floresta_tree_oak_hero_green", "floresta_tree_pine_hero", "floresta_tree_park_large_green", "floresta_tree_elm_green",
	"floresta_tree_simple_large", "floresta_tree_oak_large_green", "floresta_tree_pine_large"]
const MEDIAS := ["floresta_tree_oak_medium_green", "floresta_tree_birch_large_green", "floresta_tree_spruce_large", "floresta_tree_park_medium_green",
	"floresta_tree_simple_medium", "floresta_tree_pine_medium"]
const ARBUSTOS := ["floresta_bush_large", "floresta_bush_medium", "floresta_bush_with_flowers", "floresta_bush_clumps_large"]
const CHAO := ["floresta_mushroom_brown_large", "floresta_mushroom_red_large", "floresta_rock_06", "floresta_fallen_log", "floresta_grass_large"]
const QUANTIDADE_GIGANTES := 52          # v2: a vila e os sítios planos tiram área da mata; 52 pedidos mantêm ~44 de pé
const QUANTIDADE_MEDIAS := 150
const QUANTIDADE_CHAO := 170
const BANDOS_HUMANOIDES := [Vector2(-86, -66), Vector2(88, -86), Vector2(86, 40), Vector2(-90, 60)]
const MACACOS_POR_BANDO := 4
const SOLO_MATA := 5

var _rng := RandomNumberGenerator.new()
var _bib: BibliotecaDeModelos
var _terrenos: Array[Dictionary] = []
var _obstaculos: Array[Dictionary] = []
var _novas: Array[Dictionary] = []
var _plantadas: Array[Dictionary] = []          # {pos, raio, tipo}
var _contagem := {"gigantes": 0, "medias": 0, "chao": 0, "macacos": 0}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var saida := MAPA
	_rng.seed = 18112026
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		elif a.begins_with("--semente="):
			_rng.seed = int(a.trim_prefix("--semente="))
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	_bib = BibliotecaDeModelos.padrao()
	for id in GIGANTES + MEDIAS + ARBUSTOS + CHAO + ["mp_macaco_humanoide", "npc_mestre_geppo"]:
		if not _bib.tem(id):
			push_error("falta na loja: " + id)
			quit(1)
			return
	var mapa: Dictionary = lido["mapa"]
	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with(PREFIXO):
			trocadas += 1
			continue
		pecas.append(p)
		if p["tipo"] == "terreno":
			_terrenos.append(p)
		elif p["tipo"] == "modelo" and _perto_da_ilha(p["posicao"]):
			_obstaculos.append(p)
	if _terrenos.is_empty():
		push_error("sem relevo no mapa")
		quit(1)
		return
	_mestre()
	_bandos()
	_arvores(GIGANTES, QUANTIDADE_GIGANTES, Vector2(7.0, 10.0), "gigantes", 0.4, 260)
	_arvores(MEDIAS, QUANTIDADE_MEDIAS, Vector2(2.6, 4.2), "medias", 0.5, 120)
	_sub_bosque()
	_plataformas()
	pecas.append_array(_novas)
	var grupos: Array = []
	for g: Dictionary in mapa["grupos"]:
		if g["id"] != GRUPO:
			grupos.append(g)
	grupos.append({"id": GRUPO, "pai": "ilha_dos_macacos"})
	mapa["grupos"] = grupos
	mapa["pecas"] = pecas
	var validado := MapaArquivo.validar(JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"], "pecas": mapa["pecas"], "grupos": mapa["grupos"]})))
	if not validado["ok"]:
		push_error("mapa gerado não valida: %s" % str(validado["erros"]).left(600))
		quit(1)
		return
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_floresta_macacos_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			print("FLORESTA_MACACOS recusado: o mapa mudou durante a execução — mapa NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("FLORESTA_MACACOS %d peças (trocadas %d): %s -> %s (%s)" % [_novas.size(), trocadas, str(_contagem), saida, error_string(err)])
	quit(0 if err == OK else 1)


func _perto_da_ilha(p: Vector3) -> bool:
	return absf(p.x - CENTRO.x) < MEIA + 30.0 and absf(p.z - CENTRO.y) < MEIA + 30.0


func _dentro_da_mata(p: Vector2) -> bool:
	return absf(p.x - CENTRO.x) < MEIA - MARGEM_DA_PRAIA and absf(p.y - CENTRO.y) < MEIA - MARGEM_DA_PRAIA


# --------------------------------------------------------------- árvores
## `quantidade` árvores do `paleta` em escala `faixa`, afastadas pela copa (`fator` do tamanho maior); tenta até `tentativas` posições sorteadas.
func _arvores(paleta: Array, quantidade: int, faixa: Vector2, tipo: String, fator: float, tentativas: int) -> void:
	var feitas := 0
	for t in quantidade * tentativas / 10:
		if feitas >= quantidade:
			break
		var modelo: String = paleta[_rng.randi() % paleta.size()]
		var escala := _rng.randf_range(faixa.x, faixa.y)
		var p := Vector2(CENTRO.x + _rng.randf_range(-MEIA, MEIA), CENTRO.y + _rng.randf_range(-MEIA, MEIA))
		if _plantar(modelo, p, escala, true, tipo, fator):
			feitas += 1
	_contagem[tipo] = feitas


func _sub_bosque() -> void:
	var feitas := 0
	for t in QUANTIDADE_CHAO * 12:
		if feitas >= QUANTIDADE_CHAO:
			break
		var paleta: Array = ARBUSTOS if _rng.randf() < 0.55 else CHAO
		var modelo: String = paleta[_rng.randi() % paleta.size()]
		var escala := _rng.randf_range(1.6, 2.4) if paleta == ARBUSTOS else (_rng.randf_range(3.0, 5.0) if "mushroom" in modelo else _rng.randf_range(1.2, 2.0))
		var p := Vector2(CENTRO.x + _rng.randf_range(-MEIA, MEIA), CENTRO.y + _rng.randf_range(-MEIA, MEIA))
		if _plantar(modelo, p, escala, false, "chao", 1.0):
			feitas += 1
	_contagem["chao"] = feitas


func _plantar(modelo: String, p: Vector2, escala: float, arvore: bool, tipo: String, fator: float) -> bool:
	if not _dentro_da_mata(p):
		return false
	var tam := _bib.tamanho_padrao(modelo) * escala
	var largura := maxf(tam.x, tam.z)
	var raio := largura * (0.5 if not arvore else 0.5)           # a copa
	var tronco := maxf(1.0, largura * 0.07) if arvore else largura * 0.4
	var amostra := _chao_em(p)
	if amostra.is_empty() or int(amostra["solo"]) != SOLO_MATA or bool(amostra["molhado"]):
		return false
	# Sítios planos (Bananal, Curandeiro, Totens, Trono) e estradas ficam limpos.
	for nome in Layout.SITIOS:
		var sitio: Dictionary = Layout.SITIOS[nome]
		if (p - (CENTRO + sitio["centro"])).length() < float(sitio["transicao"]) * 0.8 + (raio * 0.35 if arvore else 0.0):
			return false
	# Clareira e arredores do Mestre ficam limpos.
	if (p - (CENTRO + CLAREIRA)).length() < RAIO_DA_CLAREIRA + (raio * 0.35 if arvore else 0.0):
		return false
	var minimo: float = amostra["altura"]
	var maximo := minimo
	var margem := maxf(2.0, tronco * 1.4)
	for i in 8:
		var c := _chao_em(p + Vector2.from_angle(i * TAU / 8.0) * margem)
		if c.is_empty() or bool(c["molhado"]) or int(c["solo"]) in [2, 3, 6]:
			return false
		minimo = minf(minimo, float(c["altura"]))
		maximo = maxf(maximo, float(c["altura"]))
	if maximo - minimo > (2.2 if arvore else 0.5):
		return false
	for o in _plantadas:
		var d := p.distance_to(o["pos"])
		if arvore and o["tipo"] != "chao":
			if d < (raio + float(o["raio"])) * fator:
				return false
		elif d < (tronco + float(o["tronco"]) + 0.6):
			return false
	for o in _obstaculos:
		var local := (p - Vector2(o["posicao"].x, o["posicao"].z)).rotated(deg_to_rad(o["rotacao_graus"].y))
		if absf(local.x) < o["tamanho"].x * 0.5 + tronco and absf(local.y) < o["tamanho"].z * 0.5 + tronco:
			return false
	_novas.append({"id": PREFIXO + str(_novas.size()), "tipo": "modelo", "modelo": modelo, "grupo": GRUPO,
		"posicao": Vector3(p.x, minimo - 0.06 + tam.y * 0.5, p.y), "tamanho": tam,
		"rotacao_graus": Vector3(0, _rng.randi_range(-180, 179), 0), "cor": Color.WHITE, "material": "liso",
		"colisao": not _bib.atravessavel(modelo)})
	_plantadas.append({"pos": p, "raio": raio, "tronco": tronco, "tipo": tipo})
	return true


# --------------------------------------------------------------- plataformas (Geppo)
const PLATAFORMAS := 8
const PASSO_VERTICAL := 3.4              # m entre plataformas: um pulo no ar do Geppo (~4 m) vence cada degrau
const RAIO_DA_ESPIRAL := 7.5
const ID_DO_BAU_DO_TOPO := "macacos_topo"


## Espiral de plataformas de madeira em volta da árvore imensa mais perto da vila: o treino do Geppo e o caminho do "fruto dourado". A última, maior, leva o baú do topo (`BausDeChefe.garantir_fixo`).
## O jogador sobe pulando no ar (5 por voo; cada plataforma recarrega). Nada disto existe sem as árvores: sem gigante perto, não gera.
func _plataformas() -> void:
	var alvo := {}
	var menor := INF
	for o in _plantadas:
		if o["tipo"] == "gigantes" and float(o["raio"]) > 10.0:
			var d: float = (o["pos"] as Vector2).distance_to(CENTRO + CLAREIRA)
			if d > RAIO_DA_CLAREIRA + 14.0 and d < menor:
				menor = d
				alvo = o
	if alvo.is_empty():
		push_warning("sem árvore imensa para as plataformas")
		return
	var centro: Vector2 = alvo["pos"]
	var chao := _chao_em(centro)
	var base_y: float = chao["altura"]
	var primeiro_angulo := (CENTRO + CLAREIRA - centro).angle()
	var raio := maxf(RAIO_DA_ESPIRAL, float(alvo["tronco"]) + 5.0)
	for i in PLATAFORMAS:
		var ang := primeiro_angulo + i * deg_to_rad(52.0)
		var pos := centro + Vector2.from_angle(ang) * raio
		var topo := i == PLATAFORMAS - 1
		var lado := 8.0 if topo else 5.0
		var y := base_y + 2.4 + i * PASSO_VERTICAL
		_novas.append({"id": PREFIXO + "plataforma_%d" % i, "tipo": "caixa", "grupo": GRUPO,
			"posicao": Vector3(pos.x, y, pos.y), "rotacao_graus": Vector3(0, rad_to_deg(-ang), 0),
			"tamanho": Vector3(lado, 0.8, lado), "cor": Color("#8a5a2b"), "material": "liso", "colisao": true})
		if topo:
			_novas.append({"id": PREFIXO + "marca_do_bau_topo", "tipo": "caixa", "grupo": GRUPO,
				"posicao": Vector3(pos.x, y + 0.45, pos.y), "rotacao_graus": Vector3.ZERO,
				"tamanho": Vector3(1.2, 0.1, 1.2), "cor": Color("#ffd24a"), "material": "liso", "colisao": false})
	_contagem["plataformas"] = PLATAFORMAS


# --------------------------------------------------------------- personagens
func _bandos() -> void:
	for c: Vector2 in BANDOS_HUMANOIDES:
		var feitos := 0
		for t in 60:
			if feitos >= MACACOS_POR_BANDO:
				break
			var p := CENTRO + c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(3.0, 14.0)
			if _pe(p, "mp_macaco_humanoide", false):
				feitos += 1
				_contagem["macacos"] += 1


## O Mestre do Geppo fica na vila plana. (O Macaco-rei, as plataformas do Geppo e a marca do baú saíram na v2, 22/11/2026: o chefe agora é o Gorila-rei, colocado por `colocar_construcoes_macacos.gd`.)
func _mestre() -> void:
	var p := CENTRO + Vector2(-4, -10)       # em frente à cabana do Mestre (v2)
	if not _pe(p, "npc_mestre_geppo", true):
		push_error("Mestre do Geppo fora do relevo")


## Uma peça `modelo` de personagem/NPC com o pé no chão (a origem da peça é o centro do volume; `NinhoDeInimigo.pe_da_peca` desce meia altura).
func _pe(p: Vector2, modelo: String, livre_de_solo: bool) -> bool:
	var amostra := _chao_em(p)
	if amostra.is_empty() or bool(amostra["molhado"]) or (not livre_de_solo and int(amostra["solo"]) in [2, 3, 6]):
		return false
	for o in _plantadas:
		if o["tipo"] == "personagem" and p.distance_to(o["pos"]) < 2.0:
			return false
	var tam := _bib.tamanho_padrao(modelo)
	_novas.append({"id": PREFIXO + str(_novas.size()), "tipo": "modelo", "modelo": modelo, "grupo": GRUPO,
		"posicao": Vector3(p.x, float(amostra["altura"]) + tam.y * 0.5, p.y), "tamanho": tam,
		"rotacao_graus": Vector3(0, _rng.randi_range(-180, 179), 0), "cor": Color.WHITE, "material": "liso", "colisao": false})
	_plantadas.append({"pos": p, "raio": 1.0, "tronco": 1.0, "tipo": "personagem"})
	return true


func _chao_em(p: Vector2) -> Dictionary:
	for terreno in _terrenos:
		var pos: Vector3 = terreno["posicao"]
		var local := (p - Vector2(pos.x, pos.z)).rotated(deg_to_rad(terreno["rotacao_graus"].y))
		var t: Vector3 = terreno["tamanho"]
		if absf(local.x) > t.x * 0.5 or absf(local.y) > t.z * 0.5:
			continue
		return {"altura": pos.y + TerrenoDoMapa.altura_local(terreno["relevo"], t, local.x, local.y),
			"solo": TerrenoDoMapa.solo_local(terreno["relevo"], t, local.x, local.y),
			"molhado": TerrenoDoMapa.molhado_local(terreno["relevo"], t, local.x, local.y)}
	return {}
