extends SceneTree
const Recompensa := preload("res://src/historia/recompensa_mine_piece.gd")
func _init() -> void:
	for vida in [24.0, 100.0, 500.0, 2000.0, 10000.0]:
		print("FAMA vida=", vida, " -> ", Recompensa.xp_de_abate(vida))
	print("VIDA_DO_BANDIDO ", NinhoDeInimigo.VIDA_DO_BANDIDO, " fama ", Recompensa.xp_de_abate(float(NinhoDeInimigo.VIDA_DO_BANDIDO)))
	var p := ProgressaoDoPersonagem.new()
	print("XP do bandido (nível 1): ", p.previa_do_abate(Recompensa.xp_de_abate(float(NinhoDeInimigo.VIDA_DO_BANDIDO))), " ; xp p/ nível 2: ", p.xp_necessario())
	quit()
