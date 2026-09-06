# Pika Pika no Mi — X

## Origem da referência
`skill X pika pika.mp4` — vídeo **gerado/processado por IA** (marca d'água
MINIMAX / Hailuo AI, 2944×1248, proporção cinematográfica). Não é captura crua
do jogo, embora use a HUD do jogo como semente.

## Restrição do dono (2026-09-04) — AUTORIDADE 1, vence o vídeo

> "apenas a direção da luz não está correta; os demais efeitos estão ótimos,
> desde o brilho até os sons"

Traduzindo para o schema:

- `visual.*` do vídeo → **APROVADO** como referência (brilho, cor, camadas).
- `audio.cues` do vídeo → **APROVADO** como referência.
- `movement.direction` / `movement.trajectory` do vídeo → **REJEITADO**.
  O feixe do vídeo dobra e volta em zigue-zague (visível em 2.58s, 3.44s,
  3.88s). Isso **não** é para copiar.

⚠️ Consequência prática: nenhum agente pode derivar direção, trajetória ou
ângulo deste vídeo. Se a direção for necessária, ela sai da spec do dono ou do
código — nunca da referência.

## Em aberto (o dono precisa decidir)

- Qual é a direção correta? As opções que o cânone dá para a Pika Pika X:
  - **feixe reto** que vai e não volta;
  - **Yata no Kagami** — o feixe REFLETE em pontos e muda de direção
    (o zigue-zague do vídeo pode ser uma tentativa disto, feita errado);
  - **feixe orbital** que curva ao redor do alvo.
- Dano, alcance, cooldown: `UNKNOWN` — não se lê em vídeo.

## O que o vídeo NÃO decide
Nada de gameplay. Aparência não determina comportamento (§12).

---

# SPEC DO DONO — 2026-09-04 (AUTORIDADE 1, fecha as perguntas em aberto)

> "ela vai para a esquerda depois para a direita depois esquerda novamente
> durante 3 ciclos. após isso, se houver um inimigo próximo durante os ciclos,
> o jogador cai em forma de luz em cima do inimigo gerando uma explosão. E
> detalhe: da esquerda para a direita e da direita para a esquerda o jogador
> ainda é impulsionado para frente, gerando uma skill que obtém visualização
> lateral."

## ⚠️ O X NÃO É UM FEIXE. É DESLOCAMENTO.

Isto muda a natureza do golpe e invalida a leitura anterior: quem vira luz e se
move é o **próprio jogador**, não um projétil. "A direção da luz" que estava
errada no vídeo é o **caminho do jogador**.

Confirmado pela imagem `direcionamento X skill.webp` — cena do anime: o Kizaru
(casaco 正義, embaixo) sobe por Marineford em **três segmentos de ziguezague**,
cada um mudando de lado, avançando.

## Comportamento

| fase | o que acontece |
|---|---|
| ciclos | esquerda → direita → esquerda, **3 ciclos** |
| avanço | em CADA perna do ziguezague o jogador é **impulsionado para frente** |
| câmera | o resultado é uma skill de **visualização lateral** (o zigue-zague só lê de lado) |
| finalizador | se houver **inimigo próximo durante os ciclos**, o jogador **cai em forma de luz sobre ele** e gera **explosão** |
| sem inimigo | (em aberto) o jogador termina o terceiro ciclo e aterrissa? |

## Ainda UNKNOWN — precisa do dono

- amplitude lateral de cada perna (metros)
- avanço para frente por perna (metros)
- duração de um ciclo
- raio de "inimigo próximo"
- dano da explosão, e se o mergulho tem hitbox no caminho
- se a câmera muda sozinha para lateral, ou se é só consequência do movimento

## O que continua REJEITADO do vídeo gerado
Trajetória e ângulo (§ acima). O vídeo do Hailuo dobrava o feixe como se fosse
um raio ricocheteando — a leitura correta é o JOGADOR se movendo, e isso o
vídeo não mostra.
