# Contexto (agentes) — Combate da arena

> 21/09/2026 · versão para pessoas: [`../pessoas/combate.md`](../pessoas/combate.md) · arquivos e ★:
> [`INDICE.md#combate`](../INDICE.md#combate) · donos do detalhe:
> [`COMBATE_CORPO_A_CORPO.md`](../../COMBATE_CORPO_A_CORPO.md), [`COMBATE_ESPADA.md`](../../COMBATE_ESPADA.md),
> [`MODOS_DE_COMBATE.md`](../../MODOS_DE_COMBATE.md), [`ESTILOS_DE_LUTA.md`](../../ESTILOS_DE_LUTA.md),
> [`PLANO_COMBATE_BATTLEGROUNDS.md`](../../PLANO_COMBATE_BATTLEGROUNDS.md)

## Escopo

Tudo que fere na arena sem ser técnica de fruta: o funil de dano, a tabela de números, o combo M1
e suas variações contextuais, counter hit, launcher, Corpo de Ferro (F), estilos de luta (modo 2),
espada Yoru (modo 3) e itens de arma. **Não** é daqui: o combate direcional do Modo História
(`src/combat/direcional/` → contexto `historia`), as FX das frutas (`frutas`), o Boss (`bosses`).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `src/combat/DamageSpec.gd` (★5) | o que um golpe É: dano, knockback, hitstun, teto, reserva — viaja pela pipeline |
| `src/combat/CombatResolver.gd` (★5) | O FUNIL: todo dano passa por `aplicar` (com hitbox ou sem) |
| `src/combat/Balance.gd` (★5) | A TABELA: todo número de dano do jogo mora aqui e só aqui |
| `src/combat/Melee.gd` (★5, ~880 linhas) | frame data do combo M1; perto do teto de 900 |
| `src/combat/contextual_melee.gd` | as 7 variações contextuais do clique (já usa token de cancelamento) |
| `src/combat/FightingStyles.gd` | estilos (Karatê Tritão, Pacifista, Mink, Boxe, Cyborg); estilo custa 60 s |
| `src/combat/YoruController.gd`, `YoruMoves.gd`, `YoruWave.gd` | espada: relógio físico único, dois M1 + Z/X/C/V |
| `src/combat/SwordBlade.gd`, `SwordSweep.gd` | 7 esferas no fio, varridas entre ticks NO SERVIDOR |
| `src/combat/StatusFX.gd` | o que está acontecendo com o personagem agora (status) |
| `src/effects/DamageZone.gd` (área `frutas`) | hitbox de área com knockback; sai cedo fora do servidor |

## Contratos

- **Pipeline:** golpe monta `DamageSpec` → `CombatResolver.aplicar(alvo, dano, …)` →
  `alvo.take_damage(amount, origem, knockback, hitstun)`. Chamar `take_damage` direto pula teto e
  reserva — não faça.
- **Arena mata pela queda:** o foco de todo golpe é knockback. (O `DAMAGE_SCALE` de 0,12 que ficava
  na `DamageZone` **saiu em 21/08**: hoje o corte de dano mora no `Balance`/`DamageSpec`.)
- **Teto por cast e reserva** (`DamageSpec.reserva`): golpe de várias partes reserva orçamento
  para o clímax.
- **Modo 3 (espada) é o único com presença física** (arma na mão, pickup no mapa).
- **Servidor valida** ações da espada e do M1; cliente só pede.

## Defeitos abertos que você vai encontrar (LISTA_DE_CORRECOES)

- **Item 59 / C2:** hitbox do M1 agendada por `create_timer` não é cancelada por finta, aparo
  ou stun — golpe interrompido no preparo ainda acerta (`Melee.gd` ~660).
- **Item 60 / A2:** hit stop GLOBAL via `Engine.time_scale` em `DamageZone` → `GameFlow`;
  desacelera o host inteiro e clientes não veem.
- **M4:** tremor de câmera do M1 sai com golpe cancelado/errado. **M5:** dois buffers de input.
- **Item 54:** replicação da espada (plano Yoru, agentes `yoru-*`).
- Dados da espada duplicados (`Melee.COMBO_SWORD` × `YoruMoves`).

Não conserte por conta dentro de outra tarefa: são itens com dono e plano.

## Armadilhas

- Três "dano" no mesmo jogo e só um vale (`ESTILOS_DE_LUTA.md` §3) — confira em `Balance.gd`.
- `else` cego depois que o terceiro modo entrou: use `match` no modo de combate.
- `Area3D` vê uma vez por quadro: golpe rápido precisa de varredura (`SwordSweep.contacts`).

## Validar

`test_compila`, `test_arena`, `test_counter_hit`, `test_ataques_contextuais`, `test_combo_contextual`,
`test_balance` (hoje FALHA — débito conhecido), `test_melee_trava` (com tela), sondas
`net_contextual_*_probe` para rede. Agentes: `critico-de-combate` (feel), `avaliador-de-animacao`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "funil dano teto reserva" --area combate
python3 tools/contexto/indice.py buscar "counter hit launcher"
python3 tools/contexto/indice.py buscar "espada fio esfera varredura"
```
