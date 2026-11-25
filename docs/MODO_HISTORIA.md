# Modo História

Guia-mestre do Modo História. A especificação original está em
[`references/modo_historia/modohistoriaplanejamento.pdf`](references/modo_historia/modohistoriaplanejamento.pdf)
(entregue pelo dono em 14/09/2026). **Os números do PDF são a fonte de verdade**;
este arquivo resume, registra as decisões de implementação e diz o que está feito.

---

## 1. Ordem de desenvolvimento (decisão do dono, 14/09/2026)

| Etapa | O quê | Estado |
|---|---|---|
| 1 | Mapa básico: **só a baseplate** e o jogador andando com WASD | ✅ feita em 14/09/2026 |
| 2 | **Editor de mapa** — o principal. Dentro do jogo, estilo Roblox Studio | ✅ v1 feita em 14/09/2026; loja de modelos .glb no mesmo dia |
| 3 | Status, XP, níveis, atributos, janela de personagem (tecla M) | ✅ sistema e janela feitos em 16/09/2026 (pedido do dono); faltam fontes de XP: inimigos e missões |

Etapa 2 ganhou em 16/09/2026: **Ctrl+G** (agrupar/separar) e **categorias** na loja.

---

## 2. Resumo da especificação (PDF)

- **Níveis 1 a 10.** A progressão normal para no **7**. Os níveis 8, 9 e 10 exigem
  uma **Missão Especial** cada; XP sozinho nunca fura a barreira. Enquanto
  bloqueado, o XP excedente continua guardado e é usado quando a missão termina.
- **XP para o próximo nível:** 1→2 1.000 · 2→3 3.000 · 3→4 7.500 · 4→5 15.000 ·
  5→6 30.000 · 6→7 60.000 · 7→8 120.000 + ME · 8→9 250.000 + ME · 9→10 500.000 + ME.
- **Ganho de XP:** inimigo comum 5–20, forte 25–75, mini-boss 100–300, boss
  500–2.000; missão simples 50–200, importante 300–1.000, principal 1.000–5.000.
- **Penalidade por inimigo mais fraco:** mesmo nível 100%, −1 75%, −2 50%, −3 25%,
  −4 ou mais 5%.
- **Atributos:** +5 pontos por level up, livres, 45 no total. Força, Inteligência,
  Constituição, Vida (HP máx = 20 + Vida × 5) e Skill.
- **Skills:** 0 a 4 (Não aprendida, Básica, Treinada, Avançada, Domínio). A janela
  mostra Combate, Espada e Fruta.
- **Estado inicial — Nível 1, Civil:** humano, HP 20, energia 10, ouro 0, atributos
  0, sem skills, `can_attack = false`, `can_dash = false`, `can_double_jump = false`.
- **Títulos:** Civil, Aprendiz, Lutador, Combatente, Especialista, Elite, Mestre |
  barreira | Super-Humano, Lendário, Ápice.
- **O combate é conquistado na história:** treinador → missão → treino → Skill de
  Combate 1 → `can_attack = true`.

---

## 3. Etapa 1 — o modo e o mapa

### Como abrir

- Menu principal → card **JOGAR** → **📜 MODO HISTÓRIA**.
- Direto, sem menu: `./jogar_historia.sh` (passa `-- --historia` ao jogo).

### Arquivos

| Arquivo | Papel |
|---|---|
| `mapas/historia/baseplate.json` | o mapa. **Fonte única** — o editor edita este arquivo |
| `src/world/mapa_arquivo.gd` (`MapaArquivo`) | lê, valida e grava o formato. Não cria nó |
| `src/world/mapa_montador.gd` (`MapaMontador`) | transforma o mapa validado em nós (jogo e editor) |
| `src/historia/ModoHistoria.gd` + `.tscn` | orquestrador da cena; `colocar_civil()` é o nascimento único |
| `src/ui/HistoriaHud.gd` | HUD mínima: menu do ESC, controle de toque, janela M e avisos |
| `src/ui/VidaEnergiaHud.gd` | barras de vida e energia no canto superior esquerdo (as da arena, só as duas), lidas do corpo a cada quadro |
| `tools/dev_tests/test_vida_energia_historia.gd` | barras: números, dano, concordância com a janela M e layout medido |
| `src/player/capacidades.gd` (`CapacidadesDoJogador`) | o que o corpo pode fazer |
| `autoload/GameFlow.gd` → `start_story()` | entrada no modo |
| `tools/dev_tests/test_modo_historia.gd` | 61 verificações |

### O formato do mapa

A baseplate tem **512 × 2 × 512 m**, topo em y = 0, cinza `#767676` com grade de 4 m
desenhada pelo cel shader da arena (a grade é em coordenada de mundo e vale para
qualquer peça). Spawn em `[0, 3, 0]`. O formato completo está no cabeçalho de
`mapa_arquivo.gd`. Cada peça tem `id`, `tipo`, `posicao`, `rotacao_graus`, `tamanho`,
`cor` (`#rrggbb`), `material` (`liso` ou `grade`), `grade_celula` e `colisao`.

| Tipo | Regra de tamanho |
|---|---|
| `caixa` | livre |
| `esfera` | x = y = z (diâmetro) |
| `cilindro` | x = z (diâmetro), y = altura, eixo em Y |
| `cunha` | livre; face em pé em −X, rampa descendo para +X |
| `modelo` | livre = a caixa que o modelo ocupa (ele é esticado para caber); exige `"modelo": "<id da loja>"`. Cor e material não se aplicam |

A física não estica esfera nem cilindro, por isso o arquivo não aceita. A validação
é rígida e junta **todos** os erros antes de recusar; um mapa inválido não monta
pela metade.

### As travas do Civil

A trava fica na **entrada do pedido**, não na tecla — assim o toque do celular, que
chama os mesmos métodos, também respeita.

| Capacidade | Onde trava |
|---|---|
| `can_attack` | `Player._request_melee` (única porta do buffer "attack": combo, chute giratório, queda esmagadora) e a tecla G |
| `can_dash` | `dash_bloqueado` em `_etapa_locomocao`, **depois** do dash-cancel |
| `can_double_jump` | `ParkourController._limite_de_geppo()`. O pulo do chão nunca trava |
| `can_use_skills` | `Player.begin_charge` (Z/X/C/V, inclusive espada) e as teclas F, E, T, 1/2/3 |

A arena não muda: `Player.capacidades` nasce com `completas()`, e o teste confere.
O Civil também nasce **sem Akuma no Mi** (`equip_fruit("")`) e **sem os "clones" da
corrida** (`Player.ecos_de_movimento_ligados = false`, o `AfterimageTrail`; pedido do
dono em 14/09/2026 — na arena o rastro continua). A queda no vazio
renasce em `Player.ponto_de_renascimento` — na arena, `Scoreboard.RESPAWN`; no Modo
História, o spawn do mapa.

---

## 4. Etapa 2 — o editor de mapa

### Como abrir

Menu principal → card **JOGAR** → **✏️ EDITOR** (escolha do dono: botão visível para
todos). Direto: `godot --path . -- --editor-mapa`. Edita
`mapas/historia/baseplate.json`, o mesmo arquivo que o Modo História lê.

### Comandos (os do Roblox Studio)

| Ação | Comando |
|---|---|
| Olhar / voar | botão direito segurado + mouse · W A S D · Q/E desce/sobe · Shift 3× · roda avança |
| Ferramentas | Ctrl+1 Selecionar · Ctrl+2 Mover · Ctrl+3 Escalar · Ctrl+4 Girar |
| Selecionar | clique · Ctrl/Shift+clique soma · arrastar em área vazia = retângulo · Esc limpa |
| Grade | seletor na barra (livre, 0,25 a 4 m); **Shift durante o arraste solta a grade**. Girar anda de 15° em 15° |
| Inserir | + Caixa / Esfera / Cilindro / Cunha — nasce em cima do que está no centro da tela |
| Editar | Ctrl+D duplica (a cópia nasce em cima) · Delete apaga · Ctrl+Z / Ctrl+Y · F enquadra a seleção |
| Agrupar | **Ctrl+G** com 2+ itens une num grupo · Ctrl+G com 1 grupo separa **um nível** (a última união sai primeiro; grupo de dentro continua inteiro) · clique pega o grupo mais de fora · **Alt+clique** pega a peça de dentro |
| Explorer | clique seleciona (também peça dentro de grupo) · clique duplo renomeia (peça ou grupo) · grupos em árvore, recolhíveis |
| Propriedades | forma, posição, rotação, tamanho, cor, material, grade, colisão, **hitbox**; aceita vírgula decimal |
| **Hitbox** | **H** mostra o volume de colisão de todas as peças · **Ctrl+H** aponta as alças do gizmo para a hitbox da peça selecionada · "Aplicar nas iguais" copia para todas as cópias do mesmo tipo/modelo |
| Salvar | Ctrl+S (o • no botão indica alteração pendente) |
| Testar | F5 ou ▶ Testar: o Civil de verdade no mapa **como está na memória**; ESC volta |
| Sair | Sair — pergunta antes se há alteração não salva |

### Arquitetura

| Arquivo | Papel | Nó? |
|---|---|---|
| `src/editor_mapa/documento_mapa.gd` (`DocumentoMapa`) | o mapa aberto; avisa por sinal | não |
| `src/editor_mapa/historico.gd` (`HistoricoDeEdicao`) | desfazer por **diferença de estado** | não |
| `src/editor_mapa/selecao.gd` (`SelecaoDoEditor`) | o que está selecionado; spawn = id `@spawn` | não |
| `src/editor_mapa/operacoes.gd` (`OperacoesDoEditor`) | toda mudança no documento | não |
| `src/editor_mapa/gizmo_matematica.gd` (`GizmoMatematica`) | eixo, anel, esticar face, girar | não |
| `src/editor_mapa/vista_mapa.gd` (`VistaDoMapa`) | documento → nós; clique na camada 20 | sim |
| `src/editor_mapa/gizmo.gd` (`GizmoDoEditor`) | alças, pega em pixels | sim |
| `src/editor_mapa/camera_livre.gd` (`CameraLivre`) | voo | sim |
| `src/editor_mapa/barra.gd`, `explorer.gd`, `propriedades.gd`, `ui_estilo.gd` | painéis | sim |
| `src/editor_mapa/EditorDeMapa.gd` + `.tscn` | orquestrador: input → operações | sim |
| `tools/dev_tests/test_editor_mapa.gd` | 120 verificações, inclusive mouse de verdade | — |

### A hitbox da peça (23/09/2026)

Até aqui a colisão era sempre derivada da peça: a forma saía do tipo e do tamanho, e no
modelo `.glb` saía da malha dele — ou, acima de 150 mil triângulos, de **uma caixa crua do
tamanho da peça**. Não dava para ver nem ajustar: o dono só descobria que a árvore era um
bloco esbarrando nela.

Agora cada peça pode ter uma **hitbox própria**: forma (caixa, esfera, cilindro, cunha ou
**cápsula**), deslocamento, tamanho e rotação, todos locais à peça. No arquivo ela é um
campo **opcional**; ausente quer dizer automático, exatamente como sempre foi, e um mapa
sem hitbox é gravado byte a byte como antes.

- **Ver:** a peça selecionada mostra o volume (verde, por cima do modelo, porque ele quase
  sempre mora dentro de geometria opaca). **H** mostra o do mapa inteiro.
- **Editar:** os campos no painel, ou **Ctrl+H** para as alças do gizmo passarem a mexer no
  volume em vez da peça — o botão da barra vira `Hitbox ✎` enquanto isso, e trocar a seleção
  devolve as alças à peça.
- **Copiar:** "Aplicar nas iguais" leva a hitbox para todas as peças do mesmo tipo (e mesmo
  modelo), num passo só de desfazer. É o que torna a ferramenta usável num mapa com trinta
  cópias da mesma árvore.
- **Uma conta só:** `MapaMontador.volume_de_colisao` é o que a física monta **e** o que o
  editor desenha. Duas contas separadas mostrariam um volume e fariam o jogador esbarrar em
  outro. Quando a colisão é a malha do modelo, essa função devolve vazio e o editor não
  desenha caixa nenhuma, em vez de inventar um retângulo que não existe.
- **Não tem "moldar ao modelo":** seria um botão inútil. `BibliotecaDeModelos.aplicar_em`
  já centraliza (`position = -centro * escala`) e escala o modelo para caber no tamanho da
  peça, então a caixa do tamanho **já é** a caixa justa da geometria.
- A hitbox não muda a aparência nem o clique: a forma de seleção (camada 20) continua vindo
  do tamanho da peça, senão um volume pequeno tornaria a peça difícil de clicar.

Metade do editor não cria nó — é o que permite testar mover, desfazer e girar sem
simular mouse. A outra metade é testada com eventos injetados no viewport.

### A loja de modelos (.glb)

Painel à **esquerda** do editor (o equivalente à Toolbox/Creator Store do Roblox).

| Ação | Como |
|---|---|
| Importar | **Importar arquivos** (um ou vários .glb) ou **Pasta** (todos os .glb de dentro, sem subpastas) |
| Achar | campo **Buscar…** (nome exibido ou id) |
| Pôr no mapa | **clique** insere no centro da tela · **arrastar** solta no ponto do mapa, pousado no chão (soltar em cima de painel não insere) |
| Organizar | **botão direito** → Categorias ▸ (marcar/desmarcar, Nova categoria…) / Renomear… / Apagar da loja (avisa quantas peças do mapa usam) |
| Categorias | seletor **Todas / Sem categoria / cada categoria (contagem)** + **☰** para criar, renomear e apagar · **Ctrl/Shift+clique** seleciona vários modelos SEM inserir, para marcar categoria em lote |

- **Categorias** (decisão do dono, 16/09/2026): **etiquetas** — um modelo pode ter várias
  ("Animal" e "Inimigo") — que **só organizam** a loja, sem efeito no jogo. Ficam no
  `catalogo.json`; o catálogo antigo, sem o campo, abre com tudo em "Sem categoria".
  Apagar categoria tira a etiqueta e mantém os modelos.

- **Onde fica** (decisão do dono): cópia em `mapas/modelos/<id>.glb` + `mapas/modelos/catalogo.json`.
  O mapa guarda só o **id**; mover ou apagar o arquivo original não afeta nada.
- **O que é recusado, com motivo:** não-.glb, acima de 150 MB, cabeçalho que não é glTF 2,
  arquivo truncado, .glb que aponta para arquivo externo (textura ao lado), modelo sem malha.
  O mesmo conteúdo importado de novo (SHA-256) não duplica.
- **Miniaturas:** foto 128 px tirada num `SubViewport` isolado, guardada em
  `user://miniaturas_modelos/` com o SHA no nome — é cache, não vai para o git.
- **No mapa:** a peça `modelo` é esticada para a caixa `tamanho` e centralizada; colisão de
  **malha** (côncava) até 150 mil triângulos, caixa acima disso. Modelo que sumiu da loja
  vira **marcador rosa** — o mapa abre do mesmo jeito.
- **Código:** `src/world/biblioteca_modelos.gd` (catálogo, carga, colisão — o jogo usa),
  `src/editor_mapa/importador_glb.gd`, `miniaturas.gd`, `loja.gd`.

### Grupos (Ctrl+G)

- No arquivo: `"grupos": [{"id", "pai"}]` e `"grupo"` em cada peça (ambos opcionais; mapa
  sem grupo grava igual a antes). Grupo não tem posição própria — **o jogo ignora grupos**.
- Mover, girar, duplicar e apagar um grupo agem em todas as peças de dentro; a posição do
  grupo em Propriedades é o centro das peças. Escalar continua sendo de uma peça.
- Grupo que fica sem peça some. Tudo passa pelo desfazer.

---

## 5. Status do personagem (tecla M)

Implementa o PDF inteiro que depende só do personagem. Código: `src/historia/progressao.gd`
(`ProgressaoDoPersonagem`, sem nó) e `src/ui/JanelaDeStatus.gd`.

| O quê | Como ficou |
|---|---|
| Abrir/fechar | **M** (ou ESC para fechar) no Modo História; o jogo para o WASD enquanto aberta |
| XP e níveis [4, 5] | tabela do PDF; XP é o progresso dentro do nível, a sobra passa para o próximo |
| Barreira [6, 7] | do 7 em diante cada nível exige missão especial; XP continua sendo guardado ("EVOLUÇÃO BLOQUEADA", excedente mostrado) |
| Pontos [10, 11] | +5 por nível; "+"/"−" só PEDEM — gravam no **Confirmar** (não há redistribuição no PDF) |
| Vida [15] | 20 + Vitalidade × 5, aplicada ao corpo na hora |
| Energia [16] | 10; **parkour não gasta energia no Modo História** (decisão do dono, 16/09/2026) |
| Skills [20, 27] | Combate/Espada/Fruta 0–4; Combate ≥ 1 libera o ataque |
| Aviso [10] | "Level Up! Nível X → Nível Y · Pontos recebidos: +5" e o aviso de barreira no topo (escondido enquanto a janela está aberta; volta ao fechar) |
| Penalidade [9] | removida em 26/10/2026 (o Mine Piece não reduz XP por nível; `AUDITORIA_FIDELIDADE_MINE_PIECE.md`, A2) |
| Salvo em | `user://historia/progresso.json` (arquivo preso a valores possíveis ao carregar) |
| Teste | painel **F8** (`src/ui/FerramentasDeTeste.gd`), só em build de desenvolvimento: +XP, concluir missão, +ouro, skills, dash, pulo duplo, boneco de duelo, comer/tirar fruta, reiniciar campanha. Era a seção TESTE da janela até 30/09/2026 |

**A janela (redesenho de 30/09/2026, pedido do dono).** Interface de jogo, não de depuração:
1040 px de largura em 1280×720, centralizada, fundo azul-petróleo quase preto (96%), títulos
dourados. Coluna esquerda (~31%): o personagem em 3D (`src/ui/PreviaDoPersonagem.gd`, a
mesma prévia da Customização, montada ao abrir, gira arrastando). Coluna direita: Raça,
Nível e barra de XP com o próximo nível, ao lado de Vida/Energia (barras do HUD, `BarraHud`)
e Ouro; ATRIBUTOS com "Pontos disponíveis" e Descartar/Confirmar na mesma linha, botões
± de 44×34 desligados quando não cabem; SKILLS com quatro marcadores por trilha. Sem
ícones nem emojis. Cabe sem rolar em 720 px, inclusive com o aviso de evolução bloqueada
(medido: 617 e 645 px de altura); a rolagem só aparece em tela menor. Enquanto aberta, as
barras de vida/energia do canto somem (ficariam cortadas pela borda, e a janela mostra as
mesmas). Capturas: `art_src/validation/status_historia/`.

**Interpretações declaradas** (o PDF não fecha): pontos vão para Força, Inteligência,
Constituição e **Vitalidade** (o atributo "Vida" do PDF, `vitality` na seção 31); "Skill"
da seção 14 são as trilhas 0–4, que não recebem ponto; técnicas Z/X/C/V seguem travadas
(o PDF não diz o que as libera); dash e pulo duplo são desbloqueios de história. O "Testar"
do editor usa um Civil nível 1 novo, sem ler nem gravar o progresso salvo.

---

## 6. Decisões e seus custos

**Player da arena com travas, não um jogador novo.** O PDF desbloqueia, ao longo
da campanha, exatamente o que o Player já tem.
- Benefício: animação, câmera, rig e parkour prontos; desbloquear é trocar um dado.
- Manutenção/extensão: 4 pontos de trava; capacidade nova = um campo + uma trava.
- Custo: ~25 linhas no Player e 8 no parkour.
- Risco: uma entrada nova de golpe que não passe por `_request_melee`/`begin_charge`
  fura a trava. O `test_modo_historia` tem controle positivo por trava, mas só cobre
  as entradas que existem hoje.

**Mapa em JSON, não em `.tres`.** Um `.tres` pode trazer script embutido, que
executa ao carregar; mapa é arquivo de troca. JSON também dá diff legível.
- Custo: validação própria, testada com 17 arquivos quebrados.
- Risco resolvido: `.json` não é exportado por padrão → `export_presets.cfg` inclui `mapas/*.json`.

**Desfazer por diferença de estado.** `iniciar` fotografa o id→peça (só referências),
`concluir` guarda antes/depois do que mudou.
- Benefício: toda operação futura ganha desfazer sem escrever nada.
- Manutenção: depende de uma regra — o `DocumentoMapa` nunca altera valor no lugar.
- Custo: memória de até 200 passos × peças tocadas por passo.

**Um nó por peça.** É o que o editor precisa para selecionar e mover peça a peça.
- ⚠️ **Gatilho:** mapa com mais de ~1.500 peças, ou montagem acima de 100 ms
  (medida: 1,2 ms com a baseplate). Aí agrupar peças estáticas por material em
  MultiMesh no jogo e manter nós individuais só no editor.

**Modelos copiados para dentro do projeto, carregados por duas portas.** Primeiro
`ResourceLoader` (o .glb já importado pelo editor do Godot — único caminho num jogo
exportado), senão `GLTFDocument` em tempo de execução (recém-importado pela loja).
- Benefício: o mapa não depende do computador de quem montou; funciona sem abrir o editor do Godot.
- Custo: espaço no projeto; o editor do Godot vai importar esses .glb quando for aberto (gera `.import`, que deve ser commitado junto).
- Risco: a porta 1 não foi validada num jogo exportado (não há export templates). ⚠️ **Gatilho:** primeira exportação → abrir um mapa com modelo no jogo exportado.
- Segurança: .glb é só dado (não executa código); o catálogo não aceita arquivo fora da pasta.

**Singleplayer puro, sem `MultiplayerSpawner`.**
- ⚠️ **Gatilho:** Modo História cooperativo → nascer pelo `Main._spawn_player_data`.

**Menu: card JOGAR com três botões** (escolha do dono). O menu já estava a 4 px do
limite de 720; um card a mais passava para 825 px.
- ⚠️ **Gatilho:** qualquer botão novo no menu exige rodar
  `tools/dev_tests/medir_menu_principal.gd` antes de entregar.

### Limites conhecidos da v1 (declarados)

| Limite | Gatilho para revisitar |
|---|---|
| Num jogo **exportado** não salva (`res://` é só leitura) — o botão avisa | o editor ir para jogadores → decidir mapa do jogador em `user://` e como o Modo História o escolhe |
| Sem salvamento automático nem recuperação | primeira perda de trabalho relatada, ou sessões longas de montagem |
| Escalar só com **uma** peça; mover e girar usam eixos do **mundo** | pedido de escalar grupo ou de eixo local (Ctrl+L no Roblox) |
| Retângulo seleciona pelo **centro** da peça | peças grandes difíceis de pegar por retângulo |
| Sem copiar/colar entre mapas; um arquivo de mapa só | segundo mapa da história |
| Apagar modelo da loja não tem desfazer (é operação de arquivo) — por isso pergunta antes | primeiro modelo apagado por engano |
| Loja não importa .gltf com arquivos soltos nem subpastas | pedido de pacote de assets em pasta com texturas separadas |
| Colisão acima de 150 mil triângulos vira caixa (teto não medido) | primeiro modelo que precise de colisão fina acima disso |
| A loja não reduz triângulos nem gera LOD (o `GLTFDocument` em tempo de execução não gera; o importador do editor do Godot gera) | ver a medição abaixo |

### Medição do primeiro mapa de verdade (14/09/2026, RTX 3050, 1280×720, Vulkan)

| Mapa | ms/quadro | FPS | primitivas/quadro |
|---|---|---|---|
| só a baseplate | 3,6 | 275 | 19,6 mil |
| mapa do dono: 23 peças (12 pinheiros, 8 estradas, 2 pedras) | 18,8 | 53 | 44,9 milhões |

O "low poly pine tree" e o "dirt road" têm ~535 mil triângulos **cada** (10,7 milhões na
cena; montagem 293 ms, 366 MB). Os dois ficam acima do teto de colisão fina e colidem
como caixa. ⚠️ **Gatilho:** o mapa passar de ~30 peças desses modelos, ou o FPS medido
cair abaixo de 60 → reduzir os modelos (Decimate no Blender, alvo de poucos mil
triângulos por árvore) ou gerar LOD na importação.
| Sem controle por **toque**: o botão aparece no celular, mas o editor pede mouse e teclado | editor ser usado em tablet/celular → esconder o botão no toque ou criar controles |

---

## 6a. Inimigos no mapa (16/09/2026)

Pedido do dono: inimigos com vida e piscando vermelho ao tomar dano. **Como o jogo acha
o inimigo:** é a peça `modelo` cujo modelo está na categoria **"inimigos"** da loja (id
`inimigos`; renomear a categoria não quebra, o id fica). Não há tipo de peça novo no
arquivo de mapa. Código: `src/historia/inimigo_do_mapa.gd` (`InimigoDoMapa`).

| O quê | Como ficou |
|---|---|
| Vida | **250** para todos (um combo M1 completo tira 278). Gatilho para mudar: primeiro inimigo que precise de dificuldade própria → campo `vida` no catálogo |
| Dano | qualquer golpe que já acerta o boneco da arena (`take_damage`); dano 0 (empurrão extra) não conta |
| Vermelho | `FxUtil.flash_red` no modelo, o mesmo da arena (amarelo se for o alvo da mira assistida) |
| Vida zero | **some da cena** (decisão do dono) e **renasce em 1 minuto** no mesmo lugar do editor, com a vida cheia (decisão de 30/09/2026; vale para todo inimigo que não seja chefe — chefe ainda não existe no modo). O nó fica adormecido (invisível, sem colisão, fora do grupo) e dá XP de novo a cada derrota |
| XP | **5 a 20, sorteado a cada derrota** (decisão do dono); aviso "Inimigo derrotado · +N XP"; se subir de nível, o "Level Up!" toma o lugar |
| Grupo | `enemy`, o mesmo da arena: mira assistida e técnicas de área já o encontram |

**Para bater:** desde 30/09/2026 o personagem já nasce com **Combate 1** (decisão do dono,
divergindo do PDF §21–27): o clique funciona no nível 1. Save antigo com Combate 0 sobe
para 1 ao carregar, e a skill não desce abaixo de 1 (`ProgressaoDoPersonagem.SKILL_MINIMA`).

**Limites declarados:**
- **Estáticos** (os .glb comuns): não andam, não atacam, não são empurrados nem entram
  em hitstun. O que luta é o boneco (seção 6b).
- **Renascer em cima do jogador:** se o jogador estiver parado exatamente no lugar do
  inimigo quando ele volta, a colisão reaparece em volta dele e o empurra para fora.
- **Só no jogo, não no "Testar" do editor:** lá o Civil não ataca, e um inimigo que
  sumisse ao morrer levaria junto o nó da peça que o editor está editando.
- **Colisão obrigatória:** o golpe acha o corpo pela colisão. Peça com "Colisão" desligada
  não toma dano (aviso no log ao abrir o modo).
- **Sem penalidade por nível (§9):** o inimigo ainda não tem nível. Gatilho: primeiro
  inimigo com nível ou categoria "forte"/"chefe" → `xp_de_inimigo`.
- **Categoria marcada DEPOIS de abrir o modo** só vale na próxima vez que o modo abrir.
- A colisão do modelo é a malha de superfície (côncava). Medido: a hitbox do soco acerta
  (48 de dano no teste). Modelo muito baixo (ex.: verme rente ao chão) pode ficar abaixo
  da caixa do soco, que é fina na vertical — o mesmo vale para o boneco da arena.

## 6b. Inimigo que luta: o boneco de duelo (30/09/2026)

Pedido do dono: o boneco de testes — o que luta com o MESMO executor do jogador — vira
inimigo, posto pelo editor. Decisões dele: persegue e luta numa **zona de 20 m** em volta
do ponto de nascimento; se o jogador sai da zona (ou morre), **volta ao ponto**; fora de
combate **regenera**; morto, **renasce em 1 minuto** no mesmo lugar; **não dá XP**.

| O quê | Como ficou |
|---|---|
| Na loja | "Boneco de duelo", aba **inimigos**, com miniatura; arrasta para o mapa como qualquer modelo. Entrou pelo mesmo importador da loja (`tools/importar_boneco_na_loja.gd`, idempotente) |
| Como o jogo o reconhece | categoria `inimigos` **+ campo `comportamento: "boneco_de_duelo"`** no catálogo (campo novo, opcional; a loja preserva e não mostra) |
| No jogo | a peça-modelo sai e um `NinhoDeInimigo` cria o `BonecoDeDuelo` no chão da peça, virado como ela (só posição e giro valem; o tamanho da peça não muda o boneco) |
| Decisão (`CerebroDeInimigo`) | EM_CASA → PERSEGUINDO (jogador dentro da zona, medida do PONTO) → LUTANDO (a 1,3 m) → VOLTANDO (jogador fora ou morto) |
| Movimento | 4,5 m/s em linha reta (acima da caminhada, abaixo da corrida); golpe e guarda freiam pela ficha, como no jogador |
| Luta | golpes em direções sorteadas a cada 1,1–1,9 s; lê o preparo do golpe do jogador: **25% apara, 35% bloqueia, 40% nada**; responde ao aparo com riposte |
| Vida / dano | 250; golpes dele a 0,1× da ficha (2–5 no Civil de vida 20) — os do boneco do F8 |
| Regeneração | **10% da vida por segundo** fora de combate (em casa ou voltando); lutando, não |
| Morte | aviso "Boneco de duelo derrotado · volta em 60 s"; corpo some em 1 s; renasce com a vida cheia |

Números em constantes no topo de `src/combat/direcional/cerebro_de_inimigo.gd`.
Medido (`test_inimigo_lutador`, 26 ✅): fica em casa com o jogador a 40 m; persegue e
chega a 1,28 m; ataca 3 vezes em 6 s (tirou 3 de vida); ergue a guarda na leitura;
volta ao ponto (0,33 m); regenera 20% em 2 s; morto, renasce no mesmo ponto.

**Limites declarados:** sem navmesh (anda reto e escorrega em parede — gatilho: primeiro
mapa que exija contornar obstáculo → `NavigationAgent3D`); sem barra de vida sobre ele;
no "Testar" do editor ele é só o modelo parado, como os outros inimigos.

---

## 7. Em aberto (perguntar ao dono quando chegar a hora)

- **Efeito de Força, Inteligência e Constituição.** O PDF diz o que "pode influenciar",
  sem fórmula. Hoje são só números na janela.
- **Fontes de XP e ouro.** Inimigos dão XP desde 16/09/2026 (seção 6a); missões e loja
  de ouro ainda não existem. Números de referência do PDF em `ProgressaoDoPersonagem.XP_REFERENCIA`.
- **Missões especiais.** O PDF não define o que são as três missões das barreiras.
- **O que libera técnicas (Z/X/C/V)** e como a energia cresce ("sistema próprio posteriormente").
- **Categoria com efeito no jogo:** "inimigos" já dá vida, XP e renascimento (seção 6a);
  o boneco de duelo luta (6b). Vida por inimigo e IA para os .glb comuns ainda não.
- **Dificuldade do boneco:** a defesa (60% dos golpes lidos) e o dano foram escolhas minhas
  (30/09); o dono ajusta.

---

## 8. Validação (16/09/2026)

```bash
GODOT="$(./find_godot.sh)"
"$GODOT" --headless --path . --script tools/dev_tests/test_modo_historia.gd   # 91 ✅, 0 ❌ (sem clones, tecla M; mapa e progresso fixos)
"$GODOT" --headless --path . --script tools/dev_tests/test_progressao.gd      # 39 ✅, 0 ❌ (regras do PDF)
"$GODOT" --headless --path . --script tools/dev_tests/test_editor_mapa.gd     # 78 ✅, 0 ❌
"$GODOT" --headless --path . --script tools/dev_tests/test_grupos_editor.gd   # 39 ✅, 0 ❌ (Ctrl+G)
"$GODOT" --headless --path . --script tools/dev_tests/test_loja_modelos.gd    # 58 ✅, 0 ❌ (inclui categorias e o catálogo real)
"$GODOT" --headless --path . --script tools/dev_tests/test_inimigos_historia.gd # 20 ✅, 0 ❌ (soco real, vermelho, some, XP; 2 controles positivos reprovam)
"$GODOT" --headless --path . --script tools/dev_tests/test_compila.gd          # 6 falhas, todas em tools/anim_editor/studio/ (débito conhecido)
./validar.sh rapido                                                            # ver docs/ESTADO_ATUAL.md
```

`test_bara_combat` falha desde antes do Modo História e foi **isolada** (item 58 de
[`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md)).

**Captura visual confiável sem abrir janela** (ver `erros.md`, 14/09/2026):

```bash
weston --backend=headless --renderer=gl --socket=wayland-historia-gl --width=1280 --height=720 &
WAYLAND_DISPLAY=wayland-historia-gl "$GODOT" --display-driver wayland --rendering-driver vulkan \
  --path . --resolution 1280x720 --write-movie /tmp/quadro.png --fixed-fps 30 --quit-after 90 -- --editor-mapa
```

Com `opengl3` + weston padrão (pixman) o jogo 3D sai só com céu — o problema é o
renderizador, não a cena.

## Pet caranguejo (30/09/2026)

> **Atualizado 30/09/2026 (noite):** pets agora moram no **inventário (N)** — o personagem já começa com o caranguejo e a gaivota — e mudam de comportamento pelo menu **B** (livre / seguir / em guarda / agressivo). Posse e modo ficam salvos no progresso; tirar/guardar saiu da janela M. Tudo em **`docs/PETS.md`**.

No modo história, **N → PETS → Caranguejo grande → Tirar**. “Guardar” devolve o companheiro ao inventário; tirar outra vez traz o mesmo para perto, sem duplicar. Não depende de F8 ou de build de desenvolvimento.

A loja do editor já oferece **pets → Caranguejo grande**. A peça guarda `comportamento: pet_caranguejo`; ao carregar a história, `pets/companhia.gd` troca o marcador estático por um pet que segue o jogador, preservando escala e yaw. Durante a edição e o “Testar” do editor a peça continua uma prévia estática (como os outros comportamentos do mapa); o comportamento roda na história.

O companheiro anda e corre lateralmente, descansa próximo ao dono, pula quando o dono pula e solta bolhas pelas duas garras a cada 6–12 segundos. As bolhas são visuais, sem dano; cada rajada se remove em 2,4 segundos. Há checagem de chão e espaço livre para invocar, desvio local de obstáculos e recuperação perto do dono após bloqueio prolongado, queda ou respawn distante. Não há navegação global por navmesh; labirintos podem exigir essa recuperação.

Fonte/rig/material: `art_src/pets/LEIA-ME.md`. Comportamento, animação e VFX: `src/historia/pets/`. Validação: `tools/dev_tests/test_pet_caranguejo.gd`; adicionar `-- --capturar` em execução com tela grava `art_src/pets/menu.png` e `pet.png`.

## Praia e oceano (30/09/2026)

A loja oferece **praia mapa → Areia de praia — low poly**, módulo de 32 × 24 m com rampa suave, colisão pela malha e encaixe lateral. Fonte e instruções: `art_src/praia/LEIA-ME.md`.

O modo história e o editor agora mostram um oceano ao redor da `baseplate` e de suas duplicatas (`baseplate_*`). Azul claro junto às bases, azul escuro em mar aberto, ondas sobrepostas, espuma costeira e variação de superfície. Editar as bases atualiza a faixa rasa. O nível fica 0,65 m abaixo do menor topo; não há piso sólido na água. Natação e flutuação ainda não foram implementadas.

Implementação: `src/world/oceano_historia.gd` + `.gdshader`. Até 64 bases horizontais, com rotação Y; a costa segue os retângulos das bases. O asset de areia é colocado manualmente pela loja; o mapa salvo do dono não é reescrito por esta integração. Validar: `python3 tools/validar_praia.py --capturar` (sem a flag: contratos headless). Capturas/relatório: `art_src/validation/praia/`. A importação da areia fica **sem compressão de vértices** (senão abrem fendas entre as cores; ver `art_src/praia/LEIA-ME.md`). Estado final: `docs/PRAIA_CHECKPOINT.md` (concluído).

## Ilha Inicial com relevo (01/10/2026)

O mapa do Modo História virou a **Ilha Inicial**: relevo em blocos (peça nova `terreno`),
rio em S de costa a costa com duas pontes, floresta e morros a oeste, vila, fazendas e
porto com navios a leste, coliseu no sudoeste (futuro palco das invocações e dos chefes)
e praia em volta. Os modelos da loja ganharam **tamanho padrão** (entram do tamanho certo
no editor) e os barcos uma categoria **navios** com ficha de propriedades. Como funciona,
como editar e como regenerar: `docs/MAPA_ILHA.md`.

## Espada inicial — 06/10/2026

O personagem recebe uma espada no inventário, inclusive em campanhas já salvas.
Abra **N → ARMAS → Equipar**: ela aparece na mão e na barra de itens. A tecla
indicada no quadrado seleciona a espada; repetir a tecla guarda e volta à luta.
**Desequipar** no inventário também retira o quadrado da barra. O equipamento e
o item ativo são salvos. Equipar concede o nível básico **Espada 1**, para que o
item inicial seja utilizável (mesmo precedente de comer uma fruta liberar Fruta 1).

- Clique esquerdo: estocada; gesto do mouse antes do clique escolhe corte para
  esquerda, direita ou de cima, como no boxe direcional.
- Botão direito: defesa, com aparo/riposte/finta e postura do executor existente.
- **Z — Giro cortante:** corpo e espada giram continuamente, com as duas mãos no
  cabo (direita junto à guarda, esquerda abaixo), com imunidade a dano
  e empurrão durante o giro. Pode andar; a câmera continua independente. O primeiro
  inimigo atingido recebe o dano do corte lateral (30) e knockback (10 m/s), e o giro
  termina. Outro Z cancela; sem limite de duração. Trocar item, incapacitação ou
  reconstruir o personagem encerra a técnica e a imunidade. Paredes bloqueiam o acerto.
  A HUD mostra a técnica somente com a espada ativa.
- Trocar item interrompe o ataque, conserva a recuperação pendente e não apaga
  reação, quebra de guarda ou rebote. Cada golpe acerta cada alvo apenas uma vez.
- O contato acompanha toda a lâmina visível e respeita obstáculos. Vara e fruta
  do pomar não ocupam a mão junto com a espada.

Modelo reaproveitado: `mapas/modelos/sword.glb`. Componente:
`src/historia/equipamentos/espada_da_historia.gd`; golpes/poses/números:
`src/combat/direcional/estilos/espada.tres`. O jogador da arena continua usando sua
Yoru e seus controles existentes. Validação: `tools/dev_tests/test_espada_historia.gd`
(usar `-- --tela` para entrada com mouse e capturas; consultar antes de capturar o desktop).

A técnica Z mora em `src/historia/equipamentos/giro_da_espada.gd`; teste dedicado:
`tools/dev_tests/test_giro_espada_historia.gd`. Não usa energia nem recarga própria;
o início respeita ataque/recuperação e reações em curso. O dano vem da ficha da espada.
Inimigos estáticos também recebem empurrão com colisão e renascem no ponto original.


## Bestas do mar — 07/10/2026

Coloque os modelos em **Editor → Loja → Bestas do mar**, próximos à costa, e salve.
Ao entrar na história, as peças ganham comportamento e animações automaticamente.
Bovina, girafa e javali são pacíficos: passam a maior parte da rotina descansando
na praia, alternando sono, alimentação e passeios nadando. Só revidam após sofrer
dano; ao se afastar do jogador, abandonam a perseguição e retornam à rotina.
Sea Serpent é boss hostil e dispara bolhas de água pela boca. As bolhas têm
trajetória fixa, podem ser esquivadas e param em paredes.

Os quatro modelos têm clipes de dormir, nadar devagar/rápido, idle, irritação,
ataque, reação ao dano, disparo e alimentação. Mordidas usam contato na boca
animada; dano interrompe ataques em preparação. Pacíficas renascem após 60 s;
o boss não renasce automaticamente. Não foram criados drops ou recompensas.

Código e números editáveis: `src/historia/bestas_mar/`; animações e fontes:
`art_src/bestas_mar/LEIA-ME.md`. Validação: 64/64 verificações de integração,
inclusive com tela, e teste de rig/loja/salvar/reabrir aprovado. Registro completo:
`docs/BESTAS_MAR_CHECKPOINT.md`. A integração não adiciona criaturas ao mapa salvo:
é necessário colocar os modelos pela loja.


## Sequência de socos — 07/10/2026

Com **Luta** ativa, cliques sem gesto do mouse alternam jab, gancho de direita,
gancho de esquerda e soco de cima. Cada clique pede um golpe; a sequência reinicia
no jab após 1,2 s sem atacar, contados do fim do golpe anterior. O clique no fim da
recuperação pode adiantar o pedido do próximo soco. Gestos do mouse continuam
escolhendo golpes diretamente. Defender, sofrer interrupção ou trocar equipamento
reinicia a sequência. Regras e ajustes: `docs/combat/ENTRADAS.md`.

## Níveis até 2400, XP por dificuldade, chefes, bandidos e a primeira missão — 08/10/2026

Plano e decisões: `docs/BANDIDOS_E_PROGRESSAO_PLANO.md`.

- **Dash do ar:** 5 m (era 8). Ao terminar, a velocidade horizontal volta à de andar,
  sem carregar o impulso. O roll do chão fica com 8 m.
- **Níveis (SUPERADO em 26/10/2026: sem teto por ilha nem missão especial; ver `AUDITORIA_FIDELIDADE_MINE_PIECE.md`, A3):**
  - O teto absoluto é **2400**. Na Ilha Inicial o teto é **10**
    (`ProgressaoDoPersonagem.teto()`), e o XP que passa dele fica guardado.
  - As missões especiais continuam só no 8, no 9 e no 10.
  - Depois do 10, cada nível pede 500 mil + 25 mil × (nível − 9). É uma curva
    provisória; o gatilho para rever (a 2ª ilha) disparou em 08/10 e espera a decisão
    do dono (ver a seção da Ilha dos Macacos).
  - **3 pontos por nível** (eram 5).
  - Título "Ápice" do 11 em diante.
- **XP de animal:** vida/10 × (1 + dano/2), gravado na ficha de cada espécie
  (`tools/mapa_ilha/aplicar_xp_por_dificuldade.gd`). Exemplos: coelho 1, vaca 12,
  urso 77, harpia 280, gorila 405. As bestas do mar seguem a mesma regra: bovina 175,
  Sea Serpent 800.
- **Vida dos chefes no topo da tela** (`src/ui/barras_de_chefes.gd`):
  - Uma barra por chefe do grupo `chefes` (gorila, harpia, Sea Serpent), até 3,
    empilhadas da mais perto para a mais longe.
  - Aparece a até 60 m ou em combate (`em_combate()`) e some quando o chefe morre ou
    quando há menu aberto.
- **Bandidos:**
  - São o boneco que luta vestido de bandido (`src/historia/bandidos/roupa_de_bandido.gd`),
    a peça "Bandido" da aba inimigos.
  - Dão 25–75 XP e renascem em 60 s.
  - Há 2 acampamentos de 3 em campo aberto, com fogueira e toras:
    `tools/mapa_ilha/colocar_bandidos_e_missao.gd`.
- **Missões** (`src/historia/missoes/`):
  - A tabela fica em `missoes.gd`; o estado vai no progresso (`missoes`, salvo junto).
  - O NPC "Guarda da vila", na praça, tem uma "?" que muda de cor:
    - amarela: missão disponível;
    - cinza: aceita;
    - amarela: pronta para entregar;
    - some: entregue (com a cadeia de 08/10, só no fim da cadeia).
  - A conversa usa a janela das lojas: Aceitar → Entregar.
  - Na tela, um contador no canto superior direito.
  - Missão "Bandidos no campo": derrotar 5 dá 300 XP + 50 de ouro, uma vez.
  - Missão nova = uma entrada na tabela + `"missao": <id>` na ficha do NPC.
- **Testes:** `test_progressao`, `test_q_rolar_e_dash`, `test_animais`,
  `test_barras_de_chefes` (9) e `test_bandidos_e_missao` (25). Fotos em
  `art_src/validation/bandidos/`.

## Ilha dos Macacos, missões do Guarda, bússola e desenho por distância — 08/10/2026

Plano, decisões e medições: `docs/ILHA_DOS_MACACOS_PLANO.md`.

- **A ilha:** a 2ª ilha, a leste do porto, com centro em (1500, 0). A placa tem 256 m e
  fica a 1.116 m de mar da inicial. Tem morros de até 23 m, chão de mata (as árvores
  gigantes ficam para depois), trilha do píer até a clareira e 4 bandos com 12 macacos.
  Fonte: `tools/mapa_ilha/gerar_ilha_dos_macacos.gd`.
- **Ilhas no jogo** (`src/historia/ilhas/`):
  - **Cadastro:** `ilhas.gd` guarda nome, placa e teto (inicial 10, macacos 20).
  - **Detector:** `detector_de_ilha.gd` marca onde o jogador está e avisa "Você chegou à
    Ilha dos Macacos". A 1ª chegada põe a ilha nas `ilhas_visitadas` (salvas), e o teto
    de nível passa a ser o da ilha mais avançada já visitada.
- **Missões do Guarda, em cadeia:** bandidos → um pet novo (150 XP + 20) → uma Akuma no
  Mi (200 + 30) → vencer a corrida dos caranguejos em 1º lugar (250 + 40) → pescar 10
  peixes (200 + 30 + a **bússola**).
  - Uma por vez; só conta o que acontece depois de aceitar.
  - A "?", o contador e a janela seguem a missão da vez.
- **Bússola:** abaixo das barras de vida e energia. A agulha aponta para a ilha,
  girando com a câmera, e ao lado aparecem a distância e o nome. Some na própria ilha.
- **Desenho por distância** (`lod_das_ilhas.gd`):
  - Até 400 m da placa de uma ilha, ela é desenhada inteira.
  - Até 1,9 km, fica o relevo; construções viram blocos e árvores viram copas. Objetos
    pequenos, NPCs e bandidos somem e param de processar.
  - Além disso, nada da ilha é desenhado.
  - Medido: olhando a ilha inicial do mar, de 4.702 para 802 objetos, e o quadro de 9 para 7 ms.
- **F8:** "Bússola liga/desliga" e "Ir à Ilha dos Macacos".
- **Pendente (decisão do dono):** a curva de XP acima do 10 e os títulos do 11 em diante.
- **Testes:** `test_ilha_dos_macacos`, `test_cadeia_do_guarda` (38), `test_lod_das_ilhas`,
  `test_progressao` e `test_bandidos_e_missao`. Medição: `medir_lod_das_ilhas.gd`. Fotos em
  `art_src/validation/ilha_dos_macacos/`.


## Marcador de missão, barcos à venda, dia e noite, Hie/Pika e Harpia — 10/10/2026
Pedido do dono, tudo no Modo História. Detalhes, medições e escolhas: `docs/PEDIDO_2026-10-10_HISTORIA.md`.
- **Marcador de missão** (`src/ui/marcador_de_missao.gd`, campo `marcar` nas missões): nos
  bandidos vivos até o fim; cumprida, no NPC que paga.
- **Vendedor de barcos** no porto (1 moeda, um de cada tipo, salvo, atraca no cais ao abrir
  o jogo); nenhum barco no mapa.
- **Dia e noite** (`CicloDiaNoite`): 24 min por dia; noite azul e legível, com lua e estrelas.
- **Pika Z** paralisa segurando, até no ar; **Hie Z** só deixa imunidade na 3ª salva;
  **Hie V** vira o lugar em gelo num raio fixo (`EraDoGelo`).
- **Harpia:** território maior, voa entre as pedras, ronda os picos, reage a golpe com
  investida, arremete depois dela; tornado a 14 m/s.

### Sharkman e mergulho — 13/10/2026

**M → Raça** permite escolher Humano ou Sharkman, com a escolha salva na campanha.
Sharkman mantém fôlego infinito. Sem a penalidade da Akuma ativa, seu nado normal
equivale à corrida no chão (base 6,3 m/s), e **Shift** nada ao dobro (base 12,6 m/s).
O rápido gasta `max(2, energia máxima × 0,2)` por segundo; sem energia, mantém o
nado normal, sem alternar velocidades a cada quadro. Soltar Shift ou recuperar
20% da energia permite acelerar novamente. **Espaço** sobe e **Ctrl** mergulha.

Ao mergulhar, uma luz azul suave de alcance 32 m acompanha o jogador e apaga
gradualmente ao emergir, preservando o ciclo dia/noite. A tinta subaquática foi
reduzida de 42% para 24% para manter o fundo legível.

Regras, testes e decisão pendente sobre Sharkman com fruta ativa:
[`SHARKMAN_BICICLETA_CHECKPOINT.md`](SHARKMAN_BICICLETA_CHECKPOINT.md).
