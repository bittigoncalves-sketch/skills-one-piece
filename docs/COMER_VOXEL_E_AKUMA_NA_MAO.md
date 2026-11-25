# Comer em voxel e Akuma na mão (decisões do dono, 25/11/2026)

Pedido: representação 3D das Akuma no Mi **na mão**, o ato de **comer** (animação + barulho) para todas as comidas e Akuma, e **pão voxelizado**. Divisão: Codex = planejamento e imagens; Claude = modelagem (Blender) e código. Escolhas do dono: os 9 alimentos ganham modelo voxel próprio; sons sintetizados.

## O que existe
- **Modelos voxel dos 9 alimentos** (16³, 0,02 m/voxel): `tools/alimentos_voxel/gerar_alimentos.py` (Blender headless; reaproveita `tools/akuma_no_mi/gerar_frutas.py`) → `assets/models/alimentos_voxel/<id>.glb`. Atlas 48×32 (6 vistas 16×16); guias em `art_src/alimentos_voxel/guias/`; textura do Codex em `art_src/alimentos_voxel/texturas/<id>.png` (sem ela vale a cor lisa).
- **Akuma na mão:** o slot selecionado da hotbar com `akuma:<id>` mostra `assets/models/akuma_no_mi/<id>.glb` na palma (`AlimentacaoVisual._sincronizar_akuma`).
- **Comer a Akuma:** botão direito → (confirma se há fruta no corpo) → gesto de comer de 2,4 s com sons; o poder só vale ao ENGOLIR; dano/rolagem cortam o gesto e a fruta continua no inventário. Na mochila aberta o clique direito segue imediato (sem gesto).
- **Comer/beber:** o item na mão é o do alimento que será consumido (`Provisoes.proxima_comida/proxima_bebida`); o gesto (`comer`/`beber`) é o de antes.
- **Sons** (`art_src/alimentacao/gerar_sons.py` → `assets/audio/alimentacao/`, 18 WAV): morder crocante (maçã), mastigar macio (pão, refeição), rasgar (carne, peixe), sorver (sopa), gole (bebidas), engolir, mordida e arrepio da Akuma. A agenda por item está em `AlimentosVoxel.agenda`, nos tempos do clipe.
- Rede: `AlimentacaoVisual` replica item, gesto e Akuma segurada do servidor para os clientes (variantes validadas).

## Testes
`tools/dev_tests/test_comer_voxel_e_akuma_na_mao.gd`; regressão: `test_alimentacao.gd`, `test_frutas_no_inventario.gd`.

## Pendências / gatilhos
- Texturas dos 9 alimentos (Codex), storyboard e plano do Codex (`docs/ALIMENTACAO_VOXEL_E_AKUMA_NA_MAO_PLANO.md`).
- Os sons são sintetizados e **não foram ouvidos por mim**: aprovação auditiva do dono. GATILHO: se soarem artificiais, trocar por gravação (a agenda não muda).
- Posição da Akuma/alimento na palma e no ponto de mordida foi conferida por medida, não por captura: validar com o dono em jogo.
