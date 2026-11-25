class_name McRede
extends RefCounted
## `PacketDistributor` / `SimpleChannel` do Forge: pacotes entre cliente e servidor. Num jogo só (ou com o
## servidor do jogo) o efeito de cada pacote — animação, velocidade, partícula — já vem por outro caminho
## da camada; aqui eles são ABSORVIDOS e CONTADOS (`rede:<mensagem>`), para a fidelidade não ser declarada
## sem saber quais pacotes o mod mandou.

static var _unica: McRede


static func instancia() -> McRede:
	if _unica == null:
		_unica = McRede.new()
	return _unica


func with(_alvo: Variant = null) -> McRede: return self
func noArg() -> McRede: return self


## `new MinepieceModAnimationMessage(clipe, idDaEntidade, override)` (SetupAnimationsProcedure).
class Animacao:
	extends RefCounted
	var clipe := ""
	var alvo := 0
	var sobrescrever := false


func send(_destino: Variant = null, mensagem: Variant = null) -> void:
	if mensagem is Animacao:
		_tocar_animacao(mensagem)
		return
	Mc.contar("rede:%s" % (mensagem.get_script().get_global_name() if mensagem is Object and mensagem.get_script() != null else "pacote"))


## O pacote vai ao cliente do jogador; aqui o corpo do jogo é o `alvo` (id de instância do nó, o `getId()` da camada).
## Só o jogador tem clipe de PlayerAnimator; para os outros corpos o pacote não existe no mod.
func _tocar_animacao(m: Animacao) -> void:
	var corpo := instance_from_id(m.alvo) as Node
	if corpo == null or not is_instance_valid(corpo) or not corpo.is_in_group("player"):
		Mc.contar("rede:animacao_sem_jogador")
		return
	if not PoseDoMod.tem(m.clipe):
		Mc._falta("animacao", "clipe_ausente:%s" % m.clipe)
		return
	AnimacaoDoMod.no_de(corpo).tocar(m.clipe, m.sobrescrever)
	# Multiplayer: o mod roda no servidor; os outros peers (e o próprio dono) tocam o clipe pelo RPC do corpo.
	if corpo.multiplayer != null and corpo.multiplayer.has_multiplayer_peer() and corpo.multiplayer.is_server() and corpo.has_method("_net_animacao_do_mod"):
		corpo.rpc("_net_animacao_do_mod", m.clipe, m.sobrescrever)
