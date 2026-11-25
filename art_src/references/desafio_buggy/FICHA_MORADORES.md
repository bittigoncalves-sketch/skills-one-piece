# Ficha de moradores — corpo e paleta

21/11/2026. As cores abaixo são as cores existentes em `NpcDaIlha.FICHAS`, listadas para preservar identidade; cabelos são propostas visuais, não propriedades cuja implementação foi verificada. `capa` é o nome do campo do projeto e pode tingir a roupa do torso; não exige um acessório/capa 3D. Todos os moradores da vila cobertos pelo pedido devem usar corpo quadrado e altura do jogador (escala efetiva conferida no jogo), com exceção do instrutor já definido em 1,13×. Atribuições abaixo dependem de o NPC realmente pertencer à vila; não converter automaticamente instâncias de todas as ilhas.

| Tipo | Capa RGB 0–1 | Calça RGB 0–1 | Cabelo proposto | Observação |
| --- | --- | --- | --- | --- |
| `npc_comida` | (0.85, 0.65, 0.28) | (0.22, 0.16, 0.12) | castanho escuro curto | Vendedor de provisões. |
| `npc_ferreiro` | (0.30, 0.22, 0.18) | (0.15, 0.17, 0.20) | preto curto | Ferreiro. |
| `npc_pescador` | (0.95, 0.74, 0.18) | (0.13, 0.22, 0.36) | castanho grisalho | Preservar vara. |
| `npc_domador` | (0.38, 0.52, 0.22) | (0.42, 0.27, 0.14) | castanho médio | Domador, onde existir na vila. |
| `npc_vendedor_frutas` | (0.56, 0.24, 0.62) | (0.20, 0.18, 0.26) | castanho escuro | Vendedor de frutas. |
| `npc_corrida` | (0.84, 0.20, 0.17) | (0.93, 0.91, 0.86) | preto curto | Preservar bandeira. |
| `npc_vendedor_barcos` | (0.10, 0.52, 0.58) | (0.12, 0.16, 0.30) | ruivo escuro | Preservar remo. |
| `npc_missao_bandidos` | (0.20, 0.32, 0.56) | (0.26, 0.21, 0.15) | castanho escuro | Guarda da vila. |
| `npc_treinador` | (0.20, 0.20, 0.42) | (0.27, 0.19, 0.17) | cachos escuros, barba curta | Visual próprio e exceção 1,13×; não substituir sua roupa dedicada pela paleta genérica. |

`npc_barba_negra` e `npc_mestre_geppo` são personagens especiais e não se devem tratar automaticamente como moradores genéricos; preservar suas decisões e conferir localização. O mapa tem múltiplas instâncias de alguns tipos, inclusive noutras ilhas: limitar a corrida à plateia da vila, sem teleporte entre ilhas. Não há, nesta ficha, garantia de que o parâmetro de cabelo esteja exposto no rig dos NPCs: conferir antes de prometer aplicação. Testar colisão, altura, chão, cabelos, acessórios e diálogos reais por NPC, e registrar imagens de frente e em jogo.
