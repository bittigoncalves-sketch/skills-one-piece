class_name PersonagensEastBlue
extends RefCounted
# ============================================================================
#  PERSONAGENS DO EAST BLUE NO MAPA (17/10/2026).
#
#  Quem é personagem: peça `modelo` cujo modelo da loja tem o comportamento
#  `mine_piece` (categoria "East Blue (Mine Piece)", registrada por
#  tools/mine_piece/registrar_na_loja.gd). No JOGO a peça some e o personagem vivo
#  (`PersonagemMinePiece`) nasce no chão dela, virado para onde ela estava virada — a
#  mesma regra dos NPCs e do ninho de inimigo. No "Testar" do editor a peça continua
#  modelo parado (o editor não pode perder o nó da peça).
#
#  O dono move, tira e põe personagens pelo editor de mapa, como qualquer peça.
# ============================================================================


static func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos) -> Array[PersonagemMinePiece]:
	var saida: Array[PersonagemMinePiece] = []
	if raiz == null or biblioteca == null:
		return saida
	for p: Dictionary in mapa.get("pecas", []):
		if p.get("tipo", "") != "modelo":
			continue
		var modelo := str(p.get("modelo", ""))
		if not biblioteca.tem(modelo) or biblioteca.comportamento_do_modelo(modelo) != DadosEastBlue.COMPORTAMENTO:
			continue
		var ficha := DadosEastBlue.ficha_do_modelo(modelo)
		if ficha.is_empty():
			push_warning("[PersonagensEastBlue] modelo sem ficha: " + modelo)
			continue
		var pers := PersonagemMinePiece.new()
		pers.montar(ficha, modelo)
		pers.name = "MP_" + String(p["id"])
		# Posição e giro ANTES de entrar na árvore (docs/erros.md, 16/09).
		pers.position = NinhoDeInimigo.pe_da_peca(p)
		pers.rotation.y = deg_to_rad((p["rotacao_graus"] as Vector3).y)
		pers.ponto_de_origem = pers.position
		pers.yaw_de_origem = pers.rotation.y
		var peca := raiz.get_node_or_null(NodePath(String(p["id"])))
		if peca != null:
			raiz.remove_child(peca)
			peca.queue_free()
		raiz.add_child(pers)
		saida.append(pers)
	return saida
