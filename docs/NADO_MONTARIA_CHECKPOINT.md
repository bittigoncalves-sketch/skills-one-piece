# Nado e montarias — 02/10/2026

Pedido vigente: redesenvolver nado do protagonista da história; Y monta/desmonta pet classificado como montaria no editor. Confirmado pelo usuário: crawl na superfície e Y novamente para desmontar. Cavalo e caranguejo inicialmente montáveis.

Sea Serpent passou ao Claude; não editar seus modelos/gerador. A última exportação da revisão anterior já havia terminado ao receber a mudança de escopo.

## Implementação

- `src/anim/nado_poses.gd`: ciclo editável com entrada, puxada, cotovelo elevado na recuperação, braços alternados, seis pernadas por ciclo, extensão dos pés e boiar parado. `ProceduralAnimator.gd` aplica no rig real e suaviza as transições.
- `src/historia/agua/jogador_na_agua.gd`: flutuação do crawl em 40% da cápsula submersa; histerese sem apoio no fundo evita entrar/sair do nado a cada quadro. Mantidos mergulho, fôlego e regras da fruta.
- `src/historia/pets/montaria.gd`: controlador exclusivo da física do pet durante a condução; suspende IA, monta o cavaleiro pelo quadril, conserva colisão acima da sela, bloqueia montagem por distância/parede/teto, busca saída livre e restaura estado ao desmontar, guardar, morrer ou sofrer incapacitação. `die_and_respawn` e `net_force_respawn` desfazem o vínculo antes de reposicionar o jogador.
- `src/historia/pets/ficha_montaria.gd`: classificação pelo catálogo, medidas de assento e correção de frente dos GLBs de cavalo. `companhia.gd`: transforma pets classificados colocados no mapa em corpos controláveis, preservando escala XYZ no visual e reconstruindo a cápsula com corpo unitário, e impede chamar uma montaria já ocupada.
- `src/anim/montaria_poses.gd`: sentado a cavalo ou com pernas dobradas sobre a carapaça.
- `Player.gd`, `ModoHistoria.gd`, `HistoriaHud.gd`: integração e dica de Y; doma com fruta continua quando não há montaria próxima.
- `mapas/modelos/catalogo.json`, `src/editor_mapa/loja.gd`, `tools/configurar_montarias.py`: categoria **Montarias**, aplicada a caranguejo_grande, horse, cavalo_da_vila_leve e animals__farm__horse_1__base; tooltip com controle. Edição: botão direito na loja → Categorias → Montarias (pet também deve pertencer a Pets).

Controles: WASD conduz; Shift corre; Espaço salta; Y monta/desmonta. Menus bloqueiam condução e Y. Disponível na campanha offline. O botão Testar do editor continua sendo seu teste de locomoção existente, sem simulação da companhia/HUD da campanha.

## Evidências

- `tools/dev_tests/test_nado_montaria.gd`: fixture e progresso isolados. Primeira execução ampliada: zero falhas em montagem, movimento, corrida, salto, menus, recolhimento, morte, congelamento, distância, paredes, teto, desmontagem sem espaço, persistência da categoria e pets escalados do editor. Rig real confirmou cabeça à frente do quadril, alternância do estado estável e transições para boiar/terra. Última execução após corrigir escala XYZ e puxada: zero falhas (integracao.log). Braçada 0,598 m; cotovelos recuperam ~0,295 m acima da superfície; flutuação varia 0,006 m em 3 s.
- `tools/nado_montaria_preview.gd`: captura GPU Forward+, jogador real sem capturar mouse (mouse=0), cavalos e caranguejo. `--video` grava 60 quadros a passo fixo 30 Hz para o ciclo. Imagens e `crawl.mp4` em `art_src/validation/nado_montaria/`.
- Revisão visual independente identificou e motivou correções: cavalo orientado ao contrário, pernas dentro da carapaça, oclusão excessiva do nadador e pés dobrados. Corrigidos; a revisão final reconheceu recuperação aérea e alternância das pernas, com recuperação parcialmente encoberta pela cabeça neste enquadramento. A revisão de código também confirmou as correções de escala XYZ e desligamento no renascimento.
- `./validar.sh rapido` terminou: 109 passaram, 10 falharam e 5 foram pulados. O teste novo foi corrigido e reexecutado isoladamente com zero falhas; restam nove falhas externas já registradas (balance, bara_combat, compila, corte_horizontal, ilha_inicial, mera_z_saque, ope_animacoes, studio_playback, trava_fruta_dano). Executado com XDG isolado e DISPLAY/WAYLAND_DISPLAY vazios, sem alterar campanha nem capturar mouse. Log: `art_src/validation/nado_montaria/regressao.log`. Água e animais já passaram. Há falhas de Balance/Bara previamente registradas na lista de correções; não corrigir fora do escopo.

## Próximo passo

Usuário mudou explicitamente para barcos em 03/10. Nado/montaria implementados e teste próprio passa; desenvolvimento vigente em BARCOS_CHECKPOINT.md. A última ampliação da puxada está no código; o vídeo anterior não inclui essa última chave. Não sobrescrever alterações concorrentes do Claude ou outras alterações já presentes no repositório.
