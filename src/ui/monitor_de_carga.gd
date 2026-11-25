class_name MonitorDeCarga
extends RefCounted
# ============================================================================
#  MONITOR DE CARGA (28/10/2026). Pedido do dono: "monitoramento do que carrega quando se inicia o jogo" e "uma tela de
#  carregamento quando se inicia o modo história — quero ver o que está sendo carregado".
#
#  Duas coisas num registro só (estático, sem autoload: funciona em `--script` e não depende de cena):
#    • MARCOS DA INICIALIZAÇÃO DO JOGO: cada autoload/menu que diz "estou pronto" (`marco`), com o tempo desde que o motor
#      começou. Vai para o console e para `user://carga/inicio_do_jogo.txt`.
#    • UMA CARGA (hoje: o Modo História): etapas com duração (`fase`), recursos que custaram carregar (`recurso`: modelos 3D
#      principalmente), e um retrato do processo (nós, objetos, memória). `terminar` imprime o resumo e grava
#      `user://carga/ultima_carga.txt`. Se houver `TelaDeCarregamento`, ela mostra tudo isso ao vivo.
#
#  Como a carga é síncrona dentro de um `_ready`, a tela só atualiza se a carga devolver o quadro entre as etapas
#  (`passo`). Sem janela real (headless/testes) `passo` não espera nada: o comportamento é o de antes, só mede.
# ============================================================================

const PASTA_DO_LOG := "user://carga"
const ESTIMATIVA_DE_ETAPAS := 28          # só para a barra; a carga real pode ter mais ou menos

static var marcos: Array[Dictionary] = []
static var etapas: Array[Dictionary] = []
static var recursos: Array[Dictionary] = []
static var titulo := ""
static var ativo := false
static var tela: Node = null
## Testes: devolver o quadro entre as etapas e criar a tela mesmo sem janela.
static var forcar_passos := false
static var _t0 := 0
static var _numeros := RegEx.create_from_string("[0-9]+")
static var _etapa_atual := {}
static var _modelos_em_cache := 0
static var _fracao_da_etapa := 0.0


# ------------------------------------------------------------------ início do jogo
## Um marco da inicialização (autoload pronto, menu pronto...). `ms` = tempo desde que o MOTOR começou.
static func marco(nome: String) -> void:
	var ms := Time.get_ticks_msec()
	var antes := int(marcos.back().ms) if not marcos.is_empty() else 0
	marcos.append({"nome": nome, "ms": ms, "delta": ms - antes})
	print("[Carga] %6d ms  (+%d ms)  %s" % [ms, ms - antes, nome])
	_gravar_inicio()


static func _gravar_inicio() -> void:
	var linhas := PackedStringArray()
	linhas.append("INICIALIZAÇÃO DO JOGO — tempo desde que o motor começou")
	linhas.append("motor %s · %s · %s" % [Engine.get_version_info().string, DisplayServer.get_name(), RenderingServer.get_video_adapter_name()])
	linhas.append("memória estática %s · objetos %d · nós %d" % [_mb(Performance.get_monitor(Performance.MEMORY_STATIC)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	linhas.append("")
	for m in marcos:
		linhas.append("%7d ms   (+%5d ms)   %s" % [m.ms, m.delta, m.nome])
	_escrever("inicio_do_jogo.txt", "\n".join(linhas) + "\n")


# ------------------------------------------------------------------ uma carga
static func comecar(nome_da_carga: String) -> void:
	titulo = nome_da_carga
	etapas.clear()
	recursos.clear()
	_etapa_atual = {}
	_modelos_em_cache = 0
	_fracao_da_etapa = 0.0
	ativo = true
	_t0 = Time.get_ticks_msec()
	print("[Carga] ===== %s: início =====" % nome_da_carga)
	if _com_janela():
		tela = load("res://src/ui/tela_de_carregamento.gd").new()
		tela.titulo = nome_da_carga
		var arvore := Engine.get_main_loop() as SceneTree
		if arvore != null:
			arvore.root.add_child.call_deferred(tela)
	fase("Abrindo a cena", "lendo o arquivo da cena e os recursos que ela pede")


## Abre uma etapa (fecha a anterior). `detalhe` = o que ela vai fazer, para a tela.
static func fase(nome: String, detalhe := "") -> void:
	if not ativo:
		return
	_fechar_etapa()
	_fracao_da_etapa = 0.0
	_etapa_atual = {"nome": nome, "detalhe": detalhe, "ini": Time.get_ticks_msec(), "recursos": 0}
	if tela != null and is_instance_valid(tela):
		tela.etapa_aberta(nome, detalhe, etapas.size(), ESTIMATIVA_DE_ETAPAS)


## Abre a etapa E devolve o quadro (para a tela mostrar o nome ANTES do trabalho pesado começar). Corrotina: `await`.
static func etapa(nome: String, detalhe := "") -> void:
	fase(nome, detalhe)
	await passo()


## Andamento DENTRO da etapa atual (0 a 1): a barra anda entre uma etapa e outra.
static func andamento(feito: int, total: int, texto := "") -> void:
	if not ativo:
		return
	_fracao_da_etapa = clampf(float(feito) / maxf(float(total), 1.0), 0.0, 1.0)
	# Sub-etapas: cada texto de andamento diferente (sem o número entre parênteses) abre uma; assim o resumo mostra ONDE
	# dentro de uma etapa longa o tempo foi.
	if not texto.is_empty() and not _etapa_atual.is_empty():
		var chave := _numeros.sub(texto.get_slice("(", 0), "#", true).strip_edges()
		var subs: Array = _etapa_atual.get("sub", [])
		if subs.is_empty() or subs.back().nome != chave:
			subs.append({"nome": chave, "ini": Time.get_ticks_msec()})
			_etapa_atual["sub"] = subs
	if tela != null and is_instance_valid(tela):
		tela.andamento(_fracao_da_etapa, texto)


## Um recurso que custou carregar (modelo 3D...). `ms` = tempo, `bytes` = tamanho do arquivo (0 se não souber).
static func recurso(tipo: String, nome: String, ms: float, bytes := 0) -> void:
	if not ativo:
		return
	recursos.append({"tipo": tipo, "nome": nome, "ms": ms, "bytes": bytes, "etapa": str(_etapa_atual.get("nome", ""))})
	if not _etapa_atual.is_empty():
		_etapa_atual["recursos"] = int(_etapa_atual["recursos"]) + 1
	if tela != null and is_instance_valid(tela):
		tela.recurso_carregado(tipo, nome, ms, bytes)


## Um modelo que já estava em memória (só conta).
static func recurso_em_cache() -> void:
	if ativo:
		_modelos_em_cache += 1


static func _fechar_etapa() -> void:
	if _etapa_atual.is_empty():
		return
	var agora := Time.get_ticks_msec()
	_etapa_atual["ms"] = agora - int(_etapa_atual["ini"])
	var subs: Array = _etapa_atual.get("sub", [])
	for k in subs.size():
		subs[k]["ms"] = (int(subs[k + 1].ini) if k + 1 < subs.size() else agora) - int(subs[k].ini)
	etapas.append(_etapa_atual)
	if tela != null and is_instance_valid(tela):
		tela.etapa_fechada(_etapa_atual)
	_etapa_atual = {}


## Devolve o quadro para a tela redesenhar (a carga é síncrona). Só espera se houver janela de verdade.
static func passo() -> void:
	if not ativo or not _com_janela():
		return
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore != null:
		await arvore.process_frame


static func vai_aguardar() -> bool:
	return ativo and _com_janela()


static func terminar() -> void:
	if not ativo:
		return
	_fechar_etapa()
	ativo = false
	var total := Time.get_ticks_msec() - _t0
	var texto := resumo(total)
	print(texto)
	_escrever("ultima_carga.txt", texto + "\n")
	if tela != null and is_instance_valid(tela):
		tela.concluir(total)
	tela = null


static func resumo(total_ms: int) -> String:
	var l := PackedStringArray()
	l.append("CARGA — %s: %.2f s" % [titulo, total_ms / 1000.0])
	l.append("motor %s · memória estática %s · objetos %d · nós %d · texturas %s" % [Engine.get_version_info().string,
		_mb(Performance.get_monitor(Performance.MEMORY_STATIC)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _mb(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))])
	var modelos := recursos.filter(func(r: Dictionary) -> bool: return r.tipo == "modelo")
	var soma_modelos := 0.0
	var bytes := 0
	for r in modelos:
		soma_modelos += float(r.ms)
		bytes += int(r.bytes)
	l.append("modelos 3D: %d lidos do disco (%.0f ms no total, %s) · %d vezes já em memória" % [modelos.size(), soma_modelos, _mb(bytes), _modelos_em_cache])
	l.append("")
	l.append("ETAPAS (na ordem):")
	for e in etapas:
		l.append("  %6d ms  %s%s%s" % [e.ms, e.nome, "  — %s" % e.detalhe if not str(e.detalhe).is_empty() else "",
			"  [%d recursos]" % e.recursos if int(e.recursos) > 0 else ""])
		for sb: Dictionary in e.get("sub", []):
			l.append("            └ %6d ms  %s" % [sb.ms, sb.nome])
	var lentas := etapas.duplicate()
	lentas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
	l.append("")
	l.append("AS 5 ETAPAS MAIS LENTAS:")
	for e in lentas.slice(0, 5):
		l.append("  %6d ms  %s  (%.0f %% da carga)" % [e.ms, e.nome, 100.0 * float(e.ms) / maxf(float(total_ms), 1.0)])
	var pesados := modelos.duplicate()
	pesados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
	l.append("")
	l.append("OS 10 MODELOS MAIS LENTOS DE LER:")
	for r in pesados.slice(0, 10):
		l.append("  %6.0f ms  %-34s %s  (etapa: %s)" % [r.ms, r.nome, _mb(r.bytes), r.etapa])
	return "\n".join(l)


# ------------------------------------------------------------------ auxiliares
static func tempo_decorrido_ms() -> int:
	return Time.get_ticks_msec() - _t0 if ativo else 0


static func modelos_lidos() -> int:
	return recursos.filter(func(r: Dictionary) -> bool: return r.tipo == "modelo").size()


static func modelos_em_cache() -> int:
	return _modelos_em_cache


static func _com_janela() -> bool:
	return forcar_passos or DisplayServer.get_name() != "headless"


static func _mb(bytes: Variant) -> String:
	return "%.1f MB" % (float(bytes) / 1048576.0)


static func _escrever(arquivo: String, texto: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA_DO_LOG))
	var f := FileAccess.open(PASTA_DO_LOG.path_join(arquivo), FileAccess.WRITE)
	if f != null:
		f.store_string(texto)
		f.close()
