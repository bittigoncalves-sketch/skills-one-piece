# Auditoria das Akuma no Mi — 2026-08-10

Resultado **medido** por `tools/dev_tests/test_frutas.gd`, com o jogo de verdade
rodando. Critérios e método em [`PLANO_FRUTAS.md`](PLANO_FRUTAS.md).

```bash
godot --headless --path . --script tools/dev_tests/test_frutas.gd
```

---

## Placar FINAL (depois dos consertos)

| fruta | obtível | equipa | golpes com hitbox | vazamento real |
|---|---|---|---|---|
| `bara_bara` | sim | sim | **4/4** | — |
| `buki_buki` | sim | sim | **4/4** | — |
| `gomu_gomu` | sim | sim | **4/4** | — |
| `goro_goro` | sim | sim | **4/4** | — |
| `gura_gura` | **sim** ✅ | sim | **4/4** | — |
| `mera_mera` | sim | sim | **4/4** | — |
| `suna_suna` | sim | sim | **4/4** ✅ | — |
| `hie_hie` | sim | sim | **4/4** ✅ | — |
| `yami_yami` | sim | sim | **4/4** ✅ | — |

**9 de 9 frutas funcionais. Zero vazamento real no jogo inteiro.**

Mudou desde a primeira medição: `yami_yami` 1/4→4/4, `hie_hie` 2/4→4/4,
`suna_suna` 3/4→4/4, e a `gura_gura` ganhou árvore (tinha os 4 golpes prontos e
era impossível de obter). Detalhe do que era cada defeito em
[`erros.md`](erros.md).

---

## Placar da PRIMEIRA medição (o que estava quebrado)

| fruta | obtível | equipa | golpes com hitbox | vazamento |
|---|---|---|---|---|
| `bara_bara` | sim | sim | **4/4** | — |
| `buki_buki` | sim | sim | **4/4** | — |
| `gomu_gomu` | sim | sim | **4/4** | — |
| `goro_goro` | sim | sim | **4/4** | — |
| `gura_gura` | **NÃO** | sim | **4/4** | — |
| `mera_mera` | sim | sim | **4/4** | 10 nós |
| `suna_suna` | sim | sim | 3/4 | 14 nós |
| `hie_hie` | sim | sim | 2/4 | 34 nós |
| `yami_yami` | sim | sim | **1/4** | 40 nós |

**Cinco frutas estão inteiras.** As quatro com pendência são **todas Logias**;
nenhuma Paramecia falhou.

Todas as 9 equipam corretamente — o bug de "pegar ope ope e receber gomu gomu"
era o fallback mudo, já corrigido (`docs/erros.md`, 2026-08-10).

---

## Detalhe por golpe

Só as frutas com pendência. `criou` = pico de nós no mundo; `sobrou` = nós que
continuaram lá depois de 8 s.

### `yami_yami` — a mais quebrada: 3 dos 4 golpes não machucam

| slot | criou | hitbox | sobrou | |
|---|---|---|---|---|
| Z | 8 | **sim** | 0 | ok |
| X | 6 | **não** | — | só visual |
| C | 6 | **não** | 0 | só visual |
| V | 46 | **não** | **40** | só visual **+ vazamento grande** |

### `hie_hie` — metade dos golpes é enfeite

| slot | criou | hitbox | sobrou | |
|---|---|---|---|---|
| Z | 5 | **sim** | 0 | ok |
| X | 9 | **sim** | 0 | ok |
| C | 4 | **não** | 0 | só visual |
| V | 34 | **não** | **34** | só visual **+ vazamento grande** |

### `suna_suna`

| slot | criou | hitbox | sobrou | |
|---|---|---|---|---|
| Z | 8 | **sim** | — | ok |
| X | 6 | **não** | 0 | só visual |
| C | 25 | **sim** | 0 | ok |
| V | 18 | **sim** | **14** | ok, mas vaza |

### `mera_mera` — golpes todos bons, só vaza

| slot | criou | hitbox | sobrou | |
|---|---|---|---|---|
| Z | 56 | **sim** | **1** | vaza pouco |
| X | 10 | **sim** | 0 | ok |
| C | 41 | **sim** | 0 | ok |
| V | 14 | **sim** | **9** | vaza |

---

## Camada de dados: passivas estão MUITO à frente das skills

| | quantidade |
|---|---|
| passivas em `FruitPassiveSystem` | **21** |
| frutas com skills em `SkillSystem` | **9** |
| árvores plantadas no mapa | **8** |

- **Todas as 9 frutas com skill têm passiva.** Nenhum buraco desse lado.
- **12 frutas têm passiva e nenhuma skill**: `pika_pika`, `magu_magu`, `ope_ope`,
  `hana_hana`, `ito_ito`, `zushi_zushi`, `moku_moku`, `tori_tori_phoenix`,
  `neko_neko_leopard`, `hito_hito_nika`, `uo_uo_seiryu`, e um id solto
  `gura_gura_alt`. São elas o "estoque" a terminar — a passiva e o nome já
  existem, falta o golpe.
- **`gura_gura` tem skills e passiva, mas nenhuma árvore**: 4/4 golpes
  funcionando e impossível de obter jogando.

---

## Fila de trabalho, por gravidade

**1. Golpe que não machuca** — 6 golpes são só efeito visual. É defeito, não
ajuste de sensação:
`yami_yami` X, C, V · `hie_hie` C, V · `suna_suna` X

**2. Vazamento de nós** — degrada a partida com o tempo:
`yami_yami` V (40) · `hie_hie` V (34) · `suna_suna` V (14) · `mera_mera` V (9) e Z (1)

**3. `gura_gura` sem árvore** — poder pronto, inalcançável.

**4. Sensação** (cadência, alcance, knockback, VFX) — só depois, e só jogando.

---

## Ressalvas — o que estes números NÃO garantem

Registrado porque medir errado com confiança é pior que não medir.

### 🔴 A coluna "vazamento" estava medindo DURAÇÃO, não vazamento

Erro meu, corrigido depois que os dois agentes mediram de forma isolada. É a
ressalva mais importante deste documento.

O teste espera **8,9 s** depois do golpe e chama de "vazado" o que ainda estiver
de pé. Só que vários efeitos **duram muito mais que isso, de propósito**:

| o que eu marquei como vazamento | o que era de fato |
|---|---|
| `hie_hie` V — 34 nós | o campo da Ice Age, `autofree(age_zone, 50.0)`. Cai a **zero em t+55 s** — a doc do golpe diz "congela o chão por 50 segundos" |
| `suna_suna` V — 14 nós | o deserto, `autofree(desert_mmi, 20.0)`. Zero em **t+20 s** |
| `yami_yami` V — 44 nós | **30 eram entulho com vida de 20 s** (janela do combo V→C) e **14 eram vazamento de verdade** — poeira dos escombros nunca liberada |

Ou seja: **de todos os números da tabela, só 14 nós do `yami_yami` eram
vazamento real.** O resto era o teste sendo impaciente.

Os valores **negativos** na medição (`suna_suna` Z = −44, `yami_yami` X = −14)
eram o mesmo fenômeno visto de outro ângulo: efeitos do slot anterior ainda
morrendo durante o slot seguinte.

**Como distinguir, e é o único jeito confiável:** disparar **um slot só**, 5
vezes seguidas, e acompanhar a contagem até ela voltar à base. Vazamento cresce
**linear** com as repetições e nunca volta; duração longa volta a zero sozinha,
na hora que o `autofree` marca.

**Consequência prática:** nenhuma duração foi encurtada para "passar no teste" —
seria deformar o design para agradar o cronômetro. A única exceção foi o entulho
do `yami_yami`, de 20 s para 6 s, e está marcada como mudança de sensação
reversível numa constante.

**Dois bugs da própria ferramenta foram corrigidos no meio do caminho**, e a
primeira passada estava errada:

| | 1ª passada (errada) | passada válida |
|---|---|---|
| árvores no mapa | 0 | 8 |
| frutas "sem árvore" | 9 | 1 |
| frutas com golpe mudo | 8 | 0 |

1. `TreeAndFruitGenerator` referenciava o autoload `FruitNet` **por
   identificador**, e isso não compila em script `-s`: a classe inteira falhava e
   devolvia lista vazia **sem avisar**. Corrigido (busca por caminho + dublê).
2. A contagem de nós era feita **num instante só** (0,9 s), o que dava falso
   negativo em golpe com wind-up — o Gomu Z aparecia como "não produziu nada".
   Agora amostra o pico ao longo de toda a janela.

**O que a auditoria continua sem cobrir:** se o golpe é bonito ou gostoso; se
funciona em rede (roda em um-jogador — a pistola da Yami já falhou só no cliente);
se o efeito nasce no lugar certo na tela; e se a `DamageZone` de fato encosta em
alguém. Ela prova que a hitbox **existe**, não que ela **acerta**.

**A auditoria não roda em paralelo consigo mesma.** `start_singleplayer()` hospeda
um servidor local na porta fixa `24565`, então uma segunda instância morre com
`Couldn't create an ENet host` e o teste reporta "a cena não subiu" — o que se
confunde facilmente com defeito do jogo. Acontece na prática quando um agente
está medindo e outro tenta medir junto. Conserto (pendente): porta aleatória, ou
uma flag de teste que suba a cena sem hospedar.

**Uma armadilha estática que não funcionou:** procurar `create_tween()` sem
prefixo como sinal de vazamento deu **falso positivo** em `FireFX` e `YamiFX` —
nos dois o tween anima o próprio nó, que é o padrão seguro. O caso perigoso é
específico (tween em `self` cujo callback libera **outro** nó, num método cujo
chamador destrói `self`) e só a medição em runtime distingue.
