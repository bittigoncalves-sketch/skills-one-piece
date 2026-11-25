# Contexto (agentes) — Frutas e técnicas

> 21/09/2026 · versão para pessoas: [`../pessoas/frutas.md`](../pessoas/frutas.md) · arquivos e ★:
> [`INDICE.md#frutas`](../INDICE.md#frutas) · dono do detalhe: [`frutas/README.md`](../../frutas/README.md)
> (uma página por fruta — o estado de HOJE, lido no código) · planos: `PLANO_FRUTAS.md`,
> `PLANO_MERA_MERA.md`, `PLANO_BARA_BARA.md`, `AUDITORIA_FRUTAS.md`

## Escopo

As Akuma no Mi: definição das técnicas Z/X/C/V, efeitos (`src/effects/<Fruta>FX.gd`, um arquivo
por fruta, às vezes com `…Grande`, `…Audio`, `…Geometry`), a hitbox comum (`DamageZone`), as
utilidades de VFX/áudio procedurais, passivas e as árvores com fruta no mapa. **Não** é daqui:
decidir recarga/energia (`CastController`, núcleo), números de dano (`Balance.gd`, combate), poses
autorais das frutas (`src/anim/*Poses.gd`, personagem).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `src/effects/DamageZone.gd` (★5) | área de dano móvel com knockback; **dano só no servidor** |
| `src/effects/FxUtil.gd` (★5) | helpers de VFX 100% procedurais (sem textura em disco) |
| `src/effects/AudioFX.gd` (★5) | sons procedurais (o projeto não tem assets de áudio de fruta); **0 testes** |
| `SkillSystem.gd` | definição das frutas e técnicas (fonte de verdade, depois da limpeza de 12/09) |
| `FruitPassiveSystem.gd` | passivas por fruta |
| `TreeAndFruitGenerator.gd` | 11 árvores místicas com fruta 3D no mapa |
| `src/effects/<Fruta>FX.gd` | a coreografia de cada fruta: Mera, Gomu, Goro, Pika, Hie(Ice), Yami, Suna(Sand), Gura, Buki, Bomu, Ope… |

Fruta inicial: **Ope Ope** (`Player.FRUTA_INICIAL`, 22/09). A **Pika Pika** é a única com kit
completo **sem árvore** no mapa. A **Rocket** (22–23/09) é a fruta do Modo História: kit da arena em
`src/combat/rocket_controller.gd`, números da história em `src/historia/frutas/rocket.tres`.
O efeito (`src/effects/rocket_vfx.gd`) usa a **paleta de 8 cores medida no vídeo** e tem camadas
por tipo de evento (`FX_EXPLOSAO`/`FX_RETICULO`/`FX_PILAR`/`FX_MISSIL`, escolhidas no `_evento` do
controlador): estilhaços, mancha de chão que fica 7 s, retículo de aviso, pilar de chamas e a
malha do foguete. **Onde o golpe cai é conta única** em `src/combat/mira_de_rocket.gd`, dividida
com o indicador de mira (`src/player/mira_de_fruta.gd`).

## Contrato: do dedo à hitbox

```
tecla Z/X/C/V → Player.begin_charge / release_charge
  → CastController.comecar / soltar        (recarga, energia, supressão)
  → Player.pedir_cast_no_servidor → RPC _net_cast → SERVIDOR _do_server_cast
  → RPC _net_play_cast (todos) → Player._fire_skill → <Fruta>FX.cast(world, origin, aim, variant, dano, self)
```

1. **VFX em todos, dano só no servidor.** Efeito bonito no cliente não prova que machuca.
2. **`_fire_skill` não devolve nada e engole erro**: técnica pode rodar sem hitbox (três frutas
   passaram meses disparando os golpes da Gomu).
3. Golpe sem `DamageZone` é enfeite (critério 5 do `PLANO_FRUTAS.md`).
4. Nó de VFX **tem que morrer**: contagem volta à base e não cresce em 5 repetições (`test_gomu_leak`).

## Estado e armadilhas

- Tabelas de dano das páginas `mera_mera.md` e `gomu_gomu.md` estão velhas; `Balance.gd` manda.
- Gura Gura foi implementada sem revisão e auditada com ~12 defeitos (itens 31–42 da lista):
  padrão de "competente e quebrado em silêncio" — revise contra o README das frutas.
- Mudou golpe → atualize a página da fruta NA MESMA TAREFA.
- Bara Bara tem redesenho planejado (`PLANO_BARA_BARA.md`); `test_bara_combat` falha (item 58).
- `SHADING_MODE_UNSHADED` descarta emissão; `set_glow_level()` é base zero (ver `visual`).
- Projétil rápido atravessa `Area3D`: varra o caminho (`DamageZone._varrer_caminho`).

## Validar

`test_frutas` (até ~8 min; rode só o slot afetado quando possível), `test_gomu_leak` (~130 s, dê
240 s), `test_compila`, e as sondas da fruta (`tools/<fruta>_preview.gd -- --capture` para capturas
das fases). Falhas conhecidas hoje: `test_mera_z_saque`, `test_ope_animacoes`,
`test_trava_fruta_dano`, `test_bara_combat`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "mera cast variant" --area frutas
python3 tools/contexto/indice.py buscar "gomu gatling" -n 5
python3 tools/contexto/indice.py buscar "teto dano reserva fruta" --docs
```
