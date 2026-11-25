# Bara Bara no Mi — redesenho da fruta e do kit

Data: 13/09/2026. Estado: **proposta de design e plano de execução; ainda não implementados**.

Pedido atual: refazer a Bara Bara, incluindo a fruta coletável, skills, design e mecânicas, usando a Ope Ope como referência de acabamento. O usuário informou que Claude resolveu o problema anterior do Boss; esta tarefa passa a tratar da fruta do jogador. Não houve nova validação das correções do Boss nesta etapa.

A preferência entre redesenhar o kit, preservar as técnicas ou iniciar imediatamente a implementação foi perguntada e permanece aberta. A proposta abaixo desenvolve o redesenho completo para revisão. Nomes, paleta e parâmetros são propostas, não decisões já aprovadas. O kit atualmente executado continua descrito em [frutas/bara_bara.md](frutas/bara_bara.md).

## 1. Direção

**Fantasia:** desmontar o próprio corpo para alcançar, cercar, escapar e voltar à guarda. O adversário consegue acompanhar de onde cada membro sai, por onde passa e quando retorna.

Três pilares:

- **Corpo reconhecível:** mãos e seções pertencem ao avatar equipado, com suas proporções e texturas. Uma mão lançada deixa seu encaixe vazio e fechado; rastros não criam membros adicionais com dano.
- **Controle com compromisso:** usar uma parte a reserva até a recomposição. Preparação, trajetória e recuperação oferecem oportunidades de resposta ao oponente.
- **Impacto legível:** efeitos reforçam a ação corporal. Sequências mantêm o alvo ao alcance dos golpes intermediários; o golpe final concentra o lançamento.

O plano do Boss já previa separação corporal, reserva de partes e retorno. Esta proposta adapta esses princípios às quatro teclas do jogador; o repertório, as fases e os parâmetros do Boss continuam separados. Os cortes evoluídos do [plano anterior](BOSS_BUGGY_COMBAT_DESIGN.md) permanecem como expansão futura, sem ocupar automaticamente o kit inicial da fruta.

## 2. Evidência atual e referência Ope

Inspeção de arquivos nesta etapa, sem executar uma nova partida:

| Sistema existente | Evidência | Consequência para o redesenho |
|---|---|---|
| Catálogo Bara | `SkillSystem.gd`: Dismantle, Buggy Ball, Cleave, Shrine | A proposta substitui essas quatro técnicas; manter o legado comparável durante a migração. |
| Execução Bara | `src/effects/BaraFX.gd`: projéteis, hold C e domínio V | Ainda não há separação do corpo do jogador nesses golpes. |
| Entrada e rede legadas | `src/player/cast_controller.gd` e `Player.gd`: `bara_cleave_active`, `bara_v_active`, início/cancelamento de hold | Migrar também o ciclo de cast e a recarga; trocar apenas VFX deixaria regras antigas ativas. |
| Passiva | `FruitPassiveSystem.gd`: descrição de esquiva de 35%, dados de velocidade ×1,05 | A descrição de esquiva não constitui implementação. Não transportá-la como funcionalidade pronta. |
| Fruta no mapa | `TreeAndFruitGenerator.gd`: Bara fora de `PICKUPS_AUTORAIS` | Atualmente usa o corpo genérico. Há registro extensível para inserir o novo coletável. |
| Dano | `Balance.gd`, `DamageSpec.gd`, `CombatResolver.gd` | Reusar orçamento por conjuração, reserva do finalizador e autoridade do servidor. |
| Partes do Boss | `BossHandBinding.gd`, `BossDetachedAttack.gd`, `BodyPartDefinition.gd`, `tools/build_buggy_hand.gd` | Existe mão direita separada do Buggy, com malhas derivadas e retorno. Os componentes dependem do Boss; precisam de adaptação explícita para o Player. |
| Rigs | `player_rig.gd`, `CharacterVisualDefinition.gd`, modelos de `assets/models/base_v2/` | Um socket ou osso não garante uma malha separável. Auditar o avatar realmente montado antes de produzir as partes. |
| Ícones | `src/ui/SkillBar.gd`: `ICONES_POR_FRUTA` | Registrar quatro ícones na tabela existente. |
| Ope | Controller, poses, pickup, assets e documentação próprios | Transferir a coordenação entre regra, movimento e apresentação. |

Foram inspecionadas visualmente três imagens existentes: `assets/models/ope_ope/fruit_preview.png`, `multimodal/cache/ope-validation/captures/02_room_completa.png` e `06_gamma_impacto.png`. Elas mostram fruta com volume e relevos, perímetro de campo compreensível e destaque concentrado no contato. São referências históricas, não capturas novas desta versão. Não foi avaliado movimento ou áudio nesta etapa.

## 3. Fruta coletável — proposta artística

**Silhueta:** fruto arredondado e lobulado, com três faixas de gomos encaixados em alturas diferentes. Os sulcos sugerem peças que se recompõem. A assimetria do topo e a haste curva permitem reconhecer a orientação enquanto gira.

**Materiais e paleta:** casca ameixa `#713B98`, gomos magenta `#BE65AE`, relevos lilás `#E5BCEB`, haste verde `#63835B`. Casca acetinada com microtextura discreta; sulcos mais escuros e rugosos; haste orgânica sem resposta metálica. Paleta proposta própria da Bara, sem alegação de reprodução canônica.

**Detalhe:** espirais integradas aos gomos, com espessura e sombreamento; relevo acompanha a superfície e não flutua sobre ela. Costuras da fruta são arredondadas, distinguíveis das bordas de separação dos membros. Modelar curvas onde alteram a silhueta. Não há restrição universal de low poly.

**Movimento no mundo:** flutuação e giro lentos; um breve afastamento dos gomos, seguido de encaixe, apresenta a ideia de fragmentação. O movimento é cosmético e não desloca a área de coleta. Revisar tamanho e contraste ao lado da Ope sob a mesma câmera e iluminação.

Entregáveis previstos: fonte Blender editável e/ou gerador em `tools/blender/bara_bara_assets.py`, GLB em `assets/models/bara_bara/`, texturas exportadas, `src/world/BaraFruitPickup.gd` e registro em `PICKUPS_AUTORAIS`. Coleta, ocultação e respawn continuam em `TreeAndFruitGenerator`/`FruitNet`. Não reconstruir a árvore inteira para trocar a fruta.

## 4. Kit proposto

Todos os valores abaixo são pontos de partida para playtest, em metros, segundos e dano final de vida. Referência atual: 2048 HP e 180 de energia por skill. Teclas continuam Z/X/C/V no modo fruta.

| Tecla | Técnica e função | Regra principal | Dano máximo por alvo | Recarga proposta |
|---|---|---|---:|---:|
| Z | **Punho Destacado** — alcance | Mão direita avança até 7 m, atinge o primeiro alvo e retorna. | 92 | 5 s |
| X | **Pinça Bara** — ataque de flanco | Duas mãos fazem trajetórias curvas e convergem num ponto mirado a até 6 m. | 176 | 7 s |
| C | **Escape Fragmentado** — defesa | Tronco se abre em seções durante um deslocamento curto de até 2,5 m, seguido de recomposição. | 0, utilitária | 10 s |
| V | **Festival Bara** — sequência final | Dois punhos alternam quatro ataques e fecham com um impacto conjunto. | 4 × 96 + 192 = 576 | 25 s |

Somatório teórico ofensivo: **844 de dano, 41,2% de 2048 HP**, sem M1, passivas ou modificadores. Isso não representa combo garantido. Não aumentar dano para compensar golpes que não conectam: medir posicionamento, trajetória e recuperação primeiro.

### Z — Punho Destacado

Preparação de 0,24 s: apoio na perna traseira, quadril gira, ombro avança e a mão se separa. Voo de até 0,35 s; retorno de até 0,35 s; recuperação de 0,18 s. Mira compromete a trajetória no lançamento. Não persegue o alvo após disparar.

Contato usa varredura de volume com raio inicial de 0,24 m, calibrado ao tamanho da mão. Parede interrompe a ida. Um acerto por alvo/conjuração e somente na ida; retorno nunca causa dano. Reação curta proposta de 0,12 s e sem lançamento, para permitir aproximação com M1.

Erro deixa uma janela de retorno vulnerável. Dano recebido ou cancelamento recolhe a mão e encerra o dano imediatamente. O modelo precisa mostrar a mão ausente durante todo o voo.

### X — Pinça Bara

Preparação de 0,38 s com braços abertos e contrapeso no tronco. As duas mãos se destacam e percorrem arcos de aproximadamente 0,42 s, até 1,2 m para cada lado da linha central. Retorno de até 0,40 s e recuperação de 0,30 s.

O ponto de convergência fica fixo ao lançar. Cada arco colide com o cenário; o alvo pode recuar ou atravessar o espaço entre trajetórias antes do fechamento. Primeiro contato válido causa 176; a segunda mão não duplica dano no mesmo alvo. O volume máximo inicial de contato é raio de 0,28 m por mão, sujeito à revisão visual.

É um golpe conjunto, com impulso curto proposto de 3 m/s e hitstun de 0,18 s. **Não captura nem prende o adversário** nesta versão; agarramento exigiria outro contrato de controle, soltura e rede. As duas mãos precisam estar disponíveis antes do aceite.

### C — Escape Fragmentado

Preparação de 0,12 s, deslocamento de 0,30 s, recomposição de 0,28 s. Direção vem da entrada de movimento; sem entrada, usa um recuo curto. Pés acompanham o percurso no solo, enquanto as seções do tronco se afastam lateralmente. A colisão do ator percorre o caminho físico, com limite antes de paredes ou falta de apoio; não teleporta para o outro lado de um obstáculo.

Proposta de defesa: janela explícita de evasão de **0,18 s**, contida no deslocamento, reaproveitando o contrato de esquiva do jogo após auditá-lo. Início e recomposição são vulneráveis. A janela vale para golpes sujeitos à esquiva normal; não elimina supressão já aplicada, morte, queda no vazio ou regras de partida. Se esse contrato não estiver disponível, implementar e testar a regra antes de apresentar o afastamento visual como proteção real.

Requer membros recompostos e não pode começar durante stagger, captura ou queda forçada. Não funciona como cancelamento gratuito de qualquer ataque. A proposta não promete imunidade permanente a espadas nem esquiva aleatória. O bônus atual de velocidade ×1,05 pode ser mantido inicialmente; a descrição da passiva deve refletir exatamente esse comportamento. Imunidade específica a cortes depende de tipagem de dano, que não foi encontrada nos três arquivos centrais auditados, e fica fora do primeiro kit.

### V — Festival Bara

Preparação de 0,60 s: guarda ampla, punhos flutuam junto aos ombros e indicam o corredor de ataque. Distância máxima proposta de 8 m. Quatro passagens alternadas com contato planejado em 0,60 / 0,95 / 1,30 / 1,65 s; impacto conjunto em 2,10 s; retorno até 0,45 s e recuperação de 0,60 s.

São as mesmas duas mãos: cada uma deve completar ida e retorno antes de seu próximo uso. O protótipo mede a velocidade necessária nos 8 m; ajustar alcance/cadência se a leitura se perder, sem instanciar cópias físicas para ocultar o problema. Trajetórias são comprometidas por golpe, com nova preparação perceptível para qualquer correção de mira. Não há acerto materializado diretamente no alvo.

Quatro acertos de 96 sem knockback e com hitstun inicial de 0,10 s; intervalos permitem esquiva. O quinto reserva 192 do orçamento de 576 e é o único que lança: hipótese inicial de 10 m/s horizontal e 6 m/s vertical, com queda e levantamento pelo controlador existente. Ausência de contato no quinto não produz lançamento. Interromper antes dele não paga o dano reservado.

O corredor indica risco, mas só o volume percorrido pelas mãos causa dano. Cobertura bloqueia cada trajetória e o alvo pode sair lateralmente. Dano no conjurador cancela o restante e recolhe as partes. M1 fica indisponível enquanto as mãos estão comprometidas; controlar isso por disponibilidade e estado, sem acrescentar uma trava fixa de cinco segundos após a animação.

## 5. Linguagem audiovisual e HUD

| Elemento | Direção proposta | Critério de leitura |
|---|---|---|
| Separação | Bordas fechadas, filete marfim e pulso magenta breve; material original nos membros | É possível ver a lacuna e reconhecer a mão sem expor um interior oco. |
| Trajeto | Rastro curto que acompanha a mão, afinando na cauda | O rastro não parece outra hitbox e não encobre o alvo. |
| Impacto | Compressão breve, estrela assimétrica e dissipação rápida | Distinguir contato de erro; reservar maior escala ao quinto golpe do V. |
| Aviso inimigo | Área vermelha estreita derivada da trajetória, fases de preparação e contato distintas | O indicador não promete dano numa área que a mão não atravessa. |
| Retorno | Rastro mais discreto e som de encaixe | Retorno sem dano não pode parecer um novo ataque. |
| Som | Separação seca, passagem de ar, dois pesos de impacto e recomposição | Áudio posicional, vozes limitadas, sem repetir apenas o som genérico de dano. |
| Ícones | Punho separado, duas mãos convergindo, corpo aberto, sequência de punhos | Silhuetas distintas em 32 e 48 px, com tecla legível. |
| Estado | Indicação compacta de mão direita/esquerda disponível e em retorno | Explicar tentativa inválida: parte ocupada, sem apoio, supressão ou recarga. |

Quatro coreografias próprias devem mostrar preparação, ação e recuperação com apoio, quadril e contrapeso da cabeça. Não depender de dedos articulados: o Buggy atual tem mão fechada na geometria. Revisar cada animação na câmera normal, além das vistas próximas das costuras.

Sons terão fonte editável, exportação reproduzível e picos medidos; usar a Ope como comparação de volume no jogo, sem declarar qualidade equivalente apenas por igualar formato de áudio. Preservar a cor/material de dano e a reação que Claude integrou no Player e no Boss, verificando também os membros temporariamente destacados.

## 6. Contratos de implementação

**Divisão por responsabilidade.** `BaraController` em `src/combat/` coordena ações; `BaraBodyController` reserva partes; binding em `src/characters/` resolve nós, ossos e malhas de cada avatar; `BaraPoses` em `src/anim/`; `BaraVfx`/`BaraAudio` em `src/effects/`; estado de HUD em `src/ui/`. Dados de dano continuam em `Balance`; recargas usam o caminho de consulta existente em `SkillSystem` e devem concordar no Player, servidor e barra.

O binding recebe um contrato independente do Boss: dono, modelo, esqueleto, definição de partes e transformações de encaixe. Não instanciar um Boss dentro do Player nem copiar a IA para executar a fruta. Reutilizar ou extrair o necessário do punho existente com regressão do Boss. A malha direita atual do Buggy não comprova suporte à mão esquerda, tronco ou avatar base; essas variantes precisam de fonte e validação próprias.

**Estados de parte:** anexada → reservada → saindo → ativa → retornando → anexada. Reserva é atômica: X/V obtêm duas mãos ou são recusados sem consumir energia. Uma parte não pertence simultaneamente a duas ações. C usa reserva das seções do tronco e exige mãos anexadas. No primeiro kit, partes não têm vida independente; o corpo mantém sua hurtbox normal fora da janela explícita de C. Não duplicar o dano recebido por adicionar hurtboxes de mão incidentalmente.

**Autoridade:** cliente solicita slot, sequência e mira. Servidor valida modo/fruta, estado de controle, energia, recarga, disponibilidade de partes, direção finita e destino permitido. Só depois aceita, cobra uma vez e cria o cast. Rejeição não consome recurso. Cancelar depois do aceite não restitui energia nem recarga. O cooldown começa no aceite; parte em retorno continua indisponível mesmo se a recarga expirar.

**Apresentação em rede:** replicar ação, sequência, tempo inicial, fase, partes e trajetórias/transformações necessárias. Clientes apresentam; não escolhem dano ou destino autoritativo. Entrada tardia reconstrói partes já separadas sem reproduzir impactos antigos. Repetir mensagens não duplica cobrança, contato ou encaixe. Validar também no cliente dono, que recebe correções de deslocamento e queda.

**Colisão e interrupção:** varrer o volume entre posições anterior/atual, considerar paredes novas durante o voo, deduplicar contato por ator e evento. Retorno não causa dano. Se parede impedir o retorno, recolher pela trajetória válida ou dissolver/reapresentar a peça no encaixe com transição visível e sem dano, mantendo prazo limitado de limpeza. Evitar um retorno infinito tentando alcançar o dono através de geometria.

**Limpeza:** dano, supressão, troca de fruta/modo, morte, respawn e desconexão encerram o cast de forma idempotente. Desabilitar dano primeiro, liberar orçamento/referências, remover efeitos e restaurar visibilidade, materiais, pose e reservas. Na morte ou desmontagem do rig, a restauração pode ser imediata; nenhuma mão persiste ligada a um ator inválido. Todas as saídas terminam com zero partes reservadas e zero hitboxes do cast.

**Migração:** conservar `BaraFX` e documentar o caminho antigo enquanto o novo kit é testado por opção de desenvolvimento. A opção precisa ser escolhida pelo servidor para toda a partida; não usar uma variável local que deixe peers com kits diferentes. Ao adotar o kit novo, remover seus vínculos com hold C e domínio V, inclusive recarga tardia e efeitos de ambiente. Não criar dois handlers ativos para o mesmo slot. Não alterar outras frutas ou o atalho do desktop nesta etapa de planejamento.

## 7. Execução em incrementos verificáveis

| Etapa | Entrega e arquivos previstos | Dependência | Critério para concluir |
|---|---|---|---|
| 0 — Referência | Este plano; inventário de rigs e baseline em `art_src/validation/bara_bara/` | Confirmar direção do kit; conferir estado real antes de editar | Registrar quais avatares/partes existem, comportamento legado, capturas e falhas anteriores da bateria. |
| 1 — Fruta | Fonte Blender, GLB/texturas, `BaraFruitPickup.gd`, tabela do gerador | Direção visual definida | Fruta reconhecível de perto e no mapa; coleta e respawn iguais no host/cliente; original editável presente. |
| 2 — Primeira fatia jogável | Binding independente, `BaraBodyController`, `BaraController`, Z, pose, áudio/ícone inicial e opção de teste | Etapa 0; mão separável no avatar testado | Punho sai do modelo, acerta 92 uma vez, bloqueia em parede, retorna sem dano e cancela corretamente em rede. Fruta da etapa 1 equipa essa experiência. |
| 3 — Duas mãos | Mão esquerda preparada, X, reservas conjuntas e HUD | Etapa 2 | Pinça causa no máximo 176 por alvo; sem duplicação de membros/dano; trajetória lateral respeita cobertura. |
| 4 — Defesa | Seções de tronco e C, contrato de evasão/solo e descrição honesta da passiva | Etapa 2; segmentação/colisão do avatar auditadas | Janela de 0,18 s testada nos limites; fora dela toma dano; não cruza parede/buraco nem escapa de estado proibido. |
| 5 — Sequência | V, reserva do impacto final, animação de reação integrada | Etapa 3; contrato atual de arremesso auditado | Quatro acertos sem deslocamento provocado pelo golpe; quinto lança somente ao acertar; teto 576; duas mãos físicas ao longo da sequência. |
| 6 — Acabamento e adoção | Quatro ícones/sons/poses finais, launcher/captura, validador, documentação do kit atual | Etapas 1–5 | Demonstração real, testes de rede e limpeza, medição de custo visual; migrar legado somente com o kit completo verificável. |

Não estimar prazo antes da auditoria de segmentação. A disponibilidade de malhas separáveis e a composição de reações com animação são os maiores desconhecidos. Implementar uma fatia completa antes de produzir as quatro skills isoladas evita descobrir tarde que o avatar ou o protocolo não suportam a mecânica.

## 8. Plano de validação e demonstração

Comando único **a criar**, não disponível nesta entrega: `python3 tools/validate_bara.py`. Deve isolar diretórios XDG e portas, preservar logs e falhar com erros de script/shader mesmo quando o processo retorna zero. Launcher e modo de captura também são entregas futuras: `./jogar_bara.sh` e `./jogar_bara.sh -- --capture`.

Casos mínimos:

- **Combate:** Z 92, X 176, C zero, V até 576; dano por contato e não por aparência; errou/parede/retorno = zero; final interrompido não consome sua reserva; várias superfícies do mesmo ator não multiplicam o hit.
- **Cadência:** comparar 30/60/120 passos de física por segundo; medir momentos de contato, encaixe, deslocamento e ausência de impulso nos quatro primeiros golpes do V. Testar alvo que anda e esquiva, além do dummy parado.
- **Defesa:** golpe imediatamente antes, durante e depois da janela de C; testar dano ainda válido no pé/corpo conforme contrato escolhido, supressão e limite de buraco. Separação visual sozinha não deve anular dano.
- **Ciclo:** cinco ativações de cada slot, cancelamento em cada fase, troca de fruta, morte, respawn e desconexão; contagem de nós/zonas/reservas volta à base; modelo não perde mãos nem mantém overlays após restaurar.
- **Rede:** host e cliente ENet em processos reais; os dois podem conjurar; cliente recebe dano/deslocamento correto; recusa sem cobrança, repetição sem duplicação, dois jogadores usando Bara ao mesmo tempo; terceiro processo entra no meio do voo e recebe o estado atual.
- **Arte e movimento:** vistas próximas das costuras e captura da câmera normal, sob a mesma luz da Ope; sem buracos, inversão esquerda/direita, pés deslizando na preparação ou brilho cobrindo a mão. Medir distância percorrida pelo membro e continuidade do encaixe.
- **Performance:** medir tempo de CPU/GPU, draw calls, geometria e transparência na mesma câmera/cena/hardware, antes e depois, inclusive dois jogadores com partes ativas. Registrar custo do pesado modelo Buggy separadamente; não declarar otimização sem comparação.
- **Regressão:** testes pertinentes de Boss, PlayerRig, frutas, balanceamento e rede; executar `./validar.sh rapido` ao alterar runtime e comparar falhas com baseline capturado naquele momento. Os números históricos do checkpoint não substituem esse baseline.

Demonstração curta: coletar fruta → Z acerta e retorna → Z bloqueado por parede → X fecha e alvo escapa → C esquiva e recompõe → V conecta sem expulsar nos quatro primeiros e lança no último → interrupção recolhe tudo. Capturar também o observador remoto e o restabelecimento do modelo após trocar de fruta.

## 9. Checkpoint desta etapa

- Concluído: inventário direcionado do legado, contratos Ope/Boss/Player e tabelas de integração; revisão de três referências visuais locais; direção artística e kit propostos; dependências e critérios de teste definidos.
- Arquivos desta entrega: este plano e ponteiros em `docs/frutas/bara_bara.md` e `docs/frutas/README.md`.
- Validação desta entrega: 32 links locais conferidos nos três documentos, nenhum destino ausente; cálculos de dano, faixas Z/X, teto V e reserva final coerentes com `Balance` inspecionado; `git diff --check` dos documentos rastreados sem problemas. Nenhum teste de runtime comprova este kit, pois ele ainda não foi implementado.
- Próximo passo: incorporar a escolha do usuário sobre o kit; auditar segmentação dos avatares efetivos e executar etapas 0–2 para entregar fruta e Z integrados.
- Limites: sem arte Bara nova, captura nova, playtest, áudio avaliado ou benchmark nesta etapa. Qualidade comparável à Ope permanece um critério de aceitação da produção, não um resultado já demonstrado.
