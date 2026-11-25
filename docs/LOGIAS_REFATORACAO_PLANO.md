# Logias do Modo História — plano de aceite

Atualizado em 24/11/2026. Escopo: Hie, Moku, Pika, Goro, Mera, Magu, Suna, Yami e Mori, uma fruta por vez. O pedido é retirar o efeito logia de transformação elemental e voo forçado, permitir técnicas em paralelo com recarga individual, disponibilizar cada fruta no inventário de teste e acrescentar sons por ataque, preservando a qualidade e a identidade do Mine Piece.

O [checkpoint](LOGIAS_REFATORACAO_CHECKPOINT.md) registra código e testes para as nove. Esses resultados são relato da implementação, não aprovação visual, sonora ou de jogabilidade; esta revisão não repetiu as baterias. As referências em `art_src/references/logias_codex/` são propostas visuais, não capturas nem prova de implementação. Documentos antigos de arena podem descrever golpes diferentes dos do Modo História.

## Como aceitar cada fruta

1. Entrar no Modo História com a build de desenvolvimento, abrir as ferramentas de teste com F8 e obter/equipar a fruta. Confirmar que aparece e que suas técnicas e entradas corretas estão acessíveis. Anotar versão, cenário, fruta e condições do teste.
2. Executar cada técnica, com e sem carga quando aplicável, em alvo próximo e distante. Conferir início, trajetória, impacto, efeito no alvo, fim e recarga própria. Seguir o mapeamento exibido na HUD: os controladores refatorados atribuem teclas diretas às técnicas disponíveis, e algumas dependem de condições específicas.
3. Iniciar uma técnica duradoura ou carregada e acionar outra antes da primeira terminar, com energia suficiente e corpo livre. Repetir com a ordem invertida e mais de duas quando possível. A primeira deve continuar e concluir corretamente; a recarga de uma não deve bloquear a outra. Conferir dano, carga e alvo de projéteis que permanecem após o início de outra técnica, especialmente nas cinco frutas do fluxo do mod: o checkpoint registra risco de leitura do estado da técnica mais recente.
4. Verificar ausência da transformação elemental automática e do voo forçado em repouso, carga, ataque e término. Não confundir uma técnica específica de deslocamento, arma ou passiva com a transformação logia. Julgar se a lentidão de carga preservada está confortável; se não estiver, registrar técnica e condição para decisão.
5. Ouvir cada ataque isolado e combinado, incluindo carga, disparo, impacto e final quando existirem. O dono decide clareza, identidade, volume, equilíbrio e repetição. Medição de espectro/clipping não substitui escuta.
6. Observar em terceira pessoa, perto e à distância, contra cenários claros e escuros: silhueta, cor, material, direção, escala, contato e limite da área devem ser legíveis sem ocultar alvo ou jogador. Comparar com a referência e o funcionamento efetivo. Registrar captura/vídeo, cenário e opinião do dono; referência não obriga alterar mecânica.
7. Verificar término e limpeza após conclusão, troca de fruta/item, morte e respawn; testar rede quando o fluxo permitir. Reproduzir qualquer falha com passos, teclas e evidência. Anotar desempenho quando efeitos simultâneos tornarem a cena lenta; investigar por medição antes de reduzir detalhe.

Para cada fruta registrar: **teste automatizado** (comando, resultado e data), **integração/playtest**, **avaliação visual**, **avaliação sonora**, **aprovação do dono** e pendências. Só marcar aceita após os itens aplicáveis passarem e o dono aprovar som e visual. Falha fora do escopo não deve ser confundida com sucesso global.

## Ordem de playtest e foco

| Ordem | Fruta | Conferência específica além dos critérios comuns |
|---|---|---|
| 1 | Hie Hie | Partisan e disparo para trás com Shift; Pheasant Beak; frente linear da Ice Ball; expansão e cristais da Ice Age; congelamento e sobreposição de projéteis. |
| 2 | Moku Moku | White Fist, White Vine, White Launcher e White Out; leitura de punho, funil, investida e área em fumaça sobreposta. |
| 3 | Pika Pika | Laser, Amano-Iwato, técnicas Yasakani, chute e espada; toque duplo; brilho não deve esconder alvo; ouvir sons sem presumir aprovação pela medição de graves. |
| 4 | Goro Goro | Vari, El Thor (incluindo Shift), Sango, Mamaragan e Raigo sob a condição da tempestade; aparo e toque duplo; relâmpagos reconhecíveis durante sobreposição. |
| 5 | Mera Mera | Percorrer todas as técnicas apresentadas pela HUD do fluxo do mod; distinguir fogo, disparos, impacto e área, inclusive projéteis persistentes. |
| 6 | Magu Magu | Percorrer técnicas da HUD do fluxo do mod; distinguir magma quente, silhueta dos projéteis e impacto, verificando persistência ao trocar de técnica. |
| 7 | Suna Suna | Percorrer técnicas da HUD; conferir leitura de areia, nuvem e área e a manutenção de efeitos persistentes durante outra técnica. |
| 8 | Yami Yami | Percorrer técnicas da HUD; conferir contorno e direção dos efeitos escuros contra cenário escuro, além de captura/liberação quando aplicáveis. |
| 9 | Mori Mori | Tree Strike, Giant Tree, Assault Attack e I'll Skewer You; raízes, árvores e perfuração devem ter silhuetas e contato legíveis. |

## Evidência técnica registrada no checkpoint

Hie: `test_hie_paralelo` 39 e `test_hie_mine_piece` 45; Moku: `test_moku_mine_piece` 27; Pika: `test_pika_mine_piece` 36; Goro: `test_goro_mine_piece` 64; Mera/Magu/Suna/Yami/Mori: `test_logias_do_mod_paralelas` 40/40. O checkpoint também registra `test_logias_refatoradas` 29/29 e regressões focadas. São contagens reportadas, não execução nesta revisão, nem evidência de aprovação humana ou regressão global.
