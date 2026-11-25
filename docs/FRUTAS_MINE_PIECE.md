# Frutas Mine Piece — referência das traduções

Frutas do Mine Piece v14 traduzidas para o controlador genérico (`src/combat/frutas_mine_piece/`).
Plano, decisões e estado: [`FRUTAS_MINE_PIECE_CHECKPOINT.md`](FRUTAS_MINE_PIECE_CHECKPOINT.md).
A Goro Goro tem controlador próprio: [`GORO_GORO_MINE_PIECE.md`](GORO_GORO_MINE_PIECE.md).
Arte e números do mod são provisórios (All Rights Reserved, fora do git) — recalibrar antes de lançar.

GATILHO: dividir este arquivo por fruta quando passar de 900 linhas.

## Como funciona (todas)

- Vendidas no vendedor de frutas do Modo História por 1 moeda; comer em N › FRUTAS; item da fruta ativo.
- **R** troca a técnica (**Shift+R** volta), **Z** usa — segurar carrega, soltar dispara.
- Energia = custo do mod / 100; recarga global = max(custo × 0,5, 5) ticks.
- Dano: mod × 10 × 250/2048 (história). Os danos base moram em `Balance.MINE_PIECE_<FRUTA>`.
- Unidades: 1 bloco = 0,88 m; 1 tick = 0,05 s (`MundoMinePiece`).
- Logias (`"familia": "logia"` na ficha): transformação elemental do dono — 4 golpes em 3 s ou 25% da vida
  em 3 s → +35% de velocidade e voo do mod; disparar técnica desfaz (`corpo_logia.gd`).
- Lentidão do mod (MobEffect SLOWNESS) na técnica: −15% por nível; amplificador ≥ 6 prende o corpo.
- Munição criada por técnica (lança, pássaro, gelo) guarda o dono (`MundoMinePiece.DONO`): não fere o
  dono nem outra munição dele (LogicAttack) e vive sozinha até a regra dela, como a entidade do mod.

| arquivo | o quê |
|---|---|
| `catalogo.gd` | fichas: nome, ícone, executor, poses, família, ciclo R; `substitui` = versão antiga do Builder |
| `controlador.gd` | R/Z, Shift, energia, recarga, Lentidão, poses, gancho de movimento do `Player` |
| `corpo_logia.gd` | transformação elemental + voo + borda e partícula do elemento |
| `vfx_fruta_mine_piece.gd` | partículas (flipbook do mod), som, placa no chão, `render_do_mod` (entityTranslucent) |
| `municao_mine_piece.gd` | base da munição que anda sozinha (AIEntityBird/AIFist): passos, ataque, parada, limites |
| `golpes_mine_piece.gd` | golpes do corpo chamados dentro de técnicas (`soco_forte` = AttackStrongPunch) |
| `imobilizacao_mine_piece.gd` | Lentidão X + sem técnica/golpe/voo nos ALVOS (status "Preso" no HUD) |
| `MundoMinePiece` (goro_mine_piece) | RangeAttack, Knockback (`empurrar_area`), tamanho, pé e dimensões do corpo |

- Controlador: `lentidao` (MobEffect SLOWNESS), `impulsionar` (setDeltaMovement da técnica),
  `invisivel` (MobEffect INVISIBILITY), Shift lido no dono, poses pela ficha.
- Captura de qualquer fruta: `DISPLAY=:1 <godot> --path . -s tools/dev_tests/captura_fruta_mine_piece.gd --
  <id> <pasta> [shift=21]` — cada técnica (carga e disparo), vista do jogador e vista lateral, folhas de contato.
- Leitura do Java: `python3 -I tools/mine_piece/compactar_java.py <Arquivo.java>`.

## Hie Hie (Mine Piece) — 20/10/2026

Fonte: `SkillHieHieProcedure` e o que ele chama. Substitui `hie_hie_no_mi_mine_piece` (Builder) na loja;
save com a antiga comprada ou equipada passa a ter esta. A do Builder continua na arena.

| R | técnica | procedimento | ⚡ | recarga | dano (mod) |
|---|---|---|---|---|---|
| 21 | Ice Block: Partisan | `IceBlockPartisan` → 4 `EntityPartisan` | 1 | 2,5 s | 15 × CNT6 por lança |
| 21+Shift | (atrás do corpo) | `IceBlockPartisan2` | — | — | 15 × 0,9, uma lança a cada 2 ticks até cnt2 = 50 |
| 22 | Ice Block: Pheasant Beak | `IceBlockPheasantBeak` → `EntityBird` | 3 | 7,5 s | 20 × CNT6 |
| 24 | Ice Ball | `IceBallProcedure` | 2,5 | 6,25 s | 15 × CNT6 por cubo, frente de 4 blocos/tick por 11 ticks |
| 25 | Ice Age | `IceAgeProcedure` | 6 | 15 s | (18 + cnt2 × 0,1) × CNT6, área até 16 blocos |

- CNT6 = 1 + carga/10; a carga vai de 0 a 5 segurando Z (cheia: clarão).
- **Efeito 12** (`Effect12` + `AIIceBall`): o alvo fica preso numa bola de gelo (vida 30 × CNT6 do atacante,
  com o +5 que Ice Ball/Ice Age somam no ataque) por até 300 ticks; some se quebrar ou se o alvo escapar
  (≥ 1 bloco). O dono não quebra o próprio gelo; quem está preso quebra no clique (dano do soco simples).
- Lança/pássaro (`AIEntityBird`): 8/4 blocos por tick, cubo de 3 × tamanho, empurrão 0,65 + a velocidade da
  munição; para no primeiro alvo ou parede e fica cravada atacando até cnt2 > 10/20 (pode acertar de novo
  quando a imunidade de 10 ticks acaba, como no mod). Congelar alguém a desfaz.
- O 23 (`IceSpikes`) está no despacho mas não no ciclo R do jogador: fica fora, como no mod.

Adaptações declaradas:
- O golpe que congela não empurra o alvo para fora do gelo (o Effect12 zera a velocidade; o empurrão
  aplicado depois o tiraria do gelo no tick seguinte).
- `BlockToIce`/`BlockDestroyAllDirection` viram placa de gelo e partículas; o mapa não muda.
- Sons vanilla (vidro, wither, respiração) usam o `ice_generate` do mod; carga cheia = clarão.
- Bolas de gelo extras da Ice Age só com Força > 9 (o jogo não tem o efeito); a Lentidão que o Effect12
  aplica nos alvos não entra (o gelo já prende); a pose de congelado (-49) do alvo não entra.
- Quebrar o próprio gelo só no jogo local (`_unhandled_input` no servidor). GATILHO: co-op na história.

Arquivos: `hie.gd` (técnicas), `lanca_de_gelo_hie.gd`, `gelo_hie.gd`; assets
`python3 -I tools/mine_piece/importar_hie.py`.

Validação: `tools/dev_tests/test_hie_mine_piece.gd` 46/0 (loja, substituição, migração do save, ciclo R,
custos, recargas, dano de cada técnica, congelar, quebrar o gelo, Lentidão, transformação, troca de fruta);
capturas com `captura_fruta_mine_piece.gd -- hie_hie_mine_piece <pasta> shift=21`. Julgamento visual do
dono pendente; não jogado à mão.

## Moku Moku (Mine Piece) — 21/10/2026

Fonte: `SkillMokuMokuProcedure`. Substitui `moku_moku_no_mi_mine_piece` (Builder) na loja e no save.

| R | técnica | procedimento | ⚡ | recarga | o que faz (mod) |
|---|---|---|---|---|---|
| 21 | White Fist | `WhiteBlow` → 2 `FistEntity` (move −1) | 1,2 | 3 s | 3 socos fortes (11 × CNT6) e 2 punhos de fumaça (18 × CNT6, 6 blocos/tick) |
| 23 | White Vine | `WhiteVine` → `TornadoEntity` | 2,5 | 6,25 s | some e vai 5 blocos acima do alvo; tornado no chão (11 × CNT6/tick, lança para cima), cresce até 10 de SIZE, 80 ticks |
| 25 | White Launcher | `WhiteLauncher` | 2,5 | 6,25 s | carga parado; investida a 4,5 blocos/tick até 10 ticks; no alvo, soco forte com cnt6 + 2,5 |
| 30 | White Out | `WhiteOut` | 3 | 7,5 s | campo de fumaça (até 48 blocos) prende quem está dentro; estouro 18 × CNT6 em 32 × CNT6 + empurrão 6 blocos/tick |

- Defeitos do mod preservados: no White Fist `yaw/picth` nunca recebem valor, então o punho nasce 2 larguras
  a +X do mundo, qualquer que seja a mira; o White Vine sobe até achar teto (ou 5 blocos) acima do alvo.
- Adaptações declaradas: a investida do White Launcher para no alvo (no mod a velocidade do tick do teleporte
  passa 4,5 blocos do alvo e o soco sai no vazio); "cloud" vanilla = fumaça do mod; anel de nuvens do White
  Out (~1000 partículas/tick) = anel de fumaça; sons vanilla = sons do combate do mod; blocos destruídos =
  fumaça; o tornado encosta no chão (o mod anda na grade de blocos).
- Arquivos: `moku.gd`, `punho_moku.gd`, `tornado_moku.gd`; assets `python3 -I tools/mine_piece/importar_moku.py`.
- Validação: `test_moku_mine_piece.gd` 27/0 (loja, substituição, save, ciclo R, custos, recargas, punhos e dano,
  teleporte invisível e tornado, investida que para no alvo + soco, campo que prende e solta, estouro,
  transformação, troca); capturas `captura_fruta_mine_piece.gd -- moku_moku_mine_piece <pasta>`. Visual do dono
  pendente; não jogado à mão.

## Ope Ope (Mine Piece) — 19/10/2026

Só a técnica 23 (Stone Throwing, `StoneOpeOpeProcedure` + `AIRubble`) está no ciclo do mod.
`ope.gd`, `entulho_ope.gd`; `test_ope_mine_piece.gd` 23/0.
