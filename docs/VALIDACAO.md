# Validação automática

```bash
./validar.sh              # tudo (~9 min)
./validar.sh rapido       # pula os lentos
./validar.sh camera rig   # só o que casar com esses nomes
```

Sai com código **0** só se tudo passou. Logs das falhas em `/tmp/validar_*.log`.

**Precisa de tela** para o traço de locomoção (`DISPLAY=:1 ./validar.sh`) — sem
ela esse teste é pulado, e os outros 15 rodam normalmente.

---

## O que a bateria cobre

| # | teste | o que prova |
|---|---|---|
| 1 | `test_compila` | todo `.gd` carrega e instancia |
| 2 | `test_arena` | 53 checagens do modo arena |
| 3 | `test_buki_buki` | 24 checagens do arsenal |
| 4 | `test_frutas` | as 9 frutas: 4 golpes cada, dano e vazamento (~330 s) |
| 5 | `test_camera` | 13 checagens do `CameraRig` |
| 6 | `test_player_rig` | 20 checagens do `PlayerRig` |
| 7 | `test_walk_run`, `test_rig_unico`, `test_anatomia_rig` | rig e caminhada |
| 8 | `test_elenco_trancado` | a trava de elenco resiste por todos os caminhos |
| 9 | `test_gomu_leak`, `test_gomu_burn_leak`, `test_sand`, `test_buggy` | vazamento de nós |
| 10 | `test_lan_discovery` | descoberta na LAN — **dois processos** |
| 11 | `traco_locomocao` | 492 quadros de física, contra referência |

---

## Três armadilhas que a bateria resolve

### 1. Todos disputam a porta 24565

Cada teste sobe um servidor local na mesma porta. Dois ao mesmo tempo: o
segundo não acha servidor, não spawna player e **trava até o timeout** — e o
sintoma parece falha do teste, não colisão. Por isso rodam **em série**.

### 2. Rodar só os que a gente lembra

A lista é descoberta do disco (`test_*.gd`), sem curadoria. Isso não é
preciosismo: durante as fases 1–4 eu vinha rodando 10 dos 15 e relatando "a
suíte passou". Os cinco que faltavam (`test_buggy`, `test_sand`,
`test_gomu_leak`, `test_gomu_burn_leak`, `test_lan_discovery`) nunca tinham sido
executados nessa sequência.

### 3. Timeout único não serve

`test_frutas` conjura 36 golpes e mede dano e vazamento em cada um: **330 s
medidos**. Com um teto genérico ele "falhava" por tempo enquanto passava em
tudo — o pior tipo de falso positivo, porque tira a confiança da bateria
inteira. Os tempos ficam em `tempo_de()`.

---

## O traço de locomoção — a única rede contra regressão de física

`tools/dev_tests/tracar_locomocao.gd` dirige o player com um **roteiro de teclas
fixo** e grava posição, velocidade e estado quadro a quadro. O resultado é
comparado com `tools/dev_tests/traco_esperado.txt`, que é commitado.

É o único teste que pega **"o personagem não anda"** ou **"atravessa parede"**.
Nenhum teste headless acusa isso.

**Cobertura:** andar, correr, salto longo, geppo, dash (21,4286 m/s medidos),
rolamento, queda, strafe, ré, parada, congelamento por combate, e parkour de
parede real (a parede é achada no mapa por varredura determinística).

### Por que precisa de janela

A locomoção só lê teclado com o mouse **capturado**, e não dá pra capturar mouse
sem servidor de vídeo. As teclas são falsificadas com
`Input.parse_input_event`, que alimenta o `Input.is_key_pressed`.

### Quando a referência muda de propósito

Se você mudar física de propósito (gravidade, velocidade, altura de pulo), o
traço **vai falhar** — é o trabalho dele. Confira o diff, confirme que a mudança
é a que você queria, e regrave:

```bash
DISPLAY=:1 godot --path . --script tools/dev_tests/tracar_locomocao.gd -- novo.txt
# confira o diff contra o antigo, e só então:
cp novo.txt tools/dev_tests/traco_esperado.txt
```

**Nunca regrave sem olhar o diff.** Regravar às cegas transforma a rede num
carimbo.

---

## Duas coisas que deixaram o traço mentir (e como foram resolvidas)

Ambas descobertas testando a rede contra bugs injetados de propósito — porque
uma bateria que nunca falhou não está provada.

### `Engine.time_scale` fazia a bateria ficar intermitente

O `GameFlow.hit_stop()` põe a escala de tempo em **0,06** no impacto de um
golpe, e a escala multiplica o **delta da física**. Quando uma bala acertava
algo no meio do traço, o mesmo pulo, no mesmo quadro, com a mesma velocidade
(16,0), andava **0,0161 em vez de 0,2667** — e a rodada divergia dali em diante.

Sintoma: o traço **passava sozinho e falhava na bateria completa**. O `_quadros`
agora força `time_scale = 1.0` a cada quadro. O traço mede física; tempo
cinematográfico é outro assunto.

### Segurar Espaço no chão dava ruído de float

Segurar a tecla faz o player pular e reencostar todo quadro; o contato com o
chão oscila e a trajetória vira ruído. Medido: **31 quadros diferentes entre
duas rodadas do mesmo código**. O roteiro usa **toque**, não tecla segurada.

---

## A sensibilidade da rede, medida

| bug injetado | pegou? |
|---|---|
| `GRAVITY` de 32,0 → 32,05 (0,15%) | ✅ já no quadro 1 |
| congelamento da rajada deixa de zerar o `sprint` | ✅ 50 quadros (pulo normal virava salto longo) |

O segundo caso é instrutivo: na **primeira** versão do roteiro ele **não** era
pego, porque o roteiro não apertava Espaço durante a rajada — e a condição do
salto longo é `q.sprint and q.f > 0.0`. Cobertura não é opinião: teste a rede
contra o bug que você teme.

---

## O que a bateria NÃO cobre

- **Rede com dois PCs de verdade.** As sondas `net_host_probe.gd` /
  `net_client_probe.gd` cobrem loopback headless e **não estão** na bateria —
  exigem dois terminais. As fases 5–7 da partição do Player vão precisar delas.
- **O que se vê na tela.** Mira dessincronizada, arma no lugar errado, animação
  feia. O traço prova a física, não o *feel*.
- **Áudio.**
