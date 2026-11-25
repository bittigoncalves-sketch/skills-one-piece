# Pouso após parede — 01/10/2026

Godot 4.6.3. Modo História real com mapa fixo `fixtures/mapa_baseplate.json`,
parede estática e entrada por `Input.parse_input_event`. Dados de usuário
isolados em `/tmp/sop-pouso/`, sem usar o progresso salvo do jogador.

| Medida | Métodos antigos | Correção |
| --- | --- | --- |
| Raiz visual após pousar (três ciclos) | Y=0 | Y=-0,809861 |
| Pé mais baixo contra piso | +0,797 a +0,810 m | -0,013 a +0,0003 m |
| Teste de regressão (28 verificações) | 11 falhas | 0 falhas |
| Arremesso pelo chefe (34 verificações) | Não repetido como controle | 0 falhas |

O controle negativo reexecuta os métodos antigos `iniciar`, `apresentar` e
`cancelar` em uma subclasse temporária, sem desfazer alterações no projeto.

Capturas comparáveis: [antes](antes_pouso.png) e [depois](depois_pouso.png).
Renderizadas em Weston virtual isolado, via OpenGL Compatibility. Esse renderizador
emite avisos sobre efeitos que exigem Forward+; as capturas validam posição e
contato dos pés, não a aparência final desses efeitos.

Traço de locomoção: 492 quadros idênticos antes/depois. A sonda temporária usa o
roteiro de `tracar_locomocao.gd` em headless, sem exigir captura do mouse (o
`MoveFrame` atual aceita essa entrada no Linux), e desliga os bonecos que atacam
para impedir knockback variável durante a medição. Não é comparação contra a
referência histórica do repositório. Os arquivos `traco-antes.txt` e
`traco-depois.txt` contêm a comparação completa.

Logs específicos: `test_pouso.log`, `controle_antigo.log`, `arremesso-boss.log`.
A compilação geral registra seis falhas já conhecidas em
`tools/anim_editor/studio/`; ver `validar_test_compila.log`.
