# Skills Builder — 05/10/2026

Pedido: novo editor no menu principal, com identificação, configurações, ativação, timeline, hitboxes, dano/efeitos, movimento, projéteis, animação, VFX, áudio, câmera, condições e botão Rodar.

Decisões confirmadas: habilidades para jogador/inimigos/chefes; arena de teste dentro do editor com alvo e reinício.

Plano em execução:
1. Contrato JSON versionado e validado, salvamento atômico em user://skills_builder, sem execução de código vindo do arquivo.
2. Arena isolada em SubViewport, executando eventos da habilidade com alvo, dano, condições, movimentos e apresentação; pausável e reiniciável.
3. Interface de edição com biblioteca, todas as seções, propriedades e timeline arrastável. Salvar, abrir, duplicar, importar/exportar e desfazer/refazer.
4. Integração com menu/GameFlow, testes de dados/runtime/UI, validação visual na engine.

Divisão autorizada por docs/AGENTES.md: builder_dados cuida apenas do contrato/testes; builder_runtime da arena e execução; builder_timeline da timeline; agente principal faz editor, menu, integração e revisão.

Árvore tem alterações anteriores sem commit. Backup dos dois pontos existentes em art_src/validation/skills_builder/before. Não reverter alterações externas. Novo código isolado em src/skills_builder.

Validação pendente. Conhecido: compilação geral do projeto já aponta seis falhas no editor de animação separado em tools/anim_editor/studio; conferir antes de atribuir novas falhas à entrega.
