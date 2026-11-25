# Loja de projéteis no Builder + Corrida de caranguejos — plano (06/10/2026)

Pedido do dono: "adicionar uma loja de projéteis na aba de projéteis a serem disparados no
editor, adicionar uma pista de corrida gigante no jogo e projetar uma corrida de
caranguejos, adicionar um npc para iniciar a corrida, o prêmio da corrida será 10 moedas,
a requisição para participar é ter um caranguejo, adicionar obstáculos na pista e parkour.
não é possível sair do caranguejo até o fim da corrida, total 5 minutos".

## Decisões do dono (06/10/2026)

| tema | decisão |
|---|---|
| loja de projéteis | **catálogo pronto + modelos**: grade de projéteis prontos (forma, rastro e valores padrão) e qualquer `.glb` da loja do editor como projétil |
| onde fica a pista | **mapa próprio**: região só da corrida; o NPC fica na ilha e leva o jogador; ao terminar ele volta. O mapa da ilha não é tocado |
| disputa | **os dois**: caranguejos rivais com IA **e** prêmio de 10 moedas para quem completar em até 5:00, mesmo sem chegar em 1º |
| regra assumida (na pergunta) | entra quem tem um caranguejo vivo (o inicial ou um domado); a corrida acaba ao cruzar a chegada ou em 5:00; até lá não dá para desmontar |
| Noro Noro | **só fechar a Z** (feito: `docs/NORO_NORO_PLANO.md`, fatia 8) |

## Decisões técnicas (minhas, com custo e gatilho)

| decisão | benefício agora | impacto futuro / extensão | custo | risco e gatilho |
|---|---|---|---|---|
| A pista é uma **região à parte na mesma cena** da história (sobre o mar, ~1,3 km da ilha), montada ao começar e apagada ao terminar. Não é outra cena | caranguejo, montaria, progresso, HUD e pets já vivem na cena da história; trocar de cena exigiria recriar tudo e recarregar a ilha na volta | outra corrida = outro dado de pista no mesmo controlador | baixo | a ilha continua simulando ao longe (animais e pomar). Gatilho: se medir mais de 2 ms por quadro com a corrida ativa, pausar a ilha durante a corrida |
| Pista descrita como **trechos encadeados** (reta, curva, ilhotas, rampa…), como uma tartaruga que anda e vira. A geometria, os portões, os obstáculos e o caminho da IA saem do mesmo dado | uma fonte só; o teste prova que o circuito fecha e que todo salto cabe no pulo do caranguejo | trecho novo = função nova no montador | médio | o dono não edita a pista no editor de mapa. Gatilho: pedido para editar → exportar para `mapas/corrida/*.json` e dar ao editor peças "portão" e "obstáculo" |
| Peças estáticas montadas pelo **`MapaMontador`** (caixa, cilindro, cunha, modelo) | mesmos materiais e colisão do mapa da história | já sai no formato do editor | baixo | — |
| **Locomoção da montaria extraída** para uma função compartilhada; o jogador e os rivais andam pela mesma conta | rival e jogador com a mesma física (justo), sem duplicar código | lentidão (Noro), lama e impulso entram num lugar só | médio (mexe na montaria) | regressão na montaria: rodar `test_montaria*` antes e depois |
| Obstáculos acertam por **conta geométrica** (distância ao tronco, ao martelo, ao braço), não por `Area3D` | o caranguejo é camada 0 (pets não bloqueiam o dono), então nenhuma `Area3D` o enxerga; a conta é determinística e testável | obstáculo novo = forma + empurrão | baixo | — |
| Caranguejos **atravessam uns aos outros** (camada 0, como os pets) | nada de engavetamento nem rival travando o jogador | — | zero | sem trombada entre corredores. Gatilho: o dono pedir contato → camada própria da corrida |
| Relógio da corrida = soma do `delta` da física (regra do projeto: sem `SceneTreeTimer` para regra de jogo) | determinístico e testável com `--fixed-fps` | — | zero | — |
| NPC da corrida só na **loja do editor (aba NPCs)**, como os outros (decisão do dono, 03/10); F8 › Corrida abre a corrida para teste | segue a regra existente | — | baixo | o dono precisa pôr o NPC no mapa pelo editor |
| `SkillsBuilder.gd` (1.007 linhas, acima do teto de 900): **o editor de poses sai** para `editor_de_poses.gd`, e a loja de projéteis nasce em arquivo próprio | volta abaixo de 900 | — | baixo | — |

## Fatias — loja de projéteis (Builder)

| # | fatia | pronto quando | estado |
|---|---|---|---|
| P1 | Catálogo + visual do projétil | `CatalogoDeProjeteis` com ~10 prontos (energia, bala de canhão, bomba, flecha, kunai, shuriken, pedra, bola de fogo, bolha, estaca de gelo); campos opcionais `visual`, `modelo`, `giro`, `rastro` na seção Projéteis; executor e prévia desenham pelo mesmo `visual(...)` (forma, orientação no rumo, giro, rastro); `.glb` da loja como projétil | **feito** — `catalogo_de_projeteis.gd` (`criar`/`animar`, 10 formas procedurais, rastro por `CPUParticles3D` no mundo, `.glb` no diâmetro do raio), campos opcionais no contrato (id de modelo conferido por regex), executor e prévia ligados |
| P2 | Loja na aba Projéteis | grade com miniatura (prontos + modelos da loja, com busca); clicar aplica forma e valores na skill (desfazer funciona); `SkillsBuilder.gd` < 900 linhas | **feito** — `loja_de_projeteis.gd` (2 colunas de 124 px: o inspetor tem 256 px; 3 colunas alargavam o painel e apertavam a prévia), fotos pela fila do `GeradorDeMiniaturas` (`pedir_cena`/`fotografar_cena`, com realce de luz); editor de poses saiu para `editor_de_poses.gd` → `SkillsBuilder.gd` 869 linhas |
| P3 | Validação | teste headless (dados, aplicar, executor dispara o visual certo, skill antiga sem os campos continua válida) + fotos da loja e dos projéteis em voo | **feito** — `test_loja_de_projeteis` 22/22; `test_skills_builder_executor` 21/21, `_publicar` 20/20, `test_editor_de_poses` 12/12, `test_poses_do_builder` 16/16; fotos `capturar_loja_de_projeteis.gd` (loja, modelos, 10 em voo, prévia com bola de fogo) |

## Fatias — corrida de caranguejos (Modo História)

| # | fatia | pronto quando | estado |
|---|---|---|---|
| C1 | Pista | ~1,3 km, circuito fechado sobre o mar. Trechos: largada, toras rolantes, ilhotas (parkour de saltos), rampa + passarela dos martelos, curva dos braços giratórios, lama, degraus, plataformas móveis, paredes móveis, reta final com impulsos. Portões em ordem. O teste prova que o circuito fecha, que todo vão cabe no pulo e que todo degrau sobe | **feito** — `src/historia/corrida/pista_dos_caranguejos.gd`: 1.273 m, 744 peças (mapa válido do editor), 18 portões (cada um com a sua distância de volta), 257 pontos de caminho; ilhotas com desvio ≤ 3,5 m entre vizinhas; rampa que sobe prolongada 0,6 m |
| C2 | Locomoção compartilhada + trava | função única de locomoção (montaria e rivais); modificadores lama/impulso/atordoado/lentidão; trava de desmontar com aviso; `test_montaria*` sem regressão | **feito** — `src/historia/pets/locomocao_de_montaria.gd` (`mover`, metas FATOR/ATORDOADO, `Lentidao` também na montaria, **subir quina ≤ 0,15 m** — o cilindro de fundo chato travava na junção rampa/deck); `montaria.gd`: `trava`, `piloto`, `montar(alvo, direto)`, dica "Y · travado até a chegada"; `companhia.recolher` recusa o caranguejo em corrida; `test_nado_montaria` 0 falhas |
| C3 | Obstáculos | toras, martelos, braços, paredes e plataformas móveis; empurrão + atordoamento curto; queda na água = volta ao último portão | **feito** — `obstaculos_da_pista.gd`: 5 toras, 5 martelos, 2 braços (poste físico), 3 fileiras de paredes de correr (forma redimensionada a cada passo), 3 plataformas `AnimatableBody3D` que carregam o caranguejo; lama ×0,5 com faixa seca de 3,5 m; impulso ×1,5 por 1,4 s; imunidade de 1,2 s entre batidas |
| C4 | Rivais com IA | 5 caranguejos com piloto (cores e números próprios, piloto montado); seguem o caminho, pulam o parkour, erram às vezes; terminam a pista sozinhos | **feito** — `piloto_de_caranguejo.gd` (pula NA borda no rumo da pista, segue reto no ar, espera a plataforma alinhar mirando onde ela vai estar, erro sorteado por semente); rivais com piloto montado (rig do jogador, pose de montaria), bandeirola e nome na cor; terminam entre 167 e 195 s, 0–3 quedas |
| C5 | Controlador da corrida | ida à pista com o caranguejo do jogador, contagem 3-2-1, relógio 5:00, posições, chegada ou tempo esgotado, 10 moedas se completou em até 5:00, volta à ilha; outros pets pausados e escondidos; a montaria não solta até o fim | **feito** — `corrida_de_caranguejos.gd` (ligado no `ModoHistoria`); pista a ~1,4 km da ilha, montada na largada e apagada na volta; semáforo de 3 luzes no arco; placas com o nome do trecho em cada portão; relógio pela física; resultado 6 s e volta |
| C6 | NPC + HUD | "Organizador da corrida" (ficha + loja: Correr / motivo da recusa) na loja do editor; HUD de tempo, posição, portão, contagem, resultado; F8 › Corrida | **feito** — ficha `npc_corrida` (bandeira quadriculada ao lado) + `loja_da_corrida.gd` (Correr apagado com o motivo; a janela fecha ao largar: `LojaDeNpc.fecha_a_janela`); importado na loja do editor, aba NPCs (`tools/importar_npcs_na_loja.gd`, catálogo +1 entrada); `src/ui/hud_da_corrida.gd`; F8 › Corrida |
| C7 | Validação | corrida inteira headless com piloto automático no caranguejo do jogador (completa em < 5:00, recebe 10 moedas, Y não desmonta); sem caranguejo = recusa; tempo esgotado = sem prêmio; rivais completam; fotos com GPU (largada, ilhotas, martelos, chegada, HUD) | **feito** — `test_corrida_de_caranguejos` 29/29 (rodar com `--fixed-fps 60`; `validar.sh` passa o argumento): jogador completa em 163,8 s com 1 queda, +10 moedas; tempo esgotado sem prêmio; fotos `capturar_corrida_caranguejos.gd` (organizador, largada, 6 trechos, chegada, vista aérea) |

Checkpoint: este arquivo é atualizado a cada fatia (estado, arquivos, testes).

## Como jogar e testar

- **No jogo:** pôr o "Organizador da corrida" no mapa pelo editor (loja › NPCs), falar com E e clicar em Correr. Sem pôr no mapa: F8 › Corrida.
- **Testes:** `test_corrida_de_caranguejos` (com `--fixed-fps 60`), `test_loja_de_projeteis`, `test_nado_montaria`.
- **Fotos:** `capturar_corrida_caranguejos.gd`, `capturar_loja_de_projeteis.gd` (com tela, `DISPLAY=:1`).

## Gatilhos do que ficou de fora

- **Trombada entre caranguejos:** eles se atravessam (camada 0, como os pets). Gatilho: o dono pedir contato.
- **Editar a pista no editor de mapa:** o editor não abre a pista. Gatilho: o dono pedir → exportar para `mapas/corrida/*.json` e criar as peças "portão" e "obstáculo".
- **Recorde de tempo salvo:** não pedido. Gatilho: o dono pedir ranking.
- **Ilha simulando ao longe durante a corrida:** gatilho, se medir mais de 2 ms por quadro a mais com a corrida ativa → pausar a ilha.

## Cores dos rivais (pedido de 06/10/2026, noite)

Pedido do dono: "dar várias cores aos caranguejos, deixando a cor dos adversários do jogador aleatória".

**Decisões dele:**
- só os rivais; o caranguejo do jogador fica como está;
- cores sorteadas a cada corrida, em qualquer matiz, vivas e distintas entre si.

**Como ficou:** `src/historia/corrida/cores_dos_caranguejos.gd`.
- `sortear` divide o círculo de cores em 5 fatias a partir de um ponto sorteado, com folga mínima de matiz de 0,14, saturação 0,75–0,95 e valor 0,85–1,0.
- `pintar` troca matiz e saturação por shader e conserva o brilho de cada ponto, então o desenho do casco fica. A cor do caranguejo vem dos vértices, por isso tingir o albedo não servia.
- Bandeirola, piloto e nome usam a mesma cor.
- O painel de tempo da corrida foi para o canto superior direito: no meio, cobria os avisos da HUD da história.

**Teste:** `test_corrida_de_caranguejos` 33/33. Confere vivas e distintas, os 5 pintados, o caranguejo do jogador intocado e outra corrida com outras cores. Foto: `1b_grid_de_frente`.
