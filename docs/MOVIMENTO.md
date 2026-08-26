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
| 3 | **Wall run** | no ar, sprint, W, rente a parede lateral, com `vel.y < 5` | gravidade a **12%** (piso −1,5 m/s) · corre na tangente · Espaço = pula para longe (`normal × 9` + `16 × 0,85`), janela **0,3 s** |
| 4 | **Pouso de precisão** | Espaço **no ar** enquanto cai (`vel.y < 3`) | ao tocar o chão com pico de queda > **9 m/s**: rolamento de **0,4 s** + poeira + janela **0,28 s** — o embalo é **preservado** |
| 5 | **Geppo** (pulo duplo) | Espaço no ar, fora de escalada/wall run, cargas > 0 | com direção: `dir × vel × 1,35` + `16 × 0,95`; parado: `16 × 1,15` · shake 0,28 · anel de ar |
| 6 | **Escalada** | no ar, Espaço **segurado** + W contra parede vertical | sobe/desce a **4,5 m/s** (W/S), cola na parede a 1,0 m/s |
| 7 | **Travessia lateral** | A/D **durante** a escalada | `4,5 × 0,8 = 3,6 m/s` na tangente |
| 8 | **Mantle** | W durante a escalada, com a **cabeça já livre** acima da beirada | `−normal × 6` + `16 × 0,8` para cima, larga a parede, janela **0,25 s** |

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

## 4. Esquiva (Q) — 12 metros em 0,28 s

**Segurar Q mira; soltar dispara.** A direção é travada no disparo — girar a
câmera no meio do dash **não o curva**.

| | |
|---|---|
| distância | **12,0 m** |
| tempo | **0,28 s** (⇒ 42,86 m/s) |
| recarga | **1,5 s** |
| gravidade | **suspensa** — o vetor inteiro é sobrescrito, `y` incluído |
| direção | tecla segurada; sem tecla, a frente da câmera (as duas já sem pitch) |
| imunidade | `damage_immune` ligado no disparo, desligado quando `_t` zera |
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
- ⚠️ **Wall run e escalada são exclusivos entre si**: `_parede_lateral` só é
  sondada quando `_escalando` é falso. Não existe "escalar correndo".
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
- **Nada do parkour atravessa a rede.** Não há RPC de escalada, wall run ou
  geppo; o adversário vê o resultado pela posição replicada, não pelo estado.
