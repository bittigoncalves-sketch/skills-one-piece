# Frutas do mod que faltavam no jogo (08/11/2026)

Fonte: os 40 ids de `FrutasDoMod.FRUTAS` × o que `PerfilDeFrutas.frutas_a_venda()` vendia.

- **Já no jogo (12 pela arena/fluxo do mod):** bomu_bomu, gomu_gomu, goro_goro, gura_gura, hie_hie, magu_magu, mera_mera, ope_ope, pika_pika, suna_suna, tori_tori_phoenix, yami_yami.
- **Cobertas pela tradução nativa (2):** moku_moku, nikyu_nikyu (`*_mine_piece`).
- **Faltavam (26, todas na loja agora):** abaixo. Agora vendidas por 1 moeda, ícone do mod, nome "<Fruta> (Mine Piece)", usadas pelo
  FLUXO DO MOD (`ControladorFrutaDoMod`: as procedures traduzidas, sem executor escrito à mão — a fidelidade vem do próprio mod).

| fruta | golpes do mod (Skill…Procedure) |
|---|---|
| aro_aro | 21 Arrow · 22 Move · 25 Combo · 29 passiva |
| batto_batto | Shigan · Attack Speed · Rankyaku · Tobu Shigan · Kamie Zanshin · Yurushitene |
| bisu_bisu | Crash Pretzel · Summon Warrior ×2 · Biscuit |
| hito_hito_daibutsu | Overhead · Brilliant Punk · Impact Ball · Overhead Super · Impact Wave |
| horo_horo | Negative Hollow · Mini Hollow · Toku Horo · Rap · Kumac |
| imu | Arrow |
| inu_inu_okuchi_no_makami | Overhead · Sweep · Raimei Hakke · Narikabura · Namuji Hyoga · Himorogiri |
| inu_inu_wolf | Shigan · Attack Speed · Rankyaku · Lupus Fall · Okami Hajiki · Jushigan · LAN |
| kage_kage | Overhead · Brick Bat · Tsuno Tokage · Doppelman · Island Shatter Punch · Shadow's Asgard |
| kira_kira | Overhead · Stone Throwing · Stone Throwing Large |
| kiro_kiro | Overhead · Jump · Overhead (Kiro) · Weight Manipulation |
| mero_mero | Pistol Kiss · Karate 7000 Brick Roundhouse · Rotate Kick · Perfume Femur Magna |
| mochi_mochi | Pistol · Gatling · Yaki Mochi · Zan Giri Mochi · Muso Donatsu |
| mori_mori | Root · Root Giant · Assault · Root Surroundings Strong |
| neko_neko_leopard | Shigan · Attack Speed · Rankyaku · Gaicho · Jump · Shugan · Rokuogan |
| neko_neko_sabertiger | Shigan · Attack Speed · Shigan Madara · Gagan · Kibasen |
| riki_riki | Overhead · Hado Elbow · Galleon Lariat · Stone Throwing ×2 |
| ryu_ryu_brachiosaurus | Overhead · Brachio Bober · Black Cofee · Brachio Launcher · Sparking Queen |
| ryu_ryu_pachycephalosaurus | Jump · Sweep · Headbutt · Ul Zugan · Ul Meteor |
| ryu_ryu_pteranodon | Attack Speed · Tankyudon · Barizodon |
| soru_soru | Overhead · Sweep · Raitei · Hebunri Fire · Furugora · Mama Raid · Ikoku |
| supa_supa | Projectile Slash · Atomic Spurt · Sparkling Daisy · Spar Break |
| uo_uo_seiryu | Overhead · Sweep · Raimei Hakke · Kongo Kabura · Kaifu · Boro Breath · Kosanze Ragnaraku · Ikoku |
| ushi_ushi_giraffe | Shigan · Attack Speed · Rankyaku · Rankyaku Ran · Amane Dachi |
| uta_uta | Note Attack · Note Laser · Posing · Note Shield · Summon Warrior · Tot Musica Pistol · Summon Tot Musica |
| zushi_zushi | Attack Speed · Gravito · Small Meteors · Moko · Rubbles · Meteor |

Os golpes que o jogador vê dependem das conquistas do mod (o mod libera por grade) e da energia.

## Teclas (pedido do dono, 08/11/2026)

Cada técnica na sua tecla, na ordem do ciclo: **Z X C V** e, havendo mais, **B N**. Segurar carrega, soltar dispara. O **R não troca mais nada**.
Zoan: a transformação passou para **J** (Shift+J volta). Vale para as nativas (Ope, Hie, Moku, Pika, Nikyu, Goro) e para o fluxo do mod.
A recarga segue a do mod (global); só a Luta tem recarga por técnica.

## Validação

`tools/dev_tests/varredura_frutas_do_mod.gd -- <fruta…>` aperta cada tecla de cada golpe e mede energia gasta, entidades que nasceram e
dano: das 26 frutas, **todos os golpes começaram**, exceto `kage_kage/Shadow's Asgard` (custo 1000) e `zushi_zushi/Meteor` (1250), que
exigem mais que os 600 de energia máxima atual (HUD: "requer X ⚡"; igual ao Raigo da Goro). 0 erros de script. Limite da validação:
mede que a técnica EXECUTA, não a fidelidade visual de cada efeito (nada foi jogado à mão); a saída da varredura mostra erros de
partículas/sons do mod que viram `Mc._falta` em algumas frutas (ex.: zushi_zushi AIMeteor) — a revisar no jogo.
