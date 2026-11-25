class_name MusicaDoDesafio
extends Node
# ============================================================================
#  MÚSICA DO DESAFIO DO BUGGY (21/11/2026) — três peças INSTRUMENTAIS sintetizadas por `tools/audio/sintetizar_buggy.py` a partir do briefing do Codex
#  (`art_src/audio/buggy_cutscene/BRIEFING.md`): a trilha da chegada (28,5 s), o sting da gargalhada (4,4 s) e o loop do jogo dos copos (12 s).
#  Um único `AudioStreamPlayer` por faixa; `parar` sempre faz fade. Arquivo ausente (cópia sem os assets) = silêncio, nunca erro.
# ============================================================================
const PASTA := "res://assets/audio/musica/"
const CHEGADA := PASTA + "buggy_chegada.ogg"
const STING := PASTA + "buggy_sting_riso.ogg"
const COPOS := PASTA + "buggy_copos_loop.ogg"

## Pedido do dono (22/11/2026): sem música no desafio do Buggy e na missão da Alvida. As faixas e a síntese ficam; basta ligar aqui para voltarem.
## GATILHO: religar quando houver uma trilha aprovada pelo dono.
const LIGADA := false

var volume_db := -6.0
var _tocando: Dictionary = {}          # caminho → AudioStreamPlayer


func tocar(caminho: String, em_loop := false, fade := 0.6, db := volume_db) -> AudioStreamPlayer:
	if not LIGADA or not ResourceLoader.exists(caminho):
		return null
	parar(caminho, 0.05)
	var stream := load(caminho) as AudioStream
	if stream == null:
		return null
	if em_loop and stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.name = "Musica_" + caminho.get_file().get_basename()
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	p.play()
	create_tween().tween_property(p, "volume_db", db, maxf(fade, 0.01))
	_tocando[caminho] = p
	return p


func parar(caminho: String, fade := 0.8) -> void:
	var p: AudioStreamPlayer = _tocando.get(caminho)
	_tocando.erase(caminho)
	if p == null or not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, maxf(fade, 0.01))
	t.tween_callback(p.queue_free)


func parar_tudo(fade := 0.8) -> void:
	for c in _tocando.keys():
		parar(c, fade)


func tocando(caminho: String) -> bool:
	var p: AudioStreamPlayer = _tocando.get(caminho)
	return p != null and is_instance_valid(p) and p.playing
