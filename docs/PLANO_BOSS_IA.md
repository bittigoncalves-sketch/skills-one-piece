# Plano — Boss mais inteligente e mortal (equipe de agentes)

Status: **onda 1 concluída** (13/09/2026) — linha de base em `art_src/validation/boss_ia/LINHA_DE_BASE.md`; metas aguardando revisão do dono.

Pedido do dono: agentes de IA com o objetivo de tornar o Boss (Buggy) mais
"inteligente" e mortal e de melhorar as skills dele.

Decisões do dono (13/09/2026):

- Os agentes são **subagentes do Claude Code**, com escopo fechado.
- Especialidades escolhidas: **percepção e tática**, **skills e fases** e
  **qualidade e revisão**. Variação de golpes e defesa (fintas, guarda do Boss)
  ficou **fora**: nenhum agente implementa isso sem novo pedido.
- **Exceção pedida pelo dono em 13/09/2026, já implementada fora das ondas:** área
  de detecção de projéteis, **dash de esquiva** e **pulo duplo**
  (`BossProjectileSensor`, `BossMobility`). Recarga do dash: 3 s, só fora do
  próprio golpe. O pulo duplo serve para pular projétil rasteiro, alcançar jogador
  no alto e cruzar buraco de 10 m. A tática e a letalidade partem disso.
- Letalidade **punitiva**. Avisos podem ser mais curtos, combos podem prender e
  o jogador pode ter de decorar padrões. **Todo golpe continua tendo aviso**
  (marca, linha ou pose legível). Um golpe sem aviso nenhum é defeito, não
  dificuldade.

As definições dos agentes não são escritas à mão:
`tools/agentes/gerar_agentes_boss.py` é a fonte única. Para corrigir um agente,
edite o gerador e rode-o de novo.

## A equipe

| Agente | Frente | Tipo | Porta |
|---|---|---|---:|
| `boss-auditor-linha-base` | qualidade | auditoria, não edita o jogo | 25000 |
| `boss-percepcao` | percepção e tática | executor | 25010 |
| `boss-tatica` | percepção e tática | executor | 25020 |
| `boss-skills` | skills e fases | executor, **uma skill por execução** | 25030 |
| `boss-fases` | skills e fases | executor | 25040 |
| `boss-letalidade` | qualidade | executor (só números e dados) | 25050 |
| `boss-rede` | qualidade | executor (só rede e o teste de rede) | 25060 |
| `boss-regressao` | qualidade | auditoria, não edita o jogo | 25070 |

Revisores que já existem e entram no fim de cada skill ou fase:
`critico-de-combate` (game feel) e `avaliador-de-animacao` (poses medidas).

## Ordem (ondas)

⚠️ **As ondas que editam rodam UMA DE CADA VEZ, na árvore principal.** Hoje há
cerca de 413 arquivos não commitados, incluindo o punho destacado do Codex e todo
o trabalho recente do Boss. Uma worktree nasce de um commit e não teria esse
código. Paralelizar agentes que editam exige que o dono commite antes. Essa
decisão é dele.

1. **Onda 1** — `boss-auditor-linha-base`. Mede o Boss de hoje contra os bots de
   referência. Pode rodar em paralelo com `critico-de-combate` (os dois só leem).
2. **Onda 2** — `boss-percepcao`. Depois, `boss-rede` e `boss-regressao`.
3. **Onda 3** — `boss-tatica`. Depois, `boss-rede` e `boss-regressao`.
4. **Onda 4** — `boss-skills`, uma skill por execução, na ordem S1, S2, S3.
   Depois de cada uma: `boss-rede`, `boss-regressao`, `critico-de-combate` e
   `avaliador-de-animacao`.
5. **Onda 5** — `boss-fases`. Depois, `boss-rede` e `boss-regressao`.
6. **Onda 6** — `boss-letalidade`. Por fim, `boss-auditor-linha-base` mede de
   novo nas mesmas condições da onda 1, para a comparação ser justa.

## Os bots de referência (a régua de "inteligente e mortal")

O auditor cria os bots uma vez, e todos os agentes medem com os mesmos. Cada bot
é um roteiro de movimento do jogador, sem input humano, que roda em headless com
física real:

| Bot | Comportamento |
|---|---|
| `parado` | fica de frente, sem se mover |
| `strafe` | anda de lado a 4,2 m/s, trocando de sentido a cada 1,2 s |
| `recuo` | se afasta em linha reta do Boss |
| `kite` | aproxima-se, dá 2 M1 e recua 5 m, em ciclo |
| `circulo` | orbita o Boss a ~3 m |
| `zigzag` | foge desviando de lado em zigue-zague (acrescentado em 13/09 para medir a mira adiantada do corte) |

Medição de referência: `--hitstop=0`, que torna a régua determinística (o hit-stop
usa relógio de parede). O `kite` precisa de `--max` >= 220 s para medir o tempo
para matar em vez de extrapolá-lo.

Grandezas por bot:

- dano causado por segundo;
- tempo para matar 2048 HP;
- taxa de acerto por golpe;
- tempo parado sem agir (em `chase` com velocidade zero, ou `guard` sem ataque);
- número de cortes lançados e acertados;
- uso do punho destacado.

## Metas (revisadas pelo dono em 13/09/2026, após a onda 1)

Linha de base: `art_src/validation/boss_ia/LINHA_DE_BASE.md`.

- **Nunca travar:** tempo parado sem agir com alvo em alcance = 0 s em todos os
  bots. Mantida pelo dono, embora já esteja cumprida. Os ~21 s por minuto
  "perseguindo colado sem atacar" contra o `circulo` (achado A3) não são meta,
  mas a tática deve reduzi-los.
- **Punir quem foge:** contra o bot `zigzag`, pelo menos 50% dos cortes acertam,
  graças à mira adiantada. Contra `recuo`/`kite` o corte já acerta 100%.
- **Mortal:** tempo para matar cai pelo menos 40% contra a linha de base em
  `strafe` e `circulo`. Contra o `kite`, tempo para matar <= 120 s (hoje ~200 s).
  O `kite` usa M1, que paralisa o Boss antes do soco dele (achado A4). A regra da
  paralisia NÃO muda: a tática e as skills contornam, por exemplo atacando de
  fora do alcance dos cliques, com investida e corte.
- **Punitivo com aviso:** todo golpe tem aviso. O piso é 0,15 s na F1; nas fases
  F2 e F3 o dono liberou até **0,12 s** nos jabs.
- **Justiça mínima:** o Boss não acerta golpe em jogador morto ou em respawn, e
  não emenda dano infinito. Todo "prende" termina em janela de saída medida.
- **Não abandonar a luta** (achado A1): o Boss não descarta o alvo só porque o
  arremessou para além do leash.

## Skills da onda 4 (ordem de produção)

- **S1 — Corte com mira adiantada + corte duplo.** A mira usa a previsão de
  posição da percepção. A variante dupla (em X ou em sequência) é um padrão com
  uma linha por evento.
- **S2 — Investida (gap closer).** O Boss avança rápido e emenda o combo quando o
  alvo "kita". Tem aviso próprio e é bloqueada por parede.
- **S3 — Punho destacado fora do combo.** Vira ferramenta de distância média, com
  correção de rumo limitada. Continua sem knockback no meio de combo e mantém a
  regra do "último golpe arremessa".

## Fases (onda 5)

| Fase | Vida | Mudança |
|---|---|---|
| F1 | 100–60% | kit atual, melhorado pela tática |
| F2 | 60–30% | preparações 20% mais curtas, recargas 30% menores, corte duplo liberado |
| F3 | < 30% | investida e punho fora do combo liberados, passo mais rápido, sem pausa longa entre combos |

A transição tem pose e aviso próprios, e o campo da fase é replicado. Os números
são propostas: a `boss-letalidade` fecha os valores.
