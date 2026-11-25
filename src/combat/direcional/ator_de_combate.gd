class_name AtorDeCombate
extends RefCounted
# ============================================================================
#  O QUE O EXECUTOR PRECISA SABER DE UM CORPO — e só isso.
#
#  O `ExecutorCorpoACorpo` não conhece `Player`, boneco nem chefe: cada tipo de
#  corpo entra por um adaptador que herda daqui. É o que deixa a IA usar o mesmo
#  executor do jogador (plano, D1).
#
#  A base responde "corpo livre, sem travas, sem rig" — serve de ator de teste. O
#  que é igual para todo corpo com o rig `base_v2` (pose, efetor, espaço físico)
#  mora aqui; o adaptador só diz QUAL é o corpo e QUAL é o modelo visível.
# ============================================================================

var _aplicador := AplicadorDePose.new()


## O nó físico do corpo (para posição, frente e depuração). Pode ser nulo em teste.
func corpo() -> Node3D:
	return null


## A raiz visível do personagem — a que gira com o olhar e contém o rig.
func modelo_visual() -> Node3D:
	return null


## Pode COMEÇAR uma ação agora? Inclui as travas de quem decide (capacidade,
## menu aberto) além das do corpo.
func pode_iniciar() -> bool:
	return not impedido()


## Está preso por algo de FORA do combate (atordoado, derrubado, congelado, morto)?
##
## ⚠️ Diferente de `pode_iniciar`, e a diferença é regra de jogo: abrir o menu no
## meio de um golpe NÃO o cancela — o compromisso é do corpo, não da tela. Só o
## que prende o corpo cancela.
##
## `contar_atordoamento = false` pergunta só pelas travas duras (derrubado,
## congelado, morto): é o que o golpe que trocou dano no ATIVO consulta (§7.1).
## Corpo que não atordoa com dano ignora o parâmetro.
func impedido(_contar_atordoamento := true) -> bool:
	return false


## Um clipe de ação (roll, deslize) dirige o corpo inteiro? Então a pose de combate
## NÃO pode ser aplicada por cima: ela sobrescreve braços e pernas do clipe.
func corpo_em_acao() -> bool:
	return false


## Um golpe com `clipe` (Epic Fight) pede o clipe que dirige o corpo; `parar` o solta (golpe cancelado ou encerrado).
func tocar_clipe_de_golpe(_caminho: String, _ate := -1.0, _velocidade := 1.0) -> void:
	pass


## O corpo está correndo (Shift com movimento) / no ar: a entrada escolhe com isso os encaixes `CORRIDA` e `NO_AR` do estilo.
func em_corrida() -> bool:
	return false


func no_ar() -> bool:
	return false


func parar_clipe_de_golpe() -> void:
	pass


## Pedido de tremor de câmera. Só o jogador local tem câmera; os outros ignoram.
func tremer_camera(_forca: float) -> void:
	pass


# ------------------------------------------------------- corpo com rig base_v2
## Base SEM escala do corpo visível (frente = −Z).
func base_do_corpo() -> Basis:
	var m := modelo_visual()
	if is_instance_valid(m):
		return m.global_basis.orthonormalized()
	var c := corpo()
	return c.global_basis.orthonormalized() if is_instance_valid(c) else Basis.IDENTITY


## Posição de mundo de um nó do rig (ex. "Hand_R"). `Vector3.INF` se não houver.
func posicao_do_no(nome: StringName) -> Vector3:
	if not _preparar_aplicador():
		return Vector3.INF
	return _aplicador.posicao_global(nome)


## Aplica a pose do combate sobre o que o animador fez neste quadro.
## `estilo`: dedos e pé de apoio. `avanco`: a velocidade que o PRÓPRIO golpe somou neste
## quadro (não é andar). `delta`: o tempo do quadro para o passo (0 no hitstop).
## `arrastado`: o corpo está sendo empurrado (reação) — nada de marcha, e os pés derrapam.
func aplicar_pose(pose: Dictionary, peso: float, estilo: EstiloCorpoACorpo = null, avanco := Vector3.ZERO,
		delta := 0.0, arrastado := false, em_repouso := false) -> void:
	if not _preparar_aplicador():
		return
	# Andando, as pernas ficam com a marcha do animador: pose de perna parada num
	# corpo que se desloca faria o pé patinar. O avanço do golpe NÃO conta como andar —
	# medido em 16/09: o jab soma ~1,1 m/s, e contar isso entregava 72% das pernas à
	# marcha justo no passo do soco (o "corpo de baixo parado" da Fase 3).
	var peso_pernas := peso
	var c := corpo() as CharacterBody3D
	if c != null and not arrastado:
		var andar := c.velocity - avanco
		var andando := clampf(Vector2(andar.x, andar.z).length() / 1.5, 0.0, 1.0)
		peso_pernas = peso * (1.0 - andando)
	_aplicador.aplicar(pose, peso, peso_pernas, estilo, delta, not arrastado, em_repouso)
	# `em_repouso`: sem golpe em curso. Andando, tronco e cabeça seguem a marcha.


func espaco() -> PhysicsDirectSpaceState3D:
	var c := corpo()
	return c.get_world_3d().direct_space_state if is_instance_valid(c) and c.is_inside_tree() else null


## O que a varredura do próprio golpe não pode acertar.
func excluir() -> Array[RID]:
	var lista: Array[RID] = []
	var c := corpo() as CollisionObject3D
	if c != null:
		lista.append(c.get_rid())
		# A própria hurtbox também: sem isto o golpe se acertaria nela.
		var hb := HurtboxDeCombate.rid_de(c)
		if hb.is_valid():
			lista.append(hb)
	return lista


func _preparar_aplicador() -> bool:
	var m := modelo_visual()
	if not is_instance_valid(m):
		return false
	_aplicador.montar(m)
	return _aplicador.valido()
