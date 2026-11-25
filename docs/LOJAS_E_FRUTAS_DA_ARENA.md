# Lojas dos NPCs, menu de técnicas e frutas da arena — Modo História (03/10/2026)

Pedido do dono (03/10/2026):
- loja do pescador para vender os peixes, 1 moeda por peixe, independente da raridade por enquanto;
- com a Rocket selecionada, um menu com as técnicas e o tempo que cada uma leva para recarregar se for usada;
- NPC domador, que vende animais de estimação novos por 1 moeda;
- NPC vendedor de frutas, que vende as frutas do singleplayer (arena) no Modo História, 1 moeda cada.

## Decisões do dono

| tema | decisão |
|---|---|
| moeda | o **ouro** da campanha (o que o status já mostra e o save já guarda) |
| frutas da arena | **kit da arena, escala da história**: mesmos golpes, energia 2–5 por técnica, recarga da arena, dano reduzido |
| fruta comprada | vai para o **inventário** (N › FRUTAS); come-se quando quiser, trocando a atual |
| domador | vende os **domáveis e os selvagens** |
| no mapa | NPCs **só na loja do editor** (aba NPCs); quem posiciona é o dono |

## As lojas (E perto do NPC; E ou ESC fecham)

| NPC | cores | o que faz |
|---|---|---|
| Pescador | capa amarela, calça azul-marinho, vara na mão | dá a vara de graça; compra peixe a 1 moeda (Vender 1 / Vender todos / Vender tudo) |
| Domador | verde e marrom | vende cada espécie a 1 moeda: os pets de corpo próprio (gaivota, caranguejo) e todo animal da loja com ficha, menos os chefes; vai para N › PETS |
| Vendedor de frutas | roxo | vende as 13 Akuma no Mi da arena a 1 moeda; vai para N › FRUTAS |

Desde 18/10/2026 o vendedor também tem a **Goro Goro (Mine Piece)** por 1 moeda: tradução do mod, R troca e Z usa (`docs/GORO_GORO_MINE_PIECE.md`).

Sem moeda, o botão Comprar fica apagado e a loja avisa "venda peixes ao pescador".
Os chefes ficam fora do domador (GATILHO: o dono pedir chefe à venda). A Rocket não
está no vendedor: é a fruta do mapa da história.

**Comer a fruta comprada (N › FRUTAS › Comer):**
- Sem fruta no corpo, come na hora.
- Com fruta no corpo, a linha pergunta "perde a Rocket?" e mostra Confirmar e Cancelar.
- A fruta antiga se perde; a comida já vem ativa na barra.

## Menu de técnicas

O painel aparece no canto inferior esquerdo só com a **fruta ativa** na barra 1–6.
Cada linha mostra a tecla, o nome e o estado:
- **recarga N s**: pronta, e esse é o tempo que leva para recarregar se for usada;
- **faltam N s**: usada, contagem regressiva;
- **sem energia**: mostra o custo.

Vale para qualquer fruta, a Rocket e as da arena.

Achado nesta rodada: esse HUD existia desde 22/09, mas ficava **fora da tela** (posição
negativa sobre âncora inferior); o teste lia só o texto. Corrigido e agora medido
(`docs/erros.md`).

## Frutas da arena na história

A ficha de cada fruta da arena é **gerada** a partir da arena (`PerfilDeFrutas.da_arena`).
É uma fonte só: uma fruta nova na arena aparece no vendedor sem arquivo novo.

| número | história | de onde vem |
|---|---|---|
| energia por técnica | Z 2 · X 3 · C 3 · V 5 (energia máxima 10, regeneração 1/s) | `PerfilDeFrutas.CUSTO_DA_ARENA` |
| recarga | a que a arena aplica de fato | `SkillSystem.recarga_da_arena` |
| dano | arena × 250/2.048 ≈ 0,122 | vida do inimigo da história / vida do jogador na arena: o golpe tira do inimigo a mesma fração de vida que tira de um jogador na arena |
| bala da rajada, dreno da invisibilidade | número da arena × (custo Z da ficha / 180) | `Player.energia_do_modo`; no dreno soma-se a regeneração, então a invisibilidade dura ~16 s |

O dano escala em `Balance.novo(fruta, slot, escala)`, que é explícito e não mexe no molde.
Na arena todos esses caminhos devolvem os números de antes: sem ficha, custo 180, bala 10,
dreno 55/s, escala 1.

**Medido** (`test_frutas_na_historia`, boneco de 250 de vida):
- As 13 frutas lançam todas as teclas com a energia e a recarga da ficha.
- O maior golpe tirou 78 de 250 (Suna V); nenhum passa da metade da vida.
- Teclas que o próprio kit da arena desliga não aparecem: Bomu só tem Z e X, Suke só tem Z.

**Fiel à arena (não é da adaptação):**
- A rajada Z da Mera e da Hie cobra por bala, não por técnica.
- O Kurouzu e o Black Hole da Yami não gastam energia.
- O Mamaragan (V da Goro) cobra duas vezes, como na arena.
- O C da Goro zera a própria recarga ("o C fica para bem mais tarde", decisão antiga do dono).
- A Ope precisa da ROOM (Z) para X, C e V.

**Corrigido nesta rodada** (vale também para a arena, sem mudar número):
- Com arma de fruta sacada (pistola da Yami, armas da Buki), o combate direcional da
  história fica suspenso: o clique esquerdo atira em vez de socar, e o direito mira em
  vez de erguer a guarda.
- Trocar de fruta estando invisível (Suke) agora desfaz a camuflagem, que antes
  continuava drenando energia com a fruta nova.

## As frutas acertam todos os NPCs (05/10/2026)

Pedido do dono: as frutas trazidas para a história afetam **todos os NPCs**. Um dos
casos que ele viu: o Z, o X e o V da Bara não funcionavam. Decisão: tudo que luta ou
vive leva o golpe (inimigos do mapa, boneco de duelo, animais com os chefes). NPCs de
loja e os pets do jogador ficam de fora. As bestas do mar não são alvo porque não têm
vida no jogo: são só modelos de cenário.

Causas encontradas e corrigidas:
- **Grupo de alvo** `alvo_de_golpe` com o ajudante `AlvosDeGolpe` (`src/combat/alvos_de_golpe.gd`). Os pontos que procuravam alvo só em "player"/"enemy" passam a ver também o animal manso: Ope (alvo, ROOM), Yami, Pika, Bara, mira de arma, alvo do corpo a corpo e asas de anjo. Na arena o grupo fica vazio.
- **Centro do corpo** (`AlvosDeGolpe.centro`): a origem do animal é o pé, então quem mira ou traça linha até o alvo usa o meio do corpo. Antes, a Ope C/V batia no chão.
- **Núcleo sólido no inimigo do mapa**: a colisão do modelo é oca (triângulos), e a zona de golpe que o envolvia não o via.
- **Mão da Bara** mira o ponto do retículo a partir do próprio encaixe. Antes seguia uma reta paralela à mira e passava 1,2 m ao lado do alvo, inclusive na arena.
- **Braço da Gomu e investidas da Gura e da Bomu** usam a mesma regra: saem do corpo e miram o ponto do retículo (`AlvosDeGolpe.ponto_mirado`, `Player.rumo_ao_ponto_mirado`).
- **Mira do Modo História** ignora as hurtboxes de combate. Com o corpo grande da Gura, o retículo acertava a hurtbox do próprio jogador.
- **Pinça do X da Bara** fecha no ponto mirado. Antes, as duas mãos só se encontravam aos 6 m e passavam ~1 m de cada lado de um alvo a 4 m.
- **Sol do V da Mera** desce no ponto do retículo. Antes, ele nascia 8 m acima e voava paralelo à mira, caindo ~20 m adiante.
- **Leque do Z da Pika** se abre em torno do ponto do retículo. Antes, saía da mão paralelo à mira de ombro.
- **Agarrão da investida da Gura** procura no centro do corpo. Com a escala 2, a esfera passava por cima de bicho baixo e o soco nunca saía.
- **Campo do V da Hie** morde todo combatente (`take_damage`), não só `CharacterBody3D`. O inimigo do mapa é corpo estático.

Regra que ficou: golpe que nasce **longe da linha da câmera** (mão, alto da cabeça,
corpo) mira o **ponto** que o retículo marca (`AlvosDeGolpe.ponto_mirado`), nunca a
direção da mira. Na câmera de ombro, as duas retas são paralelas e não se cruzam.

Medição: `tools/dev_tests/test_frutas_acertam_npcs.gd`. Cada tecla de cada fruta é
usada de verdade contra um inimigo do mapa, um boneco e uma vaca, cada um em sua raia.
O critério: golpe que machuca um machuca os três, sem exceções desde 06/10/2026.

**Liberado e corrigido pelo dono em 06/10/2026:**
- **C da Goro (Shunshin):** o teleporte varre a cápsula do corpo, desliza em chão inclinado e para em parede ou corpo. De pé, não desce abaixo do chão. Antes, mirando um alvo próximo, o corpo ia 2,4 m para dentro do chão e morria no vazio, na arena também. Teste: `test_goro_shunshin`.
- **V da Pika (Chuva de Luz):** além da chuva aleatória (que agora acompanha o jogador, num raio de 50 m), cada alvo vivo a até **50 m do jogador** leva um raio guiado a cada 0,4 s, sem empurrão. São 25 raios de 32 em 10 s, que fecham o teto do V **por alvo**: 768 na arena, 93,75 na história. Sair do raio de 50 m é a defesa. Vale na arena e na história.

Sem dano por desenho (não contam): Z e X da Ope (ROOM e Shambles), V da Gomu (Gear 2) e Z da Suke (invisibilidade).
O C da Pika é de segurar: soltar a tecla encerra a barragem.

## Arquivos

| arquivo | papel |
|---|---|
| `src/historia/npcs/npc_da_ilha.gd` | NPC genérico: ficha (nome, cores, item na mão, loja), corpo Base pintado, balão de fala |
| `src/historia/npcs/npcs_da_ilha.gd` | peças do mapa com comportamento de NPC viram NPC vivo; E → loja do mais perto |
| `src/historia/npcs/loja_de_npc.gd` | base das lojas (linhas + executar; preço padrão 1) |
| `src/historia/npcs/loja_do_pescador.gd`, `loja_do_domador.gd`, `loja_de_frutas.gd` | as três lojas |
| `src/ui/JanelaDeLoja.gd` | a janela (estilo do inventário) |
| `src/ui/TecnicasHud.gd` | o menu de técnicas |
| `src/historia/frutas/perfil_de_frutas.gd` | `da_arena`, `frutas_da_arena`, `nome_da_fruta`, escala |
| `src/historia/progressao.gd` | `vender_item_de_pesca`, `comprar_pet`, `comprar_fruta`, `comer_fruta_comprada`, `frutas_compradas` (save) |
| `tools/importar_npcs_na_loja.gd` | põe os três NPCs na loja do editor (idempotente) |

NPC novo = uma ficha em `NpcDaIlha.FICHAS` + uma classe de loja + rodar o
`importar_npcs_na_loja.gd`.

## Testes

- `tools/dev_tests/test_npcs_e_lojas.gd`: loja do editor, exportador, os três NPCs vivos, E, as três lojas, comer com confirmação, save (42).
- `tools/dev_tests/test_frutas_na_historia.gd`: contas da escala, recarga contra a regra do Player, as 13 frutas em jogo, arma sem soco (45).
- `tools/dev_tests/test_barra_de_itens.gd`: menu de técnicas (aparece, recarga, contagem, some, dentro da tela) (19).
- `tools/dev_tests/test_frutas_acertam_npcs.gd`: as 13 frutas × 4 teclas contra inimigo, boneco e vaca (~13 min; `SOP_FRUTAS=bara_bara` limita).
- `tools/dev_tests/capturar_npcs_lojas.gd`: fotos dos NPCs, das três lojas e do menu.

## Limites e gatilhos

- **Preço único (1 moeda):** decisão "por enquanto". GATILHO: preço por raridade ou espécie vira coluna na tabela do item.
- **Peixe só vende:** não há outro uso. GATILHO: comida ou receitas.
- **Toque (celular):** não há botão para o E nem para as lojas. GATILHO: a história ganhar modo celular.
- **NPCs fora do mapa da história:** o dono posiciona pela loja do editor.
