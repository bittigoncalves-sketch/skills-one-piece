# Como trabalhar aqui

Processo. Vale para qualquer IA que mexa neste repositório — Claude, Gemini, ou o
que vier depois.

---

## 1. Interprete o pedido como vindo de um desenvolvedor de jogos gênio

O dono é game developer e escreve como game developer: o pedido é a **intenção**,
não a especificação completa. Ele descreve o que quer **ver em tela**, e espera
que você resolva o resto.

**O que isso muda na prática:**

- *"o braço direito levantado"* não é "põe 1,4 rad no ombro". É **um resultado
  visual**, e o seu trabalho inclui descobrir o que produz esse resultado —
  inclusive descobrir que o rig estava espelhado.
- *"os tsunamis quando colidirem encerram o ataque"* não diz a velocidade, o eixo,
  nem o que fazer com os buracos do mapa. **Decida, e declare o que decidiu.**
- Quando ele diz que algo *"não está acontecendo"*, ele viu jogando. Acredite no
  relato e vá medir — não conclua que funciona porque o código parece certo.

**Declare as suposições.** Entregar sob suposição declarada é sempre melhor que
travar esperando resposta; e travar é melhor que adivinhar em coisa cara.

## 2. Sempre divida a tarefa entre agentes especializados

Regra do dono, e o motivo é concreto: **escopo fechado por arquivo** faz dois
agentes trabalharem sem disputar.

**Como dividir bem:**

- **por dono do comportamento**, não por fruta. "VFX da água" e "regras de
  recarga" são dois agentes; "Karatê Tritão" seria um só, gigante e conflitado;
- **diga a cada um o que ele NÃO pode tocar.** É o que impede o agente de VFX de
  editar o `Player.gd` que o outro está mexendo;
- **carregue o contexto no prompt.** O agente começa frio: dê a ele as medições
  que você já fez, as armadilhas relevantes, e o caminho dos arquivos. Fazer o
  agente redescobrir custa caro e ele descobre pior;
- **`docs/AGENTES.md`** tem o que todo prompt de agente precisa carregar.

⚠️ **A porta 24565 obriga série.** Dois processos Godot colidem. Agente que roda o
jogo vai **um por vez**; agente que só lê e escreve texto pode rodar em paralelo
com eles.

## 3. Verificação cega — quem conserta não deve ser quem aprova

**A lição mais cara desta base.**

Um agente consertou a pose do braço, mediu o **ângulo** (80,5°, correto) e deu
por bom. Um segundo agente, que recebeu **só** *"o braço direito deveria estar
levantado"* — sem ver o código, sem o relatório do primeiro — **reprovou**: mediu
*qual braço* e descobriu que o rig inteiro estava espelhado havia meses.

**Por que funciona:** quem escreve o conserto escolhe o sinal que vai medir, e
tende a escolher aquele em que o conserto passa. O verificador cego é obrigado a
derivar o critério do **comportamento esperado**, e por isso mede coisas que o
autor não pensou em medir.

**Quando usar:** sempre que o pedido for sobre algo **observável em tela**. Custa
um agente e paga sozinho.

## 4. Validar com número, não com adjetivo

`./validar.sh rapido` é o portão — **25 testes** hoje, e tem que fechar 0 falhas.

Mas a bateria só prova que você **não quebrou o que já existia**. O que você
construiu, prove com **sonda própria** e número:

- ✗ "o efeito ficou melhor"
- ✓ "6/6 tiros acertando, 10,20 de dano, 930 → 930 nós (delta 0)"

**Antes e depois com o mesmo instrumento.** Foi assim que a cirurgia de rig
provou que as poses simétricas ficaram **numericamente idênticas** em vez de
"parecidas".

E leia [`ARMADILHAS.md#10`](ARMADILHAS.md#10-sonda-que-não-imita-o-jogo-mede-o-vazio)
antes de escrever a sonda: acione pelo caminho que **o jogador** aciona.

⚠️ **Número prova função; imagem prova leitura.** Dois erros do V da Gura só
apareceram em captura de tela. Se o pedido é visual, olhe.

## 5. Bug achado ≠ bug consertado

Regra explícita do dono:

> "não deve ser executada nenhuma alteração sem minhas ordens; caso um bug seja
> detectado, apenas informe e adicione à lista de correção"

Bug fora do escopo vai para **`docs/LISTA_DE_CORRECOES.md`**, com:

- o que é;
- **como foi detectado** — sem isso a lista vira palpite;
- o que você **não** fez e por quê;
- a decisão pendente, quando houver mais de uma saída.

**Não conserte de passagem.** Um agente que "aproveita e arruma" transforma uma
tarefa revisável em duas tarefas misturadas.

## 6. Git é do dono

**Nenhum agente roda `git commit`, `git push`, `git checkout` ou `git add`.**

Isso já foi violado uma vez, e por isso o `git log` é conferido depois de todo
agente.

⚠️ **`git checkout` em massa é o pior deles:** reverter vários arquivos sem
conferir descarta trabalho não commitado — inclusive de **outra sessão rodando em
paralelo**, o que acontece de verdade neste repositório.

## 7. Documente na mesma tarefa

- mudou o comportamento de um slot de fruta → atualize `docs/frutas/<fruta>.md`
  **na mesma tarefa**;
- tomou decisão relevante → declare benefício, impacto futuro, manutenção,
  extensão, custo e riscos;
- adiou algo → **declare o gatilho** que obriga a revisitar;
- errou e descobriu por quê → `docs/erros.md`. O motivo do erro vale mais que o
  conserto.

**Nunca apague histórico.** Os `MUDANCAS_*.md` e `PEDIDO_*.md` guardam o porquê
de decisões antigas e as medições da época, que não se refazem. Reorganizar é
acrescentar ponteiro, não mover conteúdo.
