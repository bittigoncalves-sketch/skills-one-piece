# Corpo do Modo História — 15/11/2026

Pedido: corpo quadrado no estilo Minecraft, dedos, masculino com musculatura e feminino com seios; perguntar ao entrar na campanha.

Decisão provisória comunicada: escolher na primeira entrada e persistir no save. Saves anteriores sem `corpo` e campanhas reiniciadas pedem a escolha. Corpos vestidos, cabeça e membros em blocos, cinco dedos com três falanges por mão. A prévia usa o mesmo gerador do jogo.

Arquivos: `src/player/corpo_historia.gd` (fonte procedural editável), `src/ui/escolha_corpo_historia.gd`, integração em `player_rig.gd`, `ModoHistoria.gd`, `progressao.gd` e `serializacao_do_progresso.gd`.

Preserva os 13 papéis de animação, a cadeia detalhada, Grip/Weapon, colisão e altura do jogador. Montagem antes do `_ready` do Player via metadado por personagem. O elenco da arena segue no construtor existente. Campanha é singleplayer; não há protocolo novo de rede.

Correções atuais do usuário: feminino com braços mais finos; masculino com braços normais e musculatura só na barriga; resto como corpo base do Minecraft. Depois indicou duas referências: feminino `art_src/references/corpo_historia/feminino.png` (print 13:22:39), masculino `masculino.png` (13:23:43, armadura vermelha/dourada de silhueta larga). Aguardando alinhamento sobre proporções da armadura versus instrução anterior de corpo Minecraft normal, e se deseja apenas corpo ou também roupa/cabelo/orelhas da referência feminina. Não assumir que a armadura foi solicitada.

Validação inicial: parse do gerador e UI passaram no Godot 4.6.3; integração 133/133 (seleção real, migração sem perda de nível, dedos/rig, encaixes, remontagem, movimento/agachar, reentrada e cancelamento). Capturas iniciais na engine em `art_src/validation/corpo_historia` precisam ser atualizadas após revisão de proporções. Execução visual inicial com Compatibility apresentou shader de contorno exclusivo Forward+; repetir com renderer real. Corrigida consulta do jogador durante saída sem peer. Avisos de recursos ainda em uso ao encerrar requerem classificação. Teste de alimentação detectou gargalo fora da boca; ajuste por IK sem soltar item da mão em validação. Não afirmar aprovação artística nem regressão global.
