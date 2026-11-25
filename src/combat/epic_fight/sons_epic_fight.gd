class_name SonsEpicFight
extends RefCounted
## SONS DO EPIC FIGHT (12/11/2026): os `.ogg` do mod (golpe/whoosh e impacto lâmina/contundente) tocados em 3D no ponto do golpe.
## Ficam em `assets/epic_fight/sons/` (LOCAL, fora do git; `tools/epic_fight/extrair_itens.py`). Quem escolhe QUAL som é a arma
## (`LaminasEpicFight.sons`): swingSound da categoria e hitSound do material, como o `EpicFightItemCapabilityPresets` do mod.
const PASTA := "res://assets/epic_fight/sons/"
static var _cache := {}


static func existe(nome: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(PASTA + nome + ".ogg"))


static func stream(nome: String) -> AudioStream:
	if _cache.has(nome):
		return _cache[nome]
	var caminho := ProjectSettings.globalize_path(PASTA + nome + ".ogg")
	var s: AudioStream = AudioStreamOggVorbis.load_from_file(caminho) if FileAccess.file_exists(caminho) else null
	_cache[nome] = s
	return s


## Toca um dos `nomes` (sorteado) em `posicao`. Devolve false se nenhum existe (quem chamou cai no som padrão do jogo).
static func tocar(mundo: Node, posicao: Vector3, nomes: Array, volume_db := 0.0) -> bool:
	if mundo == null or nomes.is_empty():
		return false
	var nome := str(nomes.pick_random())
	var s := stream(nome)
	if s == null:
		return false
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.unit_size = 12.0
	mundo.add_child(p)
	p.global_position = posicao
	p.finished.connect(p.queue_free)
	p.play()
	return true
