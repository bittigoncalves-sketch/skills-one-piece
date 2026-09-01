# Estudo de carga — Mera Mera no Mi

Referência: vida base de 2048. A carga é um aviso visual e uma janela de
contra-jogo; não deve existir apenas para atrasar o jogador.

| Skill | Função | Dano completo | Tempo | Regra de disparo |
|---|---|---:|---:|---|
| Z — Higan | pressão com pistolas | 8 × 25 = 200 | 0,5 s | completa a carga e inicia a rajada |
| X — Hiken | confirmação com explosão | 160 + 96 = 256 | 1,0 s | completa a carga e dispara |
| C — Vagalumes | controle de espaço | 240 → 256 | 1,0 s | completa a carga e cria 15 vagalumes |
| V — Entei | clímax de área | 512 → 640 | 1,5 s | pode ser solta antes; dano escala com o tempo |

## Critério de equilíbrio

Os máximos retiram 9,8%, 12,5%, 12,5% e 31,25% da vida base, respectivamente.
Z recompensa mira parcial por concentrar dano em oito tiros; a animação de
saque é normalizada no intervalo 0→1 e percorre todas as etapas dentro dos
0,5 s. X usa a mesma regra de progresso para completar a concentração do Hiken
em 1 s. A carga é uma janela de anúncio curta; como o C só é liberado cheio,
sua execução normal entrega 256. A criação de hitboxes ocorre somente no cast
autoritativo final.
