# Guia do Projeto — leia isto antes de escrever qualquer linha

> **Este é o primeiro documento que qualquer pessoa ou IA deve ler neste
> repositório.** Ele existe porque o projeto é editado por **mais de uma IA**
> (Claude e Gemini, às vezes ao mesmo tempo) e por agentes que começam frios.
> Quem não conhece as armadilhas desta base escreve código competente que
> quebra em silêncio — foi o que aconteceu com a Gura Gura no Mi, implementada
> sem revisão e auditada depois com **~12 defeitos** ([`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md),
> itens 31–42).

**SKILLS ONE PIECE** — jogo de ação 3D em **Godot 4.6.3**, GDScript,
cliente-servidor com ENet e servidor-autoritário. Arena PvP com frutas do
diabo, estilos de luta e parkour.

---

## O guia em cinco páginas

Este arquivo é a **porta de entrada**: as regras que valem sempre e o caminho
para o resto. O conteúdo detalhado está dividido em arquivos filhos, pelo mesmo
motivo que a [`frutas/`](frutas/README.md) foi dividida por fruta — documento
gigante ninguém lê, e documento com dois donos desatualiza em silêncio.

| arquivo | quando abrir |
|---|---|
| [`guia/ONDE_COLOCAR.md`](guia/ONDE_COLOCAR.md) | "vou criar um arquivo — onde ele mora?" Pasta a pasta, o que entra e o que **não** entra |
| [`guia/COMO_ESCREVER_SCRIPT.md`](guia/COMO_ESCREVER_SCRIPT.md) | antes de escrever GDScript aqui: teto de 900 linhas, comentário de *porquê*, fonte única, autoridade de servidor |
| [`guia/ARMADILHAS.md`](guia/ARMADILHAS.md) | **a página mais valiosa.** Cada armadilha desta base com sintoma, causa e como evitar — todas com origem rastreável |
| [`guia/ASSETS_VISUAIS.md`](guia/ASSETS_VISUAIS.md) | VFX, malha, partícula, cor por fruta, limpeza de nó |
| [`guia/COMO_TRABALHAR.md`](guia/COMO_TRABALHAR.md) | processo: divisão em agentes, série vs. paralelo, o que fazer com bug fora de escopo, como validar |

---

## As seis regras que não se negociam

Se você só ler esta seção, leia esta seção.

1. **`class_name` novo exige `--editor --quit`.** Sem isso o script que o usa
   falha em SILÊNCIO e o jogo abre em **tela cinza**. Existe `./checar_cache.sh`
   para isso, e o `jogar.sh` já o chama. Detalhe em
   [`guia/ARMADILHAS.md`](guia/ARMADILHAS.md#1-class_name-novo--tela-cinza).
2. **`--editor --quit` NÃO prova que o código compila.** Quem prova é
   `godot --headless --path . --script tools/dev_tests/test_compila.gd`.
3. **Nunca posicione um nó antes de ele entrar na árvore.** `add_child` primeiro,
   `global_position`/`look_at` depois. Três ocorrências já custaram caro (itens
   21, 31 e 40 da lista) — é padrão, não coincidência.
4. **Dano é autoridade do SERVIDOR, e passa pela `DamageZone`.** VFX roda em
   todo mundo; dano, só no servidor. `MultiplayerSynchronizer` **não** serve
   para vida (item 20).
5. **Nenhum script passa de 900 linhas** ([`LIMITE_DE_TAMANHO.md`](LIMITE_DE_TAMANHO.md)).
   Passou, divide. Adiar a divisão exige declarar o **gatilho** que obriga a
   revisitar.
6. **Validar com número, não com adjetivo.** `./validar.sh rapido` é o portão.
   "Melhorou" não fecha tarefa; "6/6 acertos, 0 nós vazados" fecha.

---

## Os 10 minutos de contexto

### Rodar

```bash
./jogar.sh          # abre o jogo (chama checar_cache.sh sozinho)
./servidor.sh       # servidor dedicado headless
./validar.sh rapido # a bateria (25 testes em tools/dev_tests/test_*.gd)
```

O Godot **não está no PATH**. Use `./find_godot.sh` (é o que os scripts fazem)
ou o caminho direto: `/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64`.
O Blender (5.2, usado só no pipeline de animação) está em
`/home/gabriel-bitti/opt/blender/blender`.

### A forma do jogo

- **Cena inicial** `MainMenu.tscn`; o mundo é montado por código em `Main.gd`
  (`WorldEnv` + `MapBuilder` + `TreeScatter`), não por uma cena grande no editor.
- **Singleplayer roda o mesmo código do multiplayer**, com um servidor local na
  porta fixa **24565**.
- **Arena:** grade de lajes de 10 m com 16 buracos. Rodada de 10 min. **Quem
  mata é a queda**, não o atrito de vida — por isso `DamageZone.DAMAGE_SCALE =
  0.12` e o foco de todo golpe é knockback.
- **Vida 2048 / energia 4096.** Uma skill custa `ENERGY_SKILL = 180`.
- **Dois modos de combate** (tecla R): fruta (`current_fruit_id`) e estilo de
  luta (`FightingStyles.STYLES`).
- **Rig único de 13 papéis** para todos os personagens:
  `Torso, Neck, Head, UpperArm_L/R, ForeArm_L/R, Thigh_L/R, Shin_L/R, Foot_L/R`.
  Nos voxel são nós; nos skinnados o `SkeletonDriver` cria proxies com os mesmos
  nomes.
- **Convenção global: FRENTE = −Z.** Logo, direita anatômica = **+X** no espaço
  local do modelo.

### O caminho de um golpe, do dedo à hitbox

```
tecla (Z/X/C/V)
  → Player.begin_charge / release_charge          (casca)
  → CastController.comecar / soltar               DECIDE: recarga, energia,
                                                  supressão, casos por fruta
  → Player.pedir_cast_no_servidor(slot, aim, origem, charge)
  → RPC _net_cast  →  SERVIDOR: _do_server_cast
  → RPC _net_play_cast (call_local, todos os peers)
  → Player._fire_skill  →  <Fruta>FX.cast(world, origin, aim, variant, dano, self)
```

Duas consequências que explicam quase todo bug de fruta:

1. **Efeito bonito no cliente não é prova de que o golpe machuca** — a
   `DamageZone` sai cedo quando não é servidor.
2. **`_fire_skill` não devolve nada e engole quase tudo** — um golpe pode
   "rodar" sem criar hitbox nenhuma. Três frutas passaram meses disparando os
   golpes da Gomu Gomu sem ninguém perceber.

Fonte completa: [`frutas/README.md`](frutas/README.md).

---

## Antes de dizer "pronto" — a lista de conferência

- [ ] `godot --headless --path . --script tools/dev_tests/test_compila.gd` → 0 falhas
- [ ] `./validar.sh rapido` verde (ou a falha explicada, com log)
- [ ] criou `class_name`? rodou `./checar_cache.sh` (ou `--editor --quit`)
- [ ] mexeu em golpe de fruta? `test_frutas.gd` do slot afetado, e o arquivo
      correspondente em [`frutas/`](frutas/README.md) atualizado **na mesma tarefa**
- [ ] criou nó de VFX? provou que ele morre (critério do `test_gomu_leak`:
      a contagem volta à base, e não cresce em 5 repetições)
- [ ] nenhum arquivo passou de 900 linhas — ou o gatilho está declarado no topo dele
- [ ] achou bug fora do escopo? virou item em [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md)
      **com como foi detectado** — não foi consertado por conta própria
- [ ] as suposições que você teve que fazer estão **declaradas** no relatório

---

## O mapa dos outros documentos

Este guia diz **como construir**. Os outros dizem **o que existe**:

| pergunta | documento |
|---|---|
| como esta fruta funciona hoje? | [`frutas/README.md`](frutas/README.md) → uma página por fruta |
| que bugs conhecidos estão abertos? | [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) |
| por que este bug aconteceu? | [`erros.md`](erros.md) |
| como o `Player.gd` está sendo partido? | [`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md) |
| como se divide trabalho entre agentes? | [`AGENTES.md`](AGENTES.md) |
| o que a bateria de testes cobre e o que não cobre? | [`VALIDACAO.md`](VALIDACAO.md) |
| pipeline Mixamo → rig | [`ANIMACOES_MIXAMO.md`](ANIMACOES_MIXAMO.md) |
| o porquê de decisões antigas | `MUDANCAS_*.md`, `PEDIDO_*.md` — **nada ali é apagado** |

> ⚠️ **`DOCUMENTACAO.md`** (na raiz) é a visão geral **de 2026-08-02** e
> envelheceu em pontos concretos: descreve `src/effects/` com "17 arquivos"
> (hoje são 25), lista personagens que saíram do menu e não conhece nada da
> partição do `Player.gd` nem da arena. Use-o como panorama histórico; onde ele
> divergir deste guia, **este guia vale**.

---

## O contrato de quem pede e de quem faz

**Interprete cada pedido como vindo de um desenvolvedor de jogos gênio e
especialista.** O que chega é a **intenção**, não a especificação completa.

Isso tem duas metades, e as duas são obrigatórias:

- **entregue o que a intenção pede**, não a leitura literal mais barata. "Faça o
  Z virar tiros" no Karatê Tritão exigia primeiro descobrir que os quatro slots
  do estilo caíam no mesmo efeito — o pedido não mencionava isso e não dava para
  atender sem resolver ([`PEDIDO_2026-08-12.md`](PEDIDO_2026-08-12.md), tarefa 7);
- **declare as suposições.** Onde o pedido era ambíguo, alguém escolheu um
  número. O `JANELA_DE_COMBATE = 5 s` da regeneração de vida está marcado como
  **assumido** no documento, com a frase "é o primeiro número a calibrar". Isso
  é o padrão: escolha, diga que escolheu, e diga o que faria a escolha mudar.

E o inverso também vale: **"sempre perguntar"** é regra do dono. Pedido
ambíguo em coisa cara (mudar feel, apagar código que funciona, inverter uma
convenção) volta como pergunta, não como commit.
