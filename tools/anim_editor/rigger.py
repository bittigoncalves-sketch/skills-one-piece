"""Janela "Criar rig por marcadores" — o método do Meshy.

Mostra o modelo voxelizado, você posiciona 12 marcadores nas juntas e ele deriva
os 13 papéis do rig com os comprimentos reais daquele personagem. O resultado
vira um rig JSON normal, que o editor de animação abre como qualquer outro.

Simetria ligada: mexer no lado A espelha em B no plano X do modelo — igual ao
Meshy, e é o que evita ombro torto.
"""

import json
import math
import os
import tkinter as tk
from tkinter import messagebox, simpledialog

import markers
from mesh import Malha, listar_malhas
from viewport import Camera, _hex


class Rigger(tk.Toplevel):
    def __init__(self, pai, dir_malhas, dir_rigs, ao_salvar=None):
        super().__init__(pai)
        self.title("Criar rig por marcadores")
        self.geometry("1080x720")
        self.configure(bg="#15181e")
        self.dir_malhas = dir_malhas
        self.dir_rigs = dir_rigs
        self.ao_salvar = ao_salvar or (lambda nome: None)

        self.malha = None
        self.marcas = {}
        self.ativo = markers.SLOTS[0][0]
        self.cam = Camera()
        self._arrastando = None
        self._itens = []      # (id_no_canvas, ponto3d)

        self._monta()
        self._carrega_lista()

    # ----------------------------------------------------------- interface
    def _monta(self):
        topo = tk.Frame(self, bg="#1c2028")
        topo.pack(fill="x")
        tk.Label(topo, text="Modelo", bg="#1c2028", fg="#9aa3b2").pack(side="left", padx=(10, 4))
        self.var_modelo = tk.StringVar()
        self.om = tk.OptionMenu(topo, self.var_modelo, "")
        self.om.configure(bg="#2a3140", fg="#dfe4ec", relief="flat", highlightthickness=0)
        self.om.pack(side="left", pady=6)

        for txt, cmd in (("Sugerir posições", self._sugerir),
                         ("Limpar", self._limpar),
                         ("Derivar rig", self._derivar)):
            tk.Button(topo, text=txt, command=cmd, bg="#2a3140", fg="#dfe4ec",
                      relief="flat").pack(side="left", padx=4)

        self.var_sim = tk.IntVar(value=1)
        tk.Checkbutton(topo, text="Simetria", variable=self.var_sim, bg="#1c2028",
                       fg="#dfe4ec", selectcolor="#151920",
                       activebackground="#1c2028").pack(side="left", padx=10)

        self.lbl = tk.Label(topo, text="", bg="#1c2028", fg="#7f8896")
        self.lbl.pack(side="right", padx=10)

        corpo = tk.Frame(self, bg="#15181e")
        corpo.pack(fill="both", expand=True)

        self.cv = tk.Canvas(corpo, bg="#1c1f26", highlightthickness=0)
        self.cv.pack(side="left", fill="both", expand=True)
        self.cv.bind("<ButtonPress-1>", self._pressiona)
        self.cv.bind("<B1-Motion>", self._arrasta)
        self.cv.bind("<ButtonRelease-1>", lambda e: setattr(self, "_arrastando", None))
        self.cv.bind("<Button-3>", self._coloca)          # botão direito = marcar
        self.cv.bind("<Button-4>", lambda e: self._zoom(1))
        self.cv.bind("<Button-5>", lambda e: self._zoom(-1))
        self.cv.bind("<MouseWheel>", lambda e: self._zoom(1 if e.delta > 0 else -1))
        self.cv.bind("<Configure>", lambda e: self._desenha())

        lat = tk.Frame(corpo, bg="#1c2028", width=250)
        lat.pack(side="right", fill="y")
        lat.pack_propagate(False)
        tk.Label(lat, text="MARCADORES", bg="#1c2028", fg="#9aa3b2").pack(pady=(10, 2))
        tk.Label(lat, text="clique com o BOTÃO DIREITO\nsobre o modelo para marcar",
                 bg="#1c2028", fg="#5d6675", font=("TkDefaultFont", 8)).pack(pady=(0, 8))

        self.botoes = {}
        for chave, rotulo, cor in markers.SLOTS:
            b = tk.Button(lat, text=rotulo, anchor="w", relief="flat",
                          bg="#252b36", fg=cor,
                          command=lambda k=chave: self._ativa(k))
            b.pack(fill="x", padx=10, pady=1)
            self.botoes[chave] = b
        self._ativa(self.ativo)

    def _carrega_lista(self):
        nomes = listar_malhas(self.dir_malhas)
        menu = self.om["menu"]
        menu.delete(0, "end")
        for n in nomes:
            menu.add_command(label=n, command=lambda v=n: self._troca(v))
        if nomes:
            self._troca(nomes[0])
        else:
            messagebox.showwarning(
                "Sem modelos",
                "Rode primeiro:\n  godot --headless --path . -s tools/export_mesh.gd")

    def _troca(self, nome):
        self.var_modelo.set(nome)
        caminho = os.path.join(self.dir_malhas, nome + ".json")
        if not os.path.exists(caminho):
            return
        self.malha = Malha.de_arquivo(caminho)
        self.marcas = {}
        self.cam.alvo = [self.malha.centro_x,
                         self.malha.base[1] + self.malha.altura * 0.5,
                         self.malha.base[2] + self.malha.tamanho[2] * 0.5]
        self.cam.dist = self.malha.altura * 1.9
        self._status("%s — %d voxels, %.2f m" %
                     (nome, len(self.malha.pontos), self.malha.altura))
        self._desenha()

    # -------------------------------------------------------- interação 3D
    def _ativa(self, chave):
        self.ativo = chave
        for k, b in self.botoes.items():
            marcado = "●" if k in self.marcas else "○"
            rot = next(r for kk, r, _c in markers.SLOTS if kk == k)
            b.configure(text="%s %s" % (marcado, rot),
                        bg="#3a4658" if k == chave else "#252b36")

    def _pressiona(self, ev):
        self._arrastando = (ev.x, ev.y)

    def _arrasta(self, ev):
        if not self._arrastando:
            return
        dx, dy = ev.x - self._arrastando[0], ev.y - self._arrastando[1]
        self._arrastando = (ev.x, ev.y)
        self.cam.orbitar(dx, dy)
        self._desenha()

    def _zoom(self, passos):
        self.cam.aproximar(passos)
        self._desenha()

    def _coloca(self, ev):
        """Marca no voxel visível mais próximo do clique."""
        if not self.malha:
            return
        alvo = self._voxel_em(ev.x, ev.y)
        if alvo is None:
            self._status("clique em cima do modelo")
            return
        self.marcas[self.ativo] = alvo
        par = markers.espelhar(self.ativo)
        if par and self.var_sim.get():
            cx = self.malha.centro_x
            self.marcas[par] = (2 * cx - alvo[0], alvo[1], alvo[2])
        self._avanca()
        self._desenha()

    def _voxel_em(self, x, y):
        melhor = None
        melhor_d = 18.0 ** 2
        for iid, p in self._itens:
            co = self.cv.coords(iid)
            if not co:
                continue
            cx = (co[0] + co[2]) * 0.5
            cy = (co[1] + co[3]) * 0.5
            d = (cx - x) ** 2 + (cy - y) ** 2
            if d < melhor_d:
                melhor_d = d
                melhor = p
        return melhor

    def _avanca(self):
        """Pula para o próximo slot vazio — evita ficar clicando na lista."""
        faltam = markers.completo(self.marcas)
        if faltam:
            self._ativa(faltam[0])
            self._status("faltam %d marcador(es)" % len(faltam))
        else:
            self._ativa(self.ativo)
            self._status("todos os 12 marcados — pode derivar o rig")

    # ------------------------------------------------------------- ações
    def _sugerir(self):
        if not self.malha:
            return
        self.marcas = dict(markers.sugerir(self.malha))
        self._avanca()
        self._status("posições sugeridas — ajuste o que estiver fora")
        self._desenha()

    def _limpar(self):
        self.marcas = {}
        self._ativa(markers.SLOTS[0][0])
        self._desenha()

    def _derivar(self):
        if not self.malha:
            return
        try:
            rig = markers.derivar_rig(self.marcas, self.malha, self.malha.nome)
        except ValueError as e:
            messagebox.showwarning("Faltam marcadores", str(e))
            return
        nome = simpledialog.askstring("Salvar rig", "Nome do rig:",
                                      initialvalue=self.malha.nome + "_rig", parent=self)
        if not nome:
            return
        nome = nome.strip().replace(" ", "_")
        rig["character"] = nome
        os.makedirs(self.dir_rigs, exist_ok=True)
        caminho = os.path.join(self.dir_rigs, nome + ".json")
        with open(caminho, "w", encoding="utf-8") as f:
            json.dump(rig, f, indent=1)
        self._atualiza_indice(nome)
        self.ao_salvar(nome)
        messagebox.showinfo("Rig criado",
                            "13 ossos derivados dos marcadores.\n\nSalvo em:\n%s" % caminho,
                            parent=self)

    def _atualiza_indice(self, nome):
        idx = os.path.join(self.dir_rigs, "index.json")
        lista = []
        if os.path.exists(idx):
            with open(idx, encoding="utf-8") as f:
                lista = json.load(f).get("characters", [])
        if nome not in lista:
            lista.append(nome)
        with open(idx, "w", encoding="utf-8") as f:
            json.dump({"characters": lista}, f, indent=1)

    # ----------------------------------------------------------- desenho
    def _desenha(self):
        c = self.cv
        c.delete("all")
        self._itens = []
        if not self.malha:
            return
        larg = max(c.winfo_width(), 10)
        alt = max(c.winfo_height(), 10)

        # voxels: UM retângulo cada, do mais longe para o mais perto
        proj = []
        for p in self.malha.pontos:
            x, y, z = self.cam.projetar(p, larg, alt)
            if -50 < x < larg + 50 and -50 < y < alt + 50:
                proj.append((z, x, y, p))
        proj.sort(key=lambda t: -t[0])

        if proj:
            zs = [t[0] for t in proj]
            zmin, zmax = min(zs), max(zs)
            span = max(zmax - zmin, 1e-6)
            lado = max(self.malha.celula * self.cam.zoom / max(zs[len(zs) // 2], 0.1), 2.0)
            for z, x, y, p in proj:
                t = 1.0 - (z - zmin) / span          # perto = mais claro
                tom = 0.30 + 0.55 * t
                cor = _hex((tom * 0.80, tom * 0.84, tom * 0.92))
                iid = c.create_rectangle(x - lado / 2, y - lado / 2,
                                         x + lado / 2, y + lado / 2,
                                         fill=cor, outline="")
                self._itens.append((iid, p))

        # marcadores por cima
        for chave, _rot, cor in markers.SLOTS:
            if chave not in self.marcas:
                continue
            x, y, _z = self.cam.projetar(self.marcas[chave], larg, alt)
            r = 7 if chave == self.ativo else 5
            c.create_oval(x - r, y - r, x + r, y + r, fill=cor,
                          outline="#0b0d11", width=2)
            if chave == self.ativo:
                c.create_oval(x - r - 4, y - r - 4, x + r + 4, y + r + 4,
                              outline=cor, width=1)

        c.create_text(8, 8, anchor="nw", fill="#8b93a1", font=("TkDefaultFont", 8),
                      text="arraste = orbitar · roda = zoom · BOTÃO DIREITO = marcar")

    def _status(self, txt):
        self.lbl.configure(text=txt)
