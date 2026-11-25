# Execução da Yoru — as 8 ondas de agentes

Entrega M1 + Z/X/C/V em 09/09/2026: [código, fontes e validação](YORU_IMPLEMENTACAO.md).
O mapa abaixo registra a organização planejada; não certifica cada onda como concluída.

Montado em 2026-09-08 a partir de [`PLANO_YORU.md`](PLANO_YORU.md), obedecendo
às regras de divisão de [`AGENTES.md`](AGENTES.md).

As 24 definições são geradas por `tools/agentes/gerar_agentes_yoru.py`, que é a
**fonte única**: os cinco blocos comuns que o `AGENTES.md` exige (ferramentas,
briefing, armadilhas, linha de base da bateria, fronteiras) existem uma vez só.
Corrigir uma armadilha é editar o gerador e rodá-lo de novo — a correção chega
nos 24. Ele escreve nos dois lugares:

```bash
python3 tools/agentes/gerar_agentes_yoru.py
#   .claude/agents/    → a cópia versionada, viaja no git
#   ~/.claude/agents/  → a cópia que o Claude Code REALMENTE lê
```

⚠️ **`.claude/agents/` do projeto nunca é lido**, porque a sessão abre em `~/dev`
e o Claude Code resolve `.claude/` pela pasta da sessão. E definição nova só fica
invocável pelo nome **depois de reiniciar a sessão** — antes disso, lance um
agente genérico mandando ler o arquivo. Ver a última seção do `AGENTES.md`.

---

## Por que ONDAS e não 24 de uma vez

Três motivos, todos medidos neste projeto:

1. **O plano é sequencial por dependência.** A Etapa 0 mede a linha de base
   *antes* da primeira alteração; a 2 depende da prova de rig da 1; a 4 depende
   do arco definitivo da 3. Agente de VFX hoje sincronizaria rastro com um arco
   que ainda vai mudar.
2. **Oito agentes de uma vez estouraram o limite da sessão** em 2026-08-26. Os
   oito morreram juntos e sobrou um shader sem relatório. A regra que ficou é
   onda de 3 a 4.
3. **A porta 24565 não é paralelizável.** Cada agente tem a sua `SOP_PORTA`,
   espaçadas de 10, e o farol de LAN ocupa a seguinte.

---

## O mapa

| Onda | Etapa | Agentes | Portas | Depende de |
|---|---|---|---|---|
| **1** | 0 | `yoru-medidor-linha-base`, `yoru-auditor-rede-base` | 24700, 24710 | — |
| **2** | 1 | `yoru-blender-proporcao`, `yoru-rig-pega`, `yoru-contrato-acao` | 24720-24740 | onda 1 |
| **3** | 2A | `yoru-moveset-controller`, `yoru-varredura-fio`, `yoru-cancelamento` | 24750-24770 | onda 2 |
| **4** | 2B + 3 | `yoru-rede-autoritativa`, `yoru-choque-laminas`, `yoru-modelagem-final`, `yoru-coreografia-m1` | 24780-24810 | onda 3 (arte pode começar após a 2) |
| **5** | 4 | `yoru-vfx`, `yoru-audio`, `yoru-camera-feedback` | 24820-24840 | onda 4 |
| **6** | 5 | `yoru-tecnica-x` → `-z` → `-c` → `-v`, com `yoru-hud-tecnicas` junto | 24850-24890 | onda 5 |
| **7** | 6 | `yoru-balanceamento`, `yoru-perf-carga` | 24900, 24910 | onda 6 |
| **8** | 7 | `yoru-regressao`, `yoru-evidencia-final` | 24920, 24930 | onda 7 |

O paralelismo principal que o plano autoriza é **lógica da etapa 2 + modelagem
da etapa 3**, e é por isso que a onda 4 mistura as duas. O acordo entre essas
frentes — dimensões, marcadores, origem/eixos, relógio e eventos de ação — é o
contrato do `yoru-contrato-acao`. Mudança nele volta aos testes das duas frentes;
não invalida silenciosamente o trabalho da outra.

**Etapa 5 é uma técnica de cada vez**, na ordem de produção **X, Z, C, V** — que
não é a ordem das teclas. X reaproveita passada e corte já resolvidos; Z abre o
caminho de projétil; C exige regras de aparo; V é a mais cara. Concluir uma antes
de acumular quatro implementações incompletas.

---

## Onde cada onda escreve

**Onda 1 roda na árvore principal, em modo somente-leitura.** É deliberado, e é
a única onda assim: a Etapa 0 precisa medir o jogo que existe HOJE, com os 79
arquivos não commitados do ramo `pika-espada-modos-2026-09-06`. Uma worktree
limpa mediria código mais velho e a linha de base sairia falsa. Os dois agentes
da onda 1 são de AUDITORIA e têm `src/`, `tools/`, `assets/`, `Player.gd` e
`docs/` proibidos por nome.

**Ondas 2 em diante vão para worktrees fora do projeto**, criadas à mão:

```bash
cd ~/dev/skills-one-piece
git worktree add -b yoru-etapa1 ~/dev/soptrees/yoru-etapa1 <base>
```

Fora da pasta do projeto porque a worktree automática nasce em
`.claude/worktrees/`, **dentro** dele — e isso já envenenou o `checar_cache.sh`
(o `grep -r` leu código meio-escrito de agente como classe do jogo) e já foi
engolido por um `git add -A` como gitlink. `.gdignore` não resolve: ele fala com
o importador do Godot, não com o `grep`.

### ⚠️ Pendência que trava a onda 2

Worktree nasce de um **commit**. Os 79 arquivos não commitados — entre eles
`Player.gd`, `src/combat/Balance.gd`, `src/anim/ProceduralAnimator.gd` e
`src/ui/SkillBar.gd`, que 6 dos 24 agentes editam — **não estariam lá**. Os
executores trabalhariam sobre código mais velho e o diff voltaria desalinhado,
que é exatamente o efeito silencioso descrito no `AGENTES.md`.

Antes de lançar a onda 2: commitar esse trabalho, ou aplicá-lo nas worktrees.
Não é decisão do orquestrador — é do dono.

---

## Depois que cada onda volta

Relatório de agente é **entrada, não verdade**. Antes de repassar:

```bash
git log --oneline -3        # agente já commitou tendo "não commite" no prompt
git status --short
"$GODOT" --headless --path . --script tools/dev_tests/test_compila.gd
```

⚠️ `--editor --quit` **não** prova que o código compila: ele atualiza o cache de
`class_name` sem carregar os scripts, e um erro de identificador passa como
"0 erros" enquanto o sintoma vira "o golpe não faz nada".

A bateria fecha **55 passou / 9 falhou** desde 2026-09-06, e as nove são
pré-existentes: `test_balance`, `test_buki_buki`, `test_compila`,
`test_frutas_somem`, `test_mink_combate`, `test_morte_limpa_cast`,
`test_trava_fruta_dano`, `net_mp_probe`, `traco_locomocao`. Nenhuma delas é
achado de agente novo.
