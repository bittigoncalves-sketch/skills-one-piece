# Bestas do mar — 01/10/2026

Pedido: quatro modelos das imagens do usuário, ossos internos e cadastro na loja do editor do modo história. Direção confirmada: fidelidade ao anime. Não inclui IA, combate ou população automática do mapa.

Referência observada: bovino branco/verde com argola, girafa ocre com crina, javali de escamas/presas (imagem monocromática), serpente escura com olhos vermelhos e nadadeira clara. Cor do javali e partes submersas são interpretações, pois não estão definidas nas imagens.

Fonte planejada: `tools/blender/bestas_mar.py`, `.blend` e GLBs em `art_src/bestas_mar/`, cópias na loja em `mapas/modelos/besta_mar_*.glb`. Rig com pesos explícitos, cadeia de corpo/pescoço/cauda, mandíbula e nadadeiras.

Integração: categoria `bestas_do_mar`, sem ficha terrestre nem categoria de inimigo. Preservar catálogo e mapa vivo existentes. Agente `loja_bestas` cuida apenas do registrador e teste novos; principal modela e captura.

Estado: investigação concluída, produção em andamento. Próximo: gerar, importar, medir pesos/deformação, cadastrar, validar inserção/salvamento e capturar no Godot.

## 02/10/2026 — serpente refeita no estilo do anime

Pedido do dono: cabeça da serpente parecida ao máximo com `~/Downloads/seaserpent.webp`,
estilo anime ("anime completo": contorno, linhas e toon), tamanho e estrutura da cabeça
novos, sem low poly. Feito em `tools/blender/bestas_mar.py` (só o ramo `serpente`; as outras
três bestas não mudaram) + `src/world/importacao/estilo_anime.gd` (importação) +
`tools/capturar_serpente_anime.gd` (comparação lado a lado). Validação:
`test_bestas_mar` TUDO OK e `python3 tools/validar_bestas_mar.py --capturar` PASS. Detalhes em
`art_src/bestas_mar/LEIA-ME.md`. Versão anterior em `art_src/bestas_mar/anterior/`.


## 06/10/2026 — comportamento e animações (histórico da implementação)

Novo escopo autorizado: Sea Serpent é boss hostil e dispara bolhas de água.
Bovina, girafa e javali são pacíficos até sofrer ataque. Decisão do usuário:
afastar-se encerra a perseguição e os pacíficos voltam à rotina na praia.
Nove clipes: dormindo, nadando_walk, nadando_run, idle, irritado, atacando,
recebendo_dano, disparando_ataque e comendo. Preservar modelos, rig e estética.

Etapas: (1) clipes editáveis sobre os .blend existentes e exportação GLB;
(2) controlador de estados, locomoção praia/água, reações, ataque e bolha;
(3) ligar os modelos colocados pelo editor ao modo história e catálogo;
(4) testes reais de transições/combate/água e capturas de animação na engine.
Não povoar nem regravar o mapa vivo. Rotina usa a praia/origem onde a peça foi
colocada; não cria novas espécies ou drops. Reaproveitar água, dano e alvos.
Backup de fontes/GLBs/catálogo anterior: `sop-snapshots/2026-10-06-bestas-comportamento`
(irmão da pasta do projeto). Testes terão saves/mapas isolados.


Progresso de implementação:
- Fonte de animações: `tools/blender/animacoes_bestas_mar.py`, chamada também por
  `bestas_mar.py`. Atualiza .blend e GLBs sem regerar geometria. Nove clipes novos
  mais aliases anteriores `repouso`/`ameaca`; 36 poses capturadas no Godot.
- Runtime: `src/historia/bestas_mar/{besta_do_mar,animador,bolha_de_agua,populacao}.gd`
  e `perfis.json`; ligado no `ModoHistoria`, registrador atribui `besta_do_mar`.
- Primeiro teste 54/54; ampliado cobre contato físico da mordida e projéteis.
  As primeiras poses de ataque atingiam a 6–8 m de altura; corrigidas com dobra
  do pescoço medida no Blender e na engine: boca a ~1,3/2,0/1,2 m no jogo.
- Teste de retorno estava teleportando a besta abaixo do fundo em água rasa;
  corrigido para iniciar em água realmente funda. Runtime antecipa o fundo ao
  cruzar a margem. Última validação em execução. Não declarar entrega concluída.
- `test_bestas_mar` (GLB, skin, clipes, loja, salvar/reabrir): TUDO OK.
- Evidências e logs: `art_src/validation/bestas_mar/comportamento/`.
- Próximo: concluir retorno mar/praia, teste com tela final, regressões e docs.


## 07/10/2026 — comportamento e animações concluídos

Estado atual: implementação e validação concluídas; substitui as pendências acima.
Sea Serpent adquire o jogador sem provocação e dispara bolhas pela boca. Bovina,
girafa e javali descansam, dormem, comem e nadam; reagem ao dano, perseguem e mordem.
Ao perder o alvo por afastamento ou obstáculo prolongado, abandonam a perseguição
e voltam à rotina na costa, conforme a escolha do usuário.

Integração em `src/historia/ModoHistoria.gd`, controlador e perfis em
`src/historia/bestas_mar/`. Fonte editável dos nove clipes por espécie:
`tools/blender/animacoes_bestas_mar.py` e `.blend` em `art_src/bestas_mar/`.
O gerador completo também usa os clipes a 30 fps. Foram preservados rig, materiais,
estética e os aliases anteriores. Catálogo atualizado somente nas quatro bestas;
GLBs da loja conferidos com os fontes e hashes. Uso: Editor → Loja → Bestas do mar;
colocar perto da costa, salvar e entrar na história. Nenhuma população automática
foi criada; o mapa vivo não foi regravado por esta tarefa e atualmente não contém
instâncias dessas bestas.

Validação em Godot 4.6.3, com mapas e saves de teste isolados:
- `tools/dev_tests/test_comportamento_bestas_mar.gd`: **64/64 headless e 64/64 com
  tela**, cobrindo estados, agressividade, retorno físico do mar à praia, ondas,
  mordidas na boca, dano único, interrupção, bolhas bloqueadas por parede,
  esquiva, morte e restauração. Execução com tela sem erros ou avisos. Headless
  emite aviso de ObjectDB no encerramento, sem falha de asserção.
- `tools/dev_tests/test_bestas_mar.gd`: TUDO OK para rig/skin, clipes, catálogo,
  inserção e salvar/reabrir no editor.
- Galeria com 36 poses e capturas de integração inspecionadas na engine. Mordidas
  ajustadas após medir a boca: aproximadamente 1,32 / 2,02 / 1,21 m nas pacíficas.
- Regressões: praia/oceano, ondas/barcos e inimigos passam; espada inicial 30/30.
- `tools/dev_tests/test_compila.gd`: permanecem os seis scripts do studio de
  animação já listados como débito em `PROJECT_CONTEXT.md`; esse teste também
  emite erros de carregamento de autoloads e de recursos ao encerrar. Não é uma
  compilação geral limpa. O teste de inimigos emite aviso anterior sobre frutas.json.

Logs, medidas e imagens: `art_src/validation/bestas_mar/comportamento/`.
Detalhes de edição e regeneração: `art_src/bestas_mar/LEIA-ME.md`.
Limites: valores de combate são iniciais; balanceamento com o usuário e exportação
final do jogo não foram avaliados nesta tarefa. Não há próximo passo obrigatório
pendente para este escopo.

## 07/10/2026 — melhoria da rotina e mergulho (em andamento)

Pedido atual: pacíficas dormem, nadam, mergulham e atacam ao reagir; Sea Serpent
deve priorizar ataques. Confirmado: alternância automática praia/oceano, interrompida
quando provocadas. Sem mudança do mapa vivo ou dos parâmetros de dano/recarga.

Implementação: descanso → idle/comer → passeio no oceano → mergulho → nado
submerso → subida → praia; profundidade limitada pelo fundo físico. Boss fica
em vigilância e adquire alvo antes de qualquer rotina. Dano interrompe mergulho,
provoca reação e retorno à superfície para atacar.
Clipes novos autorais `mergulhando`, `nadando_submerso`, `emergindo`; sono com
pescoço/cabeça mais recolhidos. Fonte editável preservada em Blender.

Snapshot: `../sop-snapshots/2026-10-07-bestas-mergulho/`. Arquivos envolvidos:
controlador/animador/população em `src/historia/bestas_mar/`, gerador de animações,
fontes `.blend`, GLBs e registro das quatro entradas da loja.
Próximo: concluir bake/importação, testar ciclos reais, reação durante mergulho,
prioridade de ataques do boss e capturar as poses/transições na engine.
Evidências novas: `art_src/validation/bestas_mar/mergulho/`.

## 08/10/2026 — melhoria concluída

Substitui a pendência anterior. Rotina automática praia → mar → mergulho →
nado submerso → subida → praia integrada nas três pacíficas. Receber dano
interrompe a rotina e provoca revide. Sea Serpent fica em vigilância e combate.
Clipes novos nos quatro GLBs e fontes Blender; catálogo revalidado com hashes.

Validação: 30/30 no teste de ciclo headless (imersão 1,000 nas três espécies,
retorno físico e bloqueio em água rasa), 29/29 na rodada gráfica anterior à
asserção extra de água rasa; boss lançou 4 bolhas em 20 s, sem dormir/comer.
Regressão anterior 64/64; teste dos assets/clipes/loja, praia e ondas passaram.
Capturas de integração e galeria de 28 poses geradas; sono, mergulho, nado
submerso e disparo inspecionados na engine. `validar.sh` usa passo fixo para
o novo teste longo. Compilação geral mantém as seis falhas do studio separado
e seus erros de encerramento conhecidos. O teste antigo de combate ainda
emite aviso de ObjectDB ao fechar; os novos testes não têm erros de runtime.

Limites: sem alteração do mapa vivo/população automática; sem avaliação de rede
ou benchmark de performance. Fonte e evidência estão nas pastas da etapa acima.


## 08/10/2026 — postura de foca e leão-marinho (frente assumida pelo Claude)

Pedido do dono: "modificação nas animações das bestas do mar, bem como na velocidade de
rotação ao redor do próprio corpo; na terra, quando a besta estiver dormindo, ela deve
estar com o corpo completamente deitado, e o corpo deve estar deitado quando estiver
nadando no mar também; a besta não tem limite de respiração como o jogador, então pode
mergulhar por bastante tempo; inspiração focas e leões-marinhos". Escolhas: giro lento na
terra e ágil na água, inclinando na curva; as 4 bestas (a serpente também). Correções do
dono no mesmo dia: "as bestas devem ficar eretas quando andam em terra como antes" e
"movimentação à cabeça quando estiver nadando e dormindo para sempre estar olhando para
frente, na horizontal". A frente anterior (mergulho, 07/10) estava parada; snapshot em
`../sop-snapshots/2026-10-08-bestas-foca/`.

Estado: **feito e validado.**

- **Clipes** (`tools/blender/animacoes_bestas_mar.py`, prévia rápida em
  `tools/blender/previa_poses_bestas.py`):
  - **Deitados:** `dormindo` (barriga na areia, corpo em meia-lua) e os nados
    `nadando_walk`/`_run`/`_submerso`, `mergulhando` (nariz para baixo), `emergindo`.
    A coluna dobra para a frente repartida entre corpo e pescoço, a cauda compensa e a
    raiz desce 0,75 m. Isso é geometria, sem o `peso` da espécie; a cabeça da serpente
    ergue mais.
  - **Novos:** `boiando` (em pé na água, como a foca "de garrafa") e
    `andando_terra`/`correndo_terra`, eretos como o andar de antes.
- **Jogo** (`src/historia/bestas_mar/`):
  - O estado escolhe o clipe pelo meio (`clipe_do_estado`). Na areia: parada e andando,
    ereta; dormindo, deitada. Na água: parada, boia em pé; nadando, deitada.
  - Transição de 0,9 s quando deita ou levanta.
  - Giro com teto e aceleração: 35°/s na areia, 120°/s na água. Ela anda para onde olha.
    Nadando, inclina o corpo na curva (pivô no eixo do corpo, até 0,5 rad).
  - Cabeça estabilizada dormindo e nadando: olha à frente do rumo, nivelada.
  - Fundura na água: 3,2 em pé e 3,5 deitada (× escala).
  - Área de dano refeita a cada 0,25 s em volta dos ossos posados.
  - `tempo_submerso`: 60 s nos perfis.
- **Testes:**
  - `test_bestas_postura_foca` (novo): 68/68, com fotos em
    `art_src/validation/bestas_mar/foca/` usando `-- --tela`.
  - `test_rotina_oceano_bestas`: 32/32. O ciclo roda com mergulho de 6 s para testar
    a sequência; o fôlego é medido à parte: 32,5 s submersa, contra 30 s do jogador.
  - `test_comportamento_bestas_mar`: 64/64.
  - `test_bestas_mar`: TUDO OK.
- **Limitações:**
  - A colisão de movimento continua o núcleo vertical de antes. Deitada, o jogador
    atravessa a ponta da cauda e do pescoço; a área de dano cobre o corpo inteiro.
  - A estabilização da cabeça existe só no jogo. No Blender os clipes mostram a cabeça
    como foi animada.
