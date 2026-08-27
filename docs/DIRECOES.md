# Direções — a rosa dos ventos

Onde mora a resposta para "para que lado é a frente?". A matemática e a tabela
completa estão no cabeçalho de [`src/world/RosaDosVentos.gd`](../src/world/RosaDosVentos.gd);
aqui fica o **por que existe** e **como usar**.

---

## Por que existe

Em 2026-08-25 o auto-mira e o lunge do corpo a corpo apontavam **para trás**:

```
yaw= 0.00  dot = −1.00
yaw= 1.57  dot = −1.00
yaw= 3.14  dot = −1.00
```

`-Vector3.FORWARD.rotated(...)` — e `Vector3.FORWARD` **já é** `(0,0,−1)`, então
negá-la dá `(0,0,+1)`. O golpe acertava (a hitbox usava a expressão certa), só o
auxílio estava invertido. Passou semanas sem ninguém notar.

**A causa de fundo não é a linha errada.** É que a convenção vivia repetida em
**cinco** lugares e não havia contra o que conferir quando a sexta cópia saísse
diferente. Este arquivo é esse "contra o que".

---

## A convenção

| cardeal | eixo | Vector3 |
|---|---|---|
| NORTE | −Z | `(0, 0, −1)` |
| SUL | +Z | `(0, 0, +1)` |
| LESTE | +X | `(+1, 0, 0)` |
| OESTE | −X | `(−1, 0, 0)` |
| CIMA | +Y | `(0, +1, 0)` |
| BAIXO | −Y | `(0, −1, 0)` |

⚠️ **`Vector3.FORWARD` NÃO é "a frente do personagem".** É a constante de eixo, e
coincide com o NORTE do mundo. A frente do corpo só é igual a ela quando
`yaw == 0`. Foi essa leitura que produziu o bug.

**A frente do corpo é `-Basis.from_euler(Vector3(0, yaw, 0)).z`** — ou, agora,
`RosaDosVentos.frente(yaw)`.

---

## Como usar

Tudo o que interessa é **estático**: não precisa instanciar nada, e custa o mesmo
que a expressão inline.

```gdscript
RosaDosVentos.frente(yaw)          # e tras / direita / esquerda
RosaDosVentos.base_do_corpo(yaw)   # quando precisar de frente E direita juntas
RosaDosVentos.yaw_para(direcao)    # o caminho de volta
RosaDosVentos.nome_mais_proximo(v) # "NORTE", "LESTE", ...
```

Os **cinco sítios** que duplicavam a expressão agora chamam a rosa:
`move_frame.gd`, `melee_controller.gd`, `health_controller.gd` e `Player.gd` (×2).

### Os pontos invisíveis

`RosaDosVentos.instalar(pai)` põe em cena os 18 pontos de referência (6 cardeais,
6 eixos crus, 6 relativos ao corpo). Eles são `Node3D` puros — **sem malha
nenhuma**, custo zero de quadro, e o nó **não roda `_process`** enquanto a
visualização está desligada.

**F9** liga a visualização em jogo, ou `SOP_ROSA=1` no ambiente para já nascer
ligada num teste com tela.

---

## As duas sondas

| sonda | o que prova |
|---|---|
| `tools/dev_tests/medir_rosa_dos_ventos.gd` | que a convenção declarada **é** a que o jogo usa |
| `tools/dev_tests/medir_direcoes_skills.gd` | que cada skill vai para onde foi pedida |

A primeira roda a locomoção, a hitbox e o knockback **de verdade** e compara com a
rosa: `+1,0000` nos três, em 12 ângulos. Ela também **reproduz de propósito** a
linha errada de 2026-08-25 e exige que dê −1 — sem isso não haveria prova de que
o teste sabe reprovar.

⚠️ **A sonda mantém a expressão literal `-Basis.from_euler(...).z` em vez de
chamar a rosa.** É de propósito: se ela usasse a rosa, compararia a coisa com ela
mesma e passaria mesmo com a convenção errada. Este projeto já perdeu tempo com
exatamente esse tipo de teste tautológico (ver `erros.md`, a conferência do rig
no Blender).

### O que a segunda sonda mede

Para cada **fruta × slot × direção** (144 células) ela dispara o golpe e compara a
direção pedida com para onde o efeito realmente foi. Golpe de área ou centrado no
próprio corpo é **classificado** (`cen` / `omni`), não reprovado.

Três armadilhas que ela já teve que resolver, e que valem para qualquer sonda
parecida:

1. **Janela curta demais.** Com 2,5 s, golpe lento não criava hitbox dentro da
   própria janela e a zona nascia na medição seguinte — a tabela ficava com um
   atraso de exatamente **um passo** (LESTE lia NORTE, SUL lia LESTE). Não era
   golpe errado: era a janela. Hoje o teto é 6 s.
2. **Drenar não basta.** Esvaziar a cena entre medições não resolve o caso acima,
   porque quando o dreno olha a zona atrasada ainda não existe.
3. **Acusação exige repetição.** Golpe de área na fronteira da classificação tem
   deslocamento quase nulo, e normalizar vetor curto amplia ruído: a mesma célula
   deu −0,86 e +1,00 em rodadas diferentes. O bug real do lunge era **consistente**
   em todo yaw — então célula acusada é medida até 3× e só vale se repetir.

### A prova de que ela sabe reprovar

Uma sonda que nunca reprova não prova nada, e este projeto já teve uma
(a conferência do rig no Blender comparava o erro consigo mesma e dizia "✓").

Por isso `medir_direcoes_skills.gd` tem sabotagem embutida: com `--inverter` ela
entrega ao jogo o **oposto** do pedido e continua comparando com o pedido.
Resultado medido:

```
❗ INVERTIDAS: 108
   ❌ bara_bara Z→NORTE (-1.00, real=SUL)
   ❌ buki_buki Z→LESTE (-1.00, real=OESTE)
   ...
✓ com o `aim` invertido a sonda pegou 108 célula(s) — ela SABE reprovar.
```

108 das 121 células com direção, todas em **−1,00** — o mesmo número do bug real
de 2026-08-25. As 13 restantes são as que não criam hitbox e por isso não podem
ser julgadas.

⚠️ A sabotagem é um **flag de linha de comando**, não uma edição no código: não há
o que desfazer depois, e por isso ela não pode ficar ligada por esquecimento.
