class_name NetworkConfig
extends RefCounted
## Constantes da camada de rede. Único lugar a mudar para servidor dedicado
## (basta apontar IP/porta) — o resto da arquitetura não muda.

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 50          # preparado p/ escalar (começa com 2)
const LOCAL_IP := "127.0.0.1"
const SERVER_ID := 1             # no modelo Godot, o host é o peer id 1
