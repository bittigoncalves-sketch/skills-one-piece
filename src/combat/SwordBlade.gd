class_name SwordBlade
extends Node3D
## As ZONAS DA LÂMINA — bolinhas ao longo do fio que recebem informação.
##
## ============================================================================
##  O PEDIDO (dono, 2026-09-06)
## ============================================================================
##  *"em relação à lâmina serão colocadas zonas no formato de bolinhas nela como
##  área de recebimento de informação: quando uma dessas áreas toca em um inimigo
##  durante uma animação o inimigo recebe o dano; ou quando uma dessas áreas na
##  espada do inimigo toca a área da espada do jogador ocorre uma colisão de
##  espadas anulando ambos os movimentos."*
##
##  Duas leituras, um nó só. A bolinha é uma `Area3D` que enxerga **corpos** (o
##  inimigo) e **outras bolinhas** (a espada dele).
##
## ============================================================================
##  POR QUE ISTO SUBSTITUI A CAIXA DO GOLPE, E O QUE MUDA NA PRÁTICA
## ============================================================================
##  O corte de espada usava UMA `BoxShape3D` de `raio * 2` por `alcance * 1.5`
##  nascida na frente do peito — com os números da tabela, uma caixa de 4 m de
##  largura por 3,75 m de fundo, parada no ar durante os quadros ativos. Ela não
##  tinha relação nenhuma com onde a lâmina estava; era um volume que aparecia
##  na direção do clique.
##
##  As bolinhas são presas à ESPADA, que é presa à mão, que é girada pela
##  animação. Então elas percorrem o arco de verdade: acerta o que o fio
##  encostou, quando encostou.
##
##  ⚠️ ISSO É MAIS EXIGENTE, e o número diz quanto. A caixa antiga cobria da
##  ordem de 15 m³; as sete bolinhas de raio `RAIO` cobrem ~1,1 m³ varridos ao
##  longo do golpe. O `RAIO` é generoso de propósito (a lâmina tem 0,09 m de
##  largura e a bolinha tem 0,28 m) justamente para o corte não virar prova de
##  agulha — é a mesma lição que o C da Pika deu: hitbox honesta não pode ser
##  hitbox minúscula.
##
## ============================================================================
##  A CAMADA 8, E POR QUE UMA CAMADA PRÓPRIA
## ============================================================================
##  Neste projeto personagem e cenário vivem juntos na camada 1, e as consultas
##  de combate usam `collision_mask = 15` (camadas 1-4). Bolinha precisa ser
##  vista por OUTRA bolinha e por mais ninguém — se ela entrasse nas camadas 1-4,
##  toda varredura de projétil do jogo passaria a esbarrar em espada.
##
##  Então a bolinha MORA na camada 8 (bit 128) e OLHA para 1-4 (corpos) mais a
##  própria 8 (a espada do outro). É o que deixa o clash existir sem tocar em
##  nenhum outro sistema.

const CAMADA_LAMINA := 128          # bit 8, exclusivo das bolinhas
const MASCARA_CORPOS := 15          # camadas 1-4, onde vivem corpos e cenário

const QUANTAS := 7                  # bolinhas entre a guarda e a ponta
const RAIO := 0.28

## ⚠️ TEMPORÁRIO, no mesmo espírito do vermelho da hitbox do C: desenha as
## bolinhas para o dono conferir onde o dano mora. Azul para não confundir com
## o vermelho do C. Vire `false` quando não precisar mais ver.
const MOSTRAR_ZONAS := true
const COR_ZONA := Color(0.25, 0.75, 1.0, 0.22)

signal acertou(alvo: Node)
signal chocou(outra: SwordBlade)

var base := 0.4                     # onde a lâmina começa (local +Y)
var ponta := 1.8                    # a ponta

var dono: Node = null               # quem empunha
var _bolinhas: Array[Area3D] = []
var _armada := false
var _dano := 0.0
var _kb := 0.0
var _hitstun := 0.3
var _cast_id := 0
var _teto := 0.0
var _ja_acertou: Dictionary = {}    # um acerto por corpo POR GOLPE
var _ja_chocou := false


func _ready() -> void:
	name = "Lamina"
	_criar_bolinhas()
	desarmar()


func _criar_bolinhas() -> void:
	for i in QUANTAS:
		var t := float(i) / float(maxi(QUANTAS - 1, 1))
		var bola := Area3D.new()
		bola.name = "zona_lamina_%d" % i
		bola.position = Vector3(0.0, lerpf(base, ponta, t), 0.0)
		bola.collision_layer = CAMADA_LAMINA
		bola.collision_mask = MASCARA_CORPOS | CAMADA_LAMINA
		bola.monitorable = true      # a espada do outro precisa ENXERGAR esta

		var col := CollisionShape3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = RAIO
		col.shape = esfera
		bola.add_child(col)

		bola.body_entered.connect(_no_corpo)
		bola.area_entered.connect(_na_area)
		add_child(bola)
		_bolinhas.append(bola)

		if MOSTRAR_ZONAS:
			bola.add_child(_desenho())


func _desenho() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RAIO
	sm.height = RAIO * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COR_ZONA
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------- ligar
## Liga as bolinhas para os quadros ativos de UM golpe. O `_ja_acertou` zera
## aqui, e não no `desarmar`: é o que garante "um acerto por corpo por golpe"
## sem impedir que o próximo golpe do combo acerte o mesmo alvo de novo.
func armar(dano: float, kb: float, hitstun_dur: float, cast_id: int, teto: float) -> void:
	_dano = dano
	_kb = kb
	_hitstun = hitstun_dur
	_cast_id = cast_id
	_teto = teto
	_ja_acertou.clear()
	_ja_chocou = false
	_armada = true
	_ligar_monitores(true)


func desarmar() -> void:
	_armada = false
	_ligar_monitores(false)


func esta_armada() -> bool:
	return _armada


# ⚠️ `set_deferred`, NÃO atribuição direta. Mexer em `monitoring` durante o
# processamento de física do Godot é erro de "flushing queries"; a espada é
# armada e desarmada de dentro de temporizadores que correm justamente ali.
func _ligar_monitores(ligado: bool) -> void:
	for b in _bolinhas:
		if is_instance_valid(b):
			b.set_deferred("monitoring", ligado)
			b.set_deferred("monitorable", ligado)


# ------------------------------------------------------------- o que acerta
func _no_corpo(corpo: Node3D) -> void:
	if not _armada or corpo == null or not is_instance_valid(corpo):
		return
	if corpo == dono or _ja_acertou.has(corpo):
		return
	if not corpo.has_method("take_damage"):
		return
	# Autoridade de combate: só o servidor aplica. Em cliente a lâmina é
	# desenho — a mesma regra da `DamageZone`.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_ja_acertou[corpo] = true

	var empurrao := Knockback.calcular(global_position, corpo.global_position,
		_kb, Knockback.PADRAO, Vector3.ZERO)
	CombatResolver.aplicar(corpo, _dano, _cast_id, _teto, global_position,
		empurrao, _hitstun)
	acertou.emit(corpo)

	var placar := get_tree().get_first_node_in_group("scoreboard") if get_tree() else null
	if placar and placar.has_method("register_hit"):
		placar.register_hit(corpo, dono)


# ------------------------------------------------- espada contra espada
## O choque. `area_entered` dispara nos DOIS lados, então o primeiro a chegar
## resolve e marca os dois — sem isso o cancelamento correria duas vezes e o
## efeito de tela sairia dobrado.
func _na_area(area: Area3D) -> void:
	if not _armada or area == null or not is_instance_valid(area):
		return
	var outra := area.get_parent() as SwordBlade
	if outra == null or outra == self or outra.dono == dono:
		return
	if _ja_chocou or outra._ja_chocou:
		return
	# ⚠️ O choque acontece mesmo que a outra lâmina esteja DESARMADA? Não. Duas
	# espadas só se anulam quando as duas estão golpeando — bater na espada
	# parada de alguém que está de guarda não é um clash, é um acerto que a
	# guarda resolve. `esta_armada()` é o que separa os dois casos.
	if not outra.esta_armada():
		return

	_ja_chocou = true
	outra._ja_chocou = true
	desarmar()
	outra.desarmar()

	var ponto := (global_position + outra.global_position) * 0.5
	_cancelar_golpe_de(dono)
	_cancelar_golpe_de(outra.dono)
	_efeito_de_choque(ponto)
	chocou.emit(outra)
	outra.chocou.emit(self)


## "anulando ambos os movimentos" — o golpe em voo dos DOIS é zerado. O
## `MeleeController.cancelar_golpe()` já existia para dash-cancel e morte: ele
## limpa `_passo_em_curso`, a trava de recuperação e o buffer de clique, que é
## exatamente o que "anular o movimento" quer dizer aqui.
func _cancelar_golpe_de(quem: Node) -> void:
	if quem == null or not is_instance_valid(quem):
		return
	var mc = quem.get("_melee")
	if mc != null and mc.has_method("cancelar_golpe"):
		mc.cancelar_golpe()
	if quem.has_method("lock_movement"):
		quem.lock_movement(0.0, "")


func _efeito_de_choque(ponto: Vector3) -> void:
	var mundo := get_tree().current_scene if get_tree() else null
	if mundo == null or not is_instance_valid(mundo):
		return
	# Fagulhas de metal + anel: os dois helpers já existem e são estáticos.
	var palco := Node3D.new()
	palco.name = "ChoqueDeEspadas"
	mundo.add_child(palco)
	palco.global_position = ponto
	GoroFX.shock_ring(palco, Vector3.ZERO, Color(1.0, 0.95, 0.7, 0.9), 0.9, 0.18, 0.14)
	palco.add_child(GoroFX.sparks(34, 0.32, Vector3.UP, 95.0, 4.0, 11.0, 0.10))
	FxUtil.autofree(palco, 0.55)
	AudioFX.snap(mundo, ponto, 0.75)

	var gf := get_node_or_null("/root/GameFlow")
	if gf and gf.has_method("hit_stop"):
		gf.hit_stop()
	var sfx := get_node_or_null("/root/ScreenFX")
	if sfx and sfx.has_method("flash"):
		sfx.flash(Color(1.0, 0.95, 0.75), 0.18)
