# Combate e progressão — pedido de 23/10/2026 (checkpoint)

Pedido do dono: "quando o jogador colidir com um meio bloco correndo ao invés de simular um
pulo [...] ele deve passar para cima do meio bloco como acontece ao andar normalmente.
adicionar knockback e som de recepção do dano no jogador o knockback aplicado deve ser no
mesmo estilo do minecraft, diminuir o dano do soco e aumentar o dano das skills, aumentar a
energia por nivel ao invés de por status, recaucular nivel máximo sem o status de energia,
cada nivel concede 100 de energia".

## Decisões do dono (23/10/2026)

- Dano: **soco −50 %, técnicas +50 %** (Modo História).
- Knockback **completo** do Minecraft no jogador: empurrão fixo, pulinho, 0,5 s invulnerável, som.
- Energia **100 × nível**; o atributo Energia sai e os pontos gastos nele **voltam livres**.
- Nível máximo = o nível que **enche os atributos com limite** (Força 42 + Constituição 30 + Vida 30
  = 102 pontos, 5 por nível) → **22**. Inteligência não entra (sem limite e sem efeito).
- Custos de energia escritos para a barra de 10 → **×10** (técnicas e regeneração); pulo/dash no ar
  ficam 30/20.

## O que mudou

| Frente | Arquivo | Validação |
|---|---|---|
| Correndo sobe meio bloco/escada sem vault | `src/player/parkour_controller.gd` (`_livre_acima_do_degrau`) | `test_subir_degrau` 6/6 |
| Knockback Minecraft (só história) | `src/player/knockback_minecraft.gd`, `Player.take_damage`/`_aplicar_knockback`/`_etapa_mover`, `ModoHistoria.instalar_combate_direcional` | `test_knockback_minecraft` 10/10 (pulinho 0,94 m, 2,18 m, 2º quadro) |
| Som de dano do jogador | `assets/audio/dano_do_jogador.wav` (fonte `art_src/audio/gerar_dano_do_jogador.py`), `AudioFX.dano_do_jogador` | espectrograma + toca no teste; **ouvido não validado** |
| Soco × 0,5 / técnicas × 1,5 | `Balance.HISTORIA_*`, `ExecutorCorpoACorpo.multiplicador_desarmado` (só no estilo desarmado), `Player.escala_de_dano_da_fruta`, `PerfilDeFrutas.escala_das_tecnicas`, Rocket, Goro | `test_dano_soco_e_tecnicas` 9/9, `test_espada_historia` (espada intacta) |
| Energia 100 × nível; teto 22 | `progressao.gd` (`ENERGIA_POR_NIVEL`, `NIVEL_MAXIMO` calculado), `JanelaDeStatus.gd` | `test_progressao`, `test_barba_negra`, `test_vida_energia_historia` |
| Custos ×10 | `PerfilDeFrutas.CUSTO_DA_ARENA`/`REGEN_DA_ARENA`, `rocket.tres`, Mine Piece `ENERGIA_POR_CUSTO`, Goro, giro da espada, machado; Builder fica (já em barra de 100) | `test_goro_mine_piece`, `test_frutas_na_historia`, `test_mine_piece` 12/0 |
| Bug achado: save sem fruta virava Ope | `CatalogoFrutasMinePiece.atual("")` | `test_progressao` TUDO OK |

Testes de duelo (`test_contato_historia`, `test_defesa_historia`) desligam o knockback Minecraft do
jogador: medem geometria de contato parada, e o empurrão de 2 m desmontaria o "lado a lado".

## Pendências e gatilhos

- **Magu Magu fora do +50 %** (decisão do dono, 23/10/2026): com o bônus um golpe tirava 132 de 250;
  ela já tem dano elevado próprio. `Balance.HISTORIA_SEM_BONUS_DE_TECNICA`.
- Knockback Minecraft + combate direcional: o empurrão de 2 m e a invulnerabilidade quebram combos
  de inimigo no jogador (é o comportamento do Minecraft). Gatilho: se o duelo ficar fraco, reduzir
  `HORIZONTAL` ou desligar o pulinho só no duelo.
- Ilhas com teto acima de 22 (East Blue 30 … Shandora 60) passam a valer 22.
- Falhas que já existiam e não envolvem esta frente: Rocket "nasce sem perfil"/Z sem disparo,
  recrutamento de personagem Mine Piece, `test_inimigos_historia` (XP 150 fora de 5–20),
  `test_espada_historia` "começa com mãos livres", `test_giro` "HUD some sem espada",
  `test_ilha_inicial` (pé), `test_agua` (submerso), `test_compila`.
