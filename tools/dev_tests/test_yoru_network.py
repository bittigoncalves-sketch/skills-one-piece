#!/usr/bin/env python3
"""Host/cliente ENet reais, com entrada tardia durante ação Yoru."""
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64")
LOGDIR = Path(os.environ.get("YORU_NETWORK_LOGDIR", "/tmp/yoru-network-proof"))
LOGDIR.mkdir(parents=True, exist_ok=True)
args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tools/dev_tests/test_yoru_network.gd", "--"]
env = dict(os.environ)
env.setdefault("SOP_PORTA", "24740")
env.setdefault("XDG_DATA_HOME", "/tmp/yoru-net-data")
env.setdefault("XDG_CONFIG_HOME", "/tmp/yoru-net-config")
env.setdefault("XDG_CACHE_HOME", "/tmp/yoru-net-cache")
processes = []
try:
    with (LOGDIR / "host.log").open("w") as hostlog, (LOGDIR / "client.log").open("w") as clientlog:
        host = subprocess.Popen(args + ["host"], stdout=hostlog, stderr=subprocess.STDOUT, env=env)
        processes.append(host)
        until = time.monotonic() + 35
        while "YORU_HOST_READY" not in (LOGDIR / "host.log").read_text():
            if host.poll() is not None or time.monotonic() > until:
                raise RuntimeError("Host não preparou ação; consulte host.log")
            time.sleep(0.1)
        client = subprocess.Popen(args + ["client"], stdout=clientlog, stderr=subprocess.STDOUT, env=env)
        processes.append(client)
        codes = [client.wait(timeout=50), host.wait(timeout=10)]
    for filename in ["host.log", "client.log"]:
        data = (LOGDIR / filename).read_text()
        print(f"{filename}: {LOGDIR / filename}")
        for line in data.splitlines():
            if line.startswith(("PASS ", "FAIL ", "YORU NETWORK")):
                print(line)
        if "SCRIPT ERROR:" in data:
            codes.append(1)
    sys.exit(1 if any(codes) else 0)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
