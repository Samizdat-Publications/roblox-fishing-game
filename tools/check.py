"""The gate: run before every commit to main. Exits 1 if anything fails.

  python tools/check.py

1. Unit tests outside Studio (Lune): lune run tools/test/run.luau
2. Compile check of every script, if present: lune run tools/test/syntax.luau
3. House-rule lint (no em dashes in reader-facing text): python tools/lint.py
4. The economy simulation still runs: python tools/econ/sim.py --quick --only current

Studio-only checks stay manual at each milestone: TestRunner.runAll in Studio, the checksum
comparison (tools/sync/verify.py), the fixed shots (tools/shots/shots.py) and a playtest.
"""

from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def step(name: str, cmd: list[str]) -> bool:
    t = time.time()
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ok = r.returncode == 0
    print(f"{'PASS' if ok else 'FAIL'}  {name}  ({time.time() - t:.1f} s)")
    if not ok:
        tail = (r.stdout + r.stderr).strip().splitlines()[-25:]
        print("\n".join("      " + x for x in tail))
    return ok


def main() -> int:
    results = [step("unit tests (Lune)", ["lune", "run", "tools/test/run.luau"])]
    if (ROOT / "tools/test/syntax.luau").exists():
        results.append(step("compile check (Lune)", ["lune", "run", "tools/test/syntax.luau"]))
    results.append(step("lint: no em dashes", [sys.executable, "tools/lint.py"]))
    results.append(step("economy sim runs", [sys.executable, "tools/econ/sim.py", "--quick", "--only", "current"]))
    print("gate:", "PASS" if all(results) else "FAIL")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
