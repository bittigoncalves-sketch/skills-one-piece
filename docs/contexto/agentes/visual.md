# Contexto (agentes) — Visual, VFX e áudio

> 21/09/2026 · versão para pessoas: [`../pessoas/visual.md`](../pessoas/visual.md) · arquivos e ★:
> [`INDICE.md#visual`](../INDICE.md#visual) · donos do detalhe: [`PLANO_VISUAL.md`](../../PLANO_VISUAL.md)
> (cel-shading anime, fases), [`guia/ASSETS_VISUAIS.md`](../../guia/ASSETS_VISUAIS.md),
> [`REVISAO_QUALIDADE_GRAFICA_2026-08-30.md`](../../REVISAO_QUALIDADE_GRAFICA_2026-08-30.md)

## Escopo

O estilo de render e o feedback de tela: materiais, contorno, efeitos de tela (vinheta, flash,
quebra), rastro de arma, fôlego, e o sistema de áudio de personagem (`src/audio/`). **Não** é daqui:
os VFX de cada fruta (`src/effects/`, contexto `frutas`) e a luz do mundo (`src/world/WorldEnv.gd`,
contexto `mundo` — mas é a Fase 1 do mesmo plano).

## Arquivos

| arquivo | papel |
|---|---|
| `src/fx/ScreenFX.gd` (autoload, ★5) | overlay 2D transparente de game feel: vinheta, flash |
| `src/fx/Materiais.gd` (★4, 0 testes) | a FÁBRICA de material (Fase 3): todo material novo sai daqui |
| `src/fx/Contorno.gd` | o nó do contorno (Fase 2); a linha grossa é a mesma do HUD (`Estilo`) |
| `src/fx/ScreenShatterFX.gd` (autoload) | quebra de tela dos impactos da Gura Gura |
| `src/fx/WeaponTrail3D.gd` | rastro de arma |
| `src/fx/shaders/` | shaders do estilo |
| `VFX/BreathVFX.gd` | fôlego ao correr |
| `src/audio/audio_manager.gd`, `sound_library.gd`, `audio_events.gd`, `components/` | áudio de personagem (passos, eventos) |

## Contratos e decisões

- **Alvo de estilo: cel-shading anime One Piece** (dono, 25/08); as seis fases do `PLANO_VISUAL.md`
  estão feitas. Referência de acabamento: padrão Ope (skill `design-padrao-ope`) — qualidade da
  Ope Ope no Mi com estética própria por criação; **sem** obrigação de low poly/voxel.
- **Sem soco de FOV** (decisão do dono, `camera_rig.gd`); tremor de câmera só na autoridade local.
- **VFX procedural** (`FxUtil`) e áudio procedural (`AudioFX`) são o padrão das frutas: não há
  pasta de texturas/sons de fruta.
- Todo nó de VFX criado tem que ser liberado (critério do `test_gomu_leak`).
- Qualidade escalável: `src/effects/FxQuality.gd` (`test_fx_quality`).

## Armadilhas

- `SHADING_MODE_UNSHADED` descarta a emissão.
- `set_glow_level()` é base ZERO.
- `Engine.time_scale` para "câmera lenta" desacelera o mundo inteiro e a física.
- Medir no espaço do mundo mente com escala não uniforme.

## Validar

`medir_qualidade_grafica`, `medir_visual_no_jogo`, `medir_contorno`, `captura_visual`,
`test_fx_quality`, `test_mobility_vfx`, `test_gomu_leak` (vazamento). Visual se aprova com captura
na câmera real + medição; sem captura, declare "não validado visualmente".

## Buscar

```bash
python3 tools/contexto/indice.py buscar "material cel contorno" --area visual
python3 tools/contexto/indice.py buscar "vinheta flash tela"
python3 tools/contexto/indice.py buscar "glow emissao unshaded" --docs
```
