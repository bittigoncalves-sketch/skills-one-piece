# Números medidos — o índice

Este projeto não aceita "melhorou" sem número, e por isso acumulou dezenas de
medições. Elas estão **espalhadas em comentário de código**, uma por arquivo, e
ninguém consegue lembrar onde. Esta página é o **índice**: o número, o que ele
decidiu, e onde a conta mora.

**Regra de uso:** esta página é um mapa, não a fonte. Antes de agir sobre um
número, abra o arquivo citado — lá está a metodologia, que é a parte que
sobrevive quando o número muda.

**Como foi levantado** (2026-08-26): `grep -rn -i "medido" --include='*.gd'` em
`src/`, `Player.gd`, `autoload/` e `network/` devolve **64 linhas**; as que
carregam número estão abaixo. A contagem é de *linhas casadas*, não de medições
distintas — o mesmo número aparece repetido em até 5 cabeçalhos (o caso da
autoridade, §1).

---

## 1. Rede e autoridade

| número | o que decidiu | onde |
|---|---|---|
| **pai = 7, filho = 1** | A autoridade **não desce** para componentes criados no `_ready()`. Por isso `BukiController`, `CastController`, `HealthController`, `MeleeController` e `DisparoSustentado` **nunca** chamam `is_multiplayer_authority()` — recebem a resposta de quem sabe. | `buki_controller.gd:30`, e repetido em 4 cabeçalhos |
| **pente 9 → 12, duas vezes** | Munição infinita da Buki. Com a recarga quente, repetir `_net_buki_sacar_req` reenchia o pente: 6 zonas de dano onde o honesto tem 3. Fechado com **duas** guardas (sacar põe a anterior em recarga; só então checa o slot). | `buki_controller.gd:183-192` |
| **sniper cheia, 5 balas, 0 `DamageZone`** | Remover `_request_cast(slot)` do saque tirou de carona o registro de `_srv_arma`/`_srv_municao` — e o servidor passou a **recusar todo tiro**. Lição: remover chamada é tão perigoso quanto adicionar. | `buki_controller.gd:151-162` |

⚠️ O primeiro é o número mais reaproveitável do projeto: qualquer componente novo
criado no `_ready()` herda o mesmo problema.

---

## 2. Projétil rápido — o teto de velocidade que é de física, não de gosto

A `DamageZone` anda por teleporte (`position += vel * delta`) e a `Area3D` só
enxerga quem está sobreposto **naquele quadro**. Com alvo de 1,0 m e raio 0,16, a
janela de acerto tem ~1,32 m.

Medido em 2026-08-12, **24 disparos frontais no centro por velocidade**:

| velocidade | acertos |
|---|---|
| 79 m/s | 24/24 |
| 95 m/s | 20/24 |
| 110 m/s | 17/24 |
| 125 m/s | 16/24 |
| 200 m/s | 9/24 |

**A sniper estava em 95 e perdia 1 tiro em 6, sem o jogador ter como saber.**

⚠️ Sub-passo de *posição* não resolve — a `Area3D` detecta uma vez por quadro de
física. O que resolve é **varrer o caminho com um raio**.

⚠️ O dano *esperado* não muda acima de 79 m/s: velocidade × chance de acerto é
constante. Subir a velocidade troca **consistência** por **sensação**.

Fonte: `src/effects/DamageZone.gd:92-107` e `src/effects/BukiFX.gd:49-58`.
⚠️ *A `DamageZone` está em obra em 2026-08-26 — confira o estado real antes de
usar isto para decidir.*

---

## 3. Render — o número que reescreveu a Fase 5 do plano visual

**`SHADING_MODE_UNSHADED` descarta a emissão.** Halo em volta de uma esfera, com
glow menos sem glow:

| material | ganho de halo |
|---|---|
| unshaded + emissão 4,0 | **+0,0000** — não brilha |
| unshaded **só albedo** | +0,0000 — idêntico, ao dígito |
| unshaded + albedo ×2,5 | **+0,0597** |
| unshaded + albedo ×2,5, alpha 0,6 | +0,0422 |
| unshaded + albedo ×2,5, aditivo | +0,0625 |
| **sombreado** + emissivo | +0,0355 |

As duas primeiras serem idênticas **é a prova**. E era assim que o jogo inteiro
estava escrito: **32 combinações em 16 arquivos** declarando energia de emissão
entre 2,5 e 4,0 e jogando fora. Ninguém notou porque, até 2026-08-25, **não
existia glow no projeto** — dois defeitos escondidos um no outro.

⚠️ Não basta tirar o `unshaded`: material sombreado brilha, mas passa a
**escurecer** quando o golpe atravessa a sombra de um bloco. Fogo não apaga na
sombra. O caminho certo é `FxUtil.brilho(cor, energia)`, que põe o brilho no
**albedo**.

⚠️ **Contar por proximidade de texto não é contar.** Os "32 sítios" viraram **28**
ao contar por *função* em vez de janela de ±25 linhas: duas funções que chamam o
material de `m` se confundem. Vale para qualquer varredura por `grep` — e por
isso esta página diz sempre **como** contou.

**Outros números da mesma passada:**

- glow em intensidade 0,9 / limiar 1,05 / 4 níveis → **3,0% da tela estourada**
  numa cena com **um** golpe. Hoje: limiar **1,15**, intensidade 0,5 (PC) / 0,38.
- `FxUtil.ESCALA = 0,45` **comprime** em vez de multiplicar
  (`e = 1 + (energia−1) × ESCALA`): as energias escritas (2,5 · 4,0 · 6,0 · 8,0)
  nunca foram calibradas, e multiplicar achataria a diferença entre um golpe de
  2,5 e um de 8,0. Com 0,45 elas viram 1,68 · 2,35 · 3,25 · 4,15.
- ⚠️ **piso de 1,0**: `SandFX` declarava energia **0,8**. Aplicá-la ao albedo
  deixaria a areia mais **escura** — a correção viraria regressão silenciosa.

Fontes: `src/effects/FxUtil.gd:42-80`, `src/world/WorldEnv.gd:131-165`.

---

## 4. Iluminação e ar

**As cinco cenas de `captura_visual.gd`, antes da Fase 1:**

| cena | brilho médio | estourado | **PRETO** |
|---|---|---|---|
| `1_mundo` | 0,666 | 0,0% | **0,0%** |
| `3_perto` | 0,714 | 0,0% | 0,1% |

**Zero por cento de preto na tela inteira.** É o "chapado" virado número.

⚠️ E o chão **não** estava estourado (0,0% acima de 0,9), ao contrário do que a
inspeção visual afirmava. Ele é claro e **sem contraste** — outro problema, outro
remédio.

**A queda por altura da névoa foi a zero, medida, não estimada.** Cor lida no
meio do mesmo poço, em três condições:

| condição | cor |
|---|---|
| como estava (névoa on, fundo on) | (0,263 0,369 0,467) — azul lavado |
| sem névoa, fundo on | (0,000 0,000 0,000) — preto |
| sem névoa, fundo off | (0,000 0,000 0,016) — preto |

Duas conclusões, e as duas mudaram o desenho: quem lavava o poço era a **névoa
sozinha**, e o plano de fundo escuro que existia era **redundante** (foi
removido). A névoa de base (0,0020) ainda dá ~10% de lavagem em 55 m — o
gradiente suficiente para o poço ter profundidade sem virar chapa preta.

Fonte: `src/world/WorldEnv.gd:17-32` e `:214-231`.

---

## 5. Animação

### Deslize da marcha — a identidade que ninguém tinha escrito

```
deslize ≡ 1 − CADENCIA_ESCALA
```

**É identidade, não coincidência** (a velocidade do pé no apoio é `passada/π·ω`, e
ω já traz a passada no denominador — ela cancela), e vale enquanto `CADENCIA_MAX`
não morder. Consequências práticas:

- o deslize **não depende do porte**: `base` (perna 0,47 m) e `nami` (0,61 m) dão
  os mesmos **45%**;
- `CADENCIA_ESCALA` é a **única** alavanca de deslize que existe;
- ⚠️ os números anteriores no próprio arquivo diziam "8% de deslize". O real é
  **45%**.

**Comprar deslize com agachamento** (medido em `base`/WALK, cadência fixa):

| altura do quadril | passada | deslize | coxa |
|---|---|---|---|
| 0,80 × perna (hoje) | 0,49 m | 45% | 87° |
| 0,70 × perna | 0,59 m | 34% | 108° |
| 0,60 × perna | 0,65 m | 26% | 125° |

⚠️ **`PASSADA_GANHO` está INERTE no regime de jogo**: a passada pedida
(1,52 × perna a plena velocidade) estoura o teto geométrico (1,13 × perna) e é
cortada por ele. Trocar 1,6 por 1,3 **não muda um milímetro**; só abaixo de ~1,1 o
valor volta a ter efeito. É o tipo de alavanca que faz alguém passar uma tarde
"ajustando" nada.

⚠️ O personagem tem 1,5 m e anda a 4,2 m/s: casar o pé com o chão exige **~7,9
passos/s** — o dobro de um humano correndo. Era isso que deixava a animação
frenética.

Fonte: `src/anim/ProceduralAnimator.gd:14-50`.

### Anatomia dos clipes de soco (2026-08-11)

Sinal = **deslocamento do efetor** (punho/pé) em relação a t=0, por cinemática
direta no referencial do tronco. Foi o **único** dos três candidatos que acerta
soco reto, hook e chute: o desvio *angular* erra o chute em 0,22 s (a perna
continua girando na retração), e o alcance *frontal* erra o uppercut (que sobe).

| clipe | dur | membro | começa | **PICO = impacto** | acaba |
|---|---|---|---|---|---|
| `right_upper_hook_from_guard` | 1,77 s | braço D | 0,217 | **0,633** | 0,933 |
| `left_uppercut_from_guard` | 1,37 s | braço E | 0,217 | **0,367** | 0,783 |
| `kicking` | 2,30 s | perna D | 0,450 | **1,233** | 1,775 |
| `roundhouse_kick` | 2,17 s | perna E | 0,442 | **1,100** | 1,367 |

**Amplitude por braço** (soma UpperArm + ForeArm), que é o que provou que os dois
socos liam diferente:

| clipe | braço dominante | o outro | razão |
|---|---|---|---|
| `right_upper_hook_from_guard` | D 477° | E 144° | 3,3× |
| `left_uppercut_from_guard` | E 276° | D 56° | 4,9× |
| `punching` (o antigo, único) | E 210° | D 84° | 2,5× |

⚠️ **22% do clipe é pose de espera**: o `right_upper_hook_from_guard` só mexe o
braço aos **0,392 s de 1,77 s**. Sem `start` (que pula o começo), a única forma de
o soco conectar rápido é acelerar o clipe inteiro — e é a aceleração que borra
qual braço saiu.

⚠️ **Validar animação por contagem não funciona.** Número de faixas, de chaves ou
de canais dá "ok" num clipe totalmente congelado. Meça **amplitude por papel**.

Fontes: `src/combat/Melee.gd:18-41`, `src/anim/ProceduralAnimator.gd:118-127`.
⚠️ *`Melee.gd` está em obra em 2026-08-26.*

### Rig

- **`find_child` dos 13 papéis → `null`** nos 4 Meshy e no GLB novo, antes de
  criar os proxies. É o que garante que colisão de nome é impossível por
  construção — o `BodyScanner` só cria o driver quando **nenhum** nó do modelo se
  chama como um papel. (`src/anim/SkeletonDriver.gd:135-143`)
- **Tranco de recepção de dano: o tronco desloca 19,3°** e volta ao repouso
  sozinho, em 0,30 s ≈ 18 quadros. (`docs/MECANICAS.md`)
- **O soco da Gura sequestra o rig por 7,37 s** — o efeito colateral de
  `_apply_baked` fazer `return` no `update()`. É o motivo de a recepção de dano
  ser pose procedural e **não** clipe assado. (itens 37/38 da lista)

---

## 6. UI

| número | o que decidiu | onde |
|---|---|---|
| **`MatchHud.size = (0, 0)`** | `set_anchors_preset` **sozinho não mexe nos offsets** — ele recalcula para *manter* o retângulo atual, que era zero. O painel de kills ia parar em x = −320 (fora da tela) e o cronômetro em x = −75, em cima da barra de vida. **O painel nunca apareceu.** Use sempre `set_anchors_and_offsets_preset`. | `src/ui/MatchHud.gd:37-45` |
| **desligar pelo menu tirava o boneco e o canto continuava marcando `[x]`** | O painel de dummies virou **vista** relida todo quadro, com cache para não repintar à toa. O estado muda por três caminhos (esta tela, o ESC, qualquer script). | `src/ui/DummyToggleHud.gd:63-68` |

⚠️ A armadilha do `set_anchors_preset` foi redescoberta e comentada **quatro
vezes**, em quatro arquivos diferentes — `MatchHud.gd:37`, `AmmoHud.gd:62`,
`SniperScope.gd:51` e `DummyToggleHud.gd:50` (contado pelas linhas com `⚠️` que
citam o método, não pelas ocorrências do identificador, que somam 7 arquivos
porque os próprios comentários o mencionam). Quatro redescobertas do mesmo bug é
a definição de conhecimento que precisava de página.

---

## 7. Combate e balanceamento

| número | o que decidiu | onde |
|---|---|---|
| **755×** | Razão entre o golpe mais fraco (Goro C, 2,4) e o mais forte (Yami V, 1811) antes do `Balance.gd`. A ultimate da Yami tirava **88% de 2048** de uma vez; a da Gura, **1%**. Hoje a razão Z:V é ~8× no teto (200 → 768). | `src/combat/Balance.gd:47-49` |
| **8,3×** | O `DamageZone.DAMAGE_SCALE = 0,12` multiplicava só o que passasse por hitbox — seis efeitos chamavam `take_damage()` direto e entregavam o número cru, 8,3× mais forte. A constante **foi removida** em 2026-08-21. | `docs/frutas/README.md` |
| **24** | Multiplicadores literais (`damage * 2.5`, `* 0.35`, …) que viviam dentro dos arquivos de efeito. Viraram campos nomeados da spec. | `src/combat/Balance.gd:7-8` |
| **combo inteiro = 278** | De uma vida de 2048 (13,6%). É a regra que explica quase todo número do jogo: **quem mata é o buraco, não o dano**. | `src/combat/Balance.gd:205` |
| **+0,55 s de vantagem no acerto** | Não os +0,21 s que o plano previa. Sobram 0,35 s de folga sobre o startup seguinte: **o alvo não tem janela para agir entre os golpes**. | `docs/ESTADO_ATUAL.md` §4 |
| **o Gatling nunca nascia** | `trigger_skill_cooldown` era chamada antes de `pedir_cast`, e `pedir_cast` **também é o gate** que lê essa recarga: a skill travava contra ela mesma no mesmo quadro, nem segurando a tecla os 2,2 s inteiros. Medido em 2026-08-18 com `probe_gomu_c.gd`. | `src/player/cast_controller.gd:269-280` |
| **golpe da Suna: 142,4 contra 3–10** | 14× fora da escala. Causa: `take_damage()` direto, pulando o funil. | item 1 da lista |

---

## 8. O que este índice NÃO cobre

- **Frame data do combo M1** — mora em
  [`PLANO_COMBATE_BATTLEGROUNDS.md`](PLANO_COMBATE_BATTLEGROUNDS.md) §2.2, que é
  a fonte, e está em obra.
- **Números de dano por golpe** — a fonte é `src/combat/Balance.gd`, e repeti-los
  aqui criaria uma terceira tabela. As páginas por fruta em
  [`frutas/`](frutas/README.md) fazem a leitura de cada uma.
- **Medições que ainda não existem.** O que **nunca foi medido**: dano real em
  alvo humano jogando, alcance efetivo dos golpes de investida, e **qualquer
  coisa em rede com dois PCs de verdade** — as sondas cobrem loopback headless.
