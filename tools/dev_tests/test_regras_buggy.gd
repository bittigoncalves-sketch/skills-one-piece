extends SceneTree
# Regras do desafio do Buggy (21/11/2026): estado, XP, bloqueio do nível 7, idempotência e save/load. Rodar:
#   godot --headless --path . --script tools/dev_tests/test_regras_buggy.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _novo_com_treino() -> ProgressaoDoPersonagem:
	var p := ProgressaoDoPersonagem.new()
	p.aceitar_missao("treino"); p.contar_abate("treino"); p.entregar_missao("treino")
	return p

func _init() -> void:
	await process_frame
	print("\n===== REGRAS DO BUGGY =====")
	var R := RegrasDoDesafioBuggy
	var p0 := ProgressaoDoPersonagem.new()
	ok("sem treino entregue a cena NÃO toca", not R.deve_chegar(p0))
	var p := _novo_com_treino()
	ok("treino entregue: a cena deve tocar", R.deve_chegar(p))
	ok("marcar_chegada funciona", R.marcar_chegada(p) and R.fase(p) == R.CHEGOU)
	ok("e é idempotente (2ª vez não faz nada)", not R.marcar_chegada(p))
	ok("a cena não toca de novo", not R.deve_chegar(p))
	ok("missão dos copos aceita", p.estado_da_missao(R.MISSAO_COPOS) == "aceita")
	ok("missão do evento NÃO é oferecida a NPC", Missoes_proximas(p).is_empty())
	# acerto
	var xp0 := p.xp; var n0 := p.nivel
	var r := R.resolver_copos(p, true)
	ok("acerto: 4000 XP", int(r.get("xp", 0)) == 4000 and (p.nivel > n0 or p.xp != xp0))
	ok("acerto: missão entregue e fase copos_certo", p.estado_da_missao(R.MISSAO_COPOS) == "entregue" and R.fase(p) == R.COPOS_CERTO)
	var nivel_depois := p.nivel; var xp_depois := p.xp
	ok("2ª tentativa não paga de novo", R.resolver_copos(p, true).is_empty() and p.nivel == nivel_depois and p.xp == xp_depois)
	# erro
	var e := _novo_com_treino(); R.marcar_chegada(e)
	var xp_e := e.xp
	var re := R.resolver_copos(e, false)
	ok("erro: sem XP e a fase vai direto a aceitou (missão da luta automática)", int(re.get("xp", -1)) == 0 and e.xp == xp_e and R.fase(e) == R.ACEITOU)
	ok("erro: a missão dos copos some da lista", e.estado_da_missao(R.MISSAO_COPOS) == "entregue")
	ok("erro: uma só tentativa (acertar depois não vale)", R.resolver_copos(e, true).is_empty() and e.xp == xp_e)
	ok("erro: a missão da luta já está em andamento", e.estado_da_missao(R.MISSAO_LUTA) == "aceita")
	ok("nível da luta é 3 (era 7)", R.NIVEL_DA_LUTA == 3 and R.NIVEL_DA_LUTA == RegrasDoTreino.NIVEL_LIMITE)
	e.nivel = 1
	ok("nível 1: deve treinar; a luta NÃO está disponível", R.deve_treinar(e) and not R.luta_disponivel(e) and R.luta_bloqueada(e) and not R.liberar_luta(e))
	e.nivel = 2
	ok("nível 2 ainda treina", R.deve_treinar(e) and not R.luta_disponivel(e))
	e.nivel = 3
	ok("nível 3: a luta fica disponível e o aviso sai UMA vez", R.luta_disponivel(e) and not R.deve_treinar(e) and R.liberar_luta(e) and not R.liberar_luta(e))
	# save antigo parado na pergunta "proteger a vila?"
	var c := _novo_com_treino(); R.marcar_chegada(c)
	R._gravar(c, R.COPOS_ERRADO)
	ok("save antigo em copos_errado: ainda sem a missão", c.estado_da_missao(R.MISSAO_LUTA) == "disponivel")
	R.migrar(c)
	ok("migrar leva a aceitou com a missão em andamento", R.fase(c) == R.ACEITOU and c.estado_da_missao(R.MISSAO_LUTA) == "aceita")
	var r2 := _novo_com_treino(); R.marcar_chegada(r2)
	R._gravar(r2, R.RECUSOU)
	R.migrar(r2)
	ok("migrar também resolve o save que tinha recusado", R.fase(r2) == R.ACEITOU and r2.estado_da_missao(R.MISSAO_LUTA) == "aceita")
	ok("migrar é idempotente", not R.migrar(c) or R.fase(c) == R.ACEITOU)
	ok("quem acertou os copos não ganha a missão da luta", R.fase(p) == R.COPOS_CERTO and p.estado_da_missao(R.MISSAO_LUTA) == "disponivel")
	# save/load
	var caminho := "user://teste_regras_buggy.json"
	e.salvar(caminho)
	var l := ProgressaoDoPersonagem.carregar(caminho)
	ok("save/load preserva a fase e a missão da luta", l != null and R.fase(l) == R.ACEITOU and l.estado_da_missao(R.MISSAO_LUTA) == "aceita" and l.estado_da_missao(R.MISSAO_COPOS) == "entregue")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func Missoes_proximas(p) -> Array:
	return preload("res://src/historia/missoes/missoes.gd").proximas(p)
