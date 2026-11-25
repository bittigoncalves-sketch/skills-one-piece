# Skills do Mine Piece — referência e rascunhos

Extraído do Mine Piece v14 (mod de One Piece para Minecraft, All Rights Reserved) em
2026-10-17, **só para estudo e referência**. Nenhum código, som ou textura do mod entra aqui.

## No jogo (17/10/2026)

Decisão do dono: **frutas novas "(Mine Piece)"** no catálogo, sem mexer nos kits atuais.
Fonte reproduzível: `tools/criar_mine_piece.gd` (publica em `mapas/skills/`, ids `mp_*`).
Aparecem no menu de personagem do singleplayer e na loja de frutas do Modo História
(miniatura com selo vermelho, `tools/gerar_imagens_frutas.gd -- <ids>`).

| Fruta | Z | X | C |
|---|---|---|---|
| Pika Pika no Mi (Mine Piece) | Raio de Luz Pesado (carregar) | Velocidade é Poder (alvo ≤ 8 m) | Chute de Luz (alvo ≤ 5 m) |
| Hie Hie no Mi (Mine Piece) | Chuva de Bolas de Gelo | Bico de Faisão (carregar) | Campo de Estacas |
| Moku Moku no Mi (Mine Piece) | Cipó Branco | — | — |
| Nikyu Nikyu no Mi (Mine Piece) | Tapa de Pata (carregar) | Soco do Urso (alvo ≤ 10 m) | Choque do Urso |

- **Testes:** `tools/dev_tests/test_mine_piece.gd -- historia` (22/22) e `-- arena` (18/18):
  loja, compra, equipar e dano exato por acerto na escala de cada modo.
- **Capturas:** `tools/dev_tests/capturar_mine_piece.gd [-- esquerda]` →
  `art_src/validation/mine_piece/`.
- **Pendente:** jogar de verdade (sensação, leitura, balanceamento contra as frutas atuais);
  rede (os golpes passam pelo mesmo caminho das frutas do Builder, não testado com 2 jogadores);
  V e F livres nessas frutas.
- Os rascunhos em `rascunhos/` são a primeira versão (17/10) e ficaram **superados** pela
  ferramenta acima; servem só de histórico.

## O que há

| Fruta | Ficha (biblioteca-de-mecanicas/fichas/poder/) | Rascunhos (`rascunhos/`) |
|---|---|---|
| Pika Pika | `pika-pika-skills-mine-piece.md` | `pika_laser_pesado`, `pika_chute_de_luz`, `pika_velocidade_e_poder` |
| Hie Hie | `hie-hie-skills-restantes-mine-piece.md` (+ `hie-hie-ice-age-mine-piece.md`) | `hie_bico_de_faisao`, `hie_bola_de_gelo`, `hie_estacas_do_solo` |
| Moku Moku | `moku-moku-skills-mine-piece.md` | `moku_cipo_branco` |
| Nikyu Nikyu | `nikyu-nikyu-skills-mine-piece.md` | `nikyu_pad_ho`, `nikyu_ursus_shock`, `nikyu_kuma_punch` |

Só entram rascunhos do que o SOP **ainda não tem**; o que já existe (Raio, Yata, Yasakani,
Punho de Fumaça, Pata Gigante etc.) está comparado nas fichas.

## Como usar os rascunhos

- Ficam em `docs/`, **fora de `mapas/skills/`**, para o jogo não carregá-los sozinhos.
- Passam no `DadosSkill.validar` (10/10, rodado headless em 2026-10-17). **Não foram
  importados no jogo nem testados em partida**; poses, sons e visuais são genéricos.
- Para usar: copiar para `mapas/skills/`, abrir no Skills Builder, ajustar e registrar a
  tecla em `frutas.json`. Cuidado com tecla já ocupada pela fruta.
- Dano em escala SOP é **proposta**: âncora Laser 1 (17) ↔ Raio de Luz (98), fator 5,76.
  Hie, Moku e Nikyu não têm âncora e usam o mesmo fator só como ponto de partida; o dono do
  projeto decide os números finais. `descricao` começa com `[RASCUNHO Mine Piece, a revisar]`.

## Fora deste lote (gatilho para voltar)

- Estilo de combate base (`SkillBaseSkillProcedure`: Slash, Assault, Iai, Rifle…), Mera, Gomu,
  Goro, Magu, Ope e demais frutas: quando o dono pedir o próximo lote.
- Comportamento das entidades `PadEntity`, `FistEntity`, `TornadoEntity`, `EntityIceBallEntity`,
  `TreeRootEntity`, `EntityImpactWaveEntity` (acerto e dano reais): ler antes de implementar
  qualquer rascunho que dependa delas.
- Fonte: `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/` (descompilado com
  Vineflower; o `rea` não foi necessário).

## East Blue (17/10/2026)

Personagens, inimigos e NPCs do East Blue do mod numa ilha nova do Modo História. Tudo em
[`docs/EAST_BLUE_PLANO.md`](../../EAST_BLUE_PLANO.md); dados factuais extraídos em
`east_blue/personagens.json` e `east_blue/tecnicas.json`.
