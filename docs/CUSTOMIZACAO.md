# Customização — acessórios e cor

Menu novo no menu inicial, pedido pelo dono em 2026-08-27.

- [`src/ui/CustomizacaoMenu.gd`](../src/ui/CustomizacaoMenu.gd) — a tela
- [`src/customizacao/Acessorios.gd`](../src/customizacao/Acessorios.gd) — o catálogo
- [`src/customizacao/Paleta.gd`](../src/customizacao/Paleta.gd) — as cores
- `tools/dev_tests/medir_customizacao.gd` — 17 conferências

---

## A tela

Fundo azul; à esquerda as categorias (**Acessórios**, **Raça**, **Corpo**,
**Cor**), no centro o personagem em 3D, à direita os itens da categoria escolhida.
Escolher um item equipa na hora.

O personagem **não gira sozinho** — gira quando o jogador **arrasta com o botão
esquerdo**. Giro automático atrapalha justamente o que o menu existe para fazer:
comparar duas opções. Quando ele nunca para, cada escolha aparece num ângulo
diferente e a comparação vira memória.

A câmera fica no **−Z**, mostrando o ROSTO: o personagem olha para −Z (convenção
do projeto, ver [`DIRECOES.md`](DIRECOES.md)), e pôr a câmera no +Z mostrava as
costas. O giro lento leva as costas ao quadro sozinho, para quem quer ver as asas.

---

## Raças

Oito, em [`src/customizacao/Racas.gd`](../src/customizacao/Racas.gd): Skypiean
(asas), Oni (chifres), Sharkman (barbatana), Braços Longos, Pernas Longas,
Palhaço (nariz), Mink Coelho (orelhas + rabinho quadrado) e Mink Lobo (orelhas e
rabo **na cor do personagem**).

### Por que raça não é acessório

| | acessório | raça |
|---|---|---|
| exclusão | por **parte do corpo** | **global** — ninguém é Oni e Sharkman |
| efeito | acrescenta peça | acrescenta peça **ou muda escala** |
| desfazer | apagar a malha | apagar a malha **ou devolver a escala** |

A escala precisa de desfazer próprio: a original é guardada na aplicação e
devolvida na remoção. E é guardada de verdade, não assumida como `Vector3.ONE` —
este rig nasce com escala 1,8, e devolver ONE deformaria o corpo.

### Medidas relativas, nunca em metros

Toda peça é descrita como **fração da caixa do nó de destino**: `ancora` em 0..1
dentro da AABB, `tam` como fração do tamanho dela. Mesmo princípio do chapéu, e
pelo mesmo motivo — o modelo da prévia tem a cabeça 0,50 × 0,50 × **0,40**, e o
de jogo tem **0,74** de profundidade. Número em metros quebraria num dos dois, em
silêncio.

Na âncora, **z = 0 é a FRENTE** (o personagem olha para −Z e a AABB começa no
menor z). Por isso o nariz do palhaço tem `z = 0` e os rabos têm `z = 1`.

### ⚠️ Escala em cadeia MULTIPLICA

`ForeArm` é filho de `UpperArm`; `Shin` é filho de `Thigh`. Escalar os dois níveis
compõe: medido, a escala global do antebraço ia de 1,80 para **4,32**
(= 1,80 × 1,55 × 1,55) e o braço virava um borrão maior que o corpo.

Só o topo de cada cadeia entra na tabela — o resto herda o alongamento na medida
certa, que é para o que a hierarquia serve.

**E a bateria passava com o bug**, porque só olhava a escala LOCAL do ombro, que
estava correta. Quem denuncia é a escala **global** da ponta da cadeia, e é essa
a asserção que existe hoje:

```
escala GLOBAL do antebraço: 1.80 → 2.79 (fator 1.55×)
✓ o alongamento NÃO compõe pela hierarquia
```

### A cor do Mink Lobo

As peças dele nascem **sem material**, marcadas com `segue_cor`. Quem pinta o
corpo pinta elas junto — é o que faz orelhas e rabo acompanharem a cor escolhida.
As demais têm cor própria: chifre de Oni não fica azul porque o jogador escolheu
azul.

### O que fica registrado como limitação

**Braços Longos quase não muda a silhueta.** Mecanicamente funciona (1,55×,
medido), mas num personagem de UMA cor os braços alongados encostam no tronco e
se fundem com ele. É fato sobre a arte, não sobre o código — e some sozinho
quando houver roupa ou cor de membro separada.

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

## Corpo — os olhos

Três tamanhos em [`src/customizacao/Corpo.gd`](../src/customizacao/Corpo.gd).

⚠️ **Interpretação declarada:** o pedido dizia *"olho grande, médio e grande"* —
"grande" duas vezes. Como são três opções de TAMANHO, tratei como **pequeno,
médio e grande**. Se a intenção era outra (três formatos, por exemplo), é trocar
a tabela: a mecânica não muda.

Os três eixos são **independentes**: escolher o olho não tira a raça nem o
chapéu. Cada catálogo decide o que a sua própria escolha exclui.

---

## `Adornos` — o núcleo comum

Três sistemas pediam a mesma mecânica (pendurar peça por fração da caixa, trocar
por exclusão, mudar e desfazer escala, peça que segue a cor). Com **três** users
a duplicação virou fato medido, e o núcleo subiu para
[`src/customizacao/Adornos.gd`](../src/customizacao/Adornos.gd).

**O que NÃO subiu: a regra de exclusão.** Ela é diferente em cada um — acessório
exclui por parte do corpo, raça exclui globalmente, olho exclui outro olho — e
forçar as três num molde só criaria um parâmetro que ninguém entende. Ali só mora
o *como* apagar; o *o quê* fica em cada catálogo.

As peças usam `Materiais.superficie` (o cel shading do jogo), não
`StandardMaterial3D` avulso: peça com material padrão fica lisa e brilhante ao
lado de um corpo chapado, e denuncia que foi colada depois. O corpo da prévia usa
o mesmo — a prévia existe para decidir como vai ficar EM PARTIDA, e com outra
iluminação ela mentiria.

---

## O menu principal cabia por 6 px

Acrescentar o botão de CUSTOMIZAÇÃO fez o conteúdo somar **831 px numa tela de
720**: o botão de CONFIGURAÇÕES ficava INTEIRAMENTE fora, e nada avisava. Menu
não tem teste, não trava a bateria e não gera erro — quebra em silêncio.

Botões, margens, separações e logo foram reduzidos até caber com folga. E entrou
`tools/dev_tests/medir_menu_principal.gd`, que varre todo `Control` e reprova se
algum passar da tela. Provado que sabe reprovar: com botões de 140 px ele acusa
14 controles fora.

---

## Acessórios — seis, modelados no Blender

[`tools/blender/acessorios.py`](../tools/blender/acessorios.py) gera cinco
(chinelo, capa da Marinha, colete e calção do Luffy, as 3 espadas do Zoro); o
chapéu tem script próprio. Só caixas, como o resto do jogo.

**As medidas saem da AABB dos nós do rig**, não de metros — `Torso` 0,500 ×
0,750 × 0,360, `Foot` 0,250 × 0,125 × 0,400. Cada modelo tem a origem no ponto de
encaixe, então posicionar é multiplicar pela âncora, sem compensar meia altura.

### Três defeitos que só apareceram montando

**1. Partes diferentes, MESMO nó.** "tronco", "costas", "cintura" e "pernas"
penduram todas no `Torso`. Como a limpeza varria o nó inteiro por prefixo,
equipar as espadas **apagava o colete** — e a bateria passava, porque só testava
uma parte de cada vez. O nome da peça passou a carregar a parte
(`Acessorio_<parte>_<id>_<i>`), e entrou a asserção que faltava: quatro peças no
mesmo nó têm de conviver.

**2. Material do Blender numa cena de cel shading.** O `.glb` traz um PBR comum,
que fica liso e escurece na sombra: o colete vermelho saía como duas tiras
marrons. Ao equipar, o material de cada superfície é trocado por
`Materiais.superficie(cor_do_modelo)` — preserva a arte e faz a peça pertencer à
cena.

**3. O menu não cabia na tela.** Com seis acessórios a lista da direita levou o
menu a **1.022 px numa tela de 720**: o viewport 3D ficou com 818 px de altura e
só a parte de cima aparecia. Parecia defeito de CÂMERA e era de LAYOUT. A lista
passou a rolar, e há asserção contra a volta.

---

## Enquadramento: dois erros de conta

**Espaço errado.** `_caixa_visual` convertia para o espaço do MODELO e devolvia
3,6 de altura — mas o rig tem escala interna e o corpo mede 6,48 no MUNDO, que é
onde a câmera está. A distância saía pela metade e o enquadramento pegava só a
cabeça.

**Não era idempotente.** A versão anterior deslocava o modelo para centrar o
alvo — e cada chamada subtraía de novo, acumulando deriva. Como agora
`_enquadrar` roda a cada troca de raça e acessório, isso empurrava o personagem
para longe a cada clique. Hoje a mira usa o eixo do modelo em X/Z e a altura do
centro da caixa em Y: chamar dez vezes dá o mesmo que chamar uma, e há teste.

---

## Tons de pele

`Paleta.PELES`, sete tons — **lista separada** de `Paleta.CORES`. As cores de
TIME dizem de quem é o corpo numa partida e `Player.cor_idx` as indexa; misturar
pele nelas mudaria o significado de um índice que a rede já transmite. Os dois
grupos são exclusivos entre si: é uma cor de corpo só.

---

## O que ainda NÃO existe

**A escolha não vai para a partida.** O menu equipa no personagem da PRÉVIA; não
há persistência nem aplicação no jogador em jogo. O pedido descrevia a tela, e
parar aqui é deliberado — levar para a partida envolve decidir onde a escolha é
guardada e como ela viaja em rede, que são decisões do dono.

**As espadas do Zoro leem pequenas.** Estão na cintura e aparecem, mas de longe
viram um risco escuro. É calibragem de arte, não defeito de encaixe.
