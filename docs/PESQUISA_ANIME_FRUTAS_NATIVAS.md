# Pesquisa — golpes do anime × frutas nativas do Modo História — 15/11/2026

**Autorização do dono (15/11/2026):** pesquisar na internet, em fontes confiáveis, as dúvidas sobre os golpes das frutas; documentar; armar plano; implementar.
**Fonte:** One Piece Wiki (Fandom), comunitária — serve de referência de GESTO e EFEITO, não de balanceamento. Mochi Mochi: ver `PESQUISA_ANIME_MOCHI_MOCHI.md`.

## Hie Hie no Mi (Kuzan/Aokiji) — <https://onepiece.fandom.com/wiki/Hie_Hie_no_Mi>
| anime | jogo | fidelidade |
|---|---|---|
| **Ice Block: Partisan** — várias lanças de gelo lançadas contra o inimigo | Z/nº 21: 4 lanças em leque, vida 40, congela ao ferir | ✅ fiel (lanças múltiplas) |
| **Ice Block: Pheasant Beak** — onda de gelo em forma de faisão num só golpe | nº 22: pássaro de gelo, vida 60 | ✅ fiel |
| **Ice Ball** — esfera gigante de gelo aprisiona o oponente à distância | nº 24: frente de gelo que avança; o alvo ferido fica preso num bloco de gelo (`gelo_hie.gd`) | ✅ fiel no efeito (bloco prende) |
| **Ice Age** — congela a área inteira e tudo nela | nº 25: campo que cresce (ver reforço visível, 6g) | ✅ fiel e agora visível |
| Ice Time / Ice Time Capsule (toque que congela; onda no chão) / Ice Saber | não existem no mod v14 | reserva |

## Moku Moku no Mi (Smoker) — <https://onepiece.fandom.com/wiki/Moku_Moku_no_Mi>
| anime | jogo | fidelidade |
|---|---|---|
| **White Blow** — rajada densa de fumaça / soco de longo alcance com o punho sólido | nº 21 White Fist | ✅ |
| **White Vine** — vira uma coluna ESPIRAL de fumaça que prende/captura alvo no ar | nº 23: sobe, funil de 10 anéis girando que ergue o alvo (funil novo, 6g) | ✅ agora lê como espiral |
| **White Launcher** — vira fumaça, avança e se solidifica prendendo o alvo com o **jitte** (Nanashaku) | nº 25: investida + soco forte | ✅ no gesto; o jitte não é desenhado (reserva) |
| **White Out** — fumaça das mãos envolve e DENSIFICA, prendendo vários | nº 30: campo de fumaça prende 20 ticks e explode | ✅ |

## Pika Pika no Mi (Borsalino/Kizaru) — <https://onepiece.fandom.com/wiki/Pika_Pika_no_Mi>
| anime | jogo | fidelidade |
|---|---|---|
| **Yata no Kagami** — luz entre as mãos refletida; vira luz e chega ao ponto | nº 24: carga, teleporte de luz até o alvo + chute (risco de luz novo) | ✅ |
| **Laser** dos dedos e do **solado**; chutes na velocidade da luz | nº 21 Laser, 22 Amano-Iwato (laser do pé), 27 Acceleration (chute mergulhando) | ✅ |
| **Amaterasu** (nome de jogo) — dois dedos, flash que CEGA e perfura | sem equivalente de "cegar" | ⏳ plano: flash branco curto no ponto de impacto do Laser (reserva) |
| **Ama no Murakumo** — espada de luz | nº 30: item da fruta | ✅ |
| **Yasakani no Magatama** — só o nome (tesouro sagrado) consta; efeito não descrito na fonte | nº 29: rajada de joias de luz | ❔ sem referência confiável do efeito |

## Nikyu Nikyu no Mi (Kuma) — <https://onepiece.fandom.com/wiki/Nikyu_Nikyu_no_Mi>
| anime | jogo | fidelidade |
|---|---|---|
| **Pad Ho** — repele o ar e dispara onda de choque; **Tsuppari Pad Ho** começa com pisada e dispara rajada de palmas | nº 21 / com Shift: rajada de patas | ✅ |
| **Ursus Shock** — bolha de ar em forma de pata entre os braços, comprimida e arremessada como bomba; carregar leva tempo e deixa vulnerável | nº 22: pata gigante, segurar prende a carga, 600 de energia | ✅ (a bolha na obra é vermelha/rosada; a pata do jogo é branca luminosa) |
| **Kuma Punch / Assault** | NÃO existem na obra (a fonte só lista "Kuma no Te", golpe de jogo) | nomes do mod: marcados como não-canônicos |

## Ope Ope no Mi (Law) — <https://onepiece.fandom.com/wiki/Ope_Ope_no_Mi>
Golpes da obra: **ROOM** (esfera base de tudo), **Shambles** (troca posições dentro da ROOM), **Takt** (telecinese), **Sterben**, **Radio Knife**, **Injection Shot** (estocada que "dispara"), **Gamma Knife** (lâmina curta que destrói órgãos), **Counter Shock** (choque elétrico; as fontes divergem), **Scan**.
O kit nativo do Mine Piece traz só o nº 23 (Stone Throwing) — a obra tem muito mais; o kit do Builder/arena da Ope (`ope_ope.md`) cobre ROOM/Shambles. **Lacuna grande:** levar ROOM + Shambles/Takt/Injection Shot ao kit da história é trabalho de uma tarefa própria (precisa de decisão do dono: o mod v14 não traz essas técnicas).

## Plano de implementação (estado)
1. ✅ Mochi: rosquinhas, braços, Kaku/Yaki/Zan Giri/Muso (ver pesquisa da Mochi).
2. ✅ Hie e Moku: nada a corrigir na mecânica; o visível já foi reforçado.
3. 🟡 Pika: flash do Amaterasu no impacto do Laser IMPLEMENTADO (`pika.gd`, `ScreenFX.flash`, força 0–0,85 pela distância; só visual, sem cegueira mecânica). Verificação por A/B (mesma captura com e sem o flash): o flash soma só +4,9 de brilho médio (0–255) num quadro (0,17 s) e +1,6 em outro; o restante do brilho é do laser. Efeito real e SUTIL (conforto visual); intensidade isolada.
4. ⏳ Moku: desenhar o jitte no fim do White Launcher (reserva).
5. ⏳ Ope: decidir com o dono a entrada de ROOM/Shambles/Takt/Injection Shot no kit da história.
