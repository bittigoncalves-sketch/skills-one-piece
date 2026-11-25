# Pesquisa — Mochi Mochi no Mi (Katakuri) → skills do jogo — 15/11/2026

**Autorização do dono (15/11/2026):** pesquisar na internet, em fontes confiáveis, os golpes das frutas do anime; documentar; armar plano; implementar.
**Fonte consultada:** One Piece Wiki (Fandom) — <https://onepiece.fandom.com/wiki/Mochi_Mochi_no_Mi> (e `Charlotte_Katakuri`). É wiki mantida por fãs: serve de referência de GESTO e EFEITO, não de dado oficial de balanceamento.

## O que a fonte diz de cada golpe (resumo, em português)
| golpe (JP / tradução) | gesto | efeito |
|---|---|---|
| **Yanagi Mochi** (Willow Mochi) | tentáculos longos de mochi brotam da perna e pisoteiam | golpe repetido de área |
| **Mochi Tsuki** (Mochi Thrust) | gira o braço de mochi, solta numa estocada em broca com o tridente Mogura | estocada perfurante |
| **Kaku Mochi** (Square Mochi) | comprime braços e mãos em formato QUADRADO, endurece com Haki do Armamento | soco quadrado |
| **Yaki Mochi** (Grilled Mochi) | o antebraço INFLA até estourar | lança o punho com Haki à distância |
| **Zan Giri Mochi** (Sliced Mochi) | o corpo inteiro vira uma ROSQUINHA que gira em alta velocidade; o chão também vira mochi | golpe mais forte: antebraço endurecido e espinhoso |
| **Muso Donuts** (Peerless Donuts) | tentáculos do chão se ENROLAM em rosquinhas | invoca rosquinhas |
| **Chikara Mochi / Mochi Ginchaku** | as rosquinhas são moldadas em BRAÇOS endurecidos | várias rosquinhas socam o alvo; Ginchaku é a versão forte |

## Cruzamento com o jogo (técnicas do mod no Modo História)
| tecla | jogo | equivale a | o que já tinha | lacuna visual | decisão |
|---|---|---|---|---|---|
| Z | Edged Mochi (nº 21, procedure `GomuGomunoPistol`) | Mochi Tsuki (soco/estocada de braço esticado) | entidade `ENTITY_GOMU_ARM` | braço do mod pouco legível | braço esticado cremoso (feito em 6m) |
| X | Punch Mochi (nº 22, `GomuGomuGatling`) | Kaku Mochi / Ginchaku (socos de mochi) | rajada de braços + rosquinhas espelham | soco redondo | **punho QUADRADO** (Kaku Mochi) — implementado |
| C | "Elephant Gun" (nº 23) | soco grande | braço grande | — | braço esticado mais grosso (feito) |
| V | Burning Mochi (nº 24, `YakiMochi`) | **Yaki Mochi** | entidade `FIST` lançada | o antebraço NÃO infla antes de estourar | **antebraço que infla e estoura** — implementado |
| B | Buzz Cut Mochi (nº 25) | **Zan Giri Mochi** | investida/corte | o corpo NÃO vira rosquinha giratória | **rosquinha giratória em volta do corpo** — implementado |
| N | Unstoppable Donuts (nº 29, `SkillMusoDonatsu`) | **Muso Donuts** (+ Chikara Mochi) | 2 rosquinhas atrás, espelham técnicas | as rosquinhas "apareciam" do nada | **tentáculos do chão que formam a rosquinha** — implementado |

## Plano (e estado)
1. ✅ Rosquinhas em creme e braços esticando da mão e de cada rosquinha (6m).
2. ✅ Kaku Mochi: o punho do Punch Mochi é um CUBO (mochi comprimido em quadrado), o do Elephant Gun segue esfera grande.
3. ✅ Yaki Mochi: esfera de mochi que infla no antebraço por 0,35 s e estoura (anel + clarão) no tick do lançamento.
4. ✅ Zan Giri Mochi: rosquinha (toro) giratória em volta do corpo durante a investida, ~1 s.
5. ✅ Muso Donuts: 3 tentáculos de mochi sobem do chão e se recolhem quando a rosquinha nasce.
6. ⏳ Yanagi Mochi e Mochi Tsuki NÃO existem como técnica separada no mod v14 (não há procedure): ficam como reserva (gatilho: se o dono pedir uma 7ª tecla).
7. ⏳ Chikara Mochi propriamente dito (rosquinhas ao redor do ALVO socando): hoje as rosquinhas ficam atrás do usuário e atacam pelo espelhamento do mod (fiel ao mod); mover para o alvo seria desvio da fidelidade — decisão do dono.

## Verificação em prints (15/11/2026, `captura_sequencia_fruta.gd`)
- ✅ Yaki Mochi (V): a bola de mochi infla no antebraço e estoura (print).
- ✅ Kaku Mochi (X): o braço termina num punho CÚBICO (print lateral).
- ✅ Zan Giri Mochi (B): rosquinha de mochi em volta do jogador que sobe (print de perto).
- ✅ Muso Donuts (N): as rosquinhas ficam atrás, uma de cada lado, e os tentáculos de mochi (colunas cremes em arco) sobem na base delas nos primeiros 0,2 s e recolhem (print da câmera larga por trás, `captura_sequencia_fruta.gd`, tempos 0,03–0,5 s). Com a câmera próxima ficavam fora do quadro.

- Suíte: `test_mochi_bracos` 7/0 após os novos efeitos (Kaku/Yaki/Zan Giri/Muso); `test_pika_mine_piece` 36/0, `test_moku_mine_piece` 27/0, `test_controlador_fruta_do_mod` 31/31.
