# Pika Pika no Mi — luz

**Id:** `pika_pika` · **Tipo:** Logia · **Passiva declarada:** Fóton Reativo
(Light Dash) — **só `speed_mod 1,25` e `jump_mod 1,15` estão implementados.** O
"próximo dash vira um feixe instantâneo com +35% de dano" da descrição **não
existe no código**; é texto de vitrine, como nas outras Logias (ver o
[README da pasta](README.md)).

> ⚠️ **É a fruta inicial do jogo** (`Player.FRUTA_INICIAL`, [Player.gd:94](../../Player.gd#L94),
> desde 2026-09-04). Todo jogador que entra numa partida começa com ela, então
> defeito aqui é defeito que todo mundo vê no primeiro minuto.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/PikaFX.gd` | despacho dos 4 slots, o **Z** (`_yasakani`) e o **X** (`_yata`, classe `_ViagemDeLuz`) |
| `src/effects/PikaFXGrande.gd` | o **C** (`YasakaniController`) e o **V** (`ChuvaDeLuzController`) |
| `src/effects/PikaLightImpact.gd` | o clarão de impacto compartilhado por C e V |
| `src/effects/PikaAudio.gd` | a voz da fruta (10 cues) |
| `tools/generate_pika_audio.py` | gera os `.wav` — **fonte canônica do som** |
| `src/anim/PikaPoses.gd` | poses autorais do C (dois braços) e do V (um braço) |
| `src/player/cast_controller.gd` | o portão de **sustentação do C** (nasce no press, morre no release) |
| `src/combat/Balance.gd` | **todo o dano** dos quatro slots |

Despacho por **variante** em `PikaFX.cast`: `0 = Z`, `1 = X`, `2 = C`, `3 = V`.

---

## O que cada tecla faz, hoje

| tecla | golpe | tabela | recarga | o que acontece |
|---|---|---|---|---|
| **Z** | Salva de Luz (Yasakani no Magatama) | MULTI **7 × 14** = 98 | 5 s | sete raios em leque de 9,7°, 78 m/s, alcance 40 m |
| **X** | Yata no Kagami | ÚNICO **160** · teto 256 | 7 s | o corpo VIRA luz e viaja em ziguezague (esq→dir→esq, 21 m); se achar alguém no caminho, mergulha e explode |
| **C** | Yasakani no Magatama (barragem) | MULTI **8 × 48** · teto **384** | 10 s | teleporta 7 m para cima, trava a mira no mais próximo e sustenta 1,5 s de barragem **em área** (ver abaixo) enquanto a tecla estiver segurada |
| **V** | Chuva de Luz | MULTI **32 × 24** · teto **768** | 60 s | o céu vira dourado e chove luz sobre a arena por 12 s |

Os números saem de `src/combat/Balance.gd` e são **finais**. O `teto` do C e do
V é o que impede a densidade visual de virar dano: dezenas de fragmentos na tela
compartilham um `DamageSpec` só.

Referência autoritativa do C e do V (spec do dono, 2026-09-04):
[`docs/references/pika_pika/IMPLEMENTACAO.md`](../references/pika_pika/IMPLEMENTACAO.md).

---

## O C é ÁREA, não pontaria (2026-09-06)

Mudança pedida pelo dono: *"se o inimigo estiver na área de efeito do ataque ele
obrigatoriamente recebe o dano e fica paralisado, ao invés de ter que ficar
acertando ataque por ataque"*.

**O sintoma era real e a causa é aritmética.** Cada fragmento tinha 0,16 m de
raio e voava a 92 m/s; o leque espalhava 90 deles por 52 m de frente; e o alvo
precisava estar no caminho de **um em particular**. A barragem parecia cobrir
tudo e cobria quase nada.

### A forma

Uma **pirâmide** (`ConvexPolygonShape3D`, 5 pontos): o ápice no peito do caster
e os quatro cantos do leque a `C_ALCANCE`. A convexa liga todos os pontos entre
si — é o "todos os pontos se interligam" do pedido, literalmente.

Os cantos saem de `_cantos()`, que lê `C_ABERTURA_H` (0,72) e `C_ABERTURA_V`
(0,26) — **as mesmas constantes que `_direcao()` usa para espalhar os
fragmentos**. Elas eram literais soltos dentro do `_direcao()` e viraram
constantes justamente por isso: a hitbox é o envelope exato do visual por
construção, e não pode divergir sem que alguém mude os dois números.

### ⚠️ As dimensões, medidas

| | valor |
|---|---|
| largura na boca | **52,6 m** |
| altura na boca | 19,0 m |
| alcance frontal | 36,5 m |
| *(referência)* diâmetro da arena | 88 m |

É uma área **enorme** — e é exatamente a área que os fragmentos sempre
cobriram; o que mudou foi ela passar a valer. Se ficar demais, os botões são
`C_ABERTURA_H` e `C_ALCANCE`.

> 🔴 **A hitbox está desenhada em vermelho transparente na tela**
> (`C_MOSTRAR_HITBOX = true`), a pedido do dono, para conferência. Vire a
> constante para `false` quando não for mais preciso ver — nada além do desenho
> depende dela.

### Dano e paralisia

A zona **tica** na mesma cadência dos pulsos de fragmento (`C_POR_PULSO` acertos
a cada `C_TIQUE` = 0,05 s), então os 8 × 48 da tabela continuam valendo e o
**teto de 384 da conjuração** é o que limita o total. Medido no teste: quem é
preso a barragem inteira leva exatamente 384, nem um a mais; quem passa um
instante leva proporcionalmente menos.

Quem está dentro é **paralisado** (`RecepcaoDeDano.paralisar_com_animacao`,
renovada a cada 0,20 s e solta ao fim da barragem). O knockback é **zero de
propósito** — mesmo raciocínio já escrito no El Thor da Goro Goro: empurrar
espalha o alvo para fora da área antes de o golpe terminar, e o golpe se sabota.

**Consequências que o dono deve pesar:**

- Nesta arena quem mata é o buraco, e knockback é o que empurra para lá. O C
  deixa de ser golpe de queda e vira **dano + controle**.
- A paralisia usa o status `CONGELADO`, que é o caminho compartilhado de
  paralisia do projeto (o El Thor faz igual) — mas o HUD vai desenhar o ícone
  de **gelo** num golpe de luz. É cosmético e está em aberto.

### Mirar enquanto desfere (2026-09-06)

Mecânica pedida pelo dono: *"é possível mover o efeito e a área de dano enquanto
o desfere"*.

O `fwd` era fixado no primeiro quadro (teleporte + trava no inimigo mais
próximo) e valia até o fim. Agora ele acompanha o corpo: os fragmentos já nascem
de `_direcao(indice)` a partir do `fwd`, e a `ZonaBarragem` gira junto — efeito
e área de dano andam como uma coisa só.

Para isso os cantos passaram a ser construídos em **espaço canônico** (frente =
−Z) e a zona é **girada** por `apontar()`. Trocar os `points` da
`ConvexPolygonShape3D` a 60 Hz obrigaria a física a reconstruir a envoltória
convexa a cada quadro; girar o nó não custa nada.

⚠️ **A horizontal vem do CORPO, não da câmera, e a escolha é de rede.**
`mira_do_cast()` lê a câmera, que só existe na máquina do dono — usá-la faria o
servidor e os outros peers verem a barragem parada na direção do primeiro
quadro, enquanto o dono a vê girar. E quem decide dano é o servidor. O giro do
corpo já é replicado (`net_facing`), então mirar por ele sai sincronizado de
graça, sem um RPC novo por quadro.

⚠️ **A inclinação vertical é preservada** da mira inicial. O C começa
teleportando 7 m para cima e a trava automática aponta para baixo; a frente do
corpo é horizontal por definição, e trocar tudo por ela levantaria a barragem
para o horizonte no primeiro quadro — o golpe deixaria de mirar quem acabou de
escolher.

**A trava de movimento encolheu junto.** Era `lock_movement(C_TOTAL)` = 3,7 s, e
`Player.lock_movement` não tem timer próprio ("ignora o timer, a FSM cuida"):
soltar o C não devolvia o controle, e o jogador ficava parado o resto do tempo
sem animação de caminhada, caindo dos 7 m a que o próprio C o levou. Agora a
trava cobre só o preparo (1,0 s).

### O fragmento agora é só desenho

`FragmentoVisual` é um `Node3D` puro: sem `Area3D`, sem corpo físico, sem
varredura por quadro. Ele descobre onde parar com **um** raio no nascimento
(~90 raios na barragem inteira, contra ~30 varreduras **por quadro** antes), e
o contrato com o `RastroCurto` continua sendo a meta `pika_encerrado` — por
isso o rastro não precisou mudar uma linha.

A zona é uma `DamageZone` (e não uma `Area3D` crua como o campo de gelo da Hie
Hie) por dois motivos: herda o funil de dano inteiro — `cast_id`, teto, crédito
de kill, autoridade de servidor — e continua sendo contada como hitbox pelo
`test_frutas`, que conta `DamageZone` e leria "golpe mudo" se o C virasse outra
coisa.

Guarda de regressão: `tools/dev_tests/test_pika_c_area.gd`.

---

## Colisão — o que foi consertado em 2026-09-06

Quatro defeitos de colisão viviam aqui, e três deles vinham da mesma causa:
**a hitbox anunciada não era a hitbox que existia.**

### 1. O raspão não contava (era do motor, valia para o jogo inteiro)

A `DamageZone` anda por teleporte e varria o caminho com um `intersect_ray`
para não tunelar. Só que **raio não tem espessura**: entre dois quadros a
hitbox de um projétil deixava de ser a esfera anunciada e virava a linha do
centro dela. Quem passasse de raspão saía ileso.

Medido nesta máquina (alvo-cápsula de raio 0,40 deslocado do eixo, passo de
1,30 m — o do Z a 78 m/s):

| desvio do eixo | `intersect_ray` (antes) | esfera varrida (agora) |
|---|---|---|
| 0,00 m | acerta | acerta |
| 0,45 m | **passa direto** | acerta |
| 0,60 m | **passa direto** | acerta |
| 0,95 m | passa | passa (correto: 0,40 + 0,32 = 0,72 m é o limite) |

Agora `cast_motion` acha o instante do primeiro contato e `intersect_shape` diz
quem estava lá. Custo medido no caso que domina (voando no vazio): 0,176 µs
contra 0,105 µs do raio — **21 µs por quadro com 120 projéteis, 0,13% do
quadro**. Forma customizada (a parede de tsunami da Gura) continua no raio.

### 2. O peso do acerto quase nunca disparava

O hitstop/tremor/soco de FOV estava ligado em `body_entered`, que é sinal da
`Area3D` e só nasce quando a física vê a sobreposição naquele quadro. A 78 m/s
quem detecta é quase sempre a varredura, que chama `_on_body()` direto e **não
emite `body_entered` nenhum**. Ou seja: o item que a auditoria pontuou com 4/10
dependia de o alvo cair na fatia certa do quadro. Passou para `hit_landed`, que
sai nos dois caminhos.

### 3. O raio não parava no que acertava

A cabeça seguia viagem depois do acerto e o clarão de impacto nascia onde ela
morria de velhice — até 40 m adiante do corpo atravessado — além de atravessar
parede. Agora ela para no primeiro contato (o mesmo que o fragmento do C já
fazia) e o rastro desenha o clarão ali.

### 4. O X travava em gente e podia largar o jogador sobre o buraco

O clamp do ziguezague usava máscara cheia sem excluir ninguém: como neste
projeto personagem e mapa moram na mesma camada, **passar perto de qualquer
jogador travava a perna 1 m antes dele** — justamente quando o X deveria
seguir. E como a perna viaja em altura fixa (`_para.y = _de.y`) e nada olhava
para baixo, dava para ser largado no ar em cima de um dos 16 buracos da arena,
onde cair mata (`Scoreboard.VOID_Y`).

Agora só cenário segura a viagem, e o destino recua ao longo do próprio
segmento até achar chão. **Quando nenhuma amostra acha chão, a viagem segue** —
nesse caso a sonda não está dizendo "é perigoso", está dizendo "não sei", e
travar o golpe por falta de informação transformava o X em no-op no ar.

### 5. Honestidade do desenho

- A explosão do mergulho (4,5 m) passou a exigir **linha de visão** — ela
  atravessava muro, e a `DamageZone` já tinha a peça pronta desde o Tri-Beam.
- O anel da descarga do V passou a ter o **mesmo raio da hitbox**. Eram 2,2 m
  de dano sob um anel de 1,7 m: quem recuava até a borda do que via levava o
  golpe mesmo assim, e aprendia a distância errada.
- O núcleo visível do Z subiu de 0,55 para 0,78 do raio da hitbox. A auditoria
  media a hitbox valendo ~1,8× o que se via; agora que a esfera varrida faz o
  raio de 0,32 valer no percurso inteiro, o desenho tem de acompanhar.

Guarda de regressão: `tools/dev_tests/test_pika_colisao.gd` (6 cenários).

---

## Som — a fruta não tinha voz própria

Até 2026-09-06 a Pika tocava `AudioFX.gunshot` em cada raio do Z, mais
`whoosh`, `snap` e `impact` genéricos.

**Medição que condenou isso.** Análise por FFT dos vídeos de referência do dono
(`~/Downloads/skill X pika pika.mp4`, janelas de 0,2 s):

| trecho | banda dominante | centroide |
|---|---|---|
| 0,4–1,4 s (carga) | 2–5 kHz (86% da energia) | ~3,6 kHz |
| 1,6–4,2 s (viagem) | 5–10 kHz (75%) | ~6,4 kHz |
| 4,4–4,8 s (cauda) | 2–5 kHz (89%) | ~2,8 kHz |

Duas conclusões, as duas medidas:

1. **A fruta não tem grave.** Energia abaixo de 300 Hz: **0,0%** do início ao
   fim. O `gunshot` escorrega de 450 Hz para 50 Hz com sub em 75 Hz — era
   pólvora tocando por cima de luz.
2. **É ruído filtrado, não tom.** Fator de crista entre 12 e 27, e os picos são
   aglomerados largos, não parciais de uma fundamental. Senoide leria como
   sintetizador.

Então todo cue é a mesma receita: ruído branco por um passa-banda ressonante
cuja frequência central **varre no tempo**, e depois um passa-alta de 300 Hz que
impõe a conclusão nº 1.

| cue | onde toca | caráter |
|---|---|---|
| `carga` | wind-up do Z, carga do C | banda sobe 1,8 → 4,2 kHz |
| `disparo` | cada raio do Z | ataque instantâneo, banda desce 7,5 → 2,8 kHz |
| `fragmento` | fragmentos do C (1 em 3) | mais curto e mais agudo |
| `impacto` | onde o raio morre | estalo 5–9 kHz + glint cristalino |
| `viagem` | o X virando luz | sustentado, sobe a ~6,4 kHz |
| `explosao` | mergulho do X | **único cue com corpo grave** — e ele é o CHÃO, não a luz |
| `teleporte` | os 7 m para cima do C | zip que sobe |
| `barragem` | leito contínuo sob a barragem do C | em laço, morre ao soltar o C |
| `ceu` | ativação do V | subida de 2 s |
| `chuva` | cada descarga do V | pingo brilhante |

**O gerador é a fonte canônica.** Para mudar um som, mude
`tools/generate_pika_audio.py` e rode `python3 tools/generate_pika_audio.py` —
nunca edite os `.wav` à mão. Determinístico: mesma semente, mesmo arquivo.

O `PikaAudio` tem **teto de vozes por cue** (4 fragmentos, 5 chuvas, 7 disparos
simultâneos). O `OpeAudio`, que é o precedente, não precisa disso porque a Ope
tem golpes espaçados; a Pika tem barragem de 60 fragmentos por segundo.

---

## O que continua em aberto

- A passiva **Light Dash** é só texto: os `+35% de dano no próximo dash` não
  existem. Hoje a passiva é `speed_mod 1,25` / `jump_mod 1,15`.
- O **C** pede peso (hitstop/flash) **uma vez**, na entrada do alvo no volume;
  os tiques seguintes somam dano em silêncio, porque 20 hitstops por segundo
  travariam o jogo. Não há hoje um "peso de clímax" para o fim da barragem.
- A paralisia do C mostra o ícone de **gelo** no HUD (status `CONGELADO`, o
  caminho compartilhado de paralisia). Um status próprio de luz exigiria entrada
  nova no `StatusFX.CATALOGO` e um ícone procedural no `StatusEffectsHud`.
- O **V** aplica dano num raio de 2,2 m só nas descargas principais; a chuva
  visual é mais densa que a cadência de dano, de propósito (ver a referência).
- Os valores de dano do **C e do V** foram inferidos pela faixa canônica do
  slot, não medidos — o dono ajusta.
