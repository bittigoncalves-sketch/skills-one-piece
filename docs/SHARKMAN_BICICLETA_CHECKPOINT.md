# Sharkman, manobras Hie e iluminação — 13/10/2026

Objetivo: bicicleta com pulo/pulo duplo 360°, manobras; Sharkman com respiração
infinita, nado normal igual à corrida e rápido 2× consumindo energia; luz no mergulho.

Implementado: bicicleta (Espaço, Ctrl para empinar, inclinação nas curvas),
raça em M → status e persistência, integração do nado na locomoção, luz local de 32 m.
Escolha pendente do usuário: Sharkman nada com fruta ativa ou continua afundando?
Enquanto pendente, regra antiga de fruta ainda presente.

Arquivos: `bicicleta_de_gelo.gd`, `jogador_na_agua.gd`, `luz_de_mergulho.gd`,
`ModoHistoria.gd`, `progressao.gd`, `Player.gd`, `JanelaDeStatus.gd`, `AguaHud.gd`.

Validação final: teste próprio aprovado na suíte headless e **39/39 com tela**. Medido nado normal
6,3 m/s = corrida, rápido 12,6 m/s; inclui exaustão, 40 s sem respirar, controle
humano que sofre dano, terceiro salto recusado, 360° e pouso no mar. Capturas em
`art_src/validation/sharkman_manobras/` (mesma cena com/sem luz, fundo real).
Compilação geral: seis falhas já documentadas de `tools/anim_editor/studio/`.
Regressões: bicicleta original, locomoção no chão, modo história, nado à frente,
nado/montarias, progressão e novo teste aprovados (7 suítes). `test_agua` mantém
a falha já registrada de saída pela praia (x=272,3 ainda nadando). Bateria ampla
foi interrompida após também encontrar testes que exigem dummies ausentes na arena.

Traço: referência antiga divergiu em 462 dos 492 quadros. Comparação em cópia
isolada, restaurando somente a fórmula de velocidade anterior a esta tarefa:
**492/492 quadros idênticos ao código final**. Referência antiga não foi sobrescrita.
Todos os logs e ambos os traços estão em `art_src/validation/sharkman_manobras/`.
Na região fixa do fundo (x=380..900, y=390..540), luminância média 136,93 sem luz
e 144,78 com luz (+5,73%), na cena diurna usada pelas capturas. Sem medição de FPS.

Raça anteriormente era gravada, mas ignorada em `de_dict`; leitura agora aceita
humano/sharkman. `visual_sharkman.gd` adapta barbatanas ao rig atual em metros,
pois o catálogo antigo mede toda a hierarquia do torso e produzia peças gigantes.
O componente de água recebe `Node`, evitando carregar Player antes dos autoloads
em testes que consultam `JogadorNaAgua` diretamente. Parse do teste de água passou.

Materiais originais restaurados ao retornar a humano; dorsal medida em
0,07 × 0,48 × 0,38 m. Teste próprio usa apenas mapa e progresso isolados.
Implementação e validações concluídas para as regras atuais. Permanece a escolha
apresentada ao usuário sobre permitir nado mesmo com Akuma ativa; até resposta,
afunda com a fruta ativa e mantém respiração infinita. Sem commit.
