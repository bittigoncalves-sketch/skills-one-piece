# Goro Goro no Mi — trovão

**Id:** `goro_goro` · **Tipo:** Logia · **Passiva declarada:** Sobrecarga
Voltáica — só `speed_mod 1,15` / `jump_mod 1,10` estão implementados (o
*volt meter* de 0 a 100 não existe no código).

É a fruta mais trabalhada em VFX do projeto, e a **primeira a ganhar
charge-up** — a mecânica que o X da Gura Gura e, depois, o V da Mera Mera
reaproveitam.

---

## Arte e identidade — padrão Ope desde 2026-09-12

Fase 1 de trazer a Goro ao nível da Ope (`~/.claude/NIVEL_OPE.md`): a régua
é de **qualidade e autoria**, não de estética. A Ope é um coração carmesim com
espirais curvas; a mesma exigência aqui produziu outra coisa.

| artefato | arquivo |
|---|---|
| modelo autoral da fruta | `assets/models/goro_goro/goro_goro_fruit.glb` |
| **fonte reproduzível** | `tools/blender/goro_goro_assets.py` |
| nó de coleta próprio | `src/world/GoroFruitPickup.gd` |
| ícones dos 4 slots | `assets/ui/goro_goro/{sango,elthor,shunshin,mamaragan}.svg` |
| **áudio autoral** | `assets/audio/goro_{sango,elthor,shunshin,mamaragan,carga}.wav` |
| **fonte do áudio** | `tools/generate_goro_audio.py` · reprodutor `src/effects/GoroAudio.gd` |
| revisão no jogo | `./jogar_goro.sh` · capturas com `./jogar_goro.sh -- --capture` |

**A fruta.** Bulbo de tambor com 12 gomos verticais, casca ouro-âmbar, pedúnculo
enrolado. As espirais assinatura das Akuma no Mi são desenhadas em **zigue-zague**
— o traço do raio — em relevo da mesma família de cor, como na Ope. Medidas:
**33.860 triângulos**, 6 materiais, 0,81 × 0,81 × 1,15 m (a Ope tem 45.108).

### ⚠️ A cor foi compensada para a luz da arena

Este é o erro que custou duas rodadas de captura e que vale para **qualquer
asset novo deste projeto**: a luz azulada do céu da arena empurra a razão
verde/vermelho em cerca de **+0,15**.

| | G/R no material (sRGB) | G/R medido na tela |
|---|---:|---:|
| 1ª tentativa | 0,79 | **0,88 – 0,95** → lia como verde-oliva |
| versão entregue | 0,52 | **0,68 – 0,73** → lê como ouro |
| Ope (referência no mesmo quadro) | — | 0,21 – 0,25 |

Por isso o material sai do Blender **mais alaranjado do que parece certo lá**, e
`fruit_preview.png` mostra a fruta mais salmã do que ela aparece no jogo: aquele
render serve para conferir **geometria**. A cor que vale é a das capturas em
`multimodal/cache/goro-validation/captures/`. Conferir sempre no jogo.

### O áudio — fase 2, 2026-09-12

Cinco sons sintetizados por script (biblioteca padrão, sem amostra baixada),
mono 48 kHz/16 bits, pico **−3,1 dBFS** — a mesma régua da Ope.

**A regra de som é a mesma regra de ouro da paleta: CONTRASTE entre duas camadas
que não se misturam.** Estalo agudo e seco (o raio, que chega primeiro) contra
trovão grave e longo (a nuvem, que chega depois). Só agudo fica fino, só grave
fica surdo; o grave **atrasado** em relação ao agudo é o que o ouvido lê como
"raio caiu longe" — e desde a remodelação o X e o V acontecem mesmo longe.

Medido nos arquivos gerados, não estimado:

| arquivo | grave | agudo | ataque | papel |
|---|---:|---:|---:|---|
| `goro_sango` | 15,5% | 84,5% | 7,8 ms | Z: feixe seco e imediato |
| `goro_elthor` | 82,4% | 17,6% | 6,5 ms | X: estalo + trovão rolando |
| `goro_shunshin` | 1,0% | 99,0% | 5,1 ms | C: dois zaps, o vazio entre eles é o golpe |
| `goro_mamaragan` | 83,7% | 16,3% | **384 ms** | V: assobio da queda → impacto → trovão |
| `goro_carga` | 27,8% | 72,2% | 1249 ms | a bola crescendo nas nuvens |

⚠️ **O `mamaragan` é sincronizado, não tocado no início da queda.** O impacto
dele está em 384 ms do arquivo, e a queda leva ~600 ms: disparado ao sair da
nuvem, o estalo chegaria ~0,2 s antes da batida. A bola toca o som quando falta
exatamente `SOM_ANTES_DO_IMPACTO` para o chão.

⚠️ **O `GoroAudio` não substitui o `AudioFX`, soma-se a ele.** `snap`, `cannon`
e `whoosh` continuam onde estavam — são a camada genérica que todo golpe tem.

### Os shaders — fase 3, 2026-09-12

Dois shaders dedicados, no molde dos dois da Ope (`ope_room` + `ope_floor`).

**`goro_storm.gdshader` — a nuvem.** Antes cada "puff" era uma esfera de cor
chapada (`StandardMaterial3D` unshaded): de longe a nuvem virava uma mancha
plana, e o clarão de relâmpago era só uma luz **externa** piscando ao lado dela.
Agora a densidade responde ao ângulo de visão — o inverso do rim da `ope_room`,
porque lá o campo é uma casca de vidro e aqui é massa — e o relâmpago **acende
por dentro**, em instante pseudo-aleatório (piscar em cadência regular denuncia
o truque na hora).

**A regra de ouro da paleta continua valendo:** a nuvem é escura e **não** usa
blend aditivo. O flash interno nunca clareia a nuvem inteira, senão o raio
amarelo perde onde aparecer.

**`goro_marca.gdshader` — o aviso no chão.** Antes era um `TorusMesh` com
`volt_material`: marcava o lugar e não dizia **nada sobre o tempo**. Agora tem
aro, raias radiais de mira de artilharia e um pulso que corre para dentro
**acelerando conforme a carga** — quem está embaixo lê a urgência sem olhar o
HUD de quem conjurou. Roda num `PlaneMesh` de 2 triângulos, onde o torus pagava
centenas.

As nuvens também recebem `charge`: piscam mais rápido conforme a bola enche.

⚠️ **`storm_cloud` agora devolve `ShaderMaterial`, não `StandardMaterial3D`.**
Quem dissipa nuvem tem de animar `shader_parameter/presence` — use
`GoroFX.dissipar_material()`, que trata os dois tipos. O código antigo fazia
`if m is StandardMaterial3D: tween(...)`, e com o tipo novo a condição
simplesmente não casava: **nenhum erro, e a nuvem ficaria pendurada no céu**.
O El Thor usa a mesma oficina e foi corrigido junto.

**Custo medido** (arena real, 2 s de amostra antes e durante o golpe):
média 6,93 → 6,94 ms, p95 7,74 → 7,57 ms. Delta **+0,00 ms** — indistinguível
do ruído. ⚠️ Medido numa sessão sem display nativo (o Wayland falhou e o Godot
caiu no plano B), então o custo de GPU pode estar sub-representado; refazer numa
sessão gráfica normal antes de tratar esse número como definitivo.

### A coreografia — fase 4, 2026-09-12

Cinco gestos autorais em `src/anim/GoroPoses.gd`, nos mesmos 13 papéis do rig
que a Ope usa. **A intenção:** o raio não é empurrado, é **chamado**. Onde a Ope
é um cirurgião (gesto contido, precisão), a Goro é um deus do trovão — o corpo
se abre, o braço aponta, e a energia vem de fora dele. Nenhum dos quatro "soca".
No lugar da respiração da Ope, a Goro **crepita**: um tremor de amplitude
minúscula e frequência alta, porque corpo com corrente passando não fica parado.

| gesto | duração | amplitude | pico | corpo |
|---|---:|---:|---:|---|
| `goro_sango` (Z) | 0,55 s | 83,2° | 3294 °/s | parcial |
| `el_thor` (X) | 1,60 s | 162,2° | 2132 °/s | **inteiro** |
| `goro_shunshin` (C) | 0,45 s | 68,7° | 1037 °/s | parcial |
| `mamaragan` (V, canaliza) | sustenta | 148,4° | 656 °/s | parcial |
| `mamaragan_solta` (V, derruba) | 0,50 s | 148,4° | 1602 °/s | parcial |

**Só o X domina o corpo inteiro**, porque é o único golpe da fruta que trava o
jogador. O V ficou de fora porque desde a remodelação ele é **canalizado
andando** — uma perna autorada brigaria com a corrida por baixo. As poses
parciais escrevem perna em zero, e o teste verifica isso.

**O teto de velocidade saiu de medir a Ope**, não de um palpite: `ope_room`
1052 °/s, `ope_shambles` 1931, `ope_takt` 835 e `ope_gamma` 3250 — o pico dela,
no golpe decisivo. Todos os cinco gestos da Goro cabem nesse envelope.

⚠️ **`goro_pose_t` se REMOVE, não se zera.** O animador prefere o valor da meta
quando ela existe; publicá-la em 0,0 e não atualizar congela a pose no primeiro
quadro — o braço do El Thor nem chegava a subir, e só a captura no jogo mostrou.
Só o V publica esse relógio, porque a carga dele não tem duração prevista, e ele
**remove a meta ao morrer**: deixá-la parada faria o próximo golpe da fruta
nascer com o relógio velho.

### O que ainda NÃO foi entregue

Declarado em voz alta, como manda a régua: o **validador de um comando**
(`tools/validate_goro.py` não existe — a prova hoje é o `test_goro_poses.gd`
mais o conjunto de capturas de `./jogar_goro.sh -- --capture`). Os VFX do Z, X e
C não foram tocados; só o V foi remodelado.

**O que os números NÃO provam.** `test_goro_poses.gd` lê o EULER de cada papel,
não a direção do membro no mundo: medido na arena, `UpperArm_R.x = 172°` ergue o
braço em **diagonal** acima da cabeça, não na vertical. Quem julga direção é a
captura, não a asserção.

**Nunca foi ouvido em execução:** o áudio (ver a seção da fase 2).

**Nunca foi ouvido em execução:** o áudio. Os `.wav` foram medidos como arquivo
e carregam como `AudioStream` no Godot, mas as sessões de captura rodaram sem
display nem saída de som, e `GoroAudio.play` retorna cedo em headless por
desenho. É a primeira coisa a conferir ao abrir `./jogar_goro.sh` de verdade.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/GoroFX.gd` | a **paleta**, a oficina de raios (`bolt_fill`, `volt_material`, `storm_cloud`, `shock_ring`) e os golpes do dia a dia (Z, C) |
| `src/effects/GoroFXGrande.gd` | os dois espetáculos: **X (El Thor)** e **V (Mamaragan)** |
| `src/player/cast_controller.gd:68,173-174,183-232` | o gatilho do X no aperto e o charge-up do V |
| `src/combat/Balance.gd` | **todo o dano** dos quatro slots (a tabela única, desde 2026-08-21) |
| `SkillSystem.gd:61-66` | **só nome e cor** dos 4 slots — nenhum número de dano |
| `src/world/GoroFruitPickup.gd` | o nó da fruta no mundo (modelo autoral, giro e flutuação) |
| `src/ui/SkillBar.gd` | `GORO_ICONS` + `ICONES_POR_FRUTA`: os ícones dos slots no HUD |
| `src/effects/GoroAudio.gd` | a voz sonora da fruta (5 cues, volume e alcance por cue) |
| `src/fx/shaders/goro_storm.gdshader` | a nuvem com volume e o relâmpago que acende POR DENTRO |
| `src/fx/shaders/goro_marca.gdshader` | a marca de aviso no chão, cujo pulso acelera com a carga |
| `src/anim/GoroPoses.gd` | a **coreografia** dos quatro golpes, nos 13 papéis do rig |
| `tools/dev_tests/test_goro_poses.gd` | mede a coreografia: amplitude, velocidade, pernas, retorno ao repouso |

**Por que dois arquivos.** Os espetáculos são blocos grandes que não participam
do combate normal, e o projeto tem teto de 900 linhas por script
([`../LIMITE_DE_TAMANHO.md`](../LIMITE_DE_TAMANHO.md)). A **oficina fica no
`GoroFX`** e é chamada de lá: duplicá-la criaria duas fontes de verdade para a
paleta do trovão.

### ⚠️ Regra de ouro da paleta

A **nuvem** e a **bola** são azul-escuras; o **raio** é amarelo-branco. O efeito
é o contraste. Por isso as nuvens **não** usam blend aditivo (aditivo sobre
escuro = nada): são alpha opaco, sem emissão. Só o raio é aditivo/emissivo. Se a
nuvem clarear, o raio some dentro dela.

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Sango | feixe elétrico à frente | dano **84** · kb 14 · `fwd × 32` · vida 1,1 s · raio 1,0 |
| **X** | El Thor | nuvem de raio 9,5 m, **11 raios** que caem em 4,2 s e a coluna final | raios: **64** cada, **`paralisa = 1,2 s`** (kb 0), raio 2,8, vida 0,22 s · coluna: **128** (`partes.coluna`), kb 22, raio 3,5, vida 3,2 s · **teto 256** |
| **C** | Shunshin | teleporte-raio curto | dano **200** · kb 10 · `fwd × 25` · vida 0,6 s · raio 1,2 |
| **V** | Mamaragan | **carregável, cai de cima**: as nuvens se juntam sobre o ponto de mira, a bola cresce lá em cima e despenca ao soltar (remodelado em 2026-09-12) | bola em voo: **256** (`partes.orbe`), kb 26, raio 2,6 · detonação: **512 → 768** conforme a carga, kb 30, **raio 12**, vida 0,5 s · **teto 768** |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

**Sobre os números do X.** Os 11 raios eram `damage × 0,35` e a coluna levava o
"dano cheio" — duas frações escritas dentro do `GoroFXGrande`. Hoje cada raio
vale um acerto MULTI inteiro (64) e a coluna vale o dobro de um raio, por
`partes.coluna`; quem limita o total é o teto de 256 do slot X, não uma fração
escondida no arquivo de partículas. Consequência de leitura: **quatro raios já
gastam o orçamento inteiro**, e os sete seguintes mais a coluna continuam
paralisando, empurrando e arremessando sem tirar vida. O teto corta o dano, não
o acerto — e neste golpe o que mata é a coluna jogar o alvo para fora do mapa.

### O X tem um gatilho separado do golpe

`CastController.comecar()` chama `GoroFXGrande.gatilho_do_braco()` **no aperto**,
antes de qualquer outra coisa. Pedido do dono: *"a parte inicial do raio indo
para cima é ativada mesmo se o jogador continuar segurando a skill, visto que não
é a parte do ataque e sim uma mecânica para iniciar a reação"*. A origem é o
**`ForeArm_R` do rig**; sem rig na árvore, cai no peito.

### Os raios do X PARALISAM; só a coluna empurra

`zona.paralisa = 1,2` (`GoroFXGrande.gd:295`) troca knockback por `is_frozen` +
`StatusFX.CONGELADO` — o mesmo sinal que o gelo já usa e que o
`_etapa_travamento` do `Player` já respeita.

**Por quê:** empurrar nos raios iniciais espalhava o alvo para fora da área
antes de a coluna chegar. **O golpe se sabotava.** É o único uso do campo
`paralisa` da `DamageZone` no projeto inteiro.

### O V: a bola em voo e a detonação dividem UM orçamento

As duas hitboxes do Mamaragan nascem do mesmo aperto de tecla e carregam o mesmo
`cast_id`, então o teto de **768** do slot V vale para a soma. Quem for atingido
pela **bola em voo** leva os 256 de `partes.orbe` e, na detonação, só os 512 que
sobram do orçamento — mesmo com carga cheia. Acertar com as duas partes **não**
dobra o golpe; o que a bola em voo compra é o dano garantido de quem for
atropelado no caminho, e o empurrão dela (kb 26) continua valendo inteiro
mesmo depois do teto.

### O V cai de cima — remodelação de 2026-09-12

**Antes:** as nuvens se juntavam sobre o JOGADOR, ele flutuava 3,4 m preso no ar,
a bola crescia entre as mãos e era **arremessada na horizontal** a 27 m/s até
bater em alguma coisa.

**Agora:** é artilharia vertical. Ele aponta, a tempestade se junta **sobre o
ponto de mira**, a bola cresce dentro das nuvens e **cai**. O jogador fica livre
o tempo todo — não flutua e não trava.

| | antes | agora |
|---|---|---|
| onde as nuvens nascem | sobre o jogador | sobre o **ponto de mira** (raycast até 60 m, o mesmo do El Thor) |
| anel de nuvens | raio 12 m | raio 7 m, concentrado no alvo |
| trajetória | horizontal, 27 m/s constante | **queda vertical**, 9 → 62 m/s acelerando |
| jogador | flutuando e travado | **livre** |
| aviso ao alvo | nenhum | **marca no chão** durante toda a carga |
| duração total | 5,40 s | 4,60 s |

**A mira é seguida enquanto carrega** (`_seguir_mira`). Sem isso o alvo
congelaria no aperto, mas a soltura manda para a rede a mira do instante da
LIBERAÇÃO — as nuvens carregariam num lugar e a bola cairia em outro. Depois de
soltar o alvo trava: quem está embaixo não pode fugir junto com a mira.

**A marca no chão é o contra-jogo.** Um golpe que cai de cima sem anunciar onde
não dá chance a ninguém; o anel fica visível os ~2,3 s da carga, que é o tempo
de sair. Ela **não** usa `GoroFX.shock_ring`: aquele anel nasce para sumir, e
`grossura = 0.0` ainda degenera o `TorusMesh` e suja o log.

**A bola morre no chão do ALVO** (`y_do_alvo`), não numa altura fixa do mapa —
senão o golpe atravessaria plataformas altas.

⚠️ **`lock_movement` foi removido deste golpe.** Se voltar a aparecer aqui,
devolve o custo que a remodelação tirou de propósito.

### O charge-up do V

Linha do tempo em `MamaraganController`: `T_CARGA = 2,30 s` para a bola ficar
completa (raio 0,30 → 2,30), `T_LANCA = 3,30`, `TOTAL = 5,40`. Segurando, a
linha do tempo **congela** em `T_LANCA` e a bola espera o dedo.

⚠️ **Duas escalas de tempo, e elas não são a mesma.** O visual da bola usa
`T_CARGA = 2,30 s`; o DANO usa o `tempo_de_carga = 3,0 s` da tabela. O código
concilia as duas convertendo a carga visual, que é uma fração de 0 a 1, para os
segundos que o `DamageSpec` espera:
`spec.valor_do_hit(carga_atual() * spec.tempo_de_carga)`
(`GoroFXGrande.gd:826-828`). Ou seja: **bola visualmente cheia = dano máximo**,
independente do número de segundos — mas quem mexer em qualquer um dos dois
números precisa saber que existe essa ponte.

Até 2026-08-21 o Mamaragan tinha uma **máquina de estados própria** para o
dano da carga, a terceira curva diferente do jogo (as outras eram
`1 + carga/1,5` da Gura e `1 + carga/3,0` da Mera). Hoje as três skills
carregáveis usam a mesma reta de `dano` a `dano_max` (`DamageSpec.valor_do_hit`),
e a faixa mora na tabela: **512 → 768**.

Três regras que separam o charge-up de todo o resto do jogo:

- a execução 3D começa **no clique**, não na soltura;
- soltar dispara com a carga que houver, na mira **daquele instante**;
- **levar dano dispara** em vez de cancelar (`CastController.liberar_por_dano()`
  roda **antes** do `SkillSystem.interrupt_casting` em `take_damage`).

Soltar cedo **libera o jogador na hora** (`_liberar_jogador()`): antes o
travamento era armado para a duração cheia e quem soltava em 1 s ficava
flutuando até o prazo original vencer.

Coberto por `tools/dev_tests/test_charge_up.gd` (9 checagens).

---

## Pendências

- A recarga real do V é **25 s** (`Player.RECARGA_POR_SLOT`), não os 60 s que a
  tabela do `SkillSystem` ainda declara — item 33 da lista. O motivo do 25:
  com 60 s o ultimate saía uma vez por rodada e testar exigia esperar um minuto
  por tentativa.
- O *volt meter* da passiva não existe. Se for implementado, o lugar é a
  `FruitPassiveSystem` (que hoje só entrega dois multiplicadores).

Histórico completo da repaginação: [`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md),
tarefa 5.
