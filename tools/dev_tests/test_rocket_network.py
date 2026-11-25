"""Executa a sonda ENet de dois processos; preserva logs e códigos de saída."""
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = subprocess.check_output([str(ROOT / "find_godot.sh")], text=True).strip()
command = [GODOT, "--headless", "--path", str(ROOT), "--script",
           "tools/dev_tests/rocket_network_probe.gd", "--"]

def main():
    with open("/tmp/rocket_net_host.log", "w") as host_log, open("/tmp/rocket_net_client.log", "w") as client_log:
        host = subprocess.Popen(command + ["host"], stdout=host_log, stderr=subprocess.STDOUT)
        client = None
        try:
            time.sleep(1)
            client = subprocess.Popen(command + ["client"], stdout=client_log, stderr=subprocess.STDOUT)
            codes = [host.wait(timeout=55), client.wait(timeout=10)]
        finally:
            for process in (host, client):
                if process is not None and process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
    logs = [Path(f"/tmp/rocket_net_{side}.log").read_text() for side in ("host", "client")]
    for log in logs:
        print(log)
    return int(any(codes) or any("SCRIPT ERROR" in log or "ERROR:" in log for log in logs))

if __name__ == "__main__":
    raise SystemExit(main())
