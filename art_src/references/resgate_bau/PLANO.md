# Resgate o baú — plano de missão e direção visual

21/11/2026. O Claude informou que integrou e testou a missão no mapa real, com golpe, drop, entrega e save/load; há capturas da missão em `art_src/validation/resgate_bau/`. O código e a engine são responsabilidade dele. `bau.json` fornece as falas, `texturas.json` contém grades 16×16 e os PNGs desta pasta são conceitos, não capturas do mapa.

## Pedido e contexto confirmado

Terceira missão após o desafio do Buggy: Barba Negra oferece a missão na vila; bússola guia até um baú que é mímico; **um ataque acertado** o derruba e produz o drop **Baú misterioso**; somente ao pegar o drop o jogador retorna ao Barba Negra e recebe **20 moedas + 700 XP + Ushi Ushi no Mi (Modelo Girafa)**. A posição registrada de `cidade_barba_negra` no mapa é (159, 3,9875, 20); o local do baú em (194, ?, 74) é indicação aproximada, distância horizontal ≈64 m. Descobrir a altura do solo em execução e validar local livre, acesso e superfície; não inventar coordenada Y.

O mesmo `npc_barba_negra` oferece serviços existentes (retirada de fruta, Geppo, dash e roleta): a nova missão não deve substituir ou quebrar a loja. `historia:bau_tesouros` já existe como item de inventário em outro fluxo. O item da missão é distinto: `historia:bau_misterioso`, com ícone próprio e limite 1. A captura `6_item_na_mochila.png` mostra o item na mochila.

### Condição de desbloqueio confirmada

O dono confirmou, conforme comunicado pelo Claude e registrado em `docs/RESGATE_DO_BAU.md`: a missão abre após o desafio dos copos em **qualquer resultado**, acerto ou erro. A luta `defender_a_vila` é opcional e futura, sem ser pré-requisito.

## Estados e falas

| Estado | Ação e bússola | Diálogo |
| --- | --- | --- |
| Bloqueada | Aguarda o encerramento do desafio dos copos, independentemente do resultado. Loja do NPC segue disponível; marcador de missão somente quando puder oferecer. | Sem oferta prematura. |
| Disponível | Procurar Barba Negra; `?` sinaliza a oferta. Aceitar explicitamente a missão, sem confundir com abrir a loja. | `oferta`; jogador pode aceitar/sair sem completar a missão. |
| Aceita / alvo ativo | Apontar bússola ao mímico na posição **atual** ou ao ponto seguro do objetivo; rastreador informa recuperar o baú. Aproximação revela a criatura. | `andamento` ao conversar com o NPC. |
| Revelado | Ao se aproximar de ~4 m, o baú abre a tampa; dentes e língua aparecem e ele salta/foge brevemente. Distância, corrida e tempos são sugestões, não mudança na condição de sucesso. | `mimico_revela` em aviso curto e não bloqueante; não impedir golpes nem mover o jogador. |
| Golpe acertado / drop no chão | Ao primeiro ataque válido recebido, revelar se necessário, registrar que o alvo foi atingido e gerar **um** drop; retorno do impacto com recuo/salto curto. A bússola acompanha o drop enquanto não coletado. | `mimico_atingido` curto; não confundir impacto com coleta. |
| Drop coletado / pronta para entrega | Somente após o item “Baú misterioso” entrar efetivamente na mochila, marcar objetivo pronto. Na implementação descrita pelo Claude, a bússola do baú some; o jogador retorna ao Barba Negra. | `pronta` no NPC antes/no momento de efetivar a entrega. |
| Entregue | Entregar uma vez e pagar 20 moedas + 700 XP + Ushi Ushi no Mi (Modelo Girafa) exatamente uma vez; conservar acesso aos serviços do NPC. | `concluida` em visitas seguintes. |

A fruta de recompensa é `ushi_ushi_giraffe`, disponibilizada em **N › FRUTAS** conforme implementação relatada pelo Claude. A fala que anuncia recompensa deve coincidir com a transação real; se a entrega não ocorrer, não anunciar pagamento como concluído. O dono confirmou, conforme comunicado pelo Claude: o drop entra na mochila e o item é consumido ao entregar; sem o item, não há pagamento.

## Apresentação e comportamento do mímico

1. **Disfarce:** baú de madeira com aro metálico e fecho simples, fechado e sem dentes aparentes. Referência `01_bau_disfarcado.png`.
2. **Revelação:** ao se aproximar, tampa gira como mandíbula e revela boca escura, dentes claros e língua rosada; criatura traquina, surpreendente, sem gore. `02_mimico_revelado.png`.
3. **Reação ao golpe:** um impacto claro com recuo, contato e resposta curta; não exigir uma segunda pancada, dano mínimo específico ou perseguição após um acerto válido. O primeiro ataque válido antes do raio de revelação também deve funcionar, sem travar a missão. `03_mimico_atingido.png`.
4. **Drop:** vira um pequeno baú fechado reconhecível e distinto do alvo ativo, visível no chão com brilho discreto; ícone de inventário de mesmo desenho. `04_drop_bau_misterioso.png`.

Qualquer salto/fuga é sugestão visual e deve permanecer dentro de área alcançável, sem atravessar solo/água, desaparecer ou manter hitbox em posição obsoleta. Usar o sistema real de combate e sinais do jogador, evitando ataques aliados ou ambiente contarem indevidamente sem uma regra explícita. Não tomar decisão de dano letal real do jogador nem de inimigo hostil permanente apenas por ele ter dentes; pedido é acertar uma vez.

## Grades de textura

`texturas.json` entrega uma paleta e quatro grades independentes de 16×16: `tampa_disfarce`, `corpo_disfarce`, `boca_revelada`, `icone_bau_misterioso`. Fundo do ícone é transparente. Tampas e corpo não revelam dentes antes da animação; boca é textura do interior e não pressupõe como a malha foi construída. Usar nearest e conferir orientação, UV, costura, e que a boca não apareça por fora. O brilho do drop é efeito visual separado. A grade de dados deve virar PNG via ferramenta do Claude, com procedência preservada; as imagens conceituais não são texturas de jogo.

## Persistência e casos essenciais

- **Desbloqueio:** testar saves com copos certos, copos errados, aceita/recusada a oferta e sem desafio; executar exatamente a decisão do dono quando chegar. A terceira missão não pode bloquear a loja ou a futura missão de nível 7.
- **Progressão:** interagir/aceitar; revelar; acertar; gerar drop único; coletar; voltar; entregar uma vez; sem XP, moedas ou fruta antes da entrega ao NPC. Ataques múltiplos no mesmo frame e reentrância não duplicam drop nem recompensa.
- **Save/cena/morte:** salvar e recarregar em missão aceita, criatura revelada, drop no chão, item coletado e concluída. Não restaurar um mímico e um drop válidos ao mesmo tempo, nem perder objetivo, pagar em duplicidade ou prender controles; validar troca de cena, morte/respawn e abandono de interação.
- **Coleta e inventário:** o Baú misterioso entra na mochila e é consumido ao entregar. O Claude informa testes de mochila cheia, entrega sem item e consumo; a captura mostra o item na mochila. A validação dos testes é relato dele, não execução repetida nesta revisão.
- **Bússola/objetivo:** alvo no mundo enquanto ativo; drop no chão após golpe; conferir retorno ao NPC após coleta; nenhuma seta pendurada após conclusão. O Claude documenta que a bússola do baú some ao coletar. Verificar rota e distância no mapa real.
- **Combate e visual:** um golpe válido do jogador, miss, ataque antes da revelação e golpes rápidos repetidos; captura em disfarce, revelação, impacto, drop e retorno ao NPC no Modo História real. Testes lógicos, screenshots e aprovação artística são evidências distintas.
- **Rede:** o desafio do Buggy atual é local ao progresso do jogador; não presumir que isso resolve autoridade da nova missão. Verificar comportamento quando aplicável e reportar separadamente se cliente remoto não for testado.

## Revisão das capturas de jogo — 21/11

Na primeira revisão, a tampa se movia para dentro do corpo e o drop aparecia roxo liso. O Claude corrigiu o sentido da rotação e associou os dentes superiores à tampa; também aplicou madeira ao drop e um ícone flutuante. Nas novas capturas `3_mimico_revelado.png`, `5_drop_bau_misterioso.png` e `6_item_na_mochila.png`, a boca aberta, os dentes, a textura do baú e o ícone na mochila são visíveis. A língua aparece parcialmente entre os dentes; movimento e apreciação artística final continuam sujeitos à avaliação do dono.

Segundo o Claude, os testes cobrem golpe real, mochila cheia, entrega sem item, consumo e save/load. O Claude relata também teste da entrega da Ushi Ushi no Mi uma vez. Esses resultados são relato do implementador; esta revisão conferiu as imagens e a estrutura de código, sem repetir os testes ou validar rede/coop. O aviso de outro baú mostrado nas capturas anteriores foi identificado por ele como evento concomitante.
