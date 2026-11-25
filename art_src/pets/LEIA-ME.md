# Caranguejo grande — pet do modo história

Asset autoral procedural, criado para este projeto em 30/09/2026. Direção escolhida pelo usuário: aparência natural, carapaça detalhada. Sem assets de terceiros.

- Fonte editável: `caranguejo.blend` e `../../tools/blender/caranguejo_pet.py` (caminho a partir da raiz: `tools/blender/caranguejo_pet.py`).
- Exportação: `assets/models/pets/caranguejo_grande.glb`; cópia do catálogo: `mapas/modelos/caranguejo_grande.glb`.
- Escala original: aproximadamente 4,10 m de largura, 1,48 m de altura e 3,10 m de comprimento, contando patas e pinças; 34.904 triângulos.
- Eixos no Godot: frente −Z, movimento lateral ±X, apoio próximo de Y=0.
- Rig rígido: Corpo, Pata_E/D_0..3_A/B, Junta_E/D_0..3, Garra_E/D, Dedo_movel_E/D, Bolhas_E/D. A animação é procedural no jogo, não clipes embutidos no GLB.
- Quitina moteada por cores de vértice, regiões em relevo, borda dentada, membranas escuras e olhos brilhantes. Todas as cores exportam no GLB.

Regenerar com Blender 5.2:

```sh
/home/gabriel-bitti/opt/blender/blender --background --python tools/blender/caranguejo_pet.py
```

Depois rodar Godot headless com `--script tools/importar_caranguejo_na_loja.gd` e importar com `--editor --quit`. O importador preserva os outros modelos/categorias.

`menu.png` e `pet.png`: capturas do modo história real, em fixture de teste, Godot 4.6.3 Forward+; sem modificar o mapa ou progresso do jogador.

# Gaivota — pet do modo história (30/09/2026, noite)

Asset autoral procedural, **low poly** a pedido do dono: 326 triângulos, faces chapadas,
cor por material (manto cinza, ventre branco, pontas pretas, bico amarelo com mancha
vermelha, pernas rosadas). Sem assets de terceiros.

- Fonte editável: `gaivota.blend` e `tools/blender/gaivota_pet.py` (fonte canônica).
- Exportação: `assets/models/pets/gaivota.glb`. Não está na loja do editor (decisão do
  dono: a gaivota vem do inventário N; a loja virá com um vendedor).
- Medidas: ~0,62 m do bico à cauda, ~1,30 m de envergadura, ~0,42 m em pé (o jogo usa
  escala 1,25).
- Eixos no Godot: frente −Z, asa direita em +X, pés em Y=0.
- Juntas (vazios): Gaivota → Corpo → Cabeca, Cauda, Asa_E/D → Ponta_E/D, Perna_E/D.
  Animação procedural em `src/historia/pets/animador_gaivota.gd`.

Regenerar com Blender 5.2:

```sh
/home/gabriel-bitti/opt/blender-5.2.0-linux-x64/blender --background --python tools/blender/gaivota_pet.py
```

Depois importar no Godot com `--headless --editor --quit`. Prévias: `gaivota/previa_*.png`
(modelo), `gaivota/pose_*.png` (poses do animador), `gaivota/jogo/` (no jogo).
