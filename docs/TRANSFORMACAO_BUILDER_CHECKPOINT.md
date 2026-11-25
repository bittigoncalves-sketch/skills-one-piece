# Transformação no Skills Builder — 07/10/2026

Pedido: usuário, inimigo e assets ao redor assumirem visual do asset selecionado.
Confirmado: somente visual; movimento, colisão e combate conservados. Término por
duração configurável. Implementado: bloco de timeline, alvo/raio, fumaça/luz
ou modelo da loja, prévia e runtime compartilhados, restauração e sobreposição.
Preservar alterações recentes de outras frentes (clipes, gelo, publicação na loja).
Snapshots na pasta irmã sop-snapshots/2026-10-07-transformacao-builder.

## Arquivos desta tarefa

- Novos `src/skills_builder/{transformacao_de_skill,visual_de_transformacao,seletor_transformacao}.gd`.
- Integração em `dados_skill.gd`, `SkillsBuilder.gd`, `timeline_skill.gd`, `arena_preview.gd`, `executor_de_skill.gd`.
- `src/world/mapa_montador.gd`: grupo `assets_transformaveis` só nas peças tipo modelo.
- Testes `tools/dev_tests/test_transformacao_{skill,builder_ui,historia}.gd`; contagem de seções atualizada no teste existente `test_skills_builder_ui.gd`.
- Instruções de uso e contexto em `docs/SKILLS_BUILDER.md`, `docs/SKILLS_BUILDER_NO_JOGO.md` e contexto de ferramentas.

## Validação concluída

- Contratos: **44/44** (JSON antigo/novo, seleção, colisão/dano, duração, cancelamento, sobreposição em ambas as ordens, morte, remoção do alvo, novo equipamento e prévia).
- Interface: **14/14 headless e com tela**, incluindo seleção real do barril no catálogo, undo/redo, salvar/reabrir. Seis PNGs renderizados e inspecionados.
- História: **19/19 headless** e **20/20 com tela** (teste ampliado com soco), publicação isolada → Kit do Builder → jogador/NPC/modelo reais; movimento por teclado, ataque, colisão, dano, restauração e mapa inalterado.
- Regressões dados, prévia, executor (**21/21**), UI e publicação (**20/20**) passaram, sem `SCRIPT ERROR` nos logs.
- Compilação geral mantém **6 falhas conhecidas** em `tools/anim_editor/studio/`; não há falha de instanciação nos scripts de transformação.
- Evidências: `art_src/validation/transformacao_builder_2026-10-07/`. Testes isolam saves e publicação em `/tmp`/`user://`; nenhum kit ou mapa pessoal foi publicado/substituído.
- Após ajuste da margem da timeline: UI existente novamente sem falhas; transformação **14/14 com tela** e captura conferida com rótulo completo.
- `python3 tools/contexto/indice.py verificar`: **ok**, com avisos de idade em outros contextos já existentes; diff check dos arquivos afetados sem erro.

## Limites e observações

- Entrega concluída. Rede PvP não foi testada nesta extensão.
- As seis falhas de compilação do estúdio separado permanecem, junto dos avisos de recursos ao encerrar esse teste geral.
- O teste de história registra aviso do catálogo de publicação ao tentar ler `frutas.json` como skill em `SkillsPublicadas.atribuidas`; pertence à integração de publicação em andamento e não impede equipar/usar os três efeitos. Não alterado nesta tarefa. Custos/recargas zero do kit de teste também geram avisos intencionais de perfil.
- Um aviso de modelo ausente em `contratos.log` é intencional: confirma que asset indisponível não deixa o alvo invisível.
