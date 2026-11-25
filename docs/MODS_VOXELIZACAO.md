# Regra permanente: arte de mod entra VOXELIZADA (decisão do dono, 2026-11-10)

**Em qualquer mod encontrado/importado (Epic Fight, Mine Piece, armas e armaduras do Minecraft, e os próximos), toda a arte é
transformada para o estilo de arte VOXEL do jogo** — modelos, itens, armas, armaduras, partículas e texturas. Não se usa a malha
suave/original do mod como visual final.

- **Dados** (tempos, dano, atordoamento, custos) entram como estão; **arte** passa pela voxelização.
- Item 2D do Minecraft (sprite 16×16) → extrusão em voxels (um voxel por pixel opaco, espessura 1–2). Modelo `.json` de blocos → cubos
  reaproveitados; malha livre → voxelização por amostragem de grade (tamanho de voxel do projeto: ver `docs/ESTILO_VOXEL*` / `TreeAndFruitGenerator`).
- Exceção só com decisão explícita do dono, por item.
- Assets de mod continuam **locais e fora do git** (licença); o conversor e os testes vão ao git.
- Status por mod: Epic Fight — dados e animações convertidos; **arte (armas/armaduras) ainda a voxelizar** (ver `docs/CHECKPOINT_EPIC_FIGHT.md`).

## Status 18/11/2026 — texturas dos inimigos
- **Personagens `mp_*`**: 212 texturas de 128–512 px (e sprites de 321/348 px) reduzidas para a grade voxel (64 px; sprites 32 px) por `tools/mine_piece/voxelizar_texturas.py`
  (BOX + 40 cores + alfa seco; originais em `build/mine_piece/texturas_originais/`, `--restaurar` desfaz). Teste: `tools/dev_tests/test_texturas_voxel.gd`.
  Custo conhecido: rostos de chefes muito detalhados (Higuma, Alvida) ficam mais simples. GATILHO: se o dono quiser mais detalhe, rodar com alvo 128.
- **Animais**: já tinham malha voxel (`*.voxel.scn`). **Bestas do mar** (serpente, javali, bovina, girafa): voxelizadas com `tools/voxelizar_animais.gd -- <ids>`.
- Folha de contato para auditoria visual: `tools/dev_tests/folha_de_modelos.gd`.
