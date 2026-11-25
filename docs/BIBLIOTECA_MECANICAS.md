# Biblioteca de mecânicas (estudo de outros jogos)

Fichas que explicam como poderes e sistemas de outros jogos e mods foram feitos e pensados,
cada uma terminando em **"Adaptação para Skills One Piece"**. A adaptação traz a parte
isolável, onde ela encaixaria neste projeto (caminho real) e o critério de pronto.

- **Onde está:** `~/dev/biblioteca-de-mecanicas` (repositório próprio). O índice fica em
  `INDICE.md` e o método no `README.md`.
- **Como pedir um estudo novo:** "estude a mecânica X do jogo Y". A skill `estudar-mecanica`
  (Claude e Codex) segue o método e grava a ficha lá.
- **Ficha não é implementação.** Levar uma ficha para o jogo é tarefa própria, com o plano
  e os números deste projeto (`src/combat/Balance.gd`, `docs/MECANICAS.md`).

Fichas que já citam este projeto:

| Ficha | Compara com |
|---|---|
| `fichas/poder/hie-hie-ice-age-mine-piece.md` | `src/effects/IceFX.gd` (`_ice_age`, `_congelar_alvo`) |
| `fichas/poder/pika-pika-skills-mine-piece.md` | `mapas/skills/pika_*.json`, `docs/frutas/pika_pika.md` |
| `fichas/poder/hie-hie-skills-restantes-mine-piece.md` | `mapas/skills/Z_ice.json`, `docs/frutas/hie_hie.md` |
| `fichas/poder/moku-moku-skills-mine-piece.md` | `mapas/skills/moku_*.json` |
| `fichas/poder/nikyu-nikyu-skills-mine-piece.md` | `mapas/skills/nikyu_*.json` |

Rascunhos de skill derivados das fichas do Mine Piece (validados, não testados em jogo):
[`docs/referencias/mine_piece/`](referencias/mine_piece/LEIA-ME.md).
