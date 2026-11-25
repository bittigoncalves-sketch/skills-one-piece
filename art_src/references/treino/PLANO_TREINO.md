# Treino no campo — plano e diálogos

Estado: direção e critérios de implementação, 20/11/2026. O Claude é responsável por código e modelo 3D; os arquivos do projeto estão sendo alterados em paralelo. Esta pasta contém referências conceituais, não capturas do minigame.

## Pedido e decisões confirmadas em 20/11/2026

- Um NPC no campo inicia treino com câmera lateral; o jogador pressiona as teclas apresentadas dentro de um prazo, socando o boneco. O contato tem partículas, tremida, reação de dano e animação do boneco.
- Sai toda a cadeia que começava na vara: pesca, ferraria, facção, bandidos e a cadeia do guarda até a bússola. O treino é a única missão atual, concluída uma vez na primeira sessão com pelo menos um acerto; as sessões seguintes são repetíveis sem recriar a missão.
- Cada sessão tem seis comandos Z/X/C, com 1,2 s por comando. Z executa soco leve; X, pesado; C, rajada de três socos. Tecla errada ou tempo esgotado não produz soco naquele comando e o treino segue para o próximo.
- Quatro a seis acertos dão 500 XP; um a três dão 250 XP; zero dá 0 XP e não conta como treino. Ao atingir o nível 3 o instrutor recusa novas sessões; níveis 1 e 2 podem treinar.
- **Caso ainda a verificar:** save já no nível 3 ou acima antes de completar a missão; observar a experiência e definir uma saída com o usuário se impedir a conclusão desejada. Não inventar exceção.

## Contexto do projeto observado

O mapa `mapas/historia/baseplate.json` contém `centro_treino_voxel_1` e dois modelos `boneco_de_treino_voxel`. A cadeia antiga concedia itens e desbloqueios, inclusive bússola: testar o efeito da sua remoção em saves e sistemas existentes, sem presumir que retirar missão também retira a atividade ou o NPC. Segundo o checkpoint do Claude, a cadeia foi retirada e o instrutor usa o boneco voxel mais próximo.

`ProgressaoDoPersonagem.ganhar_xp` atualiza nível e emite mudança; `entregar_missao` também concede o XP configurado na tabela. A tabela atual configura XP da missão como zero e `RegrasDoTreino` paga a sessão conforme acertos, evitando duas fontes na primeira conclusão. Testar persistência e idempotência: reabrir diálogo, repetir sinal ou recarregar não pode pagar duas vezes.

## Fluxo proposto

1. **Encontrar e conversar:** missão inicial aponta para o treinador no campo. NPC apresenta a atividade e permite começar ou sair. Repetição usa o mesmo NPC, sem recriar a missão única.
2. **Preparar:** localizar um boneco utilizável e posicionar jogador e câmera lateral com ambos visíveis; explicar o comando e a janela de tempo antes de iniciar. Guardar câmera, movimento, entrada e HUD anteriores para restauração.
3. **Rodada:** exibir uma tecla por vez e uma barra de tempo clara; aceitar a tecla correta dentro da janela. Cada acerto produz gesto de soco e reação sincronizada do boneco. Mostrar retorno de acerto ou erro em texto/ícone, além da cor. Erro ou tempo esgotado avança ao próximo comando sem soco.
4. **Contato:** efeitos aparecem no boneco no instante do impacto: faíscas breves, reação de dano e balanço que volta à posição inicial. Tremida curta deve preservar leitura do alvo e dos comandos. Evitar dano real acidental ou destruição do boneco ao repetir.
5. **Resultado:** informar conclusão e XP apenas quando efetivamente concedidos. Na primeira conclusão, registrar uma missão entregue uma vez; nos treinos seguintes, conceder XP conforme as regras aprovadas, sem recriar o registro da missão. Conferir o nível novamente ao oferecer treino após a recompensa.
6. **Saída:** restaurar câmera, pose, entradas, foco de UI e estado do boneco ao concluir, cancelar, perder foco, morrer, trocar de cena ou carregar save. Conforme checkpoint, Esc cancela sem XP; conferir os demais casos em execução.

## Estados e textos sugeridos

Textos curtos em português, sem nome obrigatório para o personagem:

| Estado | Fala sugerida | Ações |
| --- | --- | --- |
| Primeira oferta | “Quer aprender a lutar? Treine comigo neste campo.” | “Treinar” / “Agora não” |
| Instrução | “Acerte a tecla indicada antes do tempo acabar. São seis comandos: Z é soco leve, X é pesado e C é uma sequência de três socos.” | “Começar” / “Voltar”; ajustar ao fluxo real. |
| Recompensa | “Com quatro ou mais acertos, você ganha 500 XP. De um a três, ganha 250 XP. Sem acertos, não ganha XP.” | Exibir antes do treino ou no detalhe da oferta, com quebra de linha se necessário. |
| Acerto | “Boa!” | Retorno curto, sem bloquear o próximo comando. |
| Erro ou tempo esgotado | “Errou!” / “Tempo!” | Avançar sem soco naquele comando. |
| Primeira conclusão | “Bom trabalho! Seu primeiro treino está completo.” | Exibir os acertos e o XP efetivamente concedido (250 ou 500). |
| Repetição permitida | “Vamos treinar mais uma vez?” | “Treinar” / “Agora não” |
| Conclusão repetida | “Mais um treino concluído. Continue assim!” | Exibir os acertos e o XP efetivamente concedido. |
| Nenhum acerto | “Desta vez não houve acertos. Tente novamente!” | 0 XP; não contar treino nem concluir missão. |
| Recusa por nível | “Sua força excede este campo. Não tenho mais o que lhe ensinar aqui.” | Recusar ao atingir nível 3. |
| Interrupção | “Quando estiver pronto, podemos tentar de novo.” | Não anunciar XP sem concessão. |

O texto da instrução deve acompanhar os controles reais e a regra de erro. Não apresentar 500 XP como garantidos: a recompensa depende dos acertos. Se um jogador já estiver acima do limite sem ter feito a missão, avaliar com o usuário a necessidade de migração.

## Referências visuais

- `01_treinador_frente_tres_quartos.png`: mesmo treinador em duas vistas; silhueta forte, colete índigo, faixas claras e faixa ocre. Adaptar ao rig e linguagem visual reais, sem exigir cópia literal da roupa ou proporção.
- `02_treinador_instruindo.png`: guarda e gesto apontando ao boneco. Boneco é conceitual; usar o elemento real do campo.
- `03_interface_minigame.png`: composição lateral, tecla, tempo e exemplos de acerto/erro. Z é um dos três comandos confirmados (Z/X/C); os dois indicadores são amostras, não precisam aparecer juntos. Não copiar cenário, adereços ou HUD da imagem como requisito.
- `04_impacto_e_reacao_boneco.png`: antecipação, contato e recuo/retorno. Partículas não significam destruir o boneco. Tremida só pode ser julgada em movimento.

As referências foram geradas pela ferramenta nativa de imagens; confirmação artística pertence ao usuário. Para a interface, manter comandos e alvo legíveis na resolução e câmera reais, em harmonia com a HUD já existente.

## Critérios de validação

1. **Missões e save:** campanha nova oferece treino primeiro; primeira missão fecha somente com pelo menos um acerto e só uma vez. Testar 0/1/3/4/6 acertos com 0/250/250/500/500 XP, repetição, ausência de pagamento duplo e salvar/reabrir. Testar saves com cadeia anterior disponível, aceita e entregue e recompensas já obtidas.
2. **Nível:** testar níveis 1 e 2 aceitos e nível 3 ou superior recusado, inclusive subida de nível causada pelo treino e jogador antigo já acima do limite com missão pendente.
3. **Entrada:** tecla correta, tecla errada, limite esgotado, pressão no limiar e repetição da mesma tecla; testar foco, pausa e tecla mantida. Erro/tempo avança sem soco; cancelar com Esc não paga XP, conforme checkpoint.
4. **Câmera e mundo:** cenário real do Modo História, boneco e jogador enquadrados lateralmente e sem bloqueio; movimento/controle apropriado durante o treino e restauração em todos os caminhos de saída. Testar ausência ou indisponibilidade do boneco sem travar o jogador.
5. **Feedback em execução:** vídeo/capturas sequenciais de acerto, erro, soco, partículas no ponto de contato, balanço e retorno, tremida e interface. Conferir câmera real, tamanho do alvo e nenhuma sobreposição importante. Aprovação visual humana é diferente de um teste headless.
6. **Integração:** testar no save e fluxo reais; verificar NPC, marcador, rastreador, HUD, interação com sistemas do campo, repetição, mudança de cena e, se aplicável, autoridade de rede. Reportar testes focados separadamente de regressão global e acesso por cliente remoto.
