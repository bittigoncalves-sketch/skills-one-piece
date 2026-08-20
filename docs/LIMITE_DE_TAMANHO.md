# Limite de tamanho dos scripts

> **Regra do dono do projeto (2026-08-11): nenhum script passa de 900 linhas.
> Passou, divide em dois ou mais.**

Conferir:

```bash
find . -name "*.gd" -not -path "./.godot/*" | xargs wc -l | sort -rn | head
```

---

## Estado hoje

| arquivo | linhas | |
|---|---|---|
| `Player.gd` | **1.498** | 🟡 **1.498 por `wc -l`, mas 890 de código** — ver o veredito da Fase 9 em [`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md) |
| `src/effects/FireFXGrande.gd` | 553 | ✅ criado no corte de 2026-08-11 |
| `src/effects/BukiFX.gd` | 537 | ✅ |
| `src/anim/ProceduralAnimator.gd` | **873** | 🔴 **27 do teto** — o próximo bloco não cabe, extraia antes |
| `src/anim/GuraPoses.gd` | 445 | ✅ criado em 2026-08-15 (as animações dos 4 golpes da Gura) |
| `src/effects/YamiFX.gd` | 811 | ⚠️ na mira |
| `src/effects/FireFX.gd` | 382 | ✅ (era 916) |

---

## O que já foi dividido

**`FireFX.gd` 916 → 382 + 553.** O corte foi por **tamanho de bloco**, não por
capricho: o Hibashira legado, o Inferno e a explosão somavam 533 das 916 linhas
e são os únicos golpes que não participam do combate do dia a dia — Z e X são o
uso normal da fruta, esses três são espetáculo. Foram para `FireFXGrande.gd`.

Os ajudantes comuns (materiais, partículas, brasas) **ficaram no `FireFX`** e são
chamados de lá. Duplicá-los criaria duas fontes de verdade para a paleta do fogo,
que é o que mantém a fruta coerente.

> Um detalhe que só apareceu porque o teste pegou: a classe interna
> `EnteiSunController` foi junto no corte, mas quem a instancia (`_entei_sun`)
> ficou. Passou a ser qualificada (`FireFXGrande.EnteiSunController`) — mover a
> classe de volta reabriria o arquivo para perto do limite.

---

## O que falta: `Player.gd`, 2.167 linhas

**É 2,4× o limite, e não é um corte mecânico.** `FireFX` era uma coleção de
funções estáticas independentes — dava para separar por bloco. O `Player` é uma
classe com estado compartilhado: as regiões conversam por variáveis de instância
(`_buki_weapon`, `_charging`, `_dash_t`, `velocity`, `_is_authority`…), então
mover funções para outro arquivo exige decidir **quem passa a ser dono de cada
estado**. Feito às pressas, isso quebra o jogo de um jeito que o teste headless
não pega — comportamento de input e de rede.

### O plano, quando for a hora

Extrair por **componente com estado próprio**, não por "mover funções":

| candidato | linhas aprox. | por que sai bem |
|---|---|---|
| Arsenal da Buki (`_buki_*`, RPCs de saque e tiro) | ~280 | estado próprio (`_buki_weapon`, `_buki_municao`, `_srv_buki_*`), fronteira clara |
| Parkour (wall run, vault, mantle, rolamento) | ~300 | conversa com `velocity` e `is_on_floor`, mas não com combate |
| Corpo a corpo (`_request_melee`, `_tick_melee`, RPCs) | ~120 | já tem metade em `Melee.gd` |
| Câmera e efeitos de tela (bob, FOV, shake, aberração) | ~180 | só lê estado, quase não escreve |

Ordem sugerida: **câmera primeiro** (é a que menos escreve estado, então é a de
menor risco e valida o padrão de extração), depois Buki, depois parkour.

### Rede de segurança que já existe

```bash
godot --headless --path . --script tools/dev_tests/test_compila.gd   # 0
godot --headless --path . --script tools/dev_tests/test_arena.gd     # 53 checagens
godot --headless --path . --script tools/dev_tests/test_buki_buki.gd # 24
```

Mais as sondas de rede (`net_host_probe.gd` + `net_client_probe.gd`), que são as
únicas que cobrem o que o headless de um processo só não vê.

**Gatilho:** o `Player.gd` não pode crescer mais. Qualquer tarefa que precise
adicionar código nele deve primeiro extrair um dos componentes acima.
