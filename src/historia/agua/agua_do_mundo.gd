class_name AguaDoMundo
extends RefCounted
# ============================================================================
#  ÁGUA DO MUNDO — onde há água e quanto de um corpo está dentro dela (01/10/2026).
#
#  Pedido do dono (docs/AGUA_PLANO.md): água rasa deixa mais lento, nado, mergulho —
#  para o jogador E os animais. Um lugar só responde "qual o nível da água aqui":
#    • MAR: fora das baseplates, no nível do `Oceano` (o mesmo que o desenho usa);
#    • RIO: a água gravada no relevo (`agua` dos blocos de terreno).
#  Os seabeasts (outra sessão) podem consultar daqui depois, sem depender de nada deles.
#  `registrar` é chamado pelo `ModoHistoria` depois de montar o mapa.
# ============================================================================

static var _rios: Array[Dictionary] = []     # blocos de terreno que têm água
static var _oceano: Node = null


static func registrar(mapa: Dictionary, oceano: Node) -> void:
	_rios.clear()
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "terreno" and not (p["relevo"].get("agua", PackedInt32Array()) as PackedInt32Array).is_empty():
			_rios.append(p)
	_oceano = oceano


static func esquecer() -> void:
	_rios.clear()
	_oceano = null


## Nível (Y do mundo) da superfície da água em (x, z); NAN = seco.
static func nivel_em(x: float, z: float) -> float:
	var nivel := NAN
	if _oceano != null and is_instance_valid(_oceano) and bool(_oceano.get("visible")) and _no_mar(x, z):
		nivel = float(_oceano.get("nivel"))
	for p in _rios:
		var pos: Vector3 = p["posicao"]
		var tam: Vector3 = p["tamanho"]
		if absf(x - pos.x) > tam.x * 0.5 or absf(z - pos.z) > tam.z * 0.5:
			continue
		var y := TerrenoDoMapa.agua_local(p["relevo"], tam, x - pos.x, z - pos.z)
		if not is_nan(y):
			nivel = pos.y + y if is_nan(nivel) else maxf(nivel, pos.y + y)
		break
	return nivel


## Superfície instantânea para cascos e espuma. Não muda a linha média usada
## pela natação/animais. Rios elevados mantêm a superfície plana do terreno.
static func superficie_em(x: float, z: float) -> float:
	var nivel := nivel_em(x, z)
	if is_nan(nivel):
		return NAN
	if is_instance_valid(_oceano) and bool(_oceano.get("visible")) and _no_mar(x, z) \
		and is_equal_approx(nivel, float(_oceano.get("nivel"))) and _oceano.has_method("superficie_em"):
		return float(_oceano.call("superficie_em", x, z))
	return nivel


static func normal_em(x: float, z: float) -> Vector3:
	var nivel := nivel_em(x, z)
	if not is_nan(nivel) and is_instance_valid(_oceano) and bool(_oceano.get("visible")) \
		and _no_mar(x, z) and is_equal_approx(nivel, float(_oceano.get("nivel"))) \
		and _oceano.has_method("normal_em"):
		return _oceano.call("normal_em", x, z)
	return Vector3.UP


## Quanto de um corpo de `altura` com os pés em `pes` está submerso: 0 (seco) a 1 (todo).
static func submersao(pes: Vector3, altura: float) -> float:
	var nivel := nivel_em(pes.x, pes.z)
	if is_nan(nivel):
		return 0.0
	return clampf((nivel - pes.y) / maxf(altura, 0.05), 0.0, 1.0)


## Água rasa (decisão do dono: a dificuldade de andar na água deixa mais lento):
## canela −15 %, joelho −30 %, cintura −50 %. Daí para cima já é nado.
static func fator_de_andar(submerso: float) -> float:
	return 1.0 - clampf(submerso / 0.55, 0.0, 1.0) * 0.5


## Mar = fora de todas as baseplates (as caixas que o oceano usa para a costa).
static func _no_mar(x: float, z: float) -> bool:
	var bases: Variant = _oceano.get("bases")
	if not (bases is Array) or (bases as Array).is_empty():
		return false
	for p: Dictionary in bases:
		var pos: Vector3 = p["posicao"]
		var tam: Vector3 = p["tamanho"]
		var giro := deg_to_rad((p["rotacao_graus"] as Vector3).y)
		var local := Vector2(x - pos.x, z - pos.z).rotated(giro)
		if absf(local.x) <= tam.x * 0.5 and absf(local.y) <= tam.z * 0.5:
			return false
	return true
