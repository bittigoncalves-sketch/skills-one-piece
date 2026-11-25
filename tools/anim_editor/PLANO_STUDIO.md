# Plano e critérios — Estúdio de animação

Pedido: usar o corpo atual e a Yoru reais, com manipulação simples, criação e
abertura de animações, loop e pontos editáveis na timeline. Planejamento e
implementação autorizados em 09/09/2026.

## Localização confirmada

`~/Área de trabalho/Editor de Animação.desktop` executa `tools/anim_editor/abrir.sh`.
O projeto está em `~/dev/skills-one-piece/tools/anim_editor`; não é um binário
fechado. A interface anterior é Python/Tkinter.

## Decisões

- Interface Godot independente, com renderização 3D das malhas originais. O
  lançador existente abre o estúdio; `--legacy` conserva a interface Python.
- Corpo: `assets/models/base_v2/base_v2_runtime.glb`, os mesmos 126 nós usados
  pelo jogo. Inventário em `rig_manifest.json`; sem reescrever esse arquivo.
- Espada: `assets/models/weapons/yoru_v2.glb`, presa em `Grip_R`, com seleção
  própria e transformação editável. A escala relativa respeita o jogador de
  1,5 m e a arma em metros, como no jogo.
- Dois espaços explícitos: **Animar** e **Ajustar corpo**. Mover/rotacionar/
  redimensionar no primeiro grava animação; no segundo altera a montagem.
  Pivô move a junta compensando seus filhos, preservando a pose visível.
- Arrastar eixos no 3D, campos numéricos com unidades, seleção de ossos pela
  malha ou árvore pesquisável, enquadrar seleção, vistas frente/lado/perspectiva.
- Desfazer/refazer, salvar sem caixa de confirmação, recuperação automática e
  proteção ao abandonar trabalho. Atalhos não atuam enquanto se digita texto.
- Pontos são poses completas: por padrão seguram a pose até o próximo ponto.
  A opção **Transição suave** interpola para o seguinte. Pontos podem ser
  selecionados, movidos, duplicados, renomeados e apagados. Tempos em quadros.
- Arquivo de trabalho versionado guarda montagem, poses, espada e marcadores.
  Clipes JSON antigos permanecem carregáveis, sem sobrescrever os originais.
- Exportação usa Animation com faixas de posição, rotação e escala e metadados
  de origem. Leitura dedicada no jogo evita interpretar posição como rotação,
  reconhece todos os ossos e restaura o estado ao terminar. Exportados autorais
  usam nomes próprios; colisões `.res`/`.tres` não podem selecionar o antigo.

## Ordem de implementação

1. Documento, amostragem temporal, persistência atômica, histórico e exportação.
2. Cena real com corpo, Yoru, seleção e ferramentas de transformação.
3. Interface e timeline; lançamento pelo atalho existente.
4. Integração de reprodução autoral, documentação e testes.

## Critérios de conclusão

- Abrir pelo lançador e encontrar corpo atual + Yoru prontos para editar.
- Mover braço e ver a espada acompanhá-lo; selecionar e ajustar a própria arma.
- Mover/rotacionar/redimensionar via campos e eixos; pivô não desloca a malha.
- Criar três poses, arrastar seus tempos, alternar transição, tocar com/sem loop.
- Desfazer um arraste em uma operação e recuperar uma sessão após reabertura.
- Salvar/reabrir sem perda, importar clipe antigo e exportar nova animação.
- Provar amostragem nas fronteiras dos pontos, loops, 126 ossos, montagem,
  arma, persistência e exportação; testar a janela e registrar limitações reais.

Este estágio cria a base de autoria de skills (poses e fases nomeadas). Dano,
hitboxes e eventos de combate precisam de um contrato próprio na próxima etapa;
não se deve confundir uma animação exportada com uma skill já ligada a uma tecla.

## Implementado e verificado

- Estúdio Godot isolado em `studio/`, aberto pelo lançador existente.
- Malhas originais, 126 articulações, Yoru e atalho de pose de guarda com duas mãos.
- Ferramentas em 3D e campos numéricos, montagem/pivô, árvore com busca e grupos.
- Pontos completos com hold/transição suave, arraste, nomes, cópia e exclusão.
- Loop ligado/desligado durante reprodução; histórico e salvamento atômico.
- Recuperação de sessão, abertura de todos os 33 clipes e exportação autoral.
- Leitor dedicado `StudioPlayback.gd`; restauração após prévia e precedência do
  arquivo autoral sobre um `.res` homônimo.
- Teste gráfico executado com Godot 4.6.3 / OpenGL na GPU local. Corpo e espada
  inteiros no enquadramento; controles de ponto colocados junto à timeline.
- Resultado final: 78 verificações na janela real, 14 verificações de reprodução
  no projeto do jogo, regressão `test_base_v2.gd` e testes Python legados passando.
- Comparação independente de transformações de mundo entre editor e jogo:
  maior diferença observada de aproximadamente `0.00000015`.

A guarda ajusta as duas mãos no momento em que o botão é usado; não há ainda
uma restrição contínua de IK que mantenha a mão esquerda presa durante qualquer
edição livre. Os controles permitem ajustar os dois braços e reaplicar a guarda.
