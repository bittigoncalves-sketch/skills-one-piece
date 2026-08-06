# 🏴‍☠️ Plano de Design: Personagens, Frutas 3D, 11 Árvores Místicas, Passivas & Sistema de Skills (Z, X, C, V)

**Projeto**: SKILLS ONE PIECE (`/home/gabriel-bitti/dev/skills-one-piece`)  
**Data de Atualização**: 2026-07-25  
**Estilo Visual**: Voxel 3D Otimizado (Blockbench / Godot 4)  
**Escopo**: Personagens (Buggy & Nami), Frutas 3D, 11 Árvores Místicas, Passivas Dinâmicas, Ranking de Facilidade de Criar Skills, 5 Frutas Iniciais com Skills Z X C V e Mecânicas Core de Combate.

---

## 📑 Sumário

1. [Visão Geral e Arquitetura](#-visão-geral-e-arquitetura)
2. [🏆 Ranking de Facilidade para Criar Skills (Z, X, C, V)](#-ranking-de-facilidade-para-criar-skills-z-x-c-v)
3. [⚡ As 5 Frutas Iniciais com Skills Completa (Z, X, C, V)](#-as-5-frutas-iniciais-com-skills-completa-z-x-c-v)
4. [⚔️ Mecânicas Core dos Scripts de Combate](#-mecânicas-core-dos-scripts-de-combate)
5. [Especificação Visual & Rigging dos Personagens (Voxel / Blockbench)](#-especificação-visual--rigging-dos-personagens-voxel--blockbench)
6. [Plano Detalhado de Animações: Buggy & Nami](#-plano-detalhado-de-animações-buggy--nami)
7. [🔮 Especificação 3D das Frutas do Diabo (Akuma no Mi)](#-especificação-3d-das-frutas-do-diabo-akuma-no-mi)
8. [⚡ Sistema de Passivas Dinâmicas (Passiva Yami Yami Atualizada)](#-sistema-de-passivas-dinâmicas-passiva-yami-yami-atualizada)
9. [🌳 Sistema das 11 Árvores Místicas de Cores Únicas](#-sistema-das-11-árvores-místicas-de-cores-únicas)
10. [Checklist de Implementação](#-checklist-de-implementação)

---

## 🏆 Ranking de Facilidade para Criar Skills (Z, X, C, V)

Organizadas da mais fácil para a mais complexa em termos de física 3D, matemática de projéteis e lógica de programação no Godot 4:

1. 🥇 **Gomu Gomu no Mi** *(Facilidade: 10/10)* — Colisão reta frontal, impulsos físicos simples e rajadas diretas.
2. 🥈 **Mera Mera no Mi** *(Facilidade: 9.5/10)* — Projéteis lineares em chamas e explosões esféricas com materiais emissivos.
3. 🥉 **Bara Bara no Mi** *(Facilidade: 9.0/10)* — Disparos de facas voadoras e partículas desmembradas em leque.
4. 🏅 **Goro Goro no Mi** *(Facilidade: 8.5/10)* — Raycasts instantâneos, colunas verticais de raio e teleporte de iluminação.
5. 🏅 **Yami Yami no Mi** *(Facilidade: 8.0/10)* — Atração gravitacional com vetores para o usuário, vórtices de desaceleração e aura de anulação.

---

## ⚡ As 5 Frutas Iniciais com Skills Completa (Z, X, C, V)

### 1. 🔴 Gomu Gomu no Mi (Paramecia)
- **[Z] Gomu Gomu no Pistol**: Estende o punho em linha reta numa rajada cinética frontal.
- **[X] Gomu Gomu no Bazooka**: Impulso duplo de dois braços com repulsão pesada de alvos.
- **[C] Gomu Gomu no Gatling**: Sequência frenética de 12 soco-projéteis contínuos.
- **[V] Gear 2 / Red Hawk**: Dash fulminante envolto em chamas com explosão ao impacto final.

### 2. 🔥 Mera Mera no Mi (Logia)
- **[Z] Higan (Pistola de Fogo)**: Disparo rápido de projéteis incandestentes com os dedos.
- **[X] Hiken (Punho de Fogo)**: Lança uma colossal esfera/punho flamejante que incinera a área mirada.
- **[C] Kagerou**: Dash elemental rápido que atravessa obstáculos deixando rastro de brasas.
- **[V] Dai Enkai: Entei**: Invoca uma esfera de fogo do tamanho de um pequeno sol que despenca explodindo a plataforma.

### 3. 🤡 Bara Bara no Mi (Paramecia)
- **[Z] Bara Bara Ho**: Lança a mão destacada empunhando punhal que retorna ao corpo.
- **[X] Bara Bara Senbei**: Dispara lâminas giratórias acopladas aos sapatos em leque frontal.
- **[C] Bara Bara Car**: Transforma a metade inferior num veículo desmembrado ultra-rápido por 4s.
- **[V] Bara Bara Festival**: Desmonta todo o corpo num furacão voador de lâminas fatiando inimigos em raio de 10m.

### 4. ⚡ Goro Goro no Mi (Logia)
- **[Z] Sango**: Feixe de raio elétrico de alta velocidade e perfuração instantânea.
- **[X] El Thor**: Invoca um pilar dos céus caindo verticalmente no ponto de impacto.
- **[C] Shunshin**: Teleporte elétrico instantâneo para a posição da mira.
- **[V] Mamaragan**: Tempestade de 8 raios caindo aleatoriamente na área ao redor.

### 5. 🌑 Yami Yami no Mi (Logia)
- **[Z] Kurouzu**: Gera campo de gravidade negra que puxa alvos distantes diretamente até as mãos do usuário.
- **[X] Black Hole**: Cria um portal de trevas no chão que desacelera e engole HP de alvos sobre ele.
- **[C] Liberation**: Expulsa destroços acumulados em onda de choque repulsiva em 360°.
- **[V] Anulação Total**: Dispara onda escura que desativa habilidades/skills de alvos próximos por 4 segundos.

---

## ⚔️ Mecânicas Core dos Scripts de Combate

### 1. 💥 Interrupção de Ataque sobre Dano (Hit-Stun / Stagger)
- Se o personagem sofrer dano enquanto estiver no estado de conjuração (`is_casting = true`), a habilidade é imediatamente cancelada com efeito visual de quebra, impedindo a execução de combos ininterruptos.

### 2. 💀 Sistema de Morte no Void (y < -40m)
- Ao cair da plataforma abaixo de `y = -40.0`, o jogador não apenas é reposicionado, mas sofre morte instantânea (`HP = 0`), executa partículas de dissolução e respawna no centro da arena.

### 3. 🚀 Knockback Dinâmico baseado no Intervalo de Vida
- A força do Knockback é inversamente proporcional à vida atual do alvo:
  $$\text{Knockback\_Final} = \text{Base\_Force} \times \left(1.0 + 2.5 \times \left(1.0 - \frac{\text{HP\_Atual}}{\text{HP\_Maximo}}\right)\right)$$
- *Efeito*: Inimigos com 100% de vida sofrem knockback normal (1.0x); inimigos com pouca vida (10% HP) são arremessados 3.25x mais longe!

---

## ⚡ Sistema de Passivas Dinâmicas (Passiva Yami Yami Atualizada)

- **Yami Yami no Mi**: **Supressão Abissal (Fruit Nullification Aura)** — Desativa temporariamente os poderes e habilidades ativas de usuários de fruta que entrarem num raio de 8 metros.

---

## 🛠️ Código GDScript Integrado

1. **[`SkillSystem.gd`](file:///home/gabriel-bitti/dev/skills-one-piece/SkillSystem.gd)**: Gerenciador com os dados das skills Z, X, C, V para as 5 frutas, fórmula de knockback por HP, interrupção por dano e supressão Yami Yami.
2. **[`Player.gd`](file:///home/gabriel-bitti/dev/skills-one-piece/Player.gd)**: Métodos `take_damage`, `die_and_respawn`, `cast_skill_slot` e `suppress_skills_temporarily`.
3. **[`src/ui/SkillBar.gd`](file:///home/gabriel-bitti/dev/skills-one-piece/src/ui/SkillBar.gd)** e **[`src/ui/Hud.gd`](file:///home/gabriel-bitti/dev/skills-one-piece/src/ui/Hud.gd)**: Atualização automática da UI das habilidades Z, X, C, V ao trocar de fruta.

---

## ✅ Checklist de Implementação

- [x] Ranking de facilidade para criar skills Z, X, C, V
- [x] Criação das skills Z, X, C, V para as 5 frutas iniciais
- [x] Passiva da Yami Yami atualizada para desativação de poderes próximos
- [x] Script de interrupção de ataques sobre dano (hit-stun)
- [x] Script de morte no Void ao cair da plataforma
- [x] Script de knockback dinâmico escalado pela barra de vida
- [x] Atualização completa dos scripts GDScript no Godot 4

---

**Status**: 🚀 **SISTEMA DE SKILLS E MECÂNICAS CORE DE COMBATE IMPLEMENTADOS COM SUCESSO**
