extends SceneTree
# ============================================================================
#  ÁUDIO DA PIKA PIKA — os assets existem, importam e têm o timbre certo?
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/test_pika_audio.gd
#
#  ⚠️ ESTE TESTE EXISTE POR UM DEFEITO QUE A BATERIA INTEIRA DEIXOU PASSAR.
#
#  Ao gerar os dez `.wav` da fruta, os testes de jogo continuaram verdes e o som
#  não funcionava: os arquivos não tinham `.import`, então o `ResourceLoader`
#  devolvia `null` para os dez e a Pika ficava MUDA no jogo. Nenhum teste pegou
#  porque `PikaAudio.play()` sai cedo em `DisplayServer == "headless"` — ou
#  seja, o caminho que carrega o recurso nunca era exercitado. Bateria verde e
#  fruta muda ao mesmo tempo.
#
#  Aqui o `load` é chamado DIRETO, sem passar pelo portão do headless. É a única
#  forma de um teste sem tela provar que existe som.
#
#  A checagem de espectro existe pelo motivo oposto: garantir que o arquivo
#  continua sendo o que foi MEDIDO. A assinatura da fruta, tirada do vídeo de
#  referência do dono, é "nada abaixo de 300 Hz" — e é justamente isso que uma
#  reimportação descuidada (compressão com perdas, `force/max_rate`, `force/
#  8_bit`) estragaria em silêncio.
# ============================================================================

const PISO_HZ := 300.0
const TETO_GRAVE_PCT := 3.0     # folga sobre os 0,0% medidos na referência

var _falhas: Array[String] = []


func _init() -> void:
	print("cue          dur     Hz  formato   <300Hz   centroide")
	print("------------------------------------------------------")
	for cue in PikaAudio.CUES:
		_conferir(cue, String(PikaAudio.CUES[cue]))

	# O contrato do módulo, não só dos arquivos.
	for cue in PikaAudio.CUES:
		if not PikaAudio.VOLUME.has(cue):
			_falhas.append("cue '%s' sem volume declarado" % cue)

	print("")
	if _falhas.is_empty():
		print("✓ ÁUDIO DA PIKA: os %d cues carregam e mantêm o timbre" % PikaAudio.CUES.size())
		quit(0)
		return
	for f in _falhas:
		print("✗ ", f)
	print("XX  %d falha(s)" % _falhas.size())
	quit(1)


func _conferir(cue: String, caminho: String) -> void:
	var recurso = ResourceLoader.load(caminho)
	if recurso == null or not (recurso is AudioStreamWAV):
		_falhas.append("cue '%s' NÃO CARREGA (%s) — falta o .import? rode `godot --headless --path . --import`" % [cue, caminho])
		return
	var wav := recurso as AudioStreamWAV

	# ⚠️ FORMATO. Com compressão com perdas o `data` volta codificado e não dá
	# para medir espectro nenhum — e é exatamente o caso em que o timbre pode ter
	# sido estragado sem ninguém ver. Padrão do importador do Godot é QOA
	# (`compress/mode=2`); estes dez estão em `compress/mode=0` de propósito,
	# porque 5,7 s de áudio custam 550 KB e a nitidez aguda É o golpe.
	if wav.format != AudioStreamWAV.FORMAT_16_BITS:
		_falhas.append("cue '%s' não está em 16 bits PCM — compressão com perdas no .import?" % cue)
		return

	var amostras := _amostras(wav)
	if amostras.size() < 2048:
		_falhas.append("cue '%s' curto demais para medir (%d amostras)" % [cue, amostras.size()])
		return
	var medida := _espectro(amostras, wav.mix_rate)
	var grave: float = medida["grave"]
	var centroide: float = medida["centroide"]

	print("%-12s %5.2fs %6d  %-8s %6.2f%% %8.0f Hz" % [
		cue, float(amostras.size()) / wav.mix_rate, wav.mix_rate, "16bit PCM",
		grave, centroide])

	# A LEI Nº 1 da fruta, medida na referência: 0,0% abaixo de 300 Hz. A
	# `explosao` é a exceção DECLARADA — o grave dela é o chão recebendo o
	# mergulho, não a luz.
	if cue != "explosao" and grave > TETO_GRAVE_PCT:
		_falhas.append("cue '%s' tem %.1f%% de energia abaixo de %d Hz (teto %.1f%%) — luz não tem grave"
			% [cue, grave, int(PISO_HZ), TETO_GRAVE_PCT])
	if centroide < 1500.0:
		_falhas.append("cue '%s' com centroide em %.0f Hz — abaixo da faixa medida na referência (2,5-6,5 kHz)"
			% [cue, centroide])


func _amostras(wav: AudioStreamWAV) -> PackedFloat32Array:
	var dados := wav.data
	var passo := 2 * (2 if wav.stereo else 1)
	var fora := PackedFloat32Array()
	fora.resize(dados.size() / passo)
	for i in fora.size():
		fora[i] = float(dados.decode_s16(i * passo)) / 32768.0
	return fora


# DFT numa janela de 2048 no ponto de maior energia. Janela no PICO, não no
# começo: vários cues abrem com fade de 3 ms, e medir ali daria centroide de
# silêncio.
func _espectro(s: PackedFloat32Array, taxa: int) -> Dictionary:
	var n := 2048
	var inicio := 0
	var melhor := -1.0
	var passo := maxi(1, (s.size() - n) / 12)
	for off in range(0, maxi(1, s.size() - n), passo):
		var e := 0.0
		for i in range(off, off + n, 8):
			e += s[i] * s[i]
		if e > melhor:
			melhor = e
			inicio = off

	# Goertzel por banda: 64 raias log-espaçadas cobrem 100 Hz a 12 kHz com
	# muito menos conta que uma FFT completa escrita em GDScript.
	var total := 0.0
	var soma_f := 0.0
	var grave := 0.0
	for k in 64:
		var f: float = 100.0 * pow(120.0, float(k) / 63.0)
		if f >= float(taxa) * 0.5:
			break
		var w := TAU * f / float(taxa)
		var coef := 2.0 * cos(w)
		var s1 := 0.0
		var s2 := 0.0
		for i in n:
			var janela := 0.5 - 0.5 * cos(TAU * float(i) / float(n - 1))
			var atual := s[inicio + i] * janela + coef * s1 - s2
			s2 = s1
			s1 = atual
		var mag := s1 * s1 + s2 * s2 - coef * s1 * s2
		total += mag
		soma_f += mag * f
		if f < PISO_HZ:
			grave += mag
	if total <= 0.0:
		return {"grave": 0.0, "centroide": 0.0}
	return {"grave": 100.0 * grave / total, "centroide": soma_f / total}
