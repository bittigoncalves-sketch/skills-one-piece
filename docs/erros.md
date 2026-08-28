# Registro de Erros — Skills One Piece

Todo erro encontrado no projeto, com o **motivo** de ter acontecido. Mantido pela
skill `registrar-erro`. Entradas mais recentes no topo.

O objetivo aqui não é o conserto — é a **causa**. Erro sem causa documentada volta.

---

## 2026-08-28 — a cópia do dono regenera 10x mais rápido do que deveria (ABERTO)

**Sintoma:** na tela do próprio jogador a barra de vida sobe mais rápido do que
o servidor está curando. Medido: logo após um golpe, o servidor tinha 1920,0 e
a cópia do cliente marcava 1930,2 — 10,2 hp de vida que o servidor não deu, em
cerca de 1 s.

**Causa raiz:** a penalidade de combate (`PENALIDADE_DANO = 0.10`, que derruba a
regeneração de 10,24 hp/s para 1,02 hp/s nos 5 s seguintes a um dano) depende de
`_t_ultimo_dano`, e esse campo só é escrito por `HealthController.sofrer_dano()`
— que roda **no servidor**. Na cópia do dono a vida chega por
`net_vida_do_servidor` (Player.gd:1744), que escreve `_vida.vida` direto e não
toca em `_t_ultimo_dano`. Ou seja: a cópia que o jogador enxerga não sabe que
acabou de apanhar, sai da penalidade e regenera a taxa cheia. Como o corpo do
dono tem autoridade no processo dele, o `_physics_process` roda e a regen local
acontece de verdade.

**Evidência:** `net_dano_client_probe.gd`, item D. O corpo do host visto pelo
cliente — cópia remota, que não regenera ali — bate exato (1792,0 = 1792,0), e
só o corpo do próprio cliente deriva. A assimetria entre os dois números na
mesma leitura é o que aponta a regen local como causa, e não perda de pacote.

**Descartado:** *atraso de rede*. O RPC é `reliable` e a vida do host, medida na
mesma leitura, chega exata; se fosse transporte, os dois números erravam juntos.

**Alcance:** é divergência de APRESENTAÇÃO, não vantagem de jogo — a vida do
servidor continua sendo a verdadeira e sobrescreve no dano seguinte. O jogador
vê uma barra otimista entre um golpe e outro.

**Correção:** ainda não aplicada (o pedido era o teste). O conserto natural é
`net_vida_do_servidor` marcar o combate na cópia local quando `dano > 0` — o
mesmo instante em que já chama `_feedback_de_dano`.

**Como detectar de novo:** `net_dano_probe` no `validar.sh`, item D do relatório
do cliente. Ele imprime a deriva sempre; se um dia aparecer perto de zero, o
comportamento mudou e o item A pode voltar a ler a vida tardia em vez do degrau.

## 2026-08-28 — teto absoluto num sinal cuja escala eu mesmo mudei

**Sintoma:** ao desacelerar a marcha (pedido do usuário: animação mais lenta sem
mexer no deslocamento), `test_walk_run` passou a reprovar `base / WALK` com
"não achei período — a marcha não está ciclando". A animação estava ciclando
normalmente na tela.

**Causa raiz:** `_periodo()` julgava a qualidade do casamento da série com
tolerâncias **absolutas em radianos** (0,004 para "fecha bem" e 0,02 para
"aceita"), calibradas quando a coxa oscilava 87°. A desaceleração veio de baixar
o quadril (`H_CORRIDA` 0.80→0.70, `H_SPRINT` 0.76→0.66), o que **aumenta a
amplitude** da coxa para 112° — a perna precisa abrir mais para cobrir a mesma
passada com o quadril mais baixo. O resíduo do casamento escala junto com o
sinal, estourou 0,02, e o teste reprovou uma marcha correta. A propriedade que o
teste quer verificar ("a série se repete") é de **forma**, não de escala; o teto
não podia ser fixo.

**Evidência:** amplitude da coxa 87° → 112° (1,29×) exatamente quando a falha
apareceu; as outras três marchas, com amplitude ~103°, passaram raspando. Com o
teto proporcional (0,0132 × amplitude, a mesma fração que 0,02/1,518 rad
representava antes), as quatro passam mantendo o rigor relativo original.

**Descartado:** *falta de amostra*. A primeira hipótese foi que o ciclo mais
longo (33,4 quadros) não cabia na janela de 90 quadros; alonguei para 180 e a
falha **continuou idêntica** — o que matou a hipótese antes de eu mexer em
qualquer constante do jogo.

**Correção:** `tools/dev_tests/test_walk_run.gd:263` — `_periodo()` calcula
`_amplitude(s)` e deriva `fecha`/`aceita` como fração dela; o teto do erro de
loop virou `0,033 × amplitude`.

**Como detectar de novo:** sabotagem — `CADENCIA_ESCALA := 0.0` em
`src/anim/ProceduralAnimator.gd` faz o teste voltar a imprimir "não achei
período". Se não imprimir, o teto foi afrouxado demais e o teste está cego.

**Padrão a levar adiante:** quando eu mudo uma constante que altera a **escala**
de um sinal, todo limiar absoluto medido sobre esse sinal vira suspeito. O teste
não estava errado antes — ele estava amarrado a uma escala que deixou de valer.

---

## 2026-08-28 — detector de período só testava atrasos inteiros num ciclo fracionário

**Sintoma:** mesmo depois de passar, `base / WALK` fechava o loop com erro 0,0561
contra um teto de 0,0645 (87% do teto), enquanto as outras três marchas — de
qualidade idêntica — ficavam entre 0,0001 e 0,0062, duas ordens de grandeza
abaixo. Uma assertion prestes a piscar no próximo ajuste de constante.

**Causa raiz:** `_periodo()` só avaliava atrasos **inteiros** em quadros, mas o
ciclo real é fracionário (33,4 quadros). Nenhum atraso inteiro fecha nele: o
resíduo que sobrava não media a qualidade da marcha, media **o quanto um múltiplo
do ciclo por acaso caiu perto de um inteiro**. O próprio comentário do teste já
descrevia o fenômeno ("o ciclo real é fracionário e nenhum atraso inteiro fecha
nele") mas o tratava como limitação aceita em vez de defeito de medição.

**Evidência:** com amostragem sub-quadro o erro de `base / WALK` caiu de 0,0561
para 0,0155 (24% do teto) **sem nenhuma mudança na animação**. O atraso refinado
deu 66,80 quadros = 2 × 33,4, batendo com o ciclo medido de forma independente
por `_ciclo()` (cruzamentos de média) — duas medições por métodos diferentes
concordando.

**Correção:** `tools/dev_tests/test_walk_run.gd` — `_erro_no_atraso()` amostra a
série em atraso fracionário por interpolação linear, e `_refinar_atraso()` varre
±0,5 quadro em passos de 0,05 em torno do melhor atraso inteiro.

**Como detectar de novo:** se o erro de loop de uma marcha ficar acima de ~50% do
teto enquanto as demais ficam abaixo de 10%, é desalinhamento de amostragem, não
animação ruim — compare o atraso impresso com o `ciclo N frames` da mesma linha:
ele tem que ser um múltiplo inteiro dele.

## 2026-08-25 — o transformador que consertava 28 sítios quebrou 6 e esvaziou 3 blocos

**Sintoma:** depois de rodar um script que converteu "emissão → albedo HDR" em
16 arquivos, o projeto passou de 3 para **6 scripts sem compilar**, com erros
que não pareciam ter relação: `Cannot infer the type of "arma" variable`,
`... "papel" ...`, `... "tw" ...` — em arquivos que o script nem tocou.

**Causa raiz:** duas, as duas do script:

**1. Escopo por ARQUIVO em vez de por FUNÇÃO.** Ele colhia os nomes de variável
marcados como unshaded no arquivo inteiro. No `WaterFX.gd` há duas funções que
chamam o material de `m`:

```gdscript
static func _mat_agua(...):   # SOMBREADO
    var m := StandardMaterial3D.new()
static func _mat_luz(...):    # unshaded
    var m := StandardMaterial3D.new()
    m.shading_mode = ...UNSHADED
```

O `m` de `_mat_luz` marcou o nome, e o `m` de `_mat_agua` foi convertido junto.
Em material **sombreado a emissão FUNCIONA** — apagar ali não era conserto, era
regressão. Aconteceu em 6 sítios (`BukiFX`, `BukiProjeteis`, `FireFX` ×3,
`WaterFX`).

**2. Bloco esvaziado.** As três linhas de emissão às vezes são o corpo inteiro
de um `if energia > 0.0:`. Apagá-las deixa

```gdscript
	if energia > 0.0:
	return m
```

que é erro de sintaxe — e derruba **todo script que dependa daquele**, que é o
motivo de os erros aparecerem em arquivos não tocados. Aconteceu em 3 blocos.

**Correção:** os 6 sítios sombreados foram revertidos — em material SOMBREADO a
emissão funciona, apagar ali era regressão — e os 3 blocos esvaziados, refeitos à
mão. A contagem real de sítios a converter era **28**, não 32.

**Como detectar:** transformação em massa precisa de auditoria pós-fato, não só
de revisão do diff. As duas que usei:
- procurar linha terminada em `:` seguida de linha com indentação MENOR ou igual
  (bloco vazio);
- reconferir a premissa do transformador *por função*: para cada `brilho(`
  aplicado, o material daquela variável é unshaded **naquela função**?

A segunda achou os 6. Ambas ficaram no fim do trabalho: 28 conversões em
material unshaded, **0** em sombreado, **0** sítios com emissão ainda descartada.

**E o número mudou.** A heurística original dizia "32 sítios em 16 arquivos".
Contando por função, são **28** — os outros 4 eram material sombreado que a
janela de ±25 linhas juntou por engano. Contagem por proximidade de texto não é
contagem.

---

## 2026-08-25 — `SHADING_MODE_UNSHADED` descarta a emissão, e o jogo inteiro depende disso

**Sintoma:** liguei o glow no `WorldEnv` e NADA brilhou. As configurações
estavam certas (conferidas em runtime: `glow_enabled=true`, limiar 1,05,
intensidade 0,90, níveis 0/1,0/0,9/0,6/0,35/0/0) e o `Environment` era mesmo o
vivo — provei zerando a saturação e vendo a esfera ficar cinza.

**Causa raiz:** em material `StandardMaterial3D` com
`shading_mode = SHADING_MODE_UNSHADED`, a **emissão é ignorada**. A saída é só o
albedo, que é limitado a 1,0 — e o limiar do glow é 1,05. Nada cruza, nunca.

**Medido**, três esferas, halo no anel em volta com glow ligado menos desligado:

```
unshaded + emission_energy 4.0    +0,0000   <- não brilha
unshaded SÓ albedo                +0,0000   <- IDÊNTICO ao de cima, ao dígito
sombreada + emission_energy 4.0   +0,0355   <- brilha
unshaded + albedo 2.5 (HDR)       +0,0586   <- brilha MAIS
```

As duas primeiras linhas serem iguais ao dígito é a prova: a emissão não chega
ao buffer.

**Por que dói tanto neste projeto:** `unshaded + emissivo` é exatamente a receita
dos efeitos daqui — **32 combinações em 16 arquivos** (`FxUtil`, `YamiFX`,
`FireFX`, `GoroFX`, `GuraFX`, `Melee`, `BukiFX`…). Todas escrevem
`emission_energy_multiplier` entre 2,5 e 4,0 e **jogam esse número fora** desde
sempre. Ninguém notou porque, sem glow no projeto, emissão não fazia diferença
visível de qualquer jeito — dois defeitos que se escondiam um no outro.

**Correção:** albedo acima de 1,0 no lugar da emissão. Preserva o motivo de o
efeito ser unshaded (não escurecer quando o golpe passa pela sombra) e brilha
mais que o caminho sombreado. É trabalho da Fase 5 do `PLANO_VISUAL.md`.

**Como detectar:** glow é invisível quando nada passa do limiar. O teste é
sempre comparativo e com o objeto PARADO — minha primeira medição comparou
glow on/off em dois quadros diferentes de um efeito com `RigidBody3D` voando, e
os números mudaram por causa do movimento, não do glow. Emissivo estático,
mesma câmera, mede o anel em volta.

**Lição de método:** eu afirmei duas vezes, em documento, que ligar o glow faria
"os quatro golpes de nove frutas lerem sem tocar numa linha de VFX". Era
dedução a partir de `grep emission_energy_multiplier`, não medição. O grep
provava que a emissão era ESCRITA; não provava que ela era USADA.

---

## 2026-08-25 — a névoa não pode clarear ao longe e escurecer para baixo

**Sintoma:** o buraco do mapa, que aparecia VERDE (a cor do "chão" do céu
procedural, e portanto lia como grama), passou a aparecer AZUL-CLARO depois do
meu conserto — passou a ler como água. Troquei a cor do erro.

**Causa raiz:** tentei fazer um mecanismo só cumprir duas funções opostas. O
`Environment` tem **uma cor de névoa**. Ela precisa ser clara para a perspectiva
aérea funcionar à distância; e eu liguei `fog_height_density = 0.16` para
escurecer o poço com a mesma névoa. Descendo, ela satura — e névoa opaca CLARA
é o azul que apareceu. De quebra escondeu o plano escuro que eu tinha posto
em `y = −60` para ser o fundo.

**Medido** (cor no meio do poço, mesma câmera):

```
névoa on,  fundo on    (0,263  0,369  0,467)   azul lavado
névoa OFF, fundo on    (0,000  0,000  0,000)   preto
névoa OFF, fundo off   (0,000  0,000  0,016)   preto
```

Duas conclusões: quem lavava era a névoa sozinha, e o plano de fundo era
**redundante** — o `ground_bottom_color` escuro do céu já entrega preto.

**Correção:** `fog_height_density = 0` (o ar só clareia ao longe) e o poço
escurecido pelo céu. O plano foi removido: ele nunca seria visto de perto,
porque o jogador morre em `VOID_Y = −40`, seis metros acima de onde ele estava.

**Como detectar:** quando um ajuste "conserta" trocando um problema por outro
do mesmo tamanho, quase sempre é um mecanismo sendo usado para duas coisas
contrárias. Isolar é ligar e desligar cada um e medir o pixel.

---

## 2026-08-25 — `set_glow_level()` é base ZERO e o inspetor é base UM

**Sintoma:** `ERROR: Index p_level = 7 is out of bounds
(RenderingServer::MAX_GLOW_LEVELS = 7)`, no meio do log de subida.

**Causa raiz:** as propriedades aparecem como `glow_levels/1` .. `glow_levels/7`
no inspetor, então escrevi `set_glow_level(1..7)`. O método é **base zero**
(0..6). O nível 7 estourava e o nível 0 nunca era zerado — o glow ficava
configurado errado, com um erro que some no meio da saída.

**Correção:** `set_glow_level()` passou a ser chamado com índices **0..6**, e a
configuração é lida de volta em runtime para conferir.

**Como detectar:** erro de índice em `_ready` não derruba nada e não falha
teste. Vale conferir a configuração LENDO de volta em runtime
(`get_glow_level(i)`), que foi o que expôs o buraco no nível 0.

---

## 2026-08-25 — onze clipes retargetados têm o tronco tombado ~50°

**Sintoma:** nenhum reclamado, e é o que assusta. Descoberto ao montar o
personagem no Blender: toda pose animada saía "caída". A primeira suspeita foi
da minha conversão — era do dado.

**Causa raiz:** o retarget do Mixamo deixou uma ROLAGEM no `Torso` (eixo Z) que
nunca foi zerada. Medido no primeiro quadro dos 29 clipes: **11 passam de 25°**.

```
roundhouse_kick   −81,4°   (faixa −85,7 … −51,8 — NUNCA fica de pé)
kicking           −60,6°
gunplay           −53,8°
bouncing_idle     −50,7°
boxing_1 (jab)    −32,8°
```

**Confirmado no jogo, não só no JSON:** tocando `bouncing_fight_idle` por
`play_baked`, o vetor "para cima" do torso fica a **51,4° da vertical**.

**Por que ninguém viu:** dos 11, só dois estavam em uso no combo (`boxing_1` e
`roundhouse_kick`), e ali o defeito se confundia com o problema já conhecido de
LEITURA dos socos ("os dois liam igual", 2026-08-11). O resto do acervo é
material de reserva que nunca chegou à tela.

**Como detectar:** `Torso.z` no primeiro quadro de cada clipe. Ele deve estar
perto de zero — rolagem é o eixo que um humano quase não usa parado. Uma
varredura de 10 linhas sobre `tools/anim_editor/clips/*.json` acha todos.

**Correção:** os quatro M1 do combo foram REAUTORADOS
(`tools/autorar_combo_m1.py`), com portão medido que exige `|Torso.z| <= 20°`.
Os outros 7 clipes tombados continuam como estão — estão fora de uso e a lista
ficou registrada em `docs/ESQUELETO.md`, em ordem de gravidade.

---

## 2026-08-25 — a conferência do rig no Blender comparava o erro consigo mesma

**Sintoma:** o `.blend` gerado abria com a pose de repouso PERFEITA e todas as
poses animadas embaralhadas — e o script dizia "✓ a conta fecha, pior erro
0,4 mm".

**Causa raiz:** o Godot reporta `Node3D.rotation_order = 2`, que a documentação
dele chama de **YXZ**. A string equivalente no mathutils do Blender é **`ZXY`**:
as duas bibliotecas nomeiam a ordem de Euler em sentidos opostos. Eu usei
`'YXZ'`.

O que fez o defeito sobreviver a um teste foi outra coisa, e é a lição:
**a conferência comparava a cinemática direta com o Blender, e os dois liam o
Euler pela MESMA função.** Errando junto, concordavam. A pose de repouso
disfarçava porque com todos os ângulos em zero qualquer ordem acerta.

**Correção:** `'ZXY'` no mathutils (não `'YXZ'`), mais a âncora `ANCORA_COLUNAS`
medida DENTRO do Godot, que o script recusa montar se não reproduzir — e um
controle com os eixos errados de propósito, que precisa explodir.

**Como detectar:** teste sem referência EXTERNA não prova conversão. A correção
foi colar no script uma base medida dentro do Godot (`ANCORA_COLUNAS`) e
recusar montar se a conversão não a reproduzir. Junto entrou um CONTROLE: a
mesma conta com os eixos errados de propósito, que precisa explodir — se o
controle não reprovar, o teste não vale e o script também recusa.

Medido depois: âncora 3×10⁻⁷, pior erro 0,099 mm, controle 2,243 m.

**Lição de método:** todo teste de conversão precisa de (a) uma referência
externa e (b) um controle que falhe. Sem (b), "passou" e "não sabe reprovar"
são indistinguíveis — foi a mesma classe de cegueira do `transition_to`
silencioso registrado acima.

---

## 2026-08-25 — `Melee.clipe()` só achava `.res`, e o editor grava `.tres`

**Sintoma:** golpe sem animação nenhuma, com um `push_warning` de "clipe
ausente" que some no meio do log.

**Causa raiz:** o caminho era montado como `"res://assets/animations/%s.res"` —
extensão fixa. O editor de animação do próprio projeto
(`tools/anim_editor/clip.py::para_tres`) grava **`.tres`**, que o Godot carrega
exatamente igual. Ou seja: todo clipe AUTORAL era invisível para o combo.

**Como detectar:** `push_warning` não falha teste nenhum. Vale procurar
`"%s.res"`, `"%s.tres"` e afins — extensão escrita à mão é sempre uma aposta
sobre quem gravou o arquivo.

**Correção:** `clipe()` tenta `.tres` e depois `.res`.

---

## 2026-08-25 — o auto-mira e o lunge do corpo a corpo apontavam PARA TRÁS

**Sintoma:** nenhum visível, e é o que torna o caso instrutivo. O golpe acertava
normalmente (a hitbox sempre usou a direção certa), então nada parecia errado —
o que faltava era o auxílio: o jogador nunca era puxado para o alvo.

**Causa raiz:** `find_best_melee_target` e `perform_melee_lunge` calculavam a
frente como

```gdscript
var forward = -Vector3.FORWARD.rotated(Vector3.UP, _yaw)
```

`Vector3.FORWARD` **já é** `(0, 0, −1)`. Negá-la dá `(0, 0, +1)` — para trás. O
resto do combate usa `-Basis.from_euler(Vector3(0, yaw, 0)).z`
(`melee_controller.pedir`, que é quem posiciona a hitbox).

**Medido** (`dot` entre as duas expressões, três ângulos):

```
yaw= 0.00 | lunge/auto-mira=( 0.00, 0.00, 1.00)  hitbox=( 0.00, 0.00,-1.00)  dot=-1.00
yaw= 1.57 | lunge/auto-mira=( 1.00, 0.00, 0.00)  hitbox=(-1.00, 0.00, 0.00)  dot=-1.00
yaw= 3.14 | lunge/auto-mira=( 0.00, 0.00,-1.00)  hitbox=( 0.00, 0.00, 1.00)  dot=-1.00
```

−1,00 em todo yaw: exatamente opostas, não "um pouco fora".

**Duas consequências, ambas silenciosas:**

1. o cone frontal (`dot_prod > 0.0`) selecionava alvos **atrás** do jogador;
2. o lunge empurrava o corpo **para longe** do alvo recém-selecionado — e para
   longe de onde a hitbox ia nascer.

**Correção:** `find_best_melee_target` e `perform_melee_lunge` passaram a usar
`-Basis.from_euler(Vector3(0, yaw, 0)).z` — a MESMA expressão que o resto do
combate já usava para posicionar a hitbox.

**Como detectar:** duas expressões de "frente" no mesmo sistema é o cheiro. O
teste é uma linha: `print(a.dot(b))` para alguns yaws. `-Vector3.FORWARD` é
armadilha de nome — lê-se "a frente", vale o contrário.

**O que NÃO era bug:** o `lunge_force` de 18,0. Parece absurdo para um puxão de
0,30 m (§3.3 do plano), mas é impulso de UM QUADRO — `_etapa_locomocao` reescreve
`velocity.x/z` no quadro seguinte. 18 ÷ 60 = 0,30 m, o número-alvo. Quase
"corrigi" um valor correto por ler a unidade errada.

## 2026-08-25 — o estado "Stunned" era pedido em 7 pontos e NÃO EXISTIA

**Sintoma:** nenhum. É o pior tipo — o jogo não reclamava de nada, e cinco
mecânicas estavam desligadas em silêncio.

**Causa raiz:** `Player._feedback_de_dano` chamava `_fsm.transition_to("Stunned")`
e outros seis pontos checavam `_fsm.state.name == "Stunned"`. Nunca houve um nó
com esse nome: `PlayerStateMachine.transition_to` começa com

```gdscript
if not has_node(target_state_path):
    return
```

ou seja, a transição era um **no-op calado** e as seis comparações eram falsas
para sempre. O que estava morto por causa disso:

- `_request_melee` não recusava clique sob hitstun — dava para socar apanhando;
- `golpe_prende` nunca cedia ao tranco — atacar era imunidade a empurrão, o
  oposto do que o comentário ao lado afirmava;
- o wall bounce do knockback (depois do `move_and_slide`) nunca disparou uma vez;
- o combo breaker (G) exigia estar em "Stunned" e só conseguia ler o
  `_hitstop_timer`;
- `_slot_em_uso` nunca via combate travado por stun.

**Como detectar:** `grep -n 'transition_to("' *.gd src/**/*.gd` e conferir cada
alvo contra os `add_child` da montagem da FSM. Uma transição para nó inexistente
é indistinguível de uma transição que aconteceu — a máquina não avisa.

**Correção:** `src/player/hsm/CombatStateStunned.gd`, registrado no `_ready` do
Player junto com as outras fases, e uma nota no ponto de montagem dizendo que o
NOME DO NÓ é o endereço.

**Lição de método:** `return` silencioso em resolvedor de nome é o mesmo defeito
de classe do `_fire_skill` que "engole quase tudo" (ver `docs/frutas/README.md`):
o caminho de erro é indistinguível do caminho de sucesso. Onde não dá para
mudar a assinatura, o teste tem que afirmar a EXISTÊNCIA do alvo — foi o que
`src/tests/test_fsm.gd` passou a fazer.

---

## 2026-08-25 — tirar o boneco da cena derrubou a suíte `src/tests/` inteira

**Sintoma:** `>>> TEST FAIL (cenário não montou): TrainingDummy não encontrado em
TestArena.tscn` nos três testes de `src/tests/`. Nenhum deles rodou uma asserção
desde 2026-08-23.

**Causa raiz:** o commit de 2026-08-23 (interruptores F1/F2) tirou o nó
`TrainingDummy` do `TestArena.tscn` — correto, porque os bonecos passaram a ser
criados pelo SERVIDOR via `Main.pedir_dummy()` + `MultiplayerSpawner`. O que não
acompanhou foi o `BaseTest.gd`, que buscava o nó na cena e abortava sem ele.

**Por que passou despercebido:** o aborto é uma linha só, no fim de uma saída de
centenas de linhas de `MoveFrame: ...`, e a contagem "6 falham" da validação de
08-23 não distingue teste que FALHOU de teste que nem MONTOU. É exatamente a
"segunda armadilha" que o cabeçalho do próprio `BaseTest.gd` manda nunca deixar
passar — e passou.

**Correção:** o `BaseTest` monta o próprio boneco quando a cena não traz um.
Devolver o nó à cena seria o conserto errado: a cena deixou de ser o lugar dele
de propósito.

**Como detectar:** `grep -c "cenário não montou"` na saída da suíte. Vale a pena
o `validar.sh` tratar isso como categoria própria, separada de asserção falhada.

---

## 2026-08-25 — o corpo de teste nasce a 1,7 m da parede (falso negativo de dash)

**Sintoma:** no `test_fsm.gd`, a asserção "o corpo saiu de verdade" lia
**0,0 m/s** e acusava um dash que não tinha saído. O dash havia saído: medido a
**42,9 m/s** no quadro do disparo.

**Causa raiz:** duas coisas somadas.

1. O Player, montado em `SpawnPoint` (0, 1, 0), aparece em **z = −9,77** entre os
   quadros 2 e 3 — um teleporte de 9,77 m que ninguém pediu. **A causa disso
   continua ABERTA**; medido, não explicado (`velocity` é zero antes e depois, e
   `Scoreboard.RESPAWN` é (0, 6, 0), então não é o respawn).
2. A parede da arena está em z = −11,5 e a esquiva percorre ~12 m em 0,28 s. A
   asserção media dois quadros depois do disparo, quando o `move_and_slide` já
   tinha zerado a velocidade contra a parede.

**Correção (do teste):** medir no PRIMEIRO quadro da esquiva — que é também o
instante certo semanticamente — e reposicionar o corpo antes do round que mede
deslocamento.

**Como detectar:** asserção de movimento que lê exatamente 0,0 num corpo que
deveria estar voando é quase sempre colisão, não ausência de impulso. Imprimir
`is_on_wall()` e a posição junto com a velocidade separa os dois casos em um
quadro.

**Pendência:** o teleporte do item 1. Está registrado aqui para não se perder;
quem for mexer em spawn de teste começa por ele.

## 2026-08-23 — o Kurouzu (X da Yami) virava zumbi por um argumento faltando

**Sintoma:** relatado pelo dono — "o X da Yami Yami não está atraindo o inimigo e
não está desaparecendo após o uso". O orbe do buraco negro ficava colado na palma
da mão para sempre, e os X seguintes abriam e morriam sem puxar ninguém.

**Causa raiz:** `KurouzuController` chamava `caster.pedir_cancelar_hold("X")` com
UM argumento; `Player.pedir_cancelar_hold(slot, fruit)` pede DOIS. O erro de
runtime aborta a função em curso — e no caminho SEM captura o `queue_free()` vinha
na linha **seguinte**, então nunca rodava. O controlador virava zumbi: `_exit_tree`
é quem libera o `vortex_root`, e ele nunca disparava.

O segundo sintoma sai do mesmo zumbi. A linha `set_meta("yami_kurouzu_active",
false)` vem ANTES da chamada que falha, então continuava rodando a cada quadro.
Passados os 5 s de vida do zumbi, ela desligava o X **seguinte** no primeiro
quadro — o golpe nascia já cancelado. Não era o X que estava quebrado: era o X
anterior que não tinha morrido.

**Evidência:** sonda de dois processos e de processo único
(`--script` com `GameFlow.start_singleplayer`):

```
X nº1 sem alvo -> controladores vivos: 1 | orbes vivos: 1 | kurouzu_active=false
X nº2 (6 s depois, alvo a 8,81 m):
   kurouzu_active logo após comecar = true
   kurouzu_active 0,2 s depois      = false      <- o zumbi desligou
   controladores vivos: 2 | orbes vivos: 2       <- acumulando
SCRIPT ERROR: Invalid call to function 'pedir_cancelar_hold' in base
  'CharacterBody3D (Player)'. Expected 2 argument(s).
  at: KurouzuController._physics_process (res://src/effects/YamiFX.gd:542)
```

O erro repetia a **cada quadro de física**, indefinidamente.

**Descartado:** a oclusão (`cached_los`), a força de sucção, a guarda
`caster.is_multiplayer_authority()` e o teto `KUROUZU_DURATION` — todos corretos.
Com um alvo capturado o golpe puxava 8,42 m -> 1,78 m normalmente; o defeito só
aparece quando a tecla é solta **sem captura**, que é o caso comum em jogo.

**Correção:** `src/effects/YamiFX.gd:542` e `:684` passam a fruta
(`pedir_cancelar_hold("X", "yami_yami")`), e o `queue_free()` foi movido para
**antes** de tocar no caster — a saída do controlador não pode depender de uma
chamada externa dar certo.

**Como detectar de novo:** conjurar X sem ninguém por perto, soltar, e contar os
nós que respondem a `_throw_target` na árvore. Depois da correção: 0 controladores
e 0 orbes após 5 conjurações seguidas (contagem de cena estável em ~1.000 nós).

---

## 2026-08-23 — `world.get_tree()` é null no primeiro golpe de cada vida

**Sintoma:** a primeira conjuração do X da Yami em cada vida não marcava alvo
nenhum: sem `in_kurouzu`, sem o ícone `SUGADO`, sem os 4 s de silêncio. O vórtice
abria na mão e era só enfeite por ~150 ms.

**Causa raiz:** `YamiFX._find_closest_entity` fazia
`world.get_tree().get_nodes_in_group(...)`. O `world` é o `Skills_<jogador>` de
`Player._get_skills_container()`, que entra na cena por
`add_child.call_deferred(...)` — no primeiro cast ele **ainda não está na árvore**,
e `get_tree()` devolve null.

É literalmente a mesma armadilha que `FxUtil.autofree` documenta desde
2026-08-22, no mesmo repositório. Ela voltou porque a correção de lá foi aplicada
**num ponto só**, e não à classe de problema: qualquer código que receba `world`
como parâmetro está sujeito a ele.

**Evidência:**

```
SCRIPT ERROR: Cannot call method 'get_nodes_in_group' on a null value.
  at: _find_closest_entity (res://src/effects/YamiFX.gd:444)
  [1] _kurouzu  [2] cast  [3] _fire_skill  [4] _net_play_cast
```

O que mascarava: a revarredura do `KurouzuController` 150 ms depois roda a partir
de um nó já na árvore e achava o alvo. Por isso o golpe "quase" funcionava — a
distância no primeiro instante media 4,79 m em vez de 2,71 m.

**Correção:** `src/effects/YamiFX.gd:441` cai para
`Engine.get_main_loop() as SceneTree` quando `world.get_tree()` é null — o mesmo
SceneTree, sem depender de o nó estar pendurado.

**Como detectar de novo:** `grep -rn "world.get_tree()" src/effects/` deve voltar
vazio. Em jogo: conjurar o golpe na **primeira** vez de uma vida e procurar
`Cannot call method ... on a null value` no console.

---

## 2026-08-23 — o AutoDummy andava dentro do Black Hole

**Sintoma:** relatado pelo dono — "o C da Yami Yami não deve possibilitar que o
inimigo se mova". O boneco automático perseguia e socava normalmente com o poço
aberto em cima dele.

**Causa raiz:** `AutoDummy._physics_process` chama `super._physics_process(delta)`
e **continua**. O pai (`TrainingDummy`) sai cedo em `in_vortex`, `in_kurouzu` e
`in_black_hole`, mas `super` não interrompe o corpo do filho — o próprio arquivo
já documentava isso para a guarda de autoridade em 2026-08-22 e repetiu **só** o
`is_frozen`. As três metas de controle de multidão ficaram de fora.

**Evidência:** sonda em singleplayer com o C aberto, medindo os dois bonecos lado
a lado (`in_bh=true` nos dois o tempo todo):

```
             AutoDummy          TrainingDummy
t=5,4 s      0,18 m/s           0,32 m/s
t=5,7 s      1,45 m/s   <-      0,48 m/s
t=6,0 s      3,10 m/s   <-      0,40 m/s     (3,5 m/s = perseguição cheia)
```

O TrainingDummy fica nos ~0,4 m/s da sucção; o AutoDummy acelerava para a
velocidade de perseguição e escapava do poço.

**Descartado:** o jogador humano. Duas sondas de **dois processos** (host
conjurando/cliente vítima e o inverso), com W fisicamente segurado via
`Input.parse_input_event`, mostraram `velocity=(0,0,0)` na vítima durante todo o
poço — `Player._etapa_travamento` já respeitava `in_black_hole` nos dois sentidos
da rede. O deslocamento residual de 0,48 m/s era a sucção, não a tecla.

**Correção:** `src/entities/AutoDummy.gd` repete a mesma lista de metas do pai
antes de rodar a IA.

**Como detectar de novo:** abrir o C ao lado dos dois bonecos e comparar a
velocidade dos dois. Divergência = a IA está ignorando o controle.

---

## 2026-08-23 — `set_anchors_preset` sozinho: painel de HUD fora da tela

**Sintoma:** o painel novo dos bonecos de treino não aparecia no canto inferior
direito. Ao investigar, descobriu-se que o **painel de munição da Buki Buki
(`AmmoHud`) nunca tinha aparecido também** — erro silencioso desde que o arquivo
nasceu.

**Causa raiz:** `set_anchors_preset(PRESET_FULL_RECT)` recalcula as âncoras para
**manter** o retângulo atual, que num `Control` recém-criado é `(0,0)`. Todo
cálculo que parte de `size.x`/`size.y` resolve contra zero. O que faz o `Control`
preencher a viewport é `set_anchors_**and_offsets**_preset`.

**Evidência:** print do jogo rodando —

```
[DBG] DummyToggleHud visible=true  size=(0.0, 0.0)
[DBG]   ColorRect size=(250,72)  position=(-270,-92)   <- fora da tela
[DBG] AmmoHud size=(0.0, 0.0)
[DBG] MatchHud size=(1280.0, 1280.0)                   <- o que usa o preset certo
```

**Descartado:** `visible`, `mouse_filter`, ordem dos filhos na `CanvasLayer` e a
`z_index` — todos corretos.

**Correção:** `src/ui/DummyToggleHud.gd` e `src/ui/AmmoHud.gd` passam a usar
`set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.

**Como detectar de novo:** `grep -rn "set_anchors_preset(Control.PRESET_FULL_RECT)"
src/ui/` — em `_ready()` de HUD raiz, é sempre o errado. E, no jogo rodando,
imprimir `size` do nó: `(0,0)` num painel que deveria preencher a tela é o defeito.

**Lição de método (o erro é meu, e repetido):** o `MatchHud` documenta este exato
defeito desde 2026-08-12, com a mesma explicação, no mesmo repositório — e eu
escrevi a chamada errada de novo. O motivo de escapar é que **ela não vira erro em
teste nenhum**: compila, instancia, `visible` é `true`, os filhos existem, e todas
as sondas de árvore passam. Só a captura de tela do jogo rodando denuncia. Por isso
o `AmmoHud` conviveu meses com o defeito. Regra prática: HUD nova só conta como
entregue depois de **aparecer numa captura de tela**, nunca por sonda de árvore.

---

## 2026-08-10 — `--editor --quit` não detecta script que não compila

**Sintoma:** uma edição minha quebrou o `IceFX.gd` inteiro (usei a variável
`duration` num escopo onde ela não existe). A Ice Age parou de fazer **qualquer
coisa** — sem campo, sem congelamento, sem dano. E a checagem que eu vinha
usando a sessão toda, `godot --headless --path . --editor --quit`, reportou
**"0 erros"**.

Passei três rodadas de investigação achando que o problema era alcance da área
de efeito, posição do alvo e camada de colisão. Não era nada disso: a classe
não existia em tempo de execução.

**Causa raiz:** `--editor --quit` **reimporta assets e atualiza o cache de
`class_name`** — ele não *carrega* os scripts. Erro de sintaxe ou de
identificador não aparece nessa passada; só quando alguém tenta usar a classe,
em execução, e aí o sintoma é "o golpe não faz nada", que se confunde com bug de
gameplay.

**Evidência:** com o `IceFX` quebrado, `--editor --quit` → `0 erros`; o mesmo
projeto rodando o carregamento de verdade → `Parse Error: Identifier "duration"
not declared in the current scope`.

**Descartado:** não era alcance da área (o campo cresce de 0,35 a 11,0), não era
camada de colisão (dummy e player estão os dois na 1), não era posição do alvo.
Os três foram medidos antes de eu olhar para a compilação.

**Correção:** `tools/dev_tests/test_compila.gd` — carrega **todo** `.gd` do
projeto com `load()` e falha se algum voltar `null`.

```bash
godot --headless --path . --script tools/dev_tests/test_compila.gd
```

**Como detectar de novo:** rodar esse script depois de qualquer edição, e
**principalmente depois de edição automatizada** (`sed`, script de inserção) —
que é onde nasce o erro de variável fora de escopo, porque quem edita não está
lendo o entorno. `--editor --quit` continua útil para `class_name` novo e import
de asset; ele só não serve como prova de que o código compila.

---

## 2026-08-10 — Knockback não empurrava ninguém, nem em rede nem em um-jogador

**Sintoma:** relatado jogando — "jogador cliente e servidor não tomando knockback".

**Causa raiz — são DUAS, empilhadas:**

1. **A locomoção sobrescrevia o empurrão.** O bloco de movimento faz
   `velocity.x = dir.x * effective_speed` — **atribuição**, não soma. O
   `take_damage` somava o knockback em `velocity`, e no quadro seguinte a
   locomoção reescrevia X e Z do zero. Isso vale **inclusive em um-jogador**, e é
   por isso que os DOIS jogadores foram reportados sem knockback.
2. **Em rede, o servidor empurrava a cópia errada.** A `DamageZone` roda no
   servidor, então `take_damage` mexia na cópia que o servidor tem da vítima. Se
   a vítima é de outro peer, `velocity` ali não vale nada — a replicação traz a
   posição do dono no quadro seguinte e sobrescreve.

**Evidência:** teste com dois processos, servidor mandando empurrão de
`(0, 6, −40)` no cliente. Deslocamento medido: **0,00 m antes, 6,00 m depois**.

**Descartado:** não é força insuficiente nem `DamageZone` sem alcance — o log
`🚀 Knockback Final Aplicado` saía normalmente. O empurrão era calculado e
aplicado; só não sobrevivia ao quadro.

**Correção:**
- `_kb_impulso` — o componente horizontal do knockback virou um impulso próprio,
  que decai sozinho e é **somado depois** da locomoção escrever `velocity`, logo
  antes do `move_and_slide()`. O vertical continua indo direto em `velocity.y`,
  que a locomoção não reatribui.
- `net_apply_knockback` — o servidor manda o knockback **cru** para o DONO do
  corpo, e é lá que ele é escalado. Mandar o valor já calculado seria errado: as
  duas regras que o modelam (dobrar no ar, resistir andando contra) dependem de
  `is_on_floor()` e do **teclado da vítima** — e no servidor `Input.is_key_pressed`
  lê o teclado do host, não o de quem apanhou.

**Como detectar de novo:** teste de knockback tem que medir **deslocamento em
metros**, não a existência do log. E a regra geral: qualquer efeito que escreva
em `velocity` de fora do bloco de locomoção precisa ser um impulso separado —
`velocity` pertence à locomoção, que a reescreve todo quadro.

---

## 2026-08-10 — Fruta sem skills virava Gomu Gomu em silêncio

**Sintoma:** relatado jogando — "frutas equipadas diferente das que foram
adquiridas, por exemplo ope ope resulta em gomu gomu". E: "após a morte do
jogador cliente a fruta do jogador do servidor voltou a ser a gomu gomu".

**Causa raiz:** `Player._fire_skill` tinha

```gdscript
var fid := current_fruit_id if fruit_skills.has(current_fruit_id) else "gomu_gomu"
```

Um fallback **mudo**. Ele disparava em dois casos:

- **fruta sem skills:** o mapa planta 11 árvores, mas o `SkillSystem` só conhece
  9 frutas. `ope_ope`, `hito_hito_nika` e `tori_tori_phoenix` — **3 de 11** —
  entravam no inventário com o nome certo e davam os golpes da Gomu Gomu;
- **sem fruta nenhuma:** ao morrer o jogador larga a fruta
  (`current_fruit_id = ""`), e a partir daí os golpes saíam como Gomu Gomu, como
  se ele tivesse ganhado uma fruta ao morrer.

**Evidência:** cruzando o pool de árvores com o `SkillSystem` — 11 árvores, 9
frutas com poder, 3 órfãs. E `gura_gura` tem poderes mas **nenhuma árvore**, ou
seja, é impossível de obter jogando.

**Correção:**
- O pool de árvores passou a ser **derivado** de quem tem skills
  (`get_tree_definitions` filtra por `SkillSystem`), com log do que ficou de
  fora. As definições de arte continuam no arquivo — falta só dar poderes a elas.
- O fallback morreu. Sem fruta ou com fruta sem poderes, **o golpe não sai** e o
  jogo diz por quê.

**O que NÃO foi verificado:** o relato diz que a fruta do jogador do **servidor**
mudou quando o **cliente** morreu. Medido em dois processos, cada jogador larga
a **própria** fruta ao morrer, como esperado — não reproduzi o efeito cruzado. O
que o conserto garante é que "sem fruta" deixou de **parecer** Gomu Gomu. Se
ainda acontecer de uma fruta trocar de dono, o sintoma agora é visível em vez de
disfarçado.

**Como detectar de novo:** fallback silencioso em despacho de dados é armadilha —
ele transforma "faltou registrar" em "comportamento errado plausível". Se um id
não existe, falhe alto.

---

## 2026-08-10 — Pistola da Yami: o tiro do cliente não feria ninguém

**Sintoma:** relatado jogando — "Yami Yami: o jogador do servidor não toma dano
da pistola (Z) do cliente". No host funcionava.

**Causa raiz:** `_process_yami_pistol` chamava `YamiFX.bullet()` **direto**, sem
passar pelo servidor — ao contrário do `_request_bullet` da rajada Z, que já
fazia o trajeto certo. Como a `DamageZone` só aplica dano no servidor, a bala
disparada de um cliente existia **só na tela dele**.

No host o mesmo código funciona porque lá o local **é** o servidor — a mesma
classe de erro do bug da HUD no corpo errado.

**Correção:** o tiro passou a usar o trajeto que já existia —
`_do_server_bullet` no host, `_net_bullet_req.rpc_id(1, …)` no cliente. O
`_net_bullet_play` já despachava por fruta e trata `yami_yami`.

**Como detectar de novo:** todo efeito que causa dano precisa nascer no servidor.
Procure por `FX.*(get_tree().current_scene, …)` chamado de dentro de tratamento
de input local — é a assinatura do bug.

---

## 2026-08-10 — VFX do Gomu V ficava aceso no mapa para sempre

**Sintoma:** relatado jogando — "Gomu gomu está deixando um rastro luminoso
permanente no mapa quando o v é ativado".

**Causa raiz:** em `GomuRedHawk._spawn_explosion` o tween que apaga a luz era
criado com `create_tween()` — ou seja, **no próprio `GomuRedHawk`**. Só que esse
nó chama `queue_free()` no fim de `_impact()`. O nó morre, o tween morre junto,
o `tween_callback(light.queue_free)` nunca roda, e a `OmniLight3D` fica acesa.
**Uma luz órfã por uso do V.**

**Evidência:** contagem de nós da cena, 5 disparos seguidos: **+5 nós, todos
`OmniLight3D`** — exatamente 1,0 por disparo. Depois do conserto: **delta 0**.

**Correção:** o tween nasce na própria luz (`light.create_tween()`), que
sobrevive ao criador, mais um `FxUtil.autofree(light, 0.6)` como rede de
segurança. Na mesma passada saiu um segundo defeito: `global_position` era
escrito **antes** do `add_child`, e num nó fora da árvore isso devolve
`Transform3D()` com erro — o efeito nascia no centro do mapa em vez de na ponta
do braço. Corrigido no `GomuRedHawk` e no `GomuFX`; varredura confirmou 0
ocorrências restantes do padrão em `src/effects/` e `src/combat/`.

**Como detectar de novo:**
`godot --headless --path . --script tools/dev_tests/test_gomu_leak.gd -- V`
conta os nós antes e depois. Vazamento cresce **linear** com as repetições;
"ainda não terminou" não cresce. E a regra: tween que libera um nó tem que nascer
**no nó que ele libera**, nunca em quem o criou.

---

## 2026-08-10 — No cliente, a HUD inteira operava o corpo do HOST

**Sintoma:** relatado jogando. **Só no PC que ENTRA na sala**, nunca no que
hospeda: a energia não regenerava, nem depois de morrer, e as skills de fruta não
funcionavam.

**Causa raiz:** `Hud.gd`, `StatsHud.gd`, `SkillBar.gd` e `CharacterMenu.gd`
achavam o jogador com `get_tree().get_first_node_in_group("player")` — que
devolve o **primeiro da árvore**, não o **meu**. O servidor replica os players já
existentes para o peer novo **antes** de emitir `peer_connected`, então no
cliente o corpo do host entra primeiro e fica no índice 0. No host, o índice 0 é
o corpo dele mesmo.

**É essa a assimetria inteira:** `get_first_node_in_group` acerta no host e erra
no cliente, sempre. Por isso nunca apareceu em um-jogador — lá só existe um
corpo, e ele é o certo.

**Evidência**, medida no cliente com dois processos de verdade:

```
grupo[0] = '1'          auth=false   <- corpo do HOST
grupo[1] = '454688302'  auth=true    <- o meu
get_first_node_in_group('player') -> '1'
```

- **Energia:** a barra lia o fantasma do host. Aquele corpo não é autoridade, e
  `_physics_process` desvia para `_remote_process` antes da regen — que fica em
  `Player.gd:434`. Cada tecla ainda drenava 180 dele: **3916 → 3736 → 3556, sem
  nenhuma regeneração entre as leituras**. Ao morrer, `net_force_respawn()`
  repunha a energia do corpo **certo**, que a barra não mostrava.
- **Skills:** Z/X/C/V iam para o fantasma, e `_request_cast` corta em
  `not _is_authority` — nenhuma skill saía, cooldowns em 0.00 nos quatro slots.

**Descartado com medição:** `_is_authority` do cliente é **true** (o palpite
inicial de que estaria falso caiu); a ordem `set_multiplayer_authority` → `_ready`
está certa; as anotações `@rpc` são todas `any_peer` e não rejeitam nada; metas
`is_frozen`/`in_vortex`/`in_kurouzu`/`in_black_hole` ficam false; `is_suppressed`
false; `_movement_locked_timer` expira normalmente.

**Correção:** `Player.local_player(tree)` — devolve o corpo cuja
`is_multiplayer_authority()` é true, ou `null` (melhor nada que o errado). As 6
chamadas na UI passaram a usá-lo.

**Como detectar de novo:** `get_first_node_in_group` **não serve** para achar "o
meu" de nada em jogo em rede. Toda busca de nó de jogador tem que filtrar por
autoridade. E o teste precisa de **dois processos** — sondas em
`tools/dev_tests/net_host_probe.gd` e `net_client_probe.gd`.

⚠️ Armadilha da medição: em headless os frames correm muito mais rápido que o
tempo real, então contar `process_frame` como 1/60 s dá regeneração falsa
("+314 de 640 esperado" parecia meia-regen, era o relógio da sonda). Use
`Time.get_ticks_msec()`.

---

## 2026-08-10 — O timer de cast de uma skill apagava o `is_casting` da seguinte

**Sintoma:** encadear duas skills rápido faz a segunda sumir sem erro nenhum. Some
no cliente, no host e em um-jogador — no cliente é mais frequente.

**Causa raiz:** `_fire_skill` armava `create_timer(0.3)` para apagar
`is_casting`. Se a skill seguinte começasse dentro dessa janela, o timer da
**anterior** apagava o `is_casting` da **nova**. `Player.gd:446-447` lê isso como
"cast interrompido por dano" e zera `_charging`; aí `release_charge` cai no
`if not _charging: return` e o disparo nunca acontece.

**Evidência**, quadro a quadro em singleplayer:

```
release X feito.            is_casting=true  _charging=false
begin_charge('C')        -> _charging=true   is_casting=true
>>> _charging FOI ZERADO em 248 ms (Player.gd:447), is_casting=false
cooldown de C depois do release = 0.00   (a skill NÃO saiu)
```

**Correção:** `_cast_token` — `begin_charge` incrementa um contador, e o timer só
apaga `is_casting` se o token ainda for o do cast que o armou.

**Diagnóstico anterior corrigido:** eu tratei isto como bug **exclusivo do
cliente**. Não é — acontece nos três modos. O cliente sofre mais porque o timer
dele começa um round-trip de RPC depois (`_net_cast` → servidor →
`_net_play_cast`), o que empurra a janela de 0,3 s justo para cima da tecla
seguinte.

**Como detectar de novo:** temporizador que escreve em estado compartilhado
precisa carregar a identidade de quem o armou. O sintoma é sempre o mesmo —
funciona devagar, falha rápido.

---

## 2026-08-10 — O walk patinava 45% e a documentação afirmava 8%

**Sintoma:** `tools/dev_tests/test_walk_run.gd` reprovava nos 4 casos com deslize
de 45% (teto 10% no walk, 25% no run). Ninguém tinha rodado esse teste.

**Causa raiz:** identidade algébrica, não bug de conta:

```
v_pé = passada/π · ω    e    ω = π·v/passada · CADENCIA_ESCALA
   ⇒  v_pé = v · CADENCIA_ESCALA   ⇒  deslize = 1 − 0,55 = 45%
```

A **passada cancela**. Logo o deslize não depende do porte do personagem, da
passada nem da altura do quadril: `CADENCIA_ESCALA` é a única alavanca que existe
aqui, e o freio de 0,55 fixa 45% de patinação.

**Evidência:** `base` (perna 0,469 m) e `nami` (0,613 m) dão a MESMA velocidade de
pé, 2,31 m/s — foi essa coincidência impossível que denunciou. Deslize medido
fora do animador, reconstruindo o pé pelas rotações: 45,4 / 47,1 / 45,2 / 45,9%.

**Descartado:** não é constante comendo medida do corpo — a passada escala certo
com a perna (0,488 vs 0,655 m, razão 1,34 = 0,613/0,469). E `PASSADA_GANHO` está
**inerte**: trocar 1,6 por 1,3 não muda um milímetro, porque a passada pedida já
estoura o teto geométrico e é cortada por ele.

**Correção:** ⚖️ **nenhuma no comportamento, de propósito.** As duas saídas foram
medidas e as duas são piores: tirar o freio leva a cadência de 4,35 a 7,91
passos/s e *encolhe* a coxa de 87° para 72° (o walk frenético já rejeitado);
alongar a passada exigiria 1,83×, com o quadril a 10 cm do chão numa perna de
47 cm — impossível. Os 45% são preço escolhido. O que mudou foi o **teto do
teste** e o cabeçalho do `ProceduralAnimator`, que afirmava "8% de deslize" —
**número inventado**, sem medição por trás.

O conserto real é reduzir `Player.SPEED`: 4,2 m/s num corpo de 1,5 m equivale a
um humano a ~11 m/s.

**Como detectar de novo:** o teste **pedia a nota ao próprio animador**
(`anim.deslize()`) em vez de medir a pose que sai. Provado que mascarava: com
`CADENCIA_ESCALA = 1.0` o animador dizia **0%** enquanto a pose entregava **7%**
(walk) e **29%** (run, com `CADENCIA_MAX` mordendo sem ninguém ver). Hoje o teste
mede o pé na pose e tem teto de cadência, para ninguém "consertar" deslize
acelerando as pernas.

---

## 2026-08-10 — Proxies do rig se chamam `RoleProxy_<papel>`, e três sistemas procuram `<papel>`

**Sintoma:** ⚠️ **latente — ninguém viu ainda**, porque o elenco está trancado no
`base`, que é voxel. Passa a acontecer no instante em que um personagem
**skinnado** virar jogável: a pistola do Z (mera/hie) não aparece, o fôlego perde
a âncora da cabeça, e as armas da Buki Buki **flutuam na origem do mundo** em vez
de nascer no braço.

**Causa raiz:** no personagem voxel os papéis do rig são **nós com o nome do
papel** (`ForeArm_R`, `Head`). No skinnado não existem esses nós — o
`SkeletonDriver` cria proxies e os nomeia com prefixo:

```gdscript
# src/anim/SkeletonDriver.gd:106
p.name = "RoleProxy_" + role
```

Só que três lugares procuram o nome **puro**:

| lugar | busca | resultado no skinnado |
|---|---|---|
| `Player._attach_pistol()` | `find_child("ForeArm_L/R")` | `null` → pistola nunca aparece |
| `Player.gd:923` e `:973` | `find_child("Head")` | `null` → `_head_node` vazio |
| `BukiFX._membro()` | `find_child(papel)` | `null` → cai no fallback e pendura a arma em `current_scene` |

**Evidência:** medido nos 4 modelos Meshy — `find_child("ForeArm_R")` → `null`;
`find_child("RoleProxy_ForeArm_R")` → `Node3D`. O comentário no topo de
`BukiFX._membro()` afirma que "no skinnado o BodyScanner criou proxies com os
mesmos nomes" — **está errado**, e foi essa afirmação que escondeu o problema.

**Descartado:** não é o `SkeletonDriver` falhando em resolver papéis — ele
resolve **13/13** em todos os Meshy. O rig está certo; o que não bate é o nome
pelo qual os outros sistemas o procuram.

**Correção:** ⏳ pendente. O conserto barato é fazer o driver nomear o proxy com
o papel puro (`p.name = role`), o que conserta os três de uma vez. A alternativa
é os três aceitarem os dois nomes.

**Como detectar de novo:** teste que, para cada personagem **skinnado**, exija
`_membro(caster, "ForeArm_R") != null` e `_attach_pistol` produzir nó visível.
Hoje `tools/dev_tests/test_buki_buki.gd` roda só no `base` (voxel), onde os nós
existem de verdade — por isso passa verde com o bug presente.

---

## 2026-08-10 — Baker do Mixamo salva `.res` vazio e retorna sucesso

**Sintoma:** ⚠️ **latente.** Ao assar um `.glb` cujo esqueleto não use os nomes
`mixamorig_*` (por exemplo, um modelo Meshy exportado pelo Blender), o baker
grava o arquivo, **não emite erro nenhum** e reporta sucesso — mas o `.res` sai
com faixas sem uma única chave.

**Causa raiz:** o `MAP` em `tools/bake_mixamo.gd` (linhas 18-22) mapeia papel →
osso usando **só** nomes `mixamorig_*`. Quando nenhum casa, `rest` fica vazio e
os `continue` do laço pulam todas as inserções de chave. Não há checagem de
"quantos ossos eu encontrei?" antes de salvar.

**Evidência:** no modelo Meshy novo — `MAP` original: **0 de 12 ossos
encontrados**, `.res` salvo sem erro. Com aliases Meshy acrescentados
(`Spine`, `LeftArm`, `LeftForeArm`, …): **13/13**, e os 6 clipes assam com
121/42/53/19/27/31 chaves reais.

**Descartado:** não é o `GLTFDocument` nem o `fbx_to_glb.py` — o `.glb` de
entrada tem as curvas; é o mapeamento de nomes dentro do baker que não casa.

**Correção:** ✅ feita (2026-08-10). No `MAP` cada papel virou uma LISTA de
aliases, igual à `SkeletonDriver.BONE_ALIASES`, e o papel `Neck` entrou. O bake
agora **aborta** (`push_error` + saída 1) se resolver zero ossos ou inserir zero
chaves. Medido depois: esqueleto Meshy **13/13**, esqueleto `mixamorig_*`
**13/13**. Reassar o `punching` com o `MAP` novo devolve amplitude idêntica à de
antes (`SOMA_MEMBROS=533`) — os 28 clipes antigos não regridem.

Na mesma passada caíram mais dois defeitos do baker:

- **Um clipe por arquivo.** Ele pegava só o mais longo; um `.glb` de animações
  mescladas (o Meshy exporta assim, 6 clipes) perdia os outros 5. Agora assa
  todos: 1 clipe → nome do ARQUIVO (compatível com os 28 atuais, todos de um
  clipe `mixamo_com`), 2+ → nome do CLIPE em `snake_case`.
- **Salto de euler.** `Basis.get_euler()` devolve sempre o representante
  canônico, então duas poses vizinhas saíam como +179° e −179°: a faixa é
  LINEAR e o membro dava a volta longa. Medido nos 28 clipes antigos, **17 têm
  intervalos em que o membro percorre ~360° de giro espúrio entre duas chaves**
  (`armada` 359.8°, `dying` 361.3°, `kicking` 357.7°, `running_dive_roll`
  367.8°…). O baker agora escolhe, chave a chave, o euler EQUIVALENTE mais perto
  da chave anterior — as duas famílias da ordem YXZ, `(x,y,z)` e
  `(π−x, y+π, z+π)`, mais múltiplos de 2π por eixo. E passou a assar a 60 fps,
  porque a faixa é linear e a densidade de chaves é o único controle sobre o
  erro de interpolação. Nos clipes Meshy novos o percurso máximo entre chaves
  caiu para 17.2° (`left_uppercut`) e 12.4° (`right_upper_hook`).
  ⚠️ **Os 28 `.res` antigos continuam a 30 fps e com os saltos de ~360°** — só
  somem quando forem reassados (`-s tools/bake_mixamo.gd` sem filtro).

**Como detectar de novo:** depois de qualquer bake, rodar os dois:
`godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd`
(clipe vazio ou congelado acusa na hora; o tamanho do arquivo e a contagem de
faixas, não) e
`godot --headless --path . --script tools/dev_tests/medir_salto_res.gd`
(salto entre chaves vizinhas; a coluna `PERCURSO` é o giro que o membro faz de
verdade — é ela que denuncia o estalo, não o `EULER_max`, que incha perto do
gimbal sem que nada se mexa).

---

## 2026-08-10 — `hurricane_kick` toca com os membros congelados

**Sintoma:** o clipe existe, tem duração e chaves, e é ciclado normalmente no
"Teste de Animação" — mas em jogo o personagem só balança o tronco. Braços e
pernas ficam parados na pose de descanso.

**Causa raiz:** o defeito vem do **asset de origem**, não do baker.
`assets/animations_glb/hurricane_kick.glb` tem só **2 amostras de rotação em
todo osso de membro** (`LeftArm`, `LeftForeArm`, `LeftLeg`, `LeftUpLeg`,
`RightArm`, `RightForeArm`, `RightLeg`, `RightUpLeg`, `Spine`) e 56 no `Hips`.
Duas amostras com o mesmo valor = curva constante. É a **mesma falha de "1 chave
por osso" do importador FBX** descrita na seção 3 de
[`MUDANCAS_2026-08-06.md`](MUDANCAS_2026-08-06.md), que se acreditava eliminada
pela conversão FBX→glTF via Blender: ela **sobreviveu neste arquivo**, que
provavelmente foi convertido a partir de um FBX já sem as curvas de membro.

**Evidência:** medindo amplitude de movimento (max−min por eixo, somada) nos
papéis do rig, no `.res` assado:

| clipe | braço D | braço E | perna D | perna E |
|---|---|---|---|---|
| `hurricane_kick` | **0°** | **0°** | **0°** | **0°** |
| `kicking` | 272° | 274° | 757° | 681° |

E no GLB de origem, amostras de rotação por osso: `hurricane_kick` = 2 em todo
membro / 56 no Hips; `kicking` = 69 em todos.

**Descartado:** não é o baker (`tools/bake_mixamo.gd`) e não é o pipeline —
varrendo os 28 GLBs pelo mesmo critério, **27 estão corretos e só este falha**.
Também não é falta de faixa: o `.res` tem as 12 faixas e 57 chaves, com valores
plausíveis; elas é que são todas iguais entre si.

**Correção:** ❌ **impossível localmente — o FBX de origem também não tem as
curvas.** A causa foi empurrada um nível para trás: não é o baker, não é o
`fbx_to_glb.py` e não é a conversão glTF. O **próprio `.fbx` baixado do Mixamo
já veio sem animação de membro**. Não há o que reconverter: o dado não existe em
lugar nenhum da cadeia local.

**Evidência da causa final** (medida em 2026-08-10, três leituras independentes):

1. `assets/animations/hurricane_kick.fbx` e
   `~/Downloads/animações importadas do mixamo/Hurricane Kick.fbx` são **o mesmo
   arquivo** (md5 `a07713de5041d24f0a33ebd7fa43231d`). Não existe um "original
   bom" guardado.

2. **Importado no Blender 5.2** (`bpy.ops.wm.fbx_import`), única action
   `mixamo.com`, 520 fcurves — chaves de rotação por osso:

   | osso | `hurricane_kick.fbx` | `kicking.fbx` |
   |---|---|---|
   | LeftArm / LeftForeArm / RightArm / RightForeArm | **1** | 69 |
   | LeftUpLeg / LeftLeg / RightUpLeg / RightLeg | **1** | 69 |
   | Spine | **1** | 69 |
   | Hips | 56 | 69 |

3. **Lido direto do binário FBX**, sem passar por importador nenhum (parser
   próprio, zlib + Connections), para descartar culpa do Blender. Mesmo
   resultado. Os dois arquivos têm estrutura idêntica — FBX v7700, 315
   `AnimationCurve`, 54 `AnimationCurveNode`, 67 `Model`, e **os dois takes**
   (`Take 001` e `mixamo.com`, layers `Base Layer` e `Layer0`). Histograma de
   chaves por curva:

   | | curvas com 1 chave | curvas com todas as chaves |
   |---|---|---|
   | `hurricane_kick.fbx` | **153** | 162 (56 chaves) |
   | `kicking.fbx` | 18 | 297 (69 chaves) |

   Checado também o **segundo take**: os 153 curvas órfãs (não referenciadas em
   nenhuma das 666 conexões) do `hurricane_kick` têm 56 chaves, mas só **3 delas
   têm amplitude > 1°** — e são as do `Hips`. No `kicking`, 130 das 153 órfãs
   têm amplitude > 1°. Ou seja: **nem o take escondido salva**. No arquivo
   inteiro, o `hurricane_kick` tem 8 curvas com movimento real, todas do quadril;
   o `kicking` tem 269.

**Desfecho (2026-08-10): o clipe foi ELIMINADO do projeto**, por decisão do dono.
Nenhum código o carregava — os dois testes que o usavam já tinham sido migrados
para o `kicking`. Removidos: o `.res`, o `.fbx`, o `.fbx.import`, o `.glb` e a
cópia do editor de animação (mais a entrada no `index.json` dele). A biblioteca
foi de 30 para 29 clipes.

**Como trazer de volta, se quiser:** baixar outra vez em mixamo.com e rodar
`./tools/importar_animacao.sh <arquivo.fbx>` — que reconverte, assa e **recusa**
o arquivo se ele vier quebrado de novo (foi testado exatamente contra este
clipe). O antigo continua recuperável pelo histórico do git e pelo backup em
`~/dev/_backups/skills-one-piece/animations-20260810-200658/`.
Enquanto isso não acontece, **nada quebra**: o clipe não é referenciado por
nenhum código de jogo — só por `tools/dev_tests/test_rig_unico.gd`,
`tools/dev_tests/test_anatomia_rig.gd` e pelo índice do editor de animação. O
combate corpo a corpo usa `punching` e `kicking`.

**Diagnóstico anterior corrigido:** a entrada dizia "provavelmente foi convertido
a partir de um FBX já sem as curvas de membro" — confirmado, e o "provavelmente"
pode cair. Também cai a suspeita sobre o importador FBX do Godot **neste caso
específico**: aqui ele não tinha nada para perder.

**Como detectar de novo:** contar amostras **POR OSSO** no GLB — nunca por
número de faixas, de chaves ou de canais. Os três dão "ok" num clipe totalmente
congelado (este arquivo tem os mesmos 195 canais e 65 nós animados do `kicking`,
que está perfeito). Varredura dos 28 clipes:

```bash
python3 - <<'EOF'
import json, struct, os, glob
MEMBROS = {"LeftArm","LeftForeArm","RightArm","RightForeArm",
           "LeftUpLeg","LeftLeg","RightUpLeg","RightLeg"}
for p in sorted(glob.glob("assets/animations_glb/*.glb")):
    d = open(p,'rb').read()
    j = json.loads(d[20:20+struct.unpack('<I', d[12:16])[0]].decode('utf-8'))
    if not j.get("animations"): print("SEM CLIPE:", p); continue
    a = j["animations"][0]
    nomes = {i: n.get("name","") for i, n in enumerate(j["nodes"])}
    am = [j["accessors"][a["samplers"][c["sampler"]]["output"]]["count"]
          for c in a["channels"]
          if c["target"]["path"] == "rotation"
          and nomes.get(c["target"]["node"],"").replace("mixamorig:","")
                   .replace("mixamorig_","") in MEMBROS]
    if am and max(am) <= 2:
        print("CONGELADO:", os.path.basename(p), "max", max(am), "amostras")
EOF
```

Varredura equivalente no **`.res` assado** (mede amplitude em graus por papel do
rig, que é o critério que importa de verdade — clipe congelado tem as mesmas 12
faixas e 57 chaves de um clipe bom):

```bash
godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd
```

Marca `<<< CONGELADO` quando a soma da amplitude dos 8 papéis de membro fica
abaixo de 10°. Rodado em 2026-08-10 nos 28 clipes: só o `hurricane_kick` acusa
(0° em todo membro, 380° no `Torso`); o segundo menor é o `gunplay` com 81°, e a
mediana fica perto de 1.100°.

E para conferir o **FBX** antes de converter (Blender 5.2 — a API nova trocou
`Action.fcurves` por `layers → strips → channelbags → fcurves`; código antigo
estoura `AttributeError`): contar `len(fc.keyframe_points)` das fcurves cujo
`data_path` contém `rotation`, agrupando pelo osso entre `pose.bones["…"]`. Osso
de membro com **1 chave** = arquivo veio quebrado do Mixamo.

---

## 2026-08-07 — Cópia da fórmula no teste escondeu a mudança no código

**Sintoma:** entrou o freio de cadência no animador, mas o teste de walk/run
continuou reportando o mesmo ciclo e o mesmo deslize de antes — sem acusar nada.

**Causa raiz:** o teste tinha a fórmula da cadência **replicada**
(`minf(PI * planar / passada, CADENCIA_MAX)`). Quando o animador ganhou o fator
de escala, a cópia ficou para trás e passou a medir um estado que não existia
mais.

**Evidência:** com `CADENCIA_ESCALA = 0.62` aplicado, o teste ainda dizia
"ciclo 25 quadros, deslize 0%" para o `base` — exatamente os números de antes.

**Correção:** `ProceduralAnimator` expõe `cadencia()` e `deslize()`, e o teste
chama essas. Fonte única.

**Como evitar de novo:** teste de cálculo **chama a função do código**. Se for
preciso reescrever a conta para testar, o que está sendo testado é a cópia.

**Achado junto:** o teste também não aplicava o `CHAR_TARGET_H` que o jogo aplica,
então media o `base` com perna de 1,66 m em vez de 0,69 m — a cadência calculada
não era a que roda em jogo.

---

## 2026-08-07 — Trava de elenco vazou: o jogo abria com o Crocodile

**Sintoma:** com o elenco trancado no `base`, o jogo continuava começando com o
**Crocodile**.

**Causa raiz:** pus o guarda em `Player.set_character()`, que parecia a porta de
entrada — mas não é. `_setup_character_model()` tem **quatro** chamadores, e o
que vazava era o `equip_fruit()`: ele troca a aparência conforme a fruta
(`suna_suna` → `crocodile`) e chama `_setup_character_model()` **direto**. E o
`Main` equipa `suna_suna` ao nascer ([Main.gd:108](../Main.gd)).

**Evidência:** no log do jogo, `🔄 Troca automática de aparência: comendo a fruta
[suna_suna] -> transformado em [crocodile]!` logo depois do spawn.

**Correção:** guarda movido para o topo de `_setup_character_model()` — o ponto
de estrangulamento por onde todos passam. `equip_fruit()` também checa a trava
**antes de anunciar**, senão o log dizia "transformado em crocodile" e carregava
o base logo abaixo.

**Como evitar de novo:** antes de pôr um guarda, `grep` por **todos** os
chamadores do método que de fato carrega — e proteger esse, não o que parece ser
a entrada. Teste: `tools/dev_tests/test_elenco_trancado.gd` cobre os 12 caminhos
(inicial, 5 frutas, 5 `set_character`, chamada direta).

---

## 2026-08-07 — Personagem voxelizado saiu deitado: a malha do Meshy já é Y-up

**Sintoma:** ao exportar a malha para o editor posicionar marcadores, os modelos
Meshy vinham com altura errada — a Nami com **0,55 m** em vez de 1,70.

**Causa raiz:** apliquei o giro de −90° em X da Armature **na malha também**. Mas
`mesh.get_aabb()` da Nami dá `(0.78, 1.70, 0.55)` — 1,70 na altura, ou seja **a
malha já está em Y-up**. Aquele giro existe para orientar o **esqueleto**, que é
Z-up. Aplicando nos dois, a altura vira profundidade e o personagem deita.

**Evidência:** antes 0,55 m; depois da correção, 1,70 m nos quatro modelos Meshy.

**Correção:** `tools/export_mesh.gd` — `_coletar()` guarda também a transformação
de **antes da Armature** e usa essa para malha skinnada.

**Como evitar de novo:** malha e esqueleto do Meshy vivem em espaços
**diferentes**. Para a malha, transformação de antes da Armature; para o
esqueleto, a basis do driver. Esta é a **quarta** aparição do Z-up neste projeto.

---

## 2026-08-07 — Exportação pela metade: trabalho dentro de pipe morre por SIGPIPE

**Sintoma:** o lançador do editor preparava os dados na primeira execução, mas só
os **rigs** apareciam. Os 28 clipes não eram gerados — e o log não acusava erro
nenhum.

**Causa raiz:** coloquei as duas exportações num subshell **canalizado para
`zenity --progress`**, para mostrar a barra. Quando a janela do zenity fecha (ou
sequer abre), o pipe quebra e o `echo` seguinte mata o subshell com **SIGPIPE** —
exatamente entre a primeira exportação e a segunda.

**Evidência:** log terminando em `RIGS EXPORTADOS: 6`, sem nenhuma linha da
exportação de clipes e sem mensagem de erro. Depois da correção:
`RIGS EXPORTADOS: 6` **e** `CLIPES EXPORTADOS: 28`.

**Correção:** `tools/anim_editor/abrir.sh` — as exportações rodam fora de
qualquer pipe; o aviso virou um `notify-send` solto. A verificação passou a
conferir os **arquivos gerados**, não o código de saída do pipeline.

**Como evitar de novo:** janela de progresso é só aviso. Trabalho nunca depende
dela, e o sucesso se mede pelo artefato produzido.

---

## 2026-08-07 — Rig skinnado exportado deitado e espalhado pelo chão

**Sintoma:** no editor de animação em Python, os personagens voxel montavam
certo, mas a Nami (e os outros modelos Meshy) viravam caixas soltas espalhadas
rente ao chão.

**Causa raiz:** duas coisas erradas de uma vez na exportação. Os proxies criados
pelo `SkeletonDriver` são **irmãos soltos** sob o `model_root` — o `position`
deles é **global**, não local ao papel-pai — e vivem no espaço do **esqueleto**,
que nos modelos Meshy é **Z-up**. Exportei `n.position` cru, como se fosse local
e Y-up.

**Evidência:** depois da correção, `Torso` y=1,185, `Head` +0,122 acima,
`Thigh_R` −0,36 abaixo do torso, `Shin_R` −0,36 abaixo da coxa — proporções
anatômicas. Antes, tudo se acumulava perto de y=0.

**Correção:** `tools/export_rig.gd` — no caminho skinnado, aplicar a basis
`_axis` do driver e subtrair a posição do papel-pai, usando
`SkeletonDriver.RIG_PARENT` (não dá para caminhar a árvore de nós, porque não
existe hierarquia entre os proxies).

**Como detectar de novo:** abrir o editor e olhar. Personagem deitado ou
espalhado = conversão de espaço, não cinemática. É a **terceira** vez que o Z-up
dos modelos Meshy morde neste projeto — ver as duas entradas anteriores.

---

## 2026-08-06 — Tela cinza ao abrir o singleplayer no clone do GitHub

**Sintoma:** o usuário baixou o repositório em outro computador; o menu abre, mas
ao entrar no singleplayer a tela fica **cinza permanente**.

**Causa raiz:** ao publicar, coloquei `.godot/` no `.gitignore` (150 MB de cache
regenerável). Dentro dela mora o `global_script_class_cache.cfg`, que registra
todos os `class_name` do projeto. Sem ele, **todo script que cita `MapBuilder`,
`Hud`, `TreeScatter` etc. falha ao parsear** — o `Main.gd` inteiro não carrega, a
cena fica sem script, e então não há mapa, nem player, nem câmera. O Godot desenha
uma cena 3D sem câmera com a clear color padrão: cinza.

**Evidência:** clonei o repo para `/tmp` e rodei — reproduziu na hora:

```
SCRIPT ERROR: Parse Error: Identifier "MapBuilder" not declared in the current scope.
ERROR: Failed to load script "res://Main.gd" with error "Parse error".
```

Depois do `--editor --quit` (que gera o cache): **0 erros**, modelo carrega normal.

**Descartado:** um diagnóstico externo atribuiu o cinza a um frame sem câmera
seguido de congelamento do `MapBuilder` com "2601 iterações / 7.800 nós". Não
procede: `OBSTACLE_COUNT = 90`, e `MapBuilder.build()` é chamado **direto no
`_ready()`** ([Main.gd:28](../Main.gd)), não dentro do `call_deferred`. O cinza
não é um frame — é permanente, porque o script nunca carregou.

**Correção:** `setup.sh` (importa assets + gera o cache), chamado
**automaticamente** por `jogar.sh`/`servidor.sh` quando o cache não existe, e
`find_godot.sh` — porque os scripts também tinham o caminho do Godot e do projeto
chumbados para a máquina do autor, o que quebraria em qualquer outro computador.

**Como detectar de novo:** clonar para uma pasta limpa e rodar. Se aparecer
`Parse Error: Identifier "<algum class_name>" not declared`, é o cache faltando.

---

## 2026-08-06 — Cadência da marcha: usei 2π onde era π

**Sintoma:** pé patinando no chão durante a caminhada, mesmo com a IK de pé.

**Causa raiz:** para o pé não deslizar, ele tem que recuar exatamente na
velocidade do corpo durante o apoio. Cada perna fica em apoio **metade** do ciclo,
e nessa metade o corpo avança **uma** passada — logo `ω = π·v/passada`. Eu usei
`2π`, o que dobra a cadência. Além disso a trajetória do pé no apoio precisa ser
**linear**: com senoide o pé varre rápido no meio e devagar nas pontas, enquanto o
corpo avança a velocidade constante — deslize garantido.

**Evidência:** com `2π` + senoide, o pé recuava a 2,2 m/s contra 4,2 m/s do corpo.
Com `π` + linear: **4,20 vs 4,20 — deslize 0%**.

**Correção:** `_passada()` e o avanço de fase em `ProceduralAnimator.update()`;
trajetória linear no apoio em `_perna_ik()`.

**Como detectar de novo:** `tools/dev_tests/test_walk_run.gd` compara
`(passada/π)·ω` com a velocidade do corpo.

---

## 2026-08-06 — Pé de apoio flutuando: bob por fórmula não fecha

**Sintoma:** mesmo com a IK, a altura do pé de apoio variava 2-9 cm ao longo do
ciclo.

**Causa raiz:** as rotações das juntas passam por um filtro de suavização
(`STIFFNESS`), mas eu calculava a subida do quadril por **fórmula**. Filtrar um
ângulo não é o mesmo que filtrar a altura resultante, então os dois nunca
cancelavam. Aumentar a rigidez reduzia mas não zerava.

**Correção:** inverter a lógica — `_bob_dos_pes()` **mede** a pose que de fato
saiu (já filtrada) e ajusta o quadril para o pé mais baixo encostar sempre na
mesma altura. E esse ajuste **não pode ser filtrado de novo**, senão reintroduz o
atraso que ele existe para cancelar.

**Evidência:** variação da altura do pé de apoio caiu para **0,0000**.

**Como detectar de novo:** `test_walk_run.gd`, item "altura do pé de apoio varia".

---

## 2026-08-06 — Ninguém planta o pé no chão ao andar (RESOLVIDO)

**Sintoma:** o personagem parece flutuar / quicar em vez de pisar. Visível na
gravação lateral do Barba Negra.

**Causa raiz:** `_locomotion` dobra os **dois** joelhos com o mesmo padrão, então no
cruzamento do ciclo as duas pernas estão dobradas ao mesmo tempo e o corpo afunda.
Não existe IK travando o pé de apoio no chão — nada garante que sempre haja um pé
plantado.

**Evidência:** profundidade do pé mais baixo em relação ao quadril, ao longo do ciclo:

| modelo | perna | variação | % da perna |
|---|---|---|---|
| blackbeard | 0,523 | 0,092 | 17,6% |
| ace | 0,639 | 0,152 | 23,8% |
| nami | 0,681 | 0,166 | 24,4% |
| crocodile | 0,686 | 0,186 | 27,1% |

Numa caminhada real o pé plantado fica parado e o quadril sobe/desce só ~5% — o
corpo vaulta sobre a perna de apoio. Aqui varia 5× mais.

**Correção:** ainda **não feita**. Precisa de IK de duas juntas por perna, com alvo
no chão durante a fase de apoio.

**Como detectar de novo:** `tools/dev_tests/debug_pisada.gd`. A variação do pé mais
baixo deveria ficar perto de zero.

---

## 2026-08-06 — Barba Negra parece anão (é o modelo, não a animação)

**Sintoma:** na gravação lateral, o tronco e o casaco ocupam quase toda a altura e as
pernas são dois tocos.

**Causa raiz:** proporção do modelo gerado pelo Meshy — a canela mede **0,184**
contra **0,338** da coxa, ou seja **54%**. Numa perna humana as duas são quase iguais.
O casacão cobrindo o quadril piora a leitura.

**Evidência:** comparando os quatro modelos Meshy — nami 88%, crocodile 75%, ace 68%,
**blackbeard 54%**. É o único fora da faixa.

**Correção:** nenhuma no animador — não é bug de animação. As saídas são regerar o
modelo no Meshy com proporção melhor, escalar o osso da canela, ou aceitar como
traço do personagem.

**Como evitar de novo:** antes de culpar o animador por silhueta estranha, medir
coxa/canela do modelo com `tools/dev_tests/debug_pisada.gd`.

---

## 2026-08-06 — Personagem anda ereto, sem inclinar o tronco (regressão minha)

**Sintoma:** reportado pelo usuário — "falta a orientação do corpo do jogador um
pouco para frente, o jogador está andando como se estivesse sempre reto para cima".

**Causa raiz:** ao corrigir o exagero do balanço de braço (entrada abaixo), eu
derrubei o `lean` de `lerpf(0.05, 0.35)` para `lerpf(0.02, 0.06)` **no mesmo
passo** — de 20° para 3°. O balanço estava errado; a inclinação não estava. Reduzi
tudo na mesma proporção em vez de dar alvo próprio a cada constante.

**Evidência:** inclinação média do tronco medida em 3,4° andando, contra os ~10°
que o movimento humano pede.

**Correção:** `lean = lerpf(0.05, 0.17, t)` com `+0.16` no sprint, e a cabeça
compensando `lean * 0.75` (era `0.5`) para o personagem não correr encarando o
chão. Resultado medido:

| | tronco | cabeça (local) | olhar resultante |
|---|---|---|---|
| andando | +9,7° | −7,3° | +2,4° |
| correndo | +18,9° | −14,2° | +4,7° |

**Como evitar de novo:** ao recalibrar um bloco de constantes de uma vez, cada uma
precisa do **seu** alvo. Escalar o bloco inteiro pelo mesmo fator quebra as que
estavam certas. Detectar com `tools/dev_tests/debug_inclinacao.gd`.

---

## 2026-08-06 — Personagem anda com os braços para cima

**Sintoma:** reportado pelo usuário — "a animação de walk e run está estranha e o
personagem está andando com os braços para cima". Confirmado em vídeo.

**Causa raiz:** amplitude do balanço calibrada em valores absurdos no
`ProceduralAnimator._locomotion`. `A_arm = lerpf(0.55, 1.55, speed01)` — e
**1,55 rad = 89°**. Como o braço parte do repouso **pendurado** (elevação −90°),
esses 89° o levavam até quase a **horizontal**. Correndo, o multiplicador `×1.4`
do sprint chegava a **124°**. Coxa e joelho tinham o mesmo exagero, só que menos
perceptível. Não era bug do rig skinnado — afetava voxel e skinnado igualmente.

**Evidência:** elevação do braço (arco-seno do Y da direção ombro→cotovelo) na
velocidade real do jogo:

| | antes | depois |
|---|---|---|
| Base (voxel) | −74° a **−21°** | −77° a −62° |
| Nami (skinnado) | −57° a **−21°** | −59° a −52° |

−21° é o braço quase na horizontal. Referência humana: braço balança ~20° andando
e ~45° correndo; coxa ~25° e ~40°.

**Correção:** `src/anim/ProceduralAnimator.gd`, `_locomotion()` — amplitudes
recalibradas contra movimento humano, com os valores em graus comentados ao lado.
`A_arm = lerpf(0.12, 0.35)` com `×2.2` no sprint; `A_thigh`, `A_knee`, `lean`,
`arm_out` e o giro de ombro na mesma proporção.

**Como detectar de novo:** `tools/dev_tests/debug_amplitude.gd`. A elevação do
braço andando tem que ficar perto de −75°; se chegar perto de −20°, está errado.
Capturas visuais com `tools/dev_tests/captura_anim.gd`.

---

## 2026-08-06 — Medir pose pelos nós-proxy do rig skinnado engana

**Sintoma:** meu diagnóstico disse que a perna da Nami varria **0,0°** enquanto a
do voxel varria 95° — conclusão de que o driver não funcionava.

**Causa raiz:** os proxies criados pelo `SkeletonDriver` só carregam **rotação**;
a posição deles nunca muda. Medir a direção de um membro por
`proxy_b.global_position - proxy_a.global_position` devolve sempre o mesmo vetor.

**Evidência:** ao trocar a medição para `get_bone_global_pose()` dos ossos reais,
convertida pelo `_axis` do driver, os números bateram: **95,2°** na Nami contra
**95,3°** no voxel.

**Correção:** nada no jogo — o erro era do diagnóstico. `debug_amplitude.gd` agora
lê os ossos quando o personagem é skinnado.

**Como evitar de novo:** em personagem skinnado, pose se mede nos **ossos**, nunca
nos proxies. Proxy é entrada do sistema, não saída.

---

## 2026-08-06 — Membros colapsam para dentro do corpo ao animar (modelos Meshy)

**Sintoma:** o usuário gravou o jogo e o Blackbeard ficava perfeito em repouso, mas
ao animar os braços e pernas encolhiam para dentro do tronco. Frames extraídos do
vídeo com `ffmpeg` confirmaram.

**Causa raiz:** o esqueleto dos modelos Meshy AI é **Z-up** — a altura está no eixo
Z (`Hips z=0.717`, `Spine z=1.068`, `Head z=1.219`) e a Armature carrega uma rotação
de −90° em X para corrigir. Os offsets do `ProceduralAnimator` são autorados em
**Y-up** e estavam sendo aplicados direto no espaço do osso, girando nos eixos
errados. Junto disso, o delta era acumulado pela hierarquia dos **ossos** em vez da
do **rig**, e ossos intermediários não mapeados (Shoulder, Spine01, Neck) eram
ignorados no meio da cadeia.

**Evidência:** medindo a anatomia em repouso, o pé saía **acima** do quadril
(`pé y=0.017` contra `quadril y=−0.038`) — anatomicamente impossível. Foi esse
absurdo que denunciou o eixo trocado.

**Correção:** `src/anim/SkeletonDriver.gd`, função `push()`, em 3 passos —
(1) acumular pela hierarquia do RIG (`W[papel] = W[pai] * offset`);
(2) conjugar para o espaço do esqueleto (`d_skel = A⁻¹ · W · A`, com `A` calculada
subindo a árvore até o holder); (3) compor com o repouso global e dividir pela pose
global do pai, percorrendo **todos** os ossos.

**Como detectar de novo:** `tools/dev_tests/test_anatomia_rig.gd`. Ele mede no
espaço do **personagem** — medir no espaço do osso engana por causa do Z-up. Pé
abaixo do quadril e comprimento de membro preservado são os dois critérios.

---

## 2026-08-06 — Todos os `.res` de animação estavam zerados (e sempre estiveram)

**Sintoma:** o estilo "Teste de Animação" mostrava o nome do golpe no HUD, mas o
personagem ficava parado na pose de descanso. Nunca funcionou — não foi regressão.

**Causa raiz:** o importador FBX do Godot (**ufbx**, `fbx/importer=0`) lê **1 chave
só** por osso de membro nos arquivos do Mixamo. Apenas `mixamorig_Hips` recebia
chaves reais (55 de posição, 26 de rotação). O baker então calculava delta zero para
todos os membros e gravava faixas válidas cheias de `Vector3.ZERO`.

**Evidência:** amostragem das 12 faixas de `hurricane_kick.res` em 0%, 25%, 50% e
75% do clipe — todas devolvendo `Vector3.ZERO`. As curvas **existem** no FBX:
`strings` acha 371 `AnimationCurve`, e o Blender importa **520 fcurves**. Os arquivos
regerados bateram byte a byte em tamanho com os antigos, provando que o bake é
determinístico e o problema era anterior.

**Descartado (não resolve):** `animation/trimming=false`,
`animation/remove_immutable_tracks=false`, `callback_mode_process = MANUAL` no mixer,
`advance()` no lugar de `seek()`.

**Correção:** passo novo de conversão **FBX → glTF pelo Blender headless**
(`tools/fbx_to_glb.py`), e o baker passou a ler `.glb` via `GLTFDocument`
(`tools/bake_mixamo.gd`). O Godot lê glTF com **57 chaves por osso**.

**Como detectar de novo:** amostrar as faixas do `.res` em vários instantes. Se
derem todas zero, o clipe está vazio. `BAKE FINAL: ok=N fail=0` **não** prova nada —
o baker considera sucesso um arquivo estruturalmente válido, mesmo zerado.

---

## 2026-08-06 — `root_node` errado no baker fazia o mixer ignorar todas as faixas

**Sintoma:** nenhuma faixa de osso resolvia ao tocar o clipe durante o bake.

**Causa raiz:** o baker fazia `ap.root_node = ap.get_path_to(skel.get_parent())`, mas
as faixas do glTF são `Armature/Skeleton3D:<osso>` — relativas à **raiz da cena**,
não ao pai do esqueleto.

**Evidência:** `AnimationMixer: couldn't resolve track: 'Armature/Skeleton3D:mixamorig_Hips'`.

**Correção:** `ap.root_node = ap.get_path_to(scene)` em `tools/bake_mixamo.gd`.

**Como detectar de novo:** o aviso `AnimationMixer: couldn't resolve track` no
console. Ele é fácil de perder no meio do log do bake, e **não** faz o bake falhar —
o `.res` sai zerado com `ok=N fail=0`. Ao mexer no baker, olhar o log inteiro.

---

## 2026-08-06 — `get_bone_global_pose()` fica obsoleto após `seek()` em headless

**Sintoma:** durante o bake, a pose do osso não mudava com o tempo — devolvia sempre
o valor do `t=0`, mesmo variando o `seek`.

**Causa raiz:** num script `extends SceneTree` sem frames rodando, o `Skeleton3D` não
recalcula as poses globais depois do `seek()` do AnimationPlayer. As poses **locais**
(`get_bone_pose`) atualizam na hora; as globais, não.

**Evidência:** amostrando `mixamorig_RightUpLeg` em t=0,0 / 0,4 / 0,8 / 1,2 s, a pose
local devolvia exatamente `(-1.141564, 0.277879, 2.344162)` nos quatro instantes.
Trocar `seek()` por `advance()` e pôr o mixer em `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`
não mudou nada.

**Correção:** compor a pose global à mão subindo a cadeia de pais pelas poses locais
(`_global_pose_basis` em `tools/bake_mixamo.gd`).

**Como detectar de novo:** amostrar o mesmo osso em instantes diferentes do clipe. Se
o valor repetir idêntico, a pose global está congelada — não é o clipe que está vazio.

---

## 2026-08-06 — Diagnóstico errado: acusei um rig que nem executava

**Sintoma:** afirmei com confiança que Base e Buggy estavam num rig quebrado, sem
cotovelo nem joelho.

**Causa raiz:** eu **li** `VoxelMeshes.build_buggy` e assumi que ela rodava. Não
verifiquei o caminho de execução: `CharacterBuilder.build_character` checa o `.scn`
**antes** de cair nas meshes voxel, e os `.scn` existem — então aquela função é
código morto.

**Evidência:** dump real dos modelos deu **13/13 papéis** em `base.scn`, `base.glb`,
`buggy.scn` e `buggy.glb`.

**Correção:** nada no código — era diagnóstico, não bug. O que mudou foi o método.

**Como evitar de novo:** antes de acusar uma função, confirmar qual **branch
realmente roda**. Ler o corpo da função não prova que ela é chamada.

---

## 2026-08-06 — Armadilhas de ambiente que custaram tempo

Quatro tropeços de ferramenta/configuração, cada um com causa e conserto.

### `godot` e `blender` não estão no PATH
**Sintoma:** `bash: godot: comando não encontrado` — o comando falha silenciosamente
dentro de um pipeline maior e o passo seguinte roda com dados velhos.
**Causa raiz:** os binários são baixados à mão, não instalados por pacote.
**Correção:** usar o caminho completo —
`/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64` (o mesmo do
`jogar.sh`) e `/home/gabriel-bitti/opt/blender-5.2.0-linux-x64/blender`.
**Como detectar:** `which godot` vazio.

### Projeto sem git e sem backup
**Sintoma:** nenhum — o risco só aparece depois de perder algo.
**Causa raiz:** `skills-one-piece` não é repositório git e não há cópia.
**Correção:** antes de qualquer passo que sobrescreve arquivos em massa (o bake
sobrescreve 28 `.res`), conferir tamanho/hash antes e depois. Foi assim que confirmei
não ter destruído os `.res` antigos.
**Como detectar:** `git rev-parse --is-inside-work-tree` falhando.

### `extends SceneTree` precisa de `await process_frame`
**Sintoma:** `ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()`
e todas as medições saem zeradas.
**Causa raiz:** em `_init()` a árvore de cena ainda não está viva, então
`global_position` não vale.
**Correção:** `func _init(): _run()` + `func _run(): await process_frame` antes de
qualquer medição.
**Como detectar:** o próprio erro acima no console — não ignorar, ele invalida o teste.

### Blender 4.4+ trocou a API de Action
**Sintoma:** `AttributeError: 'Action' object has no attribute 'fcurves'`.
**Causa raiz:** o sistema de *slots* substituiu `Action.fcurves` por
`layers/strips/channelbags`.
**Correção:** helper que tenta `act.fcurves` e cai para a travessia de
layers/strips/channelbags (`contar_fcurves` em `tools/fbx_to_glb.py`).
**Como detectar:** o `AttributeError` — e vale checar a versão antes de assumir a API.

### `class_name` novo derruba o jogo inteiro em TELA CINZA
**Sintoma:** clicar em JOGAR SINGLEPLAYER "não faz nada". O menu some, e fica uma
tela cinza. Parece bug do botão — não é.

**Causa raiz:** um `class_name` só existe se estiver no
`.godot/global_script_class_cache.cfg`, e esse cache **só é regenerado por
reimportação** (`--editor --quit`). Quando a Fase 2 da partição do Player criou
`class_name CameraRig`, o cache seguiu velho. Aí:

```
Parse Error: Could not find type "CameraRig" in the current scope.
Compile Error: Failed to compile depended scripts.
Invalid call. Nonexistent function 'local_player' in base 'GDScript'.
```

O `Player.gd` não compila; a cena do mundo depende dele; ninguém spawna; não há
câmera. **O clique funcionou o tempo todo** — o que quebrou foi a cena de
destino.

**Por que passou por todos os testes:** minha rotina roda `--editor --quit`
antes da suíte, o que regenera o cache. Ou seja, eu testava sempre no único
estado em que o bug não existe. O `jogar.sh` não roda isso.

**Correção:** `checar_cache.sh` (novo), chamado por `jogar.sh` e `servidor.sh`.
A checagem antiga era `[ ! -f cache ]` — pegava cache **ausente** (clone novo) e
nunca cache **defasado**. A nova compara os `class_name` do fonte com os do
cache e regenera quando falta algum.

**Como detectar:** rodar o jogo e procurar `Could not find type` /
`Failed to compile depended scripts` no console. Um `grep -c "NomeDaClasse"
.godot/global_script_class_cache.cfg` valendo 0 confirma.

**Lição de método:** *toda* fase seguinte da partição do Player cria classe
nova. Um bug que só aparece fora do ambiente de teste continua sendo um bug —
e preparar o ambiente antes de testar é justamente o que o esconde.

---

## 2026-08-27 — na parede o corpo só olhava para os lados

**Sintoma (relatado pelo dono):** andando pela parede, o personagem ficava sempre
virado para a direita ou para a esquerda.

**Causa raiz:** o MOVIMENTO usava a base da superfície (`frente·f + direita·r`),
mas a FRENTE DO CORPO usava `q.dir` — a direção **horizontal do mundo** —
projetada no plano. Numa parede vertical, `q.dir` do W é exatamente a componente
que a projeção anula: sobravam A e D, e o corpo nunca olhava para onde subia.

Movimento e olhar são a **mesma decisão**; tirá-los de fontes diferentes é a
mesma armadilha das cinco cópias da direção da frente que já custaram caro aqui.

**Correção:** a frente do corpo passou a sair da mesma
`base_da_superficie()` que o movimento, com os mesmos `q.f`/`q.r`.

**Evidência:** produto escalar entre para onde o corpo olha e a direção andada —
`+1,00` nas quatro teclas (para cima, para baixo, esquerda, direita).

**Como detectar de novo:** a asserção testa a frente **por tecla**. A anterior só
verificava que o corpo estava alinhado com a superfície, o que continuava
verdadeiro com o corpo virado para o lado errado.

---

## 2026-08-27 — duas asserções minhas eram INSTÁVEIS (passavam e reprovavam)

**Sintoma:** a mesma sonda dava `24/0` numa execução e `21/3` na seguinte, sem
nenhuma mudança de código.

**Causa raiz:** duas asserções apostavam em TEMPO em vez de esperar CONDIÇÃO.

1. *"nenhum efeito de tela"* exigia soma **exatamente** abaixo de 0,001. Os
   parâmetros do `ScreenFX` chegam a zero por interpolação e ainda têm resíduo de
   milésimos alguns quadros depois: reprovava por `0,0018`.
2. O teste do cancelamento esperava **"25 quadros"** pela carência de 0,25 s — uma
   aposta sobre o tempo de quadro. Quando chegava cedo, o espaço caía dentro da
   carência e **três** asserções caíam juntas.

**Correção:** limiar com folga de uma ordem de grandeza (0,01, bem abaixo do
visível) e espera de sobra no primeiro; espera por **condição**
(`_carencia_parede <= 0`) no segundo.

**Evidência:** três execuções seguidas em `24/0`.

**Como detectar de novo:** teste que oscila sem mudança de código é teste que
mede o relógio, não o programa. **Esperar condição, não contar quadros** — e
limiar de "efeito invisível" não é zero exato.

---

## 2026-08-27 — a direção na parede invertia com 5° de mouse (o bug intermitente)

**Sintoma (relatado pelo dono):** andando na parede o personagem ia "para o lado,
para o lado, para cima e assim por diante". **Não acontecia sempre** — só apareceu
depois de testar várias vezes.

**Causa raiz:** a base da superfície era recalculada TODO QUADRO a partir de
`q.frente` (a frente da câmera) **projetada** no plano da parede. Essa projeção
**degenera** quando a câmera olha direto para a superfície — que é exatamente o
que o jogador faz enquanto anda nela. Medido, numa parede de normal −Z:

```
yaw 175°   |projeção| = 0,087   frente = (−1, 0, 0)
yaw 180°   |projeção| = 0,000   frente =  indefinida
yaw 185°   |projeção| = 0,087   frente = (+1, 0, 0)
```

**Cinco graus de mouse invertem o eixo do movimento.** O W ia para um lado, para
o outro, e para cima quando caía no fallback. A intermitência não era mistério: o
defeito só existe perto desse ângulo.

**Correção:** a base virou **persistente com histerese**. Só se atualiza quando a
candidata está bem condicionada (`|projeção| > 0,35`, ~20° de folga em torno da
degeneração); fora disso, mantém a que já vale, reancorada na normal atual. E a
atualização é por `slerp`, nunca por substituição, para nunca saltar ao cruzar o
limiar.

Perto da degeneração a frente da câmera **não carrega informação** sobre o plano
da parede — congelar uma base boa é melhor que seguir uma ruim.

**Evidência:** com a câmera oscilando ±8° em torno do ângulo crítico, a maior
virada da base entre quadros vai de **180,0° → 0,0°**.

**Descartado:** trocar a fórmula da projeção (qualquer fórmula degenera no mesmo
ponto) e usar sempre "para cima da parede" (estável, mas tira o controle
relativo à câmera).

**Como detectar de novo:** a sonda mede a **base**, não o deslocamento. ⚠️ A
primeira versão segurava o W por 90 quadros e olhava para onde o corpo ia — mas a
7 m/s isso sobe 10 m, o jogador passa do TOPO do bloco e cai: o teste reprovava
por motivo legítimo e escondia o que se queria medir. A base existe sem o jogador
andar, e é o que o defeito atacava.

---

## 2026-08-27 — subir a parede não animava: o animador só enxerga o plano XZ

**Sintoma (relatado pelo dono):** andando para cima ou para baixo no bloco, a
animação não aparecia — andando de lado, aparecia.

**Causa raiz:** `ProceduralAnimator.update` mede a caminhada com
`Vector2(velocity.x, velocity.z).length()` — só o plano **horizontal do mundo**.
Subir a parede é movimento em **Y**, invisível para essa conta: o ciclo lia
velocidade zero e o corpo ficava parado. De lado funcionava porque aí o
movimento é mesmo horizontal.

**Evidência** (variação da pose do rig, por direção):

```
antes:   para cima ~0     para baixo ~0     para o lado ok
depois:  para cima 3,73   para baixo 4,05   para o lado 3,46
```

**Correção:** o Player decompõe a velocidade na base da **superfície** (quanto é
"para frente", quanto é "para o lado") e a reemite na base horizontal do corpo. O
animador recebe uma caminhada com a magnitude e a repartição certas, sem saber
que existe uma parede.

⚠️ E a base da superfície virou **fonte única** (`base_da_superficie()`), usada
pelo movimento E pela animação — as duas precisam da MESMA decomposição, e duas
cópias divergiriam.

**Como detectar de novo:** a asserção testava só o W. **Uma direção não cobre** —
foi exatamente por isso que o defeito passou.

---

## 2026-08-27 — cancelar a parede gastava um pulo duplo

**Sintoma:** largar a superfície com espaço consumia um geppo, punindo o jogador
por usar o cancelamento que a própria mecânica exige.

**Causa raiz:** zerar `_geppo` dentro de `_soltar_da_parede` não bastava —
`aplicar_pulos` roda **depois**, no mesmo quadro, vê o mesmo `espaco_agora` e
gasta de novo.

**Evidência:** `geppos` = 1 logo após o cancelamento; 0 depois do conserto.

**Correção:** uma marca de um quadro (`_consumiu_espaco`) diz que aquele toque já
foi usado, e `aplicar_pulos` sai sem fazer nada.

**Como detectar de novo:** conferir o CONTADOR depois do cancelamento, não só o
estado. Efeito colateral de ordem entre sistemas não aparece no estado final de
um só deles.

---

## 2026-08-27 — na parede só A e D andavam (a projeção anulava o W)

**Sintoma (relatado pelo dono):** fixado na parede, o jogador só conseguia se
mover para a direita ou esquerda.

**Causa raiz:** o movimento era `q.dir` **projetado** no plano da superfície. Mas
`q.dir` é **HORIZONTAL** — vem do yaw da câmera —, então numa parede vertical o W
produz exatamente a componente que aponta PARA DENTRO da parede, e a projeção a
anula. Sobravam só A e D, que já eram paralelos ao plano.

**Evidência** (deslocamento no plano da superfície, por tecla):

```
com o bug:   W 0,000   S 0,000   A 0,725   D 0,805
corrigido:   W 0,724   S 0,724   A 0,725   D 0,725
```

**Correção:** o movimento passou a ser montado numa **base da superfície** — a
normal é o "para cima", a frente é a da câmera projetada no plano, a direita sai
do produto vetorial. Aí `mov = frente·f + direita·r`, e W anda parede acima.

Projetar a direção final e montar a direção NA BASE CERTA parecem a mesma coisa e
não são: a projeção descarta informação que a base preserva.

**Como detectar de novo:** `medir_camera_e_parede.gd` mede **tecla por tecla**. A
versão anterior olhava só "está na parede" e passava com metade dos controles
mortos.

---

## 2026-08-27 — sem animação na parede: o animador achava que estava caindo

**Sintoma (relatado pelo dono):** nenhuma animação enquanto andava na parede.

**Causa raiz:** `ProceduralAnimator.update` decide entre ciclo de caminhada e
pose de ar pelo parâmetro `on_floor` — e o Player passava `is_on_floor()`, que na
parede é **false**. O animador tocava a pose de queda o tempo todo, e o corpo
ficava parado.

**Correção:** para o animador, a superfície **é** o chão:
`is_on_floor() or _parkour.na_parede()`.

E a velocidade vai **sem a componente de aderência** — aquele empurrão constante
contra a parede é contato, não deslocamento, e faria o ciclo de caminhada rodar
com o jogador parado.

**Como detectar de novo:** a sonda compara as rotações dos membros antes e
durante a caminhada; se não mudam, não há animação.

---

## 2026-08-27 — `global_basis` ortonormalizada DESTRÓI a escala (personagem 2,4× maior)

**Sintoma (relatado pelo dono):** ao colidir com a parede, o personagem
**aumentou de tamanho**.

**Causa raiz:** para orientar o corpo pela normal da superfície eu escrevi
`_char_model.global_basis = ...orthonormalized()`. Uma base ortonormalizada tem
escala **1** — e o modelo do jogador está em **0,4167**. Escrever a base repunha
a rotação e **jogava a escala fora**, deixando o personagem 2,4× maior.

Base carrega rotação E escala juntas; mexer numa sem repor a outra é perder a
outra.

**Evidência** (distância cabeça→pé, invariante à rotação):

```
com o bug:   antes 1,034  →  na parede 2,471   (2,4×)
corrigido:   antes 1,034  →  na parede 1,029
```

**Correção:** `_girar_modelo()` guarda `scale`, faz o slerp em bases
ortonormais e devolve `.scaled(escala)`.

**Como detectar de novo:** `medir_camera_e_parede.gd` mede o tamanho por
**distância entre ossos**, e a asserção reprova a versão com bug.

⚠️ **A primeira métrica que tentei estava errada:** o alcance em **Y do mundo**.
Ele CAI quando o corpo deita na parede — por ROTAÇÃO, não por tamanho — e a sonda
reprovava justamente o conserto. Tamanho se mede com grandeza invariante à
rotação.

---

## 2026-08-27 — a permanência na parede dependia da TECLA

**Sintoma (relatado pelo dono):** era preciso continuar segurando a tecla, quando
o pedido era um toque só.

**Causa raiz:** o estado sobrevivia consultando `_parede_frontal`, que vem de
`_normal_da_parede_escalavel(q.dir)` — **sem direção no teclado ela é ZERO**.
Soltar o W apagava a parede e o jogador caía. O fallback que eu pus "para
robustez" era exatamente o que reintroduzia a dependência que a mecânica veio
eliminar.

**Evidência:** com o W solto, `parede_frontal = (0,0,0)` e o estado caía.

**Correção:** só o que está **sob os pés** decide (um raio, que não olha para o
teclado). Mais alcance (2,0 m), origem do raio deslocada para fora da superfície
— raio que nasce dentro do sólido não reporta acerto — e uma **folga de 0,35 s**
antes de soltar, porque a superfície some por um quadro em quina ou degrau.

**Como detectar de novo:** a asserção "continua sem segurar tecla" agora observa
**180 quadros (≈3 s)**, não meia dúzia. Com poucos quadros ela passava mesmo com
o bug — o jogador só caía depois.

---

## 2026-08-27 — devolver a pose ao "zero" subiu o personagem 0,8 m

**Sintoma:** a cada dash para trás o personagem subia um pouco e ficava lá.

**Causa raiz:** o rolamento de costas move o modelo em Y/Z para girar em torno da
cintura, e no fim eu devolvia `position = 0`. Mas o repouso do modelo **não é
zero**: é **y = −0,80**, porque o rig o abaixa para os pés encostarem no chão.
Devolver a zero SUBIA o corpo 0,8 m.

**Evidência:**

```
repouso:        modelo y = −0,8000
após dash #1:   modelo y =  0,0000   ← subiu, e não voltou
após dash #2..5: 0,0000
```

Depois do conserto: −0,8000 antes e depois dos cinco dashes.

**Correção:** guardar a posição no primeiro quadro do giro e devolver a ELA.

**Como detectar de novo:** a asserção do `medir_dash.gd` comparava com ZERO e por
isso deixou o bug passar; agora compara com a pose de ANTES. **Repouso se guarda,
não se supõe** — é o mesmo erro da escala das raças, onde devolver `Vector3.ONE`
deformaria um rig que nasce com 1,8.

---

## 2026-08-27 — o anel do soco tinha rotação FIXA no mundo

**Sintoma (relatado pelo dono):** "o efeito visual que o clique libera aponta
sempre para a mesma direção".

**Causa raiz:** `Melee._impacto` fazia `m.rotation.x = PI * 0.5` — literalmente
uma rotação fixa. A POSIÇÃO do anel acompanhava o soco; a ORIENTAÇÃO, nunca.
Socar para o norte e para o sul desenhava o mesmo anel virado para o mesmo lado.
A função sequer RECEBIA a direção, embora quem a chamava (`Melee.golpear`) a
tivesse na mão.

**Evidência:** eixo do anel medido em 8 rumos — idêntico em todos antes, `+1,000`
contra a direção do golpe depois.

**Correção:** `_impacto` passou a receber `dir`, e o anel virou DUAS camadas: um
suporte que APONTA (`look_at`) e a malha girada −90° em X (o eixo de um
`TorusMesh` nasce em +Y e precisa virar −Z).

⚠️ **A primeira tentativa compôs uma `global_basis` e não sobreviveu ao tween:**
animar `scale` RECOMPÕE a base a partir de rotação + escala guardadas, e a
decomposição não voltava igual — o anel saía girado, com |dot| oscilando de 0,85
a 0,00 conforme o rumo. Separar apontar de girar resolve porque o tween passa a
mexer só na escala do suporte.

**Como detectar de novo:** `tools/dev_tests/medir_vfx_soco.gd`.

⚠️ **E três armadilhas de MEDIÇÃO, todas no mesmo teste:**
1. media o `−Z` do nó, mas o eixo de um toro é o `+Y` local — e com a rotação
   fixa antiga o `−Z` também apontava para cima, então a sonda dava o MESMO
   número no defeito e no conserto;
2. pegava os anéis dos BONECOS DE TREINO, que socam sozinhos: o resultado variava
   por rumo e não tinha relação nenhuma com o golpe medido — errado e
   convincente. Congelar os bonecos não basta; o que atrapalha é o anel que já
   estava a caminho;
3. o anel nasce com RETARDO, e com espera curta cada célula media o golpe
   ANTERIOR (atraso de exatamente um passo) — o mesmo defeito que a sonda das
   direções das skills já teve.

---

## 2026-08-27 — `SubViewport` sem `own_world_3d` compartilha o mundo da cena

**Sintoma:** o personagem da prévia do menu de Customização aparecia com a ARENA
inteira atrás dele.

**Causa raiz:** `SubViewport` nasce com `own_world_3d = false` e usa o mundo 3D da
cena que o contém. Tudo o que está na partida entra no quadro, e a luz que eu
adicionei ao viewport do menu ilumina o jogo.

**Evidência:** ligando `own_world_3d = true` o fundo passa a ser só a cor do
`Environment` do próprio viewport.

**Correção:** `_viewport.own_world_3d = true`, mais um `WorldEnvironment` e uma
`DirectionalLight3D` DENTRO do viewport — sem mundo próprio essas duas vazariam.

**Como detectar de novo:** prévia 3D em menu que mostra cenário do jogo, ou luz
que muda no jogo ao abrir um menu. A sonda confere o campo direto:
`_ok("o viewport tem mundo próprio", menu._viewport.own_world_3d)`.

---

## 2026-08-27 — enquadrar no `_ready` mede a hierarquia AINDA EM REPOUSO

**Sintoma:** a câmera da prévia nascia DENTRO do tronco do personagem; a tela
virava uma parede de cor lisa. Trocar os números da câmera não resolvia — só
mudava para outro lugar errado.

**Causa raiz:** o enquadramento é calculado da caixa do modelo, e a caixa vem de
`global_transform` de cada malha. O Godot **só propaga as transformações depois
que a árvore processa**. Calculando dentro do `_ready`, a hierarquia ainda está em
repouso e a união das AABBs sai errada.

**Evidência:** adiando um quadro, a caixa medida passou a ser
`pos (-0,9, 0, -0,36) tam (1,8, 3,6, 0,72)` — coerente com o modelo — e o
personagem apareceu inteiro no quadro.

**Descartado:** ajustar posição/FOV da câmera na mão (só troca um erro por
outro), e `force_update_transform` (resolve o sintoma sem explicar a ordem).

**Correção:** `await get_tree().process_frame` no `_ready` antes de enquadrar. E o
enquadramento é CALCULADO da caixa, não fixo — assim trocar de personagem ou
mudar a proporção do rig continua enquadrando.

**Como detectar de novo:** qualquer conta que use `global_transform` de nós
recém-adicionados. Se o resultado for absurdo mas o código parecer certo,
desconfie da ORDEM antes de desconfiar da conta.

---

## 2026-08-27 — ler DADO de uma classe pesada arrasta os autoloads dela

**Sintoma:** `SCRIPT ERROR: Compile Error: Identifier not found: FruitNet` ao rodar
a sonda do menu de Customização. Nada no menu fala de rede.

**Causa raiz:** o menu lia a paleta em `Player.CORES` — três cores. Referenciar
`Player` puxa o script inteiro (2.400 linhas) e, com ele, os AUTOLOADS de que
depende. O autoload `FruitNet` não existe ainda no momento em que uma sonda com
`-s` compila, e a compilação falha em cadeia.

**Evidência:** o erro não aparece em sondas anteriores nem no `master` sem as
mudanças — apareceu junto com o primeiro `Player.CORES` fora do `Player`.

**Correção:** a paleta saiu para `src/customizacao/Paleta.gd`, dado puro sem
dependência nenhuma. `Player.CORES` virou apelido (`const CORES := Paleta.CORES`),
então as dezenas de usos não mudaram e a fonte continua sendo uma só.

**Como detectar de novo:** erro de compilação citando um autoload em código que
não tem nada com o assunto dele. A pergunta certa não é "por que falta o
autoload", é **"por que esta tela depende da classe mais pesada do projeto para
ler dado?"** — dado deve morar em script que não depende de nada.

⚠️ E `--check-only --script <arquivo>` NÃO serve para diagnosticar isso: ele não
carrega autoloads, então acusa o mesmo erro em código que funciona. Para saber se
é real, use `tools/dev_tests/checar_compilacao.gd`, que roda no projeto completo.

---

## 2026-08-27 — o `:=` do GDScript não infere sobre Variant, e isso pegou 4 vezes

**Sintoma:** `Parse Error: Cannot infer the type of "X" variable because the value
doesn't have a set type.` O script inteiro deixa de carregar.

**Causa raiz:** iterar um `Array` ou `Dictionary` **não tipado** dá um `Variant`, e
qualquer método chamado nele devolve `Variant` — que o `:=` não consegue inferir.
Os quatro casos do mesmo dia:

```gdscript
for d in [Vector2i(6,0), ...]:      var vx := x + d.x            # ❌
for chave in dicionario:            var partes := chave.split("/")  # ❌
for x in _todos(no):                var pai := x.get_parent()     # ❌
```

Dois eram meus e dois de um agente — ou seja, não é distração de uma pessoa, é a
forma da linguagem.

**Evidência:** `medir_direcoes_skills.gd` (do agente) não carregava; três sondas
minhas quebraram na primeira execução com a mesma mensagem.

**Correção:** tipar a variável, ou o laço:

```gdscript
var passos: Array[Vector2i] = [...]      # laço tipado resolve na origem
var partes: PackedStringArray = String(chave).split("/")
var pai: Node = (x as Node).get_parent()
```

**Como detectar de novo:** o erro é de PARSE, então `--check-only` no arquivo já
denuncia — não precisa subir o jogo. Vale rodar antes de qualquer sonda nova:

```bash
godot --headless --path . --check-only --script res://tools/dev_tests/<sonda>.gd
```

**⚠️ E a armadilha vizinha, que custa mais caro:** pôr `await` numa função chamada
SEM `await` não dá erro nenhum — a função simplesmente ENCERRA ali, e o resto não
roda. Foi assim que uma sonda passou de 33 para 31 asserções em silêncio, e eu
quase tomei o placar menor por bom. Ver a entrada da conferência do rig no Blender:
teste que encolhe sozinho é primo do teste que compara o erro consigo mesmo.

---

## 2026-08-27 — as "discordâncias colisão↔visual" eram da SONDA, não do jogo

**Sintoma:** de 1.851 pontos de chão conferidos, 4 tinham o raio acertando a
`Plataforma` enquanto a tela mostrava o vazio. Parecia rasgo de renderização na
beirada dos buracos.

**Causa raiz:** duas falhas somadas, ambas da sonda `medir_blocos_sumindo.gd`.

**1. Limiar absoluto de cor.** O chão era pintado de verde puro e o teste exigia
`g > 0,35`. A névoa escurece o chão distante bem abaixo disso: a ~130 m o verde
puro chega como **(0,00 · 0,22 · 0,04)** — inconfundivelmente verde, e reprovado.
Isso acusava "o chão sumiu" na borda externa da plataforma, longe da câmera.

**2. Sem margem de silhueta.** Raio e rasterizador decidem coisas diferentes: o
raio acerta se a linha CRUZA o sólido; o pixel é pintado por COBERTURA, e na
quina a cobertura é parcial. Some a isso o `Contorno`, que pinta uma linha escura
**por cima** da silhueta — os últimos pixels da beirada da laje são contorno, não
chão. Discordar a milímetros da quina é o comportamento correto dos dois.

**Evidência:** os 3 casos que sobraram após corrigir (1) eram todos idênticos —
`y = −1,9946`, ou seja **5,4 mm** do canto de baixo (`PLATFORM_THICK = 2,0`), com
a mesma cor, sempre no rumo 100°. Consistência assim é geometria, não acaso. A
vizinhança fechou: no pixel discordante, **2 px para a esquerda** ou **4 px para
cima** já acham chão desenhado, e a cor lida é **(0,00 · 0,00 · 0,03)** — preto de
contorno.

**Descartado:** rasgo na face lateral da laje, culling da face, desencontro entre
a caixa de colisão e a instância do MultiMesh (as duas usam `Vector3(w,
PLATFORM_THICK, CELL)` na mesma origem — conferido no código).

**Correção:** `tools/dev_tests/medir_blocos_sumindo.gd` — detecção de chão por
**dominância de canal** em vez de limiar absoluto (não depende do brilho, logo
atravessa a névoa), mais uma **guarda de silhueta**: só conta como "sumiu" se
nenhum chão for desenhado num raio de 6 px. Nenhuma mudança no jogo.

**Como detectar de novo:** a sonda agora fecha em 1.851 pontos de chão e 3.880 de
bloco com **zero** discordâncias. Regra que fica: **sonda que compara raio com
pixel precisa de margem na silhueta** — sem ela, ela acusa a própria borda da
geometria. E **limiar absoluto de cor não sobrevive à névoa**; dominância, sim.


---

## 2026-08-27 — o chão escurecia em faixa porque o shader ESCREVIA `ALPHA`

**Sintoma:** o chão ganhava faixas escuras que mudavam ao girar a câmera. No mesmo
quadro, chão plano e mesma luz: metade esquerda 29,8% escurecida, direita 0,5%.

**Causa raiz:** `src/fx/shaders/cel.gdshader` fazia `ALPHA = cor.a;`. No Godot 4 a
transparência é decidida em tempo de **COMPILAÇÃO** — basta o shader **escrever**
em `ALPHA`, mesmo que o valor seja sempre 1,0, para o material inteiro ir para o
pipeline de transparência. Ali ele sai do prepass de profundidade e passa a ser
iluminado por outro caminho. `cor.a` era 1,0 nos **100 materiais** que usam o
shader (auditado em runtime): a transparência nunca foi usada, só o custo dela.

**Evidência:** bisseção, mesma cena/câmera/luz, linha de leitura validada por raio
(560 de 560 pixels acertam a `Plataforma`, zero blocos, zero céu):

| variante | esquerda |
|---|---|
| cel do jogo | 29,8% |
| mesmo `fragment()`, `light()` REMOVIDO | 29,8% |
| sem `light()` e sem grade | 29,8% |
| sem `render_mode` | 29,8% |
| **só sem a linha `ALPHA = cor.a;`** | **0,0%** |
| `StandardMaterial3D` (controle) | 0,5% |

Antes/depois em 96 casos (8 rumos × 3 posições × 2 alturas × 2 energias de sol):
rumo 90° 27,1%→0,7%; 135° 46,4%→1,1%; 225° 59,6%→1,8%. Nenhum caso piorou.

**Descartado (todos medidos, nenhum era):** cascata de sombra, grade do chão,
quantização do cel, contorno de tela, SSAO, névoa/perspectiva aérea, o `light()`
inteiro (removê-lo não muda nada) e o `render_mode`.

**Correção:** `src/fx/shaders/cel.gdshader` — a linha `ALPHA = cor.a;` removida.
Uma linha. Se algum dia precisar de superfície translúcida, faça uma VARIANTE do
shader; devolver a linha custa o chão inteiro.

**Como detectar de novo:** `tools/dev_tests/baseline_chao.gd` (esquerda deve ficar
abaixo de 5%) e `tools/dev_tests/checar_residuo_chao.gd`, que separa artefato de
sombra legítima. Regra geral: **no Godot 4 o que liga um caminho de renderização é
o shader ESCREVER no campo, não o valor escrito** — vale para `ALPHA`, `NORMAL`,
`AO` e afins.

---

## 2026-08-27 — minha métrica comparava metades da TELA sem conferir o que havia nelas

**Sintoma:** hipóteses eram "descartadas" uma após a outra sem que o número mudasse,
e o defeito parecia não ter causa. Também produziu a contradição *"trocar o material
resolve, mas parâmetro nenhum reproduz"*.

**Causa raiz (erro meu, de método):** eu media o escurecimento varrendo uma linha
de pixels e comparando a metade esquerda com a direita da TELA — **sem nunca
verificar se as duas metades mostram a mesma coisa**, e calculando a média sobre
pixels que incluíam os próprios escurecidos. Duas consequências:
1. bloco, céu e chão entravam na mesma conta;
2. **sombra de bloco legítima contava como defeito**, porque qualquer pixel abaixo
   de 92% da média era marcado.

Havia **duas causas sobrepostas** nos quadros medidos — o artefato de transparência
E sombra de verdade. Por isso nenhum toggle isolado zerava o número: cada um matava
só metade. Isso "inocentou" grade, SSAO e sombra cedo demais, e as três tiveram de
ser reabertas.

**Evidência:** com a métrica corrigida (cada pixel classificado por raio ANTES de
entrar na conta), a mesma cena mostra 560/560 pixels de `Plataforma` nas duas
metades — a comparação passou a valer. E desligando a sombra depois da correção,
os resíduos caem de 32%/40%/50% para 0,7%/0,8%/1,6%, provando que eram sombra.

**Correção:** `tools/dev_tests/baseline_chao.gd` classifica cada pixel por raio e
conta escurecimento só onde o pixel é mesmo o chão.

**Como detectar de novo:** antes de aceitar um veredito de "inocente", conferir se
a métrica olhava para o lugar certo. **Comparar número de um teste com número de
outro só vale se a métrica e a região forem as mesmas.** Corolário já pago duas
vezes: controle tem que ter o mesmo brilho do caso — testar com albedo branco não
prova nada, porque o branco satura no tonemap e esconde a variação.

---

## 2026-08-27 — eu diagnostiquei "o boneco desmonta" olhando pixel ampliado

**Sintoma:** vendo o vídeo do dono, afirmei que o personagem colapsava em
movimento — tronco tombado ~40°, pernas dobradas, cabeça sumida.

**Causa raiz (erro meu):** li "desmontado" num modelo voxel de poucos polígonos,
recortado e reescalado de um vídeo de 1316×736. Baixa resolução, pose inclinada e
um modelo sem cabeça destacada bastam para parecer quebrado. **Impressão sobre
pixel ampliado não é diagnóstico.**

**Evidência:** varrendo toda a faixa de mira do jogo (`_pitch` de +0,5 a −1,2),
parado e correndo: parado tronco 1,2°–2,6° e altura do rig 99,6%; correndo tronco
14,7° e altura 88,1%–88,4%, **sem variação por pitch**. A pose de corrida é uma
corrida agachada normal.

**Descartado no caminho:** os 4 clipes do combo M1 não têm faixa de rotação de
tronco (0,0° nos três eixos); `ProceduralAnimator.trigger_hitstop()` **nunca é
chamado** (o tremor é código morto); `balanco_torso` dá no máximo 6,9°; troca de
fruta, 2,7°.

**Correção:** nenhuma no código — não havia defeito. O alarme foi retirado.

**Como detectar de novo:** `medir_rig_por_pitch.gd`, `medir_corpo_encolhe.gd`,
`medir_tronco_combinado.gd`. Antes de afirmar que algo visual está quebrado,
medir a geometria — não descrever a imagem.

---

## 2026-08-26 — o portão visual do projeto nunca usou a câmera do jogo

**Sintoma:** defeitos visíveis em jogo (faixas ao girar a câmera) nunca apareciam
na bateria, que tem cinco cenas fixas justamente para isso.

**Causa raiz:** `tools/dev_tests/captura_visual.gd` **cria uma `Camera3D` própria**
e a posiciona na mão. Ele nunca passa pelo `CameraRig` (pivô → Ombro → SpringArm →
Camera3D), que é a câmera de verdade. Todo defeito que dependa da câmera do jogo
era invisível para a bateria **por construção** — e "olhar para trás" é exatamente
o que aquela sonda não sabe fazer.

**Evidência:** o defeito das faixas (29,8% de escurecimento) não aparece em
nenhuma das cinco cenas e aparece no primeiro rumo da sonda nova.

**Correção:** `tools/dev_tests/captura_giro.gd` — 8 rumos e 3 inclinações, pela
câmera do jogo, com entrada simulada por `InputEventKey` de verdade (o
`move_frame.gd` lê `Input.is_physical_key_pressed`, então tecla de mentira não
funciona).

**Como detectar de novo:** ao criar sonda visual, perguntar se ela passa pelo
mesmo caminho que o jogador vê. Sonda que monta o próprio caminho testa a si mesma.

---

## 2026-08-26 — "blocos invisíveis" não era descarte de renderização

**Sintoma:** o dono relatou blocos ficando invisíveis em jogo.

**Causa raiz:** nenhuma no culling — a explicação confortável estava errada. Culling
é o suspeito natural porque não gera erro nenhum: o objeto simplesmente não está lá.

**Evidência:** os 77 blocos pintados de vermelho puro; para cada um,
`unproject_position` + raio de oclusão + verificação de vermelho no pixel. **3.879
casos em 6 postos de observação, incluindo alturas de pulo (y = 8, 12 e 16): zero
sumidos.** Pintar de vermelho é o que tira a ambiguidade — bloco cinza contra chão
cinza é indistinguível por cor, e foi por isso que olhar capturas não decidia nada.

**Descartado:** culling por distância, por frustum e por altura de câmera.

**Correção:** nenhuma — não havia o defeito procurado. Achado lateral REAL, ainda
aberto: de 1.851 pontos de chão, **4** têm o raio acertando a `Plataforma` enquanto
a tela mostra o vazio; três deles em y ≈ −1,99, a face LATERAL da laje vista
através de um buraco.

**Como detectar de novo:** `tools/dev_tests/medir_blocos_sumindo.gd`.

