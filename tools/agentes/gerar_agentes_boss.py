#!/usr/bin/env python3
"""Gera as definicoes da equipe que torna o Boss mais inteligente e mortal.

Plano: docs/PLANO_BOSS_IA.md. Mesmo desenho do gerador da Yoru: o bloco comum e
UM, e corrigir uma armadilha aqui leva a correcao a todos os agentes.

Os blocos genericos (ferramentas, armadilhas da base, fronteiras, formato do
relatorio) sao IMPORTADOS de `gerar_agentes_yoru.py` em vez de copiados: copia
diverge no primeiro conserto. GATILHO para revisitar: quando surgir um terceiro
gerador, extrair esses blocos para `tools/agentes/comum.py`.

SAIDA
=====
    .claude/agents/boss-*.md    copia versionada (viaja no git)
    ~/.claude/agents/boss-*.md  a copia que o Claude Code REALMENTE le
                                (a sessao abre em ~/dev; ver AGENTES.md)

Definicao nova so fica invocavel por nome DEPOIS de reiniciar a sessao.

USO
===
    python3 tools/agentes/gerar_agentes_boss.py
"""

import pathlib
import sys

AQUI = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from gerar_agentes_yoru import (  # noqa: E402  (blocos genericos, fonte unica)
    ARMADILHAS, FERRAMENTAS, FRONTEIRAS_COMUNS, RELATORIO, bloco_lista,
)

PROJETO = AQUI.parents[1]
DESTINOS = [
    PROJETO / ".claude" / "agents",
    pathlib.Path.home() / ".claude" / "agents",
]

# ===========================================================================
#  BLOCO COMUM DO BOSS
# ===========================================================================

BRIEFING = """\
# Leia isto ANTES de tocar em qualquer coisa

Nesta ordem:

1. `docs/ESTADO_ATUAL.md` -- briefing geral de quem chega frio.
2. `docs/AGENTES.md` -- como o trabalho e dividido e o que voce NAO pode fazer.
3. `docs/PLANO_BOSS_IA.md` -- o plano que voce executa: decisoes do dono, bots de
   referencia, metas, ordem das ondas. Sua onda esta marcada abaixo.
4. `docs/BOSS_BUGGY_PROGRESS.md` -- o que o Boss faz hoje, secao por secao, com a
   evidencia de cada incremento (mais recente no topo).
5. `docs/erros.md` -- as entradas de 12-13/09/2026 sobre o Boss. Sao as causas
   medidas dos defeitos recentes; nao as reintroduza.

Decisoes do dono que voce NAO rediscute:
- letalidade **punitiva**: aviso pode ser curto e combo pode prender, mas **todo
  golpe tem aviso** (marca, linha ou pose legivel);
- **variacao de golpes e defesa do Boss (fintas, guarda) estao FORA** do escopo
  -- nao implemente, nem "de leve". EXCECAO ja implementada a pedido do dono
  (13/09): area de deteccao de projeteis + dash de esquiva (recarga 3 s, so fora
  do proprio golpe) + pulo duplo (projetil rasteiro, jogador no alto, buraco de
  10 m) em `BossProjectileSensor.gd`/`BossMobility.gd`. Use; nao reimplemente;
- o corte a distancia MANTEM knockback; os socos do combo NAO tem knockback; so
  o ULTIMO golpe que sai no combo arremessa (com derrubada do jogador).
- aviso minimo: 0,15 s na F1; nas fases F2/F3 o dono liberou ate 0,12 s nos jabs;
- a PARALISIA que os M1 do jogador causam no Boss (1o/2o acerto paralisam, 3o
  arremessa) NAO muda -- contra quem "kita", a tatica e as skills contornam;
- a meta "nunca travar" continua sendo tempo parado = 0 s (decisao do dono).

**Metas vigentes e linha de base: `docs/PLANO_BOSS_IA.md` (secao Metas) e
`art_src/validation/boss_ia/LINHA_DE_BASE.md`.** Meca com a regua
`tools/dev_tests/medir_boss_ia.gd` e `--hitstop=0` (deterministico); `kite` com
`--max` >= 220 s.
"""

DIAGNOSTICO = """\
# O Boss de hoje -- com os numeros. Nao refaca.

Tudo abaixo foi medido em 12-13/09/2026 com Godot 4.6.3, headless, fisica real.

**Arquitetura** (`src/bosses/`):

| Arquivo | Papel |
|---|---|
| `BossActor.gd` | corpo (capsula r 0,55, altura 2,2), vida 4096, campos replicados, `take_damage`, flash de dano |
| `BossDefinition.gd` + `assets/bosses/buggy/buggy_definition.tres` | dados: `ability` + `followups` (combo), `slash`, `detached_part` |
| `BossAbility.gd` / `BossSlashAbility.gd` / `BossDetachedAbility.gd` | fichas de golpe (windup/active/recovery/cooldown/dano/knockback/launch) |
| `BossBrain.gd` | alvo (aggro 11 m, leash 22 m, linha de visao) e `flee_rate` |
| `BossController.gd` | `_decide`: corte se o alvo foge; combo se no alcance ou `touching`; senao persegue com `safe_direction` |
| `BossCombat.gd` | combo (1 cast por golpe), varredura do punho, corte (YoruWave), `launch_if_hit`, `step_velocity` |
| `BossDetachedAttack.gd` / `BossHandBinding.gd` | punho destacado (trabalho do Codex, 13/09) |
| `BossHitReaction.gd` + `BossReactionPose.gd` | recepcao de M1 do jogador: 1o/2o paralisam, 3o arremessa o Boss |
| `BossVisual.gd`, `BoxingPose.gd`, `BossThrowPose.gd`, `BossTelegraph.gd` | poses procedurais e marca vermelha no chao |
| `BossEncounter.gd` | spawn e `MultiplayerSynchronizer` (lista de campos replicados) |
| `BossProjectileSensor.gd` | area de deteccao (Area3D r 12 m): projetil do jogador em voo que vai acertar em <= 0,6 s |
| `BossMobility.gd` | dash de esquiva (4 m em 0,22 s, recarga 3 s, lado sem parede/buraco) e pulo duplo (12 + 10 m/s) |

**O combo** (5 golpes; knockback 0 em TODOS):

| golpe | mao | windup | active | recovery | dano | arremessa |
|---|---|---:|---:|---:|---:|---|
| jab | E | 0,24 | 0,12 | 0,10 | 72 | -- |
| jab_right | D | 0,16 | 0,12 | 0,10 | 72 | -- |
| jab_left | E | 0,16 | 0,12 | 0,10 | 72 | -- |
| jab_finish | D | 0,16 | 0,12 | 0,60 | 72 | so se o punho NAO emenda |
| detached_fist | D | 0,55 | 0,45 | 0,45 (+0,35 retorno) | 112 | sim (14 m/s + 9 m/s) |

- Punho destacado so fica disponivel a cada 6 s (`reuse_delay`) e emenda se o
  alvo esta a <= 7 m. Sem ele, o combo acaba no 4o soco, que arremessa.
- **Alcance real do soco: ~0,97 m do centro do Boss** (mao estendida 0,72 m +
  raio 0,22; o torax gira e soma 0,14 m). `attack_distance` 1,25;
  `combo_break_distance` 2,0; `STEP_SPEED` 5 m/s (passo a frente na preparacao e
  no contato, ate 1,25 m).
- **Corte** (`corte`): mira acompanha 0,30 s, trava, linha vermelha 0,55 s,
  frente de 18 m x 1,5 m a 26 m/s, 90 de dano, knockback 14, recarga 4 s.
  Dispara so com o alvo FUGINDO (`flee_rate` >= 2 m/s) entre 4 e 18 m. Mira
  **sem previsao**: aponta para onde o alvo esta.
- O cerebro ignora a fuga de quem esta arremessado (`Player.esta_arremessado`).

**Numeros de teste que voce NAO pode piorar** (todos 0 falhas hoje):
`test_boss_lifecycle` 54, `test_boss_recepcao` 31, `test_boss_corte` 26,
`test_boss_detached` 28, `test_boss_arremesso_jogador` 34, `test_boss_mobilidade` 21,
`python3 tools/dev_tests/test_boss_network.py` 36 (host+cliente+voo+tardio),
`test_boss_buggy_visual` ok.

**Rede:** o servidor simula e aplica dano; o cliente so apresenta a partir dos
campos replicados listados em `BossEncounter._make_actor`. Campo novo de estado
que o cliente precisa ver TEM de entrar nessa lista.

**O jogador** (`Player.gd`, ~4 mil linhas, com trabalho de outras frentes nao
commitado): caixa 1,0 x 1,6 x 1,0; vida 2048; andar 4,2 m/s; derrubada nova em
`src/player/player_arremesso.gd`; flash em `src/effects/FxUtil.gd`
(`flash_dano`).
"""

DESCARTADO = """\
# O que JA FOI DESCARTADO

- **"A caixa de colisao girando fazia os socos errarem."** Refutado medindo: com
  capsula, os socos continuaram errando a 1,54 m. A causa era margem de alcance
  (soco ~0,97 m vs combo comecando a ate 1,58 m). A capsula ficou por outro
  motivo (contato igual em qualquer rotacao).
- **Knockback nos jabs.** Tirado pelo dono: afastava o alvo e o combo errava.
- **Cotovelada/chute recuando/esquiva com gancho (W/A/S/D + clique)** do jogador:
  apagados a pedido do dono. Nao os reintroduza nem conte com eles em bot.
- **Corte emendado em alvo arremessado.** Proibido pelo cerebro de proposito.
- **Medir dano no CLIENTE durante segundos.** A regeneracao local e a correcao
  autoritativa da vida se misturam; meca na copia do servidor.
- **`git checkout` como linha de base.** ~413 arquivos nao commitados na arvore.
"""

ARMADILHAS_BOSS = """\
# Armadilhas do Boss (todas custaram tempo nesta frente)

- **`SOP_BOSS_ENABLED=1`** e obrigatorio em teste: sondas em `tools/dev_tests/`
  desligam o Boss por padrao (`BossEncounter._enabled`).
- **Desligue os bonecos** (`flow.dummies["TrainingDummy"] = false`,
  `flow.dummies["AutoDummy"] = false`): o AutoDummy soca todo mundo e polui vida.
- **Nao ponha o Boss em (0, y, 0) e meca na hora**: no centro da arena ele e
  deslocado ~1 m nos primeiros quadros. Espere assentar ou use outro ponto.
- **Fisica do jogador desligada acumula empurrao** (`_vida._empurrao`): ao
  religar, ele e aplicado de uma vez. Zere antes.
- **Espera em tempo real + medida de posicao "antes do golpe"** da numero
  instavel. Meca a partir do EVENTO (acerto, mudanca de fase).
- **`test_move` com a capsula APOIADA no chao acusa colisao com o proprio piso**:
  levante o transform ~8 cm para testar so parede (medido: nenhum dash saia).
- **Congelar a fisica SO do Boss numa captura** deixa projeteis voando e acertando
  o corpo parado. Fotografe sem congelar.
- **`get_meta(nome, null)`** acusa erro quando a meta nao existe: `null` como
  padrao equivale a nao passar padrao. Use `has_meta`.
- **Chamar classe que referencia autoload direto do teste `-s`** (ex.:
  `SpinKickFX`, que usa `ScreenFX`) nao compila. Passe pelo caminho real do jogo.
- **`class_name` novo** so aparece com
  `"$GODOT" --headless --path . --import` antes do teste.
- **Rede:** o runner e `python3 tools/dev_tests/test_boss_network.py` (3
  processos). Rodar o `.gd` sozinho so avisa que faltam os peers. Posicao do
  jogador e do DONO: o servidor escrever `position` num corpo de cliente nao vale.
- **Codex trabalha no Boss em paralelo as vezes.** Antes de editar, confira
  `ls -la --time-style=+%H:%M src/bosses/` e compare com o que voce leu; se um
  arquivo mudou depois da sua leitura, releia antes de escrever.
"""

BATERIA = """\
# Linha de base da bateria -- NAO reporte falha velha como achado seu

Em 13/09/2026, depois de a trava pos-fruta de 5 s ser desligada, o
`./validar.sh rapido` fechava **81 passou / 7 falhou / 1 pulado**. As sete ja
falhavam antes de toda a frente do Boss: `test_balance`, `test_compila`,
`test_corte_horizontal`, `test_mera_z_saque`, `test_ope_animacoes`,
`test_studio_playback`, `test_trava_fruta_dano`. (`test_buki_buki`,
`test_morte_limpa_cast` e `net_mp_probe` voltaram a passar: dependiam da trava.)
Log de referencia: `art_src/validation/trava_fruta/rapido.log`. Compare nome E
contagem de problemas (`diff` das linhas `FALHOU`), nao so o total.
"""

# ===========================================================================
#  A EQUIPE
# ===========================================================================

EXEC = "Read, Grep, Glob, Bash, Write, Edit"
AUDIT = "Read, Grep, Glob, Bash, Write"

TESTES_BOSS = ("`tools/dev_tests/test_boss_*.gd` (todos) e "
               "`python3 tools/dev_tests/test_boss_network.py`")

AGENTES = [
    dict(
        nome="boss-auditor-linha-base", onda="1 (e 6, remedicao)", porta=25000, tools=AUDIT,
        especialidade="Auditoria de IA de combate",
        desc="Onda 1 do PLANO_BOSS_IA: mede o Boss atual contra cinco bots de jogador "
             "(parado, strafe, recuo, kite, circulo) -- DPS, tempo para matar, acerto por "
             "golpe, tempo travado, cortes. NAO altera codigo do jogo.",
        missao="""\
Construir a regua e medir o Boss de HOJE com ela, antes de qualquer agente
mexer. Na onda 6 voce roda de novo, nas mesmas condicoes, e entrega a
comparacao.

1. Escreva UM script de medicao reutilizavel, com os cinco bots do plano
   (`parado`, `strafe`, `recuo`, `kite`, `circulo`). Cada bot move o jogador
   real (fisica ligada, sem input humano) contra o Boss real na arena normal,
   por no minimo 40 s ou ate o jogador morrer. O script fica no SEU territorio,
   para os outros agentes o reutilizarem sem mudar a regua.
2. Por bot, meca: DPS; tempo para matar 2048 HP (vida do jogador sem
   regeneracao artificial; se precisar prolongar, some o dano em vez de mudar a
   vida); taxa de acerto por golpe (`action_id` + queda de vida medida na copia
   autoritativa); tempo parado sem agir com alvo em alcance; cortes lancados e
   acertados; usos do punho destacado; distancia media ao alvo.
3. Grave um log de decisao (instante, estado, acao, distancia, `flee_rate`) --
   e a entrada que `boss-tatica` vai usar.
4. Sem editar codigo: o que parecer defeito vira ACHADO com numero, nao conserto.""",
        sucesso="""\
`art_src/validation/boss_ia/LINHA_DE_BASE.md` com uma tabela por bot (as
grandezas acima, cada uma com o comando e a semente usada), o log de decisao
bruto e o script de medicao. Repetir o script duas vezes da os mesmos numeros
com tolerancia declarada (ex.: +-5%); se nao der, isso e o primeiro achado.""",
        territorio=["`art_src/validation/boss_ia/` (criar; relatorio, logs)",
                    "`tools/dev_tests/medir_boss_ia.gd` (criar; o script da regua -- NAO comeca com `test_`, "
                    "para o `validar.sh` nao roda-lo como teste)",
                    "/tmp ou o scratchpad (sondas temporarias)"],
        proibido=["qualquer arquivo de `src/`, `assets/`, `Player.gd`, `Main.gd`",
                  "testes existentes em `tools/dev_tests/test_*.gd`",
                  "voce e AUDITORIA: auditoria que edita deixa de ser auditoria"],
        leitura=["`src/bosses/` inteiro", "`tools/dev_tests/test_boss_arremesso_jogador.gd` (modelo de bot com fisica real)",
                 "`docs/BOSS_BUGGY_PROGRESS.md`"],
    ),
    dict(
        nome="boss-percepcao", onda="2", porta=25010, tools=EXEC,
        especialidade="Percepcao de IA (modelo do alvo)",
        desc="Onda 2 do PLANO_BOSS_IA: cria BossPerception -- modelo do alvo lido no "
             "servidor (velocidade suavizada, previsao de posicao, fuga, fase de ataque, "
             "recuperacao/whiff, arremessado, vida) -- e move o flee_rate do BossBrain para la.",
        missao="""\
Dar ao Boss um modelo do jogador que a tatica e as skills possam consultar, sem
cada uma recalcular do seu jeito.

`src/bosses/BossPerception.gd` (novo), consultado pelo `BossBrain`:
- velocidade do alvo suavizada a partir das POSICOES (funciona para jogador
  remoto no servidor, que nao tem `velocity` confiavel);
- `predict(t)` -- posicao prevista em `t` segundos, limitada por parede (raio
  contra o cenario) e por buraco (`MapBuilder.is_hole_area`);
- `flee_rate` (mova a logica atual do `BossBrain`, com o mesmo comportamento
  medido: arremessado nao conta);
- estado de combate do alvo que o SERVIDOR realmente conhece: em startup, em
  recuperacao, errou o golpe (whiff), arremessado, no ar, vida em fracao. Para
  cada campo, prove no relatorio que ele e valido para jogador REMOTO no servidor
  -- se o dado so existe na copia do dono, nao use (ou replique, com o
  `boss-rede` avisado no relatorio).

Tambem e seu (achado A1 da linha de base, no `BossBrain`): o Boss descarta o alvo
0,53 s depois de arremessa-lo para alem do leash e volta para casa. Um alvo
arremessado pelo proprio Boss nao pode ser abandonado por isso -- ele continua
alvo enquanto estiver vivo e dentro de um limite declarado por voce.

Nao decide nada: so observa. Quem decide e a `boss-tatica`.""",
        sucesso="""\
Teste novo `tools/dev_tests/test_boss_percepcao.gd`:
- previsao a 0,5 s de um bot `strafe` erra <= 0,6 m na media (e mede o erro sem
  previsao, para mostrar o ganho);
- previsao nao atravessa parede;
- `flee_rate` preserva os casos de `test_boss_corte` (parado nao foge, recuo foge,
  arremessado nao foge);
- cada campo de estado verificado em singleplayer E numa partida de rede real;
- alvo arremessado alem do leash continua alvo (teste reproduz o achado A1: antes
  descartava em ~0,5 s).

Todos os testes do Boss seguem com 0 falhas.""",
        territorio=["`src/bosses/BossPerception.gd` (criar)", "`src/bosses/BossBrain.gd`",
                    "`tools/dev_tests/test_boss_percepcao.gd` (criar)"],
        proibido=["`src/bosses/BossController.gd` e `BossCombat.gd` (sao da tatica/skills)",
                  "`Player.gd` -- se precisar de um dado do jogador que nao existe, ESCREVA no relatorio",
                  "`src/combat/`, `src/effects/`, `assets/`"],
        leitura=["`src/bosses/BossBrain.gd`", "`src/bosses/BossController.gd`",
                 "`tools/dev_tests/test_boss_corte.gd`", "`art_src/validation/boss_ia/LINHA_DE_BASE.md`"],
    ),
    dict(
        nome="boss-tatica", onda="3", porta=25020, tools=EXEC,
        especialidade="Tatica de IA (tomada de decisao)",
        desc="Onda 3 do PLANO_BOSS_IA: troca a ordem fixa do BossController._decide por "
             "escolha de acao pontuada (perseguir, pressionar, punir recuperacao, cortar com "
             "mira adiantada, anti-kite, pressao no levantar) usando BossPerception.",
        missao="""\
O `_decide` de hoje e uma escada de `if`: corte se foge, combo se perto, senao
persegue. Troque por escolha de acao PONTUADA e deterministica (mesma entrada ->
mesma decisao; qualquer aleatoriedade com semente), num arquivo proprio.

`src/bosses/BossTactics.gd` (novo). Acoes minimas:
- perseguir e cortar caminho (mirar onde o alvo ESTARA, nao onde esta);
- iniciar combo;
- **punir**: atacar quando o alvo esta em recuperacao ou errou golpe;
- corte com mira adiantada (`predict`) contra quem foge OU "kita" (se aproxima,
  bate e recua);
- pressao no levantar: posicionar-se junto de alvo arremessado para agir quando
  ele fica de pe (sem acertar enquanto ele esta deitado -- o dano em alvo deitado
  e decisao do dono que nao existe);
- anti-travamento: nunca ficar parado sem agir com alvo em alcance.

Guarde, por decisao, o motivo (pontuacao por acao) num log barato ligavel por
variavel de ambiente -- o auditor precisa dele.

⚠️ FORA DO ESCOPO: fintas, esquiva, guarda, bloqueio. Decisao do dono.""",
        sucesso="""\
Rodando `tools/dev_tests/medir_boss_ia.gd` (a regua do auditor, sem altera-la):
- tempo parado sem agir com alvo em alcance = 0 s nos 5 bots;
- DPS contra `kite` e `circulo` >= 1,5x a linha de base (meta final do plano: `kite`
  <= 120 s para matar, sem mudar a regra da paralisia -- evite ficar no alcance
  dos M1 dele);
- teste novo `tools/dev_tests/test_boss_tatica.gd`: pune recuperacao (alvo em
  whiff recebe ataque em <= 0,35 s quando em alcance), nao age em alvo deitado,
  mesma semente -> mesma sequencia de decisoes.

Todos os testes do Boss seguem com 0 falhas.""",
        territorio=["`src/bosses/BossTactics.gd` (criar)", "`src/bosses/BossController.gd`",
                    "`tools/dev_tests/test_boss_tatica.gd` (criar)"],
        proibido=["`src/bosses/BossCombat.gd` e as fichas de golpe (sao das skills)",
                  "`BossPerception.gd` (so ler; falta de dado vira pedido no relatorio)",
                  "`Player.gd`, `src/combat/`, `assets/`"],
        leitura=["`src/bosses/BossPerception.gd`", "`src/bosses/BossController.gd`",
                 "`src/bosses/BossCombat.gd`", "`art_src/validation/boss_ia/LINHA_DE_BASE.md`"],
    ),
    dict(
        nome="boss-skills", onda="4 (uma skill por execucao: S1, S2, S3)", porta=25030, tools=EXEC,
        especialidade="Design e implementacao de skills de Boss",
        desc="Onda 4 do PLANO_BOSS_IA: implementa UMA skill por execucao -- S1 corte com "
             "mira adiantada + corte duplo, S2 investida (gap closer), S3 punho destacado fora "
             "do combo -- com dados, aviso, pose, rede e teste.",
        missao="""\
Quem invoca diz qual skill (S1, S2 ou S3). Faca SO ela.

- **S1 -- corte com mira adiantada + corte duplo.** A mira usa
  `BossPerception.predict` no instante em que trava. Variante dupla: dois eventos
  de corte com uma linha vermelha cada, intervalo proprio, uma recarga
  compartilhada. Dano por evento declarado; cada alvo leva cada evento no maximo
  uma vez.
- **S2 -- investida.** Avanco rapido em linha que emenda o combo quando o alvo
  esta entre ~3 e ~8 m. Aviso proprio (pose + marca no chao), para em parede e
  buraco, nao atravessa o jogador.
- **S3 -- punho destacado fora do combo.** Ferramenta de distancia media com
  correcao de rumo limitada (graus/s declarado). Respeita a recarga do punho e
  as regras atuais (knockback 0; "ultimo golpe arremessa" so dentro do combo).

Para toda skill: ficha de dados (`BossAbility` ou subclasse), aviso (a regra do
dono: todo golpe tem aviso), pose procedural em espaco do ATOR (o esqueleto do
Meshy e Z-up: nao use eixo local de osso), campos de rede, e liberacao para a
`boss-tatica` escolher a skill (exponha a condicao de uso; nao edite o
`BossController`).""",
        sucesso="""\
- Teste novo `tools/dev_tests/test_boss_skill_<s1|s2|s3>.gd`: aviso aparece antes
  do dano (>= 0,15 s), dano sai uma vez por evento, parede bloqueia, cancelamento
  por dano nao deixa efeito pendurado.
- S1: contra o bot `zigzag`, taxa de acerto do corte >= 50% (linha de base no
  relatorio do auditor).
- Capturas com renderizador real das fases da skill em
  `art_src/validation/boss_ia/<skill>/`, inspecionadas por voce.
- Todos os testes do Boss seguem com 0 falhas.""",
        territorio=["`src/bosses/BossCombat.gd`", "`src/bosses/BossAbility.gd` e subclasses (e novas fichas)",
                    "`src/bosses/BossVisual.gd`, `BossTelegraph.gd`, `BossThrowPose.gd` e poses novas",
                    "`assets/bosses/buggy/buggy_definition.tres`",
                    "`tools/dev_tests/test_boss_skill_*.gd` (criar)", "`art_src/validation/boss_ia/`"],
        proibido=["`src/bosses/BossController.gd`, `BossTactics.gd`, `BossPerception.gd` (so ler)",
                  "`BossDetachedAttack.gd`/`BossHandBinding.gd` exceto na S3",
                  "`Player.gd`, `src/combat/YoruWave.gd` (use por dados; mudanca vira pedido)"],
        leitura=["`src/bosses/BossCombat.gd`", "`src/bosses/BossTelegraph.gd`",
                 "`tools/dev_tests/test_boss_corte.gd`", "`tools/dev_tests/test_boss_detached.gd`"],
    ),
    dict(
        nome="boss-fases", onda="5", porta=25040, tools=EXEC,
        especialidade="Fases de encontro de Boss",
        desc="Onda 5 do PLANO_BOSS_IA: fases por vida (F1 100-60%, F2 60-30% enrage, F3 <30% "
             "desesperado) com transicao anunciada, campo de fase replicado e modificadores de "
             "dados aplicados sem duplicar fichas.",
        missao="""\
Faca o Boss escalar com a vida perdida, conforme a tabela de fases do plano.

- Fase como DADO (`BossPhase` ou equivalente na definicao): limite de vida,
  multiplicadores de windup/recarga/passo, skills liberadas. Nada de copiar
  fichas por fase -- modificador aplicado na leitura.
- Transicao: pose e aviso proprios (duracao declarada), sem dano surpresa. Se
  voce der invulnerabilidade na transicao, declare a duracao e teste.
- Campo de fase replicado (`BossEncounter`), apresentacao no cliente e na barra
  de vida do Boss se couber no seu territorio.
- A `boss-tatica` le a fase para liberar skills; exponha, nao edite o controller.""",
        sucesso="""\
Teste novo `tools/dev_tests/test_boss_fases.gd`: cruza 60% e 30% uma unica vez
cada (sem oscilar com cura/dano pequeno), aplica os multiplicadores medindo o
windup real, libera as skills da fase, entrada tardia em rede recebe a fase
correta. Todos os testes do Boss seguem com 0 falhas.""",
        territorio=["`src/bosses/BossDefinition.gd`", "`src/bosses/BossActor.gd`",
                    "`src/bosses/BossEncounter.gd` (so a lista de campos replicados)",
                    "`src/bosses/BossPhase.gd` (criar)", "`src/ui/BossHealthBar.gd`",
                    "`assets/bosses/buggy/buggy_definition.tres`", "`tools/dev_tests/test_boss_fases.gd` (criar)"],
        proibido=["`BossController.gd`, `BossTactics.gd`, `BossPerception.gd`, `BossCombat.gd`",
                  "`Player.gd`, `src/combat/`"],
        leitura=["`src/bosses/BossActor.gd`", "`src/bosses/BossEncounter.gd`", "`src/ui/BossHealthBar.gd`"],
    ),
    dict(
        nome="boss-letalidade", onda="6", porta=25050, tools=EXEC,
        especialidade="Balanceamento de letalidade (punitivo)",
        desc="Onda 6 do PLANO_BOSS_IA: ajusta SO numeros (dano, windups, recargas, passo, "
             "fases) contra as metas medidas nos cinco bots, mantendo todo golpe com aviso.",
        missao="""\
Feche os numeros. Voce so mexe em DADOS -- fichas, multiplicadores de fase,
constantes de tuning ja expostas. Mudanca de logica e pedido no relatorio.

Metas (confirme no `PLANO_BOSS_IA.md` se o dono ajustou):
- tempo para matar cai >= 40% contra a linha de base em `strafe`, `kite`,
  `circulo`;
- nenhum golpe com aviso < 0,15 s na F1, nem < 0,12 s nas F2/F3 (limites do dono);
- nenhum loop sem saida: todo "prende" termina em janela de saida medida;
- nada acerta jogador morto ou em respawn.

Ajuste em conjunto e registre cada rodada (valor antes -> depois -> efeito
medido). Um numero que melhora um bot e piora outro volta.""",
        sucesso="""\
Tabela antes/depois por bot (a mesma regua do auditor) em
`art_src/validation/boss_ia/LETALIDADE.md`, com as metas atingidas ou a
distancia que falta. Todos os testes do Boss seguem com 0 falhas -- se um teste
fixa um numero que voce mudou, atualize o numero ESPERADO no teste com
justificativa escrita, nunca afrouxe a verificacao.""",
        territorio=["`assets/bosses/buggy/buggy_definition.tres` e fichas `.tres` do Boss",
                    "constantes de tuning em `src/bosses/*.gd` (so o valor)",
                    "numeros esperados em `tools/dev_tests/test_boss_*.gd`", "`art_src/validation/boss_ia/`"],
        proibido=["logica de qualquer `.gd`", "`Player.gd`, `src/combat/Balance.gd` (balanceamento do PvP)",
                  "`tools/dev_tests/medir_boss_ia.gd` (a regua nao muda)"],
        leitura=["`art_src/validation/boss_ia/LINHA_DE_BASE.md`", "`docs/PLANO_BOSS_IA.md`"],
    ),
    dict(
        nome="boss-rede", onda="depois de cada onda que edita", porta=25060, tools=EXEC,
        especialidade="Rede autoritativa do Boss",
        desc="PLANO_BOSS_IA, apos cada onda: valida em partida real (3 processos) que "
             "comportamento novo do Boss e decidido so no servidor, replica o necessario e "
             "funciona em entrada tardia; estende test_boss_network.",
        missao="""\
Depois de cada onda que edita, prove que o que entrou funciona em rede:
- decisao e dano so no servidor; cliente que tenta iniciar acao ou aplicar dano e
  ignorado;
- todo estado que o cliente precisa VER esta na lista replicada do
  `BossEncounter` e chega em entrada tardia no meio da acao;
- efeitos visuais do cliente (linha, frente de corte, poses) acontecem uma vez
  por evento, sem duplicar dano.

Estenda `tools/dev_tests/test_boss_network.gd`/`.py` com um bloco por
comportamento novo. Se faltar replicacao, voce pode adicionar o CAMPO a lista do
`BossEncounter`; logica de jogo nao e sua -- vira pedido no relatorio.""",
        sucesso="""\
`python3 tools/dev_tests/test_boss_network.py` com 0 falhas em host, cliente,
voo e tardio, incluindo um bloco novo por comportamento da onda validada, e o
log de cada processo em `art_src/validation/buggy_boss/network/`.""",
        territorio=["`tools/dev_tests/test_boss_network.gd`", "`tools/dev_tests/test_boss_network.py`",
                    "`src/bosses/BossEncounter.gd` (so a lista de campos replicados)"],
        proibido=["logica em `src/bosses/*.gd`", "`Player.gd`", "`Main.gd`"],
        leitura=["`src/bosses/BossEncounter.gd`", "os arquivos que a onda validada alterou"],
    ),
    dict(
        nome="boss-regressao", onda="depois de cada onda que edita", porta=25070, tools=AUDIT,
        especialidade="Regressao e integridade",
        desc="PLANO_BOSS_IA, apos cada onda: roda todos os testes do Boss, test_compila e a "
             "bateria rapida; separa regressao nova das 10 falhas conhecidas. NAO altera codigo.",
        missao="""\
Diga, com saida de teste, se a onda quebrou algo.

1. `"$GODOT" --headless --path . --import`, depois `test_compila.gd`: nenhum
   script novo do Boss pode aparecer na lista de falhas.
2. Todos os testes do Boss (lista no diagnostico) e o de rede.
3. `./validar.sh rapido` -- compare as linhas `FALHOU` com o log de referencia
   (nome E contagem).
4. `git status --porcelain` e `git log --oneline -3`: nenhum commit que o
   orquestrador nao fez; arquivos tocados batem com o territorio declarado pelo
   agente da onda (liste divergencias).""",
        sucesso="""\
Relatorio com: tabela teste -> resultado (com contagem), diff de falhas da
bateria contra a linha de base, arquivos tocados fora de territorio (ou
"nenhum"), e o veredito "sem regressao" ou a lista de regressoes com o comando
que as reproduz.""",
        territorio=["`art_src/validation/boss_ia/regressao/` (criar; logs)", "/tmp ou o scratchpad"],
        proibido=["qualquer arquivo de `src/`, `assets/`, `tools/`, `Player.gd`",
                  "voce e AUDITORIA: nao conserte o que achar"],
        leitura=["`validar.sh`", "`art_src/validation/buggy_boss/arremesso_flash/rapido.log`"],
    ),
]


def montar(a):
    porta = a["porta"]
    cabecalho = f"""---
name: {a['nome']}
description: {a['desc']}
tools: {a['tools']}
model: opus
---

Voce e **{a['especialidade'].lower()}** no jogo `skills-one-piece`, executando a
**onda {a['onda']}** do `docs/PLANO_BOSS_IA.md`: tornar o Boss (Buggy) mais
inteligente e mortal, e melhorar as skills dele.

Projeto: `/home/gabriel-bitti/dev/skills-one-piece`

⚠️ **Sua porta e `SOP_PORTA={porta}`.** Exporte antes de rodar qualquer teste que
suba o jogo, ou voce colide com outro agente na sala ENet:

```bash
export SOP_PORTA={porta}
```

O farol de LAN e derivado (`jogo + 1`), entao {porta + 1} tambem e seu.
"""
    partes = [
        cabecalho,
        "# Sua missao\n\n" + a["missao"] + "\n",
        "# Criterio de sucesso -- MEDIVEL\n\n" + a["sucesso"] + "\n",
        bloco_lista("Seu territorio (so aqui voce escreve)", a["territorio"]),
        bloco_lista("PROIBIDO tocar", a["proibido"]),
        bloco_lista("Leia para se situar (sem editar)", a["leitura"]),
        FERRAMENTAS,
        BRIEFING,
        DIAGNOSTICO,
        DESCARTADO,
        ARMADILHAS,
        ARMADILHAS_BOSS,
        BATERIA,
        "# Testes do Boss\n\n" + TESTES_BOSS + "\n",
        FRONTEIRAS_COMUNS,
        RELATORIO,
    ]
    return "\n---\n\n".join(p.strip() + "\n" for p in partes)


def main():
    for d in DESTINOS:
        d.mkdir(parents=True, exist_ok=True)
    nomes = [a["nome"] for a in AGENTES]
    assert len(nomes) == len(set(nomes)), "nome de agente duplicado"
    portas = [a["porta"] for a in AGENTES]
    assert len(portas) == len(set(portas)), "porta duplicada"
    for a in AGENTES:
        texto = montar(a)
        for d in DESTINOS:
            (d / f"{a['nome']}.md").write_text(texto, encoding="utf-8")
    print(f"{len(AGENTES)} agentes gerados em:")
    for d in DESTINOS:
        print(f"  {d}")
    print("\nPortas: " + ", ".join(str(p) for p in portas))


if __name__ == "__main__":
    main()
