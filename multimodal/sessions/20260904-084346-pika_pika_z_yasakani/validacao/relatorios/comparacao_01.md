# Comparação referência × implementação — iteração 1

- **referência:** `VIdeo para Skill Z.mp4` (5.042s @ 24.0fps, 1920x1080)
- **implementação:** `pika_pika_Z.mp4` (3.2s @ 30.0fps, 1280x720)
- **modo:** estrutural
- **lado a lado:** `/home/gabriel-bitti/dev/skills-one-piece/multimodal/sessions/20260904-084346-pika_pika_z_yasakani/validacao/comparacoes/lado_a_lado_01.png`

## Números

| medida | referência | implementação | delta | método |
|---|---|---|---|---|
| duração | 5.042s | 3.2s | -1.842s | OBSERVED |
| pico de movimento | 1.9s | 0.5s | -1.400s | OBSERVED |
| energia média | 0.00421 | 0.0015 | ×0.356 | OBSERVED |
| forma do movimento | — | — | erro 0.1899 · correlação -0.238 | OBSERVED |

## Fases

| fase | referência | implementação | delta | método |
|---|---|---|---|---|
| start | 0.0s | 0.0s | +0.000s | OBSERVED |
| anticipation | 1.833s | 0.433s | -1.400s | ESTIMATED |
| release | 1.9s | 0.5s | -1.400s | ESTIMATED |
| recovery | 3.3s | 2.767s | -0.533s | ESTIMATED |
| end | 5.0s | 3.167s | -1.833s | OBSERVED |

## Recomendações

> Heurística, marcada `ESTIMATED` de propósito: o número acima é medida, a recomendação é leitura do número.

- **duração curta em 1.84s** → ajustar a duração total do golpe em +1.84s  `ESTIMATED`
- **o pico de movimento acontece -1.40s fora do lugar** → alongar o windup — o golpe sai cedo demais  `ESTIMATED`
- **perfil de aceleração diferente (correlação -0.238)** → revisar as curvas de easing entre as fases; não é questão de duração, é de ritmo  `ESTIMATED`
- **a implementação mexe menos pixel que a referência (razão 0.356)** → conferir amplitude do movimento e escala do VFX; pode ser câmera diferente, então confirme no lado a lado antes de mexer  `ESTIMATED`
- **fase 'anticipation' desloca -1.40s** → ajustar o início de 'anticipation'  `ESTIMATED`
- **fase 'release' desloca -1.40s** → ajustar o início de 'release'  `ESTIMATED`
- **fase 'recovery' desloca -0.53s** → ajustar o início de 'recovery'  `ESTIMATED`
- **fase 'end' desloca -1.83s** → ajustar o início de 'end'  `ESTIMATED`

## O que este relatório NÃO diz

- Nada sobre dano, hitbox, cooldown ou rede: isso não se lê em vídeo (§12 — aparência não é comportamento).
- Se as câmeras forem diferentes, `energia` e `SSIM` medem cenário, não fidelidade — decida pelo lado a lado e pelas fases.
