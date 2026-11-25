# Decoração das demais ilhas — 18/11/2026

Pedido do dono: "partir para o desenvolvimento das outras ilhas decorando". Ferramenta: `tools/mapa_ilha/decorar_ilhas.gd` (idempotente; peças `deco_<ilha>_*`; cópia do mapa antes;
não grava se o mapa mudou durante a execução; `-- --so=ilha_east_blue,wano` para uma parte; `-- --saida=<arquivo>` para ensaiar sem tocar no mapa vivo).

| Ilha | Estilo (decisão de design minha, a confirmar) | Peças |
|---|---|---|
| East Blue (hub, antes sem árvore nenhuma) | bosques de carvalho/bétula e pinheiros, arbustos, flores, pedras | 295 |
| Vila Foosha / Shimotsuki | jardins: arbustos, flores, pedras; carvalhos / cerejeiras | 182 / 182 |
| Marinha 153 | gramado com pedras e poucos pinheiros | 84 |
| Acampamentos pirata / bandido | pinheiros, toras e pedras | 72 / 78 |
| Water Seven | palmeiras, arbustos e flores | 150 |
| Wano | cerejeiras e pinheiros, pedras, flores | 144 |
| Shandora | palmeiras grandes, cogumelos gigantes, arbustos, pedras | 190 |

Só planta em solo de capim (código 0 ou 5), fora de trilha (2/3/6), praia, água, barranco (> 1,2 m) e de qualquer peça existente (construção, NPC, personagem). Árvores saem 1,4× a faixa do estilo.
Teste: `tools/dev_tests/test_decoracao_ilhas.gd` (contagem mínima, ids únicos, dentro da placa, nada sobre construção). Capturas conferidas: East Blue (solo e aérea), Wano.
**Medido** (`medir_montagem.gd`, headless, mapa vivo inteiro, TODAS as ilhas de uma vez): 4.567 peças, 4,8 s com cache frio (terreno 1,4 s, modelos 3,4 s) e 1,5 s com cache quente. O jogo monta por ilha
(`streaming_de_ilhas`), então o custo real por chegada é menor; o quadro por segundo em jogo NÃO foi medido com a decoração. Antes (mapa do commit `9301956`, só 685 peças) a mesma conta dava 1,2 s: não é comparação de igual para igual.
**GATILHO de desempenho:** montagem de uma ilha > 2 s ou quadro < 50 FPS na RTX 3050 → reduzir `qtd` nos `ESTILOS`.
**Não feito:** a ilha inicial e a dos macacos têm geradores próprios; não pintei solo de mata (só vegetação).
**GATILHO:** o dono pedir outro estilo por ilha → editar `ESTILOS` e rodar de novo (o apaga e refaz sozinho).

## Desempenho em jogo (medido em 18/11/2026, janela 1280×720, RTX 3050, jogador parado 3 s depois de chegar à ilha)
Mesmo mapa antes (cópia `baseplate_antes_decoracao_fdfec8157ec2.json`) e depois da decoração: **East Blue** 47,1 → 45,0 FPS (18.105 → 21.819 nós); **Foosha** 51,1 → (decorada) ~52,3 FPS.
Outras ilhas com decoração: Macacos 49,9; Wano 51,8; Shandora 52,2 FPS. Tempo de chegada (montagem) igual (5,6 s no East Blue). Custo da decoração ≈ −4 % de FPS nas ilhas mais carregadas; dentro do gatilho.
