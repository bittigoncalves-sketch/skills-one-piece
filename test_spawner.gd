extends SceneTree
# ⚠️ `multiplayer` NÃO EXISTE NA `SceneTree` — é propriedade de `Node`.
# Na árvore o acesso certo é `get_multiplayer()` (ou `root.multiplayer`).
# Escrito como `multiplayer.x`, o script nem COMPILA, e era o que derrubava o
# `test_compila` da bateria desde sempre. Ver `docs/erros.md`.
#
# Este arquivo é uma SONDA de motor, não um teste: não afirma nada, só imprime.
# Por isso mora na raiz e não em `tools/dev_tests/` — lá o `validar.sh` o
# rodaria como teste, e teste sem asserção que "passa" é pior que teste vermelho.

func _init():
    var peer = OfflineMultiplayerPeer.new()
    get_multiplayer().multiplayer_peer = peer
    
    var root = Node.new()
    root.name = "Root"
    get_root().add_child(root)
    
    var spawner = MultiplayerSpawner.new()
    spawner.name = "Spawner"
    spawner.spawn_path = root.get_path()
    spawner.spawn_function = func(data):
        print("Spawn called!")
        var n = Node.new()
        return n
    
    root.add_child(spawner)
    
    print("Spawning...")
    var n = spawner.spawn({"test": 1})
    print("Spawn returned: ", n)
    quit()
