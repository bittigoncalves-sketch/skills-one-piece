class_name CliqueDeBlocos
extends Node
# ============================================================================
#  O CLIQUE DO MINECRAFT (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, etapa V5) — substitui o SOCO direcional do Modo História.
#
#    ESQUERDO  segurado: QUEBRA o bloco sob a mira (progresso = tempo × VELOCIDADE_DO_SOCO / (dureza × 1,5 s); mudar de bloco zera, como no Minecraft).
#              apertado olhando um bicho: BATE (recarga de 0,25 s: `Player.getAttackStrengthScale` → dano × (0,2 + 0,8·força²)).
#    DIREITO   num bloco de usar (porta, alçapão): abre/fecha. Com bloco na mão: COLOCA na face clicada (segurado repete a cada 0,2 s).
#              Num bicho: segue o caminho antigo (doma) — o Player trata.
#
#  Mira = o raio da CÂMERA; o alcance (4,5 blocos de 0,88 m, o do Minecraft) conta AO LONGO DO RAIO a partir do plano dos olhos, não em linha
#  reta a partir do corpo. Na câmera de FRENTE (F5) a mira é a do personagem (`CameraRig.direcao_da_mira`).
#  A física é a MESMA da grade (a colisão do terreno é a lista de triângulos das seções), então o raio de física devolve ponto e normal e a
#  célula sai de "ponto − normal·1 cm": vale para laje, escada e porta fina. Só blocos da grade são quebráveis/colocáveis; as construções
#  em .glb (V4) e as árvores ainda não — o raio as ignora como alvo.
#
#  A CHAVE (`ligado`): `SOCO_ANTIGO=1` volta ao soco direcional. Com a chave desligada o clique assume as mãos livres e o item "luta";
#  fruta, espada, vara etc. continuam com o combate de antes (são armas/skills, não o soco).
#  Regras portadas do Minecraft 1.20.1 (`MultiPlayerGameMode`, `BlockBehaviour.getDestroyProgress`, `Player.getDestroySpeed`, `Minecraft.startUseItem`):
#  progresso por tick = velocidade / dureza / 30 (100 sem a ferramenta certa — desligado, ver `ItensDeBloco.aplicar_ferramenta`); velocidade ÷5 no ar;
#  atraso de 5 ticks depois de quebrar; o direito não age enquanto se quebra; o bloco é "usado" (porta) antes de ser colocado.
#
#  O que NÃO existe ainda (gatilho: pedido do dono): braço balançando, som/partículas de quebra, ferramenta acelerando, bloco caindo no chão
#  como entidade (o drop vai direto ao inventário; sem espaço, perde-se), rede (`McRede`: hoje a edição é local).
# ============================================================================

## O clique do Minecraft está ligado? (`SOCO_ANTIGO=1` no ambiente religa o soco, para os testes antigos e a comparação.)
static var ligado := OS.get_environment("SOCO_ANTIGO") != "1"

const ALCANCE_BLOCOS := 4.5
const ALCANCE := ALCANCE_BLOCOS * GradeVoxel.BLOCO
const ALCANCE_BICHO := 3.0 * GradeVoxel.BLOCO
const ALTURA_DOS_OLHOS := 1.6
## Velocidade do soco (pedido do dono, 11/11/2026: "dobra a velocidade do soco"): multiplica o ritmo de QUEBRAR e de BATER.
## O filtro de invulnerabilidade do Minecraft no alvo (`CombatResolver.filtro_minecraft`, 0,5 s) continua limitando o dano em bicho.
const VELOCIDADE_DO_SOCO := 2.0
const RECARGA := 0.25 / VELOCIDADE_DO_SOCO
## `MultiPlayerGameMode.destroyDelay = 5` ticks: depois de quebrar um bloco, segurar o botão só começa o próximo depois disto.
const ATRASO_APOS_QUEBRAR := 0.25 / VELOCIDADE_DO_SOCO
## `Player.getDestroySpeed`: no ar (sem pisar no chão) a velocidade de quebra cai a 1/5.
const FATOR_NO_AR := 0.2
const REPETIR_COLOCACAO := 0.2
const DANO_DA_MAO := 20.0 * Balance.HISTORIA_SOCO       # o jab do boxe (20) com o fator do soco da história
const EMPURRAO := 3.0

signal quebrou(celula: Vector3i, valor: int)
signal colocou(celula: Vector3i, valor: int)
signal bateu(alvo: Node, dano: float)
signal avisou(texto: String)

var jogador: Node3D
var progressao: ProgressaoDoPersonagem
## Quem diz se o mouse é do jogo (capturado, sem menu). Os testes trocam por um que devolve true.
var mira_ativa := func() -> bool: return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or ToqueHud.ativo()

var progresso := 0.0                                    # 0..1 do bloco sob a mira
var celula_alvo := Vector3i.ZERO
var tem_alvo := false
var _grade: GradeVoxel
var _atraso := 0.0                                      # destroyDelay: segundos até poder começar a quebrar de novo
var _t_golpe := 99.0
var _t_colocar := 99.0
var _esq_antes := false
var _dir_antes := false
var _caixa: MeshInstance3D
var _rachadura: MeshInstance3D


func montar(j: Node3D, prog: ProgressaoDoPersonagem) -> void:
	jogador = j
	progressao = prog


func _ready() -> void:
	_caixa = MeshInstance3D.new()
	_caixa.name = "ContornoDoBloco"
	_caixa.top_level = true
	_caixa.visible = false
	_caixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_caixa)
	_rachadura = MeshInstance3D.new()
	_rachadura.name = "RachaduraDoBloco"
	_rachadura.top_level = true
	_rachadura.visible = false
	_rachadura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rachadura)


## As mãos são do clique? (livres ou o item "luta" — o soco; o resto dos itens tem o combate de sempre)
func assume_as_maos() -> bool:
	if not ligado or progressao == null:
		return false
	var em_uso := progressao.item_em_uso()
	return em_uso == "" or em_uso == "luta"


# =================================================================== A MIRA
## O que está sob a mira: `{"tipo": &"bloco", grade, celula, normal(Vector3i), ponto, y_na_face}` | `{"tipo": &"bicho", corpo, ponto}` |
## `{"tipo": &"nada"}`. `de`/`dir`: origem e direção do raio (a câmera). Os olhos limitam o alcance.
##
## BLOCOS pelos DADOS, não pela física: um raio que percorre as células da grade (Amanatides–Woo) e testa a forma de cada bloco (laje, escada,
## porta fina). Assim a mira vê o bloco recém-colocado ou recém-quebrado NA HORA — a colisão do terreno só chega depois da thread de malha — e a
## célula/face saem exatas, sem "ponto − normal". A física só responde pelos BICHOS (e por quem tapa a vista: uma parede de .glb).
func alvo_em(de: Vector3, dir: Vector3) -> Dictionary:
	if jogador == null or not is_instance_valid(jogador) or not jogador.is_inside_tree():
		return {"tipo": &"nada"}
	dir = dir.normalized()
	# ALCANCE A PARTIR DA MIRA (pedido do dono): conta ao longo do raio da mira, a partir do plano dos olhos — e não a distância em linha reta
	# do corpo ao ponto, que recusava o bloco que está sob a mira só por estar de lado.
	var olhos := jogador.global_position + Vector3.UP * ALTURA_DOS_OLHOS
	var t_olhos := maxf((olhos - de).dot(dir), 0.0)
	var comprimento := t_olhos + maxf(ALCANCE, ALCANCE_BICHO) + 0.5
	var par := PhysicsRayQueryParameters3D.create(de, de + dir * comprimento)
	par.exclude = _corpos_do_jogador()
	var fisico := jogador.get_world_3d().direct_space_state.intersect_ray(par)
	var t_fisico := INF
	var corpo: Node = null
	if not fisico.is_empty():
		t_fisico = de.distance_to(fisico.position)
		corpo = fisico.collider as Node
	var e_bicho := corpo != null and corpo.has_method("take_damage") and not (corpo is StaticBody3D)
	var bloco := raio_de_blocos(de, dir, comprimento)
	var t_bloco: float = bloco.t if not bloco.is_empty() else INF
	if e_bicho and t_fisico < t_bloco:
		return {"tipo": &"bicho", "corpo": corpo, "ponto": fisico.position} \
			if t_fisico - t_olhos <= ALCANCE_BICHO else {"tipo": &"nada"}
	if bloco.is_empty():
		return {"tipo": &"nada"}
	# algo que não é terreno (parede de uma construção .glb) na frente do bloco tapa a vista
	if corpo != null and not e_bicho and t_fisico < t_bloco - 0.05 and corpo.get_node_or_null("Grade") == null:
		return {"tipo": &"nada"}
	if t_bloco - t_olhos > ALCANCE:
		return {"tipo": &"nada"}
	var origem_da_celula := Vector3(bloco.celula) * GradeVoxel.BLOCO
	bloco["tipo"] = &"bloco"
	bloco["y_na_face"] = clampf((bloco.ponto.y - origem_da_celula.y) / GradeVoxel.BLOCO, 0.0, 1.0)
	return bloco


## O primeiro bloco da grade que o raio acerta, com a forma de verdade: `{t, celula, normal, ponto, grade}` ou `{}`.
func raio_de_blocos(de: Vector3, dir: Vector3, maximo: float) -> Dictionary:
	var b := GradeVoxel.BLOCO
	var c := GradeVoxel.celula_em(de)
	var passo := Vector3i(int(signf(dir.x)), int(signf(dir.y)), int(signf(dir.z)))
	var t_max := Vector3(INF, INF, INF)
	var t_delta := Vector3(INF, INF, INF)
	for i in 3:
		if dir[i] != 0.0:
			var borda := (float(c[i] + (1 if passo[i] > 0 else 0))) * b
			t_max[i] = (borda - de[i]) / dir[i]
			t_delta[i] = b / absf(dir[i])
	var t := 0.0
	while t <= maximo:
		var g := grade_de(c)
		if g != null:
			var v := g.obter(c)
			if v != TiposDeBloco.AR and TiposDeBloco.tipo_de(v) != TiposDeBloco.AGUA:
				var hit := _acertar_forma(de, dir, c, v)
				if not hit.is_empty() and hit.t <= maximo:
					hit["celula"] = c
					hit["grade"] = g
					return hit
		var eixo := 0
		if t_max.y < t_max[eixo]:
			eixo = 1
		if t_max.z < t_max[eixo]:
			eixo = 2
		t = t_max[eixo]
		t_max[eixo] += t_delta[eixo]
		c[eixo] += passo[eixo]
	return {}


## O raio contra as caixas do bloco da célula `c`: a mais próxima, `{t, normal(Vector3i), ponto}`.
static func _acertar_forma(de: Vector3, dir: Vector3, c: Vector3i, v: int) -> Dictionary:
	var melhor := {}
	var t_melhor := INF
	for caixa in _caixas_do_valor(c, v):
		var r := _raio_contra_caixa(de, dir, caixa)
		if not r.is_empty() and r.t < t_melhor:
			t_melhor = r.t
			melhor = r
	return melhor


static func _raio_contra_caixa(de: Vector3, dir: Vector3, caixa: AABB) -> Dictionary:
	var entrada := -INF
	var saida := INF
	var eixo := 0
	var lado := 1
	var a := caixa.position
	var z := caixa.end
	for i in 3:
		if absf(dir[i]) < 0.000001:
			if de[i] < a[i] or de[i] > z[i]:
				return {}
			continue
		var t1: float = (a[i] - de[i]) / dir[i]
		var t2: float = (z[i] - de[i]) / dir[i]
		var perto := minf(t1, t2)
		if perto > entrada:
			entrada = perto
			eixo = i
			lado = 1 if dir[i] < 0.0 else -1               # entrou pela face voltada para a origem
		saida = minf(saida, maxf(t1, t2))
	if entrada > saida or saida < 0.0 or entrada < 0.0:
		return {}                                           # errou, ou a origem já está dentro (a câmera dentro do bloco não mira nele)
	var n := Vector3i.ZERO
	n[eixo] = lado
	return {"t": entrada, "normal": n, "ponto": de + dir * entrada}


## As caixas do bloco em coordenadas do mundo: o cubo inteiro é uma; escada/laje/octantes são um cubinho por octante ocupado; porta, painel
## e alçapão são as caixas finas.
static func _caixas_do_valor(c: Vector3i, v: int) -> Array[AABB]:
	var b := GradeVoxel.BLOCO
	var origem := Vector3(c) * b
	var saida: Array[AABB] = []
	var oct := TiposDeBloco.octantes(v)
	if oct == 0xFF:
		saida.append(AABB(origem, Vector3.ONE * b))
	elif oct != 0:
		for i in 8:
			if oct & (1 << i) != 0:
				saida.append(AABB(origem + Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) * (b * 0.5), Vector3.ONE * (b * 0.5)))
	else:
		for k in TiposDeBloco.caixas(v):
			saida.append(AABB(origem + Vector3(k[0], k[1], k[2]) / 16.0 * b, Vector3(k[3] - k[0], k[4] - k[1], k[5] - k[2]) / 16.0 * b))
	return saida


## O corpo do jogador E os corpos filhos dele (a `Hurtbox` é um StaticBody3D): sem isto, mirar para baixo/para cima acerta o PRÓPRIO corpo
## e a mira vira "nada". Refeito a cada segundo (os filhos mudam com a fruta/arma).
var _excluir: Array[RID] = []
var _excluir_ate := 0
func _corpos_do_jogador() -> Array[RID]:
	var agora := Time.get_ticks_msec()
	if agora >= _excluir_ate:
		_excluir.clear()
		if jogador is CollisionObject3D:
			_excluir.append((jogador as CollisionObject3D).get_rid())
		for n in jogador.find_children("*", "CollisionObject3D", true, false):
			_excluir.append((n as CollisionObject3D).get_rid())
		_excluir_ate = agora + 1000
	return _excluir


func _mira_da_camera() -> Dictionary:
	if jogador == null or not jogador.is_inside_tree():
		return {"tipo": &"nada"}
	var rig: Object = jogador.rig_da_camera() if jogador.has_method("rig_da_camera") else null   # sem tipo: o CameraRig depende de autoload
	if rig != null and rig.em_frente():
		# câmera de FRENTE: ela olha para o personagem; a mira é a dele, dos olhos para onde ele olha
		return alvo_em(jogador.global_position + Vector3.UP * ALTURA_DOS_OLHOS, rig.direcao_da_mira())
	var cam := jogador.get_viewport().get_camera_3d()
	if cam == null:
		return {"tipo": &"nada"}
	return alvo_em(cam.global_position, -cam.global_transform.basis.z)


## A grade de terreno cuja coluna contém a célula (a mesma pergunta do `McRelevoCavavel.ilha_em`).
func grade_de(c: Vector3i) -> GradeVoxel:
	if is_instance_valid(_grade) and _grade.gerador != null and _grade.gerador.contem_coluna(c):
		return _grade
	for n in get_tree().get_nodes_in_group(GradeVoxel.GRUPO):
		var g := n as GradeVoxel
		if g != null and g.gerador != null and g.gerador.contem_coluna(c):
			_grade = g
			return g
	return null


# =================================================================== O QUADRO
func _physics_process(delta: float) -> void:
	if jogador == null or progressao == null:
		return
	var ativa: bool = mira_ativa.call()
	var esq := ativa and assume_as_maos() and Input.is_action_pressed(EntradaCorpoACorpo.ACAO_ATACAR)
	var dir := ativa and assume_as_maos() and Input.is_action_pressed(EntradaCorpoACorpo.ACAO_DEFENDER)
	avancar(delta, esq, dir, ativa and assume_as_maos())


## Um passo do clique com o estado dos botões (`esq`/`dir` segurados). Separado do `_physics_process` para o teste dirigir sem mouse.
func avancar(delta: float, esq: bool, dir: bool, mostrar_contorno := true) -> void:
	var mira := _mira_da_camera() if (mostrar_contorno or esq or dir) else {"tipo": &"nada"}
	avancar_com(mira, delta, esq, dir)


## O mesmo passo com a mira dada (o teste passa o alvo exato, sem câmera).
func avancar_com(mira: Dictionary, delta: float, esq: bool, dir: bool) -> void:
	_t_golpe += delta
	_t_colocar += delta
	_atualizar_contorno(mira)
	# ---- esquerdo
	if esq and mira.tipo == &"bicho":
		if not _esq_antes:
			bater(mira.corpo, mira.ponto)
		progresso = 0.0
	elif esq and mira.tipo == &"bloco":
		var c: Vector3i = mira.celula
		if not tem_alvo or c != celula_alvo:
			celula_alvo = c
			tem_alvo = true
			progresso = 0.0
		var g: GradeVoxel = mira.grade
		var tempo := ItensDeBloco.tempo_de_quebra(g.obter(c)) * ItensDeBloco.fator_sem_ferramenta(g.obter(c))
		if _atraso > 0.0:
			_atraso -= delta                                  # `continueDestroyBlock`: o atraso come o quadro, sem progresso
		elif tempo > 0.0:
			progresso += delta * VELOCIDADE_DO_SOCO * _fator_do_ar() / tempo
			if progresso >= 1.0:
				quebrar(g, c)
				progresso = 0.0
				_atraso = ATRASO_APOS_QUEBRAR
		_mostrar_rachadura(mira)
	else:
		progresso = 0.0
		tem_alvo = false
		if _rachadura != null:
			_rachadura.visible = false
	# ---- direito (como `startUseItem`: não usa nem coloca enquanto está quebrando)
	if dir and mira.tipo != &"bicho" and progresso <= 0.0:
		if not _dir_antes:
			if mira.tipo == &"bloco" and ItensDeBloco.usar(mira.grade, mira.celula):
				_t_colocar = 0.0
			else:
				_colocar_na_mira(mira)
		elif _t_colocar >= REPETIR_COLOCACAO:
			_colocar_na_mira(mira)
	_esq_antes = esq
	_dir_antes = dir


## `Player.getDestroySpeed`: no ar a quebra é 5× mais lenta. (Debaixo d'água também seria; ainda não há consulta de água na mira.)
func _fator_do_ar() -> float:
	if jogador != null and jogador.has_method("is_on_floor") and not jogador.is_on_floor():
		return FATOR_NO_AR
	return 1.0


# =================================================================== AS AÇÕES
## Quebra o bloco e põe o drop no inventário. Devolve o valor que havia.
func quebrar(g: GradeVoxel, c: Vector3i) -> int:
	var v := g.obter(c)
	if v == TiposDeBloco.AR or ItensDeBloco.tempo_de_quebra(v) < 0.0:
		return TiposDeBloco.AR
	var drop := ItensDeBloco.drop_de(v)
	RegrasDeBloco.quebrar(g, c)
	if int(drop.tipo) != 0 and int(drop.quantidade) > 0 and progressao != null:
		progressao.inventario.inserir(ItensDeBloco.nova_pilha(int(drop.tipo), int(drop.quantidade)))
	quebrou.emit(c, v)
	return v


## Bate no bicho com a força da recarga. Devolve o dano aplicado.
func bater(corpo: Node, ponto: Vector3) -> float:
	var forca := clampf(_t_golpe / RECARGA, 0.0, 1.0)
	_t_golpe = 0.0
	var dano := DANO_DA_MAO * (0.2 + forca * forca * 0.8)
	var de_onde := jogador.global_position
	var rumo := Vector3(ponto.x - de_onde.x, 0.0, ponto.z - de_onde.z)
	rumo = rumo.normalized() if rumo.length_squared() > 0.0001 else Vector3.FORWARD
	CombatResolver.aplicar(corpo, dano, 0, 0.0, ponto, rumo * EMPURRAO, 0.2, 0.0, false, jogador)
	bateu.emit(corpo, dano)
	return dano


## Bate no bicho sob a mira, se houver (o pedido de golpe por teclado/toque/teste, que não passa pelo botão do mouse).
func bater_no_que_esta_na_mira() -> bool:
	var mira := _mira_da_camera()
	if mira.tipo != &"bicho":
		return false
	bater(mira.corpo, mira.ponto)
	return true


## Botão direito com uma Akuma no Mi na mão (25/11/2026): come. Com fruta no corpo, o 1º clique avisa e o 2º (em até 4 s) confirma.
const DURACAO_DE_COMER_AKUMA := 2.4
var _confirma_id := ""
var _confirma_ate := 0


func _comer_akuma_da_mao() -> bool:
	var tag := InventarioMinecraft.id_de(progressao.inventario.na_mao())
	if not ItensDeFruta.e_akuma(tag):
		return false
	var agora := Time.get_ticks_msec()
	var ali: Node = jogador.get_node_or_null("AlimentacaoVisual")
	if ali != null and ali.has_method("comendo_akuma") and (ali.comendo() or ali.comendo_akuma()):
		return true                                        # já está comendo: o clique não faz nada
	var confirmado := _confirma_id == tag and agora < _confirma_ate
	var v := ItensDeFruta.comer(progressao, tag, confirmado, ali != null and ali.has_method("comer_akuma"))
	_confirma_id = tag if v.estado == "confirmar" else ""
	_confirma_ate = agora + 4000
	if v.estado == "pode":
		# Com o corpo na cena: gesto de comer (2,4 s, com sons); o poder só vale ao ENGOLIR e o gesto cortado devolve tudo como estava.
		var prog := progressao
		ali.comer_akuma(ItensDeFruta.id_de(tag), DURACAO_DE_COMER_AKUMA,
			func():
				var r := ItensDeFruta.comer(prog, tag, true)
				avisou.emit(str(r.texto)),
			func(): avisou.emit("Você parou de comer a %s" % ItensDeFruta.nome(tag)))
		return true
	avisou.emit(str(v.texto))
	return true


func _colocar_na_mira(mira: Dictionary) -> bool:
	_t_colocar = 0.0
	if mira.tipo != &"bloco" or progressao == null:
		return false
	var inv := progressao.inventario
	var pilha := inv.na_mao()
	var tipo := ItensDeBloco.tipo_do_item(InventarioMinecraft.id_de(pilha))
	if tipo == 0 or not pilha.quantidade > 0:
		return false
	var g: GradeVoxel = mira.grade
	var normal: Vector3i = mira.normal
	var y: float = mira.y_na_face
	# a laje clicada na face que falta se completa; senão o bloco vai para a célula vizinha na face clicada
	if ItensDeBloco.completar_laje(g, mira.celula, tipo, normal, y):
		_gastar(pilha)
		return true
	var alvo := (mira.celula as Vector3i) + normal
	var g2 := grade_de(alvo)
	if g2 == null or not ItensDeBloco.cabe(g2, alvo, tipo) or _ocupada_por_corpo(alvo, tipo):
		return false
	var olhar := _olhar()
	var escrito := ItensDeBloco.colocar(g2, alvo, tipo, normal, y, olhar)
	if escrito == 0:
		return false
	_gastar(pilha)
	colocou.emit(alvo, escrito)
	return true


func _gastar(pilha: McItem.Pilha) -> void:
	pilha.shrink(1)
	if pilha.isEmpty():
		progressao.inventario.slots[InventarioMinecraft.HOTBAR_INI + progressao.inventario.selecionado] = InventarioMinecraft.vazia()
	progressao.inventario.mudou.emit()


func _olhar() -> Vector3:
	var rig: Object = jogador.rig_da_camera() if jogador.has_method("rig_da_camera") else null   # sem tipo: o CameraRig depende de autoload
	if rig != null and rig.em_frente():
		return rig.direcao_da_mira()
	var cam := jogador.get_viewport().get_camera_3d() if jogador.is_inside_tree() else null
	return -cam.global_transform.basis.z if cam != null else -jogador.global_transform.basis.z


## O bloco novo cruzaria o corpo do jogador ou de um bicho? (o Minecraft recusa: `canBeReplaced` + `isUnobstructed`)
func _ocupada_por_corpo(c: Vector3i, tipo: int) -> bool:
	if TiposDeBloco.colide[tipo] == 0:
		return false
	var caixa := _caixa_da_celula(c, TiposDeBloco.valor(tipo))
	var corpos: Array[Node] = [jogador]
	corpos.append_array(get_tree().get_nodes_in_group("enemy"))
	corpos.append_array(get_tree().get_nodes_in_group(AlvosDeGolpe.GRUPO))
	for n in corpos:
		var b := n as Node3D
		if b == null or not is_instance_valid(b):
			continue
		var raio := 0.35 if b == jogador else 0.5
		var altura := 1.7 if b == jogador else 1.5
		var cobertura := AABB(b.global_position + Vector3(-raio, 0.02, -raio), Vector3(raio * 2.0, altura, raio * 2.0))
		if cobertura.intersects(caixa):
			return true
	return false


# =================================================================== VISUAL
## A caixa do bloco no mundo (a forma de verdade: laje é metade, porta é fina).
static func _caixa_da_celula(c: Vector3i, valor: int) -> AABB:
	var b := GradeVoxel.BLOCO
	var origem := Vector3(c) * b
	var oct := TiposDeBloco.octantes(valor)
	if oct != 0:
		var minimo := Vector3(1, 1, 1)
		var maximo := Vector3.ZERO
		for i in 8:
			if oct & (1 << i) != 0:
				var p := Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
				minimo = minimo.min(p * 0.5)
				maximo = maximo.max(p * 0.5 + Vector3.ONE * 0.5)
		return AABB(origem + minimo * b, (maximo - minimo) * b)
	var caixas := TiposDeBloco.caixas(valor)
	if not caixas.is_empty():
		var mn := Vector3(16, 16, 16)
		var mx := Vector3.ZERO
		for k in caixas:
			mn = mn.min(Vector3(k[0], k[1], k[2]))
			mx = mx.max(Vector3(k[3], k[4], k[5]))
		return AABB(origem + mn / 16.0 * b, (mx - mn) / 16.0 * b)
	return AABB(origem, Vector3.ONE * b)


func _atualizar_contorno(mira: Dictionary) -> void:
	if _caixa == null:
		return
	if mira.tipo != &"bloco":
		_caixa.visible = false
		return
	var g: GradeVoxel = mira.grade
	var caixa := _caixa_da_celula(mira.celula, g.obter(mira.celula)).grow(0.004)
	if _caixa.mesh == null:
		_caixa.mesh = _malha_de_linhas()
	_caixa.global_transform = Transform3D(Basis.from_scale(caixa.size), caixa.position)
	_caixa.visible = true


func _mostrar_rachadura(mira: Dictionary) -> void:
	if _rachadura == null:
		return
	if _rachadura.mesh == null:
		var m := BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0, 0, 0, 0.0)
		m.material = mat
		_rachadura.mesh = m
	var g: GradeVoxel = mira.grade
	var caixa := _caixa_da_celula(mira.celula, g.obter(mira.celula)).grow(0.006)
	_rachadura.global_transform = Transform3D(Basis.from_scale(caixa.size), caixa.get_center())
	((_rachadura.mesh as BoxMesh).material as StandardMaterial3D).albedo_color = Color(0, 0, 0, clampf(progresso, 0.0, 1.0) * 0.6)
	_rachadura.visible = progresso > 0.0


## 12 arestas de um cubo unitário (de 0 a 1), em linhas pretas; a escala do nó o ajusta à forma do bloco.
static func _malha_de_linhas() -> ArrayMesh:
	var v := PackedVector3Array()
	for a in 2:
		for b in 2:
			v.append_array([Vector3(0, a, b), Vector3(1, a, b), Vector3(a, 0, b), Vector3(a, 1, b), Vector3(a, b, 0), Vector3(a, b, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.surface_set_material(0, mat)
	return m


# =================================================================== PONTE COM O PLAYER
## O `Player` entrega os eventos de mouse aqui antes do caminho antigo. `true` = consumido (o soco/doma antigos não rodam).
func tratar(evento: InputEvent) -> bool:
	var botao := evento as InputEventMouseButton
	if botao == null or not assume_as_maos() or not mira_ativa.call():
		return false
	if botao.button_index == MOUSE_BUTTON_LEFT:
		return true
	if botao.button_index == MOUSE_BUTTON_RIGHT:
		if botao.pressed and _comer_akuma_da_mao():
			return true
		if ItensDeFruta.e_akuma(InventarioMinecraft.id_de(progressao.inventario.na_mao())):
			return true                                    # Akuma na mão: o botão direito é só para comer
		return _mira_da_camera().tipo != &"bicho"          # no bicho o botão direito segue para a doma
	return false
