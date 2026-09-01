# Combate corpo a corpo — documentação completa

**Última revisão:** 2026-08-31.
**Escopo:** tudo o que acontece quando o jogador clica sem fruta na mão — o
combo M1, as sete variações contextuais, as três rotas especiais, a defesa, e o
que a rede valida.

Os planos de onde isto veio continuam valendo como histórico:
`PLANO_COMBATE_CONTEXTUAL.md` (as seis fases), `PLANO_COMBATE_BATTLEGROUNDS.md`
(o combo em frame data) e `ESTILOS_DE_LUTA.md`.

---

## 1. A ordem de decisão

**Uma decisão, uma ordem fixa.** Todo clique passa por esta escada em
`MeleeController.pedir()`, e a primeira condição que bate vence. A intenção mais
específica ganha da mais genérica.

| # | condição | resultado |
|---:|---|---|
| 1 | Espaço + clique | Aú / estrelinha |
| 2 | no ar, alvo abaixo, altura de queda válida | queda esmagadora |
| 3 | Mink correndo, mordida disponível, alvo válido | investida → agarrão → chute |
| 4 | no ar, **com parede** ao lado, não gasto neste voo | chute de parede |
| 5 | no ar, sem parede | chute aéreo |
| 6 | no chão, sem sprint, A/D | esquiva lateral + gancho |
| 7 | no chão, sem sprint, S | chute recuando |
| 8 | no chão, sem sprint, W, **4º golpe do combo** | lançamento |
| 9 | no chão, sem sprint, W | cotovelada de avanço |
| 10 | qualquer outro caso | combo M1 |

⚠️ **A/D vence W/S** quando vêm juntos: uma esquiva lateral tem silhueta menos
ambígua que uma diagonal. E a rota Mink fica **acima** de toda variação
direcional, para não perder a identidade quando o jogador segura W + Shift.

---

## 2. O combo M1

Quatro golpes, encadeáveis dentro de **2,0 s** (`Melee.JANELA`). Passada a
janela, a sequência recomeça do primeiro.

| # | golpe | startup | ativo | recuperação | dano | knockback | alcance |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | Jab | 0,20 | 0,06 | 0,14 | 48 | 11 | 1,50 |
| 2 | Soco Esquerdo | 0,20 | 0,06 | 0,14 | 54 | 13 | 1,50 |
| 3 | Chute Lateral | 0,20 | 0,06 | 0,17 | 64 | 15 | 2,00 |
| 4 | Finalizador | 0,25 | 0,08 | 0,35 | 112 | 26 | 2,20 |

**O M1 não prende o corpo.** O jogador anda e pula enquanto soca. Isso mudou em
2026-08-31, revogando o pedido de 2026-08-15 ("não vai ser possível se mover até
que a animação se encerre") — nas palavras do dono, *"travava o jogador demais,
fazendo os movimentos não serem tão fluidos"*. A única exceção é a mordida Mink,
que controla a própria velocidade enquanto segura o alvo.

---

## 3. As variações contextuais

A direção que o jogador segura **no instante do clique** escolhe a intenção. Os
números são finais contra a vida de 2048.

| entrada | id | startup | ativo | recuperação | dano | deslocamento |
|---|---|---:|---:|---:|---:|---|
| W | `context_elbow` | 0,14 | 0,08 | 0,20 | 60 | frente, 1,00 |
| S | `context_retreat_kick` | 0,15 | 0,08 | 0,23 | 56 | trás, 0,85 |
| A | `context_side_hook_l` | 0,16 | 0,08 | 0,24 | 58 | esquerda, 1,10 |
| D | `context_side_hook_r` | 0,16 | 0,08 | 0,24 | 58 | direita, 1,10 |
| W no 4º | `context_launcher` | 0,18 | 0,09 | 0,26 | 72 | frente, 0,55 |
| no ar | `context_air_kick` | 0,12 | 0,08 | 0,22 | 54 | frente, 0,70 |
| no ar + parede | `context_wall_kick` | 0,10 | 0,08 | 0,24 | 58 | frente, **1,45** |

**Todas dão menos que o finalizador (112), e isso é regra, não acaso:** elas
compram POSIÇÃO, não explosão de dano. Nenhuma tem recarga própria — o custo é a
recuperação e a punição de errar.

### A direção é congelada no primeiro quadro

`attack_basis` é capturada quando o clique é aceito. Depois disso a câmera pode
girar à vontade: o corpo, a hitbox, o deslocamento e o VFX do golpe já
comprometido **não** acompanham. É a mesma falha que a Aú tinha antes de
capturar a própria direção.

### No ar existe UMA opção, não quatro

As direções não se ramificam no ar. O corpo já está comprometido com uma
trajetória, e quatro variações aéreas dariam ao jogador no ar mais escolhas do
que ele tem no chão — o contrário do que a frente quer.

---

## 4. Counter hit

Acertar quem está em **startup** — a janela entre o clique e a hitbox nascer —
rende **tempo, não estrago**:

- dano: **não sobe** (o prêmio é ele ficar parado e longe, não um pico que
  encurtaria a luta);
- hitstun: **155%**;
- empurrão: **+45%**.

⚠️ **A fase do alvo é lida ANTES do dano.** `hit_landed` chega tarde: quando
dispara, o `take_damage` já interrompeu o golpe do alvo, e a pergunta "ele estava
em startup?" responderia sempre falso — o counter nunca aconteceria, sem erro e
sem aviso. Por isso existe `DamageZone.antes_do_acerto`.

Quem decide é o **servidor**, porque é lá que a `DamageZone` nasce.

---

## 5. Launcher e perseguição aérea

No **quarto** golpe do combo, W vira lançamento: 72 de dano e impulso vertical
de 15. Nos três primeiros a cotovelada continua valendo.

O chute aéreo é a **perseguição**: ele sustenta o alvo no ar (+7 vertical), mas
**só na primeira vez por lançamento**.

### Os três bloqueios contra loop

⚠️ **É o requisito, não um detalhe.** Um launcher que funciona e não bloqueia é
pior que nenhum: lançar → perseguir → lançar prende o alvo no ar e decide a luta
sem o outro jogar.

1. um corpo **já no ar por lançamento** não é lançado de novo;
2. a marca se limpa **sozinha** ao tocar o chão — ninguém precisa lembrar de
   apagá-la, e quem caiu volta a ser lançável numa troca posterior;
3. a segunda perseguição **acerta** (dano, empurrão, hitstun) mas **não
   sustenta**, e o alvo cai. Quebra o loop sem tirar a chance de encostar.

---

## 6. Chute de parede

No ar, com parede ao lado, **uma vez por contato**. Deslocamento de 1,45 — o
maior de todas as variações, porque o valor dele é o REPOSICIONAMENTO.

- o raycast varre **quatro direções horizontais**, e não a do movimento: o
  jogador pode estar caindo parado ao lado de um muro, sem direção nenhuma;
- valida a **normal** (`|n.y| < 0,35`, a mesma régua do wall run). Um raycast que
  só pergunta "bateu em algo?" aceitaria o piso, e o chute viraria impulso grátis
  perto do chão;
- é marcado como gasto no instante em que o golpe é **aceito**, não no acerto —
  marcar no acerto deixaria chutar a parede infinitas vezes desde que errasse.

---

## 7. Defesa — Corpo de Ferro (F)

Janela de **1,0 s**, recarga de **30 s**. Duas metades que andam em sentidos
opostos, e é isso que lhe dá identidade em vez de "um segundo de imunidade":

| | antes de 2026-08-31 | agora |
|---|---|---|
| dano | invulnerabilidade total | **metade** — quem aperta F ainda apanha |
| efeitos | lista fixa de quatro | **qualquer um**, e os já em ação saem |

O corte fica no começo do `take_damage`, não só na subtração da vida: o `amount`
segue para o número que sobe na tela e para o RPC que leva a vida ao dono, e
cortar mais adiante mostraria um número diferente do que o jogador tomou.

A recusa de efeitos mora em `StatusFX.aplicar`, o único ponto por onde todo
status entra — uma lista dentro do controlador precisaria ser atualizada a cada
efeito novo, e o primeiro esquecido furaria a imunidade em silêncio.

---

## 8. A rede

O servidor é a autoridade de dano. O cliente prevê pose, deslocamento e VFX para
a resposta ser imediata, mas **não pode criar uma `DamageZone` que machuque**.

1. o cliente captura o input e mostra a ação na hora;
2. o pedido leva só `id`, origem e direção congelada;
3. o servidor rejeita: id desconhecido, arma equipada, vetor inválido, origem
   distante, recuo contra cenário, repetição antes da cadência mínima — e chão,
   **quando o golpe exige chão**;
4. só o servidor instancia `DamageZone`;
5. o servidor difunde apenas a apresentação (`id` + direção); cada cliente monta
   pose e VFX localmente.

### ⚠️ A exigência de chão é POR GOLPE

A validação recusava todo contextual fora do chão. Era correta enquanto as
variações eram todas de solo, e teria barrado o chute aéreo e o de parede **em
rede** — passando no singleplayer, onde o cliente é o servidor. O tipo de bug que
só aparece com duas máquinas. A exceção é declarada na ficha (`no_ar`).

---

## 9. Onde cada coisa mora

| arquivo | responsabilidade |
|---|---|
| `src/combat/Melee.gd` | a tabela do combo M1 e o frame data dele |
| `src/combat/contextual_melee.gd` | fichas das variações, resolvedor, counter, lançamento, sustento e a detecção de parede |
| `src/player/melee_controller.gd` | a ordem de decisão, o relógio único de fase e a punição de whiff |
| `Player.gd` | congela a direção, aplica root motion, atravessa a rede e apresenta |
| `src/player/iron_body_controller.gd` | a defesa (F) |
| `src/combat/StatusFX.gd` | aplica e recusa efeitos; é onde a imunidade do Corpo de Ferro vive |
| `src/effects/DamageZone.gd` | a hitbox, e os sinais `antes_do_acerto` / `hit_landed` |
| `src/combat/CombatResolver.gd` | o funil por onde TODO dano passa, com o orçamento por conjuração |

## 10. Os testes

| teste | o que guarda |
|---|---|
| `test_ataques_contextuais.gd` | resolver, prioridade, pose, VFX, root motion, direção congelada e limpeza |
| `test_counter_hit.gd` | a regra do counter, a leitura da fase e a **ordem dos sinais** |
| `test_launcher.gd` | launcher, perseguição, chute de parede e a exigência de chão por golpe |
| `test_corpo_de_ferro.gd` | meio dano e imunidade a qualquer efeito |
| `test_melee_trava.gd` | que o M1 **não** prende o corpo |
| `test_chute_giratorio.gd` / `test_ataque_aereo.gd` / `test_mink_combate.gd` | que as três rotas especiais continuam acima das variações |
| `net_contextual_*_probe.gd` | o caminho completo em **dois processos** |
