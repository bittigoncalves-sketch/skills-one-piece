# Ferramentas, testes e pipeline — para quem chega

> Versão para agentes: [`../agentes/ferramentas.md`](../agentes/ferramentas.md) · arquivos: [`../INDICE.md#ferramentas`](../INDICE.md#ferramentas)

## O que é

As ferramentas que provam que o jogo funciona e ajudam a produzir conteúdo:

- **A bateria de testes** — cerca de 100 testes automáticos em `tools/dev_tests/`, que abrem o jogo
  sem janela, fazem coisas e conferem o resultado com números.
- **Os scripts de raiz** — `jogar.sh` e variações, `servidor.sh`, `validar.sh` (roda a bateria),
  `checar_cache.sh` (evita a tela cinza depois de criar classe nova).
- **O pipeline de arte** — Blender, animações do Mixamo, prévias que capturam imagens de cada fase
  de um golpe.
- **O índice de busca** deste projeto (`tools/contexto/`).

## O que usar no dia a dia

```bash
./validar.sh rapido                  # a bateria, sem os testes mais lentos
./validar.sh camera rig              # só os testes com esses nomes
godot --headless --path . --script tools/dev_tests/test_compila.gd   # prova que tudo compila
python3 tools/contexto/indice.py buscar "o que procuro"
```

Hoje (21/09) **8 testes já falham por motivos conhecidos**. Se aparecer uma falha fora dessa lista
(no [`PROJECT_CONTEXT.md`](../../../PROJECT_CONTEXT.md) §8), provavelmente foi a sua mudança.

## Como é um bom teste aqui

- **Confere com número**, não com "parece certo".
- **Sabe reprovar:** tem um caso de controle que falharia se o código estivesse errado.
- **Diz as condições:** por exemplo, "os dois bonecos estavam no chão".

## Cuidado com

- **Um teste de rede por vez.** Todos usam a mesma porta.
- **Alguns testes precisam de tela** (clique real, imagem, movimento) e tomam conta do mouse
  enquanto rodam — combine antes de rodar.
- **Uma pasta que não é do jogo precisa de um arquivo `.gdignore`**, senão o Godot tenta importá-la.

## Para saber mais

- [`../../VALIDACAO.md`](../../VALIDACAO.md) — o que a bateria cobre e o que não cobre
- [`../../AGENTES.md`](../../AGENTES.md) — como o trabalho é dividido entre agentes de IA
- [`../../NUMEROS_MEDIDOS.md`](../../NUMEROS_MEDIDOS.md) — o que já foi medido (antes de medir de novo)
