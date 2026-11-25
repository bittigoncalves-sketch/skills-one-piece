# Checkpoint — pacote de 18/11/2026 (baú de chefe, raid, economia, HUD, câmera)

Meta do dono (/goal): baú de chefe com fruta por força; raid obrigatória a cada 10 min; contador de ressurreição ao lado da vida e máximo 1; barras de fome/sede do tamanho de vida/energia à direita; limpar inventário (espadas e frutas dadas); preço de frutas a partir de 1000 por poder; tirar ícone de fome do Minecraft; mais alimentos e NPC vendedor; câmera dos barcos.

| Item | Onde | Teste (todos rodados em 18/11) |
|---|---|---|
| Baú de chefe | `src/historia/baus/baus_de_chefe.gd`, ganchos em `ModoHistoria.gd` | `test_bau_de_chefe` 31/31 |
| Raid obrigatória | `src/historia/raid/raid.gd` | `test_raid_obrigatoria` 15/15; `test_raid_mine_piece`, `test_raid_persistencia` ok |
| 1 ressurreição + contador | `reanimacao_do_coracao.gd`, `VidaEnergiaHud.gd` | `test_coracao` 43/43 |
| Fome/sede à direita, sem ícone | `SobrevivenciaHud.gd`, `hud_minecraft.gd` | `test_loja_frutas_precos` 289/289, `test_visual_minecraft`, `test_pao_e_barra_de_vida` |
| Limpeza do inventário | `itens_epic_fight.gd` (`limpar_concedidos`), `progressao.gd`, `serializacao_do_progresso.gd`, `ModoHistoria.gd` | `test_inventario_armas_ef` 15/15 |
| Preço por poder | `perfil_de_frutas.gd` (`PODER_DAS_FRUTAS`, `PRECO_POR_PODER`) | `test_loja_frutas_precos`, testes das frutas Mine Piece, `test_publicar_na_loja` (com `SOP_BUILDER=1`) |
| Alimentos + NPC | `provisoes.gd`, `loja_de_comida.gd`, `MenuDeComportamento.gd` | `test_alimentos_variados` 25/25, `test_alimentacao` |
| Câmera de barco | `camera_rig.gd`, `navios/comando.gd` | `test_camera_barcos` 23/23, `test_navios` ok |

## Validação visual (18/11, janela real 1280×720, RTX 3050)
Capturas conferidas: HUD com fome/sede à direita no tamanho de vida/energia, sem ícone de fome sobre a hotbar, contador "RESSURREIÇÃO 1/1" ao lado da vida (a contagem da raid foi movida para o topo porque cobria o contador); baú lendário com rótulo e brilho; câmera nos navios `small_ship` e `ship` mostrando o barco inteiro e o mar à frente.
`test_npcs_e_lojas` corrigido (nome do NPC no catálogo alinhado à ficha): 21/21.

## Decisões do dono (18/11, via pergunta)
- Armas do Epic Fight: saem dos baús de chefe (25% dos baús, poder pelo material; `baus_de_chefe.gd`, `ProgressaoDoPersonagem.receber_arma`). `test_bau_de_chefe` 36/36.
- "1 ressurreição" = 1 por janela de 30 min; limites de raridade, tabela de poder das frutas, fórmula da câmera e relógio da raid fora do save: mantidos como estão.
- Capturas reais dos 3 navios (`boat`, `small_ship`, `ship`) conferidas.
