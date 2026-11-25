extends SceneTree
## Publica exclusivamente o novo kit desarmado; não registra nada na loja de assets.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[0] if args.size() > 0 else "res://mapas/skills"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var casos := [
		["Z", "mp_luta_soco_z", "Soco", 0.5, 0.65, 2.0, "Pressionar"],
		["X", "mp_luta_pesado_x", "Soco pesado", 2.1, 1.5, 4.0, "Sustentar"],
		["C", "mp_luta_sequencia_c", "Sequência de socos", 3.1, 4.0, 8.0, "Sustentar"],
	]
	var base: Dictionary = preload("res://src/skills_builder/dados_skill.gd").novo()
	base.identificacao.merge({"fruta": KitDoBuilder.ID_ESTILO_BASE, "dono": "Jogador"}, true)
	var teclas := {}
	for c in casos:
		var s := base.duplicate(true)
		s.identificacao.merge({"id": c[1], "nome": c[2], "descricao": "Combate desarmado do Mine Piece v14; poses e impacto importados diretamente do mod."}, true)
		s.ativacao.merge({"tecla": c[0], "modo": c[6], "repetir": false, "andar_segurando": true}, true)
		s.condicoes.merge({"exige_alvo": false, "exige_chao": false, "vida_minima": 0.0, "nivel_minimo": 1}, true)
		s.configuracoes.merge({"duracao": c[3], "recarga": c[4], "custo": c[5], "alcance": 5.5,
			"intervalo_depois": {"Z": 0.5, "X": 0.85, "C": 1.75}[c[0]]}, true)
		s.dano.valor = Balance.MINE_PIECE_LUTA[{"Z": "soco", "X": "pesado", "C": "rajada"}[c[0]]].dano
		s.eventos = []
		s.poses = []
		s.projeteis.modelo = ""
		s.transformacao.modelo = ""
		var f := FileAccess.open(pasta.path_join(c[1] + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(s, "\t") + "\n")
		teclas[c[0]] = c[1]
	var caminho := pasta.path_join("frutas.json")
	var catalogo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho)) if FileAccess.file_exists(caminho) else {
		"formato": "skills-one-piece/frutas-builder", "versao": 1, "frutas": []}
	if not catalogo.frutas.any(func(f): return f.id == KitDoBuilder.ID_ESTILO_BASE):
		catalogo.frutas.append({"id": KitDoBuilder.ID_ESTILO_BASE, "nome": "Estilo de Combate Base", "estilo": true, "cor": "#bfe6ff"})
	for fruta in catalogo.frutas:
		if fruta.id == KitDoBuilder.ID_ESTILO_BASE:
			fruta.teclas = teclas
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	f.store_string(JSON.stringify(catalogo, "\t") + "\n")
	print("Kit Luta publicado: Z/X/C Mine Piece")
	quit()
