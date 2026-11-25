class_name McEvento
extends RefCounted
# ============================================================================
#  EVENTO do Forge para os handlers `@SubscribeEvent` do Mine Piece (LivingTickEvent,
#  LivingAttackEvent, LivingHurtEvent, LivingDamageEvent, LivingDeathEvent…). As técnicas dos
#  personagens rodam no `LivingTickEvent` (EntityActiveProcedure), não no baseTick.
#  Quem escuta o quê: `mapas/east_blue/eventos_do_mod.json` (tools/mine_piece/extrair_eventos.py).
# ============================================================================

const ARQUIVO := "res://mapas/east_blue/eventos_do_mod.json"
const CANCELAVEIS := [&"LivingAttackEvent", &"LivingHurtEvent", &"LivingDamageEvent", &"LivingDeathEvent"]

static var _handlers := {}          # tipo → [[GDScript, método]]

var tipo: StringName
var entidade: McEntidade
var fonte: McFonteDeDano
var quantidade := 0.0
var cancelado := false
var conquista: Variant = null        # `AdvancementEvent`: a conquista concluída


func getEntity() -> McEntidade: return entidade
func getSource() -> McFonteDeDano: return fonte
func getAmount() -> float: return quantidade
func getAdvancement() -> Variant: return conquista
func setAmount(v: float) -> void: quantidade = v
func isCancelable() -> bool: return tipo in CANCELAVEIS
func setCanceled(sim: bool) -> void:
	if isCancelable():
		cancelado = sim
func isCanceled() -> bool: return cancelado


## Dispara o evento para todos os handlers do mod; devolve o próprio evento (cancelado, dano mudado).
static func disparar(tipo_: StringName, ent: McEntidade, fonte_: McFonteDeDano = null, valor := 0.0, conquista_: Variant = null) -> McEvento:
	var e := McEvento.new()
	e.tipo = tipo_
	e.entidade = ent
	e.fonte = fonte_ if fonte_ != null else McFonteDeDano.de(&"minecraft:generic")
	e.quantidade = valor
	e.conquista = conquista_
	for h in _de(tipo_):
		var t_h := Cronometro.ini()
		(h[0] as GDScript).call(h[1], e)
		if Cronometro.ligado:
			Cronometro.fim(StringName("evento:" + (h[0] as Script).resource_path.get_file()), t_h)
		if e.cancelado:
			break
	return e


static func _de(tipo_: StringName) -> Array:
	if _handlers.is_empty():
		var t_montar := Cronometro.ini()
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
		_handlers["_"] = []
		if d is Dictionary:
			for t in d["eventos"]:
				_handlers[StringName(t)] = []
				for par in d["eventos"][t]:
					var s := Mc.proc(StringName(par[0]))
					if s != null:
						_handlers[StringName(t)].append([s, StringName(par[1])])
		Cronometro.fim(&"McEvento.montar_tabela", t_montar)
	return _handlers.get(tipo_, [])
