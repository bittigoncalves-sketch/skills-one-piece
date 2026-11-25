Objetivo: seis tons de pele em ambos os sexos na escolha da campanha, mantendo o estilo atual.
Fonte: tons.json compartilhado pelo gerador SVG e pelo Godot; médio conserva o atlas anterior.
Integração concluída: seletor com prévias, persistência/migração/reset, PlayerRig, Mochila e Status. Dez novos atlas mais os dois originais. Amostras usam ColorRect para preservar sua cor após a normalização global da GUI.
Validação: importação concluída; 12 SVGs estruturalmente válidos; teste dos tons 133/133 e integração dos corpos 164/164 em Godot 4.6.3 Forward+, saída 0. Capturas dos seis tons e de ambos os corpos na campanha em art_src/validation/tons_de_pele. Logs completos na mesma pasta.
Limites: avisos de idle no respawn, recursos no encerramento e decodificação Unicode durante teste com janela; sem validação de regressão global. O erro inicial de compilação do teste foi causado pela referência estática a HistoriaHud antes dos autoloads; corrigido usando Node no teste.
Próximo passo: revisão artística pelo usuário; não há implementação pendente neste escopo.
