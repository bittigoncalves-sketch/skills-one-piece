# Pokébola: estoque e probabilidade de captura (08/11/2026)

Pedido do dono: 3 pokébolas a cada 5 minutos; a chance de capturar depende da raridade do inimigo e da vida dele; pesquisar as
probabilidades das pokébolas de Pokémon.

## Pesquisa (Pokémon, Gerações III/IV)
Fontes: [Bulbapedia — Catch rate](https://bulbapedia.bulbagarden.net/wiki/Catch_rate),
[Dragonfly Cave — calculadora Gen III/IV](https://www.dragonflycave.com/gen4capturecalc.aspx),
[Bulbapedia — Great Ball](https://bulbapedia.bulbagarden.net/wiki/Great_Ball), [Ultra Ball](https://bulbapedia.bulbagarden.net/wiki/Ultra_Ball).

- `a = (3·HPmax − 2·HP) · taxa_de_captura · bola · status / (3·HPmax)`; `a ≥ 255` = captura garantida; nunca abaixo de 1.
- Bola: Poké 1× · Great 1,5× · Ultra 2× · Master garantida. Status: sono/gelo 2× (2,5× da Ger. V em diante), paralisia/queimadura/veneno 1,5×.
- Taxa de captura vai de 3 (lendários) a 255 (Rattata, Pidgey); 190 Pikachu; 45 Charmander/Dragonite.
- 4 "chacoalhadas", cada uma passa com `(a/255)^¼`; só captura se as 4 passam → chance por bola = `a/255`.
  **Não confirmado** nas páginas lidas: a conta de ponto fixo `b = 1048560 / ⁴√(16711680/a)`; vem do conhecimento geral da série.

## No jogo (`ProbabilidadeDeCaptura`, `Recrutamento.tentar`, `CapturaDeInimigos`)
- **Raridade = dificuldade** (o XP de abate que o jogo já calcula): ≤5 comum (taxa 255) · ≤20 incomum (120) · ≤75 raro (45) ·
  ≤150 muito raro (15) · >150 lendário (3). Chefes continuam não capturáveis.
- **Vida**: qualquer vida pode ser alvo; menos vida, mais chance (a regra antiga "só abaixo de 25 %" saiu).
  Ex.: comum a meia vida 67 %; lendário a meia vida 0,8 %.
- **Estoque**: começa com 3, +3 a cada 5 min de jogo (teto 99), gasta 1 por arremesso; vai no save (`sistemas["pokebolas"]`).
- O arremesso mostra "Escapou! Chacoalhou N× · raridade · chance X% com a vida em Y%".
- Só existe a Pokébola comum (1×); `BOLAS` já traz Great/Ultra para quando existirem.
- GATILHO: ajustar as faixas de raridade (decisão minha, em XP) quando o dono definir raridade por espécie no catálogo.
