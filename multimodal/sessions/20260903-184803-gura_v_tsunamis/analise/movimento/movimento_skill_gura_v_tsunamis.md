# Analista de Movimento — movimento_skill_gura_v_tsunamis

- modelo: **gemini** (forçado no comando)
- duração: 86.1s
- imagens: 1
- código de saída: 0

---

### PROPRIEDADES GERAIS DO MOVIMENTO

* **Deslocamento e Pose do Personagem:** `OBSERVED` — O personagem possui **deslocamento espacial zero (0)**. Ele permanece estritamente na mesma posição horizontal/vertical e na mesma pose padrão (idle com asas) de `0.00s` a `2.80s`. Não há animação de ataque corporal ou alteração de pose visível.
* **Propagação de Efeitos (VFX):** `OBSERVED` — Todo o dinamismo e as fases da skill são representados proceduralmente por efeitos visuais. O ciclo consiste em uma onda de choque de expansão circular no solo próximo (`0.83s` a `1.20s`) e o subsequente surgimento e elevação de uma muralha de tsunami (blocos azuis) no horizonte distante (`1.10s` a `2.80s`).

---

### LINHA DO TEMPO DE MOVIMENTO

* **0.00s · START** `[OBSERVED]`
  * **Pose:** Personagem em repouso (idle), de costas para a câmera, orientado para a frente (-Z).
  * **Diferença:** Estado inicial de baseline, nenhum efeito ativo na cena.
  * **Confiança:** Alta (100%)

* **0.40s · ANTICIPATION / WINDUP** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** Nenhuma alteração visual aparente em relação a `0.00s`. Representa o período de preparação temporal antes da ativação do VFX.
  * **Confiança:** Alta

* **0.70s · ANTICIPATION / WINDUP** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** Nenhuma alteração visual aparente. Último quadro de calmaria antes do impacto.
  * **Confiança:** Alta

* **0.83s · IMPACT** `[OBSERVED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** Surgimento instantâneo de um anel concêntrico de shockwave branca no solo ao redor do personagem e linhas de rachadura/eletricidade brancas emanando de seu centro.
  * **Confiança:** Alta (100%)

* **1.10s · RELEASE** `[OBSERVED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O anel de shockwave terrestre se expande radialmente para fora. Simultaneamente, surge uma linha de blocos azuis (tsunami inicial) no horizonte (fundo da cena).
  * **Confiança:** Alta (100%)

* **1.20s · TRAVEL (VFX)** `[OBSERVED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O anel de shockwave continua sua expansão radial e começa a se dissipar. A muralha de tsunamis azul no horizonte cresce em altura e largura.
  * **Confiança:** Alta (100%)

* **1.60s · TRAVEL (VFX)** `[OBSERVED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O shockwave circular no solo dissipou-se por completo. O tsunami de blocos azuis no fundo atinge grande escala vertical e volumétrica.
  * **Confiança:** Alta (100%)

* **1.77s · RECOVERY (Personagem) / TRAVEL (VFX)** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** Completa cessação de efeitos visuais ao redor do personagem (sem shockwave residual ou partículas locais). Apenas a onda gigante no horizonte permanece ativa e em propagação.
  * **Confiança:** Alta

* **2.00s · RECOVERY (Personagem) / TRAVEL (VFX)** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O tsunami distante continua ativo e visível na mesma região do horizonte.
  * **Confiança:** Alta

* **2.40s · RECOVERY (Personagem) / TRAVEL (VFX)** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O tsunami distante permanece erguido e ativo na mesma região do horizonte.
  * **Confiança:** Alta

* **2.80s · RECOVERY (Personagem) / TRAVEL (VFX)** `[INFERRED]`
  * **Pose:** Sem alterações (totalmente estática).
  * **Diferença:** O tsunami distante permanece erguido e ativo na mesma região do horizonte.
  * **Confiança:** Alta

* **3.17s · END** `[ESTIMATED]`
  * **Pose:** Sem alterações `[ESTIMATED]`.
  * **Diferença:** Encerramento do ciclo de execução do vídeo de 3.2s. O estado final exato do tsunami neste frame é `UNKNOWN` devido à ausência do painel visual correspondente a `3.17s` na imagem de referência, mas infere-se o término ou dissipação final da skill.
  * **Confiança:** Alta
