#!/usr/bin/env python3
"""Pacing model: what real players get, stage by stage, QC1-FE9.

The time table in the header of src/shared/Pacing.luau times a bare fighter
(passive + ~2 wolf kills of raw qi a minute, refined at 1.1) and a bare gardener
(meditating on their peak), plus the regular profile's online time. This model adds
what players actually stack: herb eating (tier share of the dantian with floors,
only the floor below the band's tier), garden yield and grow times, the garden aura
(every plant, by tier and rarity, capped by peak tier and lifted by decorating, on
your own peak only), the peak score's meditation and growth bonus, the best
meditation item, herb buffs (falloff, capped by realm), spirit root grade, the FE
cultivation method, spirit cores, daily login qi, the AFK/offline credit (one 12 h
budget a day, overflow cap 1.5, full carry), seclusion's encounters (band herbs and seeds), weather,
parties and the Herbalist's band-gated seeds.

Numbers are parsed from the game's source (Pacing.luau, Herbs.luau, Items.luau,
Config.luau, BuildItems.luau, Weather.luau) at run time, so a tuning change shows up
on the next run. Player behaviour (how long they play, how many plots, what they
eat) is in PROFILES and ROADS below: those are assumptions, documented in
docs/systems/pacing-model.md.

    python3 tools/pacing_model.py                 # the profiles, the balance check, the header check
    python3 tools/pacing_model.py --stages        # plus the stage-by-stage tables
    python3 tools/pacing_model.py --levers        # plus the one-lever-off sensitivity
    python3 tools/pacing_model.py --foundation    # plus foundation percent per stage
    python3 tools/pacing_model.py --proposal      # plus PROPOSAL's knob changes (when one is pending), side by side
    python3 tools/pacing_model.py --header        # print the Pacing header's time table for this curve

Nothing here is read by the game. Outside Studio, stdlib only.
"""

from __future__ import annotations

import argparse
import copy
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared"


# --------------------------------------------------------------------------
# Parsing the game's numbers
# --------------------------------------------------------------------------

def _read(name: str) -> str:
    return (SRC / name).read_text()


def _num(text: str, key: str, default=None):
    m = re.search(rf"\b{key}\s*=\s*(-?[\d.]+)", text)
    if not m:
        if default is None:
            raise KeyError(key)
        return default
    return float(m.group(1))


def _list(text: str, key: str) -> list[float]:
    m = re.search(rf"\b{key}\s*=\s*\{{([^}}]*)\}}", text)
    if not m:
        raise KeyError(key)
    return [float(x) for x in re.findall(r"-?[\d.]+", m.group(1))]


def _block(text: str, header: str) -> str:
    """The body of `header = {` up to its matching close brace."""
    i = text.index(header)
    i = text.index("{", i)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i + 1 : j]
    raise ValueError(header)


def _map(text: str, key: str) -> dict[str, float]:
    m = re.search(rf"\b{key}\s*=\s*\{{([^}}]*)\}}", text)
    if not m:
        raise KeyError(key)
    return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*(-?[\d.]+)", m.group(1))}


def load_game() -> dict:
    pacing = _read("Pacing.luau")
    herbs_src = _read("Herbs.luau")
    config = _read("Config.luau")
    weather = _read("Weather.luau")

    curve = []
    for line in _block(pacing, "Pacing.Curve =").splitlines():
        m = re.search(r"key\s*=\s*\"(\w+)\"", line)
        if not m:
            continue
        f = dict(re.findall(r"(\w+)\s*=\s*(-?[\d.]+)", line))
        major = re.search(r"major\s*=\s*\"(\w+)\"", line).group(1)
        curve.append({
            "key": m.group(1),
            "major": major,
            "bar": float(f["bar"]),
            "dantian": float(f["dantian"]),
            "passive": float(f["passive"]),
            "gather": float(f.get("gather", 1)),
        })

    income = _block(pacing, "Pacing.Income =")
    herbs_p = _block(pacing, "Pacing.Herbs =")
    med = _block(pacing, "Pacing.Meditation =")
    score = _block(pacing, "Pacing.PeakScore =")
    brk = _block(pacing, "Pacing.Breakthrough =")
    secl = _block(pacing, "Pacing.Seclusion =")
    roots = _block(pacing, "Pacing.Roots =")
    methods = _block(pacing, "Pacing.Methods =")
    party = _block(pacing, "Pacing.Party =")
    sect = _block(pacing, "Pacing.Sect =")
    glob = _block(pacing, "Pacing.Global =")
    aura = _block(pacing, "Pacing.Aura =")
    items_src = _read("Items.luau")
    adjust = {}
    for key, body in re.findall(r"\b([A-Z]{2}\d) = \{([^}]*)\}", _block(pacing, "Pacing.Adjust =")):
        adjust[key] = {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*(-?[\d.]+)", body)}

    grades = {g: float(s) for g, s in re.findall(r"(\w+)\s*=\s*\{\s*speed\s*=\s*([\d.]+)", roots)}

    # Herbs.Defs: one block per herb
    defs_txt = _block(herbs_src, "Herbs.Defs =")
    herbs = {}
    for m in re.finditer(r"\n\t(\w+) = \{", defs_txt):
        hid = m.group(1)
        start = m.end()
        depth, j = 1, start
        while depth:
            if defs_txt[j] == "{":
                depth += 1
            elif defs_txt[j] == "}":
                depth -= 1
            j += 1
        body = defs_txt[start:j]
        if re.search(r"\bdeferred\s*=\s*true", body):
            continue  # Herbs.Deferred: parked past Foundation, out of the game
        y = re.search(r"yield\s*=\s*\{\s*([\d.]+)\s*,\s*([\d.]+)", body)
        eat_txt = body[body.index("eat ="):] if "eat =" in body else ""
        eat_txt = eat_txt[: eat_txt.find("blurb")] if "blurb" in eat_txt else eat_txt
        buffs = [(float(a), float(s)) for a, s in re.findall(r"kind\s*=\s*\"QiRate\",\s*amount\s*=\s*([\d.]+),\s*seconds\s*=\s*([\d.]+)", eat_txt)]
        herbs[hid] = {
            "tier": int(_num(body, "tier")),
            "soil": re.search(r"soil\s*=\s*\"(\w+)\"", body).group(1),
            "grow": _num(body, "growSeconds"),
            "regrow": _num(body, "regrowSeconds", 0) or None,
            "yield": (float(y.group(1)) + float(y.group(2))) / 2,
            "soldFrom": (re.search(r'soldFrom\s*=\s*"(\w+)"', body) or [None, None])[1],
            "qi": bool(re.search(r"qi\s*=\s*true", eat_txt)),
            "buff": max(buffs, default=None),
            "spacing": _num(body, "spacing"),
            "wild": "wild =" in body,
            "seedCost": _num(body, "seedCost", 0) or None,
            "rarity": re.search(r'rarity\s*=\s*"(\w+)"', body).group(1),
            "mutatesTo": (re.search(r'mutatesTo\s*=\s*"(\w+)"', body) or [None, None])[1],
            "mutateChance": _num(body, "mutateChance", 0),
            "sellPrice": _num(body, "sellPrice", 0),
            "region": (re.search(r'region\s*=\s*"(\w+)"', body) or [None, None])[1],
        }

    # Herbs.Regions: each band's beast seed pool (+ its bosses'), for seclusion's finds
    regions = {}
    for rid, body in re.findall(r'id = "(\w+)",(.*?)\n\t\}', _block(herbs_src, "Herbs.Regions ="), re.S):
        pools = re.findall(r"(seeds|bossSeeds) = \{([^}]*)\}", body)
        regions[rid] = {k: {h: float(w) for h, w in re.findall(r"(\w+) = ([\d.]+)", v)} for k, v in pools}

    sizes = re.findall(r"weight\s*=\s*([\d.]+),\s*min\s*=\s*([\d.]+),\s*max\s*=\s*([\d.]+)", _block(herbs_src, "Herbs.Sizes ="))
    tw = sum(float(w) for w, _, _ in sizes)
    mean_size = sum(float(w) * (float(a) + float(b)) / 2 for w, a, b in sizes) / tw

    tiers = []
    for line in _block(config, "TIERS =").splitlines():
        m = re.search(r"from\s*=\s*\"(\w+)\".*HerbBed\s*=\s*(\d+).*scoreCap\s*=\s*(\d+)", line)
        if m:
            tiers.append({"from": m.group(1), "beds": int(m.group(2)), "scoreCap": float(m.group(3))})
    garden = _block(config, "Garden = {")

    # weather: time-weighted mean passive and circulation bonus
    wdefs = re.findall(r"\n\t(\w+) = \{(.*?)\n\t\}", _block(weather, "Weather.Defs =") if "Weather.Defs =" in weather else weather, re.S)
    tot = pas = circ = 0.0
    for wid, body in wdefs:
        w = re.search(r"weight\s*=\s*([\d.]+)", body)
        mins = re.search(r"minutes\s*=\s*\{\s*([\d.]+)\s*,\s*([\d.]+)", body)
        if not (w and mins):
            continue
        share = float(w.group(1)) * (float(mins.group(1)) + float(mins.group(2))) / 2
        tot += share
        b = re.search(r"bonus\s*=\s*\{\s*kind\s*=\s*\"(\w+)\",\s*amount\s*=\s*([\d.]+)", body)
        if b:
            if b.group(1) == "passive":
                pas += share * float(b.group(2))
            else:
                circ += share * float(b.group(2))
    weather_mean = {"passive": pas / tot if tot else 0, "circulation": circ / tot if tot else 0}

    # build pieces: the cheapest stones per peak-score point (Pacing.PeakScore)
    build_src = _read("BuildItems.luau")
    by_cat = _map(score, "BY_CATEGORY")
    gated = _map(score, "GATED")
    per_item = _num(score, "PER_ITEM")
    pieces = []
    for it in re.split(r"\n\t\{\n", build_src)[1:]:
        iid = re.search(r'id = "(\w+)"', it)
        cat = re.search(r'category = "(\w+)"', it)
        cost = re.search(r"\bcost = (\d+)", it)
        if not (iid and cat and cost):
            continue
        lim = re.search(r"\blimit = (\d+)", it)
        realm = re.search(r'realm = \{ major = "(\w+)"', it)
        sc = re.search(r"\bscore = (\d+)", it)
        pts = float(sc.group(1)) if sc else by_cat.get(cat.group(1), 0) + (gated.get(realm.group(1), 0) if realm else 0)
        copies = min(per_item, float(lim.group(1)) if lim else per_item)
        pieces.append({"id": iid.group(1), "category": cat.group(1), "cost": float(cost.group(1)), "points": pts,
                       "copies": copies, "realm": realm.group(1) if realm else None})
    # the Herbalist's band-gated tiers: the first stage each tier III+ is sold, and the
    # stones for a day's stock of its cheapest seed (enough to start the tier; seeds
    # back fill the plots)
    stock = _list(herbs_p, "STOCK")
    shop_from, shop_cost = {}, {}
    for h in herbs.values():
        if h["soldFrom"] and h["seedCost"]:
            t = h["tier"]
            if t not in shop_from or STAGES.index(h["soldFrom"]) < STAGES.index(shop_from[t]):
                shop_from[t] = h["soldFrom"]
            shop_cost[t] = min(shop_cost.get(t, 1e18), h["seedCost"] * stock[t - 1])
    quests = _block(pacing, "Pacing.Quests =")
    quest_stones = {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*\{\s*stones\s*=\s*(\d+)", quests)}

    return {
        "curve": curve,
        "pieces": pieces,
        "quest_stones": quest_stones,
        "SHOP_FROM": shop_from,
        "SHOP_START_COST": shop_cost,
        "STARTING_STONES": _num(_block(config, "Economy = {"), "STARTING_STONES"),
        "global": {"BAR": _num(glob, "BAR"), "PASSIVE": _num(glob, "PASSIVE"), "GATHER": _num(glob, "GATHER"), "REFINE": _num(glob, "REFINE")},
        "adjust": adjust,
        "RUNS_PER_DANTIAN": _num(_block(pacing, "Pacing.Refine ="), "RUNS_PER_DANTIAN"),
        "ENEMY_QI_EXPONENT": _num(income, "ENEMY_QI_EXPONENT"),
        "DAILY_QI_SHARE": _num(income, "DAILY_QI_SHARE"),
        "OFFLINE_MAX_HOURS": _num(income, "OFFLINE_MAX_HOURS"),
        "OFFLINE_RATE": _num(income, "OFFLINE_RATE"),
        "EAT_SHARE": _list(herbs_p, "EAT_SHARE"),
        "EAT_FLOOR": _list(herbs_p, "EAT_FLOOR"),
        "BAND_SHARE": 0.0,  # Herbs.eatQi: below the eater's band tier a herb gives only its floor
        "BUFF_FALLOFF": _list(herbs_p, "BUFF_FALLOFF"),
        "BUFF_CAP": _map(herbs_p, "BUFF_CAP"),
        "STOCK": _list(herbs_p, "STOCK"),
        "AURA_BY_TIER": _list(aura, "BY_TIER"),
        "AURA_RARITY": _map(aura, "RARITY"),
        "AURA_CAP_BY_MAJOR": _map(aura, "CAP"),
        "AURA_GROWING": _num(aura, "GROWING"),
        "AURA_DECOR": _num(aura, "DECOR"),
        "AURA_ON_PEAK": True,  # Cultivation.rate: the aura multiplies meditation on your own peak
        "OFFLINE_PER_DAY": True,  # Cultivation.awayLeft: one budget a UTC day
        "PRIZE": set(_map(herbs_p, "PRIZE")),
        "ANYWHERE": _num(med, "ANYWHERE"),
        "ON_PEAK": _num(med, "ON_PEAK"),
        "SCORE_MEDITATION": _num(score, "MEDITATION"),
        "SCORE_GROWTH": _num(score, "GROWTH"),
        "OVERFLOW_CAP": _num(brk, "OVERFLOW_CAP"),
        "CARRY_SHARE": _num(brk, "CARRY_SHARE"),
        "SECLUSION_GROWTH": _num(secl, "GROWTH"),
        "FIND_CHANCE": _num(secl, "FIND_CHANCE"),
        "FINDS": _map(secl, "FINDS"),
        "FIND_RARITY": _map(secl, "FIND_RARITY"),
        "regions": regions,
        "ROOT_SPEED": grades,
        "STARTER_QI": _num(methods, "STARTER_QI"),
        "METHOD_MATCH": _num(methods, "MATCH"),
        "PARTY_BONUS_PER_MEMBER": _num(party, "BONUS_PER_MEMBER"),
        "PARTY_BONUS_CAP": _num(party, "BONUS_CAP"),
        "DAILY_STONES": _map(sect, "DAILY_STONES"),
        "SEEDS_BACK": _list(garden, "SEEDS_BACK"),
        "herbs": herbs,
        "mean_size": mean_size,
        "peak_tiers": tiers,
        "weather": weather_mean,
        # transcribed from Items.luau / Enemies.luau (per-item and per-beast tables
        # are too scattered to parse safely): see the doc's "Inputs"
        "LESSER_CORE_WOLVES": float(re.search(r"LesserSpiritCore = \{.*?qiKills = ([\d.]+)", items_src, re.S).group(1)),  # kills' qi at the eater's stage
        "GREATER_CORE_BAR": float(re.search(r"GreaterSpiritCore = \{.*?cultivationShare = ([\d.]+)", items_src, re.S).group(1)),  # of the bar
        "WOLF_QI": _num(income, "CORE_KILL_QIDROP"),  # Enemies SpiritWolf qiDrop
        "WOLVES_PER_MIN": 2,  # the header's fighter
        "MEDITATION_CUSHION": float(re.search(r'id = "MeditationCushion".*?meditation = ([\d.]+)', build_src, re.S).group(1)),
        "CUSHION_COST": float(re.search(r'id = "MeditationCushion".*?cost = (\d+)', build_src, re.S).group(1)),
        "BASE_REFINE": 1.1,  # the header's cultivation per raw qi
    }


# --------------------------------------------------------------------------
# Player profiles (assumptions; see docs/systems/pacing-model.md)
# --------------------------------------------------------------------------

# Garden plots per peak tier: (Herb Beds, Lotus Ponds, Spirit Groves). The
# limits are 16/20/24 beds (Config.Build.TIERS), 4 ponds, 3 groves (BuildItems).
# Plants per plot come from PLOT_AREA / spacing^2 (the PlotAnchor sizes live in
# the place file; these areas are an assumption).
PLOT_AREA = {"bed": 24.0, "pond": 28.0, "grove": 48.0}

STAGES = ["QC1", "QC2", "QC3", "QC4", "QC5", "QC6", "QC7", "QC8", "QC9",
          "QR1", "QR2", "QR3", "QR4", "QR5", "QR6", "QR7", "QR8", "QR9",
          "FE1", "FE2", "FE3", "FE4", "FE5", "FE6", "FE7", "FE8", "FE9"]


def idx(key: str) -> int:
    return STAGES.index(key)


# Herbs.Regions: the band (and its herb tier) each stage belongs to
BANDS = [("QC1", "InnerWilds", 1), ("QC5", "MiddleWilds", 1), ("QR1", "OuterWilds", 2), ("QR6", "DeepWilds", 3), ("FE4", "FarReaches", 4)]


def band_of(key: str):
    best = BANDS[0]
    for b in BANDS:
        if idx(b[0]) <= idx(key):
            best = b
    return best


def band_tier(key: str) -> int:
    return band_of(key)[2]


def by_stage(table: dict, stage: str, default=None):
    """The value of the last key in `table` (stage -> value) at or before `stage`."""
    best = default
    for k, v in sorted(table.items(), key=lambda kv: idx(kv[0])):
        if idx(k) <= idx(stage):
            best = v
    return best


PROFILES = {
    "casual": {
        "label": "Casual (30 min/day, light garden)",
        "sessions": [(19.0, 30)],  # (start hour, minutes) each day
        "fight_share": 0.55,  # of session minutes spent hunting; the rest seated on the peak
        "refine_eff": 1.0,  # cultivation per raw qi (score ~0.6, few full clears)
        "plots": {"QC4": (3, 1, 0), "QR1": (5, 1, 0), "FE1": (8, 1, 1)},
        "herb_tier": {"QC4": 1, "QC5": 2, "QR1": 5},  # the most a profile bothers to plant; what they can is acquired (run)
        "chase_plots": 0,  # beds kept on the next tier's mutation source
        "aura_keep": 0,  # plants of the best aura herb left standing (proposal's aura matters)
        "boss_per_hour": 0.2,  # boss kills a fight hour (bosses respawn in 3-5 min, shared)
        "treasure_share": 0.15,  # heavenly treasures claimed of those that fall while hunting
        "score": {"QC4": 12, "QR1": 40, "FE1": 70},
        "med_item": {},  # best meditation piece in range (BuildItems `meditation`)
        "buffs": 0, "buff_uptime": 0.0,  # QiRate buffs kept up while online (distinct herbs)
        "party_share": 0.0,
        "seclusion": False,
        "daily_qi": True,
        "dailies": 1,  # sect dailies done a day (from QC5)
    },
    "regular": {
        "label": "Regular (1.5 h/day, garden + some building)",
        "sessions": [(19.0, 90)],
        "fight_share": 0.55,
        "refine_eff": 1.1,
        "plots": {"QC4": (8, 2, 1), "QR1": (12, 2, 2), "FE1": (16, 3, 2)},
        "herb_tier": {"QC4": 1, "QC6": 2, "QR1": 5},
        "chase_plots": 1,
        "aura_keep": 2,
        "boss_per_hour": 0.5,
        "treasure_share": 0.3,
        "score": {"QC4": 30, "QR1": 90, "FE1": 160},
        "med_item": {"QC6": 1.5},  # a Meditation Cushion
        "buffs": 2, "buff_uptime": 0.6,
        "party_share": 0.25,
        "seclusion": False,
        "daily_qi": True,
        "dailies": 2,
    },
    "heavy": {
        "label": "Heavy (3 h/day, full garden, peak score capped, nightly seclusion)",
        "sessions": [(8.0, 60), (18.0, 120)],
        "fight_share": 0.5,
        "refine_eff": 1.25,
        "plots": {"QC4": (16, 4, 3), "QR1": (20, 4, 3), "FE1": (24, 4, 3)},
        "herb_tier": {"QC4": 1, "QC5": 2, "QR1": 5},
        "chase_plots": 3,
        "aura_keep": 4,
        "boss_per_hour": 1.2,
        "treasure_share": 0.6,
        "score": {"QC4": 1e9},  # capped by the peak tier's scoreCap
        "med_item": {"QC5": 1.5},
        "buffs": 4, "buff_uptime": 1.0,
        "party_share": 0.4,
        "seclusion": True,
        "daily_qi": True,
        "dailies": 3,
    },
}

# Shared behaviour assumptions
ASSUME = {
    "garden_from": "QC4",  # the Home lesson
    "run_minutes": 1.0,  # one full circulation run (3 levels x 15 s + walking/UI), spends dantian / RUNS_PER_DANTIAN
    "lesser_per_wolf": 0.2,  # lesser cores per wolf-equivalent of kill qi (wolf 20%; boars, serpents and QC6-8 beasts ~0.0143 per qiDrop)
    "greater_per_wolf": 0.01,  # greater cores per wolf-equivalent from QC6 (QC6/QC8 beasts 4-10%, bosses 100%)
    "greater_from": "QC6",
    "party_factor": 1.4,  # kill qi per minute in a party of 3 vs solo (shared credit at KILL_SHARE 10%, spawn-limited), before the group bonus
    "party_size": 3,
    "stones_per_fight_min": 10,  # ~0.3 stones per qiDrop (wolf 3-6 for 14, boar 5-9 for 24, QC6 10-18 for 48) at 28 qiDrop a minute, plus nodes (4-8)
    "daily_stone_share": 0.85,  # mean `stones` share of the dailies offered (Pacing.Sect.DAILIES)
}


# --------------------------------------------------------------------------
# The model
# --------------------------------------------------------------------------

class Model:
    def __init__(self, game: dict, profile: dict, levers_off: set[str] | None = None):
        self.g = game
        self.p = profile
        self.off = levers_off or set()
        self.gs = None  # the economy's purchases, set by run()
        self.band_tier = 1

    # stage numbers after Adjust and Global
    def stage(self, i: int) -> dict:
        row = self.g["curve"][i]
        adj = self.g["adjust"].get(row["key"], {})
        G = self.g["global"]
        return {
            "key": row["key"],
            "major": row["major"],
            "bar": row["bar"] * adj.get("bar", 1) * G["BAR"],
            "d": row["dantian"],
            "p": row["passive"] * adj.get("passive", 1) * G["PASSIVE"],
            "gather": row["gather"] * adj.get("gather", 1) * G["GATHER"],
            "refine": adj.get("refine", 1) * G["REFINE"],
        }

    def wolf(self, st) -> float:
        return self.g["WOLF_QI"] * (st["d"] / self.g["curve"][0]["dantian"]) ** self.g["ENEMY_QI_EXPONENT"]

    def peak_tier(self, key):
        best = self.g["peak_tiers"][0]
        for t in self.g["peak_tiers"]:
            if idx(t["from"]) <= idx(key):
                best = t
        return best

    def on(self, lever):
        return lever not in self.off

    # ---- what the player owns: the profile's targets for the stage, capped by the
    # peak tier, or (with the economy on, in run) what their stones have bought
    def targets(self, key) -> dict:
        tier = self.peak_tier(key)
        if idx(key) < idx(ASSUME["garden_from"]):
            return {"beds": 0, "ponds": 0, "groves": 0, "score": 0, "item": 0, "tier": 0}
        plots = by_stage(self.p["plots"], key, (0, 0, 0))
        return {
            "beds": min(plots[0], tier["beds"]),
            "ponds": plots[1],
            "groves": plots[2],
            "score": min(by_stage(self.p["score"], key, 0), tier["scoreCap"]) if self.on("peakscore") else 0,
            "item": self.g["MEDITATION_CUSHION"] if (by_stage(self.p["med_item"], key, 0) and self.on("meditem")) else 0,
            "tier": by_stage(self.p["herb_tier"], key, 0),
        }

    def owned(self, key) -> dict:
        t = self.targets(key)
        if self.gs is None:
            return t
        tier = self.peak_tier(key)
        score = min(tier["scoreCap"], self.gs["points"] + self.plot_points()) if self.on("peakscore") else 0
        return {
            "beds": min(self.gs["beds"], t["beds"]),
            "ponds": min(self.gs["ponds"], t["ponds"]),
            "groves": min(self.gs["groves"], t["groves"]),
            "score": min(score, t["score"]),
            "item": min(self.gs["item"], t["item"]),
            "tier": min(self.gs["tier"], t["tier"], self.gs["unlocked"]),
        }

    def plot_points(self) -> float:
        per_item = 5
        pts = {p["id"]: p["points"] for p in self.g["pieces"]}
        return (min(per_item, self.gs["beds"]) * pts.get("HerbBed", 3) + min(per_item, self.gs["ponds"]) * pts.get("LotusPond", 3)
                + min(per_item, self.gs["groves"]) * pts.get("SpiritGrove", 3))

    def per_plot(self, hid) -> int:
        h = self.g["herbs"][hid]
        return max(1, int(PLOT_AREA[h["soil"]] // h["spacing"] ** 2))

    def seed_price(self, soil, tier) -> float:
        """Stones to seed one plot of `soil` with the dearest shop herb up to `tier`
        (herbs not sold in the shop come from drops and harvests: free here)."""
        best = 0.0
        for hid, h in self.g["herbs"].items():
            # tier III+ seeds are limited stock (Herbs `stock`): bought once to start the
            # tier (shop, below), then the harvests' seeds back fill the plots
            if h["soil"] == soil and h["tier"] <= min(tier, 2) and h["seedCost"]:
                best = max(best, h["seedCost"] * self.per_plot(hid))
        return best

    def herb_qi(self, hid, d) -> float:
        h = self.g["herbs"][hid]
        if not h["qi"]:
            return 0.0
        share = self.g["EAT_SHARE"][h["tier"] - 1]
        floor = self.g["EAT_FLOOR"][h["tier"] - 1]
        if self.g.get("BAND_SHARE") is not None and h["tier"] < self.band_tier:
            # proposal: a herb below the stage's band tier gives its floor, or a
            # reduced share
            share *= self.g["BAND_SHARE"]
        return max(share * d, floor)

    def find_pool(self, key, beyond=False) -> dict:
        """Seclusion's herb and seed finds (server Seclusion.findHerb): the band's herbs
        (its Herbs.Regions pools and the herbs whose `region` it is, of the band's own
        tier; no wild, event or deferred herbs) weighted by FIND_RARITY; `beyond` takes the next band's (none
        past the Far Reaches: the band's own). Returns herb id -> probability."""
        b = band_of(key)
        if beyond:
            j = [x[1] for x in BANDS].index(b[1])
            b = BANDS[min(j + 1, len(BANDS) - 1)]
        reg = self.g["regions"].get(b[1], {})
        ids = set(reg.get("seeds", {})) | set(reg.get("bossSeeds", {}))
        ids |= {h for h, d in self.g["herbs"].items() if d["region"] == b[1]}
        w = {h: self.g["FIND_RARITY"].get(self.g["herbs"][h]["rarity"], 0) for h in ids
             if h in self.g["herbs"] and self.g["herbs"][h]["tier"] == b[2]
             and not self.g["herbs"][h]["wild"] and h not in self.g["PRIZE"]}
        tot = sum(w.values())
        return {h: v / tot for h, v in w.items() if v > 0} if tot else {}

    def seed_value(self, hid, key) -> float:
        """Stones a found seed saves: its Herbalist price when the Herbalist sells it to
        the player at this stage (a purchase it replaces); a seed the shop doesn't sell
        them (mutation-only, or a later band's) counts nothing here (conservative)."""
        h = self.g["herbs"][hid]
        if h["seedCost"] and (not h["soldFrom"] or idx(h["soldFrom"]) <= idx(key)):
            return h["seedCost"]
        return 0.0

    # ---- the garden plan for a stage: what's planted, harvests, aura, buffs
    def garden_plan(self, st) -> dict:
        key = st["key"]
        self.band_tier = band_tier(key)
        empty = {"plants": [], "aura": 0.0, "buff": 0.0, "buff_herbs_day": {}, "herbs_day": {}, "growth": 0.0, "mut_per_day": 0.0}
        if idx(key) < idx(ASSUME["garden_from"]) or not self.on("garden"):
            return empty
        have = self.owned(key)
        tier_ok = have["tier"]
        counts = {"bed": have["beds"], "pond": have["ponds"], "grove": have["groves"]}
        score = have["score"]
        growth_online = 1 + score * self.g["SCORE_GROWTH"]
        sessions = self.p["sessions"]
        # absences before each session (hours), and their growth multipliers
        absences = []
        for k, (start, mins) in enumerate(sessions):
            pstart, pmins = sessions[k - 1]
            end_prev = pstart + pmins / 60
            gap = (start - end_prev) % 24 or 24
            night = k == 0
            mult = 1 + (self.g["SECLUSION_GROWTH"] if (night and self.p["seclusion"] and self.on("seclusion")) else 0)
            absences.append((gap * 3600 * mult, mins * 60 * growth_online))

        def harvests(cycle):
            """Harvests a day of one plant with this cycle (s), and whether it ripens
            only between sessions (then it is harvested at the session's end and its
            aura counts for the whole session)."""
            n, aura_sessions = 0, 0
            for absent, online in absences:
                inside = math.floor(online / cycle)
                n += (1 if absent >= cycle else 0) + inside
                if inside == 0 and absent >= cycle:
                    aura_sessions += 1
            return n, aura_sessions / len(absences)

        avail = [hid for hid, h in self.g["herbs"].items()
                 if h["tier"] <= tier_ok and hid not in self.g["PRIZE"] and not h["wild"]]
        size = self.g["mean_size"]

        def per_plot(hid):
            return max(1, int(PLOT_AREA[self.g["herbs"][hid]["soil"]] // self.g["herbs"][hid]["spacing"] ** 2))

        def cycle(hid):
            h = self.g["herbs"][hid]
            return h["regrow"] or h["grow"]

        # plot budget in "plot units" per soil
        left = dict(counts)
        plan = []
        online_min = sum(m for _, m in sessions)

        def take(soil, plants_wanted, hid, kind):
            plots = min(left[soil], math.ceil(plants_wanted / self.per_plot(hid)))
            if plots > 0:
                left[soil] -= plots
                plan.append((hid, min(plants_wanted, plots * self.per_plot(hid)), kind))

        # 0) the standing aura plants and the mutation chase (both before buffs and qi)
        if self.p.get("aura_keep") and self.on("aura"):
            best = max(avail, key=lambda h: self.aura_of(h), default=None)
            if best:
                take(self.g["herbs"][best]["soil"], self.p["aura_keep"], best, "aura")
        if self.p.get("chase_plots"):
            srcs = [h for h in avail if self.g["herbs"][h]["mutatesTo"]
                    and self.g["herbs"][self.g["herbs"][h]["mutatesTo"]]["tier"] == tier_ok + 1]
            if srcs:
                best = max(srcs, key=lambda h: self.g["herbs"][h]["mutateChance"] * harvests(cycle(h))[0])
                soil = self.g["herbs"][best]["soil"]
                take(soil, self.p["chase_plots"] * self.per_plot(best), best, "chase")

        # 1) buffs: the strongest distinct QiRate buffs, enough herbs for the uptime
        buff_total = 0.0
        buff_day = {}
        if self.on("buffs") and self.p["buffs"]:
            cands = sorted((hid for hid in avail if self.g["herbs"][hid]["buff"]),
                           key=lambda h: -self.g["herbs"][h]["buff"][0])
            for hid in cands[: self.p["buffs"]]:
                h = self.g["herbs"][hid]
                amount, secs = h["buff"]
                need = online_min * 60 * self.p["buff_uptime"] / secs  # herbs a day
                n, _ = harvests(cycle(hid))
                per_plant = n * h["yield"] * size
                if per_plant <= 0:
                    continue
                plots_needed = math.ceil(need / per_plant / per_plot(hid))
                use = min(plots_needed, left[h["soil"]])
                if use <= 0:
                    continue
                left[h["soil"]] -= use
                got = use * per_plot(hid) * per_plant
                up = min(1.0, got / need) * self.p["buff_uptime"]
                # Pacing.Herbs.BUFF_FALLOFF: the strongest buff counts whole, the
                # next ones less (Cultivation buffTotal)
                fall = self.g.get("BUFF_FALLOFF")
                k = len(buff_day)
                weight = (fall[k] if k < len(fall) else 0.0) if fall else 1.0
                buff_total += amount * up * weight
                buff_day[hid] = min(got, need)
                plan.append((hid, use * per_plot(hid), "buff"))

        # 2) the rest: per soil, the herb with the most raw qi a plant-day; if none
        #    gives qi, the best aura plant
        herbs_day = dict(buff_day)
        aura = 0.0
        for soil in ("bed", "pond", "grove"):
            if left[soil] <= 0:
                continue
            opts = [h for h in avail if self.g["herbs"][h]["soil"] == soil]
            if not opts:
                continue

            def qi_value(hid):
                h = self.g["herbs"][hid]
                n, _ = harvests(cycle(hid))
                return self.herb_qi(hid, st["d"]) * n * h["yield"] * size * per_plot(hid)

            best = max(opts, key=qi_value)
            kind = "qi"
            if qi_value(best) <= 0 or not self.on("herbqi"):
                # nothing here gives qi: grow the best aura plant and leave it standing
                best = max(opts, key=lambda h: self.aura_of(h) * per_plot(h))
                kind = "aura"
            h = self.g["herbs"][best]
            n, _ = harvests(cycle(best))
            plants = left[soil] * per_plot(best)
            if kind == "qi":
                herbs_day[best] = herbs_day.get(best, 0) + plants * n * h["yield"] * size
            plan.append((best, plants, kind))
            left[soil] = 0

        # aura: plants that ripen between sessions stand mature through the session
        mut = 0.0  # chance a day of a seed one tier up (mutatesTo on harvest)
        for hid, plants, kind in plan:
            n, share = harvests(cycle(hid))
            share = 1.0 if kind == "aura" else share
            # growing plants radiate AURA_GROWING of a mature one's aura
            share = share + (1 - share) * self.g.get("AURA_GROWING", 0.0)
            aura += self.aura_of(hid) * size * plants * share
            h = self.g["herbs"][hid]
            if kind != "aura" and h["mutatesTo"] and self.g["herbs"][h["mutatesTo"]]["tier"] == tier_ok + 1:
                mut += plants * n * h["mutateChance"]
        cap = self.g["AURA_CAP_BY_MAJOR"][st["major"]]
        if self.g.get("AURA_DECOR"):
            # decorating the abode lifts the cap: up to AURA_DECOR more at the tier's score cap
            tier_cap = self.peak_tier(key)["scoreCap"]
            cap *= 1 + self.g["AURA_DECOR"] * min(1.0, score / tier_cap if tier_cap else 0)
        aura = min(aura, cap) if self.on("aura") else 0.0
        return {"plants": plan, "aura": aura, "buff": buff_total, "buff_herbs_day": buff_day,
                "herbs_day": herbs_day, "growth": growth_online - 1, "score": score, "mut_per_day": mut}

    def aura_of(self, hid) -> float:
        h = self.g["herbs"][hid]
        return self.g["AURA_BY_TIER"][h["tier"] - 1] * self.g["AURA_RARITY"].get(h["rarity"], 1)

    def multipliers(self, st) -> dict:
        key = st["key"]
        have = self.owned(key)
        score = have["score"]
        item = have["item"]
        grade = (self.gs or {}).get("root", "Spirit") if self.on("root") else "Spirit"
        root = self.g["ROOT_SPEED"][grade]
        method = (self.g["STARTER_QI"] + self.g["METHOD_MATCH"]) if (st["major"] == "Foundation" and self.on("method")) else 1.0
        weather = self.g["weather"] if self.on("weather") else {"passive": 0, "circulation": 0}
        med = self.g["ON_PEAK"] + score * self.g["SCORE_MEDITATION"] + item
        bonus = min(self.g["PARTY_BONUS_CAP"], (ASSUME["party_size"] - 1) * self.g["PARTY_BONUS_PER_MEMBER"])
        party = 1 + self.p["party_share"] * (ASSUME["party_factor"] * (1 + bonus) - 1) if self.on("party") else 1.0
        return {"med": med, "root": root, "method": method, "weather": weather, "party": party, "score": score}

    # ---- per-stage rates (per minute online)
    def rates(self, i: int) -> dict:
        st = self.stage(i)
        self.band_tier = band_tier(st["key"])
        m = self.multipliers(st)
        gp = self.garden_plan(st)
        w = self.wolf(st)
        bc = self.g.get("BUFF_CAP", 1e9)
        buff = min(gp["buff"], bc[st["major"]] if isinstance(bc, dict) else bc)
        common = (1 + buff) * (1 + gp["aura"]) * (1 + m["weather"]["passive"]) * m["root"] * m["method"]
        seat = m["med"]
        if self.g.get("AURA_ON_PEAK"):
            # proposal: the garden's aura fills the air of your own peak: it adds to
            # meditation there (seated), not to fighting in the wilds
            common = (1 + buff) * (1 + m["weather"]["passive"]) * m["root"] * m["method"]
            seat = m["med"] * (1 + gp["aura"])
        if self.g.get("ADDITIVE_PASSIVE"):
            # proposal: herb buffs, aura and weather add to the seat's multiplier
            # instead of multiplying it (root and method still multiply)
            bonus = buff + gp["aura"] + m["weather"]["passive"]
            common = (1 + bonus) * m["root"] * m["method"]
            seat = (m["med"] + bonus) / (1 + bonus)
        eff = self.p["refine_eff"] * st["refine"] * m["root"] * m["method"] * (1 + m["weather"]["circulation"])
        # fighting: passive (not seated) + kill qi (refining time netted, as in the header)
        kill_raw = self.g["WOLVES_PER_MIN"] * w * st["gather"] * m["method"] * m["party"]
        fight = 60 * st["p"] * common + kill_raw * eff
        # cores: extra raw qi, refined in seated time
        core_qi = self.g["LESSER_CORE_WOLVES"] * w * st["gather"]  # Realms.enemyQi includes the stage's gather
        cores_raw = self.g["WOLVES_PER_MIN"] * ASSUME["lesser_per_wolf"] * core_qi * m["party"] if self.on("cores") else 0
        greater = (self.g["WOLVES_PER_MIN"] * ASSUME["greater_per_wolf"] * m["party"]) if (self.on("cores") and idx(st["key"]) >= idx(ASSUME["greater_from"])) else 0
        seated = 60 * st["p"] * common * seat
        refine_cap = st["d"] / self.g["RUNS_PER_DANTIAN"] / ASSUME["run_minutes"]  # raw qi a seated minute
        herb_raw_day = sum(n * self.herb_qi(h, st["d"]) for h, n in gp["herbs_day"].items()) if self.on("herbqi") else 0
        sold_value = sum(n * self.g["herbs"][h]["sellPrice"] for h, n in gp["herbs_day"].items() if self.herb_qi(h, st["d"]) > 0)
        sell_per_raw = sold_value / herb_raw_day if herb_raw_day else 0
        # the profile sells this share of its qi herbs to the Herbalist (a gardener's stones)
        sell = self.p.get("sell_share", 0.0) if self.on("herbqi") else 0.0
        herb_sell_day = sold_value * sell
        herb_raw_day *= 1 - sell
        return {"st": st, "sell_per_raw": sell_per_raw, "herb_sell_day": herb_sell_day, "common": common, "fight": fight, "seated": seated, "eff": eff, "cores_raw": cores_raw,
                "greater": greater, "refine_cap": refine_cap, "herb_raw_day": herb_raw_day,
                "garden": gp, "mult": m, "w": w, "afk": st["p"] * self.g["OFFLINE_RATE"]}

    # ---- the calendar simulation
    def run(self, max_days=400) -> dict:
        i, c = 0, 0.0
        active = 0.0
        reached = {"QC1": (0.0, 1)}
        cache = {}
        # raw qi waiting to be refined, by where it came from
        pending = {"herbs": 0.0, "cores": 0.0, "daily": 0.0, "dew": 0.0}
        # cultivation gained by source and major (before the overflow cap clips it)
        sources: dict[str, dict[str, float]] = {}
        first = True
        sessions = self.p["sessions"]
        top = len(self.g["curve"]) - 1
        day = 1
        budget = self.g["OFFLINE_MAX_HOURS"]

        econ = self.on("economy")
        self.gs = {"beds": 0, "ponds": 0, "groves": 0, "points": 0.0, "item": 0, "tier": 0, "unlocked": 2, "root": "Spirit"} if econ else None
        if not econ:
            self.gs = None
        acq = {"pills": 0.0, "mut": 0.0, "seeds": 0.0, "unlocked_at": {}, "root_at": {}}
        wash = [("Earth", 3), ("Heaven", 8), ("Immortal", 16)]
        stones = self.g["STARTING_STONES"] + sum(v for k, v in self.g["quest_stones"].items() if k != "Method")
        stone_log = {}
        # the greedy points ladder: cheapest stones per peak-score point first
        ladder = []
        for pc in sorted(self.g["pieces"], key=lambda pc: pc["cost"] / pc["points"] if pc["points"] else 1e9):
            if pc["points"] and pc["category"] not in ("Garden",) and pc["id"] not in ("MeditationCushion",):
                ladder += [(pc["cost"], pc["points"], pc["realm"])] * int(pc["copies"])
        majors = ["QiCondensation", "QiRefining", "Foundation"]
        stage_min = {}  # online minutes spent at each stage index

        def key_now():
            return self.g["curve"][i]["key"]

        def gkey():
            return (i, tuple(sorted(self.gs.items())) if self.gs else None)

        def R(k=None):
            ck = gkey() if k is None or k == i else (k, None)
            if ck not in cache:
                cache[ck] = self.rates(i if k is None else k)
            return cache[ck]

        found = {"seeds": 0.0}  # seclusion's found seeds, in the stones they'd cost (seed buys only)

        def pay_seeds(cost):
            """Pay a seed purchase from found seeds first, then stones; False if short."""
            nonlocal stones
            if stones + found["seeds"] < cost:
                return False
            use = min(found["seeds"], cost)
            found["seeds"] -= use
            stones -= cost - use
            stone_log.setdefault(self.g["curve"][i]["major"], {}).setdefault("found seeds used", 0.0)
            stone_log[self.g["curve"][i]["major"]]["found seeds used"] += use
            return True

        def earn(src, amount):
            nonlocal stones
            stones += amount
            book = stone_log.setdefault(self.g["curve"][i]["major"], {})
            book[src] = book.get(src, 0.0) + amount

        def shop():
            """Spend stones toward the profile's targets for this stage, in order:
            the herb tier (re-seeding every plot), beds, the cushion, ponds, groves,
            then peak-score pieces."""
            nonlocal stones
            if not econ:
                return
            key = key_now()
            t = self.targets(key)
            gs = self.gs
            # the Herbalist's band-gated seeds (Herbs `seedCost` + `soldFrom`): a day's
            # stock of the next tier starts it once the player's band sells it
            nxt = gs["unlocked"] + 1
            start = self.g.get("SHOP_FROM", {}).get(nxt)
            if start and idx(key) >= idx(start) and nxt <= t["tier"]:
                cost = self.g["SHOP_START_COST"][nxt]
                if pay_seeds(cost):
                    gs["unlocked"] = nxt
                    acq["unlocked_at"][nxt] = (key, day)
            changed = True
            while changed:
                changed = False
                if gs["tier"] < t["tier"]:
                    cost = sum(gs[n] * self.seed_price(soil, t["tier"]) for n, soil in (("beds", "bed"), ("ponds", "pond"), ("groves", "grove")))
                    if pay_seeds(cost):
                        gs["tier"] = t["tier"]
                        changed = True
                        continue
                    break
                for n, soil, cost in (("beds", "bed", 80), ("item", None, self.g["CUSHION_COST"]), ("ponds", "pond", 240), ("groves", "grove", 400)):
                    if n == "item":
                        if gs["item"] < t["item"] and stones >= cost:
                            stones -= cost
                            gs["item"] = t["item"]
                            changed = True
                            break
                        continue
                    if gs[n] < t[n]:
                        full = cost + self.seed_price(soil, gs["tier"] or 1)
                        if stones >= cost and pay_seeds(full):
                            gs[n] += 1
                            changed = True
                            break
                        if n == "beds":
                            return  # save up for the garden first
                if changed:
                    continue
                score = self.plot_points() + gs["points"]
                if score < t["score"]:
                    j = int(gs.get("_ladder", 0))
                    while j < len(ladder) and (ladder[j][2] and majors.index(ladder[j][2]) > majors.index(self.g["curve"][i]["major"])):
                        j += 1
                    if j < len(ladder) and stones >= ladder[j][0]:
                        stones -= ladder[j][0]
                        gs["points"] += ladder[j][1]
                        ladder.pop(j)
                        changed = True

        def credit(src, amount):
            book = sources.setdefault(R(i)["st"]["major"], {})
            book[src] = book.get(src, 0.0) + amount

        def add(amount):
            nonlocal c
            c = min(self.g["OVERFLOW_CAP"] * R(i)["st"]["bar"], c + amount)

        def breakthrough():
            nonlocal i, c
            while i < top and c >= R(i)["st"]["bar"]:
                excess = c - R(i)["st"]["bar"]
                i += 1
                c = min(excess, self.g["CARRY_SHARE"] * R(i)["st"]["bar"])
                reached[R(i)["st"]["key"]] = (active / 60, day)

        def done():
            return i == top and c >= R(top)["st"]["bar"]

        for day in range(1, max_days + 1):
            for k, (start, mins) in enumerate(sessions):
                r = R(i)
                if not first:
                    pstart, pmins = sessions[k - 1]
                    gap = ((start - (pstart + pmins / 60)) % 24) or 24
                    hours = min(gap, self.g["OFFLINE_MAX_HOURS"])
                    if self.g.get("OFFLINE_PER_DAY"):
                        # proposal: one 12 h budget per day, shared by every absence
                        if k == 0:
                            budget = self.g["OFFLINE_MAX_HOURS"]
                        hours = min(hours, budget)
                        budget -= hours
                    if self.on("offline"):
                        room = self.g["OVERFLOW_CAP"] * r["st"]["bar"] - c
                        got = max(0.0, min(r["afk"] * hours * 3600, room))
                        credit("offline", got)
                        add(got)
                    if k == 0 and self.p["seclusion"] and self.on("seclusion"):
                        # no stone trickle or streak since the 2026-10-24 seclusion rework
                        # fortuitous encounters (2026-10-24): FIND_CHANCE finds an hour,
                        # by FINDS weight: a band herb (eaten for its qi), a band seed (the
                        # stones it saves, or the next tier unlocked), rarely a seed from
                        # the next band, treasures and the tempering pill
                        finds = self.g["FINDS"]
                        tot = sum(finds.values())
                        rolls = hours * self.g["FIND_CHANCE"]
                        key = r["st"]["key"]
                        self.band_tier = band_tier(key)
                        herb_raw = sum(pr * self.herb_qi(h, r["st"]["d"]) for h, pr in self.find_pool(key).items())
                        if self.on("herbqi"):
                            pending["herbs"] += rolls * finds.get("Herb", 0) / tot * herb_raw
                        for kind, beyond in (("Seed", False), ("FarSeed", True)):
                            n = rolls * finds.get(kind, 0) / tot
                            for h, pr in self.find_pool(key, beyond).items():
                                t = self.g["herbs"][h]["tier"]
                                if self.gs is not None and t == self.gs["unlocked"] + 1:
                                    acq["mut"] += n * pr
                                elif self.gs is not None and t <= self.gs["unlocked"]:
                                    # in kind: they pay only for seeds the player would buy
                                    found["seeds"] += n * pr * self.seed_value(h, key)
                        pending["dew"] += rolls * finds.get("HeavenlyDew", 0) / tot * r["st"]["d"]
                        peach = rolls * finds.get("ImmortalPeach", 0) / tot * 0.5 * r["st"]["bar"]
                        credit("seclusion finds", peach)
                        add(peach)
                first = False
                if k == 0 and self.p["daily_qi"] and self.on("dailyqi"):
                    pending["daily"] += min(r["st"]["d"], self.g["DAILY_QI_SHARE"] * r["st"]["d"] * r["st"]["gather"])
                if k == 0 and self.gs is not None:
                    # the Pavilion's root pill fragments: 3 Marrow a week with two dailies a day
                    acq["pills"] += (0.3 if self.p["dailies"] >= 2 else 0.15) / 7
                if k == 0 and idx(key_now()) >= idx("QC5"):
                    earn("sect dailies", self.p["dailies"] * self.g["DAILY_STONES"][r["st"]["major"]] * ASSUME["daily_stone_share"])
                breakthrough()
                for minute in range(int(mins)):
                    if minute % 10 == 0:
                        shop()
                    r = R(i)
                    f = self.p["fight_share"]
                    st = r["st"]
                    pas_f = f * 60 * st["p"] * r["common"]
                    kills = f * (r["fight"] - 60 * st["p"] * r["common"])
                    seated = (1 - f) * r["seated"]
                    greater = f * r["greater"] * self.g["GREATER_CORE_BAR"] * st["bar"]
                    pending["cores"] += f * r["cores_raw"]
                    # the day's herbs come in over the online minutes (harvest, eat)
                    pending["herbs"] += r["herb_raw_day"] / sum(m for _, m in sessions)
                    room = (1 - f) * r["refine_cap"]
                    total_pending = sum(pending.values())
                    refine = min(total_pending, room)
                    for src in pending:
                        share = pending[src] / total_pending if total_pending else 0
                        credit("refined " + src, refine * share * r["eff"])
                        pending[src] -= refine * share
                    credit("passive (fighting)", pas_f)
                    credit("kills", kills)
                    credit("passive (seated)", seated)
                    credit("greater cores", greater)
                    add(pas_f + kills + seated + greater + refine * r["eff"])
                    earn("hunting", f * ASSUME["stones_per_fight_min"])
                    earn("herb sales", r["herb_sell_day"] / sum(m for _, m in sessions))
                    if self.gs is not None:
                        online_day = sum(m for _, m in sessions)
                        if self.owned(key_now())["tier"] >= self.gs["unlocked"]:
                            acq["mut"] += r["garden"]["mut_per_day"] / online_day
                        # bosses: a pill at ~3% and a pity fragment (a tenth of one)
                        acq["pills"] += f * self.p["boss_per_hour"] / 60 * (0.03 + 0.1)
                        # heavenly treasures: dew fills the dantian, a peach is half a bar,
                        # and every claim that isn't a pill is a pity fragment
                        claims = f * sum(TREASURE_RATE.values()) / 60 * self.p["treasure_share"]
                        pending["dew"] += claims * 60 / 103 * st["d"]
                        peach = claims * 10 / 103 * 0.5 * st["bar"]
                        credit("treasures", peach)
                        add(peach)
                        acq["pills"] += claims * (1 / 103 + 0.1)
                        while acq["mut"] >= 1 and self.gs["unlocked"] < max(h["tier"] for h in self.g["herbs"].values()):
                            acq["mut"] -= 1
                            self.gs["unlocked"] += 1
                            acq["unlocked_at"][self.gs["unlocked"]] = (key_now(), day)
                        for grade, need in wash:
                            if acq["pills"] >= need and self.on("root") and grade not in acq["root_at"]:
                                self.gs["root"] = grade
                                acq["root_at"][grade] = (key_now(), day)
                    stage_min[i] = stage_min.get(i, 0) + 1
                    active += 1
                    was = i
                    breakthrough()
                    if was < idx("FE1") <= i:
                        earn("quests", self.g["quest_stones"].get("Method", 0))
                    if done():
                        reached["FE9 full"] = (active / 60, day)
                        return {"reached": reached, "days": day, "rates": cache, "sources": sources, "stones": stone_log, "stage_min": stage_min, "acq": acq}
                    # herbs wait in the pouch; cap the queue loosely at a day's worth
                    limit = st["d"] + r["herb_raw_day"]
                    total_pending = sum(pending.values())
                    if total_pending > limit:
                        sold = pending["herbs"] - pending["herbs"] * limit / total_pending
                        earn("herb sales", sold * r["sell_per_raw"])
                        for src in pending:
                            pending[src] *= limit / total_pending
        return {"reached": reached, "days": max_days, "rates": cache, "sources": sources, "stones": stone_log, "stage_min": stage_min, "acq": acq}


class Fighter(Model):
    """The header's fighter: continuous active play, fight only, nothing else."""

    def run(self, max_days=0):
        total, out = 0.0, {"QC1": (0.0, 1)}
        for i in range(len(self.g["curve"])):
            st = self.stage(i)
            per_min = 60 * st["p"] + self.g["WOLVES_PER_MIN"] * self.g["BASE_REFINE"] * self.wolf(st) * st["gather"]
            total += st["bar"] / per_min
            key = STAGES[i + 1] if i + 1 < len(STAGES) else "FE9 full"
            out[key] = (total / 60, None)
        return {"reached": out}


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

MILESTONES = [("QC4", "QC4"), ("QC9", "QC9"), ("QR1", "QC done"), ("QR9", "QR9"), ("FE1", "QR done"), ("FE9", "FE9"), ("FE9 full", "FE9 full")]
TARGETS = {"QR1": 2.4, "FE1": 2.4 + 7.1, "FE9 full": 2.4 + 7.1 + 19.8}


def fmt_h(h):
    if h is None:
        return "-"
    return f"{h * 60:.0f}m" if h < 1 else f"{h:.1f}h"


def summary(results: dict, names: list[str]):
    head = f"{'':28}" + "".join(f"{lab:>16}" for _, lab in MILESTONES)
    print(head)
    for name in names:
        res = results[name]["reached"]
        cells = []
        for key, _ in MILESTONES:
            v = res.get(key)
            if v is None:
                cells.append(f"{'not reached':>16}")
            elif v[1] is None:
                cells.append(f"{fmt_h(v[0]):>16}")
            else:
                cells.append(f"{fmt_h(v[0]) + ' / d' + str(v[1]):>16}")
        print(f"{name:28}" + "".join(cells))
    print(f"{'header targets (active)':28}" + "".join(f"{fmt_h(TARGETS[k]) if k in TARGETS else '':>16}" for k, _ in MILESTONES))


def stage_table(game, name, model, res):
    print(f"\n{PROFILES[name]['label'] if name in PROFILES else name}")
    print(f"{'stage':6}{'enter':>10}{'day':>5}{'fight/min':>11}{'seated/min':>12}{'med':>6}{'aura':>6}{'buff':>6}{'herb qi/day':>13}{'herb/bar':>10}{'night/bar':>10}")
    reached = res["reached"]
    for i, key in enumerate(STAGES):
        runs = [v for (k, _), v in res["rates"].items() if k == i]
        r = runs[-1] if runs else model.rates(i)
        bar = r["st"]["bar"]
        night = min(r["afk"] * game["OFFLINE_MAX_HOURS"] * 3600, game["OVERFLOW_CAP"] * bar) / bar
        e = reached.get(key)
        print(f"{key:6}{fmt_h(e[0]) if e else '-':>10}{e[1] if e else '-':>5}{r['fight']:>11.0f}{r['seated']:>12.0f}"
              f"{r['mult']['med']:>6.2f}{r['garden']['aura']:>6.2f}{r['garden']['buff']:>6.2f}"
              f"{r['herb_raw_day'] * r['eff']:>13.0f}{r['herb_raw_day'] * r['eff'] / bar:>10.2f}{night:>10.2f}")


SHORT = {"QiCondensation": "QC", "QiRefining": "QR", "Foundation": "FE"}


def source_table(results, names):
    print("\nWhere the cultivation came from, by realm (share of what was earned there)")
    for n in names:
        src = results[n].get("sources", {})
        for major in ("QiCondensation", "QiRefining", "Foundation"):
            book = src.get(major, {})
            tot = sum(book.values()) or 1
            parts = sorted(book.items(), key=lambda kv: -kv[1])
            line = ", ".join(f"{k} {v / tot * 100:.0f}%" for k, v in parts if v / tot >= 0.01)
            print(f"  {n:8} {SHORT[major]}: {line}")


# --------------------------------------------------------------------------
# Foundation percent (server Foundation.luau): what each profile naturally earns
# --------------------------------------------------------------------------

# Main-map beasts today (Config.Wilds.VARIANTS off): Enemies defs at their own realm.
BEASTS = {"QC2": 2, "QC3": 2, "QC4": 2, "QC6": 3, "QC8": 2}  # non-boss kinds per realm
BOSSES = ["QC7", "QC9", "QR5", "QR9"]
# per online hour, server-wide (Weather weights and minutes, WorldEvents triggers
# and TIMER_MINUTES 20-35): events by id, and treasure weathers
EVENT_RATE = {"ThousandYearGinseng": 0.71, "BeastSurge": 0.42, "AuspiciousClouds": 1.86, "VioletCloudMist": 1.11, "GoldenAuspiciousClouds": 0.46}
TREASURE_RATE = {"AuspiciousMist": 0.91, "RainbowAurora": 0.65, "HeavenSplit": 0.39}
# rare mutations (bonus >= MUTATION_BONUS) per growing plant per online hour: weather
# (Weather `garden` chance a minute x its share of time) and the peak's roll
MUTATION_RATE = {"Thunderstruck": 0.37, "Auspicious": 0.48 + 0.03 * 0.15, "Rainbow": 0.13, "Heavenlit": 0.05, "Golden": 0.03 * 0.05}
CACHES = {"InnerWilds": 3, "MiddleWilds": 3, "OuterWilds": 2, "DeepWilds": 0, "FarReaches": 0}  # assumption: the place file holds them

FOUNDATION_HABITS = {
    # share of events / treasures / caches they take part in, boss and Daring
    # appetite, Herbarium pages completed (tier -> stage), Dao XP a fight minute and
    # the stage a second weapon class starts
    "casual": {"events": 0.3, "treasures": 0.15, "caches": 0.3, "boss": 0.5, "daring": 0.2, "pages": {1: "QR3"}, "dao_xp": 15, "second_class": None, "kills_per_min": 1.3, "haul": 0.6},
    "regular": {"events": 0.5, "treasures": 0.3, "caches": 0.6, "boss": 0.85, "daring": 0.5, "pages": {1: "QC7", 2: "QR8"}, "dao_xp": 20, "second_class": "QR1", "kills_per_min": 1.5, "haul": 0.9},
    "heavy": {"events": 0.8, "treasures": 0.6, "caches": 1.0, "boss": 1.0, "daring": 0.9, "pages": {1: "QC6", 2: "QR4", 3: "FE3", 4: "FE8"}, "dao_xp": 25, "second_class": "QR1", "kills_per_min": 1.6, "haul": 1.0},
}


def load_foundation(game_src: str | None = None) -> dict:
    pacing = _read("Pacing.luau")
    f = _block(pacing, "Pacing.Foundation =")
    tgt = _map(f, "TARGET")
    return {"TARGET": tgt, "DEFAULT_TARGET": _num(f, "DEFAULT_TARGET"), "MAX_PERCENT": _num(f, "MAX_PERCENT"),
            "OVER_COST": _num(f, "OVER_COST", 1), "FIT_BELOW": _num(f, "FIT_BELOW"),
            "HUNTER": (10, 4, 2), "GARDENER": 3, "HAUL": 0.75, "DARING": 2,
            "CARRY": 1,  # Foundation.seal: experiences past MAX_PERCENT's need carry into the next stage
            "BONUS_TO_FULL": _num(f, "BONUS_TO_FULL"), "BONUS_PAST_FULL": _num(f, "BONUS_PAST_FULL"),
            "TEMPER_POINTS": _num(f, "TEMPER_POINTS"), "TEMPER_MAX": _num(f, "TEMPER_MAX"), "DEEPEN_MAX": _num(f, "DEEPEN_MAX")}


def load_tempering() -> dict:
    """Seclusion's tempering items (Pacing.Tempering), the heart demon's steps, the
    Pavilion's pills and seclusion's finds."""
    pacing = _read("Pacing.luau")
    t = _block(pacing, "Pacing.Tempering =")
    hd = _block(pacing, "Pacing.HeartDemon =")
    secl = _block(pacing, "Pacing.Seclusion =")
    sect = _block(pacing, "Pacing.Sect =")
    pills = _block(sect, "PILLS =")
    return {"SETTLE_SECONDS": _num(t, "SETTLE_SECONDS"), "CEILING": _num(_block(pacing, "Pacing.Foundation ="), "TEMPER_MAX"),
            "PER_DAY": _num(t, "PER_DAY"), "PER_WEEK": _num(t, "PER_WEEK"),
            "POINTS": _map(t, "POINTS"), "BOSS_CHANCE": _num(t, "BOSS_CHANCE"),
            "TEMPER_CALM": _num(hd, "TEMPER_CALM"), "TEMPER_ROUGH": _num(hd, "TEMPER_ROUGH"),
            "CLEAR_BOSS_CHANCE": _num(hd, "CLEAR_BOSS_CHANCE"), "DEEPEN_CALM": _num(hd, "DEEPEN_CALM"),
            "FIND_CHANCE": _num(secl, "FIND_CHANCE"), "FINDS": _map(secl, "FINDS"),
            "FIRST_PILLS": _map(secl, "FIRST_ITEMS").get("TemperingPill", 0),
            "PAVILION_WEEK": _num(_block(pills, "TemperingPill ="), "week")}


# How each profile tempers (assumptions): Pavilion pills bought a week (from QC5),
# Snowpeak Lotus / Nine-Leaf Lingzhi eaten in seclusion a week (once grown: QR6 / FE4),
# denials in a heart-demon trial, and whether a Clear Heart Pill is used (forgives one).
TEMPER_HABITS = {
    "casual": {"pavilion": 0.5, "snowpeak": 0.5, "lingzhi": 0.0, "denials": 1, "clear": 0.3},
    "regular": {"pavilion": 1.0, "snowpeak": 1.5, "lingzhi": 0.3, "denials": 0, "clear": 0.6},
    "heavy": {"pavilion": 1.0, "snowpeak": 3.0, "lingzhi": 1.0, "denials": 0, "clear": 1.0},
}


def percent_for(count, target, cfg):
    share = min(count, target) / target + max(0.0, count - target) / (target * cfg["OVER_COST"])
    return min(cfg["MAX_PERCENT"], round(share * 100))


def foundation_counts(model: "Model", result: dict, habits: dict, cfg: dict) -> dict:
    """Expected weighted experiences earned at each graded stage (QC4..FE8)."""
    g = model.g
    p = model.p
    seen = set()  # pool keys already earned (expected: we credit fractional keys)
    pool_left = {}  # key -> remaining probability mass not yet earned
    out = {}
    dao_xp = 0.0
    dao2_xp = 0.0
    contrib = 0.0
    sect_keys = {"chain": False, "Inner": False, "Core": False}
    days_at = {}
    reached = result["reached"]
    keys = STAGES

    def earn_prob(key, prob):
        """Earn `key` with this chance now (once per profile)."""
        left = pool_left.get(key, 1.0)
        got = left * prob
        pool_left[key] = left - got
        return got

    def dao_levels(xp, start):
        lvl, need = start, 0.0
        while lvl < 10:
            need += 30 + 30 * lvl
            if xp < need:
                break
            lvl += 1
        return lvl

    for i in range(idx("QC4"), idx("FE9")):
        key = keys[i]
        mins = result["stage_min"].get(i, 0)
        fight = mins * p["fight_share"]
        hours = mins / 60
        band = band_of(key)[1]
        btier = band_tier(key)
        rates = [v for (k, _), v in result["rates"].items() if k == i]
        r = rates[-1] if rates else model.rates(i)
        plan = r["garden"]["plants"]
        kinds = len({h for h, _, kind in plan if kind != "aura"})
        growing = sum(n for _, n, kind in plan if kind != "aura")
        count = 0.0
        # --- deeds (once per stage)
        hk, per, below = cfg["HUNTER"]
        near = [k for k in BEASTS if idx(key) - below <= idx(k) <= idx(key) + 2 and k[:2] == key[:2] or (idx(key) - below <= idx(k) <= idx(key))]
        kinds_near = sum(BEASTS[k] for k in near)
        kills = fight * habits["kills_per_min"]
        if kinds_near * per >= hk:
            count += min(1.0, kills / (hk * 1.5))
        if kinds >= cfg["GARDENER"] and mins > 0:
            sess = sum(m for _, m in p["sessions"]) / len(p["sessions"])
            count += min(1.0, mins / sess)
        trip = (r["fight"] - 60 * r["st"]["p"] * r["common"]) / max(r["eff"], 1e-9) + r["cores_raw"]
        if mins > 0 and trip * fight >= cfg["HAUL"] * r["st"]["d"]:
            count += habits["haul"]
        above = [k for k in list(BEASTS) + BOSSES if idx(k) >= idx(key) + cfg["DARING"] and k[:2] == key[:2]]
        if above and fight > 0:
            count += habits["daring"] * min(1.0, fight / 15)
        # --- hunts: first kill of each kind in reach (fit: at most FIT_BELOW under)
        reach = [k for k in BEASTS if idx(key) - cfg["FIT_BELOW"] <= idx(k) <= idx(key) + 2]
        total_kinds = sum(BEASTS[k] for k in reach) or 1
        for k in reach:
            for n in range(BEASTS[k]):
                prob = 1 - math.exp(-kills / total_kinds)
                count += earn_prob(f"hunt:{k}:{n}", prob)
        # --- bosses (weight 2) in reach
        for b in BOSSES:
            if idx(key) - cfg["FIT_BELOW"] <= idx(b) <= idx(key) + 1 and idx(b) >= idx(key) - 0:
                if b[:2] == key[:2]:
                    count += 2 * earn_prob(f"boss:{b}", habits["boss"] * min(1.0, fight / 20))
        # --- home: the band's tier, rare mutations, Herbarium pages
        if model.owned(key)["tier"] >= btier and kinds > 0 and mins > 0:
            count += earn_prob(f"home:tier@{band}", min(1.0, mins / 20))
        for mut, rate in MUTATION_RATE.items():
            count += earn_prob(f"home:mut:{mut}@{band}", 1 - math.exp(-rate * growing * hours))
        for t, at in habits["pages"].items():
            if at == key:
                count += earn_prob(f"home:book:{t}", 1.0)
        # --- Dao levels (profile-wide keys)
        before = dao_levels(dao_xp, 2)
        dao_xp += fight * habits["dao_xp"]
        count += dao_levels(dao_xp, 2) - before
        if habits["second_class"] and idx(key) >= idx(habits["second_class"]):
            before = dao_levels(dao2_xp, 0)
            dao2_xp += fight * habits["dao_xp"] * 0.5
            count += dao_levels(dao2_xp, 0) - before
        # --- discover: caches in the band's region (and the sect rack at QR1)
        n_cache = CACHES.get(band, 0)
        for c in range(n_cache):
            count += earn_prob(f"discover:{band}:{c}", habits["caches"] * (1 - math.exp(-fight / 45)))
        if key == "QR1":
            count += earn_prob("discover:rack", habits["caches"])
        # --- world: events and treasures, per band
        for ev, rate in EVENT_RATE.items():
            count += earn_prob(f"world:{ev}@{band}", 1 - math.exp(-rate * habits["events"] * hours))
        for w, rate in TREASURE_RATE.items():
            count += earn_prob(f"world:treasure:{w}@{band}", 1 - math.exp(-rate * habits["treasures"] * hours))
        # --- the sect: chain's end, Inner (QR1, 600 earned), Core (FE1, 2500 earned)
        if idx(key) >= idx("QC5"):
            day_in = reached.get(key, (0, 1))[1]
            day_out = reached.get(keys[i + 1], (0, day_in))[1]
            contrib += max(0, day_out - day_in) * p["dailies"] * 37
        if idx(key) >= idx("QR1") and not sect_keys["chain"] and p["dailies"] >= 1:
            sect_keys["chain"] = True
            count += 1
        if idx(key) >= idx("QR1") and not sect_keys["Inner"] and contrib >= 600:
            sect_keys["Inner"] = True
            count += 1
        if idx(key) >= idx("FE1") and not sect_keys["Core"] and contrib >= 2500:
            sect_keys["Core"] = True
            count += 1
        out[key] = count
    return out


def stage_percents(counts: dict, cfg: dict) -> dict:
    """Percent per stage; with cfg CARRY, experiences past what MAX_PERCENT needs
    carry into the next stage (the proposal) instead of being lost."""
    out, carry = {}, 0.0
    for key, c in counts.items():
        tgt = cfg["TARGET"].get(key, cfg["DEFAULT_TARGET"])
        have = c + carry
        out[key] = (have, percent_for(have, tgt, cfg))
        full = tgt * (1 + (cfg["MAX_PERCENT"] - 100) / 100 * cfg["OVER_COST"])
        carry = max(0.0, have - full) * cfg.get("CARRY", 0)
    return out


def foundation_table(game, profiles, cfg, label=""):
    print(f"\nFoundation percent per stage{label} (TARGET {cfg['TARGET']} default {cfg['DEFAULT_TARGET']}, OVER_COST {cfg['OVER_COST']}, MAX {cfg['MAX_PERCENT']})")
    print(f"{'stage':6}" + "".join(f"{n:>18}" for n in profiles))
    tables = {}
    for n, prof in profiles.items():
        m = Model(game, prof)
        res = m.run()
        tables[n] = foundation_counts(m, res, FOUNDATION_HABITS[n], cfg)
    per = {n: stage_percents(tables[n], cfg) for n in profiles}
    for key in STAGES[idx("QC4"):idx("FE9")]:
        cells = []
        for n in profiles:
            c, pct = per[n][key]
            cells.append(f"{c:5.1f} -> {pct:4.0f}%")
        print(f"{key:6}" + "".join(f"{x:>18}" for x in cells))
    for n in profiles:
        pcts = [v[1] for v in per[n].values()]
        med = sorted(pcts)[len(pcts) // 2]
        print(f"  {n:8} median {med:.0f}%, mean {sum(pcts) / len(pcts):.0f}%, stages under 100%: {sum(1 for x in pcts if x < 100)}, at 130%+: {sum(1 for x in pcts if x >= 130)}")
    if cfg.get("TEMPER_POINTS") and not label.startswith(" on the proposed"):
        temper_table(game, profiles, tables, cfg, load_tempering())
    return tables


def stage_bonus(pct, cfg):
    return cfg["BONUS_TO_FULL"] * min(pct, 100) / 100 + cfg["BONUS_PAST_FULL"] * max(0, pct - 100) / (cfg["MAX_PERCENT"] - 100)


def tempered_percents(model: "Model", result: dict, sealed: dict, name: str, cfg: dict, tcfg: dict) -> dict:
    """Sealed percents after the heart demon (QC9, QR9, FE9: steps x TEMPER_POINTS to
    TEMPER_MAX) and seclusion's tempering items (POINTS each to CEILING, PER_DAY /
    PER_WEEK), applied stage by stage to the stages sealed so far, lowest first."""
    p = model.p
    h = TEMPER_HABITS[name]
    reached = result["reached"]
    grades = {}
    used = {"items": 0.0, "points": 0.0, "wasted": 0.0, "hd": 0.0, "deep": 0.0, "capped": 0.0}
    finds = tcfg["FINDS"]
    find_share = finds.get("TemperingPill", 0) / sum(finds.values())

    def temper(points, ceiling, steps=1.0):
        """Raise the lowest open stage(s); fractional steps credit a share."""
        got = 0.0
        while steps > 1e-9:
            open_ = sorted((v, k) for k, v in grades.items() if v < ceiling)
            if not open_:
                break
            v, k = open_[0]
            share = min(1.0, steps)
            grades[k] = min(ceiling, v + points * share)
            got += grades[k] - v
            steps -= share
        return got

    keys = STAGES
    for i in range(idx("QC4"), idx("FE9") + 1):
        key = keys[i]
        if i > idx("QC4"):
            prev = keys[i - 1]
            grades[prev] = sealed[prev][1]
        nxt = keys[i + 1] if i + 1 < len(keys) else "FE9 full"
        day_in = reached.get(key, (0, 1))[1]
        day_out = reached.get(nxt, (0, day_in))[1]
        days = max(0.5, day_out - day_in + 0.5)
        weeks = days / 7
        # the heart demon at each major's stage 9 (the trial tempers what's sealed so far)
        if key in ("QC9", "QR9", "FE9"):
            denials = max(0, h["denials"] - h["clear"])
            steps = max(tcfg["TEMPER_ROUGH"], tcfg["TEMPER_CALM"] - denials)
            used["hd"] += temper(cfg["TEMPER_POINTS"], cfg["TEMPER_MAX"], steps)
            # a calmed trial deepens one stage at 100%+ (the lowest) past 100%, to DEEPEN_MAX
            calm = 1.0 if h["denials"] == 0 else (h["clear"] if h["denials"] == 1 else 0.0)
            deep = sorted((v, k) for k, v in grades.items() if 100 <= v < cfg["DEEPEN_MAX"])
            if deep and calm > 0:
                v, k = deep[0]
                grades[k] = min(cfg["DEEPEN_MAX"], v + tcfg["DEEPEN_CALM"] * calm)
                used["deep"] += grades[k] - v
        # seclusion's items this stage
        fight_h = result["stage_min"].get(i, 0) * p["fight_share"] / 60
        pills = fight_h * p["boss_per_hour"] * tcfg["BOSS_CHANCE"]
        if idx(key) >= idx("QC5"):
            pills += weeks * min(h["pavilion"], tcfg["PAVILION_WEEK"])
        if p["seclusion"]:
            pills += days * ASSUME.get("seclusion_hours", 10) * tcfg["FIND_CHANCE"] * find_share
        if key == "QC5":
            pills += tcfg["FIRST_PILLS"]
        snow = weeks * h["snowpeak"] if idx(key) >= idx("QR6") else 0.0
        ling = weeks * h["lingzhi"] if idx(key) >= idx("FE4") else 0.0
        room = min(days * tcfg["PER_DAY"], weeks * tcfg["PER_WEEK"])
        for pts, n in ((tcfg["POINTS"]["TemperingPill"], pills), (tcfg["POINTS"]["NineLeafLingzhi"], ling), (tcfg["POINTS"]["SnowpeakLotus"], snow)):
            take = min(n, room)
            used["capped"] += n - take
            room -= take
            if take > 0:
                got = temper(pts, tcfg["CEILING"], take)
                used["items"] += take
                used["points"] += got
                used["wasted"] += take * pts - got
    return {"grades": grades, "used": used}


def temper_table(game, profiles, tables, cfg, tcfg):
    """Sealed vs tempered (heart demon + seclusion items) at FE9."""
    print(f"\nTempering (heart demon {cfg['TEMPER_POINTS']:.0f} pts to {cfg['TEMPER_MAX']:.0f}%; seclusion items {tcfg['POINTS']} to {tcfg['CEILING']:.0f}%, {tcfg['PER_DAY']:.0f}/day {tcfg['PER_WEEK']:.0f}/week)")
    out = {}
    for n, prof in profiles.items():
        m = Model(game, prof)
        res = m.run()
        sealed = stage_percents(tables[n], cfg)
        t = tempered_percents(m, res, sealed, n, cfg, tcfg)
        before = [v[1] for v in sealed.values()]
        after = list(t["grades"].values())
        def line(pcts):
            med = sorted(pcts)[len(pcts) // 2]
            return (f"median {med:.0f}%, under 100%: {sum(1 for x in pcts if x < 100)}, 130%+: {sum(1 for x in pcts if x >= 130)}, "
                    f"bonus +{100 * sum(stage_bonus(x, cfg) for x in pcts):.0f}%")
        u = t["used"]
        print(f"  {n:8} sealed   {line(before)}")
        print(f"  {'':8} tempered {line(after)}   (heart demon +{u['hd']:.0f} pts, deepened +{u['deep']:.0f}; {u['items']:.1f} items +{u['points']:.0f} pts, {u['wasted']:.0f} pts with nothing to mend, {u['capped']:.1f} over the cap)")
        out[n] = t
    n_st = idx("FE9") - idx("QC4")
    print(f"  reference over {n_st} stages: all mended to 100% +{100 * n_st * stage_bonus(100, cfg):.0f}%, all deepened to {cfg['DEEPEN_MAX']:.0f}% +{100 * n_st * stage_bonus(cfg['DEEPEN_MAX'], cfg):.0f}%, all earned to {cfg['MAX_PERCENT']:.0f}% +{100 * n_st * stage_bonus(cfg['MAX_PERCENT'], cfg):.0f}%")
    return out


FOUNDATION_GOAL = {"casual": 95, "regular": 105, "heavy": 135}  # median stage percent (owner via coordinator, 2026-10-24)


def solve_foundation(game, profiles, cfg):
    """Grid-search TARGET (QC4, QC5-9, the rest) and OVER_COST for the mean percents
    in FOUNDATION_GOAL. Counts don't depend on the targets, so they're computed once."""
    counts = {}
    for n, prof in profiles.items():
        m = Model(game, prof)
        counts[n] = foundation_counts(m, m.run(), FOUNDATION_HABITS[n], cfg)
    best = None
    for qc4 in (2, 3, 4, 5):
        for qc in (2, 3, 4, 5, 6, 7):
            for rest in (2, 2.5, 3, 3.5, 4, 5, 6, 7):
                for over in (1.5, 2, 2.5, 3, 4, 5):
                    c = dict(cfg, OVER_COST=over, DEFAULT_TARGET=rest,
                             TARGET={"QC4": qc4, **{f"QC{k}": qc for k in range(5, 10)}})
                    err = 0.0
                    for n, goal in FOUNDATION_GOAL.items():
                        pcts = sorted(v[1] for v in stage_percents(counts[n], c).values())
                        err += (pcts[len(pcts) // 2] - goal) ** 2
                    if best is None or err < best[0]:
                        best = (err, c)
    return best[1]


LEVERS = ["economy", "herbqi", "buffs", "aura", "peakscore", "meditem", "root", "method", "cores", "offline", "dailyqi", "party", "seclusion", "weather"]


def lever_table(game, names):
    print("\nOne lever off at a time: active hours / calendar day to FE9 full (and QR done)")
    print(f"{'lever off':12}" + "".join(f"{n:>26}" for n in names))
    base = {n: Model(game, PROFILES[n]).run()["reached"] for n in names}

    def cell(res, n):
        v, b = res.get("FE9 full"), base[n].get("FE9 full")
        q = res.get("FE1")
        if not v:
            return f"{'not reached':>26}"
        delta = (v[0] / b[0] - 1) * 100 if b else 0
        return f"{fmt_h(v[0]) + ' d' + str(v[1]) + f' ({delta:+.0f}%) QR ' + fmt_h(q[0]):>26}"

    print(f"{'(none)':12}" + "".join(cell(base[n], n) for n in names))
    for lever in LEVERS:
        row = [cell(Model(game, PROFILES[n], {lever}).run()["reached"], n) for n in names]
        print(f"{lever:12}" + "".join(row))


# A pending proposal (not applied to Pacing.luau): (game key, value, why) rows that
# --proposal runs side by side, with the bars re-solved. Empty: the 2026-10-24
# rebalance is applied (docs/systems/pacing-model.md); add rows to try the next one.
PROPOSAL: list = []


# then the bars: one Pacing.Adjust `bar` multiplier per realm, solved so the regular
# profile's online-only hours (no offline credit) hit the header's active targets
REALM_TARGETS = {"QiCondensation": 2.4, "QiRefining": 7.1, "Foundation": 19.8}
REALM_OF = {"QiCondensation": ("QC1", "QR1"), "QiRefining": ("QR1", "FE1"), "Foundation": ("FE1", "FE9 full")}


def realm_hours(reached):
    out = {}
    for major, (a, b) in REALM_OF.items():
        if a in reached and b in reached:
            out[major] = reached[b][0] - reached[a][0]
    return out


HOOK_KEEP = ("QC1", "QC2", "QC3")  # the hook's bars stay as the curve has them (the first run fills QC1)


def solve_bars(game: dict, profile: dict, rounds=8) -> dict:
    g = copy.deepcopy(game)
    mult = {m: 1.0 for m in REALM_TARGETS}

    def adjust(round_to):
        return {row["key"]: {"bar": round_to(mult[row["major"]])} for row in g["curve"] if row["key"] not in HOOK_KEEP}
    for _ in range(rounds):
        g["adjust"] = adjust(lambda x: round(x, 2))
        hours = realm_hours(Model(g, profile, {"offline"}).run()["reached"])
        for major, target in REALM_TARGETS.items():
            h = hours.get(major)
            if h:
                mult[major] *= (target / h) ** 0.9
    g["adjust"] = adjust(lambda x: round(x * 20) / 20)
    return g


def apply_proposal(game: dict, bars=True) -> dict:
    g = copy.deepcopy(game)
    for key, value, _ in PROPOSAL:
        g[key] = value
    if bars:
        g = solve_bars(g, PROFILES["regular"])
    return g


def proposal_profiles():
    return copy.deepcopy(PROFILES)


# --------------------------------------------------------------------------
# The balance check (owner, 2026-10-24: "I don't want it overcomplicated to get a
# good progression pace"). No lever is mandatory: a player on one road (hunting and
# refining, or gardening and meditating) with a natural garden and no min-maxing of
# buffs, cores or decorations stays within ROAD_LIMIT of the regular's online time;
# a min-maxer stacking everything (the heavy profile) is at most MINMAX_LIMIT faster.
# --------------------------------------------------------------------------

ROAD_LIMIT = 0.15  # one-road online time at most 15% over the regular's
MINMAX_LIMIT = 1.30  # the heavy's online speed at most 1.3x the regular's

_reg = PROFILES["regular"]
ROADS = {
    # hunts three quarters of the time; a small garden of qi herbs it eats; no buff
    # herbs, no standing aura plants, no decorations or seat item, no party
    "hunter": dict(copy.deepcopy(_reg), label="Hunter road (hunt and refine, natural garden)", fight_share=0.75,
                   plots={"QC4": (4, 1, 0), "QR1": (6, 1, 1), "FE1": (8, 2, 1)}, buffs=0, buff_uptime=0.0,
                   aura_keep=0, chase_plots=0, score={}, med_item={}, party_share=0.0, dailies=1),
    # sits on its peak 70% of the time with the regular's garden and the seat (a
    # cushion); sells a third of the qi herbs for stones; no buff herbs, no standing
    # aura plants, no decorations, no party
    "gardener": dict(copy.deepcopy(_reg), label="Garden road (garden and meditate)", fight_share=0.3,
                     buffs=0, buff_uptime=0.0, aura_keep=0, chase_plots=0, score={}, med_item={"QC6": 1},
                     party_share=0.0, dailies=1, sell_share=0.3),
}


def balance_check(game: dict) -> bool:
    """Prints the one-road and min-maxer checks (online only); True when both pass."""
    def total(prof):
        r = Model(game, prof, {"offline"}).run()["reached"]
        return r.get("FE9 full", (None,))[0], realm_hours(r)
    reg, reg_r = total(PROFILES["regular"])
    print("\nBalance check (online only, to FE9 full): no lever is mandatory")
    ok = True
    for name, prof in list(ROADS.items()) + [("heavy (everything)", PROFILES["heavy"])]:
        t, rh = total(prof)
        if t is None or reg is None:
            print(f"  {name:20} not reached")
            ok = False
            continue
        over = t / reg - 1
        speed = reg / t
        if name in ROADS:
            good = over <= ROAD_LIMIT
            verdict = f"{over * 100:+.0f}% vs regular (limit +{ROAD_LIMIT * 100:.0f}%)"
        else:
            good = speed <= MINMAX_LIMIT
            verdict = f"x{speed:.2f} the regular's speed (limit x{MINMAX_LIMIT:.2f})"
        ok &= good
        realms = " / ".join(f"{SHORT[m]} {rh.get(m, 0):.1f}h" for m in REALM_TARGETS)
        print(f"  {name:20} {fmt_h(t):>7}  {verdict:42} {'ok' if good else 'FAIL'}   ({realms})")
    return ok


# --------------------------------------------------------------------------
# The Pacing header's time table (the bare fighter and gardener on this curve)
# --------------------------------------------------------------------------

def header_rows(game: dict) -> list[dict]:
    m = Model(game, PROFILES["regular"])
    reg = Model(game, PROFILES["regular"], {"offline"}).run()["reached"]
    rows = []
    for i, row in enumerate(game["curve"]):
        st = m.stage(i)
        w = m.wolf(st)
        p = st["p"]
        active = st["bar"] / (60 * p + 2 * game["BASE_REFINE"] * w * st["gather"])
        idle = st["bar"] / p / 60
        nxt = STAGES[i + 1] if i + 1 < len(STAGES) else "FE9 full"
        here = reg.get(STAGES[i]), reg.get(nxt)
        rows.append({
            "key": row["key"], "bar": st["bar"], "active": active, "peak": idle / game["ON_PEAK"],
            "meditate": idle / game["ANYWHERE"], "idle": idle,
            "runs": st["bar"] / (st["d"] / game["RUNS_PER_DANTIAN"] * game["BASE_REFINE"]),
            "wolves": st["bar"] / game["BASE_REFINE"] / (w * st["gather"]), "gather": row["gather"],
            "regular": (here[1][0] - here[0][0]) * 60 if here[0] and here[1] else None,
        })
    return rows


def _m(minutes):
    return f"{minutes:.0f} min" if minutes < 60 else f"{minutes / 60:.1f} h"


def print_header(game: dict):
    rows = header_rows(game)
    print("--   stage     bar    active  on peak  meditate    idle  regular  refine runs, wolf kills of qi")
    tot = {"QiCondensation": [0, 0, 0], "QiRefining": [0, 0, 0], "Foundation": [0, 0, 0]}
    for r, row in zip(rows, game["curve"]):
        t = tot[row["major"]]
        t[0] += r["active"]
        t[1] += r["peak"]
        t[2] += r["regular"] or 0
        g = f" (gather {r['gather']:g})" if r["gather"] != 1 else ""
        line = (f"--   {r['key']:5}{r['bar']:>9.0f}{_m(r['active']):>9}{_m(r['peak']):>9}{_m(r['meditate']):>10}{_m(r['idle']):>8}"
                f"{_m(r['regular']) if r['regular'] is not None else '-':>9}{r['runs']:>6.0f} runs  ~{r['wolves']:.0f} wolves{g}")
        last = row["key"].endswith("9")
        if last:
            line += f"   {SHORT[row['major']]} total: {t[0] / 60:.1f} h active, {t[1] / 60:.1f} h on peak, regular {t[2] / 60:.1f} h"
        print(line)


def header_check(game: dict) -> bool:
    """The Pacing header's table matches this curve (bar and the fighter's active time)."""
    src = _read("Pacing.luau")
    want = {r["key"]: r for r in header_rows(game)}
    ok, seen = True, 0
    for key, bar, active in re.findall(r"--   ([A-Z]{2}\d)\s+(\d+)\s+([\d.]+ (?:min|h))", src):
        seen += 1
        mins = float(active.split()[0]) * (60 if active.endswith("h") else 1)
        r = want.get(key)
        if not r or abs(float(bar) / r["bar"] - 1) > 0.01 or abs(mins - r["active"]) > max(0.6, 0.08 * r["active"]):
            ok = False
            print(f"  header {key}: bar {bar}, active {active}; the curve says {r['bar']:.0f}, {_m(r['active'])}" if r else f"  header {key}: unknown")
    ok &= seen == len(want)
    print(f"\nHeader check (Pacing.luau's time table vs this curve): {'ok' if ok else 'FAIL: run --header and paste it'}")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stages", action="store_true", help="stage-by-stage tables")
    ap.add_argument("--levers", action="store_true", help="one-lever-off sensitivity")
    ap.add_argument("--sources", action="store_true", help="where the cultivation came from")
    ap.add_argument("--foundation", action="store_true", help="foundation percent per stage")
    ap.add_argument("--proposal", action="store_true", help="also run the proposed knobs")
    ap.add_argument("--header", action="store_true", help="print the Pacing header's time table for this curve")
    args = ap.parse_args()

    game = load_game()
    names = list(PROFILES)
    results = {"fighter (header check)": Fighter(game, {}).run()}
    models = {}
    for n in names:
        models[n] = Model(game, PROFILES[n])
        results[n] = models[n].run()
    print("Time to each milestone: active hours / calendar day (day 1 = first day)\n")
    for n in names:
        results[n + " (online only)"] = Model(game, PROFILES[n], {"offline"}).run()
    summary(results, ["fighter (header check)"] + names + [n + " (online only)" for n in names])

    if args.sources:
        source_table(results, names)

    if args.stages:
        for n in names:
            stage_table(game, n, models[n], results[n])

    if args.foundation:
        fcfg = load_foundation()
        foundation_table(game, PROFILES, fcfg, " (with the carry)")

    if args.levers:
        lever_table(game, names)

    balance_check(game)
    header_check(game)
    if args.header:
        print()
        print_header(game)

    if args.proposal and not PROPOSAL:
        print("\nNo proposal pending (PROPOSAL is empty).")
    elif args.proposal:
        pg = apply_proposal(game)
        pp = proposal_profiles()
        presults = {"fighter (header check)": Fighter(pg, {}).run()}
        for n in names:
            presults[n] = Model(pg, pp[n]).run()
        for n in names:
            presults[n + " (online only)"] = Model(pg, pp[n], {"offline"}).run()
        adj = {row["major"]: pg["adjust"][row["key"]]["bar"] for row in pg["curve"]}
        print("\nWith the proposal (see docs/systems/pacing-model.md); bar x per realm:", adj, "\n")
        summary(presults, ["fighter (header check)"] + names + [n + " (online only)" for n in names])
        if args.stages:
            for n in names:
                stage_table(pg, n, Model(pg, pp[n]), presults[n])
        if args.foundation:
            fcfg = load_foundation()
            foundation_table(pg, pp, fcfg, " on the proposed curve, today's foundation knobs")
            foundation_table(pg, pp, solve_foundation(pg, pp, fcfg), " on the proposed curve, solved knobs, no carry")
            foundation_table(pg, pp, solve_foundation(pg, pp, dict(fcfg, CARRY=1)), " on the proposed curve, solved knobs, with carry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
