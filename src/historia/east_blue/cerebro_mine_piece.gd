class_name CerebroMinePiece
extends Node
# ============================================================================
#  CÉREBRO DOS PERSONAGENS DO EAST BLUE — a IA do Mine Piece portada (17/10/2026).
#
#  PERSEGUIÇÃO e ALVO. Quem escolhe e executa as técnicas é a IA do mod (`IaDoMod`: a procedure do
#  `baseTick` → `minepiece:skill`); o plano B antigo, com skills do Skill Builder (`mpeb_*`) e números portados
#  à mão, SAIU em 27/10/2026 (AUDITORIA_FIDELIDADE_MINE_PIECE, A8). Sem IA do mod só resta o `MeleeAttackGoal`
#  vanilla (`_melee_vanilla`).
#    • decide a cada 10 tiques = `PERIODO` (0,5 s);
#    • alvo: o jogador dentro do alcance de perseguição (ficha) e da `ZONA` em volta de casa; quem bateu nele
#      (revide, como o HurtByTargetGoal) por `REVIDE_POR` s.
#
#  Facções (`LogicAttackTargetStart` do mod): "aliado" (tag group_1: Luffy, Zoro, Sanji,
#  Yosaku, Johnny, o bando do Shanks) NUNCA começa briga com o jogador, só revida; todos os
#  outros atacam o jogador (ele conta como pirata de bando próprio — decisão declarada).
#  Brigas ENTRE personagens por facção (marinha × piratas, bandos rivais) existem no mod,
#  mas ficam desligadas (`BRIGAS_ENTRE_FACCOES`) para as zonas não se esvaziarem sozinhas;
#  o revide entre eles continua. Gatilho para ligar: o dono pedir as brigas.
# ============================================================================

const PERIODO := 0.5
## Raio em volta de casa: além disto não persegue (as zonas da ilha não se misturam).
const ZONA := 28.0
## Detecção mínima (o atributo de perseguição do mod é 16).
const DETECCAO_MINIMA := 16.0
## Camuflagem Transparente: o inimigo só sente o jogador camuflado muito perto (ouve/esbarra); além disto o perde de vista.
const PERCEPCAO_DO_CAMUFLADO := 4.0
const REVIDE_POR := 20.0
const BRIGAS_ENTRE_FACCOES := false
## PERSEGUIÇÃO DO CHEFE (08/11/2026, pedido do dono: "os chefes não param de perseguir"). O chefe NUNCA desiste do jogador enquanto há uma
## missão de combate em andamento; sem missão, depois que ELE LEVOU DANO persegue até a METADE DA ILHA (em vez dos `ZONA` m de casa).
## Mobs comuns seguem como antes.
const META_ILHA_PADRAO := 120.0
var _sofreu_dano := false
var corpo: PersonagemMinePiece = null
var alvo: Node3D = null
var _relogio := 0.0
var _revide: Node3D = null
var _revide_ate := -INF
var _tempo := 0.0
var _passeio := Vector3.INF
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	corpo = get_parent() as PersonagemMinePiece
	_rng.randomize()
	_relogio = _rng.randf_range(0.0, PERIODO)   # personagens da mesma zona não decidem juntos


func reiniciar() -> void:
	_sofreu_dano = false
	alvo = null
	_revide = null
	cancelar()


func cancelar() -> void:
	if corpo != null:
		corpo.definir_movimento_de_skill(Vector3.ZERO, false, true)
		corpo.definir_flutuar(false)
		corpo.ocultar_corpo_por_skill(false)


func foi_atacado(quem: Node3D) -> void:
	if quem == null or quem == corpo:
		return
	_revide = quem
	_revide_ate = _tempo + REVIDE_POR
	_sofreu_dano = true


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"CerebroMinePiece.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if corpo == null or not corpo.vivo():
		return
	# `NoAI` do Minecraft (`data merge entity @s {NoAI:1b}`, camada Minecraft): metas e movimento
	# param; o tick do mod continua.
	if corpo.get_meta("mc_sem_ia", false):
		corpo.andar(Vector3.ZERO)
		return
	_tempo += delta
	var lento := Lentidao.fator(corpo)
	_relogio -= delta * lento
	_mover()
	if _relogio > 0.0:
		return
	_relogio = PERIODO
	_atualizar_alvo()
	if alvo != null:
		_decidir()


# ------------------------------------------------------------------ alvo

func _e_chefe() -> bool:
	return corpo != null and bool(corpo.ficha.get("chefe", false))


## Raio em volta de casa em que este personagem ainda persegue. INF = nunca desiste.
func zona_de_perseguicao() -> float:
	if not _e_chefe():
		return ZONA
	var cena := get_tree().current_scene if is_inside_tree() else null
	var prog: Variant = cena.get("progressao") if cena != null else null
	if prog != null and prog.has_method("tem_missao_de_combate") and prog.tem_missao_de_combate():
		return INF
	if _sofreu_dano:
		return maxf(ZONA, _meia_ilha())
	return ZONA


## Metade da ilha de casa (a maior dimensão da placa da ilha ÷ 2); sem ilha achada, `META_ILHA_PADRAO`.
func _meia_ilha() -> float:
	var cena := get_tree().current_scene if is_inside_tree() else null
	var ilhas: Variant = cena.get("_ilhas") if cena != null else null
	if ilhas == null or not ("caixas" in ilhas):
		return META_ILHA_PADRAO
	var caixas: Dictionary = ilhas.caixas
	var id := preload("res://src/historia/ilhas/ilhas.gd").ilha_em(caixas, corpo.ponto_de_origem)
	if id.is_empty():
		return META_ILHA_PADRAO
	var r: Rect2 = caixas[id]
	return maxf(r.size.x, r.size.y) * 0.5


func _atualizar_alvo() -> void:
	var casa := corpo.ponto_de_origem
	var zona := zona_de_perseguicao()
	if alvo != null and (not is_instance_valid(alvo) or not _vivo(alvo) or _plano(alvo.global_position, casa) > zona + 6.0 or _oculto(alvo)):
		alvo = null
	if _revide != null and (_tempo > _revide_ate or not is_instance_valid(_revide) or not _vivo(_revide)):
		_revide = null
	if _revide != null and _plano(_revide.global_position, casa) <= zona + 6.0:
		alvo = _revide
		return
	if alvo != null:
		return
	var deteccao := maxf(DETECCAO_MINIMA, float(corpo.ficha.get("alcance_de_perseguicao", 16.0)))
	var melhor: Node3D = null
	var menor := deteccao
	for n in _candidatos():
		if not _hostil_a(n) or _oculto(n):
			continue
		var d := corpo.global_position.distance_to((n as Node3D).global_position)
		if d < menor and _plano((n as Node3D).global_position, casa) <= zona:
			menor = d
			melhor = n
	alvo = melhor


## O jogador camuflado (Suke Suke Z) fora do alcance de percepção: invisível para este corpo.
func _oculto(n: Node) -> bool:
	if not is_instance_valid(n) or not n.has_method("esta_camuflado") or not bool(n.call("esta_camuflado")):
		return false
	return corpo.global_position.distance_to((n as Node3D).global_position) > PERCEPCAO_DO_CAMUFLADO


func _candidatos() -> Array:
	var saida: Array = []
	for j in get_tree().get_nodes_in_group("player"):
		if j is Node3D and is_instance_valid(j) and _vivo(j):
			saida.append(j)
	# Criaturas invocadas pelo jogador são alvo de quem é hostil ao jogador; e a invocada olha todos os corpos (o `LogicAttack` do mod decide).
	for a in get_tree().get_nodes_in_group(McAliadoDoMod.GRUPO_DO_JOGADOR):
		if a != corpo and is_instance_valid(a) and _vivo(a):
			saida.append(a)
	if bool(corpo.ficha.get("invocado", false)):
		# Aliado invocado: ataca tudo que é inimigo do jogo (bonecos de duelo, bandidos do mapa, bestas, animais hostis, chefes), não só personagens do East Blue.
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != corpo and e is Node3D and is_instance_valid(e) and _vivo(e) and not saida.has(e):
				saida.append(e)
	if BRIGAS_ENTRE_FACCOES or bool(corpo.ficha.get("invocado", false)):
		for p in get_tree().get_nodes_in_group("personagens_east_blue"):
			if p != corpo and p is PersonagemMinePiece and (p as PersonagemMinePiece).vivo():
				saida.append(p)
	return saida


## A regra de facção do mod (sem o revide, que vale sempre).
func _hostil_a(n: Node) -> bool:
	var minha := str(corpo.ficha.get("faccao", "nenhuma"))
	if minha == "mod":
		# Fichas importadas direto do mod: quem pode atacar quem é a conta DELE (tags, dono, bando), não a nossa.
		if bool(corpo.ficha.get("invocado", false)) and n.is_in_group("enemy") and not n.is_in_group(McAliadoDoMod.GRUPO_DO_JOGADOR):
			return true            # inimigo do jogo: o aliado do jogador o ataca sem passar pela conta de bando do mod
		var eu := McEntidade.de(corpo)
		return bool(Mc.proc(&"LogicAttackProcedure").execute(eu.level(), eu, McEntidade.de(n)))
	var dele := "pirata:jogador" if n.is_in_group("player") or n.is_in_group(McAliadoDoMod.GRUPO_DO_JOGADOR) else str((n as PersonagemMinePiece).ficha.get("faccao", "nenhuma")) if n is PersonagemMinePiece else "nenhuma"
	if minha == "aliado":
		return false
	if n is PersonagemMinePiece and (n as PersonagemMinePiece).id_personagem == corpo.id_personagem:
		return false
	if dele == "aliado":
		dele = "pirata:aliados"       # os aliados são piratas (chapéu de palha, ruivo)
	if minha.begins_with("raid:"):
		return n.is_in_group("player") or not dele.begins_with("raid:")
	if minha == "marinha":
		return dele.begins_with("pirata:") or dele.begins_with("raid:")
	if minha.begins_with("pirata:"):
		return dele != minha and dele != "nenhuma"
	return true                       # "nenhuma": bandidos atacam todos


static func _vivo(n: Node) -> bool:
	if n.has_method("vivo"):
		return bool(n.call("vivo"))
	return not ("health" in n) or float(n.get("health")) > 0.0


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ------------------------------------------------------------------ decisão

## Decisão do dono (24/10/2026): TODA habilidade de inimigo vem do mod, fiel a ele. Com a IA do mod ligada e
## achada para este personagem, ela escolhe e executa as técnicas (`minepiece:skill`); este cérebro só persegue.
## Sem IA do mod (ficha sem procedure) ou com a chave desligada, só o `MeleeAttackGoal` vanilla (A8, 27/10/2026).
func _ia_do_mod_dirige() -> bool:
	return IaDoMod.ligada and corpo.ia_do_mod != null and corpo.ia_do_mod.tem_ia()


func _decidir() -> void:
	if _ia_do_mod_dirige():
		return
	_melee_vanilla()


# ------------------------------------------------------------------ andar

func _mover() -> void:
	var dono: Variant = corpo.get_meta("dono_no") if corpo.has_meta("dono_no") else null      # (get_meta com padrão null ainda loga erro por quadro)
	if dono is Node3D and is_instance_valid(dono):
		corpo.ponto_de_origem = (dono as Node3D).global_position       # a criatura invocada tem o dono como "casa": segue e defende
	var casa := corpo.ponto_de_origem
	var tatica := corpo.get_node_or_null("TaticaDeMissao") as TaticaDeMissao
	if tatica != null and tatica.dirige(alvo):
		return                    # em missão: a tática de posicionamento (atirador no alto, espadachim cercando) anda por ele
	if alvo != null and is_instance_valid(alvo):
		var d := _plano(corpo.global_position, alvo.global_position)
		var perto := 1.6 * clampf(float(corpo.ficha.get("altura", 1.8)) / 1.8, 0.8, 2.0)
		if d > perto:
			var dir := alvo.global_position - corpo.global_position
			dir.y = 0.0
			corpo.andar(dir.normalized() * corpo.velocidade_de_andar())
		else:
			corpo.andar(Vector3.ZERO)
		corpo.encarar(alvo.global_position)
		return
	corpo.soltar_olhar()
	var longe := _plano(corpo.global_position, casa)
	var aliado := str(corpo.ficha.get("faccao", "")) == "aliado" or corpo.has_meta("dono_no")
	if longe > (8.0 if aliado else 2.0):
		var dir := casa - corpo.global_position
		dir.y = 0.0
		corpo.andar(dir.normalized() * corpo.velocidade_de_andar() * 0.8)
		_passeio = Vector3.INF
		return
	# Em casa: os aliados passeiam um pouco (RandomStrollGoal); os outros esperam virados.
	if aliado:
		if not _passeio.is_finite() and _rng.randf() < 0.004:
			var a := _rng.randf() * TAU
			_passeio = casa + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 6.0)
		if _passeio.is_finite():
			var dir := _passeio - corpo.global_position
			dir.y = 0.0
			if dir.length() < 0.5:
				_passeio = Vector3.INF
				corpo.andar(Vector3.ZERO)
			else:
				corpo.andar(dir.normalized() * corpo.velocidade_de_andar() * 0.4)
			return
	corpo.andar(Vector3.ZERO)
	if longe <= 2.0:
		_sofreu_dano = false          # chegou em casa: a perseguição alargada acabou
	if longe <= 2.0 and not _passeio.is_finite():
		corpo.rotation.y = lerp_angle(corpo.rotation.y, corpo.yaw_de_origem, 0.05)


## `MeleeAttackGoal` do Minecraft para quem, no mod, não tem procedure no `baseTick`: alcance = (2 × largura)² + largura
## do alvo (em blocos², no jogo em metros), uma tentativa por segundo, dano = o atributo de ataque da ficha.
var _melee_espera := 0.0


func _melee_vanilla() -> void:
	var largura := float(corpo.ficha.get("largura", 0.6))
	var alcance := sqrt(pow(largura * 2.0, 2.0) + 0.6) * MundoMinePiece.METROS_POR_BLOCO + 0.4
	if corpo.global_position.distance_to(alvo.global_position) > alcance or _tempo < _melee_espera:
		return
	_melee_espera = _tempo + 1.0
	var eu := McEntidade.de(corpo)
	var dano := float(corpo.ficha.get("dano_corpo", 1.0))
	McEntidade.de(alvo).hurt(McFonteDeDano.de(&"minecraft:mob_attack", eu), dano)
	# `Mob.doHurtTarget`: além do 0,4 do `hurt`, o ATTACK_KNOCKBACK do mob × 0,5 na direção em que ele olha.
	var extra := eu.getAttributeValue(Mc.atributo(&"minecraft:generic.attack_knockback")) * 0.5
	if extra > 0.0:
		var yaw := corpo.rotation.y
		McEntidade.de(alvo).knockback(extra, sin(yaw), cos(yaw))      # (sin yRot, −cos yRot) do Java, com yRot = 180° − rotação
