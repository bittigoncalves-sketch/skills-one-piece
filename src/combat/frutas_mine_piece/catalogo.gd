class_name CatalogoFrutasMinePiece
extends RefCounted
## Só entra aqui fruta com executor nativo. O inventário de 39 origens não publica
## frutas automaticamente: nome/ícone não provam que uma técnica foi traduzida.
const OPE := "ope_ope_mine_piece"
const HIE := "hie_hie_mine_piece"
const MOKU := "moku_moku_mine_piece"
const PIKA := "pika_pika_mine_piece"
const NIKYU := "nikyu_nikyu_mine_piece"
## O Estilo de Combate Base (item "Luta"): não é fruta, mas usa o mesmo controlador. Mesmo id do kit antigo do Builder, para o `current_fruit_id` e os
## testes continuarem se entendendo; some da loja (`fora_da_loja`).
const LUTA := "estilo_de_combate_base"
## `substitui`: a versão antiga do Builder que esta tradução tira da loja (decisão do
## dono, 20/10/2026); save com a antiga comprada ou equipada passa a ter esta.
## Logias já refatoradas (técnicas em paralelo, sem efeito logia, sons próprios). Cada uma entra aqui ao fechar a refatoração
## e vai ao inventário de teste (`ModoHistoria`, F8 em `FerramentasDeTeste`). Ordem de trabalho: Hie → Moku → Pika → Goro → demais (as do fluxo do mod, ver docs/LOGIAS_REFATORACAO_CHECKPOINT.md).
## A Goro Goro tem controlador próprio (`GoroGoroMinePiece`, fora das FICHAS): entra pelo id e se testa em `test_goro_mine_piece`.
const REFATORADAS: Array[String] = [HIE, MOKU, PIKA, "goro_goro_mine_piece",
	# Logias do fluxo do mod (`ControladorFrutaDoMod` + `SessoesDoMod`), 24/11/2026: testes em `test_logias_do_mod_paralelas`.
	"mera_mera", "magu_magu", "suna_suna", "yami_yami", "mori_mori"]
const FICHAS := {
	OPE: {"nome": "Ope Ope (Mine Piece)", "icone": "res://assets/mine_piece/frutas/icones/ope_ope_mine_piece.png",
		"executor": "res://src/combat/frutas_mine_piece/ope.gd",
		"poses": "res://assets/mine_piece/frutas/ope/poses.json",
		"ciclo": [{"numero": 23, "nome": "Stone Throwing", "custo_mod": 100.0}]},
	HIE: {"nome": "Hie Hie (Mine Piece)", "icone": "res://assets/mine_piece/frutas/icones/hie_hie_mine_piece.png",
		"executor": "res://src/combat/frutas_mine_piece/hie.gd",
		"poses": "res://assets/mine_piece/frutas/hie/poses.json",
		"familia": "logia", "cor": Color(0.62, 0.88, 1.0), "substitui": "hie_hie_no_mi_mine_piece",
		# Refatorada em 24/11/2026: técnicas em PARALELO (cada uma na sua sessão e recarga) e sem o efeito logia (transformação/voo).
		"paralelo": true, "sem_logia": true,
		"particula_elemento": {"caminho": "res://assets/mine_piece/frutas/hie/particle_ice.png", "quadros": 12},
		"ciclo": [{"numero": 21, "nome": "Ice Block: Partisan", "custo_mod": 100.0, "recarga": 2.5},
			{"numero": 22, "nome": "Ice Block: Pheasant Beak", "custo_mod": 300.0, "recarga": 7.5},
			{"numero": 24, "nome": "Ice Ball", "custo_mod": 250.0, "recarga": 6.25},
			{"numero": 25, "nome": "Ice Age", "custo_mod": 600.0, "recarga": 15.0}]},
	MOKU: {"nome": "Moku Moku (Mine Piece)", "icone": "res://assets/mine_piece/frutas/icones/moku_moku_mine_piece.png",
		"executor": "res://src/combat/frutas_mine_piece/moku.gd",
		"poses": "res://assets/mine_piece/frutas/moku/poses.json",
		"familia": "logia", "cor": Color(0.9, 0.9, 0.92), "substitui": "moku_moku_no_mi_mine_piece",
		"paralelo": true, "sem_logia": true,   # refatorada em 24/11/2026, como a Hie
		"particula_elemento": {"caminho": "res://assets/mine_piece/frutas/moku/particle_big_smoke.png", "quadros": 12},
		"ciclo": [{"numero": 21, "nome": "White Fist", "custo_mod": 120.0, "recarga": 3.0},
			{"numero": 23, "nome": "White Vine", "custo_mod": 250.0, "recarga": 6.25},
			{"numero": 25, "nome": "White Launcher", "custo_mod": 250.0, "recarga": 6.25},
			{"numero": 30, "nome": "White Out", "custo_mod": 300.0, "recarga": 7.5}]},
	# A10 (30/10/2026): as cinco técnicas (21, 22, 25, 28 e a passiva 29) estão traduzidas; substitui a Nikyu do Builder (`mp_nikyu_*`), como a Moku.
	# A11 (30/10/2026): a Luta NATIVA, sem Builder. Z/X/C direto (`teclas_diretas`: tecla → número); recarga por técnica em segundos e custo simbólico
	# de energia (o mod não cobra nos socos). Valores de dano/empurrão em `Balance.MINE_PIECE_LUTA`; o gesto em `luta.gd`.
	LUTA: {"nome": "Estilo de Combate Base", "icone": "res://assets/ui/barra/luta.svg", "fora_da_loja": true,
		"executor": "res://src/combat/frutas_mine_piece/luta.gd",
		"poses": "res://assets/mine_piece/combate/poses.json",
		"teclas_diretas": {"Z": 1, "X": 2, "C": 3},
		"ciclo": [{"numero": 1, "nome": "Soco", "custo_mod": 2.0, "recarga": 0.65},
			{"numero": 2, "nome": "Soco pesado", "custo_mod": 4.0, "recarga": 1.5},
			{"numero": 3, "nome": "Sequência de socos", "custo_mod": 8.0, "recarga": 4.0}]},
	NIKYU: {"nome": "Nikyu Nikyu (Mine Piece)", "icone": "res://assets/mine_piece/frutas/icones/nikyu_nikyu_mine_piece.png",
		"executor": "res://src/combat/frutas_mine_piece/nikyu.gd",
		"poses": "res://assets/mine_piece/frutas/nikyu/poses.json", "substitui": "nikyu_nikyu_no_mi_mine_piece",
		"toque_duplo": 29,
		"ciclo": [{"numero": 21, "nome": "Pad Ho", "custo_mod": 50.0},
			{"numero": 22, "nome": "Ursus Shock", "custo_mod": 600.0},
			{"numero": 25, "nome": "Assault", "custo_mod": 200.0},
			{"numero": 28, "nome": "Kuma Punch", "custo_mod": 500.0}]},
	PIKA: {"nome": "Pika Pika (Mine Piece)", "icone": "res://assets/mine_piece/frutas/icones/pika_pika_mine_piece.png",
		"executor": "res://src/combat/frutas_mine_piece/pika.gd",
		"poses": "res://assets/mine_piece/frutas/pika/poses.json",
		"familia": "logia", "cor": Color(1.0, 0.92, 0.45), "substitui": "pika_pika_no_mi_mine_piece",
		"paralelo": true, "sem_logia": true,   # refatorada em 24/11/2026, como a Hie e a Moku
		"particula_elemento": {"caminho": "res://assets/mine_piece/frutas/pika/particle_light_small.png", "quadros": 5},
		"toque_duplo": 28,
		# A espada de luz (30): o item que a fruta põe no lugar dela. O corte da espada da
		# campanha vale o dano dela (estocada 26); a do mod vale 8.
		"espada": {"id": "amano_murakumo", "nome": "Ama no Murakumo Sword",
			"icone": "res://assets/mine_piece/frutas/pika/icone_espada_luz.png",
			"alcance_blocos": 3.0, "multiplicador": 8.0 / 26.0},
		"ciclo": [{"numero": 21, "nome": "Laser", "custo_mod": 150.0, "recarga": 3.75},
			{"numero": 22, "nome": "Amano-Iwato", "custo_mod": 600.0, "recarga": 15},
			{"numero": 24, "nome": "Yasakani Sacred Jewel", "custo_mod": 200.0, "recarga": 5},
			{"numero": 27, "nome": "Acceleration is Power!!!", "custo_mod": 300.0, "recarga": 7.5},
			{"numero": 29, "nome": "Yasakani Sacred Jewel", "custo_mod": 400.0, "recarga": 10},
			{"numero": 30, "nome": "Ama no Murakumo Sword", "custo_mod": 50.0, "recarga": 1.25}]},
}

static func contem(id: String) -> bool:
	return FICHAS.has(id)

## O id que vale hoje: a tradução que substituiu uma versão antiga, ou o próprio id.
static func atual(id: String) -> String:
	# Sem fruta continua sem fruta: ficha sem `substitui` (padrão "") casava com o id vazio
	# e todo save sem fruta carregava com a Ope (23/10/2026, `test_progressao`).
	if id.is_empty():
		return id
	for novo: String in FICHAS:
		if str(FICHAS[novo].get("substitui", "")) == id:
			return novo
	return id

static func substituida(id: String) -> bool:
	return atual(id) != id

static func ids() -> Array[String]:
	var saida: Array[String] = []
	for id: String in FICHAS:
		if not bool(FICHAS[id].get("em_porte", false)) and not bool(FICHAS[id].get("fora_da_loja", false)):
			saida.append(id)
	return saida

static func perfil(id: String) -> PerfilDeFrutas:
	if not contem(id):
		return null
	var p := PerfilDeFrutas.new()
	p.fruta = id
	p.regen_de_energia = PerfilDeFrutas.REGEN_DA_ARENA
	p.escala_de_dano = PerfilDeFrutas.ESCALA_DO_MOD
	p.fiel_ao_mod = true
	return p
