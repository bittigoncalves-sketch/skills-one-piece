# Relatório do `Player.gd` — mapa para particionamento

**Motivação:** o arquivo tem **2.167 linhas**, 2,4× o limite de 900 do projeto
(`LIMITE_DE_TAMANHO.md`). Este relatório mapeia o que existe lá dentro para o
dono decidir onde cortar.

**Nada foi alterado.** Bugs encontrados estão em
[`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md), não corrigidos.

Medido em 2026-08-11 por análise do fonte: **89 métodos, 113 campos, 13 RPCs**.

---

## 1. Domínios — e por que a tabela engana

| domínio | linhas | métodos |
|---|---|---|
| **NÚCLEO / CICLO** | **707** | 15 |
| HABILIDADES (frutas, cast, rajada) | 505 | 24 |
| ARSENAL BUKI | 259 | 19 |
| RIG E MODELO | 248 | 7 |
| VIDA E DANO | 139 | 5 |
| CORPO A CORPO | 76 | 5 |
| CÂMERA | 52 | 5 |
| MOVIMENTO | 45 | 4 |
| DOMA (desativada) | 30 | 3 |
| REDE | 16 | 2 |

> ⚠️ **"MOVIMENTO com 45 linhas" é falso**, e entender por quê é a coisa mais
> importante deste relatório. A classificação acima é por **nome de método**, e
> a movimentação de verdade não está em métodos próprios: ela mora **dentro do
> `_physics_process`**, que sozinho tem **291 linhas** e caiu em "NÚCLEO".
>
> O mesmo vale para parkour e dash. O "núcleo" de 707 linhas é, na prática, um
> monólito dentro do monólito.

### O que há dentro do `_physics_process` (291 linhas)

| assunto | linhas aprox. |
|---|---|
| movimento (velocidade, gravidade, `move_and_slide`) | 46 |
| parkour (wall run, vault, mantle, escalada, rolamento) | 28 |
| dash | 26 |
| habilidades / cast / energia | 17 |
| animação, rede, buki, câmera, melee | ~12 |
| restante (fluxo, condições, blocos de decisão) | ~162 |

**Três saídas antecipadas (`return`) cortam o método no meio:**

| linha | quando dispara | o que deixa de rodar |
|---|---|---|
| 542 | `not _is_authority` | **tudo** — corpo remoto só reproduz estado replicado |
| 591 | bloco de travamento (`_charging`, `_rapid_fire`, `_movement_locked_timer`, congelado, vórtice, buraco negro) | movimento, parkour, dash, câmera |
| 816 | `SkillSystem.process_void_check` (caiu no vazio) | o que vier depois no quadro da morte |

Isso é **dependência de ordem invisível**: quem cortar o arquivo sem saber que
esses `return` existem quebra o jogo de um jeito que nenhum teste headless pega.

---

## 2. O mapa do estado — o que realmente trava o corte

**22 dos 113 campos são escritos por mais de um domínio.** Enquanto isso for
verdade, mover funções para outro arquivo não separa nada: os dois lados
continuam disputando a mesma variável.

### Os piores (3 domínios escrevendo cada um)

| campo | escrito por | por que dói |
|---|---|---|
| `_yaw` | Buki, Habilidades, Núcleo | a mira é escrita pelo auxílio de mira da Buki, pela pistola da Yami e pelo mouse |
| `_pitch` | Buki, Habilidades, Núcleo | idem |
| `energy` | Habilidades, Núcleo, Vida | regenera no ciclo, é gasta pelas skills, é restaurada no respawn |
| `_kb_impulso` | Buki, Núcleo, Vida | o empurrão nasce no dano, decai no ciclo, e o recuo do canhão escreve nele |
| `_fov_punch` | Corpo a corpo, Habilidades, Núcleo | três fontes de "zoom de impacto" |
| `_gun_recoil` | Buki, Habilidades, Núcleo | coice visual, escrito por duas armas diferentes |
| `current_fruit_id` | Habilidades, Rig, Vida | equipar, trocar de modelo e morrer (larga a fruta) |

### Os demais compartilhados (2 domínios)

`_breath`, `_is_authority`, `combat_mode`, `_shake`, `is_suppressed`,
`suppression_timer`, `_charging`, `_movement_locked_timer`,
`_yami_shot_cooldown`, `_buki_visual`, `_buki_armas`, `speed_multiplier`,
`jump_multiplier`, `_srv_buki_arma`, `_srv_buki_municao`.

> Já temos um precedente do que acontece quando se ignora isso: `velocity` era
> escrito pela locomoção **e** pelo knockback, e o empurrão simplesmente não
> funcionava — a locomoção reatribuía `velocity.x/z` todo quadro. A correção foi
> dar ao knockback um campo próprio (`_kb_impulso`) somado depois. **Esse é o
> padrão que resolve os 22 casos: cada dono escreve o seu, e o ciclo combina.**

---

## 3. RPCs — o limite duro

**13 métodos `@rpc`.** Em Godot, RPC é resolvido por **caminho de nó**: mover um
método `@rpc` para outro nó muda o caminho e a chamada quebra.

| domínio | RPCs |
|---|---|
| ARSENAL BUKI | `_net_buki_sacar_req`, `_net_buki_sacar`, `_net_buki_guardar_req`, `_net_buki_guardar` |
| HABILIDADES | `_net_cast`, `_net_play_cast`, `_net_bullet_req`, `_net_bullet_play` |
| CORPO A CORPO | `_net_melee`, `_net_play_melee` |
| VIDA E DANO | `net_apply_knockback`, `net_force_respawn` |
| DOMA | `_net_tame` |

**Consequência prática:** Buki, habilidades, corpo a corpo e vida **não podem
virar arquivos soltos** com `class_name` e funções estáticas. Ou os RPCs ficam no
`Player`, ou o domínio vira um **nó filho** — e aí o caminho muda de propósito, o
que exige acertar os dois lados (é mudança de protocolo, não refatoração).

Só **CÂMERA**, **RIG E MODELO** e **MOVIMENTO/PARKOUR** estão livres de RPC.

---

## 4. Proposta de corte, com risco

### ✅ Corte 1 — CÂMERA (~52 linhas + partes do `_process`)
**Sai limpo.** Sem RPC. Escreve pouco: `_shake`, `_fov_punch`, `_bob_t`, e lê
`_yaw`/`_pitch`/`velocity`. Vira um nó filho `CameraRig` que **lê** o estado do
player e escreve só o próprio.
**Risco:** baixo. O que o teste não pega: se a mira ficar dessincronizada do
corpo, nenhuma suíte acusa — só olhando.
**Conflito a resolver antes:** `_fov_punch` tem três donos; ele precisa virar
"pedido" (`pedir_fov_punch(x)`) em vez de campo escrito de fora.

### ✅ Corte 2 — RIG E MODELO (248 linhas, 7 métodos)
**Sai limpo.** Sem RPC. `_setup_character_model` sozinho tem **124 linhas**.
Vira `PlayerRig`, responsável por montar o modelo, achar o esqueleto, encaixar no
corpo e pendurar armas.
**Risco:** médio. Mexe no que já foi caro (Z-up dos Meshy, escala 100×, proxies
do rig). Mas `test_rig_unico` e `test_anatomia_rig` cobrem isso.
**Conflito:** `_buki_armas`/`_buki_visual` são escritos por Rig **e** por Buki —
decidir quem monta e quem mostra.

### ⚠️ Corte 3 — MOVIMENTO + PARKOUR + DASH (~100 linhas dentro do `_physics_process`)
**Não é mover método: é extrair código de dentro de um método de 291 linhas.**
Exige antes quebrar o `_physics_process` em etapas nomeadas.
**Risco:** alto. É o caminho de todo quadro, com três `return` que cortam o
fluxo. Erro aqui aparece como "o personagem não anda" ou "atravessa parede".

### 🔴 Corte 4 — BUKI / HABILIDADES / CORPO A CORPO
**Bloqueados pelos RPCs.** Só saem virando **nó filho**, o que muda o caminho de
rede dos 10 RPCs desses domínios. É mudança de protocolo — exige testar com dois
processos, e um erro aqui só aparece jogando em rede.

### Ordem sugerida
1. **Câmera** — menor risco, valida o padrão de extração.
2. **Rig e modelo** — bom retorno (248 linhas) e coberto por teste.
3. **Quebrar o `_physics_process`** em etapas nomeadas, sem mover nada de
   arquivo. Sozinho isso já derruba muito do "núcleo" de 707 linhas.
4. Só então decidir se Buki/habilidades viram nós filhos.

**Estimativa:** os cortes 1 a 3 tiram ~400 linhas. O `Player.gd` iria para
~1.750 — **ainda acima de 900**. Chegar ao limite **exige** o corte 4, ou seja,
exige a decisão sobre virar nó com filhos-componentes.

---

## 5. Veredito honesto

**Particionar só movendo funções não chega ao limite de 900.** O `Player.gd` não
é grande por acúmulo de funções soltas — ele é grande porque concentra três
coisas que só ele pode fazer hoje: **ser o corpo físico**, **ser o dono do
estado** e **ser o endereço de rede**.

Os cortes 1–3 são reais e valem a pena, e derrubam o arquivo para ~1.750 linhas.
Passar disso é decisão de **arquitetura**, não de arrumação: transformar o
`Player` num nó com filhos-componentes, com o protocolo de rede reapontado.

---

## 6. Limites deste relatório

- A classificação por domínio é por **nome de método**. Ela erra onde o código
  mora dentro de um método grande — foi o caso de "MOVIMENTO com 45 linhas".
  Os números do `_physics_process` foram medidos por palavra-chave linha a
  linha, e são aproximados.
- **Não li os 17 scripts satélites por dentro** — o escopo pedido foi o
  `Player.gd` e suas fronteiras.
- **Nada foi testado em rede.** A afirmação sobre RPCs vem do modelo de
  resolução por caminho de nó do Godot, não de um experimento.
- Não estimei quanto código *novo* (repasses, sinais) cada corte adiciona.
