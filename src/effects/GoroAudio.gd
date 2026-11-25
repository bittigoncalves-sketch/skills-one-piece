class_name GoroAudio
extends RefCounted
## Assets mono de 48 kHz, sintetizados offline por `tools/generate_goro_audio.py`;
## nenhuma síntese no frame de cast. Mesmo desenho do `OpeAudio`.
##
## ⚠️ ESTES SONS NÃO SUBSTITUEM O `AudioFX`, SOMAM-SE A ELE. O `AudioFX.snap`,
## `cannon` e `whoosh` continuam onde estavam: eles são a camada genérica de
## impacto que todo golpe do jogo tem, e arrancá-la deixaria a Goro mais fina, não
## mais autoral. O que entra aqui é a ASSINATURA da fruta — o estalo elétrico e o
## trovão rolando — tocada junto.

const CUES := {
	"sango": "res://assets/audio/goro_sango.wav",
	"elthor": "res://assets/audio/goro_elthor.wav",
	"shunshin": "res://assets/audio/goro_shunshin.wav",
	"mamaragan": "res://assets/audio/goro_mamaragan.wav",
	"carga": "res://assets/audio/goro_carga.wav",
}
static var _streams: Dictionary = {}

## Volume por cue. O `carga` fica bem abaixo: é um zumbido que dura toda a
## carga e, no mesmo nível dos golpes, viraria o som mais alto da fruta.
const VOLUME := {
	"sango": -6.5,
	"elthor": -4.0,
	"shunshin": -8.0,
	"mamaragan": -4.0,
	"carga": -14.0,
}

## Alcance por cue. O trovão do X e a queda do V acontecem LONGE do jogador
## desde a remodelação de 2026-09-12 — com os 60 m do resto eles emudeciam
## justamente quando o golpe era usado no alcance para o qual foi feito.
const ALCANCE := {
	"elthor": 140.0,
	"mamaragan": 140.0,
}

static func play(parent: Node, position: Vector3, cue: String) -> AudioStreamPlayer3D:
	if not is_instance_valid(parent) or DisplayServer.get_name() == "headless":
		return null
	if not CUES.has(cue):
		return null
	if not _streams.has(cue):
		_streams[cue] = load(CUES[cue])
	var stream := _streams[cue] as AudioStream
	if stream == null:
		return null
	var sound := AudioStreamPlayer3D.new()
	sound.name = "GoroAudio_" + cue
	sound.stream = stream
	sound.volume_db = float(VOLUME.get(cue, -6.0))
	sound.unit_size = 7.0
	sound.max_distance = float(ALCANCE.get(cue, 60.0))
	sound.max_polyphony = 1
	parent.add_child(sound)
	sound.global_position = position
	sound.finished.connect(sound.queue_free)
	sound.play()
	return sound
