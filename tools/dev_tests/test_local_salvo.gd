extends SceneTree
# Save grava o último chão numa ilha (19/11/2026: sair na Ilha dos Macacos reabria na inicial).
#   godot --headless --path . --script tools/dev_tests/test_local_salvo.gd
const ARQUIVO := "user://test_local_salvo/progresso.json"
var _falhas := 0

func _ok(c: bool, m: String) -> void:
	print("  %s %s" % ["OK " if c else "FALHA", m])
	if not c: _falhas += 1

func _init() -> void:
	await process_frame
	var p := ProgressaoDoPersonagem.new()
	_ok(p.local_salvo.is_empty(), "save novo não tem local")
	p.local_salvo = {"ilha": ProgressaoDoPersonagem.Ilhas.MACACOS, "x": 12.5, "y": 3.0, "z": -40.0}
	_ok(p.salvar(ARQUIVO) == OK, "grava")
	var q := ProgressaoDoPersonagem.carregar(ARQUIVO)
	_ok(q.local_salvo.get("ilha") == ProgressaoDoPersonagem.Ilhas.MACACOS and is_equal_approx(q.local_salvo["x"], 12.5) and is_equal_approx(q.local_salvo["z"], -40.0), "volta idêntico")
	var d := p.para_dict()
	d["local_salvo"] = {"ilha": "ilha_que_nao_existe", "x": 1, "y": 1, "z": 1}
	_ok(ProgressaoDoPersonagem.de_dict(d).local_salvo.is_empty(), "ilha inventada é descartada")
	d["local_salvo"] = {"ilha": ProgressaoDoPersonagem.Ilhas.MACACOS, "x": 1e30, "y": 1, "z": 1}
	_ok(ProgressaoDoPersonagem.de_dict(d).local_salvo.is_empty(), "coordenada absurda é descartada")
	d["local_salvo"] = "lixo"
	_ok(ProgressaoDoPersonagem.de_dict(d).local_salvo.is_empty(), "tipo errado é descartado")
	p.reiniciar()
	_ok(p.local_salvo.is_empty(), "reiniciar limpa o local")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	print("===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)
