# Medição de visibilidade — frutas da ARENA trazidas ao Modo História — 15/11/2026

**Método:** `tools/dev_tests/captura_skill_fruta.gd` (arena, `start_singleplayer`): apertar → SEGURAR → soltar pelo caminho real da tecla (V segura 1,5 s), câmera lateral a 8,5 m com FOV 80°, alvo a 7 m, quadro "antes" sem o golpe; visibilidade = % de pixels que mudam (luminância >28/255) na área central em 5 instantes (0,15–2,4 s).
**Limites:** UMA câmera para todas (golpe que acontece perto do corpo ou sobe/some rápido mede pouco; Entei, p.ex., aparece num quadro só); depende de alvo/arma/clique em alguns kits (Buki, Yami Z); `nikyu_nikyu` NÃO é fruta da arena (sem poderes). Oscila ±1–2 pp entre rodadas.

## Resumo (59 golpes, 16 frutas)

- média 12.4% · mediana 4.6%
- forte (≥15%): **14** (24%)
- legível (8–15%): **6** (10%)
- fraca (4–8%): **13** (22%)
- quase invisível (<4%): **26** (44%)

## Por golpe (do menos ao mais visível)

| golpe | visibilidade | classe |
|---|---:|---|
| `yami_yami_Z` | 0.5% | quase invisível (<4%) |
| `suke_suke_Z` | 0.8% | quase invisível (<4%) |
| `buki_buki_X` | 1.1% | quase invisível (<4%) |
| `rocket_V` | 1.2% | quase invisível (<4%) |
| `bara_bara_V` | 1.2% | quase invisível (<4%) |
| `rocket_Z` | 1.3% | quase invisível (<4%) |
| `bara_bara_X` | 1.7% | quase invisível (<4%) |
| `yami_yami_C` | 1.7% | quase invisível (<4%) |
| `yami_yami_X` | 1.9% | quase invisível (<4%) |
| `mera_mera_Z` | 1.9% | quase invisível (<4%) |
| `gomu_gomu_V` | 2.0% | quase invisível (<4%) |
| `buki_buki_V` | 2.1% | quase invisível (<4%) |
| `rocket_X` | 2.2% | quase invisível (<4%) |
| `buki_buki_Z` | 2.3% | quase invisível (<4%) |
| `bara_bara_Z` | 2.4% | quase invisível (<4%) |
| `buki_buki_C` | 2.6% | quase invisível (<4%) |
| `pika_pika_C` | 2.7% | quase invisível (<4%) |
| `bara_bara_C` | 2.7% | quase invisível (<4%) |
| `suna_suna_Z` | 2.8% | quase invisível (<4%) |
| `gomu_gomu_Z` | 2.8% | quase invisível (<4%) |
| `hie_hie_Z` | 3.0% | quase invisível (<4%) |
| `tori_tori_phoenix_V` | 3.3% | quase invisível (<4%) |
| `ope_ope_Z` | 3.7% | quase invisível (<4%) |
| `tori_tori_phoenix_X` | 3.9% | quase invisível (<4%) |
| `mera_mera_V` | 3.9% | quase invisível (<4%) |
| `ope_ope_X` | 4.0% | quase invisível (<4%) |
| `gomu_gomu_X` | 4.0% | fraca (4–8%) |
| `rocket_C` | 4.0% | fraca (4–8%) |
| `hie_hie_C` | 4.2% | fraca (4–8%) |
| `magu_magu_C` | 4.6% | fraca (4–8%) |
| `ope_ope_V` | 4.6% | fraca (4–8%) |
| `pika_pika_V` | 4.8% | fraca (4–8%) |
| `goro_goro_C` | 5.9% | fraca (4–8%) |
| `gomu_gomu_C` | 6.2% | fraca (4–8%) |
| `hie_hie_X` | 6.8% | fraca (4–8%) |
| `suna_suna_C` | 6.8% | fraca (4–8%) |
| `pika_pika_Z` | 7.6% | fraca (4–8%) |
| `tori_tori_phoenix_Z` | 7.7% | fraca (4–8%) |
| `ope_ope_C` | 7.9% | fraca (4–8%) |
| `mera_mera_C` | 9.2% | legível (8–15%) |
| `gura_gura_C` | 12.1% | legível (8–15%) |
| `tori_tori_phoenix_C` | 12.4% | legível (8–15%) |
| `pika_pika_X` | 13.1% | legível (8–15%) |
| `bomu_bomu_Z` | 14.1% | legível (8–15%) |
| `magu_magu_Z` | 14.5% | legível (8–15%) |
| `gura_gura_Z` | 16.9% | forte (≥15%) |
| `goro_goro_Z` | 18.3% | forte (≥15%) |
| `suna_suna_X` | 19.6% | forte (≥15%) |
| `gura_gura_V` | 21.2% | forte (≥15%) |
| `magu_magu_V` | 24.3% | forte (≥15%) |
| `hie_hie_V` | 30.2% | forte (≥15%) |
| `bomu_bomu_X` | 31.3% | forte (≥15%) |
| `yami_yami_V` | 32.0% | forte (≥15%) |
| `suna_suna_V` | 33.0% | forte (≥15%) |
| `gura_gura_X` | 43.3% | forte (≥15%) |
| `goro_goro_X` | 51.4% | forte (≥15%) |
| `goro_goro_V` | 59.7% | forte (≥15%) |
| `magu_magu_X` | 66.0% | forte (≥15%) |
| `mera_mera_X` | 75.4% | forte (≥15%) |

## Reforço aplicado depois da medição (anel de ativação, `Player._fire_skill`)
Anel da cor da fruta sob o jogador em todo golpe de fruta da arena. A/B nos 10 golpes mais fracos (mesma câmera): média 1,5% → 1,9%; 4 de 10 melhoraram (Buki X 1,1→2,7; Bara V 1,2→2,3; Gomu V 2,0→2,9; Rocket V 1,2→1,8) — efeito pequeno (anel fino no chão, câmera lateral baixa). `test_frutas`: vazamentos idênticos com e sem o anel (Bara 34 nós, Gomu 3) — anteriores.
