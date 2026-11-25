# Medição de visibilidade das skills das frutas do Modo História — 15/11/2026 (2ª passada)

**Método:** `tools/dev_tests/captura_visibilidade_frutas.gd` equipa cada fruta, fotografa a cena SEM a técnica (linha de base), aperta a tecla e fotografa em 3 instantes;
visibilidade = % de pixels que mudam (limiar de luminância 28/255) na área central (sem HUD), no melhor dos 3 quadros. Alvo parado a 8 m; câmera padrão.
**Limites:** mede presença visual, não qualidade nem fidelidade ao anime; sensível ao enquadramento; oscila ±1–2 pp entre rodadas (partículas aleatórias).
Jogador de teste com 4000 de energia, recargas zeradas por técnica; Flor de Buda medida na forma Buda; a escolha de gênero é automática em teste.

## Resumo (121 técnicas)

- média 18.5% · mediana 13.9%
- forte (≥15%): **51** (42%)
- legível (8–15%): **64** (53%)
- fraca (4–8%): **5** (4%)
- quase invisível (<4%): **1** (1%)

## Por técnica (da menos à mais visível)

| técnica | visibilidade | classe |
|---|---:|---|
| `mochi_mochi_N` | 2.2% | quase invisível (<4%) |
| `uta_uta_Z` | 5.4% | fraca (4–8%) |
| `kage_kage_X` | 7.2% | fraca (4–8%) |
| `ryu_ryu_pteranodon_Z` | 7.3% | fraca (4–8%) |
| `batto_batto_B` | 7.5% | fraca (4–8%) |
| `neko_neko_leopard_V` | 7.8% | fraca (4–8%) |
| `ryu_ryu_pachycephalosaurus_X` | 8.0% | legível (8–15%) |
| `imu_Z` | 8.1% | legível (8–15%) |
| `pika_pika_mine_piece_C` | 8.1% | legível (8–15%) |
| `mori_mori_X` | 8.2% | legível (8–15%) |
| `zushi_zushi_Z` | 8.2% | legível (8–15%) |
| `uo_uo_seiryu_X` | 8.4% | legível (8–15%) |
| `mero_mero_Z` | 8.5% | legível (8–15%) |
| `supa_supa_X` | 8.6% | legível (8–15%) |
| `inu_inu_wolf_X` | 8.7% | legível (8–15%) |
| `uta_uta_V` | 8.7% | legível (8–15%) |
| `mero_mero_V` | 8.8% | legível (8–15%) |
| `mochi_mochi_B` | 8.9% | legível (8–15%) |
| `ryu_ryu_brachiosaurus_C` | 9.1% | legível (8–15%) |
| `ryu_ryu_pachycephalosaurus_Z` | 9.2% | legível (8–15%) |
| `kage_kage_Z` | 9.3% | legível (8–15%) |
| `mochi_mochi_Z` | 9.4% | legível (8–15%) |
| `horo_horo_V` | 9.4% | legível (8–15%) |
| `kira_kira_X` | 9.4% | legível (8–15%) |
| `inu_inu_wolf_V` | 9.6% | legível (8–15%) |
| `neko_neko_sabertiger_C` | 9.7% | legível (8–15%) |
| `batto_batto_V` | 10.0% | legível (8–15%) |
| `inu_inu_wolf_Z` | 10.1% | legível (8–15%) |
| `kiro_kiro_Z` | 10.2% | legível (8–15%) |
| `hie_hie_mine_piece_Z` | 10.2% | legível (8–15%) |
| `moku_moku_mine_piece_V` | 10.5% | legível (8–15%) |
| `ushi_ushi_giraffe_Z` | 10.5% | legível (8–15%) |
| `neko_neko_sabertiger_X` | 10.7% | legível (8–15%) |
| `inu_inu_wolf_C` | 10.7% | legível (8–15%) |
| `inu_inu_okuchi_no_makami_X` | 10.8% | legível (8–15%) |
| `zushi_zushi_X` | 10.9% | legível (8–15%) |
| `riki_riki_X` | 11.0% | legível (8–15%) |
| `zushi_zushi_B` | 11.0% | legível (8–15%) |
| `inu_inu_okuchi_no_makami_C` | 11.2% | legível (8–15%) |
| `ryu_ryu_pachycephalosaurus_C` | 11.3% | legível (8–15%) |
| `batto_batto_Z` | 11.3% | legível (8–15%) |
| `uo_uo_seiryu_Z` | 11.4% | legível (8–15%) |
| `riki_riki_Z` | 11.5% | legível (8–15%) |
| `inu_inu_okuchi_no_makami_Z` | 11.5% | legível (8–15%) |
| `supa_supa_Z` | 11.6% | legível (8–15%) |
| `uta_uta_C` | 11.6% | legível (8–15%) |
| `neko_neko_sabertiger_Z` | 11.7% | legível (8–15%) |
| `pika_pika_mine_piece_V` | 11.8% | legível (8–15%) |
| `mero_mero_C` | 12.1% | legível (8–15%) |
| `mochi_mochi_C` | 12.4% | legível (8–15%) |
| `aro_aro_Z` | 12.4% | legível (8–15%) |
| `uta_uta_X` | 12.6% | legível (8–15%) |
| `kira_kira_Z` | 12.9% | legível (8–15%) |
| `neko_neko_leopard_Z` | 13.1% | legível (8–15%) |
| `kage_kage_V` | 13.2% | legível (8–15%) |
| `bisu_bisu_C` | 13.4% | legível (8–15%) |
| `inu_inu_wolf_B` | 13.4% | legível (8–15%) |
| `ryu_ryu_brachiosaurus_X` | 13.4% | legível (8–15%) |
| `mori_mori_Z` | 13.6% | legível (8–15%) |
| `riki_riki_C` | 13.7% | legível (8–15%) |
| `moku_moku_mine_piece_Z` | 13.9% | legível (8–15%) |
| `soru_soru_C` | 14.1% | legível (8–15%) |
| `hito_hito_daibutsu_C` | 14.2% | legível (8–15%) |
| `supa_supa_V` | 14.3% | legível (8–15%) |
| `supa_supa_C` | 14.6% | legível (8–15%) |
| `kiro_kiro_X` | 14.7% | legível (8–15%) |
| `bisu_bisu_Z` | 14.7% | legível (8–15%) |
| `batto_batto_C` | 14.7% | legível (8–15%) |
| `uo_uo_seiryu_C` | 14.8% | legível (8–15%) |
| `ryu_ryu_pteranodon_X` | 14.9% | legível (8–15%) |
| `mero_mero_X` | 15.7% | forte (≥15%) |
| `inu_inu_okuchi_no_makami_V` | 15.8% | forte (≥15%) |
| `ushi_ushi_giraffe_X` | 16.0% | forte (≥15%) |
| `hito_hito_daibutsu_Z` | 16.0% | forte (≥15%) |
| `neko_neko_leopard_X` | 16.2% | forte (≥15%) |
| `ryu_ryu_brachiosaurus_Z` | 16.3% | forte (≥15%) |
| `ryu_ryu_brachiosaurus_V` | 16.4% | forte (≥15%) |
| `nikyu_nikyu_mine_piece_Z` | 16.5% | forte (≥15%) |
| `horo_horo_X` | 16.6% | forte (≥15%) |
| `kage_kage_C` | 16.9% | forte (≥15%) |
| `soru_soru_Z` | 17.2% | forte (≥15%) |
| `batto_batto_X` | 17.4% | forte (≥15%) |
| `nikyu_nikyu_mine_piece_V` | 17.4% | forte (≥15%) |
| `ushi_ushi_giraffe_C` | 17.6% | forte (≥15%) |
| `neko_neko_leopard_C` | 17.7% | forte (≥15%) |
| `ope_ope_mine_piece_Z` | 17.7% | forte (≥15%) |
| `aro_aro_X` | 17.8% | forte (≥15%) |
| `zushi_zushi_C` | 18.4% | forte (≥15%) |
| `horo_horo_C` | 19.0% | forte (≥15%) |
| `mochi_mochi_V` | 19.8% | forte (≥15%) |
| `soru_soru_V` | 20.0% | forte (≥15%) |
| `neko_neko_leopard_B` | 20.2% | forte (≥15%) |
| `horo_horo_Z` | 21.1% | forte (≥15%) |
| `neko_neko_sabertiger_V` | 21.7% | forte (≥15%) |
| `hie_hie_mine_piece_X` | 21.7% | forte (≥15%) |
| `uo_uo_seiryu_B` | 22.6% | forte (≥15%) |
| `bisu_bisu_V` | 22.9% | forte (≥15%) |
| `hie_hie_mine_piece_C` | 22.9% | forte (≥15%) |
| `bisu_bisu_X` | 24.1% | forte (≥15%) |
| `hito_hito_daibutsu_V` | 24.5% | forte (≥15%) |
| `pika_pika_mine_piece_B` | 25.9% | forte (≥15%) |
| `soru_soru_B` | 26.1% | forte (≥15%) |
| `uo_uo_seiryu_V` | 26.4% | forte (≥15%) |
| `ushi_ushi_giraffe_V` | 30.3% | forte (≥15%) |
| `soru_soru_X` | 30.5% | forte (≥15%) |
| `hito_hito_daibutsu_B` | 31.2% | forte (≥15%) |
| `hito_hito_daibutsu_X` | 31.8% | forte (≥15%) |
| `bisu_bisu_B` | 32.3% | forte (≥15%) |
| `zushi_zushi_V` | 33.6% | forte (≥15%) |
| `mochi_mochi_X` | 34.4% | forte (≥15%) |
| `mori_mori_V` | 36.4% | forte (≥15%) |
| `moku_moku_mine_piece_C` | 42.1% | forte (≥15%) |
| `riki_riki_V` | 42.1% | forte (≥15%) |
| `kira_kira_C` | 42.4% | forte (≥15%) |
| `pika_pika_mine_piece_X` | 48.9% | forte (≥15%) |
| `hie_hie_mine_piece_V` | 54.3% | forte (≥15%) |
| `mori_mori_C` | 59.1% | forte (≥15%) |
| `moku_moku_mine_piece_X` | 62.4% | forte (≥15%) |
| `pika_pika_mine_piece_Z` | 69.1% | forte (≥15%) |
| `nikyu_nikyu_mine_piece_C` | 79.6% | forte (≥15%) |
| `nikyu_nikyu_mine_piece_X` | 81.5% | forte (≥15%) |

## Não medida
- `pika_pika_mine_piece_N`: a 6ª tecla da Pika nativa não é técnica com efeito (equipar a espada, nº 30) e o controlador é recriado: sem quadro.

## Evolução
- 1ª passada: 120 técnicas · média 17,7% · fortes 47 · legíveis 58 · fracas 15 · quase invisíveis 0.
- 2ª passada (assinaturas por tipo de golpe: chute, linha de tiro, pilar, aura): 10 das 14 técnicas que estavam <8% passaram de 8% (ex.: Giraffe X 6,2→16,0; Batto X 6,3→17,4; Leopard X 6,6→16,2; Kage C 7,6→16,9; Moku Z 5,2→13,9).
