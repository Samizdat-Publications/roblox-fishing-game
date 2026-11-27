"""Rarity retune (docs/RARITY-DIRECTION.md): bite odds follow each fish's tier, and value
follows rarity, scaled so the shop curve stays where it is.

    python tools/econ/rarity_tune.py            prints the proposal and its sim results
    python tools/econ/rarity_tune.py --write    also writes the new numbers into FishData.luau
                                                and BigLakeFishData.luau

How the numbers are made:
- Odds: a fish's `rarity` weight becomes TIER_WEIGHT[tier] times a small within-tier factor
  (its old weight against the median of its tier, kept between 0.75 and 1.25), so two
  Commons still differ a little but no Epic bites like a Rare.
- Value: each tier's mean catch price is COMMON_PRICE times TIER_PRICE[tier]. The tier
  multipliers are about the inverse of the target catch shares, so each tier earns about
  the same in total and a rare catch pays for its rarity. Inside a tier, bigger fish keep
  paying more (old mean price against the tier's median, kept between 0.7 and 1.4).
- COMMON_PRICE is searched so the smart player's first-session coins per minute stays
  close to today's, and the shop goals land at about the same minutes.
"""
from __future__ import annotations

import argparse
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import sim  # noqa: E402

ROOT = HERE.parent.parent
TIER_WEIGHT = {"Common": 1.0, "Uncommon": 0.45, "Rare": 0.2, "Epic": 0.12, "Legendary": 0.02, "Mythic": 0.02}
# Pristine numbers from src/, taken before any proposal mutates the sim's fish tables.
PRISTINE = {f["id"]: {"rarity": f["rarity"], "basePrice": f["basePrice"], "tier": f.get("tier") or "Common"} for f in sim.DATA["fish"]}
# Mean price is basePrice times a size factor that depends only on the species' sizes.
SIZE_K = {sid: sim.mean_price(sid) / v["basePrice"] for sid, v in PRISTINE.items()}
TIER_PRICE = {"Common": 1.0, "Uncommon": 2.0, "Rare": 4.5, "Epic": 14.0, "Legendary": 32.0, "Mythic": 60.0}


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def proposal(common_price: float, premium: float = 1.0) -> dict:
    by_tier: dict[str, list] = {}
    for sid, v in PRISTINE.items():
        by_tier.setdefault(v["tier"], []).append(dict(v, id=sid))
    rarity, price = {}, {}
    for tier, fish in by_tier.items():
        med_w = statistics.median(f["rarity"] for f in fish)
        means = {f["id"]: f["basePrice"] * SIZE_K[f["id"]] for f in fish}
        med_p = statistics.median(means.values())
        for f in fish:
            rarity[f["id"]] = round(TIER_WEIGHT[tier] * clamp(f["rarity"] / med_w, 0.75, 1.25), 4)
            lift = premium if RANK[tier] >= RANK["Rare"] else 1.0
            want_mean = common_price * TIER_PRICE[tier] * lift * clamp(means[f["id"]] / med_p, 0.7, 1.4)
            price[f["id"]] = max(2, round(f["basePrice"] * want_mean / means[f["id"]]))
    cap_shares(rarity)
    return {"fish_rarity": rarity, "fish_price": price}


# At its best spot, time and bait, a fish may be at most this share of the bites, so even a
# player who camps on the perfect spot sees an Epic only now and then and a Legendary rarely.
# Commons have no cap; Mythics only bite in their weather (weather is off in the sim's base run).
SHARE_CAP = {"Epic": 0.12, "Legendary": 0.025}
RANK = {t: i for i, t in enumerate(["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Godlike"])}


def cap_shares(rarity: dict) -> None:
    spots = sim.LAKE_SPOTS + sim.CREEK_SPOTS + sim.BIG_SPOTS + sim.BLUE_SPOTS
    saved = {sid: sim.FISH_BY_ID[sid]["rarity"] for sid in rarity}
    for sid, w in rarity.items():
        sim.FISH_BY_ID[sid]["rarity"] = w
    try:
        for _ in range(12):
            worst, best_x = {}, {}
            for spot in spots:
                for period in sim.PERIODS:
                    for b in sim.BAIT:
                        ws = sim.bite_weights(spot, period, b["id"])
                                        # A fish is capped only against the more common fish biting beside it. Alone,
                        # or among its peers, there is nothing to cap against (and it bites slowly).
                        for sid, x in ws:
                            r = RANK[PRISTINE[sid]["tier"]]
                            lower = sum(y for o, y in ws if RANK[PRISTINE[o]["tier"]] < r)
                            # judged where it bites most: its best spot, hour and bait
                            if x > best_x.get(sid, 0):
                                best_x[sid] = x
                                worst[sid] = x / (x + lower) if lower > 0 else 0
            changed = False
            for sid, share in worst.items():
                cap = SHARE_CAP.get(PRISTINE[sid]["tier"])
                if cap and share > cap * 1.02:
                    # share = w / (w + rest); solve for the w that gives the cap
                    w = sim.FISH_BY_ID[sid]["rarity"]
                    rest = w * (1 - share) / share  # the more common fish's weight at that combo
                    sim.FISH_BY_ID[sid]["rarity"] = round(cap * rest / (1 - cap), 5)
                    changed = True
            if not changed:
                break
        for sid in rarity:
            rarity[sid] = sim.FISH_BY_ID[sid]["rarity"]
    finally:
        for sid, w in saved.items():
            sim.FISH_BY_ID[sid]["rarity"] = w


def reset():
    for sid, v in PRISTINE.items():
        sim.FISH_BY_ID[sid].update({"rarity": v["rarity"], "basePrice": v["basePrice"]})
    sim._mean_price_cache.clear()


def measure(prop: dict | None, runs: int, only: str | None = None) -> dict:
    reset()
    if prop:
        sim.use_proposal(prop)
    out = {}
    for strat in (sim.Smart(pond=False), sim.DockWorms()):
        if only and strat.name != only:
            continue
        firsts, goals, tiers, legs = [], {g: [] for g, _ in sim.GOALS}, {}, []
        for i in range(runs):
            p, per, _ = sim.run_career(strat, seed=2000 + i, sessions=20, stop_early=False)
            firsts.append(per[0])
            for g in goals:
                if p.goal_minutes.get(g) is not None:
                    goals[g].append(p.goal_minutes[g])
            for k, v in p.tiers.items():
                tiers[k] = tiers.get(k, 0) + v
            legs += [st["Legendary"] for st in p.session_tiers]
        n = sum(tiers.values()) or 1
        out[strat.name] = {
            "rate": statistics.median(firsts),
            "goals": {g: (statistics.median(v) if len(v) >= runs / 2 else None) for g, v in goals.items()},
            "shares": {t: 100 * tiers.get(t, 0) / n for t in sim.TIER_ORDER},
            "leg_per_session": statistics.mean(legs) if legs else 0,
        }
    return out


def show(label: str, m: dict) -> None:
    print(f"\n### {label}")
    for name, r in m.items():
        g = ", ".join(f"{k} {v:.0f} min" if v is not None else f"{k} not reached" for k, v in r["goals"].items())
        sh = " ".join(f"{t[:3]} {r['shares'][t]:.0f}%" for t in sim.TIER_ORDER[:6])
        print(f"- {name}: {r['rate']:.1f} coins/min first session; {g}; {sh}; Legendary per session {r['leg_per_session']:.2f}")


def write(prop: dict) -> None:
    for rel in ("src/ReplicatedStorage/Shared/FishData.luau", "src/ReplicatedStorage/Shared/BigLakeFishData.luau"):
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        blocks = re.split(r"(?=\n\t\{\n\t\tid = \")", text)
        for i, b in enumerate(blocks):
            m = re.search(r'\n\t\{\n\t\tid = "(\w+)"', b)
            if not m or m.group(1) not in prop["fish_rarity"]:
                continue
            sid = m.group(1)
            b = re.sub(r"(\n\t\trarity = )[0-9.]+", lambda x: x.group(1) + f"{prop['fish_rarity'][sid]:g}", b, count=1)
            b = re.sub(r"(\n\t\tbasePrice = )[0-9.]+", lambda x: x.group(1) + str(prop["fish_price"][sid]), b, count=1)
            blocks[i] = b
        path.write_text("".join(blocks), encoding="utf-8")
        print("wrote", rel)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--common", type=float, default=0, help="skip the search and use this Common mean price")
    a = ap.parse_args()
    before = measure(None, a.runs)
    show("Today", before)
    def bisect(lo, hi, rate_of, target, label):
        mid = (lo + hi) / 2
        for _ in range(7):
            mid = (lo + hi) / 2
            r = rate_of(mid)
            print(f"  {label} {mid:.3f}: {r:.1f} coins/min (today {target:.1f})")
            lo, hi = (mid, hi) if r < target else (lo, mid)
        return mid

    runs = max(4, a.runs // 2)
    # 1. Common price: the dock kid (mostly Common and Uncommon) keeps today's income.
    dock = "dock and worms"
    best = a.common or bisect(2.0, 20.0, lambda c: measure(proposal(c), runs, dock)[dock]["rate"], before[dock]["rate"], "Common price")
    # 2. Premium on Rare and up: the smart player keeps today's income too.
    smart = "smart, no pond"
    prem = bisect(0.3, 3.0, lambda m: measure(proposal(best, m), runs, smart)[smart]["rate"], before[smart]["rate"], "Rare-and-up premium")
    prop = proposal(best, prem)
    after = measure(prop, a.runs)
    show(f"Retuned (Common mean price {best:.2f}, Rare-and-up premium {prem:.2f})", after)
    print("\nNew numbers (rarity weight, base price):")
    for sid, v in PRISTINE.items():
        print(f"  {sid:<16} {v['tier']:<10} rarity {v['rarity']:>5} -> {prop['fish_rarity'][sid]:<7} basePrice {v['basePrice']:>5g} -> {prop['fish_price'][sid]}")
    if a.write:
        write(prop)


if __name__ == "__main__":
    main()
