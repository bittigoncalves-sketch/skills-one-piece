# Alimentação voxel e Akuma no Mi na mão — plano de aceite

Data: 25/11/2026. Entrega solicitada: representar a Akuma selecionada em 3D na mão; apresentar os nove alimentos e bebidas com modelos voxel próprios; animar e sonorizar o consumo de cada um e das Akuma. Claude é responsável pela modelagem, integração, animação e sons; Codex pelo plano, storyboard e atlas. Este arquivo define critérios e verificações; não comprova a implementação nem a aprovação visual ou sonora.

## Estado observado antes da integração

- `Provisoes.ITENS` registra seis comidas e três bebidas, em `src/historia/tripulantes/provisoes.gd`. A seleção da barra segue a ordem de `COMIDAS_NA_BARRA` e `BEBIDAS_NA_BARRA`; o visual precisa usar o **ID realmente selecionado**, não apenas as categorias genéricas `comida` e `agua`.
- `HistoriaHud._comer_devagar` reserva uma comida, devolve a unidade em interrupção e aplica fome/benefício ao concluir. A duração real depende do item (`tempo_de_comer`, limitada a 2–4,5 s). Evitar repetir a reserva ou recompensa.
- A bebida da barra hoje é debitada e faz efeito no clique; a animação vem depois. `MenuDeComportamento` também chama `Provisoes.consumir` diretamente. Não presumir que esses caminhos já façam a mesma reserva/devolução da comida: validar interrupção e evitar duplicar ou estornar efeito já aplicado. Se a regra de bebida mudar, documentar a decisão e cobrir os saves/caminhos afetados.
- A Akuma selecionável usa tag `akuma:<id>` no inventário e tem confirmação quando substitui fruta anterior (`src/inventario/itens_de_fruta.gd`); `ProgressaoDoPersonagem.comer_fruta` muda o poder imediatamente. Preservar confirmação, contagem e regra de troca; não aplicar duas vezes. Definir explicitamente se a mudança fica imediata ou será adiada, e sincronizar a animação com a transação real.
- `alimentacao_visual.gd` usa os modelos de pão/água e o socket `PlayerRig.item_handle`, replica apresentação a partir do servidor e cancela a pose em certos conflitos. `ProceduralAnimator` coordena a pose e o contato com o rig de História. Verificar os caminhos correntes antes de alterar, pois há trabalho simultâneo.
- Os clipes atuais informados pelo briefing são `comer.tres` de 1,9 s (contato aproximado 0,53–1,12 s) e `beber.tres` de 2,2 s (goles aproximados 0,85–1,38 s). São pontos de partida para aferição visual, não provas de contato ou de som. O storyboard está em `art_src/references/akuma_na_mao_codex/`.

## Critérios para cada item

Em todos os casos: item distinto e identificável, preso à mão que o usa, escala compatível com a mão e corpo, sem atravessar a cabeça ou flutuar; verificar em pé e em movimento, pelo jogador e por observador remoto. Medidas são comparação visual, não um fator universal: o pão e a maçã devem caber na palma, peixe e carne podem ultrapassá-la, tigela/prato não devem eclipsar o tronco, recipientes devem permitir contato do bocal/canudo com a boca. Os tempos são sugestões a ajustar por playtest; não exigir deformação do item, partículas ou mastigação facial que o rig não suporte.

| ID | Leitura e pegada | Ação e som esperado |
| --- | --- | --- |
| `pao` | Pão rústico oval, crosta dourada e cortes claros; na palma. | Levar à boca; mordida de crosta no contato, mastigação curta e deglutição ao terminar. |
| `maca` | Maçã vermelha com folha e caule; na palma. | Mordida mais nítida/crocante no contato, mastigar e engolir. |
| `peixe_assado` | Peixe inteiro tostado com cauda e palito visíveis; pegada no palito. | Aproximar a parte comestível da boca, sem enfiar o palito; mordida/mastigação mais macia e deglutição. |
| `sopa_de_peixe` | Tigela com caldo e pedaços de peixe visíveis por cima, estável na mão. | Sem colher na malha atual: gesto de tigela aproximada/inclinada, som de sorver e engolir; não fingir mordida seca. Continua sendo `comida` nas regras atuais. |
| `refeicao` | Prato com carne, arroz e legume distinguíveis visto de cima; escala compatível com a mão. | Aproximar prato sem virar seu conteúdo; som de refeição/mastigação e deglutição. A geometria atual não inclui talheres. |
| `carne_assada` | Carne tostada com osso claro; segurar pelo osso. | Encostar a carne na boca, mordida firme, mastigação e engolida; não morder o osso. |
| `agua_potavel` | Garrafa azul-clara com tampa e gargalo reconhecíveis, pega pelo corpo. | Bocal orientado à boca, inclinação de beber, goles de água e engolida; voltar à espera sem permanecer inclinada. |
| `leite` | Caixa clara com marca azul e bico legível. | Aproximar/inclinar a caixa pelo bico, som de goles e deglutição; conferir a orientação específica da caixa. |
| `suco_de_laranja` | Copo alaranjado com canudo e rodela; pegar pelo copo. | Aproximar o canudo da boca com copo predominantemente vertical; som de sorver/goles e engolida. |
| Akuma `akuma:<id>` | Ao selecionar a pilha, mostrar modelo correspondente de `assets/models/akuma_no_mi/<id>.glb`, aplicando aliases da mesma fruta; segurar na palma, escala que não esconda corpo/boca. | Após confirmação quando necessária: levar à boca, mordida no contato, mastigar, engolir e recuperar. Som de mordida em fruta, mastigação e engolida. Confirmar troca/cancelamento sem destruir a fruta anterior indevidamente. |

## Sincronia e interrupção

1. **Início:** selecionar o ID e modelo corretos; não reproduzir som ou consumir quando faltar item, quando o jogador estiver morto ou quando uma confirmação ainda não ocorreu. Equipar/guardar deve trocar/remover o visual sem objetos órfãos.
2. **Contato:** disparar mordida/sorvida apenas quando o item toca a boca. Para comida, usar como referência a faixa normalizada 0,53/1,9–1,12/1,9 do clipe; para bebida, 0,85/2,2–1,38/2,2. Se o clipe for esticado, multiplicar as frações pela duração efetiva e conferir visualmente. Sons de mastigação/goles devem acompanhar a fase, sem disparar a cada frame.
3. **Conclusão:** deglutição e retorno da mão. O término visual deve refletir a regra da ação: comida reservada aplica uma vez ao finalizar; para bebida e Akuma, preservar a semântica vigente até ser alterada explicitamente e testada. O modelo pode desaparecer após o consumo sem sugerir que o estoque já foi removido em um ponto que não corresponde à regra.
4. **Dano e demais interrupções:** dano durante preparação e durante contato interrompe gesto e sons; limpar pose e garantir que a mão/objeto reflitam a seleção real. Para comida reservada, devolver exatamente uma unidade e não aplicar bônus. Para bebida/Akuma já aplicadas, não duplicar nem desfazer silenciosamente o efeito; registrar a política se houver mudança. Testar morte, rolagem, troca de item/rig, saída de cena e desconexão.
5. **Rede e persistência:** servidor decide estoque, confirmação, recompensa e cancelamento; observadores veem o mesmo ID, gesto e eventos sem eco de som duplicado. Conferir jogador local e cliente remoto, troca de slot rápida, latência, save/reload e ausência de reentrada após morte. Nenhuma validação multiplayer é presumida por este plano.

## Ordem de playtest e evidências

1. **Fatia real:** pão, água e uma Akuma conhecida no Modo História. Ver seleção e consumo pela barra/inventário, progressão, quantidade antes/depois e cancelamento em dano. Capturar de frente e perfil, em câmera lenta para contato e pega.
2. **Cobertura dos nove IDs:** forçar cada item a ser o selecionado de fato; checar a tabela, tempo, clipe e categoria de som. Testar caixa, garrafa e canudo separadamente; testar sopa e prato com ângulo de câmera que mostre conteúdo.
3. **Frutas:** testar várias silhuetas e tamanhos (esfera, coração, cacho e fruta com haste), aliases, pilha, substituição com confirmação e negação. Verificar que o ícone, o ID, o modelo e o efeito correspondem à mesma fruta.
4. **Estados e rede:** interrupção em pelo menos dois momentos, troca de slot, ação corporal concorrente, morte/respawn, viagem de cena, save/reload e dois clientes. Verificar número de itens e efeito exatamente uma vez.
5. **Visual e áudio com o dono:** apresentar capturas/vídeo do jogo, visão de perfil e gravação audível sem cortes dos sons. Aprovar escala, contato, movimento natural, desenho dos nove itens e sincronia/volume/timbre por categoria. Resultado headless ou render externo não substitui a avaliação em execução.

Evidências sugeridas: teste de integração dos caminhos reais com identificação por ID, logs de início/contato/conclusão/interrupção, capturas/vídeos dos itens na mão e teste de áudio/multiplayer. Registrar falhas conhecidas separadas dos testes focados e não declarar regressão global sem executá-la.
