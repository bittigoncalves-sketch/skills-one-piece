extends RefCounted
## Deslocamentos importados dos clipes Bedrock. Restaura antes do animador calcular
## o próximo quadro, para nunca acumular offsets nem deixar membros fora do lugar.
var _anteriores: Dictionary = {}

func restaurar() -> void:
	for no in _anteriores:
		if is_instance_valid(no): no.position = _anteriores[no]
	_anteriores.clear()

## Duas fontes, somadas: `posicoes_mine_piece` (clipes Bedrock dos controladores antigos) e `posicoes_do_mod`
## (os clipes do JOGADOR do mod, `AnimacaoDoMod`).
func aplicar(ossos: Dictionary, corpo: Node) -> void:
	if corpo == null:
		return
	for chave in ["posicoes_mine_piece", "posicoes_do_mod"]:
		if not corpo.has_meta(chave):
			continue
		var posicoes: Dictionary = corpo.get_meta(chave)
		for papel in posicoes:
			if not ossos.has(papel): continue
			var no := ossos[papel] as Node3D
			if not _anteriores.has(no):
				_anteriores[no] = no.position
			no.position += posicoes[papel]
