# Reconstrução própria dos mobs do Mine Piece (decisão do dono, 25/11/2026)

Meta: medir o que do Mine Piece já está modificado o bastante para entrar no jogo, reconstruir texturas e assets
(**Codex = responsável pelas imagens**), usando o Mine Piece **só como referência de construção**, começando pelos inimigos.
Primeira ilha = pirata, galo e Chouchou; os demais ficam para outras ilhas.

## Critério de "modificado o bastante" (declarado por mim; o dono pode trocar)
Um personagem só é PRONTO quando (1) a malha é própria (`mapas/modelos/pi_<id>.glb`, cubos e UV desenhados aqui, não o
`.geo.json` do mod) **e** (2) a textura foi pintada do zero (Codex, `art_src/reconstrucao/texturas/<id>.png`).
Dados (vida, IA, tempos) e o esqueleto/animações (nomes e pivôs dos ossos) entram como estão, como em `MODS_VOXELIZACAO.md`.
Ferramenta: `python3 -I tools/mine_piece/medir_modificacao.py --md docs/MINE_PIECE_MEDICAO_MODIFICACAO.md`.

## Medição (25/11/2026) — `docs/MINE_PIECE_MEDICAO_MODIFICACAO.md`
- 110 fichas. **Antes:** 110 PROVISÓRIO (malha convertida do mod; textura só reduzida para 64 px — a redução voxel não conta como modificação).
- **Agora (25/11, 07:42):** 3 PRONTOS (pirate, chouchou, suzume→galo: malha própria + textura do Codex); 107 PROVISÓRIO.

## Feito
- `tools/mine_piece/reconstruir_primeira_ilha.py`: especifica cubos próprios, empacota o atlas, gera geo/UV/guia/provisória/.glb.
  Preview sem engine: `prever_reconstrucao.py`. `geo_para_glb.adicionar_animacoes` extraída (saída idêntica, conferida).
- `DadosEastBlue` troca `mp_<id>` por `pi_<id>` quando o .glb existe.
- `Ilhas.elenco_mp`: o spawn natural da Ilha Inicial só sorteia pirate, suzume e chouchou. Outras ilhas: sem restrição.
- Teste `tools/dev_tests/test_primeira_ilha_reconstruida.gd` 46/46.

## Pendente / gatilhos
- Texturas do Codex ENTREGUES e aplicadas (gerador + `--import` + prévia + teste 46/46). `pirate_v2.png`/`pirate_v3.png` (variações de roupa) ainda NÃO ligadas: GATILHO = querer variedade de pirata; gerar `pi_pirate_v2/v3.glb` e listá-los em `modelos` da ficha.
- Bandido (`bandit`) e as 8 variações de roupa do pirata (`mp_pirate_pirate1..8`) ficam fora desta ilha; GATILHO: ao entrar uma ilha com bandidos/Alvida, reconstruir pelo mesmo gerador (copiar a spec do PIRATA).
- Próximas ilhas, por zona da ficha: Macacos/Alvida → bandit, alvida; Shells Town → marine, morgan, helmeppo; Orange Town → buggy, cabaji, richie; Syrup → kuro, jango, sham, buchi; demais pelas zonas em `personagens.json`.
- Playtest humano da ilha com os 3 mobs; aprovação visual do dono.
