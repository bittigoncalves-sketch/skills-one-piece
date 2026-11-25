class_name EstilosDoMod
extends RefCounted
## CLASSES/ESTILOS DO MOD (09/11/2026, item 1 da auditoria): as 23 `Select*Procedure` do Mine Piece — cada uma define `PlayerSkill1` (o "modo" do jogador:
## 1 = Zoro, 2 = Shanks, 3 = Kaido, 4 = Rokushiki, 5 = Mihawk, 7 = Homem-peixe, 9 = Lunariano, 10 = Gigante, 13 = Ciborgue, 30 = Espadachim, 31 = Lutador,
## 32 = Pistoleiro…), roda `Selected` (zera o que o estilo anterior deixou) e `SelectedArmorEquip` (veste o traje do estilo). No mod, estilo e fruta são EXCLUSIVOS:
## O controlador de frutas do jogo (`ControladorFrutaDoMod`) põe `PlayerSkill1 = 1` ao nascer; `voltar_as_frutas` repõe esse valor.
##
## O QUE EXISTE: a escolha (API testada nas 23). O QUE FALTA: um controlador que LISTE e dispare as técnicas do estilo (números 1–20 de `KeyChangeTechniqueOnKeyPressed`/
## `Skill<Estilo>`), como o `ControladorFrutaDoMod` faz para as frutas (21–30). Por isso NÃO há tela para escolher estilo ainda: o jogador escolheria e ficaria sem como usar.
## GATILHO: quando existir o controlador de estilo, ligar uma aba ESTILO na central (M) a `EstilosDoMod.escolher`.

## id curto → [procedure Select*, rótulo]
const ESTILOS := {
	"zoro": ["SelectZoro", "Zoro"], "shanks": ["SelectShanks", "Shanks"], "kaido": ["SelectKaido", "Kaido"], "rokushiki": ["SelectRokushiki", "Rokushiki"],
	"mihawk": ["SelectMihawk", "Mihawk"], "sem_estilo": ["SelectNoSkill", "Sem estilo"], "fishman": ["SelectFishman", "Homem-peixe"], "sabo": ["SelectSabo", "Sabo"],
	"lunarian": ["SelectLunarian", "Lunariano"], "giant": ["SelectGiant", "Gigante"], "elizabello2": ["SelectElizabello2", "Elizabello II"],
	"celestial_dragons": ["SelectCelestialDragons", "Dragões Celestiais"], "cyborg": ["SelectCyborg", "Ciborgue"], "garp": ["SelectGarp", "Garp"],
	"usopp": ["SelectUsopp", "Usopp"], "roger": ["SelectRoger", "Roger"], "oden": ["SelectOden", "Oden"], "sanji": ["SelectSanji", "Sanji"],
	"curiel": ["SelectCuriel", "Curiel"], "indigo": ["SelectIndigo", "Dr. Indigo"], "swordsman": ["SelectSwordsman", "Espadachim"],
	"fighter": ["SelectFighter", "Lutador"], "gunman": ["SelectGunman", "Pistoleiro"], "general": ["SelectGeneral", "General"],
}


static func ids() -> Array:
	return ESTILOS.keys()


static func rotulo(id: String) -> String:
	return str(ESTILOS[id][1]) if ESTILOS.has(id) else id


## Escolhe a classe/estilo `id` pelo fluxo do mod. Devolve o novo `PlayerSkill1` (o "modo" do jogador), ou -1 se o id não existe.
static func escolher(jogador: Node, id: String) -> float:
	if not ESTILOS.has(id) or jogador == null or not is_instance_valid(jogador):
		return -1.0
	var e := McEntidade.de(jogador)
	Mc.proc(StringName(str(ESTILOS[id][0]) + "Procedure")).execute(e.level(), e)
	var v = e.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	return float(v.PlayerSkill1) if v != null else -1.0


## O modo fruta do jogo: `PlayerSkill1 = 1` (é o que o `ControladorFrutaDoMod` põe ao nascer).
static func voltar_as_frutas(jogador: Node) -> void:
	var v = McEntidade.de(jogador).getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	if v != null:
		v.PlayerSkill1 = 1.0
