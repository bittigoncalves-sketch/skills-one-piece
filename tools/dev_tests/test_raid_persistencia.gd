extends SceneTree
## REGRESSÃO (10/11/2026): "ao fechar e reabrir o jogo o avanço das raids reseta". O save guardava os estágios vencidos, mas o JSON os devolve como
## `1.0` e `[1.0].has(1)` é falso em Godot: a raid achava que nada fora vencido. Só o menu (resetar personagem) deve zerar.
##   godot --headless --path . --script tools/dev_tests/test_raid_persistencia.gd
const ARQ := "user://test_raid_persistencia.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _init() -> void:
	var Raid := preload("res://src/historia/raid/raid.gd")
	var p := ProgressaoDoPersonagem.new()
	p.gravar_dados("raids", {"east_blue": [1, 2]})
	var r := Raid.new()
	r.progressao = p
	ok(r.proximo_estagio("east_blue") == 3, "com 1 e 2 vencidos a bandeira chama o 3 (%d)" % r.proximo_estagio("east_blue"))
	# fechar e reabrir o jogo: grava em disco e carrega de novo (os números voltam como float)
	ok(p.salvar(ARQ) == OK, "salvou o progresso")
	var q := ProgressaoDoPersonagem.carregar(ARQ)
	var r2 := Raid.new()
	r2.progressao = q
	ok(r2.vencidos("east_blue") == [1, 2], "estágios vencidos voltam inteiros do disco (%s)" % str(r2.vencidos("east_blue")))
	ok(r2.proximo_estagio("east_blue") == 3, "depois de reabrir o jogo a raid segue no estágio 3 (%d)" % r2.proximo_estagio("east_blue"))
	# resetar o personagem pelo menu é o único que zera
	var novo := ProgressaoDoPersonagem.new()
	r2.progressao = novo
	ok(r2.proximo_estagio("east_blue") == 1, "personagem novo volta ao estágio 1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQ))
	print("test_raid_persistencia: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
