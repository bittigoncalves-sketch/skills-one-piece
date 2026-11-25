# Skills das frutas Mine Piece no Modo História — objetivo, funcionamento, execução e visual

Estado de **15/11/2026**. Cobre as 6 fontes de técnica nativas do Modo História: **Ope Ope, Hie Hie, Moku Moku, Pika Pika, Nikyu Nikyu**
e o **Estilo de Combate Base (Luta)**. Cada técnica abaixo tem descrição de objetivo, funcionamento e execução, os números lidos no
código e o que o jogador **vê**. As versões descritas aqui SUBSTITUEM as anteriores no jogo (a melhoria visual está no mesmo arquivo da
técnica; não há cópia paralela).

## Regras que valem para todas (lidas em `controlador.gd`, `catalogo.gd`, `Balance.gd`)
- **Ciclo R / teclas:** as frutas do mod usam o ciclo de técnicas; a ficha em `catalogo.gd` lista número, nome e `custo_mod` de cada uma.
- **Custo:** `custo_mod × ENERGIA_POR_CUSTO (1)` de energia, cobrado ao começar. Sem energia a técnica não inicia.
- **Recarga GLOBAL:** `max(custo_mod × 0,5; 5) × 0,05 s` — 50 → 1,25 s, 100 → 2,5 s, 200 → 5 s, 300 → 7,5 s, 500 → 12,5 s, 600 → 15 s. A recarga
  corre para todas as técnicas ao mesmo tempo (é por isso que o painel mostra o mesmo "faltam N s" nas quatro).
- **Carga:** segurar a tecla enche `cnt6` de 0 a 5; o multiplicador é `CNT6 = 1 + cnt6/10` (até ×1,5) sobre o dano da tabela.
- **Dano:** tabela em `Balance.MINE_PIECE_*`, em unidades do mod, escalada no jogo por `PerfilDeFrutas.ESCALA_DO_MOD`.
- **Tempo:** a lógica roda em *ticks* do mod de 0,05 s (`passo()` por tick), com contadores `cnt1…cnt10` com os nomes do Java.
- **Visual:** efeitos só desenham; o dano é de `ataque_em_area`/`DamageZone` no servidor. Os anéis de choque, feixes e rastros novos
  (`VfxFrutaMinePiece.onda_de_choque / feixe / rastro`) não ferem, não empurram e se apagam sozinhos.

---

## OPE OPE (Mine Piece) — 1 técnica

### 23 · Stone Throwing (custo 100 · recarga 2,5 s)
- **Objetivo:** ferramenta de controle e dano à distância: cercar o jogador de pedras e arremessá-las em rajada para onde ele olha.
- **Funcionamento:** nos 4 primeiros ticks nascem 4 entulhos (blocos de pedra/madeira) em volta, 45–90° para cada lado da frente, rente ao chão.
- **Carga:** segurar Z prende `cnt1` em 9 (as pedras ficam suspensas); soltar leva `cnt1` a 40 e começa o lançamento.
- **Lançamento:** em intervalos de 2 ticks cada entulho é empurrado pela direção do olhar; a pose do braço muda para `punch_right`.
- **Dano:** 15 por entulho (`MINE_PIECE_OPE.entulho`), só se o entulho tiver tamanho mínimo 0,8; o empurrão é 0,5.
- **Acerto:** o entulho fere **ao atravessar** o alvo e há invulnerabilidade compartilhada (`invulnerableTime`): uma rajada não quadruplica o dano.
- **Geometria (fiel ao Java):** as pedras nascem num cone de ±45° à frente e voam na direção do olhar; um alvo colado a 2–4 m é ultrapassado.
- **Limite do mod:** esta fruta só tem essa técnica; as outras da Ope original (ROOM, etc.) não existem no v14.
- **Cancelamento:** `cancelar()` apaga os entulhos que ainda não foram lançados.
- **Visibilidade:** entulhos grandes e escuros, bem legíveis, com poeira no nascimento; confirmado em captura (4 quadros da carga ao lançamento).
- **Verificação:** `test_ope_mine_piece` 23/0 (carga não fere, entulho fere ao atravessar, dano compartilhado).

---

## HIE HIE (Mine Piece) — gelo, Logia · 4 técnicas

### 21 · Ice Block: Partisan (custo 100 · recarga 2,5 s)
- **Objetivo:** lançar uma lança de gelo que fere e CONGELA o alvo — a técnica básica de controle da Hie.
- **Funcionamento:** preparo de 8 ticks com Lentidão IV, mão à frente (`right_arm_front`); segurar entre os ticks 6 e 8 carrega `cnt6`.
- **Execução:** no soco (`punch_right`) a lança de gelo (`lanca_de_gelo_hie.gd`) nasce à frente e voa na mira; vida da lança 40.
- **Dano:** 15 × CNT6 (`partisan`); ao ferir, o alvo é congelado (`gelo_hie.gd`) com a carga do gelo (`cnt6 + 5`).
- **Com Shift:** a lança sai por TRÁS do jogador (`_partisan_atras`), para quem é perseguido.
- **Carga cheia:** em `cnt6 = 5` há clarão e um **anel de choque azul** no ponto da lança, avisando que está no máximo.
- **Visibilidade:** partículas de gelo (agora azul-frias e brilhantes), anel na carga cheia, lança translúcida em voo.
- **Limites:** o congelamento leve (Effect12) do mod antes do gelo não entra — o gelo já prende.
- **Verificação:** `test_hie_mine_piece` 46/0.
- **Como usar:** abre o combate: congela de longe, depois entre com o Pheasant Beak ou a Ice Ball; com a recarga global de 2,5 s dá para repetir logo.

### 22 · Ice Block: Pheasant Beak (custo 300 · recarga 7,5 s)
- **Objetivo:** um pássaro de gelo mais forte que a lança, para perfurar e congelar um alvo isolado.
- **Funcionamento:** mesma estrutura de preparo (8 ticks, carga entre 6 e 8) com pose `right_arm_front`.
- **Execução:** no tick do soco o "faisão" nasce 3 blocos abaixo da frente (`frente − 3`) e sobe/voa na mira, com escala 2 × CNT6.
- **Vida:** o pássaro tem 60 de vida (`vida_passaro`): inimigos podem quebrá-lo antes de chegar.
- **Dano:** 20 × CNT6 (`passaro`); congela ao ferir como a Partisan.
- **Carga:** `cnt6` gera `cnt6 × 5 + 1` partículas de gelo no nascimento, então a carga se vê.
- **Duração:** o golpe encerra 5 ticks após o soco (`cnt3 > 5`).
- **Visibilidade:** pássaro de gelo grande + estouro de partículas frias; sem clímax próprio além da carga cheia (anel).
- **Verificação:** coberto por `test_hie_mine_piece`.
- **Como usar:** contra alvo parado ou em corredor; o pássaro tem vida 60, então não vale contra quem tem arma de longo alcance sem cobertura.

### 24 · Ice Ball (custo 250 · recarga 6,25 s)
- **Objetivo:** uma frente de gelo que avança em linha reta e congela tudo que ela atravessa, ótima contra grupo alinhado.
- **Funcionamento:** preparo de 5 ticks (Lentidão V); segurar entre os ticks 3 e 5 carrega `cnt6`.
- **Execução:** no tick 5 grava a mira (`_rumo`) e a frente (`_frente`); a cada tick por 12 ticks avança 4 blocos, aplicando 4 ataques por tick.
- **Alcance:** cresce `0,05` por tick até 0,75; cada ataque tem lado `max(16 × alcance; 3)` blocos.
- **Dano:** 15 × CNT6 por ataque de cubo (`bola`), empurrão 0,01 (quase nulo: o objetivo é prender, não arremessar).
- **Marca no chão:** uma placa de gelo no ponto de cada passo (decal translúcido) e partículas entre a mão e a frente.
- **Carga cheia:** clarão + anel de choque azul na frente do jogador.
- **Visibilidade:** faixa azul no chão + partículas; é a mais discreta da Hie (a frente é fina). Pendente de melhoria opcional.
- **Verificação:** `test_hie_mine_piece`.
- **Como usar:** em corredor ou contra grupo em fila; a frente congela tudo que atravessa mas empurra quase nada, então emende com um golpe de dano.

### 25 · Ice Age — o V da Hie (custo 600 · recarga 15 s)
- **Objetivo:** congelar uma ÁREA grande ao redor do jogador: é a ultimate de campo da Hie.
- **Funcionamento:** carga de até 10 ticks (Lentidão IX, pose `yamiyami_blackhole`); segurar prende em 9 e carrega `cnt6`; carga cheia dá clarão e anel.
- **Execução:** depois da carga, durante 8 ticks (0,4 s) a cada tick o raio do dano cresce `2 blocos` até 16 (× `ajuste` de CNT6).
- **Dano:** `(18 + cnt2 × 0,1) × CNT6` por tick em cubo crescente, empurrão 0,1 × CNT6, congelando quem for ferido (`cnt6 + 5`).
- **Problema encontrado (medido):** a expansão dura só 0,4 s e o único desenho era uma placa com alfa 0,42: a técnica funcionava e quase não se via.
- **Correção (15/11/2026):** `era_do_gelo_visivel.gd` desenha o raio REAL do dano: disco de geada com rachaduras que cresce junto, 110 cristais de gelo
  que brotam do chão onde a frente passa (mais altos na borda), anel de choque a cada passo, névoa fria subindo e luz ciano que estoura.
- **Duração do visual:** o gelo fica ~3,2 s depois que o dano termina e desbota em 1,1 s.
- **Prova:** captura antes (faixa azul fina) e depois (campo branco-azulado com cristais altos cobrindo a tela); `test_hie_mine_piece` 46/0.
- **Limites:** bolas de gelo extras da Ice Age exigem Força > 9, efeito que o jogo não tem; o visual assenta no chão sob o centro (raio no chão).
- **Como usar:** quando cercado: o campo congela quem está perto; a carga cheia (anel azul) dá `CNT6` ×1,5 no dano.

---

## MOKU MOKU (Mine Piece) — fumaça, Logia · 4 técnicas

### 21 · White Fist (custo 120 · recarga 3 s)
- **Objetivo:** soco de fumaça de curto alcance, o golpe-base de empurrão do Moku.
- **Funcionamento:** preparo curto e soco (`punch_gomu_pistol1`); segurar carrega `cnt6`.
- **Execução:** nasce um punho de fumaça (`punho_moku.gd`, `FistEntity` modo −1) que avança 6 blocos/tick, cubo de 3 × tamanho × 1,25.
- **Dano:** 18 × CNT6 (`punho`), empurrão 1,0 + metade da velocidade do punho; vida do punho 50.
- **Fim do punho:** some com `cnt1 > 15` ou `cnt2 > 20`, estourando em nuvem.
- **Fidelidade:** o punho nasce 2 larguras a +X do mundo à altura de 0,6 do corpo, qualquer que seja a mira (preservado do Java).
- **Visibilidade:** rastro de fumaça atrás do punho e estouro de nuvem + clarão no impacto; a fumaça agora é BRANCA (antes cinza-parda).
- **Verificação:** `test_moku_mine_piece` 27/0.
- **Relação:** a base do kit do Moku; a 25 reutiliza o mesmo soco forte depois da investida.
- **Objetivo cumprido:** acertou a 4 m e empurra; confirmado nas capturas.

### 23 · White Vine (custo 250 · recarga 6,25 s)
- **Objetivo:** o jogador vira fumaça, SOBE até o alto do alvo e invoca um TORNADO de fumaça que prende e arremessa para cima.
- **Funcionamento:** 20 ticks de invisibilidade enquanto é teleportado para o ponto acima do alvo (mira de 3 passos de 8 blocos, lado 16).
- **Execução:** no tick 10 nasce o tornado no chão sob esse ponto, que cresce 0,2 × CNT6 por tick até `6 + cnt6` de tamanho; some com `cnt2 > 80`.
- **Dano:** 11 × CNT6 por tick no corpo do tornado, com empurrão para cima `y = CNT6`; o tornado tem 50 de vida e pode ser quebrado.
- **Problema encontrado (medido):** o corpo sumia e nada mostrava a trepadeira ou o tornado — a malha do mod tem textura quase transparente.
- **Correção (15/11/2026):** (1) FUNIL procedural de 10 anéis girando em sentidos alternados, que cresce com o tornado; (2) RASTRO de
  nuvens do ponto de partida ao ponto de destino mais anéis de choque nas duas pontas, mostrando a "subida" do cipó.
- **Prova:** capturas mostram o funil branco crescendo, o alvo levantado e a trilha de fumaça; `test_moku_mine_piece` 27/0.
- **Fim:** invisibilidade acaba em `cnt10 > 20`; a técnica termina em `cnt10 > 25`.
- **Limite:** o tornado só fere quem está no cubo do corpo dele; fora, o funil é só desenho.
- **Como usar:** contra alvo que foge ou fica distante: a subida atravessa a distância e o tornado o ergue; quebre o tornado (vida 50) para escapar dele.

### 25 · White Launcher (custo 250 · recarga 6,25 s)
- **Objetivo:** investida de fumaça até o alvo seguida de um soco forte: um gap-closer ofensivo.
- **Funcionamento:** carga segurando (pose de preparo), depois o corpo "dispara" como fumaça e é teleportado bloco a bloco até o alvo (cubo 4 × alcance).
- **Execução:** a investida para no alvo (adaptação declarada: no mod o corpo passa 4,5 blocos além e o soco sai no vazio).
- **Golpe:** `AttackStrongPunch` no fim da investida, com `cnt6 + 2,5` de carga; pose `punch_right`.
- **Saída:** se solta no chão com `cnt2 ≥ 10` e sem segurar, levanta uma nuvem de poeira (`_fumaca` com 10 × alcance partículas).
- **Som:** `hit_strong` de combate do mod, volume 2 × alcance, no início e no impacto.
- **Visibilidade:** nuvens ao longo do trajeto e no impacto (fumaça branca agora); sem anel próprio.
- **Risco/retorno:** se não houver alvo no cubo, a investida corre a distância máxima e o soco sai no ar.
- **Verificação:** `test_moku_mine_piece`.
- **Objetivo cumprido:** fecha distância e acerta; medido na varredura (começou, gasto 200).

### 30 · White Out (custo 300 · recarga 7,5 s)
- **Objetivo:** a ultimate defensiva/ofensiva: cobrir uma ÁREA enorme de fumaça que PRENDE quem está dentro e depois explode.
- **Funcionamento:** `cnt1 5–25`: um anel de nuvens fecha sobre o corpo (raio até 30 blocos); segurar estende a fase (até `cnt5 < 4`).
- **Campo de fumaça (`cnt1 ≥ 10`):** quem está no cubo (lado até 48 blocos) fica preso 20 ticks (sem técnica, esquiva ou voo) e é erguido 0,1 do chão.
- **Execução:** em `cnt1 > 35` por 10 ticks o corpo faz `enkai`, solta 24 partículas por tick e fere (`white_out` 18 × CNT6, cubo 32 × CNT6).
- **Empurrão:** `empurrar_area` de 32 × CNT6 blocos, força 2.
- **Clímax:** no tick 36 estoura um clarão de 8 blocos e um **anel de choque branco** de 14 × CNT6 blocos (novo), com som forte.
- **Visibilidade:** nuvem branca cobrindo a tela e a anel varrendo o chão; é a skill mais legível do Moku.
- **Limite declarado:** o anel de até 1000 partículas por tick do mod vira um anel de fumaça por tick (custo).
- **Verificação:** `test_moku_mine_piece`.
- **Duração:** `cnt1 > 45` termina; recarga 7,5 s.

---

## PIKA PIKA (Mine Piece) — luz, Logia · 6 técnicas + passiva

### 21 · Laser (custo 150 · recarga 3,75 s)
- **Objetivo:** feixe de luz instantâneo e preciso de longa distância (a assinatura do Kizaru).
- **Funcionamento:** carga segurando (prende `cnt1` em 9); depois o feixe avança 20 blocos por tick em passos de 0,1.
- **Execução:** a cada 1,1 bloco um `RangeAttack` fere (17 × CNT6); termina ao bater em parede, achar alvo ou esgotar o tempo.
- **Explosão final:** `KizaruLaser1`: cubo de 12 × CNT6, dano 17 × CNT6, deixa uma onda de impacto amarela (modo 2) e marca queimada se bater em parede.
- **Visibilidade:** feixe amarelo-branco (`BeamVisual3D`), clarão e anel de choque amarelo no ponto de impacto.
- **Som:** `laser_beam` no início, `flame_explode` na explosão.
- **Carga:** `cnt6` aumenta a largura do feixe (`0,12 × CNT6`).
- **Risco/retorno:** exige mira; o raio não faz curva e para na primeira parede.
- **Verificação:** `test_pika_mine_piece` 36/0.
- **Objetivo cumprido:** acerta alvo a 14 m (varredura: começou, gasto 150).

### 22 · Amano-Iwato (custo 600 · recarga 15 s)
- **Objetivo:** o laser "do pé": um chute de luz de ÁREA maior que ergue uma coluna de luz grande — a ultimate de linha da Pika.
- **Funcionamento:** mesma lógica do Laser, com carga mais longa (prende `cnt1` em 19) e feixe saindo da altura do pé.
- **Dano:** `laser_pe` 24 × CNT6 no feixe e explosão de cubo 24 × CNT6 (o dobro do Laser).
- **Execução:** a explosão deixa uma `EntityImpactWave` modo 0 (`mp_onda_amarela.glb`) e marca no chão.
- **Visibilidade:** coluna de luz amarela do alto à vista e anel de choque grande; a mais vistosa da fruta.
- **Som:** laser de 2 × tamanho e explosão de 8 × tamanho.
- **Objetivo cumprido:** área grande fere vários alvos de uma vez.
- **Risco/retorno:** carga longa (19 ticks) deixa o jogador parado e Lentidão IX.
- **Fim:** `cnt1 ≥ 28` (do pé) encerra.
- **Verificação:** `test_pika_mine_piece`.
- **Relação:** variante do 21; compartilha `_passo_do_feixe`.

### 24 · Yasakani Sacred Jewel / Yata no Kagami (custo 200 · recarga 5 s)
- **Objetivo:** teleporte de luz até o alvo seguido de chute: um gap-closer com dano.
- **Funcionamento:** carga (`cnt2 ≥ 9` prende, `_carregar` de 0,125); em `cnt2 ≥ 11` varre 128 passos de 0,5 bloco na mira, do pé, até um alvo (cubo 3) ou parede.
- **Execução:** por 7 ticks desenha luz entre o jogador e o destino; no tick 8 teleporta, vira para o alvo mais perto (cubo 5) e chuta.
- **Dano:** `chute` 17 × CNT6 em cubo de 6 × tamanho, empurrão 2, três ticks de golpe.
- **Pose:** `both_arm_front` na carga; `kick_right/left` no chute.
- **Problema encontrado:** o teleporte era invisível (partículas esparsas).
- **Correção (15/11/2026):** RISCO amarelo da partida ao destino mais anéis de choque nas duas pontas.
- **Prova:** captura mostra a faixa de luz no momento do salto.
- **Fim:** `cnt3 ≥ 18` termina.
- **Verificação:** `test_pika_mine_piece`, `test_pika_yasakani`.

### 27 · Acceleration is Power!!! (custo 300 · recarga 7,5 s)
- **Objetivo:** subir como luz e MERGULHAR de cima num chute devastador; um golpe de impacto em área.
- **Funcionamento:** 20 ticks invisível e imobilizado subindo até um ponto alto (mira de topo, até 8 × tamanho blocos), sem sofrer dano de queda.
- **Execução:** do tick 20 em diante o corpo desce bloco a bloco, ferindo a cada bloco (`mergulho` 20, cubo 6) e no chão (`impacto_mergulho` 21, cubo 12).
- **Empurrão:** 1,5 nas duas fases (`empurrar_area`), com marca queimada no chão.
- **Problema encontrado:** o jogador sumia e nada mostrava a subida nem a descida.
- **Correção (15/11/2026):** coluna de luz da partida ao ponto alto e anel de choque na saída; no impacto, coluna do alto até o solo + anel.
- **Prova:** capturas mostram a coluna dourada atravessando a tela no mergulho.
- **Fim:** `cnt10 > 30`.
- **Som:** `high_speed_movement` na subida; dois `punch` no impacto.
- **Verificação:** `test_pika_mine_piece`.

### 29 · Yasakani no Magatama (custo 400 · recarga 10 s)
- **Objetivo:** salto e rajada de joias de luz (magatama): um disparo aéreo de área.
- **Funcionamento:** o corpo salta primeiro (4 × tamanho blocos/tick para cima; com S, para trás e para cima) e o disparo começa quando a velocidade vertical cai (`_vel_mc.y < 0,2`) ou `cnt2 > 5`.
- **Execução:** projéteis de luz (`luz_pika.gd`) saem com `Projectile.shoot`: a direção do olhar mais ruído gaussiano × 0,0075 × imprecisão 35.
- **Dano:** `flecha` 0,6 base × DamageFix × 8 de velocidade; cada projétil pode perfurar vários alvos.
- **Recarga:** `COOLDOWN_TIME` é renovado a cada tick enquanto a técnica está em uso (`c.recarga = c.recarga_total`).
- **Fases:** `cnt1 == 0` é o salto; `cnt1 ≤ 10` a rajada; depois a técnica fecha.
- **Visibilidade:** projéteis amarelos com partículas de luz — é o ponto visual mais fraco da Pika (pendente: coluna/anel no clímax).
- **Risco/retorno:** exposto no ar durante o salto; compensa em área aberta.
- **Verificação:** `test_pika_yasakani` e `test_pika_mine_piece`.
- **Relação:** a 24 é o gap-closer com chute; a 29 é a rajada de projéteis.

### 30 · Ama no Murakumo Sword (custo 50)
- **Objetivo:** equipar a espada de luz como item da fruta, para luta corpo a corpo de luz.
- **Funcionamento:** decisão do dono: vira o item da fruta — o ícone da barra muda e a espada vai para a mão sempre que a fruta está equipada.
- **Execução:** usar a 30 de novo larga a espada; comer outra fruta também a larga.
- **Dano:** 8 do mod (3 + 4 do tier + 1 do jogador), com multiplicador 8/26 para o dano da campanha (estocada 26).
- **Alcance:** 3 blocos.
- **Custo:** 50 de energia só ao equipar.
- **Visibilidade:** lâmina amarela luminosa na mão, com brilho de bloom.
- **Interação:** `luz_pika.gd` e o mod do item usam o mesmo componente.
- **Verificação:** `test_pika_mine_piece` ("troca remove o controlador e comer outra larga a espada").
- **Objetivo cumprido:** equipa e larga corretamente.

### 28 · Passiva — Teleporte de luz (toque duplo W/S, sem custo)
- **Objetivo:** esquiva/avanço rápido de luz sem gastar energia nem recarga.
- **Funcionamento:** toque duplo em W ou S com a fruta equipada e sem técnica em curso.
- **Execução:** 2 ticks presos, depois passos de 0,5 bloco na mira (para frente, para o primeiro alvo; para trás, sem alvo).
- **Visibilidade:** corpo some e reaparece com rastro de luz.
- **Limite:** não vale durante outra técnica.
- **Verificação:** `test_pika_mine_piece`.
- **Compartilhada:** o Goro usa o mesmo mecanismo (toque duplo 28).
- **Recarga:** nenhuma.
- **Custo:** nenhum.
- **Direção:** W = frente, S = trás.
- **Objetivo:** reposicionar rápido.

---

## NIKYU NIKYU (Mine Piece) — repulsão · 4 técnicas + passiva

### 21 · Pad Ho (custo 50 · recarga 1,25 s)
- **Objetivo:** a repulsão básica: uma pata de repulsão que EMPURRA para longe tudo à frente.
- **Funcionamento:** 5 ticks de carga (Lentidão IV); segurar entre o 4 e o 5 carrega `cnt6` (clarão e anel na carga cheia).
- **Execução:** no tick 7 a pose é `punch_right` e a pata (`pata_nikyu.gd`) nasce à frente com potência 8 e tamanho `base × (1 + cnt6 × 0,2)`.
- **Dano e empurrão:** a pata empurra em área (`pata_nikyu`); o mod usa a repulsão como controle, não como dano alto.
- **Problema encontrado:** a pata é branca/translúcida e pequena: a repulsão mal se lia.
- **Correção (15/11/2026):** anel de choque âmbar no ponto da pata e feixe curto da mão até ela, escalados pelo tamanho carregado.
- **Prova:** captura mostra o anel e o cone de repulsão.
- **Com Shift:** vira Tsuppari Pad Ho (rajada de patas, abaixo).
- **Verificação:** `test_nikyu_mine_piece` 66/0.
- **Fim:** `cnt1 > 10`.

### 21 + Shift · Tsuppari Pad Ho
- **Objetivo:** rajada rápida de patas para pressionar o alvo.
- **Funcionamento:** com Shift a técnica vira rajada: ao chegar em `cnt1 = 14` segurar Z mantém o contador ali (e `cnt2` ≥ 1,0) e solta UMA pata por tick.
- **Execução:** `_tsuppari()` posiciona cada pata pequena (tamanho 0,25 × alcance, potência 6) num ponto sorteado em ±90° da frente, até 3 + largura blocos.
- **Dano:** cada pata fere e empurra (`pata_nikyu`), somando em área limitada pelo teto da conjuração.
- **Custo:** o mesmo do Pad Ho (50); recarga 1,25 s.
- **Visibilidade:** várias patas brancas; o anel de choque só no Pad Ho simples.
- **Risco/retorno:** gasta tempo parado; o jogador fica com Lentidão.
- **Verificação:** `test_nikyu_mine_piece`.
- **Relação:** variante por Shift da 21.
- **Pendente:** anel por pata (opcional).

### 22 · Ursus Shock (custo 600 · recarga 15 s)
- **Objetivo:** a ultimate de repulsão: uma pata GIGANTE que esmaga e arremessa tudo à frente.
- **Funcionamento:** trava o corpo (Lentidão IX) e cria a pata de tamanho 20 no tick 1; segurar Z prende `cnt1` em 19 e a pata fica colada à mira.
- **Execução:** soltar lança a pata (`modo 1`); a âncora é `pé + 80% da altura + (1 + largura)` blocos na direção do olhar.
- **Dano:** `pata_nikyu` em área grande com empurrão forte; dura até `cnt1 > 30`.
- **Pose:** `ursus_shock`, depois `both_arm_front`.
- **Visibilidade:** a pata branca luminosa enche a tela (e tem anel de choque âmbar na carga cheia); é a mais legível da Nikyu.
- **Custo alto:** 600 de energia (precisa de nível ≥ ~6 com 1600 de máxima).
- **Risco/retorno:** longa imobilidade; alta recompensa em área.
- **Verificação:** `test_nikyu_mine_piece` ("custa 600 e recarrega 15 s").
- **Cancelamento:** `cancelar()` remove a pata.

### 25 · Assault (custo 200 · recarga 5 s)
- **Objetivo:** investida explosiva: avançar como projétil e detonar uma explosão de repulsão no fim.
- **Funcionamento:** três fases do mod: CARGA (`cnt3 = 0`) → INVESTIDA (`cnt3 = 1`) → EXPLOSÃO (`cnt1 ≥ 1`, pata modo 3 no `cnt1 = 9`).
- **Carga:** segurar enche `cnt6`; carga cheia dá clarão e anel (novo) no chão.
- **Investida:** o corpo sai invisível, varrendo na frente; para ao achar alvo ou obstáculo (`_varrer`).
- **Alcance:** `tamanho × (1 + min(Força; 50) × 0,025)`.
- **Explosão:** `_assault_explosao` fere e empurra em área no ponto final.
- **Visibilidade:** a investida em si é discreta (corpo some); a explosão final é a leitura.
- **Verificação:** `test_nikyu_mine_piece` ("custa 200 e recarrega 5 s").
- **Risco/retorno:** exige alvo na frente; sem alvo gasta a energia e termina no ar.
- **Pendente:** rastro da investida (opcional).

### 28 · Kuma Punch (custo 500 · recarga 12,5 s)
- **Objetivo:** o soco ÚNICO da Nikyu: um golpe devastador em LINHA que arremessa o alvo para longe.
- **Funcionamento:** carga (`cnt2 ≥ 9` prende), investida invisível até o alvo (velocidade 6) e então o soco em `cnt1 = 10`.
- **Execução:** a partir do tick 10 o mod fere em cone ao longo da mira: 24 × CNT6 no cubo de 8 × alcance e 18 × CNT6 em esferas de 3 × alcance ao longo do trajeto, até 6 × alcance blocos.
- **Empurrão:** `mira × 6` somada ao radial; golpes nas esferas só enquanto `cnt2 ≤ 8`.
- **Problema encontrado:** o alcance era uma LINHA sem desenho: só pequenas partículas de crit e nuvem.
- **Correção (15/11/2026):** feixe branco-âmbar da mão até a ponta (afinando, 0,45 s) e anel de choque no chão do impacto, e anel na carga cheia.
- **Fim:** `cnt1 ≥ 8 × CNT6 + 25`.
- **Verificação:** `test_nikyu_mine_piece` ("custa 500 e recarrega 12,5 s").
- **Limite declarado:** só o ramo do dono da fruta (sem o ramo da IA).
- **Como usar:** finalizador contra alvo isolado a até ~6 × alcance blocos; exige 500 de energia (nível ≥ 5 com 100 de energia por nível ×1).

### 29 · Passiva — Toque duplo W/S
- **Objetivo:** avançar/recuar rápido sem custo, como a esquiva da Nikyu.
- **Funcionamento:** dois ticks presos com invisibilidade, depois 48 passos de 0,5 bloco na mira.
- **Execução:** `cnt1 = +1` para frente (para no primeiro alvo, cubo 3 × tamanho) e `−1` para trás; três ticks e fim.
- **Custo:** nenhum; recarga nenhuma.
- **Visibilidade:** corpo some e reaparece.
- **Verificação:** `test_nikyu_mine_piece`.
- **Condição:** sem técnica em curso.
- **Direção:** W frente, S trás.
- **Mesma regra:** a da Pika (28).
- **Objetivo:** reposicionar.
- **Limites:** não atravessa paredes.

---

## ESTILO DE COMBATE BASE (Luta) — 3 técnicas desarmadas, teclas diretas Z/X/C

### 1 · Soco (Z · recarga 0,65 s · energia 2)
- **Objetivo:** o golpe básico rápido, sempre disponível, para quem não tem fruta ou espera a recarga.
- **Funcionamento:** `AttackWeakPunch`: o golpe sai no 2º tick; dura 10 ticks.
- **Execução:** cubo de 6 × alcance a 2,5 × alcance à frente.
- **Dano:** 90 (arena) / 9 do mod; empurrão 9; atordoamento 0,12 s.
- **Lentidão:** III (amp. 2) no golpe.
- **Visibilidade:** efeito de impacto `mp_impacto.glb` (animações idle1–3) no ponto do golpe.
- **Verificação:** `test_luta_nativa`, `test_luta_empurrao_paralisia`.
- **Custo:** simbólico (o mod não cobra).
- **Recarga:** própria por técnica (`recargas`).
- **Objetivo cumprido:** golpe curto de resposta.

### 2 · Soco pesado (X · recarga 1,5 s · energia 4)
- **Objetivo:** golpe forte de empurrão alto, que pode ser carregado.
- **Funcionamento:** 8 ticks de preparo com Lentidão IV; segurar X a partir de 0,3 s carrega até 25 ticks (1,25 s).
- **Execução:** o golpe sai no tick 7 sem segurar ou ao soltar; cubo de 6 × alcance.
- **Dano:** 110 (arena) / 11 do mod, +50% com a carga máxima; empurrão 27 (+50%); atordoamento 0,3 s.
- **Visibilidade:** impacto maior e empurrão evidente.
- **Decisão do dono:** Z e X empurram forte (30/10/2026).
- **Custo:** simbólico.
- **Risco/retorno:** preparo longo é um aviso para o oponente.
- **Verificação:** `test_luta_nativa`, `test_luta_empurrao_paralisia`.
- **Recarga:** 1,5 s própria.

### 3 · Sequência de socos (C · recarga 4 s · energia 8)
- **Objetivo:** combo de rajada com um golpe final, para pressionar e finalizar.
- **Funcionamento:** adaptação do projeto: rajada a cada 2 ticks a partir de 0,55 s e golpe final.
- **Duração:** soltar vale a partir de 1,25 s; o teto é 2,55 s.
- **Dano:** rajada 8 por golpe com paralisia 0,4 s; golpe final 132, empurrão 21,6, atordoamento 0,3 s.
- **Decisão do dono:** só o ÚLTIMO golpe empurra; os da rajada paralisam.
- **Visibilidade:** vários impactos em sequência e o final maior.
- **Custo:** simbólico (8).
- **Verificação:** `test_luta_nativa`, `test_luta_empurrao_paralisia`.
- **Limite:** sem `HakiEffect` nem quebra de blocos.
- **Recarga:** 4 s própria.
