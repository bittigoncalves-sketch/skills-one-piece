# Mecânicas de combate

As dez mecânicas que o dono listou em 2026-08-14, o que cada uma é, **onde mora
hoje** e o que ainda falta.

> **Como ler o estado:** ✅ existe e tem script próprio · ⚠️ existe mas ainda
> espalhada · ❌ não existe.

| # | mecânica | estado | mora em |
|---|---|---|---|
| 1 | dano de paralisia | ✅ | `src/mechanics/RecepcaoDeDano.gd` |
| 2 | animação de recepção de dano | ✅ **nova** | `src/mechanics/RecepcaoDeDano.gd` |
| 3 | congelamento | ⚠️ | `src/combat/StatusFX.gd` + meta `is_frozen` |
| 4 | knockback horizontal | ✅ | `src/mechanics/Knockback.gd` |
| 5 | knockback vertical | ✅ | `src/mechanics/Knockback.gd` |
| 6 | paralisia | ⚠️ | campo `paralisa` da `DamageZone` |
| 7 | segurar skill com animação | ⚠️ | `src/player/cast_controller.gd` |
| 8 | segurar skill com representação 3D | ⚠️ | `src/player/cast_controller.gd` |
| 9 | interrupção por dano | ⚠️ | `Player.gd`, janela `is_casting` |
| 10 | segurar skill em efeito | ⚠️ | `src/player/disparo_sustentado.gd` |

**Estado desta migração:** 4 das 10 já têm script próprio. As outras 6 existem e
**funcionam**, mas continuam dentro dos arquivos que as usam. A separação delas
está em andamento — este documento é a fonte de verdade de onde cada uma está
**hoje**, não de onde deveria estar.

---

## 1. Dano de paralisia ✅

> *"quando o jogador receber dano de certas skills ele é paralisado por um certo
> período enquanto exibe a animação de recepção de dano"*

`RecepcaoDeDano.paralisar_com_animacao(corpo, duracao)`.

É a soma de duas mecânicas que já existiam separadas — a paralisia (6) e o tranco
(2). O que faltava era **a segunda metade**: antes o alvo ficava preso com o corpo
em pose de corrida parada, o que lê como travamento de jogo, não como golpe.

A animação dura **o tempo todo** da paralisia, não os 0,30 s do tranco normal.

⚠️ **Ela vence pose de golpe**, de propósito: quem foi paralisado perdeu o
controle do corpo. O tranco normal (2) **não** vence — ver a guarda em `aplicar`.

**Medido:** prende, anima, e solta ao fim (`congelado=false`, `pose=''`).

## 2. Animação de recepção de dano ✅ — a que não existia

> *"vai ocorrer sempre que o jogador receber dano"*

`RecepcaoDeDano.pose()` + `aplicar()` + `tick()` + `limpar()`.

**O que havia antes:** `Player._feedback_de_dano` fazia flash vermelho, som e
número flutuante. Nada disso é animação — o boneco continuava correndo como se
nada tivesse acontecido.

**Por que pose procedural e não clipe do Mixamo:** `_apply_baked` faz `return` no
`update()` do animador, então enquanto um clipe assado toca **toda** a animação
procedural morre. Levar um tiro correndo pararia a corrida. É exatamente o buraco
dos itens 37/38, em que o soco da Gura sequestra o rig por 7,37 s. A pose soma
por cima: levar um tiro correndo continua lendo como corrida, com um tranco.

**Onde é disparada:** `Player._feedback_de_dano` — o funil por onde passa todo
dano visível em **qualquer** cópia, inclusive o que chega por
`net_vida_do_servidor`. Pendurar no `take_damage` faria o adversário **não** ver
você apanhar (item 20).

**Medido:** tronco desloca **19,3°** no impacto e volta ao repouso sozinho.

> ⚠️ **A armadilha que isto revelou, e ela é geral.** O contador ficava atrás do
> portão `if _etapa_travamento(delta): return` — e a paralisia faz esse portão
> fechar. **O mecanismo que congela bloqueava o relógio que descongela.** Mesma
> classe do item 23. Regra: *contador que desfaz um estado nunca pode rodar
> depois do portão que esse estado fecha.*

## 3. Congelamento ⚠️

Hie Hie no Mi. `StatusFX.CONGELADO` + meta `is_frozen`, lida por
`Player._etapa_travamento` e por `TrainingDummy`.

⚠️ **`is_frozen` tem dois donos:** o gelo e a paralisia. Por isso
`RecepcaoDeDano` marca `_dano_paralisia` — sem essa marca, soltar a paralisia
descongelaria também quem estava preso no gelo do outro golpe.

**Pendente:** ainda não tem script próprio.

## 4 e 5. Knockback horizontal e vertical ✅

`src/mechanics/Knockback.gd`.

**O que estava errado:** o vertical **não era uma mecânica** — era a constante
`0.35` escondida dentro da conta do horizontal:

```gdscript
kb = dir * knockback + Vector3.UP * knockback * 0.35
```

Ninguém ajustava a componente vertical sem editar a fórmula, e ninguém descobria
que ela existia sem ler a fórmula.

Agora há `FRACAO_VERTICAL`, três perfis nomeados (`PADRAO`, `SO_HORIZONTAL`,
`ARREMESSO`) e funções `horizontal()` / `vertical()` separadas.

**Medido:** `Knockback.calcular(centro, alvo, 20)` = `(20, 7, 0)` — **exatamente**
a conta antiga. A extração não muda nada em tela, e é por isso que ela pôde ser
feita sem decisão de design.

⚠️ **`direcao_fixa` não é preciosismo:** o radial é `alvo − centro`, e numa frente
de onda de 200 m o centro fica longe do contato. É também o que contorna o item
26 (projétil rápido empurrando o alvo **para trás**).

## 6. Paralisia ⚠️

Goro Goro no Mi: o X paralisa com os raios que caem e só a **coluna final**
empurra.

Campo `paralisa` da `DamageZone`. Quando > 0, o knockback vira zero e o alvo
recebe `is_frozen` + `StatusFX.CONGELADO`.

**Por que empurrar nos raios iniciais era pior:** espalhava o alvo para fora da
área **antes** de a coluna chegar — o golpe se sabotava.

**Pendente:** script próprio, e passar a usar
`RecepcaoDeDano.paralisar_com_animacao` para que a paralisia da `DamageZone`
também **anime** (hoje só a chamada direta anima).

## 7. Segurar skill com animação ⚠️

`CastController._carregando` + `Player.pausar_animacao(true)`, que põe
`speed_scale = 0` — a animação **congela no quadro inicial** enquanto a tecla
está pressionada. Soltar dispara.

## 8. Segurar skill com representação 3D ⚠️

`CastController._carregado`. A skill **nasce no aperto** e cresce enquanto
segurada: `GoroFXGrande.mamaragan_carregado` devolve um nó que o jogador segura.

A recarga e a energia são cobradas **no aperto**, senão dava para "espiar" o
golpe de graça começando e cancelando.

⚠️ **Dano LIBERA, não cancela** (`liberar_por_dano`) — decisão do dono. É a
exceção à mecânica 9.

**Hoje só a Goro usa** (`CARREGAVEIS = {"goro_goro": ["V"]}`).

## 9. Interrupção por dano ⚠️

Janela `is_casting` no `Player`. Um golpe inimigo interrompe o cast ou o
pressionamento.

⚠️ A exceção é o charge-up (8), onde o dano **libera** em vez de cancelar.

⚠️ O tranco de recepção (2) **não** interrompe: são mecânicas diferentes, e o
tranco tem guarda explícita para não sobrescrever pose de golpe em andamento.

## 10. Segurar skill em efeito ⚠️

`src/player/disparo_sustentado.gd`. O melhor exemplo é o **Z da Mera Mera**: a
rajada começa ao pressionar, roda enquanto a tecla estiver segurada, e para ao
soltar **ou ao acabar o pente** — os dois critérios, não só o primeiro.

Diferente da 7 e da 8: aqui a skill **executa continuamente**, não fica
carregando.

---

## O que falta

1. **Seis mecânicas ainda sem script próprio** (3, 6, 7, 8, 9, 10). Elas
   funcionam; só não estão separadas.
2. **A paralisia da `DamageZone` (6) ainda não anima.** A função existe
   (`paralisar_com_animacao`), a `DamageZone` ainda usa o caminho antigo.
3. **`docs/mecanicas/` por mecânica**, no molde de `docs/frutas/`, se este
   arquivo passar de ~600 linhas. **Gatilho declarado.**
