#!/usr/bin/env python3
"""Três processos Godot, ENet real, entrada durante jab e após morte."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get('GODOT', '/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64')
LOGDIR = Path(os.environ.get('BOSS_NETWORK_LOGDIR', ROOT / 'art_src/validation/buggy_boss/network'))
LOGDIR.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, SOP_PORTA=os.environ.get('SOP_PORTA', '24750'), XDG_DATA_HOME='/tmp/boss-net-data', XDG_CONFIG_HOME='/tmp/boss-net-config', XDG_CACHE_HOME='/tmp/boss-net-cache')
processes, handles = [], []

def launch(role):
    handle = (LOGDIR / f'{role}.log').open('w')
    handles.append(handle)
    process = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), '--log-file', str(LOGDIR / f'{role}_engine.log'), '--script', 'tools/dev_tests/test_boss_network.gd', '--', role], stdout=handle, stderr=subprocess.STDOUT, env=env)
    processes.append(process)
    return process

def wait_marker(marker):
    until = time.monotonic() + 40
    while marker not in (LOGDIR / 'host.log').read_text():
        if processes[0].poll() is not None or time.monotonic() > until:
            raise RuntimeError(f'Host não chegou a {marker}: {LOGDIR / "host.log"}')
        time.sleep(0.1)

try:
    host = launch('host')
    wait_marker('BOSS_HOST_READY')
    client = launch('client')
    client_code = client.wait(timeout=45)
    wait_marker('BOSS_FLIGHT_READY')
    flight = launch('flight')
    flight_code = flight.wait(timeout=30)
    wait_marker('BOSS_DEAD_READY')
    late = launch('late')
    codes = [client_code, flight_code, late.wait(timeout=45), host.wait(timeout=10)]
    for role in ['host', 'client', 'flight', 'late']:
        data = (LOGDIR / f'{role}.log').read_text()
        print(f'{role}: {LOGDIR / (role + ".log")}')
        print('\n'.join(line for line in data.splitlines() if line.startswith(('PASS ', 'FAIL ', 'BOSS NETWORK'))))
        if 'SCRIPT ERROR:' in data or 'ERROR:' in data:
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
