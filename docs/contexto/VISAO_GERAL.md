# Visão geral do projeto — para quem chega

> Para **pessoas** que vão trabalhar no SKILLS ONE PIECE pela primeira vez. A versão densa, para
> agentes de IA, é o [`PROJECT_CONTEXT.md`](../../PROJECT_CONTEXT.md). Escrito em 21/09/2026.
>
> Este texto não repete o panorama do jogo nem os controles: isso está no
> [`README.md`](../../README.md). Aqui está **como o projeto é organizado e como se achar nele**.

## Em uma frase

Um jogo de ação 3D inspirado em One Piece, feito em Godot 4.6.3 com GDScript, que roda em rede
(um computador é o servidor e decide o que vale; os outros pedem e mostram). Mesmo jogando
sozinho, o jogo sobe um servidor local — por isso o código é o mesmo nos dois casos.

## Os três jeitos de jogar

| modo | o que é | por onde começa no código |
|---|---|---|
| **Arena** | PvP com frutas do diabo, estilos de luta, espada e parkour. Ganha quem derruba o outro nos buracos | `Main.gd` |
| **Modo História** | campanha: nasce como Civil, sobe de nível, luta corpo a corpo num sistema inspirado em Chivalry 2 | `src/historia/ModoHistoria.gd` |
| **Editor de mapa** | monta os mapas do Modo História, no estilo do Roblox Studio | `src/editor_mapa/EditorDeMapa.gd` |

## Como o código está dividido

O projeto foi separado em **11 áreas**. Cada uma tem uma página curta para pessoas (esta
pasta, `pessoas/`) e outra densa para agentes (`agentes/`):

| área | do que cuida | página |
|---|---|---|
| Núcleo e jogador | o personagem que você controla: andar, pular, câmera, vida, rodada | [pessoas/nucleo.md](pessoas/nucleo.md) |
| Combate da arena | socos, combos, espada, estilos de luta, a tabela de dano | [pessoas/combate.md](pessoas/combate.md) |
| Frutas e técnicas | os poderes das Akuma no Mi (teclas Z, X, C, V) e seus efeitos | [pessoas/frutas.md](pessoas/frutas.md) |
| Personagem, rig e animação | como o boneco é montado, vestido e animado | [pessoas/personagem.md](pessoas/personagem.md) |
| Modo História | a campanha, o status (tecla M) e o combate direcional | [pessoas/historia.md](pessoas/historia.md) |
| Mundo e editor de mapa | a arena, os mapas em arquivo e o editor | [pessoas/mundo.md](pessoas/mundo.md) |
| Chefes e IA | o Boss (Buggy) e como ele decide | [pessoas/bosses.md](pessoas/bosses.md) |
| Rede e multiplayer | servidor, cliente, entrar numa partida | [pessoas/rede.md](pessoas/rede.md) |
| Interface e HUD | menus, barras, janela de status, controles de toque | [pessoas/interface.md](pessoas/interface.md) |
| Visual, VFX e áudio | o estilo de desenho (cel-shading), efeitos de tela, sons | [pessoas/visual.md](pessoas/visual.md) |
| Ferramentas, testes e pipeline | como provar que funciona e como produzir arte | [pessoas/ferramentas.md](pessoas/ferramentas.md) |

## Como achar um pedaço de código

Existe um **índice de busca** que responde "onde está o código de X?":

```bash
python3 tools/contexto/indice.py buscar "barra de vida"
python3 tools/contexto/indice.py buscar "por que tela cinza" --docs
```

Ele devolve arquivos e linhas, do mais parecido para o menos. Busca por palavra (não entende
sinônimo): se não achar, tente outra palavra. O mapa completo, com cada arquivo, a área e o quanto
ele pesa no projeto (★1 a ★5), está em [`INDICE.md`](INDICE.md).

## Cinco coisas que todo mundo tropeça

1. **Criou uma classe nova (`class_name`)?** Rode `./checar_cache.sh`, senão o jogo abre numa
   tela cinza sem mensagem nenhuma.
2. **"Abriu no editor" não prova que compila.** Quem prova é o teste `test_compila`.
3. **Dano quem decide é o servidor.** Um efeito bonito na sua tela não quer dizer que acertou.
4. **Nenhum arquivo passa de 900 linhas.** Passou, divide — ou escreve no topo quando vai dividir.
5. **Frente do personagem é o eixo −Z.** Metade dos bugs de animação vieram de esquecer isso.

A lista completa, com a história de cada tropeço, está em
[`../guia/ARMADILHAS.md`](../guia/ARMADILHAS.md).

## Como trabalhar aqui

- **Antes de mudar:** leia a página da área e o documento que ela indica. Muitas decisões já
  foram tomadas pelo dono do projeto e estão registradas com data.
- **Na dúvida sobre gosto ou escopo, pergunte.** Mudar a sensação de um golpe, apagar código que
  funciona ou inverter uma convenção é decisão do dono.
- **Achou um bug fora do que estava fazendo?** Anote em
  [`../LISTA_DE_CORRECOES.md`](../LISTA_DE_CORRECOES.md) em vez de consertar no meio de outra coisa.
- **Consertou um bug?** Escreva o motivo em [`../erros.md`](../erros.md). O conserto sem o motivo
  volta.
- **Antes de dizer "pronto":** `./validar.sh rapido`. Hoje (21/09) existem 8 testes que já falham
  por motivos conhecidos; o [`PROJECT_CONTEXT.md`](../../PROJECT_CONTEXT.md) §8 diz quais.

## Rodar

```bash
./jogar.sh            # arena
./jogar_historia.sh   # Modo História
./validar.sh rapido   # a bateria de testes
```

O Godot não está no PATH desta máquina: os scripts o encontram sozinhos (`./find_godot.sh`).

## Onde ler mais

| quero… | leia |
|---|---|
| entender o jogo e os controles | [`README.md`](../../README.md) |
| as regras de quem escreve código | [`../GUIA_DO_PROJETO.md`](../GUIA_DO_PROJETO.md) |
| saber o que já foi medido | [`../NUMEROS_MEDIDOS.md`](../NUMEROS_MEDIDOS.md) |
| saber o que está pedido e não feito | [`../FILA_DE_TAREFAS.md`](../FILA_DE_TAREFAS.md) |
| entender como o trabalho é dividido entre agentes | [`../AGENTES.md`](../AGENTES.md) |
