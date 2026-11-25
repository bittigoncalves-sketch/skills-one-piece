# Combate de espada — a Yoru

Preparação do corpo a corpo com arma, pedida pelo dono em **2026-09-06**. O
combo de punho continua onde estava ([`COMBATE_CORPO_A_CORPO.md`](COMBATE_CORPO_A_CORPO.md));
aqui é só o que muda quando há uma lâmina na mão.

> 🔵 **As zonas da lâmina estão desenhadas em azul transparente na tela**
> (`SwordBlade.MOSTRAR_ZONAS = true`), para conferência. Vire para `false`
> quando não precisar mais ver. Não confundir com o **vermelho** da hitbox do
> C da Pika Pika, que é outra conferência temporária.

**Como equipar:** tecla **3**. Desde 2026-09-06 a espada é o **terceiro modo de
combate**, ao lado da fruta (1) e do estilo de luta (2) — ver
[`MODOS_DE_COMBATE.md`](MODOS_DE_COMBATE.md). Entrar no modo 3 saca a Yoru, sair
dele a guarda, e **os slots Z/X/C/V ficam mudos**: quem está de espada na mão
corta, não conjura.

(Era a tecla Y, de debug, entre a montagem da espada e a chegada dos três modos.)

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `assets/models/weapons/yoru.glb` | o modelo (6,6 MB, 875 vértices, 3 texturas) |
| `src/items/YoruSword.gd` | monta a espada: modelo, `handle`, lâmina |
| `src/combat/SwordBlade.gd` | **as bolinhas do fio**: dano e choque |
| `src/combat/Melee.gd` | `COMBO_SWORD` e o `golpear()` que arma o fio |
| `src/anim/WeaponPoses.gd` | as poses de corte (já existiam) |
| `src/player/player_rig.gd` | a mão nomeada `Hand_R` |
| `Player.gd` | `sacar_ou_guardar_espada()`, `lamina_da_espada()`, tecla Y |

---

## O ponto de pega: `handle` sobre `Hand_R`

Pedido: *"nomeie o cabo como handle e a mão do jogador também, depois os ligue —
assim será possível ter uma referência de onde será segurada"*.

Antes disso a pega era um número mágico: o `SwordPickup` empilhava um cilindro
em `y = -0.15` *"para que a origem seja perto do centro da mão"*, e quem
quisesse saber onde a arma era segurada tinha de refazer a conta de cabeça.

Agora são **dois nós nomeados e um parentesco**:

```
ForeArm_R
└── Hand_R          ← a mão (player_rig.NOME_DA_MAO)
    └── Yoru
        ├── handle  ← o cabo, na origem da espada
        ├── modelo
        └── Lamina
            ├── zona_lamina_0 … zona_lamina_6
```

`handle` fica na **origem** da cena da espada, então pôr a espada como filha de
`Hand_R` já encosta um no outro — não há offset escondido em lugar nenhum do
caminho. Mover a pega é mover um dos dois nós.

### ⚠️ Os dois rigs têm o antebraço em eixos OPOSTOS

Bug relatado em 2026-09-06 ("a Yoru está no lado oposto"). A mão nasce na ponta
do antebraço nos dois casos, mas para lados opostos do Y local do osso:

```gdscript
skinnado: item_handle.position = Vector3(0,  0.36, 0.0)   # fora da mão = +Y
voxel:    item_handle.position = Vector3(0, -0.36, 0.02)  # fora da mão = -Y
```

Tudo que é segurado cresce no próprio **+Y**, então no personagem voxel — que é
o padrão — a arma crescia **de volta pelo braço**. Medido antes do conserto: a
ponta da lâmina ficava **1,15 m atrás** do jogador.

`Hand_R` do rig voxel passou a nascer com `rotation.x = PI`. O conserto mora no
**rig**, e não na espada, porque a diferença é do rig: qualquer item futuro
nasce certo sem precisar saber que existem dois tipos de personagem.

Depois: frente **+1,14 m**, lado **+0,63 m** (direito), inclinada ~10° para
baixo — guarda baixa.

> O rig do projeto tem 13 papéis e **nenhum deles é mão**: a cadeia do braço
> termina em `ForeArm`. Este nó sempre foi a mão de fato — é onde a arma encosta
> — só que nascia anônimo (`@Node3D@N`) e vivia guardado numa variável.

## A geometria do modelo, medida

O `.glb` chegou como **uma malha só** (875 vértices, um nó `mesh_node`, sem
esqueleto e sem partes separadas). Não havia cabo para renomear: foi preciso
descobrir onde ele está, desenhando a silhueta a partir das **arestas** da malha
(varrer só os vértices engana numa malha esparsa como esta).

| parte | Y no modelo cru | largura |
|---|---|---|
| pomo + cabo | +0,50 a +0,27 | ~0,05 |
| **guarda** (a cruz) | +0,26 a +0,19 | **0,35** |
| lâmina | +0,19 a −0,50 | ~0,046 |

**No modelo a lâmina aponta para −Y** — a mesma convenção do `espadas_zoro.glb`
e o **oposto** da espada empunhada anterior, cuja lâmina subia em +Y a partir da
mão. Daí a rotação de 180° em X; sem ela a Yoru nasce apontando para o chão.

Escala 2,0: a lâmina fica com **1,38 m**, na vizinhança da espada antiga (1,2 m)
e ainda lendo como montante.

---

## As bolinhas do fio

Pedido: *"na lâmina serão colocadas zonas no formato de bolinhas como área de
recebimento de informação: quando uma dessas áreas toca em um inimigo durante
uma animação o inimigo recebe o dano; ou quando uma dessas áreas na espada do
inimigo toca a área da espada do jogador ocorre uma colisão de espadas anulando
ambos os movimentos"*.

Sete `Area3D` esféricas de raio 0,28, distribuídas da guarda (0,39 m acima da
mão) até a ponta (1,77 m). Elas são presas à espada, que é presa à mão, que a
animação gira — então **percorrem o arco de verdade**.

### O que isso substituiu

O corte criava **uma `BoxShape3D`** de `raio*2` por `alcance*1.5` — com os
números da tabela, **4 m de largura por 3,75 m de fundo** — parada na frente do
peito durante os quadros ativos. Ela não tinha relação nenhuma com onde a lâmina
estava: era um volume que aparecia na direção do clique.

⚠️ **O corte ficou mais exigente, e o número diz quanto.** A caixa cobria da
ordem de 15 m³; as sete bolinhas cobrem ~1,1 m³ varridos ao longo do golpe. O
raio de 0,28 é generoso de propósito — a lâmina tem 0,09 m de largura — para o
corte não virar prova de agulha. É a mesma lição que o C da Pika deu: hitbox
honesta não pode ser hitbox minúscula.

O teste cobra que **não haja vão entre as bolinhas** (passo 0,23 m contra
diâmetro 0,56 m): um vão no meio do fio deixaria o alvo passar sem levar nada, e
o defeito seria invisível porque o golpe continuaria acertando às vezes.

### A camada 8

Neste projeto personagem e cenário vivem juntos na **camada 1**, e as consultas
de combate usam `collision_mask = 15`. Bolinha precisa ser vista por **outra
bolinha** e por mais ninguém — se entrasse nas camadas 1-4, toda varredura de
projétil do jogo passaria a esbarrar em espada.

Então a bolinha **mora na camada 8** (bit 128) e **olha** para 1-4 (corpos) mais
a própria 8 (a espada do outro).

### O choque

Duas espadas só se anulam quando **as duas estão golpeando** (`esta_armada()`).
Bater na espada parada de alguém que está de guarda não é um clash — é um acerto
que a guarda resolve.

Quando acontece: as duas lâminas desarmam, o `MeleeController.cancelar_golpe()`
dos dois donos é chamado (ele já existia para dash-cancel e morte, e limpa
`_passo_em_curso`, a trava de recuperação e o buffer de clique), e sai anel +
fagulhas + hitstop.

⚠️ `area_entered` dispara nos **dois** lados. O primeiro a chegar resolve e marca
os dois — sem isso o cancelamento correria duas vezes e o efeito de tela sairia
dobrado. O teste cobra exatamente isso (`1 e 1`, não `2 e 2`).

---

## Os efeitos vêm da ARMA, não do corpo

Defeito relatado em 2026-09-06 com gravação de tela: *"o efeito do combate corpo
a corpo está acontecendo ao invés do efeito da espada"*. Eram dois, com a mesma
causa de fundo — o efeito era calculado a partir do CORPO em vez de vir da arma.

| | antes | agora |
|---|---|---|
| impacto | `Melee._impacto`: anel de choque do SOCO, a `alcance` m à frente do peito, solto no ar | fagulhas na **bolinha que encostou** |
| rastro | entre `ForeArm_R` (o **cotovelo**) e um ponto chutado a 1,8 m | entre os nós **`guarda`** e **`ponta`** da Yoru |

O rastro cobria o antebraço inteiro mais a lâmina, e em tela lia como uma chapa
branca saindo do peito apontando para outro lado que não a espada.

A bolinha viaja junto com o sinal (`body_entered.connect(_no_corpo.bind(bola))`)
porque sem ela o receptor só sabe QUE encostou, não ONDE — e a única posição à
mão seria a do nó da lâmina, que fica junto ao punho: o clarão sairia do cabo.

⚠️ Os efeitos são pendurados por `_palco_de_efeitos()`, que usa
`get_tree().current_scene` quando existe e cai para a raiz quando não. Em script
`-s` o `current_scene` é nulo e o efeito **some sem avisar** — armadilha que o
`BaseTest` do projeto já registrava.

## O combo: horizontal, depois vertical

| clique | golpe | pose | dano | startup | ativo | recuperação | total |
|---|---|---|---|---|---|---|---|
| 1º | Corte Horizontal | `slash_type` 0 | 64 | 0,32 s | 0,14 s | 0,30 s | **0,76 s** |
| 2º | Corte Vertical | `slash_type` 2 | 96 | 0,40 s | 0,16 s | 0,44 s | **1,00 s** |
| *(referência)* jab de punho | | | 48 | 0,20 s | 0,06 s | 0,14 s | 0,40 s |

**A espada é 1,9× mais lenta que o punho**, a pedido do dono. O `ativo` cresceu
junto e não só o startup: uma lâmina de 1,38 m varrendo o espaço fica perigosa
por mais tempo que um punho, e encolher só o começo daria uma espada lenta de
sacar **e** fácil de errar — o pior dos dois.

### ⚠️ A animação e a hitbox eram duas descrições da mesma coisa, e não batiam

`WeaponPoses` tinha as fases do golpe fixas em 0,20 e 0,26 do ciclo; a hitbox
nascia em `startup` **segundos**. Medido:

| | a lâmina VARRE | a hitbox VIVE |
|---|---|---|
| antes | 0,098 → 0,127 s | 0,200 → 0,290 s |
| agora | 0,320 → 0,460 s | 0,320 → 0,460 s |

O fio passava **0,102 s antes** de o dano existir — seis quadros —, com a espada
já no arco de volta quando a hitbox aparecia. Agora as fases saem de
`Melee.fracao_do_golpe`, derivadas do mesmo frame data que arma a hitbox: erro
medido **0,0000 s**. A janela do rastro segue as mesmas fronteiras.

Eram **três** passos (corte D-E, corte E-D, corte vertical), e essa era a última
tabela do projeto ainda escrita no modelo antigo (`atraso`/`vida` em vez de
startup/ativo/recuperação). O comentário registrava o porquê: *"a espada não
está no mapa, o plano não a cobre, e escrever frame data para ela seria inventar
números"*. Isso deixou de valer — a espada voltou, com dois golpes definidos
pelo dono —, então **a espada entra no mesmo modelo de frame data do punho**.

Os tempos vêm da **animação**, não do gosto: `WeaponPoses._get_slash_frame` já
divide o corte em puxar para trás (0,00-0,20) → jogar para a frente (0,20-0,26)
→ voltar ao repouso (0,26-1,00). O `ativo` é curto porque a janela em que a
lâmina cruza o alvo é curta na animação que já existe.

### ⚠️ Golpe procedural não tem clipe — e isso quebrou a duração

Bug relatado em 2026-09-06 ("o combo de punho continua em ação com a espada
equipada"). Os cortes são procedurais e nascem com `"anim": ""`;
`Melee.duracao_tocada` começava por `clipe()`, que devolve `null`, e retornava
**0,0** antes de olhar o frame data. O Player faz
`speed = 1.0 / maxf(duracao, 0.1)` — ou seja **10×**:

| | duração | velocidade |
|---|---|---|
| antes | 0,000 s | **10,0×** (o corte inteiro em 0,1 s) |
| depois | 0,490 s | 2,0× |

Em tela o corte passava em dois quadros: o jogador clicava, nenhuma espada
aparecia, e o que sobrava era a pose de repouso — indistinguível de "o punho
continua no lugar da espada". Agora, sem clipe mas com frame data, a duração é
`startup + ativo + recuperação`.

`Balance.MELEE.espada` acompanhou: de `[64, 72, 96]` para `[64, 96]`. O par vale
160, ainda abaixo do combo de punho completo (278) — coerente com ter dois
golpes em vez de quatro.

**O `projetil: true` do corte vertical antigo não foi trazido.** A meia-lua dava
alcance ao terceiro passo de um combo de três; num par de dois ela transforma o
fechamento num golpe à distância, que é outro assunto. Fica como decisão do
dono, não como herança silenciosa.

---

## O que ficou em aberto

- A espada continua **fora do spawn do mapa**: só a tecla Y a coloca na mão.
- As poses de corte são as que já existiam (`WeaponPoses`), afinadas para uma
  espada de 1,2 m; com a Yoru em 1,38 m e mais pesada, o arco pode pedir ajuste.
- **Sem guarda/parry de espada**: o choque só acontece entre dois golpes ativos.
  Bloquear com a lâmina parada é mecânica que não existe.
- O `SwordPickup` (a espada de cubos) continua no projeto e ainda funciona pelo
  `equip_item`; ele não foi apagado para não quebrar quem o referencia.

### A pose do corte horizontal

Pedido: *"ambos os braços grudados na lâmina, a lâmina à direita do jogador parte
para a esquerda"*.

**Os braços giravam para lados opostos** em Y (direito −1,0, esquerdo +0,5): como
o `frame` multiplica os dois, um ia para a esquerda enquanto o outro ia para a
direita, e as mãos se afastavam durante o golpe.

⚠️ **O sinal em Y foi MEDIDO, e contraria os rótulos antigos.** Deduzir pelos
nomes ("tipo 0 = direita para esquerda" usava Y negativo) deu errado:
rastreando a ponta da lâmina no eixo lateral do jogador, o preparo levava a
espada para a **esquerda** (+1,07 → −0,11 m) e o golpe a trazia de volta. O
coeficiente correto é **positivo**. Hoje: direita **+1,72 m** no preparo →
esquerda **−1,44 m** no corte, nessa ordem.

**A empunhadura de duas mãos nunca existiu de verdade.** O comentário da pose de
repouso dizia que o braço esquerdo "cruza o corpo para alcançar o cabo"; medido,
a mão ficava a **0,875 m** dele. Os ângulos atuais saíram de uma **busca por
cinemática direta** (varredura dos dois ossos medindo a distância da mão ao
cabo), não de tentativa e erro.

| momento | distância da mão esquerda ao cabo |
|---|---|
| pose original | 0,875 m |
| repouso, hoje | **0,25 m** |
| pior instante do golpe | **0,38 m** |
| melhor alcançável no auge (busca exaustiva) | 0,154 m |

### A trajetória, validada em espaço LOCAL do personagem

A especificação do dono (2026-09-06) exigiu validação matemática, não visual:

```gdscript
sword_tip_local = player.global_transform.affine_inverse() * sword_tip.global_position
# preparação: x > 0    cruzamento: x -> 0    final: x < 0
```

É o que o teste faz. Resultado medido, com a janela de dano como referência:

| | x local | z local |
|---|---|---|
| início da janela | **+1,64** (direita) | −0,34 |
| cruzamento | **+0,27** (centro) | **−1,64** (à frente) |
| fim da janela | **−0,64** (esquerda) | −1,46 |

E a trajetória é um **arco**, não uma reta: a sagita (distância do meio da corda
até a curva) é **0,74 m** para a frente.

⚠️ **`root`, `SkinPivot` e `GLBModel` giram 0,00°** durante todo o ataque — o
personagem não dá meia-volta nem fica de frente para a câmera. Quem gira são os
bones.

**Os 16 quadros de referência**, com os cinco críticos:

| quadro | x local | leitura |
|---|---|---|
| **4** preparação máxima | +1,15 | direita |
| **7** aceleração | +1,62 | direita, avançando |
| **9** cruzamento | −0,80 (z = −1,27) | atravessou a frente |
| **11** final do corte | −1,54 | esquerda |
| **12** follow-through | −1,41 | inércia segura à esquerda |

### ⚠️ A curva do corte fazia a lâmina TELEPORTAR

`ease_out_expo` completava **50% do arco nos primeiros 10%** da janela e 87,5%
aos 30%. Em espaço local a ponta saltava de +1,53 para −1,22 entre duas amostras
— 2,75 m sem passar pela frente. Não havia arco.

Um corte pesado acelera *entrando* no centro, é mais rápido *ao* cruzar e
desacelera saindo — isso é uma curva em **S**, não um `ease_out`. `ease_corte`
faz 0,4% aos 10%, 50% aos 50% e 99,6% aos 90%.

### ⚠️ Não havia follow-through

O `ease_out_elastic` começava no instante em que o corte terminava e freava a
arma no ar. Medido nos 16 quadros: no **quadro 11** ("espada claramente à
esquerda") ela já estava de volta em **x = +1,33**, do lado direito.

Agora a inércia passa do ponto final (`EXCESSO_INERCIA`) e só depois a
recuperação começa — que é mais lenta que o cruzamento, como uma lâmina de
1,38 m exige.

### ⚠️ A animação é adiantada em relação à hitbox

`Melee.COMPENSACAO_CADEIA`. A lâmina é carregada pelo antebraço, que anda
atrasado pela cadeia cinética, e a espada já parte da direita no repouso
(ponta em x = +0,97). Com as fases coincidindo com a janela de dano, o fio
cruzava a frente a **92% da janela** — o dano abria com a espada ainda armada.
Adiantando só a animação, o cruzamento cai a **43% da janela**.

### ⚠️ Quem gira são os BRAÇOS — o `Torso` é pai de tudo

Relato do dono depois da primeira passada de animação:

> *"o personagem rotaciona correto, porém a animação está permanecendo a mesma
> como se ele estivesse estático [...] cabeça e torso ficam estáticos, pernas se
> dobram para manter o equilíbrio e os braços se movem ao redor do torso"*

Eu tinha posto a varredura no **tronco** (Y = 1,70 rad) porque era o que mantinha
as duas mãos no cabo. Resolveu a empunhadura e destruiu a animação, pela
hierarquia do rig:

```
Torso
├── Neck / Head
├── UpperArm_R / ForeArm_R
├── UpperArm_L / ForeArm_L
└── Thigh_R|L / Shin / Foot
```

O `Torso` é **pai de tudo**. Yaw nele roda cabeça, braços e pernas em bloco — o
personagem girava numa bandeja em vez de golpear.

**E contaminou uma medição minha.** A "passada" que reportei (0,33 m de avanço do
pé direito) era a perna sendo *carregada* pela rotação do tronco, não um passo.

| | antes (tronco gira) | agora (braços giram) |
|---|---|---|
| giro do **tronco** em Y | 90,4° | **8,4°** |
| joelhos dobram | — | **42,8° / 34,7°** |
| varredura da lâmina | +1,72 → −1,44 m | +1,64 → −1,55 m |
| mão esquerda ao cabo | 0,32 m | **0,38 m** |

O custo está na última linha e é declarado: com os braços girando sozinhos a mão
esquerda se afasta 6 cm a mais do cabo. O ombro deste rig não translada, então
alcance de braço é o teto — e a leitura de animação vale mais que 6 cm de
empunhadura.

### O corpo no corte: lâmina, balanço, pés e braços

Segunda passada de animação (2026-09-06), pedida pelo dono. Cada item foi
**medido antes e depois**, com o personagem real:

| | antes | agora |
|---|---|---|
| **direção da lâmina** no auge | 43,8° da vertical (empinada) | **77,8–89,6°** (deitada) |
| **inclinação do tronco** | 4,6 → 13,5° (consequência) | **18,9°** à frente, **17,1°** de tombo |
| **pé direito** | ia junto com o corpo | **avança 0,33 m** e cruza |
| **pé esquerdo** | terminava do mesmo lado do direito | **recua 0,15 m**, vira pivô |
| resto no fim | — | **0,00 m** (a base volta) |

**A direção da lâmina é postura da ARMA, não dos ossos.** A espada era só
*carregada* pelo braço, e no meio do corte empinava 46° para fora da horizontal
— um corte horizontal com a lâmina empinada bate de chapa, não corta. A correção
não podia vir do antebraço: girá-lo moveria a MÃO, e a mão é o que segura o
cabo. Então a arma ganhou rotação própria (`WeaponPoses.postura_da_arma`),
aplicada ao nó da espada em torno da origem dela — que é o `handle`, que é onde
a mão está. Gira o fio, não move a pega.

⚠️ **A postura anda no relógio do ANTEBRAÇO.** Quem carrega a lâmina é o
`ForeArm_R`, e ele usa o frame atrasado em 0,06 (a cadeia cinética). Compensar
com o frame do TRONCO deixava a correção adiantada em relação ao que a causava:
ótima no auge (89,1°) e mergulhando a 55,9° na entrada da janela. Mesmo atraso,
mesma fase.

**A base era simétrica e sem direção.** `absf(frame)` abria as duas coxas igual,
no preparo e no golpe — os dois pés terminavam do mesmo lado no auge, o que lê
como tropeço. Agora o agachamento é comum aos três cortes e a **passada é do
horizontal**: o corpo gira à esquerda, o pé direito passa à frente cruzando e o
esquerdo vira pivô. É a passada que dá o giro; sem ela o tronco roda 90° sobre
pernas paradas.

⚠️ **O limite é do RIG**, não da pose: braços de um osso só, ombro que não
translada, e a espada rígida no antebraço direito. Baixar disto exige mudar o
rig (ombro com translação, ou a espada presa a um ponto entre as duas mãos), não
afinar mais ângulo.

Guardas de regressão: `tools/dev_tests/test_espada_yoru.gd` (18 checagens) e
`tools/dev_tests/test_corte_horizontal.gd` (tempo, direção e empunhadura).
