# Sequência de socos — 07/10/2026

Pedido: variar os socos por cliques dentro de um intervalo. Escolha explícita do
usuário: cada novo clique avança para outro soco; não disparar vários por um clique.

Implementado: jab → gancho direito → esquerdo → overhand, usando as quatro poses
existentes. Janela inicial de 1,2 s após terminar o golpe, ajustável na ficha.
Gestos explícitos continuam direcionais. Preparo não finta por clique neutro;
buffer existente guarda um golpe e não avança o índice antes de começar. Defesa,
interrupção, menu, suspensão e mudança de estilo reiniciam. Fonte dos números,
dano, varredura e recuperação do executor preservados.

Arquivos: `src/combat/direcional/entrada_corpo_a_corpo.gd`,
`src/combat/direcional/estilo_corpo_a_corpo.gd`,
`src/combat/direcional/estilos/boxe.tres`. Teste novo:
`tools/dev_tests/test_sequencia_socos.gd`; teste gráfico ampliado:
`tools/dev_tests/test_combate_historia_tela.gd`.

Concluído. Validação em Godot 4.6.3, com saves isolados:
- **58/58 contratos** em relógios de 30/60/144 Hz, incluindo controle que desativa
  a sequência e reproduz o jab repetido; teste sem erros/avisos.
- **24/24 verificações com tela**: cliques pelo Player, quatro golpes, captura no
  contato de cada um, reinício, gesto, menu e guarda. Log final X11 sem erros/avisos.
- Oito imagens conferidas: quatro na câmera de jogo e quatro em câmera de detalhe,
  mostrando as poses existentes agora acessíveis por cliques sucessivos.
- Regressões: executor 106, leitura de entrada 21, poses 24, contato 41, defesa 22,
  aparo 19 e espada 30 verificações aprovadas. Logs finais sem erros/avisos.
- A montagem nula, usada para testar a classificação pura de gestos, revelou um
  acesso a sinal sem executor; corrigido e os testes de entrada/sequência repetidos.
- `test_compila` mantém os seis scripts do studio já documentados como débito,
  além do ruído de autoloads/recursos ao sair. Não houve compilação geral limpa.

O valor de 1,2 s é a escolha inicial informada ao usuário, ainda sujeito a ajuste
pelo seu playtest. A bateria geral completa não foi repetida nesta tarefa; foram
executados o teste de compilação e as regressões dos sistemas afetados.
Evidências: `art_src/validation/sequencia_socos_2026-10-07/`.
Snapshot anterior em pasta irmã sop-snapshots/2026-10-07-sequencia-socos.
Nenhuma etapa obrigatória do comportamento pedido ficou pendente. Sem commits.
