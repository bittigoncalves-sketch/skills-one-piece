# Refatoração das logias do modo história — checkpoint (24/11/2026)

Meta do dono: logias do modo história **sem o efeito logia** (transformação elemental/voo forçado), com a **qualidade do Mine Piece**
mantida; **habilidades que não travam as outras**; começar pelo **gelo**; cada fruta refatorada **no inventário de teste**, **testada**
e com **sons novos por ataque**. Plano e imagens: Codex (`docs/LOGIAS_PLANO*`, `art_src/references/logias_codex/`). Sem perguntas ao dono.

## Mecanismo (genérico, reaproveitado por cada logia)
- Ficha do `catalogo.gd`: `"paralelo": true` + `"sem_logia": true` + `"recarga"` em cada técnica do `ciclo`; a fruta entra em `REFATORADAS`.
- `controlador.gd`: modo paralelo = cada tecla abre uma `SessaoDeTecnicaMinePiece` (`sessao_de_tecnica.gd`) com executor próprio,
  `segurando`, `lentidao` e recarga PRÓPRIOS. Só vale a recarga da própria técnica, a energia e o corpo livre. `corpo` (logia) fica nulo.
- Executor traduzido do mod continua igual; entidades que sobrevivem à técnica (lanças, pássaro, punho, tornado) recebem
  `c.controlador()` (não a sessão, que morre com a técnica).
- Decisão declarada: a Lentidão do mod durante a carga FICA (fidelidade); o que deixou de existir é uma técnica impedir as outras.
  GATILHO: se o playtest achar a carga presa demais, reduzir `lentidao` só no modo paralelo (um ponto: `_passo_paralelo`).

## Feito
| fruta | paralelo | sem logia | sons novos | inventário | testes |
|---|---|---|---|---|---|
| Hie Hie (gelo) | sim | sim | 11 (`tools/generate_hie_audio.py`) | sim | `test_hie_paralelo` 39, `test_hie_mine_piece` 45 |
| Moku Moku (fumaça) | sim | sim | 10 (`tools/generate_moku_audio.py`) | sim | `test_moku_mine_piece` 27 |
| Pika Pika (luz) | sim (a passiva do toque duplo abre sessão 28 sem travar nada) | sim | 14 (`tools/generate_pika_mp_audio.py`, sem grave: a lei da luz, medida) | sim | `test_pika_mine_piece` 36 |
| Goro Goro (raio) | sim (`SessaoGoroMinePiece`, `D`/`z`/recarga por técnica; `SEM_LOGIA`) | sim | 11 (`tools/generate_goro_mp_audio.py`) | sim | `test_goro_mine_piece` 64 (+ shunshin/poses) |
Bateria genérica de todas as refatoradas (inventário, preparo, paralelismo, recarga individual, repouso, sons): `test_logias_refatoradas` 29/29.
Regressão sem alteração: Nikyu 66, Luta 33, Ope 23. Biblioteca de síntese: `tools/audio/sintese.py`.

| Mera, Magu, Suna, Yami, Mori (fluxo do mod) | sim, por troca de contexto (`SessoesDoMod`: o estado privado de cada técnica sai/entra no NBT do mod; a viva é dirigida pelo efeito nativo, as estacionadas à mão pelo mesmo gancho) | não havia logia a retirar (nunca usaram a transformação) | 28 (`tools/generate_logias_mod_audio.py`: carga por fruta + disparo por técnica, tocados por `SonsDasTecnicas`) | sim | `test_logias_do_mod_paralelas` 40/40 (5 frutas: 3–4 técnicas juntas, recarga por técnica, tudo termina) |
Regressão do fluxo do mod: `test_controlador_fruta_do_mod` 31/31, `test_jogador_mod` 12/12.
Todas as logias com a tag `minepiece:logia` do mod estão feitas (hie, moku, pika, goro, mera, magu, suna, yami, mori).

## Falta
1. (Resolvido 24/11 20:20) Plano e imagens do Codex entregues: `docs/LOGIAS_REFATORACAO_PLANO.md` (critérios de aceite e ordem de playtest) e `art_src/references/logias_codex/` (4 imagens da Hie + 1 ficha por fruta das outras 8; são conceitos, não capturas). Pendente do plano: playtest do dono, escuta dos sons e, nas 5 frutas do fluxo do mod, conferir dano/carga de projétil persistente ao trocar de técnica.
2. Aprovação sonora/visual do dono: som medido só por espectro/clipping (pico −3 dB; Pika sem grave), nunca ouvido por mim.
3. Playtest da carga: a Lentidão do mod durante a carga continua (ver decisão acima).
4. Auditoria estática do risco abaixo (24/11/2026): das 88 procedures alcançáveis a partir de SkillMera/Magu/Suna/Yami/Mori, NENHUMA lê chave privada (`cnt*`, `skill`, `x/y/z_pos`, `x/y/z_power`, `Damage`, `Range`…) do DONO a partir de um projétil; as leituras achadas são de ALVOS (`RangeAttack`, `EffectConfirm1`, `GetDistanceNearestEnemy`) ou do próprio jogador por alias de lambda (`DaiEnkaiEntei`, `DarkMatter`). A única que segue o dono pelo estado é `RockFragmentOnEntityTickUpdate` (entidade de outra fruta, fora das cinco). Isto reduz o risco, mas não substitui o playtest do plano.
   Limite conhecido das sessões do mod: entidade que a técnica lança e que lê o NBT do DONO depois (ex.: `cnt6` de carga) vê o estado da técnica que estiver viva — igual ao mod, que zera os contadores a cada técnica nova. Se o playtest mostrar projétil com dano trocado, ampliar `SessoesDoMod.PRIVADAS` ou copiar o valor para o projétil na criação.

## Ferramentas
`tools/audio/sintese.py` (filtros/parciais/estalos), `generate_<fruta>_audio.py`, depois `godot --headless --import`.
Inventário: build de dev com janela entrega `REFATORADAS` ×3 (`ModoHistoria.frutas_refatoradas_de_teste`) + botão F8.

## Validação visual (24/11/2026, Weston isolado — `--renderer=gl` + Vulkan, sem abrir janela)
`captura_fruta_mine_piece.gd` (Hie, Moku, Pika) e `captura_frutas_do_mod.gd` (Suna, Yami, Mori, Mera, Magu; rodar uma fruta por processo — várias
seguidas abortam o motor no Wayland). Vistas por mim: Hie (Partisan, Ice Age), Pika (Laser), Suna (Sandstorm), Yami (Black Hole): efeito da
técnica na tela, HUD com recarga por técnica, nenhum corpo de raio/voo. Vistas depois: Moku (White Fist), Goro (El Thor), Mera (Flame Commandment), Magu (Meteor Volcano), Mori (Giant Tree) — as 9 logias têm captura examinada por mim. Observação (pré-existente, não mexida): no quadro da Mera, nomes longos ("Flame Commandment: Fire Pillar") encostam no texto de estado à direita ("faltam 11,8 s") — as linhas estão alinhadas (conferi nas capturas; eu havia descrito como deslocamento, e não é); falta só dar mais largura ao estado ou encurtar o nome.
Corrigidos no caminho: HUD escondia uma das duas "Yasakani" da Pika (chave por nome; `docs/erros.md`) e `terminar()` do `ControladorFrutaDoMod`
quebrava com o emissor da carga já liberado.

## Comparação com as referências do Codex (24/11/2026)
Hie, Ice Age: o jogo tem os mesmos ELEMENTOS da referência (disco de geada + cristais + névoa), não o mesmo acabamento (revisão do Codex, #206: cristais são cones azuis chapados, o centro fica muito branco, há planos retangulares translúcidos visíveis; a ficha mostra gelo facetado e fissuras) — avaliar no playtest e em cenários reais. Hie, Ice Ball: o jogo desenhava só uma placa translúcida; a referência mostra estacas de
gelo brotando ao longo da frente. Feito: `frente_de_gelo_visivel.gd` (cones de gelo que sobem em ease-out e somem em fade, semeados a cada passo da
frente por `hie.gd`) — conferido por captura; `test_hie_mine_piece` 45 e `test_hie_paralelo` 42 seguem passando. As outras 8 fichas (Moku…Mori) NÃO foram
comparadas com as capturas: é o próximo passo natural se o dono quiser alinhar o visual às referências (as fichas do Codex são conceitos; os READMEs
dele apontam limitações em Goro e Magu).
Moku, White Vine (comparada com a ficha do Codex): o funil existe e se lê (pilha de anéis brancos translúcidos = a geometria do tornado do mod, mais "bloco" que
o redemoinho suave da referência) — mantido por fidelidade ao Mine Piece. Moku (punho, investida, White Out) e as outras 7 fichas seguem sem comparação.
Mera (comparada com a ficha do Codex): o VFX do jogo é o das procedures do mod (anel e brilho de fogo, partículas), menor e menos dramático que o conceito — referência
não obriga alterar mecânica; não mexido. Corrigido no HUD (conferido em captura): nomes longos invadiam o estado à direita; `TecnicasHud.LARGURA` 390→440 e
`LARGURA_DO_ESTADO` 130→175 (o nome longo agora termina em reticências). Ainda resta, na linha TRAVADA (cadeado) da Mera, "requer 1000" encostando no nome.
Goro e Yami (fichas do Codex vs capturas): os dois seguem o padrão da Mera — no jogo os efeitos são as partículas/anéis/feixes finos das procedures do mod (raio azul com núcleo claro;
anel roxo no chão), bem menos volumosos que os conceitos (pilar de tempestade roxo; vórtice e nuvem de trevas). Os quadros capturados são de 0,3–1,2 s após o disparo e não
pegam o pico do El Thor do céu. Não mexido (a referência é conceito; o plano diz que não obriga alterar mecânica). Candidatos se o dono quiser mais volume: pilar do El Thor,
nuvem do Dark Matter, funil do Sandstorm. Pika, Magu, Suna, Mori e golpes restantes da Moku: sem comparação ficha × captura.
Pika, Suna, Mori, Magu (fichas vs capturas, 24/11/2026): Suna — o Sandstorm do jogo é um redemoinho de linhas escuras com partículas brancas, mesma ideia do funil da ficha (menos denso);
Pika — o laser aparece como feixe/halo dourado fino, o conceito tem feixe e pilar mais largos; Mori — o jogo mostra anel verde e partículas, a ficha tem raízes e a árvore gigante
(a Giant Tree do jogo não foi capturada no pico); Magu — blocos de rocha, bolas de fogo e partículas de magma no lugar do conceito (o README do Codex já avisa que Hound Blaze parece dragão e
Great Eruption emerge do chão). Conclusão geral: o jogo mantém o VFX das procedures do mod (fiel ao Mine Piece), mais fino/menos volumoso que os conceitos; as fichas servem de
meta de volume e silhueta, não de especificação. Falta só comparar os golpes da Moku que não vi (punho, investida, White Out) com a ficha.
Moku, White Out e White Launcher (fichas vs capturas, 24/11/2026): White Out — o jogo mostra um anel branco largo no chão e uma nuvem de fumaça em volta do corpo; a ficha tem muito mais volume de
nuvem. White Launcher — nos quadros de 0,6 s só aparece um arco branco ao lado do corpo (a investida é rápida e o quadro não pega o pico). As 9 fichas do Codex agora têm ao menos uma comparação.

## Consolidação da comparação ficha × jogo (24/11/2026) — vale esta seção sobre as linhas históricas acima
As 9 fichas do Codex têm AO MENOS UMA comparação com captura do jogo; não todos os golpes de cada fruta, e vários picos não foram capturados (El Thor do céu, Giant Tree, White Launcher).
As linhas anteriores que dizem "sem comparação" são do momento em que foram escritas e já foram superadas. Evidência preservada em `art_src/validation/logias_2026-11-24/`
(16 capturas: hie_partisan, hie_ice_age, hie_ice_ball_estacas e _antes_placa, moku_white_fist/white_vine/white_out/white_launcher, pika_laser_hud_6_linhas, goro_el_thor,
mera_flame_commandment_hud_antes/depois, magu_meteor_volcano, suna_sandstorm, yami_black_hole, mori_giant_tree). Capturas = Weston isolado, Vulkan; não são prova de comportamento em movimento nem de som.

## Segunda passada da Ice Age (24/11/2026, a pedido da revisão do Codex #206/#208)
Feito: albedo do disco 1,12/1,18/1,25 → 0,86/0,95/1,05 e emissão 1,4 → 0,65 (o centro deixou de ser mancha branca); luz 4,5 → 3; cada cristal sorteia um tom entre azul fundo e azul claro
(`MultiMesh.use_colors`, também nas estacas do Ice Ball); a placa quadrada translúcida do `BlockToIce` (`VfxFrutaMinePiece.placa`) saiu da Ice Age (o disco já marca o chão).
Conferido em captura (`hie_ice_age_depois_do_acabamento.png`); `test_hie_mine_piece` 45 e `test_hie_paralelo` 42 passam.
RESOLVIDO depois (mesma sessão): os retângulos pálidos eram a NÉVOA (`FxUtil.grain` sem textura = quadrados de ~3 m); confirmado desligando a névoa numa captura e corrigido com um degradê radial
na malha da névoa (`hie_ice_age_nevoa_macia.png`: agora são puffs suaves). `test_hie_mine_piece` 45 e `test_hie_paralelo` 42 seguem passando. Ainda faltam facetas/fissuras de verdade nos cristais —
decisão do dono, em movimento. (`FxUtil.grain` sem textura é armadilha geral: qualquer outro efeito que o use sem textura mostra quadrados.)
Bateria completa (`./validar.sh rapido`): iniciada e PARADA por mim — são 412 testes em série (horas) e os 2 primeiros que falharam (`test_agachar`, `test_agua`) não tocam em frutas; não há resultado
global de regressão, só os testes focados listados acima.

## Assets 3D por técnica (pedido do dono, 24/11/2026)
"Gere com o Blender um asset para cada técnica, com base nas imagens do Codex — ex.: Suna Suna, adaga de areia = uma adaga com textura de areia, que é disparada."
**Mecanismo:** `tools/blender/logias_assets.py` (headless: `blender --background --python tools/blender/logias_assets.py [-- nome …]`) modela cada asset e uma textura procedural do elemento
(areia, madeira, magma, fogo, trevas, luz, gelo, raio, fumaça — paletas tiradas das fichas do Codex) e exporta `assets/mine_piece/frutas/logias_mod/modelos/<nome>.glb` (textura embutida; PNG em `modelos/texturas/`).
O jogo troca o desenho do projétil por ele em `AssetsDeTecnica` (`src/combat/frutas_do_mod/assets_de_tecnica.gd`), chamado por `McTipoEntidade.create` logo depois de criar o corpo; a chave é
`fruta|técnica em execução|entidade` (a técnica em execução vem de `ControladorFrutaDoMod.tecnica_em_execucao`, que enxerga a sessão paralela em tick). Dano, hitbox e movimento continuam sendo do mod;
só o desenho muda. A ponta do asset é +Y do Godot (o corpo alinha o +Y à velocidade; antes da 1ª velocidade já nasce apontando para a mira).
**Feito (13 entradas, 10 assets):** Suna 21 e 24 (adaga de areia; a Spada é a mesma ×2), 22 (cimitarra de areia); Mera 22 (punho de fogo), 25 (bola de fogo), 26 (sol de chamas);
Magu 21 e 24 (rocha de lava), 22 (cabeça de cão de magma); Yami 23 (esfera de trevas), 28 (esfera grande); Mori 22 e 24 (estaca de madeira com raízes).
**Validado:** `test_assets_de_tecnica` 28/28 — cada asset da tabela existe e tem malha+textura, e CADA técnica da tabela, disparada de verdade, cria um corpo com o asset (incl. a adaga que anda >1 m).
Capturas em `art_src/validation/logias_2026-11-24/asset_*.png` (a adaga em voo e nascendo apontada; cão de magma, estaca e punho de fogo).
**Honesto sobre a qualidade:** é a PRIMEIRA versão — malhas simples (caixas/cones/esferas com ruído) e texturas procedurais, não arte final. Na adaga a silhueta e a textura de areia leem bem; o cão de magma é
um bloco; a estaca de Mori mal se distingue na captura (o mod ainda desenha outras coisas perto); o punho de Mera é pequeno a distância. Só olhei a Suna em voo com atenção; as outras: captura única.
**Pika (executor próprio) — ligado depois:** a flecha de luz do Yasakani (`luz_pika.gd`) agora leva o dardo 3D `pika_lanca_de_luz.glb` à frente do traço (`test_assets_de_tecnica` 29/29 inclui o dardo nascendo).
**Não coberto:** Goro usa executor autoral e seus raios são feixes (`VfxGoroMinePiece`), não projéteis com corpo; Hie e Moku já tinham modelos (`mp_partisan`, `mp_passaro`, `mp_bola_de_gelo`, `mp_punho`…). Técnicas de área/campo (Sandstorm, Black Hole, White Out…)
não são projéteis: um "asset disparado" não se aplica; ficam como VFX.
**Gatilho para a próxima passada:** o dono olhar as capturas e dizer quais assets valem arte final (modelagem à mão no Blender, facetas, textura pintada a partir das fichas do Codex).

Folha de contato dos 10 assets (renderizados no Blender): `art_src/validation/logias_2026-11-24/assets_blender_folha_de_contato.png`. Revisão por imagem: a cimitarra de Suna era uma fileira de caixas em zigue-zague —
refeita como varredura em arco (crescente de verdade, `assets_blender_cimitarra_e_cao_v2.png`); a cabeça de cão de Magu virou crânio + focinho + mandíbula aberta + orelhas + presas (segue blocada, no estilo
voxel do resto do jogo). Bom: adaga, bola de fogo, sol, rocha de lava, esfera de trevas, estaca de Mori. Fraco: o punho de Mera lê como blocos empilhados; a lança de luz da Pika é fina demais.
Segunda revisão por imagem: o punho de Mera foi refeito (palma, 4 dedos dobrados com falange e ponta, polegar, cauda de chama) e lê como punho blocado; a lança de luz da Pika ficou mais grossa (`assets_blender_punho_e_lanca_v2.png`). `test_assets_de_tecnica` 29/29 depois.
