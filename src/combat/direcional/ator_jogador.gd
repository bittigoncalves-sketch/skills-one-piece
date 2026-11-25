class_name AtorJogador
extends AtorDeCombate
# ============================================================================
#  ADAPTADOR DO JOGADOR para o executor do combate direcional.
#
#  Só usa API PÚBLICA do Player. A partição do Player (docs/ARQUITETURA_PLAYER.md,
#  fase 9) existiu justamente para apagar componentes chamando métodos com `_` de
#  fora — este adaptador não reabre esse cheiro.
# ============================================================================

var _jogador: Player


func _init(jogador: Player) -> void:
	_jogador = jogador


func corpo() -> Node3D:
	return _jogador


func modelo_visual() -> Node3D:
	return _jogador.modelo_visual() if is_instance_valid(_jogador) else null


func posicao_do_no(nome: StringName) -> Vector3:
	if nome in [&"EspadaBase", &"EspadaPonta", &"EspadaBaseL", &"EspadaPontaL"]:
		var arma := _jogador.get_node_or_null("EspadaDaHistoria")
		return arma.ponto(nome) if arma != null else Vector3.INF
	return super.posicao_do_no(nome)


func em_corrida() -> bool:
	return is_instance_valid(_jogador) and _jogador.esta_correndo()


func no_ar() -> bool:
	return is_instance_valid(_jogador) and not _jogador.is_on_floor()


func tocar_clipe_de_golpe(caminho: String, ate := -1.0, velocidade := 1.0) -> void:
	if is_instance_valid(_jogador):
		_jogador.tocar_clipe_de_golpe(caminho, ate, velocidade)


func parar_clipe_de_golpe() -> void:
	if is_instance_valid(_jogador):
		_jogador.parar_clipe_de_golpe()


func tremer_camera(forca: float) -> void:
	if is_instance_valid(_jogador) and _jogador.is_multiplayer_authority():
		_jogador.add_camera_shake(forca)


func pode_iniciar() -> bool:
	if impedido() or (_jogador.get_meta("giro_espada_ativo", false) or _jogador.get_meta("magu_cao_ativo", false) \
			or _jogador.get_meta("machado_arremesso_ativo", false)):
		return false
	if not _jogador.capacidades.can_attack:
		return false
	var hud := _jogador.get_tree().get_first_node_in_group("hud") if _jogador.is_inside_tree() else null
	if hud and hud.has_method("is_menu_open") and hud.is_menu_open():
		return false
	return true


func corpo_em_acao() -> bool:
	return is_instance_valid(_jogador) and _jogador.clipe_de_acao_ativo()


func impedido(contar_atordoamento := true) -> bool:
	if not is_instance_valid(_jogador):
		return true
	return not _jogador.corpo_livre_para_golpe(contar_atordoamento)
