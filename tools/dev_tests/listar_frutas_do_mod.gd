extends SceneTree
## Imprime "IDS a b c" com as frutas só do mod (as que `varredura_frutas_do_mod` e a captura de visibilidade percorrem).
func _init() -> void:
	print("IDS ", " ".join(PerfilDeFrutas.frutas_so_do_mod()))
	quit()
