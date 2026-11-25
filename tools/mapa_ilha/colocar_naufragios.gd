extends SceneTree
# ============================================================================
#  NAUFRÁGIOS NO MAPA VIVO (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_naufragios.gd [-- --simular]
#
#  Idempotente: tira os naufrágios que ESTA ferramenta pôs (id `naufragio_*`) e põe de
#  novo nos sítios achados pelo `RelevoMarinho` — a mesma conta do jogo. Peças do dono
#  ficam como estão. Cópia do mapa em art_src/backups/mapa_historia/ antes de gravar;
#  recusa gravar se o arquivo mudou durante a execução (outra frente editando).
#
#  Sítio bom: 8–22 m de água (decisão do dono: ao alcance do fôlego de 30 s), chão PLANO
#  sob o casco inteiro, fora do miolo de recife e da rocha, longe do porto e dos outros
#  naufrágios. O casco deita ao longo da curva de nível (como afunda de verdade).
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const NIVEL := -0.65
## (id da peça, modelo, ilha pela baseplate, setor em graus em volta da ilha: 0 = leste,
## 90 = sul (+z), 180 = oeste, 270 = norte).
const PLANO := [
	["naufragio_1", "naufragio_galeao", "baseplate", 270.0],
	["naufragio_2", "naufragio_chalupa", "baseplate", 180.0],
	["naufragio_3", "naufragio_bote", "baseplate", 100.0],
	["naufragio_4", "naufragio_galeao", "baseplate_macacos", 0.0],
	["naufragio_5", "naufragio_chalupa", "baseplate_macacos", 270.0],
]
const PROFUNDIDADE := Vector2(8.0, 22.0)
const LONGE_DO_PORTO := 170.0
const ENTRE_NAUFRAGIOS := 150.0

var _relevo: RelevoMarinho
var _placas := {}                # id da 1ª baseplate da ilha → Rect2


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var simular := OS.get_cmdline_user_args().has("--simular")
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido")
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var bib := BibliotecaDeModelos.padrao()
	for linha in PLANO:
		if not bib.tem(linha[1]):
			push_error("falta na loja: %s (rode tools/importar_naufragios_na_loja.gd)" % linha[1])
			quit(1)
			return
	var oceano: Script = load("res://src/world/oceano_historia.gd")
	var bases: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return oceano.e_base(p))
	var lista: Array[Rect2] = []
	for ilha in FundoDoMar.agrupar(bases):
		var r := FundoDoMar.caixa_de(ilha)
		lista.append(r)
		for b in ilha:
			_placas[b["id"]] = r
	var terrenos: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return p.get("tipo") == "terreno")
	_relevo = RelevoMarinho.new()
	_relevo.relevo_em = FundoDoMar._relevo_em.bind(terrenos)
	_relevo.configurar(lista, FundoDoMar.ALCANCE, NIVEL)
	var portos: Array[Vector2] = []
	for p: Dictionary in mapa["pecas"]:
		if p.get("tipo") == "modelo" and String(p.get("modelo", "")).begins_with("dock"):
			portos.append(Vector2(p["posicao"].x, p["posicao"].z))

	var pecas: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return not String(p["id"]).begins_with("naufragio_"))
	var postos: Array[Vector2] = []
	var novas: Array = []
	for linha in PLANO:
		var info := bib.info(linha[1])
		var tam: Vector3 = info["tamanho"]
		var centro: Vector3 = info["centro"]
		var sitio := _achar(_placas[linha[2]], float(linha[3]), tam, portos, postos)
		if sitio.is_empty():
			push_error("sem sítio para %s no setor %.0f° de %s" % [linha[0], linha[3], linha[2]])
			quit(1)
			return
		postos.append(sitio["p"])
		var pos := Vector3(sitio["p"].x, sitio["base"] + centro.y, sitio["p"].y)
		novas.append({"id": linha[0], "tipo": "modelo", "modelo": linha[1], "grupo": "naufragios",
			"posicao": pos, "rotacao_graus": Vector3(0, sitio["giro"], 0), "tamanho": tam,
			"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true})
		print("NAUFRAGIO %s %-18s em (%.1f, %.2f, %.1f) giro %.0f° prof %.1f m desnível %.2f m" % [
			linha[0], linha[1], pos.x, pos.y, pos.z, sitio["giro"], NIVEL - sitio["base"], sitio["desnivel"]])
	if simular:
		print("SIMULACAO: mapa NÃO gravado")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
	var copia := BACKUPS.path_join("baseplate_antes_naufragios_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)
	pecas.append_array(novas)
	if not (mapa["grupos"] as Array).any(func(g: Dictionary) -> bool: return g["id"] == "naufragios"):
		(mapa["grupos"] as Array).append({"id": "naufragios", "pai": ""})
	if FileAccess.get_file_as_string(MAPA) != original:
		print("NAUFRAGIOS recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
		quit(1)
		return
	mapa["pecas"] = pecas
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("NAUFRAGIOS grava=%s (%d peças)" % [error_string(err), novas.size()])
	quit(0 if err == OK else 1)


## Melhor sítio no setor (±35°) em volta da placa. {} = nenhum.
func _achar(placa: Rect2, setor: float, tam: Vector3, portos: Array[Vector2], postos: Array[Vector2]) -> Dictionary:
	var melhor := {}
	var nota := -INF
	var c := placa.get_center()
	for da in range(-35, 36, 3):
		var ang := deg_to_rad(setor + da)
		var rumo := Vector2(cos(ang), sin(ang))
		var t := minf(placa.size.x * 0.5 / maxf(absf(rumo.x), 1e-4), placa.size.y * 0.5 / maxf(absf(rumo.y), 1e-4))
		for d in range(80, 260, 5):
			var p := c + rumo * (t + d)
			var s := _relevo.amostra(p.x, p.y)
			var prof := NIVEL - s.x
			if prof < PROFUNDIDADE.x or prof > PROFUNDIDADE.y or s.y > 0.25 or s.z > 0.08:
				continue
			if portos.any(func(q: Vector2) -> bool: return q.distance_to(p) < LONGE_DO_PORTO):
				continue
			if postos.any(func(q: Vector2) -> bool: return q.distance_to(p) < ENTRE_NAUFRAGIOS):
				continue
			# Ao longo da curva de nível: perpendicular ao gradiente.
			var g := Vector2(_relevo.altura(p.x + 1, p.y) - _relevo.altura(p.x - 1, p.y), _relevo.altura(p.x, p.y + 1) - _relevo.altura(p.x, p.y - 1))
			var ao_longo := Vector2(-g.y, g.x).normalized() if g.length() > 1e-4 else rumo.orthogonal()
			var lado := ao_longo.orthogonal()
			var alturas: Array[float] = []
			for fx in [-0.45, 0.0, 0.45]:
				for fy in [-0.3, 0.0, 0.3]:
					var q: Vector2 = p + ao_longo * tam.x * fx + lado * tam.z * fy
					alturas.append(_relevo.altura(q.x, q.y))
			var desnivel: float = alturas.max() - alturas.min()
			if desnivel > 1.4:
				continue
			# Nota: plano, perto do meio da faixa de profundidade, e com recife por perto (cena bonita).
			var perto_recife := 0.0
			for k in 8:
				var o := Vector2(26, 0).rotated(k * TAU / 8.0)
				perto_recife += _relevo.recife(p.x + o.x, p.y + o.y)
			var n := -desnivel * 2.0 - absf(prof - 14.0) * 0.15 + perto_recife * 0.6 - absf(da) * 0.01
			if n > nota:
				nota = n
				# +X do modelo (proa) ao longo da curva: giro Y que leva +X a (ax, 0, az).
				melhor = {"p": p, "base": alturas.min(), "giro": rad_to_deg(atan2(-ao_longo.y, ao_longo.x)), "desnivel": desnivel}
	return melhor
