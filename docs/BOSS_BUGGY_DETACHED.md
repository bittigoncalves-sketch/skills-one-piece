# Punho destacado após os jabs — incremento 4

13/09/2026. O usuário confirmou que os socos e a habilidade de corte estavam concluídos com Claude e pediu avanço do roadmap. A escolha para o próximo ataque foi **continuação dos jabs**. A implementação preserva o combo alternado, balanço do tórax, reação a M1 e corte contra quem foge.

## Comportamento na partida

Ao completar esquerda → direita → esquerda → direita, Buggy pode lançar o punho direito como quinto golpe. O finalizador exige que a mão esteja encaixada, o alvo permaneça visível e esteja a até 7 m do Boss, e a recarga própria tenha terminado. A direção é comprometida no início da preparação; o alvo pode sair da faixa vermelha.

A marca vermelha projeta o trajeto e o raio do punho, limitados pela primeira parede. A mão realmente deixa o braço: o original não continua desenhado enquanto uma cópia voa. O punho causa dano somente na ida, retorna ao primeiro acerto ou ao alcançar o limite/obstáculo, e se encaixa no pulso. O retorno não machuca quem atravessa seu caminho. Dano/controle no Boss cancela o ataque e recolhe a mão sem dano; morte/despawn encerram a parte e sua hitbox imediatamente.

| Parâmetro do finalizador | Valor |
|---|---:|
| Preparação visível | 0,55 s |
| Ida máxima | 0,45 s |
| Retorno | 0,35 s |
| Recuperação | 0,45 s |
| Pausa após o golpe | 0,85 s |
| Recarga da parte após lançamento | 6 s |
| Alcance de voo a partir do pulso | 7 m |
| Raio de contato | 0,24 m |
| Dano único / knockback / hitstun | 112 / 7 / 0,25 s |

O combo completo soma até 400 de dano: 4 × 72 + 112. Sair antes da conclusão dos jabs ou interromper o Boss continua quebrando o combo. A recarga de 6 s impede lançar a mão em todo combo; os quatro jabs continuam disponíveis quando a parte já retornou.

## Estrutura e asset

- `BodyPartDefinition.gd` e `right_hand_binding.tres` descrevem a malha de origem, o osso, o braço restante e as versões encaixada/rígida da mão.
- `tools/build_buggy_hand.gd` produz três recursos de malha com tampas, UV, materiais e skin preservados. O GLB original tem o mesmo SHA-256 da auditoria inicial.
- `BossHandBinding` apresenta o encaixe e a parte em voo. `BossDetachedAbility` contém os parâmetros. `BossDetachedAttack` mantém ida, retorno, colisão e recarga separados da ação de combate.
- `BossCombat` emenda o quinto golpe; `BossActor` continua atualizando o retorno mesmo depois que o golpe é interrompido. `BossEncounter` replica estado e transformação da parte em snapshots, incluindo entrada tardia.
- O dano reutiliza `DamageZone`, `DamageSpec`, `CombatResolver` e `SwordSweep`. Somente o servidor cria/acerta a hitbox; o cliente apresenta o estado replicado.

## Validação

- **28 verificações da parte, zero falhas**, incluindo a sequência automática da IA com física real; log `art_src/validation/buggy_detached/lifecycle.log`. Inclui combo completo, 30/60/120 Hz, ida/retorno, mão única, recarga, interrupção, paredes, obstáculo criado durante voo, retorno sem dano e morte.
- Rede ENet com quatro processos: **32 verificações, zero falhas**. Preserva checks de jab, corte e reação; acrescenta 112 de dano ao jogador remoto, separação/retorno e entrada durante o voo/apos morte. Logs em `art_src/validation/buggy_detached/network/`.
- Regressões específicas: quatro jabs **54/0**; recepção **31/0**; corte **26/0**. O teste de quatro jabs usa uma cópia da definição sem o quinto golpe; o finalizador e sua integração são medidos no teste específico.
- Capturas reais em Forward+, RTX 3050 Laptop, 1280×720: `attached`, `telegraph`, `outbound`, `returning`, `returned`, `wrist_attached`, `wrist_original` e `wrist_detached`. Inspeção do pulso e comparação antes/depois realizadas na engine.
- `./validar.sh rapido`: **76 aprovados, 10 falhas, 1 pulado** (saída 1). Os dez testes com falha são os mesmos da base completa de recepção: `test_balance`, `test_buki_buki`, `test_compila`, `test_corte_horizontal`, `test_mera_z_saque`, `test_morte_limpa_cast`, `test_ope_animacoes`, `test_studio_playback`, `test_trava_fruta_dano` e `net_mp_probe`. Comparação e logs preservados em `art_src/validation/buggy_detached/`. O relatório de corte de Claude encontrado no disco estava incompleto; por isso a comparação usa a última base completa de recepção. A suíte global continua com falhas conhecidas.

- Importação final do Godot concluída sem erros de script; novos UIDs e recursos carregados.

## Limites e continuação

Uma mão direita foi preparada e integrada. Ela não tem vida/hurtbox independente nem concede imunidade ao corpo. Na volta, a parte segue o pulso atual sem colisão ofensiva, inclusive se o Boss for deslocado. Captura de jogador, torso/cabeça/outras partes, fases de HP, recompensas e reset de encontro ainda não foram implementados. O corte já existente resolve parte do incremento 5, mas a captura e a segmentação para cortes corporais continuam pendentes.

Próximo incremento do roadmap: captura com soltura garantida por interrupção/morte, ou preparação da próxima parte exigida por esse ataque. Não há medição comparativa de FPS neste incremento; o asset original de aproximadamente 1,88 milhão de triângulos foi preservado.
