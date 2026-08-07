# Registro de Erros — Skills One Piece

Todo erro encontrado no projeto, com o **motivo** de ter acontecido. Mantido pela
skill `registrar-erro`. Entradas mais recentes no topo.

O objetivo aqui não é o conserto — é a **causa**. Erro sem causa documentada volta.

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
