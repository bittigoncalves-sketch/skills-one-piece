extends SceneTree
# ============================================================================
#  BANDIDOS NO CAMPO ABERTO + GUARDA DA VILA (08/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_bandidos_e_missao.gd
#
#  Pedido do dono: "adicionar no mapa bandidos com base no dummy que é capaz de lutar,
#  adicione-os em campo aberto; adicionar um npc na vila com uma interrogação amarela
#  acima da cabeça que dá a missão de matar os bandidos". Escolha dele: 2 acampamentos
#  de 3 bandidos.
#
#  Grava no MAPA VIVO, como as outras ferramentas da ilha:
#    • cada acampamento: fogueira no centro, toras de banco e 3 bandidos de sentinela num
#      círculo de 5 m, olhando para fora (peças `modelo` "bandido": no jogo viram o boneco
#      que luta vestido de bandido — `NinhoDeInimigo`);
#    • o Guarda da vila na praça, a 7 m de onde o jogador nasce, virado para lá.
#  Lugares escolhidos por varredura do mapa (08/10/2026): campo plano, seco, sem peça a
#  ≥ 19 m, longe de áreas de animais, ≥ 75 m da vila; conferidos em foto.
#  Troca SÓ as peças com prefixo `bandidos_` (rodar de novo não duplica), guarda uma
#  cópia do mapa antes (uma por versão) e NÃO grava se o arquivo mudou durante a
#  execução (outra frente editando o mapa).
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const GRUPO := "bandidos"
const PREFIXO := "bandidos_"
const ACAMPAMENTOS := [
	{"id": "norte", "centro": Vector2(56, -92), "giro": 20.0},
	{"id": "sul", "centro": Vector2(-20, 84), "giro": -35.0},
]
const RAIO := 5.0                      # bandidos em volta da fogueira
const GUARDA := {"posicao": Vector2(155.5, 13.9), "olha_para": Vector2(152, 20)}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	for id in ["bandido", "npc_missao_bandidos", "bonfire", "logs"]:
		if not bib.tem(id):
			push_error("falta na loja: %s (rode tools/importar_bandido_na_loja.gd e importar_npcs_na_loja.gd)" % id)
			quit(1)
			return
	var mapa: Dictionary = lido["mapa"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
	var copia := BACKUPS.path_join("baseplate_antes_bandidos_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)

	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with(PREFIXO):
			trocadas += 1
			continue
		pecas.append(p)
	var terrenos: Array[Dictionary] = []
	for p: Dictionary in pecas:
		if p["tipo"] == "terreno":
			terrenos.append(p)
	var grupos: Array = mapa["grupos"]
	if not grupos.any(func(g: Dictionary) -> bool: return g["id"] == GRUPO):
		grupos.append({"id": GRUPO, "pai": ""})

	var novas: Array[Dictionary] = []
	for a: Dictionary in ACAMPAMENTOS:
		var c: Vector2 = a["centro"]
		var giro: float = a["giro"]
		novas.append(_peca(bib, terrenos, "%s%s_fogueira" % [PREFIXO, a["id"]], "bonfire", c, giro, GRUPO))
		novas.append(_peca(bib, terrenos, "%s%s_toras" % [PREFIXO, a["id"]], "logs",
			c + Vector2(0, 3.0).rotated(deg_to_rad(-giro)), giro, GRUPO))
		for k in 3:
			var ang := deg_to_rad(giro + 90.0 + 120.0 * k)
			var fora := Vector2(cos(ang), sin(ang))
			var onde := c + fora * RAIO
			var yaw := rad_to_deg(atan2(-fora.x, -fora.y))      # −Z do modelo olhando para fora (sentinela)
			novas.append(_peca(bib, terrenos, "%s%s_%d" % [PREFIXO, a["id"], k + 1], "bandido", onde, yaw, GRUPO))
	var g_pos: Vector2 = GUARDA["posicao"]
	var para: Vector2 = (GUARDA["olha_para"] as Vector2) - g_pos
	novas.append(_peca(bib, terrenos, PREFIXO + "guarda_da_vila", "npc_missao_bandidos", g_pos,
		rad_to_deg(atan2(-para.x, -para.y)), "vila"))
	for p in novas:
		if p.is_empty():
			print("BANDIDOS recusado: peça fora do relevo (mapa NÃO gravado)")
			quit(1)
			return
		pecas.append(p)
		print("PECA %-30s %-20s em (%.1f, %.1f, %.1f) giro %.0f°" % [p["id"], p["modelo"], p["posicao"].x, p["posicao"].y,
			p["posicao"].z, p["rotacao_graus"].y])
	if FileAccess.get_file_as_string(MAPA) != original:
		print("BANDIDOS recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
		quit(1)
		return
	mapa["pecas"] = pecas
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("BANDIDOS %d peças (trocadas %d), grava=%s" % [novas.size(), trocadas, error_string(err)])
	quit(0 if err == OK else 1)


func _peca(bib: BibliotecaDeModelos, terrenos: Array[Dictionary], id: String, modelo: String, onde: Vector2,
		giro_graus: float, grupo: String) -> Dictionary:
	var chao := _chao(terrenos, onde)
	if is_nan(chao):
		return {}
	var tam := bib.tamanho_padrao(modelo)
	return {"id": id, "tipo": "modelo", "modelo": modelo, "grupo": grupo,
		"posicao": Vector3(onde.x, chao + tam.y * 0.5, onde.y), "rotacao_graus": Vector3(0, wrapf(giro_graus, -180.0, 180.0), 0),
		"tamanho": tam, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true}


## Y do chão do relevo em (x, z). NAN = fora.
func _chao(terrenos: Array[Dictionary], c: Vector2) -> float:
	for p in terrenos:
		var pos: Vector3 = p["posicao"]
		var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], c.x - pos.x, c.y - pos.z)
		if not is_nan(y):
			return pos.y + y
	return NAN
