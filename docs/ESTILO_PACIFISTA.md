# Estilo de combate PACIFISTA (PX)

O estilo reproduz o arsenal dos Pacifistas de *One Piece* como um kit ofensivo:
laser sustentado no Z, sequência de braços no X e uma salva convergente de três
emissores no V. Os lasers do estilo usam **amarelo com núcleo amarelo-claro** para
ter uma identidade visual única e consistente.

| Tecla | Golpe | Arquivo |
|---|---|---|
| **Z** | PX Laser Beam — feixe sustentado jogador → alvo | `src/combat/laser_px.gd` |
| **X** | PX Iron Punches — seis braços clonados | `src/combat/socos_de_ferro.gd` |
| C | Thruster Boost atual; substituição ofensiva em estudo | `FightingStyles._cast_laser` |
| **V** | PX Tri-Beam Annihilation — três emissores convergentes | `src/combat/px_tri_beam.gd` |

## Base visual dos lasers

### Causa raiz do laser vertical

A gravação mostrou uma coluna voltada para a câmera mesmo quando o transform do
cilindro indicava a direção correta. A causa determinante não era apenas o fato de
o `CylinderMesh` nascer no eixo Y: o material de partículas aplicado à malha usava
`BILLBOARD_PARTICLES`. Assim, depois dos cálculos da CPU, a GPU girava o cilindro
para encarar a câmera e destruía visualmente o alinhamento jogador → alvo. Por isso
testes que verificavam só vetores e transforms podiam passar sem produzir mudança
visível no jogo.

A correção ficou centralizada em duas peças:

- `FxUtil.mesh_emissive_material()` cria materiais 3D emissivos com
  `BILLBOARD_DISABLED`. `particle_material()` continua reservado às partículas
  que realmente devem encarar a câmera.
- `BeamVisual3D` posiciona um `CylinderMesh` exatamente no ponto médio do segmento,
  usa seu eixo Y como `inicio → fim` e registra as duas pontas para validação. O
  caso vertical e segmentos degenerados também são tratados pelo helper.

Z, os rastros do X, as guias e os três feixes do V usam essa mesma base. Isso evita
que cada golpe volte a resolver orientação, comprimento e material de uma forma
diferente. Halos, núcleos, cargas e impactos seguem a paleta amarela do estilo.

## Z — PX Laser Beam

O Z nasce no peito do jogador e termina no primeiro alvo ou obstáculo encontrado
pela mira. Como a direção original vem de um raio da câmera, a implementação
primeiro recupera o ponto mirado e então constrói um novo segmento do jogador até
esse ponto. Isso elimina a reta paralela que podia passar ao lado do alvo quando o
visual começava em uma origem diferente da usada pela mira.

O visual possui halo amarelo, núcleo amarelo-claro, clarão de saída, impacto na
ponta e três pulsos luminosos viajando **do jogador para o alvo**. As duas camadas
do feixe têm suas pontas atualizadas explicitamente a cada quadro e são encurtadas
na primeira parede.

Segurar Z mantém o laser ativo por no máximo **3 s**. A cada **0,20 s**, uma cápsula
de dano cobre o segmento inteiro; são 15 pulsos possíveis. O dano declarado do
slot é o valor da sustentação completa e é dividido entre os pulsos: soltar antes
reduz proporcionalmente o dano, sem ultrapassar o teto de balanceamento do slot.
O nó é filho do jogador, então acompanha sua rotação durante a sustentação.

Na rede, a confirmação autoritativa do cast sobe `px_laser_ativo` em cada cópia
antes de criar o nó. Assim o servidor mantém a zona de dano e os observadores
recebem o mesmo feixe; soltar Z transmite o cancelamento para todos.

> Se for preciso rebalancear o Z, altere o `dano` do slot em
> `FightingStyles.STYLES["pacifista"]`. A fração por pulso em `laser_px.gd` não é
> uma segunda fonte de balanceamento.

## X — PX Iron Punches

O X duplica o braço do próprio personagem, preservando suas proporções e aparência,
e dispara **seis clones**, alternando direita e esquerda. O braço original nunca
some. Acessórios que não pertencem ao golpe (`BukiArma_*` e `MeraPistol_*`) são
removidos dos clones para não serem replicados junto com os socos.

A coreografia foi ampliada para permanecer legível em vídeo:

- **0,18 s de antecipação** antes do primeiro braço;
- um novo braço a cada **0,10 s**, permitindo 2–3 clones simultâneos;
- abertura lateral de **0,30 m em 0,06 s**, alternada por lado, para os braços não
  nascerem escondidos atrás do corpo;
- avanço de **2 m em 0,24 s**, com destaque emissivo amarelo, clarão de partida e
  rastro amarelo de **0,46 m** sem billboard;
- **0,10 s de resolução** no alcance máximo antes de o clone desaparecer.

Cada clone leva sua própria zona de dano durante o avanço. O destino continua a
exatos 2 m da origem apesar da abertura lateral. O braço desaparece no fim em vez
de retornar, pois o caminho de volta atravessaria o alvo novamente e poderia gerar
um segundo acerto indevido.

## V — PX Tri-Beam Annihilation

O V usa os três emissores associados aos Pacifistas: boca, palma esquerda e palma
direita. O ponto de impacto é travado pelo raio original da mira no início do cast,
com alcance máximo de **26 m**. Quando o rig está disponível, as posições das mãos
são calculadas nas pontas reais dos antebraços; o fallback mantém os emissores
visualmente separados.

A animação segue três fases claras:

1. **Carga — 0,65 s:** três orbes amarelos pulsam com fases diferentes na boca e
   nas palmas. Nos 30% finais, três guias finas revelam antecipadamente o ponto de
   convergência. As cargas ignoram apenas a oclusão do próprio corpo para não
   desaparecerem atrás do personagem na câmera sobre o ombro.
2. **Disparo — 0,42 s:** três feixes completos, cada um com halo e núcleo, ligam os
   emissores ao mesmo ponto. As três cargas permanecem como bocas de fogo e os
   halos foram afinados para as linhas não se fundirem. Essa duração mantém o
   ataque visível por pelo menos 12 quadros a 30 fps, em vez de um clarão isolado.
3. **Resolução — 0,38 s:** os feixes desaparecem e o impacto termina de expandir.
   Esfera externa, núcleo luminoso e anel crescente dão volume e paralaxe à
   explosão amarela.

O impacto aplica uma única zona de dano de raio **4,5 m**. Os emissores são
canônicos; o disparo simultâneo é uma adaptação de gameplay para transformar o
arsenal no ultimate do estilo.

## Pesquisa — direção ofensiva para o C

Fontes consultadas e revisadas em 2026-09-02:

- [perfil oficial japonês do Pacifista](https://one-piece.com/character/Pacifista/index.html):
  confirma que o armamento possui lasers de Kizaru em três pontos — boca e duas
  mãos;
- [episódio 402 no site oficial](https://one-piece.com/anime/402/index.html):
  registra o Pacifista disparando feixes repetidamente durante o combate em
  Sabaody;
- [episódio 1094 no site oficial](https://one-piece.com/anime/65678/index.html):
  descreve uma sequência de ataques fortes de laser, reforçando que rajada e
  varredura são direções ofensivas compatíveis com o repertório;
- [visão geral dos Pacifistas](https://onepiece.fandom.com/wiki/Pacifista): reúne
  força física, movimentação, lasers perfurantes/explosivos e o Bubble Shield de
  resina dos Mark III;
- [referência dos lasers de Vegapunk](https://onepiece.fandom.com/wiki/Laser):
  cataloga disparos pelas palmas e pela boca e a explosão no impacto.

O repertório ofensivo dos modelos de produção se concentra em **força física,
avanços/saltos e lasers inspirados em Kizaru**. Eles não possuem a Nikyu Nikyu no
Mi de Kuma. Como o pedido para C é especificamente um ataque, o Bubble Shield fica
fora das propostas apesar de existir nos Mark III.

### Alternativas ofensivas

1. **PX Laser Sweep — recomendado:** uma palma dispara enquanto o jogador finca os
   pés e varre um arco horizontal. É controle ofensivo de área, tem leitura clara
   e não repete o Z (linha sustentada) nem o V (três linhas convergentes).
2. **PX Meteor Stomp:** salto curto seguido de uma aterrissagem de grande massa,
   com dano no centro e onda de impacto ao redor. Usa a força e a capacidade de
   salto dos Pacifistas; a onda é uma adaptação de gameplay, não um golpe nomeado.
3. **PX Pursuit Barrage:** avanço pesado acompanhado por disparos alternados de
   boca e palma. É uma adaptação de gameplay que transforma velocidade e lasers
   em pressão frontal, mas precisa de direção travada para continuar justa em PvP.
4. **PX Berserk Barrage:** sequência curta de lasers em leque, inspirada no PX-4
   danificado disparando sem precisão. Tem grande presença ofensiva, porém leitura
   menos previsível e maior risco de poluição visual.

O **Laser Sweep** continua sendo a melhor escolha para C: completa o kit com ataque
em área lateral sem inventar uma Akuma no Mi e sem competir visualmente com o V.
O **Ursus Shock** não é recomendado, porque depende da Nikyu Nikyu no Mi de Kuma
(e do S-Bear), não do equipamento dos Pacifistas produzidos em série.

## Validação

A validação cobre geometria, configuração de renderização e quadros capturados,
não apenas a direção lógica:

```sh
godot --headless --path . -s tools/dev_tests/test_beam_visual_3d.gd
godot --headless --path . -s tools/dev_tests/test_laser_px.gd
godot --headless --path . -s tools/dev_tests/test_pacifista_z_gate_rede.gd
godot --headless --path . -s tools/dev_tests/test_socos_de_ferro.gd
godot --headless --path . -s tools/dev_tests/test_px_tri_beam.gd
godot --headless --path . -s tools/dev_tests/test_balance.gd
```

As verificações incluem pontas do segmento, material sem billboard, paleta amarela,
projeção do Z até o alvo, sustentação e pulsos de dano, seis braços com alcance de
2 m, sobreposição e rastros, gate autoritativo do Z, três cargas separadas, três
feixes convergentes, duração mínima do V e dano único da explosão.

Para comparar o resultado visual em uma janela de 1286×730:

```sh
DISPLAY=:1 godot --path . --resolution 1286x730 \
  -s tools/dev_tests/capturar_pacifista_visual.gd
```

O roteiro grava quadros determinísticos de Z sustentado, sobreposição do X, carga,
disparo e impacto do V em `/tmp/skills-one-piece-pacifista-visual`. No V ele espera
as flags reais de cada fase; o slow-motion da ultimate não altera o quadro escolhido.
