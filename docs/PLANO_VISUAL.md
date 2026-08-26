# Plano — melhoria visual qualitativa

Pedido do dono (2026-08-25): *"iniciar planejamento de melhoria visual
qualitativa no jogo"*. Alvo escolhido por ele: **cel-shading anime, estilo One
Piece**. Frente por onde começar: **atmosfera e iluminação**.

> **Isto é PLANEJAMENTO, não implementação.** Nenhum arquivo do jogo foi
> alterado por este documento.

---

## 0. O diagnóstico, medido

Levantado no jogo rodando (capturas em um-jogador) e por varredura do código,
não por impressão.

| achado | evidência |
|---|---|
| ~~Não existe glow/bloom no projeto inteiro~~ | ✅ **RESOLVIDO na Fase 1** (2026-08-25) |
| ~~A emissão dos efeitos é DESCARTADA~~ | ✅ **RESOLVIDO na Fase 5** (2026-08-25). Eram **28** sítios (não 32 — a contagem por proximidade de texto inflava), todos passados para albedo HDR via `FxUtil.brilho()` |
| **Nenhum shader 3D próprio** | `find -name "*.gdshader"` devolve **zero**. Todo o visual 3D é `StandardMaterial3D` cru |
| **94 pontos criam material à mão** | em **34 arquivos** — é este número que decide a arquitetura do cel (ver §2) |
| **Sem névoa** | `env.fog_enabled = false`, com o comentário "sem parede cinza" |
| **Chão sem leitura** | plano claro liso ocupando ~60% da tela, sem textura, sem variação, sem borda |
| **Contraste estourado** | `ambient_light_energy = 1.1` (fonte céu) + chão quase branco + `TONE_MAPPER_FILMIC` |
| **Sem contorno** | nada de outline — e contorno é metade da leitura de anime |

Valores em vigor hoje (`src/world/WorldEnv.gd` e `project.godot`):

```
sol      energia 1.35   cor (1.00, 0.96, 0.88)   sombra 200 m
ambiente fonte CÉU, energia 1.10
ssao     LIGADO, raio 1.2
tonemap  FILMIC
fog      DESLIGADO
msaa_3d  1 (2×)         soft_shadow_filter_quality 2
```

---

## 1. O que "cel-shading" exige, em partes

Anime não é um efeito só. São **três**, e elas são independentes — dá para
entregar uma sem as outras:

| parte | o que faz | onde vive |
|---|---|---|
| **A. Banda de luz** | a sombra vira 2-3 degraus chapados em vez de gradiente | no MATERIAL de cada objeto |
| **B. Contorno** | linha escura na silhueta e nas quinas | passe de TELA (profundidade + normal) |
| **C. Luz e ar** | cores saturadas, sombra colorida, brilho nos efeitos | no AMBIENTE (`WorldEnv`) |

A parte **C** é a Fase 1 pedida pelo dono. As outras duas vêm depois, e a ordem
importa — ver §3.

---

## 2. A decisão de arquitetura (a que custa caro errar)

**A pergunta:** onde mora o cel? Três caminhos, e o número que decide é
**94 pontos criando material em 34 arquivos**.

| | (a) só no material | (b) só na tela | (c) HÍBRIDO |
|---|---|---|---|
| como | trocar `StandardMaterial3D` por `ShaderMaterial` em todo lugar | um passe de pós-processamento que quantiza a imagem e desenha contorno | **contorno na tela**, **banda no material** |
| qualidade | a melhor: a banda incide sobre a LUZ, o albedo fica intacto | pior: quantiza a imagem FINAL, então banda o céu, os VFX e a cor pura junto | boa |
| custo | **94 pontos** de edição, mais o risco de esquecer um e ficar um objeto "realista" no meio | 1 shader, zero mudança de material | 1 shader + uma FÁBRICA de material |
| risco | refatoração grande antes de ver qualquer pixel melhor | efeito "filtro de foto": lê como pós-processamento barato, não como anime | o normal |

**Escolhido: (c) híbrido**, e a razão é de sequência, não de gosto — o contorno
sozinho já entrega a maior parte da leitura de anime **sem tocar em material
nenhum**, então ele pode entrar cedo e ser julgado jogando. A banda entra depois,
por uma fábrica.

**A fábrica é o ponto que salva o (c) de virar o (a).** Antes de migrar 94
pontos, o passo 0 da Fase 3 é *contar quantas RECEITAS distintas existem* —
boa parte dos 94 já passa por ajudantes (`FxUtil.particle_material`,
`FireFX._voxel_material`, `_plasma_material`, `_magma_material`…). A migração é
das receitas, não dos pontos.

### ⚠️ Restrição técnica que muda o desenho do contorno

O `ScreenFX` de hoje é um **`CanvasLayer`** com shader `canvas_item`. Um shader
de canvas **não enxerga o buffer de profundidade**. Contorno de qualidade
precisa de profundidade e normal (`hint_depth_texture`,
`hint_normal_roughness_texture`), e esses só existem em shader **`spatial`**,
no Forward+.

Ou seja: o passe de contorno **não pode ser mais um uniform no `ScreenFX`**.
Ele é um nó novo — um quad em `render_priority` alto à frente da câmera, ou um
`SubViewport`. Isso é bom, aliás: mantém separado o que é *game feel* (vinheta,
flash, speed lines — o `ScreenFX` de hoje) do que é *estilo de render*.

### A decisão declarada

| | |
|---|---|
| **benefício imediato** | o contorno sozinho já muda a leitura do jogo, e a Fase 1 (ar/luz) melhora todos os VFX de graça |
| **impacto futuro** | a fábrica de material vira o lugar onde qualquer estilo futuro se troca de uma vez; hoje não existe esse lugar |
| **manutenção** | um shader de contorno e uma fábrica, contra 94 materiais soltos que já divergem entre si |
| **extensão** | personagem novo, fruta nova e bloco novo herdam o estilo sem ninguém lembrar de aplicar |
| **custo** | Fase 1 é dezenas de linhas; Fase 2 é um shader; Fase 3 é a migração das receitas |
| **riscos** | ver §6 — o principal é o contorno em cima do voxel, que já é todo quina |

---

## 3. ⚠️ A Fase 1 não é independente do cel — e isso muda os números dela

O dono pediu para começar por atmosfera e iluminação. Certo: é a frente mais
barata e a que muda mais pixel por hora. Mas **ajustar o ar para o render de
hoje e depois trocar o render é pagar duas vezes.**

Então a Fase 1 é escrita como *"a luz que um cel-shader vai consumir"*, e três
dos ajustes vão na direção CONTRÁRIA do que se faria num jogo realista:

| ajuste | jogo realista | aqui, servindo o cel | por quê |
|---|---|---|---|
| **SSAO** | manter/aumentar | **desligar ou quase** | oclusão é um gradiente suave escuro: é exatamente o que briga com faixa chapada. Hoje está ligado com raio 1,2 |
| **tonemap** | FILMIC (rola o brilho, dessatura) | **LINEAR ou REINHARD** | filmic dessatura o alto da curva; anime quer cor saturada e chapada |
| **ambiente** | alto, para preencher sombra | **baixar** | ambiente alto achata a diferença entre luz e sombra — e a diferença É o desenho no cel |
| **glow** | moderado | **ligar, generoso no emissivo** | é o que faz fogo/raio/trevas lerem como poder. Combina com cel, não briga |
| **névoa** | volumétrica | **de profundidade, chapada, afetando o céu** | dá perspectiva atmosférica sem a "parede cinza" que o comentário de hoje temia |

**Isto precisa ser dito porque a Fase 1 vai parecer PIOR sozinha em um ponto:**
tirar SSAO e baixar ambiente deixa a cena mais dura antes de a banda e o
contorno entrarem para dar forma. É uma transição declarada, não um retrocesso.

---

## 4. As fases

### Fase 1 — Ar e luz (`src/world/WorldEnv.gd`)  ⬅ **começa aqui**

Um arquivo, ~40 linhas. Sem dependência nenhuma.

1. **Glow ligado**, com limiar acima de 1.0 para só o emissivo brilhar (e não o
   chão claro virar uma mancha).

   ⚠️ **E AQUI ESTE PLANO ESTAVA ERRADO.** Ele afirmava que os golpes de nove
   frutas passariam a ler "sem tocar em uma linha de VFX". **Não passam.**
   Medido com esferas de teste — halo com glow menos halo sem glow:

   | material | diferença |
   |---|---|
   | unshaded + emissão 4.0 | **+0,0000** |
   | unshaded SÓ albedo | +0,0000 (idêntico ao de cima) |
   | sombreada + emissão 4.0 | +0,0355 |
   | unshaded + **albedo 2,5** | **+0,0586** |

   As duas primeiras serem iguais ao dígito provam que `SHADING_MODE_UNSHADED`
   **descarta a emissão** — e é assim que os efeitos deste jogo são feitos.

   A afirmação vinha de `grep emission_energy_multiplier`: o grep provava que a
   emissão era ESCRITA, não que era USADA. A correção é albedo acima de 1,0 em
   vez de emissão, e é a **Fase 5**.
2. **Névoa de profundidade**, com `fog_sky_affect` e perspectiva aérea, na cor
   do horizonte do céu — o horizonte deixa de ser uma linha onde o mundo acaba.
3. **Exposição e tonemap** recalibrados para o chão parar de estourar.
4. **SSAO** reduzido/desligado, e **sombra de contato** no lugar dele — contato
   é uma linha, não um gradiente; casa com o cel.
5. **Cor da sombra**: sombra azulada e luz quente é o par que dá "anime ensolarado".
6. Tudo isso **escalado por `GameFlow.device`** (`celular`/`tablet`/`pc`), que
   já existe e já é respeitado pelo `ScreenFX`.

**Portão:** capturas do MESMO ponto do mapa e do MESMO golpe, antes e depois,
lado a lado. Mais uma medida objetiva: o histograma do chão hoje está colado no
branco — depois, ele tem que sair do topo.

### Fase 2 — Contorno (nó novo, shader `spatial`)

Sobel de profundidade + descontinuidade de normal. Espessura em pixels,
constante com a distância (senão o contorno some de longe e engrossa de perto).

**Portão novo:** `medir_contorno.gd` — conta pixels de linha numa captura fixa e
prova que a silhueta do personagem tem contorno em três distâncias diferentes.

### Fase 3 — Banda de luz (fábrica de material)

Passo 0: **contar as receitas distintas** por trás dos 94 pontos. Só então
migrar. A fábrica nasce em `src/fx/Materiais.gd`.

**Portão:** um teste que varre `src/` e falha se aparecer `StandardMaterial3D.new()`
fora da fábrica — a mesma disciplina do `test_balance.gd` com a tabela de dano.

### Fase 4 — O chão e o mundo

O plano claro é a maior superfície da tela. Com contorno e banda já valendo,
decidir aqui o que ele precisa: textura, variação de cor por região, borda de
plataforma marcada. **Depois** das fases 2 e 3 de propósito — o que o chão
precisa muda completamente quando o render muda.

### Fase 5 — VFX das frutas ✅ **FEITA em 2026-08-25**

**28 sítios** (não 32 — contagem por proximidade de texto inflava em 4) trocaram
emissão por **albedo acima de 1,0**, via `FxUtil.brilho()`. Mais o
`particle_material`, por onde passam 13 chamadas de 6 arquivos.

Medido pelo portão (`captura_visual.gd`), cena `4_emissivo`:

| | antes da Fase 5 | depois |
|---|---|---|
| brilho médio | 0,530 | **0,620** |
| **pico** | 0,832 | **1,000** |
| tela estourada | 0,0% | **3,0%** |

As outras quatro cenas ficaram idênticas ao dígito — o que é a prova de que a
mudança tocou só o que era emissivo.

### ⚠️ E o brilho foi BAIXADO no mesmo dia

Relato do dono assim que viu: *"o brilho das skills está muito alto"*. Estava —
e o motivo é que as energias escritas nos efeitos (2,5 · 3,0 · 4,0 · 5,0 · 6,0 ·
8,0) **nunca foram calibradas**: elas viviam num campo de emissão descartado,
então ninguém jamais viu o efeito delas. Aplicadas ao pé da letra, ficaram
fortes demais.

| | Fase 5 crua | depois do ajuste |
|---|---|---|
| tela estourada | 3,0% | **0,3%** |
| pico | 1,000 | 0,975 |
| brilho médio | 0,620 | 0,533 |

**Duas alavancas, e vale saber qual é qual:**

- **`FxUtil.ESCALA`** (hoje `0,45`) — a força do EFEITO. Ela **comprime** em vez
  de multiplicar: `e = 1 + (energia − 1) × ESCALA`. Multiplicar achataria tudo
  por igual e mataria a diferença entre um golpe de 2,5 e um de 8,0; comprimir
  preserva a ordem que o autor quis e encurta a distância.
- **`WorldEnv` → `glow_intensity`** (hoje `0,5`) — o tamanho/força do HALO. Junto
  saiu o nível 4 do glow (auréola bem aberta) e o limiar subiu para 1,15, para
  passar só o núcleo de verdade.

Se voltar a incomodar, mexa primeiro na primeira (o núcleo), depois na segunda
(a auréola).

**O piso de 1,0 em `brilho()` não é detalhe:** o `SandFX` declarava energia
**0,8**, e aplicar isso ao albedo deixaria a areia mais escura do que estava. A
função existe para clarear; energia abaixo de 1 significa "não brilha".

⚠️ **E o glow escancarou um problema de arte:** os "Vagalumes de Fogo" da Mera
Mera percorrem a roda de matiz inteira e agora brilham em ciano, magenta e
verde. Registrado na [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) — é
decisão do dono, não conserto.

### Fase 6 — HUD

Retângulos chapados e fonte padrão. Fica por último porque é o único que **não**
depende do render 3D — pode ser feito em paralelo por outra frente, a qualquer
momento.

---

## 5. Divisão do trabalho

Territórios que não se cruzam, no padrão do [`AGENTES.md`](AGENTES.md):

| Ordem | Frente | Território | Depende de |
|---|---|---|---|
| 1 | **Ar e luz** | `src/world/WorldEnv.gd` | nada |
| 1 | **HUD** | `src/ui/` | nada (paralelo de verdade) |
| 2 | **Contorno** | nó + shader novos, `src/fx/` | Fase 1 (a luz que ele desenha por cima) |
| 3 | **Fábrica de material** | `src/fx/Materiais.gd` + as receitas | Fase 2 (julgar as duas juntas) |
| 4 | **Chão e mundo** | `src/world/MapBuilder.gd`, `TreeScatter.gd` | Fases 2 e 3 |
| 5 | **VFX** | `src/effects/` | Fase 1 |

---

## 6. Riscos

| # | risco | sintoma se der errado |
|---|---|---|
| 1 | **Contorno em cima de voxel** | o personagem já é todo quina; contorno em toda aresta interna vira ruído em vez de desenho. Mitigação: limiar por ÂNGULO de normal, não por aresta |
| 2 | **Glow no chão claro** | chão quase branco com glow de limiar baixo vira uma mancha leitosa. Mitigação: limiar acima de 1.0 e baixar o chão primeiro (Fase 1, item 3) |
| 3 | **Custo em celular** | contorno é um passe de tela cheia; banda multiplica shader por objeto. `GameFlow.device` já existe — o plano nasce escalado, não adaptado depois |
| 4 | **A Fase 1 parecer pior sozinha** | tirar SSAO e baixar ambiente sem banda/contorno deixa a cena dura. É a transição declarada do §3 |
| 5 | **Refatoração dos 94 pontos escapar** | um objeto esquecido fica realista no meio do cel e chama mais atenção que se nada tivesse mudado. Mitigação: o teste de varredura da Fase 3 |
| 6 | **Julgar por captura estática** | cel e contorno se decidem em MOVIMENTO (cintilação de linha, banda pulsando na sombra). Portão de captura não substitui jogar |

---

## 7. Mais sugestões — o catálogo, com custo e motivo

Levantadas depois do plano base, a pedido do dono. Ordenadas por **retorno por
hora**, não por vontade. Cada uma diz de que fase depende.

### 7.1 As quatro baratas que mudam mais

#### a) Céu com nuvens estilizadas — *provavelmente o maior ganho de identidade do plano*

O céu hoje é um `ProceduralSkyMaterial`: um degradê azul limpo, e nada mais.
One Piece **é** céu — cúmulos enormes, brancos, de borda dura, sobre azul
saturado. Um shader de céu com nuvens chapadas (ruído em degraus, que é
exatamente a mesma matemática da banda de luz do cel) muda **todo quadro do
jogo**, inclusive os que não têm nada acontecendo.

Custo: **um shader, zero geometria, zero mudança de material**. Não depende de
fase nenhuma — pode entrar junto com a Fase 1.

#### b) Luz de contorno (*rim light*)

Uma linha de luz na borda do personagem, vinda de trás. É metade do que faz um
personagem de anime "descolar" do fundo — e aqui **não é decoração, é função**:
numa arena PvP você precisa achar o adversário em um quadro.

Custo: ~5 linhas dentro do shader de cel (Fase 3). Antes disso, dá para
aproximar com uma segunda `DirectionalLight3D` de trás, na Fase 1.

#### c) ⚠️ O BURACO PRECISA LER COMO BURACO

O mapa é uma **grade com buracos quadrados**, e cair (`VOID_Y = −40`) é a
principal forma de morrer — o próprio `Melee.gd` diz "quem mata é o buraco, não
o dano". **E o buraco hoje não é desenhado.** É só ausência de malha: você olha
para baixo e vê o céu do outro lado.

O jogador precisa ver **perigo** ali. Três camadas, todas baratas:

1. névoa de altura escura dentro do poço (o mesmo sistema da Fase 1, só que
   por altura);
2. borda da plataforma marcada — com contorno (Fase 2) isso sai quase de graça;
3. um plano escuro bem abaixo, para o poço ter fundo visual sem ter fundo de
   colisão.

Isto é **comunicação de regra**, não enfeite. Está listado aqui porque é o item
de maior impacto em JOGABILIDADE de toda a lista visual.

#### d) Paleta declarada, num arquivo só

As cores nascem espalhadas em 34 arquivos. O projeto **já sabe** que isso é
problema: o `GoroFX.gd` tem uma "REGRA DE OURO DA PALETA" escrita à mão porque
a nuvem clarear faria o raio sumir dentro dela.

Uma paleta central — o que `Balance.gd` é para dano — dá harmonia e um lugar só
para retocar o jogo inteiro. **Ela não substitui as paletas por fruta**: cada
fruta continua dona do seu contraste interno; a paleta global cuida do MUNDO
(chão, blocos, céu, névoa) e das cores de leitura (jogador, inimigo, perigo).

### 7.2 Custo médio, retorno alto

#### e) Linguagem de impacto de mangá — **três peças que já existem**

Não precisa de tecnologia nova. Precisa de ligação:

| peça | estado hoje |
|---|---|
| `ProceduralAnimator.trigger_hitstop()` | **existe e ninguém chama do lado de quem bate** (é o bug B6 do plano de combate) |
| `ScreenFX.set_speed_lines()` | existe, usado só no sprint |
| `ScreenFX.flash()` | existe, usado só ao levar dano |

Anime de luta é: **congela o quadro do impacto, estoura linhas radiais a partir
do ponto de contato, dá um flash de forma.** As três peças estão prontas e
desligadas. Some-se a isso o "quadro de contato congelado" que os quatro M1
novos já trazem (§6.3 do plano de combate) e o golpe passa a ter pontuação.

Custo: ligação e calibragem. Depende da Fase 1 só para o flash não estourar.

#### f) Leitura de jogador na arena

Personagens são azul e vermelho chapados. Com contorno (Fase 2) entra de graça
uma alavanca forte: **cor e espessura de contorno por jogador** — você, o
adversário, o boneco de treino. Num jogo em que o combo trava por 1,9 s, saber
instantaneamente quem é quem vale mais que qualquer textura.

#### g) Vento na vegetação

As árvores voxel estão paradas. Um deslocamento de vértice por ruído no shader
(só nas folhas, nunca no tronco) custa pouco e tira o mundo do congelamento.
Depende da fábrica de material (Fase 3).

### 7.3 Baratas, para o fim

- **Color grading por LUT** — uma textura unifica o look inteiro e dá um botão
  só para "mais quente/mais frio". Entra depois que o cel estabilizar, senão
  você calibra duas vezes.
- **Partículas de ambiente** (poeira/pólen pegando o sol) — dá volume ao ar e
  escala ao mundo. Um `GPUParticles3D` preso à câmera.
- **Anti-aliasing**: hoje `msaa_3d = 1` (2×). Com contorno, subir para 4× no PC.

### 7.4 ⚠️ O que NÃO fazer — e por quê

Vale escrever, porque são coisas que parecem melhoria e brigam com o alvo:

| não fazer | por quê |
|---|---|
| **TAA** | borra e faz cintilar exatamente a linha do contorno. Cel quer **MSAA** |
| **Depth of field** | num jogo de luta rápido o jogador precisa ler o fundo; DOF esconde o adversário |
| **Névoa volumétrica pesada** | bonita e cara; `GameFlow.device` inclui celular. Névoa de profundidade dá o mesmo em cel |
| **Glow com limiar baixo** | o chão é quase branco: limiar baixo transforma a tela em leite. Limiar **acima de 1.0**, e só o emissivo brilha |
| **SSR / reflexos** | caro, e reflexo especular é o oposto da linguagem chapada |
| **Contorno em toda aresta** | o personagem é voxel, ou seja só quina. Contorno por ÂNGULO de normal, não por aresta (risco 1) |

### 7.5 A ferramenta que falta: capturas comparáveis

Todo o resto deste plano se julga com o olho, e olho não lembra. O projeto já
tem `tools/dev_tests/captura_*.gd`.

**Sugestão:** `captura_visual.gd`, que sobe o jogo e salva SEMPRE as mesmas
cinco cenas (mundo aberto, borda de buraco, personagem perto, um golpe
emissivo, o céu). Rodada antes e depois de cada fase, ela vira o portão do plano
inteiro — e é o que impede "eu acho que melhorou".

Vale junto uma medida objetiva por captura: **histograma**. Hoje o chão está
colado no branco; depois da Fase 1 ele tem que sair do topo, e isso é um número,
não uma opinião.

---

## 8. O que este plano NÃO cobre

- **Câmera e impacto** (o "Dynamic Camera & Impact Feedback System" que já está
  na fila) — é game feel, não estilo de render. Anda em paralelo.
- **Modelagem** dos personagens e do cenário. Cel-shading não conserta forma.
- **As animações.** Os quatro M1 acabaram de ser refeitos; os 7 clipes com o
  tronco tombado listados em [`ESQUELETO.md`](ESQUELETO.md) continuam abertos.
