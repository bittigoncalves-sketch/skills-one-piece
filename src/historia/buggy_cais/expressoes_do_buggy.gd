class_name ExpressoesDoBuggy
extends RefCounted
# ============================================================================
#  EXPRESSÕES E TEXTURAS DO BUGGY (21/11/2026) — o modelo `mp_buggy` tem UM material com o atlas 64×64 `mp_buggy_corpo.png`. As texturas novas (corpo) e as expressões faciais são
#  VARIANTES DO MESMO ATLAS (o Codex repinta; o layout UV não muda): trocar a expressão = trocar a `albedo_texture` desse material. Arquivos, em `pasta` (`PASTA_PADRAO`):
#    <id>_corpo.png            textura nova do corpo de cada personagem (`mp_buggy`, `mp_cabaji`, `mp_richie`, `mp_pirate_pirate4`, `mp_pirate_pirate5`)
#    buggy_rosto_<expr>.png    atlas completo do Buggy com só o rosto trocado (neutro, riso, raiva, surpresa, malicioso, derrotado)
#  Arquivo ausente = nada acontece (o jogo usa a textura original): o código nunca depende de a arte já ter chegado.
# ============================================================================
const PASTA_PADRAO := "res://assets/textures/desafio_buggy/"
const EXPRESSOES := ["neutro", "riso", "raiva", "surpresa", "malicioso", "derrotado"]
const TEXTURA_DO_CORPO := "mp_buggy_corpo.png"

static var pasta := PASTA_PADRAO        # os testes apontam para uma pasta própria
static var _cache: Dictionary = {}


static func caminho_da_expressao(expr: String) -> String:
	return pasta + "buggy_rosto_%s.png" % expr


static func caminho_do_corpo(id: String) -> String:
	return pasta + "%s_corpo.png" % id


static func existe(expr: String) -> bool:
	return expr in EXPRESSOES and _tem(caminho_da_expressao(expr))


static func _tem(caminho: String) -> bool:
	return ResourceLoader.exists(caminho) or FileAccess.file_exists(caminho)


static func _textura(caminho: String) -> Texture2D:
	if _cache.has(caminho):
		return _cache[caminho]
	var t: Texture2D = null
	if ResourceLoader.exists(caminho):
		t = load(caminho) as Texture2D
	elif FileAccess.file_exists(caminho):
		var img := Image.load_from_file(caminho)
		t = ImageTexture.create_from_image(img) if img != null else null
	_cache[caminho] = t
	return t


## Materiais (por malha/superfície) do modelo que usam o atlas do corpo `corpo_png` (nome do arquivo). Cada superfície ganha material PRÓPRIO na primeira troca, para não
## mexer no material compartilhado do recurso importado (outros Buggys do mapa continuam iguais).
static func _superficies(modelo: Node, corpo_png: String) -> Array:
	var saida: Array = []
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.albedo_texture == null:
				continue
			# já trocada antes (a textura em memória não tem caminho) OU ainda é o atlas original
			if mat.has_meta("do_desafio") or mat.albedo_texture.resource_path.ends_with(corpo_png):
				saida.append([m, s])
	return saida


static func _trocar(modelo: Node, corpo_png: String, tex: Texture2D) -> int:
	var n := 0
	if tex == null:
		return 0
	for par: Array in _superficies(modelo, corpo_png):
		var m := par[0] as MeshInstance3D
		var s: int = par[1]
		var atual := m.get_surface_override_material(s) as BaseMaterial3D
		var mat: BaseMaterial3D = atual if atual != null and atual.has_meta("do_desafio") else (m.get_active_material(s) as BaseMaterial3D).duplicate()
		mat.set_meta("do_desafio", true)
		mat.albedo_texture = tex
		m.set_surface_override_material(s, mat)
		n += 1
	return n


## Troca o rosto do Buggy. Devolve quantas superfícies mudaram (0 = arte ausente ou modelo sem o atlas).
static func expressao(buggy: Node, expr: String) -> int:
	if not (expr in EXPRESSOES):
		return 0
	return _trocar(buggy, TEXTURA_DO_CORPO, _textura(caminho_da_expressao(expr)))


## Aplica a textura nova do corpo de `id` (`mp_buggy`…) se o arquivo existir.
static func textura_do_corpo(modelo: Node, id: String) -> int:
	return _trocar(modelo, "%s_corpo.png" % id, _textura(caminho_do_corpo(id)))


## Expressão sugerida por estado de diálogo (cada linha do JSON pode sobrescrever com o campo "expressao").
static func do_estado(estado: String) -> String:
	match estado:
		"chegada": return "riso"
		"desafio": return "malicioso"
		"regras": return "neutro"
		"acerto": return "derrotado"
		"erro_n7": return "riso"
		"aceitou": return "malicioso"
		"recusou": return "riso"
		"luta": return "malicioso"                 # 22/11/2026: a luta do ringue
		"luta_vencida": return "derrotado"
		"luta_perdida": return "riso"
	return "neutro"
