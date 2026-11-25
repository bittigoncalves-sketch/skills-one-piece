# Execução — Bara Bara do jogador (retomada após o Codex)

Checkpoint da orquestração. Plano de origem: `docs/PLANO_BARA_BARA.md`, que
**ainda descreve o C antigo**: em 13/09 21:10 o dono trocou o C por um canhão
explosivo (Buggy Ball) e mandou apagar a Bara antiga.

## Onde o Codex parou (14/09/2026)

- Caiu às **10:51** por **limite de uso**, no meio da tarefa ("continuar", 10:45).
  O agente principal e os 3 subagentes dele (assets, binding, apresentação)
  morreram juntos.
- Últimas ações:
  - 10:50:55 ligou o `BaraHud` em `Main.gd:90-94`;
  - 10:51:02 corrigiu um `get_meta` no `BaraHud.gd`;
  - 10:51:33 criou `tools/dev_tests/test_bara_network.gd`.
  - Nada disso foi executado.
- Deixou o projeto **sem compilar**: `src/anim/BaraPoses.gd` com `segment`
  redeclarado e `var side` recuado depois de `continue`. Como o
  `ProceduralAnimator` o carrega, o Player não compilava. **Corrigido pelo
  orquestrador em 14/09**, conferido com `--check-only` nos 5 scripts da Bara.
- Dois Blender do Codex ficaram rodando (`bara_bara_assets.py` e
  `render_bara_gallery.py`). **Encerrados com ok do dono.** Os arquivos deles já
  tinham sido gravados às 10:46 e 10:50.

Mapa completo requisito → status: relatório do agente de busca, resumido abaixo.

## O que falta (do mapeamento)

- **Combate** (`BaraController`, Bara no `Balance`):
  - hitstun do Z 0,12 e do X 0,18, raio do X 0,28 (código: 0,10 / 0,10 / 0,24);
  - contato do V nos tempos do plano, sem relançar mão que está voltando;
  - contrato do C (medir o que existe e o dono aprova);
  - M1 bloqueado com as mãos fora.
- **Rede:**
  - `test_bara_network` nunca rodou;
  - entrada tardia, dois jogadores Bara, desconexão, coleta/respawn da fruta;
  - sonda antiga `net_sweep_host_probe.gd:58-59`.
- **Apresentação:**
  - aviso vermelho em Z, X e V (hoje só no C);
  - volume comparado com a Ope;
  - HUD e ícones em 32/48 px;
  - poses na câmera normal;
  - capturas (`./jogar_bara.sh -- --capture`) e performance.
- **Fechamento:**
  - `tools/validate_bara.py` (não existe);
  - documentação (plano com o C novo, `docs/frutas/bara_bara.md`);
  - regressão final.

## Decisões do dono (14/09)

- Agentes com prompt fechado, em ondas.
- Encerrar os Blender órfãos.
- Orquestrador corrige o bloqueio de sintaxe antes da onda 1.
- C: validar o que existe e propor contrato para aprovação antes de mudar.

## Ondas

| Onda | Agente | Território | Status |
|---|---|---|---|
| 1 | `bara-validador` (leitura) | `art_src/validation/bara_bara/onda1/` | **concluída**: compila; hand_binding 30/0; combate 29/30; rede 0 (teste não compila); assets 90/0; bateria 82/9/1 (as 2 novas são da Bara) |
| 2 | `bara-combate` | `BaraController.gd`, Bara no `Balance.gd`, portão M1 em `melee_controller.gd`, `test_bara_combat.gd` | em execução (cast duplo, M1, hitstun/raio, contato e relançamento do V, direção do empurrão, cenário do teste do C) |
| 2 | `bara-rede` | `BaraNetwork.gd`, blocos Bara de rede do `Player.gd`, `test_bara_network.*`, `net_sweep_host_probe.gd` | em execução |
| 2b | `bara-apresentacao` | `BaraPoses`, `BaraVfx`, `BaraAudio`, `BaraHud`, chamadas de aviso no `BaraController`, capturas | aguardando o bara-combate (mesmo arquivo) |
| 3 | `bara-fechamento` | `tools/validate_bara.py`, docs, regressão | aguardando onda 2 |

Portas: validador 26000/26010; combate 26020; rede 26030/26040; apresentação 26050;
fechamento 26060.

## C (canhão) — contrato APROVADO pelo dono em 14/09 (números medidos na onda 1)

- Preparação até o disparo: 0,65 s. Voo até explodir: ~0,58 s. Total da ação: 2,3 s. Recarga: 10 s. Energia: 180.
- Dano: 240. Raio da explosão: 3,5 m. Empurrão: 9 m/s na horizontal e 3,15 m/s na vertical.
- Alcance com mira horizontal em chão plano: 16,6 m. Teto do voo: 25,1 m (mira acima explode no ar). Mira baixa: bate no chão.
- Autodano: nenhum. Testado com a explosão a 1,29 m, 1,85 m e 2,29 m do jogador.

O `bara-fechamento` fixa esses números em teste e atualiza o `PLANO_BARA_BARA.md` e o `docs/frutas/bara_bara.md`.
