# Luta — plano de gameplay e direção visual

Estado em 20/11/2026: referências conceituais prontas; implementação e validação em andamento com o Claude. O código é compartilhado e pode mudar durante este trabalho. As imagens foram geradas pela ferramenta nativa de imagens e são guias de forma e ritmo, não modelos 3D nem capturas do jogo.

## Resultado solicitado

- **Z — soco:** toque executa um golpe; segurar repete, mantendo o mesmo dano por soco. Soltar encerra a repetição.
- **X — soco carregado:** segurar aumenta o dano do golpe; demonstrar diferenças visuais progressivas de carga e um impacto legível.
- **C — metralhadora:** segurar prolonga a sequência com mais socos; inimigos apanhando dentro da barragem não reagem. O golpe final deve ter leitura distinta e liberar o alvo para o empurrão já previsto no projeto.
- **No ar:** golpes seguem a mira da câmera também em elevação e depressão; a direção visível, o volume de acerto e o empurrão devem ser coerentes.

Teto de carga/rajada, custos, cadência, raio e demais números não foram definidos nesta solicitação: preservar os contratos atuais ou discutir mudanças com o usuário. A decisão observada no código de manter a mira horizontal no chão não prova que o requisito exija isso.

## Referências visuais

| Arquivo | Uso proposto |
| --- | --- |
| `01_impacto_leve.png` | Contato compacto e breve, sem esconder punho ou adversário. |
| `02_pesado_tres_niveis.png` | Três intensidades para comparar a carga; o terceiro quadro mostra liberação/impacto, não uma exigência de dano em degraus. |
| `03_rajada_metralhadora.png` | Alternância de braços, punhos fantasma, rastros e contatos sucessivos. |
| `04_final_rajada.png` | Encerramento com um golpe mais claro e lançamento; não exige destruição do chão. |
| `05_combate_aereo.png` | Leitura de socos no ar para cima e para baixo. |

Paleta provisória branco e dourado para diferenciar força física e facilitar leitura. Priorizar silhueta do rig real e preservação do alvo na câmera de jogo; partículas, poses e roupas nas imagens são conceitos, não assets a copiar literalmente. Ajustar densidade para que a rajada não oculte o combate.

## Etapas e verificações

1. **Entrada e simulação:** no caminho real do item Luta, conferir Z/X/C no `controlador.gd`, ações de segurar/soltar e execução em `luta.gd`; comparar dano por contato do Z tocado e repetido, X sem carga e com tempos crescentes, contagem do C curto e longo. Incluir fim de energia, cancelamento e nova ativação. Código em edição concorrente: conferir estado atual antes de alterar.
2. **Alvos e estados:** testar NPC e jogador atingidos, múltiplos alvos e alvo que sai da área; nenhum deve reagir durante os contatos da barragem e todos devem recuperar comportamento no término ou cancelamento. Verificar que o final lança quem foi atingido e que outros efeitos de imobilização independentes não sejam removidos indevidamente. Examinar `imobilizacao_mine_piece.gd`, `DamageZone.gd`, `CombatResolver.gd` e `Balance.gd`.
3. **Mira e rede:** em voo ou salto, comparar direção da câmera, contato e empurrão em horizontal, diagonal e quase vertical para cima/baixo, incluindo obstáculos entre atacante e alvo. Exercitar jogador local e cliente remoto, com servidor autoritativo; verificar origem de mira e sincronização visual. No chão, preservar comportamento existente salvo decisão diferente do usuário.
4. **Modelagem e animação:** produzir e integrar os efeitos 3D seguindo as cinco referências. Testar preparação, contato e recuperação em movimento, alternância da rajada, transições da carga e desaparecimento de efeitos ao cancelar. Evitar depender do chão para o efeito aéreo.
5. **Validação:** executar os testes focados existentes `tools/dev_tests/test_luta_nativa.gd` e `tools/dev_tests/test_luta_empurrao_paralisia.gd`, acrescentando verificações somente para os novos comportamentos e rede quando necessário. Além dos testes estruturais, executar o Modo História com Luta equipada, registrar vídeo ou capturas de cada golpe e das duas direções aéreas, e avaliar legibilidade na câmera real. A aprovação artística depende de revisão visual; testes headless não a substituem.

## Riscos a investigar

- No estado lido, `ImobilizacaoMinePiece` é compartilhada com outras técnicas e a liberação do C procura alvos numa região ampla: confirmar que o final não retira imobilização de outra origem nem solta alvos que não receberam a rajada. Testar efeitos simultâneos e cancelamento.
- Conferir se a janela da imobilização cobre os intervalos entre socos e o fechamento da sequência, sem permitir reação indevida ou deixar alvos presos após a ação.
- O `looking_at` de direção quase vertical precisa de vetor auxiliar não paralelo; verificar também que colisão, direção de empurrão e efeito apontam para o mesmo lado.
- Os exemplos visuais exageram intensidade e proporções para leitura: a escala e o custo reais precisam ser avaliados no jogo, sem inferir desempenho a partir do PNG.
