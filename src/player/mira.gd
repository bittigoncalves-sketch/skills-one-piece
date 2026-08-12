class_name Mira
extends RefCounted
# ============================================================================
#  MIRA — para onde se aponta, e de onde o tiro sai.
#
#  Fase 9 de docs/ARQUITETURA_PLAYER.md. Este corte não foi escolhido por
#  tamanho: foi para **apagar um cheiro** que as fases 5 a 8 deixaram.
#
#  Os componentes de combate precisavam do ponto de mira, e chamavam métodos
#  PRIVADOS do Player para consegui-lo:
#
#      _dono._aim_target_point()      (Buki, DisparoSustentado)
#      _dono._alvo_mais_proximo(...)  (Buki, DisparoSustentado)
#      _dono._muzzle_pos(...)         (DisparoSustentado)
#
#  Sete chamadas, três componentes, todas atravessando a fronteira que a
#  refatoração inteira existe para desenhar. Agora é um componente com API
#  pública, e quem quer mira PEDE mira.
#
#  ------------------------------------------------------------------- O QUE É
#  Três perguntas diferentes, que viviam soltas:
#
#    ponto_de_mira()  onde o raio da câmera encosta no mundo (com auxílio, puxa
#                     para o inimigo mais ALINHADO no cone de ~25°)
#    mais_proximo()   o corpo mais PERTO — outra pergunta, outro critério; é o
#                     que a pistola da Yami e o auxílio da Buki usam
#    boca_da_pistola()de onde a bala nasce, com a pistola certa na mão
#
#  ⚠️ `mais_proximo` varre `enemy` **e** `player`: numa arena PvP o alvo mais
#  provável é outro jogador. `ponto_de_mira` com auxílio varre só `enemy` — mira
#  assistida em cima de gente seria tiro grátis.
# ============================================================================

const ALCANCE_RAIO := 200.0     # até onde o raio da mira procura mundo
const ALCANCE_ASSIST := 55.0    # até onde o auxílio aceita alvo
const CONE_ASSIST := 0.9        # cosseno do cone (~25°)

var _dono: Node3D = null

func montar_em(dono: Node3D) -> void:
	_dono = dono

# Ponto no mundo sob a MIRA. Com auxílio ligado, puxa para o inimigo mais
# alinhado dentro do cone.
func ponto_de_mira(camera: Camera3D, auxilio: bool) -> Vector3:
	var de := camera.global_position
	var frente := -camera.global_transform.basis.z
	if auxilio:
		var alvo := alvo_alinhado(de, frente)
		if alvo != null:
			return alvo.global_position + Vector3.UP * 0.6
	var espaco := _dono.get_world_3d().direct_space_state
	var par := PhysicsRayQueryParameters3D.create(de, de + frente * ALCANCE_RAIO)
	par.exclude = [_dono.get_rid()]
	var hit := espaco.intersect_ray(par)
	if not hit.is_empty():
		return hit["position"]
	return de + frente * 60.0

# Inimigo mais ALINHADO à mira dentro do cone e do alcance — é o do auxílio.
func alvo_alinhado(de: Vector3, frente: Vector3) -> Node3D:
	var melhor: Node3D = null
	var melhor_alinhamento := CONE_ASSIST
	for e in _dono.get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D):
			continue
		var para: Vector3 = (e.global_position + Vector3.UP * 0.6) - de
		var d := para.length()
		if d > ALCANCE_ASSIST or d < 0.5:
			continue
		var alinhamento := frente.dot(para / d)
		if alinhamento > melhor_alinhamento:
			melhor_alinhamento = alinhamento
			melhor = e
	return melhor

# Corpo mais PRÓXIMO (inimigo ou outro jogador) dentro do alcance. Nasceu na
# pistola da Yami e hoje serve também o auxílio de mira da Buki.
func mais_proximo(alcance: float) -> Node3D:
	var melhor: Node3D = null
	var melhor_d := alcance
	var arvore := _dono.get_tree()
	if arvore == null or arvore.current_scene == null:
		return null
	for c in arvore.get_nodes_in_group("enemy") + arvore.get_nodes_in_group("player"):
		if not (c is Node3D) or c == _dono:
			continue
		var d: float = _dono.global_position.distance_to(c.global_position)
		if d < melhor_d and d > 0.2:
			melhor_d = d
			melhor = c
	return melhor

# De onde a bala nasce. Sem pistola na árvore, cai à frente do peito (mesma rede
# de segurança que a boca do cano da Buki usa).
func boca_da_pistola(pistolas: Array, lado: int, camera: Camera3D) -> Vector3:
	if lado < pistolas.size() and is_instance_valid(pistolas[lado]):
		var g: Node3D = pistolas[lado]
		return g.global_position - g.global_transform.basis.y * 0.34   # cano = −Y local
	return _dono.global_position + Vector3.UP * 1.0 - camera.global_transform.basis.z * 1.2
