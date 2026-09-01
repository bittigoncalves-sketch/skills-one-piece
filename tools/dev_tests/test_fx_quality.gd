extends SceneTree

func _init() -> void:
	var q := preload("res://src/effects/FxQuality.gd")
	assert(is_equal_approx(float(q.FATORES["pc"]["hero"]), 1.0))
	assert(float(q.FATORES["celular"]["hero"]) < float(q.FATORES["celular"]["padrao"]))
	assert(float(q.FATORES["celular"]["padrao"]) < float(q.FATORES["tablet"]["padrao"]))
	assert(q.quantidade(100, "padrao") >= 1)
	print("[OK] perfis de qualidade de VFX preservam essencial e reduzem camadas secundárias")
	quit()
