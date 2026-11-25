# Nikyu Nikyu no Mi (Modo História) — 14/10/2026

Fruta **do Skills Builder** (não tem código próprio em `src/effects/`): quatro skills em
`mapas/skills/nikyu_*.json` + a entrada em `mapas/skills/frutas.json`. A fonte reproduzível é
`tools/criar_nikyu_nikyu.gd` (monta as skills com `Dados.novo` + `SkillsPublicadas.publicar`,
a mesma API do editor; rodar de novo republica). Números em escala da arena (a história
multiplica por `ESCALA_DA_ARENA`).

| tecla | skill | o que faz |
|---|---|---|
| Z | Pata Gigante | pata de 3,2 m (o dobro do jogador) sai da mão direita; acerto de 0,6 m |
| X | Metralhadora de Patas | 5 rajadas × 8 patas nascem num anel de 2,6 m em volta do corpo e saem para a mira |
| C | Dor | pata vermelha grande; **cura 70% do dano causado** (só se acertar) |
| V | Repulsão | patinha na mão, 62 m/s; explode (4,6 m) com empurrão 30 m/s |

## O que o Builder ganhou (campos opcionais, arquivos antigos seguem válidos)
- Forma de projétil **Pata** (`assets/models/nikyu/pata.glb`, fonte `tools/blender/pata_nikyu.py`).
- `projeteis.direcao_disparo = "Anel"` + `raio_do_anel`.
- `projeteis.raio_de_acerto` — acerto menor que o desenho (pata grande não raspa o piso).
- `dano.cura_do_dano` — % do dano que volta como vida do usuário.

## Teste
`tools/dev_tests/test_nikyu_nikyu.gd` (12 verificações); captura com render: `capturar_nikyu.gd`.

## Não coberto
Rede (cura replicada ao dono do corpo), animação refinada das poses, e o desenho visto de frente.
