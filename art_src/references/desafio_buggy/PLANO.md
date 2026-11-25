# Desafio do Buggy — storyboard e direção visual

21/11/2026. Direção e imagens conceituais para a fatia atual; o código, os atores, o movimento e os modelos finais são do Claude. As imagens não são capturas do mundo real nem evidência de integração. Pedido e regras: `docs/DESAFIO_DO_BUGGY_PLANO.md`; legendas: `data/dialogos/buggy.json`.

## Contexto confirmado e limites

A cutscene ocorre no mundo da vila após a conclusão da primeira missão de treino. O mapa contém `docks_1` em (221,9; 5,8; 14,5), e `dock_long_1`, `dock_wide_1`, `dock_long_no_rope_1` em x≈268,8 e z≈10, 40 e 75. As posições são origens das peças, **não** provam altitude do piso, direção do mar, espaço navegável ou ponto seguro de desembarque. A posição das câmeras, o alinhamento do navio e o acesso devem ser escolhidos e testados no mundo real; não atravessar terra nem fazer piratas flutuarem ou desembarcarem sobre água.

O catálogo e os GLBs em `mapas/modelos/` já incluem `mp_buggy`, `mp_cabaji`, `mp_richie`, `mpe_ship_pirate_mini_1` e `mp_pirate_pirate4`, `mp_pirate_pirate5`, `mp_pirate_pirate6`. Existem instâncias dos primeiros seis personagens em Orange Town, x≈3146–3153, longe da vila. Criar atores locais próprios sem deslocar ou apagar os da outra ilha; validar escala, orientação, rig e animações efetivas antes de assumir que podem andar ou posar. A existência do GLB não comprova animação de desembarque, rig nem adequação visual. O navio é candidato visual, não confirmação de que suas dimensões ou aparência atendem à cena.

## Storyboard da chegada

Tarjas e legenda cinematográfica do sistema existente. Tempos abaixo são **sugestões** para uma cena de aproximadamente 17 s, sem limitar a leitura da fala: se o motor exigir avanço manual para legenda, a duração do plano 4 é mínima e aguarda a leitura/avanço; Esc pula de qualquer plano e aplica exatamente o mesmo estado final. Sem falas automáticas extras. Sons são direções opcionais, não recursos já existentes.

| Plano | Duração | Enquadramento e ação | Som / legenda |
| --- | --- | --- | --- |
| 01 | 4 s | Plano geral do cais, câmera sobre terra voltada ao mar: o navio pirata aparece e se aproxima; vila e madeira do cais estabelecem onde a ação acontece. | Ondas e madeira se disponíveis. Sem legenda. `01_chegada_navio.png`. |
| 02 | 4 s | Plano médio geral lateral, navio reduz a marcha e atraca junto ao cais; mostrar acesso entre bordo e madeira, com tripulação visível. | Água / rangido opcionais. Sem legenda. `02_atracacao.png`. |
| 03 | 5 s | Câmera baixa no cais, em três quartos: Buggy desembarca, seguido por Cabaji, Richie e dois piratas. Escalonar trajetórias e guardar distância; Richie continua quadrúpede. | Passos opcionais. Sem legenda. `03_desembarque.png`. |
| 04 | 4 s mínimo | Plano médio geral frontal: Buggy toma a dianteira, seus companheiros se alinham atrás e o navio permanece reconhecível. Enquadre sem esconder a legenda. | `Buggy`: “Atenção, vila! O grande Capitão Buggy chegou!” (`chegada[0]`). `04_buggy_no_cais.png`. |

Ao terminar ou pular: navio atracado e atores no mesmo estado final, restauração de câmera/controles/HUD, missão apontando ao cais e plateia acionada uma única vez conforme implementação. Os moradores correm **após** a cena; não misturar essa corrida ao desembarque. A chegada não concede XP nem resolve o jogo dos copos.

## Tripulação: ficha e lacunas

Ver `05_ficha_tripulacao.png` para intenção visual; a fonte da verdade dos personagens já existentes é o modelo do projeto, não a imagem gerada. Os humanos seguem corpo quadrado Minecraft; Richie é um leão quadrúpede blocado, não um humano. Manter escala coerente com jogador e silhueta legível na câmera.

| Integrante | Base disponível | Traços para leitura e trabalho a verificar |
| --- | --- | --- |
| Buggy | `mp_buggy.glb` | Capitão, nariz vermelho e cabelo azul; atitude teatral; verificar roupa, escala e pose reais. |
| Cabaji | `mp_cabaji.glb` | Silhueta mais estreita e espada/acessórios do modelo; verificar se espada e rig fazem parte do asset. |
| Richie | `mp_richie.glb` | Leão quadrúpede com juba; verificar apoios no chão, comprimento e movimento. |
| Pirata A / B | `mp_pirate_pirate4.glb` / `mp_pirate_pirate5.glb` | Dois tripulantes distintos; modelo 6 existe como alternativa. Verificar aparência e possibilidade de animação. |

Faltas ainda não comprovadas: atores locais, sequências de atracação, rampa/passagem, movimento de desembarque, arranjo e poses, animações utilizáveis, ajuste de escala e o navio visualmente apropriado. Não afirmar que faltam novos modelos: pode ser possível usar os existentes. Visual final depende de capturas de jogo e apreciação humana.

## Copos e pedra

Ver `06_copos_e_pedra.png` como estudo, não asset 3D. Três copos opacos idênticos em forma, cor, tamanho e material, em linha e separados o bastante para seleção inequívoca; madeira escura com aro discreto é sugestão. Pedra pequena, cinza e distinta da mesa. Mostrar a pedra sendo coberta antes de embaralhar; durante o embaralhamento ela fica oculta e acompanha logicamente o copo correto. Copos e pedra devem ser legíveis ao nível da câmera e com mira ou clique; seleção única aponta ao objeto clicado/visado, não a uma ordem alterada da lista. Não revelar a pedra antes da escolha nem diferenciar visualmente o copo vencedor. A imagem gerada é sugestão e não comprova mecanismo nem justiça do embaralhamento.

## Moradores da vila

Ver `FICHA_MORADORES.md`. Para moradores abrangidos pelo pedido: corpo quadrado com a mesma altura do jogador, tom e cabelo distinguíveis e cores de `capa`/`calca` por tipo. Preservar as cores existentes quando possível. O instrutor mantém a exceção de 1,13× registrada; não converter indiscriminadamente personagens especiais, animais ou NPCs de outras ilhas como se fossem moradores genéricos da vila.

## Regras, persistência e verificação

- Uma tentativa nos copos. Acerto encerra a missão e paga 4000 XP uma só vez; salvar/carregar ou repetir sinais não multiplica o prêmio. Erro não concede esse prêmio nem cria automaticamente a missão de luta.
- Em `erro_n7`, expor escolhas separadas **Proteger a vila** / **Recusar**. Aceitar cria a missão de retorno para luta, bloqueada até nível 7; recusar não a cria. Não prometer luta jogável nesta fatia: o encontro é posterior. Não definir o que acontece com uma eventual reconsideração da recusa sem decisão do dono.
- Confirmar o estado final ao pular em cada plano, replay de save, ausência/remoção de NPC e troca de cena; sem câmera ou controles presos. A execução é local ao jogador conforme o plano do Claude; não presumir sincronização cooperativa.
- Após a cena, validar bússola, posição de destino e plateia no mapa real, trajetos por solo sem atravessar água/obstáculos, ausência de duplicação de atores. Para os copos, cobrir embaralhamento com semente fixa, seleção, um único resultado, reload e XP idempotente.
- Capturar cada plano em jogo, conferindo visibilidade de personagens, acesso ao cais, tarjas e legenda; comparar com estes PNGs conceituais. Teste estrutural e captura visual são evidências diferentes; aprovação artística segue pendente.

## Referências geradas

As imagens são conceitos produzidos com ferramenta nativa de geração de imagem a partir do storyboard, não representam geometria/posições fiéis do mapa. O texto acima prevalece sobre eventuais erros dos conceitos, especialmente número de copos, fisionomia e tripulação. Os prompts e a revisão ficam em `PROMPTS.md`.
