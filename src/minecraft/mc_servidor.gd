class_name McServidor
extends RefCounted
## PACOTE DE SERVIDOR (09/11/2026, item 6 da auditoria): métodos que as procedures chamam no `world`/jogador e que o jogo precisa responder de forma
## COERENTE com ele (não é Minecraft com rede): lista de jogadores e mensagens globais viram o aviso do HUD, o modo de jogo é sempre SURVIVAL
## (o jogo não tem criativo/espectador), a fome do Minecraft é só um registro (a fome/sede do jogo é outro sistema), domesticação vira marca no corpo.
## Antes: qualquer procedure que alcançasse `getPlayerList().broadcastSystemMessage` (67 procedures) abortava com "Nonexistent function".

const MODO_PADRAO := &"SURVIVAL"


## `server.getPlayerList()`.
class ListaDeJogadores:
	extends RefCounted
	var mundo: McMundo

	## Mensagem global: aparece no aviso do HUD de cada jogador local (o do mod vai para o chat do servidor).
	func broadcastSystemMessage(texto: Variant = null, _overlay: Variant = false) -> void:
		for e: McEntidade in mundo.players():
			e.displayClientMessage(texto, false)

	func getPlayers() -> Array: return mundo.players()
	func getPlayerCount() -> int: return mundo.players().size()
	func getPlayer(_id: Variant) -> Variant:
		var l := mundo.players()
		return l[0] if not l.is_empty() else null


## `player.getFoodData()`: o mod o usa para encher a fome em arenas. Registro simples (20/20 de saciedade padrão).
class Alimento:
	extends RefCounted
	var nivel := 20
	var saturacao := 5.0
	func getFoodLevel() -> int: return nivel
	func setFoodLevel(n: Variant) -> void: nivel = clampi(int(n), 0, 20)
	func getSaturationLevel() -> float: return saturacao
	func setSaturation(v: Variant) -> void: saturacao = clampf(float(v), 0.0, 20.0)
	func eat(n: Variant, s: Variant = 0.0) -> void:
		nivel = clampi(nivel + int(n), 0, 20)
		saturacao = clampf(saturacao + float(s), 0.0, 20.0)
	func needsFood() -> bool: return nivel < 20


## `Minecraft.getInstance()` — só o ramo que lê o modo de jogo do cliente (`getConnection().getPlayerInfo(uuid).getGameMode()`).
class Cliente:
	extends RefCounted
	func getConnection() -> Cliente: return self
	func getPlayerInfo(_id: Variant) -> Cliente: return self
	func getGameMode() -> StringName: return MODO_PADRAO
	func isLocalServer() -> bool: return true
	func isSingleplayer() -> bool: return true
	func getPartialTick() -> float: return 1.0
