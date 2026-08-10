# Inimigos — desligados do mapa (código preservado)

Os inimigos **não nascem mais no mapa**. O código deles **não foi apagado**: está
inteiro aqui, ainda compilando, e volta a funcionar com **uma linha**.

> Por quê: o mapa virou uma arena de **luta entre jogadores** (placar de kills e
> mortes, queda pelos buracos). NPC vagando pela plataforma só atrapalhava a
> leitura da luta. Nada do trabalho de IA/replicação foi perdido.

## Como religar

Em [`Main.gd`](../../Main.gd):

```gdscript
const ENEMIES_ENABLED := true   # era false
```

É só isso. Nada mais precisa ser tocado.

Para mudar quantos nascem, `Main.ENEMY_COUNT` (padrão 5).

## O que tem nesta pasta

| Arquivo | O que é |
|---|---|
| `Enemy.gd` | O inimigo em si (`class_name Enemy`) — Marine voxel: IA, patrulha, dano, morte, doma. Antes ficava em `src/entities/Enemy.gd`. |
| `EnemySpawner.gd` | `class_name EnemySpawner` — spawn, reposição a cada 4 s e replicação em rede. Esse código **saiu do `Main.gd`** sem nenhuma alteração de comportamento. |

## Decisões que valem lembrar

**Esta pasta NÃO tem `.gdignore`, de propósito.** O Godot continua compilando os
dois scripts e `class_name Enemy` / `class_name EnemySpawner` seguem no cache
global. Isso significa:

- religar é instantâneo, sem reimportar o projeto;
- se alguém referenciar `Enemy` por engano, o erro aparece **agora**, não meses
  depois;
- o custo é ~0: são dois scripts que ninguém instancia.

**A flag é `const`.** O `MultiplayerSpawner` dos inimigos exige que servidor e
clientes montem a **mesma árvore de nós**. Como `ENEMIES_ENABLED` é constante de
compilação, não existe o caso de o host ter o nó `EnemyModule` e o cliente não —
que daria dessincronização de `spawn_path`.

## O que continua ligado (não confundir)

- **O grupo `"enemy"`.** Várias skills miram esse grupo (`DamageZone`, tornado da
  Suna, teleguiado da Buki Buki, `TargetSystem`). O grupo **não foi mexido** — ele
  só está mais vazio.
- **O dummy de treino** (`src/entities/TrainingDummy.gd`), que fica no grupo
  `"enemy"` e continua no centro do mapa. É o saco de pancadas para testar golpes
  e o combate corpo a corpo — sem ele não dá para calibrar dano nem knockback.
- **A doma** (`Player._try_tame`), que já estava desligada antes disto
  (`Player.TAMING_ENABLED = false`) e segue como estava.
