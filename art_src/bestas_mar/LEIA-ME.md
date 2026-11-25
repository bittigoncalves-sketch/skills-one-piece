# Bestas do mar

Quatro modelos produzidos a partir das imagens fornecidas em 01/10/2026. Direção confirmada pelo usuário: fidelidade às referências do anime. A imagem do javali é monocromática; sua paleta marfim/verde acinzentado é uma interpretação. Caudas, nadadeiras laterais e anatomia submersa completam as partes não mostradas nas referências.

## Arquivos e edição

- `besta_mar_*.blend`: fonte editável, malha com UV e materiais, imagens incorporadas e armature visível através da malha no Blender.
- `besta_mar_*.glb`: malha, texturas, skin, 17 ossos e quatorze clipes embutidos (doze ações e dois aliases antigos). Cópia usada no jogo: `mapas/modelos/`.
- `*_pele.png`, `*_cabeca.png`: texturas autorais geradas deterministicamente, sem downloads ou serviços externos.
- `*_medidas.json`: contagem real de geometria, ossos, pesos inválidos e deslocamento da malha sob pose da mandíbula.
- Gerador canônico: `tools/blender/bestas_mar.py`. Alterações manuais no `.blend` devem ser preservadas antes de regenerar; o gerador sobrescreve os quatro fontes/exportações.

```bash
XDG_CACHE_HOME=/tmp/sop-blender-cache blender -b --python-exit-code 1 --python tools/blender/bestas_mar.py
./find_godot.sh   # localiza o executável para os comandos abaixo
/caminho/godot --headless --path . --script tools/registrar_bestas_mar.gd
python3 tools/validar_bestas_mar.py --capturar
```

Os comandos partem da raiz do projeto. Para regenerar uma espécie, acrescente `-- bovina`, `-- girafa`, `-- javali` ou `-- serpente` ao comando Blender. O registrador mede de novo o GLB e atualiza o SHA para invalidar o cache de miniaturas.

## Rig e escala

Blender usa Z para cima e +Y para frente. A exportação converte para Y para cima e **−Z para frente**, conforme o projeto. Unidades em metros; o editor usa a dimensão nativa, editável depois por instância. O ponto zero é próximo ao fundo do corpo; para apresentação na água, a superfície cruza aproximadamente Y=3,2 m em coordenadas locais do GLB.

Hierarquia: `raiz → corpo`, quatro ossos de cauda, cinco de pescoço, `cabeca → mandibula` e duas articulações para cada nadadeira lateral. Pesos normalizados e transições no corpo e nas nadadeiras. Mandíbula, dentes inferiores e presas inferiores acompanham o mesmo osso. Os clipes `idle`, `dormindo`, `nadando_walk`, `nadando_run`, `irritado`, `atacando`, `recebendo_dano`, `disparando_ataque` e `comendo` animam corpo, pescoço, cauda, mandíbula e nadadeiras, sem deslocar a raiz. `repouso`/`ameaca` mantêm compatibilidade. No Blender ficam em trilhas NLA desativadas para editar a pose de repouso; ative uma trilha por vez para visualizar.

## Loja e alcance

Abra o **Editor de mapa → Loja → Bestas do mar**. As quatro entradas podem ser inseridas, redimensionadas e salvas como os demais modelos. Não há ficha de animal terrestre. Desde 06/10/2026, peças desses quatro modelos ganham IA e reprodução dos clipes no modo história: Sea Serpent hostil com bolhas; demais pacíficos até apanhar, abandonando a perseguição e voltando à praia quando o atacante se afasta. O editor mantém as peças editáveis; não há população automática do mapa.

Validação reproduzível e capturas da engine: `art_src/validation/bestas_mar/`. O combate foi validado em integração; aprovação artística pelo usuário e exportação final do jogo não foram avaliadas.

## Serpente: cabeça no estilo do anime (02/10/2026)

Pedido do dono: a cabeça antiga "horrível" refeita para se parecer ao máximo com o quadro do
anime `~/Downloads/seaserpent.webp`, estilo anime, sem obrigação de low poly; mudar o tamanho
e a estrutura da cabeça. Escolha do dono: **anime completo** (contorno, linhas pintadas, toon).

- Gerador: ramo `serpente` de `build_head` → `serp_cabeca` / `serp_crista` em
  `tools/blender/bestas_mar.py`. Crânio contínuo por seções (`SERP_CRANIO`) subdividido:
  focinho longo de crocodilo com nariz bulboso, testa larga, sobrancelha em V bravo (ponta de
  dentro baixa, entre os olhos), olhos vermelhos no alto olhando para a frente, boca fechada
  que sobe no fundo com dentes triangulares encaixados à mostra, linhas de tinta (rugas),
  crista em espinho listrada (branco/azul-claro, linha azul) da testa à nuca e barbatana
  listrada na garganta.
- Tamanho: a cabeça é modelada e escalada ×`SERP_ESCALA` (1,55) em volta da junta; topo do
  pescoço afinado. Cabeça/pescoço no quadro 3/4: 2,0× (anime ≈ 2,5×; antes 1,3×).
- Visual anime no Godot: `mapas/modelos/besta_mar_serpente.glb.import` usa
  `import_script/path = res://src/world/importacao/estilo_anime.gd` — materiais toon + passe
  de contorno (casca invertida), olhos com leve brilho; linhas de tinta sem contorno. As
  outras três bestas continuam com a luz normal.
- Prova visual: `tools/capturar_serpente_anime.gd` grava `art_src/validation/bestas_mar/anime/`
  (`comparacao.png` = referência | Godot no mesmo 3/4 | lado | corpo; `ameaca.png`).
- Versão anterior (cabeça antiga) guardada em `art_src/bestas_mar/anterior/`.


## Comportamentos e clipes — 06/10/2026

Fonte das animações: `tools/blender/animacoes_bestas_mar.py`, também chamada pelo
modelador canônico. Para editar/bakear apenas os clipes, preservando a geometria:

```bash
XDG_CACHE_HOME=/tmp/sop-blender-cache blender -b --python-exit-code 1 --python tools/blender/animacoes_bestas_mar.py
```

Reimportar os GLBs na engine e executar `tools/registrar_bestas_mar.gd` depois do
bake; o registro atualiza hashes do catálogo sem apagar outros itens/categorias.
Animações em loop: dormir, idle, comer e dois nados. Ações únicas: irritação,
ataque, reação e disparo. O controlador usa o tempo real dos clipes importados:
mordida em 52% (esfera de contato na boca), bolha em 54% (na ponta do focinho).
O `perfis.json` em `src/historia/bestas_mar/` reúne vida, dano, velocidades,
alcances e recarga para balanceamento, com valores iniciais de implementação.

As bestas colocadas perto da costa alternam descanso/sol, alimentação e passeios
na água. A fonte de água é `AguaDoMundo`, com flutuação nas ondas e subida da margem.
Pacíficas entram no grupo `enemy` somente após dano positivo; continuam alvos
atacáveis antes disso. O boss é hostil desde o início. Afastamento/obstáculo
prolongado encerra perseguição. Nenhum drop ou recompensa nova foi introduzido.

Validação: `test_bestas_mar.gd` + `test_comportamento_bestas_mar.gd` (com `-- --tela`
para captura em jogo). Galeria dos clipes: `tools/bestas_mar_comportamento_preview.gd`.
Evidências em `art_src/validation/bestas_mar/comportamento/`.

## Rotina de mergulho — concluída em 08/10/2026

Bovina, girafa e javali alternam dormir, observar/comer e passear no oceano.
O passeio inclui os clipes novos `mergulhando`, `nadando_submerso` e `emergindo`,
com deslocamento vertical físico, nado na profundidade e retorno à praia. O
sono recolhe mais o pescoço e a cabeça. O fundo limita a descida; águas rasas
mantêm nado de superfície. Pontos de passeio ficam a cerca de 100 m da costa.
Ao apanhar, a rotina é interrompida: a besta reage, sobe e desfere ataques;
afastamento ainda encerra o revide. Sea Serpent mantém vigilância e prioriza
as bolhas ao detectar alvo, sem entrar na rotina pacífica.

Novos testes: `test_rotina_oceano_bestas.gd` (30/30 headless, 29/29 gráficos
antes da asserção adicional de água rasa). Regressão de combate 64/64; assets,
praia/oceano e ondas/barcos passam. Galeria de 28 poses em
`art_src/validation/bestas_mar/mergulho/poses/`; ciclo físico capturado na pasta
pai. Reproduzir a galeria: Godot com tela, script
`tools/bestas_mar_comportamento_preview.gd -- --mergulho`.


## Postura de foca e leão-marinho — 08/10/2026

- **Deitadas:** dormir e nadar (`Animador.DEITADOS`).
- **Em pé:** parada e andando na areia, boiando parada na água, ameaçando e atacando.
- **Clipes novos:** `boiando`, `andando_terra` e `correndo_terra`. No total são 17 por espécie.
- **A raiz agora se move nos clipes deitados:** desce 0,75 m e inclina no mergulho. O
  gerador grava chave de posição da raiz; sem ela, o GLB saía com o corpo flutuando.
- **Prévia sem assar** (3/4, perfil e topo):
  `DISPLAY=:1 blender -b --python tools/blender/previa_poses_bestas.py -- <pasta> bovina,serpente dormindo:0.25,nadando_walk:0.5`
- **Cabeça nivelada dormindo e nadando:** é feita no jogo (`animador._nivelar_cabeca`),
  não no clipe.
- **Giro, inclinação na curva e mergulho de 60 s:** ver `docs/BESTAS_MAR_CHECKPOINT.md`.

