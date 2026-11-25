class_name DadosEastBlue
extends RefCounted
# ============================================================================
#  DADOS DOS PERSONAGENS DO EAST BLUE (Mine Piece, 17/10/2026).
#
#  Lê `mapas/east_blue/personagens.json` (vida, armadura, força, facção, técnicas — gerado
#  por tools/mine_piece/gerar_dados_east_blue.py a partir do mod) e
#  `mapas/east_blue/animacoes.json` (clipe original de cada skill `mpeb_*`). Arquivos
#  editáveis: o dono vai recalibrar tudo antes de lançar (docs/EAST_BLUE_PLANO.md).
#
#  Também guarda as CONTAS do mod, para quem lança e quem apanha usarem as mesmas:
#    • dano da técnica × (1 + 0,333 × nível de força), nível = ataque total × 0,333,
#      ataque total = dano do corpo + 3 × (amplificador da Força + 1);
#    • armadura como a do Minecraft; Resistência −20 %/nível (imune no 5º).
# ============================================================================

const ARQUIVO := "res://mapas/east_blue/personagens.json"
const ARQUIVO_DE_ANIMACOES := "res://mapas/east_blue/animacoes.json"
## Comportamento no catálogo da loja: a peça vira um personagem vivo no Modo História.
const COMPORTAMENTO := "mine_piece"
## Categoria da loja do editor.
const CATEGORIA := "east_blue_mine_piece"

static var _fichas := {}            # id → ficha
static var _por_modelo := {}        # id do modelo da loja → id da ficha
static var _anims := {}             # id da skill → {"punho": clipe, "espada": clipe}
static var _lido := false


static func _ler() -> void:
	if _lido:
		return
	_lido = true
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
	if dados is Dictionary and dados.get("personagens") is Array:
		for f: Variant in dados.personagens:
			if not (f is Dictionary) or not f.has("id"):
				continue
			_preferir_arte_propria(f)
			_fichas[str(f.id)] = f
			_por_modelo[str(f.get("modelo", ""))] = str(f.id)
			for m: Variant in f.get("modelos", []):
				_por_modelo[str(m)] = str(f.id)
	else:
		push_warning("[DadosEastBlue] sem dados em " + ARQUIVO)
	var anims: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_DE_ANIMACOES)) if FileAccess.file_exists(ARQUIVO_DE_ANIMACOES) else null
	if anims is Dictionary and anims.get("skills") is Dictionary:
		_anims = anims.skills


## Reconstrução própria (25/11/2026): se existe `pi_<id>.glb` (tools/mine_piece/reconstruir_primeira_ilha.py), a ficha
## passa a usá-lo no lugar do `mp_*` convertido do mod. O dado do mod (vida, golpes, IA) não muda; só a arte.
static func _preferir_arte_propria(f: Dictionary) -> void:
	var proprio := "pi_%s" % str(f["id"])
	if ResourceLoader.exists("res://mapas/modelos/%s.glb" % proprio):
		f["modelo_do_mod"] = f.get("modelo", "")
		f["modelo"] = proprio
		f["modelos"] = []


static func recarregar() -> void:
	_lido = false
	_fichas.clear()
	_por_modelo.clear()
	_anims.clear()


static func ids() -> Array:
	_ler()
	return _fichas.keys()


static func ficha(id: String) -> Dictionary:
	_ler()
	return _fichas.get(id, {})


## A ficha do personagem que este modelo da loja representa ({} se nenhum).
static func ficha_do_modelo(modelo: String) -> Dictionary:
	_ler()
	return ficha(str(_por_modelo.get(modelo, "")))


## Clipe original do modelo para a skill (com arma ou de mãos nuas). "" = nenhum.
static func clipe_da_skill(skill_id: String, com_arma: bool) -> String:
	_ler()
	var a: Dictionary = _anims.get(skill_id, {})
	return str(a.get("espada" if com_arma else "punho", ""))


## Multiplicador de dano das técnicas pela força (DamageFix do mod).
static func multiplicador_de_forca(f: Dictionary) -> float:
	var forca := float(f.get("forca", -1.0))
	var ataque := float(f.get("dano_corpo", 1.0)) + (3.0 * (forca + 1.0) if forca >= 0.0 else 0.0)
	return 1.0 + ataque * 0.333 * 0.333


## Dano que sobra depois da armadura (Minecraft) e da Resistência (−20 %/nível).
static func dano_recebido(f: Dictionary, dano: float) -> float:
	var armadura := float(f.get("armadura", 0.0))
	var tenacidade := float(f.get("tenacidade", 0.0))
	var reducao := clampf(maxf(armadura / 5.0, armadura - dano / (2.0 + tenacidade / 4.0)), 0.0, 20.0) / 25.0
	var d := dano * (1.0 - reducao)
	var resistencia := float(f.get("resistencia", -1.0))
	if resistencia >= 0.0:
		d *= maxf(0.0, 1.0 - 0.2 * (resistencia + 1.0))
	return d
