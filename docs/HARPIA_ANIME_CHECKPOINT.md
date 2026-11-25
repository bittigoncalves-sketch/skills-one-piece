# Harpia — acabamento anime (05/10/2026)

Implementação concluída sobre os controladores que já existiam. Decisão atual do usuário: manter investida e vendaval do modo história, aprimorando animação e VFX. Não foram alterados dano, recargas, deslocamento, volumes físicos, regras de captura, arremesso ou os cinco segundos do tornado.

## Alterações

- `src/historia/bosses/harpia/pose_harpia.gd`: fechamento das asas em cadeia (úmero, cotovelo e rémiges), contrapeso de pescoço/cauda, recuperação a partir da pose efetiva e continuidade nas interrupções. Batida do vendaval termina no tick de lançamento; os 0,7 s seguintes são continuidade e assentamento.
- `src/historia/bosses/harpia/vento_harpia.gd`: faixas de vento com tons definidos e margem escura, linhas longitudinais na investida, arcos abertos no chão indicando o raio do tornado e formação/dissipação controladas pelo relógio existente. Núcleo aberto permite enxergar os capturados. Áudio procedural existente preservado, com intensidade crescente na preparação.
- `src/historia/bosses/harpia/pulso_de_ar.gd`: crescentes transitórios no disparo e acento radial no contato, sem hitbox/dano. Posição fixa no mundo, duração limitada e remoção automática.
- `src/historia/bosses/harpia/combate_harpia.gd`: apenas integração de apresentação. Impacto visual depende de diminuição real da vida; imunidade não gera falso contato. Cancelamento remove os acentos e interrompe o vento.
- `tools/dev_tests/test_harpia_apresentacao.gd`: amostras do esqueleto real, continuidade nas transições e limpeza dos efeitos.
- `tools/dev_tests/capturar_harpia_poses.gd`: aceita diretório de saída por `HARPIA_CAPTURAS`.
- `tools/dev_tests/capturar_harpia_historia.gd`: captura os controladores na história com progresso temporário, câmera normal e câmera de inspeção. `HARPIA_ENSAIO=1` usa o terreno plano de teste; sem variável usa o mapa real. A simulação pausa somente durante a gravação de cada PNG.

## Evidências

`art_src/validation/harpia_anime_2026-10-05/`:

- `before/`: backup dos scripts originais e 21 capturas anteriores em câmera/luz fixas.
- `after/`: mesmas vistas isoladas após alteração.
- `historia/`: encontro no mapa real, com cenário e iluminação de produção.
- `ensaio/`: encontro no modo história em terreno plano, incluindo jogador visível dentro do tornado.
- `logs/`: resultados integrais da validação.

Godot 4.6.3, Forward+, NVIDIA RTX 3050 6 GB na captura. A bateria selecionada `./validar.sh harpia arena` passou em **4 testes, zero falhas**: arena, apresentação, investida e vendaval. Após o ajuste final de sincronia, apresentação foi repetida e passou novamente. Os testes de gameplay cobrem dano único, imunidade, esquiva, paredes, morte, respawn, captura e liberação. O teste novo amostrou **305 poses**, todas com ossos finitos e normalizados, mediu amplitude máxima de fechamento de **155°**, verificou continuidade nos encontros de fase e repetiu **36 configurações de VFX** sem nós residuais.

A compilação geral encontrou **seis falhas em `tools/anim_editor/studio/`** (rig_scene, main, timeline, test_selection, test_studio, view), fora dos arquivos alterados. Nenhum erro de compilação da Harpia. Captura isolada apresentou o mesmo aviso ObjectDB ao encerrar já presente no baseline; o teste de repetição dos VFX não deixou nós residuais. Não houve medição comparável de FPS, nem certificação da suíte inteira.

## Preservação e estado

A árvore já continha muitas alterações sem commit; foram preservadas. HEAD permaneceu `1e54b52`, sem commit ou push. Dois agentes iniciaram investigação seguindo `docs/AGENTES.md` e foram interrompidos por limite de uso; o agente principal revisou, completou e validou a animação deixada e implementou os demais arquivos. Sem dependências ou assets externos novos. Fonte editável nos próprios scripts.

Próximo passo opcional: playtest do encontro pelo usuário para ajuste artístico. Não há implementação pendente nesta entrega.

## 10/10/2026 — voo entre as pedras, ronda dos picos, reação e tornado mais rápido
Pedido do dono (ver `docs/PEDIDO_2026-10-10_HISTORIA.md`, frente 7): território 150 × 130 m;
`voo_harpia.gd` (desvio pela superfície, folga do chão, inclinação na curva); ronda os
picos; levou golpe → alça voo e investe; depois da investida arremete em vez de parar 1 s;
tornado 14 m/s. Correção junto: pouso de corpo solto encostado em outro
(`captura_vento.gd`, docs/erros.md 10/10). Teste novo: `test_harpia_voo` (mapa vivo).
