class_name EsquivaDeDisparo
extends RefCounted
# ============================================================================
#  ESQUIVA COM DASH DOS INIMIGOS CONTRA A BUKI BUKI (22/11/2026)
#
#  Cada tipo de inimigo move o corpo de um jeito (`_empurrao`, `_pending_knockback`,
#  `velocity`), então o DASH em si mora em cada classe; o que é IGUAL mora aqui:
#  recarga (3 s, relógio real), escolha do lado e o efeito visual/sonoro.
#  Quem avisa é a `BalaDaBuki` (bala no corredor, ou inimigo ferido).
# ============================================================================

const RECARGA := 3.0
const IMPULSO := 8.5        # m/s com decaimento de ~10 m/s² (animal, boneco): ~3,6 m
const META := "esquiva_recarga_ate_ms"


static func pronta(corpo: Node) -> bool:
	return Time.get_ticks_msec() >= int(corpo.get_meta(META, 0))


## Lado do dash (horizontal, perpendicular ao tiro, para o lado em que o corpo já está mais longe da reta). `Vector3.ZERO` = não esquiva
## (em recarga ou rumo inválido). Quando devolve um vetor, a recarga já começou e o efeito já tocou.
static func tentar(corpo: Node3D, rumo: Vector3) -> Vector3:
	if not pronta(corpo) or rumo.length() < 0.1 or not corpo.is_inside_tree():
		return Vector3.ZERO
	var lateral := Vector3(rumo.z, 0.0, -rumo.x)
	lateral = lateral.normalized() if lateral.length() > 0.05 else Vector3.RIGHT
	var jogador := corpo.get_tree().get_first_node_in_group("player") as Node3D
	var de_lado := (corpo.global_position - jogador.global_position).dot(lateral) if jogador != null else 0.0
	lateral *= signf(de_lado) if absf(de_lado) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	corpo.set_meta(META, Time.get_ticks_msec() + int(RECARGA * 1000.0))
	var cena := corpo.get_tree().current_scene
	FxUtil.dash_effect(cena, corpo.global_position + Vector3.UP * 0.2, lateral)
	AudioFX.dash(cena, corpo.global_position)
	return lateral
