# Contextos do projeto

Contexto curto por público e por área, mais um índice de busca do código. Criado em 21/09/2026.

| arquivo | para quem | o quê |
|---|---|---|
| [`../../PROJECT_CONTEXT.md`](../../PROJECT_CONTEXT.md) | agentes de IA | regras, ambiente, arquitetura, estado atual, validação (150–300 linhas) |
| [`VISAO_GERAL.md`](VISAO_GERAL.md) | pessoas | como o projeto se organiza e como se achar nele |
| `agentes/<area>.md` | agentes de IA | escopo, arquivos-chave, contratos, armadilhas, testes e buscas prontas da área |
| `pessoas/<area>.md` | pessoas | o que a área faz, onde mexer para cada tarefa comum, cuidados |
| [`INDICE.md`](INDICE.md) | os dois | **gerado**: cada arquivo `.gd` com área, linhas, relevância ★1–5, fan-in, testes e resumo |

Áreas: `nucleo` · `combate` · `frutas` · `personagem` · `historia` · `mundo` · `bosses` · `rede` ·
`interface` · `visual` · `ferramentas`.

## O índice vetorial

```bash
python3 tools/contexto/indice.py buscar "consulta" [-n 10] [--area X] [--docs | --sem-docs] [--testes]
python3 tools/contexto/indice.py construir     # refaz o índice e o INDICE.md
python3 tools/contexto/indice.py verificar     # caminhos mortos e contextos velhos
```

- **Como busca:** TF-IDF por trecho (cada função do GDScript, cada seção do Markdown), com
  identificadores partidos, acentos removidos e terminações do português reduzidas. Só biblioteca
  padrão do Python; o cache fica em `tools/contexto/.cache/` (fora do git e do Godot) e se refaz
  sozinho quando algum arquivo muda (~1,5 s).
- **Limite:** acha por palavra, não por sentido. "defesa" não acha "guarda" — busque as duas.
- **Relevância ★1–5** (fórmula no topo do `INDICE.md` e de `tools/contexto/indice.py`): quanto o
  resto do jogo depende do arquivo, o tamanho, quantos testes o vigiam e se é porta de entrada.

## Regras de manutenção

1. **Nada que muda sozinho é escrito à mão.** Lista de arquivos, linhas e relevância vêm do
   índice. Os contextos guardam o que é estável: propósito, contratos, armadilhas, onde ler.
2. **Detalhe tem um dono.** Contexto aponta para o documento dono (`frutas/README.md`,
   `combat/README.md`, `MODO_HISTORIA.md`…) em vez de copiar tabela. É a lição do
   `DOCUMENTACAO.md`, apagado em 12/09 por divergir do `README.md`.
3. **Mudou uma área?** Atualize `agentes/<area>.md` e `pessoas/<area>.md` na mesma tarefa quando
   mudar contrato, arquivo-chave ou armadilha. `verificar` acusa quando o código da área ficou mais
   novo que o contexto (é um lembrete, não um veredito: nem toda mudança exige reescrever).
4. **Pasta nova em `src/`?** Some a regra de área em `AREAS` no `tools/contexto/indice.py` e a
   linha na tabela do `PROJECT_CONTEXT.md` §5.
