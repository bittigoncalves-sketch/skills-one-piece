# Customização — acessórios e cor

Menu novo no menu inicial, pedido pelo dono em 2026-08-27.

- [`src/ui/CustomizacaoMenu.gd`](../src/ui/CustomizacaoMenu.gd) — a tela
- [`src/customizacao/Acessorios.gd`](../src/customizacao/Acessorios.gd) — o catálogo
- [`src/customizacao/Paleta.gd`](../src/customizacao/Paleta.gd) — as cores
- `tools/dev_tests/medir_customizacao.gd` — 17 conferências

---

## A tela

Fundo azul; à esquerda as categorias (**Acessórios**, **Cor**), no centro o
personagem em 3D, à direita os itens da categoria escolhida. Escolher um item
equipa na hora.

---

## Onde mora a regra da exclusão mútua

O pedido era: *dois acessórios da mesma parte do corpo não convivem — equipar o
novo tira o antigo sozinho.*

**Essa regra não está no menu.** Ela mora no catálogo, no campo `parte` de cada
acessório, e quem a aplica é o `Acessorios.equipar`. Duas consequências:

1. um acessório novo entra **sem ninguém mexer no menu**;
2. o **Gear 2**, que também veste o chapéu, obedece à mesma regra de graça — sem
   isso a transformação empilharia um segundo chapéu na cabeça de quem já
   equipou um pelo menu.

`desequipar` varre **por prefixo** (`Acessorio_`), não pela lista do catálogo:
procurar só os ids conhecidos HOJE deixaria órfão inarredável qualquer peça
equipada por um catálogo antigo — e órfão numa parte do corpo é justamente o que
a exclusão mútua existe para impedir.

---

## Três coisas que quebraram e o que ensinam

**O viewport precisa de mundo próprio.** Sem `own_world_3d = true` ele
compartilha o mundo da cena: a arena inteira apareceria atrás do personagem e a
luz do menu vazaria para o jogo.

**Enquadrar no `_ready` mede a hierarquia em repouso.** `_caixa_visual` lê
`global_transform` de cada malha, e o Godot só propaga as transformações depois
que a árvore processa. Enquadrando cedo demais, a câmera nasceu **dentro do
tronco** e a tela virou uma parede verde. A moldura passou a ser calculada no
quadro seguinte — e é calculada, não fixa: a caixa do modelo decide a distância,
então trocar de personagem continua enquadrando.

**Ler três cores do `Player` arrastava os autoloads.** `Player.CORES` obrigava o
menu a depender do script de 2.400 linhas e, com ele, do autoload `FruitNet`:

```
SCRIPT ERROR: Compile Error: Identifier not found: FruitNet
```

O erro não era sobre cor nenhuma — era sobre uma tela de menu ter virado
dependente da classe mais pesada do projeto para ler **dado**. A paleta saiu para
`Paleta.gd` e `Player.CORES` virou apelido dela: os usos existentes não mudaram e
a fonte continua sendo uma só.

---

## O que ainda NÃO existe

**A escolha não vai para a partida.** O menu equipa no personagem da PRÉVIA; não
há persistência nem aplicação no jogador em jogo. O pedido descrevia a tela, e
parar aqui é deliberado — levar para a partida envolve decidir onde a escolha é
guardada e como ela viaja em rede, que são decisões do dono.

**Um acessório só.** O catálogo tem o chapéu de palha. A estrutura (parte, nó,
fração de encaixe) já suporta mais; falta conteúdo, não código.
