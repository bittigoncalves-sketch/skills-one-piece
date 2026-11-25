class_name PikaAudio
extends RefCounted
## Voz sonora da PIKA PIKA NO MI.
##
## Assets mono de 48 kHz gerados OFFLINE por `tools/generate_pika_audio.py`.
## Nenhuma síntese roda no quadro do cast — e isso não é preferência de estilo:
## o C cria 3 fragmentos a cada 0,05 s (60 por segundo), e o `AudioFX`, que
## sintetiza o WAV na hora, foi escrito para gatilhos lentos. Mesmo com o pool
## de variantes dele, a primeira conjuração pagaria a geração inteira no quadro
## do aperto de tecla. Aqui o custo é um `load()` na primeira vez e nada depois.
##
## ------------------------------------------------------------ POR QUE EXISTE
## A Pika tocava `AudioFX.gunshot` em cada raio do Z. Medido no vídeo de
## referência do dono (`skill X pika pika.mp4`), a fruta tem **0,0% de energia
## abaixo de 300 Hz** do início ao fim da técnica; o `gunshot` escorrega de
## 450 Hz para 50 Hz com corpo grave e sub em 75 Hz. Era pólvora tocando por
## cima de luz. O raciocínio completo, com as bandas medidas, está no cabeçalho
## do gerador.
##
## ------------------------------------------------------------- TETO DE VOZES
## `OpeAudio` cria um `AudioStreamPlayer3D` por chamada e confia na cadência do
## golpe para não empilhar. A Ope tem 5 cues em golpes espaçados; a Pika tem
## barragem. Sem teto, uma conjuração do C com quatro jogadores na arena
## penduraria centenas de nós de áudio no mesmo quadro. O teto é POR CUE porque
## é assim que ele protege a leitura: 3 fragmentos simultâneos ainda soam a
## rajada, 40 soam a ruído branco.

const CUES := {
	"carga":     "res://assets/audio/pika_carga.wav",
	"disparo":   "res://assets/audio/pika_disparo.wav",
	"fragmento": "res://assets/audio/pika_fragmento.wav",
	"impacto":   "res://assets/audio/pika_impacto.wav",
	"viagem":    "res://assets/audio/pika_viagem.wav",
	"explosao":  "res://assets/audio/pika_explosao.wav",
	"teleporte": "res://assets/audio/pika_teleporte.wav",
	"barragem":  "res://assets/audio/pika_barragem.wav",
	"ceu":       "res://assets/audio/pika_ceu.wav",
	"chuva":     "res://assets/audio/pika_chuva.wav",
}

# Volume base por cue, em dB. Não é gosto: é a conta de quantos tocam juntos.
# O `fragmento` sai 9 dB abaixo do `disparo` porque são ~60 por segundo contra
# 7 por salva — a soma é que dá o volume da barragem, como no minigun da Buki.
const VOLUME := {
	"carga": -7.0, "disparo": -6.5, "fragmento": -15.5, "impacto": -8.0,
	"viagem": -7.5, "explosao": -4.5, "teleporte": -8.5, "barragem": -11.0,
	"ceu": -9.0, "chuva": -10.5,
}

# Quantas instâncias do MESMO cue podem soar ao mesmo tempo.
const TETO := {
	"fragmento": 4, "chuva": 5, "disparo": 7, "impacto": 6,
}
const TETO_PADRAO := 3

const ALCANCE := 55.0
const TAMANHO_UNIDADE := 7.0

static var _streams: Dictionary = {}
static var _vozes: Dictionary = {}


## `pitch` varia entre chamadas para a repetição não virar metrônomo — o mesmo
## motivo do pool de variantes do `AudioFX`, resolvido sem gastar memória.
static func play(parent: Node, position: Vector3, cue: String,
		pitch: float = 1.0, volume_offset_db: float = 0.0) -> AudioStreamPlayer3D:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	if DisplayServer.get_name() == "headless":
		return null
	if not CUES.has(cue):
		push_warning("PikaAudio: cue desconhecido -> %s" % cue)
		return null
	if _contar(cue) >= int(TETO.get(cue, TETO_PADRAO)):
		return null

	var stream := _stream(cue)
	if stream == null:
		return null

	var som := AudioStreamPlayer3D.new()
	som.name = "PikaAudio_" + cue
	som.stream = stream
	som.pitch_scale = maxf(0.05, pitch)
	som.volume_db = float(VOLUME.get(cue, -8.0)) + volume_offset_db
	som.unit_size = TAMANHO_UNIDADE
	som.max_distance = ALCANCE
	som.max_polyphony = 1
	parent.add_child(som)
	som.global_position = position
	_ocupar(cue, som)
	som.finished.connect(som.queue_free)
	som.play()
	return som


## Leito CONTÍNUO, para golpe sustentado. A barragem do C dura 1,5 s e o
## `pika_barragem.wav` tem 1,10 s: sem laço, a cama de som sumiria no meio da
## rajada, que é pior do que não ter cama nenhuma. O stream é DUPLICADO antes de
## receber o laço — o do cache é compartilhado, e marcá-lo faria todo uso
## futuro daquele cue nascer em loop.
##
## Quem chama é dono de parar: guarde o retorno e passe em `parar()`.
static func play_loop(parent: Node, position: Vector3, cue: String,
		pitch: float = 1.0, volume_offset_db: float = 0.0) -> AudioStreamPlayer3D:
	var som := play(parent, position, cue, pitch, volume_offset_db)
	if som == null:
		return null
	var wav := som.stream as AudioStreamWAV
	if wav == null:
		return som
	var laco := wav.duplicate() as AudioStreamWAV
	laco.loop_mode = AudioStreamWAV.LOOP_FORWARD
	laco.loop_begin = 0
	laco.loop_end = 0            # 0 = até o fim do dado
	som.stream = laco
	som.play()
	return som


## Para um som sustentado antes do fim (soltar o C encerra a barragem, e o
## leito não pode continuar tocando um golpe que já acabou).
static func parar(som: AudioStreamPlayer3D, esmaecer: float = 0.12) -> void:
	if not is_instance_valid(som):
		return
	if esmaecer <= 0.0 or not som.is_inside_tree():
		som.queue_free()
		return
	var tw := som.create_tween()
	tw.tween_property(som, "volume_db", -40.0, esmaecer)
	tw.tween_callback(som.queue_free)


static func _stream(cue: String) -> AudioStream:
	if not _streams.has(cue):
		_streams[cue] = ResourceLoader.load(CUES[cue])
	return _streams[cue] as AudioStream


# O teto conta nós VIVOS, não chamadas. Varrer a lista na hora de tocar é mais
# barato — e mais correto — do que manter um contador que decrementa por sinal:
# `queue_free` no meio de um `finished` já deixou contador furado neste projeto.
static func _contar(cue: String) -> int:
	var lista: Array = _vozes.get(cue, [])
	var vivos: Array = []
	for v in lista:
		if is_instance_valid(v) and (v as AudioStreamPlayer3D).playing:
			vivos.append(v)
	_vozes[cue] = vivos
	return vivos.size()


static func _ocupar(cue: String, som: AudioStreamPlayer3D) -> void:
	var lista: Array = _vozes.get(cue, [])
	lista.append(som)
	_vozes[cue] = lista
