class_name SonsDasTecnicas
extends RefCounted
## Sons novos (24/11/2026) das logias do fluxo do mod: uma CARGA por fruta (ao apertar a tecla) e um DISPARO por técnica (ao soltar).
## Gerados por `tools/generate_logias_mod_audio.py` em `assets/mine_piece/frutas/logias_mod/sons/<fruta>_{carga,<numero>}.wav`.
## Só toca para quem tem arquivo: fruta sem som novo fica como o mod (sem erro).
const PASTA := "res://assets/mine_piece/frutas/logias_mod/sons/"


static func caminho(fruta_id: String, numero: int) -> String:
	var curto := fruta_id.get_slice("_", 0)
	return PASTA + curto + ("_carga" if numero == 0 else "_" + str(numero)) + ".wav"


static func carga(ator: Node3D, fruta_id: String) -> void:
	tocar(ator, caminho(fruta_id, 0), 0.8)


static func disparo(ator: Node3D, fruta_id: String, numero: int) -> void:
	tocar(ator, caminho(fruta_id, numero), 1.0)


static func tocar(ator: Node3D, arquivo: String, volume: float) -> void:
	if is_instance_valid(ator) and ResourceLoader.exists(arquivo):
		VfxFrutaMinePiece.som(ator, arquivo, ator.global_position, volume)
