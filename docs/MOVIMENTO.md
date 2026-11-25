# Movimento — leitura, parkour, esquiva

Escrito em 2026-08-26 por leitura de código. Este sistema **nunca teve página**:
tudo o que está aqui vivia em cabeçalho de `.gd` e no meio de
`Player._etapa_locomocao`. O [`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md)
conta *por que* os três componentes foram extraídos; esta página conta **o que
eles fazem e com que números**.

Arquivos: `src/player/move_frame.gd`, `src/player/parkour_controller.gd`,
`src/player/dash_controller.gd`, e a etapa que os combina em
`Player.gd:1013-1135`.

---

## 1. A regra de ouro: ninguém escreve `velocity` a não ser a etapa

```
LER (MoveFrame)  →  DECIDIR (Parkour, Dash)  →  ESCREVER (Player._etapa_locomocao)
```

`ParkourController` e `DashController` **recebem** a velocidade e **devolvem** a
velocidade. Quem atribui é a etapa, e é por isso que a ordem de precedência mora
no `Player` e não dentro dos componentes: a ordem *é* a regra do jogo.

Foi assim que os **16 locais de quadro** do `_etapa_locomocao` viraram **7**
(`Player.gd:1011`). Enquanto `f`, `r`, `dir` e a borda do Espaço fossem locais
soltos, qualquer separação em três arquivos só trocaria acoplamento por
cerimônia — passar quatro valores de mão em mão. O `MoveFrame` é o pacote que
tornou a medição possível.

**Precedência de um quadro, na ordem exata em que ela roda:**

| ordem | quem | efeito |
|---|---|---|
| 1 | `q.ler()` | teclas + base da câmera (só yaw) |
| 2 | `q.congelar()` | rajada Z (Mera/Hie) e `knockdown`: para de andar, câmera segue girando |
| 3 | `_parkour.avaliar()` | pouso de precisão, sondagem de parede, recarga do geppo |
| 4 | `_dash.atualizar()` | mira, disparo, recarga, tempo restante |
| 5 | `q.travar_golpe()` | golpe em curso planta o corpo |
| 6 | `_parkour.assumiu()` | **exclusivo**: escalada / wall run mandam sozinhos, nem a gravidade roda |
| 7 | gravidade + `aplicar_pulos()` + dash + WASD | o ramo normal |

⚠️ **A ordem 4→5 é deliberada e frágil.** A esquiva lê `q.dir` para saber para
onde ir; travar o golpe **antes** dela tiraria a direção da esquiva. E a trava
vem **antes** de `aplicar_pulos` porque, invertido, o pulo viraria o cancelamento
grátis de todo golpe (`Player.gd:1066-1077`).

### As duas travas não são a mesma trava

| | `congelar()` | `travar_golpe()` | `lock_movement()` (casts) |
|---|---|---|---|
| zera `dir`/`sprint` | ✅ | ✅ | ✅ |
| zera o **Espaço** | ❌ | ✅ | ✅ |
| zera a gravidade | ❌ | ❌ | ✅ — fica boiando no ar |
| zera `dash_segurado` | ❌ | ❌ (de propósito) | — |

⚠️ **`travar_golpe()` não toca em `dash_segurado`, de propósito.** A esquiva é o
cancelamento *legítimo* do combo; quem decide se ela vale é o `dash_bloqueado` do
Player. Zerar a tecla ali dentro tiraria a decisão de quem é dono dela
(`move_frame.gd:98-101`).

⚠️ **Por que o golpe não usa `lock_movement()`, que já existe:** aquela trava é a
dos casts e zera a velocidade *inteira*, sem gravidade. Usá-la no corpo a corpo
faria quem clicasse no ar **boiar 1,5 s** (`Player.gd:1071-1076`).

---

## 2. `MoveFrame` — o que o jogador pediu neste quadro

Não decide nada, não escreve `velocity`, não toca na física.

**Duas correções que parecem detalhe e não são** (as duas saíram do bug de WASD,
relatado em `src/player/wasd_bug_report.md`):

- **`is_physical_key_pressed`, não `is_key_pressed`.** Em teclado AZERTY ou
  Dvorak a posição física WASD é outra tecla lógica — o jogador simplesmente não
  andava.
- **`menu_fechado` vem da HUD, não do `mouse_mode`.** No Wayland o
  `Input.mouse_mode` perde a sincronia com a janela ao trocar de cena (ao clicar
  em "Jogar Singleplayer"), e reporta "não capturado" até um novo clique — com
  todas as teclas de movimento **silenciadas**. O estado da UI é a fonte
  confiável; o `mouse_mode` é o fallback.

**A base da câmera é PURA (só yaw, sem pitch).** É o que faz o dash ser sempre
horizontal e olhar para cima não virar empuxo (`move_frame.gd:63-67`).

**A borda do Espaço (`espaco_agora`) mora aqui**, não no Player: detecção de
borda precisa lembrar o quadro anterior, e isso é assunto de quem lê a tecla.
Salto longo, vault e geppo só disparam na **batida** — segurar repetiria o
gatilho e viraria velocidade infinita.

⚠️ **A leitura acontece DENTRO da etapa, não antes dela.** Quando o
`_etapa_travamento` corta o quadro, `q.ler()` não roda, e a borda do Espaço **não
avança**. Ler mais cedo mudaria esse comportamento sem ninguém perceber
(`Player.gd:1014-1019`).

---

## 3. Parkour — os 8 movimentos, com os números

`max_geppo` é ajustável por fora (`Player.max_geppo`, hoje **1**).
`_forca_pulo = JUMP_VELOCITY = 16.0`, `_gravidade = GRAVITY = 32.0`,
`SPEED = 4.2` m/s (sprint ×1,5 = 6,3 m/s).

| # | movimento | como se pede | o que sai |
|---|---|---|---|
| 1 | **Vault** | correndo (Shift+W) contra obstáculo baixo — **automático**, sem tecla | `vel.y = 16 × 0,7 = 11,2` · janela de impulso **0,35 s** |
| 2 | **Salto longo** | Shift + **batida** do Espaço, no chão, andando à frente | `vel.y = 16 × 0,95 = 15,2` · janela **0,55 s** |
| 3 | **Wall run** (refeito 03/10/2026, `corrida_na_parede.gd`) | **Espaço** correndo (≥ 3,5 m/s) rente a parede lateral, a ≤ 60° dela, no chão ou no ar | gravidade **normal**, sustentada pela velocidade (72 % a partir de 4 m/s) · impulso de entrada 5 m/s · perde 1,8 m/s² · acaba < 2,5 m/s, 1,8 s, sem parede, no chão ou **Ctrl** · Espaço = salta para longe (`normal × 7` + `tangente × v × 0,85` + `13` para cima) · mesma parede só após 0,35 s |
| 4 | **Pouso de precisão** | Espaço **no ar** enquanto cai (`vel.y < 3`) | ao tocar o chão com pico de queda > **9 m/s**: rolamento de **0,4 s** + poeira + janela **0,28 s** — o embalo é **preservado** |
| 5 | **Geppo** (pulo duplo) | Espaço no ar, fora de escalada/wall run, cargas > 0 | com direção: `dir × vel × 1,35` + `16 × 0,95`; parado: `16 × 1,15` · shake 0,28 · anel de ar |
| 6 | **Escalada** (refeita 03/10/2026, `escalada.gd`) | no ar, indo de **frente** contra parede **escalável** — agarra sozinho | sobe/desce **2,2/2,8 m/s** (W/S), cola na parede a 1,0 m/s · Espaço salta para trás · Ctrl solta |
| 7 | **Travessia lateral** | A/D **durante** a escalada | **1,6 m/s**; para na quina da parede |
| 8 | **Subir a borda** (no lugar do mantle) | mãos chegam ao topo → **borda**; W sobe | sobe rente a 3,6 m/s até os pés passarem do topo, avança 0,9 m por cima — sem teleporte; sai andando a ~3 m/s |

**A "janela de impulso" (`_long_jump_t`) é um multiplicador de velocidade
horizontal de ×1,5**, e é o único ponto onde o parkour mexe na velocidade dos
outros — e ainda assim ele devolve o **fator**, não a velocidade
(`bonus_velocidade()`). Cinco dos oito movimentos a armam. Correndo com ela
aberta o jogador faz `4,2 × 1,5 (sprint) × 1,5 (janela) = 9,45 m/s`.

**Recarga do geppo:** as cargas voltam ao **tocar o chão, escalar ou correr na
parede** — não só no chão. Wall run é apoio.

⚠️ **Geppo e pouso de precisão disputam a MESMA tecla, e a ordem resolve.**
`avaliar()` roda primeiro e arma o pouso; `aplicar_pulos()` roda depois e, se
houver carga de geppo, gasta a carga **e desarma o pouso**
(`parkour_controller.gd:158-160`). Com `max_geppo = 1` isso significa: o
**primeiro** Espaço no ar é geppo, o **segundo** arma o rolamento de pouso. Não é
acidente — é a linha `_pouso_armado = false` dentro do geppo. Quem for mexer em
`max_geppo` muda também quantos apertos custam até o pouso de precisão ficar
disponível.

### As quatro sondas de cenário

Vieram do Player junto com o parkour porque só existiam para ele.

| sonda | como decide | raio/alcance |
|---|---|---|
| `_normal_da_parede_escalavel` | lê as **colisões do último movimento** (`get_slide_collision`), sem RayCast extra | `abs(normal.y) ≤ 0,2` e `dir · normal < −0,15` |
| `_normal_da_parede_lateral` | dois raios horizontais perpendiculares | 0,85 m · aceita `abs(n.y) < 0,3` |
| `_cabeca_livre_da_parede` | raio na **altura da cabeça** (+0,95 m) em direção à parede; vazio = dá para subir | 0,9 m |
| `_obstaculo_baixo_a_frente` | **dois** raios: bate no joelho (−0,4 m) **e** livre acima (+0,7 m) | 1,2 m cada |

⚠️ **A escalada usar as colisões do movimento em vez de um `RayCast3D` é
decisão, não preguiça:** é o que a faz funcionar em qualquer `StaticBody3D`,
inclusive nos 90 blocos cinza do mapa, sem ninguém precisar registrar nada
(`parkour_controller.gd:182-183`).

---

## 4. Esquiva (Q) — ROLL desde 03/10/2026

> Pedido do dono (03/10/2026): "roll passando a ser a tecla Q, eliminando o dash".
> Decisão: o roll **herda o papel de esquiva** do dash (mesma recarga, mesma janela de
> invulnerabilidade, mesmo cancelamento de golpe que acertou) e é um rolamento que se
> vê, com o clipe Mixamo "Sprinting Forward Roll". O controlador continua se chamando
> `DashController` para não quebrar quem o consulta. O que vem abaixo desta tabela
> sobre o dash de 12 m é histórico.

**Apertar Q dispara** (não há mais segurar para mirar). A direção é travada no
disparo; o corpo vira para ela e rola para a frente do próprio rumo.

| | |
|---|---|
| distância | **8 m** (era 4,5 m até o fim da tarde de 03/10/2026 — o dono pediu mais) |
| tempo | **0,65 s** (⇒ 12,3 m/s) |
| efeito e som | **nenhum** — o anel de choque e o som do dash antigo saíram (pedido do dono, 03/10/2026); o roll se lê pelo clipe |
| recarga | **1,5 s** |
| gravidade | **suspensa** — o vetor inteiro é sobrescrito, `y` incluído |
| direção | WASD; sem tecla, a frente da câmera (as duas sem pitch) |
| imunidade | `damage_immune` nos primeiros **0,28 s** (a janela do dash antigo) |
| animação | clipe de ação `sprinting_forward_roll` 0,05→1,1 s, dirigido pelo progresso do roll |
| capacidade | SEMPRE liberado (decisão do dono, 03/10/2026: "liberar o uso do Q"); o desbloqueio "dash" da progressão segue no save, mas não trava o Q |
| teste | `tools/dev_tests/test_roll_deslize.gd` |

### Agachar (Ctrl) — 20/10/2026

Substitui o deslize no Ctrl por pedido do dono. Segurar para agachar; soltar
para levantar quando houver espaço. Implementação: `src/player/agachar.gd`;
pose editável: `src/anim/pose_agachar.gd`.

- Velocidade: 30% da caminhada (1,26 m/s no personagem base), sem sprint ou
  ganho diagonal. A colisão passa a 1,5/1,8 da altura, mantendo os pés e a largura.
- Câmera: desce 0,35/1,8 da altura do corpo, suavizada; vale em 1ª e 3ª pessoa.
- Bordas: testa apoio em X, Z e diagonal antes de mover; tolera desníveis de
  até meio bloco na escala do corpo. Pulo e empurrão continuam podendo derrubar.
- Teto: consulta o volume de pé, não apenas raios. Soltar sob teto conserva a
  postura e a lentidão até sair. Q só cancela a postura se couber de pé.
- Ctrl mantém descer na água e soltar parede. Agachado não inicia parkour.
- Pose/corpo replicados por `net_agachado`; respawn restaura postura e colisão.
- Toque: manter o botão AGACHAR. Sem custo de energia ou recarga.

Referência de altura: [notas oficiais Minecraft 1.20.10](https://www.minecraft.net/en-us/article/1-20-10-update-available-bedrock).
A proporção foi adaptada ao corpo de 1,6 m e à cápsula do jogo; não muda escala
horizontal nem o salto do projeto. Teste: `tools/dev_tests/test_agachar.gd`.

### Deslize antigo — histórico de 03/10/2026 (Ctrl substituído em 20/10)

Pedido do dono: deslizar no Ctrl "somado à necessidade da velocidade de estar em
movimento"; decisão: passa **por baixo** de obstáculos baixos. `src/player/deslize.gd`.

| | |
|---|---|
| entrada | Ctrl no chão, correndo a ≥ 3,5 m/s, fora da parede, do roll e da água |
| embalo | entra na velocidade da corrida e GANHA até +10 % ao longo de 0,75 s — nunca perde (decisão do dono, 03/10/2026) |
| corpo | colisão e hurtbox pela METADE (centro desce ¼; a cápsula encolhe o raio junto) |
| teto | só levanta com espaço em cima (5 raios do centro ao topo inteiro, sem a camada da hurtbox); preso, continua deslizando |
| levantar | 0,3 s mantendo o embalo; a corrida retoma dele |
| Espaço | pula com o embalo (se o teto deixar) |
| animação | clipe de ação `running_slide` (desce 0,07→0,39, desliza até 0,85, levanta 0,85→1,44) |
| toque | botão "DESLIZA" na fileira de ações |
| som | pitch sorteado em ±6% para dois dashes seguidos não soarem colados |

⚠️ **`_passo` existe por causa de aritmética de ponto flutuante.** `_t` não zera
exato (1/60 não tem representação binária finita), então sem encurtar o último
quadro o dash anda **um quadro a mais** e percorre ~4% além da distância pedida.
O fator `_passo/delta` vale 1,0 em todos os quadros menos o último
(`dash_controller.gd:85-99`).

⚠️ **O dash não tem RPC.** Quem não é a autoridade nem chega a rodar
`atualizar()` — o som e o anel de choque são **locais**. Dar som ao dash alheio é
trabalho de *replicar* o dash, não deste ponto (`dash_controller.gd:76-80`).

**O que transborda para fora são dois PEDIDOS, não escritas:**
`_dono.pedir_rolamento(TEMPO)` e a meta `damage_immune`. O rolamento era um campo
com **dois donos** (o dash e o pouso de precisão); virou pedido, e o maior vence
— pousar em cima de um dash não deve encurtar a animação
(`Player.pedir_rolamento`).

### Dash-cancel

O dash cancela o combo **só na recuperação**, e **só se o golpe conectou**. Antes
valia em "Attacking" inteiro, o que incluía o startup: dava para apertar, ver que
ia acertar e sumir **antes de a hitbox nascer**.

⚠️ *Esta regra vive na FSM (`src/player/hsm/`), que está em obra em 2026-08-26.
Confira o estado real antes de confiar nesta linha.*

---

## 5. Armadilhas

- ⚠️ **`src/player/move_frame.gd:70` tem um `print()` por quadro de física** —
  ~60 linhas por segundo por jogador no console. É resto de depuração do bug de
  WASD. Registrado como item **46** em [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md).
- ⚠️ **Com parede ao lado, o Espaço é dela**: `avaliar()` tenta o wall run ANTES
  do pulo e do geppo. Correndo rente a uma parede, Espaço não pula — entra na
  parede. Quem for depurar "apertei pulo e grudei" procura aqui.
- ⚠️ **Buffer e coyote do wall run (03/10/2026)**: o Espaço vale por 0,15 s para
  ENTRAR na parede se não virou pulo/geppo (no ar sem geppo, ele arma o pouso de
  precisão E fica no buffer); e, se a parede acabou sozinha no ar, o Espaço nos
  0,15 s seguintes ainda dá o SALTO da parede (`CorridaNaParede.salto_coyote`),
  entregue por `aplicar_pulos` no lugar do pulo.
- ⚠️ **O vault é automático.** Não há tecla; correr contra um obstáculo baixo
  basta. Quem for depurar "pulei sem apertar nada" procura aqui.
- ⚠️ **A frente do modelo muda de dono conforme o estado**
  (`Player.gd:1113-1133`): escalando vira **para dentro** da parede (rigidez 24),
  em dash/investida vira para a direção do movimento (rigidez 35), parado
  acompanha o yaw da câmera (24). Quatro `lerp_angle` com rigidezes diferentes —
  mexer num sem os outros produz o "personagem que gira no tempo errado".
- ⚠️ **Convenção global: FRENTE = −Z.** Por isso `atan2(-dir.x, -dir.z)` no
  movimento e `atan2(wn.x, wn.z)` na escalada (o sinal inverte porque a normal
  aponta *da* parede *para* o jogador).

---

## 6. O que NÃO existe

- **Nenhum dos oito movimentos tem animação dedicada.** A mecânica está pronta;
  a animação procedural específica não. O `SkeletalAnimator.update()` recebe só
  `velocity`, `is_on_floor()` e `escalando` — wall run, mantle, vault e travessia
  lateral lêem todos como "no ar".
- **O parkour atravessa a rede como APRESENTAÇÃO (03/10/2026).** `net_parkour`
  (token de pose), `net_escalando`, `net_parede_lado`, `net_subida` e
  `net_inclinacao` vão no `MultiplayerSynchronizer` (`Main._make_player_sync`); a
  cópia remota inclina o corpo no wall run, mostra escada/borda/subida e a
  inclinação de curva. A física continua só de quem tem autoridade; não há RPC de
  parkour. Teste: `test_parkour_rede.gd`.

---

## Correr = 1,5× andar (2026-10-03)

Decisão do dono: "retirar o ganho de velocidade ao correr; correr passa a ser apenas 1,5
vezes a velocidade de andar". Saiu o `RunAccelerationController` (a corrida crescia até 2×
em 3 s no chão). O buff de aceleração da Rocket (V, ×1,6) passou para a arrancada da
locomoção (`LocomocaoChao.fator_aceleracao`): chega à velocidade mais depressa.

## Corrida do Mixamo (2026-10-03)

Pedido do dono: "tira a animação de correr do Naruto e coloca uma animação da Mixamo".
Correndo, os clipes `running`/`sprint` tomam o corpo (`ProceduralAnimator._aplicar_corrida`):
peso pela velocidade (entra de 1,8 a 3,0 m/s; sprint de 4,9 a 6,0), fase COMPARTILHADA
(os dois começam com o pé esquerdo à frente), mistura por QUATÉRNIO (o euler gravado passa
de ±π perto de 90°). A fase anda com a distância, pela passada que o clipe produz NESTE rig
(`_passada_no_rig`), com teto de cadência 5,0/7,5 passos/s (os da marcha procedural) (o `base` tem perna curta e
precisaria de 9). Por cima: inclinação de curva e de arrancada/frenagem, giro do quadril
(`Corpo:giro`), quadril baixando (`Corpo:altura`) e olhar nivelado (±6°). A silhueta
Naruto saiu; a marcha procedural (arrancada lenta, galope Mink, quem não tem clipe) balança
os braços também no sprint. Testes: `test_corrida_mixamo.gd` (clipe, por geometria) e
`test_walk_run.gd` (procedural, com o clipe desligado).

## Locomoção no chão e a FRENTE de novo (2026-10-02) — substitui a regra abaixo fora do combate

Pedido do dono (reformulação estilo Mirror's Edge Catalyst, `docs/PARKOUR_MIRRORS_EDGE_PLANO.md`):

- **A frente** segue o **movimento** correndo livre e vira para a **mira** atacando,
  usando skill, mirando arma, voando pilotado ou com golpe contextual — e fica na mira
  por `Player.COMBATE_SEGURA` (0,8 s) depois disso (`_atualizar_combate`). A regra de
  27/08 abaixo continua valendo DENTRO do combate (sonda `medir_facing.gd`, 8/8).
- **Locomoção no chão** (`src/player/locomocao_chao.gd`, recebe e devolve a velocidade):
  arrancada com o 1º passo mais forte (17 → 8 m/s²; 95 % da corrida em 0,33 s),
  frenagem 15 m/s² (para em 0,55 m da corrida), derrapagem acima de 5,6 m/s, giro
  (pedir mais de 130° da velocidade acima de 2,2 m/s: freia a 28 m/s², vira em 0,14 s e
  arranca — 0,35 s até 90 % da corrida na direção nova; o estado muda no MESMO quadro
  do comando), curva com rumo limitado (16 → 6,5 rad/s) e inclinação tg θ = v·ω/g
  (13,6° correndo, 17,7° no sprint), visual só (`ProceduralAnimator.loco_*`). No ar o
  embalo se preserva (controle 9 m/s², sem frear); combate e impulso de salto longo usam
  aceleração firme em vetor (30 m/s²), sem giro. Na água, o controle antigo.
- Medido em `tools/dev_tests/test_locomocao_chao.gd` (15 checagens, teclas reais).

## A FRENTE do personagem segue a MIRA (2026-08-27)

Decisão do dono. Antes a frente seguia o **movimento**: andar para o lado virava
o corpo para o lado, e a mira só mandava com o jogador parado.

**Por que mudou.** O golpe SEMPRE saiu pelo `_yaw` — `melee_controller` posiciona
a hitbox por ele, e as skills também. Era o corpo que discordava do golpe. Na
prática, o adversário lia a direção errada: via as costas de quem ia acertá-lo
de lado.

Medido com a sabotagem (o comportamento antigo reposto de propósito), o produto
escalar entre a frente do corpo e a direção da mira:

```
andando de ré      −1,000   ← o corpo apontava EXATAMENTE ao contrário
andando de lado     0,000   ← 90° fora
diagonal            0,707
```

Hoje, em 8 rumos × 6 direções de caminhada: **+1,000 nas 48**.

### A exceção, e por que não é negociável

**Escalando**, a frente vira para DENTRO da parede. É isso que faz a escalada
ler — um personagem grudado numa parede de costas para ela seria pior que o
problema original. Ali o corpo está preso à geometria, e a mira não manda.

### E dois números viraram um

Havia `35.0` para o caso em movimento e `24.0` para o parado — dois valores para
a mesma coisa. Agora é `Player.VELOCIDADE_FACING = 26.0`, alto o bastante para
não haver atraso perceptível entre girar o mouse e o golpe sair na direção nova,
baixo o bastante para o giro não ser corte seco.

**Sonda:** `tools/dev_tests/medir_facing.gd`. Ela sabe reprovar: com o
comportamento antigo, 0 passam e 8 falham.

---

## Dash: os quatro rumos e o rolamento de costas (2026-08-27) — SUBSTITUÍDO pelo roll em 03/10/2026

Pedido do dono: dash lateral e dash para trás, com **rolamento** no de trás.

### ⚠️ O dash já ia para os quatro lados

A direção sempre veio da tecla (`q.dir`), não da frente do corpo. O que **não**
existia era a leitura: os quatro usavam a MESMA pose, e na tela dar um passo para
trás e mergulhar para a frente ficavam iguais.

Por isso a mudança é de **animação e classificação**, não de física — distância
(12 m), tempo (0,28 s) e recarga (1,5 s) seguem iguais.

### Como o rumo é decidido

`DashController._classificar` compara a direção com a FRENTE e a DIREITA do
corpo, ambas vindas da base canônica (`RosaDosVentos.base_do_corpo`) — a mesma da
mira e da hitbox.

⚠️ **Frente e trás decidem primeiro**, com cone de 60° (`|para_frente| > 0,5`).
Uma diagonal como W+D é dash para a frente inclinado, não lateral: tratá-la como
lateral faria a esquiva mais comum do jogo escolher a pose errada.

### As poses

| rumo | pose |
|---|---|
| frente | o rolamento de mergulho que já existia |
| **trás** | **rolamento de costas: tronco arqueia para trás, queixo sobe, braços acima da cabeça — e o corpo GIRA uma volta inteira** |
| lados | mergulho lateral: tronco tomba no eixo Z, braço de fora aberto |

O rolamento de costas é a imagem **espelhada** do de frente, não uma variação:
reaproveitar a pose de frente trocando o sinal de um osso daria um agachamento
estranho, não um rolamento.

### O giro mora no Player, não no animador

Quem tem a raiz do modelo é o `Player`. A pose encolhida **sozinha** pareceria um
agachamento; é o giro que faz virar cambalhota.

E ele compensa a POSIÇÃO: a origem do modelo está nos **pés**, então girar ali
jogaria o corpo através do chão. Deslocando por `meia_altura·(1−cos)` em Y e
`meia_altura·sin` em Z, o giro acontece em torno da **cintura** — que é onde uma
cambalhota gira de verdade.

⚠️ E ele **volta ao repouso** quando a esquiva acaba. `rotation.x` não é escrito
por mais ninguém: sem essa linha o personagem ficaria de cabeça para baixo para
sempre, e ninguém o consertaria.

**Sonda:** `tools/dev_tests/medir_dash.gd` — 16 conferências. Mede as duas coisas
separadas: para onde o corpo SE MOVE (já funcionava) e qual POSE toca (o que
mudou). E confere a volta completa do giro: rolamento é giro, não encolhimento —
sem isso uma pose agachada passaria por rolamento.

---

## Andar na superfície — no lugar da escalada (2026-08-27) — REMOVIDO em 03/10/2026

> ⚠️ **Histórico.** O dono decidiu em 02/10/2026 remover a mecânica de vez, junto
> com a energia de parede e a cambalhota de saída (fatia 2 de
> [`PARKOUR_MIRRORS_EDGE_PLANO.md`](PARKOUR_MIRRORS_EDGE_PLANO.md)). O wall run novo
> mantém a parede como parede e a gravidade normal. O texto abaixo fica pelo que
> ensina sobre bases degeneradas e histerese.

Pedido do dono, inspirado em Naruto: onde o jogador escalaria, ele passa a
**andar** sobre o objeto, gastando energia; cancela **pulando**; e não precisa
segurar tecla.

### A diferença não é cosmética

| | escalada (antiga) | andar na superfície |
|---|---|---|
| estado | **segurado** — soltar o espaço larga a parede | **ligado** — entra uma vez e fica |
| movimento | sobe/desce colado | anda no PLANO da superfície, com WASD |
| orientação | corpo vira **para dentro** da parede | o "para cima" do corpo vira a **normal** da superfície |
| saída | soltar a tecla | **pular** |
| custo | nenhum | energia por segundo |

O preço existe para a mecânica ser um **recurso**, não um modo de locomoção
grátis: sem ele, andar na parede seria estritamente melhor que andar no chão e o
chão deixaria de ser uma decisão.

### Como se usa

**Dois toques de espaço**, e isso não é limitação: no chão o espaço é **pulo**. O
primeiro toque tira o jogador do chão; o segundo, já no ar e contra a superfície,
é o que gruda. Grudar direto do chão exigiria roubar a tecla mais usada do jogo.

Depois, **nada precisa ser segurado**. WASD anda pela superfície, e a normal do
que está sob os pés é reavaliada a cada quadro — é isso que deixa passar de uma
face para outra sem soltar.

### Quatro coisas que quebraram no caminho

**1. A energia não saía.** O custo estava num `elif` no bloco do dash — mas andar
na superfície entra por `_parkour.assumiu()`, a mesma porta da escalada, então
aquele ramo **nunca rodava** e a mecânica ficava de graça. Agora é cobrado num
ponto só, que roda todo quadro.

**2. O corpo grudava em pé.** A frente do modelo é projetada no plano da
superfície — mas ao grudar o corpo está ENCARANDO a parede, e essa projeção dá
**zero**. Sem uma saída para o caso degenerado a orientação nunca mudava. A saída
é "para cima da parede": a vertical do mundo projetada no plano.

**3. Outros escritores de facing desfaziam tudo.** `aplicar_mira` e mais dois
pontos escrevem `_char_model.rotation.y` todo quadro; escrever yaw numa base
inclinada mata a inclinação. Os três agora respeitam o estado.

**4. Sair não desentortava.** Largar a parede não bastava: como o resto escreve
só `rotation.y`, o personagem saía andando de lado no ar **para sempre**. Agora a
base volta inteira para "em pé olhando para a mira", e só então os escritores de
yaw voltam a mandar.

---

## Câmera: afastamento em degraus, no lugar dos efeitos de tela

Os quatro efeitos de velocidade **saíram**: borrão radial, linhas de velocidade,
aberração cromática e vinheta. As linhas misturavam a imagem com **branco puro**
(`mix(col, vec3(1.0), ...)`) — era o "esbranquiçamento" relatado; as outras três
distorciam.

Num jogo de luta, sujar a tela justamente quando o jogador se move é **cobrar
visão pelo movimento**. O retorno passou a ser a distância da câmera:

```
parado 6,01 | andando 6,89 | correndo 8,28 | parou de novo 6,10
```

**Degrau, não rampa.** A rampa proporcional que existia dava ~0,4 m andando e a
informação se perdia. E a **volta é mais rápida que a ida**: parar é uma decisão
do jogador e a câmera tem de obedecer na hora; sair andando é gradual.

As funções do `ScreenFX` continuam existindo — o flash de impacto e a visão do E
usam a mesma camada. O que saiu foi **alimentá-las pela velocidade**.

**Sonda:** `tools/dev_tests/medir_camera_e_parede.gd` — 10 conferências.
