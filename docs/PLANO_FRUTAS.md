# Plano — auditoria e aprimoramento das Akuma no Mi

Objetivo do dono do projeto: **saber quais frutas estão funcionais** (pegar numa
árvore equipa de verdade, e os quatro golpes saem) e aprimorar as que existem.

> **Regra que manda nisto:** não criar fruta nova enquanto as atuais não
> estiverem prontas. Este plano só mexe no que já existe.

---

## 1. O que "funcional" quer dizer, em números

Uma fruta só conta como funcional se passar nos **seis** critérios. Cada um é
medido, não julgado no olho:

| # | critério | como é medido |
|---|---|---|
| 1 | **Obtível** | existe árvore que a planta no mapa (`get_tree_definitions`) |
| 2 | **Equipa** | andar por cima grava o id certo em `current_fruit_id` |
| 3 | **Passiva** | `FruitPassiveSystem` aplica `speed_mod`/`jump_mod` |
| 4 | **Golpe sai** | Z/X/C/V criam nós no mundo (≠ 0) |
| 5 | **Golpe machuca** | Z/X/C/V criam **`DamageZone`** — sem isso é só enfeite |
| 6 | **Não vaza** | a contagem de nós volta ao normal depois do efeito |

O critério 5 é o que separa "bonito" de "jogável", e o 6 foi o que pegou a luz
órfã do Gomu V (uma `OmniLight3D` acesa para sempre por uso).

**Por que medir o mundo e não a função:** `_fire_skill` não devolve nada e engole
quase tudo. Um golpe pode "rodar" sem criar hitbox nenhuma — foi assim que 3
frutas passaram meses dando os golpes da Gomu Gomu sem ninguém perceber.

---

## 2. A ferramenta

```bash
godot --headless --path . --script tools/dev_tests/test_frutas.gd
godot --headless --path . --script tools/dev_tests/test_frutas.gd -- mera_mera
```

Sobe o **jogo de verdade** (não um mundo de mentira), equipa cada fruta, dispara
os quatro slots e conta o que apareceu e o que sobrou no mundo. Devolve uma
tabela e uma lista de pendências.

Ela é a fonte de verdade deste plano: **ninguém declara fruta pronta sem ela
verde.**

---

## 3. Como o trabalho é dividido

Um agente por **família de fruta**, não por tarefa. O motivo é o mesmo de sempre
(ver [`AGENTES.md`](AGENTES.md)): cada fruta vive num arquivo próprio em
`src/effects/`, então a divisão por fruta dá territórios que **não se cruzam** e
podem rodar em paralelo de verdade.

| agente | território | não pode tocar |
|---|---|---|
| **Logias** | `FireFX`, `IceFX`, `SandFX`, `GoroFX`, `YamiFX` | `Player.gd`, outras frutas |
| **Paramecias** | `GomuFX`, `GomuArm`, `GomuRedHawk`, `GomuGatling`, `BaraFX`, `GuraFX`, `BukiFX` | `Player.gd`, outras frutas |
| **Integração** | `SkillSystem.gd`, `FruitPassiveSystem.gd`, `TreeAndFruitGenerator.gd`, `data/akuma_no_mi.json` | `src/effects/` |

**`Player.gd` é território de ninguém nesta fase.** Se um agente precisar de
mudança lá, ele **reporta o patch** e quem orquestra aplica — dois agentes
editando o mesmo arquivo se sobrescrevem, e já aconteceu de perder trabalho assim.

O que todo prompt precisa carregar está em [`AGENTES.md`](AGENTES.md); o resumo é:
especialidade na primeira linha, caminhos das ferramentas (o `godot` **não** está
no PATH), o diagnóstico que já existe **com números**, o que já foi descartado,
critério de sucesso medível, fronteiras nominais, e o formato do relatório.

---

## 4. Ordem de ataque

1. **Rodar a auditoria** e congelar o resultado como linha de base. *(feito — ver
   `AUDITORIA_FRUTAS.md`)*
2. **Consertar o que está mudo** — golpe que não produz nada é bug, não é ajuste
   de sensação. Prioridade máxima.
3. **Dar hitbox ao que só tem visual** — efeito bonito que não machuca não é
   golpe.
4. **Fechar vazamentos** — nó que sobra no mapa degrada a partida com o tempo.
5. **Dar árvore a quem tem poder mas não tem onde nascer** (hoje: `gura_gura`).
6. **Só então** aprimorar sensação: cadência, alcance, knockback, VFX.

Os passos 2–5 são **defeito**. O passo 6 é **gosto**, e depende de jogar — nenhum
número decide por você.

---

## 5. O que a auditoria NÃO cobre

Honestidade sobre o alcance da ferramenta:

- **Não julga se o golpe é bonito ou gostoso.** Ela conta nós e hitboxes.
- **Não testa em rede.** Roda em um-jogador. Golpe que funciona aqui ainda pode
  falhar no cliente — foi o caso da pistola da Yami, que nascia sem passar pelo
  servidor. Para rede existem as sondas `net_host_probe.gd` / `net_client_probe.gd`.
- **Não vê a tela.** Um efeito pode nascer dentro do chão, atrás do jogador ou no
  centro do mapa e a contagem de nós não acusa. Já aconteceu: `global_position`
  escrito antes do `add_child` fazia o efeito nascer em (0,0,0).
- **Não mede dano real em alvo.** Confirma que a `DamageZone` existe, não que ela
  encosta em alguém.

---

## 6. Documentação gerada

| arquivo | conteúdo |
|---|---|
| `docs/PLANO_FRUTAS.md` | este plano |
| `docs/AUDITORIA_FRUTAS.md` | o resultado medido, fruta a fruta |
| `docs/erros.md` | todo defeito achado, com causa e como detectar |
| `tools/dev_tests/test_frutas.gd` | a ferramenta que decide o que está pronto |
