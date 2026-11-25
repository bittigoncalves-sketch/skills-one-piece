class_name McTipoEntidade
extends RefCounted
## `EntityType` do Minecraft: um por id (`Mc.tipo_entidade`), então `==` funciona como no Java.

var id: StringName


## `getType().is(TagKey)`: as tags de entidade do mod (`Mc.tag_contem`).
func is_(tag: Variant) -> bool:
	return Mc.tag_contem(tag, id)


## `EntityType.X.create(level)` / `.create(level, tag, consumer, pos, tipo, b, b)` (= spawn) /
## `.spawn(level, pos, tipo)`: um corpo virtual da entidade do mod, já no mundo.
func create(mundo: Variant, _a: Variant = null, _b: Variant = null, pos: Variant = null, _t: Variant = null,
		_c: Variant = null, _d: Variant = null) -> McEntidade:
	if not (mundo is McMundo):
		return null
	if id == &"minecraft:falling_block":
		var queda := McBlocoQueda.criar(mundo, pos if pos is McVec3 else null)
		return McEntidade.de(queda) if queda != null else null
	# Criatura que uma fruta invoca (guerreiro de biscoito, Doppelman…): corpo de personagem de verdade, não o virtual.
	if McAliadoDoMod.e_invocavel(String(id).trim_prefix("minepiece:")):
		if not McAliadoDoMod.cobrar(String(id).trim_prefix("minepiece:"), (mundo as McMundo).arvore):
			return null                    # sem o item que a invocação custa (biscoito): nada nasce
		McAliadoDoMod.abrir_vaga(String(id).trim_prefix("minepiece:"), (mundo as McMundo).arvore)      # no máximo 6 guerreiros: o mais antigo sai
		var aliado := McAliadoDoMod.criar(String(id).trim_prefix("minepiece:"), mundo, pos if pos is McVec3 else null)
		if aliado != null:
			_sinalizar(aliado.no, String(id).trim_prefix("minepiece:"), mundo)
			return aliado
	var corpo := McCorpoDoMod.criar(String(id).trim_prefix("minepiece:"), mundo, pos if pos is McVec3 else null)
	_aplicar_asset_da_tecnica(corpo, String(id).trim_prefix("minepiece:"), mundo)
	_sinalizar(corpo, String(id).trim_prefix("minepiece:"), mundo)
	return McEntidade.de(corpo)


## O asset 3D da técnica (`AssetsDeTecnica`) no lugar do desenho genérico, quando o jogador executa uma técnica que tem um. Só visual.
func _aplicar_asset_da_tecnica(corpo: Variant, id_curto: String, mundo: Variant) -> void:
	if not (corpo is Node3D) or not (mundo is McMundo) or (mundo as McMundo).arvore == null:
		return
	var jogador := (mundo as McMundo).arvore.get_first_node_in_group("player")
	if jogador != null:
		AssetsDeTecnica.aplicar(corpo, id_curto, jogador)


## Marca de nascimento (clarão + anel da cor da fruta) quando um jogador está executando técnica: ao FIM do quadro, porque a procedure
## posiciona a entidade logo depois do `create` (no `create(level)` a posição só vem em `setPos`). Só visual.
func _sinalizar(corpo: Variant, id_curto: String, mundo: Variant) -> void:
	if not (corpo is Node3D) or not (mundo is McMundo) or (mundo as McMundo).arvore == null:
		return
	var arvore: SceneTree = (mundo as McMundo).arvore
	var jogador := arvore.get_first_node_in_group("player") as Node3D
	if jogador == null:
		return
	var ctl := jogador.get_node_or_null("FrutaMinePiece")
	if ctl == null or not bool(ctl.get("ativo")):
		return
	arvore.process_frame.connect(func() -> void:
		if is_instance_valid(corpo) and is_instance_valid(jogador) and (corpo as Node3D).is_inside_tree():
			PoderDaFruta.sinal_de_nascimento(jogador, id_curto, (corpo as Node3D).global_position)
			PoderDaFruta.rastro_em_voo(corpo as Node3D, id_curto, str(jogador.get("current_fruit_id"))), CONNECT_ONE_SHOT)


func spawn(mundo: Variant, pos: Variant = null, _t: Variant = null) -> McEntidade:
	return create(mundo, null, null, pos)


func getDescriptionId() -> String: return "entity." + String(id).replace(":", ".")
func _to_string() -> String: return String(id)
