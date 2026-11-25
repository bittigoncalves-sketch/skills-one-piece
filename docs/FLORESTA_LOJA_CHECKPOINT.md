# Floresta do editor com assets da loja — 08/10/2026

Pedido: refazer a floresta do editor usando os assets da loja.
Pergunta opcional enviada: preservar caminhos/área ou reorganizar. Sem resposta
até agora; adotado preservar caminhos e área, distribuindo árvores individuais
dentro da pegada dos aglomerados antigos.

Estado inicial: mapa vivo com 687 peças; grupo floresta tem 157, sendo 123
aglomerados trees/pine_trees. Loja contém Free Forest em categorias Árvores e
Floresta. Natureza já plantada em outro grupo será preservada, assim como
relevo, água, caminhos, coliseu, serraria, construções e demais grupos.

Backup identificado pelo hash em ../sop-snapshots/2026-10-08-floresta-loja;
cópia de trabalho/evidências em art_src/validation/floresta_loja_2026-10-08.
Não regenerar a ilha inteira. A substituição pontual foi validada em cópia antes
da aplicação ao mapa vivo, com guarda contra alterações concorrentes.

Etapa anterior (bestas) concluída e registrada em BESTAS_MAR_CHECKPOINT.md:
30/30 ciclo headless, 29/29 ciclo gráfico, 64/64 combate, assets e água OK.

## Concluído — 08/10/2026

Aplicado em `mapas/historia/baseplate.json`: 123 aglomerados substituídos por
676 peças (451 árvores e 225 arbustos/plantas rasteiras), 19 modelos da loja.
Total: 1240 peças. Todas as peças fora da substituição e os demais campos do
mapa foram comparados e preservados, incluindo grupos e nascimento do jogador.
SHA-256 final: `4b55ec61d324020342c7c604b5dd4802a37d78806404178c2a22bdaf15c8d4b1`.

Implementação em `tools/mapa_ilha/floresta_da_loja.gd`, comando em
`refazer_floresta.gd` e validação em `validar_floresta.gd` no mesmo diretório.
Distribuição determinística dentro da área antiga, consultando o relevo real,
com afastamento de caminhos, margens, água e obstáculos. Nova execução sobre o
resultado não adiciona outra floresta. `capturar_ilha.gd --floresta` permite
comparar as duas vistas da mata usando `--mapa` e `--saida`.

Validação:

- 17/17 verificações headless e 17/17 com o editor gráfico: catálogo, solo,
  colisão, seleção, mover/desfazer, salvar/reabrir, determinismo e preservação.
- Capturas antes/depois inspecionadas nas mesmas câmeras, além do editor com
  uma árvore nova selecionada. Evidências em
  `art_src/validation/floresta_loja_2026-10-08/`.
- Integração da ilha: nascimento, mapa e travessia das duas pontes passaram.
  Duas falhas de contato dos pés repetiram os mesmos valores no mapa anterior:
  afastamento na encosta de 0,104 m e pico ao correr de +0,073 m (média -0,004 m).
- Compilação geral mantém seis falhas em `tools/anim_editor/studio/`, fora desta
  alteração. O editor gráfico passou os contratos, mas registrou vazamento de
  texturas ao encerrar; esse aviso de encerramento permanece sem correção.

Medição curta das duas vistas em Forward+ na RTX 3050 Laptop: antes, montagem
2691 ms e quadro médio 8,7 ms; depois, montagem 2261 ms e quadro médio 7,1 ms.
Essas amostras não estabelecem desempenho geral do mapa.

Backup: `../sop-snapshots/2026-10-08-floresta-loja/baseplate_363d3dd285b4.json`.
`resultado.json` na pasta de evidências registra a aplicação e os hashes.
Sem etapa obrigatória restante para a substituição solicitada.
