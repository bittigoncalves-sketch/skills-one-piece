# Pão, água e animações de alimentação — 30/10/2026

Objetivo: pão rústico e garrafinha em estilo anime, na mão do jogador real do Modo História, com ações distintas de morder e beber. Direção visual confirmada pelo usuário.

## Implementação

- Fonte autoral: `art_src/alimentacao/gerar_assets.py` e `alimentacao.blend`. Blender 5.2; GLBs em `assets/models/alimentacao/`. Metros, +Y para cima no Godot, pivô na pega, sem colisão para itens cosméticos. Nenhum asset externo.
- Clipes por papel do rig, sem root motion: `assets/animations/alimentacao/{comer,beber}.tres`, gerados por `art_src/alimentacao/gerar_animacoes.py`. Durações 1,9 / 2,2 segundos.
- `alimentacao_visual.gd`: componente no jogador de História; item equipado, relógio, montagem no socket, limpeza na morte/troca de slot e remontagem após trocar o rig. Mantém a última unidade visível até terminar o gesto.
- `alimentacao_poses.gd`: sobreposição dos braços/cabeça, preservando as pernas; máscara no clipe de corrida. Ações prioritárias (dano/roll/golpe) cancelam a alimentação visual.
- `HistoriaHud.gd`: inicia a apresentação apenas depois do consumo bem-sucedido. Preserva consumo imediato por clique, nutrição, estoque e controles existentes, inclusive consumo quando saciado. Cliques sucessivos reiniciam o gesto; não alteram a regra de consumo.
- `ModoHistoria.gd`: montagem do componente e atualização do equipamento pela progressão. RPCs cosméticos só aceitam o servidor; não alteram inventário remoto. O consumo permanece solo/servidor, como antes.

## Validação concluída

Godot 4.6.3, Blender 5.2. Save isolado em `/tmp/sop-alimentacao-data`; mapa fixture. Capturas com Forward+ / Vulkan na NVIDIA RTX 3050 Laptop. Não houve alteração do save pessoal.

- `test_alimentacao.gd`: **19/19**, em headless e Forward+. Entrada pelo HUD, estoque, release, item vazio, última unidade, morte/retorno, remontagem do rig, nutrição, prioridade do dano e máscara do braço durante corrida. Contato medido no personagem base: pão a menos de 12 cm do ponto de boca; gargalo a menos de 8 cm (captura final ~2,3 cm).
- `test_status_recrutamento.gd`: **31/31**; `test_sobrevivencia_integracao.gd`: **16/16**; `test_player_rig.gd`: **25/25**. Total: **91 checks focados**, sem SCRIPT ERROR.
- `python3 tools/dev_tests/test_alimentacao_rede.py`: dois processos ENet na porta exclusiva 29874. Cliente recebeu item/ação do servidor; pedidos falsificados do cliente foram rejeitados. O teste espera a montagem de ambos os jogadores antes do envio.
- Capturas em `art_src/validation/alimentacao/`: `00_assets.png`, `01_pao_equipado.png`, `02_mordida.png`, `03_gole.png`, `03a_agua_equipada.png`, `04_comer_camera_jogo.png`.
- Fonte Python verificada com `py_compile`; arquivos de animação/GLB importados. Pão: 16.000 triângulos, uma superfície com cor por vértice (sem textura/UV necessária). Garrafa: 2.314 triângulos, cinco superfícies. Sem colisores, pois são props cosméticos presos à mão. Não se afirma ganho de desempenho.

## Limites e observações

A bateria global não foi executada. Capturas e contato foram avaliados no personagem base; outros corpos personalizados e primeira pessoa não receberam avaliação visual específica. A apresentação remota foi testada com peers conectados antes da ação; não há snapshot próprio de equipamento para entrada tardia. O consumo continua restrito ao solo/servidor, como o fluxo anterior.

O log visual contém dois erros de `add_child` originados em `src/ui/tela_de_carregamento.gd:87/89` e avisos de recursos/RIDs no encerramento. As suítes de sobrevivência/status também registram avisos no encerramento. Esses arquivos não foram alterados nesta tarefa; os 91 checks passam, mas isso não equivale a um log global sem erros.

A animação mantém o consumo instantâneo já existente: o gesto é apresentação posterior. Refeições usam o mesmo pão representativo do slot comida. A geometria do pão não perde pedaços e o nível de líquido não varia durante a ação.

## Reprodução

Na raiz do projeto:

```sh
blender --background --python art_src/alimentacao/gerar_assets.py
python3 art_src/alimentacao/gerar_animacoes.py
```

Importar o projeto no Godot após regerar GLBs. Para o teste de campanha, usar o binário encontrado por `find_godot.sh`, `--fixed-fps 60 --script tools/dev_tests/test_alimentacao.gd`; acrescentar `-- --capturar` com display/renderizador disponível. Usar XDG temporário para proteger dados pessoais. Fonte Blender abre com ambas as peças visíveis; o afastamento na cena de edição não altera o pivô dos GLBs exportados.

## Comer leva tempo + regeneração acelerada (20/11/2026, pedido do dono)
- **Comer é uma AÇÃO** (`Provisoes.tempo_de_comer`): 1,5 s + fome/40, limitado a 2–4,5 s (pão ≈ 2,1 s, carne assada 4 s). Clique na barra de comida: reserva UMA unidade (`reservar`), toca o clipe esticado
  (`AlimentacaoVisual.comer`) e só no FIM aplica a fome (`aplicar_refeicao`). Interrompida (dano, rolagem, morte) → o item VOLTA (`devolver`) e nada entra. Clicar comendo não gasta outra unidade.
  Água/bebida continua instantânea no clique (`beber_da_barra`); `comer_da_barra` (instantâneo) ficou para compatibilidade.
- **Regeneração acelerada** (`HealthController.premiar_comida`): vida e energia ×3 por `10 s + 0,3 s × fome do item` (pão 17,5 s, carne assada 40 s). Comer de novo renova pelo maior; NÃO empilha com o bônus de kill (×4): vale o maior. Água e leite não dão.
- Números em constantes de `provisoes.gd` (`TEMPO_DE_COMER_*`, `REGEN_DA_COMIDA_*`) — ajustar ali.
- **Testes:** `test_comer_devagar.gd` 14/0 (tempo, reserva, fome só no fim, clique duplo, regen ×3, kill não empilha, interrupção devolve, sem comida); `test_alimentacao.gd` 19/19 (a espera passou de 2 s para ~3,3 s).
- **Não validado:** captura visual do clipe esticado (aparência da mordida mais lenta); `test_alimentacao_rede` (2 processos — o RPC `_net_consumo` ganhou o parâmetro `duracao`); `test_regeneracao_da_historia` não compila fora do jogo ("Identifier not found: GameFlow", não citado por mim; não verifiquei se é anterior).
