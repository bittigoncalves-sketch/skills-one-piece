# Centro de treino: proposta para o início do Modo História

**Estado:** proposta de design e implementação, não implementada. A direção visual e o destino das missões depois do nível 3 aguardam decisão do jogador. As imagens são conceitos, não assets 3D prontos nem capturas do jogo.

**Imagens geradas:** [centro de treino](../art_src/conceitos/centro_treino/centro_de_treino.png) e [boneco de treino](../art_src/conceitos/centro_treino/boneco_de_treino.png). O personagem ilustrado no centro é apenas referência de escala; no jogo, será usado o personagem criado pelo jogador. O boneco detalhado é a referência principal para o asset; a aparência simplificada dos bonecos na imagem do centro é ilustrativa.

**Transferência ao Claude:** solicitada pelo usuário com as duas imagens e orientação para usar o Blender via MCP na criação dos assets. Ao entregar este plano, o checkout estava na branch `pika-espada-modos-2026-09-06`, commit `9301956`; o plano e as imagens estavam sem commit. A criação dos assets foi solicitada nesta transferência; a implementação do minigame e a alteração das missões continuam propostas, sujeitas às decisões abertas. Confira instruções locais e alterações concorrentes antes de editar. Próximo passo: abrir as imagens e o plano, verificar disponibilidade do MCP Blender, produzir fontes editáveis e apresentar evidência visual; informar qualquer bloqueio.

**Atualização 20/11 — centro voxel:** o usuário solicitou alterar o centro para estilo voxel e depois pedir ao Claude a implementação no mapa, substituindo a construção onde está o ferreiro. Fonte: `tools/blender/centro_treino_voxel.py` e `art_src/blender/centro_treino/centro_treino_voxel.blend`; exportação: `assets/models/centro_treino/centro_treino_voxel.glb`; prévia: `art_src/validation/centro_treino/centro_treino_voxel.png`. A construção nova tem pavilhão e pátio, mas não inclui o boneco, que permanece separado. O `.glb` foi exportado no Blender 5.2 e verificado estruturalmente; não foi validado no Godot nem comparado no mapa. A peça anterior é `blacksmith_1` em `mapas/historia/baseplate.json`; `src/historia/missoes/inicio_da_jornada.gd` também identifica `blacksmith` para gerar o ferreiro, logo sua substituição precisa preservar o NPC e testar sua loja. O mapa já estava modificado antes desta etapa: preservar as alterações concorrentes. Localização do NPC junto ao novo centro ainda não foi respondida; encaminhar como posicionamento provisório ao lado.

## Objetivo

Substituir o início baseado nas missões atuais por um minigame de treino com o personagem real, desde o nível 1 até alcançar o nível 3. A experiência deve ensinar ações reais de movimentação e combate, registrar progresso no save da campanha e terminar com uma transição clara para a aventura.

## Direção visual proposta

- Centro situado na ilha inicial, perto de um ponto de chegada acessível: pátio espaçoso com piso legível, cobertura de madeira aberta, área para deslocamento e área para bonecos. A posição exata depende da inspeção do mapa e de teste da câmera.
- Materiais de madeira, corda e palha com acabamento estilizado de aventura anime; silhuetas bem reconhecíveis e espaço para ver o personagem. A imagem do centro representa uma proposta, não dimensões ou geometria obrigatórias.
- Boneco humanoide fixado em uma base, com áreas acolchoadas e braços articulados. Deve indicar facilmente o lado atingido e o início de cada ataque; a forma, os materiais e as animações serão aprovados visualmente antes da integração final.
- O jogador usa seu próprio corpo, aparência, roupas e controles da campanha, sem personagem substituto. A câmera e a HUD são as reais do Modo História.

## Fluxo de jogo proposto

1. Após a criação ou seleção normal do personagem, uma campanha nova começa no centro ou é guiada até ele. Apresentar um objetivo curto de cada vez e os comandos realmente configurados pelo jogador.
2. **Fundamentos (nível 1 → 2):** movimentar-se, orientar a câmera, aproximar-se do boneco e acertar uma sequência curta de golpes reais. O boneco fica parado, reage aos impactos e mostra o progresso do exercício. Ao terminar, conceder o XP restante necessário para chegar ao nível 2, caso o jogador ainda não esteja nele.
3. **Reação e combate (nível 2 → 3):** defender golpes anunciados e fazer uma sequência simples de ataque e reposicionamento. Usar esquiva/dash somente se o movimento estiver realmente disponível no início; caso não esteja, substituir por deslocamento ou planejar seu desbloqueio com decisão explícita. Ao concluir, conceder apenas o XP que falta para alcançar o nível 3.
4. Ao chegar ao nível 3 **e** concluir os exercícios, registrar treinamento concluído, informar o jogador e abrir a saída para a aventura. A repetição para praticar pode continuar disponível, sem repetir recompensas. Se outro evento conceder XP e o jogador chegar ao nível 3 antes, não reduzir o nível nem dar bônus indevido: permitir concluir os exercícios e finalizar normalmente.

As quantidades de acertos, intervalos, instruções, dano de treino e duração são parâmetros de protótipo a calibrar em playtest. O usuário ainda não aprovou valores nem duração.

## Funções do boneco

| Função | Comportamento planejado | Evidência de conclusão |
| --- | --- | --- |
| Receber golpes | Contar contatos válidos do jogador pelo sistema de combate; reagir visualmente e mostrar o acerto. | Acertos fora de alcance ou de outro autor não contam; animação não substitui registro real. |
| Feedback de progresso | Indicar objetivo atual, acertos restantes e mudança de etapa, sem encobrir o alvo. | A HUD acompanha os eventos efetivos e informa quando um exercício termina. |
| Defender | Assumir postura de guarda previsível para ensinar quando atacar. | Só acertos reconhecidos pelas regras reais contam; a guarda tem sinal visual claro. |
| Atacar para praticar defesa | Executar golpes lentos, avisados e com pausa de recuperação. | Bloqueio é registrado pelo combate real; tentativas falhas podem ser repetidas. |
| Reiniciar exercício | Retornar à pose e ao estado corretos após interrupção ou falha. | Nenhum exercício fica travado e não há XP duplicado após recarregar. |
| Prática livre | Permanecer disponível depois do tutorial, caso o design final permita retorno ao centro. | Pode receber ataques sem conceder XP infinito ou gerar recompensas de inimigo. |

O boneco não deve ser tratado como bandido, vítima de missão, pet ou alvo de recrutamento. Não deve gerar loot, fama nem XP por abate. Verificar colisão, dano, amizade, grupos e eventos de morte nos caminhos reais de combate, incluindo habilidades eventualmente presentes no save.

## O que existe hoje e impactos

- `project.godot` aponta para Godot 4.6 e `MainMenu.tscn`; o centro precisa entrar no fluxo real, não em uma cena demonstrativa isolada.
- `src/historia/progressao.gd` inicia no nível 1 e coloca `vara_inicial` em estado aceito; `src/historia/missoes/missoes.gd` define a cadeia atual. Antes do nível 3, é preciso substituir também rastreador, marcadores, ofertas e aceitação, não somente esconder texto.
- `src/historia/recompensa_mine_piece.gd` e `ProgressaoDoPersonagem.ganhar_xp` contêm a regra atual: nível 1 → 2 exige 2.000 XP e nível 2 → 3 exige 2.000 XP. Os prêmios propostos usam o XP restante da etapa no momento da concessão e devem ser concedidos uma única vez; não modificar artificialmente a fórmula geral.
- A cadeia atual conecta vara e pesca, ferraria, facção, bandidos e bússola. `src/historia/missoes/loja_de_missao.gd`, lojas de NPCs, `src/ui/JanelaDeLoja.gd` e `src/ui/bussola_hud.gd` têm dependências a revisar. A remoção integral exige decidir como manter ou substituir essas funções e recompensas.
- `src/combat/direcional/cerebro_de_treino.gd` já tem modos de ficar parado, guardar, atacar em ciclo e aparar; ele é acoplado a `BonecoDeDuelo`. Investigar se pode ser adaptado ao boneco visual sem afetar inimigos e duelos. Sua existência não comprova que esteja integrado ao novo minigame.
- O mapa inicial está em `mapas/historia/baseplate.json`; verificar terreno, spawn, acessibilidade e proximidade dos sistemas existentes antes de escolher a posição.
- `src/historia/serializacao_do_progresso.gd` já faz migrações das missões antigas, e `src/historia/missoes/inicio_da_jornada.gd` inclui ajuste para quem já tem vara. Preservar equipamentos, desbloqueios, nível, XP, recompensas e estado de campanhas existentes; não marcar missões entregues nem conceder recompensas em massa sem uma regra aprovada.

## Persistência e compatibilidade propostas

- Registrar no progresso a versão do treino, etapa atual, contadores de ações válidas, concessões já efetuadas e conclusão. Atualizar estado inicial, `para_dict`, leitura, reset e salvamento real quando implementados.
- Salvar a recompensa e seu marco de concessão de forma consistente para que fechar ou recarregar na passagem de etapa não duplique XP. Tratar recarga em qualquer exercício e reinício da campanha.
- Para campanhas anteriores, não apagar nem rebaixar dados. Jogadores já no nível 3 ou acima não devem ser obrigados a perder progresso; definir com o usuário se o treino será opcional para eles. Para saves abaixo do nível 3, definir a experiência de entrada e a política para missões que estejam em andamento antes de migrar.
- Em rede, atribuir contagem e prêmio ao jogador correto, verificar autoridade e repetição de eventos, e testar reconexão se esse caminho do Modo História estiver disponível. Não presumir que o treinamento já seja sincronizado.

## Etapas de implementação e validação

1. **Definir transição e compatibilidade.** Decidir o destino das missões após o nível 3, da facção, da bússola e dos saves existentes; conferir mapa, controles, desbloqueios e arquitetura de rede. Resultado: regras de migração e fluxos documentados.
2. **Fatia jogável integrada.** Inserir local e boneco provisórios na ilha inicial, usar o personagem e combate reais, registrar um exercício simples com feedback da HUD. Validar do menu até um acerto reconhecido no Modo História.
3. **Fluxo completo até o nível 3.** Implementar etapas, contadores, recompensa por marco e saída; integrar save, reset e retomada. Testar novo jogo, acertos válidos/inválidos, falha, XP parcial, nível 3 antecipado, reinício e repetição sem ganho extra.
4. **Missões e serviços.** Aplicar a decisão do usuário ao fluxo antigo e revisar NPCs, rastreador, pesca, ferraria, facção e bússola. Testar campanhas novas e antigas em cada ponto relevante, sem perda ou duplicação de itens e recompensas.
5. **Arte e experiência final.** Produzir o centro e o boneco com fontes editáveis, materiais e animações; importar para a engine e medir visibilidade na câmera real. Capturar centro, poses, impactos e HUD; validar leitura dos golpes, colisões, acessibilidade e desempenho em máquina/cenário registrados. Comparar ao conceito e pedir avaliação artística ao usuário.
6. **Integração e regressão.** Testar Modo História completo: criação e aparência, salvar/recarregar, sair e retornar, morte/respawn se aplicável, reinício, estados legados e rede quando suportada. Executar testes focados e verificar falhas gerais separadamente.

## Decisões abertas

1. As missões atuais ficam disponíveis depois do nível 3 ou são removidas integralmente e substituídas mais tarde? Sem essa decisão, o plano não presume que as missões retornem.
2. Qual o visual preferido para o centro: pavilhão/dojo, campo aberto ou base militar? A imagem entregue é uma proposta de pavilhão aberto.
3. Para jogadores que já possuem save, o treino é opcional, obrigatório abaixo do nível 3, ou aplicável apenas a novas campanhas? Definir a migração antes de implementar.
4. Caso a remoção seja integral, onde serão obtidos facção, vara, ferraria e bússola e como serão tratadas missões já aceitas? Nenhuma recompensa deve ser concedida automaticamente sem uma regra aprovada.

## Validação desta proposta

Foi feita leitura estática direcionada dos arquivos de progressão, missões, combate, serialização e mapa. Nenhum protótipo, teste de execução, captura do jogo ou aprovação visual foi realizado nesta etapa.

## Prompts das imagens

Imagens produzidas pela ferramenta de geração integrada do Codex.

**Centro:** “Concept art para o centro de treino inicial de um jogo de aventura pirata inspirado em anime. Uma área de treinamento de ilha costeira com um pavilhão simples de madeira parcialmente aberto, pátio claro e amplo para movimentação, dois bonecos de treino de madeira e palha bem visíveis, obstáculos simples para esquiva e circulação, mar e vegetação ao fundo. Mostrar a área inteira em perspectiva elevada legível, com um personagem aventureiro pequeno para escala. Visual 3D estilizado de jogo, cores convidativas, materiais bem acabados, adequado ao mundo de aventura do jogo; arquitetura com detalhes críveis e geometria conforme necessário, sem impor cubos. Iluminação diurna, sem textos, interface, logotipos ou marcas d'água. Isto é uma proposta visual, não mapa técnico.”

**Boneco:** “Concept art de um boneco de treino para um jogo de aventura pirata anime, peça original, corpo inteiro isolado e destacado em enquadramento largo; boneco humanoide construído de madeira, corda e palha, sobre uma base estável, com braços acolchoados articulados para indicar golpes e defesa; alvos pintados discretos legíveis no torso. Apresentar vista principal 3/4 grande e duas vistas menores frontal e lateral mostrando o mesmo design, em fundo neutro de estúdio. Aparência de asset 3D de jogo, materiais detalhados, silhueta clara, proporções consistentes e componentes mecanicamente plausíveis. Sem personagem famoso, texto, números, interface, logotipos ou marca d'água.”
