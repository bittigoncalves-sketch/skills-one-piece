# Pika Pika no Mi refeita no Skills Builder + Q (rolar/dash) — plano (06/10/2026)

Pedido do dono: "iniciar reconstrução da pika pika no mi através do editor com exceção do
V, este poderá ser mantido. modificar o Z para raio único, o X para teleportar aéreo
assim que a habilidade for iniciada, estando no ar a habilidade será iniciada, o jogador
será posto na troca de posição igual a atual, porém quando chega ao final, ao invés do
jogador cair, ele atira uma esfera de luz que explode no chão; o C consertar o
direcionamento que está gerando a skill atrás do jogador. transformar o rolamento do Q
atual do modo história no Q do singleplayer, sendo que quando Q pressionado no ar
passará a ser o dash com seu efeito de VFX e som característico."

## Decisões do dono (06/10/2026)

| tema | decisão |
|---|---|
| como entra | o Z, X e C publicados no Builder **substituem** os da `pika_pika` (arena e história); o **V continua o de hoje** (código) |
| Z | **feixe instantâneo** até 40 m, dourado |
| X | sobe (teleporte para o alto; se já está no ar, começa dali), faz no ar o **zigue-zague de luz** de hoje (esquerda, direita, esquerda; 21 m) e no fim **atira para baixo uma esfera de luz que explode no chão** (dano em área). **Sem** o mergulho no meio |
| C | refeito no Builder com a direção certa (hoje nasce atrás do jogador) |
| Q | **no chão rola** (o rolamento de hoje), **no ar faz o dash antigo** (12 m em 0,28 s, anel de choque e som) — **arena e Modo História** |

## Decisões técnicas (com custo e gatilho)

| decisão | por quê | custo | risco / gatilho |
|---|---|---|---|
| "É do Builder?" passa a valer **por tecla** (fruta + tecla), não pela fruta inteira. A `pika_pika` vira **fruta reconstruída**: entrada em `frutas.json` que aponta para a fruta da arena; tecla com skill publicada usa o Builder, tecla sem skill usa o código | o V fica em código sem duplicar nada; o mesmo serve para refazer outra fruta depois | médio (os pontos de custo/recarga/autorização/disparo do Player, o cast_controller, a HUD) | mexe no caminho de cast que todas as frutas usam: rodar `test_frutas`, `test_frutas_na_historia`, `test_frutas_acertam_npcs` e a sonda de rede |
| O Builder ganha o que a Pika pede, como campos **opcionais** (skill antiga continua válida): movimento com ângulo/inclinação e teleporte; "flutuar" (sem gravidade durante a skill); VFX "Cometa" (o corpo vira luz); feixe e hitbox que seguem a mira (com pitch) e param na parede; projétil para baixo que explode ao tocar; mirar no mais próximo | é o editor que o dono quer usar para refazer a fruta: o que for feito à mão por fora não volta para ele | médio | gatilho para virar recurso próprio: um segundo uso (outra fruta) |
| A Pika nova é feita por um script que **opera o editor** (como a Noro): `tools/criar_pika_pika.gd` | reproduzível; o que sai é o que o dono veria fazendo à mão | baixo | — |
| Dano da Pika nova: Z 98 (o total de hoje, 7 × 14), X 160 (o de hoje), C 48 por acerto, até 8 (= teto de hoje, 384) | o balanço da arena não muda com a troca | — | — |
| Q no ar = dash antigo (pressionar dispara, como o rolamento; sem mirar segurando) | coerente com o Q de hoje | baixo | o dash é local (sem RPC), como sempre foi |

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| 1 | Fruta reconstruída (Builder por tecla) | skill publicada na `pika_pika` substitui só aquela tecla, na arena e na história; V segue o código; custo/recarga/HUD/rede pela tecla; teste | **feito** — `SkillsPublicadas.reconstruir_fruta_da_arena`/`e_reconstruida` (`"reconstroi": true` no `frutas.json`), `KitDoBuilder.pelo_builder(fruta, tecla)` nos pontos de custo, recarga, autorização, disparo (Player), cast, barra da arena e ficha da história; editor: "Refazer fruta do jogo" (campo Fruta, agora em `campo_de_fruta.gd`); `test_fruta_reconstruida` 12/12 |
| 2 | Recursos novos do Builder | campos opcionais no contrato, executor, prévia; teste de cada um | **feito** — Flutuar, Mirar no alvo, modo Sustentar, movimento com Ângulo/Inclinação/Teleporte/Só do chão, hitbox e VFX "Seguir a mira" (param na parede), VFX Cometa e Explosão, projétil "Sai para" (Abaixo), Explosão ao tocar, Só efeito, sons "Luz: …" (a voz da Pika), Cor secundária; Player: `definir_flutuar`, `ocultar_corpo_por_skill`; `test_builder_recursos_pika` 11/11 |
| 3 | Pika no editor | `tools/criar_pika_pika.gd` publica Z (feixe), X (sobe + zigue-zague + esfera) e C (sobe + barragem na frente); teste em jogo dos três | **feito** — publicada em `res://mapas/skills` (`pika_raio_z`, `pika_yata_x`, `pika_yasakani_c`); `test_pika_builder` 11/11 (Z 11,96 na história = 98 × 250/2048; X sobe 6 m, some, zigue-zague −4,9…+5,1 m até 21 m, esfera fere embaixo do fim, pousa; C vai para o alvo atrás, 5 acertos em 1,25 s, soltar encerra; V do código) |
| 4 | Q: rolar no chão, dash no ar | `DashController` decide pelo chão; dash 12 m/0,28 s, anel + som; teste nos dois modos | **feito** — `DashController` (`rolando()`/`dash_no_ar()`), clipe do roll só no chão; `test_q_rolar_e_dash` 10/10 (história e arena: roll 8 m sem anel; dash 12 m em 0,25 s, desce 3 cm, anel + som, imune); `test_roll_deslize` 19/19 |
| 5 | Validação | bateria; auditoria das frutas (Pika acerta os 3 NPCs); sonda de rede da Pika; fotos com GPU | **feito** — bateria completa de 07/10: 159 passou / 15 falhou = as 12 conhecidas com os mesmos números + `test_sala_publica` (ambiente, UPnP) + duas minhas, corrigidas e rodadas de novo: `test_frutas_na_historia` (custo de energia, erros.md) e `test_q_rolar_e_dash` (o teste contava o som de 0,22 s no fim do dash, erros.md). Auditoria: Z 12/12/12, X 20/20/20 (o jogador começa deslocado para a esfera cair no alvo), C 47/47/47, V ✓; `net_pika_*_probe` (no `validar.sh`): Z 98, X 156, C ~4 acertos no servidor; fotos `capturar_pika_builder.gd` (feixe dourado, subida/cometa, esfera, explosão, barragem) |

Checkpoint: este arquivo é atualizado a cada fatia.

## Gatilhos do que ficou

- **Código antigo do Z, X e C da Pika** (`PikaFX._yasakani`, `_ViagemDeLuz`, `YasakaniController` e o portão do C no `cast_controller`/`Player`): fica sem uso, mas no lugar. Gatilho para apagar: o dono aprovar a Pika nova jogando.
- **Dash do ar sem pose própria** (usa a do ar, virado para o rumo). Gatilho: o dono pedir pose de investida no ar.
- **Projétil manual (esfera/fragmentos) sem colisão com personagem na prévia do Builder** (a prévia mede pelo alvo). Gatilho: diferença vista entre prévia e jogo.

## Em aberto (decisão do dono)

- **X sobre buraco na arena.** O zigue-zague anda 21 m sem olhar o chão; ao fim o jogador
  desce de onde está. Visto no `test_frutas` (07/10): do spawn da arena, olhando −Z, o X
  termina sobre um buraco e o jogador morre ("caiu do mapa"); o C e o V da Pika ficam sem
  medição nesse teste. O X antigo mergulhava no alvo antes do fim, por isso não aparecia.
  Proposta: opção genérica de movimento no Builder "parar antes do vazio" (a perna que
  sairia sem chão embaixo encurta; a esfera sai dali). Aguardando o dono.

---

# Rodada 2 (07/10/2026) — Z carregado, X que termina no inimigo, C em chuva, 0,5 s entre golpes

Pedido do dono: "disparo do laser Z só deve ocorrer após a tecla Z ser liberada; X caso
detecte algum inimigo próximo ou embaixo da técnica ela é encerrada em cima daquele
inimigo; C deve ocorrer em uma ampla área, uma ampla dispersão de bolinhas de laser
amarelas para todos os lados da mira do jogador; calibrar a mira do laser Z; adicionar
restrição onde um ataque só pode ser lançado 0,5 segundos após o outro. Qualquer
alteração que não conste no editor deve ser adicionada, visando seu aprimoramento."

## Decisões do dono (07/10/2026)

| tema | decisão |
|---|---|
| 0,5 s | vale para os golpes de fruta (Z/X/C/V) de **todas as frutas**, arena e história; no editor, campo por skill (padrão 0,5) |
| Z | apertar acende na mão uma **estrela de quatro pontas** que cresce; **soltar dispara** o raio (instantâneo); a carga aumenta o **empurrão até 1,5×** (arremesso mais forte e rápido); dano fixo |
| X | se houver inimigo perto ou embaixo da trajetória (~6 m), o zigue-zague **termina em cima dele** e a esfera cai nele; sem inimigo, **pára antes do vazio** (não sai de cima do chão) |
| C | **chuva na área mirada**: as bolinhas amarelas sobem e caem espalhadas num círculo largo (~10 m) em volta do ponto mirado |

## Medição antes de mexer (mira do Z)

`tools/dev_tests/medir_mira_z_pika.gd` (história, 5 alvos de 5 a 34 m, retículo no peito
pela câmera): a LINHA do raio passa pelo ponto do retículo (erro 0,00 m) e acerta em
todos. O erro é de ORIGEM: o raio nasce a 0,54–0,89 m da mão direita (sai do centro do
peito, altura 1,35 m) — na foto da câmera do jogo ele sai da cabeça e a mão estendida
fica ao lado. Calibrar = o raio (VFX e hitbox) nasce na mão (`Hand_R`) e continua indo
ao ponto do retículo.

## Decisões técnicas (com custo e gatilho)

| decisão | por quê | custo | risco / gatilho |
|---|---|---|---|
| 0,5 s = intervalo PRÓPRIO (`_intervalo_golpe`), não a `TRAVA_POS_FRUTA` desligada | a trava antiga pausava as recargas e mostrava contador; o pedido é só espaçar golpes | baixo | o servidor confere com folga de latência (80 %) e só entre teclas diferentes (rajadas de um golpe não são barradas) |
| Campos novos, todos opcionais: `configuracoes.intervalo_depois`; `ativacao.empurrao_carga_max`; `vfx.estilo` "Estrela"; `vfx.na_mao` e `hitboxes.na_mao`; `configuracoes.fim_sobre_alvo`, `parar_no_vazio`, `inicio_do_fim`; `projeteis.direcao_disparo` "Chuva" + `area_chuva` | o dono quer tudo no editor | médio | skill antiga continua válida |
| Carregar e soltar MIRA DE NOVO ao soltar (o soltar leva a mira em rede) | a câmera anda enquanto carrega | baixo | — |
| Lógica nova do executor em arquivos próprios (o executor tem 613 linhas, teto 900) | teto de linhas | baixo | — |

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| R1 | 0,5 s entre golpes de fruta | tecla nova em < 0,5 s é recusada; depois passa; vale para fruta em código e do Builder; servidor confere | **feito** — `Player.INTERVALO_ENTRE_GOLPES`/`armar_intervalo_de_golpe` (armado em `trigger_skill_cooldown`), portão em `cast_controller.comecar`, servidor em `_autorizar_cast_remoto` (80 %, teclas diferentes); campo `intervalo_depois`; `test_intervalo_entre_golpes` 19/19 (Goro, Pika arena e história, sem pausar recargas, servidor, campo do editor 1,2 s) |
| R2 | Z: carregar e soltar + estrela na mão + empurrão até 1,5× + raio nasce na mão | teste: nada sai segurando; solta = raio; empurrão 1× rápido e 1,5× cheio; raio nasce < 0,15 m da mão e passa no retículo | **feito** — VFX "Estrela" (textura de quatro pontas gerada no código), `na_mao` (VFX e hitbox), `empurrao_carga_max`, `mirar_de_novo` no soltar (a mira viaja no RPC do soltar), recarga recomeça no disparo; `test_pika_builder`: estrela a 0,00 m da mão e cresce 0,44 → 1,03; raio nasce a 0,00 m da mão e passa a 0,00 m do retículo; sai para a mira do soltar; empurrão 1,00×/1,50×; rede: segurando 0, solto no host 98 |
| R3 | X: termina no inimigo + pára antes do vazio | teste: inimigo a 5 m do caminho → esfera nele; caminho sobre buraco → pára com chão embaixo | **feito** — `viagem_de_skill.gd` + `fim_sobre_alvo`/`parar_no_vazio`/`inicio_do_fim`; a esfera sai de cima do inimigo achado (igual em todos os peers); teste: com boneco a ~3 m do caminho termina a 1,3 m dele (não vai além de z −10) e a esfera fere; na arena, do spawn, pára com chão embaixo e não cai; rede 156 |
| R4 | C: chuva na área mirada | teste: bolinhas caem num raio ~10 m do ponto mirado e ferem; custo de quadro medido | **feito** — `chuva_de_projeteis.gd` + `direcao_disparo` "Chuva"/`area_chuva`; semente = mira + origem (mesma nos peers); estouro pequeno sem luz, som a cada 90 ms; Sustentar: soltar pára as ondas e o que saiu cai; teste: 112 estouros até 9,0 m do ponto mirado, boneco do meio 7 estouros (280 da arena, segurando tudo), nada a 22 m; pior quadro de física 6,55 ms com e sem chuva; rede: 1,1 s segurando = 385 com a 1ª distribuição (concentrada) → trocada por uniforme (erros.md) |
| R5 | Pika republicada pelo editor + rede + fotos + bateria | `criar_pika_pika.gd`, sonda de rede, fotos GPU, bateria | **feito** (bateria em curso) — publicada pelo editor; sonda de rede Z 98 / X 156 / C ok; fotos (`capturar_pika_builder.gd`): estrela na mão, raio da mão, X em cima do boneco, chuva; 15 testes vizinhos verdes |

### Gatilhos do que ficou (rodada 2)

- **Braço não segue a inclinação da mira** no Z (a pose "Apontar" é fixa; o raio sai da mão e vai ao retículo). Gatilho: o dono mirar muito para cima/baixo e estranhar o braço.
- **Centro da chuva é o da hora do lançamento** (segurar o C e girar a câmera não arrasta a chuva). Gatilho: o dono pedir chuva que segue a mira — exige mandar a mira pela rede a cada onda.
- **X: cada peer decide "terminar sobre o inimigo" pelo que vê** (a esfera sai de cima do inimigo achado, então o dano bate mesmo com atraso). Gatilho: divergência vista em rede → a autoridade decide e manda por RPC.
- **HUD do Z carregando** mostra a recarga do aperto até o soltar (aí recomeça cheia). Gatilho: o dono estranhar o número.
- **Custo de GPU da chuva não medido** (a captura grava PNG a cada foto; o FPS dela não serve). Gatilho: queda de quadro percebida no jogo → medir com o monitor de desempenho, sem captura.

---

# Rodada 3 (07/10/2026) — dash no ar menor, segurar sem andar, F (voo) da Pika, animações e âncora do VFX

Pedido do dono: "diminuir impulso do dash no ar, está muito alto. quando o jogador está
segurando uma skill ele não consegue se mover a não ser que a skill diga o contrário
[...]. adicionar o F do voo da pika pika no mi. adicionar mais animações ao skill
builder e corrigir as animações atuais, adicionar as animações do rolamento e de
combate também, bem como adicionar a opção de selecionar onde uma skill VFX tem sua
âncora inicial, começando por player até qualquer objeto, animação ou projétil na cena,
podendo até ser no inimigo."

Antes, ainda no dia: o "travamento na prévia" relatado não se reproduziu com a máquina
saudável (pior quadro 10–20 ms, áudio real, 12 s de silêncio); na hora do relato a
máquina estava sem memória (troca 4/4 GB, carga ~40) e a bateria rodava junto
(`tools/dev_tests/medir_engasgo_da_previa.gd`). Aguardando o dono testar de novo.

## Decisões do dono

| tema | decisão |
|---|---|
| dash no ar | 8 m em 0,28 s (era 12 m) |
| segurar sem andar | skills do **Builder**: segurando (Carregar e soltar, Sustentar, carga do Segurar) o jogador não anda nem pula; campo novo "Pode andar enquanto segura" libera; frutas em código ficam como estão |
| F da Pika | feito no Builder: **segurar F** = o corpo vira luz e voa para onde a câmera aponta, gastando energia por segundo; soltar pára e o jogador cai |
| animações | **unificar nos clipes Mixamo**: o bloco Animação lista os clipes do jogo (combate, rolamentos, parkour, idles); prévia e jogo tocam o MESMO clipe no tempo do bloco; os 5 nomes antigos viram atalhos |
| âncora do VFX (sem pergunta; padrão meu) | Jogador (como hoje), Osso do jogador, Alvo (inimigo mais perto), Projétil de um bloco (segue a bolinha), Ponto mirado, Mundo (fica onde nasceu) |

## Medição antes de mexer (animações)

O bloco Animação: na prévia toca um clipe do `AnimationPlayer` do modelo (Ataque =
`punching`, Planar = `jump`, Investida = `run`, Vendaval = `groundsmash`); no jogo,
`Player.tocar_animacao_de_skill` liga uma POSE procedural antiga (Ataque =
`bomu_z_strike`, Planar = `air_slam_dive`...). São coisas diferentes. O jogo tem 61 clipes
bakeados (`assets/animations/*.res`, trilhas por papel do rig, aplicadas por
`ProceduralAnimator.play_baked`), que valem para a prévia também (`BodyScanner`).

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| A | dash no ar 8 m | `test_q_rolar_e_dash` mede 8 m | pendente |
| B | segurar sem andar (Builder) + campo | teste: segurando o Z da Pika, W não anda e Espaço não pula; com o campo ligado, anda | pendente |
| C | animações unificadas | campo lista os clipes; prévia e jogo aplicam o mesmo clipe (medido: ossos iguais no mesmo instante); atalhos antigos | pendente |
| D | âncora do VFX | campo + executor + prévia; teste de cada âncora | pendente |
| E | F da Pika (voo) | movimento "Seguir a mira", custo por segundo; F roteado para a Pika (arena e história); teste: segurando F voa ~na direção da câmera, solta e cai, energia cai | pendente |
| F | validação | testes vizinhos, rede, fotos, bateria (com a máquina livre) | pendente |

---

# Rodada 4 (07/10/2026) — animações em pé, Publicar na loja, poses básicas, ▶ Testar no jogo

Pedido do dono: "verificar e corrigir o editor, especificamente as animações estão
incorretas, todas viram o personagem meio de lado, a única correta é a investida. criar
botão que disponibilize a fruta e skill criada na loja do modo história, tornar esse botão
o publicar atual. adicionar poses básicas ao criador de skills. adicionar uma plataforma e
um botão de play para teste das skills."

## Medição (animações)

Fotos do jogo e da prévia no mesmo instante: no Ataque (`punching`) o corpo inteiro
aparece tombado ~60° nos dois (a paridade prévia × jogo da rodada 3 estava certa: os
dois erravam igual). Inclinação LATERAL média do tronco (que é a RAIZ do corpo no rig):
`running` −3°, `sprint` (Investida) 8°, `idle` 34°, `punching` 44°, `kicking` 46°,
`bouncing_fight_idle` 51°, `roundhouse_kick` 73°, `falling_idle` 48°. O bake desses
clipes deixou o tronco inclinado de lado; só os de corrida (usados pela marcha) ficaram
retos.

## Decisões do dono

| tema | decisão |
|---|---|
| loja | o Publicar vira "Publicar na loja": a fruta com as skills fica à venda no vendedor de frutas da história; **preço no editor** (padrão 1 moeda); skill sem fruta vai ao Kit do Builder, que também vira item |
| poses | botão **"Poses básicas"** na seção Poses com ~12 prontas, que entram na skill para usar ou editar |
| teste | **▶ Testar no jogo**: plataforma de teste com o jogador de verdade (Modo História, save de TESTE), a fruta/skill do editor comida, energia cheia, bonecos; Esc volta ao editor com a skill como estava |

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| A | clipes em pé | correção da inclinação lateral média do tronco (só clipe que não gira o corpo inteiro), igual em prévia, jogo e cópia remota; foto de frente/lado; teste | **feito** — `ClipesDeSkill.endireitar` (fora: rolamentos e `dying`); 57 clipes com a média lateral ≈ 0°; fotos jogo × prévia de frente/lado (Ataque em guarda de pé); `test_animacoes_do_builder` 12/12; o M1 usa os mesmos clipes: item 67 da LISTA. **Substituído no mesmo dia:** a causa era o bake (conversão no espaço do esqueleto); clipes reassados na v3 e `endireitar` removido — ver `docs/SKILLS_BUILDER.md` |
| B | Publicar na loja + preço | campo de preço, Kit como item, loja lê o preço, aviso; teste | **feito** — `SkillsPublicadas.preco/definir_preco`, `PerfilDeFrutas.preco_na_loja`, Kit em `frutas_a_venda`; `test_publicar_na_loja` 12/12 |
| C | poses básicas | 12 poses medidas (mão × ombro) e fotografadas; botão; teste | **feito** — `poses_basicas.gd` + botão "Poses básicas"; a Investida compensa o tronco nas coxas (o tronco é a raiz); `test_poses_basicas` 15/15 |
| D | ▶ Testar no jogo | botão, plataforma, fruta comida, bonecos, Esc volta com o documento; save de teste; teste | **feito** — `teste_no_jogo.gd`; `test_testar_no_jogo` 8/8 (inclui sair pelo menu); fotos (plataforma, aviso no canto direito, Z acertando o boneco) |

### Gatilhos (rodada 4)

- `SkillsBuilder.gd` tem 854 linhas: passou de 880, o Publicar e o Testar saem para um módulo.
- `arena_preview.gd` (804) e `executor_de_skill.gd` (~810): passou de 850, a parte de clipes/âncora sai.
- Corpo a corpo com os mesmos clipes tortos: item 67 da `LISTA_DE_CORRECOES`.

## 10/10/2026 (Modo História)
Z: campo `ativacao.paralisar_segurando` — segurando, o jogador fica parado onde está,
inclusive no ar. Só na história. `test_pika_z_paralisa`. Ver `docs/PEDIDO_2026-10-10_HISTORIA.md`.
