class_name FrutaNaMao
extends Node
# ============================================================================
#  FRUTA NA MÃO — a fruta do pomar que o jogador tirou do inventário (01/10/2026).
#
#  Decisão do dono: para domar um herbívoro, a fruta sai do inventário (aba FRUTAS) e
#  vai para a MÃO; a tecla Y tenta domar (o F continua sendo o voo da fruta).
#
#  Aqui: qual fruta está na mão, o modelo preso no `Hand_R` do rig (o mesmo nó em que a
#  espada encosta) e a marca `fruta_na_mao` no jogador — é por ela que o herbívoro
#  fica calmo (não foge nem ataca). A tentativa de doma em si é do `ModoHistoria`
#  (`pediu_doma`). Acabou a fruta no inventário, a mão esvazia sozinha.
# ============================================================================

signal mudou
signal pediu_doma(fruta_id: String)

const META := "fruta_na_mao"
const TAMANHO_NA_MAO := 0.22       # m — um pouco menor que a do galho (0,3)

var progressao: ProgressaoDoPersonagem
var biblioteca: BibliotecaDeModelos
## Devolve o jogador local (Player) ou null.
var jogador_de: Callable
var fruta_id := ""

var _visual: Node3D = null
var _da_hotbar := false           # a fruta na mão veio do slot selecionado da hotbar (25/11/2026): soltar o slot a guarda


## 25/11/2026: a fruta do pomar é item da hotbar (`pomar:<id>`): com o slot selecionado ela está na mão; trocar de slot a guarda.
func _sincronizar_com_a_hotbar() -> void:
	if progressao == null or progressao.inventario == null:
		return
	var tag := InventarioMinecraft.id_de(progressao.inventario.na_mao())
	if ItensDeFruta.e_do_pomar(tag):
		var id := ItensDeFruta.id_de(tag)
		if fruta_id != id and segurar(id):
			_da_hotbar = true
	elif _da_hotbar:
		_da_hotbar = false
		guardar()


func segurar(id: String) -> bool:
	if progressao == null or progressao.quantas_frutas_do_pomar(id) <= 0:
		return false
	if fruta_id == id:
		return true
	_tirar_visual()
	fruta_id = id
	_marcar()
	mudou.emit()
	return true


func guardar() -> void:
	if fruta_id.is_empty():
		return
	fruta_id = ""
	_tirar_visual()
	_marcar()
	mudou.emit()


func tem_fruta() -> bool:
	return not fruta_id.is_empty()


## Tecla Y (o HUD chama).
func pedir_doma() -> void:
	if tem_fruta():
		pediu_doma.emit(fruta_id)


func _process(_delta: float) -> void:
	_sincronizar_com_a_hotbar()
	if fruta_id.is_empty():
		return
	if progressao.quantas_frutas_do_pomar(fruta_id) <= 0:
		guardar()
		return
	# O rig pode ter sido remontado (troca de corpo): a mão é outra, prende de novo.
	var mao := _mao()
	if mao == null:
		return
	if _visual == null or not is_instance_valid(_visual) or _visual.get_parent() != mao:
		_tirar_visual()
		_visual = _montar(fruta_id)
		mao.add_child(_visual)
	_marcar()


func _mao() -> Node3D:
	var j: Node = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return null
	var rig: Variant = j.get("_rig")
	var mao: Variant = rig.get("item_handle") if rig != null else null
	return mao as Node3D if mao is Node3D and is_instance_valid(mao) else null


func _marcar() -> void:
	var j: Node = jogador_de.call() if jogador_de.is_valid() else null
	if j != null:
		j.set_meta(META, fruta_id)


func _montar(id: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "FrutaNaMao"
	var m := biblioteca.instanciar(id) if biblioteca != null else null
	if m != null:
		var e: Dictionary = biblioteca.info(id)
		var t: Vector3 = e["tamanho"]
		var k := TAMANHO_NA_MAO / maxf(maxf(t.x, t.y), maxf(t.z, 0.0001))
		m.scale = Vector3.ONE * k
		m.position = -(e["centro"] as Vector3) * k
		raiz.add_child(m)
	# Na palma: um pouco para fora da ponta do antebraço (o +Y da mão é "para fora").
	raiz.position = Vector3(0, 0.08, 0.06)
	return raiz


func _tirar_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		if _visual.get_parent() != null:
			_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null
