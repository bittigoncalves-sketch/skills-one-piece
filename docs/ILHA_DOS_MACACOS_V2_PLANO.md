# Ilha dos Macacos v2 — Gorila-rei, vila plana, estradas e 5 missões (plano de 22/11/2026)

Pedido do dono (22/11/2026): planejar com o Codex a missão contra o **Gorila-rei**, que começa quando o jogador chega à ilha;
criar um **local plano e estradas**; criar **5 missões** na ilha; **eliminar toda construção que não seja árvore** (pode
adicionar construções temáticas); liberado Blender, MCPs, downloads e pesquisa; **o Codex faz texturas e imagens**.
Meta fixada: "fim da atualização da ilha".

Respostas do dono às três perguntas: (1) o Gorila-rei SUBSTITUI o Macaco-rei: gorila feito no Blender, estilo voxel, comportamento de
chefe, ataques com área de dano em vermelho, vida alta, skills e animações próprias, **sem skill builder**; (2) remover tudo, inclusive os
vendedores (novos assets pelo Codex→Blender se necessário); (3) dificuldade "duro mas justo".

## Divisão de trabalho

| Quem | Faz | Onde escreve |
|---|---|---|
| Codex | imagens e texturas: folhas do gorila, construções, texturas, ícones | `art_src/references/ilha_macacos_v2_codex/`, `assets/textures/ilha_macacos/` |
| Claude | mapa (relevo, estradas), Blender (modelos voxel, rig, animação), Godot (boss, missões, props), testes | `tools/`, `src/`, `mapas/`, `assets/models/`, `docs/` |

Nota técnica: o terreno do mapa NÃO usa textura (cor chapada por solo: grama/terra/areia/rocha/mata). As texturas do Codex entram nos
**modelos** (construções, gorila, props), não no chão. O chão é diferenciado pelos códigos de solo.

## Layout (coordenadas locais à ilha; centro do mundo em (1500, 0); placa 256 × 256 m)

Arquivo único de verdade: `tools/mapa_ilha/layout_macacos.gd` (usado pelos três geradores).

- **Cais rústico** (oeste, x ≈ −128): substitui o `dock_long`.
- **Vila dos Macacos** (praça plana, centro (−12, 4), plana até raio 30 m, altura 2,4): Mestre do Geppo, fogueira, torre de vigia, arco de entrada,
  cabanas. Nenhuma árvore a menos de 46 m do centro.
- **Estradas** (terra, 5,2 m de largura, perfil suavizado): cais→vila; vila→Trono; vila→Bananal; vila→Cabana do Curandeiro; vila→Totens.
- **Sítios planos** (círculos aplainados): Bananal (−62,−40), Curandeiro (−58,56), Totens (42,78), **Trono do Gorila-rei** (platô no morro
  nordeste, centro (62,−60), raio plano 18 m, altura 10,0, solo rocha).
- Árvores: continuam todas (floresta gigante). Sub-bosque (arbustos, pedras, cogumelos) continua: não é construção.
- **Removido:** lojas de armas e de roupas e seus 3 vendedores, o píer `dock_long` e o Macaco-rei.
  **Ficam** (decisão 22/11, construção temática): as 8 plataformas de madeira do Geppo em espiral e o baú fixo do topo, que é o prêmio do "fruto dourado" (missão 5); sem elas não há como subir à copa.

## Missão principal — "O Rei da Selva" (começa ao chegar)

- **Gatilho:** `DetectorDeIlha.chegou(MACACOS, primeira_vez)`: ao pisar na ilha pela 1ª vez a missão é aceita sozinha (aviso na tela, marcador/bússola
  no Mestre do Geppo). É **paralela**: não bloqueia a cadeia "uma por vez" das demais.
- **Etapas:** (1) "Fale com o Mestre do Geppo na vila" → ele conta do Gorila-rei e aponta o Trono; (2) "Derrote o Gorila-rei no Trono".
- **Prêmio:** 6000 XP, 800 moedas, baú de chefe (existente `BausDeChefe`), título.
- **Dificuldade:** teto da ilha é nível 20; alvo é jogador nível 12–16 com Geppo. Sem portão de nível; o aviso diz o nível recomendado.

## As 5 missões da ilha (ordem sugerida; podem ser feitas em qualquer ordem, uma por vez)

| # | Nome | Quem dá | O que fazer | Evento |
|---|---|---|---|---|
| 1 | Cesto de bananas | Cozinheira da vila | colher 6 cachos no Bananal | `banana` (prop interativo) |
| 2 | Pesca do cais | Pescador do cais | pescar 3 peixes | `peixe` (já existe) |
| 3 | Os saqueadores | Mestre do Geppo | derrotar 8 macacos humanoides | `macaco` (abate) |
| 4 | Os quatro totens | Curandeiro | golpear os 4 totens no sítio dos Totens | `totem` (prop golpeável) |
| 5 | O fruto dourado | Vigia da torre | subir ao topo da árvore imensa com Geppo e colher o fruto; prêmio: baú | `fruto_dourado` (prop interativo) |

Prêmios: 300–900 XP e 100–300 moedas escalonados; a 5 dá o baú. NPCs reaproveitam corpos existentes (`npc_comida`, `npc_vendedor_frutas`, `npc_ferreiro`).

## Gorila-rei (boss)

- **Modelo:** Blender, voxel, rig próprio (hierarquia de ossos nomeados), animações: `idle`, `walk`, `run`, `rugido` (bate no peito), `soco_chao`, `pulo_esmagar`,
  `arremesso`, `investida`, `giro`, `golpeado`, `morte`, `furia` (fase 2). Textura de pele do Codex (atlas) aplicada como material.
- **Classe:** `src/historia/bosses/gorila_rei/` (mesma família da Harpia: `AnimalDaIlha` + controlador de habilidades). **Sem skill builder.**
- **Ficha:** `boss: true`, ~600 de vida (barras de chefe), preso à arena do Trono; volta ao covil se o jogador sair; respawn pelo mecanismo dos chefes.
- **Golpes (todos com aviso vermelho no chão, preenchendo até o contato; o dano só vale na área mostrada):**
  1. **Soco duplo no chão** — círculo vermelho à frente (raio 4 m), 0,9 s de aviso.
  2. **Pulo esmagador** — círculo vermelho grande no alvo (raio 7 m), 1,2 s, dano e knockback.
  3. **Investida de ombro** — faixa vermelha em linha (largura 3 m, 14 m), 1,0 s.
  4. **Giro** — anel vermelho em volta dele (raio 6 m), 0,8 s, só de perto.
  5. **Arremesso de pedra** — marca vermelha no ponto de queda (raio 3 m), 1,1 s, à distância.
  6. **Rugido** (fase 2) — onda de aviso que chama macacos humanoides.
- **Fases por vida:** F1 100–55 %, F2 55–0 % (fúria: aviso 20 % mais curto, rugido, golpes encadeados). Todos os golpes com aviso, recarga e janela de contra-ataque.
- **Telégrafo:** `AvisoVermelho` (novo, decal de disco/faixa/anel, shader unshaded, só apresentação, dano decidido no servidor por geometria igual à mostrada).
- **Rede:** decisão do golpe só no servidor; cliente recebe fase/golpe/posição do aviso por replicação.

## Ordem de execução e critérios

1. Layout + geradores (relevo, estradas, remoção das construções) — critério: mapa valida; 0 peça de loja/píer/plataforma; plano medido (variação de altura ≤ 0,15 m no raio plano); fotos.
2. Construções temáticas (Blender voxel) + colocação — critério: GLB no catálogo, peças colocadas sem árvore dentro, foto.
3. Gorila-rei: modelo → rig/animações → classe e golpes → aviso vermelho → luta testada headless (golpe só dá dano dentro da área).
4. Missões e props — critério: `test_missoes_macacos`.
5. Bateria vizinha, documentação, memória, checkpoint.

**Gatilhos de dívida:** (a) se o desempenho da ilha cair abaixo de 45 FPS medidos, reduzir sub-bosque; (b) se o chefe precisar de mais de 6 golpes, extrair tabela de golpes para dados;
(c) se uma 3ª ilha pedir vila plana, extrair `layout_macacos.gd` para formato genérico.

---
## Estado (22/11/2026) — feito e validado

**Mapa** (`test_ilha_macacos_v2` 19/0): vila plana (variação 0,000 m no raio 28), 4 sítios planos, 5 estradas de terra com rampa contínua (máx 13°), sem loja, vendedor, píer antigo nem Macaco-rei; floresta gigante mantida (42 árvores imensas). Cadeia de regeração: `gerar_ilha_dos_macacos` → `gerar_floresta_macacos` → `colocar_construcoes_macacos` (layout em `layout_macacos.gd`). Trono: centro (62,−60), altura 10 m (baixei dos 16,5 planejados: a estrada passava de 14°).
**Construções** (Blender voxel, `construcoes_macacos.py`, texturas do Codex): cabanas do Mestre e do Curandeiro, tendas, torre de vigia, cais rústico, portal, 3 totens, altar das bananas, trono, fogueira, bananeira e props (cacho, fruto dourado). As 8 plataformas do Geppo ficam (caminho do fruto dourado).
**Gorila-rei** (`test_gorila_rei` 0 falhas, 3 execuções): modelo voxel + 12 clipes no Blender; `combate_gorila.gd` com 5 golpes + fúria; cada um mostra a área vermelha e só fere quem está DENTRO dela (medido dentro×fora); nada fere antes do contato; fase 2 abaixo de 55 %; morte e reinício. Vida 1100 (subi dos ~600 da opção; um número em `registrar_gorila_rei.gd`). Dano calibrado por medição em nível 14 (`config_gorila.gd`).
**Missões** (`test_missoes_macacos`: a principal começa ao pisar na ilha, 5 missões andam e se entregam, o chefe entrega a principal e solta baú).
**Fotos:** `art_src/validation/ilha_macacos_v2/` (Weston isolado) e `art_src/validation/ilha_macacos/gorila_rei/` (poses).

### Limites e pendências declarados
- **Visual do gorila no jogo e sensação de luta** não avaliados por humano; só poses do Blender e testes por medição. Ajustar números de dano/aviso após playtest.
- **Rede:** a decisão do golpe é só do servidor, mas o aviso vermelho e a pedra são desenhados só onde o chefe roda (sem replicação para clientes remotos). GATILHO: antes de multiplayer da história, replicar `golpe/etapa/marca`.
- Rugido: a fúria acorda os macacos humanoides num raio de 70 m (implementado depois). Não implementado: totens são acionados com E (não por golpe).
- Terreno não usa textura: o Codex entregou texturas de chão que só valem para modelos.
- Cais: modelo novo, ponta sobre o mar conferida por teste de geometria; atracar barco nele não foi testado.
