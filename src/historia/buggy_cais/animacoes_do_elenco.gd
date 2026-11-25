class_name AnimacoesDoElenco
extends Node
# ============================================================================
#  ANIMAÇÕES DO ELENCO (21/11/2026) — os modelos `mp_*` já trazem um `AnimationPlayer` (idle, walk, clap, enkai, both_arm_up, negative…). Este nó (filho do modelo) escolhe
#  QUAL tocar: base = `idle` (parado) ou `walk` (andando); falando, de tempos em tempos faz um GESTO (braços ao alto, aplauso, "enkai", negação), voltando à base.
#  Quem não tem a animação (o Richie só tem idle/walk) simplesmente ignora o gesto. Sem estado externo: `andar(bool)`, `falar(bool)`, `gesto(nome)`.
#  GATILHO: elenco com rig diferente (Skeleton3D) → o mapeamento de nomes vem de um recurso; hoje o conjunto é o mesmo em todos os `mp_*`.
# ============================================================================
const GESTOS_DE_FALA := ["both_arm_up", "enkai", "clap", "negative", "right_arm_up"]
const GESTOS_DE_RISO := ["enkai", "clap", "both_arm_up"]
const FUSAO := 0.18

var _ap: AnimationPlayer
var _andando := false
var _falando := false
var _gesto_ate := 0.0
var _proximo_gesto := 0.0
var _relogio := 0.0
var _rng := RandomNumberGenerator.new()
var atual := ""


static func de(modelo: Node, semente := 0) -> AnimacoesDoElenco:
	var ap := modelo.find_children("*", "AnimationPlayer", true, false)
	if ap.is_empty():
		return null
	var n := AnimacoesDoElenco.new()
	n.name = "AnimacoesDoElenco"
	n._ap = ap[0] as AnimationPlayer
	n._rng.seed = semente if semente != 0 else hash(modelo.name)
	modelo.add_child(n)
	n._tocar(n._base())
	return n


func tem(nome: String) -> bool:
	return _ap != null and _ap.has_animation(nome)


func andar(sim: bool) -> void:
	_andando = sim


func falar(sim: bool) -> void:
	_falando = sim
	_proximo_gesto = _relogio + 0.4


## Gesto pontual (se o modelo tiver a animação). Devolve se tocou.
## `manter`: fica na pose final (a animação não volta à base) até `soltar()` — o Buggy derrotado no ringue.
func gesto(nome: String, manter := false, velocidade := 1.0) -> bool:
	if not tem(nome):
		return false
	_gesto_ate = INF if manter else _relogio + _ap.get_animation(nome).length / maxf(velocidade, 0.05)
	_tocar(nome, velocidade)
	return true


## Volta à base (idle/walk) depois de um gesto mantido.
func soltar() -> void:
	_gesto_ate = 0.0
	atual = ""
	_tocar(_base())


func _base() -> String:
	if _andando and tem("walk"):
		return "walk"
	return "idle" if tem("idle") else ""


func _tocar(nome: String, velocidade := 1.0) -> void:
	if nome.is_empty() or _ap == null or atual == nome and _ap.is_playing() and is_equal_approx(velocidade, 1.0):
		return
	atual = nome
	_ap.play(nome, FUSAO, velocidade)


func _process(delta: float) -> void:
	_relogio += delta
	if _ap == null:
		return
	if _relogio < _gesto_ate:
		return
	if _falando and _relogio >= _proximo_gesto:
		var lista := GESTOS_DE_FALA.filter(func(g: String) -> bool: return tem(g))
		if not lista.is_empty():
			gesto(lista[_rng.randi_range(0, lista.size() - 1)])
			_proximo_gesto = _relogio + _rng.randf_range(2.2, 3.6)
			return
	_tocar(_base())
	if atual == "idle" or atual == "walk":
		if not _ap.is_playing():
			_ap.play(atual)
