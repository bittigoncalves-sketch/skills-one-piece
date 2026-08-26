# Estilos de luta — o segundo modo de combate

Escrito em 2026-08-26 por leitura de código. O jogo tem **dois** modos de
combate, e só um tem documentação: as frutas têm [`frutas/`](frutas/README.md),
uma página cada. Os estilos de luta — a metade que **está sempre disponível** —
nunca tiveram página.

Arquivos: `src/combat/FightingStyles.gd`, `src/effects/WaterFX.gd`,
`Balance.ESTILOS`, e o `toggle_combat_mode` / `_fire_skill` do `Player.gd`.

---

## 1. O trato: por que o estilo custa 60 s

A tecla **R** alterna `combat_mode` entre `"fruit"` e `"style"`. As mesmas quatro
teclas (Z/X/C/V) passam a lançar outra coisa.

**A recarga do estilo é 60 s em QUALQUER slot** (`Player.RECARGA_ESTILO`), contra
5/7/10/25 s da fruta. Não é desbalanceamento — é o **preço de não depender de
fruta**:

- a fruta precisa ser achada numa árvore;
- perde-se ao morrer (`net_force_respawn` devolve a fruta à árvore);
- some quando outro jogador pega antes.

O estilo não tem nenhum desses custos. Uma recarga própria e cara é o que impede
o estilo de ser **estritamente melhor** que a fruta.

⚠️ **Vale para todos os estilos, não só o Tritão** — foi assim que o dono pediu,
em 2026-08-12: *"para todos os ataques de skills que não sejam frutas"*.

### As duas recargas são independentes

`_fruit_cooldowns` e `_style_cooldowns` são **dicionários separados**
(`Player.gd:252-255`), e a vista `_skill_cooldowns` escolhe qual devolver
conforme o modo. Consequência que só aparece jogando: **trocar de modo não
espera recarga nenhuma**. Gastar o V da fruta e apertar R dá acesso imediato ao
V do estilo, e vice-versa. Cada modo esfria no seu ritmo, em paralelo.

---

## 2. O que existe (e o que só parece existir)

Seis estilos em `STYLES_LIST`: `karate_tritao`, `pacifista`, `mink`, `boxe`,
`cyborg`, `teste_animacao`. Trocar de estilo é pelo menu **M**
(`set_fighting_style`), que **também força** `combat_mode = "style"`.

| estilo | Z | X | C | V | 4 golpes de verdade? |
|---|---|---|---|---|---|
| **Karatê Tritão** | 88 | 160 | 224 | **0** ⛔ | ✅ — três formas próprias em `WaterFX` |
| **PX Pacifista** | 92 | 176 | 200 | 704 | ❌ um golpe só |
| **Mink Electro** | 84 | 152 | 208 | 672 | ❌ um golpe só |
| **Boxe** | 88 | 168 | 192 | 688 | ❌ um golpe só |
| **Cyborg Tech** | 96 | 176 | 216 | 720 | ❌ um golpe só |
| **Teste de Animação** | 80 | 128 | 192 | 512 | parcial — cicla clipes do Mixamo |

⚠️ **Quatro dos seis estilos têm quatro nomes na HUD e um golpe.**
`_cast_laser`, `_cast_electro`, `_cast_boxe` e `_cast_cyborg` **recebem `variant`
e não o leem** — a palavra aparece uma vez só em cada função, na assinatura. Z, X,
C e V disparam efeito idêntico; o que muda é o nome na HUD, a cor, e o número que
o `_fire_skill` lê da tabela. É o item **29** da
[`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md), e continua verdadeiro em
2026-08-26.

Só o Tritão foi tratado (2026-08-13) porque só ele estava no pedido. Antes disso
ele tinha o mesmo defeito: os quatro slots caíam no **mesmo esguicho de
partículas**.

---

## 3. Três `dano` no mesmo jogo, e só um vale

Este é o ponto que custa tempo a quem chega frio.

| onde | vale? |
|---|---|
| `Balance.ESTILOS[estilo][slot]` | **sim** — é o que `Player._fire_skill` lê |
| `FightingStyles.STYLES[…]["skills"][slot]["dano"]` | não — referência de leitura, ao lado do nome e da cor |
| `FightingStyles.STYLES[…]["skills"][slot]["cooldown"]` | **não é lido por ninguém** |

Os dois primeiros são mantidos iguais de propósito, e
`tools/dev_tests/test_balance.gd` **recusa a tabela se discordarem**. O terceiro
não tem quem confira: `RECARGA_ESTILO` (60 s) ignora esses números por completo.

⚠️ **E a LISTA de estilos existe em QUATRO lugares**, todos escritos à mão e hoje
em dia coincidentes: `Player.STYLES_LIST:82`, `FightingStyles.STYLES:19`,
`Balance.ESTILOS:218` e `CharacterMenu.STYLES:26`. Adicionar um estilo exige as
quatro edições, e só a discordância entre `FightingStyles` e `Balance` tem teste.
Um estilo que entre no menu e não na `STYLES_LIST` é aceito pelo `set_fighting_style`
(`find` devolve −1) e **não faz nada**, em silêncio.

⚠️ O `"cooldown"` fica ali como registro do **ritmo pretendido** de cada golpe
(2,0 s no Z do Tritão, 14,0 s no V do Cyborg). Se um dia o estilo voltar a ter
recarga por skill, é este campo que a `trigger_skill_cooldown` deve passar a
consultar — não um número novo.

---

## 4. Duas decisões de desenho que o código explica e nenhum doc registrava

### `desabilitado` é FLAG DE DADOS, não `if`

O V do Karatê Tritão não existe (`"desabilitado": true`, dano 0). O
`CastController` recusa a tecla **no aperto**, lendo o dicionário.

**Não é** `if estilo == "karate_tritao"`. O próximo estilo que quiser 3 golpes em
vez de 4 não precisa de código novo — só do campo. O dano 0 em
`Balance.ESTILOS.karate_tritao.V` é **consequência** disso, não um valor a
calibrar.

### O `_` do `match` cobre DOIS casos, e por isso é o esguicho e não "nada"

```gdscript
match variant:
    0: WaterFX.tiros_da_mao(...)   # Z
    1: WaterFX.esguicho(...)       # X — INTACTO (pedido do dono)
    2: WaterFX.onda(...)           # C
    _: WaterFX.esguicho(...)       # V / estilo desconhecido
```

O default atende **o V desabilitado** (que em jogo nem chega ali) **e** qualquer
estilo sem tratamento próprio, que o `cast()` manda para o `_cast_water`. Um
estilo desconhecido tem que continuar saindo com o golpe genérico de sempre — por
isso o ramo não pode ser vazio.

### O corpo dos efeitos mora no `WaterFX`, não aqui

`FightingStyles.gd` é a **tabela** de estilos, não a oficina de VFX. Ele já gasta
~270 linhas só com seis estilos genéricos; enfiar três golpes de água dentro dele
o levaria ao teto de 900 linhas
([`LIMITE_DE_TAMANHO.md`](LIMITE_DE_TAMANHO.md)) **no segundo estilo** que
ganhasse tratamento de verdade. Quem for tratar Pacifista, Mink, Boxe ou Cyborg
segue o mesmo caminho: um `*FX.gd` por estilo, ao lado de `IceFX`/`FireFX`/`GoroFX`.

### Z e C do Tritão trocaram de NOME, não de lugar

O pedido do dono é *"Z = tiros d'água da mão"* e *"C = onda empurrada pra
frente"*. Os nomes canônicos estavam invertidos em relação a isso **desde
sempre**: Murasame é o jato disparado, Karakusa Kawaragete é a onda. Quem
comparar com a referência do anime e achar que está trocado, está lendo o
histórico.

---

## 5. Buracos conhecidos

- ⚠️ **`RECARGA_ESTILO` não passa pelo servidor.** É decidida só no cliente, pela
  `trigger_skill_cooldown` — a mesma forma do buraco de munição infinita da Buki
  (item 14, fechado com `_srv_recarga_ate`). Um cliente adulterado que mande
  `_net_cast_req` direto ignora a recarga. Item **30** da lista; peso menor que o
  da Buki, mas é o **mesmo furo**, e ele cresce se o estilo virar a via principal
  de combate.
- ⚠️ **`teste_animacao` é uma ferramenta de dev exposta como estilo jogável.** Os
  quatro slots ciclam a biblioteca de clipes do Mixamo (Z = próximo, X =
  anterior, C/V = repetir) e criam `DamageZone` **sem VFX nenhum**, de propósito.
  Ele está no `STYLES_LIST`, então aparece no menu M como um estilo qualquer.
- **Nenhum estilo tem passiva.** As passivas são exclusivas da fruta
  (`speed_mod` / `jump_mod`); trocar para estilo não muda velocidade nem pulo.
