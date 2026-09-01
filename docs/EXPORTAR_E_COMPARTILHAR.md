# Gerar o executável e mandar para outra pessoa

**Última revisão:** 2026-08-31.

---

## O que precisou ser feito uma vez

**Os export templates não estavam instalados** — sem eles o Godot não consegue
gerar executável nenhum. São 1,2 GB, da versão exata do editor (4.6.3.stable),
e ficam em `~/.local/share/godot/export_templates/4.6.3.stable/`.

```bash
curl -L -o templates.tpz \
  https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz
unzip -q templates.tpz -d /tmp/tpl
mkdir -p ~/.local/share/godot/export_templates/4.6.3.stable
cp /tmp/tpl/templates/* ~/.local/share/godot/export_templates/4.6.3.stable/
```

⚠️ **A ARMADILHA DO SNAP.** Rodando de um terminal do VSCode instalado por snap,
`XDG_DATA_HOME` aponta para `~/snap/code/259/.local/share`, e o Godot procura os
templates LÁ — não onde você acabou de instalar. O erro é claro sobre o caminho,
mas leva a reinstalar no lugar errado. A correção é dizer o caminho na hora:

```bash
XDG_DATA_HOME="$HOME/.local/share" godot --headless --path . --export-release "Linux"
```

---

## Gerar

```bash
cd ~/dev/skills-one-piece
G=~/Downloads/Godot_v4.6.3-stable_linux.x86_64
XDG_DATA_HOME="$HOME/.local/share" "$G" --headless --path . --export-release "Linux"
XDG_DATA_HOME="$HOME/.local/share" "$G" --headless --path . --export-release "Windows"
```

Sai em `~/dev/export/` — **fora do repositório**, de propósito: são ~500 MB e
não têm por que entrar no histórico do git.

| alvo | arquivo | tamanho |
|---|---|---|
| Linux | `skills-one-piece-linux/SkillsOnePiece.x86_64` | ~230 MB |
| Windows | `skills-one-piece-windows/SkillsOnePiece.exe` | ~264 MB |

### Um arquivo só, e não dois

`binary_format/embed_pck=true` embute os dados no executável. Com `false` saem
dois arquivos (`.exe` + `.pck`) que precisam ficar na mesma pasta — e o erro
clássico é a pessoa baixar só o `.exe`, abrir, e ver uma tela cinza sem
explicação. Um arquivo só custa nada e remove essa classe inteira de problema.

O `exclude_filter` do preset tira `docs/`, `tools/`, `art_src/` e `disabled/`:
não são usados em jogo e só engordariam o pacote.

---

## Mandar para a pessoa

O arquivo é grande demais para e-mail e para o WhatsApp. As opções que servem:

| onde | limite | observação |
|---|---|---|
| **Google Drive / OneDrive** | de sobra | o mais simples; gere um link "qualquer pessoa com o link" |
| **WeTransfer** | 2 GB grátis | não precisa de conta, mas o link expira em ~7 dias |
| **GitHub Releases** | 2 GB por arquivo | bom se o repositório já estiver no GitHub — o link não expira |
| **itch.io** | — | é uma loja de jogos; dá página, print e botão de baixar |

---

## O que avisar a quem vai receber

**No Windows** o SmartScreen vai barrar na primeira vez, porque o executável não
é assinado digitalmente (assinatura custa dinheiro e é anual). A pessoa precisa
clicar em **"Mais informações" → "Executar assim mesmo"**. Avise antes: sem
aviso, quase todo mundo desiste nessa tela.

**No Linux** é preciso dar permissão de execução:

```bash
chmod +x SkillsOnePiece.x86_64
./SkillsOnePiece.x86_64
```

**Para jogar junto**, veja `HOSPEDAR_PARA_FORA.md`: uma máquina cria a sala e
passa o código de sete letras; a outra digita esse código. Nada de configurar
roteador — o UPnP faz isso sozinho.

---

## Manter isto funcionando

- os templates são **por versão**. Ao atualizar o Godot, baixe os templates da
  versão nova, senão a exportação falha apontando um caminho que não existe;
- o `export_presets.cfg` **entra no git** (é configuração, tem 60 linhas). Os
  binários, não.
