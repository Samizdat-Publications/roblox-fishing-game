"""What daily goals and feeding frenzies add to a player's income (second overnight run).

Uses the rules and fish from sim.py (which reads src/ReplicatedStorage/Shared) and the
frenzy and goal numbers from Frenzy.luau and Goals.luau. Nothing here changes the game.

Run:  python3 tools/econ/loop.py
"""

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sim  # noqa: E402

SHARED = HERE.parent.parent / "src" / "ReplicatedStorage" / "Shared"


def luau_num(path, name):
    m = re.search(rf"{name}\s*=\s*([0-9.]+)", (SHARED / path).read_text())
    return float(m.group(1))


DURATION = luau_num("Frenzy.luau", r"Frenzy\.DURATION")
BITE_SPEED = luau_num("Frenzy.luau", r"Frenzy\.BITE_SPEED")
BOOST = luau_num("Frenzy.luau", r"Frenzy\.SCHOOL_BOOST")
PER_DAY = luau_num("Frenzy.luau", r"Frenzy\.PER_DAY")
rewards = re.search(r"REWARDS = \{ easy = (\d+), medium = (\d+), hard = (\d+) \}", (SHARED / "Goals.luau").read_text())
GOALS_PER_DAY = sum(int(x) for x in rewards.groups())

SCHOOLS = {
    "Dock": ["Bluegill", "Pumpkinseed"],
    "OpenWater": ["YellowPerch"],
    "Logs": ["BlackCrappie"],
    "Riffle": ["CreekChub"],
}


def rate(spot, period, bait, frenzy, player, skill):
    """Expected coins per real minute at one spot, with or without a frenzy on."""
    orig_w, orig_d = sim.bite_weights, sim.bite_delay_base

    def weights(s, p, b):
        w = orig_w(s, p, b)
        if frenzy and s in SCHOOLS:
            w = [(sid, x * (BOOST if sid in SCHOOLS[s] else 1)) for sid, x in w]
        return w

    def delay(w):
        return orig_d(w) * (BITE_SPEED if frenzy else 1)

    sim.bite_weights, sim.bite_delay_base = weights, delay
    try:
        r, _ = sim.expected_rate(spot, period, bait, player, skill, 0.88)
    finally:
        sim.bite_weights, sim.bite_delay_base = orig_w, orig_d
    return r * 60


def main():
    p = sim.Player()
    p.creek = True
    print(f"Frenzy: {DURATION:.0f} s, bites {1 / BITE_SPEED:.0f}x as fast, school fish x{BOOST:.0f}, about {PER_DAY} a game day\n")
    print("| Spot | Time | Bait | coins/min normally | during a frenzy | extra per frenzy (if already there) |")
    print("|---|---|---|---|---|---|")
    for spot in SCHOOLS:
        best = None
        for period in sim.PERIODS:
            for bait in ["Worm", "Cricket", "Minnow"]:
                n = rate(spot, period, bait, False, p, sim.KID)
                f = rate(spot, period, bait, True, p, sim.KID)
                if f > 0 and (best is None or f - n > best[4] - best[3]):
                    best = (spot, period, bait, n, f)
        if best:
            s, per, b, n, f = best
            print(f"| {s} | {per} | {b} | {n:.1f} | {f:.1f} | {(f - n) * DURATION / 60:.0f} |")
    print()
    print(f"Daily goals pay {GOALS_PER_DAY} coins a day if all three are done.")
    print(f"Against one {sim.SESSION_MIN} minute session (first-session rates from sim.py):")
    for name, cpm in [("dock and worms", 31.4), ("random", 36.2), ("smart", 96.2)]:
        session = cpm * sim.SESSION_MIN
        print(f"  {name:15s} {session:6.0f} coins a session, goals add {100 * GOALS_PER_DAY / session:4.0f} percent")


if __name__ == "__main__":
    main()
