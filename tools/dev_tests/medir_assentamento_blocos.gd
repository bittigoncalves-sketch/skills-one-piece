extends SceneTree
# ============================================================================
#  ASSENTAMENTO NO RELEVO EM BLOCOS (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E4).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/medir_assentamento_blocos.gd
#
#  Por ilha: cada peça `modelo` em terra (fora d'água, base acima do mar) contra o topo
#  dos blocos sob ela — quantas FLUTUAM (base mais de 5 cm acima do bloco mais alto sob
#  a pegada central) e quantas ENTERRAM (base mais de 30 cm abaixo do bloco mais baixo).
#  Estruturas do Mine Piece: a base é o piso do molde (origem + camadas de chão).
#  Só mede; não muda o mapa.
# ============================================================================

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const RELATORIO := "res://build/mine_piece/estruturas/relatorio.json"


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var mapa: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
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
		if p["tipo"] == "terreno":
			grupos[ilha]["terreno"].append(p)
		elif p["tipo"] == "modelo":
			grupos[ilha]["modelos"].append(p)
	var total_flutua := 0
	var total_enterra := 0
	for ilha in grupos:
		var relevo := RelevoEmBlocos.new()
		relevo.calcular_ou_ler(grupos[ilha]["terreno"], ilha)
		var flutua: Array = []
		var enterra := 0
		var medidos := 0
		for p: Dictionary in grupos[ilha]["modelos"]:
			var modelo := str(p["modelo"])
			if "_vendedor_" in String(p["id"]) or "_tripulante_" in String(p["id"]):
				continue                       # de pé no piso da loja / do navio
			var pos: Vector3 = p["posicao"]
			var tam: Vector3 = p["tamanho"]
			var base := pos.y - tam.y * 0.5
			if relatorio.has(modelo):
				var giro := Basis(Vector3.UP, deg_to_rad((p["rotacao_graus"] as Vector3).y))
				var origem := pos - giro * (bib.info(modelo)["centro"] as Vector3)
				base = origem.y + int(relatorio[modelo].get("chao_blocos", 0)) * RelevoEmBlocos.BLOCO
				if modelo.begins_with("mpe_ship_"):
					continue
			if base < 0.0:
				continue                       # na água / navio / fundo
			# Pegada central (metade do tamanho, girada pelo modelo).
			var lo := INF
			var hi := -INF
			var giro_y := deg_to_rad((p["rotacao_graus"] as Vector3).y)
			for dx in [-0.25, 0.0, 0.25]:
				for dz in [-0.25, 0.0, 0.25]:
					var d := Vector3(dx * tam.x, 0, dz * tam.z).rotated(Vector3.UP, giro_y)
					var h := relevo.altura(pos.x + d.x, pos.z + d.z)
					if is_nan(h):
						continue
					lo = minf(lo, h)
					hi = maxf(hi, h)
			if lo == INF:
				continue
			medidos += 1
			if base > hi + 0.05:
				flutua.append("%s %.2f" % [p["id"], base - hi])
			elif base < lo - 0.3:
				enterra += 1
		total_flutua += flutua.size()
		total_enterra += enterra
		print("ASSENTA %-26s medidos %4d  flutuam %3d  enterram %3d  %s" % [ilha, medidos, flutua.size(), enterra,
			str(flutua.slice(0, 3))])
	print("ASSENTA total flutuam %d, enterram %d" % [total_flutua, total_enterra])
	quit()
