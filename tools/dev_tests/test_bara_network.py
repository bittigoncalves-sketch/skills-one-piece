#!/usr/bin/env python3
"""Godot ENet real: host, cliente e entrada tardia com membro em voo."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64")
LOGDIR = Path(os.environ.get("BARA_NETWORK_LOGDIR", ROOT / "art_src/validation/bara_bara/network"))
LOGDIR.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, SOP_PORTA=os.environ.get("SOP_PORTA", "24791"),
           XDG_DATA_HOME="/tmp/bara-net-data", XDG_CONFIG_HOME="/tmp/bara-net-config",
           XDG_CACHE_HOME="/tmp/bara-net-cache")
processes, handles = [], []


def launch(role):
    handle = (LOGDIR / f"{role}.log").open("w")
    handles.append(handle)
    process = subprocess.Popen(
        [GODOT, "--headless", "--path", str(ROOT), "--log-file", str(LOGDIR / f"{role}_engine.log"),
         "--script", "tools/dev_tests/test_bara_network.gd", "--", role],
        stdout=handle, stderr=subprocess.STDOUT, env=env)
    processes.append(process)
    return process


def wait_marker(marker):
    deadline = time.monotonic() + 45
    while marker not in (LOGDIR / "host.log").read_text():
        if processes[0].poll() is not None or time.monotonic() > deadline:
            raise RuntimeError(f"Host não chegou a {marker}: {LOGDIR / 'host.log'}")
        time.sleep(0.1)


try:
    host = launch("host")
    wait_marker("BARA_HOST_READY")
    client = launch("client")
    wait_marker("BARA_FLIGHT_READY")
    late = launch("late")
    codes = [late.wait(timeout=25), client.wait(timeout=10), host.wait(timeout=10)]
    for role in ("host", "client", "late"):
        data = (LOGDIR / f"{role}.log").read_text()
        print(f"{role}: {LOGDIR / (role + '.log')}")
        print("\n".join(line for line in data.splitlines() if line.startswith(("PASS ", "FAIL ", "BARA NETWORK"))))
        if "ERROR:" in data or "BARA NETWORK " not in data:
            codes.append(1)
    raise SystemExit(1 if any(codes) else 0)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    for handle in handles:
        handle.close()
