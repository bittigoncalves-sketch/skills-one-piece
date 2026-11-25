# Editor de janelas (05/10/2026)

Pedido do dono: no editor de mapa, ao lado de "Hitboxes", uma opção que troca o 3D pela
edição das **janelas** do jogo. Na faixa da loja (onde ficavam os itens 3D) aparece a
lista de janelas, e a janela escolhida se edita como num canvas.

Decisões do dono:
- muda **posição, tamanho, texto e aparência** (cor do texto, tamanho da fonte, cor de fundo);
- vale para as **janelas do Modo História**;
- fica salvo **no projeto**: vale para todo mundo que jogar esta versão.

## Como usar

1. No editor de mapa, botão **Janelas** na barra (ou tecla **J**). A loja e o painel da direita do 3D saem de cena.
2. Escolha a janela na lista da esquerda. Ela aparece no meio, numa tela de 1280×720 reduzida, montada com dados de exemplo.
3. **Clique** escolhe o elemento sob o cursor (o mais de dentro). Para os pequenos ou escondidos, use a **árvore** da direita.
4. **Arrastar** move o elemento. Se ele estiver dentro de uma lista, move o ancestral livre mais próximo; puxar a cabeça move a janela.
5. As **alças** brancas do elemento selecionado redimensionam. **Shift** encaixa de 8 em 8 px.
6. No painel da direita:
   - X, Y, largura, altura;
   - texto;
   - fonte (px);
   - cor do texto;
   - cor de fundo (painéis, botões e retângulos de cor);
   - **Restaurar elemento**, que esquece o que mudou nele.
7. **Salvar layout** (ou **Ctrl+S** no modo janelas) grava o arquivo. **J** volta ao 3D.

No modo janelas, os atalhos do 3D ficam desligados (Del, F, WASD…): editar um texto
não apaga peça do mapa.

## As janelas

Inventário (N) · Status (M) · Loja dos NPCs (E) · Barra de itens (1–6) · Menu de
técnicas · Vida e energia · Medidor da pesca · Menu de pets (B) · Ferramentas de teste (F8).

O medidor da pesca é desenhado em código (não tem elementos), então só a janela
inteira se move ou redimensiona.

## Como funciona

| peça | papel |
|---|---|
| `src/ui/layout_de_janelas.gd` | o arquivo (`res://mapas/janelas/layout.json`): só o que mudou, por janela e por elemento; `aplicar` põe no jogo |
| `src/ui/catalogo_de_janelas.gd` | a lista e a montagem de cada janela com dados de exemplo (como a `HistoriaHud` monta) |
| `src/ui/jogador_de_exemplo.gd` | o mínimo de "corpo" que as janelas de vida, técnicas e pets leem |
| `src/editor_mapa/editor_de_janelas.gd` | o modo janelas: lista, canvas, árvore e propriedades |
| cada janela (`ID_DO_LAYOUT`) | chama `LayoutDeJanelas.aplicar` depois de se posicionar e de refazer o conteúdo |

**Endereço dos elementos.** Um passo por nível, a partir da janela:
- com o **nome**, quando o elemento tem nome fixo;
- com **#n** (a posição entre os irmãos), quando foi criado sem nome. O Godot batiza esses de "@Label@123", com um número que muda a cada execução.

Linhas geradas por dados (pets, peixes, itens da loja) são endereçadas pela posição na
lista: a mudança vale para "a 2ª linha", seja qual for o item dela.

**Elemento dentro de lista** (container): a lista decide a posição. Arrastar move o
ancestral livre, e o tamanho vira o tamanho mínimo do elemento. O painel avisa.

O layout fica junto dos mapas e da loja, em `mapas/`, que entrou no git em 06/10/2026 (commit `9301956`).

## Testes

- `tools/dev_tests/test_editor_de_janelas.gd`: endereço, gravar/aplicar/salvar/reler,
  botão e J, atalhos do 3D desligados, as 9 janelas montam, tela 1280×720 reduzida,
  arrastar, alça, clique no elemento, texto/fonte/cores, restaurar, Ctrl+S, e a
  janela do jogo abrindo com o layout salvo (22).
- `tools/dev_tests/capturar_editor_de_janelas.gd`: fotos do modo janelas.

## Limites e gatilhos

- **Sem desfazer** (Ctrl+Z): o "Restaurar elemento" volta ao original. GATILHO: o dono pedir desfazer passo a passo → histórico próprio no editor de janelas.
- **Texto de linha gerada por dado:** a linha volta ao texto do dado a cada atualização; o layout aplica o editado logo depois (ele vale, mas some se o dado mudar a ordem). GATILHO: editar modelos de linha → um "estilo de linha" por lista, em vez de linha por posição.
- **Janelas da arena** não estão na lista (decisão do dono). GATILHO: pedir → uma entrada no catálogo e `ID_DO_LAYOUT` na janela.
