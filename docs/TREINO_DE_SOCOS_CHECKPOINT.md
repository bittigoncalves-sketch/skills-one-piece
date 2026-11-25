# Minigame de treino de socos + instrutor — checkpoint 20/11/2026

**Pedido do dono:** minigame de treino; retirar as missões que partiam da vara de pesca; NPC instrutor no campo de treino que inicia o minigame (câmera lateral, teclas certas
no tempo, soco no boneco, partículas, tremida, reação/animação do boneco); é a PRIMEIRA missão, 500 XP por treino; a missão só ocorre uma vez, o treino se repete até o nível 3 e
depois o instrutor recusa ("a força dele excede aquele campo"). Codex: imagens do NPC, diálogo, planejamento e detalhamento (`art_src/references/treino/`). Claude: código e 3D.
**Decisões confirmadas pelo dono (20/11):** retirar TODA a cadeia; sequência de 6 teclas Z/X/C (1,2 s cada; erro/tempo = sem soco; XP 500 com ≥ 4 acertos, 250 abaixo; 0 acertos = 0);
recusa AO ATINGIR o nível 3; instrutor no centro de treino voxel.

## O que entrou
- `src/historia/treino/regras_do_treino.gd` — números e regras (XP, limite de nível, missão entregue na 1ª sessão com ≥ 1 acerto, contagem em `sistemas["treino"]`).
- `src/historia/treino/treino_de_soco.gd` — o minigame (enum de fases): congela o jogador (`is_frozen`), câmera própria ao lado do eixo jogador→boneco, prompts, soco com o clipe `punch_right/left`
  da Luta tocado direto (o nível 1 nem tem combate), contato com `luta_visual.gd` (explosão voxel), tremida de tela, boneco inclina e volta em mola, som. Esc cancela sem XP.
- `src/historia/npcs/loja_do_treinador.gd` + ficha `npc_treinador` em `npc_da_ilha.gd` — janela com "Treinar"; a recusa aparece no detalhe e na fala. Placeholder de cores até o design do Codex.
- `inicio_da_jornada.gd`: o centro de treino voxel gera o `npc_treinador` (antes gerava o ferreiro); `ModoHistoria.gd` cria o nó `TreinoDeSoco`.
- `missoes.gd`: TABELA só com `treino`. A cadeia antiga está em `aposentados/missoes_antigas/missoes_cadeia_vara_2026-11-20.gd`. Pescador, ferreiro e guarda ficam sem missão (o pescador ainda dá a vara e compra peixe).

## Testes (headless)
- `test_treino_de_soco.gd` **42/0** — tabela, regras, sessão com 6 acertos (câmera lateral, congelar, partículas, tremida, boneco reage, XP, missão), erro/tempo, cancelar/Esc, 0 acertos, repetição até o nível 3 (8 treinos) e recusa.
- `test_treino_npc_no_mapa.gd` **11/0** — mapa REAL: instrutor nasce na frente do centro, janela "Treinar", inicia o minigame, recusa no nível 3.
- Capturas reais: `art_src/validation/treino/` (UI no alto da tela, soco, explosão na altura do punho, boneco inclinado, XP no fim).

## Visual do instrutor (design do Codex, 20/11)
`art_src/references/treino/01_treinador_frente_tres_quartos.png` adaptado em `src/historia/treino/visual_do_instrutor.gd` (ficha `npc_treinador` → `vestir`): cabelo cacheado preto, barba curta,
quimono índigo (do catálogo de aparência), calça e botas escuras, faixa ocre com a ponta caindo e ataduras claras nos punhos (peças próprias, presas às juntas `Pelvis`/`Wrist_*`).
O instrutor agora encara quem chega (para fora do pavilhão; antes nascia de costas). Capturas: `art_src/validation/treino/instrutor_*.png`. Diferenças para a referência: a faixa é um bloco sobre a faixa vermelha do
quimono; o colete sem manga do Codex não existe no catálogo (usei o quimono). Pose de instruir (`02_treinador_instruindo.png`) aplicada em `POSE_GRAUS` (`pose_de_skill` fixa do NPC): base aberta, guarda esquerda, braço direito para o boneco — ângulos de ajuste visual, sem validar a leitura "apontando". NOTA: o NPC "Ferreiro" também está no pavilhão do centro (decisão pendente #47 do Codex).

## Referências do Codex aplicadas (4 de 4)
01/02 instrutor (visual e pose) · 03 interface: keycap com a tecla no alto, barra amarela que fica vermelha nos últimos 30 %, selos "BOA n / ERRO n" (a fonte pixelada não tem ✓/✗) ·
04 impacto e reação: preparação (quadro 0 do clipe do soco), contato com clarão de cubos + lascas de madeira, boneco recua inclinado e volta em mola, tremida de câmera.
Não feito de 04: imagem residual translúcida do boneco no recuo e os arcos de movimento; a tremida só foi vista em quadros isolados, não em movimento.

## Revisão do Codex (#74/#76/#78) — o que foi tratado
- **Uma só fonte de XP:** missão com `xp: 0` na tabela; `RegrasDoTreino.concluir` paga. Testado: 1ª sessão = exatamente 500, sinal repetido (`_encerrar_sessao` de novo) não paga, save→recarregar→repetir paga 500 e NÃO reentrega a missão.
- **Textos:** a janela e a oferta não prometem mais 500 garantidos ("500 / 250 / nenhum = 0"; "até 500"); falas da oferta/repetição do Codex adotadas. Resultado na tela: o centro mostra só o veredito, os números ficam no aviso da HUD (sem duplicar).
- **Save já no nível ≥ 3 sem a missão:** `migrar_save_acima_do_limite` marca a missão como entregue SEM pagar XP e roda ao abrir o Modo História (**decisão provisória minha, a confirmar com o dono**: sem ela a "?" ficaria para sempre).
- **Visual do instrutor:** cores do manequim corrigidas (o vermelho era placeholder meu), sem mangas (colete), cabelo mais volumoso, olhos/sobrancelhas ligados, cinto de coldres escondido, faixa ocre contínua com nó e ponta. Ainda: faixa alta demais (parece bloco) e rosto simples.
- **Testes antigos:** arquivados em `aposentados/missoes_antigas/tests/`: `test_bandidos_e_missao`, `test_cadeia_do_guarda`, `test_missao_provisoes`, `test_marcador_de_missao`.
  **Adaptados em 20/11:** `test_sem_espada_nem_machado` (passa), `test_sobrevivencia_integracao` (14/0, sem o bloco da forja), `test_chefes_e_capangas` (a asserção da missão de combate virou "entrada antiga é ignorada"; a verificação `controle: o chefe derrotado dá XP` é INTERMITENTE (3 rodadas com a tabela nova: falhou com 1912→96, passou, falhou com 1000→1000; 1 rodada com a tabela original passou — amostra pequena, não prova que seja anterior). `test_sobrevivencia_jornada` adaptado (32/0: bloco da cadeia trocado por conferência da campanha nova).
- **CONSEQUÊNCIA da remoção da cadeia (decisão do dono pendente):** acabaram junto a escolha de FACÇÃO (pirata/marinheiro), os 60 PÃES iniciais da jornada, a vara gratuita como missão (o pescador ainda dá a vara), a BÚSSOLA (prêmio da cadeia do guarda) e a FORJA do ferreiro (o minigame `FerrariaHud` só abria durante a missão da ferraria: hoje está INALCANÇÁVEL).

## Pendente / não validado
- **Design do NPC, falas definitivas, UI final** (Codex): hoje placeholders.
- Aprovação visual do dono (câmera, pose, intensidade do impacto); animação do boneco é mola procedural (o boneco voxel não tem clipes).
- Rede: Modo História é monoplayer; sem teste de cliente.
- Testes antigos das missões removidas: ver a seção "Testes antigos" abaixo.
- Gatilhos: mais instrutores/missões → limite e XP viram campos da ficha; segundo minigame com a mesma câmera/pose → extrair `CameraDeCena`/`PoseDeClipe`.
