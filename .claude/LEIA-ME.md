# `.claude/` — fora do projeto Godot

## ⚠️ O `.gdignore` ao lado NÃO É OPCIONAL

Agentes com isolamento por worktree criam árvores de trabalho em
`.claude/worktrees/agent-*/` — que ficam **DENTRO da pasta do projeto**. O Godot
varre tudo abaixo da raiz, então sem o `.gdignore` ele enxerga o código
**meio-escrito** dos agentes como se fosse do jogo.

Sintoma real, em 2026-08-26:

```
Classes novas desde o último preparo: CombatStateBlockBreak CombatStateBlocking ...
Regenerando o cache de class_name (senão o jogo abre em tela cinza)...
AVISO: 'CombatStateBlockBreak' não entrou no cache. Rode ./setup.sh
```

Nenhuma dessas classes pertencia ao projeto: eram de um agente que ainda estava
escrevendo — e que morreu antes de terminar. O `validar.sh` tentou regenerar o
cache por causa delas e a bateria travou.

É a **mesma armadilha** do `art_src/.gdignore` (lá é um `.blend` que faz o Godot
exigir o Blender configurado e derrubar a importação inteira). A regra geral:
**pasta dentro do projeto que não é do jogo precisa de `.gdignore`.**
