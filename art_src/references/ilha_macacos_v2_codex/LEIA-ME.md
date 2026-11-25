# Ilha dos Macacos v2 — referências do Codex

Entrega compartilhada com Claude: aqui ficam conceitos e fontes de imagem;
os PNGs de materiais e ícones destinados ao projeto ficam em
`assets/textures/ilha_macacos/`. Conceitos são referências de modelagem,
não modelos nem validação do resultado no jogo. Geração visual com a ferramenta
de imagem integrada; texturas de pixel geradas pelo script local abaixo.

## Gorila-rei

- `gorila_rei_tres_vistas.png`: frente, perfil e costas, referência de silhueta.
- `gorila_rosto.png`: close do rosto e ornamento.
- `gorila_pose_idle.png`: respiração/espera.
- `gorila_pose_peito.png`: batida no peito e rugido.
- `gorila_pose_soco_duplo.png`: soco duplo no chão.
- `gorila_pose_pulo.png`: pulo para esmagamento.
- `gorila_pose_arremesso.png`: arremesso de pedra/coco.
- `gorila_pose_investida.png`: investida com o ombro.
- `gorila_pose_giro.png`: giro dos dois braços.
- `gorila_pose_derrotado.png`: derrotado/ajoelhado.
- `gorila_pose_furia.png`: fase enfurecida e olhos vermelhos.

As folhas geradas são guias visuais: pequenos desvios entre vistas, detalhes
ornamentais e poses precisam ser resolvidos no modelo e no rig do Blender.

## Paleta do atlas

| Material | Cor principal | Variações |
|---|---|---|
| Pelagem preta-azulada | `#1D263B` | `#141C2C`, `#2B3853` |
| Pelagem azulada | `#303E58` | `#202E47`, `#41516C` |
| Dorso prateado claro | `#AEB3BF` | `#8C94A4`, `#C5C9D1` |
| Dorso prateado escuro | `#777F8E` | `#616B7C`, `#959DAB` |
| Rosto | `#484652` | `#3B3945`, `#5C5964` |
| Focinho | `#35333C` | `#292832`, `#494750` |
| Palma e sola | `#605A60` | `#4C484F`, `#746D72` |
| Unha | `#858080` | `#6F6969`, `#999392` |
| Madeira da coroa | `#6E4E31` | `#4E3728`, `#876642` |
| Osso | `#D3C8A5` | `#B2A482`, `#E5DBBF` |
| Pedra | `#777B79` | `#5E6260`, `#898C85` |
| Pedra e musgo | `#747A6D` | `#555C52`, `#899080`, `#71834C` |
| Olho branco | `#E9E6D2` | `#D6D0BA`, `#F5F1E1` |
| Olho vermelho | `#B8242B` | `#821C24`, `#ED4A3E` |
| Boca e dentes | `#483138` | `#34262C`, `#DCD0AE` |
| Reserva | `#798542` | `#5C6933`, `#98A958` |

O arquivo `gorila_rei_atlas.png` tem 128×128 pixels, com células de
32×32, na ordem acima, da esquerda para a direita e de cima para baixo.
As células são superfícies de materiais, sem iluminação direcional pintada.
O olho vermelho e a boca são materiais, não desenho anatômico completo: a
geometria e o UV devem construir o formato desejado. Use filtragem nearest;
ao usar mipmaps ou UV perto de bordas de células, evite misturar células.

## Fonte das texturas

- `gerar_texturas.py`: gerador reproduzível do atlas e das nove texturas de
  materiais. Requer Python 3 e Pillow; rodar a partir de qualquer diretório
  com `python3 art_src/references/ilha_macacos_v2_codex/gerar_texturas.py`
  na raiz do projeto. Reexecutar sobrescreve os PNGs gerados pelo script.

As nove texturas de materiais em `assets/textures/ilha_macacos/` são
`terra_batida.png`, `grama_praca.png`, `calcamento_musgoso.png`,
`madeira_tabua.png`, `bambu.png`, `palha_telhado.png`, `corda.png`,
`pedra_trono.png` e `areia_praia.png`. São 32×32, opacas e repetíveis.
A inspeção das bordas foi automatizada; a revisão visual em modelos está
pendente. A cor chapada do terreno do mapa não usa essas texturas.

## Construções

Cada PNG reúne duas vistas e amostras de cor. As referências são
conceituais; os detalhes pequenos podem ser simplificados no Blender.

- `construcao_cabana_geppo.png`: cabana do Mestre do Geppo.
- `construcao_cabana_curandeiro.png`: cabana do curandeiro.
- `construcao_torre_vigia.png`: torre de vigia com estrutura de madeira.
- `construcao_cais.png`: cais de madeira e corda.
- `construcao_portal.png`: arco de entrada da vila.
- `construcao_totem_sabio.png`: totem de macaco sábio.
- `construcao_totem_guardiao.png`: totem de macaco guardião.
- `construcao_totem_alegre.png`: totem de macaco alegre.
- `construcao_altar_bananas.png`: altar das bananas.
- `construcao_trono.png`: trono de pedra com crânios e motivo de bananas.
- `construcao_fogueira.png`: fogueira com cobertura opcional.
- `construcao_fogueira_aberta.png`: variante de fogueira sem cobertura.
- `construcao_tenda.png`: tenda de palha.

## Ícones

As fontes RGBA de alta resolução ficam aqui como `*_fonte.png` e as
exportações ficam em `assets/textures/ilha_macacos/`. Para exportar todas
as fontes disponíveis em 128×128, mantendo proporção e transparência:
`python3 art_src/references/ilha_macacos_v2_codex/exportar_icones.py`.
Requer Pillow e sobrescreve os ícones exportados com o mesmo nome.

| Fonte nesta pasta | PNG final em `assets/textures/ilha_macacos/` | Uso |
|---|---|---|
| `icone_banana_fonte.png` | `icone_banana.png` | Banana |
| `icone_coco_fonte.png` | `icone_coco.png` | Coco |
| `icone_totem_fonte.png` | `icone_totem.png` | Totem |
| `icone_fruto_dourado_fonte.png` | `icone_fruto_dourado.png` | Fruto dourado |
| `icone_coroa_gorila_fonte.png` | `icone_coroa_gorila.png` | Coroa e missão principal O Rei da Selva |
| `icone_cabana_mapa_fonte.png` | `icone_cabana_mapa.png` | Marcador de cabana |
| `missao_cesto_bananas_fonte.png` | `missao_cesto_bananas.png` | Cesto de bananas |
| `missao_pesca_cais_fonte.png` | `missao_pesca_cais.png` | Pesca do cais |
| `missao_saqueadores_fonte.png` | `missao_saqueadores.png` | Os saqueadores |
| `missao_quatro_totens_fonte.png` | `missao_quatro_totens.png` | Os quatro totens |
| `missao_fruto_dourado_fonte.png` | `missao_fruto_dourado.png` | O fruto dourado |

## Conjunto de prompts visuais

- Gorila: folha de personagem voxel, frente/perfil/costas em pose neutra,
  pelagem preta azulada e dorso prateado, rosto severo, coroa de madeira e
  ossos, ombreiras de pedra, punhos grandes e fundo neutro; usar a folha
  produzida como referência para o close e cada uma das nove ações acima.
- Construções: para cada item nomeado na lista, duas vistas da mesma peça,
  amostras de cor, sem paisagem nem personagens, arquitetura modular em
  madeira, bambu, corda, pedra e palha apropriados à peça. A variante de
  fogueira aberta remove a cobertura da referência inicial.
- Ícones: objetos e símbolos das missões descritos na tabela, isolados sobre
  transparência real, pixel art de silhueta forte e sem texto ou moldura;
  exportação final em 128×128 com nearest e preservação da proporção.

`LEIA-ME.md` é o próprio índice e registro da entrega. Os nomes e prompts
documentam referências, não garantem licença de fontes de terceiros nem
comprovam integração ou validação no jogo.
