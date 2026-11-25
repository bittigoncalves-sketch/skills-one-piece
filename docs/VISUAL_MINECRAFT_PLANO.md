# Visual estilo Minecraft — blocos e GUIs (plano + checkpoint, 12/11/2026)

Pedido do dono: planejar e implementar a melhoria visual das GUIs e do sistema de blocos para ficar mais parecido com o Minecraft, usando o REA para entender
o que for preciso (e baixar mods bem avaliados do CurseForge como referência se faltasse arquivo). Respostas dele: **blocos com textura vanilla, sem contorno;
GUIs = tudo que o jogador vê no Modo História (HUDs de luta/fruta ficam); blocos primeiro, GUIs depois.**

## Fonte dos recursos
Jar 1.20.1 (`~/Documents/curseforge/minecraft/Install/versions/1.20.1/1.20.1.jar`) — o mesmo que o REA abriu (ver `docs/INVENTARIO_MINECRAFT.md`). Nada precisou ser baixado:
texturas de bloco/item/`widgets.png`/`icons.png`/`inventory.png` já estavam em `assets/minecraft_local/` (fora do git, Mojang); as que faltavam (fonte, fundos,
janelas de container/conquistas) saem de `tools/minecraft/copiar_gui_do_jar.py` (zipfile direto no jar — o REA já provou o conteúdo; a extração dele some do /tmp).
Sem `assets/minecraft_local/` o jogo roda **igual ao de antes** (cada peça tem `disponivel()`/fallback).

## Decisões (benefício · impacto futuro · manutenção · extensão · custo · risco)
| Decisão | Por quê / trade-off |
|---|---|
| `Texture2DArray` + UV em unidades de bloco + `textureGrad` (um shader, uma chamada por seção) | Imediato: a malha gulosa continua com retângulos grandes (a textura repete sozinha). Extensão: tipo novo = 1 linha em `TexturasDeBloco.TABELA`. Risco: mipmap na costura (resolvido com `textureGrad`). Alternativa rejeitada: atlas com UV por bloco — quebraria a fusão gulosa (triângulos ×N). |
| Tinta de bioma ASSADA na imagem (grama/folha/água) | Custo zero em tempo de desenho; risco: um bioma só (planície). Gatilho: ilha com bioma diferente (neve/deserto) → tinta por vértice (`COLOR`). |
| Terreno por camadas: grama / 3 de terra / pedra (`GeradorDeRelevo.camada_em`) | Substitui a cor única `TERRENO` (decisão antiga de 22/10). Custo: mais materiais na malha → mais retângulos (medir no jogo: gatilho > 3 000 chamadas de desenho ver `MUNDO_VOXEL_PLANO`). |
| Folhas opacas (como o gráfico "rápido") | A malha corta a face entre folhas; o furo do cutout mostraria o outro lado da copa. |
| Fonte bitmap montada em tempo de execução (`FonteMinecraft`), tema único (`GuiMinecraft`) aplicado nas 5 janelas da história + `EstiloDaHistoria` com ramo vanilla | Um lugar só muda a cara (146 usos de `EstiloDaHistoria`). Limite: `FIXED_SIZE_SCALE_INTEGER_ONLY` arredonda o `font_size` ao múltiplo de 8 (12–17 → 16). |
| Corações/fome/XP no layout medido de `Gui.renderPlayerHealth` (`HudMinecraft`); barra de vida antiga some, energia fica | Vida 24 HP = 10 corações (não a regra de 20 pontos do vanilla). |

## Entregue (validado)
- **Blocos:** `src/voxel/texturas_de_bloco.gd`, `bloco_minecraft.gdshader`, UV/camada na malha (`grade_voxel.gd`), terreno em camadas (`gerador_de_relevo.gd`),
  `relevo_das_ilhas.gd` usa o material do bloco quando há textura. Provas: vitrine (`captura_blocos_texturizados.gd`) e ilha real (`captura_ilha_texturizada.gd`) vistas em tela com GPU;
  testes `test_gerador_de_relevo` 14/0, `test_grade_voxel` 14/0, `test_blocos_com_forma` 44/0, `test_voxel_no_jogo` 10/0, `test_clique_de_blocos` 103/0, `test_visual_minecraft` 14/0.
- **GUIs:** `fonte_minecraft.gd` (ascii + acentos pt-BR), `gui_minecraft.gd` (botões 9-slice do `widgets.png`, painel grafite, tema), `estilo_da_historia.gd`, `central_de_janelas.gd`,
  mochila (título só "Crafting", quantidades em fonte vanilla, **prévia 3D do personagem no retângulo do boneco**), `hud_minecraft.gd` (corações/fome/XP), nome do item acima do HUD.
  Provas em tela: `captura_central_minecraft.gd`, `captura_ilha_texturizada.gd`; testes `test_mochila_minecraft` 27/0, `test_hotbar_inventario` 18/0, conquistas 9/0 e 11/0, `test_inventario_minecraft` 30/0.

## Limites declarados (o que NÃO foi feito / validado)
- Sem sombreamento por face nem oclusão ambiente (AO) no vértice — a luz é a do sol da cena. **Gatilho:** ficar "chapado" ao lado do vanilla → AO por vértice só em faces não fundidas (custo: perde a fusão gulosa nelas).
- Sem rachadura de quebra (`destroy_stage_0..9`), sem ícone isométrico de bloco na hotbar/mochila (usa a textura plana), sem tooltip vanilla (caixa roxa) — **gatilho:** pedido do dono ou próxima fatia de GUI.
- Tinta de bioma única; água sem animação (primeiro quadro do `water_still`); porta com textura inteira por metade.
- Telas com visual próprio não migradas (menu principal, customização, JanelaDeStatus interna, árvore de conquistas): só herdam fonte/botão quando dentro das 5 janelas. HUDs de luta/arena intactos (decisão do dono).
- Não validado: GUI em celular (`ToqueHud`), escalas de janela diferentes de 1280×720, várias ilhas/biomas, desempenho medido (FPS na captura ~65–80 com a ilha inicial, sem comparação formal antes/depois).
- A classe `PreviaDoPersonagem` nova na mochila monta o personagem ao abrir (um viewport extra enquanto a aba está aberta).
- `test_compila` falha por autoloads fora de contexto (`ScreenFX`/`FruitNet`), igual ao baseline; `ModoHistoria.gd:1043` (`colocar_civil`) tem erro pré-existente de `.new()`.

## Como reproduzir
`python3 -I tools/minecraft/copiar_gui_do_jar.py` (fontes/janelas) · `godot --headless --path . --editor --quit` (registra as classes novas) ·
`DISPLAY=:1 godot --path . -s tools/dev_tests/captura_ilha_texturizada.gd -- <pasta>` · idem `captura_central_minecraft.gd`, `captura_blocos_texturizados.gd` (-- <pasta>).

## Meta do dono (12/11/2026): "pelo menos 64 blocos e suas texturas, e personalização de todas as GUIs"
- **128 blocos novos** (`src/voxel/blocos_extras.gd`; ids 26–63 e 160–255): 10 tábuas, 7 troncos, 5 folhas, ~45 pedras/solos/minérios/blocos de metal, decoração (estante, mesa de trabalho, fornalha, abóbora, TNT…), 16 concretos e 16 terracotas. Cada um com nome, textura (topo/lado/base), dureza do `Blocks.java` e item; `test_visual_minecraft` 145/0 (≥ 64, ids/nomes únicos, todos com textura) e vitrine `captura_blocos_texturizados.gd` vista em tela com os 128. Limite: só cubos (sem laje/escada dos novos; gatilho no cabeçalho do arquivo).
- **Aba BLOCOS** na central (`catalogo_de_blocos.gd`): grade de slots vanilla com **ícone isométrico texturizado** (`ItensDeBloco._icone_texturizado`); clique = 64 na mochila, direito = 1. É o acesso ao jogador enquanto não há crafting/loot (gatilho: some atrás de modo criativo).
- **Todas as GUIs:** o tema vai na janela raiz (`GuiMinecraft.aplicar_global`, chamado no `GameFlow._ready`; `GUI_VANILLA=0` desliga): fonte, botões 9-slice, sombra de texto, pixels nítidos, tooltip roxo, campo de texto. `MainMenu` ganhou a paleta escura das telas de opções e perde os emojis (a fonte pixel não os tem). Vistos em tela: menu inicial, central (6 abas), mochila, jogo.
- **Fecho das GUIs restantes (mesma sessão):** `GuiMinecraft.ligar_normalizacao` (no `GameFlow`) dá o tema a toda tela de topo (filho de `CanvasLayer` não herda o tema da raiz) e, 3 quadros depois, normaliza os estilos próprios: cantos retos, sem sombra, painéis escuros em grafite com moldura preta, botões vanilla (o menu inicial conserva os de cor de ação), sem emoji. `CustomizacaoMenu` e `ToqueHud` (botões quadrados vanilla + fonte pixel) ganharam ramo próprio. Vistas em tela: loja, pesca, técnicas, status, ferramentas, customização, arena (HUD de vida/energia, placar, fruta, dicas), HUD de toque e botões do rodapé do menu (agora DC/GH/?).
- **Limites que ficam:** barras de vida/energia da arena mantêm cor e corte inclinado (são informação); alguns textos estouram a caixa com a fonte maior (ex.: "Boneco automático" na arena, nomes longos de técnica); janelas com `font_size` explícito arredondam a 8/16/24; o ToqueHud foi visto forçado (`forcar`), não num celular; roleta, ferraria e tripulação foram fotografadas (`captura_guis_ultimas.gd`) e estão temadas; o painel de bonecos da arena foi alargado (250→300) para o texto caber; sem comparação de FPS com 128 materiais.
- **Fecho 3 (mesma sessão):** `BarraHud` ganhou o ramo vanilla (retângulo com friso claro/escuro e moldura preta) — as barras de vida/energia/roll da arena e do jogo deixaram de ser as inclinadas; a roda da `RoletaHud` desenha os nomes na fonte pixel; roleta vista GIRANDO e revelada (`captura_guis_ultimas.gd`); HUD de toque visto dentro do Modo História com `ToqueHud.forcar` (`captura_toque_no_jogo.gd`; num aparelho real continua não testado — os botões se sobrepõem à barra de fome no canto direito, posição que já era dele). Capturas: `captura_arena_minecraft.gd`, `captura_guis_restantes.gd`.
- **Fecho 4:** `SobrevivenciaHud` sai da frente dos botões de toque quando `ToqueHud.ativo()` (visto no jogo, sem sobreposição). Bateria reexecutada depois de todas as edições (13 testes, ver mensagem final). `test_clique_de_blocos` dependia da carga da máquina (a colisão da seção refeita entra em threads; o tema só deixou isso visível) — agora espera `g.esperar_tudo()` antes de mirar, 3 execuções seguidas 103/0. Variável de ambiente `GUI_SEM_NORM=1` desliga só a normalização automática (depuração).
- `test_toque` dá 23 conferem / 3 divergem **com e sem** `GUI_VANILLA=0` (mesmo resultado): falha anterior ao tema, não regressão desta meta.
- **`test_toque` é anterior a esta meta:** no commit HEAD original (worktree limpo, sem nenhuma mudança minha) dá 22 conferem / 3 divergem — as mesmas 3 (joystick arma, jogador anda, pulo), causa fora do visual.
- **Fecho 5:** estados do tema fotografados numa folha (`captura_estados_do_tema.gd`): botão normal/hover/desabilitado, campo de texto, caixa de seleção, lista, controle deslizante, rótulo com acentos e tooltip vanilla — todos com a fonte e a textura do Minecraft (o "pressionado" usa a mesma textura do hover, por desenho). FPS (leitura do overlay do próprio jogo, mesma ilha e mesma posição, 3 capturas de cada): antes das texturas 80 FPS/12,5 ms; com texturas e tema 77–82 FPS/12,1–13,0 ms — sem queda visível; não é benchmark formal.
- **O que não dá para fechar daqui, por natureza:** teste num aparelho celular real (só `ToqueHud.forcar`); "todo estado de toda tela" é um conjunto aberto (cada janela do jogo tem dezenas) — o que está coberto é a lista de telas acima, mais a folha de estados do tema, que vale para qualquer tela que use controles padrão.

## Corações → barra de vida (12/11/2026)
Pedido do dono: "modifica os corações para barrinha em cima da barra de energia". `HudMinecraft.CORACOES = false` (os corações não são desenhados; ficam a fome e o XP) e a `HistoriaHud` não chama mais `VidaEnergiaHud.usar_coracoes()`: a barra de vida do canto superior esquerdo volta, ACIMA da barra de energia. Gatilho para religar os corações: o dono pedir. Teste: `test_pao_e_barra_de_vida`.

## Drop de pão (12/11/2026)
Pedido do dono: "libera o drop de pão ao matar inimigos". `ModoHistoria._sortear_pao`: bandido, inimigo do mapa e personagem do East Blue (capanga inclusive) soltam 1–2 pães com 60 % de chance, direto nas provisões (Comida da barra); o aviso de abate mostra "+1 pão". Boneco de duelo e animais não soltam. Ajuste: `CHANCE_DE_PAO` / `PAES_POR_DROP`.
