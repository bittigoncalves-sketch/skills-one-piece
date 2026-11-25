# Animais na ilha toda, bichos 2× maiores, dano dos mobs e IA do inimigo de peça (2026-11-10)
Pedido do dono: (1) IA unificada também para os inimigos do mapa; (2) beagle, gato e pássaro com o DOBRO do tamanho e skin melhor;
(3) esses mais galinhas e patos nascem na ILHA TODA em vez de só na vila — exceto vaca e cavalos; (4) mais dano dos mobs.

| Item | Como ficou | Onde |
|---|---|---|
| IA do inimigo de peça | `InimigoDoMapa` entra em `IaDosInimigos` (facção `mapa`), acorda ao levar dano. Hoje o mapa não tem nenhuma peça dessa categoria. | `ia_dos_inimigos.gd`, `inimigo_do_mapa.gd` |
| Tamanho 2× | `tamanho_padrao` do catálogo ×2: beagle (0,50 → 1,00 m de altura), gato (0,35 → 0,70), `bird_2` e `bird-h5izaudltz` (envergadura 0,6 → 1,2). A colisão e a altura vêm dele. | `mapas/modelos/catalogo.json` |
| Skin | Re-voxelizados a **128 voxels** no maior lado (beagle ~4200 cubos; o anterior tinha ~2400 ≈ 96). 64 teria PIORADO (1110 cubos) — medido. `tools/voxelizar_animais.gd` ganhou `RESOLUCAO_POR_MODELO`. Não é repintura: é mais detalhe de cor/forma no mesmo estilo voxel. | `tools/voxelizar_animais.gd`, `mapas/modelos/*.voxel.scn` |
| Ilha toda | `beagle`, `cat`, `bird_2`, `bird-h5izaudltz`, `chicken`, `chick`, `duck` usam a PLACA da ilha como área (`expandir_para_a_ilha`); nasce o DOBRO (beagle 2→4, galinha 5→10, pinto 3→6, pato 3→6…) e o sorteio tenta 48 pontos. Vaca (4) e cavalos (3) ficam como estavam. A vila vira o ponto `seguro` de reserva. | `populacao_de_animais.gd`, `ModoHistoria._caixa_da_ilha` |
| Dano dos mobs | Bandido/boneco: multiplicador 0,3 → **0,5**. Animais hostis: dano da ficha **×2**. Criaturas do mod (East Blue): dano final ao jogador **×3** (queda/fome/afogamento NÃO escalam). | `boneco_de_duelo.gd`, `animal_da_ilha.gd`, `jogador_do_mod.gd` |

**Medido:** golpe de personagem do mod que tirava ~1,3 de 32 de vida passa a tirar ~4 (a regressão `test_dano_do_mod_no_jogador` agora exige ≥ 2); quatro golpes seguidos de 20 matam o jogador de nível 1.
**Números de balanceamento são palpite calibrado, não regra do dono:** ajustar `ESCALA_DO_GOLPE_DE_MOB`, `ESCALA_DE_DANO` e `multiplicador_de_dano` se ficar duro/mole.
**Risco:** `.voxel.scn` não vão no git; regerar com `godot --headless --path . --script tools/voxelizar_animais.gd -- beagle cat bird_2 bird-h5izaudltz`.
**Falhas anteriores confirmadas (A/B):** 7 em `test_animais` (macaco, urso, renascimento…), `test_chefes_e_capangas` "dano recebido cai pela metade" (armadura não linear), `test_inimigo_lutador` oscila.

**Revertido (10/11/2026, pedido do dono: "voltar o nível de dano do Mine Piece que o jogador recebe de mobs"):** bandido 0,5 → 0,3; animais hostis ×2 → ×1; criaturas do mod ×3 → ×1. Mantido: o conserto da invulnerabilidade em `Player.gd` (o dano do mod voltou a chegar à vida) e o resto do pacote (tamanho 2×, ilha toda).

**Restaurado às 20:17:** o "voltar o nível de dano" das 16:27 foi lido ao contrário. Medido em raid: com ×1 o golpe de um soldado tirava ~1,4 de 24 (6 %) — "NPCs não dão dano". Voltaram bandido 0,5, animais ×2 e criaturas do mod ×3. Se o nível alto estiver duro demais, ajuste só `ESCALA_DO_GOLPE_DE_MOB`.
