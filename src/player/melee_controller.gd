class_name MeleeController
extends RefCounted
# ============================================================================
#  CORPO A CORPO — o combo do clique: soco direito, soco esquerdo, chute.
#
#  Fase 7 de docs/ARQUITETURA_PLAYER.md. A tabela dos golpes (tempos, alcance,
#  clipe de animação) mora em `src/combat/Melee.gd` e continua lá — aqui fica o
#  ESTADO do combo e a decisão de quando o próximo golpe pode sair.
#
#  ---------------------------------------------------------------- OS 2 RELÓGIOS
#  `_trava`  RECUPERAÇÃO: enquanto corre, o clique não vira golpe. É o que dá
#            peso ao soco — sem ela o combo vira metralhadora.
#  `_janela` ENCADEAMENTO: tempo que ainda resta para o próximo clique continuar
#            o combo. Vencida, o próximo clique volta ao primeiro soco.
#
#  ------------------------------------------------------------------- O BUFFER
#  Clique que chega DURANTE a recuperação não some: fica guardado e sai sozinho
#  quando a trava abre. Sem isso o combo pune justamente quem clica no ritmo —
#  e os tempos de recuperação cresceram (0,40 → 0,58 s) para o soco caber em
#  tela, o que só aumentou a janela em que o clique se perdia.
#
#  O buffer é curto de propósito: clique de 1 s atrás não é intenção de agora.
#
#  ---------------------------------------------------------------- A FRONTEIRA
#  Ele decide; o Player fala rede e apresenta. Os `@rpc` (`_net_melee`,
#  `_net_play_melee`) e o `_do_server_melee` ficam no Player desde a Fase 5:
#  RPC se resolve por CAMINHO DE NÓ.
#
#  ⚠️ Nunca chama `is_multiplayer_authority()`: a autoridade NÃO desce para
#  componentes criados no `_ready()` (medido na Fase 5: pai=7, filho=1).
# ============================================================================

# Até quanto antes de a trava abrir o clique ainda é guardado.
const BUFFER := 0.18

var _dono: Node = null

var _passo: int = 0        # em que golpe do combo estamos
var _janela: float = 0.0   # tempo restante para encadear
var _trava: float = 0.0    # recuperação: bloqueia o clique durante o golpe
var _buffer: float = 0.0   # clique que chegou na recuperação, esperando a vez

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func passo() -> int:    return _passo
func janela() -> float: return _janela
func trava() -> float:  return _trava

# --------------------------------------------------------------------- clique
# `yaw` entra por parâmetro: a mira é do Player desde a Fase 2.
func pedir(yaw: float) -> void:
	if not _dono._is_authority or _dono._charging:
		return
	var hud := _dono.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open") and hud.is_menu_open():
		return

	# Clique durante a recuperação: guarda em vez de perder (ver o cabeçalho).
	if _trava > 0.0:
		if _trava <= BUFFER:
			_buffer = BUFFER
		return

	var w = _dono.equipped_weapon if _dono and "equipped_weapon" in _dono else ""
	var combo_len = Melee.COMBO_SWORD.size() if w == "sword" else Melee.COMBO.size()
	
	# Janela vencida (ou combo terminado) -> recomeça do primeiro soco.
	if _janela <= 0.0 or _passo >= combo_len:
		_passo = 0
	var golpe := Melee.passo(_passo, w)
	var s := 1.0
	if "scale" in _dono:
		s = _dono.scale.y

	# A TRAVA É A DURAÇÃO DA ANIMAÇÃO (2026-08-15). Ver `Melee.recuo()`.
	#
	# ⚠️ E NÃO ESCALA MAIS COM O PORTE. O `* s` fazia sentido quando o número era
	# escrito à mão (personagem grande, golpe mais pesado), mas o clipe toca no
	# mesmo `vel` seja qual for a escala: manter o fator daria à Gura Gura, que
	# dobra a escala ao equipar (`scale = 2`), uma trava de 2,98 s para uma
	# animação de 1,49 s. A trava é a animação, e a animação não conhece escala.
	_trava = Melee.recuo(_passo, w)
	_janela = Melee.JANELA

	var fwd := -Basis.from_euler(Vector3(0, yaw, 0)).z
	var origem: Vector3 = _dono.global_position + Vector3.UP * (1.0 * s)

	# ⚠️ O TRANCO DE CÂMERA SAI NO SOCO, NÃO NO CLIQUE. Ele já foi disparado
	# aqui direto — ou seja, até 0,5 s antes de a hitbox nascer: a tela sacudia
	# na preparação e ficava parada no impacto. Era exatamente o sintoma
	# relatado, "o impacto não sai no momento do soco".
	var t_impacto := _dono.get_tree().create_timer(float(golpe["atraso"]))
	var forca: float = float(golpe["shake"])
	t_impacto.timeout.connect(func():
		_dono.add_camera_shake(forca)
		_dono.pedir_soco_de_fov(3.0))

	_dono.pedir_golpe_no_servidor(_passo, origem, fwd)
	_passo += 1

# --------------------------------------------------------------------- ciclo
# Corre os dois relógios do combo.
func tick(delta: float, yaw: float) -> void:
	if _trava > 0.0:
		_trava = maxf(_trava - delta, 0.0)
		if _trava == 0.0 and _buffer > 0.0:
			_buffer = 0.0
			pedir(yaw)                # o clique guardado sai agora que a trava abriu

	if _buffer > 0.0:
		_buffer = maxf(_buffer - delta, 0.0)
	if _janela > 0.0:
		_janela = maxf(_janela - delta, 0.0)
		if _janela == 0.0:
			_passo = 0            # esfriou: o próximo clique volta ao soco direito

