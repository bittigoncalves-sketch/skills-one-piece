# Buggy — partitura calma para violino

Proposta autoral em `PARTITURA_VIOLINO.json`; substitui como direção musical para estas duas cenas o briefing anterior de 120 BPM. Não contém áudio nem confirma resultado tímbrico. Sem voz ou melodia citada.

## Leitura dos dados

- 64 BPM, 4/4: uma batida = 0,9375 s; um compasso = 3,75 s. `t` é o início e `d` a duração em batidas, a partir do começo da peça; `midi` é a altura (69 = Lá4); `vel` controla a dinâmica normalizada 0–1.
- `chegada` ocupa uma grade de 32 batidas / oito compassos / 30 s, em duas frases de quatro compassos. `copos_loop` ocupa 16 batidas / quatro compassos / 15 s. Silêncios depois das frases são intencionais; os eventos não precisam preencher a grade inteira.
- `vibrato.hz` é a frequência de modulação, `atraso_s` o atraso após o ataque e `profundidade_cents` a excursão máxima aproximada. Na síntese, entrar com rampa suave depois do atraso; em notas curtas não forçar o vibrato. Todas as durações aqui já incluem pequena sobreposição de arco onde a próxima nota inicia antes da anterior terminar.
- Lá menor natural: A B C D E F G. As frases caminham por graus conjuntos com respirações; há apoio em A e C, aproximação B–A na cadência. O loop começa e termina em A, respirando antes da retomada. O pad é opcional, bem abaixo do solo: Am (compassos 1–2), C (3), Am (4), evitando ataques marcados.

## Síntese e emenda

Violino solo suave em registro médio, ataque de arco progressivo (aprox. 80–150 ms), transição macia entre alturas, dinâmica moderada e release natural. Espectro por harmônicos com envelope dependente da frequência e zonas de ressonância amplas (formantes) para sugerir caixa e arco; evitar seno puro, excesso de agudos e ruído áspero. Vibrato de 5,5 Hz tardio e discreto; evitar oscilação audível no ataque. Reverberação curta e baixa, com espaço para a fala. Pad sem percussão nem ataque invasivo.

O arquivo do loop deve ter exatamente 15 s, sem silêncio acrescentado ao final. Renderizar pelo menos duas repetições consecutivas, com envelopes e reverberação contínuos, e extrair uma repetição em regime estável; verificar amostras e ouvir a junção. Caso reste descontinuidade, aplicar crossfade circular curto sem mudar a duração. Não reiniciar fases/caudas abruptamente na fronteira. Não há garantia de emenda nem de qualidade do violino até sintetizar e escutar o áudio real.
