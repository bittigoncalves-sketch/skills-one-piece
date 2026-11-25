# Yoru — plano de reformulação

Data: 2026-09-08. **Status: M1 + Z/X/C/V implementados em 09/09/2026; detalhes, evidências e limites em [YORU_IMPLEMENTACAO.md](YORU_IMPLEMENTACAO.md).**

Revisão 2: sequência reavaliada a pedido do dono. A seção 8 explica **como, quando, onde e por que** cada etapa ocorre, com condição de conclusão. A ordem de execução é a dessa seção; as seções 2–7 descrevem as disciplinas, não uma fila de trabalho.

Objetivo: elevar a Yoru ao padrão de acabamento que o dono aprovou na Ope Ope, com identidade de espada, excelente animação e mecânicas legíveis. Qualidade visual não implica aumentar dano. A primeira entrega é a reconstrução dos ataques básicos; as técnicas compõem a expansão proposta para o modo espada.

## 1. Diagnóstico e ponto de partida

Inspeção de código, documentação e arquivo GLB nesta revisão; não foi feita uma nova gravação dos ataques. Números históricos de animação abaixo vêm das medições registradas em [COMBATE_ESPADA.md](COMBATE_ESPADA.md), e serão medidos novamente na primeira etapa.

| Constatação | Consequência para o plano |
|---|---|
| M1 tem dois cortes: horizontal, 64 de dano/0,76 s; vertical, 96/1,00 s (`Melee.COMBO_SWORD`). | Manter o par e seus valores como ponto de comparação enquanto a coreografia é refeita. A espada continua mais lenta que o punho. |
| O GLB atual tem uma malha, 875 vértices, 508 triângulos, um material e três imagens incorporadas; 6.572.556 bytes. | Refazer a construção e a organização do asset. Contagem baixa por si só não prova má qualidade, mas a malha única dificulta trabalhar peças e acabamento separadamente. |
| O modelo não contém animações; os cortes são poses procedurais em `WeaponPoses.gd`. | Criar coreografias próprias e um caminho de reprodução verificável no rig real. |
| A documentação registra até 0,38 m de afastamento da mão esquerda ao cabo. | Resolver alcance, empunhadura e hierarquia do rig antes de polir os efeitos. |
| O `Torso` também carrega as pernas no rig descrito; girá-lo já fez o personagem inteiro rodar em bloco. | Controlar peito, base e braços separadamente; validar compatibilidade antes de qualquer mudança compartilhada de rig. |
| O dano usa sete esferas ligadas ao fio, raio 0,28 m; rastro usa `guarda` e `ponta`. | Preservar contato baseado na lâmina e acrescentar varredura entre amostras para cortes rápidos. |
| `SwordBlade.MOSTRAR_ZONAS` está ligado; impactos usam helpers de `GoroFX` e áudio genérico. | Criar apresentação própria da Yoru e tornar as esferas uma opção de diagnóstico. |
| O modo espada é local; a falha de replicação está documentada no item 54 de [LISTA_DE_CORRECOES.md](LISTA_DE_CORRECOES.md). | Tratar arma, golpe e choque no servidor como parte da entrega. |
| O startup compartilhado busca alvo até 12 m e chama avanço de força 18 (`CombatStateAttackStartup.gd`). | Dar à Yoru uma passada curta com colisão e trajetória sincronizada à animação; medir novamente o alcance efetivo. |
| O callback de startup de `Melee.golpear` verifica existência dos nós, mas não a identidade do ataque cancelado. | Risco inferido de rearmar um golpe antigo; reproduzir em teste e invalidar callbacks por sequência de ação. |
| Modo 3 equipa Yoru; Z/X/C/V hoje ficam desativados. | Técnicas nesses slots são uma ampliação explícita do sistema, com HUD e regras próprios. |

Os comentários antigos que mencionam tecla Y e timings anteriores não representam o comportamento atual. A implementação será a referência para a linha de base.

## 2. Direção artística

**Presença, domínio de distância e precisão.** A preparação mostra controle; o cruzamento da lâmina mostra velocidade; a recuperação mostra massa. Cada ataque deve ter uma silhueta reconhecível em pausa e um arco compreensível em velocidade normal.

- Lâmina negra com planos e fio legíveis contra o chão escuro. Reflexos estilizados e desgaste contido, mantendo a leitura anime do mundo.
- Guarda em cruz com volume trabalhado, metal dourado envelhecido, ornamentos definidos, pedras verdes e cabo com relevo visível em aproximação.
- Preto azulado `#111820`, ouro `#B68B42`, marfim `#E8E4CC`, verde profundo `#16785E` e verde luminoso `#A6F0B2` como paleta inicial. Ajustar sob a iluminação real da arena.
- Energia concentrada no fio e na trajetória; M1 discreto, técnicas mais expressivas, finalizador com a maior escala. Corpo e alvo continuam visíveis.
- Sem restrição estética de low poly. Curvas, biséis e ornamentos recebem geometria onde melhoram a silhueta; detalhes menores entram nas texturas.

## 3. Asset e trabalho no Blender

Criar `art_src/blender/yoru_master.blend` como fonte editável, usando o personagem base para conferir proporção e alcance dos braços. O arquivo aberto do usuário não precisa ser substituído para elaborar ou iniciar esse trabalho.

**Peças:** lâmina, fio, guarda, cabo, pomo, ornamentos e gemas. Exportar uma cena organizada em GLB com marcadores `handle`, `grip_l`, `guarda`, `ponta` e orientação do fio. `handle` permanece alinhado a `Hand_R`; `grip_l` identifica a segunda pega sem estimá-la pelo centro do cabo.

**Pipeline:** modelo provisório de proporções → prova de empunhadura e exportação no jogo → modelagem detalhada → malha de jogo com boa silhueta → UVs por material → bake de normal/oclusão quando útil → materiais estilizados → exportação → inspeção no Godot. O modelo provisório é ferramenta de teste, não a estética do asset final. Começar com atlas de 2K e materiais compartilháveis; subir resolução somente se a captura próxima revelar necessidade. Medir custo já na primeira versão equipada; definir orçamento final de geometria e materiais pela medição com vários espadachins na arena.

**Entregáveis:** fonte `.blend`, exportador reproduzível em `tools/blender/`, GLB, texturas, materiais, renders de frente/lado/detalhe e inspeção equipada. Comprimento inicial conserva os 1,38 m de lâmina atuais; qualquer alteração exige recalibrar alcance, sockets e detecção. Os valores em `YoruSword.gd` não podem continuar descrevendo a malha antiga após a troca.

## 4. Empunhadura e animação

Aplicar antecipação, ação e recuperação como fases de uma mesma coreografia. A pose começa a responder ao comando imediatamente; o intervalo até o acerto mostra a preparação.

1. Autorar o movimento no Blender sobre o rig real: pés, joelhos, quadril/peito, braços e espada. Exportar poses/clipes e marcadores de fase compatíveis com os 13 papéis atuais.
2. Usar animação autorada como base e correções procedurais para pega esquerda, apoio dos pés e adaptação de inclinação. A IK deve respeitar comprimento dos membros e direção dos cotovelos.
3. Se a pega estiver fora do alcance, corrigir postura, alvo da arma ou posição do ombro. Não esticar o braço indefinidamente para esconder incompatibilidade.
4. Conferir o adaptador voxel e cada rig skinned disponível. Mudança na hierarquia compartilhada exige regressão de locomoção, punhos e Ope; se o adaptador bastar, manter a intervenção no caminho de espada.
5. Um relógio de ação controla pose, janela ativa, rastro, som e transições. A compensação global atual de fase não deve ser transportada sem medição para os novos clipes.

**Biblioteca prevista:** guarda, sacar/guardar, locomoção com espada, dois M1, transição M1→M1, recuperação após erro, choque/recuo, defesa, reação ao acerto e quatro técnicas. Adaptar aterrissagem e interrupção para a arma não atravessar o chão nem saltar de pose.

### Os dois M1

| Ataque | Nova coreografia | Leitura e função |
|---|---|---|
| Corte horizontal | Preparação à direita; braços conduzem o fio pela frente; joelhos sustentam a base; lâmina termina à esquerda e continua brevemente por inércia. | Controla o espaço frontal próximo. Cabeça acompanha o alvo; o personagem não gira inteiro como uma peça rígida. |
| Corte vertical | A posição final do primeiro alimenta a elevação da espada; transferência de peso; descida definida; frenagem e retorno à guarda. | Golpe mais comprometido, com recuperação clara. A preparação avulsa também deve funcionar quando o combo reinicia. |

Conservar inicialmente 0,32/0,14/0,30 s e 0,40/0,16/0,44 s de preparação/ativo/recuperação. Refazer a trajetória dentro dessas fases antes de mudar velocidade. São referências experimentais, não limites artísticos definitivos: se a passagem ficar comprimida ou ilegível, ajustar o tempo e revisar junto alcance, exposição e capacidade de encadear. Manter 64 + 96 de dano na comparação inicial.

Sem retorno obrigatório à pose neutra entre os dois cortes. O buffer existente de 180 ms será revisado para aceitar a próxima intenção no fim da recuperação, sem transformar vários cliques em uma fila longa. Giro de mira limitado durante o ativo, recuperação após erro e cancelamentos definidos no controlador; trocar de modo não pode apagar uma penalidade de combate. A passada deve usar deslocamento autorizado pela física; qualquer movimento de raiz do clipe precisa acompanhar o deslocamento realmente permitido pelo cenário.

## 5. Técnicas propostas para Z/X/C/V

Nomes de design para este jogo, sem pretensão de nomenclatura canônica. Esta etapa sucede a aprovação técnica e visual dos M1; o ataque básico vertical continua sem projétil.

| Entrada | Técnica | Mecânica e coreografia | Efeito principal e contra-jogo |
|---|---|---|---|
| Z | **Corte do Horizonte** | Carregar a lâmina de lado e liberar uma única onda cortante frontal, com alcance finito. | Meia-lua de núcleo escuro e borda verde, ar deslocado nas extremidades. Preparação legível; trajetória sem perseguição; bloqueia em obstáculos sólidos. |
| X | **Passo do Predador** | Passada rápida e curta seguida de corte diagonal. Deslocamento físico com colisão; o golpe sai da posição realmente alcançada. | Rastro fino no caminho da espada e poeira nos apoios. Sem invulnerabilidade automática, travessia de paredes ou dano durante toda a passada. |
| C | **Guarda da Cruz** | Defesa frontal breve contra cortes físicos de espada, com janela inicial de aparo preciso. Um novo M1 após aparo confirmado libera a resposta curta; não atacar automaticamente. | Fagulhas no encontro das lâminas, ressonância metálica e recuo do atacante. Erro deixa recuperação; costas ficam vulneráveis. Na primeira entrega não bloqueia automaticamente frutas, explosões, projéteis ou ondas Z/V. |
| V | **Ruptura da Noite** | Preparação longa e corte descendente que lança uma frente vertical rente ao chão. Exige apoio no solo e percorre uma faixa de terreno à frente. | A faixa é anunciada antes do impacto e permite esquiva lateral. A frente termina em parede ou interrupção do solo; cada alvo recebe no máximo um acerto por uso. Efeito de ruptura é temporário. |

Os slots pertencem ao modo 3; modos 1 e 2 mantêm suas funções. HUD apresenta nome, disponibilidade, recarga e janela de resposta da guarda, incluindo controles de toque. O C é uma técnica temporal da Yoru; não pressupõe a criação de um sistema universal de bloqueio.

**Diferença entre Z e V:** Z é um projétil de trajetória livre que pode passar sobre um buraco; V depende de chão contínuo e controla uma faixa anunciada, com preparação mais comprometida. X ocupa a função de aproximação e C a de resposta defensiva. Se o protótipo não demonstrar funções distintas, revisar a técnica antes de produzir seus efeitos finais.

Balancear dano, recargas, alcance, hitstun e knockback juntos após prototipar as distâncias. A arena pune quedas: um pequeno empurrão próximo ao buraco pode valer mais que dano alto. Testar cadeias M1→técnica e técnica→M1 para evitar aprisionamento sem resposta. Não adicionar medidor de poder ou despertar nesta entrega.

## 6. VFX, som e câmera

- **Rastro:** faixa construída pela trajetória real do fio, com largura e intensidade relacionadas à velocidade, extremidades afiladas e dissipação curta. Limpar histórico ao equipar, teleportar ou interromper para evitar faixa atravessando a arena.
- **Contato:** corte em personagem, encontro de metal, pedra e erro no ar possuem respostas distintas. Impacto nasce no contato validado. Fagulhas não aparecem quando o golpe erra.
- **Ambiente:** poeira breve no apoio dos pés, fragmentos e marca temporária no solo apenas quando a técnica toca terreno. Expiração previsível e nenhum detrito com colisão alterando a partida.
- **Áudio:** gravações ou síntese próprias para sacar, preparação, dois cortes, contato, choque, aparo e técnicas. Camadas de ar, metal e grave com variações moderadas e limite de vozes simultâneas.
- **Câmera:** impulso curto e direcional no acerto confirmado, com opção de reduzir tremor/flash. Começar com ênfase de câmera, som e pós-processamento sem congelar o corpo atacante. Pausar somente a espada visível enquanto sua colisão continua avançando criaria divergência; qualquer hitstop futuro exige regra coerente entre apresentação e simulação. Evitar câmera forçada ou corte cinematográfico durante PvP.

Separar `YoruVfx` e `YoruAudio` da resolução de dano. Reutilizar infraestrutura de descarte e renderização é adequado; geometria, envelopes de movimento e assinatura sonora serão próprios.

## 7. Combate e rede

O servidor valida modo equipado, ação, sequência, estado, recarga e direção. Replica equipamento para jogadores presentes e quem entra depois; remotos exibem a mesma arma e fase. Cliente pode antecipar apresentação, mas não cria dano autoritativo.

Ao cancelar, desarmar a lâmina e invalidar todos os callbacks da sequência anterior, inclusive os que ainda aguardam o startup. Uma arma ausente não pode converter silenciosamente o golpe em soco. Testar também personagens com escala diferente de 1: hoje o timer de dano multiplica tempos pela escala, o que precisa concordar com o relógio de apresentação.

Essa identificação também vale para o encerramento: um callback antigo não pode desarmar a lâmina de uma ação nova. Interrupção encerra o deslocamento da ação e limpa sinais/efeitos pendentes, preservando a penalidade definida para aquele motivo de cancelamento.

Manter as zonas esféricas ao longo do fio e consultar o volume varrido entre poses sucessivas. Isso evita atravessar um alvo entre ticks. Descontinuidades de posição reiniciam a amostragem. Uma ação tem identidade única e deduplica acerto por alvo; dano não continua no arco de retorno.

A trajetória usada pelo servidor deve vir dos mesmos dados de pose e tempo que posicionam a espada apresentada. A prova inicial deve funcionar em servidor sem renderização: não depender da câmera, do rastro ou de atualização visual por frame para mover a colisão. A escala do personagem e correções de pega que alterem a arma precisam integrar esse contrato. Ajustes cosméticos não podem desviar a lâmina do volume que acerta.

**Decisão de arquitetura proposta para a prova:** exportar, junto da animação corporal, a curva de posição e orientação do `handle` relativa ao personagem. A simulação amostra essa curva pelo tempo da ação e pela posição física realmente alcançada; os braços acompanham as pegas por adaptação/IK. A montagem final conserva `handle` alinhado a `Hand_R`, sem criar dependência circular entre mover a arma e corrigir a mão. Se a curva exigir posição anatomicamente impossível, corrigir a autoria na etapa 1. Verificar também a pausa de hitstop existente em `Player._physics_process`: o caminho da Yoru precisa ter uma regra explícita para pausa/interrupção, em vez de manter timers de dano avançando fora do relógio do golpe.

Resolver choque entre duas lâminas ativas no servidor, uma vez por par de ações, com cancelamento e efeito replicados. Definir prioridade de choque e acerto no mesmo tick para o resultado não depender da ordem dos sinais. A guarda temporal do C possui regras próprias; não tornar a espada parada um bloqueio permanente.

Separar dados de ataques (`YoruMoveset`), transições (`YoruCombatController`), adaptação de pose e apresentação. Integrar ao controlador existente com fronteiras pequenas; evitar duplicar cooldowns, dano ou lógica de combo dentro de `Player.gd`.

## 8. Execução revisada: como, quando, onde e por quê

**Correções de ordem:** provar o rig antes de ornamentar a espada; colocar rede e cancelamento no primeiro protótipo jogável; validar durante todas as etapas. O acabamento completo vem depois que proporções, trajetória e eventos estão estáveis. As etapas abaixo substituem a sequência da primeira revisão.

“Quando” indica dependência e condição de início, não uma estimativa de dias ainda sem base. Ao terminar a prova de rig e exportação será possível estimar esforço com mais confiança. Uma etapa termina por evidência, não por tempo gasto nela.

### Etapa 0 — Registrar o problema atual

- **Como:** gravar horizontal, vertical e sequência em velocidade normal e lenta; amostrar mãos, ponta, orientação do fio e janelas de dano. Reproduzir equipar/atacar com host e cliente e registrar o avanço automático atual. Medir custo da cena sem os novos assets.
- **Quando:** antes da primeira alteração de implementação. O estudo documental já feito orienta a captura, mas não a substitui.
- **Onde:** arena real no Godot; testes em `tools/dev_tests/test_espada_yoru.gd` e `test_corte_horizontal.gd`; evidências previstas em `multimodal/cache/yoru-validation/`. Fontes de diagnóstico: `Melee.gd`, `SwordBlade.gd`, `WeaponPoses.gd` e `Player.gd`.
- **Por quê:** separa movimento ruim, falha de contato e falha de rede; permite comparar o resultado nas mesmas condições e impede tratar uma medição antiga como atual.
- **Entrega / saída:** vídeo inicial, tabela de medidas e lista de falhas reproduzidas. Problemas apenas suspeitos ficam identificados como hipóteses.

### Etapa 1 — Provar proporção, pega e caminho de animação

- **Como:** montar uma Yoru provisória com dimensões e marcadores corretos, junto ao personagem real. Criar guarda, preparação, cruzamento e final do corte; exportar uma sequência curta e reproduzi-la no jogo. Resolver pega esquerda e controle independente de braços/base. Provar também como a mesma trajetória será amostrada na física do servidor. Definir os dados compartilhados: modo/arma, identidade da ação, golpe, início, fases, direção, trajetória e motivo de cancelamento.
- **Quando:** após a etapa 0 e antes de escultura detalhada, texturas finais ou produção da biblioteca inteira de animações.
- **Onde:** Blender em `art_src/blender/yoru_master.blend`; exportação em `tools/blender/`; integração em `src/items/YoruSword.gd`, `src/player/player_rig.gd` e adaptadores de `src/anim/`. Esses caminhos delimitam áreas de trabalho; novos módulos ainda serão criados.
- **Por quê:** o cabo, o alcance dos braços e a orientação da lâmina determinam a coreografia. Corrigir essas relações depois de finalizar o modelo e os clipes obrigaria a refazer ambos. Um clipe bonito no Blender só serve se conservar a pose ao chegar ao Godot.
- **Entrega / saída:** proporções e marcadores estáveis; sequência importada funcionando; meta de erro da mão esquerda de até 3 cm na pega fechada para escala 1, ajustada proporcionalmente para outras escalas. Sem esticar membros nem atravessar o corpo. Se o rig impedir a meta, resolver a postura ou o adaptador nesta etapa.

### Etapa 2 — Fazer os dois M1 funcionarem de ponta a ponta

- **Como:** ligar versões preliminares de horizontal/vertical ao comando, fases, passada curta, varredura do fio e recuperação. Cada ataque recebe uma sequência que permite confirmar e cancelar a ação. O servidor valida equipamento e golpe; clientes mostram a mesma fase. Implementar choque e invalidação dos callbacks antigos junto desse caminho.
- **Quando:** depois da prova de rig. Pode ocorrer ao lado do trabalho artístico da etapa 3, desde que dimensões, marcadores e formato dos dados permaneçam estáveis.
- **Onde:** Godot, em `src/combat/`, `src/player/melee_controller.gd`, `src/player/hsm/CombatStateAttackStartup.gd` e pontos de rede de `Player.gd`; host sem renderização e cliente visível em processos separados.
- **Por quê:** produzir a coreografia inteira sobre um golpe que o servidor interpreta como soco deixaria a animação apoiada na lógica errada. Rede, contato e cancelamento influenciam diretamente quando a lâmina pode avançar e acertar.
- **Entrega / saída:** dois M1 preliminares jogáveis em rede, 64 + 96 de dano na condição de referência sem modificadores, um acerto por alvo/golpe, nenhum dano no retorno e nenhuma reativação após interrupção. A física obtém a trajetória sem depender do FPS de renderização.

### Etapa 3 — Produzir o modelo e a coreografia finais

- **Como:** detalhar lâmina, guarda, cabo, gemas e materiais; refinar os dois cortes com antecipação, aceleração, continuação por inércia e recuperação. Trabalhar ligação entre ataques, poses de entrada/saída, passos e reação ao choque. Conferir continuamente a espada equipada e os cortes sem partículas.
- **Quando:** arte detalhada pode começar após a etapa 1; ajuste final de animação depende dos eventos e da passada testados na etapa 2. As duas frentes convergem antes de avançar para acabamento de efeitos.
- **Onde:** Blender para fonte, UVs e animação; `assets/models/weapons/` e recursos de animação para exportação; `src/anim/` para reprodução e adaptação; arena real para leitura de silhueta e materiais.
- **Por quê:** é aqui que se constrói a qualidade visual principal. A espada precisa ter forma e material convincentes, e o corpo precisa sustentar o movimento. Detalhe de superfície não resolve uma pega solta ou um arco sem peso.
- **Entrega / saída:** asset final editável e exportável; horizontal e vertical reconhecíveis em velocidade normal; mãos acompanhando as pegas; pés firmes nos intervalos de apoio; fim do horizontal alimentando o vertical. Importação final conserva escala, marcadores e contato medidos. Conferência inicial de custo com várias espadas.

### Etapa 4 — Dar acabamento ao combate básico

- **Como:** construir rastro na trajetória do fio, impactos por tipo de contato, sons próprios e resposta de câmera. Usar eventos confirmados para acerto/choque; usar o movimento para som de corte no ar. Ajustar duração, intensidade e descarte de cada efeito.
- **Quando:** depois que etapas 2 e 3 convergirem. Estudos de cor e som podem acontecer antes, mas sincronização e efeitos finais precisam do arco definitivo.
- **Onde:** módulos previstos `YoruVfx` e `YoruAudio` em `src/effects/`, seguindo a organização dos efeitos e áudios específicos já presentes; shaders em `src/fx/shaders/`; integração de câmera e opções em seus componentes existentes. Inspeção na câmera normal de jogo e em aproximação.
- **Por quê:** o efeito torna velocidade, contato e peso perceptíveis. Sua posição e tempo dependem da trajetória; fazê-lo antes levaria a compensar falhas da animação e refazer rastros quando o arco mudasse.
- **Entrega / saída:** primeiro pacote completo de Yoru com os dois M1, visual e rede. Rastro preso à lâmina, impacto no contato e alvo visível; cortar o ar tem resposta distinta de acertar. Vídeo curto permite revisar esse marco separadamente das técnicas.

### Etapa 5 — Construir as técnicas, uma de cada vez

- **Como:** cada técnica passa por mecânica simples → coreografia → detecção/rede → VFX/som → ícone, recarga e toque → teste. Ordem de produção: **X, Z, C, V**, diferente da ordem das teclas. Primeiro obter a função, depois finalizar sua apresentação.
- **Quando:** após o pacote básico da etapa 4. Concluir e testar uma técnica antes de acumular quatro implementações incompletas. Os limites de dano, recarga e deslocamento já entram no protótipo; o ajuste conjunto ocorre na etapa 6.
- **Onde:** Godot em dados/controlador da Yoru, detecção e rede; Blender para coreografias ou malhas específicas; módulos próprios de VFX/áudio; `src/ui/SkillBar.gd` e controles de toque para apresentação das ações.
- **Por quê:** X aproveita a passada e o corte já resolvidos; Z estabelece o caminho de projétil; C exige regras de aparo além do choque; V combina coreografia mais comprometida, terreno e maior apresentação. Essa ordem reduz a quantidade de sistemas novos sendo depurados ao mesmo tempo.
- **Entrega / saída:** quatro ações distintas, acionáveis em desktop/toque e verificadas com host/cliente, incluindo erro, interrupção, parede e borda. HUD acompanha cada técnica desde sua integração; não fica para o fim.

| Técnica | Como acontece no jogo | Quando o evento principal ocorre | Onde atua | Por que existe / condição de teste |
|---|---|---|---|---|
| X — Passo do Predador | Preparação curta, avanço físico, corte diagonal e recuperação. | Dano só na fase de corte; avançar não é por si só um ataque. | Percurso curto à frente; parede limita a passada. | Aproximar com compromisso. Posição final, animação e fio devem concordar mesmo quando o avanço é bloqueado. |
| Z — Corte do Horizonte | Preparação lateral e liberação de uma onda de trajetória livre. | Projétil nasce no marcador de liberação; efeitos acompanham esse evento. | À frente, com alcance finito; pode cruzar vazio, termina em obstáculo sólido. | Pressionar a distância. Não perseguir alvo nem somar dano de lâmina e projétil por acidente. |
| C — Guarda da Cruz | Entrar em guarda, aparar no início da janela e permitir M1 de resposta após confirmação. | Aparo depende do contato frontal na janela precisa; contato posterior usa a regra de defesa normal definida para a técnica. | Região frontal próxima, contra cortes físicos de espada. | Recompensar leitura do adversário. Definir na tabela da ação janela, cone, defesa tardia, recuperação e duração da oportunidade de resposta antes de produzir VFX. |
| V — Ruptura da Noite | Anunciar uma faixa, preparar a espada e lançar a frente de corte rente ao terreno. | Dano acompanha a frente que se propaga, após o aviso. | Solo contínuo à frente; parede ou buraco encerra a frente. | Controlar uma faixa previsível com oportunidade de esquiva. Um acerto por alvo e nenhum dano em toda a faixa antecipadamente. |

### Etapa 6 — Ajustar o conjunto em combate e sob carga

- **Como:** jogar sequências de M1 e técnicas, comparar acerto/erro, alcance, duração de controle e expulsões da arena. Ajustar dano, recarga, knockback e recuperação em conjunto. Medir CPU/GPU com um e oito usuários simulados, testar variação de FPS, latência, rig e controles de toque.
- **Quando:** verificações menores acompanham todas as etapas; esta rodada completa acontece quando as quatro técnicas funcionam. Se um ajuste alterar o tempo ou o alcance, revisar novamente animação, rastro e aviso correspondentes.
- **Onde:** arena de treino e partida com dois processos; cenas de carga reproduzíveis; dados de movimentos, integração em `Balance.gd`, testes em `tools/dev_tests/` e HUD desktop/toque.
- **Por quê:** ações boas isoladamente podem criar um combo sem saída, empurrão excessivo ou muitos efeitos simultâneos. A qualidade precisa se manter durante uma partida, além da demonstração de um único golpe.
- **Entrega / saída:** valores de combate registrados, respostas defensivas verificadas, custo medido contra a linha de base e ausência de regressões nos caminhos afetados. Quedas de desempenho têm causa identificada e orçamento ajustado; não basta declarar um FPS sem condições de teste.

### Etapa 7 — Fechar a entrega com evidência reproduzível

- **Como:** executar a validação final sobre os assets e código efetivamente entregues, gravar antes/depois nas mesmas condições e documentar controles, limites e formas de reproduzir os testes. Conferir exportação do Blender para o recurso carregado pelo jogo.
- **Quando:** após os critérios da etapa 6. Esta etapa consolida verificações anteriores; não é o primeiro momento em que o combate será testado.
- **Onde:** documentação da Yoru em `docs/`, fonte em `art_src/`, recursos finais em `assets/`, roteiro em `tools/` e evidências em `multimodal/cache/yoru-validation/`. Os nomes ainda propostos não significam arquivos já criados.
- **Por quê:** permite avaliar a melhoria, repetir a captura e continuar trabalhando no asset sem depender de uma sessão específica do Blender ou de uma configuração manual perdida.
- **Entrega / saída:** pacote completo, vídeo comparativo, relatório de testes e limitações explícitas. Nenhum sistema é declarado concluído apenas porque um render isolado ficou bonito.

### Responsabilidades e trabalho em paralelo

Rig/animação conduz a etapa 1; combate/rede conduz a 2; arte 3D e animação dividem a 3; VFX/áudio conduz a 4; combate, animação e UI cooperam na 5. A integração revisa as saídas em cada encontro. Durante a execução, especialistas recebem escopos de arquivo delimitados, conforme [AGENTES.md](AGENTES.md).

O paralelismo principal é **lógica da etapa 2 + modelagem da etapa 3**, depois de estabilizar a pega na etapa 1. Dimensões, marcadores, origem/eixos, relógio e eventos de ação são o acordo entre essas frentes. Uma mudança nesse acordo retorna aos testes afetados antes de prosseguir; não invalida silenciosamente o trabalho da outra frente.

### Evidência exigida

- Capturas na mesma câmera, luz e distância, antes/depois, em 1× e câmera lenta. Inspecionar também sem rastro: partículas não substituem uma animação legível.
- Amostrar posições de mãos, fio e pés durante o ciclo inteiro. Medir deslizamento de um pé apenas no intervalo em que está plantado; meta inicial de até 3 cm. Metas são propostas, não resultados já obtidos.
- Verificar corte horizontal e vertical, alvos na guarda/meio/ponta, duas lâminas se cruzando, ação iniciada sobre alvo e passagem rápida entre ticks. Rodar render em 30/60/120 FPS com a mesma física e comparar acertos.
- Testar com servidor e cliente reais: equipar, entrada tardia, ataque, choque, aparo, morte e troca de modo; mensagens repetidas ou atrasadas não duplicam dano nem ressuscitam um golpe cancelado. Incluir latência e jitter controlados.
- Ensaiar próximo a parede, desnível e buraco, com dois alvos e vários jogadores; registrar dano, deslocamento e possibilidade de escapar de sequências.
- Medir CPU/GPU e percentis de frame time com um e oito usuários de espada simulados, incluindo técnicas simultâneas, na mesma máquina/cena da linha de base. Definir teto após medir; não prometer FPS absoluto sem esse perfil.
- Executar os testes existentes `test_espada_yoru.gd` e `test_corte_horizontal.gd`, atualizando apenas expectativas que a nova especificação realmente substitui. Acrescentar testes de comportamento para varredura, rede e interrupções; compilar e executar os caminhos afetados.
- Conferir regressões de modo fruta, punhos, Ope, HUD de toque e rigs disponíveis. Rig ausente é limitação explícita, não teste aprovado.

## 9. Definição de concluído

A entrega inclui fonte Blender editável, assets finais, animações, técnicas, áudio, efeitos, integração de rede, HUD, captura reproduzível e relatório de validação. A Yoru deve ser reconhecível pela silhueta, pelo gesto e pelo som, com a mesma precisão entre aquilo que aparece e aquilo que acerta.

**Primeira prioridade de execução: empunhadura + horizontal + vertical.** Só depois de esse conjunto sustentar a qualidade sozinho, expandir a apresentação e o repertório.
