extends SceneTree
# ============================================================================
#  FUNDO DO MAR EM THREADS E COM CACHE (28/10/2026): a grade de alturas do relevo marinho levava ~10 s no mapa vivo.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_fundo_do_mar_cache.gd
#
#  Prova que o jeito rápido dá EXATAMENTE os mesmos números do jeito lento: (1) as threads (cada uma com a sua cópia do relevo)
#  contra a amostragem em série, em linhas espalhadas da grade; (2) o cache em disco contra o que as threads calcularam, número a
#  número; (3) a chave do cache muda quando um terreno muda e NÃO muda quando só um modelo muda. Lê o mapa vivo (só leitura) e usa uma
#  pasta de cache PRÓPRIA do teste (não toca o cache do jogo).
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func rodar() -> void:
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	if not lido["ok"]:
		print("mapa vivo inválido")
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var oceano_script: Script = FundoDoMar.OCEANO
	var bases: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return oceano_script.e_base(p))
	var mundo := Node3D.new()
	root.add_child(mundo)

	print("\n-- 1. threads × série --")
	const PASTA_DE_TESTE := "user://cache_do_teste_fundo"
	var m1 := FundoDoMar.preparar_por_ilha(mundo, mapa, bases, -0.65)
	m1.pasta_do_cache = PASTA_DE_TESTE
	m1.chave_do_cache = ""                      # sem cache: obriga a calcular
	m1.bloquear = true
	var t0 := Time.get_ticks_msec()
	m1.passo()                                  # a grade inteira, em threads
	var ms_threads := Time.get_ticks_msec() - t0
	ok(m1.origem == "threads", "calculou em threads (%d ms)" % ms_threads)
	var nx: int = m1._grade.nx
	var nz: int = m1._grade.nz
	ok(m1._alturas.size() == nx * nz and m1._mascaras.size() == nx * nz, "grade %d × %d completa" % [nx, nz])
	var serie := m1._relevo.duplicar()
	var iguais := true
	var amostradas := 0
	for j in range(0, nz, 37):                  # linhas espalhadas (inclui costa, plataforma, talude e mar aberto)
		var z: float = m1._grade.z0 + j * FundoDoMar.CELULA
		for i in range(0, nx, 3):
			var s := serie.amostra(m1._grade.x0 + i * FundoDoMar.CELULA, z)
			var k := j * nx + i
			if m1._alturas[k] != s.x or m1._mascaras[k] != Color(s.y, s.z, s.w):
				iguais = false
			amostradas += 1
	ok(iguais, "%d amostras em série dão EXATAMENTE os mesmos números das threads" % amostradas)

	print("\n-- 2. cache em disco × threads --")
	var placas: Array[Rect2] = []
	for g in FundoDoMar.agrupar(bases):
		placas.append(FundoDoMar.caixa_de(g))
	var terrenos: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return p.get("tipo") == "terreno")
	var chave := FundoDoMar._chave_do_cache(placas, -0.65, terrenos)
	m1.chave_do_cache = chave
	m1._gravar_cache()
	var m2 := FundoDoMar.preparar_por_ilha(mundo, mapa, bases, -0.65)
	m2.pasta_do_cache = PASTA_DE_TESTE
	m2.chave_do_cache = chave
	m2.bloquear = true
	var t1 := Time.get_ticks_msec()
	m2.passo()
	var ms_cache := Time.get_ticks_msec() - t1
	ok(m2.origem == "cache", "a segunda montagem leu do disco (%d ms, contra %d ms em threads)" % [ms_cache, ms_threads])
	ok(m2._alturas == m1._alturas, "alturas do cache = as calculadas, número a número (%d)" % m2._alturas.size())
	ok(m2._mascaras == m1._mascaras, "máscaras do cache = as calculadas, número a número")
	ok(ms_cache * 4 < ms_threads, "ler do disco é pelo menos 4× mais rápido")
	# Cache de outra grade (chave diferente) ou truncado é ignorado e recalculado.
	var m3 := FundoDoMar.preparar_por_ilha(mundo, mapa, bases, -0.65)
	m3.pasta_do_cache = PASTA_DE_TESTE
	m3.chave_do_cache = "chave_que_nao_existe"
	ok(not m3._ler_cache(), "chave diferente: sem cache")
	var caminho := m1._caminho_do_cache()
	var f := FileAccess.open(caminho, FileAccess.READ_WRITE)
	f.seek(f.get_length() / 2)
	f.store_buffer(PackedByteArray([1, 2, 3]))            # estraga o meio do arquivo
	f.close()
	var m4 := FundoDoMar.preparar_por_ilha(mundo, mapa, bases, -0.65)
	m4.pasta_do_cache = PASTA_DE_TESTE
	m4.chave_do_cache = chave
	ok(not m4._ler_cache() or m4._alturas != m1._alturas, "arquivo corrompido não é aceito como se estivesse certo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA_DE_TESTE))

	print("\n-- 3. a chave do cache --")
	var base := FundoDoMar._chave_do_cache(placas, -0.65, terrenos)
	ok(base == FundoDoMar._chave_do_cache(placas, -0.65, terrenos), "a chave é estável")
	var terrenos2: Array = terrenos.duplicate(true)
	terrenos2[0]["posicao"] = (terrenos2[0]["posicao"] as Vector3) + Vector3(0, 0.5, 0)
	ok(base != FundoDoMar._chave_do_cache(placas, -0.65, terrenos2), "mexer num TERRENO muda a chave (a altura da praia muda)")
	ok(base != FundoDoMar._chave_do_cache(placas, -0.5, terrenos), "mudar o nível do mar muda a chave")
	var outras: Array[Rect2] = placas.duplicate()
	outras[0] = outras[0].grow(1.0)
	ok(base != FundoDoMar._chave_do_cache(outras, -0.65, terrenos), "mudar uma ilha muda a chave")
	ok(base == FundoDoMar._chave_do_cache(placas, -0.65, terrenos), "e mexer num modelo/NPC (não está na chave) não a muda")

	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
