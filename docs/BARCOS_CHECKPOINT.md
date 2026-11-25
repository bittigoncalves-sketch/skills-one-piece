# Barcos dirigíveis — 03/10/2026

Pedido atual: passar ao desenvolvimento de todos os barcos dirigíveis na água e sua interação com a água. Controles confirmados: Y assume/sai do comando; W/S acelera/freia/ré; A/D vira.

Projeto Godot 4.6.3, campanha offline. Categoria `navios` e FichaDeNavio já existem. Seis modelos: boat, small_ship, ship, house, house-2kytqgs4rh, house-g7esjlfi4v. Existem sete instâncias no mapa vivo (três botes); preservar mapa e catálogo. Sea Serpent permanece com Claude.

Divisão por arquivo: agente agua_barcos cuida amostragem de ondas sincronizada CPU/shader em oceano_historia/AguaDoMundo e esteira.gd; agente revisao_visual_bestas cuida barco.gd/perfil_barco.gd e orientação dos seis modelos; root cuida controlador de comando, Player/HUD/ModoHistoria, poses e integração/testes. Godot em série quando exige portas; avisar dono antes de rodar.

Contrato: ator CharacterBody3D, origem no centro horizontal do casco à linha d'água; frente -Z. configurar(bib,id,tamanho), posicionar_no_mapa(p), definir_comando(acelerador,leme), limpar_comando(), esta_na_agua(), velocidade_atual(). Propriedade leme Node3D = ponto do piloto. Água nova superficie_em e normal_em; nivel_em mantém semântica plana para jogador/animais. Rastro bounded, só na água, decai parado.

Integração planejada: trocar marcadores por corpos vivos apenas na campanha; Y próximo do leme ou casco acessível desde a água; piloto segue convés, câmera ajustada; deixar leme restaura controle a pé no convés; morte/respawn/troca de cena liberam barco; menus cortam comandos. Colisão do casco, encalhe sem navegar pela terra, ondas com flutuação amortecida e espuma/esteira.

Validação: todas seis fichas e modelos, ações reais Y/WASD, aceleração/freio/ré/curva, inércia ao sair, flutuação e inclinação coerentes com água, costa/obstáculos, menus/morte/respawn/remoção, não duplicar corpos/efeitos, captures GPU e revisão independente.

## Retomada pelo Claude (03/10/2026, à tarde) — pedido do dono

Pedido: "no modo história, parta para o desenvolvimento dos navios, ao pressionar Y é possível subir no navio e dirigi-lo; fazer também a interação dos navios com a água para que flutuem". Dono escolheu ASSUMIR esta frente (parada desde 10h22) e continuar do contrato acima.

**Estado:** navios dirigíveis = bote, chalupa e galeão; os três barcos-casa seguem cenário (decisão desta frente, mantida). Mapa vivo: 5 barcos vivos (galeão, chalupa, 3 botes), todos flutuando.

**Corrigido nesta retomada**
- `barco.gd:191` não compilava (`lado` sem tipo) — nenhum barco nascia.
- `oceano_historia.gd`: `get_shader_parameter` nulo para uniforme não definido → `float(null)` a cada amostra; ondas paradas para os barcos. `_param(nome, padrão)`.
- Flutuação: mola 40/12 com amortecimento sobre a velocidade RELATIVA à onda (a antiga seguia com ~46° de atraso).
- Jogador em pé no convés segurava o casco (afundava até 1,2 m): exceção de colisão só durante o `move_and_slide` do barco.
- `ligar_no_mapa` apagava os barcos-casa e punha barco sem leme na lista (erro no HUD a cada quadro): só troca a peça quando `configurar` dá certo.

**Validação:** `tools/dev_tests/test_navios.gd` 39/39 (flutuar, balançar, Y assume, W frente, piloto no leme, D direita, S freia e ré, Y solta de pé no convés, flutua com o jogador no convés, barcos-casa como cenário); `tools/dev_tests/capturar_navios.gd` (mapa vivo + fotos).

**Próximos passos possíveis:** encalhe/costa medidos, dano/vida do navio (ficha tem `vida`, `canhoes`), replicação em rede (a campanha é offline hoje), revisão visual das poses do piloto.


## Correção solicitada pelo dono — 03/10/2026, Codex

Pedido: colisão entre embarcações trava o jogo; simular apenas barco pilotado; cavalo da vila deve começar guardado no inventário até invocação. Substitui a decisão anterior de flutuar todos os barcos e manter inércia depois de soltar o leme.

Implementado: `barco.definir_pilotado` ativa/desativa toda física de motor/ondas/esteira. Barcos nascem inativos e conservam posição e colisões; Y ativa o selecionado, saída/morte/remoção desativa, zera velocidades e limpa a espuma. Plataformas entre barcos desabilitadas explicitamente. Removida reinjeção de `get_real_velocity()` em `velocity` após contato, pois recuperação de sobreposição não deve virar impulso. Arrays de exclusão das consultas agora são construídos antes de atribuir `exclude`. Preservadas mola/amortecimento e exceção temporária do jogador criadas pelo Claude.

Cavalo: marcador `animals__farm__horse_1__base_1` / `cavalo_da_vila_leve` concede `Cavalo da vila` em `Companhia`/`ProgressaoDoPersonagem`, sem criar corpo. N permite invocar/recolher pelo fluxo existente. `pets_do_mapa_recebidos` persiste a concessão independentemente de vida do pet, evitando duplicação e ressurreição após morte. Documento do mapa e catálogo preservados.

Validação específica: navegação 42/42; colisões 36/36 (6 cenários, 600 quadros de contato/entrada cada, frente/lateral, bote→galeão, chalupa→chalupa e galeão→bote, seguidos de frenagem/ré/Y); cavalo 19/19; progressão 43/43. Colisões com deslocamento real por quadro limitado e barco inativo imóvel; nenhum congelamento nesses cenários. Os números de tempo da sonda headless não são uma medição de FPS do mapa completo. A checagem inicial da ré misturava frenagem e marcha a ré na distância líquida: corrigida a sonda para medir o afastamento após frear.

Logs específicos: `art_src/validation/navios/regressao_piloto.log`, `colisoes.log`. Bateria geral registrada em `art_src/validation/navios/regressao_geral.log`; fechamento abaixo. Mapa vivo e comparação de falhas concluídos.

Mapa vivo validado em `test_barcos_guardados_mapa.gd`: 13/13 verificações — os cinco barcos iniciam e permanecem sem simulação/espuma, com transformações preservadas; exatamente um cavalo concedido, guardado e sem corpo seguidor. Captura GPU real `art_src/validation/navios/barcos_estacionados.png`, inspeção independente sem deformação ou esteira indevida evidente. Esta sonda monta o mapa e os sistemas de barco/pet, deixando os marcadores de áreas animais visíveis; não é uma captura da campanha completa. Logs `mapa_guardados.log`, `mapa_visual.log` e `cavalo_guardado.log`. `capturar_navios.gd` atualizado para a regra atual de barcos estacionados antes do Y.


## Fechamento da validação — 04/10/2026

`./validar.sh rapido` terminou: **120 testes passaram, 16 falharam e 5 foram pulados**. Navegação, colisões de navios, ondas, cavalo guardado, progressão, pets, nado e montaria passaram dentro da bateria.

Uma falha era uma expectativa antiga do teste de pomar/doma: ele exigia exatamente dois pets mesmo depois de o mapa conceder o cavalo. `test_pomar_e_doma.gd` agora mede o inventário antes/depois da tentativa malsucedida, comprovando que ela não concede pet. Reexecução isolada passou com zero falhas (`art_src/validation/navios/pomar_final.log`). Nenhuma regra de doma foi alterada.

As outras 15 falhas não foram corrigidas nesta frente. Nove testes já falhavam na base de nado/montaria: balance, bara_combat, compila (studio), corte_horizontal, ilha_inicial, mera_z_saque, ope_animacoes, studio_playback e trava_fruta_dano. As seis ocorrências adicionais do estado atual são clipes_parkour (salto de interpolação), frutas_na_historia (timeout de 120 s), sala_publica (UPnP/endereço), lan_discovery e sondas net_mp/net_dano (peers não apareceram). As falhas de rede não demonstram regressão da navegação offline; o ambiente e a conectividade precisam de validação própria. Registro em `docs/LISTA_DE_CORRECOES.md`. Não declarar a suíte inteira verde.

Estado: correção de barcos/cavalo concluída e validada nos cenários descritos; planejamento da Harpia documentado separadamente em `docs/BOSS_HARPIA_PLANO.md`. Os ataques da Harpia ainda são planejamento. Nenhum commit, push, reset ou alteração de mapa/catálogo nesta correção.

## 10/10/2026 — barcos só pelo vendedor (pedido do dono)
Os 7 barcos do mapa vivo saíram (5 dirigíveis + 2 barcos-casa). Barco agora é comprado no
**vendedor de barcos** do porto (1 moeda, um de cada tipo), fica salvo
(`ProgressaoDoPersonagem.barcos`) e atraca numa vaga perto do vendedor ao abrir o jogo
(`src/historia/navios/cais.gd`, `Navegacao.ligar_frota/lancar`). Detalhes e medições:
`docs/PEDIDO_2026-10-10_HISTORIA.md`. Testes: `test_vendedor_de_barcos`,
`test_barcos_guardados_mapa` (ajustado).

## 15/10/2026 — "Navegar?" e a tripulação (pedido do dono)
Y no barco abre a janela modal (`JanelaDaTripulacao`): **Sim/Não**. Não → o jogador volta à costa
(chão firme perto do vendedor de barcos). Sim → aliados em 3D à esquerda, seis vagas cinza com "+" à
direita, arrastar para escolher (arrastar de volta tira); **Zarpar** com 3–6, senão "tripulação
insuficiente" e costa; **Cancelar** = recusa. Regra em `src/historia/navios/tripulacao.gd`; fluxo em
`comando.gd` (`janela == null` mantém o Y direto, usado só pelos testes de física).
- Ave/besta marinha ficam FORA do barco no modo "seguir" (a gaivota circula e pousa); terrestres vão
  fixos no convés. Soltar o leme a até 35 m do vendedor dispensa a tripulação (volta ao inventário e
  os modos dos pets são restaurados); no mar ela continua a bordo.
- **Adiado, com gatilho:** humanos recrutados (Nami direciona o navio à ilha mais próxima) e pets
  marinhos que seguem nadando — ambos dependem de existir recrutamento / pet marinho
  (`ProgressaoDoPersonagem.recrutados`; categoria `bestas_do_mar` já é reconhecida). Layout editável da
  janela (`LayoutDeJanelas`) não registrado.
- Validação: `test_tripulacao.gd` 26/26 (inclui o contrato de arrastar do Godot), `test_navios` 42/42,
  `test_navios_colisao` 36/36. Visual da janela NÃO conferido em tela.

### 15/10/2026 (2) — roleta de tripulantes no Barba Negra
Humanos vêm da roleta (100 moedas): Nami comum, Crocodile incomum, Barba Negra lendário
(`src/historia/tripulantes/catalogo_de_tripulantes.gd`, recrutados salvos em `progressao.recrutados`).
**Pesos 70/25/5 e "sem repetição" são escolha minha, não do dono** — ajustar em `RARIDADES`.
Loja do Barba Negra refeita: 1,3× maior, linhas por preço (grátis → 100 → 1000), faixa colorida,
símbolo (`SimboloDeLoja`) e etiqueta de preço; roda animada em `RoletaHud`. Humanos aparecem na janela
da tripulação (3D do rig do elenco), ficam no convés (`TripulanteHumano`); a Nami diz o rumo da ilha
mais próxima (aviso a cada 20 s + dica do leme). Crocodile e Barba Negra a bordo: sem função ainda
(GATILHO: o dono definir). Testes: `test_roleta.gd` 26/26, `test_tripulacao.gd` 31/31,
`test_barba_negra.gd` 56/56 (expectativa de 3 → 4 linhas atualizada). Visual NÃO conferido em tela.

### 15/10/2026 (3) — Barba Negra e Crocodile a bordo
- **Barba Negra** (`pistoleiro_de_bordo.gd`): pistola na mão, atira em qualquer inimigo do grupo `enemy`
  até 45 m, 12 de dano a cada 0,9 s (bala = `DamageZone` com o jogador como autor; o casco é poupado).
- **Crocodile** (`voo_de_areia.gd`, `pernas_de_areia.gd`): sobe do convés e circula o barco (7 m de raio,
  5,5 m de altura), inclinado para a frente; as pernas encolhem (`SkeletonModifier3D`) e viram um cone de
  areia com grãos; dispara o Z da Suna Suna (`SandFX`, lâmina) a cada 2,6 s com o dano do `Balance` × 0,5.
- **Números meus, não do dono:** alcance 45 m, 12 de dano, 0,9 s / 2,6 s, escala 0,5, voo 7 m × 5,5 m.
  Ajustar nas constantes dos dois arquivos.
- Validação: `test_tripulantes_de_bordo.gd` 19/19. Visual (pose, cone de areia, giro do corpo ao mirar) NÃO
  conferido em tela; a frente do rig (−Z) é suposição.

### 15/10/2026 (4) — navegação contínua, Nami ao leme, roleta no centro
- **Viagem** (`comando.gd`): depois de zarpar, soltar o leme NÃO encerra; a faixa **NAVEGANDO**
  (`faixa_navegando.gd`, topo da tela) fica até o barco entrar numa ilha (precisa ter saído do mar, ou ser
  outra ilha que a de origem). Chegando: barco para, tripulação desce, aviso "Chegada: <ilha>". Y no barco da
  viagem volta ao leme sem perguntar de novo. O antigo "dispensa a até 35 m do porto" saiu.
- **Nami** na tripulação: ela dirige (piloto automático em `_nami_dirige`) até a ilha mais próxima **que não
  seja a de onde se zarpou** (escolha minha); o jogador fica de pé no convés e Y não toma o leme. Sem outra ilha
  no mapa, o jogador dirige. Limite: sem desvio de obstáculos/recifes (só aponta a proa e acelera).
- **Roleta**: painel e sorteado centralizados (`CenterContainer`); ao parar a roda some e o sorteado
  (3D + nome + raridade) fica 1 s no centro (`RoletaHud.exibicao`) e tudo desaparece; não há mais "Continuar".
- Validação: `test_tripulacao` 41/41, `test_roleta` 31/31, `test_navios` 42/42, `test_barba_negra` 56/56,
  `test_tripulantes_de_bordo` 19/19. Visual não conferido em tela.

### 15/10/2026 (5) — Sanji e cozinheiros na roleta, passeio no convés, "próxima ilha"
- **Roleta:** Sanji, Beto, Iara, Ravi e Otto (os cozinheiros da biblioteca do mapa) entram como COMUNS,
  junto com a Nami: 6 comuns, 1 incomum, 1 lendário (9 no total). Como o peso é por raridade, cada comum sai
  menos que a Nami saía antes. Sem função a bordo. Modelos: `bib.instanciar("cozinheiro_*")`, clipes
  `descanso`/`caminhada` do GLB (`TripulanteHumano`).
- **Passeio** (`passeio_no_conves.gd`): humanos e pets terrestres andam pelo convés (escolhem ponto com chão do
  barco na altura do convés, andam, param 1,5–5 s). O Barba Negra para ao mirar; o Crocodile voa e não passeia.
  Sem desvio de obstáculo no meio do caminho (GATILHO: navmesh do convés se um barco tiver mastro no meio).
- **Nami:** "ilha mais próxima" passou a ser a PRÓXIMA ilha = a mais perto que não é a de onde se zarpou
  (zarpando do mar, a última ilha onde o jogador esteve). Sem outra ilha ela não conduz. Fala: "Nami: próxima
  ilha é X, a N m, rumo R".
- Validação: `test_roleta` 38/38, `test_tripulacao` 47/47, `test_tripulantes_de_bordo` 19/19. Visual não conferido.

### 15/10/2026 (6) — a Nami para o navio se o jogador não está a bordo
Com a Nami ao leme, se o jogador cai na água, fica na costa ou se afasta (fora do casco + 0,5 m por mais de
0,6 s — um pulo não conta), ela PARA o navio (freio com ré curta, sem leme), aparece "Nami parou o navio" no
aviso e na faixa NAVEGANDO, e a dica oferece "Y · Subir a bordo". Y perto do casco leva o jogador ao convés e
ela retoma o rumo. Código: `jogador_a_bordo`/`_ver_se_o_jogador_caiu` em `comando.gd`.
Validação: `test_tripulacao` 54/54 (cai → para → sobe → retoma → chega). Visual não conferido.
