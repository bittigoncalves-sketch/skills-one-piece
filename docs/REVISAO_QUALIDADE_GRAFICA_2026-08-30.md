# Revisão e plano — qualidade gráfica

Data: 2026-08-30. Escopo desta etapa: diagnóstico e planejamento; **nenhuma
configuração visual do jogo é alterada por este documento**.

## Diagnóstico atual

O projeto já tem uma base visual coerente para o alvo declarado — cel-shading
anime/One Piece:

- Forward+; MSAA 2× e filtro de sombra direcional em qualidade 2;
- céu procedural, sol quente, contra-luz fria, névoa aérea, SSAO reduzido,
  tonemap Reinhard e glow HDR em `WorldEnv.gd`;
- contorno de silhueta e banda de luz por shader;
- materiais HDR para VFX via `FxUtil.brilho`, com glow deliberadamente limitado
  depois da medição que encontrou 3,0% da tela estourada numa skill isolada;
- sondas visuais existentes para captura, histograma, contorno e banda.

Isso elimina uma troca global de renderer como prioridade. Os gargalos agora
são qualitativos e por conteúdo, não a ausência de um estilo de render.

## Achados priorizados

| Prioridade | Achado | Impacto visual | Risco/custo |
|---|---|---|---|
| P0 | Não há orçamento de frame/GPU por perfil de dispositivo | Sem número, uma melhoria pode tornar celular injogável | baixo para medir |
| P1 | Arena majoritariamente feita de plano e caixas, com pouca variação de material/escala | Profundidade e identidade do cenário ficam abaixo de personagens e VFX | médio |
| P1 | VFX são criados em muitos arquivos e não têm níveis formais de qualidade | Combates múltiplos podem concentrar partículas/luzes | médio |
| P1 | O estilo de iluminação está globalmente calibrado, mas não há “zonas” de atmosfera | Todos os setores da arena têm a mesma leitura | médio |
| P2 | Materiais iluminados fora dos três grandes funis ainda podem escapar do cel | Inconsistência pontual de estilo | baixo/médio |
| P2 | Não há comparação visual automatizada entre PC, tablet e celular | Regressões por perfil passam despercebidas | médio |

## Plano de execução

### Fase A — baseline mensurável (primeiro)

**Em andamento (2026-08-30):** `tools/dev_tests/medir_qualidade_grafica.gd`
cria o baseline JSON por perfil. A sonda mede FPS, tempo de processo, draw
calls, objetos renderizados, luzes e partículas estimadas sem salvar a escolha
de dispositivo do jogador.

### Baseline coletado

Coleta feita em uma RTX 3050 Laptop, Vulkan/Forward+, janela X11 a ~144 Hz,
com 360 amostras na arena padrão. Os perfis abaixo são os presets do jogo;
**não substituem** uma coleta em hardware móvel real.

| perfil | FPS médio | ms/frame | draw calls | objetos | luzes | partículas |
|---|---:|---:|---:|---:|---:|---:|
| PC | 144,0 | 6,98 | 999 | 1.326 | 2 | 25 |
| tablet | 144,0 | 6,97 | 917 | 1.245 | 2 | 25 |
| celular | 143,9 | 6,96 | 861 | 1.188 | 2 | 25 |

O FPS está limitado pelo refresh da tela; draw calls e objetos são as medidas
mais úteis para comparar mudanças futuras nessa máquina.

1. Criar uma sonda de qualidade com três perfis: PC, tablet e celular.
2. Medir FPS/tempo de frame, quantidade de luzes dinâmicas, partículas vivas e
   draw calls em quatro cenas: arena vazia, corrida, duas skills simultâneas e
   ultimate com múltiplos jogadores.
3. Capturar as cinco cenas já usadas por `captura_visual.gd` em cada perfil.

**Portões:** PC 60 FPS sustentados; tablet 45 FPS; celular 30 FPS. Nenhuma
alteração pode aumentar o percentual de pixels estourados acima do baseline
atual nas cenas de combate.

### Fase B — leitura e identidade da arena

1. Criar três famílias de material cel: pedra clara, pedra gasta e borda/abismo.
2. Quebrar repetição de planos com decalques procedurais baratos: rachaduras,
   marcas de impacto e pequenas variações de cor, sem novas colisões.
3. Introduzir marcos visuais altos e simples (rochas, ruínas ou torres) que
   também ajudem a orientação competitiva.
4. Aplicar névoa/contraste por setores leves, preservando a leitura do buraco.

**Portões:** o jogador identifica a direção e bordas da arena em capturas de
6 m, 18 m e 45 m; sem reduzir contraste de silhueta nem clarear o abismo.

**Ajuste de leitura (2026-08-31):** as marcas lineares estáticas foram retiradas
da arena grande. Em distância elas viravam riscos escuros sem forma; a arena
fica com a variação de tom e volume dos blocos, enquanto marcas de impacto
temporárias continuam reservadas aos golpes.

### Fase C — biblioteca de VFX por custo

**Em andamento (2026-08-30):** `FxQuality.gd` centraliza os perfis. PC mantém
100%; tablet usa 90%/72%/55% e celular 80%/45%/28% para camadas
essencial/padrão/hero. `FxUtil.particles()` já aplica a política a todos os VFX
que passam pelo funil, e o fogacho da Buki também adapta partículas e luz.
Os grandes efeitos da Mera Mera foram marcados como `hero`, para o celular
reduzir a camada espetacular sem remover a sinalização principal do golpe.

`medir_qualidade_grafica.gd` aceita o argumento final `stress`: cria uma sonda
visual sintética com três VFX hero e dois padrões. Ela não instancia skills,
DamageZone, colisões, placar ou rede; compara apenas partículas, luzes e draw
calls de uma carga simultânea representativa. A coleta de estresse dura 90
quadros (~1,5 s), mantendo o pico visual na média em vez de diluí-lo em uma
coleta de arena de seis segundos.

| Perfil (RTX 3050, X11) | FPS médio | Draw calls médios | Luzes máximas | Partículas máximas |
| --- | ---: | ---: | ---: | ---: |
| PC | 138,7 | 549 | 5 | 2.425 |
| Tablet | 141,0 | 534 | 5 | 1.389 |
| Celular | 144,0 | 464 | 2 | 735 |

**Leitura:** tablet corta 43% e celular 70% das partículas do pico PC; o
celular também remove as três luzes hero. Dano, hitbox e telegraph essencial
não participam dessa política nem desse cenário de medição.

Classificação já aplicada: explosões e trilhas da Red Hawk, tempestade de
Suna no Sabaku, vento da Ice Age, cinzas do Malevolent Shrine e bruma do
Mamaragan são `hero`; a chama de `BurnStatus` é `essencial`. Os demais VFX
passam por `padrão` até receberem uma classificação específica.
As luzes hero da Red Hawk e do Entei seguem a mesma regra: permanecem no PC e
tablet, mas não são instanciadas no celular.

1. Formalizar três níveis: essencial (celular), padrão (tablet) e hero (PC).
2. Padronizar limites de partículas, duração, luzes sem sombra e distância de
   visibilidade para cada tipo de impacto, projétil, carga e ultimate.
3. Reaproveitar materiais e meshes procedurais onde o efeito é repetido.
4. Garantir que telegraphs de combate (como a aura da Observação) tenham cor,
   escala e duração próprias, sem competir com dano e com os elementos da HUD.

**Portões:** duas ultimates e quatro projéteis simultâneos mantêm a meta de
frame de cada perfil; telegraphs continuam legíveis no histograma e em captura
com o contorno ativado.

### Fase D — acabamento dos personagens

**Primeira entrega (2026-08-31):** a prévia da aba Customização agora usa uma
base discreta, luz principal quente e luz de recorte fria. Isso separa cabelo,
asas e acessórios escuros da arte de fundo, sem alterar o modelo que vai para a
partida. A pedra gasta ganhou variação tonal tridimensional de apenas 2,8% no
shader cel; a mudança não cria riscos, texturas, colisores nem draw calls.
Na arena PC a medição normal ficou em 626 draw calls nesta coleta.

1. Auditar todos os materiais iluminados fora de `MapBuilder`, `VoxelMeshes` e
   `TreeAndFruitGenerator`; migrar somente os que aparecem de modo recorrente.
2. Padronizar separação de silhueta em acessórios, armas e transformações.
3. Criar uma tabela de paleta por fruta para impedir que efeitos distintos
   tenham saturação/brilho indistinguíveis.

**Portões:** nenhuma malha recorrente usa material realista fora do cel sem
justificativa; armas e personagens permanecem reconhecíveis contra céu, chão e
VFX intensos.

## Ordem recomendada

`Fase A → Fase B → Fase C → Fase D`.

Começar pela arena depois de medir é a melhor relação de impacto por risco: ela
ocupa a maior parte da tela e melhora toda luta sem aumentar dano, partículas ou
complexidade de rede. A Fase C vem depois para garantir que o ganho de riqueza
visual não custe estabilidade de frame.

### Primeiro item da Fase B (em andamento)

A primeira intervenção é a variação procedural discreta de pedra no material
do chão. Ela acontece no mesmo shader cel e em espaço de mundo, portanto não
adiciona texturas, colisões, nós ou draw calls. A grade funcional permanece por
cima; o ruído é interpolado (sem quadrados bruscos) e sua intensidade é limitada
a 5,5% para não virar ruído visual competitivo.

**Validação:** a captura da cena principal manteve 0,0% de pixels estourados;
o perfil PC mediu 998 draw calls após a primeira versão da intervenção, contra
999 no baseline (diferença de amostragem, sem custo estrutural adicional).

### Entregas da arena — 2026-08-30

- Pedra clara do piso com variação orgânica em shader, sem textura adicional;
- três tons reaproveitados e variação tonal suave de pedra gasta nos blocos;
- bordas visuais escuras para todos os abismos, em uma MultiMesh sem colisão;
- marcas lineares estáticas retiradas após falharem no teste de leitura à
  distância.

Após as duas últimas entregas, a arena mediu **684 draw calls** no perfil PC,
abaixo do baseline de 999. A queda vem do reaproveitamento das três receitas de
material dos blocos; não deve ser lida como ganho generalizável de GPU até uma
coleta em outra máquina.

## Restrições que devem permanecer

- Não aumentar glow global sem repetir o teste de pixels estourados.
- VFX unshaded que precisam brilhar continuam usando `FxUtil.brilho`; emissão
  sozinha não cruza o limiar de glow nesta base.
- Luz dinâmica de VFX continua sem sombras, salvo caso hero medido.
- Não usar névoa de altura para esconder o abismo; a névoa clara já tornou o
  poço visualmente enganoso no passado.
- Toda alteração entra com captura antes/depois e resultado por dispositivo.
