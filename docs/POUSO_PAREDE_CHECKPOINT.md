# Pouso após andar na parede — 01/10/2026

- Objetivo: impedir flutuação persistente dos pés ao voltar ao chão no Modo História.
- Causa reproduzida: `PlayerArremesso.apresentar()` inativo restaurava qualquer inclinação X e escrevia `_rest_y=0`, mesmo sem arremesso anterior; o rig estava em Y=-0,809861.
- Correção: posse explícita da pose, do `iniciar()` até concluir a restauração ou cancelar. Arquivo: `src/player/player_arremesso.gd`.
- Regressão: `tools/dev_tests/test_pouso_parede.gd`, contrato da pose e três ciclos de subir/sair/pousar via teclas no Modo História, Godot 4.6.3 headless. Passou; raiz voltou a -0,809861 em todos.
- Validação: 28 verificações do novo teste e 34 do arremesso real pelo chefe passaram. Controle negativo com os métodos antigos: 11 falhas, raiz em Y=0 após cada pouso. Capturas antes/depois conferidas em Weston virtual isolado. Traço de 492 quadros idêntico antes/depois (headless, com os bonecos de ataque desativados para não contaminar o movimento). Evidências em `art_src/validation/pouso_parede/`.
- Bateria `validar.sh rapido` ainda em andamento; compilação encontrou as seis falhas já documentadas do editor de animações em `tools/anim_editor/studio/`. Logs em `/tmp/sop-pouso/`.
- Mudanças anteriores do projeto preservadas; não editar Player.gd nem o controlador de parkour para este conserto.
- Causa e correção registradas em `docs/erros.md`. Próximo passo: aguardar término da bateria geral, registrar resultado e encerrar a tela virtual.
