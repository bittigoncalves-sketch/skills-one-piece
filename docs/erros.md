# Registro de Erros — Skills One Piece

Todo erro encontrado no projeto, com o **motivo** de ter acontecido. Mantido pela
skill `registrar-erro`. Entradas mais recentes no topo.

O objetivo aqui não é o conserto — é a **causa**. Erro sem causa documentada volta.

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
