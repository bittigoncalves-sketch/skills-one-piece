# Armadilhas desta base

A página mais valiosa do guia. Cada item aqui **já custou tempo real** neste
projeto — nenhuma é hipotética, e cada uma diz de onde veio para você poder
conferir.

Leia antes de escrever. É mais barato que descobrir de novo.

---

## 1. `class_name` novo → tela cinza

**Sintoma:** você cria uma classe nova, tudo parece certo, e o botão de jogar
para de funcionar. Tela cinza, sem erro visível.

**Causa:** um `class_name` novo só entra em `.godot/global_script_class_cache.cfg`
depois de o editor abrir uma vez. Sem isso, o script que **usa** a classe não
compila — e falha **em silêncio**.

**Como evitar:** depois de criar `class_name`, rode `--editor --quit` uma vez, ou
use `./checar_cache.sh`, que confere o **conteúdo** do cache.

**Origem:** aconteceu na Fase 3 da partição do `Player.gd`, com `class_name
CameraRig`. Pior: a rotina de teste da época **escondia** o problema, porque
rodava `--editor --quit` antes dos testes — o jogo do dono quebrava, a bateria
não.

> ⚠️ **`--editor --quit` NÃO prova que o código compila.** Ele só popula o cache.
> Quem prova é `test_compila.gd`.

## 2. Posicionar nó FORA da árvore — três ocorrências, é padrão

**Sintoma:** o efeito nasce no lugar errado — geralmente no dobro da distância,
ou na origem do mapa.

**Causa:** `global_position` (ou `look_at`) **antes** do `add_child`. Fora da
árvore, `global_position` escreve no transform **local**, que depois se soma ao
do pai.

**Como evitar:** `add_child` **primeiro**, posicione **depois**. Sempre.

**Origem:** item 21 (`FireFX.gd:200`, `look_at` antes do `add_child`), item 31
(`GuraShatterMesh` — a rachadura nascia em ~2× a posição) e item 40
(`GuraFX._ring/_bubble/_debris`, que **não definem posição nenhuma**: com `world`
como pai, o clímax do V da Gura aparecia no **centro do mapa** enquanto o jogador
estava noutro lugar — era o principal motivo de o golpe "não fazer nada").

## 3. `Area3D` só detecta uma vez por quadro — projétil rápido atravessa

**Sintoma:** a bala passa pelo alvo e não acerta. Piora quanto mais rápida.

**Causa:** a zona anda por **teleporte** (`position += vel * delta`) e a `Area3D`
só enxerga quem está sobreposto **naquele quadro**. A 60 Hz, acima de ~79 m/s o
passo é maior que o alvo.

**⚠️ Sub-passo de posição NÃO resolve** — e essa é a parte que engana. Mover em
pedaços dentro do mesmo quadro não gera detecção nova, porque a detecção é uma
por quadro de física.

**Como evitar:** **varra o caminho com um raio** da posição anterior até a nova.
É o que `DamageZone._varrer_caminho()` faz.

**Origem:** item 24. A sniper estava a 95 m/s e perdia 1 tiro em 6 (20/24).
Depois da varredura: **10/10 em 95, 250 e 400 m/s**.

## 4. Objeto liberado compara IGUAL a `null` (Godot 4)

**Sintoma:** sua sonda conclui que algo nunca existiu — logo depois de tê-lo
medido.

**Causa:** em Godot 4, um objeto já liberado passa em `== null`. Um laço que usa
`if no == null: ainda_procurando` volta a "procurar" quando o nó morre.

**Como evitar:** use `is_instance_valid()` para validade, e guarde num **booleano
próprio** o fato de já ter encontrado. Nunca `== null` para "ainda não nasceu".

**Origem:** item 42. Custou um ciclo inteiro ao agente do V da Gura: a sonda
cronometrou o golpe e depois afirmou que ele nunca tinha nascido.

## 5. `Engine.has_singleton()` não enxerga autoload

**Sintoma:** o efeito nunca dispara, sem erro nenhum.

**Causa:** `Engine.has_singleton()` só vê singleton **nativo/GDExtension**.
Autoload não é isso.

**Como evitar:** `get_node("/root/Nome")` ou `get_node_or_null("/root/Nome")`.

**Origem:** item 41. O `ScreenShatterFX` do V da Gura **nunca rachou a tela**
porque a condição era sempre falsa. Ainda há três `if` mortos iguais em
`GuraFX._punch`, `_shockwave` e `_eruption` (inofensivos: cada um tem um `elif`
correto logo abaixo).

## 6. `var x := algo_sem_tipo.campo` não infere tipo

**Sintoma:** o script inteiro não carrega.

**Causa:** o `:=` não consegue inferir a partir de uma expressão sem tipo
declarado (campo de `Node` genérico, retorno de `get()`, etc.).

**Como evitar:** declare o tipo: `var x: float = algo.campo`.

**Origem:** mordeu ~4 vezes durante a partição do `Player.gd`.

## 7. A armadilha das "views" — campo que vira propriedade de leitura

**Sintoma:** um teste que passava começa a falhar sem que ninguém tenha mexido
nele. Ou pior: nada falha, e o comportamento muda em silêncio.

**Causa:** transformar um campo em propriedade só-leitura (`get:`) ou movê-lo
para um componente **quebra quem escrevia nele** — e a escrita continua
compilando.

**Como evitar:** **antes** de mover qualquer campo:

```bash
grep -rn "_campo\s*=" --include=*.gd src/ tools/ Player.gd
```

**Origem:** aconteceu **4 vezes** na partição do `Player.gd`
(`_buki_scope`, `_rapid_fire`, `_charging`/`_charge_slot`, `_melee_*`).

## 8. Medir no espaço do MUNDO mente — a escala é não-uniforme

**Sintoma:** duas medições do mesmo osso dão valores diferentes conforme a
direção em que ele aponta.

**Causa:** o `_char_model` tem escala **não-uniforme** — `(0,4167, 0,4167,
0,7708)`, porque o voxel é engrossado **1,85×** no Z. No mundo, o mesmo braço
"mede" 0,82 m apontando à frente e 0,50 m pendurado.

**Como evitar:** meça no espaço do modelo
(`modelo.global_transform.affine_inverse() * ponto`). E **prove que a medição é
honesta**: um segmento rígido (ombro→cotovelo) tem que ter **comprimento
constante em qualquer pose**. Se variar, sua medição está contaminada.

**Origem:** a auditoria do rig, 2026-08-14. O número honesto é 0,5625 em toda
pose; no mundo variava 4,08%.

## 9. A convenção invisível — o rig esteve espelhado por meses

**A história mais instrutiva do repositório.** Vale ler mesmo que você nunca
toque em rig.

Até 2026-08-14 o `base.scn` tinha os nós `_L` e `_R` **trocados de lado**: o nó
chamado `UpperArm_R` ficava em x = −0,375, ou seja **no braço esquerdo**. O
código estava certo (`bake_mixamo.gd` assa `mixamorig_RightArm` na faixa
`UpperArm_R`); o modelo é que mentia.

Consequência: **as 29 animações do Mixamo tocavam espelhadas**, e o "Soco
Direito" do combo era visualmente um soco de esquerda.

**Por que ninguém viu:** andar, correr e o combo de socos são quase simétricos, e
a T-pose abre os **dois** braços com sinais opostos. **Numa pose simétrica, a
convenção de lado não tem como aparecer.** O primeiro pedido que nomeou um lado
("o braço **direito** levantado, sem o esquerdo") foi o primeiro capaz de
detectar o problema.

**As três lições, e elas valem para qualquer convenção:**

1. **Uma convenção só é testada quando alguém depende dela de forma assimétrica.**
   Se todo uso é simétrico, ela pode estar errada há anos.
2. **Renomear não bastava.** As duas bases de repouso são idênticas, então o
   sinal do euler está amarrado ao **lado físico**, não ao nome — só o renome
   transformou a T-pose num abraço. O invariante que resolveu: **trocar os
   vetores entre as linhas de um par restaura exatamente o resultado físico
   anterior**, valha o par espelhado ou não.
3. **O que `_add` não escreve, a troca não alcança.** As pernas vêm da IK
   (`_perna_ik`), não de `_add`; ficaram de fora da troca e o contra-balanço
   quebrou. Quem pegou foi o `test_walk_run` — um teste de **movimento**, que viu
   o que a medição de **poses estáticas** não via.

## 10. Sonda que não imita o jogo mede o vazio

**Sintoma:** a medição dá zero e você conclui que o conserto falhou. Ou dá
sucesso e o jogo continua quebrado.

**Como evitar:** acione pelo **caminho que o jogador aciona** (`begin_charge`,
`Input.parse_input_event`, `set_fighting_style`), não forçando campos internos.

**Origens, todas reais:**
- a sonda do Yami C não mediu nada porque soltava a tecla em 0,2 s — o Black Hole
  só existe **enquanto segurado**;
- a sonda do tunelamento deu 0/12 por **dois** erros: não autorizou a bala no
  lado do **servidor**, e forçou `_arma` sem equipar, então a boca do cano usava
  transform inválido e a bala saía abaixo dos pés;
- a sonda do braço da Gura mediria zero acerto em três slots porque o **pitch
  padrão da câmera é −0,25 rad** e joga a mira no chão a 5 m. Nivele com
  `_pitch = 0` + `_update_pivot()` quando a medição depender de mira.

## 11. Uma porta, um processo

A porta **24565** é fixa e única no projeto. Dois processos Godot colidem.

**Consequência prática:** agentes que rodam o jogo têm que ser despachados **em
série**, nunca em paralelo. Agente que só lê e escreve texto pode rodar junto.

## 12. `extends SceneTree` não tem `get_tree()`

O script **é** a árvore. Use `get_root()` e
`get_first_node_in_group()` direto.

## 13. `Engine.time_scale` escala o delta da física

Um traço de referência ficou intermitente porque `GameFlow.hit_stop()` põe
`time_scale` em 0,06. Se a sua medição depende de tempo, **force `1.0` a cada
quadro**.

---

## O padrão por trás de metade desta lista

Repare quantos itens são a mesma coisa: **um estado que parece pronto e não
está** — nó fora da árvore (2), objeto liberado (4), cache de classe (1),
autoload que ainda não é singleton (5).

Antes de usar qualquer referência, pergunte: *isto já existe de verdade, ou eu só
tenho o nome dele?*
