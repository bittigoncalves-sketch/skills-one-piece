# Agachar no Ctrl — 20/10/2026

Objetivo: substituir deslize no Ctrl por agachar inspirado no Minecraft Java.
Padrão adotado: segurar Ctrl; pergunta de preferência enviada, sem resposta até aqui.

Implementado: entrada mantida, redução 1,5/1,8 da colisão com pés preservados,
30% da caminhada, consulta volumétrica para levantar, limite de borda antes
do empurrão, câmera rebaixada, pose própria e estado replicado. Ctrl mantém
descer na água e soltar parede. Q cancela o agachar se há altura livre.

Arquivos: Player.gd, Main.gd, src/player/{agachar,move_frame,parkour_controller,
camera_rig}.gd, src/anim/{pose_agachar,ProceduralAnimator}.gd, src/ui/ToqueHud.gd.

Baseline: test_compila tem 6 falhas em tools/anim_editor/studio; log em
/tmp/agachar-compila-antes.log. Repositório já contém muitas alterações de outras
frentes; não reverter nem commitar.

Validação:

- `test_agachar`: 34/34, com teclas reais, bordas X/Z/diagonal, teto baixo,
  degrau de 0,3 m, Q, pulo, empurrão, câmera, hurtbox, cápsula/caixa, réplica
  no mesmo processo, gigante, respawn e menu. Sola visual: erro medido <0,01 m.
- Regressão pelo `validar.sh`: 10 testes passaram (agachar, câmera, corrida
  na parede, escalada, morte, limpeza de cast ao morrer, rig, Q, roll e caminhada).
- `test_agua` falhou inicialmente em “submerso: sem técnicas de fruta”.
  Repetição com `--fixed-fps 60`: passou tanto com agachar ligado quanto com
  o componente desativado. Sensibilidade ao tempo/estado do teste ainda não
  investigada; não declarar a bateria inteira limpa.
- `test_ataques_agua_bestas`: 39/40, falha na alternância da IA bovina, reproduzida
  com agachar desativado (0 alternâncias). Fora do escopo desta mudança.
- `test_compila`: as mesmas 6 falhas do editor de animações, antes/depois.
- Capturas reais em Godot 4.6.3 Forward+: `art_src/previews/agachar_antes.png`,
  `agachar_depois.png`, `agachar_andando.png`. Reproduzir com
  `tools/dev_tests/preview_agachar.gd` (jogador remoto; não captura mouse).

Limites: pose adaptada ao rig humano e à cápsula existente; transporte entre
dois computadores e combinações com todas as técnicas de fruta não testados.
Sem alteração na distância do pulo, no tamanho horizontal ou nas permissões.

Rodada final: agachar 34/34, caminhada aprovada, parkour remoto 10/10.
Compilação com as mesmas seis falhas em `tools/anim_editor/studio/`.
Evidências preservadas em `art_src/validation/agachar/` (logs de integração,
regressão e compilação antes/depois). Trabalho concluído, sem commit.
