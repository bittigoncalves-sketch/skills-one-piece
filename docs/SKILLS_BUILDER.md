# Skills Builder

Acesso: **menu principal → SKILLS BUILDER**. Também aceita o argumento `--skills-builder` depois de `--` ao iniciar o Godot. O editor usa uma arena própria, sem iniciar servidor nem alterar o progresso do modo história.

## Criar e testar

1. Em **Nova**, escolha Golpe, Projétil ou Área de vento (modelo Harpia).
2. Em **Identificação da skill**, defina ID, nome, descrição, usuário (Jogador, Inimigo ou Chefe) e modelo da prévia.
3. Configure duração, recarga, custo, alcance, ativação e os componentes desejados no painel esquerdo.
4. Adicione eventos à timeline. Clique no bloco para editar seu início, duração, habilitação e parâmetros específicos. Sem bloco selecionado, o inspector edita os padrões da categoria.
5. Clique em **Rodar** ou pressione **F5**. Use Pausar/Continuar, Parar e Reiniciar alvo para repetir o ensaio.
6. Use **Salvar** para guardar na biblioteca e **Abrir** para recuperar. Importar/Exportar transfere arquivos JSON; Duplicar gera outro ID.

Arraste um bloco para mudar seu início; a borda direita ajusta sua duração. O encaixe é de 0,05 s; Shift permite arraste livre. Setas movem o bloco selecionado; Delete o remove; Escape cancela um arraste. Clique na régua para reconstruir a prévia no instante escolhido, com áudio silenciado durante a busca.

**Ctrl+S** salva; **Ctrl+Z** desfaz e **Ctrl+Shift+Z** refaz. O editor avisa antes de descartar alterações ao abrir outra habilidade ou voltar ao menu. IDs aceitam letras ASCII, números, hífen e sublinhado.

## Arena

Botão direito arrastado gira a câmera; a roda aproxima/afasta. O controle Hitboxes funciona durante a reprodução e a pausa. Abaixo da arena, configure distância do alvo, nível, estado de chão, vida do ator e alvo móvel. Os indicadores mostram tempo, vida do alvo, energia, recarga e acertos.

O modo **Segurar** aceita a tecla configurada: solte antes de completar a carga para cancelar e restituir energia. Rodar/F5 simula a carga completa. **Automática** repete respeitando custo e recarga; **Parar** encerra. Atalhos de skill não disparam enquanto um campo de texto está em edição.

Eventos suportados:

| Evento | Comportamento na arena |
| --- | --- |
| Animação | Clipes do modelo Base ou Harpia; velocidade, intensidade e pose da Harpia |
| Movimento | Frente, trás ou acima; velocidade, distância máxima e curva |
| Hitbox | Esfera, caixa ou cápsula; dimensões, posição relativa e acerto único/múltiplo |
| Projétil | Velocidade, raio, quantidade, abertura, gravidade, vida e perfuração |
| VFX | Impacto, anel, vento ou tornado; cor e escala |
| Áudio | Vento, impacto ou disparo; volume e tom; limitado à duração do bloco |
| Câmera | Tremor e campo de visão |
| Transformação | Troca temporária do visual do usuário, inimigos ou modelos do mapa; fumaça, luz ou modelo da loja |

O dano global define valor, tipo, chance/multiplicador crítico, impulso, atordoamento e lentidão. Atordoamento e lentidão afetam o alvo móvel. O alvo começa com 1000 HP, o ator com 100 de energia; Reiniciar restaura ambos. O tipo de dano identifica o efeito, sem simular resistências elementais.

Hitboxes usam metros relativos ao ator: X lateral, Y vertical e Z negativo para frente. Projetéis seguem a frente do ator, com abertura horizontal. Condições verificam nível, vida percentual, chão, alvo vivo e distância/alcance antes de consumir energia.

## Arquivos e limites desta versão

Biblioteca em `user://skills_builder` (pasta de dados do projeto Godot). JSON versionado `skills-one-piece/skill`, versão 1, validado antes de importar, executar ou salvar. Duração máxima de 30 s, até 64 eventos, 16 projéteis por disparo e arquivos de até 1 MiB. Salvamento e exportação usam arquivo temporário e renomeação para preservar a versão anterior se ocorrer falha.

O campo Usuário registra para quem a habilidade foi criada; a prévia usa o mesmo ensaio para todos. Para levar a skill ao jogo, veja **No jogo** abaixo. O catálogo de animações, sons e VFX é fechado; importar um JSON não importa modelos, clipes ou código. Há um alvo de teste e dois objetos para ensaiar transformação, sem obstáculos ou resistências. Animações/VFX da Harpia disponíveis na prévia não importam automaticamente os ataques completos do chefe.

## Transformação visual (07/10/2026)

Na timeline, escolha **Transformação → + Evento**. Selecione o bloco e ajuste **Início** e **Duração**. Em **Asset da transformação**, escolha **Fumaça**, **Luz** ou busque um modelo da loja. O campo **Transformar** aceita usuário, inimigo mais próximo, inimigos ao redor, assets ao redor ou inimigos e assets juntos. Ajuste raio, escala e cor; modelos da loja conservam seus materiais.

A troca conserva movimento, vida, colisão, IA e combate, inclusive o recebimento de dano. Fumaça e luz são formas visuais, sem conceder imunidade ou intangibilidade. Ao terminar a duração, cancelar a skill ou remover seu executor, o visual original volta. A morte também encerra a forma. Em sobreposição, aparece a transformação mais recente ainda ativa.

O raio parte do usuário e seleciona os alvos no início do bloco, até 32 por evento. **Assets** são peças de modelo da loja montadas no mapa; chão e terreno não entram. Na prévia, os dois objetos laterais permitem testar essa seleção. O tamanho da forma acompanha a altura visual do alvo multiplicada pela escala configurada; a colisão mantém o tamanho original.

Salvar, importar/exportar, desfazer/refazer e publicar preservam os parâmetros. Skills antigas continuam válidas. O modelo deve existir no catálogo local; se estiver ausente, o alvo conserva seu visual. Fumaça e luz usam o tempo da timeline e permanecem reproduzíveis ao buscar e pausar.

Implementação compartilhada pela prévia e pelo jogo: `transformacao_de_skill.gd` e `visual_de_transformacao.gd`, em `src/skills_builder/`. Validação e evidências: [checkpoint da transformação](TRANSFORMACAO_BUILDER_CHECKPOINT.md).

## No jogo (06/10/2026)

**Publicar** (barra de cima) valida a skill e a copia para `res://mapas/skills/<id>.json`, no git e igual para todo mundo que joga esta versão. **Salvar** continua guardando só o rascunho na sua biblioteca. Plano e decisões: `docs/SKILLS_BUILDER_NO_JOGO.md`.

Quem usa a skill fica nas propriedades dela (Identificação):

| Usuário | Quem usa | no jogo |
| --- | --- | --- |
| Jogador | — (a tecla da Ativação) | entra no **Kit do Builder**, na tecla Z, X, C, V ou F. Publicar outra na mesma tecla a substitui |
| Inimigo | um modelo da categoria "inimigos" da loja | os **inimigos do mapa** daquele modelo e o **boneco de duelo** do ninho daquele modelo usam a skill |
| Chefe | Harpia ou Buggy | fica atribuída; a IA dos chefes ainda não usa |
| Animal | uma espécie | fica atribuída; a IA dos animais ainda não usa |

**Kit do Builder** = as skills de Jogador equipadas como uma fruta:
- **No Modo História:** N › FRUTAS › Kit do Builder › Equipar (troca a fruta atual, com confirmação; o kit não se gasta) ou F8 › Equipar Kit do Builder.
- **Na arena:** M › Kit do Builder (o servidor equipa, todos veem).
- Teclas: Z/X/C/V e F (o F do kit vem antes do voo da Rocket e do Corpo de Ferro).
- Menu de técnicas e barra mostram os nomes e as recargas.

Números no jogo:
- **Dano:** vale na arena (vida 2048). Na história, o Kit do Builder usa a escala das frutas (× 250/2048). Skill de inimigo tira a mesma **fração da vida** do alvo (dano × vida máxima / 2048).
- **Energia:** o custo é uma fração da barra de 100 da prévia (custo 10 = 10 % da energia máxima). Inimigo não gasta energia.
- **Recarga:** os segundos do Builder, nos dois modos.
- **Ativação:** Pressionar sai na hora. Segurar carrega e sai sozinho; soltar antes devolve a energia. Automática ou "repetir" repete enquanto a tecla está apertada.
- **Condições:** valem antes de cobrar (nível, vida, chão, alvo a até a distância).

Limites no jogo:
- O **campo de visão** do bloco de Câmera vale só na prévia, porque o soco de FOV está desligado no jogo; o tremor vale.
- Os clipes de **Animação** viram poses do jogador (Preparar, Ataque, Planar, Investida, Vendaval).
- O inimigo **não escolhe time**: a skill dele fere quem estiver na área.
- A prévia supõe um alvo de 0,55 m de raio; no jogo os corpos são um pouco mais finos, então uma hitbox no limite do alcance pode errar.

## Validação

Scripts em `tools/dev_tests/`:

- `test_skills_builder_dados.gd`: contrato, entradas inválidas, limites, roundtrip, gravação e preservação do arquivo anterior.
- `test_skills_builder_preview.gd`: dano, colisões, projéteis, condições, ativação, carga, repetição, efeitos, áudio, câmera, limpeza, busca reproduzível e amostras dos rigs Base/Harpia.
- `test_skills_builder_ui.gd`: menu, seções, edição, desfazer/refazer, biblioteca, importação/exportação, duplicação, gestos de timeline e execução.
- `capturar_skills_builder.gd`: capturas em execução gráfica do editor, presets, janela compacta e menu.
- `test_skills_builder_executor.gd`: a skill no mundo de física do jogo, com paridade com a prévia.
- `test_skills_builder_publicar.gd`: publicar, kit, conflito de tecla, "Quem usa" no editor.
- `test_kit_do_builder_historia.gd`: o kit no Modo História contra inimigo, boneco e vaca.
- `test_inimigos_com_skills.gd`: inimigo do mapa e boneco usando skills atribuídas.
- `net_kit_host_probe.gd` + `net_kit_client_probe.gd`: o kit em rede (na seção multiplayer do `validar.sh`).
- `capturar_kit_do_builder.gd`: fotos das poses e de um golpe no jogo.

Capturas ficam em `art_src/validation/skills_builder/`.

## Loja de projéteis (06/10/2026)

Pedido do dono: "loja de projéteis na aba de projéteis a serem disparados no editor". Decisão: catálogo pronto **e** modelos da loja do editor.

- Na seção **Projéteis** aparece a loja: 10 prontos e, abaixo, os modelos `.glb` da loja do editor, com busca e categoria.
  - Os prontos são Energia, Bala de canhão, Bomba, Flecha, Kunai, Shuriken, Pedra, Bola de fogo, Bolha e Estaca de gelo.
  - Clicar num **pronto** grava forma, rastro, giro e valores (velocidade, raio, gravidade, vida).
  - Clicar num **modelo** troca só a forma.
  - Com um bloco de Projétil aberto, o clique vale para o bloco, como os campos; desfazer funciona.
- **Contrato:** campos opcionais `visual`, `modelo`, `giro` e `rastro` na seção Projéteis. Skill antiga sem eles continua válida, e o id do modelo é conferido (nada de caminho).
- **Desenho:** fonte única em `src/skills_builder/catalogo_de_projeteis.gd` (`criar`/`animar`), usada pela prévia e pelo jogo. O acerto continua sendo a esfera de Raio.
- **Miniaturas:** pela fila do `GeradorDeMiniaturas` (`pedir_cena`), em cache em `user://miniaturas_projeteis`. Sem tela não há foto, e os cartões mostram só o nome.
- **Testes e fotos:** `test_loja_de_projeteis` (22) e `capturar_loja_de_projeteis.gd`.
- O editor de poses saiu para `editor_de_poses.gd`, e `SkillsBuilder.gd` voltou para menos de 900 linhas.

## Refazer fruta do jogo e recursos novos (06–07/10/2026)

Pedido do dono: refazer a Pika Pika no editor (menos o V).

- **Refazer fruta do jogo** (campo Fruta da Identificação): escolhe uma fruta da arena e a põe no catálogo como **reconstruída**. Uma tecla publicada nela troca a do jogo; uma tecla vazia segue o código. Isso vale na arena, na história e em rede (`KitDoBuilder.pelo_builder(fruta, tecla)`).
- **Recursos novos**, todos opcionais (skill antiga continua válida):
  - **Configurações:** *Flutuar durante a skill* e *Mirar no alvo mais perto*.
  - **Ativação:** modo *Sustentar* (soltar encerra).
  - **Movimento:** *Ângulo lateral*, *Inclinação*, *Teleporte* e *Só se estiver no chão*.
  - **Hitbox e VFX:** *Seguir a mira* (com inclinação, pára na parede).
  - **VFX:** estilos *Cometa* (o corpo vira luz) e *Explosão*, e *Cor secundária*.
  - **Projétil:** *Sai para* (Mira/Frente/Abaixo), *Explosão ao tocar*, *Só efeito* e *Som da explosão*.
  - **Áudio:** sons *Luz: …* (a voz da Pika).
- **Testes:** `test_fruta_reconstruida`, `test_builder_recursos_pika`, `test_pika_builder` e `net_pika_*_probe`.

### Rodada 2 da Pika: campos novos (07/10/2026)

Pedido do dono: Z só dispara ao soltar, com carga; X termina em cima do inimigo; C em
chuva na área mirada; mira do Z calibrada; 0,5 s entre golpes. "Qualquer alteração que
não conste no editor deve ser adicionada." Todos opcionais:

- **Configurações:**
  - *Intervalo até o próximo golpe (s)* (padrão 0,5): depois desta skill, outro golpe de fruta só sai passado esse tempo. As frutas em código usam 0,5 s (`Player.INTERVALO_ENTRE_GOLPES`). O servidor confere com folga de 80 %, e só entre teclas diferentes.
  - *Terminar sobre o inimigo (raio, m)*, *Parar antes do vazio* e *Início do fim (s)*: a viagem dos Movimentos no plano acaba antes. Com um inimigo (outro jogador ou do grupo "enemy") perto ou embaixo, o ator vai para cima dele. Sem chão até 60 m embaixo, a viagem pára. Nos dois casos a timeline pula para o *Início do fim*, e a esfera "Abaixo" sai de cima do inimigo achado. Lógica em `viagem_de_skill.gd`.
- **Ativação:**
  - *Impulso com carga cheia (×)*: em "Carregar e soltar", o Impulso cresce com o tempo segurado até esse multiplicador. A carga enche no *Tempo de carga*.
  - Ponto de segurar 0 = toque também dispara (nada é cancelado).
  - Ao soltar, o golpe sai para a mira daquele instante (o soltar leva a mira pela rede). A recarga e o intervalo recomeçam do disparo.
- **Hitbox e VFX:**
  - *Nasce na mão*: sai da mão direita (`Hand_R` do rig; na prévia, a ponta do antebraço).
  - Estilo *Estrela*: estrela de quatro pontas que cresce com a carga, com núcleo, halo e luz.
- **Projétil:**
  - *Sai para "Chuva"* + *Área da chuva (raio, m)*: cada bolinha sai em arco e cai num ponto sorteado (uniforme) do círculo em volta do chão mirado. O sorteio usa a semente do lançamento (mira + origem), igual em todos os peers. O alcance limita o centro. Lógica em `chuva_de_projeteis.gd`.
  - Explosão com escala < 1 não acende luz (são dezenas ao mesmo tempo). Os sons de explosão em sequência saem a cada 90 ms.
- **Sustentar:** soltar pára o que faltava, mas o que já saiu termina o voo (a chuva cai).

### Rodada 3: animações, âncora do VFX, segurar sem andar e voo (07/10/2026)

- **Animação (corrigida):** a prévia tocava um clipe e o jogo uma pose antiga. Agora o campo *Clipe* lista os **61 clipes do jogo** (`clipes_de_skill.gd`: combate, rolamentos, movimento e posturas) mais os 5 nomes antigos como atalhos.
  - Prévia e jogo tocam o MESMO arquivo no tempo do bloco (local × Velocidade, parado no último quadro).
  - No jogo, o clipe sai pelo "clipe de ação" do `ProceduralAnimator`, o caminho do roll do Q, já replicado em rede.
  - *Intensidade* = quanto do clipe vale (0..1). Enquanto um clipe toca, ele passa por cima da Pose.
  - `test_animacoes_do_builder`: diferença prévia × jogo de 0,0°.
- **VFX → Âncora:**
  - *Jogador*: como antes; *Altura* e *À frente* valem só aqui.
  - *Osso do jogador*: mão direita/esquerda, cabeça, tronco, pés.
  - *Alvo*: o inimigo mais perto até o Alcance.
  - *Projétil*: segue a primeira bolinha viva do bloco cujo id vai em *Projétil do bloco*.
  - *Ponto mirado*.
  - *Mundo*: fica onde nasceu.
  - Âncora que ainda não existe esconde o efeito. `test_ancora_do_vfx`.
- **Ativação → Pode andar enquanto segura:** sem ela, segurando a tecla (Carregar e soltar, Sustentar, carga do Segurar) o jogador não anda, não pula nem esquiva (`MoveFrame.travar_por_skill`). `test_segurar_sem_andar`.
- **Movimento → Direção "Mira":** voa para onde a câmera aponta AGORA, na Velocidade (o voo do F da Pika).
- **Configurações → Custo por segundo segurando (%):** cobrado LÍQUIDO (a regeneração segue correndo). Sem energia, a skill solta sozinha.
- **Tecla F:** a fruta da arena refeita também usa o F do Builder, na arena e na história (`pelo_builder`). O menu de técnicas da história mostra o F.

### Hie refeita: campos de gelo (07/10/2026)

- **Dano → Congelar (s):** prende quem leva no bloco de gelo do jogo (`IceFX.congelar`), com 0,5 s de imunidade depois. Vale em rede (o servidor espalha) e para não-jogador, que tem a física parada. Na prévia, o alvo de treino entra no bloco.
- **Projéteis → Sai de:** Corpo, Mão direita, Mão esquerda ou Entre as mãos.
- **Sons:** "Gelo: disparo" (o estalo cristalino do Z antigo da Hie) e "Gelo: rajada".
- `test_builder_gelo`, `test_hie_builder` e `net_hie_*_probe`.

### Rodada 4: animações em pé, Publicar na loja, poses básicas e ▶ Testar no jogo (07/10/2026)

- **Animações fiéis ao Mixamo (07/10, 2ª rodada):** o "meio de lado" e o "muito parecidas" vinham do BAKE. A conversão no espaço do esqueleto do .glb deitava o corpo em todo golpe que gira o quadril e espelhava o antebraço, e todos os golpes acabavam numa mesma silhueta torta. Os 61 clipes foram reassados na conversão v3 (`docs/ANIMACOES_MIXAMO.md`), o que vale para o jogo inteiro: Builder, M1, corrida, roll, deslize e parkour. A correção paliativa do tronco (`endireitar`) saiu. Medido contra o .glb em `test_fidelidade_dos_clipes`.
- **Lista enxuta:** os repetidos `boxing_1`, `roundhouse_kick_2` e `run_to_stop_2` (mesmo conteúdo do gêmeo) saíram da lista. Skill antiga com esses nomes continua valendo e toca o gêmeo (`ClipesDeSkill.RENOMEADOS`; o campo mostra o atual). Os que quase não se mexem (`bouncing_fight_idle`, `boxing_3`, `gunplay`, `falling_idle`, menos de 15° no clipe inteiro) foram para Postura, fora de Combate. Ficam 58 clipes e 5 atalhos. A lista mostra a duração na frente do nome ("1,27 s · punching"; 08/10, `ClipesDeSkill.rotulos()`); o valor gravado continua o nome.
- **Publicar na loja** (o botão Publicar): a skill vai ao jogo e a fruta (ou o Kit do Builder, para skill sem fruta) fica à venda no vendedor de frutas do Modo História pelo **Preço na loja** do campo Fruta (padrão 1; `frutas.json`/`kit.json`, campo opcional `preco`). A fruta da arena refeita avisa que já é vendida. `test_publicar_na_loja`.
- **Poses básicas** (seção Poses): 12 prontas, medidas no rig (mão × ombro, pé × quadril) e fotografadas — guarda, socos D/E, chute frontal, apontar, braços abertos, mãos ao céu, defesa cruzada, base baixa, investida, carregar (mãos juntas), arremessar (`poses_basicas.gd`; `test_poses_basicas`).
- **▶ Testar no jogo:** o jogador de verdade no Modo História, numa plataforma de teste (60 × 60 m, bordas para o vazio, parede a 26 m), com a skill aberta na tecla, a fruta comida, energia cheia e 4 bonecos que se recuperam. Esc (ou "Voltar ao editor") volta ao editor com a skill como estava. O catálogo publicado é copiado para `user://teste_do_builder` e o save é de teste: nada do jogo de verdade muda, nem se você sair pelo menu (`teste_no_jogo.gd`; `test_testar_no_jogo`).
