"""Economy simulation for the fishing game.

Reads the real numbers from src/ReplicatedStorage/Shared (fish, bait, rods, config),
ports the bite, size, price, fight and pond rules to Python, and plays three kinds of
player through 25 minute sessions:

  smart   picks the best spot and bait for the time of day, keeps fish in the pond
  dock    stands on the dock with worms all day (what a new kid probably does)
  random  wanders to random spots with random bait

Run:  python3 tools/econ/sim.py            (full report, about a minute)
      python3 tools/econ/sim.py --quick    (fewer runs, for a fast check)

Nothing here changes the game. Numbers in docs/ECONOMY.md come from this script.
"""

import argparse
import math
import random
import statistics
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from luau_data import load_all  # noqa: E402

DATA = load_all()
CFG = DATA["config"]
FISH = DATA["fish"]
FISH_BY_ID = {f["id"]: f for f in FISH}
BAIT = DATA["bait"]
BAIT_BY_ID = {b["id"]: b for b in BAIT}
RODS = DATA["rods"]
ROD_BY_ID = {r["id"]: r for r in RODS}

LAKE_SPOTS = ["Dock", "WeedBed", "Logs", "DeepHole", "OpenWater"]
CREEK_SPOTS = ["Riffle", "Rocks", "Pool"]
PERIODS = ["Dawn", "Day", "Dusk", "Night"]
GOALS = [
    ("Fiberglass Rod", ROD_BY_ID["Fiberglass"]["price"]),
    ("Creek Pass", CFG["CREEK_PASS_PRICE"]),
    ("Graphite Rod", ROD_BY_ID["Graphite"]["price"]),
]

# Walking distance in studs from the two stands to where you stand to fish each spot,
# measured off WorldBuilder.luau (paths, dock, creek gate). Walk speed is Roblox's 16.
WALK_FROM_STANDS = {
    "Dock": 60, "DeepHole": 60, "OpenWater": 45, "WeedBed": 90, "Logs": 90,
    "Riffle": 300, "Rocks": 290, "Pool": 320,
}
WALK_SPEED = 16
SPOT_SPOT_WALK = 70  # rough studs between two lake spots (creek stretches are closer)
CREEK_SPOT_WALK = 40

# Time costs in real seconds (from Config and the client flow).
CAST_OVERHEAD = CFG["CHARGE_TIME"] * 0.8 + 0.7  # charge most of the way, line flies, bobber lands
HOOK_REACTION = 0.5
AFTER_CATCH = CFG["FIGHT_GRACE"] + 0.7  # grace period plus a glance at the catch card
AFTER_ESCAPE = 1.0
SELL_MENU = 3.0
SHOP_MENU = 6.0
SESSION_MIN = 25
OFFLINE_HOURS = 23.5  # one session a day; the pond caps this at 8 h anyway


# ---------------------------------------------------------------- fishing rules (ports)

def period_from_clock(c):
    c %= 24
    if 5 <= c < 8:
        return "Dawn"
    if 8 <= c < 17:
        return "Day"
    if 17 <= c < 20:
        return "Dusk"
    return "Night"


# The game switched to the new bite rule on 2026-11-26 (Config.BITE_SLOWEST); the old one is
# kept here so the "before" numbers in docs/ECONOMY.md can be reproduced.
BITE_RULE = "proposed" if "BITE_SLOWEST" in CFG else "current"
BITE_SLOWEST = CFG.get("BITE_SLOWEST", 40)  # slowest bite; weaker combos count as "nothing here"


# Weather (a Python port of Weather.luau; keep the two in step). WEATHER_NOW is the weather
# kind right now, or None for plain clear days (the default; --weather turns the mix on).
WEATHER_ON = False
WEATHER_NOW = None
WIND_NOW = None
LOW_LIGHT = {"LargemouthBass", "Walleye", "BlackCrappie", "NorthernPike", "SmallmouthBass", "Bowfin", "Muskellunge"}
PREDATORS = {k: 1.4 for k in ["LargemouthBass", "NorthernPike", "Walleye", "SmallmouthBass", "WhiteBass", "Muskellunge", "Bowfin"]}
WEATHER = {
    "Clear": dict(chance=0.33),
    "Overcast": dict(chance=0.25, spots=dict(WeedBed=1.3, Dock=1.2, Riffle=1.2, Rocks=1.1, DeepHole=0.85, Pool=0.85, DropOff=0.85), dawn=LOW_LIGHT),
    "Fog": dict(chance=0.15, dawn=LOW_LIGHT),
    "Wind": dict(chance=0.15),
    "PreStorm": dict(chance=0.12, all=1.3, species=dict(LargemouthBass=1.6, NorthernPike=1.6, ChannelCatfish=1.6, Walleye=1.6, WhiteBass=1.6)),
    "Storm": dict(chance=0, all=0.6),
    "ColdFront": dict(chance=0, all=0.5, spots=dict(DeepHole=1.6, Pool=1.6, DropOff=1.6, Dock=1.2)),
}
SPOT_SIDE = {"WeedBed": "west", "Logs": "east", "Dock": "south", "DeepHole": "north"}
OPPOSITE = {"north": "south", "south": "north", "east": "west", "west": "east"}


def plan_day(rng, previous):
    if previous == "PreStorm":
        return "ColdFront", None
    r, acc = rng.random(), 0
    for k, v in WEATHER.items():
        acc += v["chance"]
        if v["chance"] > 0 and r < acc:
            return k, (rng.choice(list(OPPOSITE)) if k == "Wind" else None)
    return "Clear", None


def weather_at(kind, clock):
    c = clock % 24
    if kind == "Fog" and (c >= 10 or c < 5):
        return "Clear"
    if kind == "PreStorm":
        if 15 <= c < 18:
            return "Storm"
        if c < 13 or c >= 18:
            return "Clear"
    return kind


def weather_mult(sid, spot):
    k = WEATHER.get(WEATHER_NOW or "Clear", {})
    m = k.get("all", 1) * k.get("spots", {}).get(spot, 1)
    if WEATHER_NOW == "Wind" and WIND_NOW:
        side = SPOT_SIDE.get(spot)
        if side == OPPOSITE[WIND_NOW]:
            m *= PREDATORS.get(sid, 1)
        elif side == WIND_NOW:
            m *= 0.8
    else:
        m *= k.get("species", {}).get(sid, 1)
    return m


def bite_weights(spot, period, bait):
    out = []
    k = WEATHER.get(WEATHER_NOW or "Clear", {})
    for s in FISH:
        if s.get("weather") and (s["weather"].get(WEATHER_NOW or "Clear", 0) <= 0):
            continue  # Mythics only bite in their weather
        p = "Dawn" if (period == "Day" and s["id"] in k.get("dawn", ())) else period
        w = s["rarity"] * s["spots"].get(spot, 0) * s["periods"].get(p, 0) * s["baits"].get(bait, 0)
        w *= weather_mult(s["id"], spot)
        if w > 0:
            out.append((s["id"], w))
    out.sort(key=lambda x: -x[1])
    if BITE_RULE == "proposed" and sum(w for _, w in out) < CFG["BITE_MIN"] / BITE_SLOWEST:
        return []
    return out


def pick_species(weights, rng):
    t = sum(w for _, w in weights)
    r = rng.random() * t
    for sid, w in weights:
        r -= w
        if r <= 0:
            return sid
    return weights[-1][0]


def bite_delay_base(weights):
    t = sum(w for _, w in weights)
    if BITE_RULE == "proposed":
        return min(max(CFG["BITE_MIN"] / t, CFG["BITE_MIN"]), BITE_SLOWEST)
    q = min(max(t, 0), 1)
    return CFG["BITE_MAX"] - (CFG["BITE_MAX"] - CFG["BITE_MIN"]) * q


def bite_delay(weights, rng):
    return bite_delay_base(weights) * (0.75 + rng.random() * 0.5)


def roll_size(s, rng):
    u = (rng.random() + rng.random()) / 2
    if rng.random() < 0.05:
        u = 0.85 + rng.random() * 0.15
    cm = round((s["minCm"] + (s["maxCm"] - s["minCm"]) * u) * 10) / 10
    kg = max(0.01, round(s["weightCoef"] * cm ** 3 * 100) / 100)
    return cm, kg


# Trophy and monster catches (rarity plan; values read from Rarity.luau so they stay in step).
def _rarity_consts():
    import re
    src = (Path(__file__).resolve().parents[2] / "src/ReplicatedStorage/Shared/Rarity.luau").read_text()
    def num(name):
        return float(re.search(r"Rarity\." + name + r"\s*=\s*([0-9.]+)", src).group(1))
    def pair(name):
        a, b = re.search(r"Rarity\." + name + r"\s*=\s*\{\s*([0-9.]+),\s*([0-9.]+)\s*\}", src).groups()
        return float(a), float(b)
    fights = {}
    for cls in ("trophy", "monster"):
        g, h = re.search(cls + r"\s*=\s*\{\s*gain\s*=\s*([0-9.]+),\s*heavy\s*=\s*([0-9.]+)", src).groups()
        fights[cls] = (float(g), float(h))
    return {
        "monster": num("MONSTER_CHANCE"), "trophy": num("TROPHY_CHANCE"),
        "monster_len": pair("MONSTER_LENGTH"), "trophy_len": pair("TROPHY_LENGTH"),
        "heavy_cap": num("HEAVY_CAP"), "fights": fights,
    }


RARITY = _rarity_consts()
SIZE_CLASSES = True  # --no-size-classes turns trophies and monsters off for a comparison


def roll_catch(s, rng):
    """Like FishLogic.rollCatch: size class first, then length and weight."""
    if SIZE_CLASSES:
        r = rng.random()
        rng_len = None
        if r < RARITY["monster"]:
            cls, rng_len = "monster", RARITY["monster_len"]
        elif r < RARITY["monster"] + RARITY["trophy"]:
            cls, rng_len = "trophy", RARITY["trophy_len"]
        if rng_len:
            cm = round(s["maxCm"] * (rng_len[0] + (rng_len[1] - rng_len[0]) * rng.random()) * 10) / 10
            kg = max(0.01, round(s["weightCoef"] * cm ** 3 * 100) / 100)
            return cm, kg, cls
    cm, kg = roll_size(s, rng)
    return cm, kg, "normal"


def fight_for(profile, cls):
    if cls == "normal":
        return profile
    g, h = RARITY["fights"][cls]
    p = dict(profile)
    p["gain"] = profile["gain"] * g
    p["heavy"] = min(RARITY["heavy_cap"], profile["heavy"] + h)
    return p


def price_for(s, kg):
    mid = (s["minCm"] + s["maxCm"]) / 2
    avg = s["weightCoef"] * mid ** 3
    return max(1, math.floor(s["basePrice"] * (kg / avg) ** 0.8 + 0.5))


def price_at_cm(s, cm):
    kg = max(0.01, round(s["weightCoef"] * cm ** 3 * 100) / 100)
    return price_for(s, kg)


_mean_price_cache = {}


def mean_price(sid):
    if sid not in _mean_price_cache:
        rng = random.Random(99)
        s = FISH_BY_ID[sid]
        vals = [price_for(s, roll_size(s, rng)[1]) for _ in range(4000)]
        _mean_price_cache[sid] = statistics.mean(vals)
    return _mean_price_cache[sid]


# ---------------------------------------------------------------- fight (FightModel port)

class Skill:
    def __init__(self, name, reaction, deadband, lapse_rate, lapse_len):
        self.name, self.reaction, self.deadband = name, reaction, deadband
        self.lapse_rate, self.lapse_len = lapse_rate, lapse_len


KID = Skill("kid", reaction=0.30, deadband=0.03, lapse_rate=0.25, lapse_len=0.4)
GOOD = Skill("good", reaction=0.18, deadband=0.02, lapse_rate=0.05, lapse_len=0.3)
IDLE = Skill("idle", reaction=0.1, deadband=99, lapse_rate=0, lapse_len=0)  # never touches the button


def apply_rod(profile, rod_id):
    rod = ROD_BY_ID.get(rod_id, ROD_BY_ID["Willow"])
    p = dict(profile)
    p["zone"] = min(0.6, profile["zone"] * rod["zoneMult"])
    p["heavy"] = profile["heavy"] * (1 - rod["heavyResist"])
    return p


def fight_once(profile, assist, skill, rng, dt=1 / 30):
    p = profile
    zone_size = p["zone"] * (CFG["ASSIST_ZONE"] if assist else 1)
    loss = p["loss"] * (CFG["ASSIST_LOSS"] if assist else 1)
    climb = 1 - p["heavy"] * 0.2
    fish = target = 0.5
    zone, vel = 0.4, 0.0
    prog = CFG["FIGHT_START"]
    t = 0.0
    history = []
    lag = max(1, int(skill.reaction / dt))
    holding = False
    lapse = 0.0
    idle = math.inf  # seconds since the last press or hold (the game's slack-line rule)
    grace = CFG.get("FIGHT_IDLE_GRACE")
    k = CFG["ZONE_RESPONSE"]
    while t < CFG["FIGHT_MAX_SECONDS"]:
        history.append(fish)
        seen = history[-lag] if len(history) >= lag else 0.5
        if lapse > 0:
            lapse -= dt
            want = False
        else:
            if rng.random() < skill.lapse_rate * dt:
                lapse = skill.lapse_len
            want = seen > zone + skill.deadband if not holding else seen > zone - skill.deadband
            if grace is not None and idle > grace - 0.5 and skill.deadband < 1:
                want = True  # the "Keep reeling!" cue: a real player taps
        if want and not holding:
            vel = max(vel, CFG["PRESS_KICK"] * climb)
        holding = want
        idle = 0.0 if holding else idle + dt
        t += dt
        tgt = CFG["ZONE_UP_SPEED"] * climb if holding else -CFG["ZONE_DOWN_SPEED"]
        decay = math.exp(-k * dt)
        zone += tgt * dt + (vel - tgt) * (1 - decay) / k
        vel = tgt + (vel - tgt) * decay
        half = zone_size / 2
        if zone < half:
            zone, vel = half, max(vel, 0)
        elif zone > 1 - half:
            zone, vel = 1 - half, min(vel, 0)
        if rng.random() < p["dart"] * dt:
            off = (rng.random() * 2 - 1) * p["range"] - p["sink"] * p["range"] * 0.5
            target = min(max(fish + off, 0.05), 0.95)
        d = target - fish
        mv = p["speed"] * dt
        fish = target if abs(d) <= mv else fish + math.copysign(mv, d)
        if abs(fish - zone) <= half:
            if grace is None or idle <= grace:
                prog += p["gain"] * dt
            else:
                prog -= loss * 0.5 * dt
        else:
            prog -= loss * dt
        if prog >= 1:
            return True, t
        if prog <= 0:
            return False, t
    return False, t


_fight_cache = {}


def fight_stats(sid, rod, skill, assist=True, trials=300):
    key = (sid, rod, skill.name, assist, trials)
    if key not in _fight_cache:
        rng = random.Random(hash(key) & 0xFFFF)
        prof = apply_rod(FISH_BY_ID[sid]["fight"], rod)
        wins, wt, lt = 0, [], []
        for _ in range(trials):
            ok, t = fight_once(prof, assist, skill, rng)
            if ok:
                wins += 1
                wt.append(t)
            else:
                lt.append(t)
        _fight_cache[key] = (
            wins / trials,
            statistics.mean(wt) if wt else 30.0,
            statistics.mean(lt) if lt else 10.0,
        )
    return _fight_cache[key]


# ---------------------------------------------------------------- pond (PondLogic port)

def pond_grow(f, hours):
    s = FISH_BY_ID[f["id"]]
    if hours > 0 and f["cm"] < s["maxCm"]:
        gap = s["maxCm"] - f["cm"]
        f["cm"] = s["maxCm"] - gap * math.exp(-CFG["POND_GROW_RATE"] * hours)
    f["cm"] = min(round(f["cm"] * 10) / 10, s["maxCm"])
    f["price"] = price_at_cm(s, f["cm"])


def is_grown(f):
    s = FISH_BY_ID[f["id"]]
    return f["cm"] >= s["minCm"] + 0.6 * (s["maxCm"] - s["minCm"])


def pond_tick(pond, seconds, state, rng):
    remaining = min(max(seconds, 0), CFG["POND_OFFLINE_CAP"])
    born = 0
    while remaining > 0:
        step = min(remaining, CFG["POND_BREED_EVERY"] - state["breed"])
        for f in pond:
            pond_grow(f, step / 3600)
        state["breed"] += step
        remaining -= step
        if state["breed"] >= CFG["POND_BREED_EVERY"]:
            state["breed"] = 0
            grown = defaultdict(int)
            for f in pond:
                if is_grown(f):
                    grown[f["id"]] += 1
            for s in FISH:
                if grown[s["id"]] >= 2 and len(pond) < CFG["POND_CAPACITY"] and rng.random() < CFG["POND_BREED_CHANCE"]:
                    young = {"id": s["id"], "cm": s["minCm"], "price": 0, "born": True}
                    pond_grow(young, 0)
                    pond.append(young)
                    born += 1
    return born


def pond_gain(f):
    """Coins a fish would gain if left to grow to full size."""
    s = FISH_BY_ID[f["id"]]
    return price_at_cm(s, s["maxCm"]) - price_at_cm(s, f["cm"])


# ---------------------------------------------------------------- the player

class Player:
    def __init__(self):
        self.coins = CFG["START_COINS"]
        self.bait = defaultdict(int, {"Worm": int(CFG["START_WORMS"])})
        self.lures = set()
        self.rod = "Willow"
        self.creek = False
        self.bag = []  # list of (sid, price, cm)
        self.pond = []
        self.pond_state = {"breed": 0}
        self.earned = defaultdict(float)  # where coins came from
        self.spent = defaultdict(float)
        self.goal_i = 0
        self.goal_minutes = {}
        self.catches = 0
        self.gross = 0.0  # value of every fish caught and sold, before spending
        self.played = 0.0  # real seconds of play

    def has(self, bait):
        if BAIT_BY_ID[bait]["kind"] == "lure":
            return bait in self.lures
        return self.bait[bait] > 0

    def bag_value(self):
        return sum(p for _, p, _ in self.bag)

    def next_goal(self):
        return GOALS[self.goal_i] if self.goal_i < len(GOALS) else None


def expected_rate(spot, period, bait, player, skill, hook_p):
    """Expected coins per real second for fishing one spot with one bait now."""
    w = bite_weights(spot, period, bait)
    if not w:
        return 0.0, None
    tot = sum(x for _, x in w)
    wait = bite_delay_base(w) / hook_p + HOOK_REACTION
    coins, t = 0.0, CAST_OVERHEAD + wait
    for sid, x in w:
        share = x / tot
        pw, tw, tl = fight_stats(sid, player.rod, skill)
        coins += share * pw * mean_price(sid)
        t += share * (pw * (tw + AFTER_CATCH) + (1 - pw) * (tl + AFTER_ESCAPE))
    b = BAIT_BY_ID[bait]
    if b["kind"] == "live":
        coins -= b["price"] / b["pack"]
    return coins / t, w


class Strategy:
    name = "base"
    skill = KID
    hook_p = 0.88
    uses_pond = False

    def spots(self, p):
        return LAKE_SPOTS + (CREEK_SPOTS if p.creek else [])

    def choose(self, p, period, rng, current):
        raise NotImplementedError

    def bait_to_buy(self, p, wanted, rng):
        return wanted


class Smart(Strategy):
    name = "smart"
    hook_p = 0.92

    def __init__(self, pond=True, skill=KID):
        self.uses_pond = pond
        self.skill = skill
        if not pond:
            self.name = "smart, no pond"
        if skill is GOOD:
            self.name += ", quick hands"

    def options(self, p, period):
        out = []
        for spot in self.spots(p):
            for b in BAIT:
                if b["kind"] == "lure" and b["id"] not in p.lures:
                    continue
                r, _ = expected_rate(spot, period, b["id"], p, self.skill, self.hook_p)
                if r > 0:
                    out.append((r, spot, b["id"]))
        out.sort(reverse=True)
        return out

    def choose(self, p, period, rng, current):
        opts = self.options(p, period)
        # Stay put unless moving pays: walking to a far spot costs time.
        best = opts[0]
        if current and current[0] != best[1]:
            for r, spot, bait in opts:
                if spot == current[0] and r >= best[0] * 0.9:
                    return spot, bait
        return best[1], best[2]

    def lure_worth_buying(self, p, period):
        """Buy a lure when it pays itself back within about 6 minutes of play."""
        base = self.options(p, period)[0][0]
        for b in BAIT:
            if b["kind"] != "lure" or b["id"] in p.lures or p.coins < b["price"]:
                continue
            best = max(
                (expected_rate(s, period, b["id"], p, self.skill, self.hook_p)[0] for s in self.spots(p)),
                default=0,
            )
            if best > base and b["price"] / (best - base) < 360:
                return b["id"]
        return None


class DockWorms(Strategy):
    name = "dock and worms"

    def choose(self, p, period, rng, current):
        return "Dock", "Worm"


class RandomPlayer(Strategy):
    name = "random"
    hook_p = 0.85

    def choose(self, p, period, rng, current):
        if current and rng.random() < 0.8:  # tends to stay a while
            spot = current[0]
        else:
            spot = rng.choice(self.spots(p))
        owned = [b["id"] for b in BAIT if p.has(b["id"])]
        return spot, rng.choice(owned) if owned else "Worm"

    def bait_to_buy(self, p, wanted, rng):
        affordable = [b["id"] for b in BAIT if b["price"] <= p.coins and not (b["kind"] == "lure" and b["id"] in p.lures)]
        if not affordable:
            return None
        live = [x for x in affordable if BAIT_BY_ID[x]["kind"] == "live"]
        if live and rng.random() < 0.85:
            return rng.choice(live)
        return rng.choice(affordable)


def walk_time(a, b):
    if a == b:
        return 0
    if a is None or b is None:
        return WALK_FROM_STANDS.get(a or b, 60) / WALK_SPEED
    if a in CREEK_SPOTS and b in CREEK_SPOTS:
        return CREEK_SPOT_WALK / WALK_SPEED
    if (a in CREEK_SPOTS) != (b in CREEK_SPOTS):
        return 260 / WALK_SPEED
    if {a, b} <= {"Dock", "DeepHole"}:
        return 0
    return SPOT_SPOT_WALK / WALK_SPEED


def play_session(p, strat, rng, clock_start, minutes=SESSION_MIN, log=None):
    """Play one session. Returns coins earned from fish (sold or held) during it."""
    t = 0.0
    end = minutes * 60
    here = None  # spot we stand at
    plan = None  # (spot, bait)
    start_value = p.coins + p.bag_value()

    def clock():
        return clock_start + t * 24 / CFG["DAY_LENGTH"]

    def go_to_stands(reason):
        nonlocal t, here
        t += walk_time(here, None)
        here = None
        sold = p.bag_value()
        if p.bag:
            t += SELL_MENU
            p.coins += sold
            p.earned["fish"] += sold
            p.bag = []
        # Buy goals in order whenever affordable.
        while True:
            g = p.next_goal()
            if g and p.coins >= g[1] and (g[0] != "Graphite Rod" or True):
                p.coins -= g[1]
                p.spent[g[0]] += g[1]
                if g[0] == "Fiberglass Rod":
                    p.rod = "Fiberglass"
                elif g[0] == "Graphite Rod":
                    p.rod = "Graphite"
                else:
                    p.creek = True
                p.goal_minutes[g[0]] = (p.played + t) / 60
                p.goal_i += 1
                t += SHOP_MENU
                if log is not None:
                    log.append(f"{(p.played + t) / 60:6.1f} min  bought {g[0]}")
            else:
                break

    def buy_bait(bait):
        nonlocal t
        if bait is None:
            return False
        b = BAIT_BY_ID[bait]
        if p.coins < b["price"]:
            return False
        p.coins -= b["price"]
        p.spent["bait"] += b["price"]
        if b["kind"] == "lure":
            p.lures.add(bait)
        else:
            p.bait[bait] += int(b["pack"])
        t += SHOP_MENU
        return True

    global WEATHER_NOW, WIND_NOW
    day_kind, day_wind, day_index = "Clear", None, None
    while t < end:
        period = period_from_clock(clock())
        if WEATHER_ON:
            d = int(clock() // 24)
            if d != day_index:
                day_index = d
                day_kind, day_wind = plan_day(rng, day_kind)
            WEATHER_NOW, WIND_NOW = weather_at(day_kind, clock()), day_wind
        if isinstance(strat, Smart):
            lure = strat.lure_worth_buying(p, period)
            if lure and p.coins >= BAIT_BY_ID[lure]["price"]:
                go_to_stands("lure")
                buy_bait(lure)
        plan = strat.choose(p, period, rng, plan)
        spot, bait = plan
        if not p.has(bait):
            # Need bait: walk to the shop, sell first so there is money.
            go_to_stands("bait")
            want = strat.bait_to_buy(p, bait, rng)
            if not buy_bait(want):
                if not any(p.has(b["id"]) for b in BAIT):
                    cheapest = min(b["price"] for b in BAIT)
                    if p.coins < cheapest:
                        p.bait["Worm"] += int(CFG["FREE_WORMS"])  # the shopkeeper's free worms
                plan = strat.choose(p, period, rng, None)
                spot, bait = plan
                if not p.has(bait):
                    owned = [b["id"] for b in BAIT if p.has(b["id"])]
                    if not owned:
                        t += 5
                        continue
                    bait = owned[0]
                    plan = (spot, bait)
            # A smart player stocks up for the period: two packs if cheap enough.
            if isinstance(strat, Smart) and BAIT_BY_ID[bait]["kind"] == "live":
                b = BAIT_BY_ID[bait]
                if p.coins >= b["price"] * 2 and p.bait[bait] < 10:
                    buy_bait(bait)
        if len(p.bag) >= CFG["BAG_LIMIT"]:
            go_to_stands("bag full")
            continue
        g = p.next_goal()
        if g and p.coins + p.bag_value() >= g[1] and p.coins < g[1]:
            go_to_stands("goal")
            continue
        t += walk_time(here, spot)
        here = spot
        # One cast.
        w = bite_weights(spot, period, bait)
        t += CAST_OVERHEAD
        if not w:
            t += CFG["NOTHING_WAIT"]
            if isinstance(strat, RandomPlayer):
                plan = (rng.choice(strat.spots(p)), plan[1])
            continue
        hooked = False
        while not hooked and t < end:
            t += bite_delay(w, rng)
            if rng.random() < strat.hook_p:
                hooked = True
                t += HOOK_REACTION
            else:
                t += CFG["HOOK_WINDOW"]
        if not hooked:
            break
        sid = pick_species(w, rng)
        if BAIT_BY_ID[bait]["kind"] == "live":
            p.bait[bait] -= 1
        s = FISH_BY_ID[sid]
        cm, kg, cls = roll_catch(s, rng)  # rolled at the hook, as on the server
        prof = apply_rod(fight_for(s["fight"], cls), p.rod)
        won, ft = fight_once(prof, True, strat.skill, rng)
        t += ft
        if not won:
            t += AFTER_ESCAPE
            continue
        t += AFTER_CATCH
        price = price_for(s, kg)
        p.catches += 1
        kept = False
        if strat.uses_pond:
            cand = {"id": sid, "cm": cm, "price": price, "born": False}
            pond_grow(cand, 0)
            if len(p.pond) < CFG["POND_CAPACITY"] and pond_gain(cand) >= 15:
                p.pond.append(cand)
                kept = True
                t += 4  # walk-free in practice? keeping happens at the pond panel; charge a little
        if not kept:
            p.bag.append((sid, price, cm))
            p.gross += price
        # Pond grows during play too.
        if strat.uses_pond and p.pond:
            pond_tick(p.pond, 0, p.pond_state, rng)
    if strat.uses_pond and p.pond:
        pond_tick(p.pond, minutes * 60, p.pond_state, rng)
    p.played += min(t, end)
    return p.coins + p.bag_value() - start_value


def visit_pond(p, rng):
    """Start of a session: sell grown pond fish, keep two breeders of the best kind."""
    if not p.pond:
        return 0
    by_species = defaultdict(list)
    for f in p.pond:
        by_species[f["id"]].append(f)
    keep_species = max(by_species, key=lambda k: price_at_cm(FISH_BY_ID[k], FISH_BY_ID[k]["maxCm"]))
    breeders = sorted(by_species[keep_species], key=lambda f: -f["cm"])[:2] if len(by_species[keep_species]) >= 2 else []
    sold = 0
    for f in list(p.pond):
        if f in breeders:
            continue
        s = FISH_BY_ID[f["id"]]
        if f["cm"] >= s["maxCm"] * 0.95 or (f["cm"] - s["minCm"]) >= 0.9 * (s["maxCm"] - s["minCm"]):
            p.pond.remove(f)
            p.coins += f["price"]
            p.earned["pond"] += f["price"]
            p.gross += f["price"]
            sold += f["price"]
    return sold


def run_career(strat, seed, sessions=12, log=None, stop_early=True):
    rng = random.Random(seed)
    p = Player()
    per_session = []
    pond_per_day = []
    for day in range(sessions):
        if day > 0 and strat.uses_pond:
            pond_tick(p.pond, OFFLINE_HOURS * 3600, p.pond_state, rng)
            pond_per_day.append(visit_pond(p, rng))
        before = p.gross
        play_session(p, strat, rng, clock_start=rng.random() * 24, log=log)
        per_session.append((p.gross - before) / SESSION_MIN)
        if stop_early and p.goal_i >= len(GOALS) and day >= 3:
            break
    return p, per_session, pond_per_day


# ---------------------------------------------------------------- proposal

# The six changes in docs/ECONOMY.md were applied to the game on 2026-11-26, so the sim now
# reads them from src/. To try new ideas, put them here and run with --only proposal.
PROPOSAL = {}
APPLIED_2026_11_26 = {
    "bite_rule": "proposed",
    "fish_price": {
        "Bluegill": 6, "Pumpkinseed": 6, "YellowPerch": 10, "BlackCrappie": 12,
        "LargemouthBass": 20, "ChannelCatfish": 24, "CommonCarp": 18, "NorthernPike": 45,
        "RainbowTrout": 18, "SmallmouthBass": 22, "Walleye": 26,
    },
    "goals": {"Fiberglass Rod": 150, "Creek Pass": 500, "Graphite Rod": 900},
    "bait_price": {"Spinner": 100, "PlasticWorm": 100},
}


def use_proposal(prop=PROPOSAL):
    global BITE_RULE, GOALS
    BITE_RULE = prop.get("bite_rule", BITE_RULE)
    for sid, price in prop.get("fish_price", {}).items():
        FISH_BY_ID[sid]["basePrice"] = price
    for bid, price in prop.get("bait_price", {}).items():
        BAIT_BY_ID[bid]["price"] = price
    GOALS = [(g, prop.get("goals", {}).get(g, c)) for g, c in GOALS]
    _mean_price_cache.clear()


# ---------------------------------------------------------------- reports

def fmt_min(x):
    if x is None:
        return "not reached"
    return f"{x:.0f} min"


def table(rows, headers):
    w = [max(len(str(r[i])) for r in rows + [headers]) for i in range(len(headers))]
    line = "| " + " | ".join(h.ljust(w[i]) for i, h in enumerate(headers)) + " |"
    sep = "|" + "|".join("-" * (x + 2) for x in w) + "|"
    out = [line, sep]
    for r in rows:
        out.append("| " + " | ".join(str(c).ljust(w[i]) for i, c in enumerate(r)) + " |")
    return "\n".join(out)


def report_best_spots():
    p = Player()
    rows = []
    for creek in (False, True):
        p.creek = creek
        for period in PERIODS:
            smart = Smart(pond=False)
            opts = smart.options(p, period)
            r, spot, bait = opts[0]
            p.lures = {"Spinner", "PlasticWorm"}
            r2, spot2, bait2 = smart.options(p, period)[0]
            p.lures = set()
            rows.append([
                "lake + creek" if creek else "lake only", period,
                f"{spot} + {bait}", f"{r * 60:.0f}",
                f"{spot2} + {bait2}", f"{r2 * 60:.0f}",
            ])
    return table(rows, ["Water", "Time", "Best (live bait)", "coins/min", "Best (with both lures)", "coins/min"])


def report_fights(trials):
    rows = []
    for s in FISH:
        cells = [s["name"]]
        for rod in ("Willow", "Fiberglass", "Graphite"):
            pw, tw, _ = fight_stats(s["id"], rod, KID, trials=trials)
            cells.append(f"{pw * 100:.0f}% / {tw:.0f}s")
        pw, tw, _ = fight_stats(s["id"], "Willow", GOOD, trials=trials)
        cells.append(f"{pw * 100:.0f}% / {tw:.0f}s")
        pw, tw, _ = fight_stats(s["id"], "Willow", IDLE, trials=trials)
        cells.append(f"{pw * 100:.0f}% / {tw:.0f}s")
        cells.append(f"{mean_price(s['id']):.1f}")
        rows.append(cells)
    return table(rows, ["Fish", "Willow (kid)", "Fiberglass (kid)", "Graphite (kid)", "Willow (quick hands)", "Willow (no input at all)", "Avg price"])


def report_careers(runs):
    strategies = [Smart(pond=True), Smart(pond=False), Smart(pond=True, skill=GOOD), DockWorms(), RandomPlayer()]
    rows = []
    summary = {}
    for strat in strategies:
        firsts, goals = [], defaultdict(list)
        bait_share = []
        for i in range(runs):
            p, per, _ = run_career(strat, seed=1000 + i)
            firsts.append(per[0])
            for g, _ in GOALS:
                goals[g].append(p.goal_minutes.get(g))
            spent_bait = p.spent["bait"]
            gross = p.earned["fish"] + p.earned["pond"] + p.bag_value()
            bait_share.append(spent_bait / gross if gross else 0)
        row = [strat.name, f"{statistics.median(firsts):.1f}"]
        for g, _ in GOALS:
            vals = [x for x in goals[g] if x is not None]
            reached = len(vals) / runs
            if reached >= 0.5:
                row.append(f"{statistics.median(vals):.0f} min" + ("" if reached == 1 else f" ({reached * 100:.0f}% of runs)"))
            else:
                row.append("not in 12 sessions")
        row.append(f"{statistics.median(bait_share) * 100:.0f}%")
        rows.append(row)
        summary[strat.name] = row
    heads = ["Player", "coins/min, 1st session"] + [("+ " if i else "") + f"{g} ({c:g})" for i, (g, c) in enumerate(GOALS)]
    return table(rows, heads + ["bait spend"]), summary


def report_pond(runs):
    """Coins a full pond pays per day with one session a day (smart player)."""
    vals = []
    for i in range(runs):
        _, _, pond = run_career(Smart(pond=True), seed=5000 + i, sessions=10, stop_early=False)
        if len(pond) > 3:
            vals.append(statistics.mean(pond[2:]))
    # Theoretical: six fish kept at the low end of their size range, grown 8 h, sold.
    rows = []
    for s in FISH:
        lo = s["minCm"] + 0.25 * (s["maxCm"] - s["minCm"])
        f = {"id": s["id"], "cm": lo, "price": 0}
        pond_grow(f, 0)
        start = f["price"]
        pond_grow(f, 8)
        rows.append([s["name"], f"{lo:.0f} cm, {start}", f"{f['cm']:.0f} cm, {f['price']}", f"+{f['price'] - start}"])
    return (statistics.median(vals) if vals else 0.0), table(rows, ["Fish kept", "When kept", "After 8 h away", "Gain"])


def section(title, runs, trials):
    print(f"\n# {title}\n")
    print("## Best spot and bait by time of day (expected coins per real minute, Willow Rod, kid reflexes)\n")
    print(report_best_spots())
    print("\n## Fights: chance to land / seconds to land (reel assist on)\n")
    print(report_fights(trials))
    print("\n## Careers: play minutes until each purchase (bought in order, median)\n")
    print(report_careers(runs)[0])
    pond_day, pond_table = report_pond(max(6, runs // 4))
    print(f"\n## Home pond\n\nSmart player, pond income per day once it is running (median): {pond_day:.0f} coins\n")
    print(pond_table)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true", help="fewer runs")
    ap.add_argument("--no-size-classes", action="store_true", help="turn trophies and monsters off, to compare")
    ap.add_argument("--weather", action="store_true", help="play with the weather mix from Weather.luau")
    ap.add_argument("--log", action="store_true", help="print one smart career's purchases")
    ap.add_argument("--only", choices=["current", "proposal"], help="run just one of the two")
    args = ap.parse_args()
    global SIZE_CLASSES, WEATHER_ON
    SIZE_CLASSES = not args.no_size_classes
    WEATHER_ON = args.weather
    runs = 12 if args.quick else 60
    trials = 150 if args.quick else 400

    print("Fishing game economy simulation")
    print(f"Day {CFG['DAY_LENGTH'] / 60:.0f} real minutes; sessions of {SESSION_MIN} minutes, one a day; {runs} runs per player type.")
    if args.only != "proposal":
        section("Current numbers", runs, trials)
    if PROPOSAL and args.only != "current":
        use_proposal()
        section("With the proposed changes", runs, trials)
    if args.log:
        log = []
        run_career(Smart(pond=True), seed=1, log=log)
        print("\n## One smart career\n")
        print("\n".join(log))


if __name__ == "__main__":
    main()
