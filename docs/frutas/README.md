# Akuma no Mi — índice

Uma pasta por assunto, **um arquivo por fruta**. Quem vai mexer numa fruta
amanhã abre **um** arquivo e sai sabendo o que cada tecla faz hoje, onde mora
cada parte e o que está quebrado nela.

> **O que estes arquivos são:** o estado **de hoje, lido no código**.
> **O que eles não são:** histórico. O *porquê* de decisões antigas continua nos
> `MUDANCAS_*.md` e `PEDIDO_*.md`, e cada arquivo aponta para o trecho que
> interessa. Nada foi apagado de lá.

---

## Por que a documentação foi dividida assim

A pasta `docs/` cresceu **por data**: `MUDANCAS_2026-08-06`, `…-08-10`,
`…-08-10_PARTE2`, `…-08-11`, `PEDIDO_2026-08-12`. É o formato certo para
registrar *o que aconteceu numa sessão* e o errado para responder *como a Gura
Gura funciona*: a resposta estava espalhada em cinco arquivos e em nenhum
índice. O `PEDIDO_2026-08-12.md` sozinho tem 458 linhas e sete tarefas sem
relação entre si — carga alta para quem só quer mexer numa fruta.

A divisão nova é **por fruta**, não por data e não por camada (VFX/rede/input).
O motivo é o mesmo que já vale para os agentes em [`../AGENTES.md`](../AGENTES.md)
e para o plano em [`../PLANO_FRUTAS.md`](../PLANO_FRUTAS.md): **cada fruta já
mora num arquivo próprio em `src/effects/`**, então a fronteira do documento
coincide com a fronteira do código. Dividir por camada obrigaria a abrir quatro
documentos para entender um golpe.

**A decisão, declarada:**

| | |
|---|---|
| **benefício imediato** | uma pergunta ("o que o V da Gura faz?") = um arquivo, não uma caçada por data |
| **impacto futuro** | fruta nova = arquivo novo + uma linha no índice; nenhum documento existente cresce |
| **manutenção** | o arquivo fica ao lado do território de um agente só, então dois agentes não editam o mesmo doc |
| **extensão** | o mesmo formato serve para os estilos de luta quando eles forem documentados |
| **custo** | 9 arquivos novos + ponteiros; nenhuma linha de história apagada |
| **riscos** | doc por fruta **desatualiza em silêncio** — ninguém quebra por causa disso |

**Gatilho contra o risco** (dívida adiada exige gatilho, não boa vontade):
qualquer tarefa que **mude o comportamento de um slot** (dano, alcance, tecla,
condição de uso) atualiza o arquivo daquela fruta na mesma tarefa. Se a mudança
não couber em um arquivo de fruta, ela é mudança de **sistema** e vai para
[`../ARQUITETURA_PLAYER.md`](../ARQUITETURA_PLAYER.md) ou para a
[`../LISTA_DE_CORRECOES.md`](../LISTA_DE_CORRECOES.md).

---

## Estado de cada fruta

Medido em código (2026-08-14). A coluna "hitbox" é o critério 5 do
[`../PLANO_FRUTAS.md`](../PLANO_FRUTAS.md): golpe sem `DamageZone` é enfeite.

| fruta | árvore no mapa | Z/X/C/V com hitbox | em revisão | arquivo |
|---|---|---|---|---|
| **Gura Gura** | sim | 4/4 | **🔧 sim, hoje** | [`gura_gura.md`](gura_gura.md) |
| Gomu Gomu | sim | 4/4 | — | [`gomu_gomu.md`](gomu_gomu.md) |
| Mera Mera | sim | 4/4 | — | [`mera_mera.md`](mera_mera.md) |
| Hie Hie | sim | 4/4 | — | [`hie_hie.md`](hie_hie.md) |
| Goro Goro | sim | 4/4 | — | [`goro_goro.md`](goro_goro.md) |
| Yami Yami | sim | 4/4 | — | [`yami_yami.md`](yami_yami.md) |
| Suna Suna | sim | 4/4 | — | [`suna_suna.md`](suna_suna.md) |
| Bara Bara | sim | 4/4 | — | [`bara_bara.md`](bara_bara.md) |
| Buki Buki | sim | 4/4 (arsenal) | — | [`buki_buki.md`](buki_buki.md) |

**9 frutas jogáveis, 9 árvores plantadas.** O placar medido em runtime que
originou isso está em [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md)
(2026-08-10) — lá ele diz *8 árvores* porque a `gura_gura` ainda não tinha a
dela.

### Estoque — passiva pronta, nenhum golpe

Estas **não** são jogáveis: têm nome, tipo e passiva em `FruitPassiveSystem`, e
nenhuma entrada em `SkillSystem`. Não recebem arquivo próprio porque não há o
que documentar além da linha de passiva — quando ganharem golpes, ganham
arquivo.

`pika_pika` · `magu_magu` · `ope_ope` · `hana_hana` · `ito_ito` ·
`zushi_zushi` · `moku_moku` · `tori_tori_phoenix` · `neko_neko_leopard` ·
`hito_hito_nika` · `uo_uo_seiryu` — **11 ids**, mais o órfão
`gura_gura_alt` (item 5 da lista de correções), que não é fruta nenhuma.

São 21 passivas contra 9 frutas com golpe. Três delas (`ope_ope`,
`hito_hito_nika`, `tori_tori_phoenix`) **têm árvore desenhada**, hoje filtrada
do mapa por `TreeAndFruitGenerator.get_tree_definitions()` — a arte fica
guardada, a árvore só volta quando a fruta tiver poderes.

> **Regra do dono, e ela manda nesta pasta:** não criar fruta nova enquanto as
> atuais não estiverem prontas.

---

## O que vale para TODAS as frutas

O que está aqui **não se repete** nos arquivos de fruta; eles só apontam para cá.

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

Duas consequências que explicam quase todo bug de fruta em rede:

1. **O VFX roda em todo mundo; o dano, só no servidor.** `DamageZone._on_body`
   e `_varrer_caminho` saem cedo quando `multiplayer.has_multiplayer_peer() and
   not is_server()`. Efeito bonito no cliente **não é prova** de que o golpe
   machuca.
2. **`_fire_skill` não devolve nada e engole quase tudo.** Um golpe pode "rodar"
   sem criar hitbox nenhuma — foi exatamente assim que três frutas passaram
   meses dando os golpes da Gomu Gomu sem ninguém perceber.

### Dano

`DamageZone.DAMAGE_SCALE = 0.12`. O número do `SkillSystem` é **nominal**: o
dano aplicado é `dano × 0,12`. Um golpe de 85 tira ~10,2 de uma barra de 2048.
**O foco do combate é knockback** (jogar para fora do mapa), não atrito de vida
— quem mexer em dano precisa saber que 14× de diferença passou despercebido uma
vez (o tornado da Suna, item 1 da lista).

Fonte que **fura** a escala existe e é bug conhecido: chamar `take_damage()`
direto, sem `DamageZone`.

### Recarga — cuidado, há duas tabelas e uma está morta

| onde | Z | X | C | V | vale? |
|---|---|---|---|---|---|
| `Player.RECARGA_POR_SLOT` | 5 s | 7 s | 10 s | **25 s** | **sim** |
| `SkillSystem.get_fruit_skills()[...]["cooldown"]` | 5 | 7 | 10 | **60** | **não — ninguém lê** |

No modo **estilo de luta** a recarga é `Player.RECARGA_ESTILO = 60 s` em
qualquer slot. Morrer **zera** a recarga (item 22). A divergência do V é o item
33 da lista de correções.

### Energia

`Player.ENERGY_SKILL = 180.0` por skill lançada, cobrada pelo `CastController`.
Nas skills carregáveis a cobrança é **no aperto**, não na soltura — senão dava
para espiar o golpe de graça, começando e cancelando.

### ⚠️ As passivas são TEXTO — só dois números saem do papel

`FruitPassiveSystem.get_all_passives()` descreve 21 passivas com efeitos ricos
(cargas de chama, volt meter, cura por drenagem, esquiva por desmembramento,
regeneração da fênix…). **`Player.equip_fruit` lê exatamente dois campos:**
`speed_mod` e `jump_mod`. Nada mais é implementado — conferido por grep: nenhum
outro arquivo lê `get_all_passives`, e a API de instância da classe
(`equip_fruit`, `passive_triggered`, `charge_count`, `volt_meter`) não tem
chamador nenhum.

Duas consequências:

- **quem for equilibrar frutas não pode contar com a passiva descrita** — ela
  não roda;
- a supressão da Yami Yami, que a descrição chama de passiva, na verdade vem dos
  **golpes** (X e V chamam `suppress_skills_temporarily`);
  `SkillSystem.apply_yami_suppression()` — a aura de 8 m — **não tem chamador**.

Isto está registrado como item 36 da lista de correções. Cada arquivo de fruta
repete a ressalva no cabeçalho, porque é o tipo de coisa que se descobre tarde.

### Equipar, perder, e a passiva

- `Player.equip_fruit(id)` é a **única** porta correta: esconde a fruta da
  árvore, devolve a anterior ao mapa, aplica `speed_mod`/`jump_mod` da
  `FruitPassiveSystem`, guarda a arma da Buki e atualiza a HUD.
- **Morrer devolve a fruta à árvore** e zera `current_fruit_id`. Sem fruta não
  há poder: `_fire_skill` recusa e diz por quê (o fallback mudo para
  `gomu_gomu` foi removido).
- `Player.set_character()` escreve `current_fruit_id` **direto**, sem passar
  pelo `equip_fruit` — segundo escritor, e é o item 34 da lista.

### ⚠️ Atalho de desenvolvimento ligado hoje

`Player.gd:18` e `Main.gd:114` nascem com **`gura_gura`** equipada. Está no
histórico do commit `a71a20a` como atalho de sessão, **não** como regra de jogo:
se isso chegar ao jogador final, a economia inteira das frutas (achar a árvore,
disputar a fruta, perder ao morrer) deixa de existir.

---

## Ferramentas

```bash
godot --headless --path . --script tools/dev_tests/test_frutas.gd            # todas
godot --headless --path . --script tools/dev_tests/test_frutas.gd -- mera_mera
```

Sobe o jogo de verdade, equipa cada fruta, dispara os quatro slots e conta o que
nasceu e o que sobrou no mundo. **Ninguém declara fruta pronta sem ela verde.**

⚠️ **Não roda em paralelo consigo mesma**: `start_singleplayer()` hospeda na
porta fixa `24565`; uma segunda instância morre com `Couldn't create an ENet
host` e o relatório diz "a cena não subiu", que se confunde com defeito do jogo.

O que ela **não** cobre: se o golpe é bonito, se funciona em rede, se o efeito
nasce onde deveria na tela, e se a `DamageZone` **encosta** em alguém — ela
prova que a hitbox existe, não que ela acerta.

---

## Onde a história ficou

Nada foi movido. Estes continuam sendo a fonte do *porquê*:

| documento | o que guarda sobre frutas |
|---|---|
| [`../PLANO_FRUTAS.md`](../PLANO_FRUTAS.md) | os 6 critérios de "fruta funcional" e como o trabalho é dividido |
| [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md) | o placar **medido** de 2026-08-10 e as ressalvas do método |
| [`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md) | charge-up, Goro repaginada, Black Hole nos pés, Buki/luneta, Karatê Tritão |
| [`../MUDANCAS_2026-08-11.md`](../MUDANCAS_2026-08-11.md) | a Buki Buki virou kit de FPS com munição |
| [`../MUDANCAS_2026-08-10.md`](../MUDANCAS_2026-08-10.md) | armas da Buki viraram asset `.glb` |
| [`../MUDANCAS_2026-08-06.md`](../MUDANCAS_2026-08-06.md) | a Buki Buki substituiu a Gasu Gasu |
| [`../erros.md`](../erros.md) | todo defeito de fruta com causa raiz e como detectar |
| [`../LISTA_DE_CORRECOES.md`](../LISTA_DE_CORRECOES.md) | o que está quebrado e **não** foi corrigido |
