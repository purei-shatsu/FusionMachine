"""Import Digimon card data from the DCGO simulator into a SQLite database.

DCGO stores one Unity YAML `.asset` per card under
`CardBaseEntity/<Set>/<Color>/<Kind>/<CARDID>.asset`. This walks that tree and
upserts every card into `digimon.cdb` (schema in tools/schema.sql).

The import is incremental and idempotent: each card row keeps the sha1 of the
`.asset` it came from, so re-running after DCGO ships a new set only touches the
cards that are new or changed. Safe to run repeatedly.

    python tools/dcgo_import.py                 # uses the defaults below
    python tools/dcgo_import.py --prune         # also drop cards whose .asset is gone
"""

import argparse
import hashlib
import re
import sqlite3
import struct
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent

DEFAULT_DCGO = Path(r"D:\Git\DCGO\DCGO\Assets\CardBaseEntity")
DEFAULT_ART = Path(r"D:\Downloads\DCGO_Application\Assets\Textures\Card")
DEFAULT_DB = REPO / "digimon.cdb"

# Confirmed against sample cards: Monzaemon=0, Tai Kamiya=1, Gravity Crush=2, Upamon=3.
CARD_KINDS = {0: "Digimon", 1: "Tamer", 2: "Option", 3: "DigiEgg"}

# `m_Name: BT10_060_P1` -> alt-art printing of BT10-060. The CardID field itself
# stays the base id, so it is the merge key; this only picks which asset wins.
VARIANT_RE = re.compile(r"_P(\d+)$")

# cardColors and cardKind are Unity's compact hex blob for an int array. They must NOT
# go through YAML: "01000000" matches YAML 1.1's octal int rule and would silently become
# 262144. Both are genuinely multi-valued -- BT25/EX12 ship dual Digimon/Option cards
# (Siriusmon EX12-018), whose cardKind is [0, 2].
def int_blob(text, field, path):
    match = re.search(rf"^\s*{field}:\s*(\S*)\s*$", text, re.MULTILINE)
    blob = match.group(1) if match else ""
    if len(blob) % 8:
        raise ValueError(f"{path}: {field} blob {blob!r} is not a whole number of int32s")
    return [v[0] for v in struct.iter_unpack("<i", bytes.fromhex(blob))]

# A bare "=" is YAML 1.1's reserved "value" tag, which SafeLoader has no constructor
# for. DCGO writes one in EX12_021_P1's dualEffect (where every other card has a name
# or '-'), so keep it a plain string instead of letting the whole asset fail to parse.
yaml.SafeLoader.add_constructor(
    "tag:yaml.org,2002:value", lambda loader, node: loader.construct_scalar(node)
)

# Fields DCGO ships wrong, overridden with what the card actually says. Applied by
# CardID in parse_asset, and folded into the card's source_hash so that editing an
# entry here re-imports that card on the next run.
#
# Traits: Type_ENG and Attribute_ENG are swapped on these six cards, and on no others.
# P-059 is typed "Virus" with attribute "Ceratopsian", while its Japanese fields say the
# opposite. EX11-011 has the attribute leaking into the front of its type list. The values
# below are what the Japanese fields say, so the corrected cards go into the database.
# They are found by looking for a card whose first type is an attribute name -- a trait can
# never be "Vaccine" | "Data" | "Virus" | "Free".
#
# BT17-077 and EX12-076 leak the same way, but further down the type list: the attribute
# "Free" and the form "Hybrid" are appended after the real traits. They are found by
# looking for any type that is also a known attribute or form name.
#
# Stats: these three EX-11 cards ship with DP and PlayCost zeroed out (the rest of EX-11
# is fine). DP 0 is a legal value -- BT18-086 Lucemon: Larva really is a 0 DP card -- so
# nothing can detect this automatically; the values come from the official card list.
#
# Scrape leftovers: EX11-074 Vortexdramon has the wiki markup '[[:Category:|]]' where its
# name should be and '???' where its first type should be, so it fused into nothing (no
# trait group matches '???'). Its real types are Bird Dragon / Vortex Warriors / LIBERATOR.
# The Tamers EX11-053 and EX11-071 carry the same broken name, but the game never sees
# them (it only plays card_kind 0), so they are left alone.
CARD_FIXES = {
    "P-059": {"Type_ENG": ["Ceratopsian"], "Attribute_ENG": ["Virus"]},
    "P-061": {"Type_ENG": ["Mollusk"], "Attribute_ENG": ["Data"]},
    "P-074": {"Type_ENG": ["Beastkin"], "Attribute_ENG": ["Vaccine"]},
    "P-076": {"Type_ENG": ["Composite"], "Attribute_ENG": ["Virus"]},
    "P-077": {"Type_ENG": ["Wizard"], "Attribute_ENG": ["Data"]},
    "EX11-011": {"Type_ENG": ["Dinosaur", "LIBERATOR"], "Attribute_ENG": ["Vaccine"]},
    "BT17-077": {"Type_ENG": ["Ancient Holy Warrior"]},
    "EX12-076": {"Type_ENG": ["Shaman", "Shambala", "SW", "TB", "TS"]},
    "EX11-009": {"DP": 6000, "PlayCost": 5},
    "EX11-010": {"DP": 7000, "PlayCost": 8},
    "EX11-047": {"DP": 1000, "PlayCost": 3},
    "EX11-074": {
        "CardName_ENG": "Vortexdramon",
        "Type_ENG": ["Bird Dragon", "Vortex Warriors", "LIBERATOR"],
    },
}

# Release date of every set, from the official product list at
# https://en.digimoncard.com/products/. The assets carry no date of their own, so
# this is the only way to answer "which of these two cards is newer".
#
# Set codes are written here as Bandai prints them (BT-01) and normalised to the
# form the assets use (BT1) by normalize_set_code. Sets DCGO has not shipped yet
# are listed too, so a future sync does not immediately trip the assertion below.
#
# P (promos) and LM span the game's whole life and have no single date. They sort
# oldest, so a card from a real set always wins a recency tie against them.
SET_RELEASES = {
    "P": None,
    "LM": None,
    "ST-01": "2020-04-24",
    "ST-02": "2020-04-24",
    "ST-03": "2020-04-24",
    "BT-01": "2020-05-15",
    "BT-02": "2020-07-22",
    "BT-03": "2020-10-30",
    "ST-04": "2020-11-27",
    "ST-05": "2020-11-27",
    "ST-06": "2020-11-27",
    "BT-04": "2020-12-18",
    "BT-05": "2021-02-26",
    "ST-07": "2021-04-23",
    "ST-08": "2021-04-23",
    "BT-06": "2021-05-28",
    "EX-01": "2021-07-30",
    "BT-07": "2021-08-27",
    "ST-09": "2021-10-29",
    "ST-10": "2021-10-29",
    "ST-11": "2021-11-26",
    "BT-08": "2021-11-26",
    "EX-02": "2021-12-24",
    "BT-09": "2022-02-25",
    "ST-12": "2022-04-22",
    "ST-13": "2022-04-22",
    "BT-10": "2022-05-27",
    "EX-03": "2022-07-29",
    "BT-11": "2022-09-30",
    "BT-12": "2022-11-25",
    "ST-14": "2022-12-09",
    "EX-04": "2022-12-23",
    "RB-01": "2023-01-27",
    "BT-13": "2023-02-24",
    "ST-15": "2023-05-26",
    "ST-16": "2023-05-26",
    "BT-14": "2023-06-30",
    "EX-05": "2023-08-25",
    "BT-15": "2023-09-29",
    "ST-17": "2023-11-24",
    "BT-16": "2023-12-22",
    "EX-06": "2024-02-23",
    "BT-17": "2024-03-29",
    "ST-18": "2024-04-26",
    "ST-19": "2024-04-26",
    "EX-07": "2024-05-31",
    "BT-18": "2024-06-28",
    "BT-19": "2024-09-27",
    "EX-08": "2024-11-29",
    "BT-20": "2025-01-31",
    "ST-20": "2025-04-19",
    "ST-21": "2025-04-19",
    "BT-21": "2025-04-19",
    "EX-09": "2025-06-26",
    "BT-22": "2025-07-19",
    "EX-10": "2025-09-20",
    "BT-23": "2025-10-18",
    "ST-22": "2025-12-06",
    "BT-24": "2026-01-17",
    "EX-11": "2026-02-14",
    "AD-01": "2026-03-28",
    "BT-25": "2026-05-16",
    "ST-23": "2026-05-16",
    "ST-24": "2026-05-16",
    "EX-12": "2026-07-04",
    "BT-26": "2026-08-29",
    "EX-13": "2026-10-03",
}


def parse_asset(path):
    """Parse one Unity .asset into (fields, colors, kinds). Returns None for non-card assets."""
    text = path.read_text(encoding="utf-8")

    # Drop the Unity header (%YAML / %TAG / --- !u!114 &...) so this is plain YAML.
    body = text.split("\n", 3)[3]
    doc = yaml.safe_load(body)
    fields = doc.get("MonoBehaviour")
    if not fields or "CardID" not in fields:
        return None

    fields.update(CARD_FIXES.get(fields["CardID"], {}))

    return fields, int_blob(text, "cardColors", path), int_blob(text, "cardKind", path)


def normalize_set_code(printed):
    """'BT-01' -> 'BT1', matching the set_code the assets' card ids yield. 'P' -> 'P'."""
    line, _, number = printed.partition("-")
    return line + str(int(number)) if number else line


def write_sets(db):
    """Rewrite the sets table, ranking every set oldest-first by release date.

    Undated lines (P, LM) get order 0, so they lose every recency tie.
    """
    dated = sorted((d, normalize_set_code(s)) for s, d in SET_RELEASES.items() if d)
    rows = [(normalize_set_code(s), 0, None) for s, d in SET_RELEASES.items() if not d]
    rows += [(code, order, date) for order, (date, code) in enumerate(dated, start=1)]

    db.execute("DELETE FROM sets")
    db.executemany("INSERT INTO sets (set_code, release_order, release_date) VALUES (?, ?, ?)", rows)

    orphans = [
        code
        for (code,) in db.execute(
            "SELECT DISTINCT set_code FROM cards WHERE set_code NOT IN (SELECT set_code FROM sets)"
        )
    ]
    if orphans:
        raise SystemExit(
            f"no release date for set(s) {', '.join(sorted(orphans))} -- add them to SET_RELEASES"
        )


def blank_to_none(value):
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def derive_color_names(cards):
    """Map colour int -> name using the <Color> folder each card sits in.

    Folder names are mostly right but not authoritative (some cards are misfiled),
    so take the majority folder per colour value rather than trusting any one card.
    """
    votes = defaultdict(Counter)
    for card in cards.values():
        if card["colors"]:
            votes[card["colors"][0]][card["folder_color"]] += 1
    return {value: tally.most_common(1)[0][0] for value, tally in votes.items()}


def source_hash(path, card_id):
    """Identity of a card's input: the .asset bytes, plus its CARD_FIXES entry if it has one.

    Mixing the fix in means editing CARD_FIXES re-imports exactly the cards it names, instead
    of them being skipped as unchanged. Unfixed cards keep the plain sha1 of their asset.
    """
    fix = CARD_FIXES.get(card_id)
    payload = path.read_bytes()
    if fix:
        payload += repr(sorted(fix.items())).encode()
    return hashlib.sha1(payload).hexdigest()


def collect(dcgo_root):
    """Walk the CardBaseEntity tree, merging alt-art printings into one card each."""
    best = {}
    for path in sorted(dcgo_root.rglob("*.asset")):
        parsed = parse_asset(path)
        if parsed is None:
            continue
        fields, colors, kinds = parsed

        card_id = fields["CardID"]
        variant = VARIANT_RE.search(path.stem)
        # Prefer the unsuffixed asset; otherwise the lowest -Pn.
        rank = -1 if variant is None else int(variant.group(1))

        rel = path.relative_to(dcgo_root)
        if card_id in best and best[card_id]["rank"] <= rank:
            continue
        best[card_id] = {
            "rank": rank,
            "fields": fields,
            "colors": colors,
            "kinds": kinds,
            "path": path,
            "source_path": rel.as_posix(),
            "folder_color": rel.parts[1],
            "source_hash": source_hash(path, card_id),
        }
    return best


def art_file(art_dir, card_id):
    image = art_dir / f"{card_id}.webp"
    return image.name if image.is_file() else None


def refresh_art(db, art_dir):
    """Re-stamp has_art/image_file on every card, imported this run or not.

    Art presence is a fact about the art folder, not about the .asset, so the source_hash
    skip would otherwise freeze it at whatever was on disk the first time a card was seen --
    a card whose art downloaded after its import would stay artless forever.
    """
    changed = 0
    for card_id, image_file in db.execute("SELECT card_id, image_file FROM cards").fetchall():
        current = art_file(art_dir, card_id)
        if current != image_file:
            db.execute(
                "UPDATE cards SET image_file = ?, has_art = ? WHERE card_id = ?",
                (current, int(current is not None), card_id),
            )
            changed += 1
    return changed


def build_row(card_id, card, art_dir, now):
    fields = card["fields"]

    set_code, _, number = card_id.rpartition("-")
    # The first kind is the card's primary nature; a dual Digimon/Option card is a Digimon
    # that also has an Option side, never the reverse. card_kinds holds the full list.
    kind = card["kinds"][0]

    image_file = art_file(art_dir, card_id)

    return {
        "card_id": card_id,
        "set_code": set_code,
        "card_number": int(number) if number.isdigit() else None,
        "name_en": fields["CardName_ENG"],
        "name_jp": blank_to_none(fields.get("CardName_JPN")),
        "card_kind": kind,
        "card_kind_name": CARD_KINDS[kind],
        "level": fields.get("Level"),
        "dp": fields.get("DP"),
        "play_cost": fields.get("PlayCost"),
        "rarity": fields.get("rarity"),
        "overflow_memory": fields.get("OverflowMemory"),
        "link_dp": fields.get("LinkDP"),
        "link_effect": blank_to_none(fields.get("LinkEffect")),
        "link_requirement": blank_to_none(fields.get("LinkRequirement")),
        "max_in_deck": fields.get("MaxCountInDeck"),
        "effect_en": blank_to_none(fields.get("EffectDiscription_ENG")),
        "inherited_effect_en": blank_to_none(fields.get("InheritedEffectDiscription_ENG")),
        "security_effect_en": blank_to_none(fields.get("SecurityEffectDiscription_ENG")),
        "sprite_name": blank_to_none(fields.get("CardSpriteName")),
        "image_file": image_file,
        "has_art": int(image_file is not None),
        "source_path": card["source_path"],
        "source_hash": card["source_hash"],
        "updated_at": now,
    }


def write_children(db, card_id, card, color_names):
    tables = (
        "card_colors",
        "card_kinds",
        "card_types",
        "card_forms",
        "card_attributes",
        "card_evo_costs",
    )
    for table in tables:
        db.execute(f"DELETE FROM {table} WHERE card_id = ?", (card_id,))

    db.executemany(
        "INSERT INTO card_colors (card_id, ord, color, color_name) VALUES (?, ?, ?, ?)",
        [(card_id, i, c, color_names.get(c)) for i, c in enumerate(card["colors"])],
    )
    db.executemany(
        "INSERT INTO card_kinds (card_id, ord, kind, kind_name) VALUES (?, ?, ?, ?)",
        [(card_id, i, k, CARD_KINDS[k]) for i, k in enumerate(card["kinds"])],
    )
    for table, column, field in (
        ("card_types", "type_en", "Type_ENG"),
        ("card_forms", "form_en", "Form_ENG"),
        ("card_attributes", "attribute_en", "Attribute_ENG"),
    ):
        db.executemany(
            f"INSERT INTO {table} (card_id, ord, {column}) VALUES (?, ?, ?)",
            [(card_id, i, v) for i, v in enumerate(card["fields"].get(field) or [])],
        )
    db.executemany(
        "INSERT INTO card_evo_costs"
        " (card_id, ord, from_color, from_color_name, from_level, memory_cost)"
        " VALUES (?, ?, ?, ?, ?, ?)",
        [
            (
                card_id,
                i,
                evo.get("CardColor"),
                color_names.get(evo.get("CardColor")),
                evo.get("Level"),
                evo.get("MemoryCost"),
            )
            for i, evo in enumerate(card["fields"].get("EvoCosts") or [])
        ],
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dcgo", type=Path, default=DEFAULT_DCGO, help="DCGO CardBaseEntity folder")
    ap.add_argument("--art", type=Path, default=DEFAULT_ART, help="folder of <CardID>.webp art")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="output SQLite database")
    ap.add_argument("--prune", action="store_true", help="delete cards whose .asset is gone")
    args = ap.parse_args()

    cards = collect(args.dcgo)
    color_names = derive_color_names(cards)
    print(f"scanned {len(cards)} cards; colours: " + ", ".join(
        f"{v}={color_names[v]}" for v in sorted(color_names)))

    db = sqlite3.connect(args.db)
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript((REPO / "tools" / "schema.sql").read_text(encoding="utf-8"))

    known = dict(db.execute("SELECT card_id, source_hash FROM cards"))
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    added = updated = unchanged = 0
    for card_id, card in cards.items():
        if known.get(card_id) == card["source_hash"]:
            unchanged += 1
            continue

        row = build_row(card_id, card, args.art, now)
        columns = ", ".join(row)
        placeholders = ", ".join(f":{c}" for c in row)
        db.execute(
            f"INSERT INTO cards ({columns}) VALUES ({placeholders})"
            f" ON CONFLICT(card_id) DO UPDATE SET"
            + ", ".join(f" {c} = excluded.{c}" for c in row if c != "card_id"),
            row,
        )
        write_children(db, card_id, card, color_names)

        if card_id in known:
            updated += 1
        else:
            added += 1

    missing = sorted(set(known) - set(cards))
    if missing and args.prune:
        db.executemany("DELETE FROM cards WHERE card_id = ?", [(c,) for c in missing])

    write_sets(db)
    rehashed = refresh_art(db, args.art)
    db.commit()

    with_art = db.execute("SELECT count(*) FROM cards WHERE has_art = 1").fetchone()[0]
    total = db.execute("SELECT count(*) FROM cards").fetchone()[0]
    db.close()

    print(f"added {added} / updated {updated} / unchanged {unchanged}")
    print(f"art re-stamped on {rehashed} cards")
    if missing:
        action = "pruned" if args.prune else "still present (use --prune to delete)"
        print(f"missing .asset for {len(missing)} cards: {action}")
    print(f"{total} cards in {args.db}; {with_art} with art, {total - with_art} without")


if __name__ == "__main__":
    sys.exit(main())
