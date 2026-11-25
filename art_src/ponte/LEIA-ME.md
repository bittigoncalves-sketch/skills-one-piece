# Ponte de madeira low poly (rio em S)

Asset autoral em metros: caixa **6,0 × 6,7 × 34,0** (X × Y × Z), **4.972 triângulos**, seis materiais foscos, normais planas, sem UV. Fonte: `ponte_rio.blend`; gerador determinístico: `tools/blender/ponte_rio.py`. O GLB tem duas malhas. A visual, `Ponte_rio_low_poly`, tem 121 sólidos fechados e 6 materiais. A outra é **`Colisao`**, de 396 triângulos e com material próprio, invisível no jogo (ver abaixo).

## Medidas (coordenadas do Godot)

- **Origem** (0, 0, 0) = centro da ponte, na altura das pontas do deck. Comprimento em **Z**, largura em **X**.
- **Caixa:** X −3,0 a +3,0 · Y −3,2 a +3,5 · Z −17,0 a +17,0. Centro da caixa = (0; 0,15; 0).
- **Pontas do deck a 3,2 m do fundo da caixa.** Este é o número para assentar a ponte no barranco: o fundo dos cavaletes (y = −3,2) fica 3,2 m abaixo do topo do barranco.
- **Deck:** y = 0 em z = ±17 e y = +2,4 em z = 0. O arco tem 16 trechos retos de 2,125 m sobre um perfil cosseno, tangente ao chão nas pontas e plano no topo. A inclinação máxima é **12,2°** (trechos entre |z| = 6,4 e 10,6).
- **Superfície caminhável: lisa** (versão de 01/10/2026). O colisor do jogador é uma caixa de fundo reto e não sobe degrau nenhum, então o deck é UMA laje de 10 cm, com o topo exatamente na linha do arco. As 64 tábuas de 0,53 m aparecem só pela cor: faixas alternadas que compartilham os vértices da costura, sem degrau, fresta ou face vertical. As pontas irregulares de cada tábua ficam em |x| ≥ 2,54, fora do vão útil e além dos postes. Lá a largura muda numa transição de 2 cm no fim de cada tábua.
- **Vão útil:** 4,36 m entre as faces internas dos postes (4,38 m entre os pilares das pontas). As tábuas avançam ~0,2 m para fora dos postes, com as pontas irregulares.
- **Guarda-corpos:** contínuos, de pilar a pilar, abertos só nas pontas. São 15 postes de 0,22 m por lado, a cada 2,125 m. O corrimão fica com o topo 1,10 m acima do deck (y = 3,5 no meio). A corda (Ø 7 cm) passa a 0,55 m do deck e cede 3,5 % de cada vão.
- **Cavaletes:** três, em z = −6,375, 0 e +6,375. Cada um tem 4 pernas de 0,28 m, sendo as externas inclinadas de x = ±2,75 no leito até ±2,08. Por cima, uma travessa de 6,0 m. Em y = −1,25 há uma travessa baixa na face −Z, e a face +Z leva uma cruz de São André. Completam o cavalete 4 mãos-francesas no plano lateral (o "leque" da silhueta) e 2 escoras externas até os postes. O fundo de todas as pernas está exatamente em y = −3,2, e nada desce além disso.
- **Cabeceiras:** de pedra, de |z| = 13 a 17. São três fiadas recuadas, com a frente em |z| = 13,00, 13,12 e 13,24. A base fica em y = −2,5, e o capeamento 7 cm abaixo do deck, sob as tábuas, que seguem em madeira até a ponta. As longarinas entram 21 cm na pedra. Cada cabeceira tem 2 pilares de 0,58 m em x = ±2,48, |z| = 16, com capitel piramidal (topo ≈ deck + 1,50).

## Colisão (`Colisao`, versão de 01/10/2026)

A loja usa como colisão SÓ a malha cujo nome começa com `Colisao`; ela fica invisível e fora da caixa envolvente. Antes dela, o trimesh do modelo inteiro travava a caixa do jogador (1 × 1,6 × 1 m, fundo reto) no meio do deck: a aresta de cima de uma travessa, do capeamento ou de uma longarina que encostasse no plano do piso virava uma parede de altura zero. Agora a colisão tem três sólidos fechados e nada mais:

- **Piso:** x ∈ [−2,2; 2,2], z ∈ [−17; 17], 0,30 m de espessura. O topo é a mesma linha poligonal do deck visual, nos 17 vértices do arco; as estações intermediárias do visual são colineares a ela. No interior do topo não há nenhum vértice: só as faces do topo, as laterais, o fundo e as tampas das pontas.
- **Paredes:** |x| de 2,20 a 2,35, de z = −16,29 a +16,29 (até a face externa dos pilares), abertas nas pontas. Vão do fundo do piso até 1,10 m acima do deck, seguindo o arco, e o topo delas coincide com o do corrimão. A face interna é inteira, sem vértice na altura do piso.
- Cavaletes, cabeceiras, cordas, pilares e o resto ficam só visuais.

Medido em `medidas.json` → `colisao`:
- 3 ilhas, nenhuma com volume negativo, 0 arestas abertas;
- 0 vértices no interior do topo;
- o topo coincide com o deck visual com diferença máxima de **0,0038 mm** (146.200 raios em x ∈ [−2,1; 2,1], z a cada 1 cm), e a menor normal.y é 0,9774.

## Materiais

Mesma paleta linear do kit medieval da loja: `Wood`, `Wood_Light`, `Stone`, `Stone_Light`. Principled só com cor base e rugosidade 0,92, sem textura. **`doubleSided: false`**, como no kit: todas as peças são fechadas, e uma face invertida apareceria como buraco em vez de ficar mascarada.

| material | cor (linear) | uso |
|---|---|---|
| Madeira_Escura | 0,25 0,14 0,05 | estrutura, postes |
| Madeira_Clara | 0,38 0,24 0,10 | tábuas A, corrimão |
| Madeira_Media | 0,285 0,165 0,062 | tábuas B (faixas alternadas, às vezes duas iguais) |
| Pedra | 0,24 0,25 0,22 | blocos, pilares |
| Pedra_Clara | 0,45 0,46 0,40 | capeamento, capitéis, blocos sortidos |
| Corda | 0,46 0,37 0,21 | corda do guarda-corpo |
| Colisao | 0,5 0,5 0,5 | só a malha `Colisao` (não aparece no jogo) |

## Regenerar

```bash
/home/gabriel-bitti/opt/blender/blender --background --factory-startup --python tools/blender/ponte_rio.py
# com as capturas de validação (EEVEE; a cápsula e as câmeras não vão para o .blend nem para o GLB):
/home/gabriel-bitti/opt/blender/blender --background --factory-startup --python tools/blender/ponte_rio.py -- --capturar
```

A semente é fixa (300930), e o GLB sai byte a byte igual entre execuções. O `.blend` muda nos bytes (metadados do Blender), mas não no conteúdo. A cada execução o script grava `art_src/validation/ponte/medidas.json`, com a caixa lida do próprio GLB, a contagem de triângulos e o volume com sinal de cada sólido (todos positivos, com 0 arestas abertas). Grava também os raios verticais do topo do deck: 146.200 amostras em x ∈ [−2,1; 2,1], com z a cada 1 cm. Na versão atual eles dão:
- 0 frestas;
- **degrau máximo de 0,0038 mm**, que é ruído de float32;
- desvio máximo de 0,0024 mm em relação ao arco;
- **menor normal.y de 0,9774** (cos 12,19°);
- 127 faces no topo, nenhuma com |normal.y| < 0,9.

A única face vertical que encosta no topo é a tampa da laje em z = ±17, a espessura da ponta, que fica sob a terra. A diferença bruta entre vizinhos é só a rampa: 2,16 mm a cada 1 cm e 0,22 mm a cada 1 mm. Convenção do eixo igual à de `areia_praia.py`: `v(x, y, z) -> (x, -z, y)` e exportação com `export_yup=True`.

## Integração (a fazer por quem integra)

- **Importação:** cada material vira uma superfície. Entre peças diferentes há sobreposição de 2 a 6 cm. As faixas do deck, porém, se encontram em vértices COMPARTILHADOS: sem compressão a costura fica exata. Com a compressão padrão, cada superfície quantiza pelo próprio AABB, e a costura pode desalinhar frações de milímetro. **Ligue `meshes/force_disable_compression=true`** (como na areia, ver `art_src/praia/LEIA-ME.md`) para o deck manter degrau zero no jogo.
- **Assentamento:** o deck é tangente ao chão em y = 0 nas pontas. A laje termina em z = ±17 com uma face de 10 cm, por isso a terra deve ficar um pouco ACIMA da ponta (o mapa usa 3 cm), para o deck emergir do chão. Se a loja centralizar a peça na caixa como faz com a areia, a posição Y fica no topo do barranco + 0,15.
- **Colisão:** use só a malha `Colisao` (a loja já faz isso pelo prefixo do nome). NÃO use o trimesh do modelo inteiro: as arestas da estrutura travam a caixa do jogador.

## Evidências

`art_src/validation/ponte/`: `medidas.json` e seis capturas EEVEE (1.600 × 900 ou 1.920 × 760), com um sol fixo, céu neutro, sem terreno nem água, e uma cápsula laranja de 1,6 m perto do topo:
`01_tres_quartos_alto`, `02_lateral` (ortográfica), `03_topo` (ortográfica), `04_deck_perto` (olho a 1,65 m do deck), `05_baixo_rio`, `06_tres_quartos_oposto` (sem o `Colisao`). Mais duas só do `Colisao`: `07_colisao_sozinha` (cinza chapado) e `08_colisao_sobre_ponte` (arame magenta sobre a ponte, perto do cavalete de z = −6,375 e do fim da cabeceira).

## Limitações conhecidas

- **Não validado no Godot:** importação, colisão, frestas entre superfícies e luz do jogo. As capturas são do Blender, com tonemap Standard.
- **Sem UV e sem LOD.** Se um dia houver textura, o gerador precisa ganhar projeção de UV.
- Nas três posições de cavalete, as escoras externas atravessam a ponta saliente das tábuas. É uma interseção, não um vão, e só aparece de perto, pelo lado de fora.
- O capitel dos pilares avança 5 cm sobre a linha dos postes, a 1,2 m de altura (x = ±2,13 contra ±2,18).
- O perfil e as medidas são fixos no script. Para outro vão ou outra altura, mude `L2` e `H_ARCO` junto com as posições que dependem do comprimento (`Z_CAB`, `Z_LONG`, `Z_PILAR`, `Z_CAVALETES`, que precisam cair em vértices do arco). Depois, reconfira a inclinação máxima no `medidas.json` (limite pedido: < 15°).
