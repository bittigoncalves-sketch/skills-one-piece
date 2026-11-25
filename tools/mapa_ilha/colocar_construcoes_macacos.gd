extends SceneTree
# ============================================================================
#  CONSTRUÇÕES TEMÁTICAS, NPCs, PROPS E O GORILA-REI NA ILHA DOS MACACOS v2 (22/11/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_construcoes_macacos.gd [-- --saida=<caminho>]
#
#  Rodar DEPOIS de `gerar_ilha_dos_macacos.gd` e `gerar_floresta_macacos.gd` (e depois de `registrar_construcoes_macacos.gd` / `registrar_gorila_rei.gd`).
#  Troca só as peças `macacos_vila_*`, `macacos_sitio_*` e `macacos_gorila_*`. Layout em `layout_macacos.gd`; plano em docs/ILHA_DOS_MACACOS_V2_PLANO.md.
# ============================================================================
const Layout := preload("res://tools/mapa_ilha/layout_macacos.gd")
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const PREFIXOS := ["macacos_vila_", "macacos_sitio_", "macacos_gorila_"]
const CENTRO := Vector2(1500, 0)
const MEIA := 128.0
const DECK := 0.6

var _bib: BibliotecaDeModelos
var _terrenos: Array[Dictionary] = []
var _novas: Array[Dictionary] = []
var _contagem := {}
var _pecas: Array = []


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var saida := MAPA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	_bib = BibliotecaDeModelos.padrao()
	var mapa: Dictionary = lido["mapa"]
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		var id := String(p["id"])
		if PREFIXOS.any(func(pre: String) -> bool: return id.begins_with(pre)):
			trocadas += 1
			continue
		_pecas.append(p)
		if p["tipo"] == "terreno" and id.begins_with("macacos_relevo_"):
			_terrenos.append(p)
	if _terrenos.size() != 16:
		push_error("sem o relevo da ilha: rode gerar_ilha_dos_macacos.gd antes")
		quit(1)
		return
	_vila()
	_cais()
	_bananal()
	_curandeiro()
	_totens()
	_trono()
	_fruto_dourado()
	_pecas.append_array(_novas)
	var grupos: Array = []
	var meus := ["macacos_vila", "macacos_sitio", "macacos_gorila"]
	for g: Dictionary in mapa["grupos"]:
		if not meus.has(g["id"]):
			grupos.append(g)
	for g in meus:
		grupos.append({"id": g, "pai": "ilha_dos_macacos"})
	mapa["grupos"] = grupos
	mapa["pecas"] = _pecas
	var validado := MapaArquivo.validar(JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"], "pecas": mapa["pecas"], "grupos": mapa["grupos"]})))
	if not validado["ok"]:
		push_error("mapa gerado não valida: %s" % str(validado["erros"]).left(600))
		quit(1)
		return
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_construcoes_macacos_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			print("CONSTRUCOES_MACACOS recusado: o mapa mudou durante a execução — mapa NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("CONSTRUCOES_MACACOS %d peças (trocadas %d): %s -> %s (%s)" % [_novas.size(), trocadas, str(_contagem), saida, error_string(err)])
	quit(0 if err == OK else 1)


# ------------------------------------------------------------------ chão
func _chao(l: Vector2) -> float:
	var p := CENTRO + l
	for t in _terrenos:
		var pos: Vector3 = t["posicao"]
		var s: Vector3 = t["tamanho"]
		if absf(p.x - pos.x) <= s.x * 0.5 and absf(p.y - pos.z) <= s.z * 0.5:
			return pos.y + TerrenoDoMapa.altura_local(t["relevo"], s, p.x - pos.x, p.y - pos.z)
	return 0.0


## Chão sob a pegada: o MAIS ALTO dos 9 pontos (a base do modelo não pode entrar no morro; o pé de pedra do modelo cobre a folga).
func _chao_da_pegada(l: Vector2, meia: Vector2, yaw: float) -> float:
	var alto := -INF
	for fx in [-1.0, 0.0, 1.0]:
		for fz in [-1.0, 0.0, 1.0]:
			var d := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(fx * meia.x, 0, fz * meia.y)
			alto = maxf(alto, _chao(l + Vector2(d.x, d.z)))
	return alto


func _yaw_para(de: Vector2, para: Vector2) -> float:
	var d := para - de
	return rad_to_deg(atan2(d.x, d.y))


## Peça `modelo` com o pé do modelo (z = 0 do Blender) em `l` (local à ilha) sobre o chão (ou `y_chao`).
func _modelo(id: String, modelo: String, l: Vector2, yaw: float, grupo: String, colisao := true, y_chao := NAN) -> Dictionary:
	if not _bib.tem(modelo):
		push_error("falta no catálogo: " + modelo)
		quit(1)
		return {}
	var info := _bib.info(modelo)
	var tam := _bib.tamanho_padrao(modelo)
	var centro: Vector3 = info["centro"]
	var chao := y_chao if not is_nan(y_chao) else _chao_da_pegada(l, Vector2(tam.x, tam.z) * 0.35, yaw)
	var desloc := Basis(Vector3.UP, deg_to_rad(yaw)) * centro
	var peca := {"id": id, "tipo": "modelo", "modelo": modelo, "grupo": grupo,
		"posicao": Vector3(CENTRO.x + l.x + desloc.x, chao + centro.y, CENTRO.y + l.y + desloc.z), "tamanho": tam,
		"rotacao_graus": Vector3(0, yaw, 0), "cor": Color.WHITE, "material": "liso", "colisao": colisao and not _bib.atravessavel(modelo)}
	_novas.append(peca)
	return peca


## NPC com o pé no chão (a origem da peça é o centro do volume).
func _npc(id: String, modelo: String, l: Vector2, olhando: Vector2) -> void:
	var tam := _bib.tamanho_padrao(modelo)
	_novas.append({"id": id, "tipo": "modelo", "modelo": modelo, "grupo": "macacos_vila", "posicao": Vector3(CENTRO.x + l.x, _chao(l) + tam.y * 0.5, CENTRO.y + l.y),
		"tamanho": tam, "rotacao_graus": Vector3(0, _yaw_para(l, olhando), 0), "cor": Color.WHITE, "material": "liso", "colisao": false})


# ------------------------------------------------------------------ a vila
func _vila() -> void:
	var v := Layout.VILA
	_modelo("macacos_vila_portal", "macacos_portal", Vector2(-46, 0.5), 90.0, "macacos_vila")
	_modelo("macacos_vila_fogueira", "macacos_fogueira", v + Vector2(0, 4), 0.0, "macacos_vila")
	_modelo("macacos_vila_cabana_geppo", "macacos_cabana_geppo", Vector2(-4, -18), 0.0, "macacos_vila")
	var torre := Vector2(24, 16)
	var yaw_t := _yaw_para(torre, v)
	_modelo("macacos_vila_torre", "macacos_torre_vigia", torre, yaw_t, "macacos_vila")
	_modelo("macacos_vila_tenda_0", "macacos_tenda", Vector2(14, 14), _yaw_para(Vector2(14, 14), v), "macacos_vila")
	_modelo("macacos_vila_tenda_1", "macacos_tenda", Vector2(-20, 24), _yaw_para(Vector2(-20, 24), v), "macacos_vila")
	# NPCs de missão
	_npc("macacos_vila_npc_cozinheira", "npc_macaco_cozinheira", v + Vector2(-4, 8), v)
	var frente_torre := torre + Vector2(sin(deg_to_rad(yaw_t)), cos(deg_to_rad(yaw_t))) * 6.0
	_npc("macacos_vila_npc_vigia", "npc_macaco_vigia", frente_torre, torre)
	_contagem["vila"] = 8


func _cais() -> void:
	var t := _bib.tamanho_padrao("macacos_cais")
	var info := _bib.info("macacos_cais")
	var centro: Vector3 = info["centro"]
	# O cais avança para o mar (−X), com o piso a DECK m (mesma altura do porto). O piso do modelo está em z = 2,6 do Blender.
	var x := -MEIA - t.z * 0.5 - 2.0
	var origem_y := DECK - 2.6
	var desloc := Basis(Vector3.UP, deg_to_rad(90.0)) * centro
	_novas.append({"id": "macacos_vila_cais", "tipo": "modelo", "modelo": "macacos_cais", "grupo": "macacos_vila",
		"posicao": Vector3(CENTRO.x + x + desloc.x, origem_y + centro.y, CENTRO.y + desloc.z), "tamanho": t,
		"rotacao_graus": Vector3(0, 90.0, 0), "cor": Color.WHITE, "material": "liso", "colisao": true})
	_npc("macacos_vila_npc_pescador", "npc_macaco_pescador", Vector2(-121, 4.5), Vector2(-135, 0))
	_contagem["cais"] = 2


# ------------------------------------------------------------------ sítios
func _bananal() -> void:
	var c: Vector2 = Layout.SITIOS["bananal"]["centro"]
	var y: float = Layout.SITIOS["bananal"]["altura"]
	var yaw := _yaw_para(c, Layout.VILA)
	_modelo("macacos_sitio_altar", "macacos_altar_bananas", c, yaw, "macacos_sitio", true, y)
	for i in 8:
		var a := deg_to_rad(40.0 + i * 40.0)
		_modelo("macacos_sitio_bananeira_%d" % i, "macacos_bananeira", c + Vector2(cos(a), sin(a)) * 9.0, i * 47.0, "macacos_sitio", true, y)
	for i in 6:
		var a := deg_to_rad(20.0 + i * 60.0)
		_modelo("macacos_sitio_cacho_%d" % i, "macacos_cacho_banana", c + Vector2(cos(a), sin(a)) * 5.2, i * 61.0, "macacos_sitio", false, y)
	_contagem["bananal"] = 15


func _curandeiro() -> void:
	var c: Vector2 = Layout.SITIOS["curandeiro"]["centro"]
	var y: float = Layout.SITIOS["curandeiro"]["altura"]
	var yaw := _yaw_para(c, Layout.VILA)
	_modelo("macacos_sitio_cabana_curandeiro", "macacos_cabana_curandeiro", c + Vector2(0, 0), yaw, "macacos_sitio", true, y)
	var frente := c + Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw))) * 7.5
	_npc("macacos_vila_npc_curandeiro", "npc_macaco_curandeiro", frente, c)
	_contagem["curandeiro"] = 2


func _totens() -> void:
	var c: Vector2 = Layout.SITIOS["totens"]["centro"]
	var y: float = Layout.SITIOS["totens"]["altura"]
	var modelos := ["macacos_totem_alegre", "macacos_totem_guardiao", "macacos_totem_sabio", "macacos_totem_guardiao"]
	for i in 4:
		var a := deg_to_rad(45.0 + i * 90.0)
		var p := c + Vector2(cos(a), sin(a)) * 6.5
		_modelo("macacos_sitio_totem_%d" % i, modelos[i], p, _yaw_para(p, c), "macacos_sitio", true, y)
	_contagem["totens"] = 4


func _trono() -> void:
	var c: Vector2 = Layout.SITIOS["trono"]["centro"]
	var y: float = Layout.SITIOS["trono"]["altura"]
	_modelo("macacos_sitio_trono", "macacos_trono", c + Vector2(0, -15), 0.0, "macacos_sitio", true, y)
	for s in [-1.0, 1.0]:
		var p := c + Vector2(s * 14.0, 12.0)
		_modelo("macacos_sitio_guardiao_%d" % (0 if s < 0 else 1), "macacos_totem_guardiao", p, _yaw_para(p, c), "macacos_sitio", true, y)
	# O covil do Gorila-rei: a área em que ele vive (nunca sai; volta se o jogador sair). 46 m: a arena plana e a encosta.
	var tam := Vector3(46, 24, 46)
	_novas.append({"id": "macacos_gorila_covil", "tipo": "area_animais", "grupo": "macacos_gorila",
		"posicao": Vector3(CENTRO.x + c.x, y - 1.0 + tam.y * 0.5, CENTRO.y + c.y), "rotacao_graus": Vector3.ZERO, "tamanho": tam, "cor": Color("#e04040"),
		"material": "liso", "grade_celula": 4.0, "colisao": false, "especie": "gorila_rei", "quantidade": 1})
	_contagem["trono"] = 4


## O fruto dourado fica no topo das plataformas do Geppo, ao lado do baú.
func _fruto_dourado() -> void:
	for p: Dictionary in _pecas:
		if String(p["id"]) == "macacos_floresta_marca_do_bau_topo":
			var m: Vector3 = p["posicao"]
			var tam := _bib.tamanho_padrao("macacos_fruto_dourado")
			var centro: Vector3 = _bib.info("macacos_fruto_dourado")["centro"]
			_novas.append({"id": "macacos_sitio_fruto_dourado", "tipo": "modelo", "modelo": "macacos_fruto_dourado", "grupo": "macacos_sitio",
				"posicao": Vector3(m.x + 2.4, m.y - 0.05 + centro.y, m.z), "tamanho": tam, "rotacao_graus": Vector3.ZERO, "cor": Color.WHITE,
				"material": "liso", "colisao": false})
			_contagem["fruto"] = 1
			return
	push_warning("sem a marca do baú do topo: o fruto dourado não foi colocado")
