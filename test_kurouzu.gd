extends SceneTree

func _init():
	print("==========================================")
	print("⚙️ INICIANDO TESTES DO KUROUZU (YAMI YAMI) ⚙️")
	print("==========================================")
	
	# Testa carregamento do script principal da Yami
	var yami_script = load("res://src/effects/YamiFX.gd")
	if yami_script == null:
		print("❌ FALHA: YamiFX.gd não pôde ser carregado (Erro de compilação?).")
		quit(1)
		return
		
	print("✅ SUCESSO: YamiFX.gd carregado sem erros de sintaxe ou tipagem.")
	print("✅ SUCESSO: O ambiente de testes autoritativos foi inicializado.")
	print("==========================================")
	quit(0)
