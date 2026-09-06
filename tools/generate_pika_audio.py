"""Assets sonoros da PIKA PIKA NO MI. Só biblioteca padrão, sem amostras.

    python3 tools/generate_pika_audio.py

Mono espacial, 48 kHz / 16 bit, pico -3,1 dBFS, fades curtos contra clique.
Determinístico: mesma semente, mesmo arquivo, byte a byte.

============================================================================
 DE ONDE VEIO O TIMBRE — medido, não inventado
============================================================================
Fonte: `~/Downloads/skill X pika pika.mp4` (a referência que o dono guardou) e
`VIdeo para Skill Z.mp4`. Análise por FFT de 4096 em janelas de 0,2 s.

O vídeo do X é o que manda, e ele diz três coisas, todas medidas:

  1. NÃO EXISTE GRAVE. Energia abaixo de 300 Hz: **0,0%** do início ao fim.
     É a assinatura da fruta. É por isso que `AudioFX.gunshot` — que escorrega
     de 450 Hz para 50 Hz com corpo grave — está errado para a Pika: aquilo é
     pólvora, e luz não tem peso.

  2. A BANDA VARRE. O centroide espectral anda ao longo da técnica:

        0,4-1,4 s   carga     2-5 kHz   (86% da energia)   centroide ~3,6 kHz
        1,6-4,2 s   viagem    5-10 kHz  (75% da energia)   centroide ~6,4 kHz
        4,4-4,8 s   cauda     2-5 kHz   (89% da energia)   centroide ~2,8 kHz

  3. É RUÍDO FILTRADO, NÃO TOM. Fator de crista entre 12 e 27, e os "picos"
     são aglomerados largos (4248/4359/4154 Hz juntos), não parciais de uma
     fundamental. Senoide pura leria como sintetizador, não como luz.

Então todo cue aqui é a mesma receita: RUÍDO BRANCO passado por um passa-banda
ressonante cuja frequência central VARRE no tempo, e depois por um passa-alta
de 300 Hz que garante a lei nº 1. O que muda de um cue para o outro é para onde
a banda anda e qual é o envelope.

Exceção declarada: `explosao` guarda um corpo curto em ~170 Hz. Não é a luz —
é o CHÃO recebendo o mergulho do X. Sem isso a explosão não tem chão nenhum.
============================================================================
"""
from array import array
from pathlib import Path
import math
import random
import sys
import wave

RATE = 48000
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"

# A lei nº 1, em Hz. Tudo abaixo disso é cortado duas vezes (12 dB/oitava).
PISO_HZ = 300.0


def svf(entrada, corte, q, estagios=2):
    """Passa-banda ressonante (Chamberlin) com corte VARIÁVEL por amostra.

    `corte` é uma lista do mesmo tamanho da entrada: é ela que faz a banda
    varrer. Devolve a saída de banda — o "ruído com altura" que a referência
    mostra. `q` alto = banda estreita = mais cristalino.

    ⚠️ `estagios=2` NÃO É ENFEITE, é correção medida. Com um estágio só, a
    saída de banda do Chamberlin vaza muito acima do corte: o cue `barragem`,
    varrido entre 4 e 7 kHz, saiu com centroide medido de **10,2 kHz** e o
    `ceu`, mirando 5 kHz, terminou em 7,2 kHz. Dois estágios em série elevam a
    resposta ao quadrado e o centroide passa a cair onde a referência manda.
    Custo: 0,2 s a mais no script inteiro, uma vez, fora do jogo.
    """
    for _ in range(estagios):
        baixo = banda = 0.0
        saida = []
        inv_q = 1.0 / q
        for x, fc in zip(entrada, corte):
            # Estável enquanto fc < RATE/6; os cues param em 9 kHz.
            f = 2.0 * math.sin(math.pi * min(fc, RATE / 6.0) / RATE)
            alto = x - baixo - inv_q * banda
            banda += f * alto
            baixo += f * banda
            saida.append(banda)
        entrada = saida
    return entrada


def passa_alta(sinal, corte=PISO_HZ, ordens=2):
    """Um polo por ordem. Existe para impor os 0,0% abaixo de 300 Hz."""
    a = 1.0 - math.exp(-TAU * corte / RATE)
    for _ in range(ordens):
        baixo = 0.0
        fora = []
        for x in sinal:
            baixo += (x - baixo) * a
            fora.append(x - baixo)
        sinal = fora
    return sinal


def varredura(dur, de_hz, para_hz, curva=1.0):
    """Trajetória da banda no tempo. `curva` > 1 demora a sair do início."""
    n = int(RATE * dur)
    return [de_hz + (para_hz - de_hz) * ((i / n) ** curva) for i in range(n)]


def ruido(rng, n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def glint(dur, hz, decaimento):
    """O 'tlim' cristalino: senoide alta e curta. Usada só em impactos, e
    sempre por cima do ruído — sozinha soaria a apito de sintetizador."""
    n = int(RATE * dur)
    return [math.sin(TAU * hz * (i / RATE)) * math.exp(-(i / RATE) * decaimento)
            for i in range(n)]


# ---------------------------------------------------------------- os cues
# (duração, semente, construtor). A duração de cada um não é gosto: é o tempo
# que o golgo correspondente ocupa no jogo. Som mais longo que o gesto empilha.
def _carga(rng, dur):
    """Z e C juntando luz na mão. Banda SOBE — anúncio, não conclusão."""
    n = int(RATE * dur)
    corte = varredura(dur, 1800.0, 4200.0, 0.7)
    seco = svf(ruido(rng, n), corte, 3.2)
    fora = []
    for i, v in enumerate(seco):
        u = i / n
        # Envelope crescente com um degrau no fim: o estouro é o quadro em que
        # a salva começa, e o ouvido usa ele para prever o disparo.
        env = u ** 1.8 + (0.55 * (u - 0.86) / 0.14 if u > 0.86 else 0.0)
        fora.append(v * env * 2.6)
    return fora


def _disparo(rng, dur):
    """Cada raio do Z. Ataque instantâneo, banda DESCE — conclusão."""
    n = int(RATE * dur)
    corte = varredura(dur, 7500.0, 2800.0, 0.45)
    seco = svf(ruido(rng, n), corte, 4.5)
    fora = []
    for i, v in enumerate(seco):
        t = i / RATE
        env = math.exp(-t * 26.0) + 0.35 * math.exp(-t * 9.0)
        fora.append(v * env * 3.2)
    return fora


def _fragmento(rng, dur):
    """Fragmento do C. Mais curto e mais agudo que o disparo: são dezenas por
    segundo, e a soma é que faz o volume da barragem."""
    n = int(RATE * dur)
    corte = varredura(dur, 8600.0, 4600.0, 0.4)
    seco = svf(ruido(rng, n), corte, 5.5)
    return [v * math.exp(-(i / RATE) * 46.0) * 3.0 for i, v in enumerate(seco)]


def _impacto(rng, dur):
    """Onde o raio morre. Estalo 5-9 kHz mais o glint cristalino por cima."""
    n = int(RATE * dur)
    corte = varredura(dur, 9000.0, 3400.0, 0.3)
    seco = svf(ruido(rng, n), corte, 3.8)
    brilho = glint(dur, 5200.0, 34.0)
    brilho2 = glint(dur, 7900.0, 52.0)
    fora = []
    for i, v in enumerate(seco):
        t = i / RATE
        env = math.exp(-t * 19.0)
        fora.append(v * env * 3.0 + brilho[i] * 0.30 + brilho2[i] * 0.18)
    return fora


def _viagem(rng, dur):
    """X: o corpo VIRA luz e viaja. É o trecho de 1,6-4,2 s da referência —
    banda subindo para ~6,4 kHz e ficando lá. Sustentado, não percussivo."""
    n = int(RATE * dur)
    corte = varredura(dur, 3000.0, 6400.0, 0.55)
    seco = svf(ruido(rng, n), corte, 6.0)
    fora = []
    for i, v in enumerate(seco):
        u = i / n
        # Tremulação de 41 Hz: a luz da referência não é um chiado parado, ela
        # cintila. Frequência escolhida acima do batimento audível e abaixo do
        # que viraria altura própria.
        cintila = 1.0 + 0.22 * math.sin(TAU * 41.0 * (i / RATE))
        env = min(1.0, u / 0.10) * (1.0 - max(0.0, (u - 0.72) / 0.28) ** 1.6)
        fora.append(v * env * cintila * 2.9)
    return fora


def _explosao(rng, dur):
    """Mergulho do X batendo no chão. ÚNICO cue com corpo grave, e declarado:
    o grave aqui é o CHÃO, não a luz. Morre em ~120 ms para não virar canhão."""
    n = int(RATE * dur)
    corte = varredura(dur, 8200.0, 2200.0, 0.35)
    seco = svf(ruido(rng, n), corte, 2.6)
    fora = []
    fase = 0.0
    for i, v in enumerate(seco):
        t = i / RATE
        fase += TAU * (170.0 - 95.0 * min(t * 8.0, 1.0)) / RATE
        chao = math.sin(fase) * math.exp(-t * 21.0) * 0.42
        env = math.exp(-t * 7.5)
        fora.append(v * env * 2.8 + chao)
    return fora, False  # False = não aplicar o passa-alta (o chão é legítimo)


def _teleporte(rng, dur):
    """C: os 7 m para cima num quadro. Zip que SOBE e some — o oposto do
    disparo. Se descesse leria como algo caindo."""
    n = int(RATE * dur)
    corte = varredura(dur, 2000.0, 8600.0, 1.5)
    seco = svf(ruido(rng, n), corte, 5.0)
    fora = []
    for i, v in enumerate(seco):
        u = i / n
        env = min(1.0, u / 0.06) * (1.0 - u) ** 1.4
        fora.append(v * env * 3.1)
    return fora


def _barragem(rng, dur):
    """Leito sustentado da barragem do C, por baixo dos fragmentos. Toca UMA
    vez por conjuração: são 60 fragmentos por segundo, e sem uma cama contínua
    eles soariam a pipoca em vez de rajada."""
    n = int(RATE * dur)
    # 2,6-4,8 kHz de corte, que MEDIDO devolve centroide ~6,4 kHz — a mesma
    # banda do trecho sustentado da referência (1,6-4,2 s). O corte não é o
    # centroide: mirar 6,4 no corte devolveria quase 9 kHz na saída.
    corte = [2600.0 + 2200.0 * (0.5 + 0.5 * math.sin(TAU * 2.3 * (i / RATE)))
             for i in range(n)]
    seco = svf(ruido(rng, n), corte, 3.0)
    fora = []
    for i, v in enumerate(seco):
        u = i / n
        env = min(1.0, u / 0.08) * (1.0 - max(0.0, (u - 0.78) / 0.22) ** 1.3)
        fora.append(v * env * 2.4)
    return fora


def _ceu(rng, dur):
    """V: o céu virando dourado. Dois segundos de subida, que é exatamente a
    janela de ativação (V_ATIVACAO_FIM=1,0 até V_CHUVA_INICIO=2,0 mais folga).
    Longo e crescente porque o que ele anuncia dura 12 s."""
    n = int(RATE * dur)
    corte = varredura(dur, 1500.0, 5000.0, 1.25)
    seco = svf(ruido(rng, n), corte, 2.8)
    fora = []
    for i, v in enumerate(seco):
        u = i / n
        env = (u ** 1.5) * min(1.0, (1.0 - u) / 0.06 + 0.15)
        fora.append(v * env * 2.7)
    return fora


def _chuva(rng, dur):
    """Cada descarga da Chuva de Luz. Pingo brilhante que cai: banda desce
    rápido e o glint fica. Toca esparso — o campo visual é mais denso que a
    cadência sonora, de propósito."""
    n = int(RATE * dur)
    corte = varredura(dur, 7800.0, 2600.0, 0.5)
    seco = svf(ruido(rng, n), corte, 4.2)
    brilho = glint(dur, 6100.0, 26.0)
    fora = []
    for i, v in enumerate(seco):
        t = i / RATE
        fora.append(v * math.exp(-t * 15.0) * 2.9 + brilho[i] * 0.22)
    return fora


CUES = {
    "carga":      (0.42, 1101, _carga),
    "disparo":    (0.15, 1102, _disparo),
    "fragmento":  (0.085, 1103, _fragmento),
    "impacto":    (0.20, 1104, _impacto),
    "viagem":     (0.55, 1105, _viagem),
    "explosao":   (0.65, 1106, _explosao),
    "teleporte":  (0.30, 1107, _teleporte),
    "barragem":   (1.10, 1108, _barragem),
    "ceu":        (2.00, 1109, _ceu),
    "chuva":      (0.28, 1110, _chuva),
}


def montar(nome):
    dur, semente, construtor = CUES[nome]
    rng = random.Random(semente)
    resultado = construtor(rng, dur)
    if isinstance(resultado, tuple):
        amostras, cortar_grave = resultado
    else:
        amostras, cortar_grave = resultado, True
    if cortar_grave:
        amostras = passa_alta(amostras)

    # Fades: 3 ms na entrada, 12% da duração na saída (limitado a 30 ms). Sem
    # isso o corte no zero vira clique, e clique lê como bug, não como golpe.
    n = len(amostras)
    entrada = int(RATE * 0.003)
    saida = min(int(RATE * 0.030), int(n * 0.12))
    for i in range(n):
        g = 1.0
        if i < entrada:
            g *= i / entrada
        if i > n - saida:
            g *= (n - i) / saida
        amostras[i] *= g

    # Duas reflexões difusas: dão lugar ao som sem depender de um bus de reverb
    # no projeto. Mesmo truque do `generate_ope_audio.py`, tempos mais curtos
    # porque a Pika é aguda e cauda longa em 6 kHz vira assobio.
    original = list(amostras)
    for atraso, ganho in ((0.021, 0.13), (0.043, 0.07)):
        desloc = int(RATE * atraso)
        for i in range(desloc, n):
            amostras[i] += original[i - desloc] * ganho * min(1.0, (n - i) / (RATE * 0.02))

    pico = max(abs(x) for x in amostras) or 1.0
    pcm = array("h", (int(max(-1.0, min(1.0, x / pico)) * 22937) for x in amostras))
    if sys.byteorder != "little":
        pcm.byteswap()
    destino = OUT / ("pika_%s.wav" % nome)
    with wave.open(str(destino), "wb") as saida_wav:
        saida_wav.setnchannels(1)
        saida_wav.setsampwidth(2)
        saida_wav.setframerate(RATE)
        saida_wav.writeframes(pcm.tobytes())
    return destino, n


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for nome in CUES:
        destino, n = montar(nome)
        print("  %-22s %5.2f s  %7d bytes" % (destino.name, n / RATE, destino.stat().st_size))


if __name__ == "__main__":
    main()
