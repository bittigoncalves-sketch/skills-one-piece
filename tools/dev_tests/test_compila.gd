extends SceneTree
## Carrega TODO .gd do projeto e reporta o que NAO COMPILA.
##
## Existe porque `--editor --quit` NAO detecta isso: ele reimporta assets e
## atualiza o cache de class_name, mas nao carrega os scripts. Um erro de
## sintaxe ou de identificador passa batido e o jogo quebra so em execucao —
## foi assim que uma edicao automatica minha quebrou o IceFX inteiro (a Ice Age
## parou de funcionar) enquanto o check de import dizia "0 erros".
##
##   godot --headless --path . --script tools/dev_tests/test_compila.gd
## ⚠️ LIMITE CONHECIDO DESTA FERRAMENTA (medido em 2026-08-11)
##
## `load()` devolver não-nulo NÃO prova que o script compilou: um script com erro
## de escopo às vezes volta como recurso mesmo assim. A versão anterior daqui
## contava só `== null` e dizia "0 falhas" enquanto o log tinha 18 erros —
## escondendo um `test_gomu2.gd` que fazia preload de uma cena inexistente.
##
## Agora a checagem é dupla: `null` OU `can_instantiate()` falso.
##
## E há RUÍDO ESPERADO que não é bug: script que usa AUTOLOAD por identificador
## (`GameFlow.x`, `AudioManager.y`) não compila em `godot -s`, porque ali o
## autoload existe na árvore mas não vira identificador — no jogo de verdade ele
## compila normalmente. Esses estão na lista de tolerados abaixo; qualquer OUTRO
## nome que apareça é bug de verdade.
const AUTOLOADS_TOLERADOS := [
	"GameFlow", "ServerManager", "ClientManager", "FruitNet", "ScreenFX",
	"AudioManager", "SoundLibrary",
]

func _init() -> void:
	var falhas: Array[String] = []
	for f in _gd("res://"):
		var r = load(f)
		if r == null:
			falhas.append(f + "  (load devolveu null)")
			continue
		if r is GDScript and not (r as GDScript).can_instantiate():
			# Pode ser ruído de autoload. Só acusa se o script NÃO mencionar
			# nenhum dos autoloads tolerados — aí a culpa é dele mesmo.
			var texto := FileAccess.get_file_as_string(f)
			var por_autoload := false
			for a in AUTOLOADS_TOLERADOS:
				if texto.find(a) >= 0:
					por_autoload = true
					break
			if not por_autoload:
				falhas.append(f + "  (nao instancia)")
	for x in falhas:
		print("  ❌ NAO COMPILA: ", x)
	print("scripts que nao compilam: ", falhas.size())
	quit(1 if falhas.size() > 0 else 0)
func _gd(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n in [".godot", "graphify-out", ".git"]: n = d.get_next(); continue
		var p := dir.path_join(n)
		if d.current_is_dir(): out.append_array(_gd(p))
		elif n.ends_with(".gd"): out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
