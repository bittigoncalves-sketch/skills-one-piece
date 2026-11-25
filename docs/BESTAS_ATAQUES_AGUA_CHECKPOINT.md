# Ataques de água das bestas — 08/10/2026

Pedido: substituir ataques corporais por várias bolhas simultâneas com knockback
e raio compressor de água saindo da boca. Confirmado: os dois ataques nas quatro
espécies; pacíficas reagem apenas a dano, Sea Serpent permanece hostil.

Preservar a frente recente de postura de foca, giro e mergulhos longos.
Decisão de implementação: alternar salva de cinco bolhas e raio, usando o clipe
de disparo existente, preparação visível e trajetória fixa após o disparo.
Dano passa pelo CombatResolver no servidor, parede bloqueia os dois ataques,
raio causa um acerto por alvo e é cancelado por dano/morte do atirador.

Backup anterior em `../sop-snapshots/2026-10-08-bestas-ataques-agua/`.
Evidências em `art_src/validation/bestas_mar/ataques_agua/`.
Próximo: implementar projéteis/efeitos e IA, adaptar testes de mordida para
disparo, validar rotina/postura e registrar capturas reais.
