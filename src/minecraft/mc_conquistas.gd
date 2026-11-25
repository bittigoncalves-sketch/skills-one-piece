class_name McConquistas
extends RefCounted
## As CONQUISTAS (advancements) do Mine Piece — as 123 do mod, de verdade (antes eram "já concluídas": toda técnica liberada).
## Definições: `mapas/east_blue/conquistas_do_mod.json` (`tools/mine_piece/extrair_conquistas.py`). Todas usam gatilhos
## `impossible` (só as procedures concedem: grades pela recompensa, habilidades por estilo, básicas por uso) ou `tick`
## (concluídas no primeiro tick, sem aviso).
##
## Estado = {id: [critérios feitos]} guardado na PROGRESSÃO do personagem (`conquistas_mod`, salvo junto). A fiação do
## jogador (estado, recompensa → `UpdateBounty`, conquistas por tick) está em `JogadorDoMod`.
## Concluir uma conquista (todos os critérios): `AdvancementEvent` do Forge para os handlers do mod (as grades concedem as
## habilidades que elas liberam), aviso na tela e o som do toast. Só o JOGADOR tem conquistas: para os outros corpos o
## mod checa `instanceof ServerPlayer` antes e este sistema nunca é consultado.

const ARQUIVO := "res://mapas/east_blue/conquistas_do_mod.json"
static var _defs: Dictionary = {}


static func definicoes() -> Dictionary:
	if _defs.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
		if d is Dictionary:
			for id: String in d.conquistas:
				_defs[id] = Def.de(id, d.conquistas[id])
		if _defs.is_empty():
			_defs["_"] = null
	return _defs


## Uma conquista (o `Advancement` do Minecraft).
class Def:
	extends RefCounted
	var id := ""
	var criterios: Array = []
	var pai := ""
	var gatilho := "impossible"
	var titulo := ""
	var descricao := ""
	var moldura := "task"
	var aviso := false

	static func de(id_: String, d: Dictionary) -> Def:
		var x := Def.new()
		x.id = id_
		x.criterios = d.criterios
		x.pai = str(d.pai)
		x.gatilho = str(d.gatilho)
		x.titulo = str(d.titulo)
		x.descricao = str(d.descricao)
		x.moldura = str(d.moldura)
		x.aviso = bool(d.aviso)
		return x

	func getId() -> String: return id
	func _to_string() -> String: return id


## O `AdvancementProgress` de um jogador numa conquista.
class Progresso:
	extends RefCounted
	var def: Def
	var dono: Avancos

	func isDone() -> bool:
		return def == null or getRemainingCriteria().is_empty()
	func getRemainingCriteria() -> Array:
		if def == null:
			return []
		var feitos: Array = dono.estado.get(def.id, [])
		return def.criterios.filter(func(c): return not feitos.has(c))
	func awardCriterion(c: Variant) -> bool: return dono.award(def, c)


## O `PlayerAdvancements` do jogador.
class Avancos:
	extends RefCounted
	var jogador: McEntidade
	var estado: Dictionary                   # a MESMA referência da progressão (é o que o save grava)
	var concluidas := 0                      # quantas conquistas este jogador concluiu nesta sessão (os controladores relêem a lista)

	func getOrStartProgress(a: Variant) -> Progresso:
		var p := Progresso.new()
		p.def = a if a is Def else null
		p.dono = self
		return p

	## Concede um critério; ao completar a conquista: evento, aviso e som. Devolve se algo mudou.
	func award(a: Variant, criterio: Variant) -> bool:
		if not (a is Def) or not (a as Def).criterios.has(str(criterio)):
			return false
		var d: Def = a
		var feitos: Array = estado.get(d.id, [])
		if feitos.has(str(criterio)):
			return false
		feitos.append(str(criterio))
		estado[d.id] = feitos
		if OS.get_environment("MC_TRACE_CONQUISTAS") != "":
			var pilha := get_stack()
			print("CONQUISTA ", d.id, " <- ", " < ".join(pilha.slice(1, 5).map(func(f): return str(f.function))))
		if (d.criterios.filter(func(c): return not feitos.has(c))).is_empty():
			_concluida(d)
		return true

	func revoke(a: Variant, criterio: Variant) -> bool:
		if not (a is Def):
			return false
		var feitos: Array = estado.get((a as Def).id, [])
		var i := feitos.find(str(criterio))
		if i < 0:
			return false
		feitos.remove_at(i)
		return true

	func _concluida(d: Def) -> void:
		concluidas += 1
		if d.aviso and d.gatilho != "tick":
			jogador.displayClientMessage(McTexto.de("Conquista: %s — %s" % [d.titulo, d.descricao]), false)
			McVisual.som(jogador.no.get_tree(), "ui.toast.challenge_complete" if d.moldura != "task" else "entity.experience_orb.pickup",
				jogador.position(), 1.0)
		if d.gatilho == "tick":
			# Raízes/abas concluídas no 1º tick: o único handler que reage a elas é o KIT INICIAL do mod
			# (`StartMinePieceComplated`: livro seletor de habilidade, bússola, bandeira de ataque), que o jogo não tem no
			# inventário. Não dispara; fica registrado em vez de silencioso.
			Mc.contar("conquista:kit_inicial_do_mod_nao_entregue")
			return
		McEvento.disparar(&"AdvancementEvent", jogador, null, 0.0, d)

	## Conquistas por `tick` (raízes e abas): concluídas no primeiro tick, sem aviso.
	func conceder_as_de_tick() -> void:
		for d: Def in McConquistas.definicoes().values():
			if d != null and d.gatilho == "tick":
				for c in d.criterios:
					award(d, c)


## O registro do servidor (`ServerAdvancementManager`): `getAdvancement(id)`.
class Registro:
	extends RefCounted
	func getAdvancement(id: Variant) -> Variant:
		var d: Variant = McConquistas.definicoes().get(str(id))
		if d == null:
			Mc._falta("conquista", "desconhecida:" + str(id))
		return d
