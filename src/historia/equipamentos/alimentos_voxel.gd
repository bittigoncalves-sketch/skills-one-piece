class_name AlimentosVoxel
extends RefCounted
## COMIDAS, BEBIDAS E AKUMA NA MÃO (25/11/2026): modelos voxel por item (`assets/models/alimentos_voxel/<id>.glb`, tools/alimentos_voxel/) e as Akuma
## (`assets/models/akuma_no_mi/<id>.glb`), a posição de cada um na palma e a AGENDA DE SONS do gesto de comer/beber (sons sintetizados em
## `assets/audio/alimentacao/`, art_src/alimentacao/gerar_sons.py). Os tempos são do CLIPE (`comer` 1,9 s: contato 0,53–1,12 s; `beber` 2,2 s: goles
## 0,85–1,38 s), não da parede: comer devagar estica o clipe e os sons vão junto.
const PASTA_ALIMENTOS := "res://assets/models/alimentos_voxel/"
const PASTA_AKUMA := "res://assets/models/akuma_no_mi/"
const PASTA_SONS := "res://assets/audio/alimentacao/"
const PREFIXO_AKUMA := "akuma:"
## Tamanho final do maior lado do item na mão (m) — a Akuma é maior que um pão, a garrafa maior que uma maçã.
const TAMANHO_NA_MAO := {"pao": 0.20, "maca": 0.14, "peixe_assado": 0.26, "sopa_de_peixe": 0.17, "refeicao": 0.22, "carne_assada": 0.22,
	"agua_potavel": 0.24, "leite": 0.22, "suco_de_laranja": 0.22}
const TAMANHO_AKUMA := 0.20
## Perfil de som: o que se ouve em cada mordida/mastigada/engolida (famílias de `gerar_sons.py`).
const PERFIL := {"pao": "macio", "refeicao": "macio", "maca": "crocante", "peixe_assado": "rasgar", "carne_assada": "rasgar",
	"sopa_de_peixe": "sorver", "agua_potavel": "gole", "leite": "gole", "suco_de_laranja": "gole"}
## Volume por família em dB (os arquivos nascem em níveis diferentes: mastigar é baixo, engolir é alto).
const VOLUME_DB := {"morder_crocante": 0.0, "mastigar_macio": 8.0, "rasgar": 2.0, "sorver": -2.0, "gole": -6.0, "engolir": -7.0,
	"akuma_mordida": 0.0, "akuma_arrepio": -3.0}
const VARIACOES := {"morder_crocante": 3, "mastigar_macio": 3, "rasgar": 2, "sorver": 2, "gole": 3, "engolir": 2, "akuma_mordida": 2, "akuma_arrepio": 1}
static var _cenas := {}
static var _sons := {}


static func e_akuma(variante: String) -> bool:
	return variante.begins_with(PREFIXO_AKUMA)


static func id_da_akuma(variante: String) -> String:
	return TreeAndFruitGenerator.id_do_modelo(variante.trim_prefix(PREFIXO_AKUMA))


static func caminho(variante: String) -> String:
	if e_akuma(variante):
		return PASTA_AKUMA + id_da_akuma(variante) + ".glb"
	return PASTA_ALIMENTOS + variante + ".glb"


## O modelo voxel do item (PackedScene) ou null se não existe (o chamador cai no modelo antigo).
static func cena(variante: String) -> PackedScene:
	if variante.is_empty():
		return null
	if _cenas.has(variante):
		return _cenas[variante]
	var c := caminho(variante)
	var r: PackedScene = load(c) as PackedScene if ResourceLoader.exists(c) else null
	_cenas[variante] = r
	return r


## Variante aceita pela rede (id de alimento conhecido ou Akuma com modelo): a RPC do servidor só vale para o que existe.
static func valida(variante: String) -> bool:
	return variante.is_empty() or PERFIL.has(variante) or (e_akuma(variante) and ResourceLoader.exists(caminho(variante)))


## Nó pronto para prender na mão: escalado para `TAMANHO_NA_MAO` e centrado no ponto de pega (a palma segura o centro do item).
static func instanciar(variante: String) -> Node3D:
	var pacote := cena(variante)
	if pacote == null:
		return null
	var raiz := Node3D.new()
	var modelo := pacote.instantiate() as Node3D
	raiz.add_child(modelo)
	var lado := TAMANHO_AKUMA if e_akuma(variante) else float(TAMANHO_NA_MAO.get(variante, 0.2))
	var caixa := AABB()
	var primeiro := true
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var a := (mi as MeshInstance3D).get_aabb()
		caixa = a if primeiro else caixa.merge(a)
		primeiro = false
	var maior := maxf(maxf(caixa.size.x, caixa.size.y), maxf(caixa.size.z, 0.001))
	var k := lado / maior
	modelo.scale = Vector3.ONE * k
	modelo.position = -(caixa.position + caixa.size * 0.5) * k
	return raiz


## Agenda de sons do gesto: [{"t": s do clipe, "som": família, "db": volume}], pelo item e pelo tipo de clipe ("comida" | "agua").
static func agenda(variante: String, tipo: String) -> Array:
	var ev: Array = []
	if e_akuma(variante):
		for t in [0.55, 0.78]:
			ev.append(_e(t, "akuma_mordida"))
		ev.append(_e(0.98, "mastigar_macio"))
		ev.append(_e(1.18, "mastigar_macio"))
		ev.append(_e(1.50, "engolir"))
		ev.append(_e(1.62, "akuma_arrepio"))
		return ev
	var perfil := str(PERFIL.get(variante, "gole" if tipo == "agua" else "macio"))
	if perfil == "gole":
		for t in [0.88, 1.14, 1.40]:
			ev.append(_e(t, "gole"))
		ev.append(_e(1.78, "engolir"))
		return ev
	var morder: String = {"macio": "mastigar_macio", "crocante": "morder_crocante", "rasgar": "rasgar", "sorver": "sorver"}[perfil]
	ev.append(_e(0.55, morder))
	for t in [0.76, 0.95, 1.14]:
		ev.append(_e(t, "mastigar_macio" if perfil != "crocante" else "morder_crocante"))
	ev.append(_e(1.52, "engolir"))
	return ev


static func _e(t: float, som: String) -> Dictionary:
	return {"t": t, "som": som, "db": float(VOLUME_DB.get(som, 0.0))}


## Sorteia uma variação da família (arquivo `<familia>_<n>.wav`), ou null.
static func som(familia: String, rng: RandomNumberGenerator) -> AudioStream:
	var n := rng.randi_range(1, int(VARIACOES.get(familia, 1)))
	var chave := "%s_%d" % [familia, n]
	if not _sons.has(chave):
		var c := PASTA_SONS + chave + ".wav"
		_sons[chave] = load(c) as AudioStream if ResourceLoader.exists(c) else null
	return _sons[chave]
