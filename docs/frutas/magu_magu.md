# Magu Magu no Mi — Akainu

Implementada para o **Modo História** em 13/10/2026. Disponível no vendedor de frutas pelo catálogo nativo, com os mesmos caminhos de compra, consumo, progressão e HUD das demais frutas.

| Tecla | Técnica | Comportamento | Dano na história | Energia | Recarga |
|---|---|---|---:|---:|---:|
| Z | Punho de Lava | Punho projetado a 12 m/s, até 30 m; impacto explode em 2,5 m | 48,83 | 2 | 5 s |
| X | Onda de Lava | Frente de 8 m, deslocamento a 6 m/s, alcance de 24 m; um acerto por alvo | 68,36 | 3 | 7 s |
| C | Cão de Lava | Jogador vira cão de 3,2 m; movimento controlável a 12,6 m/s, imune; contato detona em 5 m | 87,89 | 3 | 10 s |
| V | Erupção | Vulcão à frente, lava avança em anéis até cerca de 9 m; campo dura 8 s | 14,65 por pulso; teto 117,19 por alvo | 5 | 25 s |

Preparação Z/X/C/V: **0,65 / 0,95 / 0,30 / 1,35 s**. Valores iniciais de balanceamento, sujeitos ao playtest do dono. O cão dura no máximo **6 segundos**, valor assumido após pergunta de alinhamento sem resposta. Colisão com inimigo termina antes; água, morte, troca de fruta e cancelamento também restauram o jogador. O C dobra a corrida de 6,3 m/s, independentemente de Shift. A altura da forma é calculada como duas vezes a altura do colisor atual do jogador, incluindo sua escala. A referência humana de 1,6 m produz cão de 3,2 m.

Água consulta `AguaDoMundo.superficie_em` (rios e oceano): a lava perde o dano imediatamente, fica cinza e desaparece em 0,65 s. Na área do V, cada trecho solidifica individualmente para preservar lava em solo seco. O vulcão também esfria e some se a água o atingir. A pedra não vira terreno permanente.

C bloqueia dano, knockback, contato do combate direcional, arremesso, captura da Harpia e congelamento recebido pela rede. A imunidade usa `magu_cao_ativo`, sem sobrescrever estados de outras frutas. O servidor envia o fim da transformação por RPC para evitar imunidade residual no cliente.

## Fontes e contratos

- `SkillSystem.gd`: identidade; `PerfilDeFrutas.da_arena`: ficha, loja, custos e recargas da história.
- `src/combat/Balance.gd`: números de dano. `MAGU_HISTORIA` contém o dano elevado pedido para a história, aplicado antes da escala do perfil. A tabela `FRUTAS` mantém as faixas da arena.
- `src/effects/magu/tecnica_magu.gd`: preparação, projéteis, varredura do percurso, dano no servidor, transformação, água e término.
- `src/effects/magu/visual_magu.gd` e `lava.gdshader`: fontes editáveis da geometria e material; cão de `mapas/modelos/dog.glb`, já existente, com clipes idle/run.
- `Player.gd`, `cast_controller.gd` e combate direcional: integração com entrada, movimento, visibilidade e imunidade.

Dano passa por `CombatResolver`, respeita defesa direcional, orçamento da conjuração, exclusão do próprio usuário e obstáculos. V aplica no máximo um acerto por alvo por pulso, mesmo sobre placas sobrepostas.

## Evidência

`tools/dev_tests/test_magu_historia.gd`: entrada real, consumo/recarga, preparação, dano Z/X, transformação, 12,6 m/s medidos, imunidade, colisão, troca, timeout, morte, água nos quatro golpes, orçamento e remoção dos efeitos.

`tools/dev_tests/net_magu_probe.gd`: dois processos, servidor publica explosão e cliente encerra C antes do timeout.

Capturas no jogo em `art_src/validation/magu/historia_{antes,Z,X,C,V,pedra}.png`, geradas por `tools/dev_tests/capturar_magu_historia.gd` com Forward+. A captura usa câmera de inspeção; não substitui playtest manual do combate.

Logs específicos e regressão geral em `art_src/validation/magu/`. A bateria geral contém falhas fora da Magu; consultar o checkpoint para o resultado da execução, sem interpretar compilação isolada como aprovação de todo o projeto.
