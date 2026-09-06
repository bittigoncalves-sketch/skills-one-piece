# Modos de combate — teclas 1, 2 e 3

Pedido do dono em **2026-09-06**: *"redirecionar troca de fruta para estilo de
tecla de ativação R para tecla de ativação 1, 2 e 3, sendo 1 fruta, 2 estilo de
luta e 3 espada. A seleção de qual está no personagem continua no M."*

| tecla | modo | o que os slots Z/X/C/V fazem |
|---|---|---|
| **1** | `fruit` — Akuma no Mi | as quatro skills da fruta equipada |
| **2** | `style` — estilo de luta | as quatro skills do estilo selecionado |
| **3** | `sword` — a Yoru | **nada**: quem golpeia é o clique |

**O menu do M não mudou.** Ele continua sendo onde se escolhe *qual* personagem,
*qual* Akuma no Mi e *qual* estilo. As teclas 1/2/3 escolhem *qual dos três está
em uso agora*.

---

## Por que seleção direta, e não alternância

Era `toggle_combat_mode()` no **R**, indo e voltando entre dois modos. Com três,
alternar exige saber em qual você está para prever onde vai parar — e no meio de
uma luta ninguém faz essa conta. O `toggle_combat_mode` foi **removido** (não
sobrou chamador; conferido em `.gd` e `.tscn`).

## ⚠️ O terceiro valor e os `else` cegos

Todo consumidor de `combat_mode` no `Player.gd` era um `if == "style" … else`:

```gdscript
var _skill_cooldowns: Dictionary:
    get: return _fruit_cooldowns if combat_mode == "fruit" else _style_cooldowns
```

Com um terceiro valor, esses ramos caem no lado errado em silêncio — no caso
acima, o modo espada passaria a mostrar as recargas do **estilo**. Espalhar
`elif == "sword"` por seis lugares seria seis chances de esquecer um.

Em vez disso o cast inteiro é barrado na **porta de entrada**:

```gdscript
func pode_conjurar() -> bool:
    return combat_mode != "sword"
```

Checado em `cast_skill_slot`, `_request_cast` e `begin_charge` — uma verdade só,
que não precisa ser lembrada em cada ponto novo. Os ramos cegos continuam
existindo, mas agora são inalcançáveis no modo espada.

**`release_charge` NÃO tem o portão, de propósito.** Se o jogador trocar para o
modo espada com uma carga em curso, é o `soltar` que a encerra — barrá-lo
prenderia a carga para sempre.

O `Hud.update_combat_mode` tinha o mesmo `else` cego e virou um `match`.

## A espada é o único modo com presença física

Entrar no modo 3 **saca** a Yoru; sair dele **guarda**. `set_combat_mode` compara
o modo pedido com o estado real (`_yoru`) e só age quando eles divergem, então
apertar 3 duas vezes não guarda a espada por engano.

`set_fighting_style` (o clique no menu do M) passou a **passar pelo mesmo
caminho**. Antes ele atribuía `combat_mode = "style"` na mão — inofensivo com
dois modos, mas com três deixaria a Yoru na mão com a barra de estilo na tela.

⚠️ **Guardar remove da árvore ANTES de liberar.** `queue_free` sozinho deixa o nó
pendurado na mão até o fim do quadro: quem olhasse a mão no mesmo quadro ainda
veria uma espada, e sacar de novo antes da varredura criaria uma segunda
(`Yoru2`) ao lado da que está morrendo.

## A barra de skills no modo espada

Ela deixa de listar as quatro skills (que não sairiam) e passa a dizer o que o
clique faz:

```
ESPADA: YORU [3]
  Bt. Esq. — Corte Horizontal
  Bt. Esq. — Corte Vertical
```

Os títulos dos outros dois passaram de `[R: Alternar]` para `[1]` e `[2]`, e o
menu do M de `ESTILOS DE LUTA (Tecla R)` para `(Tecla 2)`.

Guarda de regressão: `tools/dev_tests/test_modos_de_combate.gd` (15 checagens).
