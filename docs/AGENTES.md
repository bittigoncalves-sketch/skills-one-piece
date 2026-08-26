# Como o trabalho é dividido neste projeto

> **Regra do dono do projeto (2026-08-10): sempre dividir o trabalho entre
> agentes especializados.**

Nada aqui é sugestão. Toda tarefa que couber em mais de uma especialidade é
repartida entre agentes, cada um com um escopo fechado — em vez de um único
agente genérico varrendo o projeto inteiro.

---

## Por que

Este projeto encosta em disciplinas que quase não se conversam: pipeline de
animação (FBX/glTF/Blender), rig e anatomia, rede cliente-servidor, VFX,
level design, UI. Um agente único carrega o contexto errado para metade do que
faz — lê `Player.gd` (1.500 linhas) para mexer num `.glb`, ou tenta decidir
netcode enquanto mede osso.

Dividir também **isola o estrago**. O agente que mexe no baker de animação não
tem motivo nenhum para tocar em `Scoreboard.gd`; dizer isso na cara dele é o que
impede o "aproveitei e arrumei".

E permite paralelismo real: consertar um clipe do Mixamo e auditar um rig novo
não dependem um do outro, então rodam juntos.

---

## As especialidades

| Especialidade | Território | Arquivos típicos |
|---|---|---|
| **Pipeline de animação** | FBX → glTF → `.res`; Blender headless; bake | `tools/fbx_to_glb.py`, `tools/bake_mixamo.gd`, `assets/animations*/` |
| **Rig e anatomia** | 13 papéis, `Skeleton3D`, Z-up dos Meshy, escala | `src/anim/`, `CharacterBuilder.gd`, `data/characters.json` |
| **Animação procedural** | marcha, parkour, poses de golpe, blend | `src/anim/ProceduralAnimator.gd` |
| **Combate e rede** | dano, knockback, autoridade servidor, RPC | `Player.gd`, `src/combat/`, `src/effects/DamageZone.gd`, `network/` |
| **VFX e assets 3D** | partículas, luz, modelagem no Blender | `src/effects/`, `tools/blender/`, `assets/models/` |
| **Mundo e regras de partida** | mapa, buracos, placar, rodada | `src/world/`, `src/match/` |
| **UI/HUD** | barras, menus, painéis | `src/ui/` |

Duas especialidades no mesmo arquivo é sinal de que o arquivo precisa quebrar,
não de que o agente precisa crescer.

---

## O que todo prompt de agente precisa ter

O agente **começa frio**. Ele não viu a conversa, não conhece o projeto e não
tem como saber o que já foi descartado. O que não estiver no prompt, ele
redescobre — gastando tempo — ou inventa.

1. **A especialidade dele**, na primeira linha. Define o que ele lê primeiro.
2. **Os caminhos das ferramentas.** O `godot` **não está no PATH**:
   - `/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64`
   - `/home/gabriel-bitti/opt/blender/blender` (5.2) — este TAMBÉM funciona
     como `blender` no PATH, conferido em 2026-08-26; o texto antigo dizia que
     não, e agente nenhum precisa perder tempo procurando.
3. **O briefing.** Mande ler [`ESTADO_ATUAL.md`](ESTADO_ATUAL.md) primeiro. Ele
   carrega o que é comum a todos (como rodar, portões de medição que já existem,
   armadilhas desta base) para o prompt não repetir isso oito vezes — e para a
   correção chegar em todos de uma vez quando algo mudar.
4. **O diagnóstico que já existe**, com os números. Sem isso ele refaz a
   investigação inteira e chega ao mesmo lugar duas horas depois.
5. **O que já foi descartado.** Metade do valor de um diagnóstico é saber o que
   *não* era.
6. **O critério de sucesso, medível.** "Consertar a animação" não serve.
   "Amplitude nos membros > 0°, sendo que o `kicking` dá 757°" serve.
7. **As fronteiras.** Que arquivos ele NÃO pode tocar, nominalmente.
8. **As armadilhas conhecidas** — as deste projeto estão logo abaixo.
9. **O formato do relatório.** O relatório do agente não chega ao usuário
   sozinho: quem invocou tem que repassar. Peça as respostas na ordem em que
   você vai precisar delas.

---

## ⚠️ Agente em WORKTREE nasce do RAMO PADRÃO, não do seu

Descoberto em 2026-08-26, com oito agentes de uma vez.

Agente lançado com isolamento por worktree abre a árvore dele a partir do
**`master`** — não do ramo em que você está trabalhando. Se o briefing (ou
qualquer coisa que o prompt mande ler) só existe no seu ramo, o agente abre uma
árvore **sem ele** e o primeiro passo dele já falha.

Foi exatamente o que aconteceu: `ESTADO_ATUAL.md` estava commitado em
`balanceamento-dano-2048`, e a worktree nasceu de `4d0889f`, que é o `master`.
Dois agentes reportaram "o arquivo não existe nesta worktree" antes de morrer.

**Regra prática:** antes de lançar agentes em worktree, **funda no `master`**
tudo o que os prompts mandam ler. Confira com:

```bash
git log --oneline -1 origin/master -- docs/ESTADO_ATUAL.md
```

E há um segundo efeito, pior porque é silencioso: o agente trabalha em cima de
um código **mais velho** que o seu. O que ele "conserta" pode já estar
consertado, e o diff dele volta desalinhado.

---

## ⚠️ Oito agentes de uma vez pode estourar o limite da sessão

Na mesma tentativa de 2026-08-26, os oito morreram juntos com
`You've hit your session limit`. Nenhum deles errou: eles foram interrompidos.

O que sobreviveu foi só o que um deles tinha escrito em disco antes de cair — um
shader, sem relatório e sem verificação nenhuma. **Artefato de agente morto é
rascunho não conferido**, e o `AGENTES.md` já diz que relatório de agente é
entrada e não verdade; sem relatório, menos ainda.

**Regra prática:** lance em ondas (3 a 4), e prefira que cada onda termine antes
da seguinte. Paralelismo que não completa não é paralelismo.

---

## Fronteiras que não se cruzam

- Agente **não commita**. Quem orquestra revisa e commita.

  ⚠️ **Isto já foi violado**, em 2026-08-10, na primeira vez que a regra existiu.
  Um agente com "não rode `git commit`" escrito no prompt commitou assim mesmo
  (`chore: atualiza assets e scripts`, mensagem genérica, autoria do usuário) — e
  o relatório final dele dizia, com todas as letras, *"Não commitei nada"*.
  O conteúdo estava certo; a informação, não.

  Conclusão prática: a regra no prompt **não é garantia**, é pedido. Depois de
  todo agente, rode `git log --oneline` e `git status` e compare com o que ele
  disse ter feito. Se apareceu commit que não é seu, olhe o `--stat` antes de
  qualquer coisa — não reescreva história com outro agente ainda rodando na
  mesma árvore.
- Agente **não roda `git checkout` em massa** — já se perdeu trabalho não
  commitado assim neste ambiente.
- Agente de auditoria **não altera arquivo do projeto**. Auditoria que edita
  deixa de ser auditoria.
- Passo que sobrescreve arquivo em lote (bake, export em pasta) exige **cópia de
  segurança antes** e, quando der, rodar só no arquivo alvo em vez da pasta.

---

## Armadilhas deste projeto (cole nos prompts)

- **Autoloads em script `-s`.** Num `godot --headless --script x.gd` os autoloads
  existem na árvore mas **não viram identificador de compilação** — `GameFlow.x`
  não compila. Use `get_root().get_node("GameFlow")`.
- **`class_name` novo** só entra no cache com `--headless --editor --quit`. Antes
  disso, qualquer script que o use falha com "Identifier not declared".
- ⚠️ **`--editor --quit` NÃO prova que o código compila.** Ele reimporta assets e
  atualiza o cache de `class_name`; não carrega os scripts. Um erro de
  identificador passa como "0 erros" e o sintoma vira "o golpe não faz nada".
  Prova de verdade: `godot --headless --path . --script tools/dev_tests/test_compila.gd`,
  que carrega todo `.gd`. Rodar sempre depois de edição por script.
- **Validar animação por contagem não funciona.** Número de faixas, de chaves ou
  de canais dá "ok" num clipe totalmente congelado. Meça **amplitude por papel**
  ou **amostras por osso**. Foi assim que o `hurricane_kick` passou meses
  quebrado — ver [`erros.md`](erros.md).
- **Esqueleto dos modelos Meshy é Z-up.** A altura fica no Z. Tratar como Y-up
  colapsa os membros para dentro do corpo.
- **Eixos Blender → Godot.** O exportador mapeia `+Y(Blender) → −Z(Godot)`: o
  sinal **inverte**. Copiar offset antigo direto sai espelhado.
- **Blender 5.2** trocou `Action.fcurves` por layers/strips/channelbags; código
  antigo quebra com `AttributeError`.
- **Tela cinza = script da cena não carregou**, não é GPU. Valide com
  `--headless --path .`.

---

## Depois que os agentes voltam

O relatório de um agente é **entrada**, não verdade. Quem orquestra confere o que
dá para conferir barato — de preferência rodando o teste, não relendo o texto — e
só então repassa ao usuário. Agente já entregou número errado com confiança neste
projeto; eu também.

Teste de regressão que cobre o conjunto:

```bash
godot --headless --path . --script tools/dev_tests/test_arena.gd
```
