#!/usr/bin/env python3
"""
GoblinArcade headless balance audit.

This is deliberately a balance model, not a WoW UI emulator. It mirrors the
runtime formulas, Studio data, loot/economy and temporary-level progression,
then runs deterministic Monte Carlo scenarios so balance changes can be
evaluated without manual playthroughs.

Two combat envelopes are reported:
- SEQUENTIAL: optimistic one-on-one engagements.
- PRESSURE: sensitivity test that adds bounded extra incoming attacks to model
  clustered/alerted enemies.
- HEAVY_PRESSURE: doubles that extra pressure envelope to expose how quickly a
  build collapses when several enemies converge.

The audit never edits Studio data. It reports evidence for a later balance pass.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import statistics
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "studio-data.json"

FLOOR_BASE = {1: 6, 2: 6, 3: 7, 4: 7, 5: 8, 6: 8, 7: 9, 8: 9, 9: 10}
ARCHETYPE_MIX = {
    1: {"kobold": 80, "spider": 20, "skeleton": 0},
    2: {"kobold": 80, "spider": 20, "skeleton": 0},
    3: {"kobold": 60, "spider": 30, "skeleton": 10},
    4: {"kobold": 60, "spider": 30, "skeleton": 10},
    5: {"kobold": 45, "spider": 30, "skeleton": 25},
    6: {"kobold": 45, "spider": 30, "skeleton": 25},
    7: {"kobold": 35, "spider": 30, "skeleton": 35},
    8: {"kobold": 35, "spider": 30, "skeleton": 35},
    9: {"kobold": 25, "spider": 25, "skeleton": 50},
}
RANK_MIX = {
    1: {"normal": 100, "veteran": 0, "elite": 0},
    2: {"normal": 100, "veteran": 0, "elite": 0},
    3: {"normal": 80, "veteran": 20, "elite": 0},
    4: {"normal": 80, "veteran": 20, "elite": 0},
    5: {"normal": 75, "veteran": 25, "elite": 0},
    6: {"normal": 75, "veteran": 25, "elite": 0},
    7: {"normal": 60, "veteran": 30, "elite": 10},
    8: {"normal": 60, "veteran": 30, "elite": 10},
    9: {"normal": 45, "veteran": 35, "elite": 20},
}
RANK_COPPER = {"normal": 1.00, "veteran": 1.40, "elite": 2.25, "boss": 5.00}
SPEED_SECONDS = {"FAST": 1.8, "NORMAL": 2.4, "SLOW": 3.2}
PRESSURE_EXTRA_HIT = {
    1: 0.00, 2: 0.02, 3: 0.05, 4: 0.08, 5: 0.12,
    6: 0.16, 7: 0.20, 8: 0.24, 9: 0.28,
}

def round_lua(value: float) -> int:
    return math.floor(value + 0.5)

def scale_combat(value: float) -> int:
    if value <= 0:
        return 0
    return max(1, math.floor(value / 10 + 0.5))

def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, math.floor((len(ordered) - 1) * p))
    return ordered[idx]

def floor_bonus(floor: int) -> int:
    if floor >= 9:
        return 4
    if floor >= 7:
        return 3
    if floor >= 5:
        return 2
    if floor >= 3:
        return 1
    return 0

def density_multiplier(rng: random.Random) -> float:
    roll = rng.randint(1, 100)
    if roll <= 20:
        return 0.90
    if roll <= 80:
        return 1.00
    return 1.10

def make_plan(rng: random.Random, count: int, weights: dict[str, int], order: list[str]) -> list[str]:
    counts: dict[str, int] = {}
    remainders: list[tuple[float, int, str]] = []
    assigned = 0
    for order_index, key in enumerate(order):
        raw = count * (weights.get(key, 0) / 100)
        whole = math.floor(raw)
        counts[key] = whole
        assigned += whole
        remainders.append((raw - whole, order_index, key))
    remainders.sort(key=lambda row: (-row[0], row[1]))
    remaining = count - assigned
    index = 0
    while remaining > 0:
        key = remainders[index][2]
        counts[key] = counts.get(key, 0) + 1
        remaining -= 1
        index = (index + 1) % len(remainders)
    plan: list[str] = []
    for key in order:
        plan.extend([key] * counts.get(key, 0))
    rng.shuffle(plan)
    return plan

@dataclass
class Enemy:
    archetype: str
    rank: str
    danger: int
    hp: int
    max_hp: int
    damage_min: int
    damage_max: int
    xp: int

@dataclass
class Item:
    id: str
    name: str
    tier: str
    required_level: int
    price: int
    category: str
    equip_loc: str | None
    subtype: str
    health: int = 0
    armor: int = 0
    attack_power: int = 0
    dodge: float = 0.0
    crit: float = 0.0
    block: float = 0.0
    damage_min: int = 0
    damage_max: int = 0
    speed: str = "NORMAL"
    trait: str = ""
    trait_value: float = 0.0
    potion_heal: float = 0.0
    quantity: int = 1

    @property
    def is_potion(self) -> bool:
        return self.category == "CONSUMABLE"

@dataclass
class Stats:
    health: int = 0
    armor: int = 0
    attack_power: int = 0
    dodge: float = 0.0
    crit: float = 0.0
    block: float = 0.0

@dataclass
class Player:
    profile: str
    level: int = 1
    levels_gained: int = 0
    xp: int = 0
    base_hp: int = 10
    max_hp: int = 10
    hp: int = 10
    gear: dict[str, Item | None] = field(default_factory=dict)
    stats: Stats = field(default_factory=Stats)
    potions: list[Item] = field(default_factory=list)
    pending: list[Item] = field(default_factory=list)
    copper: int = 0
    potions_used: int = 0
    damage_taken: int = 0

class Audit:
    def __init__(self, seed: int):
        self.rng = random.Random(seed)
        self.data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
        self.items = {x["id"]: x for x in self.data.get("items", [])}
        self.loot_tables = {x["id"]: x for x in self.data.get("lootTables", [])}
        self.loot = self.data.get("loot", [])
        self.ranks = {x["id"]: x for x in self.data.get("ranks", [])}
        self.enemies = {x["id"]: x for x in self.data.get("enemies", [])}
        self.progression = next(x for x in self.data["progression"] if x["id"] == "run_xp")
        self.warrior = next(x for x in self.data["classes"] if x["id"] == "warrior")
        self.xp_curve = [int(x.strip()) for x in str(self.progression["xpCurve"]).split(",") if x.strip()]
        self._loot_cache: dict[tuple[str, int], list[dict[str, Any]]] = {}

    def xp_needed(self, levels_gained: int) -> int:
        if levels_gained < len(self.xp_curve):
            return self.xp_curve[levels_gained]
        base = self.xp_curve[-1] if self.xp_curve else int(self.progression.get("firstLevelXp", 100))
        extra = levels_gained - len(self.xp_curve) + 1
        return max(1, round_lua(base * float(self.progression.get("levelGrowth", 1.1)) ** extra))

    def create_enemy(self, archetype: str, rank: str, player_level: int, floor: int) -> Enemy:
        a = self.enemies[archetype]
        r = self.ranks[rank]
        effective = player_level + floor_bonus(floor) + int(r.get("levelBonus", 0))
        level_pressure = 1 + 0.15 * ((player_level - 1) / 59)
        floor_hp = 1 + 0.07 * (floor - 1)
        floor_damage = 1 + 0.05 * (floor - 1)

        reference_damage = 5 + effective * 0.90
        base_hp = reference_damage * 2.50
        reference_player_hp = 100 + effective * 20
        average_damage = reference_player_hp * 0.040

        raw_hp = round_lua(
            base_hp
            * float(a["hpMultiplier"])
            * float(r["hpMultiplier"])
            * level_pressure
            * floor_hp
        )
        scaled_average = (
            average_damage
            * float(a["damageMultiplier"])
            * float(r["damageMultiplier"])
            * level_pressure
            * floor_damage
        )
        damage_min = scale_combat(max(1, round_lua(scaled_average * 0.80)))
        damage_max = max(damage_min, scale_combat(max(1, round_lua(scaled_average * 1.20))))
        xp = max(
            1,
            round_lua(
                float(a.get("dangerRating", 1))
                * float(self.progression["xpPerDanger"])
                * float(r.get("xpMultiplier", 1))
            ),
        )
        hp = scale_combat(raw_hp)
        return Enemy(
            archetype=archetype,
            rank=rank,
            danger=int(a.get("dangerRating", 1)),
            hp=hp,
            max_hp=hp,
            damage_min=damage_min,
            damage_max=damage_max,
            xp=xp,
        )

    def floor_enemies(self, player_level: int, floor: int) -> list[Enemy]:
        count = max(1, round_lua(FLOOR_BASE[floor] * density_multiplier(self.rng)))
        archetypes = make_plan(self.rng, count, ARCHETYPE_MIX[floor], ["kobold", "spider", "skeleton"])
        ranks = make_plan(self.rng, count, RANK_MIX[floor], ["normal", "veteran", "elite"])

        # Mirrors the current special-room anchors: one forced Elite from F5,
        # plus one forced Boss on F9, both inside the existing population budget.
        if floor >= 9 and count >= 1:
            ranks[0] = "boss"
        if floor >= 5 and count >= 2:
            ranks[1 if floor >= 9 else 0] = "elite"

        return [self.create_enemy(a, ranks[i], player_level, floor) for i, a in enumerate(archetypes)]

    def loot_entries(self, table_id: str, floor: int) -> list[dict[str, Any]]:
        key = (table_id, floor)
        cached = self._loot_cache.get(key)
        if cached is not None:
            return cached
        result = [
            e for e in self.loot
            if e.get("tableId") == table_id
            and floor >= int(e.get("minFloor", 1))
            and floor <= int(e.get("maxFloor", 999))
            and e.get("itemId") in self.items
        ]
        self._loot_cache[key] = result
        return result

    def build_item(self, entry: dict[str, Any]) -> Item:
        x = self.items[entry["itemId"]]
        mult = float(entry.get("powerMultiplier", 1) or 1)
        category = str(x.get("category", "ARMOR")).upper()
        return Item(
            id=x["id"],
            name=x.get("name", x["id"]),
            tier=str(x.get("tier", "T0")),
            required_level=int(x.get("requiredLevel", 1) or 1),
            price=int(x.get("price", 0) or 0),
            category=category,
            equip_loc=x.get("equipLoc"),
            subtype=str(x.get("itemSubType", category)),
            health=round_lua(float(x.get("health", 0) or 0) * mult),
            armor=round_lua(float(x.get("armor", 0) or 0) * mult),
            attack_power=round_lua(float(x.get("attackPower", 0) or 0) * mult),
            dodge=round(float(x.get("dodge", 0) or 0) * mult, 1),
            crit=round(float(x.get("crit", 0) or 0) * mult, 1),
            block=round(float(x.get("block", 0) or 0) * mult, 1),
            damage_min=max(1, round_lua(float(x.get("damageMin", 1) or 1) * mult)) if category == "WEAPON" else 0,
            damage_max=max(1, round_lua(float(x.get("damageMax", 1) or 1) * mult)) if category == "WEAPON" else 0,
            speed=str(x.get("weaponSpeed", "NORMAL")),
            trait=str(x.get("traitName", "") or ""),
            trait_value=float(x.get("traitValue", 0) or 0),
            potion_heal=float(x.get("effectValue", 0) or 0) if category == "CONSUMABLE" else 0,
            quantity=int(entry.get("quantity", 1) or 1),
        )

    def roll_loot(self, table_id: str, floor: int) -> Item | None:
        definition = self.loot_tables.get(table_id)
        if not definition:
            return None
        chance = max(0.0, min(100.0, float(definition.get("dropChance", 100))))
        if self.rng.random() * 100 >= chance:
            return None
        entries = self.loot_entries(table_id, floor)
        if not entries:
            return None
        total = sum(max(0.0, float(e.get("weight", 0))) for e in entries)
        if total <= 0:
            return None
        roll = self.rng.random() * total
        cursor = 0.0
        selected = entries[-1]
        for entry in entries:
            cursor += max(0.0, float(entry.get("weight", 0)))
            if roll <= cursor:
                selected = entry
                break
        return self.build_item(selected)

    def shop_stock(self, floor: int = 6, count: int = 4) -> list[Item]:
        entries = list(self.loot_entries("shop_inventory", floor))
        result: list[Item] = []
        while len(result) < count and entries:
            total = sum(max(0.0, float(e.get("weight", 0))) for e in entries)
            if total <= 0:
                break
            roll = self.rng.random() * total
            cursor = 0.0
            selected_index = len(entries) - 1
            for index, entry in enumerate(entries):
                cursor += max(0.0, float(entry.get("weight", 0)))
                if roll <= cursor:
                    selected_index = index
                    break
            result.append(self.build_item(entries.pop(selected_index)))
        return result

    @staticmethod
    def starter_weapon() -> Item:
        return Item(
            id="starter",
            name="Starter Sword",
            tier="T0",
            required_level=1,
            price=0,
            category="WEAPON",
            equip_loc="INVTYPE_WEAPON",
            subtype="Sword",
            damage_min=1,
            damage_max=1,
            speed="NORMAL",
        )

    def initial_player(self, profile: str) -> Player:
        player = Player(profile=profile)
        player.gear["mainhand"] = self.starter_weapon()
        self.recalculate(player)
        return player

    @staticmethod
    def slot_key(item: Item, player: Player) -> str | None:
        if item.equip_loc == "INVTYPE_FINGER":
            if not player.gear.get("finger1"):
                return "finger1"
            if not player.gear.get("finger2"):
                return "finger2"
            return "finger1"
        if item.equip_loc == "INVTYPE_TRINKET":
            if not player.gear.get("trinket1"):
                return "trinket1"
            if not player.gear.get("trinket2"):
                return "trinket2"
            return "trinket1"
        return {
            "INVTYPE_HEAD": "head",
            "INVTYPE_NECK": "neck",
            "INVTYPE_SHOULDER": "shoulder",
            "INVTYPE_CHEST": "chest",
            "INVTYPE_WAIST": "waist",
            "INVTYPE_LEGS": "legs",
            "INVTYPE_FEET": "feet",
            "INVTYPE_WRIST": "wrist",
            "INVTYPE_HAND": "hands",
            "INVTYPE_CLOAK": "back",
            "INVTYPE_WEAPON": "mainhand",
            "INVTYPE_WEAPONMAINHAND": "mainhand",
            "INVTYPE_2HWEAPON": "mainhand",
            "INVTYPE_SHIELD": "offhand",
            "INVTYPE_HOLDABLE": "offhand",
        }.get(item.equip_loc or "")

    @staticmethod
    def gear_score(item: Item | None, profile: str) -> float:
        if not item or item.is_potion:
            return -1e9
        preference = 0.0
        if profile == "shield":
            if item.equip_loc == "INVTYPE_SHIELD":
                preference += 30
            if item.equip_loc == "INVTYPE_2HWEAPON":
                preference -= 100
        elif profile == "2h":
            if item.equip_loc == "INVTYPE_2HWEAPON":
                preference += 35
            if item.equip_loc == "INVTYPE_SHIELD":
                preference -= 40
        return (
            preference
            + item.attack_power * 3
            + item.health * 2
            + item.armor * 0.8
            + item.block * 1.5
            + item.dodge
            + item.crit
            + ((item.damage_min + item.damage_max) / 2) * 4
        )

    def recalculate(self, player: Player) -> None:
        stats = Stats()
        for item in player.gear.values():
            if not item:
                continue
            stats.health += item.health
            stats.armor += item.armor
            stats.attack_power += item.attack_power
            stats.dodge += item.dodge
            stats.crit += item.crit
            stats.block += item.block
        stats.dodge = min(35, stats.dodge)
        stats.crit = min(50, stats.crit)
        stats.block = min(40, stats.block)

        old_max = max(1, player.max_hp)
        ratio = min(1.0, max(0.0, player.hp / old_max))
        player.stats = stats
        player.max_hp = max(1, player.base_hp + stats.health)
        player.hp = max(0, round_lua(player.max_hp * ratio))

    def maybe_equip(self, player: Player, item: Item) -> None:
        if item.is_potion:
            for _ in range(max(1, item.quantity)):
                player.potions.append(item)
            return
        if item.required_level > player.level:
            player.pending.append(item)
            return
        key = self.slot_key(item, player)
        if not key:
            return

        if item.equip_loc == "INVTYPE_2HWEAPON":
            if player.profile == "shield":
                return
            current = player.gear.get("mainhand")
            if not current or self.gear_score(item, player.profile) > self.gear_score(current, player.profile):
                player.gear["mainhand"] = item
                player.gear["offhand"] = None
                self.recalculate(player)
            return

        if key == "offhand" and player.gear.get("mainhand") and player.gear["mainhand"].equip_loc == "INVTYPE_2HWEAPON":
            if player.profile == "2h":
                return

        current = player.gear.get(key)
        if not current or self.gear_score(item, player.profile) > self.gear_score(current, player.profile):
            if key == "mainhand" and player.profile == "2h" and item.equip_loc != "INVTYPE_2HWEAPON":
                return
            player.gear[key] = item
            self.recalculate(player)

    def equip_pending(self, player: Player) -> None:
        old = player.pending
        player.pending = []
        for item in old:
            if item.required_level <= player.level:
                self.maybe_equip(player, item)
            else:
                player.pending.append(item)

    def grant_xp(self, player: Player, amount: int) -> None:
        player.xp += amount
        while player.level < 60 and player.xp >= self.xp_needed(player.levels_gained):
            need = self.xp_needed(player.levels_gained)
            player.xp -= need
            player.level += 1
            player.levels_gained += 1
            hp_gain = int(self.warrior.get("hpPerLevel", 0) or 0)
            player.base_hp += hp_gain
            player.max_hp += hp_gain
            player.hp += hp_gain
            self.equip_pending(player)

    @staticmethod
    def ap_bonus(attack_power: int, speed: str) -> int:
        if attack_power <= 0:
            return 0
        seconds = SPEED_SECONDS.get(speed.upper(), SPEED_SECONDS["NORMAL"])
        return max(0, round_lua((attack_power / 14) * seconds))

    def player_hit(self, player: Player, multiplier: float = 1.0) -> int:
        weapon = player.gear.get("mainhand") or self.starter_weapon()
        damage = self.rng.randint(max(1, weapon.damage_min), max(max(1, weapon.damage_min), weapon.damage_max))
        damage += self.ap_bonus(player.stats.attack_power, weapon.speed)
        damage = max(1, round_lua(damage * multiplier))
        if self.rng.random() * 100 < player.stats.crit:
            damage = max(1, round_lua(damage * 1.5))
        return damage

    def incoming_hit(self, player: Player, enemy: Enemy, defensive: bool) -> int:
        if self.rng.random() * 100 < player.stats.dodge:
            return 0
        raw = self.rng.randint(enemy.damage_min, enemy.damage_max)
        if defensive:
            raw = max(1, round_lua(raw * 0.80))
        mitigation = min(0.55, player.stats.armor / (player.stats.armor + 100))
        damage = max(1, round_lua(raw * (1 - mitigation)))
        if self.rng.random() * 100 < player.stats.block:
            damage = max(1, round_lua(damage * 0.5))
        return damage

    def use_potion(self, player: Player) -> bool:
        if not player.potions:
            return False
        player.potions.sort(key=lambda p: p.potion_heal)
        missing = player.max_hp - player.hp
        selected_index = next(
            (
                i for i, potion in enumerate(player.potions)
                if math.ceil(player.max_hp * potion.potion_heal / 100) >= missing
            ),
            len(player.potions) - 1,
        )
        potion = player.potions.pop(selected_index)
        heal = max(1, round_lua(player.max_hp * potion.potion_heal / 100))
        player.hp = min(player.max_hp, player.hp + heal)
        player.potions_used += 1
        return True

    def fight(self, player: Player, enemy: Enemy, floor: int, pressure_scale: float) -> tuple[bool, int]:
        turns = 0
        rage = 0
        defensive = player.profile == "shield" and player.level >= 10

        # Competent low-level Warrior model: use Charge as an opener once it is learned.
        if player.level >= 4:
            enemy.hp = max(0, enemy.hp - self.player_hit(player, 1.0))
            turns += 1
            rage = min(3, rage + 2)
            if enemy.hp <= 0:
                return True, turns

        while enemy.hp > 0 and player.hp > 0 and turns < 100:
            if player.hp / player.max_hp <= 0.38 and player.potions:
                self.use_potion(player)
                turns += 1
                damage = self.incoming_hit(player, enemy, defensive)
                player.hp -= damage
                player.damage_taken += damage
                if player.hp <= 0:
                    break
            else:
                multiplier = 1.0
                if rage >= 2:
                    # Heroic Strike
                    multiplier = 1.5
                    rage -= 2
                else:
                    # Basic Attack
                    rage = min(3, rage + 1)

                enemy.hp = max(0, enemy.hp - self.player_hit(player, multiplier))
                turns += 1
                if enemy.hp <= 0:
                    break

                damage = self.incoming_hit(player, enemy, defensive)
                player.hp -= damage
                player.damage_taken += damage

            # Sensitivity test for simultaneous alerted enemies. This is not
            # claimed to be exact pathfinding; it prevents the audit from
            # treating every dungeon as a sterile duel corridor.
            if (
                pressure_scale > 0
                and player.hp > 0
                and enemy.hp > 0
                and self.rng.random() < min(0.75, PRESSURE_EXTRA_HIT[floor] * pressure_scale)
            ):
                extra = self.incoming_hit(player, enemy, defensive)
                player.hp -= extra
                player.damage_taken += extra

        return player.hp > 0, turns

    @staticmethod
    def copper_reward(floor: int, enemy: Enemy) -> int:
        return max(
            1,
            round_lua(((floor * 20) + (enemy.danger * 15)) * RANK_COPPER.get(enemy.rank, 1.0)),
        )

    def floor_rewards(self, player: Player, floor: int, elite_killed: bool, boss_killed: bool) -> None:
        # Current procedural dungeon creates two Treasure chests every floor.
        for _ in range(2):
            item = self.roll_loot("treasure_chest_loot", floor)
            if item:
                self.maybe_equip(player, item)
        if floor >= 5 and elite_killed:
            item = self.roll_loot("elite_cache_loot", floor)
            if item:
                self.maybe_equip(player, item)
        if floor == 9 and boss_killed:
            item = self.roll_loot("boss_cache_loot", floor)
            if item:
                self.maybe_equip(player, item)

    def run_once(self, profile: str, pressure_scale: float) -> dict[str, Any]:
        player = self.initial_player(profile)
        floor_rows: list[dict[str, Any]] = []
        shop_snapshot: dict[str, Any] | None = None

        for floor in range(1, 10):
            start_damage = player.damage_taken
            start_potions = player.potions_used
            start_copper = player.copper

            # The exact Shop room can occur at different points in Floor 6.
            # For economy auditing we use the conservative floor-entry wallet,
            # rather than pretending every F6 kill happened before shopping.
            if floor == 6:
                stock = self.shop_stock()
                affordable = [item for item in stock if item.price <= player.copper]
                shop_snapshot = {
                    "copper": player.copper,
                    "affordable": len(affordable),
                    "stock_prices": [item.price for item in stock],
                }

                # Model an early shop: at most one useful affordable purchase.
                best_item = None
                best_gain = 0.0
                for item in affordable:
                    if item.is_potion:
                        gain = (25 if player.hp / player.max_hp < 0.70 else 5) + item.potion_heal * 0.2
                    elif item.required_level <= player.level:
                        key = self.slot_key(item, player)
                        current = player.gear.get(key) if key else None
                        gain = self.gear_score(item, profile) - self.gear_score(current, profile)
                    else:
                        gain = 0
                    if gain > best_gain:
                        best_gain = gain
                        best_item = item
                if best_item:
                    player.copper -= best_item.price
                    self.maybe_equip(player, best_item)

            enemies = self.floor_enemies(player.level, floor)
            attacks = 0
            kills = 0
            elite_killed = False
            boss_killed = False

            for enemy in enemies:
                won, used_turns = self.fight(player, enemy, floor, pressure_scale)
                attacks += used_turns
                if not won:
                    floor_rows.append({
                        "floor": floor,
                        "dead": True,
                        "kills": kills,
                        "enemy_count": len(enemies),
                        "attacks": attacks,
                        "damage": player.damage_taken - start_damage,
                        "potions_used": player.potions_used - start_potions,
                        "end_hp_pct": 0,
                        "end_level": player.level,
                        "copper_gain": player.copper - start_copper,
                    })
                    return {
                        "complete": False,
                        "death_floor": floor,
                        "player": player,
                        "floors": floor_rows,
                        "shop": shop_snapshot,
                    }

                kills += 1
                player.copper += self.copper_reward(floor, enemy)
                self.grant_xp(player, enemy.xp)
                elite_killed |= enemy.rank == "elite"
                boss_killed |= enemy.rank == "boss"

                drop = self.roll_loot("common_enemy_drops", floor)
                if drop:
                    self.maybe_equip(player, drop)

            self.floor_rewards(player, floor, elite_killed, boss_killed)

            floor_rows.append({
                "floor": floor,
                "dead": False,
                "kills": kills,
                "enemy_count": len(enemies),
                "attacks": attacks,
                "damage": player.damage_taken - start_damage,
                "potions_used": player.potions_used - start_potions,
                "end_hp_pct": 100 * player.hp / player.max_hp,
                "end_level": player.level,
                "copper_gain": player.copper - start_copper,
            })

        return {
            "complete": True,
            "death_floor": None,
            "player": player,
            "floors": floor_rows,
            "shop": shop_snapshot,
        }

    def simulate(self, profile: str, pressure_scale: float, scenario: str, runs: int) -> dict[str, Any]:
        floor_agg = [
            {
                "floor": floor,
                "reached": 0,
                "cleared": 0,
                "damage": 0.0,
                "attacks": 0.0,
                "kills": 0,
                "potions_used": 0.0,
                "end_hp_pct": 0.0,
                "end_level": 0.0,
            }
            for floor in range(1, 10)
        ]
        deaths = [0] * 10
        completions = 0
        total_potions: list[int] = []
        shop_copper: list[float] = []
        shop_affordable: list[float] = []
        final_levels: list[float] = []

        for _ in range(runs):
            result = self.run_once(profile, pressure_scale)
            player: Player = result["player"]
            total_potions.append(player.potions_used)

            if result["complete"]:
                completions += 1
                final_levels.append(player.level)
            else:
                deaths[result["death_floor"]] += 1

            if result["shop"]:
                shop_copper.append(float(result["shop"]["copper"]))
                shop_affordable.append(float(result["shop"]["affordable"]))

            for row in result["floors"]:
                target = floor_agg[row["floor"] - 1]
                target["reached"] += 1
                if not row["dead"]:
                    target["cleared"] += 1
                target["damage"] += row["damage"]
                target["attacks"] += row["attacks"]
                target["kills"] += row["kills"]
                target["potions_used"] += row["potions_used"]
                target["end_hp_pct"] += row["end_hp_pct"]
                target["end_level"] += row["end_level"]

        floors = []
        for row in floor_agg:
            reached = row["reached"]
            floors.append({
                "floor": row["floor"],
                "reached": reached,
                "clear_rate": row["cleared"] / reached if reached else 0,
                "avg_damage": row["damage"] / reached if reached else 0,
                "avg_attacks_per_kill": row["attacks"] / row["kills"] if row["kills"] else 0,
                "avg_potions_used": row["potions_used"] / reached if reached else 0,
                "avg_end_hp_pct": row["end_hp_pct"] / reached if reached else 0,
                "avg_end_level": row["end_level"] / reached if reached else 0,
            })

        return {
            "profile": profile,
            "scenario": scenario,
            "runs": runs,
            "completion_rate": completions / runs,
            "deaths": {str(floor): deaths[floor] for floor in range(1, 10) if deaths[floor]},
            "avg_potions_used": statistics.fmean(total_potions),
            "avg_final_level": statistics.fmean(final_levels) if final_levels else 0,
            "shop_copper_mean": statistics.fmean(shop_copper) if shop_copper else 0,
            "shop_copper_p10": percentile(shop_copper, 0.10),
            "shop_copper_p50": percentile(shop_copper, 0.50),
            "shop_copper_p90": percentile(shop_copper, 0.90),
            "shop_affordable_mean": statistics.fmean(shop_affordable) if shop_affordable else 0,
            "floors": floors,
        }

def render_markdown(results: list[dict[str, Any]], schema: int, studio_version: str, seed: int) -> str:
    lines = [
        "# GoblinArcade headless balance audit",
        "",
        f"- Studio: {studio_version} / schema {schema}",
        f"- Seed: {seed}",
        "- Model: fresh level-1 Arcade Warrior, live Studio loot/economy/progression, greedy compatible equipment.",
        "- PRESSURE / HEAVY_PRESSURE are bounded multi-aggro sensitivity tests, not pixel-perfect WoW pathfinding simulations.",
        "",
        "## Run outcomes",
        "",
        "| Build | Scenario | Completion | Potions used | Final level | F6 shop copper p10 / p50 / p90 | Affordable stock |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for result in results:
        lines.append(
            "| {profile} | {scenario} | {completion:.1%} | {potions:.2f} | {level:.2f} | {p10:.0f} / {p50:.0f} / {p90:.0f} | {aff:.2f} / 4 |".format(
                profile=result["profile"],
                scenario=result["scenario"],
                completion=result["completion_rate"],
                potions=result["avg_potions_used"],
                level=result["avg_final_level"],
                p10=result["shop_copper_p10"],
                p50=result["shop_copper_p50"],
                p90=result["shop_copper_p90"],
                aff=result["shop_affordable_mean"],
            )
        )

    lines += ["", "## Floor detail", ""]
    for result in results:
        lines += [
            f"### {result['profile']} / {result['scenario']}",
            "",
            "| Floor | Clear among reached | Avg damage | Player turns / kill | Potions | End HP | End level |",
            "|---:|---:|---:|---:|---:|---:|---:|",
        ]
        for floor in result["floors"]:
            lines.append(
                "| {floor} | {clear:.1%} | {damage:.2f} | {attacks:.2f} | {pots:.2f} | {hp:.1f}% | {level:.2f} |".format(
                    floor=floor["floor"],
                    clear=floor["clear_rate"],
                    damage=floor["avg_damage"],
                    attacks=floor["avg_attacks_per_kill"],
                    pots=floor["avg_potions_used"],
                    hp=floor["avg_end_hp_pct"],
                    level=floor["avg_end_level"],
                )
            )
        lines.append("")

    # Evidence flags only. They intentionally do not fail CI.
    seq = [x for x in results if x["scenario"] == "SEQUENTIAL"]
    pressure = [x for x in results if x["scenario"] == "PRESSURE"]
    heavy = [x for x in results if x["scenario"] == "HEAVY_PRESSURE"]
    lines += ["## Audit signals", ""]
    if seq and all(x["completion_rate"] > 0.95 for x in seq):
        lines.append("- ⚠️ Clean one-on-one model is very forgiving (>95% completion for both builds).")
    if pressure and all(x["completion_rate"] > 0.80 for x in pressure):
        lines.append("- ⚠️ The clustered-enemy pressure model remains forgiving (>80% completion for both builds).")
    if heavy and all(x["completion_rate"] > 0.70 for x in heavy):
        lines.append("- ⚠️ Even HEAVY_PRESSURE remains forgiving (>70% completion for both builds).")
    if heavy and any(x["completion_rate"] < 0.25 for x in heavy):
        lines.append("- ⚠️ HEAVY_PRESSURE is extremely lethal (<25% completion for at least one build).")
    if len(pressure) == 2:
        gap = abs(pressure[0]["completion_rate"] - pressure[1]["completion_rate"])
        if gap > 0.10:
            lines.append(f"- ⚠️ 1H+shield vs 2H completion gap is {gap:.1%}, large enough to investigate.")
        else:
            lines.append(f"- ✅ 1H+shield vs 2H completion gap is {gap:.1%} in the pressure model.")
    if seq:
        f6 = statistics.fmean(x["shop_affordable_mean"] for x in seq)
        if f6 < 1.0:
            lines.append("- ⚠️ Floor 6 shop economy looks too tight: average affordable stock <1 / 4.")
        elif f6 > 3.7:
            lines.append("- ⚠️ Floor 6 shop economy looks very loose: almost all stock is affordable.")
        else:
            lines.append(f"- ✅ Floor 6 shop affordability is in a usable band ({f6:.2f} / 4 stock items affordable on average).")
    lines.append("")
    return "\n".join(lines)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=6000, help="Runs per build/scenario")
    parser.add_argument("--seed", type=int, default=5401)
    args = parser.parse_args()

    audit = Audit(args.seed)
    results = []
    for profile in ("shield", "2h"):
        results.append(audit.simulate(profile, 0.0, "SEQUENTIAL", args.runs))
        results.append(audit.simulate(profile, 1.0, "PRESSURE", args.runs))
        results.append(audit.simulate(profile, 2.0, "HEAVY_PRESSURE", args.runs))

    print(
        render_markdown(
            results,
            int(audit.data.get("schemaVersion", 0)),
            str(audit.data.get("studioVersion", "?")),
            args.seed,
        )
    )
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
