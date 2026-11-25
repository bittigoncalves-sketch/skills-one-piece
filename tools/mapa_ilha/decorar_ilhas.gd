extends SceneTree
# ============================================================================
#  DECORAÇÃO DAS DEMAIS ILHAS (18/11/2026, pedido do dono: "partir para o desenvolvimento das outras ilhas decorando"). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/decorar_ilhas.gd [-- --saida=<caminho>] [--so=ilha_east_blue,...]
#
#  Cada ilha (menos a inicial e a dos macacos, que têm geradores próprios) ganha vegetação e pedras da loja (`floresta_*`, palmeiras, cerejeiras) em
#  estilo próprio — a `ESTILOS` abaixo —, sobre o solo de capim (`SOLO_PLANTAVEL`), fora de trilha, praia, água, barranco e das peças que já existem
#  (construções, NPCs, personagens). Só mexe nas peças com prefixo `deco_<ilha>_`; rodar de novo troca tudo, sem duplicar. Cópia do mapa antes e NÃO grava
#  se o arquivo mudou durante a execução (mesma proteção dos outros geradores).
#  Estilo por ilha (decisão de design minha, a confirmar): East Blue = bosques de carvalho e bétula (hub aberto); Foosha/Shimotsuki = jardins de vila (arbustos, flores,
#  pedras); Marinha 153 = gramado com pedras e poucos pinheiros; acampamentos = pinheiros, toras e pedras; Water Seven = palmeiras e arbustos; Wano = cerejeiras e pinheiros;
#  Shandora = palmeiras gigantes e cogumelos.
# ============================================================================
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const SOLO_PLANTAVEL := [0, 5]
const SOLOS_DE_CAMINHO := [2, 3, 6]

const CARVALHOS := ["floresta_tree_oak_medium_green", "floresta_tree_oak_large_green", "floresta_tree_birch_large_green", "floresta_tree_park_medium_green", "floresta_tree_elm_green"]
const PINHEIROS := ["floresta_tree_pine_medium", "floresta_tree_pine_large", "floresta_tree_spruce_large", "floresta_tree_spruce_medium"]
const ARBUSTOS := ["floresta_bush_medium", "floresta_bush_with_flowers", "floresta_bush_clumps_small", "floresta_bush_large"]
const FLORES := ["floresta_flowers_red", "floresta_grass_large", "floresta_grass_medium", "floresta_mushroom_red_large"]
const PEDRAS := ["floresta_rock_05", "floresta_rock_06", "floresta_rock_07", "floresta_rock_03", "floresta_boulder_01"]
const TORAS := ["floresta_fallen_log", "floresta_tree_stump"]
const PALMEIRAS := ["palmeira_adulta", "palmeira_jovem"]
const CEREJEIRAS := ["cerejeira_adulta", "cerejeira_jovem"]
const COGUMELOS := ["floresta_mushroom_brown_large", "floresta_mushroom_red_large", "floresta_mushroom_brown_medium"]

## id da baseplate → {centro, meia, grupos: [{paleta, qtd, escala (min,max), arvore, fator}]}. `arvore` = afasta pela copa; senão só pelo tronco/pegada.
const ESTILOS := {
	"baseplate_east_blue": {"centro": Vector2(3000, 0), "meia": 192.0, "grupos": [
		{"paleta": CARVALHOS, "qtd": 70, "escala": Vector2(1.7, 2.6), "arvore": true, "fator": 0.5},
		{"paleta": PINHEIROS, "qtd": 25, "escala": Vector2(1.6, 2.4), "arvore": true, "fator": 0.5},
		{"paleta": ARBUSTOS, "qtd": 90, "escala": Vector2(1.0, 1.6), "arvore": false},
		{"paleta": FLORES, "qtd": 80, "escala": Vector2(1.0, 1.6), "arvore": false},
		{"paleta": PEDRAS, "qtd": 30, "escala": Vector2(1.0, 1.8), "arvore": false}]},
	"baseplate_vila_foosha": {"centro": Vector2(2250, 600), "meia": 128.0, "grupos": [
		{"paleta": ARBUSTOS, "qtd": 60, "escala": Vector2(1.0, 1.5), "arvore": false},
		{"paleta": FLORES, "qtd": 90, "escala": Vector2(1.0, 1.8), "arvore": false},
		{"paleta": PEDRAS, "qtd": 20, "escala": Vector2(0.8, 1.4), "arvore": false},
		{"paleta": CARVALHOS, "qtd": 12, "escala": Vector2(1.6, 2.2), "arvore": true, "fator": 0.55}]},
	"baseplate_vila_shimotsuki": {"centro": Vector2(3750, 600), "meia": 128.0, "grupos": [
		{"paleta": ARBUSTOS, "qtd": 60, "escala": Vector2(1.0, 1.5), "arvore": false},
		{"paleta": FLORES, "qtd": 90, "escala": Vector2(1.0, 1.8), "arvore": false},
		{"paleta": CEREJEIRAS, "qtd": 14, "escala": Vector2(1.6, 2.4), "arvore": true, "fator": 0.55},
		{"paleta": PEDRAS, "qtd": 18, "escala": Vector2(0.8, 1.4), "arvore": false}]},
	"baseplate_marinha_153": {"centro": Vector2(3000, -800), "meia": 128.0, "grupos": [
		{"paleta": PEDRAS, "qtd": 30, "escala": Vector2(1.0, 1.8), "arvore": false},
		{"paleta": PINHEIROS, "qtd": 14, "escala": Vector2(1.6, 2.2), "arvore": true, "fator": 0.55},
		{"paleta": ARBUSTOS, "qtd": 40, "escala": Vector2(1.0, 1.4), "arvore": false}]},
	"baseplate_acampamento_pirata": {"centro": Vector2(3750, -450), "meia": 96.0, "grupos": [
		{"paleta": PINHEIROS, "qtd": 26, "escala": Vector2(1.7, 2.5), "arvore": true, "fator": 0.5},
		{"paleta": TORAS, "qtd": 22, "escala": Vector2(1.0, 1.6), "arvore": false},
		{"paleta": PEDRAS, "qtd": 24, "escala": Vector2(1.0, 1.8), "arvore": false}]},
	"baseplate_acampamento_bandido": {"centro": Vector2(2250, -500), "meia": 96.0, "grupos": [
		{"paleta": PINHEIROS, "qtd": 28, "escala": Vector2(1.7, 2.6), "arvore": true, "fator": 0.5},
		{"paleta": TORAS, "qtd": 24, "escala": Vector2(1.0, 1.6), "arvore": false},
		{"paleta": PEDRAS, "qtd": 26, "escala": Vector2(1.0, 2.0), "arvore": false}]},
	"baseplate_water_seven": {"centro": Vector2(5000, 0), "meia": 160.0, "grupos": [
		{"paleta": PALMEIRAS, "qtd": 40, "escala": Vector2(1.6, 2.4), "arvore": true, "fator": 0.5},
		{"paleta": ARBUSTOS, "qtd": 60, "escala": Vector2(1.0, 1.5), "arvore": false},
		{"paleta": FLORES, "qtd": 50, "escala": Vector2(1.0, 1.6), "arvore": false}]},
	"baseplate_wano": {"centro": Vector2(6500, 0), "meia": 160.0, "grupos": [
		{"paleta": CEREJEIRAS, "qtd": 40, "escala": Vector2(1.8, 2.8), "arvore": true, "fator": 0.5},
		{"paleta": PINHEIROS, "qtd": 24, "escala": Vector2(1.7, 2.5), "arvore": true, "fator": 0.5},
		{"paleta": PEDRAS, "qtd": 30, "escala": Vector2(1.0, 2.0), "arvore": false},
		{"paleta": FLORES, "qtd": 50, "escala": Vector2(1.0, 1.6), "arvore": false}]},
	"baseplate_shandora": {"centro": Vector2(8000, 0), "meia": 192.0, "grupos": [
		{"paleta": PALMEIRAS, "qtd": 50, "escala": Vector2(2.4, 3.6), "arvore": true, "fator": 0.5},
		{"paleta": COGUMELOS, "qtd": 50, "escala": Vector2(3.0, 5.0), "arvore": false},
		{"paleta": ARBUSTOS, "qtd": 60, "escala": Vector2(1.2, 1.8), "arvore": false},
		{"paleta": PEDRAS, "qtd": 30, "escala": Vector2(1.0, 2.0), "arvore": false}]},
}
## Árvores saem 1,4× maiores que a faixa de escala do estilo (a 1ª captura mostrou copas pequenas demais para ilhas de 256–384 m).
const ESCALA_DE_ARVORE := 1.4

var _rng := RandomNumberGenerator.new()
var _bib: BibliotecaDeModelos
var _terrenos: Array[Dictionary] = []
var _obstaculos: Array[Dictionary] = []
var _novas: Array[Dictionary] = []
var _plantadas: Array[Dictionary] = []
var _atual := ""
var _contagem := {}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var saida := MAPA
	var so: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
		elif a.begins_with("--so="):
			so = a.trim_prefix("--so=").split(",", false)
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	_bib = BibliotecaDeModelos.padrao()
	var todos := {}
	for e: Dictionary in ESTILOS.values():
		for g: Dictionary in e["grupos"]:
			for id: String in g["paleta"]:
				todos[id] = true
	for id in todos:
		if not _bib.tem(id):
			push_error("falta na loja: " + id)
			quit(1)
			return
	var mapa: Dictionary = lido["mapa"]
	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with("deco_"):
			if so.is_empty() or _da_ilha_pedida(String(p["id"]), so):
				trocadas += 1
				continue
		pecas.append(p)
		if p["tipo"] == "terreno":
			_terrenos.append(p)
		elif p["tipo"] == "modelo":
			_obstaculos.append(p)
	var grupos: Array = []
	var meus := {}
	for base: String in ESTILOS:
		var ilha := base.trim_prefix("baseplate_")
		if not so.is_empty() and not so.has("ilha_" + ilha) and not so.has(ilha):
			continue
		_decorar(base, ilha)
		meus["deco_" + ilha] = true
	pecas.append_array(_novas)
	for g: Dictionary in mapa["grupos"]:
		if not meus.has(g["id"]):
			grupos.append(g)
	for id in meus:
		grupos.append({"id": id, "pai": ""})
	mapa["grupos"] = grupos
	mapa["pecas"] = pecas
	var validado := MapaArquivo.validar(JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"], "pecas": mapa["pecas"], "grupos": mapa["grupos"]})))
	if not validado["ok"]:
		push_error("mapa gerado não valida: %s" % str(validado["erros"]).left(600))
		quit(1)
		return
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_decoracao_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			print("DECORACAO recusada: o mapa mudou durante a execução — mapa NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("DECORACAO %d peças novas (trocadas %d): %s -> %s (%s)" % [_novas.size(), trocadas, str(_contagem), saida, error_string(err)])
	quit(0 if err == OK else 1)


func _da_ilha_pedida(id: String, so: PackedStringArray) -> bool:
	for i in so:
		if id.begins_with("deco_%s_" % i.trim_prefix("ilha_")):
			return true
	return false


func _decorar(base: String, ilha: String) -> void:
	_atual = ilha
	_plantadas.clear()
	_rng.seed = hash("deco_" + ilha)
	var estilo: Dictionary = ESTILOS[base]
	var centro: Vector2 = estilo["centro"]
	var meia: float = estilo["meia"]
	var feitas := 0
	for g: Dictionary in estilo["grupos"]:
		var qtd: int = g["qtd"]
		var n := 0
		for t in qtd * 25:
			if n >= qtd:
				break
			var paleta: Array = g["paleta"]
			var modelo: String = paleta[_rng.randi() % paleta.size()]
			var faixa: Vector2 = g["escala"]
			var p := centro + Vector2(_rng.randf_range(-meia, meia), _rng.randf_range(-meia, meia))
			if _plantar(modelo, p, _rng.randf_range(faixa.x, faixa.y) * (ESCALA_DE_ARVORE if bool(g["arvore"]) else 1.0), bool(g["arvore"]), float(g.get("fator", 1.0)), centro, meia):
				n += 1
		feitas += n
	_contagem[ilha] = feitas


func _plantar(modelo: String, p: Vector2, escala: float, arvore: bool, fator: float, centro: Vector2, meia: float) -> bool:
	if absf(p.x - centro.x) > meia or absf(p.y - centro.y) > meia:
		return false
	var tam := _bib.tamanho_padrao(modelo) * escala
	var largura := maxf(tam.x, tam.z)
	var raio := largura * 0.5
	var tronco := maxf(0.8, largura * 0.07) if arvore else largura * 0.4
	var amostra := _chao_em(p)
	if amostra.is_empty() or not int(amostra["solo"]) in SOLO_PLANTAVEL or bool(amostra["molhado"]):
		return false
	var minimo: float = amostra["altura"]
	var maximo := minimo
	var margem := maxf(1.5, tronco * 1.4)
	for i in 8:
		var c := _chao_em(p + Vector2.from_angle(i * TAU / 8.0) * margem)
		if c.is_empty() or bool(c["molhado"]) or int(c["solo"]) in SOLOS_DE_CAMINHO:
			return false
		minimo = minf(minimo, float(c["altura"]))
		maximo = maxf(maximo, float(c["altura"]))
	if maximo - minimo > (1.2 if arvore else 0.5):
		return false
	for o in _plantadas:
		var d := p.distance_to(o["pos"])
		if arvore and o["arvore"]:
			if d < (raio + float(o["raio"])) * fator:
				return false
		elif d < tronco + float(o["tronco"]) + 0.5:
			return false
	for o in _obstaculos:
		var local := (p - Vector2(o["posicao"].x, o["posicao"].z)).rotated(deg_to_rad(o["rotacao_graus"].y))
		var folga := tronco + (3.0 if arvore else 1.2)       # construções e personagens: folga maior para a copa
		if absf(local.x) < o["tamanho"].x * 0.5 + folga and absf(local.y) < o["tamanho"].z * 0.5 + folga:
			return false
	_novas.append({"id": "deco_%s_%d" % [_atual, _novas.size()], "tipo": "modelo", "modelo": modelo, "grupo": "deco_" + _atual,
		"posicao": Vector3(p.x, minimo - 0.06 + tam.y * 0.5, p.y), "tamanho": tam,
		"rotacao_graus": Vector3(0, _rng.randi_range(-180, 179), 0), "cor": Color.WHITE, "material": "liso",
		"colisao": not _bib.atravessavel(modelo)})
	_plantadas.append({"pos": p, "raio": raio, "tronco": tronco, "arvore": arvore})
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
