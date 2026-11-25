class_name PersonagemMinePiece
extends CharacterBody3D
# ============================================================================
#  PERSONAGEM DO EAST BLUE (Mine Piece) — o corpo (17/10/2026).
#
#  Pedido do dono: os inimigos, personagens e NPCs do East Blue do mod numa ilha nova,
#  "cada um com o comportamento original, poderes, ataques e aparência que eles têm no
#  minecraft" — provisórios, "mais tarde serão alterados". Plano: docs/EAST_BLUE_PLANO.md.
#
#  O corpo: o modelo convertido do mod (`mapas/modelos/mp_<id>.glb`, fora do git) com as
#  animações dele, cápsula do tamanho da entidade, vida/armadura/resistência da ficha
#  (`DadosEastBlue`), morte e renascimento no mesmo lugar. Quem decide é o
#  `CerebroMinePiece` (filho). As técnicas são skills do Builder (`mpeb_*`) que o
#  `ExecutorDeSkill` roda com este corpo como ator: daí os métodos
#  `definir_movimento_de_skill`, `definir_flutuar` e `centro_do_corpo`.
#
#  Sem o .glb (outra máquina: a arte do mod não vai para o git) o corpo é uma cápsula
#  na cor da facção com o nome em cima — o jogo continua jogável.
# ============================================================================

signal derrotado(personagem: PersonagemMinePiece)

const GRAVIDADE := 32.0
const GIRO := 8.0                       # rad/s
## Velocidade do Minecraft (atributo 0,3) → m/s: ×15 dá 4,5 m/s, a do inimigo do mapa
## (`CerebroDeInimigo.VELOCIDADE`): alcança quem anda, quem corre escapa.
const VELOCIDADE_POR_ATRIBUTO := 15.0
## Renasce no mesmo lugar (regra dos inimigos do mapa). Chefe demora mais.
static var tempo_de_renascer := 60.0
static var tempo_de_renascer_chefe := 300.0
const SUMIR_EM := 1.6
const COR_DA_FACCAO := {"marinha": Color("#3c78d8"), "aliado": Color("#e8c547"), "nenhuma": Color("#8a5a3c")}

const RegrasDeRecompensa := preload("res://src/historia/recompensa_mine_piece.gd")
const UniformesFaccoes := preload("res://src/historia/east_blue/uniformes_faccoes.gd")

var ficha: Dictionary = {}
## CAPANGA do chefe (08/11/2026, pedido do dono): não dá XP e morre com 5 GOLPES, não pela conta de vida. Um golpe que passaria da vida
## dele conta 1 golpe e o DERRUBA por `TEMPO_CAIDO` s. Capanga = não é chefe e é de raid ou de uma zona que tem chefe (`e_capanga`).
const GOLPES_DO_CAPANGA := 5
## 13/11/2026, pedido do dono ("volta a vida dos inimigos básicos ao normal sem a restrição da necessidade de 5 ataques para matar"): a regra dos 5 golpes
## está DESLIGADA — o capanga morre pela conta de vida como qualquer inimigo. Continua capanga para o resto (não dá XP, bando, raid). GATILHO: religar se o dono pedir.
const CAPANGA_POR_GOLPES := false
const TEMPO_CAIDO := 3.0
## Janela entre dois golpes contados (um tiro de área não pode tirar os 5 num quadro só).
const JANELA_DE_GOLPE_MS := 400
var capanga := false
var golpes_restantes := GOLPES_DO_CAPANGA
var _caido_ate_ms := 0
var _golpe_livre_ms := 0
## false: some depois de morrer em vez de renascer (inimigos da raid, 18/10/2026).
var renasce := true
var id_personagem := ""
var nivel := 1                          # barra das criaturas (`BarrasDeCriaturas.nivel_de`)
var health := 20.0
var max_health := 20.0
var ponto_de_origem := Vector3.ZERO
var yaw_de_origem := 0.0
var cerebro: CerebroMinePiece = null
## A IA do mod pela camada Minecraft (23/10/2026), junto com o cérebro; chave em `IaDoMod.ligada`.
var ia_do_mod: IaDoMod = null
## Quem bateu por último (o revide do mod: HurtByTargetGoal).
var ultimo_agressor: Node3D = null
var _modelo: Node3D = null
var _anim: AnimationPlayer = null
var _clipe_atual := ""
var _clipe_trava := 0.0                 # clipe de golpe tocando: andar/parar não troca
var _mov_skill := Vector3.ZERO
var _mov_skill_quadro := -100
var _mov_skill_vertical := false
var _flutuar := false
var _empurrao := Vector3.ZERO
## Acima deste empurrão horizontal (m/s) o personagem não anda por conta própria até ele decair (ver BonecoDeDuelo.ESTONTEADO).
const ESTONTEADO := 1.5
## Empurrão do Minecraft (fixo, longe de quem bateu, pulinho no chão): quem leva golpe sem empurrão próprio também sai do lugar.
var _kb_mc := KnockbackMinecraft.new()
var _morto := false
var _camada := 1
var _rotulo: Label3D = null
var _quer_andar := Vector3.ZERO         # o cérebro pede: direção × velocidade
var _olhar_para := Vector3.INF


func montar(a_ficha: Dictionary, modelo_id: String) -> void:
	set_meta("modelo_recrutavel", modelo_id)
	ficha = a_ficha
	id_personagem = str(ficha.get("id", ""))
	name = "MP_" + id_personagem
	max_health = float(ficha.get("vida", 20.0))
	# O mod não dá nível a criatura: o nível é o da recompensa dela (a que o jogador ganha ao
	# abatê-la), pela mesma curva `UpdateBountyProcedure` do jogador.
	nivel = RegrasDeRecompensa.nivel_da_recompensa(RegrasDeRecompensa.xp_da_ficha(ficha, max_health))
	health = max_health
	capanga = e_capanga(ficha)
	golpes_restantes = GOLPES_DO_CAPANGA
	collision_layer = 1
	collision_mask = 1
	var altura := float(ficha.get("altura", 1.8))
	var largura := float(ficha.get("largura", 0.6))
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = maxf(0.25, largura * 0.5)
	forma.height = maxf(altura, forma.radius * 2.0 + 0.05)
	col.shape = forma
	col.position.y = forma.height * 0.5
	add_child(col)
	HurtboxDeCombate.instalar(self, Vector3(largura + 0.2, altura, largura + 0.2))
	# A origem deste corpo é o PÉ (a do boneco é o meio): a caixa sobe meia altura.
	HurtboxDeCombate.redimensionar(self, Vector3(largura + 0.2, altura, largura + 0.2), altura * 0.5)
	_montar_modelo(modelo_id, altura)
	_rotulo = Label3D.new()
	_rotulo.text = str(ficha.get("nome", id_personagem))
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.position.y = altura + 0.45
	_rotulo.font_size = 40
	_rotulo.pixel_size = 0.004
	_rotulo.outline_size = 8
	_rotulo.no_depth_test = false
	add_child(_rotulo)
	var faccao := str(ficha.get("faccao", "nenhuma"))
	if faccao == "aliado":
		add_to_group("npc")
	else:
		add_to_group("enemy")
	add_to_group(AlvosDeGolpe.GRUPO)
	add_to_group("personagens_east_blue")
	if bool(ficha.get("chefe", false)):
		add_to_group(BarrasDeChefes.GRUPO)
	cerebro = CerebroMinePiece.new()
	cerebro.name = "Cerebro"
	add_child(cerebro)
	if TaticaDeMissao.papel_de(ficha, id_personagem) != TaticaDeMissao.Papel.NENHUM:
		var tatica := TaticaDeMissao.new()          # em missão: atirador sobe com pulo duplo e mira; espadachim cerca defendendo
		tatica.name = "TaticaDeMissao"
		add_child(tatica)
	if bool(ficha.get("chefe", false)):
		var desvio := DesvioDeChefe.new()           # chefe desvia de projétil: teleporte, 15 s de recarga
		desvio.name = "DesvioDeChefe"
		add_child(desvio)
	ia_do_mod = IaDoMod.new()
	ia_do_mod.name = "IaDoMod"
	add_child(ia_do_mod)
	ia_do_mod.montar(self, id_personagem)
	if is_inside_tree():
		_equipar_de_fogo()
	else:
		tree_entered.connect(_equipar_de_fogo, CONNECT_ONE_SHOT)    # o `McEntidade` precisa da árvore


## O construtor Java do mod põe a arma de fogo na mão (Yasopp/Benn Beckman: fuzil, Helmeppo: pistola…): ver `EquipamentoPadrao`.
## Vale ANTES do primeiro tick, em que o `ao_nascer` do mod (SetTagMarine/SetTagPirate) pode trocar a arma, como no Java.
func _equipar_de_fogo() -> void:
	var armas := EquipamentoPadrao.armas_de_fogo(id_personagem)
	if armas.is_empty():
		return
	var e := McEntidade.de(self)
	for mao in armas:
		e.setItemSlot(StringName(mao), Mc.novo(&"ItemStack", [Mc.item(StringName("minepiece:" + str(armas[mao])))]))


## Pehkui `height`/`width` do mod (`McEntidade.definirEscala`): modelo, cápsula, hurtbox e rótulo crescem juntos.
func aplicar_escala_mc(h: float, w: float) -> void:
	var altura := float(ficha.get("altura", 1.8)) * h
	var largura := float(ficha.get("largura", 0.6)) * w
	for filho in get_children():
		if filho is CollisionShape3D and (filho as CollisionShape3D).shape is CapsuleShape3D:
			var forma := (filho as CollisionShape3D).shape as CapsuleShape3D
			forma.radius = maxf(0.25 * minf(h, w), largura * 0.5)
			forma.height = maxf(altura, forma.radius * 2.0 + 0.05)
			(filho as CollisionShape3D).position.y = forma.height * 0.5
	HurtboxDeCombate.redimensionar(self, Vector3(largura + 0.2, altura, largura + 0.2), altura * 0.5)
	if _modelo != null:
		_modelo.scale = Vector3(w, h, w)
	if _rotulo != null:
		_rotulo.position.y = altura + 0.45


func _montar_modelo(modelo_id: String, altura: float) -> void:
	var caminho := "res://mapas/modelos/%s.glb" % modelo_id
	var cena: PackedScene = load(caminho) as PackedScene if ResourceLoader.exists(caminho) else null
	if cena != null:
		_modelo = cena.instantiate() as Node3D
	elif McVisual.tem_corpo(id_personagem):
		_modelo = McVisual.corpo(id_personagem)       # criatura só-visual do mod (mpx_<id>): o desenho GeckoLib já convertido
	else:
		_modelo = _capsula_de_reserva(altura)
	_modelo.name = "Modelo"
	UniformesFaccoes.aplicar(_modelo, modelo_id)
	add_child(_modelo)
	_anim = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for nome in _anim.get_animation_list():
			if str(nome).ends_with("_loop"):
				_anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	_tocar_base("idle")


func _capsula_de_reserva(altura: float) -> Node3D:
	var raiz := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.height = altura
	m.radius = 0.35
	mi.mesh = m
	mi.position.y = altura * 0.5
	var mat := StandardMaterial3D.new()
	var faccao := str(ficha.get("faccao", "nenhuma")).get_slice(":", 0)
	mat.albedo_color = COR_DA_FACCAO.get(faccao, Color("#c0392b"))
	mi.material_override = mat
	raiz.add_child(mi)
	return raiz


# ------------------------------------------------------------------ física

## Parado no chão: roda o `move_and_slide` 1 quadro em N. Desligar só nas medições.
static var economia_de_parado := true
const PASSO_PARADO := 4


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"PersonagemMinePiece.fisica", t)


## SALTO DE PERSEGUIÇÃO (18/11/2026, macacos humanoides da Ilha dos Macacos; ficha `"salta": true`): perseguindo o jogador de 5 a 13 m, no chão e fora de golpe, o
## personagem dá um pulo longo EM CIMA dele (impulso horizontal pelo `_empurrao` + vertical), de 4,5 em 4,5 s. É um deslocamento, não um golpe: o dano continua sendo dos
## golpes normais ao chegar. (O `mpeb_ataque_salto` do mod é só uma animação de golpe por cima, não um pulo.)
const SALTO_ALCANCE := Vector2(5.0, 13.0)
const SALTO_RECARGA := 4.5
const SALTO_IMPULSO := Vector2(14.0, 9.0)        # horizontal (m/s, decai 14 m/s²) e vertical (m/s)
var _salto_espera := 0.0


func _salto_de_perseguicao(delta: float) -> void:
	if not bool(ficha.get("salta", false)):
		return
	_salto_espera = maxf(_salto_espera - delta, 0.0)
	if _salto_espera > 0.0 or not is_on_floor() or esta_caido() or Engine.get_physics_frames() - _mov_skill_quadro <= 2:
		return
	var alvo: Node3D = cerebro.alvo if cerebro != null else null          # quem o cérebro persegue (o jogador, ou quem revidou)
	if alvo == null or not is_instance_valid(alvo) or float(alvo.get("health")) <= 0.0:
		return
	var para := alvo.global_position - global_position
	var plano := Vector3(para.x, 0.0, para.z)
	if plano.length() < SALTO_ALCANCE.x or plano.length() > SALTO_ALCANCE.y or absf(para.y) > 6.0:
		return
	_salto_espera = SALTO_RECARGA
	_empurrao = plano.normalized() * SALTO_IMPULSO.x
	velocity.y = SALTO_IMPULSO.y


func _physics_process_corpo(delta: float) -> void:
	if _morto:
		return
	_clipe_trava = maxf(0.0, _clipe_trava - delta)
	_kb_mc.passar_tempo(delta)
	if (Engine.get_physics_frames() + get_instance_id()) % 30 == 0:
		_atravessar_jogadores()
	if capanga and _caido_ate_ms > 0 and not esta_caido():
		_caido_ate_ms = 0
		_levantar()
	_salto_de_perseguicao(delta)
	_passo_da_esquiva()
	var skill_movendo := Engine.get_physics_frames() - _mov_skill_quadro <= 2
	if skill_movendo:
		velocity.x = _mov_skill.x
		velocity.z = _mov_skill.z
		if _mov_skill_vertical:
			velocity.y = _mov_skill.y
	else:
		var alvo_v := _quer_andar * Lentidao.fator(self)
		if Vector2(_empurrao.x, _empurrao.z).length() > ESTONTEADO:
			alvo_v = Vector3.ZERO       # estontado: o empurrão manda (a caminhada somada o anulava)
		velocity.x = alvo_v.x + _empurrao.x
		velocity.z = alvo_v.z + _empurrao.z
	var kb := _kb_mc.impulso_do_quadro(delta, is_on_floor())
	velocity.x += kb.x
	velocity.z += kb.z
	if not (skill_movendo and _mov_skill_vertical) and not _flutuar:
		velocity.y = 0.0 if is_on_floor() and velocity.y < 0.0 else velocity.y - GRAVIDADE * delta
	elif _flutuar and not skill_movendo:
		velocity.y = 0.0
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 14.0 * delta)
	# PARADO NO CHÃO (04/11/2026): `move_and_slide` era 4,3 ms dos 4,9 ms do corpo com 81 personagens (53 µs cada, por quadro).
	# Quem está no chão, sem andar, sem empurrão, sem knockback, sem skill e sem flutuar não sai do lugar: roda 1 quadro em
	# `PASSO_PARADO` (fase por instância, para não alinhar). Perder o chão sob um parado é notado em até PASSO_PARADO quadros.
	var parado := economia_de_parado and not skill_movendo and not _flutuar and is_on_floor() \
		and velocity.x * velocity.x + velocity.z * velocity.z < 0.0001 and velocity.y <= 0.0
	if parado and (Engine.get_physics_frames() + get_instance_id()) % PASSO_PARADO != 0:
		Cronometro.contar(&"PMP.slide_pulado")
	else:
		var t_m := Cronometro.ini()
		EscaladaDeMob.ajudar(self, delta)
		move_and_slide()
		Cronometro.fim(&"PMP.move_and_slide", t_m)
	var t_h := Cronometro.ini()
	HurtboxDeCombate.sincronizar(self)
	Cronometro.fim(&"PMP.hurtbox_sincronizar", t_h)
	# Vira para onde anda (ou para quem o cérebro mandou olhar).
	var dir := Vector3(velocity.x, 0, velocity.z)
	if _olhar_para.is_finite():
		dir = _olhar_para - global_position
		dir.y = 0.0
	if dir.length_squared() > 0.04:
		var alvo_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, alvo_yaw, clampf(GIRO * delta, 0.0, 1.0))
	if _clipe_trava <= 0.0:
		var plano := Vector2(velocity.x, velocity.z).length()
		var t_b := Cronometro.ini()
		_tocar_base("walk" if plano > 0.6 else "idle")
		Cronometro.fim(&"PMP.tocar_base", t_b)
	# Caiu do mapa: volta para casa.
	if global_position.y < ponto_de_origem.y - 60.0:
		global_position = ponto_de_origem + Vector3.UP


## O cérebro pede para andar (direção no plano × m/s); ZERO = parar.
## Pulo (e pulo duplo, no ar) do corpo: impulso vertical em m/s. Só vale se o corpo estiver livre.
func pular(impulso: float) -> void:
	if not _morto and not esta_caido():
		velocity.y = impulso


func andar(direcao_vel: Vector3) -> void:
	_quer_andar = Vector3.ZERO if esta_caido() else Vector3(direcao_vel.x, 0, direcao_vel.z)


## O jogador e os inimigos NÃO se bloqueiam fisicamente (08/11/2026): uma roda de piratas em volta do jogador o travava no lugar — o relato
## "perdeu o controle do awsd". A camada 1 continua a mesma (golpes e projéteis acham o corpo); só o corpo deixa de empurrar o outro.
func _atravessar_jogadores() -> void:
	for j in get_tree().get_nodes_in_group("player"):
		if j is CharacterBody3D and not get_collision_exceptions().has(j):
			add_collision_exception_with(j)
			(j as CharacterBody3D).add_collision_exception_with(self)


## Capanga de chefe: raid (todo estágio tem chefe) ou membro de um BANDO do East Blue (zona com chefe e subordinados). Chefe e aliado nunca.
## Zona de bando é lista fixa: grand_line e novo_mundo misturam chefes e personagens soltos (Ace, Bon Clay...) que NÃO são capangas de ninguém.
## GATILHO: quando as zonas da Grand Line ganharem bandos próprios, listar aqui.
const ZONAS_DE_BANDO: Array[String] = ["bandidos", "alvida", "shells_town", "orange_town", "vila_syrup", "baratie", "arlong_park", "loguetown"]


static func e_capanga(f: Dictionary) -> bool:
	if bool(f.get("chefe", false)) or str(f.get("faccao", "")) == "aliado":
		return false
	if str(f.get("faccao", "")).begins_with("raid:"):
		return true
	return ZONAS_DE_BANDO.has(str(f.get("zona", "")))


func esta_caido() -> bool:
	return Time.get_ticks_msec() < _caido_ate_ms


## Derruba o capanga: fica estendido no chão, sem andar nem usar técnica, e levanta sozinho.
func derrubar(segundos := TEMPO_CAIDO) -> void:
	_caido_ate_ms = Time.get_ticks_msec() + int(segundos * 1000.0)
	_quer_andar = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	_mov_skill_quadro = -100
	if cerebro != null:
		cerebro.cancelar()
	if ia_do_mod != null:
		ia_do_mod.process_mode = Node.PROCESS_MODE_DISABLED       # sem técnica enquanto está no chão
	if _modelo != null:
		_modelo.rotation.x = -PI * 0.5                            # deitado de costas (o pé é a origem do corpo)
		_modelo.position.y = 0.25


func _levantar() -> void:
	if _modelo != null:
		_modelo.rotation.x = 0.0
		_modelo.position.y = 0.0
	if ia_do_mod != null and not _morto:
		ia_do_mod.process_mode = Node.PROCESS_MODE_INHERIT


func encarar(ponto: Vector3) -> void:
	_olhar_para = ponto


func soltar_olhar() -> void:
	_olhar_para = Vector3.INF


func velocidade_de_andar() -> float:
	return float(ficha.get("velocidade", 0.3)) * VELOCIDADE_POR_ATRIBUTO


# ------------------------------------------------------------ ESQUIVA COM DASH
# Pedido do dono (22/11/2026): inimigo atacado pela Buki Buki dá um dash lateral para sair da linha do tiro, com recarga de 3 s.
# Quem avisa é a `BalaDaBuki` (bala no corredor, ou o inimigo foi ferido). É um deslocamento, não um golpe: não dá dano nem invulnerabilidade.
const ESQUIVA_VELOCIDADE := 15.0
const ESQUIVA_DURACAO := 0.24            # 15 m/s x 0,24 s = 3,6 m: sai do corredor da bala
var _esquiva_ate_ms := 0
var _esquiva_vel := Vector3.ZERO


func esquiva_pronta() -> bool:
	return not _morto and EsquivaDeDisparo.pronta(self) and not esta_caido() \
		and not is_in_group("invocados_do_jogador") and not get_meta("is_frozen", false)


## `rumo`: direção do tiro. Devolve se deu o dash (lado, recarga e efeito: `EsquivaDeDisparo`).
func esquivar_de_disparo(rumo: Vector3, _chegada_em := 0.0) -> bool:
	if not esquiva_pronta() or not is_on_floor():
		return false
	var lateral := EsquivaDeDisparo.tentar(self, rumo)
	if lateral == Vector3.ZERO:
		return false
	_esquiva_vel = lateral * ESQUIVA_VELOCIDADE
	_esquiva_ate_ms = Time.get_ticks_msec() + int(ESQUIVA_DURACAO * 1000.0)
	_quer_andar = Vector3.ZERO
	return true


func _passo_da_esquiva() -> void:
	if Time.get_ticks_msec() < _esquiva_ate_ms:
		definir_movimento_de_skill(_esquiva_vel, false)


# ------------------------------------------------------------------ o executor de skill

func definir_movimento_de_skill(vel: Vector3, vertical: bool, parar: bool = false) -> void:
	if parar:
		_mov_skill_quadro = -100
		_mov_skill = Vector3.ZERO
		return
	_mov_skill = vel
	_mov_skill_vertical = vertical
	_mov_skill_quadro = Engine.get_physics_frames()


func definir_flutuar(sim: bool) -> void:
	_flutuar = sim
	if sim:
		velocity.y = 0.0


func centro_do_corpo() -> Vector3:
	return global_position + Vector3.UP * float(ficha.get("altura", 1.8)) * 0.55


## Esconde o corpo enquanto a skill o transforma em luz/fumaça ("Cometa").
func ocultar_corpo_por_skill(sim: bool) -> void:
	if is_instance_valid(_modelo):
		_modelo.visible = not sim


# ------------------------------------------------------------------ animação

## Toca um clipe de golpe do modelo (o original do mod), travando andar/parar por `duracao`.
func tocar_clipe(nome: String, duracao: float) -> void:
	if _anim == null or nome.is_empty():
		return
	var real := _achar_clipe(nome)
	if real.is_empty():
		return
	_anim.play(real, 0.08)
	_clipe_atual = real
	_clipe_trava = duracao


## Técnica do mod (`triggerAnim`): o clipe de mesmo nome; "empty"/"" solta o ciclo base. Clipe em laço (pose
## sustentada) vale até o reset ou 10 s; clipe único, pela duração dele.
func tocar_tecnica(nome: String) -> void:
	if _anim == null:
		return
	if nome.is_empty() or nome == "empty":
		_clipe_trava = 0.0
		_clipe_atual = ""
		return
	var real := _achar_clipe(nome)
	if real.is_empty():
		return
	var a := _anim.get_animation(real)
	tocar_clipe(nome, 10.0 if a.loop_mode != Animation.LOOP_NONE else a.length)


const ARMA_OSSO := {&"MAINHAND": "itemMainHand", &"OFFHAND": "itemOffHand"}


## Prende (ou tira) o item na mão: `mapas/modelos/mpi_<item>.glb` (tools/mine_piece/geo_para_glb.py --itens).
func equipar_na_mao(espaco: StringName, item: StringName) -> void:
	if _modelo == null:
		return
	var osso := _modelo.find_child(ARMA_OSSO.get(espaco, "itemMainHand"), true, false) as Node3D
	if osso == null:
		osso = _modelo.find_child("right_arm", true, false) as Node3D
	if osso == null:
		return
	var nome := "Arma_" + String(espaco)
	var antiga := osso.get_node_or_null(nome)
	if antiga != null:
		osso.remove_child(antiga)
		antiga.queue_free()
	var caminho := "res://mapas/modelos/mpi_%s.glb" % item
	if item.is_empty() or not ResourceLoader.exists(caminho):
		return
	var cena := load(caminho) as PackedScene
	if cena == null:
		return
	var arma := cena.instantiate() as Node3D
	arma.name = nome
	osso.add_child(arma)


func _tocar_base(tipo: String) -> void:
	if _anim == null:
		return
	var real := _achar_clipe(tipo)
	if real.is_empty() or real == _clipe_atual:
		return
	_anim.play(real, 0.15)
	_clipe_atual = real


## "walk" acha "walk_loop", "walk", "walking"… (cada modelo do mod nomeia do seu jeito).
func _achar_clipe(nome: String) -> String:
	if _anim.has_animation(nome):
		return nome
	if _anim.has_animation(nome + "_loop"):
		return nome + "_loop"
	for a in _anim.get_animation_list():
		if str(a).begins_with(nome):
			return str(a)
	return ""


# ------------------------------------------------------------------ dano

func vivo() -> bool:
	return not _morto and health > 0.0


func em_combate() -> bool:
	return cerebro != null and cerebro.alvo != null


func nome_de_exibicao() -> String:
	return str(ficha.get("nome", id_personagem))


## A defesa que vale AGORA. Com a IA do mod, Resistência e armadura são os do corpo vivo (efeito sorteado no nascimento,
## atributo com modificadores); sem ela, a ficha. Mesma conta do Minecraft (`DadosEastBlue.dano_recebido`).
func _defesa_viva() -> Dictionary:
	if ia_do_mod == null or not IaDoMod.ligada or not ia_do_mod.tem_ia():
		return ficha
	var e := McEntidade.de(self)
	var r := e.getEffect(Mc.efeito(&"minecraft:resistance"))
	var viva := ficha.duplicate()
	viva["resistencia"] = float(r.amplificador) if r != null else -1.0
	viva["armadura"] = e.getAttributeValue(Mc.atributo(&"minecraft:armor"))
	viva["tenacidade"] = e.getAttributeValue(Mc.atributo(&"minecraft:armor_toughness"))
	return viva


func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
	# `damage_immune`: a mesma meta do jogador; o `Invulnerable:1b` do mod (`data merge`) liga ela.
	if _morto or amount <= 0.0 or get_meta("damage_immune", false):
		return
	IaUnificada.acordar_por_dano(self)      # IA unificada: levar dano acorda (10/11/2026)
	var quem := _quem_bateu(from_pos)
	# Aliado invocado do jogador: sem fogo amigo (entre os guerreiros do mesmo dono nem vindo do próprio dono).
	if is_in_group("invocados_do_jogador") and quem != null and quem != self \
			and (quem.is_in_group("invocados_do_jogador") or quem.is_in_group("player")):
		return
	# Golpe de alguém do mesmo bando não fere (LogicAttack do mod): a rajada do Krieg
	# passa pelos piratas dele.
	if quem is PersonagemMinePiece and quem != self:
		var f_dele := str((quem as PersonagemMinePiece).ficha.get("faccao", ""))
		if f_dele == str(ficha.get("faccao", "")) and f_dele != "nenhuma" and not bool(ficha.get("invocado", false)):
			return
	# Eventos do Forge da IA do mod (chave ligada): LivingAttack/Hurt antes da armadura,
	# LivingDamage depois (camada Minecraft, 23/10/2026).
	if ia_do_mod != null:
		amount = ia_do_mod.ao_receber_dano(amount, quem)
		if amount < 0.0:
			return
	var d := DadosEastBlue.dano_recebido(_defesa_viva(), amount)
	if ia_do_mod != null:
		d = ia_do_mod.dano_final(d)
	if capanga and CAPANGA_POR_GOLPES:
		# 5 GOLPES: cada golpe tira 1/5 da vida, qualquer que seja o dano; o que passaria da vida que resta não mata — custa 1 golpe e derruba.
		var agora := Time.get_ticks_msec()
		if agora < _golpe_livre_ms:
			return
		_golpe_livre_ms = agora + JANELA_DE_GOLPE_MS
		var passaria := d >= health
		golpes_restantes -= 1
		health = 0.0 if golpes_restantes <= 0 else maxf(max_health * float(golpes_restantes) / GOLPES_DO_CAPANGA, 0.001)
		if passaria and golpes_restantes > 0:
			derrubar()
	else:
		if is_in_group(BarrasDeChefes.GRUPO):
			d = VidaEmBarras.filtrar(self, d, health, max_health)   # chefe: 10 barras (10/11/2026)
		health = maxf(0.0, health - d)
	var resiste := clampf(float(ficha.get("resistencia_a_empurrao", 0.0)), 0.0, 1.0)
	_empurrao += Vector3(knockback.x, 0, knockback.z) * (1.0 - resiste)
	# O RangeAttack do mod também ERGUE o alvo (vertical do empurrão): sem isto o golpe de fruta só arrastava o inimigo.
	if knockback.y > 0.5 and not _flutuar:
		velocity.y = maxf(velocity.y, minf(knockback.y, 8.0) * (1.0 - resiste))
	# Golpe SEM empurrão próprio (soco comum, `hurt` de outro corpo): o Minecraft empurra 0,4 bloco/tick para longe de quem
	# bateu, uma vez a cada 0,5 s (a janela de invulnerabilidade só limita o EMPURRÃO; o dano entra como sempre).
	if Vector2(knockback.x, knockback.z).length() < 0.1 and from_pos != Vector3.ZERO and resiste < 1.0:
		if bool(_kb_mc.filtrar(amount).get("empurra", false)):
			var salto := _kb_mc.empurrar(global_position, from_pos, Vector3.ZERO, GRAVIDADE, is_on_floor())
			_kb_mc.atenuar(1.0 - resiste)
			if salto > 0.0:
				velocity.y = salto * (1.0 - resiste)
	ultimo_agressor = quem
	if cerebro != null:
		cerebro.foi_atacado(ultimo_agressor)
	if health <= 0.0:
		_morrer()


## Quem bateu, para o revide. O `CombatResolver` marca o alvo durante o `take_damage`
## (`socorro.marcar`: "dano_do_jogador"; corpo a corpo: o id do autor). Sem marca, quem
## estava mais perto do ponto do golpe.
func _quem_bateu(from_pos: Vector3) -> Node3D:
	if has_meta("autor_do_dano"):
		var autor := instance_from_id(int(get_meta("autor_do_dano"))) as Node3D
		if autor != null and autor != self:
			return autor
	if has_meta("dano_do_jogador") and bool(get_meta("dano_do_jogador")):
		var j := get_tree().get_first_node_in_group("player") as Node3D
		if j != null:
			return j
	if has_meta(CombatResolver.META_CORPO_A_CORPO):
		var autor := instance_from_id(int(get_meta(CombatResolver.META_CORPO_A_CORPO))) as Node3D
		if autor != null and autor != self:
			return autor
	var melhor: Node3D = null
	var menor := 6.0
	for n in AlvosDeGolpe.todos(get_tree()):
		if n == self or not (n is Node3D) or not is_instance_valid(n):
			continue
		var dist := (n as Node3D).global_position.distance_to(from_pos)
		if dist < menor:
			menor = dist
			melhor = n
	return melhor


func _morrer() -> void:
	if ia_do_mod != null:
		ia_do_mod.ao_morrer(ultimo_agressor)
	_morto = true
	_quer_andar = Vector3.ZERO
	velocity = Vector3.ZERO
	if cerebro != null:
		cerebro.cancelar()            # a skill em curso morre com o corpo
	_mov_skill_quadro = -100
	_flutuar = false
	_camada = collision_layer
	collision_layer = 0
	_ligar_hurtbox(false)
	remove_from_group("enemy")
	remove_from_group("npc")
	remove_from_group(AlvosDeGolpe.GRUPO)
	remove_from_group(BarrasDeChefes.GRUPO)
	if _anim != null:
		var morte := _achar_clipe("death")
		if not morte.is_empty():
			_anim.play(morte, 0.1)
	derrotado.emit(self)
	get_tree().create_timer(SUMIR_EM).timeout.connect(_sumir)
	if not renasce:
		get_tree().create_timer(SUMIR_EM + 0.1).timeout.connect(queue_free)
		return
	var espera := tempo_de_renascer_chefe if bool(ficha.get("chefe", false)) else tempo_de_renascer
	get_tree().create_timer(espera).timeout.connect(_renascer)


func _sumir() -> void:
	if _morto:
		visible = false


func _ligar_hurtbox(sim: bool) -> void:
	var hb := get_node_or_null(HurtboxDeCombate.NOME) as StaticBody3D
	if hb != null:
		hb.collision_layer = HurtboxDeCombate.CAMADA if sim else 0


func _renascer() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_morto = false
	health = max_health
	golpes_restantes = GOLPES_DO_CAPANGA
	_caido_ate_ms = 0
	_levantar()
	global_position = ponto_de_origem
	rotation.y = yaw_de_origem
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	visible = true
	collision_layer = _camada
	_ligar_hurtbox(true)
	add_to_group("npc" if str(ficha.get("faccao", "")) == "aliado" else "enemy")
	add_to_group(AlvosDeGolpe.GRUPO)
	if bool(ficha.get("chefe", false)):
		add_to_group(BarrasDeChefes.GRUPO)
	_clipe_atual = ""
	_tocar_base("idle")
	if cerebro != null:
		cerebro.reiniciar()
