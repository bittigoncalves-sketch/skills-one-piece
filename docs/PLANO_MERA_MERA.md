# Plano de remodelação da Mera Mera no Mi

**Escrito em 2026-09-08.** Régua: a Ope Ope no Mi, entregue pelo Codex em
2026-09-07, hoje a melhor fruta do jogo. Este plano mede a Mera contra ela e
propõe o caminho — **nada aqui foi implementado ainda**.

Leia antes: [`PLANO_FRUTAS.md`](PLANO_FRUTAS.md) (os 6 critérios de fruta
funcional), [`frutas/mera_mera.md`](frutas/mera_mera.md) e
[`frutas/ope_ope.md`](frutas/ope_ope.md).

---

## 1. A régua: por que a Ope é a melhor (medido)

Não é dano e não é empurrão. Medido nas chamadas de `setup()`:

| golpe | knockback |
|---|---|
| Ope C (Takt) | **7,0** |
| Ope V (Gamma Knife) | **10,0** |
| Mera X (Hiken) | **35,0** |
| Mera V (explosão) | **18,0** |

A Ope empurra **menos** que a Mera e ainda assim ganha. O que ela tem:

1. **Um recurso que fecha a porta.** O ROOM (18 m, 18 s) é estado persistente, e
   X/C/V exigem estar dentro dele. Toda vez que o jogador aperta Z ele decide
   *onde vai lutar*. Nenhuma outra fruta tem uma decisão antes do golpe.
2. **Controle de posição.** O Shambles troca o jogador de lugar com o inimigo:
   0 de dano, 6 s de recarga. **Neste mapa quem mata é o buraco** — teleportar
   alguém vale mais que qualquer knockback do jogo.
3. **O jogo diz por que falhou.** `OpeController.validation_reason()` devolve uma
   string e a HUD mostra. Nenhuma outra fruta faz isso: nas outras, cast negado é
   silêncio.
4. **Recuperação por coreografia**, não por tabela: 0,85 / 0,65 / 1,65 / 0,95 s,
   e **isenta da trava global de 5 s** (`Player.trigger_skill_cooldown` tem um
   `return` só para `ope_ope`).
5. **Apresentação própria**: 4 poses dedicadas, 5 sons sintetizados, GLB próprio,
   3 shaders, 4 ícones.
6. **Ferramental próprio**: `jogar_ope.sh`, `tools/ope_preview.gd`,
   `tools/validate_ope.py`, `tools/generate_ope_audio.py`,
   `tools/blender/ope_ope_assets.py`.
7. **70 asserções** em 4 testes dedicados, incluindo rede ENet real.

---

## 2. Onde a Mera está (medido em 2026-09-08)

| | Ope Ope | Mera Mera |
|---|---|---|
| arquivos dedicados | **12** (1.362 linhas) | 3 (974 linhas) + lógica em 3 compartilhados |
| recurso / porta de entrada | ROOM | **nenhum** |
| controle (posição, negação) | Shambles | **nenhum** |
| feedback de cast negado | `validation_reason()` | **nenhum** |
| poses dedicadas | 4/4 (`OpePoses.gd`) | **2/4**, dentro de `FruitPoses.gd` (só Z e X) |
| sons próprios | 5 `.wav` sintetizados | **0** (17 chamadas ao banco genérico `AudioFX`) |
| modelos | `assets/models/ope_ope/` + fonte Blender | **0** (voxel montado em código) |
| shaders | 3 | **0** |
| ícones | 4 vetoriais | **0** |
| trava global de 5 s | **isenta** | sujeita |
| asserções de teste | **70** em 4 testes | **0** em 1 teste (`test_mera_z_saque`) |
| ferramental | 5 scripts | **0** |

### 2.1 A documentação da Mera é o artefato menos confiável dela

O [`frutas/mera_mera.md`](frutas/mera_mera.md) lista quatro ⚠️ pendências.
Medido no código de hoje, **três já estavam corrigidas desde 2026-08-22** e
ninguém atualizou o documento:

| pendência do doc | estado real |
|---|---|
| "o X perde a explosão quando ACERTA" | **corrigida** — `FireFX.gd:325-337`, a explosão nasce nos dois gatilhos |
| "a carga do V nunca chega ao sol cheio" | **corrigida** — `FireFXGrande.gd:362` usa `_spec.tempo_de_carga` |
| "carregar o V não muda o total de dano" | **corrigida** — `FireFXGrande.gd:473` usa `valor_do_hit(_carga)` |
| item 21: `look_at` antes do `add_child` | **ABERTA** — `FireFX.gd:211`, só dispara em sonda |

E os números do doc estão velhos: ele diz **Z 12 × 16** e **V 512→768 em 3,5 s**;
o `Balance.gd` de hoje diz **Z 25 × 8 (teto 200)** e **V 512→640 em 1,5 s**.

Os comentários no código mentem junto: `FireFX.gd:4` anuncia os slots como
"Higan (Z), Hiken (X), **Hibashira (C)** e **Inferno (V)**" — dois golpes que não
existem mais. `FireFXGrande.gd:429` fala em orçamento de 384; são 640.

**Consequência prática:** qualquer agente ou pessoa que chegar frio nesta fruta
recebe um mapa errado. Foi por isso que a Fase 0 vem antes de tudo.

---

## 3. O que a Mera é hoje, como jogo

Quatro slots, quatro projéteis:

| tecla | golpe | tabela | pergunta que responde |
|---|---|---|---|
| Z | Higan (rajada) | MULTI 25 × 8, teto 200 | dano à distância |
| X | Hiken | MULTI 160 + 96, teto 256 | dano à distância |
| C | Vagalumes | ÚNICO 256, teto 384 | dano à distância (com atraso) |
| V | Entei | CARREGADO 512→640 | dano à distância (carregado) |

**A fruta responde a mesma pergunta quatro vezes.** Não tem mobilidade, não tem
controle, não tem recurso, não tem decisão antes do golpe. É a definição de kit
sem identidade — e nenhum ajuste de número conserta isso.

Dois desperdícios medidos:

- **O C é espetáculo caro.** 45 `Area3D` com luz própria, raio de explosão 8,0,
  **knockback 6,0** — o menor da fruta. Como todas dividem o teto de 384, o valor
  todo sai em "uma explosão e meia": as outras 43 são enfeite. Um golpe de área
  gigante que quase não empurra, num mapa onde empurrar é o que mata.
- **O C nasce no conjurador, não na mira** (`FireFX.gd:20`). Sem ninguém a menos
  de ~20 m, a nuvem deriva até se detonar sozinha aos 20 s. Contra alguém longe,
  o C é um botão que não faz nada.

---

## 4. A tese de design

> **A Ope controla ONDE. A Mera deve controlar POR QUANTO TEMPO.**
>
> A Ope pega o inimigo e o move. A Mera nega o chão e força o inimigo a se mover
> sozinho — de preferência para perto do buraco.

Negação de área é o nicho **vago** do jogo: nada hoje deixa perigo parado no
chão. Num mapa onde o buraco mata, chão em brasa é um segundo buraco — só que
você escolhe onde colocar.

E a identidade da Mera **já está escrita no projeto, só nunca foi construída**.
`FruitPassiveSystem.gd` declara:

> "Combustão Progressiva (Overheat Charges) — Cada skill gera 1 carga de Chama.
> Com 5 cargas, o próximo ataque estoura em explosão de Fogo em área e +25%
> velocidade."

Só o `speed_mod 1,15` existe em código. **As cargas nunca foram implementadas.**
Isso não é inventar uma fruta nova: é entregar a que já foi projetada.

Assim as duas frutas passam a ter recursos de naturezas diferentes — e é isso
que faz um elenco, em vez de duas cópias:

| | Ope | Mera |
|---|---|---|
| recurso | ROOM — de **lugar** | Overheat — de **tempo** |
| como se ganha | apertando Z e escolhendo o terreno | **acertando** golpes |
| como se perde | sair, morrer, trocar de fruta, 18 s | gastando, ou esfriando |
| decisão do jogador | *onde eu quero lutar?* | *gasto agora ou aguento mais um?* |

---

## 5. As fases

### Fase 0 — Verdade (faça primeiro, é barata)

1. Reescrever [`frutas/mera_mera.md`](frutas/mera_mera.md) com os números do
   `Balance.gd` de hoje e as três pendências fechadas.
2. Corrigir os comentários que mentem: `FireFX.gd:4`, `FireFX.gd:347`,
   `FireFXGrande.gd:4`, `:424`, `:429`.
3. **Apagar o Hibashira legado** (`FireFXGrande._hibashira_legado`, sem chamador)
   e, junto com ele, o item 13 (`set_meta("is_suppressed")` que ninguém lê).
4. ⚠️ **Apagar a imunidade adormecida.** A pose `"hibashira"` concede
   **imunidade a dano** em três lugares: `Player.gd:2225`,
   `src/entities/TrainingDummy.gd:117` e `disabled/enemies/Enemy.gd:129`.
   (O `frutas/mera_mera.md` cita `TrainingDummy.gd:107` — o número está velho, a
   linha é a **117**.) Nada liga essa pose hoje; se um golpe futuro usar esse
   nome, ganha invulnerabilidade sem ninguém decidir isso.

⚠️ **A pose está mais enraizada que o golpe — separe as duas coisas.** Além do
`FireFXGrande._hibashira_legado`, existem `FruitPoses.hibashira_pose` e quatro
pontos no `ProceduralAnimator` (`:105`, `:381`, `:449`, `:519`), sendo que o
`:449` é o produto `upper_free`, que mistura os pesos de **todas** as poses de
fruta. Mexer ali toca a animação de todo o elenco. **Recomendo:** nesta fase,
apagar só o golpe morto e a imunidade; deixar a pose para uma passagem própria,
com o traço medido antes e depois.

**Por que primeiro:** todas as fases seguintes leem estes arquivos, e a armadilha
do item 4 é a única coisa aqui que pode explodir sozinha.

### Fase 1 — O defeito que sobrou

Item 21: `FireFX.gd:211` chama `mmi.look_at()` **antes** do `add_child`, então o
transform global é inválido e o tiro nunca é orientado — 16 ocorrências por
conjuração. Só dispara em sonda hoje (o `CastController` intercepta o Z), mas
sujeita o `test_frutas` a ruído. Uma linha.

### Fase 2 — Combustão Progressiva: o recurso

Implementar as cargas declaradas. **Decisão estrutural D1, abaixo.**

- Um componente `src/combat/MeraHeat.gd` com: cargas 0–5, ganho por **acerto**
  (não por uso — senão o jogador aquece batendo no vazio), decaimento por tempo
  sem acertar, e `validation_reason()` no molde da Ope.
- HUD: indicador de cargas, no molde do `OpeRoomHud`.
- Com 5 cargas: o próximo golpe ganha a explosão em área e o `speed_mod` sobe
  para 1,25 pela duração declarada.

**Ganhar por acerto, não por uso, é o ponto.** Ganhar por uso premiaria apertar
tecla; ganhar por acerto premia jogar bem e dá ao adversário como negar o
recurso — que é o que falta na Ope hoje.

### Fase 3 — O kit em volta do recurso

| tecla | destino | papel |
|---|---|---|
| **Z** Higan | **mantém** | o motor: barato, seguro, sem travar o corpo; é o que aquece |
| **X** Hiken | **mantém** | o finalizador: kb 35, o maior da fruta — é o que joga no buraco |
| **C** Vagalumes | **substituir por negação de área** | ver D2 |
| **V** Entei | **mantém como ultimate** | a carga passa a poder ser encurtada por Overheat |

O C vira **chão em brasa colocado na mira** (não no conjurador — corrige o
defeito de alcance de graça): dano por tempo, knockback zero, duração na casa
dos segundos. Não mata: **expulsa**. É o equivalente Mera do Shambles — controla
espaço sem teleportar ninguém.

### Fase 4 — Paridade de apresentação  ✅ PARTE VISUAL FEITA (2026-09-08)

> **Feito:** a camada de desenho da fruta. Ver a seção 10 no fim deste
> documento. **Falta:** poses (2/4), banco de som próprio e ícones.

- `src/anim/MeraPoses.gd` com as **4** coreografias (hoje existem 2, e só de
  preparo). Validar em **espaço local** do personagem, como manda
  [`AGENTES.md`](AGENTES.md) — rótulo não é medida.
- `tools/generate_mera_audio.py`: banco de sons próprio. **O gerador é a fonte
  canônica; nunca editar `.wav` à mão** (regra da casa, e foi o que salvou a Pika).
  ⚠️ Todo `.wav` novo precisa de `.import` — sem ele o `ResourceLoader` devolve
  `null` e a fruta fica **muda com bateria verde**.
- Shader do chão em brasa, no molde de `ope_floor.gdshader`.
- 4 ícones.

### Fase 5 — Paridade de validação

- `test_mera_integracao`, `test_mera_combate`, `test_mera_animacoes`,
  `test_mera_rede` — a Mera tem **0 asserções** hoje contra 70 da Ope.
- `jogar_mera.sh` e `tools/validate_mera.py`, espelhando os da Ope.

---

## 6. As duas decisões estruturais

### D1 — Um `MeraHeat` (recurso), **não** um `MeraController` (reescrita)

A Ope tem um controlador de 425 linhas que é dono de tudo. A tentação é copiar.
**Recomendo não copiar**: mover Z/X/C/V para um controlador novo é reescrever
VFX que já funcionam e já são cobertos pelo `test_frutas`. Criar só a camada de
decisão — o recurso, a validação e o feedback — e deixar `FireFX`, `FirefliesFX`
e `FireFXGrande` onde estão, lendo o recurso.

| | |
|---|---|
| **Benefício imediato** | a Mera ganha decisão e feedback sem tocar em efeito que funciona |
| **Impacto futuro** | `MeraHeat` é o molde de "recurso de fruta" para a próxima; a Ope viraria o molde de "controlador de fruta" |
| **Manutenção** | o recurso fica num arquivo só; hoje a lógica da Mera está espalhada por 6 |
| **Extensão** | qualquer slot novo lê o recurso sem saber dos outros |
| **Custo** | baixo — um componente + HUD, contra a reescrita dos 4 slots |
| **Riscos** | a lógica dos slots continua espalhada; se um dia a Mera precisar de coreografia encadeada como a Ope, o controlador volta à mesa |

**Horizontes.** H1: resolve com pouco código e sem regressão. H2: cria o
vocabulário de recurso, que Gura e Pika também vão querer. H3: se três frutas
tiverem recurso, a camada sobe para um `FruitResource` genérico.
**GATILHO para reabrir:** quando um segundo slot da Mera precisar travar o corpo
com coreografia própria, ou quando `FireFX.gd` passar de 900 linhas.

### D2 — O C vira negação de área, e os Vagalumes saem

| | |
|---|---|
| **Benefício imediato** | tira o único golpe que não funciona a distância e resolve o nicho vago do jogo |
| **Impacto futuro** | chão perigoso é mecânica reaproveitável (Magu Magu, armadilhas, o próprio mapa) |
| **Manutenção** | uma zona persistente é mais simples que 45 `Area3D` com luz e deriva |
| **Extensão** | a duração e o raio viram os dois botões de balanceamento |
| **Custo** | médio — é o único golpe realmente novo do plano |
| **Riscos** | zona persistente + rede é onde nascem dessincronias; e **apaga um golpe que o dono pediu em 2026-08-21** |

**Horizontes.** H1: o C passa a fazer algo em toda distância. H2: abre negação de
área para o resto do elenco. H3: se virar padrão, sobe para um
`AreaDenialZone` compartilhado.
⚠️ **Este é o item mais reversível de se arrepender e o mais caro de se enganar.**
Os Vagalumes foram um pedido explícito; trocá-los é decisão sua, não minha.

---

## 7. Decisões que são suas

1. ~~**A trava de 5 s.**~~ **DECIDIDO em 2026-09-08 pelo dono:** a Ope **não**
   recebe a trava por enquanto. A trava é uma **medida experimental** para
   forçar combate direto, não uma regra assentada do balanceamento — então não
   faz sentido propagá-la para uma fruta enquanto ela mesma está em teste.
   A assimetria fica registrada e consciente: o `return` de `ope_ope` em
   `Player.trigger_skill_cooldown` **permanece**.
   **GATILHO para reabrir:** quando a trava deixar de ser experimental (virar
   regra ou ser removida), a Mera e a Ope têm que ficar sob o mesmo critério.
2. **Os Vagalumes saem?** (D2)
3. **O Ace.** `ELENCO_LIBERADO` é `["base", "bluebuddy"]`, então equipar a Mera
   não troca a aparência. Destravar o Ace junto, ou manter o elenco fechado?
4. **O escopo.** Fases 0–1 (arrumar e documentar, barato) ou 0–5 (a remodelação
   inteira)?

---

## 8. Critérios de aceitação (medidos, não julgados)

Além dos 6 critérios do [`PLANO_FRUTAS.md`](PLANO_FRUTAS.md), a Mera remodelada
só fecha quando:

| # | critério | medida |
|---|---|---|
| 7 | tem recurso | as cargas sobem por acerto e caem por tempo, com número no HUD |
| 8 | diz por que negou | cast inválido devolve string, como `validation_reason()` |
| 9 | os 4 slots respondem perguntas diferentes | alcance, kb e duração medidos, sem dois iguais |
| 10 | coreografia em 4/4 | validada em espaço local, não por rótulo |
| 11 | som próprio | banco gerado por script, com `.import`, carregando sem `null` |
| 12 | testado | ≥ 60 asserções, incluindo um teste de rede ENet real |

---

## 9. O que este plano NÃO faz

- **Não mexe na Ope.** Ela é trabalho do Codex e está não commitada na árvore.
- **Não regrava** `traco_esperado.txt` (item 52) nem toca nas 5 falhas
  pré-existentes da bateria.
- **Não decide** nenhum dos quatro itens da seção 7.

---

## 10. O que foi feito em 2026-09-08 — a camada visual

**Escopo:** aprimoramento visual com a Ope como régua. **Nenhum arquivo da Ope
foi tocado** — só lidos, para copiar o padrão.

### O padrão que veio da Ope

O `OpeGeometry.gd` abre com uma frase que é a tese inteira:

> *"Original surgical geometry shared by the Ope effects. **No particles or
> dynamic lights.**"*

A Ope desenha com **malha procedural** e shader — anéis, linhas, arcos, agulhas
— e não com partícula. É por isso que ela lê bem: partícula é uma nuvem de
quadrados virados para a câmera, que **não tem silhueta**. A régua da casa é ler
o golpe pelo contorno (`docs/AGENTES.md`), e contorno pede volume.

E o `OpeVfx.gd` separa desenho de jogo: *"Visual API. Gameplay owns hit
detection, authority and ROOM lifetime."* Enquanto o visual mora no mesmo
arquivo que cria `DamageZone`, mexer na aparência é mexer em balanceamento.

### O que a Mera ganhou

| arquivo novo | papel | equivalente na Ope |
|---|---|---|
| `src/fx/shaders/mera_flame.gdshader` | corpo de chama: gradiente de calor no eixo local +Y, ruído que sobe, borda de silhueta | `ope_room.gdshader` |
| `src/fx/shaders/mera_ember.gdshader` | superfície sólida quente: crosta deslocada no vértice + fenda de magma pulsando | `ope_rock.gdshader` |
| `src/fx/shaders/mera_scorch.gdshader` | chão queimado, esfriando de fora para dentro | `ope_floor.gdshader` |
| `src/effects/MeraGeometry.gd` | primitivas de fogo: língua, coroa, anel, brasa, casca, queimadura | `OpeGeometry.gd` |
| `src/effects/MeraFireBurst.gd` | fogo transitório: clarão, impacto, explosão, marca | `OpeSurgicalBurst.gd` |
| `src/effects/MeraEmberBody.gd` | corpo quente persistente: punho, sol, rastro | `OpeRoomField.gd` |
| `src/effects/MeraVfx.gd` | fachada estática; **não causa dano** | `OpeVfx.gd` |
| `tools/dev_tests/test_mera_visual.gd` | **27 asserções medidas** | `test_ope_*.gd` |
| `tools/mera_preview.gd` + `jogar_mera.sh` | abre a arena com a Mera; `-- --capture` salva as fases em PNG | `tools/ope_preview.gd` + `jogar_ope.sh` |

### O que mudou na tela

| golpe | antes | agora |
|---|---|---|
| **X** Hiken | `MultiMesh` de ~60 caixas laranjas chapadas + 200 partículas | crosta de brasa com fenda acesa + coroa de chama escorrendo para trás |
| **Z** Higan | rastro de 18 partículas, sem clarão de saída | rastro em malha + **clarão de cano** nos 8 tiros |
| **V** Entei | cubo amarelo + 24 caixas **sorteadas com `randf_range`** | Sol Quadrado determinístico em crosta de magma, com coroa |
| **C** Vagalumes | 100 partículas × 45 estouros = **4.500** na cascata | estouro em malha de custo reduzido (3 línguas, sem consulta de chão) |
| explosão | 700 partículas | as mesmas 700 **mais** anel de choque e queimadura no chão |

⚠️ **Nada de jogo mudou.** Mesma hitbox, mesmo dano, mesma velocidade, mesmo
tempo de vida, mesmo `DamageSpec`. Só o desenho.

### Verificado

| medida | resultado |
|---|---|
| `test_mera_visual` | **27 verificações, 0 falhas**, sem um único ERROR no log |
| `test_frutas` (critérios 4, 5 e 6) | **Mera 4/4 com hitbox e zero vazamento** — Z 7 nós, X 19, C 565, V 72 |
| erros de `add_child` recusado **vindos da fachada visual** | **0** (era 1, no `MeraVfx`, antes do anexo adiado) |
| erros de `add_child` recusado no total | **20**, e nenhum é da camada nova — ver abaixo |
| arquivos da Ope alterados | **0** — todos com mtime anterior ao trabalho, conferido no `stat` |
| bateria completa (`./validar.sh`) | **68 passou / 6 falhou / 0 pulado** — era 67/6 antes; o +1 é o próprio `test_mera_visual`, e as 6 reprovações são **exatamente a mesma lista** de antes (`test_balance`, `test_buki_buki`, `test_morte_limpa_cast`, `test_trava_fruta_dano`, `net_mp_probe`, `traco_locomocao`). **Zero regressão.** |

⚠️ **Os 20 `add_child` recusados que sobraram são pré-existentes**, e não somem
com este trabalho. Contados pelo quadro `[0]` do backtrace, na rodada limpa:

| origem | ocorrências | o que é |
|---|---|---|
| `AudioFX.gd:64` | 10 | o tocador de som, chamado de dentro do `_higan` |
| `FireFX.gd:247` | 8 | partículas do `_higan` — caminho que **só roda em sonda** |
| `FireFX.gd:303` | 1 | partículas da explosão do Hiken |
| `FireFXGrande.gd:285` | 1 | **a `DamageZone` da explosão** — este é o item 57 |

### Cinco defeitos que o teste pegou (e que o olho não pegaria)

1. **O sol era diferente em cada máquina.** `_build_sun_model` sorteava as 24
   erupções com `randf_range` — cada peer construía o SEU sol. Agora a silhueta
   é determinística, e o teste prova (`a mesma semente reconstrói a MESMA
   malha`).
2. **O `add_child` era recusado e o efeito sumia sem aparecer.** O Hiken cria a
   explosão de dentro de um `tree_exiting`; nesse instante o pai está bloqueado
   e o Godot recusa filhos novos — `Parent node is busy setting up children`.
   A fachada passou a anexar de forma adiada, **com o `ObjectID` do pai** (uma
   lambda que captura o nó já liberado registra outro erro) e liberando o efeito
   se o pai não existir mais, para não virar órfão fora da árvore.
   ⚠️ **Na mesma pilha, a `DamageZone` da própria explosão também falha** — isso
   é defeito de jogo, pré-existente e NÃO consertado: item 57 da lista.

3. **O punho ficava comprido de través.** O núcleo é alongado 1,22× em Z para
   ler como punho em vez de bola. O código antigo orientava o `MultiMesh` com
   `Basis.looking_at`; ao trocar a malha eu perdi isso, e o alongamento passou a
   apontar para o Z do mundo em vez da direção do voo. Sem erro nenhum no log.
   O teste mede o produto escalar do eixo com a direção do tiro (hoje 1,0000).

4. **A ponta das chamas mais longas sumia.** O `mera_flame` normaliza o
   gradiente por `span`, e o `plume` sorteava comprimentos até **1,14×** disso —
   a ponta caía em h=1, onde a erosão apaga tudo. O fogo saía mais curto do que
   o pedido, silenciosamente. A variação passou a ser só para baixo (0,72 a
   1,00) e o teste trava o invariante.

5. **A queimadura nascia no lugar errado.** `_ready()` dispara dentro do
   `add_child`, e quem chama só escreve `global_position` **depois** — então o
   raio que procura o chão era traçado da **origem do mundo**. Num mapa com
   buracos isso desenha marca de fogo onde não houve fogo. A marca passou a ser
   montada no primeiro quadro. (A Ope evita o mesmo buraco com um
   `project_floor()` chamado **depois** de posicionar.)

### Quatro defeitos que só a CAPTURA pegou

O teste mede geometria; ele não sabe se ficou bonito. Foram precisas três
rodadas de `./jogar_mera.sh -- --capture` para achar estes, e nenhum deles
aparece em asserção nenhuma:

1. **O punho tinha virado um meteoro.** Na primeira versão troquei os ~60 blocos
   autorados por uma esfera achatada. Fica melhor de superfície e **perde a
   silhueta** — e "Hiken" é *Punho* de Fogo. Foi o mesmo erro que eu tinha
   evitado conscientemente no Sol Quadrado, cometido no golpe ao lado. Os blocos
   voltaram; o que mudou em relação ao original é a superfície, não a forma.
2. **Os blocos liam como parede de tijolos.** Restaurada a forma, cada cubo
   desenhava a **mesma** fenda — num `MultiMesh` todos compartilham o `VERTEX`
   local. As juntas viraram argamassa. `INSTANCE_CUSTOM` passou a carregar a
   POSIÇÃO do bloco dentro do punho, então a rachadura atravessa os blocos e a
   peça lê como uma coisa só.
3. **A explosão estourava a tela.** O anel de choque era branco (`CORE`), com
   energia 2,6 e largura 0,14, em mistura aditiva: apagava o cenário inteiro.
   Virou laranja (`MID`), energia 1,3, largura 0,07, com queda acelerada.

E um quarto, achado pela mesma via: **o sol lia como asteroide preto**. Duas
causas somadas — o ruído das fendas não era normalizado pelo tamanho do corpo
(a mesma frequência num punho de raio 1 e num sol de raio 7 vira chuvisco), e
o `set_heat` **nunca era chamado**: a carga mudava escala e luz, mas não o
calor da crosta. Hoje o `feature_scale` normaliza e o `update_charge` acende.

> **A lição, para a próxima fruta:** teste de geometria e captura de tela pegam
> conjuntos DISJUNTOS de defeito. Os cinco da seção anterior eram invisíveis a
> olho nu; estes quatro passavam com 27 asserções verdes.

### O que NÃO foi feito, e por quê

- **As poses continuam 2/4.** Coreografia é outro ofício e precisa de validação
  em espaço local; está na Fase 4 do plano.
- **O som continua o banco genérico.** Um banco próprio precisa de
  `tools/generate_mera_audio.py` e dos `.import` — sem `.import` o
  `ResourceLoader` devolve `null` e a fruta fica **muda com bateria verde**.
- **`_procedural_sun_fallback` continua sem chamador.** Ela desenha o Entei
  **com rosto** (olhos, boca, dentes). É arte autorada e não se apaga inventário
  desenhado. **GATILHO:** quando o dono escolher entre o sol liso e o sol com cara.
- **Os 45 vagalumes continuam 45.** Reduzir a nuvem é decisão de jogo (D2), não
  de visual.
- ⚠️ **O Z não foi verificado na tela.** A rajada real vem do
  `DisparoSustentado`, disparado pela TECLA SEGURADA; o
  `_do_server_cast("Z", ...)` do capturador cai no `_higan`, que é o outro
  caminho e não roda em jogo. As capturas `01`/`02` saem vazias por isso, não
  porque o clarão falhou. **Para conferir:** abrir `./jogar_mera.sh` e segurar Z.
