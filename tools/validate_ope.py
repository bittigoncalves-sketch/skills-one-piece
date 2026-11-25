"""Run Ope integration, combat, rig and a real two-process ENet regression.

Usage: python3 tools/validate_ope.py
Requires Godot and permission to bind a local UDP socket. Logs are retained in
multimodal/cache/ope-validation, outside the Godot import and git source trees.
"""
from pathlib import Path
import os
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
LOGS = PROJECT / "multimodal" / "cache" / "ope-validation"


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    engine = subprocess.check_output([str(PROJECT / "find_godot.sh")], text=True).strip()
    env = dict(os.environ, XDG_DATA_HOME=str(LOGS / "userdata"),
               XDG_CONFIG_HOME=str(LOGS / "config"))
    base = [engine, "--headless", "--path", str(PROJECT)]
    failed = []

    def check(name, code):
        contents = (LOGS / f"{name}.log").read_text(errors="replace")
        errors = "SCRIPT ERROR:" in contents or "ERROR:" in contents or "FAIL " in contents
        passed = code == 0 and not errors
        print(f"{'PASS' if passed else 'FAIL'} {name}", flush=True)
        if not passed:
            failed.append(name)
            print(contents[-5000:], flush=True)

    for index, test in enumerate(("test_ope_integracao", "test_ope_combate", "test_ope_animacoes", "test_arena", "test_fx_quality")):
        with (LOGS / f"{test}.log").open("w") as output:
            try:
                result = subprocess.run(base + ["--log-file", str(LOGS / f"{test}-engine.log"),
                    "--script", f"tools/dev_tests/{test}.gd"], cwd=PROJECT,
                    env=dict(env, SOP_PORTA=str(24780 + index * 10)), stdout=output,
                    stderr=subprocess.STDOUT, timeout=85)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
        check(test, code)

    network_env = dict(env, SOP_PORTA="24850")
    host = None
    with (LOGS / "network_host.log").open("w") as host_log, (LOGS / "network_client.log").open("w") as client_log:
        try:
            host = subprocess.Popen(base + ["--log-file", str(LOGS / "network-host-engine.log"),
                "--script", "tools/dev_tests/test_ope_rede.gd", "--", "host"], cwd=PROJECT,
                env=network_env, stdout=host_log, stderr=subprocess.STDOUT)
            time.sleep(1.5)
            client = subprocess.run(base + ["--log-file", str(LOGS / "network-client-engine.log"),
                "--script", "tools/dev_tests/test_ope_rede.gd", "--", "client"], cwd=PROJECT,
                env=network_env, stdout=client_log, stderr=subprocess.STDOUT, timeout=45)
            host_code = host.wait(timeout=8)
            client_code = client.returncode
        except subprocess.TimeoutExpired:
            host_code = client_code = 124
        finally:
            if host is not None and host.poll() is None:
                host.terminate()
                host.wait(timeout=5)
    check("network_host", host_code)
    check("network_client", client_code)
    print(f"Ope validation: {7 - len(failed)}/7 passed. Logs: {LOGS}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
