# Desafio do Buggy — plano (21/11/2026)

**Divisão:** Codex = arte, imagens, storyboard, falas, planejamento (`art_src/references/desafio_buggy/`, `data/dialogos/`). Claude = código e organização. Estilo: cinematográfico (tarjas letterbox + legendas, ver `DIALOGO_CINEMATOGRAFICO_CHECKPOINT.md`).

## Pedido do dono (texto fiel)
1. Moradores/NPCs restantes em estilo Minecraft, **tão grandes quanto o jogador** (instrutor já é 1,13×, exceção pedida antes).
2. Após concluir a 1ª missão de treino: **corte para cutscene** do Buggy chegando ao **cais** com a tripulação.
3. Depois da cutscene: a **bússola de missão** aponta para o cais; os NPCs da vila **correm até lá**.
4. Jogador chega → Buggy o desafia no **jogo dos 3 copos** (esconde a pedra num copo, embaralha). **Acertou** = sucesso da missão + **4000 XP**.
5. **Errou** = Buggy manda atingir o **nível 7** e voltar para **lutar**; se vencer, **poupa a vila**.
6. Esclarecido pelo dono: **uma tentativa**; a missão da luta **não fica disponível** enquanto o jogador não chegar ao nível 7, e **só existe se ele aceitar proteger a vila**.
7. Escopo fechado: **luta N7 fica para a próxima fatia** (só missão + diálogo agora; reaproveita `BossEncounter`).

## Fatias (cada uma jogável/validável sozinha)
| # | Entrega | Validação |
|---|---|---|
| A | Moradores em corpo quadrado, tamanho do jogador (ficha `"corpo"`, tinta por `capa`/`calca`) | teste estrutural + prints |
| B | Estado no progresso (`desafio_buggy`: não_iniciado→chegou→copos_feitos→aceitou/recusou→n7), persistido e idempotente | teste de save/load, sem pagar duas vezes |
| C | `CenaCinematografica` (câmera por planos, tarjas, pular com ESC, congela jogador/HUD, restaura tudo) | teste sem tela + print por plano |
| D | Cena da chegada: navio atraca no cais, Buggy + tripulação desembarcam e se alinham | prints dos planos; cena termina sempre (ESC pula) |
| E | Gatilho: entrega da missão `treino` → cena (uma vez) | teste de gatilho + persistência |
| F | Bússola/marcador apontando posição do cais | teste de direção + print do HUD |
| G | Moradores correm até o cais e formam plateia | teste: todos chegam; nenhum atravessa água |
| H | Jogo dos copos: 3 copos, pedra, embaralho, escolha por mira+E/clique, resultado | teste da lógica (semente fixa) + prints |
| I | Resultado: acerto = missão entregue + 4000 XP (uma vez); erro = diálogo N7 + oferta "proteger a vila" → missão `desafio_buggy_luta` bloqueada até nível 7 | testes de estado e do bloqueio |
| J | Luta N7 (`BossEncounter` no cais, vitória poupa a vila) | **fora desta rodada** |

## Contratos com o Codex
Pasta `art_src/references/desafio_buggy/`: `PLANO.md` (storyboard em planos numerados: enquadramento, duração s, o que se vê/ouve, legenda), PNGs de referência por plano, ficha da tripulação (Buggy, Cabaji, Richie + 2–4 piratas) em corpo quadrado, copos/pedra, e a aparência dos moradores (cores/cabelo) para a fatia A.
Falas: `data/dialogos/buggy.json` com estados `chegada`, `desafio`, `regras`, `acerto`, `erro_n7`, `aceitou`, `recusou`; linhas ≤ 90 caracteres.

## Decisões
- Cutscene = **câmera própria + atores de cena** sobre o mundo real (não troca de cena): mantém save, rede e mapa; o jogador é congelado e restaurado. Alternativa rejeitada: cena separada (perde o contexto do mapa e duplica carga). **Gatilho de revisão:** se houver >3 cutscenes ou cenas com lógica de jogo, extrair `RoteiroDeCena` em recurso de dados.
- Plateia de NPCs por **movimento direto + encaixe no chão** (sem navmesh): a vila é pequena e plana. Gatilho: NPC preso em obstáculo no teste → usar `NavigationAgent3D`.
- Copos: lógica pura (`JogoDosCopos`, semente injetável) separada do visual → testável sem tela.
- Modo multiplayer: a cena e o jogo são **locais ao jogador que concluiu o treino**; o estado vive no progresso dele. Gatilho: coop real → mover o estado para o host.

## Estado (21/11/2026)
- [x] Decisões do dono. **Mudança do dono durante a execução:** o jogo dos copos é na **PRAIA, numa MESA** (não no píer): o Buggy e a tripulação caminham do deck até a praia depois da cena; a plateia forma um anel em volta da mesa.
- [x] A moradores quadrados, tamanho do jogador (`VisualDeMorador`; Barba Negra e `rig` próprio ficam de fora) — `test_moradores_quadrados`.
- [x] B regras/estado/persistência (`RegrasDoDesafioBuggy`, missões `desafio_dos_copos` 4000 XP e `defender_a_vila` nível 7 mínimo) — `test_regras_buggy`.
- [x] C `CenaCinematografica` (câmera por planos, tarjas, ESC pula, esconde todas as HUDs) · D cena em 4 planos do storyboard do Codex (~17,5 s) · E gatilho (treino entregue) · F bússola de missão · G moradores correm (7 m/s) · H copos (`JogoDosCopos`, mesa) · I resultado/oferta (janela com botões Aceitar/Recusar; falas `aceitou`/`recusou`).
- Testes: `test_desafio_buggy_no_mapa` (fluxo completo no mapa real), `test_jogo_dos_copos`, `test_regras_buggy`. Prints: `art_src/validation/desafio_buggy/` (cena 1–4, praia, copos).
- [ ] J **Luta N7** (próxima fatia): `BossEncounter` no cais; vitória poupa a vila; a missão `defender_a_vila` já existe e abre no nível 7.

### Rodada 2 (21/11/2026, feedback do dono após testar)
- **Trégua de combate:** do início da cena até o fim da missão dos copos/oferta, o jogador não ataca (`capacidades`) e as criaturas num raio de 140 m ficam latentes (`Povoamento.latente`); tudo volta ao fim. (Motivo: um inimigo atrapalhou o teste.)
- **Navio bugado:** o modelo tinha uma superfície MAGENTA sem textura (material esquecido); vira o vermelho-bandeira do Buggy (`COR_DO_REMENDO`). Também o casco agora assenta na água (a origem do modelo não é a quilha).
- **Buggy "buga" na 1ª parte:** ele e a tripulação ficavam "boiando" no convés; agora ficam ESCONDIDOS até o plano 3 (desembarque), e a câmera do plano 3 saiu de perto do costado do navio.
- **Cena mais lenta:** ~27 s (6,5 + 6 + 7,5 + 7), navio 12 s, desembarque 6 s, caminhada até a praia 9 s.
- **Foco no rosto:** plano 4 é um close no rosto do Buggy (legenda); nas conversas da praia a câmera vai ao rosto dele com dolly lento (`_fala_do_buggy`) e volta ao fim.
- **Animações:** `AnimacoesDoElenco` usa o `AnimationPlayer` dos modelos (`idle`, `walk`, gestos `both_arm_up/enkai/clap/negative` ao falar); Richie só tem idle/walk.
- **Expressões e texturas:** `ExpressoesDoBuggy` troca a albedo do atlas (6 expressões, de `projeto.json` do Codex; o aplicador `tools/texturas/aplicar_projeto_buggy.py` gera os PNGs 64×64 em `assets/textures/desafio_buggy/`). Cada linha do `buggy.json` pode ter `"expressao"`; senão vale a do estado (`do_estado`).
- **Música (só instrumentos, original, inspirada em aventura marítima):** `tools/audio/sintetizar_buggy.py` sintetiza a partir do `BRIEFING.md` do Codex: `buggy_chegada.ogg` (28,5 s), `buggy_sting_riso.ogg` (4,4 s, no `erro_n7`/`recusou`), `buggy_copos_loop.ogg` (12 s, loop). Verificação objetiva (duração, pico, ausência de clipe, curva de volume por compasso, emenda do loop); **não foi ouvida por pessoa**.
- Testes novos: `test_expressoes_do_buggy`; `test_desafio_buggy_no_mapa` cobre trégua, navio, tripulação escondida, foco do rosto, animação e música.

### Limites conhecidos
- O píer da vila é um esqueleto visual SEM colisão (deck só visual, tábuas em x≈262–273, z≈36–44); o piso do cais é fixo (`PISO_DO_CAIS` 0,2). Gatilho: o dono pôr colisão no deck → tirar a constante e usar o raio.
- Os moradores correm em linha reta (sem navmesh): nos testes todos chegaram em chão firme. Gatilho: algum preso em parede → `NavigationAgent3D`.
- Modelos `mp_*`/`mpe_ship_*` são provisórios (memória do projeto); o navio mostra faces magenta de textura (arte). Não há animação de caminhada nos modelos do Buggy/tripulação (deslizam com "passada" vertical).
- Tripulação em Richie (leão quadrúpede) usa o mesmo caminho dos demais; pose não validada.
- Estado local ao jogador; cooperativo real exigiria estado no host.
