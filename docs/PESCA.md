# Pesca, barra de itens e o pescador — Modo História (03/10/2026)

> Continuação: lojas dos NPCs, moedas, menu de técnicas e as frutas da arena na
> história estão em `docs/LOJAS_E_FRUTAS_DA_ARENA.md`.

Pedido do dono (03/10/2026): minigame de pesca; equipar a vara no N; um NPC que dá a
vara de graça, no catálogo do editor; barra de itens no centro inferior (a Rocket como
foguete, espada, pistola, estilo de luta, vara), com a tecla do quadrado (1–6)
liberando o uso daquele item.

## Decisões do dono

| tema | decisão |
|---|---|
| barra 1–6 | **um item ativo por vez**; a tecla do ativo de novo solta (volta para a luta) |
| minigame | **tensão da linha**: segurar recolhe, soltar dá linha, a zona verde enche a captura, passou do limite arrebenta, peixe raro puxa mais forte |
| pescador | **personagem Base do elenco** com outra cor; **E** para conversar |

## Como se joga

1. Falar com o pescador (**E** perto dele): ganha a vara (uma só, de graça).
2. **N › PESCA › Equipar**: a vara entra na barra já **ativa** (punho = 1, fruta = 2
   se tiver, vara = a seguinte).
3. Com a vara ativa, mirar a água e **clicar**: arremessa até 14 m à frente da câmera
   (o ponto de água mais longe sem parede no caminho; sem água, avisa).
4. A boia boia; beliscadas falsas; de **2 a 6 s** ela **afunda** com um "ploc":
   **0,8 s** para clicar. Antes disso o clique recolhe ("cedo demais"); perder a janela
   = o peixe solta a isca e a espera recomeça.
5. Briga: medidor à direita do centro. **Segurar** sobe a tensão, **soltar** baixa; o
   peixe puxa sempre e dá **corridas** anunciadas 0,4 s antes por um "!" piscando —
   solte! Na zona verde a barra dourada enche; fora dela esvazia; zerou = escapou;
   tensão no topo = **arrebentou**.
6. Pegou: o peixe salta para a mão e vai para **N › PESCA** (nome e raridade).

Com a vara ativa o soco e a fruta ficam travados (`capacidades`). Trocar de item,
nadar, assumir o leme ou montar recolhe a linha na hora; afastar-se mais de 26 m da
boia arrebenta a linha.

## Números (fonte: `src/historia/pesca/tensao_da_linha.gd`)

Zona verde 0,35–0,75 · segurar +0,55/s · soltar −0,75/s · captura começa em 0,2 e
perde 0,10/s fora da zona (0,20/s com a linha frouxa).

| raridade | chance | força | segundos no verde para pegar |
|---|---|---|---|
| comum | 60 % | 0,15 | 5 |
| incomum | 28 % | 0,25 | 6,5 |
| raro | 10 % | 0,38 | 8,5 |
| lendário | 2 % | 0,50 | 11 |

Medido com robôs (30 sementes, 0,2 s de reação): soltar no aviso pega **30/30** em
todas; sempre segurar arrebenta 30/30; nunca segurar escapa 30/30; no lendário,
ignorar o aviso arrebenta ~metade. Tempo médio de briga: 4,8 s (comum) a 11,7 s
(lendário).

## Arquivos

| arquivo | papel |
|---|---|
| `src/historia/pesca/pescaria.gd` | estados (arremesso → espera → mordida → briga → recolher), entrada, metas de pose |
| `src/historia/pesca/tensao_da_linha.gd` | a briga, pura e determinística pela semente |
| `src/historia/pesca/tabela_de_peixes.gd` | 35 peixes da loja (categoria pesca): nome em português e raridade |
| `src/historia/pesca/vara_de_pesca_visual.gd` | vara no `item_handle`, linha, boia, respingos, peixe saltando |
| `src/anim/pesca_poses.gd` | braços (segura / arremesso / puxando) — convenção +X = frente |
| `src/ui/PescaHud.gd` | medidor de tensão e captura, "!" da mordida e da corrida |
| `src/ui/BarraDeItensHud.gd` | a barra 1–6 (ícones em `assets/ui/barra/`) |
| `src/historia/npcs/npcs_da_ilha.gd` | peças com comportamento de NPC viram NPC vivo; E abre a loja do mais perto |
| `src/historia/npcs/npc_da_ilha.gd` | o NPC genérico (rig Base pintado pela ficha; o pescador segura a vara) — desde a rodada das lojas |
| `src/historia/npcs/loja_do_pescador.gd` | vara de graça + compra de peixe (ver `docs/LOJAS_E_FRUTAS_DA_ARENA.md`) |
| `tools/importar_npcs_na_loja.gd` | exporta o Base pintado de cada NPC e põe na loja (categoria NPCs) — idempotente |

A vara segue a MÃO, mas a direção dela é imposta no espaço do corpo
(`VaraDePescaVisual.orientar`), para não depender do sinal das juntas. O corpo vira
para a boia pela meta `frente_forcada` (ramo no `Player`, antes de `_em_combate`).

## Pôr o pescador no mapa

Editor do mapa → loja → aba **NPCs** → **Pescador**. No jogo a peça vira o NPC; no
"Testar" do editor ela continua modelo parado. Sem pescador no mapa, o F8 tem
**Pesca › Ganhar vara de pesca**. O mapa da história **não** foi alterado: pôr o
pescador é decisão do dono.

## Testes

- `tools/dev_tests/test_pesca.gd` — lógica (robôs, sorteio) + jogo (47 checagens).
- `tools/dev_tests/test_npcs_e_lojas.gd` — os três NPCs, as lojas, o exportador e o E (substitui o `test_npc_pescador`).
- `tools/dev_tests/test_barra_de_itens.gd` — teclas 1–6 de verdade (15).
- `tools/dev_tests/capturar_pesca.gd` — fotos (vara, linha e boia, briga com HUD, pescador).

## Limites conhecidos e gatilhos

- **Peixe por lugar/isca**: rio e mar sorteiam a mesma tabela. Gatilho: o dono pedir
  peixe por região ou iscas → a raridade/lugar vira campo do catálogo (editável na loja).
- **Só no jogo local**: pose e frente da pesca são metas do jogador local; a história é
  um jogador. Gatilho: história em rede → replicar `pesca_pose` como os `net_*` do parkour.
- **Peixe não vende nem cozinha**: só se guarda. Gatilho: loja/comida da história.
- **Espada e pistola na barra**: os ícones existem (`assets/ui/barra/`), mas a
  história ainda não dá espada nem pistola. Gatilho: o primeiro desses itens existir
  na campanha → um id a mais em `ProgressaoDoPersonagem.ITENS_DA_BARRA` e
  `itens_da_barra()`.
