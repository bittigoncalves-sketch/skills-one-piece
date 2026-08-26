# Limite de tamanho dos scripts

> **Regra do dono do projeto (2026-08-11): nenhum script passa de 900 linhas.
> Passou, divide em dois ou mais.**

Conferir:

```bash
find . -name "*.gd" -not -path "./.godot/*" | xargs wc -l | sort -rn | head
```

---

## Estado hoje

> ⚠️ **Recontado em 2026-08-26** (`wc -l`, projeto inteiro, excluindo `.godot/` e
> `disabled/`). A tabela anterior estava **muito** desatualizada e se contradizia:
> dizia `Player.gd` com 1.498 linhas na tabela e 2.167 no corpo do texto. Os
> números abaixo são os reais.

| arquivo | linhas | antes dizia | |
|---|---|---|---|
| `Player.gd` | **2.437** | 1.498 / 2.167 | 🔴 **2,7× o teto.** 1.433 de código (1.004 de comentário e branco) — ainda 1,6× |
| `src/effects/YamiFX.gd` | **1.045** | 811 | 🔴 **passou o teto** (+145) |
| `src/effects/GoroFXGrande.gd` | **973** | não estava na tabela | 🔴 **passou o teto** (+73) |
| `src/anim/ProceduralAnimator.gd` | **921** | 873 "27 do teto" | 🔴 **passou o teto** (+21) — o aviso era certo e ninguém agiu |
| `src/effects/BaraFX.gd` | **857** | não estava na tabela | 🟡 43 do teto |
| `src/effects/WaterFX.gd` | **700** | não estava na tabela | 🟡 cresce a cada estilo tratado |
| `src/combat/Melee.gd` | **662** | — | ✅ |
| `src/player/cast_controller.gd` | **609** | 168 (na Fase 6c) | ✅ mas 3,6× o que era |
| `src/effects/BukiFX.gd` | **553** | 537 | ✅ |
| `src/effects/FireFXGrande.gd` | **487** | 553 | ✅ |
| `src/effects/FireFX.gd` | **486** | 382 | ✅ (era 916 antes do corte) |
| `src/anim/GuraPoses.gd` | 445 | 445 | ✅ |

**Quatro arquivos passaram do teto**, e o `ProceduralAnimator` passou exatamente
como esta página avisou que passaria. A regra existe; o portão não.

⚠️ **Esta tabela envelhece sozinha.** Ela só vale enquanto alguém recontar. O
comando está logo acima — rodá-lo custa 2 segundos e é a única forma de a página
não voltar a mentir.

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

## O que falta: `Player.gd`, 2.437 linhas

**É 2,7× o limite, e não é um corte mecânico.** `FireFX` era uma coleção de
funções estáticas independentes — dava para separar por bloco. O `Player` é uma
classe com estado compartilhado: as regiões conversam por variáveis de instância
(`_buki_weapon`, `_charging`, `_dash_t`, `velocity`, `_is_authority`…), então
mover funções para outro arquivo exige decidir **quem passa a ser dono de cada
estado**. Feito às pressas, isso quebra o jogo de um jeito que o teste headless
não pega — comportamento de input e de rede.

### ⚠️ O plano desta seção JÁ FOI EXECUTADO — e o arquivo cresceu assim mesmo

Atualizado em 2026-08-26. Os quatro candidatos listados aqui **saíram todos**, nas
Fases 2 a 8 de [`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md):

| candidato de então | onde foi parar |
|---|---|
| Câmera e efeitos de tela | `src/player/camera_rig.gd` (Fase 2) |
| Arsenal da Buki | `src/player/buki_controller.gd` (Fase 5) |
| Corpo a corpo | `src/player/melee_controller.gd` (Fase 7) |
| Parkour | `src/player/parkour_controller.gd` (Fase 4) — mais `dash_controller.gd` e `move_frame.gd`, que não estavam previstos |

E ainda saíram `health_controller.gd` (Fase 8), `cast_controller.gd`,
`player_rig.gd`, `mira.gd` e `disparo_sustentado.gd`.

**E o número que importa é este:**

| | linhas |
|---|---|
| antes da partição (2026-08-11) | 2.167 |
| depois das 9 fases (2026-08-12) | **1.498** — a partição tirou 669 |
| hoje (2026-08-26) | **2.437** — voltaram **939** em duas semanas |

**O arquivo recuperou mais do que a partição inteira tinha tirado, e em menos
tempo do que levou para cortá-lo.** A partição funcionou; o que ela não fez foi
impedir a volta, porque **não existe portão automático** — nada na bateria
(`./validar.sh rapido`) reprova por tamanho. Este documento é a regra; a regra não
tem quem a cobre.

**Este é o achado, e ele vale mais que a lista de candidatos:** o problema deixou
de ser "como cortar" e passou a ser "como não voltar". Enquanto não houver uma
checagem que **falhe**, a próxima recontagem vai dar um número maior que este.

### O que ainda dá para extrair (leitura de 2026-08-26)

O que sobrou no `Player.gd` e ainda tem estado próprio:

- **A FSM e o encanamento de combate** — os `@rpc` de melee e cast. ⚠️ Em obra em
  2026-08-26; não mexer.
- **A troca de modo de combate e as duas tabelas de recarga** (`combat_mode`,
  `_fruit_cooldowns`, `_style_cooldowns`, `toggle_combat_mode`,
  `set_fighting_style`) — fronteira limpa, ver [`ESTILOS_DE_LUTA.md`](ESTILOS_DE_LUTA.md).
- **Equipar/perder fruta** (`equip_fruit`, `limpar_skills_em_todos`, a conversa
  com `FruitNet`).

⚠️ **RPC se resolve por CAMINHO DE NÓ.** Mover um método `@rpc` para outro nó
**muda o protocolo** — foi por isso que a Fase 5 moveu o *estado* e a *regra* da
Buki e deixou os quatro `@rpc` no Player. Qualquer extração nova esbarra na mesma
parede.

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
