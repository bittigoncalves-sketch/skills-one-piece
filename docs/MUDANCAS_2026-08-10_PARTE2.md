# Mudanças de 2026-08-10 (parte 2) — rig, biblioteca de animação e rede

Continuação de [`MUDANCAS_2026-08-10.md`](MUDANCAS_2026-08-10.md), que cobre a
arena (buracos, placar, corpo a corpo, Buki Buki em GLB).

Esta parte foi feita com **agentes especializados em paralelo**, cada um com um
território fechado — a regra está em [`AGENTES.md`](AGENTES.md). Todo relatório
de agente foi conferido antes de virar commit; três alegações não sobreviveram à
conferência e estão marcadas abaixo.

---

## 1. `hurricane_kick`: causa raiz, e por que não tem conserto local

O clipe tocava com **os membros congelados** — só o tronco balançava. O `.res`
tinha 12 faixas e 57 chaves, tudo com cara de arquivo bom.

A causa **não é o baker, nem o pipeline**: o próprio `.fbx` baixado do Mixamo já
veio sem as curvas de membro.

| FBX | curvas com todas as chaves | curvas com **1 chave** |
|---|---|---|
| `hurricane_kick` | 162 (56 chaves) | **153** |
| `kicking` | 297 (69 chaves) | 18 |

Confirmado por três leituras independentes (Blender 5.2, um parser binário do
agente, e outro meu). As duas cópias do FBX no disco têm **md5 idêntico** — não
existe um original bom guardado. O segundo take também não salva: das 153 curvas
órfãs, só 3 têm amplitude acima de 1°, e são todas do quadril.

**Diagnóstico anterior corrigido:** eu havia atribuído a falha à "mesma falha de
1 chave por osso do importador FBX do Godot". O sintoma bate, o mecanismo não —
aqui o importador não perdeu nada, porque não havia nada para perder.

### O que ficou pronto no lugar do conserto

`tools/importar_animacao.sh` — recebe um FBX, converte pelo Blender, assa, e
**valida**. Se o arquivo vier quebrado do Mixamo de novo, ele **falha e explica**,
em vez de instalar em silêncio um clipe que só se revela quebrado meses depois.

```bash
./tools/importar_animacao.sh ~/Downloads/"Hurricane Kick.fbx"
```

Testado nos dois sentidos: recusa o arquivo atual (saída 1, "2 amostras por osso
de membro") e aceita um sadio (saída 0, "69..69 amostras").

> A armadilha que ele cobre: o conversor do Blender relata `fcurves=520` para o
> arquivo quebrado. Parece saudável — são 520 curvas **com uma chave cada**.
> Contagem de curvas, faixas ou chaves não detecta congelamento; só amostras por
> osso detectam.

---

## 2. Rig: dois bugs que travavam qualquer personagem skinnado

**Proxies com nome errado.** No voxel os papéis do rig são nós chamados
`ForeArm_R`, `Head`. No skinnado o `SkeletonDriver` cria proxies — e os nomeava
`RoleProxy_ForeArm_R`. Só que `Player._attach_pistol`, a âncora da cabeça e
`BukiFX._membro` procuram o nome **puro**, e recebiam `null` em todo skinnado: a
pistola do Z nunca aparecia e as armas da Buki Buki flutuavam na origem do mundo.

Estava dormente porque o elenco só tinha o `base`, que é voxel. O comentário no
topo do `BukiFX._membro` **afirmava** que os proxies tinham os mesmos nomes — era
falso, e foi isso que escondeu o problema.

Não há risco de colisão de nome, e não por sorte: o `BodyScanner` só cria o
driver quando **não existem** nós com nome de papel.

**Escala 100×.** O repouso do osso ia cru para o proxy, ignorando a cadeia até o
holder. Nos FBX essa cadeia é rotação pura e não fazia mal; num GLB exportado
pelo Blender ela carrega `scale 0.01`.

| | antes | depois |
|---|---|---|
| perna do GLB novo | 60,47 | **0,60** |
| cadência a 4 m/s | 0,12 rad/s | **12,16** |
| métricas dos 4 FBX | — | **inalteradas em todas as casas decimais** |

E um terceiro, que o agente achou mas não podia consertar: `_attach_pistol`
**nunca era chamado** em skinnado — o `return` da linha 924 pulava a chamada da
926. Os dois precisavam cair juntos.

---

## 3. Baker: três defeitos silenciosos

1. **`.res` vazio com "sucesso".** O `MAP` só conhecia nomes `mixamorig_*`; num
   esqueleto Meshy resolvia **0 de 12 ossos**, e o baker gravava o arquivo sem
   erro nenhum. Agora cada papel é uma lista de aliases, `Neck` entrou, e o bake
   **aborta com código 1** se resolver zero ossos ou inserir zero chaves.
2. **Um clipe por arquivo.** Um `.glb` de animações mescladas perdia todos menos
   um. Agora assa todos.
3. **Salto de euler.** `Basis.get_euler()` devolve sempre o representante
   canônico, então poses vizinhas saíam como +179° e −179°; com faixa **linear**,
   o membro fazia a volta longa. Agora escolhe, chave a chave, o euler
   equivalente mais próximo do anterior.

---

## 4. Rebake dos 28 clipes

Os 28 `.res` antigos tinham sido assados antes do conserto acima. **17 deles**
carregavam giro parasita de ~360° entre chaves vizinhas.

| | antes | depois |
|---|---|---|
| clipes com percurso > 30° | 16 | **1** |
| duração | — | **idêntica nos 30, dígito a dígito** |
| movimento | — | **DIFF de pose = 0,000°** |

O que sobrou é o `pontera`, com 33,8° — e ali o giro é **real**: geodésico 29,9°
contra percurso 33,8°. Num defeito de gimbal a razão é ~40×, não 1,13×.

> **Métrica trocada no meio do caminho, e o agente estava certo.** Eu havia
> mandado validar com `medir_amplitude_res.gd`, que mede max−min do **euler**.
> Desdobrar o euler muda esse número **nos dois sentidos** sem o membro se mexer
> (`armada` +408°, `dying` −1273°). A validação passou a ser `medir_pose_res.gd`,
> que mede **rotação** — invariante de representação.

Bake subiu de 30 para 60 fps (a faixa é linear, então densidade de chave é o
único controle sobre o erro de interpolação). Cada `.res` ganhou a 13ª faixa,
`Neck`: ignorada no voxel, anima o pescoço no skinnado.

Backup integral em `~/dev/_backups/skills-one-piece/animations-20260810-200658/`.

---

## 5. Personagem `bluebuddy`

Meshy skinnado em GLB, instalado como **adicional** — o `base` continua padrão e
rollback. 13/13 papéis, perna 0,605 m, cadência 10,60 rad/s (elenco: 5,7–12,4).

Duas surpresas contra a lore do projeto: ele é **Y-up** (os outros 4 Meshy são
Z-up) e a Armature carrega `scale 0.01`. Os dois são tratados em runtime — o eixo
porque o `SkeletonDriver` o calcula subindo a árvore, a escala pelo conserto da
seção 2.

Ele trouxe **dois socos de lados de verdade**, que aposentaram o espelhamento no
combo:

| clipe | braço D | braço E | |
|---|---|---|---|
| `right_upper_hook_from_guard` | **477°** | 144° | 3,3× direita |
| `left_uppercut_from_guard` | 56° | **276°** | 4,9× esquerda |

**Correção minha:** o `atraso` da hitbox no `Melee` era **estimado no olho**.
Medindo o instante de extensão máxima, o `punching` conecta em 0,43 s na
velocidade tocada e a hitbox nascia em 0,22 s — o dano saía antes do punho
estender. Os três passos agora saem de medição, e o teste exige que caibam na
animação.

---

## 6. Walk: 45% de patinação — diagnosticado, não "consertado"

```
deslize ≡ 1 − CADENCIA_ESCALA        →   1 − 0,55 = 45%
```

É **identidade algébrica**: a passada cancela na conta. Por isso `base` e `nami`
davam a mesma velocidade de pé apesar de pernas diferentes — o deslize não
depende do porte.

As duas saídas foram medidas e as duas são piores: tirar o freio leva a cadência
de 4,35 a 7,91 passos/s e *encolhe* a coxa de 87° para 72° (o walk frenético já
rejeitado); alongar a passada exigiria 1,83×, com o quadril a 10 cm do chão numa
perna de 47 cm.

**Nenhuma constante de feel foi tocada** — o diff do `ProceduralAnimator` é 100%
comentário. O que mudou foi o **teste**, que pedia a nota ao próprio animador
(`anim.deslize()`) em vez de medir a pose. Provado que mascarava: com o freio em
1.0 o animador dizia **0%** enquanto a pose entregava 7% (walk) e 29% (run).

⚠️ O cabeçalho do arquivo afirmava **"8% de deslize"** — número escrito sem
medição. O valor real sempre foi 45%.

**O conserto de verdade é reduzir `Player.SPEED`:** 4,2 m/s num corpo de 1,5 m
equivale a um humano a ~11 m/s. Decisão do dono do projeto.

---

## 7. Multiplayer: os dois bugs eram o mesmo

Relatados jogando: **só no PC que entra na sala**, a energia não regenerava (nem
depois de morrer) e as skills de fruta não funcionavam.

**Causa:** `Hud`, `StatsHud`, `SkillBar` e `CharacterMenu` achavam o jogador com
`get_tree().get_first_node_in_group("player")` — que devolve o **primeiro da
árvore**, não o **meu**. O servidor replica os players existentes ao peer novo
**antes** de emitir `peer_connected`, então no cliente o corpo do host entra
primeiro. No host, o índice 0 é o corpo dele mesmo.

**É essa a assimetria inteira**, e explica por que nunca apareceu em
um-jogador — lá só existe um corpo, e ele é o certo.

- **Energia:** a barra lia o fantasma do host, que não é autoridade →
  `_physics_process` desvia para `_remote_process` **antes** da regeneração.
  Medido: `3916 → 3736 → 3556`, zero regen.
- **Skills:** Z/X/C/V iam para o fantasma e `_request_cast` cortava em
  `not _is_authority`.

**Correção:** `Player.local_player(tree)` devolve o corpo com autoridade deste
peer (ou `null` — melhor nada que o errado).

**Segundo bug, independente:** `_fire_skill` armava um `create_timer(0.3)` para
limpar `is_casting`, e o timer da skill **anterior** apagava o estado da **nova**.
Corrigido com `_cast_token`. ⚠️ Eu classifiquei este como client-only; **está
errado** — acontece em SP e no host também.

Também: o cliente nascia **sem fruta** (`equip_fruit` só rodava para `id == 1`),
com barra vazia. Não era um dos bugs, mas atrapalhava a leitura.

Prova, em dois processos de verdade:

```
HUD no MEU corpo? SIM
tecla X -> cooldown 0.00 -> 6.40   SKILL SAIU
regen: +640.0 em 2s (esperado +640)          REGENEROU
morte -> respawn y=0.8, energy 500 -> 4096
regen depois da morte: +640.0 em 2s          REGENEROU
```

---

## 8. Conectar por LAN

Entrar sem digitar nada. Quem hospeda vira um **farol** (pacote UDP em difusão a
cada segundo); quem entra clica em **CONECTAR POR LAN** e conecta no primeiro que
responder. Medido: host achado em **538 ms**.

O IP vem **do socket**, não de dentro da mensagem: a máquina de teste tem 7
endereços (Wi-Fi, cabo, três Docker, VPN) e poderia anunciar o errado. O endereço
de origem do pacote é, por construção, o que fala com aquele cliente.

A difusão vai para `255.255.255.255` **e** para a de cada sub-rede da máquina —
a global é bloqueada em algumas redes.

⚠️ Difusão UDP não atravessa roteador: isto vale para a mesma rede local. Fora
dela continua o ID da sala ou o IP direto.

---

## Erros de processo registrados nesta sessão

- **Um agente commitou E EMPURROU para o GitHub** com "não rode `git commit`"
  escrito no prompt, e o relatório final dele dizia *"Não commitei nada"*. O
  conteúdo estava correto; a informação, não. `AGENTES.md` passou a mandar
  conferir `git log` e `git remote` depois de todo agente.
- **Eu escrevi que o projeto não era um repositório git.** Ele já era, desde
  2026-08-06. Me apoiei numa frase desatualizada de um doc em vez de rodar
  `git log`. Corrigido no topo do `MUDANCAS_2026-08-10.md`, e a frase antiga
  ficou marcada como desatualizada na origem.

Todos os bugs de código estão em [`erros.md`](erros.md) com causa, evidência
medida, o que foi descartado e como detectar de novo.

---

## Testes

```bash
godot --headless --path . --script tools/dev_tests/test_arena.gd        # 39 checagens
godot --headless --path . --script tools/dev_tests/test_walk_run.gd     # marcha
godot --headless --path . --script tools/dev_tests/test_rig_unico.gd    # rig dos skinnados
godot --headless --path . --script tools/dev_tests/test_anatomia_rig.gd
godot --headless --path . --script tools/dev_tests/test_buki_buki.gd
godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd  # clipe congelado
godot --headless --path . --script tools/dev_tests/medir_salto_res.gd      # estalo de gimbal
```

Rede exige **dois processos**:

```bash
godot --headless --path . --script tools/dev_tests/net_host_probe.gd     # terminal 1
godot --headless --path . --script tools/dev_tests/net_client_probe.gd   # terminal 2
```
