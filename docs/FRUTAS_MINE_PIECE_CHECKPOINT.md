# Frutas Mine Piece — importação em andamento

Pedido de 19/10/2026: todas as frutas do mod, exceto a Goro Goro já importada;
nome da fruta + Mine Piece, reprodução dos originais por tradução/importação,
sem Skills Builder; venda no modo história por 1 moeda.

## Evidência e decisões

- Fonte local disponível: `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14`.
- A tag `data/minepiece/tags/items/devil_fruit.json` contém 41 itens: 40 frutas
  nomeadas e um item genérico. Escopo: 39 novas frutas, Goro preservada.
- Referência de integração: `docs/GORO_GORO_MINE_PIECE.md`, controlador próprio,
  R/Shift+R seleciona, Z usa; assets do mod com origem e hash registrados.
- Existem quatro versões anteriores no Builder (Pika/Hie/Moku/Nikyu); elas não
  contam como traduções concluídas. A migração precisa evitar duplicação na loja.
- Não publicar nomes com golpes genéricos para aparentar cobertura. Inventário
  extraído não significa técnica traduzida nem validação visual concluída.
- Não modificar saves reais, mapa do usuário nem alterações preexistentes.

## Etapas e validação

1. Extrair catálogo verificável da tag original: nomes, classes, seleção de
   técnicas, custos, condições, despachos Java e assets, com hashes da origem.
2. Traduzir técnicas e dependências por fruta; reutilizar as regras Minecraft já
   portadas onde o contrato coincidir. Preservar passivas e transformações.
3. Integrar equipar, controles, HUD e loja com preço 1; preservar a Goro.
4. Testar compra/comer/equipar, custos, recargas, condições, acertos,
   cancelamento, troca de fruta e limpeza. Compilar e rodar regressões do projeto.
5. Capturar a execução real e comparar com procedimentos/assets originais.

## Decisões do dono (20/10/2026)

- **Escopo:** "aplicação completa do mod" = as 39 frutas (fora: estilo base, haki, Grand Line).
- **Versões antigas do Builder** (Pika/Hie/Moku/Nikyu `mp_*`): a tradução nativa **substitui**
  na loja e no catálogo; save com a antiga equipada migra para a nova.
- **Ordem:** Logias primeiro (reaproveitam transformação elemental e voo da Goro), depois
  Paramecias, por último Zoans (precisam de modelo transformado).

## Arquitetura (decisão minha, declarada)

- Toda fruta nova entra por `CatalogoFrutasMinePiece.FICHAS` + um executor em
  `src/combat/frutas_mine_piece/<fruta>.gd` (molde: `ope.gd`). Loja, equipar e HUD já são genéricos.
- **Corpo de logia compartilhado** no `ControladorFrutaMinePiece` (transformação elemental + voo +
  trava de movimento), ligado por `"familia": "logia"` na ficha. Benefício: as 8 Logias usam o mesmo
  código; custo: a Goro continua com a cola própria dela (duplicação de ~70 linhas).
  GATILHO: na próxima mudança na Goro, migrá-la para o controlador genérico.
- Números do mod (ticks, blocos, fórmulas) literais; dano em `Balance.MINE_PIECE_<FRUTA>`.
  Assets do mod por `tools/mine_piece/importar_<fruta>.py`, fora do git.

## Etapas

| # | Entrega | Validação |
|---|---|---|
| L0 | Corpo de logia no controlador genérico | teste: transforma (4 golpes/25%), voa, técnica desfaz, troca limpa |
| L1 | Hie Hie (21 Partisan, 22 Pheasant Beak, 24 Ice Ball, 25 Ice Age; o 23 não está no ciclo do mod) + substituir `mp_hie` | teste por técnica (custo, recarga, dano, cancelamento) + captura |
| L2 | Moku Moku (21, 23, 25, 30) + substituir `mp_moku` | idem |
| L3 | Pika Pika (21, 22, 24, 27, 29, 30 passiva) + substituir `mp_pika` | idem |
| L4–L8 | Mera, Magu, Suna, Yami, Mori | idem |
| P1–P19 | Paramecias (Nikyu primeiro: substitui `mp_nikyu`) | idem |
| Z1–Z13 | Zoans (modelo transformado) | idem |
| FIM | Regressão: `test_compila`, `test_goro_mine_piece`, `test_ope_mine_piece`, loja | bateria |

Cada fruta só é publicada no catálogo depois de todas as técnicas dela traduzidas e testadas.

## Estado

- **19/10:** Ope Ope traduzida (só tem a técnica 23 no mod); `test_ope_mine_piece` 23/0 (rodado 20/10).
- **20/10:** plano acima.
- **21/10:** L0 e L1 concluídas. Referência: `docs/FRUTAS_MINE_PIECE.md`.
  - L0: `corpo_logia.gd`, Lentidão graduada, Shift, poses por ficha; `MundoMinePiece.Ataque` ganhou
    `ignora_guarda`, `ao_ferir`, `empurrao_extra` e a regra do dono da munição (`DONO`).
  - L1: Hie Hie `test_hie_mine_piece` 46/0 + captura. Substituição genérica (`"substitui"` na ficha) na
    loja e no save; corrigido: fruta Mine Piece equipada sumia ao recarregar o save.
  - Regressão: Goro 50/0, Ope 23/0, raid 14/14, `test_mine_piece` arena 18/0 e história 18/0 (Hie antiga
    agora conferida fora da loja), `test_loja_frutas_precos` só a falha anterior de fome/sede 1024 px;
    `test_compila` com os erros anteriores de autoload (ScreenFX/FruitNet/GameFlow), sem arquivo novo.
- **21/10 (tarde):** L2 Moku Moku concluída: `test_moku_mine_piece` 27/0 + captura. Novos compartilhados:
  `MunicaoMinePiece` (a lança da Hie passou a herdar; Hie 46/0 depois), `GolpesMinePiece.soco_forte`,
  `ImobilizacaoMinePiece` (+ `StatusFX.PRESO`), `MundoMinePiece.empurrar_area/dimensoes_b/pe_de`,
  `VfxFrutaMinePiece.render_do_mod`, controlador com `impulsionar`/`invisivel`, captura genérica
  `captura_fruta_mine_piece.gd` (substitui a da Hie) e `tools/mine_piece/compactar_java.py`.
  `test_loja_frutas_precos` passou a derivar o preço das traduções do catálogo.
  - Próximo: L3 Pika Pika (substitui `pika_pika_no_mi_mine_piece`).
