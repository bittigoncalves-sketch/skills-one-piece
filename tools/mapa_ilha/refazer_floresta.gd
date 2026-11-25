extends SceneTree
## Exige entrada e saída explícitas. A aplicação ao mapa vivo ocorre após revisão.
const Floresta := preload("res://tools/mapa_ilha/floresta_da_loja.gd")
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Uso: -- <mapa de entrada> <mapa de saída>")
		quit(1)
		return
	var lido := MapaArquivo.carregar(args[0])
	if not lido.ok:
		push_error(str(lido.erros))
		quit(1)
		return
	var r := Floresta.new().refazer(lido.mapa, BibliotecaDeModelos.padrao())
	if not r.ok:
		push_error(r.erro)
		quit(1)
		return
	var err := MapaArquivo.salvar(args[1], r.mapa)
	print("FLORESTA removidas=%d novas=%d árvores=%d total=%d grava=%s" % [r.removidas, r.novas, r.get("arvores", 0), r.mapa.pecas.size(), error_string(err)])
	quit(0 if err == OK else 1)
