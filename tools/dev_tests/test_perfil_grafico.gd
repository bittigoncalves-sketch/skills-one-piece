extends SceneTree
## Perfil gráfico ECONOMIA (30/10/2026): sombra com 2 cascatas e objetos minúsculos escondidos; volta ao normal;
## automático pela bateria (simulada); escolha gravada no aparelho. Mapa/progresso exclusivos.
## ⚠️ Mexe em user://perfil_grafico.cfg: guarda o arquivo do dono e o devolve no fim.
const PROGRESSO := "user://teste_perfil_grafico_progresso.json"
var _falhas := 0
var _cfg_antes := ""
var _cfg_existia := false

func _init() -> void:
	call_deferred("_executar")

func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _cortados(raiz: Node) -> Array:
	var saida := []
	var pilha: Array[Node] = [raiz]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no.has_meta(PerfilGrafico.META_CORTADO):
			saida.append(no)
	return saida

func _executar() -> void:
	_cfg_existia = FileAccess.file_exists(PerfilGrafico.ARQUIVO)
	if _cfg_existia:
		_cfg_antes = FileAccess.get_file_as_string(PerfilGrafico.ARQUIVO)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = PROGRESSO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.NORMAL)
	root.get_node("GameFlow").start_story()
	await _quadros(100)
	var cena := current_scene
	var perfil: PerfilGrafico = cena.get_node_or_null("PerfilGrafico")
	var sol := cena.get_node("Sol") as DirectionalLight3D
	var raiz: Node = perfil.raiz_do_mapa if perfil != null else null
	_ok(perfil != null and raiz != null, "o Modo História cria o PerfilGrafico com a raiz do mapa")
	var mode_original := sol.directional_shadow_mode

	print("\n-- NORMAL: nada muda --")
	_ok(not perfil.economia and _cortados(raiz).is_empty(), "sem objetos cortados")
	_ok(sol.directional_shadow_mode == mode_original, "sombra como era")

	print("\n-- ECONOMIA manual --")
	# Um objeto pequeno e distante do tamanho de um "pomar": 0,3 m de diagonal.
	var pequeno := MeshInstance3D.new()
	pequeno.mesh = BoxMesh.new()
	(pequeno.mesh as BoxMesh).size = Vector3.ONE * 0.2
	pequeno.name = "ObjetoPequeno"
	var proprio := MeshInstance3D.new()
	proprio.mesh = BoxMesh.new()
	proprio.visibility_range_end = 77.0
	proprio.name = "ComAlcancePropio"
	raiz.add_child(pequeno)
	raiz.add_child(proprio)
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.ECONOMIA, self)
	_ok(perfil.economia, "economia ligada")
	_ok(sol.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "sol com 2 cascatas")
	var lua := cena.get_node_or_null("Lua") as DirectionalLight3D
	_ok(lua == null or lua.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "lua com 2 cascatas")
	var k := perfil._pixels_por_metro_unitario() / PerfilGrafico.PIXELS_MINIMOS
	var diag := (pequeno.get_aabb().size * pequeno.global_transform.basis.get_scale().abs()).length()
	_ok(pequeno.has_meta(PerfilGrafico.META_CORTADO) and is_equal_approx(pequeno.visibility_range_end, maxf(diag * k, PerfilGrafico.ALCANCE_MINIMO)),
		"objeto de %.2f m ganha alcance = max(diagonal × %.1f, 30) = %.1f m" % [diag, k, pequeno.visibility_range_end])
	_ok(proprio.visibility_range_end == 77.0 and not proprio.has_meta(PerfilGrafico.META_CORTADO), "quem já tem alcance próprio não é mexido")
	var piso := cortados_minimos(raiz)
	_ok(piso >= PerfilGrafico.ALCANCE_MINIMO - 0.001, "nenhum alcance abaixo do mínimo de %.0f m (menor: %.1f)" % [PerfilGrafico.ALCANCE_MINIMO, piso])

	print("\n-- objetos que chegam depois (ilha ligada) --")
	var novo := MeshInstance3D.new()
	novo.mesh = BoxMesh.new()
	novo.name = "ChegouDepois"
	raiz.add_child(novo)
	_ok(not novo.has_meta(PerfilGrafico.META_CORTADO), "antes de cobrir, não tem alcance")
	perfil.cobrir(raiz)
	_ok(novo.has_meta(PerfilGrafico.META_CORTADO), "cobrir() alcança o que chegou depois")

	print("\n-- volta ao NORMAL --")
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.NORMAL, self)
	_ok(not perfil.economia and _cortados(raiz).is_empty(), "alcances devolvidos")
	_ok(pequeno.visibility_range_end == 0.0 and proprio.visibility_range_end == 77.0, "o do próprio objeto continua; o nosso zerou")
	_ok(sol.directional_shadow_mode == mode_original, "sombra do sol volta ao modo de antes (%d)" % mode_original)

	print("\n-- AUTOMÁTICO pela bateria (simulada) --")
	var bateria := [false]
	perfil.na_bateria = func() -> bool: return bateria[0]
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.AUTO, self)
	_ok(not perfil.economia, "em headless o automático não liga mesmo na bateria (guarda dos testes)")
	perfil.respeitar_headless = false
	perfil.reavaliar()
	_ok(not perfil.economia, "tomada: normal")
	bateria[0] = true
	perfil.reavaliar()
	_ok(perfil.economia and sol.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "bateria: economia")
	bateria[0] = false
	perfil.reavaliar()
	_ok(not perfil.economia and sol.directional_shadow_mode == mode_original, "voltou à tomada: normal")

	print("\n-- escolha do aparelho --")
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.ECONOMIA)
	var cfg := ConfigFile.new()
	_ok(cfg.load(PerfilGrafico.ARQUIVO) == OK and int(cfg.get_value("grafico", "modo", -1)) == PerfilGrafico.Modo.ECONOMIA, "gravada em user://perfil_grafico.cfg")
	PerfilGrafico.definir_modo(PerfilGrafico.Modo.NORMAL, self)

	print("\n-- janela do M --")
	var hud = cena.get_node("HistoriaHud")
	var seletor := hud.central().find_child("Graficos", true, false) as OptionButton
	_ok(seletor != null and seletor.item_count == 3, "a janela Aparência tem o seletor Gráficos (Automático/Normal/Economia)")
	seletor.item_selected.emit(2)
	_ok(PerfilGrafico.modo == PerfilGrafico.Modo.ECONOMIA and perfil.economia, "escolher Economia no seletor liga o modo")
	seletor.item_selected.emit(1)
	_ok(not perfil.economia, "escolher Normal desliga")

	# devolve o arquivo do dono
	if _cfg_existia:
		var f := FileAccess.open(PerfilGrafico.ARQUIVO, FileAccess.WRITE)
		f.store_string(_cfg_antes)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfilGrafico.ARQUIVO))
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)

func cortados_minimos(raiz: Node) -> float:
	var menor := INF
	for no in _cortados(raiz):
		menor = minf(menor, (no as GeometryInstance3D).visibility_range_end)
	return menor
