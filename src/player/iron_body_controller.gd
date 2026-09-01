class_name IronBodyController
extends RefCounted

# ============================================================================
#  CORPO DE FERRO — a "defesa avançada" da Fase 6 do plano de combate.
#
#  ⚠️ O PLANO DIZIA PARA NÃO REUTILIZAR F, e o dono resolveu por outro caminho:
#  em vez de achar outra tecla, a defesa PASSOU A SER o Corpo de Ferro. Pedido
#  dele, 2026-08-31: "tecla F abre uma janela com a habilidade corpo de ferro
#  que corta os danos pela metade e torna a imunidade a qualquer efeito, mesmo
#  que este esteja em ação".
#
#  São duas mudanças de natureza oposta, e é isso que faz a habilidade ter
#  identidade em vez de ser "um segundo de imunidade":
#
#    DANO ....... AFROUXOU. Era invulnerabilidade total; agora corta pela
#                 metade. Quem aperta F ainda apanha, e a janela deixa de
#                 apagar um golpe inteiro.
#    EFEITOS .... APERTOU. Era uma lista fixa (congelado, sugado, buraco
#                 negro, silenciado); agora é QUALQUER efeito, e a recusa mora
#                 no `StatusFX.aplicar` — uma lista precisaria ser atualizada a
#                 cada efeito novo, e o primeiro esquecido furaria a imunidade
#                 sem ninguém notar.
# ============================================================================

const DURACAO := 1.0
const RECARGA := 30.0
## Quanto do dano passa durante a janela. "Corta pela metade" = 0,5.
const FATOR_DE_DANO := 0.5
var _dono: Node
var _tempo := 0.0
var _recarga := 0.0

func montar_em(dono: Node) -> void: _dono = dono
func pronto() -> bool: return _recarga <= 0.0 and _tempo <= 0.0
func recarga() -> float: return _recarga

func atualizar(delta: float) -> void:
	_recarga = maxf(_recarga - delta, 0.0)
	if _tempo <= 0.0: return
	_tempo = maxf(_tempo - delta, 0.0)
	if _tempo <= 0.0 and _dono:
		_dono.set_meta("iron_body_active", false)
		StatusFX.remover(_dono, StatusFX.INVULNERAVEL)

func ativar_confirmado() -> void:
	if _dono == null: return
	_tempo = DURACAO
	_recarga = RECARGA
	_dono.set_meta("iron_body_active", true)
	RecepcaoDeDano.limpar(_dono)
	_dono.set_meta("is_frozen", false)
	_dono.set_meta("in_vortex", false)
	_dono.set_meta("in_kurouzu", false)
	_dono.set_meta("in_black_hole", false)
	# ⚠️ TUDO, e não a lista de quatro que estava aqui. "Mesmo que este esteja em
	# ação" quer dizer que os efeitos já rodando saem — e uma lista fixa deixaria
	# de fora todo efeito criado depois dela.
	StatusFX.limpar_tudo(_dono)
	if _dono.has_method("limpar_silencio_de_corpo_de_ferro"):
		_dono.limpar_silencio_de_corpo_de_ferro()
	StatusFX.aplicar(_dono, StatusFX.INVULNERAVEL, DURACAO)
	var modelo := _dono.get("_char_model") as Node3D
	if modelo:
		FxUtil.flash_red(modelo)
