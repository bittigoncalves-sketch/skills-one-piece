Objetivo: entrada do Modo História em toda visita, personagem 3D frontal à direita, Jogar verde e Customizar vermelho à esquerda.
Decisão: Customizar reaproveita sexo/tons existentes; concluir volta à prévia; Jogar persiste e inicia a campanha; cancelar/voltar não altera o save. Campanha nova exige escolher sexo antes de jogar.
Arquivos: entrada_historia.gd (novo), escolha_corpo_historia.gd (configuração do editor), ModoHistoria.gd (entrada em toda visita e rollback de save).
Concluído: testes adaptados à entrada em toda visita, com confirmação em Jogar; controle de rotação/base na prévia compartilhada; luz frontal e cores preservadas após normalização da GUI.
Correção pontual: InventarioDaHistoria.embutir agora aguarda os controles de _ready antes de aplicar o modo embutido; erro observado ao iniciar a campanha na integração.
Validação: entrada 30/30 Forward+ com capturas; corpo 168/168 headless; seletor 28/28; política automatizada 4/4. Sem erros de script ou asserções falhando nos logs finais. Logs/capturas em art_src/validation/entrada_historia.
Limitações: animação idle no teste de respawn, recursos/objetos ainda em uso no encerramento; sem regressão global nem aprovação artística do usuário. Personalização desta entrega abrange sexo e tom de pele.
Próximo passo: revisão visual pelo usuário; nenhuma implementação pendente neste escopo.
