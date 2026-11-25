# Machado e madeira — 11/10/2026

Objetivo: assets anime low poly na loja; machado equipável com animação; árvore cai em 3 golpes, rende 5–7 madeiras e volta em 600 s; arbusto cai em 1 golpe; vida visível e inventário salvo.

Decisões: reutilizar executor/poses e inventário da história. Machado inicial guardado (como espada), sem custo inventado. Arbusto: provisoriamente 1 madeira e 600 s, pergunta enviada. Colheita só no servidor local, contato físico da cabeça do machado; sem alterar mapa autoral. Fontes de arte reproduzíveis em art_src/machado_madeira.

Estado na interrupção anterior: implementação em andamento, com integração e capturas ainda por validar.

## Retomada em 11/10/2026

O usuário confirmou a continuação desta tarefa. A implementação existente foi revisada e os sete testes selecionados passaram no Godot 4.6.3:

```sh
./validar.sh machado_madeira progressao espada_historia pomar_e_doma barra_de_itens
```

Essa seleção inclui barra de itens, espada, contato da espada, giro da espada, machado/madeira, pomar/doma e progressão. Resumo preservado em `art_src/validation/machado_madeira/testes_headless.log`.

### Comportamento entregue

- Machado inicial guardado: `N → ARMAS → Machado de lenhador → Equipar`. Clique esquerdo executa o corte; seleção e troca usam a barra de itens existente.
- Cabeça animada precisa tocar a vegetação. Árvore perde uma vida por golpe, cai no terceiro, desativa colisão e concede 5–7 madeiras. Arbusto cai no primeiro.
- Barra de vida aparece após o contato. Madeira aparece em `N → MATERIAIS`; quantidade e equipamento entram no autosave, com migração de saves antigos.
- Vegetação volta após 600 segundos de jogo. O estado temporário da vegetação não é persistido entre sessões.
- Árvore cortada deixa de produzir frutas até regenerar; frutas já caídas continuam disponíveis.
- Machado e tábuas constam da loja. Fontes `.blend` e gerador reproduzível em `art_src/machado_madeira/`, agora com README.

### Validação e limites

- Integração automatizada passou: três golpes, recompensa, ausência de recompensa repetida, salvamento, troca durante preparo, espada sem coletar, distância e parede bloqueando contato.
- Limite de regeneração exercitado com avanço controlado do relógio: ainda caída aos 599 s e restaurada aos 600 s. Pomar volta a produzir depois da restauração.
- Contato exercitado com árvore frutífera, carvalho, pinheiro, bétula e arbustos de dois tamanhos do catálogo.
- Captura gráfica em Forward+ na RTX 3050, usando Weston headless isolado do desktop. Revisadas preparação, contato, recuperação, vida e inventário. O teste aciona a entrada de combate por API; não equivale a playtest manual de teclado/mouse.
- O compositor sem ponteiro emite `pointed_win is null` quando o jogo tenta capturar o mouse, além de avisos de protocolos Wayland ausentes. Registrar como limitação da captura isolada; não declarar log gráfico sem erros.
- Corrigida a preparação do cenário de teste: suspender as frutas antes de afastar a árvore evita frutas flutuando na captura do inventário. Capturas agora criam a pasta de saída e verificam o resultado da gravação.
- Arbusto permanece provisoriamente com 1 madeira e regeneração em 600 s; a pergunta foi reapresentada na retomada, sem resposta até este registro. Não tratar como preferência confirmada.

Conclusão da retomada: repetição gráfica aprovada com **51/51 verificações**, incluindo oito capturas gravadas, saída 0 e nenhum `SCRIPT ERROR`/`Parse Error`. Log completo: `art_src/validation/machado_madeira/teste_visual.log`; avisos/erros do compositor descritos acima permanecem registrados. A nova captura do inventário foi inspecionada, sem frutas flutuando. Validação automatizada concluída; próximo passo opcional é o playtest manual no mapa do usuário.

Pedido seguinte (11/10/2026): a coleta virou a primeira missão do Guarda e os status ganharam reset total confirmado. Implementação e validação em `docs/MISSAO_MADEIRA_RESET_CHECKPOINT.md`.
