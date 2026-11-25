# Machado e bicicleta de gelo — 13/10/2026

Pedido: modificar animação do machado; uma árvore por vez, três vidas e restauração
ao afastar; bicicleta no F da Hie no modo história.

## Entrega

- Cada árvore mantém três vidas; cada golpe tira uma. Reserva central no machado
  impede dois alvos no mesmo golpe e mantém a árvore ferida até cair ou o jogador se
  afastar. A cabeça animada ainda precisa tocar, e paredes continuam bloqueando.
- Ao sair de 3,5 m do pé do tronco (horizontal ou vertical), vida parcial volta a 3.
  Parado perto, a vida permanece mesmo após ocultar a barra. Árvores derrubadas
  continuam com regeneração de 600 s, recompensa de 5–7 madeiras; arbustos com 1 vida.
- Golpe: preparo 0,42 s, fase ativa 0,22 s, recuperação 0,46 s, mão de apoio acompanha
  o cabo e aceleração na chegada ao contato. Fonte: `tools/gerar_pose_machado.gd`;
  recurso gerado: `src/combat/direcional/estilos/machado.tres`.
- Hie equipada: F monta/desmonta; WASD conduz, Shift acelera (10/15 m/s; aceleração
  12 m/s²). Terra e água; trilha visual por 2,5 s. Mantém colisor do jogador e acrescenta
  volume do veículo/ciclista. Verifica espaço ao montar. IK liga mãos/pés ao guidão e
  pedaleira, quadril ao selim. HUD mostra o F e o estado atual.
- Interrupções: troca de item/fruta, supressão, congelamento, dano com atordoamento,
  morte, arremesso e captura. Modelo, metadados e volume adicional são restaurados;
  cena remove rastro/visual. Integração na etapa de montarias existente, sem editar Player.

Suposições comunicadas, sem resposta adicional nesta sessão: F alterna em terra/água,
raio de restauração 3,5 m. Sem custo/recarga inventados. Campanha offline; não houve
pedido de replicação de bicicleta na arena ou rede.

## Arquivos

`src/historia/coleta/vegetacao_coletavel.gd`, `src/historia/equipamentos/machado_da_historia.gd`,
`tools/gerar_pose_machado.gd`, recurso `machado.tres`; novos controlador/visual
`src/historia/equipamentos/bicicleta_de_gelo*.gd`; integração em `ModoHistoria.gd`,
`HistoriaHud.gd`, `TecnicasHud.gd`, `ProceduralAnimator.gd`, `montaria_poses.gd`;
`test_machado_madeira.gd` e novo `test_bicicleta_de_gelo.gd`.

Alterações anteriores do workspace preservadas. Sem commit. Backups do machado e
logs/capturas desta tarefa: `art_src/validation/machado_bicicleta/`.

## Validação

Godot 4.6.3. Machado: **53/53 headless**, **61/61 gráfico**; três acertos, alvo único
com sensores sobrepostos, alvo mantido, espera perto >4 s, restauração ao afastar,
sem recompensa no reset, parede, troca durante preparo, espécies e missão.
Bicicleta final: **26/26 gráfico**, incluindo F pela HUD, terra, água, volume contra
parede, selim, troca de item, congelamento, cinco montagens/desmontagens, limpeza
após 2,5 s e saída da cena montado.

Regressão focada: passaram aparo da história, bicicleta, Hie V, Hie Z imunidade,
machado, missão de madeira/reset e nado/montaria. Duas falhas registradas:

- `test_compila`: seis scripts do projeto separado `tools/anim_editor/studio`, os
  mesmos já listados em PROJECT_CONTEXT; nenhum arquivo alterado desta tarefa.
- `test_hie_builder`: espera congelamento total de 0,7 s no Z; mediu 1,72 s. A regra
  de 10/10 estende o gelo entre salvas, documentada em PEDIDO_2026-10-10_HISTORIA.
  `test_hie_z_imunidade` e `test_hie_v_gelo` passaram; não alterado o Z para atender
  ao teste antigo.

`./validar.sh rapido` foi iniciado e interrompido após reprovar em múltiplas áreas
(água, arena sem dummy, balance e outras); log **parcial**, não é suíte completa.
Uma execução inicial de aparo foi contaminada por erro transitório de compilação
no alvo do pedal durante implementação; o tipo foi corrigido e aparo passou na
regressão focada. Não declarar toda a suíte verde.

Capturas reais em Forward+ / RTX 3050, Weston headless isolado. Sem SCRIPT ERROR ou
Parse Error nos logs gráficos finais. O compositor sem ponteiro emite `pointed_win
is null` e avisos de protocolos Wayland ausentes. Acionamento automatizado de F e
clique pela HUD/entrada e piloto de teste para movimento; não é playtest manual.

Estado: implementação e validação focada concluídas. Pendências externas acima;
próximo passo opcional é playtest manual no mapa autoral.

Importação final do editor concluída, UIDs dos scripts novos gerados; sem erros de
script no log de importação. `git diff --check` passou nos arquivos rastreados
selecionados. Verificação do índice terminou `ok`, com avisos de contextos antigos
já espalhados pelo projeto. Compositor isolado encerrado após as capturas.
