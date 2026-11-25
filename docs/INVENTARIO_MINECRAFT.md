# Inventário estilo Minecraft — análise (REA sobre o jar 1.20.1) e plano (10/11/2026)

Pedido do dono: "um inventário estilo Minecraft usando o REA para analisar o **Minecraft**" (a primeira leitura, "o mod", foi corrigida por ele). Decisão anterior dele: **mochila fiel ao Minecraft**.

## O que o REA mostrou (jar `~/Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar`, SHA-256 `56b71336…bb0f`)
`open_binary` + `extract_artifact` (a resposta passa do orçamento do MCP, mas a pasta `/tmp/rea-extracted-*` é criada). O jar traz **recursos** (texturas, receitas, textos, tags); as classes
estão ofuscadas — o código dos menus segue pela receita da memória `minecraft-fonte-vanilla-jar-curseforge` (mapeamento Mojang + Vineflower), se for preciso.
- `gui/container/inventory.png` (256×256, área útil 176×166). **Layout MEDIDO na própria textura** (46 molduras de slot 18×18, canto +1,+1 = origem do item):
  armadura x=8, y=8/26/44/62 · mão secundária (77, 62) · grade 2×2 (98/116, 18/36) · resultado (154, 28) · mochila 3×9 em x=8+18·c, y=84/102/120 · hotbar y=142.
- Receitas: 1174 JSON — 590 `crafting_shaped`, 232 `crafting_shapeless`, 201 `stonecutting`, 70 `smelting`, 24 `blasting`, + fornalha/fumaça/fogueira, `smithing_*` e 16 especiais. A grade 2×2 só usa `crafting_*` ≤ 2×2.
  Ingredientes: `{"item"}`, `{"tag"}` (tags em `data/minecraft/tags/items`) ou lista de alternativas. O mod Mine Piece usa o MESMO formato (`mapas/east_blue/receitas_do_mod.json`).
- Ordem dos slots do `InventoryMenu` (a que o jogo usa): 0 resultado · 1–4 grade · 5–8 armadura (cabeça→pé) · 9–35 mochila · 36–44 hotbar · 45 mão secundária.
- Recursos copiados para `assets/minecraft_local/` (fora do git, Mojang): `tools/minecraft/copiar_da_extracao.py <pasta do REA>`.

## Mecânica de clique (a do Minecraft, implementada em `InventarioMinecraft`)
Esquerdo: pega tudo / coloca tudo / junta até o limite / troca. Direito: pega metade (arredonda para cima) / coloca UM. Shift: mochila↔hotbar, armadura/grade → mochila, item de armadura → slot certo, resultado → fabrica em lote.
Número 1–9: troca o slot sob o mouse com a hotbar. Armadura só aceita a peça do slot. Limite de pilha: 64 (16 ovos/bolas/placas; 1 ferramentas, armas, armaduras, baldes…).

## Plano (fatias)
1. **Modelo** `InventarioMinecraft` + regras de itens + receitas 2×2 + persistência na progressão + testes. (feito nesta fatia)
2. **Ligação com o mod:** `ItemHandlerHelper.giveItemToPlayer`/`IItemHandler` do jogador usam o inventário real; o contador de biscoitos passa a ser a contagem do item; mão/armadura sincronizam com `McEntidade.setItemSlot`.
3. **Janela** `MochilaMinecraft` (página da central, textura vanilla local, arrastar/soltar, tooltip, ícones dos itens). (feito nesta fatia, versão base)
4. Falta: barra de hotbar na tela, soltar item no chão (Q), baú/fornalha/bancada 3×3, durabilidade e encantos, painel de personagem ao lado, arte voxelizada dos itens (regra do dono para arte de mod — aqui é Minecraft vanilla, local).

## Estado (10/11/2026, noite) — fatias 1–3 entregues
- `src/inventario/` (`InventarioMinecraft`, `RegrasDeItens`, `ReceitasMinecraft`) — 30 testes (`test_inventario_minecraft`).
- Progressão guarda `inventario` (salvo no personagem; saves antigos migram o contador de biscoitos). `ItensDoMod`/`item_do_mod` viram fachada do inventário.
- `McEntidade.Manipulador` (`IItemHandler`): enxerga a mochila e insere/extrai de verdade; `JogadorDoMod.sincronizar_equipamento`: hotbar selecionada, mão secundária e armadura → `setItemSlot`.
- Janela `src/ui/mochila_minecraft.gd` = aba MOCHILA do M (textura vanilla local; sem ela, painel próprio no mesmo layout) — 20 testes (`test_mochila_minecraft`), mas **nada visto numa janela**.
- Limites declarados: receitas só as de 2×2 (sem bancada 3×3, fornalha, pedra, ferraria); ícones de BLOCO usam a textura plana (sem cubo isométrico); sem durabilidade/encantos; a hotbar não aparece na tela
  e a barra de itens 1–4 do jogo continua separada (mão do jogo ≠ mão do inventário); os itens do jogo (fruta, vara, pokébola…) ainda não são itens do inventário.
- Próximo: barra de hotbar na tela + rolagem; soltar item (Q) e coletar do chão; unificar a barra de itens do jogo com a hotbar; bancada 3×3.

## E abre o inventário (10/11/2026, 22:37)
- **E** (Modo História): com algo para interagir (NPC, baú) a interação continua com prioridade; senão abre a central na aba MOCHILA (`HistoriaHud.abrir_mochila`). Com a mochila aberta o E a fecha (como M/ESC). O E antigo (liga/desliga a Observação) não dispara na história (`Player._e_e_do_inventario`); na arena segue igual.
- **Espaços de armadura e de itens:** os 4 slots de armadura e a mão secundária mostram o ícone-fantasma vanilla quando vazios (capacete, peitoral, calça, botas, escudo), e a janela traz os títulos "Crafting" e "Inventory". Os 36 slots de item (mochila 3×9 + hotbar) e a grade 2×2 já eram o layout vanilla.
- Teste: `test_mochila_minecraft` 24/0. `test_npcs_e_lojas` e `test_naufragios` falham por `FruitNet`/`GameFlow` fora do contexto de autoload (já era assim).

## Inventário central e hotbar (10/11/2026, 22:58)
- **Itens do jogo no inventário** (`src/inventario/itens_do_jogo.gd`): luta, fruta, espada, vara, machado, água, comida, pokébola e bandeira são itens `jogo:<id>` (limite 1). A posse continua da progressão (`itens_possuidos`); `sincronizar_itens_do_jogo` põe no inventário o que o personagem tem (slot padrão fixo: luta 1, fruta 2, espada 3, vara 4, machado 5, água 6, comida 7, pokébola 8, bandeira 9; slot ocupado → primeira vaga) e tira o que perdeu.
- **A hotbar é o inventário:** `itens_da_barra()` = itens do jogo que estão nos slots 36–44, na ordem dos slots; a tecla 1–9 é o SLOT; arrastar o item na janela (E) muda o número; guardar na mochila tira da barra. O arranjo é salvo com o personagem.
- **Hotbar na tela** (`BarraDeItensHud`, no lugar da barra experimental): 9 slots vanilla com os números 1–9 sempre visíveis, destaque do ativo, ícones, quantidade (provisões de água/comida) e nome do item ativo. Item do jogo → `ativar_item` (um por vez; apertar de novo solta); item comum → vai para a MÃO (`setItemSlot`) e solta o item do jogo.
- **Mochila centralizada** na janela do M/E; mover itens liberado (esquerdo/direito/shift/número).
- Teste `test_hotbar_inventario` 18/0. `test_barra_de_itens` (barra antiga, quadrados 1–6) está OBSOLETO e, de todo modo, não roda neste contexto (`GameFlow`/`FruitNet`).
- Falta: rolagem do mouse para trocar de slot; item comum com ação (comer, usar); atualizar o `ToqueHud` (celular) para os 9 slots; ver em janela.

## Armas do Epic Fight no inventário (12/11/2026)
Pedido do dono: tirar os blocos de teste e pôr as armas do Epic Fight na hotbar e na mochila. Item `ef:<arma>` (`src/inventario/itens_epic_fight.gd`, limite 1, ícone e nome do mod); `ItensEpicFight.entregar` roda UMA vez por save (`inventario_ef_entregue`): retira o kit antigo de blocos (só nos slots e tipos do kit), põe as armas nos slots livres da MOCHILA (27 de 32 cabem; as demais seguem na aba ARMAS). Escolher o slot na hotbar equipa a lâmina (`BarraDeItensHud._empunhar_arma_ef`); trocar de slot a tira da mão. O kit de blocos NÃO é mais entregue; blocos vêm de quebrar o mundo. Teste: `test_inventario_armas_ef` (10/0), `test_clique_de_blocos` (103/0, agora põe os próprios blocos).
