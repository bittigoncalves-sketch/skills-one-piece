extends Button
signal recebeu(id: String)
var membro_id := ""
var aceita := false
func _get_drag_data(_pos: Vector2) -> Variant:
	if membro_id.is_empty(): return null
	var previa := Label.new()
	previa.text = text
	set_drag_preview(previa)
	return {"tripulante": membro_id}
func _can_drop_data(_pos: Vector2, dados: Variant) -> bool:
	return aceita and dados is Dictionary and dados.get("tripulante") is String
func _drop_data(_pos: Vector2, dados: Variant) -> void:
	if _can_drop_data(_pos, dados): recebeu.emit(str(dados.tripulante))
