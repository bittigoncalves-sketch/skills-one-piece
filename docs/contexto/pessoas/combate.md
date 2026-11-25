# Combate da arena — para quem chega

> Versão para agentes: [`../agentes/combate.md`](../agentes/combate.md) · arquivos: [`../INDICE.md#combate`](../INDICE.md#combate)

## O que é

Tudo que machuca na arena e não é poder de fruta: o combo do clique esquerdo (M1), as variações
dele conforme a situação, o contra-ataque, o Corpo de Ferro (F), os estilos de luta e a espada.

Na arena há três **modos de combate**, trocados pelas teclas 1, 2 e 3: fruta, estilo de luta e
espada. As teclas Z, X, C e V fazem coisas diferentes em cada modo.

> O Modo História tem um combate corpo a corpo **diferente** (ver [historia.md](historia.md)).

## Como funciona, em poucas linhas

- **Todo dano passa por um funil só** (`CombatResolver`). Um golpe se descreve (quanto dano,
  quanto empurra, quanto atordoa) e o funil aplica no alvo.
- **Todos os números de dano estão numa tabela só:** `src/combat/Balance.gd`. Quer mudar quanto um
  golpe tira? É lá.
- **Na arena quem mata é a queda**, não a vida acabar. Por isso o importante de um golpe é o
  quanto ele empurra.

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar dano de qualquer golpe | `src/combat/Balance.gd` |
| mudar o tempo do combo M1 | `src/combat/Melee.gd` |
| mudar as variações do clique (no ar, correndo…) | `src/combat/contextual_melee.gd` |
| mudar um estilo de luta | `src/combat/FightingStyles.gd` |
| mudar a espada (Yoru) | `src/combat/YoruController.gd`, `SwordBlade.gd` |

## Cuidado com

- **Não chame o dano direto no alvo.** Passe pelo funil, senão o golpe fura os limites de dano.
- **Há defeitos conhecidos esperando a vez**, como a hitbox do M1 que não se cancela e a pausa de
  impacto que desacelera o jogo inteiro. Estão na [lista de correções](../../LISTA_DE_CORRECOES.md)
  com plano; não conserte no meio de outra tarefa.
- **Sensação do golpe é decisão do dono.** Mudar tempo, alcance ou força de um golpe muda como o
  jogo se sente: pergunte antes.

## Para saber mais

- [`../../COMBATE_CORPO_A_CORPO.md`](../../COMBATE_CORPO_A_CORPO.md) — combo, variações, defesa e rede
- [`../../COMBATE_ESPADA.md`](../../COMBATE_ESPADA.md) — a espada Yoru
- [`../../MODOS_DE_COMBATE.md`](../../MODOS_DE_COMBATE.md) — as teclas 1, 2 e 3
- [`../../ESTILOS_DE_LUTA.md`](../../ESTILOS_DE_LUTA.md) — os estilos de luta
