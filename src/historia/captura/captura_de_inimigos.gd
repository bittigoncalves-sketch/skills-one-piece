class_name CapturaDeInimigos
extends Node
# ============================================================================
#  POKÉBOLA (30/10/2026) — a captura de inimigos, no estilo do ARCO do Minecraft 1.20.1.
#
#  Com o item "pokebola" ativo (tecla 4 no kit inicial) aparece um CUBO NA MÃO. Segura-se o
#  BOTÃO DIREITO para PUXAR e solta-se para ATIRAR, como o arco. Medido no jar do cliente 1.20.1
#  (BowItem, Projectile, AbstractArrow, LocalPlayer, AbstractClientPlayer; REA para extrair,
#  Vineflower para ler — nada do código dele é copiado, só os números):
#    • potência  p = min((x² + 2x) / 3, 1), x = ticks puxados / 20  → cheia em 1 s, 0,42 em 0,5 s;
#    • p < 0,1 (≈ 0,15 s) não atira: soltar cedo só cancela;
#    • velocidade da bola = p × 3 blocos/tick (52,8 m/s cheia); imprecisão gaussiana 0,0172275
#      por eixo; soma a velocidade horizontal de quem atira (a vertical só no ar);
#    • gravidade 0,05 e atrito 0,99 por tick (na bola: `pokebola_arremessada.gd`);
#    • puxando, o movimento do jogador vai a 20 % (LocalPlayer: entrada × 0,2);
#    • puxando, o campo de visão fecha até 15 % conforme o tempo (AbstractClientPlayer);
#    • potência 1,0 é o "crítico" (rastro de faíscas); o som é o `entity.arrow.shoot` do mod.
#
#  ANIMAÇÃO (30/10/2026): puxando, o braço direito sobe (`right_arm_up` do mod, segura o último quadro); ao soltar, o braço
#  vai à frente (`right_arm_front`) por `DURACAO_DO_LANCAMENTO` e o cubo some da mão até ele voltar (a bola saiu). As poses
#  vêm de `tools/mine_piece/importar_captura.py` e entram pelas mesmas metas do corpo que as técnicas usam.
#
#  Acertar um inimigo VIVO de vida vermelha (`Estilo.LIMITE_VERMELHO`) o captura (regra no
#  `Recrutamento`); com vida alta a bola só some. A bola não se gasta. Trocar de item, abrir um menu ou
#  morrer enquanto puxa CANCELA sem atirar. Solo/servidor apenas.
# ============================================================================
const Bola := preload("res://src/historia/captura/pokebola_arremessada.gd")
const META_MAO := &"pokebola_na_mao"
const META_LENTIDAO := &"arco_fator_velocidade"
const GRUPOS_DE_ALVO: Array[String] = ["enemy", "animais", "bestas_do_mar"]
const TICK := 0.05                      # um tick do Minecraft
const BLOCO := 0.88                     # metros por bloco do mod
const TICKS_DE_CARGA_CHEIA := 20.0
const POTENCIA_MINIMA := 0.1
const BLOCOS_POR_TICK_CHEIA := 3.0
const IMPRECISAO := 0.0172275
const FATOR_DE_MOVIMENTO := 0.2
const ZOOM_MAXIMO := 0.15
const LADO_DO_CUBO := 0.2
const ALCANCE_DA_MIRA := 64.0
const ARQUIVO_DE_POSES := "res://assets/mine_piece/captura/poses.json"
const POSE_PUXAR := "right_arm_up"
const POSE_LANCAR := "right_arm_front"
const DURACAO_DO_LANCAMENTO := 0.35
const MARCA_DA_POSE := &"pose_da_captura"
## ESTOQUE (08/11/2026, pedido do dono): cada arremesso gasta 1 pokébola; o jogador começa com 3 e ganha mais 3 a cada 5 minutos de jogo
## (até `MAXIMO_DE_BOLAS`). Mora em `progressao.sistemas["pokebolas"]` ({n, relogio}), então vai no save sem mexer no formato dele.
## A chance de capturar sai de `ProbabilidadeDeCaptura` (raridade × vida), não mais de "vida vermelha".
const SISTEMA := "pokebolas"
const INICIAIS := 3
const BOLAS_POR_RECARGA := 3
const INTERVALO_DE_RECARGA := 300.0
const MAXIMO_DE_BOLAS := 99
static var _poses: Dictionary = {}
var _relogio := -1.0

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var recrutamento: Node
var hud: Node

var _visual: Node3D
var _puxando := false
var _t := 0.0                           # segundos puxando
var _clipe := ""
var _clipe_t := 0.0
var _lancando := 0.0                    # segundos que faltam do braço à frente


## BowItem.getPowerForTime: `ticks` puxados → potência 0..1.
static func potencia_para(segundos: float) -> float:
	var x := segundos / TICK / TICKS_DE_CARGA_CHEIA
	return minf((x * x + x * 2.0) / 3.0, 1.0)


## Velocidade de saída em m/s para a potência `p` (p × 3 blocos por tick).
static func velocidade_para(p: float) -> float:
	return p * BLOCOS_POR_TICK_CHEIA * BLOCO / TICK


func puxando() -> bool:
	return _puxando


func potencia_atual() -> float:
	return potencia_para(_t) if _puxando else 0.0


## Pokébolas no inventário.
func quantidade() -> int:
	if progressao == null:
		return 0
	var d := progressao.dados_de(SISTEMA)
	return int(d.get("n", INICIAIS))


func segundos_para_recarga() -> float:
	return maxf(INTERVALO_DE_RECARGA - maxf(_relogio, 0.0), 0.0)


func _gravar(n: int) -> void:
	progressao.gravar_dados(SISTEMA, {"n": clampi(n, 0, MAXIMO_DE_BOLAS), "relogio": maxf(_relogio, 0.0)})


func dar(n: int) -> void:
	if progressao != null and n > 0:
		_gravar(quantidade() + n)


## Gasta uma pokébola; false se não há.
func gastar() -> bool:
	if quantidade() <= 0:
		return false
	_gravar(quantidade() - 1)
	return true


func _recarregar(delta: float) -> void:
	if _relogio < 0.0:       # primeiro quadro: retoma o relógio do save
		_relogio = float(progressao.dados_de(SISTEMA).get("relogio", 0.0))
		if not progressao.sistemas.has(SISTEMA):
			_gravar(INICIAIS)
	_relogio += delta
	if _relogio >= INTERVALO_DE_RECARGA:
		_relogio -= INTERVALO_DE_RECARGA
		var antes := quantidade()
		dar(BOLAS_POR_RECARGA)
		if hud != null:
			hud.call("avisar", "+%d pokébolas (%d no total)" % [quantidade() - antes, quantidade()])


func _process(delta: float) -> void:
	if progressao == null:
		return
	_recarregar(delta)
	if progressao.item_em_uso() == "pokebola":
		_segurar()
	else:
		_soltar_cubo()
		if _puxando:
			cancelar()
	if _puxando:
		var jogador: Node3D = jogador_de.call() if jogador_de.is_valid() else null
		if jogador == null or float(jogador.get("health")) <= 0.0 or (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open")):
			cancelar()
			return
		_t += delta
		_aplicar_efeitos(jogador)
	_animar(delta)


# ------------------------------------------------------------------ puxar / atirar
## Botão direito apertado (a HUD chama).
func comecar_a_puxar() -> bool:
	if _puxando or progressao == null or progressao.item_em_uso() != "pokebola":
		return false
	var jogador: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if jogador == null or float(jogador.get("health")) <= 0.0:
		return false
	if quantidade() <= 0:
		if hud != null:
			var falta := segundos_para_recarga()
			hud.call("avisar", "Sem pokébolas · +%d em %d:%02d" % [BOLAS_POR_RECARGA, int(falta) / 60, int(falta) % 60])
		return false
	_puxando = true
	_t = 0.0
	_lancando = 0.0
	_pose(POSE_PUXAR)
	return true


## Botão direito solto (a HUD chama): atira se a potência chegou ao mínimo; senão, cancela.
func soltar() -> bool:
	if not _puxando:
		return false
	var p := potencia_para(_t)
	var jogador: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	_puxando = false
	_limpar_efeitos(jogador)
	if p < POTENCIA_MINIMA or jogador == null:
		_limpar_pose()          # soltou cedo: só abaixa o braço
		return false
	if not gastar():
		_limpar_pose()
		return false
	_atirar(jogador, p)
	if hud != null:
		hud.call("avisar", "Pokébolas: %d" % quantidade())
	_lancando = DURACAO_DO_LANCAMENTO
	_pose(POSE_LANCAR)
	return true


func cancelar() -> void:
	if not _puxando:
		return
	_puxando = false
	_lancando = 0.0
	_limpar_efeitos(jogador_de.call() if jogador_de.is_valid() else null)
	_limpar_pose()


func _atirar(jogador: Node3D, p: float) -> void:
	var origem := _origem(jogador)
	var camera: Camera3D = jogador.get("_cam") if jogador.get("_cam") != null else null
	var rumo := -jogador.global_basis.z
	if camera != null and is_instance_valid(camera):
		var ponto := AlvosDeGolpe.ponto_mirado(jogador.get_world_3d(), camera.global_position, -camera.global_basis.z,
			ALCANCE_DA_MIRA, [(jogador as CollisionObject3D).get_rid()])
		rumo = (ponto - origem).normalized()
	# Projectile.shoot: direção unitária + ruído gaussiano por eixo, depois × velocidade.
	var direcao := (rumo + Vector3(randfn(0.0, IMPRECISAO), randfn(0.0, IMPRECISAO), randfn(0.0, IMPRECISAO))).normalized()
	var velocidade := direcao * velocidade_para(p)
	# shootFromRotation soma a velocidade de quem atira; a vertical só se estiver no ar.
	var dele: Vector3 = jogador.get("velocity") if jogador.get("velocity") != null else Vector3.ZERO
	var no_chao: bool = jogador.has_method("is_on_floor") and jogador.is_on_floor()
	velocidade += Vector3(dele.x, 0.0 if no_chao else dele.y, dele.z)
	var bola := Bola.new()
	bola.captura = self
	bola.dono = jogador
	bola.velocidade = velocidade
	bola.critica = p >= 1.0
	jogador.get_tree().current_scene.add_child(bola)
	bola.global_position = origem
	# BowItem: som da flecha, tom 1 / (rand × 0,4 + 1,2) + p × 0,5.
	McVisual.som(jogador.get_tree(), "entity.arrow.shoot", McVec3.de_godot(origem), 1.0, 1.0 / (randf() * 0.4 + 1.2) + p * 0.5)


## Chamado pela bola ao acertar um corpo.
func acertou(alvo: Node3D) -> void:
	if recrutamento == null:
		return
	var t: Dictionary = recrutamento.sortear_arremesso(alvo, ProbabilidadeDeCaptura.BOLAS["pokebola"])
	var r: int = int(t["resultado"])
	# Alvo capturável (sucesso OU escape pelo sorteio): ANIMA — a bola cai, chacoalha e, no sucesso, solta 3 estrelas (sem texto).
	if r == recrutamento.Resultado.CAPTURADO or r == recrutamento.Resultado.ESCAPOU:
		_animar_captura(alvo, t)
		return
	if hud == null:
		return
	var texto: String
	if r == recrutamento.Resultado.ESCAPOU:
		texto = "Escapou! Chacoalhou %d× · %s · chance %d%% com a vida em %d%%" % [int(t["chacoalhadas"]), str(t["raridade"]),
			roundi(float(t["chance"]) * 100.0), roundi(recrutamento.fracao_de_vida(alvo) * 100.0)]
	else:
		texto = recrutamento.mensagem(r, alvo)
	if not texto.is_empty():
		hud.call("avisar", texto)


## Esconde e congela a criatura, solta a `AnimacaoDeCaptura` no chão dela e, ao fim, captura de verdade ou devolve a criatura.
func _animar_captura(alvo: Node3D, t: Dictionary) -> void:
	var modo_antes := alvo.process_mode
	alvo.set_meta("em_captura", true)
	alvo.visible = false
	alvo.process_mode = Node.PROCESS_MODE_DISABLED
	var anim := AnimacaoDeCaptura.new()
	anim.chacoalhadas = int(t["chacoalhadas"])
	anim.capturou = bool(t["capturou"])
	var chao := alvo.global_position
	var centro := AlvosDeGolpe.centro(alvo)
	anim.altura_inicial = clampf(centro.y - chao.y, 0.3, 3.0)
	var texto_falha := "Escapou! Chacoalhou %d× · %s · chance %d%% com a vida em %d%%" % [int(t["chacoalhadas"]), str(t["raridade"]),
		roundi(float(t["chance"]) * 100.0), roundi(recrutamento.fracao_de_vida(alvo) * 100.0)]
	anim.ao_terminar = func(capturou: bool) -> void:
		if not is_instance_valid(alvo):
			return
		alvo.remove_meta("em_captura")
		alvo.process_mode = modo_antes
		if capturou:
			recrutamento.capturar(alvo, false)        # sem texto: as estrelas são a resposta
		else:
			alvo.visible = true
			if hud != null:
				hud.call("avisar", texto_falha)
	var cena := alvo.get_tree().current_scene
	cena.add_child(anim)
	anim.global_position = chao


## Corpo que a bola pode acertar: inimigo, bicho ou besta, vivo e que não seja do jogador.
static func e_alvo(no: Node) -> bool:
	if not (no is Node3D) or not is_instance_valid(no) or no.is_in_group("player") or no.has_meta("membro_tripulacao"):
		return false
	for g in GRUPOS_DE_ALVO:
		if no.is_in_group(g):
			return no.get("health") != null and float(no.get("health")) > 0.0
	return false


# ---------------------------------------------------- lentidão e zoom enquanto puxa
func _aplicar_efeitos(jogador: Node) -> void:
	jogador.set_meta(META_LENTIDAO, FATOR_DE_MOVIMENTO)
	var rig: Variant = jogador.get("_camera")
	if rig != null:
		rig.set("fator_fov", 1.0 - minf(_t / TICK / TICKS_DE_CARGA_CHEIA, 1.0) * ZOOM_MAXIMO)


func _limpar_efeitos(jogador: Variant) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	if jogador.has_meta(META_LENTIDAO):
		jogador.remove_meta(META_LENTIDAO)
	var rig: Variant = jogador.get("_camera")
	if rig != null:
		rig.set("fator_fov", 1.0)


func _exit_tree() -> void:
	_limpar_efeitos(jogador_de.call() if jogador_de.is_valid() else null)
	_limpar_pose()


# ------------------------------------------------------------------ animação do braço
static func _carregar_poses() -> void:
	if _poses.is_empty() and FileAccess.file_exists(ARQUIVO_DE_POSES):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_DE_POSES))
		if d is Dictionary:
			_poses = d


func _pose(nome: String) -> void:
	_carregar_poses()
	if nome != _clipe:
		_clipe = nome
		_clipe_t = 0.0


## Puxando: braço para cima (segura o último quadro). Lançando: braço à frente, e o cubo some da mão até acabar.
func _animar(delta: float) -> void:
	var jogador: Node = jogador_de.call() if jogador_de.is_valid() else null
	if jogador == null:
		return
	if _lancando > 0.0:
		_lancando -= delta
		if _lancando <= 0.0:
			_limpar_pose()
	elif not _puxando and _clipe.is_empty():
		return
	if _clipe.is_empty() or not _poses.has(_clipe):
		return
	_clipe_t += delta
	var clipe: Dictionary = _poses[_clipe]
	var quadro := mini(int(_clipe_t * float(clipe.fps)), (clipe.quadros as Array).size() - 1)
	var peso := smoothstep(0.0, 0.08, _clipe_t)
	var rotacoes := {}
	for papel: String in clipe.quadros[quadro]:
		var a: Array = clipe.quadros[quadro][papel]
		rotacoes[papel] = Vector3(a[0], a[1], a[2]) * PI / 180.0 * peso
	var posicoes := {}
	for papel: String in clipe.posicoes[quadro]:
		var a: Array = clipe.posicoes[quadro][papel]
		posicoes[papel] = Vector3(a[0], a[1], a[2]) * peso
	jogador.set_meta("pose_de_skill", rotacoes)
	jogador.set_meta("posicoes_mine_piece", posicoes)
	jogador.set_meta(MARCA_DA_POSE, true)
	if _visual != null and is_instance_valid(_visual):
		_visual.visible = _lancando <= 0.0     # a bola saiu: a mão fica vazia até o braço voltar


## Só tira o que ESTA animação pôs (a marca), para não apagar a pose de uma técnica.
func _limpar_pose() -> void:
	_clipe = ""
	_clipe_t = 0.0
	_lancando = 0.0
	var jogador: Node = jogador_de.call() if jogador_de.is_valid() else null
	if jogador != null and is_instance_valid(jogador) and jogador.has_meta(MARCA_DA_POSE):
		for meta in ["pose_de_skill", "posicoes_mine_piece", MARCA_DA_POSE]:
			if jogador.has_meta(meta):
				jogador.remove_meta(meta)
	if _visual != null and is_instance_valid(_visual):
		_visual.visible = true


# ---------------------------------------------------------------------- cubo na mão
## De onde a bola sai: a mão, se ela estiver acima da cintura; senão (rig sem pose, ex.: testes) o peito.
func _origem(jogador: Node) -> Vector3:
	var corpo := jogador as Node3D
	var peito := corpo.global_position + Vector3.UP * 1.3 - corpo.global_basis.z * 0.4
	var rig: Variant = jogador.get("_rig")
	var mao: Variant = rig.get("item_handle") if rig != null else null
	if mao is Node3D and is_instance_valid(mao) and (mao as Node3D).global_position.y > corpo.global_position.y + 0.6:
		return (mao as Node3D).global_position
	return peito


func segurando() -> bool:
	return _visual != null and is_instance_valid(_visual) and _visual.is_inside_tree()


func _segurar() -> void:
	var jogador: Node = jogador_de.call() if jogador_de.is_valid() else null
	if jogador == null:
		return
	var rig: Variant = jogador.get("_rig")
	var mao: Variant = rig.get("item_handle") if rig != null else null
	if not (mao is Node3D) or not is_instance_valid(mao):
		return
	# O rig pode ser remontado (troca de corpo): a mão é outra, prende de novo.
	if _visual == null or not is_instance_valid(_visual) or _visual.get_parent() != mao:
		_soltar_cubo()
		_visual = _montar_cubo()
		(mao as Node3D).add_child(_visual)
	jogador.set_meta(META_MAO, true)


func _soltar_cubo() -> void:
	if _visual != null and is_instance_valid(_visual):
		if _visual.get_parent() != null:
			_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null
	var jogador: Node = jogador_de.call() if jogador_de.is_valid() else null
	if jogador != null and jogador.has_meta(META_MAO):
		jogador.remove_meta(META_MAO)


## Um cubo vermelho em cima, branco embaixo, com a faixa preta e o botão: a "pokébola" quadrada.
func _montar_cubo() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "PokebolaNaMao"
	raiz.position = Vector3(0, 0.1, 0.06)    # na palma, como a fruta na mão
	_caixa(raiz, "Topo", Vector3(LADO_DO_CUBO, LADO_DO_CUBO * 0.45, LADO_DO_CUBO), Vector3(0, LADO_DO_CUBO * 0.275, 0), Color(0.88, 0.26, 0.22))
	_caixa(raiz, "Base", Vector3(LADO_DO_CUBO, LADO_DO_CUBO * 0.45, LADO_DO_CUBO), Vector3(0, -LADO_DO_CUBO * 0.275, 0), Color(0.96, 0.96, 0.97))
	_caixa(raiz, "Faixa", Vector3(LADO_DO_CUBO * 1.02, LADO_DO_CUBO * 0.1, LADO_DO_CUBO * 1.02), Vector3.ZERO, Color(0.08, 0.09, 0.11))
	_caixa(raiz, "Botao", Vector3(LADO_DO_CUBO * 0.26, LADO_DO_CUBO * 0.26, LADO_DO_CUBO * 0.06), Vector3(0, 0, LADO_DO_CUBO * 0.5), Color(0.96, 0.96, 0.97))
	return raiz


func _caixa(pai: Node3D, nome: String, tamanho: Vector3, posicao: Vector3, cor: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = nome
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	m.mesh = caixa
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.55
	m.material_override = material
	m.position = posicao
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(m)
