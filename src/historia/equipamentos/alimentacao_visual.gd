extends Node
## Apresentação apenas. O estoque/fome/sede continuam nas Provisoes e no HUD.
const Poses = preload("res://src/anim/alimentacao_poses.gd")
const PAO = preload("res://assets/models/alimentacao/pao_rustico.glb")
const AGUA = preload("res://assets/models/alimentacao/garrafa_agua.glb")
var tipo := ""
var quantidade := 0
var tempo := -1.0
var _escala_de_tempo := 1.0              # <1 estica o clipe (comer devagar): clipe.length / duração pedida
var _ao_concluir := Callable()           # refeição completa: aplica a fome e o bônus (só no servidor)
var _ao_interromper := Callable()        # algo cortou a refeição: devolve o item
var visual: Node3D
var _tipo_visual := ""
var _j: Player
## 25/11/2026: o ITEM mostrado na mão (id do alimento: "pao", "maca"…) e a Akuma no Mi segurada (id) — modelos voxel + sons por gesto.
var variante := ""
var _tipo_equipado := ""                 # o que a progressão equipou (para voltar ao fim de comer a Akuma)
var _qtd_equipada := 0
var _variante_equipada := ""
var _akuma := ""                         # Akuma no Mi no slot selecionado da hotbar ("" = nenhuma)
var _comendo_akuma := false
var _ultimo_t := -1.0                    # relógio do clipe na última checagem de sons
var _agenda: Array = []
var _som: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _prog: ProgressaoDoPersonagem = null

func _ready() -> void:
	_j = get_parent() as Player
	process_physics_priority = -10 # publica a pose antes do Player animar

func equipar(item: String, estoque: int, nova_variante := "") -> void:
	var novo := item if item in ["comida", "agua"] else ""
	_tipo_equipado = novo
	_qtd_equipada = estoque
	_variante_equipada = nova_variante if novo != "" else ""
	if novo == tipo and estoque == quantidade and _variante_equipada == variante: return
	_definir(novo, estoque, _variante_equipada)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_equipar.rpc(novo, estoque, _variante_equipada)

func _definir(item: String, estoque: int, nova_variante := "") -> void:
	if item != tipo: cancelar()
	tipo = item
	variante = nova_variante
	quantidade = maxi(0, estoque)
	_atualizar_visual()

func apresentar(item: String, duracao := 0.0, nova_variante := "") -> void:
	if not item in ["comida", "agua"] or (_j.health <= 0 or _j.morrendo): return
	if not nova_variante.is_empty(): variante = nova_variante
	_iniciar(item, duracao)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_consumo.rpc(item, duracao, variante)

func comendo() -> bool:
	return tempo >= 0.0 and tipo == "comida"

## Comer DEVAGAR (servidor): o clipe dura `duracao` s; `ao_concluir` roda no fim, `ao_interromper` se algo cortar (dano, rolagem, morte).
func comer(duracao: float, ao_concluir: Callable, ao_interromper: Callable, nova_variante := "") -> void:
	_ao_concluir = ao_concluir
	_ao_interromper = ao_interromper
	apresentar("comida", duracao, nova_variante)

## Comer a AKUMA NO MI (25/11/2026): o mesmo gesto de comer, mais lento, com a fruta na mão e sons próprios. `ao_concluir` aplica o poder
## (só no fim); `ao_interromper` roda se algo cortar o gesto (dano, rolagem): a fruta continua no inventário.
func comer_akuma(id: String, duracao: float, ao_concluir: Callable, ao_interromper: Callable) -> bool:
	if comendo() or _comendo_akuma or (_j.health <= 0 or _j.morrendo): return false
	_akuma = id
	_comendo_akuma = true
	comer(duracao, func():
			_fim_do_akuma()
			if ao_concluir.is_valid(): ao_concluir.call(),
		func():
			_fim_do_akuma()
			if ao_interromper.is_valid(): ao_interromper.call(),
		AlimentosVoxel.PREFIXO_AKUMA + id)
	return true

func _fim_do_akuma() -> void:
	_comendo_akuma = false
	_definir(_tipo_equipado, _qtd_equipada, _variante_equipada)      # volta ao que a progressão tinha equipado (pão/água/nada)

func comendo_akuma() -> bool:
	return _comendo_akuma

func _iniciar(item: String, duracao := 0.0) -> void:
	tipo = item
	tempo = 0.0
	_escala_de_tempo = Poses.clipe(item).length / duracao if duracao > 0.0 else 1.0
	_ultimo_t = -0.001
	_agenda = AlimentosVoxel.agenda(variante, item)
	_atualizar_visual()
	_publicar_pose()

@rpc("any_peer", "call_remote", "reliable")
func _net_equipar(item: String, estoque: int, nova_variante := "") -> void:
	if multiplayer.get_remote_sender_id() != 1 or not item in ["", "comida", "agua"] or not AlimentosVoxel.valida(nova_variante): return
	_definir(item, estoque, nova_variante)

@rpc("any_peer", "call_remote", "reliable")
func _net_consumo(item: String, duracao := 0.0, nova_variante := "") -> void:
	if multiplayer.get_remote_sender_id() != 1 or not item in ["comida", "agua"] or not AlimentosVoxel.valida(nova_variante): return
	if not nova_variante.is_empty(): variante = nova_variante
	_iniciar(item, duracao)

func _physics_process(delta: float) -> void:
	if (_j.health <= 0 or _j.morrendo):
		cancelar()
		_tirar_visual()
		return
	_sincronizar_akuma()
	if tempo >= 0.0:
		# Uma ação corporal posterior tem prioridade; não fica item na boca no roll/dano.
		if not str(_j.get_meta("custom_pose", "")).is_empty() or (_j._proc_anim != null and (not _j._proc_anim.acao_clipe.is_empty() or _j._proc_anim._baked != null)):
			cancelar()
		else:
			tempo += delta * _escala_de_tempo
			_tocar_sons_ate(tempo)
			if tempo >= Poses.clipe(tipo).length:
				var concluir := _ao_concluir
				_ao_concluir = Callable()
				_ao_interromper = Callable()
				cancelar()
				if concluir.is_valid(): concluir.call()      # refeição completa: a fome entra AGORA
			else: _publicar_pose()
	_atualizar_visual()

## Akuma no Mi no slot selecionado da hotbar → fica na mão (como a fruta do pomar na `FrutaNaMao`); some ao trocar de slot ou comer.
func _sincronizar_akuma() -> void:
	if _comendo_akuma: return
	if _prog == null:
		var modo := get_tree().get_first_node_in_group("modo_historia")
		_prog = modo.get("progressao") if modo != null else null
		if _prog == null: return
	var tag := InventarioMinecraft.id_de(_prog.inventario.na_mao())
	var id := ItensDeFruta.id_de(tag) if ItensDeFruta.e_akuma(tag) else ""
	if id == _akuma: return
	_akuma = id
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_net_akuma.rpc(id)
	_atualizar_visual()

@rpc("any_peer", "call_remote", "reliable")
func _net_akuma(id: String) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not AlimentosVoxel.valida(AlimentosVoxel.PREFIXO_AKUMA + id): return
	_akuma = id
	_atualizar_visual()

## Dispara os sons da agenda cujo instante do CLIPE foi cruzado neste quadro (o clipe esticado em "comer devagar" leva os sons junto).
func _tocar_sons_ate(t: float) -> void:
	for e: Dictionary in _agenda:
		if float(e.t) > _ultimo_t and float(e.t) <= t:
			_tocar(str(e.som), float(e.db))
	_ultimo_t = t

func _tocar(familia: String, db: float) -> void:
	var fluxo := AlimentosVoxel.som(familia, _rng)
	if fluxo == null or not is_instance_valid(_j): return
	if _som == null or not is_instance_valid(_som):
		_som = AudioStreamPlayer3D.new()
		_som.name = "SomDeComer"
		_som.max_polyphony = 4
		_som.unit_size = 6.0
		_j.add_child(_som)
		_som.position = Vector3(0, 1.5, -0.2)
	_som.stream = fluxo
	_som.volume_db = db
	_som.pitch_scale = _rng.randf_range(0.94, 1.06)
	_som.play()

func _publicar_pose() -> void:
	_j.set_meta("alimentacao_pose", {"tipo": tipo, "tempo": tempo})

func cancelar() -> void:
	var interromper := _ao_interromper
	_ao_interromper = Callable()
	_ao_concluir = Callable()
	if tempo >= 0.0 and interromper.is_valid(): interromper.call()      # cortada no meio: o item volta ao estoque
	_escala_de_tempo = 1.0
	_ultimo_t = -1.0
	_agenda = []
	tempo = -1.0
	if is_instance_valid(_j): _j.remove_meta("alimentacao_pose")

## O que deve estar na mão: "akuma:<id>" (segurada ou sendo comida), o alimento atual, ou "" (nada).
func _chave_do_visual() -> String:
	if _akuma != "" and (tipo.is_empty() or _comendo_akuma):
		return AlimentosVoxel.PREFIXO_AKUMA + _akuma
	if tipo.is_empty() or (quantidade <= 0 and tempo < 0):
		return ""
	return variante if not variante.is_empty() else ("agua" if tipo == "agua" else "pao")

func _atualizar_visual() -> void:
	var chave := _chave_do_visual()
	if _j == null or (_j.health <= 0 or _j.morrendo) or chave.is_empty():
		_tirar_visual()
		return
	var mao: Node3D = _j._rig.item_handle
	if not is_instance_valid(mao):
		_tirar_visual()
		return
	if not is_instance_valid(visual) or visual.get_parent() != mao or _tipo_visual != chave:
		_tirar_visual()
		visual = AlimentosVoxel.instanciar(chave)                  # modelo voxel próprio do item / da Akuma
		if visual == null:                                          # sem modelo voxel: o pão e a garrafa de antes
			visual = (AGUA if tipo == "agua" else PAO).instantiate()
		visual.name = "ItemNaMao"
		mao.add_child(visual)
		visual.scale = Vector3.ONE / mao.global_basis.get_scale().abs()
		_tipo_visual = chave

func _process(_delta: float) -> void:
	if not is_instance_valid(visual): return
	# Compensa o socket depois do rig: garrafa em pé na espera, gargalo voltado
	# para a boca no gole. Não atravessa a cabeça seguindo o eixo do antebraço.
	var elevacao := 0.0
	if tempo >= 0.0:
		var duracao := Poses.clipe(tipo).length
		elevacao = smoothstep(.22, .58, tempo) * (1.0 - smoothstep(duracao - .55, duracao - .08, tempo))
	var base := _j._char_model.global_basis.orthonormalized()
	var inclinacao := Basis(Vector3.RIGHT, 1.80 * elevacao) if tipo == "agua" else Basis(Vector3.FORWARD, .08 * elevacao)
	if tipo == "agua" and _j._char_model.has_meta("corpo_historia"):
		inclinacao = Basis(Vector3.UP, -.65 * elevacao) * inclinacao
	visual.global_basis = base * inclinacao


## O clipe foi autorado para o rig antigo. Mantém o gesto e ajusta o braço às
## medidas do corpo em blocos; item continua preso à mão, sem flutuar até a boca.
func ajustar_contato() -> void:
	if tempo < 0.0 or not _j._char_model.has_meta("corpo_historia"): return
	var duracao := Poses.clipe(tipo).length
	var peso := smoothstep(.22, .58, tempo) * (1.0 - smoothstep(duracao - .55, duracao - .08, tempo))
	if peso < .001: return
	var base := _j._char_model.global_basis.orthonormalized()
	var inclinacao := Basis(Vector3.RIGHT, 1.80 * peso) if tipo == "agua" else Basis(Vector3.FORWARD, .08 * peso)
	if tipo == "agua":
		inclinacao = Basis(Vector3.UP, -.65 * peso) * inclinacao
	var orientacao := base * inclinacao
	var nos: Dictionary = _j._proc_anim._n
	if not nos.has("Wrist_R") or not nos.has("Head"): return
	var mao := _j._rig.item_handle
	var boca: Vector3 = (nos["Head"] as Node3D).to_global(Vector3(0, .136, -.246))
	var contato := contato_local()
	var alvo := mao.global_position.lerp(boca - orientacao * contato, peso)
	var polo := _j._char_model.global_basis.orthonormalized() * Vector3(1, -.65, .15)
	# Usa a pega como efetor: punho e mão pertencem ao segmento do antebraço.
	# Assim o contato considera o comprimento real até o item, sem alongar ossos.
	YoruRig.solve_two_bone(nos["UpperArm_R"], nos["ForeArm_R"], mao, alvo, polo)
	if is_instance_valid(visual):
		visual.global_basis = orientacao

## Ponto do item (no espaço local do `visual`) que deve tocar a boca: o gargalo da bebida; o pão/comida vai com a mão. O modelo voxel é centrado
## (a boca da garrafa fica ~10 cm acima do centro); o modelo antigo tinha o pivô na pega (gargalo a 20,4 cm).
func contato_local() -> Vector3:
	if tipo != "agua": return Vector3.ZERO
	return Vector3(0, 0.10 if AlimentosVoxel.cena(variante) != null else 0.204, 0)

func _tirar_visual() -> void:
	if is_instance_valid(visual):
		visual.get_parent().remove_child(visual)
		visual.queue_free()
	visual = null
	_tipo_visual = ""

func _exit_tree() -> void:
	cancelar()
	_tirar_visual()
