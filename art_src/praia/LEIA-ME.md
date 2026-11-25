# Areia de praia low poly

Asset autoral em metros: **32 × 1,8 × 24**, **550 triângulos**, cinco materiais foscos, UV 0–1 e normais planas. Fonte: `areia_praia.blend`; gerador determinístico: `tools/blender/areia_praia.py`.

A margem seca está em **−Z**, a descida para o mar em **+Z**. O topo vai de Y=0,6 a Y=−0,8; fundo fechado em Y=−1,2. As bordas X têm o mesmo perfil para encaixar cópias lado a lado. É um módulo retangular, não um contorno automático da ilha. Pode ser escalado e girado no editor.

## Usar

Reabrir o editor do mapa → Loja → **praia mapa** → **Areia de praia — low poly**. A loja centraliza a peça na sua caixa (centro Y=−0,3). Com o tamanho original, posição Y=−0,3 reproduz as alturas acima. A colisão automática usa os triângulos do modelo, acompanhando a rampa.

Para uma baseplate com borda em X=256 e topo Y=0: posição `(260, −0,3, z)`, rotação Y=90°, módulos separados por 32 m em Z. Isso é exemplo de encaixe, não alteração automática do mapa.

## Regenerar

```bash
/home/gabriel-bitti/opt/blender/blender --background --python tools/blender/areia_praia.py
"$(./find_godot.sh)" --headless --path . --script tools/importar_areia_na_loja.gd
"$(./find_godot.sh)" --headless --path . --editor --quit
python3 tools/validar_praia.py --capturar
```

O importador mede a malha no Godot e atualiza somente a entrada deste asset; preserva as categorias e os outros modelos. A biblioteca guarda `mapas/modelos/areia_praia_low_poly.glb`. A pasta fonte está sob o `.gdignore` de `art_src/`.

**Importação:** `mapas/modelos/areia_praia_low_poly.glb.import` tem `meshes/force_disable_compression=true`. Cada cor de areia é uma superfície; com a compressão padrão do Godot cada uma quantiza os vértices pelo próprio AABB e abrem fendas entre as cores (pontinhos pretos na areia, 30/09/2026). Se o `.import` for apagado ou recriado, religar essa opção — `test_praia_oceano.gd` reprova enquanto ela estiver desligada.

## Oceano

`src/world/oceano_historia.gd` e `.gdshader`, compartilhados pelo jogo e editor. Oceano visual automático para caixas com id `baseplate` ou prefixo `baseplate_` (duplicatas do editor). Cor pela distância ao retângulo orientado: azul claro junto da ilha, azul escuro após aproximadamente 85 m. Usa a costa mais próxima de cada pixel. Até 64 bases horizontais, incluindo rotação em Y.

Nível = menor topo das bases −0,65 m. Ondas sobrepostas em direções diferentes, arrebentação indo em direção à costa, espuma fragmentada, variação lenta de cor e ondulação curta nos reflexos. A malha tem 131.072 triângulos, com células de 1 m perto da câmera e espaçamento progressivo até 16 km; só a tesselação acompanha a câmera, as ondas usam coordenadas mundiais. Deslocamento geométrico esmaece entre 65–94 m da câmera; normais continuam animadas ao longe.

Parâmetros editáveis no script/nó: `nivel_relativo`, `largura_agua_clara`, `altura_ondas`, `velocidade_ondas`; cores no shader. Movimento/escalonamento/rotação/duplicação/remoção/desfazer das bases recalcula a costa no editor. Mapas sem baseplate não recebem superfície visível.

Nesta etapa o mar é uma superfície visual opaca, sem refração, natação, flutuação ou colisão. Não modifica o mapa salvo nem o layout da praia. Bases inclinadas em X/Z e costa de malhas arbitrárias não são analisadas. Espuma segue o contorno da baseplate, não a colisão individual de cada objeto da praia.

## Evidências

`art_src/validation/praia/`: cinco capturas e uma animação WebP (36 quadros em passos de 1/12 s) da engine Forward+ (RTX 3050), logs, `resultado.json`. As três peças de areia nas capturas são instâncias de demonstração, temporárias. O mapa real é carregado em modo leitura. As capturas em T=0 e T=2 têm a mesma câmera; o validador mede mudança numa amostra ocupada apenas pelo mar. Não é uma medição de FPS nem de qualidade artística.
