# Bomu Bomu no Mi

Fruta Paramecia de teste. Ela é propositalmente enxuta: apenas **Z** e **X**;
os slots **C/V** aparecem como indisponíveis e não lançam VFX genérico.

| tecla | técnica | carga | recarga | dano | função |
|---|---|---:|---:|---:|---|
| Z | Impacto Detonador | 0,5 s | 10 s | 144–200 | explosão curta à frente, com knockback médio |
| X | Detonação Corporal | 0,5 s | 10 s | 192–256 | explosão de área maior, com knockback alto |

## Passiva — Salto Explosivo

O salto recebe multiplicador de 1,25 e cria uma explosão visual sob os pés;
o pulo duplo também usa o efeito. A passiva não causa dano: ela é mobilidade,
não um terceiro golpe escondido.

## Apresentação

O fruto é procedural voxel: casca azul-marinho, detalhes de espiral coral e
pavio amarelo/âmbar. Ao carregar, Z recolhe o punho para uma base baixa; X abre
o corpo para conter a detonação. A soltura cria a explosão âmbar, fumaça grafite
e brasas coral.

Código: `src/effects/BomuFX.gd`; dados: `SkillSystem.gd`,
`src/combat/Balance.gd` e `FruitPassiveSystem.gd`.
