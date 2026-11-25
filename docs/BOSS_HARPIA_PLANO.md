# Harpia — Investida e Tornado Vendaval

Planejamento de 03/10/2026, revisão concluída em 04/10/2026. Atualização em 05/10/2026: os controladores dos dois ataques já estão implementados. Acabamento de animação/VFX, decisões atuais e evidências: [HARPIA_ANIME_CHECKPOINT.md](HARPIA_ANIME_CHECKPOINT.md). As propostas abaixo permanecem como histórico de design; os valores efetivos estão em `config_harpia.gd` e `tornado_vendaval.gd`.

## Pedido e decisões confirmadas

O usuário pediu dois ataques para o boss voador do modo história. Confirmou que o personagem é a **Harpia já existente**, modelo `harpia_-_animated_low_poly` e área `animais_morros_harpia`.

1. **Investida:** fecha as asas, avança contra o jogador cortando o ar ao redor e aplica enorme knockback ao acertar.
2. **Tornado Vendaval:** lança um tornado verde de vento que segue para frente por **5 segundos** e carrega os seres vivos encontrados.
3. Confirmado: os capturados giram dentro do tornado até ele desaparecer e então são lançados. Quem entra no quarto segundo permanece até o quinto segundo do mesmo tornado; cada captura não reinicia a duração.

Os tempos e intensidades adicionais abaixo são propostas iniciais de ajuste jogável, não valores pedidos pelo usuário.

## Base real do projeto

- Godot 4.6.3. A Harpia já possui `boss: true`, 700 de vida, corpo voador, altura de voo de 12 m e envergadura padrão de 7 m no catálogo. A área de origem fica no morro, centrada em aproximadamente (-142, 25.57, -160), com extensão 80 × 37.16 × 70 m.
- `AnimalDaIlha` e `PopulacaoDeAnimais` já cuidam de perseguição, território, dano, morte, reaparecimento e nível de detalhe. O ataque genérico atual do animal não implementa este kit.
- Leitura direta do GLB: uma skin, 62 joints e articulações bilaterais de ombro, braço, antebraço e mão. Clipes nativos: `flapping`, `fly`, `gliding`, `idle`, `landing`, `leap`, `lookaround`, `sleep`. O ataque adicional atual é de garras; fechamento de asas/investida requer ação dedicada.
- `AnimadorDeAnimal` seleciona clipes por palavras-chave. As novas poses precisam de prioridade explícita para não serem substituídas por voo/planagem no quadro seguinte.
- `CombatResolver` centraliza o dano e o orçamento por conjuração. `Player.receber_arremesso()`/`PlayerArremesso` já implementam voo, queda e recuperação do jogador.
- `SandTornado` é uma referência parcial de detecção, mas seu puxão por `velocity` não mantém posse do corpo: a locomoção e a IA podem sobrescrevê-lo. A captura persistente exige um contrato próprio.
- Pets, animais, jogadores, inimigos e NPCs têm controladores diferentes. `NpcDaIlha`, por exemplo, é `StaticBody3D`; limitar a captura a `CharacterBody3D`, grupo `enemy` ou presença de `take_damage` descumpriria “qualquer ser vivo”.

## Skill 1 — Investida

### Leitura em tela

A Harpia encara o jogador e sobe ligeiramente o peito; uma corrente de ar converge para suas asas. Fecha as duas asas rente ao corpo e alinha cabeça, tronco e cauda. Dispara numa trajetória curta e rápida, com linhas de vento acompanhando o corpo e cortes curvos ao redor. Ao terminar, abre as asas para frear e volta à posição de combate.

As asas precisam realmente dobrar nas articulações. Reduzir escala do modelo ou girar o corpo inteiro não demonstra o fechamento pedido. A preparação e a abertura final continuam legíveis na câmera normal do jogador. Usar o acabamento da Ope como referência de clareza, sincronia e material, com estética própria de vento.

### Regras propostas

| Fase | Proposta inicial | Resultado observável |
|---|---|---|
| Preparação | 0,8 s | Orientação acompanha o jogador; som e vento anunciam o ataque. |
| Fixação do rumo | Últimos 0,2 s da preparação | Direção fica definida; o jogador pode escapar lateralmente. |
| Avanço | 0,6 s a 40 m/s, limite de 24 m | Asas fechadas, deslocamento do corpo por física e varredura entre posições. |
| Impacto | Uma vez por alvo e conjuração | Dano configurável e arremesso forte na direção do avanço. |
| Recuperação | 1,0 s | Asas abertas freiam; janela para contra-ataque. |
| Recarga | 8 s após a execução | Evita investidas contínuas. |

- A mira usa o centro do corpo do alvo no instante em que o rumo é fixado. O mergulho parte da altitude real do boss; medir alcance inclinado antes de disparar.
- A colisão de ataque acompanha o corpo compacto e a faixa visível de vento. Varredura contínua impede atravessar o jogador entre quadros. Os cortes de ar fazem parte da mesma investida; não criam uma sequência acidental de danos por frame.
- Proposta inicial do impacto: impulso horizontal de 32 m/s e vertical de 12 m/s, calibrado em teste real para arremesso claramente maior que um golpe comum. A distância efetiva depende do chão, da gravidade e das colisões e deve ser medida.
- A frente do arremesso deriva da trajetória da Harpia. Paredes bloqueiam a investida; encostar em cenário encerra o avanço e inicia a recuperação, sem atravessamento ou tentativa infinita de mover.
- Usar o funil de dano e depois o fluxo de arremesso existente quando o impacto for aceito. Não somar dois knockbacks por aplicar dano e arremesso separadamente. Respeitar estados de invulnerabilidade e morte já existentes. A aceitação precisa de confirmação explícita: o retorno atual de `CombatResolver.aplicar` representa dano calculado e não comprova que `take_damage` aceitou um alvo imune.
- Dano é parâmetro da habilidade. Calibrar contra a vida real do protagonista da história; “enorme knockback” não implica morte instantânea.

## Skill 2 — Tornado Vendaval

### Leitura em tela

A Harpia abre as asas e faz uma batida forte para frente. Um funil verde nasce adiante do peito e se separa dela. Faixas helicoidais de vento mostram a rotação; o núcleo permanece translúcido para permitir ver os capturados. O volume de captura acompanha o volume visível. Som de vendaval ganha intensidade durante a formação e termina junto da dissipação.

Ao capturar, o ser vivo é elevado e passa a girar com o tornado. O efeito termina com abertura das faixas de vento e lançamento dos capturados, sem desaparecer deixando corpos suspensos.

### Regras propostas

| Propriedade | Definição |
|---|---|
| Preparação | Proposta: 1,1 s de animação e aviso. |
| Duração ativa | **5,0 s a partir do lançamento**, em tempo de jogo. |
| Trajetória | Rumo frontal fixado no lançamento; sem perseguir o jogador depois. |
| Velocidade | Proposta: 8 m/s; até 40 m em espaço livre. |
| Volume | Proposta inicial: raio de captura 2,5 m e altura visual 7 m, ajustados à escala da Harpia e ao terreno. |
| Captura | Seres vivos no caminho, uma entrada por corpo; capturados permanecem até terminar o tornado. |
| Saída | Aos 5 s, lançamento para fora e para cima; proposta: 18 m/s horizontal e 8 m/s vertical. |
| Recuperação/recarga | Proposta: 1,2 s de recuperação e 15 s entre lançamentos. |

- Jogador, inimigos, pets, animais e NPCs vivos participam. Pets com camada física zero precisam de sensor próprio ou consulta espacial do registro de seres vivos; somente `Area3D` nas camadas atuais pode ignorá-los. Normalizar hurtboxes por `HurtboxDeCombate.dono_de` para não capturar um corpo duas vezes. A própria conjuradora é excluída; corpos mortos, embarcações e objetos de cenário não são capturados.
- O tornado consulta a região atravessada, incluindo alvos entre a posição anterior e a próxima. Não depende somente de sobreposição no final do quadro.
- Durante a captura, locomoção, IA, ataques e reposicionamento automático do alvo cedem o movimento ao efeito. A câmera pode continuar livre. Cada alvo tem um único responsável pelo movimento.
- Capturas seguem posições orbitais com deslocamento físico e checagem de obstáculos. Não usar `global_position` incondicional para atravessar paredes nem colisões recíprocas que empurrem todos os capturados uns contra os outros.
- O corpo físico continua protegido contra o cenário; exceções temporárias entre capturados são rastreadas e removidas na saída. As órbitas visuais podem ser reduzidas em espaço apertado sem reduzir a duração da captura.
- **Obstáculo sólido:** proposta de manter os 5 s de vida, interrompendo o avanço quando não houver espaço. O tornado continua girando ali; capturados permanecem em posições válidas e são soltos ao fim. Não transportar personagens através da parede.
- Acompanhar a altura do terreno com varredura e transição limitada, em vez de saltar entre alturas ou seguir a queda do solo sem limite. Validar encostas do morro e borda do mar.
- Ao capturar um piloto ou cavaleiro, primeiro encerrar pilotagem/montaria com uma saída própria para captura, preservando a posição atual; então capturar o personagem. O método normal de desmontar pode reposicionar o jogador, portanto não basta chamá-lo sem adaptar esse caso. Pet montado e cavaleiro são alvos vivos distintos. O barco estaciona e mantém suas colisões.
- Recolhimento de pet, troca de cena, morte/remoção da Harpia ou do alvo e respawn limpam imediatamente os vínculos. Saída excepcional restaura o corpo com segurança; o lançamento final normal pertence ao término dos 5 s.
- O lançamento precisa ser independente de `take_damage`: animais rejeitam dano zero e alguns pets ignoram o argumento de knockback. Dano contínuo não foi solicitado. A primeira fatia deve demonstrar transporte e lançamento; qualquer dano definido para esta skill fica explícito nos dados, com teto por conjuração e sem dano repetido por frame.

## Integração proposta

A Harpia continua no ciclo de animais da campanha. Um controlador de habilidades próprio assume temporariamente seu cérebro, movimento e animação, devolvendo-os na recuperação. Isso preserva território, respawn e criação pelo editor e evita acoplar o rig aviário ao sistema de boxe do Buggy.

| Responsabilidade | Arquivos/sistemas previstos |
|---|---|
| Estados, seleção de ataque, parâmetros | Novo `src/historia/bosses/harpia/combate_harpia.gd` e recurso de configuração. Estados: posicionar → preparar → executar → recuperar → reposicionar. |
| Construção e ciclo do boss | Integração pequena em `animal_da_ilha.gd`/`populacao_de_animais.gd`, habilitada para `harpia_-_animated_low_poly`. |
| Asas fechadas, mergulho, batida e recuperação | Novo controlador de pose da Harpia; integração de prioridade em `animador_de_animal.gd`; clipes editáveis quando necessário. |
| Investida e VFX | Controlador da Harpia + efeito de vento com malhas/partículas reaproveitadas. |
| Tornado e captura | Novos `tornado_vendaval.gd` e controlador de captura com adaptadores por tipo de ser vivo. |
| Recepção do jogador | Reuso de `CombatResolver`, `Player.receber_arremesso` e `PlayerArremesso`; entrada/saída de captura no fluxo de movimento. |
| Animais, pets, inimigos e NPCs capturados | Adaptadores de movimento/soltura; NPC estático precisa de caminho físico temporário, conservando sua identidade e interação. |
| Parâmetros e visualização no editor | Dados de habilidades do boss e identificação da Harpia; conferir persistência antes de expandir a ficha genérica. |

A seleção considera distância, linha de visão e espaço para executar. Proposta: investida em alcance intermediário; tornado quando há distância para sua trajetória; reposicionamento quando nenhuma opção cabe. Uma habilidade por vez; não iniciar nova investida enquanto o tornado mantém o jogador capturado. O retorno normal ao território espera o tornado completar seus 5 s. Morte, remoção de cena ou reinício explícito do encontro são cancelamentos excepcionais que liberam imediatamente os alvos; não são o término normal da habilidade.

Não criar simulação permanente para os efeitos: o tornado existe apenas enquanto ativo; o controlador do boss acompanha o LOD da população, mantendo a limpeza de capturas garantida. Reusar volumes e materiais e medir o pior caso com vários seres vivos, especialmente depois do problema recente de colisões entre barcos. O LOD atual desliga física além de 80 m e a religa ao aproximar: habilidades e capturas precisam de prioridade explícita, sem reativar a IA de uma vítima cativa. A campanha offline usa servidor local; apenas uma autoridade decide captura, órbita, dano e lançamento; cada corpo recebe esse estado pelo seu controlador autorizado, sem duas simulações concorrentes. Nenhum ganho de FPS fica presumido.

## Etapas e critérios de conclusão

1. **Auditar e preparar as poses da Harpia.** Conferir ossos, eixos, clipes existentes e deformação das duas asas na engine. Entrega: poses de preparação, asas fechadas, avanço, abertura/frenagem e lançamento do vendaval. Capturas frontal e lateral demonstram a silhueta e ausência de atravessamento das asas no tronco.
2. **Entregar a investida jogável no morro.** Controlador, preparação, deslocamento, varredura, impacto e recuperação. Teste pela IA real: jogador atingido uma vez, desvio lateral funciona, parede bloqueia, knockback tem distância medida e jogador recupera controle. Não há mordida genérica simultânea.
3. **Entregar tornado com captura do jogador.** Trajetória, relógio único de 5 s, captura sustentada, colisões, pose e lançamento. Testar entrada no início e perto do fim, morte e respawn durante a captura, passagem pelo limite de LOD, captura concorrente e remoção do tornado. Nenhum controle fica travado depois.
4. **Cobrir todos os tipos de ser vivo.** Pets, montarias, animais, inimigos e NPCs; piloto/cavaleiro; múltiplos alvos. Demonstrar que o pet não usa seu teleporte de acompanhamento durante a captura e que a saída restaura colisões e comportamento. Objetos e barcos continuam sem captura.
5. **Ajustar leitura e balanço no encontro completo.** IA alterna ataques respeitando oportunidades; VFX verde, áudio, animação, volumes e dano sincronizados. Comparar custo do mesmo encontro antes/depois, com e sem capturados. Revisão visual independente e `./validar.sh rapido`, distinguindo falhas da base de regressões novas.

Testes previstos: `test_harpia_investida.gd`, `test_harpia_vendaval.gd` e captura do encontro no mapa da história. Critérios mínimos: duração de 5 s com tolerância de um tick; uma captura por corpo; dano da investida uma vez por alvo; movimentos finitos e sem atravessar obstáculos; nenhum alvo preso após término/cancelamento; ausência de crescimento de nós/referências após várias conjurações; nenhuma alteração no comportamento da águia comum.

## Pendências de calibração

Dano de cada ataque, tempos propostos, raio/velocidade do tornado e intensidade dos arremessos serão ajustados em playtest. Esses números não alteram os requisitos confirmados: asas fechadas e grande knockback na investida; tornado verde frontal de 5 s, captura de seres vivos e lançamento ao final. A implementação deve começar pela investida completa antes de ampliar a captura para todos os controladores.
