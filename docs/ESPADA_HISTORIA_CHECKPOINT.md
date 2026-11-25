# Espada no modo história — 06/10/2026

Pedido: item espada, combate por cliques semelhante ao corpo a corpo.
Decisão do usuário: item inicial no inventário para equipar; autorizou teste com tela/mouse.

## Entregue

- N → ARMAS → Equipar/Desequipar; espada na barra existente e um item ativo por vez.
- Save e migração de campanhas antigas; nova campanha recebe espada guardada.
- Mesmo executor direcional: estocada, dois cortes laterais e corte de cima,
  defesa/aparo/riposte/finta; contato da base à ponta com deduplicação e obstáculos.
- Interrupção por troca de item, sem apagar recuperação ou punições de combate.
- Pose de transporte e punho orientado após IK; arma remonta após trocar aparência.
- Modelo existente `mapas/modelos/sword.glb`, com pega na origem e lâmina +Y.

Equipar concede Espada 1: suposição de implementação para tornar o item inicial
utilizável, seguindo o precedente de comer fruta conceder Fruta 1. Números iniciais
para playtest: 26/30/30/38 de dano, preparos 0,30/0,38/0,38/0,48 s; fonte única em
`src/combat/direcional/estilos/espada.tres`. Não é uma medição de balanceamento final.

## Arquivos

`src/historia/progressao.gd`, `ModoHistoria.gd`,
`src/historia/equipamentos/espada_da_historia.gd`, `src/ui/InventarioDaHistoria.gd`,
e adaptador/pose/executor/dados em `src/combat/direcional/`.
Teste novo: `tools/dev_tests/test_espada_historia.gd`.

Snapshot do estado anterior (a árvore já tinha alterações de outras frentes) e patch:
`/home/gabriel-bitti/dev/sop-snapshots/2026-10-06-espada-historia/`.
Nenhum commit realizado. Save real e mapa do usuário não foram usados pelos testes.

## Validação

- Godot 4.6.3, headless: **30/30** verificações.
- Godot 4.6.3, X11/Vulkan Forward+, RTX 3050 Laptop: **32/32**, incluindo mouse,
  quatro direções pelo gesto+clique e tecla física da barra. Capturas inspecionadas
  da câmera de jogo/lateral, espada empunhada e inventário.
- Barra existente: **19/19**. Combate/contato/aparo da história passam na bateria geral.
- `test_compila`: seis falhas previamente documentadas em `tools/anim_editor/studio`;
  nenhum erro nos arquivos da espada. O scanner também inclui snapshots antigos
  e emite ruído de autoload; o runtime da espada não teve SCRIPT ERROR/ERROR.
- `indice.py verificar`: sem caminhos mortos; avisos de contextos antigos do projeto.
- Evidências: `art_src/validation/espada_historia_2026-10-06/`.

A captura inicial em Compatibility revelou shader de contorno incompatível com esse
renderizador; validação final refeita no Forward+ configurado pelo jogo, sem esse erro.

A execução anterior de `./validar.sh rapido` foi parcial: ao retomar, o processo e
seu log temporário já não estavam disponíveis. Até o último resultado observado,
43 testes haviam concluído; as falhas eram externas à espada (balance, Bara,
clipes de parkour, studio/compila e corte horizontal da Yoru). Não declarar a
bateria inteira aprovada. A correção abaixo tem regressão direcionada persistente.

## Correção do fio solicitada pelo usuário

O usuário confirmou: **o fio não acompanha o sentido do corte**. Corrigidas as
poses laterais (inclusive o sentido da trajetória) e o plano vertical; punhos
agora usam SLERP para atravessar ângulos sem inverter/girar artificialmente.

- Antes: 2/6 casos geométricos passaram; esquerda com dorso primeiro e vertical
  com face larga primeiro.
- Depois: 6/6; alinhamento mínimo ≥0,995 (~6°), em duas orientações do corpo.
- Integração após correção: **30/30 headless e 32/32 com tela**, sem SCRIPT ERROR/ERROR.
- Regressão direcionada concluída: **11 testes passaram**; somente `test_compila`
  reprovou, pelas seis falhas antigas de `tools/anim_editor/studio`. Log: `direcao/regressao.log`.
- Evidências persistentes em `art_src/validation/espada_historia_2026-10-06/direcao/`.
- Novos arquivos afetados: `pose_de_combate.gd`, `espada.tres`,
  `test_fio_espada_historia.gd`; teste de integração aceita `--capturas=/caminho`.



## Técnica Z — Giro cortante (06/10/2026)

Pedido: corpo e espada girando juntos até acertar inimigo, knockback no contato,
imunidade durante o giro. Escolha explícita do usuário: Z novamente cancela;
sem duração máxima. Deslocamento e câmera continuam disponíveis.

Implementação em `src/historia/equipamentos/giro_da_espada.gd`, montado pelo
componente da espada. Giro 1,6 volta/s, entrada de pose em 0,16 s, fio tangente
à trajetória e rastro curto de aço (`WeaponTrail3D` existente). Dano usa o corte
lateral da ficha (30); empurrão horizontal 10 m/s; primeiro inimigo encerra.
São valores iniciais de implementação, não balanceamento medido. Sem energia ou
recarga nova, respeitando recuperação/reação do combate antes de iniciar.

Input Z e estado no HUD da história. A imunidade tem meta própria, preservando
`damage_immune` de outros poderes. O executor direcional também recusa reação e
hitstop contra o giro. Troca de item/rig, incapacidade e saída da árvore limpam
estado. Dano só no servidor. Não afeta Yoru/arena.

`InimigoDoMapa` ignorava knockback por ser estático; agora desloca por
`move_and_collide`, desacelera e volta ao spawn original ao renascer. O contato
reutiliza `SwordSweep` e respeita paredes e grupo `enemy`.

Validação concluída:

- **42/42** na bateria final, Godot 4.6.3 X11/Forward+, RTX 3050 Laptop;
  input físico Z/W, HUD, quatro quadrantes, dano único/knockback, parede,
  aliado ignorado, imunidade de dano/reação/hitstop, cancelamento, rig e teardown.
- Primeira bateria headless **36/36**; ampliação encontrou leitura da HUD de uma
  skill removida isoladamente. Corrigida com validação de instância; cenário
  passa na execução final com tela, sem SCRIPT ERROR/ERROR.
- Fio × trajetória: mínimo **0,999**; corpo percorreu **12,57 rad** em 75 ticks.
  Giro mantido por mais de 10 s sem alvo; câmera não gira com o corpo.
- Capturas reais da câmera de jogo inspecionadas (`giro_08/23/38/53.png`).
- Regressões: espada anterior **30/30**; barra **19/19** (scanner desse teste emite o ruído conhecido de autoload `GameFlow`; não é uma execução sem erros de compilação); inimigos do mapa,
  fio da espada (**6/6**), resolução de contato e poses passaram.
- `test_compila`: mesmas **seis falhas preexistentes** em `tools/anim_editor/studio`.
  Não se declara que a compilação geral do repositório está verde.
- `indice.py verificar`: sem caminhos mortos; avisos de contextos antigos restantes.

Evidências: `art_src/validation/espada_historia_2026-10-06/giro_z/`.
`teste_antes_cleanup.log` conserva o diagnóstico da HUD; `tela.log` é a validação
final limpa. Saves isolados em `/tmp`, mapa de fixture, nenhum commit realizado.
Próximo passo: nenhum para o pedido atual; valores de dano/giro/impulso continuam
sujeitos a avaliação de balanceamento pelo dono.


## Z com duas mãos — 07/10/2026

Pedido: ambos os braços segurarem a espada durante a rotação. Concluído em
`src/historia/equipamentos/giro_da_espada.gd`. Pegada inicial adotada: direita junto
à guarda e esquerda 15 cm abaixo, com palmas em lados opostos do cabo. A pergunta
opcional de preferência não recebeu resposta durante a implementação.

A IK recebe alvos de punho calculados a partir dos encaixes autorais Weapon_R/L,
com orientação das duas mãos. Pegada aproximada da frente do corpo para ambos os
braços alcançarem sem alongar ossos. Transição de entrada de 0,16 s preservada.
A varredura acompanha a posição real da lâmina nessa nova pose; não foi criada
hitbox artificial para compensar o deslocamento da pegada. Velocidade, dano,
knockback, imunidade, condições de término e cancelamento mantidos.

Validação em Godot 4.6.3, saves/mapa de teste isolados:
- `tools/dev_tests/test_pegada_giro_espada.gd`: antes 5/7 (mão esquerda distante
  ~1 m do ponto esperado); depois **7/7 headless e 7/7 com tela**. Em 90 amostras
  durante as voltas, desvio máximo da esquerda ~1,3 cm, dentro da tolerância de
  2 cm da pega, direita alinhada ao encaixe. Capturas antes/depois inspecionadas.
- `tools/dev_tests/test_giro_espada_historia.gd`: **42/42 com tela**; quatro
  quadrantes, fio × trajetória, dano/knockback, paredes, imunidade, Z/W, troca de
  rig/equipamento e encerramento. Novo argumento opcional --capturas para manter
  as evidências anteriores. Log final sem erros/avisos.
- Espada inicial **30/30**, direção do fio **6/6**, sem erros/avisos.
- `test_compila`: permanecem as seis falhas anteriores do studio; scanner também
  emite ruído de autoloads/recursos. Não é compilação geral limpa.

Evidências: `art_src/validation/espada_historia_2026-10-07/duas_maos/`.
Snapshot anterior: pasta irmã sop-snapshots/2026-10-07-giro-duas-maos.
Fonte editável da pose é o próprio componente; não houve mudança no GLB da espada
nem no rig. Validação visual usa o personagem base atual; não mede rigs externos.
Nenhuma etapa pendente para este pedido; sem commits.
