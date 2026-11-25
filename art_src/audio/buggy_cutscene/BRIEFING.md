# Buggy chega à vila — briefing instrumental

21/11/2026. Guia original para síntese pelo Claude: nenhuma voz, amostra de fala, gravação ou melodia existente. A direção evoca aventura marítima e humor teatral de pirata; as notas abaixo são proposta autoral, sem garantia de exclusividade ou de semelhança zero por comparação automatizada. Os tempos são grade musical, não medição de uma faixa renderizada.

## Cena: “A bandeira no horizonte”

- **Centro tonal:** ré menor (D minor), com cor maior passageira em F e C. Andamento fixo **120 BPM**, compasso **4/4**, 1 batida de semínima = 0,5 s, 1 compasso = 2 s. Total **14 compassos, 28 s**; aceitar ajuste ao corte real de câmera sem fazer a legenda desaparecer antes da leitura.
- **Caráter:** aventura marítima com pompa circense, primeiro distante e amplo, depois presença confiante do capitão. Não soar sombrio demais nem usar citação identificável de trilhas existentes.
- **Timbres:** cordas sustentadas e pizzicato; metais heroicos (trompa/trompete); bumbo e caixa de marcha em dinâmica moderada; flauta/pífaro; acordeão ou violão com levada de shanty. Panorâmica discreta, sem transformar a música em ruído de fundo indistinto.
- **Mapa para a cena ~25–30 s:**

| Tempo | Compassos | Imagem/entrada | Acordes (1 por compasso) | Dinâmica |
| --- | --- | --- | --- | --- |
| 0–6 s | 1–3 | Mar e navio aproximando: acordeão leve, cordas longas, pífaro sugere o motivo; bumbo muito espaçado. | Dm – Bb – F | p → mp; espaço para ambiente. |
| 6–12 s | 4–6 | Atracação: pizzicato e caixa de marcha acrescentam pulso; trompa entra em resposta curta. | C – Dm – A | mp, tensão sem batalha. |
| 12–20 s | 7–10 | Desembarque: metais apresentam o motivo; cordas em movimento, violão ou acordeão no contratempo e tambores mais marcados. | Dm – Bb – F – C | mf → f, acompanhando passos sem encobrir ações. |
| 20–28 s | 11–14 | Close de Buggy: motivo em registro mais alto, brevíssima pausa teatral e cadência. A legenda precisa continuar inteligível. | Bb – C – A – Dm | f no início, recuar para mp sob a fala; fechar com resolução. |

**Motivo A, dois compassos, notas e duração exatas:** cada item entre colchetes é uma colcheia (0,25 s); em cada compasso há oito colcheias. Usar alturas científicas (C4 = dó central).

- Compasso 1 sobre Dm: `[D4 F4 A4 A4] [C5 A4 F4 D4]`.
- Compasso 2 sobre Bb: `[F4 G4 A4 Bb4] [A4 F4 D4 D4]`.

Pífaro apresenta o motivo em 1–2 com pouca força; metais o reapresentam em 7–8; na chegada ao close, repetir o primeiro compasso uma oitava acima **ou** usar apenas o início para deixar espaço à fala. As repetições são proposta de arranjo e não alteram o total de compassos. Contrabaixo acompanha a fundamental dos acordes; não dobrar todas as vozes na mesma oitava. Decaimento curto antes da fala; sem áudio de fala sintetizado.

**Sting de gargalhada teatral, instrumental, separado:** 2 compassos / **4 s** a 120 BPM em 4/4, Dm → A → Dm (meio compasso A e meio Dm no segundo compasso). Trompete abafado ou clarinete faz notas curtas com pausas: compasso 1 `[A4 A4 pausa A4] [C5 pausa A4 pausa]` em colcheias; compasso 2 `[G4 G4 pausa F4] [E4 pausa D4 pausa]`. Pequeno glissando de trombone e caixa suave podem pontuar; é um gesto musical de riso, **sem imitar nem usar voz**. Permitir reproduzir separadamente, com um limitador e ganho regulável, sem cortar a legenda.

## Jogo dos copos: “Olho na pedra”

- **12 s** / 6 compassos em 4/4 a **120 BPM**; ré menor. Tensão leve e brincalhona, sem prometer resultado. Copos acontecem na **mesa da praia**.
- Harmonia: Dm – C – Bb – A – Dm – A. Baixo discreto em semínimas 1 e 3; pizzicato de cordas marca as colcheias em contratempo; caixa ou tambor toca batidas leves no 2 e 4; flauta responde em duas notas curtas a cada dois compassos.
- Célula melódica sugerida em colcheias: `[D5 pausa F5 pausa] [E5 pausa D5 pausa]`. Repetir com variação de registro, deixando as pausas audíveis. Não sincronizar uma nota distinta com o copo vencedor.
- A última cadência A pode retornar ao primeiro Dm se for usado loop; exportar fim com pequeno release e conferir ponto de emenda sem clique. Para sequência de duração variável, música pode permanecer em loop até a escolha; não reiniciar a lógica do jogo ao repetir áudio.

## Implementação e validação

Sintetizar em recursos separados da lógica: trilha da chegada, sting e loop dos copos, todos sem voz. Sincronizar por eventos dos planos quando os tempos reais divergirem, sem atrasar leitura; pausar/parar e restaurar volumes ao pular ou trocar de cena. Conferir duração, ritmo, ausência de voz, recorte/clip, volume sob diálogos, transições e playback no jogo. Nenhum áudio foi produzido ou escutado nesta entrega: apreciação musical e comparação ao vídeo final continuam pendentes.
