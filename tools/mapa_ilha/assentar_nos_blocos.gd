extends SceneTree
# ============================================================================
#  ASSENTAR NOS BLOCOS (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E4).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/assentar_nos_blocos.gd [-- --saida=<arq>]
#
#  O jogo desenha o relevo em blocos, que difere do liso em até ~0,22 m: peças postas no
#  liso podem FLUTUAR. Esta ferramenta só DESCE o que flutua (base mais de 5 cm acima do
#  bloco mais alto sob a pegada central): árvore e mato até o bloco mais baixo sob ela
#  − 8 cm (a regra do `plantar_natureza.gd`); o resto até o bloco mais alto − 2 cm.
#  Fica como está: o que atravessa água (pontes), vendedor e tripulante (de pé em piso
#  de loja/navio), navio, o que está abaixo do mar e o que já enterra.
#  Mexe só no y; guarda cópia do mapa; não grava se o arquivo mudou durante a execução.
#  Idempotente: rodar de novo não acha nada.
# ============================================================================

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const RELATORIO := "res://build/mine_piece/estruturas/relatorio.json"
const FLUTUA := 0.05


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := MAPA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido")
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var bib := BibliotecaDeModelos.padrao()
	var relatorio := {}
	if FileAccess.file_exists(RELATORIO):
		for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(RELATORIO)):
			relatorio["mpe_" + str(r["estrutura"])] = r
	var caixas := Ilhas.caixas(mapa)
	var grupos := {}
	for p: Dictionary in mapa["pecas"]:
		var ilha := Ilhas.ilha_em(caixas, p["posicao"], Ilhas.MARGEM)
		if ilha.is_empty():
			continue
		if not grupos.has(ilha):
			grupos[ilha] = {"terreno": [], "modelos": []}
		grupos[ilha]["terreno" if p["tipo"] == "terreno" else "modelos"].append(p)
	var descidas := 0
	for ilha in grupos:
		var relevo := RelevoEmBlocos.new()
		relevo.calcular_ou_ler(grupos[ilha]["terreno"], ilha)
		var aqui := 0
		for p: Dictionary in grupos[ilha]["modelos"]:
			if p["tipo"] != "modelo":
				continue
			var id := String(p["id"])
			var modelo := str(p["modelo"])
			if "_vendedor_" in id or "_tripulante_" in id or modelo.begins_with("mpe_ship_") \
					or bib.categorias_do_modelo(modelo).has("navios"):
				continue
			var pos: Vector3 = p["posicao"]
			var tam: Vector3 = p["tamanho"]
			var base := pos.y - tam.y * 0.5
			if relatorio.has(modelo):
				var giro := Basis(Vector3.UP, deg_to_rad((p["rotacao_graus"] as Vector3).y))
				base = (pos - giro * (bib.info(modelo)["centro"] as Vector3)).y \
					+ int(relatorio[modelo].get("chao_blocos", 0)) * RelevoEmBlocos.BLOCO
			if base < 0.0:
				continue
			var lo := INF
			var hi := -INF
			var molhado := false
			var giro_y := deg_to_rad((p["rotacao_graus"] as Vector3).y)
			for dx in [-0.25, 0.0, 0.25]:
				for dz in [-0.25, 0.0, 0.25]:
					var d := Vector3(dx * tam.x, 0, dz * tam.z).rotated(Vector3.UP, giro_y)
					var x := pos.x + d.x
					var z := pos.z + d.z
					molhado = molhado or _molhado(grupos[ilha]["terreno"], x, z)
					var h := relevo.altura(x, z)
					if not is_nan(h):
						lo = minf(lo, h)
						hi = maxf(hi, h)
			if molhado or lo == INF or base <= hi + FLUTUA:
				continue
			var cats := bib.categorias_do_modelo(modelo)
			var alvo := (lo - 0.08) if (cats.has("arvores") or cats.has("floresta")) else (hi - 0.02)
			p["posicao"] = pos + Vector3(0, alvo - base, 0)
			aqui += 1
		descidas += aqui
		print("ASSENTAR %-26s %3d peças descidas" % [ilha, aqui])
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_assentar_blocos_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			push_error("o mapa mudou durante a execução — NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, mapa)
	print("ASSENTAR %d peças descidas -> %s (%s)" % [descidas, saida, error_string(err)])
	quit(0 if err == OK else 1)


static func _molhado(terrenos: Array, x: float, z: float) -> bool:
	for t: Dictionary in terrenos:
		var pos: Vector3 = t["posicao"]
		var tam: Vector3 = t["tamanho"]
		if absf(x - pos.x) <= tam.x * 0.5 and absf(z - pos.z) <= tam.z * 0.5:
			return TerrenoDoMapa.molhado_local(t["relevo"], tam, x - pos.x, z - pos.z)
	return false
