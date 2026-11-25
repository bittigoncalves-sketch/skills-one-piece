class_name VisualDeMorador
extends RefCounted
# ============================================================================
#  VISUAL DOS MORADORES (21/11/2026) — os NPCs da vila no corpo em CAIXAS do Minecraft (o mesmo do jogador, `corpo_historia.gd`), do TAMANHO DO JOGADOR (escala 1,0).
#  A ficha do NPC (`NpcDaIlha.FICHAS`) guarda nome, `capa`, `calca` e a loja; AQUI ficam corpo, tom de pele e cabelo/barba por tipo — cabelo e barba vêm do catálogo da
#  campanha (`aparencia_historia.gd`), então a mesma peça do editor de personagem serve. Roupa: o peito/abdome/manga ganham a `capa` e coxa/canela a `calca` da ficha.
#  Quem tem `rig` (Barba Negra) ou `corpo` na ficha (o instrutor, com `vestir` próprio) NÃO passa por aqui.
#  GATILHO: morador com roupa de catálogo (kimono, pirata…) → pôr `roupa` no dicionário de aparência e não tingir (hoje só cor lisa, 1 NPC = 1 linha).
# ============================================================================
const APARENCIAS := {
	"npc_comida": {"corpo": "masculino", "tom": "claro", "aparencia": {"cabelo": "careca", "acc_rosto": "barba_curta"}},
	"npc_ferreiro": {"corpo": "masculino", "tom": "escuro", "aparencia": {"cabelo": "careca", "acc_rosto": "barba_cheia_bigode"}},
	"npc_pescador": {"corpo": "masculino", "tom": "medio", "aparencia": {"cabelo": "curto", "cor_cabelo": "castanho", "acc_cabeca": "chapeu_palha_verao"}},
	"npc_domador": {"corpo": "masculino", "tom": "medio", "aparencia": {"cabelo": "espetado", "cor_cabelo": "ruivo"}},
	"npc_vendedor_frutas": {"corpo": "feminino", "tom": "claro", "aparencia": {"cabelo": "cabelo_rabo_cavalo_laco", "cor_cabelo": "preto"}},
	"npc_corrida": {"corpo": "masculino", "tom": "medio", "aparencia": {"cabelo": "cabelo_spiky_curto", "cor_cabelo": "loiro"}},
	"npc_vendedor_barcos": {"corpo": "masculino", "tom": "claro", "aparencia": {"cabelo": "curto", "cor_cabelo": "branco", "acc_rosto": "barba_curta"}},
	"npc_mestre_geppo": {"corpo": "masculino", "tom": "escuro", "aparencia": {"cabelo": "cabelo_crespo_curto", "cor_cabelo": "castanho"}},
	"npc_missao_bandidos": {"corpo": "masculino", "tom": "claro", "aparencia": {"cabelo": "curto", "cor_cabelo": "preto"}},
}
const PARTES_CAPA := ["Peito", "Abdomen", "Manga"]
const PARTES_CALCA := ["Coxa", "Canela"]


static func tem(tipo: String) -> bool:
	return APARENCIAS.has(tipo)


static func corpo(tipo: String) -> String:
	return str(APARENCIAS.get(tipo, {}).get("corpo", "masculino"))


static func tom(tipo: String) -> String:
	return str(APARENCIAS.get(tipo, {}).get("tom", "medio"))


## Aparência já normalizada para o catálogo (chave inválida cai em "original").
static func aparencia(tipo: String) -> Dictionary:
	var A := load("res://src/player/aparencia_historia.gd")
	return A.normalizar(APARENCIAS.get(tipo, {}).get("aparencia", {}))


## Pinta a roupa lisa do corpo em caixas com as cores da ficha. Cada malha ganha MATERIAL PRÓPRIO (o do corpo é compartilhado entre os NPCs).
static func vestir(modelo: Node3D, f: Dictionary) -> void:
	if modelo == null:
		return
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var nome := str(mi.name)
		var cor := Color.TRANSPARENT
		if nome in PARTES_CAPA:
			cor = f.get("capa", Color.TRANSPARENT)
		elif nome in PARTES_CALCA:
			cor = f.get("calca", Color.TRANSPARENT)
		if cor.a <= 0.0:
			continue
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var original := m.get_active_material(s)
			var novo: StandardMaterial3D = original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
			novo.albedo_color = cor
			novo.albedo_texture = null            # a textura do corpo (pele/camisa) cobriria a cor lisa
			m.set_surface_override_material(s, novo)
