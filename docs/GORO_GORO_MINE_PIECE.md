# Goro Goro (Mine Piece) — tradução do mod (18/10/2026)

Pedido do dono: importar a Goro Goro no Mi do Mine Piece v14 para o Skills One Piece
preservando o mod, **sem prévias do Builder**, por **tradução de código**; nome
"Goro Goro (Mine Piece)", preço 1 moeda; criar no jogo o evento que a fruta precisar e
não existir; teclas do mod por enquanto: **R troca** a técnica, **Z usa** a selecionada.

Fonte: `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14` (procedures/).
A Goro Goro da arena (`goro_goro`) continua igual e separada.

## Decisões do dono

| tema | decisão |
|---|---|
| eventos fora do R/Z | traduzir os dois: passiva 28 (toque duplo W/S) e Kari Krash 27 (defesa perfeita) |
| onde fica | só no vendedor de frutas do Modo História, 1 moeda (vai para N › FRUTAS) |
| números | lógica do mod (ticks, blocos, fórmulas); dano e energia na escala da história |
| quebra de blocos | marca visual no chão, sem destruir o mapa |
| intangibilidade das logias | **não existe** aqui. No lugar, a transformação elemental (abaixo) |
| voo das logias | traduzir o `FlyActiveProcedure` |
| transformação | 4 golpes em 3 s **ou** 25% da vida em 3 s → corpo de raio: +35% de velocidade e voo forçado; disparar técnica desfaz |

## Como jogar

- Comprar no vendedor de frutas, comer em N › FRUTAS, deixar o item da fruta ativo.
- **R** troca: Vari → El Thor → Sango → Mamaragan (→ Raigo, só durante o Mamaragan). **Shift+R** volta.
- **Z**: segurar carrega (Vari, El Thor, Sango: até ×1,5 de dano), soltar dispara.
- **Shift** no disparo do El Thor: o pilar cai do céu em vez do feixe.
- **W W** ou **S S** (toque duplo): teleporte elétrico, sem custo.
- **Aparo** do combate direcional (guarda no tempo certo): contra-ataque Kari Krash, sem custo.
- Painel de técnicas: a selecionada leva **[Z]**; a recarga é global (usou uma, todas esperam).

## Técnicas (número do mod → tradução)

| R | técnica | procedimento | ⚡ | recarga | dano (unid. do mod) |
|---|---|---|---|---|---|
| 21 | Vari | `VariProcedure` | 2 | 5 s | (14 + cnt3·0,01)·carga, cubo 24 blocos, 13 ticks |
| 22 | El Thor | `ElThorProcedure` | 4 | 10 s | 16 → 24 após o tick 20, feixe de 64 blocos |
| 22+Shift | El Thor do céu | `ElThorFallProcedure` | — | — | 16 → 24 após o tick 25, pilar |
| 23 | Sango | `SangoProcedure` + `LightningStrike2` | 4 | 10 s | 18·carga por raio, 2–4 raios/tick por 22 ticks |
| 25 | Mamaragan | `SkillMamaragan` + `MamaraganOnEffectActiveTick` | 8 | 20 s | 60 s de tempestade: 2,5%/tick, 18 por raio |
| 29 | Raigo | `RaigoProcedure` + `AIMeteorProcedure` (modo 1) | 15 | 37,5 s | 24·1,25 na queda, 45·1,25 na explosão |
| 27 | Kari Krash | `KariKrashProcedure` (via `JustGuard`) | 0 | — | 18 por tick, 10 ticks |
| 28 | passiva | `SkillGoroGoroPassive1Procedure` | 0 | — | — |

Conversões: 1 bloco = 0,88 m (escala das estruturas); 1 tick = 0,05 s; energia = custo do
mod / 100; recarga = max(custo × 0,5, 5) ticks (`StartCursedTechniqueProcedure`); dano =
mod × 10 (arena, como `Balance.MINE_PIECE_LUTA`) × 250/2048 (história) ≈ mod × 1,22.
Os danos base moram em `Balance.MINE_PIECE_GORO`.

Regras do Minecraft traduzidas porque decidem o resultado: `invulnerableTime` por alvo
(10 ticks; dentro da janela só passa a diferença para um golpe maior), empurrão do
`RangeAttack` (`knockback × 3` blocos/tick, vertical limitado), Effect 11 (choque: 0,5 s
parado; Gomu e Goro imunes), voo (`FlyActive` a cada 3 ticks, ar 0,91/0,98, Queda Lenta).

## Arquivos

| arquivo | o quê |
|---|---|
| `src/combat/goro_mine_piece/goro_goro_mine_piece.gd` | controlador: R/Z, energia, recarga, Mamaragan, Kari Krash, toque duplo, transformação, voo, poses, HUD |
| `src/combat/goro_mine_piece/tecnicas_goro_mine_piece.gd` | as técnicas tick a tick (contadores `cnt1…cnt10` do mod) |
| `src/combat/goro_mine_piece/mundo_mine_piece.gd` | RangeAttack, InsideSolidCalculate, ReturnEntitySize, imunidade, empurrão |
| `src/combat/goro_mine_piece/meteoro_raigo.gd` · `onda_de_impacto.gd` | MeteorEntity modo 1 · EntityImpactWave modo 56 |
| `src/combat/goro_mine_piece/transformacao_elemental.gd` · `voo_logia_mine_piece.gd` | regra das logias do dono · voo do mod |
| `src/combat/goro_mine_piece/vfx_goro_mine_piece.gd` | faíscas, fumaça, clarão, raios, marca, sons |
| `tools/mine_piece/importar_goro.py` | sons, partículas, poses, meteoro e ícone do mod (arte fora do git) |
| ganchos | `Player.gd` (movimento e corpo invisível), `ModoHistoria.equipar_fruta`, `HistoriaHud` (R/Z), `TecnicasHud`, `PerfilDeFrutas` (loja) |

Refazer os assets: `python3 -I tools/mine_piece/importar_goro.py` (sem eles a fruta
funciona igual, só sem sons, partículas animadas, poses e o modelo do meteoro).

## Adaptações declaradas (o resto é literal)

- A mira do jogador é o retículo (regra do projeto); no Minecraft a visão e a mira são a mesma reta.
- ElThorFall: no mod, o jogador cai na posição guardada pela técnica anterior (defeito do mod); aqui mira pelo retículo.
- Raios do céu nascem 64 blocos acima do centro (o mod usa max(y + 64, 194), teto do mundo do Minecraft).
- Carga cheia: a "explosão" de potência 0 do mod virou clarão e som.
- O ciclo do R não inclui o ataque físico (número 1 do mod): o clique já faz os socos.
- Sem a trava por grau (advancements `grade_*`): a energia é a trava (o Raigo pede 15, energia inicial 10).
- O voo exige Espaço no mod; transformado (regra do dono), W/S também comandam e parado o corpo plana.
- Fumaça do mod em tamanho menor e esmaecendo (ver `docs/erros.md`).

## Limitações e gatilhos

- **Arte do mod é provisória** (All Rights Reserved, fora do git) e os números também: recalibrar antes de lançar ([[mine-piece-arte-provisoria]]).
- **Kari Krash só pelo aparo corpo a corpo.** O jogo não tem defesa perfeita contra técnica. GATILHO: o dono pedir aparo de técnica.
- **Rede:** a lógica roda no servidor e o dono só manda teclas; efeitos visuais e o voo foram feitos para a história local. GATILHO: co-op na história.
- Fora da tradução: o céu escuro do Mamaragan (`weather thunder`), a vida das ondas de impacto, o segundo empurrão vertical (`KnockbackProcedure`, Y até 1,5) e a IA do Enel/Zeus. GATILHO: o dono pedir qualquer um deles.
- O toque duplo tem a janela do mod (leitura a cada 100 ms): toques muito rápidos podem não contar.
- Shift aqui também é correr; segue a tecla do mod "por enquanto".

## Validação (18/10/2026)

- `tools/dev_tests/test_goro_mine_piece.gd`: 50/50 — loja (1 moeda), comer, R/Shift+R,
  Vari/El Thor/Sango ferem e cobram 2/4/4 ⚡ com 5/10/10 s, recarga global, El Thor do
  céu, Mamaragan 60 s → Raigo (meteoro cai e fere), passiva por toque duplo real,
  Kari Krash pelo aparo, transformação (4 golpes e 25%), +35%, decolagem, técnica desfaz,
  trocar de fruta limpa, e as regras do Minecraft com os números do Java.
- `tools/dev_tests/captura_goro_mine_piece.gd`: capturas com janela de todas as técnicas.
  Julgamento visual do dono pendente.
