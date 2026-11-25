# Praia e oceano — 30/09/2026

Pedido: asset de areia low poly em `praia_mapa`; oceano azul claro perto das baseplates e azul escuro em mar aberto, com ondas e variação.

Implementado:
- Fonte Blender/script em `art_src/praia/` e `tools/blender/areia_praia.py`; exportação GLB na loja, categoria existente `praia_mapa`. 32 × 1,8 × 24 m, 550 triângulos, rampa e colisão da malha.
- `src/world/oceano_historia.gd` + `.gdshader`; integração em `ModoHistoria.gd` e `vista_mapa.gd`. Ondas/espuma/cores em coordenadas mundiais; recalcula ao editar/duplicar/remover baseplates.
- Documentação em `art_src/praia/LEIA-ME.md`, `docs/MODO_HISTORIA.md` e contexto de mundo. Validador `tools/validar_praia.py`; teste `test_praia_oceano.gd`; preview `tools/praia_preview.gd`.

Validação concluída:
- `python3 tools/validar_praia.py --capturar`: 14 contratos, captura GPU Forward+ sem erros de shader/script, mudança visível em 25,93% da amostra de mar entre T=0 e T=2.
- `./validar.sh praia_oceano modo_historia editor_mapa loja_modelos grupos_editor`: 5 testes passaram.
- SHA256 do mapa vivo preservado: `00945145d8779510e4f90eacac6c2d9f6d572a8f77cee315253ba90012df85eb`. Modelos/categorias anteriores preservados. Nenhum commit.
- Cinco imagens, animação WebP e logs em `art_src/validation/praia/`. As peças de areia das imagens são temporárias, sem gravação no mapa.
- Índice de contexto verificado; avisos de documentos antigos fora desta frente. `git diff --check` global aponta whitespace anterior em `GomuFX.gd`, não alterado nesta tarefa.

Bateria completa (`./validar.sh rapido`, log `/tmp/praia-bateria.log`, porta 24900, dados/config isolados, terminou 20:49): **101 passaram / 8 falharam / 5 pulados**. As 8 falhas são todas conhecidas e anteriores a esta frente (compila — 6 scripts do anim editor —, corte_horizontal, balance, bara_combat, mera_z_saque, ope_animacoes, studio_playback, trava_fruta_dano); nenhuma toca praia, oceano, loja ou editor de mapa.

## Fechamento — CONCLUÍDO (30/09/2026, 21h25)

Revalidado depois das mudanças do dia (pets B/N e `ModoHistoria.gd`):
- `./validar.sh praia_oceano modo_historia editor_mapa loja_modelos grupos_editor`: 5/5.
- **Defeito achado e corrigido:** 4 pontinhos pretos (3×3 px) sobre a areia em `03_areia_perto.png`. Causa: compressão de vértices da importação do Godot — cada uma das 5 cores é uma superfície quantizada pelo próprio AABB, e abriam fendas de submilímetro entre as cores. Provado em script descartável: 4 pontos com a malha importada, 4 sem LOD, **0** com a mesma malha sem compressão. Correção: `meshes/force_disable_compression=true` em `mapas/modelos/areia_praia_low_poly.glb.import` (550 triângulos: custo de memória desprezível). Registro completo em `docs/erros.md`.
- Novo contrato em `test_praia_oceano.gd`: a areia instanciada pela biblioteca não pode ter superfície comprimida. Comprovado que pega a regressão (religando a compressão o teste reprova; desligando, passa).
- `python3 tools/validar_praia.py --capturar`: 15 contratos PASS, captura PASS, mar 25,94% de pixels alterados em 2 s, **0** pontos escuros isolados nas 5 capturas, GLB da loja idêntico ao exportado, mapa vivo com o mesmo SHA256 `00945145…85eb`.
- Documentação ligada: `art_src/praia/LEIA-ME.md` (regra da importação) e `docs/MODO_HISTORIA.md` (seção da praia e link para `docs/PETS.md`). Nenhum commit.

Limites: água visual opaca, sem refração/natação/flutuação; costa retangular de até 64 bases horizontais (`baseplate`/`baseplate_*`, rotação Y). Espuma não analisa malhas arbitrárias. Não houve benchmark de FPS nem validação em celular/multiplayer.
