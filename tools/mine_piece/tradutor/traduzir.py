"""TRADUTOR de procedures do Mine Piece (Java/MCreator) → GDScript — E0 de
docs/MINE_PIECE_COMPLETO_MEDICAO.md (23/10/2026).

Decisão do dono: "camada Minecraft + tradutor". A procedure traduzida chama a API do Minecraft com os
MESMOS nomes (getX, hasEffect, getPersistentData...): quem os implementa é a camada `src/minecraft/`
(classe `Mc` e adaptadores). O que o tradutor não sabe mapear vira chamada genérica da camada
(`Mc.novo`, `Mc.estatico`, `Mc.campo`), que compila, e entra no RELATÓRIO de pendências — a lista do
que a E1 tem de implementar.

  • nomes SRG → oficiais (`srg_oficial.py`);  • lambdas e classes anônimas → variáveis locais
    `var _lambda_N = func(...)` na linha de antes (GDScript captura por valor; Java exige captura
    efetivamente final — mesmo comportamento);  • `x instanceof T apelido` → `Mc.e(x, &"T")` e o
    apelido volta a ser `x`;  • chamada entre procedures → `Mc.proc(&"Nome").execute(...)`.

    .venv/bin/python tradutor/traduzir.py [--so NomeProcedure] [--saida DIR] [--relatorio ARQ.json]
"""
import argparse
import collections
import json
import os
import re
import sys

from tree_sitter import Language, Parser
import tree_sitter_java as tsj

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
from srg_oficial import mapa, traduzir as desofuscar  # noqa: E402

FONTES = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece/procedures")
SAIDA = os.path.join(AQUI, "..", "..", "..", "src", "minecraft", "gerado", "procedures")

PALAVRAS_GD = {"and", "or", "not", "in", "is", "as", "func", "var", "const", "signal", "match", "when", "pass",
               "self", "super", "class_name", "extends", "elif", "await", "yield", "preload", "load", "breakpoint",
               "tool", "enum", "static", "void", "PI", "TAU", "INF", "NAN", "range", "len", "str", "print", "int",
               "float", "bool", "name", "set", "get", "abs", "min", "max", "sign", "floor", "ceil", "round",
               "sqrt", "pow", "sin", "cos", "tan", "randf", "randi", "type", "assert", "trait", "namespace"}
## Palavras RESERVADAS do GDScript: um método/campo Java com esse nome (`getType().is(...)`) ganha
## `_` no fim — a camada implementa `is_`. Variáveis evitam também as funções embutidas (PALAVRAS_GD).
RESERVADAS_GD = {"and", "or", "not", "in", "is", "as", "if", "elif", "else", "for", "while", "match", "when",
                 "break", "continue", "pass", "return", "class", "class_name", "extends", "signal", "func",
                 "static", "const", "enum", "var", "breakpoint", "preload", "await", "yield", "assert", "void",
                 "self", "super", "PI", "TAU", "INF", "NAN", "namespace", "trait"}
TIPOS_PRIMITIVOS = {"double": "float", "float": "float", "int": "int", "long": "int", "short": "int",
                    "byte": "int", "boolean": "bool", "String": "String", "char": "String"}
MATH = {"min": "min", "max": "max", "abs": "absf", "sqrt": "sqrt", "sin": "sin", "cos": "cos", "tan": "tan",
        "asin": "asin", "acos": "acos", "atan": "atan", "atan2": "atan2", "pow": "pow", "floor": "floor",
        "ceil": "ceil", "toRadians": "deg_to_rad", "toDegrees": "rad_to_deg", "exp": "exp", "log": "log",
        "signum": "sign", "hypot": "Mc.hypot", "round": "Mc.math_round", "random": "randf", "cbrt": "Mc.cbrt",
        "floorMod": "Mc.floor_mod", "log10": "Mc.log10", "floorDiv": "Mc.floor_div"}
## Métodos de String (e Object) do Java sem equivalente direto: alvo, args → GDScript.
STRING_JAVA = {
    "equals": lambda a, x: f"Mc.iguais({a}, {x})",
    "equalsIgnoreCase": lambda a, x: f"Mc.iguais_sem_caixa({a}, {x})",
    "isEmpty": lambda a, x: f"Mc.vazio({a})",
    "isBlank": lambda a, x: f"str({a}).strip_edges().is_empty()",
    "toLowerCase": lambda a, x: f"str({a}).to_lower()",
    "toUpperCase": lambda a, x: f"str({a}).to_upper()",
    "trim": lambda a, x: f"str({a}).strip_edges()",
    "startsWith": lambda a, x: f"str({a}).begins_with({x})",
    "endsWith": lambda a, x: f"str({a}).ends_with({x})",
    "substring": lambda a, x: f"Mc.substring({a}, {x})",
    "charAt": lambda a, x: f"str({a})[{x}]",
    "toString": lambda a, x: f"str({a})",
    "hashCode": lambda a, x: f"hash({a})",
    # Number.xxxValue(): o número do GDScript já é primitivo.
    "intValue": lambda a, x: f"int({a})",
    "longValue": lambda a, x: f"int({a})",
    "doubleValue": lambda a, x: f"float({a})",
    "floatValue": lambda a, x: f"float({a})",
}
## Métodos que no Java são de coleção/Supplier e no GDScript não existem ou têm outro nome. O
## tipo só se sabe rodando: a camada decide (`Mc.obter` numa lista é [i], num Callable é call()…).
## aridade → nome → (alvo, args) → GDScript.
COLECAO_JAVA = {
    0: {"get": lambda a, x: f"Mc.obter0({a})", "entrySet": lambda a, x: f"Mc.entradas({a})",
        "keySet": lambda a, x: f"Mc.chaves({a})", "values": lambda a, x: f"Mc.valores({a})",
        "size": lambda a, x: f"Mc.tamanho({a})", "clear": lambda a, x: f"Mc.limpar({a})",
        "iterator": lambda a, x: f"Mc.iterador({a})", "stream": lambda a, x: f"McFluxo.de({a})"},
    1: {"get": lambda a, x: f"Mc.obter({a}, {x})", "containsKey": lambda a, x: f"Mc.tem_chave({a}, {x})",
        "add": lambda a, x: f"Mc.adicionar({a}, {x})", "remove": lambda a, x: f"Mc.remover({a}, {x})",
        "contains": lambda a, x: f"Mc.contem({a}, {x})", "isInstance": lambda a, x: f"Mc.e({x}, {a})",
        "forEach": lambda a, x: f"Mc.para_cada({a}, {x})", "addAll": lambda a, x: f"Mc.adicionar_todos({a}, {x})",
        "set": lambda a, x: f"Mc.definir({a}, {x})", "accept": lambda a, x: f"Mc.aceitar({a}, {x})",
        "apply": lambda a, x: f"Mc.aplicar({a}, {x})", "test": lambda a, x: f"Mc.testar({a}, {x})"},
    2: {"put": lambda a, x: f"Mc.por({a}, {x})", "getOrDefault": lambda a, x: f"Mc.obter_ou({a}, {x})",
        "set": lambda a, x: f"Mc.definir_em({a}, {x})", "putIfAbsent": lambda a, x: f"Mc.por_se_ausente({a}, {x})"},
}
REGISTROS_DO_MOD = {  # MinepieceModX.NOME.get() → chamada da camada
    "MinepieceModMobEffects": "Mc.efeito", "MinepieceModEntities": "Mc.tipo_entidade",
    "MinepieceModItems": "Mc.item", "MinepieceModBlocks": "Mc.bloco", "MinepieceModParticleTypes": "Mc.particula",
    "MinepieceModSounds": "Mc.som", "MinepieceModAttributes": "Mc.atributo", "MinepieceModGameRules": "Mc.regra",
    "MinepieceModMenus": "Mc.menu",
}
REGISTROS_VANILLA = {"MobEffects": "Mc.efeito", "Attributes": "Mc.atributo", "ParticleTypes": "Mc.particula",
                     "Blocks": "Mc.bloco", "Items": "Mc.item", "EntityType": "Mc.tipo_entidade",
                     "SoundEvents": "Mc.som", "DamageTypes": "Mc.tipo_dano", "Enchantments": "Mc.encantamento"}


class Tradutor:
    def __init__(self, fonte: bytes, nome: str, pendencias: collections.Counter, sobrecargas: dict = None):
        self.fonte = fonte
        self.nome = nome
        self.pend = pendencias
        self.apelidos = [{}]          # pilha de escopos: apelido do instanceof → expressão
        self.antes = []               # linhas a emitir ANTES da instrução atual (lambdas içadas)
        self.n = 0
        self.locais_tipo = [{}]
        self._laços = 0                # profundidade de laços (para o `break rotulo`)
        self.declarados = set()        # nomes de locais já declarados no método
        self.campos_da_classe = set()  # campos estáticos da classe Java (viram `static var`)
        # {classe: {método}} com mais de uma aridade: viram `método__N` (GDScript não tem sobrecarga).
        self.sobrecargas = sobrecargas or {}

    # ------------------------------------------------------------ utilidades
    def t(self, no) -> str:
        return self.fonte[no.start_byte:no.end_byte].decode("utf-8", "replace")

    def novo_nome(self, base: str) -> str:
        self.n += 1
        return f"_{base}_{self.n}"

    def ident(self, nome: str) -> str:
        for escopo in reversed(self.apelidos):
            if nome in escopo:
                return escopo[nome]
        return nome + "_" if nome in PALAVRAS_GD else nome

    @staticmethod
    def membro(nome: str) -> str:
        return nome + "_" if nome in RESERVADAS_GD else nome

    def pendencia(self, tipo: str, quem: str) -> None:
        self.pend[f"{tipo}: {quem}"] += 1

    # ------------------------------------------------------------ declarações
    def classe(self, raiz) -> list:
        linhas = [f"# GERADO por tools/mine_piece/tradutor/traduzir.py de {self.nome}.java — não editar.",
                  "extends RefCounted", ""]
        # Campos estáticos da classe (`ENTITY_DEVIL_FRUIT_MAP`): conhecidos ANTES dos métodos, senão o
        # nome em maiúsculas parece uma classe estática desconhecida.
        for no in raiz.children:
            if no.type == "class_declaration":
                for m in no.child_by_field_name("body").children:
                    if m.type == "field_declaration":
                        for d in m.children:
                            if d.type == "variable_declarator":
                                self.campos_da_classe.add(self.t(d.child_by_field_name("name")))
        for no in raiz.children:
            if no.type != "class_declaration":
                continue
            corpo = no.child_by_field_name("body")
            for m in corpo.children:
                if m.type == "method_declaration":
                    linhas += self.metodo(m) + [""]
                elif m.type == "static_initializer":
                    # `static { ... }` do Java: o Godot chama `_static_init` ao carregar a classe.
                    self.locais_tipo.append({})
                    corpo = self.bloco([c for c in m.children if c.type == "block"][0], 1)
                    self.locais_tipo.pop()
                    linhas += ["static func _static_init() -> void:"] + (corpo or ["\tpass"]) + [""]
                elif m.type == "field_declaration":
                    jt = self.t(m.child_by_field_name("type"))
                    for d in m.children:
                        if d.type == "variable_declarator":
                            nome = self.ident(self.t(d.child_by_field_name("name")))
                            valor = d.child_by_field_name("value")
                            anot = (": " + TIPOS_PRIMITIVOS[jt]) if jt in TIPOS_PRIMITIVOS else ""
                            linhas.append(f"static var {nome}{anot} = {self.expr(valor) if valor is not None else 'null'}")
        return linhas

    def metodo(self, m) -> list:
        nome = self.t(m.child_by_field_name("name"))
        n_params = sum(1 for p in m.child_by_field_name("parameters").children if p.type == "formal_parameter")
        if nome in self.sobrecargas.get(self.nome, set()):
            nome = f"{nome}__{n_params}"
        self._ja = getattr(self, "_ja", collections.Counter())
        self._ja[nome] += 1
        if self._ja[nome] > 1:                         # mesma aridade, tipos diferentes
            self.pendencia("sobrecarga de mesma aridade", f"{self.nome}.{nome}")
            nome = f"{nome}_{self._ja[nome]}"
        self.declarados = set()
        params = []
        self.locais_tipo.append({})
        for p in m.child_by_field_name("parameters").children:
            if p.type == "formal_parameter":
                pn = self.ident(self.t(p.child_by_field_name("name")))
                tipo = self.t(p.child_by_field_name("type"))
                params.append(pn + (": " + TIPOS_PRIMITIVOS[tipo] if tipo in TIPOS_PRIMITIVOS else ""))
                self.locais_tipo[-1][pn] = tipo
        ret = self.t(m.child_by_field_name("type"))
        cab = f"static func {nome}({', '.join(params)})"
        cab += " -> " + TIPOS_PRIMITIVOS[ret] if ret in TIPOS_PRIMITIVOS else (" -> void" if ret == "void" else "")
        corpo = self.bloco(m.child_by_field_name("body"), 1)
        self.locais_tipo.pop()
        return [cab + ":"] + (corpo or ["\tpass"])

    # ------------------------------------------------------------ instruções
    def bloco(self, no, nivel: int) -> list:
        self.apelidos.append({})
        linhas = []
        for c in no.children:
            if c.type in ("{", "}", "line_comment", "block_comment"):
                continue
            linhas += self.instrucao(c, nivel)
        self.apelidos.pop()
        return linhas

    def corpo(self, no, nivel: int) -> list:
        linhas = self.bloco(no, nivel) if no.type == "block" else self.instrucao(no, nivel)
        return linhas or ["\t" * nivel + "pass"]

    LACOS = ("for_statement", "enhanced_for_statement", "while_statement", "do_statement")

    def instrucao(self, no, nivel: int) -> list:
        """Laço dentro de um laço ROTULADO que sofre `break rotulo` de dentro dele: depois do laço, `if _sair_X: break`
        (GDScript não tem break rotulado; o salto sobe um laço por vez pela bandeira)."""
        linhas = self._instrucao(no, nivel)
        if no.type in self.LACOS:
            tab = "\t" * nivel
            for r in getattr(self, "_laco_rotulado", []):
                if self._laços > r["prof"]:
                    linhas += [f"{tab}if _sair_{r['nome']}:", f"{tab}\tbreak"]
        return linhas

    def _instrucao(self, no, nivel: int) -> list:
        tab = "\t" * nivel
        self.antes = []
        tipo = no.type
        if tipo == "local_variable_declaration":
            jt = self.t(no.child_by_field_name("type"))
            linhas = []
            for d in no.children:
                if d.type != "variable_declarator":
                    continue
                nome = self.ident(self.t(d.child_by_field_name("name")))
                self.locais_tipo[-1][nome] = jt
                # Descompilador: ao redeclarar `_setval` num bloco vizinho ele renomeia para
                # `_setvalx`, `_setvalxx`... mas a lambda seguinte ainda lê `_setval`. Medido em
                # EatDevilFruit, Selected, PvPFinish: `_setval` = a ÚLTIMA variante deste bloco.
                renomeada = re.fullmatch(r"(.+?)(x+)", nome)
                if renomeada and renomeada.group(1) in self.declarados:
                    self.apelidos[-1][renomeada.group(1)] = nome
                self.declarados.add(nome)
                valor = d.child_by_field_name("value")
                anot = (": " + TIPOS_PRIMITIVOS[jt]) if jt in TIPOS_PRIMITIVOS else ""
                if valor is not None:
                    v = self.atribuicao_em_expressao(valor) if valor.type == "assignment_expression" else self.expr(valor)
                    if jt in ("double", "float") and re.fullmatch(r"-?\d+", v):
                        v += ".0"
                    linhas.append(f"{tab}var {nome}{anot} = {v}")
                else:
                    padrao = {"float": "0.0", "int": "0", "bool": "false", "String": '""'}.get(TIPOS_PRIMITIVOS.get(jt, ""), "null")
                    linhas.append(f"{tab}var {nome}{anot} = {padrao}")
            return self._com_antes(linhas, tab)
        if tipo == "expression_statement":
            e = no.children[0]
            return self._com_antes([tab + self.expr_instrucao(e)], tab)
        if tipo == "if_statement":
            return self.se(no, nivel, "if")
        if tipo == "block":
            # Bloco solto do Java (`{ ... }`) cria ESCOPO: o MCreator redeclara `_setval` com outro
            # tipo no bloco vizinho. Em GDScript só um bloco indentado faz isso.
            return [tab + "if true:"] + self.corpo(no, nivel + 1)
        if tipo == "return_statement":
            v = [c for c in no.children if c.type not in ("return", ";")]
            return self._com_antes([tab + "return" + (" " + self.expr(v[0]) if v else "")], tab)
        if tipo == "break_statement":
            alvo = [c for c in no.children if c.type == "identifier"]
            for r in getattr(self, "_laco_rotulado", []):
                if alvo and self.t(alvo[0]) == r["nome"] and self._laços > r["prof"] + 1:
                    return [f"{tab}_sair_{r['nome']} = true", f"{tab}break"]
            if alvo and getattr(self, "_rotulos", []):
                profundidade = dict(self._rotulos).get(self.t(alvo[0]))
                if profundidade is not None and profundidade != self._laços:
                    self.pendencia("instrução", "break rotulado dentro de laço")
            return [tab + "break"]
        if tipo == "continue_statement":
            atualiza = getattr(self, "_atualiza_for", [])
            return [tab + a for a in (atualiza[-1] if atualiza else [])] + [tab + "continue"]
        if tipo == "enhanced_for_statement":
            var = self.ident(self.t(no.child_by_field_name("name")))
            fonte = self.expr(no.child_by_field_name("value"))
            linhas = self._com_antes([f"{tab}for {var} in {fonte}:"], tab)
            self._laços += 1
            corpo = self.corpo(no.child_by_field_name("body"), nivel + 1)
            self._laços -= 1
            return linhas + corpo
        if tipo == "for_statement":
            return self.para(no, nivel)
        if tipo == "while_statement":
            cond = self.expr(no.child_by_field_name("condition"))
            linhas = self._com_antes([f"{tab}while {cond}:"], tab)
            self._laços += 1
            corpo = self.corpo(no.child_by_field_name("body"), nivel + 1)
            self._laços -= 1
            return linhas + corpo
        if tipo == "do_statement":
            self.pendencia("instrução", "do-while")
            cond = self.expr(no.child_by_field_name("condition"))
            return [f"{tab}while true:"] + self.corpo(no.child_by_field_name("body"), nivel + 1) + \
                [f"{tab}\tif not ({cond}):", f"{tab}\t\tbreak"]
        if tipo == "try_statement":
            corpo = self.bloco(no.child_by_field_name("body"), nivel)
            for c in no.children:
                if c.type == "finally_clause":
                    corpo += self.bloco(c.children[-1], nivel)
            return corpo
        if tipo == "throw_statement":
            return [tab + 'push_error("throw")']
        if tipo in (";", "empty_statement"):
            return []
        if tipo == "labeled_statement":
            # `rotulo: { ... break rotulo; ... }` do descompilador = "pule para o fim do bloco".
            # Vira um laço de UMA volta; `break rotulo` vira `break` (se estiver dentro de outro
            # laço o salto não seria o mesmo: pendência).
            rotulo = self.t(no.children[0])
            corpo_no = no.children[-1]
            if corpo_no.type not in ("for_statement", "enhanced_for_statement", "while_statement", "do_statement"):
                self._rotulos = getattr(self, "_rotulos", []) + [(rotulo, self._laços)]
                linhas = [f"{tab}for _rotulo_{rotulo} in 1:"] + self.corpo(corpo_no, nivel + 1)
                self._rotulos.pop()
                return linhas
            if f"break {rotulo}" in self.t(corpo_no):
                if not hasattr(self, "_laco_rotulado"):
                    self._laco_rotulado = []
                self._laco_rotulado.append({"nome": rotulo, "prof": self._laços})
                corpo = self.instrucao(corpo_no, nivel)
                self._laco_rotulado.pop()
                return [f"{tab}var _sair_{rotulo} = false"] + corpo
            return self.instrucao(corpo_no, nivel)
        if tipo == "switch_expression":
            return self.escolha(no, nivel)
        if tipo == "local_class_declaration" or tipo == "class_declaration":
            self.pendencia("instrução", "classe local")
            return [tab + "pass"]
        self.pendencia("instrução", tipo)
        return [tab + f"pass # TODO {tipo}"]

    def _com_antes(self, linhas: list, tab: str) -> list:
        pre = [tab + l for bloco in self.antes for l in bloco]
        self.antes = []
        return pre + linhas

    def se(self, no, nivel: int, palavra: str) -> list:
        tab = "\t" * nivel
        cond_no = no.child_by_field_name("condition")
        self.apelidos.append({})
        cond = self.expr(cond_no)
        linhas = self._com_antes([f"{tab}{palavra} {cond}:"], tab) if palavra == "if" else [f"{tab}{palavra} {cond}:"]
        linhas += self.corpo(no.child_by_field_name("consequence"), nivel + 1)
        self.apelidos.pop()
        alt = no.child_by_field_name("alternative")
        if alt is not None:
            if alt.type == "if_statement":
                # O `elif` não aceita linhas antes: se a condição içar lambdas, vira else + if.
                if self._icaria(alt.child_by_field_name("condition")):
                    linhas += [tab + "else:"] + self.se(alt, nivel + 1, "if")
                else:
                    linhas += self.se(alt, nivel, "elif")
            else:
                linhas += [tab + "else:"] + self.corpo(alt, nivel + 1)
        return linhas

    @staticmethod
    def _icaria(no) -> bool:
        """A expressão tem lambda ou classe anônima (que viram linhas ANTES da instrução)?"""
        pilha = [no]
        while pilha:
            n = pilha.pop()
            if n.type == "lambda_expression" or (n.type == "object_creation_expression"
                                                 and any(c.type == "class_body" for c in n.children)):
                return True
            pilha.extend(n.children)
        return False

    def para(self, no, nivel: int) -> list:
        tab = "\t" * nivel
        linhas = []
        init = no.child_by_field_name("init")
        if init is not None:
            linhas += self.instrucao(init, nivel) if init.type == "local_variable_declaration" else \
                [tab + self.expr_instrucao(init)]
        cond = no.child_by_field_name("condition")
        atualiza = [self.expr_instrucao(c) for c in no.children_by_field_name("update")]
        if not hasattr(self, "_atualiza_for"):
            self._atualiza_for = []
        self._atualiza_for.append(atualiza)
        linhas += self._com_antes([f"{tab}while {self.expr(cond) if cond is not None else 'true'}:"], tab)
        self._laços += 1
        corpo = self.corpo(no.child_by_field_name("body"), nivel + 1)
        self._laços -= 1
        self._atualiza_for.pop()
        return linhas + corpo + [tab + "\t" + a for a in atualiza]

    def escolha(self, no, nivel: int) -> list:
        self.pendencia("instrução", "switch")
        return ["\t" * nivel + "pass # TODO switch"]

    def expr_instrucao(self, e) -> str:
        if e.type == "update_expression":
            filhos = [c for c in e.children]
            op = "+=" if any(c.type == "++" for c in filhos) else "-="
            alvo = [c for c in filhos if c.type not in ("++", "--")][0]
            return f"{self.expr(alvo)} {op} 1"
        return self.expr(e)

    # ------------------------------------------------------------ expressões
    def expr(self, e) -> str:
        tipo = e.type
        f = getattr(self, "e_" + tipo, None)
        if f is not None:
            return f(e)
        if tipo in ("decimal_integer_literal", "hex_integer_literal"):
            return self.t(e).rstrip("lL")
        if tipo == "decimal_floating_point_literal":
            v = self.t(e).rstrip("fFdD")
            return v if ("." in v or "e" in v.lower()) else v + ".0"
        if tipo in ("true", "false"):
            return tipo
        if tipo == "null_literal":
            return "null"
        if tipo == "string_literal":
            return self.t(e)
        if tipo == "character_literal":
            return '"' + self.t(e)[1:-1] + '"'
        if tipo == "identifier":
            return self.ident(self.t(e))
        if tipo == "this":
            return "self"
        if tipo == "class_literal":
            return '&"' + self.t(e)[:-len(".class")].split(".")[-1] + '"'
        self.pendencia("expressão", tipo)
        return f"Mc.nao_traduzido(&\"{tipo}\")"

    def e_parenthesized_expression(self, e) -> str:
        dentro = e.children[1]
        if dentro.type == "assignment_expression":
            return "(" + self.atribuicao_em_expressao(dentro) + ")"
        return "(" + self.expr(dentro) + ")"

    def e_cast_expression(self, e) -> str:
        tipo = self.t(e.child_by_field_name("type"))
        v = self.expr(e.child_by_field_name("value"))
        if tipo in ("int", "long", "short", "byte"):
            return f"int({v})"
        if tipo in ("double", "float"):
            return f"float({v})"
        return v

    def e_binary_expression(self, e) -> str:
        op = self.t(e.child_by_field_name("operator"))
        a_no, b_no = e.child_by_field_name("left"), e.child_by_field_name("right")
        a = self.expr(a_no)
        b = self.expr(b_no)
        if op == "&&":
            return f"{a} and {b}"
        if op == "||":
            return f"({a} or {b})"
        if op == "+" and (self._e_texto(a_no) or self._e_texto(b_no)):
            return f"str({a}) + str({b})"
        if op == "%":
            return f"Mc.resto({a}, {b})"
        if op == ">>>":
            return f"{a} >> {b}"            # sem sinal: igual para valores ≥ 0 (hash/cor no mod)
        return f"{a} {op} {b}"

    def _e_texto(self, no) -> bool:
        if no.type == "string_literal":
            return True
        if no.type == "binary_expression" and self.t(no.child_by_field_name("operator")) == "+":
            return self._e_texto(no.child_by_field_name("left")) or self._e_texto(no.child_by_field_name("right"))
        if no.type == "identifier":
            return self.locais_tipo[-1].get(self.t(no)) == "String"
        if no.type == "method_invocation":
            return self.t(no.child_by_field_name("name")) in ("getString", "toString", "getName")
        return False

    def e_unary_expression(self, e) -> str:
        op = self.t(e.children[0])
        v = self.expr(e.children[1])
        return f"not ({v})" if op == "!" else f"{op}{v}"

    def e_update_expression(self, e) -> str:
        """`i++` / `++i` no meio de uma expressão: o incremento vai para a linha de antes."""
        pos = e.children[0].type not in ("++", "--")
        alvo_no = [c for c in e.children if c.type not in ("++", "--")][0]
        alvo = self.expr(alvo_no)
        op = "+=" if any(c.type == "++" for c in e.children) else "-="
        if pos:
            tmp = self.novo_nome("antes")
            self.antes.append([f"var {tmp} = {alvo}", f"{alvo} {op} 1"])
            return tmp
        self.antes.append([f"{alvo} {op} 1"])
        return alvo

    def atribuicao_em_expressao(self, e) -> str:
        """`a = (b = c)` / `if ((x = f()) != null)`: a atribuição vai para a linha de antes."""
        self.antes.append([self.e_assignment_expression(e)])
        return self.expr(e.child_by_field_name("left"))

    def e_assignment_expression(self, e) -> str:
        op = self.t(e.child_by_field_name("operator"))
        a = self.expr(e.child_by_field_name("left"))
        dir_no = e.child_by_field_name("right")
        b = self.atribuicao_em_expressao(dir_no) if dir_no.type == "assignment_expression" else self.expr(dir_no)
        if op == "%=":
            return f"{a} = Mc.resto({a}, {b})"
        return f"{a} {op} {b}"

    def e_ternary_expression(self, e) -> str:
        self.apelidos.append({})
        c = self.expr(e.child_by_field_name("condition"))
        s = self.expr(e.child_by_field_name("consequence"))
        self.apelidos.pop()
        n = self.expr(e.child_by_field_name("alternative"))
        return f"({s} if {c} else {n})"

    def e_instanceof_expression(self, e) -> str:
        filhos = [c for c in e.children if c.type != "instanceof"]
        alvo = self.expr(filhos[0])
        tipo = self.t(e.child_by_field_name("right") or filhos[1]).split(".")[-1].split("<")[0]
        nome = e.child_by_field_name("name")
        if nome is not None:
            self.apelidos[-1][self.t(nome)] = alvo
        elif len(filhos) > 2 and filhos[-1].type == "identifier":
            self.apelidos[-1][self.t(filhos[-1])] = alvo
        return f'Mc.e({alvo}, &"{tipo}")'

    def e_field_access(self, e) -> str:
        obj = e.child_by_field_name("object")
        campo = self.t(e.child_by_field_name("field"))
        ot = self.t(obj)
        sem_pacote = re.sub(r"^([a-z_]\w*\.)+(?=[A-Z])", "", ot)
        com_pacote = sem_pacote != ot
        base = sem_pacote.split(".")[-1]
        if base in REGISTROS_VANILLA:
            return f'{REGISTROS_VANILLA[base]}(&"minecraft:{campo.lower()}")'
        if base in REGISTROS_DO_MOD:
            return f'{REGISTROS_DO_MOD[base]}(&"minepiece:{campo.lower()}")'
        if com_pacote or (obj.type in ("identifier", "scoped_identifier") and ot[:1].isupper() and not self._e_local(ot)):
            return f'Mc.campo(&"{base}", &"{campo}")'
        return f"{self.expr(obj)}.{self.membro(campo)}"

    def e_scoped_identifier(self, e) -> str:
        partes = self.t(e).split(".")
        return f'Mc.campo(&"{partes[-2]}", &"{partes[-1]}")'

    def e_array_access(self, e) -> str:
        return f"{self.expr(e.child_by_field_name('array'))}[{self.expr(e.child_by_field_name('index'))}]"

    def e_array_creation_expression(self, e) -> str:
        valor = e.child_by_field_name("value")
        if valor is not None:
            return "[" + ", ".join(self.expr(c) for c in valor.children if c.type not in ("{", "}", ",")) + "]"
        self.pendencia("expressão", "array new[n]")
        return "[]"

    def e_array_initializer(self, e) -> str:
        return "[" + ", ".join(self.expr(c) for c in e.children if c.type not in ("{", "}", ",")) + "]"

    def e_object_creation_expression(self, e) -> str:
        tipo = self.t(e.child_by_field_name("type")).split("<")[0].split(".")[-1]
        args = self.argumentos(e.child_by_field_name("arguments"))
        corpo = [c for c in e.children if c.type == "class_body"]
        if corpo:
            return self.anonima(corpo[0], tipo)
        if tipo == "Object":
            return "Object.new()"
        if tipo in ("ArrayList", "LinkedList", "CopyOnWriteArrayList"):
            return "[]" if not args else f"Array({args})"
        if tipo in ("HashMap", "LinkedHashMap", "TreeMap", "ConcurrentHashMap", "HashSet", "LinkedHashSet"):
            return "{}"
        self.pendencia("new", tipo)
        return f'Mc.novo(&"{tipo}", [{args}])'

    def anonima(self, corpo, tipo: str) -> str:
        """`new Object(){ T nome(args){...} }` → lambda içada; `.nome(...)` vira `.call(...)`."""
        metodos = [c for c in corpo.children if c.type == "method_declaration"]
        if len(metodos) != 1:
            self.pendencia("classe anônima", f"{tipo} com {len(metodos)} métodos")
        if not metodos:
            return "null"
        m = metodos[0]
        nome = self.novo_nome("anon")
        params = []
        for p in m.child_by_field_name("parameters").children:
            if p.type == "formal_parameter":
                params.append(self.ident(self.t(p.child_by_field_name("name"))))
        antes_salvo = self.antes
        self.antes = []
        corpo_l = self.corpo(m.child_by_field_name("body"), 1)
        internos = self.antes
        self.antes = antes_salvo
        bloco = [f"var {nome} = func({', '.join(params)}):"] + [l for b in internos for l in ["\t" + x for x in b]] + corpo_l
        self.antes.append(bloco)
        self._anonimas = getattr(self, "_anonimas", {})
        self._anonimas[nome] = self.t(m.child_by_field_name("name"))
        return nome

    def e_lambda_expression(self, e) -> str:
        params_no = e.child_by_field_name("parameters")
        if params_no.type == "identifier":
            params = [self.ident(self.t(params_no))]
        else:
            params = [self.ident(self.t(c.child_by_field_name("name") or c)) for c in params_no.children
                      if c.type in ("identifier", "formal_parameter", "inferred_parameters")]
            params = [p for p in params if p not in ("(", ")", ",")]
        corpo = e.child_by_field_name("body")
        nome = self.novo_nome("lambda")
        antes_salvo = self.antes
        self.antes = []
        if corpo.type == "block":
            corpo_l = self.corpo(corpo, 1)
        else:
            corpo_l = ["\treturn " + self.expr(corpo)]
        internos = self.antes
        self.antes = antes_salvo
        bloco = [f"var {nome} = func({', '.join(params)}):"] + [l for b in internos for l in ["\t" + x for x in b]] + corpo_l
        self.antes.append(bloco)
        return nome

    def e_method_reference(self, e) -> str:
        partes = self.t(e).split("::")
        self.pendencia("referência de método", self.t(e))
        if partes[1] == "new":
            return "null"
        # `variavel::metodo` (referência LIGADA, ex.: `_iitemhandlerref::set`) → `variavel.metodo(o)`; `Tipo::metodo`
        # (não ligada) → `o.metodo()`. Variável = começa por minúscula ou `_` (classes do Java começam por maiúscula).
        obj = partes[0].strip()
        if obj and (obj[0].islower() or obj[0] == "_") and obj.isidentifier():
            metodo = "set_" if partes[1] == "set" else partes[1]       # `set` é método nativo do Object no Godot
            return f'func(o): return {self.ident(obj)}.{metodo}(o)'
        return f'func(o): return o.{partes[1]}()'

    def argumentos(self, no) -> str:
        if no is None:
            return ""
        return ", ".join(self.expr(c) for c in no.children if c.type not in ("(", ")", ","))

    def e_method_invocation(self, e) -> str:
        obj = e.child_by_field_name("object")
        nome = self.t(e.child_by_field_name("name"))
        args = self.argumentos(e.child_by_field_name("arguments"))
        if obj is None:
            if nome in self.sobrecargas.get(self.nome, set()):
                nome = f"{nome}__{self._n_args(e)}"
            return f"{nome}({args})"
        ot = self.t(obj)
        base = ot.split(".")[-1]
        qualificado = obj.type in ("scoped_identifier", "field_access") and re.fullmatch(r"([a-z_][\w]*\.)+[A-Z]\w*", ot)
        if qualificado and not base.endswith("Procedure"):
            self.pendencia("estático", f"{base}.{nome}")
            return f'Mc.estatico(&"{base}", &"{nome}", [{args}])'
        # Registro do mod: X.NOME.get() → Mc.registro(&"minepiece:nome")
        if nome == "get" and obj.type == "field_access":
            oo = self.t(obj.child_by_field_name("object")).split(".")[-1]
            if oo in REGISTROS_DO_MOD:
                return f'{REGISTROS_DO_MOD[oo]}(&"minepiece:{self.t(obj.child_by_field_name("field")).lower()}")'
        if nome == "get" and re.search(r"MinepieceModVariables\.(MapVariables|WorldVariables)$", ot):
            return f'Mc.variaveis(&"{base}", {args})'
        if base == "Math" or base == "StrictMath":
            if nome in MATH:
                return f"{MATH[nome]}({args})"
            self.pendencia("Math", nome)
            return f'Mc.estatico(&"Math", &"{nome}", [{args}])'
        if base.endswith("Procedure") and obj.type == "identifier":
            if nome in self.sobrecargas.get(base, set()):
                nome = f"{nome}__{self._n_args(e)}"
            return f'Mc.proc(&"{base}").{nome}({args})'
        if obj.type in ("identifier", "scoped_identifier") and ot[:1].isupper() and not self._e_local(ot):
            self.pendencia("estático", f"{base}.{nome}")
            return f'Mc.estatico(&"{base}", &"{nome}", [{args}])'
        alvo = self.expr(obj)
        if nome in STRING_JAVA:
            return STRING_JAVA[nome](alvo, args)
        if nome in ("x", "y", "z") and not args:
            return f"{alvo}.{nome}"          # Vec3: campo `x` e método `x()` (GDScript não tem os dois)
        n = self._n_args(e)
        if nome in COLECAO_JAVA.get(n, {}):
            return COLECAO_JAVA[n][nome](alvo, args)
        chave = alvo.strip("()")             # `(new Object(){...}).m(x)` chega entre parênteses
        if chave in getattr(self, "_anonimas", {}) and nome == self._anonimas[chave]:
            return f"{chave}.call({args})"
        return f"{alvo}.{self.membro(nome)}({args})"

    @staticmethod
    def _n_args(e) -> int:
        a = e.child_by_field_name("arguments")
        return sum(1 for c in a.children if c.type not in ("(", ")", ",")) if a is not None else 0

    def _e_local(self, nome: str) -> bool:
        if nome in self.campos_da_classe:
            return True
        return any(nome in s for s in self.locais_tipo) or any(nome in s for s in self.apelidos)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--so", default="")
    ap.add_argument("--saida", default=SAIDA)
    ap.add_argument("--relatorio", default="")
    args = ap.parse_args()
    parser = Parser(Language(tsj.language()))
    srg = mapa()
    os.makedirs(args.saida, exist_ok=True)
    pend = collections.Counter()
    por_arquivo = {}
    # 1ª passada: métodos com mais de uma aridade em cada procedure (sobrecarga Java).
    sobrecargas = {}
    for f in sorted(os.listdir(FONTES)):
        if not f.endswith(".java"):
            continue
        t = parser.parse(open(os.path.join(FONTES, f), "rb").read())
        aridades = collections.defaultdict(set)
        pilha = [t.root_node]
        while pilha:
            n = pilha.pop()
            if n.type == "method_declaration" and n.parent is not None and n.parent.parent is not None \
                    and n.parent.parent.type == "class_declaration" and n.parent.parent.parent.type == "program":
                nome = n.child_by_field_name("name").text.decode()
                aridades[nome].add(sum(1 for p in n.child_by_field_name("parameters").children if p.type == "formal_parameter"))
            pilha.extend(n.children)
        dup = {m for m, ar in aridades.items() if len(ar) > 1}
        if dup:
            sobrecargas[f[:-5]] = dup
    feitos = 0
    for f in sorted(os.listdir(FONTES)):
        if not f.endswith(".java") or (args.so and f[:-5] != args.so):
            continue
        texto = desofuscar(open(os.path.join(FONTES, f), encoding="utf-8", errors="replace").read(), srg).encode()
        arvore = parser.parse(texto)
        local = collections.Counter()
        tr = Tradutor(texto, f[:-5], local, sobrecargas)
        linhas = tr.classe(arvore.root_node)
        open(os.path.join(args.saida, f[:-5] + ".gd"), "w").write("\n".join(linhas) + "\n")
        pend.update(local)
        por_arquivo[f[:-5]] = dict(local)
        feitos += 1
    print(f"{feitos} procedures traduzidas → {os.path.normpath(args.saida)}")
    print(f"{sum(1 for v in por_arquivo.values() if not v)} sem nenhuma pendência")
    for k, v in pend.most_common(40):
        print(f"  {v:5d}  {k}")
    if args.relatorio:
        json.dump({"pendencias": dict(pend.most_common()), "por_arquivo": por_arquivo},
                  open(args.relatorio, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
