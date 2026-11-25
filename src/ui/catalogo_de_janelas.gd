class_name CatalogoDeJanelas
extends RefCounted
# ============================================================================
#  CATÁLOGO DE JANELAS — as janelas do Modo História que o EDITOR DE JANELAS lista
#  e sabe montar fora do jogo, com dados de EXEMPLO (05/10/2026).
#
#  Decisão do dono: as janelas do Modo História. Cada uma é montada como a
#  `HistoriaHud` monta (mesma classe, mesmo nome, mesma âncora), aberta e cheia de
#  dado fictício para dar o que editar. O id é o mesmo que a janela usa no jogo para
#  ler o layout (`ID_DO_LAYOUT` de cada classe).
#
#  Janela nova = uma linha em `JANELAS` + um ramo em `criar`, e a classe chama
#  `LayoutDeJanelas.aplicar` depois de se montar.
# ============================================================================

const JANELAS := [
	{"id": "inventario", "nome": "Itens da mochila (painel da aba MOCHILA)"},
	{"id": "status", "nome": "Status (M)"},
	{"id": "loja", "nome": "Loja dos NPCs (E)"},
	{"id": "barra", "nome": "Barra de itens (1–6)"},
	{"id": "tecnicas", "nome": "Menu de técnicas"},
	{"id": "vida_energia", "nome": "Vida e energia"},
	{"id": "pesca", "nome": "Medidor da pesca"},
	{"id": "pets", "nome": "Menu de pets (aba do M)"},
	{"id": "ferramentas", "nome": "Ferramentas de teste (F8)"},
]
const JOGADOR := "res://src/ui/jogador_de_exemplo.gd"


static func ids() -> Array[String]:
	var saida: Array[String] = []
	for j in JANELAS:
		saida.append(str(j["id"]))
	return saida


static func nome(id: String) -> String:
	for j in JANELAS:
		if j["id"] == id:
			return str(j["nome"])
	return id


## Um progresso de mentira com um pouco de tudo (fruta, vara, peixes, frutas, moedas).
static func progresso_de_exemplo() -> ProgressaoDoPersonagem:
	var p := ProgressaoDoPersonagem.new()
	p.comer_fruta("rocket")
	p.ganhar_equipamento("vara_de_pesca")
	p.equipar_vara(true)
	p.ativar_item("fruta")
	p.guardar_item_de_pesca("tuna", 3)
	p.guardar_item_de_pesca("koi", 1)
	p.ganhar_fruta_do_pomar("fruta_maca", 4)
	p.receber_fruta("mera_mera")
	p.ganhar_ouro(12)
	return p


## Monta a janela `id` dentro de `raiz` (a tela de 1280×720 do editor) e a devolve
## aberta, com o layout salvo já aplicado. `apoio` guarda os nós de exemplo que a
## janela precisa (jogador, pescaria, NPC) — o editor os libera junto.
static func criar(id: String, raiz: Control, apoio: Node, bib: BibliotecaDeModelos) -> Control:
	var prog := progresso_de_exemplo()
	var jogador: Node = load(JOGADOR).new()
	jogador.name = "JogadorDeExemplo"
	apoio.add_child(jogador)
	var janela: Control = null
	match id:
		"inventario":
			var inv := InventarioDaHistoria.new()
			inv.name = "Inventario"
			raiz.add_child(inv)
			inv.ligar(prog, null, null)
			inv.visible = true
			inv.mostrar_aba("frutas")
			janela = inv
		"status":
			var st := JanelaDeStatus.new()
			st.name = "JanelaDeStatus"
			raiz.add_child(st)
			st.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
			st.ligar(prog)
			st.visible = true
			st.abrir(null)
			janela = st
		"loja":
			var lj := JanelaDeLoja.new()
			lj.name = "JanelaDeLoja"
			raiz.add_child(lj)
			lj.ligar(prog, bib)
			var npc := NpcDaIlha.new()
			npc.tipo = "npc_pescador"
			apoio.add_child(npc)
			lj.abrir(npc)
			janela = lj
		"barra":
			var br := BarraDeItensHud.new()
			br.name = "BarraDeItens"
			raiz.add_child(br)
			br.ligar(prog)
			janela = br
		"tecnicas":
			jogador.set("perfil_de_frutas", load("res://src/historia/frutas/rocket.tres"))
			var tc := TecnicasHud.new()
			tc.name = "Tecnicas"
			raiz.add_child(tc)
			tc.atualizar(jogador, true)
			janela = tc
		"vida_energia":
			var ve := VidaEnergiaHud.new()
			ve.name = "VidaEnergia"
			raiz.add_child(ve)
			ve.atualizar(jogador)
			janela = ve
		"pesca":
			var pesca := Pescaria.new()
			pesca.name = "PescariaDeExemplo"
			apoio.add_child(pesca)
			pesca.set_physics_process(false)
			pesca.set_process(false)
			pesca.estado = Pescaria.Estado.BRIGANDO
			pesca.tensao = TensaoDaLinha.new("raro", 7)
			pesca.tensao.tensao = 0.58
			pesca.tensao.progresso = 0.45
			var ph := PescaHud.new()
			ph.name = "PescaHud"
			ph.pescaria = pesca
			raiz.add_child(ph)
			ph.visible = true
			janela = ph
		"pets":
			var mp := MenuDeComportamento.new()
			mp.name = "MenuDeComportamento"
			raiz.add_child(mp)
			mp.abrir(jogador)
			janela = mp
		"ferramentas":
			var ft := FerramentasDeTeste.new()
			ft.name = "FerramentasDeTeste"
			raiz.add_child(ft)
			ft.ligar(prog)
			ft.visible = true
			ft.posicionar()
			janela = ft
	if janela != null:
		janela.set_meta("id_do_layout", id)
		LayoutDeJanelas.aplicar(id, janela)
	return janela
