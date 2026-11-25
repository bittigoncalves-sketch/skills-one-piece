#!/usr/bin/env python3
"""Inventário da fonte Mine Piece v14, sem publicar frutas nem gerar golpes genéricos.

Extrai evidência, não interpreta Java: condições e custos alternativos continuam
explícitos para tradução. O item aleatório não é uma fruta e a Goro é preservada.
Uso: python3 -I tools/mine_piece/inventariar_frutas.py [--fonte DIRETORIO]
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FONTE = Path.home() / "dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14"
PREFIXO = "minepiece:item_devil_fruit_"
JAVA = Path("net/mcreator/minepiece")
ITEM = re.compile(r"MinepieceModItems\.ITEM_DEVIL_FRUIT_([A-Z_]+)\.get\(\)")
CHAMADA = re.compile(r"\b(\w+Procedure)\.execute\(")


def sha256(arquivo):
    return hashlib.sha256(arquivo.read_bytes()).hexdigest()


def mascarar(texto):
    """Preserva offsets, omitindo strings/comentários para contar delimitadores."""
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: re.sub(r"[^\n]", " ", m.group()), texto)


def fechar(texto, inicio, abre, fecha):
    nivel = 0
    for i in range(inicio, len(texto)):
        if texto[i] == abre:
            nivel += 1
        elif texto[i] == fecha:
            nivel -= 1
            if nivel == 0:
                return i
    raise ValueError(f"Delimitador sem fechamento em {inicio}")


def blocos_if(texto):
    mascara = mascarar(texto)
    for m in re.finditer(r"\bif\s*\(", mascara):
        abre = mascara.index("(", m.start())
        fim_condicao = fechar(mascara, abre, "(", ")")
        corpo = fim_condicao + 1
        while corpo < len(mascara) and mascara[corpo].isspace():
            corpo += 1
        if corpo >= len(mascara) or mascara[corpo] != "{":
            continue
        fim = fechar(mascara, corpo, "{", "}")
        yield {"condicao": texto[abre + 1:fim_condicao], "inicio": m.start(),
               "corpo_inicio": corpo + 1, "fim": fim,
               "corpo": texto[corpo + 1:fim],
               "linha": texto.count("\n", 0, m.start()) + 1}


def selecoes(texto, chave):
    resultado = []
    todos = list(blocos_if(texto))
    for fruta in todos:
        if chave not in ITEM.findall(fruta["condicao"]):
            continue
        # Algumas frutas declaram item e número no mesmo if (Kiro/Imu).
        filhos = [b for b in todos if fruta["corpo_inicio"] <= b["inicio"] < fruta["fim"]]
        if "p_selectNumber" in fruta["condicao"]:
            filhos.insert(0, fruta)
        for tecnica in filhos:
            numeros = re.findall(r"p_selectNumber\s*==\s*(\d+)\.0", tecnica["condicao"])
            if not numeros:
                continue
            nomes = re.findall(r'Component\.m_237115_\(\s*"([^"]+)"', tecnica["corpo"])
            custos = re.findall(r"\bcost\s*=\s*([^;]+);", tecnica["corpo"])
            if not nomes and not custos:
                continue
            resultado.append({"numeros": [int(n) for n in numeros],
                              "condicao_java": tecnica["condicao"].strip(),
                              "linha": tecnica["linha"], "chaves_nome": list(dict.fromkeys(nomes)),
                              "expressoes_custo": list(dict.fromkeys(custos)),
                              "passiva": "p_passive = true" in tecnica["corpo"]})
    return resultado


def despachos(texto):
    resultado = {}
    for bloco in blocos_if(texto):
        itens = ITEM.findall(bloco["condicao"])
        # Evita o if exterior que exclui o item genérico e contém todas as frutas.
        for chave in itens:
            chamadas = sorted(set(CHAMADA.findall(bloco["corpo"])))
            if len(chamadas) == 1:
                resultado[chave] = chamadas[0]
    return resultado


def inventariar(fonte):
    tag = Path("data/minepiece/tags/items/devil_fruit.json")
    itens = json.loads((fonte / tag).read_text())["values"]
    nomes = json.loads((fonte / "assets/minepiece/lang/en_us.json").read_text())
    familias = {}
    for familia in ("logia", "zoan", "paramecia"):
        caminho = fonte / f"data/minepiece/tags/items/{familia}.json"
        familias[familia] = json.loads(caminho.read_text())["values"]
    proc = fonte / JAVA / "procedures"
    referencias = {}
    for caminho in sorted(proc.glob("*.java")):
        texto_ref = caminho.read_text()
        for chave_ref in set(ITEM.findall(texto_ref)):
            referencias.setdefault(chave_ref, []).append(str(caminho.relative_to(fonte)))
    transformaveis = json.loads((fonte / "data/minepiece/tags/items/can_transform.json").read_text())["values"]
    despacho = despachos((proc / "DevilFruitSkill1Procedure.java").read_text())
    seletores = {p.name: p.read_text() for p in sorted(proc.glob("KeyChangeTechniqueDevilFruit*Procedure.java"))}
    frutas = []
    for item in sorted(itens):
        if not item.startswith(PREFIXO) or item == PREFIXO + "goro_goro":
            continue
        chave = item.removeprefix(PREFIXO)
        numero_item = item.split(":", 1)[1]
        # O v14 tem paramecia.json vazio: seu despachante usa o ramo else.
        familia = next((f for f, valores in familias.items() if item in valores), "paramecia")
        entrada = despacho.get(chave.upper())
        if not entrada:
            raise ValueError(f"Fruta sem despacho reconhecido: {item}")
        selecionaveis = []
        for arquivo, texto in seletores.items():
            for selecao in selecoes(texto, chave.upper()):
                selecao["arquivo"] = str(JAVA / "procedures" / arquivo)
                selecao["nomes_origem"] = [nomes.get(n, n) for n in selecao["chaves_nome"]]
                selecionaveis.append(selecao)
        texto = (proc / f"{entrada}.java").read_text()
        rotas = []
        for b in blocos_if(texto):
            if re.search(r"\bskill\s*==", b["condicao"]):
                rotas.append({"condicao_java": b["condicao"].strip(), "linha": b["linha"],
                              "procedimentos": sorted(set(CHAMADA.findall(b["corpo"])))})
        modelo = Path(f"assets/minepiece/models/item/{numero_item}.json")
        dados_modelo = json.loads((fonte / modelo).read_text())
        textura = dados_modelo["textures"]["layer0"].split(":", 1)[1]
        textura = Path("assets/minepiece/textures") / (textura + ".png")
        if not (fonte / textura).is_file():
            raise FileNotFoundError(textura)
        nome_original = re.sub(r"§.", "", nomes["item.minepiece." + numero_item])
        # O inglês omite modelos de Zoan; o identificador original distingue-os.
        partes = chave.split("_")
        nome = " ".join(p.capitalize() for p in partes[:2])
        if len(partes) > 2:
            nome += " · " + " ".join(p.capitalize() for p in partes[2:])
        frutas.append({"id": chave + "_mine_piece", "item_origem": item,
                       "nome": nome + " (Mine Piece)", "nome_original_en": nome_original,
                       "familia": familia, "preco": 1,
                       "estado": "aguarda_traducao", "despacho": entrada,
                       "transformavel_no_mod": item in transformaveis,
                       "referencias_ao_item": referencias.get(chave.upper(), []),
                       "selecao": selecionaveis, "rotas": rotas,
                       "modelo_item_origem": str(modelo), "textura_origem": str(textura),
                       "icone": f"res://assets/mine_piece/frutas/icones/{chave}_mine_piece.png"})
    return {"versao": 1, "obra": "Mine Piece v14", "autor": "orca",
            "licenca": "All Rights Reserved", "pagina": "https://www.curseforge.com/minecraft/mc-mods/mine-piece",
            "limites": ["selecao contem apenas ramos associados explicitamente a cada item",
                        "ramos compartilhados, passivas e transformacoes exigem auditoria separada",
                        "expressoes de custo alternativas nao sao um custo unico",
                        "nenhuma fruta deste inventario esta publicada ou implementada por ele"],
            "origem_jar": (fonte / "ORIGEM.sha256").read_text().strip(),
            "tag_origem": str(tag), "sha256_tag": sha256(fonte / tag),
            "excluidos": {"minepiece:item_devil_fruit": "item generico/aleatorio",
                          PREFIXO + "goro_goro": "ja integrada; preservar"},
            "frutas": frutas}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fonte", type=Path, default=FONTE)
    parser.add_argument("--destino", type=Path, default=RAIZ / "docs/referencias/mine_piece/frutas")
    parser.add_argument("--importar-icones", action="store_true")
    args = parser.parse_args()
    catalogo = inventariar(args.fonte)
    args.destino.mkdir(parents=True, exist_ok=True)
    arquivos = set()
    for fruta in catalogo["frutas"]:
        arquivos.update([fruta["modelo_item_origem"], fruta["textura_origem"],
                         str(JAVA / "procedures" / (fruta["despacho"] + ".java"))])
        arquivos.update(s["arquivo"] for s in fruta["selecao"])
        arquivos.update(fruta["referencias_ao_item"])
        for rota in fruta["rotas"]:
            arquivos.update(str(JAVA / "procedures" / (p + ".java")) for p in rota["procedimentos"])
        if args.importar_icones:
            from PIL import Image
            destino = RAIZ / fruta["icone"].removeprefix("res://")
            destino.parent.mkdir(parents=True, exist_ok=True)
            original = RAIZ / "art_src/mine_piece/frutas" / fruta["textura_origem"]
            original.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(args.fonte / fruta["textura_origem"], original)
            with Image.open(original) as imagem:
                imagem.convert("RGBA").resize((128, 128), Image.Resampling.NEAREST).save(destino)
    catalogo["fontes_sha256"] = {p: sha256(args.fonte / p) for p in sorted(arquivos)}
    for rel in (catalogo["tag_origem"], "assets/minepiece/lang/en_us.json",
                "data/minepiece/tags/items/can_transform.json",
                "data/minepiece/tags/items/logia.json", "data/minepiece/tags/items/zoan.json",
                "data/minepiece/tags/items/paramecia.json", str(JAVA / "procedures/DevilFruitSkill1Procedure.java")):
        catalogo["fontes_sha256"][rel] = sha256(args.fonte / rel)
    (args.destino / "catalogo_origem.json").write_text(json.dumps(catalogo, ensure_ascii=False, indent=2) + "\n")
    linhas = ["# Inventário extraído — Mine Piece v14", "",
              "Evidência de origem; **não representa técnicas implementadas**.", "",
              "| Fruta | Família | Seleções extraídas | Transformação por tag | Despacho |", "|---|---|---|---|---|"]
    for f in catalogo["frutas"]:
        linhas.append(f'| {f["nome"]} | {f["familia"]} | {len(f["selecao"])} | {"sim" if f["transformavel_no_mod"] else "nao"} | `{f["despacho"]}` |')
    (args.destino / "INVENTARIO.md").write_text("\n".join(linhas) + "\n")
    print(f'{len(catalogo["frutas"])} frutas; {sum(len(f["selecao"]) for f in catalogo["frutas"])} selecoes; {len(catalogo["fontes_sha256"])} fontes com SHA-256')


if __name__ == "__main__":
    main()
