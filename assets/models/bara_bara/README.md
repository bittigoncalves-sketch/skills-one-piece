# Bara Bara — fontes e contrato dos assets

Modelos e motivos autorais gerados para este projeto, inspirados na fruta de fragmentação e no canhão com munição especial do bando do Buggy. Nenhuma malha, amostra de áudio ou imagem foi extraída do anime; os emblemas são uma interpretação própria. A referência de acabamento é a integração da Ope existente, sem transferir sua identidade cirúrgica.

## Reprodução

Na raiz do projeto:

```bash
/home/gabriel-bitti/opt/blender/blender -b --python tools/blender/bara_bara_assets.py
python3 tools/generate_bara_audio.py
python3 tools/audit_bara_assets.py
/home/gabriel-bitti/opt/blender/blender -b -t 4 --python tools/blender/render_bara_gallery.py
```

Fonte canônica de geometria e material: `tools/blender/bara_bara_assets.py`. A mesma execução salva `art_src/bara_bara/bara_bara_assets.blend`, organizado para edição, e as três texturas PNG usadas na casca e na madeira. Os GLBs carregam as imagens embutidas. Os quatro SVGs em `assets/ui/bara_bara/` são suas próprias fontes vetoriais.

## Importação e encaixe

Metros; Godot **+Y para cima e -Z à frente**. Transformações de malha aplicadas, sem rig ou colisão embutida: colisão autoritativa pertence ao controlador. `manifest.json` registra AABB, triângulos antes da exportação, tamanho e nós.

| Arquivo | Origem / nós | Dimensão XYZ em metros | Triângulos |
|---|---|---|---:|
| `bara_bara_fruit.glb` | Centro da fruta; `Gomo_0`, `Gomo_1`, `Gomo_2`, `Haste` | 0,818 × 0,988 × 0,818 | 47.540 |
| `cannon.glb` | Centro do carrinho junto ao solo; `Barrel`, `Carriage` | 1,132 × 0,992 × 1,725 | 29.560 |
| `buggy_ball.glb` | Centro da esfera; `BuggyBall` | 0,420 × 0,463 × 0,460 incluindo pavio/emblema | 18.692 |

A boca do canhão está em **(0, 0.69, -0.90)**. O controlador deve emitir o projétil à frente da boca e pode transladar apenas `Barrel` no +Z local durante o recuo. O barril é realmente oco, com superfície interna escura e fundo recuado; a bala tem esfera base de diâmetro 0,42 m. Os pneus passam 0,014 m abaixo do pivô, embutindo suavemente na superfície de apoio.

O coletável `src/world/BaraFruitPickup.gd` gira/flutua e abre brevemente as três faixas. Cada faixa possui tampas fechadas, evitando buracos na breve separação. A área de coleta permanece fixa e delega `pickup_fruit(body, "bara_bara")` ao contrato já existente.

## Áudio

`tools/generate_bara_audio.py` sintetiza PCM16 mono a 48 kHz com sementes fixas. Separação, disparo, impacto, retorno e explosão têm durações distintas de 0,28/0,75/0,32/0,25/1,18 s. Pico medido de todos: **−3,0001 dBFS**, sem clipping. RMS e demais medidas em `art_src/bara_bara/audio_measurements.json`. A mistura posicional e ganho final pertencem a `BaraAudio`; normalização de pico não substitui audição no jogo.

## Evidência e limites

`art_src/bara_bara/source_gallery.png` é um render da fonte Blender: comprova geometria e apresentação da peça, sem provar importação, escala de combate, iluminação ou desempenho na engine. A integração e as capturas Godot são registradas pela validação do kit. Os modelos têm cerca de 95,8 mil triângulos combinados; esse número não é um benchmark de FPS, CPU ou GPU. Não há promessa de equivalência artística à Ope baseada apenas na contagem de malhas.

Auditoria estrutural final: **90 verificações passaram**. Dados exportados e hashes estão em `art_src/bara_bara/asset_audit.json`. Normais externas do barril têm produto radial mínimo 0,999995; internas do cano, máximo −0,996406, comprovando orientação oposta adequada. A junção de objetos ordena nomes antes de exportar; a fonte não depende da ordem de iteração de conjuntos.
