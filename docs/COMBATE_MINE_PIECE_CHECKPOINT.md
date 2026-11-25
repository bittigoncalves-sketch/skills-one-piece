# Combate desarmado Mine Piece — 18/10/2026

Objetivo: substituir Z/X do item Luta por soco e soco pesado, adicionar C sequência.
Usuário confirmou Z/X/C no SOP; no mod R seleciona e Z executa. Importar assets do
mod, sem catálogo/loja. Não alterar M1, armas ou estilos especiais.

Fonte: biblioteca-de-mecanicas/fontes-locais/minepiece-v14, já descompilada localmente.
Licença declarada: All Rights Reserved; preservar atribuição e fontes locais ignoradas.
Implementação própria em Godot, sem transcrever Java.

Descobertas: kit real = estilo_de_combate_base em mapas/skills/frutas.json;
skills antigas base_soco_vendaval_z e base_quebra_chao_x. Execução/RPC existente:
KitDoBuilder → AtivacaoDoKit → Player → ExecutorDeSkill.
Mod: AttackWeakPunch, AttackStrongPunch, AttackContinue; efeito EntityStrike
(geo + animações idle1/2/3 + slash_white), poses player_animation/punch_right/left.
Golpe simples 9 de dano base, pesado 11, rajada a cada 2 ticks + final pesado.
Valores finais adaptados à escala SOP; fidelidade visual precisa de captura na engine.

Próximo: importar fontes, implementar executor especializado e ligar o catálogo;
validar dano, cancelamento, paredes, seleção Z/X/C, importação e captura visual.
