# Carga do jogo e do Modo História (28/10/2026)

Pedido do dono: "monitoramento do que carrega quando se inicia o jogo" e "uma tela de carregamento quando se inicia o
modo história — quero ver o que está sendo carregado".

## O que existe

- `MonitorDeCarga` (`src/ui/monitor_de_carga.gd`, estático, sem autoload): registra
  - **marcos da inicialização do jogo** (autoloads, GameFlow, menu principal) com o tempo desde que o motor começou →
    console `[Carga] ...` e `user://carga/inicio_do_jogo.txt`;
  - **uma carga** (hoje o Modo História): etapas com tempo, sub-etapas, recursos lidos do disco (modelos 3D, com tamanho e
    tempo) e quantas vezes o modelo já estava em memória → console e `user://carga/ultima_carga.txt` (etapas na ordem, as 5 mais
    lentas, os 10 modelos mais lentos).
- `TelaDeCarregamento` (`src/ui/tela_de_carregamento.gd`): aparece quando o modo história começa (`GameFlow.start_story`),
  antes mesmo de a cena abrir. Mostra a etapa de agora e o que ela faz, a barra, as **etapas concluídas com o tempo de cada
  uma**, os **arquivos lidos do disco** (modelo, ms, MB) e, no rodapé, tempo, nós, memória e modelos lidos/em cache. Some com
  fade ao fim.
- `ModoHistoria._ready` virou uma carga em ETAPAS (27 etapas): entre uma e outra devolve o quadro para a tela redesenhar, e
  enquanto carrega a cena não processa nada (`process_mode = DISABLED`, devolvido no fim). O que é pesado e divisível anda aos
  poucos: as peças do mapa (`MapaMontador.montar_com_progresso`, de 12 em 12) e o fundo do mar
  (`FundoDoMar.preparar_por_ilha`, um montador por passos). Sem janela (headless/testes) nada espera: só mede, o
  comportamento é o de antes.
- Onde ficam os logs: `user://carga/` (no lançador do dono, `~/.local/share/godot/app_userdata/<projeto>/carga/`).

## O que a medição mostrou (mapa vivo, 2.799 peças, headless; 18,9 s)

| etapa | tempo | % |
|---|---|---|
| **Fundo do mar de cada ilha** | 11,2 s | 60 % |
| ↳ medindo o relevo (amostragem da grade, célula a célula, em GDScript) | 10,0 s | |
| ↳ montando os blocos | 1,1 s | |
| **Montando as peças do mapa** (320 modelos lidos do disco, 198 MB; 2.914 reaproveitados da memória) | 5,6 s | 30 % |
| Relevo das ilhas (blocos) | 0,5 s | |
| NPCs das ilhas | 0,4 s | |
| Coleta de madeira | 0,2 s | |
| Personagens do Mine Piece | 0,2 s | |
| todas as outras | < 0,2 s | |

Memória estática ao fim: 1,7 GB, 43.847 nós.

- `test_relevo_marinho` cobra "montagem em < 4000 ms" e hoje dá ~11 s: o orçamento estourou com o crescimento do mapa.
  **Gatilho / ideia, não feita:** guardar a grade do fundo em disco (cache) ou amostrar em outra thread; é onde mais se ganha.

## Limites conhecidos

- Uma etapa que é UMA chamada bloqueante (relevo das ilhas, NPCs, personagens, LOD...) congela a tela naquele texto até
  acabar (nenhuma passa de 0,5 s hoje). A aparência da tela (cores, tipografia, as listas) **não foi vista**: headless não
  desenha; só se conferiu a lógica (`test_carga_do_modo_historia` 18/18).
- O tempo de leitura dos modelos é medido na primeira vez que cada um aparece (`BibliotecaDeModelos.instanciar`).

## Redução do fundo do mar (28/10/2026, pedido: "reduzir os 10 s do fundo do mar")

A grade do relevo (`RelevoMarinho.amostra`, 2.435 × 739 = 1,8 milhão de células, ~4 µs cada em GDScript) era a parte dos 10 s.
Duas mudanças, as duas com o MESMO resultado número a número (provado em `test_fundo_do_mar_cache`):

1. **Threads** (`FundoDoMar.Montagem`, `WorkerThreadPool`): pacotes de 8 linhas, cada thread com a sua cópia do relevo
   (`RelevoMarinho.duplicar()`, sem estado dividido). **Limite de 4 threads, por medição:** o `FastNoiseLite`/relevo escala até
   4 threads (2,5× mais rápido) e PIORA acima (micro-benchmark em 12 threads lógicas: 1 thread 4,7 s · 2: 3,0 · 4: 1,9 · 5: 1,8 ·
   6: 1,9–2,3 · 8: 4,6 · 12: 6,5 s), enquanto um laço aritmético puro escala até 12. Primeira tentativa sem limite e com prioridade baixa
   usou só 3 threads (o pool dá 30 % às de baixa); com prioridade alta e 12 threads ficou igual ao serial.
2. **Cache em disco** (`user://cache/fundo_do_mar_<chave>.bin`, zstd, ~9 MB, gravação atômica; só a grade mais recente fica). A chave
   muda com as placas das ilhas, o nível do mar, o relevo dos TERRENOS (dá a altura da praia), o tamanho da célula/bloco e o
   **código** do relevo; mexer em modelos, NPCs ou árvores NÃO a invalida. Arquivo de outra chave, truncado ou corrompido é
   ignorado e recalculado.

| fundo do mar | antes | depois |
|---|---|---|
| medir o relevo (1ª vez / terreno editado) | 10,0 s | 4,0 s |
| medir o relevo (com cache) | 10,0 s | 0,13 s |
| etapa inteira (inclui 1,1 s montando os blocos) | 11,2 s | 5,4 s (1ª vez) · 1,3 s (cache) |
| carga inteira do modo história | 18,9 s | 13,0 s (1ª vez) · 8,9 s (cache) |

O que sobra, em ordem: peças do mapa 5,6 s (320 modelos lidos do disco), blocos do fundo 1,1 s, relevo das ilhas 0,5 s.
**Próximos candidatos (não feitos):** ler os modelos em threads (`ResourceLoader.load_threaded_request`) e montar os blocos do fundo
(`_bloco`, malha + colisão) — esse último mexe com objetos de cena, então fica na thread principal.
`test_relevo_marinho` cobrava "montagem < 4 s": com cache passa; sem cache fica no limite (5,4 s na primeira vez).

## Carga por distância (29/10/2026) — `StreamingDeIlhas`

Pedido do dono: carregar o mínimo conforme a distância, só onde o jogador está vendo e jogando.

- **Unidade = a ilha.** Sempre carregado (barato): relevo em blocos de todas as ilhas, fundo do mar, oceano. Carregado só perto: peças (modelos, terreno, áreas de animais) e tudo que nasce delas (NPCs, inimigos, animais, pomar, coleta, navios).
- **Raios:** monta a 700 m da placa (aos poucos, 10 peças por quadro), descarrega a 950 m (histerese de 250 m). Barco pilotado veta a descarga (`pode_descarregar`).
- **Entrada:** só a ilha do spawn. Headless carrega tudo (`SOP_CARREGAR_TUDO` / `ModoHistoria.carregar_tudo_forcado`) para os testes de história.
- **Terreno liso das peças** nasce sem malha/colisão (`MapaMontador.sem_geometria_do_terreno`, só no jogo; o editor de mapa nunca liga), porque o relevo em blocos já o cobre.
- **`ir_a_ilha`** (F8, lançador de teste) monta a ilha de destino antes de teleportar.
- **Medido (cache quente):** carga 18,9 s → 9,46 s (tudo) → 5,18 s (streaming); memória 1700 → 1145 MB; nós 43 mil → 20,6 mil.
- **O que se perde ao descarregar:** só estado passageiro (inimigo ferido, fruta no chão, animal que andou). Progresso, missões, ouro e frutas estão no save.
- **Gatilhos para revisitar:** Ilha Inicial ainda custa 2,2 s (157 modelos) → dividir em chunks se passar de ~3 s; fundo do mar de todas as ilhas custa 1,2 s → gerar por ilha se passar de 2 s; hitch ao montar ilha em jogo > 50 ms/quadro → reduzir `PECAS_POR_QUADRO`.
- **Não verificado por mim:** a sensação de pop-in/engasgo ao navegar (precisa de jogada real).
