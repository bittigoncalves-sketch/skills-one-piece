#!/usr/bin/env python3
"""Editor de Animação — Skills One Piece.

Carrega o personagem, mostra o esqueleto em 3D, e permite criar ou editar um
clipe por keyframes. Exporta direto para assets/animations/<nome>.tres, que o
jogo carrega igual a um .res.

Fluxo:
  1. escolhe o personagem (ou "novo rig" se ele ainda não tiver ossos)
  2. escolhe um clipe existente ou cria um
  3. posiciona os ossos, marca chave, avança no tempo, repete
  4. exporta

Antes de abrir, gere os dados no lado Godot:
    godot --headless --path . -s tools/export_rig.gd
    godot --headless --path . -s tools/export_anims.gd

Uso: python3 tools/anim_editor/main.py
"""

import math
import os
import sys
import tkinter as tk
from tkinter import messagebox, simpledialog, ttk

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from clip import Clip, listar_clipes           # noqa: E402
from rig import PAPEIS, Rig, listar_rigs       # noqa: E402
from viewport import Viewport                  # noqa: E402

PROJETO = os.path.abspath(os.path.join(AQUI, "..", ".."))
DIR_RIGS = os.path.join(AQUI, "rigs")
DIR_CLIPES = os.path.join(AQUI, "clips")
DIR_EXPORT = os.path.join(PROJETO, "assets", "animations")

EIXOS = ("X", "Y", "Z")


class Editor(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Editor de Animação — Skills One Piece")
        self.geometry("1180x760")
        self.configure(bg="#15181e")

        self.rig = None
        self.clip = Clip()
        self.tempo = 0.0
        self.papel = "Torso"
        self.tocando = False
        self._pose_cache = {}

        self._monta_barra()
        self._monta_corpo()
        self._carrega_rigs()
        self._redesenha()

    # ------------------------------------------------------------ interface
    def _monta_barra(self):
        b = tk.Frame(self, bg="#1c2028")
        b.pack(fill="x")

        tk.Label(b, text="Personagem", bg="#1c2028", fg="#9aa3b2").pack(side="left", padx=(10, 4))
        self.cb_person = ttk.Combobox(b, width=14, state="readonly")
        self.cb_person.pack(side="left", pady=6)
        self.cb_person.bind("<<ComboboxSelected>>", lambda e: self._troca_personagem())

        tk.Button(b, text="Criar ossos", command=self._criar_ossos,
                  bg="#2a3140", fg="#dfe4ec", relief="flat").pack(side="left", padx=6)

        ttk.Separator(b, orient="vertical").pack(side="left", fill="y", padx=8, pady=4)

        tk.Label(b, text="Clipe", bg="#1c2028", fg="#9aa3b2").pack(side="left", padx=(4, 4))
        self.cb_clipe = ttk.Combobox(b, width=22, state="readonly")
        self.cb_clipe.pack(side="left", pady=6)
        self.cb_clipe.bind("<<ComboboxSelected>>", lambda e: self._abre_clipe())

        for txt, cmd in (("Novo", self._novo_clipe), ("Fechar loop", self._fechar_loop),
                         ("Exportar .tres", self._exportar)):
            tk.Button(b, text=txt, command=cmd, bg="#2a3140", fg="#dfe4ec",
                      relief="flat").pack(side="left", padx=4)

        self.lbl_status = tk.Label(b, text="", bg="#1c2028", fg="#7f8896")
        self.lbl_status.pack(side="right", padx=10)

    def _monta_corpo(self):
        corpo = tk.Frame(self, bg="#15181e")
        corpo.pack(fill="both", expand=True)

        cv = tk.Canvas(corpo, bg="#1c1f26", highlightthickness=0)
        cv.pack(side="left", fill="both", expand=True)
        self.vp = Viewport(cv)
        self.vp.ao_redesenhar = self._redesenha
        self.vp.ao_clicar_osso = self._seleciona_osso
        cv.bind("<Configure>", lambda e: self._redesenha())

        lat = tk.Frame(corpo, bg="#1c2028", width=290)
        lat.pack(side="right", fill="y")
        lat.pack_propagate(False)

        tk.Label(lat, text="OSSOS", bg="#1c2028", fg="#9aa3b2").pack(pady=(10, 4))
        self.lista = tk.Listbox(lat, bg="#151920", fg="#dfe4ec", selectbackground="#3a4658",
                                highlightthickness=0, relief="flat", height=14)
        self.lista.pack(fill="x", padx=10)
        self.lista.bind("<<ListboxSelect>>", self._lista_click)

        tk.Label(lat, text="ROTAÇÃO (graus)", bg="#1c2028", fg="#9aa3b2").pack(pady=(14, 4))
        self.sliders = {}
        for eixo in EIXOS:
            lin = tk.Frame(lat, bg="#1c2028")
            lin.pack(fill="x", padx=10)
            tk.Label(lin, text=eixo, width=2, bg="#1c2028", fg="#dfe4ec").pack(side="left")
            s = tk.Scale(lin, from_=-180, to=180, orient="horizontal", resolution=1,
                         bg="#1c2028", fg="#dfe4ec", troughcolor="#151920",
                         highlightthickness=0, command=lambda v, e=eixo: self._muda_rot(e, v))
            s.pack(side="left", fill="x", expand=True)
            self.sliders[eixo] = s

        bt = tk.Frame(lat, bg="#1c2028")
        bt.pack(fill="x", padx=10, pady=8)
        for txt, cmd in (("Marcar chave", self._marca_chave),
                         ("Apagar chave", self._apaga_chave),
                         ("Zerar osso", self._zera_osso)):
            tk.Button(bt, text=txt, command=cmd, bg="#2a3140", fg="#dfe4ec",
                      relief="flat").pack(fill="x", pady=2)

        # ---- linha do tempo ----
        tl = tk.Frame(self, bg="#1c2028", height=110)
        tl.pack(fill="x")
        tl.pack_propagate(False)

        ctrl = tk.Frame(tl, bg="#1c2028")
        ctrl.pack(fill="x", pady=4)
        self.bt_play = tk.Button(ctrl, text="▶", width=3, command=self._play,
                                 bg="#2a3140", fg="#dfe4ec", relief="flat")
        self.bt_play.pack(side="left", padx=(10, 6))
        tk.Label(ctrl, text="duração", bg="#1c2028", fg="#9aa3b2").pack(side="left")
        self.sp_dur = tk.Spinbox(ctrl, from_=0.1, to=20, increment=0.1, width=6,
                                 command=self._muda_duracao, bg="#151920", fg="#dfe4ec",
                                 relief="flat")
        self.sp_dur.pack(side="left", padx=6)
        self.sp_dur.delete(0, "end")
        self.sp_dur.insert(0, "1.0")
        self.var_loop = tk.IntVar(value=1)
        tk.Checkbutton(ctrl, text="loop", variable=self.var_loop, bg="#1c2028",
                       fg="#dfe4ec", selectcolor="#151920",
                       activebackground="#1c2028").pack(side="left")
        self.lbl_tempo = tk.Label(ctrl, text="t = 0.00s", bg="#1c2028", fg="#dfe4ec")
        self.lbl_tempo.pack(side="left", padx=14)

        self.cv_tl = tk.Canvas(tl, bg="#151920", height=56, highlightthickness=0)
        self.cv_tl.pack(fill="x", padx=10)
        self.cv_tl.bind("<Button-1>", self._clica_timeline)
        self.cv_tl.bind("<B1-Motion>", self._clica_timeline)
        self.cv_tl.bind("<Configure>", lambda e: self._desenha_timeline())

    # -------------------------------------------------------------- dados
    def _carrega_rigs(self):
        if not os.path.isdir(DIR_RIGS):
            messagebox.showwarning(
                "Rigs não encontrados",
                "Rode primeiro no projeto:\n\n"
                "  godot --headless --path . -s tools/export_rig.gd\n"
                "  godot --headless --path . -s tools/export_anims.gd")
            nomes = []
        else:
            nomes = listar_rigs(DIR_RIGS)
        self.cb_person["values"] = nomes + ["<rig novo>"]
        if nomes:
            self.cb_person.current(0)
            self._troca_personagem()
        else:
            self.rig = Rig.canonico()
            self._preenche_lista()
        self.cb_clipe["values"] = listar_clipes(DIR_CLIPES)

    def _troca_personagem(self):
        nome = self.cb_person.get()
        if nome == "<rig novo>":
            self._criar_ossos()
            return
        caminho = os.path.join(DIR_RIGS, nome + ".json")
        if not os.path.exists(caminho):
            return
        self.rig = Rig.de_arquivo(caminho)
        self._status("%s: %d ossos%s" % (nome, len(self.rig.papeis),
                                         " (skinnado)" if self.rig.skinnado else ""))
        self._preenche_lista()
        self._redesenha()

    def _criar_ossos(self):
        """Personagem sem ossos: gera o rig canônico de 13 papéis."""
        if self.rig is not None and self.rig.papeis and self.cb_person.get() != "<rig novo>":
            if not messagebox.askyesno(
                    "Criar ossos",
                    "%s já tem %d ossos.\nCriar um rig novo do zero por cima?"
                    % (self.rig.personagem, len(self.rig.papeis))):
                return
        perna = simpledialog.askfloat("Criar ossos", "Comprimento da perna (m):",
                                      initialvalue=0.60, minvalue=0.1, maxvalue=3.0)
        if perna is None:
            return
        self.rig = Rig.canonico("novo", perna=perna)
        self._status("rig novo criado — 13 ossos canônicos")
        self._preenche_lista()
        self._redesenha()

    def _preenche_lista(self):
        self.lista.delete(0, "end")
        for p in PAPEIS:
            if p in self.rig.papeis:
                nivel = 0
                pai = self.rig.papeis[p].get("parent", "")
                while pai:
                    nivel += 1
                    pai = self.rig.papeis.get(pai, {}).get("parent", "")
                self.lista.insert("end", "  " * nivel + p)
        self._seleciona_osso(self.papel if self.papel in self.rig.papeis else "Torso")

    # ------------------------------------------------------------- clipes
    def _abre_clipe(self):
        nome = self.cb_clipe.get()
        caminho = os.path.join(DIR_CLIPES, nome + ".json")
        if not os.path.exists(caminho):
            return
        self.clip = Clip.de_json(caminho)
        self.tempo = 0.0
        self.sp_dur.delete(0, "end")
        self.sp_dur.insert(0, "%.2f" % self.clip.duracao)
        self.var_loop.set(1 if self.clip.loop else 0)
        self._status("clipe '%s': %d faixas, %.2fs" % (nome, len(self.clip.faixas), self.clip.duracao))
        self._atualiza_sliders()
        self._redesenha()

    def _novo_clipe(self):
        nome = simpledialog.askstring("Novo clipe", "Nome (sem extensão):")
        if not nome:
            return
        self.clip = Clip(nome.strip().replace(" ", "_"), float(self.sp_dur.get()),
                         bool(self.var_loop.get()))
        self.tempo = 0.0
        self._status("clipe novo: %s" % self.clip.nome)
        self._redesenha()

    def _fechar_loop(self):
        n = self.clip.fechar_loop()
        self._status("loop fechado em %d faixa(s)" % n)
        self._redesenha()

    def _exportar(self):
        if not self.clip.faixas:
            messagebox.showinfo("Exportar", "O clipe não tem nenhuma chave ainda.")
            return
        self.clip.duracao = float(self.sp_dur.get())
        self.clip.loop = bool(self.var_loop.get())
        os.makedirs(DIR_CLIPES, exist_ok=True)
        self.clip.para_json(os.path.join(DIR_CLIPES, self.clip.nome + ".json"))
        destino = os.path.join(DIR_EXPORT, self.clip.nome + ".tres")
        n = self.clip.para_tres(destino)
        self.cb_clipe["values"] = listar_clipes(DIR_CLIPES)
        self._status("exportado: %s (%d faixas)" % (os.path.relpath(destino, PROJETO), n))
        messagebox.showinfo(
            "Exportado",
            "Gravado em:\n%s\n\nNo jogo: modo estilo + \"Teste de Animação\"."
            % os.path.relpath(destino, PROJETO))

    # -------------------------------------------------------------- edição
    def _seleciona_osso(self, papel):
        self.papel = papel
        for i in range(self.lista.size()):
            if self.lista.get(i).strip() == papel:
                self.lista.selection_clear(0, "end")
                self.lista.selection_set(i)
                break
        self.vp.selecionado = papel
        self._atualiza_sliders()
        self._redesenha()

    def _lista_click(self, _ev):
        sel = self.lista.curselection()
        if sel:
            self._seleciona_osso(self.lista.get(sel[0]).strip())

    def _rot_atual(self):
        return self.clip.amostrar(self.tempo).get(self.papel, (0.0, 0.0, 0.0))

    def _atualiza_sliders(self):
        r = self._rot_atual()
        self._silencioso = True
        for i, eixo in enumerate(EIXOS):
            self.sliders[eixo].set(round(math.degrees(r[i])))
        self._silencioso = False

    def _muda_rot(self, eixo, valor):
        if getattr(self, "_silencioso", False) or self.rig is None:
            return
        r = list(self._rot_atual())
        r[EIXOS.index(eixo)] = math.radians(float(valor))
        # editar = cravar chave no instante atual; senão o ajuste some ao andar
        self.clip.por_chave(self.papel, self.tempo, tuple(r))
        self._redesenha()

    def _marca_chave(self):
        self.clip.por_chave(self.papel, self.tempo, self._rot_atual())
        self._status("chave em %s @ %.2fs" % (self.papel, self.tempo))
        self._redesenha()

    def _apaga_chave(self):
        if self.clip.tirar_chave(self.papel, self.tempo):
            self._status("chave removida")
        self._atualiza_sliders()
        self._redesenha()

    def _zera_osso(self):
        self.clip.por_chave(self.papel, self.tempo, (0.0, 0.0, 0.0))
        self._atualiza_sliders()
        self._redesenha()

    def _muda_duracao(self):
        try:
            self.clip.duracao = float(self.sp_dur.get())
        except ValueError:
            return
        self._desenha_timeline()

    # ------------------------------------------------------------- tempo
    def _clica_timeline(self, ev):
        larg = max(self.cv_tl.winfo_width() - 20, 10)
        f = min(1.0, max(0.0, (ev.x - 10) / larg))
        self.tempo = f * self.clip.duracao
        self._atualiza_sliders()
        self._redesenha()

    def _play(self):
        self.tocando = not self.tocando
        self.bt_play.configure(text="⏸" if self.tocando else "▶")
        if self.tocando:
            self._tick()

    def _tick(self):
        if not self.tocando:
            return
        self.tempo += 1.0 / 30.0
        if self.tempo > self.clip.duracao:
            self.tempo = 0.0 if self.clip.loop else self.clip.duracao
            if not self.clip.loop:
                self.tocando = False
                self.bt_play.configure(text="▶")
        self._atualiza_sliders()
        self._redesenha()
        if self.tocando:
            self.after(33, self._tick)

    # ------------------------------------------------------------ desenho
    def _redesenha(self):
        if self.rig is None:
            return
        rot = self.clip.amostrar(self.tempo)
        pose = self.rig.pose(rot)
        self.vp.desenhar(self.rig, pose)
        self.lbl_tempo.configure(text="t = %.2fs" % self.tempo)
        self._desenha_timeline()

    def _desenha_timeline(self):
        c = self.cv_tl
        c.delete("all")
        larg = max(c.winfo_width() - 20, 10)
        alt = c.winfo_height()
        c.create_line(10, alt - 14, 10 + larg, alt - 14, fill="#3a4250")

        # marcas de tempo
        for i in range(11):
            x = 10 + larg * i / 10.0
            c.create_line(x, alt - 18, x, alt - 10, fill="#3a4250")
            c.create_text(x, alt - 4, text="%.1f" % (self.clip.duracao * i / 10.0),
                          fill="#5d6675", font=("TkDefaultFont", 7))

        # chaves: laranja = do osso selecionado, cinza = dos outros
        for papel, ks in self.clip.faixas.items():
            for t, _v in ks:
                x = 10 + larg * (t / max(self.clip.duracao, 1e-6))
                if papel == self.papel:
                    c.create_polygon(x, 12, x + 5, 20, x, 28, x - 5, 20,
                                     fill="#ffb020", outline="")
                else:
                    c.create_oval(x - 2, 30, x + 2, 34, fill="#4a5364", outline="")

        # cursor
        x = 10 + larg * (self.tempo / max(self.clip.duracao, 1e-6))
        c.create_line(x, 6, x, alt - 14, fill="#e8eaf0", width=2)

    def _status(self, txt):
        self.lbl_status.configure(text=txt)


if __name__ == "__main__":
    Editor().mainloop()
